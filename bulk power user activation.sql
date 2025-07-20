CREATE Procedure acm_AddUserEmpBulk 
@clientindex int
as    
BEGIN 

;WITH NewUser AS (
    SELECT DISTINCT e.LMIndex AS EmployeeIndex 
    FROM Employee e 
    WHERE e.ClientIndex = @clientindex AND e.ServiceStatus = 1 
    AND e.LMIndex IS NOT NULL 
    AND e.LMIndex NOT IN (
        SELECT ru.EmployeeIndex 
        FROM RegisteredUsers ru 
        WHERE ru.ClientIndex = @clientindex AND ru.UserStatus = 1
    )
),
Base AS (
    SELECT 
        e.EmployeeIndex,
        e.LoginID,
        e.Email,
        e.EmployeeName,
        e.CellNo,
        e.Password,
        e.IsPassExpired,
        ROW_NUMBER() OVER (ORDER BY e.EmployeeIndex) AS rn
    FROM Employee e
    INNER JOIN NewUser nu ON e.EmployeeIndex = nu.EmployeeIndex
    WHERE e.Email IS NOT NULL
),
Maxuserindex AS (
    SELECT MAX(UserIndex) AS MaxUserIndex FROM RegisteredUsers
)
--INSERT INTO RegisteredUsers (UserIndex,ClientIndex,UserType,UserStatus,UserID,UserName,Email,Password,EmployeeIndex,ContactNo,IsPassExpired)
SELECT 
    m.MaxUserIndex + b.rn AS UserIndex,
    @clientindex AS ClientIndex,
    2 AS UserType,
    1 AS UserStatus,
    ISNULL(b.LoginID, b.Email) AS UserID,
    b.EmployeeName AS UserName,
    b.Email,
    b.Password,
    b.EmployeeIndex,
    b.CellNo AS ContactNo,
    b.IsPassExpired
FROM Base b
CROSS JOIN Maxuserindex m;
--insert into UserClients 
select userindex , clientindex  
from RegisteredUsers
where ClientIndex =  @clientindex and UserIndex not in (select UserIndex from UserClients where clientindex = @clientindex)

END