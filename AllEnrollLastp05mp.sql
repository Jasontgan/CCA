/*  This script creates the temp table #MPmembExtr containing the latest member data from MP for ICO and SCO members 
including those dis-enrolled.
*/

-- All Enrollment Spans that are valid:

if OBJECT_ID('tempdb..#ALLenrollALL') is not null
	drop table #ALLenrollALL	

select ds.value as Product, n.name_id, n.text2 as CCAID, convert(bigint,a.text1) as id_medicaid, a.app_id,
convert(datetime,left(convert(varchar(30),ds.start_date),19)) as EnrollStartDt, 
max(coalesce(convert(datetime,left(convert(varchar(30),ds.end_date),19)),'9999-12-30')) as EnrollEndDt
into #ALLenrollALL
 from mpsnapshotprod.dbo.entity_enroll_app a 
	  inner join mpsnapshotprod.dbo.name n on a.ENTITY_ID=n.NAME_ID and a.APP_TYPE='mcaid'
      inner join mpsnapshotprod.dbo.date_span as ds on n.name_id=ds.NAME_ID and ds.COLUMN_NAME='name_text19'
		and ds.value in ('ico','sco') and ds.card_type='mcaid app' -- and n.PROGRAM_ID like 'M%'
where coalesce(end_date,'9999-12-30')>start_date
  and not (n.program_id='XXX' and ds.end_date is null)
  and a.app_id=ds.extra_id
group by ds.value, n.NAME_ID, ds.START_DATE, n.text2, a.text1, a.app_Id

create index nameprod on #AllenrollAll (name_id, product)

-- Connect any contiguous enrollment spans for same product and member under each initial start date (EnrollStartDt1 here):


if OBJECT_ID('tempdb..#ALLenroll') is not null
	drop table #ALLenroll

; with Enroll (product, name_id, app_id, ccaid, id_medicaid, SeqNo, EnrollStartDt1, EnrollStartDt, EnrollEndDt)
as
(select a.product, a.name_id, a.app_id, a.ccaid, a.id_medicaid, 1, a.EnrollStartDt, a.EnrollStartDt, EnrollEndDt
 from #ALLenrollAll a
 where not exists
  (select name_id from #ALLenrollAll a1 where a.name_id=a1.name_id and a.product=a1.product
   and dateadd(dd,1,a1.EnrollEndDt)=a.EnrollStartDt)
 union all
 select c.product, c.name_id, a.app_id, c.ccaid, c.id_medicaid, c.seqno+1, c.EnrollStartDt1, a.EnrollStartDt, a.EnrollEndDt
 from Enroll c
 inner join #ALLenrollAll a on c.name_id=a.name_id and c.product=a.product
 where dateadd(dd,1,c.EnrollEndDt)=a.EnrollStartDt
 )

select * into #ALLEnroll from enroll
/*
-- Summarize to get all  Correct Periods of Enrollment by Product:


if OBJECT_ID('tempdb..#ALLenrollPer') is not null
	drop table #ALLenrollPer

select product, name_id, app_id, ccaid, id_medicaid, EnrollStartDt1 as EnrollBeginDate,
case when max(EnrollEndDt)<'9999-12-30' then max(EnrollEndDt) end as EnrollEndDate
into #ALLenrollPer
from #ALLenroll 
group by product, name_id, app_id, ccaid, id_medicaid, EnrollStartDt1

create index ccaid on #ALLenrollPer (ccaid)
*/

-- Select Most Recent Enrollment Period for member:

if OBJECT_ID('tempdb..#ALLenrollLast') is not null
	drop table #ALLenrollLast

select product, name_id, ccaid, id_medicaid, EnrollStartDt1 as EnrollBeginDate,
case when max(EnrollEndDt)<'9999-12-30' then max(EnrollEndDt) end as EnrollEndDate
into #ALLenrollLast
from #ALLenroll e1
group by product, name_id, ccaid, id_medicaid, EnrollStartDt1
having EnrollStartDt1=(select MAX(EnrollStartDt1) from #ALLenroll em 
  where e1.ccaid=em.ccaid
    and EnrollStartDt1<=getdate()  -- if want to exclude future enrolls
 )
 -- and max(EnrollEndDt)>convert(datetime,datediff(dd,0,GETDATE()))  -- add to exclude members disenrolled

create unique index name_id on #ALLenrollLast (name_id)

-- Extract provider data from MP:

if OBJECT_ID('tempdb..#MPmemberPS ') is not null
	drop table #MPmemberPS 

select * into #MPmemberPS 
from (select nm.name_id, nmp1.service_type, nmp1.update_date,
      case when nmp1.service_type in ('ICO PCL','Primary Care Loc') then 'PrimCareLoc'
	       when nmp1.service_type in ('ICO PCP','PCP') then 'PCP'
		   when nmp1.service_type in ('ICO Care Manager','Care Manager') then 'CareManager'
		   else nmp1.service_type end as ServTypeGrp,
	  convert(datetime,left(convert(varchar(30),nmp1.eff_date),19)) AS ProvfromDt, 
      isnull(convert(datetime,left(convert(varchar(30),nmp1.term_date),19)),'9999-12-31 00:00:00') as ProvtoDt,
	  case when nmp1.service_type in ('ICO PCL','Primary Care Loc','Care Manager Org','Care Model') then ps.company
			else ps.name_last+', '+ps.name_first end as Name
      ,ps.LETTER_COMP_CLOSE as CactusProvK
from mpsnapshotprod.dbo.name as nm -- inner join #ALLenrollLast el on nm.name_id=el.name_id
     inner join (select name_id, service_type, max(eff_date) as max_eff_date
		from mpsnapshotprod.dbo.name_provider
		where coalesce(TERM_DATE,'9999-12-31')>eff_date
          and service_type in ('ICO PCL','Primary Care Loc','ICO PCP','PCP','ICO Care Manager','Care Manager','Care Manager Org','Care Model')	
		group by NAME_ID, SERVICE_TYPE) nmp 
		on nm.NAME_ID=nmp.NAME_ID 
	 inner join mpsnapshotprod.dbo.name_provider as nmp1
     on nmp.name_id=nmp1.name_id and nmp.SERVICE_TYPE=nmp1.SERVICE_TYPE
		and nmp.max_eff_date=nmp1.eff_date 
		and coalesce(nmp1.TERM_DATE,'9999-12-31')>nmp1.eff_date
     inner join mpsnapshotprod.dbo.name as ps
     on nmp1.provider_id=ps.name_id
     where left(nm.program_id,1)='M') tt
 
create index nameserv on #mpmemberPS (name_id, service_type)

-- Combine/summarize data:

if OBJECT_ID('tempdb..#MPmembExtr') is not null
	drop table #MPmembExtr 

select em.product, em.name_id, em.ccaid, em.MMISid, em.DOB
, coalesce(em.DOD,convert(date,left(convert(varchar(30),ho.death_date),19))) as DOD,
em.name_last, em.name_mi, em.name_first, em.gender, em.program_id, em.LastEnrollStartDt, em.LastEnrollEndDt, em.SpokenLang
,max(case when ps1.service_type in ('Primary Care Loc','ICO PCL') then ps1.name else '' end) as LatestPCL
,max(case when ps1.service_type in ('PCP','ICO PCP') then ps1.name else '' end) as LatestPCP
,max(case when ps1.service_type in ('Care Manager','ICO Care Manager') then name else '' end) as CareManager
,max(case when ps1.service_type = 'Care Model' then ps1.name else '' end) as LatestCareModel
,max(case when ps1.service_type='Care Manager Org' then ps1.name else '' end) as LatestCMO
,max(case when ps1.service_type='Care Manager Org' and ps1.ProvToDt<'9999-12-31' then ps1.ProvToDt end) as LatestCMOendDate		    
into #MPmembExtr
from (select e.product, e.id_medicaid as MMISid, e.ccaid, e.EnrollBeginDate as LastEnrollStartDt, 
		e.EnrollEndDate as LastEnrollEndDt, n.name_id, 
		n.name_last, n.name_first, coalesce(n.name_mi,'') as name_mi, n.program_id,
		convert(date,left(convert(varchar(30),n.birth_date),19)) as DOB, 
		convert(date,left(convert(varchar(30),n.date1),19)) as DOD, n.gender, a.text23 as SpokenLang  
	 from #ALLenrollLast e inner join mpsnapshotprod.dbo.entity_enroll_app a 
				 on a.entity_id=e.name_id and a.app_type='mcaid'
	  inner join mpsnapshotprod.dbo.name n on a.ENTITY_ID=n.NAME_ID
		) em
left join mpsnapshotprod.dbo.hcfa_name_org ho on em.NAME_ID=ho.name_id
left join 	
	(select p.name_id, p.ServTypeGrp, p.ProvToDt, max(p.ProvFromDt) as MaxProvFromDt
	 from #MPmemberPS p inner join #MPmemberPS p1
	 on p.name_id=p1.name_id and p.servTypeGrp=p1.ServTypeGrp
	 group by p.name_id, p.ServTypeGrp, p.ProvToDt
	 having max(p1.ProvToDt)=p.ProvToDt) psg on em.name_id=psg.name_id 
left join #MPmemberPS ps1 on em.Name_id=ps1.Name_id and ps1.ServTypeGrp=psg.ServTypeGrp 
		and ps1.ProvToDt=psg.ProvTodt and ps1.ProvFromDt=psg.MaxProvFromDt
group by em.product, em.name_id, em.ccaid, em.name_id, em.DOB, em.DOD, em.MMISid
, em.name_last, em.name_mi, em.name_first, em.gender, em.LastEnrollStartDt, em.SpokenLang
, em.LastEnrollEndDt, em.program_id, ho.death_date

create unique index ccaid on #MPmembExtr (ccaid)

select CCAID, MMISid, DOB, Name_Last+', '+Name_First as MemberName, Product, LastEnrollStartDt, LastEnrollEndDt
, LatestPCP, LatestPCL, LatestCMO, LatestCMOendDate 
from #MPmembExtr
where ccaid = '5365558635'



select distinct cts.*,
meh.ccaid, meh.product, meh.lastenrollstartdt, meh.lastenrollenddt
--into #temp
from medical_analytics.dbo.cca_member_20200124 cts
left join 
#MPmembExtr meh
on cts.memberkey = meh.ccaid
order by 1