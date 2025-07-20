CREATE procedure [dbo].[tm_AtCl_SetData_Hamdard] -- 2695,242604,'',224345  
    @PeriodIndex int,  
    @EmployeeIndex int,  
    @Remarks nvarchar(100)='',  
    @UserEmpIndex int  
   as  
         -- exec tm_AtCl_SetData 1030, 164471, 'test', 1  
    Begin       
     declare @Msg varchar(100) =''  
     declare @AtClosingStatus tinyint = 2 , @ssStatus tinyint=8   
     declare @FromDate datetime,   
       @ToDate datetime,   
       @PeriodGroup smallint,   
       @PeriodStatus tinyint,  
       @PayrollMonth tinyint,  
       @PayrollYear smallint,  
       @TotalDays float  
     declare @TotalOTEdit tinyint=0,  
		@Header1 varchar(1000)='',  
		@Header2 varchar(1000)='' ,   
		@ClientIndex smallint=0,  
		@ApplyAbsentSandwich tinyint=0,  
		@CalculateAttendanceAllowance tinyint=0,  
		@SplitOTWD tinyint=0,   
		@CalculateShiftPremium tinyint=0,   
		@CalculateMealAllowance tinyint=0,   
		@CalculateOvertimeAmount tinyint=0,  
		@CalculateNightShiftValue tinyint=0,  
		@ClosingOTException nvarchar(1000),  
		@AbsentDeduction tinyint=0,  
		@IsEmpRosterWorkHour tinyint = 0,  
		@IsForceAbsent tinyint = 0,  
		@IsBasedOnWDFormula tinyint = 0,  
		@CalculateTransportAllowance tinyint = 0  
Declare @AdjRuleIndex int=0,  
		@TotalOvertimeAmount float=0,  
		@EmpRosterWorkHour float = 0,
        @unitindex int = 0,
		@locationindex int = 0
     select  @FromDate = p.FromDate,  
        @ToDate = p.ToDate,  
        @PeriodGroup = p.PeriodGroup,  
        @PeriodStatus = p.PeriodStatus,  
        @PayrollMonth= ISNULL(p.PayrollMonth,0),  
        @PayrollYear = ISNULL(p.PayrollYear,0),  
        @ClientIndex = pg.ClientIndex  
     from    tm_Period p, tm_PeriodGroup pg  
     where   p.PeriodIndex=@PeriodIndex   
        and p.PeriodGroup=pg.PeriodGroup  
     IF OBJECT_ID('tempdb.dbo.#ClosingSummary', 'U') IS NOT NULL  
     DROP TABLE #ClosingSummary;   
     select * into #ClosingSummary from tm_summary where employeeindex = @EmployeeIndex and atdate between @FromDate and @ToDate  
     if exists (select atcindex from tm_atc where employeeindex=@EmployeeIndex and atdate<=@Todate and atcstatus=1)  
     begin  
      insert into tm_ATChistory (ATCIndex, ProcessNo, atcStatus, Remarks, UserEmpIndex, ProcessDate)  
      select atcindex, 100, 6, 'Deleted on Attendance Closing', @UserEmpIndex, getdate()    
      from tm_atc a  
      where EmployeeIndex=@EmployeeIndex and atdate<=@Todate and atcstatus=1  
      if @@Error<>0  
      begin  
       return  
      end  
      update  tm_ATC  
      set     ATCStatus=6  
      where   Employeeindex=@EmployeeIndex  
        and atdate<=@Todate  
        and atcstatus=1  
      if @@Error<>0  
      begin  
       return  
      end  
     end  
     if exists (select LeaveIndex from LeaveDetail where employeeindex=@EmployeeIndex and FromDate<=@ToDate and LeaveStatus=1)  
     begin  
      set @Msg = 'Pending Leaves Found! [EmpIndex:' + ltrim(str(@EmployeeIndex)) + '], Please approve.'  
      raiserror (@Msg,16,1)  
      return  
     end  
     select  @TotalOTEdit = isnull(TotalOTEdit,0),  
       @ApplyAbsentSandwich = isnull(ApplyAbsentSandwich,0),  
       @CalculateAttendanceAllowance = isnull(CalculateAttendanceAllowance,0),  
       @SplitOTWD  = isnull(SplitOTWD,0),   
       @CalculateShiftPremium  = isnull(CalculateShiftPremium,0),   
       @CalculateMealAllowance  = isnull(CalculateMealAllowance,0),   
       @CalculateOvertimeAmount  = isnull(CalculateOvertimeAmount,0),  
       @CalculateNightShiftValue  = isnull(CalculateNightShiftValue,0),  
       @Header1 = isnull(Header1,''),  
       @Header2 = isnull(Header2,''),  
       @ClosingOTException=ClosingOTException,  
       @AbsentDeduction= isnull(AbsentDeduction,0),  
       @IsEmpRosterWorkHour  = isnull(IsEmpRosterWorkHour,0),  
       @IsForceAbsent  = isnull(IsForceAbsent,0),  
       @IsBasedOnWDFormula  = isnull(IsBasedOnWDFormula,0),  
       @CalculateTransportAllowance = isnull(CalculateTransportAllowance,0)  
     from    tm_AtClosingRules  
     where   ClientIndex=@ClientIndex  
      --alter table tm_AtClosingRules add IsForceAbsent tinyint , IsBasedOnWDFormula tinyint  
     set @TotalDays = DATEDIFF(dd, @FromDate, @ToDate) + 1   
     if len(isnull(@ClosingOTException,'')) > 0  
     begin  
      --exec tm_AtClosingOTException @PeriodIndex , @EmployeeIndex , @Remarks, @UserIndex  
      exec tm_AtCl_OTException @PeriodIndex , @EmployeeIndex , @Remarks, @UserEmpIndex  
     end  
    select @unitindex = unitindex from employee where employeeindex  =  @EmployeeIndex
	select @locationindex = locationindex from employee where employeeindex = @employeeindex
     select @AdjRuleIndex=AdjRuleIndex   
     from tm_VwEmpAdjRule   
     where EmployeeIndex=@EmployeeIndex--210399  
     if @IsEmpRosterWorkHour > 0   
      select @EmpRosterWorkHour = isnull(WorkHours,0) from fnEmployeeRosterWorkHours(@EmployeeIndex,@FromDate,@ToDate)  
     if @CalculateShiftPremium = 1  
     begin  
      declare @RosterList1 varchar(100),  
        @RosterList1Count float,  
        @RosterList2 varchar(100),  
        @RosterList2Count float,  
        @ShiftPremiumValue float  
      select @RosterList1=isnull(RosterList1,'0') ,  
        @RosterList1Count=isnull(RosterList1Count,0) ,  
        @RosterList2=isnull(RosterList2,'-1') ,  
        @RosterList2Count=isnull(RosterList2Count,0) ,  
        @ShiftPremiumValue=isnull(ShiftPremiumValue,0)  
      from tm_ShiftPremiumRule  
      where AdjRuleIndex=@AdjRuleIndex  
      if exists (  
         select count(*)   
         from #ClosingSummary   
         where RosterIndex in (select col1 from fnParseArray(@RosterList1,','))  
         having count(*)<@RosterList1Count  
         )  
      begin  
       set @ShiftPremiumValue=0  
      end  
      if exists (  
         select  count(*)   
         from    #ClosingSummary   
         where    RosterIndex in (select col1 from fnParseArray(@RosterList2,','))  
         having count(*)<@RosterList2Count  
         )  
      begin  
       set @ShiftPremiumValue=0  
      end  
     end  
     if @CalculateNightShiftValue = 1  
     begin  
      declare @RosterList varchar(100)='',  
        @TotalNightShiftAmount float=0,  
        @NSStartTime datetime,   
        @NSEndTime datetime,   
        @NSMinHours float=0,   
        @NSEntitlementHours float=0  
      select @RosterList=isnull(RosterList,'0'),  
        @TotalNightShiftAmount=isnull(NightShiftValue,0),  
        @NSStartTime = isnull(StartTime,''),  
        @NSEndTime = isnull(EndTime,''),  
        @NSMinHours = isnull(MinHours,0),  
        @NSEntitlementHours = isnull(EntitlementHours,0)  
      from    tm_NightShiftRule  
      where   AdjRuleIndex=@AdjRuleIndex  
      if @RosterList <> '0'  
      begin  
       select  @TotalNightShiftAmount=@TotalNightShiftAmount*count(*)   
       from    #ClosingSummary   
       where    RosterIndex in (select col1 from fnParseArray(@RosterList,','))  
      end  
      if @NSEntitlementHours > 0 and exists (select * from tm_NightShiftEmp where EmployeeIndex=@EmployeeIndex and AtDate between @FromDate and @ToDate)  
       begin  
        select @TotalNightShiftAmount = @TotalNightShiftAmount * count(*) from tm_NightShiftEmp where EmployeeIndex=@EmployeeIndex and AtDate between @FromDate and @ToDate  
       end  
      else   
       set @TotalNightShiftAmount = 0   
     end  
     if @CalculateOvertimeAmount = 1  
     begin  
      declare @OTHourSlab1 float, @OTHourSlab1Rate float,   
        @OTHourSlab2 float, @OTHourSlab2Rate float,  
        @OTHourSlab3 float, @OTHourSlab3Rate float,   
        @OTHourSlab4 float, @OTHourSlab4Rate float,  
        @MultiplierOD float, @MultiplierGD float  
      select  @OTHourSlab1 = isnull(OTHourSlab1,0),   
        @OTHourSlab1Rate = isnull(OTHourSlab1Rate,0),   
        @OTHourSlab2 = isnull(OTHourSlab2,0),   
        @OTHourSlab2Rate = isnull(OTHourSlab2Rate,0),  
        @OTHourSlab3 = isnull(OTHourSlab3,0),   
        @OTHourSlab3Rate = isnull(OTHourSlab3Rate,0),   
        @OTHourSlab4 = isnull(OTHourSlab4,0),   
        @OTHourSlab4Rate = isnull(OTHourSlab4Rate,0),  
        @MultiplierOD = isnull(MultiplierOD,0),  
        @MultiplierGD = isnull(MultiplierGD,0)  
      from    tm_OTRules   
      where   AdjRuleIndex=@AdjRuleIndex   
      if @OTHourSlab1>0  
      begin  
       select @TotalOvertimeAmount = count(*) * @OTHourSlab1Rate  
       from #ClosingSummary   
       where    ((ApOTHH*60+ApOTMI)/60.0) > 0  
         and ((ApOTHH*60+ApOTMI)/60.0) <= @OTHourSlab1  
       select  @TotalOvertimeAmount = @TotalOvertimeAmount + (count(*) * @OTHourSlab2Rate)  
       from    #ClosingSummary   
       where ((ApOTHH*60+ApOTMI)/60.0) > @OTHourSlab1  
         and ((ApOTHH*60+ApOTMI)/60.0) <= @OTHourSlab2  
       select @TotalOvertimeAmount = @TotalOvertimeAmount + (count(*) * @OTHourSlab3Rate)  
       from #ClosingSummary   
       where  ((ApOTHH*60+ApOTMI)/60.0) > @OTHourSlab2  
         and ((ApOTHH*60+ApOTMI)/60.0) <= @OTHourSlab3  
       select  @TotalOvertimeAmount = @TotalOvertimeAmount + (count(*) * @OTHourSlab4Rate)  
       from    #ClosingSummary   
       where    ((ApOTHH*60+ApOTMI)/60.0) > @OTHourSlab3  
         and ((ApOTHH*60+ApOTMI)/60.0) <= @OTHourSlab4  
       if @MultiplierGD=2  
       begin  
        select    @TotalOvertimeAmount = @TotalOvertimeAmount + (count(*) * @OTHourSlab1Rate)  
        from      #ClosingSummary   
        where   ((ApOTHH*60+ApOTMI)/60.0) > 0  
           and ((ApOTHH*60+ApOTMI)/60.0) <= @OTHourSlab1  
           and isnull(IsGazetted,0)=1  
        select    @TotalOvertimeAmount = @TotalOvertimeAmount + (count(*) * @OTHourSlab2Rate)  
        from      #ClosingSummary   
        where    ((ApOTHH*60+ApOTMI)/60.0) > @OTHourSlab1  
           and ((ApOTHH*60+ApOTMI)/60.0) <= @OTHourSlab2  
           and isnull(IsGazetted,0)=1  
        select    @TotalOvertimeAmount = @TotalOvertimeAmount + (count(*) * @OTHourSlab3Rate)  
        from      #ClosingSummary   
        where    ((ApOTHH*60+ApOTMI)/60.0) > @OTHourSlab2  
           and ((ApOTHH*60+ApOTMI)/60.0) <= @OTHourSlab3  
           and isnull(IsGazetted,0)=1  
        select    @TotalOvertimeAmount = @TotalOvertimeAmount + (count(*) * @OTHourSlab4Rate)  
        from      #ClosingSummary   
        where     ((ApOTHH*60+ApOTMI)/60.0) > @OTHourSlab3  
           and ((ApOTHH*60+ApOTMI)/60.0) <= @OTHourSlab4  
           and isnull(IsGazetted,0)=1  
       end  
      end  
     end  
     if @CalculateAttendanceAllowance = 1  
     begin  
      declare @LCCount float,  
        @LCMinutes float,  
        @EGCount float,  
        @EGMinutes float,  
        @LCEGCount float,  
        @LCEGMinutes float,  
        @LVCount1 float,  
        @LVType1 varchar(100),  
        @LVCount2 float,  
        @LVType2 varchar(100),  
        @AbsentCount float,  
        @PresentCount float,  
        @AllowanceValue float,  
        @AllowanceFormula varchar(2000)=''  
      select  @LCCount=isnull(LCCount,-1) ,  
        @LCMinutes=isnull(LCMinutes,-1) ,  
        @EGCount=isnull(EGCount,-1) ,  
        @EGMinutes=isnull(EGMinutes,-1) ,  
        @LCEGCount=isnull(LCEGCount,-1) ,  
        @LCEGMinutes=isnull(LCEGMinutes,-1) ,  
        @LVCount1=isnull(LVCount1,-1) ,  
        @LVType1=isnull(LVType1,'0') ,  
        @LVCount2=isnull(LVCount2,-1) ,  
        @LVType2=isnull(LVType2,'0') ,  
        @AbsentCount=isnull(AbsentCount,0),  
        @PresentCount = isnull(PresentCount,-1),  
        @AllowanceValue=isnull(AllowanceValue,0),  
        @AllowanceFormula = isnull(AllowanceFormula,'')  
      from    tm_GoodAttendanceRule  
      where   AdjRuleIndex=@AdjRuleIndex  
      if Len(@AllowanceFormula)>0  
      begin  
       DECLARE @SQLString nvarchar(2000)  
       DECLARE @ParmDefinition nvarchar(500)  
       set @AllowanceFormula=REPLACE(@AllowanceFormula, '[EmpIndex]', ltrim(str(@EmployeeIndex)))  
       set @AllowanceFormula=REPLACE(@AllowanceFormula, '[FromDate]', '''' + ltrim((@FromDate)) + '''')  
       set @AllowanceFormula=REPLACE(@AllowanceFormula, '[ToDate]', '''' + ltrim((@ToDate)) + '''')  
       SET @AllowanceValue=0  
       SET @SQLString =  N'' + @AllowanceFormula + ''  
       SET @ParmDefinition = N'@Allowance nvarchar(25) OUTPUT'  
       EXECUTE sp_executesql @SQLString, @ParmDefinition, @Allowance = @AllowanceValue OUTPUT  
       if @@Error<>0  
       begin  
        set @SQLString='Formula Error - Employee Index : [' + str(@EmployeeIndex) + '] '   
        raiserror (@SQLString, 16,1)  
        return  
       end  
      end  
      if exists (  
         select  count(*)   
         from    #ClosingSummary   
         where    (IsAbsent=1  or leavetype in (5,28))  
         having count(*)>@AbsentCount  
         )  
      begin  
       set @AllowanceValue=0  
      end  
      if @AllowanceValue>0   
       and @LCMinutes<>-1  
       and Exists (  
          select  sum(AdjLC*60)   
          from    #ClosingSummary   
          where    AdjLC>0  
          having sum(AdjLC*60)>@LCMinutes  
          )  
      begin  
       set @AllowanceValue=0  
      end  
      if @AllowanceValue>0   
       and @LVCount1<>-1  
       and Exists (  
          select  count(*)   
          from    #ClosingSummary   
          where    isLeave=1  
            and LeaveType in (select col1 from dbo.fnParseArray(@LVType1,','))  
            and isnull(leavestatus,1) <> 7    
          having  count(*)>@LVCount1  
          )  
      begin  
       set @AllowanceValue=0  
      end  
      if @AllowanceValue>0   
       and @LVCount2<>-1  
       and Exists (  
          select  count(*)   
          from    #ClosingSummary   
          where    isLeave=1  
            and LeaveType in (select col1 from dbo.fnParseArray(@LVType2,','))  
            and isnull(leavestatus,1) <> 7   
          having  count(*)>@LVCount2  
          )  
      begin  
       set @AllowanceValue=0  
      end  
      if @AllowanceValue>0   
       and Exists  (  
          select  sum(AdjLC*60)+sum(adjeg*60)   
          from    #ClosingSummary   
          where  (AdjLC>0 or AdjEG>0)  
            and @LCEGMinutes <> -1  
          having sum(AdjLC*60)+sum(adjeg*60) >@LCEGMinutes  
          )  
      begin  
       set @AllowanceValue=0  
      end  
      if  @AllowanceValue>0   
       and Exists   
        (  
        select  count(*)   
        from    #ClosingSummary   
        where  (  
            IsAttendance=1  
            or  
            (isLeave=1 and LeaveType in (select col1 from dbo.fnParseArray(isnull(@LVType1,'-1'),',')))  
           )  
          and @PresentCount <> -1  
        having   count(*)<@PresentCount  
        )  
      begin  
       set @AllowanceValue=0  
      end  
     end  
     if @ApplyAbsentSandwich=1   
      and exists (  
          select    s.EmployeeIndex                
          from      #ClosingSummary s, #ClosingSummary pds, #ClosingSummary nds, VwEmpDetail e  
          where    s.IsAttendance=0   
          and s.IsHoliday=1  
          and s.IsLeave=0  
          and dateadd(dd,-1,s.AtDate) = pds.AtDate   
          and dateadd(dd,1,s.AtDate) = nds.AtDate   
          and s.EmployeeIndex=pds.EmployeeIndex  
          and s.EmployeeIndex=nds.EmployeeIndex   
          and s.EmployeeIndex=e.EmployeeIndex  
          and exists (select EmployeeIndex from #ClosingSummary where EmployeeIndex=s.EmployeeIndex and AtDate=(select Max(atdate) from #ClosingSummary where EmployeeIndex=s.EmployeeIndex and AtDate<s.AtDate and IsHoliday=0) and IsAbsent=1 and EmployeeIndex=@EmployeeIndex)  
          and exists (select EmployeeIndex from #ClosingSummary where EmployeeIndex=s.EmployeeIndex and AtDate=(select MIN(atdate) from #ClosingSummary where EmployeeIndex=s.EmployeeIndex and AtDate>s.AtDate and IsHoliday=0) and IsAbsent=1 and EmployeeIndex=@EmployeeIndex)  
          --and s.employeeIndex=@EmployeeIndex  
          --and s.AtDate>=@FromDate  
          --and s.AtDate<=@ToDate  
         )  
     begin  
      insert  into tm_SummaryAbsent  (EmployeeIndex, AbsentDate, UserEmpIndex, PostDate, IsAbsentSandwich, IsLeaveSandwich  )  
      select    s.EmployeeIndex,s.atdate,@UserEmpIndex,getDate(),1,0                 
      from      #ClosingSummary s, #ClosingSummary pds, #ClosingSummary nds, VwEmpDetail e  
      where    s.IsAttendance=0   
              and s.IsHoliday=1  
              and s.IsLeave=0  
              and dateadd(dd,-1,s.AtDate) = pds.AtDate   
              and dateadd(dd,1,s.AtDate) = nds.AtDate   
              and s.EmployeeIndex=pds.EmployeeIndex  
              and s.EmployeeIndex=nds.EmployeeIndex   
              and s.EmployeeIndex=e.EmployeeIndex  
                         and exists (select EmployeeIndex from #ClosingSummary where EmployeeIndex=s.EmployeeIndex and AtDate=(select Max(atdate) from #ClosingSummary where EmployeeIndex=s.EmployeeIndex and AtDate<s.AtDate and IsHoliday=0) and IsAbsent=1 
and EmployeeIndex=@EmployeeIndex)  
                         and exists (select EmployeeIndex from #ClosingSummary where EmployeeIndex=s.EmployeeIndex and AtDate=(select MIN(atdate) from #ClosingSummary where EmployeeIndex=s.EmployeeIndex and AtDate>s.AtDate and IsHoliday=0) and IsAbsent=1 
and EmployeeIndex=@EmployeeIndex)  
      exec tm_Summary_Refresh @ClientIndex,@FromDate,@ToDate,@EmployeeIndex,0,0,0,0,0,0,0,0,1192  
      set @Msg = 'Sandwich absent  Found! [EmpIndex:' + ltrim(str(@EmployeeIndex)) + ']'  
      raiserror (@Msg,16,1)  
      return  
     end  
     if @CalculateMealAllowance = 1  
     begin  
      declare @MealLVType varchar(100),  
        @MealAllowanceValue float,  
        @MealAllowance float,  
        @TotalDeductions float=0,  
        @MealAllowanceFormula varchar(max) = ''  
      select  @MealLVType=isnull(LVType,'0') ,  
        @MealAllowanceValue=isnull(AllowanceValue,0),  
        @MealAllowanceFormula = isnull(MealAllowanceFormula,'')  
      from    tm_MealAllowanceRule   
      where   AdjRuleIndex=@AdjRuleIndex  
      select @TotalDeductions=count(*)   
      from    #ClosingSummary   
      where   (  
          IsAbsent=1   
          or   
          LeaveType in (select col1 from dbo.fnParseArray(@MealLVType,','))  
          )  
      select @MealAllowance=@MealAllowanceValue-((@MealAllowanceValue/(datediff(dd,@FromDate,@ToDate)+1))*@TotalDeductions)  
      if isnull(@MealAllowance,-1)<0  
       set @MealAllowance=0  
      if Len(@MealAllowanceFormula)>0 --and @MealAllowance = 0   
      begin  
       DECLARE @SQLStringMeal nvarchar(2000)  
       DECLARE @ParmDefinitionMeal nvarchar(500)  
       set @MealAllowance=0               
       set @MealAllowanceFormula=REPLACE(@MealAllowanceFormula, '[EmpIndex]', ltrim(str(@EmployeeIndex)))  
       set @MealAllowanceFormula=REPLACE(@MealAllowanceFormula, '[FromDate]', '''' + ltrim((@FromDate)) + '''')  
       set @MealAllowanceFormula=REPLACE(@MealAllowanceFormula, '[ToDate]', '''' + ltrim((@ToDate)) + '''')  
       SET @SQLStringMeal =  N'' + @MealAllowanceFormula + ''  
       SET @ParmDefinitionMeal = N'@Allowance nvarchar(25) OUTPUT'  
       EXECUTE sp_executesql @SQLStringMeal, @ParmDefinitionMeal, @Allowance = @MealAllowance OUTPUT  
       if @@Error<>0  
       begin  
        set @SQLStringMeal='Formula Error (Meal Allowance)- Employee Index : [' + str(@EmployeeIndex) + '] '   
        raiserror (@SQLStringMeal, 16,1)  
        return  
       end  
      end  
     end  
     if @CalculateTransportAllowance = 1  
     begin  
      declare   
        @TransportAllowanceValue float,  
        @TransportAllowance float,  
        @TransportAllowanceFormula varchar(max) = ''  
      select    
        @TransportAllowanceValue=isnull(AllowanceValue,0),  
        @TransportAllowanceFormula = isnull(TransportAllowanceFormula,'')  
      from    tm_TransportAllowanceRule   
      where   AdjRuleIndex=@AdjRuleIndex  
      if Len(@TransportAllowanceFormula)>0   
      begin  
       DECLARE @SQLStringTransport nvarchar(2000)  
       DECLARE @ParmDefinitionTransport nvarchar(500)  
       set @TransportAllowanceFormula=REPLACE(@TransportAllowanceFormula, '[EmpIndex]', ltrim(str(@EmployeeIndex)))  
       set @TransportAllowanceFormula=REPLACE(@TransportAllowanceFormula, '[FromDate]', '''' + ltrim((@FromDate)) + '''')  
       set @TransportAllowanceFormula=REPLACE(@TransportAllowanceFormula, '[ToDate]', '''' + ltrim((@ToDate)) + '''')  
       SET @SQLStringTransport =  N'' + @TransportAllowanceFormula + ''  
       SET @ParmDefinitionTransport = N'@Allowance nvarchar(25) OUTPUT'  
       EXECUTE sp_executesql @SQLStringTransport, @ParmDefinitionTransport, @Allowance = @TransportAllowance OUTPUT  
       if @@Error<>0  
       begin  
        set @SQLStringTransport='Formula Error (Transport Allowance)- Employee Index : [' + str(@EmployeeIndex) + '] '   
        raiserror (@SQLStringTransport, 16,1)  
        return  
       end  
      end  
     end  
     begin transaction  
     delete   
     from    tm_AtClosing  
     where   PeriodIndex=@PeriodIndex  
       and EmployeeIndex=@EmployeeIndex  
     if @@Error<>0  
     begin  
      rollback transaction  
      return  
     end  
     insert into tm_AtClosing   
        (  
        PeriodIndex, EmployeeIndex, AtClosingStatus, FromDate, ToDate,   
        TotalIrregular ,TotalInvalid , TotalDay , TotalHoliday , TotalHolidayGD, TotalDayAttended , TotalHolidayAttended,TotalHolidayGDAttended, TotalAbsentLeave, TotalAbsent ,  
        TotalLeave , TotalLWOP , TotalLate , TotalEarly , TotalLateEarly , TotalBreak , TotalUnderwork , TotalOvertime ,  
        TotalOvertimeWD , TotalOvertimeOD , TotalOvertimeGD , TotalOvertimeWDActual , TotalOvertimeODActual , TotalOvertimeGDActual, TotalHalfDay , TotalFullDay,   
        TotalApNightShift, TotalApMidShift, TotalApSplitShift,AttendanceAllowance,TotalOvertimeAmount,TotalShiftPremium,TotalMealAllowance,TotalNightShiftAmount,  
        EmpRosterWorkHour,TotalTransportAllowance, Remarks , UserEmpIndex , LastUpdateDate , TotalLWOPAvailed, TotalLWOPDed   
        )  
     select      @PeriodIndex,   
        @EmployeeIndex,   
        @AtClosingStatus,   
        @FromDate,   
        @Todate,  
        t.Irregular ,   
        t.Invalid ,   
        @TotalDays  ,   
        t.Holiday ,   
        t.HolidayGD,  
        t.DaysAttended ,   
        t.DaysAttendedHoliday ,   
        t.DaysAttendedGDHoliday,  
        t.AbsentLeave ,  
        --t.Absent ,  
        --(case when @ClientIndex=1147 then ( t.Absent + t.AbsentEmpIn + t.AbsentLwop ) else t.Absent end) Absent,  
        (Case when @ClientIndex in (1147,1145) then (t.Absent + t.AbsentEmpIn + t.AbsentLeave) else t.Absent end) TotalAbsent,--+ t.AbsentLwop ) else t.Absent end) TotalAbsent,  
         --(case when @ClientIndex in (1147,1145) then ( t.Absent + t.AbsentEmpIn + t.AbsentLeave + t.LWOP + t.LWOP2 ) else t.Absent end) TotalAbsent,--+ t.AbsentLwop ) else t.Absent end) TotalAbsent,  
        (t.Leave+t.leave2) Leave ,   
        (t.LWOP +isnull(ld.LWOPDedDays,0)+t.LWOP2) LWOP,   
        t.Late ,   
        t.Early ,   
        t.LateEarly ,   
        0,   
        0 ,    
        t.Overtime ,  
        (case when (t.Overtime-isnull(oth.ApOTOffday,0)-isnull(oth.ApOTGazetted,0)) < ((t.DaysAttended-t.DaysAttendedHoliday) * isnull(otr.MaxOTWD,9999)) then (t.Overtime-isnull(oth.ApOTOffday,0)-isnull(oth.ApOTGazetted,0)) else ((t.DaysAttended-t.DaysAttendedHoliday) * isnull(otr.MaxOTWD,9999)) end ) TotalOvertimeWD,  
        (case when isnull(oth.ApOTOffday,0) < ( ( case when isnull(oth.TotalNonGazetted,0)>isnull(otr.MaxOD,9999) then isnull(otr.MaxOD,9999) else isnull(oth.TotalNonGazetted,0) end ) * isnull(otr.MaxOTOD,9999)) then isnull(oth.ApOTOffday,0) else (( case 
			  when isnull(oth.TotalNonGazetted,0)>isnull(otr.MaxOD,9999) then isnull(otr.MaxOD,9999) else isnull(oth.TotalNonGazetted,0) end ) * isnull(otr.MaxOTOD,9999)) end ) TotalOvertimeOD,  
        (case when isnull(oth.ApOTGazetted,0) < (isnull(oth.TotalGazetted,0) * isnull(otr.MaxOTGD,9999)) then isnull(oth.ApOTGazetted,0) else (isnull(oth.TotalGazetted,0) * isnull(otr.MaxOTGD,9999)) end ) TotalOvertimeGD,  
        str(t.Overtime-isnull(oth.ApOTOffday,0)-isnull(oth.ApOTGazetted,0),7,2) TotalOvertimeWDActual,  
        str(isnull(oth.ApOTOffday,0),7,2) TotalOvertimeODActual,  
        str(isnull(oth.ApOTGazetted,0),7,2) TotalOvertimeGDActual,  
        t.TotalHalfDay ,  
        t.TotalFullDay ,  
        t.ApNightShift,  
        t.ApMidShift,  
        t.ApSplitShift,  
        @AllowanceValue,  
        @TotalOvertimeAmount,  
        @ShiftPremiumValue,  
        @MealAllowance,  
        @TotalNightShiftAmount,  
        isnull(@EmpRosterWorkHour,0),  
        isnull(@TransportAllowance,0),  
        @Remarks,   
        @UserEmpIndex,   
        getdate(),
		(t.LWOP + t.lwop2),
		isnull(ld.LWOPDedDays,0)
     from      (  
        select    EmployeeIndex,  
          sum((case when IsAttendance=1 and isnull(rosterindex,0)=0 and IsHoliday=0 and IsLeave=0 then 1 else 0 end)) Irregular,   
          sum((case when IsAttendance=1 and isnull(isexempt,0)=0 and isnull(empin,empout)=isnull(empout,empin)  and IsHoliday=0  then 1 else 0 end)) Invalid,   
          sum((case when isholiday=1 and isGazetted=0 then 1 else 0 end)) Holiday,   
          sum((case when isGazetted=1 then 1 else 0 end)) HolidayGD,   
          sum((case when isattendance=1 then 1 else 0 end)) DaysAttended,  
          sum((case when isattendance=1 and isHoliday=1 and isGazetted = 0 then 1 else 0 end)) DaysAttendedHoliday,  
          sum((case when isattendance=1 and isGazetted=1 then 1 else 0 end)) DaysAttendedGDHoliday,  
          sum((case when AdjLvBal>0 and isnull(AdjLvIndex,0)=0  and isnull(IsExempt,0)=0 and IsHoliday=0 then AdjLvBal else 0 end)) AbsentLeave,  
          sum((case when isAbsent=1 then 1 else 0 end)) Absent, -- donot change this. ,call Saad '10/11/2022'  
          --sum((case when isAbsent=1 then 1 when absentpartial < 1 then absentpartial else 0 end)) Absent,  
          --sum((case when isLeave=1  and LeaveType not in (5,76,79,80,81) then (case when isnull(LeaveTotalDays,0)>=1 then 1 else isnull(LeaveTotalDays,0) end ) else 0 end)) Leave,  
          --sum((case when isLeave=1  and LeaveType in (5,76,79,80,81) then (case when isnull(LeaveTotalDays,0)>=1 then 1 else isnull(LeaveTotalDays,0) end ) else 0 end)) LWOP,  
          sum((case when isLeave=1  and LeaveType not in (5,28,76,79,80,81)   
             then (case when isnull(LeaveTotalDays,0)>=1   then 1   
                   else isnull(LeaveTotalDays,0)   
               end )   
             else 0 end)) Leave,  
          sum((case when isLeave=1  and LeaveType2 not in (5,28,76,79,80,81)   
             then (case when isnull(LeaveTotalDays2,0)>=1   then 1   
                   else isnull(LeaveTotalDays2,0)   
               end )   
             else 0 end)) Leave2,  
          sum((case when isLeave=1  and LeaveType  in (5,28,76,79,80,81)   
             then (case when isnull(LeaveTotalDays,0)>=1   then 1   
                   else isnull(LeaveTotalDays,0)   
               end )   
             else 0 end)) LWOP,  
          sum((case when isLeave=1  and LeaveType2  in (5,28,76,79,80,81)   
             then (case when isnull(LeaveTotalDays2,0)>=1   then 1   
                   else isnull(LeaveTotalDays2,0)   
               end )   
             else 0 end)) LWOP2,  
		--for total late/early count in no of days---
		sum((case when IsLC=1 and @clientindex not in (1313,1314) then round( (LCHH*60+LCMI)/60.0 ,2) when @clientindex  in (1251,1334,1272) and islc = 1 and adjlc > 0 then 1 else 0 end)) Late,            
		sum((case when IsEG=1 and adjEG > 0 and @clientindex not in (1313,1314) then round( (EGHH*60+EGMI)/60.0 ,2) when @clientindex  in (1272,1334) and IsEG = 1 and adjEG > 0 then 1 else 0 end)) Early,
		--for total late/early count in no of days---
          sum((case when IsLC=1 or IsEG=1 then round( ((LCHH*60+LCMI)+(EGHH*60+EGMI))/60.0 ,2) else 0 end)) LateEarly,   
          sum((case when (ApOTHH+ApOTMI)>0 then round( (ApOTHH*60+ApOTMI)/60.0 , 2) else 0 end)) Overtime ,  
          sum((case when AdjLvBal=0.5 then AdjLvBal else 0 end)) TotalHalfDay ,  
          sum((case when AdjLvBal=1 then AdjLvBal else 0 end)) TotalFullDay ,  
          sum(isnull(s.ApNightShift,0)) ApNightShift,  
          sum(isnull(s.ApMidShift,0)) ApMidShift,  
          sum(isnull(s.ApSplitShift,0)) ApSplitShift,  
          sum(case when s.leavetype=5 then leavetotaldays else 0 end) absentlwop,  
          sum(case when (s.isexempt<>1 and s.isleave <> 1 and s.isattendance=1 and s.isholiday <> 1 and (s.empIn is null)) then 1 else 0 end ) absentEmpIn      
        from      #ClosingSummary s  
        group by EmployeeIndex  
     ) t   
     left outer join  
     (  
     select   Employeeindex, sum(ApOTOffday) ApOTOffday, sum(ApOTGazetted) ApOTGazetted, sum((case when ApOTOffday=0 then 0 else 1 end )) ApOTOffdayCount, sum((case when ApOTGazetted=0 then 0 else 1 end )) ApOTGazettedCount ,   
			  sum(IsGazetted) TotalGazetted, sum(isNonGazetted) TotalNonGazetted    
     from     tm_VwOvertimeHoliday   
     where    ClientIndex=@ClientIndex  
         and AtDate between @FromDate and @ToDate  
     group by EmployeeIndex  
     ) oth on t.EmployeeIndex=oth.EmployeeIndex  
     left outer join   
     (  
      select sum(totaldays)LWOPDedDays,employeeindex   
      from leavedetail   
      where leavestatus = 7 and leavetype = 5  
        and fromdate > = @FromDate  
        and todate < = @Todate  
      group by employeeindex  
     )ld on ld.employeeindex = t.employeeindex  
     inner join VwEmpDetail ed  on t.EmployeeIndex=ed.EmployeeIndex  
     left outer join tm_OTRules otr on isnull(ed.adjruleindex,0)=otr.adjruleindex  
     if @@Error<>0  
        begin  
       rollback transaction  
       return  
        end  
        if exists (select Periodindex from tm_atclosingException where PeriodIndex=@PeriodIndex and EmployeeIndex=@EmployeeIndex)  
        begin  
         update   tm_AtClosing  
         set      TotalOTSplit1WD = ace.TotalOTSplit1WD,  
         TotalOTSplit2WD = ace.TotalOTSplit2WD  
         from      tm_AtClosing ac,   
          tm_AtClosingException ace  
         where    ac.EmployeeIndex=ace.EmployeeIndex  
           and ac.PeriodIndex=ace.PeriodIndex  
           and ace.TotalOTSplit1WD is not null  
           and ace.TotalOTSplit2WD is not null  
        end  
     if @AbsentDeduction=1   
     Begin  
      Declare @AbsentLeave float = 0  
      select @AbsentLeave=t1.Absent + t2.LateDeduction  
      from (  
         select employeeindex, count(*) Absent  
         from #ClosingSummary   
         where  isabsent=1  
         and isexempt=0  
         and ISLEAVE=0  
         group by employeeindex  
        ) t1  
        full join   
        (  
         select EmployeeIndex, NoofLate, (NoofLate-1) / 3 LateDeduction  
         from   (  
            select employeeindex, count(*) NoofLate  
            from   #ClosingSummary   
            where  IsAttendance=1  
            and workinghh<9  
            and isLC=1  
            group by employeeindex  
           ) t  
        ) t2  on t1.EmployeeIndex=t2.EmployeeIndex  
      if @@Error<>0  
      begin  
       rollback transaction  
       return  
      end  
      update tm_AtClosing  
      set  TotalAbsentLeave=@AbsentLeave  
      where EmployeeIndex=@EmployeeIndex   
        and PeriodIndex=@PeriodIndex  
      if @@Error<>0  
      begin  
       rollback transaction  
       return  
      end  
     End  
     if @SplitOTWD = 1  
      Begin  
       If exists (select * from tm_OTRules where AdjRuleIndex=@AdjRuleIndex and isnull(SplitOTWDLimit1,0)>0)  
       Begin  
        declare @SplitOTWDLimit1 float=9999, @SplitOTWDLimit2 float=9999  
        declare @TotalOTSplit1WD float=0, @TotalOTSplit2WD float=0  
        select    @SplitOTWDLimit1=isnull(SplitOTWDLimit1,9999),   
            @SplitOTWDLimit2=isnull(SplitOTWDLimit2,9999)   
        from      tm_OTRules   
        where    AdjRuleIndex=@AdjRuleIndex -- 157  
        select    @TotalOTSplit1WD = sum(Split1) ,   
            @TotalOTSplit2WD = sum(Split2)   
        from      (  
              select    ((apothh*60)+apotmi)/60.0 ApOt,  
                     (case when @SplitOTWDLimit1>=((apothh*60)+apotmi)/60.0 then ((apothh*60)+apotmi)/60.0 else @SplitOTWDLimit1 end ) Split1,  
                     (case when @SplitOTWDLimit1>=((apothh*60)+apotmi)/60.0 then 0 else (((apothh*60)+apotmi)/60.0)-@SplitOTWDLimit1 end ) Split2  
              from      #ClosingSummary   
              where   ((ApOtHH*60)+ApOTMI)>0  
              and IsHoliday=0  
             ) t  
        update tm_AtClosing  
        set    TotalOTSplit1WD = @TotalOTSplit1WD ,-- (case when @SplitOTWDLimit1>=isnull(TotalOvertimeWD,0) then isnull(TotalOvertimeWD,0) else @SplitOTWDLimit1 end ),  
            TotalOTSplit2WD = @TotalOTSplit2WD --(case when @SplitOTWDLimit1>=isnull(TotalOvertimeWD,0) then 0 else isnull(TotalOvertimeWD,0)-@SplitOTWDLimit1 end )  
        where    EmployeeIndex=@EmployeeIndex   
             and PeriodIndex=@PeriodIndex  
        if @@Error<>0  
        begin  
          rollback transaction  
          return  
        end  
       End  
      end  
      if @IsForceAbsent > 0   
      begin  
        Declare @ForceAbsent float = 0   
        select @ForceAbsent = isnull(sum(ForceDeduction),0)  
        from   tm_summaryabsent   
        where  employeeindex in (@EmployeeIndex )   
          and absentdate between @FromDate and @ToDate  
        update tm_AtClosing   
        set    totalabsent = totalabsent + @ForceAbsent  
        where  EmployeeIndex=@EmployeeIndex   
           and PeriodIndex=@PeriodIndex  
        if @@Error<>0  
        begin  
          rollback transaction  
          return  
        end  
      End  
      if @IsBasedOnWDFormula > 0   
      begin  
       Declare @MonthlySalary int = 0 ,@WorkDays float=0,@isbasedonlwop tinyint = 0,@ServiceStartDate datetime,@ServiceEndDate datetime,@Buindex smallint=0  
       Declare @HolidayGroup smallint = 0   
       select @MonthlySalary = CurrentGrossSalary, @ServiceStartDate = ServiceStartDate,@ServiceEndDate = ServiceEndDate, @Buindex =isnull(Buindex,0),@HolidayGroup = isnull(HolidayGroup,0)  
        from employee  
        where  employeeindex = @EmployeeIndex  
       if exists (select * from Tm_atclosingWDFormula where clientindex = @ClientIndex and IsBasedMonthlySalary=1 and buindex = @Buindex) -- if based on salary  
        begin  
         select @WorkDays =WorkDays,  
           @isbasedonlwop =isbasedonlwop   
         from Tm_atclosingWDFormula   
          where clientindex = @ClientIndex  
           and @MonthlySalary between minmonthlysalary and maxmonthlysalary -- based on slab for salary   
        end  
       else  
        begin  
         select @WorkDays =WorkDays,@isbasedonlwop =isbasedonlwop from Tm_atclosingWDFormula where clientindex = @ClientIndex  
        end  
       if @WorkDays = 31 --or @WorkDays = 0   31 means MTD  
        set @WorkDays = @TotalDays  
       Declare @BlankDays float = 0  
       Declare @TotalLWOP float = 0  
       Declare @TotalPresent float = 0  
       Declare @TotalCLHoliday float = 0  
       Declare @TotalCLGDHoliday float = 0  
       Declare @TotalHoliday float = 0  
       Declare @TotalGDHoliday float = 0  
       Declare @PaidDays float = 0  
       Declare @TotalGDHolidayCount float = 0  
       Select @TotalLWOP = ISNULL(totalabsent,0) + ISNULL(totallwop,0) + ISNULL(TotalAbsentLeave,0),  
         @TotalPresent = ISNULL(TotalDayAttended,0),  
         @TotalCLHoliday = ISNULL(TotalHoliday,0)  
       from tm_atclosing   
       where    
         EmployeeIndex = @EmployeeIndex  
          and PeriodIndex=@PeriodIndex  
       select @TotalGDHolidayCount = count(*) --holiday will be count if GH and Rest day both at same day   
       from  tm_holidayschedule   
       where holidaygroup = @HolidayGroup -- need to get accroding to date wrt change date  
        and holidaydate in (select   
               atdate   
             from #ClosingSummary   
             where atdate between @fromdate and @Todate   
               and employeeindex = @EmployeeIndex   
               and isgazetted = 1   
             )  
        select @PaidDays = case when @WorkDays = 26 then count(*) - @TotalLWOP - @TotalCLHoliday - @TotalGDHolidayCount else count(*) - @TotalLWOP end  
        from   #ClosingSummary   
        where  employeeindex = @EmployeeIndex   
          and atdate between @fromdate and @Todate   
        group by employeeindex  
       if isnull(@ServiceEndDate,'2090-1-01') < @Todate  and @ServiceEndDate <> '1900-01-01'    
       begin  
        if @WorkDays = 26  
         begin  
          declare @HolidayAfterEnddate tinyint = 0   
          select @HolidayAfterEnddate = count(*)   
          from   tm_vwempoff   
          where  employeeindex = @EmployeeIndex   
            and holidaydate between dateadd(dd,1,@ServiceEndDate) and @Todate  
          set @BlankDays = datediff(dd,@ServiceEndDate,@Todate) - @HolidayAfterEnddate -- for workers holiday will be minus from blanks  
         end  
         else  
         begin  
          Set @BlankDays = datediff(dd,@ServiceEndDate,@Todate)  
         end  
       end  
       if @ServiceStartDate > @FromDate and exists (select * from Tm_atclosingWDFormula where clientindex = @ClientIndex and IsBasedMonthlySalary=1 and buindex = @Buindex)  
        begin  
         if @WorkDays = 26  
          begin  
           --Declare @LastDateOfMonth date = EOMONTH(@ServiceStartDate)  
           --Declare @WorkingDaysofMOnth tinyint = datediff(dd,@ServiceStartDate,@LastDateOfMonth) + 1  
           declare @Holidaybeforejoining tinyint = 0   
            select @Holidaybeforejoining = count(*)   
            from   tm_vwempoff   
            where  employeeindex = @EmployeeIndex   
              and holidaydate between @Fromdate and dateadd(dd,-1,@ServiceStartDate)  
            set @BlankDays = datediff(dd,@Fromdate,@ServiceStartDate) - @Holidaybeforejoining -- for workers holiday will be minus from blanks  
           --end  
          end  
         else  
          begin  
           Set @BlankDays = datediff(dd,@FromDate,@ServiceStartDate)  
          end  
        end  
         if ( @BlankDays + @TotalLWOP ) > = isnull(@PaidDays,0) and isnull(@PaidDays,0) > 0   
          set @WorkDays =  @PaidDays  
         else  
          set @WorkDays = @WorkDays - @TotalLWOP - ISNULL(@BlankDays,0)  
        --end  
       if @WorkDays < 0  
        set @WorkDays = 0  
       if @WorkDays > @TotalDays  
        set @WorkDays = @TotalDays  
       update tm_AtClosing   
       set    TotalWorkDays = @WorkDays  
       where  EmployeeIndex=@EmployeeIndex   
          and PeriodIndex=@PeriodIndex  
       if @@Error<>0  
          begin  
         rollback transaction  
         return  
          end  
      if exists (select * from tm_atClosingSummary Where EmployeeIndex=@EmployeeIndex and FromDate=@FromDate and ToDate=@ToDate and isnull(WorkDays,0)>0)  
      Begin  
       Declare @WD float  
       Select @WD=WorkDays from tm_atClosingSummary Where  EmployeeIndex=@EmployeeIndex and FromDate=@FromDate and ToDate=@ToDate  
       update tm_AtClosing   
       set    TotalWorkDays = @WD  
       where  EmployeeIndex = @EmployeeIndex   
           and PeriodIndex=@PeriodIndex  
       if @@Error<>0  
          Begin  
         rollback transaction  
         return  
          End  
      End  
      End  
     	 ------------hamdard Third party  1 early going short leave ----------------------
	 if @clientindex = 1319
      Begin  
	  declare @EG float,
			  @EGS float  
      set @EG = (select top 1 round( (EGHH*60+EGMI)/60.0 ,2) as Early_Going from tm_summary where employeeindex = @EmployeeIndex 
	  and atdate between @FromDate and @ToDate and adjEG > 0 and egHH = 1 and egMI > 29) 
	  set @EGS = (select totalearly - @EG from tm_atclosing where employeeindex  = @employeeindex and periodindex  = @periodindex )
       update tm_AtClosing   
       set    TotalEarly = isnull(@EGS,0)
       where  EmployeeIndex = @EmployeeIndex   
           and PeriodIndex=@PeriodIndex  
       if @@Error<>0  
          Begin  
         rollback transaction  
         return  
          End  
      End  
	 ------------hamdard Third party  1 early going short leave ----------------------
	  ------------hamdard Labooratories (Management) Over time from 20 Hours to 140 Hours  ----------------------
if @ClientIndex = 1313 and @unitindex = 26788 
	begin
	declare  @AOT float, --Approved Overtime
			 @UOT float --Updated Overtime
	set @AOT = (select ROUND(ISNULL(totalovertime, 0), 2) from tm_atclosing where EmployeeIndex = @EmployeeIndex and PeriodIndex = @PeriodIndex)
	set @UOT = 
			case when @AOT < 20 then 0 
				 when @AOT > 140 then 140
				 else @AOT
	        end
	 update tm_AtClosing   
       set    TotalOvertime = isnull(@UOT,0)
       where  EmployeeIndex = @EmployeeIndex   
           and PeriodIndex=@PeriodIndex  
       if @@Error<>0  
          Begin  
         rollback transaction  
         return  
          End  
	end
	  ------------hamdard Labooratories (Management) Over time from 20 Hours to 140 Hours  ----------------------
     insert into tm_AtClosingHistory (PeriodIndex, EmployeeIndex, HNo, AtClosingStatus, Remarks, UserEmpIndex, UpdateDate)  
     values    (  
        @PeriodIndex,   
        @EmployeeIndex,   
        (select isnull(max(HNo),0)+1 from tm_AtclosingHistory where periodIndex=@PeriodIndex and EmployeeIndex=@EmployeeIndex),  
        @AtClosingStatus,  
        @Remarks,  
        @UserEmpIndex,  
        getdate()  
        )  
     if @@Error<>0  
     begin  
     rollback transaction  
     return  
     end  
     commit transaction         
     -----------------------CIP integration with Attendance 2021-08-02 ---------------------------------  
     if exists (select *  from clientplan where clientindex = @clientindex and IsCIPIntegrationWithAttendance = 1)  
      EXEC tm_AtClosingCIPIntegration_SetData @PeriodIndex,@EmployeeIndex,'',@UserEmpIndex  
     -----------------------CIP integration with Attendance 2021-08-02 ---------------------------------                                                
    end  
return
