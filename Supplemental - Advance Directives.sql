

/****************************************************\
             Supplemental - ACP Query
             Approx Run Time: 00:00:14
\****************************************************/


DECLARE @date_range_begin AS DATE = '2004-06-01'	-- since the beginning of SCO?
DECLARE @date_range_end   AS DATE = '2018-12-31'	-- Change for the new measure year



/*********************************************************\
Gets Provider MPI, NPI, and DoctorID from eCW Doctors table
\*********************************************************/
IF OBJECT_ID('tempdb..#ecw_mpi_npi') IS NOT NULL GOTO skip_ecw_mpi_npi
IF OBJECT_ID('tempdb..#fake_claims') IS NOT NULL DROP TABLE #fake_claims



; WITH usertype_1 AS (
	SELECT * FROM OPENQUERY(ECW, '
		SELECT
			d.doctorID
			, CASE WHEN d.hl7id = '''' THEN NULL ELSE d.hl7id END AS hl7id
			, u.ufname
			, LEFT(u.uminitial, 1) AS uminitial
			, u.ulname
			, u.usertype
		FROM doctors d
		INNER JOIN users AS u
			ON d.doctorID = u.uid
			AND u.usertype = 1
		WHERE u.delflag = 0
	')
), usertype_5 AS (
	SELECT * FROM OPENQUERY(ECW, '
		SELECT
			d.doctorID
			, CASE WHEN d.hl7id = '''' THEN NULL ELSE d.hl7id END AS hl7id
			, u.ufname
			, LEFT(u.uminitial, 1) AS uminitial
			, u.ulname
			, u.usertype
		FROM doctors d
		INNER JOIN users AS u
			ON d.doctorID = u.uid
			AND u.usertype = 5
		WHERE u.delflag = 0
	')
), usertype_all AS (
	SELECT * FROM OPENQUERY(ECW, '
		SELECT
			d.doctorID
			, CASE WHEN d.hl7id = '''' THEN NULL ELSE d.hl7id END AS hl7id
			, u.ufname
			, LEFT(u.uminitial, 1) AS uminitial
			, u.ulname
			, u.usertype
			, LTRIM(RTRIM(d.npi)) AS npi
		FROM doctors d
		INNER JOIN users AS u
			ON d.doctorID = u.uid
		WHERE u.delflag = 0
	')
)
SELECT
	usertype_all.doctorID
	, usertype_all.ufname
	, usertype_all.uminitial
	, usertype_all.ulname
	, usertype_all.ulname + ', ' + RTRIM(usertype_all.ufname + ' ' + usertype_all.uminitial) AS 'Provider'
	, RTRIM(usertype_all.ulname + ', ' + usertype_all.ufname) AS 'prov_lfname'
	, COALESCE(usertype_all.hl7id, usertype_1.hl7id, usertype_5.hl7id) AS 'MPI_eCW'
	, usertype_all.npi
	, nppes_npi.NPI AS 'NPI_valid'
INTO #ecw_mpi_npi
FROM usertype_all
LEFT JOIN usertype_1
	ON usertype_all.doctorID = usertype_1.doctorID
LEFT JOIN usertype_5
	ON usertype_1.ufname = usertype_5.ufname
	AND usertype_1.uminitial = usertype_5.uminitial
	AND usertype_1.ulname = usertype_5.ulname
LEFT JOIN CCAMIS_Common.dbo.NPIDB AS nppes_npi
	ON usertype_all.npi = nppes_npi.NPI
WHERE usertype_all.ufname <> ''
	AND usertype_all.ulname <> ''
GROUP BY
	usertype_all.doctorID
	, usertype_all.ufname
	, usertype_all.uminitial
	, usertype_all.ulname
	, COALESCE(usertype_all.hl7id, usertype_1.hl7id, usertype_5.hl7id)
	, usertype_all.npi
	, nppes_npi.NPI
ORDER BY
	usertype_all.ulname
	, usertype_all.ufname
	, usertype_all.uminitial

skip_ecw_mpi_npi: --Just for when the query is reran


IF OBJECT_ID('tempdb..#PCP_flag') IS NOT NULL GOTO skip_PCP_flag


SELECT
	pcp.NPI
	, pcp.Provider_K
	, MAX(pcp.LONGNAME) AS 'ProvName'
	, MIN(rt.[DESCRIPTION]) AS 'status'
	, RTRIM(MIN(
		CASE WHEN id.USERDEF_RTK2 IS NOT NULL OR ea.CATEGORY_RTK = 'C3VD0FMMRO' THEN 'PCP'
			WHEN ea.category_rtk = '#FAB7BCCF1' THEN 'PCP/Spec'
			END
		)) AS 'CategoryPCP'
	, MAX(		-- does not flag anything; does it matter? 
		CASE WHEN assignment_rtk = 'C3VD0FMMJT' THEN 1
			ELSE 0
			END
		) AS 'ICO'
	, MAX(		-- does not flag anything; does it matter? 
		CASE WHEN assignment_rtk = 'C3VD0FMMGS' THEN 1
			ELSE 0
			END
		) AS 'SCO'
	, RTRIM(MAX(rp.[DESCRIPTION])) AS 'ProviderRole'
	, COALESCE(ea.originalappointmentdate, ea.presentdate_from) AS 'ContractBeginDate'
	, CASE WHEN ea.active = 0 THEN COALESCE(ea.termination_date,ea.presentdate_to) ELSE ea.termination_date END AS 'ContractEndDate'
	, nppes_npi.NPI AS 'NPI_valid'
INTO #PCP_flag
FROM CactusDBSrv.Cactus.VISUALCACTUS.PROVIDERS AS pcp
INNER JOIN CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS AS ea
	ON pcp.PROVIDER_K = ea.PROVIDER_K
INNER JOIN CactusDBSrv.Cactus.VISUALCACTUS.REFTABLE AS rt
	ON ea.STATUS_RTK = rt.reftable_k
LEFT JOIN CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID AS id
	ON ea.EA_K = id.ENTITYASSIGNMENT_K
	AND id.USERDEF_RTK2 = 'C3VD0FMP4M'
	AND id.STARTDATE IS NOT NULL
LEFT JOIN CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID AS id2
	ON ea.EA_K = id2.ENTITYASSIGNMENT_K
	AND id2.USERDEF_L1 = 1
	AND id2.ACTIVE = 1
LEFT JOIN CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID AS id3
	ON ea.EA_K = id3.ENTITYASSIGNMENT_K
	AND ea.RECORDTYPE = 'E'
	AND id3.ACTIVE = 1
LEFT JOIN CactusDBSrv.Cactus.VISUALCACTUS.REFTABLE AS rr
	ON id3.TYPE_RTK = rr.REFTABLE_K
	AND rr.[DESCRIPTION] = 'Provider Role'
LEFT JOIN CactusDBSrv.Cactus.VisualCactus.Reftable AS rp
	ON id3.USERDEF_RTK2 = rp.REFTABLE_K
LEFT JOIN CCAMIS_Common.dbo.NPIDB AS nppes_npi
	ON pcp.NPI = nppes_npi.NPI
WHERE rp.[DESCRIPTION] = 'PCP'
	AND COALESCE(CASE WHEN ea.active = 0 THEN COALESCE(ea.termination_date,ea.presentdate_to) ELSE ea.termination_date END, '9999-12-31') >= CAST(CAST(2017-3 AS VARCHAR(4)) + '-07-01' AS DATE)
GROUP BY
	pcp.NPI
	, pcp.Provider_K
	, COALESCE(ea.originalappointmentdate, ea.presentdate_from)
	, CASE WHEN ea.active = 0 THEN COALESCE(ea.termination_date,ea.presentdate_to) ELSE ea.termination_date END
	, nppes_npi.NPI


skip_PCP_flag: --Just for when the query is reran

/*********************************************************\
                Gets Advance Directives Data
\*********************************************************/
IF OBJECT_ID('tempdb..#adv_dir_table') IS NOT NULL DROP TABLE #adv_dir_table

SELECT DISTINCT
	adt.CCAID
	, RTRIM(meh.NAME_LAST + ', ' + meh.NAME_FIRST + ' ' + meh.NAME_MI) AS 'member_name'
	, meh.DOB
	, meh.Product
	, (0 + CONVERT(CHAR(8), @date_range_end, 112) - CONVERT(CHAR(8), meh.DOB, 112)) / 10000 AS 'member_age'
	, adt.adv_dir_type AS 'type'
	, adt.action_type AS 'outcome'
	, adt.[source]
	, adt.adv_dir_date AS 'date'
	, CAST(mm.member_month AS DATE) AS 'member_month'
	, adt.item_ID
	, adt.item_name
	, COALESCE(e.NPI_valid, adt.prov_ID) AS 'prov_ID'

INTO #adv_dir_table

FROM (

		-- scanned directives: HCP
		SELECT DISTINCT
			oq.CCAID
			, 'HCP' AS 'adv_dir_type'
			, CAST(oq.scandate AS DATE) AS 'adv_dir_date'
			, 'docu' AS 'action_type'
			, 'scan_eCW' AS 'source'
			, CAST(oq.docID AS VARCHAR(255)) AS 'item_ID'
			, oq.CustomName AS 'item_name'
			, CAST(oq.ReviewerID AS VARCHAR(25)) AS 'prov_ID'
		FROM OPENQUERY(ECW,'
			SELECT
				p.hl7id AS CCAID
				, CONCAT(u.ulname, '', '', u.ufname) AS Member
				, d.docID
				, d.FileName
				, d.CustomName
				, d.doc_Type
				, d.ScanDate
				, d.ScannedBy
				, d.folderName
				, CONCAT(rev.ulname, '', '', rev.ufname) AS Reviewer
				, rev.uname
				, rev.UserType
				, d.ReviewerID
			FROM document AS d
			JOIN users AS u
				ON d.patientid = u.uid
			JOIN users AS rev
				ON d.ReviewerID = rev.uid
			JOIN patients AS p
				ON d.patientid = p.pid
				AND p.hl7id BETWEEN ''5364521037'' AND ''5369999999''
			WHERE d.CustomName NOT LIKE ''%unsign%''
				AND d.doc_type = ''15''
				AND (
					   d.CustomName LIKE ''%HCP%''
					OR d.CustomName LIKE ''%HPC%''
					OR d.CustomName LIKE ''%prox%''
				)
		') AS oq


	UNION ALL

		-- scanned directives: MOLST
		SELECT DISTINCT
			oq.CCAID
			, 'MOLST' AS 'adv_dir_type'
			, CAST(oq.scandate AS DATE) AS 'adv_dir_date'
			, 'docu' AS 'action_type'
			, 'scan_eCW' AS 'source'
			, CAST(oq.docID AS VARCHAR(255)) AS 'item_ID'
			, oq.CustomName AS 'item_name'
			, CAST(oq.ReviewerID AS VARCHAR(25)) AS 'prov_ID'
		FROM OPENQUERY(ECW,'
			SELECT
				p.hl7id AS CCAID
				, CONCAT(u.ulname, '', '', u.ufname) AS Member
				, d.docID
				, d.FileName
				, d.CustomName
				, d.doc_Type
				, d.ScanDate
				, d.ScannedBy
				, d.folderName
				, CONCAT(rev.ulname, '', '', rev.ufname) AS Reviewer
				, rev.uname
				, rev.UserType
				, d.ReviewerID
			FROM document AS d
			JOIN users AS u
				ON d.patientid = u.uid
			JOIN users AS rev
				ON d.ReviewerID = rev.uid
			JOIN patients AS p
				ON d.patientid = p.pid
				AND p.hl7id BETWEEN ''5364521037'' AND ''5369999999''
			WHERE d.CustomName NOT LIKE ''%unsign%''
				AND d.doc_type = ''15''
				AND (
					   d.CustomName LIKE ''%MOLST%''
					OR d.CustomName LIKE ''%MOLSY%''
					OR d.CustomName LIKE ''%MOLT%''
					OR d.CustomName LIKE ''%MOSLT%''
					OR d.CustomName LIKE ''%life%sustain%''
					OR d.CustomName LIKE ''%med%order%''
					OR d.CustomName = ''2016 01 04 MSTL ''
					OR d.CustomName = ''2016 06 02 MOST ''
					OR d.CustomName = ''20160513MLOST''
				)
		') AS oq

	UNION ALL

		-- coded directives: HCP
		SELECT DISTINCT
			oq.CCAID
			, CASE WHEN LEFT(oq.Code, 3) = 'HCP' THEN 'HCP'
				WHEN LEFT(oq.Code, 3) = 'MOL' THEN 'MOLST'
				END AS 'adv_dir_type'
			, CAST(oq.MDate AS DATE) AS 'adv_dir_date'
			, 'docu' AS 'action_type'
			, 'coded_eCW' AS 'source'
			, CAST(oq.Code AS VARCHAR(255)) AS 'item_ID'
			, oq.Name AS 'item_name'
			, 0 AS 'prov_ID'
		FROM OPENQUERY(ECW, '
			SELECT
				p.hl7id AS CCAID
				, CONCAT(u.ulname, '', '', u.ufname) AS Member
				, d.*
			FROM pt_adv_directives AS d
			JOIN users AS u
				ON d.ptid = u.uid
			JOIN patients AS p
				ON d.ptid = p.pid
				AND p.hl7id BETWEEN ''5364521037'' AND ''5369999999''
			WHERE d.Name <> ''Not on File''
				AND d.Name NOT LIKE ''%refused%''
				AND d.Name NOT LIKE ''%not signed%''
				AND d.Name NOT LIKE ''%not on file%''
				AND d.Name NOT LIKE ''%deferred%''
				AND d.delflag <> 1
				AND d.Code IN (
					''HCP''
					, ''HCPINVOKED''
					, ''HCPSIGNED''
				)
		') AS oq


	UNION ALL

		-- coded directives: MOLST
		SELECT DISTINCT
			oq.CCAID
			, CASE WHEN LEFT(oq.Code, 3) = 'HCP' THEN 'HCP'
				WHEN LEFT(oq.Code, 3) = 'MOL' THEN 'MOLST'
				END AS 'adv_dir_type'
			, CAST(oq.MDate AS DATE) AS 'adv_dir_date'
			, 'docu' AS 'action_type'
			, 'coded_eCW' AS 'source'
			, CAST(oq.Code AS VARCHAR(255)) AS 'item_ID'
			, oq.Name AS 'item_name'
			, 0 AS 'prov_ID'
		FROM OPENQUERY(ECW, '
			SELECT
				p.hl7id AS CCAID
				, CONCAT(u.ulname, '', '', u.ufname) AS Member
				, d.*
			FROM pt_adv_directives AS d
			JOIN users AS u
				ON d.ptid = u.uid
			JOIN patients AS p
				ON d.ptid = p.pid
				AND p.hl7id BETWEEN ''5364521037'' AND ''5369999999''
			WHERE d.Name <> ''Not on File''
				AND d.Name NOT LIKE ''%refused%''
				AND d.Name NOT LIKE ''%not signed%''
				AND d.Name NOT LIKE ''%not on file%''
				AND d.Name NOT LIKE ''%deferred%''
				AND d.delflag <> 1
				AND d.Code IN (
					''MOLSIGNED''
					, ''MOLST''
				)
		') AS oq

	UNION ALL

		SELECT DISTINCT
			ecw.CCAID
			, CASE WHEN ecw.itemID IN (
					  17030001 -- Advanced Directives
					, 17828001 -- Advance directive on file
					, 18021001 -- Advance directive in chart
					, 19670001 -- Active advance directive
					, 21867442 -- Advance directive in chart
					, 21954363 -- Advance directive on file
					, 21963364 -- Advanced directive placed in chart this admission
					, 21969506 -- Copy of advanced directive obtained from patient
					, 17608001 -- Advanced directives, counseling/discussion
					, 19686001 -- Advanced care planning/counseling discussion
					, 21867492 -- Advanced directives, counseling/discussion
					, 21867931 -- Advance care planning
					, 21868980 -- ACP (advance care planning)
					, 21870182 -- Counseling regarding advanced directives and goals of care
					, 21871448 -- Advanced care planning/counseling discussion
					, 21872628 -- Advance directive discussed with patient
					, 21878138 -- Counseling regarding advanced directives
					, 21970551 -- Discussion about advance care planning held with family member
					, 21974514 -- Counseling regarding advanced care planning and goals of care
				) THEN 'ACP'
				WHEN ecw.itemID IN (
					  17031001 -- Health Proxy
					, 18989001 -- Patient has healthcare proxy
					, 21872742 -- Patient has healthcare proxy
				) THEN 'HCP'
				WHEN ecw.itemID IN (
					  21858052 -- Patient has active medical orders for life-sustaining treatment (MOLST) form
					, 21868159 -- Patient has active medical orders for life-sustaining treatment (MOLST) form
					, 21956510 -- Medical orders for life-sustaining treatment (MOLST) form in chart
				) THEN 'MOLST'
				END AS 'adv_dir_type'
			, ecw.enc_date AS 'adv_dir_date'
			, CASE WHEN ecw.itemID IN (
					  17608001 -- Advanced directives, counseling/discussion
					, 19686001 -- Advanced care planning/counseling discussion
					, 21867492 -- Advanced directives, counseling/discussion
					, 21867931 -- Advance care planning
					, 21868980 -- ACP (advance care planning)
					, 21870182 -- Counseling regarding advanced directives and goals of care
					, 21871448 -- Advanced care planning/counseling discussion
					, 21872628 -- Advance directive discussed with patient
					, 21878138 -- Counseling regarding advanced directives
					, 21970551 -- Discussion about advance care planning held with family member
					, 21974514 -- Counseling regarding advanced care planning and goals of care
				) THEN 'meet'
				WHEN ecw.itemID IN (
					  17030001 -- Advanced Directives
					, 17828001 -- Advance directive on file
					, 18021001 -- Advance directive in chart
					, 19670001 -- Active advance directive
					, 21867442 -- Advance directive in chart
					, 21954363 -- Advance directive on file
					, 21963364 -- Advanced directive placed in chart this admission
					, 21969506 -- Copy of advanced directive obtained from patient
					, 17031001 -- Health Proxy
					, 18989001 -- Patient has healthcare proxy
					, 21872742 -- Patient has healthcare proxy
					, 21858052 -- Patient has active medical orders for life-sustaining treatment (MOLST) form
					, 21868159 -- Patient has active medical orders for life-sustaining treatment (MOLST) form
					, 21956510 -- Medical orders for life-sustaining treatment (MOLST) form in chart
				) THEN 'docu'
				END AS 'action_type'
			, 'enc_eCW' AS 'source'
			, CAST(ecw.itemID AS VARCHAR(255)) AS 'item_ID'
			, ecw.itemName AS 'item_name'
			, CAST(ecw.doctorID AS VARCHAR(25)) AS 'prov_ID'

		FROM OPENQUERY(ECW,'
			SELECT
				  p.hl7id AS CCAID
				, e.date AS enc_date
				, i.itemID
				, i.itemName
				, e.doctorID
			FROM users AS u
			JOIN patients AS p
				ON u.uid = p.pid
				AND p.hl7id BETWEEN ''5364521037'' AND ''5369999999''
			JOIN structdemographics AS dem
				ON u.uid = dem.patientid
				AND dem.detailID = 681001
				AND dem.deleteflag = 0
			JOIN enc AS e
				ON u.uid = e.patientid
				AND e.deleteflag = 0
			JOIN diagnosis AS v
				ON e.encounterid = v.encounterid
			JOIN items AS i
				ON v.itemid = i.itemid
				AND v.itemid IN (
					  17030001 -- Advanced Directives
					, 17828001 -- Advance directive on file
					, 18021001 -- Advance directive in chart
					, 19670001 -- Active advance directive
					, 21867442 -- Advance directive in chart
					, 21954363 -- Advance directive on file
					, 21963364 -- Advanced directive placed in chart this admission
					, 21969506 -- Copy of advanced directive obtained from patient
					, 17608001 -- Advanced directives, counseling/discussion
					, 19686001 -- Advanced care planning/counseling discussion
					, 21867492 -- Advanced directives, counseling/discussion
					, 21867931 -- Advance care planning
					, 21868980 -- ACP (advance care planning)
					, 21870182 -- Counseling regarding advanced directives and goals of care
					, 21871448 -- Advanced care planning/counseling discussion
					, 21872628 -- Advance directive discussed with patient
					, 21878138 -- Counseling regarding advanced directives
	/*
					, 21970551 -- Discussion about advance care planning held with family member
	*/
					, 21974514 -- Counseling regarding advanced care planning and goals of care
					, 17031001 -- Health Proxy
					, 18989001 -- Patient has healthcare proxy
					, 21872742 -- Patient has healthcare proxy
					, 21858052 -- Patient has active medical orders for life-sustaining treatment (MOLST) form
					, 21868159 -- Patient has active medical orders for life-sustaining treatment (MOLST) form
					, 21956510 -- Medical orders for life-sustaining treatment (MOLST) form in chart
				)
			JOIN itemdetail AS id
				ON i.itemid = id.itemid
		') AS ecw

) AS adt

INNER JOIN CCAMIS_COMMON.dbo.members AS mem
	ON adt.CCAID = mem.cca_id

INNER JOIN CCAMIS_Common.dbo.Dim_date AS mm
	ON adt.adv_dir_date = mm.[Date]

LEFT JOIN Medical_Analytics.dbo.member_enrollment_history AS meh
	ON adt.CCAID = meh.CCAID
	AND DATEADD(MM, DATEDIFF(MM, 0, @date_range_end), 0) = meh.member_month

LEFT JOIN (
	SELECT DISTINCT
		CAST(doctorID AS VARCHAR(25)) AS 'doctorID'
		, CAST(NPI_valid AS VARCHAR(25)) AS 'NPI_valid'
	FROM (
		SELECT
			ex.*
		FROM #ecw_mpi_npi AS ex
		INNER JOIN (
			SELECT
				NPI_valid
				, COUNT(*) AS 'ID_count'
			FROM #ecw_mpi_npi
			WHERE NPI_valid IS NOT NULL
			GROUP BY
				NPI_valid
		) AS e1
			ON ex.NPI_valid = e1.NPI_valid
			AND e1.ID_count <= 4	-- this seems to be the limit where alternate versions of individual provider names gives way to group NPIs
	) AS ids
) AS e
	ON CAST(adt.prov_ID AS VARCHAR(25)) = e.doctorID

WHERE adt.adv_dir_date BETWEEN @date_range_begin AND @date_range_end
	AND (
		meh.Product = 'ICO' AND (0 + CONVERT(CHAR(8), @date_range_end, 112) - CONVERT(CHAR(8), meh.DOB, 112)) / 10000 >= 65
		OR meh.Product = 'SCO'
		)



ORDER BY
	adt.CCAID
	, adt.adv_dir_date
	, adt.adv_dir_type
	, adt.[source]




/*********************************************************\
                    Converts to OSI format  
\*********************************************************/



	SELECT
		  'MemberKey'				= adt.CCAID
		, 'ProviderKey'				= COALESCE(CAST(prov.ProviderKey AS VARCHAR(25)), CAST(npi1.NPI_valid AS VARCHAR(25)), CAST(npi2.npi AS VARCHAR(25)), CAST(adt.prov_ID AS VARCHAR(25)))
		, 'ClaimNumber'				= CAST(adt.CCAID AS VARCHAR(10))
										+ CAST(CONVERT(CHAR(8), adt.[date], 112) AS VARCHAR(8))
										+ CAST(adt.prov_ID AS VARCHAR(15))
										+ CAST(adt.[type] AS VARCHAR(5))
		, 'ClaimLineNumber'			= CAST(ROW_NUMBER() OVER (PARTITION BY adt.CCAID, adt.[date], CAST(adt.prov_ID AS VARCHAR(25)), adt.[type] ORDER BY adt.item_ID) AS VARCHAR(3))
		, 'ClaimStatus'				= 'I'
		, 'DOS'						= adt.[date]
		, 'DOSThru'					= adt.[date]
		, 'ICD9DxPri'				= CASE WHEN adt.[date] < '2015-10-01' THEN 'V6549' ELSE '' END
		, 'ICD9DxSec1'				= ''
		, 'ICD9DxSec2'				= ''
		, 'ICD9DxSec3'				= ''
		, 'ICD9DxSec4'				= ''
		, 'ICD9DxSec5'				= ''
		, 'ICD9DxSec6'				= ''
		, 'ICD9DxSec7'				= ''
		, 'ICD9DxSec8'				= ''
		, 'ICD9DxSec9'				= ''
		, 'ICD9DxSec10'				= ''
		, 'ICD10DxPri'				= CASE WHEN adt.[date] >= '2015-10-01' THEN 'Z7189' ELSE '' END
		, 'ICD10DxSec1'				= ''
		, 'ICD10DxSec2'				= ''
		, 'ICD10DxSec3'				= ''
		, 'ICD10DxSec4'				= ''
		, 'ICD10DxSec5'				= ''
		, 'ICD10DxSec6'				= ''
		, 'ICD10DxSec7'				= ''
		, 'ICD10DxSec8'				= ''
		, 'ICD10DxSec9'				= ''
		, 'ICD10DxSec10'			= ''
		, 'PCPFlag'					= CASE WHEN flg.ProviderRole = 'PCP' THEN 1 ELSE 0 END	-- "Indicator for whether the claim provider serves as a PCP for the health plan. Refers to the provider’s contractual relationship to the plan, rather than medical specialty."
		, 'HCFAPOS'					= '11'
		, 'DRG'						= ''
		, 'DRG2'					= ''
		, 'MSDRG'					= ''
		, 'MSDRG2'					= ''
		, 'TOB'						= ''
		, 'UBRevenueCode'			= ''
		, 'UBOccurCode1'			= ''
		, 'UBOccurCode2'			= ''
		, 'UBOccurCode3'			= ''
		, 'UBOccurCode4'			= ''
		, 'HCPCSPx'					= ''
		, 'HCPCSMod'				= ''
		, 'CPTPx'					= CASE WHEN adt.outcome = 'meet' OR adt.item_name LIKE 'MOLST discussed with%' THEN '1158F' ELSE '1157F' END
		, 'CPTMod1'					= ''
		, 'CPTMod2'					= ''
		, 'ICD9Px1'					= ''
		, 'ICD9Px2'					= ''
		, 'ICD9Px3'					= ''
		, 'ICD9Px4'					= ''
		, 'ICD9Px5'					= ''
		, 'ICD9Px6'					= ''
		, 'ICD9Px7'					= ''
		, 'ICD9Px8'					= ''
		, 'ICD9Px9'					= ''
		, 'ICD9Px10'				= ''
		, 'ICD10Px1'				= ''
		, 'ICD10Px2'				= ''
		, 'ICD10Px3'				= ''
		, 'ICD10Px4'				= ''
		, 'ICD10Px5'				= ''
		, 'ICD10Px6'				= ''
		, 'ICD10Px7'				= ''
		, 'ICD10Px8'				= ''
		, 'ICD10Px9'				= ''
		, 'ICD10Px10'				= ''
		, 'CVX'						= ''
		, 'DischargeStatus'			= '01'
		, 'DaysDenied'				= ''
		, 'RoomBoardFlag'			= 'N'
		, 'HomegrownPx'				= ''
		, 'HomegrownMod'			= ''
		, 'ProviderSpecialty'		= ''
		, 'ExcludeFromDischarge'	= 1		-- "Set to 1 to exclude a claim from being considered discharge-eligible by the Discharge Builder"
		, 'RxProviderFlag'			= 0
		, 'ClaimAltID1'				= CAST(CASE WHEN LEN(adt.item_name) > '30' THEN LEFT(adt.item_name, 27) + '...' ELSE LEFT(adt.item_name, 30) END AS VARCHAR(30))
		, 'ClaimAltID2'				= CAST(adt.item_ID AS VARCHAR(10)) + CAST(adt.[type] AS VARCHAR(5)) + CAST(adt.[source] AS VARCHAR(15))
		, 'RRUUnitsofService'		= 1
		, 'MajorSurgery'			= 'N'
		, 'Allowed'					= 0
		, 'Billed'					= 0
		, 'Copay'					= 0
		, 'Cost'					= 0
		, 'Paid'					= 0
		, 'APDRG'					= ''
		, 'APRDRG'					= ''
		, 'POA'						= ''
		, 'POS'						= 'OT'	-- "OT (Other)"
		, 'ProviderType'			= 'RN'	-- "RN (Registered Nurse)"
		, 'SuppSource'				= 'S'	-- "S (Standard Supplemental)"
	INTO #fake_claims
	FROM #adv_dir_table AS adt
	LEFT JOIN #PCP_flag AS flg
		ON CAST(adt.prov_ID AS VARCHAR(25)) = CAST(flg.NPI_valid AS VARCHAR(25))
		AND flg.ProviderRole = 'PCP'
	LEFT JOIN Medical_Analytics.dbo.HEDIS_2017_Provider AS prov
		ON CAST(adt.prov_ID AS VARCHAR(25)) = prov.ProviderKey
	LEFT JOIN #ecw_mpi_npi AS npi1
		ON CAST(adt.prov_ID AS VARCHAR(25)) = npi1.doctorID
	LEFT JOIN #ecw_mpi_npi AS npi2
		ON CAST(adt.prov_ID AS VARCHAR(25)) = npi2.doctorID
		AND RTRIM(COALESCE(npi2.npi, '')) <> ''

RETURN -- note: if you don't stop before creating the output file, the file gets a "(11165 row(s) affected)" line at the top and will not be recognized by QSI
/*********************************************************\
SET ANSI_WARNINGS OFF -- removes "Warning: Null value is eliminated by an aggregate or other SET operation."
SET NOCOUNT ON -- removes row count from end of file

SELECT
	*
--INTO QualityAnalytics.dbo.HEDIS_2018_Supplemental_ADV
FROM #fake_claims
WHERE ClaimLineNumber = 1
ORDER BY
	MemberKey
	, DOS
	, ProviderKey

SET ANSI_WARNINGS ON
SET NOCOUNT OFF
\*********************************************************/
