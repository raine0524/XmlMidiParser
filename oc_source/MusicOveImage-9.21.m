//
//  MusicOveImage.m
//  ReadStaff
//
//  Created by pixeltek on 12-5-20.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "MusicOveImage.h"
#import "MusicOve.h"
#import "defines.h"
#define COM_LOCAL(key) NSLocalizedStringFromTable(key, @"common_languages", nil)


#if TARGET_OS_IPHONE
//#define NEW_PAGE_MODE
#else
#define NEW_PAGE_MODE
#endif

BOOL isRetinaDevice=NO;

@implementation NotePos
- (int) start_y:(int)index
{
    if (index<0 || index>=MAX_POS_NUM) {
        return 0;
    }
    return start_y[index];
}
- (void) start_y:(int)y forIndex:(int)index
{
    if (index<0 || index>=MAX_POS_NUM) {
        return;
    }
    start_y[index]=y;
}
- (void)copyFrom:(NotePos*)pos{
    self.staff=pos.staff;
    self.page=pos.page;
    self.start_x=pos.start_x;
    self.width=pos.width;
    self.height=pos.height;
    self.part_index=pos.part_index;
    [self start_y:[pos start_y:pos.staff-1] forIndex:pos.staff-1];
}
@end

@implementation MeasurePos
@end

@interface MusicOveImage()
{
    NSUInteger STAFF_COUNT;
    int start_tempo_num,start_numerator, start_denominator;
    float start_tempo_type;
    int PART_COUNT;

    int last_fifths;
    float STAFF_HEADER_WIDTH;// =(LINE_H*10)
    
    //init before draw
    float LINE_H;
    int MARGIN_LEFT;
    int MARGIN_RIGHT;
    int MARGIN_TOP;
    float BARLINE_WIDTH;
    float BEAM_WIDTH;
    
    double GROUP_STAFF_NEXT;
    CGSize real_screen_size;
    BOOL landPageMode;
}
@property (nonatomic, strong) NSMutableString *svgXmlContent;
@property (nonatomic, strong) NSMutableString *svgMeasurePosContent;
@property (nonatomic, strong) NSMutableString *svgXmlJianpuContent; //<g id='jianpu'></g>
@property (nonatomic, strong) NSMutableString *svgXmlJianpuFixDoContent; //<g id='jianpufixdo'></g>
@property (nonatomic, strong) NSMutableString *svgXmlJianwpContent; //<g id='jianwp'></g>
@property (nonatomic, strong) NSMutableString *svgXmlJianwpFixDoContent; //<g id='jianwpfixdo'></g>
//@property (nonatomic, strong) NSMutableArray *staff_images; //array of music Svg NSString
@property (nonatomic, strong) NSMutableArray *measure_pos;
@end

@implementation MusicOveImage
@synthesize STAFF_COUNT;
@synthesize start_tempo_num,start_tempo_type, start_numerator, start_denominator;

#define YIYIN_ZOOM 0.6
#define GRACE_X_OFFSET 0

#ifdef OVE_IPHONE
#define MEAS_LEFT_MARGIN (LINE_H) //10
#define MEAS_RIGHT_MARGIN (LINE_H) //10

#define BARLINE_WIDTH 2
#define BEAM_DISTANCE 5
#define BEAM_WIDTH 2.0
#define WAVY_LINE_WIDTH 1
#define SLUR_LINE_WIDTH 1
#define EXPR_FONT_SIZE  16
#define TITLE_FONT_SIZE 22
#define NORMAL_FONT_SIZE 16
#define JIANPU_FONT_SIZE 20
#else

#define MEAS_LEFT_MARGIN  (LINE_H*2.5)//(LINE_H*2)//20
#define MEAS_RIGHT_MARGIN (LINE_H*2.5)//(LINE_H*2)//20

//#define BARLINE_WIDTH 3
#define BEAM_DISTANCE (1.5*BEAM_WIDTH)
#define GLYPH_FONT_SIZE 20
#define GLYPH_FLAG_SIZE (GLYPH_FONT_SIZE*0.7)
#define GLYPH_FINGER_SIZE (GLYPH_FONT_SIZE*0.6)

#define TREMOLO_LINE_WIDTH 3
#define WAVY_LINE_WIDTH 2
#define SLUR_LINE_WIDTH 1
#define EXPR_FONT_SIZE  (LINE_H*2.0)//20
#define TITLE_FONT_SIZE (LINE_H*4.0)//26
#define NORMAL_FONT_SIZE  (LINE_H*1.6)//19
#define JIANPU_FONT_SIZE (LINE_H*2.2)//26
#endif

- (id)init {
    self = [super init];
    if (self) {
        self.pageMode=YES;
        self.showJianpu=NO;
        start_tempo_num=108;
        start_tempo_type=1.0/4;
        self.measure_pos = [[NSMutableArray alloc]init];
        self.staff_images = [[NSMutableArray alloc]init];
#ifdef OVE_IPHONE
        LINE_H=6;
        MARGIN_LEFT=10;
        MARGIN_RIGHT=5;
        MARGIN_TOP=30;
#else
        MARGIN_LEFT=40;
        MARGIN_RIGHT=30;
        MARGIN_TOP=40;//100;
        LINE_H=12;//7.5;
#endif
    }
    return self;
}

- (int)getStaffOffset:(int)track
{
    return STAFF_OFFSET[track];
}

- (OveNote*) getNoteWithOffset:(int) meas_offset measure_pos:(int)meas_pos measure:(OveMeasure*)measure staff:(int)staff voice:(int)voice
{
    OveNote *note2=nil;
    OveMeasure* next_measure=[self.music.measures objectAtIndex:measure.number+meas_pos];
    for (int nn=0; nn<next_measure.notes.count; nn++) {
        OveNote *note=[next_measure.notes objectAtIndex:nn];
        if(note.pos.start_offset==meas_offset && note.staff==staff && note.voice==voice){
            note2=note;
            break;
        }
    }
    return note2;
}

- (float)lineToY:(int)line staff:(int)staff
{
    float y;
    y=(4-line) * (LINE_H*0.5);  //[self getNoteY:note];
    
    if (staff>1)
    {
        y+=STAFF_OFFSET[staff-1];
    }
    
    return y;
}
/*
 横梁线起始和结束坐标
 index staff voice
 0      1       0
 1      1       1
 2      2       0
 3      2       1
 */
CGRect beam_continue_pos[4];
CGRect beam_current_pos;

- (CGRect) getBeamRect:(OveBeam*)beam start_x:(float) start_x start_y:(float)start_y measure:(OveMeasure*)measure reload:(BOOL)reload
{
    CGRect drawPos=CGRectMake(beam.drawPos_x, beam.drawPos_y, beam.drawPos_width, beam.drawPos_height);
    if (drawPos.size.width==0 || reload) {
        BeamElem *elem0=beam.beam_elems.firstObject;// [beam.beam_elems objectAtIndex:0];
        //int staff=beam.staff;
        if (elem0)
        {
            float y1, y2;
            float x1, x2;
            y1 = start_y+ [self lineToY:beam.left_line staff:beam.staff];
            y2 = start_y+ [self lineToY:beam.right_line staff:beam.stop_staff];
            x1 = start_x+MEAS_LEFT_MARGIN+elem0.start_measure_offset*OFFSET_X_UNIT;
            x2 = start_x+MEAS_LEFT_MARGIN+elem0.stop_measure_offset*OFFSET_X_UNIT;
            if (elem0.stop_measure_pos>0) //这个横梁跨小节
            {
                x2+=measure.meas_length_size*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN+MEAS_LEFT_MARGIN;
            }
            
            //查找beam开始位置的note
            OveNote *note1=[self getNoteWithOffset:elem0.start_measure_offset measure_pos:0 measure:measure staff:beam.staff voice:beam.voice];
            float zoom=1;
            if (note1.isGrace) {//倚音
                zoom=YIYIN_ZOOM;
            }
            if (note1.stem_up) {
                x1+=LINE_H*zoom;
            }
            //如果beam开始点note需要变换staff,就修改y1坐标
            if (note1!=nil)
            {
                NoteElem *firstElem=[note1.note_elems objectAtIndex:0];
                if (firstElem.offsetStaff!=0) {
                    //NSLog(@"The note1 beam need offset:%d in measure=%d", note1.note_elem[0].offsetStaff, measure.number);
                    y1 = start_y+ [self lineToY:beam.left_line staff:beam.staff+firstElem.offsetStaff];
                }
            }
            
            //查找beam结束位置的note
            OveNote *note2=[self getNoteWithOffset:elem0.stop_measure_offset measure_pos:elem0.stop_measure_pos measure:measure staff:beam.staff voice:beam.voice];
            if (note2 && note2.stem_up) {
                x2+=LINE_H*zoom;
            }
            
            //如果beam终点note需要变换staff,就修改y2坐标
            if (note2!=nil) {
                NoteElem *firstElem=[note2.note_elems objectAtIndex:0];
                if (firstElem.offsetStaff!=0) {
                    //NSLog(@"The note2 beam need offset:%d in measure=%d", note2.note_elem[0].offsetStaff, measure.number);
                    y2 = start_y+ [self lineToY:beam.right_line staff:beam.stop_staff+firstElem.offsetStaff];
                }
            }/*
              if (note1.isGrace) {
              if (note1.stem_up) {
              y1+=1;
              y2+=1;
              }else{
              y1-=1;
              y2+=1;
              }
              }*/
           
            beam.drawPos_x=drawPos.origin.x=x1;
            beam.drawPos_y=drawPos.origin.y=y1;
            beam.drawPos_width=drawPos.size.width=x2-x1;
            beam.drawPos_height=drawPos.size.height=y2-y1;
            //[NSValue valueWithCGRect:rect];
        }
    }
    return drawPos;
}

#define SLUR_CONTINUE_NUM 8
//CGRect slur_continue_pos[SLUR_CONTINUE_NUM];//0-3: slur, 4-7: tie
//BOOL slur_continue_above[SLUR_CONTINUE_NUM];

struct SlurContinueInfo{
    BOOL above, validate;
    int stop_measure, stop_offset;
    int right_line;
    int stop_staff;
}slur_continue_info[SLUR_CONTINUE_NUM];

#define OCTAVE_CONTINUE_NUM 2
struct OctaveContinueInfo{
    BOOL validate;
    int offset_y,staff, start_line;
    int octave_x1,octave_y1;
}octave_continue_info[OCTAVE_CONTINUE_NUM];

+ (NSString*)svgRect:(CGRect)rect fillColor:(NSString*)fillColor strokeColor:(NSString*)strokeColor
{
    NSString *ret=[NSString stringWithFormat:@"<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' fill='%@' stroke='%@' />\n", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height, fillColor,strokeColor];
    return ret;
}

//#define fillColor "fill='white'"
//#define strokeColor "stroke='white'"
//#define bgColor "style=\"background-color:#A78464\"" //驼色
#define fillColor "fill='black'"
#define strokeColor "stroke='black'"
//#define bgColor "style=\"background-color:#FEFBEB\"" //77music黄
//#define bgColor "style=\"background-color:#D1A072\"" // 深色牛皮纸
//#define bgColor "style=\"background-color:#E0C794\"" // 牛皮纸
//#define bgColor "style=\"background-color:#EFDAB0\"" //浅色牛皮纸

#if TARGET_OS_IPHONE
#define bgColor "style=\"background-color:#F1E0B7\"" //浅色牛皮纸
#else
#define bgColor "style=\"background-color:#AEABAB\"" //灰色
#endif

#define grayColor @"#FEFBEB"
#define paperColor @"#F1E0B7"

#define CIRCLE(cx,cy,r,fill,stroke) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<circle cx='%.1f' cy='%.1f' r='%.1f' fill='%@' stroke='%@' transform=\"skewX(45)\" />\n", cx, cy, r, fill,stroke]]

/*
 <line x1="0" y1="0" x2="300" y2="300" style="stroke:rgb(99,99,99);stroke-width:2"/>
 <line x1="40" x2="120" y1="100" y2="100" stroke="black" stroke-width="20" stroke-linecap="round"/>
 线的端点: stroke-linecap属性
 　　这个属性定义了线段端点的风格，这个属性可以使用butt(平),square(方),round(圆)三个值.
 */
//#define BEGIN_MEASURE(m,x,y,w,h) \
//[self.svgXmlContent appendString:[NSString stringWithFormat:@"<rect id='m%d' x='%d' y='%d' width='%d' height='%d' style='fill: rgba(200, 200, 210, 0);' onclick='clickMm(%d)' />\n",m,x,y,w,h,m]]

#define BEGIN_MEASURE(m,x,y,w,h) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<rect id='m%d' x='%d' y='%d' width='%d' height='%d' style='fill: rgba(200, 200, 210, 0);'  />\n",m,x,y,w,h]]

#define END_MEASURE()

#define LINE_C(x1,y1,x2,y2,stroke,w)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<line x1='%.1f' x2='%.1f' y1='%.1f' y2='%.1f' stroke='%@' stroke-width='%d' />\n",x1,x2,y1,y2,stroke,w]]

#define LINE_W(x1,y1,x2,y2,w)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<line x1='%.1f' x2='%.1f' y1='%.1f' y2='%.1f' "strokeColor" stroke-width='%.1f' />\n",(float)(x1),(float)(x2),(float)(y1),(float)(y2),(float)(w)]];

#define LINE(x1,y1,x2,y2)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<line x1='%.1f' x2='%.1f' y1='%.1f' y2='%.1f' "strokeColor" />\n",(float)(x1),(float)(x2),(float)(y1),(float)(y2)]]

#define LINE_DOT(x1,y1,x2,y2)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<line x1='%d' x2='%d' y1='%d' y2='%d' stroke='black' stroke-width=\"1\" stroke-dasharray=\"5,5\" />\n",(int)(x1),(int)(x2),(int)(y1),(int)(y2)]]


#define TEXT(x,y,font_size, text)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' "fillColor">%@</text>\n", (int)(x), (int)(y+(font_size)),(int)(font_size), text]]

#define TEXT_ATTR(x,y,font_size, text, isBold, isItalic)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' "fillColor" font-weight='%@' font-style='%@'>%@</text>\n", (int)(x), (int)(y+(font_size)),(int)(font_size), (isBold)?@"bold":@"normal", (isItalic)?@"italic":@"normal", text]]

#define TEXT_CENTER(x,y,font_size, text)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' text-anchor=\"middle\" "fillColor">%@</text>\n", (int)(x), (int)(y+(font_size)),(int)(font_size), text]]

#define TEXT_RIGHT(x,y,font_size, text)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' text-anchor=\"end\" "fillColor">%@</text>\n", (int)(x), (int)(y+(font_size)),(int)(font_size), text]]

#define TEXT_RIGHT_ITALIC(x,y,font_size, text)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' text-anchor=\"end\" "fillColor" font-style='italic'>%@</text>\n", (int)(x), (int)(y+(font_size)),(int)(font_size), text]]

#if 0
#define TEXT_JIANPU(x,y,text, fixdoText, size)  \
[self.svgXmlJianpuContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' fill='blue'>%@</text>\n", (int)(x), (int)(y+(size)),(int)(size), text]];

//style="fill:#000000;font-family:Arial;font-weight:bold;font-size:40;"
#define TEXT_JIANWP(x,y,text,fixdoText,size, color) \
[self.svgXmlJianpuFixDoContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' style='fill:%@;font-family:Arial;font-weight:bold;font-size:%d;'>%@</text>\n", (int)(x+LINE_H*0.4), (int)(y+LINE_H*0.4), color, (int)(size), fixdoText]]

#else

#define TEXT_JIANPU(x,y,text, fixdoText, size)  \
[self.svgXmlJianpuContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' fill='blue'>%@</text>\n", (int)(x), (int)(y+(size)),(int)(size), text]];  \
[self.svgXmlJianpuFixDoContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' fill='blue'>%@</text>\n", (int)(x), (int)(y+(size)),(int)(size), fixdoText]]

//style="fill:#000000;font-family:Arial;font-weight:bold;font-size:40;"
//<circle cx="15" cy="15" r="15" fill="yellow" transform="skewX(45)" />
#define BACK_JIANWP(x,y,r,color) \
[self.svgXmlJianwpContent appendString:[NSString stringWithFormat:@"<circle cx='0' cy='0' r='%.1f' fill='%@' transform='translate(%d,%d)' />\n", r, color, (int)(x+r*1.5), (int)(y-r*0.0)]]; \
[self.svgXmlJianwpFixDoContent appendString:[NSString stringWithFormat:@"<circle cx='0' cy='0' r='%.1f' fill='%@' transform='translate(%d,%d)' />\n", r,  color, (int)(x+r*1.5), (int)(y-r*0.00)]];


#define TEXT_JIANWP(x,y,text,fixdoText,size, color) \
[self.svgXmlJianwpContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' style='fill:%@;font-family:Arial;font-weight:bold;font-size:%d;'>%@</text>\n", (int)(x+LINE_H*0.4), (int)(y+LINE_H*0.45), color, (int)(size), text]]; \
[self.svgXmlJianwpFixDoContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' style='fill:%@;font-family:Arial;font-weight:bold;font-size:%d;'>%@</text>\n", (int)(x+LINE_H*0.4), (int)(y+LINE_H*0.45), color, (int)(size), fixdoText]]

#endif

#define SHARP_JIANPU(x,y)   \
[self.svgXmlJianpuContent appendString:[NSString stringWithFormat:@"<text x='%.1f' y='%.1f' font-size=\"20\" fill=\"blue\" style=\"font-family: 'Aloisen New'\">%@</text>\n", (float)(x), (float)(y), ELEM_FLAG_SHARP]]; \
[self.svgXmlJianpuFixDoContent appendString:[NSString stringWithFormat:@"<text x='%.1f' y='%.1f' font-size=\"20\" fill=\"blue\" style=\"font-family: 'Aloisen New'\">%@</text>\n", (float)(x), (float)(y), ELEM_FLAG_SHARP]]

#define FLAT_JIANPU(x,y)   \
[self.svgXmlJianpuContent appendString:[NSString stringWithFormat:@"<text x='%.1f' y='%.1f' font-size='24' fill='blue' style=\"font-family: 'Aloisen New'\">%@</text>\n", (float)(x), (float)(y), ELEM_FLAG_FLAT]]; \
[self.svgXmlJianpuFixDoContent appendString:[NSString stringWithFormat:@"<text x='%.1f' y='%.1f' font-size='24' fill='blue' style=\"font-family: 'Aloisen New'\">%@</text>\n", (float)(x), (float)(y), ELEM_FLAG_FLAT]]

#define DOT_JIANPU(x,y) \
[self.svgXmlJianpuContent appendString:[NSString stringWithFormat:@"<text x='%.1f' y='%.1f' font-size=\"30\" fill=\"blue\" style=\"font-family: 'Aloisen New'\">%@</text>\n", (float)(x), (float)(y), @"c7"]]; \
[self.svgXmlJianpuFixDoContent appendString:[NSString stringWithFormat:@"<text x='%.1f' y='%.1f' font-size=\"30\" fill=\"blue\" style=\"font-family: 'Aloisen New'\">%@</text>\n", (float)(x), (float)(y), @"c7"]]

#define RECT_JIANPU(x,y,w,h)   \
[self.svgXmlJianpuContent appendFormat:@"<rect x='%d' y='%d' width='%d' height='%d' fill='rgba(252,252,230,0.75)' />", (int)(x), (int)(y), (int)(w), (int)(h)]; \
[self.svgXmlJianpuFixDoContent appendFormat:@"<rect x='%d' y='%d' width='%d' height='%d' fill='rgba(252,252,230,0.75)' />", (int)(x), (int)(y), (int)(w), (int)(h)];

#define LINE_JIANPU(x1,x2,y,w)    \
[self.svgXmlJianpuContent appendString:[NSString stringWithFormat:@"<line x1='%.1f' x2='%.1f' y1='%.1f' y2='%.1f' stroke=\"blue\" stroke-width='%d' />\n",(float)(x1),(float)(x2),(float)(y),(float)(y), (w)]]; \
[self.svgXmlJianpuFixDoContent appendString:[NSString stringWithFormat:@"<line x1='%.1f' x2='%.1f' y1='%.1f' y2='%.1f' stroke=\"blue\" stroke-width='%d' />\n",(float)(x1),(float)(x2),(float)(y),(float)(y), (w)]]


//<image xlink:href="Penguins.jpg" x="0" y="0" height="50px" width="50px"/>
#define IMAGE(x,y,w,h,img)  \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<image xlink:href='%@' x='%d' y='%d' width=\"%dpx\" height=\"%dpx\"/>\n",img, (int)(x),(int)(y),(int)(w),(int)(h)]]


#define DEFS_SVG_FONT()  \
[self.svgXmlContent appendString:@"<defs><style type=\"text/css\">\n\
<![CDATA[\n\
@font-face {\n\
font-family: 'Aloisen New';\n\
src: url(\"Aloisen New.svg#Aloisen\") format(\"svg\")\n\
}\n\
]]>\n\
</style></defs>\n"]

#define GROUP(x,y,size) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' "fillColor" style=\"font-family: 'Aloisen New';\">group</text>\n", (int)(x), (int)(y), (int)(size)]]

#define GLYPH_Petrucci(x,y,size,rotate,glyph) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%.1f' y='%.1f' font-size='%d' style=\"font-family: 'Aloisen New';\" "fillColor">&#x1%@;</text>\n", (float)(x), (float)(y), (int)(size*LINE_H*0.1),glyph]]

#define GLYPH_Petrucci_id(x,y,size,glyph, ID) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text id='%@' x='%.1f' y='%.1f' font-size='%d' style=\"font-family: 'Aloisen New';\" "fillColor">&#x1%@;</text>\n",ID, (float)(x), (float)(y), (int)(size*LINE_H*0.1),glyph]]

#define GLYPH_Petrucci_index(x,y,size,glyph, m,n,e) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text id='%d_%d_%d' x='%.1f' y='%.1f' font-size='%d' style=\"font-family: 'Aloisen New';\" onclick='clickNote(this,%d,%d,%d)'>&#x1%@;</text>\n",m,n,e, (float)(x), (float)(y), (int)(size*LINE_H*0.1),m,n,e,glyph]]

#define GLYPH_Petrucci_rotate(x,y,size,rotate,glyph) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%.1f' y='%.1f' font-size='%d' style=\"font-family: 'Aloisen New';\" rotate='%d'>&#x1%@;</text>\n", (float)(x), (float)(y), (int)(size*LINE_H*0.1),rotate,glyph]]


#define ELEM_WAVY @"ac"
#define LINE_WAVY_VERTICAL(x, y1, y2, w) [self svgWavyVertical:x start_y:y1 end_y:y2 width:w]
- (void)svgWavyVertical:(int)x start_y:(int)y1 end_y:(int)y2 width:(int)w
{
    if (y1>y2) {
        int temp=y2;
        y2=y1;
        y1=temp;
    }
    int count=(y2+2.8*LINE_H-y1)/LINE_H;
    for(int n=0;n<count;n++)
    {
        GLYPH_Petrucci(x,y1+n*LINE_H,GLYPH_FLAG_SIZE,0,ELEM_WAVY);
    }
}
#define ELEM_WAVY_HORIZONTAL @"e8"
#define LINE_WAVY_HORIZONTAL(x1, x2, y) [self svgWavyHorizontal:y start_x:x1 end_x:x2]
- (void)svgWavyHorizontal:(int)y start_x:(int)x1 end_x:(int)x2
{
    for(int n=0;n<(x2-x1)/LINE_H;n++)
    {
        GLYPH_Petrucci(x1+n*LINE_H,y,GLYPH_FLAG_SIZE,0,ELEM_WAVY_HORIZONTAL);
    }
}

// http://en.wikipedia.org/wiki/List_of_musical_symbols

#define FIVE_LINES(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"3d") //=

#define Treble  @"80" //@"26"
#define Bass    @"81" //@"3f"
#define Middle  @"82" //@"26"
#define Percussion1 @"83"

//#define CLEF_TREBLE(x,y,zoom) GLYPH_Petrucci(x,y,40*zoom,0,@"26") //&
#define CLEF_TREBLE(x,y,zoom) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,Treble) //&
#define CLEF_BASS(x,y, zoom) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,Bass) //?
#define CLEF_MID(x,y, zoom) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,Middle) //B
#define CLEF_Percussion1(x,y, zoom) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,Percussion1) //B

#define ELEM_TIME_SIGNATURE_COMMON_TIME @"8a" //4/4拍
#define ELEM_TIME_SIGNATURE_CUT_TIME @"8b" //2/2拍

#define ELEM_FLAG_SHARP @"21"
#define ELEM_FLAG_FLAT  @"22"
#define ELEM_FLAG_STOP  @"23"
#define ELEM_FLAG_DOUBLE_SHARP @"24"
#define ELEM_FLAG_DOUBLE_FLAT @"25"
#define ELEM_FLAG_SHARP_CAUTION @"26"
#define ELEM_FLAG_FLAT_CAUTION @"27"
#define ELEM_FLAG_STOP_CAUTION @"28"
#define ELEM_FLAG_DOUBLE_SHARP_CAUTION @"29"
#define ELEM_FLAG_DOUBLE_FLAT_CAUTION @"2a"


#define FLAG_SHARP(x,y,zoom) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE*zoom,0,ELEM_FLAG_SHARP) //#
#define FLAG_SHARP_CAUTION(x,y) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE,0,ELEM_FLAG_SHARP_CAUTION) //[ 123
#define FLAG_DOUBLE_SHARP(x,y,zoom) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE*zoom,0,ELEM_FLAG_DOUBLE_SHARP) //0220
//#define FLAG_DOUBLE_SHARP(x,y) GLYPH_Petrucci(x,y,30,0,ELEM_FLAG_DOUBLE_SHARP) //0220
#define FLAG_DOUBLE_SHARP_CAUTION(x,y) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE,0,ELEM_FLAG_DOUBLE_SHARP_CAUTION) // ]

#define FLAG_FLAT(x,y,zoom) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE*zoom,0,ELEM_FLAG_FLAT) //b 98
#define FLAG_FLAT_CAUTION(x,y) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE,0,ELEM_FLAG_FLAT_CAUTION) //{ 123
#define FLAG_DOUBLE_FLAT(x,y) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE,0,ELEM_FLAG_DOUBLE_FLAT) //0186
#define FLAG_DOUBLE_FLAT_CAUTION(x,y) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE,0,ELEM_FLAG_DOUBLE_FLAT_CAUTION) //0211

#define FLAG_STOP(x,y,zoom) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE*zoom,0,ELEM_FLAG_STOP) //n
#define FLAG_STOP_CAUTION(x,y, zoom) GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE*zoom,0,ELEM_FLAG_STOP_CAUTION) //N

#define ELEM_NOTE_QUADRUPLE_WHOLE      @"69"
#define ELEM_NOTE_DOUBLE_WHOLE      @"40"
#define ELEM_NOTE_FULL      @"41"
#define ELEM_NOTE_2_UP      @"42"
#define ELEM_NOTE_4_UP      @"43" //@"43"
#define ELEM_NOTE_8_UP      @"44" //@"44"
#define ELEM_NOTE_16_UP     @"45"
#define ELEM_NOTE_32_UP     @"46"
#define ELEM_NOTE_64_UP     @"47"
#define ELEM_NOTE_128_UP     @"48"

#define ELEM_NOTE_2_DOWN    @"52"//@"48"
#define ELEM_NOTE_4_DOWN    @"53"//@"51"
#define ELEM_NOTE_8_DOWN    @"54"//@"45"
#define ELEM_NOTE_16_DOWN   @"55"//@"58"
#define ELEM_NOTE_32_DOWN   @"56"
#define ELEM_NOTE_64_DOWN   @"57"
#define ELEM_NOTE_128_DOWN   @"58"

#define ELEM_NOTE_2   @"7c" //@"7c"
#define ELEM_NOTE_4   @"74" //@"74"

#define ELEM_NOTE_OpenHiHat @"51"
#define ELEM_NOTE_CloseHiHat @"4e"

#define NOTE(x,y,zoom, ELEM, ID) GLYPH_Petrucci_id(x,y-1,GLYPH_FONT_SIZE*zoom,ELEM, ID)
#define NOTE_Index(x,y,zoom, ELEM, m,n,e) GLYPH_Petrucci_index(x,y,GLYPH_FONT_SIZE*zoom,ELEM, m,n,e)

#define NOTE_FULL(x,y,zoom) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_FULL) //w
#define NOTE_2(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_2) //0250
#define NOTE_2_UP(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_2_UP) //h
#define NOTE_2_DOWN(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_2_DOWN) //H
#define NOTE_4(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_4) //0x0207
#define NOTE_4_UP(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_4_UP)//q
#define NOTE_4_DOWN(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_4_DOWN)//Q
#define NOTE_8_UP(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_8_UP)//e
#define NOTE_8_DOWN(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_8_DOWN)//E
#define NOTE_16_UP(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_16_UP)//x
#define NOTE_16_DOWN(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_16_DOWN)//X

#define NOTE_32_UP(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_32_UP) //GLYPH_Petrucci2(x,y,40*zoom,0,@"78;&#xf0fb");
#define NOTE_64_UP(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_64_UP) //GLYPH_Petrucci2(x,y,40*zoom,0,@"78;&#xf0fb;&#xf0fb");
#define NOTE_128_UP(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_128_UP)//GLYPH_Petrucci2(x,y,40*zoom,0,@"78;&#xf0fb;&#xf0fb;&#xf0fb");

#define NOTE_OpenHiHat(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_OpenHiHat)
#define NOTE_CloseHiHat(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_CloseHiHat)

#define GLYPH_Petrucci2(x,y,size,rotate,glyph) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' fill='black' style=\"font-family: 'Petrucci', Helvetica, sans-serif; font-weight: 5; font-style: normal\" rotate='%d'><tspan  x=\"%d,%d,%d,%d\" dy=\"0,%d,%d,%d\">%@</tspan></text>\n", (int)(x), (int)(y), (int)(size),rotate, (int)(x), (int)(x+(size)*0.027*LINE_H), (int)(x+(size)*0.027*LINE_H), (int)(x+(size)*0.025*LINE_H), (int)(-(size)*0.1*LINE_H), (int)(-(size)*0.02*LINE_H), (int)(-(size)*0.02*LINE_H),glyph]]

/*
<text style="fill:#000000;font-family:Arial;font-weight:bold;font-size:40">
<tspan x="50" y="60,70,80,80,75,60,80,70">COMMUNICATION</tspan>
<tspan x="50" y="150" dx="0,15" dy="10,10,10,-10,-10,-10,10,10,-10">COMMUNICATION</tspan>
<tspan x="50" y="230" rotate="10,20,30,40,50,60,70,80,90,90,90,90,90">COMMUNICATION</tspan>
</text>
*/
#define NOTE_32_DOWN(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_32_DOWN) //GLYPH_Petrucci3(x,y,40*zoom,0,@"58;&#xf0f0")
#define NOTE_64_DOWN(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_64_DOWN) //GLYPH_Petrucci3(x,y,40*zoom,0,@"58;&#xf0f0;&#xf0f0")
#define NOTE_128_DOWN(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,ELEM_NOTE_128_DOWN) //GLYPH_Petrucci3(x,y,40*zoom,0,@"58;&#xf0f0;&#xf0f0;&#xf0f0")

#define GLYPH_Petrucci3(x,y,size,rotate,glyph) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' fill='black' style=\"font-family: 'Petrucci', Helvetica, sans-serif; font-weight: 5; font-style: normal\" rotate='%d'><tspan  x=\"%d,%d,%d,%d\" dy=\"0,%d,%d,%d\">%@</tspan></text>\n", (int)(x), (int)(y), (int)(size*0.1*LINE_H),rotate, (int)(x), (int)(x), (int)(x), (int)(x), (int)(+(size)*0.09*LINE_H), (int)(+(size)*0.02*LINE_H), (int)(+(size)*0.02*LINE_H),glyph]]

#define NOTE_DOT(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"c7") //@"6b") //2e,6b
#define NORMAL_DOT(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"c7") //@"2e") //2e,6b


#define TAIL_EIGHT_UP(x,y, zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,@"49") //GLYPH_Petrucci(x,y,40*zoom,0,@"6a")//j,251,K
#define TAIL_16_UP_ZOOM(x,y,zoom)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE*zoom,0,@"4a") //GLYPH_Petrucci_Tails_up(x,y,40*zoom,@"6a;&#xf0fb")//r
#define TAIL_16_UP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"4a") //GLYPH_Petrucci_Tails_up(x,y,40,@"6a;&#xf0fb")//r
#define TAIL_32_UP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"4b") //GLYPH_Petrucci_Tails_up(x,y,40,@"6a;&#xf0fb;&#xf0fb")
#define TAIL_64_UP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"4c") //GLYPH_Petrucci_Tails_up(x,y,40,@"6a;&#xf0fb;&#xf0fb;&#xf0fb")
#define TAIL_128_UP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"4d")

#define TAIL_EIGHT_DOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"59") //GLYPH_Petrucci(x,y,40,0,@"4A")//J,239,240
#define TAIL_16_DOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"5a") //GLYPH_Petrucci_Tails_down(x,y,40,@"4a;&#xf0f0")//R
#define TAIL_32_DOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"5b") //GLYPH_Petrucci_Tails_down(x,y,40,@"4a;&#xf0f0;&#xf0f0")
#define TAIL_64_DOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"5c") //GLYPH_Petrucci_Tails_down(x,y,40,@"4a;&#xf0f0;&#xf0f0;&#xf0f0")
#define TAIL_128_DOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"5d")

#define GLYPH_Petrucci_Tails_up(x,y,size,glyph) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' fill='black' style=\"font-family: 'Petrucci', Helvetica, sans-serif; font-weight: 5; font-style: normal\"><tspan  x=\"%d,%d,%d,%d\" dy=\"0,%d,%d,%d\">%@</tspan></text>\n", (int)(x), (int)(y), (int)(size*0.1*LINE_H), (int)(x), (int)(x), (int)(x), (int)(x), (int)(-(size)*0.025*LINE_H), (int)(-(size)*0.025*LINE_H), (int)(-(size)*0.025*LINE_H),glyph]]

#define GLYPH_Petrucci_Tails_down(x,y,size,glyph) \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<text x='%d' y='%d' font-size='%d' fill='black' style=\"font-family: 'Petrucci', Helvetica, sans-serif; font-weight: 5; font-style: normal\"><tspan  x=\"%d,%d,%d,%d\" dy=\"0,%d,%d,%d\">%@</tspan></text>\n", (int)(x), (int)(y), (int)(size*0.1*LINE_H), (int)(x), (int)(x), (int)(x), (int)(x), (int)(+(size)*0.025*LINE_H), (int)(+(size)*0.025*LINE_H), (int)(+(size)*0.025*LINE_H),glyph]]

#define RESET_QUARTER(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"63") //@"\x63\x00") //@"ce") //206
#define RESET_EIGHT(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"64") //@"\x64\x00") //@"e4") //228
#define RESET_16(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"65") //@"\x65\x00") //@"c5")//197
#define RESET_32(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"66") //@"\x66\x00") //@"a8")//168
#define RESET_64(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"67") //@"\x67\x00") //@"f4")//244
#define RESET_128(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"68") //@"\x68\x00") //@"e5")//229

#define ELEM_P      @"90"//@"70" //Piano
#define ELEM_PP     @"91"//@"b9" //Pianissimo
#define ELEM_PPP    @"92"//@"b8" //Pianississimo
#define ELEM_PPPP   @"93"//@"af"  
#define ELEM_MP     @"94"//@"50" //Mezzo piano
#define ELEM_F      @"95"//@"66" //Forte
#define ELEM_FF     @"96"//@"c4" //Fortissimo
#define ELEM_FFF    @"97"//@"ec" //Fortississimo
#define ELEM_FFFF   @"98"//@"eb"
#define ELEM_MF     @"99"//@"46" //Mezzo forte
#define ELEM_SF     @"9a"//@"53"
//#define ELEM_SFF    @"9a95"
#define ELEM_FZ     @"9b"//@"5a"
#define ELEM_SFZ    @"9c"//@"a7" //Sforzando
#define ELEM_FP     @"9d"//@"ea" //Forte-piano

#define DYNAMICS_PPPP(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_PPPP)//175
#define DYNAMICS_PPP(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_PPP)//184
#define DYNAMICS_PP(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_PP)//185
#define DYNAMICS_P(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_P)//p
#define DYNAMICS_MP(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_MP)//P
#define DYNAMICS_MF(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_MF)//F
#define DYNAMICS_F(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_F)//f
#define DYNAMICS_FF(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_FF)//196
#define DYNAMICS_FFF(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_FFF)//236
#define DYNAMICS_FFFF(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_FFFF)//235
#define DYNAMICS_S(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"73")//s
#define DYNAMICS_SF(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_SF)//S
#define DYNAMICS_SFF(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_SF);GLYPH_Petrucci(x+GLYPH_FONT_SIZE/2,y,GLYPH_FONT_SIZE, 0, ELEM_F)//S
#define DYNAMICS_Z(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"7a")//z
#define DYNAMICS_FZ(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_FZ)//Z
#define DYNAMICS_SFZ(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_SFZ)//167
#define DYNAMICS_SFFZ(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"8d")//141
#define DYNAMICS_FP(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, ELEM_FP)//234
#define DYNAMICS_SFP(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"9a90")//130
#define DYNAMICS_SFPP(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"9a91")//182

#define TEXT_NUM_ALL(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"30;&#xf031;&#xf032;&#xf033;&#xf034;&#xf035;&#xf036;&#xf037;&#xf038;&#xf039")
#define TEXT_NUM_0(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"30") //num=0-9
#define TEXT_NUM_1(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"31") //num=0-9
#define TEXT_NUM_2(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"32") //num=0-9
#define TEXT_NUM_3(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"33") //num=0-9
#define TEXT_NUM_4(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"34") //num=0-9
#define TEXT_NUM_5(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"35") //num=0-9
#define TEXT_NUM_6(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"36") //num=0-9
#define TEXT_NUM_7(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"37") //num=0-9
#define TEXT_NUM_8(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"38") //num=0-9
#define TEXT_NUM_9(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"39") //num=0-9
#define TEXT_NUM(x,y,num) TEXT_NUM_##num(x,y) //num=0-9

//http://en.wikipedia.org/wiki/Dal_Segno
#define REPEAT_SEGNO(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"b0")//@"25")
#define REPEAT_CODA(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"b1")//@"de")
//http://en.wikipedia.org/wiki/Category:Musical_notation

//Staccato跳音 音符上面一个点
#define ART_STACCATO(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"c7")//@"6b") //2e,6b
//Tenuto 保持音 音符上面一条横线
#define ART_TENUTO(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"c8")//@"2d") //2d
//Accent //Marcato 着重/重音 音符上面一个大于号“>”
#define ART_MARCATO(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"c0")//@"3e") //3e
//Marcato_Dot 着重断奏 音符上面一个大于号“>”下面加一个点
#define ART_MARCATO_DOT_UP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE, 0, @"c1")//@"f9")
#define ART_MARCATO_DOT_DOWN(x,y)   GLYPH_Petrucci_rotate(x+LINE_H,y,GLYPH_FLAG_SIZE, 90, @"c1")//@"27") GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE, 0, @"df")

//Marcato //strong_accent_placement  音符上面一个"^"或者下方一个"V"
#define ART_STRONG_ACCENT_UP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE, 0, @"c2")//@"5e")
#define ART_STRONG_ACCENT_DOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE, 0, @"c4")//@"76")
//SForzando_Dot 音符上一个^加一个点，或者下方V加一个点。
#define ART_SFORZANDO_UP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE, 0, @"c3")//@"ac")
#define ART_SFORZANDO_DOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FLAG_SIZE, 0, @"c5")//@"e8")
//Staccatissimo or Spiccato 顿音 音符上面一个实心的三角形
#define ART_STACCATISSIMO(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"c6")//@"ae")
//#define ART_STACCATISSIMO_DOWN(x,y)  GLYPH_Petrucci(x+LINE_H,y,40, 180, @"c6")//@"27")
#define ART_STACCATISSIMO_DOWN(x,y)  GLYPH_Petrucci_rotate(x+LINE_H,y,GLYPH_FONT_SIZE, 180, @"c6")//@"27")

//Articulation_Fermata://延长记号 音符上面一个半圆，里面有一个点。
#define ART_FERMATA_DOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"b3")//@"75") //"fermata"="延长记号，停留记号";
#define ART_FERMATA_UP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"b2")//@"55")
//Mordent 咬音
/*
 1. Mordent or lower mordent: a shake sign crossed by a vertical line:一个锯齿符号中间穿过一条竖线
 Articulation_Short_Mordent
 如果四分音符C音上又这个符号就是要弹奏： C-B-C, 前两个是16分音符长，第三个是8分音符长
 
 2. Upper Mordent or inverted mordent: a same shake sign: 一个同样的锯齿符号
 Articulation_Inverted_Short_Mordent
 如果四分音符C音上又这个符号就是要弹奏：： D-C-D-C, 前3个是16分音符长，剩下的最后一个补足。
 Articulation_Inverted_Long_Mordent
 如果四分音符C音上又这个符号就是要弹奏： D-C-D-C-D-C..., 前面5个音是16分音符长，剩下的最后一个补足。
 */
#define ART_MORDENT_UPPER(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"a3")//@"6d") //
#define ART_MORDENT_LOWER(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"a4")//@"4d") //
#define ART_MORDENT_LONG(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"a5")//@"b5") //
//turn 音符上面一个横的S字， 表示要连续弹奏：本身，低一度音，本身
#define ART_TURN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"a6")//@"54") //
#define ART_PEDAL_DOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"d0")//@"a1")//161 //踏板
#define ART_PEDAL_UP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"d1")//@"2a")//*

//bowUp/down
#define ART_BOWDOWN(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"cd")
#define ART_BOWUP(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"cc")
#define ART_BOWDOWN_BELOW(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"cf")
#define ART_BOWUP_BELOW(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE, 0, @"ce")

//颤音 tr
#define ART_TRILL(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"a0")//@"d9")

//Octave 8va
#define OCTAVE_ATTAVA(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"b4")
//Octave 8vb
#define OCTAVE_ATTAVB(x,y)  GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"b5")
//Octave 15ma
#define OCTAVE_QUINDICESIMA(x,y)    GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"b6")

//震音 Tremolo
#define TREMOLO_8(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"a8")
#define TREMOLO_16(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"a9")
#define TREMOLO_32(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"aa")
#define TREMOLO_64(x,y) GLYPH_Petrucci(x,y,GLYPH_FONT_SIZE,0,@"ab")

- (void)fiveLines:(int)x y:(int)y
{
    for (int i=0; i<26; i++) {
        FIVE_LINES(x,y);
        x+=4*LINE_H;
    }
}
- (void)LoadMusicKnowledgeWithSize:(CGSize)screen
{
    LINE_H=10;
    [self beginSvgImage:screen];
    
    int x,y;
    x=10;
    y=120;
    
    //clef
    TEXT(x, y-80, 20, @"Clef");
    [self fiveLines:x y:y];
    CLEF_TREBLE(x+LINE_H, y-LINE_H, 1); x+=4*LINE_H;
    CLEF_MID(x+LINE_H, y-2*LINE_H, 1); x+=4*LINE_H;
    CLEF_BASS(x+LINE_H, y-3*LINE_H, 1); x+=4*LINE_H;
    
    //notation
    //x+=80;
    //y+=100;
    TEXT(x, y-70, 20, @"Notation and Accidental");
    NOTE_FULL(x, y, 1);x+=20;
    NOTE_2(x, y, 1);x+=20;
    NOTE_2_UP(x, y, 1);x+=20;
    NOTE_2_DOWN(x, y, 1);x+=20;
    NOTE_4(x, y, 1);x+=20;
    NOTE_4_UP(x, y, 1);x+=20;
    NOTE_4_DOWN(x, y, 1);x+=20;
    NOTE_8_UP(x, y, 1);x+=20;
    NOTE_8_DOWN(x, y, 1);x+=20;
    NOTE_16_UP(x, y, 1);x+=20;
    NOTE_16_DOWN(x, y, 1);x+=20;
    NOTE_32_UP(x, y, 1);x+=20;
    NOTE_32_DOWN(x, y, 1);x+=20;
    NOTE_64_UP(x, y, 1);x+=20;
    NOTE_64_DOWN(x, y, 1);x+=20;
    NOTE_128_UP(x, y, 1);x+=20;
    NOTE_128_DOWN(x, y, 1);x+=20;
    /*
    NOTE_32_DOWN(x, y, 1);x+=20;
    
    RESET_QUARTER(x, y);x+=20;
    RESET_EIGHT(x, y);x+=20;
    RESET_16(x, y);x+=20;
    RESET_32(x, y);x+=20;
    RESET_64(x, y);x+=20;
    RESET_128(x, y);x+=20;

    FLAG_SHARP(x,y);x+=20;
    FLAG_SHARP_CAUTION(x,y);x+=30;
    FLAG_DOUBLE_SHARP(x,y);x+=20;
    FLAG_DOUBLE_SHARP_CAUTION(x,y);x+=30;
    
    FLAG_FLAT(x,y);x+=20;
    FLAG_FLAT_CAUTION(x,y);x+=30;
    FLAG_DOUBLE_FLAT(x,y);x+=30;
    FLAG_DOUBLE_FLAT_CAUTION(x,y);x+=30;
    
    FLAG_STOP(x,y);x+=20;
    FLAG_STOP_CAUTION(x,y);x+=30;
    //FLAG_DOUBLE_STOP(x,y);x+=20;
    //FLAG_DOUBLE_STOP_CAUTION(x,y);x+=20;
    */
    
    //Dynamics
    x=10;
    y+=60;
    TEXT(x, y-40, 20, @"Dynamics");
    DYNAMICS_PPPP(x,y); x+=65;//0af")//175
    DYNAMICS_PPP(x,y); x+=50;//0b8")//184
    DYNAMICS_PP(x,y); x+=40;//0b9")//185
    DYNAMICS_P(x,y); x+=30;//070")//p
    DYNAMICS_MP(x,y); x+=40;//050")//P
    DYNAMICS_MF(x,y); x+=40;//046")//F
    DYNAMICS_F(x,y); x+=30;//066")//f
    DYNAMICS_FF(x,y); x+=40;//0c4")//196
    DYNAMICS_FFF(x,y); x+=40;//0ec")//236
    DYNAMICS_FFFF(x,y); x+=60;//0eb")//235
    DYNAMICS_S(x,y); x+=30;//073")//s
    DYNAMICS_SF(x,y); x+=40;//053")//S
    DYNAMICS_Z(x,y); x+=30;//07a")//z
    DYNAMICS_FZ(x,y); x+=40;//05a")//Z
    DYNAMICS_SFZ(x,y); x+=450;//0a7")//167
    DYNAMICS_SFFZ(x,y); x+=60;//08d")//141
    DYNAMICS_FP(x,y); x+=40;//0ea")//234
    DYNAMICS_SFP(x,y); x+=50;//082")//130
    DYNAMICS_SFPP(x,y); x+=60;//0b6")//182
    //TEXT_NUM_ALL(x,y);x+=50;
    x=10;y+=30;
    TEXT_NUM_ALL(x,y);x+=10*20;
    ART_FERMATA_DOWN(x, y);x+=40; //延长记号
    ART_FERMATA_UP(x, y);x+=40;
    ART_PEDAL_DOWN(x, y);x+=60; //踏板
    ART_PEDAL_UP(x,y);x+=40;
    //staccato跳音 音符上面一个点
    ART_STACCATO(x,y);x+=40;
    //tenuto 保持音 音符上面一条横线
    ART_TENUTO(x,y);x+=40;
    //accent 重音 音符上面一个大于号“>”
    ART_MARCATO(x,y);x+=40;
    //strong_accent_placement  音符上面一个大于号"^"
    ART_STRONG_ACCENT_UP(x,y);x+=40;
    //staccatissimo_placement 顿音 音符上面一个实心的三角形
    ART_STACCATISSIMO(x,y);x+=40;
    //Mordent 咬音
    ART_MORDENT_LOWER(x,y);x+=40;
    ART_MORDENT_UPPER(x,y);x+=40;
    //turn 音符上面一个横的S字， 表示要连续弹奏：本身，低一度音，本身
    ART_TURN(x,y);x+=40;

    
    
    
    REPEAT_SEGNO(x,y);x+=30;
    REPEAT_CODA(x,y);x+=30;
    /*
    TEXT_NUM(x,y,0);x+=20;
    TEXT_NUM(x,y,1);x+=20;
    TEXT_NUM(x,y,2);x+=20;
    TEXT_NUM(x,y,3);x+=20;
    TEXT_NUM(x,y,4);x+=20;
    TEXT_NUM(x,y,5);x+=20;
    TEXT_NUM(x,y,6);x+=20;
    TEXT_NUM(x,y,7);x+=20;
    TEXT_NUM(x,y,8);x+=20;
    TEXT_NUM(x,y,9);x+=20;
*/    
/*
    //Articulation
    x=10;
    y+=100;
    TEXT(x, y-60, 20, @"Articulation");    */
    //all
    x=10;y+=100;
    for (int i=0x21; i<252; i++) {
        if (i==0x83) {
            i=0x8c;
        }else if(i==0x30)
        {
            i=0x3a;
        }else if(i==0x41)
        {
            i=0x43;
        }else if(i==0x45)
        {
            i=0x47;
        }else if(i==0x50)
        {
            i=0x54;
        }else if(i==0x5a)
        {
            i=0x5c;
        }else if(i==0x7f)
        {
            i=0x81;
        }else if(i==0x8e)
        {
            i=0xa0;
        }else if(i==0xca)
        {
            i=0xce;
        }/*else if(i==0x23 || i==0x26 || i==0x3d || i==0x3f || i==0x3d || i==0x44 || i==0x48 || i==0x4b || i==0x52 || i==0x58  || i==0x5d || i==0x60 || i==0x64 || i==0x68 || i==0x72 || i==0xab || i==0xd8 || i==0xe6 || i==0xef)
        {
            i++;
        }*/
        NSString *index=[NSString stringWithFormat:@"%02x:",i];
        NSString *glyph=[NSString stringWithFormat:@"%02x",i];
        TEXT(x, y, 16, index);
        x+=20;
        
        GLYPH_Petrucci(x, y, GLYPH_FONT_SIZE, 0, glyph);
        x+=40;
        if (x>830) {
            x=10;
            y+=80;
        }
    }
    //UIPrintPageRenderer
    [self.staff_images addObject:[self endSvgImage]];
}
- (void)loadMusic:(id)music_handle musicSize:(CGSize)musicSize landPage:(BOOL)landPage {
    landPageMode=landPage;
    [self loadMusic:music_handle musicSize:musicSize screenSize:CGSizeMake(1027, 768)];
}
- (void)loadMusic:(id)music_handle musicSize:(CGSize)musicSize screenSize:(CGSize)screenSize
//- (void)loadMusic:(id)music_handle size:(CGSize)screen
{
    self.music=music_handle;
    screen_size=musicSize;
    real_screen_size=screenSize;
    //screen_size.height=screen.width*self.music.page_height/self.music.page_width;

//    LINE_H=screen.width/100;// 12;
//    if ([[UIDevice currentDevice] userInterfaceIdiom]==UIUserInterfaceIdiomPad) {
//        LINE_H=musicSize.width/120;// 12;
//    }else{
//        LINE_H=musicSize.width/120;//6;
//    }
    LINE_H=musicSize.width/120;//6;
    
    MARGIN_LEFT=LINE_H*4;//3.3;
    MARGIN_RIGHT=LINE_H*3;//2.5;
    MARGIN_TOP=LINE_H*4;//3.3;
    if (LINE_H>10) {
        BARLINE_WIDTH=3;
        BEAM_WIDTH=4;
    }else{
        BARLINE_WIDTH=2;
        BEAM_WIDTH=4;
    }
    
    //[page_view setFrame:CGRectMake(size.width-200, -5, 200, 35)];
    @autoreleasepool {
        if (self.music!=nil)
        {
            [self drawSvgMusic];
        }
    }
}
- (void)beginSvgImage:(CGSize)size
{
    [self beginSvgImage:size startMeasure:0];
}
- (void)beginSvgImage:(CGSize)size startMeasure:(int)startMeasure
{
    //<use xlink:href="Aloisen New.svg"/>
    //NSString *fontfile=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Aloisen New.svg"];
    //NSURL *font_url=[NSURL fileURLWithPath:fontfile];
    /*
    NSString *back;
    BOOL showBackground=![[NSUserDefaults standardUserDefaults] boolForKey:@"kSettingShowBackground"];
    if (showBackground) {
        back=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"background.png"];
    }else{
        back=@"";
    }
    NSURL *back_url=[NSURL fileURLWithPath:back];
     */
#ifdef NEW_PAGE_MODE
#else
    if (size.height/size.width < real_screen_size.height/real_screen_size.width) {
        size.height=size.width*real_screen_size.height/real_screen_size.width;
    }
#endif
    size.height=round(size.height);
    self.staff_size=size;
    self.page_size=CGSizeMake(size.width, size.width*self.music.xml_page_height/self.music.page_width);
    NSString *xml_header=[NSString stringWithFormat:@"<?xml version=\"1.0\" standalone=\"yes\"?>\n"
                          "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n"
                          "<html><head>\n"
                          "<meta name='viewport' content=\"width=device-width, maximum-scale=2.0, minimum-scale=0.1, user-scalable=0\"/>\n"
                          "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n"
//                          "<meta name='viewport' content=\"width=device-width,  height=device-height,  maximum-scale=2.0, minimum-scale=0.1, user-scalable=no\"/>\n"
                          "</head><body "bgColor">\n"
                          "<svg id='svg' width='%dpx' height='%dpx' version='1.1' xmlns='http://www.w3.org/2000/svg'>\n"
                          "<g id=\"myCanvas\"></g>\n",
                          (int)size.width, (int)size.height];//, font_url];
    //"<body bgcolor='#FCFCDC'>\n"
    //"<body background='background.png'>\n"
    //<meta name="viewport" content="width=device-width, initial-scale=1.0 maximum-scale=1, user-scalable=no" />
    //<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no"/>
    
    /*
    NSString *xml_header=[NSString stringWithFormat:@"<?xml version=\"1.0\" standalone=\"no\"?>\n"
    "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n"
    "<svg width='%d' height='%d' version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\">\n", (int)screen_size.width, (int)screen_size.height];
     */
    //简谱
    if (self.showJianpu) {
        self.svgXmlJianpuContent=[[NSMutableString alloc]initWithString:@"<g id='jianpu' style='visibility:hidden'>\n"];
        self.svgXmlJianpuFixDoContent=[[NSMutableString alloc]initWithString:@"<g id='jianpufixdo' style='visibility:hidden'>\n"];
        self.svgXmlJianwpContent=[[NSMutableString alloc]initWithString:@"<g id='jianwp' style='visibility:hidden'>\n"];
        self.svgXmlJianwpFixDoContent=[[NSMutableString alloc]initWithString:@"<g id='jianwpfixdo' style='visibility:hidden'>\n"];
    }
    //五线谱
    self.svgXmlContent=[[NSMutableString alloc]initWithString:xml_header];
    self.svgMeasurePosContent=[[NSMutableString alloc]initWithFormat:@"<script>\n document.documentElement.style.webkitTouchCallout='none'; document.documentElement.style.webkitUserSelect='none'; var meas_start=%d; var meas_pos=[\n",startMeasure];

//    NSString *fontfile=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Aloisen New.svg"];
    NSString *fontfile=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Music Font.svg"];
//    NSURL *font_url=[NSURL fileURLWithPath:fontfile];
    NSString *fontStr=[NSString stringWithContentsOfFile:fontfile encoding:NSUTF8StringEncoding error:nil];
    [self.svgXmlContent appendString:fontStr];

//    [self.svgXmlContent appendFormat:@"<rect x='-10' y='0' width='%d' height='%d' fill='rgb(250,250,240)' />", (int)screen_size.width+20, (int)screen_size.height ];
#ifdef NEW_PAGE_MODE
    [self drawPageBackground:screen_size];
#else
    [self.svgXmlContent appendString:@"<g id=\"tempgroup\"></g>"];
#endif
    for (int i=0; i<self.music.trackes.count*5; i++) {
        [self.svgXmlContent appendFormat:@"<rect id='cursor%d'></rect>", i];
    }
    [self.svgXmlContent appendString:@"<rect id='progressBar'></rect>"];
    [self.svgXmlContent appendString:@"<rect id='playloopA'></rect>"];
    [self.svgXmlContent appendString:@"<rect id='playloopB'></rect>"];
//    NSString *font_path=[[NSBundle mainBundle] pathForResource:@"Aloisen New" ofType:@"svg"];
//    [self.svgXmlContent appendString:[NSString stringWithContentsOfFile:font_path encoding:NSUTF8StringEncoding error:nil]];
}
- (NSString *)endSvgImage
{
    if (self.showJianpu) {
        //简谱
        [self.svgXmlJianpuContent appendString:@"</g>\n"];
        [self.svgXmlContent appendString:self.svgXmlJianpuContent];
        self.svgXmlJianpuContent=nil;
        //固定调简谱
        [self.svgXmlJianpuFixDoContent appendString:@"</g>\n"];
        [self.svgXmlContent appendString:self.svgXmlJianpuFixDoContent];
        self.svgXmlJianpuFixDoContent=nil;
        
        //简五谱
        [self.svgXmlJianwpContent appendString:@"</g>\n"];
        [self.svgXmlContent appendString:self.svgXmlJianwpContent];
        self.svgXmlJianwpContent=nil;
        //固定调简五谱
        [self.svgXmlJianwpFixDoContent appendString:@"</g>\n"];
        [self.svgXmlContent appendString:self.svgXmlJianwpFixDoContent];
        self.svgXmlJianwpFixDoContent=nil;
    }
    [self.svgXmlContent appendString:@"</svg>"];
    //FEFBEB 浅黄色
    //fefefe 浅灰色
    [self.svgXmlContent appendString:@"\
     <div id='addcomment' style='border:none; width:280px;position:absolute;visibility:hidden;background:none'>\n\
     <button id='commentA' style='width:130px;height:30px;background:#FEFBEB;color:#27ae60;font-size:medium'>文字点评</button>\n\
     </div>\n\
     \n\
     <div id='popview' style='border:none; width:280px;position:absolute;visibility:hidden;background:none'>\n\
     <button id='loopA' style='width:80px;height:30px;background:#FEFBEB;color:#27ae60;font-size:medium'>起始||:</button>\n\
     <button id='loopB' style='width:80px;height:30px;background:#FEFBEB;color:#c0392b;font-size:medium'>:||结束</button>\n\
     <button id='loopCancel' onclick='cancelLoopAB()' style='width:70px;height:30px;background:#FEFBEB;font-size:medium'>取消</button>\n\
    </div>\n"];
    //meas_pos,svgMeasurePosContent
    [self.svgXmlContent appendString:self.svgMeasurePosContent];
    [self.svgXmlContent appendString:@"</script>\n"];
//    [self.svgXmlContent appendString:@"<script type=\"text/javascript\" src=\"script.js\"></script>\n"];
    NSString *script_file = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"script.js"];
    NSString *script=[NSString stringWithContentsOfFile:script_file encoding:NSUTF8StringEncoding error:nil];
    [self.svgXmlContent appendFormat:@"<script>%@</script>\n",script];

    //end
    [self.svgXmlContent appendString:@"</body></html>\n"];

#if 0 //debug
    NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:@"test.svg"];
    [self.svgXmlContent writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
#endif
    //SVGKImage *svgImg=[SVGKImage imageWithContentsOfFile:path];
    return self.svgXmlContent;
}
- (void)beginSvgPage:(CGSize)size page:(int)page {
    if (landPageMode) {
        [self.svgXmlContent appendFormat:@"<g transform =\"translate(%.1f,0)\">\n",size.width*page];
    }else {
        [self.svgXmlContent appendFormat:@"<g transform =\"translate(0, %.1f)\">\n",size.height*page];
    }
}
- (void)drawPageBackground:(CGSize)size{
#define BACK_LEFT_MARGIN 20.0
#define BACK_RIGHT_MARGIN 20.0
#define BACK_TOP_MARGIN 8.0
#define BACK_BOTTOM_MARGIN 8.0
    
    for (int page=0; page<self.music.pages.count; page++) {
        
        float x,y;
        
        if (landPageMode) {
            x=size.width*page;
            y=0;
        }else{
            x=0;
            y=size.height*page;
        }
        
        CGRect rect=CGRectMake(x+BACK_LEFT_MARGIN, y+BACK_TOP_MARGIN, size.width-BACK_LEFT_MARGIN-BACK_RIGHT_MARGIN, size.height-BACK_TOP_MARGIN-BACK_BOTTOM_MARGIN);
        NSString *ret=[NSString stringWithFormat:@"<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' fill='%@' stroke='%@' />\n", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height, paperColor,@"#aaa"];
        [self.svgXmlContent appendString:ret];
        
        LINE_C(x+BACK_LEFT_MARGIN, y+size.height-BACK_BOTTOM_MARGIN+1, x+size.width-BACK_RIGHT_MARGIN+1, y+size.height-BACK_BOTTOM_MARGIN+1, @"#000", 2);
        LINE_C(x+size.width-BACK_RIGHT_MARGIN+1, y+BACK_TOP_MARGIN, x+size.width-BACK_RIGHT_MARGIN, y+size.height-BACK_BOTTOM_MARGIN+1, @"#000", 2);
        
        NSString *str=[NSString stringWithFormat:@"%d.",page+1];
        TEXT(rect.origin.x+10, y+size.height-30, 16, str);
    }
}
- (void)beginSvgLine:(int)line_num x:(float)x y:(float)y {
    [self.svgXmlContent appendFormat:@"<g id='line_%d' transform =\"translate(0, %.1f)\">\n",line_num,y];
//    if (line_num<10) {
//        [self.svgXmlContent appendFormat:@"<g id='line_%d' transform =\"translate(0, %.1f)\">\n",line_num,y];
//    }else{
//        [self.svgXmlContent appendFormat:@"<g id='line_%d' transform =\"translate(0, %.1f)\" style='visibility:hidden;'>\n",line_num,y];
//    }
}
- (void)endSvgLine {
    [self.svgXmlContent appendString:@"</g>\n"];
}

- (void)endSvgPage{
    [self.svgXmlContent appendString:@"</g>\n"];
}

- (void)drawJianpu: (OveMeasure *)measure start_x:(int)jianpu_start_x start_y:(int)start_y
{
    int jianpu_steps[]={
        0,-4,-1,-5,-2,1,-3,
        0,
        -4,-1,-5,-2,1,-3,0};
    for (int dd=0;dd<measure.sorted_duration_offset.count;dd++) {
        id key = [measure.sorted_duration_offset objectAtIndex:dd];
        NSArray* notes=[measure.sorted_notes objectForKey:key];
        notes=[notes sortedArrayUsingComparator:^NSComparisonResult(OveNote *obj1, OveNote *obj2) {
            NSComparisonResult ret;
            ret=obj1.note_type<obj2.note_type;
            //ret=obj1.note_elems.count>obj2.note_elems.count;
            return ret;
        }];
#define MAX_STAFF 20
        int offset_y[MAX_STAFF]={0,0,0,0,0, 0,0,0,0,0};
        
        for (int note_nn=0;note_nn<notes.count;note_nn++)
        {
            OveNote *note = [notes objectAtIndex:note_nn];
            float note_x = jianpu_start_x+MEAS_LEFT_MARGIN+note.pos.start_offset*OFFSET_X_UNIT;;
            for (int elem_nn=0; elem_nn<note.sorted_note_elems.count || elem_nn<1; elem_nn++) {
                if (note.staff<1 || note.staff>STAFF_COUNT) {
                    //NSLog(@"wrong staff=%d in measure(%d) tick(%@)", note.staff, measure.number, key);
                    continue;
                }
                int font_size=JIANPU_FONT_SIZE+1-(int)note.sorted_note_elems.count/2;
                int jianpu_y=start_y-3*LINE_H+STAFF_OFFSET[note.staff-1]+offset_y[note.staff-1];
                if (note.isRest) {
                    int rest_number=1;
                    if (note.note_type==Note_Half) {
                        rest_number=2;
                        if (note.isDot) {
                            rest_number=3;
                        }
                    }else if (note.note_type==Note_Whole)
                    {
                        rest_number=4;
                    }
                    int tmp_x=note_x-JIANPU_FONT_SIZE/12;
                    for (int count=0; count<rest_number; count++) {
                        TEXT_JIANPU(tmp_x, jianpu_y-JIANPU_FONT_SIZE/6, @"0", @"0", JIANPU_FONT_SIZE);
                        tmp_x+=measure.meas_length_size*OFFSET_X_UNIT/4;
                    }
                }else{
                    //NoteElem *note_elem=[note.sorted_note_elems objectAtIndex:elem_nn];
                    if (note.sorted_note_elems==nil) {
                        note.sorted_note_elems=note.note_elems;
                    }
                    NoteElem *note_elem=[note.sorted_note_elems objectAtIndex:note.sorted_note_elems.count-elem_nn-1];
                    if (last_fifths>=-7 && last_fifths<=7)
                    {
                        //  C  | bD  |  D  | bE  |  bF |  F  | bG  |  G  | bA  |  A  | bB  | bC
                        //  C  | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
                        //  1           2           3     4           5           6          7
                        int jiappu_step_index=(note_elem.xml_pitch_step+6+jianpu_steps[last_fifths+7]);
                        int step=jiappu_step_index%7+1;//1-7
                        int octave=note_elem.xml_pitch_octave+jiappu_step_index/7-1; //0-9
                        
                        if (step>0 && step<=7)
                        {
                            //number
                            NSString *num=[NSString stringWithFormat:@"%d", step];
                            NSString *numFixDo=[NSString stringWithFormat:@"%d", note_elem.xml_pitch_step];
                            if (note.isGrace) {
                                font_size=JIANPU_FONT_SIZE*0.7;
                            }
                            if (elem_nn>0) {
                                font_size-=5;
                            }
                            TEXT_JIANPU(note_x-font_size/12, jianpu_y-font_size/6, num, numFixDo, font_size);
                            //Jian Wupu
                            float jianwp_y=start_y + [self lineToY:note_elem.line staff:note.staff+note_elem.offsetStaff];
                            float jianwp_x=note_x;
                            int jianwp_font_size=1.2*LINE_H;
                            if (note.note_type>Note_Half) {
                                //BACK_JIANWP(note_x, note_y, 12*LINE_H/10, @"#1F1F1F");
                                if (note.isGrace) {
                                    jianwp_font_size*=0.6;
                                    jianwp_x-=LINE_H*0.2;
                                    jianwp_y-=LINE_H*0.2;
                                }
                                TEXT_JIANWP(jianwp_x, jianwp_y, num, numFixDo, jianwp_font_size, @"#FFFFFF");
                            }else{
                                if (note.note_type==Note_Whole) {
                                    jianwp_x=note_x+LINE_H*0.2;
                                }
                                BACK_JIANWP(jianwp_x, jianwp_y, 0.46*LINE_H, @"#FFFFFF");
                                TEXT_JIANWP(jianwp_x, jianwp_y, num, numFixDo, jianwp_font_size, @"#000000");
                            }
                            
                            //sharp/flat
                            if (note_elem.accidental_type==Accidental_Sharp) {
                                SHARP_JIANPU(note_x-0.4*LINE_H, jianpu_y+0.2*font_size);
                            }else if (note_elem.accidental_type==Accidental_Flat) {
                                FLAT_JIANPU(note_x-0.4*LINE_H, jianpu_y+0.2*font_size);
                            }else if (note_elem.xml_pitch_alter==0)
                            {
                                int pitch_step=note_elem.xml_pitch_step;
                                if ((last_fifths==1 && pitch_step==4) || //G major: G A B C D E #F
                                    (last_fifths==2 && (pitch_step==1||pitch_step==4)) ||   //D major: D E #F G A B #C
                                    (last_fifths==3 && (pitch_step==1||pitch_step==4||pitch_step==5)) ||   //A major: A B #C D E #F #G
                                    (last_fifths==4 && (pitch_step!=3&&pitch_step!=6&&pitch_step!=7)) ||   //E major: E #F #G A B #C #D
                                    (last_fifths==5 && (pitch_step!=3&&pitch_step!=7)) ||   //B major: B #C #D E #F #G #A
                                    (last_fifths==6 && (pitch_step!=7)) ||   //F# major: #F #G #A B #C #D #E
                                    (last_fifths==7)    //C# major: #C #D #E #F #G #A #B
                                    )
                                {
                                    FLAT_JIANPU(note_x-0.4*LINE_H, jianpu_y+0.2*font_size);
                                }else if ((last_fifths==-7) || //Cb major: bC bD bE bF bG bA bB
                                          (last_fifths==-6 && pitch_step!=4) || //Gb major: bG bA bB bC bD bE F
                                          (last_fifths==-5 && pitch_step!=4 && pitch_step!=1) ||     //Db major: bD bE F bG bA bB C
                                          (last_fifths==-4 && pitch_step!=4 && pitch_step!=1 && pitch_step!=5) ||    //Ab major: bA bB C bD bE F G
                                          (last_fifths==-3 && (pitch_step==3 || pitch_step==6 || pitch_step==7)) ||    //Eb major: bE F G bA bB C D
                                          (last_fifths==-2 && (pitch_step==3 || pitch_step==7)) ||    //Bb major: bB C D eE F G A
                                          (last_fifths==-1 && (pitch_step==7))     //F major: F G A bB C D E
                                          )
                                {
                                    SHARP_JIANPU(note_x-0.4*LINE_H, jianpu_y+0.2*font_size);
                                }
                            }
                            //above dot
                            if (octave>4) {
                                for (int dots=5; dots<=octave; dots++) {
                                    if (note.isGrace)
                                    {
                                        DOT_JIANPU(note_x+1, jianpu_y+1.5*font_size-6*dots);
                                    }else{
                                        //DOT_JIANPU(note_x+1.5, jianpu_y+1.1*font_size-6*dots);
                                        DOT_JIANPU(note_x+1.5, jianpu_y+2+JIANPU_FONT_SIZE-6*dots);
                                    }
                                }
                                //if (!note.isGrace)offset_y[note.staff-1]-=2*(octave-6);
                            }
                            
                            //below dot
                            if (octave<4) {
                                int dot_y=jianpu_y;
                                //跳过beam线
                                if (elem_nn==0 && note.note_type>Note_Quarter && note.note_type<Note_None) {
                                    dot_y+=(note.note_type-Note_Quarter)*4;
                                }
                                for (int dots=3; dots>=octave; dots--) {
                                    DOT_JIANPU(note_x+1.5, dot_y+font_size+17-5*dots);
                                    offset_y[note.staff-1]-=2;
                                }
                                //if (!note.isGrace)offset_y[note.staff-1]-=2*(2-octave);
                            }
                        }
                    }
                }//end if (isRest)
                //doted
                if (note.note_type>=Note_Quarter && note.isDot>0) {
                    for (int count=1; count<=note.isDot; count++) {
                        DOT_JIANPU(note_x+count*0.4*font_size, jianpu_y+0.5*font_size);
                    }
                }
                //beam
                if (elem_nn==0) {
                    int beam_y=jianpu_y+font_size;
                    
                    if (note.note_type>Note_Quarter)// && note.note_type<Note_None)
                    {
                        int beams=note.note_type-Note_Quarter;
                        
                        if (note.note_type>=Note_None) {
                            if (note.inBeam) {
                                beams=1;
                            }
                        }
                        for (int count=0; count<beams; count++) {
                            LINE_JIANPU(note_x-0.1*font_size, note_x+0.4*font_size, beam_y+count*4,1);
                        }
                        //if (!note.isGrace)offset_y[note.staff-1]-=1*beams;
                    }else if (note.note_type==Note_Half && !note.isRest){
                        int tmp_x=note_x;
                        tmp_x+=measure.meas_length_size*OFFSET_X_UNIT/4;
                        LINE_JIANPU(tmp_x, tmp_x+0.4*font_size, beam_y-0.5*font_size,2);
                        if (note.isDot) {
                            tmp_x+=measure.meas_length_size*OFFSET_X_UNIT/4;
                            LINE_JIANPU(tmp_x, tmp_x+0.4*font_size, beam_y-0.5*font_size,2);
                            if (note.isDot>1) {
                                DOT_JIANPU(tmp_x + 0.8*font_size, jianpu_y+0.5*font_size);
                            }
                        }
                    }else if (note.note_type==Note_Whole && !note.isRest){
                        int tmp_x=note_x;
                        for (int count=0; count<3; count++) {
                            tmp_x+=measure.meas_length_size*OFFSET_X_UNIT/4;
                            LINE_JIANPU(tmp_x, tmp_x+0.4*font_size, beam_y-0.5*font_size,2);
                        }
                    }
                    if (!note.isGrace)offset_y[note.staff-1]+=font_size*0.1;
                }//end if (elem_nn==0)
                if (!note.isGrace)offset_y[note.staff-1]-=font_size+0;
            }
            if (!note.isGrace)offset_y[note.staff-1]-=JIANPU_FONT_SIZE*0.5;
        }
    }
}

-(void)drawSvgTempo:(OveMeasure*)first_measure start_x:(float)start_x start_y:(float)start_y {
    
    if (first_measure.tempos && first_measure.tempos.count>0) {
        if (start_denominator==0) {
            start_numerator=first_measure.numerator;
            start_denominator=first_measure.denominator;
        }
        
        Tempo *tempo=first_measure.tempos.firstObject;
        float tempo_x=start_x;//+3*LINE_H;//+STAFF_HEADER_WIDTH;
        float tempo_y;
        if (tempo.offset_y) {
            tempo_y=start_y+tempo.offset_y*OFFSET_Y_UNIT;
        }else{
            tempo_y=start_y-LINE_H*2;
        }
        if (tempo.tempo_left_text) {
            CGSize tempo_size;
#if TARGET_OS_IPHONE
            tempo_size=[tempo.tempo_left_text sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:tempo.font_size]}];
#else
            tempo_size=[tempo.tempo_left_text sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:tempo.font_size]}];
#endif
            //CGSize tempo_size=[tempo.tempo_left_text sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:tempo.font_size]}];
            TEXT_ATTR(tempo_x, tempo_y-tempo_size.height, tempo.font_size, tempo.tempo_left_text,YES,NO);
            
            tempo_x+=tempo_size.width+1.5*LINE_H;
            tempo_y-=LINE_H;
        }
        //UIImage *img;
        unsigned char left_note_type=tempo.left_note_type&0x0F;
        start_tempo_num=tempo.tempo+tempo.tempo_range/2;
        start_tempo_type=1.0/4.0;
        
        switch (left_note_type) {
            case 1: //全音符
                //tmp=ELEM_NOTE_FULL;
                NOTE_FULL(tempo_x, tempo_y, 1);
                start_tempo_type=1;
                //start_tempo*=4;
                break;
            case 2://二分音符
                //tmp=ELEM_NOTE_2_UP;
                NOTE_2_UP(tempo_x, tempo_y, 1);
                start_tempo_type=1.0/2;
                //start_tempo*=2;
                break;
            case 3://四分音符
                NOTE_4_UP(tempo_x, tempo_y, 1);
                start_tempo_type=1.0/4;
                break;
            case 4://八分音符
                NOTE_8_UP(tempo_x, tempo_y, 1);
                start_tempo_type=1.0/8;
                //start_tempo/=2;
                break;
            case 5://16分音符
                NOTE_16_UP(tempo_x, tempo_y, 1);
                start_tempo_type=1.0/16;
                //start_tempo/=4;
                break;
            case 6://32分音符
                NOTE_32_UP(tempo_x, tempo_y, 1);
                start_tempo_type=1.0/32;
                //start_tempo/=8;
                break;
            case 7://64分音符
                NOTE_64_UP(tempo_x, tempo_y, 1);
                start_tempo_type=1.0/64;
                //start_tempo/=16;
                break;
            default:
                NSLog(@"Error: unknow note_type=%d", left_note_type);
                break;
        }
        NSString *tmp;
        if ((tempo.left_note_type&0x30)==0x20) {
            tmp = @". =";
            start_tempo_type*=1.5;
            //start_tempo*=1.5;
        }else{
            tmp = @"=";
        }
        if (tempo.tempo_range==0) {
            tmp = [tmp stringByAppendingFormat:@"%d", tempo.tempo];
        }else{
            tmp = [tmp stringByAppendingFormat:@"(%d-%d)", tempo.tempo, tempo.tempo+tempo.tempo_range];
        }
        TEXT(tempo_x+LINE_H*1.5, tempo_y-LINE_H*2, 2.5*LINE_H, tmp);
        //[tmp drawAtPoint:CGPointMake(tempo_x+LINE_H*4.5, start_y-LINE_H*5) withFont:[UIFont systemFontOfSize:20]];
    }else{
        //http://zh.wikipedia.org/wiki/%E9%80%9F%E5%BA%A6_(%E9%9F%B3%E6%A8%82)
        NSDictionary *times=@{
                              //Larghissimo － 极端地缓慢（40 bpm 或以下）
                              //Lentissimo － 比缓板更慢
                              //Largo － 最缓板（现代）或广板
                              //Lento － 缓板（40 - 60 bpm）
                              //Larghetto － 甚缓板（60 - 66 bpm）
                              //Grave － 沈重的、严肃的
                              //Adagio － 柔板 ／ 慢板（66 - 76 bpm）
                              //Adagietto － 颇慢
                              //Andante － 行板（76 - 108 bpm）
                              //Andantino － 比行板稍快或稍慢，视乎不同时代作曲家有不同意义
                              @"Larghissimo": @(35),// － 极端地缓慢（40 bpm 或以下）
                              @"Lentissimo": @(38),// － 比缓板更慢
                              @"Grave": @(40), //壮板     ->最慢    沈重的、严肃的
                              @"Largo": @(44), //广板     ->很慢    最缓板（现代）或广板
                              @"Lento": @(52), //慢板     ->很慢    缓板（40 - 60 bpm）
                              @"Adagio": @(56), //柔板    ->慢速    柔板 ／ 慢板（66 - 76 bpm）
                              @"Larghetto": @(60), //小广板    ->稍慢    甚缓板（60 - 66 bpm）
                              @"Cantabile": @(60), //如歌
                              @"Adagietto":@(65), //颇慢
                              @"Andante": @(66), //行板      ->行走速度或人的脉搏速度 行板（76 - 108 bpm）
                              @"Andantino": @(69), //小行板  ->行走速度或人的脉搏速度
                              @"Moderato": @(88), //中板     ->中速或人的脉搏速度
                              @"Moderato Scherzando": @(88), //中板     ->中速或人的脉搏速度 中板（90 - 115 bpm）
                              @"Allegro moderato": @(98), //中庸的快板  适度、愉快的急速
                              @"Allegretto": @(108), //小快板  ->稍快
                              @"Allegro": @(120), //快板      ->快速  快板（120 - 168 bpm）
                              @"Allegro con allegrezza": @(120), // 欢乐的快板
                              @"Allegro assai":@(130),
                              @"Allegro vivace": @(134), //活泼的快板快板
                              @"Vivace": @(140), //速板       ->很快  活泼（~140 bpm）
                              @"Vivo": @(152), //速板         ->很快
                              @"Presto": @(170), //急板       ->急速 （168 - 200 bpm）
                              @"Allegrissimo": @(191),
                              @"Vivacissimo": @(198),
                              @"Prestissimo": @(204), //最极板  ->最快 (约为200 - 208 bpm）
                              };
        BOOL found_expresssion=NO;
        for (MeasureExpressions *exp in first_measure.expresssions) {
            NSString *str=[exp.exp_text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSNumber *num=[times objectForKey:str];
            if (num!=nil) {
                start_tempo_num=[num intValue];
                start_tempo_type=1.0/4;
                found_expresssion=YES;
                break;
            }
        }
        if (!found_expresssion) {
            for (OveText *text in first_measure.meas_texts) {
                NSString *str=[text.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSNumber *num=[times objectForKey:str];
                if (num!=nil) {
                    start_tempo_num=[num intValue];
                    start_tempo_type=1.0/4;
                    break;
                }
            }
        }
    }
}

- (void)drawSvgFiveLine:(OveLine *)line start_x:(float)start_x start_y:(float)start_y
{
    for (int nn=0; nn<STAFF_COUNT; nn++)
    {
        LineStaff* tmp_staff=[line.staves objectAtIndex:nn];
//        STAFF_OFFSET[nn]=tmp_staff.y_offset*OFFSET_Y_UNIT;
//        if (nn>0)
//        {
//            STAFF_OFFSET[nn]+=STAFF_OFFSET[nn-1];
//        }
        if (tmp_staff.hide) {
            continue;
        }
        //track name
        /*
         if (nn<self.music.trackes.count) {
         OveTrack *track=[self.music.trackes objectAtIndex:nn];
         if (line_num==0 && page.begin_line==0) {
         if (track.track_name && track.track_name.length>0) {
         TEXT(MARGIN_LEFT, start_y+STAFF_OFFSET[nn]+1*LINE_H, NORMAL_FONT_SIZE, track.track_name);
         }
         }else{
         if (track.track_brief_name && track.track_brief_name.length>0) {
         TEXT(MARGIN_LEFT, start_y+STAFF_OFFSET[nn]+1*LINE_H, NORMAL_FONT_SIZE, track.track_brief_name);
         }
         }
         }*/
        
        //谱号
        if (tmp_staff.clef==Clef_Treble) { //treble clef
            CLEF_TREBLE(start_x+LINE_H*0.5, start_y+STAFF_OFFSET[nn]+3*LINE_H,1);
        }else if (tmp_staff.clef==Clef_Bass){ //base clef
            CLEF_BASS(start_x+LINE_H*0.5, start_y+STAFF_OFFSET[nn]+LINE_H*1,1);
        }else if (tmp_staff.clef==Clef_TAB){ //TAB clef
            TEXT(start_x+5, start_y+STAFF_OFFSET[nn]-0.5*LINE_H, 2*LINE_H, @"T");
            TEXT(start_x+5, start_y+STAFF_OFFSET[nn]+1.0*LINE_H, 2*LINE_H, @"A");
            TEXT(start_x+5, start_y+STAFF_OFFSET[nn]+2.7*LINE_H, 2*LINE_H, @"B");
        }else if (tmp_staff.clef==Clef_Percussion1){
            CLEF_Percussion1(start_x+LINE_H*1.5, start_y+STAFF_OFFSET[nn]+LINE_H*2,1);
        }else{
            NSLog(@"Error unknow clef=%d at staff=%d", tmp_staff.clef, nn);
        }
        //调号:升降号
        STAFF_HEADER_WIDTH = 5*LINE_H + 0.9*LINE_H* abs(line.fifths);
        last_fifths=line.fifths;
        [self drawSvgDiaohaoWithClef:tmp_staff.clef fifths:line.fifths x:start_x+0 startY:start_y+STAFF_OFFSET[nn] stop:NO];
        //画五线
        int staff_line_count=5;
        if(tmp_staff.clef==Clef_TAB) staff_line_count=6;
        for (int staff_line=0; staff_line<staff_line_count; staff_line++) {
            LINE(start_x, start_y+STAFF_OFFSET[nn]+LINE_H*staff_line, screen_size.width-MARGIN_RIGHT,start_y+STAFF_OFFSET[nn]+LINE_H*staff_line);
        }
    }
}

#if 1
- (void)drawSvgMusic
{
    self.minNoteValue=127;
    self.maxNoteValue=0;
    
    //NSLog(@"Start draw music");
    for (int i=0; i<SLUR_CONTINUE_NUM; i++) {
        //slur_continue_pos[i]=CGRectMake(0, 0, 0, 0);
        slur_continue_info[i].validate=NO;
    }
    [self.measure_pos removeAllObjects];
    
    if (self.music.pages.count==0) {
        return;
    }
    OvePage *page=self.music.pages[0];
    if (page==nil) {
        return;
    }
    //OFFSET_Y_UNIT = (size.height)/page.page_height;
    OFFSET_Y_UNIT = (screen_size.height)/(self.music.page_height);
    MARGIN_TOP = self.music.page_top_margin*OFFSET_Y_UNIT;
    
    if (self.music.version==4) {
        GROUP_STAFF_NEXT=page.staff_distance*OFFSET_Y_UNIT;///24.0;//同一组内谱表间距
    }else{
        GROUP_STAFF_NEXT=page.staff_distance*OFFSET_Y_UNIT;///14.0; //同一组内谱表间距
    }
    
    unsigned char last_denominator=0;
    unsigned char last_numerator=0;
    
#ifdef NEW_PAGE_MODE
    if (landPageMode) {
        self.music.page_left_margin=200;
        self.music.page_right_margin=200;
        [self beginSvgImage:CGSizeMake(screen_size.width*self.music.pages.count, screen_size.height)];
    }else{
        [self beginSvgImage:CGSizeMake(screen_size.width, screen_size.height*self.music.pages.count)];
    }
#else
    if (!self.pageMode) {
        [self beginSvgImage:CGSizeMake(screen_size.width, screen_size.height*self.music.pages.count)];
    }
#endif
    
    for (int page_num=0; page_num<self.music.pages.count; page_num++) {
        OvePage *page=[self.music.pages objectAtIndex:page_num];

#ifdef NEW_PAGE_MODE
        [self beginSvgPage:screen_size page:page_num];
#else
        if (self.pageMode) {
            OveLine *line=[self.music.lines objectAtIndex:page.begin_line];
            [self beginSvgImage:screen_size startMeasure:line.begin_bar];
        }
#endif

        //显示标题
//        if ([self.staff_images count]==0)
        if (page_num==0)
        {
            [self drawSvgTitle];
        }
        //画本页内所有行
        if (self.showJianpu) {//简谱覆盖的边框
            RECT_JIANPU(MARGIN_LEFT, MARGIN_TOP, screen_size.width-MARGIN_RIGHT-MARGIN_LEFT, screen_size.height-MARGIN_TOP);
        }
        //float start_y=MARGIN_TOP+self.music.page_top_margin*OFFSET_Y_UNIT;
        for (int line_num=0; line_num<page.line_count; line_num++) {
            OveLine *line=[self.music.lines objectAtIndex:line_num+page.begin_line];
            float start_x=MARGIN_LEFT;
            float start_y=line.y_offset*OFFSET_Y_UNIT+MARGIN_TOP;// + page_num*size.height;
            
#ifdef NEW_PAGE_MODE
#else
            if (!self.pageMode) {
                start_y+=page_num*screen_size.height;
            }
#endif
            
            float line_y=start_y;
//            [self beginSvgLine:line_num x:0 y:line_y];
//            start_y=0;
            
            if (line_num>0) {
            //    start_y+=page.system_distance*OFFSET_Y_UNIT + (line.staves.count-1)*page.staff_distance*OFFSET_Y_UNIT+LINE_H*4*line.staves.count;
            }
            if (line.begin_bar>=self.music.measures.count) {
                break;
            }
            OveMeasure *first_measure=[self.music.measures objectAtIndex:line.begin_bar];
            STAFF_COUNT=line.staves.count;
            //画五线背景
            float max_track_name_width=0;
            if (STAFF_COUNT>0) {
                //计算track name的最大长度
                {
                    for (int nn=0; nn<STAFF_COUNT && nn<self.music.trackes.count; nn++)
                    {
                        OveTrack *track=[self.music.trackes objectAtIndex:nn];
                        if (track.track_name && track.track_name.length>0) {
                            NSString *name=track.track_brief_name;
                            if (line_num==0 && page_num==0) {
                                name=track.track_name;
                            }
                            //CGSize track_name_size=CGSizeMake(20*track.track_name.length, 20);
#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
                            //CGSize track_name_size=[name sizeWithFont:[UIFont systemFontOfSize:NORMAL_FONT_SIZE]];
                            CGSize track_name_size=[name sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:NORMAL_FONT_SIZE]}];
#else
                            CGSize track_name_size = [name sizeWithAttributes: [NSDictionary dictionaryWithObject: [NSFont systemFontOfSize:NORMAL_FONT_SIZE] forKey: NSFontAttributeName]];
#endif
                            if (track_name_size.width>max_track_name_width) {
                                max_track_name_width=track_name_size.width;
                            }
                        }
                    }
                    start_x=max_track_name_width+MARGIN_LEFT;
                }
                for (int nn=0; nn<STAFF_COUNT; nn++)
                {
                    LineStaff* tmp_staff=[line.staves objectAtIndex:nn];
                    STAFF_OFFSET[nn]=tmp_staff.y_offset*OFFSET_Y_UNIT;
                    if (nn>0) {
                        STAFF_OFFSET[nn]+=STAFF_OFFSET[nn-1];
                    }
                }
                [self drawSvgFiveLine:line start_x:start_x start_y:start_y];
                //每一行开头的几分之几拍
//                if (!((first_measure.denominator==last_denominator) && (first_measure.numerator==last_numerator)))
                if (first_measure.denominator!=last_denominator || first_measure.numerator!=last_numerator)
                {
                    STAFF_HEADER_WIDTH += 3*LINE_H;
                    [self drawSvgTimeSignature:first_measure start_x:start_x+STAFF_HEADER_WIDTH-MEAS_LEFT_MARGIN start_y:start_y staff_count:STAFF_COUNT];
                    last_denominator=first_measure.denominator;
                    last_numerator=first_measure.numerator;
                }
                
                if (start_denominator==0 && first_measure.denominator>0) {
                    start_numerator=first_measure.numerator;
                    start_denominator=first_measure.denominator;
                }
                //大括号
                for (int i=0; i<line.staves.count; i++) {
                    LineStaff* tmp_staff=line.staves[i];
                    if (tmp_staff.hide) {
                        continue;
                    }
                    int last_staff_lines=5;
                    if (tmp_staff.clef==Clef_TAB) {
                        last_staff_lines=6;
                    }
                    int track_name_y=start_y+STAFF_OFFSET[i]+1*LINE_H;
                    if (tmp_staff.group_staff_count>0) {
                        //LineStaff *end_staff=[line.staves objectAtIndex:STAFF_COUNT-1];
                        NSUInteger end_staff_index=i+tmp_staff.group_staff_count;
                        if (end_staff_index>STAFF_COUNT) {
                            end_staff_index=STAFF_COUNT;
                        }
                        float group_start=STAFF_OFFSET[i];
                        float group_end=LINE_H*(last_staff_lines-1)+STAFF_OFFSET[end_staff_index]+2;

                        int group_size=(group_end-group_start)*3;// 0.3;
                        //GROUP(start_x-group_size/4, start_y+group_end, group_size);
                        if (line.staves.count>2) {
                            GROUP(start_x-2*LINE_H, start_y+group_end, group_size);
                        }else{
                            GROUP(start_x-LINE_H, start_y+group_end, group_size);
                        }

                        track_name_y+=(group_end-group_start)*0.5-NORMAL_FONT_SIZE;
                    }
                    //track name
                    if (i<self.music.trackes.count) {
                        OveTrack *track=[self.music.trackes objectAtIndex:i];
                        if (line_num==0 && page.begin_line==0) {
                            if (track.track_name && track.track_name.length>0) {
#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
                                //CGSize track_name_size=[track.track_name sizeWithFont:[UIFont systemFontOfSize:NORMAL_FONT_SIZE]];
                                CGSize track_name_size=[track.track_name sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:NORMAL_FONT_SIZE]}];
#else
                                CGSize track_name_size = [track.track_name sizeWithAttributes: [NSDictionary dictionaryWithObject: [NSFont systemFontOfSize:NORMAL_FONT_SIZE] forKey: NSFontAttributeName]];
#endif
                                TEXT(start_x-track_name_size.width-MEAS_LEFT_MARGIN, track_name_y, NORMAL_FONT_SIZE, track.track_name);
                            }
                        }else{
                            if (track.track_brief_name && track.track_brief_name.length>0) {
                                TEXT(MARGIN_LEFT, track_name_y, NORMAL_FONT_SIZE, track.track_brief_name);
                            }
                        }
                    }
                }
                
                //开头的barline
                if (STAFF_COUNT>0)
                {
                    int last_staff_lines=5;
                    LineStaff *last_staff=[line.staves objectAtIndex:STAFF_COUNT-1];
                    if (last_staff.clef==Clef_TAB) {
                        last_staff_lines=6;
                    }
                    LINE(start_x, start_y, start_x, start_y+STAFF_OFFSET[STAFF_COUNT-1]+(last_staff_lines-1)*LINE_H);
                    //LINE_W(size.width-MARGIN_RIGHT, start_y, size.width-MARGIN_RIGHT, start_y+STAFF_OFFSET[STAFF_COUNT-1]+(last_staff_lines-1)*LINE_H, 1);
                }
                
                //小节编号
                //[[NSString stringWithFormat:@"%d",first_measure.number+1] drawAtPoint:CGPointMake(start_x, start_y-LINE_H*4) withFont:[UIFont systemFontOfSize:16]];
//                NSString *tmp=[NSString stringWithFormat:@"%d",first_measure.number+1];
                if (first_measure.show_number>0) {
                    NSString *tmp=[NSString stringWithFormat:@"%d",first_measure.show_number];
                    //NSLog(@"measure=%@", tmp);
                    TEXT(start_x, start_y-LINE_H*4, NORMAL_FONT_SIZE, tmp);
                }
            }
            
            if (line_num<page.line_count-1) {
                OveLine *next_line=[self.music.lines objectAtIndex:line_num+page.begin_line+1];
                GROUP_STAFF_NEXT=((next_line.y_offset-line.y_offset)*OFFSET_Y_UNIT-STAFF_OFFSET[STAFF_COUNT-1])/LINE_H-4;
            }

//            unsigned char last_numerator=0, last_denominator=0;
            //计算 OFFSET_X_UNIT
            {
                int total_size=0;
                int diaohao_change=0;
                for (int nn=0; nn<line.bar_count && nn+line.begin_bar<self.music.measures.count; nn++) {
                    OveMeasure *tmp_measure=[self.music.measures objectAtIndex:line.begin_bar+nn];
                    total_size+= tmp_measure.meas_length_size;// [tmp_measure display_durations];
                    if (tmp_measure.key && nn>0) {
                        diaohao_change+=LINE_H*0.9*(1+abs(tmp_measure.key.key));
                    }
                    if (nn>0 && (tmp_measure.numerator!=last_numerator || tmp_measure.denominator!=last_denominator))
                    {
                        diaohao_change+=LINE_H;
                    }
                    last_numerator=tmp_measure.numerator;
                    last_denominator=tmp_measure.denominator;
                }
                float len=(screen_size.width-(start_x+STAFF_HEADER_WIDTH+MARGIN_RIGHT+(MEAS_LEFT_MARGIN+MEAS_RIGHT_MARGIN)*(line.bar_count)))-diaohao_change;
                
                OFFSET_X_UNIT = len / total_size;
            }
            
#if 1
            //画本行所有小节
            float x=start_x+STAFF_HEADER_WIDTH;
            for (int nn=0; nn<line.bar_count && line.begin_bar+nn<self.music.measures.count; nn++)
            {
                OveMeasure *measure = [self.music.measures objectAtIndex:line.begin_bar+nn];
                int key_offset=0;
                if (measure.key) {
                    if (measure.key.key!=0) {
                        key_offset=LINE_H*0.9*(1+abs(measure.key.key));
                    }else{
                        key_offset=LINE_H*0.9*(1+abs(measure.key.previousKey));
                    }
                }
                
                //第一页第一行的速度tempos
                //if (line_num==0 && page_num==0)
                if (measure.tempos.count>0)
                {
                    [self drawSvgTempo:measure start_x:x start_y:start_y];
                }
                
                //保存每一小节的位置，为了播放midi时高亮显示当前小节
                MeasurePos *meas_pos=[[MeasurePos alloc]init];
                meas_pos.page=[self.staff_images count];
                meas_pos.start_x=x;
                meas_pos.start_y=line_y-LINE_H*2;
                meas_pos.height=STAFF_OFFSET[STAFF_COUNT-1]+4*LINE_H+4*LINE_H;
                [self.svgMeasurePosContent appendFormat:@"{'notes':["];
                //设置note位置
                if (meas_pos.note_pos==nil) {
                    meas_pos.note_pos=[[NSMutableArray alloc]init];
                }
                
                //NSArray *sorted_duration_offset=[measure.sorted_notes.allKeys sortedArrayUsingSelector:@selector(compare:)];
                NSArray *sorted_duration_offset=measure.sorted_duration_offset;
                
                for (NSString *key in sorted_duration_offset) {
                    NSMutableArray *notes=[measure.sorted_notes objectForKey:key];
                    
                    NotePos *note_pos=[[NotePos alloc]init];
                    [meas_pos.note_pos addObject:note_pos];
                    note_pos.page=meas_pos.page;
                    
                    float note_x=x+MEAS_LEFT_MARGIN+key_offset;
                    
                    float y1[MAX_POS_NUM];
                    y1[0]=start_y-LINE_H*2;
                    for (int k=1; k<MAX_POS_NUM; k++) {
                        y1[k]=start_y+STAFF_OFFSET[k]-2*LINE_H;
                    }
                    for (OveNote *note in notes) {
                        //每个附点的符干左边沿x坐标
                        note_x = x+MEAS_LEFT_MARGIN+note.pos.start_offset*OFFSET_X_UNIT+key_offset;
                        
                        NoteElem *note_elem=note.note_elems.firstObject;//  [note.note_elems objectAtIndex:0];
//                        if (note_elem) {
//                            note_x=x+note_elem.display_x;
//                        }
                        int staff = note.staff+note_elem.offsetStaff;
                        float note_y=start_y+[self lineToY:note.line staff:staff]-2*LINE_H;
                        
                        if (note.staff<=MAX_POS_NUM) {
                            if (note_y<y1[note.staff-1]) {
                                y1[note.staff-1]=note_y;
                            }
                        }
                    }
                    for (int k=0; k<MAX_POS_NUM; k++) {
                        [note_pos start_y:y1[k] forIndex:k];
                    }
                    
                    note_pos.start_x=note_x;
                    //note_pos.stop_x=note_x+LINE_H*2.0;
                    note_pos.width=LINE_H*1.5;
                    note_pos.height=8*LINE_H;
//                    [self.svgMeasurePosContent appendFormat:@"%.0f,",note_x];
                }
                
                //begin measure: 反复记号
                int last_staff_lines=5;
                LineStaff *last_staff=[line.staves objectAtIndex:STAFF_COUNT-1];
                if (last_staff.clef==Clef_TAB) {
                    last_staff_lines=6;
                }
                int staff_count=(int)line.staves.count;
                if (measure.left_barline == Barline_RepeatLeft) {
                    for (int i=0; i<staff_count; i++) {
                        NORMAL_DOT(x+LINE_H*0.8, start_y+LINE_H*1.5+STAFF_OFFSET[i]);
                        NORMAL_DOT(x+LINE_H*0.8, start_y+LINE_H*2.5+STAFF_OFFSET[i]);
                    }
                    LINE(x+1.5*BARLINE_WIDTH, start_y, x+1.5*BARLINE_WIDTH, start_y+LINE_H*(last_staff_lines-1)+STAFF_OFFSET[staff_count-1]);
                    LINE_W(x-0, start_y, x-0, start_y+LINE_H*(last_staff_lines-1)+STAFF_OFFSET[staff_count-1], BARLINE_WIDTH);
                }else if (measure.left_barline==Barline_Double) {
                    LINE(x-BARLINE_WIDTH, start_y, x-BARLINE_WIDTH, start_y+LINE_H*(last_staff_lines-1)+STAFF_OFFSET[staff_count-1]);
                }else if (measure.left_barline!=Barline_Default) {
                    NSLog(@"Error: unknow left_barline=%d at meansure(%d)",measure.left_barline, measure.number);
                }
                
                //如果几分之几拍有变化
                if (nn>0 && (measure.numerator!=last_numerator || measure.denominator!=last_denominator))
                {
                    x+=LINE_H*0.5;
                    [self drawSvgTimeSignature:measure start_x:x start_y:start_y staff_count:STAFF_COUNT];
                    x+=LINE_H*0.5;
                }
                last_numerator=measure.numerator;
                last_denominator=measure.denominator;
                int jianpu_start_x=x;
                
                //画小节
                x=[self drawSvgMeasure:measure startX:x startY:start_y line:line line_index:line_num line_count:page.line_count];
                int w=MEAS_LEFT_MARGIN+measure.meas_length_size*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN;
                BEGIN_MEASURE(measure.number, meas_pos.start_x, meas_pos.start_y, w,meas_pos.height);
                //pos.width=x-pos.start_x;
                meas_pos.start_x+=MEAS_LEFT_MARGIN;
                meas_pos.width=x-meas_pos.start_x-MEAS_RIGHT_MARGIN;
                //END_MEASURE();
                [self.measure_pos addObject:meas_pos];
                
                for (NSString *key in sorted_duration_offset) {
                    NSMutableArray *notes=[measure.sorted_notes objectForKey:key];
                    float x=0;
                    for (OveNote *note in notes) {
                        if (note.isRest) {
                            x=note.display_note_x;
                        }else{
                            NoteElem *elem=note.note_elems.firstObject;
                            x=elem.display_x;
                            break;
                        }
                    }
                    [self.svgMeasurePosContent appendFormat:@"%.0f,",x];
                }
                
//                [self.svgMeasurePosContent appendFormat:@"],'pos':{'x':%d,'y':%d,'w':%d,'h':%d}},\n",meas_pos.start_x,meas_pos.start_y,meas_pos.width,meas_pos.height ];
                [self.svgMeasurePosContent appendFormat:@"],'pos':{'x':%d,'y':%d,'w':%d,'h':%d},'page':%d},\n",meas_pos.start_x,meas_pos.start_y,meas_pos.width,meas_pos.height,page_num ];
#ifdef NEW_PAGE_MODE
                if (landPageMode) {
                    meas_pos.start_x+=self.music.page_width*page_num;
                }else{
                    meas_pos.start_y+=self.music.page_height*page_num;
                }
#endif
                //jianpu
                if (self.showJianpu) {
                    [self drawJianpu:measure start_x:jianpu_start_x start_y:start_y];
                }
                //end jianpu
            }
#endif
//            [self endSvgLine];
        }
#ifdef NEW_PAGE_MODE
        [self endSvgPage];
#else
        if (self.pageMode) {
            [self.svgMeasurePosContent appendFormat:@"];var page_pos=null;"];
            [self.staff_images addObject:[self endSvgImage]];
        }
#endif
    }
#ifdef NEW_PAGE_MODE
    [self.svgMeasurePosContent appendFormat:@"];"];
    [self.svgMeasurePosContent appendFormat:@"var page_pos=["];
    if (landPageMode) {
        for (int page=0; page<self.music.pages.count; page++) {
            [self.svgMeasurePosContent appendFormat:@"{'x':%.0f,'y':0},",screen_size.width*page];
        }
    }else{
        for (int page=0; page<self.music.pages.count; page++) {
            [self.svgMeasurePosContent appendFormat:@"{'x':0,'y':%.0f},",screen_size.height*page];
        }
    }
    [self.svgMeasurePosContent appendFormat:@"];"];
    [self.staff_images addObject:[self endSvgImage]];
#else
    if (!self.pageMode) {
        [self.staff_images addObject:[self endSvgImage]];
    }
#endif
    //NSLog(@"Draw music end");
}
#endif

- (CGPoint)pointForNote:(int)note
                measure:(int)measure_index
                   note:(int)note_index
                  staff:(int)staff
{
    CGPoint pt;
    MeasurePos *meas_pos=self.measure_pos[measure_index];
    NotePos *note_pos=meas_pos.note_pos[note_index];
    pt.x=note_pos.start_x;
//    pt.y=meas_pos.start_y-LINE_H*2+STAFF_OFFSET[staff-1];
    
    //get staff's clef
    /*
       ||  C  | C#  |  D  | D#  |  E  |  F  | F#  |  G  | G#  |  A  | A#  | B
    -----------------------------------------------------------------------------
       ||   0 |   1 |   2 |   3 |   4 |   5 |   6 |   7 |   8 |   9 |  10 | 11
     */
    int steps[12]={0,0,1,1,2,3,3,4,4,5,5,6};
    for (OveLine *ove_line in self.music.lines) {
        if (measure_index>=ove_line.begin_bar && measure_index<ove_line.begin_bar+ove_line.bar_count) {
            LineStaff *line_staff=[ove_line.staves objectAtIndex:staff-1];
            ClefType clefType= line_staff.clef;
            int line;
            int pitch_step=steps[note%12]+1;
            int pitch_octave=note/12-1;
            if (clefType==Clef_Treble) {
                line=((pitch_step-7)+7*(pitch_octave-4));
            }else{
                line=5+((pitch_step-7)+7*(pitch_octave-3));
            }
            pt.y=meas_pos.start_y+LINE_H*2+[self lineToY:line staff:staff];
            break;
        }
    }
    return pt;
}


-(void) drawSvgTitle
{
    if (self.music.work_title.length>0) {
        NSString *title = COM_LOCAL(self.music.work_title);
        TEXT_CENTER(screen_size.width*0.5,1.5*LINE_H, TITLE_FONT_SIZE, title);
    }
    
    //work_number
    if (self.music.work_number.length>0) {
        int font_size=TITLE_FONT_SIZE*0.6;
        NSString *title = COM_LOCAL(self.music.work_number);
        TEXT_CENTER(screen_size.width*0.5,2.5*LINE_H+TITLE_FONT_SIZE, font_size, title);
    }

    // composer
//    if (self.music.composer.length>0) {
//        NSString *composer=self.music.composer;
//        int font_size=TITLE_FONT_SIZE*0.6;
//        //[tmp drawAtPoint:CGPointMake(size.width-tmp_size.width-MARGIN_RIGHT, tmp_y) withFont:[UIFont systemFontOfSize:16]];
//        TEXT_RIGHT(screen_size.width-20, TITLE_FONT_SIZE, font_size, composer);
//    }
/*
    // lyricist
    if (self.music.lyricist.length>0) {
        NSString *lyricist=self.music.lyricist;
#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
        CGSize tmp_size=[lyricist sizeWithFont:[UIFont systemFontOfSize:20]];
#else
        CGSize tmp_size=CGSizeMake(lyricist.length*17, 17);
#endif
        //[tmp drawAtPoint:CGPointMake(size.width-tmp_size.width-MARGIN_RIGHT, tmp_y) withFont:[UIFont systemFontOfSize:16]];
        TEXT(size.width-tmp_size.width-MARGIN_RIGHT, 55, 20, lyricist);
    }
 */
}
#ifdef OVE_IPHONE
#define DRAW_FLAG(off_x, line)    \
{   \
GLYPH_Petrucci(off_x+7*LINE_H,tmp_y+LINE_H*line,GLYPH_FONT_SIZE,0,flag); \
}
#else
#define DRAW_FLAG(off_x, line)    \
{   \
GLYPH_Petrucci(off_x+5*LINE_H,tmp_y+LINE_H*line,GLYPH_FONT_SIZE,0,flag); \
}
#endif

-(void)drawSvgStopDiaohaoWithClef:(ClefType)clef fifths:(int)key_fifths previousKey:(int)previousKey x:(int)x startY:(float)start_y
{
    NSString *flag=ELEM_FLAG_STOP;
    float tmp_y=start_y+LINE_H*(-1);
    x-=1*LINE_H;
    float sharp_lines[]={1.0,2.5,0.5,2.0,3.5,1.5,3.0};
    if (clef==Clef_Treble) {
        if (previousKey>0) {
            //float offx=x;
            for (int i=0; i<previousKey; i++) {
                DRAW_FLAG(x-5,sharp_lines[i]);
            }
        }
        switch (previousKey) {
            case 0://C major or a minor: CEG:135, ace:
                break;
            case 1://G major, e minor
                DRAW_FLAG(x-5,1);
                break;
            case 2://D major, b minor
                DRAW_FLAG(x-8,1);
                DRAW_FLAG(x+5,2.5);
                break;
            case 3://A major, f# minor
                DRAW_FLAG(x-12,1);
                DRAW_FLAG(x+0, 2.5);
                DRAW_FLAG(x+12,0.5);
                break;
            case 4://E major, c# minor
                DRAW_FLAG(x-15, 1);
                DRAW_FLAG(x-5, 2.5);
                DRAW_FLAG(x+5,0.5);
                DRAW_FLAG(x+15,2);
                break;
            case 5://B major, g# minor
                DRAW_FLAG(x-20,1.0);
                DRAW_FLAG(x-10, 2.5);
                DRAW_FLAG(x+0, 0.5);
                DRAW_FLAG(x+10, 2.0);
                DRAW_FLAG(x+20,3.5);
                break;
            case 6://F# major, d# minor
                DRAW_FLAG(x-22,1.0);
                DRAW_FLAG(x-12, 2.5);
                DRAW_FLAG(x-2, 0.5);
                DRAW_FLAG(x+8, 2.0);
                DRAW_FLAG(x+18,3.5);
                DRAW_FLAG(x+28,1.5);
                break;
            case 7://C# major, a# minor
                DRAW_FLAG(x-22,1.0);
                DRAW_FLAG(x-12, 2.5);
                DRAW_FLAG(x-2, 0.5);
                DRAW_FLAG(x+8, 2.0);
                DRAW_FLAG(x+18,3.5);
                DRAW_FLAG(x+28,1.5);
                DRAW_FLAG(x+38,3.0);
                break;
            case -1://F major, d minor
                DRAW_FLAG(x-5, 3.0);
                break;
            case -2://Bb major, g minor
                DRAW_FLAG(x-5, 3.0);
                DRAW_FLAG(x+5, 1.5);
                break;
            case -3://Eb major, c minor
                DRAW_FLAG(x-10, 3.0);
                DRAW_FLAG(x+0, 1.5);
                DRAW_FLAG(x+10, 3.5);
                break;
            case -4://Ab major, f minor
                DRAW_FLAG(x-13, 3.0);
                DRAW_FLAG(x-4, 1.5);
                DRAW_FLAG(x+5,3.5);
                DRAW_FLAG(x+14,2.0);
                break;
            case -5://Db major, bb minor
                DRAW_FLAG(x-16,3.0);
                DRAW_FLAG(x-8, 1.5);
                DRAW_FLAG(x+0, 3.5);
                DRAW_FLAG(x+8, 2.0);
                DRAW_FLAG(x+16,4.0);
                break;
            case -6://Gb major, eb minor
                DRAW_FLAG(x-18,3.0);
                DRAW_FLAG(x-10, 1.5);
                DRAW_FLAG(x-2, 3.5);
                DRAW_FLAG(x+6, 2.0);
                DRAW_FLAG(x+14,4.0);
                DRAW_FLAG(x+22,2.5);
                break;
            case -7://Cb major, ab minor
                DRAW_FLAG(x-20,3.0);
                DRAW_FLAG(x-12,1.5);
                DRAW_FLAG(x-4, 3.5);
                DRAW_FLAG(x+4, 2.0);
                DRAW_FLAG(x+12,4.0);
                DRAW_FLAG(x+20,2.5);
                DRAW_FLAG(x+28,4.5);
                break;
            default:
                NSLog(@"Error: unknow diaohao:%d",previousKey);
                break;
        }
    }else{
        switch (previousKey) {
            case 1://G major
                DRAW_FLAG(x-5,2);
                break;
            case 2://D major
                DRAW_FLAG(x-8,2);
                DRAW_FLAG(x+5,3.5);
                break;
            case 3://A major, f# minor
                DRAW_FLAG(x-12,2);
                DRAW_FLAG(x+0,3.5);
                DRAW_FLAG(x+12,1.5);
                break;
            case 4://E major
                DRAW_FLAG(x-15,2.0);
                DRAW_FLAG(x-5,3.5);
                DRAW_FLAG(x+5,1.5);
                DRAW_FLAG(x+15,3.0);
                break;
            case 5://B major
                DRAW_FLAG(x-20,2.0);
                DRAW_FLAG(x-10, 3.5);
                DRAW_FLAG(x+0, 1.5);
                DRAW_FLAG(x+10, 3.0);
                DRAW_FLAG(x+20,4.5);
                break;
            case 6://F# major
                DRAW_FLAG(x-20, 2.0);
                DRAW_FLAG(x-10, 3.5);
                DRAW_FLAG(x-0, 1.5);
                DRAW_FLAG(x+10, 3.0);
                DRAW_FLAG(x+20, 4.5);
                DRAW_FLAG(x+30, 2.5);
                break;
            case 7://C# major
                DRAW_FLAG(x-20, 2.0);
                DRAW_FLAG(x-10, 3.5);
                DRAW_FLAG(x-0, 1.5);
                DRAW_FLAG(x+10, 3.0);
                DRAW_FLAG(x+20, 4.5);
                DRAW_FLAG(x+30, 2.5);
                DRAW_FLAG(x+40, 4.0);
                break;
            case -1://F major, D minor
                DRAW_FLAG(x-5, 4.0);
                break;
            case -2://Bb major
                DRAW_FLAG(x-5, 4);
                DRAW_FLAG(x+5, 2.5);
                break;
            case -3://Eb major
                DRAW_FLAG(x-10, 4);
                DRAW_FLAG(x+0, 2.5);
                DRAW_FLAG(x+10, 4.5);
                break;
            case -4://Ab major
                DRAW_FLAG(x-13,4.0);
                DRAW_FLAG(x-4, 2.5);
                DRAW_FLAG(x+5, 4.5);
                DRAW_FLAG(x+14,3);
                break;
            case -5://Db major, bb minor
                DRAW_FLAG(x-16, 4.0);
                DRAW_FLAG(x-8, 2.5);
                DRAW_FLAG(x+0, 4.5);
                DRAW_FLAG(x+8, 3);
                DRAW_FLAG(x+16, 5.0);
                break;
            case -6://Gb major, eb minor
                DRAW_FLAG(x-18, 4.0);
                DRAW_FLAG(x-10, 2.5);
                DRAW_FLAG(x-2, 4.5);
                DRAW_FLAG(x+6, 3);
                DRAW_FLAG(x+14, 5.0);
                DRAW_FLAG(x+22, 3.5);
                break;
            case -7://ab minor
                DRAW_FLAG(x-20, 4.0);
                DRAW_FLAG(x-12, 2.5);
                DRAW_FLAG(x-4, 4.5);
                DRAW_FLAG(x+4, 3);
                DRAW_FLAG(x+12, 5.0);
                DRAW_FLAG(x+20, 3.5);
                DRAW_FLAG(x+28, 5.5);
                break;
            case 0: //C major or A minor
                break;
            default:
                NSLog(@"Error: unknow diaohao:%d",previousKey);
                break;
        }
    }
}

-(void)drawSvgDiaohaoWithClef:(ClefType)clef fifths:(int)key_fifths x:(int)x startY:(float)start_y  stop:(BOOL)stop_flag
{
    float tmp_y;
    NSString *flag;
    if (stop_flag) {
        flag=ELEM_FLAG_STOP;
        tmp_y=start_y+LINE_H*(-1);
        x-=1*LINE_H;
    }else if(key_fifths>0){
        flag=ELEM_FLAG_SHARP;
        tmp_y=start_y+LINE_H*(-1.0);
    }else{
        flag=ELEM_FLAG_FLAT;
        tmp_y=start_y+LINE_H*(-1);
    }
    
    if (self.showJianpu && clef==Clef_Treble && !stop_flag) {
        //jianpu
        //ELEM_FLAG_SHARP="&#xf023"
        NSArray *jianpuhao=@[@"1= C",@"1= G",@"1= D",@"1= A",@"1= E",@"1= B",@"1=F",
                             @"1=C",
                             @"1=G",@"1=D",@"1=A",@"1=E",@"1=B",@"1= F",@"1= C"];
        if (last_fifths<-1) {
            FLAT_JIANPU(x+5*LINE_H, start_y-2.5*LINE_H);
        }else if (last_fifths>5){
            SHARP_JIANPU(x+5*LINE_H, start_y-2.5*LINE_H);
        }
        TEXT_JIANPU(x+2*LINE_H, start_y-3*LINE_H, [jianpuhao objectAtIndex:last_fifths+7], @"1=C", JIANPU_FONT_SIZE);
    }
    
    if (clef==Clef_Treble) {
        switch (key_fifths) {
            case 0://C major or a minor: CEG:135, ace:
                break;
            case 1://G major, e minor
                DRAW_FLAG(x-5,1);
                break;
            case 2://D major, b minor
                DRAW_FLAG(x-8,1);
                DRAW_FLAG(x+5,2.5);
                break;
            case 3://A major, f# minor
                DRAW_FLAG(x-12,1);
                DRAW_FLAG(x+0, 2.5);
                DRAW_FLAG(x+12,0.5);
                break;
            case 4://E major, c# minor
                DRAW_FLAG(x-15, 1);
                DRAW_FLAG(x-5, 2.5);
                DRAW_FLAG(x+5,0.5);
                DRAW_FLAG(x+15,2);
                break;
            case 5://B major, g# minor
                DRAW_FLAG(x-20,1.0);
                DRAW_FLAG(x-10, 2.5);
                DRAW_FLAG(x+0, 0.5);
                DRAW_FLAG(x+10, 2.0);
                DRAW_FLAG(x+20,3.5);
                break;
            case 6://F# major, d# minor
                DRAW_FLAG(x-22,1.0);
                DRAW_FLAG(x-12, 2.5);
                DRAW_FLAG(x-2, 0.5);
                DRAW_FLAG(x+8, 2.0);
                DRAW_FLAG(x+18,3.5);
                DRAW_FLAG(x+28,1.5);
                break;
            case 7://C# major, a# minor
                DRAW_FLAG(x-22,1.0);
                DRAW_FLAG(x-12, 2.5);
                DRAW_FLAG(x-2, 0.5);
                DRAW_FLAG(x+8, 2.0);
                DRAW_FLAG(x+18,3.5);
                DRAW_FLAG(x+28,1.5);
                DRAW_FLAG(x+38,3.0);
                break;
            case -1://F major, d minor
                DRAW_FLAG(x-5, 3.0);
                break;
            case -2://Bb major, g minor
                DRAW_FLAG(x-5, 3.0);
                DRAW_FLAG(x+5, 1.5);
                break;
            case -3://Eb major, c minor
                DRAW_FLAG(x-10, 3.0);
                DRAW_FLAG(x+0, 1.5);
                DRAW_FLAG(x+10, 3.5);
                break;
            case -4://Ab major, f minor
                DRAW_FLAG(x-13, 3.0);
                DRAW_FLAG(x-4, 1.5);
                DRAW_FLAG(x+5,3.5);
                DRAW_FLAG(x+14,2.0);
                break;
            case -5://Db major, bb minor
                DRAW_FLAG(x-16,3.0);
                DRAW_FLAG(x-8, 1.5);
                DRAW_FLAG(x+0, 3.5);
                DRAW_FLAG(x+8, 2.0);
                DRAW_FLAG(x+16,4.0);
                break;
            case -6://Gb major, eb minor
                DRAW_FLAG(x-18,3.0);
                DRAW_FLAG(x-10, 1.5);
                DRAW_FLAG(x-2, 3.5);
                DRAW_FLAG(x+6, 2.0);
                DRAW_FLAG(x+14,4.0);
                DRAW_FLAG(x+22,2.5);
                break;
            case -7://Cb major, ab minor
                DRAW_FLAG(x-20,3.0);
                DRAW_FLAG(x-12,1.5);
                DRAW_FLAG(x-4, 3.5);
                DRAW_FLAG(x+4, 2.0);
                DRAW_FLAG(x+12,4.0);
                DRAW_FLAG(x+20,2.5);
                DRAW_FLAG(x+28,4.5);
                break;
            default:
                NSLog(@"Error: unknow diaohao:%d",key_fifths);
                break;
        }
    }else{
        switch (key_fifths) {
            case 1://G major
                DRAW_FLAG(x-5,2);
                break;
            case 2://D major
                DRAW_FLAG(x-8,2);
                DRAW_FLAG(x+5,3.5);
                break;
            case 3://A major, f# minor
                DRAW_FLAG(x-12,2);
                DRAW_FLAG(x+0,3.5);
                DRAW_FLAG(x+12,1.5);
                break;
            case 4://E major
                DRAW_FLAG(x-15,2.0);
                DRAW_FLAG(x-5,3.5);
                DRAW_FLAG(x+5,1.5);
                DRAW_FLAG(x+15,3.0);
                break;
            case 5://B major
                DRAW_FLAG(x-20,2.0);
                DRAW_FLAG(x-10, 3.5);
                DRAW_FLAG(x+0, 1.5);
                DRAW_FLAG(x+10, 3.0);
                DRAW_FLAG(x+20,4.5);
                break;
            case 6://F# major
                DRAW_FLAG(x-20, 2.0);
                DRAW_FLAG(x-10, 3.5);
                DRAW_FLAG(x-0, 1.5);
                DRAW_FLAG(x+10, 3.0);
                DRAW_FLAG(x+20, 4.5);
                DRAW_FLAG(x+30, 2.5);
                break;
            case 7://C# major
                DRAW_FLAG(x-20, 2.0);
                DRAW_FLAG(x-10, 3.5);
                DRAW_FLAG(x-0, 1.5);
                DRAW_FLAG(x+10, 3.0);
                DRAW_FLAG(x+20, 4.5);
                DRAW_FLAG(x+30, 2.5);
                DRAW_FLAG(x+40, 4.0);
                break;
            case -1://F major, D minor
                DRAW_FLAG(x-5, 4.0);
                break;
            case -2://Bb major
                DRAW_FLAG(x-5, 4);
                DRAW_FLAG(x+5, 2.5);
                break;
            case -3://Eb major
                DRAW_FLAG(x-10, 4);
                DRAW_FLAG(x+0, 2.5);
                DRAW_FLAG(x+10, 4.5);
                break;
            case -4://Ab major
                DRAW_FLAG(x-13,4.0);
                DRAW_FLAG(x-4, 2.5);
                DRAW_FLAG(x+5, 4.5);
                DRAW_FLAG(x+14,3);
                break;
            case -5://Db major, bb minor
                DRAW_FLAG(x-16, 4.0);
                DRAW_FLAG(x-8, 2.5);
                DRAW_FLAG(x+0, 4.5);
                DRAW_FLAG(x+8, 3);
                DRAW_FLAG(x+16, 5.0);
                break;
            case -6://Gb major, eb minor
                DRAW_FLAG(x-18, 4.0);
                DRAW_FLAG(x-10, 2.5);
                DRAW_FLAG(x-2, 4.5);
                DRAW_FLAG(x+6, 3);
                DRAW_FLAG(x+14, 5.0);
                DRAW_FLAG(x+22, 3.5);
                break;
            case -7://ab minor
                DRAW_FLAG(x-20, 4.0);
                DRAW_FLAG(x-12, 2.5);
                DRAW_FLAG(x-4, 4.5);
                DRAW_FLAG(x+4, 3);
                DRAW_FLAG(x+12, 5.0);
                DRAW_FLAG(x+20, 3.5);
                DRAW_FLAG(x+28, 5.5);
                break;
            case 0: //C major or A minor
                break;
            default:
                NSLog(@"Error: unknow diaohao:%d",key_fifths);
                break;
        }
    }
}

//time signature 拍号：几分之几拍
- (void)drawSvgTimeSignature:(OveMeasure*)measure start_x:(float)x start_y:(float)start_y staff_count:(unsigned long)staff_count
{
    if (measure.denominator>0 && measure.numerator>0)
    {
        for (int nn=0; nn<staff_count; nn++) {
            if (measure.denominator==2 && measure.numerator==2) {
                GLYPH_Petrucci(x, start_y+STAFF_OFFSET[nn]+2*LINE_H, GLYPH_FONT_SIZE, 0, ELEM_TIME_SIGNATURE_CUT_TIME);
            }else if (measure.denominator==4 && measure.numerator==4) {
                GLYPH_Petrucci(x, start_y+STAFF_OFFSET[nn]+2*LINE_H, GLYPH_FONT_SIZE, 0, ELEM_TIME_SIGNATURE_COMMON_TIME);
            }else{
                //numerator 分子
                float tmp_x=x;
                if (measure.numerator>=10) {
                    tmp_x=x-8;
                }

                NSString *tmp=[NSString stringWithFormat:@"3%d",measure.numerator%10];
                if (measure.numerator>10) {
                    tmp=[NSString stringWithFormat:@"3%d;&#x3%d",measure.numerator/10,measure.numerator%10];
                }
                GLYPH_Petrucci(tmp_x, start_y+STAFF_OFFSET[nn]+1*LINE_H,GLYPH_FONT_SIZE, 0, tmp);
                //denominator 分母
                tmp_x=x;
                if (measure.denominator>=10) {
                    tmp_x=x-8;
                }
                tmp=[NSString stringWithFormat:@"3%d",measure.denominator];
                if (measure.denominator>10) {
                    tmp=[NSString stringWithFormat:@"3%d;&#x3%d",measure.denominator/10,measure.denominator%10];
                }
                GLYPH_Petrucci(tmp_x, start_y+STAFF_OFFSET[nn]+1*LINE_H+2*LINE_H,GLYPH_FONT_SIZE, 0, tmp);
            }
        }
    }
}
-(NoteHeadType)headType:(NoteElem*)elem staff:(int)staff
{
    NoteHeadType ret=0;
    if (staff<self.music.trackes.count) {
        OveTrack *track = self.music.trackes[staff];
        if (track.start_clef>=Clef_Percussion1) {
            track_node *node_info=[track getNode];
            for (int i=0; i<16; i++) {
                if (node_info->line[i]==elem.line) {
                    ret=node_info->head_type[i];
                    break;
                }
            }
        }
    }
    return ret;
}

- (BOOL)isNote:(OveNote*)note inBeam:(OveBeam*)beam {
    BeamElem *elem0=beam.beam_elems.firstObject;
    
//    BOOL ret = ((beam.staff==note.staff ||beam.stop_staff==note.staff) && (beam.voice==note.voice) && (!beam.isGrace==!note.isGrace)
//        && (elem0.start_measure_offset <= note.pos.start_offset && (elem0.stop_measure_offset >= note.pos.start_offset || elem0.stop_measure_pos>0) )
//                );

    BOOL ret = ((beam.voice==note.voice) && (!beam.isGrace==!note.isGrace)
                && (elem0.start_measure_offset <= note.pos.start_offset && (elem0.stop_measure_offset >= note.pos.start_offset || elem0.stop_measure_pos>0) )
                );
    if (ret && beam.staff<3 && note.staff>2) {
        ret=NO;
    }
    return ret;
}

- (float)checkSlurY:(MeasureSlur*)slur measure:(OveMeasure*)measure note:(OveNote*)note start_x:(float)start_x start_y:(float)start_y slurY:(float)slurY
{
    if (note.inBeam && note.stem_up==slur.slur1_above) {
        for (OveBeam *beam in measure.beams) {
            if([self isNote:note inBeam:beam]){
                CGRect beam_pos=[self getBeamRect:beam start_x:start_x start_y:start_y measure:measure reload:NO];
                float tmp_x=start_x+MEAS_LEFT_MARGIN+note.pos.start_offset*OFFSET_X_UNIT;
                if (note.stem_up) {
                    tmp_x+=LINE_H;
                }
                float tmp_y2=beam_pos.size.height/beam_pos.size.width*(tmp_x-beam_pos.origin.x)*1+beam_pos.origin.y;
                if (slur.slur1_above) {
                    if (slurY>=tmp_y2) {
                        slurY=tmp_y2-LINE_H/2;
                    }
                }else {
                    if (slurY<=tmp_y2) {
                        slurY=tmp_y2+LINE_H/2;
                    }
                }
            }
        }
    }
    return slurY;
}

- (void)drawSvgRepeat:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y {
    //repeat_type
    if (measure.repeat_type!=Repeat_Null)
    {
        float tmp_x;//=start_x+measure.meas_length_size*OFFSET_X_UNIT*0.5;
        
        //float tmp_x+=start_x+(measure.repeate_symbol_pos.start_offset+measure.repeat_offset.offset_x)*OFFSET_X_UNIT;
        float tmp_y=start_y + STAFF_OFFSET[1]+STAFF_OFFSET[1]/2+1*LINE_H;
        //float tmp_y=start_y + STAFF_OFFSET[1]-LINE_H*2 + measure.repeat_offset.offset_y*OFFSET_Y_UNIT;
        if (measure.repeat_type==Repeat_Segno) //返回到
        {
            tmp_x=start_x+(measure.repeate_symbol_pos.start_offset+measure.repeat_offset.offset_x)*OFFSET_X_UNIT;
            if (measure.repeat_offset.offset_y) {
                tmp_y=start_y + measure.repeat_offset.offset_y*OFFSET_Y_UNIT;
            }else{
                tmp_y=start_y + STAFF_OFFSET[1]-LINE_H*2 + measure.repeat_offset.offset_y*OFFSET_Y_UNIT;
            }
            REPEAT_SEGNO(tmp_x, tmp_y);
        }else if (measure.repeat_type==Repeat_Coda) //返回到 ToCada
        {
            tmp_x=start_x+(measure.repeate_symbol_pos.start_offset+measure.repeat_offset.offset_x)*OFFSET_X_UNIT;
            tmp_y=start_y + STAFF_OFFSET[0]-LINE_H*2;// + measure.repeat_offset.offset_y*OFFSET_Y_UNIT;
            REPEAT_CODA(tmp_x-LINE_H, tmp_y);
            TEXT_RIGHT_ITALIC(tmp_x+5*LINE_H, tmp_y-2*LINE_H, EXPR_FONT_SIZE, @"Coda");
        }else if (measure.repeat_type==Repeat_ToCoda) //
        {
            tmp_x=start_x+(measure.repeate_symbol_pos.start_offset+measure.repeat_offset.offset_x)*OFFSET_X_UNIT;
            tmp_y=start_y + STAFF_OFFSET[1]-LINE_H*2 + measure.repeat_offset.offset_y*OFFSET_Y_UNIT;
            tmp_x += MEAS_LEFT_MARGIN+measure.meas_length_size*OFFSET_X_UNIT;
            REPEAT_CODA(tmp_x, tmp_y);
            TEXT_RIGHT_ITALIC(tmp_x-LINE_H*7, tmp_y-20, EXPR_FONT_SIZE, @"To Coda");
        }else if (measure.repeat_type==Repeat_DSAlCoda) //
        {
            //tmp_x += MEAS_LEFT_MARGIN+measure.meas_length_size*OFFSET_X_UNIT;
            tmp_x=start_x+measure.meas_length_size*OFFSET_X_UNIT+MEAS_LEFT_MARGIN;
            //TEXT_CENTER(tmp_x-80, tmp_y-15, 20, @"D.S. al Coda");
            TEXT_RIGHT_ITALIC(tmp_x, tmp_y-15, EXPR_FONT_SIZE, @"D.S. al Coda");
        }else if (measure.repeat_type==Repeat_DSAlFine) //
        {
            //tmp_x += MEAS_LEFT_MARGIN+measure.meas_length_size*OFFSET_X_UNIT;
            tmp_x=start_x+measure.meas_length_size*OFFSET_X_UNIT+MEAS_LEFT_MARGIN;
            TEXT_RIGHT_ITALIC(tmp_x, tmp_y-0*LINE_H, EXPR_FONT_SIZE, @"D.S. al Fine");
        }else if (measure.repeat_type==Repeat_DCAlCoda) //
        {
            tmp_x=start_x+measure.meas_length_size*OFFSET_X_UNIT+MEAS_LEFT_MARGIN;
            TEXT_RIGHT_ITALIC(tmp_x, tmp_y-15, EXPR_FONT_SIZE, @"D.C. al Code");
        }else if (measure.repeat_type==Repeat_DC) //
        {
            tmp_x=start_x+measure.meas_length_size*OFFSET_X_UNIT+MEAS_LEFT_MARGIN;
            TEXT_RIGHT_ITALIC(tmp_x, tmp_y-15, EXPR_FONT_SIZE, @"D.C.");
        }else if (measure.repeat_type==Repeat_DCAlFine) // 返回到开头，然后play到"Fine"结束
        {
            tmp_x=start_x+measure.meas_length_size*OFFSET_X_UNIT+MEAS_LEFT_MARGIN;
            TEXT_RIGHT_ITALIC(tmp_x, tmp_y-15, EXPR_FONT_SIZE, @"D.C. al Fine");
        }else if (measure.repeat_type==Repeat_Fine) //
        {
            tmp_x=start_x+measure.meas_length_size*OFFSET_X_UNIT+MEAS_LEFT_MARGIN;
            TEXT_RIGHT_ITALIC(tmp_x, tmp_y-15, EXPR_FONT_SIZE, @"Fine");
        }else{
            NSLog(@"repeat_type=%d at measure(%d)", measure.repeat_type, measure.number);
        }
    }
}

- (void)drawSvgTexts:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y
{
    if (measure.meas_texts) {
        for (OveText *text in measure.meas_texts) {
            if (text.text.length) {
                float x1 = start_x+MEAS_LEFT_MARGIN;
                //                if (text.offset_x) {
                //                    x1+=text.offset_x*OFFSET_X_UNIT;
                //                    if (ove_line.begin_bar==measure.number) {
                //                        x1-=6*LINE_H;
                //                    }
                //                }else if (text.pos.start_offset) {
                //                    x1+=(text.pos.start_offset+text.offset_x)*OFFSET_X_UNIT;
                //                }
                x1+=(text.pos.start_offset+text.offset_x)*OFFSET_X_UNIT;
                
                //                float y1 = start_y + LINE_H*2 + (text.offset_y)*OFFSET_Y_UNIT;
                float y1 = start_y - 1*LINE_H + (text.offset_y)*OFFSET_Y_UNIT;
                if (text.offset_y<0) {
                    //y1-=LINE_H;
                }
                if (text.staff>1)
                {
                    y1+=STAFF_OFFSET[text.staff-1];
                }
                //TEXT(x1, y1, text.font_size, text.text);
                float font_size=text.font_size*0.9;
                //                if (LINE_H<8) {
                //                    font_size*=0.5;
                //                }
                y1-=font_size*0.5;
                
                TEXT_ATTR(x1, y1, font_size, text.text, text.isBold, text.isItalic);
            }else{
                NSLog(@"empty measure text at measure(%d)", measure.number);
            }
            //[text.text drawAtPoint:CGPointMake(x1, y1) withFont:[UIFont systemFontOfSize:18]];
            //NSLog(@"tt(%d):%@",text.staff, text.text);
        }
    }
}

- (void)drawSvgSlurs:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y line:(OveLine *)ove_line
{
    int staff_count=(int)ove_line.staves.count;
    //slur 连奏 看上一行有没有slur没有画完。
    if (measure.number==ove_line.begin_bar) {
        for (int ss=0; ss<SLUR_CONTINUE_NUM; ss++) {
            if (slur_continue_info[ss].validate) {
                float x1 = start_x-LINE_H*2;
                float x2 = start_x+MEAS_LEFT_MARGIN+slur_continue_info[ss].stop_offset*OFFSET_X_UNIT;
                
                float y2 = start_y+ [self lineToY:slur_continue_info[ss].right_line staff:slur_continue_info[ss].stop_staff];
                float y1;
                if (!slur_continue_info[ss].above) {
                    y1=y2+LINE_H*1.5;
                }else{
                    if (slur_continue_info[ss].right_line>8) {
                        y1=start_y+ [self lineToY:8 staff:slur_continue_info[ss].stop_staff];//y2+LINE_H*(slur_continue_info[ss].right_line-10);
                    }else{
                        y1=y2-LINE_H*1.5;
                    }
                }
                
                OveMeasure *next_measure=nil;
                for (int nn=0; nn<slur_continue_info[ss].stop_measure; nn++) {
                    if (measure.number+nn>=self.music.measures.count) {
                        next_measure=self.music.measures.lastObject;
                    }else{
                        next_measure=[self.music.measures objectAtIndex:measure.number+nn];
                    }
                    x2+=next_measure.meas_length_size*OFFSET_X_UNIT+MEAS_LEFT_MARGIN+MEAS_RIGHT_MARGIN;
                }
                if (x2<=screen_size.width-MARGIN_RIGHT) {
                    [self drawSvgCurveLine:2 x1:x1 y1:y1 x2:x2 y2:y2 above:slur_continue_info[ss].above];
                    slur_continue_info[ss].validate=NO;
                }else{
                    //本行的前半段：
                    y2=y1;
                    [self drawSvgCurveLine:2 x1:x1 y1:y1 x2:screen_size.width-MARGIN_RIGHT y2:y2 above:slur_continue_info[ss].above];
                    //如果要换行了，就把延长的slur保存下来。
                    slur_continue_info[ss].stop_measure-=((ove_line.begin_bar+ove_line.bar_count)-measure.number);
#if 0
                    for (int nn=0; nn<SLUR_CONTINUE_NUM; nn++)
                    {
                        if (!slur_continue_info[nn].validate)
                        {
                            slur_continue_info[nn].above=slur.slur1_above;
                            slur_continue_info[nn].validate=YES;
                            slur_continue_info[nn].stop_staff=slur.stop_staff;
                            slur_continue_info[nn].right_line=slur.pair_ends.right_line;
                            slur_continue_info[nn].stop_offset=slur.offset.stop_offset;
                            slur_continue_info[nn].stop_measure=slur.offset.stop_measure-((ove_line.begin_bar+ove_line.bar_count)-measure.number);
                            break;
                        }
                    }
#endif

                }
            }
        }
    }
    
    //slur 连奏
    if (measure.slurs) {
        for (int i=0; i<measure.slurs.count; i++) {
            MeasureSlur *slur=[measure.slurs objectAtIndex:i];
            if (slur.staff>staff_count) {
                continue;
            }
            float x1 = start_x+MEAS_LEFT_MARGIN+slur.pos.start_offset*OFFSET_X_UNIT;
            //float x2=start_x+MEAS_LEFT_MARGIN;
            float x2=start_x+MEAS_LEFT_MARGIN+slur.offset.stop_offset*OFFSET_X_UNIT;
            
            float y1 = start_y+ [self lineToY:slur.pair_ends.left_line staff:slur.staff];
            float y2 = start_y+ [self lineToY:slur.pair_ends.right_line staff:slur.stop_staff];
            
            OveMeasure *next_measure=nil;
            for (int nn=0; nn<slur.offset.stop_measure; nn++) {
                if (measure.number+nn>=self.music.measures.count) {
                    next_measure=self.music.measures.lastObject;
                }else{
                    next_measure=[self.music.measures objectAtIndex:measure.number+nn];
                }
                x2+=next_measure.meas_length_size*OFFSET_X_UNIT+MEAS_LEFT_MARGIN+MEAS_RIGHT_MARGIN;
            }
            //if (next_measure)
            {
                OveNote *note1=slur.slur_start_note;
                OveNote *note2=slur.slur_stop_note;
                //寻找slur起点的note
                if (note1==nil) {
                    for (int nn=0; nn<measure.notes.count; nn++) {
                        OveNote *note=[measure.notes objectAtIndex:nn];
                        if(note.pos.start_offset>=slur.pos.start_offset && note.staff==slur.staff){
                            note1=note;
                            break;
                        }
                    }
                }
                
                //寻找slur终点的note
                if (note2==nil) {
                    if (measure.number+slur.offset.stop_measure>=self.music.measures.count) {
                        next_measure=self.music.measures.lastObject;
                    }else{
                        next_measure=[self.music.measures objectAtIndex:measure.number+slur.offset.stop_measure];
                    }
                    for (int nn=0; nn<next_measure.notes.count; nn++) {
                        OveNote *note=[next_measure.notes objectAtIndex:nn];
                        if(note.pos.start_offset>=slur.offset.stop_offset && note.staff==slur.stop_staff){
                            note2=note;
                            break;
                        }
                    }
                }
                if (note1) {
                    NoteElem *firstElem1=note1.note_elems.firstObject;
                    if (note1!=nil && firstElem1.offsetStaff==1 && slur.pair_ends.left_line>=0) {
                        y1+=STAFF_OFFSET[note1.staff];
                    }
                    y1=[self checkSlurY:slur measure:measure note:note1 start_x:start_x start_y:start_y slurY:y1];
                    //                        if (note1.isGrace && !note2.stem_up) {
                    //                            x2-=LINE_H;
                    //                        }
                }
                //如果slur终点的note的staff变化了，就改变y2坐标
                
                NoteElem *firstElem2=[note2.note_elems objectAtIndex:0];
                if (note2!=nil && firstElem2.offsetStaff==1 && slur.pair_ends.right_line>=0) {
                    y2+=STAFF_OFFSET[note2.staff];
                }
                if (note2==nil) {
                    NSLog(@"note2 is nil measure(%d) slur(%d)", measure.number, i);
                }else if(slur.offset.stop_measure==0 && !note1.isGrace){
                    y2=[self checkSlurY:slur measure:measure note:note2 start_x:start_x start_y:start_y slurY:y2];
                }
            }
            //x2+=slur.offset.stop_offset*OFFSET_X_UNIT;
            
            if (x1>=x2) { //倚音 yiyin
                x2=x1+LINE_H*1.0;
            }else {
                x1+=LINE_H*0.8;
            }
            if (x2<=screen_size.width-MARGIN_RIGHT) {
                //x2+=LINE_H*0.2;
                [self drawSvgCurveLine:2 x1:x1 y1:y1 x2:x2 y2:y2 above:slur.slur1_above];
            }else{
                //本行的前半段：
                if (slur.slur1_above) {
                    y2=y1-LINE_H*2;
                    if (slur.staff>0 && y2>start_y+STAFF_OFFSET[slur.staff-1]-LINE_H*3) {
                        y2=start_y+STAFF_OFFSET[slur.staff-1]-LINE_H*3;
                    }
                }else{
                    y2=y1+LINE_H*2;
                    if (slur.staff>0 && y2<start_y+STAFF_OFFSET[slur.staff-1]+LINE_H*6) {
                        y2=start_y+STAFF_OFFSET[slur.staff-1]+LINE_H*6;
                    }
                }
                [self drawSvgCurveLine:2 x1:x1 y1:y1 x2:screen_size.width-MARGIN_RIGHT y2:y2 above:slur.slur1_above];
                //如果要换行了，就把延长的slur保存下来。
#if 1
                for (int nn=0; nn<SLUR_CONTINUE_NUM; nn++)
                {
                    if (!slur_continue_info[nn].validate)
                    {
                        slur_continue_info[nn].above=slur.slur1_above;
                        slur_continue_info[nn].validate=YES;
                        slur_continue_info[nn].stop_staff=slur.stop_staff;
                        slur_continue_info[nn].right_line=slur.pair_ends.right_line;
                        slur_continue_info[nn].stop_offset=slur.offset.stop_offset;
                        slur_continue_info[nn].stop_measure=slur.offset.stop_measure-((ove_line.begin_bar+ove_line.bar_count)-measure.number);
                        break;
                    }
                }
#endif
            }
        }
    }
}

//tie 绑定
- (void)drawSvgTies:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y line:(OveLine *)ove_line
{
    int staff_count=(int)ove_line.staves.count;
    if (measure.ties) {
        for (int i=0; i<measure.ties.count; i++) {
            MeasureTie *tie=[measure.ties objectAtIndex:i];
            if (tie.staff>staff_count) {
                continue;
            }
            float x1 = start_x+MEAS_LEFT_MARGIN+tie.pos.start_offset*OFFSET_X_UNIT+1.0*LINE_H;
            if (tie.pos.start_offset<0) {
                x1-=2*MEAS_LEFT_MARGIN;
            }
            float y1 = start_y+ [self lineToY:tie.pair_ends.left_line staff:tie.staff];
            float y2 = start_y+ [self lineToY:tie.pair_ends.right_line staff:tie.staff];
            if (tie.above) {
                y1-=LINE_H;
                y2-=LINE_H;
            }else{
                y1+=LINE_H;
                y2+=LINE_H;
            }
            
            float x2=start_x;
            OveMeasure *next_measure;
            for (int nn=0; nn<tie.offset.stop_measure; nn++) {
                next_measure=[self.music.measures objectAtIndex:measure.number+nn];
                x2+=MEAS_LEFT_MARGIN+next_measure.meas_length_size*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN;
            }
            x2+=MEAS_LEFT_MARGIN+tie.offset.stop_offset*OFFSET_X_UNIT-0.0*LINE_H;
            
            if (x2<=screen_size.width-MARGIN_RIGHT) {
                [self drawSvgCurveLine:2 x1:x1 y1:y1 x2:x2 y2:y2 above:tie.above];
            }else{
#if 1
                //本行的前半段：
                [self drawSvgCurveLine:2 x1:x1 y1:y1 x2:screen_size.width-MARGIN_RIGHT y2:y1 above:tie.above];
                //如果要换行了，就把延长的tie保存下来。
                for (int nn=0; nn<SLUR_CONTINUE_NUM; nn++)
                {
                    if (!slur_continue_info[nn].validate)
                    {
                        slur_continue_info[nn].above=tie.above;
                        slur_continue_info[nn].validate=YES;
                        slur_continue_info[nn].stop_staff=tie.staff;
                        slur_continue_info[nn].right_line=tie.pair_ends.right_line;
                        slur_continue_info[nn].stop_offset=tie.offset.stop_offset;
                        slur_continue_info[nn].stop_measure=tie.offset.stop_measure-((ove_line.begin_bar+ove_line.bar_count)-measure.number);
                        break;
                    }
                }
#endif
            }
        }
    }
}

- (void)drawSvgPedals:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y line:(OveLine *)ove_line nextLine:(OveLine*)nextLine
{
    int staff_count=(int)ove_line.staves.count;
    //pedals
    if (measure.pedals) {
        for (int i=0;i<measure.pedals.count;  i++) {
            MeasurePedal *pedal=[measure.pedals objectAtIndex:i];
            if (pedal.staff>staff_count) {
                continue;
//                pedal.staff=staff_count;
            }
            float x1=start_x+MEAS_LEFT_MARGIN+pedal.pos.start_offset*OFFSET_X_UNIT;
            float y1=start_y+[self lineToY:pedal.pair_ends.left_line staff:pedal.staff];
            float x2;//=start_x+MEAS_LEFT_MARGIN+pedal.offset.stop_offset*OFFSET_X_UNIT;
            float y2=start_y+[self lineToY:pedal.pair_ends.left_line staff:pedal.staff];
            x2=start_x;
            OveMeasure *next_measure;
            for (int nn=0; nn<pedal.offset.stop_measure; nn++) {
                next_measure=[self.music.measures objectAtIndex:measure.number+nn];
                x2+=MEAS_LEFT_MARGIN+next_measure.meas_length_size*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN;
            }
            x2+=MEAS_LEFT_MARGIN+pedal.offset.stop_offset*OFFSET_X_UNIT;
            
            if (pedal.isLine) {
                LINE(x1, y1-5, x1+3, y1);
                LINE(x1+3, y1, x2-3, y2);//-----
                
                if (x2>screen_size.width-MARGIN_RIGHT) {
                    if (nextLine) {
                        y1=y1+STAFF_OFFSET[nextLine.staves.count-1]+ (4+GROUP_STAFF_NEXT)*LINE_H;
                        //analyze never read
//                        y2+=STAFF_OFFSET[nextLine.staves.count-1]+ (4+GROUP_STAFF_NEXT)*LINE_H;
                    }else{
                        y1=y1+STAFF_OFFSET[staff_count-1]+ (4+GROUP_STAFF_NEXT)*LINE_H;
                        //analyze never read
//                        y2+=STAFF_OFFSET[staff_count-1]+ (4+GROUP_STAFF_NEXT)*LINE_H;
                    }
                    x1=MARGIN_LEFT+STAFF_HEADER_WIDTH;
                    x2=x2-(screen_size.width-MARGIN_RIGHT)+x1;//+MEAS_LEFT_MARGIN;
                    //[self drawCurveLine:2 x1:x1 y1:y1 x2:x2 y2:y2 above:tie.above];
                    LINE(x1, y1, x2-3, y1);
                    LINE(x2, y1-5, x2-3, y1);
                }else{
                    LINE(x2, y1-5, x2-3, y1);
                }
            }else{
                ART_PEDAL_DOWN(x1-LINE_H*0, y1-LINE_H*0.5);//踩下踏板
                ART_PEDAL_UP(x2-LINE_H*1.5, y2-LINE_H*0.5); //松开踏板
            }
        }
    }
}
- (void)drawSvgTuplets:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y line:(OveLine *)ove_line
{
    int staff_count=(int)ove_line.staves.count;

    //tuplets
    if (measure.tuplets) {
        for (int i=0; i<measure.tuplets.count; i++) {
            OveTuplet *tuplet = [measure.tuplets objectAtIndex:i];
            if (tuplet.staff>staff_count) {
                continue;
            }
            float x1 = start_x+MEAS_LEFT_MARGIN+tuplet.pos.start_offset*OFFSET_X_UNIT;
            float y1 = start_y+ [self lineToY:tuplet.pair_ends.left_line staff:tuplet.staff];
            float y2 = start_y+ [self lineToY:tuplet.pair_ends.right_line staff:tuplet.staff];
            float x2;
            
            x2=start_x;
            OveMeasure *next_measure;
            for (int nn=0; nn<tuplet.offset.stop_measure; nn++) {
                next_measure=[self.music.measures objectAtIndex:measure.number+nn];
                x2+=MEAS_LEFT_MARGIN+next_measure.meas_length_size*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN;
            }
            x2+=MEAS_LEFT_MARGIN+tuplet.offset.stop_offset*OFFSET_X_UNIT;
            
            LINE(x1, y1, x1, y1+5);
            LINE(x2, y2, x2, y2+5);
            LINE(x1, y1, x2, y2);
            NSString* tmp_tuplet=[NSString stringWithFormat:@"%d",tuplet.tuplet];
            int tmp_x= (x1+x2)/2;
#ifdef OVE_IPHONE
            int tmp_y= (y1+y2)/2-15;
            TEXT(tmp_x, tmp_y, EXPR_FONT_SIZE, tmp_tuplet);
#else
            int tmp_y= (y1+y2)/2-16;
            TEXT(tmp_x, tmp_y, EXPR_FONT_SIZE, tmp_tuplet);
#endif
            //[tmp_tuplet drawAtPoint:CGPointMake(tmp_x, tmp_y) withFont:[UIFont systemFontOfSize:14]];
        }
    }
}
- (void)drawSvgLyrics:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y
{
    //lyrics
#ifndef OVE_IPHONE
    if (measure.lyrics) {
        for (int i=0; i<measure.lyrics.count; i++) {
            MeasureLyric *lyric=[measure.lyrics objectAtIndex:i];
            if (lyric.lyric_text.length>0) {
//                CGSize tmp_size=[lyric.lyric_text sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:EXPR_FONT_SIZE]}];
                CGSize tmp_size;
#if TARGET_OS_IPHONE
                tmp_size=[lyric.lyric_text sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:EXPR_FONT_SIZE]}];
#else
                tmp_size=[lyric.lyric_text sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:EXPR_FONT_SIZE]}];
#endif

                int tmp_x = start_x+MEAS_LEFT_MARGIN+lyric.pos.start_offset*OFFSET_X_UNIT-tmp_size.width*0.5;
                if (tmp_x<start_x+LINE_H) {
                    tmp_x=start_x+LINE_H;
                }
                
                int tmp_y = start_y+lyric.verse*LINE_H*2;
                if (lyric.offset.offset_y==0) {
                    tmp_y+=8*LINE_H;
                }else{
                    tmp_y-=lyric.offset.offset_y*OFFSET_Y_UNIT;
                }
                
                tmp_y+=STAFF_OFFSET[lyric.staff-1];
                TEXT(tmp_x, tmp_y-tmp_size.height*0.5, EXPR_FONT_SIZE, lyric.lyric_text);
            }else{
                NSLog(@"empty lyrics text at measure(%d)", measure.number);
            }
        }
    }
#endif
}
- (void)drawSvgDynamics:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y
{
    //harmony_guitar_framesharmony_guitar_frames
    if (measure.harmony_guitar_frames) {
        for (int i=0; i<measure.harmony_guitar_frames.count; i++) {
            HarmonyGuitarFrame *tmp=[measure.harmony_guitar_frames objectAtIndex:i];
            NSLog(@"measure(%d) root:%d bass:%d pos:[%d] type:%d", measure.number, tmp.root, tmp.bass, tmp.pos.start_offset, tmp.type);
            //int tmp_x = start_x+MEAS_LEFT_MARGIN+tmp.pos.start_offset*OFFSET_X_UNIT;
            //int tmp_y = start_y+8*LINE_H+lyric.offset.offset_y*OFFSET_Y_UNIT + lyric.verse*LINE_H*3;
            
            //CGSize tmp_size=[lyric.lyric_text sizeWithFont:[UIFont systemFontOfSize:12]];
            //[lyric.lyric_text drawAtPoint:CGPointMake(tmp_x-tmp_size.width*0.5, tmp_y-5) withFont:[UIFont italicSystemFontOfSize:12]];
        }
    }
    //dynamics
    if (measure.dynamics) {
        for (int i=0; i<measure.dynamics.count; i++) {
            OveDynamic *dyn=[measure.dynamics objectAtIndex:i];
            int tmp_x = start_x+MEAS_LEFT_MARGIN+dyn.pos.start_offset*OFFSET_X_UNIT;//-LINE_H;
            int tmp_y = start_y+0*LINE_H+dyn.offset_y*OFFSET_Y_UNIT;
            
            if (dyn.staff>=2) {
                tmp_y+= STAFF_OFFSET[dyn.staff-1]-1*LINE_H;
            }
            
            //NSString *str_dyn=@"none";
            if (dyn.dynamics_type==Dynamics_p) {
                //str_dyn = @"p";
                DYNAMICS_P(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_pp) {
                DYNAMICS_PP(tmp_x-2, tmp_y-0);
                //str_dyn = @"pp";
            }else if (dyn.dynamics_type==Dynamics_ppp) {
                DYNAMICS_PPP(tmp_x-2, tmp_y-0);
                //str_dyn = @"ppp";
            }else if (dyn.dynamics_type==Dynamics_pppp) {
                DYNAMICS_PPPP(tmp_x-2, tmp_y-0);
                //str_dyn = @"pppp";
            }else if (dyn.dynamics_type==Dynamics_mp) {
                DYNAMICS_MP(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_f) {
                DYNAMICS_F(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_ff) {
                DYNAMICS_FF(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_fff) {
                DYNAMICS_FFF(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_ffff) {
                DYNAMICS_FFFF(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_mf) {
                DYNAMICS_MF(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_sf) {
                DYNAMICS_SF(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_sff) {
                DYNAMICS_SFF(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_fz) {
                DYNAMICS_FZ(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_sfz) {
                DYNAMICS_SFZ(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_fp || dyn.dynamics_type==Dynamics_sffz) {
                DYNAMICS_FP(tmp_x-2, tmp_y-0);
            }else if (dyn.dynamics_type==Dynamics_sfp) {
                DYNAMICS_SFP(tmp_x-2, tmp_y-0);
            }else{
                NSLog(@"Error unknow dynamics_type=%d", dyn.dynamics_type);
            }
        }
    }
}
- (void)drawSvgExpresssions:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y
{
    //expresssions
    if (measure.expresssions) {
        for (int i=0; i<measure.expresssions.count; i++) {
            MeasureExpressions *expr=[measure.expresssions objectAtIndex:i];
            if (expr.exp_text.length>0) {
                int tmp_x = start_x+MEAS_LEFT_MARGIN+expr.pos.start_offset*OFFSET_X_UNIT;
                int tmp_y = start_y+LINE_H*1 + expr.offset_y*OFFSET_Y_UNIT;
                
                if (expr.staff>=2) {
                    tmp_y+= STAFF_OFFSET[expr.staff-1]-LINE_H*0;
                }else if (expr.offset_y<0) {
                    tmp_y-=LINE_H*3;
                }
                if (tmp_x<MARGIN_LEFT+STAFF_HEADER_WIDTH/2) {
                    tmp_x=MARGIN_LEFT+STAFF_HEADER_WIDTH/2;
                }
                if (tmp_y<30) {
                    tmp_y=30;
                }
                TEXT(tmp_x+2, tmp_y-5, EXPR_FONT_SIZE, expr.exp_text);
            }else{
                NSLog(@"empty expresssion text at measure(%d)", measure.number);
            }
        }
    }
}
- (void)drawSvgOctaveShift:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y line:(OveLine *)ove_line line_index:(int) line_index
{
    //octave shift 修改8度
    if (measure.octaves) {
        for (int i=0; i<measure.octaves.count; i++) {
            OctaveShift *octave=[measure.octaves objectAtIndex:i];
            static int octave_x1[2]={0,0};
            static int octave_y1[2]={0,0};
            static int octave_y_continue1[2]={0,0};//, octave_y_continue2;
            //static int start_line=0;
            int tmp_y=start_y+LINE_H*1+STAFF_OFFSET[octave.staff-1]+octave.offset_y*OFFSET_Y_UNIT-LINE_H;
            if (octave.octaveShiftType>=OctaveShift_8_Start && octave.octaveShiftType<=OctaveShift_Minus_15_Start)
            {
                octave_x1[octave.staff-1] = start_x+MEAS_LEFT_MARGIN+(octave.pos.start_offset/*+octave.length*/)*OFFSET_X_UNIT;
                if (octave_x1[octave.staff-1]<MEAS_LEFT_MARGIN + STAFF_HEADER_WIDTH) {
                    octave_x1[octave.staff-1]=MEAS_LEFT_MARGIN+STAFF_HEADER_WIDTH;
                }
                octave_y1[octave.staff-1] = tmp_y;
                octave_y_continue1[octave.staff-1]=octave_y1[octave.staff-1];
                //octave_y_continue2=octave_y1;
                if (octave.octaveShiftType==OctaveShift_8_Start)//8va提高8度
                {
                    OCTAVE_ATTAVA(octave_x1[octave.staff-1]-LINE_H*0.5, octave_y1[octave.staff-1]+1*LINE_H);
                }else if (octave.octaveShiftType==OctaveShift_Minus_8_Start)//8vb降低8度
                {
                    OCTAVE_ATTAVB(octave_x1[octave.staff-1]-LINE_H*0.5, octave_y1[octave.staff-1]+LINE_H);
                }else if (octave.octaveShiftType==OctaveShift_15_Start)//15va提高两个8度
                {
                    OCTAVE_QUINDICESIMA(octave_x1[octave.staff-1]-LINE_H*0.5, octave_y1[octave.staff-1]+1*LINE_H);
                }else if (octave.octaveShiftType==OctaveShift_Minus_15_Start)//15va降低两个8度
                {
                    TEXT(octave_x1[octave.staff-1]-LINE_H*0.5, octave_y1[octave.staff-1]+LINE_H, NORMAL_FONT_SIZE, @"15mb");
                }
                //start_line=line_index;
                for (int k=0; k<OCTAVE_CONTINUE_NUM; k++) {
                    if (!octave_continue_info[k].validate) {
                        octave_continue_info[k].validate=YES;
                        octave_continue_info[k].offset_y=octave.offset_y;
                        octave_continue_info[k].staff=octave.staff;
                        octave_continue_info[k].start_line=line_index;
                        octave_continue_info[k].octave_x1=octave_x1[octave.staff-1];
                        octave_continue_info[k].octave_y1=octave_y1[octave.staff-1];
                    }
                }
                
            }else if (octave.octaveShiftType>=OctaveShift_8_Stop && octave.octaveShiftType<=OctaveShift_Minus_15_Stop) {
                for (int k=0; k<OCTAVE_CONTINUE_NUM; k++) {
                    if (octave_continue_info[k].validate && octave_continue_info[k].staff==octave.staff) {
                        octave_continue_info[k].validate=NO;
                    }
                }
                //draw current line
                int octave_x2 = start_x+MEAS_LEFT_MARGIN+(octave.pos.start_offset/*+octave.length*/)*OFFSET_X_UNIT+LINE_H;
                if (octave.length>0) {
                    octave_x2 = start_x+MEAS_LEFT_MARGIN+(octave.length)*OFFSET_X_UNIT;
                }
                
                int octave_y2 = tmp_y;
                
                if (octave_y2!=octave_y1[octave.staff-1]) {
                    //                        if (octave_y2>octave_y1+4*LINE_H) {
                    //                            LINE_DOT(octave_x1+2*LINE_H,octave_y1, screen_size.width-MARGIN_RIGHT, octave_y1);
                    //                        }
                    LINE_DOT(MARGIN_LEFT+STAFF_HEADER_WIDTH,octave_y2, octave_x2, octave_y2);
                }else{
                    if (octave_x2<octave_x1[octave.staff-1]+3*LINE_H) {
                        octave_x2=octave_x1[octave.staff-1]+3*LINE_H;
                    }
                    LINE_DOT(octave_x1[octave.staff-1]+2*LINE_H, octave_y1[octave.staff-1], octave_x2, octave_y1[octave.staff-1]);
                }
                LINE(octave_x2-5, octave_y2, octave_x2, octave_y2);
                if (octave.octaveShiftType==OctaveShift_8_Stop || octave.octaveShiftType==OctaveShift_15_Start)
                {
                    LINE(octave_x2, octave_y2, octave_x2, octave_y2+8);
                }else{
                    LINE(octave_x2, octave_y2, octave_x2, octave_y2-8);
                }
            }else if(octave.octaveShiftType>=OctaveShift_8_Continue && octave.octaveShiftType<=OctaveShift_Minus_15_Continue){
                //                    if (measure.number==ove_line.begin_bar+ove_line.bar_count-1) {//本行最后一个小节
                //                        if (tmp_y!=octave_y_continue1) {
                //                            LINE_DOT(MARGIN_LEFT+STAFF_HEADER_WIDTH, tmp_y, screen_size.width-MARGIN_RIGHT, tmp_y);
                //                        }else{
                //                            LINE_DOT(octave_x1+6, tmp_y, screen_size.width-MARGIN_RIGHT, tmp_y);
                //                        }
                //                        //octave_y_continue1=octave_y_continue2;
                //                        octave_y_continue1=tmp_y;
                //                    }
            }else if(octave.octaveShiftType==OctaveShift_8_StartStop || octave.octaveShiftType==OctaveShift_Minus_8_StartStop)
            {
                //draw current line
                octave_x1[octave.staff-1] = 12+start_x+MEAS_LEFT_MARGIN+(octave.pos.start_offset/*+octave.length*/)*OFFSET_X_UNIT;
                int octave_x2 = start_x+MEAS_LEFT_MARGIN+(/*octave.pos.start_offset+*/octave.length)*OFFSET_X_UNIT;
                octave_y1[octave.staff-1] = tmp_y;//start_y+octave.offset_y*OFFSET_Y_UNIT;
                LINE_DOT(octave_x1[octave.staff-1]+LINE_H, octave_y1, octave_x2, octave_y1);
                //DRAW_DOT_LINE_C(octave_x1+5, octave_x2, octave_y1, 1,[[UIColor blackColor] CGColor]);
                LINE(octave_x2-5, octave_y1[octave.staff-1], octave_x2, octave_y1[octave.staff-1]);
                
                if (octave.octaveShiftType==OctaveShift_8_StartStop)//8va提高8度
                {
                    OCTAVE_ATTAVA(octave_x1[octave.staff-1]-LINE_H*0.5, octave_y1[octave.staff-1]-LINE_H);
                    LINE(octave_x2, octave_y1[octave.staff-1], octave_x2, octave_y1[octave.staff-1]+8);
                }else if (octave.octaveShiftType==OctaveShift_Minus_8_Start)//8vb降低8度
                {
                    OCTAVE_ATTAVB(octave_x1[octave.staff-1]-LINE_H*0.5, octave_y1[octave.staff-1]-LINE_H);
                    LINE(octave_x2, octave_y1[octave.staff-1], octave_x2, octave_y1[octave.staff-1]-8);
                }else if (octave.octaveShiftType==OctaveShift_15_Start)//15va提高两个8度
                {
                    OCTAVE_QUINDICESIMA(octave_x1[octave.staff-1]-LINE_H*0.5, octave_y1[octave.staff-1]-LINE_H);
                    LINE(octave_x2, octave_y1[octave.staff-1], octave_x2, octave_y1[octave.staff-1]+8);
                }else if (octave.octaveShiftType==OctaveShift_Minus_15_Start)//15va降低两个8度
                {
                    TEXT(octave_x1[octave.staff-1]-LINE_H*0.5, octave_y1[octave.staff-1]-LINE_H, NORMAL_FONT_SIZE, @"15mb");
                    LINE(octave_x2, octave_y1[octave.staff-1], octave_x2, octave_y1[octave.staff-1]-8);
                }
            }else{
                NSLog(@"Error: unknow octave type=%d at measure=%d", octave.octaveShiftType, measure.number);
            }
        }
    }
    if (measure.number==ove_line.begin_bar+ove_line.bar_count-1) {
        for (int k=0; k<OCTAVE_CONTINUE_NUM; k++) {
            if (octave_continue_info[k].validate) {
                //draw: continue lines
                if (line_index==octave_continue_info[k].start_line) {
                    LINE_DOT(octave_continue_info[k].octave_x1+2*LINE_H,octave_continue_info[k].octave_y1, screen_size.width-MARGIN_RIGHT, octave_continue_info[k].octave_y1);
                }else if (line_index>octave_continue_info[k].start_line) {
                    //OveLine *line=self.music.lines[line_index];
                    float continue_y=ove_line.y_offset*OFFSET_Y_UNIT+MARGIN_TOP;
                    continue_y+= 0*LINE_H + STAFF_OFFSET[octave_continue_info[k].staff-1]+octave_continue_info[k].offset_y*OFFSET_Y_UNIT;
                    
                    LINE_DOT(MARGIN_LEFT+STAFF_HEADER_WIDTH, continue_y, screen_size.width-MARGIN_RIGHT, continue_y);
                }
            }
        }
    }
}
- (void)drawSvgGlissandos:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y line:(OveLine *)ove_line line_index:(int) line_index line_count:(int)line_count
{
    int staff_count=(int)ove_line.staves.count;
    //glissandos 滑音
    if (measure.glissandos)
    {
        for (int i=0; i<measure.glissandos.count; i++) {
            MeasureGlissando *gliss=[measure.glissandos objectAtIndex:i];
            int tmp_x = start_x+MEAS_LEFT_MARGIN+gliss.pos.start_offset*OFFSET_X_UNIT;
            int tmp_y = start_y-3*LINE_H+[self lineToY:gliss.pair_ends.left_line staff:1];
            {
                int x2=start_x+5;
                OveMeasure *next_measure;
                for (int nn=0; nn<gliss.offset.stop_measure; nn++) {
                    next_measure=[self.music.measures objectAtIndex:measure.number+nn];
                    x2+=MEAS_LEFT_MARGIN+next_measure.meas_length_size*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN;
                }
                x2+=MEAS_LEFT_MARGIN+gliss.offset.stop_offset*OFFSET_X_UNIT;
                if (gliss.straight_wavy) { //wavy
                    LINE_WAVY_HORIZONTAL(tmp_x, x2, tmp_y);
                    //DRAW_WAVY_C(tmp_x, x2, tmp_y, 2, [[UIColor blackColor] CGColor]);
                    if (x2>screen_size.width-MARGIN_RIGHT && line_index<line_count-1) {
                        tmp_x=MARGIN_LEFT+STAFF_HEADER_WIDTH;
                        tmp_y+=STAFF_OFFSET[staff_count-1]+(4+GROUP_STAFF_NEXT)*LINE_H;
                        x2=x2-(screen_size.width-MARGIN_RIGHT)+tmp_x;
                        LINE_WAVY_HORIZONTAL(tmp_x, x2, tmp_y);
                        //DRAW_WAVY_C(tmp_x, x2, tmp_y, 2, [[UIColor blackColor] CGColor]);
                    }
                }else{ //straight
                    LINE_W(tmp_x, tmp_y, x2, tmp_y, WAVY_LINE_WIDTH);
                    if (x2>screen_size.width-MARGIN_RIGHT && line_index<line_count-1) {
                        tmp_x=MARGIN_LEFT+STAFF_HEADER_WIDTH;
                        tmp_y+=STAFF_OFFSET[staff_count-1]+(4+GROUP_STAFF_NEXT)*LINE_H;
                        x2=x2-(screen_size.width-MARGIN_RIGHT)+tmp_x;
                        LINE_W(tmp_x, tmp_y, x2, tmp_y, WAVY_LINE_WIDTH);
                    }
                }
            }
        }
    }
}
- (void)drawSvgWedges:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y line:(OveLine *)ove_line line_index:(int) line_index line_count:(int)line_count
{
    int staff_count=(int)ove_line.staves.count;
    //wedges
    if (measure.wedges) {
        for (int i=0; i<measure.wedges.count; i++) {
            OveWedge *wedge=[measure.wedges objectAtIndex:i];
            int tmp_x = start_x+MEAS_LEFT_MARGIN+wedge.pos.start_offset*OFFSET_X_UNIT;
            int tmp_y = start_y+LINE_H*3+wedge.offset_y*OFFSET_Y_UNIT;
            if (wedge.staff>0 && wedge.staff<=STAFF_COUNT) {
                tmp_y+=STAFF_OFFSET[wedge.staff-1];
            }
            if (wedge.wedgeOrExpression) //wedge
            {
                int x2=start_x;
                OveMeasure *next_measure;
                for (int nn=0; nn<wedge.offset.stop_measure; nn++) {
                    next_measure=[self.music.measures objectAtIndex:measure.number+nn];
                    x2+=MEAS_LEFT_MARGIN+next_measure.meas_length_size*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN;
                }
                x2+=MEAS_LEFT_MARGIN+wedge.offset.stop_offset*OFFSET_X_UNIT;
                if (x2>screen_size.width) {
                    NSLog(@"Error wedge is too long, x2=%d", x2);
                }
                if (wedge.wedgeType==Wedge_Cres_Line) { //<
                    if (x2>screen_size.width-MARGIN_RIGHT && line_index<line_count-1) {
                        LINE(tmp_x, tmp_y, screen_size.width-MARGIN_RIGHT, tmp_y-5);
                        LINE(tmp_x, tmp_y, screen_size.width-MARGIN_RIGHT, tmp_y+5);
                        
                        tmp_x=MARGIN_LEFT+STAFF_HEADER_WIDTH;
                        tmp_y+=STAFF_OFFSET[staff_count-1]+(4+GROUP_STAFF_NEXT)*LINE_H;
                        //x2=x2-(screen_size.width-MARGIN_RIGHT)+tmp_x;
                        x2=x2-(screen_size.width-MARGIN_RIGHT)+tmp_x;//-MEAS_LEFT_MARGIN-MEAS_RIGHT_MARGIN;
                        LINE(tmp_x, tmp_y-2, x2, tmp_y-5);
                        LINE(tmp_x, tmp_y+2, x2, tmp_y+5);
                    }else{
                        LINE(tmp_x, tmp_y, x2, tmp_y-5);
                        LINE(tmp_x, tmp_y, x2, tmp_y+5);
                    }
                }else if (wedge.wedgeType==Wedge_Decresc_Line) { //>
                    if (x2>screen_size.width-MARGIN_RIGHT && line_index<line_count-1) {
                        LINE(tmp_x, tmp_y-5, screen_size.width-MARGIN_RIGHT, tmp_y);
                        LINE(tmp_x, tmp_y+5, screen_size.width-MARGIN_RIGHT, tmp_y);
                        
                        tmp_x=MARGIN_LEFT+STAFF_HEADER_WIDTH;
                        tmp_y+=STAFF_OFFSET[staff_count-1]+(4+GROUP_STAFF_NEXT)*LINE_H;
                        x2=x2-(screen_size.width-MARGIN_RIGHT)+tmp_x;
                        LINE(tmp_x, tmp_y-5, x2, tmp_y);
                        LINE(tmp_x, tmp_y+5, x2, tmp_y);
                    }else{
                        LINE(tmp_x, tmp_y-5, x2, tmp_y);
                        LINE(tmp_x, tmp_y+5, x2, tmp_y);
                    }
                }else if (wedge.wedgeType==Wedge_Double_Line) { //<>
                    LINE(tmp_x, tmp_y-5, x2, tmp_y);
                    LINE(tmp_x, tmp_y+5, x2, tmp_y);
                    if (x2>screen_size.width-MARGIN_RIGHT && line_index<line_count-1) {
                        tmp_x=MARGIN_LEFT+STAFF_HEADER_WIDTH;
                        tmp_y+=STAFF_OFFSET[staff_count-1]+(4+GROUP_STAFF_NEXT)*LINE_H;
                        x2=x2-(screen_size.width-MARGIN_RIGHT)+tmp_x;
                        LINE(tmp_x, tmp_y, (tmp_x+x2)/2, tmp_y-5);
                        LINE(tmp_x, tmp_y, (tmp_x+x2)/2, tmp_y+5);
                        LINE((tmp_x+x2)/2, tmp_y-5, x2, tmp_y);
                        LINE((tmp_x+x2)/2, tmp_y+5, x2, tmp_y);
                    }
                }else{
                    NSLog(@"Unknow wedge type=%d", wedge.wedgeType);
                }
            }else if (wedge.expression_text.length>0){ //expression
                //tmp_y = start_y+LINE_H*6;
                //                    tmp_y = start_y+LINE_H*2+wedge.offset_y*OFFSET_Y_UNIT;
                TEXT(tmp_x, tmp_y-6, EXPR_FONT_SIZE, wedge.expression_text);
                //[wedge.expression_text drawAtPoint:CGPointMake(tmp_x, tmp_y-6) withFont:[UIFont italicSystemFontOfSize:18]];
            }else{
                NSLog(@"empty wedge.expression_text text at measure(%d)", measure.number);
            }
        }
    }
}

- (void)drawSvgClefs:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y line:(OveLine *)ove_line
{
    if (measure.number<self.music.measures.count-1) {
        //if next measure changed clef, show it at the end of current measure
        OveMeasure *nextMeasure=self.music.measures[measure.number+1];
        for (MeasureClef *clef in nextMeasure.clefs) {
            if (clef.pos.start_offset==0 && clef.pos.tick==0) {
                int tmp_x=start_x+MEAS_LEFT_MARGIN+measure.meas_length_size*OFFSET_X_UNIT-LINE_H*0.5;
                if (measure.right_barline==Barline_RepeatRight) {
                    tmp_x-=LINE_H*1;
                }
                int tmp_y=start_y;
                if (clef.staff>=2) {
                    tmp_y+=STAFF_OFFSET[clef.staff-1];
                }
                if (clef.clef==Clef_Treble) {
                    CLEF_TREBLE(tmp_x, tmp_y+3.0*LINE_H, 0.7);
                }else{
                    CLEF_BASS(tmp_x, tmp_y+1.0*LINE_H, 0.7);
                }
            }
        }
    }
    if (measure.clefs!=nil) {
        for (MeasureClef *clef in measure.clefs) {
            //int tmp_x=start_x+MEAS_LEFT_MARGIN+clef.pos.start_offset*OFFSET_X_UNIT-20;
            //int tmp_x=start_x+MEAS_LEFT_MARGIN+clef.pos.start_offset*OFFSET_X_UNIT-2*LINE_H;
            if (clef.pos.start_offset==0 && clef.pos.tick==0 && measure.number>0) {
                continue;
            }
            int tmp_x;
            if (clef.pos.tick==measure.meas_length_tick) {
                tmp_x=start_x+MEAS_LEFT_MARGIN+measure.meas_length_size*OFFSET_X_UNIT-LINE_H*0.5;
                if (measure.right_barline!=Barline_Default) {
                    tmp_x-=LINE_H*1;
                }
            }else if (measure.number==0) {
                tmp_x=start_x+MEAS_LEFT_MARGIN+clef.pos.start_offset*OFFSET_X_UNIT+2.0*LINE_H;
            }else if (measure.number==ove_line.begin_bar) {
                tmp_x=start_x+MEAS_LEFT_MARGIN+clef.pos.start_offset*OFFSET_X_UNIT+2.0*LINE_H;
            }else{
                tmp_x=start_x+MEAS_LEFT_MARGIN+clef.pos.start_offset*OFFSET_X_UNIT+2.0*LINE_H;
            }
            
            int tmp_y=start_y;
            if (clef.staff>=2) {
                tmp_y+=STAFF_OFFSET[clef.staff-1];
            }
            if (clef.clef==Clef_Treble) {
                CLEF_TREBLE(tmp_x-LINE_H, tmp_y+3.0*LINE_H, 0.7);
                //CLEF_BASS(tmp_x, tmp_y+1.0*LINE_H, 0.7);
            }else{
                //CLEF_TREBLE(tmp_x, tmp_y+3.0*LINE_H, 0.7);
                CLEF_BASS(tmp_x, tmp_y+1.0*LINE_H, 0.7);
            }
        }
    }
}
- (void)drawSvgRest:(OveNote*)note measure:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y
{
    if (!note.isRest) {
        return;
    }
    int line=note.line;
    //check other voice note
//    if (note.line==0)
//    {
//        NSArray *notes = [measure.sorted_notes objectForKey:[NSString stringWithFormat:@"%d", note.pos.tick]];
//        for (OveNote *tmp_note in notes) {
//            if (note.staff==tmp_note.staff && note.voice!=tmp_note.voice) {
//                if (tmp_note.voice>note.voice && tmp_note.line>-4) {
//                    line=tmp_note.line+4;
//                }else if (tmp_note.voice<note.voice && tmp_note.line<6) {
//                    line=tmp_note.line-6;
//                }
//                break;
//            }
//        }
//    }
    float x=start_x+MEAS_LEFT_MARGIN+note.pos.start_offset*OFFSET_X_UNIT;
    float y = start_y + [self lineToY:line staff:note.staff];
    
    if (note.note_type==Note_Whole) { //全休止
        x = start_x+MEAS_LEFT_MARGIN+measure.meas_length_size*OFFSET_X_UNIT/2 - LINE_H;
        if (note.line==0) {
            y = y - LINE_H*1+2;
        }else{
//            y+=2;
            y = y - LINE_H*1+2;
        }
        LINE_W(x, y, x+LINE_H*1.2, y, LINE_H*0.5);
    }else if (note.note_type==Note_Half) { //二分休止符
        LINE_W(x+LINE_H*0.5, y-2, x+LINE_H*2.0, y-2, LINE_H/2);
    }else if (note.note_type == Note_Quarter) {
        RESET_QUARTER(x-LINE_H*0, y+LINE_H*0);
    }else if (note.note_type == Note_Eight)
    {
        RESET_EIGHT(x-LINE_H*0, y-LINE_H*0.5);
    }else if (note.note_type == Note_Sixteen)
    {
        RESET_16(x+LINE_H*0.0, y+LINE_H*0.0);
    }else if (note.note_type == Note_32)
    {
        RESET_32(x+LINE_H*0.0, y+LINE_H*1.5);
    }else
    {
        NSLog(@"Error: unknow rest flag. note_type=%d at measure=%d", note.note_type, measure.number);
    }
    note.display_note_x=x;
    if (note.isDot) { //符点
        float dot_x=x+LINE_H*1.5;
        if (note.note_type==Note_Whole || note.note_type==Note_Half) {
            dot_x+=LINE_H*1.5;
        }
        float dot_y=y-LINE_H*0.5;
        if (note.line%2!=0) {
            dot_y+=LINE_H*0.5;
        }
        for (int dot=0; dot<note.isDot; dot++) {
            NOTE_DOT(dot_x+LINE_H*dot, dot_y);
        }
    }
    for (int nn=0; nn<note.note_arts.count; nn++) {
        NoteArticulation *note_art;
        note_art = [note.note_arts objectAtIndex:nn];
        ArticulationType art_type=note_art.art_type;
        BOOL art_placement_above=note_art.art_placement_above;
        //NSLog(@"Measure(%d) note_arts(%ld):0x%x", measure.number, (unsigned long)note.note_arts.count,art_type);
        
        float art_y=y, art_x=x;
        
        if (art_placement_above) {
            if (note_art.offset==nil) {
                art_y-=LINE_H*2;
            }else{
                art_y-=note_art.offset.offset_y*OFFSET_Y_UNIT;
            }
        }else{
            if (note_art.offset==nil) {
                art_y+=LINE_H*1;
            }else{
                art_y+=note_art.offset.offset_y*OFFSET_Y_UNIT;
            }
        }
        art_x+=note_art.offset.offset_x*OFFSET_X_UNIT;
        
        int staff_start_y=start_y+STAFF_OFFSET[note.staff-1];
        if (art_type==Articulation_Pedal_Down || art_type==Articulation_Pedal_Up) {
            staff_start_y=start_y;
        }
        if (![self drawSvgArt:note_art above:art_placement_above x:art_x y:art_y start_y:staff_start_y])
        {
            
        }
    }
}

- (void)drawSvgTrill:(NoteArticulation*)note_art measure:(OveMeasure*)measure note:(OveNote*)note x:(float)x art_y:(float)art_y
{
    /*
     trillNoteType 颤音
     演奏方法：可以从主音／上方助音／下方助音（或乐谱上指示的小音符）开始快速演奏，基本按照32分音符的速度,可以回音结束（或乐谱上指示的小音符结束）。
     如： C的颤音:
     (1) 可以从主音开始：C,D,C,D,C,D .....D,C,B,C
     (2) 可以从上方助音开始：D,C,D,C,D,C .....D,C,B,C
     (3) 可以从下方助音开始：B,C,D,C,D,C .....D,C,B,C
     */
    if (note_art.trillNoteType >= Note_Sixteen && note_art.trillNoteType<=Note_256)
    {
//        int staff=note.staff;
//        if (art_y>start_y+STAFF_OFFSET[staff-1]+LINE_H) {
//            art_y=start_y+STAFF_OFFSET[staff-1]+LINE_H;
//        }
        int tmp_y=art_y;// art_y-LINE_H*1;
        int x2=0;
        if (note_art.has_wavy_line) {
            x2=x+2*LINE_H;
            OveMeasure *stop_measure=measure;
            if (note_art.wavy_stop_measure>0) {
                for (int mmm=0; mmm<=note_art.wavy_stop_measure && mmm<self.music.measures.count; mmm++) {
                    stop_measure=self.music.measures[mmm+measure.number];
                    if (mmm==0) {
                        x2+=(measure.meas_length_size-note.pos.start_offset)*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN;
                    }else if (mmm==note_art.wavy_stop_measure){
                        x2+=MEAS_LEFT_MARGIN;
                    }else{
                        x2+=stop_measure.meas_length_size*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN+MEAS_LEFT_MARGIN;
                    }
                }
            }
            OveNote *stop_note;
            if (note_art.wavy_stop_note<stop_measure.notes.count) {
                stop_note=stop_measure.notes[note_art.wavy_stop_note];
                if (note_art.wavy_stop_note<stop_measure.notes.count-1) {
                    OveNote *next_note=stop_measure.notes[note_art.wavy_stop_note+1];
                    if (next_note.staff!=stop_note.staff) {
                        x2+=(stop_measure.meas_length_size-stop_note.pos.start_offset)*OFFSET_X_UNIT;
                    }else{
                        x2+=(next_note.pos.start_offset-stop_note.pos.start_offset)*OFFSET_X_UNIT;
                    }
                }else{
                    x2+=(stop_measure.meas_length_size-stop_note.pos.start_offset)*OFFSET_X_UNIT;
                }
            }else{
                stop_note=stop_measure.notes.lastObject;
            }
            x2+=stop_note.pos.start_offset*OFFSET_X_UNIT;
        }
        if (note_art.art_placement_above) {
            ART_TRILL(x-3, tmp_y);
            if (note_art.has_wavy_line) {
                LINE_WAVY_HORIZONTAL(x+2*LINE_H, x2, tmp_y);
            }
        }else
        {
            ART_TRILL(x-3, art_y+LINE_H*1.7+2);
            if (note_art.has_wavy_line) {
                LINE_WAVY_HORIZONTAL(x+2*LINE_H, x2, tmp_y);
            }
        }
        if (note_art.accidental_mark==Accidental_Natural) {
            FLAG_STOP(x+LINE_H, tmp_y-1.5*LINE_H, 1);
        }else if (note_art.accidental_mark==Accidental_Sharp) {
            FLAG_SHARP(x+LINE_H, tmp_y-1.5*LINE_H, 1);
        }else if (note_art.accidental_mark==Accidental_Flat) {
            FLAG_FLAT(x+LINE_H, tmp_y-1.5*LINE_H, 1);
        }
    }
}


- (float)drawSvgMeasure:(OveMeasure*)measure startX:(float)start_x startY:(float)start_y line:(OveLine *)ove_line line_index:(int) line_index line_count:(int)line_count
{
    float x = start_x;
    int staff_count=(int)ove_line.staves.count;// clefEveryStaff.count;
    int last_staff_lines=5;
    if (staff_count>0)
    {
        LineStaff *line_staff=[ove_line.staves objectAtIndex:staff_count-1];
        ClefType clef= line_staff.clef;//[[clefEveryStaff objectAtIndex:staff_count-1] intValue];
        if (clef==Clef_TAB) {
            last_staff_lines=6;
        }
    }
    [self drawSvgRepeat:measure startX:start_x startY:start_y];
    
    //变调
    if (measure.key && measure.key.key!=measure.key.previousKey && ove_line.begin_bar!=measure.number) {
        int key=measure.key.key;
        int previousKey=measure.key.previousKey;
        if (key>=0 && previousKey>key) {
            previousKey-=key;
            float tmp_x=x-2*abs(previousKey);
            [self drawSvgDiaohaoWithClef:Clef_Treble fifths:previousKey x:tmp_x startY:start_y stop:YES];
            [self drawSvgDiaohaoWithClef:Clef_Bass fifths:previousKey x:tmp_x startY:start_y+STAFF_OFFSET[1] stop:YES];
            //start_x+=DIAOHAO_WIDTH;
            start_x+=0+9*abs(previousKey);
            x=start_x;
        }else
        {
            if (measure.key.previousKey!=0 && (measure.key.previousKey>0 && measure.key.key<measure.key.previousKey)) {
                float tmp_x=x-9*abs(previousKey);
                [self drawSvgDiaohaoWithClef:Clef_Treble fifths:previousKey x:tmp_x startY:start_y stop:YES];
                [self drawSvgDiaohaoWithClef:Clef_Bass fifths:previousKey x:tmp_x startY:start_y+STAFF_OFFSET[1] stop:YES];
                //start_x+=DIAOHAO_WIDTH;
                start_x+=0+9*abs(previousKey);
                x=start_x;
            }
        }

        last_fifths=key;
        [self drawSvgDiaohaoWithClef:Clef_Treble fifths:key x:x-2*LINE_H startY:start_y stop:NO];
        [self drawSvgDiaohaoWithClef:Clef_Bass fifths:key x:x-2*LINE_H startY:start_y+STAFF_OFFSET[1] stop:NO];
        //start_x+=DIAOHAO_WIDTH;
        start_x+=9+9*abs(key);
    }
    
    //meas_texts
    //NSLog(@"measure:%d", measure.number);
    [self drawSvgTexts:measure startX:start_x startY:start_y];
    
    //measure.images
    if (measure.images) {
        for (OveImage *image in measure.images) {
            NSString *imgFile=image.source;
            if (!([image.source hasPrefix:@"file:"] || [image.source hasPrefix:@"http"])) {
                imgFile = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:image.source];
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:imgFile]) {
                float x1 = start_x+MEAS_LEFT_MARGIN+(image.pos.start_offset+image.offset_x)*OFFSET_X_UNIT;
                float y1 = start_y + LINE_H*2 + (image.offset_y)*OFFSET_Y_UNIT;
                NSURL *url=[NSURL fileURLWithPath:imgFile];
                IMAGE(x1, y1, image.width, image.height, url);
            }
        }
    }
    if (measure.notes && measure.notes.count>0) {
        
        //计算每个beam的位置 slurs
        for (int beam_index=0; beam_index<measure.beams.count; beam_index++) {
            OveBeam *beam=[measure.beams objectAtIndex:beam_index];
            [self getBeamRect:beam start_x:start_x start_y:start_y measure:measure reload:YES];
        }
        OveLine *nextLine;
        if (line_index<self.music.lines.count-1) {
            nextLine=self.music.lines[line_index+1];
        }
        [self drawSvgSlurs:measure startX:start_x startY:start_y line:ove_line];
        [self drawSvgTies:measure startX:start_x startY:start_y line:ove_line];
        [self drawSvgPedals:measure startX:start_x startY:start_y line:ove_line nextLine:nextLine];
        [self drawSvgTuplets:measure startX:start_x startY:start_y line:ove_line];
        [self drawSvgLyrics:measure startX:start_x startY:start_y];
        [self drawSvgDynamics:measure startX:start_x startY:start_y];
        [self drawSvgExpresssions:measure startX:start_x startY:start_y];
        [self drawSvgOctaveShift:measure startX:start_x startY:start_y line:ove_line line_index:line_index];
        [self drawSvgGlissandos:measure startX:start_x startY:start_y line:ove_line line_index:line_index line_count:line_count];
        [self drawSvgWedges:measure startX:start_x startY:start_y line:ove_line line_index:line_index line_count:line_count];
        
        /*
        if (measure.decorators!=nil) {
            for (int i=0; i<measure.decorators.count; i++) {
                MeasureDecorators *deco=[measure.decorators objectAtIndex:i];
                if (deco.decoratorType==Decorator_Articulation) {
                    float tmp_x = start_x + MEAS_LEFT_MARGIN + deco.pos.start_offset*OFFSET_X_UNIT+LINE_H*0.5;
                    float tmp_y = start_y + 2.0*LINE_H+ deco.offset_y*OFFSET_Y_UNIT + STAFF_OFFSET[deco.staff-1];// note_art->art_offset.offset_y*OFFSET_Y_UNIT;
                    
                    if(![self drawSvgArt:deco.artType above:(deco.offset_y<0) x:tmp_x y:tmp_y start_y:start_y])
                    {
                        NSLog(@"Error unknown deco art_type=0x%x in measure=%d",deco.artType, measure.number);
                    }
                }else{
                    NSLog(@"decoratorType=0x%x at measure=%d", deco.decoratorType, measure.number);
                }
            }
        }
        */
        [self drawSvgClefs:measure startX:start_x startY:start_y line:ove_line];
        
        for (int i=0;i<measure.notes.count;i++) {
            OveNote *note = [measure.notes objectAtIndex:i];
            float y=start_y;    //每一个附点中心的y坐标
            int staff=note.staff;
            
            if (note.staff>staff_count) {
                continue;
            }
            /*
            if (i==0 && note.staff==2)//补充一个全休止
            {
                x = start_x+MEAS_LEFT_MARGIN+measure.meas_length_size*OFFSET_X_UNIT/2 - LINE_H;
                y = start_y + LINE_H*1+2;
                LINE_W(x, y, x+LINE_H*1.2, y, LINE_H*0.4);
            }*/
            //每个附点的符干左边沿x坐标
            x = start_x+MEAS_LEFT_MARGIN+note.pos.start_offset*OFFSET_X_UNIT;
            
            if (note.isRest)
            {
                [self drawSvgRest:note measure:measure startX:start_x startY:start_y];
                
            }else // !isRest
            {
                //NoteElem *first_note_elem=[note.note_elems objectAtIndex:0];
                float note_y0=0;//top note y
                float note_y1;//bottom note y
                
                NoteElem *note_elem0=note.sorted_note_elems.lastObject;
                note_y0 = start_y + [self lineToY:note_elem0.line staff:staff];
                if (note.sorted_note_elems.count>1) {
                    NoteElem *note_elem1=note.sorted_note_elems.firstObject;
                    note_y1 = start_y + [self lineToY:note_elem1.line staff:staff];
                }else{
                    note_y1 = note_y0;
                }
                float note_up_y=note_y0;
                float note_below_y=note_y1;
                if (note.note_type>Note_Whole) {
                    if (note.stem_up) {
                        note_up_y=note_y0-3.5*LINE_H;
                    }else{
                        note_below_y=note_y1+3.5*LINE_H;
                    }
                }
//                float note_left_x=x;
//                float note_right_x=x+LINE_H;
                
                BOOL note_tailed_drawed=NO;
                float note_x=x;
                float stem_x=note_x+0.5;
                float delta_stem_x=0;
                float acc_x=note_x;
                note.display_note_x=note_x;

                for (int elem_nn=0; elem_nn<note.note_elems.count; elem_nn++)
                {
                    NoteElem *note_elem=[note.note_elems objectAtIndex:elem_nn];
                    note_x=x;
                    
                    
                    if (note_elem.note<self.minNoteValue) {
                        self.minNoteValue=note_elem.note;
                    }
                    if (note_elem.note>self.maxNoteValue) {
                        self.maxNoteValue=note_elem.note;
                    }
                    
                    //y:符头中心点的坐标
                    staff = note.staff+note_elem.offsetStaff;
                    y = start_y + [self lineToY:note_elem.line staff:staff];
//                    if (elem_nn==0) {
//                        note_y0=y;
//                    }else if(elem_nn==note.note_elems.count-1){
//                        note_y1=y;
//                    }
                    //TAB 谱表
                    BOOL isTABStaff=NO;
                    if(note.staff-1<ove_line.staves.count){
                        LineStaff *line_staff=[ove_line.staves objectAtIndex:staff_count-1];
                        ClefType clef= line_staff.clef;
                        //ClefType clef=[[clefEveryStaff objectAtIndex:note.staff-1] intValue];
                        if (clef==Clef_TAB) {
                            isTABStaff=YES;
                        }
                    }
                    if (isTABStaff) {
                        NSString *tmp=[NSString stringWithFormat:@"%d",note_elem.head_type-NoteHead_Guitar_0];
                        TEXT(note_x-1, y-LINE_H*1.2, NORMAL_FONT_SIZE, tmp);
                        continue;
                    }
                    
                    //符头
                    BOOL dontDrawHead=NO;
                    if (measure.show_number==87 && note.note_elems.count==2 && note.pos.tick==0) {
                        NoteElem *elem=note.note_elems.firstObject;
                        NoteElem *top=note.note_elems.lastObject;
                        NSLog(@"eee %d %d",elem.line,top.line);
                    }
                    
                    if (note.note_elems.count>1)
                    {
                        if (!note.stem_up) {
                            //和弦里和后一个音相差1,就把这个音反转显示。 0,-5, -2, 0, 0 -1 -6, -6, -1, 2
                            if (elem_nn<note.note_elems.count-1) {
                                NoteElem *prev_elem=[note.note_elems objectAtIndex:elem_nn+1];
                                if (!prev_elem.display_revert) {
                                    int delta = note_elem.line-prev_elem.line;
                                    if (delta==1||delta==-1)
                                    {
                                        if (note.stem_up) {
                                            note_x+=LINE_H;
                                            if (note.note_type==Note_Whole) {
                                                note_x+=0.4*LINE_H;
                                            }
                                        }else{
                                            note_x-=LINE_H+0;
                                            if (note.note_type==Note_Whole) {
                                                note_x-=0.4*LINE_H;
                                            }
                                            acc_x=x-LINE_H;
                                        }
                                        note_elem.display_revert=YES;
                                    }
                                }
                            }
                        }else{
                            //和弦里和前一个音相差1,就把这个音反转显示。 0,-5, -2, 0, 0 -1 -6, -6, -1, 2
                            if (elem_nn>0) {
                                NoteElem *prev_elem=[note.note_elems objectAtIndex:elem_nn-1];
                                if (!prev_elem.display_revert) {
                                    int delta = note_elem.line-prev_elem.line;
                                    if (delta==1||delta==-1)
                                    {
                                        if (note.stem_up) {
                                            note_x+=LINE_H;
                                            if (note.note_type==Note_Whole) {
                                                note_x+=0.4*LINE_H;
                                            }
                                        }else{
                                            note_x-=LINE_H+0;
                                            if (note.note_type==Note_Whole) {
                                                note_x-=0.4*LINE_H;
                                            }
                                            acc_x=x-LINE_H;
                                        }
                                        note_elem.display_revert=YES;
                                    }else if (delta==0&&note_elem.note!=prev_elem.note)
                                    {
                                        if (note.stem_up) {
                                            note_x+=2*LINE_H;
                                            acc_x=x+2*LINE_H;
                                        }else{
                                            note_x-=2*LINE_H+0;
                                            acc_x=x-LINE_H;
                                        }
                                    }
                                }
                            }
                        }
                    }else {
                        OveNote *note2;
                        int delta=0;

                        
                        //如果和前一个声部该位置的音差1或0，也把这个音移位显示
                        if (note.voice>0)
                        {
                            note2=[self getNoteWithOffset:note.pos.start_offset measure_pos:0 measure:measure staff:note.staff voice:note.voice-1];
                            if (note2 && !note2.isRest)
                            {
                                NoteElem *firstElem2=note2.note_elems.firstObject;
                                delta = firstElem2.line-note_elem.line;
                                if (!(delta==1||delta==-1 || delta==0) && note2.note_elems.count>1)
                                {
                                    NoteElem *lastElem2=[note2.note_elems lastObject];
                                    delta = lastElem2.line-note_elem.line;
                                }
                                if ((delta==0 && ((note.note_type<=Note_Half && note2.note_type>Note_Half) || (note.note_type<=Note_Whole && note2.note_type>Note_Whole)) && note2.tupletCount==0))
                                {
                                    note_x+=LINE_H+1;
                                    if (note.note_type==Note_Whole){
                                        note_x+=1;
                                    }
                                    stem_x=note_x+0.5;
                                    delta_stem_x+=LINE_H;
                                }else if (delta==0 && note_elem.dontPlay) {
                                    dontDrawHead=YES;
                                }else if(delta==-1){
                                    if (!note.inBeam) {
                                        note_x-=LINE_H;
                                        if (note.note_type==Note_Whole){
                                            note_x-=3;
                                        }
                                        stem_x=note_x+0.5;
                                        delta_stem_x-=LINE_H;
                                        acc_x=note_x-LINE_H;
                                    }
                                }else if(delta==1){
                                    if (note.note_elems.count==1 && (!note.inBeam) && note2.inBeam)
                                    {
                                        note_x+=LINE_H;
                                        if (note.note_type==Note_Whole){
                                            note_x+=3;
                                        }
                                        stem_x=note_x+0.5;
                                    }
                                    acc_x=note_x-LINE_H;
                                    
                                }
//                                else if(delta==2||delta==-2||delta==3||delta==-3)
//                                {
//                                    if (note.stem_up == note2.stem_up) {
//                                        if (!note.inBeam) {
//                                            note_x+=0.5*LINE_H;
//                                            stem_x+=0.5*LINE_H;
//                                            delta_stem_x+=0.5*LINE_H;
//                                        }
//                                    }
//                                }
                            }
                        }
                        //如果和下一个声部该位置的音差1，也把这个音移动显示
                        note2=[self getNoteWithOffset:note.pos.start_offset measure_pos:0 measure:measure staff:note.staff voice:note.voice+1];
                        NoteElem *firstElem2=note2.note_elems.lastObject;
                        
                        if (note2 && !note2.isRest)
                        {
                            int delta = firstElem2.line-note_elem.line;
                            if (delta==-1)
                            {
                                if (/*note.note_elems.count==1 &&*/ !note.inBeam)
                                {
                                    if (note.isDot) {
                                        note_x-=LINE_H;
                                        delta_stem_x-=LINE_H;
                                    }else{
                                        note_x-=LINE_H;
                                        delta_stem_x-=LINE_H;
                                        if (note.note_type==Note_Whole){
                                            note_x-=3;
                                        }
                                    }
                                    acc_x=note_x;
                                    stem_x=note_x+0.5;
                                }
                            }else if(delta==0)
                            {
                                if ((note.note_type<=Note_Half && note2.note_type>Note_Half) || (note.note_type<=Note_Whole && note2.note_type>Note_Whole)) {
                                    note_x-=LINE_H;
                                    delta_stem_x-=LINE_H;
                                    if (note.note_type==Note_Whole){
                                        note_x-=3;
                                    }
                                    acc_x=x-LINE_H;
                                    stem_x=note_x+0.5;
                                }
                            }else if(delta==1){
                                if (/*note.note_elems.count==1 &&*/ !note.inBeam)
                                {
                                    note_x+=LINE_H;
                                    delta_stem_x+=LINE_H;
                                    if (note.note_type==Note_Whole){
                                        note_x+=3;
                                    }
                                    stem_x=note_x+0.5;
                                    acc_x=note_x-LINE_H;
                                }
                            }else if(delta==2 /*|| delta==3*/)
                            {
                                //if (note.stem_up == note2.stem_up)
                                {
                                    if (!note.inBeam && note.note_type>Note_Whole) {
                                        note_x+=LINE_H;
                                        stem_x+=LINE_H;
                                        delta_stem_x+=LINE_H;
                                    }
                                }
                            }
//                            else if(delta==-2 || delta==-3)
//                            {
//                                if (note.stem_up == note2.stem_up && note.note_type>Note_Whole)
//                                {
//                                    if (note2.inBeam) {
//                                        note_x-=LINE_H;
//                                        stem_x-=LINE_H;
//                                        delta_stem_x-=LINE_H;
//                                    }
//                                }
//                            }
                        }
                    }
                    
                    float zoom=1;
                    if (note.isGrace) {//倚音
                        zoom=YIYIN_ZOOM;
                    }
                    NoteHeadType headType=[self headType:note_elem staff:note.staff-1];
                    
                    if (!dontDrawHead) {
                        if (headType==NoteHead_Percussion) {
                            NOTE_OpenHiHat(note_x, y, zoom);
                        }else if (headType==NoteHead_Closed_Rhythm) {
                            NOTE_CloseHiHat(note_x+LINE_H*0.3, y, zoom);
                        }else{
                            NSString *elem_id=[NSString stringWithFormat:@"%d_%d_%d",measure.number,i,elem_nn];
                            NSString *elem_note=ELEM_NOTE_4;
                            if (note.note_type==Note_Whole) {//whole
                                //NOTE_FULL(note_x, y,zoom);
                                elem_note=ELEM_NOTE_FULL;
                                //NOTE(note_x, y, zoom, ELEM_NOTE_FULL, elem_id);
                            }else if (note.note_type == Note_Half) {//二分音符
                                //NOTE_2(note_x, y,zoom);
                                elem_note=ELEM_NOTE_2;
                                //NOTE(note_x, y, zoom, ELEM_NOTE_2, elem_id);
                            }else{//0:倚音, 0.125:32th, 0.25:16th, 0.5:eighth, 1:quater 1.5:
                                //NOTE_4(note_x, y,zoom);
                            }
                            NOTE(note_x, y, zoom, elem_note, elem_id);
                            //NOTE_Index(note_x, y, zoom, elem_note, measure.number,i,elem_nn);
                        }
                    }
                    
                    note_elem.display_x=note_x;
                    note_elem.display_y=y;
//                    note.display_note_x=note_x;
                    
                    if (note.isDot) { //符点
                        //float dot_x=(note.note_type==Note_Whole)?note_x+LINE_H*2:note_x+LINE_H*1.5;
                        float dot_x=(note.note_type==Note_Whole)?note_x+LINE_H*2:stem_x+LINE_H*1.3;
                        float dot_y=y-LINE_H*0.5;
                        if (abs(note_elem.line)%2!=0) {
                            dot_y +=LINE_H*0.5;
                        }
                        
//                        if(note_elem.display_revert) {
//                            dot_x+=LINE_H;
//                        }else
                        if(elem_nn==note.note_elems.count-1){
                            //和前一个声部里最后一个音相差1，就调整浮点位置
                            OveNote *note2=[self getNoteWithOffset:note.pos.start_offset measure_pos:0 measure:measure staff:note.staff voice:note.voice-1];
                            if (note2 && !note2.isRest) {
                                NoteElem *bottomElem=note2.note_elems.firstObject;
                                int delta=bottomElem.line-note_elem.line;
                                if (delta==1) {
                                    dot_x+=LINE_H;
                                    dot_y=y;//+LINE_H;
                                    if (abs(note_elem.line)%2!=1) {
                                        dot_y=y+0.5*LINE_H;
                                    }
                                }
                            }
                        }else if (note.note_elems.count>1 && elem_nn<note.note_elems.count-1) {
                            //和弦里和高一个音相差1或2，就调整浮点位置
                            NoteElem *hi_elem=note.note_elems[elem_nn+1];
                            int delta=hi_elem.line-note_elem.line;
                            if (delta==1) {
//                                dot_x+=LINE_H;
//                                dot_x+=LINE_H;
                                dot_y=y;//+LINE_H;
                                if (abs(note_elem.line)%2!=1) {
                                    dot_y=y+0.5*LINE_H;
                                }
                            }
                        }
                        
                        for (int dot=0; dot<note.isDot; dot++) {
                            NOTE_DOT(dot_x+LINE_H*dot, dot_y);
                        }
                    }
                    
                    //accidental 升降符号
                    if (note_elem.accidental_type>Accidental_Normal)
                    {
                        float temp_acc_x=acc_x;

                        //调整升降记号
                        if(elem_nn==note.note_elems.count-1){
                            //和前一个声部里最后一个音相差1，就调整升降记号
                            OveNote *note2=[self getNoteWithOffset:note.pos.start_offset measure_pos:0 measure:measure staff:note.staff voice:note.voice-1];
                            if (note2) {
                                NoteElem *bottomElem=note2.note_elems.firstObject;
                                if (bottomElem.accidental_type>Accidental_Normal) {
                                    int delta=bottomElem.line-note_elem.line;
                                    if (delta==1) {
                                        temp_acc_x-=2*LINE_H;
                                    }
                                }
                            }
                        }
                        //和弦里和高一个音相差1或2，就调整升降记号
                        if (note.note_elems.count>1 && elem_nn<note.note_elems.count-1) {
                            NoteElem *hi_elem=note.note_elems[elem_nn+1];
                            if (hi_elem.accidental_type>Accidental_Normal) {
                                int delta=hi_elem.line-note_elem.line;
                                if (delta==2 || delta==1) {
                                    temp_acc_x-=LINE_H;
                                }
                            }
                        }
//                        if (note.note_elems.count>1 && elem_nn<note.note_elems.count-1) {
//                            NoteElem *nextElem=note.note_elems[elem_nn+1];
//                            if (nextElem.line==note_elem.line+1 && nextElem.accidental_type>Accidental_Normal) {
//                                temp_acc_x-=0.5*LINE_H;
//                            }
//                        }
                        if(![self drawSvgAccidental:note_elem.accidental_type acc_x:temp_acc_x acc_y:y isGrace:note.isGrace])
                        {
                            NSLog(@"Error unknow accidental_type=%d in measure=%d", note_elem.accidental_type, measure.number);
                        }
                    }
                    
                    //超出五线部分画横线
                    float more_line_y1=0;
                    int more_line_num=0;
                    if (/*elem_nn==0 &&*/elem_nn==note.note_elems.count-1 && note_elem.line>5)//在本行上面
                    {
                        more_line_num=(note_elem.line-6)/2+1;
                        more_line_y1=start_y+STAFF_OFFSET[staff-1] - more_line_num*LINE_H;
                    }else if (/*elem_nn==note.note_elems.count-1 &&*/elem_nn==0 && note_elem.line<-5) //在本行的下面
                    {
                        more_line_num=(-note_elem.line-6)/2+1;
                        //more_line_num=(y-more_line_y1)/LINE_H+1;
                        more_line_y1=start_y+STAFF_OFFSET[staff-1]+LINE_H*5;
                    }
                    if (more_line_y1>0) {
                        for (int j=0; j<more_line_num; j++) {
                            if (note.note_type==Note_Whole) {
                                LINE(x-0.4*LINE_H, more_line_y1, x+2.0*LINE_H, more_line_y1);
                            }else if (note.stem_up) {
                                LINE(x-0.4*LINE_H, more_line_y1, x+1.8*LINE_H, more_line_y1);
                            }else{
                                LINE(x-0.5*LINE_H, more_line_y1, x+1.8*LINE_H, more_line_y1);
                            }
                            more_line_y1+= LINE_H;
                        }
                    }
                }

                //横梁：beam
                if (note.inBeam)
                {
                    BOOL stem_drawed=NO;
                    
                    if (measure.show_number==46 && note.staff>2) {
                        NSLog(@"eee");
                    }
                    
                    for (int beam_index=0; beam_index<measure.beams.count; beam_index++) {
                        OveBeam *beam=[measure.beams objectAtIndex:beam_index];
                        BeamElem *elem0=beam.beam_elems.firstObject;// [beam.beam_elems objectAtIndex:0];
                        
//                        if ((beam.staff==note.staff ||beam.stop_staff==note.staff) && (beam.voice==note.voice) && (!beam.isGrace==!note.isGrace)
//                            && (elem0.start_measure_offset <= note.pos.start_offset && (elem0.stop_measure_offset >= note.pos.start_offset || elem0.stop_measure_pos>0) )
//                            )
                        if ([self isNote:note inBeam:beam])
                        {
                            float zoom=1.0;
                            if (note.isGrace) {
                                zoom=YIYIN_ZOOM;
                            }
                            
                            //CGRect beam_current_pos;
                            beam_current_pos=[self getBeamRect:beam start_x:start_x start_y:start_y measure:measure reload:NO];
                            if (beam_current_pos.size.width<=0) {
                                continue;
                            }
                            
                            
                            if (elem0.stop_measure_pos>0)
                            {
                                int tmp_index=(note.staff-1)*2+note.voice;
                                if (tmp_index>3) {
                                    NSLog(@"Error: staff(%d) or voice(%d) too big for beam. measure %d",note.staff,note.voice, measure.number);
                                    tmp_index=3;
                                }
                                //beam_continue_items[tmp_index]=beam;
                                beam_continue_pos[tmp_index]=beam_current_pos;
                            }
                            
                            //如果当前note在beam开始的第一个位置,就画横梁
                            if (elem0.start_measure_offset == note.pos.start_offset)
                            {
                                for (int j=0; j<beam.beam_elems.count; j++) {
                                    BeamElem *elem=[beam.beam_elems objectAtIndex:j];
                                    float y1,y2;
                                    //float x1=stem_x;
                                    float x1 = start_x+MEAS_LEFT_MARGIN+elem.start_measure_offset*OFFSET_X_UNIT+delta_stem_x;
                                    float x2 = start_x+MEAS_LEFT_MARGIN+elem.stop_measure_offset*OFFSET_X_UNIT+delta_stem_x;
                                    if (note.isGrace) {
                                        x1+=GRACE_X_OFFSET;
                                        x2+=GRACE_X_OFFSET;
                                    }
                                    if (elem.stop_measure_pos>0) {
                                        x2+=measure.meas_length_size*OFFSET_X_UNIT+MEAS_RIGHT_MARGIN+MEAS_LEFT_MARGIN;
                                    }
                                    OveNote *note2=beam.beam_stop_note;
                                    if (note2==nil) {
                                        note2=[self getNoteWithOffset:elem.stop_measure_offset measure_pos:elem.stop_measure_pos measure:measure staff:beam.stop_staff voice:beam.voice];
                                    }

//                                    if (j>0 && note2.stem_up!=note.stem_up)
//                                    {
//                                        OveNote *note1=[self getNoteWithOffset:elem.start_measure_offset measure_pos:elem.stop_measure_pos measure:measure staff:beam.stop_staff voice:beam.voice];
//                                        if (note1.stem_up) {
//                                            x1+=LINE_H*zoom+1.0;
//                                        }
//                                    }else
                                    if (note.stem_up) {
                                        x1+=LINE_H*zoom+0.5;
                                    }else if (x1>stem_x && note2.stem_up) {
                                        x1+=LINE_H*zoom;
                                    }
                                    if (note2 && note2.stem_up) {
                                        x2+=LINE_H*zoom;
                                        if (LINE_H>8) {
                                            x2+=0.5;
                                        }
                                    }
                                    //if (x1==x2)
                                    {
                                        if (elem.beam_type==Beam_Forward) {
                                            x2=x1+LINE_H*1.0;
                                        }else if (elem.beam_type==Beam_Backward){//Beam_Backward
                                            x1=x2-LINE_H*1.0;
                                        }
                                    }
                                    //if (j>=0)
                                    {
                                        //y2=beam_current_pos.size.height/beam_current_pos.size.width*(x2-beam_current_pos.origin.x)*zoom+beam_current_pos.origin.y;
                                        y2=beam_current_pos.size.height/beam_current_pos.size.width*(x2-beam_current_pos.origin.x)*1+beam_current_pos.origin.y;
                                        if (elem.level>1)
                                        {
                                            float delta_y=sqrtf(beam_current_pos.size.height*beam_current_pos.size.height + beam_current_pos.size.width*beam_current_pos.size.width)/beam_current_pos.size.width*BEAM_DISTANCE*zoom;
                                            
                                            if (note2.stem_up) {
                                                //y2+=j*delta_y*zoom;
                                                y2+=(elem.level-1)*delta_y;
                                            }else{
                                                y2-=(elem.level-1)*delta_y;
                                            }
                                            y1=y2-beam_current_pos.size.height/beam_current_pos.size.width*(x2-x1);
                                        }else{
                                            y1=beam_current_pos.origin.y;
                                        }
                                        
                                    }
                                    LINE_W(x1+0, y1, x2+1.0, y2, BEAM_WIDTH*zoom);
                                }
                                //tuplet n连音
                                NSString *tmp_tuplet=nil;
                                if (beam.tupletCount>0)
                                {
                                    tmp_tuplet=[NSString stringWithFormat:@"%d",beam.tupletCount];
                                }else if (note.tupletCount>0) {
                                    //tmp_tuplet=[NSString stringWithFormat:@"%d",note.tupletCount];
                                }
                                if (tmp_tuplet)
                                {
                                    int tmp_x= beam_current_pos.origin.x+beam_current_pos.size.width*0.5;//(x1+x2)/2;
                                    int tmp_y= beam_current_pos.origin.y+beam_current_pos.size.height*0.5;//(y1+y2)/2;
                                    if (note.stem_up) {
                                        tmp_y-=LINE_H*2.5;
                                    }else{
                                        tmp_y+=0;
                                    }
                                    TEXT(tmp_x, tmp_y, NORMAL_FONT_SIZE, tmp_tuplet);
                                    //[tmp_tuplet drawAtPoint:CGPointMake(tmp_x, tmp_y) withFont:[UIFont systemFontOfSize:16]];
                                }
                            }
                            //画stem
                            int stem_y=y;
                            
                            if (note.note_elems.count>1) {
                                if (note.stem_up && y<note_y1) {
                                    stem_y=note_y1;
                                }else if (!note.stem_up && y>note_y0) {
                                    stem_y=note_y0;
                                }
                            }
                            
                            CGRect rect=beam_current_pos;
                            if (beam.staff!=beam.stop_staff && beam.beam_elems.count>1 && beam.beam_start_note.stem_up!=beam.beam_stop_note.stem_up) {
                                if (note.staff==2 && beam.staff==2) {
                                    rect.origin.y-=(BEAM_DISTANCE+BEAM_WIDTH/2)*zoom*(beam.beam_elems.count-1);
                                }
                            }
                            [self drawSvgStem:rect note:note x:stem_x y:stem_y];
                            stem_drawed=YES;
                            break;
                        }
                    }
                    //如果当前note不在当前小节所有beam里面,就检查是不是在前一节延长的beam里?
                    if (!stem_drawed)
                    {
                        int tmp_index=(note.staff-1)*2+note.voice;
                        if (tmp_index>3) {
                            NSLog(@"Error: staff(%d) or voice(%d) too big for beam. measure %d",note.staff,note.voice, measure.number);
                            tmp_index=3;
                        }
                        CGRect tmp_beam_pos=beam_continue_pos[tmp_index];
                        
                        if (x>=tmp_beam_pos.origin.x && x<=tmp_beam_pos.origin.x+tmp_beam_pos.size.width+MEAS_LEFT_MARGIN)
                        {
                            [self drawSvgStem:tmp_beam_pos note:note x:x y:(note.stem_up && note_y0<note_y1)?note_y0:note_y1];
                        }else if(x>=0 && x-(STAFF_HEADER_WIDTH+MARGIN_LEFT+MEAS_LEFT_MARGIN)+screen_size.width-MARGIN_RIGHT<=tmp_beam_pos.origin.x+tmp_beam_pos.size.width)
                        {
                            //float tmp_x1=MARGIN_LEFT+STAFF_HEADER_WIDTH;
                            tmp_beam_pos.origin.x-=(screen_size.width-MARGIN_LEFT-MARGIN_RIGHT-STAFF_HEADER_WIDTH);
                            tmp_beam_pos.origin.y+=STAFF_OFFSET[staff_count-1]+(7+GROUP_STAFF_NEXT)*LINE_H;
                            if (line_index==0) {
                                tmp_beam_pos.origin.y-=screen_size.height-start_y;
                            }
                            float zoom=1;
                            if (note.isGrace) {
                                zoom=YIYIN_ZOOM;
                            }
                            LINE_W(MARGIN_LEFT+STAFF_HEADER_WIDTH, tmp_beam_pos.origin.y, tmp_beam_pos.origin.x+tmp_beam_pos.size.width, tmp_beam_pos.origin.y+tmp_beam_pos.size.height, BEAM_WIDTH*zoom);
                            [self drawSvgStem:tmp_beam_pos note:note x:x y:(note.stem_up && note_y0<note_y1)?note_y0:note_y1];
                        }
                    }
                }
                
                
                //符干: Beam外面的stem,
                if (!note_tailed_drawed && !note.hideStem && note.note_type!=Note_Whole && !note.inBeam) {
                    NoteElem *elem=[note.note_elems objectAtIndex:0];
                    
                    if (note.isGrace) {//倚音
//                        if (note.note_type>=Note_Eight) {
//                            LINE(x+LINE_H*YIYIN_ZOOM+0.5, (y>note_y0)?y:note_y0, x+LINE_H*YIYIN_ZOOM+0.5, y-LINE_H*2.0*YIYIN_ZOOM);
//                            LINE(x+LINE_H-LINE_H*0.9, y-3, x+LINE_H+LINE_H*0.3, y-LINE_H*3.0*0.5-1);
//                        }else{
                            if (note.stem_up) {
                                LINE(x+LINE_H*YIYIN_ZOOM+0.5, note_y1, x+LINE_H*YIYIN_ZOOM+0.5, note_y0-LINE_H*3.0*YIYIN_ZOOM);
                            }else{
                                LINE(x, note_y0, x, note_y1+LINE_H*3.0*YIYIN_ZOOM);
                            }
//                        }
                        //LINE(x+LINE_H-LINE_H*0.5-4, y-3, x+LINE_H-LINE_H*0.5+8, y-LINE_H*3.0*0.5-1);
                    }else if (note.stem_up)
                    {
                        stem_x+=LINE_H;
                        if (LINE_H>8) {
                            stem_x+=0.5;
                        }
                        float tmp_y=start_y+[self lineToY:elem.line staff:note.staff+elem.offsetStaff];
                        if (note.note_elems.count>1)
                        {
                            if (tmp_y<y) {
                                float tt=tmp_y;
                                tmp_y=y;
                                y=tt;
                            }
                        }
                        if (y-LINE_H*3.5>start_y+3*LINE_H+STAFF_OFFSET[note.staff-1]) {
                            LINE(stem_x, tmp_y, stem_x, start_y+2*LINE_H+STAFF_OFFSET[note.staff-1]);
                            y=start_y+5.5*LINE_H+STAFF_OFFSET[note.staff-1];
                            //note_below_y=start_y+2*LINE_H+STAFF_OFFSET[note.staff-1];
                        }else {
                            LINE(stem_x, tmp_y, stem_x, y-LINE_H*3.5);
                        }
                    }else
                    {
                        float tmp_y=start_y+[self lineToY:elem.line staff:note.staff+elem.offsetStaff];
                        if (note.note_elems.count>1){
                            if (tmp_y>y) {
                                float tt=tmp_y;
                                tmp_y=y;
                                y=tt;
                            }
                        }
                        if (tmp_y<0 || tmp_y>screen_size.height) {
                            //NSLog(@"Error stem is too long y1=%f, y2=%f in measure=%d", tmp_y, y+LINE_H*3.5, measure.number);
                        }
                        //符干要延长到五线的第2线。
                        if (y+LINE_H*3.5<start_y+2*LINE_H+STAFF_OFFSET[note.staff-1]) {
                            LINE(stem_x, tmp_y, stem_x, start_y+2*LINE_H+STAFF_OFFSET[note.staff-1]);
                            y=start_y-1.5*LINE_H+STAFF_OFFSET[note.staff-1];
                            //note_below_y=start_y+2*LINE_H+STAFF_OFFSET[note.staff-1];
                        }else{
                            LINE(stem_x, tmp_y, stem_x, y+LINE_H*3.5);
                        }
                    }
                    //tail
                    if (note.isGrace) { //倚音
                        if (note.note_type==Note_Sixteen) {
                            //TAIL_16_UP_ZOOM(x+LINE_H*YIYIN_ZOOM-0.5+GRACE_X_OFFSET, y-LINE_H*2.0*YIYIN_ZOOM, YIYIN_ZOOM);
                            TAIL_16_UP_ZOOM(x-0.5+GRACE_X_OFFSET, y+LINE_H*0.5*YIYIN_ZOOM, YIYIN_ZOOM);
                        }else if (note.note_type==Note_Eight) {
                            //TAIL_EIGHT_UP(x+LINE_H*YIYIN_ZOOM-0.5+GRACE_X_OFFSET, y-LINE_H*2.0*YIYIN_ZOOM, YIYIN_ZOOM);
                            TAIL_EIGHT_UP(x-0.5+GRACE_X_OFFSET, y+LINE_H*0.5*YIYIN_ZOOM, YIYIN_ZOOM);
                        }
                    }else if(note.note_type==Note_Eight) //eighth
                    {
                        if (note.stem_up) {
                            //TAIL_EIGHT_UP(stem_x-0.5, y-LINE_H*3.5, 1);
                            TAIL_EIGHT_UP(stem_x-LINE_H-1, y,1);//-LINE_H*3.5, 1);
                        }else {
                            //TAIL_EIGHT_DOWN(stem_x-0.5, y+LINE_H*3.5);
                            TAIL_EIGHT_DOWN(stem_x, y-1);
                        }
                    }else if(note.note_type==Note_Sixteen) //16th
                    {
                        if (note.stem_up) {
                            //TAIL_16_UP(stem_x-0.5, y);//-LINE_H*2.0);
                            TAIL_16_UP(stem_x-LINE_H-1, y);//-LINE_H*2.0);
                        }else{
                            //TAIL_16_DOWN(stem_x-0.5, y);//+LINE_H*2.0);
                            TAIL_16_DOWN(stem_x, y);//+LINE_H*2.0);
                        }
                    }else if(note.note_type==Note_32) //32th
                    {
                        if (note.stem_up) {
                            TAIL_32_UP(stem_x-LINE_H-1, y);//-LINE_H*2.0);
                        }else{
                            TAIL_32_DOWN(stem_x, y);//+LINE_H*2.0);
                        }
                    }else if(note.note_type==Note_64) //64th
                    {
                        if (note.stem_up) {
                            TAIL_64_UP(stem_x-LINE_H-1, y);//-LINE_H*2.0);
                        }else{
                            TAIL_64_DOWN(stem_x, y);//+LINE_H*2.0);
                        }
                    }else if(note.note_type> Note_64)
                    {
                        NSLog(@"Error: unknow beam=%d, n=%d",note.inBeam, note.note_type);
                    }
                }
                //draw art
                if (note.note_arts) {
                    int pedal_downs=0, pedal_ups=0;
                    float art_up_count=0, art_down_count=0;
                    float zoom=1;
                    if (note.isGrace) {
                        zoom=0.7;
                    }
                    for (int nn=0; nn<note.note_arts.count; nn++) {
                        NoteArticulation *note_art;
                        note_art = [note.note_arts objectAtIndex:nn];
                        ArticulationType art_type=note_art.art_type;
                        BOOL art_placement_above=note_art.art_placement_above;
                        //NSLog(@"Measure(%d) note_arts(%ld):0x%x", measure.number, (unsigned long)note.note_arts.count,art_type);
                        
                        float art_y=y, art_x=note_x;
                        if(note.note_elems.count>1){
                            if (art_placement_above) {
                                art_y=note_y0;
                            }else{
                                art_y=note_y1;
                            }
                        }
                        art_x+=note_art.offset.offset_x*OFFSET_X_UNIT;
                        if (note_art.offset.offset_y!=0) {
                            if (art_placement_above) {
                                art_y-=note_art.offset.offset_y*OFFSET_Y_UNIT;//+LINE_H;
                                if (note.stem_up) {
                                    art_y-=2*LINE_H;
                                }
                            }else{
                                art_y+=note_art.offset.offset_y*OFFSET_Y_UNIT;
                            }
                        }else {
                            if (note.note_type<=Note_Whole) {
                                if (art_placement_above) {
                                    art_y-=1.5*LINE_H;
                                }else{
                                    art_y+=1.5*LINE_H;
                                }
                            }else if (art_placement_above && (note.stem_up || note.isGrace)) {
                                if (note.inBeam) {
                                    //art_y=beam_current_pos.origin.y-LINE_H*1.0;
                                    art_y=beam_current_pos.size.height/beam_current_pos.size.width*(art_x-beam_current_pos.origin.x)*1+beam_current_pos.origin.y-LINE_H*1.5;
                                }else{
                                    art_y-=(note.isGrace)?1.5*LINE_H: 3*LINE_H;
                                    if (art_type==Articulation_Fermata || art_type==Articulation_Fermata_Inverted) {
                                        //art_x+=0.5*LINE_H;
                                        art_y-=2.0*LINE_H;
                                    }else if (art_type==Articulation_Finger && note_art.finger.length>1) {
                                        //art_x+=0.5*LINE_H;
                                        art_y-=1.0*LINE_H;
                                    }else if(note.note_type>=Note_Eight) {
                                        art_y-=LINE_H;
                                    }
                                }
                                if (note_art.accidental_mark>Accidental_Normal) {
                                    art_y-=1.5*LINE_H;
                                }
                            }else if ((!art_placement_above) && (!note.stem_up)) {
                                if (note.inBeam) {
                                    //art_y=beam_current_pos.origin.y+LINE_H*1.5;
                                    art_y=beam_current_pos.size.height/beam_current_pos.size.width*(art_x-beam_current_pos.origin.x)*1+beam_current_pos.origin.y+LINE_H*1.5;
                                }else{
                                    art_y+=(note.isGrace)?1.5*LINE_H: 3.0*LINE_H;
                                    art_x+=0.2*LINE_H;
                                    if (art_type==Articulation_Finger && note_art.finger.length>1) {
                                        //art_x+=0.5*LINE_H;
                                        art_y+=2.0*LINE_H;
                                    }else if(note.note_type>=Note_Eight) {
                                        art_y+=1.0*LINE_H;
//                                        art_x+=0.2*LINE_H;
                                    }
                                }
                            }else{
                                if (art_placement_above) {
                                    if (note.stem_up) {
                                        art_y-=3.5*LINE_H;
                                    }else{
                                        //art_y-=1.5*LINE_H;
                                        art_y=note_up_y-1.5*LINE_H;
                                    }
                                    if (note_art.accidental_mark>Accidental_Normal) {
                                        art_y-=1.5*LINE_H;
                                    }
                                }else{
                                    if (note.stem_up) {
//                                        art_y+=1.5*LINE_H;
                                        art_y=note_below_y+1.5*LINE_H;
                                    }else{
                                        art_y=note_below_y+LINE_H;
                                        //art_y+=LINE_H;
                                    }
                                }
                            }
                            float adds=1.4;
                            if (art_type==Articulation_Staccato || art_type==Articulation_Tenuto) {
                                adds=0.4;
                            }else if (art_type==Articulation_Fermata || art_type==Articulation_Fermata_Inverted || art_type==Articulation_Turn || art_type==Articulation_Major_Trill || art_type==Articulation_Minor_Trill) {
                                adds=2.0;
                            }
                            
                            if (art_placement_above) {
                                art_y-=LINE_H*art_up_count;
                                art_up_count+=adds;
                            }else{
                                art_y+=LINE_H*art_down_count;
                                art_down_count+=adds;
                            }
                        }
                        
                        int staff_start_y=start_y+STAFF_OFFSET[staff-1];
                        if (art_type==Articulation_Pedal_Down || art_type==Articulation_Pedal_Up) {
                            staff_start_y=start_y;
                            art_x+=4.0*LINE_H*pedal_downs+2.0*LINE_H*pedal_ups;
                            if (art_type==Articulation_Pedal_Down){
                                pedal_downs++;
                            }else if(art_type==Articulation_Pedal_Up) {
                                pedal_ups++;
                            }
                            if (art_type==Articulation_Pedal_Up && note.note_arts.count>1) {
                                for (int other=0; other<note.note_arts.count; other++) {
                                    NoteArticulation *nextArt=note.note_arts[nn+1];
                                    if (nextArt.art_type==Articulation_Pedal_Down) {
                                        art_x-=2*LINE_H;
                                        break;
                                    }
                                }
                            }
                        }
                        
                        if (![self drawSvgArt:note_art above:art_placement_above x:art_x y:art_y start_y:staff_start_y]) {
                            //Articulation_Arpeggio = 0x1E, //琶音 音符左边垂直一条波浪线
                            if (art_type == Articulation_Arpeggio)
                            {
                                //int tmp_y1=start_y-LINE_H*1.0+ STAFF_OFFSET[note.staff-1]+note_art.offset.offset_y*OFFSET_Y_UNIT;
                                //int tmp_y2=start_y+LINE_H*5.0+STAFF_OFFSET[note.staff-1]+note_art.offset.offset_y*OFFSET_Y_UNIT;
                                int tmp_x=note_x+note_art.offset.offset_x*OFFSET_X_UNIT;
                                if (note_art.offset.offset_x==0) {
                                    tmp_x-=LINE_H;
                                }
                                if (note.note_type==Note_Whole) {
                                    tmp_x-=0.5*LINE_H;
                                }
                                for (NoteElem *elem in note.note_elems) {
                                    if (elem.accidental_type!=Accidental_Normal) {
                                        tmp_x-=1.0*LINE_H;
                                        break;
                                    }
                                }
                                NoteElem *elem1=[note.sorted_note_elems objectAtIndex:0];
                                NoteElem *elem2=note.sorted_note_elems.lastObject;
                                
                                int tmp_y1=start_y+[self lineToY:elem1.line staff:note.staff+elem1.offsetStaff];
                                int tmp_y2;
                                if (note_art.arpeggiate_over_staff==2) {
                                    NSArray *notes=measure.sorted_notes[[NSString stringWithFormat:@"%d",note.pos.tick]];
                                    OveNote *endNote=notes.lastObject;
                                    if (note_art.arpeggiate_over_voice<=1) { //over one voice
                                        if (notes.count==4) {
                                            endNote=notes[2];
                                        }
                                    }
                                    elem2=endNote.note_elems.firstObject;
                                    tmp_y2=start_y+[self lineToY:elem2.line staff:note_art.arpeggiate_over_staff];
                                }else{
                                    tmp_y2=start_y+[self lineToY:elem2.line staff:note.staff+elem2.offsetStaff];
                                }
                                
                                LINE_WAVY_VERTICAL(tmp_x, tmp_y1, tmp_y2, WAVY_LINE_WIDTH);
                                //Tremolo 颤音
                            }else if (art_type == Articulation_Tremolo_Eighth
                                      || art_type==Articulation_Tremolo_Sixteenth
                                      || art_type==Articulation_Tremolo_Thirty_Second
                                      || art_type==Articulation_Tremolo_Sixty_Fourth)
                            {
#if 1
                                if (note_art.tremolo_stop_note_count==0) {
                                    float tmp_x=x-LINE_H*0.5;
                                    float tmp_y=y+LINE_H*3;
                                    if (note.stem_up) {
                                        tmp_y=y-1*LINE_H;
                                        tmp_x+=LINE_H*1;
                                    }
                                    NSString *tremolo_str=[NSString stringWithFormat:@"a%x", 8+art_type-Articulation_Tremolo_Eighth];
                                    GLYPH_Petrucci(tmp_x,tmp_y,GLYPH_FONT_SIZE,0,tremolo_str);
                                }else if(!note_art.tremolo_beem_mode && i<measure.notes.count-1){
                                    OveNote *nextNote=measure.notes[i+1];
                                    float tmp_x=x+LINE_H*0.5;
                                    float tmp_y=y+LINE_H*3.5;
                                    if (note.stem_up) {
                                        tmp_y=y-3*LINE_H;
                                        tmp_x+=LINE_H*1.5;
                                    }
                                    float next_x = start_x+MEAS_LEFT_MARGIN+nextNote.pos.start_offset*OFFSET_X_UNIT;
                                    float next_y;
                                    if (nextNote.line>note.line) {
                                        next_y=tmp_y-0.5*LINE_H;
                                    }else{
                                        next_y=tmp_y+0.5*LINE_H;
                                    }
                                    for (int i=0; i<art_type-Articulation_Tremolo_Eighth+1; i++) {
                                        LINE_W(tmp_x, tmp_y, next_x, next_y, TREMOLO_LINE_WIDTH);
                                        tmp_y+=2*TREMOLO_LINE_WIDTH;
                                        next_y+=2*TREMOLO_LINE_WIDTH;
                                    }
                                }
#else
                                float tmp_x=x;
                                float tmp_y=y+LINE_H*1.5;
                                if (note.stem_up) {
                                    tmp_y=y-3*LINE_H;
                                }
                                for (int i=0; i<art_type-Articulation_Tremolo_Eighth+1; i++) {
                                    LINE_W(tmp_x-LINE_H*0.5, tmp_y+2, tmp_x+LINE_H, tmp_y-2, WAVY_LINE_WIDTH);
                                    tmp_y+=4;
                                }
#endif
                            }else if (art_type==Articulation_Finger) {
                                NSString *tmp=note_art.finger;
                                if (note_art.finger.length==1) {
                                    tmp=[NSString stringWithFormat:@"3%x",[tmp intValue]];
                                    GLYPH_Petrucci(art_x, art_y, GLYPH_FONT_SIZE*0.6*zoom, 0, tmp);
                                }else{
//                                    GLYPH_Petrucci(art_x, art_y, GLYPH_FONT_SIZE*0.8*zoom, 0, tmp);
                                    TEXT(art_x, art_y-LINE_H, GLYPH_FONT_SIZE*0.8*zoom, tmp);
                                }
                                if (note_art.alterFinger) {
                                    tmp=[NSString stringWithFormat:@"3%x",[note_art.alterFinger intValue]];
                                    if (note_art.art_placement_above) {
                                        art_y-=1.5*LINE_H;
                                        LINE_W(art_x-2, art_y+6, art_x+LINE_H, art_y+6,1);
                                    }else{
                                        art_y+=1.5*LINE_H;
                                        LINE_W(art_x-2, art_y-6, art_x+LINE_H, art_y-6,1);
                                    }
                                    GLYPH_Petrucci(art_x, art_y, GLYPH_FONT_SIZE*0.6*zoom, 0, tmp);
                                }
                                //                                GLYPH_Petrucci(art_x, art_y, GLYPH_FINGER_SIZE, 0, tmp);
                            }else
                            {
                                NSLog(@"Error unknow art_type=0x%x in measure=%d",art_type, measure.number);
                            }
                        }
                        [self drawSvgTrill:note_art measure:measure note:note x:x art_y:art_y];
                    }
                }
                //end draw art
            }
        }
        //measure end
        
        
        //
        if (measure.numerics!=nil) {
            for (NumericEnding *num in measure.numerics) {
                if (num.numeric_text!=nil && num.numeric_text.length>0) {
                    int tmp_x1=start_x+2;
                    int tmp_y=start_y-LINE_H*2.0;
                    int tmp_x2=start_x;
                    if (num.offset_y) {
                        tmp_y=start_y-num.offset_y*OFFSET_Y_UNIT+LINE_H;
                    }
                    OveMeasure *next_measure;
                    for (int n=0; n<num.numeric_measure_count && measure.number+n<self.music.measures.count; n++) {
                        next_measure = [self.music.measures objectAtIndex:measure.number+n];
                        tmp_x2+=next_measure.meas_length_size*OFFSET_X_UNIT+(MEAS_LEFT_MARGIN+MEAS_RIGHT_MARGIN);
                    }
                    tmp_x2-=5;
                    
                    LINE(tmp_x1, tmp_y+LINE_H*1, tmp_x1, tmp_y);
                    LINE(tmp_x1, tmp_y, tmp_x2, tmp_y);
                    BOOL closeEnding=(next_measure.right_barline!=Barline_Default);
                    if (!closeEnding && next_measure.number<self.music.measures.count-1) {
                        OveMeasure *nextNextMeasure=self.music.measures[next_measure.number+1];
                        closeEnding = (nextNextMeasure.left_barline!=Barline_Default);
                    }
                    if (closeEnding) {
                        LINE(tmp_x2, tmp_y+LINE_H*1, tmp_x2, tmp_y);
                    }
                    TEXT(tmp_x1, tmp_y, NORMAL_FONT_SIZE, num.numeric_text);
                    //[num.numeric_text drawAtPoint:CGPointMake(tmp_x1, tmp_y) withFont:[UIFont systemFontOfSize:16]];
                    if (tmp_x2>=screen_size.width-MARGIN_RIGHT) {
                        tmp_x1=MARGIN_LEFT+STAFF_HEADER_WIDTH;
                        tmp_x2=tmp_x2-(screen_size.width-MARGIN_RIGHT) + tmp_x1;
                        tmp_y+=STAFF_OFFSET[staff_count-1]+(4+GROUP_STAFF_NEXT)*LINE_H;
                        LINE(tmp_x1, tmp_y, tmp_x2, tmp_y);
                        LINE(tmp_x2, tmp_y+LINE_H*1, tmp_x2, tmp_y);
                    }
                }
            }
        }
    }
    //x=start_x+ DURATION_STEP_LEN*[measure display_durations]+20;
    //        if (measure.meas_length_size==0) {
    //            x=start_x;
    //        }else{
    x = start_x+MEAS_LEFT_MARGIN+measure.meas_length_size*OFFSET_X_UNIT + MEAS_RIGHT_MARGIN;
    //        }
    if (x>screen_size.width-MARGIN_RIGHT) {
        x=screen_size.width-MARGIN_RIGHT;
    }
    
    //小节边界
    if (measure.right_barline==Barline_Double)//双细线
    {
        if (line_index<line_count-1) {
            //LINE(x-0, start_y, x-0, start_y+LINE_H*(last_staff_lines-1)+STAFF_OFFSET[staff_count-1]);
        }
        LINE(x, start_y, x, start_y+LINE_H*(last_staff_lines-1)+STAFF_OFFSET[staff_count-1]);
        LINE(x-1.5*BARLINE_WIDTH, start_y, x-1.5*BARLINE_WIDTH, start_y+LINE_H*(last_staff_lines-1)+STAFF_OFFSET[staff_count-1]);
    }else if (measure.right_barline==Barline_RepeatRight || measure.right_barline==Barline_Final) //反复记号
    {
        if (measure.right_barline==Barline_RepeatRight) {
            for (int i=0; i<staff_count; i++) {
                NORMAL_DOT(x-LINE_H*1.5, start_y+LINE_H*1.5+STAFF_OFFSET[i]);
                NORMAL_DOT(x-LINE_H*1.5, start_y+LINE_H*2.5+STAFF_OFFSET[i]);
            }
        }
        
        LINE(x-2*BARLINE_WIDTH, start_y, x-2*BARLINE_WIDTH, start_y+LINE_H*(last_staff_lines-1)+STAFF_OFFSET[staff_count-1]);
        LINE_W(x-0.5*BARLINE_WIDTH, start_y, x-0.5*BARLINE_WIDTH, start_y+LINE_H*(last_staff_lines-1)+STAFF_OFFSET[staff_count-1], BARLINE_WIDTH);
    }else if(measure.right_barline==Barline_Default)//单细线
    {
        LINE(x, start_y, x, start_y+LINE_H*(last_staff_lines-1)+STAFF_OFFSET[staff_count-1]);
    }else if(measure.right_barline!=Barline_Null)
    {
        NSLog(@"Error: unknow right_barline=%d at measure(%d)",measure.right_barline,measure.number);
    }
    return x;
}
- (void) drawSvgStem:(CGRect) beam_pos note:(OveNote*) note x:(float)x y:(float)y
{
    //画stem
    float tmp_x=x;
    float zoom=1;
    if (note.isGrace) {
        zoom=YIYIN_ZOOM;
    }

    if (note.stem_up) {
        tmp_x=x+LINE_H+1;
        if (LINE_H<10) {
            tmp_x-=0.5;
        }
        if (note.isGrace) {
            tmp_x=x+LINE_H*YIYIN_ZOOM+0.5;
        }
    }else{
        tmp_x=x+0.0;
    }
    if (note.isGrace) {
        tmp_x+=GRACE_X_OFFSET;
    }
    
    {
        float tmp_y2=beam_pos.size.height/beam_pos.size.width*(tmp_x-beam_pos.origin.x)*zoom+beam_pos.origin.y;
        if (tmp_y2>y) {
            //tmp_y2=beam_current_pos[1].size.height/beam_current_pos[1].size.width*(x-beam_current_pos[1].origin.x)+beam_current_pos[1].origin.y;
        }
        //        NoteElem *elem=&note.note_elem[0];
        //        float tmp_y=start_y+[self lineToY:elem->line staff:note.staff+elem->offsetStaff];
        
        //如果beam计算出错
        if (tmp_y2<0 || tmp_y2>screen_size.height) {
            //NSLog(@"Error, stem is too long. y1=%f, y2=%f", y, tmp_y2);
            //note.inBeam=NO;
            //DRAW_LINE(tmp_x, tmp_y/* y+(note.noteCount-1)*LINE_H*/, tmp_x, y-LINE_H*3.5, 1);
        }else{
            LINE(tmp_x, y+LINE_H*0.0, tmp_x, tmp_y2);
        }
    }
}

#define CURVE1(x1,x2,y1,y2,cp1x, cp1y,cp2x, cp2y)    \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<path d=\"M%d,%d C%d,%d %d,%d %d,%d\" "strokeColor" stroke-width='%d' fill=\"none\"/>",(int)(x1),(int)(y1),(int)(cp1x),(int)(cp1y),(int)(cp2x),(int)(cp2y),(int)(x2),(int)(y2),SLUR_LINE_WIDTH]];

#define CURVE(x1,x2,y1,y2,cp1x, cp1y,cp2x, cp2y)    \
[self.svgXmlContent appendString:[NSString stringWithFormat:@"<path d=\"M%d,%d C%d,%d %d,%d %d,%d C%d,%d %d,%d %d,%d\" "strokeColor" stroke-width='0.5' "fillColor"/>",(int)(x1),(int)(y1),(int)(cp1x),(int)(cp1y),(int)(cp2x),(int)(cp2y),(int)(x2),(int)(y2),(int)cp2x,(int)cp2y+3,(int)cp1x,(int)cp1y+3,(int)x1,(int)y1]];


-(void) drawSvgCurveLine:(int)w x1:(float)x1 y1:(float)y1 x2:(float)x2 y2:(float)y2 above:(BOOL) above
{
#if 1
#define COS20 0.94
#define SIN20 0.342
    
#define COS30 0.866
#define SIN30 0.5

#define COS45 0.7071
#define SIN45 0.7071

#define COS60 0.5
#define SIN60 0.866
    
    float COSA=COS30;
    float SINA=(-SIN30);
    float SIN_A=SIN30;
    float LEFT_RATE=0.3;
    float RIGHT_RATE=0.7;
    
    float cp1x,cp2x;
    float cp1y,cp2y;
    if (x2-x1<100) {
        LEFT_RATE=0.30;
        COSA=COS60;
        SINA=(-SIN60);
        SIN_A=SIN60;
        if (x2-x1<1.5*LINE_H) {
            x1-=LINE_H*0.5;
            x2=x1+1.5*LINE_H;
        }
    }else if (x2-x1<200) {
        COSA=COS45;
        SINA=(-SIN45);
        SIN_A=SIN45;
    }else if(x2-x1>400)
    {
        LEFT_RATE=0.2;
        COSA=COS20;
        SINA=(-SIN20);
        SIN_A=SIN20;
    }
    RIGHT_RATE=1-LEFT_RATE;
    
    float tmp1x=x1+(x2-x1)*LEFT_RATE;
    float tmp1y=y1+(y2-y1)*LEFT_RATE;
    float tmp2x=x1+(x2-x1)*RIGHT_RATE;
    float tmp2y=y1+(y2-y1)*RIGHT_RATE;
    
    if (above) {
        cp1x=(tmp1x-x1)*COSA-(tmp1y-y1)*SINA+x1;
        cp1y=(tmp1x-x1)*SINA+(tmp1y-y1)*COSA+y1;
        
        cp2x=(tmp2x-x2)*COSA-(tmp2y-y2)*SIN_A+x2;
        cp2y=(tmp2x-x2)*SIN_A+(tmp2y-y2)*COSA+y2;
    }else{
        cp1x=(tmp1x-x1)*COSA-(tmp1y-y1)*SIN_A+x1;
        cp1y=(tmp1x-x1)*SIN_A+(tmp1y-y1)*COSA+y1;
        
        cp2x=(tmp2x-x2)*COSA-(tmp2y-y2)*SINA+x2;
        cp2y=(tmp2x-x2)*SINA+(tmp2y-y2)*COSA+y2;
    }
#endif
    CURVE(x1, x2, y1, y2, cp1x, cp1y, cp2x, cp2y);
}
- (BOOL) drawSvgArt:(NoteArticulation*) art above:(BOOL)art_placement_above x:(int)x y:(int)y start_y:(float)start_y
{
    
    ArticulationType art_type=art.art_type;
    //staccato 顿音/断奏/跳音 音符上面一个点
    if (art_type == Articulation_Staccato)
    {
        if (art_placement_above) {
//            ART_STACCATO(x+LINE_H*0.4, y-LINE_H*1.0);
            ART_STACCATO(x+LINE_H*0.4, y+LINE_H*0.5);
        }else
        {
//            ART_STACCATO(x+LINE_H*0.4, y+LINE_H*1.0);
            ART_STACCATO(x+LINE_H*0.4, y-LINE_H*0.6);
        }
    }
    //tenuto 保持音 音符上面一条横线
    else if (art_type == Articulation_Tenuto)
    {
        if (art_placement_above) {
            LINE_W(x-LINE_H*0.3, y+LINE_H*0.5, x+LINE_H*1.2, y+LINE_H*0.5, 2);
        }else
        {
            LINE_W(x-LINE_H*0.2, y-LINE_H*0.5, x+LINE_H*1.3, y-LINE_H*0.5,2);
        }
    }
    //一个横线，下面加一个点
    else if (art_type == Articulation_Detached_Legato)
    {
        if (art_placement_above) {
            LINE_W(x, y+LINE_H*0.5, x+12, y+LINE_H*0.5, 2);
            ART_STACCATO(x+LINE_H*0.4, y);
        }else
        {
            LINE(x, y-LINE_H*0.5, x+12, y-LINE_H*0.5);
            ART_STACCATO(x+LINE_H*0.4, y);
        }
    }
    //Articulation_Natural_Harmonic 一个圆圈
    else if (art_type == Articulation_Natural_Harmonic)
    {
        if (art_placement_above) {
            GLYPH_Petrucci(x+LINE_H*0.4,y-LINE_H*1.0,GLYPH_FONT_SIZE, 0, @"c9");
        }else
        {
            GLYPH_Petrucci(x+LINE_H*0.4,y+LINE_H*1.0,GLYPH_FONT_SIZE, 0, @"c9");
        }
    } //Marcato 着重/重音 音符上面一个大于号“>”
    else if (art_type==Articulation_Marcato)
    {
        if (art_placement_above) {
            ART_MARCATO(x+LINE_H*0, y+LINE_H*0.5);
        }else
        {
            ART_MARCATO(x+LINE_H*0, y+LINE_H*1);
        }
    }
    //Marcato_Dot 着重断奏 音符上面一个大于号“>”下面加一个点
    else if (art_type==Articulation_Marcato_Dot)
    {
        if (art_placement_above) {
            ART_MARCATO_DOT_UP(x+LINE_H*0, y-LINE_H*0);
//            ART_MARCATO_DOT_DOWN(x, y);
        }else
        {
            //下面 >.
            /*
             中央4级中小型 1
             <beat-unit>quarter</beat-unit>
             <beat-unit-dot/>
             <beat-unit>quarter</beat-unit>
             
             和弦倚音 符干不对。 中央6级 大型1
             */
            
//            ART_MARCATO_DOT_UP(x+LINE_H*0, y-LINE_H*0); //
//            ART_MARCATO_DOT_DOWN(x, y);
            ART_STACCATO(x+LINE_H*0.4, y);
            ART_MARCATO(x+LINE_H*0, y+LINE_H*1);
        }
    }
    //Heavy_Attack 强音 音符上面一个大于号“>”下面加一个横线
    else if (art_type==Articulation_Heavy_Attack)
    {
        if (art_placement_above) {
            ART_MARCATO(x+LINE_H*0, y-LINE_H*1.5);
            LINE(x, y-LINE_H*1, x+12, y-LINE_H*1);
        }else
        {
            ART_MARCATO(x+LINE_H*0, y-LINE_H*1);
            LINE(x, y-LINE_H*0.5, x+12, y-LINE_H*0.5);
        }
    }
    //strong_accent_placement 突强 音符上面一个"^" or 突强(倒置) 音符下面一个"V"
    else if (art_type==Articulation_SForzando || art_type==Articulation_SForzando_Inverted)
    {
        if (art_placement_above) {
            ART_STRONG_ACCENT_UP(x+0.2*LINE_H, y-0.5*LINE_H);
        }else
        {
            ART_STRONG_ACCENT_DOWN(x+0.2*LINE_H, y+LINE_H*2.0);
        }
    }
    //SForzando_Dot 突强断奏 音符上面一个"^"里面加一个点 or 突强断奏(倒置) 音符下面一个"V"里面加一个点
    else if (art_type==Articulation_SForzando_Dot ||art_type==Articulation_SForzando_Dot_Inverted)
    {
        if (art_placement_above) {
            ART_SFORZANDO_UP(x+0.0*LINE_H, y+0.5*LINE_H);
        }else
        {
            ART_SFORZANDO_DOWN(x+0.2*LINE_H, y+LINE_H*0.5);
        }
    }
    //Heavier_Attack:特强音 音符上一个^下面加一个横线。
    else if (art_type==Articulation_Heavier_Attack)
    {
        if (art_placement_above) {
            ART_STRONG_ACCENT_UP(x+0.2*LINE_H, y-1.2*LINE_H);
            LINE(x, y-LINE_H*1.0, x+12, y-LINE_H*1.0);
        }else
        {
            ART_STRONG_ACCENT_DOWN(x+0.2*LINE_H, y+LINE_H*2.0);
            LINE(x, y-LINE_H*1, x+12, y-LINE_H*1);
        }
    }
    //staccatissimo_placement 短跳音/顿音 音符上面一个实心的三角形
    else if (art_type == Articulation_Staccatissimo)
    {
        if (art_placement_above) {
            ART_STACCATISSIMO(x, y+LINE_H*0.5);
        }else
        {
            ART_STACCATISSIMO_DOWN(x, y-LINE_H*0.5);
        }
    }
    //Articulation_Fermata://延长记号 音符上面一个半圆，里面有一个点。
    else if (art_type == Articulation_Fermata || art_type==Articulation_Fermata_Inverted)
    {
        if (art_placement_above) {
            ART_FERMATA_UP(x-5, y-LINE_H*0.0);
        }else
        {
            ART_FERMATA_DOWN(x-5, y+LINE_H*1.0);
        }
    }
    
    //Mordent 波音/涟音
    /*
     1. 波音／顺波音/上波音（Mordent/Upper Mordent/inverted mordent）Articulation_Inverted_Short_Mordent 一个短的锯齿符号
     如果四分音符C音上又这个符号就是要弹奏： 
     （1）C-D-C, 前两个是32分音符长，第三个是8分音符长加浮点
     （2）C-D-C, 前两个是16分音符长，第三个是8分音符长
     
     2.复顺波音 Articulation_Inverted_Long_Mordent 一个短的锯齿符号， 同顺波音
     如果四分音符C音上又这个符号就是要弹奏：
     （1）C-D-C-D-C, 前4个是32分音符长，第5个是8分音符长
     
     3. 逆波音（Inverted Mordent/lower mordent）或下波音 Articulation_Inverted_Short_Mordent
     : a shake sign crossed by a vertical line:一个锯齿符号中间穿过一条竖线
     Articulation_Short_Mordent
     如果四分音符C音上又这个符号就是要弹奏： 
     （1）C-B-C, 前两个是32分音符长，第三个是8分音符长加浮点
     （2）C-B-C, 前两个是16分音符长，第三个是8分音符长
     
     4. 复逆波音： 一个长锯齿符号中间穿过一条竖线
     Articulation_Long_Mordent
     如果四分音符C音上又这个符号就是要弹奏： C-B-C-B-C  前4个是32分音符长，第5个是8分音符长
     
     如果波音上方或下方加了个变音：b或#
     那么升高或者降低的音（如B，D）要加上b或# （演奏成Bb,D#等）
     */
    else if (art_type == Articulation_Inverted_Short_Mordent || art_type==Articulation_Inverted_Long_Mordent ||
             art_type == Articulation_Short_Mordent)
    {
        int tmp_x=x-LINE_H;
        int tmp_y=y;
        if (art_type == Articulation_Inverted_Short_Mordent) {
            ART_MORDENT_UPPER(tmp_x+1, tmp_y);
        }else if (art_type==Articulation_Short_Mordent){
            ART_MORDENT_LOWER(tmp_x+1, tmp_y);
        }else {
            ART_MORDENT_LONG(tmp_x-1, tmp_y);
        }
        if (art.accidental_mark==Accidental_Natural) {
            FLAG_STOP(tmp_x+LINE_H, tmp_y+1.5*LINE_H, 1);
        }else if (art.accidental_mark==Accidental_Sharp) {
            FLAG_SHARP(tmp_x+LINE_H, tmp_y+1.5*LINE_H, 1);
        }else if (art.accidental_mark==Accidental_Flat) {
            FLAG_FLAT(tmp_x+LINE_H, tmp_y+1.5*LINE_H, 1);
        }
    }
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
    else if (art_type == Articulation_Turn) {
//        if (y>start_y) {
//            y=start_y;
//        }
        if (art_placement_above) {
            ART_TURN(x-5, y-LINE_H*0);
        }else
        {
            ART_TURN(x-5, y+LINE_H*0);
        }
        
        if (art.accidental_mark==Accidental_Natural) {
            FLAG_STOP(x, y+1.5*LINE_H, 1);
        }else if (art.accidental_mark==Accidental_Sharp) {
            FLAG_SHARP(x, y+1.5*LINE_H, 1);
        }else if (art.accidental_mark==Accidental_Flat) {
            FLAG_FLAT(x, y+1.5*LINE_H, 1);
        }
    }
    else if(art_type==Articulation_Down_Bow){
        if (art_placement_above) {
            ART_BOWDOWN(x-5, y-LINE_H*1.8);
        }else
        {
            ART_BOWDOWN_BELOW(x-5, y-LINE_H*3.5);
        }
    }
    else if(art_type==Articulation_Up_Bow){
        if (art_placement_above) {
            ART_BOWUP(x-5, y-LINE_H*1.8);
        }else
        {
            ART_BOWUP_BELOW(x-5, y-LINE_H*3.5);
        }
    }
    //fingering_placement 指法
    /*
    else if ((art_type >= Articulation_Finger_1 && art_type<=Articulation_Finger_5) || art_type==Articulation_Open_String)
    {
        //NSString *tmp=[NSString stringWithFormat:@"%d",art_type-Articulation_Finger_1+1];
        NSString *tmp=(art_type==Articulation_Open_String)?@"30":[NSString stringWithFormat:@"3%x",art_type-Articulation_Finger_1+1];
        
        if (art_type==Articulation_Finger_1) {
            x+=1;
        }
        if (art_placement_above)
        {
//            y+=(-1.5*LINE_H);
        }else
        {
//            y+=(+1.5*LINE_H);
        }
        //@"39"
        GLYPH_Petrucci(x+2, y-0, GLYPH_FINGER_SIZE, 0, tmp);
    }*/else if (art_type == Articulation_Pedal_Down || art_type==Articulation_Pedal_Up)
    {
        float tmp_x=x;
        float tmp_y=start_y+LINE_H*8+STAFF_OFFSET[1];// - note_art->art_offset.offset_y*OFFSET_Y_UNIT;
        if (art_type==Articulation_Pedal_Down) //踩下踏板
        {
            ART_PEDAL_DOWN(tmp_x-LINE_H*1, tmp_y);
        }else if (art_type==Articulation_Pedal_Up) //松开踏板
        {
            ART_PEDAL_UP(tmp_x-LINE_H*1, tmp_y);
        }else if (art_type==Articulation_Toe_Pedal || art_type==Articulation_Heel_Pedal){
            //Articulation_Toe_Pedal
            //Articulation_Heel_Pedal 脚后跟踩踏板
        }else{
            NSLog(@"Error: unknown aa art_type=0x%x", art_type);
        }
    }else if(art_type == Articulation_Major_Trill || art_type==Articulation_Minor_Trill)
    {
    }else{
        return NO;
    }
    return YES;
}

- (BOOL) drawSvgAccidental:(AccidentalType) accidental_type acc_x:(float)acc_x acc_y:(float)y isGrace:(BOOL) isGrace
{
    //accidental 升降符号
    if (accidental_type>Accidental_Normal) {
        //UIImage *img;
        float zoom=1;
        if (isGrace) {
            zoom=YIYIN_ZOOM+0.1;
            acc_x+=1;
        }
        if (accidental_type == Accidental_Sharp) {
            FLAG_SHARP(acc_x-0.7*LINE_H*zoom, y, zoom);
        }else if (accidental_type == Accidental_DoubleSharp) {
            FLAG_DOUBLE_SHARP(acc_x-0.9*LINE_H*zoom, y,zoom);
        }else if (accidental_type == Accidental_DoubleSharp_Caution) {
            FLAG_DOUBLE_SHARP_CAUTION(acc_x-1.5*LINE_H*zoom, y);
        }else if(accidental_type == Accidental_Sharp_Caution){
            FLAG_SHARP_CAUTION(acc_x-1.5*LINE_H*zoom, y);
        }else if (accidental_type == Accidental_Natural) {
            FLAG_STOP(acc_x-0.7*LINE_H*zoom, y, zoom);
        }else if(accidental_type == Accidental_Natural_Caution){
            FLAG_STOP_CAUTION(acc_x-2*LINE_H*zoom, y, zoom);
        }else if(accidental_type == Accidental_Flat){
            FLAG_FLAT(acc_x-0.6*LINE_H*zoom, y, zoom);
        }else if(accidental_type == Accidental_DoubleFlat){
            FLAG_DOUBLE_FLAT(acc_x-1.1*LINE_H*zoom, y);
        }else if(accidental_type == Accidental_Flat_Caution){
            FLAG_FLAT_CAUTION(acc_x-2.5*LINE_H*zoom, y);
        }else{
            return NO;
        }
    }
    return YES;
}

//
//+ (BOOL)isRetinaDevice
//{
//    static int ret=-1;
//    if (ret==-1) {
//        ret=0;
//        if ([UIScreen instancesRespondToSelector:@selector(currentMode)]) {
//            CGSize real_screen_size=[[UIScreen mainScreen] currentMode].size;
//            //retina iphone 2x(320,480) = (640,960)
//            //retina ipad 2x(768,1024) = (1536,2048)
//            if (real_screen_size.width==640 || real_screen_size.width==2*768) {
//                ret=1;
//            }
//        }
//    }
//    return ret;
//}
@end



