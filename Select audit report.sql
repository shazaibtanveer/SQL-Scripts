DECLARE @StartDate DATE = '2023-09-01', 
        @EndDate DATE = '2023-09-30';

DECLARE @columns NVARCHAR(MAX), @sql NVARCHAR(MAX);

-- Step 1: Generate dynamic column list for IN, OUT, WH, STATUS
WITH DateRange AS (
    SELECT @StartDate AS Atdate
    UNION ALL
    SELECT DATEADD(DAY, 1, Atdate)
    FROM DateRange
    WHERE DATEADD(DAY, 1, Atdate) <= @EndDate
)
SELECT @columns = STUFF((
    SELECT ', ' + QUOTENAME(CONVERT(VARCHAR(10), Atdate, 120) + '_Roster') +
           ', ' + QUOTENAME(CONVERT(VARCHAR(10), Atdate, 120) + '_IN') +
           ', ' + QUOTENAME(CONVERT(VARCHAR(10), Atdate, 120) + '_OUT') +
           ', ' + QUOTENAME(CONVERT(VARCHAR(10), Atdate, 120) + '_WH') +
           ', ' + QUOTENAME(CONVERT(VARCHAR(10), Atdate, 120) + '_STATUS') +
		   ', ' + QUOTENAME(CONVERT(VARCHAR(10), Atdate, 120) + '_ADDEDSTATUS') +
		   ', ' + QUOTENAME(CONVERT(VARCHAR(10), Atdate, 120) + '_FINALSTATUS')
    FROM DateRange
    FOR XML PATH(''), TYPE
).value('.', 'NVARCHAR(MAX)'), 1, 2, '');

-- Step 2: Construct the dynamic SQL query
SET @sql = '
WITH summary AS (
    SELECT 
		e.Employeeid ,
		s.Employeeindex ,
        e.Employeename ,
		e.PositionName ,
		e.Subdepartmentname,
		e.Departmentname,
		e.Grade,
        FORMAT(e.servicestartdate, ''dd-MMM-yyyy'') AS DOJ,
		case when e.ResignDate = ''1/1/1900'' then ''0'' else FORMAT(e.ResignDate, ''dd-MMM-yyyy'') end AS DOR,
		case when e.serviceenddate = ''1/1/1900'' then ''0'' else FORMAT(e.serviceenddate, ''dd-MMM-yyyy'') end AS DOL,  
        s.Atdate,
		R.rostercode as ''Roster'',
        CONVERT(VARCHAR(5), s.Empin, 108) AS InTime,
        CONVERT(VARCHAR(5), s.Empout, 108) AS OutTime,
        ISNULL(s.WorkingTime, ''-'') AS WorkingTime,
        CASE 
            When s.IsAttendance = 1 and IsHoliday = 0 and s.adjlvUW = 0 and s.isinvalid = 0 and s.isirregular = 0 and s.WorkingHH > 4  Then ''Present'' 
			WHEN s.isattendance = 1 and  s.adjlvUW between 0.1 and 0.49 THEN ''Short Time''
            WHEN s.isattendance = 1 and  s.adjlvUW = 0.5 THEN ''Half Day'' 
            WHEN s.isattendance = 0 AND s.isholiday = 0 AND s.isabsent = 1 THEN ''Absent''
			WHEN s.isholiday = 1 and s.IsGazetted = 0 THEN ''Rest Day''
			when s.isholiday = 1 and s.IsGazetted = 1 THEN ''Public Holiday''
			WHEN S.isattendance = 1 and isholiday = 0 AND s.WorkingHH < 4 THEN ''ABSENT''
			WHEN S.isattendance = 1 and s.isirregular = 1 and isholiday = 0  THEN ''ABSENT''
			WHEN S.isattendance = 1 and s.isinvalid = 1 and isholiday = 0  THEN ''IN/OUT Missing''
			WHEN s.isattendance = 0 AND s.IsLeave = 1 AND s.LeaveTotalDays > 0.5 THEN s.LeaveDesc
            ELSE ''-'' 
        END AS Status,
		Case
			WHEN s.IsLeave = 1 AND s.LeaveTotalDays = 0.25 THEN ''Short-'' + s.LeaveDesc
			WHEN s.IsLeave = 1 AND s.LeaveTotalDays = 0.5 THEN ''Half-'' + s.LeaveDesc
			WHEN S.isattendance = 1 and s.IsLeave = 1 AND s.LeaveTotalDays > 0.5 THEN s.LeaveDesc
			ELSE ''-''
		END AS ADDEDSTATUS,
		Case
			WHEN s.isattendance = 1 AND s.isholiday = 0 AND s.isleave = 0 AND s.AdjLvBal between 0.01 and 0.49 THEN ''Short Time''
			WHEN s.isattendance = 1 AND s.isholiday = 0 AND s.isleave = 0 AND s.AdjLvBal = 0.5 THEN ''Half Day''
			WHEN s.isattendance = 1 AND s.isholiday = 0 AND s.isleave = 0 AND s.AdjLvBal = 0 THEN ''Present''
			WHEN s.isattendance = 1 AND s.isholiday = 0 AND s.isleave = 1 AND s.leavetype not in (5,76,113) and s.LeaveTotalDays < 1 THEN ''Present''
			WHEN s.isattendance = 1 AND s.isholiday = 0 AND s.isleave = 1 AND s.leavetype in (5,76,113) and s.LeaveTotalDays = 0.5 THEN ''Half Day''
			WHEN s.isattendance = 1 AND s.isholiday = 0 AND s.isleave = 1 AND s.leavetype in (5,76,113) and s.LeaveTotalDays = 0.25 THEN ''Short Time''
			WHEN s.isattendance = 1 AND s.isholiday = 0 AND s.isleave = 1 AND s.leavetype in (5,76,113) and s.LeaveTotalDays > 0.5 THEN ''Leave Without Pay''
			WHEN s.isholiday = 0 And s.isleave = 1 and s.leavetype in (1,2,3) and s.LeaveTotalDays > 0.5 THEN ''Leave''
			WHEN s.isholiday = 0 And s.isleave = 1 and s.leavetype not in (1,2,3)and s.LeaveTotalDays > 0.5 THEN s.LeaveDesc
			WHEN s.isholiday = 1 and s.IsGazetted = 0 THEN ''Rest Day''
			when s.isholiday = 1 and s.IsGazetted = 1 THEN ''Public Holiday''
			WHEN S.isattendance = 1 and isholiday = 0 and isleave = 0 AND s.WorkingHH < 4 THEN ''ABSENT''
			WHEN S.isattendance = 1 and isinvalid = 1 and isleave = 0 THEN ''ABSENT''
			When S.isabsent = 1 and s.isleave = 0 and isholiday = 0 THEN ''ABSENT''
			ELSE ''-''
		END AS FINALSTATUS
    FROM tm_summary s
    INNER JOIN vwempdetail e ON s.employeeindex = e.employeeindex
	left outer join tm_roster R on isnull(s.rosterindex,0) = R.rosterindex
    WHERE e.clientindex = 1046
      AND Atdate BETWEEN @StartDate AND @EndDate
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY EmployeeIndex) AS Sno, 
	Employeeid as ''Employee ID'', 
	Employeeindex as ''Employee Index'', 
	Employeename as ''Employee Name'',
	PositionName as ''Designation'', 
	Subdepartmentname,
	Departmentname,
	Grade,
	DOJ, 
	DOR,
	DOL, 
	' + @columns + '
FROM (
    SELECT 
        Employeeid, Employeeindex, Employeename,PositionName, Subdepartmentname,Departmentname,Grade,DOJ, DOR , DOL, 
        CONVERT(VARCHAR(10), Atdate, 120) + ''_Roster'' AS ColumnName, Roster AS Value
    FROM summary
    UNION ALL
    SELECT 
        Employeeid, Employeeindex, Employeename,PositionName, Subdepartmentname,Departmentname,Grade,DOJ, DOR , DOL, 
        CONVERT(VARCHAR(10), Atdate, 120) + ''_IN'' AS ColumnName, InTime AS Value
    FROM summary
    UNION ALL
    SELECT 
        Employeeid, Employeeindex, Employeename,PositionName, Subdepartmentname,Departmentname,Grade,DOJ, DOR , DOL, 
        CONVERT(VARCHAR(10), Atdate, 120) + ''_OUT'' AS ColumnName, OutTime AS Value
    FROM summary
    UNION ALL
    SELECT 
        Employeeid, Employeeindex, Employeename,PositionName, Subdepartmentname,Departmentname,Grade,DOJ, DOR , DOL, 
        CONVERT(VARCHAR(10), Atdate, 120) + ''_WH'' AS ColumnName, WorkingTime AS Value
    FROM summary
    UNION ALL
    SELECT 
        Employeeid, Employeeindex, Employeename,PositionName, Subdepartmentname,Departmentname,Grade,DOJ, DOR , DOL, 
        CONVERT(VARCHAR(10), Atdate, 120) + ''_STATUS'' AS ColumnName, Status AS Value
    FROM summary
	UNION ALL
    SELECT 
        Employeeid, Employeeindex, Employeename,PositionName, Subdepartmentname,Departmentname,Grade,DOJ, DOR , DOL, 
        CONVERT(VARCHAR(10), Atdate, 120) + ''_ADDEDSTATUS'' AS ColumnName, ADDEDSTATUS AS Value
    FROM summary
	UNION ALL
    SELECT 
        Employeeid, Employeeindex, Employeename,PositionName, Subdepartmentname,Departmentname,Grade,DOJ, DOR , DOL, 
        CONVERT(VARCHAR(10), Atdate, 120) + ''_FINALSTATUS'' AS ColumnName, FINALSTATUS AS Value
    FROM summary
) AS SourceTable
PIVOT (
    MAX(Value) FOR ColumnName IN (' + @columns + ')
) AS PivotTable
;
';

-- Step 3: Execute the dynamic SQL
EXEC sp_executesql @sql, N'@StartDate DATE, @EndDate DATE', @StartDate, @EndDate;
