/*
Want to review metrics for Digital Breast Tomosynthesis and code utilization of	
	77061, 77062, 77063, and G0279 

The payments made on DBT codes and review of the procedures, diagnoses, providers etc. 
claim dates:
01/01/2018
09/30/2019

*/

/*Claim Reporting*/
/*Claims for member list*/
IF OBJECT_ID('tempdb..#ADS_claims') IS NOT NULL DROP TABLE #ADS_claims
DECLARE @target_member AS BIGINT		--	= 5364521168
DECLARE @target_product AS VARCHAR(3)	--	= 'SCO'
DECLARE @target_CMO AS VARCHAR(255)		--	= 'Element Care'
DECLARE @target_PCL AS VARCHAR(255)		--	= 'Brightwood'
DECLARE @target_summary AS VARCHAR(255)	--	= 'Holyoke Health Center'
DECLARE @target_capsite AS VARCHAR(255)	--	= 'CCC'
DECLARE @report_begin AS DATE				= '2018-11-01'
DECLARE @report_end AS DATE					= '2020-12-30'
SELECT DISTINCT
	CASE WHEN c.CCAID NOT BETWEEN 5364521036 AND 5369999999 THEN '' ELSE COALESCE(c.CCAID, '') END AS 'CCAID'
	--, COALESCE(adsmm.MedicareMBI, '') AS 'MBI'
	--, COALESCE(adsmm.MedicareHIC, '') AS 'HICN'
	--, COALESCE(adsmm.MMIS_ID, '') AS 'MMIS_ID'
	, UPPER(adsmem.Name) AS 'Name'
	, adsmem.DOB
	, adsmm.Product
	, adsmm.enroll_pct
	, adsmm.CMO
	, adsmm.CMO_Group
	, CASE WHEN adsmm.Product = 'ICO'		-- revised 2017-12-22
		THEN CASE WHEN adsmm.CMO IN ('CCA-BHI', 'CCACG EAST', 'CCACG WEST', 'CCACG-Central', 'CCC-Boston', 'CCC-Framingham', 'CCC-Lawrence', 'CCC-Springfield', 'SCMO') THEN 'CCA'
			WHEN adsmm.CMO IN ('Advocates, Inc', 'Bay Cove Hmn Srvces', 'Behavioral Hlth Ntwrk', 'BosHC 4 Homeless', 'CommH Link Worc', 'Lynn Comm HC', 'Vinfen') THEN 'Health Home'
			END
		WHEN adsmm.Product = 'SCO'
		THEN CASE WHEN adsmm.CMO IN ('CCACG EAST', 'CCACG WEST', 'CCACG-Central', 'CCC-Boston', 'CCC-Framingham', 'CCC-Lawrence', 'CCC-Springfield', 'SCMO') THEN 'CCA'
			WHEN CMO IN ('BIDJP Subacute', 'BU Geriatric Service', 'East Boston Neighborhoo', 'Element Care', 'Uphams Corner Hlth Cent') THEN 'Delegated Site'
			END
		END AS 'CMO_type'
	, Membership_Type
	, adsmm.MP_PCL_SiteName
	, adsmm.MP_PCL_SummaryName
	, adsmm.MP_PCL_CapSite
	, adsmm.RateCell
	, adsmm.RateCell2 AS 'reportingclass'
	, adsmm.Region
	, adsmm.Dual
	, adsmm.City
	, adsmm.County
	, adsmm.Zipcode AS 'ZIP'
	, ClaimType										-- Dental, PCG-Medical, Pharmacy, Transportation	
	, c.ClaimType2									-- P or H
	, c.ClaimID
	, c.CLAIMNO AS 'Source_claim_no'
	, c.linenum
	, c.BillType
	, c.BillType_descr
	, c.claimline_versions
	, c.POS
	, c.POS_descr
	, c.FromDate AS 'date_from'
	, c.ToDate AS 'date_to'
	, CAST(c.To_YRMO + '01' AS DATE) AS 'member_month'
	, c.ICDVersion
	, c.ICDDiag1
	, c.ICDDiag2
	, c.ICDDiag3
	, c.ICDDiag4
	, c.ICDDiag5
	, c.revcode AS 'rev_code'
	, c.service_code
	, c.modifier
	, c.modifier2
	, c.modifier3
	, c.modifier4
	, c.service_descr
	, c.code_type									-- CPT-HCPCS, NDC
	, c.units
	, c.TPA_BILLED AS 'billed'
	, c.TPA_ALLOWED AS 'allowed'
	, c.TPA_CONTRVAL AS 'contractual'
	, c.TPA_Net AS 'net'
	, c.TPA_INTEREST AS 'interest'
	, c.cost AS 'paid'
	, c.TPA_COPAY
	, c.TPA_Interest
	, c.TPA_Refund
	, c.CCA_PLAN_PAID
	, c.DenialFlag
	, c.ClaimStatus									-- invoiced (dental claims); paid, hold, etc. (medical claims)
	, c.ClaimLineCategory_CCA
	, c.ClaimLineCategory_CCA2
	, c.claimcategory_gl1
	, c.claimcategory_gl2
	, c.claimcategory_gl3
	, c.provname AS 'provider'
	, c.prov_name
	, c.ProviderID_Full AS 'prov_id'
	, c.PCA_Flag
	--, c.Last_PaidDate AS 'date_paid'
	, COALESCE(c.DRG, '') AS 'DRG'
	--, COALESCE(c.DRGVersion, '') AS 'DRGVersion'

	, c.Specialty
      , ISNULL(c.PROV_SPECIALTY, '') AS 'specialty_ID'
      , ISNULL(c.PROV_SPEC1_DESC, '') AS 'specialty_descr'
      --, ISNULL(c.prov_leaf_node, '') AS 'prov_leaf_node'	-- including prov_leaf_node causes an error
      , ISNULL(c.prov_leaf_name, '') AS 'prov_leaf_name'
	  ,c.prov_street 
	, c.prov_city
	, c.prov_state
	, c.prov_zip
      --, c.PROV_CLASS
      --, c.PROV_CLASSDESC
      , ISNULL(c.vend_name, '') AS 'vend_name'
      , ISNULL(c.VEND_VENDORID, '') AS 'vendor_ID'
      , ISNULL(c.VEND_TAXID, '') AS 'vendor_taxID'
      , ISNULL(c.VEND_NPI, '') AS 'vendor_NPI'
      --, c.PROV_ASSIGNMENT_CACTUS
      --, c.PROVIDER_NPI_CACTUS

INTO #ADS_claims
FROM (
		SELECT DISTINCT		-- medical claims
			adsc.ClaimType
			, adsc.ClaimType2
			, adsc.CLAIMNO
			, adsc.ClaimID
			, adsc.linenum
			, adsc.ClaimStatus
			,adsc.claimline_versions
			, adsc.denialflag
			, adsc.TPA_BILLED
			, adsc.TPA_ALLOWED
			, adsc.TPA_CONTRVAL
			, adsc.TPA_Net
			, CASE WHEN adsc.PCA_flag = 1 THEN adsc.TPA_ALLOWED ELSE adsc.TPA_Net END AS 'cost'
			, adsc.PCA_Flag
			--, adsc.TPA_COB
			, adsc.TPA_COPAY
			--, adsc.TPA_COINSURANCE
			--, adsc.TPA_DEDUCTIBLE
			, adsc.TPA_Interest
			, adsc.TPA_Refund
			--, adsc.TPA_MC_PATIENTLIABILITY
			, adsc.CCAID
			--, adsmm.enroll_pct
			--, adsmm.CMO
			, adsc.FromDate
			, adsc.ToDate
			, adsc.From_YRMO
			, adsc.To_YRMO
			, adsc.Last_PaidDate
			--, adsc.LastPaid_Yrmo
			, ISNULL(adsc.HCPCS, '') AS 'service_code'
			, 'CPT-HCPCS' AS 'code_type'
			, ISNULL(adsc.Modifier, '') AS 'Modifier'
			, ISNULL(adsc.Modifier2, '') AS 'Modifier2'
			, ISNULL(adsc.Modifier3, '') AS 'Modifier3'
			, ISNULL(adsc.Modifier4, '') AS 'Modifier4'
			, ISNULL(svc.Service_desc, '') AS 'service_descr'
			, ISNULL(adsc.Revcode, '') AS 'Revcode'
			, adsc.Units
			, ISNULL(adsc.BillType, '') AS 'BillType'
			, ISNULL(bt.DESCR, '') AS 'BillType_descr'
			, ISNULL(adsc.POS, '') AS 'POS'
			, ISNULL(pos.DESCR, '') AS 'POS_descr'
			, adsc.DRG
			, adsc.DRGVersion
			, ISNULL(adsc.ICDVersion, '') AS 'ICDVersion'
			, ISNULL(adsc.ICDDiag1, '') AS 'ICDDiag1'
			, ISNULL(adsc.ICDDiag2, '') AS 'ICDDiag2'
			, ISNULL(adsc.ICDDiag3, '') AS 'ICDDiag3'
			, ISNULL(adsc.ICDDiag4, '') AS 'ICDDiag4'
			, ISNULL(adsc.ICDDiag5, '') AS 'ICDDiag5'
			, adsc.ProviderID_Full
			, adsc.provname
			--, '' AS 'ProviderZIP'
			--, '' AS 'ProviderCounty'
			--, '' AS 'ClaimCategory_CCA'
			, adsc.ClaimLineCategory_CCA
			, adsc.ClaimLineCategory_CCA2
			--, adsc.CCA_COB
			, adsc.CCA_PLAN_PAID
			--, adsc.CCA_PLAN_READYTOPAY
			--, adsc.CCA_PATIENTPAY
			, adsc.claimcategory_gl1
			, adsc.claimcategory_gl2
			, adsc.claimcategory_gl3
			, adsc.Medicaid_Medicare
			, adsc.Specialty
			--, adsp.PROV_LEAF_NODE
			, adsp.prov_leaf_name
			, adsp.PROV_CLASS
			, adsp.PROV_CLASSDESC
			, adsp.PROV_SPECIALTY
			, adsp.PROV_SPEC1_DESC
			, adsp.PROV_SPECIALTY2
			, adsp.PROV_SPEC2_DESC
			, adsp.VEND_VENDORID
			, adsp.VEND_TAXID
			, adsp.VEND_NPI
			, adsp.VEND_Name
			, adsp.PROV_ASSIGNMENT_CACTUS
			, adsp.PROVIDER_NPI_CACTUS
			, COALESCE(adsp.PROV_FIRSTNAME + ' ', '') + COALESCE(adsp.PROV_LASTNAME + ' ', '') AS 'prov_name'
			, adsp.PROV_MI
			, replace(replace(pa.STREET,char(10),''),char(13),'') AS 'prov_street' 
			, ISNULL(pa.CITY, ' ' ) AS 'prov_city'
			, ISNULL(pa.[STATE], ' ' ) AS 'prov_state'
			, ISNULL(pa.ZIP, ' ' ) AS 'prov_zip'
		FROM Actuarial_Services.dbo.ADS_Claims AS adsc
		LEFT JOIN EZCAP_DTS.dbo.PLACESVC_CODES AS pos
			ON adsc.POS = pos.CODE
		LEFT JOIN CCAMIS_Common.dbo.ez_bill_type AS bt
			ON adsc.BillType = bt.billtype
		LEFT JOIN Actuarial_Services.dbo.ADS_Providers AS adsp
			ON adsc.ProviderID_Full = adsp.ProviderID_Full
		left join ezcap_dts.dbo.PROV_COMPANY_V pv on adsp.ProviderID_Full = pv.provid
		left join ezcap_dts.dbo.PROV_addinfo pa on pv.prov_keyid = pa.prov_keyid
		LEFT JOIN CCAMIS_Common.dbo.[Services] AS svc
			ON adsc.HCPCS = svc.Prime_code_full
		WHERE (adsc.ccaID = @target_member OR @target_member IS NULL)
			AND adsc.ToDate BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
			--and adsp.VEND_TAXID in ('62-1529463','59-3205549','65-0127483') 
) AS c
LEFT JOIN Actuarial_Services.dbo.ADS_Member_Months AS adsmm
	ON c.CCAID = adsmm.ccaID
	AND c.To_YRMO = adsmm.YrMo
LEFT JOIN Actuarial_Services.dbo.ADS_Members AS adsmem
	ON c.CCAID = adsmem.ccaID
WHERE (adsmm.Product = @target_product OR @target_product IS NULL)
	AND (adsmm.CMO = @target_CMO OR @target_CMO IS NULL)
	AND (adsmm.MP_PCL_SiteName = @target_PCL OR @target_PCL IS NULL)
	AND (adsmm.MP_PCL_SummaryName = @target_summary OR @target_summary IS NULL)
	AND (adsmm.MP_PCL_CapSite = @target_capsite OR @target_capsite IS NULL)
	--AND LTRIM(RTRIM(c.service_code)) IN ('82306', '82652') 
ORDER BY
	CCAID
	, date_from
	, date_to
	, ClaimType
	, ClaimType2
	, Source_claim_no
	, linenum


SELECT
	adsc.Product
	,adsc.ClaimType2
	,adsc.ccaID
	,[CLAIMNO] = CONCAT('''',adsc.Source_claim_no)
	,adsc.linenum
	,adsc.BillType
	,adsc.POS
	,adsc.claimline_versions
	,adsc.date_from AS FromDate
	,adsc.date_to as ToDate
	,adsc.ICDDiag1
	,adsc.ICDDiag2
	,adsc.ICDDiag3
	,adsc.ICDDiag4
	,adsc.ICDDiag5
	,adsc.DRG
	,Revcode = adsc.rev_code
	,adsc.service_code AS HCPCS
	,adsc.Modifier
	,adsc.Modifier2
	,adsc.Modifier3
	,adsc.Modifier4
	,adsc.Units
	,adsc2.adj1
	,adsc2.adj2
	,adsc.billed AS TPA_BILLED
	,adsc.contractual AS TPA_CONTRVAL
	,adsc.allowed AS TPA_ALLOWED
	,adsc.net AS TPA_Net
	,adsc.interest AS TPA_Interest
	,adsc.CCA_PLAN_PAID
	,adsc.TPA_COPAY
	,adsc.TPA_Refund
	,adsc.ClaimStatus
	,adsc.PCA_Flag
	,adsc.ClaimLineCategory_CCA
	,adsc.Specialty
	,adsc.prov_leaf_name
	,adsc.prov_id AS ProviderID
	,adsc.prov_name AS provname
	,PROV_NPI
	,adsc.vendor_ID AS vendorID
	,adsc.VEND_Name
	,adsc.vendor_NPI AS VEND_NPI
	,adsc.vendor_taxID AS VEND_TAXID
	--,PROV_ADDINFO_ID
	,meh.NAME_FULL AS MemName
	--, meh.c
	,adsc.service_descr AS SVCDESC
	,ac1.DESCR AS adj1_descr
	,YEAR(meh.member_month) AS [year]
	,adsc.prov_street AS svprov_street
	, adsc.prov_city AS svprov_city
	, adsc.prov_state AS svprov_state
	, adsc.prov_zip  AS svprov_zip
	, replace(replace(ISNULL(vm.vendornm, ' '),char(10),''),char(13),'') as 'BillProvName'
	, ISNULL(hm.billprovaddr1,' ') as 'BillProvAdd1'
	, ISNULL(hm.billprovaddr3,' ') as 'BillProvAdd3'
	, ISNULL(hm.billproviderstate, ' ') as 'BillProvState'
	--,VENDOR
into #temp
FROM #ADS_claims AS adsc
INNER JOIN (SELECT CLAIMNO, linenum, adj1, adj2 FROM Actuarial_Services.dbo.ADS_Claims) adsc2 
	ON adsc.Source_claim_no = adsc2.CLAIMNO AND adsc.linenum = adsc2.linenum
left join [EZCAP_DTS].[dbo].ADJUST_CODES ac1 on adsc2.adj1 = ac1.code and ac1.code_type = 'oa'
left join [EZCAP_DTS].[dbo].ADJUST_CODES ac2 on adsc2.adj2 = ac2.code and ac2.code_type = 'oa'
LEFT JOIN Medical_Analytics.dbo.member_enrollment_history meh ON adsc.CCAID=meh.CCAID AND adsc.member_month = meh.member_month
LEFT JOIN (SELECT DISTINCT dt.claimno,dt.tblrowid,dt.FEESCHEDS_ID FROM [EZCAP_DTS].[dbo].[CLAIM_DETAILS] dt) ezdt
	ON adsc.Source_claim_no=ezdt.CLAIMNO
	AND adsc.linenum = ezdt.tblrowid
LEFT JOIN [EZCAP_DTS].[dbo].[FEE_SCHEDS] fee on ezdt.[FEESCHEDS_ID] = fee.[FEESCHEDS_ID]
LEFT JOIN [EZCAP_DTS].dbo.CLAIM_MASTERS_V hm ON adsc.Source_claim_no = hm.CLAIMNO
left join [EZCAP_DTS].dbo.VEND_MASTERS vm on hm.vendor = vm.vendorid
/*Inner Joining claims from Claim Details to get correct From Dates and To Dates*/
--INNER JOIN (SELECT CLAIMNO, TBLROWID, FROMDATESVC,TODATESVC 
--			FROM EZCAP_DTS.dbo.CLAIM_DETAILS
--			WHERE lineflag <> 'x' or lineflag is null) cd 
--	ON adsc.Source_claim_no=cd.CLAIMNO
--	AND adsc.linenum = cd.TBLROWID
--	AND TODATESVC between @report_begin AND @report_end
WHERE adsc.CCAID <> ''
	AND adsc.ClaimStatus = '9-PAID'
	AND LTRIM(RTRIM(adsc.service_code)) IN ('T1019') -- code in one of these
	and adsc.net > 0
ORDER BY
	adsc.CCAID
	, adsc.date_from
	, adsc.date_to
	, adsc.ClaimType
	, adsc.ClaimType2
	, adsc.ClaimID
	, adsc.Source_claim_no
	, adsc.linenum


select count(*) from #temp
--23701

