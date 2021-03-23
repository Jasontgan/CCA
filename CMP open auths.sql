
IF OBJECT_ID('tempdb..#STEP1') IS NOT NULL DROP TABLE #STEP1;
select 
pd.[LAST_NAME] 
, pd.[FIRST_NAME]
, pd.[CLIENT_patient_ID] as CCAID
--,lan.LANGUAGE_NAME
, bp.plan_name 
, a.[AUTH_ID]
, a.AUTH_NOTI_DATE as Received_date
, ud.[SERVICE_FROM_DATE] AS [SERVICE_FROM_DATE]
, ud.[SERVICE_TO_DATE] AS [SERVICE_TO_DATE]
, coalesce (s.SERVICE_CODE, sv.proc_code)  as proc_code
, coalesce ( cat2.proc_category, cat.proc_category)  as TypeofCode
, coalesce (svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION) as proc_description
, ud.current_requested as UnitsRequested
, ud.current_approved  as UnitsApproved
, tat.auth_priority
, stat.auth_status
, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),usr.auth_status_reason_name),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  as 'auth_status_reason_name'
, case 
	when a.IS_EXTENsion = 1 then 'Yes'
	   else 'No' 
   end as 'IS_EXTENsion'
,  case when a.is_extension=0 or a.is_extension is null then 'NA'
WHEN  extdoc.document_ref_id is not null then 'Y' else 'N' end as 'Is there an Extension letter created'
, decs.decision_Status
, decstc.[DECISION_STATUS_CODE_DESC]
 
, case when act.[MD review Completed date] is not null then act.[MD review Completed date]
-----On November 27, 2018 Amelia Levy said to use the MD review completed date as the decision date for denials
else  ud.replied_date end as Decision_Date
--, case when decs.decision_status='pending' then 'NA' else  convert(varchar, udp.replied_date, 108) end as 'Time of sponsor decision',

--,Pac.AUTH_CODE_ID
--,l.lob_name ,l.lob_desc
--, a.[PATIENT_ID], a.[LOB_BEN_ID] -- not needed 
, case when decs.decision_status='denied'  and ud.MEMBER_NOTIFICATION_DATE is not null then 
convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 111)  else ' '
END
as 'Verbal Notification'
--, MaxLetterCreatedDate

,case when decs.decision_status='approved' then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
when decs.decision_status='partially approved'  and dendoc.created_on is not null  then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
when decs.decision_status='partially approved' then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
else convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
end as WrittenNotifDate
,at.auth_type_name

,pos.[PLACE_OF_SERVICE_CODE]

,pos.PLACE_OF_SERVICE_NAME
, pdv.LAST_NAME + CASE WHEN pdv.FIRST_NAME IS NOT NULL THEN ', ' + pdv.FIRST_NAME ELSE '' END CMO
,  cs.LAST_NAME + ',' + cs.First_NAME as 'Auth owner'
,byprov.provider_name as ReferredBy
,prov.provider_name as ReferredTo
, '' as 'Status (progress)'
, '' as 'Workqueue'
, 	   case when RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) in  ('90791','90837','90846','90867','90868','90869','90870','90899','96101','96102','96118','96119','H0040','H2012','H2015','T1004') 
         OR ( RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('0100','100') and [PLACE_OF_SERVICE_CODE] in ('51', '61') )
        then 'BH'
                  when  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('T1019', 'T2022') then 'PCA'
                  when  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) IN ('99456','H0043','H2014','S5100','S5101','S5102','S5110','S5111','S5120','S5121','S5125','S5130','S5131','S5135','S5140','S5170','S5175','S9451','T1022','T1023','T2020','T2021','T2031') THEN 'LTSS'
                 when  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('99601','99602','G0151','G0152','G0153','G0155','G0156','G0157','G0158','G0299','G0300','Q3014','S9129','T1000','T1002','T1003','T1030','T1031') then 'Home Health'
                  when RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('0100','100')  THEN 'TOC'
                 WHEN   RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('0120','0191','0192','11722','11723','11724','11725','11726','11727','11728','11729','11731','11733','11734','11735','11736','11737','11738','11739','11741','11742','11743',
                                                            '11744','11745','11746','11747','11748','11749','11751','11752','11753','11754','11756','11757','11758','11759','11761','11763','11764','97001','97039','97110','97116','97530') tHEN 'TOC'
                  when  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) in ('A5508', 'A5510','A6540','A6549','A8002','A8003','A8004','A9276','A9277','A9278','A9279','A9282','A9283','A9900','A9999','S5160','S5161','S5185','T2028','T5999')
                              or RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) like 'E%' 
                              or  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) like 'L%' 
                              or  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  like 'K%' 
                              or  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) like 'V%' THEN 'DME' 
                   when coalesce (svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION) like '%transport%' then 'Transporation'
				   ELSE 'Procedures'
            end as 'Team'
	,a.[AUTH_NO]
	, Note1
	, Note2
	, Note3
		,case when decs.decision_status='denied' 
or (decs.decision_status='adjusted' 
		and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then dendoc.created_on
when decs.decision_status='partially approved'  and dendoc.created_on is not null then dendoc.created_on
else approvdoc.created_on
 end as 'letter_created_on'
  ,
	case when decs.decision_status='denied' 
or (decs.decision_status='adjusted' 
		and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then dendoc.createdbyname
when decs.decision_status='partially approved'  and dendoc.created_on is not null then dendoc.createdbyname
else approvdoc.createdbyname
 end  as letter_created_by_name
   ,
	case when decs.decision_status='denied' 
or (decs.decision_status='adjusted' 
		and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then dendoc.printedon
when decs.decision_status='partially approved'  and dendoc.created_on is not null then dendoc.printedon
else approvdoc.LETTER_PRINTED_DATE
 end  as printedon
    ,
	case when decs.decision_status='denied' 
or (decs.decision_status='adjusted' 
		and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then qd.maxupdateddate
when decs.decision_status='partially approved'  and qd.auth_no is not null then qd.maxupdateddate
else qa.maxupdateddate
 end  as letterqueue_updatedate
 
   ,  authcr.LAST_NAME + ',' + authcr.First_NAME as 'AuthCreatedBy'
   , a.created_on as 'AuthCreatedDate'
 --,admit.provider_name as AdmittingProvider
  ,fac.provider_name as Facility
 --  ,servic.provider_name as ServicingProvider
 --  , urs.[REFERRAL_STATUS_NAME]
 --  , ad.dept_name
into #STEP1
from [Altruista].dbo.um_auth a
left join  [Altruista].[dbo].[patient_details] pd on a.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null
left join [Altruista].[dbo].[lob_benf_plan] lb on a.[LOB_BEN_ID] = lb.lob_ben_id and lb.deleted_on is null
left join  [Altruista].[dbo].[lob] l on lb.[LOB_ID] = l.lob_id and l.deleted_on is null
--left join [Altruista].[dbo].benefit_plan b on l.benefit_plan_id = b.benefit_plan_id
left join [Altruista].[dbo].UM_AUTH_PROVIDER prov on a.auth_no = prov.auth_no  and prov.provider_type_id = 3 and prov.deleted_on is null-- 3 means referred to-- needs another join
left join [Altruista].[dbo].UM_AUTH_PROVIDER byprov on a.auth_no = byprov.auth_no  and byprov.provider_type_id = 2 and byprov.deleted_on is null-- 2 means referred by-- needs another join
left join [Altruista].[dbo].UM_AUTH_PROVIDER admit on a.auth_no = admit.auth_no  and admit.provider_type_id = 1 and admit.deleted_on is null-- 1 means admitting provider-- needs another join
left join [Altruista].[dbo].UM_AUTH_PROVIDER fac on a.auth_no = fac.auth_no  and fac.provider_type_id = 4 and fac.deleted_on is null-- 4 means facility
left join [Altruista].[dbo].UM_AUTH_PROVIDER servic on a.auth_no = servic.auth_no  and servic.provider_type_id = 5 and servic.deleted_on is null--5 means service
--left join [Altruista].[dbo].[PROVIDER_NETWORK] pn on pn.[PROVIDER_ID] = prov.auth_no
left join [Altruista].[dbo].UM_AUTH_CODE Pac on  a.auth_no  = Pac.auth_no and AUTH_CODE_TYPE_ID in ( 1,5) and pac.deleted_on is null-- splits the auth into auth lines
left join  [Altruista].[dbo].UM_DECISION ud on  a.auth_no  = ud.auth_no and Pac.auth_code_id = ud.auth_code_id and ud.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS decs on ud.DECISION_status = decs.DECISION_STATUS_ID and decs.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS_codes decstc on ud.DECISION_status_code_id = decstc.DECISION_STATUS_code_ID and decstc.deleted_on is null
LEFT JOIN [Altruista].[dbo].[benefit_plan] bp ON lb.[BENEFIT_PLAN_ID] = bp.[BENEFIT_PLAN_ID] and bp.deleted_on is null
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
      ( select
	   a.document_ref_id, max(b.letter_printed_date) as letter_printed_date, a.created_on
	   from
	   (select document_ref_id, max(created_on) as created_on from Altruista.dbo.um_document  where document_name like '%approv%' 
       and DELETED_ON is null 
       group by document_ref_id)a
	   inner join  Altruista.dbo.um_document b on a.document_ref_id=b.document_ref_id and b.deleted_on is null and cast(a.created_on as date)=cast(b.created_on as date)
	   group by  a.document_ref_id, a.created_on)c
	    inner join  Altruista.dbo.um_document d on c.document_ref_id=d.document_ref_id and d.deleted_on is null and c.created_on=d.created_on
			left join  [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on d.created_by=cs.member_id
			--where c.document_ref_id='5947'
		--group by  c.document_ref_id, c.letter_printed_date, c.created_on, d.created_by,  cs.last_name+ ',' + cs.first_name

) approvdoc on a.auth_no=approvdoc.document_ref_id 
LEFT JOIN 
(
        select  a.document_ref_id, a.[letter date], b.created_on, b.created_by, cs.last_name+ ',' + cs.first_name as createdbyname, letter_printed_date as printedon
		from
	   (select document_ref_id
	   --, max(created_on) as 'created_on' 
       --, cast (created_on as time)  as 'Time'
       , case when cast (max(created_on) as time) < '16:00:00'
       then  max(created_on)  else  dateadd (dd,1,max(created_on) ) 
       end as 'Letter Date'
	   ,  max(created_on) as maxcreatedon
       from Altruista.dbo.um_document
       where document_desc like '%denial%'---use document desc cause the fax names also have denial in it
       and DELETED_ON is null
	 
       group by document_ref_id)a
	    inner join  Altruista.dbo.um_document b on a.document_ref_id=b.document_ref_id and b.deleted_on is null and a. maxcreatedon=b.created_on
		left join  [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on b.created_by=cs.member_id
		group by   a.document_ref_id, a.[letter date], b.created_on, b.created_by, cs.last_name+ ',' + cs.first_name ,  letter_printed_date
      
) dendoc on a.auth_no=dendoc.document_ref_id 
left join  [Altruista].[dbo].UM_MA_PROCEDURE_CODES sv on Pac.auth_code_ref_id = sv.PROC_CODE and sv.PROC_CATEGORY_ID in (1,2, 3,7) and sv.deleted_on is null -- hcpcs, cpt, revcode or ICD10Proc

-- now join again to the sercice code table to get the items that are not being coded correctly as ProcCode

left join [Altruista].[dbo].[SERVICE_CODE] s on pac.[AUTH_CODE_REF_ID]=cast (s.SERVICE_ID as varchar) and pac.[AUTH_CODE_type_ID]=5 and s.deleted_on is null
left join  [Altruista].[dbo].UM_MA_PROCEDURE_CODES svc on  s.service_code = svc.proc_code  and svc.deleted_on is null-- hcpcs, cpt, revcode or ICD10Proc---this is to hget the description for the special service category codes
--left join [Altruista].[dbo].UM_MA_PROCEDURE_CODES sv2 on Pac.auth_code_ref_id = sv2.PROC_CODE and sv2.PROC_CATEGORY_ID in (1,2, 3,7) -- hcpcs, cpt, revcode or ICD10Proc
left join  [Altruista].[dbo].[UM_MA_PROCEDURE_CODE_CATEGORY] cat on sv.PROC_CATEGORY_ID= cat.PROC_CATEGORY_ID and cat.deleted_on is null
left join  [Altruista].[dbo].[UM_MA_PROCEDURE_CODE_CATEGORY] cat2 on svc.PROC_CATEGORY_ID= cat2.PROC_CATEGORY_ID and cat2.deleted_on is null
left join [Altruista].[dbo].[UM_MA_AUTH_STATUS] stat on a.AUTH_STATUS_ID = stat.AUTH_STATUS_ID and stat.deleted_on is null
left join [Altruista].[dbo].[LANGUAGE] lan on pd.PRIMARY_LANGUAGE_ID = lan.language_id and lan.deleted_on is null
left join [Altruista].[dbo].[UM_MA_AUTH_STATUS_reason] usr on a.[AUTH_STATUS_reason_ID]=usr.[AUTH_STATUS_reason_ID] and usr.deleted_on is null
left JOIN [Altruista].dbo.PATIENT_PHYSICIAN pp ON pd.PATIENT_ID = pp.PATIENT_ID AND  CARE_TEAM_ID IN (1,2) AND pp.PROVIDER_TYPE_ID = 181 AND -- cmo
CAST(GETDATE() AS DATE) BETWEEN pp.[START_DATE] and pp.END_DATE and
                    pp.DELETED_ON IS NULL AND
                    pp.IS_ACTIVE = 1
LEFT JOIN [Altruista].dbo.PHYSICIAN_DEMOGRAPHY pdv ON pp.physician_id = pdv.physician_id 
left join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on a.AUTH_CUR_OWNER=cs.member_id
left join (SELECT
      [ACTIVITY_LOG_REF_ID],
       [ACTIVITY_LOG_DESC],
	   max ([activity_log_followup_date]) as 'MD review Completed date'
  FROM  [Altruista].[dbo].[UM_ACTIVITY_LOG]-- this table documents all the activities on the auth
  where   [ACTIVITY_LOG_DESC]='MD Review Completed'

  and deleted_on is null
  group by
  [ACTIVITY_LOG_REF_ID],
       [ACTIVITY_LOG_DESC])act on a.auth_no=act.activity_log_ref_id

	   LEFT JOIN (select document_ref_id from Altruista.dbo.um_document  where document_name like '%extensi%' and deleted_on is null group by document_ref_id ) extdoc on a.auth_no=extdoc.document_ref_id ---looks for ex

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

left join 

(select [AUTH_NO], max([UPDATED_ON]) as maxupdateddate from [Altruista].[dbo].[LETTER_QUEUE]
where [PRINT_STATUS]=1 and deleted_on is null and template_content like '%approv%'
group by [AUTH_NO]) qa on a.auth_no=qa.auth_no
left join 

(select [AUTH_NO], max([UPDATED_ON]) as maxupdateddate from [Altruista].[dbo].[LETTER_QUEUE]
where [PRINT_STATUS]=1 and deleted_on is null and template_content like '%denia%'
group by [AUTH_NO]) qd on a.auth_no=qd.auth_no

left join [Altruista].[dbo].[CARE_STAFF_DETAILS] authcr on a.CREATED_BY=authcr.member_id

where 
--LOB_name = 'Medicare-Medicaid Duals' and 
--pd.last_name not like '%test%'
pd.client_patient_id like '53%'
--and decs.decision_Status in ('approved')
--and auth_priority in ('Prospective Standard','Prospective Expedited')
and auth_status in ('close','closed and adjusted','open','reopen', 'reopen and close', 'referral only', 'withdrawn', 'closed-reporting only')--Sara confirmed these statuses with Amelia on November 29. 2018
--and auth_status not like '%cancel%'
and (decs.DECISION_STATUS <> 'Void' or decs.decision_status is null)
--and
--a.auth_id = '1114W89C8'
and a.deleted_on is null  --  excludes deleted auths
--and doc.MaxLetterDate is null  -- excludes any that already has a letter
group by
pd.[LAST_NAME] 
,pd.[FIRST_NAME]
,pd.[CLIENT_patient_ID] 
--,lan.LANGUAGE_NAME
, bp.plan_name 
,a.[AUTH_ID]
,a.AUTH_NOTI_DATE 
--, convert(varchar, a.AUTH_NOTI_DATE, 108) as 'Time the request was received'
,ud.[SERVICE_FROM_DATE] 
, ud.[SERVICE_TO_DATE] 
, coalesce ( s.SERVICE_CODE, sv.proc_code)  
, coalesce ( cat2.proc_category, cat.proc_category) 
,coalesce (svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION) 
, current_requested 
, current_approved 
,auth_priority
 , auth_status
, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),auth_status_reason_name),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  

	   ,case when a.IS_EXTENsion = 1 then 'Yes'
	   else 'No' end 
	  ,  case when a.is_extension=0 or a.is_extension is null then 'NA'
WHEN  extdoc.document_ref_id is not null then 'Y' else 'N' end
	   ,decs.decision_Status
 ,[DECISION_STATUS_CODE_DESC]
 
 
, case when act.[MD review Completed date] is not null then act.[MD review Completed date]

else  ud.replied_date end 

, case when decs.decision_status='denied'  and ud.MEMBER_NOTIFICATION_DATE is not null then 
convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 111)  else ' '
END
,case when decs.decision_status='approved' then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
when decs.decision_status='denied' or (decs.decision_status='adjusted' and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
when decs.decision_status='partially approved'  and dendoc.created_on is not null  then convert(varchar, dendoc.[letter date] , 111) + ' 16:00:00'
when decs.decision_status='partially approved' then convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
else convert (varchar, approvdoc.LETTER_PRINTED_DATE, 111) + ' 19:00:00'
end 
,auth_type_name
,[PLACE_OF_SERVICE_CODE]
,PLACE_OF_SERVICE_NAME
, pdv.LAST_NAME + CASE WHEN pdv.FIRST_NAME IS NOT NULL THEN ', ' + pdv.FIRST_NAME ELSE '' END 
,  cs.LAST_NAME + ',' + cs.First_NAME 
,byprov.provider_name 
,prov.provider_name 
 , case when RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) in  ('90791','90837','90846','90867','90868','90869','90870','90899','96101','96102','96118','96119','H0040','H2012','H2015','T1004') 
         OR ( RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('0100','100') and [PLACE_OF_SERVICE_CODE] in ('51', '61') )
        then 'BH'
                  when  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('T1019', 'T2022') then 'PCA'
                  when  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) IN ('99456','H0043','H2014','S5100','S5101','S5102','S5110','S5111','S5120','S5121','S5125','S5130','S5131','S5135','S5140','S5170','S5175','S9451','T1022','T1023','T2020','T2021','T2031') THEN 'LTSS'
                 when  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('99601','99602','G0151','G0152','G0153','G0155','G0156','G0157','G0158','G0299','G0300','Q3014','S9129','T1000','T1002','T1003','T1030','T1031') then 'Home Health'
                  when RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('0100','100')  THEN 'TOC'
                 WHEN   RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  IN ('0120','0191','0192','11722','11723','11724','11725','11726','11727','11728','11729','11731','11733','11734','11735','11736','11737','11738','11739','11741','11742','11743',
                                                            '11744','11745','11746','11747','11748','11749','11751','11752','11753','11754','11756','11757','11758','11759','11761','11763','11764','97001','97039','97110','97116','97530') tHEN 'TOC'
                  when  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) in ('A5508', 'A5510','A6540','A6549','A8002','A8003','A8004','A9276','A9277','A9278','A9279','A9282','A9283','A9900','A9999','S5160','S5161','S5185','T2028','T5999')
                              or RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) like 'E%' 
                              or  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) like 'L%' 
                              or  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) )  like 'K%' 
                              or  RTRIM(LTRIM( coalesce ( s.SERVICE_CODE, sv.proc_code)) ) like 'V%' THEN 'DME' 
                   when coalesce (svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION) like '%transport%' then 'Transporation'
				   ELSE 'Procedures'
            end
	,a.[AUTH_NO]
	, Note1
	, Note2
	, Note3
		,case when decs.decision_status='denied' 
or (decs.decision_status='adjusted' 
		and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then dendoc.created_on
when decs.decision_status='partially approved'  and dendoc.created_on is not null then dendoc.created_on
else approvdoc.created_on
 end 
  ,
	case when decs.decision_status='denied' 
or (decs.decision_status='adjusted' 
		and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then dendoc.createdbyname
when decs.decision_status='partially approved'  and dendoc.created_on is not null then dendoc.createdbyname
else approvdoc.createdbyname
 end  
   ,
	case when decs.decision_status='denied' 
or (decs.decision_status='adjusted' 
		and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then dendoc.printedon
when decs.decision_status='partially approved'  and dendoc.created_on is not null then dendoc.printedon
else approvdoc.LETTER_PRINTED_DATE
 end  
    ,
	case when decs.decision_status='denied' 
or (decs.decision_status='adjusted' 
		and ( decstc.DECISION_STATUS_CODE_DESC  like '%reduction%' or  decstc.DECISION_STATUS_CODE_DESC  like '%termination%') )
then qd.maxupdateddate
when decs.decision_status='partially approved'  and qd.auth_no is not null then qd.maxupdateddate
else qa.maxupdateddate
 end 
  --,admit.provider_name 
  ,fac.provider_name 
  -- ,servic.provider_name
    ,  authcr.LAST_NAME + ',' + authcr.First_NAME 
   , a.created_on
   --   , urs.[REFERRAL_STATUS_NAME]
   --, ad.dept_name
   
IF OBJECT_ID('tempdb..#STEP2') IS NOT NULL DROP TABLE #STEP2;
SELECT 

 [LAST_NAME]
      ,[FIRST_NAME]
      ,[CCAID]
      ,plan_name 
      ,[AUTH_ID]
	  ,[Received_date] as 'Received Date'
     ,[SERVICE_FROM_DATE]
      ,[SERVICE_TO_DATE]
    ,[proc_code]
	  ,typeofcode
      ,[proc_description]
      ,[UnitsRequested]
      ,[UnitsApproved]
      ,[auth_priority]
      ,[auth_status]
      ,[auth_status_reason_name]
      ,[IS_extension]
	  ,[Is there an Extension letter created]
      ,[decision_Status]
      ,[DECISION_STATUS_CODE_DESC]
	  ,[Decision_Date] as 'Decision Date'
      ,[Verbal Notification]
      ,[WrittenNotifDate]
      ,[auth_type_name]
      ,[PLACE_OF_SERVICE_CODE]
      ,[PLACE_OF_SERVICE_NAME]
      ,[CMO]
      ,[Auth owner]
      ,[ReferredBy]
      ,[ReferredTo]
      ,[Status (progress)]
      ,[Workqueue]
      , [Team] 
	  , CASE WHEN  DECISION_DATE is not null then 'NA'
		when [Received_date]is null then 'NA'
		when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN cast (datediff (dd,getdate(),dateadd (dd, 28, [Received_date] )) as varchar)
		WHEN auth_priority = 'Prospective Standard'  THEN  cast (datediff (dd,getdate(),dateadd (dd, 14,[Received_date]) ) as varchar)
		when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN  cast(datediff (dd,getdate(),dateadd (dd, 16,[Received_date]) )as varchar)
			when auth_priority = 'Prospective Expedited'  THEN  cast(datediff (dd,getdate(),dateadd (dd, 3, [Received_date]) )as varchar)
			WHEN auth_priority = 'Retrospective'  THEN  cast (datediff (dd,getdate(),dateadd (dd, 14, [Received_date]) ) as varchar)
		else cast (0 as varchar) end as 'Days to Process Auth' 
, CASE WHEN 
		received_date is null then 0
		when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN dateadd (dd, 28, received_date)
		WHEN auth_priority = 'Prospective Standard'  THEN dateadd (dd, 14,received_date)
		when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 17, received_date)
		when auth_priority = 'Prospective Expedited'  THEN dateadd (dd,3,received_date)
		WHEN auth_priority = 'Retrospective'  THEN dateadd (dd, 14,received_date)
		else 0 end as deadline
 , case  when auth_priority like '%concurrent%'  then 'NA'
	  when DECISION_DATE is null then 'NoDecision'
	  when received_date is null  then 'NA'
	  --when ud.replied_date = '1900-01-01' then 'NoDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 0 then 'UntimelyDecision'  
	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%retro%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%retro%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%standard%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%standard%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 4 and auth_priority like  '%Expedited%' and (is_extension ='No' or is_extension is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 18 and auth_priority like  '%Expedited%' and is_extension ='Yes' then 'TimelyDecision'
	  else 'UntimelyDecision' 
   end as 'DecisionFlag' 	  
, case 
when auth_priority like '%concurrent%'  then 'NA'
when [WrittenNotifDate] is null then 'NoLetter'
  when received_date is null then 'NA'	
	when convert(date,[WrittenNotifDate]) = '1900-01-01' then 'NoLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 0 then 'UntimelyLetter' 
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'retrospective')  then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'retrospective') and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'Prospective Standard')  then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'Prospective Standard') and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 4 and auth_priority = 'Prospective Expedited' and (is_extension = 'No' or is_extension is null) then 'TimelyLetter'
    when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 18 and auth_priority  = 'Prospective Expedited' and is_extension = 'Yes' then 'TimelyLetter'
	else 'UntimelyLetter' 
end as 'LetterFlag'
      ,[AUTH_NO]	  	
, CASE when [Received_date] is null then 'Yes' ELSE 'No' end as 'No Receipt Date'
	,letter_created_on
  , letter_created_by_name
    , printedon,letterqueue_updatedate
, Note1
	, Note2
	, Note3
	 , AuthCreatedBy
   , AuthCreatedDate
	 --,AdmittingProvider
  ,Facility
  -- , ServicingProvider
	 ----, convert(date,[WrittenNotifDate])
	 --   , [REFERRAL_STATUS_NAME]
  -- , dept_name
	 into #step2
	  FROM #STEP1 S
	  GROUP BY [LAST_NAME]
      ,[FIRST_NAME]
      ,[CCAID]
      ,plan_name
      ,[AUTH_ID]
	  ,[Received_date]      
      ,[SERVICE_FROM_DATE]
      ,[SERVICE_TO_DATE]	  
      ,[proc_code]
      ,[proc_description]
      ,[UnitsRequested]
      ,[UnitsApproved]
      ,[auth_priority]
      ,[auth_status]
      ,[auth_status_reason_name]
      ,[IS_EXTENsion]
	  ,[Is there an Extension letter created]
      ,[decision_Status]
      ,[DECISION_STATUS_CODE_DESC]
	  ,[Decision_Date]   
      ,[Verbal Notification]
      ,[WrittenNotifDate]
      ,[auth_type_name]
      ,[PLACE_OF_SERVICE_CODE]
      ,[PLACE_OF_SERVICE_NAME]
      ,[CMO]
      ,[Auth owner]
      ,[ReferredBy]
      ,[ReferredTo]
      ,[Status (progress)]
      ,[Workqueue]
	  , CASE WHEN  DECISION_DATE is not null then 'NA'
		when [Received_date]is null then 'NA'
		when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN cast (datediff (dd,getdate(),dateadd (dd, 28, [Received_date] )) as varchar)
		WHEN auth_priority = 'Prospective Standard'  THEN  cast (datediff (dd,getdate(),dateadd (dd, 14,[Received_date]) ) as varchar)
		when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN  cast(datediff (dd,getdate(),dateadd (dd, 16,[Received_date]) )as varchar)
			when auth_priority = 'Prospective Expedited'  THEN  cast(datediff (dd,getdate(),dateadd (dd, 3, [Received_date]) )as varchar)
			WHEN auth_priority = 'Retrospective'  THEN  cast (datediff (dd,getdate(),dateadd (dd, 14, [Received_date]) ) as varchar)
		else cast (0 as varchar) end
, CASE WHEN 
		received_date is null then 0
		when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN dateadd (dd, 28, received_date)
		WHEN auth_priority = 'Prospective Standard'  THEN dateadd (dd, 14,received_date)
		when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 17, received_date)
		when auth_priority = 'Prospective Expedited'  THEN dateadd (dd,3,received_date)
		WHEN auth_priority = 'Retrospective'  THEN dateadd (dd, 14,received_date)
		else 0 end 
 , case when auth_priority like '%concurrent%'  then 'NA'
	  when DECISION_DATE is null then 'NoDecision'
	  when received_date is null  then 'NA'
	  --when ud.replied_date = '1900-01-01' then 'NoDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 0 then 'UntimelyDecision'  
	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%retro%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%retro%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%standard%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%standard%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 4 and auth_priority like  '%Expedited%' and (is_extension ='No' or is_extension is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 18 and auth_priority like  '%Expedited%' and is_extension ='Yes' then 'TimelyDecision'
	  else 'UntimelyDecision' 
   end 	  
, case 
when auth_priority like '%concurrent%'  then 'NA'
when [WrittenNotifDate] is null then 'NoLetter'
  when received_date is null then 'NA'	
	when convert(date,[WrittenNotifDate]) = '1900-01-01' then 'NoLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 0 then 'UntimelyLetter' 
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'retrospective')  then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'retrospective') and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'Prospective Standard')  then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'Prospective Standard') and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 4 and auth_priority = 'Prospective Expedited' and (is_extension = 'No' or is_extension is null) then 'TimelyLetter'
    when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 18 and auth_priority  = 'Prospective Expedited' and is_extension = 'Yes' then 'TimelyLetter'
	else 'UntimelyLetter' 
end 
      ,[AUTH_NO]

, CASE when [Received_date] is null then 'Yes' ELSE 'No' end
	,letter_created_on
  , letter_created_by_name
, Note1
	, Note2
	, Note3
	   , printedon,letterqueue_updatedate
	     ,typeofcode
		       , [Team] 
  ,Facility
   	 , AuthCreatedBy
   , AuthCreatedDate

select 
[FIRST_NAME] as 'First Name'
,[LAST_NAME] as 'Last Name'
,[CCAID]
,plan_name as 'Plan Name'
,[AUTH_ID] as 'Auth ID'
,[Received Date]
,[SERVICE_FROM_DATE]
,[SERVICE_TO_DATE]
,[proc_code] AS 'Procedure/Service Code'
  ,typeofcode as 'Type of Code'
,[proc_description] as 'Procedure/Service Description'
,[UnitsRequested] as 'Units Requested'
,[UnitsApproved] as 'Units Approved'
,[auth_priority] as 'Auth Priority'
,[auth_status] as 'Auth Status'
,[auth_status_reason_name] as 'Auth Status Reason Name'
,[IS_extension]
,[Is there an Extension letter created]
,[decision_Status]
,[DECISION_STATUS_CODE_DESC]
,[Decision Date]
,[Verbal Notification] as 'Verbal Notification Date'
,[WrittenNotifDate] as 'Written Notification Date'
,[auth_type_name]
,[PLACE_OF_SERVICE_CODE]
,[PLACE_OF_SERVICE_NAME]
,[CMO]
,[Auth owner]
,[ReferredBy]
,[ReferredTo]
,[Status (progress)]
,[Workqueue]
,Team
,[Days to Process Auth]
,deadline
,[DecisionFlag]
, 
case 
when [decision date] is not null then [DecisionFlag]
when [auth_priority] like '%concurrent%' then 'NA'
when [auth_priority] like '%expedited%' and deadline < getdate() then 'Passed deadline'
when  deadline < cast(getdate() as date) then 'Passed deadline'
when  [decision date] is null and ([auth_priority] like '%standard%' or [auth_priority] like '%retro%') and datediff(dd,[Received date],cast(getdate() as date)) >=8
 and deadline >= cast(getdate() as date) then 'Approaching Deadline'
when  [decision date] is null and ([auth_priority] like '%standard%' or [auth_priority] like '%retro%') and datediff(dd,[Received date],cast(getdate() as date)) < 8
 and deadline >= cast(getdate() as date) then 'NA'
when  [decision date] is null  and deadline >= getdate() then 'Approaching Deadline'
--else [DecisionFlag] 
end as  'Timeliness Flag For Decisions'
,[LetterFlag]
--, case when  [decision date] is null  and deadline >= getdate() then 'Future' else 'Include' end as FutureorPending
,[No Receipt Date]
	,letter_created_on
  , letter_created_by_name
   , printedon,letterqueue_updatedate
  , REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),isnull (Note1, '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  as 'Note1'
  , REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),isnull (Note2, '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  as 'Note2'
  , REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),isnull (Note3, '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  as 'Note3'

	,[AUTH_NO]
, getdate() as 'Report_Date'
	 , AuthCreatedBy
   , AuthCreatedDate
  ,Facility
 , case when [WrittenNotifDate] is null or  [decision date] is null then 'no decision/written'
 when [decision date] <=[WrittenNotifDate] then 'No' ELSE 'Yes' end as 'written before decision'
 from #step2
 where referredto like 'Lutheran%' or facility like  '%Lutheran%' 
 order by auth_id, [received date], [decision date], [SERVICE_FROM_DATE]

