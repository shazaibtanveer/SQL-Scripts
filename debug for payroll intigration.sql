declare    
		 @PeriodIndex int = 11206,            
		 @EmployeeIndex int = 397500,            
		 @Remarks nvarchar(100) = 'test by shahzaib ',            
		 @UserEmpIndex int = 300136           

		 declare @AtClosingStatus tinyint = 6, @FromDate datetime, @ToDate datetime            
		 declare @PayrollMonth tinyint, @PayrollYear smallint, @IndividualPayrollIndex bigint, @ClientIndex smallint, @InvoiceNo tinyint, @InvoiceIndex int            
		 Declare @ODIndex int  = 0 
		 Set @InvoiceNo = 0 
		 Declare @BuIndex smallint = 0  ,@UnitIndex smallint = 0  
		 
	
		select @Clientindex = Clientindex  from employee where employeeindex = @EmployeeIndex            
	if @Clientindex  in (select clientindex from  tm_AtClosingRules where isnull(CIPIntType,0) = 1 )         
		begin            
			select @InvoiceNo = c.InvoiceNo from clientinv c     
			where c.clientindex = @Clientindex         
			and c.invoicetype = 1            
		 end            
		
		 
		 select @Clientindex = Clientindex ,@BuIndex = isnull(buindex,0) from employee where employeeindex = @EmployeeIndex
	if @Clientindex  in (select clientindex from  tm_AtClosingRules where isnull(CIPIntType,0)= 2 )	        
		 begin            
			select @InvoiceNo = cd.InvoiceNo from clientinvleveldetail cd ,clientinv c             
			where c.clientindex = @Clientindex and worklocation = @BuIndex            
			and c.clientindex = cd.clientindex            
			and c.invoiceno = cd.invoiceno             
			and c.invoicetype = 1            
		 end            
	
select @Clientindex = Clientindex ,@UnitIndex = isnull(UnitIndex,0) from employee where employeeindex = @EmployeeIndex  
	IF EXISTS (SELECT 1 FROM clientplan WHERE IsCIPIntegrationWithAttendanceUnit = 1 AND ClientIndex = @Clientindex) 
		   OR EXISTS (SELECT 1 FROM tm_AtClosingRules WHERE ISNULL(CIPIntType, 0) = 3)       
		 begin           
			select @InvoiceNo = cd.InvoiceNo from clientinvleveldetail cd ,clientinv c               
			where c.clientindex = @Clientindex and worklocation = @UnitIndex            
			and c.clientindex = cd.clientindex              
			and c.invoiceno = cd.invoiceno               
			and c.invoicetype = 1            
		 end          
		 
		 if @InvoiceNo = 0             
	 select @InvoiceNo  As invoiceNo        
		 select @FromDate=fromdate,            
		@ToDate=ToDate,            
		@PayrollMonth=PayrollMonth,             
		@PayrollYear=PayrollYear            
		 from tm_Period p            
		 where PeriodIndex=@PeriodIndex            
		select          
		 @PeriodIndex,             
		 @EmployeeIndex,             
		 (select isnull(max(HNo),0)+1 from tm_AtclosingHistory where periodIndex=@PeriodIndex and EmployeeIndex=@EmployeeIndex),            
		 @AtClosingStatus,            
		 'At closing integration with CIP - ' + @Remarks,            
		 0,            
		 getdate(),            
		 @UserEmpIndex            
          
		 
		 select @ODIndex =isnull(max(ODIndex),0) from cp_EmpVariablePayDataOther            
		          
		 select @ODIndex + row_number() over (order by c.employeeindex),c.employeeindex,ci.columncode,isnull(sum(c.FieldValue),0) Amount,p.PayrollYear,p.PayrollMonth,'From At Closing ' Remarks            
		 from tm_VwAtClosingData c ,tm_period p ,clientinvat ci where             
		 p.periodindex =@PeriodIndex             
		 and p.periodindex = c.periodindex            
		 and c.employeeindex =@EmployeeIndex                       
		 and ci.clientindex = @ClientIndex            
		 and c.fieldno = ci.FieldNo            
		 and ci.InvoiceNo  = @InvoiceNo            
		 group by c.employeeindex,ci.columncode,p.PayrollYear,p.PayrollMonth            






--		 declare 
--@InvoiceNo int,
--@BuIndex smallint,
--@UnitIndex smallint,
--@clientindex int,
--@employeeindex  int = 397500
--select @Clientindex = Clientindex ,@BuIndex = isnull(buindex,0) , @UnitIndex = isnull(UnitIndex,0) from employee where employeeindex = @EmployeeIndex

--select @InvoiceNo = cd.InvoiceNo from clientinvleveldetail cd ,clientinv c             
--			where c.clientindex = @Clientindex and worklocation = @BuIndex            
--			and c.clientindex = cd.clientindex            
--			and c.invoiceno = cd.invoiceno             
--			and c.invoicetype = 1    

--select @InvoiceNo , @BuIndex

--select @InvoiceNo = c.InvoiceNo from clientinv c where c.clientindex = @Clientindex  and c.invoicetype = 1 

--select @InvoiceNo

--select @InvoiceNo = cd.InvoiceNo from clientinvleveldetail cd ,clientinv c               
--			where c.clientindex = @Clientindex and worklocation = @UnitIndex            
--			and c.clientindex = cd.clientindex              
--			and c.invoiceno = cd.invoiceno               
--			and c.invoicetype = 1 

--select @InvoiceNo , @UnitIndex