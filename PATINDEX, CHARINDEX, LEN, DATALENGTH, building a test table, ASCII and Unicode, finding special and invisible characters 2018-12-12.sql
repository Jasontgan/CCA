
-- Source: http://www.sqlservercentral.com/articles/Special+characters/111691/



-- vvv BUILDING EXAMPLE TEST DATA vvv --

IF OBJECT_ID('tempdb..#TEST_DATA') IS NOT NULL DROP TABLE #TEST_DATA;
GO

CREATE TABLE #TEST_DATA (
	row_id				INT IDENTITY(1,1) NOT NULL
	, EXAMPLE_TYPE_DESC	NVARCHAR(60)
	, EXAMPLE_TEXT		NVARCHAR(60) COLLATE Latin1_General_CS_AS
)
-- Note: the collation of the EXAMPLE_TEXT is Latin1_General_CS_AS -- this means the column is case and accent sensitive
-- Collation is SQL Server’s way of knowing how to sort and compare data.
-- For example: are strings case insensitive or not (does "ZombieLand" = "zombieland"?)
-- or are a string’s accent sensitive or not (does "Ça" = "Ca"?)

-- ASCII table:		http://www.ascii-code.com/
-- Unicode table:	http://unicode-table.com/en/

INSERT INTO #TEST_DATA (EXAMPLE_TYPE_DESC,EXAMPLE_TEXT)
VALUES
	  ('ORIGINAL',										'Zombieland')
	, ('SPACE AT END',									'Zombieland ')
	, ('SPACE AT START',								' Zombieland')
	, ('SPACE AT START AND END (Unicode)',				N' Zombieland ') -- this N makes something Unicode
	, ('SPECIAL CHARACTERS - CARRAGE RETURN LINE FEED',	'Zombieland' + CHAR(13) + CHAR(10))
	, ('SPECIAL CHARACTERS - APOSTROPHE',				'Zombie''s Land')
	, ('SPECIAL CHARACTERS - # SYMBOL',					'35 Zombie Land Apt. #13')
	, ('SPECIAL CHARACTERS /',							'This and/or that')
	, ('SPECIAL CHARACTERS \',							'This and\or that')
	, ('SPECIAL CHARACTERS MULTIPLE SPACES',			'35 Zombie    Land Apt 13')
	, ('ACCENTS',										'Régie du logement - Gouvernement du Québec')
	, ('ACCENTS',										'Ça va')
	--, ('SINGLE QUOTE',									'This is your ' + CHAR(39) + 'single quote' + CHAR(39) + ' text.')
	;

GO

-- ^^^ BUILDING EXAMPLE TEST DATA ^^^ --

-- SELECT * FROM #TEST_DATA



--  The LEN() function gives you the number of characters in a character string
--> but it trims the trailing empty spaces.

--  The DATALENGTH() function tells you the number of bytes used to make a character string.
--  ASCII character strings use 1 byte per character
--  UNICODE character strings use 2 bytes per character

SELECT
	*
	, CHARINDEX('bie', EXAMPLE_TEXT) AS 'location of "bie"'	-- CHARINDEX looks for specific strings, PATINDEX looks for patterns
	, PATINDEX('%[0-9]%', EXAMPLE_TEXT) AS 'first number'	-- will be 0 if no number found	-- note that characters should be listed in ASCII order, so 0-9 not 1-0
	, PATINDEX('%[a-Z]%', EXAMPLE_TEXT) AS 'first letter'	-- note: pattern is case sensitive
	, PATINDEX('%[a-z]%', EXAMPLE_TEXT) AS 'first lower-case letter'
	, PATINDEX('%[^0-9]%', EXAMPLE_TEXT) AS 'first non-number'
	, CASE WHEN PATINDEX('%[0-9]%', EXAMPLE_TEXT) > 0 THEN PATINDEX('%[^0-9]%', EXAMPLE_TEXT) - PATINDEX('%[0-9]%', EXAMPLE_TEXT) ELSE '' END AS 'length of first number'
	, CASE WHEN PATINDEX('%[0-9]%', EXAMPLE_TEXT) > 0 THEN PATINDEX('%[0-9]%', SUBSTRING(EXAMPLE_TEXT, PATINDEX('%[^0-9]%', EXAMPLE_TEXT) + 1, 1000)) ELSE '' END AS 'start of second number (if any)'
	, PATINDEX('%[^a-zA-Z0-9]%', EXAMPLE_TEXT) AS 'first non-number and non-letter' -- note: you do not have to separate the pattern ranges with a comma
	, PATINDEX('%[^a-zA-Z0-9 ]%', EXAMPLE_TEXT) AS 'first non-number, non-letter, and non-space' -- note: invisible characters are found but accented characters (Ç) are not
	, PATINDEX('%[^a-zA-Z0-9 .&()_-]%', EXAMPLE_TEXT) AS 'first non-number, non-letter, non-space, and non-misc'
	--, REPLACE(EXAMPLE_TEXT, '%[^a-zA-Z0-9]%', 'x') AS 'replaced'
	, LEN(EXAMPLE_TEXT) AS 'len_text'
	, DATALENGTH(EXAMPLE_TEXT)/2 AS 'datalen_text'
	, DATALENGTH('Zombieland') AS 'datalen_text_ASCII'
	, DATALENGTH(N'Zombieland') AS 'datalen_text_Unicode'
FROM #TEST_DATA
-- note that these search patterns could be used in a "WHERE EXAMPLE_TEXT LIKE" clause

-- see also this on PATINDEX: http://www.databasejournal.com/features/mssql/article.php/3071531/Using-SQL-Servers-CHARINDEX-and-PATINDEX.htm

