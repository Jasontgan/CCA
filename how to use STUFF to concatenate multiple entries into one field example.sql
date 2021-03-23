
IF OBJECT_ID('tempdb..#phone_numbers') IS NOT NULL DROP TABLE #phone_numbers

SELECT
	NAME_ID
	, PHONE_NUMBER
	, ROW_NUMBER() OVER (PARTITION BY NAME_ID ORDER BY PHONE_NUMBER) AS 'phone_num'
INTO #phone_numbers
FROM MPSnapshotProd.dbo.NAME_PHONE_NUMBERS
GROUP BY
	NAME_ID
	, PHONE_NUMBER

SELECT * FROM #phone_numbers ORDER BY NAME_ID, PHONE_NUMBER


SELECT
	p.NAME_ID
	, STUFF(
		ISNULL(
				(
					SELECT
						', ' + p2.PHONE_NUMBER
					FROM #phone_numbers AS p2
					WHERE p2.NAME_ID = p.NAME_ID
					GROUP BY
						p2.PHONE_NUMBER
					FOR XML PATH (''), TYPE
				).value('.', 'VARCHAR(MAX)') --note: "value" must be lowercase
			, '')
		, 1, 2, '') AS 'Phone number(s)'
FROM #phone_numbers AS p
GROUP BY
	p.NAME_ID
ORDER BY
	p.NAME_ID

