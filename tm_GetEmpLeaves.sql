CREATE PROCEDURE [dbo].[tm_GetEmpLeaves]    
   
@EmployeeIndex as int,   
@LeaveType tinyint,
@LeaveStatus tinyint,
@FromDate Date,
@ToDate Date   
As    
 begin    
  select     
   ld.leaveindex LeaveIndex,    
   isnull(lcm.LeaveDescription,lt.LeaveDescription) LeaveType    
   , CONVERT(char ,ld.FromDate ,107) AppliedFromDate    
   , CONVERT(char ,ld.ToDate ,107) AppliedToDate      
   , ld.TotalDays AppliedDays    
   , CONVERT(char ,ld.FromDate ,107) ApprovedFromDate    
   , CONVERT(char ,ld.ToDate ,107) ApprovedToDate      
   , ld.TotalDays ApprovedDays    
   , ls.Description LeaveStatus    
   , ld.Reason Remarks    
   ,isnull(lh.remarks,'-') Nextremarks    
   from LeaveDetail ld, LeaveStatus ls, leavehistory lh, LeaveType lt, LeaveClientMapping Lcm    
   where ld.LeaveStatus=ls.LeaveStatus    
   and ld.LeaveType=lt.LeaveType    
   and EmployeeIndex=@EmployeeIndex    
   and lh.leaveindex = ld.leaveindex    
   and (lh.leavestatus = @LeaveStatus or @LeaveStatus=0)    
   and lh.processno in (select max(processno) from leavehistory lhh where ld.leaveindex = lhh.leaveindex and (LeaveStatus =@LeaveStatus or @LeaveStatus=0)  )    
   --and lt.LeaveType=@LeaveType    
   and lcm.ClientIndex in (select ClientIndex from Employee where EmployeeIndex=@EmployeeIndex)     
   and lcm.LeaveType=ld.LeaveType     
   and (lt.LeaveType = @LeaveType or @LeaveType=0)    
   and (ls.LeaveStatus=@LeaveStatus or @LeaveStatus=0)     
   and ld.fromdate between @FromDate and @ToDate    
 END    
return 




DECLARE 
    @EmployeeIndex INT = 215685,   
    @LeaveType TINYINT,
    @LeaveStatus TINYINT,
    @FromDate DATE = '2025-01-01',
    @ToDate DATE = '2025-03-28'


SET @LeaveType = ISNULL(@LeaveType, 0);
SET @LeaveStatus = ISNULL(@LeaveStatus, 0);

SELECT     
    ld.leaveindex AS LeaveIndex,    
    ISNULL(lcm.LeaveDescription, lt.LeaveDescription) AS LeaveType,    
    CONVERT(CHAR, ld.FromDate, 107) AS AppliedFromDate,    
    CONVERT(CHAR, ld.ToDate, 107) AS AppliedToDate,      
    ld.TotalDays AS AppliedDays,    
    CONVERT(CHAR, ld.FromDate, 107) AS ApprovedFromDate,    
    CONVERT(CHAR, ld.ToDate, 107) AS ApprovedToDate,      
    ld.TotalDays AS ApprovedDays,    
    ls.Description AS LeaveStatus,    
    ld.Reason AS Remarks,    
    ISNULL(lh.remarks, '-') AS NextRemarks    
FROM LeaveDetail ld
	LEFT JOIN LeaveStatus ls ON ld.LeaveStatus = ls.LeaveStatus    
	LEFT JOIN leavehistory lh ON lh.leaveindex = ld.leaveindex  
	LEFT JOIN LeaveType lt ON ld.LeaveType = lt.LeaveType    
	LEFT JOIN LeaveClientMapping Lcm ON ld.LeaveType = Lcm.LeaveType  
WHERE 
    ld.EmployeeIndex = @EmployeeIndex
    AND (@LeaveType = 0 OR ld.LeaveType = @LeaveType)  
    AND (@LeaveStatus = 0 OR ld.LeaveStatus = @LeaveStatus)  
    AND ld.FromDate BETWEEN @FromDate AND @ToDate  
    AND lh.processno = (SELECT ISNULL(MAX(processno), 0) FROM leavehistory lhh WHERE ld.leaveindex = lhh.leaveindex AND (@LeaveStatus = 0 OR lhh.LeaveStatus = @LeaveStatus))
    AND lcm.ClientIndex IN (SELECT ClientIndex FROM Employee WHERE EmployeeIndex = @EmployeeIndex);
