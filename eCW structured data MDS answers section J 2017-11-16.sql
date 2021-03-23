

-- structured data tables
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT DISTINCT
		tblName
	FROM structdatadetail AS s
')


-- structExam search 1
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT
		*
	FROM structdatadetail AS s
	WHERE s.tblName = ''structExam''
		AND name LIKE ''%a. Cerebrovascular %''
')
ORDER BY displayIndex


-- structExam search 2
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT
		*
	FROM structdatadetail AS s
	WHERE s.tblName = ''structExam''
		AND name LIKE ''%b. Congestive %''
')
ORDER BY displayIndex


-- structExam search 3
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT
		*
	FROM structdatadetail AS s
	WHERE s.tblName = ''structExam''
		AND name LIKE ''%(stroke)%''
')
ORDER BY displayIndex


-- questions for MDS section J post-2016
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT
		*
	FROM structdatadetail AS s
	WHERE s.tblName = ''structExam''
		AND itemId = 430117
')


-- answers for MDS (one member)
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT
		*
	FROM structexam AS s
	WHERE encounterId = 193312508
')


-- combined
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT
		sdd.Id
		, sdd.catId
		, sdd.itemId
		, sdd.name
		, se.value
		, se.valueId
	FROM structdatadetail AS sdd
	INNER JOIN structexam AS se
		ON sdd.catId = se.catId
		AND sdd.itemId = se.itemId
		AND sdd.Id = se.detailId
		AND se.encounterId = 193312508
	WHERE sdd.tblName = ''structExam''
		AND sdd.itemId = 430117
')
Order by Id


-- one member's assessments
SELECT
	*
FROM OPENQUERY(SRVMEDECWREP01, '
	SELECT DISTINCT
		p.hl7id AS CCAID
		, e.encLock
		, CAST(e.Date AS DATE) AS enc_date
		, e.StartTime
		, e.VisitType
		, e.Status
		, e.Reason
		, u.uid
		, e.encounterID
	FROM users AS u
	INNER JOIN patients AS p
		ON u.uid = p.pid
	INNER JOIN enc AS e
		ON u.uid = e.patientid
		AND e.deleteflag = 0
		AND e.visitType IN (''MDS Face'', ''MDS Teleph'', ''MDS Visit'', ''HANNUAL'', ''OANNUAL'', ''ANNUAL'')
	WHERE p.hl7id = ''5364521037''
		AND e.Date >= ''2013-10-01''
') AS ecw


-- for any MDS visit (one member)
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT
		sdd.Id
		, sdd.catId
		, sdd.itemId
		, e.encounterId
		, e.visitType
		, e.date
		, CAST(sdd.name AS CHAR(255)) AS disease_dx
		, se.value AS answer
		, se.valueId
	FROM structdatadetail AS sdd
	INNER JOIN structexam AS se
		ON sdd.catId = se.catId
		AND sdd.itemId = se.itemId
		AND sdd.Id = se.detailId
	INNER JOIN enc AS e
		ON se.encounterId = e.encounterId
		AND e.deleteflag = 0
		AND e.visitType IN (''MDS Face'', ''MDS Teleph'', ''MDS Visit'', ''HANNUAL'', ''OANNUAL'', ''ANNUAL'')
	INNER JOIN patients AS p
		ON e.patientid = p.pid
		AND p.hl7id = ''5364521037''
	WHERE sdd.tblName = ''structExam''
		AND sdd.itemId = 430117
')
ORDER BY
	[date]
	, SUBSTRING(disease_dx, 2, 1)
	, LEFT(disease_dx, 1)





-- where are the earlier Section J answers?
-- questions? for MDS section J pre-2016
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT
		*
	FROM structdatadetail AS s
	WHERE s.tblName = ''structExam''
		AND itemId = 418001
')


-- answers? MDS section J pre-2016
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT
		se.*
		, e.date
		, p.hl7id
	FROM structexam AS se
	INNER JOIN enc AS e
		ON se.encounterId = e.encounterId
	INNER JOIN patients AS p
		ON e.patientid = p.pid
	WHERE itemId = 418001
')
ORDER BY date, hl7id
