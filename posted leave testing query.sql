Declare
    @ClientIndex int = 1361,           
    @FromDate date = '2025-02-01',            
    @ToDate date = '2025-03-04',      
    @UserEmpIndex int = 262663,          
    @Str varchar(max) = ''            
    -- select required data
;WITH ProcessByIndex AS (
    -- This CTE calculates userindex and employeeindex based on the length of ProcessBy
    SELECT 
			LH.LeaveIndex,
			(case when isnull(lh.ProcessBy,0) = 0 then 0 else (case when lh.ProcessBy < 33000 then lh.ProcessBy else 0 end  ) end ) UserIndex,
			(case when isnull(lh.UserEmpIndex,0) > 0 then UserEmpIndex else (case when isnull(lh.ProcessBy,0) > 33000 then lh.ProcessBy else 0 end  ) end ) EmployeeIndex,
            LH.ProcessDate,
            ROW_NUMBER() OVER (PARTITION BY LH.LeaveIndex ORDER BY LH.ProcessNo DESC) AS rn
    FROM LeaveHistory LH
    WHERE LH.LeaveIndex IN (SELECT LeaveIndex FROM LeaveDetail WHERE EmployeeIndex in 
	(select employeeindex from employee where clientindex = @ClientIndex ) and Fromdate between @fromdate and @todate)
	),
ProcessByNameget AS (
    -- This CTE joins ProcessByIndex with RegisteredUsers and Employee to get the names
    SELECT 
           PBI.LeaveIndex as Leaveindex, 
           CASE
               WHEN isnull(PBI.employeeindex,0) > 0 THEN E.EmployeeName
               WHEN isnull(PBI.userindex,0) > 0 THEN RU.Username
               ELSE NULL
           END AS ProcessByName,
           PBI.ProcessDate as ProcessDate
    FROM ProcessByIndex PBI
    LEFT JOIN RegisteredUsers RU
        ON PBI.userindex = RU.UserIndex 
    LEFT JOIN Employee E
        ON PBI.employeeindex = E.EmployeeIndex
    WHERE PBI.rn = 1
)
    -- Main query
SELECT 
        ROW_NUMBER() OVER (ORDER BY LD.EmployeeIndex) AS Sno, 
        LD.LeaveIndex,
        EE.employeeid,
        LD.EmployeeIndex,
        EE.EmployeeName,
        EE.TerritoryName,
		EE.Unitname,
		EE.Regionname,
		EE.LocationName,
		EE.DivisionName,
        EE.BUName,
        EE.DepartmentName,
        EE.SubDepartmentName,
        EE.PositionName,
        LC.LeaveDescription As 'Leave Type',
		FORMAT(LD.FromDate, 'yyyy-MM-dd | dddd') as 'From Date',
        FORMAT(LD.ToDate, 'yyyy-MM-dd | dddd') as 'To Date',
        LD.TotalDays,
        (case when LD.LeaveStatus = 1 then 'Pending Approval' 
			when LD.LeaveStatus in (2,3) then 'Approved' 
			when LD.LeaveStatus = 7 then 'Deducted' 
			when LD.LeaveStatus = 4 then 'Rejected' 
			when LD.LeaveStatus in (5,6) then 'Cancelled' Else '' End ) As 'Status', 
		LD.Reason,
		EEE.EmployeeiD as 'Applied By ID',
		EEE.Employeename as 'Applied By Name',
        LD.EntryDate AS 'Applied Date',
        PBN.ProcessByName AS 'ProcessedBy Name',
        PBN.ProcessDate As 'Processed Date'
FROM leavedetail LD
    INNER JOIN LeaveClientMapping LC ON LD.LeaveType = LC.LeaveType and LC.ClientIndex = @ClientIndex
    INNER JOIN vwempdetail EE ON LD.employeeindex = EE.employeeindex
	Left outer JOIN ProcessByNameget  PBN on LD.leaveindex = PBN.leaveindex
	INNER JOIN Employee EEE on LD.EntryBy = EEE.employeeindex
WHERE NOT (LD.leavetype = 9 AND LD.LeaveStatus = 12) AND EE.Clientindex = @ClientIndex AND LD.FromDate BETWEEN @FromDate AND @ToDate
    GROUP BY 
       	LD.LeaveIndex,EE.employeeid,LD.EmployeeIndex,EE.EmployeeName,EE.TerritoryName,EE.Unitname,
		EE.Regionname,EE.LocationName,EE.DivisionName,EE.BUName,EE.DepartmentName,EE.SubDepartmentName,
        EE.PositionName,LC.LeaveDescription,LD.FromDate,LD.todate,LD.TotalDays,LD.LeaveStatus,LD.Reason,
		EEE.EmployeeiD,EEE.Employeename,LD.EntryDate,PBN.ProcessByName,PBN.ProcessDate