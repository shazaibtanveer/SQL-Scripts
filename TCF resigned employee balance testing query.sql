SELECT 
    e.employeeid,
    lb.EmployeeIndex,
    e.employeename,
    e.positionname,
    e.servicestatusdesc,
	e.lvgroupname,
    FORMAT(e.ServiceStartDate, 'MM/dd/yyyy') AS ServiceStartDate,
    FORMAT(e.ServiceEndDate, 'MM/dd/yyyy') AS ServiceEndDate,
    lb.Opening,
    lb.Entitlement,
    lb.TotalEntitlement,
    lb.Closing AS [Balance till service end date],
    lb.Availed,

    -- Precalculate TotalDays
    TotalDays = (DATEDIFF(MONTH, 
    CASE 
        WHEN e.ServiceStartDate >= DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
        THEN e.ServiceStartDate 
        ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
    END, e.ServiceEndDate) * 30 ) + day(e.ServiceEndDate),

    -- Leave Must be availed
    CAST(
        ROUND(
            0.028 *  NULLIF((DATEDIFF(MONTH, 
							CASE 
							    WHEN e.ServiceStartDate >= DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
							    THEN e.ServiceStartDate 
							    ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
							END, e.ServiceEndDate) * 30 ) + day(e.ServiceEndDate), 0),3) AS DECIMAL(10,3)) AS [Leave Must be availed],

    -- Leaves to be Pay Off
    CAST(
        ROUND(
            CASE 
                WHEN lb.Availed < 
                    (0.028 * NULLIF(
                        (DATEDIFF(MONTH, 
						CASE 
						    WHEN e.ServiceStartDate >= DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
						    THEN e.ServiceStartDate 
						    ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
						END, e.ServiceEndDate) * 30 ) + day(e.ServiceEndDate), 0))
                THEN 
                    lb.Closing - 
                    ((0.028 * NULLIF(
                        (DATEDIFF(MONTH, 
                            CASE 
                                WHEN e.ServiceStartDate > DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                                THEN e.ServiceStartDate 
                                ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                            END, e.ServiceEndDate) * 30 ) + day(e.ServiceEndDate), 0
                    )) - lb.Availed)
                ELSE lb.Closing
            END,
        3) AS DECIMAL(10,3)
    ) AS [Leaves to be Pay Off]

FROM vwempdetail e
CROSS APPLY fnLeaveBalance(e.EmployeeIndex, e.ServiceEndDate) lb
WHERE e.ClientIndex = 1361
  AND e.TerritoryIndex = 25150 
  AND BUIndex = 152
  AND e.ServiceEndDate >= '2025-01-01'
  AND lb.LeaveType = 3
  AND e.lvgroup in (select lvgroup from leaverules where clientindex  =  1361 and leavetype  = 3 and CarryForward > 0);







--main query 


  SELECT 
    e.EmployeeID,
    lb.EmployeeIndex,
    e.EmployeeName,
    e.PositionName,
    e.ServiceStatusDesc,
    e.LvGroupName,
    FORMAT(e.ServiceStartDate, 'MM/dd/yyyy') AS ServiceStartDate,
    FORMAT(e.ServiceEndDate, 'MM/dd/yyyy') AS ServiceEndDate,
    lb.Opening,
    lb.Entitlement,
    lb.TotalEntitlement,
    lb.Closing AS [Balance till service end date],
    lb.Availed,
    TD.TotalDays,
    CAST(ROUND(0.028 * TD.TotalDays, 3) AS DECIMAL(10,3)) AS [Leave Must be availed],
    CAST(ROUND(
        CASE 
            WHEN lb.Availed < (0.028 * TD.TotalDays) THEN 
                lb.Closing - ((0.028 * TD.TotalDays) - lb.Availed)
            ELSE lb.Closing
        END, 3) AS DECIMAL(10,3)) AS [Leaves to be Pay Off]

FROM vwEmpDetail e
CROSS APPLY fnLeaveBalance(e.EmployeeIndex, e.ServiceEndDate) lb
CROSS APPLY (
    SELECT 
        TotalDays = 
            (DATEDIFF(MONTH, 
                CASE 
                    WHEN e.ServiceStartDate >= DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                    THEN e.ServiceStartDate 
                    ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                END, e.ServiceEndDate) * 30) + DAY(e.ServiceEndDate)) TD

WHERE 
    e.ClientIndex = 1361
    AND e.TerritoryIndex = 25150 
	AND e.BUIndex = 152
    AND e.ServiceEndDate >= '2025-03-01'
    AND lb.LeaveType = 3
    AND e.LvGroup IN (
        SELECT LvGroup 
        FROM LeaveRules 
        WHERE ClientIndex = 1361 AND LeaveType = 3 AND CarryForward > 0
    );


--For tCF Report

WITH TotalDaysCTE AS (
    SELECT 
        e.EmployeeIndex,
        (DATEDIFF(DAY, 
            CASE 
                WHEN e.ServiceStartDate >= DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                THEN e.ServiceStartDate 
                ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
            END, e.ServiceEndDate)) AS TotalDays
    FROM employee e
    WHERE e.ClientIndex = @clientindex
    AND e.TerritoryIndex = 25150
    AND e.ServiceEndDate > 	DATEFROMPARTS(YEAR(@fromdate), 1, 1)
)
SELECT 
    lb.EmployeeIndex,
    lb.Opening,
    lb.Entitlement,
    lb.TotalEntitlement,
    lb.availed,
    lb.adjusted,
    CAST(ROUND(
        CASE 
            WHEN lb.Availed < (0.028 * TD.TotalDays) THEN 
                lb.Closing - ((0.028 * TD.TotalDays) - lb.Availed)
            ELSE lb.Closing
        END, 3) AS DECIMAL(10,3)) AS balance,
	lb.closing
FROM employee e
CROSS APPLY fnLeaveBalance(e.EmployeeIndex, e.ServiceEndDate) lb
inner JOIN TotalDaysCTE TD ON e.EmployeeIndex = TD.EmployeeIndex
WHERE 
    lb.LeaveType = 3
ORDER BY e.EmployeeIndex;
