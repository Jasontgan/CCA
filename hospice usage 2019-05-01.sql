
DECLARE @report_begin AS DATE		= '2018-01-01'
DECLARE @report_end AS DATE			= '2018-12-31'


IF OBJECT_ID('tempdb..#hospice_ADS') IS NOT NULL DROP TABLE #hospice_ADS

SELECT DISTINCT
	adsc.CCAID
	, adsc.FromDate
	, adsc.ToDate
	, 'ADS claims' AS 'source'
	, CASE WHEN adsc.provname LIKE '%hospice%' THEN 'provider name'
		WHEN adsp.VEND_Name LIKE '%hospice%' THEN 'vendor name'
		WHEN adsp.PROV_LASTNAME LIKE '%hospice%' THEN 'provider lastname'
		WHEN adsp.prov_leaf_name = 'Hospice' THEN 'provider leaf'
		END AS 'source2'
	, adsc.Product
INTO #hospice_ADS
-- SELECT TOP 1000 *
FROM Actuarial_Services.dbo.ADS_Claims AS adsc
LEFT JOIN EZCAP_DTS.dbo.PLACESVC_CODES AS pos
	ON adsc.POS = pos.CODE
LEFT JOIN CCAMIS_Common.dbo.ez_bill_type AS bt
	ON adsc.BillType = bt.billtype
LEFT JOIN Actuarial_Services.dbo.ADS_Providers AS adsp
	ON adsc.ProviderID = adsp.ProviderID
LEFT JOIN CCAMIS_Common.dbo.[Services] AS svc
	ON adsc.HCPCS = svc.Prime_code_full
WHERE adsc.ToDate BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
	AND adsc.CCAID BETWEEN 5364521036 AND 5369999999
	AND (
		adsc.provname LIKE '%hospice%'
		OR adsp.VEND_Name LIKE '%hospice%'
		OR adsp.PROV_LASTNAME LIKE '%hospice%'
		OR adsp.prov_leaf_name = 'Hospice'
	)
PRINT '#hospice_ADS'
-- SELECT * FROM #hospice_ADS ORDER BY CCAID, FromDate, ToDate


IF OBJECT_ID('tempdb..#hospice_hcfa') IS NOT NULL DROP TABLE #hospice_hcfa

; WITH all_dates AS (
	SELECT DISTINCT
		NAME_ID
		, ENROLLMENT_DATE
		, CAST(TRANSACTION_DATA AS DATE) AS 'TRANSACTION_DATA'
		, TRANS_REPLY_CODE
		, TRC_SHORTNAME
	-- SELECT TOP 1000 *
	FROM MPSnapshotProd.dbo.HCFA_ARCH_TRR AS hat
	WHERE TRANS_REPLY_CODE IN ('071', '072', '090')
), start_min AS (
	SELECT
		NAME_ID
		, MIN(ENROLLMENT_DATE) AS 'hospice_start_min'
	FROM all_dates
	WHERE TRANS_REPLY_CODE = '071'
	GROUP BY
		NAME_ID
), all_dates_rows AS (
	SELECT
		a.*
		, ROW_NUMBER() OVER (PARTITION BY a.NAME_ID ORDER BY a.ENROLLMENT_DATE, a.TRANS_REPLY_CODE) AS 'member_row'
		, ROW_NUMBER() OVER (PARTITION BY a.NAME_ID, a.TRANS_REPLY_CODE ORDER BY a.TRANSACTION_DATA) AS 'trans_row'
		, ROW_NUMBER() OVER (PARTITION BY a.NAME_ID, a.TRANS_REPLY_CODE ORDER BY a.TRANSACTION_DATA DESC) AS 'trans_row_desc'
	FROM all_dates AS a
	INNER JOIN start_min AS s	-- only include dates that are on or after the earliest hospice start date
		ON a.NAME_ID = s.NAME_ID
		AND a.TRANSACTION_DATA >= s.hospice_start_min
), end_dates_corrected AS (
	SELECT
		starts.NAME_ID
		, starts.ENROLLMENT_DATE AS 'hospice_begin'
		, ends.TRANSACTION_DATA AS 'hospice_end'
		, deaths.TRANSACTION_DATA AS 'member_death'
		, COALESCE(CASE WHEN COALESCE(DATEDIFF(DD, ends.TRANSACTION_DATA, deaths.TRANSACTION_DATA), 0) < 0 THEN deaths.TRANSACTION_DATA ELSE ends.TRANSACTION_DATA END
				, deaths.TRANSACTION_DATA
				, CAST('2017-12-31' AS DATE)
			) AS 'hospice_end_corrected'
		, DATEDIFF(DD, 
			starts.ENROLLMENT_DATE
			, COALESCE(CASE WHEN COALESCE(DATEDIFF(DD, ends.TRANSACTION_DATA, deaths.TRANSACTION_DATA), 0) < 0 THEN deaths.TRANSACTION_DATA ELSE ends.TRANSACTION_DATA END
				, deaths.TRANSACTION_DATA
				, CAST('2017-12-31' AS DATE)
			)) AS 'hospice_days'
	FROM all_dates_rows AS starts
	LEFT JOIN all_dates_rows AS ends
		ON starts.NAME_ID = ends.NAME_ID
		AND ends.TRANS_REPLY_CODE = '072'
		AND starts.member_row + 1 = ends.member_row
		AND (
			starts.trans_row = ends.trans_row
			OR starts.trans_row_desc = ends.trans_row_desc
		)
	LEFT JOIN all_dates_rows AS deaths
		ON starts.NAME_ID = deaths.NAME_ID
		AND deaths.TRANS_REPLY_CODE = '090'
	WHERE starts.TRANS_REPLY_CODE = '071'
)
SELECT
	ID_crosswalk.CCAID
	--, xx.NAME_ID
	, xx.hospice_begin
	, xx.hospice_end_corrected AS 'hospice_end'
	, 'HCFA_ARCH_TRR' AS 'source'
	, 'HCFA_ARCH_TRR' AS 'source2'
	, meh.Product
INTO #hospice_hcfa
FROM (
	SELECT
		*
		, ROW_NUMBER() OVER (PARTITION BY NAME_ID, hospice_end_corrected ORDER BY hospice_begin DESC) AS 'last_end'
		, DATEDIFF(DD, hospice_begin, hospice_end_corrected) AS 'hospice_days'
	FROM (
		SELECT DISTINCT
			NAME_ID
			, hospice_begin
			, hospice_end_corrected
		FROM end_dates_corrected
	) AS x
	WHERE hospice_end_corrected BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
) AS xx
INNER JOIN (
	SELECT DISTINCT
		CCAID
		, NAME_ID
	FROM Medical_Analytics.dbo.member_enrollment_history
) AS ID_crosswalk
	ON xx.NAME_ID = ID_crosswalk.NAME_ID
INNER JOIN CCAMIS_Common.dbo.Dim_date AS d 
	ON xx.hospice_end_corrected = d.[Date]
INNER JOIN Medical_Analytics.dbo.member_enrollment_history AS meh
	ON xx.NAME_ID = meh.NAME_ID
	AND d.member_month = meh.member_month
WHERE xx.last_end = 1
	AND xx.hospice_days BETWEEN 0 AND 90
ORDER BY
	xx.NAME_ID
	, xx.hospice_begin
	, xx.hospice_end_corrected
PRINT '#hospice_hcfa'
-- SELECT * FROM #hospice_hcfa ORDER BY CCAID, hospice_begin, hospice_end


IF OBJECT_ID('tempdb..#hospice_ezcap') IS NOT NULL DROP TABLE #hospice_ezcap

-- DROP TABLE #hospice_ezcap
SELECT
	CAST(cmv.MEMBID AS BIGINT) AS 'CCAID'
	--, ID_crosswalk.NAME_ID
	, CAST(MIN(cd.FROMDATESVC) AS DATE) AS 'hospice_begin'
	, CAST(MAX(cd.TODATESVC) AS DATE) AS 'hospice_end'
	, 'EZCAP_DTS' AS 'source'
	, CASE WHEN cmv.BILLTYPE in ('811', '812', '813', '814', '821') THEN 'BILLTYPE'
		WHEN cmv.OUTCOME in ('40', '41', '42') THEN 'OUTCOME'
		WHEN LTRIM(RTRIM(cd.HSERVICECD)) in ('651', '656', '658') THEN 'HSERVICECD'
		WHEN LTRIM(RTRIM(cd.PROCCODE)) in ('Q5004', 'S9126', 'T2042', 'T2045', 'Q5001') THEN 'PROCCODE'
		WHEN cmv.PLACESVC = '34' THEN 'PLACESVC'
		ELSE '' END AS 'source2'
	, meh.Product
INTO #hospice_ezcap
-- SELECT *
FROM EZCAP_DTS.dbo.CLAIM_DETAILS AS cd
LEFT JOIN EZCAP_DTS.dbo.CLAIM_MASTERS_V AS cmv
	ON cd.CLAIMNO = cmv.CLAIMNO
INNER JOIN (
	SELECT DISTINCT
		CAST(CCAID AS VARCHAR(10)) AS 'CCAID'
		, NAME_ID
	FROM Medical_Analytics.dbo.member_enrollment_history
) AS ID_crosswalk
	ON cmv.MEMBID = ID_crosswalk.CCAID
INNER JOIN CCAMIS_Common.dbo.Dim_date AS d 
	ON cd.TODATESVC = d.[Date]
	AND cd.TODATESVC BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
INNER JOIN Medical_Analytics.dbo.member_enrollment_history AS meh
	ON ID_crosswalk.NAME_ID = meh.NAME_ID
	AND d.member_month = meh.member_month
WHERE
	(
		cmv.BILLTYPE IN ('811', '812', '813', '814', '821')
		OR cmv.OUTCOME IN ('40', '41', '42')
		OR LTRIM(RTRIM(cd.HSERVICECD)) IN ('651', '656', '658')
		OR LTRIM(RTRIM(cd.PROCCODE)) IN ('Q5004', 'S9126', 'T2042', 'T2045', 'Q5001')
		OR cmv.PLACESVC = '34'
	)
GROUP BY
	cmv.MEMBID
	, ID_crosswalk.NAME_ID
	, CASE WHEN cmv.BILLTYPE in ('811', '812', '813', '814', '821') THEN 'BILLTYPE'
		WHEN cmv.OUTCOME in ('40', '41', '42') THEN 'OUTCOME'
		WHEN LTRIM(RTRIM(cd.HSERVICECD)) in ('651', '656', '658') THEN 'HSERVICECD'
		WHEN LTRIM(RTRIM(cd.PROCCODE)) in ('Q5004', 'S9126', 'T2042', 'T2045', 'Q5001') THEN 'PROCCODE'
		WHEN cmv.PLACESVC = '34' THEN 'PLACESVC'
		ELSE '' END
	, meh.Product
HAVING
	MAX(cd.TODATESVC) >= '2014-01-01'
	AND DATEDIFF(DD, MIN(cd.FROMDATESVC), MAX(cd.TODATESVC)) BETWEEN 0 AND 90
PRINT '#hospice_ezcap'
-- SELECT * FROM #hospice_ezcap ORDER BY hospice_begin, hospice_end, CCAID


--IF OBJECT_ID('tempdb..#hospice_days') IS NOT NULL GOTO skip_hospice_days

---- DROP TABLE #hospice_days
--SELECT DISTINCT
--	all_rows.CCAID
--	, CAST(d.[Date] AS DATE) AS 'hospice_day'
--INTO #hospice_days
--FROM (
--		SELECT DISTINCT
--			CCAID
--			, hospice_begin
--			, hospice_end
--		FROM #hospice_hcfa
--	UNION ALL
--		SELECT DISTINCT
--			CCAID
--			, hospice_begin
--			, hospice_end
--		FROM #hospice_ezcap
--) AS all_rows
--LEFT JOIN CCAMIS_Common.dbo.Dim_date AS d
--	ON d.[Date] BETWEEN all_rows.hospice_begin AND all_rows.hospice_end
--ORDER BY
--	CCAID
--	, hospice_day
---- SELECT * FROM #hospice_days ORDER BY CCAID, hospice_day
---- SELECT COUNT(*) FROM #hospice_days	-- 51358

--skip_hospice_days:


--IF OBJECT_ID('tempdb..#hospice_spans') IS NOT NULL GOTO skip_hospice_spans

---- DROP TABLE #hospice_spans
--; WITH hospice_span_ends AS (
--	SELECT DISTINCT
--		h1.*
--		, CASE WHEN h2.hospice_day IS NULL THEN h1.hospice_day END AS 'start_flag'
--		, CASE WHEN h0.hospice_day IS NULL THEN h1.hospice_day END AS 'end_flag'
--	FROM #hospice_days AS h1
--	LEFT JOIN #hospice_days AS h0
--		ON h1.CCAID = h0.CCAID
--		AND DATEADD(DD, -1, h0.hospice_day) = h1.hospice_day
--	LEFT JOIN #hospice_days AS h2
--		ON h1.CCAID = h2.CCAID
--		AND DATEADD(DD, 1, h2.hospice_day) = h1.hospice_day
--	--ORDER BY
--	--	h1.CCAID
--	--	, h1.hospice_day
--), start_counts AS (
--	SELECT
--		CCAID
--		, hospice_day
--		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY start_flag) AS 'start_count'
--	FROM hospice_span_ends
--	WHERE start_flag IS NOT NULL
--), end_counts AS (
--	SELECT
--		CCAID
--		, hospice_day
--		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY end_flag) AS 'end_count'
--	FROM hospice_span_ends
--	WHERE end_flag IS NOT NULL
--)
--SELECT DISTINCT
--	hs.CCAID
--	, hs.hospice_day AS 'hospice_begin'
--	, he.hospice_day AS 'hospice_end'
--	, ROW_NUMBER() OVER (PARTITION BY hs.CCAID ORDER BY hs.hospice_day) AS 'span_earliest'
--	, ROW_NUMBER() OVER (PARTITION BY hs.CCAID ORDER BY hs.hospice_day DESC) AS 'span_latest'
--INTO #hospice_spans
--FROM start_counts AS hs
--INNER JOIN end_counts AS he
--	ON hs.CCAID = he.CCAID
--	AND hs.start_count = he.end_count
--ORDER BY
--	hs.CCAID
--	, hs.hospice_day
---- SELECT * FROM #hospice_spans ORDER BY CCAID, hospice_begin, hospice_end

--skip_hospice_spans:


SELECT DISTINCT
	CCAID, Product, 'hospice' AS 'service'
FROM (
		SELECT DISTINCT CCAID, Product FROM #hospice_ADS
	UNION ALL
		SELECT DISTINCT CCAID, Product FROM #hospice_hcfa
	UNION ALL
		SELECT DISTINCT CCAID, Product FROM #hospice_ezcap
) AS hospice
ORDER BY CCAID

