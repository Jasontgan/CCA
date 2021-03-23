
DECLARE @example_time		AS DATETIME		= GETDATE()
DECLARE @example_time_TEXT	AS VARCHAR(23)	= @example_time

SELECT
	@example_time												AS '@example_time'			
	, @example_time_TEXT										AS '@example_time_TEXT'				-- note that the date format changes when converted to text
	, CAST(@example_time AS DATETIME)							AS 'CAST AS DATETIME'				-- same as @example_time
	, CAST(@example_time AS DATE)								AS 'CAST AS DATE'					-- time component removed
	, CONVERT(VARCHAR(10), @example_time, 101)					AS 'CONVERT to standard US date format'
	, CONVERT(VARCHAR(10), @example_time, 1)					AS 'CONVERT to standard US date format (2-digit year)'
	, FORMAT(@example_time, 'MM/dd/yyyy HH:mm:ss', 'en-US')		AS 'FORMAT en-US (24 hr)'			-- note that 'HH' gives 24-hour time	-- note that 'MM' is month and 'mm' is minute
	, FORMAT(@example_time, 'MM/dd/yyyy hh:mm:ss tt', 'en-US')	AS 'FORMAT en-US (AM/PM)'			-- note that 'hh' gives 12-hour time and 'tt' adds AM/PM
	, FORMAT(@example_time, 'M/d/y HH:mm:ss', 'en-US')			AS 'FORMAT en-US (single digits)'	-- no leading zeroes on day and month	-- note that 'y' gives a 2-digit year
	, FORMAT(@example_time, 's', 'en-US')						AS 'date stamp (time included)'
	, FORMAT(@example_time, 'd', 'en-US')						AS 'default time format'
	, CONVERT(VARCHAR(10), @example_time, 112)					AS 'YYYYMMDD'

SELECT
	  DATEPART(yy, @example_time)								AS 'DATEPART year (yy)'
	, DATEPART(qq, @example_time)								AS 'DATEPART quarter (qq)'
	, DATEPART(mm, @example_time)								AS 'DATEPART month (mm)'
	, DATEPART(dy, @example_time)								AS 'DATEPART day of year (dy)'
	, DATEPART(dd, @example_time)								AS 'DATEPART day (dd)'
	, DATEPART(wk, @example_time)								AS 'DATEPART week of year (wk)'
	, DATEPART(dw, @example_time)								AS 'DATEPART weekday (dw)'
	, DATEPART(hh, @example_time)								AS 'DATEPART hour (hh)'
	, DATEPART(mi, @example_time)								AS 'DATEPART minute (mi)'
	, DATEPART(ss, @example_time)								AS 'DATEPART second (ss)'

SELECT
	LEFT(@example_time, 3)										AS '@example_time (first 3 characters)'			-- note that using LEFT converts the DATETIME to VARCHAR
	, LEFT(@example_time_TEXT, 3)								AS '@example_time_TEXT (first 3 characters)'
	, CAST(DATEPART(mm, @example_time) AS VARCHAR(2)) + '/' + CAST(DATEPART(dd, @example_time) AS VARCHAR(2)) + '/' + CAST(DATEPART(yy, @example_time) AS VARCHAR(4)) AS 'reformated from text'
