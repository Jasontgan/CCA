/****** Script for SelectTopNRows command from SSMS  ******/
SELECT  [member_month]
    --  ,[RelMo]
      --,[MP_enroll]
      --,[EP_enroll]
     -- ,[member_ID]
      ,[CCAID]
   
      ,[enr_span_start]
      ,[enr_span_end]
      ,[Product]

      ,[RC]
 
      ,[NAME_FIRST]
      ,[NAME_MI]
      ,[NAME_LAST]
      ,[DOB]
 
      ,[GENDER]
      ,[lang_spoken]
      ,[lang_written]
      ,[race]
      ,[ethnicity]

      ,[CMO]
         ,[cap_site]
    --  ,[CM]
 
 

     -- ,[latest_enr_mo]
      
  FROM [Medical_Analytics].[dbo].[member_enrollment_history]
  
  where RelMo = '1'and member_month = '2017-03-01' and MP_enroll = '1'and enr_span_end = '9999-12-30'