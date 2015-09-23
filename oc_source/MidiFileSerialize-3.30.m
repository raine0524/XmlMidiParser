//
//  MidiFileSerialize.m
//  ReadStaff
//
//  Created by yan bin on 11-10-11.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "MidiFileSerialize.h"
#import "MidiFile.h"

@implementation CommonEvent
@synthesize event=event_,tick=tick_;

@end

@implementation CommonEventCreator
@synthesize items=items_;

-(id)init
{
    self=[super init];
    if (self) {
        items_=[[NSMutableArray alloc]init];
    }
    return self;
}

-(void) midi_word_to_char:(unsigned short) word data:(char*) data
{
	unsigned int i ;
	const unsigned int SIZE = sizeof(unsigned short) ;
	
	for( i=0; i<SIZE; ++i ) {
		data[(SIZE-1)-i] = (char)(word % 256) ;
		word /= 256 ;
	}
}

-(void) midi_int_to_char:(unsigned int) num data:(char*) data
{
	unsigned int i ;
	const unsigned int SIZE = sizeof(unsigned int) ;
	
	for( i=0; i<SIZE; ++i ) {
		data[(SIZE-1)-i] = (char)(num % 256) ;
		num /= 256 ;
	}
}
-(void) addEvent:(Event*) ev
{
	unsigned int len=0;
    if ([ev class]!=[Event class]) {
        NSLog(@"error, unknow ev=%@",ev);
    }
//	unsigned char ch = ev.event & 0xF0;
    unsigned char ch = ev.evt & 0xF0;
    
	switch (ch) {
        case 0x80:
        case 0x90:
        case 0xa0:
        case 0xb0:
        case 0xe0: {
            len = 3;

            break;
        }
        case 0xc0:
        case 0xd0: {
            len = 2;
            break;
        }
        default: {
            break;
        }
	}
    
    CommonEvent *event=[[CommonEvent alloc]init];
    [items_ addObject:event];
    event.tick = ev.tick;
    event.event=[[NSMutableData alloc]init];
    NSMutableData *buffer=event.event;
    
    if (len>0) {
        unsigned char tmp[4];
//        int num=ev.event;
//        for (int i = 0; i < len; ++i) {
//            tmp[i] = num % 256;
//            num /= 256;
//        }
        tmp[0]=ev.evt;
        tmp[1]=ev.nn;
        if (len==3) {
            tmp[2]=ev.vv;
        }

        [buffer appendBytes:tmp length:len];
    }
}
- (void) addText:(NSString*)text style:(int)style
{
    if (text==nil || text.length==0) {
        return;
    }
    CommonEvent *event=[[CommonEvent alloc]init];
    [items_ addObject:event];
    event.tick = 0;
    event.event=[[NSMutableData alloc]init];
    NSMutableData *buffer=event.event;
    
    char tmp[4];
    [buffer appendBytes:"\xFF" length:1];
    tmp[0]=style;
    [buffer appendBytes:tmp length:1];//style
    tmp[0]=[text length];
    [buffer appendBytes:tmp length:1];//text size
    
    [buffer appendData:[text dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void) addTextEvent:(TextEvent*)ev style:(int)style
{
    CommonEvent *event=[[CommonEvent alloc]init];
    [items_ addObject:event];
    event.tick = ev.tick;
    event.event=[[NSMutableData alloc]init];
    NSMutableData *buffer=event.event;
    
    char tmp[4];
    [buffer appendBytes:"\xFF" length:1];
    tmp[0]=style;
    [buffer appendBytes:tmp length:1];//style
    tmp[0]=[ev.text length];
    [buffer appendBytes:tmp length:1];//text size
    
    [buffer appendData:[ev.text dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void) addSpecificInfoEvent:(SpecificInfoEvent*) ev
{

    CommonEvent *event=[[CommonEvent alloc]init];
    [items_ addObject:event];
    event.tick = ev.tick;
    event.event=[[NSMutableData alloc]init];
    NSMutableData *buffer=event.event;
    
    char tmp[4];
    
    [buffer appendBytes:"\xFF" length:1];
    [buffer appendBytes:"\x7F" length:1];//style
    tmp[0]=ev.infos.length;
    [buffer appendBytes:tmp length:1];//content size
    if (ev.infos) {
        [buffer appendData:ev.infos];
    }
}
- (void) addTempoEvent:(TempoEvent*)ev
{
    CommonEvent *event=[[CommonEvent alloc]init];
    [items_ addObject:event];
    event.tick = ev.tick;
    event.event=[[NSMutableData alloc]init ];
    NSMutableData *buffer=event.event;
    
    char tmp[4];
    [buffer appendBytes:"\xFF" length:1];
    [buffer appendBytes:"\x51" length:1];//style
    [buffer appendBytes:"\x03" length:1];//content size
    tmp[0]=ev.tempo>>16;
    tmp[1]=ev.tempo>>8;
    tmp[2]=ev.tempo>>0;
    [buffer appendBytes:tmp length:3];
    
    
}

-(int) index2:(int) data
{
	int i;
    
	for (i = 0; data > 0; ++i) {
		data /= 2;
	}
    
	return i - 1;
}
- (void) addTimeSignatureEvent:(TimeSignatureEvent*)ev
{
    CommonEvent *event=[[CommonEvent alloc]init];
    [items_ addObject:event];
    event.tick = ev.tick;
    event.event=[[NSMutableData alloc]init ];
    NSMutableData *buffer=event.event;
    
    char tmp[4];
    [buffer appendBytes:"\xFF" length:1];
    [buffer appendBytes:"\x58" length:1];//style
    [buffer appendBytes:"\x04" length:1];//content size
    tmp[0]=ev.numerator;
    tmp[1]=[self index2:ev.denominator];
    tmp[2]=ev.number_ticks;
    tmp[3]=ev.number_32nd_notes;
    [buffer appendBytes:tmp length:4];
    
    
}

- (void) addKeySignatureEvent:(KeySignatureEvent*)ev
{
    CommonEvent *event=[[CommonEvent alloc]init];
    [items_ addObject:event];
    event.tick = ev.tick;
    event.event=[[NSMutableData alloc]init ];
    NSMutableData *buffer=event.event;
    
    char tmp[4];
    [buffer appendBytes:"\xFF" length:1];
    [buffer appendBytes:"\x59" length:1];//style
    [buffer appendBytes:"\x02" length:1];//content size
    tmp[0]=ev.sf;
    tmp[1]=ev.mi;
    [buffer appendBytes:tmp length:2];
    
    
}
-(int) construct_delta_time:(int) tick data:(unsigned char*) data
{
	int i;
#define MAX_TIME  5//Set a big value, delta_time can't be as big as MAX bytes
    //	unsigned char data[MAX_TIME];
	unsigned char data1[MAX_TIME];
    int max=0;
    
	for (i = 0; i < MAX_TIME; ++i) {
        data1[i]=((tick & 0x7F));
		tick >>= 7;
        
		if (tick == 0) {
			max=i+1;
            break;
		}
	}
    
	for (i = 0; i < max; ++i) {
		int idx;
        
		idx = (max - i) - 1;
        
		if (idx != 0) {
            data[i]=(data1[idx] | 0x80);
		} else {
			data[i]=(data1[idx]);
		}
	}
    
	return max;
}
- (void) addSysExclusiveEvent:(SysExclusiveEvent*)ev
{
    CommonEvent *event=[[CommonEvent alloc]init];
    [items_ addObject:event];
    event.tick = ev.tick;
    event.event=[[NSMutableData alloc]init ];
    NSMutableData *buffer=event.event;
    
    unsigned char time[5];
    int size = [self construct_delta_time:ev.tick data: time];
    //[buffer appendBytes:time length:size];
    
    //NSMutableData *data=[[NSMutableData alloc]init ];
    unsigned char *bytes=(unsigned char*)[ev.event bytes];
    [buffer appendBytes:bytes length:1];
    [buffer appendBytes:time length:size];
    [buffer appendBytes:&bytes[1] length:ev.event.length-1];
    
    
}
NSInteger my_compare(CommonEvent *a, CommonEvent *b, void* data);

NSInteger my_compare(CommonEvent *a, CommonEvent *b, void* data)
{
    return a.tick-b.tick;
}
-(void) sort
{
//    [items_ sortUsingSelector:@selector(compare:)];
    [items_ sortUsingFunction:my_compare context:nil];
}
-(void) absToRel
{
	int tick=0;
	int prev=0;
    
    for (CommonEvent *a in items_) {
		tick = a.tick;
		a.tick -= prev;
        
		prev = tick;
	}
}
@end

@implementation MidiFileSerialize

/*
 load midi
 */

// int <-> word
-(unsigned int) create_midi_int:(unsigned char*) p
{
	unsigned int i ;
	unsigned int num=0;
	const unsigned int SIZE = 4 ;
	
	for ( i=0; i<SIZE; ++i ) {
		num = (num<<8) + *(p+i) ;
	}
	
	return num ;
}
//unsigned char a[2] -> word
-(unsigned short) create_word:(unsigned char*) p
{
	unsigned short num = 0 ;
	
	num = (*p)<<8 ;
	num += *(p+1) ;
	
	return num ;
}


typedef struct {
    unsigned char id_[4];
    unsigned char size_[4];
}Chunk;
//static int buf_index=0;

#define R_BUF(buf,len)  \
{                       \
NSRange range;          \
if(len+buf_index>buffer.length) return nil;  \
range.location=buf_index;range.length=len;  \
[buffer getBytes:buf range:range];  \
buf_index+=len; \
}

- (int) parseDeltaTime:(unsigned char*) p time: (int*) time
{
	unsigned int i;
	unsigned int j;
	unsigned char ch;
	unsigned int MAX=5;//
    
	for (i = 0; i < MAX; ++i) {
		ch = *(p + i);
		if (!(ch & 0x80)) {
			break;
		}
	}
    
	if (i != MAX) {
		*time = 0;
        
		for (j = 0; j < i + 1; ++j) {
			ch = *(p + j);
			*time = ((*time) << 7) + (ch & 0x7F);
		}
        
		return i + 1;
	}
    
	return -1;
}


- (NSString*) stringWithChars:(char*) buf len:(int)len
{
    NSData *data=[NSData dataWithBytes:buf length:len];
    NSString *tmp=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return tmp;
}

/*
 unsigned char event_type; //2:copyrigt, 3:name, 
 unsigned char text_size;
 char text[text_size+1];
 */

-(int) parseMetaEvent:(unsigned char*) p tick:(int) tick track:(ITrack*) track
{
	char ch=0;
	int len=0;
	int ret=0;
    
	p++; // 0xFF ;
	ch = *p++;
    
	ret = [self parseDeltaTime:p time:&len];
    
	if (ret == -1) {
		return false;
	}
    
	p += ret;
    
	switch (ch) {
        case 0x00: { //FF 00 02 ss ss: 音序号 
            //			track->set_nu = short(*p) ;
            break;
        }
        case 0x01: {//文本事件：用来注释 track 的文本
            TextEvent *event=[[TextEvent alloc]init];
            
            event.tick = tick;
            event.text = [self stringWithChars:(char*)p len:len];
            [track.texts addObject:event];
            break;
        }
        case 0x02: {//版权声明： 这个是制定的形式“(C) 1850 J.Strauss”
            //p[len]=0;
            midi_.copyright=[self stringWithChars:(char*)p len:len];
            //[NSString stringWithCString:(char*)p encoding:NSUTF8StringEncoding];
            break;
        }
        case 0x03: { // 音序或 track 的名称。
            //p[len]=0;
            track.name=[self stringWithChars:(char*)p len:len];
            //[NSString stringWithCString:(char*)p encoding:NSUTF8StringEncoding];
            break;
        }
        case 0x04: { //乐器名称 
            //p[len]=0;
            track.instrument=[self stringWithChars:(char*)p len:len];
            //[NSString stringWithCString:(char*)p encoding:NSUTF8StringEncoding];
            break;
        }
        case 0x05: { //歌词 
            TextEvent *event=[[TextEvent alloc]init];
            
            event.tick = tick;
            //p[len]=0;
            event.text=[self stringWithChars:(char*)p len:len];
            //[NSString stringWithCString:(char*)p encoding:NSUTF8StringEncoding];
            [track.lyrics addObject:event];
            break;
        }
        case 0x06: { //标记（如：“诗篇1”）
            TextEvent *event=[[TextEvent alloc]init];
            
            event.tick = tick;
            //p[len]=0;
            event.text=[self stringWithChars:(char*)p len:len];
            //[NSString stringWithCString:(char*)p encoding:NSUTF8StringEncoding];
            
            [midi_.markers addObject:event];
            break;
        }
        case 0x07: {//暗示： 用来表示舞台上发生的事情。如：“幕布升起”、“退出，台左”等。
            TextEvent *event=[[TextEvent alloc]init];
            
            event.tick = tick;
            //p[len]=0;
            event.text=[self stringWithChars:(char*)p len:len];
            //[NSString stringWithCString:(char*)p encoding:NSUTF8StringEncoding];
            
            [midi_.cuePoints addObject:event];
            break;
        }
        case 0x2f: {//Track 结束
            break;
        }
        case 0x51: { //拍子:1/4音符的速度，用微秒表示。如果没有指出，缺省的速度为 120拍/分。这个相当于 tttttt = 500,000。
            int tempo=0;
            TempoEvent *event=[[TempoEvent alloc]init];
            
            event.tick = tick;
            event.tempo = 0;
            
            tempo = *p++;
            event.tempo |= tempo << 16;
            tempo = *p++;
            event.tempo |= tempo << 8;
            tempo = *p;
            event.tempo |= tempo;
            
            [midi_.tempos addObject: event];
            break;
        }
        case 0x58: { //拍子记号: 如： 6/8 用 nn=6，dd=3 (2^3)表示。
            TimeSignatureEvent *event=[[TimeSignatureEvent alloc]init];
            
            event.tick = tick;
            
            event.numerator = *p++; //分子
            event.denominator = *p++; //分母表示为 2 的（dd次）冥
            event.number_ticks = *p++; //每个 MIDI 时钟节拍器的 tick 数目
            event.number_32nd_notes = *p; //24个MIDI时钟中1/32音符的数目（8是标准的）
            
            event.denominator = (int) pow((float) 2, event.denominator);
            
            [midi_.timeSignatures addObject:event];
            break;
        }
        case 0x59: {//音调符号:0 表示 C 调，负数表示“降调”，正数表示“升调”。
            KeySignatureEvent *event=[[KeySignatureEvent alloc]init];
            
            event.tick = tick;
            
            event.sf = *((char*) p++); //升调或降调值  -7 = 7 升调,  0 =  C 调,  +7 = 7 降调
            event.mi = *p; //0 = 大调, 1 = 小调
            
            [midi_.keySignatures addObject:event];
            break;
        }
        case 0x7f: {//音序器描述  Meta-event
            SpecificInfoEvent *event=[[SpecificInfoEvent alloc]init];
            
            event.tick = tick;
            event.infos = [NSMutableData dataWithBytes:p length:len];
            
            [track.specificEvents addObject:event];
            break;
        }
            
        default: {
            break;
        }
	}
    
	return len + ret + 2;
}

//系统高级消息
-(int) parseSystemExclusiveEvent:(unsigned char*) p tick:(int) tick
{
	int offset=0; //��ݳ�����ռ���ֽ���
	int len=0; //��ݵĳ���
	//	const int MAX(1000) ;
	SysExclusiveEvent *event=[[SysExclusiveEvent alloc]init];
    
	event.tick = tick;
    event.event=[[NSMutableData alloc]init];
    [event.event appendBytes:p length:1];
    p++;
    
	offset = [self parseDeltaTime:p time:&len];
    
	p += offset;
    
    [event.event appendBytes:p length:len];
    
    [midi_.sysExclusives addObject:event];
    
	return len + offset + 1;
}
-(int) parseChannelEvent:(unsigned char*) p pre:(unsigned char*) pre_ctrl tick:(int) tick track:(ITrack*) track
{
	int len=0;
	unsigned char ch=0;
	unsigned int temp=0;
	Event *event=[[Event alloc]init];
    
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
    
	//event.event |= temp;
    event.evt=ch;
    
	ch &= 0xF0;
    
	switch (ch) {
        case 0x80: //音符关闭 (释放键盘) 音符:00~7F 力度:00~7F
        case 0x90: //音符打开 (按下键盘) 音符:00~7F 力度:00~7F
        case 0xa0: //触摸键盘以后  音符:00~7F 力度:00~7F
        case 0xb0: //控制器  控制器号码:00~7F 控制器参数:00~7F
        case 0xe0: //滑音 音高(Pitch)低位:Pitch mod 128  音高高位:Pitch div 128
        {
            len += 2;
            temp = *p++;
            //event.event |= (temp << 8); //音符
            event.nn=temp;
            
            temp = *p;
            //event.event |= (temp << 16); //力度
            event.vv=temp;
            
            break;
        }
        case 0xc0: //切换音色： 乐器号码:00~7F
        case 0xd0: //通道演奏压力（可近似认为是音量） 值:00~7F
        {
            len += 1;
            temp = *p;
            //event.event |= (temp << 8);
            event.nn=temp;
            
            break;
        }
        default: {
            break;
        }
	}
    
	[track.events addObject:event];
    
	return len;
}
/*
 //00 FF 03 07 43 6F 6E 64 75 63 74 00 FF 2F 00
 unsigned char flag; //
 unsigned char event_type; //0xFF:meta event, 0xF0/0xF7:sys exclusive event, other: channel event
 unsigned char event_data[];
 */
-(BOOL)parseMidiEvent:(NSData*) data track:(ITrack*) track
{
	unsigned int tick=0;
	unsigned char *p, *buff;
	unsigned char pre_ctrl=0;
    
	p = (unsigned char*)[data bytes];
    buff=p;
    int size=(int)data.length;
    
	for (; p - buff < (int) size;) {
		int t=0;
		int offset;
		unsigned char ch;
        
		offset = [self parseDeltaTime:p time:&t];
        
		if (offset == -1) {
			return false;
		}
        
		tick += t;
        
		p += offset;
        
		ch = *p;
		if (ch == 0xFF) //meta event 用来表示象 track 名称、歌词、提示点等
		{
			offset = [self parseMetaEvent:p tick:tick track:track];
		} else if ((ch == 0xF0) || (ch == 0xF7)) //sys exclusive event 系统高级消息
		{
			offset = [self parseSystemExclusiveEvent:p tick:tick];
		} else //channel event
		{
			offset = [self parseChannelEvent:p pre:&pre_ctrl tick:tick  track:track];
		}
        
		p += offset;
	}
    
	return true;
}
/*
 unsigned char id[4]; //= "MTrk"
 unsigned long size; 
 unsigned char data[size]; 
 */
-(bool) readTrackData:(ITrack*) track from:(NSData*) buffer
{
    
	unsigned int len=0;
	//unsigned char* buff = NULL;
	Chunk chunk;
    
    R_BUF(&chunk, sizeof(chunk));
    
    if (memcmp(chunk.id_, "MTrk", 4)!=0) {
        return NO;
    }
    
	len =[self create_midi_int:chunk.size_];
    
    //buff = malloc(len);
    //	buff = new unsigned char[len];
	//if (buff == NULL)return false;
//    R_BUF(buff, len);
    NSData *buff;
    NSRange range;
    if(len+buf_index>buffer.length) return NO;
    range.location=buf_index;range.length=len;
    buff = [buffer subdataWithRange:range];
    buf_index+=len;
    
	if (![self parseMidiEvent:buff track:track]) {
		return false;
	}
    
	return true;
}

-(void)parseHeadInfo:(ITrack*) track
{
	if (midi_ == NULL) {
		return;
	}
    midi_.name=track.name;
    if (track.texts.count>0) {
        midi_.author=[track.texts objectAtIndex:0];
    }
}
/*
 -(void) convert0To1:(ITrack*) track
 {
 if (midi_ == NULL) {
 return;
 }
 
 unsigned int i;
 //int cnt(0) ;
 
 QList<Event> events;
 QList<Event>::const_iterator it;
 QList<QList<Event> > eventss;
 
 for(i=0; i<MAX_TRACK_NUMBER; ++i) {
 eventss.append(QList<Event>());
 }
 //eventss.resize();
 
 QSharedPointer<QList<Event> > evs = track->getEvents();
 
 for (it = evs->begin(); it != evs->end(); ++it) {
 unsigned int ch = (*it).event_ & 0x0f;
 if (ch < MAX_TRACK_NUMBER) {
 eventss[ch].push_back(*it);
 }
 }
 
 midi_->deleteTrack(0);
 
 for (i = 0; i < MAX_TRACK_NUMBER; ++i) {
 if (eventss[i].size() > 0) {
 midi_->addTrack(i);
 ITrack* track1 = midi_->getTrack(i);
 
 track1->getEvents()->clear();
 //QList<Event>& datas = const_cast<QList<Event>&>(track->get_events()) ;
 track1->addEvents(eventss[i]);
 }
 }
 }
 */
- (MidiFile*) load:(NSData*) buffer//, unsigned int size)
{
    BOOL ret=NO;
	int fmt;
	unsigned int track_cnt;
	unsigned char word[2];
	Chunk chunk;
    
    midi_=[[MidiFile alloc]init];
    buf_index=0;
	do {
        
        R_BUF(&chunk, sizeof(chunk));
//        NSLog(@"%c%c%c%c,%02x %02x %02x %02x", chunk.id_[0],chunk.id_[1],chunk.id_[2],chunk.id_[3],chunk.size_[0],chunk.size_[1],chunk.size_[2],chunk.size_[3]);
        
        if (memcmp(chunk.id_, "MThd", 4)!=0) {
            if([self create_midi_int:chunk.size_]!=0)
                break;
        }
        
        R_BUF(word, 2);//format
		fmt = [self create_word:word];
		midi_.format=fmt;
//        NSLog(@"format=%d, fmt=%d", midi_.format, fmt);
        
        R_BUF(word, 2);//track count
		track_cnt = [self create_word:word];
        
        R_BUF(word, 2);//delta time
        midi_.quarter=[self create_word:word];
        
		if (fmt == 0) {
            ITrack *track=[[ITrack alloc]init];
            [midi_.tracks addObject:track];
//			[midi_ addTrack:0];
//            ITrack *track=[midi_ getTrack:0];
			if (![self readTrackData:track from:buffer])
				break;
            
			[self parseHeadInfo:track];
            //			convert0To1(midi_->getTrack(0));
            
			ret = true;
		} else if (fmt == 1) {
			unsigned int i;
//			int offset=0;
			for (i = 0; i < track_cnt; ++i) {
                ITrack *track=[[ITrack alloc]init];
                [midi_.tracks addObject:track];
//				[midi_ addTrack:i-offset];
//                ITrack *track=[midi_ getTrack:i-offset ];
				if (![self readTrackData:track from:buffer])
					break;
                
                if (i==0 && track.events.count==0) {
					[self parseHeadInfo:track];
                    [midi_.tracks removeObject:track];
                }
                /*
                ITrack *track0=[midi_ getTrack:0];
                if (i==0 && track0.events.count==0) {
					[self parseHeadInfo:track0];
                    [midi_ deleteTrack:0];
                    //					midi_->deleteTrack(0);
					offset = 1;
				}
                 */
			}
            
			ret = true;
		}
        
	} while (0);
    
    if (ret) {
        return midi_;
    }
	return nil;
}

- (MidiFile*)loadFromData:(NSData*)data{
    return [self load:data];
}

- (MidiFile*)loadFromFile:(NSString*)file
{
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDir = [documentPaths objectAtIndex:0];
    NSString *path = [documentDir stringByAppendingPathComponent:file];
    NSMutableData *data=[NSMutableData dataWithContentsOfFile:path];
    if (data!=nil) {
        return [self load:data];
    }
    return nil;
}

/*
 save midi
 */


const unsigned char MThd[] = "MThd";
const unsigned char MTrk[] = "MTrk";
const unsigned int SIX = 6;
const unsigned int MAX_TRACK_NUMBER = 32;
const unsigned int END_TRACK = 0x002FFF00;


-(void) midi_int_to_char:(unsigned int) num data:(char*) data
{
	unsigned int i ;
	const unsigned int SIZE = sizeof(unsigned int) ;
	
	for( i=0; i<SIZE; ++i ) {
		data[(SIZE-1)-i] = (char)(num % 256) ;
		num /= 256 ;
	}
}
-(void) midi_word_to_char:(unsigned short) word data:(char*) data
{
	unsigned int i ;
	const unsigned int SIZE = sizeof(unsigned short) ;
	
	for( i=0; i<SIZE; ++i ) {
		data[(SIZE-1)-i] = (char)(word % 256) ;
		word /= 256 ;
	}
}

-(void) writeHead:(NSMutableData *)buffer
{
	char data[2];
	char six[4];
	short format=1;
	short delta_time=120;
	short trk_cnt=0;
//	NSArray* trk_idxs;
    
//	trk_idxs = [midi_ getTrackIndexs];
    
	trk_cnt = [midi_.tracks count]+1;//加上当前主控track
    
	delta_time = midi_.quarter;
    
    //MThd
    [buffer appendBytes:MThd length:4];
    
    //文件头长度：总是00 06
	[self midi_int_to_char:SIX data:six];
    [buffer appendBytes:six length:4];
    
    //格式：00 00 单轨，00 01 多轨且同步, 00 02 多轨不同步
	[self midi_word_to_char:format data:data];
    [buffer appendBytes:data length:sizeof(short)];

    //实际音轨数加一个全局音轨
	[self midi_word_to_char:trk_cnt data:data];
    [buffer appendBytes:data length:sizeof(short)];

    //bit15=0: 一个四分音符的tick数，tick是midi的最小时间单位
    //bit15=1: bit8-14:每秒多少个SMTPE帧（如－24是24帧/秒） bit0-7:每个SMTPE帧的tick数，
	[self midi_word_to_char:delta_time data:data];
    [buffer appendBytes:data length:sizeof(short)];
}

#if 1
-(NSMutableData *)constructDeltaTime:(int) tick
{
    int i;
    char tmp[4];
    int MAX = 5;//����һ���ܴ��ֵ��delta_time������ռ��MAX���ֽ�
    unsigned char data1[5];
    int count=0;
    NSMutableData *data = [[NSMutableData alloc]init];
	for (i = 0; i < MAX; ++i) 
    {
        data1[i]=tick & 0x7F;
		tick >>= 7;
        
		if (tick == 0) {
			count=i+1;
            break;
		}
	}
    
	for (i = 0; i < count; ++i) {
		int idx = (count - i) - 1;
        
		if (idx != 0) {
            tmp[0]=data1[idx]|0x80;
		} else {
            tmp[0]=data1[idx];
		}
        [data appendBytes:tmp length:1];
	}
    
	return data;
}
//全局音轨
- (void) writeMetaEvent:(NSMutableData*)buffer 
{
    
    int i;
    int trunk_start_pos=(int)buffer.length;
    CommonEventCreator *common_events_creator=[[CommonEventCreator alloc]init];

    //MTrk+本音轨长度（不包含MTrk和本身4字节）
    [buffer appendBytes:"MTrk\0\0\0\0" length:8];
    NSLog(@"MTrk 00 00 00 00");
    //auther
    [common_events_creator addText:midi_.author style:0x01];
    //copyright
    [common_events_creator addText:midi_.copyright style:0x02];
    //name
    [common_events_creator addText:midi_.name style:0x03];
    
	NSMutableArray* markers = midi_.markers;
	for (i = 0; i < markers.count; ++i) 
    {
        [common_events_creator addTextEvent:[markers objectAtIndex:i] style:0x06];
        //		common_events_creator.push_back(markers[i], 0x06);
	}
    
	NSMutableArray* cue_points = midi_.cuePoints;
	for (i = 0; i < cue_points.count; ++i) 
    {
        [common_events_creator addTextEvent:[cue_points objectAtIndex:i] style:0x07];
        //		common_events_creator.push_back(cue_points[i], 0x07);
	}
    
	NSMutableArray* tempos = midi_.tempos;
	for (i = 0; i < tempos.count; ++i) {
        [common_events_creator addTempoEvent:[tempos objectAtIndex:i]];
        //		common_events_creator.push_back(tempos->value(i));
	}
    
    NSMutableArray* time_signatures = midi_.timeSignatures;
    for (TimeSignatureEvent *item in time_signatures) {
        [common_events_creator addTimeSignatureEvent:item];
        //		common_events_creator.push_back(time_signatures->value(i));
	}
    
	NSMutableArray* key_signatures = midi_.keySignatures;
    for (KeySignatureEvent *item in key_signatures) {
        [common_events_creator addKeySignatureEvent:item];
		//common_events_creator.push_back(key_signatures->value(i));
	}
    
	NSMutableArray* sys_ex_events = midi_.sysExclusives;
    for (SysExclusiveEvent *item in sys_ex_events) {
        [common_events_creator addSysExclusiveEvent:item];
        //		common_events_creator.push_back(sys_ex_events[i]);
	}
    [common_events_creator sort];
    [common_events_creator absToRel];

    NSMutableArray *common_events = common_events_creator.items;
//	const QList<CommonEvent>& common_events = common_events_creator.getEvents();
    for (CommonEvent *item in common_events) {
//		char* data;
		NSMutableData* delta_time = [self constructDeltaTime:item.tick];
        //NSLog(@"com(%d:%@)", item.tick, item.event);
        [buffer appendData:delta_time];
//		data = new char[delta_time.size()];
//		qCopy(delta_time.begin(), delta_time.end(), data);
//		trunk.write(data, delta_time.size());
//		delete[] data;
        [buffer appendData:item.event];
        /*
        {
            unsigned char* tmp2=[item.event mutableBytes];
            int len2=item.event.length;
            NSString *tmp=[NSString stringWithFormat:@"%d (%d:%02x %02x %02x %02x %02x %02x %02x %02x)",item.tick, len2, tmp2[0], tmp2[1],tmp2[2],tmp2[3], tmp2[4], tmp2[5],tmp2[6],tmp2[7]]; 
            NSLog(@"%@",tmp);
        }*/
//		data = new char[common_events[i].event_.size()];
//		qCopy(common_events[i].event_.begin(), common_events[i].event_.end(), data);
//		trunk.write(data, common_events[i].event_.size());
//		delete[] data;
	}
    
    //endtrack: 0x002FFF00
    [buffer appendBytes:"\x00\xFF\x2F\x00" length:4];
    
    if (buffer.length >= 8) {
		unsigned int i;
		unsigned int size = (int)buffer.length - trunk_start_pos - 8;
        char data[4];
		for (i = 0; i < 4; ++i) {
			data[3 - i] = size % 256;
			size /= 256;
		}
        NSRange range;
        range.location=trunk_start_pos+4;
        range.length=4;
        [buffer replaceBytesInRange:range withBytes:data];
//        [buffer appendBytes:data length:8];
    }
    
}
-(void) writeTrackData:(ITrack*) track to:(NSMutableData*) buffer
{
//    int i;
    int trunk_start_pos=(int)buffer.length;
//	MidiChunkDataFormat trunk;
    CommonEventCreator *common_events_creator=[[CommonEventCreator alloc]init];    
    [buffer appendBytes:"MTrk\0\0\0\0" length:8];
    NSLog(@"MTrk 00 00 00 06");

    if (track.name!=nil) {
		TextEvent *ev=[[TextEvent alloc]init];
		ev.tick = 0;
		ev.text = track.name;
        
        [common_events_creator addTextEvent:ev style:3];
    }
    
    for (TextEvent *item in track.texts) {
        [common_events_creator addTextEvent:item style:0x01];//
        
    }

    for (TextEvent *item in track.lyrics) {
        [common_events_creator addTextEvent:item style:0x05];//
    }

    for (SpecificInfoEvent *item in track.specificEvents) {
        [common_events_creator addSpecificInfoEvent:item];//
    }
    
    for (Event *item in track.events) {
        [common_events_creator addEvent:item];
//        NSLog(@"ev %d:0x%x", item.tick, item.event);
        NSLog(@"ev %d:0x%x,0x%x,0x%x", item.tick, item.evt,item.nn,item.vv);
    }
    
	[common_events_creator sort];
	[common_events_creator absToRel];
    
    NSMutableArray *common_events = common_events_creator.items;
//	const QList<CommonEvent>& common_events = common_events_creator.getEvents();
//	for (i = 0; i < common_events.size(); ++i) {
    for (CommonEvent *item in common_events) {
//		char* data;
//		QList<unsigned char> delta_time = constructDeltaTime(common_events[i].tick_);
        //NSLog(@"com(%d:%@)", item.tick, item.event);
        
        NSMutableData* delta_time = [self constructDeltaTime:item.tick];        
        [buffer appendData:delta_time];

//		data = new char[delta_time.size()];
//		qCopy(delta_time.begin(), delta_time.end(), data);
        
//		trunk.write(data, delta_time.size());
        
//		delete[] data;

        [buffer appendData:item.event];
        /*
        {
            unsigned char* tmp2=[item.event mutableBytes];
            int len2=item.event.length;
            NSString *tmp=[NSString stringWithFormat:@"%d (%d:%02x %02x %02x %02x)",item.tick, len2, tmp2[0], tmp2[1],tmp2[2],tmp2[3]]; 
            NSLog(@"%@",tmp);
        }
         */
//		data = new char[common_events[i].event_.size()];
//		qCopy(common_events[i].event_.begin(), common_events[i].event_.end(), data);
        
//		trunk.write(data, common_events[i].event_.size());
        
//		delete[] data;
	}
    
    //endtrack: 0x002FFF00
    [buffer appendBytes:"\x00\xFF\x2F\x00" length:4];
    
    if (buffer.length >= 8) {
		unsigned int i;
		unsigned int size = (int)buffer.length - trunk_start_pos - 8;
        char data[4];
		for (i = 0; i < 4; ++i) {
			data[(3 - i)] = size % 256;
			size /= 256;
		}
        NSRange range;
        range.location=trunk_start_pos+4;
        range.length=4;
        [buffer replaceBytesInRange:range withBytes:data];
//        [buffer appendBytes:data length:8];
    }
}
#endif
- (NSMutableData*)saveMidi:(MidiFile*)midi ToFile:(NSString*)file
{
    NSMutableData *data;
    data=[[NSMutableData alloc]init ];
    midi_ = midi;

    [self writeHead:data];
    [self writeMetaEvent:data];
    
    
    for (ITrack *track in midi_.tracks) {
        [self writeTrackData:track to:data];
    }
    
    if (file!=nil) {
        NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDir = [documentPaths objectAtIndex:0];
        NSString *path = [documentDir stringByAppendingPathComponent:file];
        [data writeToFile:path atomically:YES];
    }
    
    return data;
}

@end
