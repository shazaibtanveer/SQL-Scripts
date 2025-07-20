DECLARE
    @Date DATE = GETDATE(),
	@Lastdate Date,
    @clientindex INT = 1361,
    @leavetype INT = 3;

select @Lastdate = DATEADD(MONTH,-3,@Date)
SELECT 
    e.employeeid,
    lb.EmployeeIndex,
    e.employeename,
    e.PositionName,
    e.DepartmentName,
    e.SubDepartmentName,
	e.LocationName,
	e.servicestatusdesc,
    FORMAT(e.ServiceStartDate, 'MM/dd/yyyy') AS ServiceStartDate,
    isnull(FORMAT(e.sconfirmationdate, 'MM/dd/yyyy'),'-') AS ConfirmationDate,
	case  WHEN e.ServiceEndDate IS NULL OR e.ServiceEndDate = '01/01/1900' THEN '-' ELSE FORMAT(e.ServiceEndDate, 'MM/dd/yyyy')  END AS ServiceEndDate,
	FORMAT(CASE WHEN e.ServiceStatus = 1 THEN @Date ELSE e.ServiceEndDate END,'MMMM, yyyy') AS [Balance Till Month],
    lcm.LeaveDescription,
    lb.Opening,
    lb.Entitlement,
    lb.TotalEntitlement,
    lb.Availed,
    lb.Adjusted,
    lb.Balance,
    lb.Lapsed,
    lb.Closing
FROM 
    vwempdetail e
CROSS APPLY 
    fnleavebalance(e.EmployeeIndex,CASE WHEN e.ServiceStatus = 1 THEN @Date ELSE e.ServiceEndDate END ) lb
INNER JOIN 
    leaveclientmapping lcm
    ON lb.LeaveType = lcm.LeaveType 
    AND lcm.clientindex = @clientindex
WHERE 
    e.ClientIndex = @clientindex 
    AND e.TerritoryIndex = 25150 
    AND lb.LeaveType = @leavetype
	AND (isnull(e.ServiceEndDate,'01/01/1900') = '01/01/1900' OR e.serviceenddate >= @Lastdate)
Order By
	lb.employeeindex

