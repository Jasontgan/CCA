--/****** Script for SelectTopNRows command from SSMS  ******/

----- Date received is still pulling from EZcap, because that field is not in ADS and the Process_date in ADS is not matching the receive date

----- we need to include corrected lines too.  so where it says to include only o or exclude c%, we need to change it.

---------- I feel like adjcode 4 should be exclude
--------------- i feel like 129 shoudl not be exclude


---- NOTES::::: This is all NCP so capitated is not an issue.

---- IS AdjCode 138 an appeal?  dismissal?  exclude?  I will exclude in claims.


	IF OBJECT_ID('tempdb..#adjcodes') IS NOT NULL DROP TABLE #adjcodes

	SELECT * INTO #adjcodes FROM (
		VALUES
		 ('16','Claim/service lacks information or has submission/billing er','Exclude',0)
		,('29','The time limit for filing has expired.','Exclude',0)
		,('129','Prior processing information appears incorrect. At least one','Ignore',0)
		,('208','National Provider Identifier - Not matched.','Exclude',0)
		,('5','The procedure code/bill type is inconsistent with the place ','Exclude',0)
		,('4','The procedure code is inconsistent with the modifier used or','Exclude',0)
		,('146','Diagnosis was invalid for the date(s) of service reported.','Exclude',0)
		,('27','Expenses incurred after coverage terminated.','Exclude',0)
		,('96','Non-covered charge(s). At least one Remark Code must be prov','Exclude',0)
		,('142','Monthly Medicaid patient liability amount.','Paid',0)
		,('206','National Provider Identifier - missing.','Exclude',0)
		,('138','Appeal procedures not followed or time limits not met.','Exclude',0)
		,('193','Original payment decision is being maintained. Upon review, ','Exclude',0)
		,('246','This non-payable code is for required reporting only.','Exclude',0)
		,('251','The attachment/other documentation content received did not ','Exclude',0)
		,('231','Mutually exclusive procedures cannot be done in the same day','Exclude',0)
		,('252','An attachment/other documentation is required to adjudicate ','Exclude',0)
		,('20','This injury/illness is covered by the liability carrier.','Exclude',0)
		,('181','Procedure code was invalid on the date of service.','Exclude',0)
		,('26','Expenses incurred prior to coverage.','Exclude',0)
		,('133','The disposition of the claim/service is pending further revi','Exclude',0)
		,('12','The diagnosis is inconsistent with the provider type. Note: ','Exclude',0)
		,('19','This is a work-related injury/illness and thus the liability','Exclude',0)
		,('8','The procedure code is inconsistent with the provider type/sp','Exclude',0)
		,('107','THE RELATED OR QUALIFYING CLAIM/SERVICE WAS NOT IDENTIFIED O','Exclude',0)
		,('95','Plan procedures not followed.','Exclude',0)
		,('1','Deductible Amount','Exclude',0)
		,('189','Not otherwise classified or unlisted procedure code (CPT/HCP','Exclude',0)
		,('139','Contracted funding agreement - Subscriber is employed by the','Exclude',0)
		,('67','Lifetime reserve days. (Handled in QTY, QTY01=LA)','Exclude',0)
		,('197','Precertification/authorization/notification absent.','Denial',0)
		,('##','SYSTEM-MORE ADJUSTMENTS','Ignore',0)
		,('185','The rendering provider is not eligible to perform the servic','Exclude',0)
		,('204','This service/equipment/drug is not covered under the patient','Denial',0)
		,('39','HA SERVICES EXCEED APPROVED UNITS/DENIED AT TIME AUTH WAS RE','Denial',0)
		,('198','Precertification/authorization exceeded.','Denial',0)
		,('109','CLAIM/SERVICE NOT COVERED BY THIS PAYER/CONTRACTOR. YOU MUST','Exclude',0)
		,('B9','Patient is enrolled in a Hospice.','Exclude',0)
		,('147','Provider contracted/negotiated rate expired or not on file.','Exclude',0)
		,('234','This procedure is not paid separately. At least one Remark C','Exclude',0)
		,('B7','This provider was not certified/eligible to be paid for this','Exclude',0)
		,('256','Service not payable per managed care contract.','denial',0)
		,('170','Payment is denied when performed/billed by this type of prov','Exclude',0)
		,('7','THE PROCEDURE/REVENUE CODE IS INCONSISTENT WITH THE PATIENTS','Exclude',0)
		,('31','Patient cannot be identified as our insured.','Exclude',0)
		,('15','THE AUTHORIZATION NUMBER IS MISSING, INVALID, OR DOES NOT AP','Denial',0)
		,('120','Patient is covered by a managed care plan.','Exclude',0)
		,('243','Services not authorized by network/primary care providers. N','Exclude',0)
		,('205','Pharmacy discount card processing fee','Exclude',0)
		,('6','THE PROCEDURE/REVENUE CODE IS INCONSISTENT WITH THE PATIENTS','Exclude',0)
		,('108','Rent/purchase guidelines were not met. Note: Refer to the 83','Denial',0)
		,('163','Attachment/other documentation referenced on the claim was n','Exclude',0)
		,('18','EXACT DUPLICATE CLAIM/SERVICE','Exclude',0)
		,('85','Patient Interest Adjustment (Use Only Group code PR)','Exclude',0)
		,('#C','SYSTEM-CAPITATED SERVICE','Paid',0)
		,('97','The benefit for this service is included in the payment/allo','Paid',0)
		,('94','Processed in Excess of charges.','Paid',0)
		,('24','Charges are covered under a capitation agreement/managed car','Paid',0)
		,('B15','This service/procedure requires that a qualifying service/pr','Exclude',0)
		,('50','These are non-covered services because this is not deemed a ','Denial',0)
		,('B1','Non-covered visits.','Denial',0)
		,('B16','New Patient qualifications were not met.','Exclude',0)
		,('M77','MISSING/INVALID PLACE OF SERVICE','Exclude',0)
		,('119','Benefit maximum for this time period or occurrence has been ','Denial',0)
		,('236','This procedure or procedure/modifier combination is not comp','Exclude',0)
		,('250','The attachment/other documentation content received is incon','Exclude',0)
		,('13','The date of death precedes the date of service.','Exclude',0)
		,('209','Per regulatory or other agreement. The provider cannot colle','Exclude',0)
		,('B4','Late filing penalty.','Exclude',0)
		,('116','The advance indemnification notice signed by the patient did','Exclude',0)
		,('P21','Payment denied based on Medical Payments Coverage (MPC) or P','Exclude',0)
		,('90','Ingredient cost adjustment. Note: To be used for pharmaceuti','Exclude',0)
		,('152','Payer deems the information submitted does not support this ','Denial',0)
		,('192','Non standard adjustment code from paper remittance. Note: Th','Exclude',0)
		,('B5','COVERAGE/PROGRAM GUIDELINES WERE NOT MET OR WERE EXCEEDED.','Exclude',0)
		,('11','The diagnosis is inconsistent with the procedure. Note: Refe','Exclude',0)
		,('186','Level of care change adjustment.','Exclude',0)
		,('M67','INVALID/INCOMPLETE/MISSING PROCEDURE','Exclude',0)
		,('23','THE IMPACT OF PRIOR PAYER(S) ADJUDICATION INCLUDING PAYMENTS','Exclude',0)
		,('160','Injury/illness was the result of an activity that is a benef','denial',0)
		,('169','Alternate benefit has been provided.','denial',0)
		,('127','Coinsurance -- Major Medical','Exclude',0)
		,('237','Legislated/Regulatory Penalty. At least one Remark Code must','Exclude',0)
		,('M15','DENIED-SEPARATE BILLED TESTS UNBUNDLED','Exclude',0)
		,('B11','The claim/service has been transferred to the proper payer/p','denial',0)
		,('162','State-mandated Requirement for Property and Casualty, see Cl','exclude',0)
		,('93','No Claim level Adjustments.','Exclude',0)
		,('255','The disposition of the related Property & Casualty claim (in','Exclude',0)
		,('M53','MISSING OR INVALID UNITS OF SERVICE','Exclude',0)
		,('41','Discount agreed to in Preferred Provider contract.','Exclude',0)
		,('175','Prescription is incomplete.','Exclude',0)
		,('M86','SVR DENIED/BRIDGED BASED ON TO OTHER CLAIM BASED ON DISCHARG','Denial',0)
		,('115','Procedure postponed, canceled, or delayed.','Denial',0)
		,('126','Deductible -- Major Medical','Exclude',0)
		,('131','Claim specific negotiated discount.','Denial',0)
		,('167','This (these) diagnosis(es) is (are) not covered. Note: Refer','Denial',0)
		,('191','Not a work related injury/illness and thus not the liability','Exclude',0)
		,('22','This care may be covered by another payer per coordination o','Exclude',0)
		,('38','Services not provided or authorized by designated (network/p','Denial',0)
		,('54','Multiple physicians/assistants are not covered in this case.','Denial',0)
		,('59','PROCESSED BASED ON MULTIPLE OR CONCURRENT PROCEDURE RULES. (','Exclude',0)
		,('B13','Previously paid. Payment for this claim/service may have bee','Exclude',0)
		,('B14','Only one visit or consultation per physician per day is cove','Exclude',0)
		,('M49','MISSING/INCOMPLETE/INVALID VALUE CODE OR AMOUNT','Exclude',0)
		,('CCHKAD','ClaimCheck adjust','Exclude',0)
		,('105','Tax withholding.','Exclude',1)
		,('196','Claim/service denied based on prior payers coverage determin','Denial',1)
		,('247','Deductible for Professional service rendered in an Instituti','Denial',1)
		,('249','This claim has been identified as a readmission. (Use only w','Denial',1)
		,('286','APPEAL TIME LIMITS NOT MET','Exclude',1)
		,('55','Procedure/treatment is deemed experimental/investigational b','Denial',1)
		,('79','Cost Report days. (Handled in MIA15)','Exclude',1)
		,('98','The hospital must file the Medicare claim for this inpatient','Denial',1)
		,('M20','MISSING/INVALID HCPCS CODE','Exclude',1)

		) AS x (AdjCode, AdjCodeDesc, OD_2019,NewFlag)

drop table ##ads1

SELECT [ClaimType]
      ,[ClaimType2]
      ,ads.[CLAIMNO]
      ,[ClaimStatus]
      ,[adjudicated_ind]
      ,[claimline_versions]
      ,[RetractedFlag]
      ,[FromDate]
      ,[ToDate]
      ,ezcap.daterecd as DateRecd
      ,[adj_sequence]
      ,[adj_claimdetails]
      ,[adj1]
      ,[adj2]
      ,[adj3]
      ,[adj4]
      ,[adj5]
      ,[adj6]
      ,[First_PaidDate]
      ,[FirstPaid_Yrmo]
      ,[Last_PaidDate]
      ,[LastPaid_Yrmo]
      ,[denialflag]
      ,[Clm_Fully_Den_Ind]
      ,sum([TPA_ALLOWED]) as TPA_Allowed
      ,sum([TPA_BILLED]) as TPA_Billed
      ,sum([TPA_Net]) as TPA_Net
      ,sum([CCA_PLAN_PAID]) as CCA_Plan_Paid
      ,[ClaimLineCategory_CCA]
      ,[ClaimLineCategory_CCA2]
      ,[claimcategory_gl1]
      ,[claimcategory_gl2]
      ,[claimcategory_gl3]
      ,[Medicaid_Medicare]
      ,[HCPCS]
      ,[Modifier]
      ,[Modifier2]
      ,[Modifier3]
      ,[Modifier4]
      ,[Revcode]
      ,sum([Units]) as Units
      ,ads.[BillType]
      ,[POS]
      ,[EZCAPClm_Specialty]
      ,[Specialty]
      ,[AdmitDate]
      ,[Admit_YRMO]
      ,[AdmitDiag]
      ,[AdmitSource]
      ,[AdmitType]
      ,[DischDate]
      ,[Disch_YRMO]
      ,[DischargeStatus]
      ,[Days]
      ,[DRG]
      ,[DRGVersion]
      ,[BH_Diag_Flag]
      ,[ACSC_Flag]
      ,[ICDVersion]
      ,[ICDDiag1]
      ,[ICDDiag2]
      ,[ICDDiag3]
      ,[ICDDiag4]
      ,[ICDDiag5]
      ,[POA1]
      ,[POA2]
      ,[POA3]
      ,[POA4]
      ,[POA5]
      ,[ICDProc1]
      ,[ICDProc2]
      ,[ICDProc3]
      ,[ICDProc4]
      ,[ICDProc5]
      ,[ICDProc6]
      ,[ICDProc7]
      ,[ICDProc8]
      ,[provname]
      ,[ProviderID]
      ,[ProviderID_Full]
      ,ads.[PROV_KEYID]
      ,[BillingProviderID]
      ,[CactusNetworkFlag]
      ,[ccaID]
      ,[Product]
      ,[Dual]

into ##ads1

  FROM [Actuarial_Services].[dbo].[ADS_Claims] ads
  join [EZCAP_DTS].[dbo].[CLAIM_MASTERS_V] ezcap
  on ads.claimno = ezcap.claimno

  where 
  product = 'sco'
  and dual = 'y'
  and medicaid_medicare = 'Medicare'
  and cactusnetworkflag = 'n'
   and [claimline_versions]  not like 'c%'  -- don't want things that are only corrections
  and not (hcpcs = '99999' and revcode is null)

group by [ClaimType]
      ,[ClaimType2]
      ,ads.[CLAIMNO]
      ,[ClaimStatus]
      ,[adjudicated_ind]
      ,[claimline_versions]
      ,[RetractedFlag]
      ,[FromDate]
      ,[ToDate]
      ,ezcap.daterecd 
      ,[adj_sequence]
      ,[adj_claimdetails]
      ,[adj1]
      ,[adj2]
      ,[adj3]
      ,[adj4]
      ,[adj5]
      ,[adj6]
      ,[First_PaidDate]
      ,[FirstPaid_Yrmo]
      ,[Last_PaidDate]
      ,[LastPaid_Yrmo]
      ,[denialflag]
      ,[Clm_Fully_Den_Ind]
      ,[ClaimLineCategory_CCA]
      ,[ClaimLineCategory_CCA2]
      ,[claimcategory_gl1]
      ,[claimcategory_gl2]
      ,[claimcategory_gl3]
      ,[Medicaid_Medicare]
      ,[HCPCS]
      ,[Modifier]
      ,[Modifier2]
      ,[Modifier3]
      ,[Modifier4]
      ,[Revcode]
      ,ads.[BillType]
      ,[POS]
      ,[EZCAPClm_Specialty]
      ,[Specialty]
      ,[AdmitDate]
      ,[Admit_YRMO]
      ,[AdmitDiag]
      ,[AdmitSource]
      ,[AdmitType]
      ,[DischDate]
      ,[Disch_YRMO]
      ,[DischargeStatus]
      ,[Days]
      ,[DRG]
      ,[DRGVersion]
      ,[BH_Diag_Flag]
      ,[ACSC_Flag]
      ,[ICDVersion]
      ,[ICDDiag1]
      ,[ICDDiag2]
      ,[ICDDiag3]
      ,[ICDDiag4]
      ,[ICDDiag5]
      ,[POA1]
      ,[POA2]
      ,[POA3]
      ,[POA4]
      ,[POA5]
      ,[ICDProc1]
      ,[ICDProc2]
      ,[ICDProc3]
      ,[ICDProc4]
      ,[ICDProc5]
      ,[ICDProc6]
      ,[ICDProc7]
      ,[ICDProc8]
      ,[provname]
      ,[ProviderID]
      ,[ProviderID_Full]
      ,ads.[PROV_KEYID]
      ,[BillingProviderID]
      ,[CactusNetworkFlag]
      ,[ccaID]
      ,[Product]
      ,[Dual]

------------FIRST PAID DATE TABLE
----------------------------------------------------------------------------------------------------------------------
drop table #fpd

SELECT  
	dt.[CLAIMNO]
	,sum(dt.net) as Paid
		,min(dt.datepaid) as fpd
	INTO #fpd

  FROM ezcap_dts.dbo.claim_details dt 
  left join ezcap_dts.dbo.claim_masters_v cmv on dt.claimno = cmv.claimno

  where 
  dt.datepaid between '2020-01-01' and '2020-12-31'
	and 
	dt.lineflag in ('o','r')
  and cmv.opt = 'sco'
  	and dt.status = '9'

  group by 	dt.[CLAIMNO]

--/* -----****************************---------------


--EXCLUDED CLAIMLINES FOR ADJUSTMENT CODES 
--MAKES #EXCLUDE TEMP TABLE

drop table #exclude

SELECT
	ca.[CLAIMNO]
	,sum(dt.net) as Paid
	,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd, dt.datepaid

	INTO #Exclude
  FROM [EZCAP_DTS].[dbo].[CLAIM_ADJUSTS] ca
  left join ezcap_dts.dbo.claim_details dt on ca.claimno = dt.claimno and ca.[CLAIMTBLROW] = dt.tblrowid and ca.LINEFLAG = dt.lineflag
  left join ezcap_dts.dbo.adjust_codes ac on ca.adjcode = ac.common_code_id
  left join #adjcodes adj1 on adj1.adjcode = ac.code
    left join ezcap_dts.dbo.claim_masters_v cmv on ca.claimno = cmv.claimno
	inner join #fpd f on ca.claimno = f.claimno and dt.datepaid = f.fpd

  where ADJGRPCODE = 'oa'
  and dt.datepaid between '2020-01-01' and '2020-12-31'
 and dt.lineflag in ('o','r')
  and od_2019 = 'Exclude'
    and cmv.opt = 'sco'
	and dt.status = '9'

  group by ca.[CLAIMNO]
	,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd, dt.datepaid


--- Make Capitated table so Caps don't show up as Denied

drop table #cap

SELECT  
	ca.[CLAIMNO]
	,sum(dt.net) as Paid
		,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd, dt.datepaid
	INTO #cap
  FROM [EZCAP_DTS].[dbo].[CLAIM_ADJUSTS] ca
  left join ezcap_dts.dbo.claim_details dt on ca.claimno = dt.claimno and ca.[CLAIMTBLROW] = dt.tblrowid and ca.LINEFLAG = dt.lineflag
  left join ezcap_dts.dbo.adjust_codes ac on ca.adjcode = ac.common_code_id
  left join #adjcodes adj1 on adj1.adjcode = ac.code
  left join ezcap_dts.dbo.claim_masters_v cmv on ca.claimno = cmv.claimno
  	inner join #fpd f on ca.claimno = f.claimno and dt.datepaid = f.fpd

  where ADJGRPCODE = 'oa'
  and dt.datepaid between '2020-01-01' and '2020-12-31'
 and dt.lineflag in ('o','r')
  and ac.code in ( '#c','24')
  and cmv.opt = 'sco'

  	and dt.status = '9'
  group by 	ca.[CLAIMNO]
		,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd, dt.datepaid

drop table #appeal

SELECT  
	ca.[CLAIMNO]
	,sum(dt.net) as Paid
		,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd, dt.REMITT_CODE, dt.datepaid
	INTO #appeal
  FROM ezcap_dts.dbo.claim_details dt 
  left join [EZCAP_DTS].[dbo].[CLAIM_ADJUSTS] ca on ca.claimno = dt.claimno and ca.[CLAIMTBLROW] = dt.tblrowid and ca.LINEFLAG = dt.lineflag
  left join ezcap_dts.dbo.adjust_codes ac on ca.adjcode = ac.common_code_id
  left join #adjcodes adj1 on adj1.adjcode = ac.code
  left join ezcap_dts.dbo.claim_masters_v cmv on ca.claimno = cmv.claimno
  	inner join #fpd f on ca.claimno = f.claimno and dt.datepaid = f.fpd

  where dt.REMITT_CODE = 'MA91'
  and dt.datepaid between '2020-01-01' and '2020-12-31'
    and (dt.lineflag <> 'x' or dt.lineflag is null)  
  and cmv.opt = 'sco'
  	and dt.status = '9'

  group by 	ca.[CLAIMNO]
		,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd, dt.REMITT_CODE , dt.datepaid


--DENIED CLAIMLINES FOR ADJUSTMENT CODES 
--MAKES #DENIED TEMP TABLE

drop table #denied

SELECT  
	ca.[CLAIMNO]
	,sum(dt.net) as Paid
		,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd, dt.datepaid
	INTO #denied

  FROM [EZCAP_DTS].[dbo].[CLAIM_ADJUSTS] ca
  left join ezcap_dts.dbo.claim_details dt on ca.claimno = dt.claimno and ca.[CLAIMTBLROW] = dt.tblrowid and ca.LINEFLAG = dt.lineflag
  left join ezcap_dts.dbo.adjust_codes ac on ca.adjcode = ac.common_code_id
  left join #adjcodes adj1 on adj1.adjcode = ac.code
  left join ezcap_dts.dbo.claim_masters_v cmv on ca.claimno = cmv.claimno
  	inner join #fpd 
	f on ca.claimno = f.claimno and dt.datepaid = f.fpd
  where ADJGRPCODE = 'oa'
  and dt.datepaid between '2020-01-01' and '2020-12-31'
	and dt.lineflag in ('o','r')
  and od_2019 = 'denial'
  and cmv.opt = 'sco'
  	and dt.status = '9'

  group by 	ca.[CLAIMNO]
		,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd, dt.datepaid

--DENIED CLAIMLINES FOR ADJUSTMENT CODES 
--MAKES #DENIED TEMP TABLE

drop table #paid

SELECT distinct 
	dt.[CLAIMNO]
	,dt.datepaid
	,sum(dt.net) as Paid
	,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd
	 into #paid

  FROM ezcap_dts.dbo.claim_details dt 
  left join [EZCAP_DTS].[dbo].[CLAIM_ADJUSTS] ca on ca.claimno = dt.claimno and ca.[CLAIMTBLROW] = dt.tblrowid and ca.LINEFLAG = dt.lineflag
  left join ezcap_dts.dbo.adjust_codes ac on ca.adjcode = ac.common_code_id
  left join #adjcodes adj1 on adj1.adjcode = ac.code
  left join ezcap_dts.dbo.claim_masters_v cmv on dt.claimno = cmv.claimno
  	inner join #fpd f on ca.claimno = f.claimno and dt.datepaid = f.fpd

  where 
  (ADJGRPCODE = 'oa' or adjgrpcode is null)
  and 
  dt.datepaid between '2020-01-01' and '2020-12-31'
 and dt.lineflag in ('o','r')
  and (od_2019 = 'paid' or (dt.adjcode is null and dt.net <>0) )
  and cmv.opt = 'sco'
  and cmv.net > 0
  	and dt.status = '9'

 group by  ca.[CLAIMNO]
	,dt.[CLAIMNO]
	,dt.datepaid
	,od_2019 
	,dt.proccode, dt.fromdatesvc, dt.todatesvc, dt.modif, dt.hservicecd
  
drop table #paidsum

SELECT  
	dt.[CLAIMNO] 
	,dt.datepaid
	,sum(dt.net) as Paid
	
	 into #paidsum

  FROM ezcap_dts.dbo.claim_details dt 
  left join ezcap_dts.dbo.claim_masters_v cmv on dt.claimno = cmv.claimno
  	inner join #fpd f on dt.claimno = f.claimno and dt.datepaid = f.fpd

  where 
  dt.datepaid between '2020-01-01' and '2020-12-31'
 and dt.lineflag in ('o','r')
  and cmv.opt = 'sco'
  	and dt.status = '9'
	and (ltrim(rtrim(dt.proccode)) <> ('T1019') or dt.proccode is null)
 group by  dt.[CLAIMNO]  
	,dt.[CLAIMNO]
	,dt.datepaid

  --------------------------------------------------------------------

  drop table ##stage2

	  select dt.claimno, dt.proccode
	  , e.claimno as ExcludeClaimno,
	  a.[ClaimType]
      ,[ClaimType2]
      ,[ClaimStatus]
      ,[adjudicated_ind]
      ,[claimline_versions]
      ,[FromDate]
      ,[ToDate]
      ,a.DateRecd
      ,[First_PaidDate]
      ,[FirstPaid_Yrmo]
      ,[Last_PaidDate]
      ,[LastPaid_Yrmo]
      ,[denialflag]
      ,[Clm_Fully_Den_Ind]
      --,[TPA_BILLED]
      --,[TPA_Net]
	  ,sum(dt.net) as Detail_Net
	  	  ,max(dt.billed) as Detail_Billed
,ps.paid as PaidforDate
	  ,dt.hservicecd
      ,[ClaimLineCategory_CCA]
      ,[ClaimLineCategory_CCA2]
      ,[claimcategory_gl1]
      ,[claimcategory_gl2]
      ,[claimcategory_gl3]
      ,[Medicaid_Medicare]
      ,[HCPCS]
      ,[Modifier]
	  ,dt.modif
      ,[Modifier2]
	  	  ,dt.modif2
      ,[Modifier3]
      ,[Modifier4]
      ,[Revcode]
      ,[Units]
	  ,sum(dt.qty) as Detail_qty
      ,[POS]
      ,[EZCAPClm_Specialty]
      ,[Specialty]
      ,[AdmitDate]
      ,[Admit_YRMO]
      ,[AdmitDiag]
      ,[AdmitSource]
      ,[AdmitType]
      ,[DischDate]
      ,[Disch_YRMO]
      ,[DischargeStatus]
      ,[Days]
      ,[DRG]
      ,[DRGVersion]
      ,[BH_Diag_Flag]
      ,[ACSC_Flag]
      ,[ICDVersion]
      ,[ICDDiag1]
      ,[provname]
      ,[ProviderID]
      ,[ProviderID_Full]
      ,[BillingProviderID]
      ,[CactusNetworkFlag]
      ,[ccaID]
      ,[Product]
      ,[Dual] 
	  ,dt.fromdatesvc
	  ,dt.todatesvc
	  ,(dt.datepaid) 
	  ,case when ps.paid = 0 and cap.claimno is null and d.claimno is not null then 'unfavorable'  -- if it's not paid and not capitated and has a denied code, it's unfavorable
	   when ps.paid = 0  then 'unfavorable'  -- if it's not paid and not capitated and has a denied code, it's unfavorable
	  when  pd.claimno is not null then 'favorable'
	  when d.claimno is not null then 'unfavorable'
		 else 'favorable' end as 'Tag'
	  

	  into ##stage2

	  from ezcap_dts.dbo.claim_details dt 
	  inner join ##ads1 a
			on a.claimno = dt.claimno
			and 
			((a.hcpcs is not null and a.revcode is not null and (a.hcpcs = ltrim(rtrim(dt.proccode)) and right(a.revcode,3) = ltrim(rtrim(dt.hservicecd))))
			or (a.hcpcs is  null and  right(a.revcode,3) = ltrim(rtrim(dt.hservicecd)))
			or (a.revcode is  null and  a.hcpcs = ltrim(rtrim(dt.proccode))))
			and dt.fromdatesvc = a.fromdate
			and dt.todatesvc = a.todate
			and (dt.modif = a.modifier or (dt.modif is null and a.modifier is null))

	inner join #fpd f on a.claimno = f.claimno and dt.datepaid = f.fpd
		left join #Exclude e on a.claimno = e.claimno and (dt.proccode = e.proccode or dt.proccode is null) and (dt.modif = e.modif or dt.modif is null) and dt.fromdatesvc = e.fromdatesvc and dt.todatesvc = e.todatesvc  and (dt.hservicecd = e.hservicecd or dt.hservicecd is null) and e.datepaid = dt.datepaid
		left join #denied d on a.claimno = d.claimno and dt.proccode = d.proccode and (dt.modif = d.modif or dt.modif is null) and dt.fromdatesvc = d.fromdatesvc and dt.todatesvc = d.todatesvc  and (dt.hservicecd = d.hservicecd or dt.hservicecd is null) and d.paid = 0 and d.datepaid = dt.datepaid
		left join #paid pd on a.claimno = pd.claimno and dt.proccode = pd.proccode and (dt.modif =pd.modif or dt.modif is null) and dt.fromdatesvc =pd.fromdatesvc and dt.todatesvc =pd.todatesvc  and (dt.hservicecd =pd.hservicecd or dt.hservicecd is null) and pd.datepaid = dt.datepaid
				left join #cap cap on a.claimno = cap.claimno and dt.proccode = cap.proccode and (dt.modif =cap.modif or dt.modif is null) and dt.fromdatesvc =cap.fromdatesvc and dt.todatesvc =cap.todatesvc  and (dt.hservicecd =cap.hservicecd or dt.hservicecd is null) and cap.datepaid = dt.datepaid
	left join #appeal ap on a.claimno = ap.claimno and dt.proccode = ap.proccode and (dt.modif =ap.modif or dt.modif is null) and dt.fromdatesvc =ap.fromdatesvc and dt.todatesvc =ap.todatesvc  and (dt.hservicecd =ap.hservicecd or dt.hservicecd is null) and dt.datepaid = ap.datepaid
	left join #paidsum ps on a.claimno = ps.claimno and dt.datepaid = ps.datepaid

		inner join ezcap_dts.dbo.claim_masters_v cmv on dt.claimno = cmv.claimno and cmv.opt = 'sco'

		where 
			(a.revcode <> '0023' or a.revcode is null) --- non-payable HIPPS code
			and e.claimno is null
			 and dt.lineflag in ('o','r')
			and dt.datepaid between '2020-01-01' and '2020-12-31'
			and ap.claimno is  null  -- exclude claims and dates paid that equal appeal outcomes
				and dt.status = '9'
				and dt.billed <> 0
			
group by dt.claimno, dt.proccode, 
	  a.[ClaimType]
      ,[ClaimType2]
      ,a.[CLAIMNO]
      ,[ClaimStatus]
      ,[adjudicated_ind]
      ,[claimline_versions]
      ,[RetractedFlag]
      ,[FromDate]
      ,[ToDate]
      ,a.DateRecd
   ,ps.paid 
      ,[adj_claimdetails]
	  ,dt.proccode
	 ,dt.hservicecd
      ,[First_PaidDate]
      ,[FirstPaid_Yrmo]
      ,[Last_PaidDate]
      ,[LastPaid_Yrmo]
      ,[denialflag]
      ,[Clm_Fully_Den_Ind]
      ,[CCA_PLAN_PAID]
      ,[ClaimLineCategory_CCA]
      ,[ClaimLineCategory_CCA2]
      ,[claimcategory_gl1]
      ,[claimcategory_gl2]
      ,[claimcategory_gl3]
      ,[Medicaid_Medicare]
      ,[HCPCS]
      ,[Modifier]
	  ,dt.modif
      ,[Modifier2]
	  ,dt.modif2
      ,[Modifier3]
      ,[Modifier4]
      ,[Revcode]
      ,[Units]
	  ,dt.tblrowid
      ,[POS]
      ,[EZCAPClm_Specialty]
      ,[Specialty]
      ,[AdmitDate]
      ,[Admit_YRMO]
      ,[AdmitDiag]
      ,[AdmitSource]
      ,[AdmitType]
      ,[DischDate]
      ,[Disch_YRMO]
      ,[DischargeStatus]
      ,[Days]
      ,[DRG]
      ,[DRGVersion]
      ,[BH_Diag_Flag]
      ,[ACSC_Flag]
      ,[ICDVersion]
      ,[ICDDiag1]
	  ,ps.paid
	  	  ,dt.fromdatesvc
		  ,dt.datepaid
	  ,dt.todatesvc
      ,[provname]
      ,[ProviderID]
      ,[ProviderID_Full]
      	  ,Clm_Fully_Den_Ind
      ,[BillingProviderID]
      ,[CactusNetworkFlag]
      ,[ccaID]
      ,[Product]
      ,[Dual]
	  ,case when ps.paid = 0 and cap.claimno is null and d.claimno is not null  then 'unfavorable'
	    when ps.paid = 0  then 'unfavorable' 
	  when  pd.claimno is not null then 'favorable'
	  when d.claimno is not null then 'unfavorable' else 'favorable' end 
	  , case when e.claimno is not null then 'exclude' else '' end
		,  e.claimno

			order by a.claimno

--- this table is for populating the pivot table to check the results:

			select s.claimno, count(s.claimno) as Claimlines, isnull(UnfavLines,0) as UnfavorableLines
			,sum(s.detail_net) as DtNet 
			,case  
			when unfavlines = count(s.claimno) then 'Adverse'
			 when unfavlines >0 then 'Partially Adverse'  else 'Favorable' end as Tag
			 ,case 
			when unfavlines = count(s.claimno) then '3'
			 when unfavlines >0 then '2'  else '1' end as DecisionID
			 ,DateRecd
			 ,ccaID
			 ,'0' as extension
			 ,'0' as expedited
			 ,'4' as Type -- claim from NCP-- we still need claims from member
			 
			  , REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),provname),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''') as Prov_Name, fpd as FirstPaidDate

		into #temp
			from ##stage2 s
		
			left join (select s.claimno, count(s.claimno) as UnfavLines   --- count up unpaid/adverse lines based on Unfavorable flag in #stage2
				from ##stage2 s  left join #paid pd on s.claimno = pd.claimno and s.proccode = pd.proccode and 
				(s.modif =pd.modif or s.modif is null) and s.fromdatesvc =pd.fromdatesvc and s.todatesvc =pd.todatesvc  and 
				(s.hservicecd =pd.hservicecd or s.hservicecd is null) and pd.paid <> 0
				  where tag = 'unfavorable' and  detail_billed>0
			group by s.claimno) s2 on s.claimno = s2.claimno

			left join #fpd f on s.claimno = f.claimno 
			where 
			s.detail_billed >0
			group by s.claimno, UnfavLines, Clm_Fully_Den_Ind, daterecd, ccaid , REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(convert(varchar(500),provname),
        CHAR(1), ''''),CHAR(2), ''''),CHAR(3), ''''),CHAR(4), ''''),CHAR(5), ''''),CHAR(6), ''''),CHAR(7), ''''),CHAR(8), ''''),CHAR(9), ''''),CHAR(10), ''''),
        CHAR(11), ''''),CHAR(12), ''''),CHAR(13), ''''),CHAR(14), ''''),CHAR(15), ''''),CHAR(16), ''''),CHAR(17), ''''),CHAR(18), ''''),CHAR(19), ''''),CHAR(20), ''''),
        CHAR(21), ''''),CHAR(22), ''''),CHAR(23), ''''),CHAR(24), ''''),CHAR(25), ''''),CHAR(26), ''''),CHAR(27), ''''),CHAR(28), ''''),CHAR(29), ''''),CHAR(30), ''''),
        CHAR(31), ''''), NCHAR(0) COLLATE Latin1_General_100_BIN2, '''')
		, fpd 			   

-- select * from #temp