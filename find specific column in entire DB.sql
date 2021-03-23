use [Altruista]

SELECT      c.name  AS 'ColumnName'
            ,t.name AS 'TableName'
FROM        sys.columns c
JOIN        sys.tables  t   ON c.object_id = t.object_id
WHERE       c.name LIKE '%place_of_service_code%'
ORDER BY    TableName
            ,ColumnName;