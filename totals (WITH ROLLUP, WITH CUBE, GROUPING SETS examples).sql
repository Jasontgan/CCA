

-- source: http://blogs.msdn.com/b/craigfr/archive/2007/10/11/grouping-sets-in-sql-server-2008.aspx

IF OBJECT_ID('tempdb..#Sales') IS NOT NULL DROP TABLE #Sales

CREATE TABLE #Sales (
	  EmpID		VARCHAR(20)
	, Yr		VARCHAR(20)
	, Sales		MONEY
)

INSERT INTO #Sales (EmpID, Yr, Sales) VALUES
	('1', '2005', 10000)
	, ('1', '2005', 2000)
	, ('1', '2006', 18000)
	, ('1', '2007', 25000)
	, ('2', '2005', 15000)
	, ('2', '2006', 6000)
	, ('3', '2006', 20000)
	, ('3', '2007', 24000)

SELECT * FROM #Sales


SELECT 'Next table shows:' = 'WITH ROLLUP example'
-- note use of ISNULL
SELECT
	ISNULL(EmpID, 'All Employees Total') AS 'EmpID'	-- note that on the sum rows, EmpID will be NULL -- ISNULL make these 'All Employees Total'
	, ISNULL(Yr, 'All Years Total') AS 'Yr'			-- ditto
	, SUM(Sales) AS 'Sales'
FROM #Sales
GROUP BY EmpID, Yr WITH ROLLUP


SELECT 'Next table shows:' = 'WITH ROLLUP example but using GROUPING SETS'
SELECT
	ISNULL(EmpID, 'All Employees Total') AS 'EmpID'
	, ISNULL(Yr, 'All Years Total') AS 'Yr'
	, SUM(Sales) AS 'Sales'
FROM #Sales
GROUP BY GROUPING SETS((EmpID, Yr), (EmpID), ())


SELECT 'Next table shows:' = 'WITH CUBE example'
SELECT
	ISNULL(EmpID, 'All Employees Total') AS 'EmpID'
	, ISNULL(Yr, 'All Years Total') AS 'Yr'
	, SUM(Sales) AS 'Sales'
FROM #Sales
GROUP BY EmpID, Yr WITH CUBE


SELECT 'Next table shows:' = 'WITH CUBE example but using GROUPING SETS'
SELECT
	ISNULL(EmpID, 'All Employees Total') AS 'EmpID'
	, ISNULL(Yr, 'All Years Total') AS 'Yr'
	, SUM(Sales) AS 'Sales'
FROM #Sales
GROUP BY GROUPING SETS((EmpID, Yr), (EmpID), (Yr), ())


SELECT 'Next table shows:' = 'GROUPING SETS with the intermediate totals skipped'
SELECT 
	ISNULL(EmpID, 'All Employees Total') AS 'EmpID'
	, ISNULL(Yr, 'All Years Total') AS 'Yr'
	, SUM(Sales) AS 'Sales'
FROM #Sales
GROUP BY GROUPING SETS((EmpID), (Yr))

