
DECLARE @report_begin AS DATE		= '2018-01-01'
DECLARE @report_end AS DATE			= '2018-12-31'


IF OBJECT_ID('tempdb..#claims_palliative') IS NOT NULL DROP TABLE #claims_palliative

SELECT DISTINCT
	cmv.MEMBID AS 'CCAID'
	, CAST(cd.FROMDATESVC AS DATE) AS 'FROMDATESVC'
	, CAST(cd.TODATESVC AS DATE) AS 'TODATESVC'
	, DATEDIFF(DD, cd.FROMDATESVC, cd.TODATESVC) + 1 AS 'days'
	, cmv.OPT AS 'Product'
INTO #claims_palliative
FROM EZCAP_DTS.dbo.CLAIM_DETAILS AS cd 
INNER JOIN EZCAP_DTS.dbo.CLAIM_MASTERS_V AS cmv
	ON cd.CLAIMNO = cmv.CLAIMNO
WHERE cd.[STATUS] = 9
	AND (cd.LINEFLAG <> 'x' OR cd.LINEFLAG IS NULL)
	AND cd.PROCCODE IN ('G0299','G0300','G0155', 'G0154','S0257', 'G0162',---kathy d has identified these codes as palliative care
		'98968', '99366', '98968', '99366')
	AND (cd.MODIF LIKE '%tg%' OR cd.MODIF LIKE '%tu%' OR cd.MODIF LIKE '%td%')
	--AND cd.TODATESVC BETWEEN '2017-01-01'and '2017-12-31'
	AND cd.TODATESVC BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
PRINT '#claims_palliative'
-- SELECT * FROM #claims_palliative ORDER BY CCAID


IF OBJECT_ID('tempdb..#enc_palliative') IS NOT NULL DROP TABLE #enc_palliative

SELECT
    *
INTO #enc_palliative
FROM OPENQUERY(ECW, '
	SELECT DISTINCT
		p.hl7id AS CCAID
		, CAST(e.Date AS DATE) AS enc_date
		, e.VisitType
	/*	, e.Reason	*/
		, LEFT(dem.value, 3) AS Product
	FROM users AS u
	INNER JOIN patients AS p
		ON u.uid = p.pid
	INNER JOIN enc AS e
		ON u.uid = e.patientid
		AND e.deleteflag = 0
		AND e.encLock = 1
	INNER JOIN structdemographics AS dem
		ON u.uid = dem.patientid
		AND dem.detailID = 681001
		AND dem.deleteflag = 0
	WHERE p.hl7id BETWEEN ''5364521037'' AND ''5369999999''   
		AND e.visitType LIKE ''PAL''     
') AS ecw
WHERE ecw.enc_date BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
PRINT '#enc_palliative'
-- SELECT * FROM #enc_palliative ORDER BY CCAID, enc_date


SELECT DISTINCT
	CCAID, Product, 'palliative' AS 'service'
FROM (
		SELECT DISTINCT
			CCAID, Product
		FROM #claims_palliative
	UNION ALL
		SELECT DISTINCT
			CCAID, Product
		FROM #enc_palliative
) AS palliative
ORDER BY CCAID
