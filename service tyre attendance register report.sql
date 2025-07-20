

Declare
@ClientIndex int = 1236,           
@FromDate date = '2025-05-01',            
@ToDate date = '2025-05-17',      
@UserEmpIndex int = 300136,          
@Str varchar(max) = '' 

		DECLARE @query VARCHAR(max) = ''
		DECLARE @Dt VARCHAR(max) = ''
		DECLARE @DtSelect VARCHAR(max) = ''
		select @Dt += ', ' + QUOTENAME(Format(FromDate,'MM/dd/yyyy')) from dbo.fnDateRangeBreakup('d',@FromDate, @ToDate,1)
		select @DtSelect += ', ISNULL(' + QUOTENAME(Format(FromDate,'MM/dd/yyyy')) + ','''') ' + QUOTENAME(Format(FromDate,'MM/dd/yyyy')) from dbo.fnDateRangeBreakup('d',@FromDate, @ToDate,1)
		if OBJECT_ID('tempdb.dbo.#AtData','U') is not null
			drop table #AtData
		if OBJECT_ID('tempdb.dbo.#AtCell','U') is not null
			drop table #AtCell
		if OBJECT_ID('tempdb.dbo.#AtSum','U') is not null
			drop table #AtSum
		select	
				Format(s.AtDate,'MM/dd/yyyy') AtDate,  
				s.EmployeeIndex,
				e.EmployeeId,
				e.EmployeeName, 
				e.Fathername,
				e.PositionName,
				e.DepartmentName,
				e.SubDepartmentName,
				e.EmploymentType,
				e.servicestatusdesc as servicestatus,
				Format(e.ServiceStartDate,'MM/dd/yyyy') as ServiceStartDate,
				Format(Isnull(e.serviceenddate,'01/01/1900'),'MM/dd/yyyy') as serviceenddate,
				isnull(s.IsAbsent,0) IsAbsent, 
				isnull(s.IsHoliday,0) IsHoliday,
				isnull(s.IsHoliday,0) isgazetted,
				isnull(s.IsLeave,0) IsLeave, 
				case when adjlc > 0 and adjlvbal = 0 then 1 else 0 end  IsLC,
				case when AdjEG > 0 and adjlvbal = 0 then 1 else 0 end  IsEG,
				Case When isnull(s.IsInvalid,0) = 1 and isnull(isleave,0) = 0 and isnull(IsHoliday,0) = 0 then 1 Else 0 End IsInvalid, 
				IsAttendance, 
				isnull(s.IsIrregular,0) IsIrregular,  
				isnull(s.LeaveType,0) LeaveType, 
				isnull(s.HolidayType,0) HolidayType,
				s.AdjLvBal, 
				Case When Isnull(s.AbsentPartial,0) > 0 and IsExempt = 0 then AbsentPartial Else 0 End Absentpartial, 
				case when isnull(s.LeaveTotalDays,0) > 1 then 1 else isnull(s.LeaveTotalDays,0) end as LeaveTotalDays, 
				isnull(s.IsExempt,0) IsExempt,
				(Case When leavetype IN (5,28,79,80,81) and leavestatus = 2 and leavetotaldays >= 1 then 1 When leavetype IN (5,28,79,80,81) and leavetotaldays<1 and leavestatus = 2 then leavetotaldays Else 0 End) TotalLWOP, 
				Case When IsGazetted = 1 and IsHoliday = 1 then 1 Else 0 End 'TotalGazetted', 
				Case When IsGazetted = 0 and IsHoliday = 1 then 1 Else 0 End 'TotalHoliday',
				case when AdjLvBal <= 0.5 then AdjLvBal else 0 end 'Half-Day ded',
				case when AdjLvBal >= 0.5 then AdjLvBal else 0 end 'Full-Day ded',
				Case When Isattendance = 1 and AdjLvBal != 1 and IsHoliday = 0 then 1 Else 0 End 'PresentOnWD',
				Case When Isattendance = 1 and AdjLvBal != 1 and IsHoliday = 1 then 1 Else 0 End 'PresentOnOD',
				Case When Isattendance = 1 and AdjLvBal != 1 and isleave = 1 and LeaveTotalDays >= 1 then 1 Else 0 End 'PresentOnLv',
				Case When s.leavestatus = 1 and leavetotaldays >= 1 and s.leavetype not in (20) then 1 When s.leavestatus = 1 and leavetotaldays < 1 then leavetotaldays Else 0 End 'UnApprovedLeaves',
				Case When s.leavestatus = 2 and leavetotaldays >= 1 and s.leavetype not in (20)then 1 When s.leavestatus = 2 and leavetotaldays < 1 then leavetotaldays Else 0 End  'ApprovedLeaves',
				CASE WHEN (s.isattendance = 1 or s.IsHoliday = 1) OR (s.isattendance = 1 and s.IsHoliday = 1) or (isleave = 1 and leavetype not in (5,28,79,80,81)) THEN 1 - Adjlvbal ELSE 0 End 'PaidDays'
				into #AtData 
		from	tm_Summary s
				inner join VwEmpDetail e on s.EmployeeIndex=e.EmployeeIndex
		where	s.ClientIndex=@ClientIndex 
				and s.AtDate between @FromDate and @ToDate 
				and e.EmployeeIndex in (select EmployeeIndex from employee where clientindex  =  @clientindex)

		
		select	EmployeeIndex, 
				DateDiff(dd,@FromDate,@ToDate)+1 TotalDays,
				sum(IsHoliday) Holidays,
				sum(IsAttendance) DayAttended,
				Sum(UnApprovedLeaves) UnApprovedLeaves,
				Sum(ApprovedLeaves) ApprovedLeaves,
				sum(IsAbsent) Absent,
				sum(AbsentPartial) AbsentPartial,
				sum(TotalGazetted) TotalGazetted,
				Sum(PresentOnWD) PresentOnWD,
				Sum(PresentOnOD) PresentOnOD,
				Sum(PresentOnLv) PresentOnLv,
				Sum(IsIrregular) TotalIrregular,
				sum(TotalLWOP) TotalLWOP,
				sum(IsLC) TotalLate,
				sum(IsEG) TotalEarly,
				sum(IsInvalid) TotalInvalid,
				sum(IsAbsent + TotalLWOP + Absentpartial) TotalDeduction,
				SUM(PaidDays) PaidDays
				into #AtSum
		from	#AtData
		group by EmployeeIndex

		select	
				Distinct d.EmployeeIndex as Employeeindex, 
				d.EmployeeId,
				d.EmployeeName, 
				d.Fathername,
				d.PositionName,
				d.DepartmentName,
				d.SubDepartmentName,
				d.EmploymentType,
				d.ServiceStartDate, 
				d.serviceenddate,
				d.servicestatus,
				d.AtDate,
				(case 
				when IsExempt=0 and IsAttendance = 1 and IsHoliday = 0 and leavetotaldays < 1 and d.islc = 0 and d.IsEG = 0 then 'PO'
				when IsExempt=0 and IsAttendance = 1 and IsHoliday = 0 and leavetotaldays < 1 and d.islc > 0 and d.IsEG = 0 then 'PL'
				when IsExempt=0 and IsAttendance = 1 and IsHoliday = 0 and leavetotaldays < 1 and d.islc = 0 and d.IsEG > 0 then 'PE'
				when IsExempt=0 and IsAttendance = 1 and IsHoliday = 1 and isgazetted = 0 then 'PH'
				when IsExempt=0 and IsAttendance = 1 and IsHoliday = 1 and isgazetted = 1 then 'PG'
				when IsExempt=0 and Isabsent = 1 then 'AB'
				When IsExempt=0 and isholiday = 1 and isattendance = 0 and isgazetted = 0 then 'OFF'
				When IsExempt=0 and isholiday = 1 and isattendance = 0 and isgazetted = 1 then 'GD'
				when isExempt=0 and IsAttendance = 1 and isholiday = 0 and adjlvbal = 0.25 then 'QD'
				when isExempt=0 and IsAttendance = 1 and isholiday = 0 and adjlvbal = 0.5 then 'HD'
				when isExempt=0 and IsAttendance = 1 and isholiday = 0 and adjlvbal = 1 then 'FD'
				When IsExempt=0 and isleave = 1 and leavetotaldays > 0.5 then lcm.leavecode
				when IsExempt = 1 then 'Exm' else '' end) As Cell,
				s.TotalDays,
				s.Holidays,
				s.DayAttended,
				s.ApprovedLeaves,
				s.AbsentPartial,
				s.TotalGazetted,
				s.PresentOnWD,
				s.PresentOnOD,
				s.PresentOnLv,
				s.TotalIrregular,
				s.TotalLate,
				s.TotalEarly,
				s.TotalInvalid,
				s.Absent,
				s.TotalLWOP,
				(s.TotalDays - s.TotalLWOP - s.Absent - s.AbsentPartial) PaidDays,
				S.PaidDays PaidDays2,
				s.TotalDeduction
				into #AtCell
		from	#AtData d
				inner join #AtSum s on d.EmployeeIndex=s.EmployeeIndex
				left outer join leaveclientmapping lcm on d.leavetype = lcm.leavetype and lcm.clientindex  = @clientindex 

--select @Dt, @DtSelect
		SET @query = '  
                    select	row_number() over (order by EmployeeID) SNo, 
							EmployeeIndex,
							EmployeeId,
							EmployeeName,
							Fathername,
							PositionName,
							DepartmentName,
							SubDepartmentName,
							EmploymentType,
							servicestatus,
							serviceenddate,
							Servicestartdate
                            '+ @DtSelect +' ,
							TotalDays,
							(Absent+AbsentPartial) as TotalAbsents,
							DayAttended,
							PresentOnWD,
							PresentOnOD,
							PresentOnLv,
							Holidays,
							TotalGazetted,
							TotalLate,
							TotalEarly,
							ApprovedLeaves,
							TotalLWOP,
							TotalInvalid,
							TotalIrregular,
							TotalDeduction,
							Case When paiddays < 0 then 0 Else paiddays End as PaidDays,
							PaidDays2
                    from #AtCell  
                        PIVOT  
                        (  
                            max(Cell)   
							FOR AtDate IN ('+ STUFF(@Dt, 1, 1,'') + ')  
                        ) AS p  
					order by EmployeeID
					'  
--        PRINT (@query);  
        exec (@query)  

--PO	Present On Time
--PL	Present Late
--PE	Present Early
--PH	Present on Holiday
--PG	Present on Gazzetted
--AB	Absent
--OFF	Off day
--GD    Gazzetted Holiday
--QD	0.25 Deduction
--HD	0.5 Deduction
--FD	Full Day deduction
--Leave Code	Leave




