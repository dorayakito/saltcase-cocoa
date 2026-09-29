//
//  SCPianoRollNote.m
//  SaltCase
//
//  Created by Sota Yokoe on 7/17/12.
//  Copyright (c) 2012 Pankaku Inc. All rights reserved.
//

#import "SCPianoRollNote.h"
#import <QuartzCore/QuartzCore.h>

const float kSCPianoRollNoteTextFieldMarginLeft = 10.0f;
const float kSCPianoRollNoteTextFieldMarginY = 5.0f;
const float kSCPianoRollNoteCloseButtonSize = 20.0f;

@interface SCPianoRollNoteDeleteButton : NSButton
@end
@implementation SCPianoRollNoteDeleteButton
- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setBordered:NO];
        self.wantsLayer = YES;
        self.layer.borderColor = CGColorCreateGenericRGB(0.0f, 0.0f, 0.0f, 0.5f);
        self.layer.borderWidth = 2.0f;
        self.layer.cornerRadius = kSCPianoRollNoteCloseButtonSize * 0.5f;
        self.layer.shadowOpacity = 0.5f;
        self.layer.shadowOffset = CGSizeMake(0.0f, -2.0f);
    }
    return self;
}
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor grayColor] set];
    
    NSBezierPath* bgPath = [NSBezierPath bezierPathWithOvalInRect:dirtyRect];
    [bgPath fill];
    
    const float size = self.frame.size.width * 0.2f;
    NSPoint center = NSMakePoint(self.frame.size.width * 0.5f, self.frame.size.height * 0.5f);
    
    NSBezierPath* line = [NSBezierPath new];
    [[NSColor whiteColor] set];
    [line setLineWidth:2.0f];
    
    [line moveToPoint:NSMakePoint(center.x - size, center.y - size)];
    [line lineToPoint:NSMakePoint(center.x + size, center.y + size)];
    [line stroke];
    [line moveToPoint:NSMakePoint(center.x + size, center.y - size)];
    [line lineToPoint:NSMakePoint(center.x - size, center.y + size)];
    [line stroke];
}
@end


typedef enum {
    SCPianoRollNoteEditingModeMove,
    SCPianoRollNoteEditingModeStretch,
} SCPianoRollNoteEditingMode;

@interface SCPianoRollNote() {
    NSPoint dragStartedAt;
    NSPoint lastDragLocation;
    CGRect originalFrame;
    SCPianoRollNoteEditingMode editMode;
    SCPianoRollNoteDeleteButton* deleteButton;
    NSTextField* textField;
    BOOL pointerInside;
}
- (void)updateExpressionAppearance;
@end

@implementation SCPianoRollNote

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.volume = 1.0f;
        self.vibrato = 0.0f;
        self.pitchBend = 0.0f;
        self.snappingEnabled = YES;
        self.layer = [CALayer layer];
        self.layer.backgroundColor = CGColorCreateGenericRGB(0.16f, 0.22f, 0.38f, 0.94f);
        self.layer.cornerRadius = 10.0f;
        self.layer.shadowOpacity = 0.5f;
        self.layer.shadowOffset = CGSizeMake(0.0f, -5.0f);
        self.layer.shadowColor = CGColorCreateGenericRGB(0.35f, 0.55f, 0.95f, 1.0f);

        self.wantsLayer = YES;
        
        textField = [[NSTextField alloc] initWithFrame:CGRectMake(kSCPianoRollNoteTextFieldMarginLeft, kSCPianoRollNoteTextFieldMarginY, 30.0f, self.frame.size.height- kSCPianoRollNoteTextFieldMarginY * 2)];
        textField.backgroundColor = [NSColor clearColor];
        textField.textColor = [NSColor whiteColor];
        textField.wantsLayer = YES;
        textField.layer.cornerRadius = 5.0f;
        textField.layer.shadowColor = CGColorCreateGenericRGB(1.0f, 1.0f, 1.0f, 0.5f);
        textField.layer.shadowOpacity = 1.0f;
        textField.layer.backgroundColor = CGColorCreateGenericRGB(1.0f, 1.0f, 1.0f, 0.25f);
        textField.layer.borderWidth = 0.0f;
        textField.delegate = self;
        [textField setBezeled:NO];
        
        // Set the default character
        NSDictionary* defaultEntries = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DefaultSettings" ofType:@"plist"]];
        textField.stringValue = defaultEntries[@"DefaultCharacter"];
        
        [self addSubview:textField];
        
        
        deleteButton = [[SCPianoRollNoteDeleteButton alloc] initWithFrame:CGRectMake(frame.size.width - kSCPianoRollNoteCloseButtonSize * 0.5f, frame.size.height - kSCPianoRollNoteCloseButtonSize * 0.5f, kSCPianoRollNoteCloseButtonSize, kSCPianoRollNoteCloseButtonSize)];
        deleteButton.autoresizingMask = NSViewMinXMargin;
        [deleteButton setTarget:self];
        [deleteButton setAction:@selector(delete:)];
        [self addSubview:deleteButton];

        NSTrackingArea* trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
            options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow owner:self userInfo:nil];
        [self addTrackingArea:trackingArea];
        [self updateExpressionAppearance];
    }
    
    return self;
}

- (void)setVolume:(float)volume {
    _volume = volume;
    [self updateExpressionAppearance];
}

- (void)setPitchBend:(float)pitchBend {
    _pitchBend = pitchBend;
    [self updateExpressionAppearance];
}

- (void)updateExpressionAppearance {
    if (!self.layer) return;
    CGFloat intensity = fminf(1.0f, fmaxf(0.0f, self.volume));
    CGFloat hue = 0.60f - (fminf(1.0f, fmaxf(-1.0f, self.pitchBend)) * 0.08f);
    self.layer.backgroundColor = [[NSColor colorWithHue:hue saturation:0.58 brightness:0.42 + intensity * 0.38 alpha:0.96] CGColor];
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.14];
    self.layer.borderWidth = selected ? 2.0 : 0.0;
    self.layer.borderColor = CGColorCreateGenericRGB(0.45f, 0.9f, 1.0f, 1.0f);
    self.layer.shadowOpacity = selected ? 0.9 : (pointerInside ? 0.7 : 0.5);
    self.layer.shadowRadius = selected ? 8.0 : (pointerInside ? 5.0 : 3.0);
    [CATransaction commit];
}

- (void)mouseEntered:(NSEvent*)event {
    pointerInside = YES;
    self.layer.shadowOpacity = self.selected ? 0.95 : 0.75;
    self.layer.shadowRadius = self.selected ? 8.0 : 5.0;
}

- (void)mouseExited:(NSEvent*)event {
    pointerInside = NO;
    self.layer.shadowOpacity = self.selected ? 0.9 : 0.5;
    self.layer.shadowRadius = self.selected ? 8.0 : 3.0;
}

- (void)setText:(NSString *)text {
    [textField setStringValue:text];
}
- (NSString*)text {
    return textField.stringValue;
}

// Make delete button clickable.
- (NSView*)hitTest:(NSPoint)aPoint {
    if ([super hitTest:aPoint]) return [super hitTest:aPoint];
    
    NSPoint convertedPoint = [self convertPoint:aPoint fromView:self.superview];
    if (NSPointInRect(convertedPoint, deleteButton.frame)) return deleteButton;
    
    return nil;
}
- (void)delete:(id)sender{
    if ([self.delegate respondsToSelector:@selector(noteToBeRemoved:)]) {
        [self.delegate noteToBeRemoved:self];
    }
}

- (NSPoint)pointOfEvent:(NSEvent*)event {
    return [self convertPoint:event.locationInWindow fromView:nil];
}
#pragma mark Mouse events
- (void)mouseDown:(NSEvent *)theEvent {
    if ([self.delegate respondsToSelector:@selector(noteWasSelected:)]) {
        [self.delegate noteWasSelected:self];
    }
    if ([self.delegate respondsToSelector:@selector(noteDidBeginEditing:)]) {
        [self.delegate noteDidBeginEditing:self];
    }
    dragStartedAt = theEvent.locationInWindow;
    lastDragLocation = dragStartedAt;
    originalFrame = self.frame;
    
    NSPoint cursorAt = [self pointOfEvent:theEvent];
    if (cursorAt.x <= self.frame.size.width / 2) {
        editMode = SCPianoRollNoteEditingModeMove;
    } else {
        editMode = SCPianoRollNoteEditingModeStretch;
    }
}
- (void)mouseDragged:(NSEvent *)theEvent {
    NSPoint location = theEvent.locationInWindow;
    NSPoint move = NSMakePoint(location.x - dragStartedAt.x, location.y - dragStartedAt.y);
    NSPoint incrementalMove = NSMakePoint(location.x - lastDragLocation.x, location.y - lastDragLocation.y);
    lastDragLocation = location;
    
    if (editMode == SCPianoRollNoteEditingModeMove) {
        float newY = self.snappingEnabled
            ? round((originalFrame.origin.y + move.y) / kSCNoteLineHeight) * kSCNoteLineHeight
            : originalFrame.origin.y + move.y;
        newY = fmaxf(0.0f, newY);
        self.frame = CGRectMake(originalFrame.origin.x + move.x, newY, originalFrame.size.width, originalFrame.size.height);
    } else {
        float newWidth = originalFrame.size.width + move.x;
        const float minimumWidth = kSCPianoRollMinimumNoteWidth;
        newWidth = fmaxf(newWidth, minimumWidth);
        self.frame = CGRectMake(originalFrame.origin.x, originalFrame.origin.y, newWidth, originalFrame.size.height);
    }
    if (editMode == SCPianoRollNoteEditingModeMove && [self.delegate respondsToSelector:@selector(note:didMoveBy:)]) {
        [self.delegate note:self didMoveBy:incrementalMove];
    }
}
- (void)mouseUp:(NSEvent *)theEvent {
    if ([self.delegate respondsToSelector:@selector(noteDidUpdate:)]) {
        [self.delegate noteDidUpdate:self];
    }
}

#pragma mark TextField delegate
- (void)controlTextDidChange:(NSNotification *)obj {
    if ([self.delegate respondsToSelector:@selector(noteDidUpdate:)]) {
        [self.delegate noteDidUpdate:self];
    }
}
@end
