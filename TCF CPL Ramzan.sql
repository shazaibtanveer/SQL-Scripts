DECLARE
    @Today DATE = GETDATE(),
    @StartDate DATE = '2025-03-02',
    @EndDate DATE = GETDATE(),
	@clientindex int = 1361



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
--CPL Calculation
CPLCalculation AS (
    SELECT 
        ts.Atdate,
        ts.employeeindex,
        ts.WorkingTime AS AdjustedTime,
        CASE 
            WHEN ts.isholiday = 1 THEN 'Off Day'
            WHEN DATENAME(WEEKDAY, ts.Atdate) = 'Friday' THEN 'Friday'
            ELSE 'Work Day'
        END AS DayType
    FROM tm_summary ts
    JOIN Employees re ON ts.employeeindex = re.employeeindex
    JOIN DateRange dr ON ts.Atdate = dr.Attendancedate
    WHERE ts.adjruleindex = 261
    AND (
        (ts.isholiday = 0 AND DATENAME(WEEKDAY, ts.Atdate) = 'Friday' AND ts.WorkingTime >= '07:00') -- Friday condition
        OR (ts.isholiday = 0 AND DATENAME(WEEKDAY, ts.Atdate) <> 'Friday' AND ts.WorkingTime >= '09:00') -- Other Work Days
        OR (ts.isholiday = 1 AND ts.WorkingTime >= '03:00') -- Off Day
    )
)
-- Insert into Leavedetail
INSERT INTO leavedetail (LeaveIndex, EmployeeIndex, LeaveType, SerialNo, FromDate, ToDate, TotalDays, Reason, LeaveStatus, LeaveEncashment, LeaveAdjustment, EntryBy, EntryDate)
SELECT 
    ROW_NUMBER() OVER (ORDER BY e.AtDate) + ISNULL((SELECT MAX(LeaveIndex) FROM leavedetail), 0) AS LeaveIndex,
    e.EmployeeIndex,
    9 AS LeaveType,
    1 AS SerialNo,
    e.AtDate AS FromDate,
    e.AtDate AS ToDate,
    1 AS TotalDays,
    'InLieu against: ' + FORMAT(e.Atdate, 'yyyy-MM-dd (dddd)') +' (' + e.DayType + ') ' + ' Working Time: ' + e.AdjustedTime  AS Reason,
    12 AS LeaveStatus,
    0 AS LeaveEncashment,
    0 AS LeaveAdjustment,
    262663 AS EntryBy,
    GETDATE() AS EntryDate
FROM CPLCalculation e
WHERE NOT EXISTS (SELECT 1 FROM leavedetail ld WHERE ld.FromDate = e.AtDate AND ld.EmployeeIndex = e.EmployeeIndex and ld.LeaveType = 9 and ld.LeaveStatus = 12)
OPTION (MAXRECURSION 0)