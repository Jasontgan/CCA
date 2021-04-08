--- 5 temp tables used and sorted
IF OBJECT_ID('tempdb..#MANAGERS_REFER_TO') IS NOT NULL DROP TABLE #MANAGERS_REFER_TO;
IF OBJECT_ID('tempdb..#test') IS NOT NULL DROP TABLE #test;
IF OBJECT_ID('tempdb..#TEMP') IS NOT NULL DROP TABLE #TEMP;
IF OBJECT_ID('tempdb..#UMworklog') IS NOT NULL DROP TABLE #UMworklog;
IF OBJECT_ID('tempdb..#UMworklogfinal') IS NOT NULL DROP TABLE #UMworklogfinal;
IF OBJECT_ID('tempdb..#final_final') IS NOT NULL DROP TABLE #final_final; 
IF OBJECT_ID('tempdb..#TBLDATA') IS NOT NULL DROP TABLE #TBLDATA; 
IF OBJECT_ID('tempdb..#FINAL_DATA') IS NOT NULL DROP TABLE #FINAL_DATA;
--- Get sorted out

--- Clean up pressure on locking tables: 
IF OBJECT_ID('tempdb..#um_auth_provider') IS NOT NULL DROP TABLE #um_auth_provider ;
IF OBJECT_ID('tempdb..#um_auth') IS NOT NULL DROP TABLE #um_auth;
IF OBJECT_ID('tempdb..#um_auth_code') IS NOT NULL DROP TABLE #um_auth_code; 
IF OBJECT_ID('tempdb..#um_ma_procedure_codes') IS NOT NULL DROP TABLE #um_ma_procedure_codes;  -- large table, small changes, but lock happens on this in combination
--- This will be  

--- Now create tables that might be in lock
IF OBJECT_ID('tempdb..#um_auth_provider') IS NULL 
	BEGIN
		SELECT *
		INTO #um_auth_provider 
		FROM [Altruista].[dbo].UM_AUTH_PROVIDER;
	END

IF OBJECT_ID('tempdb..#um_auth') IS NULL  
	BEGIN
		SELECT *
		INTO #um_auth 
		FROM [Altruista].[dbo].UM_AUTH;
	END

IF OBJECT_ID('tempdb..#um_auth_code') IS NULL  
	BEGIN
		SELECT *
		INTO #um_auth_code
		FROM [Altruista].[dbo].UM_AUTH_CODE;
	END

IF OBJECT_ID('tempdb..#um_ma_procedure_codes') IS NULL  
	BEGIN
		SELECT *
		INTO #um_ma_procedure_codes
		FROM [Altruista].[dbo].UM_MA_PROCEDURE_CODES;
	END



-- added for CarePartner
IF OBJECT_ID('tempdb..#GCPrimCM') IS NULL  
	BEGIN
		; WITH PrimCareStaff AS (
		   SELECT
				  pd.CLIENT_PATIENT_ID AS 'CCAID'
				  , pd.PATIENT_ID
				  , pp.PHYSICIAN_ID AS 'PhysID'
				  , r.ROLE_NAME AS 'PhysRole'
				  , cs.TITLE
				  , cs.FIRST_NAME
				  , cs.LAST_NAME
		   FROM Altruista.dbo.PATIENT_DETAILS AS pd
		   INNER JOIN Altruista.dbo.PATIENT_PHYSICIAN AS pp
				  ON pd.PATIENT_ID = pp.PATIENT_ID
				  AND pp.CARE_TEAM_ID = 1
				  AND pp.IS_ACTIVE = 1
				  AND pp.DELETED_ON IS NULL
		   INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS cs
				  ON pp.PHYSICIAN_ID = cs.MEMBER_ID
		   LEFT JOIN Altruista.dbo.[ROLE] AS r
				  ON cs.ROLE_ID = r.ROLE_ID
				  AND r.IS_ACTIVE = 1
				  AND r.DELETED_ON IS NULL
		   WHERE LEFT(pd.CLIENT_PATIENT_ID, 3) = '536'
				  AND pd.DELETED_ON IS NULL
	), PrimCM AS (
		   SELECT
				  pd.CLIENT_PATIENT_ID AS 'CCAID'
				  , pd.PATIENT_ID
				  , mc.MEMBER_ID
				  , CASE WHEN cs.LAST_NAME IS NULL AND cs.MIDDLE_NAME IS NOT NULL THEN cs.MIDDLE_NAME + ', ' + cs.FIRST_NAME
						 ELSE cs.LAST_NAME + ', ' + cs.FIRST_NAME END AS 'PrimCareMgr'
				  , cs.LAST_NAME
				  , cs.FIRST_NAME
				  , cs.MIDDLE_NAME
				  , r.ROLE_NAME AS 'PrimCareMgrRole'
				  , mc.CREATED_ON
		   FROM Altruista.dbo.PATIENT_DETAILS AS pd
		   INNER JOIN Altruista.dbo.MEMBER_CARESTAFF AS mc
				  ON pd.PATIENT_ID = mc.PATIENT_ID
		   INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS cs
				  ON mc.MEMBER_ID = cs.MEMBER_ID
		   LEFT JOIN Altruista.dbo.[ROLE] AS r
				  ON cs.ROLE_ID = r.ROLE_ID
				  AND r.IS_ACTIVE = 1
				  AND r.DELETED_ON IS NULL
		   WHERE LEFT(pd.CLIENT_PATIENT_ID, 3) = '536'
				  AND mc.IS_ACTIVE = 1
				  AND mc.IS_PRIMARY = 1
	), GCprimCM AS (
		   SELECT
				  pc.CCAID
				  , pc.PATIENT_ID
				  , pc.MEMBER_ID AS 'PrimCareMgrID'
				  , pc.PrimCareMgr
				  , pc.PrimCareMgrRole

				  , pcs.PhysID
				  , pcs.PhysRole
				  , pcs.FIRST_NAME
				  , pcs.LAST_NAME
				  , CASE WHEN pc.MEMBER_ID = pcs.PhysID THEN 'Y' ELSE 'N' END AS 'CMtoPhysMatch'
				  , DENSE_RANK() OVER (PARTITION BY pc.CCAID ORDER BY CASE WHEN pc.MEMBER_ID = pcs.PhysID THEN 'Y' ELSE 'N' END DESC) AS 'PCMrank'
				  , ROW_NUMBER() OVER (PARTITION BY pc.CCAID ORDER BY CASE WHEN pc.MEMBER_ID = pcs.PhysID THEN 'Y' ELSE 'N' END DESC, pc.CREATED_ON) AS 'RowNo'
		   FROM PrimCM AS pc
		   LEFT JOIN PrimCareStaff AS pcs
				  ON pc.CCAID = pcs.CCAID
				  AND pc.MEMBER_ID = pcs.PhysID
	)
	SELECT
		   *
	INTO #GCprimCM
	FROM GCPrimCM
	WHERE PCMrank = 1
		   AND RowNo = 1


	END 
-- Care partner
--Select * from #GCprimCM
--- Finish up with lock costing tables.

CREATE TABLE #MANAGERS_REFER_TO (MEMBER_ID BIGINT);

--DECLARE @TBLDATA TABLE (CFG_ADMIN_CONFIG_ID BIGINT);
--INSERT INTO @TBLDATA -- Edited - Abhishek - 05/24/2019
SELECT DISTINCT
    CUC.CFG_ADMIN_CONFIG_ID
INTO #TBLDATA
FROM Altruista.dbo.CFG_USER_CONFIG CUC
    INNER JOIN Altruista.dbo.CFG_ACCESS CC 
        ON CC.CFG_ADMIN_CONFIG_ID = CUC.CFG_ADMIN_CONFIG_ID
    INNER JOIN Altruista.dbo.CFG_ACCESS_TYPE CACT
        ON CACT.CFG_ACCESS_TYPE_ID = CC.CFG_ACCESS_TYPE_ID
    INNER JOIN Altruista.dbo.CFG_ADMIN_CONFIG CAC
        ON CAC.CFG_ADMIN_CONFIG_ID = CUC.CFG_ADMIN_CONFIG_ID
WHERE CUC.IS_ACTIVE = 1
      AND CC.IS_ACTIVE = 1
      AND CAC.IS_ACTIVE = 1
      AND CAC.DELETED_BY IS NULL
      AND CACT.DELETED_BY IS NULL
      AND CC.DELETED_BY IS NULL;

--CREATE NONCLUSTERED INDEX ix_TBLDATA ON #TBLDATA ([CFG_ADMIN_CONFIG_ID]);
 

INSERT INTO #MANAGERS_REFER_TO
SELECT DISTINCT
    MEMBER_ID AS CONFIG_ID
FROM Altruista.dbo.CFG_USER_CONFIG CG
INNER JOIN #TBLDATA TD ON TD.CFG_ADMIN_CONFIG_ID = CG.CFG_ADMIN_CONFIG_ID
WHERE IS_ACTIVE = 1
      AND MEMBER_ID IS NOT NULL;

--DECLARE @FINAL_DATA TABLE
--(
--    ID INT IDENTITY(1, 1),
--    REFERRAL_ID BIGINT,
--    PATIENT_ID BIGINT
--);

--INSERT INTO @FINAL_DATA
--(
--    REFERRAL_ID,
--    PATIENT_ID
--)-- Edited - Abhishek - 05/24/2019
SELECT UR.REFERRAL_ID,
           UA.PATIENT_ID--,
           --UR.QUEUE_ID,
           --UMAT.AUTH_TYPE_NAME
	INTO #FINAL_DATA
    FROM Altruista.dbo.UM_REFERRAL UR
        INNER JOIN Altruista.dbo.UM_AUTH UA
            ON UR.REFERRAL_REF_ID = UA.AUTH_NO
               AND UR.LEVEL_ID = 2
               AND UR.DELETED_BY IS NULL
               AND UR.REFERRAL_STATUS_ID IN ( 1, 2 )
               AND UR.DELETED_BY IS NULL
        INNER JOIN Altruista.dbo.PATIENT_DETAILS PD
            ON PD.PATIENT_ID = UA.PATIENT_ID
               AND PD.DELETED_BY IS NULL
        LEFT JOIN Altruista.dbo.UM_REFERRAL_QUEUE URQ
            ON URQ.QUEUE_ID = UR.QUEUE_ID
               AND URQ.DELETED_BY IS NULL
        INNER JOIN #MANAGERS_REFER_TO A
            ON A.MEMBER_ID = UR.CREATED_BY
        LEFT JOIN Altruista.dbo.UM_MA_AUTH_TYPE UMAT
            ON UMAT.AUTH_TYPE_ID = UA.AUTH_TYPE_ID
    WHERE 1 = 1
    UNION
    SELECT UR.REFERRAL_ID,
           UA.PATIENT_ID--,
           --UR.QUEUE_ID,
           --UMAT.AUTH_TYPE_NAME
    FROM Altruista.dbo.UM_REFERRAL UR
        INNER JOIN Altruista.dbo.UM_AUTH UA
            ON UR.REFERRAL_REF_ID = UA.AUTH_NO
               AND UR.LEVEL_ID = 2
               AND UR.DELETED_BY IS NULL
               AND UR.REFERRAL_STATUS_ID = 4
               AND UR.DELETED_BY IS NULL
        INNER JOIN #MANAGERS_REFER_TO A
            ON A.MEMBER_ID = UR.UPDATED_BY
        INNER JOIN Altruista.dbo.PATIENT_DETAILS PD
            ON PD.PATIENT_ID = UA.PATIENT_ID
               AND PD.DELETED_BY IS NULL
        LEFT JOIN Altruista.dbo.UM_REFERRAL_QUEUE URQ
            ON URQ.QUEUE_ID = UR.QUEUE_ID
               AND URQ.DELETED_BY IS NULL
        LEFT JOIN Altruista.dbo.UM_MA_AUTH_TYPE UMAT
            ON UMAT.AUTH_TYPE_ID = UA.AUTH_TYPE_ID
    WHERE 1 = 1

--SELECT TBL.REFERRAL_ID,
--       TBL.PATIENT_ID
--INTO #FINAL_DATA
--FROM #REFPAT TBL


select * into #test from #FINAL_DATA

SELECT AUTH_ID,
       CAST(UA.AUTH_NO AS VARCHAR(20)) AS AUTH_NO,
       AUTH_TYPE_NAME,
       CONCAT(PD.FIRST_NAME, ' ', +PD.LAST_NAME) AS PATIENT_NAME,       
       UR.REFERRAL_ID,
       UA.PATIENT_ID,
       REFERRAL_REQ_DATE AS REFERRED_DATE,
       --dbo.UDF_AHS_UM_AUTH_TAT_DUE_DATE(UA.AUTH_NO) AS DUE_DATE,
       CONCAT(CSD.FIRST_NAME, ' ', +CSD.LAST_NAME) AS REFERRED_BY_NAME,
	   CSD.MEMBER_ID AS REFERRED_BY_NAME_ID,--sara added to connect to use to determine what department they are in
       CONCAT(CSD1.FIRST_NAME, ' ', +CSD1.LAST_NAME) AS REFERRED_TO_NAME,
	     CSD1.MEMBER_ID AS REFERRED_TO_NAME_ID,--sara added to connect to use to determine what department they are in
       CASE
           WHEN UR.REFERRAL_STATUS_ID = 1 THEN
               'Pending Acceptance'
           WHEN UR.REFERRAL_STATUS_ID = 2 THEN
               'Accepted'
           WHEN UR.REFERRAL_STATUS_ID = 4 THEN
               'Rejected'
       END AS STATUS,
       CONCAT(CSD2.FIRST_NAME, ' ', +CSD2.LAST_NAME) AS ACCEPTED_BY_NAME,
       CASE
           WHEN UR.REFERRAL_STATUS_ID = 2 THEN
               UR.UPDATED_ON
       END AS ACCEPTED_ON,
       UMATP.AUTH_PRIORITY,
       UR.QUEUE_ID,
       IIF(ISNULL(UR.QUEUE_ID, 0) = 0, 'No', 'Yes') AS WORK_QUEUE,
       PD.CLIENT_PATIENT_ID,
       IIF(PPA.PRIVACY_ADDRESS_ID IS NOT NULL, PPA.ZIP, IIF(PPR.PREFERRED_ADDRESS_ID IS NOT NULL, PPR.ZIP, PD.ZIP)) AS ZIP_CODE,
       IIF(PPA.PRIVACY_ADDRESS_ID IS NOT NULL,
           PPA.STATE,
           IIF(PPR.PREFERRED_ADDRESS_ID IS NOT NULL, PPR.STATE, PD.STATE)) AS STATE,
       UA.CREATED_ON AS CREATED_DATE,
       D.DEPT_NAME AS DEPT_NAME
INTO #TEMP
FROM #test FD
    INNER JOIN Altruista.dbo.UM_REFERRAL UR
        ON UR.REFERRAL_ID = FD.REFERRAL_ID
    INNER JOIN #um_auth /*Altruista.dbo.UM_AUTH*/ UA
        ON UA.AUTH_NO = UR.REFERRAL_REF_ID
    INNER JOIN Altruista.dbo.PATIENT_DETAILS PD
        ON UA.PATIENT_ID = PD.PATIENT_ID
    LEFT JOIN Altruista.dbo.CARE_STAFF_DETAILS CSD
        ON CSD.MEMBER_ID = IIF(UR.REFERRAL_STATUS_ID = 4, UR.UPDATED_BY, UR.REFERRAL_REQ_FROM)
    LEFT JOIN Altruista.dbo.CARE_STAFF_DETAILS CSD2
        ON CSD2.MEMBER_ID = UR.UPDATED_BY
           AND UR.REFERRAL_STATUS_ID = 2
    LEFT JOIN Altruista.dbo.CARE_STAFF_DETAILS CSD1
        ON CSD1.MEMBER_ID = IIF(UR.REFERRAL_STATUS_ID = 4, UR.REFERRAL_REQ_FROM, UR.REFERRAL_REQ_TO)
    LEFT JOIN Altruista.dbo.UM_MA_AUTH_TYPE UMAT
        ON UMAT.AUTH_TYPE_ID = UA.AUTH_TYPE_ID
    LEFT JOIN Altruista.dbo.UM_MA_AUTH_TAT_PRIORITY UMATP
        ON UMATP.AUTH_PRIORITY_ID = UA.AUTH_PRIORITY_ID
    LEFT JOIN Altruista.dbo.PATIENT_PRIVACY_ADDRESS PPA
        ON PPA.PATIENT_ID = PD.PATIENT_ID
           AND PPA.DELETED_BY IS NULL
           AND PPA.DELETED_ON IS NULL
    LEFT JOIN Altruista.dbo.PATIENT_PREFERRED_ADDRESS PPR
        ON PD.PATIENT_ID = PPR.PATIENT_ID
           AND PPR.DELETED_BY IS NULL
           AND PPR.DELETED_ON IS NULL
    LEFT JOIN Altruista.dbo.UM_REFERRAL_QUEUE URQ
        ON URQ.QUEUE_ID = UR.QUEUE_ID
    LEFT JOIN Altruista.dbo.UM_REFERRAL_QUEUE_DEPARTMENT URQD
        ON URQD.UM_REFERRAL_QUEUE_ID = URQ.UM_REFERRAL_QUEUE_ID
           AND URQD.DELETED_BY IS NULL
    LEFT JOIN Altruista.dbo.CARE_STAFF_DEPARTMENT CCSD
        ON CCSD.CARE_STAFF_ID = ISNULL(UR.REFERRAL_REQ_TO, URQ.staff_id)
           AND CCSD.IS_WORK_QUEUE = 1
           AND URQD.DEPT_ID = CCSD.DEPT_ID
    LEFT JOIN Altruista.dbo.DEPARTMENT D
        ON D.DEPT_ID = URQD.DEPT_ID
--ORDER BY FD.ID;

CREATE NONCLUSTERED INDEX [IX_TEMP]
ON [dbo].[#TEMP] ([REFERRED_DATE])
INCLUDE ([Auth_ID],[AUTH_TYPE_NAME],[PATIENT_NAME],[REFERRED_BY_NAME],[REFERRED_BY_NAME_ID],[REFERRED_TO_NAME],[REFERRED_TO_NAME_ID],[STATUS],[ACCEPTED_ON],[AUTH_PRIORITY],[WORK_QUEUE],[CLIENT_PATIENT_ID],[ZIP_CODE],[STATE],[CREATED_DATE],[DEPT_NAME])

SELECT 
    CLIENT_PATIENT_ID AS [Altruista ID],
    t.AUTH_ID AS [Auth ID],
    AUTH_TYPE_NAME AS [Auth Type],
    AUTH_PRIORITY AS [Auth Priority],
    --DUE_DATE AS 'Due Date',
    PATIENT_NAME AS [Member Name],
    REFERRED_BY_NAME AS [Referred By],
	  REFERRED_BY_NAME_ID,
    REFERRED_TO_NAME AS [Referred To],
	  REFERRED_TO_NAME_ID,
    DEPT_NAME AS [Referred To WQ Name],
    STATUS AS [Status],
    STATE AS [State],
    ZIP_CODE AS [Zip],
    CREATED_DATE AS [Created Date],
    REFERRED_DATE AS [Max Refer Date],
	work_queue,
	max(accepted_on) as [Max Accepted Date]---taking the latest accepeted date

	into  #UMworklog
FROM #TEMP t
inner join (select auth_id, max(REFERRED_DATE) AS [maxReferDate] from #temp group by auth_id
--order by auth_id
) m on t.auth_id=m.auth_id and t.[referred_date]=m.maxreferdate

group by

 CLIENT_PATIENT_ID ,
    t.AUTH_ID ,
    AUTH_TYPE_NAME ,
    AUTH_PRIORITY ,
    --DUE_DATE AS 'Due Date',
    PATIENT_NAME ,
    REFERRED_BY_NAME ,
	  REFERRED_BY_NAME_ID,
    REFERRED_TO_NAME ,
	  REFERRED_TO_NAME_ID,
    DEPT_NAME,
    [STATUS],
    STATE ,
    ZIP_CODE ,
    CREATED_DATE,
	 REFERRED_DATE ,
	 work_queue,
	 	accepted_on
ORDER BY CLIENT_PATIENT_ID;

SELECT  
  [Altruista ID],
  [Auth ID],
   [Auth Type],
    [AUTH PRIORITY],
    --DUE_DATE AS 'Due Date',
    [Member Name],
    [Referred By],
	  REFERRED_BY_NAME_ID,
    [Referred To],
	  REFERRED_TO_NAME_ID,
    --[Referred To WQ Name],
    [STATUS] ,
    [STATE] ,
   [Zip],
    [Created Date],
    [Max Refer Date],
	[Max Accepted Date],
work_queue
,isnull([1],'') as WQName1,isnull([2],'') as WQName2,isnull([3],'') as WQName3
, isnull([4],'') as WQName4, isnull([5],'') as WQName5, isnull([6],'') as WQName6
, isnull([7],'') as WQName7
into #UMworklogfinal
		FROM (SELECT * 
				,   dense_rank () over (partition by  [auth id] order by [Referred To WQ Name] desc) as deptORDER
				FROM  #UMworklog )p
		pivot
		(max([Referred To WQ Name]) for [deptorder] in ([1],[2],[3], [4], [5],[6],[7])
		)as pvt


-----------WLM_fixed END-------------------------

---- Monitoring CMP start ----- 
IF OBJECT_ID('tempdb..#carestaff') IS NOT NULL DROP TABLE #carestaff;
IF OBJECT_ID('tempdb..#carestaffgroup') IS NOT NULL DROP TABLE #carestaffgroup;
IF OBJECT_ID('tempdb..#STEP1') IS NOT NULL DROP TABLE #STEP1;
IF OBJECT_ID('tempdb..#STEP2') IS NOT NULL DROP TABLE #STEP2;
IF OBJECT_ID('tempdb..#final') IS NOT NULL DROP TABLE #final;

---------This creates temp table for carestaff and their respective role/department which is used later in the query

--IF OBJECT_ID('tempdb..#carestaff') IS NOT NULL DROP TABLE #carestaff;
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

--IF OBJECT_ID('tempdb..#carestaffgroup') IS NOT NULL DROP TABLE #carestaffgroup;
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

--IF OBJECT_ID('tempdb..#STEP1') IS NOT NULL DROP TABLE #STEP1;
select 
pd.[LAST_NAME] 
, pd.[FIRST_NAME]
, pd.[CLIENT_patient_ID] as CCAID
--,lan.LANGUAGE_NAME
, CMBD.Business_data_Name as plan_name 
, a.[AUTH_ID]
, a.AUTH_NOTI_DATE as Received_date
, ud.[SERVICE_FROM_DATE] AS [SERVICE_FROM_DATE]
, ud.[SERVICE_TO_DATE] AS [SERVICE_TO_DATE]
, coalesce (s.SERVICE_CODE, sv.proc_code)  as proc_code
, coalesce ( cat2.proc_category, cat.proc_category)  as TypeofCode
, coalesce (sp.service_category_label, svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION) as proc_description
, ud.current_requested as UnitsRequested
, ud.current_approved  as UnitsApproved
, tat.auth_priority
, stat.auth_status
, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(MAX),usr.auth_status_reason_name),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  as [auth_status_reason_name]
, case 
	when a.IS_EXTENsion = 1 then 'Yes'
	   else 'No' 
   end as [IS_EXTENsion]
,  case when a.is_extension=0 or a.is_extension is null then 'NA'
WHEN  extdoc.document_ref_id is not null then 'Y' else 'N' end as [Is there an Extension letter created]
, decs.decision_Status
, decstc.[DECISION_STATUS_CODE_DESC]
 
, case when act.[MD review Completed date] is not null then act.[MD review Completed date]
-----On November 27, 2018 Amelia Levy said to use the MD review completed date as the decision date for denials
else  ud.replied_date end as Decision_Date
, case when decs.decision_status in ('denied', 'partially approved')  and ud.MEMBER_NOTIFICATION_DATE is not null AND ud.MEMBER_NOTIFICATION_TYPE_ID=4  then --specified to only pick up phone, not written
convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
when  cast (ud.MEMBER_NOTIFICATION_DATE as date) >= '2019-03-18'---date when UM STARTED CALLING 
   AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
else ' '
END
as 'Verbal Notification'


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
--ROBIN
, cmo.Company as CMO_At_AuthCreatedDate
, cmor.Eff_Date as cmo_eff_date
, cmor.Term_Date as cmo_term_Date
, CP.PrimCareMgr as Care_Partner
--ROBIN
,  cs.LAST_NAME + ',' + cs.First_NAME as [Auth owner]
, cs.role_name as [Auth Owner Role]
, cs.[department name(s)] as [Auth Owner Department(s)]
,byprov.provider_name as ReferredBy
,prov.provider_name as ReferredTo
,case 
when palogic.code IN ('0425','0428','0424','0434','G0176') and [PLACE_OF_SERVICE_CODE] = '12' 
then 'Home Health'
when palogic.code IN ('100','101','0100','0101') and [PLACE_OF_SERVICE_CODE] = '51'
then 'BH'
when palogic.code IN ('11055','11056','11719','11720','11721','11722','11723','11724','11725','11726','11727','11728','11729','11730','11731','11732','11733','11734','11735','11736','11737','11738','11739','11740','11741','11742',
'11743','11744','11745','11746','11747','11748','11749','11750','11751','11752','11753','11754','11755','11756','11757','11758','11759','11760','11761','11762','11763','11764','11765','92506','92507','92526',
'97001','97002','97003','97039','97100','97110','97113','97116','97124','97161','97162','97163','97164','97165','97166','97167','97168','97169','97170','97171','97172','97530','G0127','Q0103') and [PLACE_OF_SERVICE_CODE] = '31'
then 'TOC'
when palogic.code is null then 'Procedure' -- when the code is not in list, assign to Procedure
else palogic.team 
end as [Team]

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
 end as [letter_created_on]
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
 
   ,  authcr.LAST_NAME + ',' + authcr.First_NAME as [AuthCreatedBy]
   , authcr.role_name as [Auth Createdby Role]
, authcr.[department name(s)] as [Auth CreatedBy Department(s)]

   , a.created_on as [AuthCreatedDate]
 --,admit.provider_name as AdmittingProvider
  ,fac.provider_name as Facility
  , [CUST_DATA_TYPE_VALUE] as [Source of Service Request]
  , request_name as [Mode of Request]
 --  ,servic.provider_name as ServicingProvider
 --  , urs.[REFERRAL_STATUS_NAME]
 --  , ad.dept_name
into #STEP1
from #um_auth /*[Altruista].dbo.um_auth*/ a
left join  [Altruista].[dbo].[patient_details] pd on a.patient_id = pd.[PATIENT_ID] and pd.deleted_on is null

--Changes for Guiding Care Upgrade 
--left join [Altruista].[dbo].[lob_benf_plan] lb on a.[LOB_BEN_ID] = lb.lob_ben_id and lb.deleted_on is null
  left join [Altruista].[dbo].[CMN_MA_BUSINESS_HIERARCHY] CMBH on a.[LOB_BEN_ID] = CMBH.lob_ben_id and CMBH.deleted_on is null
--left join  [Altruista].[dbo].[lob] l on lb.[LOB_ID] = l.lob_id and l.deleted_on is null
  left join  [Altruista].[dbo].[CMN_MA_BUSINESS_DATA] CMBD on CMBH.[BUSINESS_DATA_ID] = CMBD.[BUSINESS_DATA_ID] and CMBD.deleted_on is null


--left join [Altruista].[dbo].benefit_plan b on l.benefit_plan_id = b.benefit_plan_id
left join #um_auth_provider /*[Altruista].[dbo].UM_AUTH_PROVIDER*/ prov on a.auth_no = prov.auth_no  and prov.provider_type_id = 3 and prov.deleted_on is null-- 3 means referred to-- needs another join
left join #um_auth_provider /*[Altruista].[dbo].UM_AUTH_PROVIDER*/ byprov on a.auth_no = byprov.auth_no  and byprov.provider_type_id = 2 and byprov.deleted_on is null-- 2 means referred by-- needs another join
left join #um_auth_provider /*[Altruista].[dbo].UM_AUTH_PROVIDER*/ admit on a.auth_no = admit.auth_no  and admit.provider_type_id = 1 and admit.deleted_on is null-- 1 means admitting provider-- needs another join
left join #um_auth_provider/*[Altruista].[dbo].UM_AUTH_PROVIDER*/ fac on a.auth_no = fac.auth_no  and fac.provider_type_id = 4 and fac.deleted_on is null-- 4 means facility
left join #um_auth_provider /*[Altruista].[dbo].UM_AUTH_PROVIDER*/ servic on a.auth_no = servic.auth_no  and servic.provider_type_id = 5 and servic.deleted_on is null--5 means service
--left join [Altruista].[dbo].[PROVIDER_NETWORK] pn on pn.[PROVIDER_ID] = prov.auth_no
left join  #um_auth_code /*[Altruista].[dbo].UM_AUTH_CODE*/ Pac on  a.auth_no  = Pac.auth_no and AUTH_CODE_TYPE_ID in ( 1,5) and pac.deleted_on is null-- splits the auth into auth lines
left join  [Altruista].[dbo].UM_DECISION ud on  a.auth_no  = ud.auth_no and Pac.auth_code_id = ud.auth_code_id and ud.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS decs on ud.DECISION_status = decs.DECISION_STATUS_ID and decs.deleted_on is null
left join [Altruista].[dbo].uM_MA_DECISION_STATUS_codes decstc on ud.DECISION_status_code_id = decstc.DECISION_STATUS_code_ID and decstc.deleted_on is null

--Changed for Guiding Care Upgrade . this cndition is not needed anymore 
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
       end as [Letter Date]
	   ,  max(created_on) as maxcreatedon
       from Altruista.dbo.um_document
       where
	 ((document_name like '%denial%' and  document_type_id in (1,2)) or  document_type_id=6)
       and DELETED_ON is null
	 
       group by document_ref_id)a
	    inner join  Altruista.dbo.um_document b on a.document_ref_id=b.document_ref_id and b.deleted_on is null and a. maxcreatedon=b.created_on
		left join  [Altruista].[dbo].[CARE_STAFF_DETAILS] cs on b.created_by=cs.member_id
		group by   a.document_ref_id, a.[letter date], b.created_on, b.created_by, cs.last_name+ ',' + cs.first_name ,  letter_printed_date
      
) dendoc on a.auth_no=dendoc.document_ref_id 
left join  #um_ma_procedure_codes /*[Altruista].[dbo].UM_MA_PROCEDURE_CODES*/ sv on Pac.auth_code_ref_id = sv.PROC_CODE and sv.PROC_CATEGORY_ID in (1,2, 3,7) and sv.deleted_on is null -- hcpcs, cpt, revcode or ICD10Proc

-- now join again to the sercice code table to get the items that are not being coded correctly as ProcCode

left join [Altruista].[dbo].[SERVICE_CODE] s on pac.[AUTH_CODE_REF_ID]=cast (s.SERVICE_ID as varchar) and pac.[AUTH_CODE_type_ID]=5 and s.deleted_on is null
left join   #um_ma_procedure_codes/*[Altruista].[dbo].UM_MA_PROCEDURE_CODES*/ svc on  s.service_code = svc.proc_code  and svc.deleted_on is null-- hcpcs, cpt, revcode or ICD10Proc---this is to hget the description for the special service category codes
--left join  /*[Altruista].[dbo].UM_MA_PROCEDURE_CODES*/ sv2 on Pac.auth_code_ref_id = sv2.PROC_CODE and sv2.PROC_CATEGORY_ID in (1,2, 3,7) -- hcpcs, cpt, revcode or ICD10Proc
left join  [Altruista].[dbo].[UM_MA_PROCEDURE_CODE_CATEGORY] cat on sv.PROC_CATEGORY_ID= cat.PROC_CATEGORY_ID and cat.deleted_on is null
left join  [Altruista].[dbo].[UM_MA_PROCEDURE_CODE_CATEGORY] cat2 on svc.PROC_CATEGORY_ID= cat2.PROC_CATEGORY_ID and cat2.deleted_on is null
left join   [Altruista].[dbo].[UM_MA_AUTH_STATUS] stat on a.AUTH_STATUS_ID = stat.AUTH_STATUS_ID and stat.deleted_on is null
left join [Altruista].[dbo].[LANGUAGE] lan on pd.PRIMARY_LANGUAGE_ID = lan.language_id and lan.deleted_on is null
left join [Altruista].[dbo].[UM_MA_AUTH_STATUS_reason] usr on a.[AUTH_STATUS_reason_ID]=usr.[AUTH_STATUS_reason_ID] and usr.deleted_on is null
left JOIN [Altruista].dbo.PATIENT_PHYSICIAN pp ON pd.PATIENT_ID = pp.PATIENT_ID AND  CARE_TEAM_ID IN (1,2) AND pp.PROVIDER_TYPE_ID = 181 AND -- cmo
CAST(GETDATE() AS DATE) BETWEEN pp.[START_DATE] and pp.END_DATE and
                    pp.DELETED_ON IS NULL AND
                    pp.IS_ACTIVE = 1
LEFT JOIN [Altruista].dbo.PHYSICIAN_DEMOGRAPHY pdv ON pp.physician_id = pdv.physician_id 
--Robin added to get CMO at time of authCreatedDate
LEFT JOIN [MPSnapshotProd].[dbo].[NAME] nm on nm.text2 = pd.client_patient_ID 
LEFT JOIN  [MPSnapshotProd].[dbo].[NAME_PROVIDER] AS cmor 		
ON nm.NAME_ID = cmor.NAME_ID AND cmor.SERVICE_TYPE = 'Care Manager Org' and  a.created_on between cmor.Eff_date and COALESCE(cmor.Term_date, '9999-12-30') --a.created_on
LEFT JOIN [MPSnapshotProd].[dbo].[NAME] AS cmo 
			ON cmor.PROVIDER_ID = cmo.NAME_ID
--
left join  [Altruista].[dbo].[SERVICE_plan] sp on pac.[AUTH_CODE_REF_ID]=cast (sp.SERVICE_ID as varchar) and pac.[AUTH_CODE_type_ID]=5 and sp.deleted_on is null
--
--CarePartner
LEFT JOIN #GCprimCM CP on CP.CCAID = pd.client_patient_ID 

-- RED updated 11/26/2019 per email from Sara on 10/28/2019
left join (SELECT
      [ACTIVITY_LOG_REF_ID],
         max ([activity_log_followup_date]) as 'MD review Completed date'
  FROM  [Altruista].[dbo].[UM_ACTIVITY_LOG]
  where   [ACTIVITY_type_id]=4

  and deleted_on is null
  group by
  [ACTIVITY_LOG_REF_ID])act on a.auth_no=act.activity_log_ref_id
	   LEFT JOIN (select document_ref_id from Altruista.dbo.um_document where ((document_name like '%exten%' and document_type_id in (1,2)) or (document_name like '%exten%' and document_type_id =12 and (DOCUMENT_DESC like '%extension letter%')))
	  and deleted_on is null group by document_ref_id ) extdoc on a.auth_no=extdoc.document_ref_id ---looks for extension letters in certain document types as using document name only is inaccurate

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
left join #carestaffgroup cs on a.AUTH_CUR_OWNER=cs.member_id
left join #carestaffgroup authcr on a.CREATED_BY=authcr.member_id
left join  [Altruista].[dbo].[AUTH_CUSTOM_FIELD_VALUE] acf on a.auth_no=acf.auth_no and acf.deleted_on is null and acf.cust_field_id = 1----this is where you can find the source of the request
left join [Altruista].[dbo].[UM_MA_CUSTOM_DATA_TYPE_VALUES] umc on acf.cust_field_value=umc.[CUST_DATA_TYPE_VALUE_ID] and umc.deleted_on is null
left join [Altruista].[dbo].[UM_MA_REQUEST_SENT_MODE] umr on a.request_sent_mode=umr.request_id and umr.deleted_on is null
left join [Medical_Analytics].[dbo].[PAcode_logic] palogic
on RTRIM(LTRIM(coalesce(s.SERVICE_CODE, sv.proc_code))) = palogic.code
where 
--LOB_name = 'Medicare-Medicaid Duals' and 
pd.[CLIENT_patient_ID] like '53%'--picking up ccaids only and not test cases
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
, CMBD.BUSINESS_DATA_NAME
,a.[AUTH_ID]
,a.AUTH_NOTI_DATE 
--, convert(varchar, a.AUTH_NOTI_DATE, 108) as 'Time the request was received'
,ud.[SERVICE_FROM_DATE] 
, ud.[SERVICE_TO_DATE] 
, coalesce ( s.SERVICE_CODE, sv.proc_code)  
, coalesce ( cat2.proc_category, cat.proc_category) 
,coalesce (sp.service_category_label, svc.PROC_DESCRIPTION, sv.PROC_DESCRIPTION) 
, current_requested 
, current_approved 
,auth_priority
 , auth_status
, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(MAX),auth_status_reason_name),
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

, case when decs.decision_status in ('denied', 'partially approved')  and ud.MEMBER_NOTIFICATION_DATE is not null AND ud.MEMBER_NOTIFICATION_TYPE_ID=4  then --specified to only pick up phone, not written
convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
when  cast (ud.MEMBER_NOTIFICATION_DATE as date) >= '2019-03-18'---date when UM STARTED CALLING 
   AND ud.MEMBER_NOTIFICATION_TYPE_ID=4 then convert(varchar, ud.MEMBER_NOTIFICATION_DATE  , 120)
else ' '
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
--ROBIN
, cmo.Company 
, cmor.Eff_Date 
, cmor.Term_Date
, CP.PrimCareMgr
--ROBIN
,  cs.LAST_NAME + ',' + cs.First_NAME 
,byprov.provider_name 
,prov.provider_name 
,case 
when palogic.code IN ('0425','0428','0424','0434','G0176') and [PLACE_OF_SERVICE_CODE] = '12' 
then 'Home Health'
when palogic.code IN ('100','101','0100','0101') and [PLACE_OF_SERVICE_CODE] = '51'
then 'BH'
when palogic.code IN ('11055','11056','11719','11720','11721','11722','11723','11724','11725','11726','11727','11728','11729','11730','11731','11732','11733','11734','11735','11736','11737','11738','11739','11740','11741','11742',
'11743','11744','11745','11746','11747','11748','11749','11750','11751','11752','11753','11754','11755','11756','11757','11758','11759','11760','11761','11762','11763','11764','11765','92506','92507','92526',
'97001','97002','97003','97039','97100','97110','97113','97116','97124','97161','97162','97163','97164','97165','97166','97167','97168','97169','97170','97171','97172','97530','G0127','Q0103') and [PLACE_OF_SERVICE_CODE] = '31'
then 'TOC'
when palogic.code is null then 'Procedure' -- when the code is not in list, assign to Procedure
else palogic.team 
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
   , authcr.role_name
   , cs.role_name
   , cs.[department name(s)]
      , authcr.[department name(s)]
   --   , urs.[REFERRAL_STATUS_NAME]
   --, ad.dept_name
     , [CUST_DATA_TYPE_VALUE] 
  , request_name

-- If the S5102 or any of the LTSS codes and the following transportation code are in a same auth, then the whole auth will change to team LTSS(S5102)

begin tran
delete from #STEP1
where rtrim(ltrim(proc_code)) in ('99284','H0011','S9458','H0010')
--
commit tran



IF OBJECT_ID('tempdb..#T2003') IS NOT NULL DROP TABLE #T2003;

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

--- If any of the following codes in a auth id, then that code will belong to that main team in that auth
;with junk as
(
	select distinct [AUTH_ID], TEAM
	FROM #step1
	where [AUTH_ID] in 
	(
		select distinct [AUTH_ID]--, team
		from #step1
		where RTRIM(LTRIM(proc_code)) IN ('99213','99212','99214','99215','99211','99202','99201','99203','99204','99205','99245')
	)
	--order by 1,2
)
,junk2 as
(
	select distinct auth_id, count(*) as temp
	from junk
	group by auth_id
	having count(*) = 2
	--order by 1
)
,junk3 as
(
	select distinct auth_id, team
	from #step1
	where auth_id in
	(
		select distinct auth_id
		from junk2
	)
	and team <> 'Procedure'
)

SELECT 

 [LAST_NAME]
      ,[FIRST_NAME]
      ,[CCAID]
      ,plan_name 
      ,s.[AUTH_ID]
	  ,[Received_date] as [Received Date]
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
	  ,[Decision_Date] as [Decision Date]
      ,[Verbal Notification]
      ,[WrittenNotifDate]
      ,[auth_type_name]
      ,[PLACE_OF_SERVICE_CODE]
      ,[PLACE_OF_SERVICE_NAME]
      ,[CMO]
	  ,CMO_At_AuthCreatedDate
	  ,Care_Partner
      ,[Auth owner]
	  , [Auth owner Role]
	  , [Auth Owner Department(s)]
      ,[ReferredBy]
      ,[ReferredTo]   
      , case when j.auth_id is not null then j.team
	  --j.auth_id is null and t.auth_id is null then s.[Team] 
	  when t.auth_id is not null then 'LTSS'
	  when hh.auth_id is not null then 'Home Health'
	  when pca.auth_id is not null then 'PCA'
	  when toc.auth_id is not null then 'TOC'
	  when bh.auth_id is not null then 'BH'
	  --when tl.auth_id is not null then tl.team
	  else s.team 
	  end as [Team] 
	  , CASE WHEN DECISION_DATE is not null then ''
		when [Received_date] is null then ''
		when 
		(auth_priority in ('Part B Med Standard') --added new priority status 2019-02-04
		
		OR (
		auth_priority in ('Prospective Standard','Retrospective')
		and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
		
		 THEN cast (datediff (dd,getdate(),dateadd (dd, 3,[Received_date]) ) as varchar)
 WHEN 
 
 (auth_priority in ('Part B Med Expedited') OR
 (auth_priority in ('Prospective Expedited')
		 and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
		
		 THEN cast (datediff (dd,getdate(),dateadd (dd, 1,[Received_date]) ) as varchar)
		when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN  cast (datediff (dd,getdate(),dateadd (dd, 28,[Received_date]) ) as varchar)
		WHEN auth_priority = 'Prospective Standard'  THEN  cast (datediff (dd,getdate(),dateadd (dd, 14,[Received_date]) ) as varchar)
		when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN   cast (datediff (hour,getdate(),dateadd (dd, 17, [Received_date] ))/24.0 as varchar)
			when auth_priority = 'Prospective Expedited'  THEN  cast(datediff (hour,getdate(),dateadd (dd, 3, [Received_date]) )/24.0 as varchar)
				WHEN (auth_priority = 'Retrospective' and is_extension ='yes') THEN  cast (datediff (dd,getdate(),dateadd (dd, 28,[Received_date]) ) as varchar)  -- added by MEP on 1/8/20
			WHEN auth_priority = 'Retrospective'  THEN  cast (datediff (dd,getdate(),dateadd (dd, 14, [Received_date]) ) as varchar)		
		
		else cast (0 as varchar) end as [Days to Process Auth]
, CASE WHEN 
		received_date is null then 0
		when 
		(auth_priority in ('Part B Med Standard') OR
		(auth_priority in ('Prospective Standard','Retrospective')
		and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
		
		 THEN dateadd (dd, 3, received_date)
		
		 WHEN 
		 (auth_priority in ('Part B Med Expedited') OR
		 (auth_priority in ('Prospective Expedited')
		 and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
		
		 THEN dateadd (dd, 1, received_date)
		when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN dateadd (dd, 28, received_date)
		WHEN auth_priority = 'Prospective Standard'  THEN dateadd (dd, 14,received_date)
		when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 17, received_date)
		when auth_priority = 'Prospective Expedited'  THEN dateadd (dd,3,received_date)
		WHEN (auth_priority = 'Retrospective'  and is_extension ='yes')  THEN dateadd (dd, 28,received_date)  -- MEP added 1/8/20
		WHEN auth_priority = 'Retrospective'  THEN dateadd (dd, 14,received_date)
		

		else 0 end as deadline
 , case  when auth_priority like '%concurrent%'  then 'NA'
	  when DECISION_DATE is null then 'NoDecision'
	  when received_date is null  then 'NA'
	  --when ud.replied_date = '1900-01-01' then 'NoDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 0 then 'UntimelyDecision'  
	  when 
	  cast(datediff(minute,received_date, DECISION_DATE) as float)/1440 <=3 AND
	  (
	   auth_priority in ('Part B Med Standard') OR (
	  auth_priority in ('Prospective Standard','Retrospective')
		and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
then 'TimelyDecision'

 when 
	  cast(datediff(minute,received_date, DECISION_DATE) as float)/1440 <=1 AND
	  (auth_priority in ('Part B Med Expedited') OR
	  (auth_priority in ('Prospective Expedited')
		 and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))

then 'TimelyDecision'

	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%retro%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%retro%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%standard%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%standard%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'
	  when cast(datediff(minute,received_date, DECISION_DATE) as float)/1440 <=3 AND auth_priority like  '%Expedited%' and (is_extension ='No' or is_extension is null) then 'TimelyDecision'
	  when cast(datediff(minute,received_date, DECISION_DATE) as float)/1440 <=17 AND auth_priority like  '%Expedited%' and is_extension ='Yes' then 'TimelyDecision'
	  else 'UntimelyDecision' 
   end as [DecisionFlag]
, case 
when auth_priority like '%concurrent%'  then 'NA'
when [WrittenNotifDate] is null then 'NoLetter'
  when received_date is null then 'NA'
    when 
	  cast(datediff(minute,[Received_date],convert(datetime,[WrittenNotifDate])) as float)/1440 <= 3  AND
	  (
	   auth_priority in ('Part B Med Standard') OR (
	  auth_priority in ('Prospective Standard','Retrospective')
		and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
then 'TimelyLetter'

 when 
	  cast(datediff(minute,[Received_date],convert(datetime,[WrittenNotifDate])) as float)/1440 <= 1  AND
	  (auth_priority in ('Part B Med Expedited') OR
	  (auth_priority in ('Prospective Expedited')
		 and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))

then 'TimelyLetter'	
	when convert(date,[WrittenNotifDate]) = '1900-01-01' then 'NoLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 0 then 'UntimelyLetter' 
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'retrospective')  then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'retrospective') and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'Prospective Standard')  then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'Prospective Standard') and is_extension = 'Yes' then 'TimelyLetter'
	when cast(datediff(minute,[Received_date],convert(datetime,[WrittenNotifDate])) as float)/1440 <= 3 and auth_priority = 'Prospective Expedited' and (is_extension = 'No' or is_extension is null) then 'TimelyLetter'
    when  cast(datediff(minute,[Received_date],convert(datetime,[WrittenNotifDate])) as float)/1440 <= 17 and auth_priority  = 'Prospective Expedited' and is_extension = 'Yes' then 'TimelyLetter'
	else 'UntimelyLetter' 
end as [LetterFlag]
      ,[AUTH_NO]	  	
, CASE when [Received_date] is null then 'Yes' ELSE 'No' end as [No Receipt Date]
	,letter_created_on
  , letter_created_by_name
    , printedon,letterqueue_updatedate
, Note1
	, Note2
	, Note3
	 , AuthCreatedBy
	 , 	 [Auth CreatedBy Role]
	 	  , [Auth CreatedBy Department(s)]
   , AuthCreatedDate
	 --,AdmittingProvider
  ,Facility
    , [Source of Service Request]
  , [Mode of Request]
	 into  #step2 
FROM #STEP1 S
left join junk3 j
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
	where team = 'BH'
)bh
  on s.auth_id = bh.auth_id
left join
(--For 99307/99308, If either those codes are present in the auth, the whole auth should go to TOC. And If POS is 31, the whole auth will be TOC
	select distinct auth_id from #step1
	where (PLACE_OF_SERVICE_CODE = '31' or RTRIM(LTRIM(proc_code)) = '99307' or RTRIM(LTRIM(proc_code)) = '99308')
)toc
  on s.auth_id = toc.auth_id
GROUP BY  [LAST_NAME]
      ,[FIRST_NAME]
      ,[CCAID]
      ,plan_name 
      ,s.[AUTH_ID]
	  ,[Received_date] 
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
	  ,[Decision_Date] 
      ,[Verbal Notification]
      ,[WrittenNotifDate]
      ,[auth_type_name]
      ,[PLACE_OF_SERVICE_CODE]
      ,[PLACE_OF_SERVICE_NAME]
      ,[CMO]
	  ,CMO_At_AuthCreatedDate
	  ,Care_Partner
      ,[Auth owner]
	  , [Auth owner Role]
	  , [Auth Owner Department(s)]
      ,[ReferredBy]
      ,[ReferredTo]   
      , case when j.auth_id is not null then j.team
	  --j.auth_id is null and t.auth_id is null then s.[Team] 
	  when t.auth_id is not null then 'LTSS'
	  when hh.auth_id is not null then 'Home Health'
	  when pca.auth_id is not null then 'PCA'
	  when toc.auth_id is not null then 'TOC'
	  when bh.auth_id is not null then 'BH'
	  --when tl.auth_id is not null then tl.team
	  else s.team 
	  end  
	  , CASE WHEN  DECISION_DATE is not null then 'NA'
		when [Received_date]is null then 'NA'
		when 
		(auth_priority in ('Part B Med Standard') OR (
		auth_priority in ('Prospective Standard','Retrospective')
		and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
		
		 THEN cast (datediff (dd,getdate(),dateadd (dd, 3,[Received_date]) ) as varchar)
 WHEN 
 
 (auth_priority in ('Part B Med Expedited') OR
 (auth_priority in ('Prospective Expedited')
		 and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
		
		 THEN cast (datediff (dd,getdate(),dateadd (dd, 1,[Received_date]) ) as varchar)
		when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN  cast (datediff (dd,getdate(),dateadd (dd, 28,[Received_date]) ) as varchar)
		WHEN auth_priority = 'Prospective Standard'  THEN  cast (datediff (dd,getdate(),dateadd (dd, 14,[Received_date]) ) as varchar)
		when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN   cast (datediff (hour,getdate(),dateadd (dd, 17, [Received_date] ))/24.0 as varchar)
			when auth_priority = 'Prospective Expedited'  THEN  cast(datediff (hour,getdate(),dateadd (dd, 3, [Received_date]) )/24.0 as varchar)
				WHEN (auth_priority = 'Retrospective' and is_extension ='yes') THEN  cast (datediff (dd,getdate(),dateadd (dd, 28,[Received_date]) ) as varchar)  -- added by MEP on 1/8/20
			WHEN auth_priority = 'Retrospective'  THEN  cast (datediff (dd,getdate(),dateadd (dd, 14, [Received_date]) ) as varchar)		
		
		else cast (0 as varchar) end
, CASE WHEN 
		received_date is null then 0
		when 
		(auth_priority in ('Part B Med Standard') OR
		(auth_priority in ('Prospective Standard','Retrospective')
		and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
		
		 THEN dateadd (dd, 3, received_date)
		
		 WHEN 
		 (auth_priority in ('Part B Med Expedited') OR
		 (auth_priority in ('Prospective Expedited')
		 and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
		
		 THEN dateadd (dd, 1, received_date)
		when (auth_priority = 'Prospective Standard' and is_extension ='yes') THEN dateadd (dd, 28, received_date)
		WHEN auth_priority = 'Prospective Standard'  THEN dateadd (dd, 14,received_date)
		when auth_priority = 'Prospective Expedited'  and (is_extension = 'yes')   THEN dateadd (dd, 17, received_date)
		when auth_priority = 'Prospective Expedited'  THEN dateadd (dd,3,received_date)
		WHEN (auth_priority = 'Retrospective'  and is_extension ='yes')  THEN dateadd (dd, 28,received_date)  -- MEP added 1/8/20
		WHEN auth_priority = 'Retrospective'  THEN dateadd (dd, 14,received_date)
		

		else 0 end
 , case  when auth_priority like '%concurrent%'  then 'NA'
	  when DECISION_DATE is null then 'NoDecision'
	  when received_date is null  then 'NA'
	  --when ud.replied_date = '1900-01-01' then 'NoDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 0 then 'UntimelyDecision'  
	  when 
	  cast(datediff(minute,received_date, DECISION_DATE) as float)/1440 <=3 AND
	  (
	   auth_priority in ('Part B Med Standard') OR (
	  auth_priority in ('Prospective Standard','Retrospective')
		and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
then 'TimelyDecision'

 when 
	  cast(datediff(minute,received_date, DECISION_DATE) as float)/1440 <=1 AND
	  (auth_priority in ('Part B Med Expedited') OR
	  (auth_priority in ('Prospective Expedited')
		 and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))

then 'TimelyDecision'

	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%retro%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%retro%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE) < 15 and (auth_priority like '%standard%'or auth_priority is null) then 'TimelyDecision'
	  when datediff(dd,received_date, DECISION_DATE)< 29 and(auth_priority like '%standard%' or auth_priority is null)  and is_extension = 'Yes' then 'TimelyDecision'
	  when cast(datediff(minute,received_date, DECISION_DATE) as float)/1440 <=3 and auth_priority like  '%Expedited%' and (is_extension ='No' or is_extension is null) then 'TimelyDecision'
	  when cast(datediff(minute,received_date, DECISION_DATE) as float)/1440 <=17 and auth_priority like  '%Expedited%' and is_extension ='Yes' then 'TimelyDecision'
	  else 'UntimelyDecision' 
   end 
, case 
when auth_priority like '%concurrent%'  then 'NA'
when [WrittenNotifDate] is null then 'NoLetter'
  when received_date is null then 'NA'
    when 
	  cast(datediff(minute,[Received_date],convert(datetime,[WrittenNotifDate])) as float)/1440 <= 3  AND
	  (
	   auth_priority in ('Part B Med Standard') OR (
	  auth_priority in ('Prospective Standard','Retrospective')
		and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))
then 'TimelyLetter'

 when 
	  cast(datediff(minute,[Received_date],convert(datetime,[WrittenNotifDate])) as float)/1440 <= 1  AND
	  (auth_priority in ('Part B Med Expedited') OR
	  (auth_priority in ('Prospective Expedited')
		 and received_date >= '2020-01-01'
		AND ltrim(rtrim(proc_code)) in 
(
'90371','J0132','J0584','J0775','J1270','J1631','J2248','J2690','J3240','J7177','J7340','J8610','J9173','J9299','Q2050','Q9961',
'90375','J0133','J0585','J0780','J1290','J1640','J2250','J2700','J3243','J7178','J7345','J8655','J9176','J9301','Q3027','Q9963',
'90376','J0153','J0586','J0795','J1300','J1642','J2260','J2704','J3245','J7179','J7500','J8670','J9178','J9302','Q4074','Q9965',
'90585','J0171','J0587','J0800','J1301','J1644','J2270','J2720','J3250','J7180','J7502','J8700','J9179','J9303','Q4081','Q9966',
'90586','J0178','J0588','J0834','J1303','J1645','J2274','J2724','J3260','J7181','J7503','J8705','J9181','J9305','Q4101','Q9967',
'90632','J0179','J0592','J0840','J1322','J1650','J2278','J2760','J3262','J7182','J7504','J9000','J9185','J9306','Q4102','Q9991',
'90653','J0180','J0594','J0841','J1325','J1652','J2280','J2765','J3285','J7183','J7507','J9017','J9190','J9307','Q4106','Q9992',
'90662','J0185','J0595','J0850','J1335','J1670','J2300','J2770','J3300','J7185','J7508','J9019','J9200','J9308','Q4110',	
'90670','J0202','J0596','J0875','J1364','J1720','J2310','J2778','J3301','J7186','J7509','J9022','J9201','J9309','Q4111',	
'90672','J0207','J0597','J0878','J1380','J1740','J2315','J2780','J3304','J7187','J7510','J9023','J9202','J9311','Q4115',	
'90674','J0221','J0598','J0881','J1410','J1742','J2323','J2783','J3315','J7188','J7511','J9025','J9203','J9312','Q4121',	
'90675','J0222','J0600','J0882','J1430','J1743','J2350','J2785','J3357','J7189','J7512','J9027','J9204','J9315','Q4132',	
'90682','J0256','J0610','J0885','J1439','J1745','J2353','J2786','J3358','J7190','J7515','J9030','J9205','J9320','Q4133',	
'90685','J0257','J0630','J0887','J1442','J1746','J2354','J2788','J3360','J7192','J7516','J9032','J9206','J9325','Q4137',	
'90686','J0278','J0636','J0888','J1447','J1750','J2357','J2790','J3370','J7193','J7517','J9033','J9207','J9328','Q4145',	
'90687','J0280','J0637','J0894','J1450','J1756','J2358','J2791','J3380','J7194','J7518','J9034','J9208','J9330','Q4151',	
'90688','J0285','J0638','J0895','J1453','J1786','J2360','J2792','J3385','J7195','J7520','J9035','J9209','J9340','Q4154',	
'90691','J0287','J0640','J0897','J1454','J1800','J2400','J2794','J3396','J7197','J7525','J9036','J9211','J9351','Q4159',	
'90714','J0289','J0641','J1000','J1458','J1815','J2405','J2795','J3410','J7198','J7527','J9039','J9214','J9352','Q4160',	
'90715','J0290','J0642','J1020','J1459','J1817','J2407','J2796','J3411','J7200','J7605','J9040','J9217','J9354','Q4170',	
'90732','J0295','J0670','J1030','J1460','J1885','J2425','J2798','J3415','J7201','J7606','J9041','J9218','J9355','Q4186',	
'90739','J0348','J0690','J1040','J1555','J1930','J2426','J2800','J3420','J7202','J7608','J9042','J9225','J9356','Q4195',	
'90740','J0360','J0692','J1050','J1556','J1931','J2430','J2805','J3430','J7203','J7611','J9043','J9226','J9357','Q4196',	
'90744','J0401','J0694','J1071','J1557','J1940','J2469','J2820','J3465','J7205','J7612','J9044','J9228','J9360','Q5101',	
'90746','J0456','J0695','J1100','J1559','J1943','J2501','J2860','J3471','J7207','J7613','J9045','J9229','J9370','Q5103',	
'90747','J0461','J0696','J1110','J1560','J1944','J2503','J2916','J3473','J7208','J7614','J9047','J9245','J9371','Q5104',	
'90756','J0470','J0697','J1120','J1561','J1950','J2504','J2920','J3475','J7209','J7620','J9050','J9250','J9390','Q5105',	
'A9575','J0475','J0698','J1160','J1566','J1953','J2505','J2930','J3480','J7210','J7626','J9055','J9260','J9395','Q5106',	
'A9576','J0476','J0702','J1162','J1568','J1955','J2507','J2997','J3485','J7211','J7631','J9060','J9261','J9400','Q5107',	
'A9577','J0480','J0712','J1165','J1569','J1956','J2510','J3000','J3486','J7308','J7639','J9065','J9262','P9041','Q5108',	
'A9578','J0485','J0713','J1170','J1570','J1980','J2515','J3010','J3489','J7311','J7644','J9070','J9263','P9045','Q5110',	
'A9579','J0490','J0714','J1190','J1571','J2001','J2540','J3060','J7030','J7312','J7674','J9100','J9264','P9046','Q5111',	
'A9581','J0500','J0717','J1200','J1572','J2010','J2543','J3090','J7040','J7313','J7682','J9119','J9266','P9047','Q5114',	
'A9585','J0515','J0720','J1205','J1575','J2020','J2545','J3095','J7042','J7316','J7686','J9120','J9267','Q0138','Q5115',	
'A9589','J0517','J0725','J1212','J1580','J2060','J2550','J3101','J7050','J7321','J8501','J9130','J9268','Q0139','Q5117',	
'A9606','J0558','J0735','J1230','J1602','J2150','J2560','J3105','J7060','J7323','J8520','J9145','J9271','Q0162','Q9950',	
'J0121','J0561','J0740','J1240','J1610','J2175','J2562','J3111','J7070','J7324','J8521','J9150','J9280','Q0164','Q9956',	
'J0122','J0565','J0743','J1245','J1626','J2182','J2597','J3121','J7120','J7325','J8530','J9153','J9285','Q0166','Q9957',	
'J0129','J0570','J0744','J1250','J1627','J2185','J2675','J3145','J7170','J7327','J8540','J9155','J9293','Q0167','Q9958',	
'J0130','J0583','J0770','J1265','J1630','J2210','J2680','J3230','J7175','J7336','J8560','J9171','J9295','Q2043','Q9960')))

then 'TimelyLetter'	
	when convert(date,[WrittenNotifDate]) = '1900-01-01' then 'NoLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 0 then 'UntimelyLetter' 
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'retrospective')  then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'retrospective') and is_extension = 'Yes' then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 15 and (auth_priority = 'Prospective Standard')  then 'TimelyLetter'
	when datediff(dd,[Received_date],convert(date,[WrittenNotifDate])) < 29 and (auth_priority = 'Prospective Standard') and is_extension = 'Yes' then 'TimelyLetter'
	when cast(datediff(minute,[Received_date],convert(datetime,[WrittenNotifDate])) as float)/1440 <= 3 and auth_priority = 'Prospective Expedited' and (is_extension = 'No' or is_extension is null) then 'TimelyLetter'
    when  cast(datediff(minute,[Received_date],convert(datetime,[WrittenNotifDate])) as float)/1440 <= 17 and auth_priority  = 'Prospective Expedited' and is_extension = 'Yes' then 'TimelyLetter'
	else 'UntimelyLetter' 
end 
      ,[AUTH_NO]	  	
, CASE when [Received_date] is null then 'Yes' ELSE 'No' end 
	,letter_created_on
  , letter_created_by_name
    , printedon,letterqueue_updatedate
, Note1
	, Note2
	, Note3
	 , AuthCreatedBy
	 , 	 [Auth CreatedBy Role]
	 	  , [Auth CreatedBy Department(s)]
   , AuthCreatedDate
	 --,AdmittingProvider
  ,Facility
    , [Source of Service Request]
  , [Mode of Request]

--select * from #step2
--where ([DECISION_STATUS] is null or [DECISION_STATUS] = 'pending')
--and [Decision Date] is not null
--and auth_type_name <> 'transportation'


IF OBJECT_ID('tempdb..#final') IS NOT NULL DROP TABLE #final;

select [FIRST_NAME] as [First Name]
,[LAST_NAME] as [Last Name]
,[CCAID]
,plan_name as [Plan Name]
,[AUTH_ID] as [Auth ID]
,[Received Date]
,[SERVICE_FROM_DATE]
,[SERVICE_TO_DATE]
,[proc_code] AS [Procedure/Service Code]
  ,typeofcode as [Type of Code]
,[proc_description] as [Procedure/Service Description]
,[UnitsRequested] as [Units Requested]
,[UnitsApproved] as [Units Approved]
,[auth_priority] as [Auth Priority]
,[auth_status] as [Auth Status]
,[auth_status_reason_name] as [Auth Status Reason Name]
,[IS_extension]
,[Is there an Extension letter created]
,[decision_Status]
,[DECISION_STATUS_CODE_DESC]
,[Decision Date]
,[Verbal Notification] as [Verbal Notification Date]
,[WrittenNotifDate] as [Written Notification Date]
,[auth_type_name]
,[PLACE_OF_SERVICE_CODE]
,[PLACE_OF_SERVICE_NAME]
,[CMO] as CurrentCMO
,CMO_At_AuthCreatedDate
,Care_Partner
,[Auth owner]
	  , [Auth owner Role]
	  , [Auth Owner Department(s)]
,[ReferredBy]
,coalesce ([ReferredTo], facility) as [ReferredTo/Facility]
,Team
,[Days to Process Auth]
,deadline
,[DecisionFlag]
, 
--case 
--when [decision date] is not null then [DecisionFlag]
--when [auth_priority] like '%concurrent%' then 'NA'
--when [decision date] is null and auth_priority like '%part b%' and deadline >= getdate() then 'Approaching Deadline'
--when ([auth_priority] like '%expedited%' OR [auth_priority] like '%part b%') and deadline < getdate() then 'Passed deadline'
--when  deadline < cast(getdate() as date) then 'Passed deadline'
--when  [decision date] is null and ([auth_priority] like '%standard%' or [auth_priority] like '%retro%') and datediff(dd,[Received date],cast(getdate() as date)) >=8
-- and deadline >= cast(getdate() as date) then 'Approaching Deadline'
--when  [decision date] is null and ([auth_priority] like '%standard%' or [auth_priority] like '%retro%') and datediff(dd,[Received date],cast(getdate() as date)) < 8
-- and deadline >= cast(getdate() as date) then 'NA'
--when  [decision date] is null  and deadline >= getdate() then 'Approaching Deadline'
----else [DecisionFlag] 
--end as  'Timeliness Flag For Decisions'

case 
when [Received Date] is null then 'No Request Date'
when IS_EXTENsion = 'Yes' and [Is there an Extension letter created] = 'N' then 'Missing Extension Letter'
when ([DECISION_STATUS] is null or [DECISION_STATUS] = 'pending') and [Decision Date] is not null then 'Denial Letter Required'
when datediff(dd, deadline, getdate()) < 4 then 'Deadline less than 4 days'
when datediff(dd, deadline, getdate()) between 4 and 7 then 'Approaching Deadline 4 - 6 days left'
when datediff(dd, deadline, getdate()) >= 7 then 'Within Timeframe'
when getdate() > deadline then 'Passed deadline' -- only day
--when auth_priority like 'Part B%' and auth_priority = 'Prospective Expedited' then getdate() > deadline then 'Passed deadline'  -- consider hr/min
else 'NA'
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
    REPLACE(REPLACE(convert(varchar(MAX),isnull (Note1, '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  as [Note1]
  , REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(MAX),isnull (Note2, '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  as [Note2]
  , REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(MAX),isnull (Note3, '')),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')  as [Note3]

	,[AUTH_NO]
, getdate() as [Report_Date]
	 , AuthCreatedBy
	 , 	  [Auth CreatedBy Role]
	 	  , [Auth CreatedBy Department(s)]
   , AuthCreatedDate
  
 , case when [WrittenNotifDate] is null or  [decision date] is null then 'no decision/written'
when [decision date] <=[WrittenNotifDate] then 'No' ELSE 'Yes' end as [written before decision]
 , case when CAST([Received Date] AS DATE) < CAST(AuthCreatedDate AS DATE) then 'Yes' else 'No' end as [Received Date before Auth Create Date]
     , [Source of Service Request]
  , [Mode of Request]
 into #final
 from #step2
 order by auth_id, [received date], [decision date], [SERVICE_FROM_DATE]



--select distinct [Timeliness Flag For Decisions], count(*)
--from #final
--group by [Timeliness Flag For Decisions]


--select top 100 [Timeliness Flag For Decisions],[Days to Process Auth], deadline,  *
--from #final
----where [Days to Process Auth] <> 'NA'
--where [Decision date] is not null
--and decision_status is null

 --drop table sandbox_mpaquette.dbo.dailyauths
IF OBJECT_ID('tempdb..#final_final') IS NOT NULL DROP TABLE #final_final;

 SELECT
 f.*
, case when [Auth Owner Department(s)] like '%external%' 
or [Auth Owner Department(s)] like '%EBNHC%'
or [Auth Owner Department(s)] like '%BU Geriatric Services%'
or [Auth Owner Department(s)] like '%Element Care%'
or [Auth Owner Department(s)] like '%Upham?s Corner Health Center%'
or [Auth Owner Department(s)] like '%Lynn Community Health Center%'
then 'External Owner' else 'Internal Owner' end as AuthOwnerAffiliation

, case when [plan name] ='ICO-Externally Managed' then 'Health Home' 
  when [plan name] ='SCO-Externally Managed' or  [plan name] ='SCO MassHealth Only-Externally Managed' then 'Delegated Site' 
  else 'CCA-Managed' end as [CMO Delegated Flag at time of auth]
, convert(varchar(10),[SERVICE_FROM_DATE],101) +'-'+convert(varchar(10),[SERVICE_TO_DATE],101) as ServiceDates
, case when [Is there an Extension letter created] = 'n' and is_extension = 'Yes' then 'Missing Extension Letter' else '' end as [ExtLetterFlag]
 , isnull(work_queue, '') as [In Work Queue?]
 , isnull([referred by],'') as [Referred By]
 , isnull(Referby.[role_name],'') as [Referred By Role]
 , isnull([referred to],'') as [Referred To]
  , isnull(Referto.[role_name], '') as [Referred To Role]
 , isnull([status],'') as [Workqueue Status]
 , isnull(convert(varchar,[max refer date], 101), '') as [Latest Referred Date]
 , 	[Max Accepted Date] as [Latest Accepted Date]
 ,isnull(WQName1,'') as [WQName1], 
  isnull(WQName2,'') as [WQName2], 
   isnull(WQName3,'') as [WQName3]--, 
, [Note1]+Note2+Note3 as [NotesGrouped]
, ROW_NUMBER() Over (partition By f.[Auth ID] order by f.service_from_date, f.service_to_Date asc) as AuthLineNumber
, getdate() as last_updated
  into #final_final
  FROM #final f
 left join #UMworklogfinal u on f.[auth id]=u.[auth id] --and f.[auth status] in ('open', 'reopen')
 LEFT JOIN #CARESTAFFGROUP REFERBY ON U.REFERRED_BY_NAME_ID=referby.MEMBER_ID
 LEFT JOIN #CARESTAFFGROUP REFERTO ON U.REFERRED_TO_NAME_ID=referto.MEMBER_ID
 --where f.[auth id]='1231MFEC1'
  ORDER BY f.[AUTH ID]

-- following is for If auth has more DME codes than the others; send auth to DME Team

CREATE NONCLUSTERED INDEX [IX_final_Final]
ON [dbo].[#final_final] ([Team])
INCLUDE ([Auth ID])

;with xxx as
(
	select s1.[Auth ID], s1.team
	from
	(
		select [Auth ID], count(distinct team) as temp
		from #final_final
		group by [Auth ID]
	)a
	join #final_final s1
	on a.[Auth ID] = s1.[Auth ID]
	where a.temp > 1
	--order by 1
)
, xx as
(
	select *
	from
	(
		select [Auth ID] as a1, count(*) single
		from xxx 
		where team = 'DME'
		group by [Auth ID]
		--order by 1
	)as pp
	join 
	(
		select [Auth ID] as a2, count(*) multi
		from xxx 
	--	where team = 'Procedure'
		group by [Auth ID]
	)as whole
	on pp.a1 = whole.a2
	--order by 1
)
, x as
(
select a1 --*, cast(multi as float) / 2--cast(single as float) / cast(multi as float)
from xx
where single >= cast(multi as float) / 2
--order by 1
)
update #final_final
set team = 'DME'
where [Auth ID] in
(
	select * from x
)

--select [Days to Process Auth], *
--from #final_final
--where [Days to Process Auth] <> ''

--select distinct [Days to Process Auth]
--from #final_final

