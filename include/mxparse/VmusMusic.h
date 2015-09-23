#ifndef	VMUSMUSIC_H_
#define	VMUSMUSIC_H_

/*
These status used to tell MusicXMLParser user that the error type, and the status
can suggest that whether the MusicXML file can not found, file content is invalid 
or other mistakes.
 */
typedef enum
{
	MUSIC_WARN_FILE_EMPTY = 1,
	MUSIC_ERROR_NONE = 0,
	MUSIC_ERROR_ARGS_INVALID = -1,
	MUSIC_ERROR_GET_FILE_ATTRI = -2,
	MUSIC_ERROR_GET_FILE_CONTENT = -3,
	MUSIC_ERROR_MEM_NOT_ENOUGH = -4,
	MUSIC_ERROR_TINYXML2_PARSE_ERROR = -5,
	MUSIC_ERROR_XMLENCODE = -6,
	MUSIC_ERROR_XMLNODE_NOT_EXIST = -7,
	MUSIC_ERROR_XMLCONTENT_INVALID = -8,
} hyStatus;

typedef enum {
	Articulation_Major_Trill										= 0x00,
	Articulation_Minor_Trill										= 0x01,
	Articulation_Trill_Section									= 0x02,
	Articulation_Inverted_Short_Mordent			= 0x03,
	Articulation_Inverted_Long_Mordent				= 0x04,
	Articulation_Short_Mordent								= 0x05,
	Articulation_Turn													= 0x06,
 	Articulation_Finger_1											= 0x07,
 	Articulation_Finger_2											= 0x08,
 	Articulation_Finger_3											= 0x09,
 	Articulation_Finger_4											= 0x0A,
 	Articulation_Finger_5											= 0x0B,
	Articulation_Finger												= 0x07,
	Articulation_Flat_Accidental_For_Trill				= 0x0C,
	Articulation_Sharp_Accidental_For_Trill			= 0x0D,
	Articulation_Natural_Accidental_For_Trill		= 0x0E,
	Articulation_Marcato											= 0x0F,
	Articulation_Marcato_Dot									= 0x10,
	Articulation_Heavy_Attack									= 0x11,
	Articulation_SForzando										= 0x12,
	Articulation_SForzando_Dot								= 0x13,
	Articulation_Heavier_Attack								= 0x14,
	Articulation_SForzando_Inverted						= 0x15,
	Articulation_SForzando_Dot_Inverted				= 0x16,
	Articulation_Staccatissimo									= 0x17,
	Articulation_Staccato											= 0x18,
	Articulation_Tenuto											= 0x19,
	Articulation_Up_Bow											= 0x1A,
	Articulation_Down_Bow										= 0x1B,
	Articulation_Up_Bow_Inverted							= 0x1C,
	Articulation_Down_Bow_Inverted					= 0x1D,
	Articulation_Arpeggio										= 0x1E,
	Articulation_Tremolo_Eighth								= 0x1F,
	Articulation_Tremolo_Sixteenth						= 0x20,
	Articulation_Tremolo_Thirty_Second				= 0x21,
	Articulation_Tremolo_Sixty_Fourth					= 0x22,
	Articulation_Natural_Harmonic							= 0x23,
	Articulation_Artificial_Harmonic						= 0x24,
	Articulation_Plus_Sign										= 0x25,
	Articulation_Fermata											= 0x26,
	Articulation_Fermata_Inverted							= 0x27,
	Articulation_Pedal_Down									= 0x28,
	Articulation_Pedal_Up										= 0x29,
	Articulation_Pause												= 0x2A,
	Articulation_Grand_Pause									= 0x2B,
	Articulation_Toe_Pedal										= 0x2C,
	Articulation_Heel_Pedal										= 0x2D,
	Articulation_Toe_To_Heel_Pedal						= 0x2E,
	Articulation_Heel_To_Toe_Pedal						= 0x2F,
	Articulation_Open_String									= 0x30,		// finger 0 in guitar or violin
	Articulation_Guitar_Lift										= 0x46,
	Articulation_Guitar_Slide_Up								= 0x47,
	Articulation_Guitar_Rip										= 0x48,
	Articulation_Guitar_Fall_Off								= 0x49,
	Articulation_Guitar_Slide_Down						= 0x4A,
	Articulation_Guitar_Spill										= 0x4B,
	Articulation_Guitar_Flip										= 0x4C,
	Articulation_Guitar_Smear									= 0x4D,
	Articulation_Guitar_Bend									= 0x4E,
	Articulation_Guitar_Doit										= 0x4F,
	Articulation_Guitar_Plop									= 0x50,
	Articulation_Guitar_Wow_Wow						= 0x51,
	Articulation_Guitar_Thumb								= 0x64,
	Articulation_Guitar_Index_Finger						= 0x65,
	Articulation_Guitar_Middle_Finger					= 0x66,
	Articulation_Guitar_Ring_Finger						= 0x67,
	Articulation_Guitar_Pinky_Finger						= 0x68,
	Articulation_Guitar_Tap										= 0x69,
	Articulation_Guitar_Hammer								= 0x6A,
	Articulation_Guitar_Pluck									= 0x6B,
	Articulation_Detached_Legato							= 0x6C,
	Articulation_None
} ArticulationType;

typedef enum {
	ArtPos_Down = 0,
	ArtPos_Above,
	ArtPos_Left,
	ArtPos_Right,
} ArticulationPos;

typedef enum {
	Decorator_Dotted_Barline = 0,
	Decorator_Articulation
} DecoratorType;

typedef enum {
	Text_Rehearsal,
	Text_SystemText,
	Text_MeasureText
} TextType;

typedef enum {
	//percussion note head define
	NoteHead_Standard = 0x00,
	NoteHead_Invisible,
	NoteHead_Rhythmic_Slash,
	NoteHead_Percussion,
	NoteHead_Closed_Rhythm,
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
	NoteHead_Guitar_0		= 0x20,
	NoteHead_Guitar_1		= 0x21,
	NoteHead_Guitar_2		= 0x22,
	NoteHead_Guitar_3		= 0x23,
	NoteHead_Guitar_4		= 0x24,
	NoteHead_Guitar_5		= 0x25,
} NoteHeadType;

typedef enum {
	Tie_None			= 0x0,
	Tie_LeftEnd		= 0x1,
	Tie_RightEnd		= 0x2
} TiePos;

typedef enum {
	Velocity_Offset,
	Velocity_SetValue,
	Velocity_Percentage
} VelocityType;

typedef enum {
	Accidental_Normal								= 0x0,
	Accidental_Sharp									= 0x1,
	Accidental_Flat										= 0x2,
	Accidental_Natural								= 0x3,
	Accidental_DoubleSharp					= 0x4,
	Accidental_DoubleFlat						= 0x5,
	Accidental_Sharp_Caution					= 0x9,
	Accidental_Flat_Caution						= 0xA,
	Accidental_Natural_Caution				= 0xB,
	Accidental_DoubleSharp_Caution	= 0xC,
	Accidental_DoubleFlat_Caution		= 0xD
} AccidentalType;

typedef enum {
	Note_DoubleWhole	= 0x0,
	Note_Whole					= 0x1,
	Note_Half						= 0x2,
	Note_Quarter				= 0x3,
	Note_Eight					= 0x4,
	Note_Sixteen				= 0x5,
	Note_32							= 0x6,
	Note_64							= 0x7,
	Note_128						= 0x8,
	Note_256						= 0x9,
	Note_None
} NoteType;

typedef enum {
	Clef_None		= -1,
	Clef_Treble	= 0,				//0x00
	Clef_Bass,							//0x01
	Clef_Alto,							//0x02
	Clef_UpAlto,						//0x03
	Clef_DownDownAlto,		//0x04
	Clef_DownAlto,				//0x05
	Clef_UpUpAlto,				//0x06
	Clef_Treble8va,					//0x07
	Clef_Bass8va,						//0x08
	Clef_Treble8vb,				//0x09
	Clef_Bass8vb,					//0x0A
	Clef_Percussion1,				//0x0B
	Clef_Percussion2,				//0x0C
	Clef_TAB							//0x0D
} ClefType;

typedef enum {
	Dynamics_pppp = 0,
	Dynamics_ppp,
	Dynamics_pp,
	Dynamics_p,
	Dynamics_mp,
	Dynamics_mf,
	Dynamics_f,
	Dynamics_ff,
	Dynamics_fff,
	Dynamics_ffff,
	Dynamics_sf,
	Dynamics_sff,		//Sforzando (sff) ͻǿ
	Dynamics_fz,
	Dynamics_sfz,
	Dynamics_sffz,
	Dynamics_fp,
	Dynamics_sfp
} DynamicsType;

typedef enum {
	OctaveShift_None				= -1,
	OctaveShift_8_Continue		= 0,
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
} OctaveShiftType;

typedef enum {
	Beam_Normal		= 0,
	Beam_Unknow		= 1,
	Beam_Forward		= 2,
	Beam_Backward	= 3,
} BeamType;

typedef enum {
	Wedge_Cres_Line = 0,	// <
	Wedge_Double_Line,		// <>, not appear in xml
	Wedge_Decresc_Line,		// >
	Wedge_Cres,					// cresc., not appear in xml, will create Expression
	Wedge_Decresc				// decresc., not appear in xml, will create Expression
} WedgeType;

typedef enum {		//parseHarmonyGuitarFrame
	Harmony_maj	= 0,
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
} HarmonyType;

typedef enum {
	Midi_Controller,
	Midi_ProgramChange,
	Midi_ChannelPressure,
	Midi_PitchWheel,
} MidiCtrlType;

typedef enum {
	Barline_Default = 0,		//0x00 will be | or final (at last measure)
	Barline_Double,			//0x01 ||
	Barline_RepeatLeft,		//0x02 ||:
	Barline_RepeatRight,	//0x03 :||
	Barline_Final,					//0x04
	Barline_Dashed,			//0x05
	Barline_Null					//0x06
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
typedef enum {
	Repeat_Null = 0,
	Repeat_Segno,
	Repeat_Coda,
	Repeat_ToCoda,
	Repeat_DSAlCoda,
	Repeat_DSAlFine,
	Repeat_DCAlCoda,
	Repeat_DC,					//same as Repeat_DCAlCoda
	Repeat_DCAlFine,
	Repeat_Fine
} RepeatType;

typedef enum {
	Group_None = 0,
	Group_Brace,
	Group_Bracket
} GroupType;

typedef enum {
	Record,
	Swing,
	Notation
} PlayStyle;

typedef struct tagOffsetElement {
	short offset_x, offset_y;
	tagOffsetElement()
		:offset_x(0)
		,offset_y(0)
	{
	}
} OffsetElement;

typedef struct tagOffsetCommonBlock {
	short stop_measure, stop_offset;
	tagOffsetCommonBlock()
		:stop_measure(0)
		,stop_offset(0)
	{
	}
} OffsetCommonBlock;

typedef struct tagCommonBlock {
	unsigned char color;
	short start_offset, tick;
	tagCommonBlock()
		:color(0)
		,start_offset(0)
		,tick(0)
	{
	}
} CommonBlock;

typedef struct tagPairEnds{
	short left_line, right_line;
	tagPairEnds()
		:left_line(0)
		,right_line(0)
	{
	}
} PairEnds;

class NoteElem {
public:
	NoteElem()
		:accidental_type(Accidental_Normal)
		,head_type(0)
		,tie_pos(Tie_None)
		,velocity(0)
		,offset_tick(0)
		,length_tick(0)
		,note(0)
		,line(0)
		,offsetStaff(0)
		,dontPlay(false)
		,rightHand(false)
		,xml_pitch_octave(0)
		,xml_pitch_step(0)
		,xml_pitch_alter(0)
		,display_revert(0)
		,display_x(0)
		,display_y(0)
	{
	}
	~NoteElem() {}

	AccidentalType accidental_type;
	unsigned char head_type;
	unsigned char tie_pos;
	unsigned char velocity;	//0-127
	short offset_tick;
	unsigned short length_tick;
	char note;
	char line;
	char offsetStaff;				// offset staff, in {-1, 0, 1}
	bool dontPlay, rightHand;
	std::vector< std::map<std::string, std::string> >xml_ties;
	unsigned char xml_pitch_octave;		//0-9
	unsigned char xml_pitch_step;			//1-7=CDEFGAB
	char xml_pitch_alter;							//-1,0,1
	std::string xml_finger;

	//for display
	bool display_revert;
	float display_x;
	float display_y;
};

class NoteArticulation {
public:
	NoteArticulation()
		:art_type(Articulation_None)
		,art_placement_above(0)
		,accidental_mark(Accidental_Normal)
		,tremolo_stop_note_count(0)
		,tremolo_beem_mode(false)
		,arpeggiate_over_voice(0)
		,arpeggiate_over_staff(0)
		,has_wavy_line(false)
		,wavy_stop_measure(0)
		,wavy_stop_note(0)
		,wavy_number(0)
		,trill_num_of_32nd(0)
		,trillNoteType(Note_None)
		,trill_interval(0)
		,finger_pos(ArtPos_Down)
		,changeVelocity(false)
		,velocity_value(0)
		,velocity_type(0)
		,changeLength(false)
		,length_percentage(0)
		,sound_effect_from(0)
		,sound_effect_to(0)
	{
	}
	~NoteArticulation() {}

	ArticulationType art_type;
	int art_placement_above;
	OffsetElement offset;
	AccidentalType accidental_mark;

	//Tremolo
	int tremolo_stop_note_count;
	bool tremolo_beem_mode;
	int arpeggiate_over_voice, arpeggiate_over_staff;

	bool has_wavy_line;
	int wavy_stop_measure, wavy_stop_note, wavy_number;
	int trill_num_of_32nd;
	NoteType trillNoteType;
	unsigned char trill_interval;
	std::string finger, alterFinger;
	ArticulationPos finger_pos;

	bool changeVelocity;
	unsigned short velocity_value;
	unsigned char velocity_type;

	bool changeLength;
	unsigned char length_percentage;
	short sound_effect_from, sound_effect_to;
};

class OveNote {
public:
	OveNote()
		:note_type(Note_None)
		,isRest(false)
		,inBeam(false)
		,isGrace(false)
		,isDot(0)
		,stem_up(false)
		,hideStem(false)
		,voice(0)
		,staff(0)
		,tupletCount(0)
		,line(0)
		,noteShift(0)
		,dontPlay(false)
		//,xml_have_tuplets(false)
		,xml_stem_default_y(0)
		,xml_duration(0)
		,display_x(0)
		,display_y(0)
		,display_note_x(0)
	{
	}
	~OveNote() {}

	CommonBlock pos;
	NoteType note_type;
	bool isRest,inBeam;
	bool isGrace;
	unsigned char isDot;
	bool stem_up,hideStem;

	unsigned char voice,staff;
	unsigned char tupletCount;
	std::vector<std::shared_ptr<NoteElem> > note_elems;
	std::vector<std::shared_ptr<NoteArticulation> > note_arts;
	char line;
	int noteShift;
	bool dontPlay;

	std::vector<std::shared_ptr<NoteElem> >sorted_note_elems;
	std::map<int, std::string> xml_beams;
	std::vector<std::map<std::string, std::string> > xml_slurs;
	//bool xml_have_tuplets;
	std::vector<std::map<std::string, std::string> > xml_tuplets;
	int xml_stem_default_y, xml_duration;
	std::vector<std::map<std::string, std::string> > xml_lyrics;
	std::vector<std::shared_ptr<NoteArticulation> > xml_fingers;

	//for display
	float display_x, display_y;
	float display_note_x;
};

class OveText {
public:
	OveText()
		:staff(0)
		,offset_x(0)
		,offset_y(0)
		,font_size(0)
		,isItalic(false)
		,isBold(false)
		,xml_start_note(0)
	{
	}
	~OveText() {}

	short staff;
	CommonBlock pos;
	std::string text;
	int offset_x, offset_y;
	unsigned char font_size;
	bool isItalic, isBold;
	int xml_start_note;
};

class OveImage{
public:
	OveImage()
		:staff(0)
		,type(0)
		,offset_x(0)
		,offset_y(0)
		,width(0)
		,height(0)
	{
	}
	~OveImage() {}

	short staff;
	CommonBlock pos;
	std::string source;
	short type;			//application/postscript, image/gif, image/jpeg, image/png, and image/tiff
	int offset_x, offset_y, width, height;
};

class MeasureExpressions{
public:
	MeasureExpressions()
		:offset_y(0)
		,staff(0)
	{
	}
	~MeasureExpressions() {}

	CommonBlock pos;
	short offset_y;
	std::string exp_text;
	short staff;
};

class MeasureClef {
public:
	MeasureClef()
		:staff(0)
		,note_index(0)
		,clef(Clef_None)
		,xml_note(0)
		,xml_scaned(false)
	{
	}
	~MeasureClef() {}

	unsigned short staff, note_index;
	CommonBlock pos;
	ClefType clef;
	int xml_note;
	bool xml_scaned;
};

class MeasureDecorators {
public:
	MeasureDecorators()
		:decoratorType(0)
		,artType(Articulation_None)
		,offset_y(0)
		,staff(0)
		,xml_staff(0)
	{
	}
	~MeasureDecorators() {}

	unsigned char decoratorType;
	ArticulationType artType;
	std::string finger;
	CommonBlock pos;
	short offset_y;
	short staff, xml_staff;
	std::shared_ptr<OveNote> xml_start_note;
};

class  OveDynamic {
public:
	OveDynamic()
		:dynamics_type(0)
		,offset_y(0)
		,staff(0)
		,playback(false)
		,velocity(0)
		,xml_note(0)
	{
	}
	~OveDynamic() {}

	unsigned char dynamics_type;
	CommonBlock pos;
	short offset_y;
	short staff;
	bool playback;
	unsigned char velocity;
	int xml_note;
};

class OctaveShift{
public:
	OctaveShift()
		:octaveShiftType(OctaveShift_None)
		,length(0)
		,end_tick(0)
		,offset_y(0)
		,staff(0)
		,xml_note(0)
	{
	}
	~OctaveShift() {}

	CommonBlock pos;
	OctaveShiftType octaveShiftType;
	unsigned short length, end_tick;
	short offset_y;
	short staff;
	int xml_note;
};

class BeamElem {
public:
	BeamElem()
	{
		memset(this, 0, sizeof(BeamElem));
	}
	~BeamElem() {}

	unsigned char tupletCount;
	unsigned char start_measure_pos,stop_measure_pos;
	short start_measure_offset, stop_measure_offset;
	unsigned char beam_type;
	unsigned char level;		//1,2...
	int xml_beam_number;
	std::shared_ptr<OveNote> lily_start_note, lily_stop_note;
};

class OveBeam{
public:
	OveBeam()
		:staff(0)
		,stop_staff(0)
		,voice(0)
		,left_line(0)
		,right_line(0)
		,tupletCount(0)
		,isGrace(false)
		,drawPos_x(0)
		,drawPos_y(0)
		,drawPos_width(0)
		,drawPos_height(0)
	{
	}
	~OveBeam() {}

	CommonBlock pos;
	short staff,stop_staff;
	unsigned char voice;
	char left_line,right_line;
	unsigned char tupletCount;
	std::vector<std::shared_ptr<BeamElem> > beam_elems;
	bool isGrace;

	//used for display
	long drawPos_x, drawPos_y, drawPos_width, drawPos_height;
	std::shared_ptr<OveNote> beam_start_note, beam_stop_note;
};

class OveWedge{
public:
	OveWedge()
		:wedgeType(0)
		,offset_y(0)
		,wedgeOrExpression(false)
		,wedge_height(0)
		,staff(0)
		,xml_staff(0)
		,xml_start_note(0)
		,xml_stop_note(0)
	{
	}
	~OveWedge() {}

	CommonBlock pos;					//start_offset, tick
	OffsetCommonBlock offset;	//stop_measure,stop_offset
	unsigned char wedgeType;	//WedgeType
	short offset_y;
	bool wedgeOrExpression;		//YES: wedge, NO: expression
	short wedge_height;
	unsigned char staff;
	std::string expression_text;

	short xml_staff;
	int xml_start_note, xml_stop_note;
};

class CommonSlur{
public:
	CommonSlur()
		:staff(0)
		,stop_staff(0)
		,xml_slur_number(0)
		,xml_start_measure_index(0)
		,xml_start_note_index(0)
		,xml_start_elem_index(0)
		,xml_stop_measure_index(0)
		,xml_stop_note_index(0)
	{
	}
	~CommonSlur() {}

	short staff, stop_staff;
	CommonBlock pos;
	PairEnds pair_ends;
	OffsetCommonBlock offset;

	short xml_slur_number;
	std::shared_ptr<OveNote> slur_start_note, slur_stop_note;
	int xml_start_measure_index, xml_start_note_index, xml_start_elem_index, xml_stop_measure_index, xml_stop_note_index;
};

class MeasureSlur : public CommonSlur {
public:
	MeasureSlur()
		:voice(0)
		,slur1_above(false)
	{
	}
	~MeasureSlur() {}

	unsigned char voice;
	bool slur1_above;
};

class MeasureTie : public CommonSlur {
public:
	MeasureTie()
		:above(false)
		,xml_tie_number(0)
		,xml_note_value(0)
 		//,xml_start_elem(NULL)
 		//,xml_belongto_measure(NULL)
		,midi_note_value(0)
		//,xml_start_measure_index(0)
		//,xml_start_note_index(0)
		//,xml_start_elem_index(0)
	{
	}
	~MeasureTie() {}

	bool above;
	short xml_tie_number, xml_note_value;
 	//NoteElem* xml_start_elem;
 	//OveMeasure* xml_belongto_measure;
	short midi_note_value;
	//int xml_start_measure_index, xml_start_note_index, xml_start_elem_index;
};

class OveTuplet : public CommonSlur {
public:
	OveTuplet()
		:tuplet(0)
	{
	}
	~OveTuplet() {}

	unsigned char tuplet;
};

class MeasureGlissando : public CommonSlur {
public:
	MeasureGlissando()
		:straight_wavy(false)
	{
	}
	~MeasureGlissando() {}

	bool straight_wavy;
};

class MeasurePedal : public CommonSlur {		//parsePedal
public:
	MeasurePedal()
		:isLine(false)
	{
	}
	~MeasurePedal() {}

	bool isLine;
};

class Tempo {
public:
	Tempo()
		:offset_y(0)
		,font_size(0)
		,left_note_type(0)
		,tempo_range(0)
		,tempo(0)
	{
	}
	~Tempo() {}

	CommonBlock pos;
	std::string tempo_left_text;
	short offset_y, font_size;
	unsigned char left_note_type, tempo_range;
	unsigned short tempo;
};

class NumericEnding {
public:
	NumericEnding()
		:numeric_measure_count(0)
		,offset_y(0)
		,ending_play(false)
		,jumpCount(0)
	{
	}
	~NumericEnding() {}
	int getJumpCount();

	std::string numeric_text;
	unsigned short numeric_measure_count;
	CommonBlock pos;
	short offset_y;
	bool ending_play;

private:
	int jumpCount;
};

class MeasureLyric {		//parseLyric
public:
	MeasureLyric()
		:verse(0)
		,voice(0)
		,staff(0)
	{
	}
	~MeasureLyric() {}

	CommonBlock pos;
	OffsetElement offset;
	std::string lyric_text;
	unsigned char verse, voice;
	short staff;
};

typedef struct tagHarmonyGuitarFrame {
	CommonBlock pos;
	HarmonyType type;
	unsigned char root, bass;
	tagHarmonyGuitarFrame()
		:type(Harmony_None)
		,root(0)
		,bass(0)
	{
	}
} HarmonyGuitarFrame;

typedef struct tagMeasureKey {
	int key, previousKey;
	unsigned char symbolCount;
	tagMeasureKey()
	{
		memset(this, 0, sizeof(tagMeasureKey));
	}
} MeasureKey;

typedef struct tagTimeSignatureParameter {
	unsigned short beat_start;
	unsigned short beat_length;			// beat length unit
	unsigned short beat_start_tick;		// beat start tick
	tagTimeSignatureParameter()
	{
		memset(this, 0, sizeof(tagTimeSignatureParameter));
	}
} TimeSignatureParameter;

typedef struct tagMidiController {
	unsigned short tick;
	unsigned short pitch_wheel_value;				//Midi_PitchWheel
	MidiCtrlType midi_type;
	unsigned char controller_value, controller_number;		//Midi_Controller
	unsigned char channel_pressure;					//Midi_ChannelPressure
	unsigned char programechange_patch;		//Midi_ProgramChange
	tagMidiController()
	{
		memset(this, 0, sizeof(tagMidiController));
	}
} MidiController;

class OveMeasure {
public:
	OveMeasure()
		:repeat_play(false)
		,number(0)
		,show_number(0)
		,belone2line(0)
		,left_barline(Barline_Default)
		,right_barline(Barline_Default)
		,repeat_count(0)
		,typeTempo(0)
		,numerator(0)
		,denominator(0)
		,meas_length_size(0)
		,meas_length_tick(0)
		,fifths(0)
		,repeat_type(Repeat_Null)
		,xml_division(0)
		,xml_staves(0)
		,xml_new_page(false)
		,xml_new_line(false)
		,xml_top_system_distance(0)
		,xml_system_distance(0)
		,xml_staff_distance(0)
		,xml_firstnote_offset_x(0)
		,lily_line_break(false)
		,midi_start_timestamp(0.0f)
		,page(0)
	{
	}
	~OveMeasure() {}
	void checkDontPlayedNotes();

	bool repeat_play;
	int number, show_number;
	int belone2line;
	//MEAS
	BarlineType left_barline;
	BarlineType right_barline;
	unsigned char repeat_count;
	short typeTempo;

	//COND parseTimeSignature
	unsigned char numerator;
	unsigned char denominator;
	unsigned short meas_length_size;
	unsigned short meas_length_tick;	//bar length (tick)

	//BDAT parseNoteRest
	std::vector<std::shared_ptr<OveNote> > notes;
	std::map<std::string, std::vector<std::shared_ptr<OveNote> > > sorted_notes;
	std::vector<std::string> sorted_duration_offset;
	std::vector<std::shared_ptr<OveBeam> > beams;
	std::vector<std::shared_ptr<MeasureSlur> > slurs;
	std::vector<std::shared_ptr<MeasureTie> > ties;
	std::vector<std::shared_ptr<OveTuplet> > tuplets;
	std::vector<std::shared_ptr<HarmonyGuitarFrame> > harmony_guitar_frames;
	std::vector<std::shared_ptr<MidiController> > midi_controllers;
	std::vector<std::shared_ptr<OveDynamic> > dynamics;		//parseDynamics  mp,p,f....
	std::vector<std::shared_ptr<OveWedge> > wedges;
	std::vector<std::shared_ptr<OctaveShift> > octaves;
	std::vector<std::shared_ptr<MeasureGlissando> > glissandos;
	std::vector<std::shared_ptr<MeasureClef> > clefs;

	int fifths;
	MeasureKey key;
	std::vector<std::shared_ptr<MeasureDecorators> > decorators;
	std::vector<std::shared_ptr<MeasureLyric> > lyrics;
	std::vector<std::shared_ptr<MeasurePedal> > pedals;
	std::vector<std::shared_ptr<NumericEnding> > numerics;		//repeat numberic ending

	//parseRepeatSymbol
	RepeatType repeat_type;
	std::string repeat_string;
	CommonBlock repeate_symbol_pos;
	OffsetElement repeat_offset;

	short xml_division;
	short xml_staves;
	bool xml_new_page, xml_new_line;
	int xml_top_system_distance, xml_system_distance, xml_staff_distance, xml_firstnote_offset_x;
	std::string xml_number;
	bool lily_line_break;
	float midi_start_timestamp;

	std::vector<std::shared_ptr<OveImage> > images;
	std::vector<std::shared_ptr<OveText> > meas_texts;
	std::vector<std::shared_ptr<MeasureExpressions> > expressions;
	std::vector<std::shared_ptr<Tempo> > tempos;
	int page;		//for display
};

class OvePage {
public:
	OvePage()
	{
		memset(this, 0, sizeof(OvePage));
	}
	~OvePage() {}

	unsigned short begin_line,line_count;
	unsigned short system_distance;
	unsigned short staff_distance;
	unsigned short xml_top_system_distance;
};

typedef struct tagLineStaff {
	short y_offset;
	ClefType clef;
	bool hide;
	unsigned char group_staff_count;
	tagLineStaff()
	{
		memset(this, 0, sizeof(tagLineStaff));
	}
} LineStaff;

class OveLine {
public:
	OveLine()
		:fifths(0)
		,bar_count(0)
		,begin_bar(0)
		,y_offset(0)
		,xml_system_distance(0)
		,xml_staff_distance(0)
	{
	}
	~OveLine() {}

	short fifths;
	unsigned short bar_count,begin_bar;
	short y_offset;
	std::vector<std::shared_ptr<LineStaff> > staves;
	short xml_system_distance, xml_staff_distance;
};

typedef struct tagtrack_voice {
	struct {
		unsigned char r1[4];
		unsigned char r2;
		unsigned char channel;	//[0,15]
		char volume;						//[-1,127], -1 default
		char pitch_shift;				//[-36,36]
		char pan;							//[-64,63]
		unsigned char r3[4];
		unsigned char r4[2];
		char patch;						//[0,127]
	} voices[8];
	unsigned char stem_type[8];		//0,1,2
	tagtrack_voice()
	{
		memset(this, 0, sizeof(tagtrack_voice));
	}
} track_voice;			//16*8+8 = 136bytes

typedef struct tagtrack_note {
	char line[16];
	unsigned char head_type[16];
	unsigned char pitch[16];
	unsigned char voice[16];
	tagtrack_note()
	{
		memset(this, 0, sizeof(tagtrack_note));
	}
} track_node;

class OveTrack{
public:
	OveTrack()
		:transpose_value(0)
		,voice_count(0)
		,start_clef(Clef_None)
		,transpose_clef(Clef_None)
	{
	}
	~OveTrack() {}

	unsigned char transpose_value;		//[-127, 127]
	unsigned char voice_count;
	std::string track_name, track_brief_name;
	ClefType start_clef,transpose_clef;

	track_voice voice;
	track_node node;
};

typedef struct tagXmlPart {
	std::string part_name;
	unsigned char from_staff, staves, patch;
	tagXmlPart()
		:from_staff(0)
		,staves(0)
		,patch(0)
	{
	}
} XmlPart;

class VmusMusic {
public:
	VmusMusic()
		:page_height(0)
		,page_width(0)
		,page_num(0)
		,xml_page_height(0)
		,page_top_margin(0)
		,page_bottom_margin(0)
		,page_left_margin(0)
		,page_right_margin(0)
		,max_measures(0)
		,xml_parts(NULL)
		,version(0)
	{
	}
	~VmusMusic() {}
	
	std::string work_title;
	std::string work_number;		//xml: e.g. Op. 98
	std::string movement_title;
	std::string movement_number;
	std::string composer, lyricist, rights;
	std::string source, software, encoding_date;
	
	int page_height,page_width, page_num, xml_page_height;
	int page_top_margin,page_bottom_margin;
	int page_left_margin, page_right_margin;
	int max_measures;

	std::vector<std::shared_ptr<OvePage> > pages;
	std::vector<std::shared_ptr<OveLine> > lines;
	std::vector<std::shared_ptr<OveTrack> > trackes;
	std::vector<std::shared_ptr<OveMeasure> > measures;
	
	std::shared_ptr<XmlPart> xml_parts;
	unsigned char version;

	std::shared_ptr<OveWedge> opened_wedge1, opened_wedge2;
};
#endif		//VMUSMUSIC_H_