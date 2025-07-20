DECLARE @FromDate DATE = '2025-04-26';
DECLARE @ToDate DATE = '2025-05-25';
DECLARE @FourMonthStart DATE;
SET @FourMonthStart = DATEADD(MONTH, -3, @FromDate);

SELECT 
    e.employeeid,
    s.employeeindex,
    e.employeename,
    e.positionname,
    e.locationname,
    e.Grade,
    SUM(s.IsAbsent) AS [Total Absent],
    SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveType IN (1,2,3,16) AND s.atdate BETWEEN @FromDate AND @ToDate THEN IIF(s.LeaveTotalDays < 1, s.LeaveTotalDays, 1) ELSE 0 END) AS [Total availed Allowed leaves],
    SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveType IN (5,28,79,80,81) AND s.atdate BETWEEN @FromDate AND @ToDate THEN IIF(s.LeaveTotalDays < 1, s.LeaveTotalDays, 1) ELSE 0 END) AS [Total LWOP],
    SUM(CASE WHEN s.adjlvbal > 0.25 AND s.atdate BETWEEN @FromDate AND @ToDate THEN s.adjlvbal ELSE 0 END) AS [AdjLvBal],
    SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveType IN (1,2,3,16) AND s.atdate BETWEEN @FourMonthStart AND @ToDate THEN IIF(s.LeaveTotalDays < 1, s.LeaveTotalDays, 1) ELSE 0 END) AS [Total availed Allowed leaves in current 4 month],
	CASE 
    WHEN SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveType IN (1,2,3,16) AND s.atdate BETWEEN @FromDate AND @ToDate THEN IIF(s.LeaveTotalDays < 1, s.LeaveTotalDays, 1) ELSE 0 END) <= 1
	 AND SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveType IN (5,28,79,80,81) AND s.atdate BETWEEN @FromDate AND @ToDate THEN IIF(s.LeaveTotalDays < 1, s.LeaveTotalDays, 1) ELSE 0 END) = 0
     AND SUM(CASE WHEN s.adjlvbal > 0.25 AND s.atdate BETWEEN @FromDate AND @ToDate THEN s.adjlvbal ELSE 0 END) = 0
     AND SUM(s.IsAbsent) = 0
    THEN CASE 
             WHEN e.gradeindex IN (53,54,56,59,60) THEN 2500
             WHEN e.gradeindex IN (55,61,57,58,62,63,64,65) THEN 2000
             ELSE 0
         END
    WHEN SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveType IN (1,2,3,16) AND s.atdate BETWEEN @FromDate AND @ToDate THEN IIF(s.LeaveTotalDays < 1, s.LeaveTotalDays, 1) ELSE 0 END) > 1
     AND SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveType IN (5,28,79,80,81) AND s.atdate BETWEEN @FromDate AND @ToDate THEN IIF(s.LeaveTotalDays < 1, s.LeaveTotalDays, 1) ELSE 0 END) = 0
	 AND SUM(s.IsAbsent) = 0
	 AND SUM(CASE WHEN s.adjlvbal > 0.25 AND s.atdate BETWEEN @FromDate AND @ToDate THEN s.adjlvbal ELSE 0 END) = 0
     AND SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveType IN (1,2,3,16) AND s.atdate BETWEEN @FourMonthStart AND @ToDate THEN IIF(s.LeaveTotalDays < 1, s.LeaveTotalDays, 1) ELSE 0 END) <= 4
    THEN CASE 
             WHEN e.gradeindex IN (53,54,56,59,60) THEN 2500
             WHEN e.gradeindex IN (55,61,57,58,62,63,64,65) THEN 2000
             ELSE 0
         END
    ELSE 0
END AS [Allowance Amount]
FROM tm_summary s
inner JOIN vwempdetail e ON e.employeeindex = s.employeeindex
WHERE 
    s.clientindex = 1236
    AND s.atdate BETWEEN @FourMonthStart AND @ToDate
    AND e.gradeindex IN (53,54,56,59,60,55,61,57,58,62,63,64,65)
    AND e.clientindex = 1236
    AND e.LocationIndex IN (12923,12924)
    AND e.positioncategory <> 46
GROUP BY 
    s.employeeindex,
    e.employeeid,
    e.employeename,
    e.locationname,
    e.gradeindex,
    e.Grade,
    e.positionname;
