

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
CREATE UNIQUE INDEX CCAID ON #id_xwalk (CCAID)
PRINT '#id_xwalk'
-- SELECT * FROM #id_xwalk ORDER BY CCAID
-- SELECT COUNT(*) FROM #id_xwalk		--81523
-- problem spans:
-- SELECT CCAID, COUNT(*) FROM #id_xwalk GROUP BY CCAID HAVING COUNT(*) > 1


-- #member_details: timeless member details
IF OBJECT_ID('tempdb..#member_details') IS NOT NULL DROP TABLE #member_details

; WITH member_demographics AS (
	SELECT DISTINCT
		CAST(n.TEXT2 AS BIGINT) AS 'CCAID'
		, UPPER(REPLACE(REPLACE(REPLACE(RTRIM(n.NAME_FIRST), CHAR(09), ''), CHAR(10), ''), CHAR(13), ''))-- AS 'NAME_FIRST'
			--+ RTRIM(' ' + UPPER(CASE WHEN PATINDEX('%[^a-Z]%', n.NAME_MI) = 1 THEN ''
			--	WHEN PATINDEX('%[^a-Z]%', n.NAME_MI) = 2 AND LEN(RTRIM(n.NAME_MI)) = 2 THEN LEFT(n.NAME_MI, 1)
			--	ELSE REPLACE(REPLACE(REPLACE(COALESCE(RTRIM(n.NAME_MI), ''), CHAR(09), ''), CHAR(10), ''), CHAR(13), '') END))-- AS 'NAME_MI'
			+ ' '
			+ UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(n.NAME_LAST)), CHAR(09), ''), CHAR(10), ''), CHAR(13), ''))-- AS 'NAME_LAST'
				AS 'NAME'
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
				CASE WHEN n.DATE1 > GETDATE() OR n.DATE1 = n.BIRTH_DATE THEN NULL ELSE n.DATE1 END
				, CASE WHEN hcfa.DEATH_DATE > GETDATE() OR hcfa.DEATH_DATE = n.BIRTH_DATE THEN NULL ELSE hcfa.DEATH_DATE END
			) AS DATE) AS 'DOD'
		, n.GENDER
		, COALESCE(a.TEXT23, 'Missing') AS 'language_spoken'
		, CASE WHEN a.TEXT23 = 'English'			THEN 'English'
			WHEN a.TEXT23 = 'Cantonese'				THEN 'Chinese'
			WHEN a.TEXT23 = 'Chinese'				THEN 'Chinese'
			WHEN a.TEXT23 = 'Mandarin'				THEN 'Chinese'
			WHEN a.TEXT23 = 'Spanish'				THEN 'Spanish'
			WHEN a.TEXT23 = 'Spanish; Castilian'	THEN 'Spanish'
			WHEN a.TEXT23 = 'Undetermined'			THEN 'Missing'
			WHEN a.TEXT23 = 'Unknown'				THEN 'Missing'
			WHEN a.TEXT23 IS NULL					THEN 'Missing'
			ELSE 'Other' END AS 'language_spoken_group'

		, COALESCE(a.TEXT6, 'Missing') AS 'language_written'
		, CASE WHEN a.TEXT6 = 'English'				THEN 'English'
			WHEN a.TEXT6 = 'Cantonese'				THEN 'Chinese'
			WHEN a.TEXT6 = 'Chinese'				THEN 'Chinese'
			WHEN a.TEXT6 = 'Mandarin'				THEN 'Chinese'
			WHEN a.TEXT6 = 'Spanish'				THEN 'Spanish'
			WHEN a.TEXT6 = 'Spanish; Castilian'		THEN 'Spanish'
			WHEN a.TEXT6 = 'Undetermined'			THEN 'Missing'
			WHEN a.TEXT6 = 'Unknown'				THEN 'Missing'
			WHEN a.TEXT6 IS NULL					THEN 'Missing'
			ELSE 'Other' END AS 'language_written_group'

		, COALESCE(a.TEXT7, 'Missing') AS 'race'
		, CASE WHEN a.TEXT7 = 'American Indian/Alaska Native'				THEN 'American Indian or Alaska Native'
			WHEN a.TEXT7 = 'Asian'											THEN 'Asian'
			WHEN a.TEXT7 = 'Black'											THEN 'Black or African American'
			WHEN a.TEXT7 = 'Caucasian'										THEN 'White'
			WHEN a.TEXT7 = 'Hispanic'										THEN 'Other Race'
			WHEN a.TEXT7 = 'Indian'											THEN 'Other Race'
			WHEN a.TEXT7 = 'Native Hawaii or Other Pacific Islander'		THEN 'Native Hawaiian or Other Pacific Islander'
			WHEN a.TEXT7 = 'Native Hawaiian or Other Pacific Islander'		THEN 'Native Hawaiian or Other Pacific Islander'
			WHEN a.TEXT7 = 'Other'											THEN 'Other Race'
			WHEN a.TEXT7 = 'Refuse to report'								THEN 'Declined'
			WHEN a.TEXT7 = 'Unknown'										THEN 'Unknown Race'
			WHEN a.TEXT7 = 'White'											THEN 'White'
			ELSE 'Unknown Race' END AS 'race_group' -- taken from HEDIS 2016 query

		, COALESCE(a.TEXT9, 'Missing') AS 'ethnicity'
		, CASE WHEN a.TEXT9 = 'Hispanic or Latino'		THEN 'Hispanic or Latino'
			WHEN a.TEXT9 = 'Not Hispanic or Latino'		THEN 'Not Hispanic or Latino'
			WHEN a.TEXT9 = 'Refuse to report'			THEN 'Declined'
			WHEN a.TEXT9 = 'Unknown'					THEN 'Unknown'
			ELSE 'Unknown' END AS 'ethnicity_group' -- taken from HEDIS 2016 query

		, COALESCE(a.TEXT8, 'Missing') AS 'marital'
		, CASE WHEN a.TEXT8 = 'Divorced'				THEN 'Single'
			WHEN a.TEXT8 = 'Legally Separated' 			THEN 'Unknown'
			WHEN a.TEXT8 = 'Married' 					THEN 'Married'
			WHEN a.TEXT8 = 'Never Married' 				THEN 'Single'
			WHEN a.TEXT8 = 'Other' 						THEN 'Unknown'
			WHEN a.TEXT8 = 'Separated' 					THEN 'Unknown'
			WHEN a.TEXT8 = 'Single' 					THEN 'Single'
			WHEN a.TEXT8 = 'Unknown' 					THEN 'Unknown'
			WHEN a.TEXT8 = 'Unmarried' 					THEN 'Single'
			WHEN a.TEXT8 = 'Unreported' 				THEN 'Unknown'
			WHEN a.TEXT8 = 'Widow' 						THEN 'Single'
			WHEN a.TEXT8 = 'Widowed' 					THEN 'Single'
			ELSE 'Unknown' END AS 'marital_group' -- taken from HEDIS 2016 query
	-- SELECT *
	FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS a
	INNER JOIN MPSnapshotProd.dbo.NAME AS n
		ON a.[ENTITY_ID] = n.NAME_ID
		AND n.PROGRAM_ID <> 'XXX'
		AND n.TEXT2 BETWEEN '5364521036' AND '5369999999'
	INNER JOIN MPSnapshotProd.dbo.DATE_SPAN AS ds
		ON n.NAME_ID = ds.NAME_ID
		AND ds.COLUMN_NAME = 'name_text19'
		--AND ds.VALUE IN ('ICO', 'SCO')
		AND ds.CARD_TYPE = 'MCAID App'
	INNER JOIN MPSnapshotProd.dbo.HCFA_NAME_ORG AS hcfa
		ON n.NAME_ID = hcfa.NAME_ID
	WHERE a.APP_TYPE = 'MCAID'
), current_enrolled AS (
	SELECT
		CAST(n.TEXT2 AS BIGINT) AS 'CCAID'
		, MAX(CAST(COALESCE(ds.END_DATE, '9999-12-30') AS DATE)) AS 'EnrollEndDt'
	-- SELECT TOP 100 *
	FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS a
	INNER JOIN MPSnapshotProd.dbo.NAME AS n
		ON a.[ENTITY_ID] = n.NAME_ID
		AND n.PROGRAM_ID <> 'XXX'
		AND n.TEXT2 BETWEEN '5364521036' AND '5369999999'
	INNER JOIN MPSnapshotProd.dbo.DATE_SPAN AS ds
		ON n.NAME_ID = ds.NAME_ID
		AND ds.COLUMN_NAME = 'name_text19'
		AND ds.VALUE IN ('ICO', 'SCO')
		AND ds.CARD_TYPE = 'MCAID App'
		AND COALESCE(ds.END_DATE, '9999-12-30') > ds.[START_DATE]
		AND COALESCE(ds.END_DATE, '9999-12-30') > GETDATE()
	WHERE a.APP_TYPE = 'MCAID'
	GROUP BY
		CAST(n.TEXT2 AS BIGINT)
)
SELECT
	member_demographics.*
	-- enroll_status  -- member has an open enrollment span in MP
	--, CASE WHEN current_enrolled.EnrollEndDt = '9999-12-30' THEN 'current member' ELSE 'not current member' END AS 'enroll_status'
	, CASE WHEN current_enrolled.EnrollEndDt >= GETDATE() THEN 'current member' ELSE 'not current member' END AS 'enroll_status'
	-- enroll_status2 -- enroll status with deaths flagged
	--, CASE WHEN member_demographics.DOD IS NULL THEN (CASE WHEN current_enrolled.EnrollEndDt = '9999-12-30' THEN 'current member' ELSE 'not current member' END) ELSE 'dead' END AS 'enroll_status2'
	, CASE WHEN member_demographics.DOD IS NOT NULL THEN 'dead'
		WHEN current_enrolled.EnrollEndDt BETWEEN DATEADD(DD, 1, CAST(GETDATE() AS DATE)) AND '9999-12-29' THEN 'future disenrollee'
		WHEN current_enrolled.EnrollEndDt = '9999-12-30' THEN 'continuing member'
		ELSE 'not current member'
		END AS 'enroll_status2'
	-- member age at time of death or today
	, (0 + CONVERT(CHAR(8), COALESCE(member_demographics.DOD, GETDATE()), 112) - CONVERT(CHAR(8), member_demographics.DOB, 112)) / 10000 AS 'current_age'
INTO #member_details
FROM member_demographics
LEFT JOIN current_enrolled
	ON member_demographics.CCAID = current_enrolled.CCAID
ORDER BY
	member_demographics.CCAID
PRINT '#member_details'
-- SELECT * FROM #member_details ORDER BY CCAID
-- SELECT DISTINCT CCAID FROM #member_details ORDER BY CCAID	--56616
-- problem spans:
-- SELECT CCAID, COUNT(*) FROM #member_details GROUP BY CCAID HAVING COUNT(*) > 1
-- SELECT * FROM #member_details WHERE CCAID = 5365555581 ORDER BY CCAID
-- SELECT * FROM #member_details ORDER BY current_age


-- #all_member_phone: current contact information for all members

IF OBJECT_ID('tempdb..#all_member_phone') IS NOT NULL DROP TABLE #all_member_phone

SELECT DISTINCT
	name.TEXT2 AS 'CCAID'
	, addr.NAME_ID
	, CASE WHEN phone.PREFERRED_FLAG NOT IN ('x','w') THEN 'v'
		ELSE phone.PREFERRED_FLAG END AS 'PHONE_PREFERRED_FLAG'
	, COALESCE(
		CASE WHEN LEN(phone.PHONE_NUMBER) = 10
			AND LEFT(RTRIM(phone.PHONE_NUMBER), 1) <> '0'
			AND RTRIM(phone.PHONE_NUMBER) <> '1234567890'
			AND RTRIM(phone.PHONE_NUMBER) <> '1234567895'
			AND RTRIM(phone.PHONE_NUMBER) <> '1115555555'
			AND RTRIM(phone.PHONE_NUMBER) <> '1010101101'
			AND RTRIM(phone.PHONE_NUMBER) <> '1010101010'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___2222222'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___8888888'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___7777777'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___9999999'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___000____'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___111____'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___555____'
			AND ISNUMERIC(LEFT(RTRIM(phone.PHONE_NUMBER), 1)) = 1
		THEN phone.PHONE_NUMBER
		END, 'not found') AS 'member_phone'
	, COALESCE(
		CASE WHEN LEN(phone.PHONE_NUMBER) = 10
			AND LEFT(RTRIM(phone.PHONE_NUMBER), 1) <> '0'
			AND RTRIM(phone.PHONE_NUMBER) <> '1234567890'
			AND RTRIM(phone.PHONE_NUMBER) <> '1234567895'
			AND RTRIM(phone.PHONE_NUMBER) <> '1115555555'
			AND RTRIM(phone.PHONE_NUMBER) <> '1010101101'
			AND RTRIM(phone.PHONE_NUMBER) <> '1010101010'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___2222222'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___8888888'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___7777777'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___9999999'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___000____'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___111____'
			AND RTRIM(phone.PHONE_NUMBER) NOT LIKE '___555____'
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
		END, 'not found') AS 'member_phone2'
	, COALESCE(CASE WHEN LEFT(phone.PHONE_TYPE, 7) = 'daytime' THEN 'Daytime'
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
			, 'not found') AS 'member_phone_type'
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
	, COALESCE(e.TEXT23, 'Missing') AS 'language_spoken'
	, (SELECT MAX(UPDATE_DATE) FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP) AS 'MP_DATE'
	, name.NAME_FIRST
	, COALESCE(name.NAME_MI, '') AS 'NAME_MI'
	, name.NAME_LAST
INTO #all_member_phone
-- SELECT TOP 1000 *
FROM MPSnapshotProd.dbo.NAME_ADDRESS AS addr
INNER JOIN MPSnapshotProd.dbo.NAME AS name
	ON addr.NAME_ID = name.NAME_ID
INNER JOIN MPSnapshotProd.dbo.NAME_PHONE_NUMBERS AS phone
	ON addr.NAME_ID = phone.NAME_ID
LEFT JOIN MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS e
	ON addr.NAME_ID = e.[ENTITY_ID]
	AND e.APP_TYPE = 'MCAID'
WHERE name.TEXT2 BETWEEN '5364521036' AND '5369999999'
	AND phone.PREFERRED_FLAG = 'x'
	AND addr.END_DATE IS NULL
PRINT '#all_member_phone'
-- SELECT * FROM #all_member_phone ORDER BY CCAID
-- SELECT DISTINCT CCAID FROM #all_member_phone		--64476
-- problem spans:
-- SELECT CCAID, COUNT(*) FROM #all_member_phone GROUP BY CCAID HAVING COUNT(*) > 1
-- SELECT amp.* FROM #all_member_phone AS amp INNER JOIN (SELECT CCAID FROM #member_details WHERE enroll_status = 'current member') AS m ON amp.CCAID = m.CCAID ORDER BY amp.CCAID	-- current members only


/*

-- SELECT * FROM #id_xwalk ORDER BY CCAID
-- SELECT * FROM #member_details ORDER BY CCAID
-- SELECT * FROM #all_member_phone ORDER BY CCAID


DROP TABLE Medical_Analytics.dbo.member_ID_crosswalk_backup
SELECT * INTO Medical_Analytics.dbo.member_ID_crosswalk_backup FROM Medical_Analytics.dbo.member_ID_crosswalk

DROP TABLE Medical_Analytics.dbo.member_ID_crosswalk

SELECT * INTO Medical_Analytics.dbo.member_ID_crosswalk FROM #id_xwalk ORDER BY CCAID
CREATE UNIQUE INDEX memb ON Medical_Analytics.dbo.member_ID_crosswalk (CCAID)

-- SELECT * FROM Medical_Analytics.dbo.member_ID_crosswalk ORDER BY CCAID


DROP TABLE Medical_Analytics.dbo.member_timeless_details_backup
SELECT * INTO Medical_Analytics.dbo.member_timeless_details_backup FROM Medical_Analytics.dbo.member_timeless_details

DROP TABLE Medical_Analytics.dbo.member_timeless_details

SELECT * INTO Medical_Analytics.dbo.member_timeless_details FROM #member_details ORDER BY CCAID
CREATE UNIQUE INDEX memb ON Medical_Analytics.dbo.member_timeless_details (CCAID)

-- SELECT * FROM Medical_Analytics.dbo.member_timeless_details ORDER BY CCAID


DROP TABLE Medical_Analytics.dbo.member_latest_phone_backup
SELECT * INTO Medical_Analytics.dbo.member_latest_phone_backup FROM Medical_Analytics.dbo.member_latest_phone

DROP TABLE Medical_Analytics.dbo.member_latest_phone

SELECT * INTO Medical_Analytics.dbo.member_latest_phone FROM #all_member_phone ORDER BY CCAID
CREATE UNIQUE INDEX memb ON Medical_Analytics.dbo.member_latest_phone (CCAID)

-- SELECT * FROM Medical_Analytics.dbo.member_latest_phone ORDER BY CCAID

*/
