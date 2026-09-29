#import "AudioBridge.h"
#import <AudioToolbox/AudioToolbox.h>
#include "DSP.hpp"
#include <memory>
#include <cstring>

struct AudioState {
    AudioUnit unit=nullptr;
    oud::DSP dsp;
    std::vector<float> input;
    std::atomic<int> error{0};
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
                       static_cast<float *>(out->mBuffers[1].mData),frames);
    return noErr;
}

@implementation AudioBridge {
    std::unique_ptr<AudioState> _state;
}
- (instancetype)init {
    if((self=[super init])) _state=std::make_unique<AudioState>();
    return self;
}
- (BOOL)startWithSampleRate:(double)sampleRate error:(NSError **)error {
    [self stop];
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
}
- (void)dealloc { [self stop]; }
- (void)setParameter:(NSInteger)parameter value:(float)value { _state->dsp.set((int)parameter,value); }
- (float)inputPeak { return _state->dsp.inputPeak.load(std::memory_order_relaxed); }
- (float)outputPeak { return _state->dsp.outputPeak.load(std::memory_order_relaxed); }
- (float)gainReduction { return _state->dsp.gainReduction.load(std::memory_order_relaxed); }
- (int)renderError { return _state->error.load(std::memory_order_relaxed); }
@end
