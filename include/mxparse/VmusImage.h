//
//  VmusImage.h
//  ReadStaff
//
//  Created by yanbin on 14-8-6.
//
//

#ifndef ReadStaff_VmusImage_h
#define ReadStaff_VmusImage_h

#define	MAX_POS_NUM 30
#define	DISCREATE_POINT_DISTANCE	5		//pixels

typedef enum
{
	OBLIQUE_PROJECTILE,
	LOGISTIC_MOTION
} MOTION_TYPE;

struct NotePos
{
    int start_y[MAX_POS_NUM];
    unsigned char page,staff;
    unsigned short width,height;
    int start_x;
    int part_index;			//for MusicXML multi part, for OVE: always =0
    float timeStamp;		//for midi play

	NotePos()
	{
		memset(this, 0, sizeof(NotePos));
	}
};

struct MeasurePos
{
    unsigned char page;
    unsigned short width,height;
    int start_x, start_y;
    int note_count;
	std::vector<std::shared_ptr<NotePos> > note_pos;

	MeasurePos()
		:page(0)
		,width(0)
		,height(0)
		,start_x(0)
		,start_y(0)
		,note_count(0)
	{
	}
};

struct PARSE_DLL CGSize {
	float width;
	float height;

	CGSize()
	{
		memset(this, 0, sizeof(CGSize));
	}
};

typedef struct tagPosition{
	float x;
	float y;

	tagPosition()
	{
		memset(this, 0, sizeof(tagPosition));
	}
} Position;

typedef struct MyRectTag {
	tagPosition origin;
	CGSize size;

	MyRectTag()
	{
		memset(this, 0, sizeof(MyRectTag));
	}
} MyRect;

std::string& trim(std::string& s);

class PARSE_DLL VmusImage
{
private:
	std::vector<MeasurePos>* measure_pos;
	const std::vector<Event>* MidiEvents;
    float screen_width, screen_height, page_height;
    int densitydpi, last_fifths;
    bool isLandscape;
    
    float LINE_H;
    int MARGIN_LEFT;
    int MARGIN_RIGHT;
    int MARGIN_TOP;
    int GROUP_STAFF_MID;
    float STAFF_HEADER_WIDTH;
    
    int GROUP_STAFF_NEXT;
    int STAFF_OFFSET[20];
	CGSize real_screen_size;
	bool landPageMode;
    
	float BARLINE_WIDTH, BEAM_WIDTH;
    float OFFSET_X_UNIT,OFFSET_Y_UNIT;
    float ending_x1,ending_y1;

	MyString *svgXmlContent, *svgMeasurePosContent, *svgXmlJianpuContent, *svgXmlJianpuFixDoContent;
	MyString *svgForceCurveContent;
	MyString *svgXmlJianwpContent;				//<g id='jianwp'></g>
	MyString *svgXmlJianwpFixDoContent;		//<g id='jianwpfixdo'></g>

private:
    void NSLog(const char* fmt,...) {}
    void LINE(float x1,float y1,float x2,float y2);
    float lineToY(int line, int staff);
	bool isNote(const std::shared_ptr<OveNote>& note, const std::shared_ptr<OveBeam>& beam);
	float checkSlurY(const std::shared_ptr<MeasureSlur>& slur, const std::shared_ptr<OveMeasure>& measure, const std::shared_ptr<OveNote>& note, float start_x, float start_y, float slurY);
    std::shared_ptr<OveNote> getNoteWithOffset(int meas_offset, int meas_pos , const std::shared_ptr<OveMeasure>& measure, int staff, int voice);
    NoteHeadType headType(std::shared_ptr<NoteElem>& elem, int staff);
	int LeastSquareFit(const std::vector<Position>& vPoint, std::vector<float>& vFactor, int nDegree);
	void AdjustForcePoint(std::vector<Position>& vForce);
	void InterPolateDP(std::vector<Position>& vDisPoint, int start_x, int end_x);
	int AddExtraPoint(std::vector<Position>& vInterPolate, Position& end_p, MOTION_TYPE type);
    bool drawSvgAccidental(AccidentalType accidental_type, float acc_x, float y, bool isGrace);
    MyRect getBeamRect(const std::shared_ptr<OveBeam>& beam, float start_x, float start_y, const std::shared_ptr<OveMeasure>& measure, bool reload);
    void drawSvgStem(MyRect beam_pos, const std::shared_ptr<OveNote>& note, float x, float y);
	void loadMusic(VmusMusic* music, const CGSize& musicSize, const CGSize& screenSize);
	int EmbeddedFileIntoSvgContent(const char* pEmbeddedFileName, MyString* pSvgContent);
    
    void drawSvgMusic();
    void beginSvgImage(CGSize size, int startMeasure = 0);
    MyString* endSvgImage();
	void beginSvgPage(const CGSize& size, int page);
	void endSvgPage();
	void drawPageBackground(const CGSize& size);
	void beginSvgLine(int line_num, float x, float y);
	void endSvgLine();
    void drawSvgTitle();
    void drawSvgCurveLine(int w, float x1, float y1, float x2, float y2, bool above);
    bool drawSvgArt(const std::shared_ptr<NoteArticulation>& art, bool art_placement_above, int x, int y, float start_y);
	void drawSvgTimeSignature(OveMeasure* measure, float x,float start_y, unsigned long staff_count);
	void drawSvgDiaohaoWithClef(ClefType clef,int key_fifths,int x, float start_y,bool stop_flag);
	void drawJianpu(OveMeasure *measure, int jianpu_start_x, int start_y);
	void drawSvgTempo(OveMeasure* first_measure, float start_x, float start_y);
	void drawSvgFiveLine(OveLine* line, float start_x, float start_y);
	void drawForceCurve(int line_num, std::map<int, std::vector<float> >& staff_xorder, int base_y, std::map<int, std::pair<int, int> >& meas_bound);

	void drawSvgRepeat(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y);
	void drawSvgTexts(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y);
	void drawSvgSlurs(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y, const std::shared_ptr<OveLine>& ove_line);
	void drawSvgTies(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y, const std::shared_ptr<OveLine>& ove_line);
	void drawSvgPedals(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y, const std::shared_ptr<OveLine>& ove_line, const std::shared_ptr<OveLine>& nextLine);
	void drawSvgTuplets(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y, const std::shared_ptr<OveLine>& ove_line);
	void drawSvgLyrics(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y);
	void drawSvgDynamics(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y);
	void drawSvgExpressions(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y);
	void drawSvgOctaveShift(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y, const std::shared_ptr<OveLine>& ove_line, int line_index);
	void drawSvgGlissandos(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y, const std::shared_ptr<OveLine>& ove_line, int line_index, int line_count);
	void drawSvgWedges(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y, const std::shared_ptr<OveLine>& ove_line, int line_index, int line_count);
	void drawSvgClefs(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y, const std::shared_ptr<OveLine>& ove_line);
	void drawSvgRest(const std::shared_ptr<OveNote>& note, const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y);
	void drawSvgTrill(const std::shared_ptr<NoteArticulation>& note_art, const std::shared_ptr<OveMeasure>& measure, const std::shared_ptr<OveNote>& note, float x, float art_y);
	float drawSvgMeasure(const std::shared_ptr<OveMeasure>& measure, float start_x, float start_y, const std::shared_ptr<OveLine>& ove_line, int line_index, int line_count);

public:
    VmusImage();
	~VmusImage();

	void loadMusic(VmusMusic* music, const CGSize& musicSize, bool landPage,  const std::vector<Event>* midi_events);
    
    VmusMusic *music;
    const char *fontContent;
    MyArray *staff_images; //array of SVG string
    
    unsigned int STAFF_COUNT;
    int start_tempo_num;
    float start_tempo_type;
    int start_numerator, start_denominator;
    bool showJianpu, pageMode;
    int minNoteValue, maxNoteValue;
	CGSize staff_size, page_size;
};
#endif
