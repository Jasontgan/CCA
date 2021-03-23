

IF OBJECT_ID('tempdb..#member_address_history') IS NOT NULL DROP TABLE #member_address_history

-- DROP TABLE #member_address_history
; WITH city_wo_non_printing_characters AS (
	SELECT
		  na.CITY AS 'CITY_orig'
		, UPPER(REPLACE(REPLACE(REPLACE(RTRIM(na.CITY), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')) AS 'CITY'
	FROM MPSnapshotProd.dbo.NAME_ADDRESS AS na
	GROUP BY
		  na.CITY
		, REPLACE(REPLACE(REPLACE(RTRIM(na.CITY), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')
), city_corrections AS ( --\\cca-fs1\groups\CrossFunctional\BI\Medical Analytics\Quality Bonus Program\Adherence\MA cities and towns from meh edit.xlsx
	SELECT
		  cwonpc.CITY_orig
		, UPPER(CASE
			WHEN cwonpc.CITY = 'ACTPM'					THEN 'ACTON'
			WHEN cwonpc.CITY = 'AGAWAN'					THEN 'AGAWAM'
			WHEN cwonpc.CITY = 'ALLSTON'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'AMEFBURY'				THEN 'AMESBURY'
			WHEN cwonpc.CITY = 'ANESBURY'				THEN 'AMESBURY'
			WHEN cwonpc.CITY = 'BEVERLLY'				THEN 'BEVERLY'
			WHEN cwonpc.CITY = 'BEVERLY FARMS'			THEN 'BEVERLY'
			WHEN cwonpc.CITY = 'BACK BAY'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'BIILLERICA'				THEN 'BILLERICA'
			WHEN cwonpc.CITY = 'BOXBORO'				THEN 'BOXBOROUGH'
			WHEN cwonpc.CITY = 'Brocton'				THEN 'BROCKTON'
			WHEN cwonpc.CITY = 'BROOKLINE VILLIAGE'		THEN 'BROOKLINE'
			WHEN cwonpc.CITY = 'BROOKLINE VLG'			THEN 'BROOKLINE'
			WHEN cwonpc.CITY = 'Bston'					THEN 'BOSTON'
			WHEN cwonpc.CITY = 'CAMBRDGE'				THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'CHARLESTOW'				THEN 'CHARLESTOWN'
			WHEN cwonpc.CITY = 'CHICOKEE'				THEN 'CHICOPEE'
			WHEN cwonpc.CITY = 'Chicopee, MA'			THEN 'CHICOPEE'
			WHEN cwonpc.CITY = 'CHICOPPE'				THEN 'CHICOPEE'
			WHEN cwonpc.CITY = 'CHINATOWN'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCHESTER'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCESTER'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCHESTER CENTER'		THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCHESTER CTR'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCHESTR CTR'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DORCHSTER'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'DRACUT MA'				THEN 'DRACUT'
			WHEN cwonpc.CITY = 'DORCHSTER'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'E ARLINGTON'			THEN 'ARLINGTON'
			WHEN cwonpc.CITY = 'EAST ARLINGTON'			THEN 'ARLINGTON'
			WHEN cwonpc.CITY = 'E BOSTON'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'EASTBOSTON'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'E BRIDGEWATER'			THEN 'EAST BRIDGEWATER'
			WHEN cwonpc.CITY = 'E BRIDGEWTR'			THEN 'EAST BRIDGEWATER'
			WHEN cwonpc.CITY = 'E BROOKFIELD'			THEN 'EAST BROOKFIELD'
			WHEN cwonpc.CITY = 'E CAMBRIDGE'			THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'E HAMPTON'				THEN 'EASTHAMPTON'
			WHEN cwonpc.CITY = 'E LONGMEADOW'			THEN 'EAST LONGMEADOW'
			WHEN cwonpc.CITY = 'E TEMPLETON'			THEN 'TEMPLETON'
			WHEN cwonpc.CITY = 'E WALPOLE'				THEN 'WALPOLE'
			WHEN cwonpc.CITY = 'E WAREHAM'				THEN 'WAREHAM'
			WHEN cwonpc.CITY = 'E. CAMBRIDGE'			THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'E.BOSTON'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'E.BRIDGEWATER'			THEN 'EAST BRIDGEWATER'
			WHEN cwonpc.CITY = 'E.BROOKFIELD'			THEN 'EAST BROOKFIELD'
			WHEN cwonpc.CITY = 'E.LONGMEADOW'			THEN 'EAST LONGMEADOW'
			WHEN cwonpc.CITY = 'E.WALPOLE'				THEN 'WALPOLE'
			WHEN cwonpc.CITY = 'E.WEYMOUTH'				THEN 'WEYMOUTH'
			WHEN cwonpc.CITY = 'EAST CAMBRIDGE'			THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'EAST WALPOLE'			THEN 'WALPOLE'
			WHEN cwonpc.CITY = 'EAST WEYMOUTH'			THEN 'WEYMOUTH'
			WHEN cwonpc.CITY = 'East Boston'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'FEEDING HILLS'			THEN 'AGAWAM'
			WHEN cwonpc.CITY = 'FEEDINGHILLS'			THEN 'AGAWAM'
			WHEN cwonpc.CITY = 'FEEDING HILL'			THEN 'AGAWAM'
			WHEN cwonpc.CITY = 'FISKDALE'				THEN 'STURBRIDGE'
			WHEN cwonpc.CITY = 'FISKDALED'				THEN 'STURBRIDGE'
			WHEN cwonpc.CITY = 'GARDENER'				THEN 'GARDNER'
			WHEN cwonpc.CITY = 'HALYOKE'				THEN 'HOLYOKE'
			WHEN cwonpc.CITY = 'HAMPTON'				THEN 'HAMPDEN'
			WHEN cwonpc.CITY = 'HAVER HILL'				THEN 'HAVERHILL'
			WHEN cwonpc.CITY = 'HAVRHILL'				THEN 'HAVERHILL'
			WHEN cwonpc.CITY = 'HAXVERHILL'				THEN 'HAVERHILL'
			WHEN cwonpc.CITY = 'HOLLYOKE'				THEN 'HOLYOKE'
			WHEN cwonpc.CITY = 'HOLOKE'					THEN 'HOLYOKE'
			WHEN cwonpc.CITY = 'HOLOYOKE'				THEN 'HOLYOKE'
			WHEN cwonpc.CITY = 'HOLYOAK'				THEN 'HOLYOKE'
			WHEN cwonpc.CITY = 'HYDA PARK'				THEN 'HYDE PARK'
			WHEN cwonpc.CITY = 'HYDEPARK'				THEN 'HYDE PARK'
			WHEN cwonpc.CITY = 'IDIAN ORCHARD'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'INDIAN ORCH'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'INDIAN ORCHANT'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'INDIAN ORCHARD'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'INDIANORCHARD'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'JAMAICA'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'Jamacia Plain'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'JAMAICA PLAIN'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'JAMAICA PLAINS'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'JAMICA PLAIN'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'JAMAICA PLAN'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'JAMICA PLAINS'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'LOWELLE'				THEN 'LOWELL'
			WHEN cwonpc.CITY = 'MADLEN'					THEN 'MALDEN'
			WHEN cwonpc.CITY = 'MALBORO'				THEN 'MARLBOROUGH'
			WHEN cwonpc.CITY = 'MALBOROUGH'				THEN 'MARLBOROUGH'
			WHEN cwonpc.CITY = 'Manchester'				THEN 'Manchester-by-the-Sea'
			WHEN cwonpc.CITY = 'MARLBORO'				THEN 'MARLBOROUGH'
			WHEN cwonpc.CITY = 'Medord'					THEN 'MEDFORD'
			WHEN cwonpc.CITY = 'MIDDLEBORO'				THEN 'MIDDLEBOROUGH'
			WHEN cwonpc.CITY = 'N ANDOVER'				THEN 'NORTH ANDOVER'
			WHEN cwonpc.CITY = 'N BROOKFIELD'			THEN 'NORTH BROOKFIELD'
			WHEN cwonpc.CITY = 'N CAMBRIDGE'			THEN 'CAMBRIDGE'
			WHEN cwonpc.CITY = 'N CHELMSFORD'			THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'N CHELMSFORD'			THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'N.CHELMSFORD'			THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'NO CHELMSFORD'			THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'NO CHELSMFORD'			THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'NORTH CHELMSFORD'		THEN 'CHELMSFORD'
			WHEN cwonpc.CITY = 'N QUINCY'				THEN 'QUINCY'
			WHEN cwonpc.CITY = 'N READING'				THEN 'NORTH READING'
			WHEN cwonpc.CITY = 'N.ANDOVER'				THEN 'NORTH ANDOVER'
			WHEN cwonpc.CITY = 'N.BROOKFIELD'			THEN 'NORTH BROOKFIELD'
			WHEN cwonpc.CITY = 'N.READING'				THEN 'NORTH READING'
			WHEN cwonpc.CITY = 'NEWTON CENTER'			THEN 'NEWTON'
			WHEN cwonpc.CITY = 'NEWTON CENTRE'			THEN 'NEWTON'
			WHEN cwonpc.CITY = 'NEWTON HGHLDS'			THEN 'NEWTON'
			WHEN cwonpc.CITY = 'NORTH ATTLEBORO'		THEN 'NORTH ATTLEBORO'
			WHEN cwonpc.CITY = 'NORTH HAMPTON'			THEN 'NORTHAMPTON'
			WHEN cwonpc.CITY = 'NORTHBORO'				THEN 'NORTHBOROUGH'
			WHEN cwonpc.CITY = 'NORTHHAMPTON'			THEN 'NORTHAMPTON'
			WHEN cwonpc.CITY = 'NORWWOD'				THEN 'NORWOOD'
			WHEN cwonpc.CITY = 'REDDING'				THEN 'READING'
			WHEN cwonpc.CITY = 'REVERE BEACH'			THEN 'REVERE'
			WHEN cwonpc.CITY = 'ROXBURY CROSSING'		THEN 'ROXBURY'
			WHEN cwonpc.CITY = 'ROXBURY XING'			THEN 'ROXBURY'
			WHEN cwonpc.CITY = 'S BOSTON'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'S.BOSTON'				THEN 'BOSTON'
			WHEN cwonpc.CITY = 'S.HADLEY'				THEN 'SOUTH HADLEY'
			WHEN cwonpc.CITY = 'S HADLEY'				THEN 'SOUTH HADLEY'
			WHEN cwonpc.CITY = 'SALISBURY BEACH'		THEN 'SALISBURY'
			WHEN cwonpc.CITY = 'SALSBURY'				THEN 'SALISBURY'
			WHEN cwonpc.CITY = 'SHELBURNE FALLS'		THEN 'SHELBURNE'
			WHEN cwonpc.CITY = 'SHELBURNE FLS'			THEN 'SHELBURNE'
			WHEN cwonpc.CITY = 'SO HADLEY'				THEN 'SOUTH HADLEY'
			WHEN cwonpc.CITY = 'South Boston'			THEN 'BOSTON'
			WHEN cwonpc.CITY = 'SOUTH BRIDGE'			THEN 'SOUTHBRIDGE'
			WHEN cwonpc.CITY = 'SOUTH HAMPTON'			THEN 'SOUTHAMPTON'
			WHEN cwonpc.CITY = 'SOUTH WICK'				THEN 'SOUTHWICK'
			WHEN cwonpc.CITY = 'SPFLD'					THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRING FIELD'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRINGFEILD'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRINGFILED'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRINGIFLED'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'SPRINGLFIELD'			THEN 'SPRINGFIELD'
			WHEN cwonpc.CITY = 'Stonham'				THEN 'STONEHAM'
			WHEN cwonpc.CITY = 'TYNGSBORO'				THEN 'TYNGSBOROUGH'
			WHEN cwonpc.CITY = 'W BRIDGEWATER'			THEN 'WEST BRIDGEWATER'
			WHEN cwonpc.CITY = 'W BROOKFIELD'			THEN 'WEST BROOKFIELD'
			WHEN cwonpc.CITY = 'W ROXBURY'				THEN 'WEST ROXBURY'
			WHEN cwonpc.CITY = 'W SPFLD'				THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'W SPRINGFIELD'			THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'W SPRNGFIELD'			THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'W.BOYLSTON'				THEN 'WEST BOYLSTON'
			WHEN cwonpc.CITY = 'W.BRIDGEWATER'			THEN 'WEST BRIDGEWATER'
			WHEN cwonpc.CITY = 'W.BROOKFIELD'			THEN 'WEST BROOKFIELD'
			WHEN cwonpc.CITY = 'W.NEWBURY'				THEN 'WEST NEWBURY'
			WHEN cwonpc.CITY = 'W.ROXBURY'				THEN 'WEST ROXBURY'
			WHEN cwonpc.CITY = 'W.SPRINGFIELD'			THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'WAKEFEILD'				THEN 'WAKEFIELD'
			WHEN cwonpc.CITY = 'WEST FIELD'				THEN 'WESTFIELD'
			WHEN cwonpc.CITY = 'WEST SPRINGFEILD'		THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'WEST SPRINGFIEL'		THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'WEST SPRINGFLD'			THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'West Srpringfield'		THEN 'WEST SPRINGFIELD'
			WHEN cwonpc.CITY = 'WESTBORO'				THEN 'WESTBOROUGH'
			WHEN cwonpc.CITY = 'WESTBOYLSTON'			THEN 'WEST BOYLSTON'
			WHEN cwonpc.CITY = 'WESTBROOKFIELD'			THEN 'WEST BROOKFIELD'
			WHEN cwonpc.CITY = 'WOCESTER'				THEN 'WORCESTER'
			WHEN cwonpc.CITY = 'WORSETER'				THEN 'WORCESTER'
			WHEN cwonpc.CITY = 'QUINY'					THEN 'Quincy'
			WHEN cwonpc.CITY = 'SALEEM'					THEN 'Salem'
			WHEN cwonpc.CITY = 'HAMDEN'					THEN 'Hampden'
			WHEN cwonpc.CITY = 'HOYOKE'					THEN 'Holyoke'
			WHEN cwonpc.CITY = 'PAMLER'					THEN 'Palmer'
			WHEN cwonpc.CITY = 'N ADAMS'				THEN 'North Adams'
			WHEN cwonpc.CITY = 'TAUMTON'				THEN 'Taunton'
			WHEN cwonpc.CITY = 'DENVERS'				THEN 'Danvers'
			WHEN cwonpc.CITY = 'HAVERAL'				THEN 'Haverhill'
			WHEN cwonpc.CITY = 'IPSWISH'				THEN 'Ipswich'
			WHEN cwonpc.CITY = 'METHEUM'				THEN 'Methuen'
			WHEN cwonpc.CITY = ' ORANGE'				THEN 'Orange'
			WHEN cwonpc.CITY = 'MIDFORD'				THEN 'Medford'
			WHEN cwonpc.CITY = 'MEDFIED'				THEN 'Medfield'
			WHEN cwonpc.CITY = 'HARDWICH'				THEN 'Harwich'
			WHEN cwonpc.CITY = 'NO ADAMS'				THEN 'North Adams'
			WHEN cwonpc.CITY = 'N EASTON'				THEN 'North Easton'
			WHEN cwonpc.CITY = 'N.EASTON'				THEN 'North Easton'
			WHEN cwonpc.CITY = 'S EASTON'				THEN 'South Easton'
			WHEN cwonpc.CITY = 'HAVERILL'				THEN 'Haverhill'
			WHEN cwonpc.CITY = 'CHIPOCEE'				THEN 'Chicopee'
			WHEN cwonpc.CITY = 'WETFIELD'				THEN 'Westfield'
			WHEN cwonpc.CITY = 'TEWSBURY'				THEN 'Tewksbury'
			WHEN cwonpc.CITY = 'W NEWTON'				THEN 'West Newton'
			WHEN cwonpc.CITY = 'W.NEWTON'				THEN 'West Newton'
			WHEN cwonpc.CITY = 'WAKFIELD'				THEN 'Wakefield'
			WHEN cwonpc.CITY = 'E TAUNTON'				THEN 'East Taunton'
			WHEN cwonpc.CITY = 'E.TAUNTON'				THEN 'East Taunton'
			WHEN cwonpc.CITY = 'FALLRIVER'				THEN 'Fall River'
			WHEN cwonpc.CITY = 'N DIGHTON'				THEN 'North Dighton'
			WHEN cwonpc.CITY = 'GLOCESTER'				THEN 'Gloucester'
			WHEN cwonpc.CITY = 'LAWERENCE'				THEN 'Lawrence'
			WHEN cwonpc.CITY = 'ROCK PORT'				THEN 'Rockport'
			WHEN cwonpc.CITY = 'SAILSBURY'				THEN 'Salisbury'
			WHEN cwonpc.CITY = 'SALUSBURY'				THEN 'Salisbury'
			WHEN cwonpc.CITY = 'SHELBURNE'				THEN 'Shelburne Falls'
			WHEN cwonpc.CITY = 'WESTFIELS'				THEN 'Westfield'
			WHEN cwonpc.CITY = 'WILBERHAM'				THEN 'Wilbraham'
			WHEN cwonpc.CITY = 'WILBRAHAN'				THEN 'Wilbraham'
			WHEN cwonpc.CITY = 'BILLERCIA'				THEN 'Billerica'
			WHEN cwonpc.CITY = 'FAMINGHAM'				THEN 'Framingham'
			WHEN cwonpc.CITY = 'TYNGSEORO'				THEN 'Tyngsboro'
			WHEN cwonpc.CITY = 'W MEDFORD'				THEN 'West Medford'
			WHEN cwonpc.CITY = 'W.MEDFORD'				THEN 'West Medford'
			WHEN cwonpc.CITY = 'S.WALPOLE'				THEN 'South Walpole'
			WHEN cwonpc.CITY = 'E FALMOUTH'				THEN 'East Falmouth'
			WHEN cwonpc.CITY = 'E SANDWICH'				THEN 'East Sandwich'
			WHEN cwonpc.CITY = 'E.FALMOUTH'				THEN 'East Falmouth'
			WHEN cwonpc.CITY = 'N FALMOUTH'				THEN 'North Falmouth'
			WHEN cwonpc.CITY = 'W YARMOUTH'				THEN 'West Yarmouth'
			WHEN cwonpc.CITY = 'MARBELHEAD'				THEN 'Marblehead'
			WHEN cwonpc.CITY = 'S HAMILTON'				THEN 'South Hamilton'
			WHEN cwonpc.CITY = 'S.HAMILTON'				THEN 'South Hamilton'
			WHEN cwonpc.CITY = 'SPINGFIELD'				THEN 'Springfield'
			WHEN cwonpc.CITY = 'SPRIGFIELD'				THEN 'Springfield'
			WHEN cwonpc.CITY = 'SPRINGFILD'				THEN 'Springfield'
			WHEN cwonpc.CITY = 'W.TOWNSEND'				THEN 'West Townsend'
			WHEN cwonpc.CITY = 'E WEYMOUTH'				THEN 'East Weymouth'
			WHEN cwonpc.CITY = 'FOXBOROUGH'				THEN 'Foxboro'
			WHEN cwonpc.CITY = 'N WEYMOUTH'				THEN 'North Weymouth'
			WHEN cwonpc.CITY = 'N.WEYMOUTH'				THEN 'North Weymouth'
			WHEN cwonpc.CITY = 'S WEYMOUTH'				THEN 'South Weymouth'
			WHEN cwonpc.CITY = 'S.WEYMOUTH'				THEN 'South Weymouth'
			WHEN cwonpc.CITY = 'HARWICHPORT'			THEN 'Harwich Port'
			WHEN cwonpc.CITY = 'S WELLFLEET'			THEN 'South Wellfleet'
			WHEN cwonpc.CITY = 'N ATTLEBORO'			THEN 'North Attleboro'
			WHEN cwonpc.CITY = 'N DARTMOUTH'			THEN 'North Dartmouth'
			WHEN cwonpc.CITY = 'N.ATTLEBORO'			THEN 'North Attleboro'
			WHEN cwonpc.CITY = 'N.DARTMOUTH'			THEN 'North Dartmouth'
			WHEN cwonpc.CITY = 'RAYNHAM CTR'			THEN 'Raynham Center'
			WHEN cwonpc.CITY = 'NEWBURY, MA'			THEN 'Newbury'
			WHEN cwonpc.CITY = 'S DEERFIELD'			THEN 'South Deerfield'
			WHEN cwonpc.CITY = 'S.DEERFIELD'			THEN 'South Deerfield'
			WHEN cwonpc.CITY = 'EAST MEADOW'			THEN 'East Longmeadow'
			WHEN cwonpc.CITY = 'LONG MEADOW'			THEN 'Longmeadow'
			WHEN cwonpc.CITY = 'THREE RIVER'			THEN 'Three Rivers'
			WHEN cwonpc.CITY = 'WEST SPRING'			THEN 'West Springfield'
			WHEN cwonpc.CITY = ' SOMERVILLE'			THEN 'Somerville'
			WHEN cwonpc.CITY = 'EVERETT, MA'			THEN 'Everett'
			WHEN cwonpc.CITY = 'N BILLERICA'			THEN 'North Billerica'
			WHEN cwonpc.CITY = 'N.BILLERICA'			THEN 'North Billerica'
			WHEN cwonpc.CITY = 'NEWTON HLDS'			THEN 'Newton Highlands'
			WHEN cwonpc.CITY = 'SOMMERVILLE'			THEN 'Somerville'
			WHEN cwonpc.CITY = 'SOMVERVILLE'			THEN 'Somerville'
			WHEN cwonpc.CITY = 'TYNSBOROUGH'			THEN 'Tyngsboro'
			WHEN cwonpc.CITY = 'S. WEYMOUTH'			THEN 'South Weymouth'
			WHEN cwonpc.CITY = 'SO WEYMOUTH'			THEN 'South Weymouth'
			WHEN cwonpc.CITY = 'YARMOUTHPORT'			THEN 'Yarmouth Port'
			WHEN cwonpc.CITY = 'LANESBOROUGH'			THEN 'Lanesboro'
			WHEN cwonpc.CITY = 'NO ATTLEBORO'			THEN 'North Attleboro'
			WHEN cwonpc.CITY = 'VINEYARD HVN'			THEN 'Vineyard Haven'
			WHEN cwonpc.CITY = 'TURNER FALLS'			THEN 'Turners Falls'
			WHEN cwonpc.CITY = 'TURNERS FALL'			THEN 'Turners Falls'
			WHEN cwonpc.CITY = 'EAST HAMPTON'			THEN 'Easthampton'
			WHEN cwonpc.CITY = 'FRAMININGHAM'			THEN 'Framingham'
			WHEN cwonpc.CITY = 'TYNGSBOROUGH'			THEN 'Tyngsboro'
			WHEN cwonpc.CITY = 'CHESNUT HILL'			THEN 'Chestnut Hill'
			WHEN cwonpc.CITY = 'NEEDHAM HGTS'			THEN 'Needham Heights'
			WHEN cwonpc.CITY = 'E. LONGMEADOW'			THEN 'East Longmeadow'
			WHEN cwonpc.CITY = 'NORTH HAMPDEN'			THEN 'Northampton'
			WHEN cwonpc.CITY = 'CAMBRIDGE, MA'			THEN 'Cambridge'
			WHEN cwonpc.CITY = 'NUTTINGS LAKE'			THEN 'Nutting Lake'
			WHEN cwonpc.CITY = 'BRAINTREE HLD'			THEN 'Braintree'
			WHEN cwonpc.CITY = 'NORTH  ANDOVER'			THEN 'North Andover'
			WHEN cwonpc.CITY = 'EASTLONGMEADOW'			THEN 'East Longmeadow'
			WHEN cwonpc.CITY = 'NORTH BILLENCA'			THEN 'North Billerica'
			WHEN cwonpc.CITY = 'WEST TOWNSHEND'			THEN 'West Townsend'
			WHEN cwonpc.CITY = ' INDIAN ORCHARD'		THEN 'Indian Orchard'
			WHEN cwonpc.CITY = 'WEST SPRNGFIELD'		THEN 'West Springfield'
			WHEN cwonpc.CITY = 'SPRINGFIELD PARK'		THEN 'Springfield'
			WHEN cwonpc.CITY = 'WEST  SPRINGFIELD'		THEN 'West Springfield'
			WHEN cwonpc.CITY = 'NORTH ATTLEBOROUGH'		THEN 'North Attleboro'
			WHEN cwonpc.CITY = 'SOUTH HADLEY FALLS'		THEN 'South Hadley'
			WHEN cwonpc.CITY = 'MANCHESTER BY THE SEA'	THEN 'Manchester-by-the-Sea'
			WHEN cwonpc.CITY = 'HOMELESS'				THEN NULL
			ELSE cwonpc.CITY END) AS 'CITY'
	FROM city_wo_non_printing_characters AS cwonpc
), county_wo_non_printing_characters AS (
	SELECT
		  na.COUNTY AS 'COUNTY_orig'
		, UPPER(REPLACE(REPLACE(REPLACE(RTRIM(na.COUNTY), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')) AS 'COUNTY'
	FROM MPSnapshotProd.dbo.NAME_ADDRESS AS na
	GROUP BY
		  na.COUNTY
		, REPLACE(REPLACE(REPLACE(RTRIM(na.COUNTY), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')
), county_corrections AS ( --\\cca-fs1\groups\CrossFunctional\BI\Medical Analytics\Quality Bonus Program\Adherence\MA cities and towns from meh edit.xlsx
	SELECT DISTINCT
		  ctywonpc.COUNTY_orig
		, CASE WHEN ctywonpc.COUNTY IN ('BARNSTABLE', 'BERKSHIRE', 'BRISTOL', 'DUKES', 'ESSEX', 'FRANKLIN', 'HAMPDEN', 'HAMPSHIRE', 'MIDDLESEX', 'NANTUCKET', 'NORFOLK', 'PLYMOUTH', 'SUFFOLK', 'WORCESTER') THEN ctywonpc.COUNTY
			WHEN ctywonpc.COUNTY = '6IDDLESEX'				THEN 'MIDDLESEX'
			WHEN ctywonpc.COUNTY = '2IDDLESEX'				THEN 'MIDDLESEX'
			WHEN ctywonpc.COUNTY = 'PYMOUTH'				THEN 'PLYMOUTH'
			WHEN ctywonpc.COUNTY = 'Uffolk'					THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = '9UFFOLK'				THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = '0FFOLK'					THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = '4UFFOLK'				THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = 'SFFOLK'					THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = '00FFOLK'				THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = '1ORCESTER'				THEN 'WORCESTER'
			WHEN ctywonpc.COUNTY = ' Berkshire '			THEN 'BERKSHIRE'
			WHEN ctywonpc.COUNTY = ' PLYMOUTH'				THEN 'PLYMOUTH'
			WHEN ctywonpc.COUNTY = 'DLESEX'					THEN 'MIDDLESEX'
			WHEN ctywonpc.COUNTY = 'IDDLESEX'				THEN 'MIDDLESEX'
			WHEN ctywonpc.COUNTY = 'MDDLESEX'				THEN 'MIDDLESEX'
			WHEN ctywonpc.COUNTY = 'NORFOLK COUNTY'			THEN 'NORFOLK'
			WHEN ctywonpc.COUNTY = 'Sullfolk'				THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = 'SUFFORK'				THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = '1UFFOLK'				THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = '040MOUTH'				THEN 'PLYMOUTH'
			WHEN ctywonpc.COUNTY = 'Revre'					THEN 'SUFFOLK'
			WHEN ctywonpc.COUNTY = 'HOMELESS'				THEN NULL
			WHEN RTRIM(LTRIM(ctywonpc.COUNTY)) = ''			THEN NULL
			ELSE NULL END AS 'COUNTY'
	FROM county_wo_non_printing_characters AS ctywonpc
), address_corrections AS (
		SELECT DISTINCT
			addr.NAME_ID
			, RTRIM(UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(addr.ADDRESS1)), CHAR(09), ''), CHAR(10), ''), CHAR(13), ''))
				+ ' ' + COALESCE(UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(addr.ADDRESS2)), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')), '')
				+ ' ' + COALESCE(UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(addr.ADDRESS3)), CHAR(09), ''), CHAR(10), ''), CHAR(13), '')), '')
				) AS 'STREET'
			, COALESCE(ccorr.CITY, addr.CITY) AS 'CITY'
			, addr.ZIP
			, ctycorr.COUNTY AS 'COUNTY'
			,	CASE WHEN addr.PREFERRED_FLAG = 'x' THEN 100 ELSE 200 END
				+
				CASE WHEN CHARINDEX('permanent', addr.ADDRESS_TYPE) > 0 THEN 10
					WHEN CHARINDEX('mailing', addr.ADDRESS_TYPE) > 0 THEN 20
					WHEN CHARINDEX('temp', addr.ADDRESS_TYPE) > 0 THEN 30
					WHEN CHARINDEX('shelter', addr.ADDRESS_TYPE) > 0 THEN 40
					WHEN CHARINDEX('office', addr.ADDRESS_TYPE) > 0 THEN 50
					ELSE 90
					END
				+
				CASE WHEN CHARINDEX('unverified', addr.ADDRESS_TYPE) > 0 THEN 1
					WHEN CHARINDEX('new', addr.ADDRESS_TYPE) > 0 THEN 2
					WHEN CHARINDEX('prior', addr.ADDRESS_TYPE) > 0 THEN 3
					WHEN CHARINDEX('old', addr.ADDRESS_TYPE) > 0 THEN 4
					ELSE 9
					END
				AS 'addr_priority_flag'
			, addr.[START_DATE]
			, addr.END_DATE
			, addr.UPDATE_DATE
		FROM MPSnapshotProd.dbo.NAME_ADDRESS AS addr
		LEFT JOIN city_corrections AS ccorr
			ON addr.CITY = ccorr.CITY_orig
		LEFT JOIN county_corrections AS ctycorr
			ON addr.COUNTY = ctycorr.COUNTY_orig
), address_priority AS (
	SELECT DISTINCT
		NAME_ID
		, STREET
		, CITY
		, ZIP
		, COUNTY
		, [START_DATE]
		, COALESCE(END_DATE, '9999-12-30') AS 'END_DATE'
		, UPDATE_DATE
		, ROW_NUMBER() OVER (PARTITION BY NAME_ID ORDER BY addr_priority_flag, UPDATE_DATE, [START_DATE], COALESCE(END_DATE, '9999-12-30')) AS 'priority'
	FROM address_corrections
), address_mm AS (
	SELECT DISTINCT
		ap.*
		, d.member_month
	FROM address_priority AS ap
	LEFT JOIN CCAMIS_Common.dbo.Dim_date AS d
		ON d.member_month BETWEEN ap.[START_DATE] AND ap.END_DATE
		AND d.member_month <= (SELECT DATEADD(DD, -DAY((SELECT DATEADD(MM, 4, GETDATE()))), (SELECT DATEADD(MM, 4, GETDATE()))))
)
SELECT
	id.CCAID
	, id.MMISID
	, t1.NAME_ID
	, t1.STREET
	, t1.CITY
	, t1.ZIP
	, t1.COUNTY
	, CAST(t1.[START_DATE] AS DATE) AS 'START_DATE'
	, CAST(t1.END_DATE AS DATE) AS 'END_DATE'
	, t1.UPDATE_DATE
	, t1.[priority]
	, CAST(t1.member_month AS DATE) AS 'member_month'
	, GETDATE() AS 'CREATEDATE'
	, (SELECT MAX(UPDATE_DATE) FROM MPSnapshotProd.dbo.NAME_ADDRESS) AS 'MP_DATE'
INTO #member_address_history
FROM address_mm AS t1
INNER JOIN address_mm AS t2
	ON t1.NAME_ID = t2.NAME_ID
	AND t1.member_month = t2.member_month
LEFT JOIN Medical_Analytics.dbo.member_ID_crosswalk AS id
	ON t1.NAME_ID = id.NAME_ID
GROUP BY
	id.CCAID
	, id.MMISID
	, t1.NAME_ID
	, t1.STREET
	, t1.CITY
	, t1.ZIP
	, t1.COUNTY
	, t1.[START_DATE]
	, t1.END_DATE
	, t1.UPDATE_DATE
	, t1.[priority]
	, t1.member_month
HAVING MIN(t2.[priority]) = t1.[priority]
ORDER BY
	NAME_ID
	, member_month
PRINT '#member_address_history'
-- SELECT * FROM #member_address_history ORDER BY CCAID, member_month
-- SELECT * FROM #member_address_history WHERE CCAID IS NOT NULL ORDER BY CCAID, member_month
-- SELECT COUNT(*) FROM #member_address_history	--2674347
-- problem spans:
-- SELECT NAME_ID, member_month, COUNT(*) FROM #member_address_history GROUP BY NAME_ID, member_month HAVING COUNT(*) > 1 ORDER BY NAME_ID, member_month
-- SELECT * FROM #member_address_history WHERE NAME_ID = 'N00000117587' ORDER BY NAME_ID, member_month
-- SELECT * FROM #member_address_history WHERE CCAID IS NULL ORDER BY NAME_ID, member_month
-- SELECT * FROM #member_address_history WHERE member_month IS NULL ORDER BY NAME_ID, member_month


/*

DROP TABLE Medical_Analytics.dbo.member_address_history_backup
SELECT * INTO Medical_Analytics.dbo.member_address_history_backup FROM Medical_Analytics.dbo.member_address_history

DROP TABLE Medical_Analytics.dbo.member_address_history

SELECT
	*
INTO Medical_Analytics.dbo.member_address_history
FROM #member_address_history
ORDER BY
	 CCAID
	 , member_month
CREATE UNIQUE INDEX memb_mm ON Medical_Analytics.dbo.member_address_history (NAME_ID, member_month)

-- SELECT distinct priority FROM Medical_Analytics.dbo.member_address_history where priority <> 1 ORDER BY CCAID, member_month
-- SELECT TOP 1000 * FROM Medical_Analytics.dbo.member_address_history WHERE CCAID IS NOT NULL ORDER BY CCAID, member_month

*/

