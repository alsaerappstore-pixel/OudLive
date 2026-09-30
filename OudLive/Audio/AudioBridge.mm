#import "AudioBridge.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include "DSP.hpp"
#include <memory>
#include <cstring>
#include <mach/mach_time.h>
#include "WetFileWriter.hpp"

struct AudioState {
    AudioUnit unit=nullptr;
    oud::DSP dsp;
    std::vector<float> input;
    std::vector<float> recordLeft,recordRight;
    std::atomic<bool> monitoring{false};
    std::atomic<int> error{0};
    WetFileWriter recorder;
    double sampleRate=48000;
};

static OSStatus render(void *context, AudioUnitRenderActionFlags *flags,
                       const AudioTimeStamp *time, UInt32 bus, UInt32 frames, AudioBufferList *out) {
    (void)bus;
    auto *state=static_cast<AudioState *>(context);
    auto silence=[&]() {
        for(UInt32 b=0;b<out->mNumberBuffers;++b)
            if(out->mBuffers[b].mData) std::memset(out->mBuffers[b].mData,0,out->mBuffers[b].mDataByteSize);
        *flags|=kAudioUnitRenderAction_OutputIsSilence;
    };
    if(frames>state->input.size() || out->mNumberBuffers!=2 ||
       !out->mBuffers[0].mData || !out->mBuffers[1].mData ||
       out->mBuffers[0].mDataByteSize<frames*sizeof(float) ||
       out->mBuffers[1].mDataByteSize<frames*sizeof(float)) {
        state->error.store(kAudioUnitErr_TooManyFramesToProcess); silence(); return noErr;
    }
    AudioBufferList input={}; input.mNumberBuffers=1;
    input.mBuffers[0]={1,UInt32(frames*sizeof(float)),state->input.data()};
    OSStatus status=AudioUnitRender(state->unit,flags,time,1,frames,&input);
    if(status!=noErr) { state->error.store(status); silence(); return noErr; }
    // A silent input may still produce delay/reverb tails.
    *flags &= ~kAudioUnitRenderAction_OutputIsSilence;
    state->dsp.process(static_cast<float *>(input.mBuffers[0].mData),
                       static_cast<float *>(out->mBuffers[0].mData),
                       static_cast<float *>(out->mBuffers[1].mData),frames,
                       state->recordLeft.data(),state->recordRight.data());
    // Write only the final stereo DSP output. Prewarmed asynchronous file I/O
    // keeps filesystem work off this callback. The reader fence protects close.
    struct StereoBuffers { UInt32 count; AudioBuffer buffers[2]; } wet={2,{
        {1,UInt32(frames*sizeof(float)),state->recordLeft.data()},
        {1,UInt32(frames*sizeof(float)),state->recordRight.data()}}};
    state->recorder.append(reinterpret_cast<AudioBufferList *>(&wet),frames,
        (time->mFlags & kAudioTimeStampHostTimeValid) ? time->mHostTime : mach_absolute_time());
    // Never send live microphone audio to the phone speaker. This gate is AFTER
    // recording, so headphone absence cannot silence the saved file.
    if(!state->monitoring.load()) silence();
    return noErr;
}

@implementation AudioBridge {
    std::unique_ptr<AudioState> _state;
}
- (instancetype)init {
    if((self=[super init])) {
        _state=std::make_unique<AudioState>();
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeChanged:)
            name:AVAudioSessionRouteChangeNotification object:nil];
    }
    return self;
}
- (void)routeChanged:(NSNotification *)notification {
    (void)notification;
    // Close the live output immediately; Swift reopens it only after validating
    // the current headphone route. Recording has its own independent bus.
    _state->monitoring.store(false);
}
- (BOOL)startWithSampleRate:(double)sampleRate error:(NSError **)error {
    [self stop];
    _state->sampleRate=sampleRate;
    AudioComponentDescription description={kAudioUnitType_Output,kAudioUnitSubType_RemoteIO,kAudioUnitManufacturer_Apple,0,0};
    AudioComponent component=AudioComponentFindNext(nullptr,&description);
    OSStatus result=component?AudioComponentInstanceNew(component,&_state->unit):kAudio_ParamError;
    auto check=[&](OSStatus status) { if(result==noErr) result=status; };
    if(result==noErr) {
        UInt32 enabled=1, maximum=4096, noAllocation=0;
        check(AudioUnitSetProperty(_state->unit,kAudioOutputUnitProperty_EnableIO,kAudioUnitScope_Input,1,&enabled,sizeof(enabled)));
        AudioStreamBasicDescription format={};
        format.mSampleRate=sampleRate; format.mFormatID=kAudioFormatLinearPCM;
        format.mFormatFlags=kAudioFormatFlagsNativeFloatPacked|kAudioFormatFlagIsNonInterleaved;
        format.mBytesPerPacket=4; format.mFramesPerPacket=1; format.mBytesPerFrame=4;
        format.mChannelsPerFrame=1; format.mBitsPerChannel=32;
        check(AudioUnitSetProperty(_state->unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output,1,&format,sizeof(format)));
        format.mChannelsPerFrame=2;
        check(AudioUnitSetProperty(_state->unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input,0,&format,sizeof(format)));
        check(AudioUnitSetProperty(_state->unit,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global,0,&maximum,sizeof(maximum)));
        check(AudioUnitSetProperty(_state->unit,kAudioUnitProperty_ShouldAllocateBuffer,kAudioUnitScope_Output,1,&noAllocation,sizeof(noAllocation)));
        AURenderCallbackStruct callback={render,_state.get()};
        check(AudioUnitSetProperty(_state->unit,kAudioUnitProperty_SetRenderCallback,kAudioUnitScope_Input,0,&callback,sizeof(callback)));
        if(result==noErr) check(AudioUnitInitialize(_state->unit));
        UInt32 size=sizeof(maximum);
        if(result==noErr) check(AudioUnitGetProperty(_state->unit,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global,0,&maximum,&size));
        if(result==noErr) {
            _state->input.assign(maximum,0); _state->dsp.prepare(float(sampleRate)); _state->error.store(0);
            _state->recordLeft.assign(maximum,0); _state->recordRight.assign(maximum,0);
            check(AudioOutputUnitStart(_state->unit));
        }
    }
    if(result!=noErr) {
        [self stop];
        if(error) *error=[NSError errorWithDomain:@"OudLive.Audio" code:result
            userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"تعذّر تشغيل الصوت (رمز %d). افصل الملحق وأعد توصيله ثم حاول مجددًا.",(int)result]}];
        return NO;
    }
    return YES;
}
- (void)stop {
    if(_state && _state->unit) {
        AudioOutputUnitStop(_state->unit); AudioUnitUninitialize(_state->unit);
        AudioComponentInstanceDispose(_state->unit); _state->unit=nullptr;
    }
    [self finishRecording:nil];
}
- (BOOL)beginRecordingAtURL:(NSURL *)url error:(NSError **)error {
    if(!_state->unit || _state->recorder.active()) {
        if(error) *error=[NSError errorWithDomain:@"OudLive.Recording" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"ابدأ الصوت أولًا وأوقف التسجيل السابق."}];
        return NO;
    }
    OSStatus result=_state->recorder.begin((__bridge CFURLRef)url,_state->sampleRate);
    if(result!=noErr) {
        if(error) *error=[NSError errorWithDomain:@"OudLive.Recording" code:result userInfo:@{NSLocalizedDescriptionKey:@"تعذّر فتح ملف التسجيل. تحقق من مساحة التخزين."}];
        return NO;
    }
    return YES;
}
- (BOOL)finishRecording:(NSError **)error {
    OSStatus result=_state->recorder.finish();
    if(result!=noErr && error) *error=[NSError errorWithDomain:@"OudLive.Recording" code:result userInfo:@{NSLocalizedDescriptionKey:@"لم يكتمل التسجيل. قد تكون مساحة التخزين غير كافية."}];
    return result==noErr;
}
- (double)recordingStartHostSeconds { return _state->recorder.startSeconds(); }
- (int)recordingError { return _state->recorder.error.load(); }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [self stop]; }
- (void)setParameter:(NSInteger)parameter value:(float)value { _state->dsp.set((int)parameter,value); }
- (void)setMonitoringEnabled:(BOOL)enabled { _state->monitoring.store(enabled); }
- (float)recordingPeak { return _state->dsp.recordPeak.load(); }
- (float)recordingReduction { return _state->dsp.recordReduction.load(); }
- (float)inputPeak { return _state->dsp.inputPeak.load(std::memory_order_relaxed); }
- (float)outputPeak { return _state->dsp.outputPeak.load(std::memory_order_relaxed); }
- (float)gainReduction { return _state->dsp.gainReduction.load(std::memory_order_relaxed); }
- (int)renderError { return _state->error.load(std::memory_order_relaxed); }
@end
