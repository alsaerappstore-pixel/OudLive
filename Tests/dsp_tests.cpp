#ifdef NDEBUG
#undef NDEBUG
#endif
#include "../OudLive/Audio/DSP.hpp"
#include <cassert>
#include <iostream>
#include <limits>
#include <cstdlib>
#include <new>
static bool rendering=false;static size_t allocations=0;
void* operator new(std::size_t n){if(rendering)++allocations;if(void *p=std::malloc(n))return p;throw std::bad_alloc();}
void operator delete(void *p)noexcept{std::free(p);}
void operator delete(void *p,std::size_t)noexcept{std::free(p);}
static void neutral(oud::DSP &d){d.set(oud::Input,0);d.set(oud::Output,0);d.set(oud::RecordGain,0);}
int main(){
    for(int rate:{8000,16000,24000,44100,48000,96000}){
        oud::DSP d;neutral(d);d.prepare(float(rate));
        std::vector<float> x(128),l(128),r(128),recL(128),recR(128);
        double energy=0;float previous=0,maxStep=0;
        for(int frame=0;frame<rate*7;frame+=128){
            if(frame/128%113==0){d.beginUpdate();d.set(oud::Reverb,(frame/128%2)?.25f:.02f);d.set(oud::Decay,(frame/128%2)?2.3f:.8f);d.set(oud::Low,(frame/128%2)?1.5f:-.5f);d.endUpdate();}
            for(int i=0;i<128;++i)x[i]=.1f*std::sin(2*oud::pi*226.4465f*(frame+i)/rate);
            rendering=true;d.process(x.data(),l.data(),r.data(),128,recL.data(),recR.data());rendering=false;
            for(int i=0;i<128;++i){assert(std::isfinite(recL[i])&&std::abs(recL[i])<.94f);energy+=recL[i]*recL[i];maxStep=std::max(maxStep,std::abs(recL[i]-previous));previous=recL[i];}
            assert(d.gainReduction.load()<=4.001f);
        }
        const float expectedSineStep=.4f*std::sin(oud::pi*226.4465f/rate)+.005f;
        assert(energy>10&&maxStep<expectedSineStep&&allocations==0);
        d.set(oud::Mute,1);for(int block=0;block<500;++block)d.process(x.data(),l.data(),r.data(),128,recL.data(),recR.data());
        double saved=0;for(int i=0;i<128;++i){assert(std::abs(l[i])<1e-5);saved+=recL[i]*recL[i];}assert(saved>.001);
        d.set(oud::Input,24);d.set(oud::RecordGain,18);
        for(int i=0;i<128;++i)x[i]=(i%3==0)?std::numeric_limits<float>::quiet_NaN():4.f;
        for(int block=0;block<100;++block)d.process(x.data(),l.data(),r.data(),128,recL.data(),recR.data());
        for(float v:recL)assert(std::isfinite(v)&&std::abs(v)<=.981f);
        std::cout<<"PASS: 7-second switching, no RT allocations, bounded protection and independent recording at "<<rate<<" Hz\n";
    }
    // Closing the hardware monitor must silence only playback, never the recording.
    for(int rate:{8000,16000,48000,96000}) {
        oud::DSP gate; gate.set(oud::Input,0);gate.set(oud::Output,0);gate.set(oud::Mute,0);gate.set(oud::Bypass,1);gate.prepare(rate);
        float in[64],left[64],right[64],savedL[64],savedR[64];
        std::fill(in,in+64,.1f);
        gate.process(in,left,right,64,savedL,savedR,false);
        for(int i=0;i<64;++i) { assert(left[i]==0 && right[i]==0);assert(std::abs(savedL[i]-.1f)<1e-6f); }
        gate.process(in,left,right,64,savedL,savedR,true);
        assert(left[63]>0 && right[63]>0);
        for(int i=0;i<64;++i) assert(std::abs(savedL[i]-.1f)<1e-6f);
    }
    std::cout<<"PASS: hardware monitor gating leaves recording unchanged at phone/headset rates\n";
    // Five-second delay capability affects the wet tap, never the direct onset.
    oud::DSP d;neutral(d);d.set(oud::Live,0);d.set(oud::DelayTime,5000);d.set(oud::Delay,.15);d.set(oud::Feedback,0);d.set(oud::Reverb,0);d.set(oud::Compression,0);d.set(oud::Noise,0);d.prepare(48000);
    std::vector<float>x(48000*6),l(x.size()),r(x.size()),recL(x.size()),recR(x.size());x[0]=.2f;
    d.process(x.data(),l.data(),r.data(),x.size(),recL.data(),recR.data());
    assert(std::abs(recL[0])>.1f);double delayed=0;for(int i=240000;i<245000;++i)delayed+=recL[i]*recL[i];assert(delayed>1e-5);
    std::cout<<"PASS: 5-second echo storage with immediate original onset and filtered late echo\n";
    // A quiet decaying note never meets a hard zero-valued gate.
    d.set(oud::Noise,.5);d.set(oud::Delay,0);d.prepare(48000);
    for(size_t i=0;i<x.size();++i)x[i]=float(.002*std::exp(-double(i)/48000)*std::sin(2*oud::pi*220*i/48000));
    d.process(x.data(),l.data(),r.data(),x.size(),recL.data(),recR.data());
    double tail=0;for(int i=200000;i<240000;++i)tail+=recL[i]*recL[i];assert(tail>1e-10);
    std::cout<<"PASS: soft expansion preserves quiet decaying resonance\n";
}
