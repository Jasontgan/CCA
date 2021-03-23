if OBJECT_ID('tempdb..#ProvContStat') is not null
       drop table #ProvContStat

; with ProvContStat1 as
(select p.Provider_k, p.id as CactusID, p.Active as ProviderActive
, case when p.INDIVIDUALINSTITUTIONFLAG='2' then 'Group' 
       when p.INDIVIDUALINSTITUTIONFLAG='1' then 'Individual' end as ProvIndType 
, p.LongName, pc.description as ProvCateg, pt.description as PracticeType
-- ,max(p.NPI) as NPI, max(pdm.NPI) as ProvIDnpi
, max(coalesce(case when p.NPI>'' then p.NPI end,pdm.npi)) as NPI
-- , max(coalesce(case when p.TaxIDnumber>'' then p.TaxIDnumber end,px.ID)) as TaxIDnumber
,ea.active as EntityAssignActive, ea.DateEntered as EntityAssignDateEntered
, coalesce(ea.originalappointmentdate,ea.presentdate_from) as ContractBeginDate
, case when ea.active=0 then coalesce(ea.termination_date,ea.presentdate_to) else ea.termination_date end as ContractEndDate 
 ,max(case when rt.description is not null then rt.description else '' end) as ProviderStatus 
 ,max(case when assignment_rtk='C3VD0FMMJT' then 1 else 0 end) as ICO
,max(case when assignment_rtk='C3VD0FMMGS' then 1 else 0 end) as SCO
,max(case when rp.description is not null then rp.description else '' end) as ProviderRole
  from CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERS p 
  inner join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS as ea on p.PROVIDER_K=ea.PROVIDER_K
             and assignment_rtk in ('C3VD0FMMJT','C3VD0FMMGS')
  inner join CactusDBSrv.[Cactus].[VISUALCACTUS].[REFTABLE] rt on ea.STATUS_RTK=rt.reftable_k
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID as id on ea.EA_K=id.ENTITYASSIGNMENT_K and ea.recordtype='E' and id.active=1    
  left join CactusDBSrv.Cactus.VisualCactus.Reftable rp on id.userdef_rtk2=rp.reftable_k 
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pc on p.category_rtk=pc.reftable_k
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pt on p.practicetype_rtk=pt.reftable_k
  left join --  get NPI from ProviderID table for cases where it is not populated in Providers table:
  (select p1.provider_k, np.NPI, p1.LongName
   from CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERID pd inner join ccamis_common.dbo.NPIDB np on pd.ID=np.NPI
     inner join CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERS p1 on pd.provider_k=p1.provider_k
       where p1.INDIVIDUALINSTITUTIONFLAG='2' -- and pc.description='Provider Entity'
         and pd.type_rtk='C3VD0FMN8L'  -- type for NPI when not in Providers.NPI      
   group by p1.provider_k, np.NPI, p1.LongName) pdm on p.provider_k=pdm.provider_k 
       where p.id>''
group by p.Provider_k, p.id, p.INDIVIDUALINSTITUTIONFLAG, p.LongName, pc.description, pt.description
,p.Active, pc.description, pt.description, ea.active, ea.originalappointmentdate, ea.termination_date  --  assignment_rtk
,ea.PresentDate_from, ea.PresentDate_to, ea.DateEntered
having max(coalesce(case when p.NPI>'' then p.NPI end,pdm.npi)) is not null
   and convert(tinyint,ea.active)=(select max(convert(tinyint,active)) from CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ea2 where ea2.provider_k=p.provider_k
             and assignment_rtk in ('C3VD0FMMJT','C3VD0FMMGS'))
)

select * into #ProvContStat
from ProvContStat1 
 union   -- add in additional Group providers that have NPIs in ProviderID table that is different from providers.NPI:
select p.Provider_k, p.id as CactusID, p.Active as ProviderActive
, case when p.INDIVIDUALINSTITUTIONFLAG='2' then 'Group' 
       when p.INDIVIDUALINSTITUTIONFLAG='1' then 'Individual' end as ProvIndType 
, p.LongName, pc.description as ProvCateg, pt.description as PracticeType, pd.id as NPI
,ea.active as EntityAssignActive, ea.DateEntered as EntityAssignDateEntered
, coalesce(ea.originalappointmentdate,ea.presentdate_from) as ContractBeginDate
, case when ea.active=0 then coalesce(ea.termination_date,ea.presentdate_to) else ea.termination_date end as ContractEndDate 
  ,max(case when rt.description is not null then rt.description else '' end) as ProviderStatus 
   ,max(case when assignment_rtk='C3VD0FMMJT' then 1 else 0 end) as ICO
   ,max(case when assignment_rtk='C3VD0FMMGS' then 1 else 0 end) as SCO
   ,max(case when rp.description is not null then rp.description else '' end) as ProviderRole
  from CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERS p 
  inner join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ea on p.PROVIDER_K=ea.PROVIDER_K
             and assignment_rtk in ('C3VD0FMMJT','C3VD0FMMGS')
  inner join CactusDBSrv.[Cactus].[VISUALCACTUS].[REFTABLE] rt on ea.STATUS_RTK=rt.reftable_k
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID id on ea.EA_K=id.ENTITYASSIGNMENT_K and ea.recordtype='E' and id.active=1    
  left join CactusDBSrv.Cactus.VisualCactus.Reftable rp on id.userdef_rtk2=rp.reftable_k 
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pc on p.category_rtk=pc.reftable_k
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pt on p.practicetype_rtk=pt.reftable_k
  inner join CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERID pd on p.provider_k=pd.Provider_k and pd.type_rtk='C3VD0FMN8L'  -- type for NPI IDs
   inner join ccamis_common.dbo.NPIDB np on pd.ID=np.NPI
       where p.id>'' and p.INDIVIDUALINSTITUTIONFLAG='2' and pc.description='Provider Entity'   
        and not exists (select npi from ProvContStat1 a where a.npi=pd.id)    -- NPIs not already captured in first step                                     
 group by p.Provider_k, p.id, p.INDIVIDUALINSTITUTIONFLAG, p.LongName, pc.description, pt.description
,p.Active, pc.description, pt.description, ea.active, ea.originalappointmentdate, ea.termination_date  
 ,ea.PresentDate_from, ea.PresentDate_to, ea.DateEntered, pd.id
having convert(tinyint,ea.active)=(select max(convert(tinyint,active)) from CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ea2 where ea2.provider_k=p.provider_k
             and assignment_rtk in ('C3VD0FMMJT','C3VD0FMMGS'))

create index npi on #ProvContStat (npi)

-- Summarize data giving most current entity assignments by provider NPI: 

if OBJECT_ID('tempdb..#ProvProdContract') is not null
       drop table #ProvProdContract


; with ProvContract1 as
(select a.NPI, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg, a.LongName, a.EntityAssignActive as ProdContractActive
,convert(date,a.EntityAssignDateEntered) as ProdContractDateEntered, convert(date,a.ContractBeginDate) as ProdContractBeginDate, convert(date,a.ContractEndDate) as ProdContractTermDate
, 'ICO' as Product
from #ProvContStat a inner join #ProvContStat b on a.npi=b.npi and a.ICO=b.ICO
where a.ICO=1 
group by a.Provider_K, a.ContractBeginDate, a.ContractEndDate, a.NPI, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg
, a.LongName, a.EntityAssignActive,a.EntityAssignDateEntered
having max(coalesce(b.ContractBeginDate,'1900-01-01'))=coalesce(a.ContractBeginDate,'1900-01-01')
and max(convert(tinyint,b.ProviderActive))=convert(tinyint,a.ProviderActive)
union all
select a.NPI, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg, a.LongName, a.EntityAssignActive as ProdContractActive
,convert(date,a.EntityAssignDateEntered) as ProdContractDateEntered, convert(date,a.ContractBeginDate) as ProdContractBeginDate, convert(date,a.ContractEndDate) as ProdContractTermDate
, 'SCO'
from #ProvContStat a inner join #ProvContStat b on a.npi=b.npi and a.SCO=b.SCO
where a.SCO=1 
group by a.Provider_K, a.ContractBeginDate, a.ContractEndDate, a.NPI, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg
, a.LongName,  a.EntityAssignActive,a.EntityAssignDateEntered
having max(coalesce(b.ContractBeginDate,'1900-01-01'))=coalesce(a.ContractBeginDate,'1900-01-01')
  and max(convert(tinyint,b.ProviderActive))=convert(tinyint,a.ProviderActive)
) 

select pc.Product, pc.NPI, pc.Provider_K, CactusID, ProviderActive, ProvIndType, ProvCateg, LongName
, ProdContractActive, ProdContractDateEntered, ProdContractBeginDate, ProdContractTermDate
, case when prodContractActive=0 then LastEntAssnDeActiveDate end as LastEntAssnDeActiveDate 
into #ProvProdContract
from ProvContract1 pc
left join 
 (select FILE_PRIMARYKEY as Provider_K, max(convert(date,auditDateTime)) as LastEntAssnDeActiveDate
  from CactusDBSrv.Cactus.VISUALCACTUS.auditLog AL -- inner join #ProvContStat pc on pc.Provider_k=al.file_primarykey
  inner JOIN CactusDBSrv.Cactus.VISUALCACTUS.auditLog_RECORDLEVEL AR ON AL.AUDITLOG_K=AR.AUDITLOG_K
  inner JOIN CactusDBSrv.Cactus.VISUALCACTUS.auditLog_FIELDLEVEL AF ON AR.AUDITLOG_RECORDLEVEL_K=AF.AUDITLOG_RECORDLEVEL_K
    where file_k='ENTASSN'
      and table_name in ('entityassignments')
      and FieldName='ACTIVE'
   group by file_primarykey, OldValue_short, NewValue_short
   having OldValue_short='.T.' and NewValue_short='.F.'
   ) da on pc.provider_k=da.provider_k
/* 
 select * from #ProvProdContract where (prodcontractactive=1 and prodcontractbegindate is not null and prodcontracttermdate is null) 
             or (prodcontractactive=0 and prodcontracttermdate is not null and prodcontractbegindate<prodcontracttermdate)
select * from #ProvProdContract where (prodcontractactive=1 and coalesce(prodcontractbegindate,prodcontractdateentered) is not null and coalesce(prodcontracttermdate,lastentassndeactivedate) is null) 
             or (prodcontractactive=0 and coalesce(prodcontracttermdate,lastentassndeactivedate) is not null and coalesce(prodcontractbegindate,prodcontractdateentered) is not null)
select * from #ProvProdContract where ProviderActive=1 and ProdContractActive=1 and ProdContractTermDate is not null
select * from #ProvProdContract where ProdContractBeginDate is null and ProdContractDateEntered is null -- and ProdContractActive=1
select * from #ProvProdContract where ProdContractActive=0 and ProdContractTermDate is null and LastEntAssnDeActiveDate is null 
             and not (ProdContractBeginDate is null and ProdContractDateEntered is null)


-- select npi, product, provindtype, ProvCateg, CactusID from ##ProvProdContract group by npi, product, provindtype, ProvCateg, CactusID having count(distinct prodcontractdateentered)=1 and count(*)>1

select * from #provProdContract p1 where exists
(select npi from #ProvProdContract p2 
group by npi, product, provindtype, cactusID 
having count(*)>1 and count(distinct prodcontractdateentered)=1
  and p1.npi=p2.npi and p1.product=p2.product and p1.provindtype=p2.provindtype
  and p1.cactusID=p2.cactusID)
  order by npi, product, provindtype, cactusID

*/
-- select product, npi, prodcontractbegindate from #ProvProdContract group by product, npi, prodcontractbegindate having count(*)>1
/*

select * from #ProvProdContract where npi in 
(select npi from #ProvProdContract group by npi, product, provindtype, ProvCateg, CactusID having count(*)>1)
order by npi, product, provindtype, ProvCateg, CactusID
*/

-- select * from #ProvProdContract where npi=1023191541
-- drop table ##ProvProdContract

if OBJECT_ID('tempdb..#ProvProdContract1') is not null
       drop table #ProvProdContract1

select a.Product, a.NPI, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType
, case when a.ProvCateg<>'No Value Specified' then a.ProvCateg end as ProvCateg
, a.LongName, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, case when min(isnull(a.ProdContractTermDate,'9999-12-31')) < '9999-12-31' then min(isnull(a.ProdContractTermDate,'9999-12-31'))
       end as ProdContractTermDate, a.LastEntAssnDeActiveDate
into #ProvProdContract1
from #ProvProdContract a inner join  #ProvProdContract a1
on a.Product=a1.Product and a.NPI=a1.NPI and a.Provider_K=a1.Provider_K and a.ProvIndType=a1.ProvIndType and a.ProvCateg=a1.ProvCateg
-- where a.NPI=1033367966
group by a.Product, a.NPI, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg
, a.LongName, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, a.LastEntAssnDeActiveDate
having isnull(a.ProdContractDateEntered,'1900-01-01')=max(isnull(a1.ProdContractDateEntered,'1900-01-01'))


-------------------
drop table [Medical_Analytics].[dbo].[jason_daphine_claims]
select * from [Medical_Analytics].[dbo].[jason_daphine_claims]

select distinct temp.*,
--, case when coalesce (cp.npi, v.pcg_vendorid) is null then 'NCP'
case when (temp.datefrom < coalesce(cp.ProdContractBeginDate, cp.ProdContractDateEntered) or temp.datefrom > cp.ProdContractTermDate) then 'NCP'
when (temp.datefrom >= coalesce(cp.ProdContractBeginDate, cp.ProdContractDateEntered,'1900-01-01') and  temp.datefrom <= isnull(cp.ProdContractTermDate,'9999-12-31')) then 'CP'
else 'N/A' end as 'cactusflag'
from
(
SELECT distinct name, title, [npi]
      ,[claim]
      ,j.[ccaid]
	  ,dt.datefrom
	  ,dt.dateto 
	  ,meh.product
  FROM [Medical_Analytics].[dbo].[jason_daphine_claims] j
  left join [EZCAP_DTS].dbo.CLAIM_masters_v dt
  on j.claim = dt.claimno
  left join ccamis_common.dbo.dim_date d 
  on dt.dateto = d.date
  LEFT JOIN Medical_Analytics.dbo.member_enrollment_history AS meh
  on j.ccaid = meh.ccaid and d.member_month= meh.member_month
--  order by 2
) temp
left join #ProvProdContract1 cp
on temp.npi = case when temp.product is null then cp.npi else cp.npi end
order by temp.npi
