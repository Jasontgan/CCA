--CTE for Care Partner info from CMP, this section is copy and pasted from BI
; WITH PrimCareStaff as
(
 SELECT
	pd.[CLIENT_PATIENT_ID]	AS CCAID,
	pd.[PATIENT_ID],
	pp.[PHYSICIAN_ID]		AS PhysID,
	cs.PRIMARY_EMAIL		AS staff_email,
	r.Role_name				AS PhysRole,
	[TITLE],
	cs.[FIRST_NAME],
	cs.[LAST_NAME]
 FROM [Altruista].[dbo].[PATIENT_DETAILS] pd
   INNER JOIN [Altruista].[dbo].[PATIENT_PHYSICIAN] pp ON pd.patient_id = pp.patient_ID
                                                         AND pp.care_team_id = 1
														 AND pp.is_active = 1
														 AND pp.deleted_on IS NULL
   INNER JOIN [Altruista].[dbo].[CARE_STAFF_DETAILS] cs ON pp.physician_id = cs.member_id
   LEFT JOIN altruista.dbo.[role] r ON cs.role_id = r.role_id AND r.is_active = 1 AND r.deleted_on IS NULL
 WHERE left(pd.[CLIENT_PATIENT_ID], 3) = '536'
       AND pd.deleted_on IS NULL
)
----------CARE MANAGER/PARTNER FROM MEMBER_CARESTAFF TABLE
, PrimCM as
  (
	SELECT
		pd.[CLIENT_PATIENT_ID]				AS CCAID,
		pd.[PATIENT_ID],
		mc.[MEMBER_ID],
		cs.last_name + ', ' + cs.first_name	AS PrimCareMgr,
		cs.PRIMARY_EMAIL					AS staff_Email
		-- , cs.Last_name, cs.First_Name, cs.Middle_name
		,
		r.Role_name                         AS PrimCareMgrRole
   FROM [Altruista].[dbo].[PATIENT_DETAILS] pd
     INNER JOIN [Altruista].[dbo].[MEMBER_CARESTAFF] mc ON pd.patient_id = mc.patient_id
     INNER JOIN [Altruista].[dbo].[CARE_STAFF_DETAILS] cs ON mc.member_id = cs.member_id
     LEFT JOIN [Altruista].[dbo].[Role] r ON cs.role_id = r.role_id AND r.is_active = 1 AND r.deleted_on IS NULL
   WHERE left(pd.[CLIENT_PATIENT_ID], 3) = '536' AND mc.is_active = 1 AND mc.is_primary = 1
  )
, final_relationships AS (
    SELECT
      pc.ccaid,
      pc.Patient_ID,
      pc.member_ID                              AS PrimCareMgrID,
      pc.PrimCareMgr,
      pc.PrimCareMgrRole,
      pc.staff_email                            AS PrimCareMgrEmail,
      pcs.PhysID,
      pcs.PhysRole,
      pcs.First_name,
      pcs.Last_Name,
      pcs.staff_email                           AS PhysEmail,
      COALESCE(pc.staff_email, pcs.staff_email) AS coalesce_email,
      CASE WHEN pc.member_ID = pcs.PhysID
        THEN 'Y'
      ELSE 'N' END                              AS CMtoPhysMatch,
      dense_rank()
		OVER ( PARTITION BY pc.ccaid
        ORDER BY CASE WHEN pc.member_ID = PCS.PhysID
          THEN 'Y'
                 ELSE 'N' END DESC )            AS PCMrank
    FROM PrimCM pc
	LEFT JOIN PrimCareStaff pcs ON pc.ccaid = pcs.ccaid AND pc.member_ID = pcs.PhysID
)
SELECT 
	fr.ccaid,
    fr.PrimCareMgr,
    fr.PrimCareMgrRole,
    fr.First_name,
    fr.Last_Name,
    fr.coalesce_email
FROM final_relationships fr
--INNER JOIN ##CCAIDs id ON fr.ccaid= id.CCAID