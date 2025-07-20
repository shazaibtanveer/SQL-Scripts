Create Procedure [dbo].[tm_Adj_SetCustom26]  
	@AdjRuleIndex int,   
	@AdjBatchIndex int,  
	@PeriodIndex smallint,  
	@ClientIndex smallint,  
	@EmpIndex int,  
	@RegionIndex smallint,  
	@DepartmentIndex smallint,  
	@LocationIndex smallint,  
	@ClientBranchIndex smallint,  
	@TerritoryIndex smallint,  
	@UnitIndex smallint,  
	@DivisionIndex smallint,  
	@PositionCategory tinyint,  
	@StrGrades varchar(200),  
	@GradeGroupIndex smallint,  
	@Remarks varchar(100),  
	@UserIndex smallint,   
	@AdjType tinyint ,  
	@UserEmpIndex int  
As  
	Begin  
		Declare	@IsBalanceCF bit,  
				@AdjIndex int,  
				@FromDate datetime,  
				@ToDate datetime,  
				@ScreenIndex smallint,  
				@HNo tinyint,  
				@AdjStatus tinyint,  
				@AdjType2LC tinyint  
		set @ScreenIndex = 1394  
		set @AdjStatus = 2   
		set @HNo = 1  
		set @AdjType2LC=0  
		set @AdjType = 26  
		select	@FromDate = FromDate,   
				@ToDate = ToDate   
		from	tm_period   
		where	PeriodIndex=@PeriodIndex   
		select @AdjIndex = ISNULL(max(AdjIndex),0)+1 from tm_Adj  
		begin transaction  
		if @AdjBatchIndex = 0   
			begin  
				select @AdjBatchIndex = isnull(MAX(AdjBatchIndex),0)+1 from tm_AdjBatch   
				insert into tm_AdjBatch (AdjBatchIndex, AdjType, AdjStatus, AdjRuleIndex, ClientIndex, FromDate, ToDate, EmpIndex, RegionIndex, DepartmentIndex, LocationIndex, ClientBranchIndex, TerritoryIndex, UnitIndex, DivisionIndex, PositionCategory, StrGrades, GradeGroupIndex)  
				values (@AdjBatchIndex, @AdjType, @AdjStatus , @AdjRuleIndex, @ClientIndex, @FromDate, @ToDate, @EmpIndex, @RegionIndex, @DepartmentIndex, @LocationIndex, @ClientBranchIndex, @TerritoryIndex, @UnitIndex, @DivisionIndex, @PositionCategory, @StrGrades, @GradeGroupIndex)  
				if @@ERROR<>0  
				begin  
					rollback transaction  
					return  
				end  
				insert into tm_AdjBatchHistory (AdjBatchIndex, HNo, AdjStatus, Remarks, UserEmpIndex, EntryBy, EntryDate )  
				values (@AdjBatchIndex, @HNo , @AdjStatus, @Remarks, @UserEmpIndex, @UserIndex, GETDATE())  
				if @@ERROR<>0  
				begin  
					rollback transaction  
					return  
				end  
			end 
		else
			begin
				delete 
				from	tm_AdjHistory
				where	AdjIndex in ( select AdjIndex from tm_Adj where	AdjBatchIndex=@AdjBatchIndex)
				if @@ERROR<>0  
				begin  
					rollback transaction  
					return  
				end  
				update	tm_Summary
				set		AdjIndex=null 
				where	AdjIndex in ( select AdjIndex from tm_Adj where	AdjBatchIndex=@AdjBatchIndex)
				if @@ERROR<>0  
				begin  
					rollback transaction  
					return  
				end  
				delete 
				from	tm_Adj 
				where	AdjBatchIndex=@AdjBatchIndex
				if @@ERROR<>0  
				begin  
					rollback transaction  
					return  
				end  
			end
 insert into tm_Adj (AdjIndex,AdjType,AdjDate,EmployeeIndex,leavetype,TotalDays,AdjBal,AdjBatchIndex,AdjStatus,AdjValue,
						adjsource,AdjBalLc,AdjBalEg,TotalDaysLC,TotalDaysEG)
		SELECT 
				@AdjIndex + ROW_NUMBER() OVER (ORDER BY EmployeeIndex) as AdjIndex,
				AdjType,
				AtDate as AdjDate,
				EmployeeIndex,
				null as leavetype,
				TotalDays,
				AdjBal,
				@AdjBatchIndex as AdjBatchIndex,
				2 as AdjStatus,
				null as AdjValue,
				null as adjsource,
				null as AdjBalLc,
				null as AdjBalEg,
				null as TotalDaysLC,
				null as TotalDaysEG
		FROM 
		(
				SELECT 
					ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY EmployeeIndex) AS SNo,
					EmployeeIndex, 
					AtDate,
					7 as adjtype,   --7
					CASE 
					WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 2 THEN 0.5 else 0
				END AS TotalDays,
				 CASE 
					WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 0 THEN 0.333334
					WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 1 THEN 0.666667
					WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 2 THEN 0
				END AS AdjBal
				FROM 
					tm_summary                 
				WHERE 
					ClientIndex = @clientindex 
					AND AtDate BETWEEN @FromDate AND @ToDate 
					AND AdjLC > 0           
					AND AdjLvBal NOT IN (0.5, 1)
			Union All
				SELECT 
					ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY EmployeeIndex) AS SNo,
					EmployeeIndex, 
					AtDate,
					19 as adjtype,  --19
				 CASE 
					WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 2 THEN 0.5 else 0
					END AS TotalDays,
				 CASE 
					WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 0 THEN 0.333334
					WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 1 THEN 0.666667
					WHEN (ROW_NUMBER() OVER (PARTITION BY EmployeeIndex ORDER BY AtDate) - 1) % 3 = 2 THEN 0
					END AS AdjBal
				FROM 
					tm_summary                 
				WHERE 
					ClientIndex = @clientindex 
					AND AtDate BETWEEN @FromDate AND @ToDate 
					AND AdjEG > 0           
					AND AdjLvBal NOT IN (0.5, 1)
		) t;  
		if @@ERROR<>0  
		begin  
			rollback transaction  
			return  
		end  
		insert into tm_AdjHistory (AdjIndex, HNo, AdjStatus, Remarks, UserEmpIndex, EntryBy, EntryDate )  
		select	AdjIndex, 1, AdjStatus, @Remarks, @UserEmpIndex, null, getdate() 
		from	tm_Adj a
		where	a.adjbatchindex=@AdjBatchIndex 
		if @@ERROR<>0  
		begin  
			rollback transaction  
			return  
		end  
		commit transaction	     
	End  
Return  
