#include "../OudLive/Audio/LoopPlayer.hpp"
#include "../OudLive/Audio/DSP.hpp"
#include <cassert>
#include <iostream>
int main(){
    oud::LoopPlayer player;
    auto clip=std::make_unique<oud::LoopPlayer::Clip>();clip->sampleRate=48000;
    for(int i=0;i<4800;++i){clip->left.push_back(.2f*std::sin(i*.03));clip->right.push_back(.1f*std::cos(i*.05));}
    auto original=clip->left;player.replace(std::move(clip));player.volume=1;player.playing=true;
    std::vector<float> l(9600),r(9600),mic(9600,0),ml(9600),mr(9600),rl(9600),rr(9600);
    player.render(l.data(),r.data(),l.size(),48000);
    for(int i=7200;i<9600;++i)assert(std::abs(l[i]-original[i%4800])<1e-5);
    oud::DSP dsp;dsp.set(oud::Output,0);dsp.prepare(48000);
    dsp.process(mic.data(),ml.data(),mr.data(),mic.size(),rl.data(),rr.data(),false,l.data(),r.data(),false);
    float peak=0;for(int i=0;i<9600;++i){assert(rl[i]==0&&rr[i]==0);peak=std::max(peak,std::abs(ml[i]));}assert(peak>.1);
    dsp.process(mic.data(),ml.data(),mr.data(),mic.size(),rl.data(),rr.data(),false,l.data(),r.data(),true);
    for(int i=0;i<9600;++i){assert(std::abs(rl[i]-l[i])<1e-6);assert(std::abs(rr[i]-r[i])<1e-6);}
    for(float rate:{8000.f,16000.f,44100.f,48000.f,96000.f})for(float speed:{.5f,1.f,2.f}){
        player.speed=speed;player.render(l.data(),r.data(),l.size(),rate);
        for(auto value:l)assert(std::isfinite(value)&&std::abs(value)<.201f);
    }
    // Peak protection is applied after summing the original loop and oud.
    std::fill(l.begin(),l.end(),2);std::fill(r.begin(),r.end(),-2);
    dsp.process(mic.data(),ml.data(),mr.data(),mic.size(),rl.data(),rr.data(),true,l.data(),r.data(),true);
    for(int i=0;i<9600;++i)assert(std::abs(rl[i])<=.941f&&std::abs(ml[i])<=.941f);
    player.playing=false;player.render(l.data(),r.data(),l.size(),48000);
    assert(std::abs(l.back())<1e-6);
    player.replace(nullptr);player.render(l.data(),r.data(),l.size(),48000);for(auto v:l)assert(v==0);
    std::cout<<"PASS original PCM at 100%, looping, variable rate, live without mic monitoring, record inclusion/exclusion, final peak protection, stop and replace\n";
}
