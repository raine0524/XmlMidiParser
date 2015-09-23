//
//  MusicOve.h
//  ReadStaff
//
//  Created by yan bin on 11-8-28.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface OveData : NSObject
@end

@interface OffsetElement : NSObject
@property (nonatomic, assign) signed short offset_x, offset_y;
@end

@interface OffsetCommonBlock : NSObject
@property (nonatomic,assign) signed short stop_measure,stop_offset;
@end

@interface CommonBlock : NSObject {
    unsigned char color;
}
@property (nonatomic,assign) signed short start_offset, tick;
@end

@interface PairEnds : NSObject
@property (nonatomic,assign) signed short left_line, right_line;
@end

typedef enum{
	Articulation_Major_Trill			= 0x00,
	Articulation_Minor_Trill			= 0x01,
	Articulation_Trill_Section			= 0x02,
	Articulation_Inverted_Short_Mordent	= 0x03,
	Articulation_Inverted_Long_Mordent	= 0x04,
	Articulation_Short_Mordent			= 0x05,
	Articulation_Turn					= 0x06,
//	Articulation_Finger_1				= 0x07,
//	Articulation_Finger_2				= 0x08,
//	Articulation_Finger_3				= 0x09,
//	Articulation_Finger_4				= 0x0A,
//	Articulation_Finger_5				= 0x0B,
    Articulation_Finger                 = 0x0B,
	Articulation_Flat_Accidental_For_Trill = 0x0C,
	Articulation_Sharp_Accidental_For_Trill = 0x0D,
	Articulation_Natural_Accidental_For_Trill = 0x0E,
	Articulation_Marcato				= 0x0F,
	Articulation_Marcato_Dot			= 0x10,
	Articulation_Heavy_Attack			= 0x11,
	Articulation_SForzando				= 0x12,
	Articulation_SForzando_Dot			= 0x13,
	Articulation_Heavier_Attack			= 0x14,
	Articulation_SForzando_Inverted		= 0x15,
	Articulation_SForzando_Dot_Inverted	= 0x16,
	Articulation_Staccatissimo			= 0x17,
	Articulation_Staccato				= 0x18,
	Articulation_Tenuto					= 0x19,
	Articulation_Up_Bow					= 0x1A,
	Articulation_Down_Bow				= 0x1B,
	Articulation_Up_Bow_Inverted		= 0x1C,
	Articulation_Down_Bow_Inverted		= 0x1D,
	Articulation_Arpeggio				= 0x1E, //琶音
	Articulation_Tremolo_Eighth			= 0x1F,
	Articulation_Tremolo_Sixteenth		= 0x20,
	Articulation_Tremolo_Thirty_Second	= 0x21,
	Articulation_Tremolo_Sixty_Fourth	= 0x22,
	Articulation_Natural_Harmonic		= 0x23,
	Articulation_Artificial_Harmonic	= 0x24,
	Articulation_Plus_Sign				= 0x25,
	Articulation_Fermata				= 0x26, //延长记号 (fermata)
	Articulation_Fermata_Inverted		= 0x27, //
	Articulation_Pedal_Down				= 0x28,
	Articulation_Pedal_Up				= 0x29,
	Articulation_Pause					= 0x2A,
	Articulation_Grand_Pause			= 0x2B,
	Articulation_Toe_Pedal				= 0x2C,
	Articulation_Heel_Pedal				= 0x2D,
	Articulation_Toe_To_Heel_Pedal		= 0x2E,
	Articulation_Heel_To_Toe_Pedal		= 0x2F,
	Articulation_Open_String			= 0x30,	// finger 0 in guitar or violin
	Articulation_Guitar_Lift			= 0x46,
	Articulation_Guitar_Slide_Up		= 0x47,
	Articulation_Guitar_Rip				= 0x48,
	Articulation_Guitar_Fall_Off		= 0x49,
	Articulation_Guitar_Slide_Down		= 0x4A,
	Articulation_Guitar_Spill			= 0x4B,
	Articulation_Guitar_Flip			= 0x4C,
	Articulation_Guitar_Smear			= 0x4D,
	Articulation_Guitar_Bend			= 0x4E,
	Articulation_Guitar_Doit			= 0x4F,
	Articulation_Guitar_Plop			= 0x50,
	Articulation_Guitar_Wow_Wow			= 0x51,
	Articulation_Guitar_Thumb			= 0x64,
	Articulation_Guitar_Index_Finger	= 0x65,
	Articulation_Guitar_Middle_Finger	= 0x66,
	Articulation_Guitar_Ring_Finger		= 0x67,
	Articulation_Guitar_Pinky_Finger	= 0x68,
	Articulation_Guitar_Tap				= 0x69,
	Articulation_Guitar_Hammer			= 0x6A,
	Articulation_Guitar_Pluck			= 0x6B,
    Articulation_Detached_Legato,
    
	Articulation_None
    
    /*	Articulation_Detached_Legato,
     Articulation_Spiccato,
     Articulation_Scoop,
     Articulation_Plop,
     Articulation_Doit,
     Articulation_Falloff,
     Articulation_Breath_Mark,
     Articulation_Caesura,*/
}ArticulationType;

typedef enum DecoratorType {
    Decorator_Dotted_Barline = 0,
    Decorator_Articulation
}DecoratorType;

@class OveNote;
@interface MeasureDecorators : NSObject {
    BOOL isMeasureRepeat;
	BOOL isSingleRepeat;
}
@property (nonatomic, assign) unsigned char decoratorType;
@property (nonatomic, assign) unsigned char artType;
@property (nonatomic, strong) NSString *finger;
@property (nonatomic, strong) CommonBlock *pos;
@property (nonatomic, assign) signed short offset_y;
@property (nonatomic, assign) short staff;
//to parse MusicXML
@property (nonatomic,assign) signed short xml_staff;
@property (nonatomic,weak) OveNote *xml_start_note;
@end

typedef enum  {
    Text_Rehearsal,
    Text_SystemText,
    Text_MeasureText
}TextType;

@interface OveText : NSObject {
    BOOL includeLineBreak;
    unsigned char ID;
    TextType textType;

    signed long width, height;
    // horizontal margin
    unsigned char horizontal_margin;
	// vertical margin
	unsigned char vertical_margin;
	// line thick
    unsigned char line_thick;
}
@property (nonatomic, assign) short staff;
@property (nonatomic, strong) CommonBlock *pos;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, assign) int offset_x, offset_y;
@property (nonatomic, assign) unsigned char font_size;
@property (nonatomic, assign) BOOL isItalic, isBold;
//to parse lilypond
@property (nonatomic, weak) OveNote *lily_note;
//to parse musicXML
@property (nonatomic, assign) int xml_start_note;
@end

@interface OveImage : NSObject
@property (nonatomic, assign) short staff;
@property (nonatomic, strong) CommonBlock *pos;
@property (nonatomic, strong) NSString *source;
@property (nonatomic, assign) short type; //application/postscript, image/gif, image/jpeg, image/png, and image/tiff
@property (nonatomic, assign) int offset_x, offset_y, width, height;
@end

@interface MeasureExpressions : NSObject {
    signed short barOffset;
    unsigned short tempo1;
    unsigned short tempo2;
}
@property (nonatomic,strong) CommonBlock *pos;
@property (nonatomic,assign) signed short offset_y;
@property (nonatomic,strong) NSString *exp_text;
@property (nonatomic,assign) short staff;
@end


typedef enum{
    //打击乐 percussion note head define
    NoteHead_Standard	= 0x00, //标准
    NoteHead_Invisible,
    NoteHead_Rhythmic_Slash,    //
    NoteHead_Percussion,        //一个圆圈一个叉 Open Hi Hat	吊镲／重音镲
    NoteHead_Closed_Rhythm,     //一个叉 Closed Hi-hat
    NoteHead_Open_Rhythm,
    NoteHead_Closed_Slash,
    NoteHead_Open_Slash,
    NoteHead_Closed_Do,
    NoteHead_Open_Do,
    NoteHead_Closed_Re,
    NoteHead_Open_Re,
    NoteHead_Closed_Mi,
    NoteHead_Open_Mi,
    NoteHead_Closed_Fa,
    NoteHead_Open_Fa,
    NoteHead_Closed_Sol,
    NoteHead_Open_Sol,
    NoteHead_Closed_La,
    NoteHead_Open_La,
    NoteHead_Closed_Ti,
    NoteHead_Open_Ti,
    //guitar note head define
    NoteHead_Guitar_0=0x20,
    NoteHead_Guitar_1=0x21,
    NoteHead_Guitar_2=0x22,
    NoteHead_Guitar_3=0x23,
    NoteHead_Guitar_4=0x24,
    NoteHead_Guitar_5=0x25,
}NoteHeadType;

typedef enum {
	Tie_None		= 0x0,
	Tie_LeftEnd		= 0x1,
	Tie_RightEnd	= 0x2
}TiePos;

typedef enum 
{
    Velocity_Offset,
    Velocity_SetValue,
    Velocity_Percentage
}VelocityType;
typedef enum  {
	Accidental_Normal				= 0x0,
	Accidental_Sharp				= 0x1,
	Accidental_Flat					= 0x2,
	Accidental_Natural				= 0x3,
	Accidental_DoubleSharp			= 0x4,
	Accidental_DoubleFlat			= 0x5,
	Accidental_Sharp_Caution		= 0x9,
	Accidental_Flat_Caution			= 0xA,
	Accidental_Natural_Caution		= 0xB,
	Accidental_DoubleSharp_Caution	= 0xC,
	Accidental_DoubleFlat_Caution	= 0xD
}AccidentalType;
typedef enum  {
	Note_DoubleWhole= 0x0,
	Note_Whole		= 0x1,
	Note_Half		= 0x2,
	Note_Quarter	= 0x3,
	Note_Eight		= 0x4,
	Note_Sixteen	= 0x5,
	Note_32			= 0x6,
	Note_64			= 0x7,
	Note_128		= 0x8,
	Note_256		= 0x9,
    
	Note_None
}NoteType;


typedef enum  {
    Clef_Treble = 0x00,	//0x00
    Clef_Bass,			//0x01
    Clef_Alto,			//0x02
    Clef_UpAlto,		//0x03
    Clef_DownDownAlto,	//0x04
    Clef_DownAlto,		//0x05
    Clef_UpUpAlto,		//0x06
    Clef_Treble8va,		//0x07
    Clef_Bass8va,		//0x08
    Clef_Treble8vb,		//0x09
    Clef_Bass8vb,		//0x0A
    Clef_Percussion1,	//0x0B //打击乐器
    Clef_Percussion2,	//0x0C
    Clef_TAB			//0x0D
}ClefType;

@interface MeasureClef : NSObject {
    unsigned short voice;
    signed char line;
}
@property (nonatomic, assign) unsigned short staff, note_index;
@property (nonatomic, strong) CommonBlock *pos;
@property (nonatomic, assign) unsigned char clef;
//xml
//@property (nonatomic, strong) OveNote *xml_note;
@property (nonatomic, assign) int xml_note;
@property (nonatomic, assign) BOOL xml_scaned;
@end

typedef enum  {
    Dynamics_pppp = 0,
    Dynamics_ppp,   //最弱
    Dynamics_pp,    //Pianissimo (pp) 很弱
    Dynamics_p,     //Piano (p) 弱
    Dynamics_mp,    //Mezzo Piano (mp) 中弱
    Dynamics_mf,    //Mezzo Forte (mf) 中强
    Dynamics_f,     //Forte (f) 强
    Dynamics_ff,    //Fortissimo (ff) 很强
    Dynamics_fff,   //最强
    Dynamics_ffff,
    Dynamics_sf,    //Sforzando (sf) 突强
    Dynamics_sff,    //Sforzando (sff) 突强
    Dynamics_fz,    //突强:该音比其他音要重一些
    Dynamics_sfz,   //突强
    Dynamics_sffz,  //突强
    Dynamics_fp,    //Fortepiano (fp) 强后突弱
    Dynamics_sfp    //特强后突然弱
}DynamicsType;

@interface  OveDynamic: NSObject {
}
@property (nonatomic,assign) unsigned char dynamics_type;
@property (nonatomic,strong) CommonBlock *pos;
@property (nonatomic,assign) signed short offset_y;
@property (nonatomic,assign) short staff;
@property (nonatomic,assign) BOOL playback;
@property (nonatomic,assign) unsigned char velocity;
//to parse MusicXML
//@property (nonatomic,strong) OveNote *xml_note;
@property (nonatomic,assign) int xml_note;
//to parse Lilypond
@property (nonatomic,weak) OveNote *lily_note;
@end

@interface NoteElem : NSObject
{
    int clefMiddleTone,clefMiddleOctave;
    unsigned char off_velocity;
}
@property (nonatomic,assign) unsigned char accidental_type;//AccidentalType
@property (nonatomic,assign) unsigned char head_type;//HeadType
@property (nonatomic,assign) unsigned char tie_pos;//TiePos
@property (nonatomic,assign) unsigned char velocity;//0-127
@property (nonatomic,assign) short offset_tick;
@property (nonatomic,assign) unsigned short length_tick;
@property (nonatomic,assign) signed char note;
@property (nonatomic,assign) signed char line;
@property (nonatomic,assign) signed char offsetStaff;// offset staff, in {-1, 0, 1}
//to play note
@property (nonatomic, assign) BOOL dontPlay,rightHand;
//to parse lilypond
@property (nonatomic, assign) char lily_finger; //0:none, 1-5
@property (nonatomic, assign) char lily_finger_placement; //0:beloa, 1:above, 2:auto
@property (nonatomic, assign) BOOL lily_accidental_attention;
//to parse MusickXML
@property (nonatomic,strong) NSMutableArray *xml_ties; //Tie: key=number, value=dict[type(start|stop),orientation(under|over)]
@property (nonatomic,assign) unsigned char xml_pitch_octave; //0-9
@property (nonatomic,assign) unsigned char xml_pitch_step; //1-7=CDEFGAB
@property (nonatomic,assign) signed char xml_pitch_alter;//-1,0,1
@property (nonatomic,strong) NSString *xml_finger;
//to display note
@property (nonatomic,assign) int display_x,display_y; //符头的左上角坐标
@property (nonatomic, assign) BOOL display_revert, tapped;
@end

typedef enum : NSUInteger {
    ArtPos_Down=0,
    ArtPos_Above,
    ArtPos_Left,
    ArtPos_Right,
} ArticulationPos;

@interface NoteArticulation : NSObject
{
    bool changeSoundEffect;
    //trill
    unsigned char auxiliary_first;
}
@property (nonatomic,assign) ArticulationType art_type;//ArticulationType

@property (nonatomic,assign) BOOL art_placement_above;
@property (nonatomic,strong) OffsetElement *offset;

@property (nonatomic, assign) AccidentalType accidental_mark;

//trill
@property (nonatomic,assign) BOOL has_wavy_line;
@property (nonatomic,assign) int wavy_stop_measure, wavy_stop_note, wavy_number;
@property (nonatomic,assign) int trill_num_of_32nd;
@property (nonatomic,assign) NoteType trillNoteType;//NoteType
@property (nonatomic,assign) unsigned char trill_interval;
//finger
@property (nonatomic,strong) NSString *finger, *alterFinger;
@property (nonatomic,assign) ArticulationPos finger_pos;

//changeVelocity
@property (nonatomic,assign) BOOL changeVelocity;
@property (nonatomic,assign) unsigned short velocity_value;
@property (nonatomic,assign) unsigned char velocity_type;//VelocityType
//changeLength
@property (nonatomic,assign) BOOL changeLength;
@property (nonatomic,assign) unsigned char length_percentage;
//changeSoundEffect
@property (nonatomic,assign) signed short sound_effect_from, sound_effect_to;
//to parse lilypond
@property (nonatomic,assign) BOOL lily_placement_auto;
@end

typedef enum  {
    OctaveShift_None=-1,
    
	OctaveShift_8_Continue = 0,
	OctaveShift_Minus_8_Continue,
	OctaveShift_15_Continue,
	OctaveShift_Minus_15_Continue,
    
	OctaveShift_8_Stop,
	OctaveShift_Minus_8_Stop,
	OctaveShift_15_Stop,
	OctaveShift_Minus_15_Stop,
    
    OctaveShift_8_Start,
	OctaveShift_Minus_8_Start,
	OctaveShift_15_Start,
	OctaveShift_Minus_15_Start,
    
    OctaveShift_8_StartStop,
	OctaveShift_Minus_8_StartStop,
	OctaveShift_15_StartStop,
	OctaveShift_Minus_15_StartStop,
}OctaveShiftType;
@class OveNote;
@interface OctaveShift : NSObject
@property (nonatomic, strong) CommonBlock *pos;
@property (nonatomic, assign) OctaveShiftType octaveShiftType;//OctaveShiftType
@property (nonatomic, assign) unsigned short length, end_tick;
@property (nonatomic, assign) signed short offset_y;
@property (nonatomic, assign) short staff;
//to parse MusicXML
@property (nonatomic,assign) int xml_note;
@end

@interface OveNote : NSObject {
    BOOL isRaw;
    BOOL isCue;
    unsigned char noteCount;
    unsigned char artCount;
    NoteType grace_note_type;
    unsigned char tupletSpace;
    //stem 符干
    int stemOffset;
}
@property (nonatomic,strong) CommonBlock *pos;
@property (nonatomic,assign) unsigned char note_type;//NoteType
@property (nonatomic,assign) BOOL isRest,inBeam;
@property (nonatomic,assign) BOOL isGrace;//倚音
@property (nonatomic,assign) unsigned char isDot; //1: 1个点， 2: 2个点。
@property (nonatomic,assign) BOOL stem_up,hideStem;//stem 符干

@property (nonatomic,assign) unsigned char voice,staff;
@property (nonatomic,assign) unsigned char tupletCount;//tuplet
@property (nonatomic,strong) NSMutableArray *note_elems; //array of NoteElem
@property (nonatomic,strong) NSMutableArray *note_arts; //array of NoteArticulation
@property (nonatomic,assign) signed char line;
@property (nonatomic,assign) int noteShift;//for player
//to play note
@property (nonatomic, assign) BOOL dontPlay;
//to show Jianpu
@property (nonatomic,strong) NSArray *sorted_note_elems; //array of NoteElem
//to parse MusicXML
@property (nonatomic,strong) NSMutableDictionary *xml_beams;//梁: dict[key:index value:begin, continue, end, forward hook, and backward hook]
@property (nonatomic,strong) NSMutableArray *xml_slurs; //slur 连奏: key=number, value=dict[type,placement,default-x,default-y,endnote,]
//@property (nonatomic,assign) BOOL xml_have_tuplets;
@property (nonatomic,strong) NSMutableArray *xml_tuplets;
@property (nonatomic,assign) int xml_stem_default_y, xml_duration;
@property (nonatomic,strong) NSMutableArray *xml_lyrics;
@property (nonatomic,strong) NSMutableArray *xml_fingers;//sorted from bottom to top
//to parse Lilypond
@property (nonatomic,strong) NSString *lily_beam_status; //auto, start, stop, none, finish
@property (nonatomic,assign) BOOL lily_hide_rest, lily_stem_auto, lily_beam_auto;
@property (nonatomic,assign) unsigned char lily_rest_octave; //0-9
@property (nonatomic,assign) unsigned char lily_rest_step; //1-7=CDEFGAB
@property (nonatomic,assign) int lily_offsetStaff; //0,-1,1
@property (nonatomic,assign) int lily_tuplet_count;
@property (nonatomic,strong) NSString* lily_tuplet_status;//start, continue, stop
@end

typedef enum{
    Beam_Normal = 0,
    Beam_Unknow = 1,
    Beam_Forward = 2,
    Beam_Backward = 3,
}BeamType;
@interface BeamElem : NSObject
@property (nonatomic, assign) unsigned char tupletCount;
@property (nonatomic,assign) unsigned char start_measure_pos,stop_measure_pos;
@property (nonatomic,assign) signed short start_measure_offset, stop_measure_offset;
@property (nonatomic,assign) unsigned char beam_type;//BeamType
@property (nonatomic,assign) unsigned char level; //1,2...
//to parse MusicXML
@property (nonatomic, assign) int xml_beam_number;
//to parse lilypond
@property (nonatomic, weak) OveNote *lily_start_note, *lily_stop_note;
@end

@interface OveBeam : NSObject {
    signed short left_shoulder_offset_y;
    signed short right_shoulder_offset_y;
    unsigned char beam_count;
}
@property (nonatomic, strong) CommonBlock *pos;
@property (nonatomic, assign) short staff,stop_staff;
@property (nonatomic, assign) unsigned char voice;
@property (nonatomic, assign) signed char left_line,right_line;
@property (nonatomic, assign) unsigned char tupletCount;
@property (nonatomic, strong) NSMutableArray *beam_elems;
@property (nonatomic, assign) BOOL isGrace;
//used for display
@property (nonatomic, assign) long drawPos_x, drawPos_y, drawPos_width, drawPos_height;
//to parse MusicXML
@property (nonatomic,weak) OveNote *beam_start_note, *beam_stop_note;
//to parse lilypond
@property (nonatomic, strong) NSArray *lily_beam_notes;
@end


typedef enum  {
    Wedge_Cres_Line = 0,	// <
    Wedge_Double_Line,		// <>, not appear in xml
    Wedge_Decresc_Line,		// >
    Wedge_Cres,				// cresc., not appear in xml, will create Expression
    Wedge_Decresc			// decresc., not appear in xml, will create Expression
}WedgeType;
@interface OveWedge : NSObject
@property (nonatomic,strong) CommonBlock *pos; //start_offset, tick
@property (nonatomic,strong) OffsetCommonBlock *offset;//stop_measure,stop_offset
@property (nonatomic,assign) unsigned char wedgeType;//WedgeType
@property (nonatomic,assign) signed short offset_y;
@property (nonatomic,assign) BOOL wedgeOrExpression; //YES: wedge, NO: expression
@property (nonatomic,assign) signed short wedge_height;
@property (nonatomic,assign) unsigned char staff;
@property (nonatomic,strong) NSString *expression_text;
//to parse MusicXML
@property (nonatomic,assign) signed short xml_staff;
@property (nonatomic,assign) int xml_start_note, xml_stop_note;
@end

@interface CommonSlur : NSObject
@property (nonatomic,assign) short staff, stop_staff;
@property (nonatomic,strong) CommonBlock *pos;
@property (nonatomic,strong) PairEnds *pair_ends;
@property (nonatomic,strong) OffsetCommonBlock *offset;
//to parse MusicXML
@property (nonatomic,assign) short xml_slur_number;
@property (nonatomic,weak) OveNote *slur_start_note, *slur_stop_note;
@property (nonatomic,assign) int xml_start_measure_index, xml_start_note_index, xml_start_elem_index,xml_stop_measure_index, xml_stop_note_index;
//to parse Lilypond
@property (nonatomic,weak) OveNote *lily_start_note, *lily_stop_note;
@property (nonatomic,assign) short lily_start_measure;
@property (nonatomic,assign) BOOL lily_placement_auto;
@end

@interface MeasureSlur : CommonSlur {
    OffsetElement *handle2;
    OffsetElement *handle3;
    unsigned char note_time_percent;
    OffsetElement *leftShoulder;
    OffsetElement *rightShoulder;
}
@property (nonatomic,assign) unsigned char voice;
@property (nonatomic,assign) BOOL slur1_above;
@end

@class OveMeasure;
@interface MeasureTie : CommonSlur {
    unsigned char note;
    unsigned short height;
    OffsetElement *leftShoulder;
    OffsetElement *rightShoulder;
}
@property (nonatomic,assign) BOOL above;
//to parse MusicXML
@property (nonatomic,assign) short xml_tie_number, xml_note_value;
//@property (nonatomic,strong) NoteElem *xml_start_elem;
//@property (nonatomic,strong) OveMeasure *xml_beloneto_measure;
//@property (nonatomic,assign) int xml_start_measure_index, xml_start_note_index, xml_start_elem_index;
//to parse MIDI
@property (nonatomic,assign) short midi_note_value;
@end

@interface OveTuplet : CommonSlur {
    unsigned short height;
    unsigned char space;
    OffsetElement *mark_handle;
    OffsetElement *leftShoulder;
    OffsetElement *rightShoulder;
}
@property (nonatomic,assign) unsigned char tuplet;
@end

@interface MeasureGlissando : CommonSlur {
    unsigned char line_thick;
    NSString *glissando_text;
    OffsetElement *leftShoulder;
    OffsetElement *rightShoulder;
}
@property (nonatomic,assign) BOOL straight_wavy;
@end

//parsePedal
@interface MeasurePedal : CommonSlur {
    BOOL isPlayBack,isHalf;
    signed short x_offset;
    OffsetElement *leftShoulder;
    OffsetElement *rightShoulder;
}
@property (nonatomic, assign) BOOL isLine;
@end

@interface Tempo : NSObject {
    BOOL show_tempo,show_before_text,show_parenthesis;
    OffsetElement *tempo_offset;
    //NSString *tempo_left_text;
    NSString *tempo_right_text;
    BOOL swing_eighth;
    unsigned char right_note_type;
}
@property (nonatomic, strong) CommonBlock *pos;
@property (nonatomic, strong) NSString *tempo_left_text;
@property (nonatomic, assign) signed short offset_y, font_size;
@property (nonatomic, assign) unsigned char left_note_type, tempo_range;
@property (nonatomic, assign) unsigned short tempo;
-(int) getQuarterTempo;
@end

@interface NumericEnding : NSObject {
    unsigned short numeric_left_offset_x;
    unsigned short numeric_height;
    signed short numeric_right_offset_x;
    unsigned short numeric_left_offset_y, numeric_right_offset_y;
    unsigned short numeric_offset_x, numeric_offset_y;
}
@property (nonatomic,strong) NSString *numeric_text;
@property (nonatomic,assign) unsigned short numeric_measure_count;
@property (nonatomic,strong) CommonBlock *pos;
@property (nonatomic, assign) signed short offset_y;
-(int) getJumpCount;

@end


//parseLyric
@interface MeasureLyric : NSObject
@property (nonatomic, strong) CommonBlock *pos;
@property (nonatomic, strong) OffsetElement *offset;
@property (nonatomic, strong) NSString *lyric_text;
@property (nonatomic, assign) unsigned char verse, voice;
@property (nonatomic, assign) short staff;
@end



//parseHarmonyGuitarFrame
typedef enum {
	Harmony_maj = 0,
	Harmony_min,
	Harmony_aug,
	Harmony_dim,
	Harmony_dim7,
	Harmony_sus2,
	Harmony_sus4,
	Harmony_sus24,
	Harmony_add2,
	Harmony_add9,
	Harmony_omit3,
	Harmony_omit5,
	Harmony_2,
	Harmony_5,
	Harmony_6,
	Harmony_69,
	Harmony_7,
	Harmony_7b5,
	Harmony_7b9,
	Harmony_7s9,
	Harmony_7s11,
	Harmony_7b5s9,
	Harmony_7b5b9,
	Harmony_7b9s9,
	Harmony_7b9s11,
	Harmony_7sus4,
	Harmony_9,
	Harmony_9b5,
	Harmony_9s11,
	Harmony_9sus4,
	Harmony_11,
	Harmony_13,
	Harmony_13b5,
	Harmony_13b9,
	Harmony_13s9,
	Harmony_13s11,
	Harmony_13sus4,
	Harmony_min_add2,
	Harmony_min_add9,
	Harmony_min_maj7,
	Harmony_min6,
	Harmony_min6_add9,
	Harmony_min7,
	Harmony_min7b5,
	Harmony_min7_add4,
	Harmony_min7_add11,
	Harmony_min9,
	Harmony_min9_b5,
	Harmony_min9_maj7,
	Harmony_min11,
	Harmony_min13,
	Harmony_maj7,
	Harmony_maj7_b5,
	Harmony_maj7_s5,
	Harmony_maj7_69,
	Harmony_maj7_add9,
	Harmony_maj7_s11,
	Harmony_maj9,
	Harmony_maj9_sus4,
	Harmony_maj9_b5,
	Harmony_maj9_s5,
	Harmony_maj9_s11,
	Harmony_maj13,
	Harmony_maj13_b5,
	Harmony_maj13_b9,
	Harmony_maj13_b9b5,
	Harmony_maj13_s11,
	Harmony_aug7,
	Harmony_aug7_b9,
	Harmony_aug7_s9,
    
	Harmony_None
}HarmonyType;
@interface HarmonyGuitarFrame : NSObject
@property (nonatomic, strong) CommonBlock *pos;
@property (nonatomic, assign) HarmonyType type;
@property (nonatomic, assign) unsigned char root, bass;
@end

@interface MeasureKey : NSObject
@property (nonatomic,assign) int key,previousKey;
@property (nonatomic,assign) unsigned char symbolCount;
@end

@interface TimeSignatureParameter : NSObject
@property (nonatomic, assign) unsigned short beat_start;
@property (nonatomic, assign) unsigned short beat_length;// beat length unit
@property (nonatomic, assign) unsigned short beat_start_tick;// beat start tick
@end

typedef enum  {
    Midi_Controller,
    Midi_ProgramChange,
    Midi_ChannelPressure,
    Midi_PitchWheel,
} MidiCtrlType;

@interface MidiController : NSObject
@property (nonatomic, assign) unsigned short tick;
@property (nonatomic, assign) unsigned short pitch_wheel_value;//Midi_PitchWheel
@property (nonatomic, assign) MidiCtrlType midi_type;
@property (nonatomic, assign) unsigned char controller_value, controller_number;//Midi_Controller
@property (nonatomic, assign) unsigned char channel_pressure;//Midi_ChannelPressure
@property (nonatomic, assign) unsigned char programechange_patch;//Midi_ProgramChange
@end

typedef enum  {
    Barline_Default = 0,	//0x00 will be | or final (at last measure)
    Barline_Double,			//0x01 ||
    Barline_RepeatLeft,		//0x02 ||:
    Barline_RepeatRight,	//0x03 :||
    Barline_Final,			//0x04
    Barline_Dashed,			//0x05
    Barline_Null			//0x06
} BarlineType;

/*
 Segno              D.S.al Fine
 (1) ---------------------->| (Jump to Segno)
 (2) |--------------------->|(End)

 
 Segno      Fine        D.S.al Coda
 (1) ---------------------->|(Jump to Segno)
 (2) |----->|(To End or Fine)
 
 To Coda                Coda
 (1) |(Jump to Coda)     |---------->|(To Fine or End)

 begin        Fine          D.C.al Fine
 (1) ---------------------->| (Jump to Begin)
 (2) |--------->|(To Fine or End)

 Begin      Fine        D.C.al Coda
 (1) ---------------------->|(Jump to Begin)
 (2) |----->|(To End or Fine)

 
 */
typedef enum{
    Repeat_Null = 0,
	Repeat_Segno,
	Repeat_Coda,
	Repeat_ToCoda,      //Jump to Coda
	Repeat_DSAlCoda,    //D.S.al Coda 连续记号（意大利语：Dal Segno，简称D.S.）指从记号处再奏
	Repeat_DSAlFine,    //D.S. 或者D.S.al Fine
	Repeat_DCAlCoda,    //D.C.al Coda 返始（意大利语：Da Capo，简称D.C.）是一种乐谱符号，指从头再奏
    Repeat_DC,          //same as Repeat_DCAlCoda
	Repeat_DCAlFine,    //D.C. 或者D.S.al Fine
	Repeat_Fine,
}RepeatType;

@interface OveMeasure: NSObject {
    //MEAS
    BOOL pickup;
    unsigned short bar_length; //bar length (tick)
    OffsetElement *bar_number_offset;
    BOOL multi_measure_rest;
    unsigned short multi_measure_rest_count;
    
    //COND
    //parseTimeSignature
    // beat length (tick)
    unsigned short beat_length;
    // bar length (tick)
    //unsigned short meas_length_tick;
    
    BOOL is_symbol,replace_font;
    // color
    unsigned char color;
    // show
    BOOL show, show_beat_group;
    unsigned char numerator1, numerator2,numerator3;
    unsigned char denominator1, denominator2, denominator3;
    unsigned char beam_group1, beam_group2, beam_group3, beam_group4;
    unsigned char beam_16th;
    unsigned char beam_32th;

    //parseBarNumber
    BOOL is_show_on_paragraph_start;
    // text align
    unsigned char text_align;
    // show flag
    unsigned char show_flag;
    // bar range
    unsigned char show_every_bar_count;
    // prefix
    unsigned char prefix[3];
    
    //parseRepeatSymbol
    NSString *repeat_text;

    //parseTimeSignatureParameters
    NSMutableArray *timeSignatureParameters;//TimeSignatureParameter

}
@property (nonatomic,assign) int number,show_number;
@property (nonatomic,assign) int belone2line;
//MEAS
@property (nonatomic,assign) BarlineType left_barline;//BarlineType
@property (nonatomic,assign) BarlineType right_barline;//BarlineType
@property (nonatomic,assign) unsigned char repeat_count;//parseBarlineParameters
@property (nonatomic,assign) BOOL repeat_play;


@property (nonatomic,assign) short typeTempo;//每分钟多少拍。
//@property (nonatomic,assign) Float32 typeTempo;//每分钟多少拍。

//COND parseTimeSignature
@property (nonatomic,assign) unsigned char numerator;//分子
@property (nonatomic,assign) unsigned char denominator;//分母
@property (nonatomic,assign) unsigned short meas_length_size;
@property (nonatomic,assign) unsigned short meas_length_tick;// bar length (tick)

//BDAT
//parseNoteRest
@property (nonatomic,strong) NSMutableArray *notes;
@property (nonatomic,strong) NSMutableDictionary *sorted_notes;//key:duration value:array of notes
@property (nonatomic,strong) NSArray *sorted_duration_offset;

@property (nonatomic,strong) NSMutableArray *beams;//parseBeam 横梁
@property (nonatomic,strong) NSMutableArray *slurs;//parseSlur 连奏
@property (nonatomic,strong) NSMutableArray *ties;//parseTie 绑定
@property (nonatomic,strong) NSMutableArray *tuplets;//parseTuplet 三连音，五连音等
@property (nonatomic,strong) NSMutableArray *meas_texts;//parseText OveText
@property (nonatomic,strong) NSMutableArray *images;//OveImage

@property (nonatomic,strong) NSMutableArray *harmony_guitar_frames;//parseHarmonyGuitarFrame
@property (nonatomic,strong) NSMutableArray *dynamics;//parseDynamics  mp,p,f....
@property (nonatomic,strong) NSMutableArray *wedges;//parseWedge 楔子
@property (nonatomic,strong) NSMutableArray *expresssions;//parseExpressions
@property (nonatomic,strong) NSMutableArray *octaves;//parseOctaveShift 升高8度
@property (nonatomic,strong) NSMutableArray *midi_controllers;//MidiController
@property (nonatomic,strong) NSMutableArray *glissandos;//parseGlissando 滑奏法

@property (nonatomic,strong) NSMutableArray *clefs; //parseClef 谱号改变 array of MeasureClef
//@property (nonatomic,retain) NSMutableArray *clefEveryStaff; //每个staff的ClefType
//@property (nonatomic,assign) int staves; //当前小节的staff count
@property (nonatomic,assign) int fifths; //当前小节的fifths
@property (nonatomic,strong) MeasureKey *key;//parseKey 本小节要换调 MeasureKey

@property (nonatomic,strong) NSMutableArray *decorators;//MeasureDecorators
@property (nonatomic,strong) NSMutableArray *tempos; //parseTempo 
@property (nonatomic,strong) NSMutableArray *lyrics;//parseLyric: array of MeasureLyric
@property (nonatomic,strong) NSMutableArray *pedals;//parsePedal: array of MeasurePedal
//repeat numberic ending
@property (nonatomic,strong) NSMutableArray *numerics;//NumericEnding
//parseRepeatSymbol
@property (nonatomic,assign) RepeatType repeat_type;//RepeatType
@property (nonatomic,strong) NSString *repeat_string;
@property (nonatomic,strong) CommonBlock *repeate_symbol_pos;
@property (nonatomic,strong) OffsetElement *repeat_offset;
//to parse MusicXML
@property (nonatomic,assign) short xml_division;
@property (nonatomic,assign) short xml_staves; //包含几个谱表
@property (nonatomic,assign) BOOL xml_new_page, xml_new_line;
@property (nonatomic,assign) int xml_top_system_distance,xml_system_distance, xml_staff_distance, xml_firstnote_offset_x;
//to parse Lilypond
@property (nonatomic,assign) BOOL lily_line_break;
//to parse midi
@property (nonatomic,assign) float midi_start_timestamp;
- (void) checkDontPlayedNotes;
@end


@interface OvePage : NSObject {
    unsigned short staff_interval;//组间距: 没有用
    unsigned short line_bar_count;
    unsigned short page_line_count;
    UInt32 left_margin;
    UInt32 right_margin;
    UInt32 page_width,page_height,top_margin,bottom_margin;
}
@property (nonatomic, assign) unsigned short begin_line,line_count;
@property (nonatomic, assign) unsigned short system_distance;//line_interval;//两个谱表组间距
@property (nonatomic, assign) unsigned short staff_distance;//staff_inline_interval;//同一组内谱表间距
//to parse MusicXML
@property (nonatomic, assign) unsigned short xml_top_system_distance;
@end

typedef enum {
	Group_None = 0,
	Group_Brace, //花括号
	Group_Bracket //括号
}GroupType;

@interface LineStaff : NSObject
//@property (nonatomic,assign) unsigned char fifths;
@property (nonatomic,assign) signed short y_offset;
@property (nonatomic,assign) unsigned char clef; //00: 高音, 01:低音 //ClefType
@property (nonatomic,assign) BOOL hide;
@property (nonatomic,assign) unsigned char group_staff_count;
//@property (nonatomic,assign) GroupType group_type; //1: group brace, 2: group bracket
@end

@interface OveLine : NSObject {
    signed short left_x_offset;
    signed short right_x_offset;
}
@property (nonatomic,assign) signed short fifths;
@property (nonatomic,assign) unsigned short bar_count,begin_bar;
@property (nonatomic,assign) signed short y_offset;
@property (nonatomic,strong) NSMutableArray *staves;//array of LineStaff
//to parse MusicXML
@property (nonatomic,assign) short xml_system_distance, xml_staff_distance;
@end
/*
typedef enum{
    titleType_ = 0x00000001,    //normal title:1.主标题，2.副标题, 3. 4. 
    instructionsType_ = 0x00010000, //instructions: 4个
    writerType_ = 0x00020002,   //composer: 作曲家 4个
    copyrightType_ = 0x00030001,//copyright: 版权 4个
    headerType_ = 0x00040000,   //header
    otherType1_ = 0x00040002,
    otherType2_ = 0x00050001,
    footerType_ = 0x00050002,   //footer
}TitleType;

@interface OveTitle : NSObject
@property (nonatomic,assign) TitleType type;
@property (nonatomic,retain) NSMutableArray *titles;
@end
*/
typedef struct{
    // 8 voices
    struct {
        unsigned char r1[4];
        unsigned char r2;
        unsigned char channel; //[0,15]
        signed char volume; //[-1,127], -1 default
        signed char pitch_shift; //[-36,36]
        signed char pan;    //[-64,63]
        unsigned char r3[4];
        unsigned char r4[2];
        signed char patch; //[0,127]
    }voices[8];
    //stem type
    unsigned char stem_type[8]; //0,1,2
}track_voice; //16*8+8 = 136bytes

typedef struct{
    signed char line[16];
    unsigned char head_type[16];
    unsigned char pitch[16];
    unsigned char voice[16];
}track_node;

@interface OveTrack : NSObject {
    //NSString *track_name;
    unsigned char patch;
    BOOL show_name,show_breif_name,mute,solo;
    BOOL show_key_each_line;//show key each line
    //unsigned char voice_count;//voice count
    track_voice voice;
    track_node node;
    //unsigned char transpose_value;
    BOOL show_transpose;
    
    unsigned char start_key;//start key
    unsigned char display_percent;//display percent
    BOOL show_leger_line;//show leger line
    BOOL show_clef;//show clef
    
    BOOL show_time_signature,show_key_signature,show_barline,fill_with_rest,flat_tail,show_clef_each_line;
    ClefType clefs_type;
    int fifths;
}
@property (nonatomic, assign) unsigned char transpose_value;// transpose value [-127, 127]
@property (nonatomic, assign) unsigned char voice_count;
@property (nonatomic, strong) NSString *track_name, *track_brief_name;
//to parse MusicXML
@property (nonatomic, strong) NSString *xml_track_id;
@property (nonatomic, assign) unsigned char xml_from_staff, xml_staves;
@property (nonatomic, assign) ClefType start_clef,transpose_celf;

//@property (nonatomic, assign) track_voice voice;
- (track_voice*) getVoice;
- (track_node*) getNode;
@end

@interface XmlPart : NSObject {
}
@property (nonatomic, strong) NSString *part_name;
@property (nonatomic, assign) unsigned char from_staff, staves, patch;
@end

typedef enum {
    Record,	Swing, Notation
}PlayStyle;

@class MidiFile;

@interface OveMusic : NSObject 

@property (nonatomic, strong) NSString *work_title;
@property (nonatomic, strong) NSString *work_number; //xml: e.g. Op. 98
@property (nonatomic, strong) NSString *composer, *lyricist, *rights; //xml
//@property (nonatomic, retain) NSMutableArray *titles;//OveTitle

//@property (nonatomic, assign) int staff_distance;           //xml: system内部staff之间距离 = ove: staff_inline_interval
@property (nonatomic, assign) int page_height,page_width;   //both
@property (nonatomic, assign) int page_top_margin,page_bottom_margin; //both
@property (nonatomic, assign) int page_left_margin, page_right_margin; //both
//@property (nonatomic, assign) int system_distance;          //xml: 前一个system的最后一条线到当前system的第一条线的距离
//@property (nonatomic, assign) int top_system_distance;      //xml: top_margin到第一个system的第一条线的距离

@property (nonatomic, assign) int max_measures;
@property (nonatomic, strong) NSMutableArray *pages; //OvePage -> above lines.

@property (nonatomic, strong) NSMutableArray *lines;//OveLine
@property (nonatomic, strong) NSMutableArray *trackes;//TRCK: OveTrack
@property (nonatomic, strong) NSMutableArray *xml_parts;//XmlPart
@property (nonatomic, assign) unsigned char version;

@property (nonatomic, strong) NSMutableArray *measures;//OveMeasure
//@property (nonatomic, strong) NSDictionary *midiSequence, *midiSequenceAccompany; //key:tick value:array of note:dict[mm, nn,ii,ee,val]

@property (nonatomic, strong) MidiFile *videoMidiFile,*accompanyMidiFile;

+ (OveData*) ove_data;
//- (BOOL)loadOve:(NSData*)data;
//- (BOOL)load:(NSString*)file folder:(NSString*)folder;
+ (NSDictionary*)getVmusMusicInfo:(NSString*)file;
+ (NSDictionary*)getOveMusicInfo:(NSString*)file;
+ (OveMusic*)loadOveMusic:(NSString*)file folder:(NSString *)folder;
+ (OveMusic*)loadFromOveData:(NSData*)oveData;
//vmus file format
+ (OveMusic*)loadFromVmusData:(NSData*)ovsData;
- (NSData*)dataOfVmusMusic;
- (NSData*)dataOfVmusMusic:(int)begin end:(int)end;

- (void)changeKey;
- (BOOL)changeToKey:(int) new_fifths;
- (BOOL)changeToKeyWithSameJianpu:(int) new_fifths increase:(BOOL)increase;

- (BOOL)supportChangeKey;
- (int)currentFifths;
@end


