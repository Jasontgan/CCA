/*This query has the new fields incorporated as requested by Mark & Andree.
   Note: If doing a search by TIN, claims could inflate. */

IF OBJECT_ID('tempdb..#ID_crossref') IS NOT NULL DROP TABLE #ID_crossref 
GO	
DECLARE @prov_search VARCHAR(MAX), @StartDate DATETIME, @EndDate DATETIME, @Product VARCHAR(3), @CODE_search VARCHAR(5), @TIN_search VARCHAR(10)

--SET @prov_search	= '%Medline%'	--<---<< enter provider search string here (insert '%' as needed for wildcards; use one '%' to get all providers)
--SET @CODE_search		= '9894%'	--<---<< enter NPI search value here
SET @TIN_search		= '36-2596612'	--<---<< enter Tax ID search here
SET @StartDate		= '2014-05-01'	--<---<< enter earliest service date (from date) here -- YYYY-MM-DD
SET @EndDate		= '9999-12-31'	--<---<< enter latest service date (to date) here -- set as '9999-12-31' if you want all claims to present
--SET @Product		= 'ICO'	--<---<< enter product search here


-- DROP TABLE #ID_crossref
SELECT * INTO #ID_crossref FROM (
--; WITH ID_crossref AS (
	SELECT 
		ds.value AS 'Product'
		, n.NAME_ID
		, CONVERT(BIGINT, n.text2) AS 'CCAID'
		, CONVERT(BIGINT, n.text2) - 5364521034 AS 'Member_ID'
		, CONVERT(BIGINT, a.text1) AS 'Medicaid_ID'
		,n.text4 as 'NPI'
	FROM MPSnapshotProd.dbo.ENTITY_ENROLL_APP AS a 
	INNER JOIN MPSnapshotProd.dbo.NAME  AS n 
		ON a.ENTITY_ID = n.NAME_ID 
		AND a.APP_TYPE = 'mcaid'
	INNER JOIN MPSnapshotProd.dbo.DATE_SPAN AS ds 
		ON n.name_id = ds.NAME_ID 
		AND ds.COLUMN_NAME = 'name_text19'
		AND ds.value IN ('ICO', 'SCO') 
		AND ds.card_type = 'mcaid app'
	WHERE 
		COALESCE(ds.end_date, '9999-12-31') > ds.[start_date]
	GROUP BY 
		ds.value
		, n.NAME_ID
		, n.text2
		, a.text1
		,n.text4
) AS ID_crossref
-- SELECT * FROM #ID_crossref


SELECT 
	 hm.MEMBID AS 'Unique CCAID'  
	 , REPLACE(hm.membname, ', ', ',') AS 'memb_name'
	, CONVERT(VARCHAR(10), m.date_of_birth, 101) AS 'DOB' 
	, meh.gender
	, RTRIM(REPLACE(REPLACE(addr.ADDRESS1, CHAR(13), ''), CHAR(10), '')) AS 'memb_street1'
	, RTRIM(addr.ADDRESS2) AS 'memb_street2'
	, RTRIM(addr.CITY) AS 'memb_city'
	, RTRIM(addr.COUNTY) AS 'memb_county'
	, RTRIM(addr.ZIP) AS 'memb_ZIP'
	, meh.latest_phone
	, hm.patrel1 as 'patient relationship to insured'
	, hm.insname1 as 'Insured Name'
	, hm.claimno
	, dt.tblrowid
	, CONVERT(VARCHAR(10), hm.dateto, 101) AS 'claim date of service'
	, CASE WHEN hm.EDI_CLAIM_ID IS NULL THEN 'Paper' ELSE 'ETF' END AS 'SubmissionCategory'
	, CONVERT(VARCHAR(10), hm.daterecd, 101) AS 'date_recd'
	, CONVERT(VARCHAR(10), dt.datepaid, 101) AS 'date_paid' 
	, dt.checkno as 'check number'
	, CONVERT(VARCHAR(10), dt.fromdatesvc, 101) AS 'date_svc_from'
	, CONVERT(VARCHAR(10), dt.todatesvc, 101) AS 'date_svc_to'
	, hm.admhour as 'admit hour'
	, hm.dschhour as 'discharge hour'
	, hm.admtype as 'admit type'
	, hm.outcome as 'discharge status'
	, dt.proccode 
	, sv2.svcdesc as 'proc_descr'
	--, dt.hservicecd as 'revenue code'
	, ' ' as 'revenue description'
	, CONVERT(VARCHAR(10), hm.datefrom, 101) AS 'date_claim_from'
	, CONVERT(VARCHAR(10), d.member_month, 101) AS 'statement covers period to'
	, ' ' as 'HCPCS/Rates'
	, dt.todatesvc as 'service date'
	, dt.MODIF 
	, dt.MODIF2
	, dt.MODIF3
	, dt.MODIF4
	, dt.qty AS 'detail_qty' 
	, Diag1
	, dx2.diagdesc as 'diagdesc1'
	, Diag2
	, dx3.diagdesc as 'diagdesc2'
	, Diag3
	, dx4.diagdesc as 'diagdesc3'
	, Diag4
	, dx5.diagdesc as 'diagdesc4'
	--, ' ' as 'Diag Qualifier'
	--, hm.placesvc as 'place of service'
	, dt.billed AS 'detail_billed'
	, dt.NET AS 'detail_net'
	, vm.vendornm as 'billing provider name'
	, ISNULL(vm.street,' ') as 'BillProvAdd1'
	, ISNULL(vm.street2,' ') as 'BillProvAdd2'
	, ISNULL(vm.city, ' ') + ',' + ' ' + ISNULL(vm.state, ' ') + ' ' + ISNULL(left(vm.zip,5),' ') as 'BillProvAdd3'
	, pv.PROVID as NPI
	, vm.TAXID
	, hm.placesvc as 'Place of Service Code'
	, po.descr as 'Place of Service Description'
	, pln.leaf_name as 'Provider Type'
	, pv.rev_fullname as 'Rendering ProvName'
	, pa.STREET AS 'prov_street' 
	, pa.CITY AS 'prov_city'
	--, pa.COUNTY AS 'prov_county'
	, pa.[STATE] AS 'prov_state'
	, pa.ZIP AS 'prov_zip'
	, hm.billtype as 'type of bill'
	, pa.city + ',' + pa.state as 'servicing facility location'
	, vm.vendor_npi as 'servicing facility NPI'
	, hm.refprov_firstname + '' + hm.refprov_lastname as 'Referring ProvName'
	, hm.RefProv_KeyId_NPI as 'referring provider NPI'
	, hm.payer1 as 'payer name'
	, dt.REND_PROVNPI as 'rendering providerNPI'
	, hm.authno as 'Prior Auth Number' 
	, sln.leaf_name AS 'service_type'
	, svs.leaf_node
	--, max(meh.rc) as 'reporting class'
	, cm.CareMgmtEntityDescription AS 'CMO'
	--, ce.ContractingEntityDescription AS 'contr_entity'
	, pcs.site_name as 'site name'
	--, max(meh.cap_site) as 'cap site' 
	--, max(meh.summary_name) as 'summary name'
	--, max(meh.contract_entity) as 'contract entity'
	, hm.opt AS 'product'
	, CASE WHEN dt.adjcode IS NULL THEN '' ELSE dt.adjcode END AS 'adj_code'
	--, ac.Code_Type
	, CASE WHEN ac.DESCR IS NULL THEN '' ELSE ac.DESCR END AS 'adj_code_descr'
	--, pv.[contract]
	
	--, CHAR(39) + hm.claimno AS txt_claimno  -- converts claim number into text to get around truncation in Excel
	--, dt.tblrowid AS claim_item
	--, ezcl.primcode_full
	--,vm.state as VendorState

into ##Temp

--drop table ##Temp

FROM EZCAP_DTS.dbo.CLAIM_DETAILS AS dt 
LEFT JOIN EZCAP_DTS.dbo.CLAIM_MASTERS_V AS hm
	ON dt.claimno = hm.claimno
LEFT JOIN #ID_crossref AS id
	ON hm.MEMBID = id.CCAID 
LEFT JOIN CCAMIS_NEXT.dbo.ez_claims AS ez 
	ON dt.claimno = ez.claimno
LEFT JOIN EZCAP_DTS.dbo.service_codes AS sv 
	ON dt.hservicecd = sv.svccode 
	--AND sv.phcode = 'h'
LEFT JOIN CCAMIS_NEXT.dbo.ez_claimline AS ezcl 
	ON dt.claimno = ezcl.claimno
	AND dt.TBLROWID = ezcl.tblrowid
LEFT JOIN CCAMIS_Common.dbo.[services] AS svs 
	ON ezcl.primcode_full = svs.prime_code_full
LEFT JOIN EZCAP_DTS.dbo.svccodes AS svx 
	ON dt.hservicecd = svx.svccode
LEFT JOIN EZCAP_DTS.dbo.ADJUST_CODES AS ac
	ON dt.adjcode = ac.code
	AND ac.Code_Type = 'OA'
LEFT JOIN EZCAP_DTS.dbo.SERVICE_CODES AS sv2 
	ON dt.proccode = sv2.svccode
--LEFT JOIN EZCAP_DTS.dbo.CLAIM_PMASTERS AS pm 
--	ON dt.claimno = pm.claimno
--LEFT JOIN CCAMIS_Common.dbo.ez_services AS sv3 
	--ON dt.proccode = sv3.primcode_full
LEFT JOIN EZCAP_DTS.dbo.VEND_MASTERS AS vm 
	ON hm.vendor = vm.vendorid
	AND vm.addtype <> 'TERMINATED'
LEFT JOIN CCAMIS_Common.dbo.ez_providers AS prov 
	ON hm.provid = prov.provid
left join CCAMIS_Common.dbo.provider_leaf_nodes pln on pln.leaf_id = prov.prov_leaf_node
--LEFT JOIN CCAMIS_Common.dbo.ez_bill_type AS bt 
	--ON bt.billtype = hm.billtype
LEFT JOIN CCAMIS_Common.dbo.dim_date AS d 
	ON hm.dateto = d.date 
LEFT JOIN CCAMIS_Common.dbo.members AS m 
	ON id.Member_ID = m.member_id_orig 
LEFT JOIN (
	SELECT 
		NAME_ID
		, ADDRESS1
		, ADDRESS2
		, CITY
		, COUNTY
		, [STATE]
		, ZIP
		, ZIP_4
		, COUNTRY
	FROM
		MPSnapshotProd.dbo.NAME_ADDRESS
	WHERE 
		PREFERRED_FLAG = 'x'
) AS addr
	ON id.NAME_ID = addr.NAME_ID 
LEFT JOIN CCAMIS_CURRENT.dbo.enrollment_premium AS ep 
	ON id.Member_ID = ep.member_id 
	AND d.member_month = ep.member_month 
	AND ep.enroll_pct = 1
LEFT JOIN CCAMIS_Common.dbo.rating_categories AS rc 
	ON ep.rating_category = rc.ratingcode 
LEFT JOIN CCAMIS_Common.dbo.primary_care_site AS pcs 
	ON ep.primary_site_id = pcs.site_id 
LEFT JOIN CCAMIS_Common.dbo.service_leaf_node AS sln 
	ON svs.leaf_node = sln.leaf_id
LEFT JOIN ezcap_dts.dbo.PROV_COMPANY_V AS pv 
	ON hm.provid = pv.provid
LEFT JOIN ezcap_dts.dbo.PROV_addinfo AS pa 
	ON pv.prov_keyid = pa.prov_keyid
	AND pa.[TYPE] = 'PRIMARY'
LEFT JOIN EZCAP_DTS.dbo.PLACESVC_CODES AS po 
	ON   hm.PLACESVC=po.CODE	
LEFT JOIN EZCAP_DTS.dbo.CLAIM_DIAGS AS dx 
	ON dx.claimno = hm.claimno
	AND dx.diagrefno = 1
--LEFT JOIN CCAMIS_Common.dbo.ICD9CM AS i 
--	ON dx.diag = i.icd9_code
LEFT JOIN CCAMIS_Common.dbo.CareManagementEntity_Records AS cm 
	ON ep.caremgmt_ent_id = cm.caremgmt_ent_id
LEFT JOIN CCAMIS_Common.dbo.Contracting_Entity_Records AS ce 
	ON ep.Contract_Ent_ID = ce.Contract_Ent_ID
LEFT JOIN Medical_Analytics.dbo.member_enrollment_history AS meh
	on hm.membid = meh.CCAID and dt.todatesvc between meh.enr_span_start and meh.enr_span_end
	--INNER JOIN [sandbox_SShegow].[dbo].[FWA_NPI] FN on pv.provid =fn.npi
left join (SELECT claimno,[ccaICDVersion] , isnull([1],'') as Diag1,isnull([2],'') as Diag2,isnull([3],'') as Diag3 ,isnull([4],'') as Diag4
--INTO #diag

  FROM (
		select cmv.claimno,  diag,diagrefno,cd.[ccaICDVersion]
		from   ezcap_dts.dbo.CLAIM_DIAGS cd 
		left join  ezcap_dts.dbo.claim_masters_v cmv on cd.claimno =  cmv.claimno
		left join ccamis_common.[dbo].[ICD10cm] ic10 on cd.diag = ic10.diagcode
		where cmv.dateto>='2014-01-01'
		group by cmv.claimno, diag,diagrefno,cd.[ccaICDVersion])

		AS dx 

		PIVOT (max(diag)

		FOR diagrefno in ([1],[2],[3],[4])) AS Q) dxq on hm.claimno = dxq.claimno

LEFT JOIN EZCAP_DTS.dbo.DIAG_CODES AS dx2 on dxq.diag1= dx2.diagcode
LEFT JOIN EZCAP_DTS.dbo.DIAG_CODES AS dx3 on dxq.diag2= dx3.diagcode
LEFT JOIN EZCAP_DTS.dbo.DIAG_CODES AS dx4 on dxq.diag3= dx4.diagcode
LEFT JOIN EZCAP_DTS.dbo.DIAG_CODES AS dx5 on dxq.diag4= dx5.diagcode

WHERE dt.[STATUS] = 9
	AND ((dt.fromdatesvc IS NULL OR dt.todatesvc IS NULL)
		OR (dt.fromdatesvc IS NOT NULL AND dt.todatesvc IS NOT NULL
			AND dt.fromdatesvc >= @StartDate AND dt.todatesvc <= @EndDate)) 
  --  AND ((@Product IS NOT NULL AND hm.opt = @Product) 
		--AND (@prov_search IS NOT NULL AND pv.rev_fullname LIKE @prov_search) 
		--OR (@prov_search IS NOT NULL AND vm.VENDORNM LIKE @prov_search) 
		--OR (@CODE_search IS NOT NULL AND dt.hservicecd LIKE @CODE_search)
		--OR (@CODE_search IS NOT NULL AND dt.proccode LIKE @CODE_search)  
		AND (@TIN_search IS NOT NULL AND vm.TAXID LIKE @TIN_search) 
		--and (ltrim(rtrim(dt.proccode)) not between '99281' and '99285') and (ltrim(rtrim(dt.proccode)) not between 'G0380' and 'G0383') and ltrim(rtrim(dt.proccode)) <> '99291'
		--and  pa.[STATE] not like 'MA'
		--and dt.[PLACESVC] <> '23'
--and id.npi in ('1619085685')
--and hm.membid = '5365554250'
--and CMO = 'CCACG WEST'
--and (meh.cap_site is NOT NULL and meh.rc IS NOT NULL and meh.summary_name IS NOT NULL and meh.contract_entity IS NOT NULL)
--and meh.relmo = '1'
--and vm.TAXID like '%36-2596612%'
and (lineflag <> 'x' or lineflag is null)

GROUP BY 
	hm.claimno
	,hm.membname
	, m.date_of_birth
	, hm.MEMBID
	, addr.ADDRESS1
	, addr.ADDRESS2
	, addr.CITY
	, addr.COUNTY
	, addr.ZIP
	, pcs.site_name
	, pv.rev_fullname
	, pa.STREET
	, pa.CITY
	, pa.COUNTY
	, pa.[STATE]
	, pa.ZIP
	, pv.provid
	, vm.TAXID
	, hm.placesvc 
	, po.descr 
	, vm.VENDORNM
	, hm.EDI_CLAIM_ID
	--, hm.claimno
	, dt.tblrowid 
	, hm.daterecd
	, hm.datefrom
	, hm.dateto
	, d.member_month
	, dt.datepaid
	, dt.fromdatesvc
	, dt.todatesvc
	, Diag1
	, Diag2
	, Diag3
	, Diag4
	, dx2.DIAGDESC
	, dx3.DIAGDESC
	, dx4.DIAGDESC
	, dx5.DIAGDESC
	, dt.HSERVICECD
	, dt.proccode
	, dt.MODIF 
	, dt.MODIF2
	, dt.MODIF3
	, dt.qty 
	, sv.svcdesc
	, sv2.svcdesc
	, sln.leaf_name
	, svs.leaf_node
	, ezcl.primcode_full
	, cm.CareMgmtEntityDescription
	--, ce.ContractingEntityDescription
	, dt.billed
	, dt.NET 
	--, pv.[contract]
	, hm.opt
	, dt.adjcode
	--, ac.Code_Type
	, ac.DESCR
	--, meh.enr_span_start
	--, meh.enr_span_end
	--, meh.enroll_status
	--,vm.state
	, meh.gender
	, meh.latest_phone
	, hm.patrel1
	, hm.insname1
	, dt.checkno
	, hm.admhour
	, hm.dschhour
	, hm.admtype
	, hm.outcome
	, dt.modif4
	, hm.placesvc
	, hm.billprovname
	, hm.billprovaddr1
	, hm.billprovaddr2
	, hm.billprovaddr3
	, hm.billprovaddr4
	, hm.billproviderstate
	, pln.leaf_name
	, dt.rend_provfirstname
	, dt.rend_provlastname
	, hm.billtype
	, vm.city
	, vm.state
	, vm.vendor_npi
	, hm.refprov_firstname
	, hm.refprov_lastname
	, hm.refprov_keyid_npi
	, hm.payer1
	, dt.rend_provnpi
	, hm.authno
	, vm.street
	, vm.street2
	, vm.zip
	--, meh.rc
	--, meh.cap_site
	--, meh.summary_name
	--, meh.contract_entity
	
ORDER BY
	  hm.membid
	, hm.claimno
	, dt.tblrowid
	 

--select * from ##Temp

--select
--		-- CCAID
--		--, Claimno
--		 count(claimno) as 'NumClaims'
--		--, tblrowid
--		 ,sum(detail_net) as 'totalpaid'

--from ##Med
