
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


--BEGIN TRAN 

--UPDATE #step
--SET DECISION_STATUS_CODE_DESC='Medical Necessity Not Established'
--from #step 
--where auth_id in ('0529WDC31')
--and DECISION_STATUS_CODE_DESC='Partial Approval'
--commit tran




	
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
				)	pn4 on piv."4" = pn4.provider_id


	create clustered index idx_auth_no on #providers(auth_no)
--;


-- select * from #providers where auth_no in ('396291','355199','438801')

-- select count(*) from #providers

--create table #auth_audit
--	(
--	 auth_no bigint not null
--	,auth_id nvarchar(50) not null
--	,patient_id bigint not null
--	,initial_auth_priority_id bigint null
--	,initial_auth_priority nvarchar(50) null
--	,last_auth_priority_id bigint null
--	,last_auth_priority nvarchar(50) null
--	,initial_auth_owner bigint null
--	,priority_change_auth_owner bigint null
--	,initial_updated_by bigint null
--	,priority_change_updated_by bigint null
--	,initial_updated_on datetime null
--	,priority_change_updated_on datetime null
--	,initial_physician_id bigint null
--	,init_phys_valid_from datetime null
--	,init_phys_valid_to datetime null
--	,init_phys_lob_id bigint null
--	,init_phys_prov_capacity nvarchar(50) null
--	,last_physician_id bigint null
--	,last_phys_valid_from datetime null
--	,last_phys_valid_to datetime null
--	,last_phys_lob_id bigint null
--	,last_phys_prov_capacity nvarchar(50) null
--	)
--		insert	into #auth_audit
--	(
--	 auth_no
--	,auth_id
--	,patient_id
--	,initial_auth_priority_id
--	,initial_auth_priority
--	,last_auth_priority_id
--	,last_auth_priority
--	,initial_auth_owner
--	,priority_change_auth_owner
--	,initial_updated_by
--	,priority_change_updated_by
--	,initial_updated_on
--	,priority_change_updated_on
--	,initial_physician_id
--	,init_phys_valid_from
--	,init_phys_valid_to
--	,init_phys_lob_id
--	,init_phys_prov_capacity
--	,last_physician_id
--	,last_phys_valid_from
--	,last_phys_valid_to
--	,last_phys_lob_id
--	,last_phys_prov_capacity
--	)
--	select distinct
--			 c.auth_no
--			,c.auth_id
--			,c.patient_id
--			,c.initial_auth_priority_id
--			,atp.auth_priority							as initial_auth_priority
--			,c.last_auth_priority_id
--			,atp2.auth_priority							as last_auth_priority
--			,c.initial_auth_owner
--			,c.priority_change_auth_owner
--			,c.initial_updated_by
--			,c.priority_change_updated_by
--			,c.initial_updated_on
--			,c.priority_change_updated_on
--			,c.initial_physician_id
--			,pn1.validity_from							as init_phys_valid_from
--			,pn1.validity_to								as init_phys_valid_to
--			,pn1.lob_id											as init_phys_lob_id
--			,pn1.provider_capacity					as init_phys_prov_capacity
--			,c.last_physician_id
--			,pn2.validity_from							as last_phys_valid_from
--			,pn2.validity_to								as last_phys_valid_to
--			,pn2.lob_id											as last_phys_lob_id
--			,pn2.provider_capacity					as last_phys_prov_capacity
--	from
--			(
--			select distinct
--					 b.auth_no
--					,b.auth_id
--					,b.patient_id
--					,max(case when b.rownum2 = 1 then b.auth_priority_id end) as initial_auth_priority_id
--					,max(case when b.rownum2 != 1 then b.auth_priority_id end) as last_auth_priority_id
--					,max(case when b.rownum2 = 1 then b.auth_cur_owner end) as initial_auth_owner
--					,max(case when b.rownum2 != 1 then b.auth_cur_owner end) as priority_change_auth_owner
--					,max(case when b.rownum2 = 1 then b.updated_by end) as initial_updated_by
--					,max(case when b.rownum2 != 1 then b.updated_by end) as priority_change_updated_by
--					,max(case when b.rownum2 = 1 then b.updated_on end) as initial_updated_on
--					,max(case when b.rownum2 != 1 then b.updated_on end) as priority_change_updated_on
--					,max(case when b.rownum2 = 1 then b.physician_id end) as initial_physician_id
--					,max(case when b.rownum2 != 1 then b.physician_id end) as last_physician_id
--			from
--					(
--					select distinct
--							 a.auth_no
--							,a.auth_id
--							,a.patient_id
--							,a.auth_priority_id
--							,row_number()over(partition by patient_id,auth_id,auth_priority_id order by a.updated_on) as rownum
--							,row_number()over(partition by patient_id,auth_id order by a.updated_on) as rownum2
--							,a.auth_cur_owner
--							,a.updated_by
--							,a.updated_on
--							,a.table_log_id
--							,aa.physician_id
--					from
--							Altruista.dbo.audit_um_auth_log a with(nolock) 
--					left join
--							Altruista.dbo.audit_um_auth_provider_log aa with(nolock) on a.table_log_id = aa.table_log_id
--					where
--							a.deleted_on is null
--					and	a.is_saved = 1 
--					) b
--			where 
--					b.rownum = 1
--			group by
--					 b.auth_no
--					,b.auth_id
--					,b.patient_id
--			) c
--	join
--			um_ma_auth_tat_priority atp with(nolock) on c.initial_auth_priority_id = atp.auth_priority_id
--			and atp.deleted_on is null
--	join
--			um_ma_auth_tat_priority atp2 with(nolock) on c.last_auth_priority_id = atp2.auth_priority_id
--			and atp2.deleted_on is null
--	left join
--			provider_network pn1 with(nolock) on c.initial_physician_id = pn1.provider_id
--			and pn1.deleted_on is null
--	left join
--			provider_network pn2 with(nolock) on c.last_physician_id = pn2.provider_id
--			and pn2.deleted_on is null
--	where 
--			c.initial_auth_priority_id !=	c.last_auth_priority_id

--	create clustered index idx_auth_no on #auth_audit(auth_no)
--;




--create table #patient_enroll
--	(
--	 patient_id bigint not null
--	,client_patient_id nvarchar(50) not null
--	,first_name nvarchar(200) null
--	,last_name nvarchar(200) null
--	,plan_desc nvarchar(4000) null
--	,plan_name nvarchar(1000) null
--	,start_date datetime null
--	,end_date datetime null
--	,lob_ben_id bigint null
--	,lob_id	bigint null
--	,lob_name nvarchar(1000) null
--	,CCA_Member_ID nvarchar(50) null
--	,aid_supplemental_description nvarchar(4000) null
--	)
--		insert	into #patient_enroll
--	(
--	 patient_id
--	,client_patient_id
--	,first_name
--	,last_name
--	,plan_desc
--	,plan_name
--	,start_date
--	,end_date
--	,lob_ben_id
--	,lob_id
--	,lob_name
--	,CCA_Member_ID
--	,aid_supplemental_description
--	)
--	select distinct
--			 pd.patient_id
--			,pd.client_patient_id
--			,pd.first_name
--			,pd.last_name
--			,bp.plan_desc
--			,bp.plan_name
--			,mbp.start_date
--			,mbp.end_date
--			,lbp.lob_ben_id
--			,l.lob_id
--			,l.lob_name
--			,pia.[Family_Link_ID]	as CCA_Member_ID
--			,pad.aid_supplemental_description

--	from
--			mem_benf_plan mbp with(nolock)
--	inner join
--			lob_benf_plan lbp with(nolock) on mbp.lob_ben_id = lbp.lob_ben_id
--			and lbp.deleted_on is null
--	inner join 
--			lob l with(nolock) on lbp.lob_id = l.lob_id
--			and l.deleted_on is null
--	inner join 
--			benefit_plan bp with(nolock) on lbp.benefit_plan_id = bp.benefit_plan_id
--			and bp.deleted_on is null
--	inner join
--			Altruista.dbo.patient_details pd with(nolock) on mbp.member_id = pd.patient_id
--			and pd.deleted_on is null
--	left join
--			Altruista.dbo.patient_index_all pia with(nolock) on pd.patient_id = pia.patient_id
--	left join
--			(
--				select distinct
--						 pasd.patient_id
--						,pasd.supplemental_code_id
--						,pasd.eligibility_startdate
--						,pasd.eligibility_enddate
--						,asd.aid_supplemental_description
--				from
--						Altruista.dbo.patient_aid_supplemental_details pasd with(nolock)
--				join
--						Altruista.dbo.aid_supplemental_details asd with(nolock) on pasd.supplemental_code_id = asd.supplemental_code_id
--				where 
--						pasd.deleted_on is null
--				and pasd.supplemental_code_id in (14,15,16,17,18,57)
--			) pad on pd.patient_id = pad.patient_id
--	where 
--			mbp.deleted_on is null
--	and l.lob_name = 'Medicare-Medicaid Duals'
--	and bp.plan_name in ('SCO-Externally Managed','SCO-CCA Managed')


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
--left join Altruista.dbo.um_document den -- bring in the denial letter 
--on s.auth_no = den.document_ref_id 
--and den.document_name like '%denial%'
--and den.document_type_id in (2,6)
--and den.deleted_on is null
--left join Altruista.dbo.um_document appr -- bring in the approve letter 
--on s.auth_no = appr.document_ref_id 
--and appr.document_name like '%approv%'
--and appr.document_type_id in (2,4)
--and appr.deleted_on is null
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

--select deadline, * from #final5 where auth_id in ('1118W65C3','0731FF9FE','0506WFF55')


IF OBJECT_ID('tempdb..#final6') IS NOT NULL DROP TABLE #final6;

SELECT * 
INTO #FINAL6
FROM #FINAL5
where  COALESCE ([Notification_Combined (WrittenOrVerbal)], DEADLINE)
 >= '2020-01-01'--@startdate 
 
-- select count(*) from #final6
 
begin tran
update #final6
set decision_date = '2020-04-22 13:24:00:000'
where auth_id = '0421T83FB';
update #final6
set decision_date = '2020-10-29 11:50:00:000'
where auth_id = '1028W2392';
update #final6
set decision_date = '2020-06-18 23:34:00:000'
where auth_id = '0615MEA61';
update #final6
set decision_date = '2020-08-19 16:31:00:000'
where auth_id = '0807F97CC';
commit tran
 
-- select [Notification_Combined (WrittenOrVerbal)], * from #final6 where auth_id in ('1118W65C3','0731FF9FE','0506WFF55')


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


--begin tran
--delete from #auths
--where cast(max_service_to_date as date) < cast(receipt_Date as date)
--commit tran


-- select count(*) from #auths

--begin tran
--update #auths
--set decision_id = 2, [ORG Determination decision_Status] = 'Partially Approved'
--where case_id in ('0827T85B5', '0410W2B7A');
--update #auths
--set decision_id = 3, [ORG Determination decision_Status] = 'Denied'
--where case_id in ('0610MBD08');
--update #auths
--set decision_id = 1, [ORG Determination decision_Status] = 'Approved'
--where case_id in ('1221FFA24', '0218M42D8', '0306W01AF', '0828W70A0', '0729MA533', '0313W4A58', '0306WC5FC');
--update #auths
--set Expedited = 1
--where case_id = '0109W241E'
--commit tran


--select top 100 * from #auths
--where case_id = '0807F97CC'



-- manually updated by Amelia

begin tran
update #auths
set decision_date = '2020-06-18 23:34:00.000', writtennotifdate = '2020-06-19 17:00:00.000', resolveddate = '2020-06-19 17:00:00.000'
where case_id = '0615MEA61';
update #auths
set decision_date = '2020-01-17 17:38:00.000', writtennotifdate = '2020-01-18 16:00:00.000', resolveddate = '2020-01-18 16:00:00.000'
where case_id = '0107TE8CD';
update #auths
set writtennotifdate = '2020-03-18 16:00:00.000',  resolveddate = '2020-03-18 16:00:00.000'
where case_id = '0310T5E41';
update #auths
set writtennotifdate = '2020-12-19 12:00:00.000', resolveddate = '2020-12-19 12:00:00.000'
where case_id = '1211FAE86';
update #auths
set decision_date = '2020-01-15 11:19:00.000', writtennotifdate = '2020-01-15 17:00:00.000', resolveddate = '2020-01-15 17:00:00.000'
where case_id = '0115W86FF';
update #auths
set decision_date = '2020-02-13 15:14:00.000', writtennotifdate = '2020-02-14 12:00:00.000', resolveddate = '2020-02-14 12:00:00.000'
where case_id = '0213T5AC6';

update #auths
set decision_date = '2020-08-19 16:31:00.000'
where case_id = '0807F97CC';
update #auths
set decision_date = '2020-07-06 10:13:00.000'
where case_id = '0706M8B87';
update #auths
set decision_date = '2020-06-05 12:48:00.000'
where case_id = '0602T2CF9';
update #auths
set decision_date = '2020-08-28 09:58:00.000'
where case_id = '0828F8674';

update #auths
set decision_date = '2020-10-29 11:50:00.000', writtennotifdate = '2020-10-30 12:00:00.000', resolveddate = '2020-10-30 12:00:00'
where case_id = '1028W2392';
--
commit tran


-- manual update UM_Verval by Amelia due to those auths are missing the verbal_notification on the line that's not MCarePayable (which got deleted from earlier process)

begin tran
update #auths
set UM_Verbal = '2020-08-26 15:04:00', resolveddate = '2020-08-26 15:04:00'
where case_id = '0826W1ECA';
update #auths
set UM_Verbal = '2020-04-06 15:00:00', resolveddate = '2020-04-06 15:00:00'
where case_id = '0406MC612';
update #auths
set UM_Verbal = '2020-07-28 10:33:00', resolveddate = '2020-07-28 10:33:00'
where case_id = '0724F4DB5';
update #auths
set UM_Verbal = '2020-12-08 14:58:00', resolveddate = '2020-12-08 14:58:00'
where case_id = '1208T59EC';
update #auths
set UM_Verbal = '2020-07-21 16:47:00', resolveddate = '2020-07-21 16:47:00'
where case_id = '0720M09C0';
update #auths
set UM_Verbal = '2020-07-30 15:26:00', resolveddate = '2020-07-30 15:26:00'
where case_id = '0729W8BA9';
update #auths
set UM_Verbal = '2020-12-22 16:03:00', resolveddate = '2020-12-22 16:03:00'
where case_id = '1210T882E';
update #auths
set UM_Verbal = '2020-08-26 08:40:00', resolveddate = '2020-08-26 08:40:00'
where case_id = '0825TB818';
update #auths
set UM_Verbal = '2020-07-28 10:33:00', resolveddate = '2020-07-28 10:33:00'
where case_id = '0724F4DB5';
commit tran

begin tran
update #auths
set resolveddate = '2020-04-23 12:00:00:000'
where case_id = '0421T83FB';
update #auths
set resolveddate = '2020-12-31 13:57:00:000'
where case_id = '1230W8F3E';
update #auths
set resolveddate = '2020-12-03 14:05:00:000'
where case_id = '1202W1C30';
update #auths
set resolveddate = '2020-10-01 15:11:00:000'
where case_id = '0930W3880';
update #auths
set resolveddate = '2020-12-31 13:38:00:000'
where case_id = '1214M9A1E';
update #auths
set resolveddate = '2020-10-05 14:19:00:000'
where case_id = '1002F1678';
update #auths
set resolveddate = '2020-06-18 13:18:00:000'
where case_id = '0615M580B';
update #auths
set resolveddate = '2020-02-03 15:35:00:000'
where case_id = '0131FBC97';
update #auths
set resolveddate = '2020-01-27 16:50:00:000'
where case_id = '0125S8835';
update #auths
set resolveddate = '2020-07-23 17:00:00:000'
where case_id = '0717FFE15';
update #auths
set resolveddate = '2020-07-14 17:00:00:000'
where case_id = '0702T1D43';
update #auths
set resolveddate = '2020-09-02 12:00:00:000'
where case_id = '0826WE979';
update #auths
set resolveddate = '2020-12-01 12:00:00:000'
where case_id = '1118W65C3';
update #auths
set resolveddate = '2020-08-10 11:05:00:000'
where case_id = '0731FF9FE';
update #auths
set resolveddate = '2020-09-21 10:41:00:000'
where case_id = '0909WFF50';
update #auths
set decision_id = 3
where case_id = '0826W8905'

update #auths
set resolveddate = '2020-02-15 12:00:000'
where case_id = '0214F3F90';
update #auths
set resolveddate = '2020-05-15 17:00:000'
where case_id = '0513W5D1A';
update #auths
set resolveddate = '2020-07-10 17:00:000'
where case_id = '0707T7F3F';
update #auths
set resolveddate = '2020-09-14 17:00:000'
where case_id = '0907MD1F3';

commit tran

--select * from #auths2 where case_id in ('0930W08D0','0721T6C8E','1210T6A69')





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


--;with base as
--(
--	select distinct a.case_id, a.resolved_Date, au.auth_no, d1.decision_status as decision_status_1, max(d1.updated_on) as updated_on_1, d2.decision_status as decision_status_2, max(d2.UPDATED_ON) as update_on_2
--	from #auths2 a
--	join [Altruista].dbo.um_auth au on a.case_id = au.auth_id
--	join [Altruista].[dbo].[AUDIT_UM_DECISION_LOG] d1 on au.auth_no = d1.auth_no
--	join [Altruista].[dbo].[AUDIT_UM_DECISION_LOG] d2
--	on d1.auth_no =d2.auth_no and d1.updated_on > d2.UPDATED_ON
--	where d1.decision_status = 8
--	and d2.DECISION_STATUS = 3
--	and a.Decision_id = 4
--	group by a.case_id, a.resolved_Date, au.auth_no, d1.decision_status, d2.decision_status
--)
--select 'H2225' as [Contract_No], a2.member_id, b.case_id, a2.receipt_Date, 'n/a' as [AOR_Receipt_Date], 0 as extension, a2.expedited as expedited, b.update_on_2 as [Resolved_Date], a2.[Type (Who Made the Request-1=CP,2=NCP)], 1 as decision_id,
--case when month(b.update_on_2) between 1 and 3 then 1
--when  month(b.update_on_2)  between 4 and 6 then 2 
--when  month(b.update_on_2)  between 7 and 9 then 3
--when  month(b.update_on_2) between 10 and 12 then 4 else 99 end as Quarter
--from base b
--join #auths2 a2
--on b.case_id = a2.case_id

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
--left join 
--(
--	SELECT 
--    [NOTE_REF_ID] as auth_no
--	FROM [Altruista].[dbo].[UM_NOTE]
--	WHERE DELETED_ON IS NULL and note_type_id=2
--	GROUP BY [NOTE_REF_ID]
    
--	union
	
--	select document_ref_id as auth_no
--	from Altruista.dbo.um_document u 
--	where document_name like '%reconsideration%' and u.deleted_on is null
--	group by document_ref_id
	
--	union
	
--	select auth_no 
--	from #final3 
--	where  [Auth owner] like '%Tierney%Joseph%' or  [Auth owner]  like '%Rivera%Yesenia%' or
--	   [AuthCreatedBy] like '%Tierney%Joseph%' or   [AuthCreatedBy] like '%Rivera%Yesenia%' 
--	group by auth_no
	
--	union
	
--	SELECT [NOTE_REF_ID]
--	FROM [Altruista].[dbo].[UM_NOTE]
--	WHERE DELETED_ON IS NULL 
--	and (note_info like '%Overturn%' or note_info like '%Maximus%' or note_info like '% IRE %' or note_info like '% COS %' OR note_info like '% BOH %' or
--	note_info like '%Continuation of Services%' or note_info like '%Appeal%' or note_info like '%Level 2%' or note_info like '%Effectuation%')
--	GROUP BY [NOTE_REF_ID]
--) app 
--on a.auth_no=app.auth_no
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

-- manually remove by Amelia
begin tran
delete from #final_auth
where auth_id in ('1120T7031','0417FD1AD','0321TCE51','0501WA00E','0508WCF4A','0618T5FE0','1003TBE17','0117FC1C7','0117FDDF8','0124FCC74','0124F48EE','0130T03E8','0214FE189','0214F3884','0221F46D0','0225T8D18','0226WCF6F',
'0227T05E9','0302MEA0F','0305TC2E8','0305TBA4A','0305T5465','0307S7EB9','0309M5DC4','0310T7939','0320F114D','0320FDFBD','0324T6EAA','0324T2E7A','0327F1E23','0327F6E02','0403FAC5D','0409T36DA','0428T5660','0429W5E4C','0501FED6F','0511M3146','0515FB93D','0519TB921','0526TC78C','0605F6E62','0608M1C0F','0611T2F0B','0615M9897','0615MED39','0618T98F4','0702T7008','0817M1657','0825T2ED8',
'0902W1E78','0904F9305','0917T6CA7','0922T0DAB','0930WDA2B','0930W4CEA','1002F6C31','1005M5446','1008T2E07','1014W23E4','1015TF054','1020T3C79','1023F631C','1030F3B8F','1103T6D52','1104W536B','1105TCE1A','1109MABA1','1113F95C3','1116MBFE4','1118WC638','1125W50FC','1210TCB4F','1211FBC4A','1215T4568','1218F0E61','1222TD742','1223W64B6','1224TDFD2','0403FE6F3','1219T8C30','1219T4439',
'1204W9E10','1224TD204','1228MA9FA','1228M8C04','1228MBF2B','1228M4ECE','1228M46D0','1228M7BD6','1229TE49F','1229T2E7F','1228M7145','1228M3E49','1228M4EB5','1228M9ADD','1230W9002','1230W97B2','1228MD850','1228MD13A','1230W258D','1230W9AA3','1230WF4D6','1230W57BB','1230W1945','1229T935B','1231TB6FF','1221ME178','1229T8004','1229TFC9E','1229TCCF0','1228MD2AC','1229TBCDE','1229TD929',
'1231TDC70','1229TD7AD','1228MA338','1217T92C5','1230W916B','1229T09F0','1231TEEE8','0108W68D7','0630TC1F7','0122W2795','0515F0339','0812W18FE','0901TF460','0817MD82F','0805W9747','0619F467A','0518MAC96','0228F3405','0713M1A6A','0413M69B4','0306F2956','0221F42B4','1022TA059','0205W2EA1','0123T6019','0128T3756','0205WF1FA','0204TDFFA','0213TB6E2','0107TE8CD','0420MD0E7','1105T7AC5',
'0910T9B9F','0228FAD91','0615MD526','0624WDE7D','1218F4077','0106M33CA','0108W82D6','0114TF9BF','0213T5AC6','0225T948A','0218T7ED9','0318W0847','0408WBEE6','0420MD579','0521TB03A','0701WBCF6','0619F8E23','0617WA54F','1207M90F4','0803MCD08','0407TE312','0103F184F','0110FCAE5','0113MB5FE','0108W3616','0114T66F4','0114T8814','0114T8E19','0115W86FF','0116TA619','0122WA328','0118S8A3E',
'0129WFDD6','0123T3F73','0130T761D','0127M44E7','0131F0ADE','0205WD728','0206TD7EF','0227TFF56','0226W6467','0210M6CBC','0320F2314','0313F936A','0330MAEAE','0325W467F','0417F207D','0311WF779','0413M87A4','0116TC7BA','0214F7BCA','0423TC1A3','0318W0A05','0401WEAD0','1218F2958','1119T5052','1103TC0FB','0414T2BDC','0402T7837','0305TC41D','1101SA0A7','1022T09B6','1013TB42C','0728TF936',
'0330M43EF','1207MC773','1124T882E','1119T9002','1029T6A91','1104WD2DC','1023FC65D','1013TF07A','0908T1B5D','0103F2873','0103F38B4','0103F0A9A','0102T5C38','0103F6F9F','0103F00B7','0106MD986','0108W9ADD','0109T733C','0108WDE42','0109T93F6','0109TF2D8','0113M6B12','0108W452A','0113M04B0','0116T072F','0117F1F16','0117F2767','0117FD25B','0113M596B','0113M56A9','0115W1FB6','0115W35B8',
'0120M6878','0121TD211','0123T5A44','0117F5105','0117F5C83','0117FDFF7','0117FE1FD','0121T9250','0118S3C30','0121T6443','0124F4199','0127M3712','0125S5701','0129W1FC4','0127M30D1','0128T012E','0123T137C','0121T40F7','0122WC00F','0123TF6CD','0127MB910','0127MB3E8','0128TA9FB','0204T9666','0131F7B56','0128T0736','0128T77F0','0129WF8DD','0204T4994','0204TE8AD','0205W0827','0127M30B9',
'0207FA413','0207FFE5B','0206T019B','0205W8B8E','0207F63CD','0205W410D','0205WCC46','0206TA1D4','0220T7944','0212WB7B8','0217MBF25','0220TE390','0213TA53A','0225T91EB','0219WF906','0222SD3D8','0223SB1AA','0224M97FE','0205W2EA1','0227T40E6','0305TF72B','0226W9939','0303TF750','0305T0526','0210MEB9F','0228F0B6D','0229S0E9D','0318W7262','0304W0FAA','0304WB9F9','0305T6DA9','0306FA5C3',
'0320FD777','0318W9A2B','0325WE99C','0331T498D','0402TC12C','0403F2465','0313F269E','0312T83C3','0313F2E67','0330MBF32','0408WA2BF','0413ME4F8','0402T3DC3','0316M00B9','0317T2F20','0420M8089','0331TBC52','0423TCC4A','0415W4698','0415WF9D4','0417F70BF','0327F57E9','0325W7433','0326TE250','0326T69E0','0327F7CB7','0420M5417','0408W946B','0314SA095','0403F38BF','0403FCE37','0316MF9ED',
'0317TA935','0401W5A58','0414T5EB5','0416T874B','0407T7D3A','0423TEFE4','0420M3349','0421TAFF2','0422WA38D','0417FB6CA','0409TDF64','0425SF2A2','0417FCA78','0417FE0F1','0414T00DF','0416T4476','0417F1B2A','0519T0254','0513W9781','0514T9FDC','0428T6366','0413MA096','0507TF65B','0508F28B9','0423TB9F6','0423TEC95','0423TFECB','0427MD4AD','0428TCD00','0422WD03A','0423T20D4','0401WDA5A',
'0506WDFB4','0508F6B3A','0515F1AC0','0511MA2CE','0508F2259','0508FDD46','0424F9EB6','0429W53B6','0416T976D','0528T7D90','0427MD7DA','0518ME909','0519TEA75','0501FBE3F','0507TE8A0','0602TC946','0514T3C36','0520WB3D2','0521TAC7E','0109T4317','0527W1AF6','0616TD887','0610WE086','0527WF7FD','0513W0E71','0514T8456','0520W40AF','0522F3170','0528T1012','0529F2585','0601MBFCF','0522FAFEC',
'0525MCC8A','0527W2026','0529F6719','0518M0BC6','0623T6D31','0602T9148','0605F3C76','0605F9E07','0612FC375','0529F6234','0612F0F4E','0615M90C2','0616T3785','0708W2AE1','0630TAAE0','0707T4598','0625T64CE','0710F53DE','0622M4653','0605F29BF','0616T39EF','0625T2C3C','0713MC962','0701W14C8','0706MD156','0720M60A2','0615M1D3B','0616T83AC','0618T684D','0618T9AE6','0624W36BB','0624W7FBF',
'0703F7F90','0703FE58E','0723TD2B9','0723TFE39','0707T3CA5','0707TFA00','0706M4F88','0622MCBDC','0709T4798','0709T7EFD','0713MD174','0716T6711','0721T0403','0706MAD60','0721T84DB','0120MA953','0122W3ECC','0122WA424','0204TD5B6','0226W5A6C','0306F478B','0721T2AEE','0114T04EB','0117FEC4B','0121T1F0C','0122WF3DE','0214F00A0','0330MFE77','0423T296A','0504MD658','0227T9EAF','0310T5DB4',
'0409T461C','0512T58D3','0513W07A1','0519T41A6','0612F8F7B','0618T9107','0702TBF77','0428T301A','0506WE98D','0514TB827','0515F8AB5','0527W1FE3','0602T0625','0603W9C40','0608M9B6E','0723TF41C','0805W594F','0810M2B00','0810M5899','0810M785F','0811T4E9B','0623T544E','0630TF17B','0828F21F5','0929TB442','1002F6FBA','1002FABFF','1007WC75D','1007WCE40','1008TF209','0804T72DA','0807FE38E',
'0812W7D9B','0813T77EA','0813T9368','0909WB040','1015T36C0','1015T7192','1021W548F','1027TBDF8','1110TE844','1111W8BF6','0924TAB3C','1001T5A13','1005MBCD6','1006T333B','1016FAA83','1102M0F72','1102M2A1C','1110T19B3','1112TE47B','1224T2C13','1230W28C5','1123M7D00','1202W9B03','1211FA30F','1218FA8ED','0828FB96C','1005M4DD9','1005M99D9','1006T0EC2','1006T175B','1006T2A55','1006T35AC',
'1006T6CD4','1006T8DEE','0805WAD6D','0807F9A80','0826W8341','0902WE430','1009F7E0E','1012M4080','1012MCE0C','1016F4CD1','1111W746A','1116M26AF','1120FF149','0929T5C92','1002F5A59','1002FF477','1002FF809','1006TB583','1006TE655','1006TEC07','1007W2EB5','1007WD2C0','1007WE0FF','1008T069E','1008T3944','1013T54BA','1015T7B2E','1021WB897','1026M392C','0727MD763','1102M33D4','1202W00A2',
'1202W96A1','1221MB85F','0807F3AE0','0817MF673','0910T235D','0730T9F02','0811TCF79','0930WC8F0','0930WF52B','1001T4CC1','1006TD530','1007W6A7F','1007WAB32','1013T6A8E','1016FDA26','1017S0B99','1017SC2A9','1023F93AD','1026M68AD','1026MAB0C','1030F634A','0904FFFD1','0909W73D9','1005M8CD1','1006T2732','1006T2CD9','1008T6C04','1008TD99A','1012M3150','1012M4D3F','1012M5973','1111WAD3F',
'1116M21A8','1208TE2E0','0728T0EBA','1027T48C1','1027T7CAA','1027TE559','1127F02B2','1207M0C1C','1208T1DE6','0819W8291','0820T8DD2','0914MFF4D','1217TE0EA','0723T9249','0723TA1C1','0730T2A99','0803MF425','0805WF23F','0819W4418','0922T0CB5','0922T223D','1002F1500','1002F6770','1002F9C43','1020T0A6B','1021W2E20','1021W421F','1027T4586','1027TF7E7','1031S4402','1105T3D11','1105TBBCB',
'1112T238E','1125W49A1','1208TD1AA','1209W0AC9','1013T7171','1016F5481','1017SD230','1021WD46A','1022TF406','1109MFE54','1114SD130','1117T92D4','0723T1FD0','0723T3CCD','0723T542C','0729WE931','0810MF3AB','1123MEC5D','1124TA5EA','1201T7DE1','0924T6B3F','1001T32C5','1001T430D','1001T5AEC','1001T63EF','1001TD3A6','1006T258C','1007W3CC0','1009F942B','1012M4733','1013T115A','1013T73B1',
'0803M2753','0819WE608','0915T1846','0922T3A89','1015TBE8D','1017S1D97','1029TDA99','1002F35A8','1002F70F1','1002FBBA3','1003SA5EE','1004SBB8F','1005M01EB','1007WCF79','1007WFB14','1020T906D','1027T5A7B','1027TCFE2','1109M4187','1109M471D','1205S077E','0803MA53B','0804TD12D','0805W0C7D','0808SA09E','0817M1F0D','1124TCE56','1218F24BF','1221MBC05','0817M91E6','0820TBD54','0824M4EA0',
'0903T82EB','0903TC796','0915T09FB','0915TEFB6','0925F0229','0730T2795','0730TB309','0805WECD7','0806T2113','0831MEC9F','1005M47A3','1007W3984','1007W8D80','1013TE4A0','1018S4ECF','1022T6A73','1110T955F','0927S0BFB','1002F5620','1002FBD72','1004S0928','1007W9A9C','1015T0D91','1020TA2A2','1021W6E99','1021W9763','0723T3644','1030FD36A','1112T33FA','1118W077E','1124T807A','0806T2D72',
'0808S4059','0819WC002','0820TCB18','0715W0507','0722W2116','0729W3523','0805W96E8','0922T0256','0929T7410','1007W2E23','1008T1168','1021W946C','1027T9A24','1027TE7EC','1027TFF5F','0918F7E73','0918FD1EB','1005M9591','1006T6BA9','1006T7DD8','1007W0233','1030FB30A','1102M5AF6','1105TB407','1106F6BED','1112T9635','1118W4853','1201T0A91','1012M32A4','1013T69B5','1020T0315','1020T3274',
'1119T6898','1120F0C0E','1224T8B22','0811T1482','0811T1C63','0811T4858','0811T92DD','0819W83E0','1204FAC53','1208T9B39','0724F13F8','0904F215D','0921MF057','0925F3A7A','0930WE787','1001T5B69','1007WBE25','1008TD6E6','1013TA6DD','1013TB74A','0826W853A','0918FFB5D','1019MBB79','1020T59D7','1020T7946','1030F5AF7','1109M0BD0','1109M0D19','1119TE3B5','1124T7162','1005M9265','1006T6AC8',
'1006TE8B5','1007W6D8D','1021WB2DA','1024S3D5C','1109MC946','1218F0FF2','1118W506C','1122SBB4D','1127F43FD','1207M7E75','1208T3BEC','0710FEF26','1207MC2E0','0908T3EB1','0922T94B5','0210MAB25','0819W9986','0819W426F','1127F0F6F','0210M5928','0207FF735','0429W9089','0407TF698','0330M8AB5','0930W4CC6','0810MC6B3','1030FF9D1','0714TC87C','0707T5E10','1130M0B39','1211F5FE4','1002FA2B9',
'1027TFF63','0817M3BFD','1008T8699','0726S549A','0103F7D3C','0106M7BEB','0113MFC90','0117F5E6E','0122W5060','0124F5C7A','0124FFAD7','0129WAAB3','0129WE086','0130T2739','0203MC7B7','0206T0639','0211T70B2','0214FD395','0228FAFBE','0304W564C','0305T2336','0305TE514','0309M9F52','0311W1D54','0312T2DBD','0314S16D6','0316M42DB','0318WC80A','0320F9480','0417F636F','0417F9E27','0421T49A5',
'0424F89A2','0425S247D','0430T0602','0430T9F8A','0504M030F','0507T500A','0511M0907','0513W097E','0527W51F9','0604T242A','0608M7629','0609TE1D7','0612F77C5','0625TE8C6','0702T5593','0706M060D','0708W7BA2','0714T2A71','0714T3D33','0716T3B21','0716T53EF','0717F7496','0717FC4D1','0720M572B','0721T92D0','0724F6EF4','0731F8784','0731F8A61','0804T7417','0804T8341','0806TD3B1','0812WAFC2',
'0825T48F8','0825TD4B7','0828F4651','0831M238A','0901T605E','0902W9062','0902WFA31','0904F6BA9','0904F8107','0908TE04E','0915TBA2E','0915TC136','0916W14A4','0916W4796','0918F7FE6','0921M492C','0921MECF4','0928M0D8F','0928MF006','0930WB8E7','1001TC4CC','1002F58BF','1008TFAB7','1009F034F','1014W7CC8','1020TC211','1028WAF4C','1029TF51B','1102MA871','1106F3EEA','1116M8DCC','1118W4068',
'1118W7558','1119T5E05','1120FFBD6','1130MB211','1201TE5A2','1209W2A0C','1209WA99B','1209WFA92','1222T83B6','1111WAC9C','1020TCFAE','0917TA41D','0917T6633','0904F6779','0819W495B','0731FC3F3','0717F6D5F','0702T81F1','0428T142B','0213T0D71','0206T8CA2','0128T0CAC','0122WC994','0113M389C','0103F3F9C','1202WC73F','0929TC111','0910T21A6','0909W8A1D','1224T90AE','0702TF21D','1204F3E9A',
'0107T00A9','0102TFE33','0102T84E2','0316M262A','0101WB2BA','0101W1B2D','0827T2C16','0902W8805','0909WE7FB','1208T3313','1117T5775','0226WF65B','0717F6EEE','0727M0F54','0123T2404','0226WE313','0429WDA85','0229S1732','1130M2739','0812WD4EF','0730T8D1A','0410FCE83','0430TB965','1224T16F9','0130T62FA','1125W22BA','1111W7E79','0826WCAD0','0320F71E1','0317TFE39','0827TECA6','1113F1511',
'0731F5267','0805W7BAB','0904F5717','0402T63A9','0910T203A','1015T91BD','0102T1C4D','0709T09E6','0520W4E9E','0506W2A78','0107TD61D','0511M7BAF','0625TE1EC','1007WC1B0','0619FBB54','0210M3984','0309MBF83','1127F551A','0819W17CA','0430T3389','0327FAF61','0304WC6D2','1009F1C51','0811TAA16','0925FF5F6','0302M40A2','1113F050B','1005M3F3C','0820T23FF','0127MA8C6','0925F22AF','0526TD2FF',
'1120FC03B','1026MC15A','0413M2EB0','1214MB28A','0511M0FE4','0216S76C9','0121TEB73','0210M747A','1109MDE95','0224MFF17','0415WFA28','0508FC877','0615M10A5','1029T2626','0413MD652','0617W9B09','1102M4C61','0518ME1B2','1228MC78F','0429WFA6B','0522FD3B6','1029TBBBD','0331TD07C','0909W6AD3','0908TB74A','1013T8F2F','0428TAD44','0323MA022','0423T85FE','0713MDE81','0824M7E08','0323M096A',
'1101S48E1','0508F9512','0421TB232','0422W7A8E','1120FD0B3','0414T20B8','0831M1853','0413M9E40','0316MF3AF','0429WA24B','0629M218C','1101S7552','0928M605D','1104W9123','0423TCE95','0406M8615','0318WDF52','0908TAB62','0103FB2D9','0406MBF97','0504M74F8','0421T4ECD','0414TCD34','0413M7A28','0908T9ABD','0124F25D2','0421T072F','0424F5A7C','0526TDDB9','0330MB07E','0521T54D8','0831MA4D6',
'0312T41D5','1117T395B','0221FAD48','0717W65E4','0512T121E','0609TC08E','0219WA689','0221F02C1','0423TE0A6','0306F16F1','0513W0C77','0513W821F','0504MDEB4','0507T264E','0910T04B5','0707T252D','1016F8305','0903T26C1','0910TE1C2','0626FADE8','1118WAD69','0303TF204','0205W3705','1104WAEDB','1001T18EE','0122WEC33','0424F543B','1105T613D','0603WE70E','0107T5EB4','1006T1007','1215T7AEC',
'1204F1488','0922T7898','0413M9F9E','0420MB918','0727M24C1','0806T13AB','0731FE368','1201T0CE3','1118W1C43','1016F9C28','0824MC420','1014W932E','0907M65E6','1211F6342','0420M2571','0918F07B6','0603W053C','1009FBAA4','0228F0259','0603W8331','0304W31EC','1027T4DD2','1021W2E75','0428TF85D','0316M2E58','1013T57CB','0915TBC36','0124FC76C','1012MC372','0225TD6D4','0225T03E2','0318W2709',
'0501FC10A','0720M0877','0719SAB42','0818T1409','0210MA00D','0228FEF6A','0214FA9BB','0629M3035','1106F525E','0319T02BB','0205W4AC0','0219W4F52','1006T86CF','0327F52D4','0427MBE8F','0729W80C2','0406MFE53','0118S01F4','0127M3B32','0118S88C2','0110FAD7C','0527WCFB9','0721T5BF9','0118S4581','0210M0902','1006T23CC','0403F3AC1','0706M4885','0826WC1AA','0729WE77F','0326T7A3C','0527WEA2E',
'0812WB123','1020TA538','1105TFBC3','0506WEADA','0422WD335','0811TC96E','1113F3394','0601M0316','0811TC30A','1030F8BEB','0402TB18C','0717F9E13','0716T0E85','0716TEB35','0716T00EE','0716T59C9','0117F9944','0304W319C','0619FF796','0923WFC27','1030F2345','1002F4ED6','0410F16D4','0803M3265','0925F9BD6','0929T488E','0909W023B','0103F79C9','0828F0D66')
--
commit tran

begin tran
update #final_auth
set [Type (Who Made the Request-1=CP,2=NCP)] = 1
where case_id in ('0910T6AD2','0323M73B5','0306FF3D8','0212W16E7','0327F2C5B','0103F447C','0226W6B7C','0323M309A','0228F96DA','0430TE19A','0326TBB1C','0427M6C68','0628S2E5B','0916W83E7','1125W54A2')
--
commit tran


--- remove auths that has appeal as note type
begin tran
delete from #final_auth
where auth_no in 
(
	select note_ref_id
	from #notes_2
	where appeal_flag is not null
)
--
commit tran

-- select count(*) from #final_auth

-- check auth with same member, same receipt date and same service
--select *
--from
--(
--	select distinct member_id, receipt_date, [Service Code(s)], count(*) as total
--	from #final_auth
--	group by member_id, receipt_date, [Service Code(s)]
--	having count(*) > 1
--) a
--join #final_auth fa
--on a.member_id = fa.member_id and a.receipt_date = fa.receipt_date and a.[Service Code(s)] = fa.[Service Code(s)]
--order by 1,2

--select * from #final_auth where latest3notes like '%pend%claims%'

-- select * from #final_auth where case_id = '0907MD1F3'


-- select * into medical_analytics.dbo.odr_auth_2020 from #final_auth 
-- drop table medical_analytics.dbo.jason_odr
-- select * from medical_analytics.dbo.jason_odr

--select distinct case_id, count(*)
--from #final_auth
--group by case_id
--having count(*) > 1




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




--select contract_no, count(case_id) as auths,  Decision_ID 
--,case when [Type (Who Made the Request-1=CP,2=NCP)] = 1 and decision_id = 1 then 'Fully Favorable (Services) Requested by enrollee/representative or provider on behalf of the enrollee'
--when [Type (Who Made the Request-1=CP,2=NCP)]  = 2 and decision_id = 1 then 'Fully Favorable (Services) Requested by Non-contract Provider'
--when [Type (Who Made the Request-1=CP,2=NCP)]  = 1 and decision_id = 2 then 'Partially Favorable (Services) Requested by enrollee/representative or provider on behalf of the enrollee'
--when [Type (Who Made the Request-1=CP,2=NCP)]  = 2 and decision_id = 2 then 'Partially Favorable (Services) Requested by Non-contract Provider'
--when [Type (Who Made the Request-1=CP,2=NCP)]  = 1 and decision_id = 3 then 'Adverse (Services) Requested by enrollee/representative or provider on behalf of the enrollee'
--when [Type (Who Made the Request-1=CP,2=NCP)]  = 2 and decision_id = 3 then 'Adverse (Services) Requested by Non-contract Provider'
--when  decision_id = 4 then 'Withdrawn'
--when  decision_id = 5 then 'Dismissals'
--else 'Err' end as Measure
--,[Quarter]
--from #auths2
--group by contract_no, [Type (Who Made the Request-1=CP,2=NCP)] , Decision_ID,Quarter
--Order By ContracT_no,MEasure,[Quarter]




