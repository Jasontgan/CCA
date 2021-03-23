
if OBJECT_ID('tempdb..#ProvGroup') is not null
	drop table #ProvGroup
go	

select pcpa.provider_K, p.npi, pcl.Group_K, pcl.ID as CactusID, pvl.provider_k as PCPlocProvider_K, coalesce(pvl.longname,pcl.groupname) as PCPlocation, 
max(rd.description) as AddressType,  -- added for this version 7  1/18/2017
case when max(pcs.description) is null then 'Not Primary Care Site' else max(pcs.description) end as LocationType
,pcla.addresstype_rtk  -- ADD provider group NPI here with precedence to Providers/Groups columns then ID in ProviderID
,max(case when e.category_rtk='C3VD0FMMSX' then 'Primary Care' else 'Not Primary Care' end) as ProviderCat
,min(case when e.category_rtk='C3VD0FMMSX' and ra.description='ICO' then 'ICO_PCL' else 'Not ICO_PCL' end) as PCLcat
,max(case when pvl.npi>'' then pvl.npi
               when pcl.npi>'' then pcl.npi
               else case when pid.type_rtk='C3VD0FMN8L' then pid.id end end) as PCLnpi
into #ProvGroup
	 from CactusDBSrv.Cactus.VISUALCACTUS.PROVIDERs p 
	 inner join CactusDBSrv.Cactus.VISUALCACTUS.PROVIDERADDRESSES pcpa on p.provider_k=pcpa.provider_k
	 inner join CactusDBSrv.[Cactus].[VISUALCACTUS].[ADDRESSES] adr on pcpa.address_k=adr.address_k
	 left join CactusDBSrv.[Cactus].[VISUALCACTUS].[REFTABLE] rd on adr.userdef_rtk1=rd.reftable_k -- and rd.description='Primary Care Site'                                         
	 inner join CactusDBSrv.Cactus.VISUALCACTUS.GROUPADDRESS pcla on pcpa.ADDRESS_K=pcla.ADDRESS_K
	 inner join CactusDBSrv.Cactus.VISUALCACTUS.GROUPS pcl on pcla.GROUP_K=pcl.GROUP_K and pcl.id like 'G%' and pcl.Active=1
	 inner join CactusDBSrv.Cactus.VisualCactus.PROVIDERS pvl on pcl.id=pvl.id
		and pvl.INDIVIDUALINSTITUTIONFLAG=2 and pvl.active=1
	 left join CactusDBSrv.Cactus.VisualCactus.PROVIDERSPECIALTIES ps on pvl.provider_k=ps.provider_k and ps.active=1
--	 left join CactusDBSrv.[Cactus].[VISUALCACTUS].[PROVIDERID] pid on pid.PROVIDER_K=pvl.provider_k and pid.active=1
	 left join 
	(select provider_k, MAX(coalesce(startdate,'1900-01-01 00:00:00.000')) as MaxStartDate 
     from CactusDBSrv.[Cactus].[VISUALCACTUS].[PROVIDERID]
     where ACTIVE=1
     group by provider_k) pix
			on pvl.PROVIDER_K=pix.provider_k 
	 left join CactusDBSrv.[Cactus].[VISUALCACTUS].[PROVIDERID] pid
            on pix.provider_k=pid.provider_k and coalesce(pid.startdate,'1900-01-01 00:00:00.000')=pix.MaxStartdate and pid.ACTIVE=1
     left join CactusDBSrv.Cactus.VisualCactus.REFTABLE pcs --For primary care site flag
			on ps.SPECIALTY_RTK=pcs.REFTABLE_K and pcs.description='Primary Care Site'  -- ps.SPECIALTY_RTK='C3VD0FMQ43
     left join CactusDBSrv.[Cactus].[VISUALCACTUS].[entityassignments] e on pvl.PROVIDER_K=e.provider_k and e.active=1
     left join CactusDBSrv.[Cactus].[VISUALCACTUS].[REFTABLE] r on e.category_rtk=r.reftable_k and r.description <> 'none'
     left join CactusDBSrv.[Cactus].[VISUALCACTUS].[REFTABLE] ra on e.assignment_rtk=ra.reftable_k			
	 where pcpa.ADDRESSTYPE_RTK ='NPDBPRIMAR' and (pcla.ADDRESSTYPE_RTK in ('NPDBPRIMAR','C3VD0FMV5P','C3VD0FMV58') or (pcla.addresstype_rtk='C3VD0FMV6J' and adr.userdef_rtk1='B3ZS0VAM3F'))
	   and pcpa.active=1 and pcla.active=1
	   and p.npi>'' and p.INDIVIDUALINSTITUTIONFLAG=1
group by pcpa.provider_K, p.npi, pcl.Group_K, pcl.ID, coalesce(pvl.longname,pcl.groupname), pvl.provider_k, pcla.addresstype_rtk

create index provider_k on #provgroup (provider_k)


if OBJECT_ID('tempdb..#cactusPCP') is not null
	drop table #cactusPCP 
go	

select pcp.NPI, pcp.Provider_K, max(pcp.LONGNAME) as ProvName, min(rt.description) as status,  -- 'Contracted'<'Credentialed' so takes priority
   min(case when id.USERDEF_RTK2 is not null or ea.CATEGORY_RTK='C3VD0FMMRO' then 'PCP'
			  when ea.category_rtk='#0A0C781AC' and rp.description='PCP' then 'PCP/AHP'
			  when ea.category_rtk='#FAB7BCCF1' then 'PCP/Spec' end) as CategoryPCP,		  
   max(case when ea.assignment_rtk='C3VD0FMMJT' -- and rt.DESCRIPTION in ('Contracted','Credentialed')  -- eliminated this requirement starting with 4/2017 report
					then 1 else 0 end) as ICO,  
   max(case when ea.assignment_rtk='C3VD0FMMGS' -- and rt.DESCRIPTION in ('Contracted','Credentialed')  -- eliminated this requirement starting with 4/2017 report
					then 1 else 0 end) as SCO
   ,max(case when id2.userdef_l1=1 then 1 else 0 end) as OpenPanel
   ,max(case when rp.description is not null then rp.description else '' end) as ProviderRole
   ,cpc.PCPlocation, cpc.Addresstype, cpc.LocationType, cpc.CactusID, cpc.PCPlocProvider_K, cpc.ProviderCat, cpc.PCLcat
  into #cactusPCP   
   from CactusDBSrv.Cactus.VISUALCACTUS.PROVIDERS as pcp
     inner join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS as ea on pcp.PROVIDER_K=ea.PROVIDER_K
	 inner join CactusDBSrv.[Cactus].[VISUALCACTUS].[REFTABLE] rt on ea.STATUS_RTK=rt.reftable_k
     left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID as id on ea.EA_K=id.ENTITYASSIGNMENT_K
			and id.userdef_rtk2='C3VD0FMP4M' and STARTDATE is not null 
	 left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID as id2 on ea.EA_K=id2.ENTITYASSIGNMENT_K
			and id2.userdef_l1=1 and id2.active=1	
     -- added following joins to get Provider Role attributes (3/18/2016):
	 left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTS as ea1 on pcp.provider_k=ea1.provider_k and ea1.recordtype='E'
	 left join CactusDBSrv.Cactus.VISUALCACTUS.ENTITYASSIGNMENTID as id3 on ea1.EA_K=id3.ENTITYASSIGNMENT_K	
			and ea1.recordtype='E' and id3.active=1		
	 left join CactusDBSrv.[Cactus].[VISUALCACTUS].[REFTABLE] rr on id3.type_rtk=rr.reftable_k
		     and rr.description='Provider Role'
	 left join CactusDBSrv.Cactus.VisualCactus.Reftable rp on id3.userdef_rtk2=rp.reftable_k and rp.description='PCP'
	 left join 
	(SELECT PROVIDER_K, CactusID, PCPlocation, AddressType, LocationType, ProviderCat, PCLcat, PCPlocProvider_K FROM #ProvGroup p
	 where addressType=(select max(addressType) from #ProvGroup p0 where p.provider_k=p0.provider_k)
	   and locationtype=(select max(locationtype) from #ProvGroup p1 where p.provider_k=p1.provider_k and p.AddressType=p1.AddressType)
	   and addresstype_rtk=(select max(addresstype_rtk) from #ProvGroup p1a where p.provider_k=p1a.provider_k and p.AddressType=p1a.AddressType and p.locationtype=p1a.locationtype)
	   and PCPlocation=(select max(pcplocation) from #ProvGroup p2 where p.provider_k=p2.provider_k and p.AddressType=p2.AddressType and p.locationtype=p2.locationtype
			and p.addresstype_rtk=p2.addresstype_rtk)
	 group by provider_k, PCPlocProvider_K, pcplocation, cactusid, AddressType, LocationType, ProviderCat, PCLcat
		) cpc
	on pcp.provider_k=cpc.provider_k 			
   where (id.USERDEF_RTK2 is not null or ea.CATEGORY_RTK in ('C3VD0FMMRO','#FAB7BCCF1','#0A0C781AC') or rp.description='PCP')
     and pcp.INDIVIDUALINSTITUTIONFLAG=1 and pcp.active=1 -- and ea.TERMINATION_DATE is null   -- per Carlo - on 3/7/2016 no longer using this term date
	 and ea.active=1
   group by pcp.NPI, pcp.Provider_K, cpc.AddressType, cpc.PCPlocation, cpc.CactusID, cpc.PCPlocProvider_K, cpc.LocationType, cpc.ProviderCat, cpc.PCLcat
   having pcp.NPI>''
   
create index npi on #cactusPCP (npi) 

select PCPlocation as PrimaryCareSite, CactusID as PCScactusID, PCPlocProvider_K as PCSprovider_K, NPI as PCPnpi, Provider_K as PCPprovider_K, ProvName as PCP, ICO, SCO 
from #CactusPCP
where ProviderRole='PCP' and ICO+SCO>0 and (Addresstype='Primary Care Site' or LocationType='Primary Care Site')
order by 1
