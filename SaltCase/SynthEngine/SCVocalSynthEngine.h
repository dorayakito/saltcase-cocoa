#import <Foundation/Foundation.h>

@class SCSynth;
@protocol SCVocalSynthEngine <NSObject>
- (void)renderToBuffer:(float *)buffer numOfPackets:(UInt32)numOfPackets sender:(SCSynth *)sender;
@end
