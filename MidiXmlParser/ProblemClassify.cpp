#include "ParseExport.h"
#include "ProblemClassify.h"

#if 0
#pragma comment(lib, "KDBAPI.lib")

bool ProblemClassify::Connect()
{
	//connect to the mysql database
	MYSQL_CONNECTION MyConn;
	MyConn.dbhost = "127.0.0.1";
	MyConn.dbport = 3306;
	MyConn.dbuser = MYSQL_USER;
	MyConn.dbpass = MYSQL_PASS;
	MyConn.dbname = MYSQL_NAME;
	if (!m_DBDriver.Connect(MyConn))
	{
		m_DBDriver.Disconnect();
		return false;
	}
	DB_InitDatabase();
	return true;
}

void ProblemClassify::Disconnect()
{
	m_DBDriver.Disconnect();
}
#endif