with disenroll as -- last member month for all the disenrolled members
(
	select max(meh.member_month) as member_month, old.ccaid
	from Medical_Analytics.dbo.member_enrollment_history meh
	join
	(
		select distinct ccaid 
		from Medical_Analytics.dbo.member_enrollment_history
		where relmo = 1
		and mp_enroll is null
	)old
	on meh.ccaid = old.ccaid
	where meh.ep_enroll = 1
	--and meh.ccaid = '5365561428'
	group by old.ccaid
)
select meh.* from 
Medical_Analytics.dbo.member_enrollment_history meh
join disenroll d
on meh.ccaid = d.ccaid and meh.member_month = d.member_month
--order by meh.ccaid

union
-- all the current enroll member
select *
from Medical_Analytics.dbo.member_enrollment_history
where relmo = 1
and mp_enroll = 1