//
//  SCPianoRoll.h
//  SaltCase
//
//  Created by Sota Yokoe on 7/14/12.
//  Copyright (c) 2012 Pankaku Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SCPianoRollNote.h"

@protocol SCPianoRollDelegate <NSObject>
- (void)pianoRollDidUpdate:(id)sender;
@optional
- (void)pianoRollDidRequestPlayback:(id)sender;
- (void)pianoRollDidSeekToBeat:(double)beat;
- (void)pianoRollSelectionDidChange:(id)sender;
@end

@interface SCPianoRoll : NSView<SCPianoRollNoteDelegate>
@property (weak) id<SCPianoRollDelegate> delegate;
@property (nonatomic, assign) float gridHorizontalInterval;
@property (readonly) NSArray* notes;
@property (readonly) NSArray* selectedNotes;
@property (nonatomic, assign) BOOL snappingEnabled;
@property (nonatomic, assign) NSInteger activeTool;
- (void)loadNotes:(NSArray*)notesInComposition;
- (void)reloadNotes:(NSArray*)notesInComposition;
- (void)moveBarToTiming:(NSTimeInterval)beats;
- (void)setUndoManager:(NSUndoManager*)undoManager;
@end
