
Alter procedure [dbo].[tm_Leaves_Application]                  
  @UserId char(20),                    
   @EmployeeIndex int,                    
   @FromDate datetime,                    
   @ToDate datetime,                    
   @LeaveType tinyint,                    
   @LeaveEncashment tinyint,                    
   @LeaveAdjustment tinyint,                    
   @TotalDays float,                    
   @Reason varchar(100),                    
   @Address varchar(100),                    
   @ContactNo varchar(20),                    
   @ContactPerson varchar(100),                    
   @RulesByPass tinyint , -- = 0 ,                    
   @AdvanceDays float , -- = 0 ,                    
   @EncashType tinyint = 1,                    
   @EncashDays float = 0,                    
   @EncashRemarks varchar(100) = '',                    
   @ShortDay float = 0,                    
   @RulesByPassForcibly tinyint=0 , --=0                    
   @oLeaveType tinyint =0, -- Original Leave Type,                    
   @IsDraft tinyint = 0,                    
   @DLeaveIndex int = 0,                   
   @LeaveCat tinyint=0,                   
   @UserEmpIndex int = 0 ,              
   @Eventdate date='1/1/1900'      
As                                                  
--ALTER procedure [dbo].[tm_Leaves_Application] 
--Declare
--   @UserId char(20) = '',                  
--   @EmployeeIndex int = 365766,                  
--   @FromDate datetime = '2024-10-11',                  
--   @ToDate datetime = '2024-10-11',                  
--   @LeaveType tinyint = 1,                  
--   @LeaveEncashment tinyint = 0,                  
--   @LeaveAdjustment tinyint = 0,                  
--   @TotalDays float = 1,                  
--   @Reason varchar(100) = '',                  
--   @Address varchar(100) = '',                  
--   @ContactNo varchar(20) = '',                  
--   @ContactPerson varchar(100) = '',                  
--   @RulesByPass tinyint  = 0, -- = 0 ,                  
--   @AdvanceDays float  = 0, -- = 0 ,                  
--   @EncashType tinyint = 1,                  
--   @EncashDays float = 0,                  
--   @EncashRemarks varchar(100) = '',                  
--   @ShortDay float = 0,                  
--   @RulesByPassForcibly tinyint=0 , --=0                  
--   @oLeaveType tinyint =0, -- Original Leave Type,                  
--   @IsDraft tinyint = 0,                  
--   @DLeaveIndex int = 0,                 
--   @LeaveCat tinyint=0,                 
--   @UserEmpIndex int = 0 ,            
--   @Eventdate date='1/1/1900'    
----As                                                
			Begin
				   --exec  
				   --raiserror ('Temporary Unavailable',16,1)  
				   --return  
				   declare @ClientType tinyint, @LeaveIndex int, @ProcessNo smallint, @LeaveStatus tinyint, @LeaveOption tinyint,@ClientIndex int  
				   declare @LvGroup smallint  , @LeaveSubStatus tinyint = 0 , @TotalLeaves smallint , @LeaveCounter Smallint  
				   declare @Msg varchar(100) , @LvCutOffDays tinyint, @AllowOtherBalance tinyint=0,@ToDoType smallint=0 , @IsAllowOtherBalance tinyint = 0,@IsCombinedLeave tinyint=0, @ATCCuttOffDays tinyint,@RestrictDays
				   tinyint ,@BirthMonth smallint,@BirthDate smallint,@IsEventDateActive tinyint,@IsEventDateCounter smallint, @LvDaysCounter float , @IsByPassMinBalance tinyint,	@IsByPasMinBalLvType tinyint, 
				   @IsAllowOnNoticePeriod tinyint, @LvFirstPriority tinyint,@LvAllowInServiceTenure tinyint, @GradeIndex tinyint, @ClientGradeIndex int
				  if @UserEmpIndex>0  
				   set @UserId=ltrim(str(@UserEmpIndex))  
					  select  @clienttype= cm.ClientType,
							  @ClientIndex=cm.ClientIndex,
							  @LvGroup=isnull(e.LvGroup,0),
							  @Birthdate=  day(e.dateofbirth),
							  @Birthmonth= month(e.dateofbirth),
							  @GradeIndex = GradeIndex
					   from   Employee e, ClientMaster cm  
					   where  e.ClientIndex = cm.ClientIndex  
							  and e.EmployeeIndex = @EmployeeIndex  

						Exec tm_leaves_calculation @Employeeindex,@Leavetype,@Fromdate
						Exec tm_leaves_calculation @Employeeindex,@Leavetype,@todate
						if @leavetype = 106
						 begin
						 set @totaldays = 0.25
						 end
						 if @LeaveType = 1 and @TotalDays in (0.5) and @UserId = '-'
						 begin
						 set @OLeaveType =   8
						 end
						 if @LeaveType = 1 and @TotalDays in (0.25) and @UserId = '-'
						 begin
						 set @OLeaveType =   43
						 end
					If @RulesByPassForcibly=0 and exists (select EmployeeIndex from tm_AtClosing where EmployeeIndex=@EmployeeIndex and Todate>=@FromDate and Employeeindex not in (select Employeeindex from employee e, clientmaster cm where e.ClientIndex = cm.ClientIndex and cm.IsBasedOnArears > 0)) and @EncashType in (1,4)  
						 begin  
							raiserror('Attendance has been closed!',16,1)  
							return  
						 end  
				if @RulesByPassForcibly=0 and exists (
					select	p.PeriodIndex 
					from	tm_period p
					where	p.PeriodGroup in (
							select	pwl.PeriodGroup 
							from	tm_PeriodGroup pg, tm_PeriodGroupWL pwl, VwEmpWL ewl
							where	ewl.EmployeeIndex=@employeeindex
									and ewl.WorkLocationIndex=pwl.WorkLocationIndex
									and ewl.WorkLocation=pwl.WorkLocation
									and pg.PeriodGroup=pwl.PeriodGroup
									and pg.PeriodCat=4
							)
							and p.PeriodStatus=3
							and p.PeriodIndex not in 
								(
									select	PeriodIndex 
									from	tm_PeriodException 
									where	(
											EmployeeIndex=@EmployeeIndex 
											or
											EmployeeIndex in (select EmployeeIndex from acm_VwEmpAuthority where UserEmpIndex=@UserEmpIndex  and WLCat=3 and employeeindex =@EmployeeIndex)
											)
											and PeriodStatus=1
								)
							and	@fromdate between p.FromDate and p.ToDate
					)
       begin  
              raiserror('Attendance Period has been closed!',16,1)  
              return  
       end
					if @RulesByPassForcibly=0  and exists (        
						select EmployeeIndex  
						from   LeaveClosing   
						where  EmployeeIndex =@EmployeeIndex   
						and PayrollMonth  > @FromDate   
						and LeaveType=@LeaveType)   
						 begin  
							raiserror ( 'Leave period is closed for employee!!!', 16, 1 )  
							return  
						 end  
  					if (convert(date,@EventDate,107) > convert(date,@FromDate,107))
						begin 
						raiserror('According to Company Policy Event Date can not be less than Request Date.',16,1) 
							--raiserror(@mssg,16,1)  
							return  
						end
			   Select @Clienttype= cm.ClientType,@ClientIndex=cm.ClientIndex ,@LvGroup=isnull(e.LvGroup,0)  
			   from   Employee e, ClientMaster cm  
			   where  e.ClientIndex = cm.ClientIndex  
				   and e.EmployeeIndex = @EmployeeIndex  
						select @AllowOtherBalance = isnull(AllowOtherBalance,0) 
						, @IsCombinedLeave=isnull(IsCombineLeave,0)
						from   LeaveClientMapping   
						where  ClientIndex=@ClientIndex and LeaveType=@LeaveType   
				------------------------
				--- umair 6-mar-2023 ---
				if exists (select clientindex from ClientPlan where isnull(IsDepenentOnLeaveRules,0)=1 and ClientIndex=@ClientIndex)
				begin
					if not exists (select leavetype from LeaveRules where ClientIndex=@ClientIndex and LvGroup=@LvGroup and LeaveType=@LeaveType)
					begin  
							raiserror('Leave Rules Are Not Defined!', 16, 1)  
							return  
					end  
				end
				--- umair 6-mar-2023 ---
				------------------------
					if   @LeaveType not in (8,13,14,24,42,43,105,24,108,75,76,55,110,111,106,104)  --Leave type 105 and 24 add by saif ullah on 4/30/2023
						 and @RulesByPass=0   and @ShortDay = 0
								 and @EncashType in (1,4)  
						 and exists (   
			--                  select * from tm_Attendance where EmployeeIndex=@EmployeeIndex and AtDate between @FromDate and @ToDate   
								select *   
								from   tm_Attendance a  
								where  a.EmployeeIndex=@EmployeeIndex and a.AtDate between @FromDate and @ToDate and (EmpIn is not null or EmpOut is not null )  
											 and Not exists (select * from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate between @FromDate and @ToDate  and AdjLvBal=1)  
								)   
				   begin  
						 set @Msg = 'The employee (' + ltrim(rtrim(str(@EmployeeIndex))) + ') found present within given dates'  
						 raiserror(@Msg, 16, 1)  
						 return  
				   end  
				   if @ClientIndex=1144 and @LeaveType = 24 and ( not exists (select * from LeaveOtherBalance where EmployeeIndex=@EmployeeIndex and LeaveType=9 and @FromDate between FromDate and ToDate and Balance >= 0.5))
					begin  
						set @Msg = 'Retry, this request exceeds the maximum allowed balance, as defined in the company policy.'   
						raiserror(@Msg, 16, 1)  
						return  
					end  
				if @RulesByPassForcibly = 1  
					set @RulesByPass = @RulesByPassForcibly 
				   if @AllowOtherBalance=1 or (exists (select * from LeaveOtherBalance where EmployeeIndex=@EmployeeIndex and LeaveType=@LeaveType and @FromDate between FromDate and ToDate))  
				   begin  
						 Exec   tm_Leaves_ApplicationOther  
											 @UserId,  
											 @EmployeeIndex ,  
											 @FromDate ,  
											 @ToDate ,  
											 @LeaveType ,  
											 @TotalDays ,  
											 @Reason,  
											 @RulesByPass,
											 @OleaveType
						 return  
						 end  
					if @AllowOtherBalance=1 
					begin  
						set @Msg = 'Retry, this request exceeds the maximum allowed balance, as defined in the company policy.'   
						raiserror(@Msg, 16, 1)  
						return  
					end  
					  --if exists (    select * from leaverules where clientindex =  @Clientindex and LeaveType = @LeaveType and @fromdate <  getdate() and isnull(LvCutOffDays, 0) <> 0)  
					  --begin   
									   --select     @LvCutOffDays = LvCutOffDays   
									   --from leaverules   
									   --where      clientindex =  @Clientindex   
									   --           and LeaveType = @LeaveType   
							 --           and @fromdate <  getdate()  
									   --           and @days >= isnull(LvCutOffDays, 0)  
									   --set @Msg ='According to Company Policy you can not apply "' + LTRIM(RTRIM(@LvCutOffDays)) + '" days post dated leaves.'  
									   --raiserror(@Msg, 16, 1)  
				--         return  
					  --end  
				   --if exists (select LeaveSubStatusNext From LeaveSubStatusGroup where clientIndex=isnull(@ClientIndex,0) and (lvgroup=@lvgroup or lvgroup=0) and (LeaveType=@LeaveType))  
				   --      set @LeaveSubStatus=(select LeaveSubStatusNext From LeaveSubStatusGroup where clientIndex=@ClientIndex and leaveSubStatus=0 and (lvgroup=@lvgroup or lvgroup=0) and (LeaveType=@LeaveType))  
				   --else     
				   --      set @LeaveSubStatus=0  
				   if exists (select LeaveSubStatusNext From LeaveSubStatusGroup where clientIndex=isnull(@ClientIndex,0) and (lvgroup=@lvgroup or lvgroup=0) and (LeaveType=@LeaveType Or Leavetype = 0))  
						 set @LeaveSubStatus=(select LeaveSubStatusNext From LeaveSubStatusGroup where clientIndex=@ClientIndex and leaveSubStatus=0 and (lvgroup=@lvgroup or lvgroup=0) and (LeaveType=@LeaveType Or Leavetype = 0))  
				   else     
						 set @LeaveSubStatus=0  
				   if (@ClientIndex = 875  and @LeaveType=2)  
						set @LeaveSubStatus=35  
				   if (convert(date,@FromDate)= '' or convert(date,@FromDate)= '1/1/1900')    
						 begin  
								raiserror('Invalid From Date.', 16, 1)  
								return  
						 end  
				   if (convert(date,@ToDate)= '' or convert(date,@ToDate)= '1/1/1900')    
						 begin  
								raiserror('Invalid To Date.', 16, 1)  
								return  
						 end  
				   if @FromDate > @ToDate   
				   begin  
						 raiserror('Invalid Date Selection.', 16, 1)  
						 return  
				   end  
				   if @LeaveType <= 0  
				   begin  
						 raiserror('Invalid Leave Type.', 16, 1)  
						 return  
				   end  
				   if exists (  
						 select ServiceEndDate   
						 from   Employee   
						 where  EmployeeIndex=@EmployeeIndex   
								and ServiceStatus<>1  
								and @FromDate not between ServiceStartDate and ServiceEndDate  --and @RulesByPassForcibly=1
				   )   
				   begin  
						 raiserror('Employee is no longer in service',16,1)  
						 return  
				   end  
				   if @UserId='-'  
						 set @LeaveStatus=1  
				--   if (@ClientIndex in (select ClientIndex from ClientPlan where LeaveApproval=2)) and @UserId<>'-'  
				--         set @LeaveStatus=2  
				--   else     
				--         set @LeaveStatus=1  
				--         set @ProcessNo=1  
				--set @LeaveOption=1  
				  Declare @ClientLeaveApproval tinyint ,@IsAllowOnNoticePeriodClient tinyint = 0  
				  select @ClientLeaveApproval = isnull(LeaveApproval,1), @IsAllowOnNoticePeriodClient = Isnull(IsAllowOnNoticePeriodClient,0) from ClientPlan where clientindex = @ClientIndex  
					   if @ClientLeaveApproval=2 and @UserId<>'-'  
							 set @LeaveStatus=2  
				  else if @ClientLeaveApproval=3  
							 set @LeaveStatus=2  
					   else     
							 set @LeaveStatus=1  

				-------------------------------------------------
				--- Leave Status Exception For Specific Grade ---
				if exists 
						(
							select	cg.ClientGradeIndex 
							from	ClientGrade cg
									inner join LeaveStatusException lse on cg.ClientGradeIndex=lse.ClientGradeIndex
							where	cg.ClientIndex=@ClientIndex and cg.GradeIndex=@GradeIndex
						)
				begin
						select	@LeaveStatus = LeaveStatus
						from	ClientGrade cg
								inner join LeaveStatusException lse on cg.ClientGradeIndex=lse.ClientGradeIndex
						where	ClientIndex=@ClientIndex and GradeIndex=@GradeIndex
				end
				--- Leave Status Exception For Specific Grade ---
				-------------------------------------------------


				set @ProcessNo=1  
				set @LeaveOption=1  
				   if @EmployeeIndex=0   
						 select @EmployeeIndex = employeeindex from RegisteredUsers where UserID=@UserId  
						 select @LvGroup=isnull(LvGroup,0)  
						 from   Employee   
						 where  EmployeeIndex=@EmployeeIndex   
				   -----------------------------------------------------------------------------------------------  
				   --- In case of Short Leave system will get default value of short leave and its multiplier  ---  
				   declare @DefaultLeaveDays float=0, @DefaultLeaveDaysMultiplier float=1  ,@EnableHDonSaturday tinyint=0
				   -------------------------------------------------------------------------  
				   --- If 4 short leaves allowed for 0.5 days each, in that case   
				   --- DefaultLeaveDays = 0.5 and DefaultLeaveDaysMultiplier= 2  
				   --- (@DefaultLeaveDays * 4 = 2 ) * @DefaultLeaveDaysMultiplier = 4       
				   -------------------------------------------------------------------------  
				   select @EncashType = isnull(DefaultLeaveEncashType,0),  
						  @DefaultLeaveDays = isnull(DefaultLeaveDays,0),  
						  @DefaultLeaveDaysMultiplier = isnull(DefaultLeaveDaysMultiplier,1)
				   from   LeaveRules lr  
				   where  LvGroup=@LvGroup  
						  and LeaveType=@LeaveType  
				  and isnull(DefaultLeaveEncashType,0)=4  
				   if @EncashType=4 and @DefaultLeaveDays>0 and @ShortDay=0  
						 set @ShortDay=@DefaultLeaveDays  
				   --- In case of Short Leave system will get default value of short leave and its multiplier  ---  
				   -----------------------------------------------------------------------------------------------  
					  -- Saad 12-11-2019--  
					---------------------------  
				   --- Getting Leave Rules ---  
				  declare @TotalAllowed smallint, @MinDays smallint, @MaxDays smallint, @MaxEncash smallint, @MaxConversion float  
				  declare @IsConfirmationBased tinyint,@ConfirmationCap float, @IsProrateBalance tinyint, @MaxBalanceNegative Float , @Blockfuturedays smallint,@blockPastdays smallint  
				  declare @IsBasedOnWDOD bit, @isApplicableOnOD bit  
				  declare @MaxEncashBalanceCap float = 0  ,@IsBasedOnWorkingDays bit,@Allow2HDInOneDay tinyint = 0 ,@NotApplicableToEmp tinyint =0 
					declare @TotalDaysQuery nvarchar(2000)=''
					if exists (select * from LeaveRulesEmp where employeeIndex=@EmployeeIndex and LeaveType=@LeaveType)  
						  select        @TotalAllowed=maxallowed,   
										@MinDays=isnull(MinDays,0),   
										@MaxDays=ISNULL(MaxDays,0),  
										@IsConfirmationBased = ISNULL(lr.IsConfirmationBased,0),  
										@IsProrateBalance = ISNULL(lr.IsProrateBalance,1),  
										@MaxBalanceNegative = ISNULL(lr.MaxBalanceNegative,0),  
										@MaxEncash=isnull(MaxEncash,0),  
										@MaxConversion=isnull(lr.MaxConversion,0),
										@IsBasedOnWorkingDays =  isnull(lr.IsBasedOnWorkingDays,0)
						  from    leaverulesEmp lr   
						  where   lr.leavetype=@LeaveType   
								 and lr.employeeindex=@EmployeeIndex  
					else  
							select  @TotalAllowed=maxallowed,   
									@MinDays=isnull(MinDays,0),   
									@MaxDays=ISNULL(MaxDays,0),  
									@IsConfirmationBased = ISNULL(lr.IsConfirmationBased,0),
									@ConfirmationCap = ISNULL(lr.ConfirmationCap,0), 
									@IsProrateBalance = ISNULL(lr.IsProrateBalance,1),  
									@MaxBalanceNegative = ISNULL(lr.MaxBalanceNegative,0),  
									@MaxEncash=isnull(MaxEncash,0),  
									@MaxConversion=isnull(lr.MaxConversion,0),  
									@LvCutOffDays = isnull(LvCutOffDays, 0),  
									@Blockfuturedays=isnull(lr.Blockfuturedays,9999),  
									@blockPastdays=isnull(lr.blockPastdays,9999),  
									@IsBasedOnWDOD=isnull(lr.IsBasedOnWDOD,0),  
									@isApplicableOnOD=isnull(lr.isApplicableOnOD,0) ,   
									@MaxEncashBalanceCap = isnull(MaxEncashBalanceCap,0),
									@IsBasedOnWorkingDays =  isnull(lr.IsBasedOnWorkingDays,0),
									@Allow2HDInOneDay = isnull(lr.Allow2HDInOneDay,0),
									@NotApplicableToEmp = isnull(lr.NotApplicableToEmp,0),  
									@IsAllowOtherBalance = Isnull(lr.IsAllowOtherBalance,0),
									@IsEventDateActive  = Isnull(lr.IsEventDateActive,''),
									@IsEventDateCounter  = Isnull(lr.IsEventDateCounter,''),
									@LvDaysCounter  = Isnull(lr.LvDaysCounter,''),
									@IsByPassMinBalance = Isnull(lr.IsByPassMinBalance,0),
									@IsByPasMinBalLvType  =  Isnull(lr.IsByPasMinBalLvType,0),
									@IsAllowOnNoticePeriod = ISNULL(lr.IsAllowOnNoticePeriod, 0),
									@LvFirstPriority        = Isnull(lr.LvFirstPriority,0),
									@LvAllowInServiceTenure = Isnull(lr.LvAllowInServiceTenure,0)
							from    Leaverules lr, Employee e   
							where   lr.leavetype=@LeaveType   
									and isnull(lr.LvGroup,0)=@LvGroup  
									and lr.ClientIndex=e.ClientIndex  
									and e.employeeindex=@EmployeeIndex  
					---------------------------  
				   --- Getting Leave Rules ---  
					  -- Saad 12-11-2019-- 
					  --select 	@IsAllowOnNoticePeriod,@IsAllowOnNoticePeriodClient
				   ----------------------------Changes as Described in Task - AT 38----------------------------------------
				IF Isnull(@IsAllowOnNoticePeriod,0) = 0 and (@IsAllowOnNoticePeriodClient = 1) 
					BEGIN
						IF EXISTS 
						(
							SELECT ServiceEndDate   
							FROM Employee   
							WHERE EmployeeIndex = @EmployeeIndex   
							AND @FromDate BETWEEN ResignDate AND ServiceEndDate
						)   
						BEGIN
							--RAISERROR('As per the policy, Employee is only allowed to mark LWOP during the notice period!!!', 16, 1);  
							--RETURN;  
							SET @Msg = 'Retry, as per company policy Selected Leave Type is not allowed during the notice period!!!'
						    raiserror(@Msg, 16, 1)  
						    return
						END
					END
					----------------------------Changes as Described in Task - AT 38----------------------------------------
						if (@IsEventDateActive  =1 and @IsEventDateCounter < datediff (DD,@Eventdate,@ToDate)+1)
						begin 
							declare @mssg varchar (150)
							set @mssg='According to Company Policy you can only apply for this leave type with in ' + rtrim (ltrim(convert(smallint,@IsEventDateCounter))) + ' days of the event date.'
							raiserror(@mssg,16,1)  
							return  
						end
					  if @NotApplicableToEmp = 1 and @UserId = '-' 
					  begin  
						raiserror('According to Company Policy you can not apply this leave type.',16,1)  
						return  
					 end   
					 if @RulesByPassForcibly=0 and exists (select * from LeaveRules where ReasonMendatory = 1 and Leavetype = @leavetype and Clientindex = @CLientindex and lvgroup = @LvGroup ) and len(ltrim(rtrim(@Reason)))=0  
					 begin  
						raiserror('Leave application reason is manadatory.',16,1)  
						return  
					 end  
					  if @RulesByPassForcibly=0 and exists ( select * from employee e, leaverules lr where e.employeeindex=@EmployeeIndex and e.LvGroup = lr.LvGroup and lr.ClientIndex=e.ClientIndex and lr.LeaveType=@LeaveType and lr.MinJobMonths > 0 and @FromDate < dateadd(mm, lr.MinJobMonths, servicestartdate) )  
					  begin  
					   raiserror('Not allowed to avail this leave before entitlement.', 16, 1)  
					   return  
					  end  
				   ----------------- SAAD ALI-----------------------  
				   if  @ClientIndex=528 and datepart(mm,@Todate) >= (select lr.FromDate from employee e, leaverules lr where e.employeeindex=@EmployeeIndex and e.LvGroup = lr.LvGroup and lr.ClientIndex=e.ClientIndex and lr.LeaveType=@LeaveType) and datepart(mm,@Fromdate) <= (select lr.ToDate from employee e, leaverules lr where e.employeeindex=@EmployeeIndex and e.LvGroup = lr.LvGroup and lr.ClientIndex=e.ClientIndex and lr.LeaveType=@LeaveType) and ((select CarryForwardYears from employee e, leaverules lr where e.employeeindex=@EmployeeIndex and e.LvGroup = lr.LvGroup and lr.ClientIndex=e.ClientIndex and lr.LeaveType=@LeaveType) = 0)   
				   begin  
						 raiserror('Not allowed to avail this leave as leave Period is changed.', 16, 1)  
						 return  
				   end  
				   ----------------- SAAD ALI-----------------------  
				if exists (Select * from leaverules  where clientindex = @clientindex and leavetype=@leaveType and isnull(restrictdays,0) > 0 and lvgroup=@lvgroup)
				begin
				  if @userid = '-' 
				  Begin
						  Select @RestrictDays=RestrictDays from leaverules  where clientindex = @clientindex and leavetype=@leaveType and isnull(restrictdays,0) > 0 and lvgroup=@lvgroup
						  if isnull(@RestrictDays, 0)>0 and datediff(day, @FromDate, getdate()) >= isnull(@RestrictDays, 0)
						  Begin
								 Set @Msg ='According to Company Policy you can not apply "' + LTRIM(RTRIM(@RestrictDays)) + '" days post dated Leave.'
								 raiserror(@Msg, 16, 1)
								 return
						  End
					 End
					End
					if exists (Select * from leaverules  where clientindex = 1266 and leavetype=@leaveType and isnull(restrictdays,0) > 0 and lvgroup=@lvgroup)
				begin
				  if (@userid in ('','-'))
				  Begin
						  Select @RestrictDays=RestrictDays from leaverules  where clientindex = @clientindex and leavetype=@leaveType and isnull(restrictdays,0) > 0 and lvgroup=@lvgroup
						  if isnull(@RestrictDays, 0)>0 and datediff(day, GETDATE(), @Fromdate) < isnull(@RestrictDays, 0)
						  Begin
								 Set @Msg ='According to Company Policy you can not apply "' + LTRIM(RTRIM(@RestrictDays)) + '" days post dated Leave.'
								 raiserror(@Msg, 16, 1)
								 return
						  End
					End
					End
				   if @LeaveType in (8,13,14,24,42,43,41,55,74,75,76,104,106,110,111)  
				   begin  
						 set @ToDate=@FromDate   
						 set @RulesByPass=1  
						 --87798, 10/1/2013  
					if @ClientIndex in (528,529,1231)   -- 528 and 529 are added previously and 1231 added by saif ullah on 2024-04-28 11:37
					begin  
							if not exists (  
									select * from tm_Summary where convert(date,AtDate)=CONVERT(date,@FromDate) and EmployeeIndex=@EmployeeIndex and AdjLvBal >=0.5  
													)  
							begin  
									raiserror('Halfday leave is not allowed!!!',16,1)  
									return  
							end  
					end  
				end 
				if   @leavetype=102 and  @Birthdate <>  day(@fromdate) and  @Birthmonth <>  month(@fromdate)
				Begin 
				begin  
						raiserror('Birthday Leave allowed on Birth date provided in system!!!',16,1)  
						return  
						end
				End 
			--        select * from leavedetail where leavetype=1 and fromdate>='3/1/2019' and employeeindex=207130  
				   ---------------------  
				   -- Continual Leave --  
				   declare @ContinualLeaveType varchar(200), @ContinualTotalDays float  
				   set     @ContinualLeaveType=0  
				   set     @ContinualTotalDays=0  
			--and exists (select EmployeeIndex from tm_Summary where EmployeeIndex=s.EmployeeIndex and AtDate=(select Max(atdate) from tm_Summary where EmployeeIndex=s.EmployeeIndex and AtDate<s.AtDate and IsHoliday=0) and IsLeave=1 and isgazetted=0)  
			--and exists (select EmployeeIndex from tm_Summary where EmployeeIndex=s.EmployeeIndex and AtDate=(select MIN(atdate) from tm_Summary where EmployeeIndex=s.EmployeeIndex and AtDate>s.AtDate and IsHoliday=0) and IsLeave=1 and isgazetted=0)  
						 --declare @LastWorkingDay datetime, @FirstWorkingDay datetime  
				   select @ContinualLeaveType=leavetype,   
						  @ContinualTotalDays=isnull(ContinualTotalDays ,0)+TotalDays   
				   from   LeaveDetail  
				   where  EmployeeIndex=@EmployeeIndex   
						  and (ToDate=dateadd(dd,-1,@FromDate) or FromDate=dateadd(dd,1,@ToDate) )  
						  and TotalDays>=1  
						  and LeaveStatus in (1,2,3)  
				   if @ContinualLeaveType>0 and @ContinualLeaveType<>@LeaveType   
				   begin  
						 set @ContinualTotalDays=0  
				   end      
				   -- Continual Leave --  
				   ---------------------  
				   if @TotalDays=0  
				   begin  
						 set @TotalDays = DATEDIFF(DD, @FromDate, @ToDate)+1    
						 if exists (  
								select *  
								from   Employee e,LeaveRules lr  
								where  lr.LvGroup=e.LvGroup  
					 and e.ClientIndex=lr.ClientIndex  
					 and e.EmployeeIndex=@EmployeeIndex  
					 and lr.LeaveType =@LeaveType  
					 and isnull(lr.LvGroup,0)=@LvGroup  
					 and isnull(lr.IsHourlyBalance,0)=1  
						 )  
						 begin  
								--set @TotalDays = @TotalDays  
								--alter table tm_rosterday drop column WorkHours  
								--alter table tm_rosterday add  WorkHours Float  
								-- select * from tm_Rosterday where rosterindex in (79,107)  
								select @TotalDays = isnull( sum( isnull(rd.WorkHours,0) ) , 0)  
								from   tm_VwEmpshift es , tm_Rosterday rd  
								where  es.employeeindex=@EmployeeIndex -- 88711   
										and dt between @FromDate and @ToDate -- '6/1/2016' and '6/10/2016'  
										and rd.RosterIndex = es.RosterIndex  
										and rd.dayno=datepart(dw,es.dt)  
										and not exists (select * from  tm_VwEmpOff eo where eo.employeeindex=es.EmployeeIndex and es.Dt = eo.HolidayDate and eo.IsOff = 1 )   
						 end  
						 if exists (    
								select o.HolidayDate   
								from   Employee e,LeaveRules lr,tm_VwEmpOff o  
								where  lr.LvGroup=e.LvGroup  
										and e.ClientIndex=lr.ClientIndex  
										and e.EmployeeIndex=o.EmployeeIndex  
										and lr.LeaveType =@LeaveType  
										and isnull(lr.LvGroup,0)=@LvGroup  
										and isnull(lr.IsBasedOnWorkingDays,0)=1  
										and HolidayDate between @FromDate and @ToDate  
										and o.EmployeeIndex =@EmployeeIndex  
						 )  
								select @TotalDays = @TotalDays - count(o.HolidayDate)  
								from   Employee e,LeaveRules lr,tm_VwEmpOff o  
								where  lr.LvGroup=e.LvGroup  
										and e.ClientIndex=lr.ClientIndex  
										and e.EmployeeIndex=o.EmployeeIndex  
										and lr.LeaveType =@LeaveType  
										and isnull(lr.LvGroup,0)=@LvGroup  
										and isnull(lr.IsBasedOnWorkingDays,0)=1  
										and HolidayDate between @FromDate and @ToDate  
										and o.EmployeeIndex =@EmployeeIndex  
						 if exists (    
								select o.HolidayDate   
								from   Employee e,LeaveRules lr,tm_VwEmpOff o  
								where  lr.LvGroup=e.LvGroup  
										and e.ClientIndex=lr.ClientIndex
										and e.EmployeeIndex=o.EmployeeIndex
										and lr.LeaveType =@LeaveType  
										and isnull(lr.LvGroup,0)=@LvGroup  
										and isnull(lr.IsBasedOnWDOD,0)=1  
										and isnull(o.IsGazetted,0)=1  
										and o.HolidayDate between @FromDate and @ToDate  
										and o.EmployeeIndex =@EmployeeIndex  
						 )  
								select @TotalDays = @TotalDays - count(o.HolidayDate)  
								from   Employee e,LeaveRules lr,tm_VwEmpOff o  
								where  lr.LvGroup=e.LvGroup  
										and e.ClientIndex=lr.ClientIndex  
										and e.EmployeeIndex=o.EmployeeIndex  
										and lr.LeaveType =@LeaveType  
										and isnull(lr.LvGroup,0)=@LvGroup  
										and isnull(lr.IsBasedOnWDOD,0)=1  
										 and isnull(o.IsGazetted,0)=1  
										and HolidayDate between @FromDate and @ToDate  
										and o.EmployeeIndex =@EmployeeIndex 
						if len(@TotalDaysQuery)>0
						begin
							--declare @FromDate date='1/1/2023', @ToDate date='1/31/2023', @EmployeeIndex int = 309720, @TotalDaysQuery nvarchar(2000)=''
							declare @TotalDaysReturn float=0, @ParmDefinition nvarchar(500)
							--set @TotalDaysQuery =  'select @TotalDaysOut = count(*)-1 from tm_VwEmpOff o where o.EmployeeIndex=[EmployeeIndex] and o.HolidayDate between ''[FromDate]'' and ''[ToDate]'' and Datepart(dw,o.HolidayDate)=7 '
							set @TotalDaysQuery = REPLACE(@TotalDaysQuery, '[EmployeeIndex]',ltrim(@EmployeeIndex))
							set @TotalDaysQuery = REPLACE(@TotalDaysQuery, '[FromDate]',rtrim(convert(char,@FromDate,107)))
							set @TotalDaysQuery = REPLACE(@TotalDaysQuery, '[ToDate]',rtrim(convert(char,@ToDate,107)))
							--select @TotalDaysQuery
							SET @TotalDaysReturn=0
							--SET @SQLString =  N'select @TotalDaysOut = (' + @tmpformula + ')'
							SET @ParmDefinition = N'@TotalDaysOut real OUTPUT' 
							EXECUTE sp_executesql @TotalDaysQuery, @ParmDefinition, @TotalDaysOut = @TotalDaysReturn OUTPUT
							--select @TotalDaysReturn TotalDaysReturn
							if @TotalDaysReturn<0
								set @TotalDaysReturn=0
							select @TotalDays = @TotalDays + @TotalDaysReturn 
						--select @Total
						end
				   end  
				   if @EncashType=5  
				   begin  
						 declare @MinLFADays float=0, @LFADays float=0  
						 if exists (  
								select ld.LeaveIndex   
								from   leavedetail ld, fnleaveperiod(@EmployeeIndex,getdate()) lp  
								where  ld.EmployeeIndex=lp.EmployeeIndex   
										and ld.LeaveType=lp.LeaveType  
										and ld.FromDate between lp.FromDate and lp.ToDate  
										and ld.LeaveType = @LeaveType  
										and isnull(ld.EncashType,0)=5  
										and ld.LeaveStatus in (1,2,3)  
						 )  
						 begin  
								raiserror('Retry without selecting LFA, as LFA has already been availed.', 16, 1)  
								return  
						 end  
						 select @MinLFADays = isnull(MinLFADays,0) from LeaveRules where lvgroup=@LvGroup and leavetype=@LeaveType  
						 --select * FROM EMPLOYEE WHERE lvgroup=167  
						 select @LFADays = isnull(sum(totaldays),0) + @TotalDays   
						 from   leavedetail ld, fnleaveperiod(@EmployeeIndex,getdate()) lp  
						 where  ld.EmployeeIndex=lp.EmployeeIndex   
								and ld.LeaveType=lp.LeaveType  
								and ld.FromDate between lp.FromDate and lp.ToDate  
								and ld.LeaveType = @LeaveType  
								and ld.LeaveStatus in (1,2,3)  
						 --set @LFADays = @LFADays + @TotalDays  
						 if @MinLFADays>@LFADays  
						 begin  
								set @Msg = 'Retry, as per company policy at least "' +  LTRIM(str(@MinLFADays)) + '[' +  LTRIM(str(@TotalDays)) + '][' +  LTRIM(str(@LFADays)) + ']" days required to availe LFA.'   
								raiserror(@Msg, 16, 1)  
								return  
						 end  
				   end  
					  -- Saad 12-11-2019---  
					  declare @dt1 datetime, @dt2 datetime  
				   --if @isApplicableOnOD=1  
				   --begin  
				   --             -- previous leave Day  
				   --             select @Dt1=atdate from tm_Summary where  EmployeeIndex=@EmployeeIndex and AtDate=(select Max(atdate) from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate<@FromDate and IsHoliday=0 and isgazetted=0) and IsLeave=1--  and isholiday=0   
				   --             -- forward leave Day  
				   --             select @Dt2=atdate from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate=(select MIN(atdate) from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate>@ToDate and IsHoliday=0 and isgazetted=0) and IsLeave=1-- and isholiday=0  
				   --             if (dateadd(DD,1,@DT1)<>@FromDate or dateadd(DD,-1,@DT2)=@ToDate) -- OD Sandwich restricted  
				   --             begin  
				   --                    raiserror('This Type of Leave is not Applicable In Continuation, please insert leave over holiday.', 16, 1)  
				   --                    return  
				   --             end  
				   --end  
				   -- Saad 12-11-2019---  
				  declare @LvDt1 datetime, @LvDt2 datetime   
			   declare @MaxDate datetime, @MinDate datetime,@PresentFlag bit = 0  
			   if @isApplicableOnOD=1  
				begin  
				   select @MinDate = Max(atdate) from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate<@FromDate and ( IsHoliday=0 or (isholiday=1 and isleave=1) ) and isgazetted=0  -- min date means 2020-04-03 for example  
				   select @MaxDate = MIN(atdate) from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate>@ToDate   and ( IsHoliday=0 or (isholiday=1 and isleave=1) ) and isgazetted=0    -- max date means 2020-04-06 for example  
				  -- previous leave Day  
				   select @LvDt1=atdate from tm_Summary where  EmployeeIndex=@EmployeeIndex and AtDate=(@MinDate) and IsLeave=1 and LeaveTotalDays > = 1  
				   -- forward leave Day  
				   select @LvDt2=atdate from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate=(@MaxDate) and IsLeave=1  and LeaveTotalDays > = 1   
				  --  Present between leave Days  
				   if exists (select  1 from tm_Summary where  EmployeeIndex=@EmployeeIndex and AtDate between isnull(isnull(@LvDt1,dateadd(DD,1,@MinDate)),@FromDate) and isnull(isnull(@LvDt2,dateadd(DD,-1,@MaxDate)),@ToDate) and IsAttendance=1)  
				   set @PresentFlag = 1  
				 if (dateadd(DD,1,@LvDt1)<>@FromDate or dateadd(DD,-1,@LvDt2)<>@ToDate) and @Totaldays > = 1 and @PresentFlag <> 1-- OD Sandwich restricted  
				   begin  
					raiserror('This Type of Leave is not Applicable In Continuation, please insert leave over holiday.', 16, 1)  
					return  
				   end  
				end  
					if exists (select * from tm_LeaveRestriction where RestrictedLeaveType=@LeaveType and ClientIndex=@ClientIndex) and @RulesByPassForcibly=0 and @TotalDays >=1   
						 Begin  
								select @dt1 = min(atdate) from tm_Summary where EmployeeIndex=@EmployeeIndex and atdate > @ToDate and IsHoliday=0  
								select @dt2 = max(atdate) from tm_Summary where EmployeeIndex=@EmployeeIndex and atdate < @FromDate and IsHoliday=0  
								if exists (select LeaveType from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate in (@Dt1, @Dt2) and IsLeave=1)  
								begin  
									 Select @ContinualLeaveType = COALESCE(@ContinualLeaveType + ',','') + convert(varchar(200),LeaveType) from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate in (@Dt1, @Dt2) and IsLeave=1  and LeaveTotalDays >= 1 
								end  
								--select @LeaveLimit = LeaveLimit
								--FROM TM_LEAVERESTRICTION
								--Where Leavetype = @LeaveType
								--and   ClientIndex = @ClientIndex
								if exists (select * from tm_LeaveRestriction where LeaveType in (select col1 from fnparsearray(@ContinualLeaveType,',')) and RestrictedLeaveType=@LeaveType and ClientIndex=@ClientIndex) and @RulesByPassForcibly=0 and @TotalDays >=1 --and Datediff(DD,@fromdate,@Todate)+1 > Isnull(@LeaveLimit,0)
								begin  
									   raiserror('This Type of Leave is not Applicable In Continuation.', 16, 1)  
									   return  
								end  
						 End  
				  --if working day based then skip holiday and leave will not insert over holiday
				  --if not working day based then apply holiday and leave will allow to insert over holiday
						 -- Saad 12-11-2019 --  
				   if @LeaveType not in (15,46) and exists(select * from tm_vwEmpoff where EmployeeIndex=@EmployeeIndex and holidaydate=@FromDate and isoff=1) and @EncashType in (1,4) and @isApplicableOnOD=0 and @IsBasedOnWorkingDays =1 --Working days check added on 2021-07-31 by Jawad 
				   begin  
						 raiserror('Leave can not be inserted over Holiday .',16,1)  
						 return  
				   end  
					  -- Saad 12-11-2019 --  
				   if @TotalDays=0  and @EncashType in (1,4)  
				   begin  
						 raiserror('Leave days/hours not found !!!',16,1)  
						 return  
				   end  
				   if @EncashType=2   
				   begin  
						 set @TotalDays=0  
						 set @RulesByPass=1  
				   end  
				   if @EncashType=4  -- Short Days  
				   begin  
						 if @ShortDay>=1 or @ShortDay <= 0  
						 begin  
								raiserror('Short days should be greater than 0 and less than 1  !!!',16,1)  
								return  
						 end  
						 set @TotalDays=@ShortDay   
						 set @RulesByPass=1  
				   end  
						 if  @Blockfuturedays<>9999   
								begin  
								   if  datediff(dd,getdate(),@FromDate) > @Blockfuturedays  and @RulesByPassForcibly = 0  
								   begin  
											 Set @Msg ='This type of leave is restricted for future '+ ltrim(rtrim(@Blockfuturedays)) +'days.'  
											 RaisError(@Msg, 16, 1)  
											 Return  
								   end  
								end  
				   -------------Block Past days 2019-08-05 by jawad---------------------------      
						if  @blockPastdays<>9999   
						begin  
							------------------------------------  
							---- commit by umair 2020-11-09 ----  
										----declare @pastdt datetime  
										----declare @skipHoliday smallint  
										----select  @pastdt = min(atdate) from tm_Summary where EmployeeIndex=@EmployeeIndex and atdate between  dateadd(day,1,@ToDate) and getdate() and IsHoliday= 0 and isleave= 0 --For Working days  
										----select  @skipHoliday = count(*) from tm_Summary where EmployeeIndex=@EmployeeIndex and atdate between  dateadd(day,1,@ToDate) and getdate() and IsHoliday= 1 and isleave= 0   
										----if  (datediff(dd,getdate(),@pastdt))+@skipHoliday <= @blockPastdays  and @RulesByPassForcibly = 0  
							---- commit by umair 2020-11-09 ----  
							------------------------------------  
							------------------------------------  
							---- changed by umair 2020-11-09 ----  
							select	@blockPastdays=@blockPastdays-count(*) 
							from	tm_VwEmpOff 
							where	employeeindex= @EmployeeIndex 
									and HolidayDate between @ToDate and convert(date,getdate())   
							if @ToDate<dateadd(dd,@blockpastdays,convert(date,getdate())) and @RulesByPassForcibly = 0  
							---- changed by umair 2020-11-09 ----  
							------------------------------------  
							begin  
								Set @Msg ='This type of leave is restricted for Past '+ ltrim(rtrim(@blockPastdays)) +'days.'  
								RaisError(@Msg, 16, 1)  
								Return  
							end  
						end  
						 -------------Block Past days 2019-08-05 by jawad---------------------------  
				   ------------------ Saad 12/11/2019 -----------------------------------  
				   --if @IsBasedOnWDOD=1   
				   --Begin  
				   --     if exists (select EmployeeIndex from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate=(select Max(atdate) from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate<@FromDate and IsHoliday=0 and isgazetted=0) and IsLeave=1 )  
				   --     or  
				   --        exists (select EmployeeIndex from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate=(select MIN(atdate) from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate>@ToDate and IsHoliday=0 and isgazetted=0) and IsLeave=1 )  
				   --     Begin  
				   --           Set @Msg ='Please enter leaves on holidays or modify the previously entered leave.'  
				   --           RaisError(@Msg, 16, 1)  
				   --           Return  
				   --     End  
				   --End  
				   ------------------ Saad 12/11/2019 -----------------------------------  
				  if isnull(@LvCutOffDays, 0)>0 and datediff(day, @Fromdate, getdate()+1) >= isnull(@LvCutOffDays, 0) and @RulesByPassForcibly = 0 and @oLeaveType not in (8,43,111,110,52) 
				   begin  
					   set @Msg ='According to Company Policy you can not apply "' + LTRIM(RTRIM(@LvCutOffDays)) + '" days post dated leaves.'  
					   raiserror(@Msg, 16, 1)  
					   return  
				   end  
				   if isnull(@LvCutOffDays, 0)>0 and datediff(day, @Fromdate, getdate()+1) >= isnull(@LvCutOffDays, 0) and @RulesByPassForcibly = 0 and @oLeaveType in (8,43) and @Fromdate <> Convert(Date,Getdate())
				   begin  
					   set @Msg ='According to Company Policy you can not apply "' + LTRIM(RTRIM(@LvCutOffDays)) + '" days post dated leaves.'  
					   raiserror(@Msg, 16, 1)  
					   return
				 end
				   if @TotalAllowed = 0 and @RulesByPass=0  and  isnull(@IsAllowOtherBalance,0) = 0 and @ClientIndex Not in (1308,1331)
				   begin  
						 raiserror('Leave Rules Are Not Defined', 16, 1)  
						 return  
				   end  
				   -----------------------------------To Get The Leave Balance---------------------------------------------------------
				   declare @Balance as float=0  
				   , @FleaveFrom Date , @Fleaveto Date 				
				   select @FleaveFrom = FromDate,
						  @Fleaveto = Todate
						from fnLeavePeriod(@EmployeeIndex,@FromDate)
						where LeaveType=@LeaveType
					If @ToDate not Between @FleaveFrom and @Fleaveto and @clientindex <> 914
					begin
					select @Balance = (case when @TotalDays<1 then round(isnull(Balance,0),2) else  round(isnull(balance,0),2) end ) 
					+ (select round(isnull(Balance,0),2) From Empleaveplan Where Employeeindex = @employeeindex and LeaveType=@LeaveType   
								and month(PayrollMonth)=month(@ToDate)  
								and year(PayrollMonth)=year(@ToDate) )
					from   EmpLeavePlan   
					where  EmployeeIndex=@EmployeeIndex   
								and LeaveType=@LeaveType   
								and month(PayrollMonth)=month(@fromdate)  
								and year(PayrollMonth)=year(@fromdate)
					end 
					else 
					begin
				   	select @Balance = (case when @TotalDays<1 then round(isnull(Balance,0),2) else  round(isnull(balance,0),2) end )  
					from   EmpLeavePlan   
					where  EmployeeIndex=@EmployeeIndex   
								and LeaveType=@LeaveType   
								and month(PayrollMonth)=month(@ToDate)  
								and year(PayrollMonth)=year(@ToDate) 
					end
					-----------------------------------To Get The Leave Balance---------------------------------------------------------

					--- Rules based Balance Addition (Leave entitlementcap before confirmation) added by shazaib 21 november 2024----- 
					
					
					if @IsConfirmationBased=1 and @ConfirmationCap > 0 
					begin
						if exists (select EmployeeIndex from Employee where EmployeeIndex=@EmployeeIndex and isnull(SConfirmationDate,'1/1/1900') = '1/1/1900') 
						begin
							select	@Balance = @ConfirmationCap - count(LeaveIndex) 
							from	LeaveDetail 
							where	LeaveType=@LeaveType 
									and EmployeeIndex=@EmployeeIndex 
									and LeaveStatus in (1,2,3,7)
						end
					end
					--- Rules based Balance Addition (Leave entitlementcap before confirmation) added by shazaib 21 november 2024---
					------------------------------------

					----------------------------------------Leave Priority Check as per task AT-84--------------------------------------
					DECLARE @PBalance FLOAT, @PleaveType Varchar(50);
					SELECT @PBalance = Balance       
					FROM fnleavebalance(@EmployeeIndex, GETDATE()) 
					WHERE LeaveType = ISNULL(@LvFirstPriority, 0);  
					SELECT @PleaveType = LeaveDescription 
					FROM LEAVECLIENTMAPPING 
					WHERE Leavetype = @LvFirstPriority 
					AND ClientIndex = @ClientIndex;
					IF @PBalance >= 1  
					BEGIN  
						SET @Msg = 'According to company policy, please use the ' + @PleaveType + ' leave first.';  
						RAISERROR(@Msg, 16, 1);    
						RETURN;    
					END;
					 ----------------------------------------Leave Priority Check as per task AT-84-----------------------------------------------------------------------------
					If (Isnull(@IsByPassMinBalance,0) = 1) and Isnull(@IsByPasMinBalLvType,0) = 1
					Begin
						  if @MinDays > 0 and (@TotalDays + @ContinualTotalDays) < @MinDays and @RulesByPass = 0 and @Balance < @MinDays
						  Begin
								set @Mindays = @Balance
						  End
					End
				   if @MinDays>0 and (@TotalDays+@ContinualTotalDays)<@MinDays and @RulesByPass=0  
				   begin  
						 set @Msg = 'Retry, as per company policy the leave request must be of at least "' +  LTRIM(str(@MinDays)) + '" day(s) or based on available balance'
						 --"based on available balance", added on QA recommendation's as per AT-09
						 raiserror(@Msg, 16, 1)  
						 return  
				   end  
				   if @MaxDays > 0 and (@TotalDays+@ContinualTotalDays)>@MaxDays and @RulesByPass=0 and @ClientIndex <> 528   
				   begin  
						 set @Msg = 'Retry, as per company policy maximum "' +  LTRIM(str(@MaxDays)) + '" day(s) leave is allowed per request [' + ltrim(str(@TotalDays)) + '|' + ltrim(str(@ContinualTotalDays)) + ']'  
						 raiserror(@Msg, 16, 1)  
						 return  
				   end  
				   if @IsConfirmationBased=1 and exists (select * from Employee where EmployeeIndex=@EmployeeIndex and isnull(SConfirmationDate,'1/1/1900') = '1/1/1900') and @LeaveType<>5  and @RulesByPassForcibly = 0 
														and @EmployeeIndex not in (select Employeeindex From Tm_Sconfirmationdateexception)
				   begin  
						 raiserror('The employee is not yet confirmed and hence not entittled to avail leave as per company policy. However Leave without pay (LWOP) may be taken at this time', 16, 1)  
						 return  
				   end  
				--select * from LeaveType where LeaveDescription like '%pater%'  
				-- this check for gender changed as per ticket no 5191  
				   if @LeaveType in (4,65) and exists (select * from Employee where EmployeeIndex=@EmployeeIndex and isnull(Gender,'M') = 'M')   
				   begin  
						 raiserror('This leave benefit is only entitled to female employees of the company', 16, 1)  
						 return  
				   end  
				   if @LeaveType in (10,82) and exists (select * from Employee where EmployeeIndex=@EmployeeIndex and isnull(Gender,'F') = 'F')   
				   begin  
						 raiserror('This leave benefit is only entitled to Male employees of the company', 16, 1)  
						 return  
				   end  
				   if @MaxConversion>0 and @IsDraft=0  
				   begin  
						 if exists    (  
													select sum(TotalDays)  
													from   LeaveDetail ld, fnLeavePeriod(@EmployeeIndex, @FromDate) lp  
													where       ld.EmployeeIndex=lp.EmployeeIndex  
																and ld.LeaveType=lp.LeaveType  
																 and ld.LeaveType=@LeaveType  
																 and leavestatus in (1,2,3,7)  
																 and ld.FromDate between lp.FromDate and lp.ToDate  
																 and ld.LeaveType <> isnull(ld.oLeaveType,ld.LeaveType)  
																 and isnull(ld.oLeaveType,0)>0  
																 and isnull(leaveencashment,0)+isnull(leaveadjustment,0)=0  
													having sum(TotalDays)+@TotalDays > @MaxConversion  
											 )  
						 begin  
							   set @Msg = 'Retry, this request exceeds the maximum allowed conversion "' +  LTRIM(str(@MaxConversion)) + '", as defined in the company policy..'  
								raiserror(@Msg, 16, 1)  
								return  
						 end            
				   end  
				   if @RulesByPassForcibly=0 and @MaxEncash < @EncashDays and @EncashType in (2,3)  
				   begin  
						 raiserror('Total Encashment Days Are Greater Than Max Encashment Days', 16, 1)  
						 return  
				   end  
				   --- Getting Leave Rules ---   
				   ---------------------------  
				   ----------------------  
				   --- Leave Clubbing ---  
				 --  declare @Balance as float=0  
				 --  , @FleaveFrom Date , @Fleaveto Date 				
				 --  select @FleaveFrom = FromDate,
					--	  @Fleaveto = Todate
					--	from fnLeavePeriod(@EmployeeIndex,@FromDate)
					--	where LeaveType=@LeaveType
					--If @ToDate not Between @FleaveFrom and @Fleaveto and @clientindex <> 914
					--begin
					--select @Balance = (case when @TotalDays<1 then round(isnull(Balance,0),2) else  round(isnull(balance,0),2) end ) 
					--+ (select round(isnull(Balance,0),2) From Empleaveplan Where Employeeindex = @employeeindex and LeaveType=@LeaveType   
					--			and month(PayrollMonth)=month(@ToDate)  
					--			and year(PayrollMonth)=year(@ToDate) )
					--from   EmpLeavePlan   
					--where  EmployeeIndex=@EmployeeIndex   
					--			and LeaveType=@LeaveType   
					--			and month(PayrollMonth)=month(@fromdate)  
					--			and year(PayrollMonth)=year(@fromdate)
					--end 
					--else 
					--begin
					----------- Haris (2023-12-14) -------------- 
					--select @Balance = (case when @TotalDays<1 then round(isnull(Balance,0),2) else  round(isnull(balance,0),2) end )  
					--from   EmpLeavePlan   
					--where  EmployeeIndex=@EmployeeIndex   
					--			and LeaveType=@LeaveType   
					--			and month(PayrollMonth)=month(@ToDate)  
					--			and year(PayrollMonth)=year(@ToDate) 
					--end
					----------- Haris (2023-12-14) --------------
				   if @Balance=0  
				   begin  
						 if exists (select * from LeaveClientMapping where ClientIndex=@ClientIndex and LeaveType=@LeaveType and isnull(AllowOnline,0)=0 and @clientindex <>947)  
								set @Balance = @MaxDays  
				   end  
				      if exists(select employeeindex from Employee where EmployeeIndex=@EmployeeIndex and @ClientIndex=914 and ServiceStatus<>1 and ServiceEndDate<>convert(date,'1/1/1900')) 
						  begin 
							select @Balance = balance from dbo.fnLeaveBalanceFS(@EmployeeIndex) where leavetype=@LeaveType
						  end
				   if @LeaveType in (8,13,14,24,42,43,74,75,76,105,104,106,110,111) and @clientindex not in (951)  --leavetype 105 added by saif ullah on 5/1/2023  
						 set @Balance=0  
					if @Clientindex=1147 and @Balance < 2 and @leavetype =1 and @lvgroup in (286,413) and @totalDays > 1
						Begin
							set @Msg = 'Retry, this request exceeds the maximum allowed balance, as defined in the company policy....' --[' + ltrim(str(@TotalDays,5,2)) + '][' + ltrim(str(@AdvanceDays,5,2)) + '][' + ltrim(str(@Balance,5,2)) + '][' + ltrim(str(@MaxBalanceNegative,5,2)) + ']' 
							raiserror(@Msg, 16, 1)  
							return  
						 end
				   if @IsCombinedLeave=0 and @EncashDays=0 and @EncashType <> 4  
				   begin  
						 if exists   
									   (      select *   
											 from   tm_LeaveClubbing lc, Employee e   
											 where  e.EmployeeIndex=@EmployeeIndex  
														   and e.ClientIndex=lc.ClientIndex   
														   and lc.LeaveType=@LeaveType   
									   )  
								begin  
									   if @Balance<0  
									   begin  
											 raiserror('Leave clubbing is NOT allowed with negative leave balance',16,1)  
											 return  
									   end  
									   if @TotalDays > round(@Balance,2)--round(@Balance,0)  
									   begin  
											declare @ExcessTotalDays float=@TotalDays-round(@Balance,2)
											 exec   tm_Leaves_Clubbing   
														   @UserId ,  
														   @EmployeeIndex ,  
														   @FromDate ,  
														   @ToDate ,  
														   @LeaveType ,  
														   @LeaveEncashment ,  
														   @LeaveAdjustment ,  
														   @TotalDays ,  
														   @Reason ,  
														   @Address ,  
														   @ContactNo ,  
														   @ContactPerson ,  
														   @RulesByPass ,   
														   @AdvanceDays ,   
														   @EncashType ,   
														   @EncashDays ,   
														   @EncashRemarks ,   
														   @ShortDay  ,   
														   @RulesByPassForcibly ,   
														   @oLeaveType ,  
																						@IsDraft  
											 select 0 LeaveIndex                                    
											 return  
									   end  
								end  
						 else  
								begin  
				   ----                  if @TotalDays>(@Balance + @MaxBalanceNegative)  
				   --                    if @isDraft=0 and @TotalDays>round(@Balance,2) and @LeaveType not in (select leavetype from leaveclientmapping where clientindex=@ClientIndex and isnull(AllowBalance,0)=0) and @RulesByPassForcibly=0  
				   --                    begin  
				   --                          if not   
				   --                          (              
				   --                                 @AdvanceDays>0   
				   --                                 and @TotalDays - round(@Balance,2) = @AdvanceDays   
				   --                                 and @TotalDays<=(round(@Balance,2) + @MaxBalanceNegative)   
				   --                          )  
				   --                          begin  
				   --                                 set @Msg = 'Retry, this request exceeds the maximum allowed balance, as defined in the company policy'   
				   --                                 raiserror(@Msg, 16, 1)  
				   --                                 return  
				   --                          end  
				   --                    end  
						 -- if  @TotalDays>round(@Balance,2) and @LeaveType not in (select leavetype from leaveclientmapping where clientindex=@ClientIndex and isnull(AllowOnline,0)=0 and @clientindex <>947) and @RulesByPassForcibly=0  
							 if  @TotalDays>round(@Balance,2) and @RulesByPassForcibly=0 
									   begin  
															--Saad 10-16-19--  
														   if @DLeaveIndex>0   
															begin   
															declare @TDays smallint  = 0, @Total smallint = 0  
																		select @TDays= sum(TotalDays)  
																		from   LeaveDetail ld, fnLeavePeriod(@EmployeeIndex, @FromDate) lp  
																		where  ld.EmployeeIndex=lp.EmployeeIndex  
																					 and ld.LeaveType=lp.LeaveType  
																					  and ld.LeaveType=@LeaveType  
																						and leavestatus in (1,2,3,7)  
																					 and ld.FromDate between lp.FromDate and lp.ToDate  
																					 and leaveIndex in (@DLeaveIndex)  
																		if  @TotalDays > (round(@Balance,2) + @TDays)  
																		begin  
																			   set @Msg = 'Retry, this request exceeds the maximum allowed balance, as defined in the company policy...'   
																			   raiserror(@Msg, 16, 1)  
																			   return  
																		end  
															  end   
														   --Saad 10-16-19--  
														   else if not   
											 (              
													@AdvanceDays>0   
													and @TotalDays - round(@Balance,2) = @AdvanceDays   
											 )  
											 begin  
												--exec tm_Leaves_Application '', 224774, '7/30/2021','7/30/2021', 8, 0,0,0.5,'','','','',0,0, 1,0,'',0,0,0,0,0, 224345                 
													if not (@TotalDays<=(round(@Balance,2) + @MaxBalanceNegative) )
													begin
														set @Msg = 'Retry, this request exceeds the maximum allowed balance, as defined in the company policy....' --[' + ltrim(str(@TotalDays,5,2)) + '][' + ltrim(str(@AdvanceDays,5,2)) + '][' + ltrim(str(@Balance,5,2)) + '][' + ltrim(str(@MaxBalanceNegative,5,2)) + ']' 
														raiserror(@Msg, 16, 1)  
														return  
													end
											end  
											-- (              
											--        @AdvanceDays>0   
											--        and @TotalDays - round(@Balance,2) = @AdvanceDays   
											--        and @TotalDays<=(round(@Balance,2) + @MaxBalanceNegative)   
											-- )  
											-- begin  
											--        set @Msg = 'Retry, this request exceeds the maximum allowed balance, as defined in the company policy.'   
											--        raiserror(@Msg, 16, 1)  
											--        return  
											--end  
									   end  
								End  
				   end  
				   --- Leave Clubbing ---  
				   ----------------------  
				   -----------------------
					--- Combined Leaves ---
					if @IsCombinedLeave=1 
					begin
						set @Msg=''
						select @Msg= isnull(lcm.LeaveDescription,lt.LeaveDescription) + '[' + rtrim(round(isnull(Balance,0),2)) + '] has sufficient balance, please apply respictive leave.'  
						from   EmpLeavePlan elp, tm_LeaveCombine lc, LeaveClientMapping lcm, LeaveType lt   
						where  elp.EmployeeIndex=@EmployeeIndex   
								and elp.LeaveType=lc.CombineLeaveType
								and lc.ClientIndex=lcm.ClientIndex
								and lc.CombineLeaveType=lcm.LeaveType
								and lcm.LeaveType=lt.LeaveType
								and lc.ClientIndex=@ClientIndex
								and month(elp.PayrollMonth)=month(@ToDate)  
								and year(elp.PayrollMonth)=year(@ToDate)  
								and round(isnull(elp.Balance,0),2)>@TotalDays
						if @Msg<>''
						begin
							raiserror(@Msg, 16, 1)  
							return  
						end
						if exists (
							select sum(round(isnull(Balance,0),2))   
							from   EmpLeavePlan elp, tm_LeaveCombine lc   
							where  elp.EmployeeIndex=@EmployeeIndex   
									and elp.LeaveType=lc.CombineLeaveType
									and lc.ClientIndex=@ClientIndex
									and month(elp.PayrollMonth)=month(@ToDate)  
									and year(elp.PayrollMonth)=year(@ToDate) 
							having sum(round(isnull(Balance,0),2))<@TotalDays
						)
						begin
							set @Msg = 'Retry, this request exceeds the maximum allowed combined balance, as defined in the company policy. .' --[' + ltrim(str(@TotalDays,5,2)) + '][' + ltrim(str(@AdvanceDays,5,2)) + '][' + ltrim(str(@Balance,5,2)) + '][' + ltrim(str(@MaxBalanceNegative,5,2)) + ']' 
							raiserror(@Msg, 16, 1)  
							return  
						end
					end
					--- Combined Leaves ---
					-----------------------
					  if @RulesByPassForcibly=0 and not exists (select * from LeaveRules where (LeaveType =@LeaveType or LeaveType in (6,7,10,11,12,15,27)) and (ClientIndex=@ClientIndex) and (LvGroup =@LvGroup or LvGroup =0)) and @leavetype <>  5  
				   begin  
						 raiserror('This Type of Leave is not Applicable for the current Leave rules that are set for the client.', 16, 1)  
						 return  
				   end  
				   if @RulesByPassForcibly=0 and @ClientIndex = 1043 and not exists (select * from LeaveRules where LeaveType =@LeaveType and ClientIndex=@ClientIndex and (LvGroup =@LvGroup or LvGroup =0)) and @leavetype <>  5  
				   begin  
						 raiserror('This Type of Leave is not Applicable for the current Leave rules...', 16, 1)  
						 return  
				   end  
				   -----------------------------  
				   --- Encashment Validation ---  
				   if @EncashDays>0 and @EncashType in (2,3)  
				   begin  
						 declare @LeaveEncashFrom date, @LeaveEncashTo date, @LeaveEncashTotalDays float=0  
						 select @LeaveEncashFrom=FromDate,   
									   @LeaveEncashTo=ToDate   
						 from   fnLeavePeriod(@EmployeeIndex,@FromDate)   
						 where  LeaveType=@LeaveType  
						 select @LeaveEncashTotalDays = isnull(sum(totaldays) ,0)  
						 from   LeaveDetail  
						 where  employeeindex=@EmployeeIndex  
									   and LeaveStatus  in (1,2,3,7)  
									   and LeaveEncashment=1  
									   and LeaveType=@LeaveType  
									   and convert(date,FromDate) between @LeaveEncashFrom and @LeaveEncashTo  
						 if @RulesByPassForcibly=0 and @MaxEncash < (@LeaveEncashTotalDays+@EncashDays)  
						 begin  
								raiserror('Total Encashment Days Are Greater Than Max Encashment Days', 16, 1)  
								return  
						 end  
						 --if @RulesByPassForcibly=0 and (@TotalDays+@EncashDays)>@Balance // umair,yawer 13-Oct-2020  
						 if @RulesByPassForcibly=0 and (@TotalDays+@EncashDays) > (@Balance - @MaxEncashBalanceCap)  
						 begin  
								set @Msg = 'Retry, this request exceeds the maximum allowed balance, as defined in the company encashment policy'   
								raiserror(@Msg, 16, 1)  
								return  
						 end  
				   end  
				   if @EncashDays>0 and @EncashType in ( 1,5)  
				   begin  
						 set @Msg = 'Retry, encashment not allowed for this type'  
						raiserror(@Msg, 16, 1)  
						 return  
				   end  
				   if @EncashType in (2,3) and not exists (select * from LeaveEncashTypeClient where ClientIndex=@ClientIndex and EncashType=@EncashType )  
				   begin  
						 set @Msg = 'Retry, encashment type is not mapped'  
						 raiserror(@Msg, 16, 1)  
						 return  
				   end  
				   --- Encashment Validation ---  
				   -----------------------------  
				   if (@ShortDay*@DefaultLeaveDaysMultiplier)>@Balance  and @EncashType in (4)  
				   begin  
						 set @Msg = 'Retry, this short leave request exceeds the maximum allowed balance'   
						 raiserror(@Msg, 16, 1)  
						 return  
				   end  
				  --------------Allow 2 half days in one day with different leave type------------------------
				  --------------------------------------------------------------------------------------------
				   declare @HalfDayPass tinyint = 0 
				   if @EncashType in (1) and @Allow2HDInOneDay = 1 
					begin
						select @HalfDayPass  = case when sum(totaldays)<1 and sum(totaldays)>0 then 1 else 0 end from leavedetail where employeeindex = @EmployeeIndex and @FromDate between fromdate and todate
						and leavestatus in (1,2,3)
						and LeaveEncashment<>1  
					end
					if @HalfDayPass = 1 and Exists (   
											select *   
											from   tm_Attendance a  
											where  a.EmployeeIndex=@EmployeeIndex and a.AtDate between @FromDate and @ToDate and (EmpIn is not null or EmpOut is not null )  
														 and Not exists (select * from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate between @FromDate and @ToDate  and AdjLvBal=1)  
											) 
					begin
						 set @Msg = 'The employee (' + ltrim(rtrim(str(@EmployeeIndex))) + ') found partially present within given dates'  
						 raiserror(@Msg, 16, 1)  
						 return  
					end
				  --------------Allow 2 half days in one day with different leave type------------------------
				  --------------------------------------------------------------------------------------------
				   if @EncashType in (1,3,4,5)  
				   begin    
						 if exists (  
								select 1 --rtrim(convert(char,ld.fromdate,107)) + ' to ' + rtrim(convert(char,ld.todate,107)), ld.totaldays, lt.leavedescription   
								from leavedetail ld, leavetype lt  
								Where ld.LeaveType = lt.LeaveType  
								and ld.LeaveStatus in (1,2,3)  
								and (@FromDate between ld.fromdate and ld.todate  
								or @ToDate between ld.fromdate and ld.todate  
								or ld.fromdate between @FromDate and @ToDate  
								or ld.todate between @FromDate and @ToDate   
								)  
								and ld.employeeindex = @EmployeeIndex  
								and not( ld.leavestatus=1 and isnull(ld.leavesubstatus,0) in (38,39))  
								and ld.LeaveEncashment<>1  
						 )  and @HalfDayPass = 0 
						 begin  
								raiserror('Leave(s) Already Entered Within Given Dates!!', 16, 1)  
								return  
						 end  
				   end      
				   if  (select isnull(AdjLvBal,0) from tm_Summary where EmployeeIndex=@EmployeeIndex and AtDate between @FromDate and @ToDate) > @TotalDays and @TotalDays < 1 and @HalfDayPass = 0 and @RulesByPassForcibly=0  and @Restrictdays <> 3
				   begin
						 raiserror('Retry, Days deduction is greater than leave days.', 16, 1)  
						 return  	
				   end 
				  --If @RulesByPassForcibly=0 and exists (select * from LeaveRules where LeaveType=@LeaveType and ClientIndex=@ClientIndex and  (LvGroup=@LvGroup or @LvGroup=0) and @LvMaxAllowedTenure > 0) --isnull(LvDaysCounter,0) > 0 ADD BY SAIF ULLAH ON 4/28/2024 FOR ALMOIZ LEAVE COUNTER UPTO CONFIRMATION
				  -- Begin  
						-- select @TotalLeaves  = Sum(totaldays) from LeaveDetail where EmployeeIndex=@EmployeeIndex and LeaveType=@LeaveType and LeaveStatus in (1,2,3)  
						-- select @LvMaxAllowedTenure = LvMaxAllowedTenure from LeaveRules where LeaveType =@LeaveType and ClientIndex =@ClientIndex and (LvGroup =@LvGroup or LvGroup =0)  
						-- if @RulesByPassForcibly=0 and  ((round(@Balance+@TotalLeaves,2) + @MaxBalanceNegative)  >= @LvMaxAllowedTenure)
						-- begin   
						--		RAISERROR('You have exceeded the tenure limit (%d Days) for this type of leave.', 16, 1, @LvMaxAllowedTenure)  
						--		return  
						-- end  
				  -- end 
				  If @RulesByPassForcibly=0 and exists (select * from LeaveRules where LeaveType=@LeaveType and ClientIndex=@ClientIndex and  (LvGroup=@LvGroup or @LvGroup=0) and @LvAllowInServiceTenure > 0) --isnull(LvDaysCounter,0) > 0 ADD BY SAIF ULLAH ON 4/28/2024 FOR ALMOIZ LEAVE COUNTER UPTO CONFIRMATION
				   Begin  
						 select @TotalLeaves  = Count(*) from LeaveDetail where EmployeeIndex=@EmployeeIndex and LeaveType=@LeaveType and LeaveStatus in (1,2,3)  
						 select @LvAllowInServiceTenure = LvAllowInServiceTenure from LeaveRules where LeaveType =@LeaveType and ClientIndex =@ClientIndex and (LvGroup =@LvGroup or LvGroup =0)  
						 if @RulesByPassForcibly=0 and  (@TotalLeaves >= @LvAllowInServiceTenure) --isnull(LvDaysCounter,0) > 0 ADD BY SAIF ULLAH ON 4/28/2024 FOR ALMOIZ LEAVE COUNTER UPTO CONFIRMATION
						 begin   
								RAISERROR('You have exceeded the tenure limit (%d Time) for this type of leave.', 16, 1, @LvAllowInServiceTenure)  
								return  
						 end  
				   end 
				  If @RulesByPassForcibly=0 and exists (select * from LeaveRules where LeaveType=@LeaveType and ClientIndex=@ClientIndex and ClientIndex <> 1266 and (LvGroup=@LvGroup or @LvGroup=0) and (isnull(LeaveCounter,0) > 0 OR isnull(LvDaysCounter,0) > 0 )) --isnull(LvDaysCounter,0) > 0 ADD BY SAIF ULLAH ON 4/28/2024 FOR ALMOIZ LEAVE COUNTER UPTO CONFIRMATION
				   Begin  
						 select @TotalLeaves  = sum(Totaldays) from LeaveDetail where EmployeeIndex=@EmployeeIndex and LeaveType=@LeaveType and LeaveStatus in (1,2,3)  
						 select @LeaveCounter = LeaveCounter from LeaveRules where LeaveType =@LeaveType and ClientIndex =@ClientIndex and (LvGroup =@LvGroup or LvGroup =0)  
						 if @RulesByPassForcibly=0 and  (@TotalLeaves >= @LeaveCounter  OR isnull(@LvDaysCounter,0) > 0) --isnull(LvDaysCounter,0) > 0 ADD BY SAIF ULLAH ON 4/28/2024 FOR ALMOIZ LEAVE COUNTER UPTO CONFIRMATION
						 begin   
								raiserror('You have exceeded leave counter for this type of leave.', 16, 1)  
								return  
						 end  
				   end  
				    If @RulesByPassForcibly=0 and exists (select * from LeaveRules where LeaveType=@LeaveType and ClientIndex=1266 and (LvGroup=@LvGroup or @LvGroup=0) and (isnull(LeaveCounter,0) > 0 OR isnull(LvDaysCounter,0) > 0 )) --isnull(LvDaysCounter,0) > 0 ADD BY SAIF ULLAH ON 4/28/2024 FOR ALMOIZ LEAVE COUNTER UPTO CONFIRMATION
				   Begin  
						 select @TotalLeaves  = sum(Totaldays) from LeaveDetail where EmployeeIndex=@EmployeeIndex and LeaveType=@LeaveType and LeaveStatus in (1,2,3) and fromdate between DATEFROMPARTS(YEAR(GETDATE()), 1, 1) and DATEFROMPARTS(YEAR(GETDATE()), 12, 31)  
						 select @LeaveCounter = LeaveCounter from LeaveRules where LeaveType =@LeaveType and ClientIndex =@ClientIndex and (LvGroup =@LvGroup or LvGroup =0)  
						 if @RulesByPassForcibly=0 and  (@TotalLeaves >= @LeaveCounter  OR isnull(@LvDaysCounter,0) > 0) --isnull(LvDaysCounter,0) > 0 ADD BY SAIF ULLAH ON 4/28/2024 FOR ALMOIZ LEAVE COUNTER UPTO CONFIRMATION
						 begin   
								raiserror('You have exceeded leave counter for this type of leave.', 16, 1)  
								return  
						 end  
				   end  
				   If @RulesByPassForcibly=0 and @ClientIndex = 925 and @LeaveType in (select LeaveType From LeaveClientMapping Where isnull(AllowOnline,0)=0 and clientindex = 925)
				  begin  
						 set @Msg = 'This Type of Leave is not Applicable for the current Leave rules.'   
						 raiserror(@Msg, 16, 1)  
						 return  
				   end  
					--Comment By Haris-- 22/12/2022---
				 --  Declare @PTodate Date
				 --  Select @PTodate = max(isnull(FromDate,'1900-01-01')) From LeaveDetail Where EmployeeIndex = @EmployeeIndex and LeaveType = @LeaveType and leavestatus not in (4,5,6)
					--If @RulesByPassForcibly=0 and @LeaveType in (select LeaveType From Leaverules Where clientindex = 914 and leavetype = 3 and isnull(ExtendMonth,0) > 0
					--			and lvgroup =@LvGroup)	and @FromDate < @PTodate
				 -- begin  
					--	 set @Msg = 'You have Already Availed Future leave kindly cancel it and Resubmit after Submission of Currect Leave.'   
					--	 raiserror(@Msg, 16, 1)  
					--	 return  
				 --  end  
					--Comment By Haris-- 22/12/2022---
				   if @UserId='-'  
				   set @UserId=@EmployeeIndex  
					  if @IsDraft = 1   
						 begin  
								set @LeaveSubStatus=38  
						 end   
				   select @EnableHDonSaturday= isnull(EnableHDonSaturday,0)
				   from   LeaveRules lr  
				   where  LvGroup=@LvGroup  
						  and LeaveType=@LeaveType  
					if @EnableHDonSaturday = 1
						begin
							declare @ShortDays float=0
							select	@ShortDays = SUM(ISNULL(rd.workhours,0)) 
							from	tm_Roster r, tm_RosterDay rd, tm_VwEmpShift es
							where	r.RosterIndex = rd.RosterIndex
									and es.RosterIndex=r.RosterIndex
									and DATEPART(dw,es.dt) = rd.DayNo 
									and es.EmployeeIndex=@EmployeeIndex
									and es.Dt between @FromDate and @ToDate
							if isnull(@ShortDays,0)>0
							set @TotalDays = @TotalDays - @ShortDays
							If @TotalDays = 0
							Set @TotalDays = 0.5
							--order by es.Dt
							--update tm_RosterDay set WorkHours=0.5 where RosterIndex=1801 and DayNo=6
						end
				   begin transaction  
					--Comment By Saif Ullah-- 10/19/2022
				   --if @EncashType in (1,3,4,5,6,7) and @DLeaveIndex=0   
				   --begin  
						 --select @LeaveIndex=isnull(max(leaveindex)+1,1) from leavedetail   
							--	 select @ProcessNo=isnull(max(ProcessNo)+1,1) from LeaveHistory where LeaveIndex=@LeaveIndex  
						 --insert into leavedetail (leaveindex, employeeindex, leavetype, serialno, fromdate, todate, totaldays, reason, leavestatus, leaveencashment, leaveadjustment, UserEmpIndex, entryby, entrydate, address, contactno, contactperson, ContinualTotalDays, RulesByPassForcibly,LeaveSubStatus,oLeaveType, EncashType,LeaveCat )  
						 --values (@LeaveIndex, @EmployeeIndex, @LeaveType, 1, @FromDate, @ToDate, @TotalDays, @Reason, @LeaveStatus, @LeaveEncashment, @LeaveEncashment, @UserEmpIndex, @UserId, getdate(), @Address, @ContactNo, @ContactPerson, @ContinualTotalDays, @RulesByPassForcibly,@LeaveSubStatus , @oLeaveType, @EncashType,@LeaveCat)  
						 --if @@Error<>0  
						 --begin  
							--	rollback transaction  
							--	return  
						 --end  
						 --insert into leavehistory (LeaveIndex, ProcessNo, LeaveStatus, Remarks, UserEmpIndex, ProcessBy, ProcessDate,LeaveSubStatus )  
						 --values (@LeaveIndex, @ProcessNo, @LeaveStatus, @Reason, @UserEmpIndex, @UserId, GETDATE(),@LeaveSubStatus)  
						 --if @@Error<>0  
						 --begin  
							--	rollback transaction  
							--	return  
						 --end  
				   --end  
				   --Comment By Saif Ullah-- 10/19/2022
					  if @EncashType in (1,3,4,5,6,7) and @DLeaveIndex=0   
				   begin  
						-----------------------
						--- Combined Leaves ---
						if @IsCombinedLeave=1
						begin
							declare @CombineLeaveType tinyint=0
							declare @rTotalDays float=@TotalDays
							declare @SortOrder float=0
							while @rTotalDays>0
							begin
								set @SortOrder=@SortOrder+1
								set @CombineLeaveType=0
								set @Balance=0
								select	@Balance = round(isnull(Balance,0),2),
										@CombineLeaveType = CombineLeaveType
								from	EmpLeavePlan elp, tm_LeaveCombine lc   
								where	elp.EmployeeIndex=@EmployeeIndex   
										and elp.LeaveType=lc.CombineLeaveType
										and lc.ClientIndex=@ClientIndex
										and month(elp.PayrollMonth)=month(@ToDate)  
										and year(elp.PayrollMonth)=year(@ToDate) 
										and lc.SortOrder=@SortOrder
								if @Balance > 0
								begin
									if @rTotalDays<=@Balance
										set @Balance=@rTotalDays
									set @rTotalDays=@rTotalDays-@Balance
									select @LeaveIndex=isnull(max(leaveindex)+1,1) from leavedetail   
									insert into leavedetail (leaveindex, employeeindex, leavetype, serialno, fromdate, todate, totaldays, reason, leavestatus, leaveencashment, leaveadjustment, UserEmpIndex, entryby, entrydate, address, contactno, contactperson, ContinualTotalDays, RulesByPassForcibly,LeaveSubStatus,oLeaveType, EncashType,LeaveCat ,Eventdate)  
									values (@LeaveIndex, @EmployeeIndex, @CombineLeaveType, 1, @FromDate, @ToDate, @Balance, @Reason, 7, @LeaveEncashment, @LeaveEncashment, @UserEmpIndex, @UserId, getdate(), @Address, @ContactNo, @ContactPerson, @ContinualTotalDays, @RulesByPassForcibly,0 , @LeaveType, @EncashType,@LeaveCat,@Eventdate)  
									If exists (select clientindex from tm_LeaveCombine where clientindex = @clientindex and combineleavetype in  (1,2))
									Begin
									Exec tm_leaves_calculation @Employeeindex,@Leavetype,@Fromdate
									End
									if @@Error<>0  
									begin  
										rollback transaction  
										return  
									end  
								end
								else
								set @rTotalDays=0
							end
						end
						--- Combined Leaves ---
						-----------------------
						 select @LeaveIndex=isnull(max(leaveindex)+1,1) from leavedetail   
						 select @ProcessNo=isnull(max(ProcessNo)+1,1) from LeaveHistory where LeaveIndex=@LeaveIndex  
						 insert into leavedetail (leaveindex, employeeindex, leavetype, serialno, fromdate, todate, totaldays, reason, leavestatus, leaveencashment, leaveadjustment, UserEmpIndex, entryby, entrydate, address, contactno, contactperson, ContinualTotalDays, RulesByPassForcibly,LeaveSubStatus,oLeaveType, EncashType,LeaveCat ,EventDate)  
						 values (@LeaveIndex, @EmployeeIndex, @LeaveType, 1, @FromDate, @ToDate, @TotalDays, @Reason, @LeaveStatus, @LeaveEncashment, @LeaveEncashment, @UserEmpIndex, @UserId, getdate(), @Address, @ContactNo, @ContactPerson, @ContinualTotalDays, @RulesByPassForcibly,@LeaveSubStatus , @oLeaveType, @EncashType,@LeaveCat,@Eventdate)  
						 if @@Error<>0  
						 begin  
								rollback transaction  
								return  
						 end  
						 insert into leavehistory (LeaveIndex, ProcessNo, LeaveStatus, Remarks, UserEmpIndex, ProcessBy, ProcessDate,LeaveSubStatus ,EventDate)  
						 values (@LeaveIndex, @ProcessNo, @LeaveStatus, @Reason, @UserEmpIndex, @UserId, GETDATE(),@LeaveSubStatus,@Eventdate)  
						 if @@Error<>0  
						 begin  
								rollback transaction  
								return  
						 end  
				   end  
				   if @EncashType in (2,3) and @EncashDays>0 and @DLeaveIndex=0  
				   begin  
						 select @LeaveIndex=isnull(max(leaveindex)+1,1) from leavedetail   
							select @ProcessNo=isnull(max(ProcessNo)+1,1) from LeaveHistory where LeaveIndex=@LeaveIndex  
						 --select leavesubstatus,* from leavedetail where employeeindex=124623  
						 insert into leavedetail (leaveindex, employeeindex, leavetype, serialno, fromdate, todate, totaldays, reason, leavestatus, leaveencashment, leaveadjustment, UserEmpIndex, entryby, entrydate, address, contactno, contactperson, ContinualTotalDays, RulesByPassForcibly,LeaveSubStatus, oLeaveType,LeaveCat ,EventDate)  
						 values (@LeaveIndex, @EmployeeIndex, @LeaveType, 1, @FromDate, @FromDate, @EncashDays, @EncashRemarks, @LeaveStatus, 1, 0, @UserEmpIndex, @UserId, getdate(), '', '', '', 0, @RulesByPassForcibly,@LeaveSubStatus, @oLeaveType,@LeaveCat ,@Eventdate)  
						 if @@Error<>0  
						 begin  
								rollback transaction  
								return  
						 end  
						 insert into leavehistory (LeaveIndex, ProcessNo, LeaveStatus, Remarks, UserEmpIndex, ProcessBy, ProcessDate,LeaveSubStatus,EventDate)  
						 values (@LeaveIndex, @ProcessNo, 1, @EncashRemarks, @UserEmpIndex, @UserId, GETDATE(),@LeaveSubStatus,@Eventdate)  
						 if @@Error<>0  
						 begin  
								rollback transaction  
								return  
						 end  
				   end  
					  if @isDraft=1 and @DLeaveIndex>0  
					  begin  
				 set    @LeaveIndex=@DLeaveIndex  
				 select @ProcessNo=isnull(max(ProcessNo)+1,1) from LeaveHistory where LeaveIndex=@LeaveIndex  
				   update leavedetail   
				   set   leavetype=@Leavetype,   
					  FromDate=@FromDate ,   
					  ToDate=@ToDate,   
					  TotalDays=@Totaldays,  
					  Reason=@Reason,   
					  Address=@Address,   
					  ContactNo=@ContactNo,   
					  ContactPerson=@ContactPerson  
				   where  LeaveIndex=@LeaveIndex  
					and EmployeeIndex=@EmployeeIndex  
				  if @@Error<>0  
				   begin  
				   rollback transaction  
				   return  
				   end  
				 insert into leavehistory (LeaveIndex, ProcessNo, LeaveStatus, Remarks, UserEmpIndex, ProcessBy, ProcessDate, leavesubstatus,EventDate)  
				 values (@LeaveIndex, @ProcessNo, 1, @Reason, @UserEmpIndex, @UserId, GETDATE(),38,@Eventdate)  
				 if @@Error<>0  
				 begin  
				 rollback transaction  
				 return  
				 end  
					   end  
					  if @DLeaveIndex>0 and @isDraft=0  
					  begin  
					  set    @LeaveIndex=@DLeaveIndex  
					  select @ProcessNo=isnull(max(ProcessNo)+1,1) from LeaveHistory where LeaveIndex=@LeaveIndex  
					  update leavedetail   
					  set   leavetype=@Leavetype,   
								  FromDate=@FromDate ,   
								  ToDate=@ToDate,   
								  TotalDays=@Totaldays,  
								  Reason=@Reason,   
								  Address=@Address,   
								  ContactNo=@ContactNo,   
								  ContactPerson=@ContactPerson,  
								  LeaveSubStatus=1  
					  where  LeaveIndex=@LeaveIndex  
								  and EmployeeIndex=@EmployeeIndex  
								if @@Error<>0  
						 begin  
							rollback transaction  
							return  
						 end  
						 insert into leavehistory (LeaveIndex, ProcessNo, LeaveStatus, Remarks, UserEmpIndex, ProcessBy, ProcessDate, leavesubstatus,EventDate)  
						 values (@LeaveIndex, @ProcessNo, 1, @Reason, @UserEmpIndex, @UserId, GETDATE(),1,@Eventdate)  
						 if @@Error<>0  
						 begin  
							rollback transaction  
							return  
						 end  
						 end  
				   commit transaction  
				  --- for Sapphire Shift supervisor 2 tier leave by Jawad (2021-11-18) -------------------- 
				  --if (select isnull(atgroup,0) from employee where employeeindex = @EmployeeIndex) in (563, 546) --Z Shift Employee 
					 -- begin 
					 -- select @lvgroup = isnull(lvgroup,@Lvgroup) from [FnShiftSupervisorGroup]( @EmployeeIndex,'1900-01-01') 
					 -- end 
				  --- for Sapphire Shift supervisor 2 tier leave by Jawad (2021-11-18) -------------------- 
			   --------------------------------  
					   -- update by umair Oct 4, 2019  
						 -- to check new Decibel5.0 todo  
					   --exec todo_Main_Set  @EmployeeIndex , @ToDoComponent , @ComponentIndex , @ToDoType , @UserIndex , @UserEmpIndex   
						 if @LeaveStatus = 1  and @isDraft=0  
						 begin  
								   if exists (select * From LeaveSubStatusGroup where clientIndex=isnull(@ClientIndex,0) and (lvgroup=@lvgroup or lvgroup=0) and (LeaveType=@LeaveType Or Leavetype = 0))  
				  Begin 
				  set @ToDoType=(select isnull(ToDoTypeNext, 1) 
				  From LeaveSubStatusGroup where clientIndex=@ClientIndex and leaveSubStatus=0 and (lvgroup=@lvgroup or lvgroup=0) and (LeaveType=@LeaveType Or Leavetype = 0))  
					if isnull(@ToDoType,0)=0
						 set @ToDoType=1  
				  end
				  else     
					 set @ToDoType=1    
					 exec todo_Main_Set @EmployeeIndex, 1, @LeaveIndex,@ToDoType,0,@EmployeeIndex -- 1=@ToDoComponent &amp;amp; 2=@ToDoType  
				 end  
					   -- update by umair Oct 4, 2019  
						 -- to check new Decibel5.0 todo  
						 --------------------------------  
				   set @TotalDays=0  
				   exec tm_Leaves_Calculation @EmployeeIndex , @LeaveType , @FromDate
				   exec tm_Leaves_Calculation @EmployeeIndex , @LeaveType , @ToDate				   
				 -------just edited--------------------  
					 declare @yFromDate as date  
					  set @yFromDate = DATEADD(y,1,@FromDate)  
					 exec tm_Leaves_Calculation @EmployeeIndex , @LeaveType , @yFromDate   
				-------just edited--------------------  
				 -------Edit By Saif Ullah for sapphire for combine leave refresh 2/25/2023--------------------  
					 If exists (select clientindex from tm_leavecombine where clientindex = @clientindex and combineleavetype = 1)
					 begin 
					 exec tm_Leaves_Calculation @EmployeeIndex , 1 , @FromDate 
					 end
				-------Edit By Saif Ullah for sapphire for combine leave refresh--------------------  
				 -------Edit By Saif Ullah for sapphire for combine leave refresh 2/25/2023--------------------  
					 If exists (select clientindex from tm_leavecombine where clientindex = @clientindex and combineleavetype = 2)
					 begin 
					 exec tm_Leaves_Calculation @EmployeeIndex , 2 , @FromDate 
					 end
				-------Edit By Saif Ullah for sapphire for combine leave refresh--------------------  
				 set @FromDate = dateadd(day,-7,@FromDate)  
				 set @ToDate = dateadd(day,7,@ToDate)  
				   exec tm_Summary_Refresh @ClientIndex,@FromDate,@ToDate,@EmployeeIndex,0,0,0,0,0,0,0,0,1192  
				   select @LeaveIndex LeaveIndex, @LeaveStatus LeaveStatus,@ClientType Clienttype,@ClientLeaveApproval ClientLeaveApproval  
				   --------------------------------------------changes-----------------------------  
				   select isnull(CellNo,'-') CellNo,rtrim(ltrim(EmployeeName)) EmployeeName,ClientIndex   
				   from Employee where EmployeeIndex =@EmployeeIndex  
				   -------------------------------------------------------------------------------- 
End


