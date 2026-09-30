#import "SCNeuralRenderContext.h"

@implementation SCNeuralRenderContext
- (instancetype)init {
    self = [super init];
    if (self) {
        _sampleRate = 44100.0;
        _velocity = 1.0f;
        _pitchCurve = @[];
        _timbreParameters = @{};
    }
    return self;
}
@end
