CREATE Procedure [dbo].[tm_Adj_SetStatus]    
				@AdjIndex int,     
				@AdjStatus tinyint,    
				@Remarks varchar(100),    
				@UserEmpIndex int   

				As

				--declare  
				-- @AdjIndex int = 360333,   
				-- @AdjStatus tinyint = 4,  
				-- @Remarks varchar(100) = '',  
				-- @UserEmpIndex int = 210095 
			  
				 Begin  
  
				  declare @EmployeeIndex int, @AtDate datetime, @CurrentAdjStatus tinyint  
  
				  declare @LC float,  
					@EG float,  
					@UW float,  
					@Brk float,  
					@LvLC float,  
					@LvEG float,  
					@LvUW float,  
					@LvBrk float  
  
  
				  set @LC = 0  
				  set @EG = 0  
				  set @UW = 0  
				  set @Brk = 0  
				  set @LvLC = 0  
				  set @LvEG = 0  
				  set @LvUW = 0  
				  set @LvBrk = 0  
  
  
				  select @EmployeeIndex=EmployeeIndex,   
					@AtDate = AdjDate,  
					@LvLC = TotalDays ,  
					@CurrentAdjStatus = isnull(AdjStatus,0)  
				  from tm_Adj   
				  where AdjIndex=@AdjIndex   
  
				  --Changes by Jawad As per Hashoo Requirement 2020-12-23-------------------  
				  Declare @IsAtClosingByPass tinyint = 0 ,@Clientindex smallint   
  
				  select @Clientindex = Clientindex from employee where employeeindex = @EmployeeIndex  
				  select @IsAtClosingByPass = isnull(IsAtClosingByPass,0) from clientplan where clientindex = @Clientindex   
				  --Changes by Jawad As per Hashoo Requirement 2020-12-23 -------------------  
  


				  if exists (select 1 from tm_AtClosing where EmployeeIndex=@EmployeeIndex and Todate>=@AtDate) and @IsAtClosingByPass = 0  
				  begin  
				   raiserror('Attendance has been closed!',16,1)  
				   return  
				  end  
  
				  begin transaction  
  
  
				  update tm_Adj set AdjStatus=@AdjStatus   
				  where AdjIndex=@AdjIndex   
				  if @@ERROR<>0  
				  begin  
				   rollback transaction  
				   return  
				  end  
  
  
				  insert into tm_AdjHistory (AdjIndex, HNo, AdjStatus, Remarks, UserEmpIndex, EntryDate )  
				  select @AdjIndex , (select isnull(MAX(hno),0)+1 from tm_AdjHistory where AdjIndex=@AdjIndex ), @AdjStatus , @Remarks, @UserEmpIndex, GETDATE()  
				  if @@ERROR<>0  
				  begin  
				   rollback transaction  
				   return  
				  end  
  
				  if @AdjStatus=3   
				  begin  
				   declare @AdjLC float, @AdjEG float, @AdjUW float, @AdjBrk float  
				   declare @AdjLvLC float, @AdjLvEG float, @AdjLvUW float, @AdjLvBrk float  
  
				   select @AdjLC=AdjLC,  
					 @AdjEG=AdjEG,  
					 @AdjUW=AdjUW,  
					 @AdjBrk=AdjBrk,  
       
					 @AdjLvLC=AdjLvLC,  
					 @AdjLvEG=AdjLvEG,  
					 @AdjLvUW=AdjLvUW,  
					 @AdjLvBrk=AdjLvBrk  
				   from tm_Summary   
				   where EmployeeIndex=@EmployeeIndex and AtDate=@AtDate  
  
  
  
				   if exists (select * from tm_SummaryAdj where EmployeeIndex=@EmployeeIndex and AtDate=@AtDate)  
					begin  
					 update tm_SummaryAdj  
					 set  AdjLC=@LC,  
					   AdjEG=@EG,  
					   AdjUW=@UW,  
					   AdjBrk=@Brk,  
					   AdjLvLC=@LvLC,  
					   AdjLvEG=@LvEG,  
					   AdjLvUW=@LvUW,  
					   AdjLvBrk=@LvBrk,  
					   RecordDate=GETDATE()  
  
					 where EmployeeIndex=@EmployeeIndex  
					   and AtDate=@AtDate  
					 if @@Error<>0  
					 begin  
					  rollback transaction  
					  return  
					 end  
					end   
				   else  
					begin  
					 insert into tm_SummaryAdj (AtDate, EmployeeIndex, AdjLC, AdjEG, AdjUW, AdjBrk, AdjLvLC , AdjLvEG, AdjLvUW, AdjLvBrk, RecordDate  )  
					 values (@AtDate, @EmployeeIndex, @LC, @EG, @UW, @Brk, @LvLC , @LvEG, @LvUW, @LvBrk , GETDATE() )  
					 if @@Error<>0  
					 begin  
					  rollback transaction  
					  return  
					 end  
					end  
  
  
				   insert into tm_SummaryAdjHistory (AtDate, EmployeeIndex, HNo, LC, EG, UW, Brk, LvLC, LvEG, LvUW, LvBrk, AdjLC, AdjEG, AdjUW, AdjBrk, AdjLvLC , AdjLvEG, AdjLvUW, AdjLvBrk, RecordDate, Remarks,  UserEmpIndex, UpdateDate, AdjIndex)  
				   select @AtDate, @EmployeeIndex, (select isnull(max(hno),0)+1 from tm_SummaryAdjHistory where EmployeeIndex=@EmployeeIndex and AtDate=@AtDate), @LC, @EG, @UW, @Brk, @LvLC, @LvEG, @LvUW, @LvBrk, @AdjLC, @AdjEG, @AdjUW, @AdjBrk, @AdjLvLC , @AdjLvEG, @AdjLvUW, @AdjLvBrk, getdate(), @Remarks, @UserEmpIndex, getdate(), @AdjIndex   
				   if @@Error<>0  
				   begin  
					rollback transaction  
					return  
				   end  
  
				  end  
  
  
				  if @AdjStatus=4 and @CurrentAdjStatus <> 4  
				  begin  
					declare @LeaveType tinyint  
					declare @AdjRuleIndex int  
					declare @AdjustLeaves float = @LvLC  
  
  
  
					select @AdjRuleIndex = ab.AdjRuleIndex    
					from tm_adj a, tm_AdjBatch ab   
					where a.employeeindex=@EmployeeIndex   
					  and a.AdjBatchIndex = ab.AdjBatchIndex   
					  and AdjIndex = @AdjIndex  
  
					if (@AdjRuleIndex is null or @AdjRuleIndex = 0)  
					 begin  
					  select @AdjRuleIndex  = AdjRuleIndex from tm_VwEmpAdjRule where employeeindex = @EmployeeIndex  
					 end  



  
					--exec tm_Summary_GetLeaveType @AdjRuleIndex,@EmployeeIndex, @AtDate, @AdjustLeaves, @LeaveType output  
					--if @@ERROR<>0  
					--begin  
					-- rollback transaction  
					-- return  
					--end  
       
					--if @LeaveType is null   
					--begin  
					-- set @LeaveType=5  
					-- --declare @Msg as varchar(50)  
					-- --set @Msg = '* Leave Type Not Found For [' + ltrim(str(@EmployeeIndex)) + '] As On ' + convert(char,@AtDate ,107)  
					-- --rollback transaction  
					-- --raiserror (@Msg, 16,1)  
					-- --return  
					--end  
            
					--insert into LeaveDetail (LeaveIndex, EmployeeIndex, LeaveType, SerialNo, FromDate, ToDate, TotalDays, Reason, LeaveStatus, LeaveEncashment, LeaveAdjustment, UserEmpIndex, EntryDate )  
					--select (select isnull(MAX(LeaveIndex),0)+1 from LeaveDetail ), @EmployeeIndex, @LeaveType, 1, @AtDate, @AtDate, @AdjustLeaves, 'Attendance Adjustment', 7,0,0, @UserEmpIndex,GETDATE()  
					--if @@ERROR<>0  
					--begin  
					-- rollback transaction  
					-- return  
					--end  
  
					----insert into @T (EmployeeIndex, LeaveType) values (@EmployeeIndex, @LeaveType)  
					--exec sp_Leaves_Calculation  @EmployeeIndex, @LeaveType, @AtDate , 0,  1  

				
				if @Clientindex not in (1163,1161,1269)
				 begin  
  
				  exec tm_Summary_GetLeaveType @AdjRuleIndex,@EmployeeIndex, @AtDate, @AdjustLeaves, @LvType = @LeaveType output    
				  if @@ERROR<>0    
				  begin    
				   rollback transaction    
				   return    
				  end    
  
  
				  if @LeaveType is null     
				  begin    
				   set @LeaveType=5    
				  end    
  
				  --update tm_adj set adjstatus = 2 where employeeindex = 268096 and adjdate >= '2022-06-01' and adjdate = '2022-06-14'  
  
  
            
				  insert into LeaveDetail (LeaveIndex, EmployeeIndex, LeaveType, SerialNo, FromDate, ToDate, TotalDays, Reason, LeaveStatus, LeaveEncashment, LeaveAdjustment, EntryBy, EntryDate )    
				  select (select isnull(MAX(LeaveIndex),0)+1 from LeaveDetail ), @EmployeeIndex, @LeaveType, 1, @AtDate, @AtDate, @AdjustLeaves, 'Attendance Adjustment', 7,0,0,@Userempindex,GETDATE()    
				  if @@ERROR<>0    
				  begin    
				   rollback transaction    
				   return    
				  end    
  
				  exec sp_Leaves_Calculation  @EmployeeIndex, @LeaveType, @AtDate , 0,  1    
  
				 end  
				else  
				 begin  
				  --------------------  
				  ---- Post Leaves ---  
				  declare @rAdjustLeaves float = @AdjustLeaves  
				  declare @LeaveBalance float=0  
  
				  while @rAdjustLeaves>0  
				  begin  
				   set @LeaveType = null  
				   set @LeaveBalance = null  
  
				   exec tm_Summary_GetLeaveTypeUmair @AdjRuleIndex,@EmployeeIndex, @AtDate, @rAdjustLeaves, @LvType = @LeaveType output, @LvBal = @LeaveBalance output    
				   if @@ERROR<>0    
				   begin    
					rollback transaction    
					return    
				   end    
  
				   set @LeaveBalance = isnull(@LeaveBalance,0)  
  
				   if @rAdjustLeaves>@LeaveBalance   
					begin  
					 set @rAdjustLeaves = @rAdjustLeaves - @LeaveBalance  
					 set @AdjustLeaves = @LeaveBalance  
					end  
				   else  
					begin  
					 set @AdjustLeaves=@rAdjustLeaves  
					 set @rAdjustLeaves = 0  
					end  
  
				   if @LeaveType is null     
				   begin    
					set @LeaveType=5    
					set @AdjustLeaves=@rAdjustLeaves  
					set @rAdjustLeaves = 0  
				   end    
  
				   --update tm_adj set adjstatus = 2 where employeeindex = 268096 and adjdate >= '2022-06-01' and adjdate = '2022-06-14'  
  
  
            
				   insert into LeaveDetail (LeaveIndex, EmployeeIndex, LeaveType, SerialNo, FromDate, ToDate, TotalDays, Reason, LeaveStatus, LeaveEncashment, LeaveAdjustment, EntryBy, EntryDate )    
				   select (select isnull(MAX(LeaveIndex),0)+1 from LeaveDetail ), @EmployeeIndex, @LeaveType, 1, @AtDate, @AtDate, @AdjustLeaves, 'Attendance Adjustment', 7,0,0,@Userempindex,GETDATE()    
				   if @@ERROR<>0    
				   begin    
					rollback transaction    
					return    
				   end    
  
				   exec sp_Leaves_Calculation  @EmployeeIndex, @LeaveType, @AtDate , 0,  1    
  


						  end  
						  end
						  end
  
				  commit transaction  
  
  
				  exec tm_Summary_SetEmp @AtDate, @EmployeeIndex, 0, @UserEmpIndex  
  
				 End  
				Return

