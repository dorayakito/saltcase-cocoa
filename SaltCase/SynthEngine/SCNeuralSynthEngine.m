#import "SCNeuralSynthEngine.h"
#import "SCNeuralVoiceBank.h"
#import "SCNeuralRenderContext.h"
#import "SCAudioEvent.h"

@interface SCNeuralSynthEngine ()
@property (nonatomic, strong) SCNeuralRenderContext *context;
@property (nonatomic) BOOL active;
@end

@implementation SCNeuralSynthEngine

- (instancetype)init { return [self initWithVoiceBank:nil]; }
- (instancetype)initWithVoiceBank:(SCNeuralVoiceBank *)voiceBank {
    self = [super init];
    if (self) {
        _voiceBank = voiceBank;
        _context = [[SCNeuralRenderContext alloc] init];
    }
    return self;
}

- (BOOL)loadVoiceBankAtURL:(NSURL *)URL error:(NSError **)error {
    SCNeuralVoiceBank *voiceBank = [[SCNeuralVoiceBank alloc] initWithURL:URL error:error];
    if (!voiceBank) {
        self.lastErrorMessage = error && *error ? (*error).localizedDescription : @"Unable to load SaltCase neural voicebank.";
        return NO;
    }
    self.voiceBank = voiceBank;
    self.lastErrorMessage = nil;
    return YES;
}

- (void)setFrequency:(float)frequency {
    [super setFrequency:frequency];
    self.context.frequency = frequency;
}

- (void)configureFromAudioEvent:(SCAudioEvent *)event {
    self.text = event.text ?: @"";
    self.frequency = event.frequency;
    self.context.phoneme = event.text ?: @"";
    self.context.frequency = event.frequency;
    self.context.velocity = event.velocity;
    self.context.vibrato = [event.note respondsToSelector:@selector(vibrato)] ? [event.note vibrato] : 0.0f;
    self.context.pitchBend = [event.note respondsToSelector:@selector(pitchBend)] ? [event.note pitchBend] : 0.0f;
    self.context.duration = event.duration;
    self.context.pitchCurve = event.pitchCurve ?: @[];
    self.context.timbreParameters = event.timbreParameters ?: @{};
}

- (void)onWithVelocity:(float)velocity {
    self.context.velocity = velocity;
    self.active = YES;
}
- (void)off { self.active = NO; }

- (void)renderToBuffer:(float *)buffer numOfPackets:(UInt32)numOfPackets sender:(SCSynth *)sender {
    self.context.frameCount = numOfPackets;
    self.context.sampleRate = sender.samplingFrameRate;
    if (self.renderBlock) {
        self.renderBlock(buffer, numOfPackets, self.context);
        return;
    }
    /*
     The Core ML feature contract is intentionally not guessed here. A trained
     voicebank supplies the acoustic/vocoder model and its manifest; until one
     is installed, silence is safer than silently reverting to sample playback.
     */
    if (!self.voiceBank.ready && self.active && self.lastErrorMessage.length == 0) {
        self.lastErrorMessage = @"No SaltCase neural voicebank is loaded.";
    }
}
@end
