--Go
--insert into screens values (13713,'Earned Leave Balance Report - Finance',0,0,0,0,0,null,null,0,null);;

--insert into rpt_main values (1845,'tm_Rpt_Qry_TCFFinance_01','Earned Leave Balance Report - Finance',
--'A detail report with encashment ammount of currently aviable Earned leave balance only TCF Finance Department',
--'../TMS/CustomAttendanceReport.aspx?', null,1,53,136,13713,1,2,1,null,null);;

--insert into rpt_MainFilters values (1845,1361,10,'From Date',1);;
--insert into rpt_MainFilters values (1845,1361,12,'To Date',1.1);;
--insert into rpt_MainFilters values (1845,1361,20,'Department',1.1);;
--insert into rpt_MainFilters values (1845,1361,21,'Location',1.1);;
--insert into rpt_MainFilters values (1845,1361,23,'Territory',1.1);;
--insert into rpt_MainFilters values (1845,1361,24,'Unit',1.1);;
--insert into rpt_MainFilters values (1845,1361,25,'Division',1.1);;
--insert into rpt_MainFilters values (1845,1361,26,'SubDepartment',1.1);;
--insert into rpt_MainFilters values (1845,1361,29,'Grade',1.1);;
--insert into rpt_MainFilters values (1845,1361,31,'Team',1.1);;
--insert into rpt_MainFilters values (1845,1361,33,'BusinessUnit',1.1);;
--insert into rpt_MainFilters values (1845,1361,48,'ServiceStatus',1.1);;
--insert into rpt_MainFilters values (1845,1361,49,'Employee',1.1);;

--Go


Alter PROCEDURE [dbo].[tm_Rpt_Qry_TCFFinance_01] 
    @ClientIndex int,           
    @FromDate nvarchar(10),            
    @ToDate nvarchar(10),           
    @UserEmpIndex int,          
    @Str varchar(max) = ''            
AS
BEGIN
  -- Declare all variables
    DECLARE @Str2 VARCHAR(1000), @SvcStatus VARCHAR(500) = '', @EmpIndx VARCHAR(500) = '', 
            @StrRegion VARCHAR(500) = '', @StrDepartment VARCHAR(500) = '', 
            @StrLocation VARCHAR(500) = '', @StrClientBranch VARCHAR(500) = '', @strTeam varchar(500)='',
            @StrTerritory VARCHAR(500) = '', @StrUnit VARCHAR(500) = '', @strclientGrade varchar(500)='',
            @StrDivision VARCHAR(500) = '', @StrSubDepartment VARCHAR(500) = '',@StrBU VARCHAR(500) = '', 
            @StrART VARCHAR(500) = '', @StrInvNo VARCHAR(500) = '';
	DECLARE @ToDateDate DATE = CAST(@ToDate AS DATE)
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
          AND employeeindex IN (SELECT EmployeeIndex FROM Employee WHERE clientindex = @ClientIndex and BUIndex = 152 and TerritoryIndex = 25150)
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
    -- select required data
SELECT 
    e.employeeid as [Employee ID],
    lb.EmployeeIndex as [Employee Index],
    e.employeename as [Employee Name],
	e.DepartmentName as [Department Name],
	e.SubDepartmentName as [Sub Department],
	e.EmploymentType as [Employment Type],
	e.ServiceStatusDesc as [Service Status],
    FORMAT(e.ServiceStartDate, 'MM/dd/yyyy') AS [Service Start Date],
    isnull(FORMAT(e.sconfirmationdate, 'MM/dd/yyyy'),'-') AS [Confirmation Date],
    Case WHEN e.ServiceEndDate = '01/01/1900' THEN '-' ELSE FORMAT(e.ServiceEndDate, 'MM/dd/yyyy') END AS [Service End Date],
	isnull(FS.FSstatus,0) AS [FS Status],
	FORMAT(@ToDateDate, 'MMMM, yyyy') as [Balance Till Month],
    'Earned Leave' As [Leave Type],
    CASE when lb.Closing < 0 THEN 0 WHEN lb.Closing > 56 THEN 56.0 ELSE lb.Closing END AS [Closing Balance],
	e.CurrentGrossSalary as [Current Gross Salary],
	Round(CASE when lb.Closing < 0 THEN 0 WHEN lb.Closing > 56 THEN 56.0 ELSE lb.Closing END * (CAST(e.CurrentGrossSalary AS DECIMAL(18,2)) * 12) / 247,2) AS [Encashment Ammount]
FROM 
    vwempdetail e
CROSS APPLY 
    fnleavebalance(e.EmployeeIndex, @ToDateDate) lb
left outer join 
	FS_master FS on lb.EmployeeIndex = FS.EmployeeIndex
WHERE 
    e.employeeindex in (select employeeindex from #emp) and lb.LeaveType = 3 and isnull(FS.FSStatus,0) = 0
Order by 
	e.EmployeeIndex
END
