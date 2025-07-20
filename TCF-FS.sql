
CREATE procedure [dbo].[Prl_FS_Notification_RecordUpdate] 
	@ClientIndex smallint ,
	@PayrollYear smallint ,
	@PayrollMonth tinyint ,
	@InvoiceNo smallint ,
	@InvoiceIndex int ,
	@UserIndex smallint ,
	@EmployeeIndex int,
	@Key varchar(20) = '',
	@FSIndex int=0
	
as
	--	exec Prl_FS_Notification_RecordUpdate  1163, 2023, 7, 2, 96660, 62, 267903, '', 39731

	begin
		----------------Add Muhib 7 Oct 2019----------------
			 declare @DecimalPlaces tinyint			
					set @DecimalPlaces=0
		----------------Add Muhib 7 Oct 2019----------------
	
		if @FSIndex>0
		begin
			select	@ClientIndex = ClientIndex,
					@PayrollYear = PayrollYear,
					@PayrollMonth = PayrollMonth,
					@InvoiceNo = InvoiceNo,
					@InvoiceIndex = InvoiceIndex ,
					@EmployeeIndex = EmployeeIndex
			from	fs_master 
			where	FSIndex=@FSIndex--20053--employeeindex=166372

		end

		--------------------------------------------------------------------------------
		-- Checking in setup for columns 55,56(Gratuity) and 175(LoanAdjustment)	  --
		-- Alter by Nabeel 26 April 2012--
		if not exists ( select * from ClientInvDetail where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=175 )
			begin
				raiserror('Column A175 Loan Adjustment is mandatory in FS Setup', 16, 1)
				return
			end
		
		
		---Checking for Advance 224 column Nabeel 29 Aug 2013 Start
		declare @ClientType tinyint
		set @ClientType=0
		
		select @ClientType=ClientType from ClientMaster where ClientIndex=@ClientIndex
		if @ClientType=2 --and @ClientIndex<>27
		begin
		
				--raiserror('Cannot process FS Now', 16, 1)
				--return
			
			--if @ClientIndex<>107 
			--begin
			if not exists ( select * from ClientInvDetail where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=224 and ColumnType=10)
				begin
					raiserror('Column A224 Advance Adjustment should be Module in FS Setup', 16, 1)
					return
				end
			--end


			if not exists ( select * from ClientInvDetail where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=175 and ColumnType=9)
				begin
					raiserror('Column A175 Loan Adjustment should be Deduction Module in FS Setup', 16, 1)
					return
				end
	
		end
		---Checking for Advance 224 column Nabeel 29 Aug 2013 End	
			
		
		if exists ( select COUNT(*) from ClientInvDetail where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode in (56,55) having COUNT(*) =2)
			begin
				raiserror('Only one column of A055 and A056 can be used in FS Setup', 16, 1)
				return
			end
		-- Alter by Nabeel 26 April 2012--
		-- Checking in setup for columns 55,56(Gratuity) and 175(LoanAdjustment)	  --
		--------------------------------------------------------------------------------

		---------------------------------------------------- 
		-- add final settlement if its not already exists --
--		declare @FSIndex int

		if exists ( select * from FS_Master where EmployeeIndex=@EmployeeIndex and FSStatus<>3 )
			select @FSIndex=FSIndex from FS_Master where EmployeeIndex=@EmployeeIndex and FSStatus<>3 
		else
			set @FSIndex=0
		
		-- Alter by Nabeel 22 July 2013--start
		--select @FSIndex=FSIndex from FS_Master where EmployeeIndex=@EmployeeIndex and FSStatus=3 and InvoiceIndex=@InvoiceIndex
		-- Alter by Nabeel 22 July 2013--end
		
		if @FSIndex=0
		begin
			exec Prl_fs_RecordAdd @PayrollYear, @PayrollMonth, @ClientIndex, @EmployeeIndex, @InvoiceNo, @UserIndex, @InvoiceIndex out, @FSIndex out
		end
		-- add final settlement if its not already exists --
		---------------------------------------------------- 
		

		declare @PayrollType tinyint
		declare @GSal  decimal(12,2), @BSal  decimal(12,2), @GR tinyint, @Mth int, @Dys int, @GC char(1)
		declare @d int, @y int, @m int
		declare @dAmount  decimal(12,2), @yAmount  decimal(12,2), @mAmount  decimal(12,2) 
		declare @GratuityAdjustment  decimal(12,2)
		declare @LoanAdjustment  decimal(12,2), @AdvanceAdjustment  decimal(12,2)
		declare @PFAmount  decimal(12,2)
		declare @PensionAmount  decimal(12,2)
		declare @ServicePeriod varchar(50)
		declare @ColumnType tinyint
		declare @Amount  decimal(12,2) --, float-- 
		declare @EncAmount varbinary(256)
		declare @lmMaxDays tinyint -- last month max days
		declare @LBSD tinyint -- last balance salary days 
		declare @SAD int -- salary Arrears days 
		declare @SAM int -- salary Arrears days 
		declare @KeyGUID UNIQUEIDENTIFIER; 
		DECLARE @SQLString nvarchar(2000)
		DECLARE @ParmDefinition nvarchar(500)
		DECLARE @DOJ date, @DOC date, @DOL date, @LPayrollDate date, @BasicSalary float
		Declare @CurrentGrossSalary float
		Declare @ActualJDays tinyint
		Declare @WorkingDays tinyint
		Declare @SPM smallint = 0  --Muhib ---28 Oct 2021
		declare @LWOP float, @Overtime float, @HolidayRest float
		Declare @LWOP_DuringNoticePeriod float
		Declare @MTD_FS tinyint		--Muhib 16 June 2022
		Declare @NoticeDeductionDays float --Muhib 16 June 2022
		Declare @NoticeEndDate Date --Muhib 16 June 2022
		Declare @NoticeDeductionDaysAfterLeaving float --Muhib 16 June 2022
		Declare @EmpHolidayGroup tinyint = 0  --Muhib 21 June 2022
		Declare @WorkDays float = 0
		Declare @isPFGroup tinyint --11 Dec 2022 Murtaza 
		Declare @EmpAgeInNumber float
		Declare @EmpServicePeriodInNumber float
		declare @EmpServiceYear float
		Declare @isPFMember tinyint = 0
		Declare @TerritoryIndex smallint
		Declare @EmploymentType tinyint = 0

		select	@PayrollType=PayrollType
		from	ClientMaster
		where	ClientIndex=@ClientIndex 


		if @PayrollType=2 
		begin
			exec prl_OpenKey 126 , 'CPPL'
			--exec prl_OpenKey @ClientIndex , @Key
			SET @KeyGUID = KEY_GUID('EncPayrollKey')
		end


		------------------------------------------------------------
		-------------- Gratuity Year, Month and Days ---------------
		---------- Muhib -------------------- 15 May 2024 ----------
		begin

		Declare @GYear smallint = 0
		Declare @GMonth tinyint= 0
		Declare @GDays tinyint= 0

			select	@GYear = ISNULL(yyyy,0), 
					@GMonth = ISNULL(mm,0), 
					@GDays = ISNULL(dd,0)
			
				from fnServicePeriod(@EmployeeIndex)

		end
		---------- Muhib -------------------- 15 May 2024 ----------
		-------------- Gratuity Year, Month and Days ---------------
		------------------------------------------------------------

		-------------------------------------------------------------
		---- get balance days for last service month unpaid salary --
		--select	@LBSD = (case when isnull(ipm.IndividualPayrollStatus,0) = 2 then 0 else DAY(e.ServiceEndDate) end)
		--from	Employee e left outer join IndividualPayrollMaster ipm 
		--		on e.EmployeeIndex=ipm.EmployeeIndex
		--		and MONTH(dateadd(m,0,e.serviceenddate))=ipm.PayrollMonth 
		--		and YEAR(dateadd(m,0,e.serviceenddate))=ipm.PayrollYear 
		--where	e.EmployeeIndex=@EmployeeIndex
		---- get balance days for last service month unpaid salary --
		-------------------------------------------------------------


		-----------------------------------------------------------
		-- get salary arrears days since last posted payroll     --
		declare @UnpaidDate date, @IPMIndex bigint=0, @IPMInvoiceNo smallint, @FSMonth date, @FSProcMonth date, @MonthlySalary float=0
		Declare @LWOP_Unpaid float = 0
		declare @GSBGroupID smallint
		declare	@CurrentSalary float,
				@jDay As tinyint,
				@jMonth As smallint,
				@jYear As smallint,
				@lDay As tinyint,
				@lMonth As smallint,
				@lYear As smallint,
				@mMaxDays As smallint,
				@mMaxJDays As smallint,
				@MaxDaysOverRide As smallint,
				@IgnoreJLAdj as tinyint,
				@CurrencyIndex tinyint,
				@j_Days smallint, 
				@l_Days smallint,
				@a_Days smallint, 
				@a_Months smallint, 
				@sa_Days smallint, 
				@sa_Months smallint, 
				@sr_Days smallint, 
				@Gender char(1), 
				@AgeInDays int,
				@ModulePayMonth As int, 
				@ModulePayAmount As float, 
				@ModulePayEveryMonth As int,
				@JoiningAdjustment As float,
				@LeavingAdjustment As float,
				@PostResignPayrollDate date,
				@ServiceStatus tinyint,
				@ServiceStartMonth date,
				@GradeIndex tinyint,
				@sDate as datetime,
				@pDate as datetime,
				@eDate as datetime,
				@ProvinceIndex tinyint,
				@FixAmountArrears float,
				@TaxEndDate datetime,
				@TaxEndDateAdjMonth tinyint,
				@ServiceEndDate datetime,
				@PFEmployer float,
				@TotalUnpaidDays int, --murtaza-30-Oct-19
				@ResignDAte Date

		--declare @DecimalPlaces tinyint = 0

		set @SAD=0
		set @SAM=0

		

		select	@DOJ = servicestartdate,
				@DOC = isnull(sconfirmationdate,'1/1/1900'),
				@DOL = isnull(serviceenddate,'1/1/1900'),
				@ResignDAte =  isnull(ResignDate,'1/1/1900'),
				@BasicSalary = isnull(BasicSalary,0),
				--@MonthlySalary = isnull(MonthlySalary,CurrentGrossSalary)
				@CurrentGrossSalary = ISNULL(CurrentGrossSalary,0),
				@GSBGroupID = ISNULL(GsbGroupId,0),
				@jDay= day(ServiceStartDate), 
				@jMonth= month(ServiceStartDate), 
				@jYear= year(ServiceStartDate), 
				@lDay= day(ServiceEndDate), 
				@lMonth= month(ServiceEndDate), 
				@lYear= year(ServiceEndDate), 
				@Gender= isnull(Gender,'-'), 
				@AgeInDays= datediff(dd, isnull(DateOfBirth,getdate()),getdate()),
				@PostResignPayrollDate=isnull(PostResignPayrollDate,'1/1/1900'), 
				@ServiceStatus=ServiceStatus
				,@ProvinceIndex=isnull(c.provinceindex,0)
				,@TaxEndDate = ISNULL(e.TaxEndDate,'1/1/1900')
				,@ServiceEndDate = ISNULL(e.ServiceEndDate,'1/1/1900')  
				,@GradeIndex = isnull(e.GradeIndex,0)
				,@CurrencyIndex = isnull(CurrencyIndex,0)
				,@mMaxDays = day(dateadd(dd,-1,dateadd(mm,1,LTRIM(str(month(serviceenddate))) + '/1/' + LTRIM(str(year(serviceenddate))))))
				, @EmpHolidayGroup = ISNULL(HolidayGroup,0)
				, @GradeIndex = isnull(e.GradeIndex,0)
				, @EmpServicePeriodInNumber = dbo.fnEmployeeServicePeriodInNumber(@EmployeeIndex) --isnull(CAST(CAST((datediff(month,(case when isnull(e.ServiceStartDate,'1/1/1900')='1/1/1900' then getdate() else e.ServiceStartDate end) ,(case when isnull(e.ServiceEndDate,'1/1/1900')='1/1/1900' then getdate() else e.ServiceEndDate end)) + 1)/12.0 AS DECIMAL(18,2))AS nvarchar(10)),'0')
				, @EmpServiceYear = Round(datediff(MM, e.ServiceStartDate, e.ServiceEndDate)/12,0)
				, @EmpAgeInNumber = isnull(CAST(CAST(datediff(month, e.DateOfBirth, GETDATE()) /12.0 AS DECIMAL(18,2))AS nvarchar(10)),'0')
				, @TerritoryIndex = isnull(e.TerritoryIndex,0)
				, @EmploymentType = e.PositionCategory
		from	employee e,City c 
		 where	isnull(e.cityindex,0) = c.cityindex 
			and EmployeeIndex=@EmployeeIndex

		select @MonthlySalary = SUM(f.FixAmount) from EmpDetailFixAmount f, ClientGSColumns c where c.ClientIndex = @ClientIndex and c.ColumnCode = f.ColumnCode and c.GSBGroupID = @GSBGroupID and f.EmployeeIndex = @EmployeeIndex and (IsNull(f.EndDate, @ServiceEndDate) >= @ServiceEndDate)


		set @FSMonth = ltrim(str(month(@DOL))) + '/1/' + ltrim(str(year(@DOL)))
		set @FSProcMonth = ltrim(str(@PayrollMonth)) + '/1/' + ltrim(str(@PayrollYear)) -- 08 Dec 2020

		Declare @FixAmountEndedBeforeSED float = 0
		select @FixAmountEndedBeforeSED = SUM(dbo.fnGetFixAmountEndDate(f.FixAmount,@FSMonth,f.EndDate)) from EmpDetailFixAmount f, ClientGSColumns c where c.ClientIndex = @ClientIndex and c.ColumnCode = f.ColumnCode and c.GSBGroupID = @GSBGroupID and f.EmployeeIndex = @EmployeeIndex and f.EndDate >= @FSMonth and f.EndDate < @ServiceEndDate

		SELECT @MTD_FS = DAY(EOMONTH(@FSProcMonth))	--Muhib 16 June 2022

		--SELECT DATEDIFF(m, '10/25/2020', '10/1/2021')
		

		--////////////////////////////////////////////
		--/// Geting Max Days As Per Invoice Setup ///
		----------- Muhib JUly 28 2021 ---------------
		set @MaxDaysOverRide=0
		select	@MaxDaysOverRide = isnull(ci.maxdays,0)

		from	clientinv ci, FS_Master fs
		where	fs.FSIndex = @FSIndex
			and isnull(ci.invoicetype,0) in (4) 
			and fs.clientindex=ci.clientindex 
			and fs.invoiceno=ci.invoiceno 
	
		if exists (select * from ClientInvOverRideMaxDaysByGS where ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo and  @CurrentGrossSalary between GSLimitFrom and GSLimitTo)
			begin
				select @MaxDaysOverRide = MaxDays from ClientInvOverRideMaxDaysByGS where ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo and  @CurrentGrossSalary between GSLimitFrom and GSLimitTo
			end
		
		if exists (
					select t.MaxDays 
						from 
						(
							select	ewl.EmployeeIndex,
									pf.ClientIndex,
									pf.InvoiceNo,
									pf.MaxDays,
									Count(*) WLCount

							from VwEmpWL ewl 
									inner join ClientInvMaxDays pf on pf.ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo
									inner join ClientInvMaxDaysWL pfwl on ewl.WorkLocation = pfwl.workLocation and ewl.WorkLocationIndex = pfwl.WorkLocationIndex and pf.ClientIndex = pfwl.ClientIndex and pf.InvoiceNo = pfwl.InvoiceNo
											   
							where ewl. EmployeeIndex in (@EmployeeIndex)

							group by ewl.EmployeeIndex, pf.ClientIndex, pf.InvoiceNo, pf.MaxDays
						) t,
						(select ClientIndex, InvoiceNo, ISNULL(Count(DISTINCT WorkLocationIndex),0) WLCount From ClientInvMaxDaysWL group by ClientIndex, InvoiceNo) wl

						where t.ClientIndex = wl.ClientIndex
							and t.InvoiceNo = wl.InvoiceNo
							and t.WLCount = wl.WLCount
					)
				begin
					select @MaxDaysOverRide = t.MaxDays 
						from 
						(
							select	ewl.EmployeeIndex,
									pf.ClientIndex,
									pf.InvoiceNo,
									pf.MaxDays,
									Count(*) WLCount

							from VwEmpWL ewl 
									inner join ClientInvMaxDays pf on pf.ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo
									inner join ClientInvMaxDaysWL pfwl on ewl.WorkLocation = pfwl.workLocation and ewl.WorkLocationIndex = pfwl.WorkLocationIndex and pf.ClientIndex = pfwl.ClientIndex and pf.InvoiceNo = pfwl.InvoiceNo
											   
							where ewl. EmployeeIndex in (@EmployeeIndex)

							group by ewl.EmployeeIndex, pf.ClientIndex, pf.InvoiceNo, pf.MaxDays
						) t,
						(select ClientIndex, InvoiceNo, ISNULL(Count(DISTINCT WorkLocationIndex),0) WLCount From ClientInvMaxDaysWL group by ClientIndex, InvoiceNo) wl

						where t.ClientIndex = wl.ClientIndex
							and t.InvoiceNo = wl.InvoiceNo
							and t.WLCount = wl.WLCount
				end


		if @MaxDaysOverRide>0
		begin
			set @ActualJDays = @mMaxJDays 
			set @mMaxJDays=@MaxDaysOverRide
			
			if @mMaxDays > @MaxDaysOverRide 
				set @mMaxDays=@MaxDaysOverRide

			set @MaxDaysOverRide=1  
		end
		----------- Muhib JUly 28 2021 ---------------
		--/// Geting Max Days As Per Invoice Setup ///
		--////////////////////////////////////////////


		---------------------------------------------
		------- is PF Member ------------------------
		if exists (select * from bn_RetirementBenefitMemberShip where RBType = 1 and EmployeeIndex = @EmployeeIndex and ISNULL(StartDAte,'1/1/1900') > '1/1/1900')
			set @isPFMember = 1

		------- is PF Member ------------------------
		---------------------------------------------
		
--		select * from fs_master where employeeindex=166081
 ----------------------------------------------------------------------------
		  ---------------- Working Day - 92 for only Modules ------------------------
		  --------------------- Muhib --- 27 May 2022 --------------------------------
		  begin
			set @ColumnType = 0
			select @ColumnType = ColumnType from ClientInvDetail where ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo and ColumnType in (10) and ColumnCode = 92

			If @ColumnType = 10
				begin
					delete from FS_Detail  where FSIndex = @FSIndex and ColumnCode = 92
					delete from FS_DetailOther where FSIndex = @FSIndex and ColumnCode = 92

					insert into FS_Detail (FSIndex,ColumnCode,Amount,EncAmount,ColumnType,IncomeTaxApply)
							values (@FSIndex, 92, @mMaxDays, null, 10, 0)

					insert into FS_DetailOther(FSIndex,ColumnCode,Amount,encamount,ColumnType,IncomeTaxApply,OAmount,Remarks)
							values (@FSIndex, 92, @mMaxDays, null, 10, 0,null,null)

				end
		  end
		  --------------------- Muhib --- 27 May 2022 --------------------------------
		  ---------------- Working Day - 92 for only Modules ------------------------
		  ----------------------------------------------------------------------------
		 


		select	@UnpaidDate=dateadd(mm,1,ltrim(str(payrollmonth))+'/1/'+ltrim(str(payrollyear))  ),
				@LPayrollDate=ltrim(str(payrollmonth))+'/1/'+ltrim(str(payrollyear))  ,
				@IPMIndex = ipm.IndividualPayrollIndex,
				@IPMInvoiceNo = ipm.InvoiceNo
		from	IndividualPayrollMaster ipm, 
				(
					select MAX(IndividualPayrollIndex) mipmindex 
					from IndividualPayrollMaster
					where IndividualPayrollStatus=2 and employeeindex = @EmployeeIndex
					group by EmployeeIndex
				) mipm 
		where	ipm.IndividualPayrollIndex=mipm.mipmindex
				and ipm.employeeindex=@EmployeeIndex--164401

		 
				---------------------------------- 
				----- umair/muhib 12/feb/2025  ---
				----select * from tm_periodcategory
				declare @tm_UnpaidDate date = @UnpaidDate

				select @tm_UnpaidDate = dateadd(dd,1,ToDate )
				from tm_Period p
				inner join tm_PeriodGroup pg on p.PeriodGroup=pg.PeriodGroup and pg.clientindex=@ClientIndex
				inner join tm_PeriodGroupWL pwl on p.PeriodGroup=pwl.PeriodGroup
				inner join VwEmpWL ewl  on pwl.WorkLocationIndex=ewl.WorkLocationIndex and pwl.WorkLocation=ewl.WorkLocation
				where pg.PeriodCat = 4
				and ewl.EmployeeIndex=@EmployeeIndex
				and p.PayrollMonth=month(@LPayrollDate)
				and p.PayrollYear=year(@LPayrollDate)
				--and p.periodindex = 9501
				if @@RowCount=0
				begin
				select @tm_UnpaidDate = dateadd(dd,1,ToDate )
				from tm_Period p
				inner join tm_PeriodGroup pg on p.PeriodGroup=pg.PeriodGroup and pg.clientindex=@ClientIndex
				where pg.PeriodCat = 4
				and p.PayrollMonth=month(@LPayrollDate)
				and p.PayrollYear=year(@LPayrollDate)
				--and p.periodindex = 9501
				end

				--- umair/muhib 12/feb/2025  ---
		
		
			if @LPayrollDate is null
				set @LPayrollDate = @FSMonth
		
			exec tm_Summary_Refresh @ClientIndex,@UnpaidDate,@DOL,@Employeeindex,0,0,0,0,0,0,0,0,1

			if @UnpaidDate is null and @ClientINdex = 1209
				set @UnpaidDate = @FSMonth

			if @UnpaidDate is null
				set @UnpaidDate = @DOJ
		
			select  @SAD = dd,
					@SAM = mm 
		
			from fnDateDiff(ISNULL(@UnpaidDate,@DOJ),@DOL)

		if @UnpaidDate > @DOL and @ClientIndex = 1090	--add by Muhib 21 June 2022
			begin
				set @SAD = 0
				set @SAM = 0
			end

		set @TotalUnpaidDays = DateDiff(dd,ISNULL(@UnpaidDate,@DOJ),@DOL)+1	--murtaza-30-Oct-19
		--set @SAM = datediff(mm,ISNULL(@UnpaidDate,@DOJ),@DOL)

		if @SAM<0
			begin
			set @SAM=@SAM+1
				set @SAD = datediff(dd,dateadd(mm, @SAM, ISNULL(@UnpaidDate,@DOJ)), @DOL)+1
				--select  @SAD = dd,
				--@SAM = mm 
				
				--	from fnDateDiff(ISNULL(@SAM),@DOL)
				set @TotalUnpaidDays = @SAD	--murtaza-30-Oct-19
			end

		------------------------------------------------------------------------------------
		----------------- link with attendance -------Muhib 17 Feb 2022 --------------------
		-- if employee resign in processed payroll month then LWOP check with Attendance ---
		
		--if @ClientIndex = 1090 and EOMONTH(@LPayrollDate) > @DOL-- testing muhib
		--begin
		--	select	@LWOP_Unpaid = ISNULL(Absent,0) + ISNULL(AbsentPartial,0) + ISNULL(Adjlvbal,0) + ISNULL(LWOP1,0) + ISNULL(LWOP2,0) + ISNULL(HolidayRest,0)
		--			from  (
		--					select sum(case when s.IsAbsent = 1 then 1 else 0 end ) Absent, 
		--							sum(case when isnull(s.AbsentPartial,0) > 0 and isnull(s.AbsentPartial,0) < 1 then s.AbsentPartial else 0 end ) AbsentPartial,
		--							sum(case 
		--									when isnull(s.adjlvbal,0) > 0 and isnull(s.adjlvbal,0) < 1 then s.adjlvbal 
		--									when isnull(s.adjlvbal,0) = 1 then 1
		--									else 0 end ) Adjlvbal,

		--							sum(case 
		--									when s.isleave = 1 and ISNULL(leavetotaldays,0) < 1 and  ISNULL(leavetype,0) in (5,28,79,80,81,76) then leavetotaldays 
		--									when s.isleave = 1 and ISNULL(leavetotaldays,0) >= 1 and ISNULL(leavetype,0) in (5,28,79,80,81,76) then 1 
		--									else 0 
		--									end 
		--								) LWOP1,
		--							sum(case 
		--									when s.isleave = 1 and ISNULL(leavetotaldays2,0) < 1 and  ISNULL(leavetype2,0) in (5,28,79,80,81,76) then leavetotaldays2 
		--									when s.isleave = 1 and ISNULL(leavetotaldays2,0) >= 1 and ISNULL(leavetype2,0) in (5,28,79,80,81,76) then 1 
		--									else 0 
		--									end 
		--								) LWOP2,
							
		--							sum(case when s.isHoliday = 1  and  s.isgazetted = 0 and @MaxDaysOverRide = 1 then 1 else 0 end ) HolidayRest	--and  s.isgazetted = 0

		--						from tm_summary s
		--					where s.employeeindex = @EmployeeIndex  
		--					and s.atdate  between DateAdd(day,1,@DOL) and EOMOnth(@DOL)	--DateAdd(day,1,@DOL)

		--					group by s.EmployeeIndex
		--			) t

		
				

		--		if @LWOP_Unpaid  <> 0 
		--			begin
		--				set @TotalUnpaidDays = @TotalUnpaidDays + @LWOP_Unpaid 
		--				set @SAD = @SAD + @LWOP_Unpaid 
		--			end
			 
		--		--if @UserIndex = 1124
		--		--	begin
		--		--	--	exec Prl_FS_Notification_RecordUpdate 1090, 2022, 2 , 6, 87308, 1124, 225021, '', 32240
		--		--	-- select * From fs_master where employeeindex = 225021
		--		--		select @LWOP_Unpaid LWOP_Unpaid, @TotalUnpaidDays TotalUnpaidDays, @SAD SAD, @DOL DOL 
		--		--	end
		
					
		--end
		-- if employee resign in processed payroll month then LWOP check with Attendance ---
		----------------- link with attendance -------Muhib 17 Feb 2022 --------------------
		------------------------------------------------------------------------------------

		--if @SAD<0
		--	set @SAD=0

		update	FS_Master
		set		UnpaidMonths = @SAM,
				UnpaidDays = @SAD,
				LastPayrollMonth = ISNULL(@LPayrollDate,'1/1/1900')
		where	FSIndex = @FSIndex

		set @l_Days = @SAD --Murtaza 3 Dec 2020

		if @FSProcMonth>@FSMonth		--16 Dec 2020
			Begin
				if @FSMonth >= @UnpaidDate
					set @FSProcMonth = @FSMonth
			End
		--murtaza-30-Oct-19
		--declare @TotalUnpaidDays int = 0
		--set @TotalUnpaidDays = DateDiff(dd,ISNULL(@UnpaidDate,@DOJ),@DOL)+1
		if exists (select ColumnCode from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=69 and ColumnType = 10)
		begin
			delete from FS_Detail where FSIndex = @FSIndex and columncode = 69

			insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
			values (@FSIndex, 69,@TotalUnpaidDays , null, 10, 0 ) 
		end

--		select datediff(mm,'2/1/2018','1/26/2018'), datediff(dd,dateadd(mm, -1, '2/1/2018'), '1/26/2018')+1

			--select	@SAD=isnull	
		--			(
		--				DATEDIFF(day,dateadd(day,-1,dateadd(m,1,convert(date,str(ipm.PayrollMonth)+'/1/'+str(ipm.PayrollYear)))),e.serviceenddate)
		--				, 
		--				DATEDIFF(dd,e.ServiceStartDate,e.ServiceEndDate)
		--			) 
		--from 
		--	Employee e 
		--	left outer join 
		--	(
		--		select	* 
		--		from	IndividualPayrollMaster ipm, 
		--				(
		--					select MAX(IndividualPayrollIndex) mipmindex 
		--					from IndividualPayrollMaster
		--					where IndividualPayrollStatus=2
		--					group by EmployeeIndex
		--				) mipm 
		--		where	ipm.IndividualPayrollIndex=mipm.mipmindex
		--	) ipm on e.EmployeeIndex = ipm.EmployeeIndex 
		--where e.EmployeeIndex=@EmployeeIndex 


		--select	@SAD=isnull	
		--			(
		--				DATEDIFF(day,dateadd(day,-1,dateadd(m,1,convert(date,str(ipm.PayrollMonth)+'/1/'+str(ipm.PayrollYear)))),e.serviceenddate)
		--				, 
		--				DATEDIFF(dd,e.ServiceStartDate,e.ServiceEndDate)
		--			) 
		--from 
		--	Employee e 
		--	left outer join 
		--	(
		--		select	* 
		--		from	IndividualPayrollMaster ipm, 
		--				(
		--					select MAX(IndividualPayrollIndex) mipmindex 
		--					from IndividualPayrollMaster
		--					where IndividualPayrollStatus=2
		--					group by EmployeeIndex
		--				) mipm 
		--		where	ipm.IndividualPayrollIndex=mipm.mipmindex
		--	) ipm on e.EmployeeIndex = ipm.EmployeeIndex 
		--where e.EmployeeIndex=@EmployeeIndex 



		-- get salary arrears days since last posted payroll     --
		-----------------------------------------------------------

		------------------
		--- Attendance ---	
		
		set @LWOP = 0 
		Set @Overtime = 0
		Set @HolidayRest = 0

		if @ClientIndex = 1090
			begin
				select	@LWOP = ISNULL(Absent,0) + ISNULL(AbsentPartial,0) + ISNULL(Adjlvbal,0) + ISNULL(LWOP1,0) + ISNULL(LWOP2,0) + ISNULL(HolidayRest,0),
						@HolidayRest = ISNULL(HolidayRest,0)
				from  (

							select sum(case when s.IsAbsent = 1 then 1 else 0 end ) Absent, 
									sum(case when isnull(s.AbsentPartial,0) > 0 and isnull(s.AbsentPartial,0) < 1 then s.AbsentPartial else 0 end ) AbsentPartial,
									sum(case 
											when isnull(s.adjlvbal,0) > 0 and isnull(s.adjlvbal,0) < 1 then s.adjlvbal 
											when isnull(s.adjlvbal,0) = 1 then 1
											else 0 end ) Adjlvbal,

									sum(case 
											when s.isleave = 1 and ISNULL(leavetotaldays,0) < 1 and  ISNULL(leavetype,0) in (5,28,79,80,81,76) then leavetotaldays 
											when s.isleave = 1 and ISNULL(leavetotaldays,0) >= 1 and ISNULL(leavetype,0) in (5,28,79,80,81,76) then 1 
											else 0 
											end 
										) LWOP1,
									sum(case 
											when s.isleave = 1 and ISNULL(leavetotaldays2,0) < 1 and  ISNULL(leavetype2,0) in (5,28,79,80,81,76) then leavetotaldays2 
											when s.isleave = 1 and ISNULL(leavetotaldays2,0) >= 1 and ISNULL(leavetype2,0) in (5,28,79,80,81,76) then 1 
											else 0 
											end 
										) LWOP2,
							
									--sum(case when s.isHoliday = 1  and  s.isgazetted = 0 and 1 = 1 then 1 else 0 end ) HolidayRest,
									sum(case when h.HolidayType in (1,2,15,18) and @MaxDaysOverRide = 1 then 1 else 0 end ) HolidayRest


								from tm_summary s
										left join (select * From tm_holidayschedule  where holidaygroup = @EmpHolidayGroup and HolidayType in (1,2,15,18)) h on s.AtDate = h.HolidayDate
							where s.employeeindex =@EmployeeIndex  
							and s.atdate  between @UnpaidDate and @ServiceEndDate

							group by s.EmployeeIndex
				) t
				
			end
			-------------------Add by Saif Ullah 2025-02-14-------------------------
		else  If @ClientIndex = 1361
		Begin
		  select		@LWOP = ISNULL(LWOP1,0) + ISNULL(LWOP2,0)
							--	, 
							--@HolidayRest = ISNULL(HolidayRest,0)
				from  (

							select sum(case 
											when s.isleave = 1 and ISNULL(leavetotaldays,0) < 1 and  ISNULL(leavetype,0) in (5,76) then leavetotaldays 
											when s.isleave = 1 and ISNULL(leavetotaldays,0) >= 1 and ISNULL(leavetype,0) in (5,76) then 1 
											else 0 
											end 
										) LWOP1,
									sum(case 
											when s.isleave = 1 and ISNULL(leavetotaldays2,0) < 1 and  ISNULL(leavetype2,0) in (5,76) then leavetotaldays2 
											when s.isleave = 1 and ISNULL(leavetotaldays2,0) >= 1 and ISNULL(leavetype2,0) in (5,76) then 1 
											else 0 
											end 
										) LWOP2
										--,
									--sum(case when s.isHoliday = 1  and  s.isgazetted = 0 and @MaxDaysOverRide = 1 then 1 else 0 end ) HolidayRest

								from tm_summary s
							where s.employeeindex =@Employeeindex  
							and s.atdate  between @tm_UnpaidDate and @ServiceEndDate

							group by s.EmployeeIndex
				) t
		End
		-------------------Add by Saif Ullah 2025-02-14-------------------------
		else
			begin
				select		@LWOP = ISNULL(Absent,0) + ISNULL(AbsentPartial,0) + ISNULL(Adjlvbal,0) + ISNULL(LWOP1,0) + ISNULL(LWOP2,0) + ISNULL(HolidayRest,0),
							@HolidayRest = ISNULL(HolidayRest,0)
				from  (

							select sum(case when s.IsAbsent = 1 then 1 else 0 end ) Absent, 
									sum(case when isnull(s.AbsentPartial,0) > 0 and isnull(s.AbsentPartial,0) < 1 then s.AbsentPartial else 0 end ) AbsentPartial,
									sum(case 
											when isnull(s.adjlvbal,0) > 0 and isnull(s.adjlvbal,0) < 1 then s.adjlvbal 
											when isnull(s.adjlvbal,0) = 1 then 1
											else 0 end ) Adjlvbal,

									sum(case 
											when s.isleave = 1 and ISNULL(leavetotaldays,0) < 1 and  ISNULL(leavetype,0) in (5,28,79,80,81,76) then leavetotaldays 
											when s.isleave = 1 and ISNULL(leavetotaldays,0) >= 1 and ISNULL(leavetype,0) in (5,28,79,80,81,76) then 1 
											else 0 
											end 
										) LWOP1,
									sum(case 
											when s.isleave = 1 and ISNULL(leavetotaldays2,0) < 1 and  ISNULL(leavetype2,0) in (5,28,79,80,81,76) then leavetotaldays2 
											when s.isleave = 1 and ISNULL(leavetotaldays2,0) >= 1 and ISNULL(leavetype2,0) in (5,28,79,80,81,76) then 1 
											else 0 
											end 
										) LWOP2,
							
									sum(case when s.isHoliday = 1  and  s.isgazetted = 0 and @MaxDaysOverRide = 1 then 1 else 0 end ) HolidayRest

								from tm_summary s
							where s.employeeindex =@Employeeindex  
							and s.atdate  between @UnpaidDate and @ServiceEndDate

							group by s.EmployeeIndex
				) t
			end


			
			--if @UserIndex = 1124
			--	begin
			--		--	exec Prl_FS_Notification_RecordUpdate 1090, 2022, 2 , 5, 87657, 1124, 227493, '', 32521
			--		-- select * From fs_master where employeeindex = 227493
			--		select @LWOP LWOP, @HolidayRest HolidayRest, @UnpaidDate UnpaidDate, @DOL DOL
			--	end
		
		--select  @LWOP  = COUNT(*)
  --      from	tm_Summary s 
  --      where	s.AtDate between @UnpaidDate and @DOL
  --              and (
		--			(s.IsLeave=1 and s.LeaveType in (5,28,79,80,81,76))
		--			or
		--			(s.IsLeave=0 and s.IsAbsent = 1 )
		--			or
		--			(@MaxDaysOverRide = 1 and isHoliday = 1 and isgazetted = 0 ) --for 26 days Muhib 12 oct 2021
		--			)
		--		and s.EmployeeIndex= @EmployeeIndex


		select  @Overtime = sum((isnull(apothh,0)*60)+isnull(apotmi,0))/60.0 
        from	tm_Summary s 
        where	s.AtDate between @tm_UnpaidDate and @DOL
				and s.EmployeeIndex= @EmployeeIndex

			---------------------------------------
			--- Gazetted Holiday Over Time (OT) ---
			--- Zeeshan 2024-06-06
			declare @i as smallint, @fColumnCode char(3), @Formula varchar(5000), @tmpFormula varchar(5000)
			if Exists(Select 1 From ClientInvFS Where ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo and isGHOT = 1 and IsNull(GHOTHourColumnCode, 0) > 0 and IsNull(GHOTAMountColumnCode, 0) > 0 and ISNULL(GHOTFormula, '') <> '')
				Begin
					Declare @GHOTHourColumnCode tinyint = 0, @GHOTAmountColumnCode tinyint = 0, @GHOvertime float
					Select 
						@Formula				= GHOTFormula,
						@GHOTHourColumnCode		= GHOTHourColumnCode,
						@GHOTAmountColumnCode	= GHOTAMountColumnCode
					From ClientInvFS 
					Where ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo

					select  @Overtime = sum((isnull(ApOTHH,0)*60)+isnull(ApOTMI,0))/60.0 
					from	tm_Summary s 
					where	s.AtDate between @tm_UnpaidDate and @DOL
							and s.EmployeeIndex= @EmployeeIndex
							and s.IsGazetted = 0

					select  @GHOvertime = sum((isnull(ApOTHH,0)*60)+isnull(ApOTMI,0))/60.0 
					from	tm_Summary s 
					where	s.AtDate between @tm_UnpaidDate and @DOL
							and s.EmployeeIndex= @EmployeeIndex
							and s.IsGazetted = 1

					if exists (select ColumnCode from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=@GHOTHourColumnCode)
					begin
						delete from FS_Detail where FSIndex = @FSIndex and columncode = @GHOTHourColumnCode
			
						insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
						values (@FSIndex, @GHOTHourColumnCode, isnull(@LWOP,0), null, 0, 0 ) 
					end

					set @Formula=REPLACE(@Formula, 'MTD', @lmMaxDays * 1.0) -- last service month total days
		--			set @Formula=REPLACE(@Formula, 'LBSD', @LBSD * 1.0) -- last balance salary days
					set @Formula=REPLACE(@Formula, 'SAD', @SAD * 1.0) -- Salary Arrears Days since last posted Payroll
					set @Formula=REPLACE(@Formula, 'SPM', @SPM) -- Service Period in Months
					set @Formula=REPLACE(@Formula, 'GSB', @GSBGroupID) -- Emp current GSB Group ID
					set @Formula=REPLACE(@Formula, 'WDs', @WorkingDays) -- Work days
					set @Formula = REPLACE(@Formula, 'GI', @GradeIndex)
					set @Formula = REPLACE(@Formula, 'EmpSSD', '''' + Cast(@DOJ as varchar(50)) + '''')	-- Service Start Date
					set @Formula = REPLACE(@Formula, 'EmpSED', '''' + Cast(@DOL as varchar(50)) + '''') -- Service End Date
					set @Formula = REPLACE(@Formula, 'EmpAge', @EmpAgeInNumber)
					set @Formula = REPLACE(@Formula, 'EmpSY', @EmpServiceYear)
					set @Formula = REPLACE(@Formula, 'EmpSP', @EmpServicePeriodInNumber)
					set @Formula = REPLACE(@Formula, 'isPF', @isPFMember)
					set @Formula = REPLACE(@Formula, 'TerritoryIndex', @TerritoryIndex)
					set @Formula = REPLACE(@Formula, 'EmpType', @EmploymentType)

					set @Formula = REPLACE(@Formula, 'GYear', @GYear)
					set @Formula = REPLACE(@Formula, 'GMonth', @GMonth)
					set @Formula = REPLACE(@Formula, 'GDays', @GDays)

					set @tmpFormula=@Formula

					while @i<LEN(@Formula)
					begin
						set @i=charindex('A',@formula, @i)
						if @i=0 
							break
					
						set @fColumnCode =  substring(@formula, charindex('A', @formula, @i)+1,3)
						--select @fColumnCode , @tmpFormula tmpFormula

						SET @Amount=0
						if @PayrollType=2
							select @Amount = convert( decimal(12,2),CONVERT(varchar(20), decryptbykey(EncAmount))) from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
						else
							select @Amount = Amount from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
			
			
						set @tmpFormula = REPLACE( @tmpFormula, 'A'+@fColumnCode, 'convert(decimal(12,2),'+ltrim(convert(nvarchar,@Amount))+')')


						set @i=@i+1
					end

					-------------------------------------------------
					------------ Fix allowance-----------------------
					------------ Muhib/Umair 22 Aug 2019-------------
					set @Formula = @tmpFormula

					while @i<LEN(@Formula)
					begin
						set @i=charindex('X',@formula, @i) --Murtaza 29 Apr 2021
						if @i=0 
							break

						set @fColumnCode =  substring(@formula, charindex('X', @formula, @i)+1,3) --Murtaza 29 Apr 2021
				
						SET @Amount=0
						if @PayrollType=2
							select @Amount = 0 --convert( decimal(12,2),CONVERT(varchar(20), decryptbykey(EncAmount))) from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
						else
							select @Amount = FixAmount from EmpDetailFixAmount where EmployeeIndex = @EmployeeIndex and ColumnCode = @fColumnCode
			
						set @tmpFormula = REPLACE( @tmpFormula, 'X'+@fColumnCode, 'convert(decimal(12,2),'+ltrim(convert(nvarchar,@Amount))+')') --Murtaza 29 Apr 2021


						set @i=@i+1
					end

					------------ Muhib/Umair 22 Aug 2019-------------
					------------ Fix allowance-----------------------
					-------------------------------------------------

			

					set @tmpformula=REPLACE(@tmpformula, 'if', ' case when ')	--Muhib 18 JUne 2017  
					set @tmpformula=REPLACE(@tmpformula, '&&', ' and ')	--Muhib 18 JUne 2017  

					SET @Amount=0
					SET @SQLString =  N'select @AmountOut = (' + @tmpformula + ')'
					SET @ParmDefinition = N'@AmountOut nvarchar(25) OUTPUT'
					EXECUTE sp_executesql @SQLString, @ParmDefinition, @AmountOut = @Amount OUTPUT

		

					--select @ColumnCode ColumnCode
					--select 'before del', * from FS_Detail where FSIndex = @FSIndex and columncode=@ColumnCode		
					delete from FS_Detail where FSIndex = @FSIndex and columncode=@GHOTAmountColumnCode
					--select 'after', * from FS_Detail where FSIndex = @FSIndex and columncode=@ColumnCode
					--		select @FSIndex,@ColumnCode,@Amount, null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= @ColumnCode
		

					if @PayrollType=2
						insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
						select @FSIndex,@GHOTAmountColumnCode,0,encryptbykey(@KeyGUID, convert(varchar(20),@Amount)), @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= @GHOTAmountColumnCode
					else
						insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
						select @FSIndex,@GHOTAmountColumnCode, Round(@Amount, @DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= @GHOTAmountColumnCode
		
					if @@Error<>0
					begin
						set @SQLString='Employee Index : [' + str(@EmployeeIndex) + ',' + STR(@GHOTAmountColumnCode) + '(' + @tmpFormula + ')' + ']'
						raiserror (@SQLString, 16,1)
						return
					end

				End

			--- Gazetted Holiday Over Time (OT) ---
			---------------------------------------

		if exists (select ColumnCode from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=140)
		begin
			delete from FS_Detail where FSIndex = @FSIndex and columncode = 140
			
			insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
			values (@FSIndex, 140, isnull(@LWOP,0), null, 0, 0 ) 
			
		end


		if exists (select ColumnCode from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=131)
		begin
			delete from FS_Detail where FSIndex = @FSIndex and columncode = 131
			
			insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
			values (@FSIndex, 131, isnull(@Overtime,0), null, 0, 0 )
			
		end
		--- Attendance ---				
		------------------


		------------------------
		--- Leave Encashment ---

		------------------Murtaza 18 Jan 2021----------------------
		Declare @IsLEFromLocation varchar(100)='',
				@IsLEFromDepartment varchar(100)='', 
				@IsLEFromGrade varchar(100)='', 
				@IsLEFromEmpType varchar(100), 
				@IsLEFromServiceDuration smallint

		select	@IsLEFromLocation = isnull(IsLEFromLocation,''),
				@IsLEFromDepartment = isnull(IsLEFromDepartment,''),
				@IsLEFromGrade = isnull(IsLEFromGrade,''),
				@IsLEFromEmpType = isnull(IsLEFromEmpType,''), 
				@IsLEFromServiceDuration = isnull(IsLEFromServiceDuration,0) 
		from	ClientInvFS
		where	ClientIndex = @ClientIndex
				and InvoiceNo = @InvoiceNo

		if exists (select ColumnCode from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=221 and ColumnType = 10)
			begin
				if exists (
					select	EmployeeIndex 
					from	employee 
					where	clientindex=@ClientIndex 
							and EmployeeIndex in (@EmployeeIndex)
							and (isnull(@IsLEFromLocation,'') = '' or LocationIndex not in (select col1 from dbo.fnParseArray(@IsLEFromLocation,',')))
							and (isnull(@IsLEFromDepartment,'') = '' or DepartmentIndex not in (select col1 from dbo.fnParseArray(@IsLEFromDepartment,',')))
							and (isnull(@IsLEFromGrade,'') = '' or GradeIndex not in (select GradeIndex from ClientGrade where ClientGradeIndex in (select col1 from dbo.fnParseArray(@IsLEFromGrade,','))) )
							and (isnull(@IsLEFromEmpType,'') = '' or PositionCategory not in (select col1 from dbo.fnParseArray(@IsLEFromEmpType,',')))
							and (isnull(@IsLEFromServiceDuration,0) = 0 or DATEDIFF(mm, @DOJ, @DOL) >= @IsLEFromServiceDuration)
							
					)
					Begin
						if exists (select * from dbo.fnLeaveBalanceFS(@EmployeeIndex) lb where balance>0 and maxencash>0)
							begin
								delete from FS_Detail where FSIndex = @FSIndex and columncode = 221
								select @DecimalPlaces=isnull(DecimalPlaces,0) from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and columncode=221

								insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
								select	@FSIndex, 221, round(max((case when lb.balance>lb.maxencash then lb.maxencash else lb.balance end )),@DecimalPlaces) Encash, null, 0, 0 
								from	dbo.fnLeaveBalanceFS(@EmployeeIndex) lb
	
							end
					End
				else
					Begin
						if exists (select * from dbo.fnLeaveBalanceFS(@EmployeeIndex) lb where balance>0 and maxencash>0)
							begin
								delete from FS_Detail where FSIndex = @FSIndex and columncode = 221
								select @DecimalPlaces=isnull(DecimalPlaces,0) from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and columncode=221

								insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
								select	@FSIndex, 221, 0, null, 0, 0 
							end
					End
			end

		
		------------------Murtaza 18 Jan 2021----------------------

		--- Leave Encashment ---
		------------------------

		-----------------------------------
		---------Muhib ---- 22 2 2022-----------
		---- SFML - Unpaid Incentive Amount -----------
		--if exists (select ColumnCode from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=87 and ColumnType in (8,9,10))
		--	begin
		--		Declare @IncentiveAmount float

		--		select	@IncentiveAmount  = SUM(Amount) 
		--			From (
		--					select	e.ClientIndex, 
		--							e.EmployeeIndex,  
		--							e.EmployeeID,
		--							e.EmployeeName,
		--							Convert(date,str(i.Month) +'/1/'+ str(i.Year)) IncentiveDdate,
		--							i.Amount,
		--							ISNULL(ipm.IndividualPayrollIndex,0) IndividualPayrollIndex

		--					from	Employee e
		--								inner join tpi_Client_Incentives i on LTRIM(RTRIM(e.EmployeeID)) = i.EmployeeID and e.ClientIndex = i.ClientIndex
		--								left join IndividualPayrollMaster ipm on e.EmployeeIndex = ipm.EmployeeIndex and ipm.PayrollMonth = i.Month and ipm.PayrollYear = i.Year and ipm.IndividualPayrollStatus = 2
							
		--					where e.EmployeeIndex = @EMployeeIndex

		--				) t
							
		--			where t.IndividualPayrollIndex = 0
					
		--		delete from FS_Detail where FSIndex = @FSIndex and columncode = 87
		--		select @DecimalPlaces=isnull(DecimalPlaces,0) from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and columncode=87

		--		insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
		--		select	@FSIndex, 87, Round(@IncentiveAmount,@DecimalPlaces), null, 9, 0 

		--	end
		---- SFML - Unpaid Incentive Amount -----------
		---------Muhib ---- 22 2 2022-----------
		-----------------------------------

---------------------
		--- Excess Leaves ---

		if @ClientIndex = 1090
			begin
				--------- exception for Sapphire --- Muhib 23 Feb 2022
			if exists (select ColumnCode from ClientInvDetail where clientindex=@ClientIndex and ClientIndex = 1090 and InvoiceNo = @InvoiceNo and ColumnCode=79 and ColumnType = 10)
				begin
					if exists (select * from dbo.fnLeaveBalanceFS(@EmployeeIndex) lb where LeaveType in (1,2) and balance < 0 )
						begin
							delete from FS_Detail where FSIndex = @FSIndex and columncode = 79
							select @DecimalPlaces=isnull(DecimalPlaces,0) from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and columncode=79

							insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
							select	@FSIndex, 79, round(sum(lb.balance*-1),@DecimalPlaces) , null, 0, 0 
							from	dbo.fnLeaveBalanceFS(@EmployeeIndex) lb
							where	lb.Balance<0
									and lb.LeaveType in (1,2)
	
						end
				end
			end
		else
		if exists (select ColumnCode from ClientInvDetail where clientindex=@ClientIndex  and InvoiceNo=@InvoiceNo and ColumnCode=79 and ColumnType = 10)
			begin
				if exists (select * from dbo.fnLeaveBalanceFS(@EmployeeIndex) lb where balance<0 )
					begin
						delete from FS_Detail where FSIndex = @FSIndex and columncode = 79
						select @DecimalPlaces=isnull(DecimalPlaces,0) from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and columncode=79

						insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
						select	@FSIndex, 79, round(sum(lb.balance*-1),@DecimalPlaces) , null, 0, 0 
						from	dbo.fnLeaveBalanceFS(@EmployeeIndex) lb
						where	lb.Balance<0
								and lb.LeaveType=3
	
					end
			end
		
		

		--- Excess Leaves ---
		---------------------

		-------------------
		--- Notice Days ---
		declare @NoticeDays float=0
		Declare @NoticeDaysActual float = 0

		if exists (select ColumnCode from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnCode=247 and ColumnType = 10)
			begin
					if @ClientIndex in (1090)
						begin
							set @NoticeDays = 0

							select	@NoticeDaysActual = (case when isnull(t.NoticeDays,30) = 255 then @MTD_FS else isnull(t.NoticeDays,30) end)

							from	employee e, 
									clientEmploymentType t	
			
							where	employeeindex = @EmployeeIndex 
								and e.PositionCategory = t.EmploymentType 
								and t.ClientIndex = e.ClientIndex
								and (ISNULL(e.SConfirmationDate,'1/1/1900') > '1/1/1900')
	
							if @ServiceEndDate = @ResignDate	--MUhib 16 June 2022
								begin
									if @MaxDaysOverRide = 1
										set @NoticeDays = @mMaxDays
									else
										set @NoticeDays = (case when @NoticeDaysActual > 30 then 30 else @NoticeDaysActual end)
								end
							else
								begin
									select @NoticeEndDate = DATEADD(day,-1,DATEADD(month, 1, @ResignDate)) --DATEADD(day, @NoticeDaysActual -1, @ResignDate)

									select	@NoticeDeductionDays =	ISNULL(Absent,0) + ISNULL(AbsentPartial,0) + ISNULL(Adjlvbal,0) + ISNULL(LWOP1,0) + ISNULL(LWOP2,0) --+ ISNULL(HolidayRest,0)
									from  (
											select sum(case when s.IsAbsent = 1 then 1 else 0 end ) Absent, 
													sum(case when isnull(s.AbsentPartial,0) > 0 and isnull(s.AbsentPartial,0) < 1 then s.AbsentPartial else 0 end ) AbsentPartial,
													sum(case 
															when isnull(s.adjlvbal,0) > 0 and isnull(s.adjlvbal,0) < 1 then s.adjlvbal 
															when isnull(s.adjlvbal,0) = 1 then 1
															else 0 end ) Adjlvbal,

													sum(case 
															when s.isleave = 1 and ISNULL(leavetotaldays,0) < 1 and  ISNULL(leavetype,0) in (5,28,79,80,81,76) then leavetotaldays 
															when s.isleave = 1 and ISNULL(leavetotaldays,0) >= 1 and ISNULL(leavetype,0) in (5,28,79,80,81,76) then 1 
															else 0 
															end 
														) LWOP1,
													sum(case 
															when s.isleave = 1 and ISNULL(leavetotaldays2,0) < 1 and  ISNULL(leavetype2,0) in (5,28,79,80,81,76) then leavetotaldays2 
															when s.isleave = 1 and ISNULL(leavetotaldays2,0) >= 1 and ISNULL(leavetype2,0) in (5,28,79,80,81,76) then 1 
															else 0 
															end 
														) LWOP2,
							
													sum(case when s.isHoliday = 1  and  s.isgazetted = 0 and 1 = 1 then 1 else 0 end ) HolidayRest

												from tm_summary s
											where s.employeeindex =@EmployeeIndex  
											and s.atdate  between  @ResignDate and @ServiceEndDate

											group by s.EmployeeIndex
										) t

									if @MaxDaysOverRide = 1
										begin
											select @NoticeDeductionDaysAfterLeaving = count(*)
											from fnDateRangeBreakup('d',DATEADD(day, 1, @ServiceEndDate), @NoticeEndDate,1) 
											where fromDAte not in (select HolidayDAte From tm_vwEmpOFF where employeeindex = @EmployeeIndex and HolidayDAte > @ServiceEndDate and IsOff = 1 and IsGazetted = 0)
										end
									else
										begin
											select @NoticeDeductionDaysAfterLeaving = count(*)
											from fnDateRangeBreakup('d',DATEADD(day, 1, @ServiceEndDate), @NoticeEndDate,1) 
										end
									
									set @NoticeDays =  @NoticeDeductionDays + @NoticeDeductionDaysAfterLeaving


							--if @UserIndex = 1124
							--	begin
							--	---	exec Prl_FS_Notification_RecordUpdate 1090, 2022, 5 , 5, 89024, 1124, 228414, '', 33686
							--	-- select * From fs_master where employeeindex = 228414
							--	select @NoticeDays NoticeDays, @LWOP LWOP, @NoticeDeductionDays NoticeDeductionDays, @NoticeDaysActual NoticeDaysActual, @LWOP_Unpaid LWOP_Unpaid, @LWOP_DuringNoticePeriod LWOP_DuringNoticePeriod, @HolidayRest HolidayRest, @NoticeDaysActual NoticeDaysActual, @NoticeDeductionDaysAfterLeaving NoticeDeductionDaysAfterLeaving, @NoticeEndDate NoticeEndDate, @ServiceEndDate ServiceEndDate, @ResignDate ResignDate, @UnpaidDate UnpaidDate, @TotalUnpaidDays TotalUnpaidDays
							--end

									if @NoticeDays > @NoticeDaysActual
										set @NoticeDays = @NoticeDaysActual

									if @MaxDaysOverRide = 1 and @NoticeDays > @mMaxDays
										set @NoticeDays = @mMaxDays
								end
						end
					else
						begin
						
							if exists (select * from FS_NoticeDays where ClientIndex = @ClientIndex)
								begin
									select @NoticeDays = case 
																when isnull(t.NoticeDays,30) = 255 then @MTD_FS
																when ISNULL(t.NoticeDays,30) = 1 then DAY(EOMONTH(ResignDate)) - ( datediff(dd,isnull(resigndate,'1/1/1900'), serviceenddate) + 1)  
															else ISNULL(t.NoticeDays,30) - ( datediff(dd,isnull(resigndate,'1/1/1900'), serviceenddate) + 1) 
													
														end
		
									from	employee e, 
											FS_NoticeDays t -- Murtaza 23 Oct 2020
			
									where	employeeindex=@EmployeeIndex 
									--	and isnull(sconfirmationdate, '1/1/1900') <> '1/1/1900'			--Commit by Muhib 10 June 2019
										and e.PositionCategory = t.EmploymentType 
										and t.ClientIndex = e.ClientIndex
										and e.ServiceStatus = t.Servicestatus -- Murtaza 23 Oct 2020
								end
					
							else
								begin
									---------------------------------------------------
									-------------- Muhib ------ July 28 2021 ----------
									if exists (select * from clientEmploymentType where ClientIndex = @ClientIndex)
										begin
											set @NoticeDays = 0
									
											if @MaxDaysOverRide = 1
												begin
													select  @NoticeDaysActual = @mMaxDays,
															@NoticeDays = 
															(	
																case 
																	when isnull(t.NoticeDays,30) = 255 
																		then @MTD_FS 
																	else  
																			--(case 
																			--		when ISNULL(t.NoticeDays,30) = 1 
																			--		then @mMaxDays
																			--		else  ISNULL(t.NoticeDays,30) end
																			--)  
																			@MTD_FS - (case when e.resigndate <> e.serviceenddate then (datediff(dd,isnull(resigndate,'1/1/1900'), serviceenddate) + 1) else 0 end)
																end
															) -- - ISNULL(@HolidayRest,0)

													from	employee e, 
															clientEmploymentType t	
			
													where	employeeindex = @EmployeeIndex 
														and e.PositionCategory = t.EmploymentType 
														and t.ClientIndex = e.ClientIndex
														and (ISNULL(e.SConfirmationDate,'1/1/1900') > '1/1/1900')


													if exists (select * From edm_ClientNoticeProbation where ClientIndex = @ClientIndex)
														begin
															select  @NoticeDaysActual = @mMaxDays,
																	@NoticeDays = 
																	(	
																		case 
																			when isnull(t.NoticeDays,30) = 255 
																				then @MTD_FS 
																			else  
																					--(case 
																					--		when ISNULL(t.NoticeDays,30) = 1 
																					--		then @mMaxDays
																					--		else  ISNULL(t.NoticeDays,30) end
																					--)  
																					@MTD_FS - (case when @ResignDAte <> e.serviceenddate then (datediff(dd,isnull(@ResignDAte,'1/1/1900'), serviceenddate) + 1) else 0 end)
																		end
																	) -- - ISNULL(@HolidayRest,0)
			
															From edm_ClientNoticeProbation t, Rpt_Data_Employee e
															where	e.EmployeeIndex = @EmployeeIndex
																and	e.ClientIndex= t.ClientIndex
																and e.ClientGradeIndex = t.ClientGradeIndex
																and e.PositionCategory = t.EmploymentType
																and (ISNULL(e.SConfirmationDate,'1/1/1900') > '1/1/1900')
														end
												end
											else
												begin
													select @NoticeDaysActual = isnull(t.NoticeDays,30),
															@NoticeDays = 
															(	
																case 
																	when isnull(t.NoticeDays,30) = 255 
																		then @MTD_FS 
																	else  (case 
																					when ISNULL(t.NoticeDays,30) = 1 --or @ClientIndex = 1090
																					then DAY(EOMONTH(resigndate)) 
																					else  ISNULL(t.NoticeDays,30) end
																			)  - (case when e.resigndate <> e.serviceenddate then (datediff(dd,isnull(resigndate,'1/1/1900'), serviceenddate) + 1) else 0 end)
																end
															)

													from	employee e, 
															clientEmploymentType t	
			
													where	employeeindex = @EmployeeIndex 
														and e.PositionCategory = t.EmploymentType 
														and t.ClientIndex = e.ClientIndex
														and (ISNULL(e.SConfirmationDate,'1/1/1900') > '1/1/1900')


													if exists (select * From edm_ClientNoticeProbation where ClientIndex = @ClientIndex)
														begin
															select @NoticeDaysActual = isnull(t.NoticeDays,30),
																	@NoticeDays = 
																	(	
																		case 
																			when isnull(t.NoticeDays,30) = 255 
																				then @MTD_FS 
																			else  (case 
																							when ISNULL(t.NoticeDays,30) = 1 --or @ClientIndex = 1090
																							then DAY(EOMONTH(@ResignDAte)) 
																							else  ISNULL(t.NoticeDays,30) end
																					)  - (case when @ResignDAte <> e.serviceenddate then (datediff(dd,isnull(@ResignDAte,'1/1/1900'), serviceenddate) + 1) else 0 end)
																		end
																	)
			
															From edm_ClientNoticeProbation t, Rpt_Data_Employee e
															where	e.EmployeeIndex = @EmployeeIndex
																and	e.ClientIndex= t.ClientIndex
																and e.ClientGradeIndex = t.ClientGradeIndex
																and e.PositionCategory = t.EmploymentType
																and (ISNULL(e.SConfirmationDate,'1/1/1900') > '1/1/1900')
														end
												end

												--add Muhib -- 
											if @NoticeDays > @NoticeDaysActual
												set @NoticeDays = @NoticeDaysActual

											if @MaxDaysOverRide = 1 and @NoticeDays > @mMaxDays
												set @NoticeDays = @mMaxDays
								  

										end
									-------------- Muhib ------ July 28 2021 ----------
									---------------------------------------------------
								end

						end
					
					--if @UserIndex = 1124
					--	begin
					--		---	exec Prl_FS_Notification_RecordUpdate 1090, 2022, 3 , 6, 89005, 1124, 250540, '', 33790
					--		-- select * From fs_master where employeeindex = 250540
					--		select @NoticeDays NoticeDays, @LWOP LWOP, @NoticeDeductionDays NoticeDeductionDays, @NoticeDaysActual NoticeDaysActual, @LWOP_Unpaid LWOP_Unpaid, @LWOP_DuringNoticePeriod LWOP_DuringNoticePeriod, @HolidayRest HolidayRest, @NoticeDaysActual NoticeDaysActual, @NoticeDeductionDaysAfterLeaving NoticeDeductionDaysAfterLeaving, @NoticeEndDate NoticeEndDate, @ServiceEndDate ServiceEndDate, @ResignDate ResignDate, @UnpaidDate UnpaidDate, @TotalUnpaidDays TotalUnpaidDays
					--	end

					if @NoticeDays < 0
						set @NoticeDays  = 0

					if @NoticeDays between 0 and 31
						begin
							
							--if	@LWOP_DuringNoticePeriod <> 0 or @LWOP <> 0
							--	begin
							--		set @NoticeDays = ISNULL(@NoticeDays,0) + @LWOP_DuringNoticePeriod --+ (@LWOP - @HolidayRest)
							--	end

							if @NoticeDays > @NoticeDaysActual
								set @NoticeDays = @NoticeDaysActual
							
							--if @UserIndex = 1124
							--	begin
							--	---	exec Prl_FS_Notification_RecordUpdate 1090, 2021, 12 , 5, 87657, 1124, 227493, '', 32521
							--	-- select * From fs_master where employeeindex = 225163
							--	select @LWOP_DuringNoticePeriod LWOP_DuringNoticePeriod, @LWOP LWOP, @NoticeDays NoticeDays, @LWOP_Unpaid LWOP_Unpaid, @HolidayRest HolidayRest
							--end


							delete from FS_Detail where FSIndex = @FSIndex and columncode = 247
						
							--Muhib -- 28 Oct 2021
							if exists (select * from EmpDeletion where Employeeindex = @EmployeeIndex and NoticeType = 1 and ApprovalStatus = 3)
								set @NoticeDays = 0

							insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
							select	@FSIndex, 247, @NoticeDays, null, 0, 0 
							--from	dbo.fnLeaveBalanceFS(@EmployeeIndex) lb
	
						end
			end

		--- Notice Days ---
		-------------------

		--------------------------------
		------- @WorkDays --------------
			select @WorkDays = ISNULL(@TotalUnpaidDays,0) - ISNULL(@LWOP,0)

			if @WorkDays < 0
				set @WorkDays = 0

		------- @WorkDays --------------
		--------------------------------

		----------------------------------
		-- Update Missing Input Columns --
		if @PayrollType=2
			insert into FS_Detail (FSIndex, ColumnCode, amount, encamount, ColumnType, IncomeTaxApply )
			select	@FSIndex, cid.columncode, 0, encryptbykey(@KeyGUID, CONVERT(varchar(20), 0)), 
					cid.ColumnType, ic.IncomeTaxApply 
			from	clientinvdetail cid, fnInvoiceColumn(@ClientIndex) ic 
			where	cid.ColumnCode=ic.ColumnCode 
					and cid.columncode<>3 
					and cid.columntype in (1,4,5)
					and cid.ClientIndex=@ClientIndex 
					and cid.InvoiceNo=@InvoiceNo
					and cid.columncode not in (select columncode from FS_Detail where FSIndex = @FSIndex)
		else
			insert into FS_Detail (FSIndex, ColumnCode, amount, encamount, ColumnType, IncomeTaxApply )
			select	@FSIndex, cid.columncode, 0, null, 
					cid.ColumnType, ic.IncomeTaxApply 
			from	clientinvdetail cid, fnInvoiceColumn(@ClientIndex) ic 
			where	cid.ColumnCode=ic.ColumnCode 
					and cid.columncode<>3 
					and cid.columntype in (1,4,5)
					and cid.ClientIndex=@ClientIndex 
					and cid.InvoiceNo=@InvoiceNo
					and cid.columncode not in (select columncode from FS_Detail where FSIndex = @FSIndex)

		update FS_Detail set ColumnType=
		(	
			select ColumnType from ClientInvDetail cid 
			where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo
			and cid.ColumnCode=FS_Detail.ColumnCode 
		)
		where FSIndex=@FSIndex -- and ColumnType is null

		update FS_Detail set IncomeTaxApply=
		(	
			select IncomeTaxApply from dbo.fnInvoiceColumn(@ClientIndex) ic
			where ic.ColumnCode=FS_Detail.ColumnCode 
		)
		where FSIndex=@FSIndex -- and IncomeTaxApply is null


		------------ 10/4/2019 By Murtaza--------
		update FS_DetailOther set ColumnType = cid.ColumnType  
				from FS_DetailOther fso, ClientInvDetail cid 
		where cid.ColumnCode = fso.ColumnCode and cid.Invoiceno = @InvoiceNo and cid.ClientIndex = @ClientIndex and fso.FSIndex = @FSIndex
		
		update FS_DetailOther set IncomeTaxApply = ic.IncomeTaxApply
				from FS_DetailOther fso, dbo.fnInvoiceColumn(@ClientIndex) ic
		where ic.ColumnCode = fso.ColumnCode and fso.FSIndex = @FSIndex

		if exists (select * from FS_Detail where columncode not in (select columncode from FS_DetailOther where FSIndex = @FSIndex) and FSIndex = @FSIndex)
			insert into FS_DetailOther (FSIndex, ColumnCode, amount, encamount, ColumnType, IncomeTaxApply )
			select * from FS_Detail where columncode not in (select columncode from FS_DetailOther where FSIndex = @FSIndex) and FSIndex = @FSIndex
		------------ 10/4/2019 By Murtaza--------


		-- Update Missing Input Columns --
		----------------------------------


		--------------------------
		-- Add Salary Per Month --
		if exists (select columncode from clientinvdetail where clientindex=@ClientIndex and invoiceno=@InvoiceNo and columntype in (3) and ColumnCode=1)
		begin
			delete from FS_Detail where FSIndex = @FSIndex and columncode = 1
			
			if @PayrollType=2
				begin
					insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select @FSIndex, 1, 0, encryptbykey(@KeyGUID, CONVERT(varchar(20), decryptbykey(isnull(EncMSal,EncGSal)))), 3, 0 from Employee where EmployeeIndex=@EmployeeIndex 
				end
			else
				insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
				select @FSIndex, 1, isnull(MonthlySalary,CurrentGrossSalary), null, 3, 0 from Employee where EmployeeIndex=@EmployeeIndex 
			
		end
		-- Add Salary Per Month --
		--------------------------

		----------------------------------------------------------------------------
		----------------------- Previous Days Adjustment ---------------------------
		-------------------- Muhib ----------- 24 June 2022 -------------------------
		begin
			Declare @Pr_GrossSalary float = 0
			Declare @Pr_AdjDays float = 0
			Declare @Pr_AdjLWOP float = 0
			Declare @Pr_Adj float = 0
			Declare @Pr_EarnedBasicSalary float = 0

			Declare @Pr_WorkDays tinyint = 26
			Declare @oldIndividualPayrollIndex bigint = 0
		
			Declare @AdjAmount float = 0
			Declare @AdjMonth tinyint = 0
			Declare @AdjYear smallint = 0
			Declare @PAIndex int = 0
		
			set @ColumnType = 0
			select @ColumnType = ColumnType from ClientInvDetail where ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo and ColumnType in (8,10) and ColumnCode = 91

			If @ColumnType = 8 Or @ColumnType = 10 
				begin
					if exists (select * From cp_EmployeePreviousAdjDetail where EmployeeIndex = @EmployeeIndex and (ISNULL(isAdjusted,0) = 0  or Remarks like '%Adjusted in FS%'))
						begin
							delete from FS_Detail  where FSIndex = @FSIndex and ColumnCode in (89,90,91)
							delete from FS_DetailOther  where FSIndex = @FSIndex and ColumnCode in (89,90,91)

							select	@PAIndex = d.PAIndex,
									@Pr_AdjDays = ISNULL(d.AdjDays,0),
									@Pr_AdjLWOP = ISNULL(d.AdjLWOP,0),
									@Pr_Adj = ISNULL(d.AdjDays,0) - ISNULL(d.AdjLWOP,0),
									@AdjMonth = d.AdjPayrollMonth,
									@AdjYear = d.AdjPayrollYear
				
							from cp_EmployeePreviousAdjMaster m, cp_EmployeePreviousAdjDetail d 
				
							where	m.PAIndex = d.PAIndex 
								and m.ClientIndex = @ClientIndex 
								and d.ApprovalStatus = 3
								and d.EmployeeIndex = @EmployeeIndex
								and (ISNULL(d.isAdjusted,0) = 0  or d.Remarks like '%Adjusted in FS%')
						
							select @oldIndividualPayrollIndex = IndividualPayrollIndex, @Pr_GrossSalary = MonthlySalary from IndividualPayrollMaster where EmployeeIndex = @EmployeeIndex and ClientIndex = @ClientIndex and PayrollMonth = @AdjMonth and PayrollYear = @AdjYear and IndividualPayrollStatus = 2

							if @oldIndividualPayrollIndex = 0
								begin
									select @Pr_GrossSalary = Amount from FS_Detail where FSIndex = @FSIndex and ColumnCode = 1
								end

							if @ClientIndex in (1090)
								select @Pr_WorkDays = ISNULL(Amount,@mMaxDays) from IndividualPayrollDetail where IndividualPayrollIndex = @oldIndividualPayrollIndex and ColumnCode = 138

							update cp_EmployeePreviousAdjDetail set isAdjusted = 1, Remarks = 'Adjusted in FS - ' + convert(varchar(20),@FSIndex) + ' WD: ' + convert(varchar(20),@Pr_WorkDays)  where EmployeeIndex = @EmployeeIndex and PAIndex = @PAIndex and AdjPayrollMonth = @AdjMonth and AdjPayrollYear = @AdjYear

							select @AdjAmount = Round((@Pr_GrossSalary / @Pr_WorkDays) * @Pr_Adj,2)

							insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
								values (@FSIndex, 89, @Pr_AdjDays, null, 10, null)
				
							insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
								values (@FSIndex, 90, @Pr_AdjLWOP, null, 10, null)

							insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
								values (@FSIndex, 91, Round(@AdjAmount,0), null, 8, 1)

							insert into FS_DetailOther ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
								values (@FSIndex, 89, @Pr_AdjDays, null, 10, null)
				
							insert into FS_DetailOther ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
								values (@FSIndex, 90, @Pr_AdjLWOP, null, 10, null)

							insert into FS_DetailOther ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
								values (@FSIndex, 91, Round(@AdjAmount,0), null, 8, 1)

						end
				end
		end
		-------------------- Muhib ----------- 24 June 2022 -------------------------
		----------------------- Previous Days Adjustment ---------------------------
		----------------------------------------------------------------------------

		--------------------
		-- Add Fix Amount --
		delete from FS_Detail where FSIndex = @FSIndex and columncode in (select columncode from clientinvdetail where clientindex=@ClientIndex and invoiceno=@InvoiceNo and columntype in (11,12,13,14,16,17))

		if exists (select columncode from clientinvdetail where clientindex=@ClientIndex and invoiceno=@InvoiceNo and columntype in (14,11,12))
			begin

				delete from FS_Detail where FSIndex = @FSIndex and columncode in (select columncode from clientinvdetail where clientindex=@ClientIndex and invoiceno=@InvoiceNo and columntype in (14,11,12))

				if @PayrollType=2
					insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select	@FSIndex, cid.columncode,
							0, 
							encryptbykey(@KeyGUID, convert(varchar(20),isnull(fa.FixAmount,0))), 
							cid.ColumnType, ic.IncomeTaxApply 
					from	ClientInvDetail cid left outer join (
												select	EmployeeIndex,
														ColumnCode,
														dbo.fnGetFixAmountEndDate(FixAmount,@FSMonth,EndDate) FixAmount, --Murtaza 16 Nov 2020
														GsbCat,
														EndDate
							
												from EmpDetailFixAmount 
												
												where EmployeeIndex = @EmployeeIndex
											) fa 
							on fa.columncode = cid.ColumnCode
							and fa.fixamount<>0 
							and fa.employeeindex=@EmployeeIndex
							, fnInvoiceColumn(@ClientIndex) ic
					where	cid.ColumnCode=ic.ColumnCode 
							and cid.clientindex=@ClientIndex 
							and cid.invoiceno=@InvoiceNo 
							and cid.ColumnType in (14,11,12)  
				else		
					insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select	@FSIndex, cid.columncode, 
							Round(isnull(fa.FixAmount,0), IsNull(cid.DecimalPlaces, 2)), 
							null, cid.ColumnType, ic.IncomeTaxApply 
					from	ClientInvDetail cid left outer join (
												select	EmployeeIndex,
														ColumnCode,
														dbo.fnGetFixAmountEndDate(FixAmount,@FSMonth,EndDate) FixAmount, --Murtaza 16 Nov 2020
														GsbCat,
														EndDate
							
												from EmpDetailFixAmount 
												
												where EmployeeIndex = @EmployeeIndex
											) fa  
							on fa.columncode = cid.ColumnCode
							and fa.fixamount<>0 
							and fa.employeeindex=@EmployeeIndex
							, fnInvoiceColumn(@ClientIndex) ic
					where	cid.ColumnCode=ic.ColumnCode 
							and cid.clientindex=@ClientIndex 
							and cid.invoiceno=@InvoiceNo 
							and cid.ColumnType in (14,11,12)  
			end

		if exists (select columncode from clientinvdetail where clientindex=@ClientIndex and invoiceno=@InvoiceNo and columntype in (13,16,17))
			begin

			--	delete from FS_Detail where FSIndex = @FSIndex and columncode in (select columncode from clientinvdetail where clientindex=@ClientIndex and invoiceno=@InvoiceNo and columntype in (11,12,13))
					--select @SAM SAM, @DOL DOL, @FSMonth FSMonth, @SAD SAD
					

				if @MaxDaysOverRide = 1
					begin
							insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
							select	@FSIndex, 
									cid.columncode, 
									round(
											(
												isnull(fa.fixamount,0) * @SAM
												+
												(( isnull(fa.fixamount,0) / 
													( @mMaxDays* 1.0)
												) 
												* 
												(case when @DOL >=  ISNULL(fa.EndDate,'1/1/2099') then DATEDIFF(dd, @FSMonth, fa.EndDate) +1 else @SAD end )
												)
											)
										 , isnull(cid.DecimalPlaces, 2)) ,
									null, 
									cid.ColumnType, 
									ic.IncomeTaxApply 
							from	ClientInvDetail cid left outer join (
														select	EmployeeIndex,
																ColumnCode,
															--	dbo.fnGetFixAmountEndDate(FixAmount,@FSMonth,EndDate) FixAmount, --Murtaza 16 Nov 2020
																FixAmount,
																GsbCat,
																EndDate
							
														from EmpDetailFixAmount 
												
														where EmployeeIndex = @EmployeeIndex
													) fa  
									on fa.columncode = cid.ColumnCode
									and fa.fixamount<>0 
									and fa.employeeindex=@EmployeeIndex
									, fnInvoiceColumn(@ClientIndex) ic
							where	cid.ColumnCode=ic.ColumnCode 
									and cid.clientindex=@ClientIndex 
									and cid.invoiceno=@InvoiceNo 
									and cid.ColumnType in (13,16,17) 
					end
				else
					begin

						insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
						select	@FSIndex, 
								cid.columncode, 
								round(
										(
											isnull(fa.fixamount,0) * @SAM
											+
											(( isnull(fa.fixamount,0) / 
												( datediff(day, dateadd(day, 1-day(@FSMonth), @FSMonth),dateadd(month, 1, dateadd(day, 1-day(@FSMonth), @FSMonth)))* 1.0)
											) 
											* 
											(case when @DOL >=  ISNULL(fa.EndDate,'1/1/2099') then DATEDIFF(dd, @FSMonth, fa.EndDate) +1 else @SAD end )
											)
										)
									 , IsNull(cid.DecimalPlaces, 2)),
								null, 
								cid.ColumnType, 
								ic.IncomeTaxApply 
						from	ClientInvDetail cid left outer join (
													select	EmployeeIndex,
															ColumnCode,
														--	dbo.fnGetFixAmountEndDate(FixAmount,@FSMonth,EndDate) FixAmount, --Murtaza 16 Nov 2020
															FixAmount,
															GsbCat,
															EndDate
							
													from EmpDetailFixAmount 
												
													where EmployeeIndex = @EmployeeIndex
												) fa  
								on fa.columncode = cid.ColumnCode
								and fa.fixamount<>0 
								and fa.employeeindex=@EmployeeIndex
								, fnInvoiceColumn(@ClientIndex) ic
						where	cid.ColumnCode=ic.ColumnCode 
								and cid.clientindex=@ClientIndex 
								and cid.invoiceno=@InvoiceNo 
								and cid.ColumnType in (13,16,17) 
				end
			end
		-- Add Fix Amount --
		--------------------

--select * from ColumnType

		--------------------------
		-- Get Unadjusted Loans --
		set @ColumnType=0

		declare @LoanType tinyint, @LoanColumn tinyint

		select @ColumnType=ColumnType from clientinvdetail where ColumnCode=175 and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo 

		If @ColumnType = 10 Or @ColumnType = 9  
		begin
		
		
			--------------------------------------------------------------------------------------
			---------------------------Update Loan Detail 8 Feb 2022------------------------------
			
			insert into FS_LoanDetail
			select	@FSIndex, @EmployeeIndex,ls.LoanNo,ld.DeductionDate,@UserIndex,GetDate()
			from	LoanDetail ld,LoanSummary ls,LoanType t
			where	ls.LoanType=t.LoanType 
					and ls.EmployeeIndex=ld.EmployeeIndex
					and ls.LoanNo=ld.LoanNo
					and t.LoanCat=1
					and ld.EmployeeIndex=@EmployeeIndex and isnull(IndividualPayrollIndex,-2) =-2

			update	LoanDetail
			set		IndividualpayrollIndex = -1
			from	LoanDetail ld,LoanSummary ls,LoanType t
			where	ls.LoanType=t.LoanType 
					and ls.EmployeeIndex=ld.EmployeeIndex
					and ls.LoanNo=ld.LoanNo
					and t.LoanCat=1
					and ld.EmployeeIndex=@EmployeeIndex and isnull(IndividualPayrollIndex,-2) =-2
			
			select	@LoanAdjustment = isnull( sum( isnull(ld.amount,0) ),0)
			from	LoanSummary ls, 
					LoanDetail ld , 
					FS_LoanDetail fsl, 
					LoanType t
			where	ls.LoanType=t.LoanType 
					and ls.EmployeeIndex=ld.EmployeeIndex
					and ls.LoanNo=ld.LoanNo
					and t.LoanCat=1
					and ld.EmployeeIndex = fsl.EmployeeIndex and ld.LoanNo = fsl.LoanNo and ld.DeductionDate = fsl.DeductionDate and FSIndex = @FSIndex
					and ld.EmployeeIndex=@EmployeeIndex --and isnull(IndividualPayrollIndex,-2) =-2
		
			---------------------------Update Loan Detail 8 Feb 2022------------------------------
			--------------------------------------------------------------------------------------
		
			select @DecimalPlaces=isnull(DecimalPlaces,0) from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and columncode=175
			--------------------
			-- Refresh Values -- 
			delete from FS_Detail where FSIndex = @FSIndex and ColumnCode=175
			
			if @PayrollType=2
				insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply ) 
				select @FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@LoanAdjustment, @DecimalPlaces))), @ColumnType, ic.IncomeTaxApply
				from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=175
			else
				insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply ) 
				select @FSIndex, ic.ColumnCode, round(@LoanAdjustment, @DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply
				from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=175
			-- Refresh Values -- 
			--------------------
		end		
		-- Get Unadjusted Loans --
		--------------------------


		----////////////////////////////////
		----/// Incase of multiple loans ///
		If @ColumnType = 10
		begin
			declare cur_Loan cursor for
			select	loantype, columncode 
			from	LoanColumn 
			where	clientindex=@ClientIndex
					and (LoanType in (select LoanType from LoanType where LoanCat=1)  or isnull(loantype,0)=0)
			open cur_Loan
			fetch next from cur_Loan into @LoanType, @LoanColumn
			while @@FETCH_STATUS=0
			begin

				set @Amount = 0
				--select	@Amount=isnull(sum(ld.Amount),0) from loandetail ld, loansummary ls 
				--where	ld.LoanNo=ls.LoanNo and ld.EmployeeIndex=ls.EmployeeIndex  
				--		and ls.LoanType=@LoanType 
				--		and ld.employeeindex = @EmployeeIndex and isnull(IndividualPayrollIndex,-2) =-2

				select	@Amount = isnull( sum( isnull(ld.amount,0) ),0)
				from	LoanSummary ls, 
						LoanDetail ld , 
						FS_LoanDetail fsl
				where	ls.EmployeeIndex=ld.EmployeeIndex
						and ls.LoanNo=ld.LoanNo
						and ls.LoanType=@LoanType 
						and ld.EmployeeIndex = fsl.EmployeeIndex 
						and ld.LoanNo = fsl.LoanNo 
						and ld.DeductionDate = fsl.DeductionDate 
						and FSIndex = @FSIndex
						and ld.EmployeeIndex=@EmployeeIndex --and isnull(IndividualPayrollIndex,-2) =-2

				--////////////////////////////////////////
				--/// Refresh Existing Column's Amount ///
				
				select @DecimalPlaces=isnull(DecimalPlaces,2) from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and columncode=@LoanColumn

				delete from fs_Detail where FSIndex  = @FSIndex and columncode=@LoanColumn   
				if @PayrollType=2
					insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply ) 
					select	@FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@Amount,@DecimalPlaces) )), 9, ic.IncomeTaxApply  
					from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=@LoanColumn 
				else
					insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply ) 
					select	@FSIndex, ic.ColumnCode, round(@Amount,@DecimalPlaces), null, 9, ic.IncomeTaxApply  
					from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=@LoanColumn 
				--/// Refresh Existing Column's Amount ///
				--////////////////////////////////////////

				fetch next from cur_Loan into @LoanType, @LoanColumn
			end
			close cur_Loan
			deallocate cur_Loan
		End
		----/// Incase of multiple loans ///
		----////////////////////////////////


		-----------------------------
		-- Get Unadjusted Advances --
		set @ColumnType=0
		select @ColumnType=ColumnType from clientinvdetail where ColumnCode=224 and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo 

		If @ColumnType = 10 Or @ColumnType = 9
		begin
			select	@AdvanceAdjustment = isnull( sum( isnull(Amount,0) ), 0)
			from	EmpDetailAdvances  
			where	EmployeeIndex=@EmployeeIndex 
					and (IndividualPayrollIndex is null or IndividualpayrollIndex=-2)
					and AdvanceType<>2

			--------------------
			-- Refresh Values -- 
			delete from FS_Detail where FSIndex = @FSIndex and ColumnCode=224

			select @DecimalPlaces=isnull(DecimalPlaces, 2) from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and columncode=224

			if @PayrollType=2
				insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply ) 
				select @FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@AdvanceAdjustment,2))), @ColumnType, ic.IncomeTaxApply
				from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=224
			else			
				insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply ) 
				select @FSIndex, ic.ColumnCode, round(@AdvanceAdjustment, @DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply
				from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=224

			if round(@AdvanceAdjustment, @DecimalPlaces)<>0
			begin
			update FS_Master set HoldAmount=round(@AdvanceAdjustment, @DecimalPlaces) where FSIndex=@FSIndex
			update EmpDetailAdvances set IndividualpayrollIndex=-2, Remarks=ltrim(rtrim(Remarks))+' / Adjusted in FS' 
			where	EmployeeIndex=@EmployeeIndex 
					and IndividualPayrollIndex is null
					and AdvanceType<>2
			end
			-- Refresh Values -- 
			--------------------
		end
		-- Get Unadjusted Advances --
		-----------------------------
		
		

		--------------
		-- Get OPD  --
		set @ColumnType=0
		select @ColumnType=ColumnType from clientinvdetail where ColumnCode=78 and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo 

		If @ColumnType = 10 Or @ColumnType = 9
		begin

			declare @OPDAdj float=0, @OPDEnt float=0, @OPDEntPerDay float=0, @OPDAvailed float=0, @OPDfDate date, @OPDtDate date, @mFrom tinyint, @dFrom tinyint, @mTo tinyint, @dTo tinyint, @yTo smallint, @yFrom smallint--, @ClientIndex smallint=882, @DOL date='6/1/2018'


			set		@mFrom = MONTH(@DOL)		
			set		@yFrom = YEAR(@DOL)
			set		@yTo = @yFrom

			if exists (select * from opd where clientindex=882 and OPDCat=1)
			Begin
				--exec bn_OPDSetEmpEntitlement @EmployeeIndex, @yFrom, @mFrom, @UserIndex, 1, '' -- Comment By Murtaza As this is generating error message on all clients 14 Apr 2022
				exec bn_OPDSetEmpEntitlement @EmployeeIndex, @yFrom, @mFrom, @UserIndex, 1, '' -- UnComment By Murtaza For Metro 16 May 2022
			End

			select	@mFrom=month(periodfrom), @dFrom=day(periodfrom), @mTo=month(periodto), @dTo=day(periodto)
			from	opd 
			where	opd.clientindex=@ClientIndex 


			If @mFrom <> 1 Or @mTo <> 12 
			begin
				If month(@DOL) >= @mFrom
					set @yTo = @yTo + 1
				If month(@DOL) < @mFrom 
					set @yFrom = @yFrom - 1
			end
		

			select @mFrom, @mTo, @dFrom, @dTo, @yFrom, @yTo


			set @OPDfDate = lTrim(str(@mFrom)) + '/' + lTrim(str(@dFrom)) + '/' + lTrim(str(@yFrom))
			set @OPDtDate = lTrim(str(@mTo)) + '/' + lTrim(str(@dTo)) + '/' + lTrim(str(@yTo))


			select	@OPDEnt = isnull(sum(Ent),0) 
			from	OPDEmpDetail 
			where	EmployeeIndex= @EmployeeIndex 
					and DtFrom between @OPDfDate and @OPDtDate


			select	@OPDAvailed = isnull(sum(OPDAmount),0) 
			from	EmpOPDClaims 
			where	EmployeeIndex= @EmployeeIndex
					and OPDMonth between @OPDfDate and @OPDtDate

			--set @OPDEntPerDay = @OPDEnt / (datediff(dd, @OPDfDate, @OPDtDate)+1)
			--set @OPDEnt = (@OPDEntPerDay*(datediff(dd, @OPDfDate, @DOL)+1))  --murtaza,7/11/19


			if @OPDAvailed>@OPDEnt
				set @OPDAdj=@OPDAvailed-@OPDEnt
			else
				set @OPDAdj=0

			
			update fs_Master
			set		OPDEntitlement=@OPDEnt,
					OPDAvailed=@OPDAvailed
			where	FSIndex=@FSIndex

			--select @OPDEnt, @OPDEntPerDay, (@OPDEntPerDay*(datediff(dd, @OPDfDate, @DOL)+1)) OPDEntNew

--			select * from EmpOPDClaims where employeeindex= 166372

--			select @OPDfDate, @OPDtDate


			--------------------
			-- Refresh Values -- 

			----------11/4/2019 murtaza--------------
			Declare @OPDAmount float = (Select Amount from FS_Detail where FSIndex = @FSIndex and ColumnCode in (78))
			Declare @OPDOAmount float = (Select Amount from FS_DetailOther where FSIndex = @FSIndex and ColumnCode in (78))
			
			if @OPDAmount = @OPDOAmount
				begin

					delete from FS_DetailOther where FSIndex = @FSIndex and ColumnCode=78

					select @DecimalPlaces=isnull(DecimalPlaces,0) from ClientInvDetail where clientindex=@ClientIndex and InvoiceNo=@InvoiceNo and columncode=78

					update FS_MasterOther
					set		OPDEntitlement=@OPDEnt,
							OPDAvailed=@OPDAvailed
					where	FSIndex=@FSIndex

					insert into FS_DetailOther(FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply ) 
					select @FSIndex, ic.ColumnCode, round(@OPDAdj,@DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply
					from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=78

				end
			----------11/4/2019 murtaza--------------

			delete from FS_Detail where FSIndex = @FSIndex and ColumnCode=78

			insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply ) 
			select @FSIndex, ic.ColumnCode, round(@OPDAdj,@DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply
			from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=78
			-- Refresh Values -- 
			--------------------
		end
		-- Get OPD  --
		--------------


		---------------------------
		-- Get Payable PF Amount --
		set @isPFGroup = 0 --Murtaza 8 Dec 2022

		if (@SAM+@SAD)<>0
		begin


			--////////////////////
			--/// Calculate PF ///
			set @ColumnType=0
			select	@ColumnType=columntype,
					@DecimalPlaces=isnull(DecimalPlaces,0)
			from clientinvdetail where columncode in (183,184) and clientindex=@ClientIndex and invoiceno=@InvoiceNo 

			If @ColumnType = 10 Or @ColumnType = 9 Or @ColumnType = 8
			begin
	    

				declare @StartingMonth tinyint, 
						@BasicPercent float,
						@PFSalary float,
						@PFPerDay float,
						@IsConfirmationBase tinyint,
						@PFServiceMonth As smallint,
						@PFAdjustment as float,
						@monthPF As float,
						@rPFSalary float,
						@rMonthPF As float,
						@jPFDays As smallint,
						@PF As float, 
						@lPF As float, 
						@jPF As float,
						@srPF as float,
						@pPF as float -- Previous PF Deducted in financial year
						,@DaysAddition float = 0		--Muhib 14 March 2019
						,@DaysDeduction float = 0		--Muhib 14 March 2019

	-------------------------------------------------------------------------
	----------------------------Muhib 7 oct 2019-----------------------------		
				,@RBCType tinyint	--1 on Confirmation by Months
									--2 on Confirmation by Days
									--3 on Membership 
				,@PFStartDate Date 
	----------------------------Muhib 7 oct 2019-----------------------------		
	-------------------------------------------------------------------------
	

				set		@StartingMonth = 0
				set		@BasicPercent = 0
				set		@IsConfirmationBase = 0
				set		@PFPerDay = 0
				set		@monthPF = 0

				----------Murtaza 8 Dec 2022---------
				if exists (select * From ClientPlanPFGroup where ClientIndex = @ClientIndex)
				begin
					set @isPFGroup = 1
				end
				----------Murtaza 8 Dec 2022---------

				if exists (select * from ClientInvPF where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo)
					begin
						begin

							select	@PFSalary=isnull(SUM( Fixamount ),0)--, @PFPerDay = SUM((amount*12)/365 )
							from	EmpDetailFixAmount
							where	EmployeeIndex=@EmployeeIndex
									and ColumnCode in (
										select ColumnCode from ClientInvPF where ClientIndex=@ClientIndex 
										and InvoiceNo=@InvoiceNo and ColumnType = 4 
										) 

							select	@PFSalary=@PFSalary-isnull(SUM( Fixamount ),0)
							from	EmpDetailFixAmount
							where	EmployeeIndex=@EmployeeIndex
									and ColumnCode in (
										select ColumnCode from ClientInvPF where ClientIndex=@ClientIndex 
										and InvoiceNo=@InvoiceNo and ColumnType = 5 
										) 
							
							if ISNULL(@MaxDaysOverRide,0) = 1   
								set @PFPerDay=((@PFSalary)/@mMaxDays)
							else
								set @PFPerDay=((@PFSalary)/Day(EOMONTH(@FSMonth)))	--PF number of days in a month >> Muhib 28 July 2021

							--set @PFPerDay=((@PFSalary*12)/365.0 )
							
							--if @SAD > 0
							--	begin
							--		set @PFSalary = @PFPerDay * @SAD
							--	end

							if exists (select * from ClientInvPF where ColumnType in (7) and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo)
								select	@DaysDeduction=isnull(SUM(Amount ),0)	--Muhib 14 March 2019
								from	FS_DetailOther
									where	FSIndex=@FSIndex
												and ColumnCode in 
													(select ColumnCode from ClientInvPF where ClientIndex=@ClientIndex 
														and InvoiceNo=@InvoiceNo and ColumnType = 7 )

								--select	@PFSalary=@PFSalary - (isnull(SUM(Amount ),0)*@PFPerDay) 
								--from	FS_Detail
								--	where	FSIndex=@FSIndex
								--				and ColumnCode in 
								--					(select ColumnCode from ClientInvPF where ClientIndex=@ClientIndex 
								--						and InvoiceNo=@InvoiceNo and ColumnType = 7 )

							if exists (select * from ClientInvPF where ColumnType in (6) and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo)
								select @DaysAddition = isnull(SUM(Amount),0)	--Muhib 14 March 2019
									from	FS_DetailOther
									where	FSIndex=@FSIndex
										and ColumnCode in 
												(select ColumnCode from ClientInvPF where ClientIndex=@ClientIndex 
													and InvoiceNo=@InvoiceNo and ColumnType = 6 )

								--select @PFSalary=@PFSalary + (isnull(SUM(Amount),0)*@PFPerDay) 
								--	from	FS_Detail
								--	where	FSIndex=@FSIndex
								--		and ColumnCode in 
								--				(select ColumnCode from ClientInvPF where ClientIndex=@ClientIndex 
								--					and InvoiceNo=@InvoiceNo and ColumnType = 6 )

						end
					end
				else
					set		@PFSalary = @BasicSalary 


				SET @rPFSalary = @PFSalary 

				-- Murtaza 8 Dec 2022--
				--select	@StartingMonth=pf.StartingMonth,
				--		@BasicPercent=(case when pf.BasicPercent=-1 then isnull(pfs.PFPercent,0) else pf.BasicPercent end),
				--		@IsConfirmationBase=pf.IsConfirmationBase
				--from	ClientPlanPF pf left outer join ClientPlanPFSlab pfs
				--		on pf.ClientIndex=pfs.ClientIndex 
				--		and datediff(mm, @DOJ, @LPayrollDate) between pfs.MonthFrom and pfs.MonthTo
				--where	pf.ClientIndex=@ClientIndex
				-- Murtaza 8 Dec 2022--
		
			-------------------------------------------------------------------------
			----------------------------Muhib 7 oct 2019-----------------------------		
				if exists (select * from ClientPlanPF where ClientIndex = @ClientIndex)
					select @RBCType = ISNULL(RBCType,1) from ClientPlanPF where ClientIndex = @ClientIndex
				
				--------------------------- Murtaza 8 Dec 2022-----------------------------------------

				if @isPFGroup = 1
						begin
							Declare @PFGroupIndex int = 0

							select @PFGroupIndex = t.PFGroupIndex 
							
							from 
							(
								select	ewl.EmployeeIndex,
										pf.PFGroupIndex,
										Count(*) WLCount

								from VwEmpWL ewl 
										inner join ClientPlanPFGroup pf on pf.ClientIndex = @ClientIndex
										inner join ClientPlanPFGroupWL pfwl on ewl.WorkLocation = pfwl.workLocation and ewl.WorkLocationIndex = pfwl.WorkLocationIndex and pf.PFGroupIndex = pfwl.PFGroupIndex
											   
								where ewl. EmployeeIndex in (@EmployeeIndex)

								group by ewl.EmployeeIndex, pf.PFGroupIndex
							) t,
							(select PFGroupIndex, ISNULL(Count(DISTINCT WorkLocationIndex),0) WLCount From ClientPlanPFGroupWL group by PFGroupIndex) wl

							where t.PFGroupIndex = wl.PFGroupIndex
								and t.WLCount = wl.WLCount
						
							
							if	ISNULL(@PFGroupIndex,0) > 0
								begin
									select	@StartingMonth=pf.StartingMonth,
											@BasicPercent= pf.BasicPercent,
											@IsConfirmationBase=pf.IsConfirmationBase,
											@RBCType = ISNULL(RBCType,1)
							
									from ClientPlanPFGroup pf where ClientIndex = @ClientINdex and PFGroupIndex = @PFGroupIndex
								end
							else
								begin
									select	@StartingMonth = 0,
											@BasicPercent = 0,
											@IsConfirmationBase = 0,
											@RBCType = 0
								end
						
						end
					else
						begin
							--select	@StartingMonth=pf.StartingMonth,
							--		@BasicPercent=(case when pf.BasicPercent=-1 then isnull(pfs.PFPercent,0) else pf.BasicPercent end),
							--		@IsConfirmationBase=pf.IsConfirmationBase
							--from    ClientPlanPF pf 
							--		left outer join ClientPlanPFSlab pfs on pf.ClientIndex=pfs.ClientIndex and datediff(mm, @DOJ, @PayrollDate) between pfs.MonthFrom and pfs.MonthTo
							--where	pf.ClientIndex = @ClientIndex

							select	@StartingMonth=pf.StartingMonth,
									@BasicPercent=(case when pf.BasicPercent=-1 then isnull(pfs.PFPercent,0) else pf.BasicPercent end),
									@IsConfirmationBase=pf.IsConfirmationBase
							from	ClientPlanPF pf left outer join ClientPlanPFSlab pfs
									on pf.ClientIndex=pfs.ClientIndex 
									and datediff(mm, @DOJ, @LPayrollDate) between pfs.MonthFrom and pfs.MonthTo
							where	pf.ClientIndex=@ClientIndex
						end
				
				--------------------------- Murtaza 8 Dec 2022-----------------------------------------

				if @RBCType = 3		
					begin
						if exists (select * from bn_RetirementBenefitMemberShip where EmployeeIndex  = @EmployeeIndex and StartDate <> '1900-01-01 00:00:00.000' )
							select @PFStartDate = StartDate from bn_RetirementBenefitMemberShip where EmployeeIndex  = @EmployeeIndex
						else	
							begin
								set @PFStartDate = '1/1/3000'
								set @BasicPercent = 0
							end
					end
			----------------------------Muhib 7 oct 2019-----------------------------		
			-------------------------------------------------------------------------

				if exists (select * from ClientPlanPFWL where clientindex=@ClientIndex)
				begin
					select	@StartingMonth = pf.StartingMonth, 
							@BasicPercent = (case when pf.BasicPercent=-1 then isnull(pfs.PFPercent,0) else pf.BasicPercent end), 
							@IsConfirmationBase = pf.IsConfirmationBase 
					from VwEmpWL ewl 
								inner join ClientPlanPFWL pf on ewl.WorkLocation = pf.workLocation and ewl.WorkLocationIndex = pf.WorkLocationIndex 
								left outer join ClientPlanPFSlabWL pfs on pf.ClientIndex=pfs.ClientIndex 
											and datediff(mm, @DOJ, @LPayrollDate) between pfs.MonthFrom and pfs.MonthTo 
											and ewl.WorkLocationIndex=pfs.WorkLocationIndex 
											and ewl.WorkLocation=pfs.WorkLocation 
					where pf.ClientIndex=@ClientIndex and ewl. employeeindex=@EmployeeIndex 
				end
				--- umair pf ssa muhib

				declare @FixAmountPF as float
						set @FixAmountPF=0
	
						select @FixAmountPF=isnull(SUM(FixAmount),0) 
						from ClientInvPF cipf, EmpDetailFixAmount edfa 
						where cipf.ClientIndex=@ClientIndex and cipf.InvoiceNo=@InvoiceNo and cipf.ColumnType=4 
							and edfa.EmployeeIndex=@EmployeeIndex and edfa.GsbCat<>1  
							and cipf.columncode=edfa.columncode
		
				set		@monthPF = ( @PFSalary * @BasicPercent ) / 100.0
				set		@rMonthPF = ( @rPFSalary * @BasicPercent ) / 100.0


			if @RBCType = 3		--Muhib 7 oct 2019
				begin
					set	@PFServiceMonth = datediff(mm, @PFStartDate, @LPayrollDate)
					set @jPFDays = (day(dateadd(d,-1,dateadd(m, 1, convert(datetime, '1/' + ltrim(str(month(@PFStartDate))) + '/' + ltrim(str(year( dateadd(m, @StartingMonth, @PFStartDate) ))),103))))-day(dateadd(m, @StartingMonth, @PFStartDate))+1)
					if dateadd(m, @StartingMonth ,@PFStartDate) > dateadd(d,-1,dateadd(m,1,@LPayrollDate))
					begin
						set @monthPF = 0
						set @jPFDays = 0 
					end
				end
			else
				begin
					if @IsConfirmationBase = 1
						begin 
							set	@PFServiceMonth = datediff(mm, @DOC, @LPayrollDate)
							set @jPFDays = (day(dateadd(d,-1,dateadd(m, 1, convert(datetime, '1/' + ltrim(str(month(@DOC))) + '/' + ltrim(str(year( dateadd(m, @StartingMonth, @DOC) ))),103))))-day(dateadd(m, @StartingMonth, @DOC))+1)
							if dateadd(m, @StartingMonth ,@DOC) > dateadd(d,-1,dateadd(m,1,@LPayrollDate))
							begin
								set @monthPF = 0
								set @jPFDays = 0 
							end
							-----------------------------------------------------------------
							---------------- Muhib 1st Feb 2019 -----------------------------
							if @DOC = '1/1/1900' 
								begin
									set @monthPF = 0
									set @jPFDays = 0
								end
							---------------- Muhib 1st Feb 2019 -----------------------------							
							-----------------------------------------------------------------

						end
					else
						begin
							set	@PFServiceMonth = datediff(mm, @DOJ, @LPayrollDate)
							set	@jPFDays = (day(dateadd(d,-1,dateadd(m, 1, convert(datetime, '1/' + ltrim(str(month( dateadd(m, @StartingMonth, @DOJ) ))) + '/' + ltrim(str(year( dateadd(m, @StartingMonth, @DOJ) ))),103))))-day(dateadd(m, @StartingMonth, @DOJ))+1)
							if dateadd(m, @StartingMonth ,@DOJ) > dateadd(d,-1,dateadd(m,1,@LPayrollDate))
							begin
								set @monthPF = 0
								set @jPFDays = 0 
							end
						end
				end
		
				
				
				set @PF = 0

				set @PF = @monthPF
        
				if exists (select * from EmpFixPF where employeeindex=@EmployeeIndex)
				begin
					select @PF = isnull(PFAmount,0) from EmpFixPF where employeeindex=@EmployeeIndex
					if @PF=-1 
						set @PF=0 
				end

			End
			--/// Calculate PF ///
			--////////////////////




			declare @PFEmployerContribution float=0, @PFEmployeeContribution float=0
			declare @TotalPFEmployer float=0, @TotalPFEmployee float=0
			declare @IPMPFEmployer float=0, @IPMPFEmployee float=0


			declare @mn int=0

			set @PFEmployerContribution = @PF
			set @PFEmployeeContribution = @PF

			select	@IPMPFEmployer = Amount
			from	IndividualPayrollDetail
			where	IndividualPayrollIndex=@IPMIndex
					and ColumnCode=183

			select	@IPMPFEmployee = Amount
			from	IndividualPayrollDetail
			where	IndividualPayrollIndex=@IPMIndex
					and ColumnCode=184
			

			-------------------------------------------------------------------------------------------------------------------------
			--------------------------------------------------Murtaza 16 May 2022----------------------------------------------------
			while @mn<@SAM
			begin


				--if not exists (select * from bn_pf_EmpWorking where EmployeeIndex=@EmployeeIndex and PayrollMonth=dateadd(mm,@mn,@UnpaidDate))
				--begin
				--	insert into bn_pf_EmpWorking ( EmployeeIndex, PayrollMonth, EmployerCont, EmployeeCont, EmployerInt, EmployeeInt, WithdrawlPermanent, WithdrawlTemporary, WithdrawlRecovery, AccumulatedBalnace ) 
				--	values ( @EmployeeIndex, dateadd(mm,@mn,@UnpaidDate),0, 0,0,0,0,0,0,0 )
				--end

				--update	bn_pf_EmpWorking 
				--set		EmployeeCont=Round(@PFEmployeeContribution, @DecimalPlaces),
				--		EmployerCont=Round(@PFEmployerContribution, @DecimalPlaces)
				--where	EmployeeIndex=@EmployeeIndex and PayrollMonth=dateadd(mm,@mn,@UnpaidDate)


				set @TotalPFEmployer = @TotalPFEmployer + @PFEmployerContribution
				set @TotalPFEmployee = @TotalPFEmployee + @PFEmployeeContribution
				
				set @mn=@mn+1

			end

			--------------------------------------------------Murtaza 16 May 2022----------------------------------------------------
			-------------------------------------------------------------------------------------------------------------------------

			if @SAM<>0
			begin
				update	fs_Master
				set		PFMonthAdj=@TotalPFEmployer+@TotalPFEmployee,
						SalMonthAdj=(@MonthlySalary*@SAM) + IsNull(@FixAmountEndedBeforeSED, 0)
				where	FSIndex=@FSIndex
			end
			
			------------------------------------------
			---------- Muhib ------ 28 July 2021 ------
			if @MaxDaysOverRide = 1  
				set @WorkingDays = @mMaxDays
			else
				set @WorkingDays = convert(float,day( dateadd(dd,-1, dateadd(mm,1,@FSMonth))  ))
			---------- Muhib ------ 28 July 2021 ------
			------------------------------------------
		
			if (@SAD - isnull(@DaysDeduction,0) + isnull(@DaysAddition,0))<>0
			begin
				
				--set @PFEmployerContribution = @PFEmployerContribution --/ convert(float,day( dateadd(dd,-1, dateadd(mm,1,@FSMonth))  )) * @SAD
				--set @PFEmployeeContribution = @PFEmployeeContribution --/ convert(float,day( dateadd(dd,-1, dateadd(mm,1,@FSMonth))  )) * @SAD
				
				-- Muhib 14 March 2019
				set @PFEmployerContribution = @PFEmployerContribution / @WorkingDays * (@SAD - @DaysDeduction + @DaysAddition)
				set @PFEmployeeContribution = @PFEmployeeContribution / @WorkingDays * (@SAD - @DaysDeduction + @DaysAddition)
				-- Muhib 14 March 2019

				--select @MonthlySalary MonthlySalary, @WorkingDays WorkingDays, @SAD SAD, @mMaxDays mMaxDays, @MaxDaysOverRide MaxDaysOverRide

				update	fs_Master
				set		PFDayAdj = @PFEmployerContribution + @PFEmployeeContribution,
						SALDayAdj = (@MonthlySalary / @WorkingDays * @SAD) + IsNull(@FixAmountEndedBeforeSED, 0)
				where	FSIndex = @FSIndex

				if not exists (select * from bn_pf_EmpWorking where EmployeeIndex=@EmployeeIndex and PayrollMonth=@FSProcMonth)
				begin
					insert into bn_pf_EmpWorking ( EmployeeIndex, PayrollMonth, EmployerCont, EmployeeCont, EmployerInt, EmployeeInt, WithdrawlPermanent, WithdrawlTemporary, WithdrawlRecovery, AccumulatedBalnace ) 
					values ( @EmployeeIndex, @FSProcMonth, 0, 0, 0, 0, 0, 0, 0, 0 )
				end

				update	bn_pf_EmpWorking 
				set		EmployeeCont=Round((case when @PFEmployeeContribution<0 then @IPMPFEmployee+@PFEmployeeContribution else @PFEmployeeContribution end ), @DecimalPlaces),
						EmployerCont=Round((case when @PFEmployerContribution<0 then @IPMPFEmployer+@PFEmployerContribution else @PFEmployerContribution end ), @DecimalPlaces)
				where	EmployeeIndex=@EmployeeIndex and PayrollMonth=@FSProcMonth


				set @TotalPFEmployer = @TotalPFEmployer + @PFEmployerContribution
				set @TotalPFEmployee = @TotalPFEmployee + @PFEmployeeContribution

			end

			else
			begin
				set @PFEmployerContribution = 0
				set @PFEmployeeContribution = 0

				update	fs_Master
				set		PFDayAdj = @PFEmployerContribution + @PFEmployeeContribution--,
						--SALDayAdj = (@MonthlySalary / convert(float,day( dateadd(dd,-1, dateadd(mm,1,@FSMonth))  )) * @SAD)
				where	FSIndex = @FSIndex

			end

			update	fs_Master
			set		SalMonthAdj= isnull(SalMonthAdj,0),
					SalDayAdj = isnull(SalDayAdj,0),
					SalAmount = isnull(SalDayAdj,0) + isnull(SalMonthAdj,0)
			where	FSIndex = @FSIndex

--alter table FS_Master add PFMonthAdj float, PFDayAdj float
--alter table FS_MasterOther add PFMonthAdj float, PFDayAdj float
			
			-----------------------------------------------------------------------------------------------------------
			--- hardcoded codition placed by Umair/Zeeshan 12-Jun-2023, it should be replaced with proper condition ---
			if @ClientIndex=530 -- Ontex - Decibel502
			begin
				if @TotalPFEmployee<0
					set @TotalPFEmployee=0
				if @TotalPFEmployer<0
					set @TotalPFEmployer=0
			end
			--- hardcoded codition placed by Umair/Zeeshan 12-Jun-2023, it should be replaced with proper condition ---
			-----------------------------------------------------------------------------------------------------------

			Declare @FSDAmount float = (Select Amount from FS_Detail where FSIndex = @FSIndex and ColumnCode in (184))
			Declare @FSDOAmount float = (Select Amount from FS_DetailOther where FSIndex = @FSIndex and ColumnCode in (184))
			
			if ((Round(@FSDAmount,0) = Round(@FSDOAmount,0)) or Round(@FSDAmount,0) <> Round(@TotalPFEmployee,0))
				begin
					delete from FS_DetailOther where FSIndex = @FSIndex and ColumnCode in (183,184)

					update	fs_MasterOther
					set		PFDayAdj = (case when (@SAD - isnull(@DaysDeduction,0) + isnull(@DaysAddition,0))<>0 then @PFEmployerContribution + @PFEmployeeContribution else 0 end)--,
							--PFAmount = @PFAmount
					where	FSIndex = @FSIndex
					
					insert into FS_DetailOther (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select	@FSIndex, ic.ColumnCode, round(@TotalPFEmployer,0), null, cid.ColumnType, ic.IncomeTaxApply
					from	fnInvoiceColumn(@ClientIndex) ic, ClientInvDetail cid 
					where	ic.ColumnCode = 183
							and ic.ColumnCode = cid.ColumnCode
							and cid.InvoiceNo = @InvoiceNo
							and cid.ClientIndex = @ClientIndex

					insert into FS_DetailOther (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select	@FSIndex, ic.ColumnCode, round(@TotalPFEmployee,0), null, cid.ColumnType, ic.IncomeTaxApply
					from	fnInvoiceColumn(@ClientIndex) ic, ClientInvDetail cid 
					where	ic.ColumnCode = 184
							and ic.ColumnCode = cid.ColumnCode
							and cid.InvoiceNo = @InvoiceNo
							and cid.ClientIndex = @ClientIndex
					-- Murtaza 3 Nov 2020--
					set @FSDOAmount = @TotalPFEmployer

					-- Zeeshan 2023-12-02 >>>>>
					if not exists (select * from bn_pf_EmpWorking where EmployeeIndex=@EmployeeIndex and PayrollMonth=@FSProcMonth)
					begin
						insert into bn_pf_EmpWorking ( EmployeeIndex, PayrollMonth, EmployerCont, EmployeeCont, EmployerInt, EmployeeInt, WithdrawlPermanent, WithdrawlTemporary, WithdrawlRecovery, AccumulatedBalnace ) 
						values ( @EmployeeIndex, @FSProcMonth, 0, 0, 0, 0, 0, 0, 0, 0 )
					end
				-- Zeeshan 2023-12-02 <<<<<

					update	bn_pf_EmpWorking 
					set		EmployeeCont=Round(@FSDOAmount, @DecimalPlaces),
							EmployerCont=Round(@FSDOAmount, @DecimalPlaces)
					where	EmployeeIndex=@EmployeeIndex and PayrollMonth= @FSProcMonth --dateadd(mm,@mn,@UnpaidDate)
					-- Murtaza 3 Nov 2020--		
				end
			
			
			delete from FS_Detail where FSIndex = @FSIndex and ColumnCode in (183,184)

			insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
			select	@FSIndex, ic.ColumnCode, round(@TotalPFEmployer,0), null, cid.ColumnType, ic.IncomeTaxApply
			from	fnInvoiceColumn(@ClientIndex) ic, ClientInvDetail cid 
			where	ic.ColumnCode = 183
					and ic.ColumnCode = cid.ColumnCode
					and cid.InvoiceNo = @InvoiceNo
					and cid.ClientIndex = @ClientIndex

			insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
			select	@FSIndex, ic.ColumnCode, round(@TotalPFEmployee,0), null, cid.ColumnType, ic.IncomeTaxApply
			from	fnInvoiceColumn(@ClientIndex) ic, ClientInvDetail cid 
			where	ic.ColumnCode = 184
					and ic.ColumnCode = cid.ColumnCode
					and cid.InvoiceNo = @InvoiceNo
					and cid.ClientIndex = @ClientIndex
			
			-- Murtaza 3 Nov 2020--
			if Round(@FSDAmount,0) <> Round(@FSDOAmount,0)
			Begin
				update	bn_pf_EmpWorking 
					set		EmployeeCont=Round(@FSDOAmount, @DecimalPlaces),
							EmployerCont=Round(@FSDOAmount, @DecimalPlaces)
					where	EmployeeIndex=@EmployeeIndex and PayrollMonth=@FSProcMonth --dateadd(mm,@mn,@UnpaidDate)
			End
			-- Murtaza 3 Nov 2020--
		end

		else
			begin
				
				if not exists (select * from FS_Detail where FSIndex = @FSIndex and ColumnCode in (183,184) )
				
				Begin
						insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
						select	@FSIndex, ic.ColumnCode, 0, null, cid.ColumnType, ic.IncomeTaxApply
						from	fnInvoiceColumn(@ClientIndex) ic, ClientInvDetail cid 
						where	ic.ColumnCode = 183
								and ic.ColumnCode = cid.ColumnCode
								and cid.InvoiceNo = @InvoiceNo
								and cid.ClientIndex = @ClientIndex

						insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
						select	@FSIndex, ic.ColumnCode, 0, null, cid.ColumnType, ic.IncomeTaxApply
						from	fnInvoiceColumn(@ClientIndex) ic, ClientInvDetail cid 
						where	ic.ColumnCode = 184
								and ic.ColumnCode = cid.ColumnCode
								and cid.InvoiceNo = @InvoiceNo
								and cid.ClientIndex = @ClientIndex
				End

				
				if not exists (select * from FS_DetailOther where FSIndex = @FSIndex and ColumnCode in (183,184) )
				
				Begin				
						insert into FS_DetailOther (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
						select	@FSIndex, ic.ColumnCode, 0, null, cid.ColumnType, ic.IncomeTaxApply
						from	fnInvoiceColumn(@ClientIndex) ic, ClientInvDetail cid 
						where	ic.ColumnCode = 183
								and ic.ColumnCode = cid.ColumnCode
								and cid.InvoiceNo = @InvoiceNo
								and cid.ClientIndex = @ClientIndex

						insert into FS_DetailOther (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
						select	@FSIndex, ic.ColumnCode, 0, null, cid.ColumnType, ic.IncomeTaxApply
						from	fnInvoiceColumn(@ClientIndex) ic, ClientInvDetail cid 
						where	ic.ColumnCode = 184
								and ic.ColumnCode = cid.ColumnCode
								and cid.InvoiceNo = @InvoiceNo
								and cid.ClientIndex = @ClientIndex
				End
				
			end

		set @ColumnType=0
		select @ColumnType=ColumnType from ClientInvDetail where ColumnCode=57 and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo

		If @ColumnType = 10 Or @ColumnType = 8
		begin
		
			--------------------
			-- Refresh Values -- 
			delete from FS_Detail where FSIndex = @FSIndex and ColumnCode=57
			delete from FS_DetailOther where FSIndex = @FSIndex and ColumnCode=57 --Change by murtaza, 20-Nov-19
			declare @FSZakat float
			declare @FSoDeduction float
			set @FSZakat=0
			set @FSoDeduction=0

			select @FSZakat = isnull(Amount,0) from bn_pf_FSDeduction where EmployeeIndex=@EmployeeIndex and FSDeductionType=1
			select @FSoDeduction = isnull(Amount,0) from bn_pf_FSDeduction where EmployeeIndex=@EmployeeIndex and FSDeductionType=2

--select * from bn_pf_FSDeduction

			------- Start Add by Aziz 01/07/2016 -------------------------------------------------------------------
			--if exists (select * from bn_pf_FSDeduction where EmployeeIndex=@EmployeeIndex  and FSDeductionType=1)
			--Begin
			--	select @FSZakat = isnull(Amount,0) from bn_pf_FSDeduction where EmployeeIndex=@EmployeeIndex and FSDeductionType=1
			--End

			--if exists (select * from bn_pf_FSDeduction where EmployeeIndex=@EmployeeIndex  and FSDeductionType=2)
			--Begin
			--	select @FSoDeduction = isnull(Amount,0) from bn_pf_FSDeduction where EmployeeIndex=@EmployeeIndex and FSDeductionType=2
			--End 
			------- End Add by Aziz 01/07/2016 ---------------------------------------------------------------------


			if @PayrollType=2
				begin
					select	@PFAmount = isnull ( sum ( round(isnull(ew.EmployeeContEnc,0),0)+round(isnull(ew.EmployerContEnc,0),0)+round(isnull(ew.EmployeeIntEnc,0),0)+round(isnull(ew.EmployerIntEnc,0),0)-round(isnull(ew.WithdrawlPermanentEnc,0),0)-round(isnull(ew.WithdrawlTemporaryEnc,0),0)+round(isnull(ew.WithdrawlRecoveryEnc,0),0) )-ROUND(@FSZakat,0)-ROUND(@FSoDeduction,0), 0)
					from	bn_pf_VwEmpWorking ew 
					where	EmployeeIndex=@EmployeeIndex

					insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select @FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@PFAmount,0))), @ColumnType, ic.IncomeTaxApply
					from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=57

					--Change by murtaza, 20-Nov-19
					insert into FS_DetailOther (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select @FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@PFAmount,0))), @ColumnType, ic.IncomeTaxApply
					from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=57
				end
			else 
				begin


					select	@PFAmount = isnull ( sum ( isnull(ew.EmployeeCont,0)+isnull(ew.EmployerCont,0)+isnull(ew.EmployeeInt,0)+isnull(ew.EmployerInt,0)-isnull(ew.WithdrawlPermanent,0)-isnull(ew.WithdrawlTemporary,0)+isnull(ew.WithdrawlRecovery,0) )-ROUND(ISNULL(@FSZakat,0),0)-ROUND(ISNULL(@FSoDeduction,0),0), 0)
					from	bn_pf_EmpWorking ew 
					where	EmployeeIndex=@EmployeeIndex

					insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select @FSIndex, ic.ColumnCode, round(@PFAmount,0), null, @ColumnType, ic.IncomeTaxApply
					from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=57

					--Change by murtaza, 20-Nov-19
					insert into FS_DetailOther (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select @FSIndex, ic.ColumnCode, round(@PFAmount,0), null, @ColumnType, ic.IncomeTaxApply
					from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=57
				end

			Update bn_pf_EmpWorking Set
				FSAmount = @PFAmount,
				ZakatDeduction = @FSZakat
			Where EmployeeIndex = @EmployeeIndex and PayrollMonth = @FSProcMonth

			-- Refresh Values -- 
			--------------------


			-- For Taxation start 19 Aug 2014
				
				
				set @pDate = LTrim(str(@PayrollMonth)) + '/1/' + LTrim(str(@PayrollYear))
				If @PayrollMonth < 7 
					begin
					set @sDate = '7/1/' + LTrim(str(@PayrollYear - 1))
					set @eDate = '7/1/' + LTrim(str(@PayrollYear))
					end
				Else
					begin
					set @sDate = '7/1/' + LTrim(str(@PayrollYear))
					set @eDate = '7/1/' + LTrim(str(@PayrollYear + 1))
					end

			-------------------------------------------------------------------------------
			-------------------------- Murtaza 25 Oct 2020 --------------------------------

			Declare @PFExemptAmount int = 150000
			------------- Murtaza 12 Jan 2021 ---------------

			if isnull(@BasicPercent,0) = 0
				Begin
					select	@BasicPercent=(case when pf.BasicPercent=-1 then isnull(pfs.PFPercent,0) else pf.BasicPercent end)
						
					from	ClientPlanPF pf left outer join ClientPlanPFSlab pfs
							on pf.ClientIndex=pfs.ClientIndex 
							and datediff(mm, @DOJ, @LPayrollDate) between pfs.MonthFrom and pfs.MonthTo

					where	pf.ClientIndex=@ClientIndex
			
					if exists (select * from ClientPlanPF where ClientIndex = @ClientIndex)
						select @RBCType = ISNULL(RBCType,1) from ClientPlanPF where ClientIndex = @ClientIndex
				
				
					if @RBCType = 3		
						begin
							if exists (select * from bn_RetirementBenefitMemberShip where EmployeeIndex  = @EmployeeIndex and StartDate <> '1900-01-01 00:00:00.000' )
								select @PFStartDate = StartDate from bn_RetirementBenefitMemberShip where EmployeeIndex  = @EmployeeIndex
							else	
								begin
									--set @PFStartDate = '1/1/3000'
									set @BasicPercent = 0
								end
						end
			
					if exists (select * from ClientPlanPFWL where clientindex=@ClientIndex)
						begin
							select	@BasicPercent = (case when pf.BasicPercent=-1 then isnull(pfs.PFPercent,0) else pf.BasicPercent end)
							
							from VwEmpWL ewl 
										inner join ClientPlanPFWL pf on ewl.WorkLocation = pf.workLocation and ewl.WorkLocationIndex = pf.WorkLocationIndex 
										left outer join ClientPlanPFSlabWL pfs on pf.ClientIndex=pfs.ClientIndex 
													and datediff(mm, @DOJ, @LPayrollDate) between pfs.MonthFrom and pfs.MonthTo 
													and ewl.WorkLocationIndex=pfs.WorkLocationIndex 
													and ewl.WorkLocation=pfs.WorkLocation 
							where pf.ClientIndex=@ClientIndex and ewl. employeeindex=@EmployeeIndex 
						end
				
				End
			------------- Murtaza 12 Jan 2021 ---------------

			if ISNULL(@BasicPercent,0) > 10
				begin
					IF OBJECT_ID('tempdb.dbo.#FiscalYearP', 'U') IS NOT NULL
							DROP TABLE #FiscalYearP; 

					IF OBJECT_ID('tempdb.dbo.#FiscalYearFS', 'U') IS NOT NULL
							DROP TABLE #FiscalYearFS; 
     
					IF OBJECT_ID('tempdb.dbo.#AnnualBasicP', 'U') IS NOT NULL
							DROP TABLE #AnnualBasicP; 

					IF OBJECT_ID('tempdb.dbo.#AnnualBasicFS', 'U') IS NOT NULL
							DROP TABLE #AnnualBasicFS;        

					select SNo, MONTH(FromDate) PayrollMonth, Year(FromDate) PayrollYear,FromDate P_Date,0 Amount into #FiscalYearP from dbo.fnDateRangeBreakup('m',@sDate,@UnpaidDate,0)

					select	f.SNo,
							f.PayrollMonth,
							f.PayrollYear,
							ISNULL(ipm.Amount + ISNULL(ad.PayrollAdjustment,0),fx.FixAmount) Amount

					into	#AnnualBasicP

					from	Employee e, 
							(select * from #FiscalYearP) f 
							left join vwIPm ipm on ipm.EmployeeIndex = @EmployeeIndex and ipm.ColumnCode = 142 and ipm.PayrollMonth = f.PayrollMonth and ipm.Payrollyear = f.PayrollYear
							left join EmpDetailFixAmountRevision ad on ipm.IndividualPayrollIndex = ISNULL(ad.Individualpayrollindex,0) and ad.ColumnCode = ipm.ColumnCode
							left join EmpDetailFixAmount fx on fx.EmployeeIndex = @EmployeeIndex and fx.ColumnCode = 142
					where	e.EmployeeIndex = @EmployeeIndex
							and e.ServiceStartDate <= DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, P_Date ) + 1, 0)) 


					select SNo, MONTH(FromDate) PayrollMonth, Year(FromDate) PayrollYear,FromDate P_Date,0 Amount into #FiscalYearFS from dbo.fnDateRangeBreakup('m',@sDate,@eDate,0)

					select	f.SNo,
							f.PayrollMonth,
							f.PayrollYear,
							--ISNULL(ipm.Amount,fx.FixAmount) Amount
							ISNULL(fsd.Amount,0) Amount

					into	#AnnualBasicFS

					from	Employee e, 
							(select * from #FiscalYearFS) f 
							left join FS_Master fsm on fsm.EmployeeIndex = @EmployeeIndex and fsm.PayrollMonth = f.PayrollMonth and fsm.Payrollyear = f.PayrollYear
							left join FS_Detail fsd on fsm.FSIndex = fsd.FSIndex and fsd.ColumnCode = 142
					where	e.EmployeeIndex = @EmployeeIndex
							and e.ServiceStartDate <= DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, P_Date ) + 1, 0)) 

					select @PFExemptAmount = (case when SUM(Amount)*0.10 < @PFExemptAmount then Round(SUM(Amount)*0.10,0) else @PFExemptAmount end) from 
					(
						select Amount from #AnnualBasicP where Amount <> 0
						union all
						select ((Amount*@SAM) + (Amount / convert(float,day( dateadd(dd,-1, dateadd(mm,1,@FSMonth))  )) * (@SAD - @DaysDeduction + @DaysAddition))) Amount from #AnnualBasicFS where Amount <> 0
					) t

				end
	
			-------------------------- Murtaza 25 Oct 2020 --------------------------------
			-------------------------------------------------------------------------------
				
				select @PFEmployer=isnull(SUM(EmployerCont),0) 
					from bn_pf_EmpWorking 
					where EmployeeIndex=@EmployeeIndex
						and PayrollMonth between @sDate and @eDate
				
				delete from Tx_OtherIncome where IncomeType=8 
					and EmployeeIndex=@EmployeeIndex	
					and PayrollMonth between @sDate and @eDate
				
				if @PFEmployer>@PFExemptAmount -- Murtaza 25 Oct 2020
				begin
					insert into Tx_OtherIncome
						(EmployeeIndex,SerialNo,PayrollMonth,IncomeType,Amount,EnteredDate,EntryBy,Remarks)
					select	@EmployeeIndex,ISNULL(MAX(serialno)+1,1),@pDate,8
							,@PFEmployer-@PFExemptAmount -- Murtaza 25 Oct 2020
							,GETDATE(),@UserIndex,'System Generated - FS PF Notional Value' 
						from	Tx_OtherIncome
						where	EmployeeIndex=@EmployeeIndex
				end
					
			-- For Taxation start 19 Aug 2014



			if @ColumnType=8
				set @PFAmount=0

		end
		-- Get Payable PF Amount --
		---------------------------

		---------------------------------------------------
		------------ Emp PF profit on FS ------------------
		----------- Muhib --- 18 Nov 2021 -----------------
		begin
			if exists (select * from ClientInvFS where ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo and ISNULL(isEmpPFProfitOnFS,0) = 1)
				begin
					Declare @EmpProfitOnFS int
					Declare @ClientPF smallint
					Declare @ExpenseIndex int
					Declare @GLMIndex int

					select @ClientPF = PFAccount from Clientmaster where Clientindex = @ClientIndex

					if exists (select * from bn_pf_Expense where employeeindex = @EmployeeIndex and ExpenseType = 4)
						begin
							select @ExpenseIndex = ExpenseIndex from bn_pf_Expense where employeeindex = @EmployeeIndex and ExpenseType = 4
							select @GLMIndex = GLMIndex from bn_pf_ExpenseHistory where employeeindex = @EmployeeIndex and GLMIndex is not null and ExpenseStatus = 2
							exec bn_Pf_ProfitOnFS_UnPost @ExpenseIndex, @GLMIndex, @UserIndex
						end

					exec bn_Pf_EmpProfitOnFSCalculate @EmployeeIndex , @EmpProfitOnFS out

					exec bn_pf_ProfitOnFSAdd 0, @ClientPF, 4, @FSMonth, @EmpProfitOnFS, 'System Generated Profit', @UserIndex, @EmployeeIndex
					
					select @ExpenseIndex = MAX(ExpenseIndex) from bn_pf_Expense where employeeindex = @EmployeeIndex and ExpenseType = 4 and ExpenseStatus = 1

					exec bn_pf_ProfitOnFSPost @ExpenseIndex, @UserIndex
				end
		end
		----------- Muhib --- 18 Nov 2021 -----------------
		------------ Emp PF profit on FS ------------------
		---------------------------------------------------
		

		---------------------------------------------------------
		------------------ Muhib 7 Oct 2019 ---------------------
		begin
		
			  --//////////////////////////
				--/// Calculate EOBI 111 ///
				declare @EmployerContribution As float, @EOBIEmployer As float
				Declare @FSDEOBIAmount AS float,  @FSDOEOBIAmount AS float

			    select @IgnoreJLAdj = isnull(IgnoreJLAdj,0) from ClientInv where ClientIndex = @ClientIndex and InvoiceNo = @InvoiceNo 
			    
				set @ColumnType=0
				select @ColumnType=columntype 
						 , @DecimalPlaces=isnull(DecimalPlaces,0)				
				from clientinvdetail where columncode in (111) and clientindex=@ClientIndex and invoiceno=@InvoiceNo 
			            
				If @ColumnType = 10 Or @ColumnType = 9 Or @ColumnType = 8 
				begin
					select @EmployerContribution = employercontribution from eobi where @LPayrollDate between fromdate and todate 
					select @EmployerContribution = employercontribution from ClientEOBI where @LPayrollDate between fromdate and todate and clientindex=@ClientIndex
					select @EmployerContribution = employercontribution from ClientProvinceEOBI where clientindex=@ClientIndex and InvoiceNo = @InvoiceNo and ProvinceIndex = @ProvinceIndex --Murtaza 28 Dec 2022

					set @EOBIEmployer = @EmployerContribution


					--//////////////////////////////////////
					--/// EOBI Calculation Pro-Rate Basis///
			        
					if @IgnoreJLAdj = 0 
					begin
						if exists (select * from clientplan where isnull(CalculateEOBIArrears,0)=1 and clientindex=@ClientIndex)
						begin
							If @a_Months > 0 
								set @EOBIEmployer = @EOBIEmployer + (@EmployerContribution * @a_Months)
				        
							If @a_Days > 0 
							begin
								set @EOBIEmployer = @EOBIEmployer + Round(((@EmployerContribution / @mMaxJDays) * @a_Days), 0)
							end
						end
						If @j_Days > 0 
							set @EOBIEmployer = Round((@EmployerContribution / @mMaxDays) * @j_Days, 0)
				        
						If @l_Days > 0 
							set @EOBIEmployer = Round((@EmployerContribution / @mMaxDays) * @l_Days, 0)
				               
						If @l_Days > 0 and @j_Days > 0 
							set @EOBIEmployer = Round((@EmployerContribution*1.0 / @mMaxDays) * ((@l_Days+1)-@jDay), 0)
					end      
			        
					--EOBI Dynamic Columns For less EOBI 
					if exists (select * from ClientInvEOBI where ColumnType in (5) and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo)
						begin
						declare @EOBILessDays smallint
						set @EOBILessDays =0
						
						if @PayrollType=2
							begin
								select  @EOBILessDays = 0
								--select @EOBILessDays=@EOBILessDays - SUM( EncAmount ) 
								--from FS_Detail 
								--where	FSIndex=@FSIndex
								--and ColumnCode in (select ColumnCode from ClientInvEOBI where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnType = 5 ) 
							end
						else
							begin
								select @EOBILessDays=@EOBILessDays - SUM( isnull(fsdo.Amount,fsd.Amount)) 
								from FS_Detail fsd left join FS_DetailOther fsdo on fsd.FSIndex = fsdo.FSIndex and fsd.ColumnCode = fsdo.ColumnCode
								where	fsd.FSIndex=@FSIndex
								and fsd.ColumnCode in (select ColumnCode from ClientInvEOBI where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnType = 5 ) 
							end
							
						set @EOBIEmployer = @EOBIEmployer + (((@EmployerContribution*1.0) / (@mMaxDays*1.0)) * @EOBILessDays*1.0)
						end
					--EOBI Dynamic Columns For less EOBI
			        
			
					--/// EOBI Calculation Pro-Rate Basis///
					--//////////////////////////////////////
			        
			       
					If (@Gender<>'F' and @AgeInDays > (365 * 60) + 15) or (@Gender='F' and @AgeInDays > (365 * 55) + 14) --or (@EmployeeIndex=139020) 
						set @EOBIEmployer = 0
			        
					if @EOBIEmployer<0
        				begin
							set @SQLString='Negative EOBI Not Allowed -  Column Code (111) Amount [' + str(@EmployeeIndex) + ']'
							raiserror (@SQLString, 16,1)
							return
						end


					if exists ( select * from EmpFixColumn where EmployeeIndex=@EmployeeIndex and columncode=111)
					begin
						select @EOBIEmployer = amount from EmpFixColumn where EmployeeIndex=@EmployeeIndex and columncode=111
					end
			        
					--////////////////////////////////////////
					--/// Refresh Existing Column's Amount ///
					set @FSDEOBIAmount = (Select Amount from FS_Detail where FSIndex = @FSIndex and ColumnCode in (111))
					set @FSDOEOBIAmount = (Select Amount from FS_DetailOther where FSIndex = @FSIndex and ColumnCode in (111))

					if ((Round(@FSDEOBIAmount,0) = Round(@FSDoEOBIAmount,0)) or Round(@FSDEOBIAmount,0) <> Round(@EOBIEmployer,0))
					Begin
						delete from FS_DetailOther where FSIndex = @FSIndex and columncode = 111  
						
						if @PayrollType=2
							insert into FS_DetailOther (FSIndex, columncode, amount, encamount, ColumnType, IncomeTaxApply ) 
							select @FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@EOBIEmployer,2) )), @ColumnType, ic.IncomeTaxApply  
							from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=111
						else
							insert into FS_DetailOther (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
							select @FSIndex, ic.ColumnCode, round(@EOBIEmployer,@DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply
							from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=111
							
					End


					delete from FS_Detail where FSIndex = @FSIndex and columncode = 111  

					if @PayrollType=2
						insert into FS_Detail (FSIndex, columncode, amount, encamount, ColumnType, IncomeTaxApply ) 
						select @FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@EOBIEmployer,2) )), @ColumnType, ic.IncomeTaxApply  
						from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=111
					else
						insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
						select @FSIndex, ic.ColumnCode, round(@EOBIEmployer,@DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply
						from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=111


						
					--/// Refresh Existing Column's Amount ///
					--////////////////////////////////////////
				End
				--/// Calculate EOBI 111 ///
				--//////////////////////////





				--//////////////////////////
				--/// Calculate EOBI 106 ///
				declare @EmployeeContribution As float, @EOBIEmployee As float
			    
				set @ColumnType=0
				select @ColumnType=columntype 
						, @DecimalPlaces=isnull(DecimalPlaces,0)
				from clientinvdetail where columncode = 106 and clientindex=@ClientIndex and invoiceno=@InvoiceNo 
			            
				If @ColumnType = 10 Or @ColumnType = 9 Or @ColumnType = 8 
				begin
					select @EmployeeContribution = employeecontribution from eobi where @LPayrollDate between fromdate and todate				--to be discuss
					select @EmployeeContribution = employeecontribution from ClientEOBI where @LPayrollDate between fromdate and todate and ClientIndex=@ClientIndex
					select @EmployeeContribution = employeecontribution from ClientProvinceEOBI where clientindex=@ClientIndex and InvoiceNo = @InvoiceNo and ProvinceIndex = @ProvinceIndex --Murtaza 28 Dec 2022
					set @EOBIEmployee = @EmployeeContribution


					if @IgnoreJLAdj =0 
					begin
						if exists (select * from clientplan where isnull(CalculateEOBIArrears,0)=1 and clientindex=@ClientIndex)
						begin
							If @a_Months > 0
								set @EOBIEmployee = @EOBIEmployee + (@EmployeeContribution*1.0 * @a_Months)
							If @a_Days > 0 
								set @EOBIEmployee = @EOBIEmployee + Round(((@EmployeeContribution*1.0 / @mMaxJDays) * @a_Days), 0)
						end
						If @j_Days > 0
							set @EOBIEmployee = Round((@EmployeeContribution*1.0 / @mMaxDays) * @j_Days, 0)
						If @l_Days > 0 
							set @EOBIEmployee = Round((@EmployeeContribution*1.0 / @mMaxDays) * @l_Days, 0)
						If @l_Days > 0 and @j_Days > 0 
							set @EOBIEmployee = Round((@EmployeeContribution*1.0 / @mMaxDays) * ((@l_Days+1)-@jDay), 0)
					end
				             
					--EOBI Dynamic Columns For less EOBI 
					if exists (select * from ClientInvEOBI where ColumnType in (5) and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo)
						begin
						set @EOBILessDays =0
						if @PayrollType=2
							begin
								select  @EOBILessDays = 0
								--select @EOBILessDays=@EOBILessDays - SUM( EncAmount ) 
								--from FS_Detail 
								--where	FSIndex = @FSIndex
								--and ColumnCode in (select ColumnCode from ClientInvEOBI where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnType = 5 ) 
							end
						else
							begin
								select @EOBILessDays=@EOBILessDays - SUM( isnull(fsdo.Amount,fsd.Amount)) 
								from FS_Detail fsd left join FS_DetailOther fsdo on fsd.FSIndex = fsdo.FSIndex and fsd.ColumnCode = fsdo.ColumnCode
								where	fsd.FSIndex=@FSIndex
								and fsd.ColumnCode in (select ColumnCode from ClientInvEOBI where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo and ColumnType = 5 )  
							end
						
						set @EOBIEmployee = @EOBIEmployee + (((@EmployeeContribution*1.0) / (@mMaxDays*1.0)) * @EOBILessDays*1.0)
						end
					--EOBI Dynamic Columns For less EOBI
			        
					If (@Gender<>'F' and @AgeInDays > (365 * 60) + 15) or (@Gender='F' and @AgeInDays > (365 * 55) + 14)  or (@EmployeeIndex=139020)
						set @EOBIEmployee = 0
			        
			      
					if @EOBIEmployee<0
        				begin
							set @SQLString='Negative EOBI Not Allowed -  Column Code (106) Amount [' + str(@EmployeeIndex) + ']'
							raiserror (@SQLString, 16,1)
							return
						end

					if exists ( select * from EmpFixColumn where EmployeeIndex=@EmployeeIndex and columncode=106)
					begin
						select @EOBIEmployee = amount from EmpFixColumn where EmployeeIndex=@EmployeeIndex and columncode=106
					end
					
					--////////////////////////////////////////
					--/// Refresh Existing Column's Amount ///
					set @FSDEOBIAmount = (Select Amount from FS_Detail where FSIndex = @FSIndex and ColumnCode in (106))
					set @FSDOEOBIAmount = (Select Amount from FS_DetailOther where FSIndex = @FSIndex and ColumnCode in (106))

					if ((Round(@FSDEOBIAmount,0) = Round(@FSDoEOBIAmount,0)) or Round(@FSDEOBIAmount,0) <> Round(@EOBIEmployee,0))
					Begin
						delete from FS_DetailOther where FSIndex = @FSIndex and columncode=106  
						
						if @PayrollType=2
							insert into FS_DetailOther (FSIndex, columncode, amount, encamount, ColumnType, IncomeTaxApply ) 
							select @FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@EOBIEmployee,2) )), @ColumnType, ic.IncomeTaxApply  
							from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=106
						else
							insert into FS_DetailOther (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
							select @FSIndex, ic.ColumnCode, round(@EOBIEmployee,@DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply
							from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=106

					End
						delete from FS_Detail where FSIndex = @FSIndex and columncode=106  
						
						if @PayrollType=2
							insert into FS_Detail (FSIndex, columncode, amount, encamount, ColumnType, IncomeTaxApply ) 
							select @FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@EOBIEmployee,2) )), @ColumnType, ic.IncomeTaxApply  
							from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=106
						else
							insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
							select @FSIndex, ic.ColumnCode, round(@EOBIEmployee,@DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply
							from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=106
					--/// Refresh Existing Column's Amount ///
					--////////////////////////////////////////
					
				End
				--/// Calculate EOBI ///
				--//////////////////////
		end
		------------------ Muhib 7 Oct 2019 ---------------------
		---------------------------------------------------------
		
		--------------------------------
		-- Get Payable Pension Amount --
		-- Nabeel 28 Apr 2014  ---------
		set @ColumnType=0
		select @ColumnType=ColumnType from ClientInvDetail where ColumnCode=65 and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo

		If @ColumnType = 10 Or @ColumnType = 8
		begin
		
			--------------------
			-- Refresh Values -- 
			delete from FS_Detail where FSIndex = @FSIndex and ColumnCode=65
			declare @pnFSZakat float
			declare @pnFSoDeduction float
			set @pnFSZakat=0
			set @pnFSoDeduction=0
			
			select @pnFSZakat = isnull(Amount,0) from bn_pension_FSDeduction where EmployeeIndex=@EmployeeIndex and FSDeductionType=1
			select @pnFSoDeduction = isnull(Amount,0) from bn_pension_FSDeduction where EmployeeIndex=@EmployeeIndex and FSDeductionType=2
			
			if @PayrollType=2
				begin
					select	@PensionAmount = isnull ( sum ( round(isnull(ew.EmployeeContEnc,0),0)+round(isnull(ew.EmployerContEnc,0),0)+round(isnull(ew.EmployeeIntEnc,0),0)+round(isnull(ew.EmployerIntEnc,0),0)-round(isnull(ew.WithdrawlPermanentEnc,0),0)-round(isnull(ew.WithdrawlTemporaryEnc,0),0)+round(isnull(ew.WithdrawlRecoveryEnc,0),0) )-ROUND(@FSZakat,0)-ROUND(@FSoDeduction,0), 0)
					from	bn_pension_VwEmpWorking ew 
					where	EmployeeIndex=@EmployeeIndex

					insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select @FSIndex, ic.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),round(@PensionAmount,0))), @ColumnType, ic.IncomeTaxApply
					from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=65
				end
			else 
				begin
					select	@PensionAmount = isnull ( sum ( isnull(ew.EmployeeCont,0)+isnull(ew.EmployerCont,0)+isnull(ew.EmployeeInt,0)+isnull(ew.EmployerInt,0)-isnull(ew.WithdrawlPermanent,0)-isnull(ew.WithdrawlTemporary,0)+isnull(ew.WithdrawlRecovery,0) )-ROUND(@FSZakat,0)-ROUND(@FSoDeduction,0), 0)
					from	bn_pension_EmpWorking ew 
					where	EmployeeIndex=@EmployeeIndex

					insert into FS_Detail (FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply )
					select @FSIndex, ic.ColumnCode, round(@PensionAmount,2), null, @ColumnType, ic.IncomeTaxApply
					from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=65
				end
			-- Refresh Values -- 
			--------------------


			if @ColumnType=8
				set @PensionAmount=0

		end
		-- Get Payable Pension Amount --
		--------------------------------

		--------------------------
		-- Gratuity Calculation --
		declare @ProrateType tinyint, @YearCap float, @GratuityAmount decimal(12,2), @IsFundedGratuity bit
				,@OldGratuityAmount  decimal(12,2)--, @DOJ datetime, @DOL datetime
				
		set @OldGratuityAmount=0
		
		select	@GratuityAdjustment = e.OldGratuityPaid,
				@lmMaxDays = day(dateadd(dd,-1,dateadd(mm,1,LTRIM(str(month(serviceenddate))) + '/1/' + LTRIM(str(year(serviceenddate)))))),
				@DOJ= e.ServiceStartDate,
				@DOL = e.ServiceEndDate
		from	VwEmpGratuity e, clientmaster cm 
		Where	e.clientindex=cm.clientindex and e.EmployeeIndex = @EmployeeIndex


		--select	@d=dd, 
		--		@m=mm, 
		--		@y=yyyy 
		--from	dbo.fnDateDiff(@DOJ, @DOL )
		select	@d=dd, 
				@m=mm, 
				@y=yyyy,
				@SPM = ISNULL(yyyy,0) * 12 +  mm			--Muhib ----Oct 28 2021
		from	dbo.fnServicePeriod(@EmployeeIndex)

		
		--Set @ServicePeriod='Year(s): ' + ltrim(str(@y)) + ', Month(s): ' + ltrim(str(@m)) + ', Day(s): ' + ltrim(str(@d)) 
		select @ServicePeriod = dbo.fnEmployeeServicePeriod(@EmployeeIndex)
		
		select	@GSal = ISNULL(SUM(FixAmount),0) 
		From	GratuityColumn gc, EmpDetailFixAmount fa
		where	gc.ClientIndex = @ClientIndex 
				and gc.ColumnCode = fa.ColumnCode 
				and fa.EmployeeIndex = @EmployeeIndex

	
		select @GSal gsal, @BSal bsal, @GR GR, 
		@Mth mth, @Dys dys, @GC gc, @y y, @m m, @d d, @ServicePeriod serviceperiod, @FSIndex FSIndex

		select @ProrateType = ProrateType From GratuityProrate where ClientIndex=@ClientIndex and @m between MonthFrom and MonthTo 
				
		If @y < 1 
			Begin
				set @y = 0
				set @m = 0
				set @d = 0
			End 
			
			
			
		if @ProrateType=1
		begin
			set @m=0
			set @d=0
		end
		if @ProrateType=2 and @m>0
		begin
			set @y = @y + 1
			set @m=0
			set @d=0
		end


-----------------------------------------------
-- start umair changes for slab wise breakup --
		--if exists (select * from clientplan where clientindex=620 and isnull(GratuityQualifyingMonth,2000)>(@y*12)+@m)
		if @ClientIndex=620 and 120 > (@y*12)+@m 
		begin
			set @y=0
			set @m=0
			set @d=0
		end



		declare @IsSeparateCal bit, @ActualGSal decimal(12,2)

		set @ActualGSal=@GSal 
		set @YearCap=0
		set @IsSeparateCal=0
		
		--select	@GSal = @GSal * Gratuity, 
		--		@YearCap=YearCap,
		--		@IsSeparateCal=ISNULL(IsSeparateCal,0)
		--from	GratuitySlab 
		--where	ClientIndex=@ClientIndex 
		--		and MonthFrom <= @y*12 and MonthTo > @y*12
		--		and (isnull(GradeArray,'')='' or isnull(GradeArray,'') like '%,' + ltrim(str(@GradeIndex)) + ',%')

		-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		--	***  Code shifted here from below by Zeeshan at 2023-08-03
		--  ***  to apply Gratuity rule on Gratuity calculation from Slabs
		------------------------------------------------------------------------
		-- For setting Gratuity Rules --
		declare @gratuityrule tinyint
		select @gratuityrule=isnull(GratuityRule,1) from ClientMaster where ClientIndex=@ClientIndex
		If @gratuityrule = 1 And @m < 6 
			Begin
			set @m = 0
			set @d = 0
			End
		If @gratuityrule = 2 
			Begin
				If @m < 6
					begin 
					set @m = 0
					set @d = 0
					End
				Else
					begin
					set @y = @y + 1
					set @m = 0
					set @d = 0
					End 
			End 
		If @gratuityrule = 4
			Begin
				set @m = 0
				set @d = 0
			End
		-----------------------------------------------------------------------
		--<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

		--------------------------------Murtaza 17 Feb 2023---------------------------------For Grade Check--------------
		if exists (
					select	Gratuity 
					from	GratuitySlab 
					where	ClientIndex=@ClientIndex 
							and MonthFrom <= @y*12 and MonthTo > @y*12
							and (isnull(GradeArray,'')='' or isnull(GradeArray,'') like '%,' + ltrim(str(@GradeIndex)) + ',%')
					)
		Begin
			select	@GSal = @GSal * Gratuity, 
					@YearCap=YearCap,
					@IsSeparateCal=ISNULL(IsSeparateCal,0)
			from	GratuitySlab 
			where	ClientIndex=@ClientIndex 
					and MonthFrom <= @y*12 and MonthTo > @y*12
					and (isnull(GradeArray,'')='' or isnull(GradeArray,'') like '%,' + ltrim(str(@GradeIndex)) + ',%')
		End
		else
		Begin
			set @GSal = 0
		End
		--------------------------------Murtaza 17 Feb 2023---------------------------------For Grade Check--------------

		--set @YearCap=0
		
		--select	@GSal = @GSal * Gratuity, 
		--		@YearCap=YearCap
		--from	GratuitySlab 
		--where	ClientIndex=@ClientIndex 
		--		and MonthFrom <= @y*12 and MonthTo > @y*12

-- end umair changes for slab wise breakup --
---------------------------------------------
		
		if @YearCap>0 and (@y>@YearCap or (@y=@YearCap and (@m>0 or @d>0)))
		begin
			set @y=@YearCap 
			set @m=0
			set @d=0
		end

		---------------------------------------------
		-- Changes By Nabeel 13 March 2012 --
		-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		--	***  Code shifted above by Zeeshan at 2023-08-03
		--  ***  to apply Gratuity rule on Gratuity calculation from Slabs
		------------------------------------------------------------------------
		---- For setting Gratuity Rules --
		--declare @gratuityrule tinyint
		--select @gratuityrule=isnull(GratuityRule,1) from ClientMaster where ClientIndex=@ClientIndex
		--If @gratuityrule = 1 And @m < 6 
		--	Begin
		--	set @m = 0
		--	set @d = 0
		--	End
		--If @gratuityrule = 2 
		--	Begin
		--		If @m < 6
		--			begin 
		--			set @m = 0
		--			set @d = 0
		--			End
		--		Else
		--			begin
		--			set @y = @y + 1
		--			set @m = 0
		--			set @d = 0
		--			End 
		--	End 
		--If @gratuityrule = 4
		--	Begin
		--		set @m = 0
		--		set @d = 0
		--	End
		-----------------------------------------------------------------------
		--<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

		--If @y < 1 
		--	Begin
		--		set @y = 0
		--		set @m = 0
		--		set @d = 0
		--	End 
		-- Changes By Nabeel 13 March 2012 --
		---------------------------------------------

		if @ClientIndex=1249
		begin
		
	    set @yAmount = Round(@GSal * @y, 0)
		set @mAmount = Round((@GSal / 12) * @m, 0)
		set @dAmount = Round((@GSal / 365) * @d, 0)

		end

		else
		begin

		set @yAmount = Round(@GSal, 0)
		set @mAmount = Round((@GSal / 12) * @m, 0)
		set @dAmount = Round((@GSal / 365) * @d, 0)
		end

-- select * from fs_master where employeeindex=102655


		if @IsSeparateCal  = 1
		begin
			select @d  d, @m m, @y y, @dAmount dAmount, @mAmount mAmount, @yAmount yAmount

			declare @slb_d int, 
					@slb_y int, 
					@slb_m int,
					@slb_dAmount  decimal(12,2), 
					@slb_yAmount  decimal(12,2), 
					@slb_mAmount  decimal(12,2) 

			exec Prl_fs_RecordUpdate_Slab  @FSIndex, @EmployeeIndex, @ClientIndex, @ActualGSal, @d, @m, @y,  @rd=@slb_d out, @rm=@slb_m out, @ry=@slb_y out, @rdAmount=@slb_dAmount out , @rmAmount=@slb_mAmount out, @ryAmount=@slb_yAmount out

			set @d = @slb_d  
			set @m = @slb_m  
			set @y = @slb_y  
			set @dAmount = @slb_dAmount  
			set @mAmount = @slb_mAmount   
			set @yAmount = @slb_yAmount  
			
			select @d  d, @m m, @y y, @dAmount dAmount, @mAmount mAmount, @yAmount yAmount
		end
	
--	select * from clientinvdetail where clientindex=882 and invoiceno=5	
--		select * from columntype		


		set @ColumnType=0
		declare @ColumnCode tinyint
		set @ColumnCode=0
		select @ColumnType = ColumnType, @ColumnCode=ColumnCode from ClientInvDetail where ColumnCode in (55,56) and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo
	
		if @ColumnType = 10 or @ColumnType = 8
			begin
				set @GratuityAmount = @dAmount + @mAmount + @yAmount - @GratuityAdjustment 
			end
		else
			set @GratuityAmount = 0
		
		
		-----------------------------------------------------------------------
		--To update a pre-assumed Gratuity Amount as per Atif Shahid if need be
		
		   
		--if @EmployeeIndex=92222      begin  set @GratuityAmount=29444    end
		 
		 
		--To update a pre-assumed Gratuity Amount as per Atif Shahid if need be
		-----------------------------------------------------------------------


		if @ColumnCode=55
			set @IsFundedGratuity = 1
		else
			set @IsFundedGratuity = 0

		delete from FS_Detail where FSIndex = @FSIndex and columncode = @ColumnCode
	
		if @PayrollType=2
			insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply)
			select @FSIndex, ic.ColumnCode, 0,encryptbykey(@KeyGUID, convert(varchar(20),@GratuityAmount)), @ColumnType, ic.IncomeTaxApply  
			from fnInvoiceColumn(@ClientIndex) ic where ic.ColumnCode=@ColumnCode
		else
			insert into FS_Detail ( FSIndex, ColumnCode, Amount, EncAmount, ColumnType, IncomeTaxApply)
			select @FSIndex, ic.ColumnCode, @GratuityAmount, null, @ColumnType, ic.IncomeTaxApply  
			from fnInvoiceColumn(@ClientIndex) ic where ic.ColumnCode=@ColumnCode

		--if @ClientIndex = 1161
		--	begin
		--		if not exists (select * from bn_RetirementBenefitMemberShip where RBType = 1 and EmployeeIndex = @EmployeeIndex)
		--			delete from FS_Detail where FSIndex = @FSIndex and columncode = @ColumnCode
		--	end

		

		-- Gratuity Calculation --
		--------------------------
		--exec [Prl_FS_Notification_RecordUpdate] 882,2019,1,5,77009,1124,165933,'',21924
		

		---------------------------------------------
		-- Get Formula Columns Of Selected Invoice --
		--declare @i as smallint, @fColumnCode char(3), @Formula varchar(5000), @tmpFormula varchar(5000)
		set @ColumnCode=0
		
		declare cur_Formula cursor for  
				select	columncode, formula, columnType, isnull(decimalplaces,2) decimalplaces
				from	clientinvdetail 
				where	Columntype in (2,6,7)
						and columncode<>8--Working for GST Calculation 08July2013 
						and clientindex=@ClientIndex  
						and invoiceno=@InvoiceNo 
				order by sortorder

		open cur_Formula
		fetch next from cur_Formula into @ColumnCode, @Formula, @ColumnType, @DecimalPlaces
		while @@FETCH_STATUS=0
		begin

			set @i=0
			set @Formula=REPLACE(@Formula, 'MTD', @lmMaxDays * 1.0) -- last service month total days
--			set @Formula=REPLACE(@Formula, 'LBSD', @LBSD * 1.0) -- last balance salary days
			set @Formula=REPLACE(@Formula, 'SAD', @SAD * 1.0) -- Salary Arrears Days since last posted Payroll
			set @Formula=REPLACE(@Formula, 'SPM', @SPM) -- Service Period in Months
			set @Formula=REPLACE(@Formula, 'GSB', @GSBGroupID) -- Emp current GSB Group ID
			set @Formula=REPLACE(@Formula, 'WDs', @WorkingDays) -- Work days
			set @Formula = REPLACE(@Formula, 'GI', @GradeIndex)
			set @Formula = REPLACE(@Formula, 'EmpSSD', '''' + Cast(@DOJ as varchar(50)) + '''')	-- Service Start Date
			set @Formula = REPLACE(@Formula, 'EmpSED', '''' + Cast(@DOL as varchar(50)) + '''') -- Service End Date
			set @Formula = REPLACE(@Formula, 'EmpAge', @EmpAgeInNumber)
			set @Formula = REPLACE(@Formula, 'EmpSY', @EmpServiceYear)
			set @Formula = REPLACE(@Formula, 'EmpSP', @EmpServicePeriodInNumber)
			set @Formula = REPLACE(@Formula, 'isPF', @isPFMember)
			set @Formula = REPLACE(@Formula, 'TerritoryIndex', @TerritoryIndex)
			set @Formula = REPLACE(@Formula, 'EmpType', @EmploymentType)

			set @Formula = REPLACE(@Formula, 'GYear', @GYear)
			set @Formula = REPLACE(@Formula, 'GMonth', @GMonth)
			set @Formula = REPLACE(@Formula, 'GDays', @GDays)


			set @tmpFormula=@Formula

			while @i<LEN(@Formula)
			begin
				set @i=charindex('A',@formula, @i)
				if @i=0 
					break
					
				set @fColumnCode =  substring(@formula, charindex('A', @formula, @i)+1,3)
				--select @fColumnCode , @tmpFormula tmpFormula

				SET @Amount=0
				if @PayrollType=2
					select @Amount = convert( decimal(12,2),CONVERT(varchar(20), decryptbykey(EncAmount))) from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
				else
					select @Amount = Amount from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
			
			
				set @tmpFormula = REPLACE( @tmpFormula, 'A'+@fColumnCode, 'convert(decimal(12,2),'+ltrim(convert(nvarchar,@Amount))+')')


				set @i=@i+1
			end

			
			-------------------------------------------------
			------------ Fix allowance-----------------------
			------------ Muhib/Umair 22 Aug 2019-------------
			set @Formula = @tmpFormula

			while @i<LEN(@Formula)
			begin
				set @i=charindex('X',@formula, @i) --Murtaza 29 Apr 2021
				if @i=0 
					break

				set @fColumnCode =  substring(@formula, charindex('X', @formula, @i)+1,3) --Murtaza 29 Apr 2021
				
				SET @Amount=0
				if @PayrollType=2
					select @Amount = 0 --convert( decimal(12,2),CONVERT(varchar(20), decryptbykey(EncAmount))) from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
				else
					select @Amount = FixAmount from EmpDetailFixAmount where EmployeeIndex = @EmployeeIndex and ColumnCode = @fColumnCode
			
				set @tmpFormula = REPLACE( @tmpFormula, 'X'+@fColumnCode, 'convert(decimal(12,2),'+ltrim(convert(nvarchar,@Amount))+')') --Murtaza 29 Apr 2021


				set @i=@i+1
			end

			------------ Muhib/Umair 22 Aug 2019-------------
			------------ Fix allowance-----------------------
			-------------------------------------------------

			

			set @tmpformula=REPLACE(@tmpformula, 'if', ' case when ')	--Muhib 18 JUne 2017  
			set @tmpformula=REPLACE(@tmpformula, '&&', ' and ')	--Muhib 18 JUne 2017  

			SET @Amount=0
			SET @SQLString =  N'select @AmountOut = (' + @tmpformula + ')'
			SET @ParmDefinition = N'@AmountOut nvarchar(25) OUTPUT'
			EXECUTE sp_executesql @SQLString, @ParmDefinition, @AmountOut = @Amount OUTPUT

		

		--select @ColumnCode ColumnCode
		--select 'before del', * from FS_Detail where FSIndex = @FSIndex and columncode=@ColumnCode		
			delete from FS_Detail where FSIndex = @FSIndex and columncode=@ColumnCode
		--select 'after', * from FS_Detail where FSIndex = @FSIndex and columncode=@ColumnCode
		--		select @FSIndex,@ColumnCode,@Amount, null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= @ColumnCode
		

			if @PayrollType=2
				insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
				select @FSIndex,@ColumnCode,0,encryptbykey(@KeyGUID, convert(varchar(20),@Amount)), @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= @ColumnCode
			else
				insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
				select @FSIndex,@ColumnCode, Round(@Amount, @DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= @ColumnCode
		
		--if @ColumnCode=2
		--begin 
		--close cur_Formula
		--deallocate cur_Formula
		--set @SQLString='Employee Index : [' + str(@EmployeeIndex) + ',' + STR(@ColumnCode) + '(' + @tmpFormula + ')' + ']'
		--		raiserror (@SQLString, 16,1)
		--		return
		--end		
				

			if @@Error<>0
			begin
				set @SQLString='Employee Index : [' + str(@EmployeeIndex) + ',' + STR(@ColumnCode) + '(' + @tmpFormula + ')' + ']'
				raiserror (@SQLString, 16,1)
				return
			end


			fetch next from cur_Formula into @ColumnCode, @Formula, @ColumnType, @DecimalPlaces
		end
		close cur_Formula
		deallocate cur_Formula

		-- Get Formula Columns Of Selected Invoice --
		---------------------------------------------
	    
	--    --///////////////////////////////////
	--    --/// Nabeel May 25, 2012		  ///
	--	--/// Get and set service charges ///
	--set @ColumnType=10    
 --   declare @ChargesType As char(1), @ServiceCharges As float, @SCMethod As smallint
    
 --   delete from FS_Detail where FSIndex = @FSIndex and columncode = 119 

 --   select @ServiceCharges= isnull(servicecharges,0), @ChargesType= isnull(chargestype,'-'), @SCMethod= isnull(scmethod,15) from clientinv where clientindex=@ClientIndex  and invoiceno=@InvoiceNo

 --   --select * from FS_Detail
    
 --   If @ChargesType = 'P' 
 --   begin
 --       declare @GrossAmount As float
 --       SET @GrossAmount = 0
 --       select @GrossAmount = isnull(amount,0) from FS_Detail where FSIndex= @FSIndex and columncode = 2 

	--	insert into fs_detail (FSIndex, columncode, amount, encamount, ColumnType, IncomeTaxApply ) 
	--	select	@FSIndex, ic.ColumnCode, round(@GrossAmount * @ServiceCharges / 100.0 ,2), null, @ColumnType, ic.IncomeTaxApply  
	--	from	fnInvoiceColumn(@ClientIndex) ic where ColumnCode=119
 --   End
 --   --/// Get and set service charges ///
	----///////////////////////////////////




-------------------------------
----GST START Nabeel 08 July 2013 
--set @ColumnType=0
--select @ColumnType= columntype from clientinvdetail 
--      where columncode=62 
--      and clientindex=@ClientIndex 
--      and invoiceno=@InvoiceNo 

        
--If @ColumnType = 10
--begin
--      declare @GSTAmount float
--      set @GSTAmount=0
      
--      declare @RevenueBoardIndex int
--      set @RevenueBoardIndex=0
      
--      select	@RevenueBoardIndex=RevenueBoardIndex from ClientInv 
--		where	clientindex=@ClientIndex 
--				and invoiceno=@InvoiceNo 
      
--      select      @GSTAmount = isnull(SUM(amount),0) * (14.0/100.0)
--      from  FS_Detail 
--      where FSIndex= @FSIndex 
--      and columncode in (19,49,108,119,233)
	  
--	  if @RevenueBoardIndex=2--Other Revenue Board
--      begin
--		set @GSTAmount=0
--	  end

--      --Nabeel 14 July 2014 start

--	  if @RevenueBoardIndex in (6,7,8)--Punjab Revenue Board
--      begin
--		set @GSTAmount=0
--		delete from FS_Detail where FSIndex = @FSIndex and columncode=62    
--      if @PayrollType=2
--            insert into FS_Detail (FSIndex, columncode, amount, encamount, ColumnType, IncomeTaxApply ) 
--            select @FSIndex,62,0, encryptbykey(@KeyGUID, convert(varchar(20),round(@GSTAmount,2))), @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= 62
--      else
--            insert into FS_Detail (FSIndex, columncode, amount, encamount, ColumnType, IncomeTaxApply ) 
--            select @FSIndex,62,@GSTAmount, null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= 62

--declare cur_Formula cursor for  
--				select	columncode, formula, columnType 
--				from	clientinvdetail 
--				where	Columntype in (2,6,7)
--						and columncode=8 
--						and clientindex=@ClientIndex  
--						and invoiceno=@InvoiceNo 
--				order by sortorder

--		open cur_Formula
--		fetch next from cur_Formula into @ColumnCode, @Formula, @ColumnType
--		while @@FETCH_STATUS=0
--		begin

--			set @i=0
--			set @Formula=REPLACE(@Formula, 'MTD', @lmMaxDays * 1.0) -- last service month total days
--			set @Formula=REPLACE(@Formula, 'SAD', @SAD * 1.0) -- Salary Arrears Days since last posted Payroll
--			set @tmpFormula=@Formula

--			while @i<LEN(@Formula)
--			begin
--				set @i=charindex('A',@formula, @i)
--				if @i=0 
--					break


--				set @fColumnCode =  substring(@formula, charindex('A', @formula, @i)+1,3)

--				SET @Amount=0
--				if @PayrollType=2
--					select @Amount = convert( decimal(12,2),CONVERT(varchar(20), decryptbykey(EncAmount))) from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
--				else
--					select @Amount = Amount from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
			
			
--				set @tmpFormula = REPLACE( @tmpFormula, 'A'+@fColumnCode, 'convert(decimal(12,2),'+ltrim(convert(nvarchar,@Amount))+')')


--				set @i=@i+1
--			end


--			SET @Amount=0
--			SET @SQLString =  N'select @AmountOut = (' + @tmpformula + ')'
--			SET @ParmDefinition = N'@AmountOut nvarchar(25) OUTPUT'
--			EXECUTE sp_executesql @SQLString, @ParmDefinition, @AmountOut = @Amount OUTPUT

--			if @RevenueBoardIndex =7 set      @GSTAmount = @Amount * (15.0/100.0)
--			if @RevenueBoardIndex in (6,8) set      @GSTAmount = @Amount * (16.0/100.0)

						
		
--			if @@Error<>0
--			begin
--				set @SQLString='Employee Index : [' + str(@EmployeeIndex) + ',' + STR(@ColumnCode) + '(' + @tmpFormula + ')' + ']'
--				raiserror (@SQLString, 16,1)
--				return
--			end


--			fetch next from cur_Formula into @ColumnCode, @Formula, @ColumnType
--		end
--		close cur_Formula
--		deallocate cur_Formula


	  
	  
--	  end	
	  

--      delete from FS_Detail where FSIndex = @FSIndex and columncode=62
    
--      if @PayrollType=2
--            insert into FS_Detail (FSIndex, columncode, amount, encamount, ColumnType, IncomeTaxApply ) 
--            select @FSIndex,62,0, encryptbykey(@KeyGUID, convert(varchar(20),round(@GSTAmount,2))), @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= 62
--      else
--            insert into FS_Detail (FSIndex, columncode, amount, encamount, ColumnType, IncomeTaxApply ) 
--            select @FSIndex,62,@GSTAmount, null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= 62
--end
----GST END Nabeel 08 July 2013 
-------------------------------


		---------------------------------------------
		-- Get Formula Columns Of Selected Invoice Billing Start--
		--declare @i as smallint, @fColumnCode char(3), @Formula varchar(5000), @tmpFormula varchar(5000)
		set @ColumnCode=0
		
		declare cur_Formula cursor for  
				select	columncode, formula, columnType, Isnull(DecimalPlaces, 2) DecimalPlaces
				from	clientinvdetail 
				where	Columntype in (2,6,7)
						and columncode=8 
						and clientindex=@ClientIndex  
						and invoiceno=@InvoiceNo 
				order by sortorder

		open cur_Formula
		fetch next from cur_Formula into @ColumnCode, @Formula, @ColumnType, @DecimalPlaces
		while @@FETCH_STATUS=0
		begin

			set @i=0
			set @Formula=REPLACE(@Formula, 'MTD', @lmMaxDays * 1.0) -- last service month total days
--			set @Formula=REPLACE(@Formula, 'LBSD', @LBSD * 1.0) -- last balance salary days
			set @Formula=REPLACE(@Formula, 'SAD', @SAD * 1.0) -- Salary Arrears Days since last posted Payroll
			set @Formula=REPLACE(@Formula, 'SPM', @SPM) -- Service Period in Months
			set @Formula=REPLACE(@Formula, 'GSB', @GSBGroupID) -- Emp current GSB Group ID
			set @Formula=REPLACE(@Formula, 'WDs', @WorkingDays) -- Work days
			set @Formula = REPLACE(@Formula, 'GI', @GradeIndex)
			set @Formula = REPLACE(@Formula, 'EmpSSD', '''' + Cast(@DOJ as varchar(50)) + '''')	-- Service Start Date
			set @Formula = REPLACE(@Formula, 'EmpSED', '''' + Cast(@DOL as varchar(50)) + '''') -- Service End Date
			set @Formula = REPLACE(@Formula, 'EmpAge', @EmpAgeInNumber)
			set @Formula = REPLACE(@Formula, 'EmpSY', @EmpServiceYear)
			set @Formula = REPLACE(@Formula, 'EmpSP', @EmpServicePeriodInNumber)
			set @Formula = REPLACE(@Formula, 'isPF', @isPFMember)
			set @Formula = REPLACE(@Formula, 'TerritoryIndex', @TerritoryIndex)
			set @Formula = REPLACE(@Formula, 'EmpType', @EmploymentType)

			set @Formula = REPLACE(@Formula, 'GYear', @GYear)
			set @Formula = REPLACE(@Formula, 'GMonth', @GMonth)
			set @Formula = REPLACE(@Formula, 'GDays', @GDays)

			set @tmpFormula=@Formula

			while @i<LEN(@Formula)
			begin
				set @i=charindex('A',@formula, @i)
				if @i=0 
					break


				set @fColumnCode =  substring(@formula, charindex('A', @formula, @i)+1,3)

				SET @Amount=0
				if @PayrollType=2
					select @Amount = convert( decimal(12,2),CONVERT(varchar(20), decryptbykey(EncAmount))) from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
				else
					select @Amount = Amount from FS_Detail where FSIndex= @FSIndex and ColumnCode= @fColumnCode
			
--if @fColumnCode=119
--		begin 
--		close cur_Formula
--		deallocate cur_Formula
		
--		set @SQLString='Employee Index : [' + str(@EmployeeIndex) + ',' + STR(@ColumnCode) + '(' + @tmpFormula + ')' + '(' + str(@Amount) + ')'+ ']'
--				raiserror (@SQLString, 16,1)
--				return
--		end	
			
				set @tmpFormula = REPLACE( @tmpFormula, 'A'+@fColumnCode, 'convert(decimal(12,2),'+ltrim(convert(nvarchar,@Amount))+')')


				set @i=@i+1
			end


			SET @Amount=0
			SET @SQLString =  N'select @AmountOut = (' + @tmpformula + ')'
			SET @ParmDefinition = N'@AmountOut nvarchar(25) OUTPUT'
			EXECUTE sp_executesql @SQLString, @ParmDefinition, @AmountOut = @Amount OUTPUT

				
			delete from FS_Detail where FSIndex = @FSIndex and columncode=@ColumnCode
    
			if @PayrollType=2
					insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
					select @FSIndex,@ColumnCode,0,encryptbykey(@KeyGUID, convert(varchar(20),@Amount)), @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= @ColumnCode
			else
					insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
					select @FSIndex,@ColumnCode, Round(@Amount, @DecimalPlaces), null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= @ColumnCode
		
		--if @ColumnCode=2
		--begin 
		--close cur_Formula
		--deallocate cur_Formula
		--set @SQLString='Employee Index : [' + str(@EmployeeIndex) + ',' + STR(@ColumnCode) + '(' + @tmpFormula + ')' + ']'
		--		raiserror (@SQLString, 16,1)
		--		return
		--end		
				

			if @@Error<>0
			begin
				set @SQLString='Employee Index : [' + str(@EmployeeIndex) + ',' + STR(@ColumnCode) + '(' + @tmpFormula + ')' + ']'
				raiserror (@SQLString, 16,1)
				return
			end


			fetch next from cur_Formula into @ColumnCode, @Formula, @ColumnType, @DecimalPlaces
		end
		close cur_Formula
		deallocate cur_Formula

		-- Get Formula Columns Of Selected Invoice Billing End --
		---------------------------------------------




		-----------------------------
		-- Get Adjusted Income Tax --
		declare @FSTax float
		set @FSTax = 0
		set @ColumnType=0
		select @ColumnType=ColumnType from clientinvdetail where ColumnCode=105 and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo 

		If @ColumnType = 9  
		begin
			
			if exists (select * from empFixTax where employeeindex = @EmployeeIndex)
				begin
					select @FSTax = TaxAmount from empFixTax where employeeindex = @EmployeeIndex

					delete from FS_DetailOther where columnCode = 105 and fsindex = @FSIndex
					
					insert into FS_DetailOther (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
					select @FSIndex,ic.ColumnCode,@FSTax, null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= 105

				end
			else
				exec Prl_fs_IncomeTaxCalculator @employeeindex, @FSIndex, @Key, @FSTax out

			--------------------
			-- Refresh Values -- 
			delete from FS_Detail where FSIndex = @FSIndex and columncode=105
    
			if @PayrollType=2
					insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
					select @FSIndex,ic.ColumnCode ,0,encryptbykey(@KeyGUID, convert(varchar(20),@FSTax)), @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= 105
			else
					insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
					select @FSIndex,ic.ColumnCode,@FSTax, null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= 105
			-- Refresh Values -- 
			--------------------
		end		
		-- Get Adjusted Income Tax --
		-----------------------------


		--------------------------
		-- Net Salary on Module --
		
		Declare @NetSalary float
		
		---- Murtaza 23 Oct 2020 ----
		set @ColumnType=0
		select @ColumnType=ColumnType from clientinvdetail where ColumnCode=167 and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo 

		If @ColumnType = 10
		begin

			set @NetSalary =	Round((select isnull(sum(amount),0) from FS_Detail where FSIndex=@FSIndex and (ColumnType in (4,6,8,11,16) or columncode=56) ),0)
								-
								Round((select isnull(sum(amount),0) from FS_Detail where FSIndex=@FSIndex and ColumnType in (5,7,9,12,17) ),0)
			
			if @PayrollType=2
				Update	FS_Detail
				set		EncAmount = @NetSalary
				where	FSIndex = @FSIndex
						and columncode = 167
			else
				Begin
					if not exists (select * from FS_Detail where FSIndex = @FSIndex and ColumnCode = 167)

						insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
						select @FSIndex,ic.ColumnCode,@NetSalary, null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= 167
					
					else
					
						Update	FS_Detail
						set		Amount = @NetSalary 
						where	FSIndex = @FSIndex 
								and columncode = 167

				End
		end
		---- Murtaza 23 Oct 2020 ----


		---- Murtaza 11 Jan 2021 ----
		set @ColumnType=0
		select @ColumnType=ColumnType from clientinvdetail where ColumnCode=4 and ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo 

		If @ColumnType = 10
		begin

			set @NetSalary  =	(select isnull(sum(amount),0) from FS_Detail where FSIndex=@FSIndex and (ColumnType in (4,6,8,11,16) or columncode=56) )
										-
										(select isnull(sum(amount),0) from FS_Detail where FSIndex=@FSIndex and ColumnType in (5,7,9,12,17) ) 
			
			if @PayrollType=2
				Update	FS_Detail
				set		EncAmount = @NetSalary
				where	FSIndex = @FSIndex
						and columncode = 4
			else
				Begin
					if not exists (select * from FS_Detail where FSIndex = @FSIndex and ColumnCode = 4)

						insert into FS_Detail (fsindex, columncode, amount, encamount, columntype, incometaxapply) 
						select @FSIndex,ic.ColumnCode,@NetSalary, null, @ColumnType, ic.IncomeTaxApply from fnInvoiceColumn(@ClientIndex) ic where columncode= 4
					
					else
					
						Update	FS_Detail
						set		Amount = @NetSalary 
						where	FSIndex = @FSIndex 
								and columncode = 4

				End
		end
		---- Murtaza 11 Jan 2021 ----

		-- Net Salary on Module --
		--------------------------



		if @PayrollType=1
			update	FS_Master 
			set		ServicePeriod=@ServicePeriod,
					gDays=@d, gMonths=@m, gYears=@y,
					gDaysAmount=@dAmount, gMonthsAmount=@mAmount, gYearsAmount=@yAmount,
					GratuityAdjustment = @GratuityAdjustment,
					--GratuityAmount= (case when @IsFundedGratuity=1 then @GratuityAmount else 0 end), -- 25 Nov 2020 As Per Yawer Sir (done by murtaza)
					GratuityAmount= @GratuityAmount,
--					LoanAdjutment=@LoanAdjustment,
--					AdvanceAdjustment=@AdvanceAdjustment,
					PFAmount=@PFAmount,
					PensionAmount=@PensionAmount,
					IncomeTax = @FSTax,
					TotalAddition=(select isnull(sum(amount),0) from FS_Detail where FSIndex=@FSIndex and (ColumnType in (4,6,8,11,16) or columncode=56) ), 
					TotalDeduction=(select isnull(sum(amount),0) from FS_Detail where FSIndex=@FSIndex and ColumnType in (5,7,9,12,17) ) 
			where	FSIndex=@FSIndex 
			
		else
			begin

				update	FS_Master 
				set		ServicePeriod=@ServicePeriod,
						gDays=@d, gMonths=@m, gYears=@y,
						EncgDaysAmount=encryptbykey(@KeyGUID, convert(varchar(20),@dAmount)), 
						EncgMonthsAmount=encryptbykey(@KeyGUID, convert(varchar(20),@mAmount)), 
						EncgYearsAmount=encryptbykey(@KeyGUID, convert(varchar(20),@yAmount)),
						--EncGratuityAmount= encryptbykey(@KeyGUID, convert(varchar(20),(@GratuityAmount))),
						EncGratuityAmount= @GratuityAmount,
						EncPFAmount= encryptbykey(@KeyGUID, convert(varchar(20),(@PFAmount))),
						EncPensionAmount= encryptbykey(@KeyGUID, convert(varchar(20),(@PensionAmount))),
						EncIncomeTax = encryptbykey(@KeyGUID, convert(varchar(20),@FSTax)),
						GratuityAdjustment = @GratuityAdjustment,
						LoanAdjutment=@LoanAdjustment,
						AdvanceAdjustment=@AdvanceAdjustment,
						EncTotalAddition=(select encryptbykey(@KeyGUID, convert(varchar(20),isnull(sum(encamount),0))) from FS_vwDetail where FSIndex=@FSIndex and (ColumnType in (4,6,8,11,16) or columncode=56) ), 
						EncTotalDeduction=(select encryptbykey(@KeyGUID, convert(varchar(20),isnull(sum(encamount),0))) from FS_vwDetail where FSIndex=@FSIndex and ColumnType in (5,7,9,12,17) ) 
				where	FSIndex=@FSIndex
			end

		declare @UnpaidDays as varchar(100)=''

		if @SAM<>0
			set @UnpaidDays = ltrim(str(@SAM)) + ' Month(s)'

		set @UnpaidDays = @UnpaidDays + (case when @SAM<>0 then ' and ' else '' end ) + ltrim(str(@SAD)) + ' Day(s)'

		 
		select @GSal gsal, @BSal bsal, @GR GR,
		@Mth mth, @Dys dys, @GC gc, @y y, @m m, @d d, @yAmount yAmount, @mAmount mAmount, @dAmount dAmount, @FSIndex FSIndex, @UnpaidDays UnpaidDays



	--//////////////////////////////////////////////////////
    --/// Set Current Salary With Payroll Salary Breakup ///

    if @PayrollType=2
		begin
			delete 
			from	FS_Detail 
			where	FSIndex=@FSIndex
					and ColumnCode in (select ColumnCode from EmpDetailFixAmountEnc where EmployeeIndex=@EmployeeIndex and GsbCat=1)

			insert into FS_Detail  (FSIndex,ColumnCode,Amount, EncAmount, ColumnType, IncomeTaxApply)
			select	@FSIndex, fa.ColumnCode, 0, encryptbykey(@KeyGUID, convert(varchar(20),fa.FixAmount)), 3, 0
			from	EmpDetailFixAmountEncVw  fa
			where	fa.EmployeeIndex=@EmployeeIndex and fa.GsbCat=1 
		end
    else
		begin
			delete 
			from	FS_Detail 
			where	FSIndex=@FSIndex
					and ColumnCode in (select ColumnCode from EmpDetailFixAmount where EmployeeIndex=@EmployeeIndex and GsbCat=1)

			
			----------------Add Muhib 16 Jan 2019----------------
			insert into FS_Detail (FSIndex,ColumnCode,Amount, EncAmount, ColumnType, IncomeTaxApply)
			select        @FSIndex, fa.ColumnCode, round(fa.FixAmount,isnull(cid.decimalplaces,2)), null, 3, 0 
			from        EmpDetailFixAmount fa 
							left outer join  ClientInvDetail cid			
										on	cid.ColumnCode=fa.ColumnCode			
										and cid.ClientIndex=@ClientIndex			
										and cid.InvoiceNo=@InvoiceNo

			 where        fa.EmployeeIndex=@EmployeeIndex and fa.GsbCat=1
						
			----------------Add Muhib 16 Jan 2019----------------
		end
    --/// Set Current Salary With Payroll Salary Breakup ///
    --//////////////////////////////////////////////////////

		
	end

return
