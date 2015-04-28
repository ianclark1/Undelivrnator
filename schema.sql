-- SQL table schema

-- SQL SERVER

	CREATE TABLE Undelivrnator (
		ID int IDENTITY(1,1) NOT NULL,
		EmailFile varchar(20) NOT NULL,
		ToAddress varchar(100) NOT NULL,
		FromAddress varchar(100) NOT NULL,
		SentDate datetime NOT NULL,
		Attempts int NOT NULL,
		ServerID char(4) NOT NULL
	)