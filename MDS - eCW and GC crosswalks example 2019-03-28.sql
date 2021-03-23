

-- eCW: one member's assessments
SELECT
	*
FROM OPENQUERY(ECW, '
	SELECT DISTINCT
		p.hl7id AS CCAID
		, e.encLock
		, CAST(e.Date AS DATE) AS enc_date
		, e.StartTime
		, e.VisitType
		, e.Status
		, e.Reason
		, u.uid
		, e.encounterID
	FROM users AS u
	INNER JOIN patients AS p
		ON u.uid = p.pid
	INNER JOIN enc AS e
		ON u.uid = e.patientid
		AND e.deleteflag = 0
		AND e.visitType IN (''MDS Face'', ''MDS Teleph'', ''MDS Visit'', ''HANNUAL'', ''OANNUAL'', ''ANNUAL'')
	WHERE p.hl7id = ''5364521045''
		AND e.Date >= ''2013-10-01''
') AS ecw
ORDER BY
	enc_date DESC


-- eCW: questions and answers, one MDS encounter
IF OBJECT_ID('tempdb..#eCW_example') IS NOT NULL DROP TABLE #eCW_example

SELECT
	*
INTO #eCW_example
FROM OPENQUERY(ECW, '
	SELECT
		p.hl7id AS CCAID
		, e.Date AS enc_date
		, e.encounterId
		, e.visitType
		, sdd.catId
		, sdd.itemId
		, sdd.Id
		, TRIM(REPLACE(REPLACE(REPLACE(CAST(sdd.name AS CHAR), CONVERT(CHAR(09) USING UTF8), ''''), CONVERT(CHAR(10) USING UTF8), ''''), CONVERT(CHAR(13) USING UTF8), '''')) AS question
		, TRIM(REPLACE(REPLACE(REPLACE(CAST(se.value AS CHAR), CONVERT(CHAR(09) USING UTF8), ''''), CONVERT(CHAR(10) USING UTF8), ''''), CONVERT(CHAR(13) USING UTF8), '''')) AS answer
		, e.date
		, se.valueId
	FROM structdatadetail AS sdd
	INNER JOIN structexam AS se
		ON sdd.catId = se.catId
		AND sdd.itemId = se.itemId
		AND sdd.Id = se.detailId
	INNER JOIN enc AS e
		ON se.encounterId = e.encounterId
		AND e.deleteflag = 0
		AND e.visitType IN (''MDS Face'', ''MDS Teleph'', ''MDS Visit'', ''HANNUAL'', ''OANNUAL'', ''ANNUAL'')
	INNER JOIN patients AS p
		ON e.patientid = p.pid
	WHERE sdd.tblName = ''structExam''
		AND e.encounterId = 194429003
/*		AND p.hl7id = ''5364521045''		*/
')
ORDER BY
	CCAID
	, enc_date
	, encounterId
	, catId
	, itemId
	, Id
PRINT '#eCW_example'

SELECT * FROM #eCW_example ORDER BY CCAID, enc_date, encounterId, catId, itemId, Id


-- GC: dates of MDS
IF OBJECT_ID('tempdb..#MDS_dates') IS NOT NULL DROP TABLE #MDS_dates

SELECT
	MDS_date_rank.CCAID
	, MDS_date_rank.ScriptStatus
	, MDS_date_rank.MDSactivityOutcome
	, MDS_date_rank.MDSactivityOutcomeNotes
	, MDS_date_rank.PERFORMED_DATE
	, MDS_date_rank.PerformedByName

	, MDS_date_rank.ARD	-- Assessment Reference Date	-- "official" MDS date

	, MDS_date_rank.MDSrank	-- identifies best date from several options
	, MDS_date_rank.MDSreason
	, SCRIPT_RUN_LOG_ID
	, RANK() OVER (PARTITION BY MDS_date_rank.CCAID ORDER BY MDS_date_rank.ARD DESC, MDS_date_rank.PERFORMED_DATE DESC) AS 'MDSseq'	-- idenfies most-recent MDS (= 1)
INTO #MDS_dates
FROM (
	SELECT
		CCAID
		, ScriptStatus
		, MDSactivityOutcome
		, MDSactivityOutcomeNotes
		, PERFORMED_DATE
		, PerformedByName
		, MAX(CASE WHEN QUESTION_OPTION = 'Assessment Reference Date' THEN ARD END) AS 'ARD'
		, RANK() OVER (PARTITION BY CCAID, MAX(CASE WHEN QUESTION_OPTION = 'Assessment Reference Date' THEN ARD END) ORDER BY PERFORMED_DATE DESC, ISNULL(ScriptEndDate, '9999-12-31') DESC) AS 'MDSrank'
		, MAX(CASE WHEN QUESTION_OPTION = 'Reasons For Assessment' THEN SUB_OPTION_VALUE END) AS 'MDSreason'
		, SCRIPT_RUN_LOG_ID
	FROM (
		SELECT DISTINCT
			pd.CLIENT_PATIENT_ID AS 'CCAID'
			, pd.PATIENT_ID
			, RTRIM(pd.LAST_NAME) + ', ' + RTRIM(pd.FIRST_NAME) AS 'MemberName'
			, spsrl.[START_DATE] AS 'ScriptStartDate'
			, spsrl.END_DATE AS 'ScriptEndDate'
				, spsrl.Status_ID
				, ao.Activity_Outcome AS 'MDSactivityOutcome'
				, pf.patient_followup_id
			, pf.PERFORMED_DATE
			, RTRIM(csd.LAST_NAME) + ', ' + RTRIM(csd.FIRST_NAME) AS 'PerformedByName'
			, sqr.SUB_OPTION_VALUE AS 'ARD_entry'
			, CASE WHEN QUESTION_OPTION = 'Assessment Reference Date' THEN RIGHT(sqr.SUB_OPTION_VALUE, 4) END AS 'ARD_entry_year'
			, CASE WHEN QUESTION_OPTION = 'Assessment Reference Date'
				THEN CASE WHEN ABS(DATEDIFF(DD, CAST(pf.PERFORMED_DATE AS DATE), CAST(REPLACE(sqr.SUB_OPTION_VALUE, '010/', '01/' /*manual fix for '010/7/2019'*/ ) AS DATE))) > 60	-- disregard date entry if more than 60 days away from performed date
					THEN CAST(pf.PERFORMED_DATE AS DATE) ELSE CAST(REPLACE(sqr.SUB_OPTION_VALUE, '010/', '01/' /*manual fix for '010/7/2019'*/ ) AS DATE)
				END END AS 'ARD'	-- Assessment Reference Date
			, ssrs.VALUE AS 'ScriptStatus'
			, REPLACE(REPLACE(REPLACE(pf.OUTCOME_NOTES, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'MDSactivityOutcomeNotes'
			, spsrl.SCRIPT_RUN_LOG_ID
			, saqo.QUESTION_OPTION
			, sqr.SUB_OPTION_VALUE

		FROM Altruista.dbo.PATIENT_DETAILS AS pd
		INNER JOIN Altruista.dbo.PATIENT_FOLLOWUP AS pf
			ON pd.PATIENT_ID = pf.PATIENT_ID
		INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS csd
			ON pf.PERFORMED_BY = csd.MEMBER_ID
		LEFT JOIN Altruista.dbo.ACTIVITY_OUTCOME AS ao
			ON pf.ACTIVITY_OUTCOME_ID = ao.ACTIVITY_OUTCOME_ID
		INNER JOIN Altruista.dbo.SCPT_PATIENT_SCRIPT_RUN_LOG AS spsrl
			ON pf.PATIENT_FOLLOWUP_ID = spsrl.PATIENT_FOLLOWUP_ID
		INNER JOIN Altruista.dbo.SCPT_SCRIPT_RUN_STATUS AS ssrs
			ON spsrl.STATUS_ID = ssrs.STATUS_ID
		INNER JOIN Altruista.dbo.SCPT_PATIENT_SCRIPT_RUN_LOG_DETAIL AS spsrld
			ON spsrl.SCRIPT_RUN_LOG_ID = spsrld.SCRIPT_RUN_LOG_ID
		INNER JOIN Altruista.dbo.SCPT_QUESTION_RESPONSE AS sqr
			ON spsrld.SCRIPT_RUN_LOG_DETAIL_ID = sqr.SCRIPT_RUN_LOG_DETAIL_ID
		INNER JOIN Altruista.dbo.SCPT_ADMIN_QUESTION_OPTION AS saqo
			ON sqr.QUESTION_OPTION_ID = saqo.QUESTION_OPTION_ID
		WHERE LEFT(pd.CLIENT_PATIENT_ID, 3) = '536'
			AND spsrl.DELETED_ON IS NULL
			AND spsrld.DELETED_ON IS NULL
			AND spsrld.IS_RESPONDED = 1
			AND spsrl.IS_SCPT_DELETED = 0
			AND sqr.DELETED_ON IS NULL
			AND sqr.IS_ACTIVE = 1
			AND pf.SCRIPT_ID = 117 -- MDS scripts only
			AND pf.DELETED_ON IS NULL
			AND pf.IS_SCPT_DELETED = 0
			AND spsrl.[START_DATE] > '2018-11-09'
			AND ssrs.VALUE <> 'Cancelled'
			AND spsrld.QUESTION_ID = 3388
			AND ISNULL(ao.ACTIVITY_OUTCOME_TYPE_ID, 1) = 1
	) AS MDSdate_details
	GROUP BY
		CCAID
		, ScriptStatus
		, MDSactivityOutcome
		, MDSactivityOutcomeNotes
		, PERFORMED_DATE
		, PerformedByName
		, ScriptEndDate
		, SCRIPT_RUN_LOG_ID
	HAVING MAX(CASE WHEN QUESTION_OPTION = 'Assessment Reference Date' THEN ARD END) IS NOT NULL
) AS MDS_date_rank
INNER JOIN CCAMIS_Common.dbo.Dim_date AS d
	ON MDS_date_rank.ARD = d.[Date]
INNER JOIN Medical_Analytics.dbo.member_enrollment_history AS meh
	ON MDS_date_rank.CCAID = meh.CCAID
	AND d.member_month = meh.member_month
WHERE MDS_date_rank.MDSrank = 1
PRINT '#MDS_dates'
-- SELECT * FROM #MDS_dates ORDER BY CCAID, MDSseq, ARD DESC
-- SELECT * FROM #MDS_dates WHERE SCRIPT_RUN_LOG_ID = 29231 ORDER BY CCAID, MDSseq, ARD DESC

-- GC: one member's assessments
SELECT * FROM #MDS_dates WHERE CCAID = 5364521045 ORDER BY CCAID, MDSseq, ARD DESC


-- GC: questions and answers, one MDS encounter
IF OBJECT_ID('tempdb..#GC_example') IS NOT NULL DROP TABLE #GC_example

SELECT DISTINCT
	pd.CLIENT_PATIENT_ID AS 'CCAID'
	, spsrld.SCRIPT_RUN_LOG_ID
	, #MDS_dates.ARD AS 'assessment_date'		-- MDS date
	, #MDS_dates.MDSseq		-- 1 = most recent
	, spsrld.QUESTION_ID
	, saq.QUESTION_NO
	, saq.OPTION_TYPE_ID
	, saq.QUESTION
	, saqo.QUESTION_OPTION_ID
	, saqo.OPTION_NO
	, saqo.QUESTION_OPTION
	, sqr.SUB_OPTION_ID
	, COALESCE(psqs.SUB_OPTION_NO, saqso.SUB_OPTION_NO) AS 'SUB_OPTION_NO'
	, COALESCE(psqs.QUESTION_SUBOPTION_TEXT, saqso.QUESTION_SUBOPTION_TEXT) AS 'QUESTION_SUBOPTION_TEXT'
	, CASE WHEN saq.OPTION_TYPE_ID = 4 THEN ''
		--WHEN saq.OPTION_TYPE_ID IN (6, 8, 9) THEN sqr.OPTION_VALUE
		ELSE COALESCE(sqr.SUB_OPTION_VALUE, sqr.OPTION_VALUE)
		END AS 'answer'
	--, csd.FIRST_NAME AS 'provider_fname'
	--, csd.LAST_NAME AS 'provider_lname'
	--, r.ROLE_NAME AS 'provider_role'
	, sqr.SUB_OPTION_VALUE, sqr.OPTION_VALUE
INTO #GC_example
-- SELECT TOP 1000 *
FROM Altruista.dbo.SCPT_PATIENT_SCRIPT_RUN_LOG_DETAIL AS spsrld
INNER JOIN Altruista.dbo.SCPT_ADMIN_SCRIPT AS sas
	ON spsrld.SCRIPT_ID = sas.SCRIPT_ID
INNER JOIN Altruista.dbo.SCPT_ADMIN_QUESTION AS saq
	ON spsrld.SCRIPT_ID = saq.SCRIPT_ID
	AND spsrld.QUESTION_ID = saq.QUESTION_ID
INNER JOIN Altruista.dbo.SCPT_ADMIN_OPTION_TYPE AS saot
	ON saq.OPTION_TYPE_ID = saot.SCPT_ADMIN_OPTION_TYPE_ID
INNER JOIN Altruista.dbo.SCPT_ADMIN_QUESTION_OPTION AS saqo
	ON saq.QUESTION_ID = saqo.QUESTION_ID
INNER JOIN Altruista.dbo.SCPT_QUESTION_RESPONSE AS sqr
	ON spsrld.SCRIPT_RUN_LOG_DETAIL_ID = sqr.SCRIPT_RUN_LOG_DETAIL_ID
	AND saqo.QUESTION_OPTION_ID = sqr.QUESTION_OPTION_ID
INNER JOIN Altruista.dbo.SCPT_PATIENT_SCRIPT_RUN_LOG AS spsrl
	ON spsrld.SCRIPT_RUN_LOG_ID = spsrl.SCRIPT_RUN_LOG_ID
	AND sqr.OPTION_VALUE IS NOT NULL
INNER JOIN Altruista.dbo.PATIENT_DETAILS AS pd
	ON spsrl.PATIENT_ID = pd.PATIENT_ID
	AND sqr.OPTION_VALUE IS NOT NULL
INNER JOIN Altruista.dbo.SCPT_SCRIPT_RUN_STATUS AS ssrs
	ON spsrl.STATUS_ID = ssrs.STATUS_ID
LEFT JOIN Altruista.dbo.SCPT_ADMIN_QUESTION_SUBOPTION AS saqso
	ON sqr.SUB_OPTION_ID = saqso.QUESTION_SUBOPTION_ID
LEFT JOIN Altruista.dbo.SCPT_ADMIN_QUESTION_SUBOPTION AS psqs
	ON saqso.PARENT_ID = psqs.QUESTION_SUBOPTION_ID
INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS csd
	ON spsrld.STAFF_ID = csd.MEMBER_ID
INNER JOIN Altruista.dbo.[ROLE] AS r
	ON csd.ROLE_ID = r.ROLE_ID
INNER JOIN #MDS_dates
	ON spsrld.SCRIPT_RUN_LOG_ID = #MDS_dates.SCRIPT_RUN_LOG_ID
WHERE spsrld.SCRIPT_ID = 117	-- MDS
	--AND pd.CLIENT_PATIENT_ID = '5364521045'
	AND spsrld.SCRIPT_RUN_LOG_ID = 47688
ORDER BY
	pd.CLIENT_PATIENT_ID
	, spsrld.SCRIPT_RUN_LOG_ID
	, saq.QUESTION_NO
	, saq.QUESTION
	, saqo.OPTION_NO
PRINT '#GC_example'
-- SELECT * FROM #GC_example ORDER BY CCAID, MDSseq, QUESTION_NO, OPTION_NO, SUB_OPTION_NO
-- SELECT * FROM #GC_example ORDER BY CCAID, MDSseq, SCRIPT_RUN_LOG_ID, QUESTION_NO, OPTION_NO, SUB_OPTION_NO, SUB_OPTION_ID
-- SELECT DISTINCT QUESTION_NO, QUESTION, OPTION_NO, QUESTION_OPTION, SUB_OPTION_NO, QUESTION_SUBOPTION_TEXT, answer FROM #GC_example ORDER BY QUESTION_NO, OPTION_NO, SUB_OPTION_NO

SELECT * FROM #GC_example ORDER BY CCAID, MDSseq, SCRIPT_RUN_LOG_ID, QUESTION_NO, OPTION_NO, SUB_OPTION_NO, SUB_OPTION_ID




-- eCW data connecting to GC IDs
-- note that the user switched the answers to questions 1214540 and 1214541
SELECT DISTINCT
	ecw.*
	, xwalk_eg.QUESTION_ID
	, xwalk_eg.QUESTION_OPTION_ID
	, xwalk_eg.SUB_OPTION_NO
FROM #eCW_example AS ecw
LEFT JOIN Medical_Analytics.dbo.MDS_crosswalk_eCW_to_GC AS xwalk_eg
	ON ecw.itemId = xwalk_eg.itemId
	AND ecw.Id = xwalk_eg.eCW_question_ID
ORDER BY CCAID, enc_date, encounterId, catId, itemId, Id

-- eCW data with GC answers
-- note that some questions (e.g., Id = 1214417) end up with multiple rows because eCW answers are concatenated while GC answers are in separate records
SELECT DISTINCT
	ecw.*
	, gc.assessment_date AS 'GC_date'
	, gc.SCRIPT_RUN_LOG_ID
	, xwalk_eg.QUESTION_ID
	, xwalk_eg.QUESTION_OPTION_ID
	, xwalk_eg.SUB_OPTION_NO
	, COALESCE(gc.QUESTION_OPTION, '') + ' ' + COALESCE(gc.QUESTION_SUBOPTION_TEXT, '') AS 'GC_question'
	, gc.answer AS 'GC_answer'
FROM #eCW_example AS ecw
LEFT JOIN Medical_Analytics.dbo.MDS_crosswalk_eCW_to_GC AS xwalk_eg
	ON ecw.itemId = xwalk_eg.itemId
	AND ecw.Id = xwalk_eg.eCW_question_ID
LEFT JOIN #GC_example AS gc
	ON xwalk_eg.QUESTION_ID = gc.QUESTION_ID
	AND xwalk_eg.QUESTION_OPTION_ID = gc.QUESTION_OPTION_ID
	AND COALESCE(xwalk_eg.SUB_OPTION_NO, '') = COALESCE(gc.SUB_OPTION_NO, '')
ORDER BY CCAID, enc_date, encounterId, catId, itemId, Id




-- GC data connecting to eCW IDs
SELECT
	gc.*
	, xwalk_ge.itemId
	, xwalk_ge.eCW_question_ID
FROM #GC_example AS gc
LEFT JOIN Medical_Analytics.dbo.MDS_crosswalk_GC_to_eCW AS xwalk_ge
	ON gc.QUESTION_ID = xwalk_ge.QUESTION_ID
	AND gc.QUESTION_OPTION_ID = xwalk_ge.QUESTION_OPTION_ID
	AND COALESCE(gc.SUB_OPTION_NO, '') = COALESCE(xwalk_ge.SUB_OPTION_NO, '')
ORDER BY gc.CCAID, gc.SCRIPT_RUN_LOG_ID, gc.assessment_date, gc.MDSseq, gc.QUESTION_ID, gc.OPTION_NO, gc.SUB_OPTION_ID

-- GC data with eCW answers
SELECT
	gc.*
	, ecw.enc_date AS 'eCW_date'
	, ecw.encounterID
	, xwalk_ge.itemId
	, xwalk_ge.eCW_question_ID
	, ecw.question AS 'eCW_question'
	, ecw.answer AS 'eCW_answer'
FROM #GC_example AS gc
LEFT JOIN Medical_Analytics.dbo.MDS_crosswalk_GC_to_eCW AS xwalk_ge
	ON gc.QUESTION_ID = xwalk_ge.QUESTION_ID
	AND gc.QUESTION_OPTION_ID = xwalk_ge.QUESTION_OPTION_ID
	AND COALESCE(gc.SUB_OPTION_NO, '') = COALESCE(xwalk_ge.SUB_OPTION_NO, '')
LEFT JOIN #eCW_example AS ecw
	ON xwalk_ge.itemId = ecw.itemId
	AND xwalk_ge.eCW_question_ID = ecw.Id
ORDER BY gc.CCAID, gc.SCRIPT_RUN_LOG_ID, gc.assessment_date, gc.MDSseq, gc.QUESTION_ID, gc.OPTION_NO, xwalk_ge.eCW_question_ID

