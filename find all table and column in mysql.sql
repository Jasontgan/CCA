select *
--into ##Referrals
from   openquery(SRVMEDECWREP01,'
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE ''%note%''
  ') as x

