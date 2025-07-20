declare
@employeeindex int,
@clientindex int,
@oldLvgroup int,
@newlvgroup int,
@gender varchar
;
with TodayEmployee as (
select employeeindex,LvGroup,Gender from employee 
where ClientIndex = @clientindex and convert(date,servicestartdate) = DATEADD(year, -1, convert(date,GETDATE()))
)


select @employeeindex = employeeindex , @oldLvgroup = LvGroup , @gender = Gender from TodayEmployee
select @newlvgroup = case when @oldLvgroup = 555 then 452 when @oldLvgroup = 556 then 453 else 0 end

update Employee set lvgroup = @newlvgroup where EmployeeIndex = @employeeindex and lvgroup = @oldLvgroup