Alter PROCEDURE [dbo].[tm_Rpt_Qry_AvailedLeaves_01] 
    @ClientIndex int,           
    @FromDate nvarchar(10),            
    @ToDate nvarchar(10),           
    @UserEmpIndex int,          
    @Str varchar(max) = ''
     
AS
   

BEGIN
-- Declare internal variables only for this report
    DECLARE @columns NVARCHAR(MAX) = ''
    DECLARE @sql NVARCHAR(MAX) = ''
-- Declare internal variables only for this report


    DECLARE @StrRegion VARCHAR(500) = ''
    DECLARE @StrDepartment VARCHAR(500) = ''
    DECLARE @StrLocation VARCHAR(500) = ''
    DECLARE @StrClientBranch VARCHAR(500) = ''
    DECLARE @StrTerritory VARCHAR(500) = ''
    DECLARE @StrUnit VARCHAR(500) = ''
    DECLARE @StrDivision VARCHAR(500) = ''
    DECLARE @StrBU VARCHAR(500) = ''
    DECLARE @StrInvNo VARCHAR(500) = ''
    DECLARE @StrART VARCHAR(500) = ''

    -- Parsing and setting values based on the prefix
    SELECT 
        @StrRegion = MAX(CASE WHEN CHARINDEX('WL1:', col1) > 0 THEN REPLACE(col1, 'WL1:', '') ELSE '' END),
        @StrDepartment = MAX(CASE WHEN CHARINDEX('WL2:', col1) > 0 THEN REPLACE(col1, 'WL2:', '') ELSE '' END),
        @StrLocation = MAX(CASE WHEN CHARINDEX('WL3:', col1) > 0 THEN REPLACE(col1, 'WL3:', '') ELSE '' END),
        @StrClientBranch = MAX(CASE WHEN CHARINDEX('WL4:', col1) > 0 THEN REPLACE(col1, 'WL4:', '') ELSE '' END),
        @StrTerritory = MAX(CASE WHEN CHARINDEX('WL5:', col1) > 0 THEN REPLACE(col1, 'WL5:', '') ELSE '' END),
        @StrUnit = MAX(CASE WHEN CHARINDEX('WL7:', col1) > 0 THEN REPLACE(col1, 'WL7:', '') ELSE '' END),
        @StrDivision = MAX(CASE WHEN CHARINDEX('WL8:', col1) > 0 THEN REPLACE(col1, 'WL8:', '') ELSE '' END),
        @StrBU = MAX(CASE WHEN CHARINDEX('WL23:', col1) > 0 THEN REPLACE(col1, 'WL23:', '') ELSE '' END),
        @StrInvNo = MAX(CASE WHEN CHARINDEX('WL6:', col1) > 0 THEN REPLACE(col1, 'WL6:', '') ELSE '' END),
        @StrART = MAX(CASE WHEN CHARINDEX('ART:', col1) > 0 THEN REPLACE(col1, 'ART:', '') ELSE '' END)
    FROM dbo.fnParseArray(@Str, '^');

    -- Step 1: Get the column headers dynamically
    SET @columns = (
        SELECT STUFF((
            SELECT ', ' + QUOTENAME(leavedescription)
            FROM LeaveClientMapping
            WHERE clientindex = @ClientIndex
            ORDER BY LeaveType
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') -- Remove the leading comma
    );

    -- Step 2: Construct the dynamic SQL query
    SET @sql = N'
    ;WITH leavename AS (
        SELECT leavetype, leavedescription 
        FROM LeaveClientMapping 
        WHERE clientindex = @ClientIndex
    ),
    leave_details AS (
        SELECT e.employeeid, e.EmployeeIndex, e.employeename, e.Locationname, e.BUname, 
               e.Departmentname, e.subdepartmentname, e.divisionname, e.Territoryname, e.PositionName,
               ISNULL(Sum(L.Totaldays), 0) AS Availed_leaves,
               COALESCE(leavename.leavedescription, ''Unknown'') AS leavedescription
        FROM vwempdetail e
        LEFT JOIN leavedetail L ON e.employeeindex = L.employeeindex AND L.Fromdate BETWEEN @FromDate AND @ToDate
        LEFT JOIN leavename ON (CASE WHEN L.totaldays = 0.5 THEN L.oLeaveType ELSE L.leavetype END) = leavename.leavetype
        WHERE E.Clientindex = @ClientIndex And L.leavestatus in (2,3,7)
        AND E.EmployeeIndex IN (SELECT EmployeeIndex FROM acm_VwEmpAuthority WHERE UserEmpIndex = @UserEmpIndex AND wlcat = 3)
        AND (@StrRegion = '''' OR E.RegionIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrRegion, '','')))
        AND (@StrDepartment = '''' OR E.DepartmentIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrDepartment, '','')))
        AND (@StrLocation = '''' OR E.LocationIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrLocation, '','')))
        AND (@StrClientBranch = '''' OR E.ClientBranchIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrClientBranch, '','')))
        AND (@StrTerritory = '''' OR E.TerritoryIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrTerritory, '','')))
        AND (@StrUnit = '''' OR E.UnitIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrUnit, '','')))
        AND (@StrDivision = '''' OR E.DivisionIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrDivision, '','')))
        AND (@StrBU = '''' OR E.BUIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrBU, '','')))
        GROUP BY e.employeeid, e.EmployeeIndex, e.employeename, e.Locationname, e.BUname, 
                 e.Departmentname, e.subdepartmentname, e.divisionname, e.Territoryname, e.PositionName, 
                 leavename.leavedescription
    )
    SELECT 
        divisionname, Territoryname, BUname, Locationname, Departmentname, subdepartmentname, 
        PositionName, employeeid, EmployeeIndex, employeename, ' + @columns + N'
    FROM 
    (
        SELECT * FROM leave_details
    ) AS SourceTable
    PIVOT 
    (
        SUM(Availed_leaves)
        FOR leavedescription IN (' + @columns + N')
    ) AS PivotTable
    ORDER BY EmployeeIndex;';

    -- Step 3: Execute the dynamic SQL
    EXEC sp_executesql @sql, 
                       N'@ClientIndex INT, @FromDate DATE, @ToDate DATE, @StrRegion VARCHAR(500), 
                         @StrDepartment VARCHAR(500), @StrLocation VARCHAR(500), @StrClientBranch VARCHAR(500), 
                         @StrTerritory VARCHAR(500), @StrUnit VARCHAR(500), @StrDivision VARCHAR(500), @StrBU VARCHAR(500), 
                         @UserEmpIndex INT', 
                       @ClientIndex = @ClientIndex, @FromDate = @FromDate, @ToDate = @ToDate, 
                       @StrRegion = @StrRegion, @StrDepartment = @StrDepartment, @StrLocation = @StrLocation, 
                       @StrClientBranch = @StrClientBranch, @StrTerritory = @StrTerritory, @StrUnit = @StrUnit, 
                       @StrDivision = @StrDivision, @StrBU = @StrBU, @UserEmpIndex = @UserEmpIndex;
END;