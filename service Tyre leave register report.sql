Declare
@DateFromFilter date = getdate(),
@employeeindex int = 477812,
@clientindex int  = 1398


Declare
@employeeid nvarchar(100),
@employeename char(100),
@servicestartdate date,
@serviceenddate date,
@dateforresignemployee date,
@servicestatus tinyint


select 
@employeeid = employeeid,
@employeename = employeename, 
@employeeindex = employeeindex,
@servicestatus = servicestatus, 
@servicestartdate = servicestartdate,
@serviceenddate = serviceenddate
from vwempdetail where employeeindex = @employeeindex

Select employeeid,employeeindex,employeename,positionname,servicestatusdesc , Format(servicestartdate,'MM/dd/yyyy') as Servicestartdate, 
isnull(Format(serviceenddate,'MM/dd/yyyy'),'0') as ServiceEndDate
from vwempdetail where employeeindex  =  @employeeindex

-- Step 1: Generate From date & To date from leave period
Declare 
@Periodfromdate date,
@PeriodTodate date
select TOP 1 
@Periodfromdate = FromDate, 
@PeriodTodate = ToDate 
from fnLeavePeriod(@employeeindex,@DateFromFilter) GROUP BY FromDate,ToDate ORDER BY COUNT(*) DESC

-- Step 2: Generate all months and days
;WITH Calendar AS (
    SELECT 
        MonthNum = m.number, 
        DayNum = d.number
    FROM 
        master..spt_values m
    CROSS JOIN 
        master..spt_values d
    WHERE 
        m.type = 'P' AND m.number BETWEEN 1 AND 12
        AND d.type = 'P' AND d.number BETWEEN 1 AND 31
),
-- Step 3: Getting all Leaves
LeaveData AS (
    SELECT 
        MONTH(s.AtDate) AS MonthNum,
        DAY(s.AtDate) AS DayNum,
        s.LeaveDesc
    FROM tm_summary s
    INNER JOIN vwempdetail e ON s.employeeindex = e.employeeindex
    WHERE 
        s.employeeindex = @employeeindex
        AND s.AtDate BETWEEN @Periodfromdate AND @PeriodTodate
        AND s.IsLeave = 1
)


-- Step 4: generating list of leaves for whole year
SELECT 
    DATENAME(MONTH, DATEFROMPARTS(2025, c.MonthNum, 1)) AS [Month],
    MAX(CASE WHEN c.DayNum = 1 THEN ld.LeaveDesc END) AS [1],
    MAX(CASE WHEN c.DayNum = 2 THEN ld.LeaveDesc END) AS [2],
    MAX(CASE WHEN c.DayNum = 3 THEN ld.LeaveDesc END) AS [3],
    MAX(CASE WHEN c.DayNum = 4 THEN ld.LeaveDesc END) AS [4],
    MAX(CASE WHEN c.DayNum = 5 THEN ld.LeaveDesc END) AS [5],
    MAX(CASE WHEN c.DayNum = 6 THEN ld.LeaveDesc END) AS [6],
    MAX(CASE WHEN c.DayNum = 7 THEN ld.LeaveDesc END) AS [7],
    MAX(CASE WHEN c.DayNum = 8 THEN ld.LeaveDesc END) AS [8],
    MAX(CASE WHEN c.DayNum = 9 THEN ld.LeaveDesc END) AS [9],
    MAX(CASE WHEN c.DayNum = 10 THEN ld.LeaveDesc END) AS [10],
    MAX(CASE WHEN c.DayNum = 11 THEN ld.LeaveDesc END) AS [11],
    MAX(CASE WHEN c.DayNum = 12 THEN ld.LeaveDesc END) AS [12],
    MAX(CASE WHEN c.DayNum = 13 THEN ld.LeaveDesc END) AS [13],
    MAX(CASE WHEN c.DayNum = 14 THEN ld.LeaveDesc END) AS [14],
    MAX(CASE WHEN c.DayNum = 15 THEN ld.LeaveDesc END) AS [15],
    MAX(CASE WHEN c.DayNum = 16 THEN ld.LeaveDesc END) AS [16],
    MAX(CASE WHEN c.DayNum = 17 THEN ld.LeaveDesc END) AS [17],
    MAX(CASE WHEN c.DayNum = 18 THEN ld.LeaveDesc END) AS [18],
    MAX(CASE WHEN c.DayNum = 19 THEN ld.LeaveDesc END) AS [19],
    MAX(CASE WHEN c.DayNum = 20 THEN ld.LeaveDesc END) AS [20],
    MAX(CASE WHEN c.DayNum = 21 THEN ld.LeaveDesc END) AS [21],
    MAX(CASE WHEN c.DayNum = 22 THEN ld.LeaveDesc END) AS [22],
    MAX(CASE WHEN c.DayNum = 23 THEN ld.LeaveDesc END) AS [23],
    MAX(CASE WHEN c.DayNum = 24 THEN ld.LeaveDesc END) AS [24],
    MAX(CASE WHEN c.DayNum = 25 THEN ld.LeaveDesc END) AS [25],
    MAX(CASE WHEN c.DayNum = 26 THEN ld.LeaveDesc END) AS [26],
    MAX(CASE WHEN c.DayNum = 27 THEN ld.LeaveDesc END) AS [27],
    MAX(CASE WHEN c.DayNum = 28 THEN ld.LeaveDesc END) AS [28],
    MAX(CASE WHEN c.DayNum = 29 THEN ld.LeaveDesc END) AS [29],
    MAX(CASE WHEN c.DayNum = 30 THEN ld.LeaveDesc END) AS [30],
    MAX(CASE WHEN c.DayNum = 31 THEN ld.LeaveDesc END) AS [31]
FROM Calendar c
LEFT JOIN LeaveData ld ON ld.MonthNum = c.MonthNum AND ld.DayNum = c.DayNum
GROUP BY c.MonthNum
ORDER BY c.MonthNum;

-- Step 5: Geting Leave balance for Current year

If @servicestatus = 1
begin
	SELECT 
	    Format(Lp.Fromdate,'MM/dd/yyyy') As FromDate, 
		Format(Lp.todate, 'MM/dd/yyyy') As Todate,
		lcm.leavedescription,
		lb.Opening,
		lb.Entitlement,
		lb.TotalEntitlement,
		lb.Availed,
		lb.Adjusted,
		lb.Encashed,
		lb.Lapsed,
		lb.Balance,
		lb.Closing
	FROM fnLeaveBalance(@EmployeeIndex, @DateFromFilter) lb
	LEFT JOIN LeaveClientMapping lcm  ON lb.LeaveType = lcm.LeaveType AND lcm.ClientIndex = @clientindex
	inner JOin fnLeavePeriod(@EmployeeIndex, @DateFromFilter) lP on lb.leavetype = Lp.leavetype
end
Else
Begin
	if year(@DateFromFilter) < year(@serviceenddate)
	set @dateforresignemployee = @DateFromFilter
	else
	Set @dateforresignemployee = @serviceenddate

	SELECT 
		Format(Lp.Fromdate,'MM/dd/yyyy') As FromDate, 
		Format(Lp.todate, 'MM/dd/yyyy') As Todate,
		lcm.leavedescription,
		lb.Opening,
		lb.Entitlement,
		lb.TotalEntitlement,
		lb.Availed,
		lb.Adjusted,
		lb.Encashed,
		lb.Lapsed,
		lb.Balance,
		lb.Closing
	FROM fnLeaveBalance(@EmployeeIndex, @dateforresignemployee) lb
	LEFT JOIN LeaveClientMapping lcm  ON lb.LeaveType = lcm.LeaveType AND lcm.ClientIndex = @clientindex
	inner JOin fnLeavePeriod(@EmployeeIndex, @serviceenddate) lP on lb.leavetype = Lp.leavetype
End