Declare 
@clientindex int = 1313,
@fromdate date = '2025-01-01',
@todate date = '2025-01-31'
Select ROW_NUMBER () Over (Order By s.EmployeeIndex) Sno,
EmployeeId,
S.Employeeindex,
EmployeeName,
Divisionname,
Locationname,
Departmentname,
UnitName,
PositionName 'Designation',
Grade,
ServiceStatusDesc,
DATEDIFF(day, @fromdate, @Todate) + 1 'Total Days',
SUM(Case When IsAbsent = 1 then 1 Else 0 End) 'Absent Days',
Sum(Case When IsAttendance = 1 and IsHoliday = 1 and IsGazetted = 0 then 1 Else 0 End)'Off Day Present',
Sum(Case When IsAttendance = 1 and IsHoliday = 1 and IsGazetted = 1 then 1 Else 0 End)'G.D.Present',
Isnull(Convert(float,Round(Sum(TotalWorkingHH*60+TotalWorkingMi)/60.0,2)),0)'Total Worked Hours',
Sum(Case When AdjLC > 0 and s.isleave = 0 then 1 Else 0 End)'Late Days',
Sum(Case When AdjEG > 0 and s.isleave = 0 then 1 Else 0 End)'Early Days',
Sum(Case When IsInvalid = 1 and IsHoliday !=1 then 1 Else 0 End)'Invalid Days',
SUM(Case When ld.LeaveStatus = 7 and ld.LeaveType = 5 then ld.totaldays Else 0 End) 'LWOP ded on Late',
SUM(ISNULL(CONVERT(FLOAT, ROUND((OThh*60+OTMi)/60.0,2)), 0)) 'Calculated OT',
SUM(ISNULL(CONVERT(FLOAT, ROUND((ApOThh*60+ApOTMi)/60.0,2)), 0)) 'Approved OT',
CAST(CONCAT(FLOOR(SUM(ApOTHH * 60 + ApOTMI) / 60),':', RIGHT(CONCAT('0', SUM(ApOTHH * 60 + ApOTMI) % 60), 2)) AS VARCHAR(10)) AS 'Late Siting Allowance',
SUM(Case When S.LeaveStatus = 2 and S.LeaveType = 5 then 1 Else 0 End) 'Approved LWOP'

from (tm_Summary S
left join VwEmpDetail E on S.EmployeeIndex = E.EmployeeIndex
LEFT outer Join LeaveDetail ld on ld.EmployeeIndex = S.EmployeeIndex and S.AtDate = ld.FromDate
)
Where S.ClientIndex = @clientindex and AtDate between @fromdate and @Todate
Group By s.EmployeeIndex,E.EmployeeId,EmployeeName,divisionname,locationname,Departmentname,UnitName,PositionName,Grade,ServiceStatusDesc
