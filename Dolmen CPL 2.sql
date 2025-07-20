DECLARE
    @Today DATE = GETDATE(),
    @StartDate DATE,
    @EndDate DATE = GETDATE(),
    @clientindex INT = 1231;

-- Determine the start date based on the Attendance Cycle date
IF DAY(@Today) >= 16
    SET @StartDate = DATEADD(DAY, 15, DATEADD(MONTH, DATEDIFF(MONTH, 0, @Today), 0)); -- 16th of the current month
ELSE
    SET @StartDate = DATEADD(DAY, 15, DATEADD(MONTH, DATEDIFF(MONTH, 0, @Today) - 1, 0)); -- 16th of the Previous month

;WITH DateRange AS (
    SELECT @StartDate AS Attendancedate
    UNION ALL
    SELECT DATEADD(DAY, 1, Attendancedate)
    FROM DateRange
    WHERE DATEADD(DAY, 1, Attendancedate) <= @EndDate
),
Employees AS (
    SELECT e.employeeindex
    FROM employee e
    WHERE e.clientindex = @clientindex
),
-- CPL Calculation
CPLCalculation AS (
    SELECT  
        ts.Atdate,
        ts.employeeindex,
        DATEADD(DAY, 1, ts.Atdate) AS Fromdate, 
        DATEADD(MONTH, 1, ts.Atdate) AS Todate,
		ts.WorkingTime As AdjustedTime,
		case when ts.isholiday = 1 then 'Off Day' else 'Work Day' end as DayType
    FROM tm_summary ts
    JOIN Employees re ON ts.employeeindex = re.employeeindex
    JOIN DateRange dr ON ts.Atdate = dr.Attendancedate
    WHERE ((ts.isholiday = 0 AND ts.WorkingTime >= '16:00') 
         OR (ts.isholiday = 1 AND ts.WorkingTime >= '06:00'))
),
-- Get the LOBIndex with increment for multiple entries
LOBIndexIncrement AS (
    SELECT 
        e.employeeindex,
        e.Atdate,
        e.Fromdate,
        e.Todate,
		e.AdjustedTime,
		e.DayType,
        m.NextLOBIndex + ROW_NUMBER() OVER (PARTITION BY e.employeeindex ORDER BY e.Atdate) - 1 AS LOBindex
    FROM CPLCalculation e
    JOIN (
        SELECT 
            ee.employeeindex,
            ISNULL(MAX(lob.LOBIndex), 0) + 1 AS NextLOBIndex
        FROM employee ee
        LEFT JOIN leaveotherbalance lob ON ee.employeeindex = lob.employeeindex
        WHERE ee.employeeindex IN (SELECT DISTINCT employeeindex FROM CPLCalculation)
        GROUP BY ee.employeeindex
    ) m ON e.employeeindex = m.employeeindex
)
-- Insert into leaveotherbalance
INSERT INTO leaveotherbalance (Employeeindex, LOBindex, Leavetype, Fromdate, Todate, Allowed, Availed, Lapsed, Balance, Remarks, 
PostBy, Postdate, ReferenceDate, LOBSource, EntitlementType)
SELECT
    l.employeeindex,
    l.LOBindex,
    9 AS LeaveType,
    l.Fromdate,
    l.Todate,
    1 AS Allowed,
    0 AS Availed,
    0 AS Lapsed,
    1 AS Balance,
    'CPL against: ' + FORMAT(l.Atdate, 'yyyy-MM-dd (dddd)') +' (' + l.DayType + ') ' + ' Working Time: ' + l.AdjustedTime AS Remarks,
    9380 AS PostBy,
    GETDATE() AS Postdate,
    l.AtDate AS ReferenceDate,
    2 AS LOBSource,
    2 AS EntitlementType

FROM LOBIndexIncrement l
WHERE NOT EXISTS (SELECT 1 FROM leaveotherbalance ld WHERE ld.FromDate = l.Fromdate AND ld.Todate = l.Todate AND ld.EmployeeIndex = l.employeeindex AND ld.LeaveType = 9)
OPTION (MAXRECURSION 0);