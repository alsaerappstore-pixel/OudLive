#pragma once
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <vector>

namespace oud {
constexpr float pi = 3.14159265358979323846f;
enum Param : int { Input, Output, Low, Mid, High, Compression, Reverb, Delay,
    DelayTime, Feedback, Modulation, ModRate, Flanger, Doubler, Bypass, Mute, Count };
inline float clamp(float x, float a, float b) { return std::max(a, std::min(b, x)); }
inline float db(float x) { return std::pow(10.f, x / 20.f); }
constexpr std::array<float, Count> defaults = {0,-9,0,0,0,.2f,.12f,0,280,.25f,0,.7f,0,0,0,0};
constexpr std::array<float, Count> minimum = {-24,-60,-12,-12,-12,0,0,0,40,0,0,.1f,0,0,0,0};
constexpr std::array<float, Count> maximum = {18,0,12,12,12,1,.8f,.8f,800,.7f,.8f,3,1,.8f,1,1};
static_assert(std::atomic<float>::is_always_lock_free, "Audio needs lock-free float atomics");

struct Biquad {
    float b0=1,b1=0,b2=0,a1=0,a2=0,z1=0,z2=0;
    void peak(float hz, float gain, float rate) {
        float A=std::pow(10.f,gain/40), w=2*pi*hz/rate, alpha=std::sin(w)/1.4f;
        float a0=1+alpha/A;
        b0=(1+alpha*A)/a0; b1=-2*std::cos(w)/a0; b2=(1-alpha*A)/a0;
        a1=b1; a2=(1-alpha/A)/a0;
    }
    float tick(float x) { float y=b0*x+z1; z1=b1*x-a1*y+z2; z2=b2*x-a2*y; return y; }
};
struct Ring {
    std::vector<float> data; size_t cursor=0;
    void prepare(size_t count) { data.assign(count,0); cursor=0; }
    float read(float delay) const {
        float p=float(cursor)-clamp(delay,1,float(data.size()-2));
        if(p<0) p+=float(data.size());
        size_t i=size_t(p), j=(i+1)%data.size(); float f=p-float(i);
        return data[i]+f*(data[j]-data[i]);
    }
    void push(float x) { data[cursor]=x; cursor=(cursor+1)%data.size(); }
};
struct Comb {
    Ring ring; float damp=0;
    float tick(float x) {
        float y=ring.read(float(ring.data.size()-2));
        damp=.25f*y+.75f*damp;
        ring.push(x+.76f*damp); return y;
    }
};
struct Allpass {
    Ring ring;
    float tick(float x) {
        float y=ring.read(float(ring.data.size()-2));
        float out=y-.5f*x; ring.push(x+.5f*out); return out;
    }
};
// Single audio-thread owner. prepare() is called only while RemoteIO is stopped.
// UI writes bounded atomics. No allocation, mutex, ObjC or dispatch in process().
class DSP {
    std::array<std::atomic<float>, Count> target;
    std::array<float,Count> current{};
    float rate=48000, smoothing=0, phase=0, phaseD1=0, phaseD2=0, envelope=0, attack=0, release=0;
    float hpX=0,hpY=0,hpCoefficient=0;
    std::array<Biquad,3> eq;
    Ring echo,mod;
    std::array<std::array<Comb,4>,2> combs;
    std::array<std::array<Allpass,2>,2> diffusion;
public:
    std::atomic<float> inputPeak{0}, outputPeak{0};
    DSP() { for(int i=0;i<Count;++i) target[i].store(defaults[i]); }
    void set(int p,float value) {
        if(p>=0 && p<Count && std::isfinite(value))
            target[p].store(clamp(value,minimum[p],maximum[p]),std::memory_order_relaxed);
    }
    float get(int p) const { return target[p].load(std::memory_order_relaxed); }
    void prepare(float sampleRate) {
        rate=sampleRate; smoothing=1-std::exp(-1/(.012f*rate));
        attack=std::exp(-1/(.005f*rate)); release=std::exp(-1/(.12f*rate));
        hpCoefficient=std::exp(-2*pi*35/rate);
        phase=phaseD1=phaseD2=envelope=hpX=hpY=0; eq={};
        for(int i=0;i<Count;++i) current[i]=get(i);
        // Fade up from silence on every start, even with persisted settings.
        current[Output]=-60;
        echo.prepare(size_t(rate*.85f)+4); mod.prepare(size_t(rate*.08f)+4);
        constexpr float times[4]={.0297f,.0371f,.0411f,.0437f};
        for(int c=0;c<2;++c) {
            for(int k=0;k<4;++k) { combs[c][k].ring.prepare(size_t(rate*(times[k]+c*.0013f))+2); combs[c][k].damp=0; }
            diffusion[c][0].ring.prepare(size_t(rate*(.005f+c*.0003f))+2);
            diffusion[c][1].ring.prepare(size_t(rate*(.0017f+c*.0002f))+2);
        }
        inputPeak.store(0); outputPeak.store(0);
    }
    void process(const float *in,float *left,float *right,size_t frames) {
        std::array<float,Count> requested;
        for(int p=0;p<Count;++p) requested[p]=get(p);
        // Gain changes use a 12ms ramp; EQ moves by a block-sized equivalent.
        float blockSmooth=1-std::pow(1-smoothing,float(frames));
        for(int p=Low;p<=High;++p) current[p]+=blockSmooth*(requested[p]-current[p]);
        eq[0].peak(180,current[Low],rate); eq[1].peak(1100,current[Mid],rate); eq[2].peak(4800,current[High],rate);
        float inPeak=0,outPeak=0;
        for(size_t i=0;i<frames;++i) {
            for(int p=0;p<Count;++p) if(p<Low || p>High) {
                current[p]+=smoothing*(requested[p]-current[p]);
                if(std::abs(requested[p]-current[p])<.0001f) current[p]=requested[p];
            }
            float raw=std::isfinite(in[i])?clamp(in[i],-8,8):0;
            inPeak=std::max(inPeak,std::abs(raw));
            float dry=raw*db(current[Input]);
            float x=hpCoefficient*(hpY+dry-hpX); hpX=dry; hpY=x;
            for(auto &band:eq) x=band.tick(x);
            float absolute=std::abs(x), coef=absolute>envelope?attack:release;
            envelope=coef*envelope+(1-coef)*absolute;
            float level=20*std::log10(std::max(envelope,1e-8f));
            float threshold=-10-20*current[Compression], ratio=1+5*current[Compression];
            float reduction=std::max(0.f,level-threshold)*(1-1/ratio);
            x*=db(-reduction);
            float echoSample=echo.read(current[DelayTime]*.001f*rate);
            echo.push(x+echoSample*current[Feedback]);
            float isFlanger=current[Flanger];
            float modBase=(.018f*(1-isFlanger)+.0025f*isFlanger)*rate;
            float modDepth=(.003f*(1-isFlanger)+.002f*isFlanger)*rate;
            float ml=mod.read(modBase+modDepth*std::sin(phase));
            float mr=mod.read(modBase+modDepth*std::sin(phase+pi*.5f));
            float dl=mod.read(rate*(.025f+.004f*std::sin(phaseD1)));
            float dr=mod.read(rate*(.039f+.004f*std::sin(phaseD2+1)));
            mod.push(x);
            float increment=2*pi*current[ModRate]/rate;
            phase+=increment; phaseD1+=increment*.73f; phaseD2+=increment*.91f;
            if(phase>2*pi) phase-=2*pi;
            if(phaseD1>2*pi) phaseD1-=2*pi;
            if(phaseD2>2*pi) phaseD2-=2*pi;
            float rv[2]={0,0};
            for(int c=0;c<2;++c) {
                for(auto &comb:combs[c]) rv[c]+=comb.tick(x)*.25f;
                for(auto &ap:diffusion[c]) rv[c]=ap.tick(rv[c]);
            }
            float mixed[2];
            mixed[0]=x*(1-.4f*current[Modulation])+ml*current[Modulation]+dl*current[Doubler]+echoSample*current[Delay]+rv[0]*current[Reverb];
            mixed[1]=x*(1-.4f*current[Modulation])+mr*current[Modulation]+dr*current[Doubler]+echoSample*current[Delay]+rv[1]*current[Reverb];
            float gain=db(current[Output])*(1-current[Mute]);
            for(int c=0;c<2;++c) {
                float y=(mixed[c]*(1-current[Bypass])+dry*current[Bypass])*gain;
                // Last-resort peak clamp; not advertised as a transparent mastering limiter.
                y=std::isfinite(y)?clamp(y,-.98f,.98f):0;
                (c==0?left:right)[i]=y; outPeak=std::max(outPeak,std::abs(y));
            }
        }
        inputPeak.store(std::max(inPeak,inputPeak.load()*.88f),std::memory_order_relaxed);
        outputPeak.store(std::max(outPeak,outputPeak.load()*.88f),std::memory_order_relaxed);
    }
};
}
