#pragma once

#include <map>
#include <string>

#if defined(WIN32) && !defined(__LCC__)
	#define	__LCC__
#endif

#ifdef WIN32
#include "mysql/mysql.h"
#else
#include "mysql.h"
#endif

typedef std::map<std::string,std::string> MySQLRow;
typedef std::map<unsigned long,MySQLRow> MySQLResultSet;

typedef struct _MYSQL_CONNECTION
{
	std::string	dbhost;
	unsigned short dbport;
	std::string dbname;
	std::string dbuser;
	std::string dbpass;
	_MYSQL_CONNECTION()
	{
		dbport=3306;
	};
}MYSQL_CONNECTION;

//---------------------------------------------------------------------------------------
// MySQL数据库驱动
class MySQLDB
{
public:
	MySQLDB(void);
	virtual ~MySQLDB(void);

	bool Connect(MYSQL_CONNECTION SingleConnection,bool bUTF8=true,bool bStoreResult=false);
	bool Connect(MYSQL_CONNECTION WriteConnection,MYSQL_CONNECTION ReadConnection,bool bUTF8=false,bool bStoreResult=false);
	void Disconnect(void);

	/*********************************************************
	 * 检查数据库(如果数据库没有连接则自动连接)
	 *********************************************************/
	bool CheckDB(void);

	/*********************************************************
	 * 选择数据库
	 *********************************************************/
	void SelectDB(const std::string& strDBName);

	/*********************************************************
	 * 创建SQL语句
	 *********************************************************/
	std::string CreateSQL(const char* cszSQL,...);

	/*********************************************************
	 * 执行SQL语句(INSERT/UPDATE/DELETE)
	 * 返回语句执行后影响的行数,如果为-1则表示执行错误
	 *********************************************************/
	int SQLExecute(const std::string& strSQL);

	/*********************************************************
	 * 执行SQL语句(SELECT)
	 * 返回语句执行后的结果集
	 *********************************************************/
	int SQLQuery(const std::string& strSQL,MySQLResultSet& res);

	/*********************************************************
	 * 获得INSERT后的记录ID号
	 *********************************************************/
	unsigned long GetLastInsertID(void);

	/*********************************************************
	 * Escape字符串
	 *********************************************************/
	const char* Escape(const std::string& strValue);

	/*********************************************************
	 * PING服务器
	 * 如果与服务器的连接有效返回0。如果出现错误，返回非0值。
	 * 返回的非0值不表示MySQL服务器本身是否已关闭，
	 * 连接可能因其他原因终端，如网络问题等。
	 *********************************************************/
	int PingSingleDB(void);
	int PingWriteDB(void);
	int PingReadDB(void);

	/*********************************************************
	 * 获得服务器版本
	 * 表示MySQL服务器版本的数值，格式如下：
	 * major_version*10000 + minor_version *100 + sub_version
	 * 例如，对于5.0.12，返回500012
	 *********************************************************/
	unsigned long GetSingleServerVersion(void);
	unsigned long GetWriteServerVersion(void);
	unsigned long GetReadServerVersion(void);

	/*********************************************************
	 * 获得客户端版本
	 * 表示MySQL客户端版本的数值，格式如下：
	 * major_version*10000 + minor_version *100 + sub_version
	 * 例如，对于5.0.12，返回500012
	 *********************************************************/
	unsigned long GetClientVersion(void);
	
protected:
	MYSQL*		m_pSingleDB;
	MYSQL*		m_pWriteDB;
	MYSQL*		m_pReadDB;
	void ShowLastError(MYSQL* pDB,const std::string& strMysql="");

private:
	bool				m_bSingle;
	MYSQL_CONNECTION	m_SingleConnection;
	MYSQL_CONNECTION	m_WriteConnection;
	MYSQL_CONNECTION	m_ReadConnection;
	bool				m_bUTF8;
	bool				m_bStoreResult;
};