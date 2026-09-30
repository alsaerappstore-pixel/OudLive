#pragma once
#include <AudioToolbox/AudioToolbox.h>
#include <atomic>
#include <thread>
#include <mach/mach_time.h>

// One render-thread producer. begin/finish run only on the control thread.
// Storage outlives all callbacks; the fence prevents disposal during a write.
class WetFileWriter {
    std::atomic<ExtAudioFileRef> file{nullptr};
    std::atomic<unsigned> readers{0};
public:
    std::atomic<int> error{0};
    std::atomic<uint64_t> firstHost{0};
    bool active() const { return file.load()!=nullptr; }
    OSStatus begin(CFURLRef url, double rate) {
        if(active()) return kAudio_ParamError;
        AudioStreamBasicDescription disk={};
        disk.mSampleRate=rate; disk.mFormatID=kAudioFormatLinearPCM;
        disk.mFormatFlags=kAudioFormatFlagsNativeFloatPacked;
        disk.mBytesPerPacket=8; disk.mFramesPerPacket=1; disk.mBytesPerFrame=8;
        disk.mChannelsPerFrame=2; disk.mBitsPerChannel=32;
        ExtAudioFileRef created=nullptr;
        OSStatus result=ExtAudioFileCreateWithURL(url,kAudioFileWAVEType,&disk,nullptr,kAudioFileFlags_EraseFile,&created);
        AudioStreamBasicDescription client=disk;
        client.mFormatFlags|=kAudioFormatFlagIsNonInterleaved; client.mBytesPerPacket=4; client.mBytesPerFrame=4;
        if(result==noErr) result=ExtAudioFileSetProperty(created,kExtAudioFileProperty_ClientDataFormat,sizeof(client),&client);
        if(result==noErr) result=ExtAudioFileWriteAsync(created,0,nullptr);
        if(result!=noErr) { if(created) ExtAudioFileDispose(created); return result; }
        error.store(0); firstHost.store(0); file.store(created); return noErr;
    }
    void append(const AudioBufferList *buffers, UInt32 frames, uint64_t host) {
        readers.fetch_add(1);
        if(auto current=file.load()) {
            if(firstHost.load()==0) firstHost.store(host);
            OSStatus result=ExtAudioFileWriteAsync(current,frames,buffers);
            if(result!=noErr) error.store(result);
        }
        readers.fetch_sub(1);
    }
    OSStatus finish() {
        auto current=file.exchange(nullptr);
        if(!current) return noErr;
        while(readers.load()!=0) std::this_thread::yield();
        OSStatus result=ExtAudioFileDispose(current);
        return result==noErr ? error.load() : result;
    }
    double startSeconds() const {
        mach_timebase_info_data_t info; mach_timebase_info(&info);
        return double(firstHost.load())*info.numer/info.denom/1.0e9;
    }
};
