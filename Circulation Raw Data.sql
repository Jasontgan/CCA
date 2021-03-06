/****** Script for SelectTopNRows command from SSMS  ******/
SELECT count(*)
  FROM [Medical_Analytics].[CCA\tkeunggan].[circulation_2019]
--114443

SELECT top 1000 *
  FROM [Medical_Analytics].[CCA\tkeunggan].[circulation_2019]





SELECT *
  FROM [Medical_Analytics].[CCA\tkeunggan].[circulation_2019]
  where [Ride Status] like 'Incom%'

select top 100 *
FROM [Medical_Analytics].[CCA\tkeunggan].[circulation_2019]
where [Total Cost] <> 'N/A'
order by [Total Cost] desc


select [Successfully Completed], [Ride Status], count(*)
  FROM [Medical_Analytics].[CCA\tkeunggan].[circulation_2019]
group by [Successfully Completed], [Ride Status]
order by 1,2


select [Successfully Completed], [Ride Status], count(*)
  FROM [Medical_Analytics].[CCA\tkeunggan].[circulation_2019]
group by [Successfully Completed], [Ride Status]


select distinct top 10 [Trip ID], count(*)
FROM [Medical_Analytics].[CCA\tkeunggan].[circulation_2019]
group by [Trip ID]
order by 2


select max(Ride ID) as ride_id, [Trip ID], [Date], [Rider ID], [Dist  (mi) Estimated], [Dist  (mi) Actual], [Total Cost], [Ride Status], [Pick Up Latitude], [Pick Up Longitude], [Drop Off Latitude], [Drop Off Longitude] 
FROM [Medical_Analytics].[CCA\tkeunggan].[circulation_2019]



