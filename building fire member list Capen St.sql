

-- this finds currently enrolled members by address (see WHERE at bottom)
-- and includes contact and care team information 
-- please check for spelling variations!!! also city variations (Boston and Brighton are both correct in this case)


if OBJECT_ID('tempdb..#PrimCM') is not null
	drop table #PrimCM	
go	
----------CARE MANAGER/PARTNER FROM PATIENT_PHYSICIAN TABLE
; with PrimCareStaff as
(SELECT pd.[CLIENT_PATIENT_ID] as CCAID, pd.[PATIENT_ID], pp.[PHYSICIAN_ID] as PhysID
     ,r.Role_name as PhysRole, [TITLE], cs.[FIRST_NAME], cs.[LAST_NAME]
  FROM [Altruista].[dbo].[PATIENT_DETAILS] pd 
  inner join [Altruista].[dbo].[PATIENT_PHYSICIAN] pp on pd.patient_id=pp.patient_ID
	and pp.care_team_id=1 and pp.is_active=1 and pp.deleted_on is null
  inner join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on pp.physician_id=cs.member_id 
  left join altruista.dbo.role r on cs.role_id=r.role_id and r.is_active=1 and r.deleted_on is null
  where left(pd.[CLIENT_PATIENT_ID],3)='536'
	and pd.deleted_on is null
)
----------CARE MANAGER/PARTNER FROM MEMBER_CARESTAFF TABLE
, PrimCM as
(SELECT pd.[CLIENT_PATIENT_ID] as CCAID, pd.[PATIENT_ID] ,mc.[MEMBER_ID], cs.last_name+', '+cs.first_name as PrimCareMgr
-- , cs.Last_name, cs.First_Name, cs.Middle_name
, r.Role_name as PrimCareMgrRole
  FROM  [Altruista].[dbo].[PATIENT_DETAILS] pd 
  inner join [Altruista].[dbo].[MEMBER_CARESTAFF] mc on pd.patient_id=mc.patient_id
  inner join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on mc.member_id=cs.member_id 
  left join [Altruista].[dbo].Role r on cs.role_id=r.role_id and r.is_active=1 and r.deleted_on is null
  where left(pd.[CLIENT_PATIENT_ID],3)='536' and mc.is_active=1 and mc.is_primary=1
	)

select pc.ccaid, pc.Patient_ID, pc.member_ID as PrimCareMgrID, pc.PrimCareMgr, pc.PrimCareMgrRole
, pcs.PhysID, pcs.PhysRole, pcs.First_name, pcs.Last_Name
, case when pc.member_ID=pcs.PhysID then 'Y' else 'N' end as CMtoPhysMatch
, dense_rank() over (partition by pc.ccaid order by case when pc.member_ID=PCS.PhysID then 'Y' else 'N' end desc) as PCMrank
 into #PrimCM
 from PrimCM pc left join PrimCareStaff pcs on pc.ccaid=pcs.ccaid and pc.member_ID=pcs.PhysID
 
-- select * from #PrimCM where PCMrank=1


SELECT
	meh.CCAID
	, meh.NAME_FULL
	,case when product = 'ICO' then 'OneCare' 
	when product = 'SCO' then product end as Product
	,product
	, meh.DOB
	, (0 + CONVERT(CHAR(8), GETDATE(), 112) - CONVERT(CHAR(8), meh.DOB, 112)) / 10000 AS 'age'
	, meh.GENDER
	, meh.lang_spoken
	, meh.lang_written
	, meh.ADDRESS1
	, meh.ADDRESS2
	, meh.CITY
	, meh.addr_start
	, meh.addr_end
	, meh.latest_phone
	, meh.CMO
	, meh.PCL
	, COALESCE(gc.PrimCareMgr, meh.CM) AS 'PrimCareMgr'
	, gc.PrimCareMgrRole
	, (SELECT MAX(CAST([Status_Date] AS DATETIME) + CAST([Status_Time] AS DATETIME)) FROM [PartnerExchange].[ptnpng].[vwPatientPing]) AS 'PatientPing_data_refreshed'
	, pp.[Status] AS 'PatientPing_latest_status'
	, pp.Status_date
	, pp.Status_Time
	, pp.Facility_Name
	, pp.Setting
-- SELECT *
FROM Medical_Analytics.dbo.member_enrollment_history AS meh
LEFT JOIN #PrimCM AS gc
	ON meh.CCAID = gc.CCAID
	AND gc.PCMrank = 1
LEFT JOIN (	-- latest entry in PatientPing
	SELECT
		p1.Patient_ID
		, p1.[Status]
		, p1.Status_date
		, p1.Status_Time
		, p1.Facility_Name
		, p1.Setting
	-- SELECT TOP 100 *
	FROM PartnerExchange.ptnpng.vwPatientPing AS p1
	INNER JOIN PartnerExchange.ptnpng.vwPatientPing AS p2
		ON p1.Patient_ID = p2.Patient_ID
	GROUP BY
		p1.Patient_ID
		, p1.[Status]
		, p1.Status_date
		, p1.Status_Time
		, p1.Facility_Name
		, p1.Setting
	HAVING MAX(CAST(p2.[Status_Date] AS DATETIME) + CAST(p2.[Status_Time] AS DATETIME)) = CAST(p1.[Status_Date] AS DATETIME) + CAST(p1.[Status_Time] AS DATETIME)
) AS pp
	ON meh.CCAID = pp.Patient_ID
WHERE
 meh.enroll_status2 = 'current member'
	AND
	 meh.latest_enr_mo = 1
	AND meh.[ADDRESS1] LIKE '4%Capen%'
	--AND meh.CITY in ('Stoughton')
ORDER BY
	meh.CCAID


/*	-- PatientPing

SELECT *
FROM PartnerExchange.sys.objects
WHERE SCHEMA_ID IN (SELECT schema_id FROM PartnerExchange.sys.schemas WHERE name = 'ptnpng')

SELECT TOP 1000 * FROM [PartnerExchange].[ptnpng].[PtnPngRosterInbd] ORDER BY [EVENT_DATE] DESC, [ROSTER_PATIENT_ID]
SELECT TOP 1000 * FROM [PartnerExchange].[ptnpng].[PatientPing] ORDER BY [Status_Date] DESC, [Patient_ID]
SELECT TOP 1000 * FROM [PartnerExchange].[ptnpng].[vwPatientPing] ORDER BY [Status_Date] DESC, [Patient_ID]

SELECT MAX([EVENT_DATE]) FROM [PartnerExchange].[ptnpng].[PtnPngRosterInbd]
SELECT MAX([Status_Date]) FROM [PartnerExchange].[ptnpng].[PatientPing]
SELECT MAX([Status_Date]) FROM [PartnerExchange].[ptnpng].[vwPatientPing]
*/


