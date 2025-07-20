Alter procedure [dbo].[tm_Rpt_Qry_CPL_01]   
      
    @ClientIndex INT ,      
    @FromDate DATE ,      
    @ToDate DATE ,      
    @UserEmpIndex INT ,     
    @Str NVARCHAR(100) = ''   
As
BEGIN    
    -- Declare all variables
    DECLARE @Str2 VARCHAR(1000), @SvcStatus VARCHAR(500) = '', @EmpIndx VARCHAR(500) = '', 
            @StrRegion VARCHAR(500) = '', @StrDepartment VARCHAR(500) = '', 
            @StrLocation VARCHAR(500) = '', @StrClientBranch VARCHAR(500) = '', 
            @StrTerritory VARCHAR(500) = '', @StrUnit VARCHAR(500) = '', 
            @StrDivision VARCHAR(500) = '',@StrSubDepartment VARCHAR(500) = '', @StrBU VARCHAR(500) = '', 
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
          AND (@StrBU = '' OR BUIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrBU, ',')));
    END;

    -- Conditional Queries Based on Leave Status
    IF EXISTS (SELECT 1 FROM LeaveDetail WHERE leavetype = 9 AND LeaveStatus = 12 
                AND employeeindex IN (SELECT EmployeeIndex FROM #Emp) 
                AND FromDate BETWEEN @FromDate AND @ToDate)
    BEGIN
        SELECT 
            E.employeeid,
            LD.employeeindex,
            E.employeename,
			E.TerritoryName,
			E.DivisionName,
			E.unitname,
            E.LocationName,
            E.DepartmentName,
            E.subdepartmentname,
            LCM.LeaveDescription,
            FORMAT(LD.FromDate, 'yyyy-MM-dd') AS 'InLieu Against Date',
            FORMAT(LD.FromDate, 'dddd') AS 'InLieu Against Day',
            LD.TotalDays,
            LD.Reason,
            LD.EntryDate
        FROM LeaveDetail LD
        INNER JOIN VwEmpDetail E ON LD.employeeindex = E.EmployeeIndex
        INNER JOIN LeaveClientMapping LCM ON LD.LeaveType = LCM.leavetype AND LCM.ClientIndex = @ClientIndex
        WHERE LD.employeeindex IN (SELECT EmployeeIndex FROM #Emp)
          AND LD.leavetype = 9
          AND LD.LeaveStatus = 12
          AND LD.FromDate BETWEEN @FromDate AND @ToDate;
    END
    ELSE 
    BEGIN
        SELECT 
            E.employeeid,
            LOB.employeeindex,
            E.employeename,
            E.TerritoryName,
			E.DivisionName,
			E.unitname,
            E.Locationname,
            E.DepartmentName,
            E.Subdepartmentname,
            E.grade,
            LOB.LOBIndex,
            LCM.LeaveDescription,
            FORMAT(LOB.FromDate, 'yyyy-MM-dd (dddd)') AS 'CPL Start Date',
            FORMAT(LOB.ToDate, 'yyyy-MM-dd (dddd)') AS 'CPL Expire Date',
            LOB.Allowed,
            CASE WHEN LOB.ToDate < GETDATE() THEN 'Expired' ELSE 'Available' END AS 'Status',
            LOB.Remarks,
            LOB.PostDate
        FROM LeaveOtherBalance LOB
        INNER JOIN VwEmpDetail E ON LOB.EmployeeIndex = E.EmployeeIndex
        INNER JOIN LeaveClientMapping LCM ON LOB.LeaveType = LCM.LeaveType AND LCM.ClientIndex = @ClientIndex
        WHERE LOB.EmployeeIndex IN (SELECT EmployeeIndex FROM #Emp)
          AND LOB.FromDate BETWEEN @FromDate AND @ToDate
        ORDER BY LOB.PostDate DESC;
    END;
END;
