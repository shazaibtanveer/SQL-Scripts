
DECLARE 
    @AdjIndex INT,
    @AdjBatchIndex INT = 2255,
    @FromDate DATE = '2025-02-26',
    @ToDate DATE = '2025-03-25',
	@clientindex int = 1334 

SELECT @AdjIndex = MAX(AdjIndex) FROM tm_adj;

SELECT 
    @AdjIndex + ROW_NUMBER() OVER (ORDER BY EmployeeIndex) as AdjIndex,
    AdjType,
    AtDate as AdjDate,
    EmployeeIndex,
	null as leavetype,
    TotalDays,
    AdjBal,
    @AdjBatchIndex as AdjBatchIndex,
    2 as AdjStatus,
	null as AdjValue,
	null as adjsource,
	null as AdjBalLc,
	null as AdjBalEg,
	null as TotalDaysLC,
	null as TotalDaysEG
FROM 
(
    SELECT 
        ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY EmployeeIndex) AS SNo,
        EmployeeIndex, 
        AtDate,
		7 as adjtype,  --7
		CASE 
        WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 2 THEN 0.5 else 0
    END AS TotalDays,
     CASE 
        WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 0 THEN 0.333334
        WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 1 THEN 0.666667
        WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 2 THEN 0
    END AS AdjBal
    FROM 
        tm_summary                 
    WHERE 
        ClientIndex = @clientindex 
        AND AtDate BETWEEN @FromDate AND @ToDate 
        AND AdjLC > 0           
        AND AdjLvBal NOT IN (0.5, 1)
Union All
	SELECT 
        ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY EmployeeIndex) AS SNo,
        EmployeeIndex, 
        AtDate,
		19 as adjtype,--19
	 CASE 
        WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 2 THEN 0.5 else 0
		END AS TotalDays,
     CASE 
        WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 0 THEN 0.333334
        WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 1 THEN 0.666667
        WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 2 THEN 0
		END AS AdjBal
    FROM 
        tm_summary                 
    WHERE 
        ClientIndex = @clientindex 
        AND AtDate BETWEEN @FromDate AND @ToDate 
        AND AdjEG > 0           
        AND AdjLvBal NOT IN (0.5, 1)
) t;  

insert into tm_adjhistory (AdjIndex,HNo,AdjStatus,EntryDate,UserEmpIndex)
select AdjIndex, 1 , 2 ,getdate(),300136 from tm_adj where adjbatchindex  = @AdjBatchIndex 