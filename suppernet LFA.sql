declare 
@leaveindex int = 1852639

declare 
@employeeindex int,
@leavetype int,
@Leavedate date,
@ALLeavedate date,
@curentyearstartdate date,
@Firstlastpayrollmonth date,
@Secondlastpayrollmonth date,
@FirstLastyearstartdate date,
@FirstLastyearendate date,
@secondLastyearstartdate date,
@secondLastyearendate date,
@LFAFirstLastYear tinyint,
@LFASecondLastYear tinyint,
@curentyearAL int,
@FirstLastyearAL int,
@servicestartdate date,
@ALcount int

select @Leavedate = fromdate , @employeeindex = employeeindex , @leavetype  = LeaveType from leavedetail where LeaveIndex = @leaveindex
select @servicestartdate = servicestartdate from employee where employeeindex  =  @employeeindex
select @curentyearstartdate = FromDate from fnleaveperiod(@employeeindex,@leavedate) where LeaveType  = @leavetype
set @Firstlastpayrollmonth = DATEADD(MONTH, -1, @curentyearstartdate)
select @FirstLastyearstartdate = FromDate , @FirstLastyearendate = ToDate from fnleaveperiod(@employeeindex,@Firstlastpayrollmonth) where LeaveType  = @leavetype
set @Secondlastpayrollmonth = DATEADD(MONTH, -1, @FirstLastyearstartdate)
select @secondLastyearstartdate = FromDate , @secondLastyearendate = ToDate from fnleaveperiod(@employeeindex,@Secondlastpayrollmonth) where LeaveType  = @leavetype
select @curentyearAL = Availed from fnLeaveBalance(@employeeindex,@Leavedate) where LeaveType = 3
select @FirstLastyearAL = Availed from fnLeaveBalance(@employeeindex,@Firstlastpayrollmonth) where LeaveType = 3

if EXISTS (select 1 from leavedetail where employeeindex  =  @employeeindex and leavetype  = @leavetype 
and fromdate between @secondLastyearstartdate and @secondLastyearendate and LeaveStatus in (1,2)) 
and @secondLastyearstartdate > @servicestartdate
	set @LFAFirstLastYear = 1
	Set @LFASecondLastYear = 0 

if @servicestartdate > @secondLastyearendate
	set @LFAFirstLastYear = 1
	Set @LFASecondLastYear = 0

if NOT EXISTS (select 1 from leavedetail where employeeindex  =  @employeeindex and leavetype  = @leavetype 
and fromdate between @secondLastyearstartdate and @secondLastyearendate and LeaveStatus in (1,2)) 
and @secondLastyearstartdate > @servicestartdate 
	set @LFAFirstLastYear = 0
	Set @LFASecondLastYear = 1

IF @LFASecondLastYear = 1
	set @ALLeavedate = @Firstlastpayrollmonth
	Set @ALcount = @FirstLastyearAL
IF @LFAFirstLastYear = 1
	Set @ALLeavedate = @Leavedate
	Set @ALcount = @curentyearAL

Begin
	DECLARE 
	@countAL INT = 5 - @ALcount,
	@i INT = 1,
	@leaveIndexAL INT
	
	SELECT @leaveIndexAL = ISNULL(MAX(LeaveIndex), 0) + 1 FROM LeaveDetail
	
	WHILE @i <= @countAL
	BEGIN
		SET @leaveIndexAL = @leaveIndexAL + 1
	    --INSERT INTO LeaveDetail (LeaveIndex, EmployeeIndex, LeaveType,serialNo, TotalDays, LeaveStatus, Reason,FromDate, ToDate, EntryBy, EntryDate)
		SELECT @leaveIndexAL, @employeeindex, 3, 1, 1, 7, 'Deducted against LFA',@ALLeavedate, @ALLeavedate, @employeeindex, GETDATE() , @servicestartdate
	    SET @i = @i + 1
	END
END




DECLARE @leaveindex INT = 1852639

-- Declare all required variables
DECLARE 
    @employeeindex INT,
    @leavetype INT,
    @Leavedate DATE,
    @ALLeavedate DATE,
    @curentyearstartdate DATE,
    @Firstlastpayrollmonth DATE,
    @Secondlastpayrollmonth DATE,
    @FirstLastyearstartdate DATE,
    @FirstLastyearendate DATE,
    @secondLastyearstartdate DATE,
    @secondLastyearendate DATE,
    @LFAFirstLastYear TINYINT = 0,
    @LFASecondLastYear TINYINT = 0,
    @curentyearAL INT,
    @FirstLastyearAL INT,
    @servicestartdate DATE,
    @ALcount INT

-- Get leave detail and employee data in one go
SELECT 
    @Leavedate = LD.FromDate,
    @employeeindex = LD.EmployeeIndex,
    @leavetype = LD.LeaveType,
    @servicestartdate = E.ServiceStartDate
FROM LeaveDetail LD
JOIN Employee E ON E.EmployeeIndex = LD.EmployeeIndex
WHERE LD.LeaveIndex = @leaveindex

-- Get current year leave period
SELECT @curentyearstartdate = FromDate
FROM fnLeavePeriod(@employeeindex, @Leavedate)
WHERE LeaveType = @leavetype

-- Calculate prior months
SET @Firstlastpayrollmonth = DATEADD(MONTH, -1, @curentyearstartdate)
SET @Secondlastpayrollmonth = DATEADD(MONTH, -1, @Firstlastpayrollmonth)

-- Get leave periods for prior years
SELECT 
    @FirstLastyearstartdate = FromDate,
    @FirstLastyearendate = ToDate
FROM fnLeavePeriod(@employeeindex, @Firstlastpayrollmonth)
WHERE LeaveType = @leavetype

SELECT 
    @secondLastyearstartdate = FromDate,
    @secondLastyearendate = ToDate
FROM fnLeavePeriod(@employeeindex, @Secondlastpayrollmonth)
WHERE LeaveType = @leavetype

-- Get availed leaves
SELECT @curentyearAL = Availed
FROM fnLeaveBalance(@employeeindex, @Leavedate)
WHERE LeaveType = 3

SELECT @FirstLastyearAL = Availed
FROM fnLeaveBalance(@employeeindex, @Firstlastpayrollmonth)
WHERE LeaveType = 3

-- Evaluate which LFA year applies
IF @servicestartdate > @secondLastyearendate
BEGIN
    SET @LFAFirstLastYear = 1
END
ELSE IF EXISTS (
    SELECT 1 
    FROM LeaveDetail 
    WHERE EmployeeIndex = @employeeindex 
      AND LeaveType = @leavetype 
      AND FromDate BETWEEN @secondLastyearstartdate AND @secondLastyearendate
      AND LeaveStatus IN (1, 2)
)
BEGIN
    SET @LFAFirstLastYear = 1
END
ELSE IF @secondLastyearstartdate > @servicestartdate
BEGIN
    SET @LFASecondLastYear = 1
END

-- Determine AL leave date and count
IF @LFASecondLastYear = 1
BEGIN
    SET @ALLeavedate = @Firstlastpayrollmonth
    SET @ALcount = @FirstLastyearAL
END
ELSE IF @LFAFirstLastYear = 1
BEGIN
    SET @ALLeavedate = @Leavedate
    SET @ALcount = @curentyearAL
END

-- Insert dummy LFA AL entries
BEGIN
    DECLARE 
        @countAL INT = 5 - ISNULL(@ALcount, 0),
        @i INT = 1,
        @leaveIndexAL INT

    -- Get max LeaveIndex once
    SELECT @leaveIndexAL = ISNULL(MAX(LeaveIndex), 0) FROM LeaveDetail

    WHILE @i <= @countAL
    BEGIN
        SET @leaveIndexAL = @leaveIndexAL + 1

        -- Replace SELECT with INSERT if needed
        SELECT 
            @leaveIndexAL AS LeaveIndex,
            @employeeindex AS EmployeeIndex,
            3 AS LeaveType,
            1 AS SerialNo,
            1 AS TotalDays,
            7 AS LeaveStatus,
            'Deducted against LFA' AS Reason,
            @ALLeavedate AS FromDate,
            @ALLeavedate AS ToDate,
            @employeeindex AS EntryBy,
            GETDATE() AS EntryDate,
            @servicestartdate AS ServiceStartDate

        SET @i = @i + 1
    END
END
