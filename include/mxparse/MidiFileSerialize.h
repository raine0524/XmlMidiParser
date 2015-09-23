#ifndef	MIDIFILESERIALIZE_H_
#define	MIDIFILESERIALIZE_H_

typedef struct tagChunk {
	unsigned char id_[4];
	unsigned char size_[4];

	tagChunk()
	{
		memset(this, 0, sizeof(tagChunk));
	}
} Chunk;

class PARSE_DLL MidiFileSerialize
{
private:
	int buf_index;
	MidiFile* midi_;

	int ReadMidiFile(const char* pFileName, int nFileSize, unsigned char* pMidiFileBuffer);

	unsigned int create_midi_int(unsigned char* p);
	unsigned short create_word(unsigned char* p);

	bool readTrackData(ITrack* track, unsigned char* buffer, int nBufLen);
	bool parseMidiEvent(unsigned char* data, int size, ITrack* track);
	int parseDeltaTime(unsigned char* p, int* time);
	int parseMetaEvent(unsigned char* p, int tick, ITrack* track);
	int parseSystemExclusiveEvent(unsigned char* p, int tick);
	int parseChannelEvent(unsigned char* p, unsigned char* pre_ctrl, int tick, ITrack* track);
	void parseHeadInfo(ITrack* track);

	MidiFile* load(unsigned char* buffer, int nBufLen);

public:
	MidiFileSerialize() : buf_index(0), midi_(NULL) {}
	~MidiFileSerialize()
	{
		if (midi_)
		{
			delete midi_;
			midi_ = NULL;
		}
	}

	MidiFile* loadFromFile(const char* file);
};

#endif		//MIDIFILESERIALIZE_H_