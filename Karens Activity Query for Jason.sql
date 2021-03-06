; with GCactivity as
(SELECT pd.client_patient_id as ccaid, pf.[PATIENT_ID] as PatientID, created_date, followup_date, due_date
      ,CARE_ACTIVITY_TYPE_NAME as ActivityType, [ACCEPT_FLAG], [PERFORMED_DATE]
      ,[REJECTION_DATE], [ACCEPTED_DATE], pf.Outcome_Notes, pf.Comments
	  ,pf.refer_to, pf.queue_id, completed_activity_id, patient_followup_id, q.ReferToDept
	  ,case when cs.last_name is null and cs.middle_name is not null then cs.middle_name+', '+cs.first_name else cs.last_name+', '+cs.first_name end as AssignedToStaff
	  ,Activity_Outcome as ActivityOutcome, pf.Activity_Outcome_ID
	  , Case when pf.Performed_date is not Null then 'Completed'
			 when pf.Rejection_date is not null then 'Rejected'
			 when pf.Accept_flag=0 then 'Pending Acceptance'
			 when pf.Accept_Flag=1 then 'Accepted'
			         end as ActivityStatus
	  , case when ao.Activity_outcome_type_id=1 then 'Successful'
			 when ao.Activity_outcome_type_id=2 then 'Unsuccessful' else '' end as ActivityOutcomeCat
      , rank() over (partition by pd.client_patient_id, at.Care_Activity_Type_Name order by pf.Created_date desc) as ActSeq
	--  , rank() over (partition by pd.client_patient_id order by pf.Performed_date desc) as ActPerfSeq
	  , row_number() over (partition by pd.client_patient_id, at.Care_Activity_Type_Name, convert(date,pf.Performed_date) 
				order by pf.Performed_date) as ActTypePerfSeq  -- gives #1 to first performed activity of each type by member/day 
--  into #GCactivity
  FROM [Altruista].[dbo].[PATIENT_FOLLOWUP] pf inner join altruista.dbo.patient_details pd on pf.patient_id=pd.patient_id
  inner join [Altruista].[dbo].[CARE_ACTIVITY_TYPE] at on pf.CARE_ACTIVITY_TYPE_ID=at.CARE_ACTIVITY_TYPE_ID
  left join Altruista.dbo.Activity_outcome ao on pf.activity_outcome_id=ao.activity_outcome_id
  left join Altruista.dbo.care_staff_details cs on pf.refer_to=cs.member_Id and role_id in (24,27)
  left join 
	(select fq.Queue_ID, case when min(d.dept_name)<>max(d.dept_name) then min(d.Dept_name)+', '+max(d.dept_name) else max(d.dept_name) end as ReferToDept  --  , qd.Dept_id,
	 from [Altruista].[dbo].[PATIENT_FOLLOWUP_QUEUE] fq 
      inner join [Altruista].[dbo].[PATIENT_FOLLOWUP_QUEUE_DEPARTMENT] qd on fq.Patient_followup_queue_id=qd.PATIENT_FOLLOWUP_QUEUE_ID
      inner join [Altruista].[dbo].[Department] d on qd.dept_id=d.dept_id
	  where d.is_work_queue=1
	  group by fq.Queue_ID 
	  ) q on pf.queue_ID=q.queue_ID
  where left(pd.client_patient_id,3)='536'
  /*
    and at.CARE_ACTIVITY_TYPE_NAME not in ('Onboarding-Reenrollee','Reenrollee','MDS - Initial','Onboarding-Outreach and intake'
				,'Onboarding-Schedule MDS','Onboarding-Perform MDS','Onboarding-Perform Initial MDS','Onboarding-Schedule Initial MDS'
				,'Schedule Initial MDS','Perform Initial MDS','MDS - Proxy'  -- mds proxy only included to exclude probable Proxy MDS's in final step
				,'Outreach/Visit-Member','Unreachable-Community Visit','Unreachable-Outreach and intake')
				*/
    and pf.deleted_on is null -- and at.deleted_on is null
--	and pf.performed_date is not null 
-- order by 1, care_activity_type_name, created_date desc
)

-- create index ccaid on #GCactivity (ccaid)


select *
from GCactivity
--where 
--ActivityType in
--('Assessment-Behavioral Health',
--'Assessment-Behavioral Health SUD',
--'Behavioral Health:  Life Skills Education',
--'Behavioral Health: Low Cost Behavioral Health',
--'Behavioral Health: Low Cost Inpatient Services',
--'Behavioral Health: Medicaid/Medicare Enrollment',
--'Behavioral Health: Substance Abuse Support',
--'Onboarding-COC Behavioral Health')
--and
where performed_date between '2020-03-01' and '2020-06-30'
----and AssignedToStaff like 'daly%'
----group by ActivityType, ActivityStatus, AssignedToStaff, ReferToDept
--order by 3 desc
