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
    oud::LoopPlayer muted;auto clockClip=std::make_unique<oud::LoopPlayer::Clip>();
    clockClip->sampleRate=48000;clockClip->left=original;clockClip->right=original;
    muted.replace(std::move(clockClip));muted.playing=true;muted.volume=0;
    muted.render(l.data(),r.data(),1280,48000);for(int i=0;i<1280;++i)assert(l[i]==0);
    muted.volume=1;muted.render(l.data(),r.data(),9600,48000);
    assert(std::abs(l.back()-original[(1280+9599)%4800])<1e-5);
    // Channel faders must affect live preview and the file in equal proportions.
    for(float amount:{0.f,.25f,1.f,2.f}) {
        oud::DSP mix;mix.set(oud::Input,0);mix.set(oud::Output,0);mix.set(oud::Bypass,1);mix.set(oud::RecordGain,6);mix.setOudVolume(amount);mix.prepare(48000);
        std::fill(mic.begin(),mic.end(),.04f);std::fill(l.begin(),l.end(),.025f);std::fill(r.begin(),r.end(),.025f);
        mix.process(mic.data(),ml.data(),mr.data(),mic.size(),rl.data(),rr.data(),true,l.data(),r.data(),true);
        const float expected=.04f*std::pow(10.f,6.f/20.f)*amount+.025f;
        assert(std::abs(rl.back()-expected)<1e-5 && std::abs(ml.back()-expected)<1e-4);
        mix.process(mic.data(),ml.data(),mr.data(),mic.size(),rl.data(),rr.data(),false,l.data(),r.data(),false);
        assert(std::abs(rl.back()-(expected-.025f))<1e-5 && std::abs(ml.back()-.025f)<1e-4);
        mix.setOudVolume(0);mix.process(mic.data(),ml.data(),mr.data(),mic.size(),rl.data(),rr.data(),true,l.data(),r.data(),true);
        assert(std::abs(rl.back()-.025f)<1e-5);
    }
    // Speaker accompaniment survives saved microphone mute and headphone gain.
    oud::DSP speaker;speaker.set(oud::Output,-60);speaker.set(oud::Mute,1);speaker.prepare(48000);
    std::fill(mic.begin(),mic.end(),.5f);std::fill(l.begin(),l.end(),.1f);std::fill(r.begin(),r.end(),.1f);
    speaker.process(mic.data(),ml.data(),mr.data(),mic.size(),rl.data(),rr.data(),false,l.data(),r.data(),false);
    assert(std::abs(ml.back()-.1f)<1e-5 && std::abs(mr.back()-.1f)<1e-5);
    std::fill(l.begin(),l.end(),0);std::fill(r.begin(),r.end(),0);
    speaker.process(mic.data(),ml.data(),mr.data(),mic.size(),rl.data(),rr.data(),false,l.data(),r.data(),false);
    assert(ml.back()==0 && mr.back()==0); // no microphone feedback on speaker
    std::cout<<"PASS speaker loop audible with microphone mute and -60 dB headphone gain; microphone remains silent\n";
    std::cout<<"PASS independent oud/loop channel balance, matching live/file mix, true mute and listen-only exclusion\n";
    std::cout<<"PASS original PCM at 100%, looping, variable rate, live without mic monitoring, record inclusion/exclusion, final peak protection, stop and replace\n";
}
