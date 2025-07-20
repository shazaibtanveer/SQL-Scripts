Alter PROCEDURE [dbo].[tm_Rpt_Qry_offday_01]
    @ClientIndex INT,           
    @FromDate NVARCHAR(10),            
    @ToDate NVARCHAR(10),           
    @UserEmpIndex INT,          
    @Str VARCHAR(MAX) = ''
AS                                   
BEGIN

--exec tm_Rpt_Qry_offday_01 1231,'2023-01-01','2023-01-31',300136

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
		IF CHARINDEX('WL9:', @Str2) > 0 SET @StrSubdepartment = REPLACE(@Str2, 'WL8:', '');
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


    -- Step 1: Generate a list of dates within the specified range with day name
    ;WITH DateRange AS (
        SELECT CAST(@FromDate AS DATE) AS DateValue, FORMAT(CAST(@FromDate AS DATE), 'yyyy-MM-dd (dddd)') AS FormattedDate
        UNION ALL
        SELECT DATEADD(DAY, 1, DateValue), FORMAT(DATEADD(DAY, 1, DateValue), 'yyyy-MM-dd (dddd)')
        FROM DateRange
        WHERE DATEADD(DAY, 1, DateValue) <= CAST(@ToDate AS DATE)
    )
    SELECT FormattedDate, DateValue
    INTO #DateRange
    FROM DateRange;

    -- Step 2: Create the dynamic pivot query
    DECLARE @cols AS NVARCHAR(MAX),
            @query AS NVARCHAR(MAX);

    -- Generate the list of date columns (with both date and day name)
    SELECT @cols = COALESCE(@cols + ', ', '') + QUOTENAME(FormattedDate)
    FROM #DateRange;

	-- Geting data for Piviot--
	-- Create the #DATA table with the necessary structure
CREATE TABLE #DATA (
    EmployeeIndex INT,
    EmployeeID NVARCHAR(50),
    EmployeeName NVARCHAR(255),
    TerritoryName NVARCHAR(255),
    UnitName NVARCHAR(255),
    LocationName NVARCHAR(255),
    DepartmentName NVARCHAR(255),
    SubDepartmentName NVARCHAR(255),
    PositionName NVARCHAR(255),
    [Date] NVARCHAR(255),
    RosterIndex NVARCHAR(255)
);

-- Insert data into the #DATA table
INSERT INTO #DATA (
    EmployeeIndex,
    EmployeeID,
    EmployeeName,
    TerritoryName,
    UnitName,
    LocationName,
    DepartmentName,
    SubDepartmentName,
    PositionName,
    [Date],
    RosterIndex
)
SELECT 
    E.EmployeeIndex, 
    E.EmployeeID,
    E.EmployeeName,
    E.TerritoryName,
    E.UnitName,
    E.LocationName,
    E.DepartmentName,
    E.SubDepartmentName,
    E.PositionName,
    DR.FormattedDate AS [Date], 
    ISNULL(EO.HolidayDesc, '') AS RosterIndex
FROM 
    vwEmpDetail E
CROSS JOIN 
    #DateRange DR
LEFT JOIN 
    tm_VwEmpOff EO 
    ON E.EmployeeIndex = EO.EmployeeIndex 
    AND EO.HolidayDate = DR.DateValue
WHERE 
    E.EmployeeIndex IN (SELECT EmployeeIndex FROM #Emp);

	-- Geting data for Piviot--

    -- Create the dynamic SQL for pivot
    SET @query = '
    SELECT ROW_NUMBER() OVER (ORDER BY EmployeeIndex) AS Sno, employeeIndex, Employeeid, Employeename,Territoryname, Unitname, LocationName, DepartmentName,Subdepartmentname, positionname, ' + @cols + '
    FROM (
        SELECT * from #DATA
    ) AS SourceTable
    PIVOT (
      MAX(RosterIndex)
	  FOR Date IN (' + @cols + ')
    ) AS PivotTable
    ORDER BY employeeIndex;';

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
    DROP TABLE #DateRange, #Emp, #DATA;
END
