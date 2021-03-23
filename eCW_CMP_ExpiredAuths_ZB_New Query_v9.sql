--pulling current care manager info from GuidingCare. This will be used later in this process

begin try
  drop table #primcm
end try
begin catch
end catch

; with PrimCareStaff as (
     SELECT 
            pd.[CLIENT_PATIENT_ID] as CCAID
            , pd.[PATIENT_ID]
            , pp.[PHYSICIAN_ID] as PhysID
            ,r.Role_name as PhysRole
            , [TITLE]
            , cs.[FIRST_NAME]
            , cs.[LAST_NAME]
            ,cs.PRIMARY_PHONE
            ,cs.MOBILE_PHONE
            ,cs.PRIMARY_EMAIL
     FROM [Altruista].[dbo].[PATIENT_DETAILS] pd 
     inner join [Altruista].[dbo].[PATIENT_PHYSICIAN] pp on pd.patient_id=pp.patient_ID
            and pp.care_team_id=1 and pp.is_active=1 and pp.deleted_on is null
     inner join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on pp.physician_id=cs.member_id 
     left join altruista.dbo.role r on cs.role_id=r.role_id and r.is_active=1 and r.deleted_on is null
     where left(pd.[CLIENT_PATIENT_ID],3)='536'
            and pd.deleted_on is null
), PrimCM as (
     SELECT 
            pd.[CLIENT_PATIENT_ID] as CCAID
            , pd.[PATIENT_ID] 
            ,mc.[MEMBER_ID]
            , cs.last_name+', '+cs.first_name as PrimCareMgr
            , r.Role_name as PrimCareMgrRole
            ,cs.PRIMARY_PHONE
            ,cs.MOBILE_PHONE
            ,cs.PRIMARY_EMAIL
     FROM  [Altruista].[dbo].[PATIENT_DETAILS] pd 
     inner join [Altruista].[dbo].[MEMBER_CARESTAFF] mc on pd.patient_id=mc.patient_id
     inner join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on mc.member_id=cs.member_id 
     left join [Altruista].[dbo].Role r on cs.role_id=r.role_id and r.is_active=1 and r.deleted_on is null
     where left(pd.[CLIENT_PATIENT_ID],3)='536' and mc.is_active=1 and mc.is_primary=1
)
select 
     pc.ccaid
     , pc.Patient_ID
     , pc.member_ID as PrimCareMgrID
     , pc.PrimCareMgr
     , pc.PrimCareMgrRole
     , pcs.PhysID, pcs.PhysRole
     , pcs.First_name, pcs.Last_Name
     ,pcs.PRIMARY_PHONE
     ,pcs.MOBILE_PHONE
     ,pcs.PRIMARY_EMAIL
     , case when pc.member_ID=pcs.PhysID then 'Y' else 'N' end as CMtoPhysMatch
     , dense_rank() over (partition by pc.ccaid order by case when pc.member_ID=PCS.PhysID then 'Y' else 'N' end desc) as PCMrank
into #PrimCM
from PrimCM pc 
left join PrimCareStaff pcs on pc.ccaid=pcs.ccaid and pc.member_ID=pcs.PhysID

begin try
  drop table #t1
end try
begin catch
end catch

--pulling auth id, auth start/end dates, patient id (later to be convert to CCA ID), referred_to facility from ECW. Referrals only pulled with a service end date of 100 days ago (relative to today) and onward to shorten query time

SELECT * 
into #t1 
FROM OPENQUERY(srvmedecwrep01, 'SELECT 
r.ReferralId
, patientID
, insId
, refFrom
, authNo
, cast(date as char(20)) as date
, reason
, diagnosis
, cast(refStDate as char(20)) as refStDate
, cast(refEnddate as char(20)) as refEnddate
, visitsAllowed
, visitsUsed
, RefTo
/*,  notes */
, deleteFlag
, referralType
, priority
, assignedTo
, assignedToId
, status
, authtype
, procedures
, fromfacility
, ToFacility
, speciality
, POS
, UnitType
, FrontOfficeAuth
, ReferralNumber
, cast(apptDate as char(20)) as apptDate
, clinicalNotes
, cast(ReceivedDate as char(20)) as ReceivedDate
, refEncId
, ApptTime
, extNHXApptBlockId
, extNHXRefTxId
, refReqId
, refFromP2pNPI
, refFromName
, refToP2pNPI
, refToName
, uploadedToPtDocs
, cast(modifiedDate as char(20)) as modifiedDate
, refToCCNameList
, refToCCNPIList
, p2pDeliveryStatus
, cast(statusUpdateDate as char(20)) as statusUpdateDate
, ccdaValidationStatus
, fromDirectAddress
, toDirectAddress
, decis.value ServiceDecision
,inv.value
,case when exped.value = 1 then 1 else 0 end as Expedited
FROM referral r
left outer join structreferraloutgoing decis  on r.referralID=decis.referralID and decis.detailID=662001
 left outer join structreferraloutgoing inv on r.referralID=inv.referralID and inv.detailID=1213614 
 left outer join structreferraloutgoing exped on r.referralID=exped.referralID and exped.detailID=1213623
where deleteflag = 0 and  (inv.value <> ''Yes'' or inv.value is null) and reason not like ''inval%''
/* and r.referralID = 14258385 */
and decis.value not in ( ''Withdrawal'',''Denied'',''Termination'',''Recoupment'')
and refEnddate >= date_add(NOW(), INTERVAL -100 DAY)
')


--pulling additional referral info, like procedure code

begin try
  drop table #ecw_edi_278_cpt
end try
begin catch
end catch



SELECT *
into #ecw_edi_278_cpt   
FROM OPENQUERY(srvmedecwrep01, 'SELECT cpt.ReferralID as joinRefID
, cpt.id as Auth_ID -- unique ID for Auth
, id.value as service -- procedure code
, cpt.UnitsApproved as Auth_Quantity
, cpt.SAId
, cpt.CPTId
, cpt.UnitsRequested
, cpt.UnitsApproved
, cpt.deleteFlag
FROM edi_278_cpt as cpt 
INNER JOIN items as it 
ON it.itemID = cpt.CPTID
INNER JOIN itemdetail as id 
ON id.itemID = it.itemID
INNER JOIN properties as prop 
ON prop.propID = id.propID
WHERE id.propID = 13 
and ltrim(rtrim(id.value)) in (''99456'',''H0038'',''H0043'',''H2014'',''S5100'',''S5102'',''S5110'',''S5120'',''S5121'',''S5130'',''S5131'',''S5135'',''S5140'',''S5161''
						,''S5170'',''S5175'',''S5185'',''T1004'',''T1019'',''T1023'',''T2020'',''T2021'',''T2022'',''T2031'',''T1030'',''T1031'',''T2003'',''A0100'', ''120'', ''191''
					)

;') as cpt


--patient ID CCAID crosswalk

begin try
  drop table #ecw_patientid_ccaid
end try
begin catch
end catch



select *
into #ecw_patientid_ccaid
from 
openquery
(
SRVMEDECWREP01, 'select pid as patientid
,HL7Id as CCAID
, ControlNo as ecwAccountNo
from patients
where HL7Id <> ''''
group by pid
,HL7Id 
,ControlNo
'
) 

--next, I pull units info, starting with visits

begin try
  drop table #ecwunits1
end try
begin catch
end catch

select *

into #ecwunits1
 
FROM OPENQUERY(srvmedecwrep01, 'SELECT 
r.ReferralId
, patientID
, insId
, refFrom
, authNo
, cast(date as char(20)) as date
, reason
, diagnosis
, cast(refStDate as char(20)) as refStDate
, cast(refEnddate as char(20)) as refEnddate
, visitsAllowed
, visitsUsed
, RefTo
/*,  notes */
, deleteFlag
, referralType
, priority
, assignedTo
, assignedToId
, status
, authtype
, procedures
, fromfacility
, ToFacility
, speciality
, POS
, UnitType
, FrontOfficeAuth
, ReferralNumber
, cast(apptDate as char(20)) as apptDate
, clinicalNotes
, cast(ReceivedDate as char(20)) as ReceivedDate
, refEncId
, ApptTime
, extNHXApptBlockId
, extNHXRefTxId
, refReqId
, refFromP2pNPI
, refFromName
, refToP2pNPI
, refToName
, uploadedToPtDocs
, cast(modifiedDate as char(20)) as modifiedDate
, refToCCNameList
, refToCCNPIList
, p2pDeliveryStatus
, cast(statusUpdateDate as char(20)) as statusUpdateDate
, ccdaValidationStatus
, fromDirectAddress
, toDirectAddress
, decis.value ServiceDecision
,inv.value
,case when exped.value = 1 then 1 else 0 end as Expedited
FROM referral r
left outer join structreferraloutgoing decis  on r.referralID=decis.referralID and decis.detailID=662001
 left outer join structreferraloutgoing inv on r.referralID=inv.referralID and inv.detailID=1213614 
 left outer join structreferraloutgoing exped on r.referralID=exped.referralID and exped.detailID=1213623
where deleteflag = 0 and  (inv.value <> ''Yes'' or inv.value is null) and reason not like ''inval%''
/* and r.referralID = 14258385 */
and decis.value not in ( ''Withdrawal'',''Denied'',''Termination'',''Recoupment'')
and refEnddate >= date_add(NOW(), INTERVAL -100 DAY)
') 

--pulling units approved


begin try
  drop table #ecwunits2
end try
begin catch
end catch

select *

into #ecwunits2

 
FROM OPENQUERY(srvmedecwrep01, 'SELECT cpt.ReferralID as joinRefID
, cpt.id as Auth_ID -- unique ID for Auth
, id.value as service -- procedure code
, cpt.UnitsApproved as Auth_Quantity
, cpt.SAId
, cpt.CPTId
, cpt.UnitsRequested
, cpt.UnitsApproved
, cpt.deleteFlag
FROM edi_278_cpt as cpt 
INNER JOIN items as it 
ON it.itemID = cpt.CPTID
INNER JOIN itemdetail as id 
ON id.itemID = it.itemID
INNER JOIN properties as prop 
ON prop.propID = id.propID
WHERE id.propID = 13
and id.value in (''99456'',''H0038'',''H0043'',''H2014'',''S5100'',''S5102'',''S5110'',''S5120'',''S5121'',''S5130'',''S5131'',''S5135'',''S5140'',''S5161''
						,''S5170'',''S5175'',''S5185'',''T1004'',''T1019'',''T1023'',''T2020'',''T2021'',''T2022'',''T2031'',''T1030'',''T1031'',''120'',''191'',''T2003'',''A0100'')

;') 

--final ecw units step, which gives priority to Visits for eCW auths

begin try
  drop table #ecwunits
end try
begin catch
end catch


SELECT DISTINCT
e1.ReferralId,
e2.service,
case 
when e1.visitsAllowed = 0 OR e1.visitsAllowed is NULL then e2.unitsapproved else e1.visitsallowed 
end as units_approved,
e1.refstdate,
e1.refenddate

into #ecwunits

from #ecwunits1 e1
inner join #ecwunits2 e2
on e1.ReferralId = e2.joinRefID

--selecting relevant fields, UNION with CMP auths. CMP auths also capped within 100 days for service_to_date

begin try
  drop table #expiring_auths
end try
begin catch
end catch

select DISTINCT
'eCW' as Source,
Convert(varchar,a.ReferralId,101) as Expiring_Auth_ID,
c.ccaid as CCAID,
a.refstdate as refstdate_dt,
a.refenddate as refenddate_dt,
a.reftoname as provider,
b.service as proc_code,
d.units_approved as units_approved
into #expiring_auths
from #t1 a
inner join #ecw_edi_278_cpt b
on a.ReferralId = b.joinrefID and b.deleteflag = 0
left join #ecw_patientid_ccaid c
on a.patientID = c.patientID
left join #ecwunits d
on a.ReferralId = d.ReferralId and ltrim(rtrim(b.service)) = ltrim(rtrim(d.service)) and a.refstdate = d.refstdate and a.refenddate = d.refenddate

UNION

select DISTINCT
'CMP' as Source,
a.auth_id as Expiring_Auth_ID,
pd.[CLIENT_patient_ID] as CCAID
, ud.[SERVICE_FROM_DATE] AS refstdate_dt
, ud.[SERVICE_TO_DATE] AS refenddate_dt
,coalesce(prov.provider_name,fac.provider_name) as provider
, case when coalesce (s.SERVICE_CODE, sv.proc_code) in ('0191','0120') 
then right (coalesce (s.SERVICE_CODE, sv.proc_code),3) 
else coalesce (s.SERVICE_CODE, sv.proc_code) end as proc_code
,ud.current_approved as units_approved
from [Altruista].dbo.um_auth a
left join  [Altruista].[dbo].[patient_details] pd on a.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
left join [Altruista].[dbo].UM_AUTH_PROVIDER prov on a.auth_no = prov.auth_no  and prov.provider_type_id = 3 and prov.deleted_on is null
left join [Altruista].[dbo].UM_AUTH_PROVIDER byprov on a.auth_no = byprov.auth_no  and byprov.provider_type_id = 2 and byprov.deleted_on is null
left join [Altruista].[dbo].UM_AUTH_CODE Pac on  a.auth_no  = Pac.auth_no and AUTH_CODE_TYPE_ID in ( 1,5) and pac.deleted_on is null
left join [Altruista].[dbo].UM_AUTH_PROVIDER fac on a.auth_no = fac.auth_no  and fac.provider_type_id = 4 and fac.deleted_on is null
left join  [Altruista].[dbo].UM_DECISION ud on  a.auth_no  = ud.auth_no and Pac.auth_code_id = ud.auth_code_id and ud.deleted_on is null
left join  [Altruista].[dbo].UM_MA_PROCEDURE_CODES sv on Pac.auth_code_ref_id = sv.PROC_CODE and sv.PROC_CATEGORY_ID in (1,2, 3,7) and sv.deleted_on is null 
left join [Altruista].[dbo].[SERVICE_CODE] s on pac.[AUTH_CODE_REF_ID]=cast (s.SERVICE_ID as varchar) and pac.[AUTH_CODE_type_ID]=5 and s.deleted_on is null
left join  [Altruista].[dbo].UM_MA_PROCEDURE_CODES svc on  s.service_code = svc.proc_code  and svc.deleted_on is null
left join [Altruista].[dbo].[UM_MA_AUTH_STATUS] stat on a.AUTH_STATUS_ID = stat.AUTH_STATUS_ID and stat.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS decs on ud.DECISION_status = decs.DECISION_STATUS_ID and decs.deleted_on is null

where 
stat.auth_status not in ('Cancelled','Closed and Cancelled', 'Withdrawn')
and decs.decision_Status not in ('Void','Denied')
and coalesce (s.SERVICE_CODE, sv.proc_code) in ('99456','H0038','H0043','H2014','S5100','S5102','S5110','S5120 ','S5121','S5130','S5131','S5135','S5140','S5161'
						,'S5170','S5175','S5185','T1004','T1019','T1023','T2020','T2021','T2022','T2031','T1030','T1031','0120','0191','T2003','A0100')
and ud.[SERVICE_TO_DATE] >= dateadd(day,-100,getdate())
and pd.[CLIENT_patient_ID] like '53%'


--adding additional fields needed for expiring auths report

begin try
  drop table #fieldsadded
end try
begin catch
end catch

select DISTINCT
a.Source,
getdate() as Run_Date,
a.Expiring_Auth_ID,
case when a.proc_code in ('0120','0191','120','191') and meh.CMO = 'Element Care' then 'Element Care'
when a.proc_code in ('0120','0191','120','191') and meh.CMO <> 'Element Care' OR meh.CMO is NULL then 'Care Transitions SNF-LTC'
when meh.product = 'SCO' then meh.ASAP_name
when meh.product = 'ICO' then meh.CMO
else meh.CMO 
end as responsible_party,
meh.CMO as CareMgrOrg,
p.primcaremgr as CareManager,
meh.ASAP_name as ASAP,
case when coord.provider_name is NOT NULL then concat(coord.provider_name,'/',coord.provider_type) else NULL end as GSSC_or_LTSS,
meh.product,
meh.name_last,
meh.name_first,
a.CCAID,
meh.DOB,
a.provider,
a.proc_code,
a.units_approved,
a.refstdate_dt,
a.refenddate_dt,
getdate() as report_date,
case when datediff(day,a.refenddate_dt,getdate())  < 0 then 'expires in ' + cast(abs(datediff(day,a.refenddate_dt,getdate())) as varchar) + ' days'
		else 'expired ' + cast(abs(datediff(day,a.refenddate_dt,getdate())) as varchar) + ' days ago' end as [expire descr],
datediff(day,a.refenddate_dt,getdate()) as [days_since_refenddate],
case when da.ccaid is null then 0 else 1 end as Renewed_Auth_Flag,
da.Expiring_Auth_ID as Renewed_Auth_ID
into #fieldsadded
from #expiring_auths a
inner join member_enrollment_history meh on a.ccaid = meh.ccaid
and meh.relmo = 0 and meh.enroll_status = 'current member'
left join
(
select
md.[PROVIDER_NAME],
        pd.[PATIENT_ID]
        , pt.provider_type
        ,pp.provider_type_id
        ,pd.[CLIENT_PATIENT_ID] as CCAID
		,pp.created_on
		, ROW_NUMBER() OVER(PARTITION BY pd.client_patient_id ORDER BY pp.created_on desc) 
    AS Row

  FROM   [Altruista].[dbo].[PATIENT_DETAILS] pd
  

left join   [Altruista].[dbo].[PATIENT_PHYSICIAN] pp on pd.PATIENT_ID = pp.patient_id
   left join [Altruista].[dbo].[PHYSICIAN_DEMOGRAPHY] md on pp.physician_id = md.physician_id
left join [Altruista].[dbo].[PROVIDER_TYPE] pt on pp.provider_type_id = pt.provider_type_id
where pt.PROVIDER_TYPE_ID in ('119','183')
and CAST(GETDATE() AS DATE) BETWEEN pp.[START_DATE] and pp.END_DATE and
                    pp.DELETED_ON IS NULL AND
                    pp.IS_ACTIVE = 1
					and md.[PROVIDER_NAME] is not NULL) coord 
on a.ccaid = coord.ccaid and coord.row = 1
left join #primcm p
on a.ccaid = p.ccaid
left join #expiring_auths da on a.ccaid = da.ccaid AND isnull(a.proc_code,0) = isnull(da.proc_code,0) AND dateadd(day,1,a.refenddate_dt) = da.refstdate_dt


--consolidating renewed_auth_ids into 1 field when all other fields match, to get rid of duplicate lines

begin try
  drop table #finalreport2
end try
begin catch
end catch

SELECT
main.source,
main.Run_Date
,main.Expiring_Auth_ID 
,main.responsible_party
,main.CareMgrOrg
,main.CareManager
,main.ASAP
,main.GSSC_or_LTSS
,main.product
,main.name_last
,main.name_first
,main.CCAID
,main.DOB
,main.provider
,main.proc_code
,main.units_approved
,main.refstdate_dt
,main.refenddate_dt
,main.report_date
,main.[expire descr]
,main.days_since_refenddate
,main.Renewed_Auth_Flag
,case when Len(main.Renewed_Auth_ID) < 1  then NULL else LEFT(main.Renewed_Auth_ID,Len(main.Renewed_Auth_ID)-1) end As "Renewed_Auths"
into #finalreport2
from
(select distinct
e3.source,
e3.Run_Date
,e3.Expiring_Auth_ID
,e3.responsible_party
,e3.CareMgrOrg
,e3.CareManager
,e3.ASAP
,e3.GSSC_or_LTSS
,e3.product
,e3.name_last
,e3.name_first
,e3.CCAID
,e3.DOB
,e3.provider
,e3.proc_code
,e3.units_approved
,e3.refstdate_dt
,e3.refenddate_dt
,e3.report_date
,e3.[expire descr]
,e3.days_since_refenddate
,e3.Renewed_Auth_Flag
,
        (SELECT z.renewed_auth_id + ',' as [text()]
		from #fieldsadded z
		where z.Source = e3.Source 
		and isnull(z.run_date,1) = isnull(e3.run_date,1)
		and isnull(z.expiring_auth_id,1) = isnull(e3.expiring_auth_id,1)
		and isnull(z.responsible_party,1) = isnull(e3.responsible_party,1)
		and isnull(z.caremgrorg,1) = isnull(e3.caremgrorg,1)
		and isnull(z.CareManager,1) = isnull(e3.CareManager,1)
		and isnull(z.asap,1) = isnull(e3.asap,1)
		and isnull(z.GSSC_or_LTSS,1) = isnull(e3.GSSC_or_LTSS,1)
		and isnull(z.product,1) = isnull(e3.product,1)
		and isnull(z.NAME_last,1) = isnull(e3.NAME_last,1)
		and isnull(z.NAME_first,1) = isnull(e3.NAME_first,1)
		and isnull(z.ccaid,1) = isnull(e3.ccaid,1)
		and isnull(z.provider,1) = isnull(e3.provider,1)
		and isnull(z.proc_code,1) = isnull(e3.proc_code,1)
		and isnull(z.refstdate_dt,1) = isnull(e3.refstdate_dt,1)
		and isnull(z.refenddate_dt,1) = isnull(e3.refenddate_dt,1)
		and isnull(z.report_date,1) = isnull(e3.report_date,1)
		and isnull(z.[expire descr],1) = isnull(e3.[expire descr],1)
		and isnull(z.[days_since_refenddate],1) = isnull(e3.[days_since_refenddate],1)
		and isnull(z.Renewed_Auth_Flag,1) = isnull(e3.Renewed_Auth_Flag,1)
		order by z.expiring_auth_id, z.proc_code
		FOR XML PATH ('')
		) renewed_auth_id
		from #fieldsadded e3
		) main



--pulling report for date range 30 days in the past and 30 days in the future

SELECT DISTINCT
 *
from #finalreport2
where days_since_refenddate between -30 and 30
ORDER BY refenddate_dt asc, ccaid
