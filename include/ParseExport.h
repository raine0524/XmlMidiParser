#pragma once

#if defined(MIDIXMLPARSER_EXPORTS)
#	if defined(_MSC_VER)
#		define PARSE_DLL	__declspec(dllexport)
#	else
#		define	PARSE_DLL
#	endif	//_MSC_VER
#else
#	if defined(_MSC_VER)
#		define	PARSE_DLL	__declspec(dllimport)
#	else
#		define	PARSE_DLL
#	endif	//_MSC_VER
#endif		//MIDIXMLPARSER_EXPORTS

#define _USE_MATH_DEFINES

//////////////////////////////////////////////////////////////////////////
//The C Standard Library
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

//////////////////////////////////////////////////////////////////////////
//The C++ Standard Library (Include the Template Library)
#include <sstream>
#include <algorithm>
#include <numeric>
#include <memory>

#include <set>
#include <map>
#include <string>
#include <vector>

//////////////////////////////////////////////////////////////////////////
//The Platform Specific Library
#ifdef WIN32
#	include <Windows.h>
#	include <tchar.h>
#	include <io.h>
#else
#	include <unistd.h>
#	include <sys/types.h>
#	include <sys/stat.h>
#	include <dirent.h>
#endif

#include "mxparse\tinyxml2.h"
#include "mxparse\MyObject.h"
#include "mxparse\VmusMusic.h"
#include "mxparse\MidiFile.h"
#include "mxparse\VmusImage.h"
#include "mxparse\MusicXMLParser.h"
#include "mxparse\MidiFile.h"
#include "mxparse\MidiFileSerialize.h"

//////////////////////////////////////////////////////////////////////////
//Module Macro define
#define TARGET_OS_IPHONE		//default mode
//#define	ADAPT_CUSTOMIZED_SCREEN