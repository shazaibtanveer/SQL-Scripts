	select @Allowance = sum((case 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 157 and ((ApOTHH*60)+ApOTMI) between 180 and 299 then 550 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 157 and ((ApOTHH*60)+ApOTMI) between 300 and 1000 then 1100  
	else 0 end )) from tm_Summary s , Rpt_Data_Employee e 
	where AtDate between [Fromdate] and [Todate]
	and s.EmployeeIndex = e.EmployeeIndex and s.EmployeeIndex = [EmpIndex]



	select @Allowance = sum((case 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 158 and ((OTHH*60)+OTMI) between 150 and 269 then 550 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 158 and ((OTHH*60)+OTMI) between 270 and 1000 then 1100  
	else 0 end )) from tm_Summary s , Rpt_Data_Employee e 
	where AtDate between [Fromdate] and [Todate]
	and s.EmployeeIndex = e.EmployeeIndex and s.EmployeeIndex = [EmpIndex]


select s.employeeindex , sum((case 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 157 and ((ApOTHH*60)+ApOTMI) between 180 and 299 then 550 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 157 and ((ApOTHH*60)+ApOTMI) between 300 and 1000 then 1100 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 158 and ((OTHH*60)+OTMI) between 150 and 269 then 550 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 158 and ((OTHH*60)+OTMI) between 270 and 1000 then 1100   
	else 0 end )) As Allowance  
from tm_Summary s 
where atdate between '2024-09-16' and '2024-10-15' and s.employeeindex in (select employeeindex from employee where clientindex  = 1141)
group by employeeindex


---- JSIL closing Report ----
select s.employeeindex , Sum(isabsent) As AbsentDays, sum((case 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 157 and ((ApOTHH*60)+ApOTMI) between 180 and 299 then 550 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 157 and ((ApOTHH*60)+ApOTMI) between 300 and 1000 then 1100 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 158 and ((OTHH*60)+OTMI) between 150 and 269 then 550 
	when S.IsHoliday = 0 and S.AdjRuleIndex = 158 and ((OTHH*60)+OTMI) between 270 and 1000 then 1100   
	else 0 end )) As Allowance ,
sum((case 
	when S.IsHoliday = 1 and S.AdjRuleIndex in (157,158) and ((WorkingHH*60)+WorkingMI) between 10 and 299 then 0.5
	when S.IsHoliday = 1 and S.AdjRuleIndex in (157,158)  and ((WorkingHH*60)+WorkingMI) between 300 and 1000 then 1
	 else 0 end )) As OffdayAllowance

from tm_Summary s 
where atdate between '2024-09-16' and '2024-10-15' and s.employeeindex in (select employeeindex from employee where clientindex  = 1141)
group by employeeindex

---- JSIL closing Report ----