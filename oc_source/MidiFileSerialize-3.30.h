//
//  MidiFileSerialize.h
//  ReadStaff
//
//  Created by yan bin on 11-10-11.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MidiFile;
@class TextEvent, Event;
@class TempoEvent,SysExclusiveEvent,TimeSignatureEvent,KeySignatureEvent,SpecificInfoEvent;
@interface CommonEvent : NSObject {
    int tick_;
    NSMutableData *event_;
}
@property (nonatomic, assign) int tick;
@property (nonatomic, strong) NSMutableData *event;
@end

@interface CommonEventCreator : NSObject {
    NSMutableArray *items_; //
}
@property (nonatomic, strong) NSMutableArray *items;
- (void) addText:(NSString*)text style:(int)style;
- (void) addTextEvent:(TextEvent*)ev style:(int)style;
- (void) addTempoEvent:(TempoEvent*)ev;
- (void) addSysExclusiveEvent:(SysExclusiveEvent*)ev;
- (void) addTimeSignatureEvent:(TimeSignatureEvent*)ev;
- (void) addKeySignatureEvent:(KeySignatureEvent*)ev;
- (void) addSpecificInfoEvent:(SpecificInfoEvent*) ev;
- (void) addEvent:(Event*) ev;
- (void) sort;
- (void) absToRel;
@end


@interface MidiFileSerialize : NSObject {
    int buf_index;
    MidiFile *midi_;
}
- (MidiFile*)loadFromData:(NSData*)data;
- (MidiFile*)loadFromFile:(NSString*)file;
- (NSMutableData*)saveMidi:(MidiFile*)midi ToFile:(NSString*)file;

@end


