//
//  SCDocument.m
//  SaltCase
//
//  Created by Sota Yokoe on 7/8/12.
//  Copyright (c) 2012 Pankaku Inc. All rights reserved.
//

#import "SCDocument.h"
#import "SCAppController.h"
#import "SCCompositionController.h"
#import "SCNote.h"
#import "SCAudioEvent.h"
#import "SCPitchUtil.h"
#import <AudioToolbox/AudioToolbox.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

const float kSCDefaultTempo = 120.0f;
const float kSCMinimumTempo = 40.0f;
const float kSCMaximumTempo = 320.0f;
const float kSCGliderTransitionControlInterval = 0.001f;
const float kSCDefaultBars = 8;
static const NSInteger kSCProjectFormatVersion = 2;

NSComparisonResult (^noteSortComparator)(id,id) = ^(id obj1, id obj2) {
    SCNote* note1 = obj1;
    SCNote* note2 = obj2;
    if (note1.startsAt > note2.startsAt) {
        return NSOrderedDescending;
    } else if (note1.startsAt < note2.startsAt) {
        return NSOrderedAscending;
    } else {
        return NSOrderedSame;
    }
};
NSComparisonResult (^eventSortComparator)(id,id) = ^(id obj1, id obj2) {
    SCAudioEvent* ev1 = obj1;
    SCAudioEvent* ev2 = obj2;
    if (ev1.timing > ev2.timing) {
        return NSOrderedDescending;
    } else if (ev1.timing < ev2.timing) {
        return NSOrderedAscending;
    } else {
        return NSOrderedSame;
    }
};

static NSArray* SCNotesFromMusicSequence(MusicSequence sequence) {
    NSMutableArray* imported = [NSMutableArray array];
    UInt32 trackCount = 0;
    MusicSequenceGetTrackCount(sequence, &trackCount);
    for (UInt32 trackIndex = 0; trackIndex < trackCount; trackIndex++) {
        MusicTrack track = NULL;
        MusicSequenceGetIndTrack(sequence, trackIndex, &track);
        MusicEventIterator iterator = NULL;
        NewMusicEventIterator(track, &iterator);
        MusicTimeStamp timestamp = 0;
        while (YES) {
            MusicEventType type;
            const void* eventData = NULL;
            UInt32 size = 0;
            MusicEventIteratorGetEventInfo(iterator, &timestamp, &type, &eventData, &size);
            if (type == kMusicEventType_MIDINoteMessage && size >= sizeof(MIDINoteMessage)) {
                MIDINoteMessage message = *(const MIDINoteMessage*)eventData;
                SCNote* note = [[SCNote alloc] init];
                note.startsAt = timestamp;
                note.length = message.duration;
                note.pitch = message.note;
                note.volume = message.velocity / 127.0f;
                [imported addObject:note];
            }
            Boolean current = NO;
            MusicEventIteratorHasCurrentEvent(iterator, &current);
            if (!current) break;
            MusicEventIteratorNextEvent(iterator);
        }
        DisposeMusicEventIterator(iterator);
    }
    return imported;
}

static NSArray* SCNotesFromUSTXData(NSData* data, float* tempoOut) {
    NSString* source = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!source) return nil;
    NSMutableArray* notes = [NSMutableArray array];
    NSArray* lines = [source componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    SCNote* current = nil;
    for (NSString* rawLine in lines) {
        NSString* line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([line hasPrefix:@"bpm:"]) {
            if (tempoOut) *tempoOut = [[line substringFromIndex:4] floatValue];
        } else if ([line hasPrefix:@"- position:"]) {
            current = [[SCNote alloc] init];
            current.startsAt = [[line substringFromIndex:11] doubleValue];
            [notes addObject:current];
        } else if (current && [line hasPrefix:@"duration:"]) {
            current.length = [[line substringFromIndex:9] doubleValue];
        } else if (current && [line hasPrefix:@"tone:"]) {
            current.pitch = [[line substringFromIndex:5] intValue];
        } else if (current && [line hasPrefix:@"lyric:"]) {
            NSString* lyric = [[line substringFromIndex:6] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([lyric hasPrefix:@"\""] && [lyric hasSuffix:@"\""]) lyric = [lyric substringWithRange:NSMakeRange(1, lyric.length - 2)];
            current.text = lyric;
        }
    }
    return notes;
}

@implementation SCDocument

- (void)setTempo:(float)tempo {
    // Range limitation: 40.0f - 320.0f
    _tempo = fminf(fmaxf(kSCMinimumTempo, tempo), kSCMaximumTempo);
}
- (NSTimeInterval)lengthInSeconds {
    return 60.0f / self.tempo * self.bars * 4;
}

- (SCNote*)noteAfter:(SCNote*)noteBefore {
    SCNote* nextNote = nil;
    BOOL isNext = NO;
    for (SCNote* note in [self.notes sortedArrayUsingComparator:noteSortComparator]) {
        if (isNext) return note;
        if (note == noteBefore) isNext = YES;
    }
    return nextNote;
}
- (NSArray*)audioEvents {
    NSMutableArray* events = [NSMutableArray array];
    for (SCNote* note in self.notes) {
        { // Start
            SCAudioEvent* event = [[SCAudioEvent alloc] init];
            event.text = note.phoneme.length > 0 ? note.phoneme : note.text;
            event.velocity = note.volume > 0.0f ? note.volume : 1.0f;
            event.timing = [note startsAtSecondsInTempo:self.tempo];
            event.type = SCAudioEventNoteOn;
            event.pitch = note.pitch;
            event.frequency = [SCPitchUtil frequencyOfPitch:event.pitch] * powf(2.0f, note.pitchBend / 12.0f);
            event.note = note;
            [events addObject:event];
        }
        
        { // End
            SCAudioEvent* event = [[SCAudioEvent alloc] init];
            event.timing = [note endsAtSecondsInTempo:self.tempo];
            event.type = SCAudioEventNoteOff;
            event.note = note;
            event.frequency = [SCPitchUtil frequencyOfPitch:event.pitch] * powf(2.0f, note.pitchBend / 12.0f);
            [events addObject:event];
        }
    }
    [events sortUsingComparator:eventSortComparator];
    
    // Enable glider
    NSMutableArray* notesOn = [NSMutableArray array];
    NSMutableArray* eventsToRemove = [NSMutableArray array];
    NSMutableArray* eventsToAdd = [NSMutableArray array];
    for (SCAudioEvent* event in events) {
        if (event.type == SCAudioEventNoteOn) {
            if (notesOn.count > 0) {
                event.type = SCAudioEventPitchChange;
                event.pitch = ((SCNote*)[notesOn lastObject]).pitch;
                SCNote* activeNote = [notesOn lastObject];
                event.frequency = [SCPitchUtil frequencyOfPitch:event.pitch] * powf(2.0f, activeNote.pitchBend / 12.0f);
            }
            
            [notesOn addObject:event.note];
            
        }
        if (event.type == SCAudioEventNoteOff) {
            [notesOn removeObject:event.note];
            
            if (notesOn.count > 0) {
                event.type = SCAudioEventPitchChange;
                event.pitch = ((SCNote*)[notesOn lastObject]).pitch;
                SCNote* activeNote = [notesOn lastObject];
                event.frequency = [SCPitchUtil frequencyOfPitch:event.pitch] * powf(2.0f, activeNote.pitchBend / 12.0f);
                
                SCNote* thisNote = event.note;
                SCNote* nextNote = [self noteAfter:thisNote]; // Currently playing
                
                if (nextNote) {                    
                    NSTimeInterval transitionLength = [thisNote endsAtSecondsInTempo:self.tempo] - [nextNote startsAtSecondsInTempo:self.tempo];
                    if (transitionLength >= 0.0f) {
                        for (float t = 0.0f; t < transitionLength; t += kSCGliderTransitionControlInterval) {
                            SCAudioEvent* pitchChangeEvent = [[SCAudioEvent alloc] init];
                            pitchChangeEvent.type = SCAudioEventPitchChange;
                            
                            float p = t / transitionLength;
                            
                            float nextFrequency = [SCPitchUtil frequencyOfPitch:nextNote.pitch] * powf(2.0f, nextNote.pitchBend / 12.0f);
                            float currentFrequency = [SCPitchUtil frequencyOfPitch:thisNote.pitch] * powf(2.0f, thisNote.pitchBend / 12.0f);
                            pitchChangeEvent.frequency = nextFrequency * p + currentFrequency * (1.0f - p);
                            pitchChangeEvent.timing = [nextNote startsAtSecondsInTempo:self.tempo] + t;
                            [eventsToAdd addObject:pitchChangeEvent];
                        }
                    }
                } else {
                    NSLog(@"Error no note after %@", thisNote);
                }
            }
        }
    }
    [events removeObjectsInArray:eventsToRemove];
    [events addObjectsFromArray:eventsToAdd];
    [events sortUsingComparator:eventSortComparator];
    
    return events;
}

- (id)init
{
    self = [super init];
    if (self) {
        // Default composition settings.
        self.tempo = kSCDefaultTempo;
        self.bars = kSCDefaultBars;
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"SCDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

+ (BOOL)autosavesInPlace
{
    return YES;
}
- (NSData*)dataOfType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    NSMutableDictionary* header = [NSMutableDictionary dictionary];
    dictionary[@"header"] = header;
    
    header[@"formatVersion"] = @(kSCProjectFormatVersion);
    header[@"tempo"] = @(self.tempo);
    header[@"bars"] = @(self.bars);
    
    NSMutableArray* noteDictionaries = [NSMutableArray array];
    for (SCNote* note in self.notes) {
        [noteDictionaries addObject:[note dictionaryRepresentation]];
    }
    dictionary[@"notes"] = noteDictionaries;
    
    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:&error];
    if (error == nil) {
        return data;
    } else {
        NSLog(@"Failed to prepare data.");
        return nil;
    }
}
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
    NSString* fileType = self.fileURL.pathExtension.lowercaseString;
    if (fileType.length == 0) fileType = typeName.lowercaseString;
    if ([fileType isEqualToString:@"mid"] || [fileType isEqualToString:@"midi"]) {
        MusicSequence sequence = NULL;
        OSStatus status = NewMusicSequence(&sequence);
        if (status == noErr) status = MusicSequenceFileLoadData(sequence, (__bridge CFDataRef)data,
                                                                  kMusicSequenceFile_MIDIType,
                                                                  kMusicSequenceLoadSMF_ChannelsToTracks);
        if (status == noErr) {
            self.notes = SCNotesFromMusicSequence(sequence);
            double endPosition = 0.0;
            for (SCNote* note in self.notes) endPosition = MAX(endPosition, note.startsAt + note.length);
            self.bars = MAX(1, (UInt32)ceil(endPosition / 4.0));
            DisposeMusicSequence(sequence);
            return YES;
        }
        if (sequence) DisposeMusicSequence(sequence);
        if (outError) *outError = [NSError errorWithDomain:@"SaltCaseImport" code:status
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Não foi possível abrir o arquivo MIDI."}];
        return NO;
    }
    if ([fileType isEqualToString:@"usxt"]) {
        float importedTempo = kSCDefaultTempo;
        NSArray* importedNotes = SCNotesFromUSTXData(data, &importedTempo);
        if (!importedNotes) {
            if (outError) *outError = [NSError errorWithDomain:@"SaltCaseImport" code:1002
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Não foi possível ler o arquivo USTX."}];
            return NO;
        }
        self.tempo = importedTempo;
        self.notes = importedNotes;
        return YES;
    }
    NSError* error = nil;
    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (dictionary) {
        NSDictionary* header = dictionary[@"header"];
        if (header) {
            NSNumber* version = header[@"formatVersion"];
            if (version && version.integerValue > kSCProjectFormatVersion) {
                if (outError) *outError = [NSError errorWithDomain:@"SaltCaseProject"
                                                               code:1001
                                                           userInfo:@{NSLocalizedDescriptionKey: @"Este projeto foi criado por uma versão mais recente do SaltCase."}];
                return NO;
            }
            NSNumber* tempoValue = header[@"tempo"];
            if (tempoValue) self.tempo = tempoValue.floatValue;
            
            NSNumber* barsValue = header[@"bars"];
            if (barsValue) self.bars = (UInt32)MAX(1, barsValue.unsignedIntegerValue);
        } else {
            NSLog(@"Header section not found.\n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            return NO;
        }
        
        NSArray* noteArray = dictionary[@"notes"];
        if (noteArray) {
            NSMutableArray* notes_ = [NSMutableArray array];
            for (NSDictionary* noteDictionary in noteArray) {
                SCNote* note = [[SCNote alloc] initWithDictionary:noteDictionary];
                [notes_ addObject:note];
            }
            self.notes = notes_;
        }
        
        return YES;
    } else {
        NSLog(@"JSON parse error.");
        return NO;
    }
}

- (void)close {
    // Stop playing before closing the composition.
    if ([SCAppController sharedInstance].currentlyPlaying == self.controller) {
        [[SCAppController sharedInstance] stopComposition:self.controller];
    }
    
    [super close];
}

#pragma mark Export
- (IBAction)exportVocal:(id)sender{
    [self.controller exportWithStyle:SCExportVocalTrackOnly];
}
- (IBAction)exportAll:(id)sender{
    [self.controller exportWithStyle:SCExportAllTracks];
}

- (IBAction)importMIDI:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"mid"],
                                   [UTType typeWithFilenameExtension:@"midi"]];
    [panel beginSheetModalForWindow:self.controller.window completionHandler:^(NSInteger result) {
        if (result != NSModalResponseOK) return;
        MusicSequence sequence = NULL;
        OSStatus status = NewMusicSequence(&sequence);
        if (status != noErr) return;
        status = MusicSequenceFileLoad(sequence, (__bridge CFURLRef)panel.URL, 0, kMusicSequenceLoadSMF_ChannelsToTracks);
        if (status == noErr) {
            BOOL hasEvent = NO;
            NSMutableArray* imported = [NSMutableArray array];
            UInt32 trackCount = 0;
            MusicSequenceGetTrackCount(sequence, &trackCount);
            for (UInt32 trackIndex = 0; trackIndex < trackCount; trackIndex++) {
                MusicTrack track = NULL;
                MusicSequenceGetIndTrack(sequence, trackIndex, &track);
                MusicEventIterator iterator = NULL;
                NewMusicEventIterator(track, &iterator);
                MusicTimeStamp timestamp = 0;
                while (YES) {
                    MusicEventType type;
                    const void* data = NULL;
                    UInt32 size = 0;
                    MusicEventIteratorGetEventInfo(iterator, &timestamp, &type, &data, &size);
                    if (type == kMusicEventType_MIDINoteMessage && size >= sizeof(MIDINoteMessage)) {
                        MIDINoteMessage message = *(const MIDINoteMessage*)data;
                        SCNote* note = [[SCNote alloc] init];
                        note.startsAt = timestamp;
                        note.length = message.duration;
                        note.pitch = message.note;
                        note.volume = message.velocity / 127.0f;
                        [imported addObject:note];
                        hasEvent = YES;
                    }
                    Boolean current = NO;
                    MusicEventIteratorHasCurrentEvent(iterator, &current);
                    if (!current) break;
                    MusicEventIteratorNextEvent(iterator);
                }
                DisposeMusicEventIterator(iterator);
            }
            if (hasEvent) {
                self.notes = imported;
                [self.controller reloadEditor];
                [self updateChangeCount:NSChangeDone];
            }
        }
        DisposeMusicSequence(sequence);
    }];
}

- (IBAction)exportMIDI:(id)sender {
    NSSavePanel* panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"mid"]];
    [panel beginSheetModalForWindow:self.controller.window completionHandler:^(NSInteger result) {
        if (result != NSModalResponseOK) return;
        MusicSequence sequence = NULL;
        if (NewMusicSequence(&sequence) != noErr) return;
        MusicTrack track = NULL;
        MusicSequenceNewTrack(sequence, &track);
        MusicTrackNewExtendedTempoEvent(track, 0.0, self.tempo);
        for (SCNote* note in self.notes) {
            MIDINoteMessage message;
            message.channel = 0;
            message.note = note.pitch;
            message.velocity = (UInt8)fminf(127.0f, fmaxf(1.0f, note.volume * 127.0f));
            message.releaseVelocity = 0;
            message.duration = note.length;
            MusicTrackNewMIDINoteEvent(track, note.startsAt, &message);
        }
        MusicSequenceFileCreate(sequence, (__bridge CFURLRef)panel.URL, kMusicSequenceFile_MIDIType, kMusicSequenceFileFlags_EraseFile, 480);
        DisposeMusicSequence(sequence);
    }];
}

@end
