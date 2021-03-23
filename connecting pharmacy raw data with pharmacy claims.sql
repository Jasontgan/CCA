; WITH Navitus_raw_data AS (
       SELECT
              COALESCE(snc_pcan.CLAIM_STS, snc.CLAIM_STS) AS 'CLAIM_STS_original'
              , COALESCE(snc.CLAIM_STS, snc_pcan.CLAIM_STS) AS 'CLAIM_STS_final'
              , snc.*
--            c.Source_claim_no = '20160601147751968468140832103226100904770480'
--                                              20160601                                                                         -- date filled
--                                                            1477519684                                                         -- pharmacy number
--                                                                            6814083                                             -- prescription number
--                                                                                         2                                             -- new refill code
--                                                                                          1032261                                  -- member_ID
--                                                                                                       00904770480        -- NDC code
              , CAST(snc.SERVICE_DT AS VARCHAR(8))
                     + CAST(snc.SUBMIT_PHARM_ID AS VARCHAR(10))
                     + CAST(snc.RX_NUMBER AS VARCHAR(25))
                     + CAST(CAST(snc.REFILL_CD AS INT) AS VARCHAR(5))
                     + CAST(CAST(snc.MEM_UNIQUE_ID AS BIGINT) - 5364521034 AS VARCHAR(10))
                     + CAST(snc.NDC_NUM AS VARCHAR(25))
                     AS 'CCAMIS_Source_claim_no'
              , CAST(LEFT(snc.SERVICE_DT, 4) + '-' + SUBSTRING(snc.SERVICE_DT, 5, 2) + '-' + SUBSTRING(snc.SERVICE_DT, 7, 2) AS DATE) AS 'SERVICE_DT_date'
       -- SELECT TOP 100 *--MIN(SERVICE_DT)
       FROM PDRIn.dbo.STG_Navitus_Claims AS snc-- WHERE snc.REJECT_CODE_1 IS NOT NULL
       LEFT JOIN PDRIn.dbo.STG_Navitus_Claims AS snc_pcan
              ON snc._CLM_AUTH_NUM = snc_pcan.PAID_CLM_AUTH_NUM
       WHERE snc.Processor_ID LIKE '%dly%'
              AND COALESCE(snc.CLAIM_STS, snc_pcan.CLAIM_STS) = 'PAID'
              --AND snc.MEM_UNIQUE_ID BETWEEN '5364521034' AND '5369999999'
              AND snc.MEM_UNIQUE_ID = CAST(1032261 + 5364521034 AS VARCHAR(10))
              AND snc.SERVICE_DT = '20160601'
), 
pharmacy_claims AS (
       SELECT
              rx.*
--            c.Source_claim_no = '20160601147751968468140832103226100904770480'
--                                              20160601                                                                         -- date_filled
--                                                            1477519684                                                         -- pharmacy_number
--                                                                            6814083                                             -- prescription_number
--                                                                                         2                                             -- new_refill_code
--                                                                                          1032261                                  -- member_ID
--                                                                                                       00904770480        -- ndc_number
              , CAST(
                             CONVERT(VARCHAR(8), rx.date_filled, 112)
                           + CAST(rx.pharmacy_number AS VARCHAR(25))
                           + CAST(rx.prescription_number AS VARCHAR(25))
                           + CAST(CAST(rx.new_refill_code AS INT) AS VARCHAR(5))
                           + CAST(rx.member_id AS VARCHAR(10))
                           + CAST(rx.ndc_number AS VARCHAR(25))
                     AS VARCHAR(50))
                     AS 'CCAMIS_Source_claim_no'
       -- SELECT TOP 1000 *
       FROM Pharmacy_Claims.dbo.pharmacy_claim_script_level AS rx
       WHERE rx.date_filled = '2016-06-01'
              AND rx.member_id = 1032261
)
SELECT
       claims.*
       , rawdata.*
FROM pharmacy_claims AS claims
LEFT JOIN Navitus_raw_data AS rawdata
       ON claims.CCAMIS_Source_claim_no = rawdata.CCAMIS_Source_claim_no
