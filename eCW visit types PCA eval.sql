--- this is only a supplemental data pull from eCW for our internal clinicians
--- who may have made the followup visit
--- Check Medication Review for example of using LOCKED BY CREDENTIALS 
--- LICSW, psychiatrist, psychologist....
--- Susan K is providing the list of clinicals/credentials to include
--- 
--notes> I added Diagnosis to see if we can use this to find Advanced Directives which are identifiable by Diagnosis
-- I added CPT/description to see if we can use this for supplemental post-hospital visits, etc.

--Encounter Notes
select *
--into #ec_enct2
from openquery(ecw,'Select e.encounterid, concat(dc.ulname,'', '',dc.ufname) as Provider
, dc.initials as Credentials, concat(res.ulname,'', '',res.ufname) as Resource,
           e.POS, p.hl7ID as CCAID, ib.value as CPT, i.itemname, concat(u.ulname,'', '',u.ufname) as Member, 
           sd.value as Product, e.date as EncDate, e.VisitType, 
           e.STATUS as EncStatus, e.encLock, 
           e.reason, ed.ChiefComplaint, e.generalNotes,
           concat(loc.ulname,'', '',loc.ufname) as LockedBy, e.doctorID, 
           e.ResourceID /*, did.value as DxCode, v.displayindex as DiagRefno, di.itemName as DxDescription */
from enc e left outer join doctors as d on e.doctorID=d.doctorID 
          left outer join users as dc on d.doctorID=dc.uid
          left outer join users as res on e.resourceID=res.uid
          left outer join users as loc on e.noteslogoutid=loc.uid
         left join users as u on e.patientID=u.uid
         left join patients as p on e.patientID=p.pid and left(p.hl7id,2)=''53''
          left outer join encounterdata as ed on e.encounterId=ed.encounterid
          left outer join billingdata as b on e.encounterID=b.encounterID
			left outer join itemdetail ib on b.itemid=ib.itemid and ib.propid=13
          left outer join structdemographics sd on u.uid=sd.patientID  and detailid = 681001
	      left outer join items as i on b.itemid=i.itemid
	/*	  left join diagnosis v on e.encounterid=v.encounterid
		left join items di on v.itemid=di.itemid  
		 left join itemdetail did on di.itemid=did.itemid  */
			
			where e.date between ''2019-01-01'' and ''2019-12-31''   ' )  q
			where (reason like '%pca%assess%'
			or reason like '%pca%eval%') and reason not like '%cancel%'

			--group by reason

			--order by visittype


		--	inner join (SELECT   [Code]
  --    ,[Definition]
  --    ,[Code System]
  --    ,[Code System OID]
  --    ,[Code System Version]
  --FROM [Medical_Analytics].[dbo].[HEDIS2018ValueSetsToCodes]
  --where 
  -- ([Value Set Name]   like 'Opioid Abuse%'
  -- or  [Value Set Name] like 'Alcohol Abuse%' or  
  --[Value Set Name] like 'Other Drug Abuse%')

  --group by [Code]
  --    ,[Definition]
  --    ,[Code System]
  --    ,[Code System OID]
  --    ,[Code System Version]) c on q.DxCode = c.code
		--	where    CPT is not null
			--where dxcode like 'v%'
			--order by encounterid
			----where cpt = '99497'
			--where visittype = 'BHSCH'
			--Q
			--join [cca-sql1].[sandbox_mpaquette].dbo.hedis_fuh_standalonevisits sav on q.cpt = sav.code
			

			--order by encounterid

			--select * from #ec_enct