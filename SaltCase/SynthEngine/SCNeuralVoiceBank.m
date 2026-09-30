#import "SCNeuralVoiceBank.h"

NSString * const SCNeuralVoiceBankErrorDomain = @"com.saltcase.neural-voicebank";

static NSError *SCVoiceError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:SCNeuralVoiceBankErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation SCNeuralVoiceBank

- (instancetype)initWithURL:(NSURL *)URL error:(NSError **)error {
    self = [super init];
    if (!self) return nil;
    _URL = [URL copy];

    if (!URL.isFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:URL.path]) {
        if (error) *error = SCVoiceError(1, @"The SaltCase voicebank does not exist.");
        return nil;
    }
    NSURL *manifestURL = [URL URLByAppendingPathComponent:@"manifest.json"];
    NSData *manifestData = [NSData dataWithContentsOfURL:manifestURL];
    NSDictionary *manifest = manifestData ? [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:error] : nil;
    if (![manifest isKindOfClass:[NSDictionary class]]) {
        if (error && !*error) *error = SCVoiceError(2, @"The voicebank manifest.json is invalid.");
        return nil;
    }
    if (![manifest[@"engine"] isEqualToString:@"saltcase-neural"] || [manifest[@"formatVersion"] integerValue] != 1) {
        if (error) *error = SCVoiceError(3, @"Unsupported SaltCase neural voicebank format.");
        return nil;
    }
    NSString *acousticName = manifest[@"models"][@"acoustic"];
    NSString *vocoderName = manifest[@"models"][@"vocoder"];
    NSURL *acousticURL = [URL URLByAppendingPathComponent:acousticName ?: @""];
    NSURL *vocoderURL = [URL URLByAppendingPathComponent:vocoderName ?: @""];
    if (![[NSFileManager defaultManager] fileExistsAtPath:acousticURL.path] || ![[NSFileManager defaultManager] fileExistsAtPath:vocoderURL.path]) {
        if (error) *error = SCVoiceError(4, @"The voicebank is missing its acoustic or vocoder Core ML model.");
        return nil;
    }
    NSError *modelError = nil;
    _acousticModel = [MLModel modelWithContentsOfURL:acousticURL error:&modelError];
    if (!_acousticModel) {
        if (error) *error = modelError ?: SCVoiceError(5, @"Unable to load the acoustic Core ML model.");
        return nil;
    }
    _vocoderModel = [MLModel modelWithContentsOfURL:vocoderURL error:&modelError];
    if (!_vocoderModel) {
        if (error) *error = modelError ?: SCVoiceError(6, @"Unable to load the vocoder Core ML model.");
        return nil;
    }
    _manifest = [manifest copy];
    _phonemes = [manifest[@"phonemes"] isKindOfClass:[NSArray class]] ? [manifest[@"phonemes"] copy] : @[];
    return self;
}

- (BOOL)ready { return self.acousticModel != nil && self.vocoderModel != nil; }
- (BOOL)supportsPhoneme:(NSString *)phoneme {
    return phoneme.length > 0 && (self.phonemes.count == 0 || [self.phonemes containsObject:phoneme]);
}
@end
