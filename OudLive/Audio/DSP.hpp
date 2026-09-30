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
    DelayTime, Feedback, Modulation, ModRate, Flanger, Doubler, Bypass, Mute,
    Decay, Predelay, Tone, Makeup, Intensity, RecordGain, Count };
inline float clamp(float x, float a, float b) { return std::max(a, std::min(b, x)); }
inline float db(float x) { return std::pow(10.f, x / 20.f); }
constexpr std::array<float, Count> defaults = {6,-9,0,0,0,.25f,.24f,.12f,320,.32f,0,.7f,0,0,0,0,2.4f,22,.5f,4,1,0};
constexpr std::array<float, Count> minimum = {-24,-60,-12,-12,-12,0,0,0,40,0,0,.1f,0,0,0,0,.4f,0,0,0,0,-12};
constexpr std::array<float, Count> maximum = {30,0,12,12,12,1,1,1,1200,.82f,1,3,1,1,1,1,7,100,1,12,1.5f,18};
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
    Ring ring; float damp=0, feedback=.8f, desiredFeedback=.8f;
    float tick(float x, float damping) {
        float y=ring.read(float(ring.data.size()-2));
        damp=damping*y+(1-damping)*damp;
        feedback+=.001f*(desiredFeedback-feedback);
        ring.push(x+feedback*damp); return y;
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
    Ring echo,echoRight,mod,pre;
    float echoDampL=0,echoDampR=0,limiterGain=1,recordLimiter=1,limiterRelease=0;
    std::array<std::array<Comb,8>,2> combs;
    std::array<std::array<Allpass,2>,2> diffusion;
public:
    std::atomic<float> inputPeak{0}, outputPeak{0}, gainReduction{0}, recordPeak{0}, recordReduction{0};
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
        phase=phaseD1=phaseD2=envelope=hpX=hpY=echoDampL=echoDampR=0; eq={};
        limiterGain=recordLimiter=1; limiterRelease=1-std::exp(-1/(.08f*rate));
        for(int i=0;i<Count;++i) current[i]=get(i);
        // Fade up from silence on every start, even with persisted settings.
        current[Output]=-60;
        echo.prepare(size_t(rate*1.55f)+4); echoRight.prepare(size_t(rate*1.55f)+4);
        mod.prepare(size_t(rate*.08f)+4); pre.prepare(size_t(rate*.15f)+4);
        constexpr float times[8]={.0297f,.0371f,.0411f,.0437f,.0313f,.0337f,.0397f,.0479f};
        for(int c=0;c<2;++c) {
            for(int k=0;k<8;++k) {
                auto &comb=combs[c][k]; comb.ring.prepare(size_t(rate*(times[k]+c*.0013f))+2); comb.damp=0;
                comb.feedback=comb.desiredFeedback=std::pow(.001f,float(comb.ring.data.size()-2)/(rate*current[Decay]));
            }
            diffusion[c][0].ring.prepare(size_t(rate*(.005f+c*.0003f))+2);
            diffusion[c][1].ring.prepare(size_t(rate*(.0017f+c*.0002f))+2);
        }
        inputPeak.store(0); outputPeak.store(0); gainReduction.store(0); recordPeak.store(0); recordReduction.store(0);
    }
    void process(const float *in,float *left,float *right,size_t frames,float *recordLeft=nullptr,float *recordRight=nullptr) {
        std::array<float,Count> requested;
        for(int p=0;p<Count;++p) requested[p]=get(p);
        for(auto &channel:combs) for(auto &comb:channel)
            comb.desiredFeedback=std::pow(.001f,float(comb.ring.data.size()-2)/(rate*requested[Decay]));
        // Gain changes use a 12ms ramp; EQ moves by a block-sized equivalent.
        float blockSmooth=1-std::pow(1-smoothing,float(frames));
        for(int p=Low;p<=High;++p) current[p]+=blockSmooth*(requested[p]-current[p]);
        eq[0].peak(180,current[Low],rate); eq[1].peak(1100,current[Mid],rate); eq[2].peak(4800,current[High],rate);
        float inPeak=0,outPeak=0,maxReduction=0,recPeak=0,recReduction=0;
        for(size_t i=0;i<frames;++i) {
            for(int p=0;p<Count;++p) if(p<Low || p>High) {
                current[p]+=smoothing*(requested[p]-current[p]);
                if(std::abs(requested[p]-current[p])<.0001f) current[p]=requested[p];
            }
            float raw=std::isfinite(in[i])?clamp(in[i],-8,8):0;
            float dry=raw*db(current[Input]);
            inPeak=std::max(inPeak,std::abs(dry));
            float x=hpCoefficient*(hpY+dry-hpX); hpX=dry; hpY=x;
            for(auto &band:eq) x=band.tick(x);
            float absolute=std::abs(x), coef=absolute>envelope?attack:release;
            envelope=coef*envelope+(1-coef)*absolute;
            float level=20*std::log10(std::max(envelope,1e-8f));
            float threshold=-10-20*current[Compression], ratio=1+5*current[Compression];
            // 6 dB soft knee preserves quieter attacks while gradually compressing.
            float over=level-threshold;
            float knee=over < -3 ? 0 : (over>3 ? over : (over+3)*(over+3)/12);
            float reduction=knee*(1-1/ratio);
            x*=db(current[Makeup]-reduction);
            float echoSample=echo.read(current[DelayTime]*.001f*rate);
            float echoSampleR=echoRight.read(current[DelayTime]*.00125f*rate);
            echoDampL+=.4f*(echoSample-echoDampL); echoDampR+=.4f*(echoSampleR-echoDampR);
            echo.push(x+echoDampR*current[Feedback]);
            echoRight.push(x+echoDampL*current[Feedback]);
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
            float preFrames=current[Predelay]*.001f*rate;
            float rvInput=pre.read(std::max(1.f,preFrames));
            float earlyL=pre.read(preFrames+.011f*rate)*.35f+pre.read(preFrames+.027f*rate)*.2f;
            float earlyR=pre.read(preFrames+.017f*rate)*.35f+pre.read(preFrames+.033f*rate)*.2f;
            pre.push(x);
            for(int c=0;c<2;++c) {
                for(auto &comb:combs[c]) rv[c]+=comb.tick(rvInput,.1f+.65f*current[Tone])*.125f;
                for(auto &ap:diffusion[c]) rv[c]=ap.tick(rv[c]);
            }
            rv[0]=rv[0]*1.7f+earlyL; rv[1]=rv[1]*1.7f+earlyR;
            float mixed[2];
            float strength=current[Intensity];
            mixed[0]=x+strength*((ml-.35f*x)*current[Modulation]+dl*current[Doubler]+echoSample*current[Delay]+rv[0]*current[Reverb]);
            mixed[1]=x+strength*((mr-.35f*x)*current[Modulation]+dr*current[Doubler]+echoSampleR*current[Delay]+rv[1]*current[Reverb]);
            // Recording splits BEFORE monitor gain and monitor mute. Its own
            // linked limiter protects the file without affecting headphone level.
            float rec[2];
            for(int c=0;c<2;++c) {
                rec[c]=(mixed[c]*(1-current[Bypass])+dry*current[Bypass])*db(current[RecordGain]);
                if(!std::isfinite(rec[c])) rec[c]=0;
            }
            float recMax=std::max(std::abs(rec[0]),std::abs(rec[1]));
            float recNeeded=recMax>.94f ? .94f/recMax : 1;
            if(recNeeded<recordLimiter) recordLimiter=recNeeded;
            else recordLimiter+=limiterRelease*(recNeeded-recordLimiter);
            recReduction=std::max(recReduction,-20*std::log10(std::max(recordLimiter,1e-8f)));
            for(int c=0;c<2;++c) {
                float sample=clamp(rec[c]*recordLimiter,-.98f,.98f);
                if(c==0 && recordLeft) recordLeft[i]=sample;
                if(c==1 && recordRight) recordRight[i]=sample;
                recPeak=std::max(recPeak,std::abs(sample));
            }
            float gain=db(current[Output])*(1-current[Mute]);
            float y[2];
            for(int c=0;c<2;++c) {
                y[c]=(mixed[c]*(1-current[Bypass])+dry*current[Bypass])*gain;
                if(!std::isfinite(y[c])) y[c]=0;
            }
            // Stereo-linked, zero-lookahead peak limiter: immediate reduction,
            // 80ms recovery. Unlike a hard clipper it preserves the stereo image.
            float peak=std::max(std::abs(y[0]),std::abs(y[1]));
            float needed=peak>.94f?.94f/peak:1;
            if(needed<limiterGain) limiterGain=needed;
            else limiterGain+=limiterRelease*(needed-limiterGain);
            maxReduction=std::max(maxReduction,-20*std::log10(std::max(limiterGain,1e-8f)));
            for(int c=0;c<2;++c) {
                float limited=clamp(y[c]*limiterGain,-.98f,.98f);
                (c==0?left:right)[i]=limited; outPeak=std::max(outPeak,std::abs(limited));
            }
        }
        recordPeak.store(std::max(recPeak,recordPeak.load()*.88f));
        recordReduction.store(std::max(recReduction,recordReduction.load()*.88f));
        inputPeak.store(std::max(inPeak,inputPeak.load()*.88f),std::memory_order_relaxed);
        outputPeak.store(std::max(outPeak,outputPeak.load()*.88f),std::memory_order_relaxed);
        gainReduction.store(std::max(maxReduction,gainReduction.load()*.88f),std::memory_order_relaxed);
    }
};
}
