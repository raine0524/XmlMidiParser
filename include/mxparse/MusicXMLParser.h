#ifndef	MUSICXMLPARSER_H_
#define	MUSICXMLPARSER_H_

#define MAX_CLEFS 30
#define MEASURES_EACH_LINE 4
#define LINES_EACH_PAGE 4

#define	VELOCITY_HIGH	90
#define	VELOCITY_MID		80
#define	VELOCITY_LOW	70

typedef enum
{
	DEVICE_PAD = 0,
	DEVICE_PHONE
} DeviceType;

typedef enum
{
	ENUM_USED_FOR_CHECK = 0,
	ENUM_USED_FOR_GENTXT
} TOOL_USAGE;

typedef enum
{
	ERROR_UNKNOWN = 0,
} ERROR_STATUS;

typedef struct
{
	bool used;
	int shift_size, start_tick, start_measure;
	int stop_tick, stop_measure;
	int octave_start_offset_y;
} OctaveShiftData;

typedef struct tagChunkSummary
{
	bool bNoteSeqCorrect;		//check whether the note sequence is correct
	bool bLikeMeasure;			//judge whether this chunk looks like a measure
	char repeat_num;					//how many times this measure is played 
	int real_meas_num;				//the real measure number, equal to mm
	int start_nn;							//start note index in this chunk
	std::multimap<int, int> mGrace;	//it->first: nn, it->second: note in one measure
	size_t note_elem_num;		//the regular note_elem number that the rest is not included
	size_t continue_rests;			//the continue rest number start with rest in the head of measure
	size_t total_entries;				//total entries in this chunk
	const char* pChunkStart, *pChunkEnd;

	void reset()
	{
		bNoteSeqCorrect = true;
		bLikeMeasure = false;
		repeat_num = 1;
		real_meas_num = 0;
		start_nn = -1;
		note_elem_num = 0;
		continue_rests = 0;
		total_entries = 0;
		pChunkStart = nullptr;
		pChunkEnd = nullptr;
		if (!mGrace.empty())
			mGrace.clear();
	}

	tagChunkSummary()
	{
		this->reset();
	}
} ChunkSummary;

typedef struct tagEntrySummary
{
	bool bExistEmptyItem;
	int index, nn, staff, note_value;
	std::string strNote;
	const char* pEntryStart;

	void reset()
	{
		bExistEmptyItem = false;
		index = 0;
		nn = -1;
		staff = 0;
		note_value = 0;
		strNote = "";
		pEntryStart = nullptr;
	}

	tagEntrySummary()
	{
		this->reset();
	}
} EntrySummary;

int GetFileSize(const char* pFileName);

void PARSE_DLL WriteFormatTxtWithoutXml(MidiFile* midi, const char* pFileName);

class PARSE_DLL MusicXMLParser
{
public:
	MusicXMLParser();
	~MusicXMLParser();

public:
	VmusMusic* m_pMusicScore;
	hyStatus ParseMusicXML(const char* pFileName, DeviceType type, TOOL_USAGE eUsage, FILE* pLogFile);
	void checkMidiSequence(MidiFile* midiFile, const char* pFileName, bool bVideoMidi);

private:
	hyStatus ReadMusicXML(const char* pFileName, int nFileSize, char* pMusicXMLBuffer);
	int CheckMusicXMLEncodeUTF8(tinyxml2::XMLDocument* doc);
	hyStatus BuildMusicScore(tinyxml2::XMLDocument* doc);

	void BuildPartlist(tinyxml2::XMLElement* element);
	void BuildPart(tinyxml2::XMLElement* element);
	void BuildWork(tinyxml2::XMLElement* element);
	void BuildIdentification(tinyxml2::XMLElement* element);
	void BuildDefaults(tinyxml2::XMLElement* element);
	void BuildMovementNumber(tinyxml2::XMLElement* element);
	void BuildMovementTitle(tinyxml2::XMLElement* element);
	void BuildCredit(tinyxml2::XMLElement* element);

	///BuildDefaultsElement
	void BuildDefaultsScaling(tinyxml2::XMLElement* sub_element) {}
	void BuildDefaultsPageLayout(tinyxml2::XMLElement* sub_element);
	void BuildDefaultsSystemLayout(tinyxml2::XMLElement* sub_element);
	void BuildDefaultsStaffLayout(tinyxml2::XMLElement* sub_element);
	void BuildDefaultsMusicFont(tinyxml2::XMLElement* sub_element) {}
	void BuildDefaultsWordFont(tinyxml2::XMLElement* sub_element) {}
	void BuildDefaultsLyricFont(tinyxml2::XMLElement* sub_element) {}
	void BuildDefaultsAppearance(tinyxml2::XMLElement* sub_element) {}
	void BuildDefaultsLyricLanguage(tinyxml2::XMLElement* sub_element) {}

	std::shared_ptr<OveNote> parseNote(tinyxml2::XMLElement* note_elem, bool* isChord, std::shared_ptr<OveMeasure>& measure, int start_staff, int tick);
	bool parseAttributes(tinyxml2::XMLElement* attributes_elem, std::shared_ptr<OveMeasure>& measure, int start_staff, std::shared_ptr<OveNote> afterNote, int tick);
	void parseMeasure(tinyxml2::XMLElement* measure_elem, int start_staff, std::shared_ptr<OveMeasure>& measure);
	void processLyrics();
	void processBeams();
	void processSlursPrev();
	void processSlursAfter();
	void processTies();
	void processFingers();
	void processPedals();
	void processRestPos();
	void processStaves();
	void processTuplets();

	int getSlurLine(OveNote* note, bool above);
	int PatchForInstrumentName(const std::string& name);
	int numOf32ndOfNoteType(NoteType note_type, int dots);
	int noteValueForStep(int pitch_step, int pitch_octave, int pitch_alter);
	NoteType noteType(const std::string& type);
	void getUpper(int* upper, int* lower, std::shared_ptr<NoteElem>& elem, int fifths, AccidentalType accidental_mark, unsigned char staff, std::shared_ptr<OveMeasure>& measure, int nn);
	std::shared_ptr<NoteArticulation> changedArticulationOfNote(std::shared_ptr<OveNote>& note);
	int tappedNoteElems(char* values, std::shared_ptr<OveNote>& note, std::shared_ptr<OveNote>& nextNote, std::shared_ptr<NoteArticulation>& art, int below_note, int upper_note);
	void setEventTrack(std::vector<Event>::iterator event, std::shared_ptr<OveNote>& note, std::shared_ptr<NoteElem>& elem, bool videoMidi, MidiFile* midiFile, int index);
	bool setEventUserdata(std::vector<Event>::iterator event, int tt, std::vector<Event>& midiEvents, int mm, int nn, int i_notes, int ee, std::shared_ptr<NoteElem>& elem, std::shared_ptr<OveMeasure>& measure, std::shared_ptr<OveNote>& note, int meas_start_tick, bool trill, bool videoMidi, MidiFile* midiFile);

	int CalculateNoteLastTick(std::vector<Event>::iterator event, std::vector<Event>& midiEvents);
	bool CheckLastNotesDontPlay(std::vector<std::shared_ptr<OveNote> >& notes);
	void ObtainSpecificItem(const char* pStart, size_t column, const char** pItem);
	void CollectChunkInfos(const char* pStart, std::vector<std::pair<std::string, ChunkSummary> >& vChunkSummary);
	void CollectEntryInfos(const char* pChunkStart, std::vector<EntrySummary>& vEntrySummary);
	bool GetMeasNoteElemsInfos(size_t meas_num, ChunkSummary& chunk_summary);
	ERROR_STATUS DetectErrorStatus(std::vector<std::pair<std::string, ChunkSummary> >& vChunkSummary, int chunk_index, std::vector<EntrySummary>& vEntrySummary, int entry_index, int lost_index);
	void AnalyseErrors(const std::string& strTextCont, const std::vector<int>& xml_lost_index, bool bTickLessThanTen, bool bXmlLeftover, bool bTempoCorrect, int incorrectTempo1, int incorrectTempo2);
private:
	int system_index;
	int default_top_system_distance, default_staff_distance, default_system_distance;
	int min_staff_distance, min_system_distance, max_staff_distance, max_system_distance;
	float LINE_height;
	OctaveShiftData octave_shift_data[2];

	ClefType last_clefs[MAX_CLEFS];
	int last_clefs_tick[MAX_CLEFS];
	ClefType measure_start_clefs[MAX_CLEFS];
	int last_key_fifths, last_numerator, last_denominator;
	int last_divisions, part_staves;

	std::vector< std::map<std::string, std::string> >* parts;
	int max_measures, staff, metronome_per_minute;
	float duration_per_256th;
	bool chord_inBeam;
	TOOL_USAGE m_eUsage;
	FILE* m_pLogFile;
};
#endif		//MUSICXMLPARSER_H_