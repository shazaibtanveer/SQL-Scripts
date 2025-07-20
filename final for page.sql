  declare @clientindex int = 1361
   declare @FromDate date='2024-12-1'
	declare @ToDate date='2024-12-31'


declare cur_Leavedays cursor for   

select leaveindex,employeeindex,LeaveType,TotalDays,FromDate,ToDate from leavedetail where  LeaveType in (3,5,9)
and LeaveStatus in (1,2) and 
( FromDate between @fromdate and @todate
 or todate between @fromdate and @todate
 or @fromdate between fromdate and todate
 or @todate  between fromdate and todate
)	
and employeeindex in (select employeeindex from employee where clientindex = @clientindex)

declare @EmployeeIndex int ,
				@LeaveIndex int,
				@lFromDate date,
				@lToDate date  ,
				@OldTotalDays float ,
				@LeaveType smallint,
				@NewTotalDays float,
				--@UserIndex smallint,      
				@CEmployeeIndex int,      
				@CLeaveType tinyint,      
				@CFromDate datetime,      
				@CToDate datetime    

IF OBJECT_ID('tempdb.dbo.#tt', 'U') IS NOT NULL  
                DROP TABLE #tt;

-- Create the temporary table
CREATE TABLE #tt (    
    --TotalDaysOld INT,
    LeaveIndex INT,
    EmployeeIndex INT,
    LeaveType INT,
    TotalDays INT,
	NewTotalDays INT,
    FromDate DATE,
    ToDate DATE,
    EntryDate DATETIME
);

open cur_Leavedays
		fetch next from cur_Leavedays into @LeaveIndex, @EmployeeIndex, @LeaveType, @OldTotalDays, @lFromDate, @lToDate
		while @@FETCH_STATUS=0
		begin

		set		@CEmployeeIndex  = @EmployeeIndex  
		set		@CLeaveType   = @LeaveType 
		set		@CFromDate   =  @lFromDate
		set		@CToDate   = @lToDate


		declare @TotalDays smallint, @IsLFA tinyint=0, @IsAgreedWithLM tinyint=0, @SendOutlookEmailStatus tinyint=0, @WFHCount int 
		declare @TotalDaysQuery nvarchar(2000)=''
  
		--if @CEmployeeIndex=0       
			---select @CEmployeeIndex = employeeindex from RegisteredUsers where UserIndex=@UserIndex      
      
		set @TotalDays = DATEDIFF(DD, @CFromDate, @CToDate)+1       
      
		select	@IsLFA= isnull(lr.IsLFA,0),
				@IsAgreedWithLM =isnull(IsAgreedWithLM,0),
				@SendOutlookEmailStatus=isnull(SendOutlookEmailStatus,0),
				@TotalDaysQuery  = Isnull(lr.TotalDaysQuery,'')
		from	Employee e, LeaveRules lr      
		where	e.EmployeeIndex=@CEmployeeIndex      
				and e.ClientIndex=lr.ClientIndex      
				and isnull(e.LvGroup,0)=lr.LvGroup      
				and lr.LeaveType=@CLeaveType      
      
		Select  @WFHCount=count(eo.HolidayDate)       
		From    tm_VwEmpOff eo       
		Where   eo.Holidaydate between @CFromDate and @CToDate      
				and eo.EmployeeIndex=@CEmployeeIndex      
				and eo.IsOff = 1       
				and eo.HolidayType=35    
    
       
      
		if exists(      
			select  eo.HolidayDate       
			from    tm_VwEmpOff eo       
			where    --eo.employeeindex=es.EmployeeIndex       
					eo.Holidaydate between @CFromDate and @CToDate      
					and eo.EmployeeIndex=@CEmployeeIndex      
					and eo.IsOff = 1       
		)      
			select	@TotalDays = (DATEDIFF(DD,@CFromDate,@CToDate)+1 ) - count(eo.holidaydate)     
			from	tm_VwEmpOff eo, Employee e, LeaveRules lr , tm_holidaygroupClient hgc       
			where	eo.holidaydate between @CFromDate and @CToDate      
					and e.ClientIndex=lr.ClientIndex       
					and lr.LeaveType=@CLeaveType      
					and isnull(lr.IsBasedOnWorkingDays,0)=1      
					and e.EmployeeIndex=eo.EmployeeIndex      
					and e.EmployeeIndex=@CEmployeeIndex      
					and isnull(e.lvgroup,0)=lr.lvgroup      
					--and isnull(e.atgroup,0)=hgc.AtGroup      
					and e.ClientIndex=hgc.ClientIndex      
					--and eo.HolidayGroup=hgc.HolidayGroup       
					and (case when isnull(e.HolidayGroup,0)=0 then isnull(hgc.DefaultHolidayGroup, hgc.HolidayGroup) else e.HolidayGroup end ) =hgc.HolidayGroup      
      
      
		select	@TotalDays=@TotalDays-count(eo.holidaydate)     
		from	tm_VwEmpOff eo, Employee e, LeaveRules lr , tm_holidaygroupClient hgc       
		where	eo.holidaydate between  @CFromDate and @CToDate      
				and e.ClientIndex=lr.ClientIndex       
				and lr.LeaveType=@CLeaveType      
				--and isnull(lr.IsBasedOnWorkingDays,0)=1      
				and e.EmployeeIndex=eo.EmployeeIndex      
				and e.EmployeeIndex=@CEmployeeIndex      
				and isnull(e.lvgroup,0)=lr.lvgroup      
				and e.ClientIndex=hgc.ClientIndex      
				and eo.IsGazetted=1      
				and isnull(lr.IsBasedOnWDOD,0)=1      
				and (case when isnull(e.HolidayGroup,0)=0 then isnull(hgc.DefaultHolidayGroup, hgc.HolidayGroup) else e.HolidayGroup end ) =hgc.HolidayGroup      
      
		if len(@TotalDaysQuery)>0
		begin
			declare @TotalDaysReturn float=0, @ParmDefinition nvarchar(500)

			--set @TotalDaysQuery =  'select @TotalDaysOut = count(*)-1 from tm_VwEmpOff o where o.EmployeeIndex=[EmployeeIndex] and o.HolidayDate between ''[FromDate]'' and ''[ToDate]'' and Datepart(dw,o.HolidayDate)=7 '
			set @TotalDaysQuery = REPLACE(@TotalDaysQuery, '[EmployeeIndex]',ltrim(@CEmployeeIndex))
			set @TotalDaysQuery = REPLACE(@TotalDaysQuery, '[FromDate]',rtrim(convert(char,@CFromDate,107)))
			set @TotalDaysQuery = REPLACE(@TotalDaysQuery, '[ToDate]',rtrim(convert(char,@CToDate,107)))
			
			SET @TotalDaysReturn=0
			SET @ParmDefinition = N'@TotalDaysOut real OUTPUT' 
			EXECUTE sp_executesql @TotalDaysQuery, @ParmDefinition, @TotalDaysOut = @TotalDaysReturn OUTPUT
			
			if @TotalDaysReturn<0
				set @TotalDaysReturn=0

			select @TotalDays = @TotalDays + @TotalDaysReturn 

		end
      
	  set @NewTotalDays = (select @TotalDays + @WFHCount  TotalDays)
		--select @TotalDays + @WFHCount  TotalDays, @IsLFA IsLFA ,@IsAgreedWithLM IsAgreedWithLM,@SendOutlookEmailStatus SendOutlookEmailStatus 
		

		
		 INSERT INTO #tt ( LeaveIndex, EmployeeIndex, LeaveType, TotalDays,NewTotalDays, FromDate, ToDate, EntryDate)
		 select leaveindex,employeeindex,leavetype,totaldays as OldTotalDays,@NewTotalDays as NewTotalDays,fromdate,todate,entrydate
		 from LeaveDetail where LeaveIndex=@LeaveIndex
		
		fetch next from cur_Leavedays into @LeaveIndex, @EmployeeIndex, @LeaveType, @TotalDays, @lFromDate, @lToDate

		end
		close cur_Leavedays
		deallocate cur_Leavedays


		 SELECT * FROM #tt where NewTotalDays < TotalDays