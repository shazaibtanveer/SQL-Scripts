select @Allowance = isnull(sum( 
case 
when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) > 540 then ROUND(720 + ROUND((AdjOT - 9.0) * 120, 2), 2) 
when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) between 180 and 540 then 720 
when isholiday = 0 and round((ApOTHH*60+ApOTMI)/60 , 2) >= 0.5 then round(AdjOT * 120 , 2) 
when isleave = 1 and leavetype = 15 and leavestatus = 2 then 720 
else 0 end) ,0) 
from Tm_Summary s,Employee e 
where IsAttendance = 1 and e.BUindex = 153 and s.EmployeeIndex = e.EmployeeIndex 
and s.EmployeeIndex = [EmpIndex] and s.atdate between [Fromdate] and [Todate]









select @Allowance = isnull(sum( 
case 
when isholiday = 1 and isattendance = 1 and isnull(leavetype,0) <> 15 and round((ApOTHH*60+ApOTMI) , 2) > 540 then ROUND(720 + ROUND((AdjOT - 9.0) * 120, 2), 2) 
when isholiday = 1 and isattendance = 1 and isnull(leavetype,0) <> 15 and round((ApOTHH*60+ApOTMI) , 2) between 180 and 540 then 720 
when isholiday = 0 and isattendance = 1 and isnull(leavetype,0) <> 15 and round((ApOTHH*60+ApOTMI)/60 , 2) >= 0.5 then round(AdjOT * 120 , 2) 
when isholiday = 1 and isattendance = 1 and isnull(leavetype,0) = 15 and leavestatus = 2 and round((ApOTHH*60+ApOTMI) , 2) > 540 then ROUND(1440 + ROUND((AdjOT - 9.0) * 120, 2), 2) 
when isholiday = 1 and isattendance = 1 and isnull(leavetype,0) = 15 and leavestatus = 2 and round((ApOTHH*60+ApOTMI) , 2) between 180 and 540 then 1440 
when isholiday = 0 and isattendance = 1 and isnull(leavetype,0) = 15 and leavestatus = 2 and round((ApOTHH*60+ApOTMI)/60 , 2) >= 0.5 then round(AdjOT * 120 , 2) 
when isholiday = 0 and isattendance = 0 and isnull(leavetype,0) = 15 and leavestatus = 2 then 720 

else 0 end) ,0) 
from Tm_Summary s,Employee e 
where IsAttendance = 1 and e.BUindex = 153 and s.EmployeeIndex = e.EmployeeIndex 
and s.EmployeeIndex = [EmpIndex] and s.atdate between [Fromdate] and [Todate]

SELECT @Allowance = ISNULL(SUM(
CASE 
WHEN IsHoliday = 1 AND IsAttendance = 1 AND LeaveType <> 15 AND TotalMinutes > 540 THEN ROUND(720 + ROUND((AdjOT - 9.0) * 120, 2), 2)
WHEN IsHoliday = 1 AND IsAttendance = 1 AND LeaveType <> 15 AND TotalMinutes BETWEEN 180 AND 540 THEN 720 
WHEN IsHoliday = 0 AND IsAttendance = 1 AND LeaveType <> 15 AND TotalHours >= 0.5 THEN ROUND(AdjOT * 120, 2) 
WHEN IsHoliday = 1 AND IsAttendance = 1 AND LeaveType = 15 AND LeaveStatus = 2 AND TotalMinutes > 540 THEN ROUND(1440 + ROUND((AdjOT - 9.0) * 120, 2), 2)
WHEN IsHoliday = 1 AND IsAttendance = 1 AND LeaveType = 15 AND LeaveStatus = 2 AND TotalMinutes BETWEEN 180 AND 540 THEN 1440 
WHEN IsHoliday = 0 AND IsAttendance = 1 AND LeaveType = 15 AND LeaveStatus = 2 AND TotalHours >= 0.5 THEN ROUND(AdjOT * 120, 2) 
WHEN IsHoliday = 0 AND IsAttendance = 0 AND LeaveType = 15 AND LeaveStatus = 2 THEN 720 
ELSE 0 END), 0)
FROM (
    SELECT 
        s.EmployeeIndex,
        s.IsHoliday,
        s.IsAttendance,
        ISNULL(s.LeaveType, 0) AS LeaveType,
        s.LeaveStatus,
        ROUND((s.ApOTHH * 60 + s.ApOTMI), 2) AS TotalMinutes,
        ROUND((s.ApOTHH * 60 + s.ApOTMI) / 60, 2) AS TotalHours,
        s.AdjOT
    FROM Tm_Summary s
    INNER JOIN Employee e ON s.EmployeeIndex = e.EmployeeIndex
    WHERE e.BUIndex = 153 
    AND s.EmployeeIndex = @EmpIndex
    AND s.AtDate BETWEEN @FromDate AND @ToDate
) AS DerivedTable;
