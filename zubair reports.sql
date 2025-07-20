
--CREATE procedure [dbo].[Tm_at_Rpt_092] 



Declare
@ClientIndex int = 1341,           
@FromDate date = '2025-04-01',            
@ToDate date = '2025-04-23',      
@UserEmpIndex int = 300136,          
@Str varchar(max) = '' 


select		
ROW_NUMBER() over (order by s.EmployeeIndex asc) SNo,		
s.EmployeeIndex As 'Employee Index',
e.EmployeeId As 'Employee ID',
e.EmployeeName As 'Employee Name',
e.Fathername As 'Father Name',
e.positionname As 'Designation',
e.Departmentname As 'Department Name',
e.Subdepartmentname As 'SubDepartment Name',
e.EmploymentType As 'Employeement Type',
e.unitname As 'Unit Name',
FORMAT(s.AtDate, 'MM/dd/yyyy') AS 'Attendance Date',
isnull(CONVERT(VARCHAR(8), s.EmpIn, 108),'-') 'EmpIn',
isnull(CONVERT(VARCHAR(8), s.EmpOut, 108),'-') 'EmpOut',
r.RosterCode As 'Roster Code',
e.AtGroupName  As 'ATGroup Name'						
from tm_Summary s 
left outer join VwEmpDetail e on s.employeeindex  = e.employeeindex
left outer join tm_VWempShift sft  on s.employeeindex = sft.employeeindex and s.atdate = sft.dt
left outer join tm_roster r on sft.RosterIndex = r.RosterIndex
where
e.clientindex = @ClientIndex
and s.clientindex  = @clientindex
and ((s.Empin is null or s.empout is null or s.empIn = s.EmpOut))
and (s.IsAttendance=1 or ( s.IsHoliday=1 and (s.empin is not null or s.empout is not null)))
and s.atdate between @FromDate and @TODate
and	(e.servicestatus=1 or (e.servicestatus = 2 and e.serviceenddate between @FromDate and @ToDate))
and isnull(s.IsExempt,0)=0
order by  e.EmployeeIndex 






Declare
@ClientIndex int = 1341,           
@FromDate date = '2025-04-01',            
@ToDate date = '2025-04-23',      
@UserEmpIndex int = 300136,          
@Str varchar(max) = '' 

		DECLARE @query VARCHAR(max) = ''
		DECLARE @Dt VARCHAR(max) = ''
		DECLARE @DtSelect VARCHAR(max) = ''
		select @Dt += ', ' + QUOTENAME(dbo.fnformatdate(FromDate,'month dd, yyyy')) from dbo.fnDateRangeBreakup('d',@FromDate, @ToDate,1)
		select @DtSelect += ', ISNULL(' + QUOTENAME(dbo.fnformatdate(FromDate,'month dd, yyyy')) + ','''') ' + QUOTENAME(dbo.fnformatdate(FromDate,'month dd, yyyy')) from dbo.fnDateRangeBreakup('d',@FromDate, @ToDate,1)
		if OBJECT_ID('tempdb.dbo.#AtData','U') is not null
			drop table #AtData
		if OBJECT_ID('tempdb.dbo.#AtCell','U') is not null
			drop table #AtCell
		if OBJECT_ID('tempdb.dbo.#AtSum','U') is not null
			drop table #AtSum
		select	
				dbo.fnformatdate(s.AtDate,'month dd, yyyy') AtDate,  
				s.EmployeeIndex,
				e.EmployeeId,
				e.EmployeeName, 
				e.Fathername,
				e.PositionName,
				e.DepartmentName,
				e.SubDepartmentName,
				e.EmploymentType,
				e.ServiceStartDate,  
				isnull(s.IsAbsent,0) IsAbsent, 
				Case When isnull(s.IsHoliday,0) = 1 and Isgazetted = 0 then 1 else 0 End IsHoliday,
				isnull(s.IsLeave,0) IsLeave, 
				isnull(s.IsEC,0) IsEC, 
				isnull(s.IsEG,0) IsEG, 
				Case When datediff(Mi,Timein,empin) > 15 and Isholiday = 0 and Isleave = 0 then 1 Else 0 End ISLC, 
				Case When isnull(s.IsInvalid,0) = 1 and isleave = 0 and (IsHoliday = 0 OR ISGazetted = 0) then 1 Else 0 End IsInvalid, 
				Case When isnull(s.IsAttendance,0) =1 and IsInvalid = 0 and Isirregular = 0 then 1 Else 0 End IsAttendance, 
				isnull(s.IsIrregular,0) IsIrregular,  
				isnull(s.LeaveDesc,'') LeaveDesc, 
				isnull(s.HolidayDesc,'') HolidayDesc,
				isnull(dbo.fnFormatDate(s.EmpIn,'HH:MIN'),'Missing In') EmpIn, 
				isnull(dbo.fnFormatDate(s.EmpOut,'HH:MIN'),'Missing Out') EmpOut ,
				isnull(s.RosterIndex,0) RosterIndex, 
				s.TimeIn, 
				s.TimeOut, 
				s.LeaveStatus,
				s.LeaveType, 
				s.AdjLvBal, 
				Case When Isnull(s.AbsentPartial,0) > 0 and IsExempt = 0 then AbsentPartial Else 0 End Absentpartial, 
				s.LeaveTotalDays, 
				s.ApOvertime, 
				s.HolidayType, 
				isnull(s.IsExempt,0) IsExempt,
				(Case When leavetype = 5 and leavestatus = 2 and leavetotaldays >= 1 then 1 When leavetype = 5 and leavetotaldays<1 and leavestatus = 2 then leavetotaldays Else 0 End) TotalLWOP, 
				Case When Isnull(AdjlvBal,0) > 0 and (Isleave = 1 or Isleave = 0) Then Adjlvbal Else 0 End 'TardinessDeductions', 
				Case When IsGazetted = 1 and IsHoliday = 0 then 1 Else 0 End 'TotalGazetted', 
				Case When Isattendance = 1 and IsInvalid = 0 and IsIrregular = 0 then 1 Else 0 End 'PresentOnWD',
				Case When Isholiday = 1 and Isattendance = 1 and Isgazetted = 0 and Empin is not null and Empout is not null then 1 Else 0 End 'PresentOnOD',
				Case When Isholiday = 0 and Isattendance = 1 and Isgazetted = 1 and Empin is not null and Empout is not null then 1 Else 0 End 'PresentOnGD',
				Case When IsLeave = 1 and Isattendance = 1 and Empin is not null and Empout is not null then 1 Else 0 End 'PresentOnLv',
				Case When IsIrregular = 1 and TimeIn is null and Timeout is null and IsHoliday = 0 then 1 Else 0 End Irregular,
				Case When s.leavestatus = 1 and leavetotaldays >= 1 and s.leavetype not in (20) then 1 When s.leavestatus = 1 and leavetotaldays < 1 then leavetotaldays Else 0 End 'UnApprovedLeaves',
				Case When s.leavestatus = 2 and leavetotaldays >= 1 and s.leavetype not in (20)then 1 When s.leavestatus = 2 and leavetotaldays < 1 then leavetotaldays Else 0 End  'ApprovedLeaves'
				into #AtData 
		from	tm_Summary s
				inner join VwEmpDetail e on s.EmployeeIndex=e.EmployeeIndex
				--inner join Positions p on e.PositionCode = p.PositionCode
				--left outer Join LeaveDetail ld on s.EmployeeIndex = ld.EmployeeIndex and s.AtDate = ld.FromDate --and s.LeaveIndex = ld.LeaveIndex
		where	s.ClientIndex=@ClientIndex--1308 
				and s.AtDate between @FromDate and @ToDate 
				and e.EmployeeIndex in (select EmployeeIndex from #Emp)
				and (@StrRegion='' or e.RegionIndex in (select col1 from dbo.fnParseArray(@StrRegion,',')))
				and (@StrDepartment='' or e.DepartmentIndex in (select col1 from dbo.fnParseArray(@StrDepartment,',')))
				and (@StrLocation='' or e.LocationIndex in (select col1 from dbo.fnParseArray(@StrLocation,',')))
				and (@StrClientBranch='' or e.ClientBranchIndex in (select col1 from dbo.fnParseArray(@StrClientBranch,',')))
				and (@StrTerritory='' or e.TerritoryIndex in (select col1 from dbo.fnParseArray(@StrTerritory,',')))
				and (@StrUnit='' or e.UnitIndex in (select col1 from dbo.fnParseArray(@StrUnit,',')))
				and (@StrDivision='' or e.DivisionIndex in (select col1 from dbo.fnParseArray(@StrDivision,',')))
				and (@StrBU='' or e.BUIndex in (select col1 from dbo.fnParseArray(@StrBU,',')))
				and (@SvcStatus='' or ServiceStatus in (select col1 from dbo.fnParseArray(@SvcStatus,',')))
				and (@strsubDepartment='' or SubDepartmentIndex in (select col1 from dbo.fnParseArray(@strsubDepartment,',')))
		
		select	EmployeeIndex, 
				DateDiff(dd,@FromDate,@ToDate)+1 TotalDays,
				sum(IsHoliday) Holidays,
				sum(IsAttendance) Attended,
				Sum(UnApprovedLeaves) UnapprovedLeaves,
				Sum(ApprovedLeaves) ApprovedLeaves,
				sum(IsAbsent) Absent,
				sum(AbsentPartial)AbsentPartial,
				sum(TotalGazetted) TotalGazetted,
				Sum(PresentOnWD) PresentOnWD,
				Sum(PresentOnOD) PresentOnOD,
				Sum(PresentOnGD) PresentOnGD,
				Sum(PresentOnLv) PresentOnLv,
				Sum(Irregular) Irregular,
				sum(TotalLWOP) TotalLWOP,
				sum(TardinessDeductions) TardinessDeductions,
				sum(IsLC) Late,
				sum(IsInvalid) Invalid
				into #AtSum
		from	#AtData
		group by EmployeeIndex

		select	
				Distinct d.EmployeeIndex, 
				d.EmployeeName, 
				d.EmployeeId, 
				d.PositionName,
				d.DepartmentName,
				d.SubDepartmentName, 
				dbo.fnFormatDate(d.ServiceStartDate,'month dd, yyyy') DOJ, 
				d.AtDate,
				+ ( case when IsExempt=0 and IsAttendance=0 and IsHoliday=1 then '<font bgcolor=#AFAFAF>' + isnull(HolidayDesc,'') + '</font>' else '' end )
				+ ( case when IsExempt=0 and IsAttendance=0 and IsLeave=1 and LeaveStatus not in (1,4) then '<font bgcolor=green>' + isnull(LeaveDesc, '') + ' Approved' + '</font>'  else ''  end ) 
				+ ( case when IsExempt=0 and IsAttendance=0 and IsLeave=1 and LeaveStatus in (1,4) then '<font bgcolor=green>' + isnull(LeaveDesc, '') + ' UnApproved' + '</font>'  else ''  end ) 
				+ ( case when IsExempt=0 and IsAbsent=1 and s.AbsentPartial=0 then '<font bgcolor=orange>Absent</font>' else '' end ) 
				+ ( case when IsExempt=0 and s.AbsentPartial>0 then '<font bgcolor=#BAAA64>P.Absent</font>' else '' end ) 
				+ ( case when IsExempt=0 and IsAttendance=1 and RosterIndex=0 and IsHoliday=0 and IsLeave=0  then EmpIn + '<br>' + EmpOut + '<br><span style="color: Red; font-size:7px;">Missing Roster</span>' else '' end ) 
				+ ( case when IsExempt=0 and IsAttendance=1 and RosterIndex>0 and IsHoliday=0 and IsLeave=0  and IsLC=0 and IsEG=0 then  EmpIn + '<br>' + EmpOut  else '' end )
				+ ( case when IsExempt=0 and IsAttendance=1 and IsLC=0 and IsEG=1 then EmpIn + '<br>' + EmpOut + '<br><span style="color: Red; font-weight: normal;">Early</span>' else '' end )
				+ ( case when IsExempt=0 and IsAttendance=1 and datediff(Mi,Timein,empin) > 15 then EmpIn + '<br>' + EmpOut + '<br><span style="color: Red; font-weight: normal;">Late</span>' else '' end )
				+ ( case when IsExempt=0 and IsAttendance=1 and IsLC=1 and s.AbsentPartial=0 then '<font bgcolor=yellow>' + EmpIn + '<br>' + EmpOut + '</font>' else '' end )
				+ ( case when IsExempt=0 and IsAttendance=1 and IsLC=1 and s.AbsentPartial>0 then '<font bgcolor=#BAAA64>' + EmpIn + '<br>' + EmpOut + '</font>' else '' end )
				+ ( case when IsExempt=0 and IsAttendance=1 and IsHoliday=1 then '<font bgcolor=#AFAFAF>' + EmpIn + '<br>' + EmpOut + '<br>' + HolidayDesc + '</font>' else '' end )
				+ ( case when IsExempt=0 and IsInvalid=1 then EmpIn + '<br>' + EmpOut + '<br><span style="bgcolor: Red; font-size: 8px; font-weight: normal;">Invalid</span>' else '' end )
				+ ( case when IsExempt=0 and IsIrregular=1 then EmpIn + '<br>' + EmpOut + '<br><span style="bgcolor: Red; font-size: 8px; font-weight: normal;">Irregular</span>' else '' end )
				+ ( case when IsExempt=1 then 'Exempt' else '' end ) As Cell,
				s.TotalDays,
				s.Holidays,
				s.Attended,
				s.ApprovedLeaves,
				Case When Isnull(c.AbsentPartial,0) >0 then c.AbsentPartial Else s.AbsentPartial End AbsentPartial,
				s.TotalGazetted,
				s.PresentOnWD,
				s.PresentOnOD,
				s.PresentOnGD,
				s.PresentOnLv,
				s.Irregular,
				s.Late,
				s.Invalid,
				s.Absent,
				Case When Isnull(C.TotalLwop,0) > 0 then c.TotalLWOP Else s.TotalLWOP End TotalLWOP,
				Case When Isnull(C.TotalHalfDay,0) > 0 then C.TotalHalfDay
				When Isnull(C.TotalFullDay,0) > 0 then C.TotalFullDay
				Else S.TardinessDeductions End TardinessDeductions,
				Case When c. UnApprovedLeaves >= 0 then C.UnapprovedLeaves
				Else S.UnapprovedLeaves End	 UnapprovedLeaves,
				s.TotalDays-Case When c. UnApprovedLeaves >= 0 then C.UnapprovedLeaves
				Else S.UnapprovedLeaves End-s.TardinessDeductions-s.TotalLWOP-s.Absent-s.AbsentPartial PaidDays
				into #AtCell
		from	#AtData d
				inner join #AtSum s on d.EmployeeIndex=s.EmployeeIndex
				left outer join tm_AtClosing c on c.EmployeeIndex=s.EmployeeIndex  and fromdate = @fromdate

--select @Dt, @DtSelect
		SET @query = '  
                    select	row_number() over (order by EmployeeName) SNo, 
							EmployeeIndex,
							EmployeeName,
							EmployeeId,
							PositionName,
							DepartmentName,
							SubDepartmentName,
							DOJ
                            '+ @DtSelect +' ,
							TotalDays,
							Holidays,
							Attended,
							ApprovedLeaves,
							AbsentPartial,
							TotalGazetted,
							PresentOnWD,
							PresentOnOD,
							PresentOnGD,
							PresentOnLv,
							Irregular,
							Late,
							Invalid,
							Absent+AbsentPartial TotalAbsents,
							TotalLWOP,
							TardinessDeductions,
							UnapprovedLeaves,
							Case When paiddays < 0 then 0 Else paiddays End PaidDays
                    from #AtCell  
                        PIVOT  
                        (  
                            max(Cell)   
							FOR AtDate IN ('+ STUFF(@Dt, 1, 1,'') + ')  
                        ) AS p  
					order by EmployeeName
					'  
--        PRINT (@query);  
        exec (@query)  
	end
return

















