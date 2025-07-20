select @Allowance = isnull(sum(
case 
when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) > 540 then ROUND(720 + ROUND((AdjOT - 9.0) * 120, 2), 2)
when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) between 180 and 540 then 720
when isholiday = 0 and round((ApOTHH*60+ApOTMI)/60 , 2) >= 0.5 then round(AdjOT * 120 , 2)
when isleave = 1 and leavetype = 15 and leavestatus = 2 then 720

else 0 
end) ,0) 
from Tm_Summary s,Employee e where IsAttendance = 1 and e.BUindex = 153 
and s.EmployeeIndex = e.EmployeeIndex and s.EmployeeIndex = [EmpIndex] and s.atdate between [Fromdate] and [Todate]








update  tm_goodattendancerule set  AllowanceFormula = 'select @Allowance = isnull(sum(
case 
when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) > 540 then ROUND(720 + ROUND((AdjOT - 9.0) * 120, 2), 2)
when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) between 180 and 540 then 720
when isholiday = 0 and round((ApOTHH*60+ApOTMI)/60 , 2) >= 0.5 then round(AdjOT * 120 , 2)
when isleave = 1 and leavetype = 15 and leavestatus = 2 then 720
else 0 
end) ,0) 
from Tm_Summary s,Employee e where IsAttendance = 1 and e.BUindex = 153 
and s.EmployeeIndex = e.EmployeeIndex and s.EmployeeIndex = [EmpIndex] and s.atdate between [Fromdate] and [Todate]'  where GARIndex = 29 and AdjRuleIndex = 262

select * from tm_goodattendancerule where GARIndex = 29




select employeeindex , 
isnull(sum(case when isholiday = 0 and round((ApOTHH*60+ApOTMI)/60 , 2) >= 0.5 then (round(AdjOT * 120 , 2)) else 0 end) ,0) As AWA_WD,
isnull(sum(case when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) between 180 and 540 then 720 else 0 end) ,0) As AWA_OD_Single, 
isnull(sum(case when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) > 540 then ROUND(720 + ROUND((AdjOT - 9.0) * 120, 2), 2) else 0 end) ,0) As AWA_OD_Double,

 
 
 isnull(sum(
case 
when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) > 540 then ROUND((AdjOT - 9.0) * 120.0, 2)

else 0 
end) ,0) As Offdaydoubleonly,

isnull(sum(
case 

when isholiday = 1 and round((ApOTHH*60+ApOTMI) , 2) between 180 and 540 then 720


else 0 
end) ,0) As OffdaySingle,
isnull(sum(
case 

when isholiday = 0 and round((ApOTHH*60+ApOTMI)/60 , 2) >= 0.5 then (round(AdjOT * 120 , 2))

else 0 
end) ,0) As WorkDay


from Tm_Summary  where isot = 1 
and clientindex  = 1355 and atdate between '2024-11-01' and '2024-11-30'
group by employeeindex
