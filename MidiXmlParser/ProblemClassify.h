#ifndef	PROBLEMCLASSIFY_H_
#define	PROBLEMCLASSIFY_H_

#include "MySQLDB.h"

#define	MYSQL_NAME	"problem_classify"
#define	MYSQL_USER	"anybody"
#define	MYSQL_PASS	"632145"

class ProblemClassify
{
public:
	ProblemClassify();
	~ProblemClassify();

public:
	bool Connect();
	void Disconnect();

private:
	void DB_InitDatabase() {}

private:
	MySQLDB m_DBDriver;
};

#endif		//PROBLEMCLASSIFY_H_