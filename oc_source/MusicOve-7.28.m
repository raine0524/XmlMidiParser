//
//  MusicOve.m
//  ReadStaff
//
//  Created by yan bin on 11-8-28.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "MusicOve.h"
//#import <objc/objc-class.h>
#import <objc/runtime.h>


NSString *stringFromBuffer(char *buffer);


typedef struct {
    UInt32 tags;
    UInt32 size;
}MuskBlock;


#define WRITE_ARRAY(tag, class, arr) \
{   \
if (arr)    \
{   \
    [writeData appendBytes:tag length:4];   \
    UInt32 len=8+2;    \
    NSMutableData *data=[[NSMutableData alloc]init];   \
    for (class *page in arr) { \
        NSData *tmp_data=[page writeToData];    \
        len+=tmp_data.length; \
        [data appendData:tmp_data]; \
    }   \
    [writeData appendBytes:&len length:4];    \
    short count=arr.count;  \
    [writeData appendBytes:&count length:sizeof(count)];    \
    [writeData appendData:data];    \
}   \
}

static int local_pos=0;
#define MUSK_SET_POS(pos) local_pos=pos;

#define MUSK_READ_BUF(buf, len) \
{   \
    NSRange range;  \
    range.location=local_pos;   \
    range.length=len;   \
    [ovsData getBytes:buf range:range]; \
    local_pos+=len; \
}

#define CHECK_TAGS(tag) \
{   \
    local_pos=next_tag_pos; \
    char tags[4];   \
    MUSK_READ_BUF(tags, 4); \
    if (memcmp(tag, tags, 4)!=0){    \
        local_pos-=4;\
    }else{   \
        UInt32 len_block;    \
        MUSK_READ_BUF(&len_block, 4);   \
        next_tag_pos+=len_block;  \
    }   \
}
/*
#define READ_ARR(tag, class, arr)    \
{   \
    if(next_tag_pos<ovsData.length){    \
    local_pos=next_tag_pos; \
    char tags[4];   \
    MUSK_READ_BUF(tags, 4); \
    if (memcmp(tag, tags, 4)!=0){    \
        local_pos-=4;\
    }else{   \
        uint32 len_block;    \
        MUSK_READ_BUF(&len_block, 4);   \
        next_tag_pos+=len_block;  \
        short count;    \
        MUSK_READ_BUF(&count, 2);   \
        if (count>0) {  \
            arr=[[NSMutableArray alloc]initWithCapacity:count]);    \
            for (int i=0; i<count; i++) {   \
                class *item=[class loadFromOvsData:ovsData]; \
                [arr addObject:item];   \
            }   \
        }   \
    }   \
    } \
}
*/
enum VMUS_TAG {
    TITL = 'LTIT',
    PAGS = 'SGAP',
    LINS = 'SNIL',
    TRKS = 'SKRT',
    MEAS = 'SAEM',
    MUSK = 'KSUM',
};

//UInt32 len_block
//UInt16 array_count
//arrays
#define READ_ARRS(class, arr)    \
{   \
    if(next_tag_pos<ovsData.length){    \
        UInt32 start=local_pos-4,len_block;    \
        MUSK_READ_BUF(&len_block, 4);   \
        next_tag_pos+=len_block;  \
        short count;    \
        MUSK_READ_BUF(&count, 2);   \
        if (count>0) {  \
            arr=[[NSMutableArray alloc]initWithCapacity:count];    \
            for (int i=0; i<count; i++) {   \
                class *item=[class loadFromOvsData:ovsData]; \
                [arr addObject:item]; \
            } \
        } \
        local_pos=start+len_block; \
    } \
}

//UInt16 array_count
//arrays
#define READ_ARRS_1(class, arr)    \
{   \
short count;    \
MUSK_READ_BUF(&count, 2);   \
if (count>0) {  \
    arr=[[NSMutableArray alloc]initWithCapacity:count];    \
    for (int i=0; i<count; i++) {   \
        class *item=[class loadFromOvsData:ovsData]; \
        if(item)[arr addObject:item]; \
        else break; \
    } \
} \
}

NSString *stringFromBuffer(char *buffer)
{
    NSString *tmp;
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding (kCFStringEncodingGB_18030_2000);
    tmp = [[NSString alloc] initWithCString:buffer encoding:enc];
    if (tmp==nil) {
        tmp = [[NSString alloc] initWithCString:buffer encoding:NSUTF8StringEncoding];
    }
    return tmp;
}

@interface OveData()
{
    NSData *ove_data;
    
    int _buffer_index;
    int _buffer_size;
}
@end

@implementation OveData

//#define DEBUG_INDEX NSLog(@"0x%x",_buffer_index)
- (void) debug_index
{
    NSLog(@"0x%x",_buffer_index);
}

- (id) initWithData:(NSData*) data
{
    self = [super init];
    if (self) {
        ove_data = data;
        _buffer_index=0;
        _buffer_size = (int)[ove_data length];
    }
    return self;
}

- (bool) seek:(int)pos
{
    if(pos<_buffer_size && pos>=0)
    {
        _buffer_index=pos;
        return true;
    }
    return false;
}
- (NSString*) readString:(int)size {
    NSString *ret=nil;
    char *buffer=malloc(size+1);
    buffer[size]=0;
    if ([self readBuffer:(unsigned char*)buffer size:size]) {
        NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding (kCFStringEncodingGB_18030_2000);
        ret = [[NSString alloc] initWithCString:buffer encoding:enc];
        if (ret==nil) {
            ret = [[NSString alloc] initWithCString:buffer encoding:NSUTF8StringEncoding];
        }
    }
    free(buffer);
    return ret;
}

- (bool) readBuffer:(unsigned char *)buf size:(int) size
{
    if(_buffer_index>=_buffer_size)
    {
        NSLog(@"readBuffer overflow.");
        return false;
    }
    NSRange range;
    range.location=_buffer_index;
    range.length=size;
    [ove_data getBytes:buf range:range];
    //    memcpy(buf, &_buffer[_buffer_size], size);
    _buffer_index+=size;
    if(_buffer_index>=_buffer_size)
    {
        NSLog(@"readBuffer overflow.");
        return false;
    }
    //    NSLog(@"0x%x",_buffer_index);
    return true;
}
- (bool) jump:(int) size
{
    if(_buffer_index+size>=_buffer_size)
    {
        //NSLog(@"jump overflow.");
        NSLog(@"jump overflow=0x%x size=%d",_buffer_index, size);
        return false;
    }
    _buffer_index+=size;
    return true;
}

- (bool) back:(int) size
{
    if(_buffer_index<size) return false;
    _buffer_index-=size;
    //    NSLog(@"0x%x",_buffer_index);
    return true;
}

- (unsigned int) toUnsignedInt:(unsigned char *)data size:(int) size
{
	if (data == NULL) {
		return 0;
	}
    
	unsigned int i;
	unsigned int num=0;
    
	for (i = 0; i < sizeof(unsigned int) && i < size; ++i) {
		num = (num << 8) + *(data + i);
	}
    
	return num;
}

-(bool) readShort: (unsigned short*)value
{
    unsigned char buf[2];
    int size=2;
    
    if(_buffer_index>=_buffer_size)
    {
        NSLog(@"readShort overflow.");
        return false;
    }
    NSRange range;
    range.location=_buffer_index;
    range.length=size;
    [ove_data getBytes:buf range:range];
    //    memcpy(buf, &_buffer[_buffer_size], size);
    _buffer_index+=size;
    //    NSLog(@"0x%x",_buffer_index);
    if(_buffer_index>=_buffer_size)
    {
        NSLog(@"readShort overflow=0x%x",_buffer_index);
        return false;
    }

    *value = [self toUnsignedInt:buf size:size];
    return true;
}

-(bool) readLong: (UInt32*)value
{
    unsigned char buf[4];
    int size=4;
    
    if(_buffer_index>=_buffer_size)
    {
        NSLog(@"readLong overflow.");
        return false;
    }
    NSRange range;
    range.location=_buffer_index;
    range.length=size;
    [ove_data getBytes:buf range:range];
    //    memcpy(buf, &_buffer[_buffer_size], size);
    _buffer_index+=size;
    //    NSLog(@"0x%x",_buffer_index);
    if(_buffer_index>=_buffer_size)
    {
        NSLog(@"readLong overflow=0x%x",_buffer_index);
        return false;
    }

    *value = [self toUnsignedInt:buf size:size];
    return true;
}
@end

bool isVersion4;

#define READ_STR(len) [[OveMusic ove_data] readString:len]
#define READ_BUF(val,len) if(![[OveMusic ove_data] readBuffer:(unsigned char*)val size:len]){return false;}
#define READ_U8(val) if(![[OveMusic ove_data] readBuffer:(unsigned char*)&(val) size:1]){return false;}
#define READ_U16(val) if(![[OveMusic ove_data] readShort:(unsigned short*)&(val)]){return false;}
#define READ_U32(val) if(![[OveMusic ove_data] readLong:(UInt32*)&(val)]){return false;}

#define READ_U8_BOOL(val)   \
{                           \
unsigned char thisByte;     \
READ_U8(thisByte)           \
val = (thisByte!=0);         \
}
#define SEEK(pos)    if (![[OveMusic ove_data] seek: pos]) {return false;}
#define JMP(num)     if (![[OveMusic ove_data] jump: num]) {return false;}
#define BACK(num)    if (![[OveMusic ove_data] back: num]) {return false;}
#define DEBUG_INDEX  [[OveMusic ove_data] debug_index];


struct OffsetElementStruct {
    signed short offset_x, offset_y;
};

@implementation OffsetElement


- (bool)parse
{    
	// x offset
    READ_U16(_offset_x)
    
	// y offset
    READ_U16(_offset_y)
    
	return true;
}
+ (OffsetElement*)parseOffsetElement
{
    OffsetElement *elem=[[OffsetElement alloc]init];
    [elem parse];
    return  elem;
}
@end

struct OffsetCommonBlockStruct {
    signed short stop_measure,stop_offset;
};

@implementation OffsetCommonBlock

- (bool)parse
{
	// offset measure
    READ_U16(_stop_measure)
    
	// end unit
    READ_U16(_stop_offset)
    
	return true;
}
+ (OffsetCommonBlock*)parseOffsetCommonBlock
{
    OffsetCommonBlock *offset=[[OffsetCommonBlock alloc]init];
    [offset parse];
    return offset;
}
@end
struct CommonBlockStruct {
    signed short start_offset, tick;
};
@implementation CommonBlock

- (bool) parse
{    
	// start tick
    READ_U16(_tick)
    
	// start unit
    READ_U16(_start_offset)
    
	if( isVersion4 )
    {
		// color
        READ_U8(color)
        JMP(1)
	}
    
	return true;
}
+ (CommonBlock*)parseCommonBlock
{
    CommonBlock *common=[[CommonBlock alloc]init];
    [common parse];
    return common;
}
@end

struct PairEndsStruct {
    signed short left_line, right_line;
};
@implementation PairEnds

-(bool)parse
{
	// left line
    READ_U16(_left_line)
    
	// right line
    READ_U16(_right_line)
    
	return true;
}
+(PairEnds*)parsePairLinesBlock
{
    PairEnds *common=[[PairEnds alloc]init];
    [common parse];
    return common;
}
@end

@implementation OveText

typedef struct{
    short staff;
    SInt32 offset_x;
    SInt16 offset_y;
    
    UInt8 font_size;
    unsigned char isBold:1;
    unsigned char isItalic:1;
    unsigned char reserved1:6;
    
    struct CommonBlockStruct pos;
    unsigned short text_len;
}TextDataStruct;

- (NSData*) writeToData
{
    TextDataStruct dataStruct={
        .staff=self.staff,
        .offset_x=self.offset_x,
        .offset_y=self.offset_y,
        .font_size=self.font_size,
        .isBold=self.isBold,
        .isItalic=self.isItalic,
        .pos={self.pos.start_offset, self.pos.tick},
        .text_len=0
    };
    const char *exp_text=self.text.UTF8String;
    if (self.text.length>0) {
        dataStruct.text_len=strlen(exp_text);
    }
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    if (dataStruct.text_len>0) {
        [writeData appendBytes:exp_text length:dataStruct.text_len];
    }
    return writeData;
}

+ (OveText*)loadFromOvsData:(NSData*)ovsData
{
    TextDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    OveText *beam=[[OveText alloc]init];
    beam.staff=data.staff;
    beam.offset_y=data.offset_y;
    beam.offset_x=data.offset_x;
    if (data.font_size<0xFF) {
        beam.font_size=data.font_size;
        beam.isBold=data.isBold;
        beam.isItalic=data.isItalic;
    }
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    if (data.text_len>0) {
        char *text=malloc(data.text_len+1);text[data.text_len]=0;
        MUSK_READ_BUF(text, data.text_len);
        beam.text=[NSString stringWithUTF8String:text];
        free(text);
    }
    return beam;
}
- (id)init
{
    self = [super init];
    if (self) {
        self.font_size=20;
        self.isBold=NO;
        self.isItalic=NO;
    }
    return self;
}
- (bool) parse: (int) length
{
    JMP(3)
    
    if (self.pos) {
        NSLog(@"Error: too many text");
    }
    self.pos = [CommonBlock parseCommonBlock];
    
	// type
    unsigned char thisByte;
    READ_U8(thisByte)
    
	includeLineBreak = (((thisByte)&0x20) != 0x20 );
	ID = thisByte&0x0F;
    
	if (ID == 0) {
		textType = Text_MeasureText;
	} else if (ID == 1) {
		textType = Text_SystemText;
	} else // id ==2
	{
		textType = Text_Rehearsal;
	}
    
    JMP(1)

	// x offset
    READ_U32(_offset_x)
    
	// y offset
    READ_U32(_offset_y)
    
	// width
    READ_U32(width)
    
	// height
    READ_U32(height)
    
    JMP(7)
    
	// horizontal margin
    READ_U8(horizontal_margin)
    
    JMP(1)
    
	// vertical margin
    READ_U8(vertical_margin)

    JMP(1)
    
	// line thick
    READ_U8(line_thick)
    
    JMP(2)
    
	// text size
    unsigned short size;
    READ_U16(size)
    
	// text string, maybe huge
//    char *textBuf;
    if (size>1024) {
        NSLog(@"error: Text too long. (size=%d)", size);
    }
//    textBuf=malloc(size+1);textBuf[size]=0;
    self.text=READ_STR(size);
    
//    self.text = stringFromBuffer(textBuf);//[NSString stringWithCString:text encoding:enc];
//    free(textBuf);
    
    //NSLog(@"Text:%@", text_text);
    
    if( !includeLineBreak ) {
        JMP(6)
	} else {
		unsigned int cursor = isVersion4 ? 43 : 41;
		cursor += size;
        
		// multi lines of text
		for( unsigned int i=0; i<2; ++i ) 
        {
			if( (int)cursor < length ) 
            {
				// line parameters count
                unsigned short lineCount;
                READ_U16(lineCount)
                
				if( i==0 && (cursor + 2 + 8*lineCount) > length ) {
					return false;
				}
                
				if( i==1 && (cursor + 2 + 8*lineCount) != length ) {
					return false;
				}
                
                JMP(8*lineCount)
                
				cursor += 2 + 8*lineCount;
			}
		}
	}
    
	return true;
}
+(OveText *) parseText:(int)length staff:(int)staff
{
    OveText *tt=[[OveText alloc]init];
    //NSLog(@"staff:%d", staff);
    [tt parse:length];
    tt.staff=staff;
    return tt;
}
@end


@implementation OveImage

typedef struct{
    short staff;
    SInt32 offset_x, offset_y;
    UInt16 width, height;
    struct CommonBlockStruct pos;
    unsigned short type;
    unsigned short source_len;
}ImageDataStruct;

- (NSData*) writeToData
{
    ImageDataStruct dataStruct={
        .staff = self.staff, .offset_x = self.offset_x, .offset_y = self.offset_y,
        .width=self.width, .height=self.height,
        .pos={self.pos.start_offset, self.pos.tick},
        .type=self.type,
        .source_len=0,
    };
    const char *source=self.source.UTF8String;
    if (self.source.length>0) {
        dataStruct.source_len=strlen(source);
    }
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    if (dataStruct.source_len>0) {
        [writeData appendBytes:source length:dataStruct.source_len];
    }
    return writeData;
}

+ (OveImage*)loadFromOvsData:(NSData*)ovsData
{
    ImageDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    OveImage *beam=[[OveImage alloc]init];
    beam.staff=data.staff;
    beam.offset_y=data.offset_y;
    beam.offset_x=data.offset_x;
    beam.width=data.width;
    beam.height=data.height;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    beam.type=data.type;
    if (data.source_len>0) {
        char *source=malloc(data.source_len+1);source[data.source_len]=0;
        MUSK_READ_BUF(source, data.source_len);
        beam.source=[NSString stringWithUTF8String:source];
        free(source);
    }
    return beam;
}
@end

@implementation MeasureExpressions
typedef struct{
    short staff, offset_y;
    struct CommonBlockStruct pos;
    unsigned short exp_text_len;
    
    //@property (nonatomic,retain) NSString *exp_text;

}ExpressionDataStruct;

- (NSData*) writeToData
{
    /*
     @property (nonatomic, retain) NSMutableArray *beam_elems;
     */
    ExpressionDataStruct dataStruct={
        self.staff, self.offset_y,
        {self.pos.start_offset, self.pos.tick},
        0
    };
    const char *exp_text=self.exp_text.UTF8String;
    if (self.exp_text.length>0) {
        dataStruct.exp_text_len=strlen(exp_text);
    }
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    if (dataStruct.exp_text_len>0) {
        [writeData appendBytes:exp_text length:dataStruct.exp_text_len];
    }
    return writeData;
}

+ (MeasureExpressions*)loadFromOvsData:(NSData*)ovsData
{
    ExpressionDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    MeasureExpressions *beam=[[MeasureExpressions alloc]init];
    beam.staff=data.staff;
    beam.offset_y=data.offset_y;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    if (data.exp_text_len>0) {
        char *text=malloc(data.exp_text_len+1);text[data.exp_text_len]=0;
        MUSK_READ_BUF(text, data.exp_text_len);
        beam.exp_text=[NSString stringWithUTF8String:text];
        free(text);
    }
    return beam;
}

- (bool) parseExpressions:(int) length staff:(int)staff_num
{
    self.staff = staff_num;
    
    JMP(3)
    
    self.pos = [CommonBlock parseCommonBlock];
    
    JMP(2)
    
	// y offset
    READ_U16(_offset_y)
    
	// range bar offset
    READ_U16(barOffset)
    
    JMP(10)
    
	// tempo 1
    READ_U16(tempo1)
    tempo1 /= 100;
	//double tempo1 = ((double)placeHolder.toUnsignedInt()) / 100.0;
    
	// tempo 2
    READ_U16(tempo2)
    tempo2 /= 100;
	//double tempo2 = ((double)placeHolder.toUnsignedInt()) / 100.0;
    
    JMP(6)
    
	// text
	int cursor = isVersion4 ? 35 : 33;
	if( length > cursor ) 
    {
        char text[100];
        READ_BUF(text, length-cursor)
        text[length-cursor]=0;
        //        direction.placement=(offset_y<0)?@"above":@"below";
        self.exp_text=[NSString stringWithCString:text encoding:NSUTF8StringEncoding];
//        NSLog(@"Expressions text=%@", exp_text);
	}
    
	return true;
}

@end

@implementation MeasureDecorators

typedef struct{
    char staff,decoratorType,artType;
    char reserved;
    short offset_y;
    struct CommonBlockStruct pos;
}DecoratorDataStruct;

- (NSData*) writeToData
{
    DecoratorDataStruct dataStruct={
        self.staff, self.decoratorType,self.artType,
        0,
        self.offset_y,
        {self.pos.start_offset, self.pos.tick},
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    return writeData;
}

+ (MeasureDecorators*)loadFromOvsData:(NSData*)ovsData
{
    DecoratorDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    MeasureDecorators *beam=[[MeasureDecorators alloc]init];
    beam.staff=data.staff;
    beam.offset_y=data.offset_y;
    beam.decoratorType=data.decoratorType;
    beam.artType=data.artType;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    return beam;
}

- (bool) getDecoratorType:(unsigned int) thisByte 
            measureRepeat:(BOOL*) measureRepeat
             singleRepeat:(BOOL*) singleRepeat
{
	*measureRepeat = NO;
	self.decoratorType = Decorator_Articulation;
	*singleRepeat = YES;
	self.artType = Articulation_None;
    
	switch (thisByte) {
        case 0x00: {
            self.decoratorType = Decorator_Dotted_Barline;
            break;
        }
        case 0x2C:
            self.artType = Articulation_Toe_Pedal;
            break;
        case 0x2D:
            self.artType = Articulation_Heel_Pedal;
            break;
        case 0x30: {
            self.artType = Articulation_Open_String;
            break;
        }
        case 0xf1:
        case 0x31: {
            self.artType = Articulation_Finger;
            self.finger=@"1";
            break;
        }
        case 0xf2:
        case 0x32: {
            self.artType = Articulation_Finger;
            self.finger=@"2";
            break;
        }
        case 0xf3:
        case 0x33: {
            self.artType = Articulation_Finger;
            self.finger=@"3";
            break;
        }
        case 0xf4:
        case 0x34: {
            self.artType = Articulation_Finger;
            self.finger=@"4";
            break;
        }
        case 0xf5:
        case 0x35: {
            self.artType = Articulation_Finger;
            self.finger=@"5";
            break;
        }
        case 0x6B: {
            self.artType = Articulation_Flat_Accidental_For_Trill;
            break;
        }
        case 0x6C: {
            self.artType = Articulation_Sharp_Accidental_For_Trill;
            break;
        }
        case 0x6D: {
            self.artType = Articulation_Natural_Accidental_For_Trill;
            break;
        }
        case 0x8d: {
            *measureRepeat = true;
            *singleRepeat = true;
            break;
        }
        case 0x8e: {
            *measureRepeat = true;
            *singleRepeat = false;
            break;
        }
        case 0xA0: {
            self.artType = Articulation_Minor_Trill;
            break;
        }
        case 0xA1: {
            self.artType = Articulation_Major_Trill;
            break;
        }
        case 0xA2: {
            self.artType = Articulation_Trill_Section;
            break;
        }
        case 0xA3: {
            self.artType = Articulation_Inverted_Short_Mordent;
            break;
        }
        case 0xA4: {
            self.artType = Articulation_Inverted_Long_Mordent;
            break;
        }
        case 0xA5: {
            self.artType = Articulation_Short_Mordent;
            break;
        }
        case 0xA6: {
            self.artType = Articulation_Turn;
            break;
        }
        case 0xA8: {
            self.artType = Articulation_Tremolo_Eighth;
            break;
        }
        case 0xA9: {
            self.artType = Articulation_Tremolo_Sixteenth;
            break;
        }
        case 0xAA: {
            self.artType = Articulation_Tremolo_Thirty_Second;
            break;
        }
        case 0xAB: {
            self.artType = Articulation_Tremolo_Sixty_Fourth;
            break;
        }
        case 0xB2: {
            self.artType = Articulation_Fermata;
            break;
        }
        case 0xB3: {
            self.artType = Articulation_Fermata_Inverted;
            break;
        }
        case 0xB9: {
            self.artType = Articulation_Pause;
            break;
        }
        case 0xBA: {
            self.artType = Articulation_Grand_Pause;
            break;
        }
        case 0xC0: {
            self.artType = Articulation_Marcato;
            break;
        }
        case 0xC1: {
            self.artType = Articulation_Marcato_Dot;
            break;
        }
        case 0xC2: {
            self.artType = Articulation_SForzando;
            break;
        }
        case 0xC3: {
            self.artType = Articulation_SForzando_Dot;
            break;
        }
        case 0xC4: {
            self.artType = Articulation_SForzando_Inverted;
            break;
        }
        case 0xC5: {
            self.artType = Articulation_SForzando_Dot_Inverted;
            break;
        }
        case 0xC6: {
            self.artType = Articulation_Staccatissimo;
            break;
        }
        case 0xC7: {
            self.artType = Articulation_Staccato;
            break;
        }
        case 0xC8: {
            self.artType = Articulation_Tenuto;
            break;
        }
        case 0xC9: {
            self.artType = Articulation_Natural_Harmonic;
            break;
        }
        case 0xCA: {
            self.artType = Articulation_Artificial_Harmonic;
            break;
        }
        case 0xCB: {
            self.artType = Articulation_Plus_Sign;
            break;
        }
        case 0xCC: {
            self.artType = Articulation_Up_Bow;
            break;
        }
        case 0xCD: {
            self.artType = Articulation_Down_Bow;
            break;
        }
        case 0xCE: {
            self.artType = Articulation_Up_Bow_Inverted;
            break;
        }
        case 0xCF: {
            self.artType = Articulation_Down_Bow_Inverted;
            break;
        }
        case 0xD0: {
            self.artType = Articulation_Pedal_Down;
            break;
        }
        case 0xD1: {
            self.artType = Articulation_Pedal_Up;
            break;
        }
        case 0xD6: {
            self.artType = Articulation_Heavy_Attack;
            break;
        }
        case 0xD7: {
            self.artType = Articulation_Heavier_Attack;
            break;
        }
        default:
            return false;
            break;
	}
    
	return true;
}
- (bool) parse:(int)length
{
    JMP(3)
    
	// common
    self.pos = [CommonBlock parseCommonBlock];
    
    JMP(2)
    
	// y offset
    READ_U16(_offset_y)
    
    JMP(2)
    
	// measure repeat | piano pedal | dotted barline | articulation
    unsigned char thisByte;
    READ_U8(thisByte)
    
    if (![self getDecoratorType:thisByte measureRepeat:&isMeasureRepeat singleRepeat:&isSingleRepeat]) {
        NSLog(@"Error: unknow artType=0x%x", thisByte);
    }
    /*
     if( isMeasureRepeat ) {
     MeasureRepeat* measureRepeat = new MeasureRepeat();
     measureData->addCrossMeasureElement(measureRepeat, true);
     
     measureRepeat->copyCommonBlock(*musicData);
     measureRepeat->setYOffset(musicData->getYOffset());
     
     measureRepeat->setSingleRepeat(isSingleRepeat);
     } else {
     Decorator* decorator = new Decorator();
     measureData->addMusicData(decorator);
     
     decorator->copyCommonBlock(*musicData);
     decorator->setYOffset(musicData->getYOffset());
     
     decorator->setDecoratorType(decoratorType);
     decorator->setArticulationType(artType);
     }
     */
    
	int cursor = isVersion4 ? 16 : 14;
    JMP(length-cursor)
    
	return true;
}
+ (MeasureDecorators*) parseDecorator:(int)length staff:(int)staff_num{
    MeasureDecorators *decorator=[[MeasureDecorators alloc]init];
    decorator.staff=staff_num;
    [decorator parse:length];
    return decorator;
}
@end

@implementation MeasureClef

typedef struct{
    char staff,clef;
    short note_index;
    struct CommonBlockStruct pos;
}ClefDataStruct;

- (NSData*) writeToData
{
    ClefDataStruct dataStruct={
        self.staff,  self.clef,
        self.note_index,
        {self.pos.start_offset, self.pos.tick},
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    return writeData;
}

+ (MeasureClef*)loadFromOvsData:(NSData*)ovsData
{
    ClefDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    MeasureClef *beam=[[MeasureClef alloc]init];
    beam.staff=data.staff;
    beam.note_index=data.note_index;
    beam.clef=data.clef;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    return beam;
}

- (BOOL) parse:(int)noteIndex staff:(int)staff_num
{
    unsigned char thisByte;
    
    self.note_index = noteIndex;
    self.staff = staff_num;
    
    JMP(1)
    READ_U16(voice)
    self.pos = [CommonBlock parseCommonBlock];
    READ_U8(thisByte)  //低4bit: 0-15
    self.clef = thisByte;
    READ_U8(line)
    JMP(2)
    
    return YES;
}
+ (MeasureClef*) parseClef:(int)noteIndex staff:(int) staff_num
{
    MeasureClef *clef = [[MeasureClef alloc]init];
    [clef parse:noteIndex staff:staff_num];
    return clef;
}
@end

@implementation OveDynamic
typedef struct{
    char staff, playback,dynamics_type;
    unsigned char velocity;
    short offset_y;
    struct CommonBlockStruct pos;
}DynamicDataStruct;

- (NSData*) writeToData
{
    /*
     @property (nonatomic, retain) NSMutableArray *beam_elems;
     */
    DynamicDataStruct dataStruct={
        self.staff, self.playback, self.dynamics_type,
        self.velocity,
        self.offset_y,
        {self.pos.start_offset, self.pos.tick},
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    return writeData;
}

+ (OveDynamic*)loadFromOvsData:(NSData*)ovsData
{
    DynamicDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    OveDynamic *beam=[[OveDynamic alloc]init];
    beam.staff=data.staff;
    beam.offset_y=data.offset_y;
    beam.playback=data.playback;
    beam.dynamics_type=data.dynamics_type;
    beam.velocity=data.velocity;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    return beam;
}



-(BOOL) parse: (int)length
{
    unsigned char thisByte;
    
    //                    Dynamics* dynamics = new Dynamics();
    //                    measureData->addMusicData(dynamics);
    JMP(1)
    
    // is playback
    READ_U8(thisByte)
    self.playback = (thisByte>>4)!=0x04;
    //                    if( !readBuffer(placeHolder, 1) ) { return false; }
    //                    dynamics->setIsPlayback(getHighNibble(placeHolder.toUnsignedInt())!=0x4);
    JMP(1)
    
    // common
    self.pos = [CommonBlock parseCommonBlock];
    
    // y offset
    READ_U16(_offset_y)  // in points from center staff??
    //                    if( !readBuffer(placeHolder, 2) ) { return false; }
    //                    dynamics->setYOffset(placeHolder.toInt());
    
    // dynamics type
    READ_U8(thisByte)
    self.dynamics_type=thisByte&0x0F;
    //                    dynamics->setDynamicsType(getLowNibble(placeHolder.toUnsignedInt()));
    
    
    // velocity
    READ_U8(_velocity)
    //                    dynamics->setVelocity(placeHolder.toUnsignedInt());
    
    int cursor = isVersion4 ? 4 : 2;
    
    JMP(cursor)
    return YES;
}
+(OveDynamic*) parseDynamics: (int)length staff:(int)staff_num
{
    OveDynamic *dyn=[[OveDynamic alloc]init];
    [dyn parse:length];
    dyn.staff=staff_num;
    return dyn;
}
@end

@implementation BeamElem
- (bool)parse:(int)length
{
    unsigned char thisByte;
    //JMP(1)
    READ_U8(thisByte) //btyp: // b0-b2=level b3=?? b6-b7=type
    
    self.level = thisByte&0x07;
    self.beam_type = (thisByte>>6)&0x03;  //0: normal, 2: forward hook, 3: backward hook
    
    // tuplet
    READ_U8(_tupletCount)
    if( self.tupletCount > 0 ) {
        //createTuplet = true;
        //                            tuplet->setTuplet(tupletCount);
        //                            tuplet->setSpace(tupletToSpace(tupletCount));
    }
    
    // start / stop measure
    // line i start end position
    //                        MeasurePos startMp;
    //                        MeasurePos stopMp;
    
    READ_U8(_start_measure_pos)
    READ_U8(_stop_measure_pos)
    //                        startMp.setMeasure(placeHolder.toUnsignedInt());
    //                        stopMp.setMeasure(placeHolder.toUnsignedInt());
    READ_U16(_start_measure_offset)
    READ_U16(_stop_measure_offset)
    //                        startMp.setOffset(placeHolder.toInt());
    //                        stopMp.setOffset(placeHolder.toInt());
    
    //                        beam->addLine(startMp, stopMp);
    
    
    
    return YES;
}
+ (BeamElem*)parseBeamElem:(int)length
{
    BeamElem *tmp=[[BeamElem alloc]init];
    [tmp parse:length];
    return tmp;
}
@end

@implementation OveBeam

typedef struct{
    char staff, voice;
    signed char left_line,right_line;
    unsigned char tupletCount;
    unsigned char stop_staff;
    struct CommonBlockStruct pos;
    //short beam_elem_count;//高字节在后面，低字节在前面
    char beam_elem_count;
    char isGrace:1;
    char reserved:7;
}BeamDataStruct;

typedef struct{
    unsigned char level;
    unsigned char tupletCount;
    unsigned char start_measure_pos,stop_measure_pos;
    char beam_type;
    char reserved;
    signed short start_measure_offset, stop_measure_offset;
}BeamElemDataStruct;

- (NSData*) writeToData
{
    BeamDataStruct dataStruct={
        .staff = self.staff, .voice=self.voice,
        .left_line = self.left_line, .right_line=self.right_line,
        .tupletCount=self.tupletCount, .stop_staff=self.stop_staff,
        .pos={self.pos.start_offset, self.pos.tick},
        .beam_elem_count=self.beam_elems.count,
        .isGrace=self.isGrace?1:0,
        .reserved=0,
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    
    for (BeamElem *elem in self.beam_elems) {
        BeamElemDataStruct data={
            elem.level,elem.tupletCount,
            elem.start_measure_pos,elem.stop_measure_pos,
            elem.beam_type, 0,
            elem.start_measure_offset,elem.stop_measure_offset
        };
        [writeData appendBytes:&data length:sizeof(data)];
    }
    return writeData;
}

+ (OveBeam*)loadFromOvsData:(NSData*)ovsData
{
    BeamDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    OveBeam *beam=[[OveBeam alloc]init];
    beam.staff=data.staff;
    //beam.stop_staff=data.staff;
    if (data.stop_staff>0 && data.stop_staff-data.staff>=-1 && data.stop_staff-data.staff<=1) {
        beam.stop_staff=data.stop_staff;
    }else{
        beam.stop_staff=data.staff;
    }
    beam.voice=data.voice;
    beam.left_line=data.left_line;
    beam.right_line=data.right_line;
    beam.tupletCount=data.tupletCount;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    beam.isGrace=(data.isGrace)?YES:NO;
    
    
    if (data.beam_elem_count>0) {
        BeamElemDataStruct elem_data;
        beam.beam_elems=[[NSMutableArray alloc]initWithCapacity:data.beam_elem_count];
        for (int i=0; i<data.beam_elem_count; i++) {
            MUSK_READ_BUF(&elem_data, sizeof(BeamElemDataStruct));
            BeamElem *elem=[[BeamElem alloc]init];
            [beam.beam_elems addObject:elem];
            elem.level=elem_data.level;
            elem.tupletCount=elem_data.tupletCount;
            elem.beam_type=elem_data.beam_type;
            elem.start_measure_offset=elem_data.start_measure_offset;
            elem.start_measure_pos=elem_data.start_measure_pos;
            elem.stop_measure_offset=elem_data.stop_measure_offset;
            elem.stop_measure_pos=elem_data.stop_measure_pos;
        }
    }
    
    return beam;
}

- (BOOL) parseBeam:(int)length staff:(int)staff_num
{
    int i;
    unsigned char thisByte;
    // maybe create tuplet, for < quarter & tool 3(
    //bool createTuplet = false;
    self.staff = staff_num;
    self.stop_staff=staff_num;
    self.drawPos_width=0;
    //                    Tuplet* tuplet = new Tuplet();

    // is grace
    //READ_U8_BOOL(_isGrace)
    READ_U8(thisByte)
    //0x3C: grace
    //0x4B: backward
    //0x5A:
    //0x00: normal
    _isGrace = (thisByte==0x3C);
    
    READ_U8(thisByte)//JMP(1)
    
    // voice
    READ_U8(_voice)
    self.voice=self.voice&0x07;
    //                    beam->setVoice(getLowNibble(placeHolder.toUnsignedInt())&0x7);
    
    // common
    self.pos=[[CommonBlock alloc]init ];
    [self.pos parse];
    
    //JMP(2)
    READ_U8(thisByte) //flag1  0x20:tremolo颤音
    READ_U8(thisByte) //dxs

    // beam count
    READ_U8(beam_count) //nne
    
    //JMP(1)
    READ_U8(thisByte) //flag2

    
    // left line
    READ_U8(_left_line)
    //                    beam->getLeftLine()->setLine(placeHolder.toInt());
    
    // right line
    READ_U8(_right_line)
    //                    beam->getRightLine()->setLine(placeHolder.toInt());
    
    if( isVersion4 ) {
        JMP(8)
    }
    
    int currentCursor = isVersion4 ? 23 : 13;
    int count = (length - currentCursor)/16;
    
    if( count != beam_count ) 
    { 
        return false; 
    }
    if (self.beam_elems==nil) {
        self.beam_elems=[[NSMutableArray alloc]initWithCapacity:count];
    }
    
    for( i=0; i<count && i<16; ++i ) {
        
        BeamElem *beam_elem=[BeamElem parseBeamElem:length];
        [self.beam_elems addObject:beam_elem];
        self.tupletCount=beam_elem.tupletCount;
        if( i == 0 ) {
            JMP(4)
            
            // left offset up+4, down-4
            READ_U16(left_shoulder_offset_y)
            //                            if( !readBuffer(placeHolder, 2) ) { return false; }
            //                            beam->getLeftShoulder()->setYOffset(placeHolder.toInt());
            
            // right offset up+4, down-4
            READ_U16(right_shoulder_offset_y)
            //                            if( !readBuffer(placeHolder, 2) ) { return false; }
            //                            beam->getRightShoulder()->setYOffset(placeHolder.toInt());
        } else {
            JMP(8)
        }
    }
    
    //                    const QList<QPair<MeasurePos, MeasurePos> > lines = beam->getLines();
    //                    MeasurePos offsetMp;
    /*
     for( i=0; i<lines.size(); ++i ) {
     if( lines[i].second > offsetMp ) {
     offsetMp = lines[i].second;
     }
     }
     beam->stop()->setMeasure(offsetMp.getMeasure());
     beam->stop()->setOffset(offsetMp.getOffset());
     
     // a case that Tuplet block don't exist, and hide inside beam
     if( createTuplet ) {
     tuplet->copyCommonBlock(*beam);
     tuplet->getLeftLine()->setLine(beam->getLeftLine()->getLine());
     tuplet->getRightLine()->setLine(beam->getRightLine()->getLine());
     tuplet->stop()->setMeasure(beam->stop()->getMeasure());
     tuplet->stop()->setOffset(maxEndUnit);
     
     measureData->addCrossMeasureElement(tuplet, true);
     } else {
     delete tuplet;
     }
     */
    return YES;
}
@end

@implementation OveWedge

typedef struct{
    char wedgeType,wedgeOrExpression;
    short offset_y;
    unsigned char wedge_height;
    unsigned char staff;
    struct CommonBlockStruct pos;
    struct OffsetCommonBlockStruct offset;
    unsigned short expression_text_len;
}WedgeDataStruct;

- (NSData*) writeToData
{
    /*
     @property (nonatomic, retain) NSMutableArray *beam_elems;
     */
    WedgeDataStruct dataStruct={
        .wedgeType=self.wedgeType,
        .wedgeOrExpression=self.wedgeOrExpression,
        .offset_y=self.offset_y,
        .wedge_height=self.wedge_height,
        .staff=self.staff,
        .pos={self.pos.start_offset, self.pos.tick},
        .offset={self.offset.stop_measure, self.offset.stop_offset},
        .expression_text_len=0
    };
    const char *exp_text=self.expression_text.UTF8String;
    if (self.expression_text.length>0) {
        dataStruct.expression_text_len=strlen(exp_text);
    }
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    if (dataStruct.expression_text_len>0) {
        [writeData appendBytes:exp_text length:dataStruct.expression_text_len];
    }
    return writeData;
}

+ (OveWedge*)loadFromOvsData:(NSData*)ovsData
{
    WedgeDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    OveWedge *beam=[[OveWedge alloc]init];
    beam.wedgeType=data.wedgeType;
    beam.offset_y=data.offset_y;
    beam.wedge_height=data.wedge_height;
    if (data.staff==0) {
        beam.staff=1;
    }else{
        beam.staff=data.staff;
        //NSLog(@"wrong staff=%d", beam.staff);
    }
    beam.wedgeOrExpression=data.wedgeOrExpression;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    beam.offset=[[OffsetCommonBlock alloc] init];
    beam.offset.stop_measure=data.offset.stop_measure;
    beam.offset.stop_offset=data.offset.stop_offset;
    
    if (data.expression_text_len>0) {
        char *text=malloc(data.expression_text_len+1);text[data.expression_text_len]=0;
        MUSK_READ_BUF(text, data.expression_text_len);
        beam.expression_text=[NSString stringWithUTF8String:text];
        free(text);
    }
    return beam;
}

- (BOOL) parse: (int)length
{
    //                    Wedge* wedge = new Wedge();
    JMP(3)
    
    // common
    self.pos = [CommonBlock parseCommonBlock];
    
    // wedge type
    unsigned char thisByte;
    READ_U8(thisByte)
    self.wedgeType = Wedge_Cres_Line;
    self.wedgeOrExpression = true;
    unsigned int highHalfByte = thisByte>>4;// getHighNibble(placeHolder.toUnsignedInt());
    unsigned int lowHalfByte = thisByte&0x0F;// getLowNibble(placeHolder.toUnsignedInt());
    
    switch (highHalfByte) {
        case 0x0: {
            self.wedgeType = Wedge_Cres_Line;
            self.wedgeOrExpression = true;
            break;
        }
        case 0x4: {
            self.wedgeType = Wedge_Decresc_Line;
            self.wedgeOrExpression = true;
            break;
        }
        case 0x6: {
            self.wedgeType = Wedge_Decresc;
            self.wedgeOrExpression = false;
            break;
        }
        case 0x2: {
            self.wedgeType = Wedge_Cres;
            self.wedgeOrExpression = false;
            break;
        }
        default:
            break;
    }
    
    // 0xb | 0x8(ove3) , else 3, 0(ove3)
    if( (lowHalfByte & 0x8) == 0x8 ) {
        self.wedgeType = Wedge_Double_Line;
        self.wedgeOrExpression = true;
    }
    JMP(1)
    
    // y offset
    READ_U16(_offset_y)
    //                    wedge->setYOffset(placeHolder.toInt());
    
    // wedge
    if( self.wedgeOrExpression ) {
        //                        measureData->addCrossMeasureElement(wedge, true);
        //                        wedge->setWedgeType(wedgeType);
        JMP(2)
        
        // height
        READ_U16(_wedge_height)
        //                        wedge->setHeight(placeHolder.toUnsignedInt());
        
        // offset common
        self.offset=[OffsetCommonBlock parseOffsetCommonBlock];
        
        int cursor = isVersion4 ? 21 : 19;
        JMP(length-cursor)
    }
    // expression : cresc, decresc
    else {
        //                        Expressions* express = new Expressions();
        //                        measureData->addMusicData(express);
        
        //                        express->copyCommonBlock(*wedge);
        //                        express->setYOffset(wedge->getYOffset());
        JMP(4)
        
        // offset common
        self.offset=[OffsetCommonBlock parseOffsetCommonBlock];
        //                        if( !parseOffsetCommonBlock(express) ) { return false; }
        
        if( isVersion4 ) {
            if (length<39) {
                self.expression_text= (self.wedgeType==Wedge_Cres) ? @"cresc." : @"dimin.";
                JMP(length-21)
            }else{
                NSLog(@"Error, unknow wedge!");
                JMP(18)
                // words
                if( length > 39 ) 
                {
                    char text[100];
                    READ_BUF(text, length-39)
                    self.expression_text=stringFromBuffer(text);//[NSString stringWithCString:text encoding:enc];
                }
            }
        } else {
            self.expression_text= (self.wedgeType==Wedge_Cres) ? @"crescendo" : @"diminuendo";
            //                            express->setText(str);
            JMP(8)
        }
    }
    return YES;
}
+ (OveWedge*) parseWedge: (int)length staff:(int)staff
{
    OveWedge *wedge=[[OveWedge alloc]init];
    [wedge parse:length];
    wedge.staff=staff;
    return wedge;
}

@end

@implementation CommonSlur
/*
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [self.pos encodeWithCoder:aCoder];
    [self.offset encodeWithCoder:aCoder];
    [self.pair_ends encodeWithCoder:aCoder];
    [aCoder encodeObject:[NSNumber numberWithShort:self.staff] forKey:@"staff"];
}
- (void)decodeWithCoder:(NSCoder *)aDecoder
{
    self.pos = [CommonBlock decodeWithCoder:aDecoder];
    self.offset = [OffsetCommonBlock decodeWithCoder:aDecoder];
    self.pair_ends = [PairEnds decodeWithCoder:aDecoder];
    NSNumber *num=[aDecoder decodeObjectForKey:@"staff"];
    self.staff = num.shortValue;
}*/

typedef struct{
    char stop_staff, staff;
    struct CommonBlockStruct pos;
    struct PairEndsStruct pair_ends;
    struct OffsetCommonBlockStruct offset;
}CommonSlurDataStruct;
- (void) writeCommonSlurDataToData:(NSMutableData*) writeData
{
    CommonSlurDataStruct dataStruct={
        self.stop_staff, self.staff,
        {self.pos.start_offset, self.pos.tick},
        {self.pair_ends.left_line, self.pair_ends.right_line},
        {self.offset.stop_measure, self.offset.stop_offset},
    };
    [writeData appendBytes:&dataStruct length:sizeof(dataStruct)];    
}

- (void)loadCommonSlurDataFromOvsData:(NSData*)ovsData
{
    CommonSlurDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    self.staff=(data.staff>0)?data.staff:data.stop_staff;
    self.stop_staff=(data.stop_staff>0)?data.stop_staff:data.staff;
    
    self.pos=[[CommonBlock alloc]init];
    self.pos.start_offset=data.pos.start_offset;
    self.pos.tick=data.pos.tick;
    
    self.pair_ends=[[PairEnds alloc]init];
    self.pair_ends.left_line=data.pair_ends.left_line;
    self.pair_ends.right_line=data.pair_ends.right_line;
    
    self.offset=[[OffsetCommonBlock alloc]init];
    self.offset.stop_offset=data.offset.stop_offset;
    self.offset.stop_measure=data.offset.stop_measure;
}

@end

@implementation MeasureSlur

typedef struct{
    char voice, slur1_above;
}SlurDataStruct;

- (NSData*) writeToData
{
    /*
     @property (nonatomic, retain) NSMutableArray *beam_elems;
     */
    SlurDataStruct dataStruct={
        self.voice, self.slur1_above,
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    [self writeCommonSlurDataToData:writeData];
    return writeData;
}

+ (MeasureSlur*)loadFromOvsData:(NSData*)ovsData
{
    SlurDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    MeasureSlur *slur=[[MeasureSlur alloc]init];
    slur.voice=data.voice;
    slur.slur1_above=data.slur1_above;
    [slur loadCommonSlurDataFromOvsData:ovsData];
    return slur;
}


-(BOOL)parse:(int)length
{
    //                    Slur* slur = new Slur();
    //                    measureData->addCrossMeasureElement(slur, true);
    JMP(2)
    
    // voice
    READ_U8(_voice)
    self.voice=self.voice&0x07;
    
    // common: 6 bytes
    self.pos = [CommonBlock parseCommonBlock];
    
    // show on top
    unsigned char thisByte;
    READ_U8(thisByte)
    self.slur1_above = (thisByte==0x80);
    
    //                    if( !readBuffer(placeHolder, 1) ) { return false; }
    //                    slur->setShowOnTop(getHighNibble(placeHolder.toUnsignedInt())==0x8);
    JMP(1)
    
    // pair lines: 4 bytes: r1, r2
    self.pair_ends = [PairEnds parsePairLinesBlock];
    
    // offset common: 4 bytes:  endm, endr
    self.offset = [OffsetCommonBlock parseOffsetCommonBlock];
    
    // handle 1
    leftShoulder=[OffsetElement parseOffsetElement];
    
    // handle 4
    rightShoulder=[OffsetElement parseOffsetElement];
    
    // handle 2: bezr1, bezr2;
    handle2=[OffsetElement parseOffsetElement];
    
    // handle 3:  bezy1, bezy2;
    handle3=[OffsetElement parseOffsetElement];
    
    //ls->bezy = (y1<0? (y2<0? -1:0) : (y2>=0? 1:0));
    /*
     below:
     leftShoulder: x>0, y>0
     rightShoulder: x=-2, y=0
     handle2: x>0,y>0
     handle3: x>0,y>0

     above:
     leftShoulder: x<0, y<0
     rightShoulder: x=8, y=1
     handle2: x>0,y>0
     handle3: x<0,y<0
     */
    //if (!slur1_above) 
    {
        if (handle3.offset_x>0 && handle3.offset_y>=0) {
            self.slur1_above=NO;
        }else if (handle3.offset_x<0 && handle3.offset_y<=0)
        {
            self.slur1_above=YES;
        }
    }
    
    if( isVersion4 ) {
        JMP(3)
        
        // note time percent 100 -> 100
        READ_U8(note_time_percent)
        //                        slur->setNoteTimePercent(placeHolder.toUnsignedInt());
        JMP(36)
    }
    return YES;
}
+(MeasureSlur*)parseSlur:(int)length staff:(int)staff_num
{
    MeasureSlur *slur=[[MeasureSlur alloc]init];
    [slur parse:length];
    slur.staff = staff_num;
    slur.stop_staff=staff_num;
    return slur;
}
@end

@implementation MeasureTie

typedef struct{
    short above;
}TieDataStruct;

- (NSData*) writeToData
{
    /*
     @property (nonatomic, retain) NSMutableArray *beam_elems;
     */
    TieDataStruct dataStruct={
        self.above,
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    [self writeCommonSlurDataToData:writeData];
    
    return writeData;
}

+ (MeasureTie*)loadFromOvsData:(NSData*)ovsData
{
    TieDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    MeasureTie *slur=[[MeasureTie alloc]init];
    slur.above=data.above;
    [slur loadCommonSlurDataFromOvsData:ovsData];
    return slur;
}

- (bool) parse
{
    //	Tie* tie = new Tie();
    //	measureData->addCrossMeasureElement(tie, true);
    JMP(3)
    
	// start common
    self.pos = [CommonBlock parseCommonBlock];
    
    JMP(1)
    
	// note
    READ_U8(note)
    //	tie->setNote(placeHolder.toUnsignedInt());
    
	// pair lines
    self.pair_ends = [PairEnds parsePairLinesBlock];
    
	// offset common
    self.offset = [OffsetCommonBlock parseOffsetCommonBlock];
    
	// left shoulder offset
    leftShoulder = [OffsetElement parseOffsetElement];
    
	// right shoulder offset
    rightShoulder = [OffsetElement parseOffsetElement];
    //	if( !parseOffsetElement(tie->getRightShoulder()) ) { return false; }
    
    if (rightShoulder.offset_x<=0 && rightShoulder.offset_y<=0) {
        self.above=YES;
    }else
    {
        self.above=NO;
    }
	// height
    READ_U16(height)
    //	tie->setHeight(placeHolder.toUnsignedInt());
    
	return true;
}
+ (MeasureTie*) parseTie:(int)staff_num
{
    MeasureTie *tie=[[MeasureTie alloc]init];
    [tie parse];
    tie.staff=staff_num;
    return tie;
}

@end

@implementation OveTuplet

typedef struct{
    short tuplet;
}TupletDataStruct;

- (NSData*) writeToData
{
    TupletDataStruct dataStruct={
        self.tuplet,
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    [self writeCommonSlurDataToData:writeData];
    
    return writeData;
}

+ (OveTuplet*)loadFromOvsData:(NSData*)ovsData
{
    TupletDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    OveTuplet *slur=[[OveTuplet alloc]init];
    slur.tuplet=data.tuplet;

    [slur loadCommonSlurDataFromOvsData:ovsData];
    return slur;
}


-(BOOL) parse: (int)length
{    
    //Tuplet* tuplet = new Tuplet();
    //measureData->addCrossMeasureElement(tuplet, true);
    JMP(1)
    unsigned short voice;
    READ_U16(voice)
    if (voice!=0) {
        voice = (voice)&0x07;
    }
    
    // common 5 bytes
    self.pos=[CommonBlock parseCommonBlock];
    
    JMP(2) //n2a
    
    // pair lines: 4 bytes
    self.pair_ends=[PairEnds parsePairLinesBlock];
    
    // offset common: 4 bytes
    self.offset=[OffsetCommonBlock parseOffsetCommonBlock];
    
    // left shoulder offset 4
    leftShoulder = [OffsetElement parseOffsetElement];
    
    // right shoulder offset 4
    rightShoulder = [OffsetElement parseOffsetElement];
    
    JMP(2) //style, n3
    
    // height
    READ_U16(height)
    
    // tuplet
    READ_U8(_tuplet)
    
    // space
    READ_U8(space)
    
    // mark offset 4
    mark_handle=[OffsetElement parseOffsetElement]; 
    //if( !parseOffsetElement(tuplet->getMarkHandle()) ) { return false; }
//    JMP(length-36)
    
    return TRUE;
}
+ (OveTuplet*) parseTuplet:(int)length staff:(int)staff_num
{
    OveTuplet *tup=[[OveTuplet alloc]init];
    tup.staff=staff_num;
    [tup parse:length];
    return tup;
}
@end

@implementation MeasureGlissando

typedef struct{
    short straight_wavy;
}GlissandoDataStruct;

- (NSData*) writeToData
{
    GlissandoDataStruct dataStruct={
        self.straight_wavy,
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    [self writeCommonSlurDataToData:writeData];
    
    return writeData;
}

+ (MeasureGlissando*)loadFromOvsData:(NSData*)ovsData
{
    GlissandoDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    MeasureGlissando *slur=[[MeasureGlissando alloc]init];
    slur.straight_wavy=data.straight_wavy;
    
    [slur loadCommonSlurDataFromOvsData:ovsData];
    return slur;
}

- (BOOL)parse
{
    unsigned char thisByte;
    
    JMP(3)
    
    // common
    self.pos=[CommonBlock parseCommonBlock];
    
    // straight or wavy 直线还是波浪线?
    READ_U8(thisByte)
    self.straight_wavy=((thisByte>>4)==4);
    
    JMP(1)
    
    // pair lines
    self.pair_ends=[PairEnds parsePairLinesBlock];
    
    // offset common
    self.offset = [OffsetCommonBlock parseOffsetCommonBlock];
    
    // left shoulder
    leftShoulder=[OffsetElement parseOffsetElement];
    
    // right shoulder
    rightShoulder=[OffsetElement parseOffsetElement];
    
    if( isVersion4 ) {
        JMP(1)
        
        // line thick
        READ_U8(line_thick)
        
        JMP(12)
        
        // text 32 bytes
        char text[32];
        READ_BUF(text, 32)
        glissando_text = [NSString stringWithCString:text encoding:NSUTF8StringEncoding];
        
        JMP(6)
    }
    return YES;
}
+(MeasureGlissando*)parseGlissando
{
    MeasureGlissando *gliss=[[MeasureGlissando alloc]init];
    [gliss parse];
    return gliss;
}
@end

@implementation MeasurePedal


- (NSData*) writeToData
{
    NSMutableData *writeData=[[NSMutableData alloc]init];
    [self writeCommonSlurDataToData:writeData];
    
    return writeData;
}

+ (MeasurePedal*)loadFromOvsData:(NSData*)ovsData
{

    MeasurePedal *slur=[[MeasurePedal alloc]init];    
    [slur loadCommonSlurDataFromOvsData:ovsData];
    return slur;
}

- (bool) parse:(int)length
{
    JMP(1)
    
	// is playback
    unsigned char thisByte;
    READ_U8(thisByte)
    isPlayBack = (thisByte&0x40);
//	pedal->setIsPlayback(getHighNibble(placeHolder.toUnsignedInt())!=4);

    JMP(1)
    
	// common
    self.pos = [CommonBlock parseCommonBlock];

    JMP(2)
    
	// pair lines
    self.pair_ends=[PairEnds parsePairLinesBlock];
    
	// offset common
    self.offset=[OffsetCommonBlock parseOffsetCommonBlock];
    
	// left shoulder
    leftShoulder=[OffsetElement parseOffsetElement];
    
	// right shoulder
    rightShoulder=[OffsetElement parseOffsetElement];
    
	int cursor = (isVersion4) ? 0x45 : 0x23;
	int blankCount = (isVersion4) ? 42 : 10;
    
    isHalf=(length > cursor);
	//pedal->setHalf( length > cursor );
    
    JMP(blankCount)
    
	if( length > cursor ) {
        JMP(2)
        
		// handle x offset
        READ_U16(x_offset)

        JMP(6)
	}
    
	return true;
}

+ (MeasurePedal*) parsePedal:(int)length staff:(int)staff_num
{
    MeasurePedal *pedal=[[MeasurePedal alloc]init];
    pedal.staff=staff_num;
    [pedal parse:length];
    return pedal;
}
@end


@implementation NumericEnding


typedef struct{
    short numeric_measure_count;
    struct CommonBlockStruct pos;
    unsigned short numeric_text_len;
}NumericEndingDataStruct;

- (NSData*) writeToData
{
    /*
     @property (nonatomic, retain) NSMutableArray *beam_elems;
     */
    NumericEndingDataStruct dataStruct={
        self.numeric_measure_count,
        {self.pos.start_offset, self.pos.tick},
        0
    };
    const char *exp_text=self.numeric_text.UTF8String;
    if (self.numeric_text.length>0) {
        dataStruct.numeric_text_len=strlen(exp_text);
    }
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    if (dataStruct.numeric_text_len>0) {
        [writeData appendBytes:exp_text length:dataStruct.numeric_text_len];
    }
    return writeData;
}

+ (NumericEnding*)loadFromOvsData:(NSData*)ovsData
{
    NumericEndingDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    NumericEnding *beam=[[NumericEnding alloc]init];
    beam.numeric_measure_count=data.numeric_measure_count;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    if (data.numeric_text_len>0) {
        char *text=malloc(data.numeric_text_len+1);text[data.numeric_text_len]=0;
        MUSK_READ_BUF(text, data.numeric_text_len);
        beam.numeric_text=[NSString stringWithUTF8String:text];
        free(text);
    }
    return beam;
}


- (BOOL) parse
{
    
    JMP(3)
    
    if (self.pos!=nil) {
        NSLog(@"Error: too many RepeatSymbol");
    }
    self.pos = [CommonBlock parseCommonBlock];
    
    JMP(6)
    
    // measure count
    READ_U16(_numeric_measure_count)
    
    JMP(2)
    
    // left x offset
    READ_U16(numeric_left_offset_x)
    
    // height
    READ_U16(numeric_height)
    
    // right x offset
    READ_U16(numeric_right_offset_x)
    
    JMP(2)
    
    // y offset
    READ_U16(numeric_left_offset_y)
    numeric_right_offset_y=numeric_left_offset_y;
    
    // number offset
    READ_U16(numeric_offset_x)
    READ_U16(numeric_offset_y)
    
    JMP(6)
    
    // text size
    unsigned char size;
    READ_U8(size)
    
    // text : size maybe a huge value
    char text[100];
    READ_BUF(text, size)
    text[size]=0;
    self.numeric_text = [NSString stringWithCString:text encoding:NSUTF8StringEncoding];
    
    // fix for wedding march.ove
    if( size % 2 == 0 ) {
        JMP(1)
    }
    return YES;
}
+ (NumericEnding*) parseNumericEnding
{
    NumericEnding *num=[[NumericEnding alloc]init];
    [num parse];
    return num;
}
-(NSMutableArray*) getNumbers
{
	int i;
    NSArray *strs = [self.numeric_text componentsSeparatedByString:@","];
//	QStringList strs = text_.split(",", QString::SkipEmptyParts);
//	QList<int> endings;
    NSMutableArray *endings=[[NSMutableArray alloc]init ];
    
	for (i = 0; i < strs.count; ++i) {
//		bool ok;
        NSString *s=[strs objectAtIndex:i];
        NSNumber *num= [NSNumber numberWithInt:[s intValue]-1];
		//int num = strs[i].toInt(&ok);
		//endings.push_back(num);
        [endings addObject:num];
	}
    
	return endings;
}
-(int) getJumpCount
{
	NSMutableArray* numbers = [self getNumbers];
	int count = 0;
    
	for (int i = 0; i < numbers.count; ++i) {
        NSNumber *num=[numbers objectAtIndex:i];
        
		if (i + 1 != [num intValue]) {
			break;
		}
        
		count = i + 1;
	}
    
	return count;
}
@end

@implementation Tempo

typedef struct{
    short tempo;
    //short left_note_type;
    unsigned char left_note_type;
    unsigned char tempo_range;
    struct CommonBlockStruct pos;
}TempoDataStruct;

- (NSData*) writeToData
{
    TempoDataStruct dataStruct={
        .tempo=self.tempo,
        .left_note_type=self.left_note_type,
        .tempo_range=self.tempo_range,
        .pos={self.pos.start_offset, self.pos.tick},
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    return writeData;
}

+ (Tempo*)loadFromOvsData:(NSData*)ovsData
{
    TempoDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    Tempo *beam=[[Tempo alloc]init];
    beam.tempo=data.tempo;
    beam.left_note_type=data.left_note_type;
    beam.tempo_range=data.tempo_range;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    return beam;
}

-(int) getQuarterTempo
{
	double factor = pow(2.0, (int) Note_Quarter - (int) (self.left_note_type&0x0F));
	int ret = (int)((double) self.tempo * factor);
    
	return ret;
}

-(BOOL) parse
{
    
    unsigned char thisByte;
    
    JMP(3) //
    
    // common
    self.pos = [CommonBlock parseCommonBlock]; //6 bytes
    
    READ_U8(thisByte) //
    
    // show tempo
    show_tempo=(thisByte&0x40)==0x40;
    // show before text
    show_before_text=(thisByte&0x80)==0x80;
    // show parenthesis
    show_parenthesis = (thisByte&0x10) == 0x10;
    // left note type
    //高2位7-6：always:01 or 00
    //高2位5-4：00: normal, 10:附点
    //底4位3-0：01:全音符，02：二分音符，03：四分音符， 04:八分音符，05：十六分音符
    //如：0x43: 四分音符，0x63,0x23: 1.5个四分音符
    self.left_note_type=thisByte;//&0x3F;
    
    JMP(1)
    //                    if( !jump(1) ) { return false; }
    
    if( isVersion4 )
    {
        JMP(2)
        // tempo
        READ_U16(_tempo) //每分钟多少音符
        self.tempo /=100;
        //                        tempo->setTypeTempo(placeHolder.toUnsignedInt()/100);
    } else {
        // tempo
        READ_U16(_tempo)
        //                        tempo->setTypeTempo(placeHolder.toUnsignedInt());
        JMP(2)
    }
    
    // offset
    tempo_offset = [[OffsetElement alloc]init];
    [tempo_offset parse];
    
    JMP(16)
    
    // 31 bytes left text
    char text[32];text[31]=0;
    READ_BUF(text, 31);
//    NSLog(@"tempo left text:%s", text);
    _tempo_left_text = [NSString stringWithCString:text encoding:NSUTF8StringEncoding];
    
    READ_U8(thisByte)
    // swing eighth
    swing_eighth = (thisByte!=0x80);
    // right note type
    right_note_type=thisByte&0x0F;
    
    // right text
    if( isVersion4 ) 
    {
        READ_BUF(text, 31)
//        NSLog(@"tempo left text:%s", text);
        tempo_right_text = [NSString stringWithCString:text encoding:NSUTF8StringEncoding];
        JMP(1)
    }
    return YES;
}

+ (Tempo*) parseTempo
{
    Tempo *tempo=[[Tempo alloc]init];
    [tempo parse];
    return tempo;
    
}
@end

@implementation OctaveShift

typedef struct{
    short staff,octaveShiftType;
    short offset_y,length,end_tick;
    struct CommonBlockStruct pos;
}OctaveShiftDataStruct;

- (NSData*) writeToData
{
    OctaveShiftDataStruct dataStruct={
        self.staff, self.octaveShiftType,
        self.offset_y, self.length,self.end_tick, 
        {self.pos.start_offset, self.pos.tick},
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    return writeData;
}

+ (OctaveShift*)loadFromOvsData:(NSData*)ovsData
{
    OctaveShiftDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    OctaveShift *beam=[[OctaveShift alloc]init];
    beam.staff=data.staff;
    beam.offset_y=data.offset_y;
    beam.length=data.length;
    beam.end_tick=data.end_tick;
    beam.octaveShiftType=data.octaveShiftType;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    return beam;
}

-(bool) parse {
    
//	OctaveShift* octave = new OctaveShift();
//	measureData->addCrossMeasureElement(octave, true);
    
    unsigned char thisByte;
    
    JMP(3)
    
	// common
    self.pos=[CommonBlock parseCommonBlock];
//	if( !parseCommonBlock(octave) ) { return false; }
    
	// octave
    READ_U8(thisByte)
    
//	if( !readBuffer(placeHolder, 1) ) { return false; }
	unsigned int type = thisByte&0x0F;//getLowNibble(placeHolder.toUnsignedInt());
	self.octaveShiftType = type;
    
//	QList<OctaveShiftPosition> positions;
//	extractOctave(type, octaveShiftType, positions);
//    octave->setOctaveShiftType(octaveShiftType);
    
    JMP(1)
    
	// y offset
    READ_U16(_offset_y)

    JMP(4)
    
	// length
    READ_U16(_length)
    if (self.octaveShiftType==OctaveShift_8_Stop || self.octaveShiftType==OctaveShift_15_Stop) {
        self.pos.start_offset=_length;
        _length=0;
    }
    
	// end tick
    READ_U16(_end_tick)
    
	// start & stop maybe appear in same measure
    /*
	for (int i=0; i<positions.size(); ++i) {
		OctaveShiftPosition position = positions[i];
		OctaveShiftEndPoint* octavePoint = new OctaveShiftEndPoint();
		measureData->addMusicData(octavePoint);
        
		octavePoint->copyCommonBlock(*octave);
		octavePoint->setOctaveShiftType(octaveShiftType);
		octavePoint->setOctaveShiftPosition(position);
		octavePoint->setEndTick(octave->getEndTick());
        
		// stop
		if( i==0 && position == OctavePosition_Stop ) {
			octavePoint->start()->setOffset(octave->start()->getOffset()+octave->getLength());
		}
        
		// end point
		if( i>0 ) {
			octavePoint->start()->setOffset(octave->start()->getOffset()+octave->getLength());
			octavePoint->setTick(octave->getEndTick());
		}
	}
    */
	return true;
}
+ (OctaveShift*)parseOctaveShift:(int)staff_num
{
    OctaveShift *octave = [[OctaveShift alloc]init];
    octave.staff=staff_num;
    [octave parse];
    return octave;
}
@end

@implementation MeasureKey
@end

@implementation TimeSignatureParameter
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[NSNumber numberWithShort:self.beat_start] forKey:@"beat_start"];
    [aCoder encodeObject:[NSNumber numberWithShort:self.beat_length] forKey:@"beat_length"];
    [aCoder encodeObject:[NSNumber numberWithShort:self.beat_start_tick] forKey:@"beat_start_tick"];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
    self=[super init];
    if (self) {
        NSNumber *num=[aDecoder decodeObjectForKey:@"beat_start"];
        self.beat_start = num.shortValue;
        num=[aDecoder decodeObjectForKey:@"beat_length"];
        self.beat_length = num.shortValue;
        num=[aDecoder decodeObjectForKey:@"beat_start_tick"];
        self.beat_start_tick = num.shortValue;
    }
    return self;
}
@end

@implementation MidiController

- (BOOL) parse:(MidiCtrlType) type
{
    self.midi_type = type;
    
    JMP(3)
    // start position
    READ_U16(_tick)
    
    switch (self.midi_type) {
        case Midi_Controller:
            // value [0, 128)
            READ_U8(_controller_value)
            // controller number
            READ_U8(_controller_number)
            break;
        case Midi_ProgramChange:
            JMP(1)
            // patch
            READ_U8(_programechange_patch)
            break;
        case Midi_ChannelPressure:
            JMP(1)
            // pressure
            READ_U8(_channel_pressure)
            break;
        case Midi_PitchWheel:
            // pitch wheel
            READ_U16(_pitch_wheel_value)
            break;
        default:
            NSLog(@"Error: unknown midi_type=%d", self.midi_type);
            break;
    }
    if(isVersion4 ) {
        JMP(2)
    }
    return YES;
}
+ (MidiController*) parseMidiController:(MidiCtrlType) type 
{
    MidiController *midi=[[MidiController alloc] init];
    [midi parse:type];
    return midi;
}
@end

@implementation MeasureLyric


typedef struct{
    short staff,voice,verse;
    struct CommonBlockStruct pos;
    struct OffsetElementStruct offset;
    unsigned short text_len;
}LyricDataStruct;

- (NSData*) writeToData
{
    LyricDataStruct dataStruct={
        self.staff, self.voice, self.verse,
        {self.pos.start_offset, self.pos.tick},
        {self.offset.offset_x, self.offset.offset_y},
        0
    };
    const char *exp_text=self.lyric_text.UTF8String;
    if (self.lyric_text.length>0) {
        dataStruct.text_len=strlen(exp_text);
    }
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    if (dataStruct.text_len>0) {
        [writeData appendBytes:exp_text length:dataStruct.text_len];
    }
    return writeData;
}

+ (MeasureLyric*)loadFromOvsData:(NSData*)ovsData
{
    LyricDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    MeasureLyric *beam=[[MeasureLyric alloc]init];
    beam.staff=data.staff;
    beam.verse=data.verse;
    beam.voice=data.voice;
    beam.pos=[[CommonBlock alloc]init];
    beam.pos.start_offset=data.pos.start_offset;
    beam.pos.tick=data.pos.tick;
    beam.offset=[[OffsetElement alloc]init];
    beam.offset.offset_x=data.offset.offset_x;
    beam.offset.offset_y=data.offset.offset_y;
    if (data.text_len>0) {
        char *text=malloc(data.text_len+1);text[data.text_len]=0;
        MUSK_READ_BUF(text, data.text_len);
        beam.lyric_text=[NSString stringWithUTF8String:text];
        free(text);
    }
    return beam;
}

- (bool) parse:(int) length
{
    JMP(3)
    
	// common
    self.pos=[CommonBlock parseCommonBlock];

    JMP(2)
    
	// offset
    self.offset=[OffsetElement parseOffsetElement];

    JMP(7)
    
	// verse
    READ_U8(_verse)
    
	if( isVersion4 ) {
        JMP(6)
        
		// lyric
		if( length > 29 ) {
            char *text=malloc(length-29+1);text[length-29]=0;
            READ_BUF(text, length-29)
            self.lyric_text = stringFromBuffer(text);//[NSString stringWithCString:text encoding:enc];
            free(text);
		}else{
            NSLog(@"lyric_text len = %d", length);
        }
	}
    
	return true;
}
+ (MeasureLyric*) parseLyric:(int) length staff:(int)staff_num
{
    MeasureLyric *lyric=[[MeasureLyric alloc]init];
    lyric.staff=staff_num;
    [lyric parse:length];
    return lyric;
}
@end

@implementation HarmonyGuitarFrame


- (bool)parse:(int)length
{
    JMP(3)

	// common
    self.pos=[CommonBlock parseCommonBlock];
    
	// root
    READ_U8(_root)
    
	// type
    unsigned char thisByte;
    READ_U8(thisByte)
    self.type=thisByte;
    
	// bass
    READ_U8(_bass)
    
	int jumpAmount = (isVersion4) ? length - 12 : length - 10;
    JMP(jumpAmount)
    
	return true;
}
+ (HarmonyGuitarFrame*) parseHarmonyGuitarFrame:(int)length
{
    HarmonyGuitarFrame *tmp=[[HarmonyGuitarFrame alloc]init];
    [tmp parse:length];
    return tmp;
}
@end

@implementation NoteElem

typedef struct {
    signed char line,note,offsetStaff;
    unsigned char velocity;
    
    unsigned char accidental_type:4; //低4bit
    unsigned char reserved1:4; //高4bit: 0-9
    
    unsigned char step:3; //000, 111: CDEFGAB
    unsigned char alter:3; //0:-3, 1:-2, 3: -1, 4:0, 5:1, 6:2, 7:3
    unsigned char pitch_flag:2; //11: have octave, step, alter. other: head_type
    //char reserved2;//head_type;
    
    unsigned char tie_pos:2; //低2bit
    unsigned char reserved3:6; //高6bit
    
    unsigned char octave:4; //低4bit: 0-9
    char reserved4:4;       //高4bit:
    
    short offset_tick,length_tick;
}NoteElemDataStruct;

- (NSData*) writeToData
{
    NoteElemDataStruct dataStruct={
        .line=self.line, .note=self.note, .offsetStaff=self.offsetStaff,
        .velocity=self.velocity,
        .accidental_type=self.accidental_type,
        
        .step=self.xml_pitch_step-1,
        .alter=0,
        .pitch_flag=3,
        .octave=self.xml_pitch_octave,
        
        .tie_pos=self.tie_pos,
        .reserved4=0,
        .offset_tick=self.offset_tick, .length_tick=self.length_tick
    };
    unsigned char new_alter=self.xml_pitch_alter+3;
    dataStruct.alter=new_alter;
    
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    return writeData;
}

+ (NoteElem*)loadFromOvsData:(NSData*)ovsData
{
    NoteElemDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    NoteElem *page=[[NoteElem alloc]init];
    page.line=data.line;
    page.note=data.note;
    page.offsetStaff=data.offsetStaff;
    page.velocity=data.velocity;
    page.accidental_type=data.accidental_type;
    if (data.pitch_flag==3) {
        page.xml_pitch_octave=data.octave;
        page.xml_pitch_step=data.step+1;
        page.xml_pitch_alter=data.alter;
        page.xml_pitch_alter-=3;
    }else{
        page.xml_pitch_octave=0;
        page.xml_pitch_step=0;
        page.xml_pitch_alter=0;
    }
    //page.head_type=data.head_type;
    page.tie_pos=data.tie_pos;
    page.offset_tick=data.offset_tick;
    page.length_tick=data.length_tick;
    return page;
}

- (BOOL)parse:(int)length
{
    //NoteElem tmp_note_elem;
    unsigned char thisByte;
    bool show;
    // note show / hide
    READ_U8(thisByte)
    show = ((thisByte&0x80) != 0x80);
    // note head type
    self.head_type = (thisByte&0x7f);
    
    // tie pos
    READ_U8(thisByte)
    self.tie_pos=(thisByte>>4);
    
    // offset staff, in {-1, 0, 1}
    READ_U8(thisByte)
    
    if( thisByte == 1 ) {
        self.offsetStaff = 1;
    }else if( thisByte == 7 ) {
        self.offsetStaff = -1;
    }else{
        self.offsetStaff = 0;
    }
    
    //notePtr->setOffsetStaff(offsetStaff);
    
    //accidental: 变音：有sharps (♯), flats (♭), and naturals (♮)的音
    READ_U8(thisByte)
    self.accidental_type=thisByte&0x0f;
    
    //notePtr->setAccidental(getLowNibble(thisByte));
    
    //accidental 0: influenced by key, 4: influenced by previous accidental in measure
    //0xc0: : influenced by key
    bool accidental_show = !( ((thisByte>>4) == 0 ) || ((thisByte>>4) == 4 ) || ((thisByte>>4) == 0x0c ));
    //                            notePtr->setShowAccidental(!notShow);
    
    /*
    if (self.accidental_show) {
        NSLog(@"accidental_show=0x%x accidental_type=%d", thisByte, self.accidental_type);
    }else{
        NSLog(@"accidental=0x%x", thisByte);
    }*/
    JMP(1)
    
    // line：五线谱的第几线，从上向下数
    READ_U8(_line)
    //                            notePtr->setLine(placeHolder.toInt());
    
    JMP(1)
    
    // note
    
    READ_U8(_note)
    //                            notePtr->setNote(note);
    /*
     if (clef_type==Clef_Treble) {//Clef_Treble
     clefMiddleTone = 6;//Tone_B
     clefMiddleOctave = 4;
     }else{
     clefMiddleTone = 1;//Tone_D
     clefMiddleOctave = 3;
     }
     int absLine =  clefMiddleTone + clefMiddleOctave * 7 + line;
     music_note.pitch_step=absLine%7+1;
     music_note.pitch_octave=absLine/7;
     music_note.pitch_alter = [self accidentalToAlter:accidental_type];
     */
    
    // note on velocity: 速度
    READ_U8(_velocity)
    //                            notePtr->setOnVelocity(onVelocity);
    
    // note off velocity
    READ_U8(off_velocity)
    //                            notePtr->setOffVelocity(offVelocity);
    JMP(2);
    
    // length (tick)
    READ_U16(_length_tick)
    //                            container->setLength(placeHolder.toUnsignedInt());
    
    // offset tick
    READ_U16(_offset_tick)
    //                            notePtr->setOffsetTick(placeHolder.toInt());
    {
/*
    ||  1  |     |  2  |     |  3  |  4  |     |  5  |     |  6  |     | 7
    ||  C  | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
 -----------------------------------------------------------------------------
 0  ||   0 |   1 |   2 |   3 |   4 |   5 |   6 |   7 |   8 |   9 |  10 | 11
*/
        self.xml_pitch_octave=self.note/12-1;
        int steps[12]={1,1,2,2,3,4,4,5,5,6,6,7};
        int index=self.note%12;
        self.xml_pitch_step=steps[index];
        if (self.accidental_type==Accidental_Flat) {
            self.xml_pitch_alter=-1;
            if (index==1 || index==3 || index==4 || index==6 || index==8 || index==10) {
                self.xml_pitch_step+=1;
            }else if (index==11)
            {
                self.xml_pitch_octave+=1;
                self.xml_pitch_step=1;
            }
        }else if (self.accidental_type==Accidental_DoubleFlat) {
            self.xml_pitch_alter=-2;
            if (index==0 || index==2 || index==5 || index==7 || index==9) {
                self.xml_pitch_step+=1;
            }
        }else if (self.accidental_type==Accidental_Sharp) {
            self.xml_pitch_alter=1;
            if (index==5) {
                self.xml_pitch_step-=1;
            }else if (index==0)
            {
                self.xml_pitch_octave-=1;
                self.xml_pitch_step=7;
            }
        }else if (self.accidental_type==Accidental_DoubleSharp) {
            self.xml_pitch_alter=2;
            if (index==2 || index==4 || index==7 || index==9 || index==11) {
                self.xml_pitch_step-=1;
            }
        }else{
            self.xml_pitch_alter=0;
        }
    }
    if (!accidental_show && self.accidental_type!=Accidental_Normal) {
        self.accidental_type=Accidental_Normal;
    }
    return show;
}

+ (NoteElem*)parseNoteElem:(int)length
{
    NoteElem *tmp=[[NoteElem alloc]init];
    bool show = [tmp parse:length];
    if (show) {
        return tmp;
    }
    return nil;
}
@end

@implementation NoteArticulation

typedef struct {
    unsigned char art_type,trillNoteType,trill_interval;
    unsigned char length_percentage,velocity_type,velocity_value;
    unsigned char above:1;
    unsigned char changeVelocity:1;
    unsigned char changeLength:1;
    char reserved;
    signed short sound_effect_from, sound_effect_to;
    struct OffsetElementStruct offset;
}ArticulationDataStruct;

- (NSData*) writeToData
{
    ArticulationDataStruct dataStruct={
        self.art_type, self.trillNoteType, self.trill_interval,
        self.length_percentage, self.velocity_type, self.velocity_value,
        self.art_placement_above, self.changeVelocity,self.changeLength,
        0,
        self.sound_effect_from, self.sound_effect_to,
        {self.offset.offset_x, self.offset.offset_y},
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    
    return writeData;
}
+ (NoteArticulation*)loadFromOvsData:(NSData*)ovsData
{
    ArticulationDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    NoteArticulation *page=[[NoteArticulation alloc]init];
    page.art_type=data.art_type;
    page.trillNoteType=data.trillNoteType;
    page.trill_interval=data.trill_interval;
    page.length_percentage=data.length_percentage;
    page.velocity_type=data.velocity_type;
    page.velocity_value=data.velocity_value;
    page.art_placement_above=data.above;
    page.changeVelocity=data.changeVelocity;
    page.changeLength=data.changeLength;
    page.sound_effect_from=data.sound_effect_from;
    page.sound_effect_to=data.sound_effect_to;
    page.offset=[[OffsetElement alloc]init];
    page.offset.offset_x=data.offset.offset_x;
    page.offset.offset_y=data.offset.offset_y;
        
    return page;
}

- (BOOL)parse:(int)block_size
{
    unsigned char thisByte;
    
    // articulation type
    READ_U8(thisByte)
    self.art_type = thisByte;
    if (thisByte>0x30) {
        NSLog(@"Error: Unknown art_type=0x%x",thisByte);
    }
    
    // placement
    READ_U8(thisByte);
    self.art_placement_above = (thisByte==0x10 || thisByte==0x30 || thisByte==0x50);
    //art->setPlacementAbove(placeHolder.toUnsignedInt()!=0x00);
    //0x00:below, 0x30:above, 0x20: ,0x10:above
    //0001 0000:above
    //0010 0000:below
    //0101 0000:above :trill
    //above: 0x10,0x30 (重音)
    //below: 0x20,
    //none: 0x00
    
    // offset
    self.offset = [[OffsetElement alloc]init ];
    [self.offset parse];
    
    
    //Articulation_Marcato:
    //above: 0x30
    //below: 0x20
    //Articulation_Finger_1 .. 5
    //above: 0x10
    //below: 0x20
    //Articulation_Pedal_Down,Articulation_Pedal_Up
    //0x00: always below
    //Articulation_Turn
    //above: 0x10
    //below: ??
    //Articulation_Major_Trill
    //above: 0x50
    //below:
    if (self.art_type >= Articulation_Major_Trill && self.art_type <= Articulation_Trill_Section) {
        //            NSLog(@"Error unknown art_placement_abve=0x%x art_type=0x%x offset_x=%d, offset_y=%d",thisByte, art_type, art_offset.offset_x, art_offset.offset_y);
    }
    
    if( !isVersion4 ) {
        if( block_size - 8 > 0 ) {
            JMP(block_size-8)
        }
    } else {
        // setting
        READ_U8(thisByte)
        changeSoundEffect = ( ( thisByte & 0x1 ) == 0x1 );
        self.changeLength = ( ( thisByte & 0x2 ) == 0x2 );
        self.changeVelocity = ( ( thisByte & 0x4 ) == 0x4 );
        //const bool changeExtraLength = ( ( thisByte & 0x20 ) == 0x20 );
        
        JMP(8)
        
        // velocity type
        READ_U8(thisByte)
        self.velocity_type = thisByte;
        if( self.changeVelocity ) {
            //art->setVelocityType((Articulation::VelocityType)thisByte);
        }
        JMP(14)
        
        // sound effect
        READ_U16(_sound_effect_from)
        //                            int from = placeHolder.toInt();
        READ_U16(_sound_effect_to)
        //                            int to = placeHolder.toInt();
        if( changeSoundEffect ) {
            //                                art->setSoundEffect(from, to);
        }
        
        JMP(1)
        
        // length percentage
        READ_U8(_length_percentage)
        if( self.changeLength ) {
            //                                art->setLengthPercentage(placeHolder.toUnsignedInt());
        }
        
        // velocity
        READ_U16(_velocity_value)
        if( self.changeVelocity ) {
            //                                art->setVelocityValue(placeHolder.toInt());
        }
        
        if( self.art_type == Articulation_Major_Trill ||
           self.art_type == Articulation_Minor_Trill ||
           self.art_type == Articulation_Trill_Section )
        {
            JMP(8)
            
            // trill note length
            unsigned char trill_note_length;
            READ_U8(trill_note_length)
            //                                art->setTrillNoteLength(placeHolder.toUnsignedInt());
            
            // trill rate
            READ_U8(thisByte)
            self.trillNoteType = Note_Sixteen;
            switch ( (thisByte>>4) ) {
                case 0:
                    self.trillNoteType = Note_None;
                    break;
                case 1:
                    self.trillNoteType = Note_Sixteen;
                    break;
                case 2:
                    self.trillNoteType = Note_32;
                    break;
                case 3:
                    self.trillNoteType = Note_64;
                    break;
                case 4:
                    self.trillNoteType = Note_128;
                    break;
                default:
                    break;
            }
            //                                art->setTrillRate(trillNoteType);
            
            // accelerate type
            //                                art->setAccelerateType(thisByte&0xf);
            JMP(1)
            
            // auxiliary first
            READ_U8(auxiliary_first)
            //                                art->setAuxiliaryFirst(placeHolder.toBoolean());
            JMP(1)
            
            // trill interval
            READ_U8(_trill_interval)
            //                                art->setTrillInterval(placeHolder.toUnsignedInt());
        } else {
            if( block_size > 40 ) {
                JMP(block_size-40)
            }
        }
    }
    
    return YES;
}
+ (NoteArticulation*)parseArticaulation:(int)block_size
{
    NoteArticulation *tmp=[[NoteArticulation alloc]init];
    [tmp parse:block_size];
    return tmp;
}
@end

@implementation OveNote

- (id)init {
    self = [super init];
    if (self) {
        self.noteShift = 0;
    }
    return self;
}


typedef struct {
    UInt32 tags,len;
    unsigned char staff,voice,tupletCount;
    signed char line,noteShift,note_type;
    //byte 1
    unsigned char isRest:1;
    unsigned char inBeam:1;
    unsigned char isDotDepartured:1;
    unsigned char stem_up:1;
    unsigned char hideStem:1;
    unsigned char isGrace:1;
    unsigned char isDot:2;
    //byte2
    unsigned char reserved;
    struct CommonBlockStruct pos;
}NoteDataStruct;
#define NOT0 '0TON'
- (NSData*) writeToData
{
    NoteDataStruct dataStruct={
        .tags=NOT0, .len=0,
        .staff=self.staff, .voice=self.voice, .tupletCount=self.tupletCount,
        .line=self.line, .noteShift=self.noteShift, .note_type=self.note_type,
        .isRest=self.isRest, .inBeam=self.inBeam, .isDotDepartured=0, .stem_up=self.stem_up, .hideStem=self.hideStem, .isGrace=self.isGrace, .isDot=self.isDot&0x03,
        0,
        {self.pos.start_offset, self.pos.tick},
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    
    //@property (nonatomic,retain) NSMutableArray *note_elems; //array of NoteElem
    WRITE_ARRAY("ELEM", NoteElem, self.note_elems);
    WRITE_ARRAY("ARTI", NoteArticulation, self.note_arts);
    
    //@property (nonatomic,retain) NSMutableArray *note_arts; //array of NoteArticulation
    UInt32 len=(UInt32)writeData.length;
    [writeData replaceBytesInRange:NSMakeRange(4, 4) withBytes:&len length:4];

    return writeData;
}

+ (OveNote*)loadFromOvsData:(NSData*)ovsData
{
    int start=local_pos;
    
    NoteDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    if (data.tags!=NOT0) {
        return nil;
    }
    int len_block=data.len;
    
    OveNote *page=[[OveNote alloc]init];
    page.staff=data.staff;
    page.voice=data.voice;
    page.tupletCount=data.tupletCount;
    page.line=data.line;
    page.noteShift=data.noteShift;
    page.note_type=data.note_type;
    page.isRest=data.isRest;
    page.inBeam=data.inBeam;
    page.isDot=data.isDot?(data.isDot):data.isDotDepartured;
    if (page.isDot>2) {
        page.isDot=0;
    }
    page.stem_up=data.stem_up;
    page.hideStem=data.hideStem;
    page.isGrace=data.isGrace;
    page.pos=[[CommonBlock alloc]init];
    page.pos.start_offset=data.pos.start_offset;
    page.pos.tick=data.pos.tick;
#define ELEM 'MELE'
#define ARTI 'ITRA'
    int next_tag_pos=local_pos;
    while (local_pos-start<len_block-4)
    {
        UInt32 tags;
        MUSK_READ_BUF(&tags, 4);
        
        switch (tags)
        {
            case ELEM:
                READ_ARRS(NoteElem, page.note_elems);
                break;
            case ARTI:
                READ_ARRS(NoteArticulation, page.note_arts);
                break;
            default:
                NSLog(@"Error unknow tag:%x", (unsigned int)tags);
                break;
        }
    }
    page.sorted_note_elems = [page.note_elems sortedArrayUsingComparator:^NSComparisonResult(NoteElem *obj1, NoteElem *obj2) {
        NSComparisonResult ret=NSOrderedSame;
        if (obj1.note>obj2.note) {
            ret=NSOrderedDescending;
        }else if (obj1.note<obj2.note) {
            ret=NSOrderedAscending;
        }
        return ret;
    }];
    
    /*
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
     */
    for (NoteElem *elem in page.note_elems) {
        if (elem.length_tick==0) {
            if (page.note_type<=0 || page.note_type>=Note_None){
                NSLog(@"wrong note_type=%d", page.note_type);
                page.note_type=Note_Eight;
            }
            int c = (int)(pow(2.0, (int)page.note_type)) ;
            elem.length_tick = 480 * 4 * 2 / c ;
            if (page.isGrace) {
                elem.length_tick/=8;
            }
        }
    }
    
    return page;
}

- (BOOL) parseNoteRest: (BOOL)rest length:(int)length staff:(int)staff_num
{
    unsigned short thisShort;
    bool show;
    self.staff = staff_num;
    // note|rest & grace
    //    isRaw = (type==Bdat_Raw_Note);
    
    READ_U16(thisShort)
    self.isGrace = ( (thisShort & 0xFF00) == 0x3C00 );
    isCue = ( thisShort == 0x4B40 || thisShort == 0x3240 );
    
    // show / hide
    // 0000 1001
    unsigned char thisByte;
    READ_U8(thisByte)
    show = ((thisByte&0x08)!=0x8);
    // voice
    self.voice = (thisByte&0x07);
    
    // common
    self.pos = [ CommonBlock parseCommonBlock];
    
    // tuplet
    READ_U8(_tupletCount)
    
    //    if (tupletCount!=0) {
    //        NSLog(@"tuplet");
    //    }
    
    // space
    READ_U8(tupletSpace)
    
    // in beam
    READ_U8(thisByte)
    self.inBeam = ( (thisByte>>4) & 0x1 ) == 0x1;
    
    // grace NoteType
    grace_note_type = (thisByte>>4);
    
    // dot 休止符
    self.isDot = (thisByte&0x0F) & 0x03;
    
    // NoteType
    READ_U8(thisByte)
    self.note_type =  thisByte&0x0F;
    
    int cursor = 0;
    
    if(rest)
    {
        self.isRest = YES;
        // line
        READ_U8(_line)
        JMP(1)
        cursor = isVersion4 ? 16 : 14;
    } else // type == Bdat_Note || type == Bdat_Raw_Note
    {
        // stem up 0x80, stem down 0x00
        READ_U8(thisByte)
        self.stem_up = (((thisByte>>4)&0x8)==0x8);
        
        // stem length
        stemOffset = thisByte%0x80;
        
        // show stem 0x00, hide stem 0x40
        READ_U8(thisByte)
        self.hideStem = (thisByte>>4)==0x4;
        
        //JMP(1)
        READ_U8(thisByte)
        
        // note count
        unsigned char tmp_noteCount;
        READ_U8(tmp_noteCount)
        unsigned int i;
        
        
        noteCount=0;
        // each note 16 bytes
        self.note_elems=[[NSMutableArray alloc]init];
        for( i=0; i<tmp_noteCount; ++i ) {

            NoteElem *note_elem=[NoteElem parseNoteElem:length];
            if (note_elem==nil) {
                continue;
            }
            //检查是不是已经有这个note_elem了？
            int nn;
            for (nn=0; nn<noteCount; nn++) {
                NoteElem *tmp_note_elem=[self.note_elems objectAtIndex:nn];
                if (note_elem.line==tmp_note_elem.line) {
                    NSLog(@"NoteElem already have");
                    break;
                }
            }
            if (nn>=noteCount && noteCount<5)
            {
                [self.note_elems addObject:note_elem];
                noteCount++;
            }else{
                NSLog(@"Too many NoteElem");
            }
        }
        
        cursor = isVersion4 ? 18 : 16;
        cursor += tmp_noteCount * 16/*note size*/;
    }
    self.sorted_note_elems=[self.note_elems sortedArrayUsingComparator:^NSComparisonResult(NoteElem *obj1, NoteElem *obj2) {
        NSComparisonResult ret=NSOrderedSame;
        if (obj1.note>obj2.note) {
            ret=NSOrderedDescending;
        }else if (obj1.note<obj2.note) {
            ret=NSOrderedAscending;
        }
        return ret;
    }];
    
    // articulation
    artCount=0;
    while ( cursor < length + 1/* 0x70 || 0x80 || 0x90 */ ) {
        //                        Articulation* art = new Articulation();
        //                        container->addArticulation(art);
        
        // block size
        unsigned short block_size;
        READ_U16(block_size)
        
        if (self.note_arts==nil) {
            self.note_arts=[[NSMutableArray alloc]init];
        }
        NoteArticulation *note_art=[NoteArticulation parseArticaulation:block_size];
        [self.note_arts addObject:note_art];
        
        artCount++;
        if (artCount>6) {
            NSLog(@"Error: too many note_art:%d", artCount);
        }
        cursor += block_size;
    }
    return show;
}

@end

@implementation OveMeasure
- (id) init
{
    self = [super init];
    if (self) {
        self.notes=nil;
        self.beams=nil;
        self.repeat_type=Repeat_Null;
    }
    return self;
}

#define MEA0 '0AEM'
#define NOTS 'STON'
#define BEAM 'MAEB'
#define SLUR 'RULS'
#define TIES 'SEIT'
#define TUPL 'LPUT'
#define GLIS 'SILG'
#define PEDA 'ADEP'
#define DYNA 'ANYD'
#define EXPR 'RPXE'
#define WEDG 'GDEW'
#define NUME 'EMUN'
#define TEXT 'TXET'
#define IMAG 'GAMI'
#define DECO 'OCED'
#define OCTA 'ATCO'
#define CLEF 'FELC'
#define TEMP 'PMET'
#define LYRI 'IRYL'

typedef struct {
    UInt32 tags, len;
    short number,typeTempo;
    unsigned short meas_length_size;
    unsigned char left_barline, right_barline;
    unsigned char repeat_type, repeat_count;//parseBarlineParameters
    unsigned char numerator;//分子
    unsigned char denominator;//分母
}MeasureDataStruct;
#define MINF 'FNIM'
typedef struct {
    unsigned short meas_length_tick;
    unsigned short r0,r1,r2,r3,r4,r5,r6;
}MeasureMoreInfoStruct;


- (NSData*) writeToData
{
    MeasureDataStruct dataStruct={
        MEA0, 0,
        self.number, self.typeTempo,
        self.meas_length_size,self.left_barline, self.right_barline,
        self.repeat_type, self.repeat_count,
        self.numerator, self.denominator,
    };
    NSMutableData *writeData=[[NSMutableData alloc]initWithBytes:&dataStruct length:sizeof(dataStruct)];
    
    MuskBlock header={MINF, sizeof(MuskBlock)+sizeof(MeasureMoreInfoStruct)};//MINF
    MeasureMoreInfoStruct moreInfoStruct={
        self.meas_length_tick,
        0,0,0,0,0,0,0
    };
    [writeData appendBytes:&header length:sizeof(header)];
    [writeData appendBytes:&moreInfoStruct length:sizeof(moreInfoStruct)];
    
    WRITE_ARRAY("NOTS", OveNote, self.notes);
    WRITE_ARRAY("BEAM", OveBeam, self.beams);
    WRITE_ARRAY("SLUR", MeasureSlur, self.slurs);
    WRITE_ARRAY("TIES", MeasureTie, self.ties);
    WRITE_ARRAY("TUPL", OveTuplet, self.tuplets);
    WRITE_ARRAY("GLIS", MeasureGlissando, self.glissandos);
    WRITE_ARRAY("PEDA", MeasurePedal, self.pedals);
    WRITE_ARRAY("DYNA", OveDynamic, self.dynamics);
    WRITE_ARRAY("EXPR", MeasureExpressions, self.expresssions);
    WRITE_ARRAY("WEDG", OveWedge, self.wedges);
    WRITE_ARRAY("NUME", NumericEnding, self.numerics);
    WRITE_ARRAY("TEXT", OveText, self.meas_texts);
    
    WRITE_ARRAY("DECO", MeasureDecorators, self.decorators);
    WRITE_ARRAY("OCTA", OctaveShift, self.octaves);
    WRITE_ARRAY("CLEF", MeasureClef, self.clefs);
    WRITE_ARRAY("TEMP", Tempo, self.tempos);
    WRITE_ARRAY("LYRI", MeasureLyric, self.lyrics);
    
    WRITE_ARRAY("IMAG", OveImage, self.images);
    UInt32 len=(UInt32)writeData.length;
    [writeData replaceBytesInRange:NSMakeRange(4, 4) withBytes:&len length:4];
    return writeData;
}

+ (OveMeasure*)loadFromOvsData:(NSData*)ovsData
{
    int start=local_pos;
    MeasureDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    if (data.tags!=MEA0) {
        NSLog(@"parse measure error, tag=0x%x(%s)", (unsigned int)data.tags, (char*)&data.tags);
        return nil;
    }
    int len_block=data.len;
    
    OveMeasure *music_measure=[[OveMeasure alloc]init];
    music_measure.number=data.number;
    music_measure.left_barline=data.left_barline;
    music_measure.right_barline=data.right_barline;
    music_measure.typeTempo=data.typeTempo;
    music_measure.repeat_type=data.repeat_type;
    music_measure.repeat_count=data.repeat_count;
    music_measure.meas_length_size=data.meas_length_size;
    music_measure.numerator=data.numerator;
    music_measure.denominator=data.denominator;

    //NSLog(@"mease=%d", music_measure.number);
    int next_tag_pos=local_pos;
    while (local_pos-start<len_block-4)
    {
        UInt32 tags;
        MUSK_READ_BUF(&tags, 4);
        
        switch (tags)
        {
            case MINF:
            {
                UInt32 len;
                MUSK_READ_BUF(&len, 4);
                next_tag_pos+=len;
                MeasureMoreInfoStruct moreInfo;
                MUSK_READ_BUF(&moreInfo, sizeof(MeasureMoreInfoStruct));
                music_measure.meas_length_tick=moreInfo.meas_length_tick;
                break;
            }
            case NOTS:
                READ_ARRS(OveNote, music_measure.notes);
                break;
            case BEAM:
                READ_ARRS(OveBeam, music_measure.beams);
                break;
            case SLUR:
                READ_ARRS(MeasureSlur, music_measure.slurs);
                break;
            case TIES:
                READ_ARRS(MeasureTie, music_measure.ties);
                break;
            case TUPL:
                READ_ARRS(OveTuplet, music_measure.tuplets);
                break;
            case GLIS:
                READ_ARRS(MeasureGlissando, music_measure.glissandos);
                break;
            case PEDA:
                READ_ARRS(MeasurePedal, music_measure.pedals);
                break;
            case DYNA:
                READ_ARRS(OveDynamic, music_measure.dynamics);
                break;
            case EXPR:
                READ_ARRS(MeasureExpressions, music_measure.expresssions);
                break;
            case WEDG:
                READ_ARRS(OveWedge, music_measure.wedges);
                break;
            case NUME:
                READ_ARRS(NumericEnding, music_measure.numerics);
                break;
            case TEXT:
                READ_ARRS(OveText, music_measure.meas_texts);
                break;
            case IMAG:
                READ_ARRS(OveImage, music_measure.images);
                break;
            case DECO:
                READ_ARRS(MeasureDecorators, music_measure.decorators);
                break;
            case OCTA:
                READ_ARRS(OctaveShift, music_measure.octaves);
                break;
            case CLEF:
                READ_ARRS(MeasureClef, music_measure.clefs);
                break;
            case TEMP:
                READ_ARRS(Tempo, music_measure.tempos);
                break;
            case LYRI:
                READ_ARRS(MeasureLyric, music_measure.lyrics);
                break;
            default:
                NSLog(@"Error unknow vmus tag:%x in measure", (unsigned int)tags);
                if(next_tag_pos<ovsData.length){
                    UInt32 start=local_pos-4;
                    UInt32 len_block;
                    MUSK_READ_BUF(&len_block, 4);
                    next_tag_pos+=len_block;
                    local_pos=start+len_block;
                }
                break;
        }
    }
    //READ_ARR("NOTS", OveNote, music_measure.notes);
    
    //按照duration分组notes
    if(music_measure.sorted_notes==nil){
        music_measure.sorted_notes=[[NSMutableDictionary alloc]init ];
    }
    for (OveNote *note in music_measure.notes) {
        NSString *tmp_key=[NSString stringWithFormat:@"%d", note.pos.tick];
        NSMutableArray *temp_notes=[music_measure.sorted_notes objectForKey:tmp_key];
        if (temp_notes==nil) {
            temp_notes=[[NSMutableArray alloc]init ];
            [music_measure.sorted_notes setObject:temp_notes forKey:tmp_key];
        }
        [temp_notes addObject:note];
    }
    
    [music_measure checkDontPlayedNotes];
    
    music_measure.sorted_duration_offset=[music_measure.sorted_notes.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString* obj1, NSString* obj2) {
        return [obj1 intValue]>[obj2 intValue];
    }];
    return music_measure;
}

- (void) checkDontPlayedNotes
{
    //remove notes, which has smaller duration with same tone
    for (NSString *key in self.sorted_notes.allKeys) {
        NSMutableArray *notes=[self.sorted_notes objectForKey:key];
        
        for (int i_notes=0;i_notes<notes.count;i_notes++) {
            OveNote *note = [notes objectAtIndex:i_notes];
            if (note.isGrace) {
                continue;
            }
            //check if there is another longer note with same tone
            for (NoteElem *elem in note.note_elems) {
                for (int t=0; t<notes.count && !elem.dontPlay; t++) {
                    OveNote *tmpNote=notes[t];
                    if (tmpNote.isGrace) {
                        continue;
                    }
                    if (tmpNote.note_type>=note.note_type && !elem.dontPlay && tmpNote!=note) {
                        for (int e=0; e<tmpNote.note_elems.count; e++) {
                            NoteElem *tmpElem=tmpNote.note_elems[e];
                            if (tmpElem.note==elem.note && tmpElem!=elem && !(elem.tie_pos&Tie_RightEnd)) {
                                tmpElem.dontPlay=YES;
                                if (tmpElem.xml_finger && elem.xml_finger==nil) {
                                    elem.xml_finger=tmpElem.xml_finger;
                                }
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
    
    for (NSString *key in self.sorted_notes.allKeys) {
        NSMutableArray *notes=[self.sorted_notes objectForKey:key];
        
        for (int i_notes=0;i_notes<notes.count;i_notes++) {
            OveNote *note = [notes objectAtIndex:i_notes];
            
            //check if there is another longer note with same tone
            int dontPlayElems=0;
            for (NoteElem *elem in note.note_elems) {
                if (elem.dontPlay) {
                    dontPlayElems++;
                }
            }
            if (dontPlayElems>0 && dontPlayElems==note.note_elems.count) {
                note.dontPlay=YES;
            }
        }
    }
}

- (void) checkDontPlayedNotes1
{
    //allenwang1982@outlook.com
    
    //remove notes, which has smaller duration with same tone
    for (NSString *key in self.sorted_notes.allKeys) {
        NSMutableArray *notes=[self.sorted_notes objectForKey:key];
        
        for (int i_notes=0;i_notes<notes.count;i_notes++) {
            OveNote *note = [notes objectAtIndex:i_notes];
            
            //check if there is another longer note with same tone
            int dontPlayElems=0;
            for (NoteElem *elem in note.note_elems) {
                for (int t=0; t<notes.count && !elem.dontPlay; t++) {
                    OveNote *tmpNote=notes[t];
                    if (tmpNote.note_type<note.note_type && !elem.dontPlay && tmpNote!=note) {
                        for (int e=0; e<tmpNote.note_elems.count; e++) {
                            NoteElem *tmpElem=tmpNote.note_elems[e];
                            if (tmpElem.note==elem.note && tmpElem!=elem) {
                                elem.dontPlay=YES;
                                break;
                            }
                        }
                    }
                }
                if (elem.dontPlay) {
                    dontPlayElems++;
                }
            }
            if (dontPlayElems>0 && dontPlayElems==note.note_elems.count) {
                note.dontPlay=YES;
            }
        }
    }
}


- (bool) parseMeasure
{
    unsigned char thisByte;
    unsigned short twoBytes;
    
    UInt32 meas_len;
    READ_U32(meas_len)//0x1c

	// multi-measure rest
    JMP(2) //01 00
    READ_U8_BOOL(multi_measure_rest);//00
	// pickup
	READ_U8_BOOL(pickup); //00
    JMP(4) //00 00 00 00
    
	// left barline
    READ_U8(thisByte) //00
    self.left_barline=thisByte;
    
	// right barline
    READ_U8(thisByte) //00
    self.right_barline=thisByte;
    
	// tempo
    READ_U16(twoBytes) //27 10=10000 就是100拍每分钟
    self.typeTempo=twoBytes;
    if( isVersion4 ) {
		self.typeTempo /= 100.0;
	}
    
    /*
     // tempo
     if( !readBuffer(placeHolder, 2) ) { return false; }
     double tempo = ((double)placeHolder.toUnsignedInt());
     if( ove_->getIsVersion4() ) {
     tempo /= 100.0;
     }
     measure->setTypeTempo(tempo);
     */
	// bar length(tick)
    READ_U16(bar_length)
    JMP(6)
    
	// bar number offset: 4 bytes
    bar_number_offset=[[OffsetElement alloc ]init];
    [bar_number_offset parse];

    JMP(2)
    
	// multi-measure rest count
    READ_U16(multi_measure_rest_count)
    
    if (meas_len>28) {
        JMP(meas_len-28)
    }
    
	return true;
}
typedef enum{
    Cond_Time_Parameters = 0x09,
    Cond_Bar_Number = 0x0A,
    Cond_Decorator = 0x16,
    Cond_Tempo = 0x1C,
    Cond_Text = 0x1D,
    Cond_Expression = 0x25,
    Cond_Barline_Parameters = 0x30,
    Cond_Repeat = 0x31,
    Cond_Numeric_Ending = 0x32,
}CondType;
- (bool) parseCond
{
    UInt32 cond_len;
    READ_U32(cond_len)
    
    unsigned short item_count;
    READ_U16(item_count)
    
    //if( !parseTimeSignature(measure, 36) ) { return false; }
    {
        // numerator 分子
        READ_U8(_numerator)
        // denominator 分母
        READ_U8(_denominator)

        JMP(2)
        
        // beat length
        READ_U16(beat_length)
        
        // bar length
        READ_U16(_meas_length_tick)

        JMP(4)
        
        // is symbol
        READ_U8_BOOL(is_symbol)
        
        JMP(1)
        
        // replace font
        READ_U8_BOOL(replace_font)
        
        // color
        READ_U8(color)
        
        // show
        READ_U8(show)
        
        // show beat group
        READ_U8_BOOL(show_beat_group)
        
        JMP(6)
        
        // numerator 1, 2, 3
        READ_U8(numerator1)
        READ_U8(numerator2)
        READ_U8(numerator3)
        
        // denominator
        READ_U8(denominator1)
        READ_U8(denominator2)
        READ_U8(denominator3)
        
        // beam group 1~4
        READ_U8(beam_group1)
        READ_U8(beam_group2)
        READ_U8(beam_group3)
        READ_U8(beam_group4)
        
        // beam 16th
        READ_U8(beam_16th)
        
        // beam 32th
        READ_U8(beam_32th)
    }    
	
	for( unsigned int i=0; i<item_count; ++i ) {
        unsigned char thisByte;
		unsigned short twoByte;
        READ_U16(twoByte);
		//unsigned int oldBlockSize = twoByte - 11;
		unsigned int newBlockSize = twoByte - 7;
        
		// type id
        unsigned char type_id;
        READ_U8(type_id)
		CondType type=type_id;
        
		switch (type) {
            case Cond_Bar_Number: {
                //              if (!parseBarNumber(measure, twoByte - 1)) { return false;}
                {
                    JMP(2)
                    
                    READ_U8(thisByte)
                    is_show_on_paragraph_start = (thisByte==8);
                    
                    unsigned int blankSize = isVersion4 ? 9 : 7;
                    JMP(blankSize)
                    
                    READ_U8(text_align)
                    
                    JMP(4)
                    
                    READ_U8(show_flag)
                    
                    JMP(10)
                    
                    READ_U8(show_every_bar_count)
                    
                    // prefix
                    READ_BUF(prefix,2)
                    //                    if( !readBuffer(placeHolder, 2) ) { return false; }
                    //                    barNumber->setPrefix(ove_->getCodecString(placeHolder.fixedSizeBufferToStrByteArray()));

                    JMP(18)
                }
                break;
            }
            case Cond_Repeat: {
                //                if (!parseRepeatSymbol(measureData, oldBlockSize)) { return false;}
                {                    
                    JMP(3)
                    
                    if (self.repeate_symbol_pos!=nil) {
                        NSLog(@"Error: too many RepeatSymbol");
                    }
                    self.repeate_symbol_pos = [CommonBlock parseCommonBlock];

                    // RepeatType
                    unsigned char thisByte;
                    READ_U8(thisByte)
                    self.repeat_type=thisByte;
                    
                    JMP(13)
                    
                    // offset
                    self.repeat_offset = [OffsetElement parseOffsetElement];

                    JMP(15)
                    
                    // size
                    unsigned short size;
                    READ_U16(size)
                    
                    // text, maybe huge
//                    char *text=(char*)malloc(size+1);text[size]=0;
//                    READ_BUF(text, size)
//                    repeat_text = [NSString stringWithCString:text encoding:NSUTF8StringEncoding];
//                    free(text);
                    repeat_text=READ_STR(size);
                    // last 0
                    if( size % 2 == 0 ) {
                        JMP(1)
                    }
                }
                break;
            }
            case Cond_Numeric_Ending: {
                //                if (!parseNumericEndings(measureData, oldBlockSize)) {return false;}
                {
                    if (self.numerics!=nil) {
                        self.numerics = [[NSMutableArray alloc]init ];
                    }
                    [self.numerics addObject: [NumericEnding parseNumericEnding]];
                }
                break;
            }
            case Cond_Decorator: {
                if (self.decorators==nil) {
                    self.decorators = [[NSMutableArray alloc]init ];
                }
                [self.decorators addObject:[MeasureDecorators parseDecorator:newBlockSize staff:1]];
                break;
            }
            case Cond_Tempo: //拍子
            {
                //                if (!parseTempo(measureData, newBlockSize)) { return false; }
                
                {
                    if (self.tempos==nil) {
                        self.tempos=[[NSMutableArray alloc]init ];
                    }
                    
                    [self.tempos addObject:[Tempo parseTempo]];
                }
                break;
            }
#if 1
            case Cond_Text: 
            {
                //if (![self parseText:nil length:newBlockSize]) {return false;}
                if (self.meas_texts==nil) {
                    self.meas_texts=[[NSMutableArray alloc]init ];
                }
                [self.meas_texts addObject:[OveText parseText:newBlockSize staff:0]];
//                meas_text = [[Text alloc]init];
//                [meas_text parseText:newBlockSize];
                break;
            }
            case Cond_Expression: 
            {
                //if (![self parseExpressions:nil length:newBlockSize]){return false;}
                if (self.expresssions==nil) {
                    self.expresssions = [[NSMutableArray alloc]init ];
                }
                MeasureExpressions *expr = [[MeasureExpressions alloc]init];
                [expr parseExpressions:newBlockSize staff:1];
                [self.expresssions addObject:expr];
                break;
            }
            case Cond_Time_Parameters: {
                //                if (!parseTimeSignatureParameters(measure, newBlockSize)) {return false;}
                {
                    //                    TimeSignature* ts = measure->getTime();
                    unsigned char numerator_count;
                    int length = newBlockSize;
                    int cursor = isVersion4 ? 10 : 8;
                    JMP(cursor)
                    
                    // numerator
                    READ_U8(numerator_count)
                    
                    cursor = isVersion4 ? 11 : 9;
                    if( ( length - cursor ) % 8 != 0 || (length - cursor) / 8 != (int)numerator_count ) {
                        return false;
                    }
                    if (timeSignatureParameters==nil) {
                        timeSignatureParameters=[[NSMutableArray alloc]init ];
                    }
                    for( unsigned int i =0; i<numerator_count; ++i ) 
                    {
                        unsigned short start, length, start_tick;
                        // beat start unit
                        READ_U16(start)
                        
                        // beat length unit
                        READ_U16(length)
                        
                        JMP(2)
                        
                        // beat start tick
                        READ_U16(start_tick)
                        //                        ts->addBeat(beatStart, beatLength, beatStartTick);

                        TimeSignatureParameter *ts=[[TimeSignatureParameter alloc]init];
                        [timeSignatureParameters addObject:ts];
                        ts.beat_start = start;
                        ts.beat_length = length;
                        ts.beat_start_tick = start_tick;
                        
                    }
                    //                    ts->endAddBeat();
                }
                break;
            }
            case Cond_Barline_Parameters: {
                //                if (!parseBarlineParameters(measure, newBlockSize)) { return false;}
                {
                    int cursor = isVersion4 ? 12 : 10;
                    JMP(cursor)
                    
                    // repeat count
                    READ_U8(_repeat_count)
                    
                    JMP(6)
                }
                break;
            }
#endif
            default: {
                NSLog(@"Error unknow cond type=0x%x newBlockSize=%d", type, newBlockSize);
                JMP(newBlockSize)
                break;
            }
		}
	}
    
	return true;
}
typedef enum {
	Bdat_Raw_Note				= 0x70,
	Bdat_Rest					= 0x80,
	Bdat_Note					= 0x90,
	Bdat_Beam					= 0x10,
	Bdat_Harmony				= 0x11,
	Bdat_Clef					= 0x12,
	Bdat_Wedge					= 0x13,	// cresendo, decresendo
	Bdat_Dynamics				= 0x14,
	Bdat_Glissando				= 0x15,
	Bdat_Decorator				= 0x16,	// measure repeat | piano pedal | dotted barline
	Bdat_Key					= 0x17,
	Bdat_Lyric					= 0x18,
	Bdat_Octave_Shift			= 0x19,
	Bdat_Slur					= 0x1B,
	Bdat_Text					= 0x1D,
	Bdat_Tie					= 0x1E,
	Bdat_Tuplet					= 0x1F,
	Bdat_Guitar_Bend			= 0x21,	//
	Bdat_Guitar_Barre			= 0x22,	//
	Bdat_Pedal					= 0x23,
	Bdat_KuoHao					= 0x24,	// () [] {}
	Bdat_Expressions			= 0x25,
	Bdat_Harp_Pedal				= 0x26,
	Bdat_Multi_Measure_Rest		= 0x27,
	Bdat_Harmony_GuitarFrame	= 0x28,
	Bdat_Graphics_40			= 0x40,	// unknown
	Bdat_Graphics_RoundRect		= 0x41,
	Bdat_Graphics_Rect			= 0x42,
	Bdat_Graphics_Round			= 0x43,
	Bdat_Graphics_Line			= 0x44,
	Bdat_Graphics_Curve			= 0x45,
	Bdat_Graphics_WedgeSymbol	= 0x46,
	Bdat_Midi_Controller		= 0xAB,
	Bdat_Midi_Program_Change	= 0xAC,
	Bdat_Midi_Channel_Pressure	= 0xAD,
	Bdat_Midi_Pitch_Wheel		= 0xAE,
	Bdat_Bar_End				= 0xFF,
    
	Bdat_None
}BdatType;

-(int) oveKeyToKey:(int) oveKey {
	int ret = 0;
    
	if( oveKey == 0 ) {
		ret = 0;
	}
	else if( oveKey > 7 ) {
		ret = oveKey - 7;
	}
	else if( oveKey <= 7 ) {
		ret = oveKey * (-1);
	}
    
	return ret;
}
- (bool) parseKey
{
//    int key, previousKey;
    unsigned char symbolCount;
    if (self.key==nil) {
        self.key=[[MeasureKey alloc]init];
    }
    
    
    unsigned char thisByte;
//	Block placeHolder;
//	Key* key = measureData->getKey();
	int cursor = isVersion4 ? 9 : 7;
    
    JMP(cursor)
    
    READ_U8(thisByte)
    self.key.key=[self oveKeyToKey:thisByte ];
    
	// previous key
    READ_U8(thisByte)
    self.key.previousKey=[self oveKeyToKey:thisByte];

    JMP(3)
    
	// symbol count
    READ_U8(symbolCount)
    self.key.symbolCount=symbolCount;

    JMP(4)
    
	return true;
}

-(bool) parseBdat:(int)index staff: (int) staff
{   
    self.number = index;
    //NSLog(@"measure=%d", index);
    UInt32 bdat_length;
    READ_U32(bdat_length)
    
	// parse here
    unsigned short cnt;
    READ_U16(cnt)
    if (staff==1 && self.notes!=nil) {
        NSLog(@"Error:");
    }
    if (self.notes==nil) {
        self.notes = [[NSMutableArray alloc]init ];
    }
    if (self.beams==nil) {
        self.beams = [[NSMutableArray alloc]init ];
    }
    
	for( unsigned int i=0; i<cnt; ++i ) {
		// 0x0028 or 0x0016 or 0x002C
        unsigned short length;
        READ_U16(length)
        length=length-7;
        
		// type id
        unsigned char thisByte;
        READ_U8(thisByte)
		BdatType type=thisByte;
        
        //NSLog(@"curpos: 0x%x, nextpos:0x%x",_buffer_index, _buffer_index+length);
		switch( type ) {
            case Bdat_Raw_Note :
            case Bdat_Rest :
            case Bdat_Note : 
            {
                //				if( !parseNoteRest(measureData, count, type) ) { return false; }
                OveNote *tmp = [[OveNote alloc]init];
                BOOL note_show = [tmp parseNoteRest:(type==Bdat_Rest) length:length staff:staff];
                if (note_show) {
                    [self.notes addObject:tmp];
                    if (tmp.pos.start_offset+50>self.meas_length_size) {
                        self.meas_length_size = tmp.pos.start_offset+50;
                    }
                    //按照duration分组notes
                    if(self.sorted_notes==nil){
                        self.sorted_notes=[[NSMutableDictionary alloc]init ];
                    }
                    
                    //NSNumber *tmp_key=[NSNumber numberWithInt:tmp.pos.tick];
                    NSString *tmp_key=[NSString stringWithFormat:@"%d", tmp.pos.tick];
                    NSMutableArray *temp_notes=[self.sorted_notes objectForKey:tmp_key];
                    if (temp_notes==nil) {
                        temp_notes=[[NSMutableArray alloc]init ];
                        [self.sorted_notes setObject:temp_notes forKey:tmp_key];
                    }
                    [temp_notes addObject:tmp];
                }

                break;
			}
            case Bdat_Beam : 
            {
                //				if( !parseBeam(measureData, count) ) { return false; }
                OveBeam *tmp = [[OveBeam alloc]init];
                [self.beams addObject:tmp];
                [tmp parseBeam:length staff:staff];
			    break;
			}/*
              case Bdat_Harmony : {
              if( !parseHarmony(measureData, count) ) { return false; }
              break;
              }
              */
            case Bdat_Clef : {
                //if( !parseClef(measureData, count) ) { return false; }
                if (self.clefs==nil) {
                    self.clefs=[[NSMutableArray alloc]init ];
                }
                MeasureClef *clef=[MeasureClef parseClef:((self.notes==nil)?0:(int)self.notes.count) staff:staff];
                [self.clefs addObject:clef];
                if (self.meas_length_size<clef.pos.start_offset+50) {
                    self.meas_length_size=clef.pos.start_offset+50;
                }
                break;
            }
            case Bdat_Dynamics : {
                //	if( !parseDynamics(measureData, count) ) { return false; }
                {
                    
                    //                    Dynamics* dynamics = new Dynamics();
                    //                    measureData->addMusicData(dynamics);
                    if (self.dynamics==nil) {
                        self.dynamics=[[NSMutableArray alloc]init ];
                    }
                    OveDynamic *dyn=[OveDynamic parseDynamics:length staff:staff];
                    [self.dynamics addObject:dyn];
                }
                break;
			}
            case Bdat_Wedge : //楔子:stop, crescendo, diminuendo
            {
                //				if( !parseWedge(measureData, count) ) { return false; }
                {
                    //                    Wedge* wedge = new Wedge();
                    if (self.wedges==nil) {
                        self.wedges = [[NSMutableArray alloc]init ];
                    }
                    OveWedge *wedge=[OveWedge parseWedge:length staff:staff];
                    [self.wedges addObject:wedge];
                }
			    break;
			}
            case Bdat_Glissando : //Glissando 滑奏法
            {
//              if( !parseGlissando(measureData, count) ) { return false; }
                //bool BarsParse::parseGlissando(MeasureData* measureData, int /*length*/) 
                if (self.glissandos==nil) {
                    self.glissandos=[[NSMutableArray alloc]init];
                }
                [self.glissandos addObject:[MeasureGlissando parseGlissando]];
                
                break;
            }
            case Bdat_Decorator : 
            {
                if (self.decorators==nil) {
                    self.decorators = [[NSMutableArray alloc]init ];
                }
                [self.decorators addObject:[MeasureDecorators parseDecorator:length staff:staff]];
			    break;
			}
            case Bdat_Key : {
                //	if( !parseKey(measureData, count) ) { return false; }
                //NSLog(@"Bdat_Key");
                [self parseKey];
				break;
			}
            case Bdat_Lyric : {
                //if( !parseLyric(measureData, count) ) { return false; }
                if (self.lyrics==nil) {
                    self.lyrics=[[NSMutableArray alloc]init];
                }
                //NSLog(@"Bdat_Lyric");
                MeasureLyric *tmp_lyric=[MeasureLyric parseLyric:length staff:staff];
                /*A-maz-ing  grace! how sweet the sound That saved a  wretch like me! I Once  was  lost, but now  am  found, Was blind, but  now I see.
                 */
                                
                BOOL already_have=NO;
                for (MeasureLyric *item in self.lyrics)
                {
                    if (item.voice == tmp_lyric.voice && item.verse==tmp_lyric.verse && item.pos.start_offset == tmp_lyric.pos.start_offset && item.staff==tmp_lyric.staff)
                    {
                        already_have=YES;
                        NSLog(@"Error, duplicate lyrics");
                        break;
                    }
                }
                if (!already_have)
                {
                    [self.lyrics addObject:tmp_lyric];
                }
                break;
            }
            
            case Bdat_Octave_Shift: {
                if (self.octaves==nil) {
                    self.octaves=[[NSMutableArray alloc]init ];
                }
                [self.octaves addObject:[OctaveShift parseOctaveShift:staff]];
                break;
            }
            case Bdat_Slur : {
                if (self.slurs==nil) {
                    self.slurs=[[NSMutableArray alloc]init ];
                }
                MeasureSlur *slur=[MeasureSlur parseSlur:length staff:staff];
                [self.slurs addObject:slur];
				break;
			}
            case Bdat_Text : {
                //if( !parseText(measureData, count) ) { return false; }
                if (self.meas_texts==nil) {
                    self.meas_texts=[[NSMutableArray alloc]init ];
                }
                [self.meas_texts addObject:[OveText parseText:length staff:staff]];
                break;
            }
            case Bdat_Tie : 
            {
                if (self.ties==nil) {
                    self.ties = [[NSMutableArray alloc]init ];
                }
                [self.ties addObject:[MeasureTie parseTie:staff]];
			    break;
			}
            case Bdat_Tuplet : 
            {
                //if( !parseTuplet(measureData, count) ) { return false; }
                //bool BarsParse::parseTuplet(MeasureData* measureData, int /*length*/) 
                if (self.tuplets==nil) {
                    self.tuplets = [[NSMutableArray alloc]init ];
                }
                [self.tuplets addObject:[OveTuplet parseTuplet:length staff:staff]];
                break;
            }
                /*
                 case Bdat_Guitar_Bend :
              case Bdat_Guitar_Barre : {
              if( !parseSizeBlock(count) ) { return false; }
              break;
              }*/
            case Bdat_Pedal: {
                //if( !parsePedal(measureData, count) ) { return false; }
                if (self.pedals==nil) {
                    self.pedals = [[NSMutableArray alloc]init ];
                }
                [self.pedals addObject:[MeasurePedal parsePedal:length staff:staff]];
                break;
            }
            /*
              case Bdat_KuoHao: {
              if( !parseKuohao(measureData, count) ) { return false; }
              break;
              }*/
            case Bdat_Expressions: 
            {
                if (self.expresssions==nil) {
                    self.expresssions = [[NSMutableArray alloc]init ];
                }
                MeasureExpressions *expr = [[MeasureExpressions alloc]init];
                [expr parseExpressions:length staff:staff];
                [self.expresssions addObject:expr];
                break;
			}/*
              case Bdat_Harp_Pedal: {
              if( !parseHarpPedal(measureData, count) ) { return false; }
              break;
              }
              case Bdat_Multi_Measure_Rest: {
              if( !parseMultiMeasureRest(measureData, count) ) { return false; }
              break;
              }*/
            case Bdat_Harmony_GuitarFrame: {
                //if( !parseHarmonyGuitarFrame(measureData, count) ) { return false; }
                if (self.harmony_guitar_frames==nil) {
                    self.harmony_guitar_frames=[[NSMutableArray alloc]init ];
                }
                [self.harmony_guitar_frames addObject:[HarmonyGuitarFrame parseHarmonyGuitarFrame:length]];
                break;
            }
            case Bdat_Harmony:{
                JMP(length)
                break;
            }
              
            case Bdat_Graphics_40:
            case Bdat_Graphics_RoundRect:
            case Bdat_Graphics_Rect:
            case Bdat_Graphics_Round:
            case Bdat_Graphics_Line:
            case Bdat_Graphics_Curve:
            case Bdat_Graphics_WedgeSymbol: {
                //if( !parseSizeBlock(count) ) { return false; }
                JMP(length)
                break;
            }
            case Bdat_Midi_Controller : {

              //if( !parseMidiController(measureData, count) ) { return false; }
              // bool BarsParse::parseMidiController(MeasureData* measureData, int /*length*/) {
                if (self.midi_controllers==nil) {
                    self.midi_controllers=[[NSMutableArray alloc]init ];
                }
                [self.midi_controllers addObject:[MidiController parseMidiController:Midi_Controller]];
 
                break;
            }
            
            case Bdat_Midi_Program_Change : {
                //if( !parseMidiProgramChange(measureData, count) ) { return false; }
                if (self.midi_controllers==nil) {
                    self.midi_controllers=[[NSMutableArray alloc]init ];
                }
                [self.midi_controllers addObject:[MidiController parseMidiController:Midi_ProgramChange]];
                break;
            }
            case Bdat_Midi_Channel_Pressure : {
                //if( !parseMidiChannelPressure(measureData, count) ) { return false; }
                if (self.midi_controllers==nil) {
                    self.midi_controllers=[[NSMutableArray alloc]init ];
                }
                [self.midi_controllers addObject:[MidiController parseMidiController:Midi_ChannelPressure]];
                break;
            }
            case Bdat_Midi_Pitch_Wheel : {
                //if( !parseMidiPitchWheel(measureData, count) ) { return false; }
                if (self.midi_controllers==nil) {
                    self.midi_controllers=[[NSMutableArray alloc]init ];
                }
                [self.midi_controllers addObject:[MidiController parseMidiController:Midi_PitchWheel]];
                break;
            }
                
            case Bdat_Bar_End:
            {
                JMP(length)
			    break;
            }
            default: {
                NSLog(@"unknow badt type:0x%x length=%d", type, length);
                JMP(length)
			    break;
			}
		}
        
		// if i==count-1 then is bar end place holder
	}
    /*
    if (notes && notes.count>0) {
        OveNote *firstNote=[notes objectAtIndex:0];
        if (firstNote.staff==2) {
            for (OveBeam *beam in beams) {
                beam.staff=2;
            }
        }
    }*/
	return true;
}
@end

@implementation OvePage

typedef struct {
    unsigned char begin_line,line_count;
    unsigned short system_distance,staff_distance;
}PageDataStruct;

- (NSData*) writeToData
{
    PageDataStruct pageData={
        self.begin_line,self.line_count,self.system_distance,self.staff_distance
    };
    return [NSData dataWithBytes:&pageData length:sizeof(pageData)];
}
+ (OvePage*)loadFromOvsData:(NSData*)ovsData
{
    PageDataStruct pageData;
    MUSK_READ_BUF(&pageData, sizeof(pageData));
    
    OvePage *page=[[OvePage alloc]init];
    page.begin_line=pageData.begin_line;
    page.line_count=pageData.line_count;
    page.system_distance=pageData.system_distance;
    page.staff_distance=pageData.staff_distance;

    return page;
}

- (BOOL) parsePageWithOveMusic:(OveMusic*)music
{
    unsigned char type[4];//"PAGE"
    READ_BUF(type,4)
    UInt32 len;
    READ_U32(len)
    READ_U16(_begin_line)
    READ_U16(_line_count)
//  
    unsigned char tmp[4];
    READ_BUF(tmp, 4)
//    NSLog(@"0x%x,0x%x,0x%x,0x%x", tmp[0],tmp[1],tmp[2],tmp[3]);
//    JMP(4)
    READ_U16(staff_interval)
    READ_U16(_system_distance)
    READ_U16(_staff_distance)
    READ_U16(line_bar_count)
    READ_U16(page_line_count)
    READ_U32(left_margin)
    READ_U32(top_margin)
    READ_U32(right_margin)
    READ_U32(bottom_margin)
    READ_U32(page_width)
    READ_U32(page_height)

    if (music) {
        music.page_width=page_width;
        music.page_top_margin=top_margin/3;
        music.page_bottom_margin=bottom_margin/2;
        music.page_height=page_height-top_margin-bottom_margin;
        music.page_left_margin=left_margin;
        music.page_right_margin=right_margin;
    }
    
    return YES;
}
@end

@implementation LineStaff
@end

@implementation OveLine

typedef struct {
    unsigned char begin_bar_lo,bar_count;
    signed char fifths;
    unsigned char begin_bar_hi;
    short y_offset;
    short staff_count;
}LineDataStruct;

typedef struct {
    signed short y_offset;
    unsigned char clef; //00: 高音, 01:低音 最高bit=0: not hide, 最高bit=1: hide,
    unsigned char group_staff_count;
}StaffDataStruct;

- (NSData*) writeToData
{
    LineDataStruct lineDataStruct={
        .begin_bar_lo = self.begin_bar&0xFF,
        .bar_count = self.bar_count,
        .fifths = self.fifths,
        .begin_bar_hi = (self.begin_bar>>8)&0xFF,
        .y_offset=self.y_offset,
        .staff_count = self.staves.count
    };
    NSMutableData *lineData=[[NSMutableData alloc]initWithBytes:&lineDataStruct length:sizeof(lineDataStruct)];

    StaffDataStruct staffDataStruct;
    for (LineStaff *staff in self.staves) {
        staffDataStruct.y_offset=staff.y_offset;
        if (staff.hide) {
            staffDataStruct.clef=staff.clef|0x80;
        }else{
            staffDataStruct.clef=staff.clef;
        }
        
        staffDataStruct.group_staff_count=staff.group_staff_count;
        [lineData appendBytes:&staffDataStruct length:sizeof(staffDataStruct)];
    }
    return lineData;
}
+ (OveLine*)loadFromOvsData:(NSData*)ovsData
{
    LineDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    OveLine *line=[[OveLine alloc]init];
    line.begin_bar=data.begin_bar_hi;
    line.begin_bar<<=8;
    line.begin_bar|=data.begin_bar_lo;
    
    line.bar_count=data.bar_count;
    line.fifths=data.fifths;
    line.y_offset=data.y_offset;

    if (data.staff_count>0) {
        line.staves=[[NSMutableArray alloc]initWithCapacity:data.staff_count];
        StaffDataStruct staffDataStruct;
        for (int i=0; i<data.staff_count; i++) {
            MUSK_READ_BUF(&staffDataStruct, sizeof(StaffDataStruct));
            LineStaff *staff=[[LineStaff alloc]init];
            staff.y_offset=staffDataStruct.y_offset;
            staff.clef=staffDataStruct.clef&0x7F;
            if (staffDataStruct.clef&0x80) {
                staff.hide=YES;
            }else{
                staff.hide=NO;
            }
            staff.group_staff_count=staffDataStruct.group_staff_count;
            [line.staves addObject:staff];
        }
    }
    return line;
}
- (BOOL) parse
{
    unsigned char thisByte;
    unsigned char type[8];
    READ_BUF(type, 4);
    type[4]=0;
    //NSLog(@"LINE:%s", type);
    
    UInt32 len;
    READ_U32(len)
     
    unsigned char tmp[8];
    READ_BUF(tmp, 2)
//    NSLog(@"0x%x,0x%x", tmp[0],tmp[1]);
//    JMP(2);

    READ_U16(_begin_bar)
    READ_U16(_bar_count)

    unsigned short staff_count;
    READ_U16(staff_count)
    
    //unsigned char tmp[4];
    READ_BUF(tmp, 4)
    //NSLog(@"0x%x,0x%x,0x%x,0x%x", tmp[0],tmp[1],tmp[2],tmp[3]);
    //JMP(4)
    
    READ_U16(_y_offset)
    READ_U16(left_x_offset)
    READ_U16(right_x_offset)

    READ_BUF(tmp, 4)
    //NSLog(@"0x%x,0x%x,0x%x,0x%x", tmp[0],tmp[1],tmp[2],tmp[3]);
//    JMP(4);
    if (self.staves==nil) {
        self.staves=[[NSMutableArray alloc]initWithCapacity:staff_count];
    }
    for (int j=0; j<staff_count; j++) {
        unsigned char key,visible,group_staff_count;
        signed short y_offset1;
        ClefType clef;
        GroupType group_type;
        
        unsigned char type[8];
        READ_BUF(type, 4)
        type[4]=0;
        //NSLog(@"STAF:%s", type);

        UInt32 len;
        READ_U32(len)  //5C
        //00 78 02 DC 01 34 0D
        //00 78 02 5A 01 15 05
        READ_BUF(tmp, 7) 
        //NSLog(@"0x%x,0x%x,0x%x,0x%x,0x%x,0x%x,0x%x", tmp[0],tmp[1],tmp[2],tmp[3],tmp[4],tmp[5],tmp[6]);
//        JMP(7);
        {
            READ_U8(thisByte) //00
            clef = thisByte;
            READ_U8(key) //00
            
            READ_BUF(tmp, 2) //00 01
            //NSLog(@"0x%x,0x%x", tmp[0],tmp[1]);
            //JMP(2);
            
            READ_U8(visible)
            JMP(12);
            READ_U16(y_offset1)
            int jumpAmount = isVersion4 ? 26 : 18;
            JMP(jumpAmount)
            READ_U8(thisByte)
            if (thisByte==1) {
                group_type=Group_Brace;
            }else if(thisByte==2){
                group_type=Group_Bracket;
            }else{
                group_type=Group_None;
            }
            
            READ_U8(group_staff_count)
        }
        
        //NSLog(@"staff[%d] %c%c%c%c len=%lu", j, staff.type[0],staff.type[1],staff.type[2],staff.type[3],staff.len);
        if (isVersion4) {
            JMP(len-54)
        }else{
            JMP(len-54+8)
        }
        
        LineStaff *tmp=[[LineStaff alloc]init];
        tmp.hide=!visible;
        [self.staves addObject:tmp];
        if (visible) {
            tmp.clef=clef;
            tmp.y_offset=y_offset1;
            /*
            tmp.key=key;
            tmp.visible=visible;
            tmp.group_type=group_type;
            */
            tmp.group_staff_count=group_staff_count;
            
            if(key>7){
                self.fifths=key-7;
            }else{
                self.fifths=key*(-1);
            }
        }else{
            tmp.y_offset=0;
            tmp.clef=0;
        }
    }
//    clefs_type[i]=staff.clef;
    return YES;
}
@end

/*

@implementation OveTitle


- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.titles forKey:@"titles"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedLong:self.type] forKey:@"type"];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
    self=[super init];
    if (self) {
        self.titles = [aDecoder decodeObjectForKey:@"titles"];
        NSNumber *num=[aDecoder decodeObjectForKey:@"type"];
        self.type = num.unsignedLongValue;
    }
    return self;
}

- (bool) parseTitle
{
    //chunk size
    UInt32 thunk_size;
    READ_U32(thunk_size)
    
    //title type
	UInt32 titleType;
    READ_U32(titleType)
    
    self.type = titleType;
    
	if( titleType == titleType_ || titleType == instructionsType_ || titleType == writerType_ || titleType == copyrightType_ ) {
        
        //offset
		unsigned char offsetBlock[4];
        READ_BUF(offsetBlock, 4)
        
        //4 items
		const unsigned int itemCount = 4;
		unsigned int i;
		for( i=0; i<itemCount; ++i ) {
			if( i>0 ) {
				//0x 00 AB 00 0C 00 00
                //0x 00 94 00 18 01 00
                JMP(6)
			}
            //item size
			unsigned short titleSize;
            READ_U16(titleSize)
            
            //item content
			char dataBlock[100];
			READ_BUF(dataBlock, titleSize)
            dataBlock[titleSize]=0;
            
            //NSString *text = [NSString stringWithCString:dataBlock encoding:NSUTF8StringEncoding];
            NSString *text = stringFromBuffer(dataBlock);
            if (text && text.length>0) {
                if (self.titles==nil) {
                    self.titles=[[NSMutableArray alloc]init ];
                }
                [self.titles addObject:text];
            }
//            NSLog(@"TITL(%d): type(0x%x)=%s(%@)",i,titleType, dataBlock, text);
		}
        //0x 00 94 00 18 01 00
        JMP(6)
        
		return true;
	}
    
	if( titleType == headerType_ || titleType == footerType_ ) {
        JMP(10)
        
		unsigned short titleSize;
        READ_U16(titleSize)
        
		char dataBlock[100];
        READ_BUF(dataBlock, titleSize)
        dataBlock[titleSize]=0;
        
        NSString *text = stringFromBuffer(dataBlock);//[NSString stringWithCString:dataBlock encoding:NSUTF8StringEncoding];
        if (text && text.length>0) {
            if (self.titles==nil) {
                self.titles=[[NSMutableArray alloc]init ];
            }
            [self.titles addObject:text];
        }
//        NSLog(@"TITL: 0x%x=%s(%@)",titleType, dataBlock, text);

		//0x 00 AB 00 0C 00 00
        JMP(6)
        
		return true;
	}else //other type
    {
        JMP(thunk_size-4)
    }
    
	return false;
}
@end
*/
@implementation XmlPart
@end

@implementation OveTrack

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.start_clef=0;
    }
    return self;
}
- (track_voice*) getVoice
{
    return &voice;
}
- (track_node*) getNode
{
    return &node;
}
typedef struct {
    unsigned char transpose_value,voice_count;
    struct {
        unsigned char channel; //[0,15]
        signed char volume; //[-1,127], -1 default
        signed char pitch_shift; //[-36,36]
        signed char pan;    //[-64,63]
        signed char patch; //[0,127]
        unsigned char reserved;
    }voices[8];
    short track_name_length;
}TrackDataStruct;

- (NSData*) writeToData
{
    TrackDataStruct trackDataStruct={
        .transpose_value=self.transpose_value,
        .voice_count=self.voice_count,
        .track_name_length=0,
    };
    for (int i=0; i<8 && i<self.voice_count; i++) {
        trackDataStruct.voices[i].channel=voice.voices[i].channel;
        trackDataStruct.voices[i].volume=voice.voices[i].volume;
        trackDataStruct.voices[i].pitch_shift=voice.voices[i].pitch_shift;
        trackDataStruct.voices[i].pan=voice.voices[i].pan;
        trackDataStruct.voices[i].patch=voice.voices[i].patch;
    }
    if (self.track_name.length>0) {
        trackDataStruct.track_name_length=strlen(self.track_name.UTF8String);
        if (trackDataStruct.track_name_length%2) {
            trackDataStruct.track_name_length++;
        }
    }
    NSMutableData *data=[[NSMutableData alloc]initWithBytes:&trackDataStruct length:sizeof(trackDataStruct)];
    if (self.track_name.length>0) {
        [data appendBytes:self.track_name.UTF8String length:trackDataStruct.track_name_length];
    }
    return data;
}
+ (OveTrack*)loadFromOvsData:(NSData*)ovsData
{
    TrackDataStruct data;
    MUSK_READ_BUF(&data, sizeof(data));
    
    OveTrack *page=[[OveTrack alloc]init];
    page.transpose_value=data.transpose_value;
    page.voice_count=data.voice_count;
    track_voice *voice = [page getVoice];
    for (int i=0; i<8 && i<data.voice_count; i++) {
        voice->voices[i].channel=data.voices[i].channel;
        if (voice->voices[i].channel>15) {
            voice->voices[i].channel=0;
        }
        voice->voices[i].volume=data.voices[i].volume;
        voice->voices[i].pan=data.voices[i].pan;
        voice->voices[i].patch=data.voices[i].patch;
        voice->voices[i].pitch_shift=data.voices[i].pitch_shift;
        
        //voice->voices[i].channel=1;
        voice->voices[i].pan=0;
        voice->voices[i].volume=-1;
        voice->voices[i].patch=-1;
    }
    
    if (data.track_name_length>0) {
        char *text=malloc(data.track_name_length+1);text[data.track_name_length]=0;
        MUSK_READ_BUF(text, data.track_name_length);
        page.track_name=[NSString stringWithUTF8String:text];
        free(text);
    }
    return page;
}
- (BOOL) parse
{
    unsigned char thisByte;
    //32bytes long track name buffer
    char text[64];
    UInt32 track_len=0;
    READ_BUF(text,32)
    
    //NSLog(@"Track name: %c %c %c %c %c %c",track_name[0],track_name[1],track_name[2],track_name[3],track_name[4],track_name[5]);
    if (memcmp(text, "TRAK", 4)==0) 
    {
        BACK(32-4)
        READ_U32(track_len)
        //NSLog(@"track len=%lu",track_len);
        READ_BUF(text, 32)
    }
    //NSLog(@"Track name: %s",text);
    
    self.track_name = stringFromBuffer(text);//[NSString stringWithCString:text encoding:NSUTF8StringEncoding];
    //NSLog(@"Track breif name: %@",track_name);
    //32 bytes
    READ_BUF(text, 32)
    self.track_brief_name=stringFromBuffer(text);

    //FF FA 00 12, FF FA 00 12
    //FF FA 00 12, FF FA 00 1A
    JMP(8) //0x fffa0012 fffa0012
    
    //        READ_BUF(&flag, 42)
    JMP(1)
    READ_U8(patch)
    patch=patch&0x7F;
    READ_U8_BOOL(show_name)
    READ_U8_BOOL(show_breif_name)
    
    JMP(1)
    READ_U8_BOOL(show_transpose)
    JMP(1)
    READ_U8_BOOL(mute)
    
    READ_U8_BOOL(solo)
    JMP(1)
    READ_U8_BOOL(show_key_each_line)
    READ_U8(_voice_count) //1
    
    JMP(3)
    // transpose value [-127, 127]
    READ_U8(_transpose_value)
    if (!show_transpose) {
        _transpose_value=0;
    }
    
    JMP(2)
    READ_U8(thisByte)
    self.start_clef=thisByte;
    READ_U8(thisByte)
    self.transpose_celf=thisByte;
    
    READ_U8(start_key)
    READ_U8(display_percent)
    READ_U8_BOOL(show_leger_line)
    READ_U8_BOOL(show_clef)
    
    READ_U8_BOOL(show_time_signature)
    READ_U8_BOOL(show_key_signature)
    READ_U8_BOOL(show_barline)
    READ_U8_BOOL(fill_with_rest);
    
    READ_U8_BOOL(flat_tail)
    READ_U8_BOOL(show_clef_each_line);
    JMP(12)
    
    //track_voice 16*8+8 = 136bytes
    READ_BUF(&voice, sizeof(voice))
    //NSLog(@"track voices channel=%d, volume=%d, pitch_shift=%d,pan=%d", voice.voices[0].channel,voice.voices[0].volume,voice.voices[0].pitch_shift,voice.voices[0].pan);
    /*
    NSLog(@"voice.channel[%d,%d,%d,%d,]", voice.voices[0].channel,voice.voices[1].channel,voice.voices[2].channel,voice.voices[3].channel);
    NSLog(@"voice.pitch_shift[%d,%d,%d,%d,]", voice.voices[0].pitch_shift,voice.voices[1].pitch_shift,voice.voices[2].pitch_shift,voice.voices[3].pitch_shift);
    NSLog(@"voice.volume[%d,%d,%d,%d,]", voice.voices[0].volume,voice.voices[1].volume,voice.voices[2].volume,voice.voices[3].volume);
    NSLog(@"voice.pan[%d,%d,%d,%d,]", voice.voices[0].pan,voice.voices[1].pan,voice.voices[2].pan,voice.voices[3].pan);
*/
    //打击乐 percussion define
    enum NoteHeadType {
        NoteHead_Standard	= 0x00,
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
        NoteHead_Open_Ti
    };
    
    //nodes
    READ_BUF(&node, sizeof(node))
    //NSLog(@"track nodes len=%lu track_len=%lu", sizeof(node), track_len);
    for (int i=0; i<16; i++) {
        NSLog(@"%d:%d,%d,%d", node.line[i], node.head_type[i], node.pitch[i], node.voice[i]);
    }
    if (track_len>0) {
        //NSLog(@"track_len=%lu", track_len);
        JMP((track_len-32-32-8-42-136-16*4))
    }
    return YES;
}
+ (OveTrack*) parseTrack
{
    OveTrack *tmp=[[OveTrack alloc]init];
    [tmp parse];
    return tmp;
}
@end

//__strong OveData *g_oveData=nil;
OveMusic *g_oveMusic=nil;
@interface OveMusic()
{
    //NSString *work_title;
    //OVSC
    //unsigned char version;
    BOOL show_page_margin,show_transpose_track;
    BOOL play_repeat;
    PlayStyle play_style;//1:Swing, 2:Notation, others: Record
    BOOL show_line_break, show_ruler,show_color;
}
@property (nonatomic, strong) OveData *g_oveData;
@end

@implementation OveMusic
@synthesize version;

+ (OveData*) ove_data
{
    return g_oveMusic.g_oveData;
}

- (bool) OvscParse 
{
    unsigned char thisByte;
    UInt32 len;
    //header length
    READ_U32(len)
    
    //version
    READ_U8(version)
    isVersion4 = (version==4);
    
    JMP(6)//02 04 00 07 00 00
    
    // show page margin
    READ_U8_BOOL(show_page_margin)

    JMP(1)
    
    //show_transpose_track
    READ_U8_BOOL(show_transpose_track)
    
    // play repeat
    READ_U8_BOOL(play_repeat)

    // play style
	READ_U8(thisByte)
	play_style = Record;
    if (thisByte==1) {
        play_style=Swing;
    }else if(thisByte == 2){
		play_style = Notation;
	}
    
	// show line break
    READ_U8_BOOL(show_line_break)
    
	// show ruler
    READ_U8_BOOL(show_ruler)

	// show color
    READ_U8_BOOL(show_color)

    
    NSLog(@"This file is create by Overture %d",version);
    JMP(len-15)
	return true;
}

-(BOOL) TrackParse
{
    unsigned short track_count;
    READ_U16(track_count)
    if (self.trackes==nil) {
        self.trackes=[[NSMutableArray alloc]initWithCapacity:track_count];
    }
    for (int i=0; i<track_count; i++) 
    {
        [self.trackes addObject:[OveTrack parseTrack]];
    }
    return true;
}
/*
- (BOOL) parsePage
{
    unsigned short begin_line,line_count;
    unsigned short staff_interval;//组间距: 没有用
    unsigned short line_interval;
    unsigned short line_bar_count;
    unsigned short page_line_count;
    unsigned short staff_inline_interval;//同一组内谱表间距
    
    unsigned char type[4];//"PAGE"
    READ_BUF(type,4)
    UInt32 len;
    READ_U32(len)
    READ_U16(begin_line)
    READ_U16(line_count)
    //
    unsigned char tmp[4];
    READ_BUF(tmp, 4)
    //    NSLog(@"0x%x,0x%x,0x%x,0x%x", tmp[0],tmp[1],tmp[2],tmp[3]);
    //    JMP(4)
    READ_U16(staff_interval)
    self.system_distance=staff_interval;
    READ_U16(line_interval)
    READ_U16(staff_inline_interval)
    self.staff_distance=staff_inline_interval;
    READ_U16(line_bar_count)
    READ_U16(page_line_count)
    READ_U32(_page_left_margin)
    READ_U32(_page_top_margin)
    READ_U32(_page_right_margin)
    READ_U32(_page_bottom_margin)
    READ_U32(_page_width)
    READ_U32(_page_height)
    
    return YES;
}
*/
-(bool) PageGroupParse
{
    unsigned short page_count;
    READ_U16(page_count)
    
    self.pages = [[NSMutableArray alloc]initWithCapacity:page_count];
    
    for (int i=0; i<page_count; i++) {
        OvePage *tmp=[[OvePage alloc]init];
        [self.pages addObject:tmp];
        if (i==0) {
            [tmp parsePageWithOveMusic:self];
        }else{
            [tmp parsePageWithOveMusic:nil];
        }
        //[self parsePage];
    }
    return true;
}

-(bool) LineGroupParse
{
    unsigned short line_count;
    READ_U16(line_count);
    self.lines = [[NSMutableArray alloc]initWithCapacity:line_count];
    
    for (int i=0; i<line_count; i++) {
        OveLine *tmp=[[OveLine alloc]init];
        [tmp parse];
        [self.lines addObject:tmp];
    }
    
    return YES;
}
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
- (bool) parseTitle
{
    //chunk size
    UInt32 thunk_size;
    READ_U32(thunk_size)
    
    //title type
	UInt32 titleType;
    READ_U32(titleType)
    
	if( titleType == titleType_ || titleType == instructionsType_ || titleType == writerType_ || titleType == copyrightType_ ) {
        
        //offset
		unsigned char offsetBlock[4];
        READ_BUF(offsetBlock, 4)
        
        //4 items
		const unsigned int itemCount = 4;
		unsigned int i;
		for( i=0; i<itemCount; ++i ) {
			if( i>0 ) {
				//0x 00 AB 00 0C 00 00
                //0x 00 94 00 18 01 00
                JMP(6)
			}
            //item size
			unsigned short titleSize;
            READ_U16(titleSize)
            
            //item content
			char dataBlock[100];
			READ_BUF(dataBlock, titleSize)
            dataBlock[titleSize]=0;
            
            //NSString *text = [NSString stringWithCString:dataBlock encoding:NSUTF8StringEncoding];
            NSString *text = stringFromBuffer(dataBlock);
            if (text && text.length>0) {
                if (titleType==titleType_) {
                    if (self.work_title==nil) {
                        self.work_title = text;
                    }else{
                        self.work_number = text;
                    }
                }else if (titleType==writerType_)
                {
                    if (self.composer==nil) {
                        self.composer=text;
                    }else{
                        self.lyricist=text;
                    }
                }else if (titleType==copyrightType_)
                {
                    self.rights=text;
                }else if (titleType==instructionsType_)
                {
                }else{
                    NSLog(@"unknow title(type:0x%x):%@", (unsigned int)titleType, text);
                }
            }
		}
        //0x 00 94 00 18 01 00
        JMP(6)
        
		return true;
	}
    
	if( titleType == headerType_ || titleType == footerType_ ) {
        JMP(10)
        
		unsigned short titleSize;
        READ_U16(titleSize)
        
		char dataBlock[100];
        READ_BUF(dataBlock, titleSize)
        dataBlock[titleSize]=0;
        
        NSString *text = stringFromBuffer(dataBlock);//[NSString stringWithCString:dataBlock encoding:NSUTF8StringEncoding];
        if (text && text.length>0) {
            NSLog(@"unknow title(type:0x%x):%@", (unsigned int)titleType, text);
        }
        //        NSLog(@"TITL: 0x%x=%s(%@)",titleType, dataBlock, text);
        
		//0x 00 AB 00 0C 00 00
        JMP(6)
        
		return true;
	}else //other type
    {
        JMP(thunk_size-4)
    }
	return false;
}
- (bool) TitleChunkParse
{
    [self parseTitle];    
    return false;
}
// only ove3 has this chunk
- (bool) LyricChunkParse
{
    UInt32 thunk_size;
    READ_U32(thunk_size)
    JMP(4)
    
	// Lyric count
    unsigned short count;
    READ_U16(count)
    
	for(int i=0; i<count; ++i ) {
		//LyricInfo info;
        unsigned char voice, verse, track,fontSize,fontStyle;
        unsigned short measure, wordCount,lyricSize,font;
        //NSString *lyric_name;
        NSString *lyric_text=nil;
        
        unsigned short tmp_size;
        READ_U16(tmp_size)
		//if( !readBuffer(placeHolder, 2) ) { return false; }
		//unsigned int size = placeHolder.toUnsignedInt();
        
		// 0x0D00
        JMP(2)
        
		// voice
        READ_U8(voice)
        
		// verse
        READ_U8(verse)
        
		// track
        READ_U8(track)
        
        JMP(1)
        
		// measure
        READ_U16(measure)
        
		// word count
        READ_U16(wordCount)
        
		// lyric size
        READ_U16(lyricSize)

        JMP(6)
        
		// name
        char name[32];
        READ_BUF(name, 32)
        //lyric_name = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];

		if(lyricSize > 0 ) {
			// lyric
            char *text;
            text=malloc(lyricSize+1);text[lyricSize]=0;
            READ_BUF(text, lyricSize)
            lyric_text = stringFromBuffer(text);//[NSString stringWithCString:text encoding:NSUTF8StringEncoding];
            free(text);
            //NSLog(@"%d:%@", i, lyric_text);

            JMP(4)
            
			// font
            READ_U16(font)

            JMP(1)
            
			// font size
            READ_U8(fontSize)
            
			// font style
            READ_U8(fontStyle)
            
            JMP(1)
            
			for( int j=0; j<wordCount; ++j ) {
                JMP(8)
			}
		}
        
		//processLyricInfo(info);
        if (!isVersion4 && lyric_text!=nil)
        {
            int index = 0; //words
            int measureId = measure-1;
            bool changeMeasure = true;
            //MeasureData* measureData = 0;
            OveMeasure *measureData=nil;
            long trackMeasureCount = self.measures.count;//ove_->getTrackBarCount();
            //QStringList words = info.lyric_.split(" ", QString::SkipEmptyParts);
            NSCharacterSet *separator=[NSCharacterSet characterSetWithCharactersInString:@" -"];
            NSArray *tmp_words = [lyric_text componentsSeparatedByCharactersInSet:separator];
            NSMutableArray *words=[[NSMutableArray alloc]init ];
            for (int nn=0;nn<tmp_words.count;nn++)
            {
                NSString *item = [tmp_words objectAtIndex:nn];
                //NSLog(@"words[%d]=%@", nn,item);
                if (item && item.length>0) {
                    [words addObject:item];
                }
            }
            while ( index < words.count && measureId+1 < trackMeasureCount) {
                if( changeMeasure ) {
                    ++measureId;
                    measureData = [self.measures objectAtIndex:measureId];
                    //measureData = ove_->getMeasureData(info.track_, measureId);
                    //changeMeasure = false;
                }
                
                if( measureData == nil ) { return false; }
                NSMutableArray *lyrics = measureData.lyrics;
                for(int note_index=0; note_index<measureData.notes.count && index<words.count; ++note_index ) 
                {
                    OveNote *note=[measureData.notes objectAtIndex:note_index];
                    if( note.isRest || note.voice != voice || note.staff-1!=track) {
                        continue;
                    }
                    for(int j=0; j<lyrics.count; ++j ) 
                    {
                        MeasureLyric* lyric =  [lyrics objectAtIndex:j];//static_cast<Lyric*>(lyrics[j]);
                        if( note.pos.start_offset == lyric.pos.start_offset && lyric.verse == verse ) 
                        {
                            if(index<words.count) {
                                NSString *l=[words objectAtIndex:index];
                                //QString l = words[index].trimmed();
                                if(l && l.length>0) {
                                    if (lyric.lyric_text==nil) {
                                        lyric.lyric_text=l;
                                    }else{
                                        lyric.lyric_text=[NSString stringWithFormat:@"%@ %@", lyric.lyric_text,l];
                                    }
                                    lyric.voice=voice;
                                }
                            }
                            ++index;
                        }
                    }
                }
                
                changeMeasure = true;
            }
        }

	}
    
	return true;
}
-(void) organizeMusic{
    
    //
	for (int mm=0; mm<self.measures.count; mm++) {
        OveMeasure* measure=[self.measures objectAtIndex:mm];
#if 0
        //move finger from decorators to note_arts
        for (int dd=0;dd<measure.decorators.count;dd++)
        {
            MeasureDecorators *deco = [measure.decorators objectAtIndex:dd];
            if ((deco.artType>=Articulation_Finger_1 && deco.artType<=Articulation_Finger_5) ||
                (deco.artType==Articulation_Staccato || //staccato跳音 音符上面一个点
                 deco.artType==Articulation_Heavy_Attack ||
                 deco.artType==Articulation_Tenuto || //tenuto 保持音 音符上面一条横线
                 deco.artType==Articulation_Marcato || deco.artType==Articulation_Marcato_Dot || //accent 重音 音符上面一个大于号“>”
                 deco.artType==Articulation_SForzando || deco.artType==Articulation_SForzando_Inverted || //strong_accent_placement  音符上面一个"^" or "V"
                 deco.artType==Articulation_SForzando_Dot ||deco.artType==Articulation_SForzando_Dot_Inverted ||
                 deco.artType==Articulation_Heavier_Attack || //"^" or "V" 里加一个点
                 deco.artType==Articulation_Staccatissimo //staccatissimo_placement 顿音 音符上面一个实心的三角形
                 )
                )
            {
                BOOL found=NO;
                for (int nn=0;nn<measure.notes.count;nn++) {
                    OveNote *note = [measure.notes objectAtIndex:nn];
                    if (note.staff == deco.staff) {
                        if (deco.pos.tick<=note.pos.tick) {
                            found=YES;
                        }else if (deco.pos.tick>note.pos.tick)
                        {
                            if (nn<measure.notes.count-1) {
                                OveNote *nextNote=[measure.notes objectAtIndex:nn+1];
                                if (nextNote.staff>deco.staff || deco.pos.tick<nextNote.pos.tick)
                                {
                                    found=YES;
                                }else if (nextNote && deco.pos.start_offset-note.pos.start_offset<nextNote.pos.start_offset-deco.pos.start_offset) //或者更靠近前一个note
                                {
                                    found=YES;
                                }
                            }else{
                                found=YES;
                            }
                        }
                        if (found) {
                            NoteArticulation *art=[[NoteArticulation alloc]init];
                            art.art_type=deco.artType;
                            art.art_placement_above = (deco.offset_y<0);
                            art.offset=[[OffsetElement alloc]init];
                            art.offset.offset_x = 0;
                            art.offset.offset_y = fabs(deco.offset_y);
                            if (note.note_arts==nil) {
                                note.note_arts=[[NSMutableArray alloc]init];
                            }
                            [note.note_arts addObject:art];
                            found=YES;
                            [measure.decorators removeObject:deco];dd--;
                            break;
                        }
                    }
                }
                if (!found) {
                    NSLog(@"Error can not find deco in measure(%d) notes!", mm);
                }
            }
        }
        //relayout fingers
        for (int nn=0;nn<measure.notes.count;nn++) {
            OveNote *note = [measure.notes objectAtIndex:nn];
            NSMutableArray *finger_arts=[[NSMutableArray alloc]init];
            int offset_y_start=0;
            for (NoteArticulation *item in note.note_arts)
            {
                if (item.art_type>=Articulation_Finger_1 && item.art_type<=Articulation_Finger_5) {
                    int i=0;
                    for (i=0;i<finger_arts.count;i++) {
                        NoteArticulation *old = [finger_arts objectAtIndex:i];
                        if (item.art_type<old.art_type) {
                            [finger_arts insertObject:item atIndex:i];
                            break;
                        }
                    }
                    if (i==finger_arts.count) {
                        [finger_arts addObject:item];
                    }
                }else if (item.art_type==Articulation_Staccato || //staccato跳音 音符上面一个点
                          item.art_type==Articulation_Heavy_Attack ||
                          item.art_type==Articulation_Tenuto || //tenuto 保持音 音符上面一条横线
                          item.art_type==Articulation_Marcato || item.art_type==Articulation_Marcato_Dot || //accent 重音 音符上面一个大于号“>”
                          item.art_type==Articulation_SForzando || item.art_type==Articulation_SForzando_Inverted || //strong_accent_placement  音符上面一个"^" or "V"
                          item.art_type==Articulation_SForzando_Dot ||item.art_type==Articulation_SForzando_Dot_Inverted ||
                          item.art_type==Articulation_Heavier_Attack || //"^" or "V" 里加一个点
                          item.art_type==Articulation_Staccatissimo //staccatissimo_placement 顿音 音符上面一个实心的三角形
                          )
                {
                    item.offset.offset_y=0;
                    item.offset.offset_x=0;
                    offset_y_start+=20;
                }
            }
            for (int i=0;i<finger_arts.count;i++) {
                NoteArticulation *item = [finger_arts objectAtIndex:i];
                if (note.staff%2==1) { //right hand:
                    if (item.art_placement_above) {
                        item.offset.offset_y=i*40+offset_y_start;
                    }else{
                        item.offset.offset_y=(finger_arts.count-1-i)*40+offset_y_start;
                        //item.offset.offset_y=(finger_arts.count-i)*40+offset_y_start;
                    }
                }else{ //left hand
                    if (item.art_placement_above) {
                        item.offset.offset_y=(finger_arts.count-1-i)*40+offset_y_start;
                    }else{
                        item.offset.offset_y=i*40+offset_y_start;
                    }
                }
            }
        }
#endif
        // octave shift
        for (int oo=0; oo<measure.octaves.count; oo++) {
            OctaveShift* octave = [measure.octaves objectAtIndex:oo];
            for (int nn=0; nn<measure.notes.count; nn++) {
                OveNote *note=[measure.notes objectAtIndex:nn];
                if ((octave.pos.start_offset<=note.pos.start_offset) && (octave.end_tick>note.pos.tick)) {
                    int shift = 12;
                    switch (octave.octaveShiftType) {
                        case OctaveShift_8_Start:
                        case OctaveShift_8_Stop: 
                        case OctaveShift_8_Continue:
                        case OctaveShift_8_StartStop:
                        {
                            shift = 12;
                            break;
                        }
                        case OctaveShift_Minus_8_Start:
                        case OctaveShift_Minus_8_Stop:
                        case OctaveShift_Minus_8_Continue:
                        case OctaveShift_Minus_8_StartStop:
                        {
                            shift = -12;
                            break;
                        }
                        case OctaveShift_15_Start: 
                        case OctaveShift_15_Continue: 
                        case OctaveShift_15_Stop: 
                        case OctaveShift_15_StartStop: 
                        {
                            shift = 24;
                            break;
                        }
                        case OctaveShift_Minus_15_Continue:
                        case OctaveShift_Minus_15_Start:
                        case OctaveShift_Minus_15_Stop:
                        case OctaveShift_Minus_15_StartStop:
                        {
                            shift = -24;
                            break;
                        }
                        default:
                            break;
                    }
                    note.noteShift=shift;
                }
            }
        }
    }
}
- (BOOL) loadOve:(NSData*)data
{
    BOOL ret=YES;
    NSLog(@"start parse OVE");
    self.g_oveData = [[OveData alloc ]initWithData: data];
    g_oveMusic=self;

    while (YES) {
        unsigned char nameThunk[4];
        READ_BUF(nameThunk, 4)
        //NSLog(@"read %c%c%c%c",nameThunk[0],nameThunk[1],nameThunk[2],nameThunk[3]);
        
        if (memcmp(nameThunk, "OVSC", 4)==0) 
        {
            [self OvscParse];
        }else if(memcmp(nameThunk, "TRKL",4)==0) //tracks
        {
            [self TrackParse];
        }else if(memcmp(nameThunk, "PAGL",4)==0) {//page
            [self PageGroupParse];
        }else if(memcmp(nameThunk, "LINL",4)==0) {//line
            [self LineGroupParse];
        }else if(memcmp(nameThunk, "BARL",4)==0)  //bars
        {
            unsigned short bars_count;
            READ_U16(bars_count)
            if (bars_count==0) {
                NSLog(@"Error: wrong BARL format.");
                ret=NO;
                break;
            }
            self.max_measures = bars_count;
            //创建所有小节
            self.measures = [[NSMutableArray alloc]init];
            for (int i=0; i<bars_count; i++) {
                OveMeasure *music_measure = [[OveMeasure alloc]init];
                [self.measures addObject:music_measure];
            }

            for (int i=0; i<bars_count; i++) {
                unsigned char bars_type[4]; //"MEAS"
                READ_BUF(bars_type, 4)
                //NSLog(@"BARL(%d): %c%c%c%c", i, bars_type[0],bars_type[1],bars_type[2],bars_type[3]);
                OveMeasure *music_measure = [self.measures objectAtIndex:i];
                [music_measure parseMeasure];
                if (i==bars_count-1 && music_measure.right_barline==Barline_Default) {
                    music_measure.right_barline=Barline_Final;
                }
                //set belone2line for each measure
                for (int ll=0; ll<self.lines.count; ll++) {
                    OveLine *line=[self.lines objectAtIndex:ll];
                    if (i>=line.begin_bar && i<line.begin_bar+line.bar_count) {
                        music_measure.belone2line=ll;
                        break;
                    }
                }
            }

            for (int i=0; i<bars_count; i++) {
                unsigned char bars_type[4]; //"COND"
                READ_BUF(bars_type, 4)
                //NSLog(@"COND(%d): %c%c%c%c", i, bars_type[0],bars_type[1],bars_type[2],bars_type[3]);
                OveMeasure *music_measure = [self.measures objectAtIndex:i];
                [music_measure parseCond];
            }

            BOOL isSepcailOveture4=NO;
            for (int i=0; ; i++) {
                char bars_type[4]; //"BDAT"
                READ_BUF(bars_type, 4)
                //NSLog(@"BARL: %c%c%c%c",bars_type[0],bars_type[1],bars_type[2],bars_type[3]);
                if (strncmp("BDAT", bars_type,4)!=0) {
                    if (memcmp("BD", &bars_type[2], 2)==0) {
                        JMP(-2)
                        isSepcailOveture4=YES;
                        READ_BUF(bars_type, 4)
                        if (strncmp("BDAT", bars_type,4)!=0){
                            JMP(-6)
                            break;
                        }
                    }else{
                        JMP(-4)
                        break;
                    }
                }
                
                if (i%bars_count<self.measures.count) 
                {
                    OveMeasure * music_measure = [self.measures objectAtIndex:i%bars_count];
                    //NSLog(@"measure %d", i%bars_count);
                    
                    [music_measure parseBdat:i%bars_count staff: i/bars_count+1];
                    //music_measure.sorted_duration_offset=[music_measure.sorted_notes.allKeys sortedArrayUsingSelector:@selector(compare:)];
                    [music_measure checkDontPlayedNotes];
                    music_measure.sorted_duration_offset=[music_measure.sorted_notes.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString* obj1, NSString* obj2) {
                        return [obj1 intValue]>[obj2 intValue];
                    }];
                    //NSLog(@"measure %d", music_measure.number);
                }
                if (isSepcailOveture4) {
                    JMP(2)
                }
            }
//            [self postMusicProcess];
        }else if (memcmp(nameThunk, "TITL",4)==0) {//title
            [self TitleChunkParse];
        }else if(memcmp(nameThunk, "LYRC",4)==0){//only OVE3 has this chunk //LyricChunkParse 
			//parse.setLyricChunk(&lyricChunk);
            [self LyricChunkParse];
        }else if (memcmp(nameThunk, "COND",4)==0 || //no use
                  memcmp(nameThunk, "BDAT",4)==0 //no use
                  )
        {
            UInt32 thunk_size;
            READ_U32(thunk_size)
            NSLog(@"Error: the tag: %c%c%c%c should not be here",nameThunk[0],nameThunk[1],nameThunk[2],nameThunk[3]);
            JMP(thunk_size)
        }else if( memcmp(nameThunk, "PACH",4)==0 || //size chunk
                  memcmp(nameThunk, "FNTS",4)==0 || //size chunk
                  memcmp(nameThunk, "ODEV",4)==0 || //size chunk
                  memcmp(nameThunk, "ALOT",4)==0 || //size chunk
                  memcmp(nameThunk, "FMAP",4)==0 || //size chunk
                  memcmp(nameThunk, "SSET",4)==0 || //size chunk
                  memcmp(nameThunk, "PCPR",4)==0 //size chunk
                  ) 
        {
            UInt32 thunk_size;
            READ_U32(thunk_size)
            NSLog(@"Warn: no used tag: %c%c%c%c",nameThunk[0],nameThunk[1],nameThunk[2],nameThunk[3]);
            JMP(thunk_size)
        }else if(memcmp(nameThunk, "ENGR",4)==0)//谱面
        {
            UInt32 thunk_size;
            READ_U32(thunk_size)
            //00 04 00 05
            JMP(4)
            
            //spaces between staves 
            unsigned short spaces_between_staves;
            READ_U16(spaces_between_staves)
            
            //spaces between systems 不同系统之间的距离
            unsigned short spaces_between_systems;
            READ_U16(spaces_between_systems)
            
            //spaces between groups 同一系统内，不同乐器之间的具体
            unsigned short spaces_between_groups;
            READ_U16(spaces_between_groups)
            
            //00 00 00 00 00 00
            JMP(6)
            
            //00 03
            //barline宽度
            unsigned short barline_thickness;
            READ_U16(barline_thickness)
            
            //00 06
            //两个横梁之间的间距
            unsigned short spaces_between_beam;
            READ_U16(spaces_between_beam)
            
            //00 0C ＝12
            //横梁的线宽
            unsigned short beam_thickness;
            READ_U16(beam_thickness)
            
            //00 02
            //符干的线宽
            unsigned short stem_thickness; 
            READ_U16(stem_thickness)
            //00 02
            //谱线宽度
            unsigned short line_thickness;
            READ_U16(line_thickness)
            //00 02
            //上下加线的宽度
            unsigned short more_line_thickness;//
            READ_U16(more_line_thickness)
            
            //00 00
            JMP(2)
            
            //00 00 01 20 =288
            JMP(4)
            
            //00 18 =24
            //谱号到barline的距离
            JMP(2)
            
            //00 18 =24
            //音符到barline的距离
            JMP(2)
            
            //00 78 =120
            //谱号(clef)到音符(note)的距离
            unsigned short clef_note_distance;
            READ_U16(clef_note_distance)
            
            //00 54 =84
            //谱号(clef)到其他音符的默认距离
            unsigned short clef_other_distance;
            READ_U16(clef_other_distance)
            
            //00 3c =60
            //
            JMP(2)
            
            //00 24 =36
            //调号（key）到其他音符的默认距离
            unsigned short key_other_distance;
            READ_U16(key_other_distance)
            
            //00 30 =48
            //拍号到其他音符的默认距离
            unsigned short tempo_other_distance;
            READ_U16(tempo_other_distance)
            
            //00 18 =24
            //每一行的终止小节和前面的距离
            unsigned short endline_other_distance;
            READ_U16(endline_other_distance)
            
            //00x14
            JMP(14)

            //00 01
            //变音记号与音符间距
            unsigned short key_note_distance;
            READ_U16(key_note_distance)
            
            //00 00 00 3C =60
            JMP(4)
            
            //00 41 =65
            JMP(2)
            
            //00 02
            JMP(2)
            
            //00 10 =16
            JMP(2)
            
            //00 00 00 00 00 00
            JMP(6)
            
            if (isVersion4) {
                //00 04
                //同音高连线tie的线宽
                unsigned short tie_line_thickness;
                READ_U16(tie_line_thickness)
                
                //00 04
                //不同音高连线slur的线宽
                unsigned short slur_line_thickness;
                READ_U16(slur_line_thickness)
                
                //00x14
                JMP(14)
            }else{
                //00 00
                JMP(2)
            }
            //JMP(thunk_size)
        }else if(memcmp(nameThunk, "VSTD",4)==0) //VST插件描述
        {
            UInt32 thunk_size;
            READ_U32(thunk_size)
            
            JMP(thunk_size)
        }else if(memcmp(nameThunk, "ARTI",4)==0) //
        {
            UInt32 thunk_size;
            READ_U32(thunk_size)
            
            JMP(thunk_size)
        }else if(memcmp(nameThunk, "\xFF\xFF\xFF\xFF",4)==0)
        {
            NSLog(@"paser End");
            break;
        }else if(memcmp(nameThunk, "OVP0",4)==0)
        {
            NSLog(@"Error: not support OVP0 format");
            ret=NO;
            break;
        }else//
        {
            UInt32 thunk_size;
            READ_U32(thunk_size)
            //NSLog(@"Error: unknown tag: %c%c%c%c",nameThunk[0],nameThunk[1],nameThunk[2],nameThunk[3]);
            JMP(thunk_size)
            break;
        }
    }
    
    [self organizeMusic];
    return ret;
}

+ (NSDictionary*)getOveMusicInfo:(NSString*)file
{
    NSData *ovsData = [NSData dataWithContentsOfFile:file];
    g_oveMusic=[[OveMusic alloc]init];
    
    NSLog(@"start parse OVE");
    g_oveMusic.g_oveData = [[OveData alloc ]initWithData: ovsData];
    //g_oveMusic=self;
    NSDictionary *dict=nil;
    NSString *work_title=@"", *composer=@"", *work_number, *lyricist, *rights;
    
    NSRange search_range;
    search_range.location=0;
    search_range.length=ovsData.length;
    
    while (YES) {
        NSRange range = [ovsData rangeOfData:[NSData dataWithBytes:"TITL" length:4] options:NSDataSearchBackwards range:search_range];
        if (range.length==0) {
            break;
        }
        SEEK((int)range.location);
        search_range.length=range.location;
        
        unsigned char nameThunk[4];
        READ_BUF(nameThunk, 4)
        
        if (memcmp(nameThunk, "TITL",4)==0) {//title
            //chunk size
            UInt32 thunk_size;
            READ_U32(thunk_size)
            
            //title type
            UInt32 titleType;
            READ_U32(titleType)
            
            if( titleType == titleType_ || titleType == instructionsType_ || titleType == writerType_ || titleType == copyrightType_ ) {
                
                //offset
                unsigned char offsetBlock[4];
                READ_BUF(offsetBlock, 4)
                
                //4 items
                const unsigned int itemCount = 4;
                unsigned int i;
                for( i=0; i<itemCount; ++i ) {
                    if( i>0 ) {
                        //0x 00 AB 00 0C 00 00
                        //0x 00 94 00 18 01 00
                        JMP(6)
                    }
                    //item size
                    unsigned short titleSize;
                    READ_U16(titleSize)
                    
                    //item content
                    char dataBlock[100];
                    READ_BUF(dataBlock, titleSize)
                    if (titleSize>100) {
                        titleSize=99;
                    }
                    dataBlock[titleSize]=0;
                    
                    //NSString *text = [NSString stringWithCString:dataBlock encoding:NSUTF8StringEncoding];
                    NSString *text = stringFromBuffer(dataBlock);
                    if (text && text.length>0) {
                        if (titleType==titleType_) {
                            if (work_title.length==0) {
                                work_title = text;
                            }else{
                                work_number = text;
                            }
                        }else if (titleType==writerType_)
                        {
                            if (composer.length==0) {
                                composer=text;
                            }else{
                                lyricist=text;
                            }
                        }else if (titleType==copyrightType_)
                        {
                            rights=text;
                        }else if (titleType==instructionsType_)
                        {
                        }else{
                            NSLog(@"unknow title(type:0x%x):%@", (unsigned int)titleType, text);
                        }
                    }
                }
                //0x 00 94 00 18 01 00
                JMP(6)
            }
            
            if( titleType == headerType_ || titleType == footerType_ ) {
                JMP(10)
                
                unsigned short titleSize;
                READ_U16(titleSize)
                
                char dataBlock[100];
                READ_BUF(dataBlock, titleSize)
                dataBlock[titleSize]=0;
                
                NSString *text = stringFromBuffer(dataBlock);//[NSString stringWithCString:dataBlock encoding:NSUTF8StringEncoding];
                if (text && text.length>0) {
                    NSLog(@"unknow title(type:0x%x):%@", (unsigned int)titleType, text);
                }
                //        NSLog(@"TITL: 0x%x=%s(%@)",titleType, dataBlock, text);
                
                //0x 00 AB 00 0C 00 00
                JMP(6)
                
            }else //other type
            {
                JMP(thunk_size-4)
            }
        }
    }
    if (work_title.length>0 && composer.length>0) {
        dict=@{@"composer":composer, @"title":work_title};
    }else{
        if (work_title.length>0) {
            dict=@{@"title":work_title};
        }else  if (composer.length>0) {
            dict=@{@"title":work_title};
        }
    }
    g_oveMusic.g_oveData=nil;
    g_oveMusic=nil;
    return dict;
}
+ (NSDictionary*)getVmusMusicInfo:(NSString*)file
{
    NSData *ovsData = [NSData dataWithContentsOfFile:file];
    if (ovsData) {
        int next_tag_pos=0;
        NSString *work_title, *composer,*lyricist,*work_number;
        MuskBlock blockHead;
        while (next_tag_pos<ovsData.length-4) {
            MUSK_SET_POS(next_tag_pos);
            MUSK_READ_BUF(&blockHead, sizeof(blockHead));
            switch (blockHead.tags) {
                case MUSK:
                    local_pos+=blockHead.size;
                    break;
                case TITL:
                {
#define GET_TITLE(title_name)\
{   \
unsigned short len; \
MUSK_READ_BUF(&len, 2); \
if (len>0)  \
{   \
char *text=malloc(len+1); text[len]=0;  \
MUSK_READ_BUF(text, len);   \
title_name = [NSString stringWithUTF8String:text];    \
free(text); \
}   \
}
                    GET_TITLE(work_title);
                    GET_TITLE(composer);
                    GET_TITLE(lyricist);
                    GET_TITLE(work_number);
                    if (composer && work_title) {
                        return @{@"composer": composer, @"title":work_title};
                    }else{
                        return nil;
                    }
                }
                default:
                    NSLog(@"unknown tag: 0x%x, %s", (unsigned int)blockHead.tags, (char*)&blockHead.tags);
                    local_pos+=blockHead.size;
                    break;
            }
            next_tag_pos+=blockHead.size;
        }
    }
    return nil;
}
+ (OveMusic*)loadOveMusic:(NSString*)file folder:(NSString *)folder 
{
    NSString *path=file;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDir = [documentPaths objectAtIndex:0];
        path = documentDir;
        if (folder) {
            path = [path stringByAppendingPathComponent:folder];
            NSFileManager *manager=[NSFileManager defaultManager];
            if (![manager fileExistsAtPath:path]) {
                [manager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
            }
        }
        path = [path stringByAppendingPathComponent:file];
    }
    
    NSData *vmus_data, *ove_data;
    if ([[[file pathExtension] lowercaseString] isEqualToString:@"vmus"]) {
        vmus_data=[NSData dataWithContentsOfFile:path];
    }else if ([[[file pathExtension] lowercaseString] isEqualToString:@"ove"]) {
        ove_data = [NSData dataWithContentsOfFile:path];
    }
    
    if (vmus_data==nil && ove_data==nil) {
        NSString *vmus_file=[path stringByAppendingPathExtension:@"vmus"]; //test if it is vmus under document folder
        vmus_data=[NSData dataWithContentsOfFile:vmus_file];
        if (vmus_data==nil) {
            NSString *ove_file=[path stringByAppendingPathExtension:@"ove"];//test if it is vmus under document folder
            ove_data=[NSData dataWithContentsOfFile:ove_file];
            if (ove_data==nil) {
                vmus_file=[[NSBundle mainBundle] pathForResource:file ofType:@"vmus"]; //test if it is vmus under resource folder
                vmus_data=[NSData dataWithContentsOfFile:vmus_file];
                if (vmus_data==nil){
                    ove_file=[[NSBundle mainBundle] pathForResource:file ofType:@"ove"]; //test if it is vmus under resource folder
                    ove_data=[NSData dataWithContentsOfFile:ove_file];
                }
            }
        }
    }
    OveMusic *music=nil;
    if (vmus_data) {
        music = [self loadFromVmusData:vmus_data];
    }else if (ove_data){
        music = [self loadFromOveData:ove_data];
    }else{
        NSLog(@"Can not read file:%@", file);
    }
    /*
    
    if (music==nil) {
        NSString *vmus_file=[[NSBundle mainBundle] pathForResource:file ofType:@"vmus"];
        NSData *data=[NSData dataWithContentsOfFile:vmus_file];
        if (data) {
            music = [self loadFromVmusData:data];
        }
    }
    if (music==nil) {
        music=[[OveMusic alloc]init];
        music.work_title=[file stringByDeletingPathExtension];
        NSString *ove_file=[[NSBundle mainBundle] pathForResource:file ofType:@"ove"];
        NSData *data=[NSData dataWithContentsOfFile:ove_file];
        if (data==nil)
        {
            data=[NSData dataWithContentsOfFile:path];
            if (data==nil) {
                NSLog(@"Can not read file:%@", file);
                return nil;
            }
        }
        if (![music loadOve:data]) {
            return nil;
        }
#if 0//
        NSMutableDictionary *finalDict = [music serializeObject:music];
        
        NSError *error=nil;
        NSData *json_data= [NSJSONSerialization dataWithJSONObject:finalDict options:NSJSONWritingPrettyPrinted error:&error];
        if (error) {
            NSLog(@"Error=%@", error);
        }
        [json_data writeToFile:ovsPathFile atomically:YES];
        //[finalDict writeToFile:plistFile atomically:YES];
#else
        //[music writeToOvsFile:plistFile];
        //NSData *writeData=[music dataOfVmusMusic];
        //if (writeData) {
            //save to file
            //[writeData writeToFile:plistFile atomically:YES];
        //}
#endif
    }
*/
    return music;
}
+ (OveMusic*)loadFromOveData:(NSData*)oveData
{
    OveMusic *music=[[OveMusic alloc]init];
    if (![music loadOve:oveData]) {
        music.g_oveData=nil;
        return nil;
    }
    music.g_oveData=nil;

    return music;

}
/*
- (BOOL)load:(NSString*)file folder:(NSString *)folder
{
    self.work_title=file;
    NSString *ove_file=[[NSBundle mainBundle] pathForResource:file ofType:@"ove"];
    NSData *data=[NSData dataWithContentsOfFile:ove_file];
    if (data==nil)
    {
        NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDir = [documentPaths objectAtIndex:0];
        NSString *path = documentDir;
        if (folder) {
            path = [path stringByAppendingPathComponent:folder];
        }
        path = [path stringByAppendingPathComponent:file];
        NSString *ext=[path pathExtension];
        if (ext.length!=3) {
            path = [path stringByAppendingPathExtension:@"ove"];
        }
        data=[NSData dataWithContentsOfFile:path];
        if (data==nil) {
            NSLog(@"Can not read file:%@", file);
            return NO;
        }
    }
    
    return [self loadOve:data];
    
}
*/
- (NSData*)dataOfVmusMusic
{
    return [self dataOfVmusMusic:0 end:0];//all
}


//total 4*8 bytes
typedef struct {
    UInt32 version;
    UInt32 width, height;
    UInt16 top_margin, bottom_margin, left_margin, right_margin;
    UInt32 measure_count;
    //added for version 0x0002
    //UInt32 reserved1;
    //UInt32 reserved2;
}MuskHeaderContent;

typedef struct {
    MuskBlock head; //8 bytes
    UInt32 version;
    UInt32 width, height;
    UInt16 top_margin, bottom_margin, left_margin, right_margin;
    UInt32 measure_count;
    //added for version 0x0002
    //UInt32 reserved1;
    //UInt32 reserved2;
}MuskHeader;

- (NSData*)dataOfVmusMusic:(int)beginLine end:(int)endLine
{
    NSArray *new_lines=self.lines;
    NSMutableArray *new_pages=self.pages;
    NSArray *new_measures = self.measures;
    if (beginLine!=0 || endLine!=0) {
#define LINES_PER_PAGE 6
        int staff_distance=300;
        int start_measure_index=[[self.lines objectAtIndex:beginLine] begin_bar];
        OveLine *lastLine=[self.lines objectAtIndex:endLine];
        int max_measures=lastLine.begin_bar + lastLine.bar_count-start_measure_index;
        
        //prepair lines
        NSRange line_range=NSMakeRange(beginLine, endLine-beginLine+1);
        new_lines=[NSArray arrayWithArray:[self.lines subarrayWithRange:line_range]];
        int y_offset=200;
        for (int i=0; i<new_lines.count; i++) {
            if (i%LINES_PER_PAGE==0) {
                y_offset=200;
            }
            OveLine *line=[new_lines objectAtIndex:i];
            line.begin_bar-=start_measure_index;
            line.y_offset=y_offset;y_offset+=600;
            for (int ss=0; ss<line.staves.count; ss++) {
                LineStaff *staff=[line.staves objectAtIndex:ss];
                staff.y_offset=ss*staff_distance;
            }
        }
        //pages
        new_pages=[[NSMutableArray alloc]initWithCapacity:new_lines.count/LINES_PER_PAGE+1];
        for (int i=0; i<new_lines.count/LINES_PER_PAGE+1; i++) {
            OvePage *page=[[OvePage alloc]init];
            [new_pages addObject:page];
            page.staff_distance=staff_distance;
            page.begin_line=i*LINES_PER_PAGE;
            if (i==new_lines.count/LINES_PER_PAGE) {
                page.line_count=new_lines.count%LINES_PER_PAGE;
            }else{
                page.line_count=LINES_PER_PAGE;
            }
        }
        //measures
        NSRange measure_range;
        measure_range.location=start_measure_index;
        measure_range.length=max_measures;
        new_measures=[NSArray arrayWithArray:[self.measures subarrayWithRange:measure_range]];
        for (int i=0; i<new_measures.count; i++) {
            OveMeasure *measure=[new_measures objectAtIndex:i];
            measure.number=i;
        }
    }
    
    //write to data
    NSMutableData *writeData=[[NSMutableData alloc]init];
    self.version=0x0001; //v1
    //header
    MuskHeader muskHeader={
        .head.tags = MUSK,// "MUSK",
        .head.size = sizeof(MuskHeader),
        .version = self.version,
        .width = self.page_width, .height = self.page_height,
        .top_margin = self.page_top_margin,  .bottom_margin = self.page_bottom_margin, .left_margin = self.page_left_margin, .right_margin=self.page_right_margin,
        .measure_count = self.max_measures
    };
    [writeData appendBytes:&muskHeader length:sizeof(muskHeader)];
    
    //titles
    const char *work_title=self.work_title.UTF8String;
    const char *composer=self.composer.UTF8String;
    const char *lyricist=self.lyricist.UTF8String;
    const char *work_number=self.work_number.UTF8String;
    
    NSMutableData *titleData=[[NSMutableData alloc]init];
#define WRITE_TITLE(title)  \
{   \
unsigned short len=(title!=NULL)?strlen(title):0;  \
[titleData appendBytes:&len length:2];  \
if (len>0) {    \
[titleData appendBytes:title length:len];  \
}\
}
    WRITE_TITLE(work_title);
    WRITE_TITLE(composer);
    WRITE_TITLE(lyricist);
    WRITE_TITLE(work_number);
    UInt32 len_title=(UInt32)(8+titleData.length);
    [writeData appendBytes:"TITL" length:4];
    [writeData appendBytes:&len_title length:4];
    [writeData appendData:titleData];
    
    //@property (nonatomic, retain) NSMutableArray *pages; //OvePage -> above lines.
    WRITE_ARRAY("PAGS", OvePage, new_pages);
    
    //@property (nonatomic, retain) NSMutableArray *lines;//OveLine
    WRITE_ARRAY("LINS", OveLine, new_lines);
    
    //@property (nonatomic, retain) NSMutableArray *trackes;//TRCK: OveTrack
    WRITE_ARRAY("TRKS", OveTrack, self.trackes);
    
    //@property (nonatomic, retain) NSMutableArray *measures;//OveMeasure
    WRITE_ARRAY("MEAS", OveMeasure, new_measures);
    
    return writeData;
}
+ (OveMusic*)loadFromVmusData:(NSData*)ovsData
{
    //NSRange range;
    int next_tag_pos=0;
    OveMusic *newmusic=[[OveMusic alloc]init];
    
    MuskBlock blockHead;
    while (next_tag_pos<ovsData.length-4) {
        MUSK_SET_POS(next_tag_pos);
        MUSK_READ_BUF(&blockHead, sizeof(blockHead));
        switch (blockHead.tags) {
            case MUSK:
            {
                MuskHeaderContent muskHeader;
                MUSK_READ_BUF(&muskHeader, sizeof(MuskHeaderContent));
                newmusic.version=muskHeader.version;
                newmusic.page_width=muskHeader.width;
                newmusic.page_height=muskHeader.height;
                newmusic.page_top_margin=muskHeader.top_margin;
                newmusic.page_bottom_margin=muskHeader.bottom_margin;
                newmusic.page_left_margin=muskHeader.left_margin;
                newmusic.page_right_margin=muskHeader.right_margin;
                newmusic.max_measures=muskHeader.measure_count;
                break;
            }
            case TITL:
            {
#define GET_TITLE(title_name)\
{   \
unsigned short len; \
MUSK_READ_BUF(&len, 2); \
if (len>0)  \
{   \
char *text=malloc(len+1); text[len]=0;  \
MUSK_READ_BUF(text, len);   \
title_name = [NSString stringWithUTF8String:text];    \
free(text); \
}   \
}
                GET_TITLE(newmusic.work_title);
                GET_TITLE(newmusic.composer);
                GET_TITLE(newmusic.lyricist);
                GET_TITLE(newmusic.work_number);
                break;
            }
            case PAGS:
                READ_ARRS_1(OvePage, newmusic.pages);
                break;
            case LINS:
                READ_ARRS_1(OveLine, newmusic.lines);
                break;
            case TRKS:
                READ_ARRS_1(OveTrack, newmusic.trackes);
                break;
            case MEAS:
                //READ_ARRS_1(OveMeasure, newmusic.measures);
            {   
                short count;
                MUSK_READ_BUF(&count, 2);   
                if (count>0) {  
                    newmusic.measures=[[NSMutableArray alloc]initWithCapacity:count];    
                    for (int i=0; i<count; i++) {   
                        OveMeasure *item=[OveMeasure loadFromOvsData:ovsData]; 
                        if(item)[newmusic.measures addObject:item]; 
                        else{
                            newmusic=nil;
                            return nil;
                        }
                    } 
                } 
            }
                break;
            default:
                NSLog(@"unknown tag: 0x%x, %s", (unsigned int)blockHead.tags, (char*)&blockHead.tags);
                break;
        }
        next_tag_pos+=blockHead.size;
    }
    
    //向前兼容，某些早期vmus曲库的line.begin_bar只有一个字节
    if (newmusic.measures.count<256) {
        for (int ll=0; ll<newmusic.lines.count; ll++) {
            OveLine *line=[newmusic.lines objectAtIndex:ll];
            line.begin_bar&=0x00FF;
        }
    }
    
    if (![newmusic supportChangeKey])
    {
        char last_clef[60];
        int octave_shift_size[60];
        memset(octave_shift_size, 0, sizeof(octave_shift_size));
        for (int ll=0; ll<newmusic.lines.count; ll++) {
            OveLine *line=[newmusic.lines objectAtIndex:ll];
            for (int ss=0; ss<line.staves.count; ss++) {
                LineStaff *line_staff=[line.staves objectAtIndex:ss];
                last_clef[ss]=line_staff.clef;
            }
            for (int mm=line.begin_bar; mm<line.begin_bar+line.bar_count && mm<newmusic.measures.count; mm++) {
                OveMeasure *measure=[newmusic.measures objectAtIndex:mm];
                
                for (int nn=0; nn<measure.notes.count; nn++) {
                    OveNote *note=[measure.notes objectAtIndex:nn];
                    if (note.staff==0 || note.staff>line.staves.count || note.note_elems.count==0) {
                        continue;
                    }
                    NoteElem *elem0=[note.note_elems objectAtIndex:0];
                    int staff=note.staff+elem0.offsetStaff;
                    
                    if (measure.clefs) {
                        for (MeasureClef *clef in measure.clefs) {
                            if (staff==clef.staff && clef.pos.start_offset<note.pos.start_offset) {
                                last_clef[staff-1]=clef.clef;
                            }
                        }
                    }
                    if (measure.octaves.count>0) {
                        for (OctaveShift *shift in measure.octaves) {
                            if (shift.staff==staff) {
                                if (shift.octaveShiftType == OctaveShift_8_Start) {
                                    if (shift.pos.start_offset<note.pos.start_offset) {
                                        octave_shift_size[staff-1]=7;
                                    }
                                }else if (shift.octaveShiftType == OctaveShift_8_Stop) {
                                    if ((shift.length>0 && shift.length<note.pos.start_offset) ||
                                        (shift.length==0 && shift.pos.start_offset<note.pos.start_offset)) {
                                        octave_shift_size[staff-1]=0;
                                    }
                                }else if (shift.octaveShiftType == OctaveShift_15_Start) {
                                    if (shift.pos.start_offset<note.pos.start_offset) {
                                        octave_shift_size[staff-1]=15;
                                    }
                                }else if (shift.octaveShiftType == OctaveShift_15_Stop) {
                                    if ((shift.length>0 && shift.length<note.pos.start_offset) ||
                                        (shift.length==0 && shift.pos.start_offset<note.pos.start_offset)) {
                                        octave_shift_size[staff-1]=0;
                                    }
                                }else if(shift.octaveShiftType==OctaveShift_8_StartStop || shift.octaveShiftType==OctaveShift_Minus_8_StartStop){
                                    //to do
                                }
                            }
                        }
                    }
                    //LineStaff *staff=[line.staves objectAtIndex:staff-1];
                    for (int ee=0; ee<note.note_elems.count; ee++) {
                        NoteElem *elem=[note.note_elems objectAtIndex:ee];
                        int elem_line=elem.line+octave_shift_size[staff-1];
                        
                        if (last_clef[staff-1]==Clef_Treble) {
                            //line: -6 C, -5 D, -4 E, -3 F, -2 G, -1 A, 0 B, 1 C, 2 D
                            elem.xml_pitch_step=abs(34+elem_line)%7+1;
                            elem.xml_pitch_octave=(elem_line-(elem.xml_pitch_step-7))/7+4;
                        }else{ //Clef_Bass
                            //-8, C,-7 D, -6 E, -5 F, -4 G, -3 A, -2 B -1 C, 0 D, 1 E, 2 F,
                            elem.xml_pitch_step=abs(36+elem_line)%7+1;
                            elem.xml_pitch_octave=(elem_line-5-(elem.xml_pitch_step-7))/7+3;
                        }
                        int note_val=[newmusic noteFromPitchStep:elem.xml_pitch_step pitchOctave:elem.xml_pitch_octave pitchAlter:0];
                        elem.xml_pitch_alter=elem.note-note_val;
                        if (elem.xml_pitch_alter>2 || elem.xml_pitch_alter<-2) {
                            NSLog(@"alter too big at measure(%d) line=%d note(%d)=(%d,%d)", mm+1, elem.line,nn, elem.note, note_val);
                            if (elem.xml_pitch_alter<=-22) { //高16度
                                NSLog(@"Error alter");
                            }else if (elem.xml_pitch_alter<=-11 && elem.xml_pitch_alter>=-13) { //高8度
                                elem.note+=12;
                                elem.xml_pitch_alter=elem.note-note_val;
                                NSLog(@"new note=(%d,%d)",elem.note, note_val);
                                if (elem.xml_pitch_alter>2 || elem.xml_pitch_alter<-2) {
                                    NSLog(@"again alter too big note=(%d,%d)",elem.note, note_val);
                                }
                            }else{
                                NSLog(@"Error alter");
                            }
                        }
                    }
                }
                //for next measure
                if (measure.clefs) {
                    for (MeasureClef *clef in measure.clefs) {
                        last_clef[clef.staff-1]=clef.clef;
                    }
                }
                if (measure.octaves.count>0) {
                    for (OctaveShift *shift in measure.octaves) {
                        if (shift.octaveShiftType == OctaveShift_8_Stop) {
                            octave_shift_size[shift.staff-1]=0;
                        }else if (shift.octaveShiftType == OctaveShift_15_Stop) {
                            octave_shift_size[shift.staff-1]=0;
                        }
                    }
                }
                //end
            }
        }
    }
    
    return newmusic;
}
/*
 
 fifths
 0
 C major || 1   |     |  2  |     |  3  |  4  |     |  5  |     |  6  |     |  7
 C D E F G A B
 a minor || 3   |     |  4  |     |  5  |  6  |     |     |  7  |  1  |     |  2
 A B C D E F #G
 1: G major: #G A B C D E F
 e minor
 E F #G A B C #D
 */
/*
 全 全 半 全 全 全 半
 1，2，3，4，5，6，7，1
 C，D，E，F，G，A，B，C
 
 转调规则：
 1.  降X调->X调->升X调，把所有音提高半度.反方向就降半度
 所以简化调式，就把向fifths小的方向变化:
 if (fifths>3 || fifths<-3)
 {
 new_fifths = 7-abs(fifths);
 if (fifths<0) new_fifths*=-1;
 }
 
 E.g.
 降X大调->X大调 或者 X大调->升X大调，把所有音提高半度
 降x小调->x小调 或者 x小调->升x小调，把所有音提高半度
 
 -6 Gb major --> 1 G major 所有音升高半度
 Gb major: bG bA bB bC bD bE F
 G major: G A B C D E #F
 
 eb minor: bE F bG bA bB bC D
 e minor: E #F G A B C #D
 
 
 -2 Bb major -> 5 B major
 Bb major: bB C D eE F G A
 B major: B #C #D E #F #G #A
 
 0 C major -> 7 #C major
 C major: C D E F G A B
 C# major: #C #D #E #F #G #A #B
 
 -1 F major -> 6 F# major
 F major: F G A bB C D E
 F# major: #F #G #A B #C #D #E
 
 其他
 加两个降号的，变一个降号
 加降号的，变还原。
 加还原的，变升号。
 加升号的，变两个升号
 
 2. ，
 
 fifths
 case 0
 C major: C D E F G A B
 a minor: A B C D E F G
 case 1
 G major: G A B C D E #F
 e minor: E #F G A B C D
 case 2
 D major: D E #F G A B #C
 b minor: B #C D E #F G A
 case 3://
 A major: A B #C D E #F #G
 f# minor:#F #G A B #C D E 
 case 4://
 E major: E #F #G A B #C #D
 c# minor
 case 5://
 B major: B #C #D E #F #G #A
 g# minor:#G #A B #C #D E #F 
 case 6://
 F# major: #F #G #A B #C #D #E
 d# minor: #D #E #F #G #A B #C
 case 7:
 C# major: #C #D #E #F #G #A #B
 a# minor:
 
 case -1://
 F major: F G A bB C D E
 d minor: D E F G A bB C
 case -2://
 Bb major: bB C D bE F G A
 g minor:  G A bB C D bE F
 case -3://
 Eb major: bE F G bA bB C D
 c minor
 case -4://
 Ab major: bA bB C bD bE F G
 f minor:  F G bA bB C bD bE
 case -5://
 Db major: bD bE F bG bA bB C
 bb minor: bB C bD bE F bG bA
 case -6://
 Gb major: bG bA bB bC bD bE F
 eb minor: bE F bG bA bB bC bD
 
 case -7://
 Cb major: bC bD bE bF bG bA bB
 ab minor
 
 
 下表列出的是与音符相对应的命令标记。
 八度音阶||                    音符号
 #  ||
    ||  C  | bD  |  D  | bE  |  bF |  F  | bG  |  G  | bA  |  A  | bB  | bC
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
/*
 1. 非同名移调: 音名会改变，简谱不变。
 keyIndex=-11...+11
 */
- (BOOL)changeToKeyWithSameJianpu:(int)new_fifths increase:(BOOL)increase
{
    if (new_fifths<-7 || new_fifths>7) {
        return NO;
    }
    char fifthsAlters[15][7]={
        {-1,-1,-1,-1,-1,-1,-1}, //Cb major: bC bD bE bF bG bA bB -7
        {-1,-1,-1,-1,-1,-1, 0}, //Gb major: bG bA bB bC bD bE  F -6
        {-1,-1, 0,-1,-1,-1, 0}, //Db major: bD bE  F bG bA bB  C -5
        {-1,-1, 0,-1,-1, 0, 0}, //Ab major: bA bB  C bD bE  F  G -4
        {-1, 0, 0,-1,-1, 0, 0}, //Eb major: bE  F  G bA bB  C  D -3
        {-1, 0, 0,-1, 0, 0, 0}, //Bb major: bB  C  D bE  F  G  A -2
        { 0, 0, 0,-1, 0, 0, 0}, //F major:   F  G  A bB  C  D  E -1

        { 0, 0, 0, 0, 0, 0, 0}, //C major:   C  D  E  F  G  A  B  0

        { 0, 0, 0, 0, 0, 0, 1}, //G major:   G  A  B  C  D  E #F  1
        { 0, 0, 1, 0, 0, 0, 1}, //D major:   D  E #F  G  A  B #C  2
        { 0, 0, 1, 0, 0, 1, 1}, //A major:   A  B #C  D  E #F #G  3
        { 0, 1, 1, 0, 0, 1, 1}, //E major:   E #F #G  A  B #C #D  4
        { 0, 1, 1, 0, 1, 1, 1}, //B major:   B #C #D  E #F #G #A  5
        { 1, 1, 1, 0, 1, 1, 1}, //F# major: #F #G #A  B #C #D #E  6
        { 1, 1, 1, 1, 1, 1, 1}  //C# major: #C #D #E #F #G #A #B  7
    };
    /*
     0:
     C major:   C  D  E  F  G  A  B  0
     1:
     Db major: bD bE  F bG bA bB  C -5
     C# major: #C #D #E #F #G #A #B  7
     2:
     D major:   D  E #F  G  A  B #C  2
     3:
     Eb major: bE  F  G bA bB  C  D -3
     4:
     E major:   E #F #G  A  B #C #D  4
     5:
     F major:   F  G  A bB  C  D  E -1
     6:
     F# major: #F #G #A  B #C #D #E  6
     Gb major: bG bA bB bC bD bE  F -6
     7:
     G major:   G  A  B  C  D  E #F  1
     8:
     Ab major: bA bB  C bD bE  F  G -4
     9:
     A major:   A  B #C  D  E #F #G  3
     10:
     Bb major: bB  C  D bE  F  G  A -2
     11:
     B major:   B #C #D  E #F #G #A  5
     Cb major: bC bD bE bF bG bA bB -7
     */
    int notePosForFifths[15]={
        11,6,1,8,3,10,5,
        0,
        7,2,9,4,11,6,1
    };

    /*
     0:
     Cb major: bC bD bE bF bG bA bB -7
     C major:   C  D  E  F  G  A  B  0
     C# major: #C #D #E #F #G #A #B  7
     1:
     Db major: bD bE  F bG bA bB  C -5
     D major:   D  E #F  G  A  B #C  2
     2:
     Eb major: bE  F  G bA bB  C  D -3
     E major:   E #F #G  A  B #C #D  4
     3:
     F major:   F  G  A bB  C  D  E -1
     F# major: #F #G #A  B #C #D #E  6
     4:
     Gb major: bG bA bB bC bD bE  F -6
     G major:   G  A  B  C  D  E #F  1
     5:
     Ab major: bA bB  C bD bE  F  G -4
     A major:   A  B #C  D  E #F #G  3
     6:
     Bb major: bB  C  D bE  F  G  A -2
     B major:   B #C #D  E #F #G #A  5
     */
    int linePosForFifths[15]={
        0,4,1,5,2,6,3,
        0,
        4,1,5,2,6,3,0
    };
    BOOL changed=NO;
    int noteOffset=0, lineOffset=0;
    for (OveLine *line in self.lines) {
        if (/*new_fifths==line.fifths || */line.fifths>7 || line.fifths<-7) {
            continue;
        }
        if (increase>0) {
            if (new_fifths!=line.fifths) {
                noteOffset=(12+notePosForFifths[new_fifths+7]-notePosForFifths[line.fifths+7])%12;
                lineOffset=(7+linePosForFifths[new_fifths+7]-linePosForFifths[line.fifths+7])%7;
            }else{
                noteOffset=12;
                lineOffset=6;
            }
        }else{
            if (new_fifths!=line.fifths) {
                noteOffset=-(12+notePosForFifths[line.fifths+7]-notePosForFifths[new_fifths+7])%12;
                lineOffset=-(7+linePosForFifths[line.fifths+7]-linePosForFifths[new_fifths+7])%7;
            }else{
                noteOffset=-12;
                lineOffset=-6;
            }
        }
        changed=YES;
        
        for (int mm=line.begin_bar; mm<line.begin_bar+line.bar_count; mm++) {
            OveMeasure *measure=[self.measures objectAtIndex:mm];
            //change beam
            for (int bb=0; bb<measure.beams.count; bb++) {
                OveBeam *beam=[measure.beams objectAtIndex:bb];
                beam.left_line+=lineOffset;
                beam.right_line+=lineOffset;
            }
            //change slur
            for (MeasureSlur *slur in measure.slurs) {
                slur.pair_ends.left_line+=lineOffset;
                slur.pair_ends.right_line+=lineOffset;
            }
            //change tie
            for (MeasureTie *tie in measure.ties) {
                tie.pair_ends.left_line+=lineOffset;
                tie.pair_ends.right_line+=lineOffset;
            }
            //change note
            memset(measure_accidental, 0, sizeof(measure_accidental));//每一小节的每个音只要标记一次
            for (int nn=0; nn<measure.notes.count; nn++) {
                OveNote *note=[measure.notes objectAtIndex:nn];
                if (nn>0) {
                    OveNote *prev_note=[measure.notes objectAtIndex:nn-1];
                    if (note.staff>prev_note.staff) {//换staff后重新标记
                        memset(measure_accidental, 0, sizeof(measure_accidental));
                    }
                }
                for (int ee=0; ee<note.note_elems.count; ee++) {
                    NoteElem *elem=[note.note_elems objectAtIndex:ee];
                    /*
                    //  C  | bD  |  D  | bE  |  bF |  F  | bG  |  G  | bA  |  A  | bB  | bC
                    //  C  | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
                    //  1           2           3     4           5           6          7
                    1. G major: C D E #F G A B, ->C major: note-7
                    step(oct,alter): 1:4(-1,0), 2:5(-1,0), 3:6(-1,0), 4:7(-1,-1), 5:1(0,0), 6:2(0,0), 7:3(0,0)
                     */
                    /*fifth=7
                     1. C# major: #C #D #E #F #G #A #B, ->C major: note-1
                     step(oct,alter): 1:7(-1,0), 2:1(0,+1), 3:2(0,+1), 4:3(0,0), 5:4(0,+1), 6:5(0,+1), 7:6(0,+1),
                     fifth=-5
                     Db major: bD bE F bG bA bB C ->C major: note-1
                     */
                    /*fifth=2
                     2. D major: D E #F G A B #C, ->C major: note-2
                     step(oct,alter): 1:7(-1,-1), 2:1(0,0), 3:2(0,0), 4:3(0,-1), 5:4(0,0), 6:5(0,0), 7:6(0,0),
                     */
                    /*fifth=-3
                     3. Eb major: bE F G bA bB C D, ->C major: note-3
                     step(oct,alter): 1:6(-1,0), 2:7(-1,0), 3:1(0,+1), 4:2(0,0), 5:3(0,0), 6:4(0,+1), 7:5(0,+1),
                     */
                    /*fifth=4
                     4. E major: E #F #G A B #C #D, ->C major: note-4
                     step(oct,alter): 1:6(-1,-1), 2:7(-1,-1), 3:1(0,0), 4:2(0,-1), 5:3(0,-1), 6:4(0,0), 7:5(0,0),
                     */
                    /*fifth=-1
                     5. F major: F G A bB C D E, ->C major: note-5
                     step(oct,alter): 1:5(-1,0), 2:6(-1,0), 3:7(-1,0), 4:1(0,0), 5:2(0,0), 6:3(0,0), 7:4(0,+1),
                     */
                    /*
                     fifth=6
                     6. F# major: #F #G #A B #C #D #E, ->C major: note-6
                     fifth=1
                     7. G major: G A B C D E #F , ->C major: note-7
                                 C D E F G A B
                     fifth=-4
                     8. Ab major: bA bB C bD bE F G, ->C major: note-8
                     fifth=3
                     9. A major: A B #C D E #F #G, ->C major: note-9
                     fifth=-2
                     10. Bb major: bB C D bE F G A, ->C major: note-10
                                    C D E F  G A B
                     fifth=5
                     11. B major: B #C #D E #F #G #A, ->C major: note-11
                    */
                    int new_pitch_step=elem.xml_pitch_step;
                    int new_pitch_octave=elem.xml_pitch_octave;
                    int new_pitch_alter=elem.xml_pitch_alter;
                    if (new_fifths==line.fifths) {
                        if (increase) {
                            new_pitch_octave+=1;
                        }else{
                            new_pitch_octave-=1;
                        }
                    }else{
                        //  C  | bD  |  D  | bE  |  bF |  F  | bG  |  G  | bA  |  A  | bB  | bC
                        //  C  | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
                        //  1           2           3     4           5           6          7
                        /*
                         C major:   C  D  E  F  G  A  B
                         C# major: #C #D #E #F #G #A #B
                         Db major: bD bE  F bG bA bB  C
                         D major:   D  E #F  G  A  B #C
                         Eb major: bE  F  G bA bB  C  D
                         E major:   E #F #G  A  B #C #D
                         F major:   F  G  A bB  C  D  E
                         F# major: #F #G #A  B #C #D #E
                         Gb major: bG bA bB bC bD bE  F
                         G major:   G  A  B  C  D  E #F
                         Ab major: bA bB  C bD bE  F  G
                         A major:   A  B #C  D  E #F #G
                         Bb major: bB  C  D bE  F  G  A
                         B major:   B #C #D  E #F #G #A
                         Cb major: bC bD bE bF bG bA bB
                         */
                        if (increase) {
                            if (elem.xml_pitch_step+lineOffset>7) {
                                new_pitch_octave+=1;
                                new_pitch_step=(elem.xml_pitch_step+lineOffset)%7;
                            }else{
                                new_pitch_step=elem.xml_pitch_step+lineOffset;
                            }
                        }else{
                            if (elem.xml_pitch_step+lineOffset>0) {
                                new_pitch_step=elem.xml_pitch_step+lineOffset;
                            }else {
                                new_pitch_octave-=1;
                                new_pitch_step=elem.xml_pitch_step+(7+lineOffset);
                            }
                        }
                        int jianpu_steps[]={
                            0,-4,-1,-5,-2,1,-3,
                            0,
                            -4,-1,-5,-2,1,-3,0};
                        int jiappu_step_index=(elem.xml_pitch_step+6+jianpu_steps[line.fifths+7]);
                        int step=jiappu_step_index%7;//0-6
                        char old_fifths_alter=fifthsAlters[line.fifths+7][step];
                        char new_fifths_alter=fifthsAlters[new_fifths+7][step];//简谱不变
                        if (old_fifths_alter!=new_fifths_alter) {
                            new_pitch_alter+=new_fifths_alter-old_fifths_alter;
                            elem.accidental_type=Accidental_Normal;
                            if (new_pitch_alter==0 && new_fifths_alter!=0) {
                                elem.accidental_type=Accidental_Natural;
                            }else if (new_pitch_alter==-1 && new_fifths_alter!=-1) {
                                elem.accidental_type=Accidental_Flat;
                            }else if (new_pitch_alter==-2) {
                                elem.accidental_type=Accidental_DoubleFlat;
                            }else if (new_pitch_alter==1 && new_fifths_alter!=1) {
                                elem.accidental_type=Accidental_Sharp;
                            }else if (new_pitch_alter==2) {
                                elem.accidental_type=Accidental_DoubleSharp;
                            }
                        }
                    }
                    
                    //
                    elem.xml_pitch_octave=new_pitch_octave;
                    elem.xml_pitch_step=new_pitch_step;
                    elem.xml_pitch_alter=new_pitch_alter;
                    
                    elem.note+=noteOffset;//note_index;
                    note.line+=lineOffset;
                    elem.line+=lineOffset;
                    //[self calNotePitch:elem];
                }
            }
        }
        line.fifths=new_fifths;
    }
    return changed;
}
- (void)calNotePitch:(NoteElem*)elem
{
    /*
     ||  1  |     |  2  |     |  3  |  4  |     |  5  |     |  6  |     | 7
     ||  C  | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
     -----------------------------------------------------------------------------
     0  ||   0 |   1 |   2 |   3 |   4 |   5 |   6 |   7 |   8 |   9 |  10 | 11
     */
    elem.xml_pitch_octave=elem.note/12-1;
    int steps[12]={1,1,2,2,3,4,4,5,5,6,6,7};
    int index=elem.note%12;
    elem.xml_pitch_step=steps[index];
    if (elem.accidental_type==Accidental_Flat) {
        elem.xml_pitch_alter=-1;
        if (index==1 || index==3 || index==4 || index==6 || index==8 || index==10) {
            elem.xml_pitch_step+=1;
        }else if (index==11)
        {
            elem.xml_pitch_octave+=1;
            elem.xml_pitch_step=1;
        }
    }else if (elem.accidental_type==Accidental_DoubleFlat) {
        elem.xml_pitch_alter=-2;
        if (index==0 || index==2 || index==5 || index==7 || index==9) {
            elem.xml_pitch_step+=1;
        }
    }else if (elem.accidental_type==Accidental_Sharp) {
        elem.xml_pitch_alter=1;
        if (index==5) {
            elem.xml_pitch_step-=1;
        }else if (index==0)
        {
            elem.xml_pitch_octave-=1;
            elem.xml_pitch_step=7;
        }
    }else if (elem.accidental_type==Accidental_DoubleSharp) {
        elem.xml_pitch_alter=2;
        if (index==2 || index==4 || index==7 || index==9 || index==11) {
            elem.xml_pitch_step-=1;
        }
    }else{
        elem.xml_pitch_alter=0;
    }
}
/*
 升号的顺序：F - C - G - D - A - E - B
 降号的顺序：B - E - A - D - G - C - F
 //0  C major: C D E F G A B
 //1  G major: G A B C D E #F
 //2  D major: D E #F G A B #C
 //3  A major: A B #C D E #F #G
 //4  E major: E #F #G A B #C #D
 //5  B major: B #C #D E #F #G #A
 //6 F# major: #F #G #A B #C #D #E
 //7 C# major: #C #D #E #F #G #A #B
 //-7 Cb major: bC bD bE bF bG bA bB
 //-6 Gb major: bG bA bB bC bD bE F
 //-5 Db major: bD bE F bG bA bB C
 //-4 Ab major: bA bB C bD bE F G
 //-3 Eb major: bE F G bA bB C D
 //-2 Bb major: bB C D bE F G A
 //-1  F major: F G A bB C D E
 
 e.g.
 升号的顺序：F - C - G - D - A - E - B
 唱名-Fa - Do - Sol - Re - La - Mi - Si 4,1,5,2,6,3,7
 降号的顺序：B - E - A - D - G - C - F
 唱名-Si - Mi - La - Re - Sol - Do - Fa 
 fifths->	0: C D E F G A B
 //0  C major/a minor: C D E F G A B        N/A
 //1  G major/e minor: C D E #F G A B       F-
 //2  D major/b minor: #C D E #F G A B      FC-
 //3  A major/f# minor: #C D E #F #G A B 	FCG-
 //4  E major/c# minor: #C #D E #F #G A B 	FCGD-
 //5  B major/g# minor: #C #D E #F #G #A B 	FCGDA-
 //6 F# major/d# minor: #C #D #E #F #G #A B 	FCGDAE-
 //7 C# major/a# minor: #C #D #E #F #G #A #B	FCGDAEB-
 //-7 Cb major/ab minor: bC bD bE bF bG bA bB	BEADGCF+
 //-6 Gb major/eb minor: bC bD bE F bG bA bB 	BEADGC+
 //-5 Db major/bb minor: C bD bE F bG bA bB	BEADG+
 //-4 Ab major/f minor: C bD bE F Gb A bB	BEAD+
 //-3 Eb major/c minor: C D bE F G bA bB	BEA+
 //-2 Bb major/g minor: C D bE F G A bB 	BE+
 //-1  F major/d minor: C D E F G A bB      B+
*/
- (int)alterFromFifthsTo0:(int)fifths step:(int)pitch_step
{
    int alter=0;
    if (fifths>0) {
        int alters[8]={0,4,1,5,2,6,3,7};
        for (int i=1; i<8 && i<=fifths; i++) {
            if (pitch_step==alters[i]) {
                alter=-1;
                break;
            }
        }
    }else{
        int alters[8]={0,7,3,6,2,5,1,4};
        for (int i=1; i<8 && i<=-fifths; i++) {
            if (pitch_step==alters[i]) {
                alter=1;
                break;
            }
        }
    }
    return  alter;
}
/*
 0: C D E F G A B
 ->
 //0  C major: C D E F G A B        N/A
 //1  G major: C D E #F G A B       F+
 //2  D major: #C D E #F G A B      FC+
 //3  A major: #C D E #F #G A B 	FCG+
 //4  E major: #C #D E #F #G A B 	FCGD+
 //5  B major: #C #D E #F #G #A B 	FCGDA+
 //6 F# major: #C #D #E #F #G #A B 	FCGDAE+
 //7 C# major: #C #D #E #F #G #A #B	FCGDAEB+
 //-7 Cb major: bC bD bE bF bG bA bB	BEADGCF-
 //-6 Gb major: bC bD bE F bG bA bB 	BEADGC-
 //-5 Db major: C bD bE F bG bA bB	BEADG-
 //-4 Ab major: C bD bE F Gb A bB	BEAD-
 //-3 Eb major: C D bE F G bA bB	BEA-
 //-2 Bb major: C D bE F G A bB 	BE-
 //-1  F major: C D E F G A bB      B-
 */
- (int)alterFrom0ToFifths:(int)fifths step:(int)pitch_step
{
    int alter=0;
    if (fifths>0) {
        int alters[8]={0,4,1,5,2,6,3,7};
        for (int i=1; i<8 && i<=fifths; i++) {
            if (pitch_step==alters[i]) {
                alter=1;
                break;
            }
        }
    }else{
        int alters[8]={0,7,3,6,2,5,1,4};
        for (int i=1; i<8 && i<=-fifths; i++) {
            if (pitch_step==alters[i]) {
                alter=-1;
                break;
            }
        }
    }
    return  alter;
}
static signed char measure_accidental[70]; //note_index=pitch_octave*7+pitch_step  0~70
- (BOOL)changeToKey:(int) new_fifths
{
    BOOL changed=NO;
    int last_origin_fifths=0;
    for (OveLine *line in self.lines) {
        if (new_fifths == line.fifths) {
            continue;
        }
        changed=YES;
        last_origin_fifths=line.fifths;
        
        for (int mm=line.begin_bar; mm<line.begin_bar+line.bar_count; mm++) {
            OveMeasure *measure=[self.measures objectAtIndex:mm];
            memset(measure_accidental, 0, sizeof(measure_accidental));//每一小节的每个音只要标记一次
            for (int nn=0; nn<measure.notes.count; nn++) {
                OveNote *note=[measure.notes objectAtIndex:nn];
                if (nn>0) {
                    OveNote *prev_note=[measure.notes objectAtIndex:nn-1];
                    if (note.staff>prev_note.staff) {//换staff后重新标记
                        memset(measure_accidental, 0, sizeof(measure_accidental));
                    }
                }
                for (int ee=0; ee<note.note_elems.count; ee++) {
                    NoteElem *elem=[note.note_elems objectAtIndex:ee];
                    int pitch_octave=elem.xml_pitch_octave;
                    int pitch_step=elem.xml_pitch_step;
                    int pitch_alter=elem.xml_pitch_alter;
                    int note_index=pitch_octave*7+pitch_step;
                    
                    pitch_alter+=[self alterFromFifthsTo0:last_origin_fifths step:pitch_step];
                    if (new_fifths!=0) {
                        pitch_alter+=[self alterFrom0ToFifths:new_fifths step:pitch_step];
                    }
                    
                    elem.note=[self noteFromPitchStep:pitch_step pitchOctave:pitch_octave pitchAlter:pitch_alter];
                    AccidentalType new_accidental=Accidental_Normal;
                    if ((new_fifths==1 && pitch_step==4) || //G major: G A B C D E #F
                        (new_fifths==2 && (pitch_step==1||pitch_step==4)) ||   //D major: D E #F G A B #C
                        (new_fifths==3 && (pitch_step==1||pitch_step==4||pitch_step==5)) ||   //A major: A B #C D E #F #G
                        (new_fifths==4 && (pitch_step!=3&&pitch_step!=6&&pitch_step!=7)) ||   //E major: E #F #G A B #C #D
                        (new_fifths==5 && (pitch_step!=3&&pitch_step!=7)) ||   //B major: B #C #D E #F #G #A
                        (new_fifths==6 && (pitch_step!=7)) ||   //F# major: #F #G #A B #C #D #E
                        (new_fifths==7)    //C# major: #C #D #E #F #G #A #B
                        )
                    {
                        if (pitch_alter==0) {
                            new_accidental=Accidental_Natural;
                        }else if (pitch_alter==2) {
                            new_accidental=Accidental_DoubleSharp;
                        }else if (pitch_alter==-1) {
                            new_accidental=Accidental_Flat;
                        }else if (pitch_step==-2) {
                            new_accidental=Accidental_DoubleFlat;
                        }
                    }else if ((new_fifths==-7) || //Cb major: bC bD bE bF bG bA bB
                              (new_fifths==-6 && pitch_step!=4) || //Gb major: bG bA bB bC bD bE F
                              (new_fifths==-5 && pitch_step!=4 && pitch_step!=1) ||     //Db major: bD bE F bG bA bB C
                              (new_fifths==-4 && pitch_step!=4 && pitch_step!=1 && pitch_step!=5) ||    //Ab major: bA bB C bD bE F G
                              (new_fifths==-3 && (pitch_step==3 || pitch_step==6 || pitch_step==7)) ||    //Eb major: bE F G bA bB C D
                              (new_fifths==-2 && (pitch_step==3 || pitch_step==7)) ||    //Bb major: bB C D eE F G A
                              (new_fifths==-1 && (pitch_step==7))     //F major: F G A bB C D E
                              )
                    {
                        if (pitch_alter==0) {
                            new_accidental=Accidental_Natural;
                        }else if (pitch_alter==1) {
                            new_accidental=Accidental_Sharp;
                        }else if (pitch_alter==2) {
                            new_accidental=Accidental_DoubleSharp;
                        }else if (pitch_alter==-2) {
                            new_accidental=Accidental_DoubleFlat;
                        }
                    }else{ //others
                        if (pitch_alter==0) {
                            if (measure_accidental[note_index]!=Accidental_Normal) {
                                new_accidental=Accidental_Natural;
                            }
                        }else if (pitch_alter==1) {
                            new_accidental=Accidental_Sharp;
                        }else if (pitch_alter==2) {
                            new_accidental=Accidental_DoubleSharp;
                        }else if (pitch_alter==-1) {
                            new_accidental=Accidental_Flat;
                        }else if (pitch_step==-2) {
                            new_accidental=Accidental_DoubleFlat;
                        }
                    }
                    
                    if (measure_accidental[note_index]!=new_accidental) {
                        elem.accidental_type=new_accidental;
                        measure_accidental[note_index]=new_accidental;
                    }else{
                        elem.accidental_type=Accidental_Normal;
                    }
                    
                    elem.xml_pitch_alter=pitch_alter;
                }
            }
        }
        line.fifths=new_fifths;
    }
    return changed;
}
-(int)currentFifths
{
    OveLine *line=[self.lines objectAtIndex:0];
    return line.fifths;
}
- (BOOL)supportChangeKey
{
    for (int mm=0; mm<self.measures.count && mm<4; mm++) {
        OveMeasure *measure=[self.measures objectAtIndex:mm];
        for (int nn=0; nn<measure.notes.count; nn++) {
            OveNote *note=[measure.notes objectAtIndex:nn];
            for (int ee=0; ee<note.note_elems.count; ee++) {
                NoteElem *elem=[note.note_elems objectAtIndex:ee];
                if (elem.xml_pitch_step>0 || elem.xml_pitch_octave>0) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (void)changeKey
{
    OveLine *line=[self.lines objectAtIndex:0];
    int new_fifths=0;
    new_fifths = 7-abs(line.fifths);
    if (line.fifths>0)
    {
        new_fifths*=-1;
    }
    
    [self changeToKey:new_fifths];
    
}

- (int)noteFromPitchStep:(int)pitch_step pitchOctave:(int)pitch_octave pitchAlter:(int)pitch_alter
{
    //pitch_octave: 0-10
    //pitch_step: 1-7: CDEFGAB
    //pitch_alter: -1: flat, 0: normal, 1:sharp
    int note=(1+pitch_octave)*12+pitch_alter;
    if (pitch_step==2) { //D
        note+=2;
    }else if (pitch_step==3) { //E
        note+=4;
    }else if (pitch_step==4) { //F
        note+=5;
    }else if (pitch_step==5) { //G
        note+=7;
    }else if (pitch_step==6) { //A
        note+=9;
    }else if (pitch_step==7) { //B
        note+=11;
    }
    return note;
}

@end

