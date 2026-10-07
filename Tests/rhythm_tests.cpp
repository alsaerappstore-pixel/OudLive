#ifdef NDEBUG
#undef NDEBUG
#endif
#include "../OudLive/Audio/RhythmEngine.hpp"
#include "../OudLive/Audio/DSP.hpp"
#include <cassert>
#include <iostream>
#include <limits>

static const char *bank="OudLive/RhythmBank";
static double energy(const std::vector<float> &x) { double e=0; for(float v:x) { assert(std::isfinite(v)); e+=v*v; } return e; }
static void render(oud::RhythmEngine &engine,std::vector<float> &l,std::vector<float> &r,size_t block) {
    for(size_t offset=0;offset<l.size();offset+=block) engine.render(l.data()+offset,r.data()+offset,std::min(block,l.size()-offset));
}
int main() {
    oud::RhythmEngine engine;
    assert(!engine.loadBank("missing-percussion.pcm"));
    std::vector<float> zeroL(128),zeroR(128); engine.prepare(48000); engine.select(0); engine.setPlaying(true);
    engine.render(zeroL.data(),zeroR.data(),128); assert(energy(zeroL)==0);
    assert(engine.loadBank(bank)); engine.prepare(48000); engine.setVolume(.65); engine.setTempo(120);
    for(int id=0;id<oud::rhythmCount;++id) {
        engine.setPlaying(false); engine.render(zeroL.data(),zeroR.data(),128);
        engine.select(id); engine.setPlaying(true);
        const int n=oud::rhythmPatterns[id].count;
        std::vector<float> l(n*6000*2),r(l.size());
        render(engine,l,r,127); assert(energy(l)>1 && energy(r)>1);
        assert(std::abs(engine.position())<.0001 || engine.position()>.9999);
        for(float v:l) assert(std::abs(v)<2);
    }
    std::cout<<"PASS: all "<<oud::rhythmCount<<" real-sample patterns complete two sample-clock cycles at 120 BPM\n";
    // Identical waveform and event count for tiny vs irregular hardware buffers.
    oud::RhythmEngine a,b; assert(a.loadBank(bank)&&b.loadBank(bank)); a.prepare(48000); b.prepare(48000);
    a.select(0);b.select(0);a.setPlaying(true);b.setPlaying(true);a.setTempo(137);b.setTempo(137);
    std::vector<float> al(240000),ar(al.size()),bl(al.size()),br(al.size());
    render(a,al,ar,1);render(b,bl,br,4093);
    assert(al==bl && ar==br && a.debugTriggers()==b.debugTriggers());
    std::cout<<"PASS: no drift or lost notes across block boundaries, tempo 137\n";
    // Tempo changes advance phase at the new speed, without restarting a sample.
    a.setTempo(40); b.setTempo(220); a.render(zeroL.data(),zeroR.data(),128);b.render(zeroL.data(),zeroR.data(),128);
    assert(a.position()!=b.position());
    a.setPlaying(false); std::vector<float> tail(4800),tailR(4800);render(a,tail,tailR,128);
    for(size_t i=1000;i<tail.size();++i) assert(tail[i]==0 && tailR[i]==0);
    a.setTempo(std::numeric_limits<float>::quiet_NaN()); a.setVolume(std::numeric_limits<float>::infinity());
    a.select(999);a.setPlaying(true);render(a,tail,tailR,128); assert(energy(tail)==0);
    std::cout<<"PASS: tempo changes, invalid input guards, stop fade and silent missing bank\n";
    for(int rate:{8000,16000,44100,48000,96000}) {
        engine.prepare(rate);engine.select(11);engine.setTempo(220);engine.setVolume(1);engine.setPlaying(true);
        oud::DSP dsp; dsp.set(oud::Bypass,1);dsp.set(oud::RecordGain,18);dsp.set(oud::Mute,1);dsp.prepare(float(rate));
        std::vector<float> mic(256,.8f),backL(256),backR(256),l(256),r(256),recL(256),recR(256);
        double saved=0;
        for(int block=0;block<rate/256;++block) {
            engine.render(backL.data(),backR.data(),256);
            dsp.process(mic.data(),l.data(),r.data(),256,recL.data(),recR.data(),backL.data(),backR.data());
            for(int i=0;i<256;++i) {
                assert(l[i]==0 && r[i]==0);
                assert(std::isfinite(recL[i]) && std::abs(recL[i])<=.981f && std::abs(recR[i])<=.981f);
                saved+=recL[i]*recL[i];
            }
        }
        assert(saved>1);
    }
    // Raw means dry microphone plus backing, not losing the independent rhythm.
    oud::DSP dsp; dsp.set(oud::Bypass,1);dsp.set(oud::Input,0);dsp.set(oud::Output,0);dsp.set(oud::RecordGain,0);dsp.prepare(48000);
    float mic[4]={.1f,.2f,-.1f,-.2f},backL[4]={.1f,-.1f,.2f,-.2f},backR[4]={.2f,-.2f,.1f,-.1f},l[4],r[4],recL[4],recR[4];
    dsp.process(mic,l,r,4,recL,recR,backL,backR);
    for(int i=0;i<4;++i) { assert(std::abs(recL[i]-mic[i]-backL[i])<.0001f);assert(std::abs(recR[i]-mic[i]-backR[i])<.0001f); }
    std::cout<<"PASS: raw + rhythm mix, independent muted monitor, recording limiter at 8/16/44.1/48/96 kHz\n";
}
