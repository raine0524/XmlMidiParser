//
//  MidiFile.m
//  ReadStaff
//
//  Created by yan bin on 11-10-9.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//
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
 0  ||   0 |   1 |   2 |   3 |   4 |   5 |   6 |   7 |   8 |   9 |  10 | 11
 1  ||  12 |  13 |  14 |  15 |  16 |  17 |  18 |  19 |  20 |  21 |  22 | 23
 2  ||  24 |  25 |  26 |  27 |  28 |  29 |  30 |  31 |  32 |  33 |  34 | 35
 3  ||  36 |  37 |  38 |  39 |  40 |  41 |  42 |  43 |  44 |  45 |  46 | 47
 4  ||  48 |  49 |  50 |  51 |  52 |  53 |  54 |  55 |  56 |  57 |  58 | 59
 5  ||  60 |  61 |  62 |  63 |  64 |  65 |  66 |  67 |  68 |  69 |  70 | 71
 6  ||  72 |  73 |  74 |  75 |  76 |  77 |  78 |  79 |  80 |  81 |  82 | 83
 7  ||  84 |  85 |  86 |  87 |  88 |  89 |  90 |  91 |  92 |  93 |  94 | 95
 8  ||  96 |  97 |  98 |  99 | 100 | 101 | 102 | 103 | 104 | 105 | 106 | 107
 9  || 108 | 109 | 110 | 111 | 112 | 113 | 114 | 115 | 116 | 117 | 118 | 119
 10 || 120 | 121 | 122 | 123 | 124 | 125 | 126 | 127 |

 
 八度音阶||                    音符号
 #  ||
    || C   | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
 -----------------------------------------------------------------------------
 0  ||   0 |   1 |   2 |   3 |   4 |   5 |   6 |   7 |   8 |   9 |   A |  B
 1  ||   C |   D |   E |   F |  10 |  11 |  12 |  13 |  14 |  15 |  16 | 17
 2  ||  18 |  19 |  1A |  1B |  1C |  1D |  1E |  1F |  20 |  21 |  22 | 23
 3  ||  24 |  25 |  26 |  27 |  28 |  29 |  2A |  2B |  2C |  2D |  2E | 2F
 4  ||  30 |  31 |  32 |  33 |  34 |  35 |  36 |  37 |  38 |  39 |  3A | 3B
 5  ||  3C |  3D |  3E |  3F |  40 |  41 |  42 |  43 |  44 |  45 |  46 | 47
 6  ||  48 |  49 |  4A |  4B |  4C |  4D |  4E |  4F |  50 |  51 |  52 | 53
 
 7  ||  84 |  85 |  86 |  87 |  88 |  89 |  90 |  91 |  92 |  93 |  94 | 95
 8  ||  96 |  97 |  98 |  99 | 100 | 101 | 102 | 103 | 104 | 105 | 106 | 107
 9  || 108 | 109 | 110 | 111 | 112 | 113 | 114 | 115 | 116 | 117 | 118 | 119
 10 || 120 | 121 | 122 | 123 | 124 | 125 | 126 | 127 |


 tt 9n xx vv //tt: delta_time; 9n: 打开n通道发音; xx: 音符00~7F; vv:力度00~7F
 tt 8n xx vv //tt: delta_time; 8n: 关闭n通道发音; xx: 音符00~7F; vv:力度00~7F
 
 case 0xa0: //触摸键盘以后  音符:00~7F 力度:00~7F
 case 0xb0: //控制器  控制器号码:00~7F 控制器参数:00~7F
 case 0xc0: //切换音色： 乐器号码:00~7F
 case 0xd0: //通道演奏压力（可近似认为是音量） 值:00~7F
 case 0xe0: //滑音 音高(Pitch)低位:Pitch mod 128  音高高位:Pitch div 128

 */


#import "MidiFile.h"
#import "defines.h"

@implementation BaseEvent
@synthesize tick=tick_;
@end

@implementation Event
- (instancetype)initWithCoder:(NSCoder *)decoder
{
//    self = [super initWithCoder:coder];
    if (self) {
        self.evt = [decoder decodeIntForKey:NSStringFromSelector(@selector(evt))];
        self.nn = [decoder decodeIntForKey:NSStringFromSelector(@selector(nn))];
        self.vv = [decoder decodeIntForKey:NSStringFromSelector(@selector(vv))];
        self.tick = [decoder decodeIntForKey:NSStringFromSelector(@selector(tick))];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:self.evt forKey:NSStringFromSelector(@selector(evt))];
    [coder encodeInt:self.nn forKey:NSStringFromSelector(@selector(nn))];
    [coder encodeInt:self.vv forKey:NSStringFromSelector(@selector(vv))];
    [coder encodeInt:self.tick forKey:NSStringFromSelector(@selector(tick))];
}
@end

@implementation TimeSignatureEvent
@synthesize numerator=numerator_,number_ticks=number_ticks_,number_32nd_notes=number_32nd_notes_,denominator=denominator_;
@end

@implementation TextEvent
@synthesize text=text_;
@end

@implementation TempoEvent
@synthesize tempo=tempo_;
@end

@implementation KeySignatureEvent
@synthesize mi=mi_;
@synthesize sf=sf_;
@end

@implementation SpecificInfoEvent
@synthesize infos=infos_;
@end

@implementation ChordEvent
@end

//系统高级消息
@implementation SysExclusiveEvent
@synthesize event=event_;
@end

@implementation ITrack
@synthesize number=number_;
@synthesize name=name_;
@synthesize instrument=instrument_;
@synthesize events=events_;
@synthesize lyrics=lyrics_;
@synthesize specificEvents=specificEvents_;
@synthesize texts=texts_;
- (id) init
{
    self=[super init];
    if (self) {
        events_=[[NSMutableArray alloc]init];
        texts_=[[NSMutableArray alloc]init];
        lyrics_=[[NSMutableArray alloc]init];
        specificEvents_=[[NSMutableArray alloc]init];
    }
    return self;
}

- (void) clear
{
    number_ = 0;
    self.name = nil;
    self.instrument = nil;
}
/*
 class Pre {
 public:
 bool operator()(const Event& e1, const Event& e2) const {
 if (e1.tick_ == e2.tick_) {
 if ((e1.event_ & 0xF0) == 0xC0 && (e2.event_ & 0xF0) == 0x90) //instrument
 return true;
 
 if ((e1.event_ & 0xF0) == 0xB0 && (e2.event_ & 0xF0) == 0x90) //control event
 return true;
 }
 
 return e1.tick_ < e2.tick_;
 }
 };
 */
/*
- (BOOL)addEvents:(NSMutableArray*) events 
{
    [track_.events addObjectsFromArray:events];
    
    endAdd();
    
    return true;
}
 bool TrackImp::endAdd() {
 QList<Event>& events = *track_->events_.data();
 qStableSort(events.begin(), events.end(), Pre());
 
 return true;
 }
 */
//
NSInteger compair_event(Event* e1, Event* e2, void* data);

//NSInteger compair_event(Event* e1, Event* e2, void* data)
//{
//    if (e1.tick == e2.tick) {
//        if ((e1.event & 0xF0) == 0xC0 && (e2.event & 0xF0) == 0x90) //instrument
//            return true;
//        
//        if ((e1.event & 0xF0) == 0xB0 && (e2.event & 0xF0) == 0x90) //control event
//            return true;
//    }
//    
//    return e1.tick - e2.tick;
//}

NSInteger compair_event(Event* e1, Event* e2, void* data)
{
    if (e1.tick == e2.tick) {
        if ((e1.evt & 0xF0) == 0xC0 && (e2.evt & 0xF0) == 0x90) //instrument
            return true;
        
        if ((e1.evt & 0xF0) == 0xB0 && (e2.evt & 0xF0) == 0x90) //control event
            return true;
    }
    
    return e1.tick - e2.tick;
}

-(bool) sort_events
{
//    QList<Event>& events = *track_->events_.data();
//    qStableSort(events.begin(), events.end(), Pre());
    [events_ sortUsingFunction:compair_event context:nil];
    return true;
}
@end

@interface MidiFile()
@property (nonatomic, strong) NSArray *mergedMidiEvents;
@end

@implementation MidiFile
@synthesize tempos=tempos_,timeSignatures=timeSignatures_;
@synthesize markers=markers_, cuePoints=cuePoints_, keySignatures=keySignatures_, sysExclusives=sysExclusives_;
@synthesize quarter=quarter_, format=format_;
@synthesize author=author_, name=name_, copyright=copyright_;
@synthesize tracks=tracks_;

- (id) init
{
    self = [super init];
    if (self) {
        tracks_ = [[NSMutableArray alloc]init];
        tempos_ = [[NSMutableArray alloc]init];
        timeSignatures_ = [[NSMutableArray alloc]init];
        keySignatures_ = [[NSMutableArray alloc]init];
        sysExclusives_ = [[NSMutableArray alloc]init];
    }
    return self;
}
    

-(BOOL) addTrack:(int) idx
{/*
    NSNumber *key = [NSNumber numberWithInt:idx];
    ITrack *track=[tracks_ objectForKey:key];
    if (track==nil) {
        track=[[ITrack alloc]init];
        [tracks_ setObject:track forKey:key];
        [track release];
        return YES;
    }
  */
    return NO;
    /*
    QMap<int, TrackPtr>::iterator it;
    
    it = midi_->tracks_.find(idx);
    
    if (it == midi_->tracks_.end()) {
        midi_->tracks_[idx] = TrackPtr(new TrackImp);
        return true;
    }
    return false;
     */
}

- (NSMutableArray*) getTracks
{
    return tracks_;
}
    
-(ITrack*)getTrack:(int) idx
{
    return [tracks_ objectAtIndex:idx];
    /*
    QMap<int, TrackPtr>::iterator it;
    
    it = midi_->tracks_.find(idx);
    
    if (it != midi_->tracks_.end()) {
        return it.value().data();
    }
    
    return NULL;
     */
}
- (ITrack*)getTrackPianoTrack
{
    ITrack *track0=nil;
    
    //search the piano track
    for (ITrack *track in self.tracks) {
        if (track.events.count>0) {
            track0=track;
            BOOL foundPiano=NO;
            for (Event *event in track.events) {
                //c9 是打击乐channel
                if (event.evt!=0xc9 && (event.evt&0xf0)==0xc0 && event.nn==0) {
                    foundPiano=YES;
                    break;
                }
            }
            if (foundPiano) {
                break;
            }
        }
    }
    return track0;
}

- (void)sortEvents:(NSMutableArray*)midiEvents
{
    [midiEvents sortWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(Event *obj1, Event *obj2) {
        if (obj1.tick==obj2.tick) {
            
            unsigned char evt1=obj1.evt&0xF0;
            unsigned char evt2=obj2.evt&0xF0;
            if (evt1!=evt2) {
                if (evt1==0x80 || (evt1==0x90&&obj1.vv==0)) {
                    return NSOrderedAscending;
                }else if (evt2==0x80 || (evt2==0x90&&obj2.vv==0)) {
                    return NSOrderedDescending;
                }
            }
            return NSOrderedSame;
        }else if (obj1.tick<obj2.tick) {
            return NSOrderedAscending;
        }else //if (obj1.tick>obj2.tick)
        {
            return NSOrderedDescending;
        }
    }];
}

- (void)dealloc
{
    self.mergedMidiEvents=nil;
}

- (NSArray*)mergedMidiEvents {
    if (_mergedMidiEvents==nil) {
#if 1
        NSMutableArray *midiEvents=[NSMutableArray new];
        
        if (self.tracks.count>2) {
            int top1=0, top1_num=0;
            int top2=1, top2_num=0;
            for (int i=0;i<self.tracks.count;i++) {
                ITrack *track = self.tracks[i];
                if (track.events.count>top1_num) {
                    top2=top1;
                    top2_num=top1_num;
                    top1=i;
                    top1_num=(int)track.events.count;
                }else if (track.events.count>top2_num) {
                    top2=i;
                    top2_num=(int)track.events.count;
                }
            }
            if (top1!=top2) {
                ITrack *track0,*track1;
                if (top1>top2) {
                    track0=self.tracks[top2];
                    track1=self.tracks[top1];
                }else{
                    track0=self.tracks[top1];
                    track1=self.tracks[top2];
                }
                for (Event *e in track0.events) {
                    e.track=0;
                }
                
                for (Event *e in track1.events) {
                    e.track=1;
                }
            }
        }
        
        for (int i=0;i<self.tracks.count;i++) {
            ITrack *track = self.tracks[i];
            [midiEvents addObjectsFromArray:track.events];
        }
        if (self.tracks.count==2) {
            for (int i=0;i<self.tracks.count;i++) {
                ITrack *track = self.tracks[i];
                if (track.events.count==0) {
                    self.onlyOneTrack=YES;
                }
            }
        }
        
        [self sortEvents:midiEvents];

        //remove the notes with same tick, evt, nn
        NSMutableIndexSet *duplicateEvents=[NSMutableIndexSet new];
        for (int i=0; i<midiEvents.count; i++) {
            Event *event=midiEvents[i];
            //NSLog(@"%d %d:%x %d %d", i, event.tick, event.evt, event.nn, event.vv);
            //if (event.evt==0x90 || event.evt==0x80)
            int evt=event.evt&0xf0;
            int channel=event.evt&0x0f;
            if (evt==0x90 && event.vv>0) //note on
            {
                for (int k=i+1; k<midiEvents.count; k++) {
                    Event *nextEvent=midiEvents[k];
                    int next_evt=nextEvent.evt&0xf0;
                    int next_channel=nextEvent.evt&0x0f;
                    if (nextEvent.tick!=event.tick) {
                        break;
                    }else{
                        if (nextEvent.nn==event.nn && (next_evt==0x90 && next_channel==channel && nextEvent.vv>0 )) {
                            [duplicateEvents addIndex:k];
                            for (int off=k+1; off<midiEvents.count; off++) {
                                Event *offEvent=midiEvents[off];
                                int off_evt=offEvent.evt&0xf0;
                                int off_channel=offEvent.evt&0x0f;
                                if ((off_evt==0x80 || (off_evt==0x90 && offEvent.vv==0)) && offEvent.nn==event.nn && channel==off_channel) {
                                    [duplicateEvents addIndex:off];
                                    break;
                                }
                            }
//                            NSLog(@"dup:%d %x %d %d -> %d %x %d %d",
//                                  event.tick, event.evt, event.nn, event.vv,
//                                  nextEvent.tick, nextEvent.evt, nextEvent.nn, nextEvent.vv);
                        }
                    }
                }
            }
        }
        if (duplicateEvents.count>0) {
            NSLog(@"tracks:%d, remove %d duplicate events",(int)self.tracks.count, (int)duplicateEvents.count);
            [midiEvents removeObjectsAtIndexes:duplicateEvents];
        }
        
#if 1
        //检查是否有重叠的event：同一个音，前面还没有结束，后面就又开始了。
        int changedEvent=0;
        for (int i=0; i<midiEvents.count; i++) {
            Event *event=midiEvents[i];
            if (event.evt==0x90 && event.vv>0) //note on
            {
                int nextStartTick=-1;
                for (int k=i+1; k<midiEvents.count; k++) {
                    Event *nextEvent=midiEvents[k];
                    if (nextEvent.nn==event.nn && (nextEvent.evt&0x0f)==(event.evt&0x0f)) {
                        if ((nextEvent.evt&0xf0)==0x80 || ((nextEvent.evt&0xf0)==0x90 && nextEvent.vv==0 )) { //note off
                            if (nextStartTick>0) {
                                nextEvent.tick=nextStartTick;
                                changedEvent++;
                            }
                            break;
                        }else if(nextEvent.evt==0x90 && nextEvent.vv>0){ //note on
                            nextStartTick=nextEvent.tick;
                        }
                    }
                }
            }
        }
        if (changedEvent>0) {
            [self sortEvents:midiEvents];
        }
#endif
        
        _mergedMidiEvents=midiEvents;
        
#else
        NSMutableArray *midiEvents=[NSMutableArray new];
        int size=(int)self.tracks.count * sizeof(int);
        int *index=malloc(size);
        memset(index, 0, size);
        
        while (YES) {
            //find the nearest event
            int tick=INT32_MAX;
            int nearest_i=0;
            Event *nearest_event=nil;
            for (int i=0;i<self.tracks.count;i++) {
                ITrack *track = self.tracks[i];
                if (index[i]<track.events.count) {
                    Event *event=track.events[index[i]];
                    if (event.tick<tick) {
                        tick=event.tick;
                        nearest_i=i;
                        nearest_event=event;
                    }
                }
            }
            if (nearest_event) {
                [midiEvents addObject:nearest_event];
                index[nearest_i]++;
                //NSLog(@"%d:%x %d %d", nearest_event.tick, nearest_event.evt, nearest_event.nn, nearest_event.vv);
            }else{
                break;
            }
        }
        free(index);
        
        _mergedMidiEvents=midiEvents;
#endif
    }
    return _mergedMidiEvents;
}

- (double)secPerTick {
    int ticksPerQuarter=self.quarter;
    TempoEvent *te=self.tempos.firstObject;
    int usPerQuarter=te.tempo;
    return usPerQuarter/1000000.0/ticksPerQuarter;
}

/*
 4: 480
 8: 240
 16:120
 32:60
 64:30
 128:15
    bool MidiImp::isEmpty(void) {
        QList<int> indexs = getTrackIndexs();
 
        for (int i = 0; i < indexs.size(); ++i) {
            ITrack* track = getTrack(indexs[i]);
            QSharedPointer<QList<Event> > evs = track->getEvents();
            
            if (!evs->isEmpty()) {
                return false;
            }
        }
        
        return true;
    }
*/
-(void)clear
{
    format_ = 1;
    quarter_ = 480;
    
    [tempos_ removeAllObjects];
    [timeSignatures_ removeAllObjects];
    [keySignatures_ removeAllObjects];
    [sysExclusives_ removeAllObjects];
    
    [markers_ removeAllObjects];
    [cuePoints_ removeAllObjects];

    [tracks_ removeAllObjects];
    
}

@end
