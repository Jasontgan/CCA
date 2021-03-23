
/*
-- If you ever get this error:
--		Conversion failed when converting the varchar value '1225017296-01' to data type int.
-- it's because you're connecting Claims to ez_provider instead of provider.
-- For example:

		SELECT * FROM CCAMIS_Common.dbo.ez_providers AS ezp WHERE ezp.provid = '1225017296-01'

-- vs:

		SELECT * FROM CCAMIS_Common.dbo.provider AS p WHERE p.prov_id = '1225017296-01'

-- Note also that ez_services must be converted to services (see below).
-- 
-- In the lines below, CLAIMS connections are active and EZ CLAIMS connections are commented out.
*/

SELECT 
	c.Claim_num
	--ezc.CLAIMNO
	, c.[Source]
	, c.Source_claim_no
	--, cl.claim_num
	--, ezcl.claimno
	, cl.tablerowid
	--, ezcl.tblrowid
	, c.member_id
	--, ezc.MEMBER_ID
	, c.member_id + 5364521034 AS 'CCAID'
	--, ezc.MEMBER_ID + 5364521034 AS 'CCAID'
	, c.prov_id
	, c.vendor_id
	, c.date_received
	, c.date_from
	--, ezc.DATEFROM
	, c.date_to
	--, ezc.DATETO
	, c.Hedis_encounter_type
	--, ezc.HEDIS_ENCOUNTER_TYPE
	, c.hospital_claim_type
	--, ezc.Hospital_Claim_type
	, MAX(c.[days]) AS 'days'
	--, MAX(ezc.INPATIENTDAYS) AS 'days'
	, MAX(c.claim) AS 'claims'
	--, COUNT(DISTINCT ezc.CLAIMNO) AS 'claims'
	, c.ccaICDVersion
	--, ezc.ccaICDVersion
	--, ac.code_type
	, cmv.PLACESVC AS 'POS'
	, pos.DESCR AS 'POS_descr'
	, COUNT(DISTINCT c.claim_num) AS 'claim_count'
	, SUM(cl.net) AS 'net_sum'
-- SELECT TOP 1000 * 
FROM CCAMIS_NEXT.dbo.Claims AS c 
--FROM CCAMIS_NEXT.dbo.ez_claims AS ezc 
-- SELECT TOP 10 * FROM CCAMIS_NEXT.dbo.claimline AS cl
INNER JOIN CCAMIS_NEXT.dbo.claimline AS cl
	ON c.Claim_num = cl.claim_num
-- SELECT TOP 10 * FROM CCAMIS_NEXT.dbo.ez_claimline AS ezcl
--INNER JOIN CCAMIS_NEXT.dbo.ez_claimline AS ezcl  
--	ON ezc.CLAIMNO = ezcl.claimno
INNER JOIN CCAMIS_Common.dbo.members AS m 
	ON c.member_id = m.member_id_orig
	--ON ezc.MEMBER_ID = m.member_id_orig
	AND m.cca_id IS NOT NULL

		--INNER JOIN (
		--	SELECT 
		--		ezcl.claimno
		--		, MAX(CAST(ezcl.todatesvc AS DATE)) AS 'todatesvc'
		--	FROM CCAMIS_NEXT.dbo.ez_claimline AS ezcl
		--	GROUP BY
		--		ezcl.claimno
		--) AS ezcl_todatesvc
		--	ON ezc.CLAIMNO = ezcl_todatesvc.claimno

INNER JOIN CCAMIS_Common.dbo.dim_date AS d -- NOTE: linking on cl.todatesvc will create duplicate entries if summarizing on claim header
	ON CAST(cl.todatesvc AS DATE) = d.[Date] -- NOTE: linking on the date-to in the claims header creates problems.
	--ON CAST(ezcl.todatesvc AS DATE) = d.[Date]
INNER JOIN CCAMIS_NEXT.dbo.enrollment_premium AS ep 
	ON c.member_id = ep.member_id 
	AND d.member_month = ep.member_month 
	AND ep.enroll_pct = 1 
LEFT JOIN CCAMIS_Common.dbo.rating_categories AS rc 
	ON ep.rating_category = rc.ratingcode 
LEFT JOIN CCAMIS_Common.dbo.[Services] AS sv  
	ON cl.prime_code_full = sv.Prime_code_full
--LEFT JOIN CCAMIS_Common.dbo.ez_services AS ezsv  
--	ON ezcl.primcode_full = ezsv.PRIMCODE_FULL
LEFT JOIN CCAMIS_Common.dbo.service_leaf_node AS sln  
	ON sv.leaf_node = sln.leaf_id
	--ON ezsv.leaf_node = sln.leaf_id
LEFT JOIN CCAMIS_Common.dbo.provider AS p
	ON c.prov_id = p.prov_id 
--LEFT JOIN CCAMIS_Common.dbo.ez_providers AS ezp
--	ON ezc.PROVID = ezp.PROVID 
LEFT JOIN CCAMIS_Common.dbo.provider_leaf_nodes AS pln
	ON p.prov_leaf_node = pln.leaf_id
	--ON ezp.Prov_leaf_node = pln.leaf_id
LEFT JOIN CCAMIS_NEXT.dbo.claimdiag AS dx
	ON c.Claim_num = dx.Claim_num
--LEFT JOIN CCAMIS_NEXT.dbo.ez_claimdiag AS ezdx 
--	ON ezc.CLAIMNO = ezdx.claimno
		--LEFT JOIN CCAMIS_NEXT.dbo.ez_claimdiag AS ezdx9 
		--	ON ezc.CLAIMNO = ezdx9.claimno
		--	AND ezc.ccaICDVersion = '9'
		--LEFT JOIN CCAMIS_NEXT.dbo.ez_claimdiag AS ezdx10 
		--	ON ezc.CLAIMNO = ezdx10.claimno
		--	AND ezc.ccaICDVersion = '10'
		--LEFT JOIN CCAMIS_Common.dbo.ICD9CM AS icd9 
		--	ON ezdx9.diag = icd9.ICD9_Code
		--LEFT JOIN CCAMIS_Common.dbo.ICD10cm AS icd10 
		--	ON ezdx10.diag = icd10.DiagCode
LEFT JOIN EZCAP_DTS.dbo.CLAIM_MASTERS_V AS cmv
    ON c.Source_claim_no = cmv.CLAIMNO
--    ON ezc.CLAIMNO = cmv.CLAIMNO
		LEFT JOIN EZCAP_DTS.dbo.PLACESVC_CODES AS pos
			ON cmv.PLACESVC = pos.CODE
LEFT JOIN EZCAP_DTS.dbo.claim_details AS cd  
	ON c.Source_claim_no = cd.CLAIMNO 
	AND cl.tablerowid = cd.TBLROWID
	--ON ezcl.claimno = cd.CLAIMNO 
	--AND ezcl.tblrowid = cd.TBLROWID
LEFT JOIN EZCAP_DTS.dbo.ADJUST_CODES AS ac  
	ON cd.adjcode = ac.code
	AND ac.code_type = 'OA'

WHERE c.[Source] NOT IN ('IBNR','EBRisk','FullCapGross','FullCapOffset','PCapBonus','SCapBonus','ShadowOff') -- these remove capitated amounts from net
	AND cl.fromdatesvc >= '2016-01-01' 
	AND cl.todatesvc <= '2016-01-31 23:59:59'
	--AND ezcl.fromdatesvc >= '2016-01-01' 
	--AND ezcl.todatesvc <= '2016-01-31 23:59:59'
	--AND ep.member_month BETWEEN '2016-01-01' AND '2016-01-31'
	--AND ep.member_id + 5364521034 = 5364521037
	--AND pln.leaf_name = 'Acute Care Hospital' 
	--AND c.hospital_claim_type = 'Emergency' 

GROUP BY
	c.Claim_num
	--ezc.CLAIMNO
	, c.[Source]
	, c.Source_claim_no
	, cl.claim_num
	--, ezcl.claimno
	, cl.tablerowid
	--, ezcl.tblrowid
	, c.member_id
	--, ezc.MEMBER_ID
	, c.prov_id
	, c.vendor_id
	, c.date_received
	, c.date_from
	--, ezc.DATEFROM
	, c.date_to
	--, ezc.DATETO
	, c.Hedis_encounter_type
	--, ezc.HEDIS_ENCOUNTER_TYPE
	, c.hospital_claim_type
	--, ezc.Hospital_Claim_type
	, c.ccaICDVersion
	--, ezc.ccaICDVersion
	--, ac.code_type
	, cmv.PLACESVC
	, pos.DESCR

ORDER BY
	c.Claim_num
	--ezc.CLAIMNO
	--, c.[Source]
	--, c.Source_claim_no
	--, cl.claim_num
	--, ezcl.claimno
	, cl.tablerowid
	--, ezcl.tblrowid
