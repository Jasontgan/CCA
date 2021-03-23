

IF OBJECT_ID('tempdb..#GCmds') IS NOT NULL DROP TABLE #GCmds

; WITH GCmds AS (
	SELECT
		pd.[CLIENT_PATIENT_ID] AS 'CCAID'
		, pd.[PATIENT_ID]
		, pd.Last_Name + ', ' + pd.first_name AS 'MemberName'
		, prl.[Start_date] AS 'ScriptStartDate'
		, prl.End_date AS 'ScriptEndDate'
		, prl.Status_ID
		, srs.Value AS 'ScriptStatus'
		, ao.Activity_Outcome AS 'MDSactivityOutcome'
		, pf.Outcome_notes AS 'MDSactivityOutcomeNotes'
		, pf.patient_followup_id
		, pf.[PERFORMED_DATE]
		, csa.Last_Name + ', ' + csa.first_name AS 'PerformedByName'
		, MAX(CASE WHEN sqo.Question_Option = 'Assessment Reference Date' THEN sqr.Sub_Option_Value END) AS 'ARD'
		, RANK() OVER (PARTITION BY pd.[CLIENT_PATIENT_ID]
			ORDER BY MAX(CASE WHEN sqo.Question_Option = 'Assessment Reference Date' THEN sqr.Sub_Option_Value END) DESC
			, pf.Performed_date DESC, ISNULL(prl.End_date,'9999-12-31') DESC) AS 'MDSrank'
		, MAX(CASE WHEN sqo.Question_Option = 'Reasons For Assessment' THEN sqr.Sub_Option_Value END) AS 'MDSreason'
		, COUNT(DISTINCT sqo.Question_option + sqr.Sub_option_value) AS 'MDSanswerCount'
	FROM [Altruista].[dbo].[PATIENT_DETAILS] AS pd
	INNER JOIN [Altruista].[dbo].[PATIENT_FOLLOWUP] AS pf
		ON pd.Patient_ID = pf.Patient_ID
	INNER JOIN Altruista.dbo.CARE_STAFF_DETAILS AS csa
		ON pf.performed_by = csa.MEMBER_ID
	LEFT JOIN Altruista.dbo.Activity_Outcome AS ao
		ON pf.Activity_Outcome_ID = ao.Activity_Outcome_ID
	INNER JOIN altruista.dbo.scpt_patient_script_run_log AS prl
		ON pf.patient_followup_id = prl.patient_followup_id
	INNER JOIN [Altruista].[dbo].[SCPT_SCRIPT_RUN_STATUS] AS srs
		ON prl.status_id = srs.status_id
	INNER JOIN altruista.dbo.scpt_patient_script_run_log_detail AS prld
		ON prl.script_run_log_id = prld.script_run_log_id
	INNER JOIN [Altruista].[dbo].[SCPT_ADMIN_QUESTION] AS sq
		ON prld.question_ID = sq.question_ID
	INNER JOIN altruista.dbo.scpt_question_response AS sqr
		ON prld.script_run_log_detail_id = sqr.script_run_log_detail_ID
	INNER JOIN Altruista.dbo.Scpt_admin_question_option AS sqo
		ON sqr.question_option_id = sqo.question_option_id
	LEFT JOIN Altruista.dbo.Scpt_admin_question_suboption AS sqs
		ON sqr.sub_option_id = sqs.question_suboption_id
	LEFT JOIN Altruista.dbo.Scpt_admin_question_suboption AS psqs
		ON sqs.parent_ID = psqs.question_suboption_id
	WHERE LEFT(pd.[CLIENT_PATIENT_ID], 3) = '536'
		AND prl.deleted_on IS NULL
		AND prld.deleted_on IS NULL
		AND prld.is_responded = 1
		AND prl.is_scpt_deleted = 0
		AND sqr.deleted_on IS NULL
		AND SQR.IS_ACTIVE = 1
		AND pf.script_Id = 117 -- MDS scripts only
		AND pf.deleted_on IS NULL
		AND pf.is_scpt_deleted = 0
		AND prl.[Start_date] > '2018-11-09'
		AND srs.Value <> 'Cancelled'
	GROUP BY
		pd.[CLIENT_PATIENT_ID]-- AS 'CCAID'
		, pd.[PATIENT_ID]
		, pd.Last_Name + ', ' + pd.first_name-- AS 'MemberName'
		, prl.[Start_date]-- AS 'ScriptStartDate'
		, prl.End_date-- AS 'ScriptEndDate'
		, prl.Status_ID
		, srs.Value-- AS 'ScriptStatus'
		, ao.Activity_Outcome-- AS 'MDSactivityOutcome'
		, pf.Outcome_notes-- AS 'MDSactivityOutcomeNotes'
		, pf.patient_followup_id
		, pf.[PERFORMED_DATE]
		, csa.Last_Name + ', ' + csa.first_name-- AS 'PerformedByName'
)
SELECT
	CCAID
	--, CAST(ARD AS DATE) AS 'ARD'
	, ARD
	, ScriptStatus
	, MDSreason
	, MDSactivityOutcome
	, REPLACE(REPLACE(REPLACE(MDSactivityOutcomeNotes, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'MDSactivityOutcomeNotes'
	, Performed_date AS PerformedDate
	, PerformedByName
	, MDSrank
INTO #GCmds
FROM GCmds
--WHERE MDSrank = 1

CREATE UNIQUE INDEX CCAID ON #GCmds (CCAID)

-- SELECT * FROM #GCmds ORDER BY CCAID, ARD
SELECT * FROM #GCmds WHERE MDSrank = 1 ORDER BY CCAID, ARD


