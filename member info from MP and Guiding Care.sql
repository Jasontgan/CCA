/**/
DECLARE		@first_report_month		AS DATE	= '2019-10-01'
DECLARE		@last_report_month		AS DATE	= '2019-10-01'
DECLARE		@last_report_monthend	AS DATE	= DATEADD(DD, -1, DATEADD(MM, 1, @last_report_month))
DECLARE		@min_enr_span_end		AS DATE = '2019-10-31'
SELECT @first_report_month AS '@first_report_month', @last_report_month AS '@last_report_month', @last_report_monthend AS '@last_report_monthend', @min_enr_span_end AS '@min_enr_span_end'

IF OBJECT_ID('tempdb..#SMI_members') IS NOT NULL DROP TABLE #SMI_members
IF OBJECT_ID('tempdb..#all_member_phone') IS NOT NULL DROP TABLE #all_member_phone
IF OBJECT_ID('tempdb..#all_assessments') IS NOT NULL DROP TABLE #all_assessments
IF OBJECT_ID('tempdb..#MDS_ED_Q') IS NOT NULL DROP TABLE #MDS_ED_Q

; WITH phone_data AS (
	SELECT DISTINCT
		name.TEXT2 AS 'CCAID'
		, addr.NAME_ID
		, RTRIM(phone.PHONE_NUMBER) AS 'member_phone'
		, CASE WHEN CHARINDEX('day', phone.PHONE_TYPE) > 0 THEN 'day'
			WHEN CHARINDEX('night', phone.PHONE_TYPE) > 0 THEN 'night'
			WHEN CHARINDEX('TTY', phone.PHONE_TYPE) > 0 THEN 'TTY'
			WHEN CHARINDEX('home', phone.PHONE_TYPE) > 0 THEN 'home'
			WHEN CHARINDEX('fac', phone.PHONE_TYPE) > 0 THEN 'fac'
			WHEN CHARINDEX('fax', phone.PHONE_TYPE) > 0 THEN 'fax'
			WHEN CHARINDEX('mob', phone.PHONE_TYPE) > 0 THEN 'cell'
			WHEN CHARINDEX('office', phone.PHONE_TYPE) > 0 THEN 'office'
			WHEN CHARINDEX('cell', phone.PHONE_TYPE) > 0 THEN 'cell'
			WHEN CHARINDEX('other', phone.PHONE_TYPE) > 0 THEN 'other'
			WHEN CHARINDEX('no phone', phone.PHONE_TYPE) > 0 THEN 'no phone'
			ELSE 'unknown' END AS 'phone_type'	-- includes Relevate-######, Shelter#-######, Temporary / OOA-####, Unknown-######
		, CASE WHEN phone.PREFERRED_FLAG = 'x' THEN 0
			WHEN CHARINDEX('mob', phone.PHONE_TYPE) > 0 
				OR CHARINDEX('home', phone.PHONE_TYPE) > 0
				OR CHARINDEX('cell', phone.PHONE_TYPE) > 0 THEN 1
			WHEN CHARINDEX('day', phone.PHONE_TYPE) > 0 THEN 2
			WHEN CHARINDEX('night', phone.PHONE_TYPE) > 0
				OR CHARINDEX('office', phone.PHONE_TYPE) > 0
				OR CHARINDEX('TTY', phone.PHONE_TYPE) > 0
				OR CHARINDEX('fac', phone.PHONE_TYPE) > 0 THEN 3
			WHEN CHARINDEX('fax', phone.PHONE_TYPE) > 0 THEN 4
			WHEN CHARINDEX('other', phone.PHONE_TYPE) > 0 THEN 5
			WHEN CHARINDEX('no phone', phone.PHONE_TYPE) > 0 THEN 6
			ELSE 5 END AS 'phone_pref'
		, phone.PREFERRED_FLAG
		, phone.CREATE_DATE
		, COALESCE(phone.PHONE_EXTENSION, '') AS 'ext.'
		, COALESCE(phone.BEST_TIME_TO_CALL, '') AS 'best time'
	FROM MPSnapshotProd.dbo.NAME_ADDRESS AS addr
	INNER JOIN MPSnapshotProd.dbo.NAME AS name
		ON addr.NAME_ID = name.NAME_ID
	INNER JOIN MPSnapshotProd.dbo.NAME_PHONE_NUMBERS AS phone
		ON addr.NAME_ID = phone.NAME_ID
	WHERE name.TEXT2 LIKE '53%'
		AND addr.END_DATE IS NULL
		AND LEN(RTRIM(phone.PHONE_NUMBER)) = 10
		AND LEFT(RTRIM(phone.PHONE_NUMBER), 1) <> '0'
		AND RTRIM(phone.PHONE_NUMBER) <> '1111111111'
		AND RTRIM(phone.PHONE_NUMBER) <> '1234567890'
		AND RTRIM(phone.PHONE_NUMBER) <> '9999999999'
		AND ISNUMERIC(LEFT(RTRIM(phone.PHONE_NUMBER), 1)) = 1
), phone_data_distinct AS (
	SELECT
		pd.CCAID
		, pd.NAME_ID
		, pd.member_phone
		, pd.phone_type
		, pd.phone_pref
		, pd.[ext.]
		, pd.[best time]
		, MAX(pd.CREATE_DATE) AS 'CREATE_DATE'
	FROM phone_data AS pd
	GROUP BY
		pd.CCAID
		, pd.NAME_ID
		, pd.member_phone
		, pd.phone_type
		, pd.phone_pref
		, pd.[ext.]
		, pd.[best time]
), phone_pref AS (
	SELECT
		pdd.CCAID
		, pdd.NAME_ID
		, pdd.member_phone
		, pdd.phone_type
		, pdd.phone_pref
		, 'phone_' + CAST(ROW_NUMBER() OVER (PARTITION BY pdd.CCAID ORDER BY pdd.phone_pref, pdd.phone_type, pdd.CREATE_DATE DESC, pdd.member_phone) AS VARCHAR(2)) AS 'pref'
		, CASE WHEN pdd.phone_pref = 0 THEN 'latest_phone'
			WHEN pdd.phone_type = 'day' THEN 'daytime_phone'
			WHEN pdd.phone_type = 'home' THEN 'home_phone'
			WHEN pdd.phone_type = 'cell' THEN 'mobile_phone'
			ELSE '' END AS 'phone_flag'
		, pdd.[ext.]
		, pdd.[best time]
		--, pdd.CREATE_DATE
	FROM phone_data_distinct AS pdd-- ORDER BY CCAID, phone_pref
)
SELECT
	*
INTO #all_member_phone
FROM (
	SELECT
		CCAID
		, member_phone
		--, pref
		, phone_flag
	FROM phone_pref
	WHERE pref BETWEEN 'phone_1' AND 'phone_4'
) AS amp
PIVOT (
	--MAX(member_phone) FOR pref IN ([phone_1], [phone_2], [phone_3], [phone_4], [phone_5], [phone_6], [phone_7], [phone_8], [phone_9])
	MAX(member_phone) FOR phone_flag IN ([latest_phone], [daytime_phone], [home_phone], [mobile_phone])
) AS pvt

;WITH latest_gc_address_date AS (
	SELECT
		CLIENT_PATIENT_ID
		,max_update_date = MAX(UPDATED_ON)
	FROM [Altruista].[dbo].[PATIENT_DETAILS]
	GROUP BY
		CLIENT_PATIENT_ID
)
SELECT 
	CCAID=n.TEXT2
	,MP_latest_phone = amp.latest_phone
	,MP_daytime_phone = amp.daytime_phone
	,MP_home_phone = amp.home_phone
	,MP_mobile_phone = amp.mobile_phone
	,MP_preferred_address_type = na.address_type
	,MP_preferred_address = 
		REPLACE(REPLACE(CONCAT(na.ADDRESS1,' ',na.ADDRESS2),CHAR(10),''),CHAR(13),'')
	,MP_preferred_address_city = REPLACE(na.CITY,CHAR(10),'')
	,MP_preferred_address_state = na.[STATE]
	,MP_preferred_address_zip = na.ZIP
	,GC_home_phone = gcpd.HOME_PHONE
	,GC_cell_phone = gcpd.CELL_PHONE
	,GC_alternate_phone = gcpd.ALTERNATE_PHONE
	,GC_address = gcpd.[ADDRESS]
	,GC_city = gcpd.CITY
	,GC_state = gcpd.[STATE]
	,GC_zip = gcpd.ZIP
FROM MPSnapshotProd.dbo.NAME n 
LEFT JOIN #all_member_phone amp ON amp.CCAID=n.TEXT2
LEFT JOIN MPSnapshotProd.dbo.NAME_ADDRESS na ON n.NAME_ID = na.NAME_ID
	AND (GETDATE() BETWEEN na.[START_DATE] AND na.[END_DATE]
		OR (GETDATE() >= na.[START_DATE] AND na.[END_DATE] IS NULL))
	AND PREFERRED_FLAG = 'x'
LEFT JOIN latest_gc_address_date lgad ON n.TEXT2=lgad.CLIENT_PATIENT_ID
LEFT JOIN [Altruista].[dbo].[PATIENT_DETAILS] gcpd ON n.TEXT2=gcpd.CLIENT_PATIENT_ID
	AND gcpd.UPDATED_ON=lgad.max_update_date
/*Restrict to currently enrolled*/
INNER JOIN MPSnapshotProd.dbo.DATE_SPAN ds_enr ON
	n.NAME_ID=ds_enr.NAME_ID
	AND GETDATE() >= CAST(ds_enr.[START_DATE] AS DATE)
	AND (CAST(ds_enr.END_DATE AS DATE) >= GETDATE() OR ds_enr.END_DATE IS NULL)
	AND ds_enr.VALUE IN ('ICO','SCO') 
	AND ds_enr.COLUMN_NAME = 'name_text19'
