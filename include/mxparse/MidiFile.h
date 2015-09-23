#ifndef	MIDIFILE_H_
#define	MIDIFILE_H_

//if evt=0xB0(Control change), nn is:
#define GM_Control_Modulation_Wheel	1
#define GM_Control_Volumel						7
#define GM_Control_Strenth						9
#define GM_Control_Pan								10
#define GM_Control_Expression					11
#define GM_Control_Pedal							64
#define GM_Control_ResetAllControl			121
#define GM_Control_AllNotesOff				123

//midi device -> mac os
#define GM_Control_NRPN_Increment		96	//0x60 vv:00 +1	1~127
#define GM_Control_NRPN_Decrement		97	//0x61 vv:00	-1		1~127
#define GM_Control_NRPN_LSB					98	//0x62 vv:0x07
#define GM_Control_NRPN_MSB					99	//0x63 vv:0x37

//mac os -> midi device
//adjust speaker volume
//F0 0x41 0x00 0x42 0x12 0x40 0x00 0x04 vv xx 0xf7  //vv default=0x7f
//adjust auto play volume
//B0 07 vv


class BaseEvent
{
public:
	BaseEvent() : tick(0), track(0) {}
	~BaseEvent() {}

	unsigned char track;
	int tick;
};

class Event : public BaseEvent
{
public:
	Event()
		:evt(0)
		,nn(0)
		,vv(0)
		,xml_is_empty(true)
		,mm(0)
		,note_index(0)
		,note_staff(0)
		,last_tick(0)
		,finger(0)
		,play_priority(0)
		,track_priority(0)
	{
	}
	~Event() {}

	unsigned char evt, nn, vv;
	bool xml_is_empty;
	int mm, note_index, note_staff, last_tick, tick_offset, finger, oveline;
	int play_priority, track_priority;
	std::string elem_id, measure;
};

class TextEvent : public BaseEvent
{
public:
	std::string text;
};

class SpecificInfoEvent : public BaseEvent
{
public:
	std::vector<unsigned char> infos;
};

class TempoEvent : public BaseEvent
{
public:
	TempoEvent() : tempo(0) {}
	~TempoEvent() {}

	int tempo;		//usec/ед to  ед/min
};

class TimeSignatureEvent : public BaseEvent
{
public:
	TimeSignatureEvent() : numerator(0), denominator(0), number_ticks(0), number_32nd_notes(0) {}
	~TimeSignatureEvent() {}

	int numerator, denominator, number_ticks, number_32nd_notes;
};

class KeySignatureEvent : public BaseEvent
{
public:
	KeySignatureEvent() : sf(0), mi(0) {}
	~KeySignatureEvent() {}

	int sf, mi;
};

class SysExclusiveEvent : public BaseEvent
{
public:
	std::vector<unsigned char> event;
};

class ITrack
{
public:
	ITrack() : number(0) {}
	~ITrack() {}

	int number;
	std::string name;
	std::string instrument;
	std::vector<Event> events;
	std::vector<TextEvent> lyrics, texts;
	std::vector<SpecificInfoEvent> specificEvents;
};

class MidiFile
{
private:
	//callback function for std::sort
	static bool sort_ascending_order_tick(const Event& obj1, const Event& obj2);

public:
	MidiFile() : onlyOneTrack(false), quarter(0), format(0), maxTracks(0) {}
	~MidiFile() 
	{
		format = 1;
		quarter = 480;
	}

	std::string strFileName;
	std::vector<TextEvent> markers, cuePoints;
	std::vector<TempoEvent> tempos;
	std::vector<TimeSignatureEvent> timeSignatures;
	std::vector<KeySignatureEvent> keySignatures;
	std::vector<SysExclusiveEvent> sysExclusives;
	std::vector<ITrack> tracks;

	bool onlyOneTrack;
	int quarter, format;
	std::string author, name, copyright;
	std::vector<Event> _mergedMidiEvents;
	int maxTracks;

	ITrack* getTrack(int idx) { return &tracks[idx]; }
	ITrack* getTrackPianoTrack();
	double secPerTick();
	std::vector<Event>& mergedMidiEvents();
};

#endif		//MIDIFILE_H_