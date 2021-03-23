

-- see Karen Derby's email, Wed 6/7/2017 9:39 AM, about the new 'Passive Enroll Date' in MP -- see query: MP source for auto vs voluntary enrollment 2017-04-21.sql (below uses CCAMIS_Common.dbo.members, which appears to be accurate and up to date)


/* -- when was MP last updated?
SELECT MAX(UPDATE_DATE) AS 'latest_MP_update' FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP WITH (NOLOCK)
*/

/* -- when was MEH last updated?
USE Medical_Analytics
GO
SELECT TOP 1 CREATEDATE FROM Medical_Analytics.dbo.member_enrollment_history		-- started
SELECT [modify_date], name FROM sys.tables WHERE name = 'member_enrollment_history'	-- written to server
*/

/* -- is member_selected_stats up to date?
SELECT
	CASE WHEN DATEDIFF(DD,
		  (SELECT MAX(DATETO)      FROM CCAMIS_CURRENT.dbo.ez_claims)
		, (SELECT TOP 1 max_DATETO FROM Medical_Analytics.dbo.member_selected_stats)
	) = 0 THEN 'ok' ELSE 'NO' END AS 'CCAMIS_CURRENT'
	, CASE WHEN DATEDIFF(DD,
		  (SELECT MAX(DATETO)      FROM CCAMIS_NEXT.dbo.ez_claims)
		, (SELECT TOP 1 max_DATETO FROM Medical_Analytics.dbo.member_selected_stats)
	) = 0 THEN 'ok' ELSE 'NO' END AS 'CCAMIS_NEXT'
*/

-- 2017-05-02	-- added race, ethnicity, language, and marital groupings from HEDIS 2016 demographics file (per Inovalon)
				-- \\cca-fs1\groups\CrossFunctional\BI\Medical Analytics\Inovalon_HEDIS_2016\Output queries FINAL\QSI MemberData (2016) 2017-02-03 FINAL with last three characters of contract ID for CMSPlanID.sql
-- 2017-05-02	-- added county FIPS code
-- 2017-05-04	-- added readmits

/*
DROP TABLE #month_list			-- dropped when rerun
DROP TABLE #kd_ALL_enroll_ALL	-- skipped when rerun
DROP TABLE #kd_ALL_enroll		-- skipped when rerun
DROP TABLE #ICOSCO_mm			-- skipped when rerun
DROP TABLE #all_enrollment		-- skipped when rerun
DROP TABLE #member_addresses	-- skipped when rerun
DROP TABLE #all_member_phone	-- skipped when rerun
DROP TABLE #all_member_phone_concatenated	-- dropped when rerun
DROP TABLE #cactusPCP			-- skipped when rerun
DROP TABLE #services_all		-- skipped when rerun
DROP TABLE #services			-- skipped when rerun
DROP TABLE #status				-- skipped when rerun
DROP TABLE #provider_list		-- dropped when rerun
--DROP TABLE #selected_stats		-- skipped when rerun
DROP TABLE #enr_mo_counts		-- skipped when rerun
DROP TABLE #roster				-- dropped when rerun
*/


-- #month_list: member months will include 60 months up to the latest date in EP (the version in CCAMIS_CURRENT) plus any future enrollment months in MP

IF OBJECT_ID('tempdb..#month_list') IS NOT NULL DROP TABLE #month_list

-- DROP TABLE #month_list
/*	use this for short history	*/		DECLARE @start_year_date DATETIME SET @start_year_date = (DATEADD(MM, DATEDIFF(MM, 0, (SELECT MAX(member_month) FROM CCAMIS_CURRENT.dbo.enrollment_premium)) - 59, 0))
/*	use this for all history	*/		--DECLARE @start_year_date DATETIME SET @start_year_date = (SELECT MIN([START_DATE]) FROM MPSnapshotProd.dbo.DATE_SPAN WHERE COLUMN_NAME = 'name_text19' AND VALUE IN ('ICO', 'SCO') AND CARD_TYPE = 'MCAID App')
--PRINT @start_year_date
; WITH max_mp AS ( -- latest enrollment date in MP
	SELECT
		MIN(ds.[START_DATE]) AS 'min_mp_date'
		, MAX(ds.[START_DATE]) AS 'max_mp_date'
		, DATEDIFF(MM, MIN(ds.[START_DATE]), @start_year_date) AS 'seq_adj'
	-- SELECT MAX(UPDATE_DATE)
	FROM MPSnapshotProd.dbo.DATE_SPAN AS ds
	WHERE ds.COLUMN_NAME = 'name_text19'
		AND ds.VALUE IN ('ICO', 'SCO')
		AND ds.CARD_TYPE = 'MCAID App'
), max_ep AS ( -- latest enrollment date in EP (in CCAMIS_CURRENT)
	SELECT
		MIN(member_month) AS 'min_ep_date'
		, MAX(member_month) AS 'max_ep_date'
	FROM CCAMIS_CURRENT.dbo.enrollment_premium AS ep
), month_list_all AS (
	SELECT
		ROW_NUMBER() OVER(ORDER BY d.member_month) - max_mp.seq_adj AS 'SeqNo'
		, d.member_month AS 'MonthBeginDateTime'
		, DATEADD(SS, -1, DATEADD(MM, 1, d.member_month)) AS 'MonthEndDateTime'
		, d.CalendarYear AS 'Year'
		, RIGHT(d.CalendarQuarterofYear, 2) AS 'Quarter'
		, RIGHT(d.CalendarPeriodofYear, 2) AS 'Month'
		--, d.Lag AS 'RelMo'
		, DATEDIFF(MM, d.member_month, max_ep.max_ep_date) + 1 AS 'RelMo'
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
		--, max_ep.max_ep_date
		--, d.Lag
		, max_ep.max_ep_date
)
SELECT
	*
INTO #month_list
FROM month_list_all
WHERE SeqNo > 0
ORDER BY
	MonthBeginDateTime
PRINT ' 63 rows  #month_list (short)'  -- short list is five years plus future enrollment months (usually 60 + 3)
PRINT ' 158 rows  #month_list (all)'  -- all list is all months since the beginning of SCO plus future enrollment months (155 + 3 as of the April 2017 data load)
-- SELECT * FROM #month_list

--skip_month_list:


-- #kd_ALL_enroll_ALL:
-- All Enrollment Spans that are valid
-- see \\cca-fs1\groups\CrossFunctional\IT\MP Data Dictionaries\Program_id definitions.xlsx for PROGRAM_ID definitions (M30 = active; M90 = disenrolled)

IF OBJECT_ID('tempdb..#kd_ALL_enroll_ALL') IS NOT NULL GOTO skip_kd_ALL_enroll_ALL

-- DROP TABLE #kd_ALL_enroll_ALL
SELECT * INTO #kd_ALL_enroll_ALL FROM (
	SELECT DISTINCT
		ds.VALUE AS 'Product'
		, n.PROGRAM_ID
		, n.NAME_ID
		, CAST(n.TEXT2 AS BIGINT) AS 'CCAID'
		, CAST(n.TEXT2 AS BIGINT) - 5364521034 AS 'Member_ID'
		, CAST(a.TEXT1 AS BIGINT) AS 'Medicaid_ID'
		, CAST(ds.[START_DATE] AS DATE) AS 'EnrollStartDt'
		, CAST(COALESCE(ds.END_DATE, '9999-12-30') AS DATE) AS 'EnrollEndDt'  -- changed 2016-10-04
		, CASE WHEN ds.VALUE = 'SCO' AND ds.[START_DATE] = a.DATE2_DATE THEN 'SCO_passive' END AS 'SCO_passive_flag' -- 2017-07-24 -- with Karen's advice
	-- SELECT TOP 100 *
	FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS a
	INNER JOIN MPSnapshotProd.dbo.NAME AS n
		ON a.[ENTITY_ID] = n.NAME_ID
		AND a.APP_TYPE = 'MCAID'
	INNER JOIN MPSnapshotProd.dbo.DATE_SPAN AS ds
		ON n.NAME_ID = ds.NAME_ID
		AND ds.COLUMN_NAME = 'name_text19'
		AND ds.VALUE IN ('ICO', 'SCO')
		AND ds.CARD_TYPE = 'MCAID App'
	WHERE COALESCE(ds.END_DATE, '9999-12-30') > ds.[START_DATE]
		AND n.PROGRAM_ID <> 'XXX'
) AS kd_ALL_enroll_ALL
ORDER BY
	kd_ALL_enroll_ALL.CCAID
	, kd_ALL_enroll_ALL.EnrollStartDt
	, kd_ALL_enroll_ALL.EnrollEndDt
--PRINT ' 30409 rows  #kd_ALL_enroll_ALL'  -- 2016-10-06-0852
--PRINT ' 31456 rows  #kd_ALL_enroll_ALL'  -- 2016-10-21-1053
--PRINT ' 32767 rows  #kd_ALL_enroll_ALL'  -- 2016-12-01-0934
PRINT ' 40061 rows  #kd_ALL_enroll_ALL'  -- 2017-07-25-1020
-- SELECT * FROM #kd_ALL_enroll_ALL ORDER BY CCAID, EnrollStartDt, EnrollEndDt
-- SELECT * FROM #kd_ALL_enroll_ALL WHERE NAME_ID = 'N00007858261' ORDER BY CCAID, EnrollStartDt, EnrollEndDt
-- SELECT * FROM MPSnapshotProd.dbo.NAME WHERE NAME_ID = 'N00007858261'

skip_kd_ALL_enroll_ALL:


-- #kd_ALL_enroll:
-- Connect any contiguous enrollment spans for same product and member under each initial start date (EnrollStartDt1 here):

IF OBJECT_ID('tempdb..#kd_ALL_enroll') IS NOT NULL GOTO skip_kd_ALL_enroll

; WITH Enroll (product, name_id, CCAID, Member_ID, Medicaid_ID, SCO_passive_flag, SeqNo, EnrollStartDt1, EnrollStartDt, EnrollEndDt)
AS (
		SELECT
			a.Product
			, a.NAME_ID
			, a.CCAID
			, a.Member_ID
			, a.Medicaid_ID
			, a.SCO_passive_flag
			, 1
			, a.EnrollStartDt
			, a.EnrollStartDt
			, a.EnrollEndDt
		FROM #kd_ALL_enroll_ALL AS a
		WHERE NOT EXISTS (
			SELECT
				a1.NAME_ID
			FROM #kd_ALL_enroll_ALL AS a1
			WHERE a.NAME_ID = a1.NAME_ID
				AND a.Product = a1.Product
				AND DATEADD(DD, 1, a1.EnrollEndDt) = a.EnrollStartDt
			)
	UNION ALL
		SELECT
			c.Product
			, c.NAME_ID
			, c.CCAID
			, c.Member_ID
			, c.Medicaid_ID
			, c.SCO_passive_flag
			, c.SeqNo + 1
			, c.EnrollStartDt1
			, a.EnrollStartDt
			, a.EnrollEndDt
		FROM Enroll AS c
		INNER JOIN #kd_ALL_enroll_ALL AS a
			ON c.NAME_ID = a.NAME_ID
			AND c.Product = a.Product
		WHERE DATEADD(DD, 1, c.EnrollEndDt) = a.EnrollStartDt
	)
SELECT * INTO #kd_ALL_enroll FROM enroll
--PRINT ' 30409 rows   #kd_ALL_enroll'  -- 2016-10-06-0852
--PRINT ' 31456 rows   #kd_ALL_enroll'  -- 2016-10-21-1053
--PRINT ' 32767 rows   #kd_ALL_enroll'  -- 2016-12-01-0934
PRINT ' 40061 rows   #kd_ALL_enroll'  -- 2017-07-25-1020
-- SELECT * FROM #kd_ALL_enroll ORDER BY CCAID, EnrollStartDt1, EnrollStartDt, EnrollEndDt
-- SELECT * FROM #kd_ALL_enroll WHERE NAME_ID = 'N00000118501' ORDER BY CCAID, EnrollStartDt1, EnrollStartDt, EnrollEndDt
-- SELECT * FROM #kd_ALL_enroll WHERE SCO_passive_flag IS NOT NULL ORDER BY CCAID, EnrollStartDt1, EnrollStartDt, EnrollEndDt

skip_kd_ALL_enroll:


-- #ICOSCO_mm: this gives all ICO and SCO members for all months whether the member was enrolled in a particular month or not

IF OBJECT_ID('tempdb..#ICOSCO_mm') IS NOT NULL GOTO skip_ICO_mm

-- DROP TABLE #ICOSCO_mm
; WITH members AS ( -- ICO and SCO membership
	SELECT DISTINCT
		NAME_ID
		, CCAID
		, Member_ID
		, Medicaid_ID
		, SCO_passive_flag
	FROM #kd_ALL_enroll
	WHERE EnrollEndDt > (SELECT MIN(MonthBeginDateTime) FROM #month_list) -- only members who are still enrolled at the start of the five years
), mm AS (
	SELECT
		CAST(MonthBeginDateTime AS DATE) AS 'member_month'
		, RelMo
	FROM #month_list
)
SELECT
	*
INTO #ICOSCO_mm
FROM members
	, mm
ORDER BY
	member_id
	, member_month
CREATE INDEX memb_mm ON #ICOSCO_mm (member_id, member_month)
--PRINT ' 1566540 rows   #ICOSCO_mm -- this should be equal to (the number of months) × (the number of members)'  -- 2016-10-06-0852 -- (SELECT COUNT(*) * (SELECT COUNT(DISTINCT NAME_ID) FROM #kd_ALL_enroll_ALL WHERE EnrollEndDt > (SELECT MIN(MonthBeginDateTime) FROM #month_list)) FROM #month_list)
--PRINT ' 1625640 rows   #ICOSCO_mm -- this should be equal to (the number of months) × (the number of members)'  -- 2016-10-21-1053 -- (SELECT COUNT(*) * (SELECT COUNT(DISTINCT NAME_ID) FROM #kd_ALL_enroll_ALL WHERE EnrollEndDt > (SELECT MIN(MonthBeginDateTime) FROM #month_list)) FROM #month_list)
--PRINT ' 1783530 rows   #ICOSCO_mm -- this should be equal to (the number of months) × (the number of members)'  -- 2016-12-01-0934 -- (SELECT COUNT(*) * (SELECT COUNT(DISTINCT NAME_ID) FROM #kd_ALL_enroll_ALL WHERE EnrollEndDt > (SELECT MIN(MonthBeginDateTime) FROM #month_list)) FROM #month_list)
PRINT ' 2192192 rows   #ICOSCO_mm -- this should be equal to (the number of months) × (the number of members)'  -- 2017-07-25-1020 -- (SELECT COUNT(*) * (SELECT COUNT(DISTINCT NAME_ID) FROM #kd_ALL_enroll_ALL WHERE EnrollEndDt > (SELECT MIN(MonthBeginDateTime) FROM #month_list)) FROM #month_list)
DECLARE @warning_message5a AS VARCHAR(100)
DECLARE @warning_message5b AS VARCHAR(100)
DECLARE @warning_message6 AS VARCHAR(100)
DECLARE @rows_target AS INT
DECLARE @rows_actual AS INT
SET @rows_target = (SELECT COUNT(DISTINCT MonthBeginDateTime) * (SELECT COUNT(DISTINCT NAME_ID) FROM #kd_ALL_enroll_ALL WHERE EnrollEndDt > (SELECT MIN(MonthBeginDateTime) FROM #month_list)) FROM #month_list)
SET @rows_actual = (SELECT COUNT(*) FROM #ICOSCO_mm)
SELECT @warning_message5a = 'There are ' + CAST(@rows_actual AS VARCHAR(10)) + ' rows in the table #ICOSCO_mm'
SELECT @warning_message5b = '         (' + CAST(@rows_target AS VARCHAR(10)) + ' rows were expected.)'
SELECT @warning_message6 = CASE WHEN @rows_actual <> @rows_target THEN '--> ROW NUMBER MISMATCH! <--' ELSE '                  --> Row count OK.' END
PRINT @warning_message5a
PRINT @warning_message5b
PRINT @warning_message6
-- SELECT * FROM #ICOSCO_mm ORDER BY member_id, member_month -- 01:08 to display
-- SELECT COUNT(*) FROM #ICOSCO_mm
-- (SELECT COUNT(DISTINCT MonthBeginDateTime) * (SELECT COUNT(DISTINCT NAME_ID) FROM #kd_ALL_enroll_ALL WHERE EnrollEndDt > (SELECT MIN(MonthBeginDateTime) FROM #month_list)) FROM #month_list)
-- SELECT member_id, member_month FROM #ICOSCO_mm GROUP BY member_id, member_month
-- SELECT member_month FROM #ICOSCO_mm GROUP BY member_month ORDER BY member_month

skip_ICO_mm:


-- #all_enrollment: this adds all enrolled months from EP (in CCAMIS_CURRENT) with details

IF OBJECT_ID('tempdb..#all_enrollment') IS NOT NULL GOTO skip_all_enrollment

-- DROP TABLE #all_enrollment
SELECT
	#ICOSCO_mm.*
	, CASE WHEN kd.NAME_ID IS NOT NULL THEN 1 END AS 'MP_enroll' -- enrolled in NAME
	, kd.Product
	, enr.ep_Product

	, enr.ep_RC
	, enr.ep_Dual

	, MP_rc.RC AS 'MP_RC'
	, CASE WHEN SUBSTRING(MP_rc.RC, 3, 1) = 'D' OR SUBSTRING(MP_rc.RC, 1, 1) = 'D' THEN 'Dual' ELSE CASE WHEN MP_rc.RC IS NOT NULL THEN 'MHO' END END AS 'MP_Dual'

	, enr.ep_Class
	, enr.ep_enroll_pct
	, enr.ep_rating_category
	, enr.ep_primary_site_id
	, enr.ep_pcs_site_name
	, enr.ep_pcs_summary_name
	, enr.ep_pcs_cap_site
	, enr.ep_CareMgmt_Ent_id
	, enr.ep_care_mgmt_entity_descr
	, enr.ep_Contract_Ent_ID
	, enr.ep_ContractingEntityDescription
	, enr.ep_PCP_id
	, enr.ep_NP_id
	, enr.ep_ASAP_id
	, enr.MonthsSinceEnrolled
	, enr.TotalEnrollmentMonth
	, enr.ContinuousEnrollmentMonth
	--, enr.report_entity
	--, enr.report_entity_ID

	, enr.part_c_risk_score
	, enr.part_d_risk_score

	, enr.medicaid_premium
	, enr.medicare_part_c_premium
	, enr.medicare_part_d_premium
	, enr.medicare_part_d_lics
	, enr.medicare_part_d_reins
	--, enr.medicare_part_d_risk_share
	, enr.medicare_revenue_total
	, enr.total_premium

INTO #all_enrollment
-- SELECT *
FROM #ICOSCO_mm
LEFT JOIN (
	SELECT
		ep.member_ID
		, ep.member_id + 5364521034 AS 'CCAID'
		, rc.Product AS 'ep_Product'
		, rc.Dual AS 'ep_Dual'
		, rc.Class AS 'ep_Class'
		, RTRIM(rc.ReportingClass) AS 'ep_RC'
		, CAST(ep.member_month AS DATE) AS 'member_month'
		, ep.enroll_pct AS 'ep_enroll_pct'
		, ep.rating_category AS 'ep_rating_category'
		, ep.primary_site_id AS 'ep_primary_site_id'
		, CASE WHEN pcs.site_name = 'OneCare No Site' THEN NULL ELSE pcs.site_name END AS 'ep_pcs_site_name'
		, CASE WHEN pcs.summary_name = 'OneCare No Site' THEN NULL ELSE pcs.summary_name END AS 'ep_pcs_summary_name'
		, CASE WHEN pcs.Cap_site = 'OneCare No Site' THEN NULL ELSE pcs.Cap_site END AS 'ep_pcs_cap_site'
		, ep.CareMgmt_Ent_id AS 'ep_CareMgmt_Ent_id'
		, cm.CareMgmtEntityDescription AS 'ep_care_mgmt_entity_descr'
		, ep.Contract_Ent_ID AS 'ep_Contract_Ent_ID'
		, cer.ContractingEntityDescription AS 'ep_ContractingEntityDescription'
		, ep.PCP_id AS 'ep_PCP_id'
		, ep.NP_id AS 'ep_NP_id'
		, ep.ASAP_id AS 'ep_ASAP_id'
		, ep.MonthsSinceEnrolled
		, ep.TotalEnrollmentMonth
		, ep.ContinuousEnrollmentMonth

		, ep.part_c_risk_score
		, ep.part_d_risk_score

		-- added 2017-08-01 at Todd's request
		, ep.medicaid_premium-- AS 'ep_medicaid_premium'
		, ep.medicare_part_c_premium-- AS 'ep_medicare_part_c_premium'
		, ep.medicare_part_d_premium-- AS 'ep_medicare_part_d_premium'
		, ep.medicare_part_d_lics-- AS 'ep_medicare_part_d_lics'
		, ep.medicare_part_d_reins-- AS 'ep_medicare_part_d_reins'
		--, ep.medicare_part_d_risk_share-- AS 'ep_medicare_part_d_risk_share' -- always 0
		, ep.medicare_revenue_total-- AS 'ep_medicare_revenue_total'
		, ep.total_premium-- AS 'ep_total_premium'

		--, CASE WHEN                     cer.ContractingEntityDescription = 'Cambridge Health Alliance' THEN 'Cambridge Health Alliance'
		--	WHEN                        cer.ContractingEntityDescription = 'East Boston Neighborhoo'   THEN 'East Boston (EBNHC)'
		--	WHEN                        cer.ContractingEntityDescription = 'Holyoke Hlth Center'       THEN 'Holyoke Health Center'
		--	WHEN                        cer.ContractingEntityDescription = 'Lynn Comm HC'              THEN 'Lynn Community Health Center'
		--	WHEN                        cer.ContractingEntityDescription = 'Uphams Corner Hlth Cent'   THEN 'Uphams Corner'
		--	WHEN rc.Product = 'ICO' AND cer.ContractingEntityDescription = 'Atrius Health'             THEN 'Atrius'
		--	WHEN rc.Product = 'ICO' AND cer.ContractingEntityDescription = 'Reliant Medical Group'     THEN 'Reliant'
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CCC-Boston'                THEN 'CCC-Boston'
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CCC-Framingham'            THEN 'CCC-Framingham'
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CCC-Lawrence'              THEN 'CCC-Lawrence'
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CCC-Springfield'           THEN 'CCC-Springfield'
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CommHlthConn Worcest'      THEN 'Community Healthlink (CHL)'
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'Community Healthlink'      THEN 'Community Healthlink (CHL)'
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'BUGS'                      THEN 'BUGS'
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'BU Geriatric Service'      THEN 'BUGS'
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'Element Care'              THEN 'Element Care'
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'Element Care'              THEN 'Element Care'
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'BIDJP Subacute'            THEN 'BIDJP Subacute'
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'CG East'                   THEN 'CG East'
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'CG West'                   THEN 'CG West'
		--	END AS 'report_entity'

		--, CASE WHEN                     cer.ContractingEntityDescription = 'Cambridge Health Alliance' THEN ep.Contract_Ent_ID
		--	WHEN                        cer.ContractingEntityDescription = 'East Boston Neighborhoo'   THEN ep.Contract_Ent_ID
		--	WHEN                        cer.ContractingEntityDescription = 'Holyoke Hlth Center'       THEN ep.Contract_Ent_ID
		--	WHEN                        cer.ContractingEntityDescription = 'Lynn Comm HC'              THEN ep.Contract_Ent_ID
		--	WHEN                        cer.ContractingEntityDescription = 'Uphams Corner Hlth Cent'   THEN ep.Contract_Ent_ID
		--	WHEN rc.Product = 'ICO' AND cer.ContractingEntityDescription = 'Atrius Health'             THEN ep.Contract_Ent_ID
		--	WHEN rc.Product = 'ICO' AND cer.ContractingEntityDescription = 'Reliant Medical Group'     THEN ep.Contract_Ent_ID
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CCC-Boston'                THEN ep.CareMgmt_Ent_id
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CCC-Framingham'            THEN ep.CareMgmt_Ent_id
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CCC-Lawrence'              THEN ep.CareMgmt_Ent_id
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CCC-Springfield'           THEN ep.CareMgmt_Ent_id
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'CommHlthConn Worcest'      THEN ep.CareMgmt_Ent_id
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'Community Healthlink'      THEN ep.CareMgmt_Ent_id
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'BUGS'                      THEN ep.primary_site_id
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'BU Geriatric Service'      THEN ep.CareMgmt_Ent_id
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'Element Care'              THEN ep.primary_site_id
		--	WHEN rc.Product = 'ICO' AND cm.CareMgmtEntityDescription     = 'Element Care'              THEN ep.CareMgmt_Ent_id
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'BIDJP Subacute'            THEN ep.primary_site_id
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'CG East'                   THEN ep.primary_site_id
		--	WHEN rc.Product = 'SCO' AND pcs.Cap_site                     = 'CG West'                   THEN ep.primary_site_id
		--	END AS 'report_entity_ID'

	-- SELECT TOP 10000 *
	FROM CCAMIS_CURRENT.dbo.enrollment_premium AS ep-- WHERE member_id = 5365564633 - 5364521034 ORDER BY member_month
	INNER JOIN CCAMIS_Common.dbo.rating_categories AS rc
		ON ep.rating_category = rc.ratingcode
		AND rc.Product IN ('ICO', 'SCO')
	LEFT JOIN CCAMIS_Common.dbo.primary_care_site AS pcs
		ON ep.primary_site_id = pcs.site_id
	LEFT JOIN CCAMIS_Common.dbo.CareManagementEntity_Records AS cm
		ON ep.caremgmt_ent_id = cm.caremgmt_ent_id
	LEFT JOIN CCAMIS_Common.dbo.Contracting_Entity_Records AS cer
		ON ep.Contract_Ent_ID = cer.Contract_Ent_ID
	WHERE ep.enroll_pct = 1
) AS enr
	ON #ICOSCO_mm.member_id = enr.member_id
	AND #ICOSCO_mm.member_month = enr.member_month
LEFT JOIN #kd_ALL_enroll AS kd
	ON #ICOSCO_mm.member_id = kd.Member_ID
	AND #ICOSCO_mm.member_month BETWEEN kd.EnrollStartDt AND kd.EnrollEndDt
LEFT JOIN (
	SELECT
		ds.NAME_ID
		, ds.[START_DATE]
		, CAST(COALESCE(ds.END_DATE, '9999-12-30') AS DATE) AS 'END_DATE'
		, ds.VALUE AS 'RC'
		, CAST(n.TEXT2 AS BIGINT) AS 'CCAID'
		, CAST(n.TEXT2 AS BIGINT) - 5364521034 AS 'Member_ID'
	FROM MPSnapshotProd.dbo.DATE_SPAN AS ds
	LEFT JOIN MPSnapshotProd.dbo.NAME AS n
		ON ds.NAME_ID = n.NAME_ID
		AND n.PROGRAM_ID <> 'XXX'
		AND n.TEXT2 LIKE '536_______'
	WHERE ds.CARD_TYPE = 'MCAID App'
		AND ds.COLUMN_NAME = 'name_text14'
		AND ds.VALUE <> '99'
	--ORDER BY
	--	n.TEXT2
	--	, ds.[START_DATE]
	--	, ds.END_DATE
) AS MP_rc
	ON #ICOSCO_mm.member_id = MP_rc.Member_ID
	AND #ICOSCO_mm.member_month BETWEEN MP_rc.[START_DATE] AND MP_rc.END_DATE
ORDER BY
	#ICOSCO_mm.CCAID
	, #ICOSCO_mm.member_month
CREATE INDEX memb_mm_enr_prod_rc_loc ON #all_enrollment (member_id, member_month, product, ep_enroll_pct, ep_rating_category, ep_pcs_site_name, ep_pcs_summary_name, ep_pcs_cap_site, ep_care_mgmt_entity_descr, ep_ContractingEntityDescription)
--PRINT ' 1566540 rows   #all_enrollment -- this should be the same as ICOSCO_mm'  -- 2016-10-06-0852
--PRINT ' 1625640 rows   #all_enrollment -- this should be the same as ICOSCO_mm'  -- 2016-10-21-1053
--PRINT ' 1783530 rows   #all_enrollment -- this should be the same as ICOSCO_mm'  -- 2016-12-01-0934
PRINT ' 2192200 rows   #all_enrollment -- this should be the same as ICOSCO_mm'  -- 2017-07-25-1028
-- SELECT * FROM #all_enrollment ORDER BY member_ID, member_month
-- SELECT COUNT(*) AS ICOSCO_mm FROM #ICOSCO_mm SELECT COUNT(*) AS all_enrollment FROM #all_enrollment
-- SELECT * FROM #all_enrollment WHERE Product <> ep_Product ORDER BY member_ID, member_month
-- SELECT DISTINCT CCAID FROM #all_enrollment WHERE SCO_passive_flag IS NOT NULL
-- SELECT member_ID, member_month FROM #all_enrollment GROUP BY member_ID, member_month HAVING COUNT(*) > 1 ORDER BY member_ID, member_month
-- SELECT * FROM #all_enrollment WHERE member_ID = 1082415 ORDER BY member_ID, member_month

skip_all_enrollment:


-- #member_addresses: this gives a prioritized list of addresses for any member and date range
-- if two addresses occur within the same member-month: select the one with the lowest addr_priority number

IF OBJECT_ID('tempdb..#member_addresses') IS NOT NULL GOTO skip_member_addresses

-- DROP TABLE #member_addresses
; WITH city_wo_non_printing_characters AS (
	SELECT
		  na.CITY AS 'CITY_orig'
		, UPPER(REPLACE(REPLACE(REPLACE(RTRIM(na.CITY), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')) AS 'CITY'
	FROM MPSnapshotProd.dbo.NAME_ADDRESS AS na
	GROUP BY
		  na.CITY
		, REPLACE(REPLACE(REPLACE(RTRIM(na.CITY), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')
), city_corrections AS ( --\\cca-fs1\groups\CrossFunctional\BI\Medical Analytics\Quality Bonus Program\Adherence\MA cities and towns from meh edit.xlsx
	SELECT
		  cwonpc.CITY_orig
		, CASE
			WHEN cwonpc.CITY = 'ACTPM'				THEN 'ACTON'
			WHEN cwonpc.CITY = 'AGAWAN'				THEN 'AGAWAM'
			WHEN cwonpc.CITY = 'ALLSTON'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'AMEFBURY'			THEN 'AMESBURY'
			WHEN cwonpc.CITY = 'BACK BAY'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'BIILLERICA'			THEN 'BILLERICA'
			WHEN cwonpc.CITY = 'BOXBORO'			THEN 'BOXBOROUGH'
			WHEN cwonpc.CITY = 'Brocton'			THEN 'BROCKTON'
			WHEN cwonpc.CITY = 'BROOKLINE VLG'		THEN 'BROOKLINE'
			WHEN cwonpc.CITY = 'Bston'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'CAMBRDGE'			THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'CHARLESTOW'			THEN 'CHARLESTOWN'
			WHEN cwonpc.CITY = 'CHICOKEE'			THEN 'CHICOPEE'
			WHEN cwonpc.CITY = 'Chicopee, MA'		THEN 'CHICOPEE'
			WHEN cwonpc.CITY = 'DORCHESTER'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCESTER'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCHESTER CENTER'	THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCHESTER CTR'		THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCHESTR CTR'		THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCHSTER'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DRACUT MA'			THEN 'DRACUT'
			WHEN cwonpc.CITY = 'DORCHSTER'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'E ARLINGTON'		THEN 'ARLINGTON'
			WHEN cwonpc.CITY = 'EAST ARLINGTON'		THEN 'ARLINGTON'
			WHEN cwonpc.CITY = 'E BOSTON'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'E BRIDGEWATER'		THEN 'EAST BRIDGEWATER'
			WHEN cwonpc.CITY = 'E BRIDGEWTR'		THEN 'EAST BRIDGEWATER'
			WHEN cwonpc.CITY = 'E BROOKFIELD'		THEN 'EAST BROOKFIELD'
			WHEN cwonpc.CITY = 'E CAMBRIDGE'		THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'E HAMPTON'			THEN 'EASTHAMPTON'
			WHEN cwonpc.CITY = 'E LONGMEADOW'		THEN 'EAST LONGMEADOW'
			WHEN cwonpc.CITY = 'E TEMPLETON'		THEN 'TEMPLETON'
			WHEN cwonpc.CITY = 'E WALPOLE'			THEN 'WALPOLE'
			WHEN cwonpc.CITY = 'E WAREHAM'			THEN 'WAREHAM'
			WHEN cwonpc.CITY = 'E. CAMBRIDGE'		THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'E.BOSTON'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'E.BRIDGEWATER'		THEN 'EAST BRIDGEWATER'
			WHEN cwonpc.CITY = 'E.BROOKFIELD'		THEN 'EAST BROOKFIELD'
			WHEN cwonpc.CITY = 'E.LONGMEADOW'		THEN 'EAST LONGMEADOW'
			WHEN cwonpc.CITY = 'E.WALPOLE'			THEN 'WALPOLE'
			WHEN cwonpc.CITY = 'E.WEYMOUTH'			THEN 'WEYMOUTH'
			WHEN cwonpc.CITY = 'EAST CAMBRIDGE'		THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'EAST WALPOLE'		THEN 'WALPOLE'
			WHEN cwonpc.CITY = 'EAST WEYMOUTH'		THEN 'WEYMOUTH'
			WHEN cwonpc.CITY = 'East Boston'		THEN 'BOSTON'
			WHEN cwonpc.CITY = 'FEEDING HILLS'		THEN 'AGAWAM'
			WHEN cwonpc.CITY = 'FEEDINGHILLS'		THEN 'AGAWAM'
			WHEN cwonpc.CITY = 'FISKDALE'			THEN 'STURBRIDGE'
			WHEN cwonpc.CITY = 'FISKDALED'			THEN 'STURBRIDGE'
			WHEN cwonpc.CITY = 'FOXBORO'			THEN 'FOXBOROUGH'
			WHEN cwonpc.CITY = 'GARDENER'			THEN 'GARDNER'
			WHEN cwonpc.CITY = 'HALYOKE'			THEN 'HOLYOKE'
			WHEN cwonpc.CITY = 'HAMPTON'			THEN 'HAMPDEN'
			WHEN cwonpc.CITY = 'HAXVERHILL'			THEN 'HAVERHILL'
			WHEN cwonpc.CITY = 'HOLLYOKE'			THEN 'HOLYOKE'
			WHEN cwonpc.CITY = 'HYDEPARK'			THEN 'HYDE PARK'
			WHEN cwonpc.CITY = 'INDIAN ORCH'		THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'INDIAN ORCHANT'		THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'INDIAN ORCHARD'		THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'INDIANORCHARD'		THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'JAMAICA'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'Jamacia Plain'		THEN 'BOSTON'
			WHEN cwonpc.CITY = 'JAMAICA PLAIN'		THEN 'BOSTON'
			WHEN cwonpc.CITY = 'JAMAICA PLAINS'		THEN 'BOSTON'
			WHEN cwonpc.CITY = 'JAMICA PLAIN'		THEN 'BOSTON'
			WHEN cwonpc.CITY = 'LOWELLE'			THEN 'LOWELL'
			WHEN cwonpc.CITY = 'MADLEN'				THEN 'MALDEN'
			WHEN cwonpc.CITY = 'MALBORO'			THEN 'MARLBOROUGH'
			WHEN cwonpc.CITY = 'MALBOROUGH'			THEN 'MARLBOROUGH'
			WHEN cwonpc.CITY = 'Manchester'			THEN 'MANCHESTER-BY-THE-SEA'
			WHEN cwonpc.CITY = 'MARLBORO'			THEN 'MARLBOROUGH'
			WHEN cwonpc.CITY = 'Medord'				THEN 'MEDFORD'
			WHEN cwonpc.CITY = 'MIDDLEBORO'			THEN 'MIDDLEBOROUGH'
			WHEN cwonpc.CITY = 'N ANDOVER'			THEN 'NORTH ANDOVER'
			WHEN cwonpc.CITY = 'N BROOKFIELD'		THEN 'NORTH BROOKFIELD'
			WHEN cwonpc.CITY = 'N CAMBRIDGE'		THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'N CHELMSFORD'		THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'N CHELMSFORD'		THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'N.CHELMSFORD'		THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'NO CHELMSFORD'		THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'NO CHELSMFORD'		THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'NORTH CHELMSFORD'	THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'N QUINCY'			THEN 'QUINCY'
			WHEN cwonpc.CITY = 'N READING'			THEN 'NORTH READING'
			WHEN cwonpc.CITY = 'N.ANDOVER'			THEN 'NORTH ANDOVER'
			WHEN cwonpc.CITY = 'N.BROOKFIELD'		THEN 'NORTH BROOKFIELD'
			WHEN cwonpc.CITY = 'N.READING'			THEN 'NORTH READING'
			WHEN cwonpc.CITY = 'NEWTON CENTER'		THEN 'NEWTON'
			WHEN cwonpc.CITY = 'NEWTON CENTRE'		THEN 'NEWTON'
			WHEN cwonpc.CITY = 'NEWTON HGHLDS'		THEN 'NEWTON'
			WHEN cwonpc.CITY = 'NORTH ATTLEBORO'	THEN 'NORTH ATTLEBOROUGH'
			WHEN cwonpc.CITY = 'NORTH HAMPTON'		THEN 'NORTHAMPTON'
			WHEN cwonpc.CITY = 'NORTHBORO'			THEN 'NORTHBOROUGH'
			WHEN cwonpc.CITY = 'NORTHHAMPTON'		THEN 'NORTHAMPTON'
			WHEN cwonpc.CITY = 'NORWWOD'			THEN 'NORWOOD'
			WHEN cwonpc.CITY = 'REDDING'			THEN 'READING'
			WHEN cwonpc.CITY = 'REVERE BEACH'		THEN 'REVERE'
			WHEN cwonpc.CITY = 'ROXBURY CROSSING'	THEN 'ROXBURY'
			WHEN cwonpc.CITY = 'ROXBURY XING'		THEN 'ROXBURY'
			WHEN cwonpc.CITY = 'S BOSTON'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'S.BOSTON'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'S.HADLEY'			THEN 'SOUTH HADLEY'
			WHEN cwonpc.CITY = 'S HADLEY'			THEN 'SOUTH HADLEY'
			WHEN cwonpc.CITY = 'SALISBURY BEACH'	THEN 'SALISBURY'
			WHEN cwonpc.CITY = 'SALSBURY'			THEN 'SALISBURY'
			WHEN cwonpc.CITY = 'SHELBURNE FALLS'	THEN 'SHELBURNE'
			WHEN cwonpc.CITY = 'SHELBURNE FLS'		THEN 'SHELBURNE'
			WHEN cwonpc.CITY = 'SO HADLEY'			THEN 'SOUTH HADLEY'
			WHEN cwonpc.CITY = 'South Boston'		THEN 'BOSTON'
			WHEN cwonpc.CITY = 'SOUTH BRIDGE'		THEN 'SOUTHBRIDGE'
			WHEN cwonpc.CITY = 'SOUTH HAMPTON'		THEN 'SOUTHAMPTON'
			WHEN cwonpc.CITY = 'SOUTH WICK'			THEN 'SOUTHWICK'
			WHEN cwonpc.CITY = 'SPFLD'				THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRING FIELD'		THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRINGFEILD'		THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRINGFILED'		THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRINGIFLED'		THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRINGLFIELD'		THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'Stonham'			THEN 'STONEHAM'
			WHEN cwonpc.CITY = 'TYNGSBORO'			THEN 'TYNGSBOROUGH'
			WHEN cwonpc.CITY = 'W BRIDGEWATER'		THEN 'WEST BRIDGEWATER'
			WHEN cwonpc.CITY = 'W BROOKFIELD'		THEN 'WEST BROOKFIELD'
			WHEN cwonpc.CITY = 'W ROXBURY'			THEN 'WEST ROXBURY'
			WHEN cwonpc.CITY = 'W SPFLD'			THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'W SPRINGFIELD'		THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'W SPRNGFIELD'		THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'W.BOYLSTON'			THEN 'WEST BOYLSTON'
			WHEN cwonpc.CITY = 'W.BRIDGEWATER'		THEN 'WEST BRIDGEWATER'
			WHEN cwonpc.CITY = 'W.BROOKFIELD'		THEN 'WEST BROOKFIELD'
			WHEN cwonpc.CITY = 'W.NEWBURY'			THEN 'WEST NEWBURY'
			WHEN cwonpc.CITY = 'W.ROXBURY'			THEN 'WEST ROXBURY'
			WHEN cwonpc.CITY = 'W.SPRINGFIELD'		THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'WAKEFEILD'			THEN 'WAKEFIELD'
			WHEN cwonpc.CITY = 'WEST FIELD'			THEN 'WESTFIELD'
			WHEN cwonpc.CITY = 'WEST SPRINGFEILD'	THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'WEST SPRINGFIEL'	THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'WEST SPRINGFLD'		THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'West Srpringfield'	THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'WESTBORO'			THEN 'WESTBOROUGH'
			WHEN cwonpc.CITY = 'WESTBOYLSTON'		THEN 'WEST BOYLSTON'
			WHEN cwonpc.CITY = 'WESTBROOKFIELD'		THEN 'WEST BROOKFIELD'
			WHEN cwonpc.CITY = 'WOCESTER'			THEN 'WORCESTER'
			WHEN cwonpc.CITY = 'WORSETER'			THEN 'WORCESTER'
			WHEN cwonpc.CITY = 'HOMELESS'			THEN NULL
			ELSE cwonpc.CITY END AS 'CITY'
	FROM city_wo_non_printing_characters AS cwonpc
)
SELECT
	  ROW_NUMBER() OVER(PARTITION BY a2.NAME_ID ORDER BY a2.addr_priority_flag, a2.[START_DATE] DESC, a2.END_DATE DESC, a2.addr_timestamp DESC) AS 'addr_priority'
	, a2.addr_priority_flag
	, a2.NAME_ID
	, UPPER(a2.ADDRESS_TYPE) AS 'ADDRESS_TYPE'
	, a2.PREFERRED_FLAG
	, REPLACE(REPLACE(REPLACE(RTRIM(a2.ADDRESS1), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'ADDRESS1'
	, REPLACE(REPLACE(REPLACE(RTRIM(a2.ADDRESS2), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'ADDRESS2'
	, city_corrections.CITY
	, a2.[STATE]
	, a2.ZIP
	, a2.ZIP_4
	, a2.COUNTRY
	--, a2.COUNTY
	, CASE WHEN a2.COUNTY = '6IDDLESEX'			THEN 'MIDDLESEX'
		WHEN a2.COUNTY = '2IDDLESEX'			THEN 'MIDDLESEX'
		WHEN a2.COUNTY = 'Kt@lippalogic.com'	THEN 'CUMBERLAND'
		WHEN a2.COUNTY = 'PYMOUTH'				THEN 'PLYMOUTH'
		WHEN a2.COUNTY = 'Uffolk'				THEN 'SUFFOLK'
		WHEN a2.COUNTY = '9UFFOLK'				THEN 'SUFFOLK'
		WHEN a2.COUNTY = '0FFOLK'				THEN 'SUFFOLK'
		WHEN a2.COUNTY = '00000'				THEN 'SUFFOLK'
		WHEN a2.COUNTY = '1ORCESTER'			THEN 'WORCESTER'
		WHEN a2.COUNTY = 'HOMELESS'				THEN NULL
		WHEN RTRIM(LTRIM(a2.COUNTY)) = ''		THEN NULL
		WHEN city_corrections.CITY = 'LONGMEADOW'	THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'LYNN'			THEN 'ESSEX'
		WHEN city_corrections.CITY = 'SPRINGFIELD'	THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'RANDOLPH'		THEN 'NORFOLK'
		WHEN city_corrections.CITY = 'WESTFIELD'	THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'AGAWAM'		THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'BEVERLY'		THEN 'ESSEX'
		WHEN city_corrections.CITY = 'BOSTON'		THEN 'SUFFOLK'
		WHEN city_corrections.CITY = 'BROCKTON'		THEN 'PLYMOUTH'
		WHEN city_corrections.CITY = 'BROOKLINE'	THEN 'NORFOLK'
		WHEN city_corrections.CITY = 'CAMBRIDGE'	THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'CHICOPEE'		THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'EVERETT'		THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'FALL RIVER'	THEN 'BRISTOL'
		WHEN city_corrections.CITY = 'FITCHBURG'	THEN 'WORCESTER'
		WHEN city_corrections.CITY = 'FRAMINGHAM'	THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'GARDNER'		THEN 'WORCESTER'
		WHEN city_corrections.CITY = 'HOLYOKE'		THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'MAYNARD'		THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'METHUEN'		THEN 'ESSEX'
		WHEN city_corrections.CITY = 'MILFORD'		THEN 'WORCESTER'
		WHEN city_corrections.CITY = 'NATICK'		THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'ONSET'		THEN 'PLYMOUTH'
		WHEN city_corrections.CITY = 'REVERE'		THEN 'SUFFOLK'
		WHEN city_corrections.CITY = 'S.DEERFIELD'	THEN 'FRANKLIN'
		WHEN city_corrections.CITY = 'SOMERVILLE'	THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'STONEHAM'		THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'WARE'			THEN 'HAMPSHIRE'
		WHEN city_corrections.CITY = 'WATERTOWN'	THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'WOLLASTON'	THEN 'NORFOLK'
		ELSE UPPER(RTRIM(LTRIM(a2.COUNTY))) END AS 'COUNTY'
	, a2.ZIP_ID
	, CAST(a2.[START_DATE] AS DATE) AS 'START_DATE'
	, CAST(a2.END_DATE AS DATE) AS 'END_DATE'
INTO #member_addresses
FROM (
	SELECT
		a1.*
		, CASE WHEN a1.timestamp_loc > 0 AND ISNUMERIC(SUBSTRING(a1.ADDRESS_TYPE, a1.timestamp_loc + 4, 2)) = 1
			THEN CAST('20' + SUBSTRING(a1.ADDRESS_TYPE, a1.timestamp_loc + 4, 2)
				+ '-' + SUBSTRING(a1.ADDRESS_TYPE, a1.timestamp_loc, 2)
				+ '-' + SUBSTRING(a1.ADDRESS_TYPE, a1.timestamp_loc + 2, 2)
				+ ' ' + SUBSTRING(a1.ADDRESS_TYPE, a1.timestamp_loc + 6, 2)
				+ ':' + SUBSTRING(a1.ADDRESS_TYPE, a1.timestamp_loc + 8, 2)
				+ ':' + SUBSTRING(a1.ADDRESS_TYPE, a1.timestamp_loc + 10, 2)
			AS DATETIME)
			END AS 'addr_timestamp'
	FROM (
		SELECT
			*
			, CASE WHEN addr.PREFERRED_FLAG = 'x' THEN 0
				ELSE
					CASE WHEN CHARINDEX('permanent', addr.ADDRESS_TYPE) > 0 THEN 10
						WHEN CHARINDEX('mailing', addr.ADDRESS_TYPE) > 0 THEN 20
						WHEN CHARINDEX('temp', addr.ADDRESS_TYPE) > 0 THEN 30
						WHEN CHARINDEX('shelter', addr.ADDRESS_TYPE) > 0 THEN 40
						WHEN CHARINDEX('office', addr.ADDRESS_TYPE) > 0 THEN 50
						END
						+
					CASE WHEN CHARINDEX('unverified', addr.ADDRESS_TYPE) > 0 THEN 1
						WHEN CHARINDEX('new', addr.ADDRESS_TYPE) > 0 THEN 2
						WHEN CHARINDEX('prior', addr.ADDRESS_TYPE) > 0 THEN 3
						WHEN CHARINDEX('old', addr.ADDRESS_TYPE) > 0 THEN 4
						ELSE 0
						END
				END AS 'addr_priority_flag'
			, CASE WHEN CHARINDEX('MAILING-', addr.ADDRESS_TYPE) = 0
				THEN CASE WHEN CHARINDEX('UNVERIFIED-', addr.ADDRESS_TYPE) = 0
					THEN CASE WHEN CHARINDEX('PERMANENT-', addr.ADDRESS_TYPE) = 0
						THEN 0
						ELSE CHARINDEX('PERMANENT-', addr.ADDRESS_TYPE) + 10 END
					ELSE CHARINDEX('UNVERIFIED-', addr.ADDRESS_TYPE) + 11 END
				ELSE CHARINDEX('MAILING-', addr.ADDRESS_TYPE) + 8 END
				AS 'timestamp_loc'
		FROM MPSnapshotProd.dbo.NAME_ADDRESS AS addr
	) AS a1
) AS a2
LEFT JOIN city_corrections
	ON a2.CITY = city_corrections.CITY_orig
GROUP BY
	  a2.[START_DATE]
	, a2.END_DATE
	, a2.addr_timestamp
	, a2.addr_priority_flag
	, a2.NAME_ID
	, UPPER(a2.ADDRESS_TYPE) --AS 'ADDRESS_TYPE'
	, a2.PREFERRED_FLAG
	, REPLACE(REPLACE(REPLACE(RTRIM(a2.ADDRESS1), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') --AS 'ADDRESS1'
	, REPLACE(REPLACE(REPLACE(RTRIM(a2.ADDRESS2), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') --AS 'ADDRESS2'
	, city_corrections.CITY
	, a2.[STATE]
	, a2.ZIP
	, a2.ZIP_4
	, a2.COUNTRY
	--, a2.COUNTY
	, CASE WHEN a2.COUNTY = '6IDDLESEX'			THEN 'MIDDLESEX'
		WHEN a2.COUNTY = '2IDDLESEX'			THEN 'MIDDLESEX'
		WHEN a2.COUNTY = 'Kt@lippalogic.com'	THEN 'CUMBERLAND'
		WHEN a2.COUNTY = 'PYMOUTH'				THEN 'PLYMOUTH'
		WHEN a2.COUNTY = 'Uffolk'				THEN 'SUFFOLK'
		WHEN a2.COUNTY = '9UFFOLK'				THEN 'SUFFOLK'
		WHEN a2.COUNTY = '0FFOLK'				THEN 'SUFFOLK'
		WHEN a2.COUNTY = '00000'				THEN 'SUFFOLK'
		WHEN a2.COUNTY = '1ORCESTER'			THEN 'WORCESTER'
		WHEN a2.COUNTY = 'HOMELESS'				THEN NULL
		WHEN RTRIM(LTRIM(a2.COUNTY)) = ''		THEN NULL
		WHEN city_corrections.CITY = 'LONGMEADOW'	THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'LYNN'			THEN 'ESSEX'
		WHEN city_corrections.CITY = 'SPRINGFIELD'	THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'RANDOLPH'		THEN 'NORFOLK'
		WHEN city_corrections.CITY = 'WESTFIELD'	THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'AGAWAM'		THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'BEVERLY'		THEN 'ESSEX'
		WHEN city_corrections.CITY = 'BOSTON'		THEN 'SUFFOLK'
		WHEN city_corrections.CITY = 'BROCKTON'		THEN 'PLYMOUTH'
		WHEN city_corrections.CITY = 'BROOKLINE'	THEN 'NORFOLK'
		WHEN city_corrections.CITY = 'CAMBRIDGE'	THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'CHICOPEE'		THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'EVERETT'		THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'FALL RIVER'	THEN 'BRISTOL'
		WHEN city_corrections.CITY = 'FITCHBURG'	THEN 'WORCESTER'
		WHEN city_corrections.CITY = 'FRAMINGHAM'	THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'GARDNER'		THEN 'WORCESTER'
		WHEN city_corrections.CITY = 'HOLYOKE'		THEN 'HAMPDEN'
		WHEN city_corrections.CITY = 'MAYNARD'		THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'METHUEN'		THEN 'ESSEX'
		WHEN city_corrections.CITY = 'MILFORD'		THEN 'WORCESTER'
		WHEN city_corrections.CITY = 'NATICK'		THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'ONSET'		THEN 'PLYMOUTH'
		WHEN city_corrections.CITY = 'REVERE'		THEN 'SUFFOLK'
		WHEN city_corrections.CITY = 'S.DEERFIELD'	THEN 'FRANKLIN'
		WHEN city_corrections.CITY = 'SOMERVILLE'	THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'STONEHAM'		THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'WARE'			THEN 'HAMPSHIRE'
		WHEN city_corrections.CITY = 'WATERTOWN'	THEN 'MIDDLESEX'
		WHEN city_corrections.CITY = 'WOLLASTON'	THEN 'NORFOLK'
		ELSE UPPER(RTRIM(LTRIM(a2.COUNTY))) END --AS 'COUNTY'
	, a2.ZIP_ID
	, CAST(a2.[START_DATE] AS DATE) --AS 'START_DATE'
	, CAST(a2.END_DATE AS DATE) --AS 'END_DATE'
ORDER BY
	a2.NAME_ID
	, ROW_NUMBER() OVER(PARTITION BY a2.NAME_ID ORDER BY a2.addr_priority_flag, a2.[START_DATE], a2.END_DATE, a2.addr_timestamp)
CREATE INDEX memb_priority ON #member_addresses (NAME_ID, addr_priority)
--PRINT ' 47494 rows   #member_addresses'  -- 2016-10-06-0852
--PRINT ' 48792 rows   #member_addresses'  -- 2016-10-21-1053
PRINT ' 50839 rows   #member_addresses'  -- 2016-12-01-0934
-- SELECT * FROM #member_addresses WHERE NAME_ID = 'N00007176702' ORDER BY NAME_ID, addr_priority

skip_member_addresses:


-- #all_member_phone: current contact information for all members

--IF OBJECT_ID('tempdb..#all_member_phone') IS NOT NULL DROP TABLE #all_member_phone
IF OBJECT_ID('tempdb..#all_member_phone') IS NOT NULL GOTO skip_all_member_phone

SELECT
	name.TEXT2 AS 'CCAID'
	, addr.NAME_ID
	, CASE WHEN phone.PREFERRED_FLAG NOT IN ('x','w') THEN 'v'
		ELSE phone.PREFERRED_FLAG END AS 'PHONE_PREFERRED_FLAG'
	, CASE WHEN LEN(phone.PHONE_NUMBER) = 10
		AND LEFT(RTRIM(phone.PHONE_NUMBER), 1) <> '0'
		AND RTRIM(phone.PHONE_NUMBER) <> '1111111111'
		AND RTRIM(phone.PHONE_NUMBER) <> '1234567890'
		AND RTRIM(phone.PHONE_NUMBER) <> '9999999999'
		AND ISNUMERIC(LEFT(RTRIM(phone.PHONE_NUMBER), 1)) = 1
		THEN '(' + SUBSTRING(phone.PHONE_NUMBER,1,3) + ') '
			+ SUBSTRING(phone.PHONE_NUMBER,4,3) + '-'
			+ SUBSTRING(phone.PHONE_NUMBER,7,4)
			+ ' [' +
			CASE WHEN LEFT(phone.PHONE_TYPE, 7) = 'daytime' THEN 'Daytime'
				WHEN LEFT(phone.PHONE_TYPE, 9) = 'nighttime' THEN 'Nighttime'
				WHEN CHARINDEX('TTY', phone.PHONE_TYPE) > 0 THEN 'TTY'
				WHEN LEFT(phone.PHONE_TYPE, 4) = 'home' THEN 'Home'
				WHEN RTRIM(phone.PHONE_TYPE) = 'facility' THEN 'Facility'
				WHEN RTRIM(phone.PHONE_TYPE) = 'fax' THEN 'Fax'
				WHEN RTRIM(phone.PHONE_TYPE) = 'mobile' THEN 'Mobile'
				WHEN RTRIM(phone.PHONE_TYPE) = 'office' THEN 'Office'
				WHEN RTRIM(phone.PHONE_TYPE) = 'other' THEN 'Other'
				WHEN LEFT(phone.PHONE_TYPE, 8) = 'no phone' THEN '"No Phone"'
				ELSE RTRIM(phone.PHONE_TYPE) END
			+ ']'
		ELSE NULL END AS 'member_phone'
	, CASE WHEN LEFT(phone.PHONE_TYPE, 7) = 'daytime' THEN 1
		WHEN LEFT(phone.PHONE_TYPE, 9) = 'nighttime' THEN 1
		WHEN CHARINDEX('TTY', phone.PHONE_TYPE) > 0 THEN 1
		WHEN LEFT(phone.PHONE_TYPE, 4) = 'home' THEN 0
		WHEN RTRIM(phone.PHONE_TYPE) = 'facility' THEN 2
		WHEN RTRIM(phone.PHONE_TYPE) = 'fax' THEN 3
		WHEN RTRIM(phone.PHONE_TYPE) = 'mobile' THEN 0
		WHEN RTRIM(phone.PHONE_TYPE) = 'office' THEN 2
		WHEN RTRIM(phone.PHONE_TYPE) = 'other' THEN 4
		WHEN LEFT(phone.PHONE_TYPE, 8) = 'no phone' THEN 5
		ELSE 4 END AS 'PHONE_PREF'
INTO #all_member_phone
FROM MPSnapshotProd.dbo.NAME_ADDRESS AS addr
LEFT JOIN MPSnapshotProd.dbo.NAME AS name
	ON addr.NAME_ID = name.NAME_ID
LEFT JOIN MPSnapshotProd.dbo.NAME_PHONE_NUMBERS AS phone
	ON addr.NAME_ID = phone.NAME_ID
WHERE name.TEXT2 LIKE '53%'
	AND phone.PREFERRED_FLAG = 'x'
	AND addr.END_DATE IS NULL
GROUP BY
	name.TEXT2
	, addr.NAME_ID
	, phone.PREFERRED_FLAG
	, phone.PHONE_TYPE
	, phone.PHONE_NUMBER
--PRINT ' 33994 rows   #all_member_phone'  -- 2016-10-11-0848
--PRINT ' 24007 rows   #all_member_phone'  -- 2016-10-11-0851 -- addr.END_DATE IS NULL -- it looks like this reduces the number of phone numbers to one per member
--PRINT ' 24987 rows   #all_member_phone'  -- 2016-10-21-1053
PRINT ' 26009 rows   #all_member_phone'  -- 2016-12-01-0934
-- SELECT * FROM #all_member_phone WHERE ccaid = 5365564209 5364522236 5365560061 AND address_end_date IS NULL ORDER BY PHONE_PREFERRED_FLAG DESC

IF OBJECT_ID('tempdb..#all_member_phone_concatenated') IS NOT NULL DROP TABLE #all_member_phone_concatenated

-- DROP TABLE #all_member_phone_concatenated
SELECT * INTO #all_member_phone_concatenated FROM (
    SELECT
		phone.NAME_ID
        , phone.CCAID
        , phone.CCAID - 5364521034 AS 'member_ID'
        , STUFF(ISNULL((SELECT ', ' + LOWER(phone2.member_phone)
            FROM (
                SELECT
					phone3.NAME_ID
                    , phone3.CCAID
                    , phone3.CCAID - 5364521034 'member_ID'
                    , phone3.PHONE_PREF
                    , LOWER(phone3.member_phone) AS 'member_phone'
                FROM #all_member_phone AS phone3
                --WHERE phone3.address_end_date IS NULL
                GROUP BY
					phone3.NAME_ID
                    , phone3.CCAID
                    , phone3.PHONE_PREF
                    , phone3.member_phone
            ) AS phone2
            WHERE phone2.NAME_ID = phone.NAME_ID
            GROUP BY
				phone2.CCAID
                , phone2.PHONE_PREF
                , phone2.member_phone
            ORDER BY
				phone2.CCAID
                , phone2.PHONE_PREF
            FOR XML PATH (''), TYPE).value('.','VARCHAR(max)'), ''), 1, 2, '') AS 'Phone number(s)' --note: "value" must be lowercase
    FROM #all_member_phone AS phone
    GROUP BY
		phone.NAME_ID
        , phone.CCAID
) AS all_member_phone_concatenated
ORDER BY all_member_phone_concatenated.CCAID
--PRINT ' 24006 rows   #all_member_phone_concatenated'  -- 2016-10-11-0851
--PRINT ' 24986 rows   #all_member_phone_concatenated'  -- 2016-10-11-0851
PRINT ' 26009 rows   #all_member_phone_concatenated'  -- 2016-12-01-0934
-- SELECT * FROM #all_member_phone_concatenated WHERE ccaid = 5364521314 5364522236 5364522236
-- SELECT COUNT(*), COUNT(DISTINCT CCAID) FROM #all_member_phone_concatenated

skip_all_member_phone:


-- cactusPCP: this provides a crosswalk of NAME_ID to NPI via Cactus Provider_K; adapted from an email from Karen Derby, Tue 3/8/2016 5:00 PM
IF OBJECT_ID('tempdb..#cactusPCP') IS NOT NULL GOTO skip_cactusPCP

-- DROP TABLE #cactusPCP
SELECT * INTO #cactusPCP FROM (
	SELECT
		pcp.NPI
		, pcp.TAXIDNUMBER
		, pcp.PROVIDER_K
		, MAX(pcp.LONGNAME) AS 'ProvName'
		, MIN(rt.[DESCRIPTION]) AS 'status' -- 'Contracted' < 'Credentialed' so takes priority
		, MIN(CASE WHEN id.USERDEF_RTK2 IS NOT NULL
				OR ea.CATEGORY_RTK = 'C3VD0FMMRO' THEN 'PCP'
			WHEN ea.category_rtk = '#FAB7BCCF1' THEN 'PCP/Spec'
			END) AS 'CategoryPCP'
		, MAX(CASE WHEN ea.assignment_rtk = 'C3VD0FMMJT'
				AND rt.[DESCRIPTION] IN ('Contracted', 'Credentialed') THEN 1
			ELSE 0 END) AS 'ICO'
		, MAX(CASE WHEN ea.assignment_rtk = 'C3VD0FMMGS'
				AND rt.[DESCRIPTION] IN ('Contracted', 'Credentialed') THEN 1
			ELSE 0 END) AS 'SCO'
		, MAX(rp.[DESCRIPTION]) AS 'ProviderRole'
		, MAX(CASE WHEN
				rp.[DESCRIPTION] = 'PCP'
				AND pcp.INDIVIDUALINSTITUTIONFLAG = 1
				AND pcp.active = 1
				AND ea.active = 1
				THEN 1 END
			) AS 'PCP_flag'
	-- SELECT TOP 100 *
	FROM CactusDBSrv.Cactus.VISUALCACTUS.PROVIDERS AS pcp
	INNER JOIN CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS AS ea
		ON pcp.PROVIDER_K = ea.PROVIDER_K
	INNER JOIN CactusDBSrv.Cactus.VISUALCACTUS.REFTABLE AS rt
		ON ea.STATUS_RTK = rt.reftable_k
	LEFT JOIN CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID AS id
		ON ea.EA_K = id.ENTITYASSIGNMENT_K
		AND id.userdef_rtk2 = 'C3VD0FMP4M'
		AND id.STARTDATE IS NOT NULL
	LEFT JOIN CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID AS id2
		ON ea.EA_K = id2.ENTITYASSIGNMENT_K
		AND id2.userdef_l1 = 1
		AND id2.active = 1
	LEFT JOIN CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID AS id3
		ON ea.EA_K = id3.ENTITYASSIGNMENT_K
		AND ea.recordtype = 'E'
		AND id3.active = 1
	LEFT JOIN CactusDBSrv.Cactus.VISUALCACTUS.REFTABLE AS rr
		ON id3.type_rtk = rr.reftable_k
		AND rr.[DESCRIPTION] = 'Provider Role'
	LEFT JOIN CactusDBSrv.Cactus.VisualCactus.Reftable AS rp
		ON id3.userdef_rtk2 = rp.reftable_k
	--WHERE rp.[DESCRIPTION] = 'PCP'
	--	AND pcp.INDIVIDUALINSTITUTIONFLAG = 1
	--	AND pcp.active = 1
	--	AND ea.active = 1
	GROUP BY
		pcp.NPI
		, pcp.TAXIDNUMBER
		, pcp.Provider_K
) AS cactusPCP
--PRINT ' 42608 rows   #cactusPCP'  -- 2016-10-28-1147
PRINT ' 42641 rows   #cactusPCP'  -- 2016-12-01-0934
-- SELECT * FROM #cactusPCP ORDER BY Provider_K
-- SELECT * FROM #cactusPCP WHERE PCP_flag = 1 ORDER BY Provider_K

skip_cactusPCP:


-- #services: this gets all services from DATE_SPAN for all members by date -- note fix: #services_all is modified into #services below

IF OBJECT_ID('tempdb..#services_all') IS NOT NULL GOTO skip_services_all

-- DROP TABLE #services_all
SELECT
	ds.NAME_ID
	, n.TEXT2 AS 'CCAID'
	, ds.VALUE AS 'Product'
	, CAST(n.TEXT2 AS BIGINT) - 5364521034 AS 'member_ID'
	, CAST(ds.[START_DATE] AS DATE) AS 'START_DATE'
	, CAST(ds.END_DATE AS DATE) AS 'END_DATE'
	, np.SERVICE_TYPE
	, np.PROVIDER_ID AS 'prov_ID'
	--, COALESCE(REPLACE(REPLACE(REPLACE(npn.COMPANY, CHAR(09), ''), CHAR(10), ''), CHAR(13), ''), npn.NAME_LAST + ', ' + npn.NAME_FIRST) AS 'prov_name' -- this will include crap in CMO and ICO PCL  -- 2016-09-02
	, CASE WHEN np.SERVICE_TYPE IN ('Care Manager Org', 'ICO PCL') THEN npn.COMPANY
-- note: for NAME_ID = N00007858261 this will put 'Refused LTSC' in for PCP name
		ELSE COALESCE(REPLACE(REPLACE(REPLACE(npn.COMPANY, CHAR(09), ''), CHAR(10), ''), CHAR(13), ''), npn.NAME_LAST + ', ' + npn.NAME_FIRST)
		END AS 'prov_name'
	, CAST(np.EFF_DATE AS DATE) AS 'EFF_DATE'
	--, CAST(COALESCE(np.TERM_DATE, '9999-12-31') AS DATE) AS 'TERM_DATE'
	, CAST(np.TERM_DATE AS DATE) AS 'TERM_DATE'
	, npn.LETTER_COMP_CLOSE AS 'CactusProvK'
	, CASE WHEN LEN(RTRIM(npn.TEXT4)) = 10 AND ISNUMERIC(RTRIM(npn.TEXT4)) = 1 THEN RTRIM(npn.TEXT4) END AS 'NPI'
INTO #services_all
-- SELECT *
FROM MPSnapshotProd.dbo.DATE_SPAN AS ds
INNER JOIN (
	SELECT MIN(member_month) AS 'min_mm' FROM #ICOSCO_mm
) AS ICOSCO_mm
	--ON COALESCE(ds.END_DATE, '9999-12-30') > ICOSCO_mm.min_mm
	ON (ds.END_DATE IS NULL OR ds.END_DATE > ICOSCO_mm.min_mm)
INNER JOIN MPSnapshotProd.dbo.NAME AS n
	ON ds.NAME_ID = n.NAME_ID
	AND n.PROGRAM_ID <> 'XXX'
LEFT JOIN MPSnapshotProd.dbo.NAME_PROVIDER AS np
	ON ds.NAME_ID = np.NAME_ID
	AND np.SERVICE_TYPE IN (
		'Care Manager'
		, 'ICO Care Manager'
		, 'Care Manager Org'
		, 'ICO PCL'
		, 'Primary Care Loc'
		, 'ICO PCP'
		, 'PCP'
		, 'Secondary Care Loc'
		, 'ICO Supp. Care Mgr'
		, 'LTSC Agency'
		, 'ASAP'
		, 'Care Model'
	)
	AND (np.TERM_DATE IS NULL OR np.TERM_DATE > ICOSCO_mm.min_mm)
	AND COALESCE(np.TERM_DATE, '9999-12-31') > np.EFF_DATE -- 2016-10-21-1053: this is how invalid date spans are traditionally flagged
LEFT JOIN MPSnapshotProd.dbo.NAME AS npn
	ON np.PROVIDER_ID = npn.NAME_ID
WHERE ds.COLUMN_NAME = 'name_text19'
	AND ds.VALUE IN ('ICO', 'SCO')
	AND ds.CARD_TYPE = 'MCAID App'
	--AND ds.END_DATE IS NULL
GROUP BY
	ds.NAME_ID
	, n.TEXT2
	, ds.VALUE
	, ds.[START_DATE]
	, ds.END_DATE
	, np.SERVICE_TYPE
	, np.PROVIDER_ID
	, npn.COMPANY
	, npn.NAME_LAST
	, npn.NAME_FIRST
	, np.EFF_DATE
	, np.TERM_DATE
	, npn.LETTER_COMP_CLOSE
	, CASE WHEN LEN(RTRIM(npn.TEXT4)) = 10 AND ISNUMERIC(RTRIM(npn.TEXT4)) = 1 THEN RTRIM(npn.TEXT4) END
ORDER BY
	n.TEXT2
	, ds.[START_DATE]
	, np.EFF_DATE
CREATE INDEX memb_serv_prov ON #services_all (member_id, SERVICE_TYPE, prov_ID)
--PRINT ' 187149 rows   #services_all'  -- 2016-10-06-0852
--PRINT ' 190822 rows   #services_all'  -- 2016-10-21-1053 -- before fix
--PRINT ' 188345 rows   #services_all'  -- 2016-10-21-1053
--PRINT ' 200192 rows   #services_all'  -- 2016-12-01-0934
--PRINT ' 201934 rows   #services_all'  -- 2016-12-15-1143 -- before LTSC added
--PRINT ' 255772 rows   #services_all'  -- 2017-05-22-1500 -- before ASAP added
PRINT ' 268988 rows   #services_all'  -- 2017-05-22-1500 -- after ASAP added
-- SELECT * FROM #services_all ORDER BY member_ID, SERVICE_TYPE, EFF_DATE, TERM_DATE

skip_services_all:

-- this fixes overlapping date spans in #services_all by taking the day before the next EFF_DATE as a TERM_DATE
IF OBJECT_ID('tempdb..#services') IS NOT NULL GOTO skip_services

-- DROP TABLE #services
; WITH serv AS (
	SELECT
		s.NAME_ID
		, s.SERVICE_TYPE
		, s.prov_ID
		, s.prov_name
		, s.EFF_DATE
		, s.TERM_DATE
		, ROW_NUMBER() OVER(PARTITION BY s.NAME_ID, s.SERVICE_TYPE ORDER BY s.EFF_DATE) AS 'row_num'
	FROM #services_all AS s
	--WHERE CCAID = 5365580109
	GROUP BY
		s.NAME_ID
		, s.SERVICE_TYPE
		, s.prov_ID
		, s.prov_name
		, s.EFF_DATE
		, s.TERM_DATE
)
SELECT
	sa.NAME_ID
	, sa.CCAID
	, sa.Product
	, sa.member_ID
	, sa.[START_DATE]
	, sa.END_DATE
	, sa.SERVICE_TYPE
	, sa.prov_ID
	, sa.prov_name
	, s3.EFF_DATE
	, s3.TERM_DATE
	, sa.CactusProvK
	, sa.NPI
INTO #services
FROM #services_all AS sa
LEFT JOIN (
	SELECT
		s1.NAME_ID
		, s1.SERVICE_TYPE
		, s1.prov_ID
		, s1.prov_name
		, s1.EFF_DATE
		, COALESCE(CASE WHEN s1.TERM_DATE > s2.EFF_DATE THEN DATEADD(DD, -1, s2.EFF_DATE) ELSE s1.TERM_DATE END, DATEADD(DD, -1, s2.EFF_DATE), '9999-12-31') AS 'TERM_DATE' --test_TERM_DATE
	FROM serv AS s1
	LEFT JOIN serv AS s2
		ON s1.NAME_ID = s2.NAME_ID
		AND s1.SERVICE_TYPE = s2.SERVICE_TYPE
		AND s1.row_num = s2.row_num - 1
) AS s3
	ON sa.NAME_ID = s3.NAME_ID
	AND sa.SERVICE_TYPE = s3.SERVICE_TYPE
	AND sa.prov_ID = s3.prov_ID
	AND COALESCE(sa.END_DATE, '9999-12-31') > s3.EFF_DATE
	AND sa.[START_DATE] <= s3.TERM_DATE
WHERE s3.EFF_DATE IS NOT NULL
	--AND CCAID = 5365580109
GROUP BY
	sa.NAME_ID
	, sa.CCAID
	, sa.Product
	, sa.member_ID
	, sa.[START_DATE]
	, sa.END_DATE
	, sa.SERVICE_TYPE
	, sa.prov_ID
	, sa.prov_name
	, s3.EFF_DATE
	, s3.TERM_DATE
	, sa.CactusProvK
	, sa.NPI
CREATE INDEX memb_serv_prov ON #services (member_id, SERVICE_TYPE, prov_ID)
--PRINT ' 161240 rows   #services'  -- 2016-10-06-0852
--PRINT ' 162578 rows   #services'  -- 2016-10-21-1053
PRINT ' 172371 rows   #services'  -- 2016-12-01-0934
-- SELECT * FROM #services ORDER BY member_ID, SERVICE_TYPE, EFF_DATE, TERM_DATE
-- SELECT * FROM #services_all WHERE CCAID = 5365580109 ORDER BY member_ID, SERVICE_TYPE, EFF_DATE -- pre-fix: note Reliant's TERM_DATE for EFF_DATE 2015-01-01
-- SELECT * FROM #services WHERE CCAID = 5365580109 ORDER BY member_ID, SERVICE_TYPE, EFF_DATE
-- SELECT * FROM #services WHERE CCAID = 5364525448 AND SERVICE_TYPE = 'Care Manager' ORDER BY member_ID, SERVICE_TYPE, START_DATE, EFF_DATE

skip_services:


-- #status: this shows enrollment status for any member for all months since the beginning of the five years
-- note: some rows will be duplicated due to overlapping NAME_PROVIDER date ranges (problem examples sent to David Browne 2016-08-26)
-- when date ranges overlap, preference is given to the latest EFF_DATE (using mm_row_count below)

IF OBJECT_ID('tempdb..#status') IS NOT NULL GOTO skip_status

-- DROP TABLE #status
; WITH max_enroll AS (
	SELECT
		MAX(EnrollStartDt) AS 'latest_start'
	FROM #kd_ALL_enroll
)
, max_disenroll AS (
	SELECT
		MAX(EnrollEndDt) AS 'latest_end'
		, DATEADD(DD, 1, MAX(EnrollEndDt)) AS 'enroll_limit'
	FROM #kd_ALL_enroll
	WHERE EnrollEndDt < '9999-12-30'
)
SELECT
	*
INTO #status
FROM (
	SELECT
		t.member_ID
		, t.CCAID
		, t.NAME_ID
		, enr.enr_span_start
		, enr.enr_span_end
		, t.MP_enroll
		, CASE WHEN enr_status.name_id IS NULL THEN 'not current member' ELSE 'current member' END AS 'enroll_status'
		, t.member_month
		, t.RelMo
		, t.Product
		, t.ep_Product
		, t.SCO_passive_flag
		, t.ep_Dual
		, t.ep_RC
		, t.MP_Dual
		, t.MP_RC
		, t.ep_Class
		, t.ep_enroll_pct
		, t.ep_rating_category
		, t.ep_primary_site_id AS 'cap_site_ID'
		, t.ep_pcs_site_name AS 'site_name'
		, t.ep_pcs_summary_name AS 'summary_name'
		, t.ep_pcs_cap_site AS 'cap_site'
		, t.ep_CareMgmt_Ent_id AS 'care_mgmt_ID'
		, t.ep_care_mgmt_entity_descr AS 'care_mgmt'
		, t.ep_Contract_Ent_ID AS 'contract_entity_ID'
		, t.ep_ContractingEntityDescription AS 'contract_entity'
		, t.ep_PCP_id
		, t.ep_NP_id
		, t.ep_ASAP_id

		, pcl.SERVICE_TYPE AS 'PCL_SERVICE_TYPE'
		, pcl.prov_ID AS 'PCL_ID'
		, pcl.prov_name AS 'PCL_name'
		, pcl.EFF_DATE AS 'PCL_EFF_DATE'
		, pcl.TERM_DATE AS 'PCL_TERM_DATE'

		, ico_pcl.SERVICE_TYPE AS 'ICO_PCL_SERVICE_TYPE'
		, ico_pcl.prov_ID AS 'ICO_PCL_ID'
		, ico_pcl.prov_name AS 'ICO_PCL_name'
		, ico_pcl.EFF_DATE AS 'ICO_PCL_EFF_DATE'
		, ico_pcl.TERM_DATE AS 'ICO_PCL_TERM_DATE'

		, pcp.SERVICE_TYPE AS 'PCP_SERVICE_TYPE'
		, pcp.prov_ID AS 'PCP_ID'
		, pcp.prov_name AS 'PCP_name'
		, pcp.EFF_DATE AS 'PCP_EFF_DATE'
		, pcp.TERM_DATE AS 'PCP_TERM_DATE'

		, ico_pcp.SERVICE_TYPE AS 'ICO_PCP_SERVICE_TYPE'
		, ico_pcp.prov_ID AS 'ICO_PCP_ID'
		, ico_pcp.prov_name AS 'ICO_PCP_name'
		, ico_pcp.EFF_DATE AS 'ICO_PCP_EFF_DATE'
		, ico_pcp.TERM_DATE AS 'ICO_PCP_TERM_DATE'

		, cmo.SERVICE_TYPE AS 'CMO_SERVICE_TYPE'
		, cmo.prov_ID AS 'CMO_ID'
		, cmo.prov_name AS 'CMO_name'
		, cmo.EFF_DATE AS 'CMO_EFF_DATE'
		, cmo.TERM_DATE AS 'CMO_TERM_DATE'

		, cm.SERVICE_TYPE AS 'CM_SERVICE_TYPE'
		, cm.prov_ID AS 'CM_ID'
		, cm.prov_name AS 'CM_name'
		, cm.EFF_DATE AS 'CM_EFF_DATE'
		, cm.TERM_DATE AS 'CM_TERM_DATE'

		, ico_cm.SERVICE_TYPE AS 'ICO_CM_SERVICE_TYPE'
		, ico_cm.prov_ID AS 'ICO_CM_ID'
		, ico_cm.prov_name AS 'ICO_CM_name'
		, ico_cm.EFF_DATE AS 'ICO_CM_EFF_DATE'
		, ico_cm.TERM_DATE AS 'ICO_CM_TERM_DATE'

		, ico_cm_s.SERVICE_TYPE AS 'ICO_SUPP_CM_SERVICE_TYPE'
		, ico_cm_s.prov_ID AS 'ICO_SUPP_CM_ID'
		, ico_cm_s.prov_name AS 'ICO_SUPP_CM_name'
		, ico_cm_s.EFF_DATE AS 'ICO_SUPP_CM_EFF_DATE'
		, ico_cm_s.TERM_DATE AS 'ICO_SUPP_CM_TERM_DATE'

		, ltsc_s.SERVICE_TYPE AS 'LTSC_AGENCY_SERVICE_TYPE'
		, ltsc_s.prov_ID AS 'LTSC_AGENCY_ID'
		, ltsc_s.prov_name AS 'LTSC_AGENCY_name'
		, ltsc_s.EFF_DATE AS 'LTSC_AGENCY_EFF_DATE'
		, ltsc_s.TERM_DATE AS 'LTSC_AGENCY_TERM_DATE'

		, asap_s.SERVICE_TYPE AS 'ASAP_SERVICE_TYPE'
		, asap_s.prov_ID AS 'ASAP_ID'
		, asap_s.prov_name AS 'ASAP_name'
		, asap_s.EFF_DATE AS 'ASAP_EFF_DATE'
		, asap_s.TERM_DATE AS 'ASAP_TERM_DATE'

		, caremodel_s.SERVICE_TYPE AS 'CareModel_SERVICE_TYPE'
		, caremodel_s.prov_ID AS 'CareModel_ID'
		, caremodel_s.prov_name AS 'CareModel_name'
		, caremodel_s.EFF_DATE AS 'CareModel_EFF_DATE'
		, caremodel_s.TERM_DATE AS 'CareModel_TERM_DATE'
		--, DATEDIFF(MM, GETDATE(), t.member_month) AS 'relmo'
		, t.MonthsSinceEnrolled
		, t.TotalEnrollmentMonth
		, t.ContinuousEnrollmentMonth
		, ROW_NUMBER() OVER(
			PARTITION BY
				t.CCAID
				, t.member_month
			ORDER BY
				t.CCAID
				, t.member_month
				, pcl.EFF_DATE DESC
				, ico_pcl.EFF_DATE DESC
				, pcp.EFF_DATE DESC
				, ico_pcp.EFF_DATE DESC
				, cmo.EFF_DATE DESC
				, cm.EFF_DATE DESC
				, ico_cm.EFF_DATE DESC
			) AS 'mm_row_count' -- this is here to eliminate duplicate rows caused by overlapping NAME_PROVIDER date ranges -- this gives preference to the latest enrollment date spa

		, ico_pcl.CactusProvK AS 'ico_pcl_CactusProvK'
		, ico_pcl.NPI AS 'ico_pcl_NPI'
		, pcl.CactusProvK AS 'pcl_CactusProvK'
		, pcl.NPI AS 'pcl_NPI'

		, ico_pcp.CactusProvK AS 'ico_pcp_CactusProvK'
		, ico_pcp.NPI AS 'ico_pcp_NPI'
		, pcp.CactusProvK AS 'pcp_CactusProvK'
		, pcp.NPI AS 'pcp_NPI'

		, t.part_c_risk_score
		, t.part_d_risk_score

		, t.medicaid_premium
		, t.medicare_part_c_premium
		, t.medicare_part_d_premium
		, t.medicare_part_d_lics
		, t.medicare_part_d_reins
		, t.medicare_revenue_total
		, t.total_premium

	-- SELECT MAX(END_DATE) FROM #status
	-- SELECT *
	FROM #all_enrollment AS t
	LEFT JOIN #services AS pcl
		ON t.CCAID = pcl.CCAID
		AND t.member_month BETWEEN pcl.EFF_DATE AND pcl.TERM_DATE
		AND pcl.SERVICE_TYPE = 'Primary Care Loc'
	LEFT JOIN #services AS ico_pcl
		ON t.CCAID = ico_pcl.CCAID
		AND t.member_month BETWEEN ico_pcl.EFF_DATE AND ico_pcl.TERM_DATE
		AND ico_pcl.SERVICE_TYPE = 'ICO PCL'
	LEFT JOIN #services AS pcp
		ON t.CCAID = pcp.CCAID
		AND t.member_month BETWEEN pcp.EFF_DATE AND pcp.TERM_DATE
		AND pcp.SERVICE_TYPE = 'PCP'
	LEFT JOIN #services AS ico_pcp
		ON t.CCAID = ico_pcp.CCAID
		AND t.member_month BETWEEN ico_pcp.EFF_DATE AND ico_pcp.TERM_DATE
		AND ico_pcp.SERVICE_TYPE = 'ICO PCP'
	LEFT JOIN #services AS cmo
		ON t.CCAID = cmo.CCAID
		AND t.member_month BETWEEN cmo.EFF_DATE AND cmo.TERM_DATE
		AND cmo.SERVICE_TYPE = 'Care Manager Org'
	LEFT JOIN #services AS cm
		ON t.CCAID = cm.CCAID
		AND t.member_month BETWEEN cm.EFF_DATE AND cm.TERM_DATE
		AND cm.SERVICE_TYPE = 'Care Manager'
	LEFT JOIN #services AS ico_cm
		ON t.CCAID = ico_cm.CCAID
		AND t.member_month BETWEEN ico_cm.EFF_DATE AND ico_cm.TERM_DATE
		AND ico_cm.SERVICE_TYPE = 'ICO Care Manager'
	LEFT JOIN #services AS ico_cm_s  -- added 2016-10-04
		ON t.CCAID = ico_cm_s.CCAID
		AND t.member_month BETWEEN ico_cm_s.EFF_DATE AND ico_cm_s.TERM_DATE
		AND ico_cm_s.SERVICE_TYPE = 'ICO Supp. Care Mgr'
	LEFT JOIN #services AS ltsc_s  -- added 2016-12-15
		ON t.CCAID = ltsc_s.CCAID
		AND t.member_month BETWEEN ltsc_s.EFF_DATE AND ltsc_s.TERM_DATE
		AND ltsc_s.SERVICE_TYPE = 'LTSC Agency'
	LEFT JOIN #services AS asap_s  -- added 2017-05-22
		ON t.CCAID = asap_s.CCAID
		AND t.member_month BETWEEN asap_s.EFF_DATE AND asap_s.TERM_DATE
		AND asap_s.SERVICE_TYPE = 'ASAP'
	LEFT JOIN #services AS caremodel_s  -- added 2017-09-21
		ON t.CCAID = caremodel_s.CCAID
		AND t.member_month BETWEEN caremodel_s.EFF_DATE AND caremodel_s.TERM_DATE
		AND caremodel_s.SERVICE_TYPE = 'Care Model'
	LEFT JOIN (
		SELECT
			name_id
			, EnrollStartDt1 AS 'enr_span_start'
			, CASE WHEN MAX(EnrollEndDt) < '9999-12-30' THEN MAX(EnrollEndDt) ELSE '9999-12-30' END AS 'enr_span_end'
		FROM #kd_ALL_enroll AS e1
		GROUP BY
			name_id
			, EnrollStartDt1
	) AS enr
		ON t.NAME_ID = enr.name_id
		AND t.member_month BETWEEN enr.enr_span_start AND enr.enr_span_end
	LEFT JOIN (
		SELECT
			NAME_ID
			, MAX(EnrollEndDt) AS 'enr_max'
		FROM #kd_ALL_enroll AS e1												-- 2017-02-24 -- [NOT] changed from #kd_ALL_enroll to get PROGRAM_ID (appears to give the same results)
		--WHERE   PROGRAM_ID <> 'M86'	-- 86 Disenrolled -- pending CMS confirmation	-- 2017-02-24 -- EnrollEndDt appears to capture these
		--	AND PROGRAM_ID <> 'M88'	-- 88 Disenrolled -- pending 834 confirmation	-- 2017-02-24
		--	AND PROGRAM_ID <> 'M90'	-- 90 Disenrolled Member						-- 2017-02-24
		GROUP BY
			NAME_ID
		HAVING MAX(EnrollEndDt) >= '9999-12-30'
	) AS enr_status
		ON t.NAME_ID = enr_status.name_id
	GROUP BY
		t.member_ID
		, t.CCAID
		, t.NAME_ID
		, enr.enr_span_start
		, enr.enr_span_end
		, t.MP_enroll
		, enr_status.name_id
		, t.member_month
		, t.RelMo
		, t.Product
		, t.ep_Product
		, t.SCO_passive_flag
		, t.ep_Dual
		, t.ep_RC
		, t.MP_Dual
		, t.MP_RC
		, t.ep_Class
		, t.ep_enroll_pct
		, t.ep_rating_category
		, t.ep_primary_site_id
		, t.ep_pcs_site_name
		, t.ep_pcs_summary_name
		, t.ep_pcs_cap_site
		, t.ep_CareMgmt_Ent_id
		, t.ep_care_mgmt_entity_descr
		, t.ep_Contract_Ent_ID
		, t.ep_ContractingEntityDescription
		, t.ep_PCP_id
		, t.ep_NP_id
		, t.ep_ASAP_id

		, pcl.SERVICE_TYPE --AS 'PCL_SERVICE_TYPE'
		, pcl.prov_ID --AS 'PCL_ID'
		, pcl.prov_name --AS 'PCL_name'
		, pcl.EFF_DATE --AS 'PCL_EFF_DATE'
		, pcl.TERM_DATE --AS 'PCL_TERM_DATE'

		, ico_pcl.SERVICE_TYPE --AS 'ICO_PCL_SERVICE_TYPE'
		, ico_pcl.prov_ID --AS 'ICO_PCL_ID'
		, ico_pcl.prov_name --AS 'ICO_PCL_name'
		, ico_pcl.EFF_DATE --AS 'ICO_PCL_EFF_DATE'
		, ico_pcl.TERM_DATE --AS 'ICO_PCL_TERM_DATE'

		, pcp.SERVICE_TYPE --AS 'PCP_SERVICE_TYPE'
		, pcp.prov_ID --AS 'PCP_ID'
		, pcp.prov_name --AS 'PCP_name'
		, pcp.EFF_DATE --AS 'PCP_EFF_DATE'
		, pcp.TERM_DATE --AS 'PCP_TERM_DATE'

		, ico_pcp.SERVICE_TYPE --AS 'ICO_PCP_SERVICE_TYPE'
		, ico_pcp.prov_ID --AS 'ICO_PCP_ID'
		, ico_pcp.prov_name --AS 'ICO_PCP_name'
		, ico_pcp.EFF_DATE --AS 'ICO_PCP_EFF_DATE'
		, ico_pcp.TERM_DATE --AS 'ICO_PCP_TERM_DATE'

		, cmo.SERVICE_TYPE --AS 'CMO_SERVICE_TYPE'
		, cmo.prov_ID --AS 'CMO_ID'
		, cmo.prov_name --AS 'CMO_name'
		, cmo.EFF_DATE --AS 'CMO_EFF_DATE'
		, cmo.TERM_DATE --AS 'CMO_TERM_DATE'

		, cm.SERVICE_TYPE --AS 'CM_SERVICE_TYPE'
		, cm.prov_ID --AS 'CM_ID'
		, cm.prov_name --AS 'CM_name'
		, cm.EFF_DATE --AS 'CM_EFF_DATE'
		, cm.TERM_DATE --AS 'CM_TERM_DATE'

		, ico_cm.SERVICE_TYPE --AS 'ICO_CM_SERVICE_TYPE'
		, ico_cm.prov_ID --AS 'ICO_CM_ID'
		, ico_cm.prov_name --AS 'ICO_CM_name'
		, ico_cm.EFF_DATE --AS 'ICO_CM_EFF_DATE'
		, ico_cm.TERM_DATE --AS 'ICO_CM_TERM_DATE'

		, ico_cm_s.SERVICE_TYPE --AS 'ICO_SUPP_CM_SERVICE_TYPE'
		, ico_cm_s.prov_ID --AS 'ICO_SUPP_CM_ID'
		, ico_cm_s.prov_name --AS 'ICO_SUPP_CM_name'
		, ico_cm_s.EFF_DATE --AS 'ICO_SUPP_CM_EFF_DATE'
		, ico_cm_s.TERM_DATE --AS 'ICO_SUPP_CM_TERM_DATE'

		, ltsc_s.SERVICE_TYPE --AS 'LTSC_AGENCY_SERVICE_TYPE'
		, ltsc_s.prov_ID --AS 'LTSC_AGENCY_ID'
		, ltsc_s.prov_name --AS 'LTSC_AGENCY_name'
		, ltsc_s.EFF_DATE --AS 'LTSC_AGENCY_EFF_DATE'
		, ltsc_s.TERM_DATE --AS 'LTSC_AGENCY_TERM_DATE'

		, asap_s.SERVICE_TYPE --AS 'ASAP_SERVICE_TYPE'
		, asap_s.prov_ID --AS 'ASAP_ID'
		, asap_s.prov_name --AS 'ASAP_name'
		, asap_s.EFF_DATE --AS 'ASAP_EFF_DATE'
		, asap_s.TERM_DATE --AS 'ASAP_TERM_DATE'

		, caremodel_s.SERVICE_TYPE --AS 'CareModel_SERVICE_TYPE'
		, caremodel_s.prov_ID --AS 'CareModel_ID'
		, caremodel_s.prov_name --AS 'CareModel_name'
		, caremodel_s.EFF_DATE --AS 'CareModel_EFF_DATE'
		, caremodel_s.TERM_DATE --AS 'CareModel_TERM_DATE'

		, t.MonthsSinceEnrolled
		, t.TotalEnrollmentMonth
		, t.ContinuousEnrollmentMonth

		, ico_pcl.CactusProvK --AS 'ico_pcl_CactusProvK'
		, ico_pcl.NPI --AS 'ico_pcl_NPI'
		, pcl.CactusProvK --AS 'pcl_CactusProvK'
		, pcl.NPI --AS 'pcl_NPI'

		, ico_pcp.CactusProvK --AS 'ico_pcp_CactusProvK'
		, ico_pcp.NPI --AS 'ico_pcp_NPI'
		, pcp.CactusProvK --AS 'pcp_CactusProvK'
		, pcp.NPI --AS 'pcp_NPI'

		, t.part_c_risk_score
		, t.part_d_risk_score

		, t.medicaid_premium
		, t.medicare_part_c_premium
		, t.medicare_part_d_premium
		, t.medicare_part_d_lics
		, t.medicare_part_d_reins
		, t.medicare_revenue_total
		, t.total_premium

) AS [status]
, max_enroll
, max_disenroll
--PRINT ' 1566547 rows   #status -- this should be the same as the rows for #ICOSCO_mm and #all_enrollment'  -- 2016-10-06-0852
--PRINT ' 1625645 rows   #status -- this should be the same as the rows for #ICOSCO_mm and #all_enrollment'  -- 2016-10-21-1053
PRINT ' 1783535 rows   #status -- this should be the same as the rows for #ICOSCO_mm and #all_enrollment'  -- 2016-12-01-0934
-- SELECT * FROM #status ORDER BY CCAID, member_month
-- SELECT * FROM #status WHERE NAME_ID = 'N00018950918' ORDER BY CCAID, member_month
-- SELECT * FROM #status WHERE ep_pcs_summary_name LIKE '%atrius%' ORDER BY CCAID, member_month
-- SELECT * FROM #status WHERE member_ID = 1061761 ORDER BY CCAID, member_month
-- SELECT ico_pcl_CactusProvK, pcl_CactusProvK, ico_pcp_CactusProvK, pcp_CactusProvK FROM #status GROUP BY ico_pcl_CactusProvK, pcl_CactusProvK, ico_pcp_CactusProvK, pcp_CactusProvK

skip_status:



DECLARE @warning_message AS VARCHAR(100)
DECLARE @rows_off AS INT
SET @rows_off = (SELECT COUNT(*) AS 'count_row' FROM #status) - (SELECT COUNT(DISTINCT a.CCAID) * COUNT(DISTINCT a.member_month) FROM #ICOSCO_mm AS a)
SELECT @warning_message = CASE WHEN @rows_off <> 0 THEN '                        -> there ' + CASE WHEN ABS(@rows_off) = 1 THEN 'is ' ELSE 'are ' END + CAST(ABS(@rows_off) AS VARCHAR(10)) + CASE WHEN @rows_off > 0 THEN ' more row' ELSE ' fewer row' END + CASE WHEN ABS(@rows_off) > 1 THEN 's' ELSE '' END + ' than expected'
	ELSE '                        -> row number is correct' END
PRINT @warning_message
PRINT '                        -- extra rows in MP are due to enrollment spans that overlap on the first of the month (Jan. 2017)'


/*

-- row number check: the number of rows should be the product of the number of members and the number of months (one member per month)
-- 00:08 to run
; WITH b AS (SELECT COUNT(*) AS 'count_row' FROM #status)
SELECT
	COUNT(DISTINCT a.CCAID) AS 'num_memb'
	, COUNT(DISTINCT a.member_month) AS 'num_mos'
	, COUNT(DISTINCT a.CCAID) * COUNT(DISTINCT a.member_month) AS 'rows should be this'
	, MAX(b.count_row) AS 'rows are actually this'
FROM #ICOSCO_mm AS a
, b

-- problem months:
SELECT
	b.member_month
	, COUNT(DISTINCT b.CCAID) AS 'target_mm'
	, COUNT(b.CCAID) AS 'actual_mm'
	, COUNT(b.CCAID) - COUNT(DISTINCT b.CCAID) AS 'extra_mm'
FROM #status AS b
GROUP BY
	b.member_month
HAVING COUNT(b.CCAID) - COUNT(DISTINCT b.CCAID) > 0
ORDER BY
	COUNT(b.CCAID) - COUNT(DISTINCT b.CCAID) DESC

-- problem members:
SELECT
	CCAID
	, MAX(count_mm) AS 'count_mm'
FROM (
	SELECT
		b.member_month
		, b.CCAID
		, COUNT(b.CCAID) AS 'count_mm'
	FROM #status AS b
	GROUP BY
		b.member_month
		, b.CCAID
	HAVING COUNT(b.CCAID) > 1
	--ORDER BY
	--	member_month
	--	, CCAID
) AS q
GROUP BY
	CCAID
ORDER BY
	CCAID
	MAX(count_mm) DESC

*/


-- #provider_list: consolidated list of providers

IF OBJECT_ID('tempdb..#provider_list') IS NOT NULL DROP TABLE #provider_list

-- DROP TABLE #provider_list
SELECT
	prov.member_month
	, prov.RelMo
	, prov.member_ID
	, prov.PCP
	, prov.PCL
	, prov.CactusPCLprovK
	, COALESCE(prov.CactusPCPprovK,			-- fixes from Sara 2017-03-09
		CASE WHEN prov.PCP		= 'Cruz-Polanco, Mayra'	THEN 'C3VD0PK3M6'
			WHEN prov.PCP		= 'Molica, Salvatore'	THEN 'C3VD0PJ8MC'
			WHEN prov.PCP		= 'Mikulic, Lucas'		THEN 'C3VD0PKLSJ'
			WHEN prov.PCP		= 'Rosenberg, Naomi'	THEN 'C3VD0PL96H'
			WHEN prov.PCP		= 'Odell, Christine'	THEN 'C3VD0PKI0V'
			WHEN prov.PCP		= 'Long, Sarah'			THEN 'Y4EF0QJYUR'
			WHEN prov.PCP		= 'Mugford, James'		THEN 'C3XP0QX3L3'
			WHEN prov.PCP		= 'Lee, Betty'			THEN 'C3VD0PKM16'
			WHEN prov.PCP		= 'Melville, Daniel'	THEN 'C3VD0PKQYE'
			WHEN prov.PCP		= 'Triffletti, Philip'	THEN 'C3VD0PKY3T'
			WHEN prov.PCP		= 'Adelstein, Pamela'	THEN 'C3VD0PIXM9'
			WHEN prov.PCP		= 'Heemstra, Valerie'	THEN 'C3VD0PIWUY'
			WHEN prov.PCP		= 'Ballan, David'		THEN 'C3VD0PL3SR'
			WHEN prov.PCP		= 'Jainchill, John'		THEN 'C3VD0PIOJJ'
			END) AS 'CactusPCPprovK'
	, prov.PCL_NPI
	, prov.PCP_NPI
	, prov.CMO
	, prov.CM
	, prov.PCP_ID
	, prov.PCL_ID
	, prov.CMO_ID
	, prov.CM_ID
	, prov.LTSC_AGENCY_name
	, prov.LTSC_AGENCY_ID
	, prov.ASAP_name
	, prov.ASAP_ID
	, prov.CareModel_name
	, prov.CareModel_ID
	, prov.cap_site
	, prov.cap_site_ID
	, prov.care_mgmt
	, prov.care_mgmt_ID
	, prov.contract_entity
	, prov.contract_entity_ID
	, prov.summary_name
	, prov.site_name
INTO #provider_list
FROM (
	SELECT
		s.member_month
		, s.RelMo
		, s.member_ID
		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ICO_PCP_name, s.PCP_name) ELSE COALESCE(s.PCP_name, s.ICO_PCP_name) END AS 'PCP'
		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ICO_PCL_name, s.PCL_name) ELSE COALESCE(s.PCL_name, s.ICO_PCL_name) END AS 'PCL'
		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ico_pcl_CactusProvK, s.pcl_CactusProvK) ELSE COALESCE(s.pcl_CactusProvK, s.ico_pcl_CactusProvK) END AS 'CactusPCLprovK'
		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ico_pcp_CactusProvK, s.pcp_CactusProvK) ELSE COALESCE(s.pcp_CactusProvK, s.ico_pcp_CactusProvK) END AS 'CactusPCPprovK'
		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ico_pcl_NPI, s.pcl_NPI) ELSE COALESCE(s.pcl_NPI, s.ico_pcl_NPI) END AS 'PCL_NPI'
		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ico_pcp_NPI, s.pcp_NPI) ELSE COALESCE(s.pcp_NPI, s.ico_pcp_NPI) END AS 'PCP_NPI'
		, s.CMO_name AS 'CMO'
		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ICO_CM_name, s.ICO_SUPP_CM_name, s.CM_name) ELSE COALESCE(s.CM_name, s.ICO_CM_name, s.ICO_SUPP_CM_name) END AS 'CM'
		--, s.ICO_SUPP_CM_name AS 'Supp_CM'

		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ICO_PCP_ID, s.PCP_ID) ELSE COALESCE(s.PCP_ID, s.ICO_PCP_ID) END AS 'PCP_ID'
		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ICO_PCL_ID, s.PCL_ID) ELSE COALESCE(s.PCL_ID, s.ICO_PCL_ID) END AS 'PCL_ID'
		, s.CMO_ID AS 'CMO_ID'
		, CASE WHEN s.Product = 'ICO' THEN COALESCE(s.ICO_CM_ID, s.ICO_SUPP_CM_ID, s.CM_ID) ELSE COALESCE(s.CM_ID, s.ICO_CM_ID, s.ICO_SUPP_CM_ID) END AS 'CM_ID'
		--, s.ICO_SUPP_CM_ID AS 'Supp_CM_ID'

		, s.LTSC_AGENCY_name AS 'LTSC_AGENCY_name'	-- added 2016-12-15
		, s.LTSC_AGENCY_ID AS 'LTSC_AGENCY_ID'		-- added 2016-12-15
		, s.ASAP_name AS 'ASAP_name'	-- added 2017-05-22
		, s.ASAP_ID AS 'ASAP_ID'		-- added 2017-05-22
		, s.CareModel_name AS 'CareModel_name'	-- added 2017-09-21
		, s.CareModel_ID AS 'CareModel_ID'		-- added 2017-09-21
		, s.cap_site AS 'cap_site'
		, s.cap_site_ID AS 'cap_site_ID'
		, s.care_mgmt AS 'care_mgmt'
		, s.care_mgmt_ID AS 'care_mgmt_ID'
		, s.contract_entity AS 'contract_entity'
		, s.contract_entity_ID AS 'contract_entity_ID'
		, s.summary_name AS 'summary_name'
		, s.site_name AS 'site_name'

	-- SELECT *
	FROM #status AS s
	WHERE s.mm_row_count = 1 -- this is here to eliminate duplicate rows caused by overlapping NAME_PROVIDER date ranges
) AS prov
CREATE INDEX memb_mm ON #provider_list (member_ID, member_month)
--PRINT ' 1566540 rows   #provider_list'  -- 2016-10-06-0741
--PRINT ' 1625640 rows   #provider_list'  -- 2016-10-06-0741
--PRINT ' 1783530 rows   #provider_list'  -- 2016-10-06-0741
PRINT ' 1878786 rows   #provider_list'  -- 2017-03-09-1335
-- SELECT * FROM #provider_list ORDER BY Member_ID, member_month
-- SELECT * FROM #provider_list WHERE PCP_ID = 'N00007858261' ORDER BY Member_ID, member_month
-- SELECT CactusPCLprovK FROM #provider_list GROUP BY CactusPCLprovK  WHERE member_ID = 5365561171 - 5364521034 ORDER BY Member_ID, member_month




-- #selected_stats: net, count of claims, IP, obs, ED
-- 10:00 to run -- 2017-04-03-0945
-- 10:30 to run -- 1919295 rows -- 2017-04-05-1100
-- 11:50 to run -- 2173122 rows -- 2017-08-10-0850

--IF OBJECT_ID('tempdb..#selected_stats') IS NOT NULL GOTO skip_selected_stats
--IF OBJECT_ID('Medical_Analytics.dbo.member_enrollment_history2') IS NOT NULL GOTO skip_that
--PRINT 'this'
--skip_that:

IF DATEDIFF(DD,
	(SELECT MAX(DATETO) FROM CCAMIS_CURRENT.dbo.ez_claims)
	, (SELECT TOP 1 max_DATETO FROM Medical_Analytics.dbo.member_selected_stats)
	) = 0 GOTO skip_selected_stats ELSE PRINT 'STATS NEED UPDATING!' GOTO skip_selected_stats

-- when running all_years: uncomment the references to all_years in the INTO and INDEX statements below and comment the equivalent non-all_years lines
DROP TABLE Medical_Analytics.dbo.member_selected_stats
--DROP TABLE Medical_Analytics.dbo.member_selected_stats_all_years

; WITH select_memb_mm AS (
	--SELECT
	--	CCAID
	--	, member_ID
	--	, member_month
	--FROM Medical_Analytics.dbo.member_enrollment_history
	--GROUP BY
	--	CCAID
	--	, member_ID
	--	, member_month
	SELECT
		CCAID
		, member_ID
		, member_month
	FROM #ICOSCO_mm
	GROUP BY
		CCAID
		, member_ID
		, member_month
), ip AS (
	-- ip: IP claim details: count of IP claims and admits, sum of IP net
	--LEFT JOIN (
	SELECT
		ezc.member_id
		, d.member_month
		--, COUNT(DISTINCT ezc.CLAIMNO) AS 'count_IPclaims'
		, SUM(st.amount) AS 'IP_days'
		, SUM(ezcl.net) AS 'IP_net'
	FROM CCAMIS_CURRENT.dbo.ez_claims AS ezc
	INNER JOIN CCAMIS_CURRENT.dbo.ez_claimline AS ezcl
		ON ezc.CLAIMNO = ezcl.claimno
	LEFT JOIN CCAMIS_CURRENT.dbo.ez_stats AS st
		ON ezcl.claimno = st.claimno
		AND ezcl.tblrowid = st.linenum
	INNER JOIN CCAMIS_Common.dbo.dim_date AS d
		ON CAST(ezcl.todatesvc AS DATE) = d.[date]
	INNER JOIN CCAMIS_CURRENT.dbo.enrollment_premium AS ep
		ON ezc.member_id = ep.member_id
		AND d.member_month = ep.member_month
		AND ep.enroll_pct = 1
	INNER JOIN select_memb_mm
		ON ep.member_id = select_memb_mm.member_ID
		AND ep.member_month = select_memb_mm.member_month
	LEFT JOIN CCAMIS_CURRENT.dbo.ez_claimdiag AS dx
		ON ezc.CLAIMNO = dx.claimno
	LEFT JOIN CCAMIS_Common.dbo.drg AS drg
		ON ezc.drg = drg.DRG_ID
	WHERE st.stat = 'InpDay'
		AND dx.diagrefno = 1
	GROUP BY
		ezc.member_id
		, d.member_month
	--) AS ip
	--	ON oc3.member_ID = ip.member_id
	--	AND oc3.member_month = ip.member_month
), adm AS (
	SELECT
		d.member_month
		, ezc.MEMBER_ID
		, SUM(st.amount) AS 'admits'
	FROM CCAMIS_CURRENT.dbo.ez_claims AS ezc
	INNER JOIN CCAMIS_CURRENT.dbo.ez_claimline AS ezcl
		ON ezc.claimno = ezcl.claimno
	LEFT JOIN CCAMIS_CURRENT.dbo.ez_stats AS st
		ON ezcl.claimno = st.claimno
		AND ezcl.tblrowid = st.linenum
	INNER JOIN CCAMIS_Common.dbo.dim_date AS d
		ON CAST(ezcl.todatesvc AS DATE) = d.[Date]
	INNER JOIN select_memb_mm
		ON ezc.member_id = select_memb_mm.member_ID
		AND d.member_month = select_memb_mm.member_month
	INNER JOIN CCAMIS_CURRENT.dbo.enrollment_premium AS ep
		ON ezc.member_id = ep.member_id
		AND d.member_month = ep.member_month
		AND ep.enroll_pct = 1
	LEFT JOIN CCAMIS_CURRENT.dbo.ez_claimdiag AS dx
		ON ezc.claimno = dx.claimno
	WHERE
		ezc.DATETO IS NOT NULL
		AND st.stat = 'dischhosp'
		AND dx.diagrefno = 1
	GROUP BY
		d.member_month
		, ezc.MEMBER_ID
), claims_net AS (
	-- claims_net: count of claims and sum of net
	--LEFT JOIN (
	SELECT
		ezc.member_id
		, d.member_month
		, COUNT(DISTINCT ezc.CLAIMNO) AS 'count_claims'
		, SUM(ezcl.Net) AS 'sum_cl_net'
		, SUM(ezcl.QTY) AS 'sum_cl_qty'
	-- SELECT TOP 100 *
	FROM CCAMIS_CURRENT.dbo.ez_claims AS ezc
	INNER JOIN CCAMIS_CURRENT.dbo.ez_claimline AS ezcl
		ON ezc.claimno = ezcl.claimno
	INNER JOIN CCAMIS_Common.dbo.dim_date AS d
		ON CAST(ezcl.todatesvc AS DATE) = d.[date]
	INNER JOIN CCAMIS_CURRENT.dbo.enrollment_premium AS ep
		ON ezc.member_id = ep.member_id
		AND d.member_month = ep.member_month
		AND ep.enroll_pct = 1
	INNER JOIN select_memb_mm
		ON ep.member_id = select_memb_mm.member_ID
		AND ep.member_month = select_memb_mm.member_month
	GROUP BY
		ezc.member_id
		, d.member_month
	--ORDER BY
	--	ezc.member_id
	--	, d.member_month
	--) AS claims_net
	--	ON oc3.member_ID = claims_net.member_id
	--	AND oc3.member_month = claims_net.member_month
), obs AS (
	-- obs: count of obs claims
	--LEFT JOIN (
	SELECT
		ezc.member_ID
		, d.member_month
		, COUNT(DISTINCT ezc.claimno) AS 'obs_claims'
	FROM CCAMIS_CURRENT.dbo.ez_claims AS ezc
	INNER JOIN CCAMIS_CURRENT.dbo.ez_claimline AS ezcl
		ON ezc.claimno = ezcl.claimno
	INNER JOIN CCAMIS_Common.dbo.dim_date AS d
		ON CAST(ezcl.todatesvc AS DATE) = d.[date]
	INNER JOIN CCAMIS_CURRENT.dbo.enrollment_premium AS ep
		ON ezc.member_id = ep.member_id
		AND d.member_month = ep.member_month
		AND ep.enroll_pct = 1
	INNER JOIN select_memb_mm
		ON ep.member_id = select_memb_mm.member_ID
		AND ep.member_month = select_memb_mm.member_month
	LEFT JOIN CCAMIS_Common.dbo.ez_providers AS p
		ON ezc.provid = p.provid
	LEFT JOIN CCAMIS_Common.dbo.provider_leaf_nodes AS pln
		ON p.prov_leaf_node = pln.leaf_id
	LEFT JOIN CCAMIS_Common.dbo.ez_services AS sv
		ON ezcl.primcode_full = sv.primcode_full
	LEFT JOIN CCAMIS_Common.dbo.service_leaf_node AS sln
		ON sv.leaf_node = sln.leaf_id
	WHERE
		pln.leaf_name = 'Acute Care Hospital'
		AND sln.leaf_name = 'Observation'
	GROUP BY
		ezc.member_ID
		, d.member_month
	--) AS obs
	--	ON oc3.member_ID = obs.member_ID
	--	AND oc3.member_month = obs.member_month
), ed AS (
	-- ed: count of ED visits
	--LEFT JOIN (
	SELECT
		ezc.member_ID
		, d.member_month
		, COUNT(DISTINCT ezc.CLAIMNO) AS 'ED_visits'
		, SUM(ezcl.net) AS 'ED_net'
	-- SELECT *
	FROM CCAMIS_CURRENT.dbo.ez_claims AS ezc
	INNER JOIN CCAMIS_CURRENT.dbo.ez_claimline AS ezcl
		ON ezc.claimno = ezcl.claimno
	INNER JOIN CCAMIS_Common.dbo.dim_date AS d
		ON CAST(ezcl.todatesvc AS DATE) = d.[date]
	INNER JOIN CCAMIS_CURRENT.dbo.enrollment_premium AS ep
		ON ezc.member_id = ep.member_id
		AND d.member_month = ep.member_month
		AND ep.enroll_pct = 1
	INNER JOIN select_memb_mm
		ON ep.member_id = select_memb_mm.member_ID
		AND ep.member_month = select_memb_mm.member_month
	--LEFT JOIN CCAMIS_CURRENT.dbo.ez_stats AS st
	--	ON ezcl.claimno = st.claimno
	--	AND ezcl.tblrowid = st.linenum
	LEFT JOIN CCAMIS_Common.dbo.ez_providers AS p
		ON ezc.provid = p.provid
	LEFT JOIN CCAMIS_Common.dbo.provider_leaf_nodes AS pln
		ON p.prov_leaf_node = pln.leaf_id
	--LEFT JOIN CCAMIS_Common.dbo.ez_services AS sv
	--	ON ezcl.primcode_full = sv.primcode_full
	--LEFT JOIN CCAMIS_Common.dbo.service_leaf_node AS sln
	--	ON sv.leaf_node = sln.leaf_id
	WHERE
		ezc.DATETO IS NOT NULL
		AND ezc.Hospital_Claim_type = 'Emergency'
		AND pln.leaf_name = 'Acute Care Hospital'
	--WHERE
	--	ezc.DATETO IS NOT NULL
	--	AND sln.leaf_name = 'ER Visit'
	--	AND pln.leaf_name = 'Acute Care Hospital'
	GROUP BY
		ezc.member_ID
		, d.member_month
	--) AS ed
	--	ON oc3.member_ID = ed.member_ID
	--	AND oc3.member_month = ed.member_month
), med AS (
	SELECT
		c.member_id
		, d.member_month
		, SUM(cl.net) AS 'medical_cost'
	-- SELECT TOP 100 *
	FROM CCAMIS_CURRENT.dbo.Claims AS c
	-- SELECT TOP 10 * FROM CCAMIS_CURRENT.dbo.claimline AS cl
	INNER JOIN CCAMIS_CURRENT.dbo.claimline AS cl
		ON c.claim_num = cl.claim_num
	INNER JOIN CCAMIS_Common.dbo.dim_date AS d
		ON CAST(cl.todatesvc AS DATE) = d.[Date]
	INNER JOIN select_memb_mm
		ON c.member_id = select_memb_mm.member_ID
		AND d.member_month = select_memb_mm.member_month
	WHERE c.[Source] NOT IN ('IBNR', 'OCRiskShare', 'PartDRiskShare', 'ShadowOff', 'EBRisk', 'FullCapOffset', 'FullCapGross', 'PCapBonus', 'SCapBonus') -- IBNR left out because the numbers have been off recently -- 2016-06-10
	GROUP BY
		c.member_id
		, d.member_month
), rx AS (
	SELECT
		rx.member_id
		, rx.member_month
		, SUM(rx.drug_cost) AS 'drug_cost'
	FROM CCAMIS_CURRENT.dbo.pharmacy_claim_script_level AS rx
	INNER JOIN select_memb_mm
		ON rx.member_id = select_memb_mm.member_ID
		AND rx.member_month = select_memb_mm.member_month
	GROUP BY
		rx.member_id
		, rx.member_month
), readmits AS ( -- 2017-05-04
	SELECT
		rb.member_id
		, rb.member_month
		, SUM(rb.AdmitCount) AS 'Admits'
		, SUM(rb.ReadmitCount) AS 'Readmits'
	FROM CCAMIS_CURRENT.dbo.ReadmissionBase AS rb
	INNER JOIN select_memb_mm
		ON rb.member_id = select_memb_mm.member_ID
		AND rb.member_month = select_memb_mm.member_month
	GROUP BY
		rb.member_id
		, rb.member_month
)
SELECT
	select_memb_mm.*
	, med.medical_cost
	, rx.drug_cost
	, ed.ED_visits
	, ed.ED_net
	, adm.admits
	, ip.IP_days
	, ip.IP_net
	, obs.obs_claims
	--, ip.count_IPclaims
	, readmits.admits AS 'readmission_admits'	-- different from admits? -- 2017-05-04
	, readmits.readmits	-- 2017-05-04
	, claims_net.sum_cl_net AS 'sum_net'
	, claims_net.sum_cl_qty AS 'sum_qty'
	, GETDATE() AS 'CREATEDATE'
	, (SELECT MAX(DATETO) FROM CCAMIS_CURRENT.dbo.ez_claims) AS 'max_DATETO'
--INTO #selected_stats
-- SELECT *
INTO Medical_Analytics.dbo.member_selected_stats --FROM #selected_stats
--INTO Medical_Analytics.dbo.member_selected_stats_all_years
FROM select_memb_mm
LEFT JOIN ip
	ON select_memb_mm.member_ID = ip.member_id
	AND select_memb_mm.member_month = ip.member_month
LEFT JOIN claims_net
	ON select_memb_mm.member_ID = claims_net.member_id
	AND select_memb_mm.member_month = claims_net.member_month
LEFT JOIN obs
	ON select_memb_mm.member_ID = obs.member_id
	AND select_memb_mm.member_month = obs.member_month
LEFT JOIN ed
	ON select_memb_mm.member_ID = ed.member_id
	AND select_memb_mm.member_month = ed.member_month
LEFT JOIN med
	ON select_memb_mm.member_ID = med.member_id
	AND select_memb_mm.member_month = med.member_month
LEFT JOIN rx
	ON select_memb_mm.member_ID = rx.member_id
	AND select_memb_mm.member_month = rx.member_month
LEFT JOIN adm
	ON select_memb_mm.member_ID = adm.member_id
	AND select_memb_mm.member_month = adm.member_month
LEFT JOIN readmits -- 2017-05-04
	ON select_memb_mm.member_ID = readmits.member_id
	AND select_memb_mm.member_month = readmits.member_month
CREATE INDEX memb_mm ON Medical_Analytics.dbo.member_selected_stats (member_ID, member_month)
--CREATE INDEX memb_mm ON Medical_Analytics.dbo.member_selected_stats_all_years (member_ID, member_month)
PRINT ' 1888210 rows   Medical_Analytics.dbo.member_selected_stats'  -- 2017-04-03-0945
-- SELECT * FROM #selected_stats ORDER BY member_ID, member_month
-- SELECT * FROM Medical_Analytics.dbo.member_selected_stats ORDER BY member_ID, member_month
-- SELECT TOP 1 CREATEDATE FROM Medical_Analytics.dbo.member_selected_stats

skip_selected_stats:


-- #enr_mo_counts: this shows the month count (ascending and descending) of each enrollment span and of overall enrollment

IF OBJECT_ID('tempdb..#enr_mo_counts') IS NOT NULL GOTO skip_enr_mo_counts

-- DROP TABLE #enr_mo_counts
; WITH meh_mm_range AS ( -- range of EP dates used for MEH
	SELECT
		  MAX(CASE WHEN SeqNo = 1 THEN CAST(MonthBeginDateTime AS DATE) END) AS 'mm_min'
		, MAX(CASE WHEN RelMo = 1 THEN CAST(MonthBeginDateTime AS DATE) END) AS 'mm_max'
	-- SELECT *
	FROM #month_list
), enr_spans AS (
		SELECT -- enrollment spans which ended before the beginning of the MEH date range; total pre-MEH member months
			mehay.CCAID
			, mehay.enr_span_start
			, mehay.enr_span_end
			, DATEADD(DD, -DAY(mehay.enr_span_end) + 1, mehay.enr_span_end) AS 'enr_span_end_mm'
			, DATEDIFF(MM, mehay.enr_span_start, mehay.enr_span_end) + 1 AS 'enr_span_mm'
		FROM Medical_Analytics.dbo.member_enrollment_history_all_years AS mehay
		, meh_mm_range
		WHERE mehay.enr_span_end < meh_mm_range.mm_min
		GROUP BY
			mehay.CCAID
			, mehay.enr_span_start
			, mehay.enr_span_end
	UNION ALL
		SELECT -- enrollment spans from the MEH date range; total MEH member months
			s2.CCAID
			, s2.enr_span_start
			, s2.enr_span_end
			, CASE WHEN DATEDIFF(MM, s2.enr_span_end, meh_mm_range.mm_max) > 0 THEN DATEADD(DD, -DAY(s2.enr_span_end) + 1, s2.enr_span_end) ELSE meh_mm_range.mm_max END AS 'enr_span_end_mm'
			, DATEDIFF(MM, s2.enr_span_start, CASE WHEN DATEDIFF(MM, s2.enr_span_end, meh_mm_range.mm_max) > 0 THEN s2.enr_span_end ELSE meh_mm_range.mm_max END) + 1 AS 'enr_span_mm'
		-- SELECT *
		FROM #status AS s2
		, meh_mm_range
		WHERE s2.enr_span_start IS NOT NULL
			AND s2.ep_enroll_pct = 1 -- added 2017-06-02 to keep ranges within EP
		GROUP BY
			s2.CCAID
			, s2.enr_span_start
			, s2.enr_span_end
			, meh_mm_range.mm_max
), enr_mm AS ( -- total member months
	SELECT
		enr_spans.CCAID
		, SUM(enr_spans.enr_span_mm) AS 'enr_mm'
	FROM enr_spans
	GROUP BY
		enr_spans.CCAID
), enr_spans_latest_MP AS (
	SELECT
		s3.CCAID
		, MAX(s3.enr_span_start) AS 'enr_span_start_MP'
		, MAX(s3.member_month) AS 'enr_span_end_MP'
	FROM #status AS s3
	WHERE s3.MP_enroll = 1-- AND CCAID = 5365561731
	GROUP BY
		s3.CCAID
)
SELECT
	s1.CCAID
	, s1.member_month
	--, s1.enr_span_start
	--, s1.enr_span_end
	, DATEDIFF(MM, enr_spans.enr_span_start, s1.member_month) + 1 AS 'enr_mo_span'
	, DATEDIFF(MM, s1.member_month, enr_spans.enr_span_end_mm) + 1 AS 'latest_enr_mo_span'
	--, enr_spans.enr_span_mm
	--, enr_mm.enr_mm
	--, SUM(COALESCE(enr_spans_prior.enr_span_mm, 0)) AS 'prior_mm'
	, DATEDIFF(MM, enr_spans.enr_span_start, s1.member_month) + 1 + SUM(COALESCE(enr_spans_prior.enr_span_mm, 0)) AS 'enr_mo'
	, enr_mm.enr_mm - (DATEDIFF(MM, enr_spans.enr_span_start, s1.member_month) + 1 + SUM(COALESCE(enr_spans_prior.enr_span_mm, 0))) + 1 AS 'latest_enr_mo'
	, DATEDIFF(MM, s1.member_month, enr_spans_latest_MP.enr_span_end_MP) + 1 AS 'latest_enr_mo_span_MP'
INTO #enr_mo_counts
FROM #status AS s1
LEFT JOIN enr_spans
	ON s1.CCAID = enr_spans.CCAID
	AND s1.enr_span_start = enr_spans.enr_span_start
LEFT JOIN enr_mm
	ON s1.CCAID = enr_mm.CCAID
LEFT JOIN enr_spans AS enr_spans_prior
	ON s1.CCAID = enr_spans_prior.CCAID
	AND DATEDIFF(DD, enr_spans_prior.enr_span_end, s1.enr_span_start) > 0
LEFT JOIN enr_spans_latest_MP
	ON s1.CCAID = enr_spans_latest_MP.CCAID
	AND s1.member_month BETWEEN enr_spans_latest_MP.enr_span_start_MP AND enr_spans_latest_MP.enr_span_end_MP
WHERE s1.enr_span_start IS NOT NULL
	--AND s1.CCAID IN (5364521037, 5365554849, 5364521057, 5364521059, 5364521060, 5364521169, 5364521169)
	--AND s1.CCAID IN (5365561659, 5365561731)-- AND s1.member_month >= '2017-01-01'
GROUP BY
	s1.CCAID
	, s1.member_month
	, s1.enr_span_start
	, s1.enr_span_end
	, enr_spans.enr_span_start
	, enr_spans.enr_span_end_mm
	, enr_spans.enr_span_mm
	, enr_mm.enr_mm
	, enr_spans_latest_MP.enr_span_end_MP
ORDER BY
	CCAID
	, member_month
-- SELECT * FROM #enr_mo_counts ORDER BY CCAID, member_month
-- SELECT COUNT(*) FROM #enr_mo_counts
-- SELECT * FROM #enr_mo_counts WHERE CCAID IN (5364521037, 5365554849, 5364521056, 5364521057, 5364521059, 5364521060, 5364521169, 5364522098) ORDER BY CCAID, member_month
-- SELECT * FROM #enr_mo_counts WHERE CCAID IN (5365561731) ORDER BY CCAID, member_month

skip_enr_mo_counts:


-- #roster: this shows enrollment, provider, and address history for any member in any month since the beginning of the five years

IF OBJECT_ID('tempdb..#roster') IS NOT NULL DROP TABLE #roster

SELECT
	s.member_month
	, m.RelMo -- moved 2017-02-27
	--, s.MP_enroll
	, CASE WHEN s.member_month > s.latest_start THEN NULL ELSE s.MP_enroll END AS 'MP_enroll'
	, s.ep_enroll_pct AS 'EP_enroll'
	, s.member_ID
	, s.CCAID
	, s.NAME_ID
	, hcfa.HIC_NUMBER											-- CMS
	, hcfa.HICN_trim											-- CMS -- this is the same as HIC_NUMBER but with non-printing characters removed from the right
	, hcfa.HICN_9
	, hcfa.HICN_type
	, McareID.[Description] AS 'HICN_type_descr'
	, mi.MMISID													-- MassHealth
	, n.SOC_SEC
	, s.enr_span_start
	, s.enr_span_end
	, s.Product
	, contr.ContractNumber
	--, contr.DisplayName
	, aea.PROGRAM_ID
-- enroll_status  -- member has an open enrollment span in MP
-- enroll_status2 -- enroll status flagged for deaths
-- enroll_status3 -- enroll status flagged for deaths (flagged by source) -- see email to Clif, et al, 2017-05-03, for further explanation
	, s.enroll_status
	, CASE WHEN COALESCE(n.DATE1, hcfa.DEATH_DATE, memb.date_of_death) IS NULL THEN s.enroll_status ELSE 'not current member' END AS 'enroll_status2'
	, CASE WHEN COALESCE(n.DATE1, hcfa.DEATH_DATE, memb.date_of_death) IS NOT NULL
		THEN 'Dead '
			+ RTRIM(
				CASE WHEN n.DATE1 IS NOT NULL THEN '(MP) ' ELSE '' END
				+ CASE WHEN hcfa.DEATH_DATE IS NOT NULL THEN '(HCFA) ' ELSE '' END
				+ CASE WHEN memb.date_of_death IS NOT NULL THEN '(member table) ' ELSE '' END
			)
		ELSE s.enroll_status END AS 'enroll_status3'
	, s.SCO_passive_flag
	, s.ep_Dual AS 'Dual'
	, s.ep_RC AS 'RC'
	, s.MP_Dual
	, s.MP_RC
	, UPPER(s.ep_Class) AS 'Class'
	, s.ep_rating_category AS 'rating_category'

	, s.part_c_risk_score
	, s.part_d_risk_score

	, s.medicaid_premium
	, s.medicare_part_c_premium
	, s.medicare_part_d_premium
	, s.medicare_part_d_lics
	, s.medicare_part_d_reins
	, s.medicare_revenue_total
	, s.total_premium

	, memb.Assignment
	, REPLACE(REPLACE(REPLACE(RTRIM(n.NAME_FIRST), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'NAME_FIRST'
	, CASE WHEN SUBSTRING(n.NAME_MI, 2, 1) = '.' THEN LEFT(n.NAME_MI, 1)
		ELSE REPLACE(REPLACE(REPLACE(COALESCE(RTRIM(n.NAME_MI), ''), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') END AS 'NAME_MI'
	, REPLACE(REPLACE(REPLACE(RTRIM(n.NAME_LAST), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'NAME_LAST'
	, CAST(n.BIRTH_DATE AS DATE) AS 'DOB'
	, CAST(COALESCE(n.DATE1, hcfa.DEATH_DATE, memb.date_of_death) AS DATE) AS 'DOD' -- changed per David Browne 2016-06-27-1351
	, n.GENDER

	, COALESCE(e.TEXT23, 'Missing') AS 'lang_spoken'
	, CASE WHEN e.TEXT23 = 'English'			THEN 'English'
		WHEN e.TEXT23 = 'Cantonese'				THEN 'Chinese'
		WHEN e.TEXT23 = 'Chinese'				THEN 'Chinese'
		WHEN e.TEXT23 = 'Mandarin'				THEN 'Chinese'
		WHEN e.TEXT23 = 'Spanish'				THEN 'Spanish'
		WHEN e.TEXT23 = 'Spanish; Castilian'	THEN 'Spanish'
		WHEN e.TEXT23 = 'Undetermined'			THEN 'Unknown'
		WHEN e.TEXT23 = 'Unknown'				THEN 'Unknown'
		ELSE 'Missing' END AS 'lang_spoken_group' -- taken from HEDIS 2016 query

	, COALESCE(e.TEXT6, 'Missing') AS 'lang_written'
	, CASE WHEN e.TEXT6 = 'English'				THEN 'English'
		WHEN e.TEXT6 = 'Cantonese'				THEN 'Chinese'
		WHEN e.TEXT6 = 'Chinese'				THEN 'Chinese'
		WHEN e.TEXT6 = 'Mandarin'				THEN 'Chinese'
		WHEN e.TEXT6 = 'Spanish'				THEN 'Spanish'
		WHEN e.TEXT6 = 'Spanish; Castilian'		THEN 'Spanish'
		WHEN e.TEXT6 = 'Undetermined'			THEN 'Unknown'
		WHEN e.TEXT6 = 'Unknown'				THEN 'Unknown'
		ELSE 'Missing' END AS 'lang_written_group' -- taken from HEDIS 2016 query

	, COALESCE(e.TEXT7, 'Missing') AS 'race'
	, CASE WHEN e.TEXT7 = 'American Indian/Alaska Native'				THEN 'American Indian or Alaska Native'
		WHEN e.TEXT7 = 'Asian'											THEN 'Asian'
		WHEN e.TEXT7 = 'Black'											THEN 'Black or African American'
		WHEN e.TEXT7 = 'Caucasian'										THEN 'White'
		WHEN e.TEXT7 = 'Hispanic'										THEN 'Other Race'
		WHEN e.TEXT7 = 'Indian'											THEN 'Other Race'
		WHEN e.TEXT7 = 'Native Hawaii or Other Pacific Islander'		THEN 'Native Hawaiian or Other Pacific Islander'
		WHEN e.TEXT7 = 'Native Hawaiian or Other Pacific Islander'		THEN 'Native Hawaiian or Other Pacific Islander'
		WHEN e.TEXT7 = 'Other'											THEN 'Other Race'
		WHEN e.TEXT7 = 'Refuse to report'								THEN 'Declined'
		WHEN e.TEXT7 = 'Unknown'										THEN 'Unknown Race'
		WHEN e.TEXT7 = 'White'											THEN 'White'
		ELSE 'Unknown Race' END AS 'race_group' -- taken from HEDIS 2016 query

	, COALESCE(e.TEXT9, 'Missing') AS 'ethnicity'
	, CASE WHEN e.TEXT9 = 'Hispanic or Latino'		THEN 'Hispanic or Latino'
		WHEN e.TEXT9 = 'Not Hispanic or Latino'		THEN 'Not Hispanic or Latino'
		WHEN e.TEXT9 = 'Refuse to report'			THEN 'Declined'
		WHEN e.TEXT9 = 'Unknown'					THEN 'Unknown'
		ELSE 'Unknown' END AS 'ethnicity_group' -- taken from HEDIS 2016 query

	, COALESCE(e.TEXT8, 'Missing') AS 'marital'
	, CASE WHEN e.TEXT8 = 'Divorced'				THEN 'Single'
		WHEN e.TEXT8 = 'Legally Separated' 			THEN 'Unknown'
		WHEN e.TEXT8 = 'Married' 					THEN 'Married'
		WHEN e.TEXT8 = 'Never Married' 				THEN 'Single'
		WHEN e.TEXT8 = 'Other' 						THEN 'Unknown'
		WHEN e.TEXT8 = 'Separated' 					THEN 'Unknown'
		WHEN e.TEXT8 = 'Single' 					THEN 'Single'
		WHEN e.TEXT8 = 'Unknown' 					THEN 'Unknown'
		WHEN e.TEXT8 = 'Unmarried' 					THEN 'Single'
		WHEN e.TEXT8 = 'Unreported' 				THEN 'Unknown'
		WHEN e.TEXT8 = 'Widow' 						THEN 'Single'
		WHEN e.TEXT8 = 'Widowed' 					THEN 'Single'
		ELSE 'Unknown' END AS 'marital_group' -- taken from HEDIS 2016 query

	, COALESCE(cme.CareManagementEntityGroup, '') AS 'CMO_group'

	, prov.PCP
	, prov.PCP_ID
	, prov.CactusPCPprovK
	, prov.PCP_NPI
	, npi.NPI AS 'X_NPI'
	, prov.PCL
	, prov.PCL_ID
	, prov.CactusPCLprovK
	, prov.PCL_NPI
	, CASE WHEN RTRIM(npi_pcl.NPI) = '' THEN NULL ELSE npi_pcl.NPI END AS 'prov_NPI' -- added 2016-11-28
	, CASE WHEN RTRIM(npi_pcl.TAXIDNUMBER) = '' THEN NULL ELSE npi_pcl.TAXIDNUMBER END AS 'prov_taxID' -- added 2016-11-28
	, prov.CMO

	-- manual SCMO ID fix:
	, CASE WHEN prov.CMO = 'SCMO' AND s.Product = 'SCO' THEN 'N00018707741'
		ELSE prov.CMO_ID END AS 'CMO_ID'

	, prov.CM
	, prov.CM_ID

	, prov.LTSC_AGENCY_name		-- added 2016-12-15
	, prov.LTSC_AGENCY_ID		-- added 2016-12-15

	, prov.ASAP_name		-- added 2017-05-22
	, prov.ASAP_ID			-- added 2017-05-22

	, prov.CareModel_name		-- added 2017-09-21
	, prov.CareModel_ID			-- added 2017-09-21

	, prov.cap_site
	, prov.cap_site_ID
	, CASE WHEN prov.cap_site IN (
			'BIDJP Subacute'
			, 'BUGS'
			, 'East Boston'
			, 'Element Care'
			, 'Uphams Corner'
		) AND s.Product = 'SCO'
		THEN 'delegated'
		END AS 'cap_site_flag'

	, prov.care_mgmt
	, prov.care_mgmt_ID

	, prov.contract_entity
	, prov.contract_entity_ID

	, prov.summary_name
	, prov.site_name

	, pv.REV_FULLNAME -- added 2016-11-28

	--, s.MonthsSinceEnrolled
	--, s.TotalEnrollmentMonth

	--, memb_max_mo.max_mo - s.TotalEnrollmentMonth + 1 AS 'latest_enr_mo_LEGACY'
	--, s.ContinuousEnrollmentMonth

	, enr.enr_mo_span			-- month count of current enrollment span				-- to latest month in EP (=max)
	, enr.latest_enr_mo_span	-- month count of current enrollment span (descending)	-- to latest month in EP (=1)
	, enr.enr_mo				-- month count of enrollment in Product					-- to latest month in EP (=max)
	, enr.latest_enr_mo			-- month count of enrollment in Product (descending)	-- to latest month in EP (=1)
	, enr.latest_enr_mo_span_MP	-- month count of current enrollment span (descending)	-- to latest month in MP (=1)	-- latest enrollment span only (the count is the same as latest_enr_mo_span for other spans)

	, m.[Year]
	, m.[Quarter]
	, m.[Month]
	, CASE WHEN MP_problems.CCAID IS NOT NULL THEN 'MP problem' END AS 'MP_problem'
	, addr.addr_priority
	, addr.ADDRESS1
	, addr.ADDRESS2
	, addr.CITY
	, addr.[STATE]
	, addr.ZIP
	, addr.ZIP_4
	, addr.COUNTRY
	, addr.COUNTY
	, fips.COUNTYFP AS 'County_FIPS'
	, addr.ZIP_ID
	, addr.[START_DATE] AS 'addr_start'
	, addr.END_DATE AS 'addr_end'
	, phone.[Phone number(s)] AS 'latest_phone'

	, ss.sum_net				-- average: $2,505 (SCO); $1,535 (ICO) -- too low?
	, ss.IP_net				-- average:   $448 (SCO);   $352 (ICO)
	--, ss.count_claims -- averages 7.6 claims per mm -- too high?
	--, ss.count_IPclaims -- identical to total_admits
	, ss.IP_days			-- average per 1000: 424.1 (SCO);  309.8 (ICO) -- checked against UM
	, ss.obs_claims				-- average per 1000: 165.0 (SCO);  135.1 (ICO) -- checked against UM
	, ss.ED_visits				-- average per 1000: 763.6 (SCO); 1451.4 (ICO) -- checked against UM
	, ss.readmission_admits	-- different from admits? -- 2017-05-04
	, ss.readmits -- 2017-05-04

	, GETDATE() AS 'CREATEDATE'
	, (SELECT MAX(UPDATE_DATE) FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP) AS 'MP_DATE'

INTO #roster
-- SELECT *
FROM #status AS s
LEFT JOIN #provider_list AS prov
	ON s.Member_ID = prov.Member_ID
	AND s.member_month = prov.member_month
--LEFT JOIN Medical_Analytics.dbo.CareManagementEntity_Records_add_crossref AS cme
--	ON s.CMO_ID = cme.prov_ID
LEFT JOIN #month_list AS m
	ON s.member_month = m.MonthBeginDateTime
--LEFT JOIN (
--	SELECT
--		s1.CCAID
--		, MAX(s1.TotalEnrollmentMonth) AS max_mo
--	FROM #status AS s1
--	GROUP BY
--		s1.CCAID
--) AS memb_max_mo
--	ON s.CCAID = memb_max_mo.CCAID
LEFT JOIN (
	-- problem member months:
	SELECT
		b.member_month
		, b.CCAID
		, COUNT(b.CCAID) AS 'count_mm'
	FROM #status AS b
	GROUP BY
		b.member_month
		, b.CCAID
	HAVING COUNT(b.CCAID) > 1
) AS MP_problems
	ON s.CCAID = MP_problems.CCAID
	AND s.member_month = MP_problems.member_month
LEFT JOIN MPSnapshotProd.dbo.NAME AS n
	ON s.NAME_ID = n.NAME_ID
	AND n.PROGRAM_ID <> 'XXX'
LEFT OUTER JOIN MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS e
	ON s.NAME_ID = e.[ENTITY_ID]
	AND e.APP_TYPE = 'MCAID'
LEFT JOIN (
	SELECT
		hcfa1.*
		, RTRIM(hcfa1.HIC_NUMBER) AS 'HICN_trim'
		, CASE WHEN ISNUMERIC(LEFT(hcfa1.HIC_NUMBER, 1)) = 1 THEN LEFT(hcfa1.HIC_NUMBER, 9) END AS 'HICN_9'
		, CASE WHEN ISNUMERIC(LEFT(hcfa1.HIC_NUMBER, 1)) = 1 THEN RTRIM(SUBSTRING(hcfa1.HIC_NUMBER, 10, 10)) END AS 'HICN_type'
	FROM ( -- 2017-01-23
		SELECT
			  NAME_ID
			, REPLACE(REPLACE(REPLACE(HIC_NUMBER, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'HIC_NUMBER'
			, DEATH_DATE
		FROM MPSnapshotProd.dbo.HCFA_NAME_ORG
	) AS hcfa1
) AS hcfa
	ON n.NAME_ID = hcfa.NAME_ID
LEFT JOIN Medical_Analytics.dbo.Medicare_ID_codes AS McareID
	ON hcfa.HICN_type = McareID.[Code]
-- SELECT * FROM CCAMIS_Common.dbo.members
LEFT JOIN CCAMIS_Common.dbo.CareManagementEntity_Records AS cme
	ON prov.CMO = cme.CareMgmtEntityDescription
LEFT JOIN CCAMIS_Common.dbo.members AS memb
	ON n.TEXT2 = memb.cca_id
	AND COALESCE(memb.date_of_death, '9999-12-31') > memb.date_of_birth  -- 2016-08-10 -- fixed to allow for NULL DODs
LEFT JOIN #member_addresses AS addr
	ON n.NAME_ID = addr.NAME_ID
	AND s.member_month BETWEEN addr.[START_DATE] AND COALESCE(addr.END_DATE, '9999-12-31')
LEFT JOIN Medical_Analytics.dbo.MA_cities_counties AS cty
	ON addr.CITY = cty.CITY
LEFT JOIN Medical_Analytics.dbo.FIPS_codes AS fips
	ON addr.COUNTY = fips.county1
	AND addr.[STATE] = fips.[STATE]
LEFT JOIN #all_member_phone_concatenated AS phone
	ON n.NAME_ID = phone.NAME_ID
INNER JOIN (
	SELECT
		s1.member_ID
		, s1.member_month
		, MIN(addr.addr_priority) AS 'pref_addr'
	FROM #status AS s1
	LEFT JOIN #member_addresses AS addr
		ON s1.NAME_ID = addr.NAME_ID
		AND s1.member_month BETWEEN addr.[START_DATE] AND COALESCE(addr.END_DATE, '9999-12-31')
	WHERE s1.mm_row_count = 1
	GROUP BY
		s1.member_ID
		, s1.member_month
) AS addr_limit
	ON s.member_ID = addr_limit.member_ID
	AND s.member_month = addr_limit.member_month
	AND (addr.addr_priority = addr_limit.pref_addr OR addr_limit.pref_addr IS NULL)
LEFT JOIN #cactusPCP AS npi
	ON prov.CactusPCPprovK = npi.Provider_K
	AND npi.PCP_flag = 1
LEFT JOIN #cactusPCP AS npi_pcl -- added 2016-11-28
	ON prov.CactusPCLprovK = npi_pcl.Provider_K
	--AND npi.PCP_flag IS NULL
LEFT JOIN EZCAP_DTS.dbo.PROV_COMPANY_V AS pv -- added 2016-11-28  --
	ON npi_pcl.NPI = pv.provid

--select member_id, CactusPCLprovK
--from #provider_list AS prov
--LEFT JOIN #cactusPCP AS npi_pcl -- added 2016-11-28
--	ON prov.CactusPCLprovK = npi_pcl.Provider_K
--GROUP BY  member_id, CactusPCLprovK

LEFT JOIN ( -- this has a duplicate row for CCAID 5365582795 -- 2017-02-14
	SELECT
		CCAID
		, MMISID
	FROM MPSNAPSHOTPROD.dbo.VwMP_MemberInfo
	WHERE CCAID IS NOT NULL
	GROUP BY
		CCAID
		, MMISID
	--HAVING COUNT(*) > 1
) AS mi
	ON s.CCAID = mi.CCAID
LEFT JOIN #kd_ALL_enroll_ALL AS aea
	ON s.CCAID = aea.CCAID
	AND s.member_month BETWEEN aea.EnrollStartDt AND aea.EnrollEndDt
LEFT JOIN CCAMIS_Common.dbo.ContractNumber AS contr
	ON s.Product = contr.Product
LEFT JOIN Medical_Analytics.dbo.member_selected_stats AS ss
	ON s.Member_ID = ss.Member_ID
	AND s.member_month = ss.member_month
LEFT JOIN #enr_mo_counts AS enr
	ON s.CCAID = enr.CCAID
	AND s.member_month = enr.member_month

WHERE s.mm_row_count = 1 -- this is here to eliminate duplicate rows caused by overlapping NAME_PROVIDER date ranges

ORDER BY
	s.CCAID
	, s.member_month

CREATE INDEX memb_mm ON #roster (member_ID, member_month)

DECLARE @warning_message2 AS VARCHAR(100)
DECLARE @rows_total AS INT
SET @rows_total = (SELECT COUNT(DISTINCT a.CCAID) * COUNT(DISTINCT a.member_month) FROM #ICOSCO_mm AS a)
SELECT @warning_message2 = ' ' + CAST(@rows_total AS VARCHAR(10)) + ' -> the correct number of rows'
PRINT @warning_message2
--PRINT ' 1566540 rows   #roster -- as of 2016-10-06-0852 --> this should be the same as the rows for #ICOSCO_mm and #all_enrollment'
--PRINT ' 1625640 rows   #roster -- as of 2016-10-21-1053 --> this should be the same as the rows for #ICOSCO_mm and #all_enrollment'
--PRINT ' 1783530 rows   #roster -- as of 2016-12-01-0934 --> this should be the same as the rows for #ICOSCO_mm and #all_enrollment'
-- SELECT * FROM #roster AS r ORDER BY member_ID, member_month
-- SELECT COUNT(*) FROM #roster AS r
-- SELECT * FROM #roster AS r WHERE r.MP_enroll = 1 AND r.RelMo = -1 ORDER BY member_ID, member_month
-- SELECT member_ID, member_month, COUNT(*) FROM #roster GROUP BY member_ID, member_month HAVING COUNT(*) > 1
-- SELECT CMO, CMO_ID, COUNT(*) FROM #roster AS r WHERE MP_enroll = 1 GROUP BY CMO, CMO_ID ORDER BY CMO, CMO_ID
-- SELECT * FROM #roster AS r WHERE member_ID = 1061761 ORDER BY member_ID, member_month
-- SELECT * FROM #roster AS r WHERE prov_NPI IS NOT NULL ORDER BY member_ID, member_month
-- SELECT * FROM #roster AS r WHERE enroll_status <> enroll_status2 ORDER BY member_ID, member_month
-- SELECT TOP 100 * FROM #roster AS r ORDER BY member_ID, member_month
-- SELECT lang_spoken, COUNT(DISTINCT CCAID) AS 'memb_count' FROM #roster AS r GROUP BY lang_spoken ORDER BY lang_spoken
-- SELECT lang_written, COUNT(DISTINCT CCAID) AS 'memb_count' FROM #roster AS r GROUP BY lang_written ORDER BY lang_written
-- SELECT member_month, Product, SUM(MP_Enroll), SUM(sum_net), SUM(IP_net), SUM(count_IPclaims), SUM(IP_days), SUM(obs_claims), SUM(ED_visits) FROM #roster AS r WHERE Product IS NOT NULL GROUP BY member_month, Product
-- SELECT * FROM #roster AS r WHERE CCAID = 5364522098 ORDER BY member_ID, member_month
/*
	SELECT
		ROW_NUMBER() OVER(PARTITION BY HICN_9 ORDER BY HICN_type) AS 'HICN_row',
		HIC_NUMBER, HICN_trim, HICN_9, HICN_type, HICN_type_descr
		, COUNT(DISTINCT CCAID) AS 'memb_count'
	FROM #roster AS r
	WHERE RelMo = 1 AND EP_enroll = 1
	GROUP BY HIC_NUMBER, HICN_trim, HICN_9, HICN_type, HICN_type_descr ORDER BY HIC_NUMBER, HICN_trim, HICN_9, HICN_type, HICN_type_descr
*/
-- SELECT prov_NPI, COUNT(DISTINCT CCAID) FROM #roster AS r WHERE RelMo = 1 AND EP_enroll = 1 GROUP BY prov_NPI ORDER BY prov_NPI
-- SELECT REV_FULLNAME, COUNT(DISTINCT CCAID) AS 'memb_count' FROM #roster AS r WHERE RelMo = 1 AND EP_enroll = 1 GROUP BY REV_FULLNAME ORDER BY REV_FULLNAME
-- SELECT prov_taxID, COUNT(DISTINCT CCAID) AS 'memb_count' FROM #roster AS r WHERE RelMo = 1 AND EP_enroll = 1 GROUP BY prov_taxID ORDER BY prov_taxID
-- SELECT PROGRAM_ID, COUNT(DISTINCT CCAID) AS 'memb_count' FROM #roster AS r WHERE RelMo = 1 AND EP_enroll = 1 GROUP BY PROGRAM_ID ORDER BY PROGRAM_ID
-- SELECT Product, CMO_group, CMO, PCL, cap_site, contract_entity, summary_name, site_name, COUNT(DISTINCT CCAID) AS 'memb_count' FROM #roster AS r WHERE RelMo = 1 AND EP_enroll = 1 GROUP BY Product, CMO_group, CMO, PCL, cap_site, contract_entity, summary_name, site_name
-- SELECT CCAID, member_month, Product, MonthsSinceEnrolled, TotalEnrollmentMonth, latest_enr_mo_LEGACY, ContinuousEnrollmentMonth, enr_mo_span, latest_enr_mo_span, enr_mo, latest_enr_mo, latest_enr_mo_span_MP FROM #roster AS r WHERE latest_enr_mo_LEGACY IS NOT NULL OR latest_enr_mo IS NOT NULL ORDER BY CCAID, member_month
-- SELECT CCAID, member_month, Product, TotalEnrollmentMonth, enr_mo FROM #roster AS r WHERE TotalEnrollmentMonth <> enr_mo AND (latest_enr_mo_LEGACY IS NOT NULL OR latest_enr_mo IS NOT NULL) ORDER BY CCAID, member_month
-- SELECT CCAID, member_month, Product, enr_span_start, enr_span_end, TotalEnrollmentMonth, enr_mo, latest_enr_mo_LEGACY, latest_enr_mo, ContinuousEnrollmentMonth, enr_mo_span, latest_enr_mo_span, latest_enr_mo_span_MP FROM #roster AS r WHERE CCAID IN (5364521037, 5365554849, 5364521056, 5364521057, 5364521059, 5364521060, 5364521169, 5364522098) AND (latest_enr_mo_LEGACY IS NOT NULL OR latest_enr_mo IS NOT NULL) ORDER BY CCAID, member_month


/*
SELECT Product, CMO, COUNT(DISTINCT CCAID) AS 'memb_count', MAX(member_month) AS 'mm_max' FROM #roster AS r WHERE EP_enroll = 1 AND CMO LIKE '%dorc%' GROUP BY Product, CMO
SELECT Product, PCL, COUNT(DISTINCT CCAID) AS 'memb_count', MAX(member_month) AS 'mm_max' FROM #roster AS r WHERE EP_enroll = 1 AND PCL LIKE '%dorc%' GROUP BY Product, PCL
SELECT Product, site_name, COUNT(DISTINCT CCAID) AS 'memb_count', MAX(member_month) AS 'mm_max' FROM #roster AS r WHERE EP_enroll = 1 AND site_name LIKE '%dorc%' GROUP BY Product, site_name
SELECT Product, summary_name, COUNT(DISTINCT CCAID) AS 'memb_count', MAX(member_month) AS 'mm_max' FROM #roster AS r WHERE EP_enroll = 1 AND summary_name LIKE '%dorc%' GROUP BY Product, summary_name
SELECT Product, contract_entity, COUNT(DISTINCT CCAID) AS 'memb_count', MAX(member_month) AS 'mm_max' FROM #roster AS r WHERE EP_enroll = 1 AND contract_entity LIKE '%dorc%' GROUP BY Product, contract_entity
SELECT Product, cap_site, summary_name, COUNT(DISTINCT CCAID) AS 'memb_count', MAX(member_month) AS 'mm_max' FROM #roster AS r WHERE EP_enroll = 1 AND cap_site LIKE '%dorc%' GROUP BY Product, cap_site, summary_name
SELECT CITY, COUNTY, STATE FROM #roster AS r GROUP BY CITY, COUNTY, STATE

SELECT Product, contract_entity, PCL, COUNT(DISTINCT CCAID) AS 'memb_count', MAX(member_month) AS 'mm_max' FROM #roster AS r
WHERE EP_enroll = 1
	AND Product = 'ICO'
	--AND contract_entity LIKE '%riverb%'
	--AND contract_entity = 'CE'
	AND PCL LIKE '%riverb%'
GROUP BY Product, contract_entity, PCL ORDER BY Product, contract_entity, PCL
*/


PRINT ''
PRINT 'Halted'
RETURN
SELECT 2 + 2 AS '2+2='


-- SELECT CareModel_name, CareModel_ID, Product, member_month, COUNT(DISTINCT CCAID) as 'member_count' FROM #roster WHERE MP_enroll IS NOT NULL GROUP BY CareModel_name, CareModel_ID, Product, member_month ORDER BY CareModel_name, CareModel_ID, Product, member_month
-- SELECT * FROM #roster WHERE CareModel_name IS NOT NULL ORDER BY CCAID, member_month
-- SELECT DISTINCT CCAID, Product, CareModel_name FROM #roster WHERE CareModel_name IS NOT NULL AND RelMo = 1 AND EP_enroll = 1 ORDER BY CCAID


/*
SELECT * FROM #roster WHERE member_ID = 3 AND member_month = '2016-09-01'
SELECT * FROM Medical_Analytics.dbo.member_enrollment_history WHERE member_ID = 3 AND member_month = '2016-09-01'
SELECT * FROM sandbox_BKeith.dbo.member_enrollment_history_backup WHERE member_ID = 3 AND member_month = '2016-09-01'
*/

/*
SELECT CMO, product, COUNT(CCAID) FROM #roster WHERE EP_enroll = 1 AND RelMo = 1 GROUP BY CMO, product ORDER BY product, CMO
SELECT CMO, product, COUNT(CCAID) FROM Medical_Analytics.dbo.member_enrollment_history WHERE EP_enroll = 1 AND RelMo = 1 GROUP BY CMO, product ORDER BY product, CMO
*/

/*
SELECT SUM(CCAID), COUNT(*), COUNT(DISTINCT CCAID), 'existing' FROM Medical_Analytics.dbo.member_enrollment_history
SELECT SUM(CCAID), COUNT(*), COUNT(DISTINCT CCAID), 'new' FROM #roster
*/

-- SELECT LTSC_AGENCY_name, LTSC_AGENCY_ID, product, SUM(EP_enroll) AS 'mm', COUNT(DISTINCT CCAID) AS 'memb' FROM #roster WHERE EP_enroll = 1 AND (LTSC_AGENCY_name IS NOT NULL OR LTSC_AGENCY_ID IS NOT NULL) GROUP BY LTSC_AGENCY_name, LTSC_AGENCY_ID, product ORDER BY LTSC_AGENCY_name, LTSC_AGENCY_ID, product
-- SELECT ASAP_name, ASAP_ID, product, SUM(EP_enroll) AS 'mm', COUNT(DISTINCT CCAID) AS 'memb' FROM #roster WHERE EP_enroll = 1 AND (ASAP_name IS NOT NULL OR ASAP_ID IS NOT NULL) GROUP BY ASAP_name, ASAP_ID, product ORDER BY ASAP_name, ASAP_ID, product

-->--> ••• <--<--
-- write tables to server
DROP TABLE		 sandbox_BKeith.dbo.member_enrollment_history_backup
SELECT * INTO	 sandbox_BKeith.dbo.member_enrollment_history_backup FROM Medical_Analytics.dbo.member_enrollment_history
-- SELECT TOP 1 CREATEDATE FROM #roster
-- SELECT TOP 1 'member_enrollment_history_backup_' + CAST(YEAR(CREATEDATE) AS VARCHAR(4)) + LEFT('00', 2 - LEN(MONTH(CREATEDATE))) + CAST(MONTH(CREATEDATE) AS VARCHAR(2)) + LEFT('00', 2 - LEN(DAY(CREATEDATE))) + CAST(DAY(CREATEDATE) AS VARCHAR(2)) + '_' + LEFT('00', 2 - LEN(DATEPART(HOUR, CREATEDATE))) + CAST(DATEPART(HOUR, CREATEDATE) AS VARCHAR(2)) + LEFT('00', 2 - LEN(DATEPART(MINUTE, CREATEDATE))) + CAST(DATEPART(MINUTE, CREATEDATE) AS VARCHAR(2)) FROM #roster
--DROP TABLE #roster2 SELECT * INTO #roster2 FROM Medical_Analytics.dbo.member_enrollment_history
DROP TABLE    Medical_Analytics.dbo.member_enrollment_history
SELECT * INTO Medical_Analytics.dbo.member_enrollment_history FROM #roster
CREATE INDEX memb_mm ON Medical_Analytics.dbo.member_enrollment_history (member_ID, member_month)
-- SELECT TOP 1 CREATEDATE FROM Medical_Analytics.dbo.member_enrollment_history
-->--> ••• <--<--

/*
SELECT * FROM Medical_Analytics.dbo.member_enrollment_history WHERE latest_enr_mo = 1 ORDER BY CCAID
SELECT * FROM #roster										  WHERE latest_enr_mo = 1 ORDER BY CCAID
*/

/*
EXEC Medical_Analytics.dbo.member_enrollment_history_5yr_daily_refresh

-- SELECT CCAID FROM Medical_Analytics.dbo.member_enrollment_history GROUP BY CCAID HAVING COUNT(DISTINCT NAME_ID) > 1 -- CCAID with more than one NAME_ID -- 2017-07-20

DECLARE @warning_message3 AS VARCHAR(100)
DECLARE @warning_message4 AS VARCHAR(100)
DECLARE @rows_target AS INT
DECLARE @rows_actual AS INT
SET @rows_target = (SELECT COUNT(DISTINCT meh.CCAID) * COUNT(DISTINCT meh.member_month) FROM Medical_Analytics.dbo.member_enrollment_history AS meh)
SET @rows_actual = (SELECT COUNT(*) FROM Medical_Analytics.dbo.member_enrollment_history)
SELECT @warning_message3 = 'There are ' + CAST(@rows_actual AS VARCHAR(10)) + ' rows in the table (' + CAST(@rows_target AS VARCHAR(10)) + ' rows expected.)'
SELECT @warning_message4 = CASE WHEN @rows_actual <> @rows_target THEN '--> ROW NUMBER MISMATCH! <--' ELSE 'Row count OK.' END
PRINT @warning_message3
PRINT @warning_message4

-- SELECT COUNT(*), COUNT(DISTINCT CCAID), MAX(CREATEDATE) FROM Medical_Analytics.dbo.member_enrollment_history
*/

/* -- Rx daily rejects:
SELECT MAX(snc.FileLoadDatetimestamp) FROM PDRIn.dbo.STG_Navitus_Claims AS snc WITH (NOLOCK) WHERE snc.PROCESSOR_ID LIKE '%dly%'

\\cca-fs1\groups\CrossFunctional\BI\Medical Analytics\Pharmacy\SR008910 pharmacy daily rejects\SR008910 Rx rejects template v6b.xlsx

EXEC Medical_Analytics.dbo.pharmacydailyrejects_20170926	-- backup copy of previous version (v6b)

\\cca-fs1\groups\CrossFunctional\BI\Medical Analytics\Pharmacy\SR008910 pharmacy daily rejects\SR008910 Rx rejects template v7.xlsx

EXEC Medical_Analytics.dbo.pharmacydailyrejects_v7			-- columns removed from final query but still includes all data pull (takes about two minutes to run)
EXEC Medical_Analytics.dbo.pharmacydailyrejects_simple		-- columns removed from final query and unnecessary data not pulled
EXEC Medical_Analytics.dbo.pharmacydailyrejects				-- same as pharmacydailyrejects_simple but without comments

*/

/* -- outgoing RN referrals

EXEC Medical_Analytics.dbo.outgoing_RN_referrals			-- SR011257 outgoing RN referrals, incl blank proc and selected spec 2017-09-14.sql -- Nicole Desaulnier

\\cca-fs1\groups\CrossFunctional\BI\Medical Analytics\Adhoc Requests\Desaulniers\SR011257 outgoing referrals template.xlsx

*/

/*
SELECT SUM(CCAID), COUNT(*), COUNT(DISTINCT CCAID), 'BACKUP' FROM sandbox_BKeith.dbo.member_enrollment_history_backup_20170224_0915
SELECT SUM(CCAID), COUNT(*), COUNT(DISTINCT CCAID), 'NEW' FROM Medical_Analytics.dbo.member_enrollment_history
SELECT MAX(member_month) AS 'mp_enroll_max', 'BACKUP' FROM sandbox_BKeith.dbo.member_enrollment_history_backup WHERE MP_enroll = 1
SELECT MAX(member_month) AS 'ep_enroll_max', 'BACKUP' FROM sandbox_BKeith.dbo.member_enrollment_history_backup WHERE EP_enroll = 1
SELECT MAX(member_month) AS 'mp_enroll_max', 'NEW' FROM Medical_Analytics.dbo.member_enrollment_history WHERE MP_enroll = 1
SELECT MAX(member_month) AS 'ep_enroll_max', 'NEW' FROM Medical_Analytics.dbo.member_enrollment_history WHERE EP_enroll = 1
*/



PRINT ''
PRINT 'Halted'
RETURN
SELECT 2 + 2 AS '2+2='



/*
SELECT * FROM #month_list
SELECT * FROM #kd_ALL_enroll_ALL ORDER BY CCAID, EnrollStartDt, EnrollEndDt
SELECT * FROM #kd_ALL_enroll ORDER BY CCAID, EnrollStartDt1, EnrollStartDt, EnrollEndDt
SELECT * FROM #ICOSCO_mm ORDER BY member_id, member_month
SELECT * FROM #all_enrollment ORDER BY member_ID, member_month
SELECT * FROM #member_addresses ORDER BY NAME_ID, addr_priority
SELECT * FROM #all_member_phone ORDER BY CCAID
SELECT * FROM #services_all ORDER BY member_ID, SERVICE_TYPE, EFF_DATE, TERM_DATE
SELECT * FROM #services ORDER BY member_ID, SERVICE_TYPE, EFF_DATE, TERM_DATE
SELECT * FROM #status ORDER BY CCAID, member_month
SELECT * FROM #provider_list ORDER BY Member_ID
SELECT * FROM #roster AS r ORDER BY member_ID, member_month
*/

/*
SELECT TOP 1000 * FROM Medical_Analytics.dbo.member_enrollment_history AS meh ORDER BY member_ID, member_month
*/

/* -- future development -- strange CMO IDs in MP:
SELECT CMO, CMO_ID, CMO_group, COUNT(*), COUNT(CMO_ID) FROM Medical_Analytics.dbo.member_enrollment_history AS meh GROUP BY CMO, CMO_ID, CMO_group ORDER BY CMO, CMO_ID, CMO_group
SELECT * FROM #services WHERE prov_id IN ('N00006235666', 'N00018705524', 'N00018705642', 'N00018705948') ORDER BY SERVICE_TYPE, prov_id
*/
SELECT TOP 1000 * FROM Medical_Analytics.dbo.member_enrollment_history AS meh WHERE member_ID = 1066010 ORDER BY member_ID, member_month

SELECT
	meh.*
FROM Medical_Analytics.dbo.member_enrollment_history AS meh
INNER JOIN ( -- members with more than one enrollment span (original)
	SELECT
		Member_ID
		, COUNT(Member_ID) AS 'memb_count'
		--, EnrollStartDt
		--, EnrollEndDt
	-- SELECT *
	FROM #KD_All_enroll_all
	GROUP BY
		Member_ID
		--, EnrollStartDt
		--, EnrollEndDt
	HAVING COUNT(Member_ID) > 1
) AS multi_enroll
	ON meh.Member_ID = multi_enroll.Member_ID
WHERE MP_enroll = 1 AND RelMo = 1 AND PCP IS NULL
ORDER BY
	member_ID
	, member_month

SELECT * FROM #kd_ALL_enroll ORDER BY CCAID, EnrollStartDt1, EnrollStartDt, EnrollEndDt

-- dead members who are still enrolled
/*
SELECT
	*
FROM Medical_Analytics.dbo.member_enrollment_history AS meh
WHERE DOD IS NOT NULL
	AND enroll_status = 'current member'
	AND RelMo = 1
ORDER BY member_ID, member_month
*/

-- HICN with non-printing characters
/*
SELECT *
FROM Medical_Analytics.dbo.member_enrollment_history AS meh
WHERE REPLACE(REPLACE(REPLACE(HICN_trim, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') <> HICN_trim
*/

/* -- members who are in EP but do not have a Product
SELECT
	*
FROM #roster AS meh
WHERE EP_enroll = 1
	AND Product IS NULL

SELECT
	*
FROM Medical_Analytics.dbo.member_enrollment_history AS meh
WHERE EP_enroll = 1
	AND Product IS NULL


; WITH problem_NAME_ID AS (
	SELECT
		NAME_ID
	FROM Medical_Analytics.dbo.member_enrollment_history AS meh
	WHERE EP_enroll = 1
		AND Product IS NULL
	GROUP BY
		NAME_ID
)
SELECT
	ds.VALUE AS 'Product'
	, n.PROGRAM_ID
	, n.NAME_ID
	, CAST(n.TEXT2 AS BIGINT) AS 'CCAID'
	, CAST(ds.[START_DATE] AS DATE) AS 'EnrollStartDt'
	, MAX(CAST(COALESCE(ds.END_DATE, '9999-12-30') AS DATE)) AS 'EnrollEndDt'  -- changed 2016-10-04
FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS a
INNER JOIN MPSnapshotProd.dbo.NAME AS n
	ON a.[ENTITY_ID] = n.NAME_ID
	AND a.APP_TYPE = 'MCAID'
INNER JOIN MPSnapshotProd.dbo.DATE_SPAN AS ds
	ON n.NAME_ID = ds.NAME_ID
	AND ds.COLUMN_NAME = 'name_text19'
	AND ds.VALUE IN ('ICO', 'SCO')
	AND ds.CARD_TYPE = 'MCAID App'
INNER JOIN problem_NAME_ID
	ON a.[ENTITY_ID] = problem_NAME_ID.NAME_ID
WHERE COALESCE(ds.END_DATE, '9999-12-30') > ds.[START_DATE]
	AND n.PROGRAM_ID <> 'XXX'
GROUP BY
	ds.VALUE
	, n.PROGRAM_ID
	, n.NAME_ID
	, n.TEXT2
	, a.TEXT1
	, ds.[START_DATE]
ORDER BY
	n.NAME_ID
	, ds.[START_DATE]

*/



