
Alter PROCEDURE [dbo].[tm_Rpt_Qry_PostedLeaves_01] 
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
;WITH ProcessByIndex AS (
    -- This CTE calculates userindex and employeeindex based on the length of ProcessBy
    SELECT 
			LH.LeaveIndex,
			(case when isnull(lh.ProcessBy,0) = 0 then 0 else (case when lh.ProcessBy < 33000 then lh.ProcessBy else 0 end  ) end ) UserIndex,
			(case when isnull(lh.UserEmpIndex,0) > 0 then UserEmpIndex else (case when isnull(lh.ProcessBy,0) > 33000 then lh.ProcessBy else 0 end  ) end ) EmployeeIndex,
            LH.ProcessDate,
            ROW_NUMBER() OVER (PARTITION BY LH.LeaveIndex ORDER BY LH.ProcessNo DESC) AS rn
    FROM LeaveHistory LH
    WHERE LH.LeaveIndex IN (SELECT LeaveIndex FROM LeaveDetail WHERE EmployeeIndex in 
	(select employeeindex from employee where clientindex = @ClientIndex ) and Fromdate between @fromdate and @todate)
	),
ProcessByNameget AS (
    -- This CTE joins ProcessByIndex with RegisteredUsers and Employee to get the names
    SELECT 
           PBI.LeaveIndex as Leaveindex, 
           CASE
               WHEN isnull(PBI.employeeindex,0) > 0 THEN E.EmployeeName
               WHEN isnull(PBI.userindex,0) > 0 THEN RU.Username
               ELSE NULL
           END AS ProcessByName,
           PBI.ProcessDate as ProcessDate
    FROM ProcessByIndex PBI
    LEFT JOIN RegisteredUsers RU
        ON PBI.userindex = RU.UserIndex 
    LEFT JOIN Employee E
        ON PBI.employeeindex = E.EmployeeIndex
    WHERE PBI.rn = 1
)
    -- Main query
SELECT 
        ROW_NUMBER() OVER (ORDER BY LD.EmployeeIndex) AS Sno, 
        LD.LeaveIndex,
        EE.employeeid,
        LD.EmployeeIndex,
        EE.EmployeeName,
        EE.TerritoryName,
		EE.Unitname,
		EE.Regionname,
		EE.LocationName,
		EE.DivisionName,
        EE.BUName,
        EE.DepartmentName,
        EE.SubDepartmentName,
        EE.PositionName,
        LC.LeaveDescription As 'Leave Type',
		FORMAT(LD.FromDate, 'yyyy-MM-dd | dddd') as 'From Date',
        FORMAT(LD.ToDate, 'yyyy-MM-dd | dddd') as 'To Date',
        LD.TotalDays,
        (case when LD.LeaveStatus = 1 then 'Pending Approval' 
			when LD.LeaveStatus in (2,3) then 'Approved' 
			when LD.LeaveStatus = 7 then 'Deducted' 
			when LD.LeaveStatus = 4 then 'Rejected' 
			when LD.LeaveStatus in (5,6) then 'Cancelled' Else '' End ) As 'Status', 
		LD.Reason,
		EEE.EmployeeiD as 'Applied By ID',
		EEE.Employeename as 'Applied By Name',
        LD.EntryDate AS 'Applied Date',
        PBN.ProcessByName AS 'ProcessedBy Name',
        PBN.ProcessDate As 'Processed Date'
FROM leavedetail LD
    INNER JOIN LeaveClientMapping LC ON LD.LeaveType = LC.LeaveType and LC.ClientIndex = @ClientIndex
    INNER JOIN vwempdetail EE ON LD.employeeindex = EE.employeeindex
	Left outer JOIN ProcessByNameget  PBN on LD.leaveindex = PBN.leaveindex
	INNER JOIN Employee EEE on LD.EntryBy = EEE.employeeindex
WHERE NOT (LD.leavetype = 9 AND LD.LeaveStatus = 12) AND EE.Clientindex = @ClientIndex AND LD.FromDate BETWEEN @FromDate AND @ToDate AND 
		LD.EmployeeIndex IN (SELECT EmployeeIndex FROM #emp)
    GROUP BY 
       	LD.LeaveIndex,EE.employeeid,LD.EmployeeIndex,EE.EmployeeName,EE.TerritoryName,EE.Unitname,
		EE.Regionname,EE.LocationName,EE.DivisionName,EE.BUName,EE.DepartmentName,EE.SubDepartmentName,
        EE.PositionName,LC.LeaveDescription,LD.FromDate,LD.todate,LD.TotalDays,LD.LeaveStatus,LD.Reason,
		EEE.EmployeeiD,EEE.Employeename,LD.EntryDate,PBN.ProcessByName,PBN.ProcessDate
END
