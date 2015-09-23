#include "ParseExport.h"
#include "MeasureToTick.h"

#ifdef TARGET_OS_IPHONE
#define ONLY_ONE_PAGE
#endif

#define	MAX_NOTE_ELEMS	512

int GetFileSize(const char* pFileName)
{
	if (!pFileName)
		return -1;

	int nFileSize;
#ifdef WIN32
	WIN32_FIND_DATA stFileInfo;
	HANDLE hFile = FindFirstFile(pFileName, &stFileInfo);
	if (INVALID_HANDLE_VALUE == hFile) {
		nFileSize = -2;
	} else {
		nFileSize =  stFileInfo.nFileSizeLow;
		FindClose(hFile);
	}
#else
	if (-1 == access(pFileName, 0)) {
		nFileSize = -3;
	} else {
		struct stat buf;
		if (-1 == stat(pFileName, &buf))
			nFileSize = -4;
		else
			nFileSize = buf.st_size;
	}
#endif
	return nFileSize;
}

MusicXMLParser::MusicXMLParser()
	:m_pMusicScore(NULL)
	,parts(nullptr)
{
	parts = new std::vector< std::map<std::string, std::string> >();
}

MusicXMLParser::~MusicXMLParser()
{
	if (m_pMusicScore) 
	{
		delete m_pMusicScore;
		m_pMusicScore = NULL;
	}
	if (parts)
	{
		delete parts;
		parts = nullptr;
	}
}

hyStatus MusicXMLParser::ParseMusicXML(const char* pFileName, DeviceType type, TOOL_USAGE eUsage, FILE* pLogFile)
{
	if (!pFileName)
		return MUSIC_ERROR_ARGS_INVALID;

	if (m_pMusicScore)
	{
		delete m_pMusicScore;
		m_pMusicScore = NULL;
	}

	m_pMusicScore = new VmusMusic();
	if (!m_pMusicScore)
		return MUSIC_ERROR_MEM_NOT_ENOUGH;

	m_eUsage = eUsage;
	m_pLogFile = pLogFile;
	system_index = 0;
	LINE_height = 10;

#if defined(TARGET_OS_MAC) && !defined(TARGET_OS_EMBEDDED) && !defined(TARGET_OS_IPHONE)
	min_staff_distance = LINE_height*9;
	min_system_distance = LINE_height*11;
	max_staff_distance = LINE_height*16;
	max_system_distance = LINE_height*18;
#else
	if (DEVICE_PAD == type) {
		min_staff_distance = LINE_height*9;
		min_system_distance = LINE_height*12;
		max_staff_distance = LINE_height*16;
		max_system_distance = LINE_height*18;
	} else if (DEVICE_PHONE == type) {
		min_staff_distance = LINE_height*8;
		min_system_distance = LINE_height*9;
		max_staff_distance = LINE_height*8;
		max_system_distance = LINE_height*9;
	}
#endif

	default_top_system_distance = 0;
	default_staff_distance = 0;
	default_system_distance = 0;
	
	last_key_fifths = 0;
	last_numerator = 4;
	last_denominator = 4;
	last_divisions = 0;
	part_staves = 1;
	//octave_shift_size = 0;
	//octave_shift_staff = 0;
	memset(octave_shift_data, 0, sizeof(OctaveShiftData)*2);
	max_measures = 0;
	staff = 0;
	metronome_per_minute = 0;
	duration_per_256th = 0;
	chord_inBeam = false;
	for (int i = 0; i < MAX_CLEFS; i++)
	{
		last_clefs[i] = measure_start_clefs[i] = Clef_None;
		last_clefs_tick[i] = -1;
	}
	if (!parts->empty())
		parts->clear();

	hyStatus sts = MUSIC_ERROR_NONE;
	int nFileSize = GetFileSize(pFileName);
	if (nFileSize < 0)
		return MUSIC_ERROR_GET_FILE_ATTRI;
	if (0 == nFileSize)
		return MUSIC_WARN_FILE_EMPTY;

	char* pMusicXMLBuffer = new char[nFileSize];
	if (!pMusicXMLBuffer) {
		return MUSIC_ERROR_MEM_NOT_ENOUGH;
	} else {
		sts = ReadMusicXML(pFileName, nFileSize, pMusicXMLBuffer);
		if (MUSIC_ERROR_NONE != sts)
		{
			delete []pMusicXMLBuffer;
			return sts;
		}
	}

	tinyxml2::XMLDocument* doc = new tinyxml2::XMLDocument();
	if (!doc)
	{
		delete []pMusicXMLBuffer;
		return MUSIC_ERROR_MEM_NOT_ENOUGH;
	}
	
	if (tinyxml2::XML_NO_ERROR != doc->Parse(pMusicXMLBuffer, nFileSize))
	{
		delete doc;
		delete []pMusicXMLBuffer;
		return MUSIC_ERROR_TINYXML2_PARSE_ERROR;
	}
	sts = BuildMusicScore(doc);
	delete doc;
	delete []pMusicXMLBuffer;
	return sts;
}

void MusicXMLParser::getUpper(int* upper, int* lower, std::shared_ptr<NoteElem>& elem, int fifths, AccidentalType accidental_mark, unsigned char staff, std::shared_ptr<OveMeasure>& measure, int nn)
{
	int upper_step = elem->xml_pitch_step+1;
	int upper_octave = elem->xml_pitch_octave;
	int upper_alter = 0;		//elem->xml_pitch_alter;
	if (upper_step > 7)
	{
		upper_step = 1;
		upper_octave++;
	}

	int below_step = elem->xml_pitch_step-1;
	int below_octave = elem->xml_pitch_octave;
	int below_alter = 0;		//elem->xml_pitch_alter;
	if (below_step < 1)
	{
		below_step = 7;
		below_octave--;
	}

	if (Accidental_Sharp == accidental_mark) {
		below_alter = 1;
		upper_alter = 1;
	} else if (Accidental_Flat == accidental_mark) {
		below_alter = -1;
		upper_alter = -1;
	} else if (Accidental_Normal == accidental_mark) {
		/*This case means the  upper-note and lower-note only influenced by the clef in the head of one system. 
		 *And there exist a case that the sharp/flat flag may occurs in the internal of one measure, the latter case
		 *has a higher priority in generally.
		 */
		char minusFifths[8] = {0, 7, 3, 6, 2, 5, 1, 4};		//bB, bE, bA, bD, bG, bC, bF
		if (fifths < 0) {
			for (int i = 1; i < -fifths+1; i++)
			{
				if (minusFifths[i] == below_step)
					below_alter = -1;
				if (minusFifths[i] == upper_step)
					upper_alter = -1;
			}
		} else if (fifths > 0) {
			for (int i = 7; i > 7-fifths; i--)
			{
				if (minusFifths[i] == below_step)
					below_alter = 1;
				if (minusFifths[i] == upper_step)
					upper_alter = 1;
			}
		}
#if 1
		std::map<int, int> mStepAlter;		//key: xml_pitch_step, value: xml_pitch_alter
		for (; nn >= 0; --nn) {
			auto& notes = measure->sorted_notes[measure->sorted_duration_offset[nn]];
			for (auto note = notes.begin(); note != notes.end(); note++) {
				if ((*note)->staff == staff) {
					for (auto note_elem = (*note)->note_elems.begin(); note_elem != (*note)->note_elems.end(); note_elem++) {
						if ((*note_elem)->xml_pitch_alter && mStepAlter.find((*note_elem)->xml_pitch_step) == mStepAlter.end())
							mStepAlter[(*note_elem)->xml_pitch_step] = (*note_elem)->xml_pitch_alter;
					}
				}
			}
		}
		if (!mStepAlter.empty())
		{
			if (mStepAlter.find(upper_step) != mStepAlter.end())
				upper_alter = mStepAlter[upper_step];
			if (mStepAlter.find(below_step) != mStepAlter.end())
				below_alter = mStepAlter[below_step];
		}
#endif
	}

	int upper_note = noteValueForStep(upper_step, upper_octave, upper_alter);
	int below_note = noteValueForStep(below_step, below_octave, below_alter);

	*upper = upper_note-elem->note;
	*lower = below_note-elem->note;
	if (*upper > 2)
		*upper = 2;
	if (*lower < -2)
		*lower = -2;
	
	/*
	#  ||
		||  C  | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
	-----------------------------------------------------------------------------
	0  ||   0 |   1 |   2 |   3 |   4 |   5 |   6 |   7 |   8 |   9 |  10 | 11
	0  ||  12 |  13 |  14 |  15 |  16 |  17 |  18 |  19 |  20 |  21 |  22 | 23
	1  ||  24 |  25 |  26 |  27 |  28 |  29 |  30 |  31 |  32 |  33 |  34 | 35
	2  ||  36 |  37 |  38 |  39 |  40 |  41 |  42 |  43 |  44 |  45 |  46 | 47
	3  ||  48 |  49 |  50 |  51 |  52 |  53 |  54 |  55 |  56 |  57 |  58 | 59
	4  ||  60 |  61 |  62 |  63 |  64 |  65 |  66 |  67 |  68 |  69 |  70 | 71
	5  ||  72 |  73 |  74 |  75 |  76 |  77 |  78 |  79 |  80 |  81 |  82 | 83
	6  ||  84 |  85 |  86 |  87 |  88 |  89 |  90 |  91 |  92 |  93 |  94 | 95
	7  ||  96 |  97 |  98 |  99 | 100 | 101 | 102 | 103 | 104 | 105 | 106 | 107
	8  || 108 | 109 | 110 | 111 | 112 | 113 | 114 | 115 | 116 | 117 | 118 | 119
	9  || 120 | 121 | 122 | 123 | 124 | 125 | 126 | 127 |
     
    unsigned char scales_map[15][8]={
        {-1,1,3,4,6,8,10,11},//fifths=-7, bB,bE,bA,bD,bG,bC,bF
        {-1,1,3,5,6,8,10,11},//fifths=-6, bB,bE,bA,bD,bG,bC
        {0,1,3,5,6,8,10,12}, //fifths=-5, bB,bE,bA,bD,bG
        {0,1,3,5,7,8,10,12}, //fifths=-4, bB,bE,bA,bD
        {0,2,3,5,7,8,10,12}, //fifths=-3, bB,bE,bA
        {0,2,3,5,7,9,10,12}, //fifths=-2, bB,bE
        {0,2,4,5,7,9,10,12}, //fifths=-1, bB
        {0,2,4,5,7,9,11,12}, //0
        {0,2,4,6,7,9,11,12}, //fifths=1, #F
        {1,2,4,6,7,9,11,13}, //fifths=2, #F, #C
        {1,2,4,6,8,9,11,13}, //fifths=3, #F, #C, #G
        {1,3,4,6,8,9,11,13}, //fifths=4, #F, #C, #G, #D
        {1,3,4,6,8,10,11,13},//fifths=5, #F, #C, #G, #D, #A
        {1,2,5,6,8,10,11,13},//fifths=6, #F, #C, #G, #D, #A,#E
        {1,2,5,6,8,10,12,13}, //fifths=7, #F, #C, #G, #D, #A,#E,#B
    };
	*/
}

std::shared_ptr<NoteArticulation> MusicXMLParser::changedArticulationOfNote(std::shared_ptr<OveNote>& note)
{
	if (note->note_elems.size() > 0 && note->note_arts.size() > 0) {
		for (auto art = note->note_arts.begin(); art != note->note_arts.end(); art++) {
			if (((*art)->art_type >= Articulation_Major_Trill && (*art)->art_type <= Articulation_Turn) || 
				((*art)->art_type >= Articulation_Tremolo_Eighth && (*art)->art_type <= Articulation_Tremolo_Sixty_Fourth))
				return *art;
		}
	}
	return nullptr;
}

//return array of note values [@() ...]
//startNote:-1:低一度 0:本音 1:高一度
int MusicXMLParser::tappedNoteElems(char* values, std::shared_ptr<OveNote>& note, std::shared_ptr<OveNote>& nextNote, std::shared_ptr<NoteArticulation>& art, int below_note, int upper_note)
{
	int values_count = 0;
	if (art->art_type >= Articulation_Major_Trill && art->art_type <= Articulation_Turn) {
		std::shared_ptr<NoteElem>& lastElem = note->note_elems.back();
		values[0] = lastElem->note;
		if (Articulation_Short_Mordent == art->art_type) {
			//短波音，本位音－低1度音－本位音
			values_count = 3;
			values[1] = lastElem->note+below_note;
			values[2] = lastElem->note;
		} else if (Articulation_Inverted_Short_Mordent == art->art_type) {
			/*
			逆波音:
			//本位音－高1度音－本位音
			//高1度音-本位音－高1度音－本位音

			3. 逆波音（Inverted Mordent/lower mordent）或下波音 Articulation_Inverted_Short_Mordent
			: a shake sign crossed by a vertical line:一个锯齿符号中间穿过一条竖线
			Articulation_Short_Mordent
			如果四分音符C音上又这个符号就是要弹奏：
			（1）C-B-C, 前两个是32分音符长，第三个是8分音符长加浮点
			（2）C-B-C, 前两个是16分音符长，第三个是8分音符长
			*/
			values_count = 3;
			values[1] = lastElem->note+upper_note;
			values[2] = lastElem->note;
		} else if (Articulation_Major_Trill == art->art_type || Articulation_Minor_Trill == art->art_type) {
			/*
			trillNoteType 颤音
			演奏方法：可以从主音／上方助音／下方助音（或乐谱上指示的小音符）开始快速演奏，基本按照32分音符的速度,可以回音结束（或乐谱上指示的小音符结束）。
			如： C的颤音:
			(1) 可以从主音开始：C,D,C,D,C,D .....D,C,B,C
			(2) 可以从上方助音开始：D,C,D,C,D,C .....D,C,B,C
			(3) 可以从下方助音开始：B,C,D,C,D,C .....D,C,B,C
			//颤音，32分音符的（本位音－高1度音）交替
			// 8分音符C: C-D-C 4-1
			// 4分音符C: C-D-C-D-C-D-C 8-1
			//4.分音符C: C-D-C-D-C-D-C-D-C-D-C 8+4-1
			// 2分音符C: C-D-C-D-C-D-C-D-C-D-C-D-C-D-C 16-1
			颤音演奏数目一般没有规律，主要的准则就是得听起来非常快。这首乐曲速度相对较慢。如果乐曲速度很慢，那一个全音符就无法按照32分音符，
			弹32次来衡量，因为这样衡量就会使得颤音太慢。同样的，如果乐曲速度很快，那一个全音符也无法按32音符来衡量，因为32分音符就会使得颤音太快。
			颤音的速度相对有一个比较清晰的标准，就是很快。具体在数字上就是大约一秒钟出来5~8个音，但是数目上来说却是自由的。
			一个全音符根据曲目速度不同可能会颤音许多不规律的音符，基本不会出现32次，64次或者16次此类太过于规律的情况。
			*/
			values_count = art->trill_num_of_32nd;
			for (int c = 0; c < values_count*2; c++)
			{
				if (c%2 == 1)
					values[c] = lastElem->note+upper_note;
				else
					values[c] = lastElem->note;
			}
		} else if (Articulation_Turn == art->art_type) {
			/*
			turn 回音
			1. 顺回音：音符上面一个横的S字， 如果标注在一个四分音符C上，表示要连续弹奏：
			//（1）本身，低一度音，本身
			（2）D-C-B-C: 4个16分音符
			（3）D-C-B-C: 前3个是一个（16分音符的）三连音，第4个补足(一般是8分音符或者需要加浮点)
			（4）C-D-C-B-C: 一个16分音符的5连音
			（5）C-D-C-B-C: 前4个是32分音符，第4个是8分音符; 如果记在两个音符之间，则第1个是8分音符，后4个是32分音符
			2. 逆回音：音符上面一个横的S字，中间穿过一个竖线， 如果标注在一个四分音符C上，表示要连续弹奏：
			（2）B-C-D-C: 4个16分音符
			（3）B-C-D-C: 前3个是一个（16分音符的）三连音，第4个是8分音符
			（4）C-B-C-D-C: 一个16分音符的5连音
			（5）C-B-C-D-C: 前4个是32分音符，第4个补足(一般是8分音符或者需要加浮点); 如果记在两个音符之间，则第1个是8分音符，后4个是32分音符

			如果回音上方或下方加了个变音：b或#
			那么最低的音（如B）要加上b或# （演奏成Bb,B#等）
			*/
			values_count = 5;
			values[1] = lastElem->note+upper_note;		//firstElem->note+2;
			values[2] = lastElem->note;
			values[3] = lastElem->note+below_note;		//firstElem->note-1;
			values[4] = lastElem->note;
		} else {
			printf("TODO: for articulation %d\n", art->art_type);
		}
	} else if (art->art_type >= Articulation_Tremolo_Eighth && art->art_type <= Articulation_Tremolo_Sixty_Fourth) {
		int numberOf64th = 1;
		if (Articulation_Tremolo_Eighth == art->art_type) {
			numberOf64th = 8;
		} else if (Articulation_Tremolo_Sixteenth == art->art_type) {
			numberOf64th = 4;
		} else if (Articulation_Tremolo_Thirty_Second == art->art_type) {
			numberOf64th = 2;
		}
		int totalOf64th = 16;
		if (Note_Whole == note->note_type) {
			totalOf64th = 64;
		} else if (Note_Half == note->note_type) {
			totalOf64th = 32;
		} else if (Note_Quarter == note->note_type) {
			totalOf64th = 16;
		}
		if (note->isDot)
			totalOf64th *= 1.5;
		values_count = totalOf64th/numberOf64th;

		if (art->tremolo_stop_note_count > 0 && nextNote) {
			values_count -= 1;
			auto& lastElem1 = note->note_elems.back();
			auto& lastElem2 = nextNote->note_elems.back();
			if (1 == note->note_elems.size()) {
				for (int i = 0; i < totalOf64th/2; ++i) {
					values[2*i] = lastElem1->note;
					values[2*i+1] = lastElem2->note;
				}
			} else {
				auto& firstElem = note->note_elems.front();
				for (int i = 0; i < totalOf64th/2; ++i)
				{
					values[2*i] = firstElem->note;
					values[2*i+1] = lastElem1->note;
				}
			}
		} else {
			auto& lastElem = note->note_elems.back();
			if (1 == note->note_elems.size()) {
				for (int i = 0; i < totalOf64th; ++i)
					values[i] = lastElem->note;
			} else {
				auto& firstElem = note->note_elems.front();
				for (int i = 0; i < totalOf64th/2; ++i) {
					values[2*i] = firstElem->note;
					values[2*i+1] = lastElem->note;
				}
			}
		}
	}
	return values_count;
}

void MusicXMLParser::setEventTrack(std::vector<Event>::iterator event, std::shared_ptr<OveNote>& note, std::shared_ptr<NoteElem>& elem, bool videoMidi, MidiFile* midiFile, int index)
{
	if (videoMidi) {		//video midi use normal midi's track info
		event->track = (elem->rightHand) ? 0 : 1;
		for (int i = index+1, len = midiFile->_mergedMidiEvents.size(); i < len; ++i)
		{
			auto& next = midiFile->_mergedMidiEvents[i];
			unsigned char evt = next.evt & 0xF0;
			if (0x80 == evt || (0x90 == evt && 0 == next.vv))
			{
				if (next.nn == event->nn)
				{
					next.track = event->track;
					break;
				}
			}
		}
	} else {
		if (midiFile->onlyOneTrack)
			event->track = note->staff-1;
		elem->rightHand = (0 == event->track);		//save track info to xml for video mode
	}
}

int MusicXMLParser::CalculateNoteLastTick(std::vector<Event>::iterator event, std::vector<Event>& midiEvents)
{
	//find this note's stop event
	auto nextEvent = event;
	for (nextEvent++; nextEvent != midiEvents.end(); nextEvent++)
	{
		unsigned char nextEvt = nextEvent->evt & 0xF0;
		unsigned char nextChannel = nextEvent->evt & 0x0F;
		if ((0x80 == nextEvt || (0x90 == nextEvt	&& 0 == nextEvent->vv)) && nextEvent->nn == event->nn && (event->evt & 0x0F) == nextChannel)
			break;
	}
	if (nextEvent != midiEvents.end())
		return nextEvent->tick-event->tick;
	else
		return -1;
}

bool MusicXMLParser::setEventUserdata(std::vector<Event>::iterator event, int tt, std::vector<Event>& midiEvents, int mm, int nn, int i_notes, int ee, std::shared_ptr<NoteElem>& elem, std::shared_ptr<OveMeasure>& measure, std::shared_ptr<OveNote>& note, int meas_start_tick, bool trill, bool videoMidi, MidiFile* midiFile)
{
	if (videoMidi) {		//video midi use normal midi's track info
		event->track = (elem->rightHand) ? 0 : 1;
		for (int i = tt+1, len = midiFile->_mergedMidiEvents.size(); i < len; ++i)
		{
			auto& next = midiFile->_mergedMidiEvents[i];
			unsigned char evt = next.evt & 0xF0;
			if (0x80 == evt || (0x90 == evt && 0 == next.vv))
			{
				if (next.nn == event->nn)
				{
					next.track = event->track;
					break;
				}
			}
		}
	} else {
		if (midiFile->onlyOneTrack)
			event->track = note->staff-1;
		elem->rightHand = (event->track == 0);		//save track info to xml for video mode
	}

	//finger
	int finger = 0;
	if (elem->xml_finger != "")
	{
		finger = atoi(elem->xml_finger.c_str());
		if (trill)
		{
			if (finger < 5 && ((event->nn > elem->note && 0 == event->track) || (event->nn < elem->note && 1 == event->track)))
				finger += 1;
			else if (finger > 0 && ((event->nn < elem->note && 0 == event->track) || (event->nn > elem->note && 1 == event->track)))
				finger -= 1;
		}
	}

	//get oveline
	int oveline = -1;
	for (int i = 0; i < m_pMusicScore->lines.size(); ++i)
	{
		auto& line = m_pMusicScore->lines[i];
		if (mm >= line->begin_bar && mm < line->begin_bar+line->bar_count)
		{
			oveline = i;
			break;
		}
	}

	//set elem_id
	int index_in_notes = 0;
	for (; index_in_notes < measure->notes.size(); index_in_notes++)
		if (note.get() == measure->notes[index_in_notes].get())
			break;
	char elem_id[32];
	sprintf(elem_id, "%d_%d_%d", mm, index_in_notes, ee);

	int note_duration = CalculateNoteLastTick(event, midiEvents);
	if (-1 != note_duration) {
		//event->userdata
		event->xml_is_empty = false;
		event->measure = measure->xml_number;
		event->mm = mm;
		event->note_index = nn;
		event->note_staff = event->track+1;
		event->last_tick = note_duration;
		event->tick_offset = event->tick-meas_start_tick;
		event->elem_id = elem_id;
		event->finger = finger;
		event->oveline = oveline;
		return true;
	} else {
		printf("Error: can not find note's stop event in midi %d,%d,%d,%d,%d\n", mm, nn, i_notes, ee, elem->note);
		return false;
	}
}

/* What if last notes' elements in current measure needn't play, this situation treated as extreme case still
 * have to check and deal with it.
 */
bool MusicXMLParser::CheckLastNotesDontPlay(std::vector<std::shared_ptr<OveNote> >& notes)
{
	for (auto note = notes.begin(); note != notes.end(); note++) {
		for (auto note_elem = (*note)->note_elems.begin(); note_elem != (*note)->note_elems.end(); note_elem++) {
			if ((*note_elem)->tie_pos & Tie_RightEnd || (*note_elem)->dontPlay)
				continue;
			else
				return false;
		}
	}
	return true;
}

void WriteFormatTxtWithoutXml(MidiFile* midi, const char* pFileName)
{
	FILE* pFormatTxt = fopen(pFileName, "w");
	fprintf(pFormatTxt, "%d 3/4 %d %d\n", 60*1000*1000/midi->tempos.front().tempo, midi->quarter, midi->tempos.front().tempo);
	for (auto midi_event = midi->_mergedMidiEvents.begin(); midi_event != midi->_mergedMidiEvents.end(); ++midi_event)
	{
		if (0x90 == (midi_event->evt & 0xF0) && midi_event->vv > 0)		//start note
		{
			//find this note's stop event
			auto nextEvent = midi_event;
			for (nextEvent++; nextEvent != midi->_mergedMidiEvents.end(); nextEvent++)
			{
				unsigned char nextEvt = nextEvent->evt & 0xF0;
				unsigned char nextChannel = nextEvent->evt & 0x0F;
				if ((0x80 == nextEvt || (0x90 == nextEvt && 0 == nextEvent->vv)) && nextEvent->nn == midi_event->nn && (midi_event->evt & 0x0F) == nextChannel)
					break;
			}
			if (nextEvent != midi->_mergedMidiEvents.end())
			{
				midi_event->last_tick = nextEvent->tick-midi_event->tick;
				fprintf(pFormatTxt, "%d:%d:%d: : :%d: :%d: : \n", midi_event->nn, midi_event->tick, midi_event->last_tick, midi_event->track+1, midi_event->vv);
			}
			else
			{
				printf("Writing txt without xml occurs error that event(tick:%d note:%d) doesn't have stop note", midi_event->tick, midi_event->nn);
			}
		}
	}
	fclose(pFormatTxt);
}

#define TICK_RANGE	480*2
#define TICK_RANGE_STEP_OVER_MEASURE	480*3
void MusicXMLParser::checkMidiSequence(MidiFile* midiFile, const char* pFileName, bool bVideoMidi)
{
	if (!m_pMusicScore)
		return;

	unsigned char nErrorCode = 0;
	char* abc[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
	FILE* text = fopen(pFileName, "w");
	if (ENUM_USED_FOR_CHECK == m_eUsage)
		fprintf(text, "#(index),起始tick,第几小节'第几个tick,evt,note,note,vol(力度值),持续的ticks,measure(第几小节),nn(音在小节中的编号),staff(1代表右手，2代表左手)\n");
	else		//ENUM_USED_FOR_GENTXT == m_eUsage
		fprintf(text, "%d %d/%d %d %d\n", 60*1000*1000/midiFile->tempos.front().tempo, /*midiFile->timeSignatures.front().numerator, midiFile->timeSignatures.front().denominator,*/
		m_pMusicScore->measures[0]->numerator, m_pMusicScore->measures[0]->denominator, midiFile->quarter, midiFile->tempos.front().tempo);

	std::vector<Event>& midiEvents = midiFile->_mergedMidiEvents;
	std::vector<TimeSignatureEvent>& timeSignatures = midiFile->timeSignatures;
	midiFile->maxTracks = m_pMusicScore->trackes.size();
	int ticksPerQuarter = midiFile->quarter, midi_index = 0;
	long size = sizeof(bool)*midiEvents.size();
	bool* eventFlags = static_cast<bool*>(malloc(size));
	memset(eventFlags, 0, size);

	MeasureToTick mtt;
	mtt.checkIsRepeatPlay = bVideoMidi;
	mtt.build(m_pMusicScore, ticksPerQuarter);
	std::vector<Segment> segments;
	for (int i = 0; i < mtt.segments_->count; i++)
		segments.push_back(*static_cast<Segment*>(mtt.segments_->objects[i]));

	//int numerator, denominator = numerator = 4;
	//if (!timeSignatures.empty())
	//{
	//	numerator = timeSignatures.front().numerator;
	//	denominator = timeSignatures.front().denominator;
	//}

	int meas_start_tick = 0;
	int cur_event_tick = -1, next_event_tick = -1;
	int cur_event_index = 0;
	for (auto segment = segments.begin(); segment != segments.end(); segment++)
	{
		int beginMeasure = segment->measure;
		int endMeasure = segment->measure+segment->measureCount;
		
		for (int mm = beginMeasure; mm < endMeasure && mm < m_pMusicScore->measures.size(); mm++)
		{
			std::shared_ptr<OveMeasure>& measure = m_pMusicScore->measures[mm];
			const std::vector<std::string>& sorted_duration_offset = measure->sorted_duration_offset;
			bool got_meas_start_tick = false;
			int rest_ticks = 0;

			for (int nn = 0; nn < sorted_duration_offset.size(); nn++)
			{
				int note_start_tick = 0;
				bool got_note_start_tick = false;
				const std::string& key = sorted_duration_offset[nn];

				int elem_count = 0, i_notes = 0;
				auto& notes = measure->sorted_notes[key];
				if (notes.size() > 0)
				{
					bool allRest = true;
					NoteType minRestType = Note_None;
					for (auto n = notes.begin(); n != notes.end(); n++)
					{
						if (!(*n)->isRest)
							allRest = false;
						if ((*n)->note_type > minRestType)
							minRestType = (*n)->note_type;
					}

					if (allRest && minRestType < Note_256)
					{
						/*
						Note_DoubleWhole= 0x0,
						Note_Whole		= 0x1,
						Note_Half		= 0x2,
						Note_Quarter	= 0x3,
						Note_Eight		= 0x4,
						Note_Sixteen	= 0x5,
						Note_32		= 0x6,
						Note_64		= 0x7,
						Note_128		= 0x8,
						Note_256		= 0x9,
						*/
						int bats[] = {480*8, 480*4, 480*2, 480, 480/2, 480/4, 480/8, 480/16, 480/32};
						rest_ticks = bats[minRestType];
						continue;
					}
				}
				for (auto note = notes.begin(); note != notes.end(); note++, i_notes++)
				{
					if ((*note)->note_elems.empty())
						continue;

					elem_count += (*note)->note_elems.size();
					int tick_range = (nn == 0) ? TICK_RANGE_STEP_OVER_MEASURE : TICK_RANGE;
					int upper_note = 2, below_note = 2, values_count = 0;
					char values[MAX_NOTE_ELEMS] = {0};

					std::vector<std::shared_ptr<NoteElem> > note_elems;
					std::shared_ptr<NoteElem> lastElem = (*note)->note_elems.back();
					auto art = changedArticulationOfNote(*note);
					if (art)
					{
						if (Accidental_Natural == art->accidental_mark) {
							getUpper(&upper_note, &below_note, lastElem, 0, Accidental_Normal, (*note)->staff, measure, nn-1);
						} else {
							getUpper(&upper_note, &below_note, lastElem, measure->fifths, art->accidental_mark, (*note)->staff, measure, nn-1);
						}

						std::shared_ptr<OveNote> nextNote;
						for (int n = 0; n < measure->notes.size()-1; ++n)
						{
							auto& tmpNote = measure->notes[n];
							if (tmpNote.get() == note->get())
							{
								nextNote = measure->notes[n+1];
								if (nextNote->staff != (*note)->staff)
									nextNote = nullptr;
								break;
							}
						}
						values_count = tappedNoteElems(values, *note, nextNote, art, below_note, upper_note);
						if (values_count > 8)
						{
							if (bVideoMidi)
								tick_range = 480*(0.25+values_count/8);
							else
								tick_range = 480*(values_count/8)+40;
						}

						if (bVideoMidi) {
							bool hasFermata = false;
							for (auto noteArt = (*note)->note_arts.begin(); noteArt != (*note)->note_arts.end(); ++noteArt) {
								if (Articulation_Fermata == (*noteArt)->art_type || Articulation_Fermata_Inverted == (*noteArt)->art_type) {
									hasFermata = true;
									break;
								}
							}
							if (hasFermata)
								tick_range += 80;
						}

						if (Articulation_Major_Trill == art->art_type && nn < sorted_duration_offset.size()-1)
						{
							//看颤音是否有小音符结尾。如果有超过4个小音符，就是华彩：就是打破节奏了，一小节当两小节甚至10小节弹。
							int grace_count = 0;
							for (int nextIndex = 0; nextIndex < measure->notes.size()-1; nextIndex++) {
								if (measure->notes[nextIndex].get() == note->get()) {
									for (int nextN = nextIndex+1; nextN < measure->notes.size(); nextN++) {
										auto& nextNote = measure->notes[nextN];
										if (nextNote->isGrace && nextNote->staff == (*note)->staff)
											//values_count--;
											grace_count++;
										else
											break;
									}
									break;
								}
							}
							if (grace_count < 5) {
								values_count -= grace_count;
							} else {
								values_count *= 2;
								tick_range *= 2;
								printf("many grace:%d\n", grace_count);
							}
						}

						if (values_count > 0)
						{
							int trill_start_tick = 0;
							int trill_stop_tick = 0;
							for (int ee = 0; ee < values_count; ee++)
							{
								auto event = midiEvents.begin()+midi_index;
								for (int tt = midi_index; tt < midiEvents.size(); tt++, event++)
								{
									if (eventFlags[tt])
										continue;
									unsigned char evt = event->evt & 0xF0;
									unsigned char channel = event->evt & 0x0F;
									if (0x90 == evt && event->vv > 0)		//start note
									{
										if (Articulation_Major_Trill == art->art_type && ee > 0) {
											if (event->tick >= trill_stop_tick) {
												values_count = 0;
												break;
											}
										}

										bool found = (event->nn == values[ee]);
										if (!found && ee == 0)
										{
											if (Articulation_Major_Trill == art->art_type) {
												if (event->nn == values[0]+below_note || event->nn == values[0]+upper_note)
												{
													found = true;
													for (int temp = 1; temp < values_count; temp++)
													{
														if (temp%2 == 1)
															values[temp] = lastElem->note;
														else
															values[temp] = lastElem->note+upper_note;
													}
												}
											} else if (Articulation_Inverted_Short_Mordent == art->art_type) {
												//高1度音-本位音－高1度音－本位音
												if (event->nn == values[0]+upper_note)
												{
													found = true;
													values_count = 4;
													for (int temp = 1; temp < values_count; temp++)
													{
														if (temp%2 == 1)
															values[temp] = lastElem->note;
														else
															values[temp] = lastElem->note+upper_note;
													}
												}
											}
										}
										if (found) {
											if (0 == ee && Articulation_Major_Trill == art->art_type)
											{
												trill_start_tick = event->tick;
												trill_stop_tick = trill_start_tick+480/8*(values_count+1);		//redundancy
												if (bVideoMidi)
													trill_stop_tick += 120;
												values_count *= 2;
											}

											eventFlags[tt] = true;
											if (!got_note_start_tick)
											{
												note_start_tick = event->tick;
												got_note_start_tick = true;

												if (!got_meas_start_tick)
												{
													meas_start_tick = event->tick;
													//printf("measure(%d): %d\n", measure->number, meas_start_tick);
													if (rest_ticks > 0)
														meas_start_tick -= rest_ticks;
													got_meas_start_tick = true;
												}

												if (rest_ticks > 0)
													rest_ticks = 0;
											}
											if (setEventUserdata(event, tt, midiEvents, mm, nn, i_notes, ee, lastElem, measure, *note, meas_start_tick, ee>0, bVideoMidi, midiFile))
											{
												if (event->last_tick < 10)
													nErrorCode |= 1;
												if (ENUM_USED_FOR_GENTXT == m_eUsage)
													fprintf(text, "%d:%d:%d:%d:%d:%d:%d:%d:%s:%d\n", event->nn, event->tick, event->last_tick, mm, nn,event->note_staff, lastElem->line, event->vv, event->elem_id.c_str(), event->finger);
											}
											if (ee == 0 && Articulation_Major_Trill == art->art_type)
												event->last_tick = 480/8*values_count/2;
											break;
										} else {
											if (next_event_tick >= 0 && event->tick-next_event_tick > tick_range)
											{
												printf("Error, trill Event(%d) tick:%d, should closed to %d. in %d %d note:%d\n", tt, event->tick, next_event_tick, mm, nn, lastElem->note);
												break;
											}
										}
									}
								}
							}
							note_elems.insert(note_elems.begin(), (*note)->note_elems.begin(), (*note)->note_elems.end());
							note_elems.pop_back();
						}
					} else {
						note_elems = (*note)->note_elems;
					}

					for (int ee = 0; ee < note_elems.size(); ee++)
					{
						std::shared_ptr<NoteElem>& elem = note_elems[ee];
						if (elem->tie_pos & Tie_RightEnd || elem->dontPlay) {
							if (elem->tie_pos & Tie_RightEnd) {
								if (!got_meas_start_tick && next_event_tick >= 0) {
									got_meas_start_tick = true;
									got_note_start_tick = true;
									meas_start_tick = next_event_tick;
									//printf("measure1(%d): %d\n", measure->number, meas_start_tick);
								}
							}
							continue;
						}

						int skipped_midi_event = 0;
						bool found_untracked_event = false;
						auto event = midiEvents.begin()+midi_index;
						for (int tt = midi_index; tt < midiEvents.size(); tt++, event++)
						{
							if (eventFlags[tt])
								continue;

							unsigned char evt = event->evt & 0xF0;
							unsigned char channel = event->evt & 0x0F;
							if (0x90 == evt && event->vv > 0) {		//start note
								if (event->nn == elem->note) {
									eventFlags[tt] = true;
									if (!got_note_start_tick)
									{
										note_start_tick = event->tick;
										got_note_start_tick = true;

										if (!got_meas_start_tick)
										{
											meas_start_tick = event->tick;
											if (rest_ticks > 0)
												meas_start_tick -= rest_ticks;
											got_meas_start_tick = true;
											//printf("measure2(%d): %d\n", measure->number, meas_start_tick);
										}
										if (rest_ticks > 0)
											rest_ticks = 0;
									}
									if (setEventUserdata(event, tt, midiEvents, mm, nn, i_notes, ee, elem, measure, *note, meas_start_tick, false, bVideoMidi, midiFile))
									{
										if (event->last_tick < 10)
											nErrorCode |= 1;
										if (ENUM_USED_FOR_GENTXT == m_eUsage)
											fprintf(text, "%d:%d:%d:%d:%d:%d:%d:%d:%s:%d\n", event->nn, event->tick, event->last_tick, mm, nn,event->note_staff, lastElem->line, event->vv, event->elem_id.c_str(), event->finger);
									}

									if (!found_untracked_event) {
										midi_index = tt+1;
									} else {
										Event& untracked_event = midiEvents[midi_index];
										int delta = event->tick-untracked_event.tick;
										if (delta > tick_range)
										{
											printf("Error, too ealier event(%d)(%d-%d=%d*480),should be ignored. in %d %d\n", midi_index, untracked_event.tick, event->tick, delta/480, mm, nn);
											if (tick_range == TICK_RANGE || tick_range == TICK_RANGE_STEP_OVER_MEASURE)
												midi_index++;
										}
									}

									cur_event_index = tt;
									if (cur_event_tick < event->tick)
									{
										cur_event_tick = event->tick;
										int plusTick = 0;
										for (int nextMm = mm; nextMm < m_pMusicScore->measures.size() && nextMm < endMeasure; ++nextMm) {
											auto& nextMeasure = m_pMusicScore->measures[nextMm];
											int nextNn, start_tick, stop_tick;
											if (nextMm == mm) {
												nextNn = nn+1;
												start_tick = atoi(key.c_str());
											} else {
												nextNn = 0;
												start_tick = 0;
											}
											stop_tick = start_tick;
											bool foundStopNote = false;
											for (; nextNn < nextMeasure->sorted_duration_offset.size(); ++nextNn) {
												std::string& nextKey = nextMeasure->sorted_duration_offset[nextNn];
												auto& nextNotes = nextMeasure->sorted_notes[nextKey];
												for (auto nextNote = nextNotes.begin(); nextNote != nextNotes.end(); ++nextNote) {
													if (!(*nextNote)->isRest) {
														for (auto elem = (*nextNote)->note_elems.begin(); elem != (*nextNote)->note_elems.end(); ++elem) {
															if (!((*elem)->tie_pos & Tie_RightEnd)) {
																foundStopNote = true;
																break;
															}
														}
														if (foundStopNote)
															break;
													}
												}
												if (foundStopNote) {
													stop_tick = atoi(nextKey.c_str());
													break;
												}
											}
											if (foundStopNote) {
												plusTick += stop_tick-start_tick;
												break;
											} else {
												plusTick += measure->meas_length_tick-start_tick;
											}
										}
										/*
										if (nn < sorted_duration_offset.size()-1) {
											const std::string& nextKey = sorted_duration_offset[nn+1];
											next_event_tick = cur_event_tick+atoi(nextKey.c_str())-atoi(key.c_str());
											if (nn == sorted_duration_offset.size()-2 && CheckLastNotesDontPlay(measure->sorted_notes[nextKey]))
												next_event_tick += measure->meas_length_tick-atoi(nextKey.c_str());
										} else {
											next_event_tick = cur_event_tick+measure->meas_length_tick-atoi(key.c_str());
										}
										*/
										next_event_tick = cur_event_tick+plusTick;
									}
									//if (nn < sorted_duration_offset.size()-1)
									//	next_event_tick += measure->meas_length_tick-atoi(key.c_str());
									break;
								} else if (!eventFlags[tt]) {
									if (!found_untracked_event)
									{
										midi_index = tt;
										found_untracked_event = true;
									}
									if (next_event_tick >= 0 && event->tick-next_event_tick > tick_range)
									{
										printf("Error, Event(%d) tick:%d, should closed to (%d-%d). in %d %d note:%d\n", tt, event->tick, cur_event_tick, next_event_tick, mm, nn, elem->note);
										break;
									}
									skipped_midi_event++;
									if (skipped_midi_event > 40)
									{
										//printf("Error can't find note in midi %d, %d, %d, %d, %d, %d\n", mm, nn, i_notes, ee, (*elem)->note, (*elem)->line);
										if (ENUM_USED_FOR_CHECK == m_eUsage)
										{
											nErrorCode |= 2;
											fprintf(text, " , , , , , , , ,%s,%d,%d\n", measure->xml_number.c_str(), nn, (*note)->staff);
										}
										break;
									}
								}
							}
						}
					}
				}
				//midi_index = cur_event_index;
			}
			//finished one measure
			if (midi_index < cur_event_index-10)
			{
				midi_index = cur_event_index-10;
				if (midi_index < 0)
					midi_index = 0;
			}
		}
	}

	if (ENUM_USED_FOR_CHECK == m_eUsage)
	{
		char buffer[64];
		std::string strTextCont;
		std::vector<int> xml_lost_index;
		std::vector<int> tick_less_than_ten_index;

		if (nErrorCode & 0x2)
			strTextCont += " , , , , , , , , , , \n";
		int index = 1;
		std::string last_measure = "-1";
		for (auto midi_event = midiEvents.begin(); midi_event != midiEvents.end(); midi_event++, index++) {
			if (0x90 == static_cast<int>(midi_event->evt & 0xF0) && midi_event->vv > 0) {
				if ("-1" == last_measure)
					last_measure = midi_event->measure;

				if (midi_event->xml_is_empty) {
					nErrorCode |= 4;
					midi_event->last_tick = CalculateNoteLastTick(midi_event, midiEvents);
					sprintf(buffer, "%d,%d, ,%x,%d,%d%s,%d,%d, , , \n", index, midi_event->tick, midi_event->evt, midi_event->nn, midi_event->nn/12-1, abc[midi_event->nn%12], midi_event->vv, midi_event->last_tick);
					strTextCont += buffer;
					xml_lost_index.push_back(index);
				} else {
					if (last_measure != midi_event->measure)
					{
						last_measure = midi_event->measure;
						strTextCont += " , , , , , , , , , , \n";
					}
					sprintf(buffer, "%d,%d,%s'%d,%x,%d,%d%s,%d,%d,%s,%d,%d\n",index, midi_event->tick, midi_event->measure.c_str(), midi_event->tick_offset, midi_event->evt, midi_event->nn, midi_event->nn/12-1, abc[midi_event->nn%12], midi_event->vv, midi_event->last_tick, midi_event->measure.c_str(), midi_event->note_index, midi_event->note_staff);
					strTextCont += buffer;
				}
				if (midi_event->last_tick < 10)
					tick_less_than_ten_index.push_back(index);
			}
		}
		fprintf(text, strTextCont.c_str());
		fflush(text);		//flush the stream buffer
		bool tempo_is_correct = true;
		int incorrect_tempo_ticks[2] = {0}, incorrect_tempos[2] = {0};
		if (midiFile->tempos.empty()) {
			tempo_is_correct = false;
		} else {
			if (midiFile->tempos.size() > 1)
			{
				int first_tempo = midiFile->tempos.front().tempo;
				for (auto it = midiFile->tempos.begin(); it != midiFile->tempos.end(); it++) {
					if (it->tempo != first_tempo) {
						tempo_is_correct = false;
						incorrect_tempo_ticks[0] = midiFile->tempos.front().tick;
						incorrect_tempos[0] = midiFile->tempos.front().tempo;
						incorrect_tempo_ticks[1] = it->tick;
						incorrect_tempos[1] = it->tempo;
						break;
					}
				}
			}
		}
		if (nErrorCode)
		{
			char tmpbuf[1024*8];
			sprintf(tmpbuf, "%s:", midiFile->strFileName.c_str());
			if (nErrorCode & 0x1)
			{
				char buffer[8];
				strcat(tmpbuf, "\tsome tick less than 10~");
				for (auto it = tick_less_than_ten_index.begin(); it != tick_less_than_ten_index.end(); it++)
				{
					sprintf(buffer, "%d ", *it);
					strcat(tmpbuf, buffer);
				}
			}
			if (nErrorCode & 0x2)
				strcat(tmpbuf, "\tmidi file lost some events");
			if (nErrorCode & 0x4)
			{
				char buffer[8];
				strcat(tmpbuf, "\txml file lost some parts~");
				for (auto it = xml_lost_index.begin(); it != xml_lost_index.end(); it++)
				{
					sprintf(buffer, "%d ", *it);
					strcat(tmpbuf, buffer);
				}
			}
			if (!tempo_is_correct)
			{
				strcat(tmpbuf, "\tTempoEvents is not corresponding");
				if (!midiFile->tempos.empty())
				{
					char buffer[32];
					sprintf(buffer, ": %d-%d %d-%d", incorrect_tempo_ticks[0], incorrect_tempos[0], incorrect_tempo_ticks[1], incorrect_tempos[1]);
					strcat(tmpbuf, buffer);
				}
			}
			int incorrectTempo1, incorrectTempo2 = incorrectTempo1 = incorrect_tempos[0];
			if (!tempo_is_correct)
				incorrectTempo2 = incorrect_tempos[1];
			fprintf(m_pLogFile, "%s\n***分析***\n", tmpbuf);
			AnalyseErrors(strTextCont, xml_lost_index, (tick_less_than_ten_index.size() > 0) ? true : false, (0 != (nErrorCode & 0x2)) ? true : false, tempo_is_correct, incorrectTempo1, incorrectTempo2);
		}
	}
	free(eventFlags);
	fclose(text);
}

void MusicXMLParser::ObtainSpecificItem(const char* pStart, size_t column, const char** pItem)
{
	while (column)
	{
		pStart = strchr(pStart, ',')+1;
		column--;
	}
	*pItem = pStart;
}

bool MusicXMLParser::GetMeasNoteElemsInfos(size_t meas_num, ChunkSummary& chunk_summary)
{
	if (meas_num >= m_pMusicScore->measures.size())
		return false;

	bool bGetFirstNonRest = false;
	auto measure = m_pMusicScore->measures[meas_num];
	for (int nn = 0; nn < measure->sorted_duration_offset.size(); ++nn) {
		auto notes = measure->sorted_notes[measure->sorted_duration_offset[nn]];
		if (!bGetFirstNonRest) {
			bool bAllRest = true;
			for (auto note = notes.begin(); note != notes.end(); ++note) {
				if (!(*note)->isRest) {
					bAllRest = false;
					break;
				}
			}
			if (bAllRest) {
				chunk_summary.continue_rests++;
				continue;
			} else {
				bGetFirstNonRest = true;
			}
		}

		int sts = 0;
		for (auto note = notes.begin(); note != notes.end(); ++note) {
			if (!(*note)->note_elems.empty()) {		//if the note is a rest, the note_elems array is empty
				if (changedArticulationOfNote(*note)) {
					//this is a grace note, but this note may note play
					sts = 1;
				}
				for (auto elem = (*note)->note_elems.begin(); elem != (*note)->note_elems.end(); ++elem) {
					/* if the note_elem is the right end of tie or this elem needn't play by `checkDontPlayedNotes ` routine,
				 		* the elem can't included in the statistics.
				 		*/
					if (!((*elem)->tie_pos & Tie_RightEnd || (*elem)->dontPlay)) {
						if (1 == sts)
							chunk_summary.mGrace.insert(std::pair<int, int>(nn, (*elem)->note));
						chunk_summary.note_elem_num++;
					}
				}
			}
		}
	}
	return true;
}

#define	NOTE_ITEM	4
#define	MEASURE_ITEM	8
#define	NOTEINDEX_ITEM	9
#define	ENTRY_RATIO	0.6
#define	CHUNK_SPAN	2
#define EIGENVALUE	" , , , , , , , , , , "
void MusicXMLParser::CollectChunkInfos(const char* pStart, std::vector<std::pair<std::string, ChunkSummary> >& vChunkSummary)
{
	if (!vChunkSummary.empty())
		vChunkSummary.clear();
	ChunkSummary chunk_summary;
	bool bGetChunkFirstEntry = false;
	const char* pMeasItem, *pNoteIndexItem, *pLastEntry;
	std::string strMeasNum;
	int nLastNoteIndex, nTotalEntries = 0;
	while (*pStart)
	{
		if (!strncmp(pStart, EIGENVALUE, strlen(EIGENVALUE))) {
			chunk_summary.total_entries = nTotalEntries;
			chunk_summary.pChunkEnd = pLastEntry;
			vChunkSummary.push_back(std::pair<std::string, ChunkSummary>(strMeasNum, chunk_summary));
			bGetChunkFirstEntry = false;
			chunk_summary.reset();
		} else {
			ObtainSpecificItem(pStart, NOTEINDEX_ITEM, &pNoteIndexItem);
			if (!bGetChunkFirstEntry) {
				bGetChunkFirstEntry = true;
				nTotalEntries = 1;
				chunk_summary.start_nn = nLastNoteIndex = atoi(pNoteIndexItem);
				chunk_summary.pChunkStart = pStart;
				ObtainSpecificItem(pStart, MEASURE_ITEM, &pMeasItem);
				strMeasNum = std::string(pMeasItem, strchr(pMeasItem, ',')-pMeasItem);
				size_t meas_num = 0;
				while (meas_num < m_pMusicScore->measures.size())
				{
					if (m_pMusicScore->measures[meas_num]->xml_number == strMeasNum)
						break;
					else
						meas_num++;
				}
				chunk_summary.real_meas_num = meas_num;
				if (!GetMeasNoteElemsInfos(meas_num, chunk_summary))
				{
					//it's impossible enter into this branch of the judgment statement, skip this chunk if possible
					printf("Analysis get error, the measure number %d is out of the range [0, %d]\n", meas_num, m_pMusicScore->measures.size());
					while (*pStart && strncmp(pStart, EIGENVALUE, strlen(EIGENVALUE)))
						pStart = strchr(pStart, '\n')+1;
				}
			} else {		//other entry
				nTotalEntries++;
				int nn = atoi(pNoteIndexItem);
				if (nn >= nLastNoteIndex) {
					nLastNoteIndex = nn;
				} else {	//nn less than last nn, check if this is a grace note
					const char* pNoteItem = nullptr;
					ObtainSpecificItem(pStart, NOTE_ITEM, &pNoteItem);
					int note = atoi(pNoteItem);
					auto pair = chunk_summary.mGrace.find(nn);
					if (pair == chunk_summary.mGrace.end() || !(pair->second-2 <= note && note <= pair->second+2))
						chunk_summary.bNoteSeqCorrect = false;
				}
			}
		}
		if (chunk_summary.real_meas_num < m_pMusicScore->measures.size())
		{
			pLastEntry = pStart;
			pStart = strchr(pStart, '\n')+1;
		}
	}

	for (int i = 0; i < vChunkSummary.size(); ++i) {
		if (vChunkSummary[i].second.total_entries >= vChunkSummary[i].second.note_elem_num*ENTRY_RATIO)
			vChunkSummary[i].second.bLikeMeasure = true;			//maximum like a measure
		for (int j = i-1; j >= 0; --j) {
			if (vChunkSummary[i].first == vChunkSummary[j].first) {
				if (i-j > CHUNK_SPAN)		//maximum like repeat
					vChunkSummary[i].second.repeat_num = vChunkSummary[i].second.repeat_num+1;
				else
					vChunkSummary[i].second.repeat_num = vChunkSummary[i].second.repeat_num;
			}
		}
	}
}

void MusicXMLParser::CollectEntryInfos(const char* pChunkStart, std::vector<EntrySummary>& vEntrySummary)
{
	if (!vEntrySummary.empty())
		vEntrySummary.clear();
	EntrySummary entry_summary;
	const char* pItem;
	do {
		entry_summary.pEntryStart = pChunkStart;
		entry_summary.index = atoi(pChunkStart);
		ObtainSpecificItem(pChunkStart, NOTE_ITEM, &pItem);
		entry_summary.note_value = atoi(pItem);
		ObtainSpecificItem(pChunkStart, NOTE_ITEM+1, &pItem);
		entry_summary.strNote = std::string(pItem, strchr(pItem, ',')-pItem);
		ObtainSpecificItem(pChunkStart, MEASURE_ITEM+1, &pItem);
		entry_summary.nn = atoi(pItem);
		ObtainSpecificItem(pChunkStart, MEASURE_ITEM+2, &pItem);
		entry_summary.staff = atoi(pItem);
		if (*pItem == ' ')
			entry_summary.bExistEmptyItem = true;
		vEntrySummary.push_back(entry_summary);
		pChunkStart = strchr(pChunkStart, '\n')+1;
		entry_summary.reset();
	} while (*pChunkStart && strncmp(pChunkStart, EIGENVALUE, strlen(EIGENVALUE)));
}

void MusicXMLParser::AnalyseErrors(const std::string& strTextCont, const std::vector<int>& xml_lost_index, bool bTickLessThanTen, bool bXmlLeftover, bool bTempoCorrect, int incorrectTempo1, int incorrectTempo2)
{
	int index = 1;
	const char* pStart = nullptr;
	if (!bTempoCorrect)
		fprintf(m_pLogFile, "%d、midi文件中的节拍在某处发生了变化，从%d变化到%d，请对应乐谱确认这种变化是否正常\n", index++, incorrectTempo1, incorrectTempo2);
	if (bXmlLeftover) {
		fprintf(m_pLogFile, "%d、xml文件中似乎有些多余的音，这些音在midi文件中找不到，但极有可能是不匹配的原因造成的，"
			"请打开生成的后缀为.csv的excel文件，在该文件的开头存在一系列提示：measure这一列提示在乐谱的第几小节，"
			"nn表示在这一小节的第几个音处，而staff这一列则表示是上音轨还是下音轨，根据这些信息可以在乐谱中找到对应"
			"的音符，与midi手动比对确定是哪个文件造成的错误，若错误太多则有可能需要重新制作midi。\n", index++);
		pStart = strstr(strTextCont.c_str(), EIGENVALUE);
		pStart = strchr(pStart, '\n')+1;
	} else {
		pStart = strTextCont.c_str();
	}
	if (bTickLessThanTen)
	{
		fprintf(m_pLogFile, "%d、midi文件中有些音的持续时值小于10个tick，请使用midi编辑器过滤出这些时值过小的音，并确认"
			"这些音是否正常。\n", index++);
	}

	if (!xml_lost_index.empty())
	{
		//it->first: the virtual measure number; it->second: measure summary
		std::vector<EntrySummary> vEntrySummary;
		std::vector<std::pair<std::string, ChunkSummary> > vChunkSummary;
		CollectChunkInfos(pStart, vChunkSummary);
		int ci = 0, ej = 0, elast = 0;
		for (auto lost = xml_lost_index.begin(); lost != xml_lost_index.end(); lost++) {
			for (int i = ci; i < vChunkSummary.size(); ++i) {
				if (atoi(vChunkSummary[i].second.pChunkStart) <= *lost && atoi(vChunkSummary[i].second.pChunkEnd) >= *lost) {
					ci = i;
					break;
				}
			}
			CollectEntryInfos(vChunkSummary[ci].second.pChunkStart, vEntrySummary);
			for (int i = 0; i < vEntrySummary.size(); ++i) {
				if (vEntrySummary[i].index == *lost) {
					for (int j = i-1; j >= 0; --j) {
						if (!vEntrySummary[j].bExistEmptyItem) {
							elast = j;
							break;
						}
					}
					ej = i;
					break;
				}
			}
			if (vChunkSummary[ci].second.bLikeMeasure) {
				fprintf(m_pLogFile, "%d、midi文件中第%d遍反复的第%d小节第%d个音附近的%s音未能正确匹配\n", 
					index++, vChunkSummary[ci].second.repeat_num, vChunkSummary[ci].second.real_meas_num+1,
					vEntrySummary[elast].nn+1, vEntrySummary[ej].strNote.c_str());
			} else {
				//stub
			}
		}
	}
	fprintf(m_pLogFile, "\n");
}

hyStatus MusicXMLParser::ReadMusicXML(const char* pFileName, int nFileSize, char* pMusicXMLBuffer)
{
	if (!pFileName || nFileSize <= 0 || !pMusicXMLBuffer)
		return MUSIC_ERROR_ARGS_INVALID;

	FILE* pFile = fopen(pFileName, "rb");
	if (!pFile)
		return MUSIC_ERROR_GET_FILE_CONTENT;

	int szRead = fread(pMusicXMLBuffer, 1, nFileSize, pFile);
	if (szRead != nFileSize)
		return MUSIC_ERROR_GET_FILE_CONTENT;

	fclose(pFile);
	return MUSIC_ERROR_NONE;
}

int MusicXMLParser::CheckMusicXMLEncodeUTF8(tinyxml2::XMLDocument* doc)
{
	if (!doc)
		return -1;

	const char* buf = doc->GetBuffer();
	if (!buf)
		return -2;

	const char* pos = strstr(buf, "encoding=\"");
	if (!pos) {	//The unknown encoded MusicXML will be handled as UTF-8 by default
		return 0;
	} else {
		pos += strlen("encoding=\"");
		if (0 == strncmp(pos, "UTF-8", 5))
			return 0;
		else
			return -3;
	}
}

hyStatus MusicXMLParser::BuildMusicScore(tinyxml2::XMLDocument* doc)
{
	if (!doc)
		return MUSIC_ERROR_TINYXML2_PARSE_ERROR;

	int nRetCode = CheckMusicXMLEncodeUTF8(doc);
	if (-1 == nRetCode || -2 == nRetCode)
		return MUSIC_ERROR_ARGS_INVALID;
	if (-3 == nRetCode)
		return MUSIC_ERROR_XMLENCODE;

	tinyxml2::XMLElement* pXMLRootNode = doc->FirstChildElement("score-partwise");
	if (!pXMLRootNode)
		return MUSIC_ERROR_XMLNODE_NOT_EXIST;

	tinyxml2::XMLElement* element = pXMLRootNode->FirstChildElement();
	while (element)
	{
		const char* name = element->Value();
		if (name && 0 == strcmp(name, "work")) {
			BuildWork(element);
		} else if (name && 0 == strcmp(name, "movement-title")) {
			BuildMovementTitle(element);
		} else if (name && 0 == strcmp(name, "movement-number")) {
			BuildMovementNumber(element);
		} else if (name && 0 == strcmp(name, "identification")) {
			BuildIdentification(element);
		} else if (name && 0 == strcmp(name, "defaults")) {
			BuildDefaults(element);
		} else if (name && 0 == strcmp(name, "part-list")) {
			BuildPartlist(element);
		} else if (name && 0 == strcmp(name, "part")) {
			BuildPart(element);
		} else if (name && 0 == strcmp(name, "credit")) {
			BuildCredit(element);
		}
		element = element->NextSiblingElement();
	}
	m_pMusicScore->max_measures = max_measures;

	//tracks
	for (auto it = parts->begin(); it != parts->end(); it++)
	{
		std::string part_name, instrument_name = part_name = "";
		int staves = 0;
		if (it->find("part_name") != it->end())
			part_name = (*it)["part_name"];
		if (part_name == "MusicXML Part")
			part_name = "Piano";
		if (it->find("instrument_name") != it->end())
			instrument_name = (*it)["instrument_name"];
		if (it->find("staves") != it->end())
			staves = atoi((*it)["staves"].c_str());

		for (int tt = 0; tt < staves; tt++)
		{
			std::shared_ptr<OveTrack> track = std::make_shared<OveTrack>();
			m_pMusicScore->trackes.push_back(track);
			if (0 == tt)
				track->track_name = part_name;		//TODO: some xml has wrong part-name
			else
				track->track_name = "";
			track->transpose_value = 0;
			track->voice_count = 8;
			track_voice* voice = &(track->voice);
			for (int i = 0; i < 8 && i < track->voice_count; i++)
			{
				voice->voices[i].channel = 0;
				voice->voices[i].volume = -1;
				voice->voices[i].pan = 0;
				voice->voices[i].pitch_shift = 0;
				int patch = -1;
				if (0 == i)
				{
					patch = PatchForInstrumentName(instrument_name);
					if (patch < 0)
						patch = PatchForInstrumentName(part_name);
				}
				voice->voices[i].patch = patch;
			}
		}
	}
	m_pMusicScore->max_measures = max_measures;

 	//check if need to rearrange lines/pages
#ifndef ONLY_ONE_PAGE
 	if (m_pMusicScore->pages.size() == 1) {
 		if (m_pMusicScore->lines.size() == 1) {
 			m_pMusicScore->lines.clear();
 			int line_count = (max_measures+MEASURES_EACH_LINE-1)/MEASURES_EACH_LINE;
 
 			for (int i = 0; i < line_count; i++)
 			{
				auto& temp_measure = m_pMusicScore->measures[i*MEASURES_EACH_LINE];

				std::shared_ptr<OveLine> line = std::make_shared<OveLine>();
 				m_pMusicScore->lines.push_back(line);
 				line->begin_bar = i*MEASURES_EACH_LINE;
 				if (i < line_count-1) {
 					line->bar_count = MEASURES_EACH_LINE;
 				} else {
 					line->bar_count = max_measures%MEASURES_EACH_LINE;
 					if (!line->bar_count)
 						line->bar_count = MEASURES_EACH_LINE;
 				}
 				line->fifths = temp_measure->fifths;
 				if (temp_measure->xml_staff_distance > 0)
 					line->xml_staff_distance = temp_measure->xml_staff_distance;
 				else
 					line->xml_staff_distance = static_cast<short>(LINE_height*5);
 				if (temp_measure->xml_system_distance > 0)
 					line->xml_system_distance = temp_measure->xml_system_distance;
 				else
 					line->xml_system_distance = static_cast<short>(LINE_height*10*part_staves);
 
 				//staves
 				for (int ss = 0; ss < part_staves; ss++)
 				{
					std::shared_ptr<LineStaff> lineStaff = std::make_shared<LineStaff>();
 					line->staves.push_back(lineStaff);
 					lineStaff->y_offset = (0 == ss) ? 0 : line->xml_staff_distance+LINE_height*4;
 					lineStaff->hide = false;
 					if (0 == ss)
 						lineStaff->group_staff_count = part_staves-1;
 					else
 						lineStaff->group_staff_count = 0;
 					lineStaff->clef = measure_start_clefs[ss];
 
 					if (temp_measure->clefs.size() > 0) {
 						for (auto it = temp_measure->clefs.begin(); it != temp_measure->clefs.end(); it++) {
 							if ((*it)->staff == ss+1 && (*it)->pos.tick == 0) {
 								lineStaff->clef = (*it)->clef;
 								temp_measure->clefs.erase(it);
 								break;
 							}
 						}
 					}
 				}
 			}
 		}
 
 		//pages
 		m_pMusicScore->pages.clear();
 
 		int page_begin_line = 0;
 		auto& first_line = m_pMusicScore->lines.front();
 		float staff_height = first_line->staves.size()*(default_staff_distance+default_system_distance+5*LINE_height);
 		
 		for (int i = 0; i < m_pMusicScore->lines.size(); i++) {
			auto& line = m_pMusicScore->lines[i];
 			if ((i-page_begin_line)*staff_height > m_pMusicScore->page_height || i == m_pMusicScore->lines.size()-1) {
 				std::shared_ptr<OvePage> page = std::make_shared<OvePage>();
 				m_pMusicScore->pages.push_back(page);
 				page->begin_line = page_begin_line;
 				page->line_count = i+1-page_begin_line;
 				page_begin_line = i+1;

				auto& temp_measure = m_pMusicScore->measures[line->begin_bar];
 				if (temp_measure->xml_top_system_distance > 0)
 					page->xml_top_system_distance = temp_measure->xml_top_system_distance;
 				else
 					page->xml_top_system_distance = LINE_height*10;
 			}
 		}
 	}
#endif

	//sort notes for each measure
	for (int i = 0; i < max_measures; i++)
	{
		auto& temp_measure = m_pMusicScore->measures[i];
		float unitPerBeat = temp_measure->meas_length_size/(temp_measure->meas_length_tick/480.0);

		//按照duration分组notes
		std::stringstream ss;
		std::string tmp_key;
		for (auto it = temp_measure->notes.begin(); it != temp_measure->notes.end(); it++)
		{
			ss << (*it)->pos.tick;
			ss >> tmp_key;

			if (temp_measure->sorted_notes.end() == temp_measure->sorted_notes.find(tmp_key))
				temp_measure->sorted_notes[tmp_key] = std::vector<std::shared_ptr<OveNote> >();
			temp_measure->sorted_notes[tmp_key].push_back(*it);
			ss.clear();
		}

		std::vector<int> tmp_key_array;
		for (auto it = temp_measure->sorted_notes.begin(); it != temp_measure->sorted_notes.end(); it++)
			tmp_key_array.push_back(atoi(it->first.c_str()));
		std::sort(tmp_key_array.begin(), tmp_key_array.end(), [](const int& obj1, const int& obj2)->bool{ return obj1 < obj2; });
		for (auto it = tmp_key_array.begin(); it != tmp_key_array.end(); it++)
		{
			ss.clear();
			ss << *it;
			ss >> tmp_key;
			temp_measure->sorted_duration_offset.push_back(tmp_key);
		}
		
		int delta_offset = 0;		//调整每个note的offset: clef
		float LINE_width = m_pMusicScore->page_width/102.4f;		//1024x1365
		for (int nn = 0; nn < temp_measure->sorted_duration_offset.size(); ++nn)
		{
			auto& key = temp_measure->sorted_duration_offset[nn];
			int min_xml_duration = 10000;
			auto& notes = temp_measure->sorted_notes[key];

			//sharp/flat/natural
			for (auto it_note = notes.begin(); it_note != notes.end(); it_note++) {
				for (auto it_elem = (*it_note)->note_elems.begin(); it_elem != (*it_note)->note_elems.end(); it_elem++) {
					if ((*it_elem)->accidental_type > 0 && (nn == 0 || (*it_note)->note_type > Note_Quarter)) {
						delta_offset += LINE_height*1;
						if (nn == 0 && temp_measure->left_barline == Barline_RepeatLeft) {
							delta_offset += LINE_height*1;
						} else if ((*it_note)->isGrace) {
							delta_offset += LINE_height*1;
						}
						break;
					}
				}
			}

			//grace note
			int grace_number = 0;
			for (auto it_note = notes.begin(); it_note != notes.end(); it_note++) {
				if ((*it_note)->isGrace || 0 == (*it_note)->xml_duration) {
					(*it_note)->pos.start_offset = delta_offset+unitPerBeat*(*it_note)->pos.tick/480.0;
					(*it_note)->pos.start_offset += grace_number*unitPerBeat/4;
					grace_number++;
				}
			}
			if (grace_number > 0)
				delta_offset += grace_number*unitPerBeat/3;

			for (auto it_note = notes.begin(); it_note != notes.end(); it_note++) {
				//normal note
				if (!(*it_note)->isGrace && (*it_note)->xml_duration > 0) {
					(*it_note)->pos.start_offset = delta_offset+unitPerBeat*(*it_note)->pos.tick/480.0;
					if ((*it_note)->xml_duration < min_xml_duration)
						min_xml_duration = (*it_note)->xml_duration;
				}

				//sort note_elems for each note
				if ((*it_note)->note_elems.size() > 1) {
					(*it_note)->sorted_note_elems = (*it_note)->note_elems;
					std::sort((*it_note)->sorted_note_elems.begin(), (*it_note)->sorted_note_elems.end(), [](const std::shared_ptr<NoteElem>& obj1, const std::shared_ptr<NoteElem>& obj2)->bool{ return obj1->note < obj2->note; });
				} else {
					(*it_note)->sorted_note_elems = (*it_note)->note_elems;
				}
			}

			for (auto it_note = notes.begin(); it_note != notes.end(); it_note++) {
				if ((*it_note)->note_type > Note_Sixteen || ((*it_note)->note_type > Note_Eight && !(*it_note)->inBeam)) {
					delta_offset += LINE_height*2;
					break;
				}
			}
			if (min_xml_duration < temp_measure->xml_division)
				delta_offset += 2*LINE_height*(temp_measure->xml_division-min_xml_duration)/temp_measure->xml_division;

			std::shared_ptr<OveNote>& note0 = notes.front();
			for (auto it_clef = temp_measure->clefs.begin(); it_clef != temp_measure->clefs.end(); it_clef++) {
				if ((*it_clef)->xml_note < 0) {
					if (!(*it_clef)->xml_scaned && (*it_clef)->pos.tick < note0->pos.tick) {
						(*it_clef)->xml_scaned = true;
						if (nn > 0)
						{
							auto& prev_key = temp_measure->sorted_duration_offset[nn-1];
							auto& prev_notes = temp_measure->sorted_notes[prev_key];
							auto& prev_note = prev_notes.front();
							(*it_clef)->pos.start_offset = prev_note->pos.start_offset;
							(*it_clef)->pos.tick = prev_note->pos.tick;
						}
					}
				} else if ((*it_clef)->pos.tick == note0->pos.tick && !(*it_clef)->xml_scaned) {
					(*it_clef)->xml_scaned = true;
					int increase = LINE_width*10;
#if 1
					std::shared_ptr<OveNote> xml_note;
					if ((*it_clef)->xml_note < temp_measure->notes.size()) {
						xml_note = temp_measure->notes[(*it_clef)->xml_note];
						if (0 == (*it_clef)->xml_note) {
							(*it_clef)->pos.tick = 0;
							(*it_clef)->pos.start_offset = 0;
							increase = 0;
							if (i > 0)
							{
								//check if there already have clef at the end of the previous measure
								auto& prev_measure = m_pMusicScore->measures[i-1];
								for (auto prevClef = prev_measure->clefs.begin(); prevClef != prev_measure->clefs.end(); prevClef++) {
									if ((*prevClef)->staff == (*it_clef)->staff && (*prevClef)->pos.tick == temp_measure->meas_length_tick) {
										(*it_clef)->pos.start_offset = -0.2*LINE_width;
										increase = 4*LINE_width;
										break;
									}
								}
							}
						} else {
							if ((*it_clef)->staff == xml_note->staff) {
								auto& prevNote = temp_measure->notes[(*it_clef)->xml_note-1];
								(*it_clef)->pos.tick = xml_note->pos.tick;
								if (prevNote->staff == (*it_clef)->staff) {
									(*it_clef)->pos.start_offset = prevNote->pos.start_offset;
									if (prevNote->note_type < Note_Eight || (Note_Eight == prevNote->note_type && prevNote->isDot))		//四分音符和二分音符已经有足够的空间，不需要后移了
										increase = 0;
									else if (Note_Eight == prevNote->note_type)
										increase /= 2;
								} else {
									(*it_clef)->pos.start_offset = 0;
									increase = 0;
								}
							} else {
								(*it_clef)->pos.tick = temp_measure->meas_length_tick;
								(*it_clef)->pos.start_offset = temp_measure->meas_length_size;
								increase = 0;
							}
						}
					} else {
						//xml_note = temp_measure->notes.back();
						(*it_clef)->pos.tick = temp_measure->meas_length_tick;
						(*it_clef)->pos.start_offset = temp_measure->meas_length_size;
						increase = 0;
					}
#else
					if ((*it_clef)->clef == Clef_Bass)
						(*it_clef)->pos.start_offset = note0->pos.start_offset+increase*1.2;
					else
						(*it_clef)->pos.start_offset = note0->pos.start_offset+increase;
#endif
					if (increase > 0)
					{
						//如果同staff里的clef后面还有音符，才统一后移delta_offset
						//analyze never read
						//bool found = false;
						for (auto it_note = temp_measure->notes.begin(); it_note != temp_measure->notes.end(); it_note++) {
							if ((*it_note)->staff == (*it_clef)->staff && (*it_note)->pos.tick >= (*it_clef)->pos.tick) {
								delta_offset += increase;
								//analyze never read
								//found = true;
								break;
							}
						}
					}
				}
			}
		}
		temp_measure->meas_length_size += delta_offset;
	}
	processStaves();

	//计算wedge,octaves,pedal,OveDynamic,text的pos
	for (auto it = m_pMusicScore->pages.begin(); it != m_pMusicScore->pages.end(); it++)
	{
		int line_offset_y = (*it)->xml_top_system_distance;
		auto it_line = m_pMusicScore->lines.begin()+(*it)->begin_line;

		for (int ll = (*it)->begin_line; ll < (*it)->line_count+(*it)->begin_line; ll++, it_line++)
		{
			if (ll > (*it)->begin_line)
				line_offset_y += (*it_line)->xml_system_distance;
			(*it_line)->y_offset = line_offset_y;
			if (ll < (*it)->line_count+(*it)->begin_line-1)
			{
				auto it_nextLine = it_line;
				it_nextLine++;
				line_offset_y += (*it_line)->staves.size()*LINE_height*4+(*it_nextLine)->xml_staff_distance*((*it_line)->staves.size()-1);
			}
			if ((*it_line)->begin_bar+(*it_line)->bar_count > max_measures)
				(*it_line)->bar_count = max_measures-(*it_line)->begin_bar;

			auto it_measure = m_pMusicScore->measures.begin()+(*it_line)->begin_bar;
			for (int mm = (*it_line)->begin_bar; mm < (*it_line)->begin_bar+(*it_line)->bar_count; mm++, it_measure++)
			{
				float unitPerBeat = (*it_measure)->meas_length_size/((*it_measure)->meas_length_tick/480.0);

				//caculate wedge offset_y
				for (auto it_wedge = (*it_measure)->wedges.begin(); it_wedge != (*it_measure)->wedges.end(); it_wedge++)
				{
					std::shared_ptr<OveNote> xml_start_note = nullptr;
					if ((*it_wedge)->xml_start_note < (*it_measure)->notes.size()) {
						xml_start_note = (*it_measure)->notes[(*it_wedge)->xml_start_note];
					} else {
						xml_start_note = (*it_measure)->notes.back();
					}
					(*it_wedge)->pos.tick = xml_start_note->pos.tick;
					(*it_wedge)->pos.start_offset += xml_start_note->pos.start_offset;

					std::shared_ptr<OveMeasure> stop_measure = nullptr;
					if ((*it_wedge)->offset.stop_measure > 0)
						stop_measure = m_pMusicScore->measures[(*it_measure)->number+(*it_wedge)->offset.stop_measure];
					else
						stop_measure = (*it_measure);
					std::shared_ptr<OveNote> xml_stop_note = nullptr;
					if ((*it_wedge)->xml_stop_note < stop_measure->notes.size()) {
						xml_stop_note = stop_measure->notes[(*it_wedge)->xml_stop_note];
						if (xml_stop_note->staff != (*it_wedge)->xml_staff)
						{
							if ((*it_wedge)->xml_stop_note > 0) {
								xml_stop_note = stop_measure->notes[(*it_wedge)->xml_stop_note-1];
								(*it_wedge)->offset.stop_offset += stop_measure->meas_length_size-xml_stop_note->pos.start_offset;
							} else {
								xml_stop_note = stop_measure->notes.front();
							}
						}
					} else {
						xml_stop_note = stop_measure->notes.back();
					}

					if (0 == (*it_wedge)->offset.stop_measure && (*it_wedge)->xml_stop_note == (*it_wedge)->xml_start_note) {
						if ((*it_wedge)->xml_stop_note < (*it_measure)->notes.size()-1) {
							auto& nextNote = (*it_measure)->notes[(*it_wedge)->xml_stop_note+1];
							if (nextNote->staff == xml_stop_note->staff && nextNote->voice == xml_stop_note->voice)
								(*it_wedge)->offset.stop_offset += nextNote->pos.start_offset;
							else
								(*it_wedge)->offset.stop_offset = (*it_measure)->meas_length_size;
						} else {
							(*it_wedge)->offset.stop_offset = (*it_measure)->meas_length_tick;
						}
					} else if ((*it_wedge)->offset.stop_measure > 0 || xml_stop_note->pos.start_offset > (*it_wedge)->pos.start_offset) {
						(*it_wedge)->offset.stop_offset += xml_stop_note->pos.start_offset;
						if ((*it_measure)->wedges.size() > 0)
							(*it_wedge)->offset.stop_offset -= 0.5*LINE_height;
					} else {
						(*it_wedge)->offset.stop_offset = (*it_measure)->meas_length_size;
					}

					(*it_wedge)->offset_y += ((*it_line)->xml_staff_distance+LINE_height*4)*((*it_wedge)->xml_staff-1)+4*LINE_height;
					if ((*it_wedge)->offset.stop_measure > 3)
					{
						printf("error, wedge stop_measure is too big = %d\n", (*it_wedge)->offset.stop_measure);
						(*it_wedge)->offset.stop_measure = 1;
					}
				}
				//set OctaveShift pos
				for (auto it_shift = (*it_measure)->octaves.begin(); it_shift != (*it_measure)->octaves.end(); it_shift++)
				{
					std::shared_ptr<OveNote> xml_note = nullptr;
					if ((*it_shift)->xml_note < (*it_measure)->notes.size()) {
						xml_note = (*it_measure)->notes[(*it_shift)->xml_note];
						if (xml_note->staff != (*it_shift)->staff) {
							(*it_shift)->pos.tick = (*it_measure)->meas_length_tick;
							(*it_shift)->pos.start_offset = (*it_measure)->meas_length_size;
						} else {
							(*it_shift)->pos.tick = xml_note->pos.tick;
							(*it_shift)->pos.start_offset = xml_note->pos.start_offset;
						}
					} else {
						printf("error\n");
						//xml_note = (*it_measure)->notes.back();
					}
				}
				//set pedal pos
				for (auto it_deco = (*it_measure)->decorators.begin(); it_deco != (*it_measure)->decorators.end(); it_deco++)
				{
					if (Articulation_Pedal_Up == (*it_deco)->artType || Articulation_Pedal_Down == (*it_deco)->artType)
					{
						if ((*it_deco)->xml_start_note) {
							(*it_deco)->pos.tick = (*it_deco)->xml_start_note->pos.tick+(*it_deco)->xml_start_note->xml_duration*480/(*it_measure)->xml_division;
							(*it_deco)->pos.start_offset = (*it_deco)->xml_start_note->pos.start_offset+(*it_measure)->meas_length_size*(*it_deco)->xml_start_note->xml_duration/(1.0*(*it_measure)->numerator*(*it_measure)->xml_division);
						} else {
							(*it_deco)->pos.tick = 0;
							(*it_deco)->pos.start_offset = 0;
						}
					}
				}
				//set text pos
				for (auto text = (*it_measure)->meas_texts.begin(); text != (*it_measure)->meas_texts.end(); text++)
				{
					if ((*text)->pos.tick > 0) {
						(*text)->pos.start_offset = (*text)->pos.tick*unitPerBeat/480.0;
						(*text)->offset_x = 0;
					} else if (0 == (*text)->xml_start_note) {
						(*text)->pos.tick = 0;
						//(*text)->pos.start_offset = 0;
					} else {
						std::shared_ptr<OveNote> note;
						if ((*text)->xml_start_note < (*it_measure)->notes.size()) {
							note = (*it_measure)->notes[(*text)->xml_start_note];
							(*text)->pos.start_offset = note->pos.start_offset;
						} else {
							note = (*it_measure)->notes.back();
							(*text)->pos.start_offset = (*it_measure)->meas_length_size;
						}
						if ((*text)->pos.tick < 0)
							(*text)->pos.start_offset += (*text)->pos.tick*unitPerBeat/480.0;
						(*text)->pos.tick = note->pos.tick;
					}
				}
				//set OveDynamic pos
				for (auto it_dyn = (*it_measure)->dynamics.begin(); it_dyn != (*it_measure)->dynamics.end(); it_dyn++)
				{
					if ((*it_dyn)->pos.tick > 0) {
						(*it_dyn)->pos.start_offset = (*it_dyn)->pos.tick*unitPerBeat/480.0;
					} else {
#if 1
						(*it_dyn)->pos.start_offset += (*it_dyn)->pos.tick*unitPerBeat/480.0;
#else
						std::shared_ptr<OveNote> xml_note = nullptr;
						if ((*it_dyn)->xml_note < (*it_measure)->notes.size()) {
							xml_note = (*it_measure)->notes[(*it_dyn)->xml_note];
						} else {
							xml_note = (*it_measure)->notes.back();
						}
						if ((*it_dyn)->pos.tick)
							(*it_dyn)->pos.start_offset += (*it_dyn)->pos.tick*unitPerBeat/480.0;

						if (xml_note->staff != (*it_dyn)->staff) {
							(*it_dyn)->pos.tick = 0;
						} else {
							(*it_dyn)->pos.tick = xml_note->pos.tick;
							(*it_dyn)->pos.start_offset += xml_note->pos.start_offset;
						}
#endif
					}
				}

				//set velocity for each note_elem
				for (auto it_tick = (*it_measure)->sorted_duration_offset.begin(); it_tick != (*it_measure)->sorted_duration_offset.end(); it_tick++)
				{
					int velocity = VELOCITY_LOW;
					bool usedDyn = false;
					for (auto it_dyn = (*it_measure)->dynamics.begin(); it_dyn != (*it_measure)->dynamics.end(); it_dyn++) {
						if ((*it_dyn)->dynamics_type >= Dynamics_pppp || (*it_dyn)->dynamics_type <= Dynamics_ffff) {
							if (atoi((*it_tick).c_str()) > (*it_dyn)->pos.tick-(*it_measure)->meas_length_tick*0.1 && atoi((*it_tick).c_str()) < (*it_dyn)->pos.tick+(*it_measure)->meas_length_tick*0.25) {
								velocity = VELOCITY_MID+10*((*it_dyn)->dynamics_type-Dynamics_mf);		//0-9
								usedDyn = true;
								break;
							}
						}
					}
					if (!usedDyn)
					{
						if ((*it_measure)->numerator < 4) {
							// 2/4,2/8: 强，弱
							if (atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*1.0/(*it_measure)->numerator)
								velocity = VELOCITY_HIGH;
						} else if (4 == (*it_measure)->numerator) {
							// 4/4,4/8: 强，弱, 次强,弱
							if (atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*0.25)
								velocity = VELOCITY_HIGH;
							else if (atoi((*it_tick).c_str()) >= (*it_measure)->meas_length_tick*0.5 && atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*0.75)
								velocity = VELOCITY_MID;
						} else if (3 == (*it_measure)->numerator) {
							/*
							3/4,3/8：强，弱，弱
							6/4,6/8: 强,弱,弱, 次强,弱,弱
							9/8: 强,弱,弱, 次强,弱,弱, 次强,弱,弱
							12/8: 强,弱,弱, 次强,弱,弱, 次强,弱,弱, 次强,弱,弱
							*/
							if (atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*0.33)
								velocity = VELOCITY_HIGH;
						} else if (6 == (*it_measure)->numerator) {
							if (atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*0.33)
								velocity = VELOCITY_HIGH;
							else if (atoi((*it_tick).c_str()) >= (*it_measure)->meas_length_tick*0.5 && atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*0.66)
								velocity = VELOCITY_MID;
						} else if (9 == (*it_measure)->numerator) {
							if (atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick/9.0)
								velocity = VELOCITY_HIGH;
							else if ((atoi((*it_tick).c_str()) >= (*it_measure)->meas_length_tick*0.33 && atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*4.0/9.0) || 
										(atoi((*it_tick).c_str()) >= (*it_measure)->meas_length_tick*0.66 && atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*7.0/9.0))
								velocity = VELOCITY_MID;
						} else if (12 == (*it_measure)->numerator) {
							if (atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick/12.0)
								velocity = VELOCITY_HIGH;
							else if ((atoi((*it_tick).c_str()) >= (*it_measure)->meas_length_tick*3.0/12 && atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*4.0/12) || 
										(atoi((*it_tick).c_str()) >= (*it_measure)->meas_length_tick*6.0/12 && atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*7.0/12) || 
										(atoi((*it_tick).c_str()) >= (*it_measure)->meas_length_tick*9.0/12 && atoi((*it_tick).c_str()) < (*it_measure)->meas_length_tick*10.0/12))
								velocity = VELOCITY_MID;
						}
					}
					auto notes = (*it_measure)->sorted_notes[*it_tick];
					for (auto it_note = notes.begin(); it_note != notes.end(); it_note++) {
						if (!(*it_note)->isGrace) {
							for (auto it_elem = (*it_note)->note_elems.begin(); it_elem != (*it_note)->note_elems.end(); it_elem++)
								(*it_elem)->velocity = velocity;
						}
					}
				}
			}
		}
	}
#ifdef ONLY_ONE_PAGE
	if (m_pMusicScore->lines.size() > 1)
	{
		auto& lastLine = m_pMusicScore->lines.back();
		auto& lastStaff = lastLine->staves.back();
		m_pMusicScore->page_height = lastLine->y_offset+LINE_height*5+lastStaff->y_offset+200;
		if (4 == lastLine->staves.size())
			m_pMusicScore->page_height = lastLine->y_offset+LINE_height*4*lastLine->staves.size()+lastLine->xml_staff_distance*2+lastLine->xml_system_distance+200;
	}
#endif
	processLyrics();
	processBeams();
	processTuplets();
	processSlursAfter();
	processTies();
	processFingers();
	processPedals();
	processRestPos();
	return MUSIC_ERROR_NONE;
}

int MusicXMLParser::PatchForInstrumentName(const std::string& name)
{
	static std::map<std::string, int> instrumentPatch;
	if (instrumentPatch.empty())
	{
		// Piano(钢琴)
		instrumentPatch["Piano"] = 1;
		instrumentPatch["Grand Piano"] = 1;
		instrumentPatch["Acoustic Grand Piano"] = 1;		//平台钢琴
		instrumentPatch["Bright Acoustic Piano"] = 2;		//亮音钢琴
		instrumentPatch["Electric Grand Piano"] = 3;		//电钢琴
		instrumentPatch["Honky-tonk Piano"] = 4;			//酒吧钢琴
		instrumentPatch["Electric Piano 1"] = 5;					//电钢琴1
		instrumentPatch["Electric Piano 2"] = 6;					//电钢琴2
		instrumentPatch["Harpsichord"] = 7;						//大键琴
		instrumentPatch["Clavinet"] = 8;								//电翼琴
		//Chromatic Percussion(半音阶打击乐器)
		instrumentPatch["Celesta"] = 9;				//钢片琴
		instrumentPatch["Glockenspiel"] = 10;	//钟琴 港译:铁片琴
		instrumentPatch["Musical box"] = 11;		//音乐盒
		instrumentPatch["Vibraphone"] = 12;		//颤音琴
		instrumentPatch["Marimba"] = 13;			//马林巴琴
		instrumentPatch["Xylophone"] = 14;		//木琴
		instrumentPatch["Tubular Bell"] = 15;		//管钟
		instrumentPatch["Dulcimer"] = 16;			//洋琴
		//Organ(风琴)
		instrumentPatch["Drawbar Organ"] = 17;			//音栓风琴
		instrumentPatch["Percussive Organ"] = 18;		//敲击风琴
		instrumentPatch["Rock Organ"] = 19;					//摇滚风琴
		instrumentPatch["Church organ"] = 20;				//教堂管风琴
		instrumentPatch["Reed organ"] = 21;					//簧风琴
		instrumentPatch["Accordion"] = 22;					//手风琴
		instrumentPatch["Harmonica"] = 23;					//口琴
		instrumentPatch["Tango Accordion"] = 24;		//探戈手风琴
		//Guitar(吉他)
		instrumentPatch["Guitar"] = 25;
		instrumentPatch["Acoustic Guitar(nylon)"] = 25;		//木吉他(尼龙弦)
		instrumentPatch["Acoustic Guitar(steel)"] = 26;		//木吉他(钢弦)
		instrumentPatch["Electric Guitar(jazz)"] = 27;			//电吉他(爵士)
		instrumentPatch["Electric Guitar(clean)"] = 28;			//电吉他(原音)
		instrumentPatch["Electric Guitar(muted)"] = 29;		//电吉他(闷音)
		instrumentPatch["Overdriven Guitar"] = 30;				//电吉他(破音)
		instrumentPatch["Distortion Guitar"] = 31;				//电吉他(失真)
		instrumentPatch["Guitar harmonics"] = 32;				//吉他泛音
		//Bass(贝斯)
		instrumentPatch["Bass"] = 33;
		instrumentPatch["Acoustic Bass"] = 33;				//民谣贝斯
		instrumentPatch["Electric Bass(finger)"] = 34;	//电贝斯(指奏)
		instrumentPatch["Electric Bass(pick)"] = 35;		//电贝斯(拨奏)
		instrumentPatch["Fretless Bass"] = 36;				//无格贝斯
		instrumentPatch["Slap Bass 1"] = 37;					//捶鈎贝斯 1
		instrumentPatch["Slap Bass 2"] = 38;					//捶鈎贝斯 2
		instrumentPatch["Synth Bass 1"] = 39;				//合成贝斯 1
		instrumentPatch["Synth Bass 2"] = 40;				//合成贝斯 2
		//Strings(弦乐器)
		instrumentPatch["Violin II"] = 41;
		instrumentPatch["Violin"] = 41;						//小提琴
		instrumentPatch["Viola"] = 42;							//中提琴
		instrumentPatch["Cello"] = 43;							//大提琴
		instrumentPatch["Contrabass"] = 44;				//低音大提琴
		instrumentPatch["Tremolo Strings"] = 45;		//颤弓弦乐
		instrumentPatch["Pizzicato Strings"] = 46;		//弹拨弦乐
		instrumentPatch["Orchestral Harp"] = 47;		//竖琴
		instrumentPatch["Timpani"] = 48;					//定音鼓
		//Ensemble(合奏)
		instrumentPatch["String Ensemble 1"] = 49;		//弦乐合奏 1
		instrumentPatch["String Ensemble 2"] = 50;		//弦乐合奏 2
		instrumentPatch["Synth Strings 1"] = 51;			//合成弦乐 1
		instrumentPatch["Synth Strings 2"] = 52;			//合成弦乐 2
		instrumentPatch["Voice"] = 53;
		instrumentPatch["Voice Aahs"] = 53;					//人声“啊”
		instrumentPatch["Voice Oohs"] = 54;					//人声“喔”
		instrumentPatch["Synth Voice"] = 55;					//合成人声
		instrumentPatch["Orchestra Hit"] = 56;				//交响打击乐
		//Brass(铜管乐器)
		instrumentPatch["Trumpets"] = 57;
		instrumentPatch["Trumpet"] = 57;					//小号
		instrumentPatch["Trombone"] = 58;				//长号
		instrumentPatch["Tuba"] = 59;							//大号(吐巴号、低音号)
		instrumentPatch["Muted Trumpet"] = 60;		//闷音小号
		instrumentPatch["Horn"] = 61;
		instrumentPatch["French horn"] = 61;				//法国号(圆号)
		instrumentPatch["Brass"] = 62;
		instrumentPatch["Brass Section"] = 62;			//铜管乐
		instrumentPatch["Synth Brass 1"] = 63;			//合成铜管 1
		instrumentPatch["Synth Brass 2"] = 64;			//合成铜管 2
		//Reed(簧乐器)
		instrumentPatch["Sax"] = 65;
		instrumentPatch["Soprano Sax"] = 65;				//高音萨克斯风
		instrumentPatch["Alto Sax"] = 66;						//中音萨克斯风
		instrumentPatch["Tenor Sax"] = 67;					//次中音萨克斯风
		instrumentPatch["Baritone Sax"] = 68;				//上低音萨克斯风
		instrumentPatch["Oboes"] = 69;
		instrumentPatch["Oboe"] = 69;							//双簧管
		instrumentPatch["English Horn"] = 70;				//英国管
		instrumentPatch["Bassoons"] = 71;
		instrumentPatch["Bassoon"] = 71;						//低音管(巴颂管)
		instrumentPatch["Bass Clarinet in Bb"] = 72;
		instrumentPatch["Clarinets"] = 72;
		instrumentPatch["Clarinets in Bb"] = 72;
		instrumentPatch["Clarinet"] = 72;						//单簧管(黑管、竖笛)
		//Pipe(吹管乐器)
		instrumentPatch["Piccolo"] = 73;				//短笛
		instrumentPatch["Flutes"] = 74;
		instrumentPatch["Flute"] = 74;					//长笛
		instrumentPatch["Recorder"] = 75;			//直笛
		instrumentPatch["Pan Flute"] = 76;			//排笛
		instrumentPatch["Blown Bottle"] = 77;	//瓶笛
		instrumentPatch["Shakuhachi"] = 78;		//尺八
		instrumentPatch["Whistle"] = 79;				//哨子
		instrumentPatch["Ocarina"] = 80;				//陶笛
		//Synth Lead(合成音 主旋律)
		instrumentPatch["Lead 1(square)"] = 81;			//方波
		instrumentPatch["Lead 2(sawtooth)"] = 82;		//锯齿波
		instrumentPatch["Lead 3(calliope)"] = 83;			//汽笛风琴
		instrumentPatch["Lead 4(chiff)"] = 84;				//合成吹管
		instrumentPatch["Lead 5(charang)"] = 85;			//合成电吉他
		instrumentPatch["Lead 6(voice)"] = 86;				//人声键盘
		instrumentPatch["Lead 7(fifths)"] = 87;				//五度音
		instrumentPatch["Lead 8(bass + lead)"] = 88;	//贝斯吉他合奏
		//Synth Pad(合成音和弦衬底)
		instrumentPatch["Pad 1(new age)"] = 89;		//新世纪
		instrumentPatch["Pad 2(warm)"] = 90;			//温暖
		instrumentPatch["Pad 3(polysynth)"] = 91;	//多重合音
		instrumentPatch["Choir Aahs"] = 92;
		instrumentPatch["Pad 4(choir)"] = 92;				//人声合唱
		instrumentPatch["Pad 5(bowed)"] = 93;			//玻璃
		instrumentPatch["Pad 6(metallic)"] = 94;		//金属
		instrumentPatch["Pad 7(halo)"] = 95;				//光华
		instrumentPatch["Pad 8(sweep)"] = 96;			//扫掠
		//Synth Effects(合成音效果)
		instrumentPatch["FX 1(rain)"] = 97;						//雨
		instrumentPatch["FX 2(soundtrack)"] = 98;		//电影音效
		instrumentPatch["FX 3(crystal)"] = 99;				//水晶
		instrumentPatch["FX 4(atmosphere)"] = 100;	//气氛
		instrumentPatch["FX 5(brightness)"] = 101;		//明亮
		instrumentPatch["FX 6(goblins)"] = 102;			//魅影
		instrumentPatch["FX 7(echoes)"] = 103;				//回音
		instrumentPatch["FX 8(sci-fi)"] = 104;					//科幻
		//Ethnic(民族乐器)
		instrumentPatch["Sitar"] = 105;				//西塔琴
		instrumentPatch["Banjo"] = 106;				//五弦琴(斑鸠琴)
		instrumentPatch["Shamisen"] = 107;		//三味线
		instrumentPatch["Koto"] = 108;				//十三弦琴(古筝)
		instrumentPatch["Kalimba"] = 109;			//卡林巴铁片琴
		instrumentPatch["Bagpipe"] = 110;			//苏格兰风笛
		instrumentPatch["Fiddle"] = 111;				//古提琴
		instrumentPatch["Shanai"] = 112;			//(弄蛇人)兽笛 ;发声机制类似唢呐
		//Percussive(打击乐器)
		instrumentPatch["Tinkle Bell"] = 113;					//叮当铃
		instrumentPatch["Agogo"] = 114;						//阿哥哥鼓
		instrumentPatch["Steel Drums"] = 115;				//钢鼓
		instrumentPatch["Woodblock"] = 116;				//木鱼
		instrumentPatch["Taiko Drum"] = 117;				//太鼓
		instrumentPatch["Melodic Tom"] = 118;			//定音筒鼓
		instrumentPatch["Synth Drum"] = 119;				//合成鼓
		instrumentPatch["Reverse Cymbal"] = 120;		//逆转钹声
		//Sound effects(特殊音效)
		instrumentPatch["Guitar Fret Noise"] = 121;		//吉他滑弦杂音
		instrumentPatch["Breath Noise"] = 122;				//呼吸杂音
		instrumentPatch["Seashore"] = 123;					//海岸
		instrumentPatch["Bird Tweet"] = 124;					//鸟鸣
		instrumentPatch["Telephone Ring"] = 125;		//电话铃声
		instrumentPatch["Helicopter"] = 126;					//直升机
		instrumentPatch["Applause"] = 127;					//拍手
		instrumentPatch["Gunshot"] = 128;						//枪声
	}
	int patch = 0;
	std::map<std::string, int>::iterator it = instrumentPatch.find(name);
	if (it != instrumentPatch.end())
		patch = instrumentPatch[name];
	else
		printf("unknown inst:%s\n", name.c_str());
	return patch-1;
}

void MusicXMLParser::processStaves()
{
	for (int i = 0; i < m_pMusicScore->lines.size(); ++i) {
		auto& line = m_pMusicScore->lines[i];
		while (line->staves.size() > 2) {
			bool hideStaff = true;
			for (int m = line->begin_bar; m < line->begin_bar+line->bar_count; ++m) {
				auto& measure = m_pMusicScore->measures[m];
				for (auto note = measure->notes.begin(); note != measure->notes.end(); ++note) {
					if ((*note)->staff == line->staves.size() && !(*note)->note_elems.empty()) {
						hideStaff = false;
						break;
					}
				}
			}
			if (hideStaff) {
				auto& first = line->staves.front();
				line->staves.pop_back();
				if (first->group_staff_count > line->staves.size()-1)
					first->group_staff_count = line->staves.size()-1;
			} else {
				break;
			}
		}
	}
}

void MusicXMLParser::processLyrics()
{
	auto it = m_pMusicScore->measures.begin();
	for (int i = 0; i < m_pMusicScore->max_measures; i++, it++) {
		for (auto it_note = (*it)->notes.begin(); it_note != (*it)->notes.end(); it_note++) {
			if (0 == (*it_note)->xml_lyrics.size())
				continue;

			for (auto dict = (*it_note)->xml_lyrics.begin(); dict != (*it_note)->xml_lyrics.end(); dict++)
			{
				std::shared_ptr<MeasureLyric> lyric = std::make_shared<MeasureLyric>();
				(*it)->lyrics.push_back(lyric);

				lyric->staff = (*it_note)->staff;
				lyric->voice = (*it_note)->voice;
				int number = atoi((*dict)["number"].c_str());
				lyric->verse = number-1;

				int offset_y = atoi((*dict)["offset_y"].c_str());
				int offset_x = atoi((*dict)["offset_x"].c_str());
				lyric->offset.offset_y = offset_y;
				lyric->offset.offset_x = offset_x;
				lyric->pos.tick = (*it_note)->pos.tick;
				lyric->pos.start_offset = (*it_note)->pos.start_offset;
				lyric->lyric_text = (*dict)["text"];
			}
			(*it_note)->xml_lyrics.clear();
		}
	}
}

void MusicXMLParser::processBeams()
{
	std::vector<std::shared_ptr<OveBeam> > openedBeams;
	auto measure = m_pMusicScore->measures.begin();
	for (int i = 0; i < m_pMusicScore->measures.size(); i++, measure++)
	{
		std::vector<int> beam_continue_lines;
		beam_continue_lines.reserve((*measure)->notes.size());

		int tuplet_index = 0;
		auto note = (*measure)->notes.begin();
		for (size_t nn = 0; nn < (*measure)->notes.size(); nn++, note++)
		{
			//tuplets
			bool xml_have_tuplets = false;
			if (!(*note)->xml_tuplets.empty()) {
				if ((*note)->note_type > Note_Quarter && !(*note)->isRest && (*note)->inBeam) {
					xml_have_tuplets = true;
					for (auto dict = (*note)->xml_tuplets.begin(); dict != (*note)->xml_tuplets.end(); dict++)
					{
						const std::string& show_number = (*dict)["show-number"];
						if ("none" == show_number) {
							xml_have_tuplets = false;
						} else {
							const std::string& type = (*dict)["type"];
							const std::string& number = (*dict)["number"];
							if ("stop" == type && nn > 0) {
								for (int prevN = nn-1; prevN >=0 && xml_have_tuplets; prevN--) {
									auto& prevNote = (*measure)->notes[prevN];
									if (prevNote->staff == (*note)->staff && !prevNote->xml_tuplets.empty()) {
										for (auto prevTuplet = prevNote->xml_tuplets.begin(); prevTuplet != prevNote->xml_tuplets.end(); prevTuplet++) {
											const std::string& prevType = (*prevTuplet)["type"];
											const std::string& prevNumber = (*prevTuplet)["number"];
											if (number == prevNumber && "start" == prevType)
											{
												const std::string& prev_show_number = (*prevTuplet)["show-number"];
												if ("none" == prev_show_number)
													xml_have_tuplets = false;
												break;
											}
										}
									}
								}
							}
						}
					}
					(*note)->xml_tuplets.clear();
				}
			}

			//beams
			if (0 == (*note)->xml_beams.size())
				continue;

			std::vector<int> sorted_beam_keys;
			for (auto it = (*note)->xml_beams.begin(); it != (*note)->xml_beams.end(); it++)
				sorted_beam_keys.push_back(it->first);
			std::sort(sorted_beam_keys.begin(), sorted_beam_keys.end(), [](const int& obj1, const int& obj2)->bool{ return obj1 < obj2; });

			int beam_line_offset = 7, beam_line = 0;
			if ((*note)->isGrace)
				beam_line_offset = 4;
			NoteElem* lastElem = (*note)->note_elems.back().get();
			NoteElem* firstElem = (*note)->note_elems.front().get();
			if (0 != (*note)->xml_stem_default_y) {
				beam_line = 4+(*note)->xml_stem_default_y/LINE_height*2;
			} else if ((*note)->stem_up) {
				if (firstElem->line > lastElem->line)
					beam_line = firstElem->line+beam_line_offset;
				else
					beam_line = lastElem->line+beam_line_offset;
			} else {
				if (firstElem->line < lastElem->line)
					beam_line = firstElem->line-beam_line_offset;
				else
					beam_line = lastElem->line-beam_line_offset;
			}

			//梁: dict[key:index value:begin, continue, end, forward hook, and backward hook]
			for (size_t bb = 0; bb < (*note)->xml_beams.size(); bb++)
			{
				int beam_number = sorted_beam_keys[bb];
				std::string beam_type = (*note)->xml_beams[beam_number];

				//hotfix: for some beam has "continue", but it has no "end"
				if ("continue" == beam_type)
				{
					OveNote* next_note = nullptr;
					if (nn < (*measure)->notes.size()-1)
						next_note = (*measure)->notes[nn+1].get();

					if (next_note && next_note->note_type < (*note)->note_type)
					{
						bool have_next_beam = false;
						for (auto it = next_note->xml_beams.begin(); it != next_note->xml_beams.end(); it++) {
							if (beam_number == it->first) {
								have_next_beam = true;
								break;
							}
						}
						if (!have_next_beam)
							beam_type = "end";
					}
				}
				//hotfix: for some beam has two "end"
				if ("end" == beam_type)
				{
					OveNote* next_note = nullptr;
					if (nn < (*measure)->notes.size()-1)
						next_note = (*measure)->notes[nn+1].get();

					if (next_note && next_note->note_type < (*note)->note_type)
					{
						bool have_next_beam = false;
						for (auto it = next_note->xml_beams.begin(); it != next_note->xml_beams.end(); it++) {
							if (beam_number == it->first && beam_type == it->second) {
								have_next_beam = true;
								break;
							}
						}
						if (have_next_beam)
							beam_type = "continue";
					}
				}
				//hotfix:for some beam has "end", but it has no "begin"
				if ("end" == beam_type && openedBeams.size() > 0)
				{
					bool has_begin = false;
					for (auto beam = openedBeams.begin(); beam != openedBeams.end(); beam++) {
						for (auto beam_elem = (*beam)->beam_elems.begin(); beam_elem != (*beam)->beam_elems.end(); beam_elem++) {
							if ((*beam_elem)->xml_beam_number == beam_number && (*beam)->isGrace == (*note)->isGrace) {
								has_begin = true;
								break;
							}
						}
					}
					if (!has_begin)
						beam_type = "forward hook";
				}

				if ("begin" == beam_type) {
					std::shared_ptr<OveBeam> beam;
					if (openedBeams.size() > 0)
					{
						beam = openedBeams.back();
						if ((beam->staff == (*note)->staff && beam->voice != (*note)->voice) || beam->isGrace != (*note)->isGrace)
							beam = nullptr;
					}
					if (!beam)
					{
						tuplet_index = nn;
						beam_continue_lines.clear();
						beam = std::make_shared<OveBeam>();
						(*measure)->beams.push_back(beam);
						openedBeams.push_back(beam);
						beam->drawPos_width = 0;
						beam->staff = (*note)->staff;
						beam->voice = (*note)->voice;
						beam->isGrace = (*note)->isGrace;
						beam->pos.tick = (*note)->pos.tick;
						beam->pos.start_offset = (*note)->pos.start_offset;
						beam->left_line = beam_line;
					}
					beam->beam_start_note = *note;

					std::shared_ptr<BeamElem> beam_elem = std::make_shared<BeamElem>();
					beam->beam_elems.push_back(beam_elem);
					beam_elem->xml_beam_number = beam_number;
					beam_elem->start_measure_pos = i;
					beam_elem->start_measure_offset = (*note)->pos.start_offset;
					beam_elem->level = beam_number;		//beam->beam_elems.size()
				} else if ("backward hook" == beam_type || "forward hook" == beam_type) {
					OveBeam* beam = nullptr;
					if ((*measure)->beams.size() > 0) {
						beam = (*measure)->beams.back().get();
						std::shared_ptr<BeamElem> beam_elem = std::make_shared<BeamElem>();
						beam->beam_elems.push_back(beam_elem);
						beam_elem->start_measure_pos = 0;
						beam_elem->start_measure_offset = (*note)->pos.start_offset;
						beam_elem->stop_measure_pos = 0;
						beam_elem->stop_measure_offset = (*note)->pos.start_offset;
						beam_elem->level = beam_number;		//beam->beam_elems.size();
						if ("backward hook" == beam_type)
							beam_elem->beam_type = Beam_Backward;
						else
							beam_elem->beam_type = Beam_Forward;
					} else {
						printf("error, no OpenedBeams for backward hook\n");
					}
				} else if ("continue" == beam_type) {
					beam_continue_lines.push_back(beam_line);
				} else if ("end" == beam_type) {
					for (auto beam = openedBeams.begin(); beam != openedBeams.end(); beam++)
					{
						if (((*beam)->staff == (*note)->staff && (*beam)->voice != (*note)->voice) || (*beam)->isGrace != (*note)->isGrace)
							continue;

						int not_closed_beamelem = 0;
						for (auto beam_elem = (*beam)->beam_elems.begin(); beam_elem != (*beam)->beam_elems.end(); beam_elem++) {
							if ((*beam_elem)->xml_beam_number == beam_number) {
								(*beam)->stop_staff = (*note)->staff;
								(*beam)->right_line = beam_line;
								(*beam)->beam_stop_note = *note;

								if ((*beam)->staff == (*note)->staff) {		//如果头和尾不在同一个staff，就不要调整left，right_line了
									if ((*beam)->right_line+4 < (*beam)->left_line) {
										if ((*note)->stem_up)
											(*beam)->right_line += 3;
										else
											(*beam)->left_line -= 3;
									} else if ((*beam)->left_line+4 < (*beam)->right_line) {
										if ((*note)->stem_up)
											(*beam)->left_line += 3;
										else
											(*beam)->right_line -= 3;
									}
									if (0 == beam_continue_lines.size())
									{
										if ((*beam)->left_line > (*beam)->right_line+2)
											(*beam)->right_line = (*beam)->left_line-2;
										else if ((*beam)->left_line < (*beam)->right_line-2)
											(*beam)->right_line = (*beam)->left_line+2;
									}
									//检查Beam中间的note的beam位置。（不包括两头的note）
									for (size_t bc = 0; bc < beam_continue_lines.size(); bc++)
									{
										int line_num = beam_continue_lines[bc];
										int target_line = line_num;
										int cur_line = ((*beam)->left_line+(*beam)->right_line)*(1.0*(bc+1)/(beam_continue_lines.size()+2));
										if ((*note)->stem_up) {
											if (target_line > cur_line && target_line < cur_line+10)
											{
												if ((*beam)->left_line < (*beam)->right_line) {
													if (target_line > (*beam)->right_line)
														(*beam)->right_line = target_line;
													(*beam)->left_line = (*beam)->right_line;
												} else {
													if (target_line > (*beam)->left_line)
														(*beam)->left_line = target_line;
													(*beam)->right_line = (*beam)->left_line;
												}
											}
										} else {
											if (target_line < cur_line && target_line > cur_line-10)
											{
												if ((*beam)->left_line > (*beam)->right_line) {
													if (target_line < (*beam)->right_line)
														(*beam)->right_line = target_line;
													(*beam)->left_line = (*beam)->right_line;		//target_line-line-1;
												} else {
													if (target_line < (*beam)->left_line)
														(*beam)->left_line = target_line;
													(*beam)->right_line = (*beam)->left_line;		//target_line-line;
												}
											}
										}
									}
								} else {
									if ((*beam)->beam_start_note->stem_up != (*note)->stem_up) {
										int staff_lines = 2*min_staff_distance/LINE_height;
										for (int l = 0; l < m_pMusicScore->lines.size(); ++l)
										{
											auto& line = m_pMusicScore->lines[l];
											if ((*measure)->number >= line->begin_bar && (*measure)->number < line->begin_bar+line->bar_count)
											{
												staff_lines = 2*line->xml_staff_distance/LINE_height;
												break;
											}
										}
										if ((*beam)->staff == 1 && (*beam)->stop_staff == 2) {
											if ((*beam)->right_line > staff_lines+(*beam)->right_line) {
												(*beam)->left_line -= 4;
												(*beam)->right_line += 4;
											}
										} else {
											if ((*beam)->left_line < staff_lines+(*beam)->right_line)
											{
												(*beam)->left_line += 4;
												(*beam)->right_line -= 4;
											}
										}
									}
								}
								(*beam_elem)->stop_measure_pos = i-(*beam_elem)->start_measure_pos;
								(*beam_elem)->start_measure_pos = 0;
								(*beam_elem)->stop_measure_offset = (*note)->pos.start_offset;
								(*beam_elem)->xml_beam_number = 0;
							} else {
								if ((*beam_elem)->xml_beam_number > 0)
									not_closed_beamelem++;
							}
						}
						//check if closed all beams
						if (0 == not_closed_beamelem) {
							if (xml_have_tuplets) {
								(*beam)->tupletCount = nn-tuplet_index+1;
								if ((*beam)->tupletCount <= 3) {
									(*beam)->tupletCount = 3;
								} else if ((*beam)->tupletCount == 6) {
									(*beam)->tupletCount = 6;
								} else {
									(*beam)->tupletCount = 0;
								}	
							}
							openedBeams.erase(beam);
							break;
						}
					}
				} else {
					printf("unknown beam: %s\n", beam_type.c_str());
				}
			}
			(*note)->xml_beams.clear();
		}
		//remove no end beams
		for (auto beam = (*measure)->beams.begin(); beam != (*measure)->beams.end(); beam++) {
			for (auto elem = (*beam)->beam_elems.begin(); elem != (*beam)->beam_elems.end(); elem++) {
				if ((*elem)->stop_measure_offset < (*elem)->start_measure_offset) {
					(*beam)->beam_elems.erase(elem);
					openedBeams.clear();
					break;
				}
			}
		}
	}
	if (openedBeams.size() > 0)
		printf("error, there openedBeams = %ld", openedBeams.size());
}

void MusicXMLParser::processSlursAfter()
{
	for (auto measure = m_pMusicScore->measures.begin(); measure != m_pMusicScore->measures.end(); ++measure) {
		for (auto slur = (*measure)->slurs.begin(); slur != (*measure)->slurs.end(); ++slur) {
			if ((*slur)->slur_start_note)
				(*slur)->pos.start_offset = (*slur)->slur_start_note->pos.start_offset;
			else
				(*slur)->pos.start_offset = 0;
			if ((*slur)->slur_stop_note)
				(*slur)->offset.stop_offset = (*slur)->slur_stop_note->pos.start_offset;
			else
				(*slur)->offset.stop_offset = 0;
		}
	}
}

void MusicXMLParser::processSlursPrev()
{
	std::vector<std::shared_ptr<MeasureSlur> > startedSlurs, stoppedSlurs;
	auto measure = m_pMusicScore->measures.begin();
	for (int i = 0; i < m_pMusicScore->measures.size(); i++, measure++) {
		for (auto note = (*measure)->notes.begin(); note != (*measure)->notes.end(); note++) {
			int slur_line_offset = 7;
			if ((*note)->isGrace) {
				slur_line_offset = 4;
			} else if (Note_Whole == (*note)->note_type) {
				slur_line_offset = 2;
			}
			int up_line_offset = 0, below_line_offset = 0;

			//slur 连奏: key=number, value=dict[type,placement,default-x,default-y,endnote,]
			int bb = 0;
			for (auto slur_values = (*note)->xml_slurs.begin(); slur_values != (*note)->xml_slurs.end(); slur_values++, bb++)
			{
				std::string slur_number = (*slur_values)["number"];
				std::string slur_type = (*slur_values)["type"];		//start, stop
				std::string above_string = (*slur_values)["placement"];		//above, below
				bool above = (above_string == "" && !(*note)->isGrace) || ("above" == above_string);
				int default_y = 0;
				int slur_line = (*note)->line+default_y/LINE_height;
				if (0 == default_y)
					slur_line = getSlurLine(note->get(), above);

				if ("start" == slur_type) {
					if (0 == default_y)
					{
						if (up_line_offset < 0 && bb > 1)
							above = false;
						if (above) {
							slur_line += ((*note)->stem_up) ? slur_line_offset : 2;
							slur_line += up_line_offset;
							up_line_offset -= 2;
						} else {
							slur_line -= ((*note)->stem_up) ? 2 : slur_line_offset;
							slur_line -= below_line_offset;
							below_line_offset -= 2;
						}
					}
					bool slur_started = false;
					for (auto slur = stoppedSlurs.begin(); slur != stoppedSlurs.end(); slur++) {
						if ((*slur)->xml_slur_number == atoi(slur_number.c_str())) {
							(*measure)->slurs.push_back(*slur);
							(*slur)->slur1_above = above;
							(*slur)->pair_ends.left_line = slur_line;
							(*slur)->pair_ends.right_line += ((*slur)->slur1_above) ? 2 : -2;
							(*slur)->pos.tick = (*note)->pos.tick;
							(*slur)->pos.start_offset = (*note)->pos.start_offset;
							(*slur)->offset.stop_measure = i-(*slur)->offset.stop_measure;
							(*slur)->staff = (*note)->staff;
							stoppedSlurs.erase(slur);
							slur_started = true;
							break;
						}
					}
					if (!slur_started)
					{
						std::shared_ptr<MeasureSlur> slur = std::make_shared<MeasureSlur>();
						(*measure)->slurs.push_back(slur);
						startedSlurs.push_back(slur);

						slur->slur_start_note = *note;
						slur->xml_slur_number = atoi(slur_number.c_str());
						slur->staff = (*note)->staff;
						slur->voice = (*note)->voice;
						slur->slur1_above = above;
						slur->pos.tick = (*note)->pos.tick;
						slur->pos.start_offset = (*note)->pos.start_offset;
						slur->pair_ends.left_line = slur_line;
						if ((*note)->isGrace)
							slur->pair_ends.right_line = slur_line;
						else
							slur->pair_ends.right_line = 100;
						slur->offset.stop_measure = i;
					}
				} else if ("stop" == slur_type) {
					bool slur_stopped = false;
					for (auto slur = startedSlurs.begin(); slur != startedSlurs.end(); slur++) {
						if ((*slur)->xml_slur_number == atoi(slur_number.c_str())) {
							if (100 == (*slur)->pair_ends.right_line) {
								if ((*slur)->slur_start_note->isGrace) {
									slur_line = (*slur)->pair_ends.left_line;
								} else if (0 == default_y) {
									slur_line = getSlurLine(note->get(), (*slur)->slur1_above);
									if ((*slur)->slur1_above) {
										slur_line += ((*note)->stem_up) ? slur_line_offset : 2;
										if ((*note)->stem_up && (*note)->inBeam)
											slur_line += 2;
										slur_line += up_line_offset;
										up_line_offset -= 2;
									} else {
										slur_line -= ((*note)->stem_up) ? 2 : slur_line_offset;
										if (!(*note)->stem_up && (*note)->inBeam)
											slur_line -= 2;
										slur_line -= below_line_offset;
										below_line_offset -= 2;
									}
								}
								(*slur)->pair_ends.right_line = slur_line;
							}
							
							(*slur)->slur_stop_note = *note;
							(*slur)->stop_staff = (*note)->staff;
							auto& start_measure = m_pMusicScore->measures[(*slur)->offset.stop_measure];
							if (i > (*slur)->offset.stop_measure && !(*measure)->numerics.empty() && !start_measure->numerics.empty()) {
								//slur should not over endings 连音线不能跨越房子。
								for (auto it = start_measure->slurs.begin(); it != start_measure->slurs.end(); ++it) {
									if (it->get() == slur->get()) {
										start_measure->slurs.erase(it);
										break;
									}
								}
								(*measure)->slurs.push_back(*slur);
								(*slur)->offset.stop_measure = 0;
								(*slur)->slur_start_note.reset();
								(*slur)->pos.tick = 0;
								(*slur)->pos.start_offset = 0;
							} else {
								(*slur)->offset.stop_measure = i-(*slur)->offset.stop_measure;
							}
							(*slur)->offset.stop_offset = (*note)->pos.start_offset;
							startedSlurs.erase(slur);
							slur_stopped = true;
							break;
						}
					}
					if (!slur_stopped)
					{
						std::shared_ptr<MeasureSlur> slur = std::make_shared<MeasureSlur>();
						stoppedSlurs.push_back(slur);

						slur->slur_stop_note = *note;
						slur->xml_slur_number = atoi(slur_number.c_str());
						slur->stop_staff = (*note)->staff;
						slur->voice = (*note)->voice;
						slur->pos.tick = (*note)->pos.tick;
						slur->pos.start_offset = (*note)->pos.start_offset;
						slur->pair_ends.right_line = slur_line;
						slur->offset.stop_measure = i;
						slur->offset.stop_offset = (*note)->pos.start_offset;
						printf("slur stop before start\n");
					}
				}
			}
			if (!(*note)->xml_slurs.empty())
				(*note)->xml_slurs.clear();
		}
	}

	if (startedSlurs.size() > 0)
	{
		printf("error, it should no startedSlurs=%ld\n", startedSlurs.size());
		for (auto slur = startedSlurs.begin(); slur != startedSlurs.end(); slur++)
		{
			(*slur)->pair_ends.right_line = (*slur)->pair_ends.left_line;
			(*slur)->offset.stop_measure = 0;		//i-slur.offset.stop_measure;
			(*slur)->offset.stop_offset = (*slur)->pos.start_offset;
			(*slur)->stop_staff = (*slur)->staff;
		}
	}
	if (stoppedSlurs.size() > 0)
	{
		printf("error, it should no stoppedSlurs=%ld\n", stoppedSlurs.size());
		for (auto slur = stoppedSlurs.begin(); slur != stoppedSlurs.end(); slur++)
		{
			(*slur)->pair_ends.left_line = (*slur)->pair_ends.right_line;
			(*slur)->offset.stop_measure = 0;		//i-slur.offset.stop_measure;
			(*slur)->staff = (*slur)->stop_staff;
		}
	}
}

int MusicXMLParser::getSlurLine(OveNote* note, bool above)
{
	int slur_line = note->line;
	if (note->note_elems.size() > 1)
	{
		std::shared_ptr<NoteElem> firstElem, lastElem;
		if (!note->sorted_note_elems.empty()) {
			firstElem = note->sorted_note_elems.back();
			lastElem = note->sorted_note_elems.front();
		} else {
			firstElem = note->note_elems.back();
			lastElem = note->note_elems.front();
		}

		if (firstElem->line >= lastElem->line) {
			if (above)
				slur_line = firstElem->line+0;
			else
				slur_line = lastElem->line-0;
		} else {
			if (above)
				slur_line = lastElem->line;
			else
				slur_line = firstElem->line;
		}
	}
	return slur_line;
}

void MusicXMLParser::processTies()
{
	std::vector<std::shared_ptr<MeasureTie> > openedTies;
	auto measure = m_pMusicScore->measures.begin();
	for (int i = 0; i < m_pMusicScore->max_measures; i++, measure++) {
		int nn = 0;
		for (auto note = (*measure)->notes.begin(); note != (*measure)->notes.end(); note++, nn++) {
			int ee = 0;
			for (auto elem = (*note)->note_elems.begin(); elem != (*note)->note_elems.end(); elem++, ee++) {
				//tie 连奏: key=number, value=dict[type,placement,default-x,default-y,endnote,]
				if ((*elem)->xml_ties.empty())
					continue;

				for (auto dict = (*elem)->xml_ties.begin(); dict != (*elem)->xml_ties.end(); dict++) {
					std::string number = "";
					std::string tie_type = "";		//start, stop
					std::string orientation = "";		//under, over
					if (dict->find("number") != dict->end())
						number = (*dict)["number"];
					if (dict->find("type") != dict->end())
						tie_type = (*dict)["type"];
					if (dict->find("orientation") != dict->end())
						orientation = (*dict)["orientation"];
					bool above = ("" == orientation) || ("over" == orientation);
					if ((*note)->note_elems.size() > 1)
						above = (elem != (*note)->note_elems.begin());
					if ((*note)->note_type > Note_Whole && 1 == (*note)->note_elems.size())
					{
						//check if there are more than one voice
						bool onlyOneVoice = true;
						for (auto otherNote = (*measure)->notes.begin(); otherNote != (*measure)->notes.end(); ++otherNote) {
							if ((*otherNote)->staff == (*note)->staff && (*otherNote)->voice != (*note)->voice) {
								onlyOneVoice = false;
								break;
							}
						}
						if (onlyOneVoice) {
							above = !(*note)->stem_up;
						} else {
							if (1 == (*note)->voice || 3 == (*note)->voice)
								above = true;
							else
								above = false;
						}
					}

					if ("start" == tie_type) {
						//hotfix: some music XML has only start tie, but no stop tie
						std::shared_ptr<MeasureTie> tie = std::make_shared<MeasureTie>();
						(*measure)->ties.push_back(tie);
						openedTies.push_back(tie);

						tie->above = above;
						tie->xml_tie_number = atoi(number.c_str());
						tie->xml_note_value = (*elem)->note;
						//tie->xml_start_elem = (*elem);
						//tie->xml_belongto_measure = *measure;
						tie->xml_start_measure_index = i;
						tie->xml_start_note_index = nn;
						tie->xml_start_elem_index = ee;
						tie->staff = (*note)->staff;
						tie->pos.tick = (*note)->pos.tick;
						tie->pos.start_offset = (*note)->pos.start_offset;
						tie->pair_ends.left_line = (*elem)->line;
						tie->pair_ends.right_line = tie->pair_ends.left_line;
						tie->offset.stop_measure = i;
					} else if ("stop" == tie_type) {
						if (openedTies.size() > 0) {
							bool closed = false;
							for (auto tie = openedTies.begin(); tie != openedTies.end(); tie++) {
								if ((*tie)->xml_tie_number == atoi(number.c_str()) && (*tie)->xml_note_value == (*elem)->note && (*tie)->staff == (*note)->staff) {
									(*tie)->offset.stop_measure = i-(*tie)->offset.stop_measure;
									(*tie)->offset.stop_offset = (*note)->pos.start_offset;
									(*tie)->stop_staff = (*note)->staff;
									//(*tie)->xml_start_elem->length_tick += (*elem)->length_tick;
									openedTies.erase(tie);
									closed = true;
									break;
								}
							}
							if (!closed)
								printf("error, can not find tie start for stop tie\n");
						} else {
							printf("error, there is no start tie for stop tie\n");
						}
					}
				}
				(*elem)->xml_ties.clear();
			}
		}
	}
	if (openedTies.size() > 0)
	{
		for (auto tie = openedTies.begin(); tie != openedTies.end(); tie++)
		{
			std::shared_ptr<OveMeasure> measure;
			if ((*tie)->xml_start_measure_index < m_pMusicScore->measures.size())
				measure = m_pMusicScore->measures[(*tie)->xml_start_measure_index];

			std::shared_ptr<OveNote> note;
			if ((*tie)->xml_start_note_index < measure->notes.size())
				note = measure->notes[(*tie)->xml_start_note_index];

			std::shared_ptr<NoteElem> elem;
			if ((*tie)->xml_start_elem_index < note->note_elems.size())
				elem = note->note_elems[(*tie)->xml_start_elem_index];

			bool paired = false;
			for (int i = (*tie)->xml_start_note_index+1; i < measure->notes.size() && !paired; i++)
			{
				std::shared_ptr<OveNote>& nextNote = measure->notes[i];
				if (note->staff == nextNote->staff) {
					for (auto nextElem = nextNote->note_elems.begin(); nextElem != nextNote->note_elems.end(); nextElem++) {
						if (elem->note == (*nextElem)->note) {
							(*tie)->offset.stop_measure = 0;
							(*tie)->offset.stop_offset = nextNote->pos.start_offset;
							(*tie)->stop_staff = note->staff;
							(*nextElem)->tie_pos = Tie_RightEnd;
							paired = true;
							break;
						}
					}
				}
			}
			if (!paired)
			{
				printf("error, the tie should no start at measure:%d nn:%d\n", (*tie)->xml_start_measure_index, (*tie)->xml_start_note_index);
				elem->tie_pos = Tie_None;
				for (auto it = measure->ties.begin(); it != measure->ties.end(); it++) {
					if (it->get() == tie->get()) {
						measure->ties.erase(it);
						break;
					}
				}
			}
		}
	}
}

void MusicXMLParser::processFingers()
{
	//check fingers for chord note
	for (int i = 0; i < m_pMusicScore->max_measures; i++)
	{
		std::shared_ptr<OveMeasure>& measure = m_pMusicScore->measures[i];
		for (auto it = measure->sorted_notes.begin(); it != measure->sorted_notes.end(); it++) {
			for (auto note = it->second.begin(); note != it->second.end(); note++) {
				if ((*note)->note_elems.size() > 0 && (*note)->xml_fingers.size() > 0) {
					std::shared_ptr<NoteArticulation>& art = (*note)->xml_fingers.front();
					std::shared_ptr<NoteArticulation>& lastArt = (*note)->xml_fingers.back();
					int above = art->art_placement_above;
					ArticulationPos finger_pos = (above != 0) ? ArtPos_Above : ArtPos_Down;

					if ((*note)->note_elems.size() == (*note)->xml_fingers.size() && (*note)->xml_fingers.size() > 1) {
						auto& firstElem = (*note)->note_elems.front();
						auto& secondElem = (*note)->note_elems[1];
						if (secondElem->line-firstElem->line > 1 && (*note)->pos.tick == 0)
						{
							if (art->offset.offset_x <= -9 && lastArt->offset.offset_x <= -9) {
								finger_pos = ArtPos_Left;
							} else if (art->offset.offset_x > 15 && lastArt->offset.offset_x > 15) {
								finger_pos = ArtPos_Right;
							}
						}
					}
					/*
					if ((*note)->note_type > Note_Whole && (*note)->note_elems.size() == (*note)->xml_fingers.size() && 
									(((*note)->voice == 1 && (*note)->staff == 1 && !(*note)->stem_up) || ((*note)->voice == 2 && (*note)->staff == 2 && !(*note)->stem_up))) {
						finger_pos = ArtPos_Above;
					} else if (lastArt->offset.offset_y < 0 && !(*note)->stem_up) {
						finger_pos = ArtPos_Down;
					}
					*/
					if (ArtPos_Left != finger_pos && ArtPos_Right != finger_pos && (*note)->note_elems.size() == (*note)->xml_fingers.size())
					{
						//if (!above && art->offset.offset_y < -15 && lastArt->offset.offset_y < -15) {
						//	finger_pos = ArtPos_Above;
						//} else if (above && art->offset.offset_y < -15 && lastArt->offset.offset_y < -15) {
						//	finger_pos = ArtPos_Down;
						//}
					}
					above = (finger_pos > ArtPos_Down) ? 1 : 0;

					if ((*note)->xml_fingers.size() > 1 && (*note)->note_elems.size() > 1)
					{
						std::sort((*note)->xml_fingers.begin(), (*note)->xml_fingers.end(), [above](const std::shared_ptr<NoteArticulation>& obj1, const std::shared_ptr<NoteArticulation>& obj2)->bool{
							if (obj1->art_placement_above > obj2->art_placement_above || obj1->art_placement_above < obj2->art_placement_above)
							{
								if (above > 0) {
									if (obj1->art_placement_above > 0 && obj2->art_placement_above < 1) {
										return false;
									} else {
										return true;
									}
								} else {
									if (obj1->art_placement_above > 0 && obj2->art_placement_above < 1) {
										return true;
									} else {
										return false;
									}
								}
							}
							if (above > 0) {
								if (obj1->offset.offset_y > obj2->offset.offset_y) {
									return false;
								} else {
									return true;
								}
							} else {
								if (obj1->offset.offset_y > obj2->offset.offset_y) {
									return true;
								} else {
									return false;
								}
							}
						});
					}
					if ((*note)->xml_fingers.size() > 1 && (*note)->note_elems.size() == 1) {
						bool twoVoice = false;
						if (!twoVoice)
						{
							std::shared_ptr<NoteArticulation>& firstArt = (*note)->xml_fingers.front();
							std::shared_ptr<NoteArticulation>& lastArt = (*note)->xml_fingers.back();
							if (firstArt->offset.offset_y > lastArt->offset.offset_y-3 && firstArt->offset.offset_y < lastArt->offset.offset_y+3) {
								bool haveTrill = false;
								for (auto a = (*note)->note_arts.begin(); a != (*note)->note_arts.end(); a++) {
									if (Articulation_Major_Trill == (*a)->art_type || Articulation_Minor_Trill == (*a)->art_type) {
										haveTrill = true;
									}
								}
								if (2 == (*note)->xml_fingers.size()) {
									const char* seg = nullptr;
									if (haveTrill)		//颤音指法
										seg = " ";
									else
										seg = "-";		//同音换指

									char buffer[64];
									if (firstArt->offset.offset_x < lastArt->offset.offset_x) {
										sprintf(buffer, "%s%s%s", firstArt->finger.c_str(), seg, lastArt->finger.c_str());
										firstArt->finger = buffer;
									} else {
										sprintf(buffer, "%s%s%s", lastArt->finger.c_str(), seg, firstArt->finger.c_str());
										firstArt->finger = buffer;
									}
									(*note)->xml_fingers.pop_back();
								} else {
									std::string str = "";
									if (firstArt->offset.offset_x < lastArt->offset.offset_x) {
										for (auto art = (*note)->xml_fingers.begin(); art != (*note)->xml_fingers.end(); art++)
											str = str+" "+(*art)->finger;
									} else {
										for (auto art = (*note)->xml_fingers.begin(); art != (*note)->xml_fingers.end(); art++)
											str = (*art)->finger+" "+str;
									}
									firstArt->finger = str;
									for (int i = 0; i < (*note)->xml_fingers.size()-1; i++)
										(*note)->xml_fingers.pop_back();
								}

								firstArt->offset.offset_y = 0;		//LINE_height*1.5;
								firstArt->offset.offset_x = -LINE_height;
								(*note)->note_arts.push_back(firstArt);
							} else {
								//可选择指法
								if (above) {
									firstArt->alterFinger = lastArt->finger;
									firstArt->finger = firstArt->finger;
								} else {
									firstArt->alterFinger = lastArt->finger;
									firstArt->finger = firstArt->finger;
								}
								firstArt->offset.offset_y = 0;
								firstArt->offset.offset_x = 0;
								(*note)->xml_fingers.pop_back();
								(*note)->note_arts.push_back(firstArt);
							}
						}
					} else {
						(*note)->note_arts.insert((*note)->note_arts.end(), (*note)->xml_fingers.begin(), (*note)->xml_fingers.end());
						int left_offset_x = 0;
						if (ArtPos_Left == finger_pos) {
							for (auto elem = (*note)->note_elems.begin(); elem != (*note)->note_elems.end(); elem++) {
								if (Accidental_Normal != (*elem)->accidental_type) {
									left_offset_x = -LINE_height;
									break;
								}
							}
						}
						for (int f = 0; f < (*note)->xml_fingers.size(); f++)
						{
							std::shared_ptr<NoteArticulation>& art = (*note)->xml_fingers[f];
							art->art_placement_above = above;
							art->offset.offset_y = 0;
							art->offset.offset_x = 0;
							if ((*note)->xml_fingers.size() == (*note)->note_elems.size() && finger_pos > ArtPos_Above)
							{
								//std::shared_ptr<NoteElem>& bottom_elem = (*note)->note_elems.front();
								//std::shared_ptr<NoteElem>& elem = (*note)->note_elems[(*note)->note_elems.size()-f-1];
								auto& top_elem = (*note)->note_elems.back();
								auto& elem = (*note)->note_elems[f];
								if (ArtPos_Left == finger_pos) {
									art->offset.offset_x = -2.0*LINE_height+left_offset_x;
									//art->offset.offset_y = -0.55*(elem->line-bottom_elem->line+1)*LINE_height;
									art->offset.offset_y = -0.55*(top_elem->line-elem->line+1)*LINE_height;
								} else if (ArtPos_Right == finger_pos) {
									art->offset.offset_x = 2.5*LINE_height;
									//art->offset.offset_y = -0.55*(elem->line-bottom_elem->line+1)*LINE_height;
									art->offset.offset_y = -0.55*(top_elem->line-elem->line+1)*LINE_height;
								}
							}
							if (!(*note)->inBeam && (*note)->note_type > Note_Whole)
								if (!(*note)->stem_up && !above)
									art->offset.offset_x = 3;
						}
					}
					if ((*note)->note_elems.size() <= (*note)->xml_fingers.size()) {
						for (int f = 0; f < (*note)->note_elems.size(); f++) {
							if (f < (*note)->xml_fingers.size()) {
								std::shared_ptr<NoteElem> elem;
								if (above)
									elem = (*note)->note_elems[f];
								else
									elem = (*note)->note_elems[(*note)->note_elems.size()-f-1];
								std::shared_ptr<NoteArticulation>& art = (*note)->xml_fingers[f];
								elem->xml_finger = art->finger;
							}
						}
						if ((*note)->xml_fingers.size() == 2*(*note)->note_elems.size())
						{
							//可选择指法,在中间插一个延音记号
							int finger_count = 0, f = 0;
							for (auto it = (*note)->note_arts.begin(); it != (*note)->note_arts.end(); ++it, ++f)
							{
								auto& art = (*note)->note_arts[f];
								if (Articulation_Finger == art->art_type)
								{
									finger_count++;
									if (finger_count == (*note)->note_elems.size())
									{
										auto new_art = std::make_shared<NoteArticulation>();
										new_art->art_type = Articulation_Tenuto;
										new_art->art_placement_above = art->art_placement_above;
										(*note)->note_arts.insert(++it, new_art);
										break;
									}
								}
							}
						}
					} else if ((*note)->note_elems.size() > (*note)->xml_fingers.size() && (*note)->xml_fingers.size() > 1) {		//暂时不要在虚拟键盘上显示指法少于和弦个数的指法。
						for (int f = 0; f < (*note)->note_elems.size(); f++) {
							if (f < (*note)->xml_fingers.size()) {
								std::shared_ptr<NoteElem> elem;
								if (above)
									elem = (*note)->note_elems[(*note)->note_elems.size()-f-1];
								else
									elem = (*note)->note_elems[f];
								std::shared_ptr<NoteArticulation>& art = (*note)->xml_fingers[(*note)->xml_fingers.size()-f-1];
								elem->xml_finger = art->finger;
							}
						}
					}
				}
			}
		}		//for sorted_notes
		measure->checkDontPlayedNotes();
	}
}

void MusicXMLParser::processTuplets()
{
	for (int i = 0; i < m_pMusicScore->max_measures; ++i) {
		auto& measure = m_pMusicScore->measures[i];
		for (int nn = 0; nn < measure->notes.size(); ++nn) {
			auto& note = measure->notes[nn];
			if (!note->inBeam && !note->xml_tuplets.empty()) {
				for (auto dict = note->xml_tuplets.begin(); dict != note->xml_tuplets.end(); ++dict) {
					std::string& type = (*dict)["type"];		//start, stop
					bool needBracket = ((*dict)["bracket"] == "1") ? true : false;
					if (!needBracket && type == "start")
						continue;

					std::string& number = (*dict)["number"];
					int xml_slur_number = atoi(number.c_str());
					if ("start" == type) {
						std::shared_ptr<OveTuplet> tuplet = std::make_shared<OveTuplet>();
						measure->tuplets.push_back(tuplet);
						tuplet->staff = note->staff;
						tuplet->stop_staff = note->staff;
						tuplet->pos.start_offset = note->pos.start_offset;
						tuplet->pos.tick = note->pos.tick;
						tuplet->pair_ends.left_line = note->line+4;
						if (note->stem_up)
							tuplet->pair_ends.left_line += 6;
						tuplet->xml_slur_number = xml_slur_number;
						tuplet->xml_start_note_index = nn;
					} else {		//stop
						for (int prev = measure->tuplets.size()-1; prev >= 0; --prev) {
							auto& prevTuplet = measure->tuplets[prev];
							if (prevTuplet->xml_slur_number == xml_slur_number && !prevTuplet->offset.stop_measure && !prevTuplet->offset.stop_offset) {
								prevTuplet->offset.stop_measure = 0;
								prevTuplet->offset.stop_offset = note->pos.start_offset;
								prevTuplet->pair_ends.right_line = note->line+4;
								if (note->stem_up)
								{
									prevTuplet->pair_ends.right_line += 6;
									prevTuplet->offset.stop_offset += LINE_height;
								}
								prevTuplet->tuplet = 3;
								break;
							}
						}
					}
				}
			}
		}
	}
}

void MusicXMLParser::processPedals()
{
	for (int i = 0; i < m_pMusicScore->max_measures; i++) {
		auto& measure = m_pMusicScore->measures[i];
		for (auto pedal = measure->pedals.begin(); pedal != measure->pedals.end(); pedal++) {
			//start
			if ((*pedal)->xml_start_note_index < measure->notes.size()) {
				auto& start_note = measure->notes[(*pedal)->xml_start_note_index];
				(*pedal)->pos.start_offset = start_note->pos.start_offset;
			} else {
				auto& start_note = measure->notes.back();
				(*pedal)->pos.start_offset = start_note->pos.start_offset;
			}

			//stop
			auto& stop_measure = m_pMusicScore->measures[(*pedal)->xml_stop_measure_index];
			if ((*pedal)->xml_stop_note_index >= stop_measure->notes.size()-1) {
				if ((*pedal)->xml_start_note_index == (*pedal)->xml_stop_note_index && (*pedal)->xml_start_measure_index == (*pedal)->xml_stop_measure_index) {
					(*pedal)->offset.stop_offset = measure->meas_length_size;
				} else {
					auto& stop_note = stop_measure->notes.back();
					(*pedal)->offset.stop_offset = stop_note->pos.start_offset;
				}
			} else {
				auto& stop_note = stop_measure->notes[(*pedal)->xml_stop_note_index];
				(*pedal)->offset.stop_offset = stop_note->pos.start_offset;
			}
		}
	}
}

void MusicXMLParser::processRestPos()
{
	for (int i = 0; i < m_pMusicScore->max_measures; i++) {
		auto& measure = m_pMusicScore->measures[i];
		for (auto it = measure->sorted_notes.begin(); it != measure->sorted_notes.end(); it++) {
			for (auto note = it->second.begin(); note != it->second.end(); note++) {
				if ((*note)->isRest && !(*note)->line) {
					std::shared_ptr<OveNote> nextVoiceNote = nullptr;
					for (auto otherNote = measure->notes.begin(); otherNote != measure->notes.end(); otherNote++) {
						if ((*otherNote)->staff == (*note)->staff && (*otherNote)->voice != (*note)->voice) {
							if ((*otherNote)->isRest && (*otherNote)->note_type == (*note)->note_type) {
								//don't shift same rest;
							} else {
								nextVoiceNote = *otherNote;
								break;
							}
						}
					}
					if (nextVoiceNote)
					{
						if ((*note)->voice < nextVoiceNote->voice) {
							int topline = nextVoiceNote->line;
							if (nextVoiceNote->note_elems.size() > 1)
								topline = nextVoiceNote->note_elems.back()->line;
							if ((*note)->line < topline+4 && topline > -3)
								(*note)->line = topline+4;
						} else {
							int bottomline = nextVoiceNote->line;
							if (nextVoiceNote->note_elems.size() > 1)
								bottomline = nextVoiceNote->note_elems.front()->line;
							if ((*note)->line > bottomline-4 && bottomline < 3)
								(*note)->line = bottomline-4;
						}
					}
				}
			}
		}
	}
}

void MusicXMLParser::BuildWork(tinyxml2::XMLElement* element)
{
	if (!element)
		return;

	tinyxml2::XMLElement* sub_element = element->FirstChildElement();
	while (sub_element)
	{
		const char* name = sub_element->Value();
		const char* text = NULL;
		if (name && 0 == strcmp(name, "work-number")) {
			text = sub_element->GetText();
			if (text)
				m_pMusicScore->work_number = text;
			else
				m_pMusicScore->work_number = "";
		} else if (name && 0 == strcmp(name, "work-title")) {
			text = sub_element->GetText();
			if (text)
				m_pMusicScore->work_title = text;
			else
				m_pMusicScore->work_title = "";
		}
		sub_element = sub_element->NextSiblingElement();
	}
}

void MusicXMLParser::BuildMovementTitle(tinyxml2::XMLElement* element)
{
	if (!element)
		return;

	const char* text = element->GetText();
	if (text)
		m_pMusicScore->work_title = text;
	else
		m_pMusicScore->work_title = "";
}

void MusicXMLParser::BuildMovementNumber(tinyxml2::XMLElement* element)
{
	if (!element)
		return;

	const char* text = element->GetText();
	if (text)
		m_pMusicScore->movement_number = text;
	else
		m_pMusicScore->movement_number = "";
}

void MusicXMLParser::BuildIdentification(tinyxml2::XMLElement* element)
{
	if (!element)
		return;

	tinyxml2::XMLElement* sub_element = element->FirstChildElement();
	while (sub_element)
	{
		const char* name = sub_element->Value();
		const char* text = nullptr;
		if (name && 0 == strcmp(name, "rights")) {
			text = sub_element->GetText();
			if (text)
				m_pMusicScore->rights = text;
			else
				m_pMusicScore->rights = "";
		} else if (name && 0 == strcmp(name, "creator")) {
			const char* creator_type = sub_element->Attribute("type");
			if (creator_type && 0 == strcmp(creator_type, "composer")) {
				text = sub_element->GetText();
				if (text)
					m_pMusicScore->composer	 = text;
				else
					m_pMusicScore->composer = "";
			} else if (creator_type && 0 == strcmp(creator_type, "lyricist")) {
				text = sub_element->GetText();
				if (text)
					m_pMusicScore->lyricist = text;
				else
					m_pMusicScore->lyricist = "";
			}
		} else if (name && 0 == strcmp(name, "source")) {
			text = sub_element->GetText();
			if (text)
				m_pMusicScore->source = text;
			else
				m_pMusicScore->source = "";
		} else if (name && 0 == strcmp(name, "encoding")) {
			tinyxml2::XMLElement* grandson_element = sub_element->FirstChildElement();
			while (grandson_element)
			{
				const char* grandson_name = grandson_element->Value();
				if (grandson_name && 0 == strcmp(grandson_name, "software")) {
					text = grandson_element->GetText();
					if (text)
						m_pMusicScore->software = text;
					else
						m_pMusicScore->software = "";
				} else if (grandson_name && 0 == strcmp(grandson_name, "encoding-date")) {
					text = grandson_element->GetText();
					if (text)
						m_pMusicScore->encoding_date = text;
					else
						m_pMusicScore->encoding_date = "";
				}
				grandson_element = grandson_element->NextSiblingElement();
			}
		} else if (name && 0 == strcmp(name, "miscellaneous")) {
			//ignore
		}
		sub_element = sub_element->NextSiblingElement();
	}
}

void MusicXMLParser::BuildDefaults(tinyxml2::XMLElement* element)
{
	if (!element)
		return;

	tinyxml2::XMLElement* sub_element = element->FirstChildElement();
	while (sub_element)
	{
		const char* name = sub_element->Value();
		if (name && 0 == strcmp(name, "scaling")) {
			BuildDefaultsScaling(sub_element);
		} else if (name && 0 == strcmp(name, "page-layout")) {
			BuildDefaultsPageLayout(sub_element);
		} else if (name && 0 == strcmp(name, "system-layout")) {
			BuildDefaultsSystemLayout(sub_element);
		} else if (name && 0 == strcmp(name, "staff-layout")) {
			BuildDefaultsStaffLayout(sub_element);
		} else if (name && 0 == strcmp(name, "music-font")) {
			BuildDefaultsMusicFont(sub_element);
		} else if (name && 0 == strcmp(name, "word-font")) {
			BuildDefaultsWordFont(sub_element);
		} else if (name && 0 == strcmp(name, "lyric-font")) {
			BuildDefaultsLyricFont(sub_element);
		} else if (name && 0 == strcmp(name, "appearance")) {
			BuildDefaultsAppearance(sub_element);
		} else if (name && 0 == strcmp(name, "lyric-language")) {
			BuildDefaultsLyricLanguage(sub_element);
		}
		sub_element = sub_element->NextSiblingElement();
	}
}

void MusicXMLParser::BuildDefaultsPageLayout(tinyxml2::XMLElement* sub_element)
{
	if (!sub_element)
		return;

	double var = 0;
	tinyxml2::XMLElement* grandson_element = sub_element->FirstChildElement();
	while (grandson_element)
	{
		const char* name = grandson_element->Value();
		if (name && 0 == strcmp(name, "page-height")) {
			if (tinyxml2::XML_SUCCESS == grandson_element->QueryDoubleText(&var))
			{
				m_pMusicScore->page_height = var;
				m_pMusicScore->xml_page_height = var;
			}
		} else if (name && 0 == strcmp(name, "page-width")) {
			if (tinyxml2::XML_SUCCESS == grandson_element->QueryDoubleText(&var))
				m_pMusicScore->page_width = var;
		} else if (name && 0 == strcmp(name, "page-margins")) {
			tinyxml2::XMLElement* great_grandson_element = grandson_element->FirstChildElement();
			while (great_grandson_element)
			{
				name = great_grandson_element->Value();
				if (name && 0 == strcmp(name, "left-margin")) {
					if (tinyxml2::XML_SUCCESS == great_grandson_element->QueryDoubleText(&var))
						m_pMusicScore->page_left_margin = var;
				} else if (name && 0 == strcmp(name, "right-margin")) {
					if (tinyxml2::XML_SUCCESS == great_grandson_element->QueryDoubleText(&var))
						m_pMusicScore->page_right_margin = var;
				} else if (name && 0 == strcmp(name, "top-margin")) {
					if (tinyxml2::XML_SUCCESS == great_grandson_element->QueryDoubleText(&var))
						m_pMusicScore->page_top_margin = var;
				} else if (name && 0 == strcmp(name, "bottom-margin")) {
					if (tinyxml2::XML_SUCCESS == great_grandson_element->QueryDoubleText(&var))
						m_pMusicScore->page_bottom_margin = var;
				}
				great_grandson_element = great_grandson_element->NextSiblingElement();
			}
		}
		grandson_element = grandson_element->NextSiblingElement();
	}

	default_top_system_distance = m_pMusicScore->page_height*0.02;
	default_staff_distance = m_pMusicScore->page_height*0.03;
	default_system_distance = m_pMusicScore->page_height*0.04;
}

void MusicXMLParser::BuildDefaultsSystemLayout(tinyxml2::XMLElement* sub_element)
{
	if (!sub_element)
		return;

	double var = 0;
	tinyxml2::XMLElement* grandson_element = sub_element->FirstChildElement("system-distance");
	if (grandson_element && tinyxml2::XML_SUCCESS == grandson_element->QueryDoubleText(&var))
		default_system_distance = var;

	grandson_element = sub_element->FirstChildElement("top-system-distance");
	if (grandson_element && tinyxml2::XML_SUCCESS == grandson_element->QueryDoubleText(&var))
		default_top_system_distance = var;

	if (default_system_distance < min_system_distance)
		default_system_distance = min_system_distance;
	else if (default_system_distance > max_system_distance)
		default_system_distance = max_system_distance;
}

void MusicXMLParser::BuildDefaultsStaffLayout(tinyxml2::XMLElement* sub_element)
{
	if (!sub_element)
		return;

	double var = 0;
	tinyxml2::XMLElement* grandson_element = sub_element->FirstChildElement("staff-distance");
	if (grandson_element && tinyxml2::XML_SUCCESS == grandson_element->QueryDoubleText(&var))
	{
		default_staff_distance = var;
		if (default_staff_distance < min_staff_distance) {
#ifdef	ADAPT_CUSTOMIZED_SCREEN
			default_staff_distance = 7*LINE_height;
#else
			default_staff_distance = min_staff_distance;
#endif
		} else if (default_staff_distance > max_staff_distance) {
			default_staff_distance = max_staff_distance;
		}
	}
}

void MusicXMLParser::BuildCredit(tinyxml2::XMLElement* element)
{
	/*
	<credit page="1">
	<credit-type>title</credit-type>
	<credit-words default-x="64" default-y="1440" font-family="????_GBK" font-size="24.2" halign="left" justify="center" valign="top" xml:lang="zh" xml:space="preserve">小  步  舞  曲
	</credit-words>
	</credit>
	*/
	tinyxml2::XMLElement* credit_type_element = element->FirstChildElement("credit-type");
	if (credit_type_element)
	{
		const char* text = credit_type_element->GetText();
		if (text && 0 == strcmp(text, "title")) {
			tinyxml2::XMLElement* credit_words_element = element->FirstChildElement("credit-words");
			if (credit_words_element)
			{
				const char* words = credit_words_element->GetText();
				if (m_pMusicScore->work_title.empty() && strlen(words) > 1)
					m_pMusicScore->work_title = words;
			}
		} else if (text && 0 == strcmp(text, "subtitle")) {
			tinyxml2::XMLElement* credit_words_element = element->FirstChildElement("credit-words");
			if (credit_words_element)
			{
				const char* words = credit_words_element->GetText();
				if (strlen(words) > 1)
					m_pMusicScore->work_number = words;
			}
		}
	}
}

void MusicXMLParser::BuildPartlist(tinyxml2::XMLElement* element)
{
	if (!element)
		return;

	std::vector<std::string> part_id_list;
	tinyxml2::XMLElement* sub_element = element->FirstChildElement();
	while (sub_element)
	{
		const char* name = sub_element->Value();
		if (name && 0 == strcmp(name, "score-part")) {
			const char* part_id = nullptr, *part_name = nullptr, *instrument_name = nullptr;
			part_id = sub_element->Attribute("id");
			if (part_id)
				part_id_list.push_back(part_id);

			tinyxml2::XMLElement* temp_element = sub_element->FirstChildElement("part-name");
			if (temp_element)
				part_name = temp_element->GetText();

			std::map<std::string, std::string> dict;
			if (part_name)
				dict["part_name"] = part_name;
			else
				dict["part_name"] = "";
			if (part_id)
				dict["part_id"] = part_id;
			else
				dict["part_id"] = "";

			tinyxml2::XMLElement* score_instrument_elem = sub_element->FirstChildElement("score-instrument");
			if (score_instrument_elem)
			{
				temp_element = score_instrument_elem->FirstChildElement("instrument-name");
				if (temp_element)
				{
					instrument_name = temp_element->GetText();
					if (instrument_name)
						dict["instrument_name"] = instrument_name;
				}
			}
			parts->push_back(dict);
		} else if ("part-group" == name) {
			//ignore
		}
		sub_element = sub_element->NextSiblingElement();
	}
}

void MusicXMLParser::BuildPart(tinyxml2::XMLElement* element)
{
	if (!element)
		return;

	const char* part_id = element->Attribute("id");
	std::map<std::string, std::string>* temp_part = NULL;
	for (auto it = parts->begin(); it != parts->end(); it++) {
		if (part_id && 0 == strcmp(part_id, (*it)["part_id"].c_str())) {
			temp_part = &(*it);
			break;
		}
	}
	if (!temp_part)
	{
		std::map<std::string, std::string> dict;
		if (part_id)
			dict["part_id"] = part_id;
		else
			dict["part_id"] = "";
		parts->push_back(dict);
		temp_part = &(parts->back());
	}
	std::stringstream ss;
	std::string s;
	ss << (staff+1);
	ss >> s;
	temp_part->insert(std::pair<std::string, std::string>("from_staff", s));
	part_staves = 1;

	//read measures
	std::shared_ptr<OveLine> line;
	std::shared_ptr<OvePage> page;
	int page_index = 0, line_index = 0, measure_index = 0;
	float staff_height = LINE_height*4;
	tinyxml2::XMLElement* measure_elem = element->FirstChildElement();
	while (measure_elem)
	{
		std::shared_ptr<OveMeasure> temp_measure;
		if (measure_index >= max_measures) {
			temp_measure = std::make_shared<OveMeasure>();
			m_pMusicScore->measures.push_back(temp_measure);
			temp_measure->number = measure_index;
			temp_measure->xml_division = last_divisions;
			memcpy(measure_start_clefs, last_clefs, sizeof(measure_start_clefs));
		} else {
			temp_measure = m_pMusicScore->measures[measure_index];
		}
		parseMeasure(measure_elem, staff, temp_measure);

		if (measure_index >= max_measures) {		//the first part(group)
			if (0 == measure_index || temp_measure->xml_new_line || temp_measure->xml_new_page) {
				//new page
				if (0 == measure_index 
#ifndef ONLY_ONE_PAGE
					|| temp_measure->xml_new_page
#endif
					) {
					if (page)		//previous page
						page->line_count = line_index-page->begin_line;
					if (m_pMusicScore->pages.empty())
					{
						page = std::make_shared<OvePage>();		//new page
						m_pMusicScore->pages.push_back(page);
						page->begin_line = line_index;
						page->system_distance = temp_measure->xml_system_distance;
						page->staff_distance = temp_measure->xml_staff_distance;
						page->xml_top_system_distance = temp_measure->xml_top_system_distance;
						page_index++;
					}
					m_pMusicScore->page_num++;
				}

				if (line)		//previous line
				{
					line->bar_count = measure_index-line->begin_bar;
					line->xml_staff_distance = temp_measure->xml_staff_distance;
				}
				line = std::make_shared<OveLine>();		//new line
				m_pMusicScore->lines.push_back(line);
				line->begin_bar = measure_index;
				line->fifths = temp_measure->fifths;
				line->xml_staff_distance = temp_measure->xml_staff_distance;
				line->xml_system_distance = temp_measure->xml_system_distance;
				for (int ss = 0; ss < part_staves; ss++)
				{
					std::shared_ptr<LineStaff> lineStaff = std::make_shared<LineStaff>();
					line->staves.push_back(lineStaff);
					lineStaff->y_offset = (0 == ss) ? 0 : line->xml_staff_distance+staff_height;
					lineStaff->hide = false;
					if (0 == ss)
						lineStaff->group_staff_count = part_staves-1;
					else
						lineStaff->group_staff_count = 0;
					lineStaff->clef = measure_start_clefs[ss];

					if (temp_measure->clefs.size() > 0) {
						for (auto clef = temp_measure->clefs.begin(); clef != temp_measure->clefs.end(); clef++) {
							std::shared_ptr<OveNote> xml_note;
							if ((*clef)->xml_note < temp_measure->notes.size())
								xml_note = temp_measure->notes[(*clef)->xml_note];
							else
								xml_note = temp_measure->notes.back();

							if ((*clef)->staff == ss+1 && xml_note->pos.tick == 0) {
								lineStaff->clef = (*clef)->clef;
								//don't remove this clef
								//temp_measure->clefs.erase(clef);
								break;
							}
						}
					}
				}
				line_index++;
			}
		} else {		//from the second part/group
			if (0 == measure_index || temp_measure->xml_new_line || temp_measure->xml_new_page) {
				if (0 == measure_index 
#ifndef ONLY_ONE_PAGE
					|| temp_measure->xml_new_page
#endif
					) {
					page = m_pMusicScore->pages[page_index];
					page_index++;
				}

				line = m_pMusicScore->lines[line_index];
				if (temp_measure->xml_staff_distance > 0)
					line->xml_staff_distance = temp_measure->xml_staff_distance;
				if (temp_measure->xml_system_distance > 0)
					line->xml_system_distance = temp_measure->xml_system_distance;

				for (int ss = 0; ss< part_staves; ss++)
				{
					std::shared_ptr<LineStaff> lineStaff = std::make_shared<LineStaff>();
					line->staves.push_back(lineStaff);
					lineStaff->y_offset = line->xml_staff_distance+staff_height;
					lineStaff->hide = false;
					if (0 == ss)
						lineStaff->group_staff_count = part_staves-1;
					else
						lineStaff->group_staff_count = 0;
					lineStaff->clef = last_clefs[ss+staff];
					if (temp_measure->clefs.size() > 0) {
						for (auto it = temp_measure->clefs.begin(); it != temp_measure->clefs.end(); it++) {
							if ((*it)->staff == staff+ss+1 && (*it)->pos.tick == 0) {
								lineStaff->clef = (*it)->clef;
								temp_measure->clefs.erase(it);
								break;
							}
						}
					}
				}
				line_index++;
			}
		}
		measure_elem = measure_elem->NextSiblingElement();
		measure_index++;
	}
	staff += part_staves;
	processSlursPrev();
	ss.clear();
	ss << part_staves;
	ss >> s;
	temp_part->insert(std::pair<std::string, std::string>("staves", s));

	if (max_measures < m_pMusicScore->measures.size())
	{
		max_measures = m_pMusicScore->measures.size();
		line->bar_count = max_measures-line->begin_bar;
		page->line_count = line_index-page->begin_line;
	}
	//add lines info
}

void MusicXMLParser::parseMeasure(tinyxml2::XMLElement* measure_elem, int start_staff, std::shared_ptr<OveMeasure>& measure)
{
	if (!measure_elem || !measure)
		return;

	static std::map<std::string, RepeatType> DCRepeat;
	if (DCRepeat.empty())
	{
		DCRepeat["Coda"] = Repeat_Coda;
		DCRepeat["al Coda"] = Repeat_ToCoda;
		DCRepeat["To Coda"] = Repeat_ToCoda;
		DCRepeat["D.S. al Coda"] = Repeat_DSAlCoda;
		DCRepeat["D.S. al Fine"] = Repeat_DSAlFine;
		DCRepeat["D.C. al Coda"] = Repeat_DCAlCoda;
		DCRepeat["D.C. al Fine"] = Repeat_DCAlFine;
		DCRepeat["Da Capo al Fine"] = Repeat_DCAlFine;
		DCRepeat["Da Capl al Fine"] = Repeat_DCAlFine;
		DCRepeat["D.C."] = Repeat_DC;
		DCRepeat["Fine"] = Repeat_Fine;
	}

	const char* name = measure_elem->Value();
	if (name && 0 == strcmp(name, "measure")) {
		if (ENUM_USED_FOR_GENTXT == m_eUsage) {
			const char* implicit = measure_elem->Attribute("implicit");
			if (!implicit || !strcmp(implicit, "no"))
			{
				const char* measure_number = measure_elem->Attribute("number");
				if (measure_number)
					measure->xml_number = measure_number;
			}
		} else {		//ENUM_USED_FOR_CHECK == m_eUsage
			const char* measure_number = measure_elem->Attribute("number");
			if (measure_number)
				measure->xml_number = measure_number;
		}

		const char* measure_width = measure_elem->Attribute("width");
		if (measure_width) {
			measure->meas_length_size = atoi(measure_width);
			if (1 == m_pMusicScore->measures.size() && measure->meas_length_size > 7*LINE_height)
				measure->meas_length_size -= 7*LINE_height;
		} else {
			measure->meas_length_size = m_pMusicScore->page_width/3;
		}

		//<print new-system="yes"> <system-layout>...</system_layout></print>
		tinyxml2::XMLElement* print_elem = measure_elem->FirstChildElement("print");
		if (print_elem) {
			const char* new_system = print_elem->Attribute("new-system");
			if (new_system && 0 == strcmp(new_system, "yes")) {
				system_index++;
				measure->xml_new_line = true;
				//if (measure_width && measure->meas_length_size > 7*LINE_height)
				//	measure->meas_length_size -= 7*LINE_height;
			} else {
				measure->xml_new_line = false;
			}
			const char* new_page = print_elem->Attribute("new-page");
#ifdef ONLY_ONE_PAGE
			if (new_page && !strcmp(new_page, "yes"))
			{
				measure->xml_new_line = true;
				measure->xml_new_page = true;
			}
#else
			if (new_page && !strcmp(new_page, "yes")) {
				measure->xml_new_page = true;
			} else {
				measure->xml_new_page = false;
			}
#endif

			tinyxml2::XMLElement* system_layout_elem = print_elem->FirstChildElement("system-layout");
			int top_system_distance = 0;
			if (system_layout_elem) {
				tinyxml2::XMLElement* divisions_elem = system_layout_elem->FirstChildElement("system-distance");
				if (divisions_elem)
				{
					const char* text = divisions_elem->GetText();
					if (text)
						measure->xml_system_distance = atoi(text);
				}
				divisions_elem = system_layout_elem->FirstChildElement("top-system-distance");
				if (divisions_elem)
				{
					const char* text = divisions_elem->GetText();
					if (text)
						top_system_distance = atoi(text);
				}
				if (measure->xml_system_distance == 0)
					measure->xml_system_distance = default_system_distance;
				measure->xml_system_distance += top_system_distance;
			} else {
				measure->xml_system_distance = default_system_distance;
			}

			if (top_system_distance > 0)
				measure->xml_top_system_distance = top_system_distance;
			else
				measure->xml_top_system_distance = default_top_system_distance;

			tinyxml2::XMLElement* staff_layout_elem = print_elem->FirstChildElement("staff-layout");
			if (staff_layout_elem)
			{
				tinyxml2::XMLElement* divisions_elem = staff_layout_elem->FirstChildElement("staff-distance");
				if (divisions_elem)
				{
					const char* text = divisions_elem->GetText();
					if (text)
						measure->xml_staff_distance = atoi(text);
				}
				if (measure->xml_staff_distance < min_staff_distance)
					measure->xml_staff_distance = min_staff_distance;
				else if (measure->xml_staff_distance > max_staff_distance)
					measure->xml_staff_distance = max_staff_distance;
			}
			if (0 == measure->xml_staff_distance)
				measure->xml_staff_distance = default_staff_distance;
		}
// 		if (0 == measure->xml_system_distance)
// 			measure->xml_system_distance = default_system_distance;
		if (0 == measure->xml_staff_distance)
			measure->xml_staff_distance = default_staff_distance;

		//notes
		tinyxml2::XMLElement* note_elem = measure_elem->FirstChildElement();
		float tick = 0;
		int temp_backup_duration = 0, temp_forward_duration = 0, start_offset = 0;
		std::shared_ptr<OveNote> direction_note, first_chord_note;
		while (note_elem)
		{
			name = note_elem->Value();
			if (name && 0 == strcmp(name, "note")) {
				bool isChord = false;
				std::shared_ptr<OveNote> note = parseNote(note_elem, &isChord, measure, start_staff, tick);
				//calculate note line, depend on clef

				if (note->note_elems.size() > 0) {
					std::shared_ptr<NoteElem>& elem = note->note_elems.front();
					ClefType clefType;
					if (tick > last_clefs_tick[note->staff-1]) {
						clefType = last_clefs[note->staff-1];
					} else {
						clefType = measure_start_clefs[note->staff-1];
					}

					if (Clef_Treble == clefType) {
						note->line = (elem->xml_pitch_step-7)+7*(elem->xml_pitch_octave-4);
					} else {
						note->line = 5+(elem->xml_pitch_step-7)+7*(elem->xml_pitch_octave-3);
					}

					//if (octave_shift_size != 0 && note->staff == octave_shift_staff)
					//	note->line -= octave_shift_size;
					int index = note->staff-1;
					if (0 != octave_shift_data[index].shift_size && 
						((measure->number == octave_shift_data[index].start_measure && tick >= octave_shift_data[index].start_tick) || measure->number > octave_shift_data[index].start_measure) &&
						(octave_shift_data[index].stop_tick < 0 || (tick < octave_shift_data[index].stop_tick && measure->number <= octave_shift_data[index].stop_measure)))
						note->line -= octave_shift_data[index].shift_size;

					//if (note->isRest && 0 == note->line)
					//	note->line = 1;
					elem->line = note->line;
				}

				if (!isChord) {
					measure->notes.push_back(note);
					note->pos.tick = tick;
					if (0 != note->pos.start_offset) {
						start_offset = note->pos.start_offset;
						start_offset += measure->meas_length_size*note->xml_duration/(last_divisions*last_numerator*4/last_denominator);
					} else {
						note->pos.start_offset = start_offset;
						if (note->isGrace)
							note->pos.start_offset -= measure->meas_length_size*(last_divisions/4)/(last_divisions*last_numerator*4/last_denominator);
						start_offset += measure->meas_length_size*note->xml_duration/(last_divisions*last_numerator*4/last_denominator);
					}
					tick += note->xml_duration*480.0/last_divisions;
					if (tick > measure->meas_length_tick)
						measure->meas_length_tick = tick;
					chord_inBeam = note->inBeam;
					first_chord_note = note;
					if (note->isGrace)
						tick += 1;
				} else {
					//chord
					if (!note->note_arts.empty())
						for (auto it = note->note_arts.begin(); it != note->note_arts.end(); it++)
							first_chord_note->note_arts.push_back(*it);

					if (!note->note_elems.empty())
					{
						for (auto it = note->note_elems.begin(); it != note->note_elems.end(); it++)
							first_chord_note->note_elems.push_back(*it);
						auto& newElem = note->note_elems.front();
						note->line = newElem->line;

						if (note->staff > first_chord_note->staff) {
							newElem->offsetStaff = 1;
						} else if (note->staff < first_chord_note->staff) {
							newElem->offsetStaff = -1;
						}
					}
				}
			} else if (name && 0 == strcmp(name, "attributes")) {
				parseAttributes(note_elem, measure, start_staff, (0 == tick) ? nullptr : first_chord_note, tick);
			} else if (name && 0 == strcmp(name, "backup")) {
				tinyxml2::XMLElement* divisions_elem = note_elem->FirstChildElement("duration");
				if (divisions_elem)
				{
					const char* text = divisions_elem->GetText();
					if (text)
						temp_backup_duration = atoi(text);
				}
				tick -= temp_backup_duration*480.0/last_divisions;
				if (tick < 0)
				{
					tick = 0;
					printf("backup duration too long at measure(%d)\n", measure->number);
				}
				if (0 == tick)
					start_offset = 0;
				else
					start_offset -= measure->meas_length_size*temp_backup_duration/(last_divisions*last_numerator*4/last_denominator);
			} else if (name && 0 == strcmp(name, "forward")) {
				tinyxml2::XMLElement* divisions_elem = note_elem->FirstChildElement("duration");
				if (divisions_elem)
				{
					const char* text = divisions_elem->GetText();
					if (text)
						temp_forward_duration = atoi(text);
				}
				tick += temp_forward_duration*480.0/last_divisions;
				start_offset += measure->meas_length_size*temp_forward_duration/(last_divisions*last_numerator*4/last_denominator);
			} else if (name && 0 == strcmp(name, "direction")) {
				tinyxml2::XMLElement* direction_elem = note_elem;
				int staff = 1;
				tinyxml2::XMLElement* divisions_elem = direction_elem->FirstChildElement("staff");
				if (divisions_elem)
				{
					const char* text = divisions_elem->GetText();
					if (text)
						staff = atoi(text);
				}
				int dir_offset = 0;
				divisions_elem = direction_elem->FirstChildElement("offset");
				if (divisions_elem)
				{
					const char* text = divisions_elem->GetText();
					if (text)
						dir_offset = atoi(text);
				}
				const char* placement = direction_elem->Attribute("placement");
				//<sound tempo="60"/>
				tinyxml2::XMLElement* sound_elem = direction_elem->FirstChildElement("sound");
				if (sound_elem)
				{
					const char* sound = sound_elem->Attribute("tempo");
					if (sound)
						measure->typeTempo = atoi(sound);
				}
				tinyxml2::XMLElement* type_elem = direction_elem->FirstChildElement("direction-type");
				while (type_elem)
				{
					tinyxml2::XMLElement* child_elem = type_elem->FirstChildElement();
					std::shared_ptr<OveText> conc_words = nullptr;
					while (child_elem)
					{
						const char* name = child_elem->Value();
						int default_x = 0, default_y = 0, relative_x = 0;
						const char* default_attri = child_elem->Attribute("default-x");
						if (default_attri)
							default_x = atoi(default_attri);
						default_attri = child_elem->Attribute("default-y");
						if (default_attri)
							default_y = atoi(default_attri);
						const char* relative_attr = child_elem->Attribute("relative-x");
						if (relative_attr)
							relative_x = atoi(relative_attr);

						if (placement && 0 == default_y)
						{
							if (placement && 0 == strcmp(placement, "below"))
								default_y -= 7*LINE_height;
							else
								default_y += 7*LINE_height;
						}
						
						CommonBlock pos;
						pos.tick = tick;
						pos.start_offset = start_offset;

						if (name && 0 == strcmp(name, "sound")) {
							measure->typeTempo = 0;
							const char* attr = child_elem->Attribute("tempo");
							if (attr)
								measure->typeTempo = atoi(attr);
						} else if (name && 0 == strcmp(name, "metronome")) {
							bool dot = false;
							const char* metronome_beat_unit = nullptr, *metronome_per_minute = nullptr;
							tinyxml2::XMLElement* temp_elem = child_elem->FirstChildElement("beat-unit");
							if (temp_elem)
								metronome_beat_unit = temp_elem->GetText();

							temp_elem = child_elem->FirstChildElement("beat-unit-dot");
							if (temp_elem)
								dot = true;

							temp_elem = child_elem->FirstChildElement("per-minute");
							if (temp_elem)
								metronome_per_minute = temp_elem->GetText();

							std::shared_ptr<Tempo> tempo = std::make_shared<Tempo>();
							measure->tempos.push_back(tempo);
							// left note type
							//高2位7-6：always:01
							//高2位5-4：00: normal, 10:附点
							//底4位3-0：01:全音符，02：二分音符，03：四分音符， 04:八分音符，05：十六分音符
							//如：0x43: 四分音符，0x63,0x23: 1.5个四分音符
							if (metronome_beat_unit && 0 == strcmp(metronome_beat_unit, "half")) {
								tempo->left_note_type = 0x02;
							} else if (metronome_beat_unit && (0 == strcmp(metronome_beat_unit, "quater") || 0 == strcmp(metronome_beat_unit, "quarter"))) {
								tempo->left_note_type = 0x03;
							} else if (metronome_beat_unit && 0 == strcmp(metronome_beat_unit, "eighth")) {
								tempo->left_note_type = 0x04;
							} else if (metronome_beat_unit && 0 == strcmp(metronome_beat_unit, "16th")) {
								tempo->left_note_type = 0x05;
							} else {
								tempo->left_note_type = 0x03;
							}
							if (dot)
								tempo->left_note_type |= 0x20;
							tempo->tempo_range = 0;
							const char* pch = nullptr;
							if (metronome_per_minute)
							{
								tempo->tempo = atoi(metronome_per_minute);
								pch = strstr(metronome_per_minute, "-");
							}
							if (pch)
							{
								int next_temp = atoi(pch+1);
								if (next_temp > tempo->tempo)
									tempo->tempo_range = next_temp-tempo->tempo;
							}
							tempo->pos = pos;

							if (measure->meas_texts.size()) {
								std::shared_ptr<OveText>& text = measure->meas_texts.back();
								tempo->tempo_left_text = text->text;
								tempo->offset_y = text->offset_y;
								if (text->font_size > 0)
									tempo->font_size = text->font_size;
								else
									tempo->font_size = 28;
								measure->meas_texts.pop_back();
							} else {
								const char* attr = child_elem->Attribute("default-y");
								if (attr)
									tempo->offset_y = -atoi(attr);
							}
						} else if (name && 0 == strcmp(name, "dynamics")) {
							std::string dynamic_text;
							tinyxml2::XMLElement* dynamic_item_element = child_elem->FirstChildElement();
							while (dynamic_item_element)
							{
								const char* dynamic_item = dynamic_item_element->Value();
								if (dynamic_item)
									dynamic_text += dynamic_item;
								dynamic_item_element = dynamic_item_element->NextSiblingElement();
							}

							std::shared_ptr<OveDynamic> dynamic = std::make_shared<OveDynamic>();
							measure->dynamics.push_back(dynamic);
							std::map<std::string, DynamicsType> dynamic_values;
							dynamic_values["p"] = Dynamics_p;
							dynamic_values["pp"] = Dynamics_pp;
							dynamic_values["ppp"] = Dynamics_ppp;
							dynamic_values["pppp"] = Dynamics_pppp;
							dynamic_values["f"] = Dynamics_f;
							dynamic_values["ff"] = Dynamics_ff;
							dynamic_values["fff"] = Dynamics_fff;
							dynamic_values["ffff"] = Dynamics_ffff;
							dynamic_values["fp"] = Dynamics_fp;
							dynamic_values["mp"] = Dynamics_mp;
							dynamic_values["mf"] = Dynamics_mf;
							dynamic_values["sf"] = Dynamics_sf;
							dynamic_values["sff"] = Dynamics_sff;
							dynamic_values["fz"] = Dynamics_fz;
							dynamic_values["sfz"] = Dynamics_sfz;
							dynamic_values["sffz"] = Dynamics_sffz;
							dynamic_values["sfp"] = Dynamics_sfp;

							if (default_y) {
								dynamic->offset_y = -default_y;
							} else {
								dynamic->offset_y = LINE_height*4;
							}

							dynamic->pos.start_offset = relative_x;
							if (0 == default_x)
								dynamic->pos.tick = dir_offset*480.0/last_divisions;

							if (!dynamic->pos.tick)
								dynamic->pos.tick = tick;
							dynamic->xml_note = measure->notes.size();

							dynamic->staff = staff+start_staff;
							if (dynamic_values.find(dynamic_text) != dynamic_values.end())
								dynamic->dynamics_type = dynamic_values[dynamic_text];
						} else if (name && 0 == strcmp(name, "bracket")) {		//表示踏板或者左右手
							/*
							<!ATTLIST bracket
							type %start-stop-continue; #REQUIRED
							number %number-level; #IMPLIED
							line-end (up | down | both | arrow | none) #REQUIRED
							end-length %tenths; #IMPLIED
							%line-type;
							%dashed-formatting;
							%position;
							%color;
							>
							//<bracket default-y="-72" line-end="up" line-type="solid" number="1" relative-x="-13" type="start"/>
							//<bracket line-end="up" number="1" type="stop"/>
							*/
							const char* type = child_elem->Attribute("type");
							const char* attr = child_elem->Attribute("number");
							int number = attr ? atoi(attr) : 0;
							const char* line_end = child_elem->Attribute("line-end");
							if (line_end && 0 == strcmp(line_end, "up")) {		//pedal
								if (type && 0 == strcmp(type, "start")) {
									std::shared_ptr<MeasurePedal> pedal = std::make_shared<MeasurePedal>();
									measure->pedals.push_back(pedal);
									pedal->xml_slur_number = number;
									pedal->xml_start_measure_index = measure->number;
									pedal->xml_start_note_index = measure->notes.size();
									pedal->staff = staff+start_staff;
									pedal->isLine = true;
									pedal->pos.tick = tick;
									pedal->pos.start_offset = start_offset;
									pedal->pair_ends.left_line = default_y/LINE_height*2;
									pedal->pair_ends.right_line = default_y/LINE_height*2;
								} else if (type && 0 == strcmp(type, "stop")) {
									for (int mm = measure->number; mm >= 0; mm--) {
										auto& temp_measure = m_pMusicScore->measures[mm];
										for (auto pedal = temp_measure->pedals.begin(); pedal != temp_measure->pedals.end(); pedal++) {
											if ((*pedal)->xml_slur_number == number && 0 == (*pedal)->offset.stop_measure && 0 == (*pedal)->offset.stop_offset) {
												(*pedal)->xml_stop_measure_index = measure->number;
												if (measure->notes.size() > 0)
													(*pedal)->xml_stop_note_index = measure->notes.size()-1;
												else
													(*pedal)->xml_stop_note_index = 0;
												(*pedal)->offset.stop_measure = measure->number-mm;
												break;
											}
										}
									}
								}
							}
						} else if (name && 0 == strcmp(name, "pedal")) {
							//踩踏板:start | stop | continue(allows more precise formatting across system breaks) | change (indicates a pedal lift and retake indicated with an inverted V marking)
							//<pedal default-y="-99" line="no" relative-x="-10" type="start"/>
							//<pedal default-y="-65" line="yes" type="start"/>
							//<pedal line="yes" type="change"/>
							//<pedal line="yes" type="stop"/>

							const char* pedal_type = child_elem->Attribute("type");
							const char* attr = child_elem->Attribute("line");
							bool pedal_line = (attr && 0 == strcmp(attr, "yes"));
							if (pedal_type && (!strcmp(pedal_type, "stop") || !strcmp(pedal_type, "change"))) {
								for (int mm = measure->number; mm >= 0; mm--) {
									auto& temp_measure = m_pMusicScore->measures[mm];
									for (auto pedal = temp_measure->pedals.begin(); pedal != temp_measure->pedals.end(); pedal++) {
										if (!(*pedal)->offset.stop_measure && !(*pedal)->offset.stop_offset) {
											(*pedal)->xml_stop_measure_index = measure->number;
											(*pedal)->xml_stop_note_index = measure->notes.size();
											(*pedal)->offset.stop_measure = measure->number-mm;
											break;
										}
									}
								}
							}

							static int pedal_start_line = 0;
							if (pedal_type && (!strcmp(pedal_type, "start") || !strcmp(pedal_type, "change"))) {
								if (!strcmp(pedal_type, "start")) {
									if (default_y)
										pedal_start_line = default_y/LINE_height*2;
									else
										pedal_start_line = -7;
								}
								std::shared_ptr<MeasurePedal> pedal = std::make_shared<MeasurePedal>();
								measure->pedals	.push_back(pedal);
								pedal->isLine = pedal_line;
								pedal->xml_start_measure_index = measure->number;
								pedal->xml_start_note_index = measure->notes.size();
								pedal->staff = 2+start_staff;
								pedal->pos.tick = tick;
								pedal->pos.start_offset = start_offset;
								pedal->pair_ends.left_line = pedal_start_line;
								pedal->pair_ends.right_line = pedal_start_line;
							}
							/*
							std::shared_ptr<MeasureDecorators> deco = std::make_shared<MeasureDecorators>();
							measure->decorators.push_back(deco);
							deco->decoratorType = Decorator_Articulation;
							deco->staff = staff+start_staff;
							deco->xml_start_note = (0 == tick) ? nullptr : first_chord_note;

							if (placement) {
								if (placement && 0 == strcmp(placement, "below"))
									deco->offset_y = -4*LINE_height;
								else
									deco->offset_y = 4*LINE_height;
							} else {
								deco->offset_y = -default_y;
							}
							if (pedal_type && 0 == strcmp(pedal_type, "start"))
								deco->artType = Articulation_Pedal_Down;
							else
								deco->artType = Articulation_Pedal_Up;
							*/
						} else if (name && 0 == strcmp(name, "wedge")) {
							if (placement)
							{
								if (0 == strcmp(placement, "below"))
									default_y = -1*LINE_height;
								else
									default_y = 12*LINE_height;
							}

							//static std::shared_ptr<OveWedge> opened_wedge[2];
							const char* wedge_type = child_elem->Attribute("type");		//楔子:stop, crescendo, diminuendo
							const char* numberStr = child_elem->Attribute("number");		//1,2...
							int number = 0;
							if (numberStr && 0 == strcmp(numberStr, "2"))
								number = 1;

							if (wedge_type && 0 != strcmp(wedge_type, "stop")) {
								std::shared_ptr<OveWedge> wedge = std::make_shared<OveWedge>();
								measure->wedges.push_back(wedge);
								if (0 == number)
									m_pMusicScore->opened_wedge1 = wedge;
								else
									m_pMusicScore->opened_wedge2 = wedge;
								//opened_wedge[number] = wedge;
								wedge->wedgeOrExpression = true;
								if (wedge_type && 0 == strcmp(wedge_type, "crescendo"))		//crescendo <
									wedge->wedgeType = Wedge_Cres_Line;
								else		//diminuendo >
									wedge->wedgeType = Wedge_Decresc_Line;
								wedge->offset_y = -default_y;
								wedge->xml_staff = staff+start_staff;
								wedge->xml_start_note = measure->notes.size();		//the wedge start with next note
								if (0 == default_x && 0 != dir_offset) {
									wedge->pos.tick = dir_offset*LINE_height;
								} else {
									wedge->pos.start_offset = 0;
								}
								wedge->offset.stop_measure = measure->number;
							} else {
								std::shared_ptr<OveWedge> wedge;
								if (0 == number)
									wedge = m_pMusicScore->opened_wedge1;
								else
									wedge = m_pMusicScore->opened_wedge2;
								wedge->offset.stop_measure = measure->number-wedge->offset.stop_measure;
								wedge->xml_stop_note = measure->notes.size();		//the wedge end with next note
								wedge->xml_staff = staff+start_staff;
								if (!wedge->offset.stop_measure && wedge->xml_stop_note == wedge->xml_start_note && wedge->xml_start_note > 0)
									wedge->xml_start_note--;
								//if (0 == default_x && 0 != dir_offset)
								//	opened_wedge[number]->offset.stop_offset = dir_offset*LINE_height;
							}
						} else if (name && 0 == strcmp(name, "words")) {
							const char* temp_words = child_elem->GetText();
							if (temp_words && !strcmp(temp_words, "piu"))
								temp_words = "più";

							int font_size = 10;
							const char* font_size_attr = child_elem->Attribute("font-size");
							if (font_size_attr)
								font_size = atoi(font_size_attr);
							const char* font_weight = child_elem->Attribute("font-weight");		//font-weight="bold"
							const char* font_style = child_elem->Attribute("font-style");
							const char* relative_x = child_elem->Attribute("relative-x");

							std::string DC_words = temp_words ? temp_words : "";
							RepeatType repeatType = Repeat_Null;
							if (!trim(DC_words).empty() && DCRepeat.find(DC_words) != DCRepeat.end())
								repeatType = DCRepeat[DC_words];
							if (repeatType) {
								measure->repeat_type = repeatType;
							} else if (temp_words) {
								if (conc_words == nullptr)
								{
									conc_words = std::make_shared<OveText>();
									measure->meas_texts.push_back(conc_words);
								}

								std::shared_ptr<OveText> text = conc_words;
								if (!text->text.empty()) {
									if (temp_words)
									{
										char tmp_buf[64];
										sprintf(tmp_buf, "%s %s", text->text.c_str(), temp_words);
										text->text = tmp_buf;
									}
								} else {
									if (temp_words)
										text->text = temp_words;

									text->offset_y = -default_y;
									text->offset_x = (relative_x ? atoi(relative_x) : 0);	//+dir_offset*LINE_height;
									text->staff = staff+start_staff;
									text->xml_start_note = measure->notes.size();
									if (!relative_x && measure->dynamics.size() > 0) {
										for (auto dyn = measure->dynamics.begin(); dyn != measure->dynamics.end(); dyn++) {
											if ((*dyn)->staff == text->staff && (*dyn)->pos.start_offset == text->offset_x && (*dyn)->xml_note == text->xml_start_note) {
												(*dyn)->pos.start_offset -= LINE_height;
												text->offset_x += 2*LINE_height;
												break;
											}
										}
									}
									if (default_x == 0 && dir_offset != 0) {
										text->pos.tick = dir_offset*480.0/last_divisions;
									} else {
										text->pos.tick = 0;
									}
									if (font_weight && 0 == strcmp(font_weight, "bold"))
										text->isBold = true;
									else
										text->isBold = false;
									if (font_style && 0 == strcmp(font_style, "italic"))
										text->isItalic = true;
									else
										text->isItalic = false;
									if (font_size > 0)
										text->font_size = font_size*2;
								}
							}
						} else if (name && 0 == strcmp(name, "image")) {
							std::shared_ptr<OveImage> image = std::make_shared<OveImage>();
							measure->images.push_back(image);
							const char* attr = child_elem->Attribute("source");
							if (attr)
								image->source = attr;
							else
								image->source = "";
							image->offset_y = -default_y;
							image->offset_x = default_x;
							attr = child_elem->Attribute("halign");
							if (attr)
								image->width = atoi(attr);
							attr = child_elem->Attribute("valign");
							if (attr)
								image->height = atoi(attr);
							image->type = 0;
							image->staff = staff+start_staff;
							image->pos = pos;
						} else if (name && 0 == strcmp(name, "octave-shift")) {
							//static int octave_start_offset_y = 0;
							const char* type = child_elem->Attribute("type");		//up | down | stop | continue
							int size = 0;				//8: one octave, 15: two cotaves
							const char* attr = child_elem->Attribute("size");
							if (attr)
								size = atoi(attr);
							if (0 == size)
								size = 8;

							std::shared_ptr<OctaveShift> shift = std::make_shared<OctaveShift>();
							measure->octaves.push_back(shift);
							shift->staff = staff+start_staff;
							int shift_index = shift->staff-1;

							if (type && 0 == strcmp(type, "down")) {		//down 比真正的降低8度
								shift->xml_note = measure->notes.size();
								shift->offset_y = -default_y;
								octave_shift_data[shift_index].octave_start_offset_y = -default_y;

								if (8 != size) {
									shift->octaveShiftType = OctaveShift_15_Start;
									octave_shift_data[shift_index].shift_size = 15;
								} else {
									shift->octaveShiftType = OctaveShift_8_Start;
									octave_shift_data[shift_index].shift_size = 7;
								}
								octave_shift_data[shift_index].start_tick = tick;
								octave_shift_data[shift_index].stop_tick = -1;
								octave_shift_data[shift_index].start_measure = measure->number;
								
								//如果前面是倚音，需要把倚音提高8度
								if (measure->xml_new_line && measure->notes.size() > 0) {
									for (int prev = measure->notes.size()-1; prev >= 0; prev--) {
										std::shared_ptr<OveNote>& prevNote = measure->notes[prev];
										if (prevNote->staff == shift->staff && prevNote->isGrace) {
											for (auto prevElem = prevNote->note_elems.begin(); prevElem != prevNote->note_elems.end(); prevElem++) {
												if (OctaveShift_15_Start == shift->octaveShiftType)
													(*prevElem)->note += 12*2;
												else
													(*prevElem)->note += 12;
											}
										} else {
											break;
										}
									}
								}
							} else if (type && 0 == strcmp(type, "up")) {		//up 比真正的升高8度
								shift->xml_note = measure->notes.size();
								shift->offset_y = -default_y;
								octave_shift_data[shift_index].octave_start_offset_y = -default_y;

								if (8 != size) {
									shift->octaveShiftType = OctaveShift_Minus_15_Start;
									octave_shift_data[shift_index].shift_size = -15;
								} else {
									shift->octaveShiftType = OctaveShift_Minus_8_Start;
									octave_shift_data[shift_index].shift_size = -7;
								}
								octave_shift_data[shift_index].start_tick = tick;
								octave_shift_data[shift_index].stop_tick = -1;
								octave_shift_data[shift_index].start_measure = measure->number;
							} else if (type && 0 == strcmp(type, "stop")) {
								shift->offset_y = octave_shift_data[shift_index].octave_start_offset_y;
								if (8 != size)
									shift->octaveShiftType = (octave_shift_data[shift_index].shift_size > 0) ? OctaveShift_15_Stop : OctaveShift_Minus_15_Stop;
								else
									shift->octaveShiftType = (octave_shift_data[shift_index].shift_size > 0) ? OctaveShift_8_Stop : OctaveShift_Minus_8_Stop;
								//if (tick > 0) {
								//	shift->xml_note = measure->notes.size();
								//	octave_shift_data[shift_index].stop_tick = tick-1;
								//} else {
								shift->xml_note = (measure->notes.size() > 0) ? measure->notes.size()-1 : 0;
								octave_shift_data[shift_index].stop_tick = tick;
								//}
								octave_shift_data[shift_index].stop_measure = measure->number;
							} else if (type && 0 == strcmp(type, "continue")) {
								shift->xml_note = (measure->notes.size() > 0) ? measure->notes.size()-1 : 0;
								shift->offset_y = octave_shift_data[shift_index].octave_start_offset_y;
								if (8 != size)
									shift->octaveShiftType = OctaveShift_15_Continue;
								else
									shift->octaveShiftType = OctaveShift_8_Continue;
							}
						} else if (name && 0 == strcmp(name, "segno")) { 
							measure->repeat_type = Repeat_Segno;
							measure->repeat_offset.offset_x = 0;
							measure->repeat_offset.offset_y = -default_y;
						} else if (name && 0 == strcmp(name, "coda")) {
							measure->repeat_type = Repeat_Coda;
							measure->repeat_offset.offset_x = 0;
							measure->repeat_offset.offset_y = -default_y;
						} else {
							printf("Error unknown direct type=%s\n", name);
						}
						child_elem = child_elem->NextSiblingElement();
					}
					type_elem = type_elem->NextSiblingElement("direction-type");
				}
			} else if (name && 0 == strcmp(name, "barline")) {
				const char* barline_location = note_elem->Attribute("location");		//left, right
				const char* barline_bar_style = NULL;
				tinyxml2::XMLElement* temp_elem = note_elem->FirstChildElement("bar-style");
				if (temp_elem)
					barline_bar_style = temp_elem->GetText();
				tinyxml2::XMLElement* repeat_elem = note_elem->FirstChildElement("repeat");
				if (repeat_elem) {
					const char* barline_repeat_direction = repeat_elem->Attribute("direction");		//forward, backward
					const char* play = repeat_elem->Attribute("play");		//yes or no, default is yes
					if (play && !strcmp(play, "no")) {
						measure->repeat_play = false;
					} else {
						measure->repeat_play = true;
					}
					if (barline_location && 0 == strcmp(barline_location, "left")) {
						if (barline_repeat_direction && 0 == strcmp(barline_repeat_direction, "forward"))
							measure->left_barline = Barline_RepeatLeft;
						else
							printf("error, unknown barline_repeat_direction=%s\n", barline_repeat_direction);
					} else {
						if (barline_repeat_direction && 0 == strcmp(barline_repeat_direction, "backward")) {
							measure->right_barline = Barline_RepeatRight;
							measure->repeat_count = 1;
						} else {
							measure->right_barline = Barline_Final;
						}
					}
				} else {
					if (barline_bar_style)
					{
						if (0 == strcmp(barline_bar_style, "light-heavy")) {
							measure->right_barline = Barline_Final;
						} else if (0 == strcmp(barline_bar_style, "light-light")) {
							measure->right_barline = Barline_Double;
						} else if (0 == strcmp(barline_bar_style, "none")) {
							if (measure->notes.size() > 0)
								measure->right_barline = Barline_Default;
							else
								measure->right_barline = Barline_Null;
						}
					}
				}
				//<ending default-y="48" end-length="30" font-size="8.5" number="1" print-object="yes" type="start"/>
				tinyxml2::XMLElement* ending_elem = note_elem->FirstChildElement("ending");
				if (ending_elem)
				{
					const char* barline_ending_number = ending_elem->Attribute("number");		//1,2,
					const char* barline_ending_type = ending_elem->Attribute("type");		//start, stop
					const char* default_y = ending_elem->Attribute("default-y");

					static std::vector<std::shared_ptr<NumericEnding> > opened_ending;
					if (barline_ending_type && 0 == strcmp(barline_ending_type, "start")) {
						std::shared_ptr<NumericEnding> ending = std::make_shared<NumericEnding>();
						measure->numerics.push_back(ending);
						if (barline_ending_number)
							ending->numeric_text = barline_ending_number;
						ending->numeric_measure_count = 1;
						ending->pos.tick = tick;
						ending->pos.start_offset = measure->number;		//start_offset;
						if (default_y)
							ending->offset_y = atoi(default_y);

						const char* play = ending_elem->Attribute("play");		//yes or no, default is yes
						if (play && !strcmp(play, "no")) {
							ending->ending_play = false;
							ending->numeric_measure_count = 0;
						} else {
							ending->ending_play = true;
						}
						opened_ending.push_back(ending);
					} else {
						bool find_stopped = false;
						for (auto ending = opened_ending.begin(); ending != opened_ending.end(); ending++) {
							if (barline_ending_number && 0 == strcmp((*ending)->numeric_text.c_str(), barline_ending_number)) {
								(*ending)->numeric_measure_count = measure->number-(*ending)->pos.start_offset+1;
								opened_ending.erase(ending);
								find_stopped = true;
								break;
							}
						}
						if (!find_stopped)
							printf("Barline ending Error\n");
					}
				}
			}
			note_elem = note_elem->NextSiblingElement();
		}
	} else {
		printf("error unknown element:%s\n", name);
		return;
	}
	measure->fifths = last_key_fifths;
	measure->numerator = last_numerator;
	measure->denominator = last_denominator;
	measure->xml_staves += part_staves;
	measure->typeTempo = metronome_per_minute;
}

int MusicXMLParser::numOf32ndOfNoteType(NoteType note_type, int dots)
{
	int trill_num_of_32nd;
	if (Note_Whole == note_type) {
		trill_num_of_32nd = 32;		//32;
	} else if (Note_Half == note_type) {
		trill_num_of_32nd = 16;
	} else if (Note_Quarter == note_type) {
		trill_num_of_32nd = 8;
	} else if (Note_Eight == note_type) {
		trill_num_of_32nd = 4;
	} else {
		trill_num_of_32nd = 6;
	}
	if (dots > 0)
		trill_num_of_32nd += trill_num_of_32nd/2;
	return trill_num_of_32nd;
}

int MusicXMLParser::noteValueForStep(int pitch_step, int pitch_octave, int pitch_alter)
{
	int note_value = (1+pitch_octave)*12+pitch_alter;
	if (2 == pitch_step) {		//D
		note_value += 2;
	} else if (3 == pitch_step) {		//E
		note_value += 4;
	} else if (4 == pitch_step) {		//F
		note_value += 5;
	} else if (5 == pitch_step) {		//G
		note_value += 7;
	} else if (6 == pitch_step) {		//A
		note_value += 9;
	} else if (7 == pitch_step) {		//B
		note_value += 11;
	}
	return note_value;
}

NoteType MusicXMLParser::noteType(const std::string& type)
{
	NoteType note_type = Note_None;
	if ("breve" == type) {
		note_type = Note_DoubleWhole;
	} else if ("whole" == type) {
		note_type = Note_Whole;
	} else if ("half" == type) {
		note_type = Note_Half;
	} else if ("quarter" == type) {
		note_type = Note_Quarter;
	} else if ("eighth" == type) {
		note_type = Note_Eight;
	} else if ("16th" == type) {
		note_type = Note_Sixteen;
	} else if ("32nd" == type) {
		note_type = Note_32;
	} else if ("64th" == type) {
		note_type = Note_64;
	} else if ("128th" == type) {
		note_type = Note_128;
	} else if ("256th" == type) {
		note_type = Note_256;
	} else {
		printf("Error: unknown note_type=%s\n", type.c_str());
	}
	return note_type;
}

std::shared_ptr<OveNote> MusicXMLParser::parseNote(tinyxml2::XMLElement* note_elem, bool* isChord, std::shared_ptr<OveMeasure>& measure, int start_staff, int tick)
{
	if (!note_elem || !isChord || !measure)
		return nullptr;

	const char* name = note_elem->Value();
	if (name && 0 == strcmp(name, "note")) {
		//<note default-x="149">
		const char* default_x_str = note_elem->Attribute("default-x");
		int start_offset = 0;
		if (default_x_str)
			start_offset = atoi(default_x_str);
		if (measure->notes.empty())
		{
			measure->xml_firstnote_offset_x = start_offset;
			if (measure->xml_new_line)
				measure->meas_length_size -= start_offset;
		}

		int duration = 0, staff = 1, voice = 0, dots = 0;
		int pitch_step = 0, pitch_octave = 0, pitch_alter = 0, note_value = 0, stem_default_y = 0;
		unsigned char tie_pos = Tie_None;
		bool inBeam = false, isGrace = false, isRest = false, stem_up = false;

		NoteType note_type = Note_None;
		const char* accidental = nullptr;
		std::map<int, std::string> xml_beams;
		std::vector<std::map<std::string, std::string> >xml_ties, xml_slurs, xml_lyrics, xml_tuplets;
		//bool have_tuplets = false;
		std::vector<std::shared_ptr<NoteArticulation> > note_arts, xml_fingers;

		tinyxml2::XMLElement* elem = note_elem->FirstChildElement();
		while (elem)
		{
			name = elem->Value();
			if (name && 0 == strcmp(name, "duration")) {
				const char* text = elem->GetText();
				if (text)
					duration = atoi(text);
			} else if (name && 0 == strcmp(name, "voice")) {
				const char* text = elem->GetText();
				if (text)
					voice = atoi(text);
			} else if (name && 0 == strcmp(name, "chord")) {
				*isChord = true;
				inBeam = chord_inBeam;
			} else if (name && 0 == strcmp(name, "dot")) {
				dots++;
			} else if (name && 0 == strcmp(name, "grace")) {
				isGrace = true;
			} else if (name && 0 == strcmp(name, "staff")) {
				const char* text = elem->GetText();
				if (text)
					staff = atoi(text);
			} else if (name && 0 == strcmp(name, "accidental")) {
				accidental = elem->GetText();
			} else if (name && 0 == strcmp(name, "stem")) {
				tinyxml2::XMLElement* stem_elem = elem;
				if (stem_elem)
				{
					const char* stem = stem_elem->GetText();
					if (stem && 0 == strcmp(stem, "up"))
						stem_up = true;
					else
						stem_up = false;
					const char* number = stem_elem->Attribute("default-y");
					if (number)
						stem_default_y = atoi(number);
				}
			} else if (name && 0 == strcmp(name, "beam")) {
				const char* number = elem->Attribute("number");
				if (!number)
					number = "1";
				const char* text = elem->GetText();
				if (text)
					xml_beams[atoi(number)] = text;
				else
					xml_beams[atoi(number)] = "";
				inBeam = true;
			} else if (name && 0 == strcmp(name, "type")) {
				const char* type = nullptr;		//256th, 128th, 64th, 32nd, 16th, eighth, quarter, half, whole, breve, and long
				tinyxml2::XMLElement* temp_elem = note_elem->FirstChildElement("type");
				if (temp_elem)
					type = temp_elem->GetText();
				if (type) {
					note_type = noteType(type);
					if (duration > 0)
						duration_per_256th = note_type*1.0f/duration;
				} else {
					note_type = static_cast<NoteType>((int)duration_per_256th*duration);
				}
			} else if (name && 0 == strcmp(name, "rest")) {
				const char* step = nullptr;
				isRest = true;
				tinyxml2::XMLElement* temp_elem = elem->FirstChildElement("display-step");
				if (temp_elem)
					step = temp_elem->GetText();
				if (step) {
					if (0 == strcmp(step, "C"))	pitch_step = 1;
					else if (0 == strcmp(step, "D"))	pitch_step = 2;
					else if (0 == strcmp(step, "E"))	pitch_step = 3;
					else if (0 == strcmp(step, "F"))	pitch_step = 4;
					else if (0 == strcmp(step, "G"))	pitch_step = 5;
					else if (0 == strcmp(step, "A"))	pitch_step = 6;
					else if (0 == strcmp(step, "B"))	pitch_step = 7;
					else printf("Error: unknown reset step=%s\n", step);
				} else {
					pitch_step = 0;
				}
				temp_elem = elem->FirstChildElement("display-octave");
				if (temp_elem)
				{
					const char* text = temp_elem->GetText();
					if (text)
						pitch_octave = atoi(text);
				}
			} else if (name && 0 == strcmp(name, "pitch")) {
				const char* step = nullptr;
				tinyxml2::XMLElement* temp_elem = elem->FirstChildElement("step");
				if (temp_elem)
					step = temp_elem->GetText();
				if (step)
				{
					if (0 == strcmp(step, "C"))	pitch_step = 1;
					else if (0 == strcmp(step, "D"))	pitch_step = 2;
					else if (0 == strcmp(step, "E"))	pitch_step = 3;
					else if (0 == strcmp(step, "F"))	pitch_step = 4;
					else if (0 == strcmp(step, "G"))	pitch_step = 5;
					else if (0 == strcmp(step, "A"))	pitch_step = 6;
					else if (0 == strcmp(step, "B"))	pitch_step = 7;
					else printf("Error, unknown pitch step=%s\n", step);
				}
				temp_elem = elem->FirstChildElement("alter");
				if (temp_elem)
				{
					const char* text = temp_elem->GetText();
					if (text)
						pitch_alter = atoi(text);
				}
				temp_elem = elem->FirstChildElement("octave");
				if (temp_elem)
				{
					const char* text = temp_elem->GetText();
					if (text)
						pitch_octave = atoi(text);
				}
				note_value = noteValueForStep(pitch_step, pitch_octave, pitch_alter);
				/*
				note_value = (1+pitch_octave)*12+pitch_alter;
				if (2 == pitch_step)	note_value += 2;		//D
				else if (3 == pitch_step)	note_value += 4;		//E
				else if (4 == pitch_step)	note_value += 5;		//F
				else if (5 == pitch_step)	note_value += 7;		//G
				else if (6 == pitch_step)	note_value += 9;		//A
				else if (7 == pitch_step)	note_value += 11;	//B
				*/
			} else if (name && 0 == strcmp(name, "notations")) {
				//<slur number="1" placement="above" type="start"/>
				tinyxml2::XMLElement* slur_elem = elem->FirstChildElement("slur");
				while (slur_elem)
				{
					const char* number = slur_elem->Attribute("number");
					if (!number)
						number = "1";
					const char* placement = slur_elem->Attribute("placement");
					const char* type = slur_elem->Attribute("type");
					const char* slur_bezier_y = slur_elem->Attribute("bezier-y");
					const char* slur_default_y = slur_elem->Attribute("default-y");
					const char* slur_default_x = slur_elem->Attribute("default-x");
					if (type && (0 == strcmp(type, "start") || 0 == strcmp(type, "stop")))
					{
						xml_slurs.push_back(std::map<std::string, std::string>());
						std::map<std::string, std::string>* slur_value = &(xml_slurs.back());
						slur_value->insert(std::pair<std::string, std::string>("number", number));
						if (type)
							slur_value->insert(std::pair<std::string, std::string>("type", type));
						if (placement)
							slur_value->insert(std::pair<std::string, std::string>("placement", placement));
						if (slur_bezier_y)
							slur_value->insert(std::pair<std::string, std::string>("bezier-y", slur_bezier_y));
						if (slur_default_x)
							slur_value->insert(std::pair<std::string, std::string>("default-x", slur_default_x));
						if (slur_default_y)
							slur_value->insert(std::pair<std::string, std::string>("default-y", slur_default_y));
						std::stringstream ss;
						std::string s;
						ss << measure->notes.size();
						ss >> s;
						slur_value->insert(std::pair<std::string, std::string>("note_index", s));
						ss.clear();
						ss << measure->number;
						ss >> s;
						slur_value->insert(std::pair<std::string, std::string>("measure_index", s));
					}
					slur_elem = slur_elem->NextSiblingElement("slur");
				}
				//<tied type="start"/>
				tinyxml2::XMLElement* tied_elem = elem->FirstChildElement("tied");
				while (tied_elem)
				{
					const char* orientation = tied_elem->Attribute("orientation");
					if (!orientation)
						orientation = "over";
					const char* number = tied_elem->Attribute("number");
					if (!number)
						number = "0";
					const char* type = tied_elem->Attribute("type");
					if (type)
					{
						std::map<std::string, std::string> dict;
						dict["number"] = number;
						dict["type"] = type;
						dict["orientation"] = orientation;
						xml_ties.push_back(dict);
						if (0 == strcmp(type, "start"))
							tie_pos |= Tie_LeftEnd;
						else
							tie_pos |= Tie_RightEnd;
					}
					tied_elem = tied_elem->NextSiblingElement("tied");
				}

				tinyxml2::XMLElement* tuplet_elem = elem->FirstChildElement("tuplet");
				while (tuplet_elem)
				{
					const char* attr = nullptr;
					std::string type, show_number, number, needBracket = "0";
					attr = tuplet_elem->Attribute("type");		//start, stop
					if (attr)
						type = attr;

					attr = tuplet_elem->Attribute("show-number");
					if (attr)
						show_number = attr;

					attr = tuplet_elem->Attribute("bracket");
					if (attr && !strcmp(attr, "yes"))
						needBracket = "1";

					attr = tuplet_elem->Attribute("number");
					if (attr)
						number = attr;
					else
						number = "1";

					NoteType tuplet_type = Note_None;
					tinyxml2::XMLElement* tuplet_normal_elem = tuplet_elem->FirstChildElement("tuplet-normal");
					if (tuplet_normal_elem)
					{
						const char* tuplet_type_str = nullptr;
						tinyxml2::XMLElement* tuplet_type_elem = tuplet_normal_elem->FirstChildElement("tuplet-type");
						if (tuplet_type_elem)
							tuplet_type_str = tuplet_type_elem->GetText();
						tuplet_type = noteType(tuplet_type_str);

						std::shared_ptr<NoteArticulation> art = std::make_shared<NoteArticulation>();
						note_arts.push_back(art);
						if (Note_Eight == note_type) {
							art->art_type = Articulation_Tremolo_Eighth;
						} else if (Note_Sixteen == note_type) {
							art->art_type = Articulation_Tremolo_Sixteenth;
						} else if (Note_32 == note_type) {
							art->art_type = Articulation_Tremolo_Thirty_Second;
						} else if (Note_64 == note_type) {
							art->art_type = Articulation_Tremolo_Sixty_Fourth;
						}
						art->tremolo_stop_note_count = 1;
						art->tremolo_beem_mode = true;
						note_type = tuplet_type;
					}

					if (Note_None == tuplet_type && "stop" == type)
					{
						//analyze never read
						for (int prevN = measure->notes.size()-1; prevN >= 0; --prevN)
						{
							auto& prevNote = measure->notes[prevN];
							if (!prevNote->xml_tuplets.empty())
							{
								for (auto dict = prevNote->xml_tuplets.begin(); dict != prevNote->xml_tuplets.end(); ++dict)
								{
									std::string& prev_number = (*dict)["number"];
									std::string& prev_type = (*dict)["type"];
									if (prev_number == number && "start" == prev_type)
									{
										NoteType start_tuplet_type = static_cast<NoteType>(atoi((*dict)["tuplet-type"].c_str()));
										if (Note_None != start_tuplet_type)
											note_type = start_tuplet_type;
										break;
									}
								}
							}
						}
					}
					std::stringstream ss;
					std::string s;
					ss << tuplet_type;
					ss >> s;

					std::map<std::string, std::string> dict;
					dict["tuplet-type"] = s;
					dict["type"] = type;
					dict["number"] = number;
					dict["show-number"] = show_number;
					dict["bracket"] = needBracket;
					xml_tuplets.push_back(std::move(dict));
					tuplet_elem = tuplet_elem->NextSiblingElement("tuplet");
				}

				tinyxml2::XMLElement* articulations_elem = elem->FirstChildElement("articulations");
				if (articulations_elem)
				{
					tinyxml2::XMLElement* child_elem = articulations_elem->FirstChildElement();
					while (child_elem)
					{
						/*
						accent:     加强音（或重音）【意大利语：Marcato，意指显著 Accento】指将某一音符或和弦奏得更响、更大力，它以向右的“>”符号标示。
						strong_accent:  特加强音（或重音）【意大利语：Marcatimisso】与加强音相似，但较加强音更响，并以向上的“^”标示
						staccato:   断音（意大利语：Staccato，意指“分离”）又称跳音，特指音符短促的发音，并于音符上加上一小点表示。
						tenuto:     持续音（或保持音）【意大利语：Tenuto，意指保持】，特指将某一音符奏得比较长，也有些演译是将此音奏得比较响，其标示为一横线，位于音符上方或下方，视乎音符的方向而定。
						detached-legato:
						staccatissimo:  特断音（或顿音）（意大利语：Staccatissimo），意指把一音符弹得非常短促，程度高于断音。其标示方法为一楔形，若该音符方向向下，则楔形向下，反之亦然
						spiccato:
						scoop:
						plop:
						doit:
						alloff:
						breath-mark:
						caesura:
						stress:
						unstress:
						other-articulation
						*/
						const char* art_name = child_elem->Value();
						const char* placement = child_elem->Attribute("placement");
						std::map<std::string, ArticulationType> art_values;
						art_values["accent"]						= Articulation_Marcato;
						art_values["strong-accent"]			= Articulation_SForzando;
						art_values["staccato"]						= Articulation_Staccato;
						art_values["tenuto"]						= Articulation_Tenuto;
						art_values["detached-legato"]		= Articulation_Detached_Legato;
						art_values["staccatissimo"]			= Articulation_Staccatissimo;
						art_values["spiccato"]						= Articulation_SForzando;
						art_values["scoop"]							= Articulation_SForzando_Dot;
						art_values["plop"]							= Articulation_None;
						art_values["doit"]								= Articulation_None;
						art_values["alloff"]							= Articulation_None;
						art_values["breath-mark"]				= Articulation_None;
						art_values["caesura"]						= Articulation_None;
						art_values["stress"]							= Articulation_SForzando_Dot;
						art_values["other-articulation"]	= Articulation_None;
						ArticulationType art_type = Articulation_Major_Trill;
						if (art_name && art_values.find(art_name) != art_values.end())
							art_type = art_values[art_name];
						if (Articulation_None == art_type || Articulation_Major_Trill == art_type)
							printf("Error unknow articulations type\n");
						//check if there already have same art
						bool alreadyHave = false;
						for (auto temp_art = note_arts.begin(); temp_art != note_arts.end(); temp_art++) {
							if ((*temp_art)->art_type == art_type) {
								alreadyHave = true;
								break;
							}
						}
						//合并Articulation_Staccato+Articulation_SForzando=Articulation_SForzando_Dot
						if (Articulation_Staccato == art_type || Articulation_SForzando == art_type) {
							for (auto temp_art = note_arts.begin(); temp_art != note_arts.end(); temp_art++) {
								if ((Articulation_SForzando == (*temp_art)->art_type && Articulation_Staccato == art_type) || 
									(Articulation_Staccato == (*temp_art)->art_type && Articulation_SForzando == art_type)) {
									(*temp_art)->art_type = Articulation_SForzando_Dot;
									alreadyHave = true;
									break;
								}
							}
						}
						//合并Articulation_Marcato+Articulation_Staccato=Articulation_Marcato_Dot
						if (Articulation_Staccato == art_type || Articulation_Marcato == art_type) {
							for (auto temp_art = note_arts.begin(); temp_art != note_arts.end(); temp_art++) {
								if ((Articulation_Marcato == (*temp_art)->art_type && Articulation_Staccato == art_type) || 
									(Articulation_Staccato == (*temp_art)->art_type && Articulation_Marcato == art_type)) {
									(*temp_art)->art_type = Articulation_Marcato_Dot;
									alreadyHave = true;
									break;
								}
							}
						}

						if (!alreadyHave)
						{
							std::shared_ptr<NoteArticulation> art = std::make_shared<NoteArticulation>();
							note_arts.push_back(art);
							art->art_type = art_type;
							if (placement && 0 == strcmp(placement, "above"))
								art->art_placement_above = 1;

#if 1
							art->offset.offset_y = 0;
							art->offset.offset_x = 0;
#else
							const char* attr = child_elem->Attribute("default-x");
							if (attr)
								art->offset.offset_x = atoi(attr);
							attr = child_elem->Attribute("default-y");
							if (Articulation_Staccato == art->art_type || Articulation_Tenuto == art->art_type || Articulation_Marcato == art->art_type || Articulation_Staccatissimo == art->art_type || Articulation_SForzando == art->art_type) {
								art->offset.offset_y = 0;
								art->offset.offset_x = 0;
							} else if (attr) {
								art->offset.offset_y = atoi(attr);
							} else if (placement) {
								if (1 == art->art_placement_above)
									art->offset.offset_y += LINE_height;
								else
									art->offset.offset_y -= LINE_height;
							}
#endif
						}
						child_elem = child_elem->NextSiblingElement();
					}
				}
				/*
				<!ELEMENT ornaments
				(((trill-mark | turn | delayed-turn | inverted-turn |
				delayed-inverted-turn | vertical-turn | shake |
				wavy-line | mordent | inverted-mordent | schleifer |
				tremolo | other-ornament), accidental-mark*)*)>
				e.g.
				<ornaments>
				<tremolo default-x="-4" default-y="-40" type="single">3</tremolo>
				<tremolo type="start">3</tremolo>
				<tremolo type="stop">3</tremolo>
				</ornaments>

				<ornaments>
				<mordent default-x="-85" default-y="37" placement="above"/>
				<accidental-mark>natural</accidental-mark>
				</ornaments>

				<ornaments>
				<trill-mark default-y="10"/>
				<wavy-line default-y="10" number="1" type="start"/>
				<wavy-line number="1" relative-x="271" type="stop"/>
				</ornaments>
				*/
				tinyxml2::XMLElement* ornaments_elem = elem->FirstChildElement("ornaments");
				if (ornaments_elem)
				{
					const char* accidental_mark = nullptr;
					tinyxml2::XMLElement* accidental_mark_elem = ornaments_elem->FirstChildElement("accidental-mark");
					if (accidental_mark_elem) {
						accidental_mark = accidental_mark_elem->GetText();
					} else {
						accidental_mark_elem = elem->FirstChildElement("accidental-mark");
						if (accidental_mark_elem)
							accidental_mark = accidental_mark_elem->GetText();
					}

					std::shared_ptr<NoteArticulation> trill_art = nullptr;		//for wavy-line
					std::map<std::string, ArticulationType> ornaments_values;
					ornaments_values["tremolo"]							= Articulation_Tremolo_Eighth;
					ornaments_values["turn"]									= Articulation_Turn;
					ornaments_values["delayed-turn"]					= Articulation_Turn;
					ornaments_values["inverted-turn"]					= Articulation_Turn;
					ornaments_values["delayed-inverted-turn"]	= Articulation_Turn;
					ornaments_values["vertical-turn"]					= Articulation_Turn;
					ornaments_values["mordent"]							= Articulation_Short_Mordent;
					ornaments_values["inverted-mordent"]			= Articulation_Inverted_Short_Mordent;
					ornaments_values["other-ornament"]				= Articulation_None;
					ornaments_values["schleifer"]							= Articulation_None;
					ornaments_values["wavy-line"]							= Articulation_None;
					ornaments_values["shake"]								= Articulation_None;
					ornaments_values["trill-mark"]							= Articulation_Major_Trill;
					tinyxml2::XMLElement* ornaments_child_elem = ornaments_elem->FirstChildElement();
					while (ornaments_child_elem)
					{
						const char* art_name = ornaments_child_elem->Value();
						if (ornaments_values.find(art_name) == ornaments_values.end() || Articulation_None == ornaments_values[art_name]) {
							printf("Error unknown ornaments type=%s\n", art_name);
						} else {
							const char* placement = ornaments_child_elem->Attribute("placement");
							std::shared_ptr<NoteArticulation> art = std::make_shared<NoteArticulation>();
							note_arts.push_back(art);
							art->art_type = ornaments_values[art_name];
							const char* attr = ornaments_child_elem->Attribute("default-x");
							if (attr)
								art->offset.offset_x = atoi(attr);
							//attr = ornaments_child_elem->Attribute("default-y");
							//if (attr)
							//	art->offset.offset_y = atoi(attr);

							if (placement && 0 == strcmp(placement, "below"))
								art->art_placement_above = 1;
							if (Articulation_Tremolo_Eighth == art->art_type)
							{
								int num = 0;
								const char* text = ornaments_child_elem->GetText();
								if (text)
									num = atoi(text);
								if (2 == num) {
									art->art_type = Articulation_Tremolo_Sixteenth;
								} else if (3 == num) {
									art->art_type = Articulation_Tremolo_Thirty_Second;
								} else if (4 == num) {
									art->art_type = Articulation_Tremolo_Sixty_Fourth;
								}

								//type: single,start,stop
								const char* type = ornaments_child_elem->Attribute("type");
								if (type && !strcmp(type, "single"))
									art->tremolo_stop_note_count = 0;
								else if (type && !strcmp(type, "start"))
									art->tremolo_stop_note_count = 1;
								else
									note_arts.pop_back();
							}
							//if (has_wavy_line)
							//{
							//	art->has_wavy_line = true;
							//	art->wavy_number = wavy_num;
							//}
							if (accidental_mark)
							{
								printf("accidental_mark:%s\n", accidental_mark);
								if (0 == strcmp(accidental_mark, "natural")) {
									art->accidental_mark = Accidental_Natural;
								} else if (0 == strcmp(accidental_mark, "sharp")) {
									art->accidental_mark = Accidental_Sharp;
								} else if (0 == strcmp(accidental_mark, "flat")) {
									art->accidental_mark = Accidental_Flat;
								}
							}
							if (Articulation_Major_Trill == art->art_type)
							{
								trill_art = art;
								art->trillNoteType = Note_32;
								art->trill_interval = 1;
								art->offset.offset_y = 0;
								art->offset.offset_x = 0;
								art->trill_num_of_32nd = numOf32ndOfNoteType(note_type, dots);
							}
							if (Articulation_Short_Mordent == art->art_type || Articulation_Inverted_Short_Mordent == art->art_type)
							{
								art->offset.offset_x = 0;
								const char* isLong = ornaments_child_elem->Attribute("long");
								if (isLong && 0 == strcmp(isLong, "yes"))
									art->art_type = Articulation_Inverted_Long_Mordent;
							}
						}
						ornaments_child_elem = ornaments_child_elem->NextSiblingElement();
					}
					//check wavy-line
					bool has_wavy_line = false;
					int wavy_num = 0;
					//if (trill_art)
					{
						tinyxml2::XMLElement* wavy_line_elem = ornaments_elem->FirstChildElement("wavy-line");
						while (wavy_line_elem)
						{
							const char* attr = wavy_line_elem->Attribute("number");
							if (attr)
								wavy_num = atoi(attr);

							const char* type = wavy_line_elem->Attribute("type");
							if (type && 0 == strcmp(type, "start")) {
								has_wavy_line = true;
								if (trill_art)
								{
									trill_art->has_wavy_line = true;
									trill_art->wavy_number = wavy_num;
								}
							} else if (type && 0 == strcmp(type, "stop")) {
								int more_trill_num_of_32nd = 0;
								bool found_start_trill = false;
								if (!isGrace)
									more_trill_num_of_32nd = numOf32ndOfNoteType(note_type, dots);

								if (has_wavy_line) {
									if (trill_art) {
										trill_art->wavy_stop_measure = 0;
										trill_art->wavy_stop_note = measure->notes.size();
										trill_art->trill_num_of_32nd += more_trill_num_of_32nd;
									}
								} else {
#if 1
									//find start note
									std::shared_ptr<OveNote> trill_start_note;
									for (int mm = m_pMusicScore->measures.size()-1; mm >= 0 && !found_start_trill; --mm)
									{
										auto& temp_measure = m_pMusicScore->measures[mm];
										for (int nn = temp_measure->notes.size()-1; nn >= 0 && !found_start_trill; --nn)
										{
											auto& temp_note = temp_measure->notes[nn];
											if (temp_note->staff == staff)
											{
												for (auto temp_art = temp_note->note_arts.begin(); temp_art != temp_note->note_arts.end(); ++temp_art)
												{
													if ((*temp_art)->has_wavy_line && (*temp_art)->wavy_number == wavy_num)
													{
														nn = -1;
														mm = -1;
														found_start_trill = true;
														trill_start_note = temp_note;
														break;
													}
												}
											}
										}
									}
									if (trill_start_note)
									{
										int grace_num = 0;
										found_start_trill = false;
										more_trill_num_of_32nd = 0;
										if (voice == trill_start_note->voice)
										{
											if (isGrace)
												grace_num++;
											else
												more_trill_num_of_32nd += numOf32ndOfNoteType(note_type, dots);
										}
										for (int mm = m_pMusicScore->measures.size()-1; mm >= 0 && !found_start_trill; --mm)
										{
											auto& temp_measure = m_pMusicScore->measures[mm];
											for (int nn = temp_measure->notes.size()-1; nn >= 0 && !found_start_trill; --nn)
											{
												auto& temp_note = temp_measure->notes[nn];
												if (temp_note->staff == staff && temp_note->voice == trill_start_note->voice)
												{
													for (auto temp_art = temp_note->note_arts.begin(); temp_art != temp_note->note_arts.end(); ++temp_art)
													{
														if ((*temp_art)->has_wavy_line && (*temp_art)->wavy_number == wavy_num)
														{
															(*temp_art)->wavy_stop_measure = measure->number-mm;
															(*temp_art)->wavy_stop_note = measure->notes.size();
															(*temp_art	)->trill_num_of_32nd += more_trill_num_of_32nd-grace_num;
															nn = -1;
															mm = -1;
															found_start_trill = true;
															trill_start_note = temp_note;
															break;
														}
													}
													if (!found_start_trill)
													{
														if (temp_note->isGrace)
															grace_num++;
														else
															more_trill_num_of_32nd += numOf32ndOfNoteType(temp_note->note_type, temp_note->isDot);
													}
												}
											}
										}
									}
#else
									for (int mm = m_pMusicScore->measures.size()-1; mm >= 0 && !found_start_trill; mm--) {
										std::shared_ptr<OveMeasure>& temp_measure = m_pMusicScore->measures[mm];
										for (int nn = temp_measure->notes.size()-1; nn >= 0 && !found_start_trill; nn--)
										{
											std::shared_ptr<OveNote>& temp_note = temp_measure->notes[nn];
											if (temp_note->staff == staff) {
												for (auto temp_art = temp_note->note_arts.begin(); temp_art != temp_note->note_arts.end(); temp_art++) {
													if ((*temp_art)->has_wavy_line && (*temp_art)->wavy_number == wavy_num) {
														(*temp_art)->wavy_stop_measure = measure->number-mm;
														(*temp_art)->wavy_stop_note = measure->notes.size();
														//if (!isGrace)
														//	(*temp_art)->trill_num_of_32nd += numOf32ndOfNoteType(note_type, dots);
														(*temp_art)->trill_num_of_32nd += more_trill_num_of_32nd;
														nn = -1;
														mm = -1;
														found_start_trill = true;
														break;
													}
												}
												if (!found_start_trill && !temp_note->isGrace)
													more_trill_num_of_32nd += numOf32ndOfNoteType(temp_note->note_type, temp_note->isDot);
											}
										}
									}
#endif
								}
							}
							wavy_line_elem = wavy_line_elem->NextSiblingElement("wavy-line");
						}
					}
				}
				/*
				//arpeggiate_position
				//<arpeggiate default-x="-20" number="1" voice="1" staff="1" />
				staff=m, 这个琶音跨越m个staff
				voice=n, 这个琶音延长到第m个staff里，跨越n个声部。
				*/
				tinyxml2::XMLElement* arpeggiate_elem = elem->FirstChildElement("arpeggiate");
				if (arpeggiate_elem)
				{
					std::shared_ptr<NoteArticulation> art = std::make_shared<NoteArticulation>();
					note_arts.push_back(art);
					art->art_type = Articulation_Arpeggio;
					const char* attr = arpeggiate_elem->Attribute("default-x");
					if (attr)
						art->offset.offset_x = atoi(attr);
					attr = arpeggiate_elem->Attribute("default-y");
					if (attr)
						art->offset.offset_y = atoi(attr);

					const char* num = arpeggiate_elem->Attribute("voice");
					if (num)
						art->arpeggiate_over_voice = atoi(num);
					num = arpeggiate_elem->Attribute("staff");
					if (num)
						art->arpeggiate_over_staff = atoi(num);
				}

				tinyxml2::XMLElement* technical_elem = elem->FirstChildElement("technical");
				if (technical_elem)
				{
					tinyxml2::XMLElement* technical_child_elem = technical_elem->FirstChildElement();
					while (technical_child_elem)
					{
						const char* art_name = technical_child_elem->Value();
						if (art_name && 0 == strcmp(art_name, "fingering"))
						{
							const char* placement = technical_child_elem->Attribute("placement");
							const char* finger_text = technical_child_elem->GetText();

							std::shared_ptr<NoteArticulation> art = std::make_shared<NoteArticulation>();
							art->art_type = Articulation_Finger;
							if (finger_text)
								art->finger = finger_text;
							art->art_placement_above = (placement && 0 == strcmp(placement, "above")) ? 1 : 0;

							const char* attr = technical_child_elem->Attribute("default-x");
							if (attr)
								art->offset.offset_x = atoi(attr);
							//if (art->offset.offset_x > 6) {
							//	art->offset.offset_x = 6;
							//} else if (art->offset.offset_x < -6) {
							//	art->offset.offset_x = -6;
							//}
							const char* default_y = technical_child_elem->Attribute("default-y");
							if (!default_y)
								default_y = "0";
							/*
							int offset_y = 0;
							for (std::list<NoteArticulation*>::iterator item = note_arts.begin(); item != note_arts.end(); item++)
								if ((*item)->art_placement_above == art->art_placement_above && Articulation_Finger == (*item)->art_type)
									offset_y += (*item)->offset.offset_y;
							if (art->art_placement_above)
								art->offset.offset_y = atoi(default_y)+offset_y;
							else
								art->offset.offset_y = -atoi(default_y)-offset_y;
							*/
							art->offset.offset_y = atoi(default_y);
							xml_fingers.push_back(art);
						}
						technical_child_elem = technical_child_elem->NextSiblingElement();
					}
				}

				//fermata:延音：朝下的一个小括号里面加一个点
				//<fermata default-x="-5" default-y="31" type="upright"/>
				tinyxml2::XMLElement* fermata_elem = elem->FirstChildElement("fermata");
				if (fermata_elem)
				{
					std::shared_ptr<NoteArticulation> art = std::make_shared<NoteArticulation>();
					note_arts.push_back(art);
					art->art_type = Articulation_Fermata;

					const char* default_x_str = fermata_elem->Attribute("default-x");
					const char* default_y_str = fermata_elem->Attribute("default-y");
					if (default_x_str)
						art->offset.offset_x = atoi(default_x_str);

					const char* fermata_type = fermata_elem->Attribute("type");		//upright | inverted
					if (fermata_type && 0 == strcmp(fermata_type, "upright")) {
						art->art_placement_above = 1;
						if (default_y_str) {
							art->offset.offset_y = atoi(default_y_str)-2*LINE_height;
							if (art->offset.offset_y < 2*LINE_height)
								art->offset.offset_y = 2*LINE_height;
						}
					} else {
						art->art_type = Articulation_Fermata_Inverted;
						if (default_y_str) {
							art->offset.offset_y = -atoi(default_y_str)-2*LINE_height;
							if (art->offset.offset_y < 2*LINE_height)
								art->offset.offset_y = 2*LINE_height;
						}
					}
				}
			} else if (name && 0 == strcmp(name, "lyric")) {
				tinyxml2::XMLElement* lyric_elem = elem;
				xml_lyrics.push_back(std::map<std::string, std::string>());
				std::map<std::string, std::string>& lyric = xml_lyrics.back();
				/*
				<lyric default-y="-80" number="1" relative-x="9">//歌词
				<syllabic>single</syllabic>//音节的:"single", "begin", "end", or "middle"
				<text>1.</text>
				<elision> </elision> //元音
				<syllabic>single</syllabic>
				<text>Should</text>
				</lyric>
				*/
				const char* syllabic = nullptr;
				tinyxml2::XMLElement* temp_elem = lyric_elem->FirstChildElement("syllabic");
				if (temp_elem)
					syllabic = temp_elem->GetText();
				if (syllabic)
					lyric["syllabic"] = syllabic;
				int number = 0;
				const char* attr = lyric_elem->Attribute("number");
				if (attr)
					number = atoi(attr);
				if (number < 1)
					number = 1;
				std::stringstream ss;
				std::string s;
				ss << number;
				ss >> s;
				lyric["number"] = s;

				int offset_x, offset_y = offset_x = 0;
				attr = lyric_elem->Attribute("default-y");
				if (attr)
					offset_y = atoi(attr);
				attr = lyric_elem->Attribute("relative-x");
				if (attr)
					offset_x = atoi(attr);
				ss.clear();
				ss << offset_x;
				ss >> s;
				lyric["offset_x"] = s;
				ss.clear();
				ss << offset_y;
				ss >> s;
				lyric["offset_y"] = s;

				std::string lyric_text = "";
				tinyxml2::XMLElement* child_elem = lyric_elem->FirstChildElement();
				while (child_elem)
				{
					const char* name = child_elem->Value();
					if (name && (0 == strcmp(name, "text") || 0 == strcmp(name, "elision")))
					{
						const char* tmp = child_elem->GetText();
						std::string tmp_str = "";
						if (tmp)
							tmp_str = tmp;
						lyric_text += tmp_str;
					}
					child_elem = child_elem->NextSiblingElement();
				}
				if (!lyric_text.empty())
					lyric["text"] = lyric_text;
			} else if (name && 0 == strcmp(name, "time-modification")) {
				const char* time_modification;
				tinyxml2::XMLElement* temp_elem = elem->FirstChildElement("actual-notes");
				if (temp_elem)
					time_modification = temp_elem->GetText();
			} else if (name && 0 == strcmp(name, "instrument")) {
				///...
			} else if (name && 0 == strcmp(name, "tie")) {
				///...
			} else {
				printf("Unknown tag \"%s\" in <note>\n", name);
			}
			elem = elem->NextSiblingElement();
		}

		std::shared_ptr<OveNote> note = std::make_shared<OveNote>();
		note->staff = staff+start_staff;
		note->voice = voice;
		note->isDot = dots;
		note->isGrace = isGrace;
		note->inBeam = inBeam;
		note->isRest = isRest;
		note->stem_up = stem_up;
		if (Note_None == note_type)
		{
			if (duration == last_divisions*last_numerator*4/last_denominator) {
				note_type = Note_Whole;
			} else if (duration > 0) {
				int type = (last_divisions*4)/duration;
				switch (type)
				{
				case 1 :		note_type = Note_Whole;		break;
				case 2 :		note_type = Note_Half;			break;
				case 4 :		note_type = Note_Quarter;	break;
				case 8 :		note_type = Note_Eight;		break;
				case 16 :		note_type = Note_Sixteen;	break;
				case 64 :		note_type = Note_64;				break;
				case 128 :	note_type = Note_128;			break;
				case 256 :	note_type = Note_256;			break;
				default:
					printf("Error unknown rest type=(%d)/(%d)\n", duration, last_divisions);
					break;
				}
			}
		}
		note->note_type = note_type;
		note->xml_stem_default_y = stem_default_y;
		if (0 == pitch_octave) {
			note->line = 0;
		} else if (isRest) {
			ClefType clefType;
			if (note->pos.tick >= last_clefs_tick[note->staff-1]) {
				clefType = last_clefs[note->staff-1];
			} else {
				clefType = measure_start_clefs[note->staff-1];
			}
			if (Clef_Treble == clefType) {
				note->line = (pitch_step-7)+7*(pitch_octave-4);
			} else {
				note->line = 5+(pitch_step-7)+7*(pitch_octave-3);
			}
			if (0 == note->line)
				note->line = 1;
		}

		note->pos.tick = tick;
		note->pos.start_offset = start_offset;
		note->xml_duration = duration;
		if (!xml_slurs.empty())
			note->xml_slurs.insert(note->xml_slurs.begin(), xml_slurs.begin(), xml_slurs.end());
		if (!note_arts.empty())
			note->note_arts.insert(note->note_arts.begin(), note_arts.begin(), note_arts.end());
		if (!xml_lyrics.empty())
			note->xml_lyrics.insert(note->xml_lyrics.begin(), xml_lyrics.begin(), xml_lyrics.end());
		if (!xml_beams.empty())
			note->xml_beams.insert(xml_beams.begin(), xml_beams.end());
		note->xml_tuplets = xml_tuplets;
		//note->xml_have_tuplets = have_tuplets;

		std::shared_ptr<NoteElem> noteElem;
		if (!isRest)
		{
			if (!noteElem)
			{
				noteElem = std::make_shared<NoteElem>();
				note->note_elems.push_back(noteElem);
			}
			if (accidental)
			{
				//accidental: sharp(升半音), flat(降半音), natural(还原), double-sharp, sharp-sharp, flat-flat, natural-sharp, natural-flat, quarter-flat, quarter-sharp, three- quarters-flat, and three-quarters-sharp
				std::map<std::string, AccidentalType> accidental_values;
				accidental_values["sharp"]								= Accidental_Sharp;
				accidental_values["flat"]									= Accidental_Flat;
				accidental_values["natural"]							= Accidental_Natural;
				accidental_values["double-sharp"]				= Accidental_DoubleSharp;
				accidental_values["sharp-sharp"]					= Accidental_Sharp_Caution;
				accidental_values["flat-flat"]							= Accidental_DoubleFlat;
				accidental_values["natural-sharp"]				= Accidental_Sharp_Caution;
				accidental_values["natural-flat"]					= Accidental_Flat_Caution;
				accidental_values["quarter-flat"]					= Accidental_Flat;
				accidental_values["three-quarters-flat"]		= Accidental_Flat;
				accidental_values["three-quarters-sharp"]	= Accidental_Sharp;
				std::map<std::string, AccidentalType>::iterator it = accidental_values.find(accidental);
				if (it != accidental_values.end())
					noteElem->accidental_type = accidental_values[accidental];
				else
					noteElem->accidental_type = Accidental_Normal;
			}
			/*
			下表列出的是与音符相对应的命令标记。
			八度音阶||                    音符号
			#  ||
				||  C  | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
			-----------------------------------------------------------------------------
			0  ||   0 |   1 |   2 |   3 |   4 |   5 |   6 |   7 |   8 |   9 |  10 | 11
			0  ||  12 |  13 |  14 |  15 |  16 |  17 |  18 |  19 |  20 |  21 |  22 | 23
			1  ||  24 |  25 |  26 |  27 |  28 |  29 |  30 |  31 |  32 |  33 |  34 | 35
			2  ||  36 |  37 |  38 |  39 |  40 |  41 |  42 |  43 |  44 |  45 |  46 | 47
			3  ||  48 |  49 |  50 |  51 |  52 |  53 |  54 |  55 |  56 |  57 |  58 | 59
			4  ||  60 |  61 |  62 |  63 |  64 |  65 |  66 |  67 |  68 |  69 |  70 | 71
			5  ||  72 |  73 |  74 |  75 |  76 |  77 |  78 |  79 |  80 |  81 |  82 | 83
			6  ||  84 |  85 |  86 |  87 |  88 |  89 |  90 |  91 |  92 |  93 |  94 | 95
			7  ||  96 |  97 |  98 |  99 | 100 | 101 | 102 | 103 | 104 | 105 | 106 | 107
			8  || 108 | 109 | 110 | 111 | 112 | 113 | 114 | 115 | 116 | 117 | 118 | 119
			9  || 120 | 121 | 122 | 123 | 124 | 125 | 126 | 127 |
			*/
			noteElem->note = note_value;
			noteElem->line = note->line;
			noteElem->tie_pos = tie_pos;
			noteElem->velocity = 70;
			if (!xml_ties.empty())
				noteElem->xml_ties.insert(noteElem->xml_ties.begin(), xml_ties.begin(), xml_ties.end());
			noteElem->length_tick = note->xml_duration*480/last_divisions;
			noteElem->xml_pitch_octave = pitch_octave;
			noteElem->xml_pitch_step = pitch_step;
			noteElem->xml_pitch_alter = pitch_alter;
		}
		return note;
	}
	return nullptr;
}

bool MusicXMLParser::parseAttributes(tinyxml2::XMLElement* attributes_elem, std::shared_ptr<OveMeasure>& measure, int start_staff, std::shared_ptr<OveNote> afterNote, int tick)
{
	if (!attributes_elem || !measure)
		return false;

	int divisions = 0;
	if (attributes_elem)
	{
		tinyxml2::XMLElement* divisions_elem = attributes_elem->FirstChildElement("divisions");
		if (divisions_elem)
		{
			const char* text = divisions_elem->GetText();
			if (text)
				divisions = atoi(text);
			last_divisions = divisions;
			measure->xml_division = last_divisions;
		}
		tinyxml2::XMLElement* key_elem = attributes_elem->FirstChildElement("key");
		if (key_elem)
		{
			const char* key_mode = nullptr;
			int fifths = last_key_fifths;
			tinyxml2::XMLElement* temp_elem = key_elem->FirstChildElement("fifths");
			if (temp_elem)
			{
				const char* text = temp_elem->GetText();
				if (text)
					fifths = atoi(text);
			}
			temp_elem = key_elem->FirstChildElement("mode");
			if (temp_elem)
				key_mode = temp_elem->GetText();
			if (key_mode && 0 == strcmp(key_mode, "minor"))
				//fifths *= -1;
			if (measure->number > 0 && fifths != last_key_fifths)
			{
				measure->key.key = fifths;
				measure->key.previousKey = last_key_fifths;
			}
			last_key_fifths = fifths;
		}
		tinyxml2::XMLElement* time_elem = attributes_elem->FirstChildElement("time");
		if (time_elem)
		{
			const char* text = nullptr;
			tinyxml2::XMLElement* temp_elem = time_elem->FirstChildElement("beats");
			if (temp_elem)
			{
				text = temp_elem->GetText();
				if (text)
					last_numerator = atoi(text);
			}
			temp_elem = time_elem->FirstChildElement("beat-type");
			if (temp_elem)
			{
				text = temp_elem->GetText();
				if (text)
					last_denominator = atoi(text);
			}
		}
		tinyxml2::XMLElement* staves_elem = attributes_elem->FirstChildElement("staves");
		if (staves_elem)
		{
			const char* text = staves_elem->GetText();
			if (text)
				part_staves = atoi(text);
		}

		int clef_index = start_staff;
		tinyxml2::XMLElement* clef_elem = attributes_elem->FirstChildElement("clef");
		while (clef_elem)
		{
			const char* clef_sign = nullptr;
			int clef_line = 0, clef_number = 0;
			//<clef number="1">
			const char* attr = clef_elem->Attribute("number");
			if (attr)
				clef_number = atoi(attr);
			if (clef_number > 0)
				clef_index = start_staff+clef_number-1;

			//Sign values include G, F, C, percussion, TAB, jianpu, and none
			tinyxml2::XMLElement* temp_elem = clef_elem->FirstChildElement("sign");
			if (temp_elem)
				clef_sign = temp_elem->GetText();
			temp_elem = clef_elem->FirstChildElement("line");
			if (temp_elem)
			{
				const char* text = temp_elem->GetText();
				if (text)
					clef_line = atoi(text);
			}

			ClefType clefType;
			if (clef_sign && 0 == strcmp(clef_sign, "G") && 2 == clef_line)
				clefType = Clef_Treble;
			else if (clef_sign && 0 == strcmp(clef_sign, "F") && 4 == clef_line)
				clefType = Clef_Bass;
			else if (clef_sign && 0 == strcmp(clef_sign, "C") && 3 == clef_line)
				clefType = Clef_Alto;
			else if (clef_sign && 0 == strcmp(clef_sign, "percussion"))
				clefType = Clef_Percussion1;
			else if (clef_sign && 0 == strcmp(clef_sign, "TAB"))
				clefType = Clef_TAB;
			else
				clefType = Clef_Bass;

			if (afterNote || (last_clefs[clef_index] != clefType && measure->number > 0)) {
				std::shared_ptr<MeasureClef> clef = std::make_shared<MeasureClef>();
				measure->clefs.push_back(clef);
				clef->clef = clefType;
				clef->staff = clef_index+1;
				clef->xml_note = measure->notes.size();
#if 0
				if (afterNote && afterNote->staff == clef->staff) {
					clef->pos.tick = afterNote->pos.tick;
					last_clefs_tick[clef_index] = clef->pos.tick;
				} else {
					measure_start_clefs[clef_index] = clefType;
					clef->pos.tick = 0;
					last_clefs_tick[clef_index] = 0;
				}
#else
				if (afterNote && afterNote->staff == clef->staff) {
					clef->pos.tick = afterNote->pos.tick;
				} else if (tick > 0) {
					clef->xml_note = -1;
					clef->pos.tick = tick-1;
				} else {
					measure_start_clefs[clef_index] = clefType;
					clef->pos.tick = 0;
				}
				last_clefs_tick[clef_index] = clef->pos.tick;
#endif
			} else {
				measure_start_clefs[clef_index] = clefType;
			}
			last_clefs[clef_index] = clefType;
			clef_elem = clef_elem->NextSiblingElement("clef");
			clef_index++;
		}
	}
	return true;
}