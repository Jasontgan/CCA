



------Care Management Acitivities------------------------------

select * from
(

SELECT distinct 

 'CM' as GC_Module,
  [Member Activity].[PATIENT_FOLLOWUP_ID] AS [GC_ACTIVITYID],
  [Member Activity].[PATIENT_ID] AS [GC_PATIENT_ID],
  [Member Activity].[a_CCAID] AS [CCAID],
  [Member Activity].[b_Member_Name] AS [Member_Name],
  [Member Activity].[c_DOB] AS [DOB],
  [Member Activity].[d_PLAN_NAME] AS [Plan_Name],
  [Member Activity].[e_plan_start] AS [Plan_start],
  [Member Activity].[f_plan_end] AS [Plan_end],
  --[Member Activity].[MEMBER_ID] AS [MEMBER_ID],
   left ([Member Activity].[d_PLAN_NAME], 3) AS [Product],
   --'' as 'Product Start Date',
   --'' as 'Product End Date',
     [Member Activity].City,
 [Member Activity].Zip,
  [Member Activity].County,
  [CP].PRIMCAREMGR AS [Care Partner] ,
    --[Care Partner].[Care_Partner] AS [Care_Partner],
    [CMO].[h_CMO] AS [CMO],
PCL.P_PCL AS PCL,
  --[CMO].[CLIENT_PATIENT_ID] AS [CLIENT_PATIENT_ID],
  --[CMO].[PATIENT_ID] AS [PATIENT_ID (Custom SQL Query)],

  --[Care Partner].[CLIENT_PATIENT_ID] AS [CLIENT_PATIENT_ID (Custom SQL Query)],
  --[Care Partner].[PATIENT_ID] AS [PATIENT_ID (Custom SQL Query) #1],

  --[Unreachable/Unwilling].[CLIENT_PATIENT_ID] AS [CLIENT_PATIENT_ID (Custom SQL Query1)],
  case when [Unreachable/Unwilling].[n_Unreachable] is not null then 'Y' else 'N' END AS [Unreachable],
  case when [Unreachable/Unwilling].[o_Unwilling_to_Participate] is not null then 'Y' else 'N' end AS [Unwilling_to_Participate],
   [Member Activity].[j_CARE_ACTIVITY_TYPE_NAME] AS [Activity_Type],
  [Member Activity].[l_Activity_Create_Date] AS [Activity_Created_Date],
  [Member Activity].[m_Activity_Scheduled_Date] AS [Activity_Scheduled_Date],
     convert(varchar(20), [Member Activity].[due_date], 120) AS GC_Due_Date,
	[Member Activity].performed_date as 'Completed/Performed Date',
    [Member Activity].[CALL_STATUS_DESC] as 'case_Activity_Outcome' ,
		  [Member Activity].[ACTIVITY_OUTCOME] as 'GC_Activity_Outcome',
	  [Member Activity].[ACTIVITY_OUTCOME_TYPE] as 'GC_Activity_Outcome_Type',
	     
		    [Member Activity].[k_REFER_TO_NAME] as 'Activity Assigned/Referred To',
		  ACTIVITYCREATEDBY as 'Activity Created By',
		   [Member Activity].PRIORITY,
		  '' as 'Auth Owner',
		  
      '' as AUTH_ID,
       --auth.AUTH_NO,
       '' as AUTH_STATUS,
      '' as AUTH_STATUS_REASON_NAME,

          -- coalesce to combine RefTo and Facility into one field (mep)

       '' as GC_AuthProviderName,

	     REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),isnull (   [Member Activity].comments , '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')
		  as 'Activity Notes',

		  
	     REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),isnull (outcome_notes , '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')
		  as 'Activity Outcome Notes'
			  --[Member Activity].ACCEPT_FLAG,
		

  --[Member Activity].[REFER_TO] AS [REFER_TO],
  --[Member Activity].[QUEUE_ID] AS [QUEUE_ID],
  --[Member Activity].[SCRIPT_ID] AS [SCRIPT_ID],

FROM (
  SELECT
  	pf.PATIENT_FOLLOWUP_ID,
  	pf.PATIENT_ID,
  	pd.CLIENT_PATIENT_ID a_CCAID,
  	pd.LAST_NAME + ', ' + pd.FIRST_NAME b_Member_Name,
	pd.city,
	pd.zip,
	county.description as County,
  	CAST(pd.BIRTH_YEAR AS DATE) c_DOB,
          bp.PLAN_NAME d_PLAN_NAME,
  	CAST(MIN(mb_plan.[START_DATE]) OVER (PARTITION BY pd.CLIENT_PATIENT_ID, mb_plan.LOB_BEN_ID) AS DATE) e_plan_start,
  	CAST(MAX(mb_plan.END_DATE) OVER (PARTITION BY pd.CLIENT_PATIENT_ID, mb_plan.LOB_BEN_ID) AS DATE) f_plan_end,
   --       mc_primary.MEMBER_ID,
  	--primary_cm.LAST_NAME + ', ' + primary_cm.FIRST_NAME g_Primary_CareManager,
  	act_ref.CARE_ACTIVITY_TYPE_NAME j_CARE_ACTIVITY_TYPE_NAME,
  	pf.CREATED_DATE l_Activity_Create_Date,
  	pf.FOLLOWUP_DATE m_Activity_Scheduled_Date,
  	hcv.REFER_TO_NAME k_REFER_TO_NAME,	
  	CASE WHEN pf.CALL_STATUS = 1 then 'Completed' else 'Not Completed' end as CALL_STATUS_DESC,  
  	pf.REFER_TO,
  	pf.QUEUE_ID,
  	pf.SCRIPT_ID,
	pf.due_date,
	ao.[ACTIVITY_OUTCOME],
		aoT.[ACTIVITY_OUTCOME_TYPE],

		pf.performed_date,
		pf.comments,
		PF.ACCEPT_FLAG,
		PF.PRIORITY,
		 pfcreate.LAST_NAME + ',' + pfcreate.First_NAME AS ACTIVITYCREATEDBY
		 ,  pf.outcome_notes
  FROM
  dbo.PATIENT_FOLLOWUP pf
  JOIN
  	dbo.PATIENT_DETAILS pd
  ON
  	pf.PATIENT_ID = pd.PATIENT_ID AND
  	pd.DELETED_ON IS NULL AND
  	pd.CLIENT_PATIENT_ID LIKE '536%'
  left JOIN
  	dbo.MEM_BENF_PLAN mb_plan
  ON
  	pd.PATIENT_ID = mb_plan.MEMBER_ID AND
  	GETDATE() BETWEEN mb_plan.[START_DATE] and mb_plan.END_DATE AND
	MB_PLAN.DELETED_ON IS NULL
  left JOIN
  	dbo.CARE_ACTIVITY_TYPE act_ref
  ON
  	pf.CARE_ACTIVITY_TYPE_ID = act_ref.CARE_ACTIVITY_TYPE_ID
  LEFT JOIN
  	dbo.LOB_BENF_PLAN lob_bp
  ON
  	mb_plan.LOB_BEN_ID = lob_bp.LOB_BEN_ID AND
	lob_bp.DELETED_ON IS NULL
  LEFT JOIN
  	dbo.BENEFIT_PLAN bp
  ON
  	lob_bp.BENEFIT_PLAN_ID = bp.BENEFIT_PLAN_ID
  LEFT JOIN
  	dbo.healthcoach_reference_v hcv
  ON
  	pf.PATIENT_FOLLOWUP_ID = hcv.PATIENT_FOLLOWUP_ID

  --LEFT JOIN
  --	dbo.MEMBER_CARESTAFF mc_primary
  --ON
  --	pd.PATIENT_ID = mc_primary.PATIENT_ID AND
  --	mc_primary.IS_ACTIVE = 1 AND
  --	mc_primary.IS_PRIMARY = 1
  --LEFT JOIN
  --	dbo.CARE_STAFF_DETAILS primary_cm
  --ON
  --	mc_primary.MEMBER_ID = primary_cm.MEMBER_ID

left join 
[dbo].[COUNTY] county
on pd.county_id=county.county_id

left join  [dbo].[ACTIVITY_OUTCOME] ao
on pf.[ACTIVITY_OUTCOME_ID]=ao.[ACTIVITY_OUTCOME_ID] and
ao.deleted_on is null


left join  [dbo].[ACTIVITY_OUTCOME_TYPE] aot
on ao.[ACTIVITY_OUTCOME_TYPE_ID]=aot.[ACTIVITY_OUTCOME_TYPE_ID] and
aot.deleted_on is null


left JOIN
      [Altruista].[dbo].[CARE_STAFF_DETAILS]  pfcreate
       ON
       pf.created_by = pfcreate.MEMBER_ID


  WHERE
  	pf.DELETED_ON IS NULL
) [Member Activity]
  LEFT JOIN (
  SELECT CLIENT_PATIENT_ID, PATIENT_ID, CMO h_CMO
  	FROM
  	(
  		SELECT
  			pd.CLIENT_PATIENT_ID,
  			pd.PATIENT_ID,
  			pdv.LAST_NAME + CASE WHEN pdv.FIRST_NAME IS NOT NULL THEN ', ' + pdv.FIRST_NAME ELSE '' END CMO,
  			ROW_NUMBER() OVER (PARTITION BY pd.CLIENT_PATIENT_ID ORDER BY pp.END_DATE DESC, pp.[START_DATE] DESC) rn
  		FROM
  			dbo.patient_details_v pd
  		JOIN
  			dbo.PATIENT_PHYSICIAN pp
  		ON
  			pd.PATIENT_ID = pp.PATIENT_ID AND  
  			CARE_TEAM_ID IN (1,2) AND
  			pp.PROVIDER_TYPE_ID = 181 AND -- cmo
  			CAST(GETDATE() AS DATE) BETWEEN [START_DATE] and END_DATE and
  			pp.DELETED_ON IS NULL AND
  			pp.IS_ACTIVE = 1
  		LEFT JOIN
  			dbo.PHYSICIAN_DEMOGRAPHY_V pdv 
  		ON
  			pp.physician_id = pdv.physician_id 
  		WHERE
  			pd.CLIENT_PATIENT_ID LIKE '536%' 
  	) a
  	WHERE rn = 1
) [CMO] ON ([Member Activity].[a_CCAID] = [CMO].[CLIENT_PATIENT_ID])
LEFT JOIN (
  SELECT CLIENT_PATIENT_ID, PATIENT_ID, PCL AS P_PCL
  	FROM
  	(
  		SELECT
  			pd.CLIENT_PATIENT_ID,
  			pd.PATIENT_ID,
  			pdv.LAST_NAME + CASE WHEN pdv.FIRST_NAME IS NOT NULL THEN ', ' + pdv.FIRST_NAME ELSE '' END PCL,
  			ROW_NUMBER() OVER (PARTITION BY pd.CLIENT_PATIENT_ID ORDER BY pp.END_DATE DESC, pp.[START_DATE] DESC) rn
  		FROM
  			dbo.patient_details_v pd
  		JOIN
  			dbo.PATIENT_PHYSICIAN pp
  		ON
  			pd.PATIENT_ID = pp.PATIENT_ID AND  
  			CARE_TEAM_ID IN (1,2) AND
  			pp.PROVIDER_TYPE_ID  IN ('185','193') AND -- SCO & ICO PCL
  			CAST(GETDATE() AS DATE) BETWEEN [START_DATE] and END_DATE and
  			pp.DELETED_ON IS NULL AND
  			pp.IS_ACTIVE = 1
  		LEFT JOIN
  			dbo.PHYSICIAN_DEMOGRAPHY_V pdv 
  		ON
  			pp.physician_id = pdv.physician_id 
  		WHERE
  			pd.CLIENT_PATIENT_ID LIKE '536%' 
  	) a
  	WHERE rn = 1
) [PCL] ON ([Member Activity].[a_CCAID] = [PCL].[CLIENT_PATIENT_ID])

  LEFT JOIN (
  SELECT
  	pd.CLIENT_PATIENT_ID,
  	--ben_prog.[PROGRAM_NAME]
  	MAX(CASE WHEN ben_prog.[PROGRAM_NAME] = 'Unreachable' THEN 'Y' ELSE NULL END) n_Unreachable,
  	MAX(CASE WHEN ben_prog.[PROGRAM_NAME] = 'Unwilling to Participate' THEN 'Y' ELSE NULL END) o_Unwilling_to_Participate
  FROM
  	dbo.PATIENT_DETAILS pd
  JOIN
  	dbo.MEM_BENF_PROG mb_prog
  ON
  	pd.PATIENT_ID = mb_prog.MEMBER_ID AND
  	CAST(GETDATE() AS DATE) BETWEEN mb_prog.[START_DATE] AND mb_prog.END_DATE and
	mb_prog.deleted_on is null
  JOIN
  	dbo.BENF_PLAN_PROG bpp
  ON
  	mb_prog.BEN_PLAN_PROG_ID = bpp.BEN_PLAN_PROG_ID AND
  	bpp.BENEFIT_PROGRAM_ID IN (22, 23) and  -- unreachable, unwilling to participate
	bpp.deleted_on is null
  JOIN
  	dbo.BENEFIT_PROGRAM ben_prog
  ON
  	bpp.BENEFIT_PROGRAM_ID = ben_prog.BENEFIT_PROGRAM_ID and
	ben_prog.deleted_on is null
  WHERE
  	pd.CLIENT_PATIENT_ID LIKE '536%'
	AND pd.deleted_on is null
  GROUP BY
  	pd.CLIENT_PATIENT_ID
) [Unreachable/Unwilling] ON ([Member Activity].[a_CCAID] = [Unreachable/Unwilling].[CLIENT_PATIENT_ID])

LEFT JOIN

(

select pc.ccaid, pc.Patient_ID, pc.member_ID as PrimCareMgrID, pc.PrimCareMgr, pc.PrimCareMgrRole
, pcs.PhysID, pcs.PhysRole, pcs.First_name, pcs.Last_Name
, case when pc.member_ID=pcs.PhysID then 'Y' else 'N' end as CMtoPhysMatch
, dense_rank() over (partition by pc.ccaid order by case when pc.member_ID=PCS.PhysID then 'Y' else 'N' end desc) as PCMrank
 --into #PrimCM
 from 
 (SELECT pd.[CLIENT_PATIENT_ID] as CCAID, pd.[PATIENT_ID] ,mc.[MEMBER_ID], cs.last_name+', '+cs.first_name as PrimCareMgr
-- , cs.Last_name, cs.First_Name, cs.Middle_name
, r.Role_name as PrimCareMgrRole
  FROM  [Altruista].[dbo].[PATIENT_DETAILS] pd 
  inner join [Altruista].[dbo].[MEMBER_CARESTAFF] mc on pd.patient_id=mc.patient_id
  inner join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on mc.member_id=cs.member_id 
  left join [Altruista].[dbo].Role r on cs.role_id=r.role_id and r.is_active=1 and r.deleted_on is null
  where left(pd.[CLIENT_PATIENT_ID],3)='536' and mc.is_active=1 and mc.is_primary=1
	) pc 
 left join 
 (SELECT pd.[CLIENT_PATIENT_ID] as CCAID, pd.[PATIENT_ID], pp.[PHYSICIAN_ID] as PhysID
     ,r.Role_name as PhysRole, [TITLE], cs.[FIRST_NAME], cs.[LAST_NAME]
  FROM [Altruista].[dbo].[PATIENT_DETAILS] pd 
  inner join [Altruista].[dbo].[PATIENT_PHYSICIAN] pp on pd.patient_id=pp.patient_ID
	and pp.care_team_id=1 and pp.is_active=1 and pp.deleted_on is null
  inner join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on pp.physician_id=cs.member_id 
  left join altruista.dbo.role r on cs.role_id=r.role_id and r.is_active=1 and r.deleted_on is null
  where left(pd.[CLIENT_PATIENT_ID],3)='536'
	and pd.deleted_on is null
)pcs on pc.ccaid=pcs.ccaid and pc.member_ID=pcs.PhysID
  
)CP ON ([Member Activity].[a_CCAID] =CP.CCAID) AND CP.PCMrank=1----CARE PARTNER INFO
--where [Member Activity].[a_CCAID]='5365631904'


union







------Utilization Management/Authorization Acitivities------------------------------

SELECT DISTINCT
      'UM' as GC_Module,
	    umal.ACTIVITY_LOG_ID  GC_ActivityID,
	     auth.Patient_ID GC_PatientID,
 
     
	pd.CLIENT_PATIENT_ID  AS CCAID,
		pd.LAST_NAME + ', ' + pd.FIRST_NAME AS Member_Name,
	CAST(pd.BIRTH_YEAR AS DATE) AS DOB,
	
          bp.PLAN_NAME AS PLAN_NAME,
  	CAST(MIN(mb_plan.[START_DATE]) OVER (PARTITION BY pd.CLIENT_PATIENT_ID, mb_plan.LOB_BEN_ID) AS DATE) AS plan_start,
  	CAST(MAX(mb_plan.END_DATE) OVER (PARTITION BY pd.CLIENT_PATIENT_ID, mb_plan.LOB_BEN_ID) AS DATE) AS plan_end,
   --       mc_primary.MEMBER_ID,
     left (BP.[PLAN_NAME], 3) AS [Product],
   --'' as 'Product Start Date',
   --'' as 'Product End Date',
	pd.city,
	pd.zip,
	county.description as County,
  	[CP].PRIMCAREMGR AS [Care Partner] ,
    --[Care Partner].[Care_Partner] AS [Care_Partner],
    [CMO].[h_CMO] AS [CMO],
	 PCL.P_PCL AS PCL,
	 case when [Unreachable/Unwilling].[n_Unreachable] is not null then 'Y' else 'N' END AS [Unreachable],
	 case when [Unreachable/Unwilling].[o_Unwilling_to_Participate] is not null then 'Y' else 'N' end AS [Unwilling_to_Participate],
   
    
  
       umat.Activity_Type_Name  as Activity_Type,
	        umal.CREATED_ON    as   Activity_Created_Date,
			   umal.ACTIVITY_LOG_FOLLOWUP_DATE as  Activity_Scheduled_Date, 
			  
     	  CASE WHEN 
		auth.AUTH_NOTI_DATE  is null then ''
		when (tat.auth_priority = 'Prospective Standard' and auth.is_extension =1) THEN convert(varchar(20),dateadd (dd, 28, auth.AUTH_NOTI_DATE ), 120)
		WHEN tat.auth_priority = 'Prospective Standard'  THEN convert(varchar(20),dateadd (dd, 14,auth.AUTH_NOTI_DATE), 120)
		when tat.auth_priority = 'Prospective Expedited'  and (auth.is_extension = 1)   THEN convert(varchar(20),dateadd (dd, 17, auth.AUTH_NOTI_DATE) , 120)
		when tat.auth_priority = 'Prospective Expedited'  THEN convert(varchar(20),dateadd (dd,3,auth.AUTH_NOTI_DATE ) ,120)
		WHEN tat.auth_priority = 'Retrospective'  THEN convert(varchar(20),dateadd (dd, 14,auth.AUTH_NOTI_DATE) , 120)
		else '' end as GC_DueDate,  
	   --auth.auth_due_date,
          -- case statement for outcome (mep)
		     umal.ACTIVITY_LOG_COMPLETED_DATE as 'Completed/Performed Date',

		     case when ACTIVITY_LOG_STATUS = 0 then 'Not Completed'
          when ACTIVITY_LOG_STATUS = 1 then 'Completed'
          else 'Error' end as 'case_Activity_Outcome' ,
		  '' as 'GC_Activity_Outcome',
	 '' as 'GC_Activity_Outcome_Type',
       --umrs.REFERRAL_STATUS_NAME GC_ActivityOutcome,

         actassign.LAST_NAME + ',' +  actassign.First_NAME as 'Activity Assigned/Referred To',
		  actcreate.LAST_NAME + ',' + actcreate.First_NAME as 'Activity Created By',
		  	 ap.[ACTIVITY_PRIORITY] as 'Priority',

		   authown.LAST_NAME + ',' + authown.First_NAME as 'Auth Owner',
		 
      auth.AUTH_ID,
       --auth.AUTH_NO,
       umas.AUTH_STATUS,

	   
	     REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),isnull (     umasr.AUTH_STATUS_REASON_NAME, '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')
		  as 'AUTH_STATUS_REASON_NAME',
     

          -- coalesce to combine RefTo and Facility into one field (mep)

       coalesce(umprov3.PROVIDER_NAME, umprov4.PROVIDER_NAME) as  GC_AuthProvider

          --,umprov3.PROVIDER_NAME as RefToProv, umprov4.PROVIDER_NAME as Facility
              ,   
	     REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),isnull (   [ACTIVITY_LOG_DESC] , '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')
		  as 'Activity Notes'
			  , '' as 'Activity Outcome Notes'

			--, '' accept_flag
		
		
			--,umal.activity_log_status
     FROM [Altruista].[dbo].[UM_ACTIVITY_LOG] umal

JOIN
       [Altruista].[dbo].[UM_MA_ACTIVITY_TYPE] umat
       ON
       umal.ACTIVITY_TYPE_ID = umat.ACTIVITY_TYPE_ID
       AND umat.DELETED_ON IS NULL

JOIN
       [Altruista].[dbo].[UM_AUTH] auth
       ON
       umal.ACTIVITY_LOG_REF_ID = auth.AUTH_NO
       AND auth.DELETED_ON IS NULL
 JOIN
  	dbo.PATIENT_DETAILS pd
  ON
  	AUTH.PATIENT_ID = pd.PATIENT_ID AND
  	pd.DELETED_ON IS NULL AND
  	pd.CLIENT_PATIENT_ID LIKE '536%'
  LEFT JOIN
  	dbo.MEM_BENF_PLAN mb_plan
  ON
  	pd.PATIENT_ID = mb_plan.MEMBER_ID AND
   	GETDATE() BETWEEN mb_plan.[START_DATE] and mb_plan.END_DATE AND
	MB_PLAN.DELETED_ON IS NULL
 
  LEFT JOIN
  	dbo.LOB_BENF_PLAN lob_bp
  ON
  	mb_plan.LOB_BEN_ID = lob_bp.LOB_BEN_ID
  LEFT JOIN
  	dbo.BENEFIT_PLAN bp
  ON
  	lob_bp.BENEFIT_PLAN_ID = bp.BENEFIT_PLAN_ID

left join 
[dbo].[COUNTY] county
on pd.county_id=county.county_id

left JOIN
      [Altruista].[dbo].[CARE_STAFF_DETAILS]  actassign
       ON
       umal.ACTIVITY_LOG_ASSIGN_TO = actassign.MEMBER_ID
       --AND mbr.DELETED_ON IS NULL


left JOIN
      [Altruista].[dbo].[CARE_STAFF_DETAILS]  actcreate
       ON
       umal.ACTIVITY_LOG_created_by = actcreate.MEMBER_ID


left JOIN
      [Altruista].[dbo].[CARE_STAFF_DETAILS] authown
       ON
      auth.AUTH_CUR_OWNER=authown.member_id
left JOIN
       [Altruista].[dbo].[UM_MA_AUTH_STATUS] umas
       ON
       auth.AUTH_STATUS_ID = umas.AUTH_STATUS_ID
       AND umas.DELETED_ON IS NULL

left JOIN
       [Altruista].[dbo].[UM_MA_AUTH_STATUS_REASON] umasr
       ON 
       auth.AUTH_STATUS_REASON_ID = umasr.AUTH_STATUS_REASON_ID
       AND umasr.DELETED_ON IS NULL

left join  [Altruista].[dbo].UM_MA_AUTH_TAT_PRIORITY tat 
		on auth.auth_priority_id = tat.auth_priority_id and 
		tat.deleted_on is null
          --- copied the below link to include both RefTo and Facility so that they can be Coalesced (MEP)

LEFT JOIN
      [Altruista].[dbo].[UM_AUTH_PROVIDER] umprov3
       ON
       auth.AUTH_NO = umprov3.AUTH_NO
       AND umprov3.DELETED_ON IS NULL
       AND umprov3.PROVIDER_TYPE_ID = 3 


LEFT JOIN
       [Altruista].[dbo].[UM_AUTH_PROVIDER] umprov4
       ON
       auth.AUTH_NO = umprov4.AUTH_NO
       AND umprov4.DELETED_ON IS NULL
       AND umprov4.PROVIDER_TYPE_ID = 4 

  LEFT JOIN (
  SELECT CLIENT_PATIENT_ID, PATIENT_ID, CMO h_CMO
  	FROM
  	(
  		SELECT
  			pd.CLIENT_PATIENT_ID,
  			pd.PATIENT_ID,
  			pdv.LAST_NAME + CASE WHEN pdv.FIRST_NAME IS NOT NULL THEN ', ' + pdv.FIRST_NAME ELSE '' END CMO,
  			ROW_NUMBER() OVER (PARTITION BY pd.CLIENT_PATIENT_ID ORDER BY pp.END_DATE DESC, pp.[START_DATE] DESC) rn
  		FROM
  			dbo.patient_details_v pd
  		JOIN
  			dbo.PATIENT_PHYSICIAN pp
  		ON
  			pd.PATIENT_ID = pp.PATIENT_ID AND  
  			CARE_TEAM_ID IN (1,2) AND
  			pp.PROVIDER_TYPE_ID = 181 AND -- cmo
  			CAST(GETDATE() AS DATE) BETWEEN [START_DATE] and END_DATE and
  			pp.DELETED_ON IS NULL AND
  			pp.IS_ACTIVE = 1
  		LEFT JOIN
  			dbo.PHYSICIAN_DEMOGRAPHY_V pdv 
  		ON
  			pp.physician_id = pdv.physician_id 
  		WHERE
  			pd.CLIENT_PATIENT_ID LIKE '536%' 
  	) a
  	WHERE rn = 1
) [CMO] ON (	pd.CLIENT_PATIENT_ID  = [CMO].[CLIENT_PATIENT_ID])
LEFT JOIN (
  SELECT CLIENT_PATIENT_ID, PATIENT_ID, PCL AS P_PCL
  	FROM
  	(
  		SELECT
  			pd.CLIENT_PATIENT_ID,
  			pd.PATIENT_ID,
  			pdv.LAST_NAME + CASE WHEN pdv.FIRST_NAME IS NOT NULL THEN ', ' + pdv.FIRST_NAME ELSE '' END PCL,
  			ROW_NUMBER() OVER (PARTITION BY pd.CLIENT_PATIENT_ID ORDER BY pp.END_DATE DESC, pp.[START_DATE] DESC) rn
  		FROM
  			dbo.patient_details_v pd
  		JOIN
  			dbo.PATIENT_PHYSICIAN pp
  		ON
  			pd.PATIENT_ID = pp.PATIENT_ID AND  
  			CARE_TEAM_ID IN (1,2) AND
  			pp.PROVIDER_TYPE_ID  IN ('185','193') AND -- SCO & ICO PCL
  			CAST(GETDATE() AS DATE) BETWEEN [START_DATE] and END_DATE and
  			pp.DELETED_ON IS NULL AND
  			pp.IS_ACTIVE = 1
  		LEFT JOIN
  			dbo.PHYSICIAN_DEMOGRAPHY_V pdv 
  		ON
  			pp.physician_id = pdv.physician_id 
  		WHERE
  			pd.CLIENT_PATIENT_ID LIKE '536%' 
  	) a
  	WHERE rn = 1
) [PCL] ON (	pd.CLIENT_PATIENT_ID  = [PCL].[CLIENT_PATIENT_ID])

  LEFT JOIN (
  SELECT
  	pd.CLIENT_PATIENT_ID,
  	--ben_prog.[PROGRAM_NAME]
  	MAX(CASE WHEN ben_prog.[PROGRAM_NAME] = 'Unreachable' THEN 'Y' ELSE NULL END) n_Unreachable,
  	MAX(CASE WHEN ben_prog.[PROGRAM_NAME] = 'Unwilling to Participate' THEN 'Y' ELSE NULL END) o_Unwilling_to_Participate
  FROM
  	dbo.PATIENT_DETAILS pd
  JOIN
  	dbo.MEM_BENF_PROG mb_prog
  ON
  	pd.PATIENT_ID = mb_prog.MEMBER_ID AND
  	CAST(GETDATE() AS DATE) BETWEEN mb_prog.[START_DATE] AND mb_prog.END_DATE and
	mb_prog.deleted_on is null
  JOIN
  	dbo.BENF_PLAN_PROG bpp
  ON
  	mb_prog.BEN_PLAN_PROG_ID = bpp.BEN_PLAN_PROG_ID AND
  	bpp.BENEFIT_PROGRAM_ID IN (22, 23) and  -- unreachable, unwilling to participate
	bpp.deleted_on is null
  JOIN
  	dbo.BENEFIT_PROGRAM ben_prog
  ON
  	bpp.BENEFIT_PROGRAM_ID = ben_prog.BENEFIT_PROGRAM_ID and
	ben_prog.deleted_on is null
  WHERE
  	pd.CLIENT_PATIENT_ID LIKE '536%'
	AND pd.deleted_on is null
  GROUP BY
  	pd.CLIENT_PATIENT_ID
) [Unreachable/Unwilling] ON (	pd.CLIENT_PATIENT_ID  = [Unreachable/Unwilling].[CLIENT_PATIENT_ID])

LEFT JOIN

(

select pc.ccaid, pc.Patient_ID, pc.member_ID as PrimCareMgrID, pc.PrimCareMgr, pc.PrimCareMgrRole
, pcs.PhysID, pcs.PhysRole, pcs.First_name, pcs.Last_Name
, case when pc.member_ID=pcs.PhysID then 'Y' else 'N' end as CMtoPhysMatch
, dense_rank() over (partition by pc.ccaid order by case when pc.member_ID=PCS.PhysID then 'Y' else 'N' end desc) as PCMrank
 --into #PrimCM
 from 
 (SELECT pd.[CLIENT_PATIENT_ID] as CCAID, pd.[PATIENT_ID] ,mc.[MEMBER_ID], cs.last_name+', '+cs.first_name as PrimCareMgr
-- , cs.Last_name, cs.First_Name, cs.Middle_name
, r.Role_name as PrimCareMgrRole
  FROM  [Altruista].[dbo].[PATIENT_DETAILS] pd 
  inner join [Altruista].[dbo].[MEMBER_CARESTAFF] mc on pd.patient_id=mc.patient_id
  inner join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on mc.member_id=cs.member_id 
  left join [Altruista].[dbo].Role r on cs.role_id=r.role_id and r.is_active=1 and r.deleted_on is null
  where left(pd.[CLIENT_PATIENT_ID],3)='536' and mc.is_active=1 and mc.is_primary=1
	) pc 
 left join 
 (SELECT pd.[CLIENT_PATIENT_ID] as CCAID, pd.[PATIENT_ID], pp.[PHYSICIAN_ID] as PhysID
     ,r.Role_name as PhysRole, [TITLE], cs.[FIRST_NAME], cs.[LAST_NAME]
  FROM [Altruista].[dbo].[PATIENT_DETAILS] pd 
  inner join [Altruista].[dbo].[PATIENT_PHYSICIAN] pp on pd.patient_id=pp.patient_ID
	and pp.care_team_id=1 and pp.is_active=1 and pp.deleted_on is null
  inner join [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on pp.physician_id=cs.member_id 
  left join altruista.dbo.role r on cs.role_id=r.role_id and r.is_active=1 and r.deleted_on is null
  where left(pd.[CLIENT_PATIENT_ID],3)='536'
	and pd.deleted_on is null
)pcs on pc.ccaid=pcs.ccaid and pc.member_ID=pcs.PhysID
  
)CP ON (	pd.CLIENT_PATIENT_ID =CP.CCAID) AND CP.PCMrank=1----CARE PARTNER INFO

LEFT JOIN 
[dbo].[UM_MA_ACTIVITY_PRIORITY] ap
ON
umal.activity_priority_id=ap.activity_priority_id AND
ap.deleted_on is null

WHERE umaL.DELETED_ON IS NULL 

--and umal.gc_flag_id=5
--and pd.patient_id='38428'

--AND AUTH.AUTH_ID IS NULL

)a 

where 
(cmo like '%onboarding%' or cmo like '%Commonwealth Care Alliance Clinical Group (East)%')
order by ccaid, activity_created_date