
DECLARE @target_firstname AS VARCHAR(255)	--= 'bradley'
DECLARE @target_lastname AS VARCHAR(255)	= 'townsend'


SELECT 'The next table is:' = 'reporting chain'

; WITH level_1 AS (
	SELECT
		1 AS 'level'
		, mchp_1.l1_full_name
		, mchp_1.l1_first_name
		, mchp_1.l1_last_name
		--, mchp_1.l1_work_contact_work_email
		--, mchp_1.l1_work_contact_work_phone
		, mchp_1.l1_position_status
		--, mchp_1.l1_business_unit_code
		--, mchp_1.l1_business_unit_description
		, mchp_1.l1_hire_rehire_date
		, mchp_1.l1_termination_date
		--, mchp_1.l1_job_title_code
		, mchp_1.l1_job_title_description
		, mchp_1.l1_home_department_description
		--, mchp_1.l1_job_function_code
		, mchp_1.l1_job_function_description
		, mchp_1.l2_full_name AS 'reports_to'
		, mchp_1.l2_job_title_description AS 'reports_to_title'
	-- SELECT *
	FROM Medical_Analytics.etl.member_cp_hierarchy AS mchp_1
	WHERE mchp_1.l1_last_name = COALESCE(@target_lastname, mchp_1.l1_last_name)
		AND mchp_1.l1_first_name = COALESCE(@target_firstname, mchp_1.l1_first_name)
), level_2 AS (
	SELECT
		2 AS 'level'
		, mchp_2.l1_full_name
		, mchp_2.l1_first_name
		, mchp_2.l1_last_name
		--, mchp_2.l1_work_contact_work_email
		--, mchp_2.l1_work_contact_work_phone
		, mchp_2.l1_position_status
		--, mchp_2.l1_business_unit_code
		--, mchp_2.l1_business_unit_description
		, mchp_2.l1_hire_rehire_date
		, mchp_2.l1_termination_date
		--, mchp_2.l1_job_title_code
		, mchp_2.l1_job_title_description
		, mchp_2.l1_home_department_description
		--, mchp_2.l1_job_function_code
		, mchp_2.l1_job_function_description
		, mchp_2.l2_full_name AS 'reports_to'
		, mchp_2.l2_job_title_description AS 'reports_to_title'
	-- SELECT *
	FROM Medical_Analytics.etl.member_cp_hierarchy AS mchp_2
	INNER JOIN level_1
		ON mchp_2.l1_full_name = level_1.reports_to
), level_3 AS (
	SELECT
		3 AS 'level'
		, mchp_3.l1_full_name
		, mchp_3.l1_first_name
		, mchp_3.l1_last_name
		--, mchp_3.l1_work_contact_work_email
		--, mchp_3.l1_work_contact_work_phone
		, mchp_3.l1_position_status
		--, mchp_3.l1_business_unit_code
		--, mchp_3.l1_business_unit_description
		, mchp_3.l1_hire_rehire_date
		, mchp_3.l1_termination_date
		--, mchp_3.l1_job_title_code
		, mchp_3.l1_job_title_description
		, mchp_3.l1_home_department_description
		--, mchp_3.l1_job_function_code
		, mchp_3.l1_job_function_description
		, mchp_3.l2_full_name AS 'reports_to'
		, mchp_3.l2_job_title_description AS 'reports_to_title'
	-- SELECT *
	FROM Medical_Analytics.etl.member_cp_hierarchy AS mchp_3
	INNER JOIN level_2
		ON mchp_3.l1_full_name = level_2.reports_to
), level_4 AS (
	SELECT
		4 AS 'level'
		, mchp_4.l1_full_name
		, mchp_4.l1_first_name
		, mchp_4.l1_last_name
		--, mchp_4.l1_work_contact_work_email
		--, mchp_4.l1_work_contact_work_phone
		, mchp_4.l1_position_status
		--, mchp_4.l1_business_unit_code
		--, mchp_4.l1_business_unit_description
		, mchp_4.l1_hire_rehire_date
		, mchp_4.l1_termination_date
		--, mchp_4.l1_job_title_code
		, mchp_4.l1_job_title_description
		, mchp_4.l1_home_department_description
		--, mchp_4.l1_job_function_code
		, mchp_4.l1_job_function_description
		, mchp_4.l2_full_name AS 'reports_to'
		, mchp_4.l2_job_title_description AS 'reports_to_title'
	-- SELECT *
	FROM Medical_Analytics.etl.member_cp_hierarchy AS mchp_4
	INNER JOIN level_3
		ON mchp_4.l1_full_name = level_3.reports_to
)
SELECT * FROM (
		SELECT * FROM level_1
	UNION ALL
		SELECT * FROM level_2
	UNION ALL
		SELECT * FROM level_3
	UNION ALL
		SELECT * FROM level_4
) AS x
ORDER BY [level], l1_position_status, l1_hire_rehire_date



--DECLARE @target_firstname AS VARCHAR(255)	= 'mihir'
--DECLARE @target_lastname AS VARCHAR(255)	= 'shah'

SELECT 'The next table is:' = 'team'

; WITH level_1 AS (
	SELECT
		1 AS 'level'
		, mchp_1.l1_full_name
		, mchp_1.l1_first_name
		, mchp_1.l1_last_name
		--, mchp_1.l1_work_contact_work_email
		--, mchp_1.l1_work_contact_work_phone
		, mchp_1.l1_position_status
		--, mchp_1.l1_business_unit_code
		--, mchp_1.l1_business_unit_description
		, mchp_1.l1_hire_rehire_date
		, mchp_1.l1_termination_date
		--, mchp_1.l1_job_title_code
		, mchp_1.l1_job_title_description
		, mchp_1.l1_home_department_description
		--, mchp_1.l1_job_function_code
		, mchp_1.l1_job_function_description
		, mchp_1.l2_full_name AS 'reports_to'
		, mchp_1.l2_job_title_description AS 'reports_to_title'
	-- SELECT *
	FROM Medical_Analytics.etl.member_cp_hierarchy AS mchp_1
	WHERE mchp_1.l1_last_name = COALESCE(@target_lastname, mchp_1.l1_last_name)
		AND mchp_1.l1_first_name = COALESCE(@target_firstname, mchp_1.l1_first_name)
), level_2 AS (
	SELECT
		2 AS 'level'
		, mchp_2.l1_full_name
		, mchp_2.l1_first_name
		, mchp_2.l1_last_name
		--, mchp_2.l1_work_contact_work_email
		--, mchp_2.l1_work_contact_work_phone
		, mchp_2.l1_position_status
		--, mchp_2.l1_business_unit_code
		--, mchp_2.l1_business_unit_description
		, mchp_2.l1_hire_rehire_date
		, mchp_2.l1_termination_date
		--, mchp_2.l1_job_title_code
		, mchp_2.l1_job_title_description
		, mchp_2.l1_home_department_description
		--, mchp_2.l1_job_function_code
		, mchp_2.l1_job_function_description
		, mchp_2.l2_full_name AS 'reports_to'
		, mchp_2.l2_job_title_description AS 'reports_to_title'
	-- SELECT *
	FROM Medical_Analytics.etl.member_cp_hierarchy AS mchp_2
	INNER JOIN level_1
		ON mchp_2.l2_full_name = level_1.l1_full_name
), level_3 AS (
	SELECT
		3 AS 'level'
		, mchp_3.l1_full_name
		, mchp_3.l1_first_name
		, mchp_3.l1_last_name
		--, mchp_3.l1_work_contact_work_email
		--, mchp_3.l1_work_contact_work_phone
		, mchp_3.l1_position_status
		--, mchp_3.l1_business_unit_code
		--, mchp_3.l1_business_unit_description
		, mchp_3.l1_hire_rehire_date
		, mchp_3.l1_termination_date
		--, mchp_3.l1_job_title_code
		, mchp_3.l1_job_title_description
		, mchp_3.l1_home_department_description
		--, mchp_3.l1_job_function_code
		, mchp_3.l1_job_function_description
		, mchp_3.l2_full_name AS 'reports_to'
		, mchp_3.l2_job_title_description AS 'reports_to_title'
	-- SELECT *
	FROM Medical_Analytics.etl.member_cp_hierarchy AS mchp_3
	INNER JOIN level_2
		ON mchp_3.l2_full_name = level_2.l1_full_name
), level_4 AS (
	SELECT
		4 AS 'level'
		, mchp_4.l1_full_name
		, mchp_4.l1_first_name
		, mchp_4.l1_last_name
		--, mchp_4.l1_work_contact_work_email
		--, mchp_4.l1_work_contact_work_phone
		, mchp_4.l1_position_status
		--, mchp_4.l1_business_unit_code
		--, mchp_4.l1_business_unit_description
		, mchp_4.l1_hire_rehire_date
		, mchp_4.l1_termination_date
		--, mchp_4.l1_job_title_code
		, mchp_4.l1_job_title_description
		, mchp_4.l1_home_department_description
		--, mchp_4.l1_job_function_code
		, mchp_4.l1_job_function_description
		, mchp_4.l2_full_name AS 'reports_to'
		, mchp_4.l2_job_title_description AS 'reports_to_title'
	-- SELECT *
	FROM Medical_Analytics.etl.member_cp_hierarchy AS mchp_4
	INNER JOIN level_3
		ON mchp_4.l2_full_name = level_3.l1_full_name
)
SELECT * FROM (
		SELECT * FROM level_1
	UNION ALL
		SELECT * FROM level_2
	UNION ALL
		SELECT * FROM level_3
	UNION ALL
		SELECT * FROM level_4
) AS x
ORDER BY [level], reports_to, l1_position_status, l1_hire_rehire_date


/*	See also:
SELECT * FROM Medical_Analytics.ETL.zgao_member_cp_hierarchy WHERE [Last Name] LIKE '%keith%'
SELECT * FROM Medical_Analytics.etl.new_member_cp_hierarchy WHERE l1_full_name LIKE '%keith%'
-- also emails:
--	From: Seema Badaya 
--	Sent: Tuesday, November 19, 2019 1:54 PM
*/
