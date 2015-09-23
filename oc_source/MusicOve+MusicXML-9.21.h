//
//  MusicOve+MusicXML.h
//  ReadStaff
//
//  Created by yan bin on 13-4-19.
//
//

#import "MusicOve.h"
//
//@interface MidiXmlMeasure : NSObject
//@property (nonatomic, assign) int meas_start_tick, meas_tick_size;
//@property (nonatomic, strong) NSMutableArray *notes;//array of MidiXmlNotes
//@end
//
//@interface MidiXmlNotes : NSObject
//@property (nonatomic, assign) int meas_start_tick, meas_tick_size;
//@property (nonatomic, strong) NSMutableArray *elements;//array of MidiXmlElement
//@end
//
//@interface MidiXmlElement : NSObject
////tick, evt, n, v, measure_index, note_index, staff, line, isRest,finger
//@property (nonatomic, assign) int tick, evt, n,v;
//@property (nonatomic, assign) int measure_index, note_index, staff, line, isRest, finger;
//@end

@interface OveMusic (MusicXML)
+ (OveMusic*)loadXMLMusic:(NSString*)file folder:(NSString *)folder;
+ (OveMusic*)loadFromXMLData:(NSData*)xml_data midiData:(NSData*)midi_data;
+ (OveMusic*)loadFromMXLFile:(NSString*)mxlFilePath;
+ (NSDictionary*) getXmlMusicInfo:(NSString*)file folder:(NSString *)folder;
+ (MidiFile*)parseMidi:(NSData*)midi_data;
//- (void)loadAccompany:(NSData*)midi_data;
- (void)loadVideoMidi:(NSData*)midi_data;
- (NSArray*)getNoRepeatMidiEvents:(NSArray*)midiEvents;
@end
