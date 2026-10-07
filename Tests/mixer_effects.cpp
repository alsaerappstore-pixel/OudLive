#ifdef NDEBUG
#undef NDEBUG
#endif
#include "../OudLive/Audio/DSP.hpp"
#include <cassert>
#include <iostream>

static std::vector<float> render(const std::vector<float>& input,int parameter,float amount,int rate=48000,bool live=true) {
    oud::DSP dsp;
    for(int p:{oud::Input,oud::Output,oud::Low,oud::Mid,oud::High,oud::Compression,oud::Reverb,oud::Noise,oud::Makeup,oud::Delay,oud::Trim})dsp.set(p,0);
    dsp.set(oud::Intensity,1);dsp.set(oud::Live,live?1:0);dsp.set(parameter,amount);dsp.prepare(rate);
    std::vector<float> left(input.size()),right(input.size()),saved(input.size()),savedR(input.size());
    for(size_t i=0;i<input.size();i+=128)dsp.process(input.data()+i,left.data()+i,right.data()+i,std::min(size_t(128),input.size()-i),saved.data()+i,savedR.data()+i);
    for(float x:saved)assert(std::isfinite(x)&&std::abs(x)<=.981f);
    return saved;
}
static double energy(const std::vector<float>& x,size_t begin,size_t end) { double e=0;for(size_t i=begin;i<end;++i)e+=x[i]*x[i];return e+1e-30; }
static std::vector<float> tone(int rate,float amp,float hz,int seconds=3) {
    std::vector<float> x(rate*seconds);for(size_t i=0;i<x.size();++i)x[i]=amp*std::sin(2*oud::pi*hz*i/rate);return x;
}
int main() {
    std::cout<<std::unitbuf;
    for(int rate:{8000,16000,48000,96000}) {
        auto signal=tone(rate,.002f,1000);
        auto clean=render(signal,oud::Noise,0,rate),gated=render(signal,oud::Noise,1,rate);
        double suppression=10*std::log10(energy(clean,rate*2,rate*3)/energy(gated,rate*2,rate*3));assert(suppression>30);
        auto quiet=tone(rate,.015f,440),loud=tone(rate,.25f,440);
        auto q0=render(quiet,oud::Compression,0,rate),l0=render(loud,oud::Compression,0,rate);
        auto q1=render(quiet,oud::Compression,1,rate),l1=render(loud,oud::Compression,1,rate);
        const double before=10*std::log10(energy(l0,rate*2,rate*3)/energy(q0,rate*2,rate*3));
        const double after=10*std::log10(energy(l1,rate*2,rate*3)/energy(q1,rate*2,rate*3));assert(before-after>12);
        auto bass=tone(rate,.03f,230);
        auto low=render(bass,oud::Low,-9,rate),high=render(bass,oud::Low,9,rate);
        const double eq=10*std::log10(energy(high,rate*2,rate*3)/energy(low,rate*2,rate*3));assert(eq>14);
        // Quiet background followed by a strong pluck: gate must reopen promptly.
        auto opening=tone(rate,.002f,1000);for(int i=rate;i<rate*2;++i)opening[i]=.25f*std::sin(2*oud::pi*440*i/rate);
        auto open=render(opening,oud::Noise,1,rate),reference=render(opening,oud::Noise,0,rate);
        double recovery=energy(open,rate+rate/10,rate+rate/5)/energy(reference,rate+rate/10,rate+rate/5);assert(recovery>.9);
        assert(energy(open,rate,rate+rate/100)/energy(reference,rate,rate+rate/100)>.3);
        std::cout<<"PASS "<<rate<<"Hz: noise reduction="<<suppression<<"dB, dynamic span reduced="<<before-after<<"dB, bass sweep="<<eq<<"dB; gate reopens\n";
    }
    for(bool live:{false,true}) {
        const int rate=48000;std::vector<float> pluck(rate*4);
        for(int i=0;i<rate/4;++i)pluck[i]=.12f*std::exp(-float(i)/(rate*.06f))*std::sin(2*oud::pi*330*i/rate);
        auto subtle=render(pluck,oud::Reverb,.3f,rate,live),strong=render(pluck,oud::Reverb,1,rate,live),dry=render(pluck,oud::Reverb,0,rate,live);
        double tailBoost=10*std::log10(energy(strong,rate/2,rate*3)/energy(subtle,rate/2,rate*3));assert(tailBoost>18);
        assert(energy(strong,rate/2,rate*3)>100*energy(dry,rate/2,rate*3));
        std::cout<<"PASS: reverb tail +"<<tailBoost<<"dB vs old maximum; live="<<live<<"\n";
    }
}
