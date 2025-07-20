
Alter procedure [dbo].[tm_LeavesAdj_Delete]

       @Clientindex int,    
       @Leaveindex int,    
       @UserEmpindex int    
    
	as 
       BEGIN    
             Declare @FromDate date, @ToDate date ,@LEmpIndex int   

			   
    select @LEmpIndex = EmployeeIndex from Leavedetail where LeaveIndex = @LeaveIndex    
  
           declare @lvemployeeindex as int, @leavetype as tinyint    
             select  @FromDate=fromdate, @ToDate=todate, @lvemployeeindex=employeeindex, @leavetype=LeaveType from LeaveDetail where LeaveIndex=@Leaveindex -- fromdate and todate selected by Jawad which was not passed to tm_summary previously    
    
			IF 
		--exists (select EmployeeIndex from tm_AtClosing where  EmployeeIndex=@LEmpIndex and Todate>=@FromDate)
		exists (select EmployeeIndex from tm_AtClosing where EmployeeIndex = @LEmpIndex and Todate>=@FromDate and Employeeindex not in 
		(select Employeeindex from employee e, clientmaster cm where e.ClientIndex = cm.ClientIndex and cm.IsBasedOnArears > 0))
             begin      
                raiserror('Attendance has been closed!',16,1)      
                return      
             end      
    
             update LeaveDetail set LeaveStatus = 6 where LeaveIndex = @Leaveindex    
           
             insert into LeaveHistory (LeaveIndex,ProcessNo,LeaveStatus,Remarks,UserEmpIndex,ProcessDate,MNo)    
             values (@Leaveindex,(Select  isnull(MAX(ProcessNo),0)+1 from LeaveHistory where LeaveIndex=@Leaveindex),6,'Leave Deleted through Master User',@UserEmpIndex,GETDATE(),null)    
    
           
        
    
             exec tm_Compleaves_ResetBalance  @LeaveIndex, 1--@UserIndex    
                 
             exec sp_leaves_calculation  @lvemployeeIndex, @LeaveType, @FromDate, 0, 1    
    
			 exec todo_Main_Delete @lvemployeeindex, 1, @LeaveIndex, 1, 0, @UserEmpIndex
             ---Leave Refresh in Attendance---------    
             exec tm_Summary_Refresh @ClientIndex,@FromDate,@ToDate,@lvemployeeIndex,0,0,0,0,0,0,0,0,1    
             ---Leave Refresh in Attendance---------    
    
       END    
return    
