//
//  SCNote.m
//  SaltCase
//
//  Created by Sota Yokoe on 7/21/12.
//  Copyright (c) 2012 Pankaku Inc. All rights reserved.
//

#import "SCNote.h"

@implementation SCNote
- (void)setVolume:(float)volume {
    _volume = fminf(1.0f, fmaxf(0.0f, volume));
}
- (void)setVibrato:(float)vibrato {
    _vibrato = fminf(1.0f, fmaxf(0.0f, vibrato));
}
- (void)setPitchBend:(float)pitchBend {
    _pitchBend = fminf(1.0f, fmaxf(-1.0f, pitchBend));
}

- (id)init {
    self = [super init];
    if (self) {
        self.volume = 1.0f;
        self.vibrato = 0.0f;
        self.pitchBend = 0.0f;
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        self.startsAt = [dictionary[@"startsAt"] floatValue];
        self.length = [dictionary[@"length"] floatValue];
        self.pitch = [dictionary[@"pitch"] intValue];
        self.text = dictionary[@"text"];
        self.phoneme = dictionary[@"phoneme"];
        self.volume = dictionary[@"volume"] ? [dictionary[@"volume"] floatValue] : 1.0f;
        self.vibrato = dictionary[@"vibrato"] ? [dictionary[@"vibrato"] floatValue] : 0.0f;
        self.pitchBend = dictionary[@"pitchBend"] ? [dictionary[@"pitchBend"] floatValue] : 0.0f;
    }
    return self;
}

- (NSDictionary*)dictionaryRepresentation {
    return @{@"startsAt": @(self.startsAt), 
            @"length": @(self.length), 
            @"pitch": @(self.pitch), 
            @"text": self.text ? self.text : @"",
            @"phoneme": self.phoneme ? self.phoneme : @"",
            @"volume": @(self.volume),
            @"vibrato": @(self.vibrato),
            @"pitchBend": @(self.pitchBend)};
}
- (NSString*)description { return [[self dictionaryRepresentation] description]; }

- (NSTimeInterval)startsAtSecondsInTempo:(float)tempo {
    return self.startsAt * 60.0f / tempo;
}
- (NSTimeInterval)endsAtSecondsInTempo:(float)tempo {
    return (self.startsAt + self.length) * 60.0f / tempo;
}
@end
