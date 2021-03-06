/****** Script for SelectTopNRows command from SSMS  ******/

--drop table #disenroll
--drop table #disenroll2  

SELECT 
		--[member_month]
  --    --,[RelMo]
  --    --,[MP_enroll]
  --    --,[EP_enroll]
  --    ,[member_ID]
      distinct [CCAID]
      --,meh.[NAME_ID]
      --,[enr_mo] as 'Months Enrolled'
	  ,[enr_span_start]
      ,max([enr_span_end]) as 'LastEnrEnd'
      ,[Product]
      ,[enroll_status]
      --,[enroll_status2]
      --,[enroll_status3]
      --,[Assignment]
      ,[NAME_FIRST]
      ,[NAME_MI]
      ,[NAME_LAST]
      --,[DOB]
      --,[DOD]
      ,[GENDER]
      ,[lang_spoken]
      --,[race]
      --,[ethnicity]
      --,[CM]
      --,[latest_enr_mo]
	  ,ISNULL(coalesce(mp.ADDRESS1, meh.ADDRESS1), ' ') as 'ADDRESS1'
	  ,ISNULL(coalesce(mp.ADDRESS2, meh.ADDRESS2), ' ') as 'ADDRESS2'
	  ,ISNULL(coalesce(mp.CITY, meh.CITY),' ') as 'CITY'
	  ,ISNULL(coalesce(mp.[STATE], meh.[STATE]), ' ') as 'STATE'
	  ,ISNULL(coalesce(mp.ZIP, meh.ZIP), ' ') as 'ZIP'
	  --,case when mp.ADDRESS_TYPE = 'MAILING' and mp.PREFERRED_FLAG = 'x' then mp.ADDRESS1 else meh.ADDRESS1 end as 'ADDRESS1'
	  --,case when mp.ADDRESS_TYPE = 'MAILING' and mp.PREFERRED_FLAG = 'x' then mp.ADDRESS2 else meh.ADDRESS2 end as 'ADDRESS2'
	  --,case when mp.ADDRESS_TYPE = 'MAILING' and mp.PREFERRED_FLAG = 'x' then mp.CITY else meh.CITY end as 'CITY'
	  --,case when mp.ADDRESS_TYPE = 'MAILING' and mp.PREFERRED_FLAG = 'x' then mp.[STATE] else meh.[STATE] end as 'STATE'
	  --,case when mp.ADDRESS_TYPE = 'MAILING' and mp.PREFERRED_FLAG = 'x' then mp.ZIP else meh.ZIP end as 'ZIP'
	  --, mp.address_type
	  --,mp.ADDRESS1
	  --,mp.ADDRESS2
	  --,mp.CITY
	  --,mp.[STATE]
	  --,mp.ZIP
      --,ISNULL(meh.[ADDRESS1], ' ') as 'Address1'
      --,ISNULL(meh.[ADDRESS2], ' ') as 'Address2'
      --,ISNULL(meh.[CITY], ' ') as 'City'
      --,ISNULL(meh.[STATE], ' ') as 'State'
      --,ISNULL(meh.[ZIP], ' ') as 'Zip'
        
  --into #disenroll  
  --into #disp 
  --select ccaid from #disp group by ccaid having count(ccaid)>1 
  --select * from #disp where ccaid = '5365605260'
  --drop table #disenroll

  FROM [Medical_Analytics].[dbo].[member_enrollment_history] as meh
  LEFT JOIN (
   select
   NAME_ID, ADDRESS_TYPE, PREFERRED_FLAG, ADDRESS1, ADDRESS2, CITY, [STATE], ZIP
   FROM [MPSnapshotProd].[dbo].[NAME_ADDRESS] where ADDRESS_TYPE like 'MAILING%' and PREFERRED_FLAG = 'x'
   ) as mp on meh.name_id = mp.name_id

  where 
  
  --[relmo] between 1 and 7 
  --[relmo] = 1
  [latest_enr_mo] = 1
  and [enr_span_end] between '2017-12-01' and '2018-05-30' 
  and [dod] is NULL
  and [enroll_status] like 'Not%'
  --and ccaid = '5365605260'

  group by

  --[member_month]
      --,[RelMo]
      --,[MP_enroll]
      --,[EP_enroll]
      --,[member_ID]
      [CCAID]
      ,meh.[NAME_ID]
      --,[enr_mo] 
      --,max([enr_span_end]) 
	  ,[enr_span_start]
      ,[Product]
      --,[ContractNumber]
      --,[PROGRAM_ID]
      ,[enroll_status]
      --,[enroll_status2]
      --,[enroll_status3]
      --,[Assignment]
      ,[NAME_FIRST]
      ,[NAME_MI]
      ,[NAME_LAST]
      --,[DOB]
      --,[DOD]
      ,[GENDER]
      ,[lang_spoken]
      --,[lang_spoken_group]
      --,[lang_written]
      --,[lang_written_group]
      --,[race]
      ----,[race_group]
      --,[ethnicity]
      --,[CM]
      --,[latest_enr_mo]
      --,ISNULL(meh.[ADDRESS1], ' ') 
      --,ISNULL(meh.[ADDRESS2], ' ') 
      --,ISNULL(meh.[CITY], ' ') 
      --,ISNULL(meh.[STATE], ' ') 
      --,ISNULL(meh.[ZIP], ' ') 
	  ,mp.address_type
	  ,mp.ADDRESS1
	  ,mp.ADDRESS2
	  ,mp.CITY
	  ,mp.[STATE]
	  ,mp.ZIP
	  ,mp.PREFERRED_FLAG
	  ,meh.ADDRESS1
	  ,meh.ADDRESS2
	  ,meh.CITY
	  ,meh.[STATE]
	  ,meh.ZIP
  
  order by [ccaid]

  --select * from #dis where ccaid = '5365628686'

----drop table #disenroll2
--select *
-- into #disenroll2
-- from #disenroll 
 
-- where [LastEnrEnd] between '2017-09-01' and '2018-02-28' and [latest_enr_mo] =1 and [enroll_status] like 'Not%'

/*Final Table for Report */

--select DISTINCT

--ccaid
--,[Months Enrolled]
--,LastEnrEnd
--,Product
--,enroll_status
----,enroll_status2
----,enroll_status3
--,Assignment
--, Name_First + ' ' + Name_MI + Name_Last as 'Member'
--,Name_First
--,Name_MI
--,Name_Last
--,Gender
--,Lang_spoken
--,race
--,ethnicity
--,CM as 'Care Partner'
--,Address1
--,Address2
--,City
--,[State]
--,Zip

--from #disenroll2

--where [product] = 'SCO'

--order by LastEnrEnd

/* checking to make sure no DOD was missed */

--select ds.*
--,cm.date_of_death
--,hcfa.death_date
--,n.date1
--,d1.dod as 'dodrec'

-- from #disenroll2 as ds
--left join [CCAMIS_Common].[dbo].[members] as cm on ds.member_id = cm.member_id_active --order by ds.ccaid
--left join [MPSnapshotProd].[dbo].[HCFA_NAME_ORG] as hcfa on ds.member_id = hcfa.member_id --order by ds.ccaid
--left join [MPSnapshotProd].[dbo].[NAME] as n on ds.name_id=n.name_id --order by ds.ccaid
--left join (
--  select
--   member_month, ccaid, dod from medical_analytics.dbo.member_enrollment_history  
--   where relmo=0 and dod >'2017-06-01' --order by dod

--  ) as d1 on ds.ccaid=d1.ccaid

--drop table #disenroll2