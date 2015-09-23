#include "ParseExport.h"

#define R_BUF(buf, len)	\
{	\
	if (len+buf_index > nBufLen) return 0;	\
	memcpy(buf, buffer+buf_index, len);		\
	buf_index += len;		\
}

int MidiFileSerialize::ReadMidiFile(const char* pFileName, int nFileSize, unsigned char* pMidiFileBuffer)
{
	if (!pFileName || nFileSize <= 0 || !pMidiFileBuffer)
		return -1;

	FILE* pFile = fopen(pFileName, "rb");
	if (!pFile)
		return -2;

	int szRead = fread(pMidiFileBuffer, 1, nFileSize, pFile);
	if (szRead != nFileSize)
		return -3;

	fclose(pFile);
	return 0;
}

MidiFile* MidiFileSerialize::loadFromFile(const char* file)
{
	if (!file)
		return NULL;

	int nFileSize = GetFileSize(file);
	if (nFileSize <= 0)
		return NULL;

	unsigned char* pMidiFileBuffer = new unsigned char[nFileSize];
	if (!pMidiFileBuffer) {
		return NULL;
	} else {
		int sts = ReadMidiFile(file, nFileSize, pMidiFileBuffer);
		if (sts)
		{
			delete []pMidiFileBuffer;
			return NULL;
		}
	}

	buf_index = 0;
	if (midi_)
	{
		delete midi_;
		midi_ = NULL;
	}

	MidiFile* midi = load(pMidiFileBuffer, nFileSize);
	delete []pMidiFileBuffer;
	midi->strFileName = file;
	midi->strFileName.replace(midi->strFileName.rfind("."), strlen(".mid"), "");
	midi->mergedMidiEvents();
	return midi;
}

// int <-> word
unsigned int MidiFileSerialize::create_midi_int(unsigned char* p)
{
	unsigned int i, num = 0;
	const unsigned int SIZE = 4;
	for (i = 0; i < SIZE; i++)
		num = (num << 8)+*(p+i);
	return num;
}

//unsigned char a[2] -> word
unsigned short MidiFileSerialize::create_word(unsigned char* p)
{
	unsigned short num = 0;
	num = (*p)<<8;
	num += *(p+1);
	return num;
}

bool MidiFileSerialize::readTrackData(ITrack* track, unsigned char* buffer, int nBufLen)
{
	unsigned int len = 0;
	Chunk chunk;

	R_BUF(&chunk, sizeof(chunk));
	if (0 != memcmp(chunk.id_, "MTrk", 4))
		return false;

	len = create_midi_int(chunk.size_);
	if (len+buf_index > nBufLen)
		return false;

	unsigned char* buff = buffer+buf_index;
	buf_index += len;
	if (!parseMidiEvent(buff, len, track))
		return false;
	return true;
}

bool MidiFileSerialize::parseMidiEvent(unsigned char* data, int size, ITrack* track)
{
	unsigned int tick = 0;
	unsigned char* p, *buff;
	unsigned char pre_ctrl = 0;

	p = data;
	buff = p;

	while (p-buff < size)
	{
		int t = 0, offset;
		unsigned char ch;

		offset = parseDeltaTime(p, &t);
		if (-1 == offset)
			return false;

		tick += t;
		p += offset;
		ch = *p;
		if (0xFF == ch)		//meta event 用来表示象 track 名称、歌词、提示点等
			offset = parseMetaEvent(p, tick, track);
		else if (0xF0 == ch || 0xF7 == ch)		//sys exclusive event 系统高级消息
			offset = parseSystemExclusiveEvent(p, tick);
		else		//channel event
			offset = parseChannelEvent(p, &pre_ctrl, tick, track);
		p += offset;
	}
	return true;
}

int MidiFileSerialize::parseDeltaTime(unsigned char* p, int* time)
{
	unsigned int i, j;
	unsigned char ch;
	unsigned int MAX = 5;

	for (i = 0; i < MAX; i++)
	{
		ch = *(p+i);
		if (!(ch & 0x80))
			break;
	}

	if (i != MAX)
	{
		*time = 0;
		for (j = 0; j < i+1; j++)
		{
			ch = *(p+j);
			*time = ((*time) << 7)+(ch & 0x7F);
		}
		return i+1;
	}
	return -1;
}

int MidiFileSerialize::parseMetaEvent(unsigned char* p, int tick, ITrack* track)
{
	char ch = 0;
	int len = 0, ret = 0;

	p++;		//0xFF
	ch = *p++;

	ret = parseDeltaTime(p, &len);
	if (-1 == ret)
		return false;
	p += ret;

	switch(ch)
	{
	case 0x00:		//FF 00 02 ss ss: 音序号
		{
			break;
		}
	case 0x01:		//文本事件：用来注释 track 的文本
		{
			TextEvent event;
			event.tick = tick;
			event.text = std::string(p, p+len);
			track->texts.push_back(event);
			break;
		}
	case 0x02:		//版权声明： 这个是制定的形式“(C) 1850 J.Strauss”
		{
			midi_->copyright = std::string(p, p+len);
			break;
		}
	case 0x03:		// 音序或 track 的名称。
		{
			track->name = std::string(p, p+len);
			break;
		}
	case 0x04:		//乐器名称
		{
			track->instrument = std::string(p, p+len);
			break;
		}
	case 0x05:		//歌词
		{
			TextEvent event;
			event.tick = tick;
			event.text = std::string(p, p+len);
			track->lyrics.push_back(event);
			break;
		}
	case 0x06:		//标记（如：“诗篇1”）
		{
			TextEvent event;
			event.tick = tick;
			event.text = std::string(p, p+len);
			midi_->markers.push_back(event);
			break;
		}
	case 0x07:		//暗示： 用来表示舞台上发生的事情。如：“幕布升起”、“退出，台左”等。
		{
			TextEvent event;
			event.tick = tick;
			event.text = std::string(p, p+len);
			midi_->cuePoints.push_back(event);
			break;
		}
	case 0x2f:		//Track 结束
		{
			break;
		}
	case 0x51:		//拍子:1/4音符的速度，用微秒表示。如果没有指出，缺省的速度为 120拍/分。这个相当于 tttttt = 500,000。
		{
			TempoEvent event;
			event.tick = tick;
			event.tempo = 0;

			int tempo = *p++;
			event.tempo |= tempo << 16;
			tempo = *p++;
			event.tempo |= tempo << 8;
			tempo = *p;
			event.tempo |= tempo;
			midi_->tempos.push_back(event);
			break;
		}
	case 0x58:		//拍子记号: 如： 6/8 用 nn=6，dd=3 (2^3)表示。
		{
			TimeSignatureEvent event;
			event.tick = tick;
			event.numerator = *p++;					//分子
			event.denominator = *p++;				//分母表示为 2 的（dd次）冥
			event.number_ticks = *p++;				//每个 MIDI 时钟节拍器的 tick 数目
			event.number_32nd_notes = *p;		//24个MIDI时钟中1/32音符的数目（8是标准的）
			event.denominator = (int)pow((float)2, event.denominator);
			midi_->timeSignatures.push_back(event);
			break;
		}
	case 0x59:		//音调符号:0 表示 C 调，负数表示“降调”，正数表示“升调”。
		{
			KeySignatureEvent event;
			event.tick = tick;
			event.sf = *p++;		//升调或降调值  -7 = 7 升调,  0 =  C 调,  +7 = 7 降调
			event.mi = *p;			//0 = 大调, 1 = 小调
			midi_->keySignatures.push_back(event);
			break;
		}
	case 0x7f:		//音序器描述  Meta-event
		{
			SpecificInfoEvent event;
			event.tick = tick;
			event.infos = std::vector<unsigned char>(p, p+len);
			track->specificEvents.push_back(event);
			break;
		}
	default:
		{
			break;
		}
	}
	return len+ret+2;
}

//系统高级消息
int MidiFileSerialize::parseSystemExclusiveEvent(unsigned char* p, int tick)
{
	int offset, len = offset = 0;
	SysExclusiveEvent sys_event;
	sys_event.tick = tick;
	sys_event.event.push_back(*p++);
	offset = parseDeltaTime(p, &len);
	p += offset;
	for (int i = 0; i < len; i++)
		sys_event.event.push_back(*p++);
	midi_->sysExclusives.push_back(sys_event);
	return len+offset+1;
}

int MidiFileSerialize::parseChannelEvent(unsigned char* p, unsigned char* pre_ctrl, int tick, ITrack* track)
{
	int len = 0;
	unsigned char ch = 0;
	unsigned int temp = 0;

	Event event;
	event.tick = tick;
	ch = *p;
	if (ch & 0x80) {
		temp = *p++;
		*pre_ctrl = ch;
		len++;
	} else {
		temp = *pre_ctrl;
		ch = *pre_ctrl;
	}
	event.evt = ch;
	ch &= 0xF0;

	switch(ch)
	{
	case 0x80:		//音符关闭 (释放键盘) 音符:00~7F 力度:00~7F
	case 0x90:		//音符打开 (按下键盘) 音符:00~7F 力度:00~7F
	case 0xa0:		//触摸键盘以后  音符:00~7F 力度:00~7F
	case 0xb0:		//控制器  控制器号码:00~7F 控制器参数:00~7F
	case 0xe0:		//滑音 音高(Pitch)低位:Pitch mod 128  音高高位:Pitch div 128
		{
			len += 2;
			temp = *p++;
			event.nn = temp;
			temp = *p;
			event.vv = temp;
			//change 0x90 nn 0 -> 0x80 nn 0
			if (event.vv == 0 && 0x90 == (event.evt & 0xF0))
				event.evt = 0x80 | (event.evt & 0x0F);
			break;
		}
	case 0xc0:		//切换音色： 乐器号码:00~7F
	case 0xd0:		//通道演奏压力（可近似认为是音量） 值:00~7F
		{
			len += 1;
			temp = *p;
			event.nn = temp;
			break;
		}
	default:
		{
			break;
		}
	}
	track->events.push_back(event);
	return len;
}

void MidiFileSerialize::parseHeadInfo(ITrack* track)
{
	if (!midi_)
		return;
	midi_->name = track->name;
	if (!track->texts.empty())
		midi_->author = track->texts.front().text;
}

MidiFile* MidiFileSerialize::load(unsigned char* buffer, int nBufLen)
{
	bool ret = false;
	int fmt;
	unsigned int track_cnt;
	unsigned char word[2];
	Chunk chunk;

	midi_ = new MidiFile();
	buf_index = 0;

	do {
		R_BUF(&chunk, sizeof(chunk));
		//printf("%c%c%c%c, %02x %02x %02x %02x\n", chunk.id_[0], chunk.id_[1], chunk.id_[2], chunk.id_[3], chunk.size_[0], chunk.size_[1], chunk.size_[2], chunk.size_[3]);

		if (memcmp(chunk.id_, "MThd", 4) != 0) {
			if (create_midi_int(chunk.size_) != 0)
				break;
		}

		R_BUF(word, 2);		//format
		fmt = create_word(word);
		midi_->format = fmt;
		//printf("format=%d, fmt=%d\n", midi_->format, fmt);

		R_BUF(word, 2);		//track count
		track_cnt = create_word(word);
		
		R_BUF(word, 2);		//delta time
		midi_->quarter = create_word(word);

		if (0 == fmt) {
			ITrack track;
			if (!readTrackData(&track, buffer, nBufLen))
				break;
			parseHeadInfo(&track);
			midi_->tracks.push_back(track);
			ret = true;
		} else if (1 == fmt) {
			for (size_t i = 0; i < track_cnt; i++)
			{
				ITrack track;
				if (!readTrackData(&track, buffer, nBufLen))
					break;

				if (0 != i || !track.events.empty() || track_cnt <= 2)
					midi_->tracks.push_back(track);
				else
					parseHeadInfo(&track);
			}
			ret = true;
		}
	} while(0);

	//set track id for each event
	for (int t = 0; t < midi_->tracks.size(); ++t) {
		ITrack& track = midi_->tracks[t];
		for (int e = 0; e < track.events.size(); ++e) {
			Event& event = track.events[e];
			event.track = t;
		}
	}

	if (ret)
		return midi_;
	else
		return NULL;
}