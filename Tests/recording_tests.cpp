#include "../OudLive/Audio/WetFileWriter.hpp"
#include "../OudLive/Audio/DSP.hpp"
#include <vector>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <chrono>
#include <string>

int main() {
    const std::string path="/tmp/oudlive-recording-test-"+std::to_string(mach_absolute_time())+".wav";
    CFURLRef url=CFURLCreateFromFileSystemRepresentation(nullptr,reinterpret_cast<const UInt8 *>(path.data()),path.size(),false);
    WetFileWriter recorder;
    assert(recorder.begin(url,48000)==noErr);
    oud::DSP dsp;
    dsp.set(oud::Input,0); dsp.set(oud::Output,0); dsp.set(oud::Mute,0); dsp.set(oud::Reverb,0.7);
    dsp.prepare(48000);
    std::vector<float> in(128),left(128),right(128),monitorL(128),monitorR(128),expected;
    struct StereoBuffers { UInt32 count; AudioBuffer buffers[2]; } buffers={2,{{1,512,left.data()},{1,512,right.data()}}};
    for(int block=0;block<375;++block) {
        for(int i=0;i<128;++i) in[i]=block<100 ? 0.2f*std::sin((block*128+i)*440.f*6.2831853f/48000.f) : 0;
        dsp.process(in.data(),monitorL.data(),monitorR.data(),128,left.data(),right.data(),false);
        for(int i=0;i<128;++i) assert(monitorL[i]==0 && monitorR[i]==0);
        for(int i=0;i<128;++i) { expected.push_back(left[i]); expected.push_back(right[i]); }
        recorder.append(reinterpret_cast<AudioBufferList *>(&buffers),128,mach_absolute_time());
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    assert(recorder.startSeconds()>0);
    assert(recorder.finish()==noErr && !recorder.active());
    recorder.append(reinterpret_cast<AudioBufferList *>(&buffers),128,mach_absolute_time());
    assert(recorder.finish()==noErr);
    ExtAudioFileRef read=nullptr; assert(ExtAudioFileOpenURL(url,&read)==noErr);
    AudioStreamBasicDescription format={}; UInt32 size=sizeof(format);
    assert(ExtAudioFileGetProperty(read,kExtAudioFileProperty_FileDataFormat,&size,&format)==noErr);
    assert(format.mSampleRate==48000 && format.mChannelsPerFrame==2);
    assert(ExtAudioFileSetProperty(read,kExtAudioFileProperty_ClientDataFormat,sizeof(format),&format)==noErr);
    std::vector<float> actual(expected.size()+256);
    AudioBufferList output={}; output.mNumberBuffers=1; output.mBuffers[0]={2,UInt32(actual.size()*4),actual.data()};
    UInt32 count=UInt32(actual.size()/2); assert(ExtAudioFileRead(read,&count,&output)==noErr);
    assert(count==48000); ExtAudioFileDispose(read);
    double tail=0;
    for(size_t i=0;i<expected.size();++i) {
        assert(std::abs(expected[i]-actual[i])<0.000001f);
        if(i>30000) tail+=actual[i]*actual[i];
    }
    assert(tail>0.0001); // Reverb tail in recorded data, after the source has stopped.
    assert(recorder.begin(url,44100)==noErr); // Recording can restart at a new route rate.
    recorder.append(reinterpret_cast<AudioBufferList *>(&buffers),128,mach_absolute_time());
    assert(recorder.finish()==noErr);
    CFRelease(url); std::remove(path.c_str());
    std::puts("PASS: processed microphone WAV matches sample-for-sample with monitoring off; reverb tail, duration and restart preserved");
}
