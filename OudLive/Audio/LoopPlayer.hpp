#pragma once
#include <atomic>
#include <vector>
#include <memory>
#include <thread>
#include <cmath>
#include <algorithm>

namespace oud {
// File decoding and ownership changes happen off the audio callback. Reader
// fencing prevents freeing a clip until the callback has relinquished it.
class LoopPlayer {
public:
    struct Clip { std::vector<float> left,right; double sampleRate=44100; };
    std::atomic<bool> playing{false},recordEnabled{true};
    std::atomic<float> speed{1},volume{.65f};
private:
    std::unique_ptr<Clip> owned;
    std::atomic<Clip*> published{nullptr};
    std::atomic<unsigned> readers{0},revision{0};
    unsigned seen=0; double position=0; float gain=0;
public:
    void replace(std::unique_ptr<Clip> clip) {
        published.store(nullptr);
        while(readers.load()!=0) std::this_thread::yield();
        owned=std::move(clip);revision.fetch_add(1);
        published.store(owned.get());
    }
    void render(float *left,float *right,size_t count,double outputRate) {
        readers.fetch_add(1);
        Clip *clip=published.load();
        const unsigned version=revision.load();
        if(version!=seen){seen=version;position=0;gain=0;}
        const bool valid=clip&&!clip->left.empty()&&clip->left.size()==clip->right.size();
        float s=speed.load(),v=volume.load();
        s=std::isfinite(s)?std::clamp(s,.5f,2.f):1;
        v=std::isfinite(v)?std::clamp(v,0.f,1.f):0;
        const float target=playing.load()&&valid?v:0;
        outputRate=std::isfinite(outputRate)&&outputRate>0?outputRate:48000;
        const float smoothing=1-std::exp(-1.f/float(outputRate*.005));
        for(size_t i=0;i<count;++i) {
            left[i]=right[i]=0;gain+=smoothing*(target-gain);
            if(!valid||gain<1e-7f)continue;
            const size_t n=clip->left.size(),a=size_t(position)%n,b=(a+1)%n;
            const float f=float(position-std::floor(position));
            left[i]=(clip->left[a]+f*(clip->left[b]-clip->left[a]))*gain;
            right[i]=(clip->right[a]+f*(clip->right[b]-clip->right[a]))*gain;
            position=std::fmod(position+s*clip->sampleRate/outputRate,double(n));
        }
        readers.fetch_sub(1);
    }
};
}
