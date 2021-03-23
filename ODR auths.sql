
USE [Altruista]  
GO
 
declare 
@startdate as datetime,
@enddate as datetime 


set @startdate= '2020-01-01 00:00:00'
set @enddate  = '2020-12-31 23:59:59'



--drop table #STEP
drop table #STEP1
drop table #providers
drop table #auth_audit
drop table #patient_enroll





IF OBJECT_ID('tempdb..#carestaff') IS NOT NULL DROP TABLE #carestaff;
select 
cs.member_id
, cs.first_name
, cs.last_name
, r.role_name
, d.dept_name
, csd.is_work_queue
, title
into #carestaff

from [Altruista].[dbo].[CARE_STAFF_DETAILS] cs
left join [Altruista].[dbo].[CARE_STAFF_DEPARTMENT] csd on cs.member_id=csd.care_staff_id and csd.deleted_on is null
left join [Altruista].[dbo].[DEPARTMENT] d on csd.dept_id=d.dept_id and d.deleted_on is null
left join [Altruista].[dbo].[ROLE] r on  cs.ROLE_ID=r.ROLE_ID and r.deleted_on is null
group by
cs.member_id
, cs.first_name
, cs.last_name
, r.role_name
, d.dept_name
, csd.is_work_queue
, title
order by cs.member_id



IF OBJECT_ID('tempdb..#carestaffgroup') IS NOT NULL DROP TABLE #carestaffgroup;
select
member_id
, first_name
, last_name
, role_name
, cast (STUFF(
	(
	SELECT ', ' + CAST(dept_name AS VARCHAR(MAX))
	FROM #carestaff AS s
	WHERE s.[member_id] = cs.[member_id]
	GROUP BY
	s.[dept_name]
	for xml path(''),type).value('(./text())[1]','VARCHAR(MAX)'),1,1,'') as varchar(2000)) as [Department Name(s)]
into #carestaffgroup
from #carestaff cs
group by
member_id
, first_name
, last_name
, role_name

create clustered columnstore index ccl_ind on #carestaffgroup

IF OBJECT_ID('tempdb..#step') IS NOT NULL DROP TABLE #step;

select pd.[LAST_NAME] 
, pd.[FIRST_NAME]
, pd.[CLIENT_patient_ID] as CCAID
--, case when bp.plan_name in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
--when bp.plan_name in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
--else 'Other' end as Contract_ID
, case when l.business_data_name in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when l.business_data_name in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
else 'Other' end as Contract_ID
, a.[AUTH_ID]
, A.AUTH_NO
, a.AUTH_NOTI_DATE as Received_date
, ud.[SERVICE_FROM_DATE] AS [SERVICE_FROM_DATE]
, ud.[SERVICE_TO_DATE] AS [SERVICE_TO_DATE]
, coalesce ( s.SERVICE_CODE, sv.proc_code)  as proc_code
, coalesce (svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION) as proc_description
, auth_priority
, auth_status
, decs.decision_Status
, case when  sv.proc_code in ('0191','0120','0192','0193','0100') or s.service_code in ('0191','0120','0192','0193', '0100') or (ar.mindecision in ('Approved', 'Trans Approved') and dec_count=1)
then  ud.replied_date 
when act.[MD review Completed date] is not null then act.[MD review Completed date]
else ud.replied_date end as Decision_Date

--, case when decs.decision_status in ('denied', 'partially approved')  AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then ud.MEMBER_NOTIFICATION_DATE
--when cast (ud.MEMBER_NOTIFICATION_DATE as date) >= '2020-03-18'
--AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then ud.MEMBER_NOTIFICATION_DATE
--else ' '
--END as 'Verbal Notification'

,case when decs.decision_status in ('denied', 'partially approved')  and ud.MEMBER_NOTIFICATION_DATE is not null AND ud.MEMBER_NOTIFICATION_TYPE_ID=4  then --specified to only pick up phone, not written
convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
when  cast (ud.MEMBER_NOTIFICATION_DATE as date) >= '2019-03-18'---date when UM STARTED CALLING 
AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
else ' ' END as 'Verbal Notification' 


, case when decs.decision_status='approved' then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
when decs.decision_status='partially approved'  and dendoc.created_on is not null  then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
when decs.decision_status='partially approved' then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
else convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
end as WrittenNotifDate
, auth_type_name
, pdv.LAST_NAME + CASE WHEN pdv.FIRST_NAME IS NOT NULL THEN ', ' + pdv.FIRST_NAME ELSE '' END CMO
, byprov.provider_name as ReferredBy
, DECISION_STATUS_CODE_DESC
, src.cust_data_type_value as request_source
, case when a.is_extension=1 then 'Y' else 'N' end as 'Is_extension',
case when a.is_extension=0 or a.is_extension is null then 'NA'
WHEN extdoc.document_ref_id is not null then 'Y' else 'N'  
end as 'If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?'
, act.role_name as denialrole
, a.patient_id 
, a.LOB_BEN_ID
, case when l.business_data_name like '%externally%' then 'Y' else 'N' end as 'ExternallyManaged'
, coalesce(pln.leaf_name,pln1.leaf_name) as ProvLeaf
, pos.[PLACE_OF_SERVICE_CODE] as pos
, CAST (UD.created_on AS DATE) 'DecisionCreatedDate'
, case when s.SERVICE_CODE  in ('99218','t1013', 't2022')  or  sv.proc_code in ('99218','t1013','t2022')then 'Exclude' 
end as 'Exclusion' 
, a.created_on AS [AuthCreatedDate]
, authcr.LAST_NAME + ',' + authcr.First_NAME as [AuthCreatedBy]
, authcr.role_name as [Auth Createdby Role]
, authcr.[department name(s)] as [Auth CreatedBy Department(s)]
, cso.LAST_NAME + ',' + cs.First_NAME as [Auth owner]
, cso.role_name as [Auth Owner Role]
, cso.[department name(s)] as [Auth Owner Department(s)]
, request_name
, ud.replied_date
, case when act.[MD review Completed date] is not null and (decs.decision_status in ('approved', 'trans approved') or (decs.decision_status='adjusted' and (not ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') or DECISION_STATUS_CODE_DESC  is null)))
then 'yes' else 'no' end as 'reviewforeffectuation'
into #STEP

from [Altruista].dbo.um_auth a
left join [Altruista].[dbo].[patient_details] pd on a.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
--left join [Altruista].[dbo].[lob_benf_plan] lb on a.[LOB_BEN_ID] = lb.lob_ben_id and lb.deleted_on is null
left join [Altruista].[dbo].CMN_MA_BUSINESS_HIERARCHY lb on a.[LOB_BEN_ID] = lb.lob_ben_id and lb.deleted_on is null
--left join [Altruista].[dbo].[lob] l on lb.[LOB_ID] = l.lob_id and l.deleted_on is null
LEFT JOIN [Altruista].dbo.CMN_MA_BUSINESS_DATA AS l ON lb.BUSINESS_DATA_ID = l.BUSINESS_DATA_ID AND l.DELETED_ON IS NULL
left join [Altruista].[dbo].UM_AUTH_PROVIDER prov on a.auth_no = prov.auth_no  and prov.provider_type_id = 3 and prov.deleted_on is null
left join [Altruista].[dbo].UM_AUTH_PROVIDER byprov on a.auth_no = byprov.auth_no  and byprov.provider_type_id = 2 and byprov.deleted_on is null
left join [Altruista].[dbo].UM_AUTH_PROVIDER fac on a.auth_no = fac.auth_no  and fac.provider_type_id = 4 and fac.deleted_on is null
left join ccamis_common.[dbo].[ez_providers] p on prov.provider_npi_value = p.provid
left join ccamis_common.[dbo].[provider_leaf_nodes] pln on p.prov_leaf_node = pln.leaf_id
left join ccamis_common.[dbo].[ez_providers] p1 on fac.provider_npi_value = p1.provid
left join ccamis_common.[dbo].[provider_leaf_nodes] pln1 on p1.prov_leaf_node = pln1.leaf_id
left join [Altruista].[dbo].UM_AUTH_CODE Pac on  a.auth_no  = Pac.auth_no and AUTH_CODE_TYPE_ID in ( 1,5) and pac.deleted_on is null
left join [Altruista].[dbo].UM_DECISION ud on  a.auth_no  = ud.auth_no and Pac.auth_code_id = ud.auth_code_id and ud.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS decs on ud.DECISION_status = decs.DECISION_STATUS_ID and decs.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS_codes decstc on ud.DECISION_status_code_id = decstc.DECISION_STATUS_code_ID and decstc.deleted_on is null
--LEFT JOIN [Altruista].[dbo].[benefit_plan] bp ON lb.[BENEFIT_PLAN_ID] = bp.[BENEFIT_PLAN_ID] and bp.deleted_on is null
left join [Altruista].[dbo].UM_MA_AUTH_TAT_PRIORITY tat on a.auth_priority_id = tat.auth_priority_id and tat.deleted_on is null
left join [Altruista].[dbo].UM_MA_CANCEL_VOID_REASON cv on a.CANCEL_VOID_REASON_ID = cv.CANCEL_VOID_REASON_ID and cv.deleted_on is null
left join [Altruista].[dbo].UM_AUTH_PLACE_OF_SERVICe ap on a.auth_no = ap.AUTH_NO and ap.deleted_on is null
left join [Altruista].[dbo].UM_MA_PLACE_OF_SERVICE pos on ap.PLACE_OF_SERVICE_ID = pos.PLACE_OF_SERVICE_ID and pos.deleted_on is null
left join [Altruista].[dbo].[UM_MA_AUTH_TYPE] at on a.AUTH_TYPE_ID = at.AUTH_TYPE_ID  and at.deleted_on is null
LEFT JOIN 
(
	select   c.document_ref_id, c.letter_printed_date, c.created_on, d.created_by,  cs.last_name+ ',' + cs.first_name as createdbyname 
	from
		( 
			select
			a.document_ref_id, max(b.letter_printed_date) as letter_printed_date, a.created_on
			from
			(
				select document_ref_id, max(created_on) as created_on 
				from Altruista.dbo.um_document  
				where document_name like '%approv%' 
				and DELETED_ON is null 
				group by document_ref_id
			)a
			inner join Altruista.dbo.um_document b 
			on a.document_ref_id=b.document_ref_id and b.deleted_on is null and cast(a.created_on as date)=cast(b.created_on as date)
			group by  a.document_ref_id, a.created_on
		)c
	inner join  Altruista.dbo.um_document d on c.document_ref_id=d.document_ref_id and d.deleted_on is null and c.created_on=d.created_on
	left join  [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on d.created_by=cs.member_id
	group by  c.document_ref_id, c.letter_printed_date, c.created_on, d.created_by,  cs.last_name+ ',' + cs.first_name
) approvdoc on a.auth_no=approvdoc.document_ref_id 
LEFT JOIN 
(
	select  a.document_ref_id, a.[letter date], b.created_on, b.created_by, cs.last_name+ ',' + cs.first_name as createdbyname, letter_printed_date as printedon
	from
	(
		select document_ref_id
		, case when cast (max(created_on) as time) < '16:00:00'
		then  max(created_on)  else  dateadd (dd,1,max(created_on) ) 
		end as 'Letter Date'
		, max(created_on) as maxcreatedon
		from Altruista.dbo.um_document
		where ((document_name like '%denial%' and  document_type_id in (1,2)) or  document_type_id=6)
		and DELETED_ON is null
		group by document_ref_id
	)a
	inner join  Altruista.dbo.um_document b on a.document_ref_id=b.document_ref_id and b.deleted_on is null and a. maxcreatedon=b.created_on
	left join  [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on b.created_by=cs.member_id
	group by   a.document_ref_id, a.[letter date], b.created_on, b.created_by, cs.last_name+ ',' + cs.first_name ,  letter_printed_date      
) dendoc on a.auth_no=dendoc.document_ref_id 
left join [Altruista].[dbo].UM_MA_PROCEDURE_CODES sv on Pac.auth_code_ref_id = sv.PROC_CODE and sv.PROC_CATEGORY_ID in (1,2, 3,7) and sv.deleted_on is null 
left join [Altruista].[dbo].[SERVICE_CODE] s on pac.[AUTH_CODE_REF_ID]=cast (s.SERVICE_ID as varchar) and pac.[AUTH_CODE_type_ID]=5 and s.deleted_on is null
left join [Altruista].[dbo].UM_MA_PROCEDURE_CODES svc on  s.service_code = svc.proc_code  and svc.deleted_on is null
left join [Altruista].[dbo].[UM_MA_AUTH_STATUS] stat on a.AUTH_STATUS_ID = stat.AUTH_STATUS_ID and stat.deleted_on is null
left join [Altruista].[dbo].[LANGUAGE] lan on pd.PRIMARY_LANGUAGE_ID = lan.language_id and lan.deleted_on is null
left join [Altruista].[dbo].[UM_MA_AUTH_STATUS_reason] usr on a.[AUTH_STATUS_reason_ID]=usr.[AUTH_STATUS_reason_ID] and usr.deleted_on is null
left JOIN [Altruista].dbo.PATIENT_PHYSICIAN pp 
ON pd.PATIENT_ID = pp.PATIENT_ID AND  CARE_TEAM_ID IN (1,2) AND pp.PROVIDER_TYPE_ID = 181 
AND CAST(GETDATE() AS DATE) BETWEEN pp.[START_DATE] and pp.END_DATE and pp.DELETED_ON IS NULL AND pp.IS_ACTIVE = 1
LEFT JOIN [Altruista].dbo.PHYSICIAN_DEMOGRAPHY pdv ON pp.physician_id = pdv.physician_id 
left join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on a.AUTH_CUR_OWNER=cs.member_id
left join 
(
	select 
	a.[ACTIVITY_LOG_REF_ID],
	a.[MD review Completed date],
	max([role_name]) as role_name
	from [Altruista].[dbo].[UM_ACTIVITY_LOG] ul
	inner join 
	(
		SELECT
		[ACTIVITY_LOG_REF_ID],
		max ([activity_log_followup_date]) as 'MD review Completed date'
		FROM  [Altruista].[dbo].[UM_ACTIVITY_LOG] a 
		where  [ACTIVITY_TYPE_ID]=4
		and a.deleted_on is null
		group by [ACTIVITY_LOG_REF_ID]
	)a on a.[ACTIVITY_LOG_REF_ID]=ul.[ACTIVITY_LOG_REF_ID] and a.[md review completed date]=ul.[activity_log_followup_date] and ul.deleted_on is null
	left join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on ul. activity_log_created_by=cs.member_id
	left join  Altruista.dbo.role r on cs.role_id=r.role_id and r.deleted_on is null
	group by
	a.[ACTIVITY_LOG_REF_ID],
	a.[MD review Completed date]
)act on a.auth_no=act.activity_log_ref_id
LEFT JOIN 
(
	select document_ref_id 
	from Altruista.dbo.um_document 
	where ((document_name like '%exten%' and document_type_id in (1,2)) or (document_name like '%exten%' and document_type_id =12 and (DOCUMENT_DESC like '%extension letter%')))
	and deleted_on is null group by document_ref_id 
) extdoc 
on a.auth_no=extdoc.document_ref_id 
left join
(	
	SELECT  [NOTE_REF_ID],isnull([1],'') as Note1,isnull([2],'') as Note2,isnull([3],'') as Note3
	FROM
		(
			SELECT [NOTE_REF_ID], [NOTE_INFO],  dense_rank () over (partition by  [NOTE_REF_ID] order by CREATED_ON desc) as NOTEORDER
			FROM [Altruista].[dbo].[UM_NOTE]
			WHERE DELETED_ON IS NULL
			GROUP BY [NOTE_REF_ID], [NOTE_INFO],  CREATED_ON
		)p
		pivot
		(max(note_info) for [noteorder] in ([1],[2],[3]))as pvt
)n on a.auth_no=n.[NOTE_REF_ID]
left join
(
	--select distinct
	--cfv.auth_no
	--,cfv.decision_id
	--,cf.cust_field_name
	----,cdt.cust_data_type_value
	--from Altruista.dbo.auth_custom_field_value cfv with(nolock)
	--join Altruista.dbo.um_ma_custom_fields cf with(nolock) 
	--on cfv.cust_field_id = cf.cust_field_id
	--join Altruista.dbo.um_ma_custom_data_type_values cdt with(nolock) 
	--on cfv.cust_field_id = cdt.cust_field_id
	--and cfv.cust_field_value = cdt.cust_data_type_value_id
	--and cdt.deleted_on is null
	--where cfv.deleted_on is null
	--and cf.cust_field_name = 'Source of Service Request'
	select distinct
	cfv.auth_no
	,cfv.decision_id
	,cf.cust_field_name
	,cdt.cust_data_type_value
	from Altruista.dbo.auth_custom_field_value cfv with(nolock)
	join Altruista.dbo.um_ma_custom_fields cf with(nolock) 
	on cfv.cust_field_id = cf.cust_field_id
	join Altruista.dbo.um_ma_custom_data_type_values cdt with(nolock) 
	on cfv.cust_field_value = cdt.cust_data_type_value_id
	and cdt.deleted_on is null
	where cfv.deleted_on is null
	and cf.cust_field_name = 'Source of Service Request'
	and cfv.cust_field_id = 1
) src on a.auth_no = src.auth_no
left join #carestaffgroup cso on a.AUTH_CUR_OWNER=cso.member_id
left join #carestaffgroup authcr on a.CREATED_BY=authcr.member_id
left join [Altruista].[dbo].[UM_MA_REQUEST_SENT_MODE] umr on a.request_sent_mode=umr.request_id and umr.deleted_on is null
left join 
(
	select auth_id, min(decs.decision_status) as mindecision, count (distinct decs.decision_status) as dec_Count
	from [Altruista].[dbo].UM_AUTH a
	left join  [Altruista].[dbo].UM_AUTH_CODE Pac on  a.auth_no  = Pac.auth_no and AUTH_CODE_TYPE_ID in ( 1,5) and pac.deleted_on is null
	left join  [Altruista].[dbo].UM_DECISION ud on  a.auth_no  = ud.auth_no and Pac.auth_code_id = ud.auth_code_id and ud.deleted_on is null
	left join [Altruista].[dbo].uM_MA_DECISION_STATUS decs on ud.DECISION_status = decs.DECISION_STATUS_ID and decs.deleted_on is null
	where (decs.DECISION_STATUS <> 'Void' or decs.decision_status is null)
	and a.deleted_on is null 
	group by auth_id
) ar 
on a.auth_id=ar.auth_id

--where LOB_name = 'Medicare-Medicaid Duals' 
--and bp.plan_name in ('SCO-Externally Managed', 'SCO-CCA Managed') 
where lb.data_root_name = 'Medicare-Medicaid Duals' 
and l.business_data_name in ('SCO-Externally Managed', 'SCO-CCA Managed')
and pd.[CLIENT_patient_ID] like '53%'
and auth_status in  ('close','closed and adjusted','open','reopen', 'reopen and close','Withdrawn')
and a.deleted_on is null 
and (not (decstc.DECISION_STATUS_CODE_DESC in ('Suspension of Services', 'Duplicate Request') )or decstc.DECISION_STATUS_CODE_DESC is null)
group by
pd.[LAST_NAME] 
, pd.[FIRST_NAME]
, pd.[CLIENT_patient_ID] 
--, case when bp.plan_name in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
--when bp.plan_name in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
--else 'Other' end 
, case when l.business_data_name in ('SCO-Externally Managed', 'SCO-CCA Managed') then 'H2225' 
when l.business_data_name in ('ICO-Externally Managed','ICO-CCA Managed') then 'H0137' 
else 'Other' end 
, a.[AUTH_ID]
, A.AUTH_NO
, a.AUTH_NOTI_DATE
, ud.[SERVICE_FROM_DATE] 
, ud.[SERVICE_TO_DATE] 
, coalesce ( s.SERVICE_CODE, sv.proc_code)
, coalesce (svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION) 
, auth_priority
, auth_status
, decs.decision_Status
, case when  sv.proc_code in ('0191','0120','0192','0193','0100') or s.service_code in ('0191','0120','0192','0193', '0100') or (ar.mindecision in ('Approved', 'Trans Approved') and dec_count=1)
then  ud.replied_date 
when act.[MD review Completed date] is not null then act.[MD review Completed date]

else ud.replied_date end 
--, case when decs.decision_status in ('denied', 'partially approved')  AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then ud.MEMBER_NOTIFICATION_DATE
--when cast (ud.MEMBER_NOTIFICATION_DATE as date) >= '2020-03-18'
--AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then ud.MEMBER_NOTIFICATION_DATE
--else ' '
--END 
,case when decs.decision_status in ('denied', 'partially approved')  and ud.MEMBER_NOTIFICATION_DATE is not null AND ud.MEMBER_NOTIFICATION_TYPE_ID=4  then --specified to only pick up phone, not written
convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
when  cast (ud.MEMBER_NOTIFICATION_DATE as date) >= '2019-03-18'---date when UM STARTED CALLING 
AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
else ' '
END
, case when decs.decision_status='approved' then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
when decs.decision_status='partially approved'  and dendoc.created_on is not null  then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
when decs.decision_status='partially approved' then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
else convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
end 
, auth_type_name
, pdv.LAST_NAME + CASE WHEN pdv.FIRST_NAME IS NOT NULL THEN ', ' + pdv.FIRST_NAME ELSE '' END
, byprov.provider_name
, DECISION_STATUS_CODE_DESC
, src.cust_data_type_value
, case when a.is_extension=1 then 'Y' else 'N' end 
, case when a.is_extension=0 or a.is_extension is null then 'NA'
WHEN extdoc.document_ref_id is not null then 'Y' else 'N'  
end 
, act.role_name 
, a.patient_id 
, a.LOB_BEN_ID
, case when l.business_data_name like '%externally%' then 'Y' else 'N' end 
, coalesce(pln.leaf_name,pln1.leaf_name) 
, pos.[PLACE_OF_SERVICE_CODE]
, CAST (UD.created_on AS DATE) 
, case when s.SERVICE_CODE  in ('99218','t1013', 't2022')  or  sv.proc_code in ('99218','t1013','t2022')then 'Exclude' 
end 
, a.created_on 
, authcr.LAST_NAME + ',' + authcr.First_NAME 
, authcr.role_name 
, authcr.[department name(s)] 
, cso.LAST_NAME + ',' + cs.First_NAME 
, cso.role_name 
, cso.[department name(s)] 
, request_name
, ud.replied_date
, case when act.[MD review Completed date] is not null and (decs.decision_status in ('approved', 'trans approved') or (decs.decision_status='adjusted' and (not ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') or DECISION_STATUS_CODE_DESC  is null)))
then 'yes' else 'no' end 

-- select * from #step where auth_id in ('0907MD1F3') ('0103FAC47','0113M6B12')

begin tran
delete from #step
where auth_status <> 'Withdrawn'
and DECISION_STATUS = 'Void'

commit tran



begin tran
delete from #step
where ltrim(rtrim(proc_code)) in ('RC570','GP','PI','U9','AE','D9920','86129','TU','U6','CK','EO130','AZ','GO','ZB','D4341','51759','70455','E0416','NY165','L1550','D7210','PT','A4343','KL','0','QM','A0150','K0130','H5180','ST','CE','E0510','97100','D1206','D1330','RB','PA120','T4','K0162','Q0109','D6792','V9','A0110','A0302','A0300','H5138','E1038','65755',
'48200','D7521','CF','BO','ES250','D3330','HG','S2125','UK','ZA','HQ','53870','D7120','K0260','TRAVL','Q0117','H5010','Q0103','97101','RC550','95850','A2000','TP','KA','T6','KC','D0210','AJ','HK','D7999','GY','QN','90722','D7250','M9999','D5140','RHA20','E0152','526','L1','Q0119','H5030','QH','QW','TQ','H1017','D1110','24030','E0252','NY118','D5130','UE','SS','A2','AH','A0020','CJ','D0150','D7230','HP','AF','GH','Q0040','R0309','97201','NB','E0151','DA')
commit tran




	
drop table #step_a

select s.*, b.auth_id as keepline
into #step_a 
from #step s
left join
(
	select * from
	(
		select auth_id
		, min(decision_status) as mindecs
		, max(decision_status) as maxdecs
		, min(decision_date) as mindecdate
		, max(decision_date) as maxdecdate
		, min(decisioncreateddate) as mincreatedate
		, max(decisioncreateddate) as maxcreatedate
		from #step 
		group by auth_id
	) a 
	where mindecs=maxdecs
	and cast(mindecdate as date)<> cast(maxdecdate as date) 
	and cast(mincreatedate as date)<>cast(maxcreatedate as date)
) b 
on s.auth_id=b.auth_id and s.decision_Date=b.mindecdate 
left join
(
	select distinct auth_id from
	(
		select auth_id	
		, min(decision_status) as mindecs
		, max(decision_status) as maxdecs
		, min(decision_date) as mindecdate
		, max(decision_date) as maxdecdate
		, min(decisioncreateddate) as mincreatedate
		, max(decisioncreateddate) as maxcreatedate
		from #step 
		group by auth_id
	) a 
	where mindecs=maxdecs
	and cast(mindecdate as date)<> cast(maxdecdate as date) 
	and cast(mincreatedate as date)<>cast(maxcreatedate as date)
) c on s.auth_id=c.auth_id 
where b.AUTH_ID is not null OR c.auth_id is null


select s.*
into #step_b 
from #step_a s
where
exclusion is null


select 
case when ltrim(rtrim(proc_code)) in ( 'A0425','A4335','B4150','B4152','A4927','B4154','A4245','A4402','B4160','A4326','A4244','A0120','A0090','A0150','A0366', 'travl')then 'N'
	WHEN ltrim(rtrim(proc_code)) ='E1399' AND proc_description LIKE '%Use%Modifier%' THEN 'Y'
	WHEN ltrim(rtrim(proc_code)) ='E1399' THEN 'N'
	when spl.medicareindicator ='Y' then 'Y'
	when spl.medicareindicator ='N' then 'N'
	when ltrim(rtrim(proc_code)) ='0191' then 'Y'
	when proc_description like '%Medicaid%' then 'N'
	when ltrim(rtrim(proc_code)) like 'V%' then 'N'
	when dme.maxfee is not null then 'Y'
	when si.medicareindicator = 'Y' then 'Y'
	when proc_description in ('SNF Medical leave of absence', 'SNF CUSTODIAL') then 'N' 
	when ltrim(rtrim(proc_code)) in ('0183','0185') then 'N'
	WHEN proc_code ='0120' then 'N'
	when cov in ('I','M','S') then 'N'
	when cov in ('C','d') and spl.medicareindicator is null then 'Y'
	when ltrim(rtrim(proc_code)) in ('HMKER','MEALS') then 'N'
	when ltrim(rtrim(proc_code)) = '912' then 'N'
	when ltrim(rtrim(proc_code)) = '1002' then 'N'
	when ltrim(rtrim(proc_code)) = '0100' and pos = '25' then 'N'
	when ltrim(rtrim(proc_code)) = '0100' then 'Y'
	when ltrim(rtrim(proc_code)) = '0126' and pos = '21' then 'N'
	when spl.medicareindicator is null then 'Y'
	when ProvLeaf = 'NURSING FACILITY' and proc_description = 'SKILLED NURSING' Then 'Y' 
	when proc_description = 'CUSTODIAL MLOA' then 'N' 
	when proc_description = 'CUSTODIAL NMLOA' then 'N' 
	when ProvLeaf = 'acute care hospital' then 'Y'
	when ProvLeaf = 'Adult Day Health' then 'N' 
	when left(ltrim(proc_code),1)<>'1' and ProvLeaf = 'Nursing Facility' then 'Y' 
	else 'CHECK' end as MCarePayable
,a.* 
, case when s2.auth_id is not null then 'Yes' else 'No' end as 'Adjusted_AdjustedCheck'
into  #step1
from 
( 
	select * from #step_b
	where coalesce(auth_priority, 'temp') not in ('Concurrent Expedited','Concurrent Standard')
)a
left join [Medical_Analytics].[dbo].[MMPISplitByProcCode_updated] spl 
on ltrim(rtrim(a.proc_code)) between spl.procfirst and spl.proclast and len(procfirst)>4 and len(proclast)>4 and len( ltrim(rtrim(a.proc_code)))>4
left join medical_analytics.[dbo].[hcpc18]  hc 
on ltrim(rtrim(a.proc_code)) = hc.hcpc
left join 
(
	SELECT [hcpcs], juris,max([ma (nr)]) as maxfee
	FROM medical_analytics.dbo.dmefs_2018
	where [ma (nr)] >0
	group by [hcpcs], juris
) dme on ltrim(rtrim(a.proc_code)) = dme.[hcpcs]
left join  medical_analytics.dbo.addb2018 addb 
on ltrim(rtrim(a.proc_code)) = addb.[hcpcs code]
left join medical_analytics.dbo.statind2018  si 
on si.statind =  addb.si
  left join (select distinct auth_id from #step_b where decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%' ) s2 on a.auth_id=s2.auth_id


begin tran

update #step1
set decision_date=a.replied_Date
from #step1 s
inner join 
(
	SELECT ROW_NUMBER() OVER(Partition by c.auth_id ORDER BY a.replied_date desc) AS Row,
    a.[DECISION_ID]
    ,a.[DECISION_NO]
    ,a.[AUTH_NO]
    ,a.[REPLIED_DATE]
    ,c.auth_id
	FROM [Altruista].[dbo].[AUDIT_UM_DECISION_LOG] a
	inner join 
	(
		SELECT [DECISION_ID], [DECISION_NO], [AUTH_NO]
		FROM [Altruista].[dbo].[UM_DECISION]
		where decision_status = '4'
		and decision_status_code_id = '1'
	) b
	on a.DECISION_ID = b.DECISION_ID and a.DECISION_NO = b.DECISION_NO and a.auth_no = b.AUTH_NO
	left join [Altruista].dbo.um_auth c
	on a.AUTH_NO = c.AUTH_NO
	where a.replied_date is not null
	and a.decision_Status not in (4,8)
	and a.DELETED_ON is null
) a
on s.auth_no=a.auth_no
where decision_status='adjusted' and DECISION_STATUS_CODE_DESC  ='Adjusted'
and row = 1

commit tran

-- select * from #step1 where auth_id in ('0205W2EA1','0103FAC47','0113M6B12') order by 6
-- select distinct auth_priority from #step1

IF OBJECT_ID('tempdb..#providers') IS NOT NULL DROP TABLE #providers;

create table #providers
	(
	 auth_no bigint not null
	,referred_by_provider_id bigint null
	,referred_to_provider_id bigint null
	,facility_provider_id bigint null
	,referred_by_provider_code nvarchar(50)
	,referred_to_provider_code nvarchar(50)
	,facility_provider_code nvarchar(50)
	,referred_by_provider_name nvarchar(1000)
	,ref_by_validity_from datetime null
	,ref_by_validity_to datetime null
	,ref_by_lob_id bigint null
	,ref_by_provider_capacity nvarchar(50) null
	,referred_to_provider_name nvarchar(1000)
	,ref_to_validity_from datetime null
	,ref_to_validity_to datetime null
	,ref_to_lob_id bigint null
	,ref_to_provider_capacity nvarchar(50) null
	,facility_provider_name nvarchar(1000)
	,facility_validity_from datetime null
	,facility_validity_to datetime null
	,facility_lob_id bigint null
	,facility_provider_capacity nvarchar(50) null
	)
	insert into #providers
	(
	 auth_no
	,referred_by_provider_id
	,referred_to_provider_id
	,facility_provider_id
	,referred_by_provider_code
	,referred_to_provider_code
	,facility_provider_code
	,referred_by_provider_name
	,ref_by_validity_from
	,ref_by_validity_to
	,ref_by_lob_id
	,ref_by_provider_capacity
	,referred_to_provider_name
	,ref_to_validity_from
	,ref_to_validity_to
	,ref_to_lob_id
	,ref_to_provider_capacity
	,facility_provider_name
	,facility_validity_from
	,facility_validity_to
	,facility_lob_id
	,facility_provider_capacity
	)
	select distinct 
		 piv.auth_no
		,piv."2"								as referred_by_provider_id
		,piv."3"								as referred_to_provider_id
		,piv."4"								as facility_provider_id
		,p2.physician_code			as referred_by_provider_code
		,p3.physician_code			as referred_to_provider_code
		,p4.physician_code			as facility_provider_code
	
		,uap2.provider_name			as referred_by_provider_name
		,pn2.validity_from			as ref_by_validity_from
		,pn2.validity_to				as ref_by_validity_to
		,pn2.niu_lob_id							as ref_by_lob_id
		,pn2.provider_capacity	as ref_by_provider_capacity
		,uap3.provider_name			as referred_to_provider_name
		,pn3.validity_from			as ref_to_validity_from
		,pn3.validity_to				as ref_to_validity_to
		,pn3.niu_lob_id							as ref_to_lob_id
		,pn3.provider_capacity	as ref_to_provider_capacity
		,uap4.provider_name			as facility_provider_name
		,pn4.validity_from			as facility_validity_from
		,pn4.validity_to				as facility_validity_to
		,pn4.niu_lob_id							as facility_lob_id
		,pn4.provider_capacity	as facility_provider_capacity
	from 
		(
			select 
				 a.auth_no
				,a.provider_type_id
				,a.physician_id
			from 
					(
					select 
						 ap.auth_no
						,ap.provider_type_id
						,ap.physician_id
						,ap.provider_name
					from 
						um_auth_provider ap with(nolock)
					inner join
						(select auth_no from #STEP1) auth on ap.auth_no = auth.auth_no
					where 
							ap.deleted_by is null
						and ap.deleted_on is null
					) a
		) src
		pivot( 
			max( physician_id )  for provider_type_id in (
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
		
		left join 
				(
				--select distinct p.provider_id,p.validity_from,p.validity_to,p.netwrok_id,niu_lob_id,provider_capacity
				-- from provider_network p with(nolock) 
				-- inner join
				--		(
				--		select
				--				 provider_id
				--				,max(netwrok_id) as max_network_id
				--		from
				--				Altruista.dbo.provider_network with(nolock)
				--		where
				--				is_active = 1
				--		group by
				--				provider_id
				--		)       src on p.netwrok_id   = src.max_network_id	
					select distinct a.*, pn.validity_to, pn.netwrok_id, pn.niu_lob_id, pn.provider_capacity
					from
					(
						select
						provider_id
						--,min(netwrok_id) as max_network_id
						,min(validity_from) as validity_from
						from Altruista.dbo.provider_network with(nolock)
						where is_active = 1
						--and provider_id in ('28218','21145')
						and PROVIDER_ENROLLMENT not like '%ICO%'
						group by provider_id
					)a
					join Altruista.dbo.provider_network pn
					on a.provider_id = pn.provider_id and a.validity_from = pn.validity_from
					where pn.PROVIDER_ENROLLMENT not like '%ICO%'
					and pn.is_active = 1
				)		pn2 on piv."2" = pn2.provider_id
		left join 
				(
				--select distinct p.provider_id,p.validity_from,p.validity_to,p.netwrok_id,niu_lob_id,provider_capacity
				-- from provider_network p with(nolock) 
				-- inner join
				--		(
				--		select
				--				 provider_id
				--				,max(netwrok_id) as max_network_id
				--		from
				--				Altruista.dbo.provider_network with(nolock)
				--		where
				--				is_active = 1
				--		group by
				--				provider_id
				--		)       src on p.netwrok_id   = src.max_network_id	
					select distinct a.*, pn.validity_to, pn.netwrok_id, pn.niu_lob_id, pn.provider_capacity
					from
					(
						select
						provider_id
						--,min(netwrok_id) as max_network_id
						,min(validity_from) as validity_from
						from Altruista.dbo.provider_network with(nolock)
						where is_active = 1
						--and provider_id in ('28218','21145')
						and PROVIDER_ENROLLMENT not like '%ICO%'
						group by provider_id
					)a
					join Altruista.dbo.provider_network pn
					on a.provider_id = pn.provider_id and a.validity_from = pn.validity_from
					where pn.PROVIDER_ENROLLMENT not like '%ICO%'
					and pn.is_active = 1
				)		pn3 on piv."3" = pn3.provider_id
		left join 
				select distinct a.*, pn.validity_to, pn.netwrok_id, pn.niu_lob_id, pn.provider_capacity
					from
					(
						select
						provider_id
						--,min(netwrok_id) as max_network_id
						,min(validity_from) as validity_from
						from Altruista.dbo.provider_network with(nolock)
						where is_active = 1
						--and provider_id in ('28218','21145')
						and PROVIDER_ENROLLMENT not like '%ICO%'
						group by provider_id
					)a
					join Altruista.dbo.provider_network pn
					on a.provider_id = pn.provider_id and a.validity_from = pn.validity_from
					where pn.PROVIDER_ENROLLMENT not like '%ICO%'
					and pn.is_active = 1
				)	pn4 on piv."4" = pn4.provider_id


	create clustered index idx_auth_no on #providers(auth_no)


-- drop table #notes

SELECT  [NOTE_REF_ID]
,isnull([1],'') as Note1,isnull([2],'') as Note2,isnull([3],'') as Note3, isnull([4],'') as Note4, isnull([5],'') as Note5, isnull([6],'') as Note6, isnull([7],'') as Note7, isnull([8],'') as Note8,
isnull([9],'') as Note9, isnull([10],'') as Note10
into #notes
		FROM
		(
SELECT 
      [NOTE_REF_ID]
      ,[NOTE_INFO]
   
	  ,  dense_rank () over (partition by  [NOTE_REF_ID] order by CREATED_ON desc) as NOTEORDER
	
  FROM [Altruista].[dbo].[UM_NOTE]
  WHERE DELETED_ON IS NULL

  GROUP BY
     [NOTE_REF_ID]
      ,[NOTE_INFO]
    ,  CREATED_ON)p
		pivot
		(max(note_info) for [noteorder] in ([1],[2],[3],[4],[5], [6],[7],[8],[9],[10])
		)as pvt

-- select * from #notes where note_ref_id = 404712

select n.*,
case when appeal.note_ref_id is not null then 'appeal' else null
end as 'appeal_flag'
into #notes_2
from #notes n
left join 
(
	select distinct note_ref_id
	from [Altruista].[dbo].[UM_NOTE]
	where note_type_id = 2
)appeal
on n.[NOTE_REF_ID] = appeal.note_ref_id
	

-- select * from #notes_2 where appeal_flag is not null
-- select * from [Altruista].dbo.um_auth where auth_no in (276677,400205,212389,210832,420436,341394)


drop table #step2



-- select distinct decision_status, count(*) from #step1 group by decision_Status
-- select * from #step1 where auth_id in ('0206T341F','1118M6347')

--select auth_id, count(distinct decision_status)
--from #step1
--group by auth_id
--having count(distinct decision_status) > 2

SELECT 
[LAST_NAME]
,[FIRST_NAME]
,[CCAID]
,[Contract_ID]
,s.[AUTH_ID]
,[Received_date]
, STUFF(
		ISNULL(
				(
					SELECT
						' | ' +S2.[PROC_CODE]
					FROM #STEP1 AS S2

					WHERE S2.[AUTH_ID] = S.[AUTH_ID] 
					and MCarePayable= 'Y'
					GROUP BY
						S2.[PROC_CODE]
					FOR XML PATH (''), TYPE
				).value('.', 'VARCHAR(MAX)') 
			, '')
		, 1, 2, '') AS 'Service Code(s)'
, STUFF(
		ISNULL(
				(
					SELECT
						' | ' +S2.[PROC_DESCRIPTION]
					FROM #STEP1 AS S2
					WHERE S2.[AUTH_ID] = S.[AUTH_ID] 
					GROUP BY
					S2.[PROC_DESCRIPTION]
					FOR XML PATH (''), TYPE
				).value('.', 'VARCHAR(MAX)') 
			, '')
		, 1, 2, '') AS 'Service Description(s)'
,[auth_priority]
,[IS_EXTENsion]
,case when ad.[AUTH_ID] is not null then [ORG Determination]
when decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') then 'Denied'
when decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%'  then 'Approved'
when decision_status='TRANS APPROVED' THEN 'Approved'
else decision_status end as 'ORG Determination decision_Status'
,case when ad.[AUTH_ID] is not null then [ODAG]
when decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') then 'Denied'
when decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%'  then 'Approved'
when decision_status='TRANS APPROVED' THEN 'Approved'
when decision_status='PARTIALLY APPROVED' THEN 'Denied'
else decision_status end as 'ODAG Decision_status'
, [Decision_Date]
,[Verbal Notification]
,[WrittenNotifDate]
,decision_status
--,den.document_id, appr.document_id
--,case when den.document_id is not null then 'Denial letter'
--when appr.document_id is not null then 'Approve letter'
--else 'none' end as 'letter type'
,[auth_type_name]
,[CMO]
,[AUTH_NO]
, STUFF(
		ISNULL(
				(
					SELECT
						' | ' +S2.DECISION_STATUS_CODE_DESC
					FROM #STEP1 AS S2
					WHERE S2.[AUTH_ID] = S.[AUTH_ID]
					and MCarePayable= 'Y' 
					GROUP BY
						S2.DECISION_STATUS_CODE_DESC
					FOR XML PATH (''), TYPE
				).value('.', 'VARCHAR(MAX)') 
			, '')
		, 1, 2, '') AS 'DECISION_STATUS_CODE_DESC'
,request_source		
,[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?]
, denialrole
, PATIENT_ID
, LOB_BEN_ID
, ExternallyManaged
,MCarePayable
, MIN([SERVICE_FROM_DATE]) AS 'SERVICE_FROM_DATE'
, max([SERVICE_to_DATE]) as [SERVICE_to_DATE]
, [AuthCreatedDate]
, [AuthCreatedBy]
, [Auth Createdby Role]
, [Auth CreatedBy Department(s)]
, [Auth owner]
, [Auth Owner Role]
, [Auth Owner Department(s)]
, request_name
, Adjusted_AdjustedCheck
, auth_status
, ReferredBy
into #step2
FROM #STEP1 S
left join
	 -- 	(  select distinct a.auth_id, 'Partially Approved' as 'ORG Determination', 'Denied' as 'ODAG' from
	 --( select * from #step1 s where decision_status in ('Partially Approved','denied') or  (decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%')))a
	 -- inner join (select * from #step1 se where decision_status in  ('approved','Partially Approved', 'trans approved')   or  (decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%adjusted%' ))) b on a.[AUTH_ID]=b.[auth_id]
	 -- )ad on s.auth_id=ad.auth_id
(  
	select distinct a.auth_id, 'Partially Approved' as 'ORG Determination', 'Denied' as 'ODAG'--'Denied' as 'Overall Decision' 
	from --,--- 'Denied' as 'ODAG' from
	( 
		select * 
		from #step1 s 
		where decision_status in ('Partially Approved','denied') or  (decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%'))
	)a
	inner join 
	(
		select * 
		from #step1 se 
		where decision_status in ('approved','Partially Approved', 'trans approved')  or  (decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%adjusted%' ))
	) b on a.[AUTH_ID]=b.[auth_id]
)ad 
on s.auth_id=ad.auth_id
where MCarePayable= 'Y'
--and s.auth_id = '0206T341F'
GROUP BY
[LAST_NAME]
,[FIRST_NAME]
,[CCAID]
,[Contract_ID]
,s.[AUTH_ID]
, [Received_date]
,[auth_priority]
,[IS_EXTENsion]
,[Verbal Notification]
,[WrittenNotifDate]
--,case when den.document_id is not null then 'Denial letter'
--when appr.document_id is not null then 'Approve letter'
--else 'none' end
,[auth_type_name]
,[CMO]
,[AUTH_NO]
,case when ad.[AUTH_ID] is not null then [ORG Determination]
when decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') then 'Denied'
when decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%'  then 'Approved'
when decision_status='TRANS APPROVED' THEN 'Approved'
else decision_status end
, [Decision_Date]
,case when ad.[AUTH_ID] is not null then [ORG Determination]
when decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') then 'Denied'
when decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%'  then 'Approved'
when decision_status='TRANS APPROVED' THEN 'Approved'
else decision_status end 
,case when ad.[AUTH_ID] is not null then [ODAG]
when decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') then 'Denied'
when decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%'  then 'Approved'
when decision_status='TRANS APPROVED' THEN 'Approved'
when decision_status='PARTIALLY APPROVED' THEN 'Denied'
else decision_status end
,request_source
,[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?]
, denialrole
, PATIENT_ID
, LOB_BEN_ID
, ExternallyManaged
, MCarePayable
, [AuthCreatedDate]
, [AuthCreatedBy]
, [Auth Createdby Role]
, [Auth CreatedBy Department(s)]
, [Auth owner]
, [Auth Owner Role]
, [Auth Owner Department(s)]
, request_name
, Adjusted_AdjustedCheck
, auth_status
, ReferredBy
,decision_status
--,den.document_id, appr.document_id
-- select decision_date, * from #step2 where auth_id in ('0826W1ECA') order by auth_id
-- select * from #step2 where auth_id in ('0206T341F','1025F6B46','0119TDB9B') order by auth_id


--select distinct decision_status
--from #step2


--select auth_id, count(decision_status)
--from #step2
--group by auth_id
--having count(decision_status) > 2

-- drop table #step3

SELECT 
[LAST_NAME]
,[FIRST_NAME]
, [CCAID]
, [Contract_ID]
,S.[AUTH_ID]
,[Received_date] as 'Received_Date'
, [Service Code(s)]
, [Service Description(s)]
,[auth_priority]
,[IS_extension]
,[ODAG Decision_status]
, [ORG Determination decision_Status]
--,case when rtrim(ltrim([Service Code(s)])) in ('120','191','192','193', '0120','0191','0191','0192', '0193') 
,case when rtrim(ltrim([Service Code(s)])) in ('120','191','192','193', '0120','0191','0191','0192', '0193','0100') 
OR rtrim(ltrim([Service Code(s)])) LIKE '0120 | 0191'   OR rtrim(ltrim([Service Code(s)])) LIKE '0120 | 0192'   OR rtrim(ltrim([Service Code(s)])) LIKE '0120 | 0193'
OR rtrim(ltrim([Service Code(s)])) LIKE '0191 | 0192'  OR rtrim(ltrim([Service Code(s)])) LIKE '0191 | 0193' OR rtrim(ltrim([Service Code(s)])) LIKE '0192 | 0193'
--or ( rtrim(ltrim([Service Code(s)])) between '0100'and '0119' and len(rtrim(ltrim([Service Code(s)])))=4 ) 
--or ( rtrim(ltrim([Service Code(s)])) between '0121'and '0190' and len(rtrim(ltrim([Service Code(s)])))=4)
--or ( rtrim(ltrim([Service Code(s)])) between '0193'and '0219' and len(rtrim(ltrim([Service Code(s)])))=4)
then  min([Decision_Date]) else  MAX([Decision_Date]) end as 'Decision_Date'

,max([Verbal Notification]) as 'Verbal_Notification'
,case when rtrim(ltrim([Service Code(s)])) in ('120','191','192','193', '0120','0191','0191','0192', '0193') 
OR rtrim(ltrim([Service Code(s)])) LIKE '0120 | 0191'   OR rtrim(ltrim([Service Code(s)])) LIKE '0120 | 0192'   OR rtrim(ltrim([Service Code(s)])) LIKE '0120 | 0193'
OR rtrim(ltrim([Service Code(s)])) LIKE '0191 | 0192'  OR rtrim(ltrim([Service Code(s)])) LIKE '0191 | 0193' OR rtrim(ltrim([Service Code(s)])) LIKE '0192 | 0193'
then  min(s.[WrittenNotifDate]) --else  max([WrittenNotifDate]) end  as 'WrittenNotifDate'
when [ODAG Decision_status] = 'Denied' then den.writtennotifdate
when [ODAG Decision_status] = 'Approved' then appr.writtennotifdate
else min(s.[WrittenNotifDate]) end  as 'WrittenNotifDate'
,[auth_type_name]
,[CMO]
, CASE WHEN received_date is null then 0
when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN dateadd (dd, 28, received_date)
WHEN auth_priority = 'Prospective Standard'  THEN dateadd (dd, 14,received_date)
when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 17, received_date)
when auth_priority = 'Prospective Expedited'  THEN dateadd (dd,3,received_date)
when (auth_priority = 'Retrospective' and is_extension ='yes') THEN dateadd (dd, 28, received_date)
WHEN auth_priority = 'Retrospective'  THEN dateadd (dd, 14,received_date)
when (auth_priority = 'Concurrent Standard' and is_extension ='yes') THEN dateadd (dd, 28, received_date)
WHEN auth_priority = 'Concurrent Standard'  THEN dateadd (dd, 14,received_date)
when auth_priority = 'Concurrent Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 28, received_date)
WHEN auth_priority = 'Concurrent Expedited'  THEN dateadd (dd, 14,received_date)
when auth_priority = 'Part B Med Expedited'   THEN dateadd (dd, 1, received_date)
when auth_priority = 'Part B Med Standard'  THEN dateadd(dd, 3, received_date) 
else 0 end as deadline
, DECISION_STATUS_CODE_DESC
,request_source
,[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?]
, denialrole
,AUTH_NO
, PATIENT_ID
, LOB_BEN_ID
, ExternallyManaged
, mcarepayable
, min(SERVICE_FROM_DATE) as 'MIN_SERVICE_FROM_DATE'
, mAX(SERVICE_to_DATE) as 'MAX_SERVICE_TO_DATE'
, Adjusted_AdjustedCheck
, [AuthCreatedDate]
, [AuthCreatedBy]
, [Auth Createdby Role]
, [Auth CreatedBy Department(s)]
, [Auth owner]
, [Auth Owner Role]
, [Auth Owner Department(s)]
, request_name
, auth_status
, ReferredBy
into #step3
FROM #STEP2 S
left join 
(
	select auth_id, min(writtennotifdate) as writtennotifdate
	from #step2
	where decision_status in ('Denied','Partially Approved')
	--and auth_id in ('0206T341F','1025F6B46','0119TDB9B')
	group by auth_id
)den
on s.auth_id = den.auth_id
left join 
(
	select auth_id, min(writtennotifdate) as writtennotifdate
	from #step2
	where decision_status in ('Approved')
	--and auth_id in ('0206T341F','1025F6B46','0119TDB9B')
	group by auth_id
)appr
on s.auth_id = appr.auth_id
--where s.auth_id in ('0206T341F','1025F6B46','0119TDB9B')
GROUP BY
[LAST_NAME]
,[FIRST_NAME]
,[CCAID]
,[Contract_ID]
,S.[AUTH_ID]
,[Received_date] 
,[Service Code(s)]
,[Service Description(s)]
,[auth_priority]
,[IS_EXTENsion]
,[ODAG Decision_status]
,[ORG Determination decision_Status]
,[auth_type_name]
,[CMO]
,DECISION_STATUS_CODE_DESC
,request_source
,[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?]
,denialrole
,AUTH_NO
,PATIENT_ID
,LOB_BEN_ID
,ExternallyManaged
,mcarepayable
,[AuthCreatedDate]
,[AuthCreatedBy]
,[Auth Createdby Role]
,[Auth CreatedBy Department(s)]
,[Auth owner]
,[Auth Owner Role]
,[Auth Owner Department(s)]
,request_name
,Adjusted_AdjustedCheck
,auth_status
,ReferredBy
,den.writtennotifdate
,appr.writtennotifdate


-- select count(*) from #step3 --67475
-- select * from #step3 where auth_id in ('0206T341F') ('0205W2EA1','0206T341F')
-- select distinct auth_priority from #step3

IF OBJECT_ID('tempdb..#step4') IS NOT NULL DROP TABLE #step4;

select s3.LAST_NAME, s3.FIRST_NAME, s3.CCAID, s3.Contract_ID, s3.AUTH_ID, s3.Received_Date, s3.[Service Code(s)], s3.[Service Description(s)], s3.auth_priority, s3.IS_extension, s3.[ODAG Decision_status], s3.[ORG Determination decision_Status],
s3.Decision_Date, s3.Verbal_Notification, min(crm.printandmailtime) as WrittenNotifDate, s3.auth_type_name, s3.CMO, s3.deadline, s3.DECISION_STATUS_CODE_DESC, s3.request_source, s3.[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?], s3.denialrole, s3.AUTH_NO, 
s3.PATIENT_ID, s3.LOB_BEN_ID, s3.ExternallyManaged, s3.mcarepayable, s3.MIN_SERVICE_FROM_DATE, s3.MAX_SERVICE_TO_DATE, s3.Adjusted_AdjustedCheck, s3.AuthCreatedDate, s3.AuthCreatedBy, s3.[Auth Createdby Role], 
s3.[Auth CreatedBy Department(s)], s3.[Auth owner], s3.[Auth Owner Role], s3.[Auth Owner Department(s)], s3.request_name, s3.auth_status, s3.ReferredBy
into #step4
from #step3 s3
join [PartnerExchange].[auths].[CCARemoteMailing_correction] crmc
on s3.auth_id = crmc.authid and crmc.correctedfilename not like '%exten%'
left join [PartnerExchange].[auths].[CCARemoteMailing] crm
on crmc.filename = crm.filename
group by s3.LAST_NAME, s3.FIRST_NAME, s3.CCAID, s3.Contract_ID, s3.AUTH_ID, s3.Received_Date, s3.[Service Code(s)], s3.[Service Description(s)], s3.auth_priority, s3.IS_extension, s3.[ODAG Decision_status], s3.[ORG Determination decision_Status],
s3.Decision_Date, s3.Verbal_Notification, s3.auth_type_name, s3.CMO, s3.deadline, s3.DECISION_STATUS_CODE_DESC, s3.request_source, s3.[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?], s3.denialrole, s3.AUTH_NO, 
s3.PATIENT_ID, s3.LOB_BEN_ID, s3.ExternallyManaged, s3.mcarepayable, s3.MIN_SERVICE_FROM_DATE, s3.MAX_SERVICE_TO_DATE, s3.Adjusted_AdjustedCheck, s3.AuthCreatedDate, s3.AuthCreatedBy, s3.[Auth Createdby Role], 
s3.[Auth CreatedBy Department(s)], s3.[Auth owner], s3.[Auth Owner Role], s3.[Auth Owner Department(s)], s3.request_name, s3.auth_status, s3.ReferredBy

union

select s3.LAST_NAME, s3.FIRST_NAME, s3.CCAID, s3.Contract_ID, s3.AUTH_ID, s3.Received_Date, s3.[Service Code(s)], s3.[Service Description(s)], s3.auth_priority, s3.IS_extension, s3.[ODAG Decision_status], s3.[ORG Determination decision_Status],
s3.Decision_Date, s3.Verbal_Notification, 
case when [ODAG Decision_status] = 'Denied' and cast(s3.WrittenNotifDate as datetime) >= '2020-03-26 16:52:00' then min(crm.printandmailtime)
else s3.WrittenNotifDate end as WrittenNotifDate, --s3.WrittenNotifDate,
s3.auth_type_name, s3.CMO, s3.deadline, s3.DECISION_STATUS_CODE_DESC, s3.request_source, s3.[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?], s3.denialrole, s3.AUTH_NO, 
s3.PATIENT_ID, s3.LOB_BEN_ID, s3.ExternallyManaged, s3.mcarepayable, s3.MIN_SERVICE_FROM_DATE, s3.MAX_SERVICE_TO_DATE, s3.Adjusted_AdjustedCheck, s3.AuthCreatedDate, s3.AuthCreatedBy, s3.[Auth Createdby Role], 
s3.[Auth CreatedBy Department(s)], s3.[Auth owner], s3.[Auth Owner Role], s3.[Auth Owner Department(s)], s3.request_name, s3.auth_status, s3.ReferredBy
from #step3 s3
left join 
( 
	select * 
	from [PartnerExchange].[auths].[CCARemoteMailing] 
	where filename not like '%exten%'
	and [filename] not in 
	(
		select b.[filename]
		from [PartnerExchange].[auths].[CCARemoteMailing_correction] a
		join [PartnerExchange].[auths].[CCARemoteMailing] b
		on a.[filename] = b.[filename]
		where correctedfilename like '%exten%'
	)
)crm
--on crm.filename like '%' + s3.auth_id + '%'
on SUBSTRING(crm.filename,17, 9) = s3.auth_id
where s3.auth_id not in 
(
	select distinct authid from [PartnerExchange].[auths].[CCARemoteMailing_correction]
	where correctedfilename not like '%exten%'
	--and authid in ('0205W2EA1','0206T341F')
) 
--and s3.auth_id in ('0205W2EA1','0206T341F')
group by s3.LAST_NAME, s3.FIRST_NAME, s3.CCAID, s3.Contract_ID, s3.AUTH_ID, s3.Received_Date, s3.[Service Code(s)], s3.[Service Description(s)], s3.auth_priority, s3.IS_extension, s3.[ODAG Decision_status], s3.[ORG Determination decision_Status],
s3.Decision_Date, s3.Verbal_Notification, 
--case when [ODAG Decision_status] = 'Denied' and s3.WrittenNotifDate >= '2020-03-26 14:52:00' then min(crm.printandmailtime)
s3.WrittenNotifDate, s3.auth_type_name, s3.CMO, s3.deadline, s3.DECISION_STATUS_CODE_DESC, s3.request_source, s3.[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?], s3.denialrole, s3.AUTH_NO, 
s3.PATIENT_ID, s3.LOB_BEN_ID, s3.ExternallyManaged, s3.mcarepayable, s3.MIN_SERVICE_FROM_DATE, s3.MAX_SERVICE_TO_DATE, s3.Adjusted_AdjustedCheck, s3.AuthCreatedDate, s3.AuthCreatedBy, s3.[Auth Createdby Role], 
s3.[Auth CreatedBy Department(s)], s3.[Auth owner], s3.[Auth Owner Role], s3.[Auth Owner Department(s)], s3.request_name, s3.auth_status, s3.ReferredBy


-- select * from #step4 where auth_id in ('0205W2EA1','0206T341F')

-- select count(*) from #step4

--select distinct auth_priority from #step4

IF OBJECT_ID('tempdb..#final') IS NOT NULL DROP TABLE #final;

select * 
, case  
when DECISION_DATE is null then 'NoDecision'
when received_date is null  then 'NA'
when datediff(dd,received_date, DECISION_DATE) < 0 then 'UntimelyDecision'  
when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%retro%'or auth_priority is null) then 'TimelyDecision'
when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%retro%' or auth_priority is null)  and is_extension = 'Y' then 'TimelyDecision'
when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%standard%'or auth_priority is null) then 'TimelyDecision'
when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%standard%' or auth_priority is null)  and is_extension = 'Y' then 'TimelyDecision'
when datediff(hour,received_date, DECISION_DATE)/24.0 <=3 and auth_priority like  '%Expedited%' and (is_extension ='N' or is_extension is null) then 'TimelyDecision'
when datediff(hour,received_date, DECISION_DATE)/24.0 <=17 and auth_priority like  '%Expedited%' and is_extension ='Y' then 'TimelyDecision'
else 'UntimelyDecision' 
end as 'DecisionFlag' 
into #final
from #step4 s1 
where [Service Code(s)] is not null and auth_id <>'1203M0E29'


IF OBJECT_ID('tempdb..#final2') IS NOT NULL DROP TABLE #final2;

select *
into #final2
from
(
	SELECT * 
	FROM #FINAL s1
	  where
		 ((s1.[ORG Determination decision_Status] = 'Pending' and s1.auth_type_name <>'Inpatient') or (s1.[ORG Determination decision_Status] <> 'Pending' and s1.auth_type_name ='Inpatient'))
		 
		
			or s1.AUTH_ID not in (select distinct AUTH_ID from #final s2 where ((s1.AUTH_ID = s2.AUTH_ID and s2.[ORG Determination decision_Status] = 'Pending' and s2.auth_type_name <>'Inpatient')
			or (s1.AUTH_ID = s2.AUTH_ID and s2.[ORG Determination decision_Status] <> 'Pending' and s2.auth_type_name ='Inpatient'))
			)
	)a 
	where 
 not((a.auth_id ='0108TD4B8'and [ORG Determination decision_Status] is null) or (a.auth_id ='0129TD250'and [ORG Determination decision_Status] is null))
	and [ORG Determination decision_Status] is not null

-- select count(*) from #final
	
-- select * from #final2 where auth_id in ('0731F4102','0724F87B4','1203TE605')
-- drop table #letters
select a.*
into #letters
from
(
select document_ref_id, letter_printed_Date as letter_date,	 'Approved' as 'Type'
, case when created_on >= '2019-06-28' then 'AH' else 'internal' end as 'TimeStampLogic' 
from Altruista.dbo.um_document (nolock)
where document_name like '%approv%' and document_type_id in (2,4)
and not (document_name like '%appeal%' or document_name like  '%reopen%')
and DELETED_ON is null and letter_printed_Date is not null
group by document_ref_id, letter_printed_Date 
, case when created_on >= '2019-06-28' then 'AH' else 'internal' end   

union

select document_ref_id, 
case when cast (created_on as time) < '16:00:00' then  created_on  else  dateadd (dd,1,created_on ) 
end as 'Letter Date'
,'Denied' as 'Type'
,'internal' as 'TimeStampLogic' 
from Altruista.dbo.um_document (nolock)
where ((document_name like '%denial%' and  document_type_id in (1,2)) or  document_type_id=6) 
and DELETED_ON is null
group by document_ref_id, 
case when cast (created_on as time) < '16:00:00'
then created_on else dateadd (dd,1,created_on ) end
)a


-- select * from #letters where document_ref_id = '341638'
-- drop table #letters_v2
		  
select *, 
case when [type]='approved' and [timestamplogic]='internal' then  dateadd (hour, 12, cast(cast (letter_date as date) as datetime))
when [type]='denied' then dateadd (hour, 16, cast(cast (letter_date as date) as datetime))  
else letter_date
end as 'Correct_Letter_Date'
into #letters_v2
from #letters

-- select * from #letters_v2 where document_ref_id = '376337'	

IF OBJECT_ID('tempdb..#final3') IS NOT NULL DROP TABLE #final3;

select 
Contract_ID
, CCAID
, AUTH_ID
, Received_Date	
, [Service Code(s)]
, [Service Description(s)]
, auth_priority	
, IS_extension	
, auth_status
, MCarePayable
, [ORG Determination decision_Status]
, Decision_Date	
, DECISION_STATUS_CODE_DESC
, Verbal_Notification	
, WrittenNotifDate	
, auth_type_name	
, deadline
, Adjusted_AdjustedCheck	
, min_SERVICE_FROM_DATE	
, max_SERVICE_to_DATE	
, f.auth_no	
, DecisionFlag	
, let.CORRECT_letter_date
, [lettercount]
, es.decisions
, request_source
,REQUEST_NAME
,ReferredBy
,dense_rank () over (partition by  let.[document_REF_ID] order by let.[type] desc, let.letter_Date asc) as letter_ORDER
, case when let.correct_letter_date is Null and  let2.correct_letter_date < decision_date then 'Yes' ELSE 'NA' end as 'Letter before decision'
, CMO			
, AuthCreatedDate	
,AuthCreatedBy	
,[Auth Createdby Role]
, [Auth CreatedBy Department(s)]
, [Auth owner]
, [Auth Owner Role]	
, [Auth Owner Department(s)]	
into #final3
from
(
	select *, 
	case when [ORG Determination decision_Status]='Partially Approved' then 'Denied' 
	else [ORG Determination decision_Status]
	end as 'New Decision' 
	from  #final2
) f
left join #letters_v2 let 
on f.auth_no=let.document_ref_id and correct_letter_date >= decision_date  
left join #letters_v2 let2 
on f.auth_no=let2.document_ref_id and f.[new decision]=let2.[type]
left join  
(
	select document_ref_id
	, count(letter_date) as lettercount 
	, STUFF(
		ISNULL(
				(
					SELECT
						' | ' +S2.[type]
					FROM #letters_V2 AS S2
					WHERE S2. document_ref_id = l.document_ref_id 
					GROUP BY
						S2.[type]
					FOR XML PATH (''), TYPE
				).value('.', 'VARCHAR(MAX)') 
			, '')
		, 1, 2, '') AS 'Decisions'
	from #letters_V2 l 
	group by document_Ref_id
) es 
on f.auth_no=es.document_ref_id 
group by
Contract_ID
, CCAID
, AUTH_ID	
,Received_Date	
,[Service Code(s)]
, [Service Description(s)]
, auth_priority	
, IS_extension	
, auth_status
, MCarePayable
,[ORG Determination decision_Status]
, Decision_Date	
,DECISION_STATUS_CODE_DESC
, Verbal_Notification	
, WrittenNotifDate	
, auth_type_name	
, deadline
, Adjusted_AdjustedCheck	
, min_SERVICE_FROM_DATE	
, max_SERVICE_to_DATE	
,f.auth_no	
, DecisionFlag	
,let.[document_REF_ID] 
, let.[type]
, let.letter_Date 
, let.CORRECT_letter_date
, [lettercount]
, es.decisions
, request_source
,REQUEST_NAME
,ReferredBy
, case when let.correct_letter_date is Null and  let2.correct_letter_date < decision_date then 'Yes' ELSE 'NA' end 
, CMO			
, AuthCreatedDate	
,AuthCreatedBy	
,[Auth Createdby Role]
, [Auth CreatedBy Department(s)]
, [Auth owner]
, [Auth Owner Role]	
, [Auth Owner Department(s)]	
order by auth_id

-- select * from #final3 where auth_id in ('0826W1ECA')

-- select count(*) from #final3


--select distinct [ORG Determination decision_Status]
--from #final3

IF OBJECT_ID('tempdb..#final4') IS NOT NULL DROP TABLE #final4;

select 
Contract_ID
, CCAID
, AUTH_ID
,Received_Date	
,[Service Code(s)]
, [Service Description(s)]
, auth_priority	
, IS_extension	
, auth_status
, MCarePayable
,[ORG Determination decision_Status]
, Decision_Date	
,DECISION_STATUS_CODE_DESC
, case when (Verbal_Notification='1900-01-01 00:00:00.000' or Verbal_Notification is null or Verbal_Notification = ' ') and v.verbaldate is null then Null 
when (Verbal_Notification='1900-01-01 00:00:00.000' or Verbal_Notification is null or Verbal_Notification = ' ') and v.verbaldate is not null then  v.verbaldate
when [ORG Determination decision_Status] in ('Denied') then verbal_notification 
when [ORG Determination decision_Status] in  ('Partially Approved') then coalesce (Verbal_Notification, v.verbaldate)
when cast(Verbaldate as datetime) <= cast(Verbal_Notification as datetime) then Verbaldate
else Verbal_Notification 
end as 'Verbal_Notification_Combined'

, case when Verbal_Notification='1900-01-01 00:00:00.000' then Null else verbal_notification end as 'UM_Verbal'

, v.verbaldate as 'SharePoint_Verbal'
--, CORRECT_letter_date as 'WrittenNotifDate'
, case when f.[ORG Determination decision_Status] in ('Denied','Partially Approved') then f.[WrittenNotifDate] 
when f.[ORG Determination decision_Status] = 'Approved' then f.CORRECT_letter_date
else f.CORRECT_letter_date end as 'WrittenNotifDate'	
, auth_type_name	
, deadline
, Adjusted_AdjustedCheck	
, min_SERVICE_FROM_DATE	
, max_SERVICE_to_DATE	
, f.auth_no	
, DecisionFlag	
, case when received_date is null then 'NA'
when CORRECT_LETTER_dATE is null and  cast (deadline as date) <= cast (getdate() as date) then 'UntimelyLetter'
when CORRECT_LETTER_dATE is null and  cast (deadline as date) > cast (getdate() as date)  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 0 then 'UntimelyLetter' 
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'retrospective')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'retrospective') and is_extension = 'Yes' then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'Prospective Standard')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'Prospective Standard') and is_extension = 'Yes' then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE))/24.0 <= 3 and auth_priority = 'Prospective Expedited' and (is_extension = 'No' or is_extension is null) then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE))/24.0 <= 17 and auth_priority  = 'Prospective Expedited' and is_extension = 'Yes' then 'TimelyLetter'
else 'UntimelyLetter' 
end as 'LetterFlag'
, [lettercount]
, decisions as lettertype
, request_source
, REQUEST_NAME
, ReferredBy
, [Letter before decision]
, CMO			
, AuthCreatedDate	
, AuthCreatedBy	
, [Auth Createdby Role]
, [Auth CreatedBy Department(s)]
, [Auth owner]
, [Auth Owner Role]	
, [Auth Owner Department(s)]	
into #final4
from #final3 f
left join 
(
	--select referralid, verbaldate--modified as verbaldate
	--from sandbox_Sshegow.dbo.verbalnotificationuptodec162019
	select referralid, min(modified) as verbaldate
	from [Medical_Analytics].[dbo].[src_excel_sharepoint_verbal_notification_archive]  
	where referralid is not null
	--and referralid in ('0222S581C')
	group by referralid
) v 
on f.auth_id=v.referralid
where letter_order=1
and [ORG Determination decision_Status] in ('Approved', 'Denied', 'Partially Approved', 'Void') 
--and f.auth_id in ('1102M22FF')
group by
Contract_ID
, CCAID
, AUTH_ID
, Received_Date	
, [Service Code(s)]
, [Service Description(s)]
, auth_priority	
, IS_extension	
, auth_status
, MCarePayable
, [ORG Determination decision_Status]
, Decision_Date	
, DECISION_STATUS_CODE_DESC
, case when (Verbal_Notification='1900-01-01 00:00:00.000' or Verbal_Notification is null or Verbal_Notification = ' ') and v.verbaldate is null then Null 
when (Verbal_Notification='1900-01-01 00:00:00.000' or Verbal_Notification is null or Verbal_Notification = ' ') and v.verbaldate is not null then  v.verbaldate
when [ORG Determination decision_Status] in ('Denied') then verbal_notification 
when [ORG Determination decision_Status] in  ('Partially Approved') then coalesce (Verbal_Notification, v.verbaldate)
when cast(Verbaldate as datetime) <= cast(Verbal_Notification as datetime) then Verbaldate
else Verbal_Notification end 
, case when Verbal_Notification='1900-01-01 00:00:00.000' then Null else verbal_notification end 
, v.verbaldate 
, case when f.[ORG Determination decision_Status] in ('Denied','Partially Approved') then f.[WrittenNotifDate] 
when f.[ORG Determination decision_Status] = 'Approved' then f.CORRECT_letter_date
else f.CORRECT_letter_date end
, auth_type_name	
, deadline
, Adjusted_AdjustedCheck	
, min_SERVICE_FROM_DATE	
, max_SERVICE_to_DATE	
, f.auth_no	
, DecisionFlag	
, case 
when received_date is null then 'NA'
when CORRECT_LETTER_dATE is null and  cast (deadline as date) <= cast (getdate() as date) then 'UntimelyLetter'
when CORRECT_LETTER_dATE is null and  cast (deadline as date) > cast (getdate() as date)  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 0 then 'UntimelyLetter' 
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'retrospective')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'retrospective') and is_extension = 'Yes' then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'Prospective Standard')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'Prospective Standard') and is_extension = 'Yes' then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE))/24.0 <= 3 and auth_priority = 'Prospective Expedited' and (is_extension = 'No' or is_extension is null) then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE))/24.0 <= 17 and auth_priority  = 'Prospective Expedited' and is_extension = 'Yes' then 'TimelyLetter'
else 'UntimelyLetter' 
end 
, [lettercount]
, decisions 
, request_source
,REQUEST_NAME
,ReferredBy
,[Letter before decision]
, CMO			
, AuthCreatedDate	
,AuthCreatedBy	
,[Auth Createdby Role]
, [Auth CreatedBy Department(s)]
, [Auth owner]
, [Auth Owner Role]	
, [Auth Owner Department(s)]	
order by auth_id



--select * from #final4 where auth_id in ('0506WFF55')


--select count(*) from #final4

IF OBJECT_ID('tempdb..#final5') IS NOT NULL DROP TABLE #final5;
		   
select *, case 
--when verbal_notification_combined is null and writtennotifdate is  null then null
--when verbal_notification_combined is null and writtennotifdate is not null then writtennotifdate
when (verbal_notification_combined is null or verbal_notification_combined = '1900-01-01 00:00:00.000' or Verbal_Notification_Combined = ' ') and writtennotifdate is null then null
when (verbal_notification_combined is null or verbal_notification_combined = '1900-01-01 00:00:00.000' or Verbal_Notification_Combined = ' ') and writtennotifdate is not null then writtennotifdate
when verbal_notification_combined is not null and Verbal_Notification_Combined <> ' ' and writtennotifdate is null then verbal_notification_combined
when verbal_notification_combined is not null and Verbal_Notification_Combined <> ' ' and cast(verbal_notification_combined as datetime) < cast(writtennotifdate as datetime) then verbal_notification_combined 
else writtennotifdate end as 'Notification_Combined (WrittenOrVerbal)'
into #final5
from #final4  
--where auth_id = '0729W197C'

--select count(*) from #final5


IF OBJECT_ID('tempdb..#final6') IS NOT NULL DROP TABLE #final6;

SELECT * 
INTO #FINAL6
FROM #FINAL5
where  COALESCE ([Notification_Combined (WrittenOrVerbal)], DEADLINE)
 >= '2020-01-01'--@startdate 
 
-- select count(*) from #final6
 


IF OBJECT_ID('tempdb..#auths') IS NOT NULL DROP TABLE #auths;

;with temp as
(
select 
Contract_ID
	, CCAID as 'Member_ID'
 ,Auth_id as Case_id
, Received_date as Receipt_Date
 	,'n/a' as 'AOR_Receipt_Date'
	,case when is_extension ='y' then 1 else 0
		end as 'Extension',
	--case when auth_priority like '%Prospective Expedited%' then 1 else 0 end as 'Expedited'
	case when auth_priority like '%Expedited%' then 1 else 0 end as 'Expedited'
		,case when auth_status like 'withdraw%' then 4
	 when [ORG Determination decision_Status] ='Approved' then 1
		when [ORG Determination decision_Status] like '%denied%' then 3
		
		when [ORG Determination decision_Status] like '%Partially Approved%' then 2
		 
		else 9
		 end as 'Decision_id'
, decision_date 
,Verbal_Notification_combined
, Sharepoint_verbal
, UM_verbal
, WrittenNotifDate 
, [Notification_Combined (WrittenOrVerbal)]
, [Notification_Combined (WrittenOrVerbal)] as ResolvedDate  
	,case when auth_status like 'withdraw%' then '4-Withdrawn'
	 when [ORG Determination decision_Status] ='Approved' then '1-Fully Favorable'
		when [ORG Determination decision_Status] is null then 'check'
		when [ORG Determination decision_Status] like '%denied%' then '3-Adverse'
		when [ORG Determination decision_Status] like '%Partially Approved%' then '2-Partially Favorable'
		when [ORG Determination decision_Status] = 'pending' then '9-Pending' 
		else 'check'
		end as 'Decision_Key'
,'' as Reopened
,case when month(coalesce([Notification_Combined (WrittenOrVerbal)], decision_date)) between 1 and 3 then 1
when month(coalesce([Notification_Combined (WrittenOrVerbal)], decision_date))  between 4 and 6 then 2 
when month(coalesce([Notification_Combined (WrittenOrVerbal)], decision_date))  between 7 and 9 then 3
when month(coalesce([Notification_Combined (WrittenOrVerbal)], decision_date))  between 10 and 12 then 4 else 99 end as Quarter
,mcarepayable
, auth_status
	,  [ORG Determination decision_Status]
	, min_service_from_date,
	max_service_to_date, [service code(s)], [service description(s)]
	, auth_no
	, request_source
	, request_name
	,ReferredBy
	,  lettertype
		, [Letter before decision]
from  #final6 a 
group by
Contract_ID
	, CCAID 
 ,auth_id 
, Received_date 
	,case when is_extension ='y' then 1 else 0
		end ,
	case when auth_priority like '%Expedited%' then 1 else 0 end 

		,case when auth_status like 'withdraw%' then 4
	 when [ORG Determination decision_Status] ='Approved' then 1
		when [ORG Determination decision_Status] like '%denied%' then 3
		
		when [ORG Determination decision_Status] like '%Partially Approved%' then 2
		 
		else 9
		 end 
, decision_date 
, Verbal_Notification_combined
, Sharepoint_verbal
, UM_verbal
, WrittenNotifDate
,[Notification_Combined (WrittenOrVerbal)]
	,case when auth_status like 'withdraw%' then '4-Withdrawn'
	 when [ORG Determination decision_Status] ='Approved' then '1-Fully Favorable'
		when [ORG Determination decision_Status] is null then 'check'
		when [ORG Determination decision_Status] like '%denied%' then '3-Adverse'
		when [ORG Determination decision_Status] like '%Partially Approved%' then '2-Partially Favorable'
		when [ORG Determination decision_Status] = 'pending' then '9-Pending' 
		else 'check'
		end 
,case when month(coalesce([Notification_Combined (WrittenOrVerbal)], decision_date)) between 1 and 3 then 1
when month(coalesce([Notification_Combined (WrittenOrVerbal)], decision_date))  between 4 and 6 then 2 
when month(coalesce([Notification_Combined (WrittenOrVerbal)], decision_date))  between 7 and 9 then 3
when month(coalesce([Notification_Combined (WrittenOrVerbal)], decision_date))  between 10 and 12 then 4 else 99 end 
,mcarepayable
, auth_status
	,  [ORG Determination decision_Status]
	, min_service_from_date,
	max_service_to_date, [service code(s)], [service description(s)], auth_no
		, request_source
		, request_name
	,ReferredBy
	,  lettertype
		, [Letter before decision]

)
select *
into  #auths
from temp
--where case_id in ('1118W65C3','0731FF9FE','0506WFF55')


 --select * from #auths where cast(max_service_to_date as date) < cast(receipt_Date as date)


 --select * from #providers where auth_no in ('438801','396291','355199')


IF OBJECT_ID('tempdb..#auths2') IS NOT NULL DROP TABLE #auths2;

SELECT [Contract_ID] as Contract_No
,[Member_ID]
,convert(varchar(20),[Case_ID]) as Case_ID
,CONVERT(VARCHAR(10),[Receipt_Date], 101)+ ' ' + CONVERT(VARCHAR(10), [Receipt_Date], 108) AS [Receipt_Date]
,[AOR_Receipt_Date]
,[Extension]
,[Expedited]
,CONVERT(VARCHAR(10),Resolveddate, 101)+ ' ' +	CONVERT(VARCHAR(10), [ResolvedDate], 108)  as [Resolved_Date]
,case when a.request_source IN ('Member','Member Representative','Care Partner/Manager or Service Coordinator') then 1
when a.request_source in ('Provider')
	and e.referred_by_provider_id is not null 
	and a.[Receipt_Date] between e.ref_by_validity_from and e.ref_by_validity_to
	and e.ref_by_provider_capacity = 'PAR' then 1
when a.request_source in ('Provider')
	and e.referred_by_provider_id is not null 
	and  a.[Receipt_Date] not between e.ref_by_validity_from and e.ref_by_validity_to then 2
when a.request_source in ('Provider')
	and e.referred_by_provider_id is not null
	and e.ref_by_provider_capacity like '%non%par%' then 2
when a.request_source is null
	and e.referred_by_provider_id is not null 
	and  a.[Receipt_Date] between e.ref_by_validity_from and e.ref_by_validity_to
	and e.ref_by_provider_capacity = 'PAR' then 1
when a.request_source is null
	and e.referred_by_provider_id is not null 
	and  a.[Receipt_Date] not between e.ref_by_validity_from and e.ref_by_validity_to then 2
when a.request_source is null
	and e.referred_by_provider_id is not null
	and e.ref_by_provider_capacity like '%non%par%' then 2		
when a.request_source in ('Provider')
	and e.referred_by_provider_name like 'Out of Network%'or ref_by_validity_from is null
	then 2			 
else 99 end as 'Type (Who Made the Request-1=CP,2=NCP)'	
,[Decision_id]
,case when month(resolveddate) between 1 and 3 then 1
when  month(resolveddate)  between 4 and 6 then 2 
when  month(resolveddate)  between 7 and 9 then 3
when  month(resolveddate) between 10 and 12 then 4 else 99 end as Quarter
into #auths2
FROM #auths a
left join #providers e 
on a.auth_no = e.auth_no
GROUP BY
[Contract_ID]
,[Member_ID]
,[Case_id]
,[Receipt_Date]
,[AOR_Receipt_Date]
,[Extension]
,[Expedited]
,[ResolvedDate]
,case when a.request_source IN ('Member','Member Representative','Care Partner/Manager or Service Coordinator') then 1
when a.request_source in ('Provider')
	and e.referred_by_provider_id is not null 
	and a.[Receipt_Date] between e.ref_by_validity_from and e.ref_by_validity_to
	and e.ref_by_provider_capacity = 'PAR' then 1
when a.request_source in ('Provider')
	and e.referred_by_provider_id is not null 
	and  a.[Receipt_Date] not between e.ref_by_validity_from and e.ref_by_validity_to then 2
when a.request_source in ('Provider')
	and e.referred_by_provider_id is not null
	and e.ref_by_provider_capacity like '%non%par%' then 2
when a.request_source is null
	and e.referred_by_provider_id is not null 
	and  a.[Receipt_Date] between e.ref_by_validity_from and e.ref_by_validity_to
	and e.ref_by_provider_capacity = 'PAR' then 1
when a.request_source is null
	and e.referred_by_provider_id is not null 
	and  a.[Receipt_Date] not between e.ref_by_validity_from and e.ref_by_validity_to then 2
when a.request_source is null
	and e.referred_by_provider_id is not null
	and e.ref_by_provider_capacity like '%non%par%' then 2
when a.request_source in ('Provider')
	and e.referred_by_provider_name like 'Out of Network%'or ref_by_validity_from is null
	then 2		
else 99 end 
,[Decision_id]
,case when month(resolveddate) between 1 and 3 then 1
when  month(resolveddate)  between 4 and 6 then 2 
when  month(resolveddate)  between 7 and 9 then 3
when  month(resolveddate) between 10 and 12 then 4 else 99 end 

-- select count(*) from #auths2
-- select * from #auths2 where case_id in ('0930W08D0','0721T6C8E','1210T6A69')


-- drop table #faxdocument
IF OBJECT_ID('tempdb..#faxdocument') IS NOT NULL DROP TABLE #faxdocument;

select 
d.*,
case when  patindex ('%[2][0][0-2][0-9][0-1][0-9][0-3][0-9]%', document_name)>0 
then SubString (document_name, patindex ('%[2][0][0-2][0-9][0-1][0-9][0-3][0-9]%', document_name), 8)
when patindex ('%[2][0][0-2][0-9][ ][0-1][0-9][ ][0-3][0-9]%', document_name)>0 
then SubString (document_name, patindex ('%[2][0][0-2][0-9][ ][0-1][0-9][ ][0-3][0-9]%', document_name), 10)
when patindex ('%[2][0][0-2][0-9][-][0-1][0-9][-][0-3][0-9]%', document_name)>0 
then SubString (document_name, patindex ('%[2][0][0-2][0-9][-][0-1][0-9][-][0-3][0-9]%', document_name), 11)
when patindex ('%[2][0][0-2][0-9][_|-|.][0-1][0-9][_|-|.][0-3][0-9]%', document_name) > 0 
then SubString ( document_name, patindex ('%[2][0][0-2][0-9][_|-|.][0-1][0-9][_|-|.][0-3][0-9]%', document_name), 11)
end as 'docDATE',
case when  patindex ('%[2][0][0-2][0-9][0-1][0-9][0-3][0-9]%', document_name)>0 
then SubString (document_name, patindex ('%[2][0][0-2][0-9][0-1][0-9][0-3][0-9]%', document_name) + 9, 4)
when patindex ('%[2][0][0-2][0-9][ ][0-1][0-9][ ][0-3][0-9]%', document_name)>0 
then SubString (document_name, patindex ('%[2][0][0-2][0-9][ ][0-1][0-9][ ][0-3][0-9]%', document_name) + 11, 4)
end as 'docTime'
into #faxdocument
from
(
	select document_ref_id, document_name, document_desc, created_on 
	from Altruista.dbo.um_document (nolock) u 
	where (document_type_id in (5,12,14,3) or document_name like '%fax%')
	and u.deleted_on is null
	--and u.CREATED_ON >='2019-03-01'
	group by document_ref_id, document_name, document_desc, created_on
) d 
inner join 
(
	SELECT * 
	FROM
	(
		SELECT * ,  dense_rank () over (partition by  document_ref_id order by PICK,MIN_CREATED desc) as PICKORDER---Sorting by Latest note first
		FROM
		(
			select document_ref_id , min(created_on) as min_created, 'TYPE1' AS'PICK' 
			from Altruista.dbo.um_document(nolock) u 
			where document_type_id in (5, 12)
			and u.deleted_on is null 	--and u.CREATED_ON >='2019-03-01'
			group by document_ref_id
	   
			UNION

			select document_ref_id , min(created_on) as min_created, 'TYPE2' AS'PICK' 
			from Altruista.dbo.um_document(nolock)u 
			where (document_type_id in (14,3) or document_name like '%fax%')
			and u.deleted_on is null 	--and u.CREATED_ON >='2019-03-01'
			group by document_ref_id
	   )A 
	)B 
	WHERE PICKORDER=1----Amelia specified to choose auth request type documents first
) m 
on m.document_ref_id=d.document_ref_id and m.min_created=d.created_on




--select * 
--from #auths2
--where decision_id = 4



IF OBJECT_ID('tempdb..#final_auth') IS NOT NULL DROP TABLE #final_auth;

select 
a.*
, f.*
, b.decision_count
, case when resolved_date is null or receipt_date  is null or decision_date <  received_date then 'Yes' else 'No' 
end as 'Error: Resolved Date before Receipt Date or Receipt/Resolved Date is null' 
, case when r.auth_id is not null then 'yes' else 'no' end as 'Retro (based on date logic)'
, case when reo.auth_no is not null then 'yes' else 'no' end as 'Reopening Letter'
, case when appch.auth_no is not null then 'yes' else 'no' end as 'Appealsform'
, replace(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(8000),isnull (
note1 + note2 + note3 + note4 + note5 + note6 + note7 + note8 + note9 + note10, '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, ''''), char(34), '''')  as latest3notes

, case when f.[ORG Determination decision_status]='pending' then 'Yes' else 'No' end as 'Pending Decision'
, case when f.WrittenNotifDate is not null then 'Yes' else 'No' end as 'LetterSent'
, case when cast(f.decision_date as date) < cast(f.Received_Date as date) then 'Yes' else 'No' end as 'Decision before Receipt'
, case when f.writtenNotifDate is null then 'NA'
	when cast(f.WrittenNotifDate as date) < cast(f.decision_date as date) then 'Yes' else 'No' end as 'Written before Decision'
, case when step.Is_extension='y' and step.[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?]='n' then 'Yes'
	when step.Is_extension='y' and step.[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?]='Y' THEN 'No' else 'NA'
	end as 'ExtensionLetterMissing?'
, case when rr.auth_no is not null then 'Yes' else 'No' end as 'More than One who made the request'
, case when cast(f.min_service_from_date as date) < cast(f.received_Date as date) then 'Yes' else 'No' end as 'Min Start date is prior to request date'
, case when cast(f.max_SERVICE_to_DATE as date) < cast(f.received_Date as date) then 'Yes' else 'No' end as 'MAx end date is prior to request date'
, do.document_name
, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
  REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
  REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
  REPLACE(REPLACE(convert(varchar(500),isnull (do.document_desc, '')),
  CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
  CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
  CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
  CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  as document_desc
, case when cast(f.Received_Date as datetime) = TRY_CAST(replace (replace (replace (do.docdate, ' ',''),'.',''),'-','') + ' '+ case when ISNUMERIC (do.doctime)=0 then '' else substring(do.doctime, 0, 3)+':'+substring(do.doctime, 3, 3) end as datetime)
	then 'Yes' else 'No' end as 'ReceiptFaxmatch(DATETIMEMATCH)'
, case when cast(f.Received_Date as date)=TRY_CAST(REPLACE(replace (replace (replace (do.docdate, ' ',''),'.',''),'-',''),'_','')AS DATE) then 'Yes' else 'No' 
	end as 'ReceiptFaxmatch(DATEMATCH)'
, case when cast(f.Received_Date as date)=TRY_CAST(REPLACE(replace (replace (replace (do.docdate, ' ',''),'.',''),'-',''),'_','')AS DATE) then 'Yes' 
	WHEN f.REQUEST_NAME in ('Internal Request', 'Email', 'Phone', 'Mail', 'Web Portal') and CAST(f.AuthCreatedDate AS DATE)=CAST(f.Received_Date AS DATE)
	and (not(do.document_name like '%fax%') or do.document_name is null) then 'Yes'
	when fac.newfixeddate = cast(f.Received_Date as date)  then 'Yes' 
	when CAST(f.AuthCreatedDate AS DATE)=CAST(f.Received_Date AS DATE) then 'Yes'
	--when fac.[Authorization or Claim Number] is not null  and CAST(a.AuthCreatedDate AS DATE)=CAST(a.Received_Date AS DATE) then 'Yes'
	when fac.[Authorization or Claim Number] is not null then 'NoBUTReviewed'
	else 'No' 
	end as 'ReceiptFaxmatchwithREVIEW'
, replace (replace (replace (do.docdate, ' ',''),'.',''),'-','') as faxdate
, TRY_CAST(replace (replace (replace (do.docdate, ' ',''),'.',''),'-','') + ' '+ case when ISNUMERIC (do.doctime)=0 then '' else substring(do.doctime, 0, 3)+':'+substring(do.doctime, 3, 3) end as datetime) as faxdatetime
, case when DATEADD(MINUTE, DATEDIFF(MINUTE, 0, f.AuthCreatedDate), 0)=DATEADD(MINUTE, DATEDIFF(MINUTE, 0, f.Received_Date), 0)
	then 'Yes' else 'No' end as 'CreateDateMatchReceiptDate(DATETIMEMATCH)'
, case when CAST(f.AuthCreatedDate AS DATE)=CAST(f.Received_Date AS DATE)
	then 'Yes' else 'No' end as 'CreateDateMatchReceiptDate(DATEATCH)'
, case when appch.auth_no is not null then 'Yes' else 'No' end as 'Appeal?'
, case when sm.auth_id is not null and f.auth_type_name	<>'transportation'
	then 'Yes' else 'No' end as 'SameServiceDateAndCodeButDifferentAuth'
, case when ( convert(nvarchar(8),f.um_verbal,108)  is null or f.um_verbal LIKE '%1900%' OR  f.um_verbal = '' ) then 'NA'
	when f.um_verbal < f.Decision_Date then 'yes' else 'No' end as 'oral before decision'


into #final_auth
from #auths2 a
left join #final6 f 
on f.auth_id=a.case_id
left join 
(
	select auth_id, count (distinct (cast (decision_date as date))) as decision_count 
	from #step b 
	group by auth_id
)b 
on f.auth_id=b.auth_id
left join 
(
	select auth_id 
	from #final6
	where cast([max_SERVICE_to_DATE] as date)  < cast(received_Date as date) 
)r 
on f.auth_id=r.auth_id
left join
( 
	select document_ref_id as auth_no
	from Altruista.dbo.um_document(nolock) u 
	where document_name like '%reopen%' 
	and u.deleted_on is null
	group by document_ref_id
) reo 
on f.auth_no=reo.auth_no
left join 
(
	select document_ref_id as auth_no
	from Altruista.dbo.um_document(nolock) u 
	where (document_name like '%reconsideration%' or document_name like '%appeal%' or document_name like '%overturn%')
	and u.deleted_on is null
	group by document_ref_id

	union
	   
	select auth_no 
	from #final3 
	where [Auth owner] like '%Tierney%Joseph%' or [Auth owner] like '%Rivera%Yesenia%' or [AuthCreatedBy] like '%Tierney%Joseph%' or [AuthCreatedBy] like '%Rivera%Yesenia%' 
	group by auth_no
) appch 
on f.auth_no=appch.auth_no
left join #notes_2 n 
on f.auth_no=n.[NOTE_REF_ID]

left join
(	
	select auth_no from #final6 
	group by auth_no 
	having count (distinct request_source)>1
)rr 
on f.auth_no=rr.auth_no---auths with more than one source of who made request
left join #FAXDOCUMENT do 
on f.auth_no = do.document_ref_id
LEFT JOIN 
(
	SELECT *, CASE WHEN FIXEDDATE='NA' THEN NULL ELSE CAST(FIXEDDATE AS DATE) END AS newfixeddate 
	FROM SANDBOX_sSHEGOW.DBO.faxerrorcheckauditMSSAR
) FAC 
ON f.AUTH_ID=FAC.[Authorization or Claim Number]
left join
(
	select b.Auth_id from
	(
		select Auth_id, ccaid, [Decision_status], service_from_date, service_to_date, [proc_code] 
		from #step1 
		group by Auth_id, ccaid, [Decision_status], service_from_date, service_to_date, [proc_code] 
	) a
	inner join 
	(
		select Auth_id, ccaid, [Decision_status], service_from_date, service_to_date, [proc_code] 
		from #step1 
		group by Auth_id, ccaid, [Decision_status], service_from_date, service_to_date, [proc_code] 
	)b 
	on b.ccaid=a.ccaid and b.service_from_date=a.service_from_date and b.service_to_date=a.service_to_date
	and b.[proc_code]=a.proc_code and b.[Decision_status]=a.[Decision_status] and b.[auth_id]<>a.[auth_id]
	group by b.Auth_id
) sm 
on f.auth_id=sm.auth_id
left join 
(
	select distinct auth_id, Is_extension,[If an extension was taken, did the sponsor notify the member of the reason(s) for the delay..?] from #step
) step
on f.auth_id = step.auth_id


begin tran
update #final_auth
set resolved_date = format(decision_date, 'MM/dd/yyyy HH:mm'),
quarter = case when month(decision_date) between 1 and 3 then 1
when  month(decision_date)  between 4 and 6 then 2 
when  month(decision_date)  between 7 and 9 then 3
when  month(decision_date) between 10 and 12 then 4 else 99 end
where decision_id = 4
--
commit tran

begin tran
update #final_auth
set decision_date = '2020-10-23 14:43:00.000'
where case_id = '1023F2B1C';
commit tran


--- Remove auths with received date in 2021– Removal 2021
begin tran
delete from #final_auth
where year(cast(receipt_date as date)) <> '2020'
--(1267 row(s) affected)
commit tran

--- remove any auths with resolve date that is not in 2020
begin tran
delete from #final_auth
where year(cast(resolved_date as date)) <> '2020'
--
commit tran





select base.*, q1.q1_total, q2.q2_total, q3.q3_total, q4.q4_total
from
(
	select distinct [Type (Who Made the Request-1=CP,2=NCP)]
	from #final_auth
)base
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q1_total
	from #final_auth
	where quarter = 1
	and decision_id <> 4
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q1
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q1.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q2_total
	from #final_auth
	where quarter = 2
	and decision_id <> 4
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q2
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q2.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q3_total
	from #final_auth
	where quarter = 3
	and decision_id <> 4
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q3
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q3.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q4_total
	from #final_auth
	where quarter = 4
	and decision_id <> 4
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q4
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q4.[Type (Who Made the Request-1=CP,2=NCP)]
order by 1



--- withdrawn

select distinct base.*, q1.q1_total, q2.q2_total, q3.q3_total, q4.q4_total
from
(
	select 'withdrawn' as temp
	from #final_auth
)base
left join 
(
	select 'withdrawn' as temp, count(*) as Q1_total
	from #final_auth
	where quarter = 1
	and decision_id = 4
)q1
on base.temp = q1.temp
left join 
(
	select 'withdrawn' as temp, count(*) as Q2_total
	from #final_auth
	where quarter = 2
	and decision_id = 4
	--order by 1, 2
)q2
on base.temp = q2.temp
left join 
(
	select 'withdrawn' as temp, count(*) as Q3_total
	from #final_auth
	where quarter = 3
	and decision_id = 4
)q3
on base.temp = q3.temp
left join 
(
	select 'withdrawn' as temp, count(*) as Q4_total
	from #final_auth
	where quarter = 4
	and decision_id = 4
)q4
on base.temp = q4.temp
order by 1





--- decision 1 (fully favorable)
select base.*, q1.q1_total, q2.q2_total, q3.q3_total, q4.q4_total
from
(
	select distinct [Type (Who Made the Request-1=CP,2=NCP)]
	from #final_auth
)base
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q1_total
	from #final_auth
	where quarter = 1
	and decision_id = 1
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q1
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q1.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q2_total
	from #final_auth
	where quarter = 2
	and decision_id = 1
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q2
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q2.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q3_total
	from #final_auth
	where quarter = 3
	and decision_id = 1
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q3
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q3.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q4_total
	from #final_auth
	where quarter = 4
	and decision_id = 1
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q4
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q4.[Type (Who Made the Request-1=CP,2=NCP)]
order by 1


--- decision 2 (partly favorable)
select base.*, q1.q1_total, q2.q2_total, q3.q3_total, q4.q4_total
from
(
	select distinct [Type (Who Made the Request-1=CP,2=NCP)]
	from #final_auth
)base
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q1_total
	from #final_auth
	where quarter = 1
	and decision_id = 2
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q1
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q1.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q2_total
	from #final_auth
	where quarter = 2
	and decision_id = 2
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q2
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q2.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q3_total
	from #final_auth
	where quarter = 3
	and decision_id = 2
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q3
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q3.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q4_total
	from #final_auth
	where quarter = 4
	and decision_id = 2
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q4
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q4.[Type (Who Made the Request-1=CP,2=NCP)]
order by 1


--- decision 3 (denied)
select base.*, q1.q1_total, q2.q2_total, q3.q3_total, q4.q4_total
from
(
	select distinct [Type (Who Made the Request-1=CP,2=NCP)]
	from #final_auth
)base
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q1_total
	from #final_auth
	where quarter = 1
	and decision_id = 3
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q1
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q1.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q2_total
	from #final_auth
	where quarter = 2
	and decision_id = 3
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q2
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q2.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q3_total
	from #final_auth
	where quarter = 3
	and decision_id = 3
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q3
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q3.[Type (Who Made the Request-1=CP,2=NCP)]
left join 
(
	select [Type (Who Made the Request-1=CP,2=NCP)], count(*) as Q4_total
	from #final_auth
	where quarter = 4
	and decision_id = 3
	group by quarter, [Type (Who Made the Request-1=CP,2=NCP)]
	--order by 1, 2
)q4
on base.[Type (Who Made the Request-1=CP,2=NCP)] = q4.[Type (Who Made the Request-1=CP,2=NCP)]
order by 1



