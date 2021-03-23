USE Altruista
DECLARE @SearchStr nvarchar(100) = 'Member is requesting disposable chux pads, pullups size M and Vanilla Ensure, 24 cans'
DECLARE @Results TABLE (ColumnName nvarchar(370), ColumnValue nvarchar(3630))

SET NOCOUNT ON

DECLARE @TableName nvarchar(256), @ColumnName nvarchar(128), @SearchStr2 nvarchar(110)
SET  @TableName = ''
SET @SearchStr2 = QUOTENAME('%' + @SearchStr + '%','''')

WHILE @TableName IS NOT NULL

BEGIN
    SET @ColumnName = ''
    SET @TableName = 
    (
        SELECT MIN(QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME))
        FROM     INFORMATION_SCHEMA.TABLES
        WHERE         TABLE_TYPE = 'BASE TABLE'
            AND    QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) > @TableName
            AND    OBJECTPROPERTY(
                    OBJECT_ID(
                        QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME)
                         ), 'IsMSShipped'
                           ) = 0
    )

    WHILE (@TableName IS NOT NULL) AND (@ColumnName IS NOT NULL)

    BEGIN
        SET @ColumnName =
        (
            SELECT MIN(QUOTENAME(COLUMN_NAME))
            FROM     INFORMATION_SCHEMA.COLUMNS
            WHERE         TABLE_SCHEMA    = PARSENAME(@TableName, 2)
                AND    TABLE_NAME    = PARSENAME(@TableName, 1)
                AND    DATA_TYPE IN ('char', 'varchar', 'nchar', 'nvarchar', 'int', 'decimal')
                AND    QUOTENAME(COLUMN_NAME) > @ColumnName
        )

        IF @ColumnName IS NOT NULL

        BEGIN
            INSERT INTO @results
            EXEC
            (
                'SELECT ''' + @TableName + '.' + @ColumnName + ''', LEFT(' + @ColumnName + ', 3630) 
                FROM ' + @TableName + ' (NOLOCK) ' +
                ' WHERE ' + @ColumnName + ' LIKE ' + @SearchStr2
            )
        END
    END    
END

SELECT ColumnName, ColumnValue 
into #results
FROM @Results

select * from #results
--
[dbo].[HEALTH_NOTES].[HEALTH_NOTES]
[dbo].[HEALTHCOACH_REFERENCE].[RATIONALE_BY_REFEREE]
[dbo].[PATIENT_FOLLOWUP].[COMMENTS]

select --pd.[CLIENT_PATIENT_ID] AS CCAID, pf.patient_id, pf.comments, pf.created_date, 
*
from [dbo].[PATIENT_FOLLOWUP] pf
inner join [Altruista].[dbo].[PATIENT_FOLLOWUP_QUEUE] pfq
on pf.queue_id = pfq.queue_id
inner join [Altruista].[dbo].[PATIENT_FOLLOWUP_QUEUE_DEPARTMENT] pfqd
on pfq.patient_followup_queue_id = pfqd.patient_followup_queue_id and pfqd.dept_id = 216 -- 216 is Geriatric dept
inner join [Altruista].[dbo].[PATIENT_DETAILS] pd
on pf.patient_id = pd.patient_id
where pf.patient_id = '30474'
and [COMMENTS] = 'Hello, 

Member is requesting new DME supplies. Member is requesting disposable chux pads, pullups size M and Vanilla Ensure, 24 cans. Please follow up.'

select * from healthcoach_reference_v
where patient_id = '30474'

select * from [dbo].[HEALTH_NOTES]
where patient_id = '30474'
and health_note_type_id = 5 -- this is activity type id
--566654


select * from [Altruista].[dbo].[PATIENT_FOLLOWUP_QUEUE_DEPARTMENT]
where dept_id = 216



with temp as
(
	select --* 
	crow = row_number() over(partition by pd.[CLIENT_PATIENT_ID] order by pf.created_date desc),
	drow = row_number() over(partition by pd.[CLIENT_PATIENT_ID] order by pf.created_date desc),
	pd.[CLIENT_PATIENT_ID]	AS CCAID,
	--pf.patient_id,
	pf.comments,
	pf.created_date
	from [Altruista].[dbo].[PATIENT_FOLLOWUP] pf
	inner join [Altruista].[dbo].[PATIENT_FOLLOWUP_QUEUE] pfq
	on pf.queue_id = pfq.queue_id
	inner join [Altruista].[dbo].[PATIENT_FOLLOWUP_QUEUE_DEPARTMENT] pfqd
	on pfq.patient_followup_queue_id = pfqd.patient_followup_queue_id
	inner join [Altruista].[dbo].[PATIENT_DETAILS] pd
	on pf. patient_id = pf.patient_id
	where pfqd.dept_id in (77,78,79,80,81,82) -- dept id 77 to 82 are RRT West
	and (pf.comments like '%moca%' or pf.comments like '%geri%' or pf.comments like '%minicog%' or pf.comments like '%mini cog%')
	and pd.[CLIENT_PATIENT_ID] in ('5364521061','5364521084','5364521195','5365761200')
	group by pd.[CLIENT_PATIENT_ID],
	--pf.patient_id,
	pf.comments,
	pf.created_date
)
, temp2 as
(
	select 'comment' + cast(crow as varchar(10)) as crow, 'date' + cast(drow as varchar(10)) as drow, ccaid, comments, created_date 
	from temp
	--where crow <= 5
	--and drow <= 5
) select * from temp2
select ccaid
,date1 = max(date1)
,comment1 = max(comment1)
,date2 = max(date2)
,comment2 = max(comment2)
,date3 = max(date3)
,comment3 = max(comment3)
,date4 = max(date4)
,comment4 = max(comment4)
,date5 = max(date5)
,comment5 = max(comment5)

--isnull(q.[1],'') as comment1, isnull(q.[2],'') as comment2, isnull(q.[3],'') as comment3, isnull(q.[4],'') as comment4, isnull(q.[5],'') as comment5,
--isnull(b.[1],'') as date1, isnull(b.[2],'') as date2, isnull(b.[3],'') as date3, isnull(b.[4],'') as date4, isnull(b.[5],'') as date5  
from
temp2
pivot (max(comments) for crow in (comment1, comment2, comment3, comment4, comment5)) as q
pivot (max(created_date) for drow in (date1, date2, date3, date4, date5)) as b
group by ccaid
--order by 1
