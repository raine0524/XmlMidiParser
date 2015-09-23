//
//  MidiFile.h
//  ReadStaff
//
//  Created by yan bin on 11-10-9.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BaseEvent : NSObject {
	int tick_;
}
@property (nonatomic, assign) int tick;
@property (nonatomic, assign) unsigned char track;
//- (BOOL) lessThan:(BaseEvent*)ev;
//- (BOOL) equ:(BaseEvent*)ev;

/*
bool operator<(const SpecificInfoEvent& ev) const {
    return tick_ < ev.tick_;
}
bool operator==(const SpecificInfoEvent& ev) const {
    return tick_ == ev.tick_;
}
 */
@end


//if evt=0xB0(Control change), nn is:
#define GM_Control_Modulation_Wheel 1
#define GM_Control_Volumel 7
#define GM_Control_Pan  10
#define GM_Control_Expression  11
#define GM_Control_Pedal 64
#define GM_Control_ResetAllControl 121
#define GM_Control_AllNotesOff  123

@interface Event : BaseEvent {
	//unsigned int event_; // channel event, a note on event 0x9xnnvv00 will be saved like 0x00vvnn9x
}
//@property (nonatomic, assign) unsigned int event;
@property (nonatomic, assign) unsigned char evt, nn, vv;
@property (nonatomic, strong) NSMutableDictionary *userdata;
@end

@interface TextEvent : BaseEvent {
	NSString *text_;
}
@property (nonatomic, strong) NSString* text;
@end
@interface SpecificInfoEvent : BaseEvent {
//    unsigned char infos_[100];
    NSMutableData *infos_;
}
@property (nonatomic, strong) NSMutableData *infos;
@end

@interface TempoEvent : BaseEvent {
	int tempo_; // microseconds/quarter note
}
@property (nonatomic, assign) int tempo;
@end

@interface TimeSignatureEvent : BaseEvent {
	int numerator_; // such as 2, 3, 4 etc, default=4
	int denominator_; //such as 2, 4, 8 etc 3/4 as numerator_/denominator_, default=4
	int number_ticks_;
	int number_32nd_notes_;
    
}
@property (nonatomic, assign) int numerator, denominator,number_ticks,number_32nd_notes;
@end

@interface KeySignatureEvent : BaseEvent {
	int sf_; //sf_=sharps/flats (-7=7 flats, 0=key of c,7=7 sharps)
	int mi_; //mi_=major/minor (0=major, 1=minor)
}
@property (nonatomic,assign) int sf, mi;
/*    
 bool operator<(const KeySignatureEvent& ev) const {
 return tick_ < ev.tick_;
 }
 bool operator==(const KeySignatureEvent& ev) const {
 return (tick_ == ev.tick_) && (sf_ == ev.sf_);
 }
 */
@end

@interface SysExclusiveEvent : BaseEvent {
//    unsigned char *event_[100];
    
	NSMutableData* event_;
    //QByteArray event_;
    /*
	bool operator <(const SysExclusiveEvent& ev) const {
		return tick_ < ev.tick_;
	}
	bool operator==(const SysExclusiveEvent& ev) const {
		return tick_ == ev.tick_;
	}
     */
}
@property (nonatomic, strong) NSMutableData* event;
@end

@interface ChordEvent : BaseEvent {
	unsigned int root_;
	unsigned int type_;
	unsigned int bass_;
    
//	ChordEvent() : tick_(0), root_(0), type_(0), bass_(0) {}
/*    
	bool operator <(const ChordEvent& ev) const {
		return tick_ < ev.tick_;
	}
	bool operator ==(const ChordEvent& ev) const {
		return (tick_ == ev.tick_) && (root_ == ev.root_) && (type_ == ev.type_);
	}
 */
}
@end

@interface ITrack : NSObject {
    int number_;
    NSString *name_;//track的名字
    NSString *instrument_;//track使用的乐器名，这是存储在midi文件中的一个字符串，跟track中的乐器事件没有一一对应关系
    
    NSMutableArray *events_;//BaseEvent
    NSMutableArray *lyrics_; //TextEvent
    NSMutableArray *specificEvents_; //SpecificInfoEvent
    NSMutableArray *texts_; //TextEvent
}
@property (nonatomic, assign) int number;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *instrument;
@property (nonatomic, readonly) NSMutableArray *events, *lyrics, *specificEvents, *texts;
-(bool) sort_events;

@end


@interface MidiFile : NSObject {
    
@private
    NSMutableArray *tempos_; //TempoEvent list
    NSMutableArray *timeSignatures_; //TimeSignatureEvent
    NSMutableArray *keySignatures_; //KeySignatureEvent
    NSMutableArray *sysExclusives_; //SysExclusiveEvent
    NSMutableArray *markers_;  //TextEvent
    NSMutableArray *cuePoints_; //TextEvent

    NSMutableArray *tracks_;//ITrack
    
    int format_;
    int quarter_;
    NSString *name_;
    NSString *author_;
    NSString *copyright_;
}
@property (nonatomic, strong) NSMutableArray *markers, *cuePoints, *tempos, *timeSignatures, *keySignatures, *sysExclusives, *tracks;
@property (nonatomic, assign) int quarter, format;
@property (nonatomic, strong) NSString *author, *name, *copyright;
@property (nonatomic, readonly) NSArray *mergedMidiEvents;

@property (nonatomic, strong) NSMutableDictionary *midiMeasureInfo; //key:meas_start_tick value:dict[mm, duration, note_ticks]
@property (nonatomic, assign) int midiLoseEvents;
@property (nonatomic, assign) BOOL onlyOneTrack;

- (ITrack*)getTrackPianoTrack;
- (double)secPerTick;

@end
