

-- care partner history from Guiding Care
IF OBJECT_ID('tempdb..#GCprimCM') IS NOT NULL DROP TABLE #GCPrimCM

; WITH CM_roles AS (
	/*	-- table builder: available roles
		SELECT DISTINCT
			r.ROLE_NAME
			, ', ' + CHAR(39) + r.ROLE_NAME + CHAR(39) AS 'for_SQL_IN_list'
			, ', (' + CHAR(39) + r.ROLE_NAME + CHAR(39) + ')' AS 'for_SQL_VALUE_list'
		FROM Altruista.dbo.PATIENT_DETAILS AS pd
		INNER JOIN Altruista.dbo.PATIENT_PHYSICIAN AS pp
			ON pd.PATIENT_ID = pp.PATIENT_ID
			AND pp.CARE_TEAM_ID = 1
		INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS cs
			ON pp.PHYSICIAN_ID = cs.MEMBER_ID
		INNER JOIN Altruista.dbo.[ROLE] AS r
			ON cs.ROLE_ID = r.ROLE_ID
			--AND r.IS_ACTIVE = 1
			--AND r.DELETED_ON IS NULL
		WHERE LEFT(pd.CLIENT_PATIENT_ID, 3) = '536'
		ORDER BY
			r.ROLE_NAME
	*/
	SELECT * FROM (
		VALUES 
		  ('Care Coordinator')
		, ('Clinical Support Coordinator')
		, ('CM Manager')
		, ('CM Manager and Clinical Reviewer')
		, ('Delegated Care Coordinator')
		, ('External Care Coordinator')
		--, ('Intake Coordinator')
		--, ('Member Services')
		--, ('Read Only')
		, ('UM Manager')
		, ('UM Manager and Clinical Reviewer')
		, ('UM Nurse')
		, ('UM Physician')
		, ('UM Physician and Clinical Reviewer')
		--, ('UM Review Specialist')
	) AS x (CM_roles)
), PrimCareStaff AS (
	SELECT
		pd.CLIENT_PATIENT_ID AS 'CCAID'
		, pd.PATIENT_ID
		, pp.PHYSICIAN_ID AS 'PhysID'
		, r.ROLE_NAME AS 'PhysRole'
		, cs.TITLE
		, cs.FIRST_NAME
		, cs.LAST_NAME
		, CASE WHEN cs.PRIMARY_PHONE NOT LIKE '000%'
			AND cs.PRIMARY_PHONE NOT LIKE '111%'
			AND cs.PRIMARY_PHONE NOT LIKE '123%'
			AND cs.PRIMARY_PHONE NOT LIKE '999%'
			AND COALESCE(RTRIM(cs.PRIMARY_PHONE), '') <> ''
			THEN cs.PRIMARY_PHONE
			END AS 'PRIMARY_PHONE'
		, CASE WHEN cs.PRIMARY_PHONE NOT LIKE '000%'
			AND cs.PRIMARY_PHONE NOT LIKE '111%'
			AND cs.PRIMARY_PHONE NOT LIKE '123%'
			AND cs.PRIMARY_PHONE NOT LIKE '999%'
			AND COALESCE(RTRIM(cs.PRIMARY_PHONE), '') <> ''
			THEN REPLACE(RTRIM(cs.PRIMARY_PHONE), '-', '')
			END AS 'PRIMARY_PHONE2'
		, CASE WHEN COALESCE(RTRIM(cs.ALTERNATE_PHONE), '') <> '' THEN cs.ALTERNATE_PHONE END AS 'ALTERNATE_PHONE'
		, CASE WHEN COALESCE(RTRIM(cs.MOBILE_PHONE), '') <> '' THEN cs.PRIMARY_PHONE END AS 'MOBILE_PHONE'
		, cs.PRIMARY_EMAIL
	FROM Altruista.dbo.PATIENT_DETAILS AS pd
	INNER JOIN Altruista.dbo.PATIENT_PHYSICIAN AS pp
		ON pd.PATIENT_ID = pp.PATIENT_ID
		AND pp.CARE_TEAM_ID = 1
		--AND pp.IS_ACTIVE = 1
		AND pp.DELETED_ON IS NULL
	INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS cs
		ON pp.PHYSICIAN_ID = cs.MEMBER_ID
	INNER JOIN Altruista.dbo.[ROLE] AS r
		ON cs.ROLE_ID = r.ROLE_ID
		--AND r.IS_ACTIVE = 1
		AND r.DELETED_ON IS NULL
	WHERE LEFT(pd.CLIENT_PATIENT_ID, 3) = '536'
		AND pd.DELETED_ON IS NULL
		AND r.ROLE_NAME IN (SELECT * FROM CM_roles)
		--	'Care Coordinator', 'CM Manager', 'Delegated Care Coordinator', 'UM Manager', 'UM Nurse'
		--	, 'Clinical Support Coordinator', 'CM Manager and Clinical Reviewer', 'External Care Coordinator', 'UM Manager and Clinical Reviewer', 'UM Physician'
		--	--, 'Intake Coordinator', 'Member Services', 'Read Only', 'UM Review Specialist'
		--)
), PrimCM AS (
	SELECT
		pd.CLIENT_PATIENT_ID AS 'CCAID'
		, pd.PATIENT_ID
		, mc.MEMBER_ID
		, mc.CREATED_ON AS 'PrimCPassignedDate'
		, CASE WHEN cs.LAST_NAME IS NULL AND cs.MIDDLE_NAME IS NOT NULL THEN cs.MIDDLE_NAME + ', ' + cs.FIRST_NAME
			ELSE cs.LAST_NAME + ', ' + cs.FIRST_NAME END AS 'PrimCareMgr'
		, cs.LAST_NAME
		, cs.FIRST_NAME
		, cs.MIDDLE_NAME
		, r.ROLE_NAME AS 'PrimCareMgrRole'
		, mc.CREATED_ON
	FROM Altruista.dbo.PATIENT_DETAILS AS pd
	INNER JOIN Altruista.dbo.MEMBER_CARESTAFF AS mc
		ON pd.PATIENT_ID = mc.PATIENT_ID
	INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS cs
		ON mc.MEMBER_ID = cs.MEMBER_ID
	INNER JOIN Altruista.dbo.[ROLE] AS r
		ON cs.ROLE_ID = r.ROLE_ID
		AND r.IS_ACTIVE = 1
		AND r.DELETED_ON IS NULL
	WHERE LEFT(pd.CLIENT_PATIENT_ID, 3) = '536'
		--AND mc.IS_ACTIVE = 1
		--AND mc.IS_PRIMARY = 1
		AND r.ROLE_NAME IN (SELECT * FROM CM_roles)
		--	'Care Coordinator', 'CM Manager', 'Delegated Care Coordinator', 'UM Manager', 'UM Nurse'
		--	, 'Clinical Support Coordinator', 'CM Manager and Clinical Reviewer', 'External Care Coordinator', 'UM Manager and Clinical Reviewer', 'UM Physician'
		--	--, 'Intake Coordinator', 'Member Services', 'Read Only', 'UM Review Specialist'
		--)
), GCprimCM_distinct AS (
	SELECT DISTINCT
		pc.CCAID
		, pc.PATIENT_ID
		, pc.MEMBER_ID AS 'PrimCareMgrID'
		, pc.PrimCareMgr
		, pc.PrimCareMgrRole
		, pcs.PhysID
		, pcs.PhysRole
		, pcs.FIRST_NAME
		, pcs.LAST_NAME
		, pcs.PRIMARY_PHONE
		, pcs.PRIMARY_PHONE2
		, pcs.ALTERNATE_PHONE
		, pcs.MOBILE_PHONE
		, pcs.PRIMARY_EMAIL
		, pc.PrimCPassignedDate
		, CASE WHEN pc.MEMBER_ID = pcs.PhysID THEN 'Y' ELSE 'N' END AS 'CMtoPhysMatch'
	FROM PrimCM AS pc
	LEFT JOIN PrimCareStaff AS pcs
		ON pc.CCAID = pcs.CCAID
		AND pc.MEMBER_ID = pcs.PhysID
), GCprimCM AS (
	SELECT
		*
		, DENSE_RANK() OVER (PARTITION BY CCAID ORDER BY CASE WHEN PrimCareMgrID = PhysID THEN 'Y' ELSE 'N' END DESC) AS 'PCMrank'
		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY CASE WHEN PrimCareMgrID = PhysID THEN 'Y' ELSE 'N' END DESC, PrimCPassignedDate) AS 'RowNo'			-- 1 = first
		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY CASE WHEN PrimCareMgrID = PhysID THEN 'Y' ELSE 'N' END DESC, PrimCPassignedDate DESC) AS 'RowNo_desc'	-- 1 = latest
	FROM GCprimCM_distinct
)
SELECT
	*
INTO #GCprimCM
FROM GCPrimCM
WHERE PCMrank = 1
	--AND RowNo = 1
PRINT '#GCprimCM'
CREATE UNIQUE INDEX CCAID_CMrow ON #GCprimCM (CCAID, RowNo)
-- SELECT * FROM #GCprimCM ORDER BY CCAID, RowNo
-- SELECT COUNT(*) FROM #GCprimCM		--69751
-- SELECT CCAID, COUNT(*) FROM #GCprimCM GROUP BY CCAID HAVING COUNT(*) > 1
-- SELECT MAX(PrimCPassignedDate) FROM #GCprimCM
-- SELECT * FROM #GCprimCM WHERE DAY(PrimCPassignedDate) <> 1 ORDER BY CCAID, RowNo


-- care partner phone and email
IF OBJECT_ID('tempdb..#CM_contact') IS NOT NULL DROP TABLE #CM_contact

SELECT DISTINCT
	PrimCareMgrID
	, PRIMARY_PHONE2
	, PRIMARY_EMAIL
INTO #CM_contact
FROM #GCprimCM
WHERE PRIMARY_EMAIL IS NOT NULL
PRINT '#CM_contact'
-- SELECT * FROM #CM_contact ORDER BY PrimCareMgrID
-- SELECT COUNT(*) FROM #CM_contact		--655
-- SELECT PrimCareMgrID FROM #CM_contact GROUP BY PrimCareMgrID HAVING COUNT(*) > 1 ORDER BY PrimCareMgrID


-- care manager member months
IF OBJECT_ID('tempdb..#cm_mm') IS NOT NULL DROP TABLE #cm_mm

; WITH member_cm_starts AS (
	SELECT DISTINCT
		CCAID
		, PrimCareMgrID AS 'CM_ID'
		, FIRST_NAME + ' ' + LAST_NAME AS 'CM'
		, PrimCareMgrRole AS 'CM_role'
		, CAST(PrimCPassignedDate AS DATE) AS 'CM_begin'
		, PrimCPassignedDate AS 'CM_begin_day_time'
	FROM #GCprimCM
), member_cm_starts_max_day AS (
	SELECT
		mcms1.CCAID
		, mcms1.CM_ID
		, mcms1.CM
		, mcms1.CM_role
		, mcms1.CM_begin
		, mcms1.CM_begin_day_time
	FROM member_cm_starts AS mcms1
	INNER JOIN member_cm_starts AS mcms2
		ON mcms1.CCAID = mcms2.CCAID
		AND mcms1.CM_begin = mcms2.CM_begin
	GROUP BY
		mcms1.CCAID
		, mcms1.CM_ID
		, mcms1.CM
		, mcms1.CM_role
		, mcms1.CM_begin
		, mcms1.CM_begin_day_time
	HAVING MAX(mcms2.CM_begin_day_time) = mcms1.CM_begin_day_time
), member_cm_rows AS (
	SELECT
		CCAID
		, CM_ID
		, CM
		, CM_role
		, CM_begin
		, ROW_NUMBER() OVER (PARTITION BY CCAID ORDER BY CM_begin) AS 'CM_row'
	FROM member_cm_starts_max_day
), member_cm_ends AS (
	SELECT
		mcmr1.*
		, COALESCE(DATEADD(DD, -1, mcmr2.CM_begin), '9999-12-30') AS 'CM_end'
	FROM member_cm_rows AS mcmr1
	LEFT JOIN member_cm_rows AS mcmr2
		ON mcmr1.CCAID = mcmr2.CCAID
		AND mcmr1.CM_row = mcmr2.CM_row - 1
)
SELECT
	mcme.CCAID
	, mcme.CM_ID
	, mcme.CM
	, mcme.CM_role
	, #CM_contact.PRIMARY_PHONE2 AS 'CM_phone'
	, #CM_contact.PRIMARY_EMAIL AS 'CM_email'
	, MIN(mcme.CM_begin) AS 'CM_begin'
	, MAX(mcme.CM_end) AS 'CM_end'
	--, MAX(mcme.CM_row) AS 'CM_row'
	, CAST(d.member_month AS DATE) AS 'member_month'
	, GETDATE() AS 'CREATEDATE'
	, (SELECT MAX(PrimCPassignedDate) FROM #GCprimCM) AS 'GC_DATE'
INTO #cm_mm
FROM member_cm_ends AS mcme
LEFT JOIN CCAMIS_Common.dbo.Dim_date AS d
	ON d.member_month BETWEEN mcme.CM_begin AND COALESCE(mcme.CM_end, DATEADD(MM, 4, GETDATE()))
LEFT JOIN #CM_contact
	ON mcme.CM_ID = #CM_contact.PrimCareMgrID
GROUP BY
	mcme.CCAID
	, mcme.CM_ID
	, mcme.CM
	, mcme.CM_role
	, #CM_contact.PRIMARY_PHONE2-- AS 'CM_phone'
	, #CM_contact.PRIMARY_EMAIL-- AS 'CM_email'
	, d.member_month
ORDER BY
	CCAID
	, CM_begin
	, member_month
PRINT '#cm_mm'
-- SELECT * FROM #cm_mm ORDER BY CCAID, member_month
-- SELECT COUNT(*) FROM #cm_mm		--952803
-- SELECT CCAID, member_month FROM #cm_mm GROUP BY CCAID, member_month HAVING COUNT(*) > 1 ORDER BY CCAID, member_month
-- SELECT DISTINCT CM_begin, CM_end FROM #cm_mm ORDER BY CM_begin, CM_end
-- SELECT * FROM #cm_mm WHERE MONTH(CM_begin) = MONTH(CM_end) AND YEAR(CM_begin) = YEAR(CM_end) ORDER BY CCAID, member_month
-- SELECT * FROM #cm_mm WHERE CCAID = 5365774977 ORDER BY CCAID, CM_begin, CM_end, member_month
-- SELECT * FROM #cm_mm WHERE CCAID = 5365707837 ORDER BY CCAID, CM_begin, CM_end, member_month




/*

-- SELECT * FROM #GCprimCM ORDER BY CCAID, RowNo
-- SELECT * FROM #cm_mm ORDER BY CCAID, member_month

DROP TABLE Medical_Analytics.dbo.member_GC_CM_history_backup
SELECT * INTO Medical_Analytics.dbo.member_GC_CM_history_backup FROM Medical_Analytics.dbo.member_GC_CM_history

DROP TABLE Medical_Analytics.dbo.member_GC_CM_history

SELECT
	*
INTO Medical_Analytics.dbo.member_GC_CM_history
FROM #cm_mm
ORDER BY
	 CCAID
	 , CM_begin
	 , member_month
CREATE UNIQUE INDEX memb_cp_start_mm ON Medical_Analytics.dbo.member_GC_CM_history (CCAID, CM_ID, CM_begin, member_month)

-- SELECT * FROM Medical_Analytics.dbo.member_GC_CM_history ORDER BY CCAID, member_month
-- SELECT TOP 1000 * FROM Medical_Analytics.dbo.member_GC_CM_history ORDER BY CCAID, member_month

*/

