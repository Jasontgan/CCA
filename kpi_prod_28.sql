--- note: checked source of CMO in GC.  It does not appear to have history, i.e. if member changes, there is no way to roll back to the effective CMO.
--- same for plan_name.  

select 
--auth_id
--, 
cs.member_id
, cs.first_name
, cs.last_name
, r.role_name
--, care_staff_dept_id
, d.dept_name
, csd.is_work_queue
--, d.is_work_queue 
, title
into #carestaff

from [Altruista].[dbo].[CARE_STAFF_DETAILS] cs
left join [Altruista].[dbo].[CARE_STAFF_DEPARTMENT] csd on cs.member_id=csd.care_staff_id and csd.deleted_on is null
left join [Altruista].[dbo].[DEPARTMENT] d on csd.dept_id=d.dept_id and d.deleted_on is null
left join [Altruista].[dbo].[ROLE] r on  cs.ROLE_ID=r.ROLE_ID and r.deleted_on is null
--where cs.deleted_on is null
group by
cs.member_id
, cs.first_name
, cs.last_name
, r.role_name
--, care_staff_dept_id
, d.dept_name
, csd.is_work_queue
--, d.is_work_queue 
, title
order by cs.member_id

-- select * from #carestaff where member_id = 9016

select
member_id
, first_name
, last_name
, role_name
	, STUFF((
					SELECT ', ' + CAST(dept_name AS VARCHAR(MAX))
					FROM #carestaff AS s
					WHERE s.[member_id] = cs.[member_id]
					GROUP BY
						s.[dept_name]
					for xml path(''),type).value('(./text())[1]','VARCHAR(MAX)'),1,1,'') as [Department Name(s)]

		
		into #carestaffgroup
		from #carestaff cs

		group by
	member_id
, first_name
, last_name
, role_name

-- drop table #step

select distinct pd.[LAST_NAME],
	   pd.[FIRST_NAME],
	   pd.[CLIENT_patient_ID] as CCAID,
	   --bp.plan_name,
	   IIF(lb.PARENT_LOB_BEN_ID IS NULL,'UD', l.BUSINESS_DATA_NAME) AS 'PLAN_NAME',
	   a.[AUTH_ID],
	   a.created_on,
	   stat.auth_status,
	   a.AUTH_NOTI_DATE as Received_date, 
	   --convert(varchar, a.AUTH_NOTI_DATE, 108) as 'Time the request was received',
	   ud.[SERVICE_FROM_DATE] AS [SERVICE_FROM_DATE], 
	   ud.[SERVICE_TO_DATE] AS [SERVICE_TO_DATE],
	   coalesce ( s.SERVICE_CODE, sv.proc_code)  as proc_code,
	   coalesce (sp.service_category_label, svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION) as proc_description,
	   auth_priority,
	   case 
			when a.IS_EXTENsion = 1 then 'Yes'
			else 'No' 
	   end as 'IS_Extension',
	   decs.decision_Status
 --,[DECISION_STATUS_CODE_DESC]
	,case when  sv.proc_code in ('0191','0120','0192','0193') or s.service_code in ('0191','0120','0192','0193') 

or (ar.mindecision in ('Approved', 'Trans Approved') and dec_count=1)---when an auth has all approved lines, Amelia L said to use the decision date on decision tab instead of MD Review date

then  ud.replied_date 
when act.[MD review Completed date] is not null then act.[MD review Completed date]
-----On November 27, 2018 Amelia Levy said to use the MD review completed date as the decision date for denials
else  ud.replied_date end  as Decision_Date
	,case when decs.decision_status in ('denied', 'partially approved')  and ud.MEMBER_NOTIFICATION_DATE is not null AND ud.MEMBER_NOTIFICATION_TYPE_ID=4  then --specified to only pick up phone, not written
	convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
	when  cast (ud.MEMBER_NOTIFICATION_DATE as date) >= '2019-03-18'---date when UM STARTED CALLING 
	AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
	else ' ' END as 'Verbal Notification' 
--, MaxLetterCreatedDate
--**	,case 
--**			when decs.decision_status='approved' 
--**					then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
--**
--**
--**			when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
--**			and dendoc.[letter date] >= '2020-03-26' and act.[MD review Completed date] >= '2020-03-26' --when letterdate and descision date both > 3/26, use the PrintAndMailTime from [CCARemoteMailing]
--**					then min(ac.PrintAndMailTime)--convert(varchar, ac.PrintAndMailTime , 111) + ' 16:00:00'
--**
--**			when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
--**			and dendoc.[letter date] < '2020-03-26' -- when letter date is less than 3/26, then use the old logic from the table
--**					then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
--**
--**			when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') ) 
--**			and dendoc.[letter date] >= '2020-03-26' and act.[MD review Completed date] < '2020-03-26' and dendoc.[letter date] < ac.PrintAndMailTime
--**					then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00' -- when letter date and > 3/26 but the decision date < 3/26, compare letterdate and the PrintAndMailTime from [CCARemoteMailing], use the earliest
--**			when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
--**			and dendoc.[letter date] >= '2020-03-26' and act.[MD review Completed date] < '2020-03-26' and dendoc.[letter date] >= ac.PrintAndMailTime
--**					then min(ac.PrintAndMailTime) -- when letter date and > 3/26 but the decision date < 3/26, compare letterdate and the PrintAndMailTime from [CCARemoteMailing], use the earliest
--**
--**			
--**
--**			when decs.decision_status='partially approved'  and dendoc.created_on is not null 
--**					then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
--**			when decs.decision_status='partially approved' 
--**					then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
--**			else convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
--**	end as WrittenNotifDate,
	,case 
			when decs.decision_status='approved' 
					then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 16:00:00'--' 19:00:00'
			when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
					then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
			when decs.decision_status='partially approved'  and dendoc.created_on is not null 
					then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
			when decs.decision_status='partially approved'  and dendoc.created_on is null 
					then ''
			--when decs.decision_status='partially approved' 
			--		then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 16:00:00'--' 19:00:00'
			else convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 16:00:00'--' 19:00:00'
	end as WrittenNotifDate,
	auth_type_name,
	--ac.PrintAndMailTime, act.[MD review Completed date],
--, pdv.LAST_NAME + CASE WHEN pdv.FIRST_NAME IS NOT NULL THEN ', ' + pdv.FIRST_NAME ELSE '' END CMO

	DECISION_STATUS_CODE_DESC,
	a.auth_no
	, CAST (UD.created_on AS DATE) 'DecisionCreatedDate'
	,case when (sv.proc_code between '0100'and '0119' and len(rtrim(ltrim(sv.proc_code)))=4 )  ---length of 4 was added as there were some anethesia codes getting excluded that should not be excluded
or ( sv.proc_code between '0121'and '0190' and len(rtrim(ltrim(sv.proc_code)))=4)
or ( sv.proc_code between '0193'and '0219' and len(rtrim(ltrim(sv.proc_code)))=4)
or ( s.SERVICE_CODE  between '0100'and '0119' and len(rtrim(ltrim(s.SERVICE_CODE)))=4)
or ( s.SERVICE_CODE between '0121'and '0190' and len(rtrim(ltrim(s.SERVICE_CODE)))=4)
or ( s.SERVICE_CODE  between '0193'and '0219' and len(rtrim(ltrim(s.SERVICE_CODE)))=4 ) 
or  s.SERVICE_CODE  in ('99218','t1013')  or  sv.proc_code in ('99218','t1013')
then 'Exclude' end as 'Exclusion' 
, place_of_service_code as POS
	,  cso.LAST_NAME + ',' + cs.First_NAME as [Auth owner]
, cso.role_name as [Auth Owner Role]
, cso.[department name(s)] as [Auth Owner Department(s)]
    ,  authcr.LAST_NAME + ',' + authcr.First_NAME as [AuthCreatedBy]
		,pdv.last_name as AuthCMO
into #STEP
--select * from #step
from  [Altruista].[dbo].um_auth a
--left join 
--(
--	select * from [PartnerExchange].[auths].[CCARemoteMailing] 
--	where filename not like '%extension%'
--)ac
--on ac.filename like '%' + a.auth_id + '%' 
left join  [Altruista].[dbo].[patient_details] pd on a.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
--left join [Altruista].[dbo].[lob_benf_plan] lb on a.[LOB_BEN_ID] = lb.lob_ben_id and lb.deleted_on is null
--left join  [Altruista].[dbo].[lob] l on lb.[LOB_ID] = l.lob_id and l.deleted_on is null
--left join [Altruista].[dbo].benefit_plan b on l.benefit_plan_id = b.benefit_plan_id
left join [Altruista].[dbo].CMN_MA_BUSINESS_HIERARCHY lb on a.[LOB_BEN_ID] = lb.lob_ben_id and lb.deleted_on is null
LEFT JOIN [Altruista].dbo.CMN_MA_BUSINESS_DATA AS l ON lb.BUSINESS_DATA_ID = l.BUSINESS_DATA_ID AND l.DELETED_ON IS NULL

left join  [Altruista].[dbo].um_auth_provider  prov on a.auth_no = prov.auth_no  and prov.provider_type_id = 3 and prov.deleted_on is null-- 3 means referred to-- needs another join
left join  [Altruista].[dbo].um_auth_provider  byprov on a.auth_no = byprov.auth_no  and byprov.provider_type_id = 2 and byprov.deleted_on is null-- 2 means referred by-- needs another join
--left join [Altruista].[dbo].[PROVIDER_NETWORK] pn on pn.[PROVIDER_ID] = prov.auth_no
left join  [Altruista].[dbo].um_auth_code Pac on  a.auth_no  = Pac.auth_no and AUTH_CODE_TYPE_ID in ( 1,5) and pac.deleted_on is null-- splits the auth into auth lines
left join  [Altruista].[dbo].UM_DECISION ud on  a.auth_no  = ud.auth_no and Pac.auth_code_id = ud.auth_code_id and ud.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS decs on ud.DECISION_status = decs.DECISION_STATUS_ID and decs.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS_codes decstc on ud.DECISION_status_code_id = decstc.DECISION_STATUS_code_ID and decstc.deleted_on is null
--LEFT JOIN [Altruista].[dbo].[benefit_plan] bp ON lb.[BENEFIT_PLAN_ID] = bp.[BENEFIT_PLAN_ID] and bp.deleted_on is null
left join  [Altruista].[dbo].UM_MA_AUTH_TAT_PRIORITY tat on a.auth_priority_id = tat.auth_priority_id and tat.deleted_on is null
--left join [Altruista].[dbo].UM_DOCUMENT doc on a.auth_no = doc.DOCUMENT_REF_ID --and doc.document_name in ('
left join[Altruista].[dbo].UM_MA_CANCEL_VOID_REASON cv on a.CANCEL_VOID_REASON_ID = cv.CANCEL_VOID_REASON_ID and cv.deleted_on is null--and doc.document_name in ('
left join [Altruista].[dbo].UM_AUTH_PLACE_OF_SERVICe ap on a.auth_no = ap.AUTH_NO and ap.deleted_on is null
left join [Altruista].[dbo].UM_MA_PLACE_OF_SERVICE pos on ap.PLACE_OF_SERVICE_ID = pos.PLACE_OF_SERVICE_ID and pos.deleted_on is null
left join [Altruista].[dbo].[UM_MA_AUTH_TYPE] at on a.AUTH_TYPE_ID = at.AUTH_TYPE_ID  and at.deleted_on is null
LEFT JOIN 
(
	select   c.document_ref_id, c.letter_printed_date, c.created_on, d.created_by,  cs.last_name+ ',' + cs.first_name as createdbyname ---these multiple steps below are done to get the lastest create date and created by associated withthe latest printed on date 
	from
		  ( 
			  select a.document_ref_id, max(b.letter_printed_date) as letter_printed_date, a.created_on
			  from
				(
					select document_ref_id, max(created_on) as created_on from Altruista.dbo.um_document  
					where DELETED_ON is null  
					and (DOCUMENT_NAME like ('%H0137%approval%') or DOCUMENT_NAME like ('%H2225%approval%'))
					and document_type_id in (2, 4)
					--and LETTER_PRINTED_DATE is not null
					group by document_ref_id
				)a
			  inner join  Altruista.dbo.um_document b 
			  on a.document_ref_id=b.document_ref_id and b.deleted_on is null and cast(a.created_on as date)=cast(b.created_on as date)
			  group by  a.document_ref_id, a.created_on
		 )c
	inner join  Altruista.dbo.um_document d 
	on c.document_ref_id=d.document_ref_id and d.deleted_on is null and c.created_on=d.created_on
	left join  [Altruista].[dbo].[CARE_STAFF_DETAILS] cs 
	on d.created_by=cs.member_id
	--where c.document_ref_id='259701'
	group by  c.document_ref_id, c.letter_printed_date, c.created_on, d.created_by,  cs.last_name+ ',' + cs.first_name

) approvdoc on a.auth_no=approvdoc.document_ref_id 
LEFT JOIN 
(
	select  a.document_ref_id, a.[letter date], b.created_on, b.created_by, cs.last_name+ ',' + cs.first_name as createdbyname, letter_printed_date as printedon
	from
	(
		select document_ref_id
		--, max(created_on) as 'created_on' 
		--, cast (created_on as time)  as 'Time'
		, case when cast (min(created_on) as time) < '16:00:00'
		then  min(created_on)  else  dateadd (dd,1,min(created_on) ) 
		end as 'Letter Date'
		,  min(created_on) as maxcreatedon
		from Altruista.dbo.um_document
		where --((document_name like '%denial%' and  document_type_id in (2)) or  document_type_id=6)
		document_name like '%denial%' and document_type_id in (2, 6)
		and DELETED_ON is null
		--and document_ref_id= '34733'
		group by document_ref_id
	)a
	inner join  Altruista.dbo.um_document b on a.document_ref_id=b.document_ref_id and b.deleted_on is null and a. maxcreatedon=b.created_on
	left join  [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on b.created_by=cs.member_id
	group by   a.document_ref_id, a.[letter date], b.created_on, b.created_by, cs.last_name+ ',' + cs.first_name ,  letter_printed_date
	      
) dendoc on a.auth_no=dendoc.document_ref_id 

left join  [Altruista].[dbo].UM_MA_PROCEDURE_CODES sv on Pac.auth_code_ref_id = sv.PROC_CODE and sv.PROC_CATEGORY_ID in (1,2, 3,7) and sv.deleted_on is null -- hcpcs, cpt, revcode or ICD10Proc

-- now join again to the sercice code table to get the items that are not being coded correctly as ProcCode

left join [Altruista].[dbo].[SERVICE_CODE] s on pac.[AUTH_CODE_REF_ID]=cast (s.SERVICE_ID as varchar) and pac.[AUTH_CODE_type_ID]=5 and s.deleted_on is null
left join  [Altruista].[dbo].um_ma_procedure_codes svc on  s.service_code = svc.proc_code  and svc.deleted_on is null-- hcpcs, cpt, revcode or ICD10Proc---this is to hget the description for the special service category codes
--left join [Altruista].[dbo].UM_MA_PROCEDURE_CODES sv2 on Pac.auth_code_ref_id = sv2.PROC_CODE and sv2.PROC_CATEGORY_ID in (1,2, 3,7) -- hcpcs, cpt, revcode or ICD10Proc
left join [Altruista].[dbo].[UM_MA_AUTH_STATUS] stat on a.AUTH_STATUS_ID = stat.AUTH_STATUS_ID and stat.deleted_on is null
left join [Altruista].[dbo].[LANGUAGE] lan on pd.PRIMARY_LANGUAGE_ID = lan.language_id and lan.deleted_on is null
left join [Altruista].[dbo].[UM_MA_AUTH_STATUS_reason] usr on a.[AUTH_STATUS_reason_ID]=usr.[AUTH_STATUS_reason_ID] and usr.deleted_on is null
left JOIN [Altruista].dbo.PATIENT_PHYSICIAN pp ON pd.PATIENT_ID = pp.PATIENT_ID AND  CARE_TEAM_ID IN (1,2) AND pp.PROVIDER_TYPE_ID = 181 AND -- cmo
CAST(getdate() AS DATE) BETWEEN pp.[START_DATE] and pp.END_DATE and
                    pp.DELETED_ON IS NULL AND
                    pp.IS_ACTIVE = 1
LEFT JOIN [Altruista].dbo.PHYSICIAN_DEMOGRAPHY pdv ON pp.physician_id = pdv.physician_id 
left join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on a.AUTH_CUR_OWNER=cs.member_id
left join [Altruista].[dbo].[SERVICE_plan] sp on pac.[AUTH_CODE_REF_ID]=cast (sp.SERVICE_ID as varchar) and pac.[AUTH_CODE_type_ID]=5 and sp.deleted_on is null
left join (SELECT [ACTIVITY_LOG_REF_ID],
	   max ([activity_log_followup_date]) as 'MD review Completed date'
  FROM  [Altruista].[dbo].[UM_ACTIVITY_LOG] where   [ACTIVITY_type_id]=4 and deleted_on is null group by
  [ACTIVITY_LOG_REF_ID])act on a.auth_no=act.activity_log_ref_id

	   LEFT JOIN (select document_ref_id from Altruista.dbo.um_document where ((document_name like '%exten%' and document_type_id in (1,2)) or (document_name like '%exten%' and document_type_id =12 and (DOCUMENT_DESC like '%extension letter%')))
	  and deleted_on is null group by document_ref_id  ) extdoc on a.auth_no=extdoc.document_ref_id ---looks for ex

	left join---this is grabbing the notes in the auth table
	(	SELECT  [NOTE_REF_ID]
,isnull([1],'') as Note1,isnull([2],'') as Note2,isnull([3],'') as Note3
		FROM
		(
SELECT 
      [NOTE_REF_ID]
      ,[NOTE_INFO]
   
	  ,  dense_rank () over (partition by  [NOTE_REF_ID] order by CREATED_ON desc) as NOTEORDER---Sorting by Latest note first
	
  FROM [Altruista].[dbo].[UM_NOTE]
  WHERE DELETED_ON IS NULL

  GROUP BY
     [NOTE_REF_ID]
      ,[NOTE_INFO]
    ,  CREATED_ON)p
		pivot
		(max(note_info) for [noteorder] in ([1],[2],[3])--getting last three notes
		)as pvt
		)n on a.auth_no=n.[NOTE_REF_ID]

left join #carestaffgroup cso on a.AUTH_CUR_OWNER=cso.member_id
left join #carestaffgroup authcr on a.CREATED_BY=authcr.member_id
  left join (select auth_id, min(decs.decision_status) as mindecision, count (distinct decs.decision_status) as dec_Count
from 
[Altruista].[dbo].UM_AUTH a
left join  [Altruista].[dbo].UM_AUTH_CODE Pac on  a.auth_no  = Pac.auth_no and AUTH_CODE_TYPE_ID in ( 1,5) and pac.deleted_on is null-- splits the auth into auth lines
left join  [Altruista].[dbo].UM_DECISION ud on  a.auth_no  = ud.auth_no and Pac.auth_code_id = ud.auth_code_id and ud.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS decs on ud.DECISION_status = decs.DECISION_STATUS_ID and decs.deleted_on is null
where (decs.DECISION_STATUS <> 'Void' or decs.decision_status is null)

and a.deleted_on is null 


group by auth_id) ar on a.auth_id=ar.auth_id
where 
--LOB_name = 'Medicare-Medicaid Duals' and 
--pd.last_name not like '%test%'
pd.[CLIENT_patient_ID] like '53%'--picking up ccaids only and not test cases
--and decs.decision_Status in ('approved')
--and auth_priority in ('Prospective Standard','Prospective Expedited')
and auth_status in ('close','closed and adjusted','open','reopen', 'reopen and close')--Sara confirmed these statuses with Amelia on November 29. 2018
--and auth_status not like '%cancel%'
and (decs.DECISION_STATUS <> 'Void' or decs.decision_status is null)
--and a.auth_id = '0127S8116'--'0331TED2F'
and a.deleted_on is null  --  excludes deleted auths
--and doc.MaxLetterDate is null  -- excludes any that already has a letter
--and tat.auth_priority in ('Prospective Standard','Prospective Expedited')
and (not (decstc.DECISION_STATUS_CODE_DESC in ('Suspension of Services', 'Duplicate Request') )or decstc.DECISION_STATUS_CODE_DESC is null)
--and (not (s.SERVICE_CODE in('T2022'))or s.SERVICE_CODE is null)---remove inpatient and other codes that do not require PA per Amelia
--and (not ( sv.proc_code in('T2022'))or  sv.proc_code is null)

group by
pd.[LAST_NAME],
	   pd.[FIRST_NAME],
	   pd.[CLIENT_patient_ID],
	 --bp.plan_name,
	   IIF(lb.PARENT_LOB_BEN_ID IS NULL,'UD', l.BUSINESS_DATA_NAME),
	   a.[AUTH_ID],
	   a.created_on,
	   stat.auth_status,
	   a.AUTH_NOTI_DATE, 
	   coalesce ( s.SERVICE_CODE, sv.proc_code),
	   coalesce (sp.service_category_label, svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION),
	   auth_priority,
	   case 
			when a.IS_EXTENsion = 1 then 'Yes'
			else 'No' 
	   end,
	   decs.decision_Status
 ,case when  sv.proc_code in ('0191','0120','0192','0193') or s.service_code in ('0191','0120','0192','0193') 

or (ar.mindecision in ('Approved', 'Trans Approved') and dec_count=1)---when an auth has all approved lines, Amelia L said to use the decision date on decision tab instead of MD Review date

then  ud.replied_date 
when act.[MD review Completed date] is not null then act.[MD review Completed date]
-----On November 27, 2018 Amelia Levy said to use the MD review completed date as the decision date for denials
else  ud.replied_date end
	 ,case when decs.decision_status in ('denied', 'partially approved')  and ud.MEMBER_NOTIFICATION_DATE is not null AND ud.MEMBER_NOTIFICATION_TYPE_ID=4  then --specified to only pick up phone, not written
convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
when  cast (ud.MEMBER_NOTIFICATION_DATE as date) >= '2019-03-18'---date when UM STARTED CALLING 
   AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
else ' '
END
	--,case 
	--		when decs.decision_status='approved' 
	--				then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
	--		when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
	--		and dendoc.[letter date] < '2020-03-26' -- when letter date is less than 3/26, then use the old logic from the table
	--				then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
	--		when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') ) 
	--		and dendoc.[letter date] >= '2020-03-26' and act.[MD review Completed date] < '2020-03-26' and dendoc.[letter date] < ac.PrintAndMailTime
	--				then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00' -- when letter date and > 3/26 but the decision date < 3/26, compare letterdate and the PrintAndMailTime from [CCARemoteMailing], use the earliest
	--		when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
	--		and dendoc.[letter date] >= '2020-03-26' and act.[MD review Completed date] < '2020-03-26' and dendoc.[letter date] >= ac.PrintAndMailTime
	--				then ac.PrintAndMailTime -- when letter date and > 3/26 but the decision date < 3/26, compare letterdate and the PrintAndMailTime from [CCARemoteMailing], use the earliest
	--		when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
	--		and dendoc.[letter date] >= '2020-03-26' and act.[MD review Completed date] >= '2020-03-26' --when letterdate and descision date both > 3/26, use the PrintAndMailTime from [CCARemoteMailing]
	--				then ac.PrintAndMailTime --convert(varchar, ac.PrintAndMailTime , 111) + ' 16:00:00'
	--		when decs.decision_status='partially approved'  and dendoc.created_on is not null 
	--				then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
	--		when decs.decision_status='partially approved' 
	--				then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
	--		else convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
	--end,
--,decs.decision_status, approvdoc.LETTER_PRINTED_DATE, decstc.DECISION_STATUS_CODE_DESC, dendoc.[letter date], act.[MD review Completed date], --ac.PrintAndMailTime,dendoc.created_on,
	,case 
			when decs.decision_status='approved' 
					then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 16:00:00'--' 19:00:00'
			when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
					then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
			when decs.decision_status='partially approved'  and dendoc.created_on is not null 
					then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
			when decs.decision_status='partially approved'  and dendoc.created_on is null 
					then ''
			--when decs.decision_status='partially approved' 
			--		then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 16:00:00'--' 19:00:00'
			else convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 16:00:00'--' 19:00:00'
	end,
	auth_type_name,
	DECISION_STATUS_CODE_DESC,
	  ud.[SERVICE_FROM_DATE],
	  a.auth_no,
	  	UD.created_on,
		CAST (UD.created_on AS DATE)
		,case when (sv.proc_code between '0100'and '0119' and len(rtrim(ltrim(sv.proc_code)))=4 )  ---length of 4 was added as there were some anethesia codes getting excluded that should not be excluded
or ( sv.proc_code between '0121'and '0190' and len(rtrim(ltrim(sv.proc_code)))=4)
or ( sv.proc_code between '0193'and '0219' and len(rtrim(ltrim(sv.proc_code)))=4)
or ( s.SERVICE_CODE  between '0100'and '0119' and len(rtrim(ltrim(s.SERVICE_CODE)))=4)
or ( s.SERVICE_CODE between '0121'and '0190' and len(rtrim(ltrim(s.SERVICE_CODE)))=4)
or ( s.SERVICE_CODE  between '0193'and '0219' and len(rtrim(ltrim(s.SERVICE_CODE)))=4 ) 
or  s.SERVICE_CODE  in ('99218','t1013')  or  sv.proc_code in ('99218','t1013')
then 'Exclude' end ,
	   ud.[SERVICE_TO_DATE]
	--select * from #step
	,place_of_service_code
	,  cso.LAST_NAME + ',' + cs.First_NAME 
, cso.role_name
, cso.[department name(s)]
    ,  authcr.LAST_NAME + ',' + authcr.First_NAME 
	,pdv.last_name

begin tran
delete from #STEP
where rtrim(ltrim(proc_code)) in ('99284','H0011','S9458','H0010')
--
commit tran

create index idx_auth_id on #step(auth_id);

-- select * from #step where auth_id in ('0319T4AF6','0405F1F8F') order by auth_id

-- cpt code 99284 does not require prior authorization per Kate on 9/21/2020

delete from #step
where proc_code = '99284'
--



	-- select * from #step where auth_id in ('0103FC415','0104S0C29','0104S24F6')

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
	from #step group by auth_id) a 
	where mindecs=maxdecs
	and cast(mindecdate as date)<> cast(maxdecdate as date) and cast(mincreatedate as date)<>cast(maxcreatedate as date)
	--and auth_id='0311MB147'
	) b on s.auth_id=b.auth_id and s.decision_Date=b.mindecdate 
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
	from #step group by auth_id) a 
	where mindecs=maxdecs
	and cast(mindecdate as date)<> cast(maxdecdate as date) and cast(mincreatedate as date)<>cast(maxcreatedate as date)
	--and auth_id='0311MB147'
	) c on s.auth_id=c.auth_id 

	where b.AUTH_ID is not null OR c.auth_id is null


-- select * from #step_a where auth_id in ('0103FC415','0104S0C29','0104S24F6')
	----- TEAM LOGIC IS BELOW \/\/\/\/\/\/\/\/\/\/\/\/\/
-- select * from #step1 where auth_id = '0502TEFC9'

	select s.*
	--, case when b.auth_id is not null then 'yes' else 'no' end as removedlines 
	--, CASE WHEN PA.[TEAM] IS NOT NULL and PA.TEAM IN( 'Procedures','LTSS','Home Health','DME', 'PCA', 'Transportation','TOC', 'No Auth Required', 'BH') THEN PA.TEAM ELSE 'OTHER' END AS 'Category'
	--,case when rtrim(ltrim(pa.code)) IN ('0425','0428','0424','0434','G0176') and s.pos = '12' 
	,case when rtrim(ltrim(pa.code)) IN ('0425','0428','0424','0434','G0176','SS','J2405','S9351','S9370','B4185','B4197','B4220','B4224','B9004','E0776','J1720','S9376','J9100','J2260','S9348','S9331','B4189','S9368','B4193','S9365','J0171','J1200','J1756','S9542','S9339','S9126','S9128') and s.pos = '12' 
	then 'Home Health'
	when rtrim(ltrim(pa.code)) IN ('101','0101') and s.pos = '51'
	then 'BH'
	when rtrim(ltrim(pa.code)) IN ('100','0100') and s.pos = '51'
	then 'BH Admit'
	when rtrim(ltrim(pa.code)) IN ('100','0100') and (s.pos <> '51' or s.pos is null)
	then 'Inpatient'
	when rtrim(ltrim(pa.code)) IN ('120','191','192','193','194','0120','0191','0192','0193','0194') 
	then 'SNF'
	when rtrim(ltrim(pa.code)) IN ('11055','11056','11719','11720','11721','11722','11723','11724','11725','11726','11727','11728','11729','11730','11731','11732','11733','11734','11735','11736','11737','11738','11739','11740','11741','11742',
	'11743','11744','11745','11746','11747','11748','11749','11750','11751','11752','11753','11754','11755','11756','11757','11758','11759','11760','11761','11762','11763','11764','11765','92506','92507','92526',
	'97001','97002','97003','97039','97100','97110','97113','97116','97124','97161','97162','97163','97164','97165','97166','97167','97168','97169','97170','97171','97172','97530','G0127','Q0103') and s.pos = '31'
	then 'TOC'
	when rtrim(ltrim(pa.code)) is null and (LTRIM(RTRIM(S.PROC_CODE)) like 'L%' or LTRIM(RTRIM(S.PROC_CODE)) like 'K%' or LTRIM(RTRIM(S.PROC_CODE)) like 'V%' or LTRIM(RTRIM(S.PROC_CODE)) like 'E%') then 'DME'
	when rtrim(ltrim(pa.code)) is null and (LTRIM(RTRIM(S.PROC_CODE)) not like 'L%' or LTRIM(RTRIM(S.PROC_CODE)) not like 'K%' or LTRIM(RTRIM(S.PROC_CODE)) not like 'V%' or LTRIM(RTRIM(S.PROC_CODE)) not like 'E%')then 'Procedure' -- when the code is not in list, assign to Procedure
	else pa.team 
	end as 'Category'
		, case when s2.auth_id is not null then 'Yes' else 'No' end as 'Adjusted_AdjustedCheck'
	into #step1 
	from #step_a s
	--left join (select auth_id from #step_a  where removedAuth is not null group by auth_id) b on s.auth_id=b.auth_id
	--LEFT JOIN MEDICAL_ANALYTICS.DBO.PACODETEAM2019  PA ON LTRIM(RTRIM(S.PROC_CODE))=LTRIM(RTRIM(PA.CODE))
	left join [Medical_Analytics].[dbo].[PAcode_logic] pa on LTRIM(RTRIM(S.PROC_CODE))=pa.code
	  left join (select distinct auth_id from #step_a where decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%' ) s2 on s.auth_id=s2.auth_id
	--  where s.auth_id = '0502TEFC9'

--select category, *
--from #step1
--where auth_id = '1001TC6AC'

--select category, *
--from #step1_1
--where auth_id = '1001TC6AC'

--drop table #step1_1

--select PROC_CODE, category from #step1 where auth_id = '0718TBE08'
	--where removedauth is null 
	--and exclusion is null---exclude IP per Amelia l.
-- select * from #step1 where category is null
select s.auth_id
into #T2003
from
(
	select distinct auth_id from #step1
	where RTRIM(LTRIM(proc_code)) IN ('0662','3103','3105','H0038','H0043','H1017','H2014','S0311','S5100','S5101','S5102','S5108','S5110','S5111','S5120','S5121','S5125','S5130','S5131','S5135','S5136','S5140','S5141','S5170','S5175','S9127','S9451','T1001','T1004','T1022','T1023','T1028','T2012','T2020','T2021','T2023','T2031','S5199')
)s
join
(
	select auth_id from #step1
	where RTRIM(LTRIM(proc_code)) IN ('A0080','A0090','A0100','A0110','A0120','A0130','A0140','A0160','A0170','A0180','A0190','A0200','A0210','R0070','R0075','R0076','S0215','S9975','S9992','T2001','T2002','T2003','T2005','T2007','T2049','S0209','E1038','S0209')
)t
on s.auth_id = t.auth_id


-- select * from #T2003
--- If any of the following codes in a auth id, then that code will belong to that main team in that auth
;with cat1 as
(
	select distinct [AUTH_ID], Category
	FROM #step1
	where [AUTH_ID] in 
	(
		select distinct [AUTH_ID]--, team
		from #step1
		where RTRIM(LTRIM(proc_code)) IN ('99213','99212','99214','99215','99211','99202','99201','99203','99204','99205','99245')
	)
	--order by 1,2
)
,cat2 as
(
	select distinct auth_id, count(*) as temp
	from cat1
	group by auth_id
	having count(*) = 2
	--order by 1
)
,cat3 as
(
	select distinct auth_id, Category
	from #step1
	where auth_id in
	(
		select distinct auth_id
		from cat2
	)
	and Category <> 'Procedure'
)--select * from junk3
select last_name, first_name, ccaid, plan_name, s.auth_id, s.created_on, s.auth_status, received_date, service_from_date, service_to_date, proc_code, proc_description, auth_priority, is_extension, decision_status, decision_date, [Verbal Notification], writtennotifdate, auth_type_name,
decision_status_code_desc, auth_no, decisioncreateddate, exclusion, pos, [Auth owner], [Auth Owner Role], [Auth Owner Department(s)], authcreatedby, keepline, 
case when j.auth_id is not null then j.category
--j.auth_id is null and t.auth_id is null then s.[Team] 
when t.auth_id is not null then 'LTSS'
when hh.auth_id is not null then 'Home Health'
when pca.auth_id is not null then 'PCA'
when toc.auth_id is not null then 'TOC'
when bh.auth_id is not null then 'BH'
--when tl.auth_id is not null then tl.team
else s.category 
end as category, 
--toc.auth_id,
adjusted_adjustedcheck
into #STEP1_1
FROM #STEP1 S
left join cat3 j
  on s.auth_id = j.auth_id
left join #T2003 t
  on s.auth_id = t.auth_id
left join
(--If any of the following Home Health code in a auth id, the whole auth will be HomeHealth
	select distinct auth_id from #step1
	where RTRIM(LTRIM(proc_code)) IN ('99601','99602','S5498','S5501','S5502','S5502','S5517','S5521','S9325','S9326','S9328','S9338','S9345','S9347','S9361','S9363','S9367','S9373','S9374','S9375','S9379','S9490','S9500','S9501','S9502','S9503','S9504','G0299','G0151')
)hh
  on s.auth_id = hh.auth_id
left join
(--If any of the following PCA code in a auth id, the whole auth will be PCA
	select distinct auth_id from #step1
	where RTRIM(LTRIM(proc_code)) IN ('T1019', 'T2022', '99456')
)pca
  on s.auth_id = pca.auth_id
left join
(--If any of the following PCA code in a auth id, the whole auth will be PCA
	select distinct auth_id from #step1
	where category = 'BH'
)bh
  on s.auth_id = bh.auth_id
left join
(--For 99307/99308, If either those codes are present in the auth, the whole auth should go to TOC. And If POS is 31, the whole auth will be TOC
	select distinct auth_id from #step1
	where (pos = '31' or RTRIM(LTRIM(proc_code)) = '99307' or RTRIM(LTRIM(proc_code)) = '99308')
	--and category not in ('SNF','Transportation')--<> 'SNF'
	--and auth_id in ('0502TEFC9','1231T68D0','1216MA11B','0304W1CB0','0207F2DC2')
	and auth_id not in 
	(
		select distinct auth_id from #STEP1 where category  in ('SNF','Transportation')
	)
)toc
  on s.auth_id = toc.auth_id
--where s.auth_id in ('0502TEFC9','1231T68D0','1216MA11B','0304W1CB0','0207F2DC2')  
--order by s.auth_id



-- if there's a SNF and TOC both existed in 1 auth, assign the entire auth to SNF (7/14/2020 per Kate)
begin tran
update #step1_1
set category = 'SNF'
where auth_id in
(
	select snf.auth_id
	from
	(
		select distinct auth_id
		from #STEP1_1
		where category = 'SNF'
	)snf
	join
	(
		select distinct auth_id
		from #STEP1_1
		where category = 'TOC'
	)toc
	on snf.auth_id = toc.auth_id
)
commit tran



SELECT AUTH_ID into #multipleteam FROM #STEP1 GROUP BY AUTH_ID HAVING COUNT(DISTINCT CATEGORY)>1

-- select writtennotifdate, * from #step1_1 where auth_id = '0116TFCC8'

--Adjusted Adjusted logic
----this part is updating the cases where auths have a decision as adjusted and reason adjusted to use the previous decision before it was adjusted


	begin tran
update #step1_1
set decision_date=a.replied_Date


from #step1_1 s
inner join 
(SELECT 
ROW_NUMBER() OVER(Partition by c.auth_id ORDER BY a.replied_date desc) AS Row,
      a.[DECISION_ID]
      ,a.[DECISION_NO]
      ,a.[AUTH_NO]
      ,a.[REPLIED_DATE]
         ,c.auth_id
   FROM [Altruista].[dbo].[AUDIT_UM_DECISION_LOG] a
  inner join (
  SELECT [DECISION_ID]
      ,[DECISION_NO]
      ,[AUTH_NO]
    FROM [Altruista].[dbo].[UM_DECISION]
  where 
  decision_status = '4'
  and decision_status_code_id = '1'
) b
on a.DECISION_ID = b.DECISION_ID
and a.DECISION_NO = b.DECISION_NO
and a.auth_no = b.AUTH_NO
left join [Altruista].dbo.um_auth c
on a.AUTH_NO = c.AUTH_NO
where a.replied_date is not null
and a.decision_Status not in (4,8)
and a.DELETED_ON is null
) a
on s.auth_no=a.auth_no
 where  decision_status='adjusted' and DECISION_STATUS_CODE_DESC  ='Adjusted'
and row = 1

commit tran


create index idx_auth_id_1 on #step1_1(auth_id);
-- select * from #step1_1 where auth_id in ('0103FC415','0104S0C29','0104S24F6')

-- drop table #step2
SELECT [LAST_NAME]
,[FIRST_NAME]
,[CCAID]
, plan_name
,s.[AUTH_ID]
,s.created_on
,s.auth_status
,[Received_date]
, STUFF(
	ISNULL(
			(
				SELECT
					' | ' +S2.[PROC_CODE]
				FROM #STEP1 AS S2
				WHERE S2.[AUTH_ID] = S.[AUTH_ID] 
				GROUP BY
					S2.[PROC_CODE]
				FOR XML PATH (''), TYPE
			).value('.', 'VARCHAR(MAX)') --note: "value" must be lowercase
	  , '')
, 1, 2, '') AS 'Service Code(s)'
--, r.[Service Description]
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
			).value('.', 'VARCHAR(MAX)') --note: "value" must be lowercase
	, '')
, 1, 2, '') AS 'Service Description(s)'
  --,[UnitsRequested]
  --,[UnitsApproved]
,[auth_priority]
--,[auth_status]
--,[auth_status_reason_name]
,[IS_EXTENsion]
,case when ad.[AUTH_ID] is not null then ad.[Overall Decision]
when decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') then 'Denied'  --- changed 6/18/19
when decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%'  then 'Approved'--confirmed with Amelia on 12/21/2018
when decision_status= 'Partially Approved' then 'Denied'																					---- also changed 6/18
when decision_status='TRANS APPROVED' THEN 'Approved'
else decision_status 
end as 'Overall Decision'
--       ,case when ad.[AUTH_ID] is not null then [ODAG]
--when decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') then 'Denied'
-- when decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%'  then 'Approved'
-- when decision_status='TRANS APPROVED' THEN 'Approved'
--  when decision_status='PARTIALLY APPROVED' THEN 'Denied'
-- else decision_status end as 'ODAG Decision_status'
--,[DECISION_STATUS_CODE_DESC]
, [Decision_Date]
,[Verbal Notification]
,[WrittenNotifDate]
,[auth_type_name]
,min([SERVICE_FROM_DATE]) as [min_SERVICE_FROM_DATE]
,max([SERVICE_To_DATE]) as [max_SERVICE_to_DATE]
,auth_no
,s.DecisionCreatedDate
--,removedlines
,MAX(category) AS CATEGORY
,s.pos
,Adjusted_AdjustedCheck
into #step2
FROM #STEP1_1 S
left join
----- CHANGED HERE ON 6/18
(  
	select distinct a.auth_id, 'Denied' as 'Overall Decision' 
	from
	( 
		select * 
		from #step1_1 s 
		where decision_status in ('Partially Approved','denied') or  (decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%'))
	)a
	inner join 
	(
		select * 
		from #step1_1 se 
		where decision_status in ('approved','Partially Approved', 'trans approved')  or  (decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%adjusted%' ))
	) b 
	on a.[AUTH_ID]=b.[auth_id]
)ad 
on s.auth_id=ad.auth_id
GROUP BY [LAST_NAME]
,[FIRST_NAME]
,[CCAID]
, plan_name
,s.[AUTH_ID]
,s.auth_status
,s.created_on
,[Received_date]
,[auth_priority]
,[IS_EXTENsion]
,case when ad.[AUTH_ID] is not null then ad.[Overall Decision]
when decision_status='adjusted' and ( DECISION_STATUS_CODE_DESC  like '%reduction%' or  DECISION_STATUS_CODE_DESC  like '%termination%') then 'Denied'  --- changed 6/18/19
when decision_status='adjusted' and DECISION_STATUS_CODE_DESC  like '%adjusted%'  then 'Approved'--confirmed with Amelia on 12/21/2018
when decision_status 			= 'Partially Approved' then 'Denied'																					---- also changed 6/18
when decision_status='TRANS APPROVED' THEN 'Approved'
else decision_status end
, [Decision_Date]
,[Verbal Notification]
,[WrittenNotifDate]
,[auth_type_name]
, auth_no
, s.DecisionCreatedDate
--,removedlines
--, category
,s.pos
,Adjusted_AdjustedCheck


-- select * from #step2 where auth_id in ('0319T4AF6','0405F1F8F')


--select * from #step2
--where [Service Code(s)] like '%T2022%'


---remove inpatient and other codes that do not require PA per Amelia
delete from #step2
where [Service Code(s)] = ' T2022' --or [Service Code(s)] = 'T2022'
--and auth_id = '0528T2CE2'
--(11332 row(s) affected)

--begin tran
update #step2
set [Service Code(s)] = replace([Service Code(s)], '| T2022', ''), [Service Description(s)] = replace([Service Description(s)], '| Personal Care Management Skills Training (PCM)', '')
where [Service Code(s)] like '%| T2022'





-- drop table #step3

SELECT  [CCAID]
, plan_name
,s.[AUTH_ID]
,s.created_on
,s.auth_status
,[Received_date] as 'Received_Date'
, [Service Code(s)]
, [Service Description(s)]
,[auth_priority]
,[IS_extension]
,[Overall Decision]
--, [ORG Determination decision_Status]
,case when rtrim(ltrim([Service Code(s)])) in ('120','191','192','193', '0120','0191','0191','0192', '0193','0100') 
OR rtrim(ltrim([Service Code(s)])) LIKE '0120 | 0191'   OR rtrim(ltrim([Service Code(s)])) LIKE '0120 | 0192'   OR rtrim(ltrim([Service Code(s)])) LIKE '0120 | 0193'
OR rtrim(ltrim([Service Code(s)])) LIKE '0191 | 0192'  OR rtrim(ltrim([Service Code(s)])) LIKE '0191 | 0193' OR rtrim(ltrim([Service Code(s)])) LIKE '0192 | 0193'
then  min([Decision_Date]) else  MAX([Decision_Date]) end as 'Decision_Date'--Amelia stated to use the MIN Decision date for SNFs
,max([Verbal Notification]) as 'Verbal_Notification'
--,max([WrittenNotifDate]) as 'WrittenNotifDate'
--,min([WrittenNotifDate]) as 'WrittenNotifDate'
,case when s.[Overall Decision] = 'Denied' then den.WrittenNotifDate
else min(s.[WrittenNotifDate])
end as [WrittenNotifDate]
,[auth_type_name]
, CASE WHEN received_date is null then 0
when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN dateadd (dd, 28, cast(received_date as date))
WHEN auth_priority = 'Prospective Standard'  THEN dateadd (dd, 14, cast(received_date as date))
when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 17, received_date)
when auth_priority = 'Prospective Expedited'  THEN dateadd (dd,3,received_date)
WHEN auth_priority = 'Retrospective' and IS_extension = 'Yes' THEN dateadd (dd, 28, received_date) --cast(received_date as date))
WHEN auth_priority = 'Retrospective'  THEN dateadd (dd, 14, cast(received_date as date))
when (auth_priority = 'Concurrent Standard' and is_extension ='yes') THEN dateadd (dd, 28, cast(received_date as date))
WHEN auth_priority = 'Concurrent Standard'  THEN dateadd (dd, 14, cast(received_date as date))
when auth_priority = 'Concurrent Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 28, received_date)
WHEN auth_priority = 'Concurrent Expedited'  THEN dateadd (dd, 14,received_date)
when auth_priority = 'Part B Med Expedited'   THEN dateadd (dd, 1, received_date)
when auth_priority = 'Part B Med Standard'  THEN dateadd(dd, 3, received_date) 
else 0 end as deadline      -- select deadline, * from #step3 where auth_id = '0102W3CA5'
, Adjusted_AdjustedCheck
, min([min_SERVICE_FROM_DATE]) as [min_SERVICE_FROM_DATE]
, max([max_SERVICE_to_DATE]) as [max_SERVICE_to_DATE]
, auth_no
	--		, MIN (DecisionCreatedDate ) as 'MinAuthCreatedDate'
	--, Max (DecisionCreatedDate ) as 'MaxAuthCreatedDate'
	--,removedlines
, MAX(CATEGORY) AS CATEGORY
, s.pos
into #step3 
FROM #STEP2 S
left join 
(
	select auth_id, min([WrittenNotifDate]) as 'WrittenNotifDate' 
	from #step1
	where decision_status in ('Denied','Partially Approved','Adjusted')
	--and auth_id = '0109TA80B'
	group by auth_id
)den 
on s.auth_id = den.auth_id
-- select * from #step2 where auth_id = '0102T8FE0'	
--where s.auth_id = '0122W2795'
GROUP BY [CCAID]
, plan_name
,s.[AUTH_ID]
,s.created_on
,s.auth_status
,[Received_date] 
, [Service Code(s)]
, [Service Description(s)]
, s.pos
, [auth_priority]
,[IS_EXTENsion]
,[Overall Decision]
,[auth_type_name]
,s.[Overall Decision]
, den.WrittenNotifDate
, CASE WHEN received_date is null then 0
when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN dateadd (dd, 28, cast(received_date as date))
WHEN auth_priority = 'Prospective Standard'  THEN dateadd (dd, 14, cast(received_date as date))
when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 17, received_date)
when auth_priority = 'Prospective Expedited'  THEN dateadd (dd,3,received_date)
WHEN auth_priority = 'Retrospective'  THEN dateadd (dd, 14, cast(received_date as date))
WHEN auth_priority = 'Retrospective' and is_extension ='yes' THEN dateadd (dd, 28, received_date) --cast(received_date as date))
when (auth_priority = 'Concurrent Standard' and is_extension ='yes') THEN dateadd (dd, 28, cast(received_date as date))
WHEN auth_priority = 'Concurrent Standard'  THEN dateadd (dd, 14, cast(received_date as date))
when auth_priority = 'Concurrent Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 28, received_date)
WHEN auth_priority = 'Concurrent Expedited'  THEN dateadd (dd, 14,received_date)
when auth_priority = 'Part B Med Expedited'   THEN dateadd (dd, 1, received_date)
when auth_priority = 'Part B Med Standard'  THEN dateadd(dd, 3, received_date) 
else 0 end
, Adjusted_AdjustedCheck
, auth_no
				--, CATEGORY

-- select * from #step3 where auth_id in ('0319T4AF6','0405F1F8F')

-- select count(*) from #step4

-- drop table #step4


select s3.CCAID, s3.plan_name, s3.AUTH_ID, s3.created_on, s3.auth_status, s3.Received_Date, s3.[Service Code(s)], s3.[Service Description(s)], s3.auth_priority, s3.IS_extension, s3.[Overall Decision], s3.Decision_Date, s3.Verbal_Notification, --s3.WrittenNotifDate,
min(crm.printandmailtime) as writtennotifdate, s3.auth_type_name, s3.deadline, s3.Adjusted_AdjustedCheck, s3.min_SERVICE_FROM_DATE, s3.max_SERVICE_to_DATE, s3.auth_no, s3.CATEGORY, s3.pos
into #step4
from #step3 s3
join [PartnerExchange].[auths].[CCARemoteMailing_correction] crmc
on s3.auth_id = crmc.authid and crmc.correctedfilename not like '%exten%'
left join [PartnerExchange].[auths].[CCARemoteMailing] crm
on crmc.filename = crm.filename
group by s3.CCAID, s3.plan_name, s3.AUTH_ID, s3.created_on, s3.auth_status, s3.Received_Date, s3.[Service Code(s)], s3.[Service Description(s)], s3.auth_priority, s3.IS_extension, s3.[Overall Decision], s3.Decision_Date, s3.Verbal_Notification, s3.WrittenNotifDate,
s3.auth_type_name, s3.deadline, s3.Adjusted_AdjustedCheck, s3.min_SERVICE_FROM_DATE, s3.max_SERVICE_to_DATE, s3.auth_no, s3.CATEGORY, s3.pos

union

select s3.CCAID, s3.plan_name, s3.AUTH_ID, s3.created_on, s3.auth_status, s3.Received_Date, s3.[Service Code(s)], s3.[Service Description(s)], s3.auth_priority, s3.IS_extension, s3.[Overall Decision], s3.Decision_Date, s3.Verbal_Notification, 
case when [Overall Decision] = 'Denied' and cast(s3.WrittenNotifDate as datetime) >= '2020-03-26 16:52:00' then min(crm.printandmailtime)
else s3.WrittenNotifDate end as writtennotifdate,
--coalesce(min(crm.printandmailtime), s3.WrittenNotifDate) as writtennotifdate, 
--min(crm.printandmailtime),
s3.auth_type_name, s3.deadline, s3.Adjusted_AdjustedCheck, s3.min_SERVICE_FROM_DATE, s3.max_SERVICE_to_DATE, s3.auth_no, s3.CATEGORY, s3.pos
--into #abc
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
) 
--and crm.[filename] not in
--(
--	select b.[filename]
--	from [PartnerExchange].[auths].[CCARemoteMailing_correction] a
--	join [PartnerExchange].[auths].[CCARemoteMailing] b
--	on a.[filename] = b.[filename]
--	where correctedfilename like '%exten%'
--)
--and s3.[Overall Decision] = 'Denied'
--and s3.auth_id in ('0117TE353')
group by s3.CCAID, s3.plan_name, s3.AUTH_ID, s3.created_on, s3.auth_status, s3.Received_Date, s3.[Service Code(s)], s3.[Service Description(s)], s3.auth_priority, s3.IS_extension, s3.[Overall Decision], s3.Decision_Date, s3.Verbal_Notification, s3.WrittenNotifDate,
s3.auth_type_name, s3.deadline, s3.Adjusted_AdjustedCheck, s3.min_SERVICE_FROM_DATE, s3.max_SERVICE_to_DATE, s3.auth_no, s3.CATEGORY, s3.pos

begin tran
update #step4
set writtennotifdate = null
where writtennotifdate = '1900-01-01 00:00:00.000'
--
commit tran

-- select * from #step4 where auth_id in ('0319T4AF6','0405F1F8F') order by auth_id

-- select distinct [Overall Decision] from #step4 

BEGIN TRAN ---per Amelia, updating auth_id 0506MA284 to use letter created_date rather as decision date since decision status was updated after letter was created
       UPDATE #step4
       SET Decision_Date = '2019-05-15 03:47:46'
       from #step4
       where auth_id = '0506MA284'
commit tran

BEGIN TRAN ---per Amelia, updating auth_id 0423TB6F9 
       UPDATE #step4
       SET Decision_Date = '2019-05-03'
       from #step4 
       where auth_id = '0423TB6F9'
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-06-27'
       from #step4 
       where auth_id = '0624MD25F'
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-05-30'
       from #step4 
       where auth_id in ('0522W430E','0517F7235','0529WDE94','0528T3535','0521T3825')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-06-07'
       from #step4 
       where auth_id in ('0603M5646')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-06-05'
       from #step4 
       where auth_id in ('0524F6E32')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-06-12'
       from #step4 
       where auth_id in ('0531F53DC')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-07-03'
       from #step4 
       where auth_id in ('0702T333D')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-05-09'
       from #step4 
       where auth_id in ('0501W18A8')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-07-29'
       from #step4 
       where auth_id in ('0725T64B8')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-07-19'
       from #step4 
       where auth_id in ('0718T99D9')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-05-01'
       from #step4 
       where auth_id in ('0418T1A8B')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-07-23'
       from #step4 
       where auth_id in ('0722M2ADA')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-05-02'
       from #step4 
       where auth_id in ('0502TAE9C')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-07-11'
       from #step4 
       where auth_id in ('0711T7D2B')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-06-18'
       from #step4 
       where auth_id in ('0618T73A8')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-06-12'
       from #step4 
       where auth_id in ('0606T67F9')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-06-17'
       from #step4 
       where auth_id in ('0605WA9CD')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-05-22 15:53'
       from #step4 
       where auth_id in ('0522W26ED')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-05-16 15:51:37'
       from #step4 
       where auth_id in ('0516T04DD')
commit tran

BEGIN TRAN ---per Amelia
       UPDATE #step4
       SET Decision_Date = '2019-05-21 09:56:59'
       from #step4 
       where auth_id in ('0520M4BA7')
commit tran

BEGIN TRAN ---per Amelia, updating auth_id 0502T2FB3 
       UPDATE #step4
       SET Decision_Date = '2019-05-02'
       from #step4 
       where auth_id = '0502T2FB3'
commit tran

BEGIN TRAN ---per Amelia, updating auth_id 0502T2FB3 
       UPDATE #step4
       SET Decision_Date = '2019-06-28'
       from #step4 
       where auth_id = '0628F57E5'
commit tran

BEGIN TRAN ---per Amelia, updating auth_id 0502T2FB3 
       UPDATE #step4
       SET Decision_Date = '2019-05-29'
       from #step4 
       where auth_id = '0524F590F'
commit tran

BEGIN TRAN 
       UPDATE #step4
       SET Decision_Date = '2019-07-22'
       from #step4 
       where auth_id = '0718T2E9F'
commit tran

BEGIN TRAN 
       UPDATE #step4
       SET Decision_Date = '2019-07-22'
       from #step4 
       where auth_id = '0715ME5C7'
commit tran

BEGIN TRAN 
       UPDATE #step4
       SET Decision_Date = '2019-07-18'
       from #step4 
       where auth_id = '0715M67E7'
commit tran

BEGIN TRAN 
       UPDATE #step4
       SET Decision_Date = '2019-07-26'
       from #step4 
       where auth_id = '0723T3101'
commit tran

BEGIN TRAN 
       UPDATE #step4
       SET Decision_Date = '2019-07-15'
       from #step4 
       where auth_id = '0715MF398'
commit tran










DECLARE
  @StartDate DATETIME
   
SET
  @StartDate = '2019-01-01'






--select * from #step4 where auth_id  = '0117TE353'

SELECT 

 f.*
     ,CMO_name as cmo



,case when Product = 'ICO' then 'CCA Managed'
	when CMO_Group = 'Delegated Site' then 'Externally Managed'
	--when product = 'SCO' and CMO in ('BIDHC-ECCP', 'BU Geriatric Service', 'East Boston Neighborhoo', 'Element Care', 'Uphams Corner Hlth Cent') then 'Externally Managed'
	--when product = 'SCO' and meh.care_mgmt in ('BIDHC-ECCP', 'BU Geriatric Service', 'East Boston Neighborhoo', 'Element Care', 'Uphams Corner Hlth Cent') then 'Externally Managed'
	when product = 'SCO' and meh.cmo_name in ('BIDHC-ECCP', 'BU Geriatric Service', 'East Boston Neighborhoo', 'Element Care', 'Uphams Corner Hlth Cent') then 'Externally Managed'
	when cmo_name like 'Long Term Care%' or meh.cmo_name in ('Behavioral Hlth Ntwrk', 'Onboarding') then 'CCA Managed'
	
	when CMO_Group is null and plan_name in ('SCO MassHealth Only-Externally Managed','SCO-Externally Managed') then 'Externally Managed' 
	--when CMO_Group is null and plan_name = 'iCO-Externally Managed' then 'Externally Managed'
	else 'CCA Managed' end as Managed2
 


 , case  ---when auth_priority like '%concurrent%'  then 'NA'
	  when DECISION_DATE is null AND cast (deadline as date) <= cast (getdate() as date)  then 'UntimelyDecision'
	   when DECISION_DATE is null AND cast (deadline as date) > cast (getdate() as date)  then 'TimelyDecision'
	  	  when DECISION_DATE is null then 'NoDecision'
	  when received_date is null  then 'NA'
	  --when ud.replied_date = '1900-01-01' then 'NoDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 0 then 'UntimelyDecision' 

	  --when datediff(dd,received_date, DECISION_DATE)> 3 and auth_priority = 'Part B Med Standard' then 'UntimelyDecision'
	  --when datediff(dd,received_date, DECISION_DATE)> 1 and auth_priority = 'Part B Med Expedited' then 'UntimelyDecision'
	  when DECISION_DATE <= deadline and auth_priority like 'Part B Med %' then 'TimelyDecision' -- this is upon Amelia's request to 8c in her document
	  when DECISION_DATE > deadline and auth_priority like 'Part B Med %' then 'UntimelyDecision' -- this is upon Amelia's request to 8c in her document
--	  when datediff(dd,received_date, DECISION_DATE)> 1 and auth_priority = 'Part B Med Expedited' then 'UntimelyDecision'

	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%retro%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%retro%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'

	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%standard%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 29 and(auth_priority like '%standard%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'
	  
	  --when datediff(minute,received_date, DECISION_DATE)/24.0 <=3 and auth_priority like  '%Expedited%' and (is_extension ='No' or is_extension is null) then 'TimelyDecision' -- 4320
	  --when datediff(minute,received_date, DECISION_DATE)/24.0 <=17 and auth_priority like  '%Expedited%' and is_extension ='Yes' then 'TimelyDecision' --24480
	  when datediff(minute,received_date, DECISION_DATE) <= 4320 and auth_priority like  '%Expedited%' and (is_extension ='No' or is_extension is null) then 'TimelyDecision' -- 4320 min = 3 days
	  when datediff(minute,received_date, DECISION_DATE) <= 24480 and auth_priority like  '%Expedited%' and is_extension ='Yes' then 'TimelyDecision' -- 24480 min = 17 days


	  else 'UntimelyDecision' 
   end as 'DecisionFlag' 
, datediff(minute,received_date, DECISION_DATE) as temp
, case ---when auth_priority like '%concurrent%'  then 'NA'

  when received_date is null then 'NA'
	when [WrittenNotifDate] is null and  cast (deadline as date) <= cast (getdate() as date) then 'UntimelyLetter'
	when [WrittenNotifDate] is null and  cast (deadline as date) > cast (getdate() as date)  then 'TimelyLetter'
	when convert(date,[WrittenNotifDate]) = '1900-01-01' and  cast (deadline as date) <= cast (getdate() as date)  then 'UntimelyLetter'
	when convert(date,[WrittenNotifDate]) = '1900-01-01' and cast (deadline as date)  > cast (getdate() as date) then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 0 then 'UntimelyLetter' 
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'retrospective')  then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'retrospective') and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'Prospective Standard')  then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'Prospective Standard') and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(hour,[Received_date],convert(datetime,[WrittenNotifDate]))/24.0 <= 3 and auth_priority = 'Prospective Expedited' and (is_extension = 'No' or is_extension is null) then 'TimelyLetter'
    when datediff(hour,[Received_date],convert(datetime,[WrittenNotifDate]))/24.0 <= 17 and auth_priority  = 'Prospective Expedited' and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'Concurrent Standard')  then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'Concurrent Standard') and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 15 and auth_priority = 'Concurrent Expedited' and (is_extension = 'No' or is_extension is null) then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 29 and auth_priority  = 'Concurrent Expedited' and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 2 and auth_priority = 'Part B Med Expedited'  then 'TimelyLetter'
	when datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate])) < 4 and auth_priority  = 'Part B Med Standard'  then 'TimelyLetter'


	---Amelia stated to treat concurrent expedited as standard
	else 'UntimelyLetter' 
end as 'LetterFlag'
,rec.member_month as 'ReceivedMonth'
,CMO_Group, Dual
	--,datediff(dd,convert(date,[Received_date]),convert(date,[WrittenNotifDate]))   
	INTO #FINAL
	--INTO #FINALll
	  FROM #step4 f -- select top 1000 * from #step4
--left join ccamis_common.dbo.dim_date rec on cast (f.received_Date as date)= rec.date	  
left join ccamis_common.dbo.dim_date rec on cast (f.created_on as date)= rec.date	  
--left join ccamis_common.dbo.dim_date ddec on cast (f.DECISION_DATE as date)= ddec.date
--left join ccamis_common.dbo.dim_date ddl on cast (f.deadline as date) = ddl.date
--left join medical_analytics.dbo.member_enrollment_history MEH on meh.ccaid = f.ccaid and meh.member_month = rec.member_month
left join medical_analytics.dbo.member_enrollment_MP MEH on meh.ccaid = f.ccaid and meh.member_month = rec.member_month

	--where received_date >= @startdate -- '2019-01-01'--
	--where created_date >= @startdate -- '2019-01-01'--
	--and auth_id in ( '0105S0356','0823F7AF2','0812M6F97','0621FEEE2','0531F06A4','0318MA1D1','0309M51B8','0208FE215','0208F4E14','0208F47D6','0130W4A3E')
	--and auth_priority = 'Prospective Expedited'

--and writtennotifdate > deadline
--and  auth_id in ('0325M2A54','0517F4D33')

--drop table #final

--select DecisionFlag, deadline, * from #final where auth_id in ('0319T4AF6','0405F1F8F') --where auth_priority like 'concurrent%'
-- 


select  a.*
, case when cast(min_service_from_date as date) < cast(received_Date as date) then 'Yes' else 'No' end as 'Start date is prior to request date'
--, adj.replied_date
, case when cast(max_service_to_date as date) < cast(received_Date as date) then 'Yes' else 'No' end as 'End date is prior to request date'

, case when b.auth_id is not null then 'YES' ELSE 'NO' END AS 'MultipleTeams'
into #final2
from
(
	SELECT * 
	FROM #FINAL s1
	  where
		 ((s1.[Overall Decision] = 'Pending' and s1.auth_type_name <>'Inpatient') or (s1.[Overall Decision] <> 'Pending' and s1.auth_type_name ='Inpatient'))---5/20/2019 Amelia stated that when an auth is SNF/Inpatient---we should choose the line that isnt pending if there is one---choose the first line---logic for first line is above
		 
		 ---since there are ones that have pending and approved/denied---we have to consider the pending in these cases since the whole auth isnt complete and thus would be considered as having no decision
			or s1.AUTH_ID not in (select distinct AUTH_ID from #final s2 where ((s1.AUTH_ID = s2.AUTH_ID and s2.[overall decision] = 'Pending' and s2.auth_type_name <>'Inpatient')
			or (s1.AUTH_ID = s2.AUTH_ID and s2.[overall decision] <> 'Pending' and s2.auth_type_name ='Inpatient'))
			)
	)a 

	LEFT JOIN (SELECT AUTH_ID FROM #multipleteam GROUP BY AUTH_ID)b on a.auth_id=b.auth_id
	--left join (select auth_id, 

	where [Service Code(s)] is not null 
	and not((a.auth_id ='0108TD4B8'and [overall decision] is null) or (a.auth_id ='0129TD250'and [overall decision] is null))--these two auths are duplicating
	
	and [overall decision] is not null

-- select * from #final2 where auth_id in ('0808S8054')

BEGIN TRAN ---per Kate, Updating so that the written notification date will get picked up as this is a case where the decision is after letter

UPDATE #final2
SET Decision_Date = '2020-03-18'
from
#final2 
where auth_id = '0310T5E41'

commit tran

-- select * from #final2 where auth_id in ('0401WA19A','0908T1B52','1023F2B1C','1013T390D')

	------new written notification logic------
select a.*
into #letters
from
(
	select ud.document_ref_id, ud.letter_printed_Date as letter_date,	 'Approved' as 'Type'
	, case when ud.created_on >= '2019-06-28' then 'AH' else 'internal' end as 'TimeStampLogic' 
	from Altruista.dbo.um_document ud
	left join #final2 f2
	on ud.document_ref_id = f2.auth_no
	where ud.document_name like '%approv%' and ud.document_type_id in (2,4)
	and not (ud.document_name like '%appeal%' or ud.document_name like  '%reopen%')
	and ud.DELETED_ON is null and ud.letter_printed_Date is not null
	and ud.created_on > f2.decision_date -- letter created_on must be after the decision date
	--and ud.document_ref_id = '366063'
	group by ud.document_ref_id, ud.letter_printed_Date , case when ud.created_on >= '2019-06-28' then 'AH' else 'internal' end   

	union
	   
	select document_ref_id
    , case when cast (created_on as time) < '16:00:00'then  created_on  else  dateadd (dd,1,created_on ) 
    end as 'Letter Date'
	, 'Denied' as 'Type'
	, 'internal' as 'TimeStampLogic' 
	from Altruista.dbo.um_document 
	where --((document_name like '%denial%' and  document_type_id in (1,2)) or  document_type_id=6) 
	document_name like '%denial%' and document_type_id in (2, 6)
	and DELETED_ON is null
	--and document_ref_id = 327703
	group by document_ref_id, case when cast (created_on as time) < '16:00:00'
    then  created_on  else  dateadd (dd,1,created_on ) end
)a

select *, 
case when [type]='approved' and [timestamplogic]='internal' then  dateadd (hour, 12, cast(cast (letter_date as date) as datetime))
when [type]='denied' then dateadd (hour, 16, cast(cast (letter_date as date) as datetime)) else letter_date
end as 'Correct_Letter_Date'
into #letters_v2
from #letters

-- drop index #letters_v2.idx_letters_v2
-- create index idx_letters_v2 on #letters_v2(document_ref_id, [type])
create clustered columnstore index ccl_ind on #letters_v2

--select top 100 * from #letters_v2 where document_ref_id in (15675)
--select * from Altruista.dbo.um_document where document_ref_id in (352681,359148,359495) order by 4

-- 
--select *,  dense_rank () over (partition by  let.[document_REF_ID] order by let.letter_Date asc) as letter_ORDER 
--from #letters_v2 let
--where document_ref_id in ('275150')

-- select count(*) from #final2

--select distinct [type] 
--from #letters_v2

--select a.document_ref_id
--from 
--(
--	select distinct document_ref_id
--	from #letters_v2
--	where type = 'Approved'
--)a
--join
--(
--	select distinct document_ref_id
--	from #letters_v2
--	where type = 'Denied'
--)d 
--on a.document_ref_id = d.document_ref_id

-- drop table #final3

IF OBJECT_ID('tempdb..#final3') IS NOT NULL DROP TABLE #final3;

select 
CCAID
,plan_name	
,AUTH_ID
,created_on	
,auth_status
,Received_Date	
,[Service Code(s)]
, [Service Description(s)]
, auth_priority	
, IS_extension	
,[Overall Decision]
, Decision_Date	
, Verbal_Notification	
, WrittenNotifDate	
, auth_type_name	
, deadline	
, Adjusted_AdjustedCheck	
, min_SERVICE_FROM_DATE	
, max_SERVICE_to_DATE	
,f.auth_no	
--, removedlines	
, CATEGORY	
, DecisionFlag	
, LetterFlag	
, ReceivedMonth	
, [Start date is prior to request date]
, [End date is prior to request date]
, [MultipleTeams]
--, case when [Overall Decision] = 'Approved' then let_app.CORRECT_letter_date
--else let.CORRECT_letter_date
--end as CORRECT_letter_date
, CORRECT_letter_date
, [lettercount]
, es.decisions
, CMO
, CMO_Group, DUal
, Managed2
--, case when cast(letter_date as date)>= cast(decision_date as date) then 'yes'else 'no' end as test
--,dense_rank () over (partition by  let.[document_REF_ID] order by let.[type] desc, let.letter_Date asc) as letter_ORDER
,dense_rank () over (partition by  let.[document_REF_ID] order by let.letter_Date asc) as letter_ORDER -- replace the previous line by removed the order by [tyoe], only order by the letter day 8/5/2020 - Jason
, let.[type] as let_letter_type
into #final3
from #final2 f
left join #letters_v2 let 
on f.auth_no=let.document_ref_id and cast(let.CORRECT_letter_date as datetime)>= cast(decision_date as datetime)---looking for letters after or on decision date MEP CHANGE TO DATETIME
--and let.[type] <> 'Approved'
--left join #letters_v2 let_app 
--on f.auth_no=let.document_ref_id and cast(let.CORRECT_letter_date as datetime)>= cast(decision_date as datetime)---looking for letters after or on decision date MEP CHANGE TO DATETIME
--and let_app.[type] = 'Approved'
left join  
(
	select
	document_ref_id, count(letter_date) as lettercount 
	,STUFF(
		ISNULL(
				(
					SELECT
						' | ' +S2.[type]
					FROM #letters_V2 AS S2
					WHERE S2. document_ref_id = l.document_ref_id 
					GROUP BY
						S2.[type]
					FOR XML PATH (''), TYPE
				).value('.', 'VARCHAR(MAX)') --note: "value" must be lowercase
			, '')
		, 1, 2, ''
	) AS 'Decisions'
	from #letters_V2 l 
	where document_ref_id = 255596
	group by document_Ref_id
) es 
on f.auth_no = es.document_ref_id 
--where auth_id in ('0215S8DAF')
group by
CCAID
,plan_name	
,AUTH_ID	
,created_on
,auth_status
,Received_Date	
,[Service Code(s)]
, [Service Description(s)]
, auth_priority	
, IS_extension	
, [Overall Decision]
, Decision_Date	
, Verbal_Notification	
, WrittenNotifDate	
, auth_type_name	
, deadline	
, Adjusted_AdjustedCheck	
, min_SERVICE_FROM_DATE	
, max_SERVICE_to_DATE	
, f.auth_no	
--, removedlines	
, CATEGORY	
, DecisionFlag	
, LetterFlag	
, ReceivedMonth	
, [Start date is prior to request date]
, [End date is prior to request date]
, [MultipleTeams]
, CMO, CMO_Group, DUal
 --min (letter_date) as letterdate
, [lettercount]
, es.decisions
, CORRECT_letter_date
, let.[document_REF_ID]
, let.[type] 
, let.letter_Date 
, Managed2
, let.[type] 
--, case when [Overall Decision] = 'Approved' then let_app.CORRECT_letter_date
--else let.CORRECT_letter_date end
order by auth_id


-- select * from #final3 where auth_id in ('0319T4AF6','0405F1F8F') order by auth_id

--select distinct auth_priority, tat
--from #report2
--order by 1
--

-- select * from #letters_v2 where document_ref_id in (255596, 227261)

-- select distinct [Overall Decision], count(*) from #final3 group by [Overall Decision]


-- select distinct auth

IF OBJECT_ID('tempdb..#report') IS NOT NULL DROP TABLE #report;

select 
f.CCAID
,f.plan_name	
,f.AUTH_ID	
,f.created_on
,f.auth_status
,f.Received_Date	
,f.[Service Code(s)]
,f.[Service Description(s)]
,f.auth_priority	
,f.IS_extension	
,f.[Overall Decision]
,f.Decision_Date	
,f.Verbal_Notification	
--, f.CORRECT_letter_date as 'WrittenNotifDate'
--, case when f.[WrittenNotifDate] >= '2020-03-26' then f.[WrittenNotifDate] else f.CORRECT_letter_date end as 'WrittenNotifDate' -- Jason 10/8/2020: after talked to MEP, if the letter date is after 3/26, use the date from [CCARemoteMailing], otherwise use the "new written notification logic" created by Sara
, case when f.[Overall Decision] = 'Denied' then f.[WrittenNotifDate] 
when f.[Overall Decision] = 'Approved' and f.let_letter_type = 'Denied' then f.[WrittenNotifDate]
when f.[Overall Decision] = 'Approved' and f.let_letter_type <> 'Denied' then f.CORRECT_letter_date--min(f.CORRECT_letter_date)  
else f.CORRECT_letter_date end as 'WrittenNotifDate' -- Jason 10/8/2020: after talked to MEP, if the letter date is after 3/26, use the date from [CCARemoteMailing], otherwise use the "new written notification logic" created by Sara
--, case when f.[Overall Decision] = 'Denied' then f.[WrittenNotifDate] 
--when f.[Overall Decision] <> 'Denied' and f.[WrittenNotifDate] >= '2020-03-26' then f.[WrittenNotifDate]
--else f.CORRECT_letter_date end as 'WrittenNotifDate' -- Jason 10/8/2020: after talked to MEP, if the letter date is after 3/26, use the date from [CCARemoteMailing], otherwise use the "new written notification logic" created by Sara
,f.auth_type_name	
,f.deadline	
,f.Adjusted_AdjustedCheck	
,f.min_SERVICE_FROM_DATE	
,f.max_SERVICE_to_DATE	
,f.auth_no	
--,f.removedlines	
,f.CATEGORY	
,f.DecisionFlag	
,case ---when auth_priority like '%concurrent%'  then 'NA'
when received_date is null then 'NA'
when CORRECT_LETTER_dATE is null and  cast (deadline as date) <= cast (getdate() as date) then 'UntimelyLetter'
when CORRECT_LETTER_dATE is null and  cast (deadline as date) > cast (getdate() as date)  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 0 then 'UntimelyLetter' 
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'retrospective')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'retrospective') and f.is_extension = 'Yes' then 'TimelyLetter'
--when auth_priority = 'Retrospective' and (convert(date, verbal_notification) > convert(date, deadline) or verbal_notification is null) and convert(date, writtennotifdate) <= convert(date, deadline) then 'timelyLetter' --If no verbal notification is made, or verbal notification > deadline, the written notifcation has to <= deadline to be timely. 
--when auth_priority = 'Retrospective' and writtennotifdate < (case when convert(date, verbal_notification) <= convert(date, deadline) then dateadd(dd, 3, convert(date, deadline)) end) then 'timelyletter' -- if verbal is made on/before deadline, then written notification has to <= after add 3 days to deadline in order to be timely
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'Prospective Standard')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'Prospective Standard') and f.is_extension = 'Yes' then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) <= 72 and auth_priority = 'Prospective Expedited' and (f.is_extension = 'No' or f.is_extension is null) then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE))/24.0 <= 17 and auth_priority  = 'Prospective Expedited' and f.is_extension = 'Yes' then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'Concurrent Standard')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'Concurrent Standard') and f.is_extension = 'Yes' then 'TimelyLetter'
when datediff(dd,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) < 15 and auth_priority = 'Concurrent Expedited' and (f.is_extension = 'No' or f.is_extension is null) then 'TimelyLetter'
when datediff(dd,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) < 29  and auth_priority  = 'Concurrent Expedited' and f.is_extension = 'Yes' then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) <= 24  and auth_priority = 'Part B Med Expedited'  then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) <= 72  and auth_priority  = 'Part B Med Standard' then 'TimelyLetter'
else 'UntimelyLetter' 
end as 'LetterFlag'
,ReceivedMonth	
--, [Start date is prior to request date]
--, [End date is prior to request date]
,[MultipleTeams]
--,convert(datetime,CORRECT_LETTER_dATE)
,a.pos
--,datediff(hour,f.[Received_date],convert(datetime,CORRECT_LETTER_dATE))
,case when CORRECT_LETTER_dATE is null then 'NoLetter' else 'Letter' end as TATDenominator

--, CORRECT_LETTER_dATE
,CMO
,CMO_Group, DUal
,Managed2
--, [lettercount]
--, decisions as LetterDecisions
INTO #report
from #final3 f
left join 
(
	select auth_id, pos 
	from #step
	group by auth_id, pos
) a 
on a.auth_id = f.auth_id
where letter_order=1 --and  receivedmonth>= '2019-01-01'  
--and f.auth_id in ('0319T4AF6','0405F1F8F')
group by
CCAID
,plan_name	
,f.AUTH_ID	
,f.created_on
,f.auth_status
,f.Received_Date	
,f.[Service Code(s)]
,f.[Service Description(s)]
,f.auth_priority	
,f.IS_extension	
,f.[Overall Decision]
,f.Decision_Date	
,f.Verbal_Notification	
,f.CORRECT_letter_date	
,case when f.[Overall Decision] = 'Denied' then f.[WrittenNotifDate] 
when f.[Overall Decision] = 'Approved' and f.let_letter_type = 'Denied' then f.[WrittenNotifDate]
when f.[Overall Decision] = 'Approved' and f.let_letter_type <> 'Denied' then f.CORRECT_letter_date--min(f.CORRECT_letter_date)      
else f.CORRECT_letter_date end -- Jason 10/8/2020: after talked to MEP, if the letter date is after 3/26, use the date from [CCARemoteMailing], otherwise use the "new written notification logic" created by Sara
--,f.[WrittenNotifDate] 
--,f.[Overall Decision]
--,f.CORRECT_letter_date
,f.auth_type_name	
,f.deadline	
,f.Adjusted_AdjustedCheck	
,f.min_SERVICE_FROM_DATE	
,f.max_SERVICE_to_DATE	
,f.auth_no	
--,f.removedlines	
,f.CATEGORY	
,f.DecisionFlag	
,a.pos
, Managed2
, case ---when auth_priority like '%concurrent%'  then 'NA'
when received_date is null then 'NA'
when CORRECT_LETTER_dATE is null and  cast (deadline as date) <= cast (getdate() as date) then 'UntimelyLetter'
when CORRECT_LETTER_dATE is null and  cast (deadline as date) > cast (getdate() as date)  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 0 then 'UntimelyLetter' 
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'retrospective')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'retrospective') and f.is_extension = 'Yes' then 'TimelyLetter'
--when auth_priority = 'Retrospective' and (convert(date, verbal_notification) > convert(date, deadline) or verbal_notification is null) and convert(date, writtennotifdate) <= convert(date, deadline) then 'timelyLetter' --If no verbal notification is made, or verbal notification > deadline, the written notifcation has to <= deadline to be timely. 
--when auth_priority = 'Retrospective' and writtennotifdate < (case when convert(date, verbal_notification) <= convert(date, deadline) then dateadd(dd, 3, convert(date, deadline)) end) then 'timelyletter' -- if verbal is made on/before deadline, then written notification has to <= after add 3 days to deadline in order to be timely
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'Prospective Standard')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'Prospective Standard') and f.is_extension = 'Yes' then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) <= 72 and auth_priority = 'Prospective Expedited' and (f.is_extension = 'No' or f.is_extension is null) then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE))/24.0 <= 17 and auth_priority  = 'Prospective Expedited' and f.is_extension = 'Yes' then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 15 and (auth_priority = 'Concurrent Standard')  then 'TimelyLetter'
when datediff(dd,convert(date,[Received_date]),convert(date,CORRECT_LETTER_dATE)) < 29 and (auth_priority = 'Concurrent Standard') and f.is_extension = 'Yes' then 'TimelyLetter'
when datediff(dd,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) < 15 and auth_priority = 'Concurrent Expedited' and (f.is_extension = 'No' or f.is_extension is null) then 'TimelyLetter'
when datediff(dd,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) < 29  and auth_priority  = 'Concurrent Expedited' and f.is_extension = 'Yes' then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) <= 24  and auth_priority = 'Part B Med Expedited'  then 'TimelyLetter'
when datediff(hour,[Received_date],convert(datetime,CORRECT_LETTER_dATE)) <= 72  and auth_priority  = 'Part B Med Standard' then 'TimelyLetter'
else 'UntimelyLetter' 
end
, ReceivedMonth	
--, [Start date is prior to request date]
--, [End date is prior to request date]
, [MultipleTeams]
,case when CORRECT_LETTER_dATE is null then 'NoLetter' else 'Letter' end 
--,case when WrittenNotifDate is null then 1000 else datediff(d,f.Received_Date,WrittenNotifDate) end
,CMO, CMO_Group, DUal
--,datediff(hour,f.[Received_date],convert(datetime,WrittenNotifDate))/24.0 
order by auth_id


-- select * from #report where auth_id in ('0319T4AF6','0405F1F8F')
-- select count(*) from #report --408301
--select top 1000 * from #report2 --where auth_id = '0115TF50E'

----------------- following part is to fix the writtennotifdate for approved, should be the earlier approved letter date after decision, not the denial letter date

IF OBJECT_ID('tempdb..#fix_appr_let_date') IS NOT NULL DROP TABLE #fix_appr_let_date;
; with base as
(
	select a.document_ref_id
	from 
	(
		select distinct document_ref_id
		from #letters_v2
		where type = 'Approved'
	)a
	join
	(
		select distinct document_ref_id
		from #letters_v2
		where type = 'Denied'
	)d 
	on a.document_ref_id = d.document_ref_id
)
, b2 as
(
	select b.*, F3.*
	from #final3 f3
	join base b
	on f3.auth_no = b.document_ref_id
	where [Overall Decision] = 'Approved'
	--order by f3.auth_id
)--select * from b2
select b2.*
into #fix_appr_let_date
from b2
join 
(
	select auth_id, min(letter_order) as letter_order 
	from b2
	where let_letter_type = 'approved'
	--and auth_id in ('0110TDD73')
	group by auth_id
	--order by 4
)app_min_let
on b2.auth_id = app_min_let.auth_id and b2.letter_order = app_min_let.letter_order
order by 1

begin tran
update #report
set #report.writtennotifdate = #fix_appr_let_date.correct_letter_date
from #report 
join #fix_appr_let_date
on #report.auth_id = #fix_appr_let_date.auth_id
--
commit tran

-----------------  fix done

begin tran
update #report
set WrittenNotifDate ='2019-01-17 16:00:00'
from #report
where auth_id='0115TF50E'
commit tran


-- select * from #report where auth_id in ('0111SB581',
--'0111SCD71',
--'0113M92FF',
--'0114M3515',
--'0114M77DF',
--'0114TF966',
--'0115WE337',
--'0115WFDD6',
--'0116T1072',
--'0116TC55D'
--)

IF OBJECT_ID('tempdb..#report2') IS NOT NULL DROP TABLE #report2;

select -- plan, category, month, year
left(plan_name,3)+(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
when  auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
when category ='Home Health' then 'Homecare'
when Category = 'DME' then 'DME'
when category = 'procedures' then 'Procedures'
when category = 'PCA' then 'PCA'
when auth_type_name = 'HCBS' then 'LTSS'
when auth_type_name = 'Transportation' then 'Transportation'
else 'Procedures' end)+cast(month(receivedmonth) as varchar(2))+cast(year(receivedmonth) as varchar(4)) as PCMY_Index,

-- plan, category, month, year, decision
left(plan_name,3)+(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
when  auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
when category ='Home Health' then 'Homecare'
when Category = 'DME' then 'DME'
when category = 'procedures' then 'Procedures'
when category = 'PCA' then 'PCA'
when auth_type_name = 'HCBS' then 'LTSS'
when auth_type_name = 'Transportation' then 'Transportation'
else 'Procedures' end)+cast(month(receivedmonth) as varchar(2))+cast(year(receivedmonth) as varchar(4))+[overall decision] as PCMYD_Index,

-- plan, category, month, year, decision, timely
left(plan_name,3)+(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
when auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
when category ='Home Health' then 'Homecare'
when Category = 'DME' then 'DME'
when category = 'procedures' then 'Procedures'
when category = 'PCA' then 'PCA'
when auth_type_name = 'HCBS' then 'LTSS'
when auth_type_name = 'Transportation' then 'Transportation'
else 'Procedures' end)+cast(month(receivedmonth) as varchar(2))+cast(year(receivedmonth) as varchar(4))+[overall decision]+LetterFlag as PCMYDF_Index,

-- plan, category, year
left(plan_name,3)+(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
when auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
when category ='Home Health' then 'Homecare'
when Category = 'DME' then 'DME'
when category = 'procedures' then 'Procedures'
when category = 'PCA' then 'PCA'
when auth_type_name = 'HCBS' then 'LTSS'
when auth_type_name = 'Transportation' then 'Transportation'
else 'Procedures' end)+cast(year(receivedmonth) as varchar(4)) as PCY_Index,

-- plan, category, decision
left(plan_name,3)+(case when([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
when auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
when category ='Home Health' then 'Homecare'
when Category = 'DME' then 'DME'
when category = 'procedures' then 'Procedures'
when category = 'PCA' then 'PCA'
when auth_type_name = 'HCBS' then 'LTSS'
when auth_type_name = 'Transportation' then 'Transportation'
else 'Procedures' end)+[overall decision] as PCD_Index,

-- category, month, year
(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
when auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
when category ='Home Health' then 'Homecare'
when Category = 'DME' then 'DME'
when category = 'procedures' then 'Procedures'
when category = 'PCA' then 'PCA'
when auth_type_name = 'HCBS' then 'LTSS'
when auth_type_name = 'Transportation' then 'Transportation'
else 'Procedures' end)+cast(month(receivedmonth) as varchar(2))+cast(year(receivedmonth) as varchar(4)) as CMY_index,

-- category, year
(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
when auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
when category ='Home Health' then 'Homecare'
when Category = 'DME' then 'DME'
when category = 'procedures' then 'Procedures'
when category = 'PCA' then 'PCA'
when auth_type_name = 'HCBS' then 'LTSS'
when auth_type_name = 'Transportation' then 'Transportation'
else 'Procedures' end)+cast(year(receivedmonth) as varchar(4)) as CY_index,

left(plan_name,3) as Product,
category as cat,
auth_type_name, count(auth_id) as Auths,--convert(varchar(10),ReceivedMonth,101) as RecMonth, --LetterFlag as decisionflag, --[overall decision],

--- *** MEP changed this Managed logic to Managed2 (derived earlier from MEH) in order to correct plan_name-derived Managed because it does not have hsitory like MEH
Managed2 as Managed
,auth_priority
--,case when auth_priority like 'Part B%' then 'Expedited' -- Amelia asked to put all Part B in Expedited (her document #7)
,case when auth_priority like '%standard%' or auth_priority  like '%concurrent%' then 'Standard'
when auth_priority like '%exped%' then 'Expedited' 
when auth_priority like '%retro%' then 'Standard'  else 'Other' end as Timeframe
,TATDenominator
,CCAID,	plan_name,	AUTH_ID,	created_on, auth_status, Received_Date,	[Service Code(s)],	[Service Description(s)],	[auth_priority] as authpriority,
IS_extension,	[Overall Decision] as OverallDecision,	Decision_Date,	Verbal_Notification,	WrittenNotifDate,	auth_type_name as authtypename,	deadline,	Adjusted_AdjustedCheck,	min_SERVICE_FROM_DATE,	max_SERVICE_to_DATE,
r.auth_no,	CATEGORY as authcategory,	DecisionFlag as DecisionTimelinessFlag,	LetterFlag,	--ReceivedMonth,	
MultipleTeams,	pos,	TATDenominator as TAT_denominator,	
case when auth_priority in ('Part B Med Expedited','Concurrent Expedited','Prospective Expedited') then cast(datediff(hour,r.[Received_date],convert(datetime,WrittenNotifDate)) as varchar) + ' hours' 
when auth_priority in ('Part B Med Standard') then cast(CAST((DATEDIFF(s,r.[Received_date],WrittenNotifDate) / 86400.0) AS DECIMAL(6,1)) as varchar)   + ' day'
else 
--	case when auth_priority not in ('Concurrent Expedited','Prospective Expedited','Part B Med Expedited','Part B Med Standard') /* and datediff(day,f.[Received_date],CORRECT_LETTER_dATE) >= 3 */ then 
cast(datediff(day,r.[Received_date],WrittenNotifDate) as varchar) + ' day'
	--when auth_priority not in ('Concurrent Expedited','Prospective Expedited','Part B Med Expedited','Part B Med Standard') and datediff(day,f.[Received_date],CORRECT_LETTER_dATE) < 3 then cast(datediff(hour,f.[Received_date],convert(datetime,CORRECT_LETTER_dATE))/24.0 as varchar) + ' hour'
--	end
end as TAT 
, CMO, 
cast(month(received_date) as varchar) + '/' + cast(year(received_date)as varchar) as 'Received_month',
cast(month(Decision_Date) as varchar) + '/' + cast(year(Decision_Date)as varchar) as 'Decision_month',
cast(month(created_on) as varchar) + '/' + cast(year(created_on)as varchar) as 'Created_month'
, case when uden.document_ref_id is null then 'No' else 'Yes' end as 'Denial Letter History' -- added per Kate's request
into #report2	 
 FROM #report r
		     left join (
	
--	 select document_ref_id as auth_no
--	  from
-- Altruista.dbo.um_document u 
--	   where (document_name like '%reconsideration%' 
--	   or document_name like '%appeal%' 
--	   or document_name like '%overturn%' 
--	   or document_desc like '%appeal%')
--	   and u.deleted_on is null
--	   --and document_ref_id = '290961'
--	 group by document_ref_id
--	   union
--	   select auth_no from #step where  [Auth owner] like '%Tierney%Joseph%' or  [Auth owner]  like '%Rivera%Yesenia%' or
--	   [AuthCreatedBy] like '%Tierney%Joseph%' or   [AuthCreatedBy] like '%Rivera%Yesenia%' 
---- select distinct [AuthCreatedBy] from #step where [AuthCreatedBy] like '%karen%'
---- select distinct [Auth owner] from #step where [Auth owner] like '%karen%'

--	   group by auth_no

		SELECT [NOTE_REF_ID] as auth_no
		FROM [Altruista].[dbo].[UM_NOTE]
		WHERE DELETED_ON IS NULL 
		and note_type_id=2
		GROUP BY [NOTE_REF_ID]
		union
		select document_ref_id as auth_no
		from Altruista.dbo.um_document u 
		where u.deleted_on is null
		and (document_name like '%reconsideration%' or document_name like '%appeal%' or document_name like '%overturn%')
		group by document_ref_id
		union
		select auth_no 
		from #step 
		where  [Auth owner] like '%Tierney%Joseph%' or  [Auth owner]  like '%Rivera%Yesenia%' or [AuthCreatedBy] like '%Tierney%Joseph%' or   [AuthCreatedBy] like '%Rivera%Yesenia%' 
		group by auth_no
	   
	 ) appch on r.auth_no=appch.auth_no
	left join 
	(
		select document_ref_id from Altruista.dbo.um_document 
		where ((document_name like '%denial%' and  document_type_id in (1,2)) or  document_type_id=6) 
		and DELETED_ON is null
		group by document_ref_id
	)uden on r.auth_no=uden.document_Ref_id
WHERE category  <> 'No AUth Required'
and plan_name not in ('UD') -- exclude test account
and r.auth_id not in 
('0528TE958',---remove via Amelia communication on June 10, 2019
'0513MBBFD',
'0510F3254',
'0508W15EF',
'0507TAD0E',
'0503FCE8B',
'0503F3546',
'0531FB43F',
'0528T474B',
'0521TD235',
'0521T4B30',
'0520MCB59',
'0515W5E21',
'0515W34DB',
'0507TAB18',
'0507T7FCF',
'0501WC1F9',
'0503F3546',
'0507T51BA',
'0503F3546',
'0502T29E3',
'0604T342A',
'0723T30B3',
'0715M73E8',
'0723TD8E7',
'0814W3262'

)
and appch.auth_no is null---exclude potential appeals
		  --and receivedmonth between @StartDate and @EndDate
		  --and receivedmonth<='2019-03-31'
		  		  group by  
				   left(plan_name,3)+(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
		when  auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
		 when category ='Home Health' then 'Homecare'
		 when Category = 'DME' then 'DME'
		 when category = 'procedures' then 'Procedures'
		 when category = 'PCA' then 'PCA'
	when auth_type_name = 'HCBS' then 'LTSS'
		when auth_type_name = 'Transportation' then 'Transportation'
		 else 'Procedures' end)+cast(month(receivedmonth) as varchar(2))+cast(year(receivedmonth) as varchar(4)) ,

		 -- plan, category, month, year, decision
		  left(plan_name,3)+(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
		when  auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
		 when category ='Home Health' then 'Homecare'
		 when Category = 'DME' then 'DME'
		 when category = 'procedures' then 'Procedures'
		 when category = 'PCA' then 'PCA'
	when auth_type_name = 'HCBS' then 'LTSS'
			when auth_type_name = 'Transportation' then 'Transportation'
		 else 'Procedures' end)+cast(month(receivedmonth) as varchar(2))+cast(year(receivedmonth) as varchar(4))+[overall decision] ,


		 -- plan, category, month, year, decision, timely
		  left(plan_name,3)+(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
		when  auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
		 when category ='Home Health' then 'Homecare'
		 when Category = 'DME' then 'DME'
		 when category = 'procedures' then 'Procedures'
		 when category = 'PCA' then 'PCA'
	when auth_type_name = 'HCBS' then 'LTSS'
			when auth_type_name = 'Transportation' then 'Transportation'
		 else 'Procedures' end)+cast(month(receivedmonth) as varchar(2))+cast(year(receivedmonth) as varchar(4))+[overall decision]+LetterFlag ,

	 -- plan, category, year
		 		  left(plan_name,3)+(case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
		when  auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
		 when category ='Home Health' then 'Homecare'
		 when Category = 'DME' then 'DME'
		 when category = 'procedures' then 'Procedures'
		 when category = 'PCA' then 'PCA'
	when auth_type_name = 'HCBS' then 'LTSS'
			when auth_type_name = 'Transportation' then 'Transportation'
		 else 'Procedures' end)+cast(year(receivedmonth) as varchar(4)) ,

	 -- plan, category, decision
		 	 left(plan_name,3)+(case when 	 	([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
		when 	 auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
		 when category ='Home Health' then 'Homecare'
		 when Category = 'DME' then 'DME'
		 when category = 'procedures' then 'Procedures'
		 when category = 'PCA' then 'PCA'
	when auth_type_name = 'HCBS' then 'LTSS'
			when auth_type_name = 'Transportation' then 'Transportation'
		 else 'Procedures' end)+[overall decision] ,


	 -- category, month, year
		 		 		  (case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
		when  auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
		 when category ='Home Health' then 'Homecare'
		 when Category = 'DME' then 'DME'
		 when category = 'procedures' then 'Procedures'
		 when category = 'PCA' then 'PCA'
	when auth_type_name = 'HCBS' then 'LTSS'
			when auth_type_name = 'Transportation' then 'Transportation'
		 else 'Procedures' end)+cast(month(receivedmonth) as varchar(2))+cast(year(receivedmonth) as varchar(4)) ,

	 -- category, year
	--	 (case when ([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
	--	when  auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
	--	 when category ='Home Health' then 'Homecare'
	--	 when Category = 'DME' then 'DME'
	--	 when category = 'procedures' then 'Procedures'
	--	 when category = 'PCA' then 'PCA'
	--when auth_type_name = 'HCBS' then 'LTSS'
	--		when auth_type_name = 'Transportation' then 'Transportation'
	--	 else 'Procedures' end)+cast(year(receivedmonth) as varchar(4)) ,



		  left(plan_name,3) ,
		 case when
		([Service Code(s)] like '%0120%' or [Service Code(s)] like '%0191%') and POS = '31' then 'SNF'
		when   auth_type_name = 'Inpatient' and category = 'TOC' then 'Acute Inpatient'
		 when category ='Home Health' then 'Homecare'
		 when Category = 'DME' then 'DME'
		 when category = 'procedures' then 'Procedures'
		 when category = 'PCA' then 'PCA'
	when auth_type_name = 'HCBS' then 'LTSS'
			when auth_type_name = 'Transportation' then 'Transportation'
		 else 'Procedures' end ,

		 auth_type_name, category,convert(varchar(10),ReceivedMonth,101) ,LetterFlag , [overall decision]

	--	 ,case when plan_name in ('SCO-Externally Managed','SCO MassHealth Only-Externally Managed')
 --then 'Externally Managed' else 
	--		-- SUBSTRING(plan_name, CHARINDEX('-', plan_name) + 1, LEN(plan_name)) 
	--		'CCA Managed' end 

		 ,auth_priority
		 --,case when auth_priority like 'Part B%' then 'Expedited' -- Amelia asked to put all Part B in Expedited (her document #7)
		 ,case when auth_priority like '%standard%' or auth_priority  like '%concurrent%' then 'Standard'
		 when auth_priority like '%exped%' then 'Expedited' 
		  when auth_priority like '%retro%' then 'Standard'  else 'Other' end 
		 ,TATDenominator
		 	,CCAID,	plan_name,	AUTH_ID,	created_on, auth_status, Received_Date,	[Service Code(s)],	[Service Description(s)],	[auth_priority],
		IS_extension,	[Overall Decision],	Decision_Date,	Verbal_Notification,	WrittenNotifDate,	auth_type_name,	deadline,	Adjusted_AdjustedCheck,	min_SERVICE_FROM_DATE,	max_SERVICE_to_DATE,
			r.auth_no,	CATEGORY,	DecisionFlag,	LetterFlag,	ReceivedMonth,	MultipleTeams,	pos,	TATDenominator
,case when auth_priority in ('Concurrent Expedited','Prospective Expedited') then cast(datediff(hour,r.[Received_date],convert(datetime,WrittenNotifDate)) as varchar) + ' hours' 
when auth_priority in ('Part B Med Expedited','Part B Med Standard') then cast(CAST((DATEDIFF(s,r.[Received_date],WrittenNotifDate) / 86400.0) AS DECIMAL(6,1)) as varchar)   + ' day' 
else 
--	case when auth_priority not in ('Concurrent Expedited','Prospective Expedited','Part B Med Expedited','Part B Med Standard') /* and datediff(day,f.[Received_date],CORRECT_LETTER_dATE) >= 3 */ then 
cast(datediff(day,r.[Received_date],WrittenNotifDate) as varchar) + ' day'
end
,CMO
,Managed2, case when uden.document_ref_id is null then 'No' else 'Yes' end

-- select CAST(DATEDIFF(s,'Received Date’,’Written Notif Date’) / 86400.0) AS DECIMAL(6,1))  

-- remove note_type = appeal per Amelia/Kate
delete from #report2
where auth_id in 
(
	select distinct r2.auth_id--, un.[NOTE_REF_ID]
	from #report2 r2
	join [Altruista].[dbo].[UM_NOTE] un
	on r2.auth_no = un.[NOTE_REF_ID]
	where un.note_type_id = 2
	and un.deleted_on is null
	--and r2.auth_id in ('0113M92FF','0204TFFED','0211T6AC6','0305TF20E','0912T2681','1202M362B')
)

-- remove Transportation effective 1/1/2020 
delete from #report2
where cat = 'Transportation'
and received_date >= '2020-01-01'

-- update to the latest cmo if the cmo wasn't assigned at the time of the auth for all the Externally Managed members
begin tran
update r2
set cmo = temp.cmo_name
from #report2 r2
join
(
	select cmo_name, aa.*
	from 
	medical_analytics.dbo.member_enrollment_MP mp
	join 
	(
		select ccaid, --enroll_mm, 
		max(member_month) as member_month
		from medical_analytics.dbo.member_enrollment_MP
		where ccaid in 
		(
			select distinct ccaid
			from #report2
			where managed = 'Externally Managed'
			and cmo is null
		)
		and cmo_name is not null
		group by ccaid
		--order by enroll_mm desc
	)aa
	on mp.ccaid = aa.ccaid and mp.member_month = aa.member_month
)temp
on r2.ccaid = temp.ccaid
where r2.managed = 'Externally Managed'
and r2.cmo is null

commit tran

-- update to 'CCA Managed' for the ones that ccaid is not in MP or they belonged to CCAEast / CCCBoston and they originally 'Externally Managed'

begin tran
update #report2
set managed = 'CCA Managed'
where managed = 'Externally Managed'
and (cmo is null or cmo in ('CCACG EAST','CCC-Boston'))

commit tran


--select top 1000 *
--from #report2

--select WrittenNotifDate, auth_id, * from #report2
--where auth_id in ('0319T4AF6','0405F1F8F','0606T801B','1126MA082')



--select top 1000 tat, *
--from #report2
--where auth_priority like 'Part B%'