
--go
--alter table clientplanattendance add IsCorrectBalanceHR tinyint
--go

Alter procedure [dbo].[tm_Leaves_EmpSummaryUE]
	@FromDate datetime,
	@LeaveType tinyint,
	@EmployeeIndex int,
	@UserEmpIndex int
as
	begin

		declare @ClientIndex int, @HideBalance tinyint = 0

		select  @ClientIndex=Clientindex from Employee where EmployeeIndex =@EmployeeIndex 
		declare @ExtendPlan tinyint=0    
    
		if exists (select employeeindex from EmpLeaveExtendPlan where EmployeeIndex=@EmployeeIndex)    
		set @ExtendPlan=1 
		
		declare @IsCorrectBalanceHR int = 0
		select @IsCorrectBalanceHR = isnull(IsCorrectBalanceHR,0) from clientplanattendance where clientindex = @clientindex
  
		select	@HideBalance=isnull(lr.HideBalance,0)
		from	LeaveRules lr , Employee e 
		where	e.ClientIndex=lr.ClientIndex
				and lr.lvGroup=e.lvGroup
				and e.EmployeeIndex=@EmployeeIndex
				and lr.LeaveType=@LeaveType
		declare @TotalEntitlement float=0    
    
		select @TotalEntitlement=totalentitlement     
		from dbo.fnLeaveBalance(@EmployeeIndex, @FromDate)     
		where leavetype=@LeaveType 

if exists ( select IsCorrectBalanceHR from ClientPlanAttendance where ClientIndex = @ClientIndex and IsCorrectBalanceHR = 1 )
		begin
				Select datename(mm, lp.PayrollMonth) + ' ' + ltrim(str(year(lp.payrollmonth))) 'Month', 
				round(lp.Availed,2) 'Availed', 
				round(lp.Encashed,2) 'Encashed', 
				round(lp.Adjusted,2) 'Deducted', 
				   (    
				case     
					when @ExtendPlan=0    
					then isnull(@TotalEntitlement,0) - isnull(lp.runningAvailed,0)      
					else  round(lp.Balance,2)     
				end     
				) 'Balance' 
				From EmpLeavePlan lp, leavetype lt, fnLeavePeriod(@EmployeeIndex, @FromDate) t
				Where lp.employeeindex=@EmployeeIndex
				and lp.PayrollMonth between t.FromDate  and t.ToDate
				and t.LeaveType=lt.LeaveType
				and lp.LeaveType=@LeaveType and lp.LeaveType=lt.LeaveType
		end
	Else
		if @HideBalance=1 and @iscorrectBalanceHR = 0
			Begin
				Select datename(mm, lp.PayrollMonth) + ' ' + ltrim(str(year(lp.payrollmonth))) 'Month', 
				round(lp.Availed,2) 'Availed', 
				round(lp.Encashed,2) 'Encashed', 
				round(lp.Adjusted,2) 'Deducted' 
				From EmpLeavePlan lp, leavetype lt, fnLeavePeriod(@EmployeeIndex, @FromDate) t
				Where lp.employeeindex=@EmployeeIndex
				and lp.PayrollMonth between t.FromDate  and t.ToDate
				and t.LeaveType=lt.LeaveType
				and lp.LeaveType=@LeaveType and lp.LeaveType=lt.LeaveType
			end
		else 
			Begin
				Select datename(mm, lp.PayrollMonth) + ' ' + ltrim(str(year(lp.payrollmonth))) 'Month', 
				round(lp.Availed,2) 'Availed', 
				round(lp.Encashed,2) 'Encashed', 
				round(lp.Adjusted,2) 'Deducted',
				round(lp.Balance,2) 'Balance'  
				From EmpLeavePlan lp, leavetype lt, fnLeavePeriod(@EmployeeIndex, @FromDate) t
				Where lp.employeeindex=@EmployeeIndex
				and lp.PayrollMonth between t.FromDate  and t.ToDate
				and t.LeaveType=lt.LeaveType
				and lp.LeaveType=@LeaveType and lp.LeaveType=lt.LeaveType
			End
	End		
Return