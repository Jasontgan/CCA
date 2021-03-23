
DECLARE @date_range_begin AS DATE = '2001-01-01'	-- since the beginning of SCO?
DECLARE @date_range_end   AS DATE = '2050-12-31'



-- provider MPI, NPI, and DoctorID from eCW Doctors table
IF OBJECT_ID('tempdb..#ecw_mpi_npi') IS NOT NULL GOTO skip_ecw_mpi_npi

-- DROP TABLE #ecw_mpi_npi
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
--WHERE usertype_all.ufname = 'Racquel'
--	AND usertype_all.ulname = 'Hatfield'
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
-- SELECT * FROM #ecw_mpi_npi ORDER BY ulname, ufname, MPI_eCW
-- SELECT * FROM #ecw_mpi_npi ORDER BY doctorID
-- SELECT * FROM #ecw_mpi_npi WHERE ulname LIKE '%weiss%' ORDER BY ulname_fix, ufname_fix, MPI_eCW
-- SELECT * FROM #ecw_mpi_npi WHERE NPI_valid IS NULL AND COALESCE(npi, '') <> ''

skip_ecw_mpi_npi:


IF OBJECT_ID('tempdb..#PCP_flag') IS NOT NULL GOTO skip_PCP_flag

-- DROP TABLE #PCP_flag
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
	, MAX(		-- does not flag anything; does it matter? -- 2018-01-12
		CASE WHEN assignment_rtk = 'C3VD0FMMJT' THEN 1
			ELSE 0
			END
		) AS 'ICO'
	, MAX(		-- does not flag anything; does it matter? -- 2018-01-12
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
-- SELECT * FROM #PCP_flag
-- SELECT * FROM #PCP_flag WHERE NPI_valid IS NULL AND COALESCE(NPI, '') <> ''

skip_PCP_flag:


IF OBJECT_ID('tempdb..##adv_dir_table') IS NOT NULL DROP TABLE ##adv_dir_table

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
	--, adt.prov_ID
	, COALESCE(e.NPI_valid, adt.prov_ID) AS 'prov_ID'

INTO ##adv_dir_table

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
			--, oq.Reviewer
			--, oq.UserType
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
		--GROUP BY
		--	oq.CCAID
		--	, oq.scandate

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
			--, oq.Reviewer
			--, oq.UserType
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
		--GROUP BY
		--	oq.CCAID
		--	, oq.scandate
		
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
			, 'coded_HCP' AS 'prov_ID'
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
		
		--GROUP BY
		--	oq.CCAID
		--	, CASE WHEN LEFT(oq.Code, 3) = 'HCP' THEN 'HCP'
		--		WHEN LEFT(oq.Code, 3) = 'MOL' THEN 'MOLST'
		--		END
		--	, oq.MDate

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
			, 'coded_MOLST' AS 'prov_ID'
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
		
		--GROUP BY
		--	oq.CCAID
		--	, CASE WHEN LEFT(oq.Code, 3) = 'HCP' THEN 'HCP'
		--		WHEN LEFT(oq.Code, 3) = 'MOL' THEN 'MOLST'
		--		END
		--	, oq.MDate

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
	--AND (
	--	meh.Product = 'ICO' AND (0 + CONVERT(CHAR(8), @date_range_end, 112) - CONVERT(CHAR(8), meh.DOB, 112)) / 10000 >= 65
		--meh.Product = 'ICO' AND (0 + CONVERT(CHAR(8), @date_range_end, 112) - CONVERT(CHAR(8), meh.DOB, 112)) / 10000 
	--	OR meh.Product = 'SCO'
	--	)

--GROUP BY
--	adt.CCAID
--	, RTRIM(meh.NAME_LAST + ', ' + meh.NAME_FIRST + ' ' + meh.NAME_MI)
--	, meh.DOB
--	, meh.Product
--	, (0 + CONVERT(CHAR(8), @date_range_end, 112) - CONVERT(CHAR(8), meh.DOB, 112)) / 10000
--	, adt.adv_dir_type
--	, adt.action_type
--	, adt.[source]
--	, adt.adv_dir_date
--	, mm.member_month
--	, adt.item_ID
--	, adt.item_name
--	, adt.prov_ID

ORDER BY
	adt.CCAID
	, adt.adv_dir_date
	, adt.adv_dir_type
	, adt.[source]


--select * from ##adv_dir_table

;with ad as
(
	select * from
	(
		select ccaid, name_full
		from medical_analytics.[dbo].[member_enrollment_history]
		where product = 'SCO'
		and member_month = '2018-11-01'
		and mp_enroll = 1
	--order by 1
	)meh
	left join
	(
		select ccaid as ccaid2, max(date) as adv_dir_date
		from ##adv_dir_table t
		group by ccaid
	)a
	on meh.ccaid = a.ccaid2
	--order by 1
)
select cast(numer as float) / cast(denom as float)
from
(
	select 'aa' as boom, count(*) as numer
	from ad
	where adv_dir_date is not null
)as numer
join
(
	select 'aa' as boom, count(*) as  denom
	from ad
)as denom
on numer.boom = denom.boom