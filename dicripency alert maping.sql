WITH CurrentSno AS (
    SELECT ISNULL(MAX(sno), 0) AS maxsno 
    FROM aa_emaildetail 
    WHERE activityindex = 303
),
NewEmployees AS (
    SELECT 
        e.employeeindex,
        ROW_NUMBER() OVER (ORDER BY e.employeeindex) AS rn
    FROM employee e
	left outer join tm_AtExempt AE on e.employeeindex = AE.employeeindex
    WHERE 
        e.clientindex = 1361 
		AND AE.EmployeeIndex != e.EmployeeIndex
        AND e.TerritoryIndex = 25150 
        AND e.servicestatus = 1 
        AND ISNULL(e.email, '-') NOT IN ('-', '')
        AND e.employeeindex NOT IN (
            SELECT employeeindex FROM aa_emaildetail WHERE activityindex = 303
        )
)
--insert into aa_emaildetail (ActivityIndex,Sno,ClientIndex,EmployeeIndex)
SELECT 
    303 AS activityindex,
    b.maxsno + m.rn AS sno,
    1361 AS clientindex,
    m.employeeindex
FROM NewEmployees m
CROSS JOIN CurrentSno b;



