

SELECT
	r.referralType
	, FORMAT(r.[Date], 'MM/dd/yyyy', 'en-US') AS 'Date'
	, r.Reason
	, r.refFromName AS 'Referral From'
	, r.refToName AS 'Referral To'
	, COALESCE(r.SpecialityDescr, '') AS 'Speciality'
	, FORMAT(r.refStDate, 'MM/dd/yyyy', 'en-US') AS 'Start Date'
	, FORMAT(r.refEnddate, 'MM/dd/yyyy', 'en-US') AS 'End Date'
	, r.visitsAllowed AS 'Allowed'
	, r.visitsUsed AS 'Used visits'
	, '' AS ' '
	, CONCAT(r.PatientName, ' (', r.patientID, ')') AS 'Patient'
	, r.insuranceName AS 'Insurance'
	, r.CCAID
	, r.DOB
	, r.POS
	, r.refFromName AS 'Ref From'
	, COALESCE(r.fac_from, '') AS 'Facility From'
	, '' AS 'Auth Code'
	, FORMAT(r.refStDate, 'MM/dd/yyyy', 'en-US') AS 'Start Date'
	, FORMAT(r.[date], 'MM/dd/yyyy', 'en-US') AS 'Referral Date'
	, CASE WHEN r.[priority] = '0' THEN 'Routine'
		WHEN r.[priority] = '1' THEN 'Urgent'
		WHEN r.[priority] = '2' THEN 'Stat'
		--ELSE r.[priority]
		END AS 'Priority'
	, '' AS ' '
	, r.refToName AS 'Provider'
	, COALESCE(r.SpecialityDescr, '') AS 'Speciality'
	, COALESCE(r.fac_to, '') AS 'Facility To'
	, REPLACE(REPLACE(REPLACE(r.AuthType, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'AuthType'
	, r.requestStatus
	, FORMAT(r.refEnddate, 'MM/dd/yyyy', 'en-US') AS 'End Date'
	, r.assignedTo AS 'Assigned To'
	, r.UnitType AS 'Unit Type'
	, r.[status]
	, REPLACE(REPLACE(REPLACE(r.reason_char, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'Reason'
	, REPLACE(REPLACE(REPLACE(r.notes_char, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'notes'
	, REPLACE(REPLACE(REPLACE(r.ServiceDecision, CHAR(09), ''), CHAR(10), ''), CHAR(13), '') AS 'Service Decision'
	, r.dec_timeframe_value AS 'Decision Timeframe'
	--, r.*
FROM OPENQUERY(ECW, '
	SELECT DISTINCT
		r.*
		, sp.Speciality AS SpecialityDescr
		, p.hl7id AS CCAID
		, RTRIM(CONCAT(u.ulname, '', '', u.ufname, '' '', u.uminitial)) AS PatientName
		, u.ptDOB AS DOB
		, CAST(decis.value AS CHAR(4351)) AS ServiceDecision
		, es.requestStatus
		, CAST(r.notes AS CHAR(4351)) AS notes_char
		, CAST(r.reason AS CHAR(4351)) AS reason_char
		, insurance.insuranceName
		, facfrom.Name AS fac_from
		, facto.Name AS fac_to
		, CAST(IFNULL(dec_timeframe.value, '''') AS CHAR(255)) AS dec_timeframe_value
	FROM referral AS r
	JOIN users AS u
		ON r.patientID = u.uid
		AND r.deleteFlag = 0
	JOIN patients AS p
		ON u.uid = p.pid
/*		AND LEFT(p.hl7id, 2) = ''53''	*/
		AND p.hl7id = ''5365558374''	

	LEFT JOIN insurancedetail AS ins
		ON p.pid = ins.pid
	LEFT JOIN insurance
		ON ins.insid = insurance.insid
	JOIN edi_278_servicelevel as es
		ON r.ReferralId = es.ReferralId 
	LEFT OUTER JOIN edi_speciality AS sp
		ON r.speciality = sp.ID
	LEFT OUTER JOIN structreferraloutgoing AS decis
		ON r.referralID = decis.referralID
		AND decis.detailID = 662001
	LEFT JOIN edi_facilities AS facfrom
		ON r.fromfacility = facfrom.id
	LEFT JOIN edi_facilities AS facto
		ON r.tofacility = facto.id
	LEFT OUTER JOIN structreferraloutgoing AS dec_timeframe
		ON r.referralID = dec_timeframe.referralID
		AND dec_timeframe.detailID = 1213623
/*	WHERE r.deleteFlag = 0 and sp.Speciality = ''Transportation'' */
/*		AND r.patientID = 4726001		*/
') AS r
ORDER BY
	r.[date] DESC
	, r.refStDate DESC
	, r.refEnddate DESC
	, r.visitsAllowed DESC

