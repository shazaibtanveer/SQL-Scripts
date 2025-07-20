declare
@Fromdate date = '2025-01-01',
@ToDate date = getdate(),
@clientindex int = 1361,
@leavetype int = 3


IF OBJECT_ID('tempdb.dbo.#emplvbal', 'U') IS NOT NULL 
DROP TABLE #emplvbal;

declare @ToDateDate DATE = CAST(@ToDate AS DATE)
--create a #table for All employees balance
CREATE TABLE #emplvbal (
    employeeindex INT,
    Opening DECIMAL(10, 2),
    Entitlement DECIMAL(10, 2),
    TotalEntitlement DECIMAL(10, 2),
    Availed DECIMAL(10, 2),
    Adjusted DECIMAL(10, 2),
    Balance DECIMAL(10, 2),
    Closing DECIMAL(10, 2)
);

--inserting active employee's leaves balance
insert into #emplvbal
SELECT 
    lb.EmployeeIndex,
	lb.Opening,
	lb.Entitlement,
	lb.TotalEntitlement,
	lb.availed,
	lb.adjusted,
	lb.balance,
	lb.closing
FROM 
    employee e
CROSS APPLY 
    fnleavebalance(e.EmployeeIndex, @ToDateDate) lb
WHERE 
    e.ClientIndex = @clientindex and e.TerritoryIndex = 25150 and lb.LeaveType = @leavetype and e.servicestatus  = 1
Order by 
	e.EmployeeIndex

--inserting Non-Active employee's leaves balance only for TCF
IF @clientindex = 1361
BEGIN
    ;WITH TotalDaysCTE AS (
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
        AND e.ServiceEndDate > DATEFROMPARTS(YEAR(@fromdate), 1, 1)
    )
insert into #emplvbal
SELECT 
    lb.EmployeeIndex,
    lb.Opening,
    lb.Entitlement,
    lb.TotalEntitlement,
    lb.availed,
    cast(lb.availed AS DECIMAL(10,2)) - CAST(ROUND(0.028 * TD.TotalDays, 2) AS DECIMAL(10,2)) AS adjusted,
    CAST(
        CASE
            WHEN ROUND(
                CASE 
                    WHEN lb.Availed < (0.028 * TD.TotalDays) THEN 
                        lb.Closing - ((0.028 * TD.TotalDays) - lb.Availed)
                    ELSE lb.Closing
                END, 3) > 56.0 
            THEN 56.0
            ELSE ROUND(
                CASE 
                    WHEN lb.Availed < (0.028 * TD.TotalDays) THEN 
                        lb.Closing - ((0.028 * TD.TotalDays) - lb.Availed)
                    ELSE lb.Closing
                END, 3)
        END AS DECIMAL(10, 2)) AS balance,
    CASE WHEN lb.Closing > 56 THEN 56.0 ELSE lb.Closing END AS Closing
FROM employee e
    CROSS APPLY fnLeaveBalance(e.EmployeeIndex, e.ServiceEndDate) lb
    INNER JOIN TotalDaysCTE TD ON e.EmployeeIndex = TD.EmployeeIndex
WHERE 
       lb.LeaveType = @leavetype
ORDER BY 
		e.EmployeeIndex;

END


else

--inserting Non-Active employee's leaves balance

insert into #emplvbal
SELECT 
    lb.EmployeeIndex,
	lb.Opening,
	lb.Entitlement,
	lb.TotalEntitlement,
	lb.availed,
	lb.adjusted,
	lb.balance,
	lb.Closing
FROM 
    employee e
CROSS APPLY 
    fnleavebalance(e.EmployeeIndex, e.serviceenddate) lb
WHERE 
    e.ClientIndex = @clientindex and lb.LeaveType = @leavetype and e.servicestatus  != 1
	AND e.serviceenddate > 	DATEFROMPARTS(YEAR(@fromdate), 1, 1)
Order by 
	e.EmployeeIndex

--Main Select Query
SELECT 
    e.employeeid as [Employee ID],
    eb.EmployeeIndex as [Employee Index],
    e.employeename as [Employee Name],
	e.DepartmentName as [Department Name],
	e.SubDepartmentName as [Sub Department],
	e.EmploymentType as [Employment Type],
	e.ServiceStatusDesc as [Service Status],
    FORMAT(e.ServiceStartDate, 'MM/dd/yyyy') AS [Service Start Date],
    isnull(FORMAT(e.sconfirmationdate, 'MM/dd/yyyy'),'-') AS [Confirmation Date],
    Case WHEN e.ServiceEndDate = '01/01/1900' THEN '-' ELSE FORMAT(e.ServiceEndDate, 'MM/dd/yyyy') END AS [Service End Date],
	eb.Opening,
    eb.Entitlement,
    eb.TotalEntitlement,
    eb.Availed,
	eb.Adjusted,
	eb.Balance,
    eb.Closing
From #emplvbal eb
inner join vwempdetail e on eb.employeeindex = e.employeeindex 
where e.clientindex  =  @clientindex
order by e.employeeindex



