
go
insert into tm_AtClosingIntType values (4,'Territory Invoice')
go



Alter procedure [dbo].[tm_AtClosingCIPIntegration_SetData]            
		 @PeriodIndex int,            
		 @EmployeeIndex int,            
		 @Remarks nvarchar(100),            
		 @UserEmpIndex int            
		as                 
		begin            
		 declare @AtClosingStatus tinyint = 6, @FromDate datetime, @ToDate datetime            
		 declare @PayrollMonth tinyint, @PayrollYear smallint, @IndividualPayrollIndex bigint, @ClientIndex smallint, @InvoiceNo tinyint, @InvoiceIndex int            
		 Declare @ODIndex int  =0            
		 Set @InvoiceNo = 0             
		 Declare @BuIndex smallint = 0  , @UnitIndex smallint = 0 , @TerritoryIndex int = 0
---Default Invoice
		 select @Clientindex = Clientindex  from employee where employeeindex = @EmployeeIndex            
		 --if @Clientindex in (1162,1101,1270,1266,1079,1359) --For Sapphire WL invoice is BusinessUnit temp check in SP            
		 if @Clientindex  in (select clientindex from  tm_AtClosingRules where isnull(CIPIntType,0) = 1 ) --For Sapphire/ dfl WL invoice is BusinessUnit temp check in SP            
		 begin            
	   select @InvoiceNo = c.InvoiceNo from clientinv c      
	   where c.clientindex = @Clientindex                    
	   and c.invoicetype = 1            
		 end          
---Business Unit Invoice
		select @Clientindex = Clientindex ,@BuIndex = isnull(buindex,0) from employee where employeeindex = @EmployeeIndex            
		 --if @Clientindex  in (1090,1147,1145,1231,1361) --For Sapphire/ dfl WL invoice is BusinessUnit temp check in SP            
		 if @Clientindex  in (select clientindex from  tm_AtClosingRules where isnull(CIPIntType,0)= 2 ) --For Sapphire/ dfl WL invoice is BusinessUnit temp check in SP            
		 begin            
	   select @InvoiceNo = cd.InvoiceNo from clientinvleveldetail cd ,clientinv c             
	   where c.clientindex = @Clientindex and worklocation = @BuIndex            
	   and c.clientindex = cd.clientindex            
	   and c.invoiceno = cd.invoiceno             
	   and c.invoicetype = 1            
		 end              
--- Unit Invoice
		SELECT @Clientindex = Clientindex, @UnitIndex = ISNULL(UnitIndex, 0) 
		FROM employee 
		WHERE employeeindex = @EmployeeIndex;
		IF EXISTS (SELECT 1 FROM clientplan WHERE IsCIPIntegrationWithAttendanceUnit = 1 AND ClientIndex = @Clientindex) 
		   OR EXISTS (SELECT 1 FROM tm_AtClosingRules WHERE ISNULL(CIPIntType, 0) = 3)
		BEGIN
		    SELECT @InvoiceNo = cd.InvoiceNo 
		    FROM clientinvleveldetail cd
		    JOIN clientinv c ON c.clientindex = cd.clientindex AND c.invoiceno = cd.invoiceno
		    WHERE c.clientindex = @Clientindex 
		      AND worklocation = @UnitIndex
		      AND c.invoicetype = 1;
		END;
---Territory Invoice
		select @Clientindex = Clientindex ,@TerritoryIndex = isnull(TerritoryIndex,0) from employee where employeeindex = @EmployeeIndex                      
		 if @Clientindex  in (select clientindex from  tm_AtClosingRules where isnull(CIPIntType,0)= 4 )       
		 begin            
	   select @InvoiceNo = cd.InvoiceNo from clientinvleveldetail cd ,clientinv c             
	   where c.clientindex = @Clientindex and worklocation = @TerritoryIndex            
	   and c.clientindex = cd.clientindex            
	   and c.invoiceno = cd.invoiceno             
	   and c.invoicetype = 1            
		 end ;



		 if @InvoiceNo = 0             
	   return            
		 select 
		@FromDate=fromdate,            
		@ToDate=ToDate,            
		@PayrollMonth=PayrollMonth,             
		@PayrollYear=PayrollYear            
		 from tm_Period p            
		 where PeriodIndex=@PeriodIndex            
		 begin transaction            
		 insert into tm_AtClosingHistory (PeriodIndex, EmployeeIndex, HNo, AtClosingStatus, Remarks, UpdateBy, UpdateDate,UserEmpIndex)            
		 values (            
		 @PeriodIndex,             
		 @EmployeeIndex,             
		 (select isnull(max(HNo),0)+1 from tm_AtclosingHistory where periodIndex=@PeriodIndex and EmployeeIndex=@EmployeeIndex),            
		 @AtClosingStatus,            
		 'At closing integration with CIP - ' + @Remarks,            
		 0,            
		 getdate(),            
		 @UserEmpIndex            
		)            
		 if @@Error<>0            
		 begin            
	   rollback transaction            
	   --select (0)            
	   return            
		 end            
		 delete from cp_empvariablepaydataother             
		 where  EmployeeIndex = @EmployeeIndex             
		and ColumnCode in (select ColumnCode from ClientInvAt where ClientIndex=@ClientIndex and InvoiceNo=@InvoiceNo)            
		and PayrollYear = @PayrollYear             
		and PayrollMonth = @PayrollMonth            
		 if @@Error<>0            
		 begin            
	   rollback transaction            
	   --select (1)        
	   return            
		 end            
		 select @ODIndex =isnull(max(ODIndex),0) from cp_EmpVariablePayDataOther            
		 insert into cp_EmpVariablePayDataOther (ODIndex, EmployeeIndex, ColumnCode,Amount,PayrollYear,PayrollMonth,Remarks)            
		 select @ODIndex + row_number() over (order by c.employeeindex),c.employeeindex,ci.columncode,isnull(sum(c.FieldValue),0) Amount,p.PayrollYear,p.PayrollMonth,'From At Closing ' Remarks            
		 from tm_VwAtClosingData c ,tm_period p ,clientinvat ci where             
		 p.periodindex =@PeriodIndex             
		 and p.periodindex = c.periodindex            
		 and c.employeeindex =@EmployeeIndex            
		 --and  c.fieldno in (13,14,16,11,12)            
		 and ci.clientindex = @ClientIndex            
		 and c.fieldno = ci.FieldNo            
		 and ci.InvoiceNo  = @InvoiceNo            
		 group by c.employeeindex,ci.columncode,p.PayrollYear,p.PayrollMonth            
		 if @@Error<>0            
		 begin            
	   rollback transaction            
	   --select (2)            
	   return            
		 End             
		 commit transaction                
End
