Declare
@clientindex int = 1361,
@Fromdate date = '2024-09-21',
@todate date = '2024-11-8'

if EXISTS (select 1 from LeaveDetail where leavetype = 9 and LeaveStatus = 12 and employeeindex in (select employeeindex from employee where clientindex  =  @clientindex) and fromdate between @Fromdate and @todate )
begin (
select E.employeeid,
LD.employeeindex,
e.employeename,
e.LocationName,
e.DepartmentName,
e.subdepartmentname,
LCM.LeaveDescription,
FORMAT(LD.Fromdate, 'yyyy-MM-dd (dddd)') As 'InLieu Against',
LD.TotalDays,
LD.Reason,
LD.EntryDate
from LeaveDetail LD
inner join VwEmpDetail e on LD.employeeindex  = E.EmployeeIndex
inner join leaveclientmapping LCM on LD.LeaveType = LCM.leavetype and LCM.ClientIndex = @clientindex
where LD.employeeindex in (select employeeindex from employee where clientindex  = @clientindex) and LD.leavetype = 9 
and LD.LeaveStatus = 12 and LD.FromDate between @Fromdate and @todate)
end

else 

begin (
select e.employeeid,
lob.employeeindex,
e.employeename,
e.unitname,
e.Locationname,
e.DepartmentName,
e.grade,
lob.LOBIndex,
lcm.LeaveDescription,
FORMAT(lob.Fromdate,
'yyyy-MM-dd (dddd)') As 'CPL Start Date',
FORMAT(lob.ToDate,
'yyyy-MM-dd (dddd)') As 'CPL Expire Date',
lob.Allowed,
case when lob.todate <  getdate() then 'Expired' Else 'Avaiable' end,
lob.Remarks,
lob.PostDate
from LeaveOtherBalance lob inner join vwempdetail e on lob.EmployeeIndex = e.EmployeeIndex
inner join LeaveClientMapping lcm on lob.LeaveType = lcm.LeaveType
where lob.EmployeeIndex in (select employeeindex from employee where clientindex  =  @clientindex) and lcm.ClientIndex = @clientindex 
and lob.Fromdate between @fromdate and @Todate) order by lob.PostDate desc
end