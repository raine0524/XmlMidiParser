#include "MainWindow.h"

int APIENTRY _tWinMain( __in HINSTANCE hInstance, __in_opt HINSTANCE hPrevInstance, __in LPSTR lpCmdLine, __in int nShowCmd )
{
	//This UI is so simple that can run independently without the support of COM library
	DuiLib::CPaintManagerUI::SetInstance(hInstance);

	CMainWindow* pCheckWnd = new CMainWindow(_T("MainWindow.xml"));
	pCheckWnd->Create(NULL, _T("CheckWnd"), UI_WNDSTYLE_FRAME, WS_EX_WINDOWEDGE);
	pCheckWnd->ShowModal();
	delete pCheckWnd;

	return 0;
}