declare
@Date date = getdate(),
@clientindex int = 1361,
@leavetype int = 3
SELECT 
    e.employeeid,
    lb.EmployeeIndex,
    e.employeename,
	e.PositionName,
	e.DepartmentName,
	e.SubDepartmentName,

    FORMAT(e.ServiceStartDate, 'MM/dd/yyyy') AS ServiceStartDate,
    FORMAT(e.sconfirmationdate, 'MM/dd/yyyy') AS ConfirmationDate,
	@date as 'Balance Till Date',
    lb.LeaveType,
    lcm.LeaveDescription,
    lb.Opening,
    lb.Entitlement,
    lb.TotalEntitlement,
    lb.Availed,
	lb.Adjusted,
	Lb.Balance,
    lb.Lapsed,
    lb.Closing
FROM 
    vwempdetail e
CROSS APPLY 
    fnleavebalance(e.EmployeeIndex, @Date) lb
inner JOIN 
    leaveclientmapping lcm
ON 
    lb.LeaveType = lcm.LeaveType and lcm.clientindex  = @clientindex
WHERE 
    e.ClientIndex = @clientindex and e.departmentindex in (14540,14537,14542,14603) and e.TerritoryIndex = 25150 and lb.LeaveType = @leavetype






declare
@ToDate date = getdate(),
@clientindex int = 1361,
@leavetype int = 3
declare @ToDateDate DATE = CAST(@ToDate AS DATE)
SELECT 
    e.employeeid as [Employee ID],
    lb.EmployeeIndex as [Employee Index],
    e.employeename as [Employee Name],
	e.DepartmentName as [Department Name],
	e.SubDepartmentName as [Sub Department],
	e.EmploymentType as [Employment Type],
	e.ServiceStatusDesc as [Service Status],
    FORMAT(e.ServiceStartDate, 'MM/dd/yyyy') AS [Service Start Date],
    isnull(FORMAT(e.sconfirmationdate, 'MM/dd/yyyy'),'-') AS [Confirmation Date],
    Case WHEN e.ServiceEndDate = '01/01/1900' THEN '-' ELSE FORMAT(e.ServiceEndDate, 'MM/dd/yyyy') END AS [Service End Date],
	isnull(FS.FSstatus,0) AS [FS Status],
	FORMAT(@ToDateDate, 'MMMM, yyyy') as [Balance Till Month],
    'Earned Leave' As [Leave Type],
    CASE when lb.Closing < 0 THEN 0 WHEN lb.Closing > 56 THEN 56.0 ELSE lb.Closing END AS [Closing Balance],
	e.CurrentGrossSalary as [Current Gross Salary],
	Round(CASE when lb.Closing < 0 THEN 0 WHEN lb.Closing > 56 THEN 56.0 ELSE lb.Closing END * (CAST(e.CurrentGrossSalary AS DECIMAL(18,2)) * 12) / 247,2) AS [Encashment Ammount]
FROM 
    vwempdetail e
CROSS APPLY 
    fnleavebalance(e.EmployeeIndex, @ToDateDate) lb
left outer join 
	FS_master FS on lb.EmployeeIndex = FS.EmployeeIndex
WHERE 
    e.ClientIndex = @clientindex and e.TerritoryIndex = 25150 and lb.LeaveType = @leavetype and isnull(FS.FSStatus,0) = 0
Order by 
	e.EmployeeIndex