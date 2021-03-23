

select FirstName         
      ,LastName         
      ,CCAID              
	  ,ReferralID        
	 ,convert(varchar(60),ServiceRequestedBy) as ServiceRequestedBy
	 ,reffromname
	  ,RefDate 
	  	  ,cast(RTRIM(i2.itemname) as VARCHAR(60))    as 'Issue description and type of service'
		  ,cast(rtrim(id2.value) as varchar(60))  as CPT
	  ,RefstDate
	  ,Refenddate
	  ,reftoname
	  ,modifieddate
	  ,cast(Reopened  as varchar(100))
	  ,convert(varchar(30),ExpeditedFlag) as ExpeditedFlag
	  ,convert(varchar(30),ExtensionFlag) as ExtensionFlag
	  ,convert(varchar(30),InvalidAuth) as InvalidAuth
	  ,cast(deleteflag as varchar(100)) as deleteFlag
	  ,cast(diagnosis as varchar(100))
	  ,cast([reason] as varchar(400)) as Reason
	  --,Receiveddate
	  ,cast(i2.itemid as varchar(100)) ProcItemID
	  
	  ,cast(rtrim(id2.value) as varchar(60))  as 'service_code'
	  	 , cast(RTRIM(i2.itemname) as VARCHAR(60))  as ServiceDescription 
		 --, requeststatus
		  --,case when RTRIM(ltrim(id2.value)) in ( '191','192','120','100') then 'IP/SNF' else '' end as IPSNFFlag
,ContractingEntityDescription


from openquery(SRVMEDECWREP01,'select r.authtype, r.ReferralID, r.patientID
, p.hl7id as CCAID, u.ulname as LastName,u.ufname as FirstName
, u.ptDOB as DOB
, r.refFrom, d.PrintName as RefFromDoc, 
                                 r.date as RefDate, r.diagnosis, r.refStDate
								 , r.refEnddate, r.visitsAllowed, r.RefTo,
								  d.PrintName RefToDoc, r.notes, r.deleteFlag
								  , r.referralType, 
                                 r.priority as RefPriority, r.assignedTo
								 ,  r.assignedToID, r.status, r.procedures
								 , cpt.ItemName as ProcedureName, r.fromfacility
								 , r.ToFacility, r.speciality, sp.Speciality as SpecialityDescr, r.POS, 
                                 r.UnitType, r.refFromP2pNPI, r.refFromName, r.refToP2pNPI, r.refToName
								 , ip.value as TypeOfInpatientFacility, 
                                 adm.value as TypeOfAdmission, plan.value as PlannedUnplanned
								 , disp.value as DispositionName, pri.value as Priority,
                                 ret.value as ReturnToAdmin,reason,r.Receiveddate,
                                 reqby.value as ServiceRequestedBy, decis.value ServiceDecision
								 , deadl.value as MeetsDeadline, revi.value as DecisionReview
								 , disc.value as DecisionDiscussedWMember,
                                 decdt.value as DecisionDate, r.modifiedDate,exped.value as ExpeditedFlag
								 ,exten.value as ExtensionFlag,inv.value as InvalidAuth
								 , reop.value as Reopened,id.value as CPT
									,esl.requestStatus					

                                                        from referral r join users u on r.patientID=u.uid and r.deleteFlag=0 and r.referralType=''O''
                                                                  join patients p on u.uid=p.pid and left(p.hl7id,2)=''53''
                                                                  left outer join doctors d on r.refFrom=d.doctorID
                                                                  left outer join doctors d2 on r.RefTo=d2.doctorID
                                                                  left outer join edi_speciality sp on r.speciality=sp.ID
                                                                  left outer join structreferraloutgoing ip on r.referralID=ip.referralID and ip.detailID=669001
                                                                  left outer join structreferraloutgoing adm on r.referralID=adm.referralID and adm.detailID=670001
                                                                  left outer join structreferraloutgoing plan on r.referralID=plan.referralID and plan.detailID=671001
                   						 left join edi_278_servicelevel esl on r.referralID =  esl.referralID
				                         left outer join structreferraloutgoing disp on r.referralID=disp.referralID and disp.detailID=672001
                                         left outer join structreferraloutgoing pri on r.referralID=pri.referralID and pri.detailID=136001
                                        left outer join structreferraloutgoing inter on r.referralID=inter.referralID and inter.detailID=137001
                                         left outer join structreferraloutgoing ret on r.referralID=ret.referralID and ret.detailID=660001
										left outer join structreferraloutgoing reqby on r.referralID=reqby.referralID and reqby.detailID=661001                                    
                                        left outer join structreferraloutgoing decis on r.referralID=decis.referralID and decis.detailID=662001
                                        left outer join structreferraloutgoing deadl on r.referralID=deadl.referralID and deadl.detailID=663001
                                        left outer join structreferraloutgoing revi on r.referralID=revi.referralID and revi.detailID=665001
										left outer join structreferraloutgoing disc on r.referralID=disc.referralID and disc.detailID=666001
                                        left outer join structreferraloutgoing decdt on r.referralID=decdt.referralID and decdt.detailID=667001
                                        left outer join structreferraloutgoing inv on r.referralID=inv.referralID and inv.detailID=1213614
                                        left outer join structreferraloutgoing reop on r.referralID=reop.referralID and reop.detailID=1213622
                                        left outer join structreferraloutgoing exped on r.referralID=exped.referralID and exped.detailID=1213623
                                        left outer join structreferraloutgoing exten on r.referralID=exten.referralID and exten.detailID=1213620
                                        left outer join items cpt on r.procedures=cpt.itemID
										left outer join itemdetail id on cpt.itemID=id.itemid and (propid = 13 or propid is null)																		     
 																                                                                                                               
                                                                  where r.deleteflag = 0  ') as x

 CROSS APPLY clinicalcommon.dbo.udfSplit(x.[procedures],'|') split2
                       join (select * from openquery(SRVMEDECWREP01,'select itemid, itemname from items ')) as i2 on split2.val=i2.itemid --and DATEDIFF(MM,x.DOB,x.RefDate)/12 < 65
                  join (select * from openquery(SRVMEDECWREP01,'select itemid, value from itemdetail' )) as id2 on i2.itemid=id2.itemid and id2.value<>''

	 left join ccamis_common.dbo.dim_date d on refstdate =d.date
	 left join ccamis_current.dbo.enrollment_premium ep on ccaid-5364521034 = ep.member_id and d.member_month = ep.member_month
	 left join ccamis_common.dbo.Contracting_Entity_Records ce on ep.contract_ent_id = ce.contract_ent_id
				  where 
(refstdate>='2017-07-05' or refenddate >='2017-07-05')
and reftoname like '%Compassionate%'
and reason not like 'inval%'

Group By
	FirstName         
		,LastName         
		,CCAID              
		,ReferralID        
		,convert(varchar(60),ServiceRequestedBy)
		,reffromname
		,RefDate 
		,cast(i2.itemname as varchar(100))
		,RefstDate
		,Refenddate
		,reftoname
		,modifieddate
		,cast(Reopened  as varchar(100))
		,convert(varchar(30),ExpeditedFlag)
		,convert(varchar(30),ExtensionFlag)
		,convert(varchar(30),InvalidAuth)
		,cast(deleteflag as varchar(100))
		,cast(diagnosis as varchar(100))
	  ,cast([reason] as varchar(400))
	  ,cast(Receiveddate as varchar(100))
	  ,cast(i2.itemid as varchar(100))
	  ,cast(rtrim(id2.value) as varchar(60)) 
	  	  ,cast(RTRIM(i2.itemname) as VARCHAR(60)) 
		 , cast(requeststatus as varchar(60)) 
,ContractingEntityDescription
