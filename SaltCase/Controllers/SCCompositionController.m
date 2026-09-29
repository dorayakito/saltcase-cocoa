//
//  SCAppController.m
//  SaltCase
//
//  Created by Sota Yokoe on 7/8/12.
//  Copyright (c) 2012 Pankaku Inc. All rights reserved.
//

#import "SCCompositionController.h"
#import "SCAppController.h"

#import "SCDocument.h"
#import "SCSynth.h"
#import "SCKeyboardView.h"
#import "SCNote.h"
#import "SCAudioEvent.h"
#import "SCPitchUtil.h"

#import "SCVocalInstrument.h"
#import "SCSineWaveGenerator.h"
#import "SCMultiSampler.h"
#import "SCExporter.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface SCTimelineRulerView : NSView
@property (nonatomic) CGFloat gridInterval;
@property (nonatomic, copy) void (^seekHandler)(CGFloat beat);
@end

@implementation SCTimelineRulerView {
    BOOL dragging;
}
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor colorWithCalibratedWhite:0.07 alpha:0.98] setFill];
    NSRectFill(self.bounds);
    for (NSInteger column = 0; column * self.gridInterval <= self.bounds.size.width; column++) {
        CGFloat x = column * self.gridInterval;
        BOOL bar = column % 4 == 0;
        [[NSColor colorWithCalibratedWhite:(bar ? 0.86 : 0.48) alpha:(bar ? 0.9 : 0.65)] set];
        [NSBezierPath strokeLineFromPoint:NSMakePoint(x, self.bounds.size.height)
                                  toPoint:NSMakePoint(x, bar ? 7 : 13)];
        if (bar) [[NSString stringWithFormat:@"%ld", (long)(column / 4 + 1)]
                   drawAtPoint:NSMakePoint(x + 4, 2)
                   withAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:10],
                                    NSForegroundColorAttributeName: [NSColor secondaryLabelColor]}];
    }
}
- (void)seekFromEvent:(NSEvent*)event {
    CGFloat beat = MAX(0.0, [self convertPoint:event.locationInWindow fromView:nil].x / self.gridInterval);
    if (self.seekHandler) self.seekHandler(beat);
}
- (void)mouseDown:(NSEvent*)event { dragging = YES; [self seekFromEvent:event]; }
- (void)mouseDragged:(NSEvent*)event { if (dragging) [self seekFromEvent:event]; }
- (void)mouseUp:(NSEvent*)event { dragging = NO; }
@end

@interface SCCompositionController() {
    SCPianoRoll* pianoRoll;
    UInt32 nextEventIndex;
    UInt32 renderedPackets;    
    NSSlider* pianoRollXScaleSlider;
    SCVocalInstrument* vocalLine;
}
@property (strong) NSArray* events;
@property (strong) NSVisualEffectView* editorToolbar;
@property (strong) NSSlider* editorTempoSlider;
@property (strong) NSTextField* editorStatusLabel;
@property (strong) NSSlider* editorVolumeSlider;
@property (assign) BOOL loopEnabled;
@property (assign) BOOL metronomeEnabled;
@property (strong) NSButton* editorPlayButton;
@property (strong) NSButton* editorStopButton;
@property (strong) NSButton* editorLoopButton;
@property (strong) NSVisualEffectView* expressionPanel;
@property (strong) NSSlider* expressionVolumeSlider;
@property (strong) NSSlider* expressionVibratoSlider;
@property (strong) NSSlider* expressionPitchSlider;
@property (strong) NSTextField* expressionLyricField;
@property (strong) NSTextField* expressionPhonemeField;
@property (strong) NSArray<NSButton*>* editorToolButtons;
@property (strong) SCTimelineRulerView* timelineRuler;
@end

@implementation SCCompositionController

- (void)reloadEditor {
    [pianoRoll reloadNotes:self.composition.notes ?: @[]];
}

- (void)pianoRollDidRequestPlayback:(id)sender {
    if ([SCAppController sharedInstance].currentlyPlaying == self) {
        [self stopComposition:self];
    } else {
        [self playComposition:self];
    }
}

- (void)pianoRollDidSeekToBeat:(double)beat {
    double seconds = beat * 60.0 / self.composition.tempo;
    self.editorStatusLabel.stringValue = [NSString stringWithFormat:@"%.0f BPM · %02d:%05.2f",
                                          self.composition.tempo, (int)(seconds / 60.0), fmod(seconds, 60.0)];
}

- (void)pianoRollSelectionDidChange:(id)sender {
    SCPianoRollNote* note = pianoRoll.selectedNotes.firstObject;
    if (!note) return;
    self.expressionVolumeSlider.floatValue = note.volume;
    self.expressionVibratoSlider.floatValue = note.vibrato;
    self.expressionPitchSlider.floatValue = note.pitchBend;
    self.expressionLyricField.stringValue = note.text ?: @"";
    self.expressionPhonemeField.stringValue = note.phoneme ?: @"";
}

- (void)awakeFromNib {
    [super awakeFromNib];

    self.window.minSize = NSMakeSize(960.0, 640.0);
    self.window.titleVisibility = NSWindowTitleVisible;
    self.window.titlebarAppearsTransparent = YES;
    self.window.title = @"SaltCase · Editor";
    self.window.toolbarStyle = NSWindowToolbarStyleUnified;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioBufferDidUpdate:) name:SCBufferUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorToolDidChange:) name:@"SCPianoRollActiveToolDidChange" object:pianoRoll];
    
    float maxHeight = kSCNumOfRows * kSCNoteLineHeight;
    pianoRoll = [[SCPianoRoll alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, 2000.f, maxHeight)];
    pianoRoll.delegate = self;
    [pianoRoll setUndoManager:self.composition.undoManager];
    if (self.composition.notes) [pianoRoll loadNotes:self.composition.notes];
    self.scrollView.documentView = pianoRoll;
    [self installEditorToolbar];
    [self installTimelineRuler];
    [self installExpressionPanel];
    
    SCKeyboardView* keyboard = [[SCKeyboardView alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, self.keyboardScroll.contentView.frame.size.width, maxHeight)];
    self.keyboardScroll.documentView = keyboard;
    
    float pianoSliderHeight = self.scrollView.horizontalScroller.frame.size.height;
    
    pianoRollXScaleSlider = [[NSSlider alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.keyboardScroll.frame.size.width, pianoSliderHeight)];
    pianoRollXScaleSlider.maxValue = kSCPianoRollHorizontalMaxGridInterval;
    pianoRollXScaleSlider.minValue = kSCPianoRollHorizontalMinGridInterval;
    [pianoRollXScaleSlider setFloatValue:kSCPianoRollHorizontalGridInterval]; // TODO: Restore setting.
    [self.mainView addSubview:pianoRollXScaleSlider];
    [pianoRollXScaleSlider setTarget:self];
    [pianoRollXScaleSlider setAction:@selector(pianoRollXScaleSliderDidUpdate:)];
    
    self.keyboardScroll.frame = CGRectMake(0.0f, self.keyboardScroll.frame.origin.y + pianoSliderHeight, self.keyboardScroll.frame.size.width, self.keyboardScroll.frame.size.height - pianoSliderHeight);
    
    // Synchronize scrolling between the piano roll and the keyboard view.
    // http://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/NSScrollViewGuide/Articles/SynchroScroll.html
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pianoRollDidScroll:) name:NSViewBoundsDidChangeNotification object:self.scrollView.contentView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardViewDidScroll:) name:NSViewBoundsDidChangeNotification object:self.keyboardScroll.contentView];
    NSString* sampleVoiceDirectory = [[NSBundle mainBundle] pathForResource:@"sample" ofType:nil];
    vocalLine = [[SCMultiSampler alloc] initWithContentsOfDirectoryAtPath:sampleVoiceDirectory];
    keyboard.vocalLine = vocalLine;
    
    // Scroll to initial point.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.keyboardScroll.contentView scrollToPoint:NSMakePoint(0.0f, kSCNoteLineHeight * 12)];
    });
    

}

- (void)installTimelineRuler {
    NSRect scrollFrame = self.scrollView.frame;
    self.timelineRuler = [[SCTimelineRulerView alloc] initWithFrame:NSMakeRect(scrollFrame.origin.x,
                                                                                NSMaxY(scrollFrame) - 26.0,
                                                                                scrollFrame.size.width, 26.0)];
    self.timelineRuler.gridInterval = pianoRoll.gridHorizontalInterval;
    self.timelineRuler.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    __weak typeof(self) weakSelf = self;
    self.timelineRuler.seekHandler = ^(CGFloat beat) {
        SCCompositionController* strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf->pianoRoll moveBarToTiming:beat];
        [strongSelf pianoRollDidSeekToBeat:beat];
    };
    [self.mainView addSubview:self.timelineRuler positioned:NSWindowAbove relativeTo:nil];
}

- (void)installExpressionPanel {
    self.expressionPanel = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, self.mainView.bounds.size.width, 64)];
    self.expressionPanel.material = NSVisualEffectMaterialUnderWindowBackground;
    self.expressionPanel.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    self.expressionPanel.state = NSVisualEffectStateActive;
    self.expressionPanel.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;

    NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(14, 12, 560, 40)];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.spacing = 8;
    stack.alignment = NSLayoutAttributeCenterY;
    [stack addArrangedSubview:[NSTextField labelWithString:@"Expressions"]];

    self.expressionVolumeSlider = [self expressionSliderWithTitle:@"Volume" min:0 max:1 action:@selector(expressionVolumeChanged:)];
    self.expressionVibratoSlider = [self expressionSliderWithTitle:@"Vibrato" min:0 max:1 action:@selector(expressionVibratoChanged:)];
    self.expressionPitchSlider = [self expressionSliderWithTitle:@"Pitch" min:-1 max:1 action:@selector(expressionPitchChanged:)];
    [stack addArrangedSubview:[NSTextField labelWithString:@"Vol"]];
    [stack addArrangedSubview:self.expressionVolumeSlider];
    [stack addArrangedSubview:[NSTextField labelWithString:@"Vibrato"]];
    [stack addArrangedSubview:self.expressionVibratoSlider];
    [stack addArrangedSubview:[NSTextField labelWithString:@"Pitch"]];
    [stack addArrangedSubview:self.expressionPitchSlider];
    self.expressionLyricField = [NSTextField textFieldWithString:@""];
    self.expressionLyricField.placeholderString = @"Letra";
    self.expressionLyricField.target = self;
    self.expressionLyricField.action = @selector(expressionLyricChanged:);
    self.expressionLyricField.toolTip = @"Letra das notas selecionadas";
    self.expressionPhonemeField = [NSTextField textFieldWithString:@""];
    self.expressionPhonemeField.placeholderString = @"Fonema";
    self.expressionPhonemeField.target = self;
    self.expressionPhonemeField.action = @selector(expressionPhonemeChanged:);
    self.expressionPhonemeField.toolTip = @"Fonema personalizado";
    [stack addArrangedSubview:self.expressionLyricField];
    [stack addArrangedSubview:self.expressionPhonemeField];
    [self.expressionPanel addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.expressionPanel.leadingAnchor constant:14.0],
        [stack.trailingAnchor constraintEqualToAnchor:self.expressionPanel.trailingAnchor constant:-14.0],
        [stack.centerYAnchor constraintEqualToAnchor:self.expressionPanel.centerYAnchor]
    ]];
    [self.mainView addSubview:self.expressionPanel positioned:NSWindowAbove relativeTo:nil];
}

- (NSSlider*)expressionSliderWithTitle:(NSString*)title min:(double)min max:(double)max action:(SEL)action {
    NSSlider* slider = [NSSlider sliderWithValue:(min + max) * 0.5 minValue:min maxValue:max target:self action:action];
    slider.toolTip = title;
    slider.controlSize = NSControlSizeSmall;
    return slider;
}

- (NSArray*)selectedExpressionNotes {
    return pianoRoll.selectedNotes;
}
- (NSDictionary*)expressionSnapshot {
    NSMutableDictionary* snapshot = [NSMutableDictionary dictionary];
    for (SCPianoRollNote* note in [self selectedExpressionNotes]) {
        snapshot[[NSValue valueWithNonretainedObject:note]] = @{
            @"volume": @(note.volume),
            @"vibrato": @(note.vibrato),
            @"pitchBend": @(note.pitchBend),
            @"text": note.text ?: @"",
            @"phoneme": note.phoneme ?: @""
        };
    }
    return snapshot;
}
- (void)registerExpressionUndo {
    NSDictionary* snapshot = [self expressionSnapshot];
    if (snapshot.count) [[self.composition.undoManager prepareWithInvocationTarget:self] restoreExpressionValues:snapshot];
}
- (void)restoreExpressionValues:(NSDictionary*)snapshot {
    NSDictionary* current = [self expressionSnapshot];
    [[self.composition.undoManager prepareWithInvocationTarget:self] restoreExpressionValues:current];
    for (NSValue* key in snapshot) {
        SCPianoRollNote* note = key.nonretainedObjectValue;
        NSDictionary* values = snapshot[key];
        if (!note) continue;
        note.volume = [values[@"volume"] floatValue];
        note.vibrato = [values[@"vibrato"] floatValue];
        note.pitchBend = [values[@"pitchBend"] floatValue];
        note.text = values[@"text"];
        note.phoneme = values[@"phoneme"];
    }
    [pianoRoll.delegate pianoRollDidUpdate:pianoRoll];
}
- (void)expressionVolumeChanged:(NSSlider*)slider {
    [self registerExpressionUndo];
    for (SCPianoRollNote* note in [self selectedExpressionNotes]) note.volume = slider.floatValue;
    [pianoRoll.delegate pianoRollDidUpdate:pianoRoll];
}
- (void)expressionVibratoChanged:(NSSlider*)slider {
    [self registerExpressionUndo];
    for (SCPianoRollNote* note in [self selectedExpressionNotes]) note.vibrato = slider.floatValue;
    [pianoRoll.delegate pianoRollDidUpdate:pianoRoll];
}
- (void)expressionPitchChanged:(NSSlider*)slider {
    [self registerExpressionUndo];
    for (SCPianoRollNote* note in [self selectedExpressionNotes]) note.pitchBend = slider.floatValue;
    [pianoRoll.delegate pianoRollDidUpdate:pianoRoll];
}
- (void)expressionLyricChanged:(NSTextField*)field {
    [self registerExpressionUndo];
    for (SCPianoRollNote* note in [self selectedExpressionNotes]) note.text = field.stringValue;
    [pianoRoll.delegate pianoRollDidUpdate:pianoRoll];
}
- (void)expressionPhonemeChanged:(NSTextField*)field {
    [self registerExpressionUndo];
    for (SCPianoRollNote* note in [self selectedExpressionNotes]) note.phoneme = field.stringValue;
    [pianoRoll.delegate pianoRollDidUpdate:pianoRoll];
}
- (void)installEditorToolbar {
    self.editorToolbar = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, self.mainView.bounds.size.height - 42,
                                                                                self.mainView.bounds.size.width, 42)];
    self.editorToolbar.material = NSVisualEffectMaterialHeaderView;
    self.editorToolbar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    self.editorToolbar.state = NSVisualEffectStateActive;
    self.editorToolbar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

    NSStackView* controls = [[NSStackView alloc] initWithFrame:NSMakeRect(12, 7, 390, 28)];
    controls.translatesAutoresizingMaskIntoConstraints = NO;
    controls.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controls.spacing = 6;
    controls.alignment = NSLayoutAttributeCenterY;

    NSArray* toolDefinitions = @[
        @[ @"Select", @"1" ], @[ @"Pencil", @"2" ], @[ @"Erase", @"3" ]
    ];
    for (NSArray* definition in toolDefinitions) {
        NSButton* button = [NSButton buttonWithTitle:[NSString stringWithFormat:@"%@  %@", definition[0], definition[1]]
                                               target:self action:@selector(editorToolButtonPressed:)];
        button.tag = [definition[1] integerValue];
        button.buttonType = NSButtonTypeToggle;
        button.bezelStyle = NSBezelStyleTexturedRounded;
        button.toolTip = [NSString stringWithFormat:@"%@ (tecla %@)", definition[0], definition[1]];
        [controls addArrangedSubview:button];
    }
    self.editorToolButtons = [controls.arrangedSubviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSView* view, NSDictionary* bindings) {
        return [view isKindOfClass:[NSButton class]];
    }]];
    [self editorToolDidChange:nil];
    NSButton* snap = [NSButton checkboxWithTitle:@"Snap" target:self action:@selector(editorSnapButtonPressed:)];
    snap.state = pianoRoll.snappingEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    snap.toolTip = @"Ativar ou desativar encaixe na grade (P)";
    [controls addArrangedSubview:snap];

    NSButton* zoomOut = [NSButton buttonWithTitle:@"−" target:self action:@selector(editorZoomOut:)];
    NSButton* zoomIn = [NSButton buttonWithTitle:@"+" target:self action:@selector(editorZoomIn:)];
    zoomOut.toolTip = @"Reduzir zoom (Q)";
    zoomIn.toolTip = @"Aumentar zoom (E)";
    [controls addArrangedSubview:zoomOut];
    [controls addArrangedSubview:zoomIn];
    [self.editorToolbar addSubview:controls];

    NSStackView* transport = [[NSStackView alloc] initWithFrame:NSMakeRect(420, 7, 420, 28)];
    transport.translatesAutoresizingMaskIntoConstraints = NO;
    transport.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    transport.spacing = 8;
    transport.alignment = NSLayoutAttributeCenterY;
    self.editorPlayButton = [NSButton buttonWithTitle:@"▶  Play" target:self action:@selector(playComposition:)];
    self.editorPlayButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.editorPlayButton.toolTip = @"Reproduzir (Espaço)";
    self.editorStopButton = [NSButton buttonWithTitle:@"■  Stop" target:self action:@selector(stopComposition:)];
    self.editorStopButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.editorStopButton.toolTip = @"Parar reprodução";
    [transport addArrangedSubview:self.editorPlayButton];
    [transport addArrangedSubview:self.editorStopButton];

    NSTextField* tempoTitle = [NSTextField labelWithString:@"Tempo"];
    self.editorTempoSlider = [NSSlider sliderWithValue:self.composition.tempo minValue:40.0
                                                maxValue:320.0 target:self action:@selector(editorTempoChanged:)];
    self.editorTempoSlider.controlSize = NSControlSizeSmall;
    self.editorTempoSlider.toolTip = @"Tempo da composição em BPM";
    [transport addArrangedSubview:tempoTitle];
    [transport addArrangedSubview:self.editorTempoSlider];
    self.editorStatusLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"%.0f BPM", self.composition.tempo]];
    self.editorStatusLabel.textColor = [NSColor secondaryLabelColor];
    [transport addArrangedSubview:self.editorStatusLabel];
    self.editorLoopButton = [NSButton checkboxWithTitle:@"Loop" target:self action:@selector(editorLoopButtonPressed:)];
    self.editorLoopButton.toolTip = @"Repetir a composição ao terminar";
    [transport addArrangedSubview:self.editorLoopButton];
    NSButton* metronome = [NSButton checkboxWithTitle:@"Click" target:self action:@selector(editorMetronomeButtonPressed:)];
    metronome.state = NSControlStateValueOn;
    metronome.toolTip = @"Ativar ou desativar o metrônomo";
    self.metronomeEnabled = YES;
    [transport addArrangedSubview:metronome];
    self.editorVolumeSlider = [NSSlider sliderWithValue:0.5 minValue:0.0 maxValue:1.0
                                                  target:self action:@selector(editorVolumeChanged:)];
    self.editorVolumeSlider.controlSize = NSControlSizeSmall;
    self.editorVolumeSlider.toolTip = @"Volume de reprodução";
    [transport addArrangedSubview:self.editorVolumeSlider];
    NSButton* importMIDI = [NSButton buttonWithTitle:@"MIDI ⇩" target:self action:@selector(importMIDI:)];
    NSButton* exportMIDI = [NSButton buttonWithTitle:@"MIDI ⇧" target:self action:@selector(exportMIDI:)];
    importMIDI.toolTip = @"Importar MIDI";
    exportMIDI.toolTip = @"Exportar MIDI";
    [transport addArrangedSubview:importMIDI];
    [transport addArrangedSubview:exportMIDI];
    [self.editorToolbar addSubview:transport];
    [NSLayoutConstraint activateConstraints:@[
        [controls.leadingAnchor constraintEqualToAnchor:self.editorToolbar.leadingAnchor constant:12.0],
        [controls.centerYAnchor constraintEqualToAnchor:self.editorToolbar.centerYAnchor],
        [transport.leadingAnchor constraintEqualToAnchor:controls.trailingAnchor constant:18.0],
        [transport.trailingAnchor constraintEqualToAnchor:self.editorToolbar.trailingAnchor constant:-12.0],
        [transport.centerYAnchor constraintEqualToAnchor:self.editorToolbar.centerYAnchor]
    ]];
    [self.mainView addSubview:self.editorToolbar positioned:NSWindowAbove relativeTo:nil];
}

- (void)importMIDI:(id)sender {
    [self.composition importMIDI:sender];
}
- (void)exportMIDI:(id)sender {
    [self.composition exportMIDI:sender];
}

- (void)editorToolButtonPressed:(NSButton*)sender {
    pianoRoll.activeTool = sender.tag;
}
- (void)editorToolDidChange:(NSNotification*)notification {
    for (NSButton* button in self.editorToolButtons) {
        button.state = button.tag == pianoRoll.activeTool ? NSControlStateValueOn : NSControlStateValueOff;
    }
}
- (void)editorSnapButtonPressed:(NSButton*)sender {
    pianoRoll.snappingEnabled = sender.state == NSControlStateValueOn;
}
- (void)editorZoomIn:(id)sender {
    pianoRoll.gridHorizontalInterval = fminf(kSCPianoRollHorizontalMaxGridInterval, pianoRoll.gridHorizontalInterval * 1.15f);
}
- (void)editorZoomOut:(id)sender {
    pianoRoll.gridHorizontalInterval = fmaxf(kSCPianoRollHorizontalMinGridInterval, pianoRoll.gridHorizontalInterval / 1.15f);
}
- (void)editorTempoChanged:(NSSlider*)sender {
    self.composition.tempo = sender.floatValue;
    self.editorStatusLabel.stringValue = [NSString stringWithFormat:@"%.0f BPM", self.composition.tempo];
    [self.tempoSlider setFloatValue:self.composition.tempo];
    [self.tempoLabel takeFloatValueFrom:self.tempoSlider];
}
- (void)editorLoopButtonPressed:(NSButton*)sender {
    self.loopEnabled = sender.state == NSControlStateValueOn;
}
- (void)editorMetronomeButtonPressed:(NSButton*)sender {
    self.metronomeEnabled = sender.state == NSControlStateValueOn;
}
- (void)editorVolumeChanged:(NSSlider*)sender {
    [SCAppController sharedInstance].synth.volume = sender.floatValue;
}
- (void)dealloc
{
    NSLog(@"CompositionContr dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Notifications

- (void)audioBufferDidUpdate:(NSNotification*)note {
    if ([SCAppController sharedInstance].currentlyPlaying == self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SCSynth* player = (SCSynth*)note.object;
            
            float timeIntervalPerBeat = (60.0f / self.composition.tempo);
            int beats = (int)floor(player.timeElapsed / timeIntervalPerBeat);
            
            [self.timeLabel setStringValue:[NSString stringWithFormat:@"%02d:%06.3f - %03d/%d %.2f|%.2f", (int)floor(player.timeElapsed / 60), player.timeElapsed - (int)floor(player.timeElapsed / 60) * 60 , beats / 4, beats % 4,
                                       [player levelForChannel:0], [player levelForChannel:1]]];
            
            [pianoRoll moveBarToTiming:player.timeElapsed / timeIntervalPerBeat];
            if (self.loopEnabled && player.timeElapsed >= self.composition.lengthInSeconds) {
                [[SCAppController sharedInstance] stopComposition:self];
                [self playComposition:self];
            }
        });
    }
}

- (void)pianoRollDidScroll:(NSNotification*)note {
    NSClipView *changedContentView = note.object;
    NSPoint changedBoundsOrigin = changedContentView.documentVisibleRect.origin;
    changedBoundsOrigin.x = 0.0f;
    [self.keyboardScroll.contentView scrollToPoint:changedBoundsOrigin];
    [self.keyboardScroll reflectScrolledClipView:self.keyboardScroll.contentView];
}
- (void)keyboardViewDidScroll:(NSNotification*)note {
    NSClipView *changedContentView = note.object;
    NSPoint changedBoundsOrigin = changedContentView.documentVisibleRect.origin;
    changedBoundsOrigin.x = self.scrollView.contentView.bounds.origin.x;
    [self.scrollView.contentView scrollToPoint:changedBoundsOrigin];
    [self.scrollView reflectScrolledClipView:self.scrollView.contentView];
}

#pragma mark -

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
    if (theItem == self.playButton) {
        return ([SCAppController sharedInstance].currentlyPlaying == nil);
    }
    if (theItem == self.stopButton) {
        return ([SCAppController sharedInstance].currentlyPlaying != nil);
    }
    if (theItem == self.settingsButton) {
        // Disabled while the song is playing.
        return ([SCAppController sharedInstance].currentlyPlaying != self);
    }
    return NO;
}

#pragma mark Audio
- (SCAudioEvent*)nextEvent {
    if (nextEventIndex < self.events.count) {
        return self.events[nextEventIndex];
    } else {
        return nil;
    }
}
- (void)processEvent:(SCAudioEvent*)event sender:(SCSynth *)sender {
    switch (event.type) {
        case SCAudioEventNoteOn:
            [vocalLine setText:event.text];
            [vocalLine onWithVelocity:event.velocity];
            [vocalLine setFrequency:event.frequency];
            break;
        case SCAudioEventNoteOff:
            [vocalLine off];
            break;
        case SCAudioEventPitchChange:
            [vocalLine setFrequency:event.frequency];
            break;
        default:
            break;
    }
}
- (void)renderPartToBuffer:(float *)buffer numOfPackets:(UInt32)numOfPackets sender:(SCSynth *)sender{
    [vocalLine renderToBuffer:buffer numOfPackets:numOfPackets sender:sender];
    if (self.metronomeEnabled) {
        [self.metronome renderToBuffer:buffer numOfPackets:numOfPackets player:sender];
    }
}
- (void)renderBuffer:(float *)buffer numOfPackets:(UInt32)numOfPackets sender:(SCSynth *)sender {
    int i = 0;
    int numRendered = 0;
    while (i < numOfPackets) {
        SCAudioEvent* nextEvent = [self nextEvent];
        
        // Next event is in the buffer.
        if (nextEvent && nextEvent.timingPacketNumber < renderedPackets + numOfPackets) {
            // Render to the next event.
            int numToRender = (nextEvent.timingPacketNumber - (renderedPackets + i));
//            NSLog(@"Render A[%d]-[%d] (%d)", renderedPackets + i, nextEvent.timingPacketNumber, numToRender);
            [self renderPartToBuffer:buffer numOfPackets:numToRender sender:sender];
            buffer += kSCNumOfChannels * numToRender;
            numRendered += numToRender;

            i = nextEvent.timingPacketNumber - renderedPackets;
            [self processEvent:nextEvent sender:sender];
            
            // Go next event.
            nextEventIndex++;
        } else { // No events scheduled in the buffer
            
            int numToRender = (renderedPackets + numOfPackets - (renderedPackets + i));
//            NSLog(@"Render B[%d]-[%d (%d)]", renderedPackets + i, renderedPackets + numOfPackets, numToRender);
            [self renderPartToBuffer:buffer numOfPackets:numToRender sender:sender];
            buffer += kSCNumOfChannels * numToRender;
            i = numOfPackets;
//            NSLog(@"i = %d, nTR = %d", i, numToRender);
            
            numRendered += numToRender;
        }
    }
    if (numRendered != 1024) NSLog(@"Rendered packets count is incorrect. %d", numRendered);
    
    renderedPackets += numOfPackets;
}
- (void)prepareForPlay {
    NSArray* events = self.composition.audioEvents;
    for (SCAudioEvent* event in events) {
        event.timingPacketNumber = (int)round(event.timing * [SCAppController sharedInstance].synth.samplingFrameRate);
    }
    self.events = events;
    nextEventIndex = 0;
    renderedPackets = 0;
    
    [vocalLine off];
}
- (IBAction)playComposition:(id)sender {
    [self.metronome reset];
    self.metronome.tempo = self.composition.tempo;
    
    [self prepareForPlay];
    
    if ([[SCAppController sharedInstance] playComposition:self]) {
        self.editorPlayButton.title = @"●  Playing";
        self.editorPlayButton.state = NSControlStateValueOn;
        self.editorStatusLabel.stringValue = [NSString stringWithFormat:@"● Reproduzindo · %.0f BPM", self.composition.tempo];
        NSLog(@"Started playing %@", self.composition);
    } else {
        NSLog(@"Failed to start playing %@.\nCurrently playing: %@", self.composition, [SCAppController sharedInstance].currentlyPlaying);
    }
}
- (IBAction)stopComposition:(id)sender {
    [[SCAppController sharedInstance] stopComposition:self];
    self.editorPlayButton.title = @"▶  Play";
    self.editorPlayButton.state = NSControlStateValueOff;
    self.editorStatusLabel.stringValue = [NSString stringWithFormat:@"%.0f BPM", self.composition.tempo];
}

#pragma mark Export
- (void)exportWithStyle:(SCExportStyle)style {
    NSSavePanel* savePanel = [NSSavePanel savePanel];
    savePanel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"wav"],
                                      [UTType typeWithFilenameExtension:@"aiff"],
                                      [UTType typeWithFilenameExtension:@"m4a"]];
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            SCExporter* exporter = [[SCExporter alloc] initWithURL:savePanel.URL style:style];
            exporter.renderer = self;
            exporter.numOfFrames = [SCAppController sharedInstance].synth.samplingFrameRate * self.composition.lengthInSeconds;
            [self prepareForPlay];
            [exporter exportWithSynth:[SCAppController sharedInstance].synth completionHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.window endSheet:self.progressPanel];
                });
            } updateHandler:^(int framesWrote) {
                self.progressBar.maxValue = exporter.numOfFrames;
                self.progressBar.doubleValue = framesWrote;
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.window beginSheet:self.progressPanel completionHandler:^(NSModalResponse response) {
                    [self.progressPanel orderOut:self];
                }];
            });   
        }
    }];
}
- (void)exportProgressPanelDidEnd:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    [sheet orderOut:self];
}

#pragma mark Settings
- (IBAction)openSettings:(id)sender {
    [self.tempoSlider setFloatValue:self.composition.tempo];
    [self.tempoLabel takeFloatValueFrom:self.tempoSlider];
    
    [self.barsText setIntegerValue:self.composition.bars];
    [self.barsStepper takeIntegerValueFrom:self.barsText];
    
    [self.window beginSheet:self.settingsSheet completionHandler:^(NSModalResponse response) {
        [self.settingsSheet orderOut:self];
    }];
}
- (IBAction)closeSettings:(id)sender {
    self.composition.tempo = self.tempoSlider.floatValue;
    self.composition.bars = (UInt32)MAX(1, self.barsStepper.integerValue);
    [self.window endSheet:self.settingsSheet];
    
    [self resizePianoRoll];
}
- (void)settingsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    [sheet orderOut:self];
}

#pragma mark Editor
- (void)pianoRollDidUpdate:(id)sender {
    self.composition.notes = ((SCPianoRoll*)sender).notes;
    [self.composition updateChangeCount:NSChangeDone];
}
- (void)pianoRollXScaleSliderDidUpdate:(id)sender {
    pianoRoll.gridHorizontalInterval = [sender floatValue];
    [self resizePianoRoll];
}
- (void)resizePianoRoll {
    CGRect originalFrame = pianoRoll.frame;
    originalFrame.size.width = pianoRoll.gridHorizontalInterval * 4 * self.composition.bars;
    pianoRoll.frame = originalFrame;
}
@end
