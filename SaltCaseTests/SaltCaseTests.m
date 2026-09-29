//
//  SaltCaseTests.m
//  SaltCaseTests
//
//  Created by Sota Yokoe on 7/8/12.
//  Copyright (c) 2012 Pankaku Inc. All rights reserved.
//

#import "SaltCaseTests.h"
#import "SCDocument.h"
#import "SCNote.h"
#import "SCAudioEvent.h"
#import "SCPitchUtil.h"

@implementation SaltCaseTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

// Tempo property has a range limitation (40.0f - 320.0f)
- (void)testCompositionTempoRangeLimitation
{
    SCDocument* composition = [[SCDocument alloc] init];
    composition.tempo = 120.0f;
    XCTAssertEqual(composition.tempo, 120.0f, @"Tempo can be set to 120.0f");
    composition.tempo = -50.0f;
    XCTAssertFalse(composition.tempo == -50.0f, @"Negative tempo cannot be set.");
    XCTAssertTrue(composition.tempo > 0.0f, @"Tempo cannot be negative.");
    composition.tempo = 10000.0f;
    XCTAssertFalse(composition.tempo == 10000.0f, @"Tremenderous tempo cannot be set.");
    XCTAssertTrue(composition.tempo <= 320.0f, @"Tempo should be smaller than 320.0f");
}

- (void)testAudioEventOptimization
{
    SCDocument* composition = [[SCDocument alloc] init];
    XCTAssertEqual(composition.notes.count, (NSUInteger)0, @"There should be no notes when a new composition is created.");
    XCTAssertEqual(composition.audioEvents.count, (NSUInteger)0, @"There should be no events when no notes are set.");
    
    SCNote* note = [[SCNote alloc] init];
    note.startsAt = 1.0f;
    note.length = 0.5f;
    composition.notes = [NSArray arrayWithObject:note];
    XCTAssertEqual(composition.notes.count, (NSUInteger)1, @"There should be 1 event.");
    XCTAssertEqual(composition.audioEvents.count, (NSUInteger)2, @"There should be 2 events (on and off).");
}
- (void)testAudioEventOptimizationWithNoOverlappedNotes {
    SCDocument* composition = [[SCDocument alloc] init];
    
    SCNote* note1 = [[SCNote alloc] init];
    note1.startsAt = 1.0f;
    note1.length = 0.5f;
    
    SCNote* note2 = [[SCNote alloc] init];
    note2.startsAt = 2.0f;
    note2.length = 0.5f;
    
    composition.notes = [NSArray arrayWithObjects:note1, note2, nil];
    XCTAssertEqual(composition.notes.count, (NSUInteger)2, @"There should be 2 event.");
    XCTAssertEqual(composition.audioEvents.count, (NSUInteger)4, @"There should be 4 events (on and off for each note).");
}
- (void)testAudioEventOptimizationWithOverlappedNotes {
    SCDocument* composition = [[SCDocument alloc] init];
    
    SCNote* note1 = [[SCNote alloc] init];
    note1.startsAt = 1.0f;
    note1.length = 1.5f;
    
    SCNote* note2 = [[SCNote alloc] init];
    note2.startsAt = 2.0f;
    note2.length = 0.5f;
    
    composition.notes = [NSArray arrayWithObjects:note1, note2, nil];
    XCTAssertEqual(composition.notes.count, (NSUInteger)2, @"There should be 2 event.");
    
    int numberOfNoteOn = 0;
    int numberOfNoteOff = 0;
    for (SCAudioEvent* event in composition.audioEvents) {
        if (event.type == SCAudioEventNoteOn) numberOfNoteOn++;
        if (event.type == SCAudioEventNoteOff) numberOfNoteOff++;
    }
    XCTAssertEqual(numberOfNoteOn, 1, @"Overlapped notes should be treated as one note. Only 1 'on' event should exist.");
    XCTAssertEqual(numberOfNoteOff, 1, @"Overlapped notes should be treated as one note. Only 1 'off' event should exist.");
}

- (void)testLengthCalculation {
    SCDocument* composition = [[SCDocument alloc] init];
    composition.tempo = 60.0f;
    composition.bars = 1;
    XCTAssertTrue(abs(composition.lengthInSeconds - 4.0) <= 0.01, @"60bpm 4beats should be 4.0 secs.");
    
    composition.tempo = 120.0f;
    XCTAssertTrue(abs(composition.lengthInSeconds - 2.0) <= 0.01, @"120bpm 4beats should be 2.0 secs.");
    
    composition.bars = 2;
    XCTAssertTrue(abs(composition.lengthInSeconds - 4.0) <= 0.01, @"120bpm 8beats should be 4.0 secs.");
}

- (void)testExpressionAndPhonemePersistence {
    SCDocument* original = [[SCDocument alloc] init];
    SCNote* note = [[SCNote alloc] init];
    note.startsAt = 0.0f;
    note.length = 1.0f;
    note.pitch = 12;
    note.text = @"ら";
    note.phoneme = @"ra";
    note.volume = 0.72f;
    note.vibrato = 0.35f;
    note.pitchBend = -0.2f;
    original.notes = @[note];

    NSError* writeError = nil;
    NSData* data = [original dataOfType:@"saltcase" error:&writeError];
    XCTAssertNil(writeError);
    XCTAssertNotNil(data);

    SCDocument* restored = [[SCDocument alloc] init];
    NSError* readError = nil;
    XCTAssertTrue([restored readFromData:data ofType:@"saltcase" error:&readError]);
    XCTAssertNil(readError);
    SCNote* restoredNote = restored.notes.firstObject;
    XCTAssertEqualObjects(restoredNote.phoneme, @"ra");
    XCTAssertEqualWithAccuracy(restoredNote.volume, 0.72f, 0.001f);
    XCTAssertEqualWithAccuracy(restoredNote.vibrato, 0.35f, 0.001f);
    XCTAssertEqualWithAccuracy(restoredNote.pitchBend, -0.2f, 0.001f);
}

- (void)testAudioEventUsesPhonemeAndVelocity {
    SCDocument* composition = [[SCDocument alloc] init];
    SCNote* note = [[SCNote alloc] init];
    note.startsAt = 0.0f;
    note.length = 1.0f;
    note.text = @"ら";
    note.phoneme = @"ra";
    note.volume = 0.64f;
    composition.notes = @[note];

    SCAudioEvent* startEvent = composition.audioEvents.firstObject;
    XCTAssertEqualObjects(startEvent.text, @"ra");
    XCTAssertEqualWithAccuracy(startEvent.velocity, 0.64f, 0.001f);
}

- (void)testPitchBendChangesAudioFrequency {
    SCDocument* composition = [[SCDocument alloc] init];
    SCNote* note = [[SCNote alloc] init];
    note.startsAt = 0.0f;
    note.length = 1.0f;
    note.pitch = 12;
    note.pitchBend = 1.0f;
    composition.notes = @[note];

    SCAudioEvent* event = composition.audioEvents.firstObject;
    float baseFrequency = [SCPitchUtil frequencyOfPitch:12];
    XCTAssertEqualWithAccuracy(event.frequency, baseFrequency * powf(2.0f, 1.0f / 12.0f), 0.01f);
}

- (void)testExpressionValuesAreClamped {
    SCNote* note = [[SCNote alloc] init];
    note.volume = 2.0f;
    note.vibrato = -1.0f;
    note.pitchBend = 4.0f;
    XCTAssertEqualWithAccuracy(note.volume, 1.0f, 0.001f);
    XCTAssertEqualWithAccuracy(note.vibrato, 0.0f, 0.001f);
    XCTAssertEqualWithAccuracy(note.pitchBend, 1.0f, 0.001f);
}

- (void)testProjectFormatVersionIsWritten {
    SCDocument* composition = [[SCDocument alloc] init];
    NSData* data = [composition dataOfType:@"saltcase" error:nil];
    NSDictionary* project = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertEqual([project[@"header"][@"formatVersion"] integerValue], 2);
}
- (void)testFutureProjectFormatIsRejected {
    NSDictionary* project = @{
        @"header": @{@"formatVersion": @999, @"tempo": @120, @"bars": @8},
        @"notes": @[]
    };
    NSData* data = [NSJSONSerialization dataWithJSONObject:project options:0 error:nil];
    SCDocument* composition = [[SCDocument alloc] init];
    NSError* error = nil;
    XCTAssertFalse([composition readFromData:data ofType:@"saltcase" error:&error]);
    XCTAssertEqual(error.code, 1001);
}

- (void)testUSTXImportReadsBasicNotes {
    NSString* ustx = @"bpm: 132\nnotes:\n- position: 480\n  duration: 240\n  tone: 64\n  lyric: la\n";
    SCDocument* composition = [[SCDocument alloc] init];
    NSError* error = nil;
    XCTAssertTrue([composition readFromData:[ustx dataUsingEncoding:NSUTF8StringEncoding]
                                     ofType:@"ustx" error:&error]);
    XCTAssertNil(error);
    XCTAssertEqualWithAccuracy(composition.tempo, 132.0f, 0.001f);
    XCTAssertEqual(composition.notes.count, 1);
    SCNote* note = composition.notes.firstObject;
    XCTAssertEqualWithAccuracy(note.startsAt, 480.0, 0.001);
    XCTAssertEqual(note.pitch, 64);
    XCTAssertEqualObjects(note.text, @"la");
}
@end
