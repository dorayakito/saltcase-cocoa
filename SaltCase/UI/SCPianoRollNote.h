//
//  SCPianoRollNote.h
//  SaltCase
//
//  Created by Sota Yokoe on 7/17/12.
//  Copyright (c) 2012 Pankaku Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SCPianoRollNote;
@protocol SCPianoRollNoteDelegate <NSObject>
- (void)noteDidUpdate:(SCPianoRollNote*)note;
- (void)noteToBeRemoved:(SCPianoRollNote*)note;
@optional
- (void)noteWasSelected:(SCPianoRollNote*)note;
- (void)noteDidBeginEditing:(SCPianoRollNote*)note;
- (void)note:(SCPianoRollNote*)note didMoveBy:(NSPoint)delta;
@end

@interface SCPianoRollNote : NSView <NSTextFieldDelegate>
@property (weak) id<SCPianoRollNoteDelegate> delegate;
@property (nonatomic) NSString* text;
@property (nonatomic, copy) NSString* phoneme;
@property (nonatomic, assign) float volume;
@property (nonatomic, assign) float vibrato;
@property (nonatomic, assign) float pitchBend;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, assign) BOOL snappingEnabled;
@end
