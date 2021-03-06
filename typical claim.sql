--drop table #temp

SELECT distinct 
hm.MEMBID as 'CCAID'
,hm.membname
, hm.claimno
-- , dt.tblrowid
--,site_name
--,convert(varchar(10),hm.dateto,101) as 'claim service date'
--,convert(varchar(10),hm.daterecd,101) as 'DateRecd' --,dt.hservicecd,sv.svcdesc,[MODIF]
--,convert(varchar(10),dt.[datepaid],101) as 'DatePaid' --,dt.hservicecd,sv.svcdesc,[MODIF]
,convert(varchar(10),dt.fromdatesvc,101) as 'svcdatefrom'
,convert(varchar(10),dt.todatesvc,101) as 'svcdateto'
--, ISNULL(hm.admhour, ' ') as 'admit hour'
--, ISNULL(hm.dschhour, ' ') as 'discharge hour'
--, ISNULL(hm.admtype, ' ') as 'admit type'
, case when dt.hservicecd is null then dt.proccode else dt.hservicecd end as 'Procedure'
, case when sv.svcdesc is null then sv2.svcdesc else sv.svcdesc end as 'ProcDesc'
, ISNULL(dt.hservicecd, ' ') as 'revenue code'
--, convert(varchar(10),hm.datefrom,101) as 'claimdatefrom'
--, CONVERT(VARCHAR(10), d.member_month, 101) AS 'statement covers period to'
--, ' ' as 'HCPCS/Rates'
--, convert(varchar(10),dt.todatesvc,101) as 'service date'
--, ISNULL(dt.MODIF, ' ') as 'MODIF'
--, ISNULL(dt.MODIF2,' ') as 'MODIF2'
--, ISNULL(dt.MODIF3,' ') as 'MODIF3'
--, ISNULL(dt.MODIF4,' ') as 'MODIF4'
, dt.qty AS 'detail_qty' 
, dt.billed as detail_billed
,(dt.[NET]) as detail_net
, ISNULL(vm.vendornm, ' ') as 'BillProvName'
, ISNULL(hm.billprovaddr1,' ') as 'BillProvAdd1'
, ISNULL(hm.billprovaddr3,' ') as 'BillProvAdd3'
, ISNULL(hm.billproviderstate, ' ') as 'BillProvState'
, pv.PROVID as NPI
, vm.TAXID
, hm.placesvc as 'Place of Service Code'
, po.descr as 'Place of Service Description'
, pln.leaf_name as 'Provider Type'
--, prov.rev_fullname as 'Rendering Prov Name'
--, ISNULL(max(pa.STREET), ' ') AS 'prov_street' 
--, ISNULL(max(pa.CITY), ' ' ) AS 'prov_city'
--, ISNULL(max(pa.[STATE]), ' ' ) AS 'prov_state'
--, ISNULL(max(pa.ZIP), ' ' ) AS 'prov_zip'
--, hm.billtype as 'type of bill'
--, max(pa.city + ',' + pa.state) as 'servicing facility location'
--, vm.vendor_npi as 'servicing facility NPI'
--, ISNULL(hm.refprov_firstname + '' + hm.refprov_lastname, ' ') as 'Referring ProvName'
--, ISNULL(hm.RefProvID, ' ' ) as 'referring provider NPI'  --NOTE: DO NOT USE RefProv_KeyID OR IT WILL RESULT IN UNIQUE ID ERROR
--, ISNULL(hm.payer1, ' ') as 'payer name'
--, ISNULL(dt.REND_PROVNPI, ' ') as 'rendering providerNPI'
--, ISNULL(hm.authno, ' ') as 'Prior Auth Number' 
--, sln.leaf_name AS 'service_type'
--, svs.leaf_node
--, meh.CMO
, meh.site_name
, hm.opt AS 'product'
--,case when dt.adjcode is null then '' else dt.adjcode end as adj_code
--,case when ac.descr is null then '' else ac.descr end as AdjCodeDescr
--,vm.VENDORNM
into #temp

  FROM [EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt 
  --left join CCAMIS_NEXT.dbo.ez_claims ez on dt.claimno = ez.claimno
  --LEFT JOIN CCAMIS_NEXT.dbo.ez_claimline AS ezcl 
	--ON dt.claimno = ezcl.claimno
 -- LEFT JOIN CCAMIS_Common.dbo.[services] AS svs 
	--ON ezcl.primcode_full = svs.prime_code_full
  	left join [EZCAP_DTS].[dbo].[service_codes] sv   on dt.hservicecd = sv.svccode and sv.phcode = 'h'
  	--left join [EZCAP_DTS].[dbo].[svccodes] svx   on dt.hservicecd = svx.svccode
	left join [EZCAP_DTS].[dbo].ADJUST_CODES ac on dt.adjcode = ac.code and ac.code_type = 'oa'
	left join [EZCAP_DTS].dbo.CLAIM_masters_v hm on dt.claimno = hm.claimno
	left join [EZCAP_DTS].[dbo].[service_codes] sv2   on dt.proccode = sv2.svccode
	--left join [EZCAP_DTS].dbo.CLAIM_pMASTERS pm on dt.claimno = pm.claimno
	--left join CCAMIS_Common.dbo.ez_services sv3 on dt.proccode = sv3.primcode_full
	left join [EZCAP_DTS].dbo.VEND_MASTERS vm on hm.vendor = vm.vendorid and vm.ADDTYPE <> 'TERMINATED'
 	left join CCAMIS_Common.dbo.ez_providers prov on hm.provid = prov.provid
	left join CCAMIS_Common.dbo.provider_leaf_nodes pln on pln.leaf_id = prov.prov_leaf_node
	--left join ccamis_next.dbo.ez_claims ctype on dt.claimno = ctype.claimno and ctype.hospital_claim_type <> 'Inpatient'
	--LEFT JOIN CCAMIS_Common.dbo.service_leaf_node AS sln 
	--	ON svs.leaf_node = sln.leaf_id
	--left join [EZCAP_DTS].dbo.claim_notes cn on hm.claimno = cn.claimno
 	--left join CCAMIS_Common.dbo.ez_bill_type bt on bt.billtype = hm.billtype
	--left join srvmedsql01.mpsnapshotprod.dbo.vwmp_memberinfo mi on hm.membid = mi.ccaid		
  left join ccamis_common.dbo.dim_date d on hm.dateto = d.date --1733464			
	--left join ccamis_next.dbo.enrollment_premium ep 			
	--on mi.member_id  = ep.member_id and d.member_month = ep.member_month and enroll_pct = 1 --1729791		
LEFT JOIN Medical_Analytics.dbo.member_enrollment_history AS meh
	on hm.membid = meh.CCAID and d.member_month= meh.member_month --dt.todatesvc between meh.enr_span_start and meh.enr_span_end
--left join ccamis_common.dbo.rating_categories rc on ep.rating_category = rc.ratingcode --1729791			
--left join ccamis_common.dbo.primary_care_site pcs on ep.primary_site_id = pcs.site_id --1729791			
   left join ezcap_dts.dbo.PROV_COMPANY_V pv on hm.provid = pv.provid
   left join ezcap_dts.dbo.PROV_addinfo pa on pv.prov_keyid = pa.prov_keyid
   LEFT JOIN EZCAP_DTS.dbo.PLACESVC_CODES AS po 
	ON   hm.PLACESVC=po.CODE
   LEFT JOIN EZCAP_DTS.dbo.Check_Masters as py on dt.checkno = py.checkno
   --left join [EZCAP_DTS].dbo.CLAIM_DIAGS dx   on dx.claimno = hm.claimno
   --left join CCAMIS_Common.dbo.ICD9CM i on dx.diag = i.icd9_code
--left join [CCAMIS_Common].[dbo].[CareManagementEntity_Records] cm on ep.caremgmt_ent_id = cm.caremgmt_ent_id
--left join [CCAMIS_Common].[dbo].[Contracting_Entity_Records] ce on ep.Contract_Ent_ID = ce.Contract_Ent_ID

where --dt.claimno = '20170930921195310293'
--prov.rev_fullname like '%Gorn%Joe%' and
dt.todatesvc between'2018-01-01' and '2019-01-01' --between'2014-05-01' and '2014-06-01'
-- and vm.VENDOR_NPI = '1144754185' --or '1578721338'  --First is Eastway, second NPI is Luo, Yi
--and vm.vendornm like '%Wong%Kwok%'
-- and vm.TAXID = '273858505'
-- and hm.membid = '5364525039'
 --and prov.PROVID like '1346373362%'
and ltrim(rtrim(dt.proccode)) = 'S5170'
--and diagrefno = 1
--and po.descr not like 'INPATIENT%'
and dt.net > 0
and dt.status = 9
and (lineflag <> 'x' or lineflag is null)

--select * from #temp


select billprovname, taxid, sum(detail_net) as total_paid, sum(detail_qty) as total_qty, sum(detail_net) / sum(detail_qty) as paid_per_unit
from #temp
group by billprovname, taxid
order by 3 desc