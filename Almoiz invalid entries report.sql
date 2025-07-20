go

insert into screens values (13676,'Detailed Invalid (Missing IN & OUT) Entries Report',0,0,0,0,0,null,null,0,null);;
insert into rpt_main values (1823,'tm_Rpt_Qry_InvalidEntries_02','Detailed Invalid (Missing IN & OUT) Entries Report',
'Detailed Invalid (Missing IN & OUT) Entries Report','../TMS/CustomAttendanceReport.aspx?', null,1,53,136,13676,1,2,1,null);;

insert into rpt_MainFilters values (1823,1361,10,'From Date',1);;
insert into rpt_MainFilters values (1823,1361,12,'To Date',1.1);;
insert into rpt_MainFilters values (1823,1361,20,'Department',1.1);;
insert into rpt_MainFilters values (1823,1361,21,'Location',1.1);;
insert into rpt_MainFilters values (1823,1361,23,'Territory',1.1);;
insert into rpt_MainFilters values (1823,1361,24,'Unit',1.1);;
insert into rpt_MainFilters values (1823,1361,25,'Division',1.1);;
insert into rpt_MainFilters values (1823,1361,26,'SubDepartment',1.1);;
insert into rpt_MainFilters values (1823,1361,29,'Grade',1.1);;
insert into rpt_MainFilters values (1823,1361,31,'Team',1.1);;
insert into rpt_MainFilters values (1823,1361,33,'BusinessUnit',1.1);;
insert into rpt_MainFilters values (1823,1361,48,'ServiceStatus',1.1);;
insert into rpt_MainFilters values (1823,1361,49,'Employee',1.1);;

go


Create procedure [dbo].[tm_Rpt_Qry_InvalidEntries_02]
    @ClientIndex INT,           
    @FromDate NVARCHAR(10),            
    @ToDate NVARCHAR(10),           
    @UserEmpIndex INT,          
    @Str VARCHAR(MAX) = ''
AS                                   
BEGIN
    -- Declare all variables
    DECLARE @Str2 VARCHAR(1000), @SvcStatus VARCHAR(500) = '', @EmpIndx VARCHAR(500) = '', 
            @StrRegion VARCHAR(500) = '', @StrDepartment VARCHAR(500) = '', 
            @StrLocation VARCHAR(500) = '', @StrClientBranch VARCHAR(500) = '', @strTeam varchar(500)='',
            @StrTerritory VARCHAR(500) = '', @StrUnit VARCHAR(500) = '', @strclientGrade varchar(500)='',
            @StrDivision VARCHAR(500) = '', @StrSubDepartment VARCHAR(500) = '',@StrBU VARCHAR(500) = '', 
            @StrART VARCHAR(500) = '', @StrInvNo VARCHAR(500) = '';

    DECLARE cur_LeavePeriod CURSOR FOR
        SELECT col1 FROM dbo.fnParseArray(@Str, '^');
    OPEN cur_LeavePeriod;
    FETCH NEXT FROM cur_LeavePeriod INTO @Str2;
    WHILE @@FETCH_STATUS = 0    
    BEGIN
        -- Use conditional parsing and set values directly based on prefixes
        IF CHARINDEX('WL1:', @Str2) > 0 SET @StrRegion = REPLACE(@Str2, 'WL1:', '');
        IF CHARINDEX('WL2:', @Str2) > 0 SET @StrDepartment = REPLACE(@Str2, 'WL2:', '');
        IF CHARINDEX('WL3:', @Str2) > 0 SET @StrLocation = REPLACE(@Str2, 'WL3:', '');
        IF CHARINDEX('WL4:', @Str2) > 0 SET @StrClientBranch = REPLACE(@Str2, 'WL4:', '');
        IF CHARINDEX('WL5:', @Str2) > 0 SET @StrTerritory = REPLACE(@Str2, 'WL5:', '');
        IF CHARINDEX('WL6:', @Str2) > 0 SET @StrInvNo = REPLACE(@Str2, 'WL6:', '');
        IF CHARINDEX('WL7:', @Str2) > 0 SET @StrUnit = REPLACE(@Str2, 'WL7:', '');
        IF CHARINDEX('WL8:', @Str2) > 0 SET @StrDivision = REPLACE(@Str2, 'WL8:', '');
		IF CHARINDEX('WL9:', @Str2) > 0 SET @StrSubdepartment = REPLACE(@Str2, 'WL9:', '');
		if charindex('WL15:', @Str2) > 0 set @strclientGrade = REPLACE(@Str2,'WL15:','');
		if charindex('WL18:', @Str2) > 0 set @strTeam = REPLACE(@Str2,'WL18:','');
        IF CHARINDEX('WL23:', @Str2) > 0 SET @StrBU = REPLACE(@Str2, 'WL23:', '');
        IF CHARINDEX('ART:', @Str2) > 0 SET @StrART = REPLACE(@Str2, 'ART:', '');
        IF CHARINDEX('EmpIndx:', @Str2) > 0 SET @EmpIndx = REPLACE(@Str2, 'EmpIndx:', '');
        IF CHARINDEX('SS:', @Str2) > 0 SET @SvcStatus = REPLACE(@Str2, 'SS:', '');
		
        FETCH NEXT FROM cur_LeavePeriod INTO @Str2;
    END;
    CLOSE cur_LeavePeriod;
    DEALLOCATE cur_LeavePeriod;

    -- Initialize the #Emp temp table
    IF OBJECT_ID('tempdb.dbo.#Emp', 'U') IS NOT NULL  
        DROP TABLE #Emp;

    CREATE TABLE #Emp (EmployeeIndex INT);

    SET @SvcStatus = ISNULL(NULLIF(LTRIM(RTRIM(@SvcStatus)), ''), '1');

    -- Populate the #Emp table based on conditions
    IF LTRIM(RTRIM(@EmpIndx)) <> ''
    BEGIN
        INSERT INTO #Emp (EmployeeIndex)
        SELECT employeeindex
        FROM employee
        WHERE employeeindex IN (SELECT col1 FROM dbo.fnParseArray(@EmpIndx, ','))
          AND (ServiceStatus IN (SELECT col1 FROM dbo.fnParseArray(@SvcStatus, ',')));
    END
    ELSE
    BEGIN
        INSERT INTO #Emp (EmployeeIndex)
        SELECT employeeindex
        FROM employee
        WHERE clientindex = @ClientIndex 
          AND employeeindex IN (SELECT EmployeeIndex FROM acm_VwEmpAuthority WHERE UserEmpIndex = @UserEmpIndex AND WLCat = 3)
          AND (ServiceStatus IN (SELECT col1 FROM dbo.fnParseArray(@SvcStatus, ',')))
          AND (@StrRegion = '' OR RegionIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrRegion, ',')))
          AND (@StrDepartment = '' OR DepartmentIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrDepartment, ',')))
          AND (@StrLocation = '' OR LocationIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrLocation, ',')))
          AND (@StrClientBranch = '' OR ClientBranchIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrClientBranch, ',')))
          AND (@StrTerritory = '' OR TerritoryIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrTerritory, ',')))
          AND (@StrUnit = '' OR UnitIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrUnit, ',')))
          AND (@StrDivision = '' OR DivisionIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrDivision, ',')))
		  AND (@StrSubdepartment = '' OR Subdepartmentindex IN (SELECT col1 FROM dbo.fnParseArray(@StrSubdepartment, ',')))
		  And (@strclientGrade  ='' or GradeIndex in(select col1 from dbo.fnParseArray(@strclientGrade,',')))
		  And (@strTeam  ='' or TeamIndex in(select col1 from dbo.fnParseArray(@strTeam,',')))
          AND (@StrBU = '' OR BUIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrBU, ',')));
    END;
select		
	ROW_NUMBER() over (order by s.EmployeeIndex asc) SNo,		
	s.EmployeeIndex As 'Employee Index',
	e.EmployeeId As 'Employee ID',
	e.EmployeeName As 'Employee Name',
	e.Fathername As 'Father Name',
	e.positionname As 'Designation',
	e.Departmentname As 'Department Name',
	e.Subdepartmentname As 'SubDepartment Name',
	e.EmploymentType As 'Employeement Type',
	e.unitname As 'Unit Name',
	FORMAT(s.AtDate, 'MM/dd/yyyy dddd') AS 'Attendance Date',
	isnull(CONVERT(VARCHAR(8), s.EmpIn, 108),'-') 'EmpIn',
	isnull(CONVERT(VARCHAR(8), s.EmpOut, 108),'-') 'EmpOut',
	r.RosterCode As 'Roster Code',
	e.AtGroupName  As 'ATGroup Name'						
from tm_Summary s 
	left outer join VwEmpDetail e on s.employeeindex  = e.employeeindex
	left outer join tm_VWempShift sft  on s.employeeindex = sft.employeeindex and s.atdate = sft.dt
	left outer join tm_roster r on sft.RosterIndex = r.RosterIndex
where
	e.clientindex = @ClientIndex and s.atdate between @FromDate and @TODate
	and s.clientindex  = @clientindex and S.employeeindex in (select employeeindex from #EMP)
	and ((s.Empin is null or s.empout is null or s.empIn = s.EmpOut))
	and (s.IsAttendance=1 or ( s.IsHoliday=1 and (s.empin is not null or s.empout is not null)))
	and	(e.servicestatus=1 or (e.servicestatus = 2 and e.serviceenddate between @FromDate and @ToDate))
	and isnull(s.IsExempt,0)=0
order by  e.EmployeeIndex 

    -- Clean up
    DROP TABLE #Emp;
END
