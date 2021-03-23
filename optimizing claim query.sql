SELECT 
hm.MEMBID as 'CCAID'
,hm.membname
,meh.DOB
,meh.gender				
--,rc.ReportingClass
,meh.address1
,ISNULL(meh.address2, ' ') as 'address2'
, meh.city
, meh.state
, meh.zip
--,CurrentAddress2
--,CurrentAddressCity
, meh.latest_phone
, hm.claimno
 , dt.tblrowid
--,site_name
,convert(varchar(10),hm.dateto,101) as 'claim service date'
,case when hm.EDI_CLAIM_ID is null then 'Paper' else 'EFT' end as 'SubmissionCategory'
,convert(varchar(10),hm.daterecd,101) as 'DateRecd' --,dt.hservicecd,sv.svcdesc,[MODIF]
,convert(varchar(10),dt.[datepaid],101) as 'DatePaid' --,dt.hservicecd,sv.svcdesc,[MODIF]
, ISNULL(dt.checkno, ' ') as 'check number'
,convert(varchar(10),dt.fromdatesvc,101) as 'svcdatefrom'
,convert(varchar(10),dt.todatesvc,101) as 'svcdateto'
, ISNULL(hm.admhour, ' ') as 'admit hour'
, ISNULL(hm.dschhour, ' ') as 'discharge hour'
, ISNULL(hm.admtype, ' ') as 'admit type'
, hm.outcome as 'discharge status'
, case when dt.hservicecd is null then dt.proccode else dt.hservicecd end as 'Procedure'
, case when sv.svcdesc is null then sv2.svcdesc else sv.svcdesc end as 'ProcDesc'
, ISNULL(dt.hservicecd, ' ') as 'revenue code'
, convert(varchar(10),hm.datefrom,101) as 'claimdatefrom'
, CONVERT(VARCHAR(10), d.member_month, 101) AS 'statement covers period to'
--, ' ' as 'HCPCS/Rates'
, convert(varchar(10),dt.todatesvc,101) as 'service date'
, ISNULL(dt.MODIF, ' ') as 'MODIF'
, ISNULL(dt.MODIF2,' ') as 'MODIF2'
, ISNULL(dt.MODIF3,' ') as 'MODIF3'
, ISNULL(dt.MODIF4,' ') as 'MODIF4'
, dt.qty AS 'detail_qty' 
, Diag1
	, dx2.diagdesc as 'diagdesc1'
	, Diag2
	, dx3.diagdesc as 'diagdesc2'
	, Diag3
	, dx4.diagdesc as 'diagdesc3'
	, Diag4
	, dx5.diagdesc as 'diagdesc4'
--, dx.diag
--, dx.diagrefno
--, dx.DIAGDESC
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
, prov.rev_fullname as 'Rendering Prov Name'
--, ISNULL(max(pa.STREET), ' ') AS 'prov_street' 

, replace(replace(max(pa.STREET),char(10),''),char(13),'') AS 'prov_street' 
, ISNULL(max(pa.CITY), ' ' ) AS 'prov_city'
, ISNULL(max(pa.[STATE]), ' ' ) AS 'prov_state'
, ISNULL(max(pa.ZIP), ' ' ) AS 'prov_zip'
, hm.billtype as 'type of bill'
, max(pa.city + ',' + pa.state) as 'servicing facility location'
, vm.vendor_npi as 'servicing facility NPI'
, ISNULL(hm.refprov_firstname + '' + hm.refprov_lastname, ' ') as 'Referring ProvName'
, ISNULL(hm.RefProvID, ' ' ) as 'referring provider NPI'  --NOTE: DO NOT USE RefProv_KeyID OR IT WILL RESULT IN UNIQUE ID ERROR
, ISNULL(hm.payer1, ' ') as 'payer name'
, ISNULL(dt.REND_PROVNPI, ' ') as 'rendering providerNPI'
, ISNULL(hm.authno, ' ') as 'Prior Auth Number' 
--, sln.leaf_name AS 'service_type'
--, svs.leaf_node
, meh.CMO
, meh.site_name
, hm.opt AS 'product'
,case when dt.adjcode is null then '' else dt.adjcode end as adj_code
,case when ac.descr is null then '' else ac.descr end as AdjCodeDescr
--,vm.VENDORNM
--DUPLICATES BELOW--
--,pa.STREET as provstreet
--,pa.CITY as provcity
--,pa.STATE as provstate
--,pa.ZIP as provzip
--,vm.VENDORID
--,NPINO
--,vendornm
--,[CareMgmtEntityDescription]
--,ContractingEntityDescription
--,dt.status
--,pv.contract
--,[ADJCODE]
--,ac.descr
--,hm.inpatdays
--,hm.billed as claim_billed
--,hm.net as claim_net
--,pv.rev_fullname
--,vendornm
--,hm.billtype
--,bt.descr as billtypedescr
--,hm.placesvc
--,hm.opt
--,dt.billed as detailcharges
--,dt.net as detailpaid
--,hm.opt as Product

  FROM [EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt 
  --left join CCAMIS_NEXT.dbo.ez_claims ez on dt.claimno = ez.claimno
  --LEFT JOIN CCAMIS_NEXT.dbo.ez_claimline AS ezcl 
	--ON dt.claimno = ezcl.claimno
 -- LEFT JOIN CCAMIS_Common.dbo.[services] AS svs 
	--ON ezcl.primcode_full = svs.prime_code_full
  	left join [EZCAP_DTS].[dbo].[service_codes] sv   on dt.hservicecd = sv.svccode and sv.phcode = 'h'
  	--left join [EZCAP_DTS].[dbo].[svccodes] svx   on dt.hservicecd = svx.svccode
	left join [EZCAP_DTS].[dbo].ADJUST_CODES ac on dt.adjcode = ac.code  --------------------------************************
	left join [EZCAP_DTS].dbo.CLAIM_masters_v hm on dt.claimno = hm.claimno --------------------------************************
	left join [EZCAP_DTS].[dbo].[service_codes] sv2   on dt.proccode = sv2.svccode
	--left join [EZCAP_DTS].dbo.CLAIM_pMASTERS pm on dt.claimno = pm.claimno
	--left join CCAMIS_Common.dbo.ez_services sv3 on dt.proccode = sv3.primcode_full
	left join [EZCAP_DTS].dbo.VEND_MASTERS vm on hm.vendor = vm.vendorid
 	left join CCAMIS_Common.dbo.ez_providers prov on hm.provid = prov.provid
	left join CCAMIS_Common.dbo.provider_leaf_nodes pln on pln.leaf_id = prov.prov_leaf_node
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
   --left join [EZCAP_DTS].dbo.CLAIM_DIAGS dx   on dx.claimno = hm.claimno
   --left join CCAMIS_Common.dbo.ICD9CM i on dx.diag = i.icd9_code
--left join [CCAMIS_Common].[dbo].[CareManagementEntity_Records] cm on ep.caremgmt_ent_id = cm.caremgmt_ent_id
--left join [CCAMIS_Common].[dbo].[Contracting_Entity_Records] ce on ep.Contract_Ent_ID = ce.Contract_Ent_ID
left join 
(
SELECT claimno,[ccaICDVersion] , isnull([1],'') as Diag1,isnull([2],'') as Diag2,isnull([3],'') as Diag3 ,isnull([4],'') as Diag4
 FROM (
		select cmv.claimno,  diag,diagrefno,cd.[ccaICDVersion]
		from   ezcap_dts.dbo.CLAIM_DIAGS cd 
		inner join  ezcap_dts.dbo.claim_masters_v cmv on cd.claimno =  cmv.claimno
		--left join ccamis_common.[dbo].[ICD10cm] ic10 on cd.diag = ic10.diagcode
		where cmv.dateto>='2014-07-01'
		group by cmv.claimno, diag,diagrefno,cd.[ccaICDVersion]
	  ) AS dx 

		PIVOT 
	  (
		max(diag)

		FOR diagrefno in ([1],[2],[3],[4])
	  ) AS Q
) dxq on hm.claimno = dxq.claimno

LEFT JOIN EZCAP_DTS.dbo.DIAG_CODES AS dx2 on dxq.diag1= dx2.diagcode
LEFT JOIN EZCAP_DTS.dbo.DIAG_CODES AS dx3 on dxq.diag2= dx3.diagcode
LEFT JOIN EZCAP_DTS.dbo.DIAG_CODES AS dx4 on dxq.diag3= dx4.diagcode
LEFT JOIN EZCAP_DTS.dbo.DIAG_CODES AS dx5 on dxq.diag4= dx5.diagcode

where 
--prov.rev_fullname like 'Suburban%'
  dt.todatesvc between'2017-01-01' and '2019-05-31'
--  and hm.MEMBID = '5365566314'
--and vm.VENDOR_NPI in ('1245423615') --or '1578721338'  --First is Eastway, second NPI is Luo, Yi
--and pv.provid = '1245423615'
--and vm.vendornm like '%Whole%'
--and dt.proccode in ('S0280', 'T1023', 'G0175', 'H0046')
and vm.TAXID = '04-2581129'
--divagrefno = 1
and dt.status = 9
and (lineflag <> 'x' or lineflag is null)
and dt.net > 0
--and (pa.STREET like '%'+char(13)+'%' or pa.STREET like '%'+char(10)+'%')
group by 
 hm.[CLAIMNO]
,hm.MEMBID
,hm.membname
--,rc.ReportingClass
--,dt.[datepaid]
,hm.datefrom
,hm.dateto
--,hm.net
--,hm.datepaid
--,hm.inpatdays
--,prov.rev_fullname
-- ,hm.othpayerauth
--  ,hm.crossref_id
,hm.billtype
--,bt.descr
--,hm.placesvc
--,hm.billed
--,[ADJUST]
, dt.[ADJCODE]
,ac.descr
--,cn.notes
,hm.opt
, vm.VENDORNM
--,vm.STREET
--,vm.STREET2
--,vm.CITY
--,vm.STATE
--,vm.ZIP
,vm.VENDORID
,vm.TAXID
, hm.placesvc 
, po.descr
,vm.VENDOR_NPI
,hm.EDI_CLAIM_ID
,dt.hservicecd
,dt.proccode
,sv.svcdesc
,sv2.svcdesc
,dt.billed
,dt.net
--,hm.membname
--,birth_date				
--,hm.MEMBID
--,CurrentAddress1
--,CurrentAddress2
--,CurrentAddressCity
,dt.[datepaid]
--,pcs.site_name
--,pv.rev_fullname
--,pa.street
--,pa.city
--,pa.zip
--,pa.state
--,NPINO
,vendornm
--,pv.contract
,dt.datepaid
--,ContractingEntityDescription
--         ,[CareMgmtEntityDescription]
--,vendornm
--,hm.claimno
,hm.daterecd
,dt.fromdatesvc
,dt.todatesvc
  --,dx.diag
  --,dx.diagrefno
  --,dx.DIAGDESC
,MODIF			
,MODIF2
,MODIF3
,dt.qty		
--,hm.daterecd
,dt.billed 
,dt.net 
,dt.status
--,hm.opt 
,meh.gender
,meh.dob
,meh.address1
,meh.address2
, meh.city
, meh.state
, meh.zip
, meh.latest_phone
, hm.patrel1 
, hm.insname1
, dt.tblrowid
, dt.checkno
, hm.admhour 
, hm.dschhour 
, hm.admtype 
, hm.outcome
, CONVERT(VARCHAR(10), d.member_month, 101)
, dt.modif4
, hm.billprovname
, hm.billprovaddr1
, hm.billprovaddr3
, hm.billproviderstate
, pv.PROVID
, pln.leaf_name 
, prov.rev_fullname 
, hm.refprov_firstname + '' + hm.refprov_lastname 
, hm.RefProvid 
, hm.payer1 
, dt.REND_PROVNPI 
, hm.authno 
--, sln.leaf_name 
--, svs.leaf_node 
--, cm.CareMgmtEntityDescription
, meh.cmo
, meh.site_name
, Diag1
	, Diag2
	, Diag3
	, Diag4
	, dx2.DIAGDESC
	, dx3.DIAGDESC
	, dx4.DIAGDESC
	, dx5.DIAGDESC

order by
   hm.membid
   , hm.claimno
   , dt.tblrowid
