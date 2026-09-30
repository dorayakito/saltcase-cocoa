//
//  SCAudioEvent.m
//  SaltCase
//
//  Created by Sota Yokoe on 7/21/12.
//  Copyright (c) 2012 Pankaku Inc. All rights reserved.
//

#import "SCAudioEvent.h"

@implementation SCAudioEvent

- (instancetype)init {
    self = [super init];
    if (self) {
        _pitchCurve = @[];
        _timbreParameters = @{};
    }
    return self;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"%.2f(%d) - %d", self.timing, self.timingPacketNumber, self.type];
}
@end
