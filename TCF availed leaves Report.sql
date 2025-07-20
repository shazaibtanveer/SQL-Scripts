DECLARE 
    @columns NVARCHAR(MAX), 
    @sql NVARCHAR(MAX),
    @clientindex INT = 1231,
    @fromdate DATE = '2023-01-01',
    @todate DATE = '2024-12-31';

-- Step 1: Get the column headers dynamically
SET @columns = (
    SELECT STUFF((
        SELECT ', ' + QUOTENAME(leavedescription)
        FROM LeaveClientMapping
        WHERE clientindex = @clientindex
        ORDER BY LeaveType
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') -- Remove the leading comma
);

-- Step 2: Construct the dynamic SQL query
SET @sql = N'
;WITH leavename AS (
    SELECT leavetype, leavedescription 
    FROM LeaveClientMapping 
    WHERE clientindex = @clientindex
),
leave_details AS (
    SELECT e.employeeid, e.EmployeeIndex, e.employeename, e.Locationname, e.BUname, 
           e.Departmentname, e.subdepartmentname, e.divisionname, e.Territoryname, e.PositionName,
           ISNULL(COUNT(s.leavetype), 0) AS Availed_leaves,
           COALESCE(leavename.leavedescription, ''Unknown'') AS leavedescription
    FROM leavedetail s 
    RIGHT JOIN vwempdetail e ON s.employeeindex = e.employeeindex
    LEFT JOIN leavename ON (CASE WHEN s.totaldays = 0.5 THEN s.oLeaveType ELSE s.leavetype END) = leavename.leavetype
    WHERE e.clientindex = @clientindex AND s.Fromdate BETWEEN @fromdate AND @todate
    GROUP BY e.employeeid, e.EmployeeIndex, e.employeename, e.Locationname, e.BUname, 
             e.Departmentname, e.subdepartmentname, e.divisionname, e.Territoryname, e.PositionName, 
             leavename.leavedescription
)
SELECT 
    divisionname, Territoryname, BUname, Locationname, Departmentname, subdepartmentname, 
    PositionName, employeeid, EmployeeIndex, employeename, ' + @columns + '
FROM 
(
    SELECT * FROM leave_details
) AS SourceTable
PIVOT 
(
    SUM(Availed_leaves)
    FOR leavedescription IN (' + @columns + ')
) AS PivotTable
ORDER BY EmployeeIndex;';

-- Step 3: Execute the dynamic SQL
EXEC sp_executesql @sql, N'@clientindex INT, @fromdate DATE, @todate DATE', 
                    @clientindex = @clientindex, @fromdate = @fromdate, @todate = @todate;