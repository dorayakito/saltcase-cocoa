#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>

FOUNDATION_EXPORT NSString * const SCNeuralVoiceBankErrorDomain;

@interface SCNeuralVoiceBank : NSObject
@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSDictionary *manifest;
@property (nonatomic, readonly) MLModel *acousticModel;
@property (nonatomic, readonly) MLModel *vocoderModel;
@property (nonatomic, readonly) NSArray<NSString*> *phonemes;
@property (nonatomic, readonly) BOOL ready;

- (instancetype)initWithURL:(NSURL *)URL error:(NSError **)error;
- (BOOL)supportsPhoneme:(NSString *)phoneme;
@end
