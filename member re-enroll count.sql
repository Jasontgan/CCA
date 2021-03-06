SELECT top 2000 *
  FROM [Medical_Analytics].[dbo].[member_enrollment_history]
  where CCAID = '5365564633'
  order by 2,1 desc

SELECT *
  FROM [Medical_Analytics].[dbo].[member_enrollment_history]
  where relmo = 1 --CCAID = '5365582379'
  order by 1
  and relmo = 1
  and MP_enroll = 1


select distinct CCAID, RelMo, count(*)
  FROM [Medical_Analytics].[dbo].[member_enrollment_history]
  where RelMo = 1
group by CCAID, RelMo
having count(*) > 1

select a.* 
from 
(
select CCAID, count(distinct enr_span_end) as enroll_times
  FROM [Medical_Analytics].[dbo].[member_enrollment_history]
  --where enroll_status = 'current member'
  --and CCAID = '5365605429'
  --and RelMo = 1
group by CCAID
having count(distinct enr_span_end) > 1
)a
inner join
(
select CCAID
  FROM [Medical_Analytics].[dbo].[member_enrollment_history]
  where RelMo = 1
  and enroll_status = 'current member'
  --and CCAID = '5365605429'
)b
on a.CCAID = b.CCAID
order by 2


