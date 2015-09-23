#pragma once

#include "stdafx.h"
#include "ParseExport.h"

#define	LIST_ELEMENT_HEIGHT		21
#define	READ_PIPE_BUFFER_LEN		4096
#define	CHECK_LOG_FILE					".\\midi-xml.log"

typedef enum
{
	ENUM_TRAVERSE_STATISTIC = 0,
	ENUM_TRAVERSE_PROCESS,
} TRAVERSE_USAGE;

typedef enum
{
	ENUM_RESOURCE_NONE = 0,
	ENUM_RESOURCE_XML,
	ENUM_RESOURCE_MIDI,
} RESOURCE_TYPE;

void DepthFirstTraverseDir(const std::string strRootDir, void (*pf)(void*, std::string&), void* pProcessor);

class CMenuWnd : public WindowBasedOnXML
{
public:
	explicit CMenuWnd(LPCTSTR pszXMLPath) : WindowBasedOnXML(pszXMLPath) {}
protected:
	virtual ~CMenuWnd() {}		//privatize the destructor, so the object only can be created by `new` that ensure the `delete this` operation wouldn't go wrong.

public:
	void Init(DuiLib::CControlUI* pOwner, POINT& ptPos);
	virtual void OnFinalMessage( HWND hWnd ) { delete this; }
	virtual void Notify(DuiLib::TNotifyUI& msg);
	virtual LRESULT OnKillFocus(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);

protected:
	DuiLib::CControlUI* m_pOwner;
};

class CMainWindow : public WindowBasedOnXML
{
public:
	explicit CMainWindow(LPCTSTR pszXMLPath);

	virtual void InitWindow();
	virtual void Notify(DuiLib::TNotifyUI& msg);
	virtual LRESULT HandleMessage(UINT uMsg, WPARAM wParam, LPARAM lParam);
	virtual void OnFinalMessage( HWND hWnd );

protected:
	void OnCreateMenu(DuiLib::TNotifyUI& msg, bool& bHandled);
	void OnSetFocus(DuiLib::TNotifyUI& msg, bool& bHandled);
	void OnButtonClick(DuiLib::TNotifyUI& msg, bool& bHandled);
	void OnSelectChanged(DuiLib::TNotifyUI& msg, bool& bHandled);
	void OnDeleteListElement(DuiLib::TNotifyUI& msg, bool& bHandled);
	void OnDropFiles(HDROP hDropInfo, bool& bHandled);

protected:
	void GetDefaultEditor();
	void DetectThreadFinish();
	void SearchListMatchedMidi(const std::string& strXmlFile);
	void TraverseListElement(void (*pf)(void*, std::string&), TRAVERSE_USAGE eUsage);
	HANDLE CreatePipeAndThread();
	void ProcessResourceFile(std::string& strSrcFileName, RESOURCE_TYPE eResType);
	bool CheckXmlBelongList(const std::string& strXmlFile, std::string& strMidiFile, std::string& strSPMidiFile);
	void WriteScoreHtml(MidiFile* midi, const char* pHtmlFileName);

	static void StatisticCallback(void* pInstance, std::string& strFileName);
	static void ProcessCallback(void* pInstance, std::string& strFileName);
	static unsigned int __stdcall StartExecuteTask(void* pArg);
	static unsigned int __stdcall MainTaskThread(void* pArg);

protected:
	CMenuWnd* m_pRButtonMenu;
	DuiLib::CListUI* m_pFileAndFolderList;
	DuiLib::CCheckBoxUI* m_pXmlExistCheckBox;
	DuiLib::CButtonUI* m_pStartBtn;
	DuiLib::CButtonUI* m_pClearBtn;
	DuiLib::CButtonUI* m_pOpenLogBtn;
	DuiLib::CProgressUI* m_pRunProgress;
	DuiLib::CRichEditUI* m_pConsoleText;
	TOOL_USAGE m_eUsage;
	size_t m_nTotalMusicScores, m_nProcessedScores;
	std::multimap<std::string, std::string> m_mXmlMidiMap;		//it->first: xml, it->second: midi

	HANDLE m_hStartThread;
	HANDLE m_hReadPipe, m_hWritePipe;
	FILE* m_pLogFile;
	DuiLib::CDuiString m_strCmdLine;
	char m_pPipeBuffer[READ_PIPE_BUFFER_LEN+1];
	MusicXMLParser m_mXmlParser;
};