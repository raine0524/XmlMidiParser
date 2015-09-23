//
//  MeasureToTick.cpp
//  ReadStaff
//
//  Created by yanbin on 14-8-6.
//
//

#include "ParseExport.h"
#include "MeasureToTick.h"

MeasureToTick::~MeasureToTick()
{
    Delete_MyArray(Segment,segments_);
    Delete_MyArray(MeasureTick,mts_);
    Delete_MyArray(TimeTick,tts_);
}

bool canStop(RepeatNode* node)
{
	if (node->repeatCommand == RepeatCommand_End)
		return true;
    
	if (node->repeatCommand == RepeatCommand_Fine && node->access > 0)
		return true;
    
	return false;
}

void updateAccess(MyArray* repeats, int startID, int stopID)
{
	for (int i = startID; i <= stopID && i < (int) repeats->count; ++i) {
        RepeatNode *repeat=(RepeatNode *)(repeats->objects[i]);
        repeat->access+=1;
    }
}

int findBackwardOfNumeric(MyArray* repeats, int numericID)
{
    RepeatNode *repeat = (RepeatNode *)repeats->objects[numericID];
    NumericEnding* numeric = repeat->numeric;
    if (numeric != NULL)
    {
        int measure =  repeat->measure; //numeric->start()->getMeasure();
        int measureCount = repeat->measureCount; //numeric->stop()->getMeasure();
        bool findBackward = false;
        
        for (int i = numericID + 1; i < repeats->count; ++i)
        {
            RepeatNode *item=(RepeatNode *)repeats->objects[i];
            if (/*repeats->objects[i].numeric != NULL ||*/ findBackward)
            {
                break;
            }
            
            if (item->repeatCommand == RepeatCommand_Backward) {
                findBackward = true;
                
                if (item->measure >= measure + measureCount - 1) {
                    return i;
                }
            }
        }
    }
    return -1;
}

bool canJumpLeft(MyArray* repeats, int id, bool* isNumeric, int* backwardID)
{
    *isNumeric = false;
    
    if (id >= 0 && id < (int) repeats->count) {
        
        int findBackwardID = findBackwardOfNumeric(repeats, id);
        RepeatNode *node = (RepeatNode *)repeats->objects[id];
        
        if (findBackwardID >= 0 && findBackwardID < (int) repeats->count) {
            *isNumeric = true;
            RepeatNode *back_repeat=(RepeatNode *)repeats->objects[findBackwardID];
            if (back_repeat->access <= node->numeric->getJumpCount())
                //if (repeats->objects[findBackwardID].access_ <= repeats->objects[id].numeric_->getJumpCount())
            {
                *backwardID = findBackwardID;
                return true;
            }
        }
        
        // other
        //RepeatNode& node = repeats->objects[id];
        
        if (node->repeatCommand == RepeatCommand_DS) {
            if (node->access == 0) {
                return true;
            }
        }
        
        if (node->repeatCommand == RepeatCommand_DC) {
            if (node->access == 0) {
                return true;
            }
        }
        
        if (node->repeatCommand == RepeatCommand_Backward) {
            if (!node->isNumericBackward && node->access
                < node->backwardRepeatCount) {
                return true;
            }
        }
    }
    return false;
}

bool canJumpRight(MyArray *repeats, int id, MyArray* probes)
{
    if (id >= 0 && id < (int) repeats->count) {
        //const RepeatNode& node = repeats->objects[id] ;
        
        RepeatNode *node=(RepeatNode *)repeats->objects[id];
        int findBackwardID = findBackwardOfNumeric(repeats, id);
        
        if (findBackwardID >= 0 && findBackwardID < (int) repeats->count) {
			int jumpCount = node->numeric->getJumpCount();
            if (node->access > jumpCount) {
                // :|| -> start -> numeric
                // :|| -> ||: -> numeric
                if (probes->count >= 2)
                {
                    Probe *prob=(Probe *)probes->objects[probes->count - 2];
                    RepeatNode *tmp=(RepeatNode *)repeats->objects[prob->toRepeatID];
                    if (tmp->repeatCommand == RepeatCommand_Backward) {
                        return true;
                    }
                }
				if (2 == node->access && 0 == jumpCount)
					return true;
            }
        }
        
        if (node->repeatCommand == RepeatCommand_ToCoda) {
            if (node->access > 0) {
                if (probes->count>= 2) {
                    Probe *prob=(Probe *)probes->objects[probes->count - 1];
                    RepeatNode *from_repeat=(RepeatNode *)repeats->objects[prob->fromRepeatID];
                    RepeatNode *to_repeat=(RepeatNode *)repeats->objects[prob->toRepeatID];
                    // ds al coda -> segno -> to coda -> coda
                    if (to_repeat->repeatCommand == RepeatCommand_Segno) {
                        if (from_repeat->repeatType == Repeat_DSAlCoda) {
                            return true;
                        }
                    }
                    
                    // dc al coda -> start -> to coda -> coda
                    if (to_repeat->repeatCommand == RepeatCommand_Start) {
                        if (from_repeat->repeatType == Repeat_DCAlCoda || from_repeat->repeatType == Repeat_DC) {
                            return true;
                        }
                    }
                }
            }
        }
    }
    return false;
}

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

bool searchBestJumpLeftRepeat(MyArray *repeats, int id, RepeatCommand *choices, int choices_count, int* jumpID)
{
    *jumpID = -1;
    
    for (int i = 0; i < (int) choices_count; ++i) {
        for (int j = id - 1; j >= 0; --j)
        {
            RepeatNode *node=(RepeatNode *)repeats->objects[j];
            if (node->repeatCommand == choices[i]) {
                *jumpID = j;
                return true;
            }
        }
    }
    return false;
}

bool searchBestJumpRightRepeat(MyArray* repeats, int id, RepeatCommand* choices, int choices_count, int* jumpID)
{
    *jumpID = -1;
    
    for (int i = 0; i < (int) choices_count; ++i) {
        for (int j = id + 1; j < (int) repeats->count; ++j) {
            RepeatNode *node=(RepeatNode *)repeats->objects[j];
            if (node->repeatCommand == choices[i]) {
                *jumpID = j;
                return true;
            }
        }
    }
    return false;
}

void MeasureToTick::TraverseRepeats(MyArray *repeats, int startID, int currentID, int pass, MyArray* probes, bool* stopped)
{
	if (*stopped)
		return;
    
	if (currentID < 0 || currentID >= (int) repeats->count) {
		//NSLog("MeasureToTick::TraverseRepeats currentID out of range!");
		return;
	}
    
	// stop
    RepeatNode* cur_repeat=(RepeatNode*)repeats->objects[currentID];
    if (canStop(cur_repeat)) {
        if (startID < currentID) {
            Probe *probe=new Probe();
            probe->fromRepeatID=startID;
            probe->toRepeatID = currentID;
            probe->action = Action_Play;
            probe->pass = pass;
            probes->addObject(probe);
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
        RepeatNode *search_node=(RepeatNode *)repeats->objects[searchID];
        RepeatCommand  choices[4];
        int choices_count = getJumpChoice(search_node->repeatCommand, choices);
        int jumpID = -1;
        
        bool find = searchBestJumpLeftRepeat(repeats, searchID, choices,choices_count, &jumpID);
        
        if (find) {
            
            if (startID < searchID) {
                Probe *probe= new Probe();
                probe->fromRepeatID=startID;
                probe->toRepeatID=searchID;
                probe->action=Action_Play;
                probe->pass=pass;
                probes->addObject(probe);
                //				probes.push_back(Probe(startID, searchID, Action_Play, pass));
            }
            
            Probe *probe=new Probe();
            probe->fromRepeatID=searchID;
            probe->toRepeatID=jumpID;
            probe->action=Action_Jump;
            probe->pass=pass;
            probes->addObject(probe);
            //probes.push_back(Probe(searchID, jumpID, Action_Jump, pass));
            
            updateAccess(repeats, currentID, searchID);
            TraverseRepeats(repeats, jumpID, jumpID, pass + 1, probes, stopped);
        }
    }
    
    // jump right
    if (jumpRight) {
        //		QList<RepeatCommand> choices = getJumpChoice(repeats->objects[currentID].repeatCommand_);
        RepeatNode *cur_node=(RepeatNode *)repeats->objects[currentID];
        RepeatCommand  choices[4];
        int choices_count = getJumpChoice(cur_node->repeatCommand, choices);
        
        int jumpID = -1;
        bool find = searchBestJumpRightRepeat(repeats, currentID, choices,choices_count, &jumpID);
        
        if (find) {
            
            if (startID < currentID) {
                Probe *probe=new Probe();
                probe->fromRepeatID=startID;
                probe->toRepeatID=currentID;
                probe->action=Action_Play;
                probe->pass=pass;
                probes->addObject(probe);
                
                //				probes.push_back(Probe(startID, currentID, Action_Play, pass));
            }
            
            Probe *probe=new Probe();
            probe->fromRepeatID=currentID;
            probe->toRepeatID=jumpID;
            probe->action=Action_Jump;
            probe->pass=pass;
            probes->addObject(probe);
            //			probes.push_back(Probe(currentID, jumpID, Action_Jump, pass));
            updateAccess(repeats, currentID, currentID);
            TraverseRepeats(repeats, jumpID, jumpID, pass, probes, stopped);
        }
    }
    
    // play
    updateAccess(repeats, currentID, currentID);
    TraverseRepeats(repeats, startID, currentID+1, pass, probes, stopped);
}

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

int MeasureToTick::getTick(int measure, int tick_pos)
{
    //	TimeTick *tt;
    for (int i = 0; i < tts_->count; ++i)
    {
        TimeTick *item=(TimeTick *)tts_->objects[i];
        if (measure >= item->measure)
        {
            if (i==tts_->count-1) {
                int measuresTick = (measure - item->measure) * getMeasureTick(quarter_, item->numerator, item->denominator);
                return item->tick + measuresTick + tick_pos;
            }
            if (i<tts_->count-1) {
                TimeTick *next_item=(TimeTick *)tts_->objects[i+1];
                if (measure < next_item->measure) {
                    int measuresTick = (measure - item->measure) * getMeasureTick(quarter_, item->numerator, item->denominator);
                    return item->tick + measuresTick + tick_pos;
                }
            }
        }
    }
    return 0;
}

int MeasureToTick::getMeasure(int tick)
{
    if (tick==0) {
        return 0;
    }
    
    for (int i=0;i<mts_->count;i++)
    {
        MeasureTick *mt = (MeasureTick *)mts_->objects[i];
        if (tick>=mt->absoluteTick && tick<mt->absoluteTick+mt->duration) {
            return mt->measure;
        }
    }
    return ove->measures.size()-1;
}

void MeasureToTick::buildMts()
{
    if (mts_==NULL) {
        mts_= new MyArray();
    }else{
        mts_->removeAllObjects();
    }
    MeasureTick *prev_mt=NULL;
    for (int i=0; i<segments_->count; i++)
    {
        Segment *item=(Segment *)segments_->objects[i];
        for (int j=item->measure; j<item->measure+item->measureCount; j++)
        {
            MeasureTick *mt=new MeasureTick;// [[MeasureTick alloc]init];
            mts_->addObject(mt);
            mt->measure=j;
            mt->duration=0;
            mt->absoluteTick = item->relativeTick+(getTick(j, 0)-getTick(item->measure, 0));
            if (prev_mt) {
                prev_mt->duration=mt->absoluteTick-prev_mt->absoluteTick;
            }
            prev_mt=mt;
            
        }
    }
#if 0
    for (int i=0;i<mts_.count;i++)
    {
        MeasureTick *mt = mts_[i];
        NSLog(@"%d:measure(%d):(%d,%d) paizi:%f",i,mt.measure,mt.absoluteTick,mt.duration, mt.duration/(quarter_/2.0));
    }
#endif
}

void MeasureToTick::build(VmusMusic* ove, int quarter)
{
	int currentTick = 0;
	int measureCount = ove->measures.size();// ove->getMeasureCount();
    
	quarter_ = quarter;
    this->ove=ove;
	this->ove = ove;//[ove retain];
    if (tts_!=NULL) {
        tts_->removeAllObjects();
    }else{
        //tts_=new TimeTick;
        tts_= new MyArray();// [[NSMutableArray alloc]init ];
    }
    
	for (int i = 0; i < ove->measures.size(); i++)
	{
		OveMeasure* measure = ove->measures[i].get();
        //		TimeSignature* time = measure->getTime();
		TimeTick *tt=new TimeTick;
        bool change = false;
        
		tt->tick = currentTick;
		tt->numerator = measure->numerator;// time->getNumerator();
		tt->denominator = measure->denominator;// time->getDenominator();
		tt->measure = i;
        
		if (i == 0) {
			change = true;
		} else {
			OveMeasure* prevMeasure = ove->measures[i-1].get();
            //			OVE::TimeSignature* previousTime = this->ove->getMeasure(i - 1)->getTime();
            
			if (measure->numerator != prevMeasure->numerator || measure->denominator!=prevMeasure->denominator)
            {
                change = true;
			}
		}
        
        currentTick += quarter_ * 4 * tt->numerator / tt->denominator;
        
		if (change) {
            tts_->addObject(tt);
		}else{
            delete tt;
        }
	}
    
	buildSegments();
    buildMts();
}

void MeasureToTick::AddRepeatNode(MyArray* repeats, RepeatNode *node)
{
    for (int i = 0; i < repeats->count; ++i) {
        RepeatNode *item=(RepeatNode *)repeats->objects[i];
		if (item->measure == node->measure && item->repeatCommand == node->repeatCommand) {
			delete node;
			return;
		}
	}
	repeats->addObject(node);
}

bool MeasureToTick::RepeatType2Left(RepeatType type)
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

RepeatCommand MeasureToTick::RepeatType2Command(RepeatType type) {
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

int MeasureToTick::compair_repeat_note( RepeatNode* data1,  RepeatNode* data2, void* user)
{
    if (data1->measure != data2->measure)
        return data1->measure > data2->measure;
    
    if (data1->atLeft != data2->atLeft)
        return !data1->atLeft;
    
    return data1->nodeType > data2->nodeType;
}

void MeasureToTick::sortRepeatNotes(MyArray* repeats)
{
    int len=repeats->count;
    for(int i=0;i<len;i++)
    {
        for(int j=0;j<len-i-1;j++)
        {
            RepeatNode *r1=(RepeatNode *)repeats->objects[j];
            RepeatNode *r2=(RepeatNode *)repeats->objects[j+1];
            
            if (compair_repeat_note(r1, r2, NULL)) {
                repeats->objects[j]=r2;
                repeats->objects[j+1]=r1;
            }
        }
    }
}

MyArray* MeasureToTick::getAllRepeats()
{
	int i;
	int j;
	int k;
	int l;
    MyArray * repeats=new MyArray();//=[[NSMutableArray alloc]init];
	int trackBarCount = (unsigned int) this->ove->measures.size();// ->getTrackBarCount();
    
	if (trackBarCount > 0) {
		RepeatNode *startnode=new RepeatNode();
        
		startnode->measure = 0;
		startnode->measureCount = 0;
		startnode->atLeft = true;
		startnode->nodeType = NodeType_None;
		startnode->repeatType = Repeat_Null;
		startnode->barline = Barline_Default;
		startnode->repeatCommand = RepeatCommand_Start;
        
        AddRepeatNode(repeats,startnode);
	}
    
	//for (i = 0; i < this->ove->getPartCount(); ++i)
    {
		int partStaffCount = 1;//this->ove->getStaffCount(i);
        
		for (j = 0; j < partStaffCount; ++j) {
			//Track* trackPtr = this->ove->getTrack(i, j) ;
            
			for (k = 0; k < trackBarCount; ++k) {
				OveMeasure* measure = ove->measures[k].get();// ->getMeasure(k);
                //				OveMeasureData* measureData = this->ove->getMeasureData(i, j, k);
                int barIndex = measure->number;// ->getBarNumber()->getIndex();
                
                // repeat symbol
                //QList<OVE::MusicData*> measureRepeats = measureData->getMusicDatas(OVE::MusicData_Repeat);
                
                //for (l = 0; l < this->ove->measures.count; ++l)
                {
                    
                    if (measure->repeat_type != Repeat_Null) {
                        RepeatNode *node=new RepeatNode();
                        
                        node->nodeType = NodeType_RepeatSymbol;
                        node->measure =  measure->number;// repeat->start()->getMeasure();
                        node->measureCount = 0;
                        node->atLeft = RepeatType2Left(measure->repeat_type);
                        node->repeatType = measure->repeat_type; //repeat->getRepeatType();
                        node->repeatCommand = RepeatType2Command(measure->repeat_type);
                        
                        AddRepeatNode(repeats, node);
                    }
                }
                
                // barline : forward / backward
                for (l = 0; l < 2; ++l) {
					if (checkIsRepeatPlay && !measure->repeat_play) {
						printf("ignore repeat for measure:%d(%d)\n", measure->number, measure->show_number);
					} else {
						BarlineType barline = (l == 0) ? measure->left_barline : measure->right_barline;

						if (barline == Barline_RepeatLeft || barline == Barline_RepeatRight) {
							RepeatNode *node=new RepeatNode();

							node->nodeType = NodeType_Barline;
							node->measure = barIndex;
							node->measureCount = 0;
							node->atLeft = l == 0;
							node->repeatCommand = (barline == Barline_RepeatLeft) ? RepeatCommand_Forward : RepeatCommand_Backward;
							node->repeatType = Repeat_Null;
							node->barline = barline;
							node->backwardRepeatCount = measure->repeat_count;// ->getBackwardRepeatCount();
							if (node->backwardRepeatCount==0) {
								node->backwardRepeatCount=1;
							}
							AddRepeatNode(repeats, node);
						}
					}
                }
                
                // numeric ending
                /*
                 const QList<OVE::MusicData*> numerics = measureData->getCrossMeasureElements(
                 OVE::MusicData_Numeric_Ending, OVE::MeasureData::PairType_Start);
                 */
				for (auto it = measure->numerics.begin(); it != measure->numerics.end(); it++)
                {
                    NumericEnding *num=it->get();
                    if (num->pos.start_offset || num->pos.tick) {
                        //					NumericEnding* numeric = dynamic_cast<OVE::NumericEnding*> (numerics[l]);
                        RepeatNode *node=new RepeatNode();
                        
                        node->nodeType = NodeType_NumericEnding;
                        node->measure = barIndex;
                        node->measureCount = num->numeric_measure_count;//numeric->stop()->getMeasure();
                        node->atLeft = true;
                        node->repeatCommand = RepeatCommand_NumericEnding;
                        node->numeric = num;
                        //					node->numeric = numeric;
                        
                        AddRepeatNode(repeats, node);
                    }
                }
            }
        }
    }
    
    if (trackBarCount > 0) {
        RepeatNode *endnode=new RepeatNode();
        
        endnode->measure = trackBarCount - 1;
        endnode->measureCount = 0;
        endnode->atLeft = false;
        endnode->nodeType = NodeType_None;
        endnode->repeatType = Repeat_Null;
        endnode->barline = Barline_Default;
        endnode->repeatCommand = RepeatCommand_End;
        
        AddRepeatNode(repeats, endnode);
    }
    
    sortRepeatNotes(repeats);
    
    //	sort(repeats.begin(), repeats.end(), CompareRepeatNode());
    for (i = 0; i < repeats->count; ++i) {
        RepeatNode *repeat=(RepeatNode *)repeats->objects[i];
		NumericEnding* numeric = repeat->numeric;
		if (repeat->repeatCommand == RepeatCommand_NumericEnding)// && numeric	!= NULL)
        {
			int measure = numeric->pos.start_offset;// numeric->start()->getMeasure();
			int measureCount = repeat->measureCount;// numeric->stop()->getMeasure();
            
			for (j = i + 1; j < repeats->count; ++j)
            {
                RepeatNode *item=(RepeatNode *)repeats->objects[j];
				if (item->repeatCommand == RepeatCommand_Backward
                    && item->measure == measure + measureCount) {
					item->isNumericBackward = true;
				}
			}
		}
	}
    return repeats;
}
                                                                           
void MeasureToTick::buildSegments()
{
	bool basic = false;
    
    if (segments_==NULL) {
        segments_=new MyArray();//[[NSMutableArray alloc]init];
    }else{
        segments_->removeAllObjects();
        //[segments_ removeAllObjects];
    }
    
	if (basic) {
		Segment *segment=new Segment;
        segment->measure = 0;
		segment->measureCount = this->ove->measures.size();// ->getMeasureCount();
		segment->command = RepeatCommand_None;
		segment->fromMeasure = 0;
		segment->fromCommand = RepeatCommand_Start;
        //segments_=segment;
        segments_->addObject(segment);
	} else {
		//int measureCount = this->ove->get_measure_count() ;
		MyArray *repeats =getAllRepeats();
		MyArray *probes=new MyArray();//[[NSMutableArray alloc]init];
		bool stopped = false;
        
		TraverseRepeats(repeats, 0, 0, 0, probes, &stopped);

#if 0
		//dump repeats
		for (int i = 0; i < repeats->count; i++) {
			RepeatNode* r = (RepeatNode*)repeats->objects[i];
			printf("%d:%d,%d,%d,%d,%d\n", i, r->measure, r->measureCount, r->repeatCommand, r->nodeType, r->repeatType);
		}
		//dump probes
		for (int i = 0; i < probes->count; i++) {
			Probe* r = (Probe*)probes->objects[i];
			RepeatNode* from = (RepeatNode*)repeats->objects[r->fromRepeatID];
			RepeatNode* to = (RepeatNode*)repeats->objects[r->toRepeatID];
			printf("%d:%d-%d,%d->%d %d, %d\n", i, r->fromRepeatID, r->toRepeatID, from->measure, to->measure, r->action, r->pass);
		}
#endif
        
		for (int i = 0; i < probes->count; ++i) {
            Probe *prob=(Probe *)probes->objects[i];
            if (prob->action == Action_Play) {
                Segment *segment=new Segment();
                RepeatNode *fromNode=(RepeatNode *)repeats->objects[prob->fromRepeatID];
                RepeatNode *toNode=(RepeatNode *)repeats->objects[prob->toRepeatID];
                
                segment->measure = fromNode->measure;
                if (!RepeatCommand2Left(fromNode->repeatCommand)) {
                    segment->measure+=1;
                }
                
                segment->measureCount = toNode->measure - segment->measure;
                if (!RepeatCommand2Left(toNode->repeatCommand)) {
                    ++segment->measureCount;
                }
                
                segment->command = fromNode->repeatCommand;
                segment->fromMeasure = segment->measure;
                segment->fromCommand = segment->command;
                if (i>0)
                {
                    Probe *prev_prob=(Probe *)probes->objects[i-1];
                    if (prev_prob->action == Action_Jump)
                        //if (i > 0 && probes[i - 1].action_ == Action_Jump)
                    {
                        RepeatNode *tmp=(RepeatNode *)repeats->objects[prev_prob->fromRepeatID];
                        segment->fromMeasure = tmp->measure;
                        segment->fromCommand = tmp->repeatCommand;
                    }
                }
                segments_->addObject(segment);
            }
        }
        Delete_MyArray(Probe, probes);
        Delete_MyArray(RepeatNode, repeats);
    }
    
    int tick = 0;
    for (int i = 0; i < segments_->count; ++i) {
        Segment *segment = (Segment *)segments_->objects[i];
        
        int beginTick = getTick(segment->measure, 0);
        int endTick = getTick(segment->measure + segment->measureCount, 0);
        
        segment->relativeTick = tick;
        segment->absoluteTick = beginTick;
        
        tick += endTick - beginTick;
		//printf("%d:%d-%d,%d\n", i, segment->measure, segment->measure+segment->measureCount, segment->command);
    }
}

const char* MeasureToTick::Repeat2String(RepeatCommand cmd)
{
    //	QString str = QString();
    const char *str=NULL;
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
    return str;
}

int MeasureToTick::getMeasureWithPercent(float percent)
{
    if (percent==0) {
        return 0;
    }
    MeasureTick *last_mt=(MeasureTick *)mts_->lastObject();
    int total_tick=last_mt->absoluteTick+last_mt->duration;
    int tick=static_cast<int>(total_tick*percent);
    for (int i=0;i<mts_->count;i++)
    {
        MeasureTick *mt = (MeasureTick *)mts_->objects[i];
        if (tick>=mt->absoluteTick && tick<mt->absoluteTick+mt->duration) {
            return mt->measure;
        }
    }
    return this->ove->measures.size()-1;
}

int MeasureToTick::getMeasureWithTick(int tick)
{
    if (tick==0) {
        return 0;
    }
    
    for (int i=0;i<mts_->count;i++)
    {
        MeasureTick *mt = (MeasureTick *)mts_->objects[i];
        if (tick>=mt->absoluteTick && tick<mt->absoluteTick+mt->duration) {
            return mt->measure;
        }
    }
    return this->ove->measures.size()-1;
}