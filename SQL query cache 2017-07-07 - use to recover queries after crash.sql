
SELECT
	*
	, LEN([Script]) AS 'Script_length'
FROM (
	SELECT
		execquery.last_execution_time AS [Date Time]
		, execsql.text AS [Script]
	FROM sys.dm_exec_query_stats AS execquery
	CROSS APPLY sys.dm_exec_sql_text(execquery.sql_handle) AS execsql
	WHERE execsql.text LIKE '%5360000001%'
		--AND execquery.last_execution_time BETWEEN '2017-07-06 19:00:00' AND '2017-07-06 16:02:59'
	--ORDER BY execquery.last_execution_time DESC
) AS queries
ORDER BY [Date Time] DESC

SELECT qs.execution_count,  
    SUBSTRING(qt.text,qs.statement_start_offset/2 +1,   
                 (CASE WHEN qs.statement_end_offset = -1   
                       THEN LEN(CONVERT(nvarchar(max), qt.text)) * 2   
                       ELSE qs.statement_end_offset end -  
                            qs.statement_start_offset  
                 )/2  
             ) AS query_text,   
     qt.dbid, dbname= DB_NAME (qt.dbid), qt.objectid,   
     qs.total_rows, qs.last_rows, qs.min_rows, qs.max_rows  
FROM sys.dm_exec_query_stats AS qs   
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt   
WHERE qt.text like '%depression%'   
ORDER BY qs.execution_count DESC;  
