go
delete from rpt_MainFilters where ReportIndex = 1825;;
delete from rpt_main where ReportIndex = 1825;;

insert into screens values (13679,'Detailed Attendance Register Report',0,0,0,0,0,null,null,0,null);;
insert into rpt_main values (1825,'tm_Rpt_Qry_Ghraphical_02','Detailed Attendance Register Report',
'A Detailed Attendance Register same like Ghraphical register report','../TMS/CustomAttendanceReport.aspx?', null,1,53,136,13679,1,2,1,null);;

insert into rpt_MainFilters values (1825,1361,10,'From Date',1);;
insert into rpt_MainFilters values (1825,1361,12,'To Date',1.1);;
insert into rpt_MainFilters values (1825,1361,20,'Department',1.1);;
insert into rpt_MainFilters values (1825,1361,21,'Location',1.1);;
insert into rpt_MainFilters values (1825,1361,23,'Territory',1.1);;
insert into rpt_MainFilters values (1825,1361,24,'Unit',1.1);;
insert into rpt_MainFilters values (1825,1361,25,'Division',1.1);;
insert into rpt_MainFilters values (1825,1361,26,'SubDepartment',1.1);;
insert into rpt_MainFilters values (1825,1361,29,'Grade',1.1);;
insert into rpt_MainFilters values (1825,1361,31,'Team',1.1);;
insert into rpt_MainFilters values (1825,1361,33,'BusinessUnit',1.1);;
insert into rpt_MainFilters values (1825,1361,48,'ServiceStatus',1.1);;
insert into rpt_MainFilters values (1825,1361,49,'Employee',1.1);;

go




Create procedure [dbo].[tm_Rpt_Qry_Ghraphical_02]
    @ClientIndex INT,           
    @FromDate NVARCHAR(10),            
    @ToDate NVARCHAR(10),           
    @UserEmpIndex INT,          
    @Str VARCHAR(MAX) = ''
AS                                   
BEGIN
    -- Declare all variables
    DECLARE @Str2 VARCHAR(1000), @SvcStatus VARCHAR(500) = '', @EmpIndx VARCHAR(500) = '', 
            @StrRegion VARCHAR(500) = '', @StrDepartment VARCHAR(500) = '', 
            @StrLocation VARCHAR(500) = '', @StrClientBranch VARCHAR(500) = '', @strTeam varchar(500)='',
            @StrTerritory VARCHAR(500) = '', @StrUnit VARCHAR(500) = '', @strclientGrade varchar(500)='',
            @StrDivision VARCHAR(500) = '', @StrSubDepartment VARCHAR(500) = '',@StrBU VARCHAR(500) = '', 
            @StrART VARCHAR(500) = '', @StrInvNo VARCHAR(500) = '';

    DECLARE cur_LeavePeriod CURSOR FOR
        SELECT col1 FROM dbo.fnParseArray(@Str, '^');
    OPEN cur_LeavePeriod;
    FETCH NEXT FROM cur_LeavePeriod INTO @Str2;
    WHILE @@FETCH_STATUS = 0    
    BEGIN
        -- Use conditional parsing and set values directly based on prefixes
        IF CHARINDEX('WL1:', @Str2) > 0 SET @StrRegion = REPLACE(@Str2, 'WL1:', '');
        IF CHARINDEX('WL2:', @Str2) > 0 SET @StrDepartment = REPLACE(@Str2, 'WL2:', '');
        IF CHARINDEX('WL3:', @Str2) > 0 SET @StrLocation = REPLACE(@Str2, 'WL3:', '');
        IF CHARINDEX('WL4:', @Str2) > 0 SET @StrClientBranch = REPLACE(@Str2, 'WL4:', '');
        IF CHARINDEX('WL5:', @Str2) > 0 SET @StrTerritory = REPLACE(@Str2, 'WL5:', '');
        IF CHARINDEX('WL6:', @Str2) > 0 SET @StrInvNo = REPLACE(@Str2, 'WL6:', '');
        IF CHARINDEX('WL7:', @Str2) > 0 SET @StrUnit = REPLACE(@Str2, 'WL7:', '');
        IF CHARINDEX('WL8:', @Str2) > 0 SET @StrDivision = REPLACE(@Str2, 'WL8:', '');
		IF CHARINDEX('WL9:', @Str2) > 0 SET @StrSubdepartment = REPLACE(@Str2, 'WL9:', '');
		if charindex('WL15:', @Str2) > 0 set @strclientGrade = REPLACE(@Str2,'WL15:','');
		if charindex('WL18:', @Str2) > 0 set @strTeam = REPLACE(@Str2,'WL18:','');
        IF CHARINDEX('WL23:', @Str2) > 0 SET @StrBU = REPLACE(@Str2, 'WL23:', '');
        IF CHARINDEX('ART:', @Str2) > 0 SET @StrART = REPLACE(@Str2, 'ART:', '');
        IF CHARINDEX('EmpIndx:', @Str2) > 0 SET @EmpIndx = REPLACE(@Str2, 'EmpIndx:', '');
        IF CHARINDEX('SS:', @Str2) > 0 SET @SvcStatus = REPLACE(@Str2, 'SS:', '');
		
        FETCH NEXT FROM cur_LeavePeriod INTO @Str2;
    END;
    CLOSE cur_LeavePeriod;
    DEALLOCATE cur_LeavePeriod;

    -- Initialize the #Emp temp table
    IF OBJECT_ID('tempdb.dbo.#Emp', 'U') IS NOT NULL  
        DROP TABLE #Emp;

    CREATE TABLE #Emp (EmployeeIndex INT);

    SET @SvcStatus = ISNULL(NULLIF(LTRIM(RTRIM(@SvcStatus)), ''), '1');

    -- Populate the #Emp table based on conditions
    IF LTRIM(RTRIM(@EmpIndx)) <> ''
    BEGIN
        INSERT INTO #Emp (EmployeeIndex)
        SELECT employeeindex
        FROM employee
        WHERE employeeindex IN (SELECT col1 FROM dbo.fnParseArray(@EmpIndx, ','))
          AND (ServiceStatus IN (SELECT col1 FROM dbo.fnParseArray(@SvcStatus, ',')));
    END
    ELSE
    BEGIN
        INSERT INTO #Emp (EmployeeIndex)
        SELECT employeeindex
        FROM employee
        WHERE clientindex = @ClientIndex 
          AND employeeindex IN (SELECT EmployeeIndex FROM acm_VwEmpAuthority WHERE UserEmpIndex = @UserEmpIndex AND WLCat = 3)
          AND (ServiceStatus IN (SELECT col1 FROM dbo.fnParseArray(@SvcStatus, ',')))
          AND (@StrRegion = '' OR RegionIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrRegion, ',')))
          AND (@StrDepartment = '' OR DepartmentIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrDepartment, ',')))
          AND (@StrLocation = '' OR LocationIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrLocation, ',')))
          AND (@StrClientBranch = '' OR ClientBranchIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrClientBranch, ',')))
          AND (@StrTerritory = '' OR TerritoryIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrTerritory, ',')))
          AND (@StrUnit = '' OR UnitIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrUnit, ',')))
          AND (@StrDivision = '' OR DivisionIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrDivision, ',')))
		  AND (@StrSubdepartment = '' OR Subdepartmentindex IN (SELECT col1 FROM dbo.fnParseArray(@StrSubdepartment, ',')))
		  And (@strclientGrade  ='' or GradeIndex in(select col1 from dbo.fnParseArray(@strclientGrade,',')))
		  And (@strTeam  ='' or TeamIndex in(select col1 from dbo.fnParseArray(@strTeam,',')))
          AND (@StrBU = '' OR BUIndex IN (SELECT col1 FROM dbo.fnParseArray(@StrBU, ',')));
    END;
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
				(Case When leavetype IN (5,28,79,80,81) and leavestatus = 2 and leavetotaldays >= 1 then 1 When leavetype IN (5,28,79,80,81) and leavetotaldays<1 and leavestatus = 2 then leavetotaldays Else 0 End) TotalLWOP, 
				Case When Isnull(AdjlvBal,0) > 0 and (Isleave = 1 or Isleave = 0) Then Adjlvbal Else 0 End 'TardinessDeductions', 
				Case When IsGazetted = 1 and IsHoliday = 0 then 1 Else 0 End 'TotalGazetted', 
				Case When Isattendance = 1 and IsInvalid = 0 and IsIrregular = 0 then 1 Else 0 End 'PresentOnWD',
				Case When Isholiday = 1 and Isattendance = 1 and Isgazetted = 0 and Empin is not null and Empout is not null then 1 Else 0 End 'PresentOnOD',
				Case When Isholiday = 0 and Isattendance = 1 and Isgazetted = 1 and Empin is not null and Empout is not null then 1 Else 0 End 'PresentOnGD',
				Case When IsLeave = 1 and Isattendance = 1 and Empin is not null and Empout is not null then 1 Else 0 End 'PresentOnLv',
				Case When IsIrregular = 1 and TimeIn is null and Timeout is null and IsHoliday = 0 then 1 Else 0 End Irregular,
				Case When s.leavestatus = 1 and leavetotaldays >= 1 and s.leavetype not in (20) then 1 When s.leavestatus = 1 and leavetotaldays < 1 then leavetotaldays Else 0 End 'UnApprovedLeaves',
				Case When s.leavestatus = 2 and leavetotaldays >= 1 and s.leavetype not in (20)then 1 When s.leavestatus = 2 and leavetotaldays < 1 then leavetotaldays Else 0 End  'ApprovedLeaves',
				CASE WHEN (s.isattendance = 1 or s.IsHoliday = 1) OR (s.isattendance = 1 and s.IsHoliday = 1) or (isleave = 1 and leavetype not in (5,28,79,80,81)) THEN 1 - Adjlvbal ELSE 0 End 'PaidDays'
				into #AtData 
		from	tm_Summary s
				inner join VwEmpDetail e on s.EmployeeIndex=e.EmployeeIndex
				--left outer Join LeaveDetail ld on s.EmployeeIndex = ld.EmployeeIndex and s.AtDate = ld.FromDate --and s.LeaveIndex = ld.LeaveIndex
		where	s.ClientIndex=@ClientIndex
				and s.AtDate between @FromDate and @ToDate 
				and e.EmployeeIndex in (select EmployeeIndex from #Emp)

		
		select	EmployeeIndex, 
				DateDiff(dd,@FromDate,@ToDate)+1 TotalDays,
				sum(IsHoliday) Holidays,
				sum(IsAttendance) Attended,
				Sum(UnApprovedLeaves) UnApprovedLeaves,
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
				sum(IsInvalid) Invalid,
				sum(IsAbsent + TardinessDeductions + TotalLWOP + Absentpartial) TotalDeduction,
				SUM(PaidDays) PaidDays
				into #AtSum
		from	#AtData
		group by EmployeeIndex

		select	
				Distinct d.EmployeeIndex, 
				d.EmployeeId,
				d.EmployeeName, 
				d.Fathername,
				d.PositionName,
				d.DepartmentName,
				d.SubDepartmentName,
				d.EmploymentType,
				d.ServiceStartDate, 
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
				+ ( case when IsExempt=0 and IsAttendance=1 and IsLeave=1 and LeaveType in (55,110) and LeaveStatus in (1,2,3) then '<font bgcolor=#AFAFAF>' + EmpIn + '<br>' + EmpOut + '<br>' + isnull(LeaveDesc, '') + '</font>' else '' end )
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
					Else S.UnApprovedLeaves End	 UnapprovedLeaves,
				s.TotalDays - s.TardinessDeductions - s.TotalLWOP - s.Absent - s.AbsentPartial PaidDays,
				S.PaidDays PaidDays2,
				s.TotalDeduction
				into #AtCell
		from	#AtData d
				inner join #AtSum s on d.EmployeeIndex=s.EmployeeIndex
				left outer join tm_AtClosing c on c.EmployeeIndex=s.EmployeeIndex  and fromdate = @fromdate

--select @Dt, @DtSelect
		SET @query = '  
                    select	row_number() over (order by EmployeeName) SNo, 
							EmployeeIndex,
							EmployeeId,
							EmployeeName,
							Fathername,
							PositionName,
							DepartmentName,
							SubDepartmentName,
							EmploymentType,
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
							TotalDeduction,
							Case When paiddays < 0 then 0 Else paiddays End PaidDays,
							PaidDays2
                    from #AtCell  
                        PIVOT  
                        (  
                            max(Cell)   
							FOR AtDate IN ('+ STUFF(@Dt, 1, 1,'') + ')  
                        ) AS p  
					order by EmployeeName
					'  
-- PRINT (@query);  
        exec (@query)  

-- Clean up
    DROP TABLE #Emp;
END
