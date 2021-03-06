

-- 0:56 to run	--2019-07-16

/*	-- temp tables used below:

-- #month_list: list of months for the last five full calendar years plus the current fraction of this year up to the future enrollment months in MP (maximum 2)
   SELECT * FROM #month_list ORDER BY SeqNo

-- #member_product_spans: enrollment spans
-- seamless re-enrollment spans have been combined, unless the member has changed product (the ADS source shows only one continuous span even when a member changes product)
   SELECT * FROM #member_product_spans ORDER BY CCAID, Product, enr_span_start, enr_span_end

-- #id_xwalk: member ID crosswalk
   SELECT * FROM #id_xwalk ORDER BY CCAID

-- #all_members_and_months: all members and months (regardless of enrollment status)
   SELECT * FROM #all_members_and_months ORDER BY CCAID, member_month

-- #member_details: timeless member details
   SELECT * FROM #member_details ORDER BY CCAID

-- #MP_PCL: PCL from MP (ADS has PCL site, summary, and cap site)
   SELECT * FROM #MP_PCL ORDER BY CCAID, EFF_DATE, TERM_DATE

-- #member_enrollment_history: all members and all months with enrollment details
   SELECT TOP 10000 * FROM #member_enrollment_history ORDER BY CCAID, member_month

*/


/*	use this for five-year extract	*/		DECLARE @start_year_date DATETIME = (DATEADD(YY, DATEDIFF(YY, 0, (SELECT MAX(member_month) FROM Actuarial_Services.dbo.ADS_Member_Months WHERE enroll_pct = 1)) - 5, 0))
/*	use this for all history		*/		--DECLARE @start_year_date DATETIME = (SELECT MIN([START_DATE]) FROM MPSnapshotProd.dbo.DATE_SPAN WHERE COLUMN_NAME = 'name_text19' AND VALUE IN ('ICO', 'SCO') AND CARD_TYPE = 'MCAID App')
SELECT 'extract beginning:' = @start_year_date


-- #month_list: list of months for the last five full calendar years plus the current fraction of this year up to the future enrollment months in MP (maximum 2)
IF OBJECT_ID('tempdb..#month_list') IS NOT NULL DROP TABLE #month_list

; WITH max_mp AS ( -- latest enrollment date in MP
	SELECT
		MIN(ds.[START_DATE]) AS 'min_mp_date'
		--, MAX(ds.[START_DATE]) AS 'max_mp_date'
		, MAX(CASE WHEN ds.[START_DATE] > DATEADD(MM, 1, GETDATE()) THEN DATEADD(DD, -DAY(GETDATE()) + 1, DATEADD(MM, 1, GETDATE())) ELSE ds.[START_DATE] END) AS 'max_mp_date'
		, DATEDIFF(MM, MIN(ds.[START_DATE]), @start_year_date) AS 'seq_adj'
	FROM MPSnapshotProd.dbo.DATE_SPAN AS ds
	WHERE ds.COLUMN_NAME = 'name_text19'
		AND ds.VALUE IN ('ICO', 'SCO')
		AND ds.CARD_TYPE = 'MCAID App'
), max_ep AS ( -- latest enrollment date in ADS_Member_Months
	SELECT
		MIN(member_month) AS 'min_ep_date'
		, MAX(member_month) AS 'max_ep_date'
	FROM Actuarial_Services.dbo.ADS_Member_Months AS ep
	WHERE ep.enroll_pct = 1
), month_list_all AS (
	SELECT
		ROW_NUMBER() OVER(ORDER BY d.member_month) - max_mp.seq_adj AS 'SeqNo'
		, d.member_month AS 'MonthBeginDateTime'
		, DATEADD(SS, -1, DATEADD(MM, 1, d.member_month)) AS 'MonthEndDateTime'
		, CAST(d.member_month AS DATE) AS 'member_month'
		, d.CalendarYear AS 'Year'
		, RIGHT(d.CalendarQuarterofYear, 2) AS 'Quarter'
		, RIGHT(d.CalendarPeriodofYear, 2) AS 'Month'
		, DATEDIFF(MM, d.member_month, GETDATE()) AS 'RelMo'
	-- SELECT *
	FROM CCAMIS_Common.dbo.dim_date AS d
	INNER JOIN max_mp
		ON d.member_month BETWEEN max_mp.min_mp_date AND max_mp.max_mp_date
	, max_ep
	GROUP BY
		d.member_month
		, max_mp.seq_adj
		, d.CalendarYear
		, d.CalendarQuarterofYear
		, d.CalendarPeriodofYear
		, max_ep.max_ep_date
)
SELECT DISTINCT
	month_list_all.*
	, month_list_all.SeqNo + max_mp.seq_adj AS 'CCA_mo'
INTO #month_list
FROM month_list_all
, max_mp
WHERE month_list_all.SeqNo > 0
ORDER BY
	month_list_all.MonthBeginDateTime
PRINT '#month_list'
-- SELECT * FROM #month_list ORDER BY SeqNo


-- #member_product_spans: enrollment spans
-- seamless re-enrollment spans have been combined, unless the member has changed product (the ADS source shows only one continuous span even when a member changes product)
IF OBJECT_ID('tempdb..#member_product_spans') IS NOT NULL DROP TABLE #member_product_spans

; WITH multi_product_spans AS (
	SELECT
		*
		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY Product) AS 'span_num'	-- note: this only works because 1., members only move from ICO to SCO (and not the other direction), and 2., ICO comes before SCO alphabetically
	FROM (
		SELECT DISTINCT
			mm1.CCAID
			, mm1.Product
			, mm1.span_start_dt
			, mm1.span_end_dt
		FROM Actuarial_Services.dbo.ADS_Member_Months AS mm1
		INNER JOIN (
			SELECT
				CCAID
				, span_start_dt
				, span_end_dt
				, COUNT(DISTINCT Product) AS 'product_count'
			FROM Actuarial_Services.dbo.ADS_Member_Months
			GROUP BY
				CCAID
				, span_start_dt
				, span_end_dt
			HAVING COUNT(DISTINCT Product) > 1
		) AS mm2
			ON mm1.CCAID = mm2.CCAID
			AND mm1.span_start_dt = mm2.span_start_dt
			AND mm1.span_end_dt = mm2.span_end_dt
	) AS x
), product_begins_and_ends AS (
		SELECT
			mm3.CCAID
			, mm3.Product
			, MIN(mm3.member_month) AS 'mm_begin'
			, MAX(mm3.member_month) AS 'mm_end'
			, ROW_NUMBER() OVER (PARTITION BY mm3.CCAID ORDER BY MIN(mm3.member_month)) AS 'span_num'
		FROM Actuarial_Services.dbo.ADS_Member_Months AS mm3
		INNER JOIN multi_product_spans AS mps3
			ON mm3.CCAID = mps3.CCAID
			AND mm3.member_month BETWEEN mps3.span_start_dt AND mps3.span_end_dt
		GROUP BY
			mm3.CCAID
			, mm3.Product
), combined_spans AS (
	SELECT
		*
		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY enr_span_start) AS 'span_num'
	FROM (
			-- spans where a change of product has been absorbed
			SELECT
				mps.CCAID
				, mps.Product
				, CASE WHEN mps.span_num = 1 THEN mps.span_start_dt
					WHEN mps.span_num = 2 THEN pbae.mm_begin
					END AS 'enr_span_start'
				, CASE WHEN mps.span_num = 1 THEN DATEADD(DD, -1, DATEADD(MM, 1, pbae.mm_end))
					WHEN mps.span_num = 2 THEN mps.span_end_dt
					END AS 'enr_span_end'
			FROM multi_product_spans AS mps
			LEFT JOIN product_begins_and_ends AS pbae
				ON mps.CCAID = pbae.CCAID
				AND mps.span_num = pbae.span_num
		UNION ALL
			-- all other spans in ADS
			SELECT DISTINCT
				mm.CCAID
				, mm.Product
				, mm.span_start_dt
				, mm.span_end_dt
			FROM Actuarial_Services.dbo.ADS_Member_Months AS mm
			WHERE NOT EXISTS (	-- this filters the problem spans out
				SELECT
					mps1.CCAID
					, mps1.Product
					, mps1.span_start_dt
					, mps1.span_end_dt
				FROM multi_product_spans AS mps1
				WHERE mps1.CCAID = mm.CCAID
					AND mps1.Product = mm.Product
					AND mps1.span_start_dt = mm.span_start_dt
					AND mps1.span_end_dt = mm.span_end_dt
			)
		UNION ALL
			-- spans in MP which are not in ADS
			SELECT DISTINCT
				CAST(n.TEXT2 AS BIGINT) AS 'CCAID'
				, ds.VALUE AS 'Product'
				, CAST(ds.[START_DATE] AS DATE) AS 'EnrollStartDt'
				, CAST(COALESCE(ds.END_DATE, '9999-12-30') AS DATE) AS 'EnrollEndDt'
			-- SELECT TOP 100 *
			FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS a
			INNER JOIN MPSnapshotProd.dbo.NAME AS n
				ON a.[ENTITY_ID] = n.NAME_ID
				AND n.PROGRAM_ID <> 'XXX'
				AND n.TEXT2 LIKE '536_______'
			INNER JOIN MPSnapshotProd.dbo.DATE_SPAN AS ds
				ON n.NAME_ID = ds.NAME_ID
				AND ds.COLUMN_NAME = 'name_text19'
				AND ds.VALUE IN ('ICO', 'SCO')
				AND ds.CARD_TYPE = 'MCAID App'
				AND COALESCE(ds.END_DATE, '9999-12-30') > ds.[START_DATE]
			WHERE a.APP_TYPE = 'MCAID'
				AND ds.[START_DATE] BETWEEN
					(SELECT MAX(DATEADD(MM, 1, member_month)) FROM Actuarial_Services.dbo.ADS_Member_Months WHERE enroll_pct = 1)
					AND 
					(SELECT MAX([START_DATE]) FROM MPSnapshotProd.dbo.DATE_SPAN WHERE COLUMN_NAME = 'name_text19' AND VALUE IN ('ICO', 'SCO') AND CARD_TYPE = 'MCAID App')
	) AS xx
), overlap_fix AS (		-- removes spans where the start date overlaps the previous span
	SELECT
		o1.*
	FROM combined_spans AS o1
	WHERE NOT EXISTS (
		SELECT
			*
		FROM combined_spans AS o2
		WHERE o2.CCAID = o1.CCAID
			AND o2.span_num = o1.span_num - 1
			AND o2.enr_span_end > o1.enr_span_start
	)
)
SELECT
	*
INTO #member_product_spans
FROM overlap_fix
ORDER BY
	CCAID
	, Product
	, enr_span_start
	, enr_span_end
PRINT '#member_product_spans'
-- SELECT * FROM #member_product_spans ORDER BY CCAID, Product, enr_span_start, enr_span_end	--58472
-- SELECT * FROM #member_product_spans WHERE CCAID IN (5365686997, 5365768871, 5365768900) ORDER BY CCAID, Product, enr_span_start, enr_span_end	-- members with new spans in MP (which creates an overlap with ADS)


-- #id_xwalk: member ID crosswalk
IF OBJECT_ID('tempdb..#id_xwalk') IS NOT NULL DROP TABLE #id_xwalk

SELECT DISTINCT
	n.NAME_ID
	, CAST(n.TEXT2 AS BIGINT) AS 'CCAID'
	, CAST(n.TEXT2 AS BIGINT) - 5364521034 AS 'member_ID'
	, COALESCE(ads.MMIS_ID, mi.MMISID) AS 'MMISID'			-- MassHealth
	, RTRIM(hcfa.MBI) AS 'MBI'									-- CMS
	, hcfa.HIC_NUMBER											-- CMS (this became MBI as of April 1, 2018)
	, hcfa.HIC_NUMBER_ORIG										-- CMS (actual HICN)
	--, hcfa.HICN_trim											-- CMS -- this is the same as HIC_NUMBER_ORIG but with non-printing characters removed from the right
	--, hcfa.HICN_9												-- CMS -- the first nine characters of HIC_NUMBER_ORIG
	--, hcfa.HICN_type											-- CMS -- the last one or two characters of HIC_NUMBER_ORIG
	, n.SOC_SEC
INTO #id_xwalk
FROM MPSnapshotProd.dbo.NAME AS n
LEFT JOIN (
	SELECT DISTINCT	
		m.CCAID
		, m.MPMemberID AS 'NAME_ID'
		, m.MedicareHIC AS 'HICN'
		, m.MedicareMBI AS 'MBI'
		, m.MMIS_ID
	FROM Actuarial_Services.dbo.ADS_Members AS m
) AS ads
	ON n.TEXT2 = ads.CCAID
LEFT JOIN (
	SELECT
		hcfa1.*
		, RTRIM(hcfa1.HIC_NUMBER_ORIG) AS 'HICN_trim'
		, CASE WHEN ISNUMERIC(SUBSTRING(hcfa1.HIC_NUMBER_ORIG, 2, 1)) = 1 THEN LEFT(hcfa1.HIC_NUMBER_ORIG, 9) END AS 'HICN_9'
		, CASE WHEN ISNUMERIC(SUBSTRING(hcfa1.HIC_NUMBER_ORIG, 2, 1)) = 1 THEN RTRIM(SUBSTRING(hcfa1.HIC_NUMBER_ORIG, 10, 10)) END AS 'HICN_type'
	FROM ( -- 2017-01-23
		SELECT DISTINCT
			  NAME_ID
			, REPLACE(REPLACE(REPLACE(HIC_NUMBER, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'HIC_NUMBER'
			, MBI
			, REPLACE(REPLACE(REPLACE(HIC_NUMBER_ORIG, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'HIC_NUMBER_ORIG'
			, MEMBER_ID AS 'CCAID'
			, DEATH_DATE
		FROM MPSnapshotProd.dbo.HCFA_NAME_ORG
	) AS hcfa1
) AS hcfa
	ON n.NAME_ID = hcfa.NAME_ID
LEFT JOIN (
-- duplicate IDs in MP?
-- SELECT CCAID, MMISID FROM MPSnapshotProd.dbo.VwMP_MemberInfo WHERE CCAID BETWEEN '5364521036' AND '5369999999' GROUP BY CCAID, MMISID HAVING COUNT(*) > 1
	SELECT DISTINCT
		CCAID
		, MMISID
	FROM MPSnapshotProd.dbo.VwMP_MemberInfo
	WHERE CCAID BETWEEN '5364521036' AND '5369999999'
) AS mi
	ON n.TEXT2 = mi.CCAID
WHERE n.TEXT2 BETWEEN '5364521036' AND '5369999999'
PRINT '#id_xwalk'
-- SELECT * FROM #id_xwalk ORDER BY CCAID	--74194
-- SELECT CCAID, COUNT(*) FROM #id_xwalk GROUP BY CCAID HAVING COUNT(*) > 1


-- #all_members_and_months: all members and months (regardless of enrollment status)
IF OBJECT_ID('tempdb..#all_members_and_months') IS NOT NULL DROP TABLE #all_members_and_months

SELECT
	member_month
	, RelMo
	, CCAID
INTO #all_members_and_months
FROM #month_list
CROSS APPLY (
	SELECT DISTINCT
		mm.CCAID
	-- SELECT TOP 1000 *
	FROM Actuarial_Services.dbo.ADS_Member_Months AS mm
	INNER JOIN #month_list
		ON mm.member_month = #month_list.MonthBeginDateTime
	WHERE mm.enroll_pct = 1
) AS x
ORDER BY SeqNo, CCAID
PRINT '#all_members_and_months'
-- SELECT * FROM #all_members_and_months ORDER BY CCAID, member_month
/* -- row check:
SELECT
	(SELECT COUNT(*) FROM #all_members_and_months) AS 'actual'
	,	(SELECT COUNT(DISTINCT MonthBeginDateTime) FROM #month_list)
		*
		(	SELECT COUNT(DISTINCT CCAID)
			FROM Actuarial_Services.dbo.ADS_Member_Months AS mm
			INNER JOIN #month_list ON mm.member_month = #month_list.MonthBeginDateTime
			WHERE enroll_pct = 1
		) AS 'expected'
*/
-- SELECT * FROM #all_members_and_months ORDER BY CCAID, member_month


-- #member_details: timeless member details
IF OBJECT_ID('tempdb..#member_details') IS NOT NULL DROP TABLE #member_details

SELECT
	m.CCAID
	, m.Name
	, mp.NAME_FIRST
	, mp.NAME_MI
	, mp.NAME_LAST
	, mp.NAME_FULL
	, m.Sex AS 'GENDER'
	, mp.DOB
	, mp.DOD
	, m.Race
	, m.PrimaryLanguage AS 'lang_spoken'
	-- enroll_status  -- member has an open enrollment span in MP
	, CASE WHEN mps.enr_span_end = '9999-12-30' THEN 'current member' ELSE 'not current member' END AS 'enroll_status'
	-- enroll_status2 -- enroll status with deaths flagged
	, CASE WHEN mp.DOD IS NULL THEN (CASE WHEN mps.enr_span_end = '9999-12-30' THEN 'current member' ELSE 'not current member' END) ELSE 'not current member' END AS 'enroll_status2'
INTO #member_details
-- SELECT *
FROM Actuarial_Services.dbo.ADS_Members AS m
LEFT JOIN (
	SELECT DISTINCT
		CAST(n.TEXT2 AS BIGINT) AS 'CCAID'
		, UPPER(REPLACE(REPLACE(REPLACE(RTRIM(n.NAME_FIRST), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')) AS 'NAME_FIRST'
		, UPPER(CASE WHEN PATINDEX('%[^a-Z]%', n.NAME_MI) = 1 THEN ''
			WHEN PATINDEX('%[^a-Z]%', n.NAME_MI) = 2 AND LEN(RTRIM(n.NAME_MI)) = 2 THEN LEFT(n.NAME_MI, 1)
			ELSE REPLACE(REPLACE(REPLACE(COALESCE(RTRIM(n.NAME_MI), ''), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') END) AS 'NAME_MI'
		, UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(n.NAME_LAST)), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')) AS 'NAME_LAST'
		, UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(n.NAME_LAST)), CHAR(09), ''), CHAR(10), ''), CHAR(13), ''))-- AS 'NAME_LAST'
			+ ', '
			+ UPPER(REPLACE(REPLACE(REPLACE(RTRIM(n.NAME_FIRST), CHAR(09), ''), CHAR(10), ''), CHAR(13), ''))-- AS 'NAME_FIRST'
			+ RTRIM(' ' + UPPER(CASE WHEN PATINDEX('%[^a-Z]%', n.NAME_MI) = 1 THEN ''
				WHEN PATINDEX('%[^a-Z]%', n.NAME_MI) = 2 AND LEN(RTRIM(n.NAME_MI)) = 2 THEN LEFT(n.NAME_MI, 1)
				ELSE REPLACE(REPLACE(REPLACE(COALESCE(RTRIM(n.NAME_MI), ''), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') END))-- AS 'NAME_MI'
				AS 'NAME_FULL'
		, CAST(
				CASE WHEN DATEDIFF(YY
						, n.BIRTH_DATE
						, COALESCE(
							CASE WHEN n.DATE1 > GETDATE() THEN NULL ELSE n.DATE1 END
							, CASE WHEN hcfa.DEATH_DATE > GETDATE() THEN NULL ELSE hcfa.DEATH_DATE END
							, GETDATE()
							)
					) >= DATEDIFF(YY, 0, GETDATE())		-- is the age in years more than the number of years from 1900 to present? -- to exclude invalid dates
				THEN NULL
				ELSE n.BIRTH_DATE END
			AS DATE) AS 'DOB'
		, CAST(COALESCE(
				CASE WHEN n.DATE1 > GETDATE() THEN NULL ELSE n.DATE1 END
				, CASE WHEN hcfa.DEATH_DATE > GETDATE() THEN NULL ELSE hcfa.DEATH_DATE END
			) AS DATE) AS 'DOD'
	-- SELECT *
	FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS a
	LEFT JOIN MPSnapshotProd.dbo.NAME AS n
		ON a.[ENTITY_ID] = n.NAME_ID
		AND n.PROGRAM_ID <> 'XXX'
		AND n.TEXT2 LIKE '536%'
	LEFT JOIN MPSnapshotProd.dbo.DATE_SPAN AS ds
		ON n.NAME_ID = ds.NAME_ID
		AND ds.COLUMN_NAME = 'name_text19'
		--AND ds.VALUE IN ('ICO', 'SCO')
		AND ds.CARD_TYPE = 'MCAID App'
	LEFT JOIN MPSnapshotProd.dbo.HCFA_NAME_ORG AS hcfa
		ON n.NAME_ID = hcfa.NAME_ID
	WHERE a.APP_TYPE = 'MCAID'
		AND n.TEXT2 BETWEEN '5364521036' AND '5369999999'
) AS mp
	ON m.CCAID = mp.CCAID
LEFT JOIN (
	SELECT CCAID, MAX(enr_span_end) AS 'enr_span_end' FROM #member_product_spans GROUP BY CCAID
) AS mps
	ON m.CCAID = mps.CCAID
ORDER BY
	m.CCAID
PRINT '#member_details'
-- SELECT * FROM #member_details ORDER BY CCAID
-- SELECT DISTINCT CCAID FROM #member_details ORDER BY CCAID	--53626


-- #MP_PCL: PCL from MP (ADS has PCL site, summary, and cap site)
IF OBJECT_ID('tempdb..#MP_PCL') IS NOT NULL DROP TABLE #MP_PCL

; WITH pcl_spans AS (
	SELECT DISTINCT
		n.TEXT2 AS 'CCAID'
		--, CAST(ds.[START_DATE] AS DATE) AS 'START_DATE'
		--, CAST(ds.END_DATE AS DATE) AS 'END_DATE'
		, np.SERVICE_TYPE
		, np.PROVIDER_ID AS 'prov_ID'
		, CASE WHEN np.SERVICE_TYPE IN ('Care Manager Org', 'ICO PCL') THEN npn.COMPANY
			ELSE COALESCE(REPLACE(REPLACE(REPLACE(npn.COMPANY, CHAR(09), ''), CHAR(10), ''), CHAR(13), ''), npn.NAME_LAST + ', ' + npn.NAME_FIRST)
			END AS 'prov_name'
		, CAST(np.EFF_DATE AS DATE) AS 'EFF_DATE'
		--, CAST(np.TERM_DATE AS DATE) AS 'TERM_DATE'
		, CASE WHEN n.TEXT2 = '5365574613' AND np.EFF_DATE = '2016-01-01' THEN '2016-05-31' ELSE CAST(np.TERM_DATE AS DATE) END AS 'TERM_DATE'
		--, npn.LETTER_COMP_CLOSE AS 'CactusProvK'
		--, CASE WHEN LEN(RTRIM(npn.TEXT4)) = 10 AND ISNUMERIC(RTRIM(npn.TEXT4)) = 1 THEN RTRIM(npn.TEXT4) END AS 'NPI'
	-- SELECT *
	FROM MPSnapshotProd.dbo.DATE_SPAN AS ds
	INNER JOIN MPSnapshotProd.dbo.NAME AS n
		ON ds.NAME_ID = n.NAME_ID
		AND n.PROGRAM_ID <> 'XXX'
		AND n.TEXT2 LIKE '536_______'
	LEFT JOIN MPSnapshotProd.dbo.NAME_PROVIDER AS np
		ON ds.NAME_ID = np.NAME_ID
		AND np.SERVICE_TYPE IN (
			'ICO PCL'
			, 'Primary Care Loc'
		)
		--AND (np.TERM_DATE IS NULL OR np.TERM_DATE > ICOSCO_mm.min_mm)
		AND COALESCE(np.TERM_DATE, '9999-12-31') > np.EFF_DATE -- 2016-10-21-1053: this is how invalid date spans are traditionally flagged
	LEFT JOIN MPSnapshotProd.dbo.NAME AS npn
		ON np.PROVIDER_ID = npn.NAME_ID
	WHERE ds.COLUMN_NAME = 'name_text19'
		AND ds.VALUE IN ('ICO', 'SCO')
		AND ds.CARD_TYPE = 'MCAID App'
		--AND ds.END_DATE IS NULL
), span_counts AS (
	SELECT
		*
		, ROW_NUMBER() OVER(PARTITION BY CCAID ORDER BY EFF_DATE) AS 'span_num'
	FROM pcl_spans
)
SELECT
	s1.CCAID
	, s1.SERVICE_TYPE
	, s1.prov_ID
	, s1.prov_name
	, s1.EFF_DATE
	--, s1.TERM_DATE
	, CASE WHEN s1.EFF_DATE IS NOT NULL THEN COALESCE(s1.TERM_DATE, DATEADD(DD, -1, s2.EFF_DATE), '9999-12-31') END AS 'TERM_DATE'	-- replaces open spans with the subsequent span start, if any
	, s1.span_num
INTO #MP_PCL
FROM span_counts AS s1
LEFT JOIN span_counts AS s2
	ON s1.CCAID = s2.CCAID
	AND s1.span_num = s2.span_num - 1
ORDER BY
	CCAID
	--, [START_DATE]
	, EFF_DATE
	, TERM_DATE
PRINT '#MP_PCL'
-- SELECT * FROM #MP_PCL ORDER BY CCAID, EFF_DATE, TERM_DATE	--67680
-- SELECT * FROM #MP_PCL WHERE CCAID = 5365574613 ORDER BY CCAID, EFF_DATE, TERM_DATE	-- this person has an overlapping span in MP (fixed above)
-- SELECT * FROM #MP_PCL WHERE CCAID IN (5365563990, 5365610363, 5365686997, 5365768871, 5365768900) ORDER BY CCAID, EFF_DATE, TERM_DATE	-- these people have open spans


-- #member_enrollment_history: all members and all months with enrollment details
IF OBJECT_ID('tempdb..#member_enrollment_history') IS NOT NULL DROP TABLE #member_enrollment_history

SELECT DISTINCT
	amam.*
	, mps.Product
	, CASE WHEN mps.CCAID IS NOT NULL THEN 1 END AS 'MP_enroll'
	, CASE WHEN amam.RelMo >= 1 THEN mm.enroll_pct END AS 'EP_enroll'
	, enrollment_month_count.enr_mo			-- number of months a member has been enrolled
	, enrollment_month_count.latest_enr_mo	-- number of months a member has been enrolled, descending (the latest month of enrollment = 1)
	, mps.enr_span_start
	, mps.enr_span_end
	, m.enroll_status
	, m.enroll_status2
	, id.member_ID
	, id.NAME_ID
	, id.MMISID
	, id.MBI
	, id.HIC_NUMBER
	, id.HIC_NUMBER_ORIG
	, id.SOC_SEC
	, m.Name
	, m.NAME_FIRST
	, m.NAME_MI
	, m.NAME_LAST
	, m.NAME_FULL
	, m.GENDER
	, m.DOB
	, m.DOD
	, m.Race
	, m.lang_spoken
	, mm.CITY
	, mm.Zipcode AS 'ZIP'
	, mm.Dual
	, CASE WHEN mm.RateCell LIKE 'Tier%' THEN 'Institutional' ELSE mm.RateCell END AS 'RC'
	--, mm.RateCell2
	, CASE WHEN mps.Product = 'ICO' THEN COALESCE(ico_pcl.prov_name, pcl.prov_name) ELSE COALESCE(pcl.prov_name, ico_pcl.prov_name) END AS 'PCL'	-- MP PCL
	, mm.MP_PCL_SiteName AS 'site_name'
	, mm.MP_PCL_SummaryName AS 'summary_name'
	, mm.MP_PCL_CapSite AS 'cap_site'
	, mm.CMO
	, mm.CMO_Group
	, CASE WHEN mps.Product = 'ICO'
		THEN CASE WHEN mm.CMO IN (
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
			WHEN mm.CMO IN (
				'Advocates, Inc'
				, 'Bay Cove Hmn Srvces'
				, 'Behavioral Hlth Ntwrk'
				, 'BosHC 4 Homeless'
				, 'CommH Link Worc'
				, 'Lynn Comm HC'
				, 'Vinfen'
			) THEN 'Health Home'
			END
		WHEN mps.Product = 'SCO'
		THEN CASE WHEN mm.CMO IN (
				'CCACG EAST'
				, 'CCACG WEST'
				, 'CCACG-Central'
				, 'CCC-Boston'
				, 'CCC-Framingham'
				, 'CCC-Lawrence'
				, 'CCC-Springfield'
				, 'SCMO'
			) THEN 'CCA'
			WHEN mm.CMO IN (
				'BIDJP Subacute'
				, 'BU Geriatric Service'
				, 'East Boston Neighborhoo'
				, 'Element Care'
				, 'Uphams Corner Hlth Cent'
			) THEN 'Delegated Site'
			END
		END AS 'CMO_group2'
INTO #member_enrollment_history
FROM #all_members_and_months AS amam
LEFT JOIN #member_product_spans AS mps
	ON amam.CCAID = mps.CCAID
	AND amam.member_month BETWEEN mps.enr_span_start AND mps.enr_span_end
LEFT JOIN Actuarial_Services.dbo.ADS_Member_Months AS mm
	ON amam.CCAID = mm.CCAID
	AND amam.member_month = mm.member_month
LEFT JOIN #id_xwalk AS id
	ON amam.CCAID = id.CCAID
LEFT JOIN #member_details AS m
	ON amam.CCAID = m.CCAID
LEFT JOIN (
	SELECT
		CCAID
		, member_month
		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY member_month) AS 'enr_mo'
		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY member_month DESC) AS 'latest_enr_mo'
	FROM Actuarial_Services.dbo.ADS_Member_Months
	WHERE enroll_pct = 1
) AS enrollment_month_count
	ON amam.CCAID = enrollment_month_count.CCAID
	AND amam.member_month = enrollment_month_count.member_month
LEFT JOIN #MP_PCL AS pcl
	ON amam.CCAID = pcl.CCAID
	AND amam.member_month BETWEEN pcl.EFF_DATE AND pcl.TERM_DATE
	AND pcl.SERVICE_TYPE = 'Primary Care Loc'
LEFT JOIN #MP_PCL AS ico_pcl
	ON amam.CCAID = ico_pcl.CCAID
	AND amam.member_month BETWEEN ico_pcl.EFF_DATE AND ico_pcl.TERM_DATE
	AND ico_pcl.SERVICE_TYPE = 'ICO PCL'
ORDER BY
	CCAID
	, member_month
PRINT '#member_enrollment_history'
-- SELECT TOP 10000 * FROM #member_enrollment_history ORDER BY CCAID, member_month
-- SELECT COUNT(*) FROM #member_enrollment_history	--3345807
-- problem member months:
-- SELECT CCAID, member_month, COUNT(*) FROM #member_enrollment_history GROUP BY CCAID, member_month HAVING COUNT(*) > 1 ORDER BY CCAID, member_month
-- SELECT TOP 10000 * FROM #member_enrollment_history WHERE CCAID IN (5365563990, 5365610363, 5365686997, 5365768871, 5365768900) ORDER BY CCAID, member_month
-- SELECT TOP 10000 * FROM #member_enrollment_history WHERE CCAID IN (5365686997, 5365768871, 5365768900) ORDER BY CCAID, member_month, enr_span_start
-- SELECT DISTINCT RateCell, RateCell2 FROM #member_enrollment_history ORDER BY RateCell, RateCell2
-- SELECT TOP 10000 * FROM #member_enrollment_history WHERE CCAID IN (5364521045, 5364521056, 5364521057, 5364521060, 5364521249, 5365555012) ORDER BY CCAID, member_month



