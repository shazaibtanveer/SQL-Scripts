go

delete from rpt_MainFilters where ReportIndex = 1826;;
delete from rpt_main where ReportIndex = 1826;;

insert into screens values (13680,'Detailed Overtime Register Day wise',0,0,0,0,0,null,null,0,null);;
insert into rpt_main values (1826,'tm_Rpt_Qry_OT_05','Detailed Overtime Register Day wise',
'Detailed Overtime Register Dynamicaly Day wise','../TMS/CustomAttendanceReport.aspx?', null,1,53,136,13680,1,2,1,null);;

insert into rpt_MainFilters values (1826,1361,10,'From Date',1);;
insert into rpt_MainFilters values (1826,1361,12,'To Date',1.1);;
insert into rpt_MainFilters values (1826,1361,20,'Department',1.1);;
insert into rpt_MainFilters values (1826,1361,21,'Location',1.1);;
insert into rpt_MainFilters values (1826,1361,23,'Territory',1.1);;
insert into rpt_MainFilters values (1826,1361,24,'Unit',1.1);;
insert into rpt_MainFilters values (1826,1361,25,'Division',1.1);;
insert into rpt_MainFilters values (1826,1361,26,'SubDepartment',1.1);;
insert into rpt_MainFilters values (1826,1361,29,'Grade',1.1);;
insert into rpt_MainFilters values (1826,1361,31,'Team',1.1);;
insert into rpt_MainFilters values (1826,1361,33,'BusinessUnit',1.1);;
insert into rpt_MainFilters values (1826,1361,48,'ServiceStatus',1.1);;
insert into rpt_MainFilters values (1826,1361,49,'Employee',1.1);;

go



Create PROCEDURE [dbo].[tm_Rpt_Qry_OT_05]
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
	IF OBJECT_ID('tempdb.dbo.#DateRange', 'U') IS NOT NULL  
        DROP TABLE #DateRange;
	IF OBJECT_ID('tempdb.dbo.#OTime', 'U') IS NOT NULL  
        DROP TABLE #OTime;
	IF OBJECT_ID('tempdb.dbo.#TotalOT', 'U') IS NOT NULL  
        DROP TABLE #TotalOT;

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

    -- Generate DateRange
    ;WITH DateRange AS (
        SELECT CAST(@FromDate AS DATE) AS DateValue, FORMAT(CAST(@FromDate AS DATE), 'MM/dd/yyyy | dddd') AS FormattedDate
        UNION ALL
        SELECT DATEADD(DAY, 1, DateValue), FORMAT(DATEADD(DAY, 1, DateValue), 'MM/dd/yyyy | dddd')
        FROM DateRange
        WHERE DATEADD(DAY, 1, DateValue) <= CAST(@ToDate AS DATE)
    )

    SELECT *
    INTO #DateRange
    FROM DateRange;

    -- Create #InvalidDays temp table for Over Time
    ;WITH OTime AS (
        SELECT 
            S.EmployeeIndex,
            S.AtDate,
			S.ApOvertime
        FROM tm_summary S
        WHERE S.EmployeeIndex IN (SELECT EmployeeIndex FROM #Emp) and IsOT = 1
          AND S.AtDate BETWEEN @FromDate AND @ToDate
    )
    SELECT *
    INTO #OTime
    FROM OTime;

	-- Create temp table #TotalOT for total overtime
	SELECT 
	    EmployeeIndex,
		ROUND(SUM(CAST(ApOTHH AS FLOAT) + CAST(ApOTMI AS FLOAT) / 60.0), 2) AS TotalOvertimeHours,
		CAST(SUM(ApOTHH * 60 + ApOTMI) / 60 AS VARCHAR) + ':' + 
		RIGHT('00' + CAST(SUM(ApOTHH * 60 + ApOTMI) % 60 AS VARCHAR), 2) AS TotalOvertime
	INTO #TotalOT
	FROM tm_summary
	WHERE EmployeeIndex IN (
	    SELECT EmployeeIndex 
	    FROM employee 
	    WHERE clientindex = @ClientIndex
	)
	AND IsOT = 1
	AND AtDate BETWEEN @FromDate AND @ToDate
	GROUP BY EmployeeIndex;

    -- Generate dynamic pivot query
    DECLARE @cols NVARCHAR(MAX),
            @query NVARCHAR(MAX);

SELECT @cols = STUFF(
    (SELECT DISTINCT ', ' + QUOTENAME(FormattedDate)
     FROM #DateRange
     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 
    1, 2, '');


    SET @query = '
    SELECT 
        ROW_NUMBER() OVER (ORDER BY employeeIndex) AS Sno,
        Employeeid,
		EmployeeIndex,
		employeename,
		Fathername,
		positionname,
		DepartmentName,
		Subdepartmentname,
		EmploymentType,
		LocationName,
        ' + @cols + ',
		TotalOvertime,
		TotalOvertimeHours
    FROM (
        SELECT 
            E.Employeeid,
			O.EmployeeIndex,
			E.employeename,
			E.Fathername,
			E.positionname,
			E.DepartmentName,
			E.Subdepartmentname,
			E.EmploymentType,
			E.LocationName,
            DR.FormattedDate,
            O.APOvertime,
			T.TotalOvertime,
			T.TotalOvertimeHours
        FROM #DateRange DR
        inner JOIN #OTime O ON DR.DateValue = O.AtDate
		inner join vwempdetail E On O.Employeeindex = E.employeeindex
		inner join #TotalOT T on O.employeeindex = T.employeeindex
    ) AS SourceTable
    PIVOT (
        MAX(APOvertime)
        FOR FormattedDate IN (' + @cols + ')
    ) AS PivotTable;';
	
    -- Execute the dynamic query
    EXEC sp_executesql @query, N'@ClientIndex INT, @UserEmpIndex INT,@SvcStatus VARCHAR(500), @EmpIndx VARCHAR(500), 
            @StrRegion VARCHAR(500), @StrDepartment VARCHAR(500), 
            @StrLocation VARCHAR(500), @StrClientBranch VARCHAR(500), @strTeam varchar(500),
            @StrTerritory VARCHAR(500), @StrUnit VARCHAR(500), @strclientGrade varchar(500),
            @StrDivision VARCHAR(500), @StrSubDepartment VARCHAR(500),@StrBU VARCHAR(500), 
            @StrART VARCHAR(500), @StrInvNo VARCHAR(500)', 
			@ClientIndex, @UserEmpIndex, @SvcStatus, @EmpIndx, 
            @StrRegion, @StrDepartment, 
            @StrLocation, @StrClientBranch, @strTeam,
            @StrTerritory, @StrUnit, @strclientGrade,
            @StrDivision, @StrSubDepartment,@StrBU, 
            @StrART, @StrInvNo;

    -- Clean up
    DROP TABLE #DateRange, #OTime, #TotalOT, #Emp;
END
