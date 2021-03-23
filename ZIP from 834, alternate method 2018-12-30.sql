
; WITH ZIP_entries AS (
	SELECT DISTINCT
		etf.TransactionID
		--, etf.FileDate
		, etf.[Postal Code]
		, CAST(d.member_month AS DATE) AS 'member_month'
	-- SELECT *
	FROM Medical_Analytics.dbo.Onecare834 AS etf
	INNER JOIN CCAMIS_Common.dbo.Dim_date AS d
		ON etf.FileDate = d.[Date]
	WHERE COALESCE(RTRIM(etf.[Postal Code]), '') <> ''
		AND etf.TransactionID IN ('100000003713', '100000003895')
	--ORDER BY etf.TransactionID, member_month
), ZIP_rows AS (
	SELECT DISTINCT
		ze.TransactionID
		, ze.member_month
		, ze.[Postal Code]
		, ROW_NUMBER() OVER (PARTITION BY ze.TransactionID ORDER BY ze.member_month) AS 'member_row'
	FROM ZIP_entries AS ze
), ZIP_begin_end AS (
	SELECT
		zr.*
		, zr2.member_row AS 'member_row2'
		, CASE WHEN zr2.member_row IS NULL THEN zr.[Postal Code]
			WHEN zr.[Postal Code] <> zr2.[Postal Code] THEN zr.[Postal Code]
			END AS 'new_code_begin'
		, CASE WHEN zr0.member_row IS NULL THEN zr.[Postal Code]
			WHEN zr.[Postal Code] <> zr0.[Postal Code] THEN zr.[Postal Code]
			END AS 'new_code_end'
	FROM ZIP_rows AS zr
	LEFT JOIN ZIP_rows AS zr2
		ON zr.TransactionID = zr2.TransactionID
		AND zr.member_row = zr2.member_row + 1
	LEFT JOIN ZIP_rows AS zr0
		ON zr.TransactionID = zr0.TransactionID
		AND zr.member_row = zr0.member_row - 1
	--ORDER BY TransactionID, member_month
), ZIP_begin_end_rows AS (
	SELECT
		zbe.*
		, ROW_NUMBER() OVER (PARTITION BY zbe.TransactionID ORDER BY zbe.new_code_begin) AS 'range_begin_num'
		, ROW_NUMBER() OVER (PARTITION BY zbe.TransactionID ORDER BY zbe.new_code_end) AS 'range_end_num'
	FROM ZIP_begin_end AS zbe
	--WHERE zbe.new_code_begin IS NOT NULL
	--	AND zbe.new_code_end IS NOT NULL
	--ORDER BY
	--	zbe.TransactionID
	--	, zbe.member_row
	--ORDER BY TransactionID, member_month
)
SELECT
	zber.TransactionID
	, LEFT(zber.[Postal Code] , 5) AS 'ZIP'
	, zber.member_month AS 'ZIP_begin'
	, DATEADD(MM, 1, zber2.member_month) AS 'ZIP_end'
	--, zber.member_row
	----, zber.member_row2
	--, zber.new_code_begin
	----, zber.new_code_end
	--, zber.range_begin_num
	----, zber.range_end_num
	--, zber2.new_code_end
	--, zber2.range_end_num
FROM ZIP_begin_end_rows AS zber
LEFT JOIN ZIP_begin_end_rows AS zber2
	ON zber.TransactionID = zber2.TransactionID
	AND zber.new_code_begin = zber2.new_code_end
	AND zber.range_begin_num = zber2.range_end_num
order by 1, 2, 4
