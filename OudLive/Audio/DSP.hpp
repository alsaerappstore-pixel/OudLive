#pragma once
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <vector>
namespace oud {
constexpr float pi=3.14159265358979323846f;
enum Param:int { Input,Output,Low,Mid,High,Compression,Reverb,Delay,DelayTime,Feedback,RoomSize,Width,Early,Noise,Bypass,Mute,Decay,Predelay,Tone,Makeup,Intensity,RecordGain,Live,Trim,Count };
using Controls=std::array<float,Count>;
constexpr Controls defaults={6,-9,1,-.2f,-.6f,.2f,.13f,0,250,0,.35f,.25f,.4f,.15f,0,0,1.2f,24,.25f,.35f,1,0,1,-.4f};
constexpr Controls minimum={-24,-60,-3,-3,-3,0,0,0,40,0,0,0,0,0,0,0,.5f,10,0,0,0,-12,0,-3};
constexpr Controls maximum={24,0,3,3,3,1,.3f,.15f,5000,.35f,1,.65f,.7f,.5f,1,1,5,40,1,2,1,18,1,3};
inline float clamp(float x,float lo,float hi){return std::max(lo,std::min(hi,x));}
inline float db(float x){return std::pow(10.f,x/20);}
static_assert(std::atomic<float>::is_always_lock_free,"Audio requires lock-free controls");
struct Ring {
    std::vector<float> data;size_t cursor=0;
    void prepare(size_t n){data.assign(n,0);cursor=0;}
    float read(float delay)const{
        if(data.size()<3)return 0;
        double p=double(cursor)-clamp(delay,1,float(data.size()-2));if(p<0)p+=double(data.size());
        size_t whole=size_t(p),i=whole%data.size(),j=(i+1)%data.size();return data[i]+float(p-double(whole))*(data[j]-data[i]);
    }
    void push(float x){data[cursor]=x;cursor=(cursor+1)%data.size();}
};
struct Biquad {
    float b0=1,b1=0,b2=0,a1=0,a2=0,z1=0,z2=0;
    void peak(float hz,float gain,float rate){
        hz=clamp(hz,10,rate*.43f);float A=std::pow(10.f,gain/40),w=2*pi*hz/rate,alpha=std::sin(w)/1.6f,a0=1+alpha/A;
        b0=(1+alpha*A)/a0;b1=-2*std::cos(w)/a0;b2=(1-alpha*A)/a0;a1=b1;a2=(1-alpha/A)/a0;
    }
    float tick(float x){float y=b0*x+z1;z1=b1*x-a1*y+z2;z2=b2*x-a2*y;return y;}
};
struct LowPass {
    float state=0,coefficient=0;
    void configure(float hz,float rate){coefficient=1-std::exp(-2*pi*std::min(hz,rate*.4f)/rate);}
    float tick(float x){state+=coefficient*(x-state);return state;}
};
struct HighPass {
    float previous=0,state=0,coefficient=0;
    void configure(float hz,float rate){coefficient=std::exp(-2*pi*hz/rate);}
    float tick(float x){state=coefficient*(state+x-previous);previous=x;return state;}
};
struct AcousticComb {
    Ring ring;LowPass damping;float delay=1,feedback=0;
    float tick(float x){float y=ring.read(delay);ring.push(x+damping.tick(y)*feedback);return y;}
};
struct Diffuser {
    Ring ring;float delay=1,gain=.5f;
    float tick(float x){float y=ring.read(delay),out=y-gain*x;ring.push(x+gain*out);return out;}
};
// Fixed taps, no modulation, pitch trackers, detuning or waveshapers.
class AcousticState {
    Controls p=defaults;float rate=48000,env=0,noiseEnv=0,noiseGain=1,attack=0,release=0,slow=0;
    float bodyEnergy=0,edgeEnergy=0,totalEnergy=0,bodyCut=0,edgeCut=0;unsigned counter=0;
    HighPass rumble,reverbLow,delayLow;
    LowPass reverbHigh,delayHigh,bodyLow,bodyHigh,edgeLow,edgeHigh;
    std::array<Biquad,3> eq;Biquad adaptiveBody,adaptiveEdge;Ring pre,echo;
    std::array<std::array<AcousticComb,8>,2> combs;
    std::array<std::array<Diffuser,2>,2> diffusion;
public:
    float reduction=0;
    void prepare(float sampleRate,const Controls &controls){
        rate=sampleRate;env=noiseEnv=bodyEnergy=edgeEnergy=totalEnergy=bodyCut=edgeCut=0;noiseGain=1;counter=0;
        rumble={};reverbLow={};delayLow={};reverbHigh={};delayHigh={};bodyLow={};bodyHigh={};edgeLow={};edgeHigh={};eq={};adaptiveBody={};adaptiveEdge={};
        attack=std::exp(-1/(rate*.02f));release=std::exp(-1/(rate*.18f));slow=1-std::exp(-1/(rate*.5f));
        rumble.configure(55,rate);bodyLow.configure(500,rate);bodyHigh.configure(250,rate);edgeLow.configure(5000,rate);edgeHigh.configure(3000,rate);
        pre.prepare(size_t(rate*.2f)+4);echo.prepare(size_t(rate*5.01f)+4);
        for(auto &channel:combs)for(auto &comb:channel){comb.ring.prepare(size_t(rate*.1f)+4);comb.damping={};}
        for(auto &channel:diffusion)for(auto &d:channel)d.ring.prepare(size_t(rate*.008f)+4);
        configure(controls);
    }
    void configure(const Controls &controls){
        p=controls;eq[0].peak(230,p[Low],rate);eq[1].peak(1500,p[Mid],rate);eq[2].peak(4000,p[High],rate);
        reverbLow.configure(120+40*p[RoomSize],rate);reverbHigh.configure(5000+4000*p[Tone],rate);
        delayLow.configure(180,rate);delayHigh.configure(3500+2500*p[Tone],rate);
        constexpr float times[8]={.0297f,.0371f,.0411f,.0437f,.0313f,.0337f,.0397f,.0479f};
        for(int c=0;c<2;++c){
            for(int k=0;k<8;++k){auto &comb=combs[c][k];comb.delay=rate*(times[k]*(.8f+.5f*p[RoomSize])+c*.0013f);comb.feedback=std::pow(.001f,comb.delay/(rate*p[Decay]));comb.damping.configure(2200+4200*p[Tone],rate);}
            diffusion[c][0].delay=rate*(.005f+c*.0003f);diffusion[c][1].delay=rate*(.0017f+c*.0002f);
            for(auto &d:diffusion[c])d.gain=.45f+.1f*p[RoomSize];
        }
    }
    std::array<float,2> tick(float input){
        float x=rumble.tick(input);const float body=bodyLow.tick(x)-bodyHigh.tick(x),edge=edgeLow.tick(x)-edgeHigh.tick(x);
        bodyEnergy+=slow*(body*body-bodyEnergy);edgeEnergy+=slow*(edge*edge-edgeEnergy);totalEnergy+=slow*(x*x-totalEnergy);
        // Adapt only with small, slow cuts when incoming spectral energy is excessive.
        if((counter++&63)==0){
            float desiredBody=totalEnergy>1e-5f?clamp((bodyEnergy/(totalEnergy+1e-12f)-.22f)*8,0,1.5f):0;
            float desiredEdge=totalEnergy>1e-5f?clamp((edgeEnergy/(totalEnergy+1e-12f)-.15f)*10,0,1.5f):0;
            const float adapt=1-std::exp(-64/(rate*.4f));bodyCut+=adapt*(desiredBody-bodyCut);edgeCut+=adapt*(desiredEdge-edgeCut);
            adaptiveBody.peak(350,-bodyCut,rate);adaptiveEdge.peak(3800,-edgeCut,rate);
        }
        for(auto &filter:eq)x=filter.tick(x);x=adaptiveEdge.tick(adaptiveBody.tick(x));
        float amplitude=std::abs(x),coef=amplitude>env?attack:release;env=coef*env+(1-coef)*amplitude;
        const float over=20*std::log10(std::max(env,1e-9f))+20;
        float knee=over<=-3?0:(over>=3?over:(over+3)*(over+3)/12);
        reduction=p[Compression]>.001f?std::min(4.f,knee*(1-1/(1.5f+p[Compression]))):0;x*=db(-reduction+p[Makeup]);
        noiseEnv+=(1-std::exp(-1/(rate*.08f)))*(amplitude-noiseEnv);
        const float quiet=clamp((-60-20*std::log10(std::max(noiseEnv,1e-9f)))/20,0,1);
        const float desiredNoise=1-.4f*p[Noise]*quiet,noiseTime=desiredNoise>noiseGain?.025f:1.5f;
        noiseGain+=(1-std::exp(-1/(rate*noiseTime)))*(desiredNoise-noiseGain);x*=noiseGain;
        const float delayTap=echo.read(p[DelayTime]*rate*.001f),warmEcho=delayHigh.tick(delayLow.tick(delayTap));echo.push(x+warmEcho*p[Feedback]);
        const float pd=p[Predelay]*rate*.001f,roomInput=pre.read(pd);
        const float earlyL=.45f*pre.read(pd+rate*.011f)+.25f*pre.read(pd+rate*.023f)+.15f*pre.read(pd+rate*.041f);
        const float earlyR=.4f*pre.read(pd+rate*.017f)+.25f*pre.read(pd+rate*.031f)+.15f*pre.read(pd+rate*.047f);pre.push(reverbHigh.tick(reverbLow.tick(x)));
        float rv[2]={0,0};for(int c=0;c<2;++c){for(auto &comb:combs[c])rv[c]+=comb.tick(roomInput)*.125f;for(auto &d:diffusion[c])rv[c]=d.tick(rv[c]);}
        rv[0]=rv[0]*1.2f+earlyL*p[Early];rv[1]=rv[1]*1.2f+earlyR*p[Early];
        float mid=.5f*(rv[0]+rv[1]),side=.5f*(rv[0]-rv[1]);const bool live=p[Live]>.5f;
        const float width=live?std::min(p[Width],.25f):p[Width],echoAmount=live?0:p[Delay];
        // The direct oud remains centred and undelayed. Width affects only ambience.
        return {(x+p[Intensity]*((mid+side*width)*p[Reverb]+warmEcho*echoAmount))*db(p[Trim]),(x+p[Intensity]*((mid-side*width)*p[Reverb]+warmEcho*echoAmount))*db(p[Trim])};
    }
};
class DSP {
    std::array<std::atomic<float>,Count> target;std::atomic<unsigned> revision{0};
    Controls accepted=defaults,current=defaults,profile=defaults;std::array<AcousticState,2> cores;
    int active=0;bool fading=false;float fade=1,fadeStep=0,rate=48000,smoothing=0,limiterGain=1,recordLimiter=1,limiterRelease=0;
    static bool acousticDifference(const Controls &a,const Controls &b){for(int i=0;i<Count;++i)if(i!=Input&&i!=Output&&i!=RecordGain&&i!=Mute&&i!=Bypass&&std::abs(a[i]-b[i])>1e-5f)return true;return false;}
public:
    std::atomic<float> inputPeak{0},outputPeak{0},gainReduction{0},recordPeak{0},recordReduction{0};
    DSP(){for(int i=0;i<Count;++i)target[i].store(defaults[i]);}
    void beginUpdate(){revision.fetch_add(1,std::memory_order_acq_rel);}
    void endUpdate(){revision.fetch_add(1,std::memory_order_release);}
    void set(int p,float value){if(p>=0&&p<Count&&std::isfinite(value))target[p].store(clamp(value,minimum[p],maximum[p]),std::memory_order_relaxed);}
    float get(int p)const{return target[p].load(std::memory_order_relaxed);}
    void prepare(float sampleRate){
        rate=std::isfinite(sampleRate)?clamp(sampleRate,8000,192000):48000;for(int i=0;i<Count;++i)accepted[i]=current[i]=profile[i]=get(i);
        for(auto &core:cores)core.prepare(rate,profile);active=0;fading=false;fade=1;fadeStep=1/(rate*.05f);smoothing=1-std::exp(-1/(rate*.015f));
        current[Output]=-60;limiterGain=recordLimiter=1;limiterRelease=1-std::exp(-1/(rate*.1f));inputPeak=0;outputPeak=0;gainReduction=0;recordPeak=0;recordReduction=0;
    }
    void process(const float *in,float *left,float *right,size_t frames,float *recordLeft=nullptr,float *recordRight=nullptr,const float *backingLeft=nullptr,const float *backingRight=nullptr){
        const unsigned before=revision.load(std::memory_order_acquire);Controls request;for(int p=0;p<Count;++p)request[p]=get(p);
        if(!(before&1)&&revision.load(std::memory_order_acquire)==before)accepted=request;
        // Full-state linear crossfade, two preallocated continuously warm paths.
        // No allocations/locks/clears on the render thread; latest change is coalesced.
        if(!fading&&acousticDifference(accepted,profile)){cores[1-active].configure(accepted);profile=accepted;fading=true;fade=0;}
        float inPeak=0,outPeak=0,recPeak=0,gr=0,recGR=0;
        for(size_t i=0;i<frames;++i){
            for(int p:{Input,Output,RecordGain,Mute,Bypass})current[p]+=smoothing*(accepted[p]-current[p]);
            const float input=std::isfinite(in[i])?clamp(in[i],-4,4):0;inPeak=std::max(inPeak,std::abs(input));const float dry=input*db(current[Input]);
            auto a=cores[active].tick(dry),b=cores[1-active].tick(dry);float mix=fading?fade:0,combined[2];
            for(int c=0;c<2;++c){float enhanced=a[c]*(1-mix)+b[c]*mix;combined[c]=enhanced*(1-current[Bypass])+dry*current[Bypass]+(c==0?(backingLeft?backingLeft[i]:0):(backingRight?backingRight[i]:0));if(!std::isfinite(combined[c]))combined[c]=0;}
            gr=std::max(gr,cores[active].reduction*(1-mix)+cores[1-active].reduction*mix);
            if(fading){fade+=fadeStep;if(fade>=1){active=1-active;fading=false;fade=1;}}
            float rec[2]={combined[0]*db(current[RecordGain]),combined[1]*db(current[RecordGain])};
            float maxRec=std::max(std::abs(rec[0]),std::abs(rec[1])),need=maxRec>.94f?.94f/maxRec:1;
            recordLimiter=need<recordLimiter?need:recordLimiter+limiterRelease*(need-recordLimiter);recGR=std::max(recGR,-20*std::log10(std::max(recordLimiter,1e-9f)));
            if(recordLeft)recordLeft[i]=clamp(rec[0]*recordLimiter,-.98f,.98f);if(recordRight)recordRight[i]=clamp(rec[1]*recordLimiter,-.98f,.98f);recPeak=std::max(recPeak,maxRec*recordLimiter);
            float gain=db(current[Output])*(1-current[Mute]),y[2]={combined[0]*gain,combined[1]*gain},peak=std::max(std::abs(y[0]),std::abs(y[1]));
            need=peak>.94f?.94f/peak:1;limiterGain=need<limiterGain?need:limiterGain+limiterRelease*(need-limiterGain);
            left[i]=clamp(y[0]*limiterGain,-.98f,.98f);right[i]=clamp(y[1]*limiterGain,-.98f,.98f);outPeak=std::max(outPeak,peak*limiterGain);
        }
        inputPeak.store(inPeak);outputPeak.store(outPeak);gainReduction.store(gr);recordPeak.store(recPeak);recordReduction.store(recGR);
    }
};
}
