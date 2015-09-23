#include "ParseExport.h"

/*
MIDI实例
1. 文件头　　
 4d 54 68 64 // “MThd”
 00 00 00 06 // 长度always 6，后面有6个字节的数据
 00 01 // 0－单轨; 1－多规，同步; 2－多规，异步
 00 02 // 轨道数，即为”MTrk”的个数
 00 c0 // 基本时间格式，即一个四分音符的tick数，tick是MIDI中的最小时间单位
2. 全局轨
 4d 54 72 6b // “MTrk”，全局轨为附加信息(如标题版权速度和系统码(Sysx)等)
 00 00 00 3d // 长度
 
 00 ff 03 // 音轨名称
 05 // 长度
 54 69 74 6c 65 // “Title”
 
 00 ff 02 // 版权公告
 0a // 长度
 43 6f 6d 70 6f 73 65 72 20 3a // “Composer :”
 　　
 00 ff 01 // 文字事件
 09 // 长度
 52 65 6d 61 72 6b 73 20 3a // “Remarks :”
 
 00 ff 51 // 设定速度xx xx xx，以微秒(us)为单位，是四分音符的时值. 如果没有指出，缺省的速度为 120拍/分
 03 // 长度
 07 a1 20 // 四分音符为 500,000 us，即 0.5s
 
 00 ff 58 // 拍号标记
 04 // 长度
 04 02 18 08 // nn dd cc bb 拍号表示为四个数字。nn和dd代表分子和分母。分母指的是2的dd次方，例如，2代表4，3代表8。cc代表一个四分音符应该占多少个MIDI时间单位，bb代表一个四分音符的时值等价于多少个32分音符。 因此，完整的 6 / 8拍号应该表示为 FF 58 04 06 03 24 08 。这是， 6 / 8拍号（ 8等于2的三次方，因此，这里是06 03），四分音符是32个MIDI时间间隔（十六进制24即是32），四分音符等于8个三十二分音符。
 
 00 ff 59 // 谱号信息
 02 // 长度
 00 00 // sf mf 。sf指明乐曲曲调中升号、降号的数目。例如，A大调在五线谱上注了三个升号，那么sf=03。又如，F大调，五线谱上写有一个降号，那么sf=81。也就是说，升号数目写成0x，降号数目写成8x 。mf指出曲调是大调还是小调。大调mf=00，小调mf=01。
 00 ff 2f 00 // 音轨终止
3. 普通音轨　　
 4d 54 72 6b // “MTrk”，普通音轨
 00 00 01 17 // 长度
 　　
 00 ff 03 // 00: delta_time; ff 03:元事件，音轨名称
 06 // 长度
 43 20 48 61 72 70 // “C Harp”
 
 00 b0 00 00 // 00:delta_time; bn:设置n通道控制器; xx:控制器编号; xx:控制器值。此处为设置0通道0号控制器值为0。
 00 b0 20 00 // 此处为设置0通道32号控制器值为0。
 00 c0 16    // 00:delta_time; cn:设置n通道音色; xx:音色值。此处为设置0通道音色值为22 Accordion 手风琴。
 84 40 b0 65 00 // 84 40:delta_time; 此处为设置0通道101号控制器值为0。
 00 b0 64 00 // 此处为设置0通道100号控制器值为0。
 00 b0 06 18 // 此处为设置0通道6号控制器值为0。
 00 b0 07 7e // 此处为设置0通道7号控制器(主音音量)值为126。
 00 e0 00 40 // 00:delta_time; en:设置n通道音高; xx yy:各取低7bit组成14bit值。此处为设置0通道音高值为64。
 00 b0 0a 40 // 此处为设置0通道7号控制器(主音音量)值为126。
 
 00 90 43 40 // 00:delta_time; 9n:打开n通道发音; xx yy: 第一个数据是音符代号。有128个音，对MIDI设备，编号为0至127个（其中中央C音符代号是60）。 第二个数据字节是速度，从0到127的一个值。这表明，用多少力量弹奏。 一个速度为零的开始发声信息被认为，事实上的一个停止发声的信息。此处为以64力度发出67音符。
 81 10 80 43 40 // 81 10:delta_time; 8n:关闭n通道发音; xx yy: 第一个数据是音符代号。有128个音，对MIDI设备，编号为0至127个（其中中央C音符代号是60）。 第二个数据字节是速度，从0到127的一个值。这表明，用多少力量弹奏。 一个速度为零的开始发声信息被认为，事实上的一个停止发声的信息。此处为以64力度关闭67音符。
 00 90 43 40
 30 80 43 40
 00 90 45 40
 81 40 80 45 40
 00 90 43 40
 81 40 80 43 40
 00 90 48 40
 81 40 80 48 40
 00 90 47 40
 　　83 00 80 47 40
 　　00 90 43 40
 　　81 10 80 43 40
 　　00 90 43 40
 　　30 80 43 40
 　　00 90 45 40
 　　81 40 80 45 40
 　　00 90 43 40
 　　81 40 80 43 40
 　　00 90 4a 40
 　　81 40 80 4a 40
 　　00 90 48 40
 　　83 00 80 48 40
 　　00 90 43 40
 　　81 10 80 43 40
 　　00 90 43 40
 　　30 80 43 40
 　　00 90 4f 40
 　　81 40 80 4f 40
 　　00 90 4c 40
 　　81 40 80 4c 40
 　　00 90 48 40
 　　81 40 80 48 40
 　　00 90 47 40
 　　81 40 80 47 40
 　　00 90 45 40
 　　83 00 80 45 40
 　　00 90 4d 40
 　　81 10 80 4d 40
 　　00 90 4d 40
 　　30 80 4d 40
 　　00 90 4c 40
 　　81 40 80 4c 40
 　　00 90 48 40
 　　81 40 80 48 40
 　　00 90 4a 40
 　　81 40 80 4a 40
 　　00 90 48 40
 　　83 00 80 48 40
 　　01 b0 7b 00 // 00:delta_time; bn:设置n通道控制器; xx:控制器编号; xx:控制器值。此处为设置0通道123号控制器(关闭所有音符)值为0。
 　　00 b0 78 00 // 00:delta_time; bn:设置n通道控制器; xx:控制器编号; xx:控制器值。此处为设置0通道120号控制器(关闭所有声音)值为0。
 00 ff 2f 00 // 音轨终止

 下表列出的是与音符相对应的命令标记。
 八度音阶||                    音符号
 #  ||
     || C   | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
 -----------------------------------------------------------------------------
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
 
 八度音阶||                    音符号
 #  ||
    || C   | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
 -----------------------------------------------------------------------------
 0  ||   C |   D |   E |   F |  10 |  11 |  12 |  13 |  14 |  15 |  16 | 17
 1  ||  18 |  19 |  1A |  1B |  1C |  1D |  1E |  1F |  20 |  21 |  22 | 23
 2  ||  24 |  25 |  26 |  27 |  28 |  29 |  2A |  2B |  2C |  2D |  2E | 2F
 3  ||  30 |  31 |  32 |  33 |  34 |  35 |  36 |  37 |  38 |  39 |  3A | 3B
 4  ||  3C |  3D |  3E |  3F |  40 |  41 |  42 |  43 |  44 |  45 |  46 | 47
 5  ||  48 |  49 |  4A |  4B |  4C |  4D |  4E |  4F |  50 |  51 |  52 | 53
 6  ||  84 |  85 |  86 |  87 |  88 |  89 |  90 |  91 |  92 |  93 |  94 | 95
 7  ||  96 |  97 |  98 |  99 | 100 | 101 | 102 | 103 | 104 | 105 | 106 | 107
 8  || 108 | 109 | 110 | 111 | 112 | 113 | 114 | 115 | 116 | 117 | 118 | 119
 9  || 120 | 121 | 122 | 123 | 124 | 125 | 126 | 127 |

 tt 9n xx vv //tt: delta_time; 9n: 打开n通道发音; xx: 音符00~7F; vv:力度00~7F
 tt 8n xx vv //tt: delta_time; 8n: 关闭n通道发音; xx: 音符00~7F; vv:力度00~7F
 
 case 0xa0: //触摸键盘以后  音符:00~7F 力度:00~7F
 case 0xb0: //控制器  控制器号码:00~7F 控制器参数:00~7F
 case 0xc0: //切换音色： 乐器号码:00~7F
 case 0xd0: //通道演奏压力（可近似认为是音量） 值:00~7F
 case 0xe0: //滑音 音高(Pitch)低位:Pitch mod 128  音高高位:Pitch div 128
 */

ITrack* MidiFile::getTrackPianoTrack()
{
	ITrack* track0 = NULL;

	//search the piano track
	for (auto track = tracks.begin(); track != tracks.end(); track++) {
		if (track->events.size() > 0) {
			track0 = &(*track);
			bool foundPiano = false;
			for (auto event = track->events.begin(); event != track->events.end(); event++) {
				//c9 是打击乐channel
				if (event->evt != 0xC9 && (event->evt & 0xF0) == 0xC0 && event->nn == 0) {
					foundPiano = true;
					break;
				}
			}
			if (foundPiano)
				break;
		}
	}
	return track0;
}

double MidiFile::secPerTick()
{
	int ticksPerQuarter = quarter;
	int usPerQuarter = tempos.front().tempo;
	return usPerQuarter/1000000.0/ticksPerQuarter;
}

bool MidiFile::sort_ascending_order_tick(const Event& obj1, const Event& obj2)
{
	if (obj1.tick < obj2.tick) {
		return true;
	} else if (obj1.tick > obj2.tick) {
		return false;
	} else {
		if (obj1.play_priority > obj2.play_priority) {
			return true;
		} else if (obj1.play_priority < obj2.play_priority) {
			return false;
		} else {
			if (obj1.track_priority < obj2.track_priority) {
				return true;
			} else if (obj1.track_priority > obj2.track_priority) {
				return false;
			} else {
				return obj1.nn < obj2.nn;
			}
		}
	}
}

std::vector<Event>& MidiFile::mergedMidiEvents()
{
	if (_mergedMidiEvents.empty())
	{
		int tracksHaveEvents = 0;
		for (int i = 0; i < tracks.size(); ++i)
		{
			ITrack& track = tracks[i];
			if (track.events.size() > 0)
				tracksHaveEvents++;
		}

		if (tracksHaveEvents <= 1) {
			onlyOneTrack = true;
		} else if (tracks.size() > maxTracks) {
			int top1 = 0, top1_num = 0;
			int top2 = 1, top2_num = 0;
			for (int i = 0; i < tracks.size(); i++)
			{
				if (tracks[i].events.size() > top1_num) {
					top2 = top1;
					top2_num = top1_num;
					top1 = i;
					top1_num = tracks[i].events.size();
				} else if (tracks[i].events.size() > top2_num) {
					top2 = i;
					top2_num = tracks[i].events.size();
				}
			}
			if (top1 != top2)
			{
				ITrack* track0, *track1;
				if (top1 > top2) {
					track0 = &tracks[top2];
					track1 = &tracks[top1];
				} else {
					track0 = &tracks[top1];
					track1 = &tracks[top2];
				}

				for (auto e = track0->events.begin(); e != track0->events.end(); e++)
					e->track = 0;
				for (auto e = track1->events.begin(); e != track1->events.end(); e++)
					e->track = 1;
			}
		}

		int track_index = 0;
		for (auto track = tracks.begin(); track != tracks.end(); track++, track_index++) {
			if (!track->events.empty()) {
				//_mergedMidiEvents.insert(_mergedMidiEvents.end(), track->events.begin(), track->events.end());
				for (auto midi_event = track->events.begin(); midi_event != track->events.end(); midi_event++) {
					midi_event->track_priority = track_index;
					if (0x80 == (midi_event->evt & 0xF0) || (0x90 == (midi_event->evt & 0xF0) && 0 == midi_event->vv))
						midi_event->play_priority = 1;		//the note coresponding with this event off, means its priority is higher
					_mergedMidiEvents.push_back(*midi_event);
				}
			}
		}
		std::sort(_mergedMidiEvents.begin(), _mergedMidiEvents.end(), sort_ascending_order_tick);

		//remove the notes with same tick, evt, nn
		std::set<int> duplicateEvents;
		for (int i = 0; i < _mergedMidiEvents.size(); i++)
		{
			auto& event = _mergedMidiEvents[i];
			int evt = event.evt & 0xF0;
			int channel = event.evt & 0x0F;
			if (0x90 == evt && event.vv > 0) {		//note on 
				for (int k = i+1; k < _mergedMidiEvents.size(); k++) {
					auto& nextEvent = _mergedMidiEvents[k];
					int next_evt = nextEvent.evt & 0xF0;
					int next_channel = nextEvent.evt & 0x0F;
					if (nextEvent.tick != event.tick) {
						break;
					} else {
						if (nextEvent.nn == event.nn && (0x90 == next_evt && next_channel == channel && nextEvent.vv > 0))
						{
							duplicateEvents.insert(k);
							for (int off = k+1; off < _mergedMidiEvents.size(); off++)
							{
								auto& offEvent = _mergedMidiEvents[off];
								int off_evt = offEvent.evt & 0xF0;
								int off_channel = offEvent.evt & 0x0F;
								if ((0x80 == off_evt || (0x90 == off_evt && 0 == offEvent.vv)) && channel == off_channel && offEvent.nn == nextEvent.nn)
								{
									duplicateEvents.insert(off);
									break;
								}
							}
						}
					}
				}
			}
		}
		if (duplicateEvents.size() > 0)
		{
			printf("tracks:%d, remove %d duplicate events\n", tracks.size(), duplicateEvents.size());
			for (auto rit = duplicateEvents.rbegin(); rit != duplicateEvents.rend(); rit++)
			{
				int index = 0;
				for (auto event = _mergedMidiEvents.begin(); event != _mergedMidiEvents.end(); event++, index++) {
					if (index == *rit) {
						_mergedMidiEvents.erase(event);
						break;
					}
				}
			}
		}

		//检查是否有重叠的event：同一个音，前面还没有结束，后面就又开始了
		int changedEvent = 0;
		for (int i = 0; i < _mergedMidiEvents.size(); i++)
		{
			auto& event = _mergedMidiEvents[i];
			if (0x90 == (event.evt & 0xF0) && event.vv > 0)		//note on
			{
				int nextStartTick = -1;
				for (int j = i+1; j < _mergedMidiEvents.size(); j++)
				{
					auto& nextEvent = _mergedMidiEvents[j];
					if (nextEvent.nn == event.nn && (event.evt & 0x0F) == (nextEvent.evt & 0x0F)) {
						if (0x80 == (nextEvent.evt & 0xF0) || (0x90 == (nextEvent.evt & 0xF0) && 0 == nextEvent.vv)) {		//note off
							if (nextStartTick > 0 && nextEvent.tick > event.tick+480*8)
							{
								nextEvent.tick = nextStartTick;
								changedEvent++;
							}
							break;
						} else if (0x90 == (nextEvent.evt & 0xF0) && nextEvent.vv > 0) {		//note on
							nextStartTick = nextEvent.tick;
						}
					}
				}
			}
		}
		if (changedEvent > 0)
			std::sort(_mergedMidiEvents.begin(), _mergedMidiEvents.end(), sort_ascending_order_tick);
	}
	return _mergedMidiEvents;
}