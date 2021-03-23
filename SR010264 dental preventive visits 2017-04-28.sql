
SELECT
	meh.CCAID
	, meh.member_ID
	, meh.NAME_ID
	, meh.[Year]
	, SUM(meh.EP_enroll) AS 'enr_mm'
	, mm_latest.Product
	, mm_latest.COUNTY
	, mm_latest.CMO
	, mm_latest.CMO_group
	, mm_latest.lang_spoken
FROM Medical_Analytics.dbo.member_enrollment_history AS meh
LEFT JOIN (
	SELECT
		*
	FROM Medical_Analytics.dbo.member_enrollment_history
	WHERE latest_enr_mo = 1
) AS mm_latest
	ON meh.CCAID = mm_latest.CCAID
WHERE meh.[Year] IN (2015, 2016)
	AND meh.EP_enroll = 1
GROUP BY
	meh.CCAID
	, meh.member_ID
	, meh.NAME_ID
	, meh.[Year]
	, mm_latest.Product
	, mm_latest.COUNTY
	, mm_latest.CMO
	, mm_latest.CMO_group
	, mm_latest.lang_spoken
HAVING SUM(meh.EP_enroll) >= 11

