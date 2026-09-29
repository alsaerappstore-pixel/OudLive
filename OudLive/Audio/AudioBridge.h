#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// All methods except metering are called on the main thread.
@interface AudioBridge : NSObject
- (BOOL)startWithSampleRate:(double)sampleRate error:(NSError **)error;
- (void)stop;
- (void)setParameter:(NSInteger)parameter value:(float)value;
@property(nonatomic, readonly) float inputPeak;
@property(nonatomic, readonly) float outputPeak;
@property(nonatomic, readonly) int renderError;
@end
NS_ASSUME_NONNULL_END
