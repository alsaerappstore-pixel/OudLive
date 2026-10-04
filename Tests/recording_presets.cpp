#include "../OudLive/Audio/DSP.hpp"
#include <fstream>
#include <iostream>
#include <cassert>
#include <memory>
int main() {
    std::ifstream recipes("build/recording-presets.txt"); assert(recipes.good());
    constexpr int rate=48000, frames=rate*6;
    std::vector<float> dry(frames),left(frames),right(frames),wetL(frames),wetR(frames);
    // A repeatable plucked-string-like stimulus followed by silence for tail checks.
    for(int i=0;i<rate*2;++i) {
        double t=double(i)/rate, age=std::fmod(t,.4);
        dry[i]=float(.14*std::exp(-age*9)*(std::sin(2*oud::pi*220*t)+.45*std::sin(2*oud::pi*440*t)+.2*std::sin(2*oud::pi*1760*t)));
    }
    std::vector<std::vector<float>> outputs;
    for(int preset=0;preset<15;++preset) {
        auto dsp=std::make_unique<oud::DSP>(); dsp->prepare(rate);
        for(int p=0;p<oud::Count;++p) { float value; assert(bool(recipes>>value)); dsp->set(p,value); }
        std::vector<float> silence(rate,0), a(rate), b(rate); dsp->process(silence.data(),a.data(),b.data(),rate);
        dsp->process(dry.data(),left.data(),right.data(),frames,wetL.data(),wetR.data());
        double energy=0; float peak=0;
        for(int i=0;i<frames;++i) { assert(std::isfinite(wetL[i])&&std::isfinite(wetR[i])); peak=std::max(peak,std::max(std::abs(wetL[i]),std::abs(wetR[i]))); energy+=double(wetL[i])*wetL[i]; }
        assert(energy>1 && peak<.95f);
        outputs.push_back(wetL);
        std::cout<<"Preset "<<preset+1<<": peak="<<peak<<", energy="<<energy<<"\n";
    }
    double closest=1;
    for(int i=0;i<15;++i) for(int j=0;j<i;++j) {
        double aa=0,bb=0,ab=0;
        for(int k=0;k<frames;++k) { aa+=double(outputs[i][k])*outputs[i][k]; bb+=double(outputs[j][k])*outputs[j][k]; ab+=double(outputs[i][k])*outputs[j][k]; }
        double difference=std::sqrt(std::max(0.0,2-2*ab/std::sqrt(aa*bb)));
        closest=std::min(closest,difference); assert(difference>.015);
    }
    std::cout<<"PASS: 15 recipes rendered finite, non-silent, unclipped and pairwise different after level normalization; smallest difference="<<closest<<"\n";
}
