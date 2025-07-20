select
format(s.AtDate,'MMMM d, yyyy') as [Date],
format(s.AtDate,'dddd') as [Day],
format(s.timein,'HH:mm') +'-'+ format(s.timeout,'HH:mm') as [Shift Time],
format(s.empin,'HH:mm') as [Time IN],
format(s.empout,'HH:mm') as [Time OUT],
s.WorkingTime,
s.LateComming AS [Late Comming],
s.Overtime AS [Over Time],
s.holidaydesc + s.Remarks as [Remarks]
from tm_summary s inner join Employee e on s.employeeindex = e.employeeindex 
where s.EmployeeIndex = 215685 and s.atdate between '2025-06-01' and '2025-07-03'

select * from tm_summary where employeeindex =  397500 and atdate  = '2025-05-02'


