#import "SCVocalInstrument.h"
#import "SCVocalSynthEngine.h"

@class SCNeuralVoiceBank;
@class SCNeuralRenderContext;

typedef void (^SCNeuralRenderBlock)(float *buffer, UInt32 frameCount, SCNeuralRenderContext *context);

@interface SCNeuralSynthEngine : SCVocalInstrument <SCVocalSynthEngine>
@property (nonatomic, strong) SCNeuralVoiceBank *voiceBank;
@property (nonatomic, copy) NSString *lastErrorMessage;
@property (nonatomic, copy) SCNeuralRenderBlock renderBlock;
- (instancetype)initWithVoiceBank:(SCNeuralVoiceBank *)voiceBank;
- (BOOL)loadVoiceBankAtURL:(NSURL *)URL error:(NSError **)error;
- (void)configureFromAudioEvent:(id)event;
@end
