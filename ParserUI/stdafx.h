#pragma once

#include <string>

#include "UIlib.h"
#include "resource.h"

#ifdef _DEBUG
#	ifdef	_UNICODE
#		pragma comment(lib, "DuiLib_ud.lib")
#	else
#		pragma comment(lib, "DuiLib_d.lib")
#	endif
#else
#	ifdef	_UNICODE
#		pragma comment(lib, "DuiLib_u.lib")
#	else
#		pragma comment(lib, "DuiLib.lib")
#	endif
#endif

class WindowBasedOnXML : public DuiLib::WindowImplBase
{
public:
	explicit WindowBasedOnXML(LPCTSTR pszXMLPath) : m_strXMLPath(pszXMLPath) {}
	virtual LPCTSTR GetWindowClassName() const	{ return _T("WndBasedOnXML"); }
	virtual DuiLib::CDuiString GetSkinFile()					{ return m_strXMLPath; }
	virtual DuiLib::CDuiString GetSkinFolder()				{ return _T("skin"); }

protected:
	DuiLib::CDuiString m_strXMLPath;
};