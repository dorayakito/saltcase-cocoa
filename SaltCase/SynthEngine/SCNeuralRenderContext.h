#import <Foundation/Foundation.h>

@interface SCNeuralRenderContext : NSObject
@property (nonatomic) double sampleRate;
@property (nonatomic) UInt32 frameCount;
@property (nonatomic) float frequency;
@property (nonatomic) float velocity;
@property (nonatomic) float vibrato;
@property (nonatomic) float pitchBend;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, copy) NSString *phoneme;
@property (nonatomic, copy) NSArray<NSNumber*> *pitchCurve;
@property (nonatomic, copy) NSDictionary *timbreParameters;
@end
