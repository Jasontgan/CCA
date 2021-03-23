SELECT
    *
into ##RRT_encounter
FROM OPENQUERY(ECW, '
    SELECT DISTINCT
        p.hl7id AS CCAID
        , e.encLock
        , CAST(e.Date AS DATE) AS enc_date
        , e.StartTime
        , e.VisitType
        , e.Status
        , RTRIM(CONCAT(du.ulname, '', '', du.ufname, '' '', du.uminitial)) AS provider
        , RTRIM(COALESCE(CONCAT(ru.ulname, '', '', ru.ufname, '' '', ru.uminitial), '''')) AS resource
        , e.Reason
		, e.facilityid
        , u.uid
        , vc.description AS VisitTypeDescr
        , d.printname AS provider_printname
        , r.printname AS resource_printname

        , du.umobileno
        , du.upagerno
        , du.ufname
        , du.uminitial
        , du.ulname
        , du.uemail
        , du.upaddress
        , du.upcity
        , du.upstate
        , du.upPhone
        , du.UserType
        , du.zipcode
        , du.initials AS provider_credentials
        , ru.initials AS resource_credentials
        , du.primaryservicelocation

        , RTRIM(CONCAT(u.ulname, '', '', u.ufname, '' '', u.uminitial)) AS member_name
        , u.dob
        , e.encounterID

    FROM users AS u
    JOIN patients AS p
        ON u.uid = p.pid
    JOIN enc AS e
        ON u.uid = e.patientid
        AND e.deleteflag = 0
/*        AND e.visitType NOT IN (''EXTCOMM'', ''HRS'', ''MATRIX'', ''MDS Proxy'', ''NP'', ''TRANS'', ''WEB'')    */
        AND e.encLock = 1
    JOIN doctors AS d
        ON e.doctorID = d.doctorID
    LEFT JOIN visitcodes AS vc
        ON e.VisitType = vc.name
    LEFT JOIN users AS du
        ON d.doctorID = du.uid
    LEFT JOIN doctors AS r
        ON e.resourceID = r.doctorID
    LEFT JOIN users AS ru
        ON r.doctorID = ru.uid

/*    WHERE e.Date >= ''2013-10-01''        AND p.hl7id = ''5364521037''        */    
    WHERE e.Date >= ''2018-01-01'' and e.Date < ''2019-01-01''
         AND p.hl7id between ''5364521037'' AND ''5369999999''      
         and e.reason like ''%rrt%''  
') AS ecw


select * from ##RRT_encounter order by 3
--9417

select count(distinct ccaid)
from ##RRT_encounter 
--4045
