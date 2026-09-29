//
//  SCPianoRoll.m
//  SaltCase
//
//  Created by Sota Yokoe on 7/14/12.
//  Copyright (c) 2012 Pankaku Inc. All rights reserved.
//

#import "SCPianoRoll.h"
#import "SCPianoRollNote.h"

#import "SCNote.h"
#import <QuartzCore/QuartzCore.h>

@interface SCPianoRoll() {
    NSPoint dragStartedAt;
    CGRect selectedNoteOriginalFrame;
    NSPoint selectionOrigin;
    BOOL selectingRect;
    NSRect selectionRect;
    NSMutableDictionary* dragOriginalFrames;
}
@property (strong) NSMutableArray* noteViews;
@property (weak) SCPianoRollNote* selectedNote;
@property (weak) NSView* timingBar;
@property (strong) NSMutableArray* selectedNoteViews;
@property (strong) NSUndoManager* editUndoManager;
@end

static NSString* const SCPianoRollNotesPasteboardType = @"com.saltcase.notes";
typedef NS_ENUM(NSInteger, SCPianoRollTool) {
    SCPianoRollToolSelect = 1,
    SCPianoRollToolPencil = 2,
    SCPianoRollToolEraser = 3,
};

@implementation SCPianoRoll

- (void)setActiveTool:(NSInteger)activeTool {
    _activeTool = activeTool;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SCPianoRollActiveToolDidChange" object:self];
}

- (NSArray*)notes {
    NSMutableArray* notes = [NSMutableArray array];
    for (SCPianoRollNote* noteView in self.noteViews) {
        SCNote* note = [[SCNote alloc] init];
        note.startsAt = noteView.frame.origin.x / self.gridHorizontalInterval;
        note.length = noteView.frame.size.width / self.gridHorizontalInterval;
        note.pitch = (int)round(noteView.frame.origin.y / kSCNoteLineHeight);
        note.text = noteView.text;
        note.phoneme = noteView.phoneme;
        note.volume = noteView.volume;
        note.vibrato = noteView.vibrato;
        note.pitchBend = noteView.pitchBend;
        [notes addObject:note];
    }
    return notes;
}

- (void)setGridHorizontalInterval:(float)gridHorizontalInterval {
    float previousScale = _gridHorizontalInterval;
    _gridHorizontalInterval = gridHorizontalInterval;
    
    // Stretch notes.
    float scale = gridHorizontalInterval / previousScale;
    for (SCPianoRollNote* note in self.noteViews) {
        CGRect originalFrame = note.frame;
        note.frame = CGRectMake(originalFrame.origin.x * scale,
                                originalFrame.origin.y,
                                originalFrame.size.width * scale,
                                originalFrame.size.height);
    }
    
    [self setNeedsDisplay:YES];
}

- (void)setSnappingEnabled:(BOOL)snappingEnabled {
    _snappingEnabled = snappingEnabled;
    for (SCPianoRollNote* note in self.noteViews) note.snappingEnabled = snappingEnabled;
}

#pragma mark -

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.noteViews = [NSMutableArray array];
        self.selectedNoteViews = [NSMutableArray array];
        self.editUndoManager = [[NSUndoManager alloc] init];
        dragOriginalFrames = [NSMutableDictionary dictionary];
        self.snappingEnabled = YES;
        self.activeTool = SCPianoRollToolPencil;
        self.gridHorizontalInterval = kSCPianoRollHorizontalGridInterval;
        
        
        NSView* bar = [[NSView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 2.0f, self.frame.size.height)];
        bar.wantsLayer = YES;
        bar.layer.backgroundColor = CGColorCreateGenericRGB(0.35f, 0.85f, 1.0f, 1.0f);
        bar.layer.shadowColor = CGColorCreateGenericRGB(0.25f, 0.75f, 1.0f, 1.0f);
        bar.layer.shadowOpacity = 0.9f;
        bar.layer.shadowRadius = 5.0f;
        [self addSubview:bar];
        self.timingBar = bar;
    }
    return self;
}

- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder { return YES; }
- (NSArray*)selectedNotes { return [self.selectedNoteViews copy]; }
- (void)clearSelection {
    for (SCPianoRollNote* note in self.selectedNoteViews) note.selected = NO;
    [self.selectedNoteViews removeAllObjects];
    self.selectedNote = nil;
}
- (void)setUndoManager:(NSUndoManager*)undoManager {
    if (undoManager) self.editUndoManager = undoManager;
}

- (void)selectNote:(SCPianoRollNote*)note extending:(BOOL)extending {
    if (!extending) {
        for (SCPianoRollNote* oldNote in self.selectedNoteViews) {
            oldNote.selected = NO;
        }
        [self.selectedNoteViews removeAllObjects];
    }
    if (![self.selectedNoteViews containsObject:note]) [self.selectedNoteViews addObject:note];
    note.selected = YES;
    self.selectedNote = note;
}

- (void)noteWasSelected:(SCPianoRollNote*)note {
    [self selectNote:note extending:([NSApp currentEvent].modifierFlags & NSEventModifierFlagShift) != 0];
    [self.window makeFirstResponder:self];
    if ([self.delegate respondsToSelector:@selector(pianoRollSelectionDidChange:)])
        [self.delegate pianoRollSelectionDidChange:self];
    if (self.activeTool == SCPianoRollToolEraser) [self deleteSelectedNotes];
}

- (void)noteDidBeginEditing:(SCPianoRollNote*)note {
    [dragOriginalFrames removeAllObjects];
    for (SCPianoRollNote* selected in self.selectedNoteViews) {
        dragOriginalFrames[[NSValue valueWithNonretainedObject:selected]] = [NSValue valueWithRect:selected.frame];
    }
}

- (void)deleteSelectedNotes {
    NSArray* removed = [self.selectedNoteViews copy];
    [[self.editUndoManager prepareWithInvocationTarget:self] restoreNotes:removed];
    for (SCPianoRollNote* note in removed) {
        [note removeFromSuperview];
        [self.noteViews removeObject:note];
    }
    [self.selectedNoteViews removeAllObjects];
    if ([self.delegate respondsToSelector:@selector(pianoRollDidUpdate:)]) [self.delegate pianoRollDidUpdate:self];
}

- (void)restoreNotes:(NSArray*)notes {
    for (SCPianoRollNote* note in notes) {
        [self addSubview:note];
        [self.noteViews addObject:note];
    }
    if ([self.delegate respondsToSelector:@selector(pianoRollDidUpdate:)]) [self.delegate pianoRollDidUpdate:self];
}

- (void)applyMovementX:(CGFloat)deltaX y:(CGFloat)deltaY {
    [[self.editUndoManager prepareWithInvocationTarget:self] applyMovementX:-deltaX y:-deltaY];
    for (SCPianoRollNote* note in self.selectedNoteViews) {
        NSRect frame = note.frame;
        frame.origin.x = fmaxf(0.0f, frame.origin.x + deltaX);
        frame.origin.y = fmaxf(0.0f, frame.origin.y + deltaY);
        note.frame = frame;
    }
    [self.delegate pianoRollDidUpdate:self];
}

- (void)applyWidthDelta:(CGFloat)delta {
    [[self.editUndoManager prepareWithInvocationTarget:self] applyWidthDelta:-delta];
    for (SCPianoRollNote* note in self.selectedNoteViews) {
        NSRect frame = note.frame;
        frame.size.width = fmaxf(kSCPianoRollMinimumNoteWidth, frame.size.width + delta);
        note.frame = frame;
    }
    [self.delegate pianoRollDidUpdate:self];
}

- (void)copy:(id)sender {
    if (self.selectedNoteViews.count == 0) return;
    NSMutableArray* values = [NSMutableArray array];
    for (SCPianoRollNote* note in self.selectedNoteViews) {
        [values addObject:@{ @"x": @(note.frame.origin.x), @"y": @(note.frame.origin.y),
                             @"width": @(note.frame.size.width), @"text": note.text ?: @"",
                             @"phoneme": note.phoneme ?: @"", @"volume": @(note.volume),
                             @"vibrato": @(note.vibrato), @"pitchBend": @(note.pitchBend) }];
    }
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:values format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setData:data forType:SCPianoRollNotesPasteboardType];
}

- (void)cut:(id)sender { [self copy:sender]; [self deleteSelectedNotes]; }

- (void)paste:(id)sender {
    NSData* data = [[NSPasteboard generalPasteboard] dataForType:SCPianoRollNotesPasteboardType];
    if (!data) return;
    NSArray* values = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
    NSMutableArray* pasted = [NSMutableArray array];
    for (NSDictionary* value in values) {
        NSRect frame = NSMakeRect([value[@"x"] floatValue] + self.gridHorizontalInterval,
                                  [value[@"y"] floatValue], [value[@"width"] floatValue], kSCNoteLineHeight);
        SCPianoRollNote* note = [[SCPianoRollNote alloc] initWithFrame:frame];
        note.text = value[@"text"];
        note.phoneme = value[@"phoneme"];
        if (value[@"volume"]) note.volume = [value[@"volume"] floatValue];
        if (value[@"vibrato"]) note.vibrato = [value[@"vibrato"] floatValue];
        if (value[@"pitchBend"]) note.pitchBend = [value[@"pitchBend"] floatValue];
        note.delegate = self;
        [self addSubview:note]; [self.noteViews addObject:note]; [pasted addObject:note];
    }
    [[self.editUndoManager prepareWithInvocationTarget:self] deleteNotes:pasted];
    [self.selectedNoteViews removeAllObjects];
    for (SCPianoRollNote* note in pasted) [self selectNote:note extending:YES];
    [self.delegate pianoRollDidUpdate:self];
}

- (void)deleteNotes:(NSArray*)notes {
    for (SCPianoRollNote* note in notes) { [note removeFromSuperview]; [self.noteViews removeObject:note]; }
}

- (void)keyDown:(NSEvent*)event {
    NSUInteger flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    NSString* chars = event.charactersIgnoringModifiers.lowercaseString;
    if ([chars isEqualToString:@"z"] && (flags & NSEventModifierFlagCommand)) {
        if (flags & NSEventModifierFlagShift) [self.editUndoManager redo]; else [self.editUndoManager undo];
        return;
    }
    if ([chars isEqualToString:@"a"] && (flags & NSEventModifierFlagCommand)) {
        [self.selectedNoteViews removeAllObjects];
        for (SCPianoRollNote* note in self.noteViews) [self selectNote:note extending:YES];
        if ([self.delegate respondsToSelector:@selector(pianoRollSelectionDidChange:)]) [self.delegate pianoRollSelectionDidChange:self];
        return;
    }
    if ([chars isEqualToString:@"c"] && (flags & NSEventModifierFlagCommand)) { [self copy:self]; return; }
    if ([chars isEqualToString:@"x"] && (flags & NSEventModifierFlagCommand)) { [self cut:self]; return; }
    if ([chars isEqualToString:@"v"] && (flags & NSEventModifierFlagCommand)) { [self paste:self]; return; }
    if ([chars isEqualToString:@" "] && flags == 0) {
        if ([self.delegate respondsToSelector:@selector(pianoRollDidRequestPlayback:)])
            [self.delegate pianoRollDidRequestPlayback:self];
        return;
    }
    if ([chars isEqualToString:@"p"] && flags == 0) { self.snappingEnabled = !self.snappingEnabled; return; }
    if (flags == 0 && chars.length == 1 && chars.integerValue >= 1 && chars.integerValue <= 3) {
        self.activeTool = chars.integerValue;
        return;
    }
    if ([chars isEqualToString:@"e"] && flags == 0) {
        self.gridHorizontalInterval = fminf(kSCPianoRollHorizontalMaxGridInterval, self.gridHorizontalInterval * 1.15f);
        return;
    }
    if ([chars isEqualToString:@"q"] && flags == 0) {
        self.gridHorizontalInterval = fmaxf(kSCPianoRollHorizontalMinGridInterval, self.gridHorizontalInterval / 1.15f);
        return;
    }
    if (event.keyCode == 51 || event.keyCode == 117) { [self deleteSelectedNotes]; return; }
    if (event.keyCode == 53) {
        [self clearSelection];
        if ([self.delegate respondsToSelector:@selector(pianoRollSelectionDidChange:)]) [self.delegate pianoRollSelectionDidChange:self];
        return;
    }
    if (event.keyCode == 126 || event.keyCode == 125) {
        float semitones = (flags & NSEventModifierFlagCommand) ? 12.0f : 1.0f;
        float delta = (event.keyCode == 126 ? semitones : -semitones) * kSCNoteLineHeight;
        [self applyMovementX:0 y:delta]; return;
    }
    if (event.keyCode == 123 || event.keyCode == 124) {
        CGFloat delta = event.keyCode == 123 ? -self.gridHorizontalInterval : self.gridHorizontalInterval;
        if (flags & NSEventModifierFlagCommand) [self applyMovementX:delta y:0];
        else if (flags & NSEventModifierFlagOption) [self applyWidthDelta:delta];
        return;
    }
    [super keyDown:event];
}

- (void)loadNotes:(NSArray*)notesInComposition {
    for (SCNote* note in notesInComposition) {
        SCPianoRollNote* noteView = [[SCPianoRollNote alloc] initWithFrame:NSMakeRect(note.startsAt * self.gridHorizontalInterval,
                                                                                      note.pitch * kSCNoteLineHeight, 
                                                                                      note.length * self.gridHorizontalInterval, kSCNoteLineHeight)];
        if (note.text) noteView.text = note.text;
        noteView.phoneme = note.phoneme;
        noteView.volume = note.volume;
        noteView.vibrato = note.vibrato;
        noteView.pitchBend = note.pitchBend;
        noteView.snappingEnabled = self.snappingEnabled;
        noteView.delegate = self;
        [self addSubview:noteView];
        [self.noteViews addObject:noteView];
    }
}

- (void)reloadNotes:(NSArray*)notesInComposition {
    NSArray* currentNotes = [self.noteViews copy];
    for (SCPianoRollNote* note in currentNotes) [note removeFromSuperview];
    [self.noteViews removeAllObjects];
    [self clearSelection];
    self.selectedNote = nil;
    [self loadNotes:notesInComposition];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedWhite:0.11 alpha:1.0] setFill];
    NSRectFill(dirtyRect);

    for (NSInteger row = 0; row <= (NSInteger)(self.frame.size.height / kSCNoteLineHeight); row++) {
        if (row % 2 == 0) {
            [[NSColor colorWithCalibratedWhite:0.16 alpha:0.28] setFill];
            NSRectFill(NSMakeRect(dirtyRect.origin.x, row * kSCNoteLineHeight,
                                  dirtyRect.size.width, kSCNoteLineHeight));
        }
    }

    [[NSColor colorWithCalibratedWhite:0.30 alpha:0.65] set];
    [NSBezierPath setDefaultLineWidth:1];
    
    float y = 0.0f;
    while (y <= self.frame.size.height) {
        [NSBezierPath strokeLineFromPoint:NSMakePoint(0.0f, y) toPoint:NSMakePoint(self.frame.size.width, y)];
        y += kSCNoteLineHeight;
    }
    
    float x = 0.0f;
    NSInteger column = 0;
    while (x <= self.frame.size.width) {
        if (column % 4 == 0) {
            [[NSColor colorWithCalibratedRed:0.35 green:0.55 blue:0.75 alpha:0.42] set];
            [NSBezierPath setDefaultLineWidth:1.5];
        } else {
            [[NSColor colorWithCalibratedWhite:0.30 alpha:0.65] set];
            [NSBezierPath setDefaultLineWidth:1];
        }
        [NSBezierPath strokeLineFromPoint:NSMakePoint(x, 0.0f) toPoint:NSMakePoint(x, self.frame.size.height)];
        x += self.gridHorizontalInterval;
        column++;
    }
    if (selectingRect) {
        [[NSColor colorWithCalibratedRed:0.2 green:0.7 blue:1.0 alpha:0.18] setFill];
        NSRectFillUsingOperation(selectionRect, NSCompositingOperationSourceOver);
        [[NSColor colorWithCalibratedRed:0.2 green:0.7 blue:1.0 alpha:0.9] setStroke];
        [NSBezierPath strokeRect:selectionRect];
    }

}

- (double)beatPositionAtPoint:(NSPoint)point {
    return point.x / kSCPianoRollHorizontalGridInterval;
}
- (UInt32)pitchNumberAtPoint:(NSPoint)point {
    int pitchNumber = (int)floor(point.y / kSCNoteLineHeight);
    return pitchNumber >= 0 ? pitchNumber : 0;
}
- (NSPoint)pointOfEvent:(NSEvent*)event {
    return [self convertPoint:event.locationInWindow fromView:nil];
}
- (void)moveSelectedStretchTo:(NSPoint)cursorAt {
    if (self.selectedNote) {
        float diff = cursorAt.x - dragStartedAt.x;
        float newWidth = fmaxf(selectedNoteOriginalFrame.size.width + diff, kSCPianoRollMinimumNoteWidth);
        self.selectedNote.frame = NSMakeRect(selectedNoteOriginalFrame.origin.x, selectedNoteOriginalFrame.origin.y,
                                             newWidth, selectedNoteOriginalFrame.size.height);
    }
}

- (void)moveBarToTiming:(NSTimeInterval)beats {
    NSRect nextFrame = CGRectMake(beats * self.gridHorizontalInterval, 0.0f, 2.0f, self.frame.size.height);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
        context.duration = 0.035;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        self.timingBar.animator.frame = nextFrame;
    } completionHandler:nil];
}

#pragma mark SCPianoRollNoteDelegate
- (void)noteDidUpdate:(SCPianoRollNote *)note {
    if (self.snappingEnabled) {
        for (SCPianoRollNote* selected in self.selectedNoteViews) {
            NSRect frame = selected.frame;
            frame.origin.x = fmaxf(0.0f, round(frame.origin.x / self.gridHorizontalInterval) * self.gridHorizontalInterval);
            selected.frame = frame;
        }
    } else {
        NSRect frame = note.frame;
        frame.origin.x = fmaxf(0.0f, frame.origin.x);
        note.frame = frame;
    }
    if (dragOriginalFrames.count > 0) {
        NSDictionary* original = [dragOriginalFrames copy];
        [[self.editUndoManager prepareWithInvocationTarget:self] restoreFrames:original];
        [dragOriginalFrames removeAllObjects];
    }
    if ([self.delegate respondsToSelector:@selector(pianoRollDidUpdate:)]) {
        [self.delegate pianoRollDidUpdate:self];
    }
}
- (void)restoreFrames:(NSDictionary*)frames {
    NSMutableDictionary* current = [NSMutableDictionary dictionary];
    for (NSValue* key in frames) {
        SCPianoRollNote* note = key.nonretainedObjectValue;
        if (!note) continue;
        current[key] = [NSValue valueWithRect:note.frame];
        note.frame = [frames[key] rectValue];
    }
    [[self.editUndoManager prepareWithInvocationTarget:self] restoreFrames:current];
}
- (void)note:(SCPianoRollNote*)note didMoveBy:(NSPoint)delta {
    if (![self.selectedNoteViews containsObject:note]) return;
    for (SCPianoRollNote* other in self.selectedNoteViews) {
        if (other == note) continue;
        NSRect frame = other.frame;
        frame.origin.x = fmaxf(0.0f, frame.origin.x + delta.x);
        frame.origin.y = fmaxf(0.0f, frame.origin.y + delta.y);
        other.frame = frame;
    }
}
- (void)noteToBeRemoved:(SCPianoRollNote *)note {
    if (![self.selectedNoteViews containsObject:note]) [self selectNote:note extending:NO];
    [self deleteSelectedNotes];
}

#pragma mark Mouse events

- (void)mouseDown:(NSEvent *)theEvent {
    NSPoint cursorAt = [self pointOfEvent:theEvent];

    if (theEvent.modifierFlags & NSEventModifierFlagOption) {
        selectingRect = YES;
        selectionOrigin = cursorAt;
        selectionRect = NSMakeRect(cursorAt.x, cursorAt.y, 0, 0);
        [self clearSelection];
        [self setNeedsDisplay:YES];
        [self.window makeFirstResponder:self];
        return;
    }

    if (self.activeTool == SCPianoRollToolSelect) {
        [self clearSelection];
        [self setNeedsDisplay:YES];
        [self.window makeFirstResponder:self];
        return;
    }
    
    float y = [self pitchNumberAtPoint:cursorAt] * kSCNoteLineHeight;
    CGFloat noteX = self.snappingEnabled ? round(cursorAt.x / self.gridHorizontalInterval) * self.gridHorizontalInterval : cursorAt.x;
    SCPianoRollNote* note = [[SCPianoRollNote alloc] initWithFrame:NSMakeRect(noteX, y, self.gridHorizontalInterval, kSCNoteLineHeight)];
    selectedNoteOriginalFrame = note.frame;
    dragStartedAt = cursorAt;
    note.delegate = self;
    note.snappingEnabled = self.snappingEnabled;
    [self addSubview:note];
    [self.noteViews addObject:note];
    [self selectNote:note extending:NO];
    [self.window makeFirstResponder:self];
}
- (void)mouseDragged:(NSEvent *)theEvent {
    if (selectingRect) {
        NSPoint current = [self pointOfEvent:theEvent];
        selectionRect = NSMakeRect(MIN(selectionOrigin.x, current.x), MIN(selectionOrigin.y, current.y),
                                   fabs(current.x - selectionOrigin.x), fabs(current.y - selectionOrigin.y));
        [self setNeedsDisplay:YES];
        return;
    }
    [self moveSelectedStretchTo:[self pointOfEvent:theEvent]];
}
- (void)mouseUp:(NSEvent *)theEvent {
    if (selectingRect) {
        selectingRect = NO;
        for (SCPianoRollNote* note in self.noteViews) {
            if (NSIntersectsRect(selectionRect, note.frame)) [self selectNote:note extending:YES];
        }
        if ([self.delegate respondsToSelector:@selector(pianoRollSelectionDidChange:)]) [self.delegate pianoRollSelectionDidChange:self];
        selectionRect = NSZeroRect;
        [self setNeedsDisplay:YES];
        return;
    }
    [self moveSelectedStretchTo:[self pointOfEvent:theEvent]];
    self.selectedNote = nil;
    
    if ([self.delegate respondsToSelector:@selector(pianoRollDidUpdate:)]) {
        [self.delegate pianoRollDidUpdate:self];
    }
}
@end
