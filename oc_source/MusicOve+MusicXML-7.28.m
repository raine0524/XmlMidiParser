//
//  MusicOve+MusicXML.m
//  ReadStaff
//
//  Created by yan bin on 13-4-19.
//
//

@import CoreMIDI;
@import AudioToolbox;
#import "MusicOve+MusicXML.h"
#import "TBXML.h"
#import "ZipArchive.h"
#import "NewPlayMidi.h"
#import "MeasureToTick.h"
#import "MidiFile.h"
#import "MidiFileSerialize.h"

#define READ_SUB_INT(var, sub, parent_elem)  \
{                               \
if(parent_elem){    \
TBXMLElement *divisions_elem = [TBXML childElementNamed:sub parentElement:parent_elem]; \
if (divisions_elem!=nil) {      \
var = [[TBXML textForElement:divisions_elem] intValue];   \
}                             \
}   \
}

#define READ_SUB_STR(var, sub, parent_elem)  \
{                           \
if(parent_elem){        \
TBXMLElement *temp_elem = [TBXML childElementNamed:sub parentElement:parent_elem]; \
if (temp_elem!=nil) {  \
var = [TBXML textForElement:temp_elem];   \
}else{var=nil;}                    \
}   \
}


#define ONLY_ONE_PAGE

@implementation OveMusic (MusicXML)

#pragma mark - read MusicXML

static float duration_per_256th;
static BOOL chord_inBeam=NO;

- (int)numOf32ndOfNoteType:(NoteType)note_type dots:(int)dots {
    int trill_num_of_32nd;
    if (note_type==Note_Whole) {
        trill_num_of_32nd=32;//32;
    }else if (note_type==Note_Half) {
        trill_num_of_32nd=16;
    }else if (note_type==Note_Quarter) {
        trill_num_of_32nd=8;
    }else if (note_type==Note_Eight) {
        trill_num_of_32nd=4;
    }else{
        trill_num_of_32nd=6;
    }
    if (dots>0) {
        trill_num_of_32nd+=trill_num_of_32nd/2;
    }
    return trill_num_of_32nd;
}

//pitch_step:1..7
//pitch_alter:-1,0,+1
- (int)noteValueForStep:(int)pitch_step octave:(int)pitch_octave alter:(int)pitch_alter {
    int note_value=(1+pitch_octave)*12+pitch_alter;
    if (pitch_step==2) { //D
        note_value+=2;
    }else if (pitch_step==3) { //E
        note_value+=4;
    }else if (pitch_step==4) { //F
        note_value+=5;
    }else if (pitch_step==5) { //G
        note_value+=7;
    }else if (pitch_step==6) { //A
        note_value+=9;
    }else if (pitch_step==7) { //B
        note_value+=11;
    }
    return note_value;
}

- (OveNote*) parseNote:(TBXMLElement*)note_elem isChord:(BOOL *)isChord inMeasure:(OveMeasure*)measure staff:(int)start_staff tick:(int)tick
{
    //self.time_modification=0;
    NSString *name = [TBXML elementName:note_elem];
    if (note_elem==nil) {
        return nil;
    }
    if ([name isEqualToString:@"note"]) {
        //<note default-x="149">
        NSString *default_x_str = [TBXML valueOfAttributeNamed:@"default-x" forElement:note_elem];
        int start_offset=[default_x_str intValue];
        if (measure.notes.count==0) {
            measure.xml_firstnote_offset_x=start_offset;
            if (measure.xml_new_line) {
                measure.meas_length_size-=start_offset;
            }
        }

        int duration=0, staff=1, voice=0;
        int pitch_step=0,pitch_octave=0,pitch_alter=0,note_value=0;
        int stem_default_y=0;
        unsigned char tie_pos=0;
        BOOL inBeam=NO, isGrace=NO, isRest=NO,stem_up=NO;
        int dots=0;

        NoteType note_type=Note_None;
        NSString *accidental=nil;
        NSMutableDictionary *xml_beams=nil;
        NSMutableArray *xml_ties=nil, *xml_slurs=nil, *xml_tuplets=nil;
        //BOOL have_tuplets=NO;
        //NSMutableArray *xml_tied_types=nil;
        NSMutableArray *note_arts=nil, *xml_lyrics=nil, *xml_fingers=nil;
        
        TBXMLElement *elem = note_elem->firstChild;
        
        while (elem) {
            name = [TBXML elementName:elem];
            if ([name isEqualToString:@"duration"]) {
                duration=[[TBXML textForElement:elem] intValue];
                //self.duration_display=self.duration;
            }else if ([name isEqualToString:@"voice"]) {
                //voice
                voice=[[TBXML textForElement:elem] intValue];
            }else if ([name isEqualToString:@"chord"]) {
                *isChord=YES;
                inBeam=chord_inBeam;
            }else if ([name isEqualToString:@"dot"]) {
                dots++;
            }else if ([name isEqualToString:@"grace"]) {
                //grace
                isGrace=YES;
            }else if ([name isEqualToString:@"staff"]) {
                staff = [[TBXML textForElement:elem] intValue];
            }else if ([name isEqualToString:@"accidental"]) {
                accidental=[TBXML textForElement:elem];
                //READ_SUB_STR(accidental, @"accidental", note_elem);
            }else if ([name isEqualToString:@"stem"]) {
                //stem
                TBXMLElement *stem_elem=elem;
                if (stem_elem) {
                    NSString *stem=[TBXML textForElement:stem_elem];
                    if (stem && [stem isEqualToString:@"up"]) {
                        stem_up=YES;
                    }else
                    {
                        stem_up=NO;
                    }
                    NSString *number=[TBXML valueOfAttributeNamed:@"default-y" forElement:stem_elem];
                    if (number) {
                        stem_default_y = [number intValue];
                    }
                }
            }else if ([name isEqualToString:@"beam"]) {
                NSString *number=[TBXML valueOfAttributeNamed:@"number" forElement:elem];
                if (xml_beams==nil) {
                    xml_beams=[[NSMutableDictionary alloc]initWithCapacity:6];
                }
                if (number==nil) {
                    number=@"1";
                }
                [xml_beams setObject:[TBXML textForElement:elem] forKey:number];
                inBeam=YES;
            }else if ([name isEqualToString:@"type"]) {
                //type
                NSString* type=nil;           //256th, 128th, 64th, 32nd, 16th, eighth, quarter, half, whole, breve, and long
                READ_SUB_STR(type, @"type", note_elem);
                if (type) {
                    if ([type isEqualToString:@"breve"]) {
                        note_type=Note_DoubleWhole;
                    }else if ([type isEqualToString:@"whole"]) {
                        note_type=Note_Whole;
                    }else if ([type isEqualToString:@"half"]) {
                        note_type=Note_Half;
                    }else if ([type isEqualToString:@"quarter"]) {
                        note_type=Note_Quarter;
                    }else if ([type isEqualToString:@"eighth"]) {
                        note_type=Note_Eight;
                    }else if ([type isEqualToString:@"16th"]) {
                        note_type=Note_Sixteen;
                    }else if ([type isEqualToString:@"32nd"]) {
                        note_type=Note_32;
                    }else if ([type isEqualToString:@"64th"]) {
                        note_type=Note_64;
                    }else if ([type isEqualToString:@"128th"]) {
                        note_type=Note_128;
                    }else if ([type isEqualToString:@"256th"]) {
                        note_type=Note_256;
                    }else{
                        NSLog(@"Error: unknow note_type=%@",type);
                    }
                    if (duration>0) {
                        duration_per_256th=note_type*1.0/duration;
                    }
                }else{
                    //NSLog(@"Error: no note type");
                    note_type=duration_per_256th*duration;
                }
            }else if ([name isEqualToString:@"rest"]) {
                NSString *step=nil;
                isRest=YES;
                READ_SUB_STR(step, @"display-step", elem);
                if (step) {
                    if ([step isEqualToString:@"C"])pitch_step=1;
                    else if ([step isEqualToString:@"D"])pitch_step=2;
                    else if ([step isEqualToString:@"E"])pitch_step=3;
                    else if ([step isEqualToString:@"F"])pitch_step=4;
                    else if ([step isEqualToString:@"G"])pitch_step=5;
                    else if ([step isEqualToString:@"A"])pitch_step=6;
                    else if ([step isEqualToString:@"B"])pitch_step=7;
                    else NSLog(@"Error: unknow reset step=%@",step);
                }else{
                    pitch_step=0;
                }
                READ_SUB_INT(pitch_octave, @"display-octave", elem);
            }else if ([name isEqualToString:@"pitch"]) {
                NSString *step=nil;
                READ_SUB_STR(step, @"step", elem);
                if (step) {
                    if ([step isEqualToString:@"C"])pitch_step=1;
                    else if ([step isEqualToString:@"D"])pitch_step=2;
                    else if ([step isEqualToString:@"E"])pitch_step=3;
                    else if ([step isEqualToString:@"F"])pitch_step=4;
                    else if ([step isEqualToString:@"G"])pitch_step=5;
                    else if ([step isEqualToString:@"A"])pitch_step=6;
                    else if ([step isEqualToString:@"B"])pitch_step=7;
                    else NSLog(@"Error: unknow pitch step=%@",step);
                }
                READ_SUB_INT(pitch_alter, @"alter", elem);
                READ_SUB_INT(pitch_octave, @"octave", elem);
                note_value=[self noteValueForStep:pitch_step octave:pitch_octave alter:pitch_alter];
                /*
                note_value=(1+pitch_octave)*12+pitch_alter;
                if (pitch_step==2) { //D
                    note_value+=2;
                }else if (pitch_step==3) { //E
                    note_value+=4;
                }else if (pitch_step==4) { //F
                    note_value+=5;
                }else if (pitch_step==5) { //G
                    note_value+=7;
                }else if (pitch_step==6) { //A
                    note_value+=9;
                }else if (pitch_step==7) { //B
                    note_value+=11;
                }
                */
            }else if ([name isEqualToString:@"notations"]) {
                //<slur number="1" placement="above" type="start"/>
                TBXMLElement *slur_elem = [TBXML childElementNamed:@"slur" parentElement:elem];
                while (slur_elem) {
                    if (xml_slurs==nil) {
                        xml_slurs=[[NSMutableArray alloc]init ];
                    }
                    NSString* number = [TBXML valueOfAttributeNamed:@"number" forElement:slur_elem];
                    if (number==nil) {
                        number=@"1";
                    }
                    NSString *placement = [TBXML valueOfAttributeNamed:@"placement" forElement:slur_elem];
                    NSString *type = [TBXML valueOfAttributeNamed:@"type" forElement:slur_elem];
                    NSString *slur_bezier_y = [TBXML valueOfAttributeNamed:@"bezier-y" forElement:slur_elem];
                    NSString *slur_default_y = [TBXML valueOfAttributeNamed:@"default-y" forElement:slur_elem];
                    NSString *slur_default_x = [TBXML valueOfAttributeNamed:@"default-x" forElement:slur_elem];
                    if ([type isEqualToString:@"start"] || [type isEqualToString:@"stop"]) {
                        NSMutableDictionary *slur_value=[[NSMutableDictionary alloc]init ];
                        
                        [xml_slurs addObject:slur_value];
                        
                        [slur_value setObject:number forKey:@"number"];
                        [slur_value setObject:type forKey:@"type"];
                        
                        if (placement) {
                            [slur_value setObject:placement forKey:@"placement"];
                        }
                        if (slur_bezier_y) {
                            [slur_value setObject:slur_bezier_y forKey:@"bezier-y"];
                        }
                        if (slur_default_x) {
                            [slur_value setObject:slur_default_x forKey:@"default-x"];
                        }
                        if (slur_default_y) {
                            [slur_value setObject:slur_default_y forKey:@"default-y"];
                        }
                        [slur_value setObject:@(measure.notes.count) forKey:@"note_index"];
                        [slur_value setObject:@(measure.number) forKey:@"measure_index"];
                    }
                    slur_elem = [TBXML nextSiblingNamed:@"slur" searchFromElement:slur_elem];
                }
                //tied_type
                //<tied type="start"/>
                TBXMLElement *tied_elem = [TBXML childElementNamed:@"tied" parentElement:elem];
                while (tied_elem) {
                    NSString *orientation = [TBXML valueOfAttributeNamed:@"orientation" forElement:tied_elem]; //under, over
                    if (orientation==nil) {
                        orientation=@"over";
                    }
                    NSString *number=[TBXML valueOfAttributeNamed:@"number" forElement:tied_elem];
                    if (number==nil) {
                        number=@"0";
                    }
                    NSString *type=[TBXML valueOfAttributeNamed:@"type" forElement:tied_elem];
                    if (type) {
                        if (xml_ties==nil) {
                            xml_ties=[[NSMutableArray alloc]initWithCapacity:3];
                        }
                        [xml_ties addObject:@{@"number":number, @"type": type, @"orientation":orientation}];
                        
                        if ([type isEqualToString:@"start"]) {
                            tie_pos|=Tie_LeftEnd;
                        }else{
                            tie_pos|=Tie_RightEnd;
                        }
                    }
                    tied_elem = [TBXML nextSiblingNamed:@"tied" searchFromElement:tied_elem];
                }

                //tuplet
                TBXMLElement *tuplet_elem = [TBXML childElementNamed:@"tuplet" parentElement:elem];
                while (tuplet_elem) {
                    if (xml_tuplets==nil) {
                        xml_tuplets=[NSMutableArray new];
                    }
                    NSString *type = [TBXML valueOfAttributeNamed:@"type" forElement:tuplet_elem]; //start, stop
                    NSString *show_number=[TBXML valueOfAttributeNamed:@"show-number" forElement:tuplet_elem];
                    if (show_number==nil) {
                        show_number=@"";
                    }
                    NSString *bracket=[TBXML valueOfAttributeNamed:@"bracket" forElement:tuplet_elem];
                    BOOL needBracket=NO;
                    if (bracket && [bracket isEqualToString:@"yes"]) {
                        needBracket=YES;
                    }
                    //if ([type isEqualToString:@"start"] && ![show_number isEqualToString:@"none"])
                    {
                        //have_tuplets=YES;
                    }
                    NSString *number=[TBXML valueOfAttributeNamed:@"number" forElement:tuplet_elem];
                    if (number==nil) {
                        number=@"1";
                    }
                    [xml_tuplets addObject:@{
                                             @"type":type,
                                             @"number":number,
                                             @"show-number":show_number,
                                             @"bracket":@(needBracket)
                                             }];
                    tuplet_elem = [TBXML nextSiblingNamed:@"tuplet" searchFromElement:tuplet_elem];
                }

                //articulations
                TBXMLElement *articulations_elem = [TBXML childElementNamed:@"articulations" parentElement:elem];
                if (articulations_elem) {
                    //self.articulation=[XmlNoteArticulation parseArticulation:articulations_elem];
                    TBXMLElement *child_elem = articulations_elem->firstChild;//[TBXML childElementNamed:@"text" parentElement:lyric_elem];
                    if (note_arts==nil) {
                        note_arts=[[NSMutableArray alloc]init];
                    }
                    while(child_elem!=nil)
                    {
                        /*
                         accent:     加强音（或重音）﹝意大利语：Marcato，意指显著 Accento﹞指将某一音符或和弦奏得更响、更大力，它以向右的“›”符号标示。
                         strong_accent:  特加强音（或重音）﹝意大利语：Marcatimisso﹞与加强音相似，但较加强音更响，并以向上的“^”标示
                         staccato:   断音（意大利语：Staccato，意指“分离”）又称跳音，特指音符短促的发音，并于音符上加上一小点表示。
                         tenuto:     持续音（或保持音）﹝意大利语：Tenuto，意指保持﹞，特指将某一音符奏得比较长，也有些演译是将此音奏得比较响，其标示为一横线，位于音符上方或下方，视乎音符的方向而定。
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
                        NSString *art_name = [TBXML elementName:child_elem];
                        NSString *placement=[TBXML valueOfAttributeNamed:@"placement" forElement:child_elem];

                        NSDictionary *art_values=@{@"accent": @(Articulation_Marcato),
                                                   @"strong-accent": @(Articulation_SForzando),
                                                   @"staccato": @(Articulation_Staccato),
                                                   @"tenuto": @(Articulation_Tenuto),
                                                   @"detached-legato": @(Articulation_Detached_Legato),
                                                   @"staccatissimo": @(Articulation_Staccatissimo),
                                                   @"spiccato": @(Articulation_SForzando),
                                                   @"scoop": @(Articulation_SForzando_Dot),
                                                   @"plop": @(Articulation_None),
                                                   @"doit": @(Articulation_None),
                                                   @"alloff": @(Articulation_None),
                                                   @"breath-mark": @(Articulation_None),
                                                   @"caesura": @(Articulation_None),
                                                   @"stress": @(Articulation_SForzando_Dot),
                                                   @"other-articulation": @(Articulation_None),
                                                   };
                        ArticulationType art_type=[[art_values objectForKey:art_name] intValue];
                        if (art_type==Articulation_None || art_type==0) {
                            NSLog(@"Error unknow articulations type=%@",art_name);
                        }
                        //check if there already have same art
                        BOOL alreadyHave=NO;
                        for (NoteArticulation *temp_art in note_arts) {
                            if (temp_art.art_type==art_type) {
                                alreadyHave=YES;
                                break;
                            }
                        }
                        //合并Articulation_Staccato+Articulation_SForzando=Articulation_SForzando_Dot
                        if (art_type==Articulation_Staccato || art_type==Articulation_SForzando){
                            for (NoteArticulation *temp_art in note_arts) {
                                if ((temp_art.art_type==Articulation_SForzando && art_type==Articulation_Staccato)||
                                    (temp_art.art_type==Articulation_Staccato && art_type==Articulation_SForzando)
                                    ) {
                                    temp_art.art_type=Articulation_SForzando_Dot;
                                    alreadyHave=YES;
                                    break;
                                }
                            }
                        }
                        //合并Articulation_Marcato+Articulation_Staccato=Articulation_Marcato_Dot
                        if (art_type==Articulation_Staccato || art_type==Articulation_Marcato){
                            for (NoteArticulation *temp_art in note_arts) {
                                if ((temp_art.art_type==Articulation_Marcato && art_type==Articulation_Staccato)||
                                    (temp_art.art_type==Articulation_Staccato && art_type==Articulation_Marcato)
                                    ) {
                                    temp_art.art_type=Articulation_Marcato_Dot;
                                    alreadyHave=YES;
                                    break;
                                }
                            }
                        }
                        
                        if (!alreadyHave) {
                            NoteArticulation *art=[[NoteArticulation alloc]init];
                            [note_arts addObject:art];
                            art.art_type=art_type;
                            if ([placement isEqualToString:@"above"]) {
                                art.art_placement_above=YES;
                            }
                            
                            art.offset=[[OffsetElement alloc]init];
#if 1
                            art.offset.offset_y=0;
                            art.offset.offset_x=0;
#else
                            art.offset.offset_x=[[TBXML valueOfAttributeNamed:@"default-x" forElement:child_elem] intValue];
                            NSString *default_y=[TBXML valueOfAttributeNamed:@"default-y" forElement:child_elem];
                            if (art.art_type==Articulation_Staccato || art.art_type==Articulation_Tenuto || art.art_type==Articulation_Marcato || art.art_type==Articulation_Staccatissimo || art.art_type==Articulation_SForzando) {
                                art.offset.offset_y=0;
                                art.offset.offset_x=0;
                            }else if (default_y) {
                                art.offset.offset_y=[default_y intValue];
                            }else if (placement) {
                                if (art.art_placement_above) {
                                    art.offset.offset_y+=LINE_height;
                                }else{
                                    art.offset.offset_y-=LINE_height;
                                }
                            }
#endif
                        }

                        //NSString *position=[MusicPosition parsePosition:child_elem];
                        
                        child_elem = child_elem->nextSibling;// [TBXML nextSiblingNamed:@"clef" searchFromElement:clef_elem];
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
                //ornaments: 
                TBXMLElement *ornaments_elem = [TBXML childElementNamed:@"ornaments" parentElement:elem];
                if (ornaments_elem) {
                    if (note_arts==nil) {
                        note_arts=[[NSMutableArray alloc]init];
                    }
                    
                    NSString *accidental_mark=nil;
                    TBXMLElement *accidental_mark_elem = [TBXML childElementNamed:@"accidental-mark" parentElement:ornaments_elem];
                    if (accidental_mark_elem) {
                        accidental_mark=[TBXML textForElement:accidental_mark_elem];
                    }else {
                        accidental_mark_elem = [TBXML childElementNamed:@"accidental-mark" parentElement:elem];
                        if (accidental_mark_elem) {
                            accidental_mark=[TBXML textForElement:accidental_mark_elem];
                        }
                    }
                    
                    NoteArticulation *trill_art=nil;//for wavy-line
                    TBXMLElement *ornaments_child_elem = ornaments_elem->firstChild;
                    while (ornaments_child_elem) {
                        NSString *art_name = [TBXML elementName:ornaments_child_elem];
                        NSDictionary *ornaments_values=@{@"tremolo": @(Articulation_Tremolo_Eighth),
                                                         @"turn": @(Articulation_Turn),
                                                         @"delayed-turn": @(Articulation_Turn),
                                                         @"inverted-turn": @(Articulation_Turn),
                                                         @"delayed-inverted-turn": @(Articulation_Turn),
                                                         @"vertical-turn": @(Articulation_Turn),
                                                         @"mordent": @(Articulation_Short_Mordent),
                                                         @"inverted-mordent": @(Articulation_Inverted_Short_Mordent),
                                                         @"other-ornament": @(Articulation_None),
                                                         @"schleifer": @(Articulation_None),
                                                         @"wavy-line": @(Articulation_None),
                                                         @"shake": @(Articulation_None),
                                                         @"trill-mark": @(Articulation_Major_Trill),
                                                   };
                        NSNumber *art_type_num=[ornaments_values objectForKey:art_name];
                        if (art_type_num==nil || [art_type_num intValue]==Articulation_None) {
                            NSLog(@"Error unknow ornaments type=%@",art_name);
                        }else{
                            NSString *placement=[TBXML valueOfAttributeNamed:@"placement" forElement:ornaments_child_elem];
                            
                            NoteArticulation *art=[[NoteArticulation alloc]init];
                            [note_arts addObject:art];
                            art.art_type=[art_type_num intValue];
                            art.offset=[[OffsetElement alloc]init];
                            art.offset.offset_x=[[TBXML valueOfAttributeNamed:@"default-x" forElement:ornaments_child_elem] intValue];
//                            art.offset.offset_y=[[TBXML valueOfAttributeNamed:@"default-y" forElement:ornaments_child_elem] intValue];
//                            if (art.art_type==Articulation_Turn) {
//                                art.offset.offset_y=0;
//                            }
                            if (![placement isEqualToString:@"below"]) {
                                art.art_placement_above=YES;
                            }
                            if (art.art_type==Articulation_Tremolo_Eighth) {
                                int num=[[TBXML textForElement:ornaments_child_elem]intValue];
                                if (num==2) {
                                    art.art_type=Articulation_Tremolo_Sixteenth;
                                }else if (num==3) {
                                    art.art_type=Articulation_Tremolo_Thirty_Second;
                                }else if (num==4) {
                                    art.art_type=Articulation_Tremolo_Sixty_Fourth;
                                }
                            }
//                            if (has_wavy_line) {
//                                art.has_wavy_line=YES;
//                                art.wavy_number=wavy_num;
//                            }
                            if (accidental_mark) {
                                NSLog(@"accidental_mark:%@", accidental_mark);
                                if ([accidental_mark isEqualToString:@"natural"]) {
                                    art.accidental_mark=Accidental_Natural;
                                }else if ([accidental_mark isEqualToString:@"sharp"]) {
                                    art.accidental_mark=Accidental_Sharp;
                                }else if ([accidental_mark isEqualToString:@"flat"]) {
                                    art.accidental_mark=Accidental_Flat;
                                }
                            }

                            if (art.art_type==Articulation_Major_Trill) {
                                trill_art=art;
                                art.trillNoteType=Note_32;
                                art.trill_interval=1;
                                art.offset.offset_y=0;
                                art.offset.offset_x=0;
                                art.trill_num_of_32nd=[self numOf32ndOfNoteType:note_type dots:dots];
                            }
                            if (art.art_type==Articulation_Short_Mordent || art.art_type==Articulation_Inverted_Short_Mordent) {
                                art.offset.offset_x=0;
                                NSString *isLong=[TBXML valueOfAttributeNamed:@"long" forElement:ornaments_child_elem];
                                if (isLong && [isLong isEqualToString:@"yes"]) {
                                    art.art_type=Articulation_Inverted_Long_Mordent;
                                }
                            }
                        }
                        ornaments_child_elem=ornaments_child_elem->nextSibling;
                    }
                    //check wavy-line
                    BOOL has_wavy_line=NO;
                    int wavy_num=0;
//                    if (trill_art)
                    {
                        TBXMLElement *wavy_line_elem = [TBXML childElementNamed:@"wavy-line" parentElement:ornaments_elem];
                        while (wavy_line_elem) {
                            NSString *type=[TBXML valueOfAttributeNamed:@"type" forElement:wavy_line_elem];
                            wavy_num=[[TBXML valueOfAttributeNamed:@"number" forElement:wavy_line_elem] intValue];
                            if ([type isEqualToString:@"start"]) {
                                has_wavy_line=YES;
                                if (trill_art) {
                                    trill_art.has_wavy_line=YES;
                                    trill_art.wavy_number=wavy_num;
                                }
                            }else if ([type isEqualToString:@"stop"]) {
                                int more_trill_num_of_32nd=0;
                                BOOL found_start_trill=NO;
                                if (!isGrace) {
                                    more_trill_num_of_32nd=[self numOf32ndOfNoteType:note_type dots:dots];
                                }
                                if (has_wavy_line) {
                                    if (trill_art) {
                                        trill_art.wavy_stop_measure=0;//measure.number - (self.measures.count-1);
                                        trill_art.wavy_stop_note=(int)measure.notes.count;
                                        trill_art.trill_num_of_32nd+=more_trill_num_of_32nd;
                                    }
                                }else
                                    for (int mm=(int)self.measures.count-1; mm>=0 && !found_start_trill; mm--) {
                                        OveMeasure *temp_measure=self.measures[mm];
                                        for (int nn=(int)temp_measure.notes.count-1; nn>=0 && !found_start_trill; nn--) {
                                            OveNote *temp_note=temp_measure.notes[nn];
                                            if (temp_note.staff==staff) {
                                                for (NoteArticulation *temp_art in temp_note.note_arts) {
                                                    if (temp_art.has_wavy_line && temp_art.wavy_number==wavy_num) {
                                                        temp_art.wavy_stop_measure=measure.number - mm;
                                                        temp_art.wavy_stop_note=(int)measure.notes.count;
                                                        //                                                if (!isGrace) {
                                                        //                                                    temp_art.trill_num_of_32nd+=[self numOf32ndOfNoteType:note_type dots:dots];
                                                        //                                                }
                                                        temp_art.trill_num_of_32nd+=more_trill_num_of_32nd;
                                                        nn=-1;
                                                        mm=-1;
                                                        found_start_trill=YES;
                                                        break;
                                                    }
                                                }
                                                if (!found_start_trill && !temp_note.isGrace) {
                                                    more_trill_num_of_32nd+=[self numOf32ndOfNoteType:temp_note.note_type dots:temp_note.isDot];
                                                }
                                            }
                                            
                                        }
                                    }
                            }
                            wavy_line_elem=[TBXML nextSiblingNamed:@"wavy-line" searchFromElement:wavy_line_elem];
                        }
                    }
                    
                    
                }
                //arpeggiate_position
                TBXMLElement *arpeggiate_elem = [TBXML childElementNamed:@"arpeggiate" parentElement:elem];
                if (arpeggiate_elem) {
                    if (note_arts==nil) {
                        note_arts=[[NSMutableArray alloc]init];
                    }
                    NoteArticulation *art=[[NoteArticulation alloc]init];
                    [note_arts addObject:art];
                    art.art_type=Articulation_Arpeggio;
                    art.offset=[[OffsetElement alloc]init];
                    art.offset.offset_x=[[TBXML valueOfAttributeNamed:@"default-x" forElement:arpeggiate_elem] intValue];
                    art.offset.offset_y=[[TBXML valueOfAttributeNamed:@"default-y" forElement:arpeggiate_elem] intValue];
                    //self.arpeggiate_position=[MusicPosition parsePosition:arpeggiate_elem];
                }
                
                //glissando
                
                //technical
                TBXMLElement *technical_elem = [TBXML childElementNamed:@"technical" parentElement:elem];
                if (technical_elem) {
                    if (note_arts==nil) {
                        note_arts=[[NSMutableArray alloc]init];
                    }
                    TBXMLElement *technical_child_elem = technical_elem->firstChild;
                    while (technical_child_elem) {
                        NSString *art_name = [TBXML elementName:technical_child_elem];
                        if ([art_name isEqualToString:@"fingering"]) {
                            NSString *placement=[TBXML valueOfAttributeNamed:@"placement" forElement:technical_child_elem];
                            NSString *finger_text=[TBXML textForElement:technical_child_elem];
                            
                            NoteArticulation *art=[[NoteArticulation alloc]init];
//                            art.art_type=Articulation_Finger_1+[finger_text intValue]-1;
                            art.art_type=Articulation_Finger;
                            art.finger=finger_text;//[NSString stringWithFormat:@"%c",0x30+[finger_text intValue]];
                            art.art_placement_above=[placement isEqualToString:@"above"];
                            
                            art.offset=[[OffsetElement alloc]init];
                            art.offset.offset_x=[[TBXML valueOfAttributeNamed:@"default-x" forElement:technical_child_elem] intValue];
//                            if (art.offset.offset_x>6) {
//                                art.offset.offset_x=6;
//                            }else if (art.offset.offset_x<-6) {
//                                art.offset.offset_x=-6;
//                            }
                            NSString *default_y=[TBXML valueOfAttributeNamed:@"default-y" forElement:technical_child_elem];
                            /*
                            int offset_y=0;
                            for (NoteArticulation *item in note_arts) {
                                if (item.art_placement_above==art.art_placement_above && (item.art_type==Articulation_Finger)) {
                                    offset_y+=item.offset.offset_y;
                                }
                            }
                            if (art.art_placement_above) {
                                art.offset.offset_y=[default_y intValue]+offset_y;
                            }else{
                                art.offset.offset_y=-[default_y intValue]-offset_y;
                            }
                            */
                            art.offset.offset_y=[default_y intValue];
                            
                            //[note_arts addObject:art];
                            
                            //
                            if (xml_fingers==nil) {
                                xml_fingers=[NSMutableArray new];
                            }
                            [xml_fingers addObject:art];
                        }
                        technical_child_elem=technical_child_elem->nextSibling;
                    }
                }
                
                //fermata:延音：超下的一个小括号里面加一个点
                //<fermata default-x="-5" default-y="31" type="upright"/>
                TBXMLElement *fermata_elem = [TBXML childElementNamed:@"fermata" parentElement:elem];
                if (fermata_elem) {
                    if (note_arts==nil) {
                        note_arts=[[NSMutableArray alloc]init];
                    }
                    NoteArticulation *art=[[NoteArticulation alloc]init];
                    [note_arts addObject:art];
                    art.art_type=Articulation_Fermata;
                    
                    NSString *default_x_str = [TBXML valueOfAttributeNamed:@"default-x" forElement:fermata_elem];
                    NSString *default_y_str = [TBXML valueOfAttributeNamed:@"default-y" forElement:fermata_elem];
                    art.offset=[[OffsetElement alloc] init];
                    art.offset.offset_x=[default_x_str intValue];
                    
                    //self.fermata_position=[MusicPosition parsePosition:fermata_elem];
                    NSString *fermata_type = [TBXML valueOfAttributeNamed:@"type" forElement:fermata_elem]; //upright | inverted
                    if ([fermata_type isEqualToString:@"upright"]) {
                        art.art_placement_above=YES;
                        if (default_y_str) {
                            art.offset.offset_y=[default_y_str intValue]-2*LINE_height;
                            if (art.offset.offset_y<2*LINE_height) {
                                art.offset.offset_y=2*LINE_height;
                            }
                        }
                    }else{
                        art.art_type=Articulation_Fermata_Inverted;
                        if (default_y_str) {
                            art.offset.offset_y=-[default_y_str intValue]-2*LINE_height;
                            if (art.offset.offset_y<2*LINE_height) {
                                art.offset.offset_y=2*LINE_height;
                            }
                        }
                    }
                }
            }else if ([name isEqualToString:@"lyric"]) {
                if (xml_lyrics==nil) {
                    xml_lyrics=[[NSMutableArray alloc]init];
                }
                TBXMLElement *lyric_elem = elem;
                NSMutableDictionary *lyric=[[NSMutableDictionary alloc]init];
                [xml_lyrics addObject:lyric];
                
                //[measure.lyrics addObject:[MusicLyric parseLyric:elem]];
                /*
                 <lyric default-y="-80" number="1" relative-x="9">//歌词
                 <syllabic>single</syllabic>//音节的:"single", "begin", "end", or "middle"
                 <text>1.</text>
                 <elision> </elision> //元音
                 <syllabic>single</syllabic>
                 <text>Should</text>
                 </lyric>
                 */
                NSString *syllabic;
                READ_SUB_STR(syllabic, @"syllabic", lyric_elem);
                if (syllabic) {
                    [lyric setObject:syllabic forKey:@"syllabic"];
                }
                
                int number = [[TBXML valueOfAttributeNamed:@"number" forElement:lyric_elem] intValue];
                if (number<1) {
                    number=1;
                }
                [lyric setObject:[NSNumber numberWithInt:number] forKey:@"number"];
                
                int offset_y=1*[[TBXML valueOfAttributeNamed:@"default-y" forElement:lyric_elem] intValue];
                int offset_x=[[TBXML valueOfAttributeNamed:@"relative-x" forElement:lyric_elem] intValue];
                [lyric setObject:@(offset_x) forKey:@"offset_x"];
                [lyric setObject:@(offset_y) forKey:@"offset_y"];
                //lyric.staff=staff+start_staff;
                //lyric.voice=voice;
                //lyric.verse=number-1;
                //lyric.offset=[[[OffsetElement alloc]init]autorelease];
                //lyric.offset.offset_y=offset_y;
                //lyric.offset.offset_x=offset_x;
                
                NSString *lyric_text=nil;
                TBXMLElement *child_elem = lyric_elem->firstChild;//[TBXML childElementNamed:@"text" parentElement:lyric_elem];
                while(child_elem!=nil)
                {
                    NSString *name=[NSString stringWithFormat:@"%s",child_elem->name];
                    if ([name isEqualToString:@"text"] || [name isEqualToString:@"elision"]) {
                        NSString *tmp=[TBXML textForElement:child_elem];
                        lyric_text=[NSString stringWithFormat:@"%@%@",(lyric_text)?lyric_text:@"", tmp];
                    }
                    child_elem = child_elem->nextSibling;// [TBXML nextSiblingNamed:@"clef" searchFromElement:clef_elem];
                }
                if (lyric_text.length>0) {
                    [lyric setObject:lyric_text forKey:@"text"];
                }
            }else if ([name isEqualToString:@"time-modification"]) {
                NSString *time_modification;
                READ_SUB_STR(time_modification, @"actual-notes", elem);
            }else if ([name isEqualToString:@"instrument"]) {
                
            }else if ([name isEqualToString:@"tie"]) {
                
            }else{
                NSLog(@"Unknow tag \"%@\" in <note>", name);
            }
            
            elem = elem->nextSibling;
        }
        
        //        NSLog(@"note[%d_%d]%1.1f (%@) stem(%@) backup(%d) slur_type(%@)", pitch_step, pitch_octave, duration/4.0,lyric_text,stem, backup_duration,slur_type);
        //        NSLog(@"note[%d_%d]%1.1f (%@) stem(%@) beam1(%@) beam2(%@)", pitch_step, pitch_octave, duration/4.0,lyric_text,stem, beam1,beam2);
        
        OveNote *note=[[OveNote alloc]init];
        note.staff=staff+start_staff;
        note.voice=voice;
        note.isDot=dots;
        note.isGrace=isGrace;
        note.inBeam=inBeam;
        note.isRest=isRest;
        note.stem_up=stem_up;
        if (note_type==Note_None) {
            //if (duration==last_divisions*last_numerator)
            if (duration==last_divisions*last_numerator*4/last_denominator)
            {
                note_type=Note_Whole;
            }else if(duration>0){
                int type=(last_divisions*4)/ duration;
                switch (type) {
                    case 1:
                        note_type=Note_Whole;
                        break;
                    case 2:
                        note_type=Note_Half;
                        break;
                    case 4:
                        note_type=Note_Quarter;
                        break;
                    case 8:
                        note_type=Note_Eight;
                        break;
                    case 16:
                        note_type=Note_Sixteen;
                        break;
                    case 32:
                        note_type=Note_32;
                        break;
                    case 64:
                        note_type=Note_64;
                        break;
                    case 128:
                        note_type=Note_128;
                        break;
                    case 256:
                        note_type=Note_256;
                        break;
                    default:
                        NSLog(@"Error unknow rest type=(%d)/(%d)",duration, last_divisions);
                        break;
                }
            }
        }
        note.note_type=note_type;
        note.xml_stem_default_y=stem_default_y;
        
        if (pitch_octave==0) {
            note.line=0;
        }
//        else{
//            ClefType clefType=last_clefs[note.staff-1];
//            if (note.pos.tick>=last_clefs_tick[note.staff-1]) {
//                clefType=last_clefs[note.staff-1];
//            }else{
//                clefType=measure_start_clefs[note.staff-1];
//            }
//            if (clefType==Clef_Treble) {
//                note.line=((pitch_step-7)+7*(pitch_octave-4));
//            }else{
//                note.line=5+((pitch_step-7)+7*(pitch_octave-3));
//            }
//            if (octave_shift_size!=0 && note.staff==octave_shift_staff) {
//                note.line-=octave_shift_size;
//            }
//            if (isRest && note.line==0) {
//                note.line=1;
//            }
//        }
        if (pitch_octave==0) {
            note.line=0;
        }else if (isRest) {
            ClefType clefType=last_clefs[note.staff-1];
            if (note.pos.tick>=last_clefs_tick[note.staff-1]) {
                clefType=last_clefs[note.staff-1];
            }else{
                clefType=measure_start_clefs[note.staff-1];
            }
            if (clefType==Clef_Treble) {
                note.line=((pitch_step-7)+7*(pitch_octave-4));
            }else{
                note.line=5+((pitch_step-7)+7*(pitch_octave-3));
            }
            if (note.line==0) {
                note.line=1;
            }
        }

        //pos
        note.pos=[[CommonBlock alloc]init];
        note.pos.tick=tick;
        note.pos.start_offset=start_offset;
        note.xml_duration=duration;
        note.xml_slurs=xml_slurs;
        note.note_arts=note_arts;
        note.xml_fingers=xml_fingers;
        note.xml_lyrics=xml_lyrics;
        note.xml_beams=xml_beams;
        note.xml_tuplets=xml_tuplets;
        //note.xml_have_tuplets=have_tuplets;
        
        NoteElem *noteElem=nil;
        if (!isRest) {
            if (noteElem==nil) {
                noteElem=[[NoteElem alloc]init];
                if (note.note_elems==nil) {
                    note.note_elems=[[NSMutableArray alloc]init];
                }
                [note.note_elems addObject:noteElem];
            }
            if (accidental) {
                //accidental: sharp(升半音), flat(降半音), natural(还原), double-sharp, sharp-sharp, flat-flat, natural-sharp, natural-flat, quarter-flat, quarter-sharp, three- quarters-flat, and three-quarters-sharp
                NSDictionary *accidental_values=@{@"sharp": @(Accidental_Sharp),
                                                  @"flat": @(Accidental_Flat),
                                                  @"natural": @(Accidental_Natural),
                                                  @"double-sharp": @(Accidental_DoubleSharp),
                                                  @"sharp-sharp": @(Accidental_Sharp_Caution),
                                                  @"flat-flat": @(Accidental_DoubleFlat),
                                                  @"natural-sharp": @(Accidental_Sharp_Caution),
                                                  @"natural-flat": @(Accidental_Flat_Caution),
                                                  @"quarter-flat": @(Accidental_Flat),
                                                  @"three-quarters-flat": @(Accidental_Flat),
                                                  @"three-quarters-sharp": @(Accidental_Sharp)};
                NSNumber *num=[accidental_values objectForKey:accidental];
                if (num) {
                    noteElem.accidental_type=[num intValue];
                }else{
                    noteElem.accidental_type=Accidental_Normal;
                }
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
            //pitch_octave: 0-10
            //pitch_step: 1-7: CDEFGAB
            //pitch_alter: -1: flat, 0: normal, 1:sharp
            /*
            noteElem.note=(1+pitch_octave)*12+pitch_alter;
            if (pitch_step==2) { //D
                noteElem.note+=2;
            }else if (pitch_step==3) { //E
                noteElem.note+=4;
            }else if (pitch_step==4) { //F
                noteElem.note+=5;
            }else if (pitch_step==5) { //G
                noteElem.note+=7;
            }else if (pitch_step==6) { //A
                noteElem.note+=9;
            }else if (pitch_step==7) { //B
                noteElem.note+=11;
            }*/
            noteElem.note=note_value;
            noteElem.line=note.line;
            noteElem.tie_pos=tie_pos;
            noteElem.velocity=70;
            noteElem.xml_ties=xml_ties;
            noteElem.length_tick=note.xml_duration*480/last_divisions;
            noteElem.xml_pitch_octave=pitch_octave;
            noteElem.xml_pitch_step=pitch_step;
            noteElem.xml_pitch_alter=pitch_alter;
        }
        
        /*
         if (pitch_alter==-1) {
         noteElem.accidental_type=Accidental_Flat;
         }else if (pitch_alter==1) {
         noteElem.accidental_type=Accidental_Sharp;
         }*/
        return note;
    }
    return nil;
}
#define MAX_CLEFS 30
static int last_clefs_tick[MAX_CLEFS]={-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
static ClefType last_clefs[MAX_CLEFS]={-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
static ClefType measure_start_clefs[MAX_CLEFS]={-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
static int last_key_fifths=0, last_numerator=4, last_denominator=4;
static int last_divisions=0;
static int part_staves=1;

//octave_shift
static struct{
    BOOL used;
    //int shift_staff;//0:unused. 1,2: staff
    int shift_size,start_tick,start_measure;
    int stop_tick,stop_measure;
    int octave_start_offset_y;
}octave_shift_data[2];
//static int octave_shift_size=0;
//static int octave_shift_start_tick=0, octave_shift_start_measure=0;
//static int octave_shift_stop_tick=0,octave_shift_stop_measure=0;

//- (BOOL)parseAttributes:(TBXMLElement*)attributes_elem measure:(OveMeasure*)measure staff:(int)start_staff afterNote:(OveNote*)afterNote
- (BOOL)parseAttributes:(TBXMLElement*)attributes_elem measure:(OveMeasure*)measure staff:(int)start_staff afterNote:(OveNote*)afterNote tick:(int)tick
{
    int divisions;
    //attributes
    if(attributes_elem!=nil)
    {
        //divisions
        TBXMLElement *divisions_elem = [TBXML childElementNamed:@"divisions" parentElement:attributes_elem];
        if (divisions_elem!=nil) {
            divisions = [[TBXML textForElement:divisions_elem] intValue];
            last_divisions = divisions;
            measure.xml_division=last_divisions;
        }
        //key
        TBXMLElement *key_elem = [TBXML childElementNamed:@"key" parentElement:attributes_elem];
        if (key_elem!=nil)
        {
            NSString *key_mode=nil;
            int fifths=last_key_fifths;
            //fifths
            READ_SUB_INT(fifths, @"fifths", key_elem);
            //mode
            READ_SUB_STR(key_mode, @"mode", key_elem);
            if ([key_mode isEqualToString:@"minor"]) {
                //fifths*=-1;
            }
            if (measure.number>0 && fifths!=last_key_fifths) {
                measure.key=[[MeasureKey alloc]init];
                measure.key.key=fifths;
                measure.key.previousKey=last_key_fifths;
            }
            last_key_fifths=fifths;
        }
        //time
        TBXMLElement *time_elem = [TBXML childElementNamed:@"time" parentElement:attributes_elem];
        if(time_elem!=nil)
        {
            //beats
            READ_SUB_INT(last_numerator, @"beats", time_elem);
            //beat-type
            READ_SUB_INT(last_denominator, @"beat-type", time_elem);
        }
        //staves
        TBXMLElement *staves_elem = [TBXML childElementNamed:@"staves" parentElement:attributes_elem];
        if (staves_elem!=nil) {
            part_staves = [[TBXML textForElement:staves_elem] intValue];
        }
        
        //clef
        int clef_index=start_staff;
        TBXMLElement *clef_elem = [TBXML childElementNamed:@"clef" parentElement:attributes_elem];
        while(clef_elem!=nil)
        {
            NSString *clef_sign=nil;
            int clef_line=0,clef_number;
            //<clef number="1">
            clef_number = [[TBXML valueOfAttributeNamed:@"number" forElement:clef_elem] intValue];
            if (clef_number>0) {
                clef_index=start_staff+clef_number-1;
            }
            
            //Sign values include G, F, C, percussion, TAB, jianpu, and none
            READ_SUB_STR(clef_sign, @"sign", clef_elem);
            //line
            READ_SUB_INT(clef_line, @"line", clef_elem);
            
            ClefType clefType;
            if ([clef_sign isEqualToString:@"G"] && clef_line==2) {
                clefType=Clef_Treble;
            }else if ([clef_sign isEqualToString:@"F"] && clef_line==4) {
                clefType=Clef_Bass;
            }else if ([clef_sign isEqualToString:@"C"] && clef_line==3) {
                clefType=Clef_Alto;
            }else if ([clef_sign isEqualToString:@"percussion"]) {
                clefType=Clef_Percussion1;
            }else if ([clef_sign isEqualToString:@"TAB"]) {
                clefType=Clef_TAB;
            }else{
                clefType=Clef_Bass;
            }
            
            if (measure.clefs==nil) {
                measure.clefs=[[NSMutableArray alloc]init];
            }
            if (afterNote || (last_clefs[clef_index]!=clefType && measure.number>0))
            {
                MeasureClef *clef=[[MeasureClef alloc]init];
                clef.clef=clefType;
                clef.staff=clef_index+1;
                //clef pos
                clef.pos=[[CommonBlock alloc]init];
                clef.xml_note=(int)measure.notes.count;
#if 0
                if (afterNote && afterNote.staff==clef.staff) {
                    clef.pos.tick=afterNote.pos.tick;
                    last_clefs_tick[clef_index]=clef.pos.tick;
                }else{
                    measure_start_clefs[clef_index]=clefType;
                    clef.pos.tick=0;
                    last_clefs_tick[clef_index]=0;
                }
#else
                if (afterNote && afterNote.staff==clef.staff) {
                    clef.pos.tick=afterNote.pos.tick;
                }else if(tick>0){
                    clef.xml_note=-1;
                    clef.pos.tick=tick-1;
                }else{
                    measure_start_clefs[clef_index]=clefType;
                    clef.pos.tick=0;
                }
                last_clefs_tick[clef_index]=clef.pos.tick;
                
//                clef.pos.tick=tick-1;
//                last_clefs_tick[clef_index]=clef.pos.tick;
#endif
                [measure.clefs addObject:clef];
            }else{
                measure_start_clefs[clef_index]=clefType;//last_clefs[clef_index];
            }
            last_clefs[clef_index]=clefType;
            //last_clefs[clef_index+1]=clefType;//下一个默认和前一个相同。

            //NSLog(@"measure(%d) clef[%d]=%d", measure.number, clef.staff, clefType);
            
            clef_elem = [TBXML nextSiblingNamed:@"clef" searchFromElement:clef_elem];
            clef_index++;
        }
        //NSLog(@"divisions=%d key(fifths=%d) (%d/%d)", divisions, measure.fifths,self.beats,self.beat_type);
    }
    return YES;
}
int metronome_per_minute=0;

-(OveMeasure*) parseMeasure:(TBXMLElement*)measure_elem  staff:(int)start_staff measure:(OveMeasure*)measure
{
    static NSDictionary *DCRepeat=nil;
    if (DCRepeat==nil) {
        DCRepeat=@{@"Coda":@(Repeat_Coda),
                   @"al Coda":@(Repeat_ToCoda),
                   @"To Coda":@(Repeat_ToCoda),
                   @"D.S. al Coda":@(Repeat_DSAlCoda),
                   @"D.S. al Fine":@(Repeat_DSAlFine),
                   @"D.C. al Coda":@(Repeat_DCAlCoda),
                   @"D.C. al Fine":@(Repeat_DCAlFine),
                   @"Da Capo al Fine":@(Repeat_DCAlFine),
                   @"Da Capl al Fine":@(Repeat_DCAlFine),
                   @"D.C.":@(Repeat_DC),
                   @"Fine":@(Repeat_Fine)};
    }
    //OveMeasure *measure=[[OveMeasure alloc]init];
    
    NSString *name = [TBXML elementName:measure_elem];
    if ([name isEqualToString:@"measure"]) {
        //number
        NSString *implicit = [TBXML valueOfAttributeNamed:@"implicit" forElement:measure_elem];
        if (implicit==nil || [implicit isEqualToString:@"no"]) {
            NSString *measure_number;
            measure_number = [TBXML valueOfAttributeNamed:@"number" forElement:measure_elem];
            if ([measure_number hasPrefix:@"X"]) {
                measure_number=[measure_number substringFromIndex:1];
            }
            measure.show_number=[measure_number intValue];
        }
        //measure.number = [measure_number intValue];
        //width
        NSString *measure_width;
        measure_width = [TBXML valueOfAttributeNamed:@"width" forElement:measure_elem];
        if (measure_width) {
            measure.meas_length_size = [measure_width intValue];
            //measure.meas_length_size-=60;//minus clef/key space
            if (self.measures.count==1 && measure.meas_length_size>7*LINE_height) {
                measure.meas_length_size-=7*LINE_height;
            }
        }else{
            //measure.meas_length_size = 0;
            measure.meas_length_size = self.page_width/3;
        }
        //NSLog(@"measure[%d] width=%d", number,width);
        
        //<print new-system="yes"> <system-layout>...</system_layout></print>
        TBXMLElement *print_elem = [TBXML childElementNamed:@"print" parentElement:measure_elem];
        if (print_elem) {
            NSString *new_system=[TBXML valueOfAttributeNamed:@"new-system" forElement:print_elem];
            if ([new_system isEqualToString:@"yes"]) {
                system_index++;
                measure.xml_new_line=YES;
//                if (measure_width && measure.meas_length_size>7*LINE_height) {
//                    measure.meas_length_size-=7*LINE_height;
//                }
            }else{
                measure.xml_new_line=NO;
            }
            NSString *new_page=[TBXML valueOfAttributeNamed:@"new-page" forElement:print_elem];
#ifdef ONLY_ONE_PAGE
            if ([new_page isEqualToString:@"yes"]) {
                measure.xml_new_line=YES;
            }
#else
            if ([new_page isEqualToString:@"yes"]) {
                measure.xml_new_page=YES;
            }else{
                measure.xml_new_page=NO;
            }
#endif
            TBXMLElement *system_layout_elem = [TBXML childElementNamed:@"system-layout" parentElement:print_elem];
            int top_system_distance=0;
            if (system_layout_elem) {
                READ_SUB_INT(measure.xml_system_distance, @"system-distance", system_layout_elem);
                //system_distance[system_index%5]=distance;
//                if (measure.xml_system_distance==0 && measure.number>0) {
//                    OveMeasure *prev=self.measures[measure.number-1];
//                    measure.xml_system_distance=prev.xml_system_distance;
//                }
                if (measure.xml_system_distance==0) {
                    measure.xml_system_distance=default_system_distance;
                }
                READ_SUB_INT(top_system_distance, @"top-system-distance", system_layout_elem);
                measure.xml_system_distance+=top_system_distance;
            }else{
                measure.xml_system_distance=default_system_distance;
            }

//            if (measure.xml_system_distance<min_system_distance) {
//                measure.xml_system_distance=min_system_distance;
//            }else if(measure.xml_system_distance>max_system_distance) {
//                measure.xml_system_distance=max_system_distance;
//            }
            
#ifdef ONLY_ONE_PAGE
//            measure.xml_system_distance+=top_system_distance;
            
#endif
            if (top_system_distance>0) {
                measure.xml_top_system_distance=top_system_distance;
            }else{
                measure.xml_top_system_distance=default_top_system_distance;
            }
            
            TBXMLElement *staff_layout_elem = [TBXML childElementNamed:@"staff-layout" parentElement:print_elem];
            if (staff_layout_elem) {
                READ_SUB_INT(measure.xml_staff_distance, @"staff-distance", staff_layout_elem);
                if (measure.xml_staff_distance<min_staff_distance) {
                    measure.xml_staff_distance=min_staff_distance;
                }else if(measure.xml_staff_distance>max_staff_distance) {
                    measure.xml_staff_distance=max_staff_distance;
                }
                //measure.xml_staff_distance=staff_distance;
                //system_layout=[SystemLayout parse:system_layout_elem];
                //[system_layout retain];
            }
            if (measure.xml_staff_distance==0) {
                measure.xml_staff_distance=default_staff_distance;
            }
        }
//        if (measure.xml_system_distance==0) {
//            measure.xml_system_distance=default_system_distance;
//        }
        if (measure.xml_staff_distance==0) {
            measure.xml_staff_distance=default_staff_distance;
        }
        
        //notes
        TBXMLElement *note_elem=measure_elem->firstChild;
        int temp_backup_duration=0;
        int temp_forward_duration=0;
        //int temp_duration_offset=0;
        int start_offset=0;
        float tick=0;
        
        NSMutableArray *temp_directions=nil;
        OveNote *direction_note=nil;
        OveNote *first_chord_note=nil;
        //MusicAttributes *temp_attributes=nil;
        if (measure.notes==nil) {
            measure.notes=[[NSMutableArray alloc]init ];
        }
        do {
            name=[TBXML elementName:note_elem];
            if ([name isEqualToString:@"note"]) {
                
                BOOL isChord=NO;
                OveNote *note = [self parseNote:note_elem isChord:&isChord inMeasure:measure staff:start_staff tick:tick];
                //calculate note line, depend on clef
                
                if (note.note_elems.count>0) {
                    NoteElem *elem=note.note_elems.firstObject;
                    ClefType clefType;
                    if (tick>last_clefs_tick[note.staff-1]) {
                        clefType=last_clefs[note.staff-1];
                    }else{
                        clefType=measure_start_clefs[note.staff-1];
                    }
                    if (clefType==Clef_Treble) {
                        note.line=((elem.xml_pitch_step-7)+7*(elem.xml_pitch_octave-4));
                    }else{
                        note.line=5+((elem.xml_pitch_step-7)+7*(elem.xml_pitch_octave-3));
                    }
//                    if (octave_shift_size!=0 && note.staff==octave_shift_staff) {
//                        note.line-=octave_shift_size;
//                    }
                    int index=note.staff-1;
                    if (//note.staff==octave_shift_staff &&
                        octave_shift_data[index].shift_size!=0 &&
                        ((measure.number==octave_shift_data[index].start_measure && tick>=octave_shift_data[index].start_tick) || measure.number>octave_shift_data[index].start_measure ) &&
                        (octave_shift_data[index].stop_tick<0 || (tick<octave_shift_data[index].stop_tick && measure.number<=octave_shift_data[index].stop_measure))
                        ) {
                        note.line-=octave_shift_data[index].shift_size;
                    }

//                    if (note.isRest && note.line==0) {
//                        note.line=1;
//                    }
                    elem.line=note.line;
                }
                
                if (!isChord) {
                    [measure.notes addObject:note];
                    note.pos.tick=tick;
                    if (note.pos.start_offset!=0) {
                        start_offset=note.pos.start_offset;
                        //start_offset+=measure.meas_length_size*note.xml_duration/(last_divisions*last_numerator);
                        start_offset+=measure.meas_length_size*note.xml_duration/(last_divisions*last_numerator*4/last_denominator);
                    }else{
                        note.pos.start_offset=start_offset;
                        if (note.isGrace) {
                            //note.pos.start_offset-=measure.meas_length_size*(last_divisions/4)/(last_divisions*last_numerator);
                            note.pos.start_offset-=measure.meas_length_size*(last_divisions/4)/(last_divisions*last_numerator*4/last_denominator);
                        }
                        //start_offset+=measure.meas_length_size*note.xml_duration/(last_divisions*last_numerator);
                        start_offset+=measure.meas_length_size*note.xml_duration/(last_divisions*last_numerator*4/last_denominator);
                    }
                    tick+=note.xml_duration*480.0/last_divisions;
                    if (tick>measure.meas_length_tick) {
                        measure.meas_length_tick=tick;
                    }
                    chord_inBeam=note.inBeam;
                    first_chord_note=note;
                }else{
                    //chord
                    if (note.note_arts!=nil) {
                        if (first_chord_note.note_arts==nil) {
                            first_chord_note.note_arts= [[NSMutableArray alloc]init];
                        }
                        [first_chord_note.note_arts addObjectsFromArray:note.note_arts];
                    }
                    if (note.note_elems) {
                        if (first_chord_note.note_elems==nil) {
                            first_chord_note.note_elems= [[NSMutableArray alloc]init];
                        }
#if 1
                        [first_chord_note.note_elems addObjectsFromArray:note.note_elems];
                        NoteElem *newElem=note.note_elems.firstObject;
                        note.line=newElem.line;
#else
                        NoteElem *newElem=[note.note_elems objectAtIndex:0];
                        int nn=0;
                        for (; nn<first_chord_note.note_elems.count; nn++) {
                            NoteElem *noteElem=[first_chord_note.note_elems objectAtIndex:nn];
                            if (!note.stem_up && newElem.line>noteElem.line) {
                                [first_chord_note.note_elems insertObject:newElem atIndex:nn];
                                break;
                            }else if (note.stem_up && newElem.line<noteElem.line) {
                                [first_chord_note.note_elems insertObject:newElem atIndex:nn];
                                break;
                            }
                        }
                        if (nn>=first_chord_note.note_elems.count-1) {
                            [first_chord_note.note_elems addObjectsFromArray:note.note_elems];
                            note.line=newElem.line;
                        }
#endif
                        if (note.staff>first_chord_note.staff) {
                            newElem.offsetStaff=1;
                        }else if (note.staff<first_chord_note.staff) {
                            newElem.offsetStaff=-1;
                        }
                        
                    }
                }
                //NSLog(@"Offset:%@ notes:%d duration:%d",key, temp_notes.count, note.duration);
                
                //如果低于16分音符的，显示的时候当作16分音符来显示。
                //if (note.pos.tick!=0 && self.divisions/note.pos.tick>4) {
                //    note.duration_display=self.divisions/4;
               // }
            }else if([name isEqualToString:@"attributes"])
            {
//                [self parseAttributes:note_elem measure:measure staff:(int)start_staff afterNote:(tick==0)?nil:first_chord_note];
                [self parseAttributes:note_elem measure:measure staff:(int)start_staff afterNote:(tick==0)?nil:first_chord_note tick:tick];
                /*
                if (measure.clefs) {
                    for (MeasureClef *clef in measure.clefs) {
                        if (clef.pos.tick == first_chord_note.pos.tick && clef.pos.tick>0) {
                            start_offset+=measure.meas_length_size/(4*last_numerator);
                            break;
                        }
                    }
                }*/
            }else if([name isEqualToString:@"backup"])
            {
                if (temp_directions==nil) {
                    direction_note=nil;
                }
                READ_SUB_INT(temp_backup_duration, @"duration", note_elem);
                //temp_duration_offset-=temp_backup_duration;
                //NSLog(@"offset=%d",temp_duration_offset);
                tick-=temp_backup_duration*480.0/last_divisions;
                if (tick<0) {
                    tick=0;
                    NSLog(@"backup duration too long at measure(%d)",measure.number);
                }
                if (tick==0) {
                    start_offset=0;
                }else{
                    //start_offset-=measure.meas_length_size*temp_backup_duration/(last_divisions*last_numerator);
                    start_offset-=measure.meas_length_size*temp_backup_duration/(last_divisions*last_numerator*4/last_denominator);
                }
            }else if([name isEqualToString:@"forward"])
            {
                READ_SUB_INT(temp_forward_duration, @"duration", note_elem);
                //temp_duration_offset+=temp_backup_duration;
                //NSLog(@"offset=%d",temp_duration_offset);
                tick+=temp_forward_duration*480.0/last_divisions;
                //start_offset+=measure.meas_length_size*temp_forward_duration/(last_divisions*last_numerator);
                start_offset+=measure.meas_length_size*temp_forward_duration/(last_divisions*last_numerator*4/last_denominator);
            }else if ([name isEqualToString:@"direction"]) {
                //directions
                if (temp_directions==nil) {
                    temp_directions=[[NSMutableArray alloc]init];
                }
#if 1
                TBXMLElement *direction_elem=note_elem;
                //staff
                int staff=1;
                READ_SUB_INT(staff, @"staff", direction_elem);
                int dir_offset=0;
                READ_SUB_INT(dir_offset, @"offset", direction_elem);
                //placement
                NSString *placement = [TBXML valueOfAttributeNamed:@"placement" forElement:direction_elem];
                //<sound tempo="60"/>
                TBXMLElement *sound_elem = [TBXML childElementNamed:@"sound" parentElement:direction_elem];
                
                if (sound_elem) {
                    NSString *sound=[TBXML valueOfAttributeNamed:@"tempo" forElement:sound_elem];
                    if (sound) {
                        measure.typeTempo = [sound intValue];
                    }
                }
                
                //BOOL above=[placement isEqualToString:@"above"];
                //direction-type
                TBXMLElement *type_elem = [TBXML childElementNamed:@"direction-type" parentElement:direction_elem];
                
                while (type_elem) {
                    TBXMLElement *child_elem=type_elem->firstChild;
                    OveText *conc_words=nil;
                    
                    while (child_elem!=nil) {
                        NSString *name=[TBXML elementName:child_elem];
                        //self.position=[MusicPosition parsePosition:child_elem];
                        int default_x=[[TBXML valueOfAttributeNamed:@"default-x" forElement:child_elem] intValue];
                        int default_y=[[TBXML valueOfAttributeNamed:@"default-y" forElement:child_elem] intValue];
                        int relative_x=[[TBXML valueOfAttributeNamed:@"relative-x" forElement:child_elem] intValue];
                        //int relative_y=[[TBXML valueOfAttributeNamed:@"relative-y" forElement:child_elem] intValue];
                        
                        if (placement && default_y==0) {
                            if ([placement isEqualToString:@"below"]) {
                                default_y-=7*LINE_height;
                            }else{
                                default_y+=7*LINE_height;
                            }
                        }
                        
                        CommonBlock *pos=[[CommonBlock alloc]init];
                        pos.tick=tick;
                        pos.start_offset=start_offset;
                        
                        if ([name isEqualToString:@"sound"]) {
                            measure.typeTempo = [[TBXML valueOfAttributeNamed:@"tempo" forElement:child_elem] intValue];
                        }else if ([name isEqualToString:@"metronome"]) {
                            NSString *metronome_beat_unit=nil,*metronome_per_minute=nil,*metronome_beat_unit_dot=nil;
                            BOOL dot=NO;
                            READ_SUB_STR(metronome_beat_unit, @"beat-unit", child_elem);
                            READ_SUB_STR(metronome_beat_unit_dot, @"beat-unit-dot", child_elem);
                            if (metronome_beat_unit_dot) {
                                dot=YES;
                            }
                            
                            READ_SUB_STR(metronome_per_minute, @"per-minute", child_elem);
                            
                            if (measure.tempos==nil) {
                                measure.tempos=[[NSMutableArray alloc]init];
                            }
                            Tempo *tempo=[[Tempo alloc]init];
                            [measure.tempos addObject:tempo];
                            // left note type
                            //高2位7-6：always:01
                            //高2位5-4：00: normal, 10:附点
                            //底4位3-0：01:全音符，02：二分音符，03：四分音符， 04:八分音符，05：十六分音符
                            //如：0x43: 四分音符，0x63,0x23: 1.5个四分音符
                            if ([metronome_beat_unit isEqualToString:@"half"]) {
                                tempo.left_note_type=0x02;
                            }else if ([metronome_beat_unit isEqualToString:@"quater"] || [metronome_beat_unit isEqualToString:@"quarter"]) {
                                tempo.left_note_type=0x03;
                            }else if ([metronome_beat_unit isEqualToString:@"eighth"]) {
                                tempo.left_note_type=0x04;
                            }else if ([metronome_beat_unit isEqualToString:@"16th"]) {
                                tempo.left_note_type=0x05;
                            }else {
                                tempo.left_note_type=0x03;
                            }
                            if (dot) {
                                tempo.left_note_type|=0x20;
                            }
                            tempo.tempo=[metronome_per_minute intValue];
                            tempo.tempo_range=0;
                            NSRange range=[metronome_per_minute rangeOfString:@"-"];
                            if (range.length>0) {
                                int next_temp=[[metronome_per_minute substringFromIndex:range.location+1] intValue];
                                if (next_temp>tempo.tempo) {
                                    tempo.tempo_range=next_temp-tempo.tempo;
                                }
                            }
                            tempo.pos = pos;
                            
                            if (measure.meas_texts.count) {
                                OveText *text=measure.meas_texts.lastObject;
                                tempo.tempo_left_text=text.text;
                                tempo.offset_y=text.offset_y;
                                if (text.font_size>0) {
                                    tempo.font_size=text.font_size;
                                }else{
                                    tempo.font_size=28;
                                }
                                [measure.meas_texts removeLastObject];
                            }else{
                                tempo.offset_y=-[[TBXML valueOfAttributeNamed:@"default-y" forElement:child_elem] intValue];
                            }
                        }else if ([name isEqualToString:@"dynamics"]) {
                            NSString *dynamic_text = @"";//[TBXML elementName:child_elem->firstChild];
                            TBXMLElement *dynamic_item_element=child_elem->firstChild;
                            while (dynamic_item_element) {
                                NSString *dynamic_item = [TBXML elementName:dynamic_item_element];
                                dynamic_text=[dynamic_text stringByAppendingString:dynamic_item];
                                dynamic_item_element=dynamic_item_element->nextSibling;
                            }
                            if (measure.dynamics==nil) {
                                measure.dynamics=[[NSMutableArray alloc]init];
                            }
                            OveDynamic *dynamic=[[OveDynamic alloc]init];
                            [measure.dynamics addObject:dynamic];
                            NSDictionary *dynamic_values=@{@"p": @(Dynamics_p),
                                                           @"pp": @(Dynamics_pp),
                                                           @"ppp": @(Dynamics_ppp),
                                                           @"pppp": @(Dynamics_pppp),
                                                           @"f": @(Dynamics_f),
                                                           @"ff": @(Dynamics_ff),
                                                           @"fff": @(Dynamics_fff),
                                                           @"ffff": @(Dynamics_ffff),
                                                           @"fp": @(Dynamics_fp),
                                                           @"mp": @(Dynamics_mp),
                                                           @"mf": @(Dynamics_mf),
                                                           @"sf": @(Dynamics_sf),
                                                           @"sff": @(Dynamics_sff),
                                                           @"fz": @(Dynamics_fz),
                                                           @"sfz": @(Dynamics_sfz),
                                                           @"sffz": @(Dynamics_sffz),
                                                           @"sfp": @(Dynamics_sfp)
                                                           };
                            if (default_y!=0) {
                                dynamic.offset_y=-default_y;
                            }else{
                                dynamic.offset_y=LINE_height*4;
//                                if ([placement isEqualToString:@"below"]) {
//                                }
                            }
                            dynamic.pos = [[CommonBlock alloc]init];
                            dynamic.pos.start_offset=relative_x;//+dir_offset*LINE_height;
                            if (default_x==0) {
                                dynamic.pos.tick=dir_offset*480/last_divisions;// dir_offset*LINE_height;
                            }
                            //dynamic.xml_note=(tick==0)?nil:first_chord_note;
                            if (dynamic.pos.tick==0) {
                                dynamic.pos.tick=tick;
                            }
                            dynamic.xml_note=(int)measure.notes.count;
                            
                            dynamic.staff=staff+start_staff;
                            dynamic.dynamics_type=[[dynamic_values objectForKey:dynamic_text] intValue];
                        }else if ([name isEqualToString:@"bracket"]) { //表示踏板或者左右手
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
                            NSString *type = [TBXML valueOfAttributeNamed:@"type" forElement:child_elem];
                            //NSString *line_type = [TBXML valueOfAttributeNamed:@"line-type" forElement:child_elem];
                            int number = [[TBXML valueOfAttributeNamed:@"number" forElement:child_elem] intValue];
                            NSString *line_end = [TBXML valueOfAttributeNamed:@"line-end" forElement:child_elem];
                            if ([line_end isEqualToString:@"up"]) { //pedal
                                if ([type isEqualToString:@"start"]) {
                                    MeasurePedal *pedal=[[MeasurePedal alloc]init];
                                    if (measure.pedals==nil) {
                                        measure.pedals=[NSMutableArray new];
                                    }
                                    [measure.pedals addObject:pedal];
                                    pedal.xml_slur_number=number;
                                    pedal.xml_start_measure_index=measure.number;
                                    pedal.xml_start_note_index=(int)measure.notes.count;
                                    pedal.staff=staff+start_staff;
                                    pedal.isLine=YES;
                                    pedal.pos=[[CommonBlock alloc]init];
                                    pedal.pos.tick=tick;
                                    pedal.pos.start_offset=start_offset;
                                    pedal.pair_ends=[[PairEnds alloc]init];
                                    pedal.pair_ends.left_line=default_y/LINE_height*2;
                                    pedal.pair_ends.right_line=default_y/LINE_height*2;
                                }else if ([type isEqualToString:@"stop"]) {
                                    for (int mm=measure.number; mm>=0; mm--) {
                                        OveMeasure *temp_measure=self.measures[mm];
                                        for (MeasurePedal *pedal in temp_measure.pedals) {
                                            if (pedal.xml_slur_number==number && pedal.offset==nil) {
                                                pedal.xml_stop_measure_index=measure.number;
                                                if (measure.notes.count>0) {
                                                    pedal.xml_stop_note_index=(int)measure.notes.count-1;
                                                }else{
                                                    pedal.xml_stop_note_index=0;
                                                }
                                                pedal.offset=[[OffsetCommonBlock alloc]init];
                                                pedal.offset.stop_measure=measure.number-mm;
//                                                prev_pedal.offset.stop_offset=start_offset;
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                        }else if ([name isEqualToString:@"pedal"]) {
                            //踩踏板:start | stop | continue(allows more precise formatting across system breaks) | change (indicates a pedal lift and retake indicated with an inverted V marking)
                            //<pedal default-y="-99" line="no" relative-x="-10" type="start"/>
                            //<pedal default-y="-65" line="yes" type="start"/>
                            //<pedal line="yes" type="change"/>
                            //<pedal line="yes" type="stop"/>
                            
                            NSString *pedal_type = [TBXML valueOfAttributeNamed:@"type" forElement:child_elem];
                            BOOL pedal_line = [[TBXML valueOfAttributeNamed:@"line" forElement:child_elem] isEqualToString:@"yes"];
                           
                            if ([pedal_type isEqualToString:@"stop"] || [pedal_type isEqualToString:@"change"]) {
                                for (int mm=measure.number; mm>=0; mm--) {
                                    OveMeasure *temp_measure=self.measures[mm];
                                    for (MeasurePedal *pedal in temp_measure.pedals) {
                                        if (pedal.offset==nil) {
                                            pedal.xml_stop_measure_index=measure.number;
                                            pedal.xml_stop_note_index=(int)measure.notes.count;
                                            pedal.offset=[[OffsetCommonBlock alloc]init];
                                            pedal.offset.stop_measure=measure.number-mm;
                                            //prev_pedal.offset.stop_offset=start_offset;
                                            break;
                                        }
                                    }
                                }
                            }
                            static int pedal_start_line=0;
                            if ([pedal_type isEqualToString:@"start"] || [pedal_type isEqualToString:@"change"]) {
                                if ([pedal_type isEqualToString:@"start"]) {
                                    if(default_y) {
                                        pedal_start_line=default_y/LINE_height*2;
                                    }else{
                                        pedal_start_line=-7;
                                    }
                                }
                                MeasurePedal *pedal=[[MeasurePedal alloc]init];
                                if (measure.pedals==nil) {
                                    measure.pedals=[NSMutableArray new];
                                }
                                [measure.pedals addObject:pedal];
                                pedal.isLine=pedal_line;
                                pedal.xml_start_measure_index=measure.number;
                                pedal.xml_start_note_index=(int)measure.notes.count;
                                pedal.staff=2+start_staff;
                                pedal.pos=[[CommonBlock alloc]init];
                                pedal.pos.tick=tick;
                                pedal.pos.start_offset=start_offset;
                                pedal.pair_ends=[[PairEnds alloc]init];
                                pedal.pair_ends.left_line=pedal_start_line;
                                pedal.pair_ends.right_line=pedal_start_line;
                            }
                            /*
                            if (measure.decorators==nil) {
                                measure.decorators=[[NSMutableArray alloc]init];
                            }
                            MeasureDecorators *deco=[[MeasureDecorators alloc]init];
                            [measure.decorators addObject:deco];
                            deco.decoratorType=Decorator_Articulation;
                            deco.staff=staff+start_staff;
                            deco.xml_start_note=(tick==0)?nil:first_chord_note;
                            //deco.pos=pos;
                            
                            if (placement) {
                                if ([placement isEqualToString:@"below"]) {
                                    deco.offset_y=-4*LINE_height;
                                }else{
                                    deco.offset_y=4*LINE_height;
                                }
                            }else{
                                deco.offset_y=-default_y;
                            }
                            if ([pedal_type isEqualToString:@"start"]) {
                                deco.artType=Articulation_Pedal_Down;
                            }else{
                                deco.artType=Articulation_Pedal_Up;
                            }*/
                        }else if ([name isEqualToString:@"wedge"]) {
                            if (placement) {
                                if ([placement isEqualToString:@"below"]) {
                                    default_y=-1*LINE_height;
                                }else{
                                    default_y=12*LINE_height;
                                }
                            }
                            static OveWedge *opened_wedge[2]={nil,nil};
                            NSString *wedge_type = [TBXML valueOfAttributeNamed:@"type" forElement:child_elem];//楔子:stop, crescendo, diminuendo
                            NSString *numberStr=[TBXML valueOfAttributeNamed:@"number" forElement:child_elem];//1,2...
                            int number=0;
                            if ([numberStr isEqualToString:@"2"]) {
                                number=1;
                            }
                            
                            if (![wedge_type isEqualToString:@"stop"]) { //start
                                if (measure.wedges==nil) {
                                    measure.wedges=[[NSMutableArray alloc]init];
                                }
                                OveWedge *wedge=[[OveWedge alloc]init];
                                opened_wedge[number]=wedge;
                                
                                [measure.wedges addObject:wedge];
                                wedge.wedgeOrExpression=YES;
                                if ([wedge_type isEqualToString:@"crescendo"]) {//crescendo <
                                    wedge.wedgeType=Wedge_Cres_Line;
                                }else{
                                    wedge.wedgeType=Wedge_Decresc_Line; //diminuendo >
                                }
                                //wedge.expression_text=wedge_type;
                                wedge.offset_y=-default_y;
                                
                                wedge.xml_staff=staff+start_staff;
                                //wedge.xml_start_note=(tick==0)?nil:first_chord_note;
                                wedge.xml_start_note=(int)measure.notes.count;//the wedge start with next note
                                wedge.pos=[[CommonBlock alloc]init];
                                if (default_x==0 && dir_offset!=0) {
                                    wedge.pos.tick=dir_offset*LINE_height;
                                    //wedge.pos.tick=dir_offset*480/last_divisions;
                                }else{
                                    wedge.pos.start_offset=0;
                                }
                                //wedge.pos = pos;
                                wedge.offset=[[OffsetCommonBlock alloc]init];
                                wedge.offset.stop_measure=measure.number;
                            }else {
                                opened_wedge[number].offset.stop_measure=measure.number-opened_wedge[number].offset.stop_measure;
                                opened_wedge[number].xml_stop_note=(int)measure.notes.count;//the wedge end with next note
                                opened_wedge[number].xml_staff=staff+start_staff;
                                if (opened_wedge[number].offset.stop_measure==0 && opened_wedge[number].xml_stop_note==opened_wedge[number].xml_start_note) {
                                    if (opened_wedge[number].xml_start_note>0) {
                                        opened_wedge[number].xml_start_note--;
                                    }
                                }
//                                if (default_x==0 && dir_offset!=0) {
//                                    opened_wedge[number].offset.stop_offset=dir_offset*LINE_height;
//                                }

                            }
                        }else if ([name isEqualToString:@"words"]) {
                            if (placement) {
                                if ([placement isEqualToString:@"below"]) {
                                    //default_y+=4*LINE_height;
                                }else{
                                    //default_y+=4*LINE_height;
                                }
                            }
                            NSString *temp_words=nil;
                            temp_words = [TBXML textForElement:child_elem];
                            if ([temp_words isEqualToString:@"piu"]) {
                                temp_words=@"più";
                            }
                            int font_size = [[TBXML valueOfAttributeNamed:@"font-size" forElement:child_elem] intValue];
                            NSString *font_weight = [TBXML valueOfAttributeNamed:@"font-weight" forElement:child_elem]; //font-weight="bold"
                            NSString *font_style = [TBXML valueOfAttributeNamed:@"font-style" forElement:child_elem];
                            NSString *relative_x = [TBXML valueOfAttributeNamed:@"relative-x" forElement:child_elem];
                            
                            NSString *DC_words=[temp_words stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            NSNumber *repeatType=DCRepeat[DC_words];
                            if (repeatType) {
                                measure.repeat_type=repeatType.intValue;
                            }else if (temp_words) {
                                
                                if (conc_words==nil) {
                                    if (measure.meas_texts==nil) {
                                        measure.meas_texts=[[NSMutableArray alloc]init];
                                    }
                                    conc_words=[[OveText alloc] init];
                                    [measure.meas_texts addObject:conc_words];
                                }
//                                OveText *text=[[OveText alloc]init];
                                //text.text = [NSString stringWithFormat:@"%@ %@",text.text?text.text:@"",temp_words];
                                //[measure.meas_texts addObject:text];
                                OveText *text=conc_words;
                                if (text.text) {
                                    text.text = [NSString stringWithFormat:@"%@ %@",text.text,temp_words];
                                }else{
                                    text.text=temp_words;
                                    text.offset_y=-default_y;
                                    text.offset_x=[relative_x intValue];//+dir_offset*LINE_height;
                                    //                                text.offset_x=default_x+[relative_x intValue];
                                    text.staff=staff+start_staff;
                                    text.xml_start_note=(int)measure.notes.count;
//                                    if (measure.notes.count>0) {
//                                        text.xml_start_note=(int)measure.notes.count-1;
//                                    }else{
//                                        text.xml_start_note=0;
//                                    }
                                    if (relative_x==0 && measure.dynamics.count>0) {
                                        for (OveDynamic *dyn in measure.dynamics) {
                                            if (dyn.staff==text.staff && dyn.pos.start_offset==text.offset_x && dyn.xml_note==text.xml_start_note) {
                                                dyn.pos.start_offset-=LINE_height;
                                                text.offset_x+=2*LINE_height;
                                                break;
                                            }
                                        }
                                    }
                                    text.pos=[[CommonBlock alloc]init];
                                    if (default_x==0 && dir_offset!=0) {
                                        //text.pos.tick=dir_offset*LINE_height;
                                        text.pos.tick=dir_offset*480/last_divisions;
                                    }else{
                                        text.pos.tick=0;
                                    }
                                    
                                    if ([font_weight isEqualToString:@"bold"]) {
                                        text.isBold=YES;
                                    }
                                    if ([font_style isEqualToString:@"italic"]) {
                                        text.isItalic=YES;
                                    }
                                    if (font_size>0) {
                                        text.font_size=font_size*2;
                                    }
                                }

                            }
                        }else if ([name isEqualToString:@"image"]) {
                            if (measure.images==nil) {
                                measure.images=[[NSMutableArray alloc]init];
                            }
                            OveImage *image=[[OveImage alloc]init];
                            [measure.images addObject:image];
                            image.source = [TBXML valueOfAttributeNamed:@"source" forElement:child_elem];
                            image.offset_y=-default_y;
                            image.offset_x=default_x;
                            image.width=[[TBXML valueOfAttributeNamed:@"halign" forElement:child_elem] intValue];
                            image.height=[[TBXML valueOfAttributeNamed:@"valign" forElement:child_elem] intValue];
                            image.type=0;
                            image.staff=staff+start_staff;
                            image.pos = pos;
                        }else if ([name isEqualToString:@"octave-shift"]) {
                            //static int octave_start_offset_y=0;
                            //NSString *number=[TBXML valueOfAttributeNamed:@"number" forElement:child_elem];
                            NSString *type=[TBXML valueOfAttributeNamed:@"type" forElement:child_elem]; //up | down | stop | continue
                            int size=[[TBXML valueOfAttributeNamed:@"size" forElement:child_elem] intValue]; //8: one octave, 15: two cotaves
                            if (size==0) {
                                size=8;
                            }
                            if (measure.octaves==nil) {
                                measure.octaves=[[NSMutableArray alloc]init];
                            }
                            OctaveShift *shift=[[OctaveShift alloc]init];
                            [measure.octaves addObject:shift];
                            //shift.xml_note=(tick==0)?nil:first_chord_note;
                            shift.staff=staff+start_staff;
                            int shift_index=shift.staff-1;
                            
                            if ([type isEqualToString:@"down"]) {//down 比真正的降低8度
                                shift.xml_note=(int)measure.notes.count;
                                shift.offset_y=-default_y;
                                octave_shift_data[shift_index].octave_start_offset_y=-default_y;
                                
                                //octave_shift_staff=shift.staff;
                                if (size!=8) {
                                    shift.octaveShiftType=OctaveShift_15_Start;
                                    octave_shift_data[shift_index].shift_size=15;
                                }else{
                                    shift.octaveShiftType=OctaveShift_8_Start;
                                    octave_shift_data[shift_index].shift_size=7;
                                }
                                octave_shift_data[shift_index].start_tick=tick;
                                octave_shift_data[shift_index].stop_tick=-1;
                                octave_shift_data[shift_index].start_measure=measure.number;
                                //如果前面是倚音，需要把倚音提高8度
                                if (measure.xml_new_line && measure.notes.count>0) {
                                    for (int prev=(int)measure.notes.count-1; prev>=0; prev--) {
                                        OveNote *prevNote=measure.notes[prev];
                                        if (prevNote.staff==shift.staff && prevNote.isGrace) {
                                            for (NoteElem *prevElem in prevNote.note_elems) {
                                                //if (prevElem.note<12)
                                                {
                                                    if (shift.octaveShiftType==OctaveShift_15_Start) {
                                                        prevElem.note+=12*2;
                                                    }else{
                                                        prevElem.note+=12;
                                                    }
                                                }
                                            }
                                        }else{
                                            break;
                                        }
                                    }
                                }
                            }else if ([type isEqualToString:@"up"]) {//up 比真正的升高8度
                                shift.xml_note=(int)measure.notes.count;
                                shift.offset_y=-default_y;
                                octave_shift_data[shift_index].octave_start_offset_y=-default_y;
                                
                                //octave_shift_staff=shift.staff;
                                
                                if (size!=8) {
                                    shift.octaveShiftType=OctaveShift_Minus_15_Start;
                                    octave_shift_data[shift_index].shift_size=-15;
                                }else{
                                    shift.octaveShiftType=OctaveShift_Minus_8_Start;
                                    octave_shift_data[shift_index].shift_size=-7;
                                }
                                octave_shift_data[shift_index].start_tick=tick+1;
                                octave_shift_data[shift_index].stop_tick=-1;
                                octave_shift_data[shift_index].start_measure=measure.number;
                            }else if([type isEqualToString:@"stop"])
                            {
                                shift.offset_y=octave_shift_data[shift_index].octave_start_offset_y;
                                if (size!=8) {
                                    shift.octaveShiftType=(octave_shift_data[shift_index].shift_size>0)?OctaveShift_15_Stop:OctaveShift_Minus_15_Stop;
                                }else{
                                    shift.octaveShiftType=(octave_shift_data[shift_index].shift_size>0)?OctaveShift_8_Stop:OctaveShift_Minus_8_Stop;
                                }
                                //octave_shift_size=0;
//                                if (tick>0) {
//                                    shift.xml_note=(int)measure.notes.count;
//                                    octave_shift_data[shift_index].stop_tick=tick-1;
//                                }else{
                                    shift.xml_note=(measure.notes.count>0)?(int)measure.notes.count-1:0;
                                    octave_shift_data[shift_index].stop_tick=tick;
//                                }
                                octave_shift_data[shift_index].stop_measure=measure.number;
                            }else if([type isEqualToString:@"continue"])
                            {
                                shift.xml_note=(measure.notes.count>0)?(int)measure.notes.count-1:0;
                                shift.offset_y=octave_shift_data[shift_index].octave_start_offset_y;
                                if (size!=8) {
                                    shift.octaveShiftType=OctaveShift_15_Continue;
                                }else{
                                    shift.octaveShiftType=OctaveShift_8_Continue;
                                }
                            }
                        }else if ([name isEqualToString:@"segno"]) {
                            measure.repeat_type=Repeat_Segno;
                            measure.repeat_offset=[[OffsetElement alloc] init];
                            measure.repeat_offset.offset_x=0;
                            measure.repeat_offset.offset_y=-default_y;
                        }else if ([name isEqualToString:@"coda"]) {
                            measure.repeat_type=Repeat_Coda;
                            measure.repeat_offset=[[OffsetElement alloc] init];
                            measure.repeat_offset.offset_x=0;
                            measure.repeat_offset.offset_y=-default_y;
                        }else {
                            NSLog(@"Error unknow direct type=%@", name);
                        }
                        child_elem=child_elem->nextSibling;
                    }
                    type_elem=[TBXML nextSiblingNamed:@"direction-type" searchFromElement:type_elem];
                }
                
#endif
                
                //MusicDirection *direction=[[MusicDirection alloc]init];
                //[direction parse:note_elem];
                //[temp_directions addObject:direction];
            }else if ([name isEqualToString:@"barline"])
            {
                NSString *barline_location = [TBXML valueOfAttributeNamed:@"location" forElement:note_elem]; //left, right
                
                NSString *barline_bar_style=nil;
                READ_SUB_STR(barline_bar_style, @"bar-style", note_elem);
                
                TBXMLElement *repeat_elem = [TBXML childElementNamed:@"repeat" parentElement:note_elem];
                if (repeat_elem) {
                    NSString *barline_repeat_direction=nil;
                    barline_repeat_direction = [TBXML valueOfAttributeNamed:@"direction" forElement:repeat_elem]; //forward, backward
                    NSString *play=[TBXML valueOfAttributeNamed:@"play" forElement:repeat_elem]; //yes or no, default is yes
                    if (play && [play isEqualToString:@"no"]) {
                        measure.repeat_play=NO;
                    }else{
                        measure.repeat_play=YES;
                    }
                    if ([barline_location isEqualToString:@"left"]) {
                        if (barline_repeat_direction && [barline_repeat_direction isEqualToString:@"forward"]) {
                            measure.left_barline=Barline_RepeatLeft;
                        }else{
                            NSLog(@"error, unknow barline_repeat_direction=%@", barline_repeat_direction);
                        }
                    }else{
                        if (barline_repeat_direction && [barline_repeat_direction isEqualToString:@"backward"]) {
                            measure.right_barline=Barline_RepeatRight;
                            measure.repeat_count=1;
                        }else{
                            measure.right_barline=Barline_Final;
                        }
                    }
                }else{
                    if ([barline_bar_style isEqualToString:@"light-heavy"]){
                        measure.right_barline = Barline_Final;
                    }else if ([barline_bar_style isEqualToString:@"light-light"]){
                        measure.right_barline = Barline_Double;
                    }else if ([barline_bar_style isEqualToString:@"none"]){
                        if (measure.notes.count>0) {
                            measure.right_barline = Barline_Default;
                        }else{
                            measure.right_barline = Barline_Null;
                        }
                    }
                }
                //<ending default-y="48" end-length="30" font-size="8.5" number="1" print-object="yes" type="start"/>
                TBXMLElement *ending_elem = [TBXML childElementNamed:@"ending" parentElement:note_elem];
                if (ending_elem) {
                    NSString *barline_ending_number=nil,*barline_ending_type=nil;
                    barline_ending_number = [TBXML valueOfAttributeNamed:@"number" forElement:ending_elem]; //1,2,
                    barline_ending_type = [TBXML valueOfAttributeNamed:@"type" forElement:ending_elem]; //start, stop
                    NSString *default_y=[TBXML valueOfAttributeNamed:@"default-y" forElement:ending_elem];
                    
                    if (measure.numerics==nil) {
                        measure.numerics=[[NSMutableArray alloc]init];
                    }
                    static NSMutableArray *opened_ending=nil;
                    if (opened_ending==nil) {
                        opened_ending=[[NSMutableArray alloc]init];
                    }
                    if ([barline_ending_type isEqualToString:@"start"]) {
                        NumericEnding *ending=[[NumericEnding alloc]init];
                        [measure.numerics addObject:ending];
                        ending.numeric_text=barline_ending_number;
                        ending.numeric_measure_count=1;
                        ending.pos=[[CommonBlock alloc]init];
                        ending.pos.tick=tick;
                        ending.pos.start_offset=measure.number;//start_offset;
                        ending.offset_y=[default_y intValue];
                        [opened_ending addObject:ending];
                    }else{
                        BOOL find_stoped=NO;
                        for (NumericEnding *ending in opened_ending) {
                            if ([ending.numeric_text isEqualToString:barline_ending_number]) {
                                ending.numeric_measure_count=measure.number-ending.pos.start_offset+1;
                                [opened_ending removeObject:ending];
                                find_stoped=YES;
                                break;
                            }
                        }
                        if (!find_stoped) {
                            NSLog(@"Barline ending Error");
                        }
                    }
                }
            }
            
            note_elem = note_elem->nextSibling;
            if (note_elem==nil) {
                break;
            }
        } while (YES);
        //if (temp_directions) {
        //    direction_note.directions=temp_directions;
       // }
        
    }else
    {
        NSLog(@"error unknow element:%@", name);
        return nil;
    }
    
    measure.fifths=last_key_fifths;
    measure.numerator=last_numerator;
    measure.denominator=last_denominator;
    measure.xml_staves +=part_staves;
    measure.typeTempo = metronome_per_minute;

    return measure;
}

static int system_index=0;
static int default_top_system_distance, default_staff_distance=0,default_system_distance=0;
static int min_staff_distance=0, min_system_distance=0,max_staff_distance=0, max_system_distance=0;
static float LINE_height=10;

- (BOOL) parseMusicXML:(NSData*)pageData
{
	TBXMLElement *element;
    NSError *error;

    system_index=0;
    LINE_height=10;
    //LINE_height=1024.0/120;
    
    default_top_system_distance=0;
    if ([[UIDevice currentDevice] userInterfaceIdiom]==UIUserInterfaceIdiomPad) {
        min_staff_distance=LINE_height*9;
        min_system_distance=LINE_height*11;
        max_staff_distance=LINE_height*16;
        max_system_distance=LINE_height*18;
    }else{
        min_staff_distance=LINE_height*8;
        min_system_distance=LINE_height*9;
        max_staff_distance=LINE_height*8;
        max_system_distance=LINE_height*9;
    }
    default_staff_distance=0, default_system_distance=0;
    last_key_fifths=0, last_numerator=4, last_denominator=4;
    last_divisions=0;
    part_staves=1;
    for (int i=0; i<MAX_CLEFS; i++) {
        last_clefs[i]=-1;
        measure_start_clefs[i]=-1;
        last_clefs_tick[i]=-1;
    }
    //octave_shift_size=0;
    //octave_shift_staff=0;
    memset(octave_shift_data, 0, sizeof(octave_shift_data));
//    octave_shift_start_tick=0, octave_shift_start_measure=0;
//    octave_shift_stop_tick=0,octave_shift_stop_measure=0;

    
	TBXML * tbxml = [[TBXML alloc] initWithXMLData:pageData error:&error];//[TBXML newTBXMLWithXMLData:pageData error:&error];
	element = [tbxml rootXMLElement];
	if (element==NULL)
	{
		NSLog(@"Fail to parse xml file. error=%@", error);
		return NO;
	}
	NSString *name = [TBXML elementName:element];
    if (![name isEqualToString:@"score-partwise"]) {
        NSLog(@"this is not a MusicXML %@",name);
        return NO;
    }
    NSMutableArray *parts=[[NSMutableArray alloc]init]; //array of dict[pard_id, part_name, staves, from_staff]
    int max_measures=0;
    int staff=0;
    
    element = element->firstChild;
    do {
        name = [TBXML elementName:element];
        if ([name isEqualToString:@"work"]) {
            READ_SUB_STR(self.work_title, @"work-title",element);
            READ_SUB_STR(self.work_number, @"work-number",element);
        }else if ([name isEqualToString:@"movement-title"]) {
            self.work_title = [TBXML textForElement:element];
        }else if ([name isEqualToString:@"movement-number"]) {
            NSString *movement_number = [TBXML textForElement:element];
            self.work_number=movement_number;
        }else if ([name isEqualToString:@"identification"]) {
            TBXMLElement *temp_elem= element->firstChild;
            while (YES) {
                NSString *temp_name=[TBXML elementName:temp_elem];
                if ([temp_name isEqualToString:@"rights"]) {
                    self.rights=[TBXML textForElement:temp_elem];
                }else if ([temp_name isEqualToString:@"creator"]) {
                    NSString *creator_type;
                    creator_type=[TBXML valueOfAttributeNamed:@"type" forElement:temp_elem];
                    if ([creator_type isEqualToString:@"composer"]) {
                        self.composer = [TBXML textForElement:temp_elem];
                    }else if ([creator_type isEqualToString:@"lyricist"]) {
                        self.lyricist = [TBXML textForElement:temp_elem];
                    }else{
                        NSLog(@"Error: unknow creator type(%@)",creator_type);
                    }
                }
                temp_elem = temp_elem->nextSibling;
                if (temp_elem==nil) {
                    break;
                }
            }
        }else if ([name isEqualToString:@"defaults"]) {
            /*
             <page-layout>
             <page-height>1760</page-height>
             <page-width>1360</page-width>
             <page-margins type="both">
             <left-margin>80</left-margin>
             <right-margin>80</right-margin>
             <top-margin>80</top-margin>
             <bottom-margin>80</bottom-margin>
             </page-margins>
             </page-layout>
             */
            TBXMLElement *temp_elem=[TBXML childElementNamed:@"page-layout" parentElement:element];
            int page_width, page_height;
            READ_SUB_INT(page_height, @"page-height", temp_elem);
            READ_SUB_INT(page_width, @"page-width", temp_elem);
            self.page_height=page_height;
            self.page_width=page_width;
            default_top_system_distance=page_height*0.02;
            default_staff_distance=page_height*0.03;
            default_system_distance=page_height*0.04;
            
            
            TBXMLElement *margin_elem=[TBXML childElementNamed:@"page-margins" parentElement:temp_elem];
            READ_SUB_INT(self.page_left_margin, @"left-margin", margin_elem);
            READ_SUB_INT(self.page_right_margin, @"right-margin", margin_elem);
            READ_SUB_INT(self.page_top_margin, @"top-margin", margin_elem);
            READ_SUB_INT(self.page_bottom_margin, @"bottom-margin", margin_elem);
            
            
            /*
             <system-layout>
             <system-margins>
             <left-margin>71</left-margin>
             <right-margin>0</right-margin>
             </system-margins>
             <system-distance>108</system-distance>
             <top-system-distance>65</top-system-distance>
             </system-layout>
             */
            temp_elem=[TBXML childElementNamed:@"system-layout" parentElement:element];
            if (temp_elem) {
                //int distance=0;
                READ_SUB_INT(default_system_distance, @"system-distance", temp_elem);
                //system_distance[0]=distance;
                READ_SUB_INT(default_top_system_distance, @"top-system-distance", temp_elem);
                
                if (default_system_distance<min_system_distance) {
                    default_system_distance=min_system_distance;
                }else if(default_system_distance>max_system_distance) {
                    default_system_distance=max_system_distance;
                }
            }
            /*
             <staff-layout>
             <staff-distance>101</staff-distance>
             </staff-layout>
             */
            temp_elem=[TBXML childElementNamed:@"staff-layout" parentElement:element];
            if (temp_elem) {
                READ_SUB_INT(default_staff_distance, @"staff-distance", temp_elem);
                if (default_staff_distance<min_staff_distance) {
                    default_staff_distance=min_staff_distance;
                }else if(default_staff_distance>max_staff_distance) {
                    default_staff_distance=max_staff_distance;
                }
            }
            //page_width/page_height = 1024/height
//            float screen_width=1024;
//            float screen_height=screen_width*self.page_width/self.page_height;
//            LINE_height=(self.page_height)/screen_height * 10;
            //LINE_height=1024.0/100;
            //LINE_height=self.page_width/120.0;
            //LINE_height=10;
            
//            LINE_height=(self.page_height-self.page_top_margin-self.page_bottom_margin/*-top_system_distance*/)/(1024.0*1024.0/768.0) * 10;
            
            
            /*
             <appearance>
             <line-width type="stem">0.957</line-width>
             <line-width type="beam">5.0391</line-width>
             <line-width type="staff">0.957</line-width>
             <line-width type="light barline">1.875</line-width>
             <line-width type="heavy barline">5.0391</line-width>
             <line-width type="leger">1.875</line-width>
             <line-width type="ending">0.957</line-width>
             <line-width type="wedge">0.957</line-width>
             <line-width type="enclosure">0.957</line-width>
             <line-width type="tuplet bracket">0.957</line-width>
             <note-size type="grace">60</note-size>
             <note-size type="cue">60</note-size>
             </appearance>
             */
        }else if ([name isEqualToString:@"credit"]){
            /*
             <credit page="1">
             <credit-type>title</credit-type>
             <credit-words default-x="64" default-y="1440" font-family="????_GBK" font-size="24.2" halign="left" justify="center" valign="top" xml:lang="zh" xml:space="preserve">小  步  舞  曲
             </credit-words>
             </credit>
             */
            TBXMLElement *credit_type_element=[TBXML childElementNamed:@"credit-type" parentElement:element];
            if (credit_type_element) {
                if ([[TBXML textForElement:credit_type_element] isEqualToString:@"title"]) {
                    TBXMLElement *credit_words_element=[TBXML childElementNamed:@"credit-words" parentElement:element];
                    if (credit_words_element) {
                        NSString *words=[TBXML textForElement:credit_words_element];
                        if (self.work_title.length==0 && words.length>1) {
                            self.work_title = words;
                        }
                    }
                }else if ([[TBXML textForElement:credit_type_element] isEqualToString:@"subtitle"]) {
                    TBXMLElement *credit_words_element=[TBXML childElementNamed:@"credit-words" parentElement:element];
                    if (credit_words_element) {
                        NSString *words=[TBXML textForElement:credit_words_element];
                        if (words.length>1) {
                            self.work_number = words;
                        }
                    }
                }
            }
        }else if ([name isEqualToString:@"part-list"]) {
            TBXMLElement *temp_elem= element->firstChild;
            NSMutableArray *part_id_list=[[NSMutableArray alloc]init];
            do {
                NSString *part_name=[TBXML elementName:temp_elem];
                if ([part_name isEqualToString:@"score-part"]) {
                    
                    NSString *part_id, *part_name,*instrument_name;
                    part_id = [TBXML valueOfAttributeNamed:@"id" forElement:temp_elem];
                    [part_id_list addObject:part_id];
                    part_name = [TBXML textForElement: [TBXML childElementNamed:@"part-name" parentElement:temp_elem] ];
                    
                    NSMutableDictionary *dict=[[NSMutableDictionary alloc]init];
                    [parts addObject:dict];
                    [dict setObject:part_name forKey:@"part_name"];
                    [dict setObject:part_id forKey:@"part_id"];
                    
                    TBXMLElement *score_instrument_elem = [TBXML childElementNamed:@"score-instrument" parentElement:temp_elem];
                    READ_SUB_STR(instrument_name, @"instrument-name", score_instrument_elem);
                    if (instrument_name) {
                        [dict setObject:instrument_name forKey:@"instrument_name"];
                    }
                    
                }else if ([part_name isEqualToString:@"part-group"])
                {
                    NSLog(@"warning no use for element:%@", part_name);
                }else
                {
                    NSLog(@"error unknow element:%@", part_name);
                }
                
                temp_elem = temp_elem->nextSibling;
                if (temp_elem==nil) {
                    break;
                }
            } while (YES);
        }else if ([name isEqualToString:@"part"]) {
            //create temp_part and ID
            NSString *part_id=[TBXML valueOfAttributeNamed:@"id" forElement:element];
            NSMutableDictionary *temp_part=nil;
            for (NSMutableDictionary* dict in parts) {
                NSString* temp_id=[dict objectForKey:@"part_id"];
                if ([part_id isEqualToString:temp_id]) {
                    temp_part=dict;
                    break;
                }
            }
            if (temp_part==nil) {
                temp_part=[[NSMutableDictionary alloc]init];
                [temp_part setObject:part_id forKey:@"part_id"];
                [parts addObject:temp_part];
            }
            [temp_part setObject:@(staff+1) forKey:@"from_staff"];
            /*
            OveTrack *temp_track=nil;
            for (OveTrack *track in self.trackes) {
                if ([part_id isEqualToString:track.xml_track_id]) {
                    temp_track=track;
                    break;
                }
            }
            if (temp_track==nil) {
                temp_track=[[OveTrack alloc]init];
                temp_track.xml_track_id=part_id;
            }
            temp_track.xml_from_staff=staff+1;
             */
            
            /*
            MusicPart *temp_part = [self.parts objectForKey:part_id];
            if (temp_part==nil) {
                temp_part = [[MusicPart alloc]init];
                [self.parts setObject:temp_part forKey:part_id];
            }
            temp_part.measures = [[NSMutableArray alloc]init];
             */
            part_staves=1;
             
            NSLog(@"part id=%@", part_id);
            if (self.measures==nil) {
                self.measures=[[NSMutableArray alloc]init];
            }
            OveLine *line=nil;
            if (self.lines==nil) {
                self.lines=[[NSMutableArray alloc]init];
            }
            OvePage *page=nil;
            if (self.pages==nil) {
                self.pages=[[NSMutableArray alloc]init];
            }
            int page_index=0, line_index=0;
            float staff_height=LINE_height * 4;

            //read measures
            int measure_index=0;
            TBXMLElement *measure_elem= element->firstChild;
            do {
                OveMeasure *temp_measure;
                if (measure_index>=max_measures) {
                    temp_measure = [[OveMeasure alloc]init];
                    [self.measures addObject:temp_measure];
                    temp_measure.number=measure_index;
                    temp_measure.xml_division=last_divisions;
                    memcpy(measure_start_clefs, last_clefs, sizeof(measure_start_clefs));
                }else{
                    temp_measure=[self.measures objectAtIndex:measure_index];
                    //[cur_measure.notes addObjectsFromArray:temp_measure.notes];
                    //[cur_measure.dynamics addObjectsFromArray:temp_measure.dynamics];
                    //cur_measure.staves+=temp_measure.staves;
                }
                [self parseMeasure:measure_elem staff:staff measure:temp_measure];
                //remove empty measure
//                if (temp_measure.notes.count==0) {
//                    [self.measures removeLastObject];
//                    max_measures=(int)self.measures.count;
//                    if (i<self.measures.count-1) {
//                        OveMeasure *nextMeasure=self.temp_measure[i+1];
//                        if (temp_measure.clefs) {
//                            if (nextMeasure.clefs==nil) {
//                                nextMeasure.clefs=[NSMutableArray new];
//                            }
//                            [nextMeasure.clefs addObjectsFromArray:temp_measure.clefs];
//                        }
//                        if (temp_measure.fifths!=0 && nextMeasure.fifths==0) {
//                            nextMeasure.fifths=temp_measure.fifths;
//                        }
//                    }
//                }
                if (measure_index>=max_measures) { //the first part(group)
                    if (measure_index==0 || temp_measure.xml_new_line || temp_measure.xml_new_page) {
                        //new page
                        if (measure_index==0 || temp_measure.xml_new_page) {
                            if (page) {//previous page
                                page.line_count=line_index-page.begin_line;
                            }
                            //new page
                            page = [[OvePage alloc]init];
                            page.begin_line=line_index;
                            page.system_distance = temp_measure.xml_system_distance;
                            page.staff_distance=temp_measure.xml_staff_distance;
                            page.xml_top_system_distance=temp_measure.xml_top_system_distance;
                            [self.pages addObject:page];
                            page_index++;
                        }

                        if (line) { //prevouse line
                            line.bar_count=measure_index-line.begin_bar;
                            line.xml_staff_distance=temp_measure.xml_staff_distance;
                        }
                        
                        //new line
                        line=[[OveLine alloc]init];
                        [self.lines addObject:line];
                        line.begin_bar=measure_index;
                        line.fifths=temp_measure.fifths;
                        line.xml_staff_distance=temp_measure.xml_staff_distance;
                        line.xml_system_distance=temp_measure.xml_system_distance;
                        //staves
                        line.staves=[[NSMutableArray alloc]init];
                        for (int ss=0; ss<part_staves; ss++) {
                            LineStaff *lineStaff=[[LineStaff alloc]init];
                            lineStaff.y_offset=(ss==0)?0:line.xml_staff_distance+staff_height;
                            [line.staves addObject:lineStaff];
                            lineStaff.hide=NO;
                            if (ss==0) {
                                lineStaff.group_staff_count=part_staves-1;
                            }else{
                                lineStaff.group_staff_count=0;
                            }
                            //staves
                            //MeasureClef *clef=[temp_measure.clefs objectAtIndex:ss];
                            lineStaff.clef=measure_start_clefs[ss];

                            if (temp_measure.clefs.count>0) {
                                for (MeasureClef *clef in temp_measure.clefs) {
                                    OveNote *xml_note;
                                    if (clef.xml_note<temp_measure.notes.count) {
                                        xml_note=temp_measure.notes[clef.xml_note];
                                    }else{
                                        xml_note=temp_measure.notes.lastObject;
                                    }
                                    if (clef.staff==ss+1 && xml_note.pos.tick==0) {
                                        lineStaff.clef=clef.clef;
                                        //dont remove this clef
                                        //[temp_measure.clefs removeObject:clef];
                                        break;
                                    }
                                }
                            }
                        }
                        line_index++;
                    }
                }else{//from the second part/group
                    if (measure_index==0 || temp_measure.xml_new_line || temp_measure.xml_new_page) {
                        if (measure_index==0 || temp_measure.xml_new_page) {
                            page = [self.pages objectAtIndex:page_index];
                            page_index++;
                        }
                        line=[self.lines objectAtIndex:line_index];
                        if (temp_measure.xml_staff_distance>0) {
                            line.xml_staff_distance=temp_measure.xml_staff_distance;
                        }
                        if (temp_measure.xml_system_distance>0) {
                            line.xml_system_distance=temp_measure.xml_system_distance;
                        }

                        for (int ss=0; ss<part_staves; ss++) {
                            LineStaff *lineStaff=[[LineStaff alloc]init];
                            lineStaff.y_offset=line.xml_staff_distance+staff_height;
                            [line.staves addObject:lineStaff];
                            lineStaff.hide=NO;
                            if (ss==0) {
                                lineStaff.group_staff_count=part_staves-1;
                            }else{
                                lineStaff.group_staff_count=0;
                            }
                            //staves
                            lineStaff.clef=last_clefs[ss+staff];
                            if (temp_measure.clefs.count>0) {
                                for (MeasureClef *clef in temp_measure.clefs) {
                                    if (clef.staff==staff+ss+1 && clef.pos.tick==0) {
                                        lineStaff.clef=clef.clef;
                                        [temp_measure.clefs removeObject:clef];
                                        break;
                                    }
                                }
                            }
                        }
                        line_index++;
                    }
                }
                
                measure_elem = measure_elem->nextSibling;
                measure_index++;
                if (measure_elem==nil) {
                    break;
                }
            } while (YES);
            staff+=part_staves;
            [self processSlursPrev];
            //temp_track.xml_staves=part_staves;
            [temp_part setObject:@(part_staves) forKey:@"staves"];

            if (max_measures<self.measures.count) {
                max_measures=(int)self.measures.count;
                
                line.bar_count=max_measures-line.begin_bar;
                page.line_count=line_index-page.begin_line;
            }
            //add lines info
        }
        
        element=element->nextSibling;
        if (element==nil) {
            break;
        }
    } while (YES);
    
    //tracks
    self.trackes=[[NSMutableArray alloc]init];
    for (int pp=0; pp<parts.count; pp++) {
        NSDictionary *part=[parts objectAtIndex:pp];
        NSString *part_name=[part objectForKey:@"part_name"];
        NSString *instrument_name=part[@"instrument_name"];
        if ([part_name isEqualToString:@"MusicXML Part"]) {
            part_name=@"Piano";
        }
        
        int staves = [[part objectForKey:@"staves"] intValue];
        
        for (int tt=0; tt<staves; tt++) {
            OveTrack *track=[[OveTrack alloc]init];
            [self.trackes addObject:track];
            if (tt==0) {
                track.track_name=part_name; //todo: some xml has wrong part-name
            }else{
                track.track_name=nil;
            }
            track.transpose_value=0;
            track.voice_count=8;
            track_voice *voice=[track getVoice];
            for (int i=0; i<8 && i<track.voice_count; i++) {
                
                voice->voices[i].channel=0;
                voice->voices[i].volume=-1;
                voice->voices[i].pan=0;
                voice->voices[i].pitch_shift=0;
                int patch=-1;
                if (i==0) {
                    patch=[NewPlayMidi patchForInstrumentName:instrument_name];
                    if (patch<0) {
                        patch=[NewPlayMidi patchForInstrumentName:part_name];
                    }
                }
                voice->voices[i].patch=patch;
            }
        }
    }
    //remove empty measures
    /*
    NSMutableArray *measures=[NSMutableArray new];
    for (int i=0; i<self.measures.count; i++) {
        OveMeasure *measure=self.measures[i];
        if (measure.notes.count>0) {
            [measures addObject:measure];
        }else{
            if (i<self.measures.count-1) {
                OveMeasure *nextMeasure=self.measures[i+1];
                if (measure.clefs) {
                    if (nextMeasure.clefs==nil) {
                        nextMeasure.clefs=[NSMutableArray new];
                    }
                    [nextMeasure.clefs addObjectsFromArray:measure.clefs];
                }
                if (measure.fifths!=0 && nextMeasure.fifths==0) {
                    nextMeasure.fifths=measure.fifths;
                }
            }
        }
    }
    self.measures=measures;
    max_measures=(int)measures.count;
    */
    self.max_measures=max_measures;
    
    //check if need to rearrange lines/pages
#define MEASURES_EACH_LINE 4
#define LINES_EACH_PAGE 4

#ifndef ONLY_ONE_PAGE
    if (self.pages.count==1){
        if (self.lines.count==1) {
            //lines
            [self.lines removeAllObjects];
            int line_count=(max_measures+MEASURES_EACH_LINE-1)/MEASURES_EACH_LINE;
            for (int i=0; i<line_count; i++) {
                OveMeasure *temp_measure=self.measures[i*MEASURES_EACH_LINE];
                
                OveLine *line=[[OveLine alloc] init];
                [self.lines addObject:line];
                line.begin_bar=i*MEASURES_EACH_LINE;
                if (i<line_count-1) {
                    line.bar_count=MEASURES_EACH_LINE;
                }else{
                    line.bar_count=max_measures%MEASURES_EACH_LINE;
                    if (line.bar_count==0) {
                        line.bar_count=MEASURES_EACH_LINE;
                    }
                }
                
                line.fifths=temp_measure.fifths;
                if (temp_measure.xml_staff_distance>0) {
                    line.xml_staff_distance=temp_measure.xml_staff_distance;
                }else{
                    line.xml_staff_distance=LINE_height*5;
                }
                if (temp_measure.xml_system_distance>0) {
                    line.xml_system_distance=temp_measure.xml_system_distance;
                }else{
                    line.xml_system_distance=LINE_height*10*part_staves;
                }
                //staves
                line.staves=[[NSMutableArray alloc]init];
                for (int ss=0; ss<part_staves; ss++) {
                    LineStaff *lineStaff=[[LineStaff alloc]init];
                    lineStaff.y_offset=(ss==0)?0:line.xml_staff_distance+LINE_height * 4;;
                    [line.staves addObject:lineStaff];
                    lineStaff.hide=NO;
                    if (ss==0) {
                        lineStaff.group_staff_count=part_staves-1;
                    }else{
                        lineStaff.group_staff_count=0;
                    }
                    //staves
                    //MeasureClef *clef=[temp_measure.clefs objectAtIndex:ss];
                    lineStaff.clef=measure_start_clefs[ss];
                    
                    if (temp_measure.clefs.count>0) {
                        for (MeasureClef *clef in temp_measure.clefs) {
                            if (clef.staff==ss+1 && clef.pos.tick==0) {
                                lineStaff.clef=clef.clef;
                                [temp_measure.clefs removeObject:clef];
                                break;
                            }
                        }
                    }
                }
            }
        }

        //pages
        [self.pages removeAllObjects];
#if 1
        int page_begin_line=0;
        
        OveLine *first_line=self.lines.firstObject;
        float staff_height=first_line.staves.count*(default_staff_distance+default_system_distance+5*LINE_height);
        
        for (int i=0; i<self.lines.count; i++) {
            OveLine *line=self.lines[i];
            //float height=line.staves.count*(default_staff_distance+default_system_distance+5*LINE_height);
            if ((i-page_begin_line)*staff_height>self.page_height || i==self.lines.count-1) {
                OvePage *page=[[OvePage alloc] init];
                [self.pages addObject:page];
                //page.system_distance=first_page.system_distance;
                //page.staff_distance=first_page.staff_distance;
                page.begin_line=page_begin_line;
                page.line_count=i+1-page_begin_line;
                page_begin_line=i+1;
                
                OveMeasure *temp_measure=self.measures[line.begin_bar];
                //page.system_distance = temp_measure.xml_system_distance;
                //page.staff_distance=temp_measure.xml_staff_distance;
                if (temp_measure.xml_top_system_distance>0) {
                    page.xml_top_system_distance=temp_measure.xml_top_system_distance;
                }else{
                    page.xml_top_system_distance=LINE_height*10;
                }
            }
        }
#endif
    }
#endif

    //sort notes for each measure
    for (int i=0; i<max_measures; i++) {
        OveMeasure *temp_measure = [self.measures objectAtIndex:i];
        float unitPerBeat=temp_measure.meas_length_size/(temp_measure.meas_length_tick/480.0);
//        float temp_unitPerBeat=temp_measure.meas_length_size/(1.0*temp_measure.numerator*4/temp_measure.denominator);
//        if (unitPerBeat!=temp_unitPerBeat) {
//            NSLog(@"measure(%d)",i);
//        }
        //按照duration分组notes
        if(temp_measure.sorted_notes==nil){
            temp_measure.sorted_notes=[[NSMutableDictionary alloc]init ];
        }
        for (OveNote *note in temp_measure.notes) {
            NSString *tmp_key=[NSString stringWithFormat:@"%d", note.pos.tick];
            NSMutableArray *temp_notes=[temp_measure.sorted_notes objectForKey:tmp_key];
            if (temp_notes==nil) {
                temp_notes=[[NSMutableArray alloc]init ];
                [temp_measure.sorted_notes setObject:temp_notes forKey:tmp_key];
            }
            [temp_notes addObject:note];
        }
        
//        [temp_measure checkDontPlayedNotes];
        
        temp_measure.sorted_duration_offset=[temp_measure.sorted_notes.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString* obj1, NSString* obj2) {
            return ([obj1 intValue]>[obj2 intValue])?NSOrderedDescending:NSOrderedAscending;
        }];
        
        //调整每个note的offset: clef
        int delta_offset=0;
        //1024x1365
        float LINE_width=self.page_width/102.40;
        //float last_note_offset=0,note_offset=0;
        for (int nn=0;nn<temp_measure.sorted_duration_offset.count;nn++) {
            NSString *key = [temp_measure.sorted_duration_offset objectAtIndex:nn];
            int min_xml_duration=10000;
            NSArray *notes=[temp_measure.sorted_notes objectForKey:key];
            //float unitPerTick=temp_measure.meas_length_size/(480.0*temp_measure.numerator);
            
            //sharp/flat/natural
            for (OveNote *note in notes) {
                for (NoteElem *elem in note.note_elems) {
                    if (elem.accidental_type>0 && (nn==0 || note.note_type>Note_Quarter) ) {
                        delta_offset+=LINE_height*1;
                        if (nn==0 && temp_measure.left_barline==Barline_RepeatLeft) {
                            delta_offset+=LINE_height*1;
                        }else if(note.isGrace) {
                            delta_offset+=LINE_height*1;
                        }
                        break;
                    }
                }
            }
            //grace note
            int grace_number=0;
            for (OveNote *note in notes) {
                if (note.isGrace || note.xml_duration==0) {
                    note.pos.start_offset=delta_offset+unitPerBeat*note.pos.tick/480.0;
                    note.pos.start_offset+=(grace_number-0)*unitPerBeat/(4);
                    grace_number++;
                }
            }
            if (grace_number>0) {
                delta_offset+=(grace_number-0)*unitPerBeat/(3);
            }
            
            for (int ee=0;ee<notes.count;ee++) {
                OveNote *note = [notes objectAtIndex:ee];
                //normal note
                if (!note.isGrace && note.xml_duration>0) {
                    note.pos.start_offset=delta_offset+unitPerBeat*note.pos.tick/480.0;
                    //NSLog(@"%d:%d:%d %d %d",i,nn,ee,note.pos.tick,note.pos.start_offset);
                    if (note.xml_duration<min_xml_duration) {
                        min_xml_duration=note.xml_duration;
                    }
                }
                //sort note_elems for each note
                if (note.note_elems.count>1) {
                    note.sorted_note_elems=[note.note_elems sortedArrayUsingComparator:^NSComparisonResult(NoteElem *obj1, NoteElem *obj2) {
                        NSComparisonResult ret=NSOrderedSame;
                        if (obj1.note>obj2.note) {
                            ret=NSOrderedDescending;
                        }else if (obj1.note<obj2.note) {
                            ret=NSOrderedAscending;
                        }
                        return ret;
                    }];
                }else{
                    note.sorted_note_elems=note.note_elems;
                }
            }
            
            for (OveNote *note in notes) {
                if (note.note_type>Note_Sixteen || (note.note_type>Note_Eight&&!note.inBeam)) {
                    delta_offset+=LINE_height*2;
                    break;
                }
            }
            if (min_xml_duration<temp_measure.xml_division) {
                //delta_offset+=unitPerBeat*(temp_measure.xml_division/2-min_xml_duration)/(temp_measure.xml_division);
                delta_offset+=2*LINE_height*(temp_measure.xml_division-min_xml_duration)/temp_measure.xml_division;//unitPerBeat*(temp_measure.xml_division/2-min_xml_duration)/(temp_measure.xml_division);
            }
            //measure.meas_length_size*note.xml_duration/(last_divisions*last_numerator)
            //clef
            OveNote *note0=notes.firstObject;
            for (MeasureClef *clef in temp_measure.clefs) {
                if (clef.xml_note<0) {
                    if (!clef.xml_scaned && clef.pos.tick<note0.pos.tick) {
                        clef.xml_scaned=YES;
                        if (nn>0) {
                            NSString *prev_key = [temp_measure.sorted_duration_offset objectAtIndex:nn-1];
                            NSArray *prev_notes=[temp_measure.sorted_notes objectForKey:prev_key];
                            OveNote *prev_note=prev_notes.firstObject;
                            clef.pos.start_offset=prev_note.pos.start_offset;
                            clef.pos.tick=prev_note.pos.tick;
                        }
                    }
                    
                }else if (/*clef.pos.tick>0 &&*/ clef.pos.tick==note0.pos.tick && !clef.xml_scaned) {
                    //int increase=LINE_height*8;// temp_measure.meas_length_size/(2*temp_measure.numerator);
                    clef.xml_scaned=YES;
                    int increase=LINE_width*10;
#if 1
                    OveNote *xml_note;
                    if (clef.xml_note<temp_measure.notes.count) {
                        xml_note=temp_measure.notes[clef.xml_note];
                        if (clef.xml_note==0) {
                            clef.pos.tick=0;
                            clef.pos.start_offset=0;
                            increase=0;
                            if (i>0) {
                                //check if there already have clef at the end of the previous measure
                                OveMeasure *prev_measure=self.measures[i-1];
                                for (MeasureClef *prevClef in prev_measure.clefs) {
                                    if (prevClef.staff==clef.staff && prevClef.pos.tick==temp_measure.meas_length_tick) {
                                        clef.pos.start_offset=-0.2*LINE_width;
                                        increase=4*LINE_width;
                                        break;
                                    }
                                }
                            }
                        }else{
                            if (clef.staff==xml_note.staff) {
                                OveNote *prevNote=temp_measure.notes[clef.xml_note-1];
                                clef.pos.tick=xml_note.pos.tick;
                                if (prevNote.staff==clef.staff) {
                                    clef.pos.start_offset=prevNote.pos.start_offset;
                                    if (prevNote.note_type<Note_Eight || (prevNote.note_type==Note_Eight && prevNote.isDot)){//四分音符和二分音符已经有足够的空间，不需要后移了。
                                        increase=0;
                                    }else if (prevNote.note_type==Note_Eight)
                                    {
                                        increase/=2;
                                    }
                                }else{
                                    clef.pos.start_offset=0;
                                    increase=0;
                                }
                            }else{
                                clef.pos.tick=temp_measure.meas_length_tick;
                                clef.pos.start_offset=temp_measure.meas_length_size;
                                increase=0;
                            }
                        }
                    }else{
                        //xml_note=temp_measure.notes.lastObject;
                        //clef.pos.tick=xml_note.pos.tick;
                        clef.pos.tick=temp_measure.meas_length_tick;
                        clef.pos.start_offset=temp_measure.meas_length_size;
                        increase=0;
                    }
                    
#else
                    if (clef.clef==Clef_Bass) {
                        clef.pos.start_offset=note0.pos.start_offset+increase*1.2;
                    }else{
                        clef.pos.start_offset=note0.pos.start_offset+increase;
                    }
#endif
//                    if (xml_note.note_type<Note_Eight || (xml_note.note_type==Note_Eight && xml_note.isDot)){//四分音符和二分音符已经有足够的空间，不需要后移了。
//                        increase=0;
//                    }else if (xml_note.note_type==Note_Eight)
//                    {
//                        increase/=2;
//                    }
                    if (increase>0) {
                        //如果同staff里的clef后面还有音符，才统一后移delta_offset
                        BOOL found=NO;
                        for (OveNote* note in temp_measure.notes) {
                            if (note.staff==clef.staff && note.pos.tick>=clef.pos.tick) {
                                delta_offset+=increase;
                                found=YES;
                                break;
                            }
                        }
//                        if (!found) {
//                            clef.pos.start_offset=note0.pos.start_offset+LINE_width*10;
//                        }
                    }
                }
            }
        }
        temp_measure.meas_length_size+=delta_offset;
        
//        for (MeasureClef *clef in temp_measure.clefs) {
//            if (!clef.xml_scaned && clef.pos.tick>0) {
//                clef.pos.start_offset=unitPerBeat*clef.pos.tick/480.0;
//            }
//        }
    }
    [self processStaves];
    //计算wedge,octaves,pedal, OveDynamic,text的pos;
    for (OvePage *page in self.pages) {
        int line_offset_y=page.xml_top_system_distance;
        for (int ll=page.begin_line;ll<page.line_count+page.begin_line;ll++) {
            OveLine *line = [self.lines objectAtIndex:ll];
            if (ll>page.begin_line) {
                line_offset_y+=line.xml_system_distance;
            }
            line.y_offset=line_offset_y;
            if (ll<page.line_count+page.begin_line-1) {
                OveLine *nextLine=[self.lines objectAtIndex:ll+1];
                line_offset_y+=line.staves.count*LINE_height*4+nextLine.xml_staff_distance*(line.staves.count-1);
            }
            if (line.begin_bar+line.bar_count>max_measures) {
                line.bar_count=max_measures-line.begin_bar;
            }
            for (int mm=line.begin_bar; mm<line.begin_bar+line.bar_count; mm++) {
                OveMeasure *measure=[self.measures objectAtIndex:mm];
//                float unitPerBeat=measure.meas_length_size/(1.0*measure.numerator*4/measure.denominator);
                float unitPerBeat=measure.meas_length_size/(measure.meas_length_tick/480.0);
                //caculate wedge offset_y
                for (OveWedge *wedge in measure.wedges) {
                    //wedge.pos=[[CommonBlock alloc]init];
                    
                    OveNote *xml_start_note;
                    if (wedge.xml_start_note<measure.notes.count) {
                        xml_start_note=measure.notes[wedge.xml_start_note];
                    }else{
                        xml_start_note=measure.notes.lastObject;
                    }
                    {
//                        if (wedge.pos.tick) {
//                            wedge.pos.start_offset=unitPerBeat * xml_start_note.pos.tick/480.0;
//                        }
                        wedge.pos.tick=xml_start_note.pos.tick;
                        wedge.pos.start_offset+=xml_start_note.pos.start_offset;
                    }
                    
                    OveMeasure *stop_measure;
                    if (wedge.offset.stop_measure>0) {
                        stop_measure=self.measures[measure.number+wedge.offset.stop_measure];
                    }else{
                        stop_measure=measure;
                    }
                    OveNote *xml_stop_note;
                    if (wedge.xml_stop_note<stop_measure.notes.count) {
                        xml_stop_note=stop_measure.notes[wedge.xml_stop_note];
                        if (xml_stop_note.staff!=wedge.xml_staff) {
                            if (wedge.xml_stop_note>0) {
                                xml_stop_note=stop_measure.notes[wedge.xml_stop_note-1];
                                wedge.offset.stop_offset+=stop_measure.meas_length_size-xml_stop_note.pos.start_offset;
                            }else{
                                xml_stop_note=stop_measure.notes.firstObject;
                            }
                        }
                    }else{
                        xml_stop_note=stop_measure.notes.lastObject;
                    }

                    if (wedge.offset.stop_measure==0 && wedge.xml_stop_note==wedge.xml_start_note) {
                        if (wedge.xml_stop_note<measure.notes.count-1) {
                            OveNote *nextNote=measure.notes[wedge.xml_stop_note+1];
                            if (nextNote.staff==xml_stop_note.staff && nextNote.voice==xml_stop_note.voice) {
                                wedge.offset.stop_offset+=nextNote.pos.start_offset;
                            }else{
                                wedge.offset.stop_offset=measure.meas_length_size;
                            }
                        }else{
                            wedge.offset.stop_offset=measure.meas_length_tick;
                        }
                    }else if (wedge.offset.stop_measure>0 || xml_stop_note.pos.start_offset>wedge.pos.start_offset) {
                        wedge.offset.stop_offset+=xml_stop_note.pos.start_offset;//-2*LINE_height;
                        if (measure.wedges.count>0) {
                            wedge.offset.stop_offset-=0.5*LINE_height;
                        }
                    }else{
                        wedge.offset.stop_offset=measure.meas_length_size;
                        //wedge.offset.stop_offset+=xml_stop_note.pos.start_offset;
                    }

                    //+measure.meas_length_size*wedge.xml_start_note.xml_duration/(1.0*measure.numerator*measure.xml_division);
                    wedge.offset_y+=(line.xml_staff_distance+LINE_height*4)*(wedge.xml_staff-1)+4*LINE_height;
                    if (wedge.offset.stop_measure>3) {
                        NSLog(@"error, wedge stop_measure is too big=%d",wedge.offset.stop_measure);
                        wedge.offset.stop_measure=1;
                    }
                }
                //set OctaveShift pos
                for (OctaveShift *shift in measure.octaves) {
                    shift.pos=[[CommonBlock alloc]init];
                    OveNote *xml_note=nil;
                    if (shift.xml_note<measure.notes.count) {
                        xml_note=measure.notes[shift.xml_note];
                        if (xml_note.staff!=shift.staff) {
                            shift.pos.tick=measure.meas_length_tick;
                            shift.pos.start_offset=measure.meas_length_size;
                        }else{
                            shift.pos.tick=xml_note.pos.tick;
                            shift.pos.start_offset=xml_note.pos.start_offset;
                        }
                    }else{
                        NSLog(@"error");
                        //xml_note=measure.notes.lastObject;
                    }
//                    shift.pos.tick=xml_note.pos.tick;
//                    shift.pos.start_offset=xml_note.pos.start_offset;
                }
                //set pedal pos
                for (MeasureDecorators *deco in measure.decorators) {
                    if (deco.artType==Articulation_Pedal_Up || deco.artType==Articulation_Pedal_Down) {
                        deco.pos=[[CommonBlock alloc]init];
                        deco.pos.tick=deco.xml_start_note.pos.tick+deco.xml_start_note.xml_duration*480/measure.xml_division;
                        deco.pos.start_offset=deco.xml_start_note.pos.start_offset+measure.meas_length_size*deco.xml_start_note.xml_duration/(1.0*measure.numerator*measure.xml_division);
                    }
                }
                //set text pos
                for (OveText *text in measure.meas_texts) {
                    //text.pos=[[CommonBlock alloc]init];
                    if (text.pos.tick>0) {
                        text.pos.start_offset=text.pos.tick*unitPerBeat/480.0;
                        text.offset_x=0;
                    }else if (text.xml_start_note==0) {
                        text.pos.tick=0;
                        //text.pos.start_offset=0;
                    }else{
                        OveNote *note;
                        if (text.xml_start_note<measure.notes.count) {
                            note=measure.notes[text.xml_start_note];
                            text.pos.start_offset=note.pos.start_offset;
                        }else{
                            note=measure.notes.lastObject;
                            text.pos.start_offset=measure.meas_length_size;
                        }
                        if (text.pos.tick<0) {
                            text.pos.start_offset+=text.pos.tick*unitPerBeat/480.0;
                        }
                        text.pos.tick=note.pos.tick;
                        
                    }
                }
                
                //set OveDynamic pos
                for (OveDynamic *dynamic in measure.dynamics)
                {
                    if (dynamic.pos.tick>0) {
                        dynamic.pos.start_offset=dynamic.pos.tick*unitPerBeat/480.0;
                    }else{
#if 1
                        dynamic.pos.start_offset+=dynamic.pos.tick*unitPerBeat/480.0;
#else
                        OveNote *xml_note;
                        if (dynamic.xml_note<measure.notes.count) {
                            xml_note=measure.notes[dynamic.xml_note];
                        }else{
                            xml_note=measure.notes.lastObject;
                        }
                        //dynamic.pos=[[CommonBlock alloc]init];
                        if (dynamic.pos.tick) {
                            dynamic.pos.start_offset+=dynamic.pos.tick*unitPerBeat/480.0;
                        }
                        if (xml_note.staff!=dynamic.staff) {
                            dynamic.pos.tick=0;
                        }else{
                            dynamic.pos.tick=xml_note.pos.tick;
                            //dynamic.pos.start_offset=xml_note.pos.start_offset;//-measure.xml_firstnote_offset_x;
                            dynamic.pos.start_offset+=xml_note.pos.start_offset;
                            //dynamic.pos.start_offset-=measure.xml_firstnote_offset_x;
                        }
#endif
                    }
                }
#if 1
                //set velocity for each note_elem
#define VELOCITY_HIGH   90
#define VELOCITY_MID    80
#define VELOCITY_LOW    70
                
                for (NSNumber *tick in measure.sorted_duration_offset) {
                    int velocity=VELOCITY_LOW;
                    BOOL usedDyn=NO;
                    for (OveDynamic *dyn in measure.dynamics)
                    {
                        if (dyn.dynamics_type>=Dynamics_pppp || dyn.dynamics_type<=Dynamics_ffff) {
                            if (tick.intValue>dyn.pos.tick-measure.meas_length_tick*0.1 && tick.intValue<dyn.pos.tick+measure.meas_length_tick*0.25) {
                                velocity=VELOCITY_MID+10*(dyn.dynamics_type-Dynamics_mf); //0-9
                                usedDyn=YES;
                                break;
                            }
                        }
                    }
                    if (!usedDyn) {
                        // 2/4,2/8: 强，弱
                        if (measure.numerator<4) {
                            if (tick.intValue<measure.meas_length_tick*1.0/measure.numerator) {
                                velocity=VELOCITY_HIGH;
                            }
                            // 4/4,4/8: 强，弱, 次强,弱
                        }else if (measure.numerator==4) {
                            if (tick.intValue<measure.meas_length_tick*0.25) {
                                velocity=VELOCITY_HIGH;
                            }else if (tick.intValue>=measure.meas_length_tick*0.5 && tick.intValue<measure.meas_length_tick*0.75){
                                velocity=VELOCITY_MID;
                            }
                        }
                        /*
                         3/4,3/8：强，弱，弱
                         6/4,6/8: 强,弱,弱, 次强,弱,弱
                         9/8: 强,弱,弱, 次强,弱,弱, 次强,弱,弱
                         12/8: 强,弱,弱, 次强,弱,弱, 次强,弱,弱, 次强,弱,弱
                         */
                        else if (measure.numerator==3){
                            if (tick.intValue<measure.meas_length_tick*0.33) {
                                velocity=VELOCITY_HIGH;
                            }
                        }else if (measure.numerator==6){
                            if (tick.intValue<measure.meas_length_tick*0.33) {
                                velocity=VELOCITY_HIGH;
                            }else if (tick.intValue>=measure.meas_length_tick*0.5 && tick.intValue<measure.meas_length_tick*0.66){
                                velocity=VELOCITY_MID;
                            }
                        }else if (measure.numerator==9){
                            if (tick.intValue<measure.meas_length_tick/9.0) {
                                velocity=VELOCITY_HIGH;
                            }else if ((tick.intValue>=measure.meas_length_tick*0.33 && tick.intValue<measure.meas_length_tick*4.0/9.0) ||
                                      (tick.intValue>=measure.meas_length_tick*0.66 && tick.intValue<measure.meas_length_tick*7.0/9.0)){
                                velocity=VELOCITY_MID;
                            }
                        }else if (measure.numerator==12){
                            if (tick.intValue<measure.meas_length_tick/12.0) {
                                velocity=VELOCITY_HIGH;
                            }else if ((tick.intValue>=measure.meas_length_tick*3.0/12 && tick.intValue<measure.meas_length_tick*4.0/12) ||
                                      (tick.intValue>=measure.meas_length_tick*6.0/12 && tick.intValue<measure.meas_length_tick*7.0/12) ||
                                      (tick.intValue>=measure.meas_length_tick*9.0/12 && tick.intValue<measure.meas_length_tick*10.0/12)
                                      ){
                                velocity=VELOCITY_MID;
                            }
                        }
                    }                    
                    NSArray *notes=[measure.sorted_notes objectForKey:tick];
                    for (OveNote *note in notes) {
                        if (!note.isGrace) {
                            for (NoteElem *note_elem in note.note_elems) {
                                note_elem.velocity=velocity;
                            }
                        }
                    }
                }
#endif
            }
        }
    }
#ifdef ONLY_ONE_PAGE
    if (self.lines.count>1) {
        OveLine *lastLine=self.lines.lastObject;
        LineStaff *lastStaff=lastLine.staves.lastObject;
        self.page_height=lastLine.y_offset+LINE_height*5+lastStaff.y_offset+200;
    }
#endif
    [self processLyrics];
    [self processBeams];
    [self processTuplets];
    [self processSlursAfter];
    [self processTies];
    [self processFingers];
    [self processPedals];
    [self processRestPos];
    return YES;
}
- (void)processStaves {
    
    for (int i=0; i<self.lines.count; i++) {
        OveLine *line=self.lines[i];
        if (line.staves.count>2) {
            BOOL hideStaff=YES;
            for (int m=line.begin_bar; m<line.begin_bar+line.bar_count; m++) {
                OveMeasure *measure=self.measures[m];
                for (OveNote *note in measure.notes) {
                    if (note.staff==line.staves.count && note.note_elems.count>0) {
                        hideStaff=NO;
                        break;
                    }
                }
            }
            if (hideStaff) {
//                for (int m=line.begin_bar; m<line.begin_bar+line.bar_count; m++) {
//                    OveMeasure *measure=self.measures[m];
//                    for (OveNote *note in measure.notes) {
//                        if (note.staff==line.staves.count && note.note_elems.count>0) {
//                            note.hide=YES;
//                        }
//                    }
//                }
//                LineStaff *lineStaff=line.staves.lastObject;
//                lineStaff.hide=YES;
                LineStaff *first=line.staves.firstObject;
                [line.staves removeLastObject];
                if (first.group_staff_count>line.staves.count-1) {
                    first.group_staff_count=line.staves.count-1;
                }
            }
        }
    }
}
- (void)processRestPos
{
    for (int i=0; i<self.max_measures; i++) {
        OveMeasure *measure=[self.measures objectAtIndex:i];
        for (NSArray *notes in measure.sorted_notes.allValues) {
            for (OveNote *note in notes) {
                if (note.isRest && note.line==0) {
                    OveNote *nextVoiceNote=nil;
                    for (OveNote *otherNote in measure.notes) {
                        if (otherNote.staff==note.staff && otherNote.voice != note.voice) {
                            if (otherNote.isRest && otherNote.note_type==note.note_type) {
                                //dont shift same rest;
                            }else{
                                nextVoiceNote=otherNote;
                                break;
                            }
                        }
                    }
                    if (nextVoiceNote) {
                        if (note.voice<nextVoiceNote.voice) {
                            int topline=nextVoiceNote.line;
                            if (nextVoiceNote.note_elems.count>1) {
                                NoteElem *elem=nextVoiceNote.note_elems.lastObject;
                                topline=elem.line;
                            }
                            if (note.line<topline+4 && topline>-3) {
                                note.line=topline+4;
                            }
                        }else{
                            int bottomline=nextVoiceNote.line;
                            if (nextVoiceNote.note_elems.count>1) {
                                NoteElem *elem=nextVoiceNote.note_elems.firstObject;
                                bottomline=elem.line;
                            }
                            if (note.line>bottomline-4 && bottomline<3) {
                                note.line=bottomline-4;
                            }
                        }
                    }
                }
            }
        }
    }
}
- (void)processPedals
{
    for (int i=0; i<self.max_measures; i++) {
        OveMeasure *measure=[self.measures objectAtIndex:i];
        for (MeasurePedal *pedal in measure.pedals) {
            //start
            if (pedal.xml_start_note_index<measure.notes.count) {
                OveNote *start_note=measure.notes[pedal.xml_start_note_index];
                pedal.pos.start_offset=start_note.pos.start_offset;
            }else{
                OveNote *start_note=measure.notes.lastObject;
                pedal.pos.start_offset=start_note.pos.start_offset;
                //pedal.pos.start_offset=measure.meas_length_size;
            }
            
            //stop
            //pedal.xml_stop_note_index=(int)measure.notes.count;
            OveMeasure *stop_measure=self.measures[pedal.xml_stop_measure_index];
            if (pedal.xml_stop_note_index>=stop_measure.notes.count-1) {
                if (pedal.xml_start_note_index==pedal.xml_stop_note_index && pedal.xml_start_measure_index==pedal.xml_stop_measure_index) {
                    pedal.offset.stop_offset=measure.meas_length_size;
                }else{
                    OveNote *stop_note=stop_measure.notes.lastObject;
                    pedal.offset.stop_offset=stop_note.pos.start_offset;
                }
            }else{
                OveNote *stop_note=stop_measure.notes[pedal.xml_stop_note_index];
                pedal.offset.stop_offset=stop_note.pos.start_offset;
            }
        }
    }
}
- (void)processFingers
{
    //check fingers for chord note
    for (int i=0; i<self.max_measures; i++) {
        OveMeasure *measure=[self.measures objectAtIndex:i];
        for (NSArray *notes in measure.sorted_notes.allValues) {
            
            for (OveNote *note in notes) {
                if(note.note_elems.count>0 && note.xml_fingers.count>0){
                    if (note.note_arts==nil) {
                        note.note_arts=[NSMutableArray new];
                    }
                    NoteArticulation *art=note.xml_fingers.firstObject;
                    NoteArticulation *lastArt=note.xml_fingers.lastObject;
                    BOOL above=art.art_placement_above;
                    ArticulationPos finger_pos=above?ArtPos_Above:ArtPos_Down;
                    
                    if (note.note_elems.count==note.xml_fingers.count && note.xml_fingers.count>1) {
                        NoteElem *firstElem=note.note_elems.firstObject;
                        NoteElem *secondElem=note.note_elems[1];
                        if (secondElem.line-firstElem.line>1 && note.pos.tick==0) {
                            if (art.offset.offset_x<=-9 && lastArt.offset.offset_x<=-9) {
                                finger_pos=ArtPos_Left;
                            }else if (art.offset.offset_x>15 && lastArt.offset.offset_x>15) {
                                finger_pos=ArtPos_Right;
                            }
                        }
                    } /* if (note.note_type>Note_Whole &&
                        note.note_elems.count==note.xml_fingers.count &&
                        ((note.voice==1 && note.staff==1 && !note.stem_up) ||
                         (note.voice==2 && note.staff==2 && !note.stem_up)
                         )
                        )
                    {
                        finger_pos=ArtPos_Above;
                    }else if (lastArt.offset.offset_y<0 && !note.stem_up){
                        finger_pos=ArtPos_Down;
                    }*/
                    if (finger_pos!=ArtPos_Left && finger_pos!=ArtPos_Right && note.note_elems.count==note.xml_fingers.count) {
//                        if (!above && art.offset.offset_y<-15 && lastArt.offset.offset_y<-15) {
//                            finger_pos=ArtPos_Above;
//                        }else if (above && art.offset.offset_y<-15 && lastArt.offset.offset_y<-15) {
//                            finger_pos=ArtPos_Down;
//                        }
                    }
                    above=(finger_pos>ArtPos_Down);
                    
                    if (note.xml_fingers.count>1 && note.note_elems.count>1) {
                        [note.xml_fingers sortWithOptions:0 usingComparator:^NSComparisonResult(NoteArticulation *obj1, NoteArticulation *obj2) {
                            //NSLog(@"%@:%@",obj1.finger, obj2.finger);
                            if (obj1.art_placement_above != obj2.art_placement_above) {
                                if (above ) {
                                    if (obj1.art_placement_above && !obj2.art_placement_above) {
                                        //NSLog(@"1: d");
                                        return NSOrderedDescending;
                                    }else{
                                        //NSLog(@"1: a");
                                        return NSOrderedAscending;
                                    }
                                }else{
                                    if (obj1.art_placement_above && !obj2.art_placement_above) {
                                        //NSLog(@"2: a");
                                        return NSOrderedAscending;
                                    }else{
                                        //NSLog(@"2: d");
                                        return NSOrderedDescending;
                                    }
                                }
                            }
                            if (above) {
                                if (obj1.offset.offset_y>obj2.offset.offset_y) {
                                    //NSLog(@"4: d");
                                    return NSOrderedDescending;
                                }else{
                                    //NSLog(@"4: a");
                                    return NSOrderedAscending;
                                }
                            }else{
                                if (obj1.offset.offset_y>obj2.offset.offset_y) {
                                    //NSLog(@"4: d");
                                    return NSOrderedAscending;
                                }else{
                                    //NSLog(@"4: a");
                                    return NSOrderedDescending;
                                }
                            }
                        }];
                    }
                    if (note.xml_fingers.count>1 && note.note_elems.count==1) {
                        
                        BOOL twoVoice=NO;
                        //                            for (OveNote *nextNote in notes) {
                        //                                if (nextNote.staff==note.staff && nextNote.voice!=note.voice) {
                        //                                    twoVoice=YES;
                        //
                        //                                    break;
                        //                                }
                        //                            }
                        if (!twoVoice) {
                            NoteArticulation *firstArt=note.xml_fingers.firstObject;
                            NoteArticulation *lastArt=note.xml_fingers.lastObject;
                            if (firstArt.offset.offset_y>lastArt.offset.offset_y-3 && firstArt.offset.offset_y<lastArt.offset.offset_y+3) {
                                BOOL haveTrill=NO;
                                for (NoteArticulation *a in note.note_arts) {
                                    if (a.art_type==Articulation_Major_Trill||a.art_type==Articulation_Minor_Trill) {
                                        haveTrill=YES;
                                    }
                                }
                                if (note.xml_fingers.count==2) {
                                    NSString *seg;
                                    if (haveTrill) {//颤音指法
                                        seg=@" ";
                                    }else{
                                        seg=@"-";//同音换指
                                    }
                                    
                                    if (firstArt.offset.offset_x<lastArt.offset.offset_x) {
                                        firstArt.finger=[NSString stringWithFormat:@"%@%@%@", firstArt.finger,seg,lastArt.finger];
                                    }else{
                                        firstArt.finger=[NSString stringWithFormat:@"%@%@%@", lastArt.finger,seg,firstArt.finger];
                                    }
                                    [note.xml_fingers removeLastObject];
                                }else{
                                    NSString *str=@"";
                                    if (firstArt.offset.offset_x<lastArt.offset.offset_x) {
                                        for (NoteArticulation *art in note.xml_fingers) {
                                            str=[str stringByAppendingFormat:@" %@",art.finger];
                                        }
                                    }else{
                                        for (NoteArticulation *art in note.xml_fingers) {
                                            str=[art.finger stringByAppendingFormat:@" %@",str];
                                        }
                                    }
                                    firstArt.finger=str;
                                    [note.xml_fingers removeObjectsInRange:NSMakeRange(1, note.xml_fingers.count-1)];
                                }
                                
                                firstArt.offset.offset_y=0;//LINE_height*1.5;
                                firstArt.offset.offset_x=-LINE_height;
                                [note.note_arts addObject:firstArt];
                            }else{
                                //可选择指法
                                if (above) {
                                    firstArt.alterFinger=[NSString stringWithFormat:@"%@", lastArt.finger];
                                    firstArt.finger=[NSString stringWithFormat:@"%@", firstArt.finger];
                                }else{
                                    firstArt.alterFinger=[NSString stringWithFormat:@"%@", lastArt.finger];
                                    firstArt.finger=[NSString stringWithFormat:@"%@", firstArt.finger];
                                }
                                firstArt.offset.offset_y=0;// above?LINE_height*1.5:-LINE_height*1.5;
                                firstArt.offset.offset_x=0;//-LINE_height;
                                [note.xml_fingers removeLastObject];
                                [note.note_arts addObject:firstArt];
                            }
                        }
                    }else{
                        [note.note_arts addObjectsFromArray:note.xml_fingers];
                        int left_offset_x=0;
                        if (finger_pos==ArtPos_Left) {
                            for (NoteElem *elem in note.note_elems) {
                                if (elem.accidental_type!=Accidental_Normal) {
                                    left_offset_x=-LINE_height;
                                    break;
                                }
                            }
                        }
                        for (int f=0; f<note.xml_fingers.count; f++) {
                            NoteArticulation *art=note.xml_fingers[f];
//                            float y_times=1;
                            art.art_placement_above=above;
                            art.offset.offset_y=0;
                            art.offset.offset_x=0;
                            if (note.xml_fingers.count==note.note_elems.count && finger_pos>ArtPos_Above) {
//                                NoteElem *bottom_elem=note.note_elems.firstObject;
//                                NoteElem *elem=note.note_elems[note.note_elems.count-f-1];
                                NoteElem *top_elem=note.note_elems.lastObject;
                                NoteElem *elem=note.note_elems[f];
                                if (finger_pos==ArtPos_Left) {
                                    art.offset.offset_x=-2.0*LINE_height+left_offset_x;
                                    //art.offset.offset_y=-0.55*(elem.line-bottom_elem.line+1)*LINE_height;
                                    art.offset.offset_y=-0.55*(top_elem.line - elem.line+1)*LINE_height;
                                }else if (finger_pos==ArtPos_Right) {
                                    art.offset.offset_x=2.5*LINE_height;
                                    //art.offset.offset_y=-0.55*(elem.line-bottom_elem.line+1)*LINE_height;
                                    art.offset.offset_y=-0.55*(top_elem.line - elem.line+1)*LINE_height;
                                }
                            }
                            if (!note.inBeam && note.note_type>Note_Whole) {
                                if (!note.stem_up && !above) {
                                    art.offset.offset_x=3;
                                }
                            }
                        }
                    }
                    
                    if (note.note_elems.count<=note.xml_fingers.count) {
                        for (int f=0; f<note.note_elems.count; f++) {
                            if (f<note.xml_fingers.count) {
                                NoteElem *elem;
                                if (above) {
                                    elem=note.note_elems[f];
                                }else{
                                    elem=note.note_elems[note.note_elems.count-f-1];
                                }
                                NoteArticulation *art=note.xml_fingers[f];
                                elem.xml_finger=art.finger;
                            }
                        }
                        if (note.xml_fingers.count==2*note.note_elems.count) {
                            //可选择指法,在中间插一个延音记号
                            int finger_count=0;
                            for (int f=0; f<note.note_arts.count; f++) {
                                NoteArticulation *art=note.note_arts[f];
                                if (art.art_type==Articulation_Finger) {
                                    finger_count++;
                                    if (finger_count==note.note_elems.count) {
                                        NoteArticulation *new_art=[[NoteArticulation alloc] init];
                                        new_art.art_type=Articulation_Tenuto;
                                        new_art.art_placement_above=art.art_placement_above;
                                        [note.note_arts insertObject:new_art atIndex:f+1];
                                        break;
                                    }
                                }
                            }
                        }
                    } //暂时不要在虚拟键盘上显示指法少于和弦个数的指法。
                      else if(note.note_elems.count>note.xml_fingers.count && note.xml_fingers.count>1){
                        for (int f=0; f<note.note_elems.count; f++) {
                            if (f<note.xml_fingers.count) {
                                NoteElem *elem;
                                if (above) {
                                    elem=note.note_elems[note.note_elems.count-f-1];
                                }else{
                                    elem=note.note_elems[f];
                                }
                                NoteArticulation *art=note.xml_fingers[note.xml_fingers.count-f-1];
                                elem.xml_finger=art.finger;
                            }
                        }
                    }
                    //
                }
            }
        }//for sorted_notes
        
        [measure checkDontPlayedNotes];
    }
}

- (void)processLyrics
{
    for (int i=0; i<self.max_measures; i++) {
        OveMeasure *measure=[self.measures objectAtIndex:i];
        for (int nn=0; nn<measure.notes.count; nn++) {
            OveNote *note=[measure.notes objectAtIndex:nn];
            if (note.xml_lyrics.count==0) {
                continue;
            }
            
            if (measure.lyrics==nil) {
                measure.lyrics=[[NSMutableArray alloc]init];
            }
            for (NSDictionary *dict in note.xml_lyrics) {
                MeasureLyric *lyric=[[MeasureLyric alloc]init];
                [measure.lyrics addObject:lyric];
                
                lyric.staff=note.staff;
                lyric.voice=note.voice;
                int number=[[dict objectForKey:@"number"] intValue];
                lyric.verse=number-1;
                
                int offset_y=[[dict objectForKey:@"offset_y"] intValue];
                int offset_x=[[dict objectForKey:@"offset_x"] intValue];
                lyric.offset=[[OffsetElement alloc]init];
                lyric.offset.offset_y=offset_y;
                lyric.offset.offset_x=offset_x;
                
                lyric.pos=[[CommonBlock alloc]init];
                lyric.pos.tick=note.pos.tick;
                lyric.pos.start_offset=note.pos.start_offset;
                
                lyric.lyric_text = [dict objectForKey:@"text"];
            }
            note.xml_lyrics=nil;
        }
    }
}

- (void)processTuplets{
    for (int i=0; i<self.max_measures; i++) {
        OveMeasure *measure=[self.measures objectAtIndex:i];
        for (int nn=0; nn<measure.notes.count; nn++) {
            OveNote *note=[measure.notes objectAtIndex:nn];
            if (!note.inBeam && note.xml_tuplets) {
                for (NSDictionary *dict in note.xml_tuplets) {
                    NSString *type=dict[@"type"]; //start, stop
                    BOOL needBracket=[dict[@"bracket"] boolValue];
                    if (!needBracket && [type isEqualToString:@"start"]) {
                        continue;
                    }
                    NSString *number=dict[@"number"];
                    int xml_slur_number=number.intValue;
                    if ([type isEqualToString:@"start"]) {
                        if (measure.tuplets==nil) {
                            measure.tuplets=[NSMutableArray new];
                        }
                        OveTuplet *tuplet=[[OveTuplet alloc]init];
                        [measure.tuplets addObject:tuplet];
                        tuplet.staff=note.staff;
                        tuplet.stop_staff=note.staff;
                        tuplet.pos=[[CommonBlock alloc] init];
                        tuplet.pos.start_offset=note.pos.start_offset;
                        tuplet.pos.tick=note.pos.tick;
                        tuplet.pair_ends=[[PairEnds alloc]init];
                        tuplet.pair_ends.left_line=note.line+4;
                        if (note.stem_up) {
                            tuplet.pair_ends.left_line+=6;
                        }
                        
                        tuplet.xml_slur_number=xml_slur_number;
                        tuplet.xml_start_note_index=nn;
                    }else{ //stop
                        for (int prev=(int)measure.tuplets.count-1; prev>=0; prev--) {
                            OveTuplet *prevTuplet=measure.tuplets[prev];
                            if (/*prevTuplet.staff==note.staff &&*/ prevTuplet.xml_slur_number==xml_slur_number && prevTuplet.offset==nil) {
                                prevTuplet.offset=[[OffsetCommonBlock alloc]init];
                                prevTuplet.offset.stop_measure=0;
                                
                                prevTuplet.offset.stop_offset=note.pos.start_offset;
                                prevTuplet.pair_ends.right_line=note.line+4;
                                if (note.stem_up) {
                                    prevTuplet.pair_ends.right_line+=6;
                                    prevTuplet.offset.stop_offset+=LINE_height;
                                }
                                prevTuplet.tuplet=3;
//                                prevTuplet.tuplet=nn-prevTuplet.xml_start_note_index;
//                                if (prevTuplet.tuplet>3) {
//                                    prevTuplet.tuplet=6;
//                                }else {
//                                    prevTuplet.tuplet=3;
//                                }
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
}

- (void)processBeams{
    //process beams
    NSMutableArray *openedBeams=[[NSMutableArray alloc]init];
    for (int i=0; i<self.measures.count; i++) {
        OveMeasure *measure=[self.measures objectAtIndex:i];
        //beam_continue_lines
        NSMutableArray *beam_continue_lines=[[NSMutableArray alloc]initWithCapacity:measure.notes.count];
        
        int tuplet_index=0;
        for (int nn=0; nn<measure.notes.count; nn++) {
            OveNote *note=[measure.notes objectAtIndex:nn];
            //tuplets
            BOOL xml_have_tuplets=NO;
            if (note.xml_tuplets) {
                if (note.note_type>Note_Quarter && !note.isRest && note.inBeam) {
                    xml_have_tuplets=YES;
                    for (NSDictionary *dict in note.xml_tuplets) {
                        NSString *show_number=dict[@"show-number"];
                        if ([show_number isEqualToString:@"none"]) {
                            xml_have_tuplets=NO;
                        }else{
                            NSString *type=dict[@"type"];
                            NSString *number=dict[@"number"];
                            if ([type isEqualToString:@"stop"] && nn>0) {
                                for (int prevN=nn-1; prevN>=0 && xml_have_tuplets; prevN--) {
                                    OveNote *prevNote=measure.notes[prevN];
                                    if (prevNote.staff==note.staff && prevNote.xml_tuplets) {
                                        for (NSDictionary *prevTuplet in prevNote.xml_tuplets) {
                                            NSString *prefType=prevTuplet[@"type"];
                                            NSString *prevNumber=prevTuplet[@"number"];
                                            if ([number isEqualToString:prevNumber] && [prefType isEqualToString:@"start"]) {
                                                NSString *prev_show_number=prevTuplet[@"show-number"];
                                                if ([prev_show_number isEqualToString:@"none"]) {
                                                    xml_have_tuplets=NO;
                                                }
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    note.xml_tuplets=nil;
                }
            }
            
            //beams
            if (note.xml_beams.count==0) {
                continue;
            }
            NSArray *sorted_beam_keys=[note.xml_beams.allKeys sortedArrayUsingSelector:@selector(compare:)];
            
            //beam line
            int beam_line_offset=7;
            if (note.isGrace) {
                beam_line_offset=4;
            }
            int beam_line=0;
            NoteElem *lastElem=[note.note_elems lastObject];
            NoteElem *firstElem=[note.note_elems objectAtIndex:0];
            if (note.xml_stem_default_y!=0) {
                beam_line=4+note.xml_stem_default_y/(LINE_height)*2;
            }else if (note.stem_up) {
                if (firstElem.line>lastElem.line) {
                    beam_line=firstElem.line+beam_line_offset;
                }else{
                    beam_line=lastElem.line+beam_line_offset;
                }
            }else{
                if (firstElem.line<lastElem.line) {
                    beam_line=firstElem.line-beam_line_offset;
                }else{
                    beam_line=lastElem.line-beam_line_offset;
                }
            }
            
            //梁: dict[key:index value:begin, continue, end, forward hook, and backward hook]
            for (int bb=0; bb<note.xml_beams.count; bb++) {
                if (measure.beams==nil) {
                    measure.beams=[[NSMutableArray alloc]init];
                }
                NSString *beam_number=[sorted_beam_keys objectAtIndex:bb];
                NSString *beam_type=note.xml_beams[beam_number];
                
                //hotfix: for some beam has "continue", but it has no "end"
                if ([beam_type isEqualToString:@"continue"]) {
                    OveNote *next_note=nil;
                    if (nn<measure.notes.count-1) {
                        next_note=measure.notes[nn+1];
                    }else{
                        
                    }
                    if (next_note && next_note.note_type<note.note_type) {
                        BOOL have_next_beam=NO;
                        for (NSString *next_beam_number in next_note.xml_beams.allKeys) {
                            if ([beam_number isEqualToString:next_beam_number]) {
                                have_next_beam=YES;
                                break;
                            }
                        }
                        if (!have_next_beam) {
                            beam_type=@"end";
                        }
                    }
                }
                //hotfix: for some beam has two "end"
                if ([beam_type isEqualToString:@"end"]) {
                    OveNote *next_note=nil;
                    if (nn<measure.notes.count-1) {
                        next_note=measure.notes[nn+1];
                    }else{
                        
                    }
                    if (next_note && next_note.note_type<note.note_type) {
                        BOOL have_next_beam=NO;
                        for (NSString *next_beam_number in next_note.xml_beams.allKeys) {
                            if ([beam_number isEqualToString:next_beam_number] && [next_note.xml_beams[next_beam_number] isEqualToString:beam_type]) {
                                have_next_beam=YES;
                                break;
                            }
                        }
                        if (have_next_beam) {
                            beam_type=@"continue";
                        }
                    }
                }
                //hotfix:for some beam has "end", but it has no "begin"
                if ([beam_type isEqualToString:@"end"] && openedBeams.count>0) {
                    BOOL has_begin=NO;
                    for (OveBeam *beam in openedBeams) {
                        for (BeamElem *beam_elem in beam.beam_elems) {
                            if (beam_elem.xml_beam_number==[beam_number intValue] && beam.isGrace==note.isGrace) {
                                has_begin=YES;
                                break;
                            }
                        }
                    }
                    if (!has_begin) {
                        beam_type=@"forward hook";
                    }
                }

                
                if ([beam_type isEqualToString:@"begin"]) {
                    OveBeam *beam=nil;
                    if (openedBeams.count>0) {
                        beam = openedBeams.lastObject;
                        if ((beam.staff==note.staff && beam.voice!=note.voice) || beam.isGrace!=note.isGrace)
                        {
                            beam=nil;
                        }
                    }
                    if (beam==nil)
                    {
                        //if (note.xml_have_tuplets)
                        {
                            tuplet_index=nn;
                        }
                        [beam_continue_lines removeAllObjects];
                        
                        beam=[[OveBeam alloc]init];
                        [measure.beams addObject:beam];
                        [openedBeams addObject:beam];
                        beam.drawPos_width=0;
                        beam.staff=note.staff;
                        beam.voice=note.voice;
                        beam.isGrace=note.isGrace;
                        beam.pos=[[CommonBlock alloc]init];
                        beam.pos.tick=note.pos.tick;
                        beam.pos.start_offset=note.pos.start_offset;
                        
                        beam.left_line=beam_line;
                        beam.beam_elems=[[NSMutableArray alloc]init];
                    }
                    beam.beam_start_note=note;
                    
                    BeamElem *beam_elem=[[BeamElem alloc]init];
                    [beam.beam_elems addObject:beam_elem];
                    beam_elem.xml_beam_number=[beam_number intValue];
                    beam_elem.start_measure_pos=i;
                    beam_elem.start_measure_offset=note.pos.start_offset;
                    beam_elem.level=[beam_number intValue];//beam.beam_elems.count;
                }else if([beam_type isEqualToString:@"backward hook"] || [beam_type isEqualToString:@"forward hook"])
                {
                    OveBeam *beam;
                    if (measure.beams.count>0) {
                        beam=[measure.beams lastObject];
                        
                        BeamElem *beam_elem=[[BeamElem alloc]init];
                        [beam.beam_elems addObject:beam_elem];
                        beam_elem.start_measure_pos=0;
                        beam_elem.start_measure_offset=note.pos.start_offset;
                        beam_elem.stop_measure_pos=0;
                        beam_elem.stop_measure_offset=note.pos.start_offset;
                        beam_elem.level=[beam_number intValue];//beam.beam_elems.count;
                        if ([beam_type isEqualToString:@"backward hook"]) {
                            beam_elem.beam_type=Beam_Backward;
                        }else{
                            beam_elem.beam_type=Beam_Forward;
                        }
                    }else{
                        NSLog(@"error, no OpenedBeams for backward hook");
                    }
                }else if ([beam_type isEqualToString:@"continue"]) {
                    [beam_continue_lines addObject:[NSNumber numberWithInt:beam_line]];
                }else if([beam_type isEqualToString:@"end"])
                {
                    for (OveBeam *beam in openedBeams) {
                        if ((beam.staff==note.staff && beam.voice!=note.voice) || beam.isGrace!=note.isGrace) {
                            continue;
                        }
                        int not_closed_beamelem=0;
                        for (BeamElem *beam_elem in beam.beam_elems) {
                            if (beam_elem.xml_beam_number == beam_number.intValue/* && beam.staff==note.staff && beam.voice==note.voice*/) {
                                beam.stop_staff=note.staff;
                                beam.right_line=beam_line;
                                beam.beam_stop_note=note;

                                if (beam.staff==note.staff) {//如果头和尾不在同一个staff，就不要调整left，right_line了
                                    if (beam.right_line+4<beam.left_line) {
                                        if (note.stem_up) {
                                            beam.right_line+=3;
                                        }else{
                                            beam.left_line-=3;
                                        }
                                    }else if (beam.left_line+4<beam.right_line) {
                                        if (note.stem_up) {
                                            beam.left_line+=3;
                                        }else{
                                            beam.right_line-=3;
                                        }
                                    }
                                    if (beam_continue_lines.count==0) {
                                        if (beam.left_line>beam.right_line+2) {
                                            beam.right_line=beam.left_line-2;
                                        }else if (beam.left_line<beam.right_line-2){
                                            beam.right_line=beam.left_line+2;
                                        }
                                    }
                                    //检查Beam中间的note的beam位置。（不包括两头的note）
                                    for (int bc=0;bc<beam_continue_lines.count;bc++)
                                    {
                                        NSNumber *line_num = [beam_continue_lines objectAtIndex:bc];
                                        int target_line=line_num.intValue;
                                        int cur_line=(beam.left_line+beam.right_line)*(1.0*(bc+1)/(beam_continue_lines.count+2));
                                        if (note.stem_up)
                                        {
                                            if (target_line>cur_line && target_line<cur_line+10)
                                            {
                                                if (beam.left_line<beam.right_line) {
                                                    if (target_line>beam.right_line) {
                                                        beam.right_line=target_line;
                                                    }
                                                    //beam.right_line+=1;
                                                    beam.left_line=beam.right_line;
                                                }else{
                                                    if (target_line>beam.left_line) {
                                                        beam.left_line=target_line;
                                                    }
                                                    //beam.left_line+=1;
                                                    beam.right_line=beam.left_line;
                                                }
                                                //break;
                                            }
                                        }else{
                                            if (target_line<cur_line && target_line>cur_line-10)
                                            {
                                                if (beam.left_line>beam.right_line) {
                                                    if (target_line<beam.right_line) {
                                                        beam.right_line=target_line;
                                                    }
                                                    //beam.right_line-=1;
                                                    beam.left_line=beam.right_line;//target_line-line-1;
                                                }else{
                                                    if (target_line<beam.left_line) {
                                                        beam.left_line=target_line;
                                                    }
                                                    //beam.left_line-=1;
                                                    beam.right_line=beam.left_line;//target_line-line;
                                                }
                                            }
                                        }
                                    }
                                }else{
                                    if (beam.beam_start_note.stem_up!=note.stem_up) {
                                        int staff_lines = 2*min_staff_distance/LINE_height;
                                        for (int l=0; l<self.lines.count; l++) {
                                            OveLine *line=self.lines[l];
                                            if (measure.number>=line.begin_bar&&measure.number<line.begin_bar+line.bar_count) {
                                                staff_lines=2*line.xml_staff_distance/LINE_height;
                                                break;
                                            }
                                        }
                                        if (beam.staff==1 && beam.stop_staff==2) {
//                                            beam.left_line-=4;
//                                            beam.right_line+=4;
                                            if (beam.right_line>staff_lines+beam.right_line) {
                                                beam.left_line-=4;
                                                beam.right_line+=4;
//                                                beam.right_line=staff_lines+8-beam.right_line;
                                            }
                                        }else {
//                                            beam.left_line+=4;
//                                            beam.right_line-=4;
                                            if (beam.left_line<staff_lines+beam.right_line) {
                                                beam.left_line+=4;
                                                beam.right_line-=4;
//                                                beam.left_line=staff_lines+8+beam.right_line;
                                            }
                                        }
                                    }
                                }
                                
                                beam_elem.stop_measure_pos=i-beam_elem.start_measure_pos;
                                beam_elem.start_measure_pos=0;
                                beam_elem.stop_measure_offset=note.pos.start_offset;
                                beam_elem.xml_beam_number=0;
                            }else{
                                if (beam_elem.xml_beam_number>0) {
                                    not_closed_beamelem++;
                                }
                            }
                        }
                        //check if closed all beams
                        if (not_closed_beamelem==0) {
                            if (xml_have_tuplets) {
                                beam.tupletCount=nn-tuplet_index+1;
                                if (beam.tupletCount<=3) {
                                    beam.tupletCount=3;
                                }else if (beam.tupletCount==6) {
                                    beam.tupletCount=6;
                                }else{
                                    beam.tupletCount=0;
                                }
                            }
                            [openedBeams removeObject:beam];
                            break;
                        }
                    }
                    
                }else {
                    NSLog(@"unknow beam:%@", beam_type);
                }
            }
            note.xml_beams=nil;
        }
        //remove no end beams
        for (int j=0; j<measure.beams.count; j++) {
            OveBeam *beam=measure.beams[j];
            for (BeamElem *elem in beam.beam_elems) {
                if (elem.stop_measure_offset<elem.start_measure_offset) {
                    [beam.beam_elems removeObject:elem];
                    [openedBeams removeAllObjects];
//                    OveBeam *openBeam = openedBeams.firstObject;
//                    if (openBeam) {
//                        [openBeam.beam_elems removeObject:elem];
//                    }
                    break;
                }
            }
        }
    }
    if (openedBeams.count>0) {
        NSLog(@"error, there openedBeams=%ld", (unsigned long)openedBeams.count);
    }
}
- (int)getSlurLine:(OveNote*)note above:(BOOL)above
{
//    int slur_line=(above)?note.line+1:note.line-1;
    int slur_line=note.line;
    if (note.note_elems.count>1) {
        NoteElem *firstElem=note.sorted_note_elems.lastObject;
        NoteElem *lastElem=note.note_elems.firstObject;
        if (firstElem.line>=lastElem.line) {
            if (above) {
                slur_line=firstElem.line+0;
            }else{
                slur_line=lastElem.line-0;
            }
        }else{
            if (above) {
                slur_line=lastElem.line;
            }else{
                slur_line=firstElem.line;
            }
        }
    }
    return slur_line;
}
- (void)processSlursAfter {
    for (OveMeasure *measure in self.measures) {
        for (MeasureSlur *slur in measure.slurs) {
            slur.pos.start_offset=slur.slur_start_note.pos.start_offset;
            slur.offset.stop_offset=slur.slur_stop_note.pos.start_offset;
        }
    }
}

- (void)processSlursPrev{
    //float LINE_height=(self.page_height-self.page_top_margin-self.page_bottom_margin-top_system_distance)/(1024.0*1024.0/768.0) * 10;
    //float LINE_height=(self.page_height)/(1024.0*1024.0/768.0) * 10;

    //process slurss
    NSMutableArray *startedSlurs=[[NSMutableArray alloc]init];
    NSMutableArray *stoppedSlurs=[[NSMutableArray alloc]init];
    for (int i=0; i<self.measures.count; i++) {
        OveMeasure *measure=[self.measures objectAtIndex:i];

        //for (int nn=0; nn<measure.notes.count; nn++) {
            //OveNote *note=[measure.notes objectAtIndex:nn];
        //int slur_start_line_offset=0;
        for (int nn=0; nn<measure.notes.count; nn++) {
            OveNote *note=[measure.notes objectAtIndex:nn];
            int slur_line_offset=7;
            if (note.isGrace) {
                slur_line_offset=4;
            }else if(note.note_type==Note_Whole) {
                slur_line_offset=2;
            }
            int up_line_offset=0,below_line_offset=0;
            
            //slur 连奏: key=number, value=dict[type,placement,default-x,default-y,endnote,]
            for (int bb=0; bb<note.xml_slurs.count; bb++) {
                if (measure.slurs==nil) {
                    measure.slurs=[[NSMutableArray alloc]init];
                }
                NSDictionary *slur_values=[note.xml_slurs objectAtIndex:bb];
                NSString *slur_number=[slur_values objectForKey:@"number"];
                NSString *slur_type=[slur_values objectForKey:@"type"];//start, stop
                NSString *above_string=[slur_values objectForKey:@"placement"];//above, below
                BOOL above = (above_string==nil && !note.isGrace) || [above_string isEqualToString:@"above"];
                int default_y=[[slur_values objectForKey:@"default-y"] intValue];
                default_y=0;
                int slur_line=note.line+default_y/(LINE_height);
                if (default_y==0) {
                    slur_line=[self getSlurLine:note above:above];
                }
                
                if ([slur_type isEqualToString:@"start"]) {
                    if (default_y==0) {
                        if (up_line_offset<0 && bb>1) {
                            above=NO;
                        }
                        if (above) {
                            slur_line+=(note.stem_up)?slur_line_offset:2;
                            slur_line+=up_line_offset;
                            up_line_offset-=2;
                        }else{
                            slur_line-=(note.stem_up)?2:slur_line_offset;
                            slur_line-=below_line_offset;
                            below_line_offset-=2;
                        }
                    }
                    BOOL slur_started=NO;
                    for (MeasureSlur *slur in stoppedSlurs) {
                        if (slur.xml_slur_number == slur_number.intValue/* && slur.staff==note.staff && slur.voice==note.voice*/) {
                            [measure.slurs addObject:slur];
                            slur.slur1_above=above;
                            slur.pair_ends.left_line=slur_line;
                            slur.pair_ends.right_line+=(slur.slur1_above)?2:-2;
                            slur.pos.tick=note.pos.tick;
                            slur.pos.start_offset=note.pos.start_offset;
                            slur.offset.stop_measure=i-slur.offset.stop_measure;
                            slur.staff=note.staff;
                            [stoppedSlurs removeObject:slur];
                            slur_started=YES;
                            break;
                        }
                    }
                    if (!slur_started) {
                        MeasureSlur *slur=[[MeasureSlur alloc]init];
                        [measure.slurs addObject:slur];
                        [startedSlurs addObject:slur];
                        
                        slur.slur_start_note=note;
                        slur.xml_slur_number=[slur_number intValue];
                        slur.staff=note.staff;
                        slur.voice=note.voice;
                        slur.slur1_above=above;
                        slur.pos=[[CommonBlock alloc]init];
                        slur.pos.tick=note.pos.tick;
                        slur.pos.start_offset=note.pos.start_offset;
                        slur.pair_ends=[[PairEnds alloc]init];
                        slur.pair_ends.left_line=slur_line;
                        if (note.isGrace) {
                            slur.pair_ends.right_line=slur_line;
                        }else{
                            slur.pair_ends.right_line=100;
                        }
                        slur.offset=[[OffsetCommonBlock alloc]init];
                        slur.offset.stop_measure=i;
                    }
                }else if([slur_type isEqualToString:@"stop"])
                {
                    BOOL slur_stopped=NO;
                    for (MeasureSlur *slur in startedSlurs) {
                        if (slur.xml_slur_number == slur_number.intValue/* && slur.staff==note.staff && slur.voice==note.voice*/) {
                            if (slur.pair_ends.right_line==100) {
                                if (slur.slur_start_note.isGrace) {
                                    slur_line=slur.pair_ends.left_line;
                                }else if (default_y==0) {
                                    slur_line=[self getSlurLine:note above:slur.slur1_above];
                                    if (slur.slur1_above) {
                                        slur_line+=((note.stem_up)?slur_line_offset:2);
                                        if (note.stem_up && note.inBeam) {
                                            slur_line+=2;
                                        }
                                        
                                        slur_line+=up_line_offset;
                                        up_line_offset-=2;
                                    }else{
                                        slur_line-=((note.stem_up)?2:slur_line_offset);
                                        if (!note.stem_up && note.inBeam) {
                                            slur_line-=2;
                                        }
                                        
                                        slur_line-=below_line_offset;
                                        below_line_offset-=2;
                                    }
                                }
                                slur.pair_ends.right_line=slur_line;
                            }
                            slur.slur_stop_note=note;
                            slur.stop_staff=note.staff;
                            
                            OveMeasure *start_measure=self.measures[slur.offset.stop_measure];
                            if (i>slur.offset.stop_measure && measure.numerics&&start_measure.numerics) {
                                //slur should not over endings 连音线不能跨越房子。
                                [start_measure.slurs removeObject:slur];
                                if (measure.slurs==nil) {
                                    measure.slurs=[NSMutableArray new];
                                }
                                [measure.slurs addObject:slur];
                                slur.offset.stop_measure=0;
                                slur.slur_start_note=nil;
                                slur.pos.tick=0;
                                slur.pos.start_offset=0;
                            }else{
                                slur.offset.stop_measure=i-slur.offset.stop_measure;
                            }
                            slur.offset.stop_offset=note.pos.start_offset;
                            
                            [startedSlurs removeObject:slur];
                            slur_stopped=YES;
                            break;
                        }
                    }
                    if (!slur_stopped)
                    {
                        MeasureSlur *slur=[[MeasureSlur alloc]init];
                        [stoppedSlurs addObject:slur];
                        
                        slur.slur_stop_note=note;
                        slur.xml_slur_number=[slur_number intValue];
                        slur.stop_staff=note.staff;
                        slur.voice=note.voice;
                        slur.pos=[[CommonBlock alloc]init];
                        slur.pos.tick=note.pos.tick;
                        slur.pos.start_offset=note.pos.start_offset;
                        slur.pair_ends=[[PairEnds alloc]init];
                        slur.pair_ends.right_line=slur_line;
                        slur.offset=[[OffsetCommonBlock alloc]init];
                        slur.offset.stop_measure=i;
                        slur.offset.stop_offset=note.pos.start_offset;
                        
                        NSLog(@"slur stop before start");
                    }
                }
            }
            note.xml_slurs=nil;
        }
    }

    if (startedSlurs.count>0) {
        NSLog(@"error, it should no stardedSlurs=%ld", (unsigned long)startedSlurs.count);
        for (MeasureSlur *slur in startedSlurs) {
            slur.pair_ends.right_line=slur.pair_ends.left_line;
            slur.offset.stop_measure=0;//i-slur.offset.stop_measure;
            slur.offset.stop_offset=slur.pos.start_offset;
            slur.stop_staff=slur.staff;
        }
    }
    if (stoppedSlurs.count>0) {
        NSLog(@"error, it should no stoppedSlurs=%ld", (unsigned long)stoppedSlurs.count);
        for (MeasureSlur *slur in stoppedSlurs) {
            slur.pair_ends.left_line=slur.pair_ends.right_line;
            slur.offset.stop_measure=0;//i-slur.offset.stop_measure;
            slur.staff=slur.stop_staff;
        }
    }
}

- (void)processTies{
    //float LINE_height=(self.page_height-self.page_top_margin-self.page_bottom_margin-top_system_distance)/(1024.0*1024.0/768.0) * 10;
    
    //process ties
    NSMutableArray *openedTies=[[NSMutableArray alloc]init];
    for (int i=0; i<self.max_measures; i++) {
        OveMeasure *measure=[self.measures objectAtIndex:i];
        
        //for (int nn=0; nn<measure.notes.count; nn++) {
        //OveNote *note=[measure.notes objectAtIndex:nn];
        for (int nn=0; nn<measure.notes.count; nn++) {
            OveNote *note=[measure.notes objectAtIndex:nn];
            for (int ee=0; ee<note.note_elems.count; ee++) {
                NoteElem *elem=[note.note_elems objectAtIndex:ee];
                //tie 连奏: key=number, value=dict[type,placement,default-x,default-y,endnote,]
                for (int bb=0; bb<elem.xml_ties.count; bb++) {
                    if (measure.ties==nil) {
                        measure.ties=[[NSMutableArray alloc]init];
                    }
                    NSDictionary *dict=[elem.xml_ties objectAtIndex:bb];
                    NSString *number=[dict objectForKey:@"number"];
                    NSString *tie_type=[dict objectForKey:@"type"]; //start, stop
                    NSString *orientation=[dict objectForKey:@"orientation"]; //under, over
                    BOOL above=(orientation==nil)||[orientation isEqualToString:@"over"];
                    if (note.note_elems.count>1) {
                        above=(ee>0);
                    }
                    if (note.note_type>Note_Whole && note.note_elems.count==1) {
                        //check if there are more than one voice
                        BOOL onlyOneVoice=YES;
                        for (OveNote *otherNote in measure.notes) {
                            if (otherNote.staff==note.staff && otherNote.voice != note.voice) {
                                onlyOneVoice=NO;
                                break;
                            }
                        }
                        if (onlyOneVoice) {
                            above=!note.stem_up;
                        }else{
                            if (note.voice==1 || note.voice==3) {
                                above=YES;
                            }else{
                                above=NO;
                            }
                        }
                    }
                    //BOOL above = (above_string==nil) || [above_string isEqualToString:@"above"];
                    //int default_y=[[slur_values objectForKey:@"default-y"] intValue];
                    
                    if ([tie_type isEqualToString:@"start"]) {
                        MeasureTie *tie=[[MeasureTie alloc]init];
                        [measure.ties addObject:tie];
                        [openedTies addObject:tie];
                        
                        tie.above=above;
                        tie.xml_tie_number=[number intValue];
                        tie.xml_note_value=elem.note;
//                        tie.xml_start_elem=elem;
//                        tie.xml_beloneto_measure=measure;
                        tie.xml_start_measure_index=i;
                        tie.xml_start_note_index=nn;
                        tie.xml_start_elem_index=ee;
                        tie.staff=note.staff;
                        tie.pos=[[CommonBlock alloc]init];
                        tie.pos.tick=note.pos.tick;
                        tie.pos.start_offset=note.pos.start_offset;
                        tie.pair_ends=[[PairEnds alloc]init];
                        tie.pair_ends.left_line=elem.line;
                        tie.pair_ends.right_line=tie.pair_ends.left_line;
                        tie.offset=[[OffsetCommonBlock alloc]init];
                        tie.offset.stop_measure=i;
                        
                    }else if([tie_type isEqualToString:@"stop"])
                    {
                        if (openedTies.count>0) {
                            BOOL closed=NO;
                            for (int tt=(int)openedTies.count-1;tt>=0;tt--) {
                                MeasureTie *tie = openedTies[tt];
                                if (tie.xml_tie_number==number.intValue && tie.xml_note_value==elem.note && tie.staff==note.staff) {
                                    tie.offset.stop_measure=i-tie.offset.stop_measure;
                                    tie.offset.stop_offset=note.pos.start_offset;
                                    tie.stop_staff=note.staff;
                                    //tie.xml_start_elem.length_tick+=elem.length_tick;
                                    [openedTies removeObject:tie];
                                    closed=YES;
                                    break;
                                }
                            }
                            if (!closed) {
                                NSLog(@"error, can not find tie start for stop tie");
                            }
                        }else{
                            NSLog(@"error, There is no start tie for stop tie");
                        }
                    }
                }
                elem.xml_ties=nil;
            }
        }
    }
    if (openedTies.count>0) {
//        NSLog(@"error, it should no openedTies=%ld", (unsigned long)openedTies.count);
        for (MeasureTie *tie in openedTies) {
//            tie.offset.stop_measure=0;//i-tie.offset.stop_measure;
//            tie.offset.stop_offset=tie.pos.start_offset;
//            tie.stop_staff=tie.staff;
            OveMeasure *measure=self.measures[tie.xml_start_measure_index];
            OveNote *note=measure.notes[tie.xml_start_note_index];
            NoteElem *elem=note.note_elems[tie.xml_start_elem_index];
            BOOL paired=NO;
            for (int i=tie.xml_start_note_index+1; i<measure.notes.count && !paired; i++) {
                OveNote *nextNote=measure.notes[i];
                if (note.staff==nextNote.staff) {
                    for (NoteElem* nextElem in nextNote.note_elems) {
                        if (elem.note==nextElem.note) {
                            tie.offset.stop_measure=0;
                            tie.offset.stop_offset=nextNote.pos.start_offset;
                            tie.stop_staff=note.staff;
                            nextElem.tie_pos=Tie_RightEnd;
                            paired=YES;
                            break;
                        }
                    }
                }
            }
//            NoteElem *elem=tie.xml_start_elem;
            if (!paired) {
                NSLog(@"error, the tie should no start at measure:%d nn:%d", tie.xml_start_measure_index, tie.xml_start_note_index);
                elem.tie_pos=Tie_None;
                [measure.ties removeObject:tie];
            }
        }
    }
}



-(int) NoteTypeToTick:(NoteType) note_type tempo:(int) tempo  doted:(int)doted
{
#if 0
    int c = (int)(pow(2.0, (int)note_type)) ;
    return quarter * 4 * 2 / c ;
#else
    int ticks=480;//ticksPerTempo;
    if(note_type==Note_Whole) {
        ticks*=4;
    }else if(note_type==Note_Half) {
        ticks*=2;
    }else if (note_type==Note_Eight) {
        ticks/=2;
    }else if(note_type==Note_Sixteen) {
        ticks/=4;
    }else if(note_type==Note_32) {
        ticks/=8;
    }else if(note_type==Note_64) {
        ticks/=16;
    }else if(note_type==Note_128) {
        ticks/=32;
    }else if(note_type==Note_256) {
        ticks/=64;
    }
    if (doted==1) {
        ticks*=1.5;
    }else if (doted==2)
    {
        ticks*=1.75;
    }
    return ticks;
#endif
}

- (void)addNoteTick:(int)note_start_tick toMeasureInfo:(NSMutableDictionary*)measureInfo {
    NSMutableArray *note_ticks=measureInfo[@"note_ticks"];
    if (note_ticks==nil) {
        note_ticks=[NSMutableArray new];
        measureInfo[@"note_ticks"]=note_ticks;
    }
    [note_ticks addObject:@(note_start_tick)];
}

//- (void)addNoteEventIndex:(int)event_index toMeasureInfo:(NSMutableDictionary*)measureInfo {
//    NSMutableArray *note_ticks=measureInfo[@"note_event_indexs"];
//    if (note_ticks==nil) {
//        note_ticks=[NSMutableArray new];
//        measureInfo[@"note_event_indexs"]=note_ticks;
//    }
//    [note_ticks addObject:@(event_index)];
//}

- (void)getUpper1:(int*)upper lower:(int*)lower forNote:(int)note fifths:(int)fifths {
    int step=note%12;
    //int oct=firstElem.note/12;
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
     */
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
    unsigned char *scales=scales_map[fifths+7];
    int upper_note=2;// firstElem.note+2;
    int below_note=-2;//firstElem.note-2;
    for (int v=0; v<7; v++) {
        if (step==scales[v]) { //step:0..11
            upper_note= scales[v+1]-step;
            break;
        }else if (step<scales[v]) {
            upper_note=scales[v]-step; //oct*12+scales[v];
            break;
        }
    }
    for (int v=0; v<7; v++) {
        if (step==scales[v]) {
            below_note=(scales[(6+v)%7]-step-12)%12;
            break;
        }else if (step<scales[v]) {
            if (v==0){
                below_note=scales[6]-step-12;// //oct*12+scales[(v+6)%7];
            }else{
                below_note=scales[v-1]-step;// //oct*12+scales[(v+6)%7];
            }
            break;
        }
    }
    *upper=upper_note;
    *lower=below_note;
}

- (void)getUpper:(int*)upper lower:(int*)lower forNoteElem:(NoteElem*)elem fifths:(int)fifths accidental:(AccidentalType)accidental_mark {
    
    //art.accidental_mark==Accidental_Natural
    
    int upper_step=elem.xml_pitch_step+1;
    int upper_octave=elem.xml_pitch_octave;
    int upper_alter=0;//elem.xml_pitch_alter;
    if (upper_step>7) {
        upper_step=1;
        upper_octave++;
    }
    
    int below_step=elem.xml_pitch_step-1;
    int below_octave=elem.xml_pitch_octave;
    int below_alter=0;//elem.xml_pitch_alter;
    if (below_step<1) {
        below_step=7;
        below_octave--;
    }
    
    if (accidental_mark==Accidental_Sharp) {
        below_alter=1;
        upper_alter=1;
    }else if (accidental_mark==Accidental_Flat) {
        below_alter=-1;
        upper_alter=-1;
    }if (accidental_mark==Accidental_Normal) {
        char minusFifths[8]={0,7,3,6,2,5,1,4};//bB,bE,bA,bD,bG,bC,bF
        if (fifths<0) {
            for (int i=1; i<-fifths+1; i++) {
                if (minusFifths[i]==below_step) {
                    below_alter=-1;
                }
                if (minusFifths[i]==upper_step) {
                    upper_alter=-1;
                }
            }
        }else if (fifths>0) {
            for (int i=7; i>7-fifths; i--) {
                if (minusFifths[i]==below_step) {
                    below_alter=1;
                }
                if (minusFifths[i]==upper_step) {
                    upper_alter=1;
                }
            }
        }
    }
    
    int upper_note=[self noteValueForStep:upper_step octave:upper_octave alter:upper_alter];
    int below_note=[self noteValueForStep:below_step octave:below_octave alter:below_alter];
    
    *upper=upper_note-elem.note;
    *lower=below_note-elem.note;
    if (*upper>2) {
        *upper=2;
    }
    if (*lower<-2) {
        *lower=-2;
    }
    
    //int step=note%12;
    
    //int oct=firstElem.note/12;
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

- (NoteArticulation*)changedArticulationOfNote:(OveNote*)note{
    if (note.note_elems.count>0 && note.note_arts.count>0) {
        for (NoteArticulation *art in note.note_arts) {
            if ((art.art_type>=Articulation_Major_Trill && art.art_type<=Articulation_Turn) ||
                (art.art_type>=Articulation_Tremolo_Eighth && art.art_type<=Articulation_Tremolo_Sixty_Fourth)
                ) {
                return art;
            }
        }
    }
    return nil;
}

//return array of note values [@() ...]
//startNote:-1:低一度 0:本音 1:高一度
- (int)tappedNoteElems:(signed char*)values note:(OveNote*)note art:(NoteArticulation*)art below_note:(int)below_note upper_note:(int)upper_note {
    int values_count=0;
    if (art.art_type>=Articulation_Major_Trill && art.art_type<=Articulation_Turn) {
        NoteElem *lastElem=note.note_elems.lastObject;
        
        values[0]=lastElem.note;
        if (art.art_type==Articulation_Short_Mordent) {
            //短波音，本位音－低1度音－本位音
            values_count=3;
            values[1]=lastElem.note+below_note;
            values[2]=lastElem.note;
            
        }else if (art.art_type==Articulation_Inverted_Short_Mordent) {
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
            values_count=3;
            values[1]=lastElem.note+upper_note;
            values[2]=lastElem.note;
            
        }else if (art.art_type==Articulation_Major_Trill || art.art_type==Articulation_Minor_Trill){
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
             颤音演奏数目一般没有规律，主要的准则就是得听起来非常快。这首乐曲速度相对较慢。如果乐曲速度很慢，那一个全音符就无法按照32分音符，弹32次来衡量，因为这样衡量就会使得颤音太慢。同样的，如果乐曲速度很快，那一个全音符也无法按32音符来衡量，因为32分音符就会使得颤音太快。颤音的速度相对有一个比较清晰的标准，就是很快。具体在数字上就是大约一秒钟出来5~8个音，但是数目上来说却是自由的。一个全音符根据曲目速度不同可能会颤音许多不规律的音符，基本不会出现32次，64次或者16次此类太过于规律的情况。
             */
            //if (art.trill_num_of_32nd>8) {
            //  tick_range=480*(2+art.trill_num_of_32nd/4);
            //}
            values_count=art.trill_num_of_32nd;
            
            for (int c=0; c<values_count*2; c++) {
                if (c%2==1) {
                    values[c]=lastElem.note+upper_note;
                }else{
                    values[c]=lastElem.note;
                }
            }
            
        }else if(art.art_type==Articulation_Turn){
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
            values_count=5;
            values[1]=lastElem.note+upper_note;//firstElem.note+2;
            values[2]=lastElem.note;
            values[3]=lastElem.note+below_note;//firstElem.note-1;
            values[4]=lastElem.note;
        }else{
            NSLog(@"TODO: for articulation %d",art.art_type);
        }
    }else if(art.art_type>=Articulation_Tremolo_Eighth && art.art_type<=Articulation_Tremolo_Sixty_Fourth) {
        int numberOf64th=1;
        if (art.art_type==Articulation_Tremolo_Eighth) {
            numberOf64th=8;
        }else if (art.art_type==Articulation_Tremolo_Sixteenth) {
            numberOf64th=4;
        }else if (art.art_type==Articulation_Tremolo_Thirty_Second) {
            numberOf64th=2;
        }
        int totalOf64th=16;
        if (note.note_type==Note_Whole) {
            totalOf64th=64;
        }else if (note.note_type==Note_Half) {
            totalOf64th=32;
        }else if (note.note_type==Note_Quarter) {
            totalOf64th=16;
        }
        if (note.isDot) {
            totalOf64th*=1.5;
        }
        values_count=totalOf64th/numberOf64th;
        NoteElem *lastElem=note.note_elems.lastObject;
        if (note.note_elems.count==1) {
            for (int i=0; i<totalOf64th; i++) {
                values[i]=lastElem.note;
            }
        }else{
            NoteElem *firstElem=note.note_elems.firstObject;
            for (int i=0; i<totalOf64th/2; i++) {
                values[2*i]=firstElem.note;
                values[2*i+1]=lastElem.note;
            }
        }
    }
    return values_count;
}

- (void)setEventUserdata:(Event*)event from:(int)tt midiEvents:(NSArray*)midiEvents channel:(int)channel mm:(int)mm nn:(int)nn i_notes:(int)i_notes ee:(int)ee elem:(NoteElem*)elem measure:(OveMeasure*)measure note:(OveNote*)note meas_start_tick:(int)meas_start_tick trill:(BOOL)trill videoMidi:(BOOL)videoMidi midiFile:(MidiFile*)midiFile {
    //find this note's stop event
    int note_duration=0;
    for (int next=tt; next<midiEvents.count; next++) {
        Event *nextEvent=midiEvents[next];
        unsigned char nextEvt=nextEvent.evt&0xf0;
        unsigned char nextChannel=nextEvent.evt&0x0f;
        if ((nextEvt==0x80 || (nextEvt==0x90 && nextEvent.vv==0)) && nextEvent.nn==event.nn && channel==nextChannel) {
            note_duration=nextEvent.tick-event.tick;
            break;
        }
    }
    if (note_duration==0) {
        NSLog(@"Error: can not find note's stop event in midi %d,%d,%d,%d,%d",mm,nn,i_notes,ee,elem.note);
    }
    
    if (videoMidi) { //video midi use normal midi's track info
        event.track=(elem.rightHand)?0:1;
    }else{
        if (midiFile.onlyOneTrack) {
            event.track=note.staff-1;
        }
        elem.rightHand=(event.track==0); //save track info to xml for video mode
    }
    
    //finger
    int finger=0;
    if (elem.xml_finger) {
        finger=[elem.xml_finger intValue];
        if (trill) {
            if (finger<5 &&
                ((event.nn>elem.note && event.track==0) ||
                (event.nn<elem.note && event.track==1))) {
                finger+=1;
            }else if (finger>0 &&
                      ((event.nn<elem.note && event.track==0) ||
                      (event.nn>elem.note && event.track==1))) {
                finger-=1;
            }
        }
    }
    //get oveline
    int oveline=-1;
    for (int i=0; i<self.lines.count; i++) {
        OveLine *line=self.lines[i];
        if (mm>=line.begin_bar && mm<line.begin_bar+line.bar_count) {
            oveline=i;
            break;
        }
    }
    
    //set elem_id
    int index_in_notes=0;
    for (; index_in_notes<measure.notes.count; index_in_notes++) {
        if (measure.notes[index_in_notes]==note) {
            break;
        }
    }
    NSString *elem_id=[NSString stringWithFormat:@"%d_%d_%d",mm,index_in_notes,ee];
    event.userdata=[NSMutableDictionary dictionaryWithDictionary:@{@"mm":@(mm),
                                                                   @"nn":@(nn),
                                                                   @"ii":@(i_notes),
                                                                   @"ee":@(ee),
                                                                   @"staff":@(note.staff),
                                                                   //@"track":@(event.track),
                                                                   @"duration":@(note_duration),
                                                                   @"line":@(elem.line),
                                                                   @"type":@(note.note_type),
                                                                   @"finger":@(finger),
                                                                   @"trill":@(trill),
                                                                   @"meas_start_tick":@(meas_start_tick),
                                                                   @"elem_id":elem_id,
                                                                   @"oveline":@(oveline)
                                                                   }];
}
- (void)checkMidiSequence:(MidiFile*)midiFile videoMidi:(BOOL)videoMidi{
    
#if 0
    [self testGetNoteNeibour];
#endif
    
    NSArray *midiEvents=midiFile.mergedMidiEvents;
    NSArray* timeSignatures=midiFile.timeSignatures;
    int ticksPerQuarter=midiFile.quarter;
    midiFile.midiMeasureInfo=[NSMutableDictionary new];
    
    int midi_index=0;
    //    Event *event=midiEvents.firstObject;
    //    cur_tick=event.tick;
    
    long size=sizeof(BOOL)*midiEvents.count;
    BOOL *eventFlags=malloc(size);
    memset(eventFlags, 0, size);
    
    MeasureToTick *mtt_;
    
    mtt_=[[MeasureToTick alloc]init];
    mtt_.checkIsRepeatPlay=videoMidi;
    [mtt_ build:self quarter:ticksPerQuarter];
    NSArray *segments_ = mtt_.segments;
    
    //unsigned int measure_stamp=0, timestamp=0;
    int numerator=4,denominator=4;
    TimeSignatureEvent *se=timeSignatures.firstObject;
    if (se) {
        numerator=se.numerator;
        denominator=se.denominator;
    }
    
    int meas_start_tick=0;
    int cur_event_tick=-1, next_event_tick=-1;
    int cur_event_index=0;
    for (int k=0;k<segments_.count; k++) {
        Segment *segment=segments_[k];
        int beginMeasure = segment.measure;
        int endMeasure = segment.measure + segment.measureCount;
        
        for (int mm = beginMeasure; mm < endMeasure && mm<self.measures.count; ++mm) {
            OveMeasure *measure=[self.measures objectAtIndex:mm];
            NSArray *sorted_duration_offset=measure.sorted_duration_offset;
            BOOL got_meas_start_tick=NO;
            int rest_ticks=0;
            NSMutableDictionary *measureInfo=[NSMutableDictionary new];
            [measureInfo setObject:@(mm) forKey:@"mm"];
            
            for (int nn=0;nn<sorted_duration_offset.count;nn++) {
                int note_start_tick=0;
                BOOL got_note_start_tick=NO;
                NSString *key = [sorted_duration_offset objectAtIndex:nn];
                //timestamp=measure_stamp+key.intValue*ticksPerQuarter/480;
                //NSLog(@"%d:%d:%d",mm,play_cur_note, timestamp);
//                if (next_event_tick>=0 && cur_event_tick>=0) {
//                    if (nn<sorted_duration_offset.count-1) {
//                        NSString *nextKey=sorted_duration_offset[nn+1];
//                        next_event_tick=cur_event_tick+[nextKey intValue]-[key intValue];
//                    }else{
//                        next_event_tick=cur_event_tick+measure.meas_length_tick-[key intValue];
//                    }
//                }
                
                int elem_count=0;
                NSMutableArray *notes=[measure.sorted_notes objectForKey:key];
                if (notes.count>0) {
                    BOOL allRest=YES;
                    NoteType minRestType=0;
                    for (OveNote* n in notes) {
                        if (!n.isRest) {
                            allRest=NO;
                        }
                        if (n.note_type>minRestType) {
                            minRestType=n.note_type;
                        }
                    }
//                    OveNote *note=notes.firstObject;
                    
                    if (allRest && minRestType<Note_256) {
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
                         Note_256		= 0x9,*/
                        int bats[]={480*8,480*4,480*2,480,480/2,480/4,480/8,480/16,480/32};
                        rest_ticks=bats[minRestType];

                        if (next_event_tick>=0) {
                            [self addNoteTick:next_event_tick toMeasureInfo:measureInfo];
                        }
                        continue;
                    }
                }
                for (int i_notes=0;i_notes<notes.count;i_notes++) {
                    OveNote *note = [notes objectAtIndex:i_notes];
                    elem_count+=note.note_elems.count;
                    //Articulation_Inverted_Short_Mordent
                    //BOOL hasSeperateNotes=NO;
                    //BOOL seperateNoteType=0;
#define TICK_RANGE (480*2)
                    int tick_range=TICK_RANGE;
                    int upper_note=2,below_note=2;
#define MAX_NOTE_ELEMS  512
                    signed char values[MAX_NOTE_ELEMS];
                    int values_count=0;

                    NSArray *note_elems=note.note_elems;
                    NoteArticulation *art=[self changedArticulationOfNote:note];
                    NoteElem *lastElem=note.note_elems.lastObject;
                    if (art) {
                        //int step=lastElem.note%12;
                        if (art.accidental_mark==Accidental_Natural) {
                            [self getUpper:&upper_note lower:&below_note forNoteElem:lastElem fifths:0 accidental:Accidental_Normal];
                        }else{
                            [self getUpper:&upper_note lower:&below_note forNoteElem:lastElem fifths:measure.fifths accidental:art.accidental_mark];
                        }
                        values_count=[self tappedNoteElems:values note:note art:art below_note:below_note upper_note:upper_note];
                        if (values_count>8) {
                            tick_range=480*(0.25+values_count/8);
                        }
                        if (videoMidi) {
                            BOOL hasFermata=NO;
                            for (NoteArticulation *noteArt in note.note_arts) {
                                if (noteArt.art_type==Articulation_Fermata || noteArt.art_type==Articulation_Fermata_Inverted) {
                                    hasFermata=YES;
                                    break;
                                }
                            }
                            if (hasFermata) {
                                tick_range+=80;
                            }
                        }
                        
                        if (art.art_type==Articulation_Major_Trill && nn<sorted_duration_offset.count-1) {
                            //看颤音是否有小音符结尾
                            for (int nextIndex=0; nextIndex<measure.notes.count-1; nextIndex++) {
                                if (measure.notes[nextIndex]==note) {
                                    for (int nextN=nextIndex+1; nextN<measure.notes.count; nextN++) {
                                        OveNote *nextNote=measure.notes[nextN];
                                        if (nextNote.isGrace && nextNote.staff==note.staff) {
                                            values_count--;
                                        }else{
                                            break;
                                        }
                                    }
                                    break;
                                }
                            }
                        }
                        
                        if (values_count>0) {
                            int trill_start_tick=0;
                            int trill_stop_tick=0;
                            for (int ee=0; ee<values_count; ee++) {
                                for (int tt=midi_index; tt<midiEvents.count; tt++){
                                    if (eventFlags[tt]) {
                                        continue;
                                    }
                                    Event *event=midiEvents[tt];
                                    unsigned char evt=event.evt&0xf0;
                                    unsigned char channel=event.evt&0x0f;
                                    if (evt==0x90 && event.vv>0){ //start note
                                        if (art.art_type==Articulation_Major_Trill && ee>0) {
                                            if (event.tick>=trill_stop_tick) {
                                                values_count=0;
                                                break;
                                            }
                                        }
                                        
                                        BOOL found=(event.nn==values[ee]);
                                        if (!found && ee==0) {
                                            if (art.art_type==Articulation_Major_Trill) {
                                                if (event.nn==values[0]+below_note || event.nn==values[0]+upper_note) {
                                                    found=YES;
                                                    for (int temp=1; temp<values_count; temp++) {
                                                        if (temp%2==1) {
                                                            values[temp]=lastElem.note;
                                                        }else{
                                                            values[temp]=lastElem.note+upper_note;
                                                        }
                                                    }
                                                }
                                            }else if (art.art_type==Articulation_Inverted_Short_Mordent) {
                                                //高1度音-本位音－高1度音－本位音
                                                if (event.nn==values[0]+upper_note) {
                                                    found=YES;
                                                    values_count=4;
                                                    for (int temp=1; temp<values_count; temp++) {
                                                        if (temp%2==1) {
                                                            values[temp]=lastElem.note;
                                                        }else{
                                                            values[temp]=lastElem.note+upper_note;
                                                        }
                                                    }
                                                }
                                            }
                                            //
                                        }
                                        
                                        if (found){
                                            if (ee==0 && art.art_type==Articulation_Major_Trill) {
                                                trill_start_tick=event.tick;
                                                trill_stop_tick=trill_start_tick+ 480/8*values_count+120;
                                                values_count*=2;
                                            }
                                            
                                            
                                            eventFlags[tt]=YES;
                                            //if (ee==0)
                                            {
                                                if (!got_note_start_tick) {
                                                    note_start_tick=event.tick;
                                                    got_note_start_tick=YES;
                                                    
                                                    [self addNoteTick:note_start_tick toMeasureInfo:measureInfo];
//                                                    [self addNoteEventIndex:tt toMeasureInfo:measureInfo];
                                                    
                                                    if (!got_meas_start_tick) {
                                                        
                                                        meas_start_tick=event.tick;
                                                        NSLog(@"measure0(%d): %d", measure.number, meas_start_tick);
                                                        if (rest_ticks>0) {
                                                            meas_start_tick-=rest_ticks;
                                                        }
                                                        got_meas_start_tick=YES;
                                                        [midiFile.midiMeasureInfo setObject:measureInfo forKey:@(meas_start_tick)];
                                                        //NSLog(@"(%d):%d", mm, meas_start_tick);
                                                    }
                                                    if (rest_ticks>0) {
                                                        rest_ticks=0;
                                                    }
                                                }
                                                
                                                [self setEventUserdata:event from:tt midiEvents:midiEvents channel:channel mm:mm nn:nn i_notes:i_notes ee:ee elem:lastElem measure:measure note:note meas_start_tick:meas_start_tick trill:ee>0 videoMidi:videoMidi midiFile:midiFile];
                                                if (ee==0 && art.art_type==Articulation_Major_Trill) {
                                                    [event.userdata setObject:@(480/8*values_count/2) forKey:@"duration"];
                                                }
                                            }
                                            break;
                                        }else{
                                            if (next_event_tick>=0 && event.tick-next_event_tick>tick_range) {
                                                //eventFlags[tt]=YES;
                                                NSLog(@"Error, trill Event(%d) tick:%d,should closed to %d. in %d %d note:%d", tt, event.tick, next_event_tick,mm,nn, lastElem.note);
                                                //midi_index++;
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                            NSMutableArray *elems=[NSMutableArray arrayWithArray:note.note_elems];
                            [elems removeLastObject];
                            note_elems=elems;
                        }
                    }else{
//                        note_elems=note.note_elems;
                    }
                    
                    //int duration=[self NoteTypeToTick:note.note_type tempo:ticksPerTempo doted:note.isDot];
                    for (int ee=0;ee<note_elems.count;ee++) {
                        NoteElem *elem = note_elems[ee];
                        if (elem.tie_pos&Tie_RightEnd || elem.dontPlay) {
                            if (elem.tie_pos&Tie_RightEnd) {
                                if (!got_meas_start_tick && next_event_tick>=0) {
                                    [self addNoteTick:next_event_tick toMeasureInfo:measureInfo];
//                                    [self addNoteEventIndex:midi_index toMeasureInfo:measureInfo];
                                    got_meas_start_tick=YES;
                                    got_note_start_tick=YES;
                                    meas_start_tick=next_event_tick;
                                    //NSLog(@"measure1(%d): %d", measure.number, meas_start_tick);

                                    [midiFile.midiMeasureInfo setObject:measureInfo forKey:@(meas_start_tick)];
                                }
                            }
                            continue;
                        }
                        
                        int skipped_midi_event=0;
                        BOOL found_untracked_event=NO;
                        for (int tt=midi_index; tt<midiEvents.count; tt++) {
                            if (eventFlags[tt]) {
                                continue;
                            }
                            Event *event=midiEvents[tt];
                            unsigned char evt=event.evt&0xf0;
                            unsigned char channel=event.evt&0x0f;
                            if (evt==0x90 && event.vv>0){ //start note
                                if (event.nn==elem.note) {
                                    eventFlags[tt]=YES;//event.userdata=TRUE;
                                    if (!got_note_start_tick) {
                                        note_start_tick=event.tick;
                                        got_note_start_tick=YES;
                                        
                                        [self addNoteTick:note_start_tick toMeasureInfo:measureInfo];
//                                        [self addNoteEventIndex:tt toMeasureInfo:measureInfo];
                                        
                                        if (!got_meas_start_tick) {
                                            
                                            meas_start_tick=event.tick;
                                            if (rest_ticks>0) {
                                                meas_start_tick-=rest_ticks;
                                            }
                                            got_meas_start_tick=YES;
                                            //NSLog(@"measure2(%d): %d", measure.number, meas_start_tick);
                                            [midiFile.midiMeasureInfo setObject:measureInfo forKey:@(meas_start_tick)];
                                            //NSLog(@"(%d):%d", mm, meas_start_tick);
                                        }
                                        if (rest_ticks>0) {
                                            rest_ticks=0;
                                        }
                                    }
                                    
                                    [self setEventUserdata:event from:tt midiEvents:midiEvents channel:channel mm:mm nn:nn i_notes:i_notes ee:ee elem:elem measure:measure note:note meas_start_tick:meas_start_tick trill:NO videoMidi:videoMidi midiFile:midiFile];
//                                    if (videoMidi) { //video midi use normal midi's track info
//                                        event.track=(elem.rightHand)?0:1;
//                                    }else{
//                                        elem.rightHand=(event.track==0); //save track info to xml for video mode
//                                    }
                                    //NSLog(@"seq(%d) %d:%d,%d,%d,%d,%d",tt,event.tick,mm,nn,i_notes,ee,elem.note);
                                    //NSLog(@"seq(%d) %d(%x):%d,%d,%d,%d,%d",tt,event.tick,event.evt,mm,nn,i_notes,ee,elem.note);
                                    //midi_index=tt;
                                    if (!found_untracked_event) {
                                        midi_index=tt+1;
                                    }else{
                                        Event *untracked_event=midiEvents[midi_index];
                                        int delta=event.tick-untracked_event.tick;
                                        if (delta>tick_range) {
                                            //NSLog(@"can't find note in midi %d,%d",mm,nn);
                                            NSLog(@"Error, too ealier event(%d)(%d-%d=%d*480),should be ignored. in %d %d", midi_index, untracked_event.tick, event.tick,delta/480,mm,nn);
                                            if (tick_range==TICK_RANGE) {
                                                midi_index++;
                                            }
                                        }
                                    }
                                    cur_event_index=tt;
                                    if (cur_event_tick<event.tick) {
                                        cur_event_tick=event.tick;
                                        int plusTick=0;
                                        for (int nextMm=mm; nextMm<self.measures.count && nextMm<endMeasure; nextMm++) {
                                            OveMeasure *nextMeasure=self.measures[nextMm];
                                            int nextNn;
                                            int start_tick,stop_tick;
                                            if (nextMm==mm) {
                                                nextNn=nn+1;
                                                start_tick=[key intValue];
                                                //stop_tick=[key intValue];
                                            }else{
                                                nextNn=0;
                                                start_tick=0;
                                            }
                                            stop_tick=start_tick;
                                            BOOL foundStopNote=NO;
                                            for (; nextNn<nextMeasure.sorted_duration_offset.count; nextNn++) {
                                                NSString *nextKey=nextMeasure.sorted_duration_offset[nextNn];
                                                NSArray *nextNotes=nextMeasure.sorted_notes[nextKey];
                                                for (OveNote *nextNote in nextNotes) {
                                                    if (!nextNote.isRest) {
                                                        for (NoteElem *elem in nextNote.note_elems) {
                                                            if (!(elem.tie_pos&Tie_RightEnd)) {
                                                                foundStopNote=YES;
                                                                break;
                                                            }
                                                        }
                                                        if (foundStopNote) {
                                                            break;
                                                        }
//                                                        foundStopNote=YES;
//                                                        break;
                                                    }
                                                }
                                                if (foundStopNote) {
                                                    stop_tick=nextKey.intValue;
                                                    break;
                                                }
                                            }
                                            if (foundStopNote) {
                                                plusTick+=stop_tick-start_tick;
                                                break;
                                            }else{
                                                plusTick+=measure.meas_length_tick-start_tick;
                                            }
                                        }
                                        /*
                                        if (nn<sorted_duration_offset.count-1) {
                                            for (int next=nn+1; next<sorted_duration_offset.count; next++) {
                                                NSString *nextKey=sorted_duration_offset[nn+1];
                                                NSArray *nextNotes=measure.sorted_notes[nextKey];
                                                BOOL ignore=YES;
                                                for (OveNote *nextNote in nextNotes) {
                                                    if (!nextNote.isRest) {
                                                        ignore=NO;
                                                        break;
                                                    }else{
                                                        for (NoteElem *elem in nextNote.note_elems) {
                                                            if (!(elem.tie_pos&Tie_RightEnd)) {
                                                                ignore=NO;
                                                                break;
                                                            }
                                                        }
                                                    }
                                                }
                                                if (!ignore) {
                                                    plusTick=[nextKey intValue]-[key intValue];
                                                    break;
                                                }
                                            }
//                                            if (plusTick==0) {
//                                                plusTick=measure.meas_length_tick-[key intValue];
//                                            }
//                                            next_event_tick=cur_event_tick+plusTick;
                                        }
                                        
                                        if (plusTick==0 && mm<self.measures.count-1 && mm<endMeasure-1){
                                            OveMeasure *nextMeasure=self.measures[mm+1];
                                            
                                            next_event_tick=cur_event_tick+measure.meas_length_tick-[key intValue];
                                        }*/
                                        next_event_tick=cur_event_tick+plusTick;
                                    }
                                    
//                                    if (nn<sorted_duration_offset.count-1) {
//                                        next_event_tick+=measure.meas_length_tick-[key intValue];
//                                    }
                                    break;
                                }else if(eventFlags[tt]==NO){
                                    if (!found_untracked_event) {
                                        midi_index=tt;
                                        found_untracked_event=YES;
                                    }
                                    if (next_event_tick>=0 && event.tick-next_event_tick>tick_range) {
                                        //eventFlags[tt]=YES;
                                        NSLog(@"Error, Event(%d) tick:%d,should closed to(%d-%d). in %d %d note:%d", tt, event.tick,cur_event_tick, next_event_tick,mm,nn, elem.note);
                                        //midi_index++;
                                        break;
                                    }
                                    //NSLog(@"--(%d) %d:%x,%d,%d",tt,event.tick,event.evt,event.nn, event.vv);
                                    skipped_midi_event++;
                                    if (skipped_midi_event>40) {
                                        NSLog(@"Error can't find note in midi %d,%d,%d,%d,%d,%d",mm,nn,i_notes,ee,elem.note,elem.line);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
                
                //midi_index=cur_event_index;
                //NSLog(@"%d:%d:t:%d(%d)",mm,play_cur_note, timestamp,elem_count);
//                if (midi_index<cur_event_index-20) {
//                    midi_index=cur_event_index-20;
//                    if (midi_index<0) {
//                        midi_index=0;
//                    }
//                }
            }
            //finished one measure
            if (midi_index<cur_event_index-10) {
                midi_index=cur_event_index-10;
                if (midi_index<0) {
                    midi_index=0;
                }
            }
            //measure_stamp+=measure.meas_length_tick*ticksPerQuarter/480;
        }
    }
#if 1
    if (midiFile.midiMeasureInfo.count>0) {
        NSArray *sortedTicks=[midiFile.midiMeasureInfo.allKeys sortedArrayUsingSelector:@selector(compare:)];
        for (int i=0; i<sortedTicks.count-1; i++) {
            NSNumber *start_tick_num=sortedTicks[i];
            NSMutableDictionary *measInfo=midiFile.midiMeasureInfo[start_tick_num];
            measInfo[@"duration"]=@([sortedTicks[i+1] intValue] - [start_tick_num intValue]);
        }
    }
#endif
    
    NSMutableDictionary *lastMeasInfo=midiFile.midiMeasureInfo[@(meas_start_tick)];
    Event *lastEvent=midiEvents.lastObject;
    NSArray *note_ticks=lastMeasInfo[@"note_ticks"];
    [lastMeasInfo setObject:@(lastEvent.tick-[note_ticks.firstObject intValue]) forKey:@"duration"];
    
    //debug
#if 1
    char *abc[]={"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"};
    NSMutableString *debugString=[[NSMutableString alloc] initWithString:@"#,tick,evt,on/off,note,size,measure,nn,ii,ee,staff,line,meas_tick\n"];
    int midiLoseEvents=0;
    for (int i=0; i<midiEvents.count; i++) {
        Event *event=midiEvents[i];
        unsigned char evt=event.evt&0xf0;
        unsigned char channel=event.evt&0x0f;
        if (evt!=0x90 || (event.vv==0 && evt==0x90)) {
            continue;
        }
        
        [debugString appendFormat:@"%d,%d,%x %d %d,",i,event.tick,event.evt,event.nn, event.vv];
        if (evt==0x90 || evt==0x80) {
            int oct=event.nn/12-1;
            int step=event.nn%12;
            NSString *onoff=@"on";
            if (event.evt==0x80 || event.vv==0) {
                onoff=@"off";
            }else{
                if (event.userdata==nil) {
                    NSLog(@"Error can't find note %d:%d,%x,%d(%d%s),%d in xml", i,event.tick,event.evt,event.nn,oct,abc[step],event.vv);
                }
            }
            [debugString appendFormat:@"%@,%d%s,",onoff, oct,abc[step]];
        }else{
            [debugString appendFormat:@",,"];
        }
        int note_duration=0;
        if (event.userdata) {
            note_duration=[event.userdata[@"duration"] intValue];
            int mm=[event.userdata[@"mm"] intValue];
            OveMeasure *measure=self.measures[mm];
            [debugString appendFormat:@"%@%@,%d,%@,%@,%@,%@,%@,%@\n",
             event.userdata[@"duration"], note_duration<10 ? @"*" : @"",
             measure.number,event.userdata[@"nn"],event.userdata[@"ii"],
             event.userdata[@"ee"],event.userdata[@"staff"],event.userdata[@"line"],
             event.userdata[@"meas_start_tick"]];
            if (note_duration<10) {
                midiLoseEvents++;
            }
        }else{
            for (int next=i; next<midiEvents.count; next++) {
                Event *nextEvent=midiEvents[next];
                unsigned char nextEvt=nextEvent.evt&0xf0;
                unsigned char nextChannel=nextEvent.evt&0x0f;
                if ((nextEvt==0x80 || (nextEvt==0x90 && nextEvent.vv==0)) && nextEvent.nn==event.nn && channel==nextChannel) {
                    note_duration=nextEvent.tick-event.tick;
                    break;
                }
            }
            [debugString appendFormat:@"%d%@,,,,,,,\n",note_duration,note_duration<10?@"*":@""];
            if (!eventFlags[i]) {
                midiLoseEvents++;
            }else{
//                if (note_duration<10) {
//                    midiLoseEvents++;
//                }
            }
        }
    }
    midiFile.midiLoseEvents=midiLoseEvents;
    if (midiLoseEvents>0) {
        NSLog(@"Error, midi lose %d event",midiLoseEvents);
    }
#endif
    
    free(eventFlags);
}

- (MidiFile*)parseMidi:(NSData*)midi_data videoMidi:(BOOL)videoMidi{
    MidiFileSerialize *mfs=[[MidiFileSerialize alloc]init];
    MidiFile *midiFile = [mfs loadFromData:midi_data];
    //self.accompanyMidiFile=midiFile;
    
    [self checkMidiSequence:midiFile videoMidi:videoMidi];
    return midiFile;
}

+ (MidiFile*)parseMidi:(NSData*)midi_data {
    MidiFileSerialize *mfs=[[MidiFileSerialize alloc]init];
    MidiFile *midiFile = [mfs loadFromData:midi_data];
    NSArray *events=midiFile.mergedMidiEvents;
    for (int i=0; i<events.count; i++) {
        Event *event=events[i];
        int evt=event.evt & 0xf0;
        if (evt==kMIDIMessage_NoteOn && event.vv>0) {
            int duration=0;
            for (int next=i+1; next<events.count; next++) {
                Event *nextEvent=events[next];
                if ((nextEvent.evt&0xf0)==kMIDIMessage_NoteOff || ((nextEvent.evt&0xf0)==kMIDIMessage_NoteOn && nextEvent.vv==0)) {
                    duration=nextEvent.tick-event.tick;
                    break;
                }
            }
            event.userdata=[NSMutableDictionary dictionaryWithDictionary:@{@"duration":@(duration)}];
        }
    }
    return midiFile;
}
//- (void)loadAccompany:(NSData*)midi_data
//{
//    MidiFileSerialize *mfs=[[MidiFileSerialize alloc]init];
//    MidiFile *midiFile = [mfs loadFromData:midi_data];
//    self.accompanyMidiFile=midiFile;
//    
//    ITrack *track0=[midiFile getTrackPianoTrack];
//    NSArray *midiEvents=track0.events;
//    if (midiFile.tracks.count<=3) {
//        midiEvents=midiFile.mergedMidiEvents;
//    }
//    [self checkMidiSequence:midiFile];
////    [self checkMidiSequence:midiEvents timeSignatures:midiFile.timeSignatures quarter:midiFile.quarter];
//}

- (void)loadVideoMidi:(NSData*)midi_data
{
    self.videoMidiFile=[self parseMidi:midi_data videoMidi:YES];
//    MidiFileSerialize *mfs=[[MidiFileSerialize alloc]init];
//    MidiFile *midiFile = [mfs loadFromData:midi_data];
//    self.videoMidiFile=midiFile;
//    
//    ITrack *track0=[midiFile getTrackPianoTrack];
//    NSArray *midiEvents=track0.events;
//    if (midiFile.tracks.count<=3) {
//        midiEvents=midiFile.mergedMidiEvents;
//    }
//    [self checkMidiSequence:midiFile];
    //    [self checkMidiSequence:midiEvents timeSignatures:midiFile.timeSignatures quarter:midiFile.quarter];
}

+ (NSDictionary*) getXmlMusicInfo:(NSString*)file folder:(NSString *)folder
{
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDir = [documentPaths objectAtIndex:0];
    NSString *path = documentDir;
    if (folder) {
        path = [path stringByAppendingPathComponent:folder];
    }
    path = [path stringByAppendingPathComponent:file];
    NSString *xml_data=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (xml_data==nil) {
        NSLog(@"Can not read file:%@", file);
        return nil;
    }
    NSString *composer=@"", *title=@"";
    
    //<movement-title>Bach 2 part invention No.3</movement-title>
    NSRange range=[xml_data rangeOfString:@"<movement-title>"];
    if (range.length>0) {
        range.location+=range.length;
        range.length=100;
        NSRange end=[xml_data rangeOfString:@"</movement-title>" options:NSCaseInsensitiveSearch range:range];
        if (end.length>0 && end.location>range.location) {
            range.length=end.location-range.location;
            title=[xml_data substringWithRange:range];
        }
    }
    
    //<creator type="composer">J.S. Bach</creator>
    range=[xml_data rangeOfString:@"<creator type=\"composer\">"];
    if (range.length>0) {
        range.location+=range.length;
        range.length=100;
        NSRange end=[xml_data rangeOfString:@"</creator>" options:NSCaseInsensitiveSearch range:range];
        if (end.length>0 && end.location>range.location) {
            range.length=end.location-range.location;
            composer=[xml_data substringWithRange:range];
            //return @{@"composer":};
        }
    }
    if (composer.length>0 || title.length>0) {
        return @{@"composer":composer, @"title":title};
    }

    return nil;
}
+ (OveMusic*)loadXMLMusic:(NSString*)file folder:(NSString *)folder
{
    NSString *xml_file=[[NSBundle mainBundle] pathForResource:file ofType:@"xml"];
    NSString *midi_file=[[NSBundle mainBundle] pathForResource:file ofType:@"mid"];
    
    NSData *xml_data=[NSData dataWithContentsOfFile:xml_file];
    NSData *midi_data=[NSData dataWithContentsOfFile:midi_file];
    
    if (xml_data==nil)
    {
        NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDir = [documentPaths objectAtIndex:0];
        NSString *path = documentDir;
        if (folder) {
            path = [path stringByAppendingPathComponent:folder];
        }
        path = [path stringByAppendingPathComponent:file];
        xml_file = [path stringByAppendingPathExtension:@"xml"];
        xml_data=[NSData dataWithContentsOfFile:xml_file];
        if (xml_data==nil) {
            NSLog(@"Can not read file:%@", file);
            return nil;
        }
        
        midi_file = [path stringByAppendingPathExtension:@"mid"];
        midi_data=[NSData dataWithContentsOfFile:midi_file];
    }
    OveMusic *music=[[OveMusic alloc]init];
    [music parseMusicXML:xml_data];
    if (midi_data) {
        music.accompanyMidiFile = [music parseMidi:midi_data videoMidi:NO];
    }
    return music;
}
+ (OveMusic*)loadFromXMLData:(NSData*)xml_data midiData:(NSData*)midi_data
{
    OveMusic *music=[[OveMusic alloc]init];

    if (![music parseMusicXML:xml_data]) {
        return nil;
    }
    if (midi_data) {
        music.accompanyMidiFile = [music parseMidi:midi_data videoMidi:NO];
    }
    return music;
}
+ (OveMusic*)loadFromMXLFile:(NSString*)mxlFilePath
{
    NSData *xml_data=[self unzip:mxlFilePath];

    if (xml_data) {
        OveMusic *music=[[OveMusic alloc]init];
        
        if ([music parseMusicXML:xml_data]) {
            return music;
        }
    }
    return nil;
}


+ (NSData*)unzip:(NSString *)zipFile
{
    ZipArchive* zip = [[ZipArchive alloc] init];
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //NSString *dcoumentpath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    //NSString* l_zipfile = [[NSBundle mainBundle] pathForResource:musicname ofType:@"zip"];
    NSString *musicname=@"test/";
    NSString* unzipto = [NSTemporaryDirectory() stringByAppendingPathComponent:musicname];
    BOOL ret = [zip UnzipOpenFile:zipFile];
    NSString *xml_filename=nil;
    if(ret)
    {
        ret = [zip UnzipFileTo:unzipto overWrite:YES];
        if( NO==ret)
        {
            NSLog(@"extrace music(%@) failed", musicname);
        }
        NSString *containerFile=[unzipto stringByAppendingPathComponent:@"META-INF/container.xml"];
        NSString *containerContent=[NSString stringWithContentsOfFile:containerFile encoding:NSUTF8StringEncoding error:nil];
        if (containerContent) {
            NSRange range=[containerContent rangeOfString:@"<rootfile full-path=\""];
            if (range.length>0) {
                range.location+=range.length;
                range.length=containerContent.length-range.location;
                NSRange end=[containerContent rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:range];
                if (end.length>0) {
                    range.length=end.location-range.location;
                    NSString *filename=[containerContent substringWithRange:range];
                    xml_filename=[unzipto stringByAppendingPathComponent:filename];
                }
            }
        }
        [zip UnzipCloseFile];
    }
    if (xml_filename) {
        return [NSData dataWithContentsOfFile:xml_filename];
    }
    return nil;
}

@end
