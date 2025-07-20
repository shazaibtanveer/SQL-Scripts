USE [Decibel_Development]
GO

/****** Object:  StoredProcedure [dbo].[sp_Leaves_Draft]    Script Date: 1/7/2025 1:27:37 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


Alter procedure [dbo].[sp_Leaves_Draft]  
	@UserIndex int,  
	@EmployeeIndex int
as  
	Declare @LanguageIndex tinyint = 1
    ---For Sapphire urdu Kiosk -----------    
	
	if exists (select * from employee where employeeindex = @EmployeeIndex and lower(ltrim(rtrim(OtherDetail3))) = 'urdu')
		Set  @LanguageIndex  = 3
	---For Sapphire urdu Kiosk -----------
  
	if @EmployeeIndex>0   
		begin
				declare @LMName nvarchar(50)='', @LM2Name nvarchar(50)=''

				select	@LMName= ' (' + isnull(lm1.EmployeeName,'') + ')', @LM2Name= ' (' + isnull(lm2.EmployeeName,'') + ')' 
				from	Employee e
						left outer join Employee lm1 on e.LMIndex=lm1.EmployeeIndex
						left outer join Employee lm2 on e.LM2Index=lm2.EmployeeIndex
				where	e.ClientIndex=1313
						and e.EmployeeIndex=@EmployeeIndex

	
			  Select LD.LEAVEINDEX 'Leave Index', E.EMPLOYEENAME 'Employee Name', 
					case when @LanguageIndex = 3 then isnull(isnull(lcm.Additionaltext,lcm.leavedescription),lt.LeaveDescription) else isnull(lcm.leavedescription,lt.LeaveDescription) end  'Leave Type', 
					ltrim(rtrim(CONVERT(char, fromdate, 107))) 'From Date', ltrim(rtrim(CONVERT(char, todate, 107))) 'To Date', TotalDays 'Total Days', ld.Reason, ISNULL(ld.address,'') 'Address', ISNULL(ld.contactno,'') 'Contact No.' ,ISNULL(ld.contactPerson,'') 'Contact Person' , 
					lss.Description +  (case when isnull(ld.LeaveSubStatus,0)=1 then @LMName else @LM2Name end )  'Leave Status'
					,isnull(ld.LeaveSubStatus,0) LSS, ld.leavetype LT  
			  from   Employee e, LeaveDetail ld left outer join LeaveSubStatus lss on lss.leavesubstatus=ld.leavesubstatus,  
					 LeaveType lt , leaveclientmapping lcm  
			  where  e.EmployeeIndex = ld.EmployeeIndex 
			  And (case when isnull(ld.oLeaveType,0)>0 then ld.oLeaveType else ld.LeaveType end) = lt.LeaveType   
			  and ld.leavestatus=1 and isnull(ld.leaveencashment,0)=0 and e.EmployeeIndex=@EmployeeIndex  
			  and lcm.ClientIndex=e.ClientIndex   
			  and lcm.leavetype=lt.leavetype    
			  and LeaveIndex not in (select LeaveIndex from LeavePlanner)   
			  order by Convert(date,ld.FromDate) desc --order by FromDate for engro  
		end
	else  
	begin
		  Select LD.LEAVEINDEX 'Leave Index', E.EMPLOYEENAME 'Employee Name', case when @LanguageIndex = 3 then isnull(isnull(lcm.Additionaltext,lcm.leavedescription),lt.LeaveDescription) else isnull(lcm.leavedescription,lt.LeaveDescription) end  'Leave Type', ltrim(rtrim(CONVERT(char, fromdate, 107))) 'From Date', ltrim(rtrim(CONVERT(char, todate, 107))) 'To Date', TotalDays 'Total Days', ld.Reason, ISNULL(ld.address,'') 'Address', ISNULL(ld.contactno,'') 'Contact No.',ISNULL(ld.contactPerson,'') 'Contact Person' , lss.Description 'Leave Status'  
		  from   Employee e, LeaveDetail ld left outer join LeaveSubStatus lss on lss.leavesubstatus=ld.leavesubstatus,  
				 LeaveType lt, registeredusers ru , leaveclientmapping lcm  
		  where  e.EmployeeIndex = ld.EmployeeIndex And (case when isnull(ld.oLeaveType,0)>0 then ld.oLeaveType else ld.LeaveType end)= lt.LeaveType   
		  and ld.leavestatus=1 and isnull(ld.leaveencashment,0)=0 and e.EmployeeIndex=ru.employeeindex  
		  and ru.userindex=@UserIndex  
		  and lcm.ClientIndex=e.ClientIndex   
		  and lcm.leavetype=lt.leavetype  
		  and LeaveIndex not in (select LeaveIndex from LeavePlanner)  
		  order by Convert(date,ld.FromDate) desc --order by FromDate for engro  
	end
return  
GO


