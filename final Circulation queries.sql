select top 1000 * from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor != 'CTS'


select count(*) from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
--
1428946



select distinct reportperiodstart, count(*)
from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
group by reportperiodstart
--

select * from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where eventkeyreservnbr = '9312584706'
order by tripkey, claimlineno




select *
from
(
       select distinct eventkeyreservnbr, count(distinct procedurecode1) as temp
       from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
       where sourcevendor = 'CRC'
       group by eventkeyreservnbr
)aa
where temp > 3

select * from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where procedurecode4 is not null
order by tripkey, claimlineno


select 
--COUNT(Distinct ClaimID) as 'Dist Claim Count'
--,SUM(Paid) as 'Total Paid'
eventkeyreservnbr, sum(paidamount) as paid
from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
       where sourcevendor = 'CRC'
       and (pickupstreet is null OR PickupState is null)
group by eventkeyreservnbr



select top 100 * from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
and ActualPickUpTime = '0000'


select memberid, count(distinct eventkeyreservnbr)
from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
and ActualPickUpTime = '0000'
and reportperiodstart = '2019-08-01'
group by memberid
order by 2 desc

select * from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
and ActualPickUpTime = '0000'
and reportperiodstart = '2019-08-01'
and memberid = '5365559329'
order by dateofservice, eventkeyreservnbr, tripkey, claimlineno



---- 1 duplicated claims

select top 100 *
from
(
	select memberid, planid, dateofservice, --procedurecode1,
	pickupstreet, pickupcity, pickupstate, dropoffstreet, dropoffcity, dropoffstate, 
	scheduledpickuptime, actualpickuptime, actualdropofftime, eventkeyreservnbr, sum(billedamount) as billedamount, sum(paidamount) as paidamount, providername
	from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
	where sourcevendor = 'CRC'
	--and reportperiodstart = '2019-09-01'
	and actualpickuptime <> '0000'
	group by memberid, planid, dateofservice, --procedurecode1,
	pickupstreet, pickupcity, pickupstate, dropoffstreet, dropoffcity, dropoffstate, 
	scheduledpickuptime, actualpickuptime, actualdropofftime, eventkeyreservnbr, providername
)a
inner join 
(
	select memberid, planid, dateofservice, --procedurecode1,
	pickupstreet, pickupcity, pickupstate, dropoffstreet, dropoffcity, dropoffstate, 
	scheduledpickuptime, actualpickuptime, actualdropofftime, eventkeyreservnbr, sum(billedamount) as billedamount, sum(paidamount) as paidamount, providername
	from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
	where sourcevendor = 'CRC'
	--and reportperiodstart = '2019-09-01'
	and actualpickuptime <> '0000'
	group by memberid, planid, dateofservice, --procedurecode1,
	pickupstreet, pickupcity, pickupstate, dropoffstreet, dropoffcity, dropoffstate, 
	scheduledpickuptime, actualpickuptime, actualdropofftime, eventkeyreservnbr, providername
)b
on a.memberid = b.memberid and a.dateofservice = b.dateofservice and a.pickupstreet = b.pickupstreet and a.dropoffstreet = b.dropoffstreet and a.actualpickuptime = b.actualpickuptime --do we need the same time as well?
and a.providername = b.providername -- if look for different provider, then remove the "a.actualpickuptime = b.actualpickuptime"
and a.eventkeyreservnbr <> b.eventkeyreservnbr
order by 1, 3, a.eventkeyreservnbr

---- 2 NULL address

select top 100 *
from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
and (PickupState = 'NU' or dropoffstate = 'NU')


---- 3 member no show

SELECT top 50
enc.reportperiodstart, enc.memberid, enc.planid, enc.dateofservice, enc.procedurecode1, enc.pickupstreet, enc.pickupcity, enc.pickupstate, enc.dropofffacility, enc.dropoffstreet, enc.dropoffcity, enc.dropoffstate, enc.eventkeyreservnbr, enc.tripkey, 
enc.scheduledpickuptime, enc.actualpickuptime, enc.actualdropofftime, enc.billedamount, enc.paidamount, enc.providername
,port.RideID
,port.Ride_Status
FROM [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims] enc
INNER JOIN Actuarial_Services.dbo.CRC_Portal_Claims port ON enc.eventkeyreservnbr = port.RideID
WHERE sourcevendor = 'CRC'
and port.Ride_Status = 'Canceled - Rider_Canceled'
AND enc.ActualPickupTime > enc.ScheduledPickupTime
order by eventkeyreservnbr


---- 5 Lyft driver cancelled and we were billed

SELECT top 20
enc.reportperiodstart, enc.memberid, enc.planid, enc.dateofservice, enc.procedurecode1, enc.pickupstreet, enc.pickupcity, enc.pickupstate, enc.dropofffacility, enc.dropoffstreet, enc.dropoffcity, enc.dropoffstate, enc.eventkeyreservnbr, enc.tripkey, 
enc.scheduledpickuptime, enc.actualpickuptime, enc.actualdropofftime, enc.billedamount, enc.paidamount, enc.providername
,port.RideID
,port.Ride_Status
FROM [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims] enc
inner JOIN Actuarial_Services.dbo.CRC_Portal_Claims port ON enc.eventkeyreservnbr = port.RideID
WHERE port.Ride_Status in ( 'Canceled - Driver_Canceled', 'Completed - Driver_Canceled', 'Incomplete - Driver_Canceled' , 'No_Drivers_Available')
AND enc.paidamount > 0
AND enc.ProviderName = 'Lyft'
order by enc.eventkeyreservnbr

---- 6 TP driver cancelled and we were billed

SELECT top 20
enc.reportperiodstart, enc.memberid, enc.planid, enc.dateofservice, enc.procedurecode1, enc.pickupstreet, enc.pickupcity, enc.pickupstate, enc.dropofffacility, enc.dropoffstreet, enc.dropoffcity, enc.dropoffstate, enc.eventkeyreservnbr, enc.tripkey, 
enc.scheduledpickuptime, enc.actualpickuptime, enc.actualdropofftime, enc.billedamount, enc.paidamount, enc.providername
,port.RideID
,port.Ride_Status
FROM [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims] enc
inner JOIN Actuarial_Services.dbo.CRC_Portal_Claims port ON enc.eventkeyreservnbr = port.RideID
WHERE port.Ride_Status in ( 'Canceled - Driver_Canceled', 'Completed - Driver_Canceled', 'Incomplete - Driver_Canceled' , 'No_Drivers_Available')
AND enc.paidamount > 0
AND enc.ProviderName <> 'Lyft'
order by enc.eventkeyreservnbr

---- 12 HCPCS count

select distinct procedurecode1, count(*), sum(paidamount)
from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
group by procedurecode1
order by 2 desc


---- 13 HCPCS on a Single Claim

select 
tripkey
,count(distinct procedurecode1) as 'HCPCS count'
from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
group by tripkey
having count(procedurecode1) > 5
order by 2 desc 





---- 15 X0147
select top 100 * from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
and procedurecode3 = 'X0147' 
--
0


---- 16 PULocation = DOLocation

select top 100 * from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
and pickupstreet = dropoffstreet
and pickupcity = dropoffcity


---- 17 PUCity=DOCity & >$100

select top 20
enc.reportperiodstart, enc.memberid, enc.planid, enc.dateofservice, enc.procedurecode1, enc.pickupstreet, enc.pickupcity, enc.pickupstate, enc.dropofffacility, enc.dropoffstreet, enc.dropoffcity, enc.dropoffstate, enc.eventkeyreservnbr, enc.tripkey, 
enc.scheduledpickuptime, enc.actualpickuptime, enc.actualdropofftime, enc.actualmiles, enc.billedamount, enc.paidamount, enc.providername
--COUNT(distinct eventkeyreservnbr) as 'Dist Claim Count'
from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims] enc
where pickupCity = dropoffCity
and Paidamount >= '100' --This dollar amount can be changed based on what the business thinks is worth noting
--group by procedurecode1
--order by procedurecode1
order by enc.eventkeyreservnbr

---- 18 Est Mi vs Act Mi (mileage difference - portal vs encounter)


SELECT top 20
enc.reportperiodstart, enc.memberid, enc.planid, enc.dateofservice, enc.procedurecode1, enc.pickupstreet, enc.pickupcity, enc.pickupstate, enc.dropofffacility, enc.dropoffstreet, enc.dropoffcity, enc.dropoffstate, enc.eventkeyreservnbr, enc.tripkey, 
enc.scheduledpickuptime, enc.actualpickuptime, enc.actualdropofftime, enc.actualmiles, enc.billedamount, enc.paidamount, enc.providername
,port.RideID
,port.Ride_Status, port.actual_distance
FROM [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims] enc
inner JOIN Actuarial_Services.dbo.CRC_Portal_Claims port ON enc.eventkeyreservnbr = port.RideID
WHERE enc.actualmiles <> port.actual_distance
order by enc.eventkeyreservnbr

---- 19  ActPUT&ActDOT vs Duration>30min  (portal vs encounter)


select ccaid, tripid, rideid, Transportation_Provider, dateofservice, ride_status, pu_address, pu_city, pu_state, do_address, do_city, do_state, DO_Latitude, DO_Longitude, Original_PU_Time, Actual_PU_Time, Original_DO_Time, Actual_DO_Time, Est_Distance, Actual_Distance, Paid,
datediff(minute, actual_pu_time, actual_do_time) as calcuated_time, duration
from Actuarial_Services.dbo.CRC_Portal_Claims p
where abs(datediff(minute, actual_pu_time, actual_do_time) - duration) > 30
order by 2





















srvmlbsqlt05\cca
in [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]


Actuarial_Services.dbo.CRC_Portal_Claims 


select count(*) from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
--
1428946

select top 100 * from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'


select distinct reportperiodstart, count(*)
from [Medical_Analytics].[CCA\jzheng].[all_TransportationClaims]
where sourcevendor = 'CRC'
group by reportperiodstart
--
