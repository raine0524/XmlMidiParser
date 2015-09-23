#include "MainWindow.h"
#include <io.h>
#include <fcntl.h>
#include <process.h>

#pragma comment(lib, "MidiXmlParser.lib")

void DepthFirstTraverseDir(const std::string strRootDir, void (*pf)(void*, std::string&), void* pProcessor)
{
#ifdef WIN32
	WIN32_FIND_DATA FindData;
	HANDLE hFind = ::FindFirstFile(std::string(strRootDir+"*.*").c_str(), &FindData);
	if (INVALID_HANDLE_VALUE == hFind)
	{
		printf("root directory is not valid\n");
		return;
	}
	while (::FindNextFile(hFind, &FindData))
	{
		if (!strcmp(FindData.cFileName, ".") || !strcmp(FindData.cFileName, ".."))
			continue;

		if (FindData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {		//directory
			DepthFirstTraverseDir(strRootDir+FindData.cFileName+"\\", pf, pProcessor);
		} else {		//file
			pf(pProcessor, strRootDir+FindData.cFileName);
			Sleep(10);
		}
	}
	::FindClose(hFind);
#else
	struct dirent* ent = NULL;
	struct stat st;
	DIR* pDir = opendir(strRootDir.c_str());
	if (!pDir)
	{
		perror("open directory failed\n");
		return;
	}
	while (ent = readdir(pDir))
	{
		if (!strcmp(ent->d_name, ".") || !strcmp(ent->d_name, ".."))
			continue;

		if (-1 == stat(std::string(strRootDir+ent->d_name).c_str(), &st))
		{
			perror("stat");
			return;
		}

		if (S_ISDIR(st.st_mode)) {		//directory
			DepthFirstTraverseDir(strRootDir+ent->d_name+"/", pf, pProcessor);
		} else {		//file
			std::string strFileName = strRootDir+ent->d_name;
			pf(pProcessor, strFileName);
			usleep(1000*10);
		}
	}
	closedir(pDir);
#endif
}

void CMenuWnd::Init(DuiLib::CControlUI* pOwner, POINT& ptPos)
{
	if (pOwner)
	{
		m_pOwner = pOwner;
		HWND hWndParent = pOwner->GetManager()->GetPaintWindow();
		Create(hWndParent, _T("MenuWnd"), UI_WNDSTYLE_FRAME, WS_EX_WINDOWEDGE);
		::ClientToScreen(hWndParent, &ptPos);
		::SetWindowPos(this->GetHWND(), NULL, ptPos.x, ptPos.y, 0, 0, SWP_NOZORDER | SWP_NOSIZE | SWP_NOACTIVATE);
	}
}

void CMenuWnd::Notify(DuiLib::TNotifyUI& msg)
{
	if (msg.sType == _T("itemclick"))
	{
		if (msg.pSender->GetName() == _T("menu_delete") && m_pOwner)
		{
			m_pOwner->GetManager()->SendNotify(m_pOwner, "menu_delete", 0, 0, true);
			Close();
		}
	}
}

LRESULT CMenuWnd::OnKillFocus(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled)
{
	Close();
	bHandled = FALSE;
	return __super::OnKillFocus(uMsg, wParam, lParam, bHandled);
}

CMainWindow::CMainWindow(LPCTSTR pszXMLPath)
	:WindowBasedOnXML(pszXMLPath)
	,m_eUsage(ENUM_USED_FOR_CHECK)
	,m_hStartThread(INVALID_HANDLE_VALUE)
	,m_pLogFile(nullptr)
{
}

void CMainWindow::InitWindow()
{
	SetIcon(IDI_ICON1);
	/*here have to create a console through invoking the `AllocConsole()`, otherwise GetStdHandle(STD_OUT_HANDLE) 
	 *will return an invalid handle
	 */
	if (AllocConsole())
		::ShowWindow(GetConsoleWindow(), SW_HIDE);		//hide the console window

	CenterWindow();
	::DragAcceptFiles(this->GetHWND(), TRUE);
	GetDefaultEditor();

	m_pFileAndFolderList = static_cast<DuiLib::CListUI*>(m_PaintManager.FindControl(_T("fileList")));
	m_pXmlExistCheckBox = static_cast<DuiLib::CCheckBoxUI*>(m_PaintManager.FindControl(_T("xmlExist")));
	m_pStartBtn = static_cast<DuiLib::CButtonUI*>(m_PaintManager.FindControl(_T("startBtn")));
	m_pClearBtn = static_cast<DuiLib::CButtonUI*>(m_PaintManager.FindControl(_T("clearBtn")));
	m_pOpenLogBtn = static_cast<DuiLib::CButtonUI*>(m_PaintManager.FindControl(_T("openLogBtn")));
	m_pRunProgress = static_cast<DuiLib::CProgressUI*>(m_PaintManager.FindControl(_T("runProgress")));
	m_pConsoleText = static_cast<DuiLib::CRichEditUI*>(m_PaintManager.FindControl(_T("view_richedit")));

	m_pXmlExistCheckBox->SetEnabled(false);
	if (_access(CHECK_LOG_FILE, 0) != -1)
		m_pOpenLogBtn->SetEnabled(true);
	else
		m_pOpenLogBtn->SetEnabled(false);
	m_pStartBtn->SetEnabled(false);

#if 0
	DuiLib::CListTextElementUI* pListElement = new DuiLib::CListTextElementUI();
	m_pFileAndFolderList->Add(pListElement);
	pListElement->SetText(0, "E:\\res\\MidiFileParser\\test");
	pListElement->SetFixedHeight(LIST_ELEMENT_HEIGHT);
#endif
}

void CMainWindow::Notify(DuiLib::TNotifyUI& msg)
{
	bool bHandled = false;
	if (msg.sType == _T("menu"))
	{
		OnCreateMenu(msg, bHandled);
	}
	else if (msg.sType == _T("setfocus"))
	{
		OnSetFocus(msg, bHandled);
	}
	else if (msg.sType == _T("click"))
	{
		OnButtonClick(msg, bHandled);
	}
	else if (msg.sType == _T("selectchanged"))
	{
		OnSelectChanged(msg, bHandled);
	}
	else if (msg.sType == _T("menu_delete"))
	{
		OnDeleteListElement(msg, bHandled);
	}
	if (!bHandled)
		__super::Notify(msg);
}

LRESULT CMainWindow::HandleMessage(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	DetectThreadFinish();
	LRESULT lRes = 0;
	bool bHandled = true;
	switch (uMsg)
	{
	case WM_DROPFILES:		OnDropFiles((HDROP)wParam, bHandled); break;
	default:	bHandled = false; break;
	}
	if (bHandled) return lRes;
	return __super::HandleMessage(uMsg, wParam, lParam);
}

void CMainWindow::OnFinalMessage( HWND hWnd )
{
	::FreeConsole();
	return __super::OnFinalMessage(hWnd);
}

void CMainWindow::GetDefaultEditor()
{
	HKEY hKey;
	long lRet = RegOpenKeyEx(HKEY_CLASSES_ROOT, "txtfile\\shell\\open\\command", 0, KEY_QUERY_VALUE, &hKey);
	if (ERROR_SUCCESS == lRet)		//open success
	{
		enum { TEMP_BUFFER = 128 };
		TCHAR tchData[TEMP_BUFFER] = {0};
		DWORD dwSize = sizeof(tchData);
		lRet = RegQueryValueEx(hKey, "", NULL, NULL, (LPBYTE)tchData, &dwSize);		//Query the default item if the value name is ""
		if (ERROR_SUCCESS == lRet)
		{
			DWORD ch = 0;
			if ((ch = ExpandEnvironmentStringsA(tchData, NULL, 0)) != 0)
			{
				LPSTR pCmd = new char[ch];
				ExpandEnvironmentStringsA(tchData, pCmd, ch);
				std::string strDefaultValue = pCmd;
				m_strCmdLine.Format(_T("%s %s"), strDefaultValue.substr(0, strDefaultValue.find(" ")).c_str(), CHECK_LOG_FILE);
				delete pCmd;
			}
		}
		RegCloseKey(hKey);
	}
}

void CMainWindow::DetectThreadFinish()
{
	if (INVALID_HANDLE_VALUE != m_hStartThread)
	{
		if (WAIT_OBJECT_0 == WaitForSingleObject(m_hStartThread, 0))
		{
			::CloseHandle(m_hStartThread);
			m_hStartThread = INVALID_HANDLE_VALUE;
			if (ENUM_USED_FOR_CHECK == m_eUsage)
			{
				m_pConsoleText->AppendText("资源文件检查完成！");
			}
			else		//ENUM_USED_FOR_GENTXT == m_eUsage
			{
				m_pConsoleText->AppendText("生成html/txt完成！");
				m_pXmlExistCheckBox->SetEnabled(true);
			}
			m_pStartBtn->SetEnabled(true);
			m_pClearBtn->SetEnabled(true);
			if (ENUM_USED_FOR_CHECK == m_eUsage && _access(CHECK_LOG_FILE, 0) != -1)
				m_pOpenLogBtn->SetEnabled(true);
		}
	}
}

void CMainWindow::OnCreateMenu(DuiLib::TNotifyUI& msg, bool& bHandled)
{
	if (msg.pSender->GetName() == _T("fileList") && m_pFileAndFolderList->GetCurSel() >= 0)
	{
		m_pRButtonMenu = new CMenuWnd(_T("MenuStyle\\RBtnUp.xml"));
		if (m_pRButtonMenu)
		{
			POINT pt = {msg.ptMouse.x, msg.ptMouse.y};
			m_pRButtonMenu->Init(m_pFileAndFolderList, pt);
			m_pRButtonMenu->ShowWindow(TRUE);
		}
	}
}

void CMainWindow::OnSetFocus(DuiLib::TNotifyUI& msg, bool& bHandled)
{
	if (msg.pSender->GetParent() == m_pFileAndFolderList && m_pFileAndFolderList->GetCurSel() >= 0)
		m_pFileAndFolderList->SelectItem(-1);
}

void CMainWindow::OnButtonClick(DuiLib::TNotifyUI& msg, bool& bHandled)
{
	if (msg.pSender == m_pClearBtn)
	{
		m_pFileAndFolderList->RemoveAll();
		m_pConsoleText->SetText("");
		m_pRunProgress->SetValue(0);
		m_pStartBtn->SetEnabled(false);
		if (!m_mXmlMidiMap.empty())
			m_mXmlMidiMap.clear();
	}
	else if (msg.pSender == m_pStartBtn)
	{
		m_pXmlExistCheckBox->SetEnabled(false);
		m_pStartBtn->SetEnabled(false);
		m_pClearBtn->SetEnabled(false);
		m_pOpenLogBtn->SetEnabled(false);
		m_hStartThread = (HANDLE)_beginthreadex(NULL, 0, StartExecuteTask, this, 0, NULL);
	}
	else if (msg.pSender == m_pOpenLogBtn)
	{
		::WinExec(m_strCmdLine.GetData(), SW_SHOWNORMAL);
	}
}

void CMainWindow::OnSelectChanged(DuiLib::TNotifyUI& msg, bool& bHandled)
{
	const DuiLib::CDuiString& strName = msg.pSender->GetName();
	if (strName == _T("checkRadio"))
	{
		m_eUsage = ENUM_USED_FOR_CHECK;
		m_pXmlExistCheckBox->SetCheck(true);
		m_pXmlExistCheckBox->SetEnabled(false);
		if (_access(CHECK_LOG_FILE, 0) != -1)
			m_pOpenLogBtn->SetEnabled(true);
	}
	else if (strName == _T("genRadio"))
	{
		m_eUsage = ENUM_USED_FOR_GENTXT;
		m_pXmlExistCheckBox->SetEnabled(true);
		m_pOpenLogBtn->SetEnabled(false);
	}
}

void CMainWindow::OnDeleteListElement(DuiLib::TNotifyUI& msg, bool& bHandled)
{
	m_pFileAndFolderList->RemoveAt(m_pFileAndFolderList->GetCurSel());
	if (0 == m_pFileAndFolderList->GetCount())
		m_pStartBtn->SetEnabled(false);
	bHandled = true;
}

void CMainWindow::OnDropFiles(HDROP hDropInfo, bool& bHandled)
{
	char strFileName[MAX_PATH] = {0};
	UINT nFileNum = ::DragQueryFile(hDropInfo, -1, NULL, 0);
	for (int i = 0; i < nFileNum; ++i)
	{
		::DragQueryFile(hDropInfo, i, strFileName, MAX_PATH);
		bool bRepeatAdd = false;
		for (int i = 0; i < m_pFileAndFolderList->GetCount(); ++i)
		{
			DuiLib::CListTextElementUI* pListElement = static_cast<DuiLib::CListTextElementUI*>(m_pFileAndFolderList->GetItemAt(i));
			if (!strcmp(strFileName, pListElement->GetText(0)))
			{
				bRepeatAdd = true;
				break;
			}
		}
		if (!bRepeatAdd)
		{
			DuiLib::CListTextElementUI* pListElement = new DuiLib::CListTextElementUI();
			m_pFileAndFolderList->Add(pListElement);
			pListElement->SetText(0, strFileName);
			pListElement->SetFixedHeight(LIST_ELEMENT_HEIGHT);
		}
	}
	::DragFinish(hDropInfo);
	if (m_pFileAndFolderList->GetCount())
		m_pStartBtn->SetEnabled(true);
}

void CMainWindow::StatisticCallback(void* pInstance, std::string& strFileName)
{
	//file with the postfix ".xml" or ".mid" is supposed as music score
	CMainWindow* pThis = static_cast<CMainWindow*>(pInstance);
	std::string strFilePostfix = strFileName.substr(strFileName.rfind("."));
	if (pThis->m_pXmlExistCheckBox->GetCheck() && strFilePostfix == ".xml")
	{
		pThis->m_nTotalMusicScores++;
	}
	else if (!pThis->m_pXmlExistCheckBox->GetCheck() && strFilePostfix == ".mid")
	{
		pThis->m_nTotalMusicScores++;
	}
}

void CMainWindow::ProcessCallback(void* pInstance, std::string& strFileName)
{
	CMainWindow* pThis = static_cast<CMainWindow*>(pInstance);
	std::string strFilePostfix = strFileName.substr(strFileName.rfind("."));
	RESOURCE_TYPE eResType = ENUM_RESOURCE_NONE;
	if (".xml" == strFilePostfix)
		eResType = ENUM_RESOURCE_XML;
	else if (".mid" == strFilePostfix)
		eResType = ENUM_RESOURCE_MIDI;

	if (ENUM_RESOURCE_NONE == eResType || (ENUM_RESOURCE_MIDI == eResType && pThis->m_pXmlExistCheckBox->GetCheck())
		|| (ENUM_RESOURCE_XML == eResType && !pThis->m_pXmlExistCheckBox->GetCheck()))
		return;

	printf("Process Music Score %s...\n", strFileName.substr(0, strFileName.rfind(".")).c_str());
	pThis->ProcessResourceFile(strFileName, eResType);
	pThis->m_nProcessedScores++;
	pThis->m_pRunProgress->SetValue(100.0*pThis->m_nProcessedScores/pThis->m_nTotalMusicScores);
}

void CMainWindow::ProcessResourceFile(std::string& strSrcFileName, RESOURCE_TYPE eResType)
{
	if (ENUM_RESOURCE_XML == eResType)
	{
		hyStatus sts = m_mXmlParser.ParseMusicXML(strSrcFileName.c_str(), DEVICE_PAD, m_eUsage, m_pLogFile);
		if (MUSIC_ERROR_NONE == sts)
		{
			MidiFile* midi = nullptr;
			MidiFileSerialize midi_parser;
			std::string strMidiFileName = strSrcFileName.substr(0, strSrcFileName.rfind("."))+".mid";
			std::string strSPMidiFileName = strSrcFileName.substr(0, strSrcFileName.rfind("."))+"_sp.mid";
			CheckXmlBelongList(strSrcFileName, strMidiFileName, strSPMidiFileName);

			//first parse the standard midi file and generate the corresponding the file .csv/.txt
			if (strMidiFileName != "" && _access(strMidiFileName.c_str(), 0) != -1)
			{
				midi = midi_parser.loadFromFile(strMidiFileName.c_str());
				if (ENUM_USED_FOR_CHECK == m_eUsage)
					strMidiFileName.replace(strMidiFileName.rfind("."), strlen(".mid"), ".csv");
				else		//ENUM_USED_FOR_GENTXT == pThis->m_eUsage
					strMidiFileName.replace(strMidiFileName.rfind("."), strlen(".mid"), ".txt");
				m_mXmlParser.checkMidiSequence(midi, strMidiFileName.c_str(), false);
			}

			//then maybe exist video midi need to parse, check whether exist, and the track info of the corresponding
			//event must retrieve from the standard midi.
			if (strSPMidiFileName != "" && _access(strSPMidiFileName.c_str(), 0) != -1)
			{
				midi = midi_parser.loadFromFile(strSPMidiFileName.c_str());
				if (ENUM_USED_FOR_CHECK == m_eUsage)
					strSPMidiFileName.replace(strSPMidiFileName.rfind("."), strlen(".mid"), ".csv");
				else		//ENUM_USED_FOR_GENTXT == pThis->m_eUsage
					strSPMidiFileName.replace(strSPMidiFileName.rfind("."), strlen(".mid"), ".txt");
				m_mXmlParser.checkMidiSequence(midi, strSPMidiFileName.c_str(), true);
			}

			/*NOTE that there some infos such as event->note_staff, event->oveline were retrieved in the
			 * checkMidiSequence routinue, therefore the progress of generating html file must after it.
			 */
			strSrcFileName.replace(strSrcFileName.rfind("."), strlen(".xml"), ".html");
			WriteScoreHtml(midi, strSrcFileName.c_str());
		}
	}
	else if (ENUM_RESOURCE_MIDI == eResType)
	{
		MidiFileSerialize midi_parser;
		MidiFile* midi = midi_parser.loadFromFile(strSrcFileName.c_str());
		strSrcFileName.replace(strSrcFileName.rfind("."), strlen(".mid"), ".txt");
		WriteFormatTxtWithoutXml(midi, strSrcFileName.c_str());
	}
}

void CMainWindow::WriteScoreHtml(MidiFile* midi, const char* pHtmlFileName)
{
	CGSize musicSize;
#ifdef ADAPT_CUSTOMIZED_SCREEN
	musicSize.width = 1224+50;
#else
	musicSize.width = 1024;
#endif
	musicSize.height = musicSize.width*m_mXmlParser.m_pMusicScore->page_height/m_mXmlParser.m_pMusicScore->page_width;
	VmusImage svg;
	svg.loadMusic(m_mXmlParser.m_pMusicScore, musicSize, true, midi ? (&midi->_mergedMidiEvents) : nullptr);

	FILE* fp = fopen(pHtmlFileName, "w");
	MyString* str = static_cast<MyString*>(svg.staff_images->objects[0]);
	fwrite(str->getBuffer(), 1, str->length, fp);
	fclose(fp);
}

bool CMainWindow::CheckXmlBelongList(const std::string& strXmlFile, std::string& strMidiFile, std::string& strSPMidiFile)
{
	if (m_mXmlMidiMap.find(strXmlFile) == m_mXmlMidiMap.end())		//not find
		return false;

	strMidiFile = ""; strSPMidiFile = "";
	auto ret = m_mXmlMidiMap.equal_range(strXmlFile);
	for (auto it = ret.first; it != ret.second; ++it)
	{
		if (strstr(it->second.c_str(), "sp"))
			strSPMidiFile = it->second;
		else
			strMidiFile = it->second;
	}
	return true;
}

void CMainWindow::TraverseListElement(void (*pf)(void*, std::string&), TRAVERSE_USAGE eUsage)
{
	if (ENUM_TRAVERSE_STATISTIC == eUsage)
	{
		m_nTotalMusicScores = 0;
	}
	else
	{
		m_nProcessedScores = 0;
		if (ENUM_USED_FOR_CHECK == m_eUsage)
		{
			m_pLogFile = fopen(CHECK_LOG_FILE, "w");
		}
	}

	for (int i = 0; i < m_pFileAndFolderList->GetCount(); ++i)
	{
		DuiLib::CListTextElementUI* pListElement = static_cast<DuiLib::CListTextElementUI*>(m_pFileAndFolderList->GetItemAt(i));
		LPCTSTR strItem = pListElement->GetText(0);
		DWORD dwFileAttr = ::GetFileAttributes(strItem);
		if (INVALID_FILE_ATTRIBUTES != dwFileAttr)
		{
			if (dwFileAttr & FILE_ATTRIBUTE_DIRECTORY) {		//directory
				DepthFirstTraverseDir(strItem+std::string("\\"), pf, this);
			} else {		//file
				if (ENUM_TRAVERSE_STATISTIC == eUsage)
				{
					std::string strFile = strItem;
					if (strFile.substr(strFile.rfind(".")) == ".xml")
						SearchListMatchedMidi(strFile);
				}
				pf(this, std::string((LPCTSTR)strItem));
				Sleep(10);
			}
		}
	}

	if (ENUM_TRAVERSE_PROCESS == eUsage && ENUM_USED_FOR_CHECK == m_eUsage && m_pLogFile)
	{
		fclose(m_pLogFile);
		m_pLogFile = nullptr;
	}
}

void CMainWindow::SearchListMatchedMidi(const std::string& strXmlFile)
{
	/*Note that the file repeated in the list will be filtered, this condition ensure that each file is different*/
	const std::string& strScoreName = strXmlFile.substr(strXmlFile.rfind("\\")+1, strXmlFile.rfind(".")-strXmlFile.rfind("\\")-1);
	for (int i = 0; i < m_pFileAndFolderList->GetCount(); ++i)
	{
		DuiLib::CListTextElementUI* pListElement = static_cast<DuiLib::CListTextElementUI*>(m_pFileAndFolderList->GetItemAt(i));
		std::string strItem = pListElement->GetText(0);
		if (strstr(strItem.c_str(), strScoreName.c_str()) && strItem.substr(strItem.rfind(".")) == ".mid")
			m_mXmlMidiMap.insert(std::pair<std::string, std::string>(strXmlFile, strItem));
	}
}

HANDLE CMainWindow::CreatePipeAndThread()
{
	SECURITY_ATTRIBUTES sa;
	sa.nLength = sizeof(SECURITY_ATTRIBUTES);
	sa.lpSecurityDescriptor = NULL;		//use the system default security descriptor
	sa.bInheritHandle = FALSE;
	::CreatePipe(&m_hReadPipe, &m_hWritePipe, &sa, 0);		//create pipe success

	//redirect stdout to the specified handle `m_hWritePipe`
	int hCrt = _open_osfhandle((long)m_hWritePipe, _O_TEXT);
	*stdout = *(_fdopen(hCrt, "w"));
	setvbuf(stdout, NULL, _IONBF, 0);		//read data or write data from stream directly without buffer

	//create a thread that used for execute the specified task
	return (HANDLE)_beginthreadex(NULL, 0, MainTaskThread, this, 0, NULL);
}

unsigned int CMainWindow::MainTaskThread(void* pArg)
{
	CMainWindow* pThis = static_cast<CMainWindow*>(pArg);
	pThis->TraverseListElement(ProcessCallback, ENUM_TRAVERSE_PROCESS);
	CloseHandle(pThis->m_hWritePipe);
	return 0;
}

unsigned int CMainWindow::StartExecuteTask(void* pArg)
{
	CMainWindow* pThis = static_cast<CMainWindow*>(pArg);
	if (!pThis->m_mXmlMidiMap.empty())
		pThis->m_mXmlMidiMap.clear();

	//First calculate the total music scores through traversing all the file for displaying the progress
	pThis->TraverseListElement(StatisticCallback, ENUM_TRAVERSE_STATISTIC);
	//Next create a pipe and thread in which the pipe is used for the communication among multi-threads
	HANDLE hTaskThread = pThis->CreatePipeAndThread();

	//read data written by another thread from the pipe and display the output on the Text control
	DWORD nReadNum = 0;
	pThis->m_pConsoleText->SetText("");
	while (ReadFile(pThis->m_hReadPipe, pThis->m_pPipeBuffer, READ_PIPE_BUFFER_LEN, &nReadNum, NULL))
	{
		pThis->m_pPipeBuffer[nReadNum] = 0;
		pThis->m_pConsoleText->AppendText(pThis->m_pPipeBuffer);		//<--Duilib_d.dll exist some unknown bugs
		pThis->m_pConsoleText->EndDown();
		Sleep(20);
	}
	if (ERROR_BROKEN_PIPE == GetLastError())
	{
		CloseHandle(pThis->m_hReadPipe);
		WaitForSingleObject(hTaskThread, INFINITE);
		CloseHandle(hTaskThread);
	}
	return 0;
}