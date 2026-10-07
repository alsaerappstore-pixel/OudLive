#ifdef NDEBUG
#undef NDEBUG
#endif
#include "../OudLive/Audio/DSP.hpp"
#include <fstream>
#include <iostream>
#include <cassert>
int main(){
    std::ifstream recipes("build/recording-presets.txt");assert(recipes.good());
    std::array<oud::Controls,5> controls;
    for(auto &c:controls)for(float &x:c){recipes>>x;assert(!recipes.fail());}
    constexpr int rate=48000,seconds=12,frames=rate*seconds;
    std::vector<float> input(frames),l(frames),r(frames),rl(frames),rr(frames);
    double minEnergy=1e30,maxEnergy=0,minPluck=1e30,maxPluck=0;
    for(int live=0;live<2;++live)for(int preset=0;preset<5;++preset){
        oud::DSP d;for(int p=0;p<oud::Count;++p)d.set(p,controls[preset][p]);d.set(oud::Live,float(live));d.prepare(rate);
        // Quarter-tone test stimulus, settled duration includes more than five seconds.
        const double frequency=220*std::pow(2.,1./24.);
        for(int i=0;i<frames;++i)input[i]=float(.12*std::sin(2*3.141592653589793*frequency*i/rate));
        for(int start=0;start<frames;start+=128)d.process(input.data()+start,l.data()+start,r.data()+start,std::min(128,frames-start),rl.data()+start,rr.data()+start);
        std::vector<double> crossings;std::array<double,seconds> energy{};
        for(int i=1;i<frames;++i){
            assert(std::isfinite(rl[i])&&std::abs(rl[i])<.94f&&std::isfinite(rr[i]));energy[i/rate]+=rl[i]*rl[i];
            if(i>rate*6&&rl[i-1]<=0&&rl[i]>0)crossings.push_back(i-1-rl[i-1]/double(rl[i]-rl[i-1]));
        }
        assert(crossings.size()>100);
        const double measured=(crossings.size()-1)*rate/(crossings.back()-crossings.front());
        const double cents=1200*std::log2(measured/frequency);assert(std::abs(cents)<.1);
        double low=1e30,high=0;for(int sec=4;sec<seconds;++sec){low=std::min(low,energy[sec]);high=std::max(high,energy[sec]);assert(energy[sec]>.1);}
        assert(high/low<1.03);assert(d.gainReduction.load()<=4.001f);
        double e=energy[10];minEnergy=std::min(minEnergy,e);maxEnergy=std::max(maxEnergy,e);
        std::cout<<"Profile "<<preset<<" live="<<live<<" pitchErrorCents="<<cents<<" steadyEnergy="<<e<<"\n";
        d.prepare(rate);
        for(int i=0;i<frames;++i){
            double t=double(i)/rate,age=std::fmod(t,.25),attack=std::min(1.,age/.002);
            double string=0;for(int h=1;h<=12;++h)string+=std::sin(2*3.141592653589793*113.223246*h*t)/std::pow(h,1.4);
            input[i]=float(.15*attack*std::exp(-age*8)*string);
        }
        double pluckEnergy=0;
        for(int start=0;start<frames;start+=128)d.process(input.data()+start,l.data()+start,r.data()+start,std::min(128,frames-start),rl.data()+start,rr.data()+start);
        for(int i=rate*4;i<frames;++i){assert(std::isfinite(rl[i])&&std::abs(rl[i])<.94f);pluckEnergy+=rl[i]*rl[i];}
        assert(pluckEnergy>1);minPluck=std::min(minPluck,pluckEnergy);maxPluck=std::max(maxPluck,pluckEnergy);
    }
    const double spread=10*std::log10(maxEnergy/minEnergy);assert(spread<2.5);
    const double pluckSpread=10*std::log10(maxPluck/minPluck);assert(pluckSpread<2.5);
    std::cout<<"PASS: 12-second articulated harmonic string stimulus, no clipping; level spread "<<pluckSpread<<" dB\n";
    std::cout<<"PASS: exactly five profiles, 12 seconds each in both live modes, quarter-tone error <0.1 cent, steady levels and loudness spread "<<spread<<" dB on reference tone\n";
}
