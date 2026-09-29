#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class SCSynth;
@protocol SCAudioRenderer <NSObject>
- (void)renderBuffer:(float*)buffer numOfPackets:(UInt32)numOfPackets sender:(SCSynth*)sender;
@end

@interface SCSynth : NSObject
@property (readonly) UInt32 renderedPackets;
@property (strong) id<SCAudioRenderer>renderer;
@property (readonly) float samplingFrameRate;
@property (readonly) NSTimeInterval timeElapsed;
@property (nonatomic, assign) float volume;
- (void)playWithRenderer:(NSObject<SCAudioRenderer>*)renderer;
- (void)stop:(BOOL)shouldStopImmediately;
- (float)levelForChannel:(int)channel;
@end
