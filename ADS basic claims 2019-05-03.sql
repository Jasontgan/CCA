

DECLARE @target_member AS BIGINT		--	= 5364521168
DECLARE @target_product AS VARCHAR(3)	--	= 'SCO'
DECLARE @target_CMO AS VARCHAR(255)		--	= 'Element Care'
DECLARE @target_PCL AS VARCHAR(255)		--	= 'Brightwood'
DECLARE @target_summary AS VARCHAR(255)	--	= 'Holyoke Health Center'
DECLARE @target_capsite AS VARCHAR(255)	--	= 'CCC'
DECLARE @report_begin AS DATE				= '2018-01-01'
DECLARE @report_end AS DATE					= '2018-01-31'


IF OBJECT_ID('tempdb..#ADS_claims') IS NOT NULL DROP TABLE #ADS_claims

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
	, c.revcode AS 'rev_code'
	, c.service_code
	, c.modifier
	, c.modifier2
	, c.service_descr
	, c.code_type									-- CPT-HCPCS, NDC
	, c.units
	, c.TPA_BILLED AS 'billed'
	, c.TPA_ALLOWED AS 'allowed'
	, c.TPA_CONTRVAL AS 'contractual'
	, c.TPA_Net AS 'net'
	, c.TPA_INTEREST AS 'interest'
	, c.cost AS 'paid'
	, c.DenialFlag
	, c.ClaimStatus									-- invoiced (dental claims); paid, hold, etc. (medical claims)
	, c.ClaimLineCategory_CCA
	, c.ClaimLineCategory_CCA2
	, c.claimcategory_gl1
	, c.claimcategory_gl2
	, c.claimcategory_gl3
	, c.provname AS 'provider'
	, c.prov_name
	, c.ProviderID AS 'prov_id'

	--, c.Last_PaidDate AS 'date_paid'
	--, COALESCE(c.DRG, '') AS 'DRG'
	--, COALESCE(c.DRGVersion, '') AS 'DRGVersion'

	--, c.Specialty
      , ISNULL(c.PROV_SPECIALTY, '') AS 'specialty_ID'
      , ISNULL(c.PROV_SPEC1_DESC, '') AS 'specialty_descr'
      --, ISNULL(c.prov_leaf_node, '') AS 'prov_leaf_node'	-- including prov_leaf_node causes an error
      , ISNULL(c.prov_leaf_name, '') AS 'prov_leaf_name'
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
			, adsc.denialflag
			, adsc.TPA_BILLED
			, adsc.TPA_ALLOWED
			, adsc.TPA_CONTRVAL
			, adsc.TPA_Net
			, CASE WHEN adsc.PCA_flag = 1 THEN adsc.TPA_ALLOWED ELSE adsc.TPA_Net END AS 'cost'
			--, adsc.TPA_COB
			--, adsc.TPA_COPAY
			--, adsc.TPA_COINSURANCE
			--, adsc.TPA_DEDUCTIBLE
			, adsc.TPA_Interest
			--, adsc.TPA_Refund
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
			--, adsc.ICDDiag5
			, adsc.ProviderID
			, adsc.provname
			--, '' AS 'ProviderZIP'
			--, '' AS 'ProviderCounty'
			--, '' AS 'ClaimCategory_CCA'
			, adsc.ClaimLineCategory_CCA
			, adsc.ClaimLineCategory_CCA2
			--, adsc.CCA_COB
			--, adsc.CCA_PLAN_PAID
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

		-- SELECT DISTINCT BillType
		-- SELECT DISTINCT Specialty
		-- SELECT TOP 1000 *
		FROM Actuarial_Services.dbo.ADS_Claims AS adsc
		LEFT JOIN EZCAP_DTS.dbo.PLACESVC_CODES AS pos
			ON adsc.POS = pos.CODE
		LEFT JOIN CCAMIS_Common.dbo.ez_bill_type AS bt
			ON adsc.BillType = bt.billtype
		LEFT JOIN Actuarial_Services.dbo.ADS_Providers AS adsp
			ON adsc.ProviderID = adsp.ProviderID
		LEFT JOIN CCAMIS_Common.dbo.[Services] AS svc
			ON adsc.HCPCS = svc.Prime_code_full
		WHERE (adsc.ccaID = @target_member OR @target_member IS NULL)
			AND adsc.ToDate BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
	UNION ALL
		SELECT DISTINCT		-- dental claims
			adsc.ClaimType
			, '' AS 'ClaimType2'
			, adsc.ClaimNo
			, adsc.ClaimID
			, adsc.LineNum
			, CASE WHEN dent_invoice_date IS NULL THEN '' ELSE 'invoiced' END AS 'ClaimStatus'
			, adsc.DenialFlag
			, adsc.TPA_BILLED
			, adsc.TPA_ALLOWED
			, adsc.TPA_CONTRVAL
			, adsc.TPA_NET
			, adsc.TPA_NET AS 'cost'
			--, adsc.TPA_COB
			--, adsc.TPA_COPAY
			--, adsc.TPA_COINSURANCE
			--, adsc.TPA_DEDUCTIBLE
			, adsc.TPA_INTEREST
			--, adsc.TPA_REFUND
			--, '' AS 'TPA_MC_PATIENTLIABILITY'
			, adsc.CCAID
			--, adsmm.enroll_pct
			--, adsmm.CMO
			, adsc.fromdate
			, adsc.ToDate
			, adsc.From_YRMO
			, adsc.To_YRMO
			, adsc.PaidDate
			--, adsc.Paid_YRMO
			, ISNULL(adsc.HCPCS, '') AS 'service_code'
			, 'CPT-HCPCS' AS 'code_type'
			, '' AS 'Modifier'
			, '' AS 'Modifier2'
			, ISNULL(svc.Service_desc, '') AS 'service_descr'
			, '' AS 'Revcode'
			, 1 AS 'Units'
			, '' AS 'BillType'
			, '' AS 'BillType_descr'
			, '' AS 'POS'
			, '' AS 'POS_descr'
			, '' AS 'DRG'
			, '' AS 'DRGVersion'
			, ISNULL(adsc.ICDVersion, '') AS 'ICDVersion'
			, ISNULL(adsc.ICDDiag1, '') AS 'ICDDiag1'
			, ISNULL(adsc.ICDDiag2, '') AS 'ICDDiag2'
			, ISNULL(adsc.ICDDiag3, '') AS 'ICDDiag3'
			, ISNULL(adsc.ICDDiag4, '') AS 'ICDDiag4'
			--, '' AS 'ICDDiag5'
			, adsc.ProviderID
			, adsc.provname
			--, adsc.ProviderZIP
			--, adsc.ProviderCounty
			--, adsc.ClaimCategory_CCA
			, adsc.ClaimLineCategory_CCA
			, adsc.ClaimLineCategory_CCA2
			--, adsc.CCA_COB
			--, adsc.CCA_PLAN_PAID
			--, adsc.CCA_PLAN_READYTOPAY
			--, adsc.CCA_PATIENTPAY
			, adsc.claimcategory_gl1
			, adsc.claimcategory_gl2
			, adsc.claimcategory_gl3
			, '' AS 'Medicaid_Medicare'
			, '' AS 'Specialty'
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

		-- SELECT TOP 1000 *
		FROM Actuarial_Services.dbo.ADS_Claims_Dental AS adsc
		LEFT JOIN Actuarial_Services.dbo.ADS_Providers AS adsp
			ON adsc.ProviderID = adsp.ProviderID
		LEFT JOIN CCAMIS_Common.dbo.[Services] AS svc
			ON adsc.HCPCS = svc.Prime_code_full
		WHERE (adsc.CCAID = @target_member OR @target_member IS NULL)
			AND adsc.ToDate BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
	UNION ALL
		SELECT DISTINCT		-- transportation claims
			adsc.ClaimType
			, '' AS 'ClaimType2'
			, adsc.ClaimNo
			, adsc.ClaimID
			, adsc.LineNum
			, '' AS 'ClaimStatus'
			, adsc.DenialFlag
			, adsc.TPA_BILLED
			, adsc.TPA_ALLOWED
			, adsc.TPA_CONTRVAL
			, adsc.TPA_NET
			, adsc.TPA_NET AS 'cost'
			--, adsc.TPA_COB
			--, adsc.TPA_COPAY
			--, adsc.TPA_COINSURANCE
			--, adsc.TPA_DEDUCTIBLE
			, adsc.TPA_INTEREST
			--, adsc.TPA_REFUND
			--, '' AS 'TPA_MC_PATIENTLIABILITY'
			, adsc.CCAID
			--, adsmm.enroll_pct
			--, adsmm.CMO
			, adsc.fromdate
			, adsc.ToDate
			, adsc.From_YRMO
			, adsc.To_YRMO
			, adsc.PaidDate
			--, adsc.Paid_YRMO
			, ISNULL(adsc.HCPCS, '') AS 'service_code'
			, 'CPT-HCPCS' AS 'code_type'
			, ISNULL(adsc.Modifier, '') AS 'Modifier'
			, ISNULL(adsc.Modifier2, '') AS 'Modifier2'
			, ISNULL(svc.Service_desc, '') AS 'service_descr'
			, '' AS 'Revcode'
			, adsc.Units
			, '' AS 'BillType'
			, '' AS 'BillType_descr'
			, '' AS 'POS'
			, '' AS 'POS_descr'
			, '' AS 'DRG'
			, '' AS 'DRGVersion'
			, '' AS 'ICDVersion'
			, '' AS 'ICDDiag1'
			, '' AS 'ICDDiag2'
			, '' AS 'ICDDiag3'
			, '' AS 'ICDDiag4'
			--, '' AS 'ICDDiag5'
			, adsc.ProviderID
			, adsc.provname
			--, adsc.ProviderZIP
			--, '' AS 'ProviderCounty'
			--, adsc.ClaimCategory_CCA
			, adsc.ClaimLineCategory_CCA
			, adsc.ClaimLineCategory_CCA2
			--, adsc.CCA_COB
			--, adsc.CCA_Plan_Paid
			--, adsc.CCA_PLAN_READYTOPAY
			--, adsc.CCA_PATIENTPAY
			, adsc.claimcategory_gl1
			, adsc.claimcategory_gl2
			, adsc.claimcategory_gl3
			, '' AS 'Medicaid_Medicare'
			, '' AS 'Specialty'
			--, '' AS 'PROV_LEAF_NODE'
			, '' AS 'prov_leaf_name'
			, '' AS 'PROV_CLASS'
			, '' AS 'PROV_CLASSDESC'
			, '' AS 'PROV_SPECIALTY'
			, '' AS 'PROV_SPEC1_DESC'
			, '' AS 'PROV_SPECIALTY2'
			, '' AS 'PROV_SPEC2_DESC'
			, '' AS 'VEND_VENDORID'
			, '' AS 'VEND_TAXID'
			, '' AS 'VEND_NPI'
			, '' AS 'VEND_Name'
			, '' AS 'PROV_ASSIGNMENT_CACTUS'
			, '' AS 'PROVIDER_NPI_CACTUS'
			, '' AS 'prov_name'
			, '' AS 'PROV_MI'

		-- SELECT TOP 1000 *
		FROM Actuarial_Services.dbo.ADS_Claims_Transp AS adsc
		LEFT JOIN Actuarial_Services.dbo.ADS_Providers AS adsp
			ON adsc.ProviderID = adsp.ProviderID
		LEFT JOIN CCAMIS_Common.dbo.[Services] AS svc
			ON adsc.HCPCS = svc.Prime_code_full
		WHERE (adsc.CCAID = @target_member OR @target_member IS NULL)
			AND adsc.ToDate BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
	UNION ALL
		SELECT DISTINCT		-- pharmacy claims
			adsc.ClaimType
			, '' AS 'ClaimType2'
			, adsc.ClaimNo
			, 'RX' + adsc.ClaimNo AS 'ClaimID'
			, 1 AS 'linenum'
			, '' AS 'ClaimStatus'
			, 'N' AS 'denialflag'
			, adsc.TPA_BILLED
			, adsc.TPA_ALLOWED
			, adsc.TPA_CONTRVAL
			, adsc.TPA_NET
			, adsc.TPA_NET AS 'cost'
			--, adsc.TPA_COB
			--, adsc.TPA_COPAY
			--, adsc.TPA_COINSURANCE
			--, adsc.TPA_DEDUCTIBLE
			, adsc.TPA_INTEREST
			--, adsc.TPA_REFUND
			--, '' AS 'TPA_MC_PATIENTLIABILITY'
			, adsc.ccaID
			--, adsmm.enroll_pct
			--, adsmm.CMO
			, adsc.fromdate
			, adsc.fromdate AS 'ToDate'
			, adsc.From_YRMO
			, adsc.From_YRMO AS 'To_YRMO'
			, adsc.Last_PaidDate
			--, adsc.Last_Paid_YRMO
			, adsc.Rx_NDC
			, 'NDC' AS 'code_type'
			, '' AS 'Modifier'
			, '' AS 'Modifier2'
			, adsc.Rx_Drug_Long
			, '' AS 'Revcode'
			, 1 AS 'Units'
			, '' AS 'BillType'
			, '' AS 'BillType_descr'
			, '' AS 'POS'
			, '' AS 'POS_descr'
			, '' AS 'DRG'
			, '' AS 'DRGVersion'
			, '' AS 'ICDVersion'
			, '' AS 'ICDDiag1'
			, '' AS 'ICDDiag2'
			, '' AS 'ICDDiag3'
			, '' AS 'ICDDiag4'
			--, '' AS 'ICDDiag5'
			, adsc.ProviderID
			, adsc.provname
			--, adsc.ProviderZIP
			--, '' AS 'ProviderCounty'
			--, '' AS 'ClaimCategory_CCA'
			, adsc.ClaimLineCategory_CCA
			, '' AS 'ClaimLineCategory_CCA2'
			--, CCA_COB
			--, CCA_PLAN_PAID
			--, CCA_PLAN_READYTOPAY
			--, CCA_PATIENTPAY
			, adsc.claimcategory_gl1
			, adsc.claimcategory_gl2
			, adsc.claimcategory_gl3
			, '' AS 'Medicaid_Medicare'
			, '' AS 'Specialty'
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

		-- SELECT TOP 1000 *
		FROM Actuarial_Services.dbo.ADS_Claims_Rx AS adsc
		LEFT JOIN Actuarial_Services.dbo.ADS_Providers AS adsp
			ON adsc.ProviderID = adsp.ProviderID
		LEFT JOIN CCAMIS_Common.dbo.[Services] AS svc
			ON adsc.Rx_NDC = svc.Prime_code_full
		WHERE (adsc.ccaID = @target_member OR @target_member IS NULL)
			AND adsc.fromdate BETWEEN @report_begin AND COALESCE(@report_end, '9999-12-30')
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
ORDER BY
	CCAID
	, date_from
	, date_to
	, ClaimType
	, ClaimType2
	, Source_claim_no
	, linenum
PRINT '#ADS_claims'
-- SELECT TOP 1000 * FROM #ADS_claims WHERE CCAID <> '' ORDER BY CCAID, date_from, date_to, ClaimType, ClaimType2, ClaimID, Source_claim_no, linenum
-- SELECT * FROM #ADS_claims ORDER BY CCAID, date_from, date_to, ClaimType, ClaimType2, ClaimID, Source_claim_no, linenum
-- SELECT COUNT(*) AS 'row_count' FROM #ADS_claims	--10488911	--778899
-- SELECT COUNT(DISTINCT CCAID) AS 'member_count' FROM #ADS_claims	--34775	--24162
-- SELECT FORMAT(SUM(paid), 'C', 'en-us') AS 'paid_sum' FROM #ADS_claims	--$1,036,274,153.02	--$78,113,166.36
-- SELECT DISTINCT code_type FROM #ADS_claims ORDER BY code_type
-- invalid IDs:
	-- SELECT CCAID, COUNT(*) AS 'row_count' FROM #ADS_claims WHERE CCAID IS NULL OR CCAID NOT BETWEEN 5364521036 AND 5369999999 GROUP BY CCAID
-- code trim check:
	-- SELECT * FROM #ADS_claims WHERE LEFT(service_code, 5) <> service_code AND code_type = 'CPT-HCPCS'
-- duplicate rows?
	-- SELECT CCAID, ClaimID, linenum, COUNT(*) FROM #ADS_claims GROUP BY CCAID, ClaimID, linenum HAVING COUNT(*) > 1 ORDER BY CCAID, ClaimID, linenum
-- SELECT ClaimType, ClaimStatus, DenialFlag, COUNT(DISTINCT ClaimID) AS 'claims' FROM #ADS_claims GROUP BY ClaimType, ClaimStatus, DenialFlag ORDER BY ClaimType, ClaimStatus, DenialFlag
-- SELECT DISTINCT Product, Name FROM #ADS_claims ORDER BY Product, Name


SELECT TOP 1000
	adsc.*
FROM #ADS_claims AS adsc
WHERE adsc.CCAID <> ''
	AND adsc.ClaimStatus = '9-PAID'
ORDER BY
	adsc.CCAID
	, adsc.date_from
	, adsc.date_to
	, adsc.ClaimType
	, adsc.ClaimType2
	, adsc.ClaimID
	, adsc.Source_claim_no
	, adsc.linenum

