//
//  MeasureToTick.h
//  ReadStaff
//
//  Created by yan bin on 11-10-20.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MusicOve.h"

#if 1
typedef enum  {
	NodeType_Barline,
	NodeType_RepeatSymbol,
	NodeType_NumericEnding,
	NodeType_None
}NodeType;
#else
typedef enum  {
	NodeType_RepeatSymbol = 0,
	NodeType_Barline,
	NodeType_NumericEnding,
	NodeType_None
}NodeType;
#endif

typedef enum {
	RepeatCommand_Start = 0,
	RepeatCommand_End, //��Ȼ����
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

@interface Segment : NSObject {
	int measure;
	int measureCount;
	int relativeTick;
	int absoluteTick;
	RepeatCommand command;
	int fromMeasure;
	RepeatCommand fromCommand;
};
@property (nonatomic, assign) int measure, measureCount, relativeTick, absoluteTick, fromMeasure;
@property (nonatomic, assign) RepeatCommand command, fromCommand;
    /*
     Segment() :
     measure_(0), measureCount_(0), relativeTick_(0), absoluteTick_(0),
     command_(RepeatCommand_None), fromMeasure_(0) {	}
     Segment(int measure, int measureCount, RepeatCommand repeatCommand,
     int relativeTick = 0, int absoluteTick = 0, int fromMeasure = 0,
     RepeatCommand fromCommand = RepeatCommand_None) :
     measure_(measure), measureCount_(measureCount), relativeTick_(
     relativeTick), absoluteTick_(absoluteTick), command_(
     repeatCommand), fromMeasure_(fromMeasure), fromCommand_(
     fromCommand) {
     }
     
     int getOffsetTick() const {
     return relativeTick_ - absoluteTick_;
     }
     */
- (int) getOffsetTick;

@end
    
@interface RepeatNode : NSObject {
	int measure;
	int measureCount;
	RepeatCommand repeatCommand;
	int access;
    
	bool atLeft;
	NodeType nodeType;
	RepeatType repeatType;
	BarlineType barline;
	bool isNumericBackward; //numericĩβ��:||���
	int backwardRepeatCount; //:||��������
    NumericEnding* numeric;
    //int numberic_start_measure;
    /*
     RepeatNode() :
     measure_(0), measureCount_(0), repeatCommand_(RepeatCommand_None),
     access_(0), atLeft_(true), nodeType_(NodeType_RepeatSymbol),
     repeatType_(OVE::Repeat_Null), barline_(OVE::Barline_Default),
     isNumericBackward_(false), backwardRepeatCount_(0), numeric_(
     NULL) {
     }
     */
};
@property (nonatomic, assign) int measure, measureCount, access, backwardRepeatCount;
@property (nonatomic, assign) bool atLeft, isNumericBackward;
@property (nonatomic, assign) RepeatCommand repeatCommand;
@property (nonatomic, assign) NodeType nodeType;
@property (nonatomic, assign) RepeatType repeatType;
@property (nonatomic, assign) BarlineType barline;
@property (nonatomic, strong) NumericEnding* numeric;
@end

typedef enum {
	Action_Play = 0, Action_Jump, Action_Stop,
    
	Action_None
}Action;

@interface Probe : NSObject {
	int fromRepeatID;
	int toRepeatID;
	Action action;
	int pass;
    /*
     Probe() : fromRepeatID_(-1), toRepeatID_(-1), action_(Action_Stop), pass_(-1) {}
     Probe(int fromRepeatID, int toRepeatID, Action action, int pass) :
     fromRepeatID_(fromRepeatID), toRepeatID_(toRepeatID), action_(action),
     pass_(pass) {}
     */
};
@property (nonatomic, assign) int fromRepeatID, toRepeatID, pass;
@property (nonatomic, assign) Action action;
@end

struct Cursor {
	int repeatID_;
	int pass_;
};

@interface TimeTick : NSObject {
    int numerator;
    int denominator;
    int measure;
    int tick;
    
//    TimeTick() : numerator_(4), denominator_(4), measure_(0), tick_(0) {}
};
@property (nonatomic, assign) int numerator, denominator, measure, tick;
@end

/*
 void build(OVE::OveSong* ove, int quarter);
 
 int getTick(int measure, int tick_pos);
 
 QList<TimeTick> getTimeTicks() const;
 
 QList<Segment> getSegments() const;
 
 private:
 void buildSegments();
 
 // prepare repeats
 QList<RepeatNode> getAllRepeats();
 
 static bool RepeatType2Left(OVE::RepeatType type);
 static RepeatCommand RepeatType2Command(OVE::RepeatType type);
 
 // traverse
 void TraverseRepeats(QList<RepeatNode>& repeats, int startID,
 int currentID, int pass, QList<Probe>& probes, bool& stopped);
 
 bool canJumpLeft(const QList<RepeatNode>& repeats, int id, bool& isNumeric, int& backwardID);
 bool canJumpRight(const QList<RepeatNode>& repeats, int id, const QList<Probe>& probes);
 
 static QList<RepeatCommand> getJumpChoice(RepeatCommand command);
 
 bool searchBestJumpLeftRepeat(QList<RepeatNode>& repeats, int id,
 const QList<RepeatCommand>& choices, int& jumpID);
 
 bool searchBestJumpRightRepeat(QList<RepeatNode>& repeats,
 int id, const QList<RepeatCommand>& choices, int& jumpID);
 
 static bool canStop(const RepeatNode& node);
 static void updateAccess(QList<RepeatNode>& repeats, int startID,	int stopID);
 
 private:
 int quarter_;
 OVE::OveSong* ove_;
 
 QList<TimeTick> tts_;
 QList<Segment> segments_;
 };
 */

@interface MeasureTick : NSObject {
    int absoluteTick; //从开始到现在的ticks
    int absoluteMs; //从开始到现在的ms
    int duration; //当前小节的ticks
    int measure; //小节编号
}
@property (nonatomic,assign)int absoluteTick,measure,duration;
@end


@interface MeasureToTick : NSObject {
    int quarter_;
    
    NSMutableArray *tts_; //TimeTick
    NSMutableArray *segments_; //Segment;
    NSMutableArray *mts_; //MeasureTick
}
@property (nonatomic, readonly) NSMutableArray *segments, *tts;
@property (nonatomic, assign) BOOL checkIsRepeatPlay;
-(void) build:(OveMusic*) ove quarter:(int) quarter;
-(int) getTick:(int) measure pos:(int) tick_pos;
-(int) getMeasure:(int) tick;
-(int) getMeasureWithTick:(int) tick;
-(int) getMeasureWithPercent:(float)percent;
-(int) getMeasureTick:(int) measureID;
+(NSString*)Repeat2String:(RepeatCommand) cmd;
@end
