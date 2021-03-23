---------------------------------------------------fully dential
select distinct aa.claimno, --aa.tot_net, dt.claimno, dt.tblrowid, dt.billed, dt.net, 
dt.adjcode, ac.descr--, count(*)
from
(
	SELECT 
	dt.claimno, sum(dt.net) as tot_net
	--case when dt.adjcode is null then '' else dt.adjcode end as adj_code
	--,case when ac.descr is null then '' else ac.descr end as AdjCodeDescr
	--, count(distinct dt.claimno)
	  FROM [EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt 
	--  	left join [EZCAP_DTS].[dbo].[service_codes] sv   on dt.hservicecd = sv.svccode and sv.phcode = 'h'
	---------	left join [EZCAP_DTS].[dbo].ADJUST_CODES ac on dt.adjcode = ac.code and ac.code_type = 'oa'
	where 
	dt.todatesvc between'2017-01-01' and '2017-12-01' --between'2014-05-01' and '2014-06-01'
	and dt.status = 9
	and (lineflag <> 'x' or lineflag is null)
	group by dt.claimno
	--having sum(dt.net) = 0
)aa
inner join
[EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt 
on aa.claimno = dt.claimno
inner join 
[EZCAP_DTS].[dbo].ADJUST_CODES ac 
on dt.adjcode = ac.code and ac.code_type = 'oa'
where aa.tot_net = 0
and dt.adjcode not in ('#C','97')
--group by dt.adjcode, ac.descr
order by 1

---------------------------------------------------partial dential

select distinct aa.claimno, aa.adjcode, ac.descr 
--into #temp1
from
(
	select distinct dt.claimno, dt.tblrowid, dt.adjcode 
	from 
	[EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt
	--inner join [Medical_Analytics].[dbo].[ODAG_adjust_code_2017] maa
	--on dt.adjcode = maa.adjcode 
	where net = 0
	and todatesvc between'2017-01-01' and '2017-12-01'
	and dt.status = 9
	and (lineflag <> 'x' or lineflag is null)
	and billed > 0
	and dt.adjcode not in ('#C','97')
	--and maa.status = 'denial'
	and dt.claimno not in 
	(
				SELECT distinct
				dt.claimno--, sum(dt.net) as tot_net
				--case when dt.adjcode is null then '' else dt.adjcode end as adj_code
				--,case when ac.descr is null then '' else ac.descr end as AdjCodeDescr
				--, count(distinct dt.claimno)
				  FROM [EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt 
				--  	left join [EZCAP_DTS].[dbo].[service_codes] sv   on dt.hservicecd = sv.svccode and sv.phcode = 'h'
				---------	left join [EZCAP_DTS].[dbo].ADJUST_CODES ac on dt.adjcode = ac.code and ac.code_type = 'oa'
				where 
				dt.todatesvc between'2017-01-01' and '2017-12-01' --between'2014-05-01' and '2014-06-01'
				and dt.status = 9
				and (lineflag <> 'x' or lineflag is null)
				--and claimno ='20170106921198400010'
				group by dt.claimno
				having sum(dt.net) = 0
	)
	and dt.claimno not in 
	(
		select claimno
		FROM [EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt 	
		where todatesvc between'2017-01-01' and '2017-12-01'
		and dt.status = 9
		and (lineflag <> 'x' or lineflag is null)
--		and dt.adjcode not in ('#C')
--		and claimno = '20170825821195303291'
		group by claimno
		having count(distinct proccode) = 1 and count(tblrowid) > 1 and count(distinct fromdatesvc) = 1
	)
	and dt.claimno not in 
	(
		select distinct claimno
			from	
			(	
				select claimno, tblrowid, count(*) as tot
				FROM [EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt 	
			--	where claimno = '20170602821195200087'
				group by claimno, tblrowid
				having count(*) > 1	
			) as aa	
	)
)aa
inner join [Medical_Analytics].[dbo].[ODAG_adjust_code_2017] maa
on aa.adjcode = maa.adjcode
inner join 
[EZCAP_DTS].[dbo].ADJUST_CODES ac 
on aa.adjcode = ac.code and ac.code_type = 'oa'
where maa.status = 'denial'
order by 1	


--select * from #temp1

--select distinct claimno, count(*)
--from #temp1
--group by claimno
--having count(*) > 1
