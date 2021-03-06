
----------------------- providers

IF OBJECT_ID('tempdb..#providers') IS NOT NULL DROP TABLE #providers;

----this logic on providers is taken from Altruista
USE [Altruista]  
GO

create table #providers
(auth_no bigint not null
,referred_by_provider_id bigint null
,referred_to_provider_id bigint null
,facility_provider_id bigint null
,referred_by_provider_code nvarchar(50)
,referred_to_provider_code nvarchar(50)
,facility_provider_code nvarchar(50)
,referred_by_provider_name nvarchar(1000)
,ref_by_validity_from datetime null
,ref_by_validity_to datetime null
--,ref_by_lob_id bigint null
,ref_by_provider_capacity nvarchar(50) null
,referred_to_provider_name nvarchar(1000)
,ref_to_validity_from datetime null
,ref_to_validity_to datetime null
--,ref_to_lob_id bigint null
,ref_to_provider_capacity nvarchar(50) null
,facility_provider_name nvarchar(1000)
,facility_validity_from datetime null
,facility_validity_to datetime null
--,facility_lob_id bigint null
,facility_provider_capacity nvarchar(50) null
)
insert into #providers
(auth_no
,referred_by_provider_id
,referred_to_provider_id
,facility_provider_id
,referred_by_provider_code
,referred_to_provider_code
,facility_provider_code
,referred_by_provider_name
,ref_by_validity_from
,ref_by_validity_to
--,ref_by_lob_id
,ref_by_provider_capacity
,referred_to_provider_name
,ref_to_validity_from
,ref_to_validity_to
--,ref_to_lob_id
,ref_to_provider_capacity
,facility_provider_name
,facility_validity_from
,facility_validity_to
--,facility_lob_id
,facility_provider_capacity
)

select distinct
piv.auth_no
,piv."2" as referred_by_provider_id
,piv."3" as referred_to_provider_id
,piv."4" as facility_provider_id
,p2.physician_code as referred_by_provider_code
,p3.physician_code as referred_to_provider_code
,p4.physician_code as facility_provider_code
,uap2.provider_name as referred_by_provider_name
,pn2.validity_from as ref_by_validity_from
,pn2.validity_to as ref_by_validity_to
--,pn2.lob_id as ref_by_lob_id
,pn2.provider_capacity as ref_by_provider_capacity
,uap3.provider_name as referred_to_provider_name
,pn3.validity_from as ref_to_validity_from
,pn3.validity_to as ref_to_validity_to
--,pn3.lob_id as ref_to_lob_id
,pn3.provider_capacity as ref_to_provider_capacity
,uap4.provider_name as facility_provider_name
,pn4.validity_from as facility_validity_from
,pn4.validity_to as facility_validity_to
--,pn4.lob_id as facility_lob_id
,pn4.provider_capacity as facility_provider_capacity
from
(
select
a.auth_no
,a.provider_type_id
,a.physician_id
from
(select ap.auth_no
,ap.provider_type_id
,ap.physician_id
,ap.provider_name
from um_auth_provider ap with(nolock)
where ap.deleted_by is null
and ap.deleted_on is null
) a
) src
pivot(
max( physician_id ) for provider_type_id in (
[1]
,[2]
,[3]
,[4]
)
) piv
left join physician_demography p2 with(nolock) on piv."2" = p2.physician_id
left join physician_demography p3 with(nolock) on piv."3" = p3.physician_id
left join physician_demography p4 with(nolock) on piv."4" = p4.physician_id
left join um_auth_provider uap2 with(nolock) on piv.auth_no = uap2.auth_no and uap2.PROVIDER_TYPE_ID = 2
left join um_auth_provider uap3 with(nolock) on piv.auth_no = uap3.auth_no and uap3.PROVIDER_TYPE_ID = 3
left join um_auth_provider uap4 with(nolock) on piv.auth_no = uap4.auth_no and uap4.PROVIDER_TYPE_ID = 4
left join (select distinct p.provider_id,p.validity_from,p.validity_to,p.netwrok_id--,lob_id
,provider_capacity
		from provider_network p with(nolock)
inner join
(select provider_id
,max(netwrok_id) as max_network_id
from Altruista.dbo.provider_network with(nolock)
where is_active = 1
group by provider_id
) src on p.netwrok_id = src.max_network_id 
) pn2 on piv."2" = pn2.provider_id
left join
(select distinct p.provider_id,p.validity_from,p.validity_to,p.netwrok_id--,lob_id
,provider_capacity
from provider_network p with(nolock)
inner join
(select provider_id
,max(netwrok_id) as max_network_id
from Altruista.dbo.provider_network with(nolock)
where is_active = 1
group by provider_id
) src on p.netwrok_id = src.max_network_id 
) pn3 on piv."3" = pn3.provider_id
left join (select distinct p.provider_id,p.validity_from,p.validity_to,p.netwrok_id--,lob_id
,provider_capacity
		from provider_network p with(nolock)
inner join
(select provider_id
,max(netwrok_id) as max_network_id
from Altruista.dbo.provider_network with(nolock)
where is_active = 1
group by provider_id
) src on p.netwrok_id = src.max_network_id 
) pn4 on piv."4" = pn4.provider_id

create clustered index idx_auth_no on #providers(auth_no);

--select * from  #providers
------------------------------ Auth

IF OBJECT_ID('tempdb..#auth') IS NOT NULL DROP TABLE #auth;

select distinct
pd.[LAST_NAME] 
,pd.[FIRST_NAME]
,pd.[CLIENT_patient_ID] as CCAID
,pd.patient_id
--,bp.plan_name 
--,case when bp.plan_name in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
--when bp.plan_name in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' else 'Other' end as Contract_ID
, case when l.business_data_name like 'SCO%' then 'SCO'
when l.business_data_name like 'ICO%' then 'ICO'
else 'other' end as plan_name
, case when l.business_data_name in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when l.business_data_name in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
else 'Other' end as Contract_ID
,a.[AUTH_ID]
,A.AUTH_NO
,a.AUTH_NOTI_DATE as Received_date
,stuff ((
SELECT ',' + CAST(AUTH_CODE_REF_ID AS VARCHAR(MAX)) from ---groups all diag codes into one row
(
	select auth_no, [AUTH_CODE_REF_ID] from  [Altruista].[dbo].[UM_AUTH_CODE]
	where [AUTH_CODE_TYPE_ID]=2---diagnosis code
	group by  auth_no, [AUTH_CODE_REF_ID] 
)d where (d.[AUTH_no] =a.[AUTH_no] )
for xml path(''),type).value('(./text())[1]','VARCHAR(MAX)'),1,1,'') AS Diagnosis
	,case 
				when e.referred_to_provider_id is not null 
					and a.AUTH_NOTI_DATE  between e.ref_to_validity_from and e.ref_to_validity_to
					and e.ref_to_provider_capacity = 'PAR'  then 'CP'
				when e.referred_to_provider_id is not null 
					and (a.AUTH_NOTI_DATE  not between e.ref_to_validity_from and e.ref_to_validity_to
							or e.ref_to_validity_from is null) then 'NCP'
				when e.referred_to_provider_id is not null
					and e.ref_to_provider_capacity like '%non%par%' then 'NCP'
				when e.referred_to_provider_id is null 
					and e.facility_provider_code is not null 
					and a.AUTH_NOTI_DATE  between e.facility_validity_from and e.facility_validity_to
					and e.facility_provider_capacity = 'PAR'  then 'CP'
				when e.referred_to_provider_id is null 
					and e.facility_provider_code is not null 
					and (a.AUTH_NOTI_DATE not between e.facility_validity_from and e.facility_validity_to 
							or e.facility_validity_from is null) then 'NCP'
				when e.facility_provider_code is not null
					and e.facility_provider_capacity like '%non%par%' then 'NCP'
			   when decstc.decision_status_code_desc like '%Out of Network%' 
			  or decstc.decision_status_code_desc like '%Non PAR Provider%' then 'NCP' 
			
			else NULL end	[Provider Type]	--H  

into #auth
from [Altruista].[dbo].UM_AUTH a
--left join [Altruista].[dbo].[lob_benf_plan] lb on a.[LOB_BEN_ID] = lb.lob_ben_id and lb.deleted_on is null
--left join  [Altruista].[dbo].[lob] l on lb.[LOB_ID] = l.lob_id and l.deleted_on is null
--LEFT JOIN [Altruista].[dbo].[benefit_plan] bp ON lb.[BENEFIT_PLAN_ID] = bp.[BENEFIT_PLAN_ID] and bp.deleted_on is null
left join [Altruista].[dbo].CMN_MA_BUSINESS_HIERARCHY lb on a.[LOB_BEN_ID] = lb.lob_ben_id and lb.deleted_on is null
LEFT JOIN [Altruista].dbo.CMN_MA_BUSINESS_DATA AS l ON lb.BUSINESS_DATA_ID = l.BUSINESS_DATA_ID AND l.DELETED_ON IS NULL
left join  [Altruista].[dbo].UM_AUTH_CODE Pac on  a.auth_no  = Pac.auth_no and AUTH_CODE_TYPE_ID in ( 1,5) and pac.deleted_on is null-- splits the auth into auth lines
left join  [Altruista].[dbo].[patient_details] pd on a.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
left join  [Altruista].[dbo].UM_DECISION ud on  a.auth_no  = ud.auth_no and Pac.auth_code_id = ud.auth_code_id and ud.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS decs on ud.DECISION_status = decs.DECISION_STATUS_ID and decs.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS_codes decstc on ud.DECISION_status_code_id = decstc.DECISION_STATUS_code_ID and decstc.deleted_on is null
left join #providers e on a.auth_no = e.auth_no
where --LOB_name = 'Medicare-Medicaid Duals' 
--pd.last_name not like '%test%'
--and 
pd.[CLIENT_patient_ID] like '53%'--picking up ccaids only and not test cases
--and decs.decision_Status in ('approved')
--and auth_priority in ('Prospective Standard','Prospective Expedited')
--**and auth_status in ('close','closed and adjusted','open','reopen', 'reopen and close')--Sara confirmed these statuses with Amelia on November 29. 2018
--and auth_status not like '%cancel%'
--and (decs.DECISION_STATUS <> 'Void' or decs.decision_status is null)
--and a.deleted_on is null  --  excludes deleted auths
--and bp.plan_name in ('SCO-Externally Managed', 'SCO-CCA Managed')
--select * from #auth
-- select * from [Altruista].[dbo].UM_AUTH where auth_no = '48380'

--select distinct Contract_ID, count(*) from #auth group by Contract_ID

---------------------- TABLE 5


select 
pd.FIRST_NAME  as 'Beneficiary First Name'
,pd.last_name as 'Beneficiary Last Name'
,adsm.MedicareMBI as 'Enrollee ID'
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end as Contract_ID
,'001' as [Plan ID]
,cur.[COMPLAINT_RECORD_ID] as [Authorization or Claim Number]
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end as [Who made the request?]
,a.[Provider Type] as [Provider Type]
,cur.[RECEIVED_DATE] as [Date the request was received]
,a.diagnosis
,cur.[COMPLAINT_CATEGORY] as [Issue description and type of service]
,'N' as [Was request made under the expedited timeframe but processed by the plan under the standard timeframe?]
--,case when cur.complaint_class like 'expedited%' then (case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end) 
--else 'NA' 
--end as [Request for expedited timeframe]
, case when cur.IS_EXTENDED = 0 then 'NA' else 'Y' end as [Request for expedited timeframe]
,case when cur.IS_EXTENDED = 0 then 'N' else 'Y' end as [Was a timeframe extension taken?]
,case when cur.is_extended = 0 then 'NA' else 'Y' end as [If an extension was taken?]
,case when [OUTCOME_CATEGORY] like '%Approv%' then 'approved'
when [OUTCOME_CATEGORY] like '%denied%' then 'denied with IRE auto forward' 
else [OUTCOME_CATEGORY] 
end as [Request Disposition]
,[RESOLUTION_DATE] as [Date of sponsor decision]
--,case when [OUTCOME_CATEGORY] like '%denied%' and [OUTCOME_SUBCATEGORY] = 'Not Medically Necessary' then 'Y'
--when [OUTCOME_CATEGORY] like '%denied%' and [OUTCOME_SUBCATEGORY] <> 'Not Medically Necessary' then 'N'
--else 'NA' end as [If denied for lack of medical necessity, was the review completed by a physician or other appropriate health care professional?]
,'Y' as [Was the organization determination denied for lack of medical necessity?]
,min(letter.created_on) as [Date written notification provided to enrollee/provider] 
,min(effect.created_on) as [Date service authorization entered/effectuated in the sponsor's system]
,case when [OUTCOME_CATEGORY] like '%denied%' then convert(varchar(10), letter.created_on, 111) else 'NA' end as [Date forwarded to IRE if denied or untimely]
--,'' as [If request denied or untimely, date enrollee notified request has been forwarded to IRE]
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 111) end as [AOR Receipt date] 
,'NA' as [First Tier, Downstream, and Related Entity]
,coalesce(c.auth_id,xad.auth_id) as AuthID, cur.episode_name
,pd.[CLIENT_patient_ID] as CCAID
--,case when lob_name = 'Medicare-Medicaid Duals' then 'Dual'
--when lob_name = 'Managed Medicaid' then 'MH Only' else 'Missing' end as Enrollment

FROM [Altruista].[dbo].[VW_RPT_COMPLAINT_UNIVERSE_REG_RPT] cur
join  [Altruista].[dbo].[ag_auth_complaint] c  
on cur.complaint_record_id = c.complaint_record_id
left join [Altruista].[dbo].[ag_external_auth_details_v] xad on cur.complaint_record_id = xad.complaint_record_id
left join #AUTH a 
on c.auth_id = a.[AUTH_ID] --and r.date_of_service_start_date = a.service_from_date and r.date_of_service_end_date = a.service_to_date
left join  [Altruista].[dbo].[patient_details] pd on cur.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
left join #AUTH xa 
on xad.auth_id = xa.[AUTH_ID] 
--left join [Altruista].[dbo].[LOB] lob on cur.LOB_ID = lob.lob_id

left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] letter
on cur.complaint_record_id = letter.complaint_record_id and letter.action_type = 'Appeal Decision Letter Sent'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] effect
on cur.complaint_record_id = effect.complaint_record_id and effect.action_type = 'Effectuation Entered'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] ire
on cur.complaint_record_id = ire.complaint_record_id and ire.action_type = 'IRE Autoforward'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] aor
on cur.complaint_record_id = aor.complaint_record_id and aor.action_type = 'AOR Received'
left join #providers e 
on a.auth_no = e.auth_no
left join [Actuarial_Services].[dbo].[ADS_Members] adsm
on pd.[CLIENT_patient_ID] = adsm.ccaid

where cur.complaint_class = 'Standard Appeal'--like '%appeal%'
and cur.outcome_category <> 'improperly filed'
and (cur.resolution_date between '2020-10-01' and '2020-12-31' or cur.due_date between '2020-10-01' and '2020-12-31') 
and cur.[COMPLAINT_CATEGORY] not in ('Other - MH Appeal','Part D - Appeal')
--and (episode_name not in ('dental','pca','Homemaker Services') or episode_name is null)
and [OUTCOME_CATEGORY] not in ('Dismissed','Withdrawn')
and (a.plan_name like 'SCO%' or a.plan_name is null)

group by adsm.MedicareMBI  
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end
,cur.[COMPLAINT_RECORD_ID]  
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end  
,a.[Provider Type]  
,cur.[RECEIVED_DATE]  
,a.diagnosis
,cur.[COMPLAINT_CATEGORY]  
 
, case when cur.IS_EXTENDED = 0 then 'NA' else 'Y' end 
,case when cur.IS_EXTENDED = 0 then 'N' else 'Y' end  
,case when cur.is_extended = 0 then 'NA' else 'Y' end  
,case when [OUTCOME_CATEGORY] like '%Approv%' then 'approved'
when [OUTCOME_CATEGORY] like '%denied%' then 'denied with IRE auto forward' 
else [OUTCOME_CATEGORY] 
end  
,[RESOLUTION_DATE]  
,case when [OUTCOME_CATEGORY] like '%denied%' then convert(varchar(10), letter.created_on, 111) else 'NA' end  
--,'' as [If request denied or untimely, date enrollee notified request has been forwarded to IRE]
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 111) end  
,pd.first_name
,coalesce(c.auth_id,xad.auth_id), cur.episode_name
,pd.[CLIENT_patient_ID]
,pd.last_name
--,lob_name

order by 1, 4 --r.complaint_record_id


---------------------- TABLE 6

select 
pd.FIRST_NAME  as 'Beneficiary First Name'
,pd.last_name as 'Beneficiary Last Name'
,adsm.MedicareMBI as 'Enrollee ID'
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end as Contract_ID
,'001' as [Plan ID]
,cur.[COMPLAINT_RECORD_ID] as [Authorization or Claim Number]
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end as [Who made the request?]
,a.[Provider Type] as [Provider Type]
,cast(cur.[RECEIVED_DATE] as date) as [Date the request was received]
,cast(cur.[RECEIVED_DATE] as time) as [Time the request was received] ----------
,a.diagnosis
,cur.[COMPLAINT_CATEGORY] as [Issue description and type of service]
,case when cur.complaint_class like 'expedited%' then (case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end) 
else 'NA' 
end as [Request for expedited timeframe]	
--, case when cur.IS_EXTENDED = 0 then 'NA' else 'Y' end as [Request for expedited timeframe]
,case when cur.IS_EXTENDED = 0 then 'N' else 'Y' end as [Was a timeframe extension taken?]
,case when cur.is_extended = 0 then 'NA' else 'Y' end as [If an extension was taken?]
,case when [OUTCOME_CATEGORY] like '%Approv%' then 'approved'
when [OUTCOME_CATEGORY] like '%denied%' then 'denied with IRE auto forward' 
else [OUTCOME_CATEGORY] 
end as [Request Disposition]
,convert(varchar(10), [RESOLUTION_DATE], 111) as [Date of sponsor decision]
,convert(varchar(10), [RESOLUTION_DATE], 114) as [Time of sponsor decision] ----------
--,'' as [Was request made under the expedited timeframe but processed by the plan under the standard timeframe?]
,'Y' as [Was the organization determination denied for lack of medical necessity?]

--,case when [OUTCOME_CATEGORY] like '%denied%' and [OUTCOME_SUBCATEGORY] = 'Not Medically Necessary' then 'Y'
--when [OUTCOME_CATEGORY] like '%denied%' and [OUTCOME_SUBCATEGORY] <> 'Not Medically Necessary' then 'N'
--else 'NA' end as [If denied for lack of medical necessity, was the review completed by a physician or other appropriate health care professional?]
--,'' as [If the request was denied for lack of medical necessity, was the reconsideration completed by a physician?]
,convert(varchar(10), min(verbal.created_on), 111) as [Date oral notification provided to enrollee] ----------
,convert(varchar(10), min(verbal.created_on), 114) as [Time oral notification provided to enrollee] ----------
,convert(varchar(10), min(letter.created_on), 111) as [Date written notification provided to enrollee/provider] 
--,convert(varchar(10), letter.created_on, 114) as [Time written notification provided to enrollee/provider] ----------
,case when datename(dw, letter.created_on) in ('Monday','Tuesday','Wednesday','Thursday','Friday') then '17:00:00' 
when  datename(dw, letter.created_on) in ('Saturday') then '12:00:00'
else null 
end as [Time written notification provided to enrollee/provider]
,convert(varchar(10), effect.created_on, 111) as [Date service authorization entered/effectuated in the sponsor's system]
,convert(varchar(10), effect.created_on, 114) as [Time service authorization entered/effectuated in the sponsor's system] -----------

,case when [OUTCOME_CATEGORY] like '%denied%' then convert(varchar(10), letter.created_on, 111) else 'NA' end as [Date forwarded to IRE if denied or untimely]
--,'' as [If request denied or untimely, date enrollee notified request has been forwarded to IRE]
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 111) end as [AOR Receipt date] 
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 114) end as [AOR Receipt time] ------------
,'NA' as [First Tier, Downstream, and Related Entity]
--,coalesce(c.auth_id,xad.auth_id), cur.episode_name
--,pd.[CLIENT_patient_ID]
--,case when lob_name = 'Medicare-Medicaid Duals' then 'Dual'
--when lob_name = 'Managed Medicaid' then 'MH Only' else 'Missing' end as Enrollment


FROM [Altruista].[dbo].[VW_RPT_COMPLAINT_UNIVERSE_REG_RPT] cur
join  [Altruista].[dbo].[ag_auth_complaint] c  
on cur.complaint_record_id = c.complaint_record_id
left join [Altruista].[dbo].[ag_external_auth_details_v] xad on cur.complaint_record_id = xad.complaint_record_id

left join #AUTH a 
on c.auth_id = a.auth_id --and r.date_of_service_start_date = a.service_from_date and r.date_of_service_end_date = a.service_to_date

left join  [Altruista].[dbo].[patient_details] pd on cur.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
left join #AUTH xa 
on xad.auth_id = xa.[AUTH_ID] 
--left join [Altruista].[dbo].[LOB] lob on cur.LOB_ID = lob.lob_id

left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] letter
on cur.complaint_record_id = letter.complaint_record_id and letter.action_type = 'Appeal Decision Letter Sent'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] effect
on cur.complaint_record_id = effect.complaint_record_id and effect.action_type = 'Effectuation Entered'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] ire
on cur.complaint_record_id = ire.complaint_record_id and ire.action_type = 'IRE Autoforward'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] aor
on cur.complaint_record_id = aor.complaint_record_id and aor.action_type = 'AOR Received'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] verbal
on cur.complaint_record_id = verbal.complaint_record_id and verbal.action_type = 'Verbal Notification as Required'
left join [Actuarial_Services].[dbo].[ADS_Members] adsm
on pd.[CLIENT_patient_ID] = adsm.ccaid

  where cur.complaint_class = 'Expedited Appeal'--like '%appeal%'
  and cur.outcome_category <> 'improperly filed'
  and (cur.resolution_date between '2020-10-01' and '2020-12-31' or cur.due_date between '2020-10-01' and '2020-12-31') 
  and cur.[COMPLAINT_CATEGORY] not in ('Other - MH Appeal','Part D - Appeal')
	--and (episode_name not in ('dental','pca','Homemaker Services') or episode_name is null)
	and [OUTCOME_CATEGORY] not in ('Dismissed','Withdrawn')
	and (a.plan_name like 'SCO%' or xa.plan_name like 'SCO%' or a.plan_name is null)


group by coalesce(a.[FIRST_NAME],xa.first_name)  
,coalesce(a.[last_NAME],xa.last_name)  
,adsm.MedicareMBI  
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end
,cur.[COMPLAINT_RECORD_ID]  
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end  
,a.[Provider Type]  
,cur.[RECEIVED_DATE]  
,a.diagnosis
,cur.[COMPLAINT_CATEGORY]  
,case when cur.complaint_class like 'expedited%' then (case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end) 
else 'NA' 
end 
, case when cur.IS_EXTENDED = 0 then 'NA' else 'Y' end 
,case when cur.IS_EXTENDED = 0 then 'N' else 'Y' end  
,case when cur.is_extended = 0 then 'NA' else 'Y' end  
,case when [OUTCOME_CATEGORY] like '%Approv%' then 'approved'
when [OUTCOME_CATEGORY] like '%denied%' then 'denied with IRE auto forward' 
else [OUTCOME_CATEGORY] 
end  
,[RESOLUTION_DATE]  
 
,effect.created_on 
,case when [OUTCOME_CATEGORY] like '%denied%' then convert(varchar(10), letter.created_on, 111) else 'NA' end  
--,'' as [If request denied or untimely, date enrollee notified request has been forwarded to IRE]
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 111) end  
,pd.first_name
,coalesce(c.auth_id,xad.auth_id), cur.episode_name
,pd.[CLIENT_patient_ID]
,pd.last_name
--,lob_name
, letter.created_on
, aor.created_on
  order by 1, 4 --r.complaint_record_id


---------------------- TABLE 11

--select *
--FROM [Altruista].[dbo].[VW_RPT_COMPLAINT_UNIVERSE_REG_RPT]
--where complaint_type = 'Grievance'
--and COMPLAINT_class = 'Standard Grievance'

select 
pd.FIRST_NAME  as 'Beneficiary First Name'
,pd.last_name as 'Beneficiary Last Name'
,adsm.MedicareMBI as 'Enrollee ID'
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end as Contract_ID
,'001' as [Plan ID]
--,cur.[COMPLAINT_RECORD_ID] as [Authorization or Claim Number]
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end as [Person who made the rquest]
--,a.[Provider Type] as [Provider Type]
,cur.[RECEIVED_DATE] as [Date the request was received]
--,a.diagnosis
,cur.[COMMUNICATION_TYPE] as [How was the grievance/complaint received?]
,cur.[COMPLAINT_CATEGORY] as [Category of the grievance/complaint]
,cur.[COMPLAINT_NOTES] as [Grievance/complaint description]
,case when cur.complaint_category = 'QOC' then 'Y' else 'N' end as [Was this a quality of care grievance?]
,case when cur.IS_EXTENDED = 1 then 'Y' else 'N' end as [Was a timeframe extension taken?]
,case when cur.IS_EXTENDED = 0 then 'NA' else '' end as [If an extension was taken, did the sponsor notify the member of the reason(s) for the delay?]
,case when cur.IS_EXTENDED = 0 then 'NA' else '' end as [If the extension was taken because the sponsor needed more information, did they notice the enrollee?]
,convert(varchar(10), min(verbal.created_on), 111) as [Date oral notification of resolution provided to enrollee]
,min(letter.created_on) as [Date written notification of resolution provided to enrollee] 
,cur.OUTCOME_NOTES as [Resolution Description]
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 111) end as [AOR Receipt date] 
,'NA' as [First Tier, Downstream, and Related Entity]

FROM [Altruista].[dbo].[VW_RPT_COMPLAINT_UNIVERSE_REG_RPT] cur
join  [Altruista].[dbo].[ag_auth_complaint] c  
on cur.complaint_record_id = c.complaint_record_id
left join [Altruista].[dbo].[ag_external_auth_details_v] xad on cur.complaint_record_id = xad.complaint_record_id
left join #AUTH a 
on c.auth_id = a.[AUTH_ID] --and r.date_of_service_start_date = a.service_from_date and r.date_of_service_end_date = a.service_to_date
left join  [Altruista].[dbo].[patient_details] pd on cur.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
left join #AUTH xa 
on xad.auth_id = xa.[AUTH_ID] 
--left join [Altruista].[dbo].[LOB] lob on cur.LOB_ID = lob.lob_id

left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] letter
on cur.complaint_record_id = letter.complaint_record_id and letter.action_type = 'Appeal Decision Letter Sent'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] effect
on cur.complaint_record_id = effect.complaint_record_id and effect.action_type = 'Effectuation Entered'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] ire
on cur.complaint_record_id = ire.complaint_record_id and ire.action_type = 'IRE Autoforward'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] aor
on cur.complaint_record_id = aor.complaint_record_id and aor.action_type = 'AOR Received'
left join #providers e 
on a.auth_no = e.auth_no
left join [Actuarial_Services].[dbo].[ADS_Members] adsm
on pd.[CLIENT_patient_ID] = adsm.ccaid
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] verbal
on cur.complaint_record_id = verbal.complaint_record_id and verbal.action_type = 'Verbal Notification as Required'

where cur.complaint_class = 'Standard Grievance'
and cur.outcome_category <> 'improperly filed'
and (cur.resolution_date between '2020-10-01' and '2020-12-31' or cur.due_date between '2020-10-01' and '2020-12-31') 
and cur.[COMPLAINT_CATEGORY] not in ('Other - MH Appeal','Part D - Appeal')
--and (episode_name not in ('dental','pca','Homemaker Services') or episode_name is null)
and [OUTCOME_CATEGORY] not in ('Dismissed','Withdrawn')
and (a.plan_name like 'SCO%' or a.plan_name is null)

group by pd.FIRST_NAME  
,pd.last_name 
,adsm.MedicareMBI 
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end 
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end 
,cur.[RECEIVED_DATE] 
,cur.[COMMUNICATION_TYPE] 
,cur.[COMPLAINT_CATEGORY] 
,cur.[COMPLAINT_NOTES] 
,case when cur.complaint_category = 'QOC' then 'Y' else 'N' end
,case when cur.IS_EXTENDED = 1 then 'Y' else 'N' end 
,case when cur.IS_EXTENDED = 0 then 'NA' else '' end 
,case when cur.IS_EXTENDED = 0 then 'NA' else '' end 
,cur.OUTCOME_NOTES 
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 111) end 
order by 1, 4 --r.complaint_record_id


---------------------- TABLE 12


select 
pd.FIRST_NAME  as 'Beneficiary First Name'
,pd.last_name as 'Beneficiary Last Name'
,adsm.MedicareMBI as 'Enrollee ID'
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end as Contract_ID
,'001' as [Plan ID]
--,cur.[COMPLAINT_RECORD_ID] as [Authorization or Claim Number]
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end as [Person who made the rquest]
--,a.[Provider Type] as [Provider Type]
,cur.[RECEIVED_DATE] as [Date the request was received]
,convert(varchar(10), cur.[RECEIVED_DATE], 114) as [Time request was received]
--,a.diagnosis
,cur.[COMMUNICATION_TYPE] as [How was the grievance/complaint received?]
,cur.[COMPLAINT_CATEGORY] as [Category of the grievance/complaint]
,cur.[COMPLAINT_NOTES] as [Grievance/complaint description]
,convert(varchar(10), min(verbal.created_on), 111) as [Date oral notification of resolution provided to enrollee]
,convert(varchar(10), min(verbal.created_on), 114) as [Time oral notification of resolution provided to enrollee]
,min(letter.created_on) as [Date written notification of resolution provided to enrollee] 
,case when datename(dw, letter.created_on) in ('Monday','Tuesday','Wednesday','Thursday','Friday') then '17:00:00' 
when  datename(dw, letter.created_on) in ('Saturday') then '12:00:00'
else null 
end as [Time written notification of resolution provided to enrollee/provider]
,cur.OUTCOME_NOTES as [Resolution Description]
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 111) end as [AOR Receipt date] 
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 114) end as [AOR Receipt time]
,'NA' as [First Tier, Downstream, and Related Entity]

FROM [Altruista].[dbo].[VW_RPT_COMPLAINT_UNIVERSE_REG_RPT] cur
join  [Altruista].[dbo].[ag_auth_complaint] c  
on cur.complaint_record_id = c.complaint_record_id
left join [Altruista].[dbo].[ag_external_auth_details_v] xad on cur.complaint_record_id = xad.complaint_record_id
left join #AUTH a 
on c.auth_id = a.[AUTH_ID] --and r.date_of_service_start_date = a.service_from_date and r.date_of_service_end_date = a.service_to_date
left join  [Altruista].[dbo].[patient_details] pd on cur.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
left join #AUTH xa 
on xad.auth_id = xa.[AUTH_ID] 
--left join [Altruista].[dbo].[LOB] lob on cur.LOB_ID = lob.lob_id

left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] letter
on cur.complaint_record_id = letter.complaint_record_id and letter.action_type = 'Appeal Decision Letter Sent'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] effect
on cur.complaint_record_id = effect.complaint_record_id and effect.action_type = 'Effectuation Entered'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] ire
on cur.complaint_record_id = ire.complaint_record_id and ire.action_type = 'IRE Autoforward'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] aor
on cur.complaint_record_id = aor.complaint_record_id and aor.action_type = 'AOR Received'
left join #providers e 
on a.auth_no = e.auth_no
left join [Actuarial_Services].[dbo].[ADS_Members] adsm
on pd.[CLIENT_patient_ID] = adsm.ccaid
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] verbal
on cur.complaint_record_id = verbal.complaint_record_id and verbal.action_type = 'Verbal Notification as Required'

where cur.complaint_class = 'Expedited Grievance'
and cur.outcome_category <> 'improperly filed'
and (cur.resolution_date between '2020-01-01' and '2020-12-31' or cur.due_date between '2020-01-01' and '2020-12-31') 
and cur.[COMPLAINT_CATEGORY] not in ('Other - MH Appeal','Part D - Appeal')
--and (episode_name not in ('dental','pca','Homemaker Services') or episode_name is null)
and [OUTCOME_CATEGORY] not in ('Dismissed','Withdrawn')
and (a.plan_name like 'SCO%' or a.plan_name is null)

group by pd.FIRST_NAME  
,pd.last_name 
,adsm.MedicareMBI 
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end 
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end 
,cur.[RECEIVED_DATE] 
,cur.[COMMUNICATION_TYPE] 
,cur.[COMPLAINT_CATEGORY] 
,cur.[COMPLAINT_NOTES] 
,case when datename(dw, letter.created_on) in ('Monday','Tuesday','Wednesday','Thursday','Friday') then '17:00:00' 
when  datename(dw, letter.created_on) in ('Saturday') then '12:00:00'
else null 
end 
,cur.OUTCOME_NOTES 
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 111) end 
,case when aor.created_on is null then 'NA' else convert(varchar(10), aor.created_on, 114) end
order by 1, 4 --r.complaint_record_id


---------------------- TABLE 13


select 
pd.FIRST_NAME  as 'Beneficiary First Name'
,pd.last_name as 'Beneficiary Last Name'
,adsm.MedicareMBI as 'Enrollee ID'
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end as Contract_ID
,'001' as [Plan ID]
,cur.[COMPLAINT_RECORD_ID] as [Authorization or Claim Number]
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end as [Person who made the rquest]
,cur.complaint_class as [Type of Request]
,a.[Provider Type] as [Provider Type]
,cur.[RECEIVED_DATE] as [Date the request was received]
--,a.diagnosis
,cur.[COMPLAINT_CATEGORY] as [Issue description]
,case when cur.complaint_class like 'Standard%' then 'S'
when cur.complaint_class like 'Expedited%' then 'E'
else '' end as [Is this an expedited or standard request?]
,case when cur.IS_EXTENDED = 1 then 'Y' else 'N' end as [Was a timeframe extension taken?]
,cur.RESOLUTION_DATE as [Date the request was dismissed]
,cur.OUTCOME_NOTES as [Reason for Dismissal]
,min(letter.created_on) as [Date written notification of resolution provided to enrollee] 
,case when ire.created_on is null then 'N'
else 'Y' end as [Appealed to IRE?]
,case when ire.created_on is null then 'NA'
else cast(ire.created_on as varchar(20)) 
end as [Date forwarded to IRE]
,'NA' as [First Tier, Downstream, and Related Entity]

FROM [Altruista].[dbo].[VW_RPT_COMPLAINT_UNIVERSE_REG_RPT] cur
join  [Altruista].[dbo].[ag_auth_complaint] c  
on cur.complaint_record_id = c.complaint_record_id
left join [Altruista].[dbo].[ag_external_auth_details_v] xad on cur.complaint_record_id = xad.complaint_record_id
left join #AUTH a 
on c.auth_id = a.[AUTH_ID] --and r.date_of_service_start_date = a.service_from_date and r.date_of_service_end_date = a.service_to_date
left join  [Altruista].[dbo].[patient_details] pd on cur.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
left join #AUTH xa 
on xad.auth_id = xa.[AUTH_ID] 
--left join [Altruista].[dbo].[LOB] lob on cur.LOB_ID = lob.lob_id

left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] letter
on cur.complaint_record_id = letter.complaint_record_id and letter.action_type = 'Appeal Decision Letter Sent'
--left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] effect
--on cur.complaint_record_id = effect.complaint_record_id and effect.action_type = 'Effectuation Entered'
left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] ire
on cur.complaint_record_id = ire.complaint_record_id and ire.action_type = 'IRE Autoforward'
--left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] aor
--on cur.complaint_record_id = aor.complaint_record_id and aor.action_type = 'AOR Received'
left join #providers e 
on a.auth_no = e.auth_no
left join [Actuarial_Services].[dbo].[ADS_Members] adsm
on pd.[CLIENT_patient_ID] = adsm.ccaid
--left join [Altruista].[dbo].[VW_RPT_COMPLAINT_ACTIONS_REG_RPT] verbal
--on cur.complaint_record_id = verbal.complaint_record_id and verbal.action_type = 'Verbal Notification as Required'

where cur.complaint_class in ('Standard Grievance', 'Expedited Grievance','Expedited Appeal','Standard Appeal')
and cur.outcome_category <> 'improperly filed'
and (cur.resolution_date between '2020-10-01' and '2020-12-31' or cur.due_date between '2020-10-01' and '2020-12-31') 
and cur.[COMPLAINT_CATEGORY] not in ('Other - MH Appeal','Part D - Appeal')
--and (episode_name not in ('dental','pca','Homemaker Services') or episode_name is null)
and [OUTCOME_CATEGORY] = 'Dismissed'
and (a.plan_name like 'SCO%' or a.plan_name is null)

group by pd.FIRST_NAME  
,pd.last_name
,adsm.MedicareMBI 
,case when coalesce(a.plan_name,xa.plan_name) in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when  coalesce(a.plan_name,xa.plan_name) in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
when latest_product = 'Sco' then 'H2225'
when latest_product = 'ICO' then 'H0137' else 'Other' end 
,cur.[COMPLAINT_RECORD_ID]
,case when cur.[INITIATED_TYPE_NAME] = 'Member' then 'B' else a.[Provider Type] end 
,cur.complaint_class 
,a.[Provider Type]
,cur.[RECEIVED_DATE]
,cur.[COMPLAINT_CATEGORY]
,case when cur.complaint_class like 'Standard%' then 'S'
when cur.complaint_class like 'Expedited%' then 'E'
else '' end 
,case when cur.IS_EXTENDED = 1 then 'Y' else 'N' end 
,cur.RESOLUTION_DATE 
,cur.OUTCOME_NOTES
,case when ire.created_on is null then 'N'
else 'Y' end 
,case when ire.created_on is null then 'NA'
else cast(ire.created_on as varchar(20))
end 
order by 1, 4 --r.complaint_record_id
