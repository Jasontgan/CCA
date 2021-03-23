select
       *
       , DATEADD(MM, DATEDIFF(MM, 0, RefDate), 0) AS 'ref_mm'
--into ##Referrals
from   openquery(SRVMEDECWREP01,'select  
       r.ReferralID
,      p.hl7id as CCAID
,      concat(concat(u.ulname,'', ''),u.ufname) as PatientName
,      r.refFrom
,      d.PrintName as RefFromName
,      r.date as RefDate
,      r.reason
,      r.visitsAllowed
,   d.PrintName RefToDoc
,   r.refToName
,      r.assignedTo
,      r.status
, cpt.ItemName as ProcedureName
, r.speciality
,   sp.Speciality as SpecialityDescr
,  r.POS
, reqby.value as ServiceRequestedBy
, decis.value ServiceDecision
, id.value
,refstdate
,refenddate



from referral r 
  
join users u on r.patientID=u.uid and r.deleteFlag=0
join patients p on u.uid=p.pid and left(p.hl7id,2)=''53''
left outer join doctors d on r.refFrom=d.doctorID

left outer join edi_speciality sp on r.speciality=sp.ID
left outer join structreferraloutgoing ip  on r.referralID=ip.referralID and ip.detailID=669001
left outer join structreferraloutgoing adm on r.referralID=adm.referralID and adm.detailID=670001
left outer join structreferraloutgoing plan  on r.referralID=plan.referralID and plan.detailID=671001
left outer join structreferraloutgoing disp on r.referralID=disp.referralID and disp.detailID=672001
left outer join structreferraloutgoing pri on r.referralID=pri.referralID and pri.detailID=136001
left outer join structreferraloutgoing inter on r.referralID=inter.referralID and inter.detailID=137001
left outer join structreferraloutgoing ret  on r.referralID=ret.referralID and ret.detailID=660001
left outer join structreferraloutgoing reqby  on r.referralID=reqby.referralID and reqby.detailID=661001                                    
left outer join structreferraloutgoing decis  on r.referralID=decis.referralID and decis.detailID=662001
left outer join structreferraloutgoing revi  on r.referralID=revi.referralID and revi.detailID=665001
left outer join structreferraloutgoing disc  on r.referralID=disc.referralID and disc.detailID=666001
left outer join structreferraloutgoing decdt  on r.referralID=decdt.referralID and decdt.detailID=667001
left outer join items cpt on r.procedures=cpt.itemID 
left outer join itemdetail id on cpt.itemID=id.itemid and (propid = 13 or propid is null)
left outer join items i on r.diagnosis=i.itemid  

where 
r.deleteflag = 0 
and r.refenddate >= ''2016-01-01'' 
/* and r.reftoname like "%Lahey%" */
and id.value = ''T1019''
/* and decis.value not like "%Withdraw%" and decis.value not like "%Administrative%" and decis.value not like "%Terminated%" */
  ') as x

