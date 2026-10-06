#ifdef NDEBUG
#undef NDEBUG
#endif
#include "../OudLive/Audio/DSP.hpp"
#include <cassert>
#include <iostream>
#include <limits>
#include <random>

static void flat(oud::DSP &d) {
    for(int i=0;i<oud::Count;++i) d.set(i,oud::defaults[i]);
    d.set(oud::Input,0); d.set(oud::Output,0); d.set(oud::Compression,0); d.set(oud::Reverb,0);
    d.set(oud::Makeup,0); d.set(oud::Delay,0);
}
static void settle(oud::DSP &d, int frames=12000) {
    std::vector<float> z(frames),l(frames),r(frames); d.process(z.data(),l.data(),r.data(),z.size());
}
static double sineRMS(oud::DSP &d,float hz,float amplitude=0.2f) {
    constexpr int n=48000; std::vector<float>x(n),l(n),r(n);
    for(int i=0;i<n;++i)x[i]=amplitude*std::sin(2*oud::pi*hz*i/48000);
    d.process(x.data(),l.data(),r.data(),n);
    double sum=0; for(int i=n/2;i<n;++i)sum+=l[i]*l[i]; return std::sqrt(sum/(n/2));
}
int main() {
    {
        oud::Ring ring; ring.prepare(3844); ring.cursor=2;
        ring.data[0]=8; ring.data.back()=4;
        float value=ring.read(std::nextafter(2.f,3.f));
        assert(std::isfinite(value) && std::abs(value-8.f)<.001f);
        std::cout<<"PASS: fractional delay wrap remains in bounds near the first sample\n";
    }
    {
        oud::DSP d; flat(d); d.set(oud::Bypass,1); d.prepare(48000); settle(d);
        float x[4]={.2f,-.4f,0,.1f},l[4],r[4]; d.process(x,l,r,4);
        for(int i=0;i<4;++i) { assert(std::abs(l[i]-x[i])<1e-4); assert(l[i]==r[i]); }
        std::cout<<"PASS: dry bypass has no added sample delay\n";
    }
    {
        oud::DSP dry,boost; flat(dry); flat(boost); boost.set(oud::Low,6);
        dry.prepare(48000); boost.prepare(48000);
        double ratio=sineRMS(boost,180)/sineRMS(dry,180);
        assert(ratio>1.9 && ratio<2.1);
        std::cout<<"PASS: low EQ +6 dB measured at 180 Hz\n";
    }
    {
        oud::DSP dry,compressed; flat(dry); flat(compressed); compressed.set(oud::Compression,1);
        dry.prepare(48000); compressed.prepare(48000);
        assert(sineRMS(compressed,1000,.7f)<sineRMS(dry,1000,.7f)*.25);
        std::cout<<"PASS: compressor reduces a sustained loud tone\n";
    }
    {
        oud::DSP d; flat(d); d.set(oud::Delay,0.5f); d.set(oud::Feedback,0); d.set(oud::DelayTime,100);
        d.prepare(48000); settle(d);
        std::vector<float>x(10000),l(10000),r(10000); x[0]=.5f; d.process(x.data(),l.data(),r.data(),x.size());
        assert(l[0]>.45 && l[4800]>.20 && std::abs(l[9600])<.01);
        std::cout<<"PASS: first echo at 100 ms and zero feedback prevents repeats\n";
    }
    {
        oud::DSP d; flat(d); d.set(oud::Reverb,.7f); d.prepare(48000); settle(d);
        std::vector<float>x(48000),l(48000),r(48000); x[0]=.5;
        d.process(x.data(),l.data(),r.data(),x.size());
        double tail=0,stereo=0; for(size_t i=4800;i<x.size();++i) { tail+=l[i]*l[i]; stereo+=std::abs(l[i]-r[i]); }
        assert(tail>1e-6 && stereo>1e-3);
        std::cout<<"PASS: reverb has a decaying stereo tail\n";
    }
    for(int variant=0;variant<3;++variant) {
        oud::DSP d; flat(d); d.set(variant==2?oud::Doubler:oud::Modulation,.6f);
        d.set(oud::Flanger,variant==1?1:0); d.prepare(48000);
        std::vector<float>x(48000),l(48000),r(48000);
        for(size_t i=0;i<x.size();++i)x[i]=.2f*std::sin(2*oud::pi*440*i/48000);
        d.process(x.data(),l.data(),r.data(),x.size());
        double difference=0; for(size_t i=4800;i<x.size();++i)difference+=std::abs(l[i]-r[i]);
        assert(difference>1);
        std::cout<<"PASS: "<<(variant==0?"chorus":variant==1?"flanger":"doubler")<<" produces independent stereo voices\n";
    }
    for(float rate:{8000.f,16000.f,24000.f,32000.f,44100.f,48000.f,96000.f}) {
        oud::DSP d; for(int p=0;p<oud::Count;++p)d.set(p,oud::maximum[p]);
        d.set(oud::Mute,0); d.set(oud::Bypass,0); d.prepare(rate);
        std::mt19937 random(42); std::uniform_real_distribution<float> dist(-2,2);
        std::array<float,257>x,l,r;
        for(int block=0;block<400;++block) {
            for(auto &v:x)v=dist(random);
            x[0]=std::numeric_limits<float>::quiet_NaN();
            d.process(x.data(),l.data(),r.data(),x.size());
            for(size_t i=0;i<x.size();++i) assert(std::isfinite(l[i]) && std::isfinite(r[i]) && std::abs(l[i])<=.98f && std::abs(r[i])<=.98f);
        }
        d.set(oud::Mute,1); settle(d,24000);
        x.fill(.9f); d.process(x.data(),l.data(),r.data(),x.size());
        for(float v:l)assert(std::abs(v)<.0001);
        d.set(oud::Input,std::numeric_limits<float>::infinity()); assert(d.get(oud::Input)==30);
        std::cout<<"PASS: bounded output, NaN rejection, mute at "<<rate<<" Hz\n";
    }
    {
        oud::DSP base,boost; flat(base); flat(boost); boost.set(oud::Input,12);
        base.prepare(48000); boost.prepare(48000);
        double ratio=sineRMS(boost,1000,.01f)/sineRMS(base,1000,.01f);
        assert(ratio>3.9 && ratio<4.1);
        std::cout<<"PASS: +12 dB capture boost raises quiet input by four times\n";
    }
    {
        oud::DSP base,boost; flat(base); flat(boost); boost.set(oud::Makeup,6);
        base.prepare(48000); boost.prepare(48000);
        double ratio=sineRMS(boost,1000,.03f)/sineRMS(base,1000,.03f);
        assert(ratio>1.9 && ratio<2.1);
        std::cout<<"PASS: independent compressor makeup restores output level\n";
    }
    {
        auto lateEnergy=[](float seconds) {
            oud::DSP d; flat(d); d.set(oud::Decay,seconds); d.set(oud::Reverb,1); d.prepare(48000); settle(d);
            std::vector<float>x(144000),l(144000),r(144000); x[0]=.4f;
            d.process(x.data(),l.data(),r.data(),x.size());
            double energy=0; for(size_t i=48000;i<x.size();++i) energy+=l[i]*l[i]+r[i]*r[i]; return energy;
        };
        assert(lateEnergy(6)>lateEnergy(.5f)*100);
        std::cout<<"PASS: long decay produces a measurably longer reverb tail\n";
    }
    {
        oud::DSP dry,wet; flat(dry); flat(wet); wet.set(oud::Reverb,1); wet.set(oud::Predelay,80);
        dry.prepare(48000); wet.prepare(48000); settle(dry); settle(wet);
        std::vector<float>x(12000),a(12000),b(12000),c(12000),e(12000); x[0]=.4;
        dry.process(x.data(),a.data(),b.data(),x.size()); wet.process(x.data(),c.data(),e.data(),x.size());
        for(size_t i=0;i<3840;++i) assert(std::abs(a[i]-c[i])<1e-5);
        double delta=0; for(size_t i=3840;i<x.size();++i)delta+=std::abs(a[i]-c[i]); assert(delta>.01);
        std::cout<<"PASS: predelay keeps reverb behind the initial pick attack\n";
    }
    {
        oud::DSP d; flat(d); d.set(oud::Input,30); d.prepare(48000); settle(d);
        sineRMS(d,1000,.5);
        assert(d.gainReduction.load()>10 && d.outputPeak.load()<=.941f);
        settle(d,48000);
        double recovered=sineRMS(d,1000,.001f);
        assert(recovered>.02 && recovered<.024);
        std::cout<<"PASS: linked limiter bounds peaks and recovers after overload\n";
    }
    {
        oud::DSP dry,wet; flat(dry); flat(wet); wet.set(oud::Reverb,1); wet.set(oud::Delay,1); wet.set(oud::Modulation,1); wet.set(oud::Intensity,0);
        dry.prepare(48000); wet.prepare(48000);
        assert(std::abs(sineRMS(dry,880)-sineRMS(wet,880))<1e-6);
        std::cout<<"PASS: global effects intensity zero removes all wet contributions\n";
    }
    {
        oud::DSP a,b; flat(a); flat(b); a.set(oud::Output,-30); a.set(oud::Mute,1);
        a.prepare(48000); b.prepare(48000);
        std::vector<float>x(48000),l(48000),r(48000),al(48000),ar(48000),bl(48000),br(48000);
        for(size_t i=0;i<x.size();++i)x[i]=.05f*std::sin(2*oud::pi*440*i/48000.f);
        a.process(x.data(),l.data(),r.data(),x.size(),al.data(),ar.data());
        for(float v:l) assert(v==0);
        b.process(x.data(),l.data(),r.data(),x.size(),bl.data(),br.data());
        double energy=0;
        for(size_t i=0;i<x.size();++i) { assert(std::abs(al[i]-bl[i])<1e-7f); energy+=al[i]*al[i]; }
        assert(energy>1);
        std::cout<<"PASS: recording stays audible and identical with monitor mute or reduced headphone level\n";
    }
    {
        oud::DSP a,b; flat(a); flat(b); b.set(oud::RecordGain,6); a.prepare(48000); b.prepare(48000);
        std::vector<float>x(12000,.01f),l(12000),r(12000),al(12000),ar(12000),bl(12000),br(12000);
        a.set(oud::Bypass,1); b.set(oud::Bypass,1);
        a.process(x.data(),l.data(),r.data(),x.size(),al.data(),ar.data());
        b.process(x.data(),l.data(),r.data(),x.size(),bl.data(),br.data());
        assert(bl.back()/al.back()>1.99f && bl.back()/al.back()<2.0f);
        b.set(oud::Input,30); b.set(oud::RecordGain,18); std::fill(x.begin(),x.end(),1.f);
        b.process(x.data(),l.data(),r.data(),x.size(),bl.data(),br.data());
        for(float v:bl) assert(std::isfinite(v) && std::abs(v)<=.941f);
        std::cout<<"PASS: separate recording gain amplifies correctly and limits excessive peaks\n";
    }
    for(float rate:{8000.f,16000.f,24000.f,32000.f}) {
        // The high EQ center used to exceed Nyquist at 8 kHz and became unstable.
        oud::Biquad eq; eq.peak(4800,12,rate);
        double tail=0;
        for(int i=0;i<int(rate);++i) {
            float v=eq.tick(i==0 ? .1f : 0.f);
            assert(std::isfinite(v) && std::abs(v)<1.f);
            if(i>int(rate)/2) tail+=double(v)*v;
        }
        assert(tail<1e-8);
        oud::DSP dry,wet; flat(dry); flat(wet); wet.set(oud::Reverb,.8f); wet.set(oud::Delay,.7f);
        dry.prepare(rate); wet.prepare(rate);
        double energy=0,difference=0;
        std::array<float,128>x,l,r,a,b;
        for(int block=0;block<200;++block) {
            for(size_t i=0;i<x.size();++i) x[i]=.1f*std::sin(2*oud::pi*440*(block*128+i)/rate);
            dry.process(x.data(),a.data(),b.data(),x.size()); wet.process(x.data(),l.data(),r.data(),x.size());
            for(size_t i=0;i<x.size();++i) { energy+=l[i]*l[i]; difference+=std::abs(l[i]-a[i]); }
        }
        assert(energy>1 && difference>1);
        std::cout<<"PASS: HFP-rate EQ is stable and live effects remain audible at "<<rate<<" Hz without recording\n";
    }
    for(float rate:{8000.f,16000.f,48000.f}) {
        oud::DSP d; flat(d); d.set(oud::Low,8); d.set(oud::High,-8);
        d.set(oud::Reverb,1); d.set(oud::Delay,1); d.set(oud::Feedback,.7f); d.set(oud::Modulation,.8f);
        d.prepare(rate);
        std::vector<float>x(int(rate),.04f),l(x.size()),r(x.size()),rl(x.size()),rr(x.size());
        d.process(x.data(),l.data(),r.data(),x.size(),rl.data(),rr.data());
        d.set(oud::Bypass,1);
        std::fill(x.begin(),x.end(),0); d.process(x.data(),l.data(),r.data(),x.size(),rl.data(),rr.data());
        for(size_t i=0;i<x.size();++i) x[i]=.02f+.03f*std::sin(2*oud::pi*25*i/rate)+.05f*std::sin(2*oud::pi*440*i/rate);
        d.process(x.data(),l.data(),r.data(),x.size(),rl.data(),rr.data());
        for(size_t i=0;i<x.size();++i) {
            assert(std::abs(l[i]-x[i])<1e-6f && std::abs(r[i]-x[i])<1e-6f);
            assert(std::abs(rl[i]-x[i])<1e-6f && std::abs(rr[i]-x[i])<1e-6f);
        }
        std::cout<<"PASS: switching wet to raw removes filter coloration and effect tails from monitor and recording at "<<rate<<" Hz\n";
    }
    std::cout<<"All DSP checks passed. Device latency and iOS integration still require hardware testing.\n";
}
