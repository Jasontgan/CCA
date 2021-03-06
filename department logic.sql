select 
--auth_id
--, 
authcr.member_id
, authcr.first_name
, authcr.last_name
, authcrrol.role_name
, care_staff_dept_id
, dept_name
, authcrdep.is_work_queue
, d.is_work_queue 
, title
from [Altruista].[dbo].um_auth a
left join [Altruista].[dbo].[CARE_STAFF_DETAILS] authcr on a.CREATED_BY=authcr.member_id
left join [Altruista].[dbo].[CARE_STAFF_DEPARTMENT] authcrdep on authcr.member_id=authcrdep.care_staff_id and authcrdep.deleted_on is null
left join [Altruista].[dbo].[DEPARTMENT] d on authcrdep.dept_id=d.dept_id and d.deleted_on is null
left join [Altruista].[dbo].[ROLE] authcrrol on  authcr.ROLE_ID=authcrrol.ROLE_ID and authcrrol.deleted_on is null
where a.deleted_on is null
group by
authcr.first_name
, authcr.last_name
, authcrrol.role_name
, care_staff_dept_id
, dept_name
, authcrdep.is_work_queue
, d.is_work_queue 
, authcr.member_id
, title
order by authcr.member_id, care_staff_dept_id



