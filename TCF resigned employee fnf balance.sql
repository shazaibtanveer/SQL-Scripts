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
    TotalDays = DATEDIFF(DAY, 
        CASE 
            WHEN e.ServiceStartDate > DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
            THEN e.ServiceStartDate 
            ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
        END, 
        e.ServiceEndDate
    ) + 1,

    -- Leave Must be availed
    CAST(
        ROUND(
            (10.0/365) *  NULLIF(
                DATEDIFF(DAY, 
                    CASE 
                        WHEN e.ServiceStartDate > DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                        THEN e.ServiceStartDate 
                        ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                    END, 
                    e.ServiceEndDate
                ) + 1, 0
            ),
            3
        ) AS DECIMAL(10,3)
    ) AS [Leave Must be availed],

    -- Leaves to be Pay Off
    CAST(
        ROUND(
            CASE 
                WHEN lb.Availed < 
                    ((10.0/365) * NULLIF(
                        DATEDIFF(DAY, 
                            CASE 
                                WHEN e.ServiceStartDate > DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                                THEN e.ServiceStartDate 
                                ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                            END, 
                            e.ServiceEndDate
                        ) + 1, 0
                    ))
                THEN 
                    lb.Closing - 
                    (((10.0/365) * NULLIF(
                        DATEDIFF(DAY, 
                            CASE 
                                WHEN e.ServiceStartDate > DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                                THEN e.ServiceStartDate 
                                ELSE DATEFROMPARTS(YEAR(e.ServiceEndDate), 1, 1) 
                            END, 
                            e.ServiceEndDate
                        ) + 1, 0
                    )) - lb.Availed)
                ELSE lb.Closing
            END,
        3) AS DECIMAL(10,3)
    ) AS [Leaves to be Pay Off]

FROM vwempdetail e
CROSS APPLY fnLeaveBalance(e.EmployeeIndex, e.ServiceEndDate) lb
WHERE e.ClientIndex = 1361
  AND e.TerritoryIndex = 25150 
  AND e.ServiceEndDate >= '2025-03-01'
  AND lb.LeaveType = 3
  AND e.lvgroup in (select lvgroup from leaverules where clientindex  =  1361 and leavetype  = 3 and CarryForward > 0);
