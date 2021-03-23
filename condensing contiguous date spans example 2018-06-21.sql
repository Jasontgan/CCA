
IF OBJECT_ID('tempdb..#temp_example_table') IS NOT NULL DROP TABLE #temp_example_table

CREATE TABLE #temp_example_table (
	MembID			VARCHAR(7) NOT NULL
	, span_start	DATE NOT NULL
	, span_end		DATE NOT NULL
)

INSERT INTO #temp_example_table (MembID, span_start, span_end)
VALUES	  ('A69280', '2018-01-31', '2018-01-31')	-- new member
		, ('A69280', '2018-02-01', '2018-02-27')	-- gap: 0
		, ('B51797', '2018-05-22', '2018-05-31')	-- new member
		, ('B51797', '2018-06-01', '2018-06-15')	-- gap: 0
		, ('B51797', '2018-07-01', '2018-07-31')	-- gap: 15
		, ('B51797', '2018-08-01', '2018-08-12')	-- gap: 0
		, ('C37878', '2018-04-03', '2018-04-30')	-- new member
		, ('C37878', '2018-05-01', '2018-05-31')	-- gap: 0
		, ('C37878', '2018-06-02', '2018-06-19')	-- gap: 1
		, ('D97444', '2018-01-05', '2018-01-26')	-- new member
		, ('E24541', '2018-01-28', '2018-01-31')	-- new member
		, ('E24541', '2018-02-01', '2018-02-02')	-- gap: 0
		, ('F46305', '2018-02-19', '2018-02-28')	-- new member
		, ('F46305', '2018-03-01', '2018-03-31')	-- gap: 0
		, ('F46305', '2018-04-01', '2018-04-06')	-- gap: 0
		, ('G60012', '2018-06-17', '2018-06-30')	-- new member
		, ('H73860', '2018-05-01', '2018-05-31')	-- new member
		, ('H73860', '2018-06-01', '2018-06-12')	-- gap: 0

SELECT 'Next table is:' = 'original spans'
SELECT * FROM #temp_example_table ORDER BY MembID, span_start, span_end 


IF OBJECT_ID('tempdb..#temp_example_table_with_contiguous_span_starts') IS NOT NULL DROP TABLE #temp_example_table_with_contiguous_span_starts

; WITH Enroll (MembID, SeqNo, contiguous_span_start, span_start, span_end) AS (
		SELECT
			a.MembID
			, 1
			, a.span_start
			, a.span_start
			, a.span_end
		FROM #temp_example_table AS a
		WHERE NOT EXISTS (	-- excludes spans which are not at the beginning of contiguous spans
			SELECT
				a1.MembID
			FROM #temp_example_table AS a1
			WHERE a.MembID = a1.MembID
				AND DATEADD(DD, 1, a1.span_end) = a.span_start
		)
	UNION ALL
		SELECT
			c.MembID
			, c.SeqNo + 1
			, c.contiguous_span_start
			, a.span_start
			, a.span_end
		FROM Enroll AS c
		INNER JOIN #temp_example_table AS a
			ON c.MembID = a.MembID
		WHERE DATEADD(DD, 1, c.span_end) = a.span_start
	)
SELECT * INTO #temp_example_table_with_contiguous_span_starts FROM enroll

SELECT 'Next table is:' = 'condensed spans'
SELECT
	tetwcss.MembID
	, tetwcss.contiguous_span_start AS 'span_start'
	, MAX(tetwcss.span_end) AS 'span_end'
FROM #temp_example_table_with_contiguous_span_starts AS tetwcss
GROUP BY
	tetwcss.MembID
	, tetwcss.contiguous_span_start
ORDER BY
	tetwcss.MembID
	, tetwcss.contiguous_span_start

