SELECT hm.[CLAIMNO],
--vm.vendor_npi,
--dt.phcode,
dt.adjrefo,
dt.feescheds_id,
dt.tblrowid
,hm.MEMBID
,meh.dod
,hm.membname
  ,hm.placesvc as Claim_Masters_V_Placesvc
  ,dt.placesvc as Claim_Details_Placesvc
--,convert(varchar(10),dt.[datepaid],101) as 'DatePaid' --,dt.hservicecd,sv.svcdesc,[MODIF]
--,convert(varchar(10),hm.datefrom,101) as 'datefrom2'
--,convert(varchar(10),hm.dateto,101) as 'dateto2'
,convert(varchar(10),dt.fromdatesvc,101) as 'fromdate'
,convert(varchar(10),dt.todatesvc,101) as 'todate'
--,hm.datepaid
,[ADJUST]
,[ADJCODE]
,ac.descr as AdjCodeDesc
,(dt.[NET]) as detail_net
,(dt.qty) as detail_qty
,max(dt.billed) as detail_billed
,hm.inpatdays
,hm.billed as claim_billed
,hm.net as claim_net
,prov.rev_fullname
,hm.provid
--,hm.daterecd
,hm.othpayerauth
  ,hm.crossref_id
  ,hm.billtype
  ,bt.descr as billtypedescr
  ,pln.leaf_name as ProvLeaf
  ,hm.opt
  ,vendornm
  ,dt.phcode
  ,dt.hservicecd
  ,dt.proccode
  --,rc.[CODE]
  --,rc.[DESCR]
  ,d.member_month

  ,case when dt.phcode = 'h' then dt.hservicecd
  else dt.proccode end as 'NPROC'

  ,modif
  --,dt.proccode
  ,case when dt.hservicecd is null then dt.proccode else dt.hservicecd end as 'Procedure'
,case when sv.svcdesc is null then sv2.svcdesc else sv.svcdesc end as 'ProcDesc'
--,cn.notes
--,cn.createdate
--  ,cn.subject
  ,convert(varchar(10),hm.daterecd,101) as 'date_recd'
,convert(varchar(10),dt.datepaid,101) as 'dt date_paid'
,convert(varchar(10),hm.datepaid,101) as 'cmv date_paid'
,dt.status
       ,hm.outcome
       ,dt.placesvc as dtplacesvc
       ,hm.placesvc as hmplacesvc
             ,rc.code
       ,rc.descr
       ,hm.reversed
       ,dt.createdate
       ,dt.LASTCHANGEDATE
       ,dt.detail_notes
             ,dt.checkno
             ,sv2.SVCCODE
             ,sv2.SVCDESC
                           ,hospital_claim_type
                           ,lineflag
                           --,ep.[NP_id]
       
                           ,hm2.drgcode
                           ,cd.diag
                           ,cd.diagdesc
                           ,enr_span_end
                           ,enroll_status
                           INTO #southbay  --select * from #southbay 

--drop table #southbay

  FROM [EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt 
  left join CCAMIS_NEXT.dbo.ez_claims ez on dt.claimno = ez.claimno
       left join [EZCAP_DTS].[dbo].[service_codes] sv   on dt.hservicecd = sv.svccode and sv.phcode = 'h'
       left join [EZCAP_DTS].[dbo].[svccodes] svx   on dt.hservicecd = svx.svccode
left join [EZCAP_DTS].[dbo].[REMITTANCE_CODES] rc on rc.code = dt.remitt_code and rc.code_type is null
       left join [EZCAP_DTS].[dbo].ADJUST_CODES ac on dt.adjcode = ac.code and ac.code_type = 'oa'
       left join [EZCAP_DTS].dbo.CLAIM_masters_v hm on dt.claimno = hm.claimno
       left join [EZCAP_DTS].[dbo].[service_codes] sv2   on dt.proccode = sv2.svccode
       left join [EZCAP_DTS].dbo.CLAIM_pMASTERS pm on dt.claimno = pm.claimno
             left join [EZCAP_DTS].dbo.CLAIM_hMASTERS hm2 on dt.claimno = hm2.claimno
       left join CCAMIS_Common.dbo.ez_services sv3 on dt.proccode = sv3.primcode_full
       left join [EZCAP_DTS].dbo.VEND_MASTERS vm on hm.vendor = vm.vendorid  and vm.ADDTYPE <> 'TERMINATED' --select * from [EZCAP_DTS].dbo.VEND_MASTERS
      left join CCAMIS_Common.dbo.ez_providers prov on hm.provid = prov.provid
       --left join [EZCAP_DTS].dbo.claim_notes cn on hm.claimno = cn.claimno
      left join CCAMIS_Common.dbo.ez_bill_type bt on bt.billtype = hm.billtype
             left join CCAMIS_Common.dbo.provider_leaf_nodes pln on pln.leaf_id = prov.prov_leaf_node
       left join CCAMIS_Common.dbo.members m on hm.membid = m.cca_id
             left join CCAMIS_Common.dbo.dim_date d on d.date = hm.dateto
       left join CCAMIS_current.dbo.enrollment_premium ep on ep.member_id = m.member_id_orig and
             d.member_month = ep.member_month and ep.enroll_pct = 1
             left join ccamis_common.dbo.primary_care_site pcs on ep.primary_site_id = pcs.site_id --1729791
             left join medical_analytics.dbo.member_enrollment_history MEH on hm.membid =  meh.ccaid and meh.member_month = d.member_month
left join ezcap_dts.dbo.claim_diags cd on hm.claimno = cd.claimno and diagrefno = 1

where 
(meh.enroll_status like 'current%' or enr_span_end >='2017-12-01') and
hm.dateto between '2017-01-01' and '2017-12-31'   and
--or 
--hm.claimno in ('20161128921195313566') 
vendornm =  'SOUTH BAY MENTAL HEALTH CENTER, INC.'
--and
--) and
--dt.hservicecd like '%912%'
--dt.checkno = '5099341'
--ltrim(rtrim(dt.hservicecd)) between '100' and '199'
----vendornm like 'north shore community heal%'
--hm.membid = '5365554899'  --and
--hm.provid in ( '222873792','1447344130')
--and ltrim(rtrim(dt.hservicecd)) = '191'
--and dt.proccode in ('h2016')
--dt.claimno in ('20170203821195200155')
  --and 
  --cd.diag like 'z34%'
  --prov.Specialty = '96' or prov.Specialty2 = '96'
--hm.placesvc is null
--and 
--prov.rev_fullname like '%dimasi%'
and 
(lineflag <> 'x' or lineflag is null)
--and ltrim(rtrim(dt.proccode)) in ('90804','90806','90832', '90834', '90791', '90847', '90853', '90882', '90887')
--cn.notes = 'updated L1 modifier to deny time limits as past time limit on both listed claims for same dates
--lf'
--and 
--hm.placesvc in ('21','31') 
----dt.placesvc is  null
--and dt.todatesvc >='2015-01-01'
----and dt.proccode = 'T2003'
--and sv.svcdesc not like 'anesth%'
--and dt.placesvc = '31'
--and vendornm like '%envios%'
--and dt.net <>0
--and dt.status = 9
--and (vendornm like 'medline%')  

group by hm.[CLAIMNO]
--,vm.vendor_npi
,hm.MEMBID
,hm.membname
--,dt.[datepaid]
,hm.datefrom
,hm.dateto
,hm.net
--,hm.datepaid
,hm.inpatdays
,dt.adjrefo
,prov.rev_fullname
,hm.othpayerauth
  ,hm.crossref_id
  ,hm.billtype
  ,bt.descr
  ,hm.placesvc
  ,hm.billed
,[ADJUST]
,[ADJCODE]
,ac.descr
  ,hm.opt
  ,vendornm
  ,dt.hservicecd
  ,dt.proccode
  ,sv.svcdesc
  ,sv2.svcdesc
  ,dt.billed
  ,dt.net
  ,(dt.qty)
  ,dt.tblrowid
  ,hm.daterecd
  ,dt.datepaid
  ,dt.fromdatesvc
  ,dt.todatesvc
    ,modif
       ,dt.status
       ,hm.datepaid
       ,hm.checkno
       ,dt.checkno
       ,hm.provid
       ,hm.outcome
             ,dt.placesvc 
       ,hm.placesvc
       ,rc.code
       ,rc.descr
       ,meh.dod
             ,hm.reversed
                    ,dt.createdate
       ,dt.LASTCHANGEDATE
             ,dt.detail_notes
                           ,sv2.SVCCODE
             ,sv2.SVCDESC
                           ,pln.leaf_name
                           ,hospital_claim_type
                                        ,pln.leaf_id  ,d.member_month
                                                                   ,lineflag,dt.feescheds_id
                    ,hm.othpayerauth                        ,hm2.drgcode
                           ,hm.provid,dt.phcode
                             ,rc.[CODE]                     ,enroll_status
  ,rc.[DESCR] ,cd.diag            ,cd.diagdesc                     ,enr_span_end
--                         ,cn.notes
--,cn.createdate
--  ,cn.subject
order by hm.datefrom 

select distinct sb.member_month, count(distinct sb.membid)
from #southbay sb
inner join medical_analytics.dbo.member_enrollment_history meh
on sb.membid = meh.ccaid
where sb.member_month > '2017-05-01'
and meh.member_month = '2017-10-01'
and meh.ep_enroll = 1
group by sb.member_month


select --distinct sb.member_month, count(distinct sb.membid)
distinct sb.membid as ccaid, meh.name_first, meh.name_last, meh.dob, meh.gender, meh.PCL, meh.cmo, meh.care_mgmt, max(sb.todate) as most_recent_visit
from #southbay sb
inner join medical_analytics.dbo.member_enrollment_history meh
on sb.membid = meh.ccaid
where sb.member_month > '2017-05-01'
and meh.member_month = '2017-10-01'
and meh.ep_enroll = 1
group by sb.membid, meh.name_first, meh.name_last, meh.dob, meh.gender, meh.PCL, meh.cmo, meh.care_mgmt




--select * from medical_analytics.dbo.member_enrollment_history meh
--where ccaid = '5365584729'
--order by 1 desc