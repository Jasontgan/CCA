

-- let's say you have a query like this to look up the last encounter date of a given member during a given time frame:
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT 
		MAX(e.date) AS last_enc_date
		, p.hl7id AS CCAID
	FROM users AS u
	INNER JOIN patients AS p
		ON u.uid = p.pid
		AND p.hl7id = ''5364521037''
	INNER JOIN enc AS e
		ON u.uid = e.patientid
		AND e.deleteflag = 0
	WHERE e.date BETWEEN ''2018-01-01'' AND ''2018-12-31''
	GROUP BY 
		p.hl7id
')


-- to make this into a dynamic query, you need to create a query that reproduces all of the above as output text and saves it into a variable

DECLARE @query_text AS NVARCHAR(MAX)

SET @query_text =

'SELECT
	*
FROM OPENQUERY(ECW, ' + CHAR(39)	-- NOTE! all single quotes have to be replaced with this CHAR function
+ '
	SELECT 
		MAX(e.date) AS last_enc_date
		, p.hl7id AS CCAID
	FROM users AS u
	INNER JOIN patients AS p
		ON u.uid = p.pid
		AND p.hl7id = ' + CHAR(39) + CHAR(39) + '5364521037' + CHAR(39) + CHAR(39)	-- note how weird double-quotes end up looking
+ '
	INNER JOIN enc AS e
		ON u.uid = e.patientid
		AND e.deleteflag = 0
	WHERE e.date BETWEEN ' + CHAR(39) + CHAR(39) + '2018-01-01' + CHAR(39) + CHAR(39) + ' AND ' + CHAR(39) + CHAR(39) + '2018-12-31' + CHAR(39) + CHAR(39)
 + '
 	GROUP BY 
		p.hl7id'
 + CHAR(39) + ')'

PRINT @query_text	-- if this has been done right, you should be able to copy the output into the query window and run it successfully


-- now, do the same thing but swab out key criteria with input variables:

DECLARE @target_CCAID AS VARCHAR(10)	= 5364521037	-- note that this is text, not a BIGINT
DECLARE @report_begin AS VARCHAR(10)	= '2018-01-01'	-- note that this is text, not a DATE
DECLARE @report_end AS VARCHAR(10)		= '2018-12-31'	-- note that this is text, not a DATE

DECLARE @query_text2 AS NVARCHAR(MAX)

SET @query_text2 =

'SELECT
	*
FROM OPENQUERY(ECW, ' + CHAR(39)
+ '
	SELECT 
		MAX(e.date) AS last_enc_date
		, p.hl7id AS CCAID
	FROM users AS u
	INNER JOIN patients AS p
		ON u.uid = p.pid
		AND p.hl7id = ' + CHAR(39) + CHAR(39) + @target_CCAID + CHAR(39) + CHAR(39)
+ '
	INNER JOIN enc AS e
		ON u.uid = e.patientid
		AND e.deleteflag = 0
	WHERE e.date BETWEEN ' + CHAR(39) + CHAR(39) + @report_begin + CHAR(39) + CHAR(39) + ' AND ' + CHAR(39) + CHAR(39) + @report_end + CHAR(39) + CHAR(39)
 + '
 	GROUP BY 
		p.hl7id'
 + CHAR(39) + ')'

--PRINT @query_text2	-- again, if this has been done right, you should be able to copy the output into the query window and run it successfully
	
-- if the output text can be successfully as a query, put the text variable into this statement and it will run:
EXECUTE sp_executesql @query_text2
