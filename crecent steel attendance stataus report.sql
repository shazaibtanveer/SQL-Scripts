declare
    @ClientIndex INT = 1395,           
    @FromDate NVARCHAR(10) = '2025-03-26',            
    @ToDate NVARCHAR(10) = '2025-04-25'        

    -- Initialize the #Emp temp table
    IF OBJECT_ID('tempdb.dbo.#Emp', 'U') IS NOT NULL  
        DROP TABLE #Emp;
    CREATE TABLE #Emp (EmployeeIndex INT);
        INSERT INTO #Emp (EmployeeIndex)
        SELECT employeeindex
        FROM employee
        WHERE clientindex = @ClientIndex 
  AND (
        ISNULL(ServiceEndDate, '01/01/1900') = '01/01/1900' 
        OR ISNULL(ServiceEndDate, '01/01/1900') >= '03/25/2025'
      )
     

Declare @TotalDays INT = DATEDIFF(DAY, @fromdate, @Todate) + 1;
--Late & Early Deductions
With LateEarlyded AS (
SELECT 
    EmployeeIndex,
    sum(TotalDays) AS LateArivalcalculation
FROM (
    SELECT 
		EmployeeIndex,
		CASE WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 2 THEN 1 ELSE 0 END AS TotalDays
    FROM tm_summary
    WHERE ClientIndex = @ClientIndex 
      AND AtDate BETWEEN @FromDate AND @ToDate 
      AND (AdjLC > 0 or Adjeg > 0)
      AND AdjLvBal NOT IN (0.5, 1)
) t
GROUP BY EmployeeIndex
)
-- Final SELECT
SELECT 
ROW_NUMBER() OVER (ORDER BY s.EmployeeIndex) AS Sno,
e.EmployeeId,
s.EmployeeIndex,
e.EmployeeName,
e.LocationName,
e.DepartmentName,
e.PositionName AS Designation,
e.Grade,
e.ServiceStatusDesc,
e.ServiceStartDate,
e.ServiceEndDate,
@FromDate AS FromDate,
@ToDate AS ToDate,
@TotalDays AS 'Total Days',
ISNULL((
    SUM(CASE WHEN s.IsAbsent = 1 THEN 1 ELSE 0 END) +
    SUM(CASE WHEN s.LeaveStatus IN (2,7) AND s.LeaveType = 5 THEN 1 
             WHEN ld.LeaveStatus = 7 AND ld.LeaveType = 5 THEN 1 ELSE 0 END) +
    SUM(CASE WHEN s.LeaveStatus = 1 AND s.LeaveTotalDays > 0.5 THEN 1 ELSE 0 END) +
    SUM(s.AdjLvBal)
), 0) AS 'Total Deductions',
@TotalDays - ISNULL((
    SUM(CASE WHEN s.IsAbsent = 1 THEN 1 ELSE 0 END) +
    SUM(CASE WHEN s.LeaveStatus IN (2,7) AND s.LeaveType = 5 THEN 1 
             WHEN ld.LeaveStatus = 7 AND ld.LeaveType = 5 THEN 1 ELSE 0 END) +
    SUM(CASE WHEN s.LeaveStatus = 1 AND s.LeaveTotalDays > 0.5 THEN 1 ELSE 0 END) +
    SUM(s.AdjLvBal)
), 0) AS 'Total Paid Days',
SUM(CASE WHEN s.IsAttendance = 1 AND s.IsHoliday = 0 THEN 1 ELSE 0 END) AS 'Work Days',
SUM(CASE WHEN s.IsAttendance = 1 THEN 1 ELSE 0 END) AS 'Present Days',
SUM(CASE WHEN s.IsAbsent = 1 THEN 1 ELSE 0 END) AS 'Absent Days',
SUM(CASE WHEN s.IsAttendance = 0 AND s.IsHoliday = 1 AND s.IsGazetted = 0 THEN 1 ELSE 0 END) AS 'Off Days',
SUM(s.IsGazetted) AS 'Gazetted Days',
SUM(CASE WHEN s.IsAttendance = 1 AND s.IsHoliday = 1 AND s.IsGazetted = 0 THEN 1 ELSE 0 END) AS 'Off Day Present',
SUM(CASE WHEN s.IsAttendance = 1 AND s.IsHoliday = 1 AND s.IsGazetted = 1 THEN 1 ELSE 0 END) AS 'G.D. Present',
SUM(Case when isholiday = 0 then ISNULL(CONVERT(FLOAT, ROUND((OThh*60+OTMi)/60.0,2)), 0) else 0 end) 'Calculated OT WD',
SUM(Case when isholiday = 1 and IsGazetted = 0 then ISNULL(CONVERT(FLOAT, ROUND((OThh*60+OTMi)/60.0,2)), 0) else 0 end) 'Calculated OT OD',
SUM(Case when isholiday = 1 and IsGazetted = 1 then ISNULL(CONVERT(FLOAT, ROUND((OThh*60+OTMi)/60.0,2)), 0) else 0 end) 'Calculated OT GD',
Isnull(Convert(float,Round(Sum(OThh*60+OTMi)/60.0,2)),0) 'Total Calculated OT',
ISNULL(ROUND(SUM(s.StandardHH * 60 + s.StandardMi) / 60.0, 2), 0) AS 'Entitled W.Hours',
ISNULL(ROUND(SUM(s.TotalWorkingHH * 60 + s.TotalWorkingMi) / 60.0, 2), 0) AS 'Worked Hrs',
SUM(CASE WHEN s.IsAttendance = 1 AND s.IsHoliday = 0 AND s.IsInvalid = 1 THEN 1 ELSE 0 END) AS 'Total Invalid',
SUM(CASE WHEN s.IsAttendance = 1 AND s.IsHoliday = 0 AND s.IsIrregular = 1 THEN 1 ELSE 0 END) AS 'Total Irregular',
SUM(CASE WHEN s.IsAttendance = 1 AND s.IsLC = 0 AND s.IsEG = 0 AND s.AdjLvBal = 0 AND s.IsHoliday = 0 THEN 1 ELSE 0 END) AS 'On-Time Count', 
SUM(CASE WHEN s.AdjLC > 0 AND s.AdjLvLC = 0 THEN 1 ELSE 0 END) AS 'Late Days',
SUM(CASE WHEN s.AdjEG > 0 AND s.AdjLvEG = 0 THEN 1 ELSE 0 END) AS 'Early Days',
ISNULL(led.LateArivalcalculation, 0) AS 'Late Arival Calulation',
Sum(s.adjlc) AS 'Late Hours',
Sum(s.AdjEG) AS 'Early Hours',
Sum(s.adjlc) + Sum(s.AdjEG) AS 'Total Short Hours',
SUM(CASE WHEN s.AdjLvBal = 0.5 THEN 0.5 ELSE 0 END) AS 'Half Day Ded',
SUM(CASE WHEN s.AdjLvBal = 1 THEN 1 ELSE 0 END) AS 'Full Day Ded',
SUM(s.AdjLvBal) AS 'Tot. Late/Early Ded',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType <> 5 THEN 1 ELSE 0 END) AS 'Approved/Paid Lv.',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 1 THEN 1 ELSE 0 END) AS 'Unapproved Lv.',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType = 5  THEN CASE WHEN s.LeaveTotalDays >= 1 THEN 1 ELSE s.LeaveTotalDays END ELSE 0 END) AS 'LWOP',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType = 1  THEN CASE WHEN s.LeaveTotalDays >= 1 THEN 1 ELSE s.LeaveTotalDays END ELSE 0 END) AS 'Casual',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType = 2  THEN CASE WHEN s.LeaveTotalDays >= 1 THEN 1 ELSE s.LeaveTotalDays END ELSE 0 END) AS 'Sick',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType = 3  THEN CASE WHEN s.LeaveTotalDays >= 1 THEN 1 ELSE s.LeaveTotalDays END ELSE 0 END) AS 'Annual',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType = 4  THEN CASE WHEN s.LeaveTotalDays >= 1 THEN 1 ELSE s.LeaveTotalDays END ELSE 0 END) AS 'Maternity',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType = 9  THEN CASE WHEN s.LeaveTotalDays >= 1 THEN 1 ELSE s.LeaveTotalDays END ELSE 0 END) AS 'Compensatory',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType = 20 THEN CASE WHEN s.LeaveTotalDays >= 1 THEN 1 ELSE s.LeaveTotalDays END ELSE 0 END) AS 'On Duty',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType = 34 THEN CASE WHEN s.LeaveTotalDays >= 1 THEN 1 ELSE s.LeaveTotalDays END ELSE 0 END) AS 'Accident',
SUM(CASE WHEN s.IsLeave = 1 AND s.LeaveStatus = 2 AND s.LeaveType = 41 THEN CASE WHEN s.LeaveTotalDays >= 1 THEN 1 ELSE s.LeaveTotalDays END ELSE 0 END) AS 'Short'

FROM tm_Summary s
JOIN VwEmpDetail e ON s.EmployeeIndex = e.EmployeeIndex
LEFT JOIN LeaveDetail ld ON ld.EmployeeIndex = s.EmployeeIndex AND s.AtDate = ld.FromDate
LEFT JOIN LateEarlyded led ON s.EmployeeIndex = led.EmployeeIndex
WHERE s.ClientIndex = @ClientIndex AND s.AtDate BETWEEN @FromDate AND @ToDate and  S.EmployeeIndex IN (SELECT EmployeeIndex FROM #Emp)
GROUP BY 
    s.EmployeeIndex, e.EmployeeId, e.EmployeeName, e.LocationName, e.DepartmentName, e.ServiceStartDate,e.ServiceEndDate,
    e.PositionName, e.Grade, e.ServiceStatusDesc, 
    led.LateArivalcalculation
    -- Clean up
    DROP TABLE #Emp;
