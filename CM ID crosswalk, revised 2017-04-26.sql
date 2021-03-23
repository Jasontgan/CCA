

-- program ID definitions
-- source: \\cca-fs1\groups\CrossFunctional\BI\Medical Analytics\ClinOps\Program_id definitions 2017-04-25.xlsx (ultimately from: \\cca-fs1\groups\CrossFunctional\IT\MP Data Dictionaries\Program_id definitions.xlsx)
IF OBJECT_ID('tempdb..#program_ID_definitions') IS NOT NULL GOTO skip_program_ID_definitions

CREATE TABLE #program_ID_definitions (PROGRAM_ID VARCHAR(3), description VARCHAR(100), note VARCHAR(25))

INSERT INTO #program_ID_definitions VALUES ('M00', 'Prospects', 'members')
INSERT INTO #program_ID_definitions VALUES ('MC0', 'Prospects -- send to clinical system', 'members')
INSERT INTO #program_ID_definitions VALUES ('M01', '01 Lead - OM: Lead requiring BRC/Scope of Appt', 'members')
INSERT INTO #program_ID_definitions VALUES ('M02', '02 Authorized Lead - OM: Permission to contact', 'members')
INSERT INTO #program_ID_definitions VALUES ('M03', '03 Prospect - OM: Agreed to Visit or Mailing', 'members')
INSERT INTO #program_ID_definitions VALUES ('M04', '04 Applicant - OM: Outreach check app/incomplete', 'members')
INSERT INTO #program_ID_definitions VALUES ('M06', '06 Awaiting CMS Cancellation', 'members')
INSERT INTO #program_ID_definitions VALUES ('M08', '08 Enrolled, awaiting 834 Cancelation', 'members')
INSERT INTO #program_ID_definitions VALUES ('M10', '10 Enrollment - Ops: Enrollment enters Application', 'members')
INSERT INTO #program_ID_definitions VALUES ('M11', '11 MH Pending - Ops: MassHealth Submission', 'members')
INSERT INTO #program_ID_definitions VALUES ('M12', '12 CMS Ready to Enroll - Ops: Applicants Ready for CMS', 'members')
INSERT INTO #program_ID_definitions VALUES ('M14', '14 CMS Ready to Disenroll - Ops: Members ready for disenroll', 'members')
INSERT INTO #program_ID_definitions VALUES ('M16', '16 CMS Submitted - MARx submission - awaiting response', 'members')
INSERT INTO #program_ID_definitions VALUES ('M18', 'new ICO member, waiting for CMS Confirmation', 'members')
INSERT INTO #program_ID_definitions VALUES ('M22', '22 CMS Rejections', 'members')
INSERT INTO #program_ID_definitions VALUES ('M23', '23 CMS No Reply - Missing reply to submission', 'members')
INSERT INTO #program_ID_definitions VALUES ('M24', '24 CMS Special Resolution - response requires analysis/action', 'members')
INSERT INTO #program_ID_definitions VALUES ('M28', '28 Future Enrolled -- pending 834 confirmation', 'members')
INSERT INTO #program_ID_definitions VALUES ('M30', '30 Active Members', 'members')
INSERT INTO #program_ID_definitions VALUES ('M86', '86 Disenrolled -- pending CMS confirmation', 'members')
INSERT INTO #program_ID_definitions VALUES ('M88', '88 Disenrolled -- pending 834 confirmation', 'members')
INSERT INTO #program_ID_definitions VALUES ('M90', '90 Disenrolled Member', 'members')
INSERT INTO #program_ID_definitions VALUES ('XXX', 'Dead Records', 'members')

INSERT INTO #program_ID_definitions VALUES ('P01', 'P01 PCP', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P05', 'P05 Care Manager', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P06', 'P06 GSSC', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P07', 'P07 Primary Care Team', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P08', 'P08 ASAP', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P0A', 'ICO PCP', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P0B', 'ICO Clinical Care Manager', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P0C', 'ICO Supportive Care Manager', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P0D', 'ICO Primary Care Location', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P0E', 'ICO Primary Care Health Home', 'no longer in use')
INSERT INTO #program_ID_definitions VALUES ('P0F', 'ICO Behavioral Health Home', 'no longer in use')
INSERT INTO #program_ID_definitions VALUES ('P0G', 'ICO Supportive Care Organization', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P0H', 'Long Term Support Agency', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P0J', 'Health Outreach Worker', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P0K', 'Dental Provider', 'Not implemented')
INSERT INTO #program_ID_definitions VALUES ('P0L', 'Long Term Support Coordinator', 'Not implemented')
INSERT INTO #program_ID_definitions VALUES ('P10', 'P10 Pharmacy', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P1X', 'P1X Closed Pharmacy', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P20', 'P20 Primary Care Location', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P2X', 'P2X Closed Primary Care Loc', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P30', 'P30 Secondary Care Location', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P3X', 'P3X Closed Secondary Care Loc', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P40', 'P40 Care Manager Org', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P4X', 'P4X Closed Care Manager Org', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P60', 'P60 Contracting Entity', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P6X', 'P6X Closed Contracting Entity', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P90', 'Care Model', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P9X', 'Inactive Care Model', 'providers')
INSERT INTO #program_ID_definitions VALUES ('P9Z', 'Invalid Care Model', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PDH', 'Dummy Long Term Support Coordination', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PR1', 'Referrers', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PR2', 'Referral Organizations', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PX1', 'PX1 Closed PCP', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PX5', 'PX5 Closed Care Manager', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PX6', 'PX6 Closed GSSC', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PX7', 'PX7 Closed Primary Care Team', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PX8', 'PX8 Closed ASAP', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PXA', 'Inactive ICO PCP', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PXB', 'Inactive ICO Clinical Care Manager', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PXC', 'Inactive ICO Care Coordinator', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PXD', 'Inactive ICO Primary Care Location', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PXE', 'Inactive ICO Primary Care Health Home', 'no longer in use')
INSERT INTO #program_ID_definitions VALUES ('PXF', 'Inactive ICO Behavioral Health Home', 'no longer in use')
INSERT INTO #program_ID_definitions VALUES ('PXH', 'Inactive Long Term Support Coordination', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PXJ', 'Inactive Health Outreach Worker', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PXK', 'Inactive Dental Provider', 'not implemented')
INSERT INTO #program_ID_definitions VALUES ('PY5', 'Inactive SCO Care Managers', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PZH', 'Invalid Long Term Support Coordination', 'providers')
INSERT INTO #program_ID_definitions VALUES ('PZK', 'Invalid Dental Provider', 'Not implemented')

-- SELECT * FROM #program_ID_definitions ORDER BY PROGRAM_ID

skip_program_ID_definitions:


-- provider MPI, NPI, and Cactus ID from MP
IF OBJECT_ID('tempdb..#mp_id') IS NOT NULL GOTO skip_mp_id

-- DROP TABLE #mp_id
SELECT * INTO #mp_id FROM (
	SELECT
		n.NAME_ID
		, UPPER(n.NAME_FIRST) AS 'NAME_FIRST'
		, COALESCE(LEFT(n.NAME_MI, 1), '') AS 'NAME_MI'
		, UPPER(n.NAME_LAST) AS 'NAME_LAST'
		--, n.NAME_SUF
		, n.LETTER_COMP_CLOSE AS 'PROVIDER_K'
		, n.TEXT1 AS 'MPI' -- Em, em-em-em-em-MPI
		--, n.TEXT4 AS 'NPI'
		, CASE WHEN LEN(RTRIM(n.TEXT4)) = 10 AND ISNUMERIC(RTRIM(n.TEXT4)) = 1 THEN RTRIM(n.TEXT4) END AS 'NPI'
		--, n.PROGRAM_ID
		--, pid_defn.[description] AS 'pid_descr'
		--, np.SERVICE_TYPE
		, CASE WHEN np.SERVICE_TYPE = 'Care Manager'		THEN 'CM'
			WHEN np.SERVICE_TYPE = 'ICO Supp. Care Mgr'		THEN 'CM'
			WHEN np.SERVICE_TYPE = 'ICO Care Manager'		THEN 'CM'
			WHEN np.SERVICE_TYPE = 'Care Manager Org'		THEN 'CMO'
			WHEN np.SERVICE_TYPE = 'ICO PCL'				THEN 'PCL'
			WHEN np.SERVICE_TYPE = 'Primary Care Loc'		THEN 'PCL'
			WHEN np.SERVICE_TYPE = 'ICO PCP'				THEN 'PCP'
			WHEN np.SERVICE_TYPE = 'PCP'					THEN 'PCP'

			WHEN pid_defn.[description] = 'P05 Care Manager'					THEN 'CM'
			WHEN pid_defn.[description] = 'ICO Clinical Care Manager'			THEN 'CM'
			WHEN pid_defn.[description] = 'ICO Supportive Care Manager'			THEN 'CM'
			WHEN pid_defn.[description] = 'PX5 Closed Care Manager'				THEN 'CM'
			WHEN pid_defn.[description] = 'Inactive ICO Clinical Care Manager'	THEN 'CM'
			WHEN pid_defn.[description] = 'Inactive ICO Care Coordinator'		THEN 'CM'
			WHEN pid_defn.[description] = 'Inactive SCO Care Managers'			THEN 'CM'
			WHEN pid_defn.[description] = 'ICO Supportive Care Organization'	THEN 'CMO'
			WHEN pid_defn.[description] = 'P40 Care Manager Org'				THEN 'CMO'
			WHEN pid_defn.[description] = 'P4X Closed Care Manager Org'			THEN 'CMO'
			WHEN pid_defn.[description] = 'P07 Primary Care Team'				THEN 'PCL'
			WHEN pid_defn.[description] = 'ICO Primary Care Location'			THEN 'PCL'
			WHEN pid_defn.[description] = 'P20 Primary Care Location'			THEN 'PCL'
			WHEN pid_defn.[description] = 'P2X Closed Primary Care Loc'			THEN 'PCL'
			WHEN pid_defn.[description] = 'PX7 Closed Primary Care Team'		THEN 'PCL'
			WHEN pid_defn.[description] = 'Inactive ICO Primary Care Location'	THEN 'PCL'
			WHEN pid_defn.[description] = 'P01 PCP'								THEN 'PCP'
			WHEN pid_defn.[description] = 'ICO PCP'								THEN 'PCP'
			WHEN pid_defn.[description] = 'PX1 Closed PCP'						THEN 'PCP'
			WHEN pid_defn.[description] = 'Inactive ICO PCP'					THEN 'PCP'

			END AS 'prov_role'

		, CASE WHEN np.SERVICE_TYPE IN (
				  'Care Manager'
				, 'Care Manager Org'
				, 'ICO Care Manager'
				, 'ICO PCL'
				, 'ICO PCP'
				, 'ICO Supp. Care Mgr'
				, 'PCP'
				, 'Primary Care Loc'
			) THEN 'np.SERVICE_TYPE'
			WHEN pid_defn.[description] IN (
				  'P05 Care Manager'
				, 'ICO Clinical Care Manager'
				, 'ICO Supportive Care Manager'
				, 'PX5 Closed Care Manager'
				, 'Inactive ICO Clinical Care Manager'
				, 'Inactive ICO Care Coordinator'
				, 'Inactive SCO Care Managers'
				, 'ICO Supportive Care Organization'
				, 'P40 Care Manager Org'
				, 'P4X Closed Care Manager Org'
				, 'P07 Primary Care Team'
				, 'ICO Primary Care Location'
				, 'P20 Primary Care Location'
				, 'P2X Closed Primary Care Loc'
				, 'PX7 Closed Primary Care Team'
				, 'Inactive ICO Primary Care Location'
				, 'P01 PCP'
				, 'ICO PCP'
				, 'PX1 Closed PCP'
				, 'Inactive ICO PCP'
			) THEN 'n.PROGRAM_ID'
			END AS 'prov_role_source'

		, pid_defn.note
		, CAST(MAX(np.EFF_DATE) AS DATE) AS 'EFF_DATE'
		, CAST(MAX(np.TERM_DATE) AS DATE) AS 'TERM_DATE'
	-- SELECT TOP 1000 *
	FROM MPSnapshotProd.dbo.NAME AS n --WHERE NAME_FIRST = 'laura' AND NAME_LAST = 'black'
	INNER JOIN #program_ID_definitions AS pid_defn
		ON n.PROGRAM_ID = pid_defn.PROGRAM_ID
		AND pid_defn.note = 'providers' --WHERE NAME_FIRST = 'laura' AND NAME_LAST = 'black'
	--LEFT JOIN CCAMIS_Common.dbo.provider AS p
	--	ON n.TEXT4 = p.NPI
	LEFT JOIN MPSnapshotProd.dbo.NAME_PROVIDER AS np
		ON n.NAME_ID = np.PROVIDER_ID
		AND np.SERVICE_TYPE IN (
			'Care Manager'
			, 'ICO Care Manager'
			, 'Care Manager Org'
			, 'ICO PCL'
			, 'Primary Care Loc'
			, 'ICO PCP'
			, 'PCP'
			, 'Secondary Care Loc'
			, 'ICO Supp. Care Mgr')
			--, 'LTSC Agency')
		--AND np.TERM_DATE IS NULL --OR np.TERM_DATE > ICOSCO_mm.min_mm)
		--AND COALESCE(np.TERM_DATE, '9999-12-31') > np.EFF_DATE -- 2016-10-21-1053: this is how invalid date spans are traditionally flagged

	--WHERE p.prov_id IS NOT NULL
	GROUP BY
		n.NAME_ID
		, n.NAME_FIRST
		, n.NAME_MI
		, n.NAME_LAST
		--, n.NAME_SUF
		, n.LETTER_COMP_CLOSE
		, n.TEXT1
		--, n.TEXT4 AS 'NPI'
		, CASE WHEN LEN(RTRIM(n.TEXT4)) = 10 AND ISNUMERIC(RTRIM(n.TEXT4)) = 1 THEN RTRIM(n.TEXT4) END --AS 'NPI'
		--, n.PROGRAM_ID
		--, pid_defn.[description]
		--, np.SERVICE_TYPE
		, CASE WHEN np.SERVICE_TYPE = 'Care Manager'		THEN 'CM'
			WHEN np.SERVICE_TYPE = 'ICO Supp. Care Mgr'		THEN 'CM'
			WHEN np.SERVICE_TYPE = 'ICO Care Manager'		THEN 'CM'
			WHEN np.SERVICE_TYPE = 'Care Manager Org'		THEN 'CMO'
			WHEN np.SERVICE_TYPE = 'ICO PCL'				THEN 'PCL'
			WHEN np.SERVICE_TYPE = 'Primary Care Loc'		THEN 'PCL'
			WHEN np.SERVICE_TYPE = 'ICO PCP'				THEN 'PCP'
			WHEN np.SERVICE_TYPE = 'PCP'					THEN 'PCP'

			WHEN pid_defn.[description] = 'P05 Care Manager'					THEN 'CM'
			WHEN pid_defn.[description] = 'ICO Clinical Care Manager'			THEN 'CM'
			WHEN pid_defn.[description] = 'ICO Supportive Care Manager'			THEN 'CM'
			WHEN pid_defn.[description] = 'PX5 Closed Care Manager'				THEN 'CM'
			WHEN pid_defn.[description] = 'Inactive ICO Clinical Care Manager'	THEN 'CM'
			WHEN pid_defn.[description] = 'Inactive ICO Care Coordinator'		THEN 'CM'
			WHEN pid_defn.[description] = 'Inactive SCO Care Managers'			THEN 'CM'
			WHEN pid_defn.[description] = 'ICO Supportive Care Organization'	THEN 'CMO'
			WHEN pid_defn.[description] = 'P40 Care Manager Org'				THEN 'CMO'
			WHEN pid_defn.[description] = 'P4X Closed Care Manager Org'			THEN 'CMO'
			WHEN pid_defn.[description] = 'P07 Primary Care Team'				THEN 'PCL'
			WHEN pid_defn.[description] = 'ICO Primary Care Location'			THEN 'PCL'
			WHEN pid_defn.[description] = 'P20 Primary Care Location'			THEN 'PCL'
			WHEN pid_defn.[description] = 'P2X Closed Primary Care Loc'			THEN 'PCL'
			WHEN pid_defn.[description] = 'PX7 Closed Primary Care Team'		THEN 'PCL'
			WHEN pid_defn.[description] = 'Inactive ICO Primary Care Location'	THEN 'PCL'
			WHEN pid_defn.[description] = 'P01 PCP'								THEN 'PCP'
			WHEN pid_defn.[description] = 'ICO PCP'								THEN 'PCP'
			WHEN pid_defn.[description] = 'PX1 Closed PCP'						THEN 'PCP'
			WHEN pid_defn.[description] = 'Inactive ICO PCP'					THEN 'PCP'

			END --AS 'prov_role'

		, CASE WHEN np.SERVICE_TYPE IN (
				  'Care Manager'
				, 'Care Manager Org'
				, 'ICO Care Manager'
				, 'ICO PCL'
				, 'ICO PCP'
				, 'ICO Supp. Care Mgr'
				, 'PCP'
				, 'Primary Care Loc'
			) THEN 'np.SERVICE_TYPE'
			WHEN pid_defn.[description] IN (
				  'P05 Care Manager'
				, 'ICO Clinical Care Manager'
				, 'ICO Supportive Care Manager'
				, 'PX5 Closed Care Manager'
				, 'Inactive ICO Clinical Care Manager'
				, 'Inactive ICO Care Coordinator'
				, 'Inactive SCO Care Managers'
				, 'ICO Supportive Care Organization'
				, 'P40 Care Manager Org'
				, 'P4X Closed Care Manager Org'
				, 'P07 Primary Care Team'
				, 'ICO Primary Care Location'
				, 'P20 Primary Care Location'
				, 'P2X Closed Primary Care Loc'
				, 'PX7 Closed Primary Care Team'
				, 'Inactive ICO Primary Care Location'
				, 'P01 PCP'
				, 'ICO PCP'
				, 'PX1 Closed PCP'
				, 'Inactive ICO PCP'
			) THEN 'n.PROGRAM_ID'
			END --AS 'prov_role_source'

		, pid_defn.note
		--, CAST(np.EFF_DATE AS DATE) --AS 'EFF_DATE'
		--, CAST(np.TERM_DATE AS DATE) --AS 'TERM_DATE'
	--ORDER BY
	--	n.NAME_LAST
	--	--n.NAME_ID
	--	, n.NAME_FIRST
) AS mp_id
ORDER BY
	mp_id.NAME_LAST
	--mp_id.NAME_ID
	, mp_id.NAME_FIRST
--PRINT ' 1723 rows   #mp_id' -- 2017-04-26-1338
PRINT ' 11092 rows   #mp_id' -- 2017-04-26-1452 -- with CM from both SERVICE_TYPE and PROGRAM_ID
-- SELECT * FROM #mp_id ORDER BY NAME_LAST, NAME_FIRST
-- SELECT NAME_ID FROM #mp_id GROUP BY NAME_ID
-- SELECT * FROM #mp_id WHERE prov_role = 'CM' ORDER BY NAME_LAST, NAME_FIRST
-- SELECT NAME_ID FROM #mp_id WHERE prov_role = 'CM' GROUP BY NAME_ID
-- SELECT #mp_id.* FROM #mp_id INNER JOIN (SELECT NAME_ID FROM #mp_id WHERE prov_role = 'CM' GROUP BY NAME_ID HAVING COUNT(*) > 1) AS dup_names ON #mp_id.NAME_ID = dup_names.NAME_ID
-- SELECT * FROM #mp_id WHERE prov_role = 'CM' AND MPI IS NULL ORDER BY NAME_LAST, NAME_FIRST
-- SELECT * FROM #mp_id WHERE prov_role = 'CM' AND NAME_LAST IS NULL ORDER BY NAME_LAST, NAME_FIRST
-- SELECT * FROM #mp_id WHERE prov_role = 'CM' AND NAME_FIRST IS NULL ORDER BY NAME_LAST, NAME_FIRST
-- SELECT * FROM #mp_id WHERE prov_role = 'CM' AND NAME_FIRST IS NOT NULL AND MPI IS NOT NULL ORDER BY NAME_LAST, NAME_FIRST
-- SELECT NAME_ID, NPI, MPI FROM #mp_id WHERE prov_role = 'CM' AND NAME_FIRST IS NOT NULL AND MPI IS NOT NULL GROUP BY NAME_ID, NPI, MPI
-- SELECT MPI FROM #mp_id WHERE prov_role = 'CM' AND NAME_FIRST IS NOT NULL AND MPI IS NOT NULL GROUP BY MPI

skip_mp_id:



--SELECT TOP 1000 *
--		, pid_defn.[description] AS 'pid_descr'

--	FROM MPSnapshotProd.dbo.NAME AS n 
--		INNER JOIN #program_ID_definitions AS pid_defn
--		ON n.PROGRAM_ID = pid_defn.PROGRAM_ID
--		AND pid_defn.note = 'providers'
--WHERE NAME_FIRST = 'laura' AND NAME_LAST = 'black'
--SELECT * FROM #program_ID_definitions



SELECT	
	*
FROM OPENQUERY (SRVMEDECWREP01, '
	SELECT
		d.doctorID
		, d.speciality
		, d.PrintName
		, d.providerCode
		, d.TaxID
		, d.NPI
		, d.hl7id AS MPI
	FROM doctors AS d
	WHERE COALESCE(hl7id, '''') <> ''''
	GROUP BY
		d.doctorID
		, d.speciality
		, d.PrintName
		, d.providerCode
		, d.TaxID
		, d.NPI
		, d.hl7id
	')


SELECT
	ecw.*
FROM OPENQUERY(SRVMEDECWREP01, '
	SELECT 
		p.hl7id AS CCAID
		, e.Date
		, d.hl7id AS dr_MPI
		, r.hl7id AS res_MPI
	FROM users AS u
	INNER JOIN patients AS p
		ON u.uid = p.pid
	INNER JOIN enc AS e
		ON u.uid = e.patientid
		AND e.deleteflag = 0
		AND e.visitType IN (''MDS Face'', ''MDS Teleph'', ''MDS Visit'', ''HANNUAL'', ''OANNUAL'', ''ANNUAL'')	/*	ANNUAL added 2017-02-02		*/
	LEFT JOIN doctors AS d
		ON e.doctorID = d.doctorID
	LEFT JOIN doctors AS r
		ON e.resourceID = r.doctorID
	WHERE p.hl7id LIKE ''536%''
/*		AND e.Date = ''2017-02-01''		*/
		AND e.Date >= ''2013-10-01''
		AND (
			RTRIM(COALESCE(d.hl7id, '''')) <> ''''
			OR RTRIM(COALESCE(r.hl7id, '''')) <> ''''
		)
	GROUP BY
		p.hl7id
		, e.Date
		, d.hl7id
		, r.hl7id
') AS ecw

