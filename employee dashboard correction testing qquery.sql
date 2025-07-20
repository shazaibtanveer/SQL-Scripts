--Alter procedure [dbo].[App_tm_ATCApplication]  
--      @UserEmpIndex char(20),  
--      @EmployeeIndex int,  
--      @AtDate datetime,  
--      @CorrectIn smalldatetime,  
--      @CorrectOut smalldatetime,  
--      @ATCType tinyint,  
--      @ReasonType tinyint,  
--      @Remarks varchar(100)  
--as  
Declare
    @UserEmpIndex char(20) = 291598,  
    @EmployeeIndex int =  291598,  
    @AtDate datetime = '2025-06-03',  
    @CorrectIn smalldatetime, --= '5/2/2025 9:52:00 AM',  
    @CorrectOut smalldatetime = '6/3/2025 8:55:00 PM',  
    @ATCType tinyint = 2,  
    @ReasonType tinyint = 1,  
    @Remarks varchar(100) = 'test'  

      declare @ATCIndex int, @ProcessNo smallint, @ATCStatus tinyint, @EmpIn smalldatetime, @EmpOut smalldatetime  
      declare @StrDate as char(10), @TimeIn smalldatetime, @TimeOut smalldatetime, @LateMargin as smallint, @OTMargin as smallint, @RosterIndex smallint  
      declare @ClientIndex smallint, @ATCCuttOffDays tinyint, @Msg varchar(100) , @RestrictATCPostPeriodWise tinyint , @FromDate Date , @ToDate Date  
   declare @IsByPassATCOnCurrentDate tinyint    
      set @StrDate = CONVERT(char(10), @AtDate, 101)  
    set @ATCStatus=1  
    set @ProcessNo=1  
    set @EmpIn=null  
    set @EmpOut=null  
      set @RosterIndex=0  
      select @ClientIndex =  ClientIndex from employee where EmployeeIndex =  @EmployeeIndex  
   select @IsByPassATCOnCurrentDate = isnull(IsByPassATCOnCurrentDate,0) from ClientPlan where ClientIndex = @ClientIndex    
   ----------------------------------------------------------------Not Allowed to Mark Correction When Leave Already Applied For Hyundai----------------------------------------------------------------  
   ---------------------------------------------------------------------------------------6/30/2024-----------------------------------------------------------------------------------------------------  
   If Exists (select EmployeeIndex from LeaveDetail Where EmployeeIndex = @EmployeeIndex and @ClientIndex = 1308 and FromDate = @AtDate and LeaveStatus In (1,2,3))  
   Begin  
            raiserror('As Per The Company Policy, You are not Allowed to Mark the Correction, Please Contact With Your HR!',16,1)  
      return  
   End  
   ----------------------------------------------------------------Not Allowed to Mark Correction When Leave Already Applied For Hyundai----------------------------------------------------------------  
   ---------------------------------------------------------------------------------------6/30/2024-----------------------------------------------------------------------------------------------------  
      if exists (select * from tm_AtClosing where EmployeeIndex=@EmployeeIndex and Todate>=@AtDate and @ClientIndex Not in (1162,1161))  
      begin  
            raiserror('Attendance has been closed!',16,1)  
            return  
      end  
   if exists (  
     select p.PeriodIndex   
     from tm_period p  
     where p.PeriodGroup in (  
       select pwl.PeriodGroup   
       from tm_PeriodGroup pg, tm_PeriodGroupWL pwl, VwEmpWL ewl  
       where ewl.EmployeeIndex=@employeeindex  
         and ewl.WorkLocationIndex=pwl.WorkLocationIndex  
         and ewl.WorkLocation=pwl.WorkLocation  
         and pg.PeriodGroup=pwl.PeriodGroup  
         and pg.PeriodCat=4  
       )  
       and p.PeriodStatus=3  
       and p.PeriodIndex not in   
        (  
         select PeriodIndex   
         from tm_PeriodException   
         where (  
           EmployeeIndex=@EmployeeIndex   
           or  
           @EmployeeIndex in (select EmployeeIndex from acm_VwEmpAuthority where UserEmpIndex=@UserEmpIndex and WLCat=3)    
           )  
           and PeriodStatus=1  
        )  
       and @AtDate between p.FromDate and p.ToDate  
     )  
       begin    
              raiserror('Attendance Period has been closed!',16,1)    
              return    
       end  
	   --Restric & Unrestric attendance correction on Leave day and on specific types--
		DECLARE 
		    @IsNotAllowAttOnLvOnApp TINYINT,
		    @IsNotAllowAttOnLvOnAppExempted VARCHAR(20)
		SELECT 
		    @IsNotAllowAttOnLvOnApp = ISNULL(IsNotAllowAttOnLvOnApp, 0),
		    @IsNotAllowAttOnLvOnAppExempted = ISNULL(IsNotAllowAttOnLvOnAppExempted, '')
		FROM clientplanAttendance 
		WHERE ClientIndex = @clientIndex
		IF (@IsNotAllowAttOnLvOnApp = 1 )
		BEGIN 
		    IF EXISTS (
		        SELECT 1 
		        FROM LeaveDetail 
		        WHERE EmployeeIndex = @EmployeeIndex 
		          AND CONVERT(DATE, @AtDate) BETWEEN FromDate AND ToDate 
		          AND LeaveStatus IN (1, 2, 3) 
		          AND LeaveType Not IN (SELECT col1 FROM dbo.fnparsearray(@IsNotAllowAttOnLvOnAppExempted, ','))
		    ) 
		    BEGIN 
		        RAISERROR('You are not allowed to mark attendance correction on leave day', 16, 1) 
		        RETURN 
		    END 
		END 
	  --Restric & Unrestric attendance correction on Leave day and on specific types--
    If (Convert(Date,@CorrectIn) = Convert(Date,Getdate())  or Convert(Date,@Correctout) = Convert(Date,Getdate())) and Isnull(@IsByPassATCOnCurrentDate,0) = 0    
   Begin    
          raiserror('Correction Is Not Allowed to Mark on the Current Date!!!',16,1)    
            return    
   End -- This Check Ensures the ClientWise Attendance Correction Restriction/Non Restriction as described in task # AT-27.  
      if exists (select * from clientplan where clientindex = @ClientIndex and isnull(ATCCuttOffDays, 0) <> 0)  
      begin  
            select @ATCCuttOffDays = ATCCuttOffDays from ClientPlan where Clientindex =  @ClientIndex  
            if isnull(@ATCCuttOffDays, 0)>0 and datediff(day, @AtDate, getdate()) >= isnull(@ATCCuttOffDays, 0)  
            begin  
                  set @Msg ='According to Company Policy you can not apply "' + LTRIM(RTRIM(@ATCCuttOffDays)) + '" days post dated correction.'  
                  raiserror(@Msg, 16, 1)  
                  return  
            end  
      end   
      if @EmployeeIndex=0   
            select @EmployeeIndex = employeeindex from RegisteredUsers where UserID=@UserEmpIndex  
      --declare @ClientIndex int  
            --select @ClientIndex=Clientindex from employee where EmployeeIndex = @EmployeeIndex  
            if @ClientIndex <> 711 and Isnull(@IsByPassATCOnCurrentDate,0) = 0    
            begin  
                  if @AtDate>=CONVERT(DATE,GETDATE())   
                  begin  
                        raiserror('Post Dated Attendance Correction Is Not Allowed!!', 16,1)  
                        return  
                  end  
            end  
    if Isnull(@IsByPassATCOnCurrentDate,0) = 1   
      begin    
                  if @AtDate> CONVERT(DATE,GETDATE())    
                  begin    
                        raiserror('Post Dated Attendance Correction Is Not Allowed!!', 16,1)    
                        return    
                  end    
            end   
      if @CorrectOut = @CorrectIn   
      begin  
            raiserror('In and Out time are same, please change!!', 16,1)  
            return  
      end  
      if exists (select * from tm_ATC where EmployeeIndex=@EmployeeIndex and AtDate=@AtDate and ATCStatus=1 )  
      begin  
            raiserror('Attendance correction for the day is already in approval.', 16,1)  
            return  
      end  
      if not exists (select * from tm_EmpShift where EmployeeIndex=@EmployeeIndex and @AtDate between FromDate and ToDate)  
            begin  
                  select      @RosterIndex = isnull(isnull(isnull(isnull(ves.rosterindex,er.rosterindex), rg.rosterindex),rc.rosterindex),cm.defaultroster)  
                  from  Employee e   
							  Left Outer join tm_VwEmpShift Ves on e.EmployeeIndex = ves.EmployeeIndex and ves.dt = @AtDate and EmpRosterCount > 0
                              left outer join tm_rosteremp er on e.employeeindex=er.employeeindex and @AtDate between er.fromdate and er.TODATE   
                              left outer join tm_RosterAtGroup rg on e.AtGroup=rg.AtGroup and @AtDate between rg.fromdate and rg.TODATE,  
                              clientmaster cm   
                              left outer join tm_rosterclient rc on cm.ClientIndex=rc.clientindex  and @AtDate between rc.fromdate and rc.TODATE  
                  where e.EmployeeIndex=@EmployeeIndex and e.clientindex=CM.clientindex   
                  if @@ROWCOUNT=0   
                        return  
                  select  
                              @TimeIn  = @StrDate  + ' ' + ltrim(str(TimeInH)) + ':' + ltrim(STR(TimeInM)),  
                              @Timeout = @StrDate + ' ' + str(TimeOutH) + ':' + str(TimeOutM),  
                              @LateMargin = isnull(LateMargin,0),  
                              @OTMargin = isnull(OTMargin,0)  
                  from tm_Roster r, tm_RosterDay rd  
                  where r.RosterIndex=rd.RosterIndex  
                  and rd.DayNo=DATEPART(dw,@AtDate) and r.RosterIndex=@RosterIndex  
            end  
      else  
            begin  
                  select  
                              @TimeIn  = @StrDate  + ' ' + ltrim(str(TimeInH)) + ':' + ltrim(STR(TimeInM)),  
                              @Timeout = @StrDate + ' ' + str(TimeOutH) + ':' + str(TimeOutM),  
                              @LateMargin = isnull(LateMargin,0),  
                              @OTMargin = isnull(OTMargin,0)  
                  from  tm_EmpShift es  
                  where EmployeeIndex=@EmployeeIndex   
                              and @AtDate between FromDate and ToDate           
            end  
      if @TimeIn>@TimeOut  
            set @TimeOut = DATEADD(d, 1, @TimeOut)  
      select @EmpIn=EmpIn, @EmpOut=EmpOut from tm_Attendance   
      where EmployeeIndex=@EmployeeIndex and AtDate=@AtDate  
      if @ATCType=1 and @EmpOut<@CorrectIn  
      begin  
            raiserror('Invalid In Time', 16,1)  
            return  
      end  
      if @ATCType=2 and @EmpIn>@CorrectOut    
      begin  
            raiserror('Invalid Out Time', 16,1)  
            return  
      end  
      if @ATCType=3 and @CorrectOut<@CorrectIn    
      begin  
            raiserror('Invalid In/Out Time', 16,1)  
            return  
      end  
   Select @RestrictATCPostPeriodWise = isnull(RestrictATCPostPeriodWise,0)  
   From ClientPlan   
   Where ClientIndex = @ClientIndex  
   Select @FromDate = p.FromDate,  
   @Todate = p.todate  
   from tm_Period p,  
   tm_PeriodGroup pg  
   where pg.ClientIndex=@ClientIndex  
   and pg.PeriodGroup=p.PeriodGroup  
   and pg.PeriodCat=4  
   and @AtDate Between p.FromDate and p.ToDate  
   if @RestrictATCPostPeriodWise > 0 and @RestrictATCPostPeriodWise <= (select COUNT(*) From Tm_Atc Where EmployeeIndex = @EmployeeIndex and atdate between @FromDate and @ToDate and ATCStatus in (1,2,3,9))   
      begin  
   set @Msg ='You are not allowed to make more than "' + LTRIM(RTRIM(@RestrictATCPostPeriodWise)) + '" attendance corrections in a period.'  
                  raiserror(@Msg, 16, 1)  
                  return  
      end  
      begin transaction  
      if  not exists (select * from tm_Attendance where EmployeeIndex=@EmployeeIndex and AtDate=@AtDate) --    @EmpIn is null and @EmpOut is null   
            begin   
      --          set @StrDate = CONVERT(char, @AtDate, 101)  
                  --insert into tm_Attendance (AtDate, EmployeeIndex, EmpIn, EmpOut, TimeIn, TimeOut, LateMargin, OTMargin, AttendanceStatus, RosterIndex)                 
                select 'tm_Attendance', @AtDate, @EmployeeIndex, @TimeIn, @TimeIn, @TimeIn, @TimeOut, @LateMargin, @OTMargin, 3, @RosterIndex 
                  if @@Error<>0  
                  begin  
                        rollback transaction  
                        return  
                  end  
            end  
     -- else  
            --begin  
            --      update      tm_Attendance   
            --      set         TimeIn=@TimeIn, TimeOut=@TimeOut, LateMargin=@LateMargin, OTMargin=@OTMargin, RosterIndex=@RosterIndex    
            --      where AtDate=@AtDate and EmployeeIndex=@EmployeeIndex  
            --      if @@Error<>0  
            --      begin  
            --            rollback transaction  
            --            return  
            --      end  
            --end  
      if exists (select * from Employee where EmployeeIndex=@EmployeeIndex and ClientIndex in (select ClientIndex from ClientPlan where EmpAtcApproval=2))  
      begin         
            set @ATCStatus = 2  
            if @ATCType=1   select @ATCType
                  --update tm_Attendance set EmpIn=@CorrectIn, AttendanceStatus=3, RosterIndex=@RosterIndex where AtDate=@AtDate and EmployeeIndex=@EmployeeIndex  
            if @ATCType=2   select @ATCType
                 --update tm_Attendance set Empout=@CorrectOut, AttendanceStatus=3, RosterIndex=@RosterIndex where AtDate=@AtDate and EmployeeIndex=@EmployeeIndex  
            if @ATCType=3   select @ATCType
                 -- update tm_Attendance set EmpIn=@CorrectIn, EmpOut=@CorrectOut, AttendanceStatus=3, RosterIndex=@RosterIndex where AtDate=@AtDate and EmployeeIndex=@EmployeeIndex  
      end  
   
   -- calculate IsFoundDLIn & IsFoundDLout, updated on 05/21/2025

   		declare 
		@IsFoundDLIn bit, 
		@IsFoundDLOut bit,
		@employeeIN smalldatetime,
		@employeeOUT smalldatetime
		set @IsFoundDLIn = 0  
        set @IsFoundDLOut = 0   

		SELECT @employeeIN = EmpIn, @employeeOUT = EmpOut FROM tm_attendance WHERE EmployeeIndex = @EmployeeIndex AND AtDate = @AtDate


       if exists (
	   select 1 from tm_AtDataLog where EmployeeIndex=@EmployeeIndex and AtTime=@employeeIN and DLStatus = 6
	   union all
	   select 1 from tm_Attendanceweb where EmployeeIndex = @EmployeeIndex and logintype = 1 and LoginTime = @employeeIN
	   ) 
	   set @IsFoundDLIn=1 

       if exists (
	   select 1 from tm_AtDataLog where EmployeeIndex=@EmployeeIndex and AtTime = @employeeOUT and DLStatus = 6
	   union all
	   select 1 from tm_Attendanceweb where EmployeeIndex = @EmployeeIndex and logintype = 2 and LoginTime = @employeeOUT
	   )  
	   set @IsFoundDLOut=1  

	 -- calculate IsFoundDLIn & IsFoundDLout


		select 1 as LogforIN_Machine from tm_AtDataLog where EmployeeIndex=@EmployeeIndex and AtTime=@employeeIn and DLStatus = 6
	  
	   select 1 as LogforIN_Mobile from tm_Attendanceweb where EmployeeIndex = @EmployeeIndex and logintype = 1 and LoginTime = @employeeIn


	   select 1  as LogforOUT_machine from tm_AtDataLog where EmployeeIndex=@EmployeeIndex and AtTime=@employeeout and DLStatus = 6
	  
	   select 1 as LogforOUT_mobile from tm_Attendanceweb where EmployeeIndex = @EmployeeIndex and logintype = 2 and LoginTime = @employeeout

	select @ATCIndex=isnull(max(atcindex)+1,1) from tm_ATC  
    --insert into tm_atc (atcindex, employeeindex, atctype, atdate, remarks, reasontype, atcstatus, empIn, empOut, correctin, correctout,IsFoundDLIn,IsFoundDLOut)  
 select 'tm_atc', @atcIndex as atcIndex, @EmployeeIndex as EmployeeIndex, @atcType as atcType, @atDate as atdate, @Remarks as remarks, @ReasonType as reasontype, @ATCStatus as atcstatus, @EmpIn as EmpIN, @EmpOut as empout, @CorrectIn as correctIN, @CorrectOut as CorrectOUT,@IsFoundDLIn as [IN] ,@IsFoundDLOut as [out] 
      if @@Error<>0  
      begin  
            rollback transaction  
            return  
      end  
  --insert into tm_ATChistory (ATCIndex, ProcessNo, atcStatus, Remarks, ProcessBy, ProcessDate)  
     --values (@ATCIndex, @ProcessNo, @ATCStatus, @Remarks, @UserEmpIndex, GETDATE())  
      if @@Error<>0  
      begin  
            rollback transaction  
            return  
      end  
      commit transaction  
    --------------------------------  
     -- update by umair Oct 4, 2019  
  -- to check new Decibel5.0 todo  
     --exec todo_Main_Set  @EmployeeIndex , @ToDoComponent , @ComponentIndex , @ToDoType , @UserIndex , @UserEmpIndex   
     --exec todo_Main_Set @EmployeeIndex, 2, @ATCIndex,6, 0, @EmployeeIndex -- 1=@ToDoComponent & 2=@ToDoType  
     -- update by umair Oct 4, 2019  
  -- to check new Decibel5.0 todo  
  --------------------------------  
      ---------------------For email and sms---------------------------------  
      declare @ClientType tinyint --,@ClientIndex int  
      begin  
            select      @clienttype= cm.ClientType,@ClientIndex=cm.ClientIndex   
            from  Employee e, ClientMaster cm  
            where e.ClientIndex = cm.ClientIndex  
                        and e.EmployeeIndex = @EmployeeIndex  
      end  
      select @ClientType ClientType  
      select isnull(CellNo,'-') CellNo,rtrim(ltrim(EmployeeName)) EmployeeName,ClientIndex ,@ATCIndex ATCIndex,@ATCStatus ATCStatus  
      from Employee where EmployeeIndex =@EmployeeIndex  
      ---------------------For email and sms---------------------------------  
return
