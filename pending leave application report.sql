
Alter PROCEDURE [dbo].[tm_Rpt_Qry_PendingLeaves_01] 
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
    -- select required data
WITH leave AS (
    SELECT 
        leaveindex, employeeindex, leavetype, leavestatus, leavesubstatus, fromdate, todate, totaldays 
    FROM 
        leavedetail 
    WHERE 
        EmployeeIndex IN (SELECT employeeindex FROM #Emp) 
        AND leavestatus = 1
        AND FromDate BETWEEN @Fromdate AND @Todate
),
LM2 AS (
    SELECT 
        EmployeeIndex AS LM2index, 
        Employeename AS LM2name
    FROM 
        employee
    WHERE 
        employeeindex IN (SELECT DISTINCT lm2index FROM employee WHERE clientindex = @clientindex)
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY LD.EmployeeIndex) AS Sno,
	LD.leaveindex,
    E.EmployeeId,
    LD.EmployeeIndex,
    E.EmployeeName,
    E.LMName as 'Line Manager',
    isnull(LM2.LM2Name,'-') As 'Line Manager 2',
    E.UnitName,
    E.divisionname,
	E.Territoryname,
	E.RegionName,
    E.locationname,
    E.departmentname,
	E.SubDepartmentName,
    LCM.LeaveDescription,
    LD.TotalDays,
    FORMAT(LD.FromDate, 'yyyy-MM-dd | dddd') 'From Date',
    FORMAT(LD.ToDate, 'yyyy-MM-dd | dddd') 'To Date',
    CASE
        WHEN LD.LeaveStatus = 1 AND isnull(LD.LeaveSubStatus,0) in (0,1) THEN 'Pending at LineManager'
		WHEN LD.LeaveStatus = 1 AND LD.LeaveSubStatus = 2 THEN 'Pending at Tier 02'
		WHEN LD.LeaveStatus = 1 AND LD.LeaveSubStatus = 5 THEN 'Pending at Tier 03'
        ELSE '-' 
    END AS LeaveStatusDescription
FROM 
    leave LD
INNER JOIN 
    LeaveClientMapping LCM ON LD.LeaveType = LCM.LeaveType AND LCM.clientindex = @clientindex
INNER JOIN 
    vwempdetail E ON LD.EmployeeIndex = E.EmployeeIndex AND E.clientindex = @clientindex
LEFT OUTER JOIN 
    LM2 ON E.lm2index = LM2.LM2index
Order by sno
END
