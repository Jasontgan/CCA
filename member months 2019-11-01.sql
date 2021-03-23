
-- 11:29 to run -- 2019-11-01-0739

-- #kd_ALL_enroll_ALL:
-- all valid enrollment spans
-- see \\cca-fs1\groups\CrossFunctional\IT\MP Data Dictionaries\Program_id definitions.xlsx for PROGRAM_ID definitions (M30 = active; M90 = disenrolled)

IF OBJECT_ID('tempdb..#kd_ALL_enroll_ALL') IS NOT NULL DROP TABLE #kd_ALL_enroll_ALL

; WITH enrollment_spans AS (
	SELECT DISTINCT
		ds.VALUE AS 'Product'
		, n.PROGRAM_ID
		, n.NAME_ID
		, CAST(n.TEXT2 AS BIGINT) AS 'CCAID'
		, CAST(a.TEXT1 AS BIGINT) AS 'Medicaid_ID'
		, CAST(ds.[START_DATE] AS DATE) AS 'MP_enroll_begin'
		, CAST(COALESCE(ds.END_DATE, '9999-12-30') AS DATE) AS 'MP_enroll_end'
		, (SELECT MAX(UPDATE_DATE) FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP) AS 'MP_DATE'
	-- SELECT TOP 100 *
	FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS a
	INNER JOIN MPSnapshotProd.dbo.NAME AS n
		ON a.[ENTITY_ID] = n.NAME_ID
		--AND n.PROGRAM_ID <> 'XXX'	--2019-11-25
		AND n.TEXT2 LIKE '536_______'
	INNER JOIN MPSnapshotProd.dbo.DATE_SPAN AS ds
		ON n.NAME_ID = ds.NAME_ID
		AND ds.COLUMN_NAME = 'name_text19'
		AND ds.VALUE IN ('ICO', 'SCO')
		AND ds.CARD_TYPE = 'MCAID App'
		AND COALESCE(ds.END_DATE, '9999-12-30') > ds.[START_DATE]
	WHERE a.APP_TYPE = 'MCAID'
		AND NOT (n.PROGRAM_ID = 'XXX' AND ds.END_DATE IS NULL)	--2019-11-25
), date_limit AS (
	SELECT DISTINCT
		CASE WHEN (SELECT MAX(MP_enroll_begin) FROM enrollment_spans) > (SELECT DATEADD(MM, 4, GETDATE()))						-- if the latest enrollment start is more than four months from now, then
			THEN CAST(DATEADD(DD, -DAY((SELECT DATEADD(MM, 4, GETDATE()))), (SELECT DATEADD(MM, 4, GETDATE()))) AS DATE)			-- limit spans to the end of fourth month from now
			ELSE DATEADD(DD, -1, DATEADD(MM, 1, (SELECT MAX(MP_enroll_begin) FROM enrollment_spans)))								-- otherwise limit spans to the end of the month of the latest enrollment start
		END AS 'last_mm'
	FROM enrollment_spans
)
SELECT DISTINCT
	es.*
	, CAST(d.member_month AS DATE) AS 'member_month'
	, 1 AS 'MP_enroll'
INTO #kd_ALL_enroll_ALL
FROM enrollment_spans AS es
INNER JOIN CCAMIS_Common.dbo.Dim_date AS d
	ON d.[Date] BETWEEN es.MP_enroll_begin AND es.MP_enroll_end
	AND d.[Date] <= (SELECT last_mm FROM date_limit)
PRINT '#kd_ALL_enroll_ALL'
-- SELECT * FROM #kd_ALL_enroll_ALL ORDER BY CCAID, MP_enroll_begin, MP_enroll_end, member_month
-- SELECT COUNT(*) FROM #kd_ALL_enroll_ALL		--1931797
-- SELECT MAX(MP_enroll_begin) FROM #kd_ALL_enroll_ALL
-- SELECT MAX(MP_enroll_end) FROM #kd_ALL_enroll_ALL WHERE MP_enroll_end <> '9999-12-30'
-- SELECT * FROM #kd_ALL_enroll_ALL WHERE CCAID IN (5365617011, 5365552953) ORDER BY CCAID, MP_enroll_begin, MP_enroll_end, member_month
-- SELECT COUNT(DISTINCT CCAID) FROM #kd_ALL_enroll_ALL		--56727


-- seamless enrollment spans by product
IF OBJECT_ID('tempdb..#continuous_enroll') IS NOT NULL DROP TABLE #continuous_enroll

; WITH distinct_spans AS (
	SELECT DISTINCT		--69940
		Product
		, NAME_ID
		, MP_enroll_begin
		, MP_enroll_end
	FROM #kd_ALL_enroll_ALL
), Enroll (Product, NAME_ID, SeqNo, MP_enroll_begin1, MP_enroll_begin, MP_enroll_end) AS (
		SELECT
			a.Product
			, a.NAME_ID
			, 1
			, a.MP_enroll_begin
			, a.MP_enroll_begin
			, a.MP_enroll_end
		FROM distinct_spans AS a
		WHERE NOT EXISTS (
			SELECT
				a1.NAME_ID
			FROM distinct_spans AS a1
			WHERE a.NAME_ID = a1.NAME_ID
				AND a.Product = a1.Product
				AND DATEADD(DD, 1, a1.MP_enroll_end) = a.MP_enroll_begin
		)
	UNION ALL
		SELECT
			c.Product
			, c.NAME_ID
			, c.SeqNo + 1
			, c.MP_enroll_begin1
			, a.MP_enroll_begin
			, a.MP_enroll_end
		FROM Enroll AS c
		INNER JOIN distinct_spans AS a
			ON c.NAME_ID = a.NAME_ID
			AND c.Product = a.Product
		WHERE DATEADD(DD, 1, c.MP_enroll_end) = a.MP_enroll_begin
)
SELECT
	e1.NAME_ID
	, e1.Product
	, e1.SeqNo AS 'enroll_span'
	, e1.MP_enroll_begin1 AS 'enroll_begin'
	, e1.MP_enroll_end AS 'enroll_end'
INTO #continuous_enroll
FROM Enroll AS e1
INNER JOIN Enroll AS e2
	ON e1.NAME_ID = e2.NAME_ID
	AND e1.Product = e2.Product
	AND e1.MP_enroll_begin1 = e2.MP_enroll_begin1
GROUP BY
	e1.NAME_ID
	, e1.Product
	, e1.MP_enroll_begin1
	, e1.MP_enroll_end
	, e1.SeqNo
HAVING MAX(e2.SeqNo) = e1.SeqNo
PRINT '#continuous_enroll'
-- SELECT * FROM #continuous_enroll ORDER BY NAME_ID, enroll_begin, enroll_end
-- SELECT COUNT(*) FROM #continuous_enroll		--63792
-- SELECT COUNT(DISTINCT NAME_ID) FROM #continuous_enroll		--56185

-- SELECT * FROM #kd_ALL_enroll_ALL ORDER BY NAME_ID, MP_enroll_begin, MP_enroll_end
-- SELECT * FROM #kd_ALL_enroll_ALL WHERE NAME_ID = 'N00000117868' ORDER BY NAME_ID, member_month
-- SELECT * FROM #kd_ALL_enroll_ALL WHERE NAME_ID IN ('N00005528263', 'N00010473987', 'N00017982899', 'N00009808280') ORDER BY NAME_ID, MP_enroll_begin, MP_enroll_end
-- SELECT * FROM #kd_ALL_enroll_ALL WHERE NAME_ID IN ('N00000119874', 'N00005532637', 'N00005644868', 'N00005803341', 'N00005817960', 'N00005846206', 'N00006194743', 'N00009016268', 'N00009155741', 'N00011528060', 'N00013598572', 'N00019232448') ORDER BY NAME_ID, MP_enroll_begin, MP_enroll_end

-- SELECT * FROM #continuous_enroll WHERE NAME_ID = 'N00000117868' ORDER BY NAME_ID, enroll_begin, enroll_end
-- SELECT * FROM #continuous_enroll WHERE NAME_ID IN ('N00005528263', 'N00010473987', 'N00017982899', 'N00009808280') ORDER BY NAME_ID, enroll_begin, enroll_end
-- SELECT * FROM #continuous_enroll WHERE NAME_ID IN ('N00000119874', 'N00005532637', 'N00005644868', 'N00005803341', 'N00005817960', 'N00005846206', 'N00006194743', 'N00009016268', 'N00009155741', 'N00011528060', 'N00013598572', 'N00019232448') ORDER BY NAME_ID, enroll_begin, enroll_end


-- rate cell spans
IF OBJECT_ID('tempdb..#RC_spans') IS NOT NULL DROP TABLE #RC_spans

SELECT DISTINCT
	ds.NAME_ID
	, ds.VALUE AS 'RC_MP'
	, CAST(ds.[START_DATE] AS DATE) AS 'MP_rc_begin'
	, CAST(COALESCE(ds.END_DATE, '9999-12-30') AS DATE) AS 'MP_rc_end'
	--, d.member_month
INTO #RC_spans
FROM MPSnapshotProd.dbo.DATE_SPAN AS ds
INNER JOIN MPSnapshotProd.dbo.NAME AS n
	ON ds.NAME_ID = n.NAME_ID
	AND n.PROGRAM_ID <> 'XXX'
	AND n.TEXT2 LIKE '536_______'
WHERE ds.CARD_TYPE = 'MCAID App'
	AND ds.COLUMN_NAME = 'name_text14'
	AND ds.VALUE <> '99'
	AND ds.VALUE IS NOT NULL
	AND ds.[START_DATE] < COALESCE(ds.END_DATE, '9999-12-30')
PRINT '#RC_spans'
-- SELECT * FROM #RC_spans ORDER BY NAME_ID, MP_rc_begin
-- SELECT COUNT(*) FROM #RC_spans		--64064
-- SELECT COUNT(DISTINCT NAME_ID) FROM #RC_spans		--36739
-- SELECT * FROM #RC_spans WHERE NAME_ID = 'N00000117576' ORDER BY NAME_ID, MP_rc_begin
-- SELECT * FROM #RC_spans WHERE NAME_ID = 'N00002917941' ORDER BY NAME_ID, MP_rc_begin


-- seamless RC spans
-- note that this uses a different method than the enrollment spans above
-- the enrollment span method didn't work here because of a recursion error; so:
--		enrollment spans are consolidated using Karen's recursion method
--		RC spans are consolidated by finding the edges of a particular span by month
-- when I tried consolidating the enrollment spans using the RC method, it took much longer -- 6:19 using edge detection vs 0:49 using Karen's recursion
IF OBJECT_ID('tempdb..#continuous_rc') IS NOT NULL DROP TABLE #continuous_rc

; WITH RC_mm AS (
	SELECT DISTINCT
		rcs.*
		, d.member_month
	FROM #RC_spans AS rcs
	INNER JOIN CCAMIS_Common.dbo.Dim_date AS d
		ON d.[Date] BETWEEN rcs.MP_rc_begin AND COALESCE(rcs.MP_rc_end, DATEADD(MM, 4, GETDATE()))
), RC_starts_ends AS (
	SELECT
		r1.*
		, CASE WHEN r0.member_month IS NULL OR r1.RC_MP <> r0.RC_MP THEN r1.member_month END AS 'starts'
		, CASE WHEN r2.member_month IS NULL OR r1.RC_MP <> r2.RC_MP THEN r1.member_month END AS 'ends'
	FROM RC_mm AS r1
	LEFT JOIN RC_mm AS r0
		ON r1.NAME_ID = r0.NAME_ID
		AND r1.member_month = DATEADD(MM, 1, r0.member_month)
	LEFT JOIN RC_mm AS r2
		ON r1.NAME_ID = r2.NAME_ID
		AND r1.member_month = DATEADD(MM, -1, r2.member_month)
), RC_start_counts AS (
	SELECT
		NAME_ID
		, RC_MP
		, starts
		, ROW_NUMBER() OVER (PARTITION BY NAME_ID ORDER BY starts) AS 'start_count'
	FROM RC_starts_ends
	WHERE starts IS NOT NULL
), RC_end_counts AS (
	SELECT
		NAME_ID
		, RC_MP
		, CASE WHEN ends > GETDATE() THEN '9999-12-30' ELSE ends END AS 'ends'
		, ROW_NUMBER() OVER (PARTITION BY NAME_ID ORDER BY ends) AS 'end_count'
	FROM RC_starts_ends
	WHERE ends IS NOT NULL
)
SELECT
	rcsc.NAME_ID
	, rcsc.RC_MP
	, rcsc.start_count AS 'RC_span'
	, CAST(rcsc.starts AS DATE) AS 'RC_begin'
	, CASE WHEN rcec.ends = '9999-12-30' THEN '9999-12-30' ELSE CAST(DATEADD(DD, -1, DATEADD(MM, 1, rcec.ends)) AS DATE) END AS 'RC_end'
INTO #continuous_rc
FROM RC_start_counts AS rcsc
INNER JOIN RC_end_counts AS rcec
	ON rcsc.NAME_ID = rcec.NAME_ID
	AND rcsc.start_count = rcec.end_count
ORDER BY
	rcsc.NAME_ID
	, rcsc.starts
PRINT '#continuous_rc'
-- SELECT * FROM #continuous_rc ORDER BY NAME_ID, RC_span
-- SELECT COUNT(*) FROM #continuous_rc		--92109
-- SELECT COUNT(DISTINCT NAME_ID) FROM #continuous_rc		--56333
-- SELECT * FROM #continuous_rc WHERE NAME_ID IN ('N00027104617', 'N00005805305', 'N00007582658') ORDER BY NAME_ID, RC_span


-- enrollment plus other tables
IF OBJECT_ID('tempdb..#combined_enroll_rc') IS NOT NULL DROP TABLE #combined_enroll_rc

SELECT DISTINCT
	enr.CCAID
	, enr.Medicaid_ID
	, enr.NAME_ID
	, enr.member_month
	, enr.Product
	, rc.Product2
	, CASE WHEN rc.Product2 = 'SCO Dual' THEN 'SCO'
		WHEN rc.Product2 = 'SCO Medicaid' THEN 'MHO'
		WHEN rc.Product2 LIKE 'One Care%' THEN 'ICO'
		END AS 'Product3'
	, enr.MP_enroll
	--, enr.MP_enroll_begin
	--, enr.MP_enroll_end
	, cenr.enroll_begin
	, cenr.enroll_end
	, RTRIM(rc.MPCode) AS 'MPCode'
	--, rc.MP_RC_Group
	, RTRIM(rc.ReportingClass) AS 'ReportingClass'
	--, rc.RatingCode
	--, rc.MedicaidRating_Code
	, rc.Class
	, rc.Dual
	, rc.Region
	, crc.RC_begin
	, crc.RC_end
INTO #combined_enroll_rc
FROM #kd_ALL_enroll_ALL AS enr
INNER JOIN #continuous_enroll AS cenr
	ON enr.NAME_ID = cenr.NAME_ID
	AND enr.Product = cenr.Product
	AND enr.member_month BETWEEN cenr.enroll_begin AND cenr.enroll_end
LEFT JOIN #continuous_rc AS crc
	ON enr.NAME_ID = crc.NAME_ID
	AND enr.member_month BETWEEN crc.RC_begin AND crc.RC_end
LEFT JOIN CCAMIS_Common.dbo.rating_categories AS rc
	ON crc.RC_MP = rc.MPCode
	AND rc.Product IN ('ICO', 'SCO')
ORDER BY
	CCAID
	, member_month
PRINT '#combined_enroll_rc'
-- SELECT * FROM #combined_enroll_rc ORDER BY CCAID, member_month
-- SELECT COUNT(*) FROM #combined_enroll_rc		--1931071
-- SELECT COUNT(DISTINCT NAME_ID) FROM #combined_enroll_rc		--56185
-- SELECT COUNT(DISTINCT CCAID) FROM #combined_enroll_rc			--56185
-- SELECT * FROM #combined_enroll_rc WHERE NAME_ID IN ('N00005528263', 'N00010473987', 'N00017982899', 'N00009808280') ORDER BY NAME_ID, member_month
-- SELECT * FROM #combined_enroll_rc WHERE NAME_ID IN ('N00000119874', 'N00005532637', 'N00005644868', 'N00005803341', 'N00005817960', 'N00005846206', 'N00006194743', 'N00009016268', 'N00009155741', 'N00011528060', 'N00013598572', 'N00019232448') ORDER BY NAME_ID, member_month
-- SELECT * FROM #combined_enroll_rc WHERE NAME_ID IN ('N00000117576') ORDER BY NAME_ID, member_month
-- SELECT * FROM #combined_enroll_rc WHERE NAME_ID IN ('N00002917941') ORDER BY NAME_ID, member_month
-- SELECT DISTINCT CCAID, Product, enroll_begin, enroll_end FROM #combined_enroll_rc ORDER BY CCAID, Product, enroll_begin, enroll_end
-- SELECT DISTINCT CCAID, Product, enroll_begin, enroll_end FROM #combined_enroll_rc WHERE enroll_end = '9999-12-30' ORDER BY CCAID, Product, enroll_begin, enroll_end
-- SELECT DISTINCT CCAID, Product, enroll_begin, enroll_end FROM #combined_enroll_rc WHERE enroll_end = '2019-09-30' ORDER BY CCAID, Product, enroll_begin, enroll_end
-- SELECT DISTINCT CCAID, Product, enroll_begin, enroll_end FROM #combined_enroll_rc WHERE enroll_end >= GETDATE() ORDER BY CCAID, Product, enroll_begin, enroll_end
-- SELECT DISTINCT Product, Product2, Product3 FROM #combined_enroll_rc ORDER BY Product, Product2, Product3
-- SELECT DISTINCT CCAID, NAME_ID, MPCode, RC_begin, RC_end FROM #combined_enroll_rc ORDER BY CCAID, NAME_ID, MPCode, RC_begin, RC_end
-- SELECT * FROM #combined_enroll_rc WHERE CCAID = 5365573352 ORDER BY CCAID, member_month
-- SELECT * FROM #RC_spans WHERE NAME_ID = 'N00007600015' ORDER BY NAME_ID, MP_rc_begin
-- SELECT * FROM #combined_enroll_rc WHERE RC_end IS NULL ORDER BY CCAID, member_month
-- SELECT * FROM #RC_spans WHERE NAME_ID = 'N00000117571' ORDER BY NAME_ID, MP_rc_begin
-- SELECT * FROM #combined_enroll_rc WHERE CCAID = 5364521045 ORDER BY CCAID, member_month
-- SELECT * FROM #combined_enroll_rc WHERE CCAID = 5365774361 ORDER BY CCAID, member_month
-- SELECT * FROM #combined_enroll_rc WHERE RC_begin IS NULL ORDER BY CCAID, member_month
-- SELECT * FROM #combined_enroll_rc WHERE NAME_ID IN ('N00027104617', 'N00005805305', 'N00007582658') ORDER BY NAME_ID, member_month

-- members with gaps in their RC spans
-- SELECT * FROM #combined_enroll_rc WHERE CCAID IN (SELECT DISTINCT CCAID FROM #combined_enroll_rc WHERE RC_begin IS NULL) ORDER BY CCAID, member_month


-- picking up the latest RC for lapsed spans
-- repairs flagged under RC_cont_flag
IF OBJECT_ID('tempdb..#combined_enroll_rc_2') IS NOT NULL DROP TABLE #combined_enroll_rc_2

; WITH ended_spans AS (
	SELECT
		*
		, CASE WHEN RC_end <> '9999-12-30' THEN DATEADD(DD, 1, RC_end) END AS 'noRC_begin'
	FROM #continuous_rc
), final_enrollments AS (		-- final enrollment spans
	SELECT
		c.NAME_ID
		, c.enroll_begin
		, c.enroll_end
	FROM #combined_enroll_rc AS c
	INNER JOIN #combined_enroll_rc AS c2
		ON c.NAME_ID = c2.NAME_ID
	GROUP BY
		c.NAME_ID
		, c.enroll_begin
		, c.enroll_end
	HAVING MAX(c2.enroll_begin) = c.enroll_begin
		AND MAX(c2.enroll_end) = c.enroll_end
), rc_end_spans AS (
	SELECT
		es.NAME_ID
		, es.RC_MP
		, es.noRC_begin
		, final_enrollments.enroll_end AS 'noRC_end'
	FROM ended_spans AS es
	INNER JOIN final_enrollments
		ON es.NAME_ID = final_enrollments.NAME_ID
		AND es.noRC_begin BETWEEN final_enrollments.enroll_begin AND final_enrollments.enroll_end
), persistent_rc_spans AS (				-- spans outside of RC spans, with previous RC brought forward
		SELECT									-- intermediate spans (where there is a later span start)
			es.NAME_ID
			, es.RC_MP
			, es.noRC_begin
			, DATEADD(DD, -1, es2.RC_begin) AS 'noRC_end'
		FROM ended_spans AS es
		INNER JOIN ended_spans AS es2
			ON es.NAME_ID = es2.NAME_ID
			AND es.RC_span = es2.RC_span - 1
			AND es.noRC_begin <> es2.RC_begin
		WHERE es2.RC_begin IS NOT NULL
			AND es.noRC_begin IS NOT NULL
	UNION ALL
		SELECT									-- end spans (where there are no more later spans)
			rces.NAME_ID
			, rces.RC_MP
			, rces.noRC_begin
			, rces.noRC_end
		FROM rc_end_spans AS rces
		INNER JOIN rc_end_spans AS rces2
			ON rces.NAME_ID = rces2.NAME_ID
		GROUP BY
			rces.NAME_ID
			, rces.RC_MP
			, rces.noRC_begin
			, rces.noRC_end
		HAVING MAX(rces2.noRC_begin) = rces.noRC_begin
), patched_spans AS (
	SELECT DISTINCT
		rcg.CCAID
		, rcg.Medicaid_ID
		, rcg.NAME_ID
		, rcg.member_month
		, rcg.Product
		, COALESCE(rcg.Product2, rc.Product2) AS 'Product2'
		, CASE WHEN COALESCE(rcg.Product2, rc.Product2) = 'SCO Dual' THEN 'SCO'
			WHEN COALESCE(rcg.Product2, rc.Product2) = 'SCO Medicaid' THEN 'MHO'
			WHEN COALESCE(rcg.Product2, rc.Product2) LIKE 'One Care%' THEN 'ICO'
			END AS 'Product3'
		, rcg.MP_enroll
		, rcg.enroll_begin
		, rcg.enroll_end
		, COALESCE(rcg.MPCode, prcs.RC_MP) AS 'MPCode'
		, RTRIM(COALESCE(rcg.ReportingClass, rc.ReportingClass)) AS 'ReportingClass'
		, RTRIM(COALESCE(rcg.Class, rc.Class)) AS 'Class'
		, RTRIM(COALESCE(rcg.Dual, rc.Dual)) AS 'Dual'
		, RTRIM(COALESCE(rcg.Region, rc.Region)) AS 'Region'
		, COALESCE(rcg.RC_begin, prcs.noRC_begin) AS 'RC_begin'
		, COALESCE(rcg.RC_end, prcs.noRC_end) AS 'RC_end'
		, CASE WHEN rcg.MPCode IS NULL AND prcs.RC_MP IS NOT NULL THEN 1 ELSE 0 END AS 'RC_cont_flag'
	--INTO #combined_enroll_rc_2
	FROM #combined_enroll_rc AS rcg
	LEFT JOIN persistent_rc_spans AS prcs
		ON rcg.NAME_ID = prcs.NAME_ID
		AND rcg.member_month BETWEEN prcs.noRC_begin AND prcs.noRC_end
	LEFT JOIN CCAMIS_Common.dbo.rating_categories AS rc
		ON COALESCE(rcg.MPCode, prcs.RC_MP) = rc.MPCode
		AND rc.Product IN ('ICO', 'SCO')
	--ORDER BY
	--	rcg.CCAID
	--	, rcg.member_month
) -- this fixes situations where a gap in a RC span (while the member is still enrolled) creates a new RC_end month and a duplicate row	--2019-12-17
SELECT
	CCAID
	, Medicaid_ID
	, NAME_ID
	, member_month
	, Product
	, Product2
	, Product3
	, MP_enroll
	, enroll_begin
	, enroll_end
	, MPCode
	, ReportingClass
	, Class
	, Dual
	, Region
	, RC_begin
	, MAX(RC_end) AS 'RC_end'
	, RC_cont_flag
INTO #combined_enroll_rc_2
FROM patched_spans
GROUP BY
	CCAID
	, Medicaid_ID
	, NAME_ID
	, member_month
	, Product
	, Product2
	, Product3
	, MP_enroll
	, enroll_begin
	, enroll_end
	, MPCode
	, ReportingClass
	, Class
	, Dual
	, Region
	, RC_begin
	--, MAX(RC_end) AS 'RC_end'
	, RC_cont_flag
ORDER BY
	CCAID
	, member_month

PRINT '#combined_enroll_rc_2'
-- SELECT * FROM #combined_enroll_rc_2 ORDER BY CCAID, member_month
-- SELECT COUNT(*) FROM #combined_enroll_rc_2		--1931651
-- SELECT * FROM #combined_enroll_rc_2 WHERE RC_cont_flag = 1 ORDER BY CCAID, member_month
-- SELECT * FROM #combined_enroll_rc_2 WHERE NAME_ID IN ('N00027104617', 'N00005805305', 'N00007582658') ORDER BY NAME_ID, member_month

-- members with gaps in their RC spans (repaired)
-- SELECT * FROM #combined_enroll_rc_2 WHERE CCAID IN (SELECT DISTINCT CCAID FROM #combined_enroll_rc WHERE RC_begin IS NULL) ORDER BY CCAID, member_month

-- problem records?
-- SELECT CCAID, member_month, COUNT(*) AS 'row_count' FROM #combined_enroll_rc_2 GROUP BY CCAID, member_month HAVING COUNT(*) > 1 ORDER BY CCAID, member_month

-- members with multiple products
/*
SELECT COUNT(*) FROM #combined_enroll_rc_2			--1931245
SELECT COUNT(*) FROM (SELECT DISTINCT CCAID, member_month FROM #combined_enroll_rc_2) AS x			--1931231
SELECT CCAID, member_month, COUNT(*) AS 'row_count' FROM #combined_enroll_rc_2 GROUP BY CCAID, member_month HAVING COUNT(*) > 1 ORDER BY CCAID, member_month

SELECT * FROM #combined_enroll_rc_2 AS cer
INNER JOIN (
	SELECT DISTINCT CCAID FROM (SELECT CCAID, member_month FROM #combined_enroll_rc_2 GROUP BY CCAID, member_month HAVING COUNT(*) > 1) AS x
) AS too_many_products
	ON cer.CCAID = too_many_products.CCAID
ORDER BY cer.CCAID, cer.member_month

SELECT COUNT(*) FROM (
	SELECT CCAID, member_month FROM #combined_enroll_rc_2 GROUP BY CCAID, member_month HAVING COUNT(*) > 1-- ORDER BY CCAID, member_month
) AS X
--14

SELECT COUNT(*) FROM (
	SELECT CCAID, member_month FROM #combined_enroll_rc_2 GROUP BY CCAID, member_month HAVING COUNT(*) = 1-- ORDER BY CCAID, member_month
) AS X
--1931217

SELECT cer2.CCAID, cer2.member_month, cer2.Product, cer2.Product2
FROM #combined_enroll_rc_2 AS cer2
INNER JOIN (
	SELECT CCAID, member_month FROM #combined_enroll_rc_2 GROUP BY CCAID, member_month HAVING COUNT(*) > 1-- ORDER BY CCAID, member_month
) AS problem_spans
	ON cer2.CCAID = problem_spans.CCAID
	AND cer2.member_month = problem_spans.member_month
ORDER BY cer2.CCAID, cer2.member_month, cer2.Product, cer2.Product2
--28

*/


-- selecting the highest product in months with more than one (assumes one, that members will only move from ICO to SCO, and two, that "SCO" comes after "One Care" alphabetically)
IF OBJECT_ID('tempdb..#combined_enroll_rc_3') IS NOT NULL DROP TABLE #combined_enroll_rc_3

SELECT
	cer2.*
INTO #combined_enroll_rc_3
FROM #combined_enroll_rc_2 AS cer2
INNER JOIN (
		SELECT cer2.CCAID, cer2.member_month, cer2.Product, MAX(cer2.Product2) AS 'Product2'
		FROM #combined_enroll_rc_2 AS cer2
		INNER JOIN (
			SELECT CCAID, member_month
			FROM #combined_enroll_rc_2
			GROUP BY CCAID, member_month
			HAVING COUNT(*) > 1
		) AS problem_spans
			ON cer2.CCAID = problem_spans.CCAID
			AND cer2.member_month = problem_spans.member_month
		GROUP BY cer2.CCAID, cer2.member_month, cer2.Product
		--ORDER BY cer2.CCAID, cer2.member_month, cer2.Product
		----14
	UNION ALL
		SELECT cer2.CCAID, cer2.member_month, cer2.Product, cer2.Product2
		FROM #combined_enroll_rc_2 AS cer2
		INNER JOIN (
			SELECT CCAID, member_month
			FROM #combined_enroll_rc_2
			GROUP BY CCAID, member_month
			HAVING COUNT(*) = 1
		) AS non_problem_spans
			ON cer2.CCAID = non_problem_spans.CCAID
			AND cer2.member_month = non_problem_spans.member_month
		GROUP BY cer2.CCAID, cer2.member_month, cer2.Product, cer2.Product2
		--ORDER BY cer2.CCAID, cer2.member_month, cer2.Product, cer2.Product2
		----1931217
) AS corrected_product
	ON cer2.CCAID = corrected_product.CCAID
	AND cer2.member_month = corrected_product.member_month
	AND cer2.Product = corrected_product.Product
	AND cer2.Product2 = corrected_product.Product2
ORDER BY
	cer2.CCAID
	, cer2.member_month
PRINT '#combined_enroll_rc_3'
-- SELECT * FROM #combined_enroll_rc_3 ORDER BY CCAID, member_month
-- SELECT COUNT(*) FROM #combined_enroll_rc_3		--1931315
-- problem records?
-- SELECT CCAID, member_month, COUNT(*) AS 'row_count' FROM #combined_enroll_rc_3 GROUP BY CCAID, member_month HAVING COUNT(*) > 1 ORDER BY CCAID, member_month


-- #services: all service spans from DATE_SPAN for all members
IF OBJECT_ID('tempdb..#services') IS NOT NULL DROP TABLE #services

; WITH service_spans AS (
	SELECT DISTINCT
		ds.NAME_ID
		, n.TEXT2 AS 'CCAID'
		, np.SERVICE_TYPE
		, np.PROVIDER_ID
		, npn.COMPANY
		, npn.NAME_FIRST
		, npn.NAME_LAST
		, CASE WHEN npn.COMPANY IS NULL THEN RTRIM(COALESCE(npn.NAME_FIRST, '') + ' ' + COALESCE(npn.NAME_LAST, ''))
			ELSE npn.COMPANY
			END AS 'prov_name'
		, np.EFF_DATE
		, np.TERM_DATE
		, npn.LETTER_COMP_CLOSE AS 'CactusProvK'
		, CASE WHEN LEN(RTRIM(npn.TEXT4)) = 10 AND ISNUMERIC(RTRIM(npn.TEXT4)) = 1 THEN RTRIM(npn.TEXT4) END AS 'NPI'
		, np.CREATE_DATE
		, np.UPDATE_DATE
	-- SELECT *
	FROM MPSnapshotProd.dbo.DATE_SPAN AS ds
	INNER JOIN MPSnapshotProd.dbo.NAME AS n
		ON ds.NAME_ID = n.NAME_ID
		AND n.PROGRAM_ID <> 'XXX'
		AND n.TEXT2 LIKE '536_______'
	LEFT JOIN MPSnapshotProd.dbo.NAME_PROVIDER AS np
		ON ds.NAME_ID = np.NAME_ID
		AND COALESCE(np.TERM_DATE, '9999-12-31') > np.EFF_DATE -- this is how invalid date spans are traditionally flagged
	LEFT JOIN MPSnapshotProd.dbo.NAME AS npn
		ON np.PROVIDER_ID = npn.NAME_ID
	WHERE ds.COLUMN_NAME = 'name_text19'
		AND ds.VALUE IN ('ICO', 'SCO')
		AND ds.CARD_TYPE = 'MCAID App'
		--AND ds.NAME_ID = 'N00028561714'
		AND NOT EXISTS (	-- manual removal of one overlapping PCP span
			SELECT DISTINCT
				ds2.NAME_ID
				, np2.PROVIDER_ID
			-- SELECT *
			FROM MPSnapshotProd.dbo.DATE_SPAN AS ds2
			INNER JOIN MPSnapshotProd.dbo.NAME AS n2
				ON ds2.NAME_ID = n2.NAME_ID
				AND n2.PROGRAM_ID <> 'XXX'
				AND n2.TEXT2 IN ('5365669777')
			INNER JOIN MPSnapshotProd.dbo.NAME_PROVIDER AS np2
				ON ds2.NAME_ID = np2.NAME_ID
				AND np2.PROVIDER_ID IN ('N00018703576')
			WHERE np2.PROVIDER_ID = np.PROVIDER_ID
				AND ds2.NAME_ID = ds.NAME_ID
		)
)
SELECT
	NAME_ID
	, CCAID
	, SERVICE_TYPE
	, PROVIDER_ID
	, COMPANY
	, NAME_FIRST
	, NAME_LAST
	, prov_name
	, EFF_DATE
	, COALESCE(TERM_DATE, '9999-12-30') AS 'TERM_DATE'
	, CactusProvK
	, NPI
	, ROW_NUMBER() OVER (PARTITION BY NAME_ID, SERVICE_TYPE ORDER BY CREATE_DATE, UPDATE_DATE) AS 'span_num'
	, (SELECT MAX(UPDATE_DATE) FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP) AS 'MP_DATE'
INTO #services
FROM service_spans
ORDER BY
	NAME_ID
	, EFF_DATE
	, TERM_DATE
	, CREATE_DATE
	, UPDATE_DATE
--CREATE INDEX memb_serv_prov ON #services_all (member_id, SERVICE_TYPE, prov_ID)
PRINT '#services'
-- SELECT * FROM #services ORDER BY CCAID, SERVICE_TYPE, EFF_DATE, TERM_DATE
-- SELECT COUNT(*) FROM #services		--572181
-- SELECT COUNT(DISTINCT NAME_ID) FROM #services		--56337
-- SELECT DISTINCT SERVICE_TYPE FROM #services ORDER BY SERVICE_TYPE
-- SELECT SERVICE_TYPE, COUNT(DISTINCT CCAID) AS 'members', MAX(EFF_DATE) 'latest_effective' FROM #services GROUP BY SERVICE_TYPE ORDER BY SERVICE_TYPE
-- SELECT * FROM #services WHERE SERVICE_TYPE = 'Supportive Care Org' ORDER BY CCAID, SERVICE_TYPE, EFF_DATE, TERM_DATE
-- SELECT * FROM #services WHERE SERVICE_TYPE = 'Pharmacy 1' ORDER BY CCAID, SERVICE_TYPE, EFF_DATE, TERM_DATE
-- SELECT * FROM #services WHERE SERVICE_TYPE = 'PCT Member 1' ORDER BY CCAID, SERVICE_TYPE, EFF_DATE, TERM_DATE


-- PCL service spans (overlaps fixed)
-- combines both 'Primary Care Loc' and 'ICO PCL' into one field
IF OBJECT_ID('tempdb..#PCL') IS NOT NULL DROP TABLE #PCL

; WITH pcl_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, pcl.CactusProvK AS 'PCL_provK'
		, pcl.NPI AS 'PCL_NPI'
		, pcl.PROVIDER_ID AS 'PCL_NAME_ID'
		, pcl.prov_name AS 'PCL_name'
		, pcl.EFF_DATE AS 'PCL_EFF_DATE'
		, pcl.TERM_DATE AS 'PCL_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS pcl
		ON cer3.CCAID = pcl.CCAID
		AND cer3.member_month BETWEEN pcl.EFF_DATE AND pcl.TERM_DATE
		AND pcl.SERVICE_TYPE IN ('Primary Care Loc', 'ICO PCL')
	--WHERE cer3.NAME_ID = 'N00004664276'
)
SELECT
	pcl1.NAME_ID
	, pcl1.member_month
	, pcl1.PCL_provK
	, pcl1.PCL_NPI
	, pcl1.PCL_NAME_ID
	, pcl1.PCL_name
	, pcl1.PCL_EFF_DATE
	, pcl1.PCL_TERM_DATE
INTO #PCL
FROM pcl_spans AS pcl1
INNER JOIN pcl_spans AS pcl2
	ON pcl1.NAME_ID = pcl2.NAME_ID
	AND pcl1.member_month = pcl2.member_month
GROUP BY
	pcl1.NAME_ID
	, pcl1.member_month
	, pcl1.PCL_provK
	, pcl1.PCL_NPI
	, pcl1.PCL_NAME_ID
	, pcl1.PCL_name
	, pcl1.PCL_EFF_DATE
	, pcl1.PCL_TERM_DATE
HAVING MAX(pcl2.PCL_EFF_DATE) = pcl1.PCL_EFF_DATE
PRINT '#PCL'
-- SELECT * FROM #PCL ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #PCL		--726631


-- PCP service spans (overlaps fixed)
-- combines both 'PCP' and 'ICO PCP' into one field
IF OBJECT_ID('tempdb..#PCP') IS NOT NULL DROP TABLE #PCP

; WITH pcp_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, pcp.CactusProvK AS 'PCP_provK'
		, pcp.NPI AS 'PCP_NPI'
		, pcp.PROVIDER_ID AS 'PCP_NAME_ID'
		, pcp.prov_name AS 'PCP_name'
		, pcp.EFF_DATE AS 'PCP_EFF_DATE'
		, pcp.TERM_DATE AS 'PCP_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS pcp
		ON cer3.CCAID = pcp.CCAID
		AND cer3.member_month BETWEEN pcp.EFF_DATE AND pcp.TERM_DATE
		AND pcp.SERVICE_TYPE IN ('PCP', 'ICO PCP')
	WHERE pcp.prov_name <> 'Telephonic RN'	-- fixes one member
)
SELECT
	pcp1.NAME_ID
	, pcp1.member_month
	, pcp1.PCP_provK
	, pcp1.PCP_NPI
	, MAX(pcp1.PCP_NAME_ID) AS 'PCP_NAME_ID'
	, pcp1.PCP_name
	, pcp1.PCP_EFF_DATE
	, pcp1.PCP_TERM_DATE
INTO #PCP
FROM pcp_spans AS pcp1
INNER JOIN pcp_spans AS pcp2
	ON pcp1.NAME_ID = pcp2.NAME_ID
	AND pcp1.member_month = pcp2.member_month
GROUP BY
	pcp1.NAME_ID
	, pcp1.member_month
	, pcp1.PCP_provK
	, pcp1.PCP_NPI
	--, pcp1.PCP_NAME_ID
	, pcp1.PCP_name
	, pcp1.PCP_EFF_DATE
	, pcp1.PCP_TERM_DATE
HAVING MAX(pcp2.PCP_EFF_DATE) = pcp1.PCP_EFF_DATE
	AND MAX(pcp2.PCP_TERM_DATE) = pcp1.PCP_TERM_DATE
	AND MAX(COALESCE(pcp2.PCP_NPI, '')) = COALESCE(pcp1.PCP_NPI, '')	-- gives preference to providers with NPI if EFF_DATE and TERM_DATE are identical
PRINT '#PCP'
-- SELECT * FROM #PCP ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #PCP		--733231


-- CMO service spans (overlaps fixed)
IF OBJECT_ID('tempdb..#CMO') IS NOT NULL DROP TABLE #CMO

; WITH cmo_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, cmo.CactusProvK AS 'CMO_provK'
		, cmo.NPI AS 'CMO_NPI'
		, cmo.PROVIDER_ID AS 'CMO_NAME_ID'
		, cmo.prov_name AS 'CMO_name'
		, cmo.EFF_DATE AS 'CMO_EFF_DATE'
		, cmo.TERM_DATE AS 'CMO_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS cmo
		ON cer3.CCAID = cmo.CCAID
		AND cer3.member_month BETWEEN cmo.EFF_DATE AND cmo.TERM_DATE
		AND cmo.SERVICE_TYPE IN ('Care Manager Org')
)
SELECT
	cmo1.NAME_ID
	, cmo1.member_month
	, cmo1.CMO_provK
	, cmo1.CMO_NPI
	, cmo1.CMO_NAME_ID
	, cmo1.CMO_name
	, cmo1.CMO_EFF_DATE
	, cmo1.CMO_TERM_DATE
INTO #CMO
FROM cmo_spans AS cmo1
INNER JOIN cmo_spans AS cmo2
	ON cmo1.NAME_ID = cmo2.NAME_ID
	AND cmo1.member_month = cmo2.member_month
GROUP BY
	cmo1.NAME_ID
	, cmo1.member_month
	, cmo1.CMO_provK
	, cmo1.CMO_NPI
	, cmo1.CMO_NAME_ID
	, cmo1.CMO_name
	, cmo1.CMO_EFF_DATE
	, cmo1.CMO_TERM_DATE
HAVING MAX(cmo2.CMO_EFF_DATE) = cmo1.CMO_EFF_DATE
PRINT '#CMO'
-- SELECT * FROM #CMO ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #CMO		--1003163


-- CM service spans (overlaps fixed)
-- combines 'Care Manager', 'ICO Care Manager', and 'ICO Supp. Care Mgr' into one field
IF OBJECT_ID('tempdb..#CM') IS NOT NULL DROP TABLE #CM

; WITH cm_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, cm.CactusProvK AS 'CM_provK'
		, cm.NPI AS 'CM_NPI'
		, cm.PROVIDER_ID AS 'CM_NAME_ID'
		, cm.prov_name AS 'CM_name'
		, cm.EFF_DATE AS 'CM_EFF_DATE'
		, cm.TERM_DATE AS 'CM_TERM_DATE'
	-- SELECT COUNT(*)
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS cm
		ON cer3.CCAID = cm.CCAID
		AND cer3.member_month BETWEEN cm.EFF_DATE AND cm.TERM_DATE
		AND cm.SERVICE_TYPE IN ('Care Manager', 'ICO Care Manager', 'ICO Supp. Care Mgr')
)
SELECT
	cm1.NAME_ID
	, cm1.member_month
	, cm1.CM_provK
	, cm1.CM_NPI
	, cm1.CM_NAME_ID
	, cm1.CM_name
	, cm1.CM_EFF_DATE
	, cm1.CM_TERM_DATE
INTO #CM
FROM cm_spans AS cm1
INNER JOIN cm_spans AS cm2
	ON cm1.NAME_ID = cm2.NAME_ID
	AND cm1.member_month = cm2.member_month
GROUP BY
	cm1.NAME_ID
	, cm1.member_month
	, cm1.CM_provK
	, cm1.CM_NPI
	, cm1.CM_NAME_ID
	, cm1.CM_name
	, cm1.CM_EFF_DATE
	, cm1.CM_TERM_DATE
HAVING MAX(cm2.CM_EFF_DATE) = cm1.CM_EFF_DATE
	AND MAX(cm2.CM_TERM_DATE) = cm1.CM_TERM_DATE
	AND MAX(COALESCE(cm2.CM_NPI, '')) = COALESCE(cm1.CM_NPI, '')	-- gives preference to providers with NPI if EFF_DATE and TERM_DATE are identical
PRINT '#CM'
-- SELECT * FROM #CM ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #CM		--1147714
-- SELECT COUNT(*) FROM #CM		--1145608	-- adding term date limit
-- SELECT COUNT(*) FROM #CM		--1145490	-- adding NPI limit
-- problem records?
-- SELECT NAME_ID, member_month, COUNT(*) FROM #CM GROUP BY NAME_ID, member_month HAVING COUNT(*) > 1 ORDER BY NAME_ID, member_month
-- SELECT * FROM #CM WHERE NAME_ID = 'N00000118929' ORDER BY NAME_ID, member_month, CM_name
-- SELECT * FROM #CM WHERE NAME_ID = 'N00005535031' ORDER BY NAME_ID, member_month, CM_name


-- ASAP service spans (overlaps fixed)
IF OBJECT_ID('tempdb..#ASAP') IS NOT NULL DROP TABLE #ASAP

; WITH asap_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, asap.CactusProvK AS 'ASAP_provK'
		, asap.NPI AS 'ASAP_NPI'
		, asap.PROVIDER_ID AS 'ASAP_NAME_ID'
		, asap.prov_name AS 'ASAP_name'
		, asap.EFF_DATE AS 'ASAP_EFF_DATE'
		, asap.TERM_DATE AS 'ASAP_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS asap
		ON cer3.CCAID = asap.CCAID
		AND cer3.member_month BETWEEN asap.EFF_DATE AND asap.TERM_DATE
		AND asap.SERVICE_TYPE IN ('ASAP')
)
SELECT
	asap1.NAME_ID
	, asap1.member_month
	, asap1.ASAP_provK
	, asap1.ASAP_NPI
	, asap1.ASAP_NAME_ID
	, asap1.ASAP_name
	, asap1.ASAP_EFF_DATE
	, asap1.ASAP_TERM_DATE
INTO #ASAP
FROM asap_spans AS asap1
INNER JOIN asap_spans AS asap2
	ON asap1.NAME_ID = asap2.NAME_ID
	AND asap1.member_month = asap2.member_month
GROUP BY
	asap1.NAME_ID
	, asap1.member_month
	, asap1.ASAP_provK
	, asap1.ASAP_NPI
	, asap1.ASAP_NAME_ID
	, asap1.ASAP_name
	, asap1.ASAP_EFF_DATE
	, asap1.ASAP_TERM_DATE
HAVING MAX(asap2.ASAP_EFF_DATE) = asap1.ASAP_EFF_DATE
PRINT '#ASAP'
-- SELECT * FROM #ASAP ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #ASAP		--154713


-- Behav Health Home service spans (overlaps fixed)
IF OBJECT_ID('tempdb..#BHH') IS NOT NULL DROP TABLE #BHH

; WITH bhh_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, bhh.CactusProvK AS 'BHH_provK'
		, bhh.NPI AS 'BHH_NPI'
		, bhh.PROVIDER_ID AS 'BHH_NAME_ID'
		, bhh.prov_name AS 'BHH_name'
		, bhh.EFF_DATE AS 'BHH_EFF_DATE'
		, bhh.TERM_DATE AS 'BHH_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS bhh
		ON cer3.CCAID = bhh.CCAID
		AND cer3.member_month BETWEEN bhh.EFF_DATE AND bhh.TERM_DATE
		AND bhh.SERVICE_TYPE IN ('Behav Health Home')
)
SELECT
	bhh1.NAME_ID
	, bhh1.member_month
	, bhh1.BHH_provK
	, bhh1.BHH_NPI
	, bhh1.BHH_NAME_ID
	, bhh1.BHH_name
	, bhh1.BHH_EFF_DATE
	, bhh1.BHH_TERM_DATE
INTO #BHH
FROM bhh_spans AS bhh1
INNER JOIN bhh_spans AS bhh2
	ON bhh1.NAME_ID = bhh2.NAME_ID
	AND bhh1.member_month = bhh2.member_month
GROUP BY
	bhh1.NAME_ID
	, bhh1.member_month
	, bhh1.BHH_provK
	, bhh1.BHH_NPI
	, bhh1.BHH_NAME_ID
	, bhh1.BHH_name
	, bhh1.BHH_EFF_DATE
	, bhh1.BHH_TERM_DATE
HAVING MAX(bhh2.BHH_EFF_DATE) = bhh1.BHH_EFF_DATE
PRINT '#BHH'
-- SELECT * FROM #BHH ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #BHH		--15604


-- Care Model service spans (overlaps fixed)
IF OBJECT_ID('tempdb..#CAREMODEL') IS NOT NULL DROP TABLE #CAREMODEL

; WITH caremodel_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, caremodel.CactusProvK AS 'CAREMODEL_provK'
		, caremodel.NPI AS 'CAREMODEL_NPI'
		, caremodel.PROVIDER_ID AS 'CAREMODEL_NAME_ID'
		, caremodel.prov_name AS 'CAREMODEL_name'
		, caremodel.EFF_DATE AS 'CAREMODEL_EFF_DATE'
		, caremodel.TERM_DATE AS 'CAREMODEL_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS caremodel
		ON cer3.CCAID = caremodel.CCAID
		AND cer3.member_month BETWEEN caremodel.EFF_DATE AND caremodel.TERM_DATE
		AND caremodel.SERVICE_TYPE IN ('Care Model')
)
SELECT
	caremodel1.NAME_ID
	, caremodel1.member_month
	, caremodel1.CAREMODEL_provK
	, caremodel1.CAREMODEL_NPI
	, caremodel1.CAREMODEL_NAME_ID
	, caremodel1.CAREMODEL_name
	, caremodel1.CAREMODEL_EFF_DATE
	, caremodel1.CAREMODEL_TERM_DATE
INTO #CAREMODEL
FROM caremodel_spans AS caremodel1
INNER JOIN caremodel_spans AS caremodel2
	ON caremodel1.NAME_ID = caremodel2.NAME_ID
	AND caremodel1.member_month = caremodel2.member_month
GROUP BY
	caremodel1.NAME_ID
	, caremodel1.member_month
	, caremodel1.CAREMODEL_provK
	, caremodel1.CAREMODEL_NPI
	, caremodel1.CAREMODEL_NAME_ID
	, caremodel1.CAREMODEL_name
	, caremodel1.CAREMODEL_EFF_DATE
	, caremodel1.CAREMODEL_TERM_DATE
HAVING MAX(caremodel2.CAREMODEL_EFF_DATE) = caremodel1.CAREMODEL_EFF_DATE
PRINT '#CAREMODEL'
-- SELECT * FROM #CAREMODEL ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #CAREMODEL		--203302


-- Contracting Entity service spans (overlaps fixed)
IF OBJECT_ID('tempdb..#CE') IS NOT NULL DROP TABLE #CE

; WITH ce_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, ce.CactusProvK AS 'CE_provK'
		, ce.NPI AS 'CE_NPI'
		, ce.PROVIDER_ID AS 'CE_NAME_ID'
		, ce.prov_name AS 'CE_name'
		, ce.EFF_DATE AS 'CE_EFF_DATE'
		, ce.TERM_DATE AS 'CE_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS ce
		ON cer3.CCAID = ce.CCAID
		AND cer3.member_month BETWEEN ce.EFF_DATE AND ce.TERM_DATE
		AND ce.SERVICE_TYPE IN ('Contracting Entity')
)
SELECT
	ce1.NAME_ID
	, ce1.member_month
	, ce1.CE_provK
	, ce1.CE_NPI
	, ce1.CE_NAME_ID
	, ce1.CE_name
	, ce1.CE_EFF_DATE
	, ce1.CE_TERM_DATE
INTO #CE
FROM ce_spans AS ce1
INNER JOIN ce_spans AS ce2
	ON ce1.NAME_ID = ce2.NAME_ID
	AND ce1.member_month = ce2.member_month
GROUP BY
	ce1.NAME_ID
	, ce1.member_month
	, ce1.CE_provK
	, ce1.CE_NPI
	, ce1.CE_NAME_ID
	, ce1.CE_name
	, ce1.CE_EFF_DATE
	, ce1.CE_TERM_DATE
HAVING MAX(ce2.CE_EFF_DATE) = ce1.CE_EFF_DATE
PRINT '#CE'
-- SELECT * FROM #CE ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #CE		--352604


-- GSSC service spans (overlaps fixed)
IF OBJECT_ID('tempdb..#GSSC') IS NOT NULL DROP TABLE #GSSC

; WITH gssc_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, gssc.CactusProvK AS 'GSSC_provK'
		, gssc.NPI AS 'GSSC_NPI'
		, gssc.PROVIDER_ID AS 'GSSC_NAME_ID'
		, gssc.prov_name AS 'GSSC_name'
		, gssc.EFF_DATE AS 'GSSC_EFF_DATE'
		, gssc.TERM_DATE AS 'GSSC_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS gssc
		ON cer3.CCAID = gssc.CCAID
		AND cer3.member_month BETWEEN gssc.EFF_DATE AND gssc.TERM_DATE
		AND gssc.SERVICE_TYPE IN ('GSSC')
)
SELECT
	gssc1.NAME_ID
	, gssc1.member_month
	, gssc1.GSSC_provK
	, gssc1.GSSC_NPI
	, gssc1.GSSC_NAME_ID
	, gssc1.GSSC_name
	, gssc1.GSSC_EFF_DATE
	, gssc1.GSSC_TERM_DATE
INTO #GSSC
FROM gssc_spans AS gssc1
INNER JOIN gssc_spans AS gssc2
	ON gssc1.NAME_ID = gssc2.NAME_ID
	AND gssc1.member_month = gssc2.member_month
GROUP BY
	gssc1.NAME_ID
	, gssc1.member_month
	, gssc1.GSSC_provK
	, gssc1.GSSC_NPI
	, gssc1.GSSC_NAME_ID
	, gssc1.GSSC_name
	, gssc1.GSSC_EFF_DATE
	, gssc1.GSSC_TERM_DATE
HAVING MAX(gssc2.GSSC_EFF_DATE) = gssc1.GSSC_EFF_DATE
PRINT '#GSSC'
-- SELECT * FROM #GSSC ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #GSSC		--213453


-- HOW service spans (overlaps fixed)
IF OBJECT_ID('tempdb..#HOW') IS NOT NULL DROP TABLE #HOW

; WITH how_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, how.CactusProvK AS 'HOW_provK'
		, how.NPI AS 'HOW_NPI'
		, how.PROVIDER_ID AS 'HOW_NAME_ID'
		, how.prov_name AS 'HOW_name'
		, how.EFF_DATE AS 'HOW_EFF_DATE'
		, how.TERM_DATE AS 'HOW_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS how
		ON cer3.CCAID = how.CCAID
		AND cer3.member_month BETWEEN how.EFF_DATE AND how.TERM_DATE
		AND how.SERVICE_TYPE IN ('Health Outreach Worker')
)
SELECT
	how1.NAME_ID
	, how1.member_month
	, how1.HOW_provK
	, how1.HOW_NPI
	, how1.HOW_NAME_ID
	, how1.HOW_name
	, how1.HOW_EFF_DATE
	, how1.HOW_TERM_DATE
INTO #HOW
FROM how_spans AS how1
INNER JOIN how_spans AS how2
	ON how1.NAME_ID = how2.NAME_ID
	AND how1.member_month = how2.member_month
GROUP BY
	how1.NAME_ID
	, how1.member_month
	, how1.HOW_provK
	, how1.HOW_NPI
	, how1.HOW_NAME_ID
	, how1.HOW_name
	, how1.HOW_EFF_DATE
	, how1.HOW_TERM_DATE
HAVING MAX(how2.HOW_EFF_DATE) = how1.HOW_EFF_DATE
PRINT '#HOW'
-- SELECT * FROM #HOW ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #HOW		--13443


-- LTSC service spans (overlaps fixed)
IF OBJECT_ID('tempdb..#LTSC') IS NOT NULL DROP TABLE #LTSC

; WITH ltsc_spans AS (
	SELECT DISTINCT
		cer3.NAME_ID
		, cer3.member_month
		, ltsc.CactusProvK AS 'LTSC_provK'
		, ltsc.NPI AS 'LTSC_NPI'
		, ltsc.PROVIDER_ID AS 'LTSC_NAME_ID'
		, ltsc.prov_name AS 'LTSC_name'
		, ltsc.EFF_DATE AS 'LTSC_EFF_DATE'
		, ltsc.TERM_DATE AS 'LTSC_TERM_DATE'
	-- SELECT TOP 1000 *
	FROM #combined_enroll_rc_3 AS cer3
	INNER JOIN #services AS ltsc
		ON cer3.CCAID = ltsc.CCAID
		AND cer3.member_month BETWEEN ltsc.EFF_DATE AND ltsc.TERM_DATE
		AND ltsc.SERVICE_TYPE IN ('LTSC Agency')
)
SELECT
	ltsc1.NAME_ID
	, ltsc1.member_month
	, ltsc1.LTSC_provK
	, ltsc1.LTSC_NPI
	, ltsc1.LTSC_NAME_ID
	, ltsc1.LTSC_name
	, ltsc1.LTSC_EFF_DATE
	, ltsc1.LTSC_TERM_DATE
INTO #LTSC
FROM ltsc_spans AS ltsc1
INNER JOIN ltsc_spans AS ltsc2
	ON ltsc1.NAME_ID = ltsc2.NAME_ID
	AND ltsc1.member_month = ltsc2.member_month
GROUP BY
	ltsc1.NAME_ID
	, ltsc1.member_month
	, ltsc1.LTSC_provK
	, ltsc1.LTSC_NPI
	, ltsc1.LTSC_NAME_ID
	, ltsc1.LTSC_name
	, ltsc1.LTSC_EFF_DATE
	, ltsc1.LTSC_TERM_DATE
HAVING MAX(ltsc2.LTSC_EFF_DATE) = ltsc1.LTSC_EFF_DATE
PRINT '#LTSC'
-- SELECT * FROM #LTSC ORDER BY NAME_ID, member_month
-- SELECT COUNT(*) FROM #LTSC		--304976


-- SELECT * FROM #PCL ORDER BY NAME_ID, member_month
-- SELECT * FROM #PCP ORDER BY NAME_ID, member_month
-- SELECT * FROM #CMO ORDER BY NAME_ID, member_month
-- SELECT * FROM #CM ORDER BY NAME_ID, member_month
-- SELECT * FROM #ASAP ORDER BY NAME_ID, member_month
-- SELECT * FROM #BHH ORDER BY NAME_ID, member_month
-- SELECT * FROM #CAREMODEL ORDER BY NAME_ID, member_month
-- SELECT * FROM #CE ORDER BY NAME_ID, member_month
-- SELECT * FROM #GSSC ORDER BY NAME_ID, member_month
-- SELECT * FROM #HOW ORDER BY NAME_ID, member_month
-- SELECT * FROM #LTSC ORDER BY NAME_ID, member_month


---- care partner history from Guiding Care
--IF OBJECT_ID('tempdb..#GCprimCM') IS NOT NULL DROP TABLE #GCPrimCM

--; WITH CM_roles AS (
--	/*	-- table builder: available roles
--		SELECT DISTINCT
--			r.ROLE_NAME
--			, ', ' + CHAR(39) + r.ROLE_NAME + CHAR(39) AS 'for_SQL_IN_list'
--			, ', (' + CHAR(39) + r.ROLE_NAME + CHAR(39) + ')' AS 'for_SQL_VALUE_list'
--		FROM Altruista.dbo.PATIENT_DETAILS AS pd
--		INNER JOIN Altruista.dbo.PATIENT_PHYSICIAN AS pp
--			ON pd.PATIENT_ID = pp.PATIENT_ID
--			AND pp.CARE_TEAM_ID = 1
--		INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS cs
--			ON pp.PHYSICIAN_ID = cs.MEMBER_ID
--		INNER JOIN Altruista.dbo.[ROLE] AS r
--			ON cs.ROLE_ID = r.ROLE_ID
--			--AND r.IS_ACTIVE = 1
--			--AND r.DELETED_ON IS NULL
--		WHERE LEFT(pd.CLIENT_PATIENT_ID, 3) = '536'
--		ORDER BY
--			r.ROLE_NAME
--	*/
--	SELECT * FROM (
--		VALUES 
--		  ('Care Coordinator')
--		, ('Clinical Support Coordinator')
--		, ('CM Manager')
--		, ('CM Manager and Clinical Reviewer')
--		, ('Delegated Care Coordinator')
--		, ('External Care Coordinator')
--		--, ('Intake Coordinator')
--		--, ('Member Services')
--		--, ('Read Only')
--		, ('UM Manager')
--		, ('UM Manager and Clinical Reviewer')
--		, ('UM Nurse')
--		, ('UM Physician')
--		, ('UM Physician and Clinical Reviewer')
--		--, ('UM Review Specialist')
--	) AS x (CM_roles)
--), PrimCareStaff AS (
--	SELECT
--		pd.CLIENT_PATIENT_ID AS 'CCAID'
--		, pd.PATIENT_ID
--		, pp.PHYSICIAN_ID AS 'PhysID'
--		, r.ROLE_NAME AS 'PhysRole'
--		, cs.TITLE
--		, cs.FIRST_NAME
--		, cs.LAST_NAME
--	FROM Altruista.dbo.PATIENT_DETAILS AS pd
--	INNER JOIN Altruista.dbo.PATIENT_PHYSICIAN AS pp
--		ON pd.PATIENT_ID = pp.PATIENT_ID
--		AND pp.CARE_TEAM_ID = 1
--		--AND pp.IS_ACTIVE = 1
--		AND pp.DELETED_ON IS NULL
--	INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS cs
--		ON pp.PHYSICIAN_ID = cs.MEMBER_ID
--	INNER JOIN Altruista.dbo.[ROLE] AS r
--		ON cs.ROLE_ID = r.ROLE_ID
--		--AND r.IS_ACTIVE = 1
--		AND r.DELETED_ON IS NULL
--	WHERE LEFT(pd.CLIENT_PATIENT_ID, 3) = '536'
--		AND pd.DELETED_ON IS NULL
--		AND r.ROLE_NAME IN (SELECT * FROM CM_roles)
--		--	'Care Coordinator', 'CM Manager', 'Delegated Care Coordinator', 'UM Manager', 'UM Nurse'
--		--	, 'Clinical Support Coordinator', 'CM Manager and Clinical Reviewer', 'External Care Coordinator', 'UM Manager and Clinical Reviewer', 'UM Physician'
--		--	--, 'Intake Coordinator', 'Member Services', 'Read Only', 'UM Review Specialist'
--		--)
--), PrimCM AS (
--	SELECT
--		pd.CLIENT_PATIENT_ID AS 'CCAID'
--		, pd.PATIENT_ID
--		, mc.MEMBER_ID
--		, mc.CREATED_ON AS 'PrimCPassignedDate'
--		, CASE WHEN cs.LAST_NAME IS NULL AND cs.MIDDLE_NAME IS NOT NULL THEN cs.MIDDLE_NAME + ', ' + cs.FIRST_NAME
--			ELSE cs.LAST_NAME + ', ' + cs.FIRST_NAME END AS 'PrimCareMgr'
--		, cs.LAST_NAME
--		, cs.FIRST_NAME
--		, cs.MIDDLE_NAME
--		, r.ROLE_NAME AS 'PrimCareMgrRole'
--		, mc.CREATED_ON
--	FROM Altruista.dbo.PATIENT_DETAILS AS pd
--	INNER JOIN Altruista.dbo.MEMBER_CARESTAFF AS mc
--		ON pd.PATIENT_ID = mc.PATIENT_ID
--	INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS cs
--		ON mc.MEMBER_ID = cs.MEMBER_ID
--	INNER JOIN Altruista.dbo.[ROLE] AS r
--		ON cs.ROLE_ID = r.ROLE_ID
--		AND r.IS_ACTIVE = 1
--		AND r.DELETED_ON IS NULL
--	WHERE LEFT(pd.CLIENT_PATIENT_ID, 3) = '536'
--		--AND mc.IS_ACTIVE = 1
--		--AND mc.IS_PRIMARY = 1
--		AND r.ROLE_NAME IN (SELECT * FROM CM_roles)
--		--	'Care Coordinator', 'CM Manager', 'Delegated Care Coordinator', 'UM Manager', 'UM Nurse'
--		--	, 'Clinical Support Coordinator', 'CM Manager and Clinical Reviewer', 'External Care Coordinator', 'UM Manager and Clinical Reviewer', 'UM Physician'
--		--	--, 'Intake Coordinator', 'Member Services', 'Read Only', 'UM Review Specialist'
--		--)
--), GCprimCM_distinct AS (
--	SELECT DISTINCT
--		pc.CCAID
--		, pc.PATIENT_ID
--		, pc.MEMBER_ID AS 'PrimCareMgrID'
--		, pc.PrimCareMgr
--		, pc.PrimCareMgrRole
--		, pcs.PhysID
--		, pcs.PhysRole
--		, pcs.FIRST_NAME
--		, pcs.LAST_NAME
--		, pc.PrimCPassignedDate
--		, CASE WHEN pc.MEMBER_ID = pcs.PhysID THEN 'Y' ELSE 'N' END AS 'CMtoPhysMatch'
--	FROM PrimCM AS pc
--	LEFT JOIN PrimCareStaff AS pcs
--		ON pc.CCAID = pcs.CCAID
--		AND pc.MEMBER_ID = pcs.PhysID
--), GCprimCM AS (
--	SELECT
--		*
--		, DENSE_RANK() OVER (PARTITION BY CCAID ORDER BY CASE WHEN PrimCareMgrID = PhysID THEN 'Y' ELSE 'N' END DESC) AS 'PCMrank'
--		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY CASE WHEN PrimCareMgrID = PhysID THEN 'Y' ELSE 'N' END DESC, PrimCPassignedDate) AS 'RowNo'			-- 1 = first
--		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY CASE WHEN PrimCareMgrID = PhysID THEN 'Y' ELSE 'N' END DESC, PrimCPassignedDate DESC) AS 'RowNo_desc'	-- 1 = latest
--	FROM GCprimCM_distinct
--)
--SELECT
--	*
--INTO #GCprimCM
--FROM GCPrimCM
--WHERE PCMrank = 1
--	--AND RowNo = 1
--PRINT '#GCprimCM'
--CREATE UNIQUE INDEX CCAID_CMrow ON #GCprimCM (CCAID, RowNo)
---- SELECT * FROM #GCprimCM ORDER BY CCAID, RowNo
---- SELECT COUNT(*) FROM #GCprimCM		--68009
---- SELECT CCAID, COUNT(*) FROM #GCprimCM GROUP BY CCAID HAVING COUNT(*) > 1


---- care manager member months
--IF OBJECT_ID('tempdb..#cm_mm') IS NOT NULL DROP TABLE #cm_mm

--; WITH member_cm_starts AS (
--	SELECT DISTINCT
--		CCAID
--		, PrimCareMgrID AS 'CM_ID'
--		, FIRST_NAME + ' ' + LAST_NAME AS 'CM'
--		, PrimCareMgrRole AS 'CM_role'
--		, CAST(PrimCPassignedDate AS DATE) AS 'CM_begin'
--		, PrimCPassignedDate AS 'CM_begin_day_time'
--	FROM #GCprimCM
--), member_cm_starts_max_day AS (
--	SELECT
--		mcms1.CCAID
--		, mcms1.CM_ID
--		, mcms1.CM
--		, mcms1.CM_role
--		, mcms1.CM_begin
--		, mcms1.CM_begin_day_time
--	FROM member_cm_starts AS mcms1
--	INNER JOIN member_cm_starts AS mcms2
--		ON mcms1.CCAID = mcms2.CCAID
--		AND mcms1.CM_begin = mcms2.CM_begin
--	GROUP BY
--		mcms1.CCAID
--		, mcms1.CM_ID
--		, mcms1.CM
--		, mcms1.CM_role
--		, mcms1.CM_begin
--		, mcms1.CM_begin_day_time
--	HAVING MAX(mcms2.CM_begin_day_time) = mcms1.CM_begin_day_time
--), member_cm_rows AS (
--	SELECT
--		CCAID
--		, CM_ID
--		, CM
--		, CM_role
--		, CM_begin
--		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY CM_begin) AS 'CM_row'
--	FROM member_cm_starts_max_day
--), member_cm_ends AS (
--	SELECT
--		mcmr1.*
--		, COALESCE(DATEADD(DD, -1, mcmr2.CM_begin), '9999-12-30') AS 'CM_end'
--	FROM member_cm_rows AS mcmr1
--	LEFT JOIN member_cm_rows AS mcmr2
--		ON mcmr1.CCAID = mcmr2.CCAID
--		AND mcmr1.CM_row = mcmr2.CM_row - 1
--)
--SELECT
--	mcme.CCAID
--	, mcme.CM_ID
--	, mcme.CM
--	, mcme.CM_role
--	, MIN(mcme.CM_begin) AS 'CM_begin'
--	, MAX(mcme.CM_end) AS 'CM_end'
--	--, MAX(mcme.CM_row) AS 'CM_row'
--	, CAST(d.member_month AS DATE) AS 'member_month'
--INTO #cm_mm
--FROM member_cm_ends AS mcme
--INNER JOIN CCAMIS_Common.dbo.Dim_date AS d
--	ON d.member_month BETWEEN mcme.CM_begin AND COALESCE(mcme.CM_end, DATEADD(MM, 4, GETDATE()))
--GROUP BY
--	mcme.CCAID
--	, mcme.CM_ID
--	, mcme.CM
--	, mcme.CM_role
--	, d.member_month
--ORDER BY
--	CCAID
--	, CM_begin
--	, member_month
--PRINT '#cm_mm'
---- SELECT * FROM #cm_mm ORDER BY CCAID, member_month
---- SELECT COUNT(*) FROM #cm_mm		--944271
---- SELECT CCAID, member_month FROM #cm_mm GROUP BY CCAID, member_month HAVING COUNT(*) > 1 ORDER BY CCAID, member_month


-- distinct members, months, RC, and MP services
IF OBJECT_ID('tempdb..#combined_MP_services') IS NOT NULL DROP TABLE #combined_MP_services

SELECT DISTINCT
	cer3.*

	, #PCL.PCL_provK
	, #PCL.PCL_NPI
	, #PCL.PCL_NAME_ID
	, #PCL.PCL_name
	, CASE WHEN #PCL.PCL_name IN (
			'Brockton Neighborhood HC'
			, 'CommHlthConn'
			, 'Community Hth Ctr Frln Cty Grn'
			, 'Comm H.C. of Franklin C'
			, 'Dimock Com Hlth Cntr'
			, 'East Boston Neighborhoo'
			, 'Family HC Worcester'
			, 'Fenway Comm HC'
			, 'Holyoke Hlth Center'
			, 'Lynn Comm HC'
			, 'Lynn Comm-Market Sq'
			, 'Lynn Comm-Western Ave'
			, 'North Shore Comm Hlth'
			, 'Uphams Corner Hlth Cent'
			, 'Huntington HC'
			, 'Worthington HC'
			, 'North End Waterfont Health'
			, 'South End Community HC'
		) THEN 1
		ELSE 0 END AS 'C3_FQHC'
	-- see: \\cca-fs1\groups\CrossFunctional\BI\Medical Analytics\Adhoc Requests\Shah Mihir\BID-394 CCC member map\
	-- source: https://www.communitycarecooperative.org/masshealth-find-a-provider

	, #PCP.PCP_provK
	, #PCP.PCP_NPI
	, #PCP.PCP_NAME_ID
	, #PCP.PCP_name

	, #CMO.CMO_provK
	, #CMO.CMO_NPI
	, #CMO.CMO_NAME_ID
	, #CMO.CMO_name
	, cmer.CareManagementEntityGroup AS 'CMO_group'
	, CASE WHEN cer3.Product = 'ICO'		-- revised 2017-12-22
		THEN CASE WHEN #CMO.CMO_name IN (
				'CCA-BHI'
				, 'CCACG EAST'
				, 'CCACG WEST'
				, 'CCACG-Central'
				, 'CCC-Boston'
				, 'CCC-Framingham'
				, 'CCC-Lawrence'
				, 'CCC-Springfield'
				, 'SCMO'
			) THEN 'CCA'
			WHEN #CMO.CMO_name IN (
				'Advocates, Inc'
				, 'Bay Cove Hmn Srvces'
				, 'Behavioral Hlth Ntwrk'
				, 'BosHC 4 Homeless'
				, 'CommH Link Worc'
				, 'Lynn Comm HC'
				, 'Vinfen'
			) THEN 'Health Home'
			END
		WHEN cer3.Product = 'SCO'
		THEN CASE WHEN #CMO.CMO_name IN (
				'CCACG EAST'
				, 'CCACG WEST'
				, 'CCACG-Central'
				, 'CCC-Boston'
				, 'CCC-Framingham'
				, 'CCC-Lawrence'
				, 'CCC-Springfield'
				, 'SCMO'
			) THEN 'CCA'
			WHEN #CMO.CMO_name IN (
				'BIDJP Subacute'
				, 'BU Geriatric Service'
				, 'East Boston Neighborhoo'
				, 'Element Care'
				, 'Uphams Corner Hlth Cent'
			) THEN 'Delegated Site'
			END
		END AS 'CMO_group2'

	, #CM.CM_provK	 AS 'MP_CM_provK'
	, #CM.CM_NPI	 AS 'MP_CM_NPI'
	, #CM.CM_NAME_ID AS 'MP_CM_NAME_ID'
	, #CM.CM_name	 AS 'MP_CM_name'
	, CAST(#CM.CM_EFF_DATE AS DATE) AS 'MP_CM_begin'
	, CAST(#CM.CM_TERM_DATE AS DATE) AS 'MP_CM_end'

	, gccm.CM AS 'GC_care_manager'
	, gccm.CM_ID AS 'GC_CM_ID'
	, gccm.CM_role AS 'GC_CM_role'
	, gccm.CM_begin AS 'GC_CM_begin'
	, gccm.CM_end AS 'GC_CM_end'

	, COALESCE(gccm.CM, #CM.CM_name) AS 'CM_combined'
	, COALESCE(CASE WHEN COALESCE(gccm.CM_begin, '2019-01-01') <= '2018-11-12' AND #CM.CM_EFF_DATE IS NOT NULL THEN CAST(#CM.CM_EFF_DATE AS DATE) ELSE gccm.CM_begin END, CAST(#CM.CM_EFF_DATE AS DATE)) AS 'CM_begin'
	, COALESCE(gccm.CM_end, CAST(#CM.CM_TERM_DATE AS DATE)) AS 'CM_end'

	, #ASAP.ASAP_provK
	, #ASAP.ASAP_NPI	-- very few
	, #ASAP.ASAP_NAME_ID
	, #ASAP.ASAP_name

	, #BHH.BHH_provK
	, #BHH.BHH_NPI	-- very few
	, #BHH.BHH_NAME_ID
	, #BHH.BHH_name

	, #CAREMODEL.CAREMODEL_provK
	, #CAREMODEL.CAREMODEL_NPI	-- very few
	, #CAREMODEL.CAREMODEL_NAME_ID
	, #CAREMODEL.CAREMODEL_name

	, #CE.CE_provK
	, #CE.CE_NPI	-- very few
	, #CE.CE_NAME_ID
	, #CE.CE_name

	, #GSSC.GSSC_provK
	, #GSSC.GSSC_NPI
	, #GSSC.GSSC_NAME_ID
	, #GSSC.GSSC_name

	, #HOW.HOW_provK
	, #HOW.HOW_NPI
	, #HOW.HOW_NAME_ID
	, #HOW.HOW_name

	, #LTSC.LTSC_provK
	, #LTSC.LTSC_NPI	-- very few
	, #LTSC.LTSC_NAME_ID
	, #LTSC.LTSC_name

INTO #combined_MP_services
FROM #combined_enroll_rc_3 AS cer3
-- SELECT * FROM #PCL ORDER BY NAME_ID, member_month
LEFT JOIN #PCL
	ON cer3.NAME_ID = #PCL.NAME_ID
	AND cer3.member_month = #PCL.member_month
-- SELECT * FROM #PCP ORDER BY NAME_ID, member_month
LEFT JOIN #PCP
	ON cer3.NAME_ID = #PCP.NAME_ID
	AND cer3.member_month = #PCP.member_month
-- SELECT * FROM #CMO ORDER BY NAME_ID, member_month
LEFT JOIN #CMO
	ON cer3.NAME_ID = #CMO.NAME_ID
	AND cer3.member_month = #CMO.member_month
-- SELECT * FROM #CM ORDER BY NAME_ID, member_month
LEFT JOIN #CM
	ON cer3.NAME_ID = #CM.NAME_ID
	AND cer3.member_month = #CM.member_month
-- SELECT * FROM #ASAP ORDER BY NAME_ID, member_month
LEFT JOIN #ASAP
	ON cer3.NAME_ID = #ASAP.NAME_ID
	AND cer3.member_month = #ASAP.member_month
-- SELECT * FROM #BHH ORDER BY NAME_ID, member_month
LEFT JOIN #BHH
	ON cer3.NAME_ID = #BHH.NAME_ID
	AND cer3.member_month = #BHH.member_month
-- SELECT * FROM #CAREMODEL ORDER BY NAME_ID, member_month
LEFT JOIN #CAREMODEL
	ON cer3.NAME_ID = #CAREMODEL.NAME_ID
	AND cer3.member_month = #CAREMODEL.member_month
-- SELECT * FROM #CE ORDER BY NAME_ID, member_month
LEFT JOIN #CE
	ON cer3.NAME_ID = #CE.NAME_ID
	AND cer3.member_month = #CE.member_month
-- SELECT * FROM #GSSC ORDER BY NAME_ID, member_month
LEFT JOIN #GSSC
	ON cer3.NAME_ID = #GSSC.NAME_ID
	AND cer3.member_month = #GSSC.member_month
-- SELECT * FROM #HOW ORDER BY NAME_ID, member_month
LEFT JOIN #HOW
	ON cer3.NAME_ID = #HOW.NAME_ID
	AND cer3.member_month = #HOW.member_month
-- SELECT * FROM #LTSC ORDER BY NAME_ID, member_month
LEFT JOIN #LTSC
	ON cer3.NAME_ID = #LTSC.NAME_ID
	AND cer3.member_month = #LTSC.member_month
LEFT JOIN CCAMIS_Common.dbo.CareManagementEntity_Records AS cmer
	ON (
		#CMO.CMO_NAME_ID = cmer.MPCareMgmtID
		OR #CMO.CMO_name = cmer.CareMgmtEntityDescription
	)
--LEFT JOIN #cm_mm AS gccm
LEFT JOIN Medical_Analytics.dbo.member_GC_CM_history AS gccm
	ON cer3.CCAID = gccm.CCAID
	AND cer3.member_month = gccm.member_month
PRINT '#combined_MP_services'
-- SELECT * FROM #combined_MP_services ORDER BY CCAID, member_month
-- SELECT COUNT(*) FROM #combined_MP_services		--1931901
-- problem records?
-- SELECT CCAID, member_month, COUNT(*) AS 'row_count' FROM #combined_MP_services GROUP BY CCAID, member_month HAVING COUNT(*) > 1 ORDER BY CCAID, member_month
-- SELECT COUNT(DISTINCT CCAID) FROM #combined_MP_services	--56727
-- SELECT member_month, Product, COUNT(DISTINCT CCAID) AS 'member_count' FROM #combined_MP_services GROUP BY member_month, Product ORDER BY member_month DESC, Product
-- SELECT enroll_begin, enroll_end, COUNT(DISTINCT CCAID) AS 'member_count' FROM #combined_MP_services GROUP BY enroll_begin, enroll_end ORDER BY enroll_begin, enroll_end

-- SELECT * FROM #combined_MP_services WHERE CCAID = 5364522554 ORDER BY CCAID, member_month	-- duplicate CM spans
-- SELECT * FROM #CM WHERE NAME_ID = 'N00000118929' ORDER BY NAME_ID, member_month
-- SELECT * FROM #combined_MP_services WHERE CCAID = 5365631644 ORDER BY CCAID, member_month	-- duplicate PCP spans
-- SELECT * FROM #PCP WHERE NAME_ID = 'N00021909720' ORDER BY NAME_ID, member_month
-- SELECT PCP_name, COUNT(DISTINCT NAME_ID) FROM #PCP GROUP BY PCP_name ORDER BY COUNT(DISTINCT NAME_ID) DESC
-- SELECT * FROM #combined_MP_services WHERE CCAID = 5364524634 ORDER BY CCAID, member_month
-- SELECT * FROM #combined_MP_services WHERE CCAID = 5364524769 ORDER BY CCAID, member_month
-- SELECT * FROM #combined_MP_services WHERE CCAID = 5365669777 ORDER BY CCAID, member_month
-- SELECT * FROM #PCP WHERE NAME_ID = 'N00028561714' ORDER BY NAME_ID, member_month
-- SELECT * FROM #combined_MP_services WHERE CCAID = 5365558488 ORDER BY CCAID, member_month
-- SELECT * FROM #combined_MP_services WHERE CCAID = 5365631128 ORDER BY CCAID, member_month
-- SELECT COUNT(DISTINCT PCP_NAME_ID) FROM #combined_MP_services	--5117
-- SELECT DISTINCT GC_care_manager, member_month FROM #combined_MP_services WHERE GC_care_manager IS NOT NULL ORDER BY GC_care_manager, member_month
-- SELECT DISTINCT GC_care_manager, member_month FROM #combined_MP_services WHERE GC_care_manager IS NOT NULL ORDER BY member_month, GC_care_manager
-- SELECT * FROM #CM ORDER BY NAME_ID, member_month
-- SELECT MP_CM_name, GC_care_manager, COUNT(DISTINCT CCAID) AS 'member_count' FROM #combined_MP_services WHERE member_month >= '2018-12-01' GROUP BY MP_CM_name, GC_care_manager ORDER BY MP_CM_name, GC_care_manager
-- SELECT GC_CM_begin, COUNT(*) FROM #combined_MP_services GROUP BY GC_CM_begin ORDER BY GC_CM_begin
-- SELECT CM_begin, COUNT(*) FROM #combined_MP_services WHERE member_month >= '2019-10-01' GROUP BY CM_begin ORDER BY CM_begin
-- SELECT CM_begin, COUNT(*) FROM #combined_MP_services GROUP BY CM_begin ORDER BY CM_begin


-- final roster
IF OBJECT_ID('tempdb..#roster') IS NOT NULL DROP TABLE #roster

; WITH future_enroll_adjust AS (		-- this turns the "latest" member_month count (below) into a negative number for future enrollment months
	SELECT
		CCAID
		, CASE WHEN MAX(member_month) < GETDATE() THEN 0 ELSE DATEDIFF(MM, GETDATE(), MAX(member_month)) END AS 'mm_adj'
	FROM #combined_MP_services
	GROUP BY
		CCAID
)
SELECT
	ROW_NUMBER() OVER (PARTITION BY roster.CCAID ORDER BY roster.member_month) AS 'enroll_mm'
	, ROW_NUMBER() OVER (PARTITION BY roster.CCAID ORDER BY roster.member_month DESC) - fea.mm_adj AS 'enroll_mm_latest'
	, roster.*
	, GETDATE() AS 'CREATEDATE'
	, (SELECT MAX(MP_date) AS 'MP_date' FROM #kd_ALL_enroll_ALL) AS 'MP_DATE'
INTO #roster
FROM #combined_MP_services AS roster
INNER JOIN future_enroll_adjust AS fea
	ON roster.CCAID = fea.CCAID
ORDER BY
	CCAID
	, member_month
CREATE UNIQUE INDEX memb_mm ON #roster (CCAID, member_month)
PRINT '#roster'


-- checks for non-unique CCAID and member-month combinations
DECLARE @problem_rows TABLE (
	CCAID			BIGINT
	, member_month	DATE
	, row_count		INT
)

INSERT TOP (10000000) INTO @problem_rows (CCAID, member_month, row_count)
	SELECT
		CCAID
		, member_month
		, COUNT(*) AS 'row_count'
	FROM #roster
	GROUP BY
		CCAID
		, member_month
	HAVING COUNT(*) > 1
--SELECT * FROM @problem_rows
--SELECT COUNT(*) FROM @problem_rows

DECLARE @warning_message AS VARCHAR(100)
SELECT @warning_message = CASE WHEN (SELECT COUNT(*) FROM @problem_rows) = 0 THEN 'no problems with #roster' ELSE 'there are ' + CAST((SELECT COUNT(*) FROM @problem_rows) AS VARCHAR(6)) + ' problem records in #roster' END
PRINT @warning_message


-- SELECT * FROM #roster ORDER BY CCAID, member_month
-- SELECT COUNT(*) FROM #roster		--1931901
-- problem records?
-- SELECT CCAID, member_month, COUNT(*) AS 'row_count' FROM #roster GROUP BY CCAID, member_month HAVING COUNT(*) > 1 ORDER BY CCAID, member_month
-- SELECT * FROM #roster WHERE CCAID = 5365572629 ORDER BY CCAID, member_month
-- SELECT COUNT(DISTINCT CCAID) FROM #roster	--56455
-- SELECT DISTINCT Product, Product2, Product3 FROM #roster ORDER BY Product, Product2, Product3
-- SELECT DISTINCT ReportingClass FROM #roster ORDER BY ReportingClass
-- SELECT DISTINCT Class FROM #roster ORDER BY Class
-- SELECT DISTINCT Dual FROM #roster ORDER BY Dual
-- SELECT DISTINCT Region FROM #roster ORDER BY Region


-- SELECT DISTINCT CMO_name, CMO_Group, CMO_Group2 FROM #roster ORDER BY CMO_name, CMO_Group, CMO_Group2

-- SELECT * FROM #CE ORDER BY NAME_ID, member_month
-- SELECT DISTINCT NAME_ID FROM #CE ORDER BY NAME_ID


-- duplicate entries removed with fix on 2019-12-17
-- WHERE NOT ((r.CCAID = 5365560454 AND r.RC_end = '2017-08-31') OR (r.CCAID = 5365572629 AND r.RC_end = '2019-07-31') OR (r.CCAID = 5365644550 AND r.RC_end = '2019-12-31'))


/*

-- SELECT * FROM #roster ORDER BY CCAID, member_month
-- SELECT TOP 1000 * FROM #roster ORDER BY CCAID, member_month

DROP TABLE Medical_Analytics.dbo.member_enrollment_MP_backup
SELECT * INTO Medical_Analytics.dbo.member_enrollment_MP_backup FROM Medical_Analytics.dbo.member_enrollment_MP

DROP TABLE Medical_Analytics.dbo.member_enrollment_MP

SELECT
	r.*
INTO Medical_Analytics.dbo.member_enrollment_MP
FROM #roster AS r
ORDER BY
	 r.CCAID
	 , r.member_month
CREATE UNIQUE INDEX memb_mm ON Medical_Analytics.dbo.member_enrollment_MP (CCAID, member_month)

-- SELECT * FROM Medical_Analytics.dbo.member_enrollment_MP ORDER BY CCAID, member_month
-- SELECT TOP 1000 * FROM Medical_Analytics.dbo.member_enrollment_MP ORDER BY CCAID, member_month

*/

