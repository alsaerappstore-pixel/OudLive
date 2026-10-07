#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// All methods except metering are called on the main thread.
@interface AudioBridge : NSObject
- (BOOL)startWithSampleRate:(double)sampleRate error:(NSError **)error;
- (void)stop;
- (void)setParameter:(NSInteger)parameter value:(float)value;
- (void)setParameters:(NSArray<NSNumber *> *)values;
- (void)setRecordRhythmEnabled:(BOOL)enabled;
- (void)setMonitoringEnabled:(BOOL)enabled;
- (void)setRhythm:(NSInteger)index playing:(BOOL)playing tempo:(float)tempo volume:(float)volume;
@property(nonatomic, readonly) BOOL rhythmReady;
@property(nonatomic, readonly) float rhythmPosition;
@property(nonatomic, readonly) float recordingPeak;
@property(nonatomic, readonly) float recordingReduction;
- (BOOL)beginRecordingAtURL:(NSURL *)url error:(NSError **)error;
- (BOOL)finishRecording:(NSError **)error;
@property(nonatomic, readonly) double recordingStartHostSeconds;
@property(nonatomic, readonly) int recordingError;
@property(nonatomic, readonly) float inputPeak;
@property(nonatomic, readonly) float outputPeak;
@property(nonatomic, readonly) float gainReduction;
@property(nonatomic, readonly) int renderError;
@end
NS_ASSUME_NONNULL_END

