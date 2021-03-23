/* Extract most current product contract entity assignments from Cactus 
-- need to add Contract Entity Cactus ID linked to PCGid (Vendor ID) in order to join claims based on both Provid and Vendor ID
-- For this version (2/4/2019) include Provider Category and Status from 'E' record and use these values if Category and Status at Provider basic level is not specified.
*/

if OBJECT_ID('tempdb..#ProvContStat') is not null
	drop table #ProvContStat

; with ProvContStat1 as
(select p.Provider_k, p.id as CactusID, p.Active as ProviderActive
, case when p.INDIVIDUALINSTITUTIONFLAG='2' then 'Group' 
       when p.INDIVIDUALINSTITUTIONFLAG='1' then 'Individual' end as ProvIndType, p.LongName
, isnull(case when pc.description is not null and pc.description<>'No Value Specified' then pc.description end,pe.description) as ProvCateg
,  pt.description as PracticeType
 , max(isnull(case when p.NPI>'' then p.NPI end,pdm.npi)) as NPI, p.TaxIDnumber as TaxID
 ,ea.active as EntityAssignActive, ea.DateEntered as EntityAssignDateEntered 
 , isnull(ea.originalappointmentdate,ea.presentdate_from) as ContractBeginDate
 , case when ea.active=0 then isnull(ea.termination_date,ea.presentdate_to) else ea.termination_date end as ContractEndDate 
 , case when ce.GroupName is not null then ce.GroupName else 'None Assigned' end as ContractEntityGroup
 , ce.GroupID as ContractEntityCactusID
 , isnull(max(case when rt.description is not null and rt.description<>'No Value Specified' then rt.description end),ps.description) as ProviderStatus
 , max(case when ea.assignment_rtk='C3VD0FMMJT' then 1 else 0 end) as ICO
 , max(case when ea.assignment_rtk='C3VD0FMMGS' then 1 else 0 end) as SCO
  from CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERS p 
  inner join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS as ea on p.PROVIDER_K=ea.PROVIDER_K
		and assignment_rtk in ('C3VD0FMMJT','C3VD0FMMGS')
  inner join CactusDBSrv.[Cactus].[VISUALCACTUS].[REFTABLE] rt on ea.STATUS_RTK=rt.reftable_k
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS as ear on p.PROVIDER_K=ear.PROVIDER_K
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID as id on ear.EA_K=id.ENTITYASSIGNMENT_K and ear.recordtype='E' and id.active=1    
  left join CactusDBSrv.Cactus.VisualCactus.Reftable rp on id.userdef_rtk2=rp.reftable_k 
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pc on p.category_rtk=pc.reftable_k
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pt on p.practicetype_rtk=pt.reftable_k
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS eai on p.provider_k=eai.provider_k and eai.status_rtk = 'C4W30GSU6H' and ltrim(rtrim(EAI.category_rtk))='NONE'
		and eai.recordtype='E' and ltrim(rtrim(eai.assignment_rtk))='NONE' and eai.Active=1
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS eac on p.provider_k=eac.provider_k
		and eac.recordtype='E' and ltrim(rtrim(eac.assignment_rtk))='NONE' and eac.Active=1
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pe on eac.category_rtk=pe.reftable_k
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] ps on eac.status_rtk=ps.reftable_k
  left join --  get NPI from ProviderID table for cases where it is not populated in Providers table:
  (select p1.provider_k, np.NPI, p1.LongName
   from CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERID pd inner join ccamis_common.dbo.NPIDB np on pd.ID=np.NPI
     inner join CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERS p1 on pd.provider_k=p1.provider_k
	where p1.INDIVIDUALINSTITUTIONFLAG='2' -- and pc.description='Provider Entity'
	  and pd.type_rtk='C3VD0FMN8L'  -- type for NPI when not in Providers.NPI      
   group by p1.provider_k, np.NPI, p1.LongName) pdm on p.provider_k=pdm.provider_k 
   left join  -- get Group Contract Entity:
   (select p.npi, p.id as CactusID, p.provider_k, ea.ea_k as EntAssnID, pg.id as GroupID, g.GroupName
    from CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERS p 
    inner join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ea on p.provider_k=ea.provider_k
	inner join CactusDBSrv.Cactus.VISUALCACTUS.EAADDRESSES ed on ea.ea_k=ed.ea_k
	inner join CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERaddresses pa on p.provider_k=pa.provider_k 
				and ed.provideraddress_k=pa.provideraddress_k
	inner join CactusDBSrv.Cactus.VISUALCACTUS.GROUPADDRESS ga on pa.address_k=ga.address_k
	inner join CactusDBSrv.Cactus.VISUALCACTUS.GROUPS g on ga.group_k=g.group_k
	inner join CactusDBSrv.Cactus.VISUALCACTUS.Providers pg on g.id=pg.id
    where ed.eaaddresstype_rtk='C3VD0FMV6Y'  -- contract entity relationship address
      and pg.category_rtk='C3VD0FMN8J'  -- contracting entity group facility type
group by  p.npi, p.id, p.provider_k, pg.id, g.GroupName, ea.ea_K) ce on p.provider_k=ce.provider_k and ea.ea_k=ce.EntAssnID
left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ee on p.provider_k=ee.provider_k  and ee.userdef_rtk3='C5120LTHH9' and ee.recordtype='E'
	where p.id>'' -- and ce.EntAssnID is null
	  and rt.description <>'Duplicate/Invalid' -- provider status not duplicate/invalid
   	  and eai.provider_k IS NULL  --  entity assignments not marked duplicate/invalid overall on record_type='E'
 group by p.Provider_k, p.id, p.INDIVIDUALINSTITUTIONFLAG, p.LongName, pc.description, pt.description
 ,p.Active, pc.description, pt.description, ea.active, ea.originalappointmentdate, ea.termination_date  -- , ea.ea_K
 ,ea.PresentDate_from, ea.PresentDate_to, ea.DateEntered, ce.GroupName, ce.GroupID, p.TaxIDnumber, pe.description, ps.description
 having max(isnull(case when p.NPI>'' then p.NPI end,pdm.npi)) is not null
 /*
   and convert(tinyint,ea.active)=(select max(convert(tinyint,active)) from
    CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ea2 where ea2.provider_k=p.provider_k
		and assignment_rtk in ('C3VD0FMMJT','C3VD0FMMGS'))
		*/
)                                
-- select * from #ProvContStat
 select * into #ProvContStat
 from ProvContStat1 
 union   -- add in additional Group providers that have NPIs in ProviderID table that is different from providers.NPI:
 select p.Provider_k, p.id as CactusID, p.Active as ProviderActive
, case when p.INDIVIDUALINSTITUTIONFLAG='2' then 'Group' 
       when p.INDIVIDUALINSTITUTIONFLAG='1' then 'Individual' end as ProvIndType 
, p.LongName, isnull(case when pc.description is not null and pc.description<>'No Value Specified' then pc.description end,pe.description) as ProvCateg
, pt.description as PracticeType, pd.id as NPI, p.TaxIDnumber as TaxID
 ,ea.active as EntityAssignActive, ea.DateEntered as EntityAssignDateEntered
 , isnull(ea.originalappointmentdate,ea.presentdate_from) as ContractBeginDate
 , case when ea.active=0 then isnull(ea.termination_date,ea.presentdate_to) else ea.termination_date end as ContractEndDate 
 , case when ce.GroupName is not null then ce.GroupName else 'None Assigned' end as ContractEntityGroup, ce.GroupID as ContractEntityCactusID
 , isnull(max(case when rt.description is not null and rt.description<>'No Value Specified' then rt.description end),ps.description) as ProviderStatus
 , max(case when ea.assignment_rtk='C3VD0FMMJT' then 1 else 0 end) as ICO
 , max(case when ea.assignment_rtk='C3VD0FMMGS' then 1 else 0 end) as SCO
--  ,max(case when rp.description is not null then rp.description else '' end) as CurrProviderRole
  from CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERS p 
  inner join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ea on p.PROVIDER_K=ea.PROVIDER_K
		and assignment_rtk in ('C3VD0FMMJT','C3VD0FMMGS')
  inner join CactusDBSrv.[Cactus].[VISUALCACTUS].[REFTABLE] rt on ea.STATUS_RTK=rt.reftable_k
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS as ear on p.PROVIDER_K=ear.PROVIDER_K
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID as id on ear.EA_K=id.ENTITYASSIGNMENT_K and ear.recordtype='E' and id.active=1    
  left join CactusDBSrv.Cactus.VisualCactus.Reftable rp on id.userdef_rtk2=rp.reftable_k 
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pc on p.category_rtk=pc.reftable_k
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pt on p.practicetype_rtk=pt.reftable_k
  inner join CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERID pd on p.provider_k=pd.Provider_k and pd.type_rtk='C3VD0FMN8L'  -- type for NPI IDs
  inner join ccamis_common.dbo.NPIDB np on pd.ID=np.NPI
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS eai on p.provider_k=eai.provider_k and eai.status_rtk = 'C4W30GSU6H' and ltrim(rtrim(EAI.category_rtk))='NONE'
    and eai.recordtype='E' and ltrim(rtrim(eai.assignment_rtk))='NONE' and eai.Active=1
  left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS eac on p.provider_k=eac.provider_k
	and eac.recordtype='E' and ltrim(rtrim(eac.assignment_rtk))='NONE' and eac.Active=1
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] pe on eac.category_rtk=pe.reftable_k
  left join CactusDBsrv.[Cactus].[VISUALCACTUS].[REFTABLE] ps on eac.status_rtk=ps.reftable_k
  left join -- get Group Contract Entity:
   (select p.npi, p.id as CactusID, p.provider_k, ea.ea_k as EntAssnID, pg.id as GroupID, g.GroupName
    from CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERS p 
    inner join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ea on p.provider_k=ea.provider_k
	inner join CactusDBSrv.Cactus.VISUALCACTUS.EAADDRESSES ed on ea.ea_k=ed.ea_k
	inner join CactusDBsrv.Cactus.VISUALCACTUS.PROVIDERaddresses pa on p.provider_k=pa.provider_k 
				and ed.provideraddress_k=pa.provideraddress_k
	inner join CactusDBSrv.Cactus.VISUALCACTUS.GROUPADDRESS ga on pa.address_k=ga.address_k
	inner join CactusDBSrv.Cactus.VISUALCACTUS.GROUPS g on ga.group_k=g.group_k
	inner join CactusDBSrv.Cactus.VISUALCACTUS.Providers pg on g.id=pg.id
    where ed.eaaddresstype_rtk='C3VD0FMV6Y'  -- contract entity relationship address
      and pg.category_rtk='C3VD0FMN8J'  -- contracting entity group facility type
	  and ea.assignment_rtk in ('C3VD0FMMJT','C3VD0FMMGS')
group by  p.npi, p.id, p.provider_k, g.GroupName, ea.ea_K, pg.ID) ce on p.provider_k=ce.provider_k and ea.ea_k=ce.EntAssnID
	where p.id>'' and p.INDIVIDUALINSTITUTIONFLAG='2' and pc.description='Provider Entity'   
	 and not exists (select npi from ProvContStat1 a where a.npi=pd.id)    -- NPIs not already captured in first step  
     and rt.description <>'Duplicate/Invalid' -- provider status not duplicate/invalid  
     and eai.provider_k is null  --  entity assignments not marked duplicate/invalid overall                                 
 group by p.Provider_k, p.id, p.INDIVIDUALINSTITUTIONFLAG, p.LongName, pc.description, pt.description
 ,p.Active, pc.description, pt.description, ea.active, ea.originalappointmentdate, ea.termination_date  
 ,ea.PresentDate_from, ea.PresentDate_to, ea.DateEntered, pd.id, ce.GroupName, ce.GroupID, p.TaxIDnumber, pe.description, ps.description
 /*
 having convert(tinyint,ea.active)=(select max(convert(tinyint,active)) from CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ea2 where ea2.provider_k=p.provider_k
		and assignment_rtk in ('C3VD0FMMJT','C3VD0FMMGS'))
		*/

create index npi on #ProvContStat (npi)

-- Summarize data giving most current entity assignments by provider NPI: 

if OBJECT_ID('tempdb..#ProvContract') is not null
	drop table #ProvContract


; with ProvContract1 as
(select a.NPI, a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProviderStatus, a.ProvIndType, a.ProvCateg, a.LongName, a.ContractEntityGroup
, a.ContractEntityCactusID, a.EntityAssignActive as ProdContractActive
,convert(date,a.EntityAssignDateEntered) as ProdContractDateEntered, convert(date,a.ContractBeginDate) as ProdContractBeginDate, convert(date,a.ContractEndDate) as ProdContractTermDate
, 'ICO' as Product
from #ProvContStat a inner join #ProvContStat b on a.npi=b.npi and a.ICO=b.ICO
where a.ICO=1 
group by a.Provider_K, a.ContractBeginDate, a.ContractEndDate, a.NPI, a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg
, a.LongName, a.EntityAssignActive, a.EntityAssignDateEntered, a.ContractEntityGroup, a.ContractEntityCactusID, a.ProviderStatus
having max(convert(tinyint,b.ProviderActive))=convert(tinyint,a.ProviderActive)
union all
select a.NPI, a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProviderStatus, a.ProvIndType, a.ProvCateg, a.LongName, a.ContractEntityGroup
, a.ContractEntityCactusID, a.EntityAssignActive as ProdContractActive
,convert(date,a.EntityAssignDateEntered) as ProdContractDateEntered, convert(date,a.ContractBeginDate) as ProdContractBeginDate, convert(date,a.ContractEndDate) as ProdContractTermDate
, 'SCO'
from #ProvContStat a inner join #ProvContStat b on a.npi=b.npi and a.SCO=b.SCO
where a.SCO=1 
group by a.Provider_K, a.ContractBeginDate, a.ContractEndDate, a.NPI, a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg
, a.LongName, a.EntityAssignActive, a.EntityAssignDateEntered, a.ContractEntityGroup, a.ContractEntityCactusID, a.ProviderStatus
having max(convert(tinyint,b.ProviderActive))=convert(tinyint,a.ProviderActive)
) 

select a.NPI, a.Provider_K, a.CactusID, a.ProviderActive, a.ProviderStatus, a.ProvIndType, a.ProvCateg, a.LongName, a.ContractEntityGroup, a.ContractEntityCactusID
, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate, a.ProdContractTermDate, a.Product, a.TaxID
into #ProvContract
from ProvContract1 a inner join ProvContract1 b 
on a.npi=b.npi and a.product=b.product 
   and a.ContractEntityGroup=b.ContractEntityGroup 
group by a.NPI, a.Provider_K, a.CactusID, a.ProviderActive, a.ProviderStatus, a.ProvIndType, a.ProvCateg, a.LongName, a.TaxID
, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate, a.ProdContractTermDate, a.Product, a.ContractEntityGroup, a.ContractEntityCactusID
-- having max(isnull(b.ProdContractBeginDate,'1900-01-01'))=isnull(a.ProdContractBeginDate,'1900-01-01')

-- select * from #ProvContract where npi in (1487608485,1407866619)
               
if OBJECT_ID('tempdb..#ProvProdContract1') is not null
	drop table #ProvProdContract1

 select pc.Product, pc.NPI, pc.TaxID, pc.Provider_K, CactusID, ProviderActive, ProviderStatus, ProvIndType, ProvCateg, LongName, ContractEntityGroup, ContractEntityCactusID
 , ProdContractActive, ProdContractDateEntered, ProdContractBeginDate, ProdContractTermDate
 , case when prodContractActive=0 then LastEntAssnDeActiveDate end as LastEntAssnDeActiveDate 
into #ProvProdContract1
 from #ProvContract pc
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


create index provprodk on #ProvProdContract1 (Product, npi, provider_k)

; with ProvProdContract1 as
(select a.Product, a.NPI, a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProviderStatus, a.ProvIndType
, case when a.ProvCateg<>'No Value Specified' then a.ProvCateg end as ProvCateg
, a.LongName, a.ContractEntityGroup, a.ContractEntityCactusID, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, case when min(isnull(a.ProdContractTermDate,'9999-12-31')) < '9999-12-31' then min(isnull(a.ProdContractTermDate,'9999-12-31'))
	end as ProdContractTermDate, a.LastEntAssnDeActiveDate
from #ProvProdContract1 a inner join  #ProvProdContract1 a1
on a.Product=a1.Product and a.NPI=a1.NPI and a.Provider_K=a1.Provider_K 
  and isnull(a.ProvIndType,'')=isnull(a1.ProvIndType,'') and isnull(a.ProvCateg,'')=isnull(a1.ProvCateg,'')
group by a.Product, a.NPI,a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg
, a.LongName, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, a.LastEntAssnDeActiveDate, a.ContractEntityGroup, a.ContractEntityCactusID, a.ProviderStatus
having convert(tinyint,a.ProdContractActive)=max(convert(tinyint,a1.ProdContractActive))
-- order by a.npi
)
                 
-- drop table #ProvProdContract
select * into #ProvProdContract from 
(select a.Product, a.NPI, a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProviderStatus, a.ProvIndType, a.ProvCateg
,a.LongName, a.ContractEntityGroup, a.ContractEntityCactusID, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, a.ProdContractTermDate, a.LastEntAssnDeActiveDate
from ProvProdContract1 a inner join ProvProdContract1 a1
on a.Product=a1.Product and a.NPI=a1.NPI and a.Provider_K=a1.Provider_K 
 and isnull(a.ProvIndType,'')=isnull(a1.ProvIndType,'') and isnull(a.ProvCateg,'')=isnull(a1.ProvCateg,'')
  -- and a.ContractEntityGroup=a1.ContractEntityGroup
  and a.ContractEntityCactusID=a1.ContractEntityCactusID
  where not exists
  (select npi from ProvProdContract1 b
   where a.npi=b.npi and a.product=b.product and a.provider_k=b.provider_k
     and b.ContractEntityGroup='None Assigned')
group by a.Product, a.NPI, a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg
,a.LongName, a.ContractEntityGroup, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, a.ProdContractTermDate, a.LastEntAssnDeActiveDate, a.ContractEntityCactusID, a.ProviderStatus
-- having isnull(a.ProdContractDateEntered,'1900-01-01')=max(isnull(a1.ProdContractDateEntered,'1900-01-01'))
union 
select a.Product, a.NPI, a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProviderStatus, a.ProvIndType, a.ProvCateg
,a.LongName, a.ContractEntityGroup, a.ContractEntityCactusID, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, a.ProdContractTermDate, a.LastEntAssnDeActiveDate
from ProvProdContract1 a inner join ProvProdContract1 a1
on a.Product=a1.Product and a.NPI=a1.NPI and a.Provider_K=a1.Provider_K 
 and isnull(a.ProvIndType,'')=isnull(a1.ProvIndType,'') and isnull(a.ProvCateg,'')=isnull(a1.ProvCateg,'')
  where exists
  (select npi from ProvProdContract1 b
   where a.npi=b.npi and a.product=b.product and a.provider_k=b.provider_k
     and b.ContractEntityGroup='None Assigned')
group by a.Product, a.NPI, a.TaxID, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg
,a.LongName, a.ContractEntityGroup, a.ContractEntityCactusID, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, a.ProdContractTermDate, a.LastEntAssnDeActiveDate, a.ProviderStatus
-- having isnull(a.ProdContractDateEntered,'1900-01-01')=max(isnull(a1.ProdContractDateEntered,'1900-01-01'))
) tt

--  Add in PCG vendor ID:
-- drop table ##ProvProdContract
select * into ##ProvProdContract
from 
(select a.Product, a.NPI, a.Provider_K, a.CactusID, a.ProviderActive, a.ProviderStatus, a.ProvIndType, a.ProvCateg, a.TaxID, ee.userdef_c3 as PCG_VendorID
,a.LongName, a.ContractEntityGroup, a.ContractEntityCactusID, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, a.ProdContractTermDate, a.LastEntAssnDeActiveDate
    from #ProvProdContract a left join CactusDBSrv.Cactus.VISUALCACTUS.Providers pg on a.Provider_K=pg.Provider_k
	left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS ee on pg.provider_k=ee.provider_k and ee.userdef_rtk3='C5120LTHH9' and ee.recordType='E'  -- PCG VendorID
 group by a.Product, a.NPI, a.TaxID, ee.userdef_c3, a.Provider_K, a.CactusID, a.ProviderActive, a.ProvIndType, a.ProvCateg
,a.LongName, a.ContractEntityGroup, a.ContractEntityCactusID, a.ProdContractActive, a.ProdContractDateEntered, a.ProdContractBeginDate
, a.ProdContractTermDate, a.LastEntAssnDeActiveDate, a.ProviderStatus
) tt

delete from ##ProvProdContract 
where ContractEntityGroup='None Assigned' and exists
 (select provider_k from ##ProvProdContract b
  where ##ProvProdContract.Provider_k=b.Provider_k
    and ##ProvProdContract.product=b.product
	and b.contractEntityGroup<>'None Assigned')


/*
-- drop/rename table Medical_Analytics.dbo.CactusProviderProdContract
-- select * into Medical_Analytics.dbo.CactusProviderProdContract from ##ProvProdContract

-- create index npi on Medical_Analytics.dbo.CactusProviderProdContract (npi)

-- select npi, product, cactusID, cONTRACTeNTITYGROUP from Medical_Analytics.dbo.CactusProviderProdContract group by npi, product, cactusID, CONTRACTENTITYGROUP having count(*)>1  -- 1222
*/
