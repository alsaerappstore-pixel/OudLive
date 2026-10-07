#pragma once
#include "RhythmPatterns.hpp"
#include <atomic>
#include <vector>
#include <array>
#include <fstream>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <string>

namespace oud {
// Recorded one-shots sequenced by the audio sample clock. No allocations, locks,
// filesystem access or UI timers in render(). loadBank/prepare require stopped IO.
class RhythmEngine {
    struct Voice { int sample=-1; size_t position=0; float gain=0, release=1; bool fading=false; };
    std::array<std::vector<float>,18> original, samples;
    std::array<Voice,64> voices{};
    std::array<unsigned,6> roundRobin{};
    std::atomic<int> requested{-1};
    std::atomic<bool> enabled{false};
    std::atomic<float> tempo{100}, volume{.45f};
    std::atomic<float> phaseMeter{0};
    int active=-1;
    bool playing=false, loaded=false;
    double rate=48000, phase=0;
    int lastStep=-1;
    float level=0;
    uint64_t triggers=0;
    void releaseVoices() { for(auto &v:voices) if(v.sample>=0) v.fading=true; }
    void hit(int instrument,float gain) {
        auto slot=std::find_if(voices.begin(),voices.end(),[](const Voice &v){return v.sample<0;});
        if(slot==voices.end()) return; // bounded voice budget; never allocate on RT
        int sample=instrument*3+int(roundRobin[instrument]++%3);
        *slot={sample,0,gain,1,false}; ++triggers;
    }
public:
    bool loadBank(const char *path) {
        loaded=false;
        for(size_t index=0;index<original.size();++index) {
            auto &sample=original[index];
            std::ifstream file(std::string(path)+"/sample-"+std::to_string(index)+".pcm",std::ios::binary);
            uint32_t n=0; file.read(reinterpret_cast<char*>(&n),4);
            if(!file || n<16 || n>48000) return false;
            sample.resize(n); file.read(reinterpret_cast<char*>(sample.data()),n*sizeof(float));
            if(!file) return false;
            for(float x:sample) if(!std::isfinite(x) || std::abs(x)>1) return false;
        }
        loaded=true; return true;
    }
    bool ready() const { return loaded; }
    void prepare(double sampleRate) {
        rate=std::isfinite(sampleRate)?std::clamp(sampleRate,8000.0,192000.0):48000;
        // Offline band-limited resampling also covers narrow-band Bluetooth HFP.
        for(size_t s=0;s<samples.size();++s) {
            const auto &input=original[s]; auto &output=samples[s];
            output.assign(size_t(std::ceil(input.size()*rate/24000)),0);
            const double cutoff=.45*std::min(1.0,rate/24000), pi=3.141592653589793;
            for(size_t i=0;i<output.size();++i) {
                const double position=i*24000/rate; const int center=int(position);
                double sum=0,weights=0;
                for(int k=-24;k<=24;++k) {
                    const int index=center+k; const double distance=position-index;
                    const double z=2*cutoff*distance;
                    const double sinc=std::abs(z)<1e-10?1:std::sin(pi*z)/(pi*z);
                    const double window=.5+.5*std::cos(pi*distance/25);
                    const double weight=2*cutoff*sinc*window;
                    if(index>=0 && size_t(index)<input.size()) sum+=input[index]*weight;
                    weights+=weight;
                }
                output[i]=float(sum/weights);
            }
        }
        voices={}; roundRobin={}; active=-1; playing=false; phase=0; lastStep=-1; level=0; triggers=0; phaseMeter.store(0);
    }
    void select(int index) { requested.store(index>=0 && index<rhythmCount?index:-1,std::memory_order_relaxed); }
    void setPlaying(bool value) { enabled.store(value,std::memory_order_relaxed); }
    void setTempo(float value) { if(std::isfinite(value)) tempo.store(std::clamp(value,40.f,220.f),std::memory_order_relaxed); }
    void setVolume(float value) { if(std::isfinite(value)) volume.store(std::clamp(value,0.f,1.f),std::memory_order_relaxed); }
    float position() const { return phaseMeter.load(std::memory_order_relaxed); }
    uint64_t debugTriggers() const { return triggers; } // stopped/offline tests only
    void render(float *left,float *right,size_t frames) {
        const int selected=requested.load(std::memory_order_relaxed);
        const bool run=loaded && enabled.load(std::memory_order_relaxed) && selected>=0;
        if(active!=selected || playing!=run) {
            releaseVoices(); active=selected; playing=run; phase=0; lastStep=-1;
        }
        const double increment=tempo.load(std::memory_order_relaxed)*4/(60*rate);
        const float target=volume.load(std::memory_order_relaxed);
        const float smooth=float(1-std::exp(-1/(rate*.015)));
        const float releaseStep=float(1/(rate*.008));
        constexpr float pan[6]={0,.12f,-.12f,0,-.3f,.3f};
        for(size_t i=0;i<frames;++i) {
            if(run) {
                const auto &pattern=rhythmPatterns[active];
                const int step=std::min(int(phase),pattern.count-1);
                if(step!=lastStep) {
                    for(int v=0;v<6;++v) if(pattern.steps[step].gain[v]>0) hit(v,pattern.steps[step].gain[v]);
                    lastStep=step;
                }
                phase+=increment;
                if(phase>=pattern.count) { phase-=pattern.count; lastStep=-1; }
            }
            level+=smooth*(target-level);
            float l=0,r=0;
            for(auto &voice:voices) {
                if(voice.sample<0) continue;
                const auto &sample=samples[size_t(voice.sample)];
                if(voice.position>=sample.size()) { voice.sample=-1; continue; }
                const float x=sample[voice.position++]*voice.gain*voice.release;
                const float p=pan[voice.sample/3]; l+=x*(1-p); r+=x*(1+p);
                if(voice.fading) { voice.release-=releaseStep; if(voice.release<=0) voice.sample=-1; }
            }
            left[i]=l*level*.65f; right[i]=r*level*.65f;
        }
        phaseMeter.store(run?float(phase/rhythmPatterns[active].count):0,std::memory_order_relaxed);
    }
};
}
