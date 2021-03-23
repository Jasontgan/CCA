
SELECT
	ecw.encLock
	, ecw.enc_date AS 'Date'
	, ecw.StartTime AS 'Time'
	, ecw.VisitType AS 'Type'
	, ecw.VisitTypeDescr
	, ecw.[Status]
	--, RTRIM(ecw.Provider) AS 'Provider'
	--, RTRIM(ecw.[Resource]) AS 'Resource'
	, ecw.Provider
	, ecw.[Resource]
	, ecw.Reason
	, ecw.encounterID
	, ecw.CCAID
	, ecw.member_name
	, ecw.DOB
	, ecw.[uid] AS 'userID_eCW'
	, meh.CM AS 'CM from MP (mm)'
	, ecw.CM_eCW AS 'CM from eCW'
	, meh.CMO AS 'CMO from MP (mm)'
	, ecw.CMO_eCW AS 'CMO from eCW'
	, meh.PCP AS 'PCP from MP (mm)'
/*
	, ecw.CareModel_eCW
*/
	, ecw.printname	AS 'Provider_printname'

	-- provider data:
	--, ecw.umobileno
	--, ecw.upagerno
	--, ecw.ufname
	--, ecw.uminitial
	--, ecw.ulname
	--, ecw.uemail
	--, ecw.upaddress
	--, ecw.upcity
	--, ecw.upstate
	--, ecw.upPhone
	--, ecw.UserType
	--, ecw.zipcode
	, ecw.initials AS 'Credentials'
	--, ecw.primaryservicelocation

FROM OPENQUERY(ECW, '
	SELECT DISTINCT
		p.hl7id AS CCAID
		, e.encLock
		, CAST(e.Date AS DATE) AS enc_date
		, e.StartTime
		, e.VisitType
		, e.Status
		, RTRIM(CONCAT(du.ulname, '', '', du.ufname, '' '', du.uminitial)) AS Provider
		, RTRIM(COALESCE(CONCAT(ru.ulname, '', '', ru.ufname, '' '', ru.uminitial), '''')) AS Resource
		, e.Reason
		, u.uid
        , vc.description AS VisitTypeDescr
		, dem_cm.value AS CM_eCW
		, dem_cmo.value AS CMO_eCW
/*
		, dem_cmdl.value AS CareModel_eCW
*/
		, d.printname

		, du.umobileno
		, du.upagerno
		, du.ufname
		, du.uminitial
		, du.ulname
		, du.uemail
		, du.upaddress
		, du.upcity
		, du.upstate
		, du.upPhone
		, du.UserType
		, du.zipcode
		, du.initials
		, du.primaryservicelocation

		, RTRIM(CONCAT(u.ulname, '', '', u.ufname, '' '', u.uminitial)) AS member_name
		, u.dob
		, e.encounterID

	FROM users AS u
	INNER JOIN patients AS p
		ON u.uid = p.pid
	INNER JOIN enc AS e
		ON u.uid = e.patientid
		AND e.deleteflag = 0
/*		AND e.visitType IN (''MDS Face'', ''MDS Teleph'', ''MDS Visit'', ''HANNUAL'', ''OANNUAL'', ''ANNUAL'')		*/
/*		AND e.visitType NOT IN (''CMR'', ''CONF'', ''MDS Proxy'', ''COCTEL'', ''EXTCOMM'')	*//*	non-face-to-face visits?	*/
	INNER JOIN doctors AS d
		ON e.doctorID = d.doctorID
	LEFT JOIN visitcodes AS vc
		ON e.VisitType = vc.name
	LEFT JOIN users AS du
		ON d.doctorID = du.uid
	LEFT JOIN doctors AS r
		ON e.resourceID = r.doctorID
	LEFT JOIN users AS ru
		ON r.doctorID = ru.uid

	LEFT JOIN structdemographics AS dem_cm
		ON p.pid = dem_cm.patientId
		AND dem_cm.deleteflag = 0
	INNER JOIN structdatadetail AS d_cm
		ON dem_cm.detailId = d_cm.Id
		AND d_cm.tblName = ''structDemographics''
		AND d_cm.name = ''Care Manager''

	LEFT JOIN structdemographics AS dem_cmo
		ON p.pid = dem_cmo.patientId
		AND dem_cmo.deleteflag = 0
	INNER JOIN structdatadetail AS d_cmo
		ON dem_cmo.detailId = d_cmo.Id
		AND d_cmo.tblName = ''structDemographics''
		AND d_cmo.name = ''Care Management Organization ''

/*	-- Care Model does not work
	LEFT JOIN structdemographics AS dem_cmdl
		ON p.pid = dem_cmdl.patientId
		AND dem_cmdl.deleteflag = 0
	INNER JOIN structdatadetail AS d_cmdl
		ON dem_cmdl.detailId = d_cmdl.Id
		AND d_cmdl.tblName = ''structDemographics''
		AND d_cmdl.name = ''Care Model''
*/

	WHERE e.Date >= ''2013-10-01'' AND p.hl7id = ''5364524431''		
/*	WHERE e.Date  = ''2017-12-15'' AND p.hl7id BETWEEN ''5364521037'' AND ''5369999999''		*/
/*	WHERE u.uid IN (39303688, 9123)		*/
') AS ecw
INNER JOIN CCAMIS_Common.dbo.Dim_date AS d
	ON ecw.enc_date = d.[Date]
INNER JOIN Medical_Analytics.dbo.member_enrollment_history AS meh
	ON ecw.CCAID = meh.CCAID
	AND d.member_month = meh.member_month
ORDER BY
	ecw.CCAID
	, enc_date DESC
	, ecw.StartTime DESC
	, ecw.VisitType DESC


/*	-- all structdemographics for one user
	SELECT
		*
	FROM OPENQUERY(ECW, '
		SELECT
			dem.*
			, sdd.name
		FROM structdemographics AS dem
		LEFT JOIN structdatadetail AS sdd
			ON dem.detailId = sdd.Id
		WHERE dem.patientId = 3253001
	')
*/

/*	-- all name values from structdatadetail for table structdemographics
	SELECT
		*
	FROM OPENQUERY(ECW, '
		SELECT DISTINCT
			Id
			, name
		FROM structdatadetail AS s
		WHERE s.tblName = ''structDemographics''
		/*
			AND name = ''Care Manager''
		*/
		/*
			AND name LIKE ''%PCP%''
		*/
	')
*/


/*	-- only two members (as of 2018-01-03) have Care Models:
	SELECT
		*
	FROM OPENQUERY(ECW, '
		SELECT
			dem.patientId
		FROM structdemographics AS dem
		JOIN structdatadetail AS sdd
			ON dem.detailId = sdd.Id
			AND sdd.name = ''Care Model''
	')
*/


/*	-- all Care Managers
	SELECT
		ecw.*
	FROM OPENQUERY(ECW, '
		SELECT DISTINCT
			d_cm.name
			, dem_cm.value
		FROM structdemographics AS dem_cm
		INNER JOIN structdatadetail AS d_cm
			ON dem_cm.detailId = d_cm.Id
			AND d_cm.tblName = ''structDemographics''
			AND d_cm.name = ''Care Manager''
	') AS ecw
*/


-- eCW care managers matched to MP care managers
; WITH standard_name AS (
	SELECT
		ecw.name
		, ecw.value
		--ecw.*
		--, CASE WHEN ecw.name_only = 'SCMO' THEN 'SCMO'
		--	ELSE COALESCE(LEFT(ecw.name_wcomma_only, CHARINDEX(',', ecw.name_wcomma_only) - 1), LEFT(ecw.name_wspace_only, CHARINDEX(' ', ecw.name_wspace_only) - 1), ecw.name_only)
		--	END AS 'NAME_FIRST'
		--, CASE WHEN ecw.name_only = 'SCMO' THEN 'SCMO'
		--	WHEN ecw.space_loc > 1 AND (ecw.space_loc < ecw.comma_loc OR ecw.comma_loc = 0) THEN LEFT(ecw.name_only, ecw.space_loc - 1)
		--	WHEN ecw.comma_loc > 1 THEN SUBSTRING(ecw.name_only, ecw.comma_loc + 2, 1000)
		--	ELSE ecw.name_only
		--	END AS 'NAME_FIRST'
		--, CASE WHEN ecw.space_loc > 1 AND (ecw.space_loc < ecw.comma_loc OR ecw.comma_loc = 0) THEN SUBSTRING(ecw.name_only, ecw.space_loc + 1, 1000)
		--	WHEN ecw.comma_loc > 1 THEN LEFT(ecw.name_only, ecw.comma_loc - 1)
		--	ELSE ecw.name_only
		--	END AS 'NAME_LAST'
		, CASE WHEN ecw.name_only = 'SCMO' THEN 'SCMO'
			ELSE CASE WHEN ecw.comma_loc > 1 THEN LEFT(ecw.name_only, ecw.comma_loc - 1)
			WHEN ecw.space_loc > 1 AND (ecw.space_loc < ecw.comma_loc OR ecw.comma_loc = 0) THEN SUBSTRING(ecw.name_only, ecw.space_loc + 1, 1000)
			ELSE ecw.name_only
			END-- AS 'NAME_LAST'
			+ ', ' +
			CASE WHEN ecw.comma_loc > 1 THEN SUBSTRING(ecw.name_only, ecw.comma_loc + 2, 1000)
			WHEN ecw.space_loc > 1 AND (ecw.space_loc < ecw.comma_loc OR ecw.comma_loc = 0) THEN LEFT(ecw.name_only, ecw.space_loc - 1)
			ELSE ecw.name_only
			END-- AS 'NAME_FIRST'
			END AS 'cm_name'
			
	FROM OPENQUERY(ECW, '
		SELECT DISTINCT
			d_cm.name
			, CAST(dem_cm.value AS CHAR(255)) AS value
			, CAST(CASE WHEN INSTR(dem_cm.value, '':'') > 1 THEN LEFT(dem_cm.value, INSTR(dem_cm.value, '':'') - 1) END AS CHAR(255)) AS name_only
			, CAST(CASE WHEN INSTR(dem_cm.value, '':'') > 1 AND INSTR(dem_cm.value, '','') <= 1 AND INSTR(dem_cm.value, '' '') > 1 THEN LEFT(dem_cm.value, INSTR(dem_cm.value, '':'') - 1) END AS CHAR(255)) AS name_wspace_only
			, CAST(CASE WHEN INSTR(dem_cm.value, '':'') > 1 AND INSTR(dem_cm.value, '','') > 1 THEN LEFT(dem_cm.value, INSTR(dem_cm.value, '':'') - 1) END AS CHAR(255)) AS name_wcomma_only
			, INSTR(CASE WHEN INSTR(dem_cm.value, '':'') > 1 THEN LEFT(dem_cm.value, INSTR(dem_cm.value, '':'') - 1) END, '' '') AS space_loc
			, INSTR(CASE WHEN INSTR(dem_cm.value, '':'') > 1 THEN LEFT(dem_cm.value, INSTR(dem_cm.value, '':'') - 1) END, '','') AS comma_loc
		FROM structdemographics AS dem_cm
		INNER JOIN structdatadetail AS d_cm
			ON dem_cm.detailId = d_cm.Id
			AND d_cm.tblName = ''structDemographics''
			AND d_cm.name = ''Care Manager''
	') AS ecw
), with_manual_fixes AS (
	SELECT
		name
		, value
		, CASE WHEN	cm_name = 'Hernandez Hernandez, Antonio'	THEN 'Hernandez, Antonio'
			WHEN	cm_name = 'Kelley, Cynthia'					THEN 'Kelley-Grady, Cynthia'
			WHEN	cm_name = 'Laforme, Pat'					THEN 'Laforme, Patricia'
			WHEN	cm_name = 'Malfroy- Camine, Evelyne'		THEN 'Malfroy-Camine, Evelyne'
			WHEN	cm_name = 'McDonnell-Lemoine, Molly'		THEN 'Lemoine, Molly'
			WHEN	cm_name = 'Staples, Erica'					THEN 'Staple, Erica'
			WHEN	cm_name = 'Weiss, Benjamin'					THEN 'Weiss, Ben'
			ELSE cm_name
			END AS 'cm_name'
	FROM standard_name
)
SELECT
	n.name
	, n.value
	, n.cm_name AS 'CM_eCW'
	, meh.CM AS 'CM_MP'
FROM with_manual_fixes AS n
LEFT JOIN (
	SELECT DISTINCT
		CM
	FROM Medical_Analytics.dbo.member_enrollment_history
	WHERE CM IS NOT NULL
) AS meh
	ON n.cm_name = meh.CM


/*	-- all Care Management Organizations
	SELECT
		ecw.*
	FROM OPENQUERY(ECW, '
		SELECT DISTINCT
			d_cmo.name
			, dem_cmo.value
		FROM structdemographics AS dem_cmo
		INNER JOIN structdatadetail AS d_cmo
			ON dem_cmo.detailId = d_cmo.Id
			AND d_cmo.tblName = ''structDemographics''
			AND d_cmo.name = ''Care Management Organization ''
	') AS ecw
*/


-- eCW CMOs matched to MP CMOs
; WITH standard_name AS (
	SELECT
		ecw.*
	FROM OPENQUERY(ECW, '
		SELECT DISTINCT
			d_cmo.name
			, CAST(dem_cmo.value AS CHAR(255)) AS value
			, CASE WHEN INSTR(dem_cmo.value, '':'') > 1 THEN LEFT(CAST(dem_cmo.value AS CHAR(255)), INSTR(dem_cmo.value, '':'') - 1) ELSE RTRIM(CAST(dem_cmo.value AS CHAR(255))) END AS cmo_name
		FROM structdemographics AS dem_cmo
		INNER JOIN structdatadetail AS d_cmo
			ON dem_cmo.detailId = d_cmo.Id
			AND d_cmo.tblName = ''structDemographics''
			AND d_cmo.name = ''Care Management Organization ''
	') AS ecw
), with_manual_fixes AS (
	SELECT
		name
		, value
		, CASE WHEN	cmo_name = 'Telephonic RN,                     '	THEN 'Telephonic RN'
			WHEN	cmo_name = 'CMO Brightwood Hlth Ctr-Bay'			THEN 'Brightwood Hlth Ctr-Bay'
			WHEN	cmo_name = 'CMO CCC-Framingham'						THEN 'CCC-Framingham'
			WHEN	cmo_name = 'SCMO SCMO'								THEN 'SCMO'
			WHEN	cmo_name = 'Long Term Care,                     '	THEN 'Long Term Care CMO'
			WHEN	cmo_name = 'CCC'									THEN 'CCC-Boston'
			WHEN	cmo_name = 'CMO CCC-Lawrence'						THEN 'CCC-Lawrence'
			WHEN	cmo_name = 'CMO CCC-Springfield'					THEN 'CCC-Springfield'
			ELSE cmo_name
			END AS 'cmo_name'
	FROM standard_name
)
SELECT
	n.name
	, n.value
	, n.cmo_name AS 'CMO_eCW'
	, meh.CMO AS 'CMO_MP'
FROM with_manual_fixes AS n
LEFT JOIN (
	SELECT DISTINCT
		CMO
	FROM Medical_Analytics.dbo.member_enrollment_history
	GROUP BY CMO
) AS meh
	ON n.cmo_name = meh.CMO


/*	-- eCW providers with name matches in MP
	SELECT DISTINCT
		ecw.*
		, MP_providers.NAME_FIRST
		, MP_providers.NAME_LAST

	FROM OPENQUERY(ECW, '
		SELECT DISTINCT
			d.doctorID AS doctorID
			, d.printname
			, du.ufname
			, du.uminitial
			, du.ulname
			, RTRIM(CONCAT(du.ulname, '', '', du.ufname, '' '', du.uminitial)) AS Provider
	/*
			, r.doctorID AS resourceID
			, r.printname
			, ru.ufname
			, ru.uminitial
			, ru.ulname
			, RTRIM(COALESCE(CONCAT(ru.ulname, '', '', ru.ufname, '' '', ru.uminitial), '''')) AS Resource
	*/
		FROM enc AS e
		INNER JOIN doctors AS d
			ON e.doctorID = d.doctorID
		LEFT JOIN users AS du
			ON d.doctorID = du.uid
	/*
		LEFT JOIN doctors AS r
			ON e.resourceID = r.doctorID
		LEFT JOIN users AS ru
			ON r.doctorID = ru.uid
	*/
		WHERE e.Date >= ''2013-10-01''	
			AND e.deleteflag = 0

	/*	WHERE e.Date  = ''2017-12-15'' AND p.hl7id BETWEEN ''5364521037'' AND ''5369999999''		*/
	/*	WHERE u.uid IN (39303688, 9123)		*/
	') AS ecw
	INNER JOIN (
		SELECT DISTINCT
			npn.NAME_FIRST
			, npn.NAME_MI
			, npn.NAME_LAST
			--, np.SERVICE_TYPE
		FROM MPSnapshotProd.dbo.NAME AS npn
		INNER JOIN MPSnapshotProd.dbo.NAME_PROVIDER AS np
			ON npn.NAME_ID = np.NAME_ID
	) AS MP_providers
		ON ecw.ulname = MP_providers.NAME_LAST
		AND ecw.ufname = MP_providers.NAME_FIRST
	ORDER BY
		ecw.ufname
		, ecw.uminitial
		, ecw.ulname
*/


