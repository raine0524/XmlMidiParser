//
//  MeasureToTick.h
//  ReadStaff
//
//  Created by yanbin on 14-8-6.
//
//

#ifndef ReadStaff_MeasureToTick_h
#define ReadStaff_MeasureToTick_h

typedef enum  {
	NodeType_Barline,
	NodeType_RepeatSymbol,
	NodeType_NumericEnding,
	NodeType_None
}NodeType;

typedef enum {
	RepeatCommand_Start = 0,
	RepeatCommand_End,
	RepeatCommand_Forward,
	RepeatCommand_Backward,
	RepeatCommand_Segno,
	RepeatCommand_ToCoda,
	RepeatCommand_Coda,
	RepeatCommand_DC,
	RepeatCommand_DS,
	RepeatCommand_Fine,
	RepeatCommand_NumericEnding,
    
	RepeatCommand_None
}RepeatCommand;


class Segment:public MyObject {
private:
    
public:
    ~Segment() {}
    
    int measure, measureCount, relativeTick, absoluteTick, fromMeasure;
    RepeatCommand command, fromCommand;
    
    Segment() : measure(0), measureCount(0), relativeTick(0), absoluteTick(0), command(RepeatCommand_None), fromMeasure(0) {}
    Segment(int measure, int measureCount, RepeatCommand repeatCommand,
            int relativeTick = 0, int absoluteTick = 0, int fromMeasure = 0,
            RepeatCommand fromCommand = RepeatCommand_None) :
    measure(measure), measureCount(measureCount), relativeTick(relativeTick), absoluteTick(absoluteTick), command(repeatCommand), fromMeasure(fromMeasure), fromCommand( fromCommand) {
    }
    
    int getOffsetTick() const {
        return relativeTick - absoluteTick;
    }
    
};

class RepeatNode:public MyObject {
private:
    /*
	int measure;
	int measureCount;
	RepeatCommand repeatCommand;
	int access;
    
	bool atLeft;
	NodeType nodeType;
	RepeatType repeatType;
	BarlineType barline;
	bool isNumericBackward;
	int backwardRepeatCount;
    NumericEnding* numeric;
     */
    //int numberic_start_measure;
public:
	RepeatNode()
		:measure(0)
		,measureCount(0)
		,access(0)
		,backwardRepeatCount(0)
		,atLeft(true)
		,isNumericBackward(false)
		,repeatCommand(RepeatCommand_None)
		,nodeType(NodeType_RepeatSymbol)
		,repeatType(Repeat_Null)
		,barline(Barline_Default)
		,numeric(NULL)
	{
	}
    
    int measure, measureCount, access, backwardRepeatCount;
    bool atLeft, isNumericBackward;
    RepeatCommand repeatCommand;
    NodeType nodeType;
    RepeatType repeatType;
    BarlineType barline;
    NumericEnding* numeric;
};

typedef enum {
	Action_Play = 0, Action_Jump, Action_Stop,
    
	Action_None
}Action;

class Probe: public MyObject {
private:
    /*
     Probe() : fromRepeatID_(-1), toRepeatID_(-1), action_(Action_Stop), pass_(-1) {}
     Probe(int fromRepeatID, int toRepeatID, Action action, int pass) :
     fromRepeatID_(fromRepeatID), toRepeatID_(toRepeatID), action_(action),
     pass_(pass) {}
     */
public:
	Probe()
		:fromRepeatID(0)
		,toRepeatID(0)
		,pass(0)
		,action(Action_None)
	{
	}
	~Probe() {}
    int fromRepeatID, toRepeatID, pass;
    Action action;
};

struct Cursor {
	int repeatID_;
	int pass_;
	Cursor()
	{
		memset(this, 0, sizeof(Cursor));
	}
};

class TimeTick:public MyObject  {
private:
    //    TimeTick() : numerator_(4), denominator_(4), measure_(0), tick_(0) {}
public:
	TimeTick()
	{
		memset(this, 0, sizeof(TimeTick));
	}
	~TimeTick() {}
    int numerator, denominator, measure, tick;
};

class MeasureTick:public MyObject  {
private:
    int absoluteMs; //从开始到现在的ms
public:
    int absoluteTick; //从开始到现在的ticks
    int measure; //小节编号
    int duration; //当前小节的ticks
	MeasureTick()
	{
		memset(this, 0, sizeof(MeasureTick));
	}
    ~MeasureTick() {}
};

class MeasureToTick {
private:
    VmusMusic* ove;
    int quarter_;
    
    MyArray *mts_; //MeasureTick
    void buildSegments();
    MyArray* getAllRepeats();
    void AddRepeatNode(MyArray* repeats, RepeatNode *node);
    bool RepeatType2Left(RepeatType type);
    RepeatCommand RepeatType2Command(RepeatType type);
    int compair_repeat_note(RepeatNode* data1,  RepeatNode* data2, void* user);
    void sortRepeatNotes(MyArray* repeats);
    void TraverseRepeats(MyArray *repeats, int startID, int currentID, int pass, MyArray* probes, bool* stopped);
    int getTick(int measure, int tick_pos);
    int getMeasure(int tick);
    void buildMts();
    const char* Repeat2String(RepeatCommand cmd);
    int getMeasureWithPercent(float percent);
    int getMeasureWithTick(int tick);
public:
	MeasureToTick()
		:ove(NULL)
		,quarter_(0)
		,mts_(NULL)
		,tts_(NULL)
		,segments_(NULL)
		,checkIsRepeatPlay(false)
	{
	}
    ~MeasureToTick();
    
    MyArray *tts_; //TimeTick
    MyArray *segments_; //Segment;
	bool checkIsRepeatPlay;
    void build(VmusMusic* ove, int quarter);
    /*
    -(int) getTick:(int) measure pos:(int) tick_pos;
    -(int) getMeasure:(int) tick;
    -(int) getMeasureWithTick:(int) tick;
    -(int) getMeasureWithPercent:(float)percent;
    -(int) getMeasureTick:(int) measureID;
    +(NSString*)Repeat2String:(RepeatCommand) cmd;
     */
};

#endif
