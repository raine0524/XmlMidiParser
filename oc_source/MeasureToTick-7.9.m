//
//  MeasureToTick.m
//  ReadStaff
//
//  Created by yan bin on 11-10-20.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "MeasureToTick.h"
#import "MusicOve.h"


@implementation Segment
@synthesize measure, measureCount, relativeTick, absoluteTick, fromMeasure;
@synthesize command, fromCommand;
- (int) getOffsetTick
{
    return relativeTick - absoluteTick;
}

@end

@implementation TimeTick
@synthesize numerator, denominator, measure, tick;
@end

@implementation MeasureTick
@synthesize absoluteTick,measure,duration;
@end

@implementation RepeatNode
@synthesize measure, measureCount, backwardRepeatCount;
@synthesize atLeft, isNumericBackward;
@synthesize repeatCommand;
@synthesize nodeType;
@synthesize repeatType;
@synthesize barline, access;
@synthesize numeric;
@end

@implementation Probe
@synthesize fromRepeatID, toRepeatID, pass;
@synthesize action;
@end

@interface MeasureToTick()
@property (nonatomic, strong) OveMusic* ove;
@end

@implementation MeasureToTick
@synthesize segments=segments_, tts=tts_;
- (void) AddRepeatNode:(NSMutableArray*) repeats node:(RepeatNode *)node
{
	for (int i = 0; i < repeats.count; ++i) {
        RepeatNode *item=[repeats objectAtIndex:i];
		if (item.measure == node.measure && item.repeatCommand == node.repeatCommand) {
			return;
		}
	}
    
	[repeats addObject:node];
}

-(bool) RepeatType2Left:(RepeatType) type
{
	bool left = true;
    
	switch (type) {
        case Repeat_Segno:
        case Repeat_Coda: {
            left = true;
            break;
        }
        case Repeat_ToCoda:
        case Repeat_DSAlCoda:
        case Repeat_DSAlFine:
        case Repeat_DCAlCoda:
        case Repeat_DC:
        case Repeat_DCAlFine:
        case Repeat_Fine: {
            left = false;
            break;
        }
        default:
            break;
	}
    
	return left;
}
-(RepeatCommand) RepeatType2Command:(RepeatType) type {
	RepeatCommand command = RepeatCommand_None;
    
	switch (type) {
        case Repeat_Segno: {
            command = RepeatCommand_Segno;
            break;
        }
        case Repeat_Coda: {
            command = RepeatCommand_Coda;
            break;
        }
        case Repeat_ToCoda: {
            command = RepeatCommand_ToCoda;
            break;
        }
        case Repeat_DSAlCoda:
        case Repeat_DSAlFine: {
            command = RepeatCommand_DS;
            break;
        }
        case Repeat_DCAlCoda:
        case Repeat_DC:
        case Repeat_DCAlFine: {
            command = RepeatCommand_DC;
            break;
        }
        case Repeat_Fine: {
            command = RepeatCommand_Fine;
            break;
        }
        default:
            break;
	}
    
	return command;
}
NSInteger compair_repeat_note( RepeatNode* data1,  RepeatNode* data2, void* user);
NSInteger compair_repeat_note( RepeatNode* data1,  RepeatNode* data2, void* user)
{
    if (data1.measure != data2.measure)
        return data1.measure > data2.measure;
    
    if (data1.atLeft != data2.atLeft)
        return !data1.atLeft;
    
    return data1.nodeType > data2.nodeType;
}

- (NSMutableArray*) getAllRepeats
{
	int i;
	int j;
	int k;
	int l;
    NSMutableArray * repeats=[[NSMutableArray alloc]init];
	int trackBarCount = (unsigned int) self.ove.measures.count;// ->getTrackBarCount();
    
	if (trackBarCount > 0) {
		RepeatNode *startNode=[[RepeatNode alloc]init];
        
		startNode.measure = 0;
		startNode.measureCount = 0;
		startNode.atLeft = true;
		startNode.nodeType = NodeType_None;
		startNode.repeatType = Repeat_Null;
		startNode.barline = Barline_Default;
		startNode.repeatCommand = RepeatCommand_Start;
        
		[self AddRepeatNode:repeats node:startNode];
	}
    
	//for (i = 0; i < self.ove->getPartCount(); ++i) 
    {
		int partStaffCount = 1;//self.ove->getStaffCount(i);
        
		for (j = 0; j < partStaffCount; ++j) {
			//Track* trackPtr = self.ove->getTrack(i, j) ;
            
			for (k = 0; k < trackBarCount; ++k) {
				OveMeasure* measure = [self.ove.measures objectAtIndex:k];// ->getMeasure(k);
//				OveMeasureData* measureData = self.ove->getMeasureData(i, j, k);
				int barIndex = measure.number;// ->getBarNumber()->getIndex();
                
				// repeat symbol
				//QList<OVE::MusicData*> measureRepeats = measureData->getMusicDatas(OVE::MusicData_Repeat);
                
				//for (l = 0; l < self.ove.measures.count; ++l) 
                {
                    
                    if (measure.repeat_type != Repeat_Null) {
                        RepeatNode *node=[[RepeatNode alloc]init];
                        
                        node.nodeType = NodeType_RepeatSymbol;
                        node.measure =  measure.number;// repeat->start()->getMeasure();
                        node.measureCount = 0;
                        node.atLeft = [self RepeatType2Left:measure.repeat_type];
                        node.repeatType = measure.repeat_type; //repeat->getRepeatType();
                        node.repeatCommand = [self RepeatType2Command:measure.repeat_type];
                        
                        [self AddRepeatNode:repeats node: node];
                    }
				}
                
				// barline : forward / backward
				for (l = 0; l < 2; ++l) {
                    if (self.checkIsRepeatPlay && !measure.repeat_play)
                    {
                        NSLog(@"ignore repeat for measure:%d(%d)", measure.number,measure.show_number);
                    }else{
                        BarlineType barline = (l == 0) ? measure.left_barline : measure.right_barline;
                        
                        if (barline == Barline_RepeatLeft || barline == Barline_RepeatRight) {
                            RepeatNode *node=[[RepeatNode alloc]init];
                            
                            node.nodeType = NodeType_Barline;
                            node.measure = barIndex;
                            node.measureCount = 0;
                            node.atLeft = l == 0;
                            node.repeatCommand = (barline == Barline_RepeatLeft) ? RepeatCommand_Forward : RepeatCommand_Backward;
                            node.repeatType = Repeat_Null;
                            node.barline = barline;
                            node.backwardRepeatCount = measure.repeat_count;// ->getBackwardRepeatCount();
                            if (node.backwardRepeatCount==0) {
                                node.backwardRepeatCount=1;
                            }
                            [self AddRepeatNode:repeats node: node];
                        }
                    }

				}
                
				// numeric ending
                /*
				const QList<OVE::MusicData*> numerics = measureData->getCrossMeasureElements(
                                                                                             OVE::MusicData_Numeric_Ending, OVE::MeasureData::PairType_Start);
                */
				for (l = 0; l < measure.numerics.count; ++l) 
                {
                    NumericEnding *num=[measure.numerics objectAtIndex:l];
                    if (num.pos) {
                        //					NumericEnding* numeric = dynamic_cast<OVE::NumericEnding*> (numerics[l]);
                        RepeatNode *node=[[RepeatNode alloc]init];
                        
                        node.nodeType = NodeType_NumericEnding;
                        node.measure = barIndex;
                        node.measureCount = num.numeric_measure_count;//numeric->stop()->getMeasure();
                        node.atLeft = true;
                        node.repeatCommand = RepeatCommand_NumericEnding;
                        node.numeric = num;
                        //					node.numeric = numeric;
                        
                        [self AddRepeatNode:repeats node: node];
                    }
				}
			}
		}
	}
    
	if (trackBarCount > 0) {
		RepeatNode *endNode=[[RepeatNode alloc]init];
        
		endNode.measure = trackBarCount - 1;
		endNode.measureCount = 0;
		endNode.atLeft = false;
		endNode.nodeType = NodeType_None;
		endNode.repeatType = Repeat_Null;
		endNode.barline = Barline_Default;
		endNode.repeatCommand = RepeatCommand_End;
        
		[self AddRepeatNode:repeats node: endNode];
	}

    [repeats sortUsingFunction:compair_repeat_note context:nil];

//	sort(repeats.begin(), repeats.end(), CompareRepeatNode());
    
	for (i = 0; i < repeats.count; ++i) {
        RepeatNode *repeat=[repeats objectAtIndex:i];
		NumericEnding* numeric = repeat.numeric;
		if (repeat.repeatCommand == RepeatCommand_NumericEnding)// && numeric	!= NULL) 
        {
			int measure = numeric.pos.start_offset;// numeric->start()->getMeasure();
			int measureCount = repeat.measureCount;// numeric->stop()->getMeasure();
            
			for (j = i + 1; j < repeats.count; ++j) 
            {
                RepeatNode *item=[repeats objectAtIndex:j];
				if (item.repeatCommand == RepeatCommand_Backward
                    && item.measure == measure + measureCount) {
					item.isNumericBackward = true;
				}
			}
		}
	}
    
	return repeats;
}

bool canStop(RepeatNode* node);
bool canStop(RepeatNode* node)
{
	if (node.repeatCommand == RepeatCommand_End)
		return true;
    
	if (node.repeatCommand == RepeatCommand_Fine && node.access > 0)
		return true;
    
	return false;
}

void updateAccess(NSMutableArray* repeats, int startID, int stopID);
void updateAccess(NSMutableArray* repeats, int startID, int stopID)
{
	for (int i = startID; i <= stopID && i < (int) repeats.count; ++i) {
        RepeatNode *repeat=[repeats objectAtIndex:i];
        repeat.access+=1;
//		++repeats[i].access_;
	}
}

int findBackwardOfNumeric(NSMutableArray* repeats, int numericID);
int findBackwardOfNumeric(NSMutableArray* repeats, int numericID) 
{
    RepeatNode *repeat = [repeats objectAtIndex:numericID];
	NumericEnding* numeric = repeat.numeric;
	if (numeric != NULL) 
    {
		int measure =  repeat.measure; //numeric->start()->getMeasure();
		int measureCount = repeat.measureCount; //numeric->stop()->getMeasure();
		bool findBackward = false;
        
		for (int i = numericID + 1; i < repeats.count; ++i) 
        {
            RepeatNode *item=[repeats objectAtIndex:i];
			if (/*repeats[i].numeric != NULL ||*/ findBackward) 
            {
				break;
			}
            
			if (item.repeatCommand == RepeatCommand_Backward) {
				findBackward = true;
                
				if (item.measure >= measure + measureCount - 1) {
					return i;
				}
			}
		}
	}
    
	return -1;
}

bool canJumpLeft(NSMutableArray* repeats, int id, bool* isNumeric, int* backwardID);
bool canJumpLeft(NSMutableArray* repeats, int id, bool* isNumeric, int* backwardID) 
{
	*isNumeric = false;
    
	if (id >= 0 && id < (int) repeats.count) {
		//��:||�ҷ�ڣ����ʴ���������֮�ڣ�Ȼ����ȥ����ߵ�start��||:
		int findBackwardID = findBackwardOfNumeric(repeats, id);
        RepeatNode *node = [repeats objectAtIndex:id];
        
		if (findBackwardID >= 0 && findBackwardID < (int) repeats.count) {
			*isNumeric = true;
            RepeatNode *back_repeat=[repeats objectAtIndex:findBackwardID];
			if (back_repeat.access <= [node.numeric getJumpCount])
            //if (repeats[findBackwardID].access_ <= repeats[id].numeric_->getJumpCount()) 
            {
				*backwardID = findBackwardID;
				return true;
			}
		}
        
		// other
		//RepeatNode& node = repeats[id];
        
		if (node.repeatCommand == RepeatCommand_DS) {
			if (node.access == 0) {
				return true;
			}
		}
        
		if (node.repeatCommand == RepeatCommand_DC) {
			if (node.access == 0) {
				return true;
			}
		}
        
		if (node.repeatCommand == RepeatCommand_Backward) {
			if (!node.isNumericBackward && node.access
                < node.backwardRepeatCount) {
				return true;
			}
		}
	}
    
	return false;
}

bool canJumpRight(NSMutableArray *repeats, int ID, NSMutableArray* probes);
bool canJumpRight(NSMutableArray *repeats, int ID, NSMutableArray* probes)
{
	if (ID >= 0 && ID < (int) repeats.count) {
		//const RepeatNode& node = repeats[id] ;
        
		//numeric��:||�ҷ�ڣ����numeric��򲿷�С��
        RepeatNode *node=[repeats objectAtIndex:ID];
		int findBackwardID = findBackwardOfNumeric(repeats, ID);
        
		if (findBackwardID >= 0 && findBackwardID < (int) repeats.count) {
            int jumpCount=[node.numeric  getJumpCount];
			if (node.access > jumpCount) {
				// :|| -> start -> numeric
				// :|| -> ||: -> numeric
                if (probes.count >= 2)
                {
                    Probe *prob=[probes objectAtIndex:probes.count - 2];
                    RepeatNode *tmp=[repeats objectAtIndex:prob.toRepeatID];
                    if (tmp.repeatCommand == RepeatCommand_Backward) {
                        return true;
                    }
                }
                if (node.access==2 && jumpCount==0) {
                    return true;
                }
			}
		}
        
		if (node.repeatCommand == RepeatCommand_ToCoda) {
			if (node.access > 0) {
				if (probes.count>= 2) {
                    Probe *prob=[probes objectAtIndex:probes.count - 1];
                    RepeatNode *from_repeat=[repeats objectAtIndex:prob.fromRepeatID];
                    RepeatNode *to_repeat=[repeats objectAtIndex:prob.toRepeatID];
					// ds al coda -> segno -> to coda -> coda
					if (to_repeat.repeatCommand == RepeatCommand_Segno) {
						if (from_repeat.repeatType == Repeat_DSAlCoda) {
							return true;
						}
					}
                    
					// dc al coda -> start -> to coda -> coda
					if (to_repeat.repeatCommand == RepeatCommand_Start) {
						if (from_repeat.repeatType == Repeat_DCAlCoda || from_repeat.repeatType==Repeat_DC) {
							return true;
						}
					}
				}
			}
		}
	}
    
	return false;
}

//QList<RepeatCommand> MeasureToTick::getJumpChoice(RepeatCommand command) 
int getJumpChoice(RepeatCommand command, RepeatCommand *commands);
int getJumpChoice(RepeatCommand command, RepeatCommand *commands) 
{
	//QList<RepeatCommand> commands;
    int count=0;
	switch (command) {
        case RepeatCommand_Start:
        case RepeatCommand_Forward:
        case RepeatCommand_Segno:
        case RepeatCommand_Coda:
        case RepeatCommand_Fine:
        case RepeatCommand_End:
            break;
            // left
        case RepeatCommand_Backward:
            commands[0]=RepeatCommand_Forward;
            commands[1]=RepeatCommand_Start;
            count=2;
//            commands.push_back(RepeatCommand_Forward);
//            commands.push_back(RepeatCommand_Start);
            break;
        case RepeatCommand_DC:
            commands[0]=RepeatCommand_Start;
            count=1;
//            commands.push_back(RepeatCommand_Start);
            break;
        case RepeatCommand_DS:
            commands[0]=RepeatCommand_Segno;
            count=1;
//            commands.push_back(RepeatCommand_Segno);
            break;
            // right
        case RepeatCommand_NumericEnding:
            commands[0]=RepeatCommand_Backward;
            count=1;
//            commands.push_back(RepeatCommand_Backward);
            break;
        case RepeatCommand_ToCoda:
            commands[0]=RepeatCommand_Coda;
            count=1;
//            commands.push_back(RepeatCommand_Coda);
            break;
        default:
            break;
	}
//    commands[count]=0;

	return count;
}

bool searchBestJumpLeftRepeat(NSMutableArray *repeats, int id, RepeatCommand *choices, int choices_count, int* jumpID);
bool searchBestJumpLeftRepeat(NSMutableArray *repeats, int id, RepeatCommand *choices, int choices_count, int* jumpID) 
{
	// ������unsigned int
	*jumpID = -1;
    
	for (int i = 0; i < (int) choices_count; ++i) {
		for (int j = id - 1; j >= 0; --j) 
        {
            RepeatNode *node=[repeats objectAtIndex:j];
			if (node.repeatCommand == choices[i]) {
				*jumpID = j;
				return true;
			}
		}
	}
    
	return false;
}

bool searchBestJumpRightRepeat(NSMutableArray* repeats, int id, RepeatCommand* choices, int choices_count, int* jumpID);
bool searchBestJumpRightRepeat(NSMutableArray* repeats, int id, RepeatCommand* choices, int choices_count, int* jumpID)
{
	*jumpID = -1;
    
	for (int i = 0; i < (int) choices_count; ++i) {
		for (int j = id + 1; j < (int) repeats.count; ++j) {
            RepeatNode *node=[repeats objectAtIndex:j];
			if (node.repeatCommand == choices[i]) {
				*jumpID = j;
				return true;
			}
		}
	}
    
	return false;
}

-(void) TraverseRepeats:(NSMutableArray *)repeats start:(int) startID current:(int) currentID pass:(int) pass probs:(NSMutableArray*)probes stopped:(bool*) stopped
{
	if (*stopped)
		return;
    
	if (currentID < 0 || currentID >= (int) repeats.count) {
		NSLog(@"MeasureToTick::TraverseRepeats currentID out of range!");
		return;
	}
    
	// stop
    RepeatNode *cur_repeat=[repeats objectAtIndex:currentID];
	if (canStop(cur_repeat)) {
		if (startID < currentID) {
            Probe *probe=[[Probe alloc]init];
            probe.fromRepeatID=startID;
            probe.toRepeatID = currentID;
            probe.action = Action_Play;
            probe.pass = pass;
            [probes addObject:probe];
		}
        
		updateAccess(repeats, currentID, currentID);
        
		*stopped = true;
        
		return;
	}
    
	bool isNumeric = false;
	int backwardID = -1;
	bool jumpLeft = canJumpLeft(repeats, currentID, &isNumeric, &backwardID);
    
	bool jumpRight = canJumpRight(repeats, currentID, probes);
    
	// jump left
	if (jumpLeft) {
		int searchID = isNumeric ? backwardID : currentID;
        RepeatNode *search_node=[repeats objectAtIndex:searchID];
		RepeatCommand  choices[4];
        int choices_count = getJumpChoice(search_node.repeatCommand, choices);
		int jumpID = -1;
        
		bool find = searchBestJumpLeftRepeat(repeats, searchID, choices,choices_count, &jumpID);
        
		if (find) {
            
			if (startID < searchID) {
                Probe *probe=[[Probe alloc]init];
                probe.fromRepeatID=startID;
                probe.toRepeatID=searchID;
                probe.action=Action_Play;
                probe.pass=pass;
                [probes addObject:probe];
//				probes.push_back(Probe(startID, searchID, Action_Play, pass));
			}
            
			Probe *probe=[[Probe alloc]init];
            probe.fromRepeatID=searchID;
            probe.toRepeatID=jumpID;
            probe.action=Action_Jump;
            probe.pass=pass;
            [probes addObject:probe];
//			probes.push_back(Probe(searchID, jumpID, Action_Jump, pass));
            
			// �϶���������
			updateAccess(repeats, currentID, searchID);
			[self TraverseRepeats:repeats start:jumpID current:jumpID pass:pass + 1 probs:probes stopped: stopped];
		}
	}
    
	// jump right
	if (jumpRight) {
//		QList<RepeatCommand> choices = getJumpChoice(repeats[currentID].repeatCommand_);
        RepeatNode *cur_node=[repeats objectAtIndex:currentID];
        RepeatCommand  choices[4];
        int choices_count = getJumpChoice(cur_node.repeatCommand, choices);

		int jumpID = -1;
		bool find = searchBestJumpRightRepeat(repeats, currentID, choices,choices_count, &jumpID);
        
		if (find) {
            
			if (startID < currentID) {
                Probe *probe=[[Probe alloc]init];
                probe.fromRepeatID=startID;
                probe.toRepeatID=currentID;
                probe.action=Action_Play;
                probe.pass=pass;
                [probes addObject:probe];

//				probes.push_back(Probe(startID, currentID, Action_Play, pass));
			}
            
            Probe *probe=[[Probe alloc]init];
            probe.fromRepeatID=currentID;
            probe.toRepeatID=jumpID;
            probe.action=Action_Jump;
            probe.pass=pass;
            [probes addObject:probe];
//			probes.push_back(Probe(currentID, jumpID, Action_Jump, pass));
            
			updateAccess(repeats, currentID, currentID);
			[self TraverseRepeats:repeats start:jumpID current:jumpID pass:pass probs:probes stopped:stopped];
		}
	}
    
	// play
	updateAccess(repeats, currentID, currentID);
	[self TraverseRepeats:repeats start:startID current:currentID+1 pass:pass probs:probes stopped:stopped];
}

bool RepeatCommand2Left(RepeatCommand command);
bool RepeatCommand2Left(RepeatCommand command) 
{
	bool left = false;
    
	switch (command) {
        case RepeatCommand_Start:
        case RepeatCommand_Forward:
        case RepeatCommand_Segno:
        case RepeatCommand_Coda:
        case RepeatCommand_NumericEnding:
            left = true;
            break;
        case RepeatCommand_End:
        case RepeatCommand_Backward:
        case RepeatCommand_ToCoda:
        case RepeatCommand_DC:
        case RepeatCommand_DS:
        case RepeatCommand_Fine:
            left = false;
            break;
        default:
            break;
	}
    
	return left;
}
#define getMeasureTick(quarter, num, den) (quarter * 4 * num / den)

-(int) getTick:(int) measure pos:(int) tick_pos 
{
//	TimeTick *tt;
    
	for (int i = 0; i < tts_.count; ++i) 
    {
        TimeTick *item=[tts_ objectAtIndex:i];
        if (measure >= item.measure) 
        {
            if (i==tts_.count-1) {
                int measuresTick = (measure - item.measure) * getMeasureTick(quarter_, item.numerator, item.denominator);
                
                return item.tick + measuresTick + tick_pos;

            }
            if (i<tts_.count-1) {
                TimeTick *next_item=[tts_ objectAtIndex:i+1];
                if (measure < next_item.measure) {
                    int measuresTick = (measure - item.measure) * getMeasureTick(quarter_, item.numerator, item.denominator);
                    
                    return item.tick + measuresTick + tick_pos;
                }
            }
        }
	}
	return 0;
}
-(int) getMeasure:(int) tick
{
    if (tick==0) {
        return 0;
    }
    
    for (MeasureTick *mt in mts_) 
    {
        if (tick>=mt.absoluteTick && tick<mt.absoluteTick+mt.duration) {
            return mt.measure;
        }
    }
    
	return (int)self.ove.measures.count-1;
}

-(int) getMeasureTick:(int) measureID
{
    if (measureID==0) {
        return 0;
    }
    
    for (MeasureTick *mt in mts_) 
    {
        if (mt.measure==measureID) {
            return mt.absoluteTick;
        }
    }
    
	return 0;
}

-(int) getMeasureWithPercent:(float) percent
{
    if (percent==0) {
        return 0;
    }
    MeasureTick *last_mt=[mts_ lastObject];
    int total_tick=last_mt.absoluteTick+last_mt.duration;
    int tick=total_tick*percent;
    for (MeasureTick *mt in mts_) 
    {
        if (tick>=mt.absoluteTick && tick<mt.absoluteTick+mt.duration) {
            return mt.measure;
        }
    }
    
	return (int)self.ove.measures.count-1;
}


-(int) getMeasureWithTick:(int) tick
{
    
    if (tick==0) {
        return 0;
    }
    
    for (int i=0;i<mts_.count;i++) 
    {
        MeasureTick *mt = [mts_ objectAtIndex:i];
        if (tick>=mt.absoluteTick && tick<mt.absoluteTick+mt.duration) {
            return mt.measure;
        }
    }
    
	return (int)self.ove.measures.count-1;
}

-(void) buildMts
{
    if (mts_==nil) {
        mts_=[[NSMutableArray alloc]init ];
    }else{
        [mts_ removeAllObjects];
    }
    MeasureTick *prev_mt=nil;
    for (int i=0; i<segments_.count; i++) 
    {
        Segment *item=[segments_ objectAtIndex:i];
        for (int j=item.measure; j<item.measure+item.measureCount; j++) 
        {
            MeasureTick *mt=[[MeasureTick alloc]init];
            [mts_ addObject:mt];
            mt.measure=j;
            mt.duration=0;
            mt.absoluteTick = item.relativeTick+([self getTick:j pos:0]-[self getTick:item.measure pos:0]);
            if (prev_mt) {
                prev_mt.duration=mt.absoluteTick-prev_mt.absoluteTick;
            }
            prev_mt=mt;

        }
    }
#if 0
    for (int i=0;i<mts_.count;i++) 
    {
        MeasureTick *mt = [mts_ objectAtIndex:i];
        NSLog(@"%d:measure(%d):(%d,%d) paizi:%f",i,mt.measure,mt.absoluteTick,mt.duration, mt.duration/(quarter_/2.0));
    }
#endif
}

-(void) buildSegments
{
	bool basic = false;
    
    if (segments_==nil) {
        segments_=[[NSMutableArray alloc]init];
    }else{
        [segments_ removeAllObjects];
    }

	if (basic) {
		Segment *segment=[[Segment alloc]init];
		segment.measure = 0;
		segment.measureCount = (int)self.ove.measures.count;// ->getMeasureCount();
		segment.command = RepeatCommand_None;
		segment.fromMeasure = 0;
		segment.fromCommand = RepeatCommand_Start;
        
        [segments_ addObject:segment];
	} else {
		//int measureCount = self.ove->get_measure_count() ;
		NSMutableArray *repeats =[self getAllRepeats];
		NSMutableArray *probes=[[NSMutableArray alloc]init];
		bool stopped = false;
        
		[self TraverseRepeats:repeats start:0 current:0 pass:0 probs:probes stopped:&stopped];
        
#if 0
        //dump repeats
        for (int i=0; i<repeats.count; i++) {
            RepeatNode *r=repeats[i];
            NSLog(@"%d:%d,%d,%d,%d,%d",i, r.measure, r.measureCount,r.repeatCommand,r.nodeType,r.repeatType);
        }
        //dump probes
        for (int i=0; i<probes.count; i++) {
            Probe *r=probes[i];
            RepeatNode *from=repeats[r.fromRepeatID];
            RepeatNode *to=repeats[r.toRepeatID];
            NSLog(@"%d:%d-%d,%d->%d %d,%d",i, r.fromRepeatID, r.toRepeatID, from.measure, to.measure, r.action,r.pass);
        }
#endif
		for (int i = 0; i < probes.count; ++i) {
            Probe *prob=[probes objectAtIndex:i];
			if (prob.action == Action_Play) {
				Segment *segment=[[Segment alloc]init];
                RepeatNode *fromNode=[repeats objectAtIndex:prob.fromRepeatID];
                RepeatNode *toNode=[repeats objectAtIndex:prob.toRepeatID];
                
				segment.measure = fromNode.measure;
				if (!RepeatCommand2Left(fromNode.repeatCommand)) {
					segment.measure+=1;
				}
                
				segment.measureCount = toNode.measure - segment.measure;
				if (!RepeatCommand2Left(toNode.repeatCommand)) {
					++segment.measureCount;
				}
                
				segment.command = fromNode.repeatCommand;
                
				segment.fromMeasure = segment.measure;
				segment.fromCommand = segment.command;
                if (i>0) 
                {
                    Probe *prev_prob=[probes objectAtIndex:i-1];
                    if (prev_prob.action == Action_Jump) 
                    //if (i > 0 && probes[i - 1].action_ == Action_Jump) 
                    {
                        RepeatNode *tmp=[repeats objectAtIndex:prev_prob.fromRepeatID];
                        segment.fromMeasure = tmp.measure;
                        segment.fromCommand = tmp.repeatCommand;
                    }
                }
                [segments_ addObject:segment];
			}
		}
	}
    
	int tick = 0;
    
	for (int i = 0; i < segments_.count; ++i) {
		Segment *segment = [segments_ objectAtIndex:i];
        
		int beginTick = [self getTick:segment.measure pos:0];
		int endTick = [self getTick:segment.measure + segment.measureCount pos:0];
        
		segment.relativeTick = tick;
		segment.absoluteTick = beginTick;
        
		tick += endTick - beginTick;
        
        //NSLog(@"%d:%d-%d,%d",i, segment.measure, segment.measure+segment.measureCount,segment.command);
	}
}
- (void) build:(OveMusic*) ove quarter:(int) quarter
{
	int currentTick = 0;
	int measureCount = (int)ove.measures.count;// ove->getMeasureCount();
    
	quarter_ = quarter;
	self.ove = ove;//[ove retain];
    if (tts_!=nil) {
        [tts_ removeAllObjects];
    }else{
        tts_=[[NSMutableArray alloc]init ];
    }
    
	for (int i = 0; i < measureCount; ++i) {
		OveMeasure* measure = [self.ove.measures objectAtIndex:i];
        //		TimeSignature* time = measure->getTime();
		TimeTick *tt=[[TimeTick alloc]init];
		bool change = false;
        
        
		tt.tick = currentTick;
		tt.numerator = measure.numerator;// time->getNumerator();
		tt.denominator = measure.denominator;// time->getDenominator();
		tt.measure = i;
        
		if (i == 0) {
			change = true;
		} else {
            OveMeasure* prevMeasure=[self.ove.measures objectAtIndex:i-1];
            //			OVE::TimeSignature* previousTime = self.ove->getMeasure(i - 1)->getTime();
            
			if (measure.numerator != prevMeasure.numerator || measure.denominator!=prevMeasure.denominator)
            {
                change = true;
			}
		}
        
		if (change) {
            [tts_ addObject:tt];
		}
        currentTick += quarter_ * 4 * tt.numerator / tt.denominator;
	}
    
	[self buildSegments];
    [self buildMts];
}
+(NSString*)Repeat2String:(RepeatCommand) cmd
{
    //	QString str = QString();
    char *str=NULL;
	switch (cmd) {
        case RepeatCommand_Start:
            str = "Start";
            break;
        case RepeatCommand_End:
            str = "End";
            break;
        case RepeatCommand_Forward:
            str = "||:";
            break;
        case RepeatCommand_Backward:
            str = ":||";
            break;
        case RepeatCommand_Segno:
            str = "Segno";
            break;
        case RepeatCommand_ToCoda:
            str = "To Coda";
            break;
        case RepeatCommand_Coda:
            str = "Coda";
            break;
        case RepeatCommand_DC:
            str = "D.C.";
            break;
        case RepeatCommand_DS:
            str = "D.S.";
            break;
        case RepeatCommand_Fine:
            str = "Fine";
            break;
        case RepeatCommand_NumericEnding:
            str = "Numeric";
            break;
        case RepeatCommand_None:
            break;
	}
    
	return [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
}
@end
