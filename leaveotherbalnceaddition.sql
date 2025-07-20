
Alter procedure [dbo].[sp_Leaves_LandingPageGrid]
@UserId char(20) ,              
@EmployeeIndex int,              
@FromDate date ='1/1/1900'   ,
@UserEmpindex int = 0,
@LanguageIndex tinyint= 1
as
--declare
--@UserId char(20) ='',              
--@EmployeeIndex int=271468,              
--@FromDate date ='2024-02-26',
--@UserEmpindex int = 224214
 begin                

if @UserEmpindex>0
	if @UserEmpindex <> @EmployeeIndex
		begin
			IF OBJECT_ID('tempdb.dbo.#Emp', 'U') IS NOT NULL
			DROP TABLE #Emp; 
			select EmployeeIndex 
			into  #Emp
			from 
				(
				select EmployeeIndex From acm_VwEmpAuthority where UserEmpIndex = @UserEmpindex and WLCat = 3
				union all
				select EmployeeIndex from Employee where ISNULL(LMIndex,0) = @UserEmpindex 
				) t
			if not exists (select * from #Emp where EmployeeIndex = @EmployeeIndex)
				set @EmployeeIndex = 999999999
		end
 declare @Dt as datetime, @LeaveType tinyint, @ClientIndex smallint, @ServiceStatus tinyint , @ServiceEndDate datetime  ,@Lvgroup smallint            
 Declare @OtherLvType smallint,@EntitlementDurationMonths tinyint  ,@EntitlementStartDate tinyint,@MaxAllowed float,@OFromdate date ,@OToDate date      
 declare @CStart Date , @CEnd date , @FD date
 if @FromDate='1/1/1900'         
 set @FromDate=getdate()      
 --set @FromDate='2022-04-01' -- Temp check to show the march short leave in april          
  if @EmployeeIndex=0               
   select @EmployeeIndex = employeeindex from RegisteredUsers where UserID=@UserId              
  select  @ClientIndex = ClientIndex, @ServiceStatus = ServiceStatus , @ServiceEndDate = ServiceEndDate ,@Lvgroup = isnull(Lvgroup,0)            
  from   Employee             
  where   employeeindex = @EmployeeIndex              
  --select @ClientIndex = ClientIndex from Employee where EmployeeIndex=@EmployeeIndex                
  if @ServiceStatus = 1              
  begin               
    set @Dt=convert(datetime,convert(char,@FromDate,101),101)              
  end              
  Else              
  begin              
    set @Dt=convert(datetime,convert(char,@ServiceEndDate,101),101)              
  end               
            
-----------------------------------------------------------------------------------------------------------------            
----------------monthly entitlement of any leave type configure for client  (2022-05-17  SAAD)-------------------            
  if exists (select * from LeaveRules where lvgroup = @Lvgroup and ClientIndex = @ClientIndex and IsMonthlyOtherBalance >0 )            
  begin            
 
--select @OtherLvType =leavetype,@MaxAllowed = isnull(IsMonthlyOBEntitlement,0)  from LeaveRules where lvgroup = @Lvgroup and ClientIndex = @ClientIndex and IsMonthlyOtherBalance >0            

declare 
@OtherLvType2 int,
@MaxAllowed2 float,
@OtherLvType3 int,
@MaxAllowed3 float


DECLARE @LeaveDetails TABLE (
	sno int,
    LeaveType INT,
    MaxAllowed float
);

INSERT INTO @LeaveDetails (sno,LeaveType, MaxAllowed)
SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS sno,leavetype,ISNULL(IsMonthlyOBEntitlement, 0) 
FROM LeaveRules WHERE lvgroup = @Lvgroup AND ClientIndex = @ClientIndex AND IsMonthlyOtherBalance > 0;


select @OtherLvType =leavetype,@MaxAllowed = isnull(MaxAllowed,0)  from @LeaveDetails where sno = 1
select @OtherLvType2 =leavetype,@MaxAllowed2 = isnull(MaxAllowed,0)  from @LeaveDetails where sno = 2
select @OtherLvType3 =leavetype,@MaxAllowed3 = isnull(MaxAllowed,0)  from @LeaveDetails where sno = 3



 if exists (select 1 from @LeaveDetails where sno = 1) and not exists (select * from leaveotherbalance where employeeindex  =@EmployeeIndex and leavetype = @OtherLvType and month(FromDate) = month(@FromDate) and Year(FromDate) = Year(@FromDate))--Year(FromDate) = (@FromDate)  added as per task SG-1                
 begin            
  select  @EntitlementDurationMonths= isnull(EntitlementDurationMonths,0),            
    @EntitlementStartDate=isnull(EntitlementStartDate,0)            
  from    tm_CompLeaveRules             
  where   ClientIndex = @ClientIndex             
    and leavetype = @OtherLvType            
  SET @OFromdate = CONVERT(VARCHAR(7), @FromDate, 120) +'-'+convert(varchar,@EntitlementStartDate)            
         
  SET @OToDate = dateadd(dd,-1,dateadd(mm,@EntitlementDurationMonths,@OFromdate))            
      
  insert into leaveotherbalance             
  (EmployeeIndex,LOBIndex,LeaveType,FromDate,ToDate,Allowed,Availed,Lapsed,Balance,Remarks,PostBy,PostDate,ReferenceDate,LOBSource,HoursAdjusted)             
  values (@EmployeeIndex,            
    (select isnull(max(LOBIndex),0)+1 from LeaveOtherBalance where employeeindex=@EmployeeIndex),            
    @OtherLvType,            
    @OFromDate,            
    @OToDate,            
    @MaxAllowed,            
    0,            
    0,            
    @MaxAllowed,            
    '',            
    1192,            
    getdate(),            
    @OFromDate,            
    4,            
    0)            
 end   
 
 if exists (select 1 from @LeaveDetails where sno = 2) and not exists (select * from leaveotherbalance where employeeindex  =@EmployeeIndex and leavetype = @OtherLvType2 and month(FromDate) = month(@FromDate) and Year(FromDate) = Year(@FromDate))--Year(FromDate) = (@FromDate)  added as per task SG-1                
 begin            
  select  @EntitlementDurationMonths= isnull(EntitlementDurationMonths,0),            
    @EntitlementStartDate=isnull(EntitlementStartDate,0)            
  from    tm_CompLeaveRules             
  where   ClientIndex = @ClientIndex             
    and leavetype = @OtherLvType2            
  SET @OFromdate = CONVERT(VARCHAR(7), @FromDate, 120) +'-'+convert(varchar,@EntitlementStartDate)            
           
  SET @OToDate = dateadd(dd,-1,dateadd(mm,@EntitlementDurationMonths,@OFromdate))            
          
  insert into leaveotherbalance             
  (EmployeeIndex,LOBIndex,LeaveType,FromDate,ToDate,Allowed,Availed,Lapsed,Balance,Remarks,PostBy,PostDate,ReferenceDate,LOBSource,HoursAdjusted)             
  values (@EmployeeIndex,            
    (select isnull(max(LOBIndex),0)+1 from LeaveOtherBalance where employeeindex=@EmployeeIndex),            
    @OtherLvType2,            
    @OFromDate,            
    @OToDate,            
    @MaxAllowed2,            
    0,            
    0,            
    @MaxAllowed2,            
    '',            
    1192,            
    getdate(),            
    @OFromDate,            
    4,            
    0)            
 end 
 
 if exists (select 1 from @LeaveDetails where sno = 3) and not exists (select * from leaveotherbalance where employeeindex  =@EmployeeIndex and leavetype = @OtherLvType3 and month(FromDate) = month(@FromDate) and Year(FromDate) = Year(@FromDate))--Year(FromDate) = (@FromDate)  added as per task SG-1                
 begin            
  select  @EntitlementDurationMonths= isnull(EntitlementDurationMonths,0),            
    @EntitlementStartDate=isnull(EntitlementStartDate,0)            
  from    tm_CompLeaveRules             
  where   ClientIndex = @ClientIndex             
    and leavetype = @OtherLvType3            
  SET @OFromdate = CONVERT(VARCHAR(7), @FromDate, 120) +'-'+convert(varchar,@EntitlementStartDate)            
          
  SET @OToDate = dateadd(dd,-1,dateadd(mm,@EntitlementDurationMonths,@OFromdate))            
        
  insert into leaveotherbalance             
  (EmployeeIndex,LOBIndex,LeaveType,FromDate,ToDate,Allowed,Availed,Lapsed,Balance,Remarks,PostBy,PostDate,ReferenceDate,LOBSource,HoursAdjusted)             
  values (@EmployeeIndex,            
    (select isnull(max(LOBIndex),0)+1 from LeaveOtherBalance where employeeindex=@EmployeeIndex),            
    @OtherLvType3,            
    @OFromDate,            
    @OToDate,            
    @MaxAllowed3,            
    0,            
    0,            
    @MaxAllowed3,            
    '',            
    1192,            
    getdate(),            
    @OFromDate,            
    4,            
    0)            
 end            
  end            
----------------monthly entitlement of any leave type configure for client  (2022-05-17  SAAD)-------------------   
-------------------------------------------------------------------------------------------------------------------            
  declare cur_Leaves cursor for              
  select leavetype from leavetype where leavetype in (select LeaveType from leaveclientmapping where clientindex=@ClientIndex and isnull(allowbalance,0)=1)              
           
  open cur_Leaves              
  fetch next from cur_Leaves into @LeaveType              
  while @@FETCH_STATUS=0              
  begin              
   declare @Dt2 datetime = dateadd(yy,1,@Dt)                
   exec sp_leaves_calculation  @EmployeeIndex, @LeaveType, @Dt, 0, 1              
   exec sp_leaves_calculation  @EmployeeIndex, @LeaveType, @Dt2, 0, 1              
   fetch next from cur_Leaves into @LeaveType              
  end              
  close cur_Leaves              
  deallocate cur_Leaves              
    
   select @cstart=FromDate,
		  @Cend = Todate
		  From fnleaveperiod (@EmployeeIndex,@FromDate) lp
	Where lp.leavetype = @leavetype
	select @FD = '03/' + convert(varchar(2),DATEPART(DD,fromdate))+'/'+ convert(varchar(4),DATEPART(YYYY,fromdate)) from dbo.fnLeavePeriod(@EmployeeIndex,@FromDate) where leavetype =3
--   if exists(select employeeindex from Employee where EmployeeIndex=@EmployeeIndex and @ClientIndex=914 and ServiceStatus<>1 and (ServiceEndDate<>convert(date,'1/1/1900') or ContractEndDate<>convert(date,'1/1/1900')))   
if exists (select employeeindex from Employee where EmployeeIndex=@EmployeeIndex and @ClientIndex=914 and  --((ServiceStatus<>1 and 
((ServiceEndDate<>convert(date,'1/1/1900')) or ContractEndDate<>convert(date,'1/1/1900')) and isnull(ContractEndDate,'1/1/1900') between @cstart and @CEnd )
  begin  
  If @EmployeeIndex in (select lob.EmployeeIndex from LeaveOtherBalance lob, LeaveType lt               
    left outer join LeaveClientMapping lcm on lcm.LeaveType=lt.LeaveType and lcm.ClientIndex=@ClientIndex              
  where lob.LeaveType=lt.LeaveType               
    and convert(date,@Dt) between lob.FromDate and lob.ToDate              
    and lob.EmployeeIndex=@EmployeeIndex --164320              
 and @ClientIndex <> 1206  )
	begin
	select lt.LeaveType,isnull(isnull(ltl.LeaveDescription, lcm.leavedescription), lt.LeaveDescription) + ' (' + ltrim(rtrim(convert(char,FromDate,107))) + ' to ' + ltrim(rtrim(convert(char,ToDate,107))) + ')' LeaveDescription,               
    0 Opening,               
    lob.Allowed ,              
    lob.Availed,              
    0 Deducted,              
    0 Encashed,              
    lob.Balance               
  from LeaveOtherBalance lob, LeaveType lt  
	left JOIN 	LeaveTypeTitle ltl ON ltl.LeaveTypeIndex = lt.LeaveType and ltl.LanguageIndex = @LanguageIndex	
    left outer join LeaveClientMapping lcm on lcm.LeaveType=lt.LeaveType and lcm.ClientIndex=@ClientIndex              
  where lob.LeaveType=lt.LeaveType               
    and convert(date,@Dt) between lob.FromDate and lob.ToDate              
    and lob.EmployeeIndex=@EmployeeIndex --164320              
 and @ClientIndex <> 1206  
	End
	Else
	Begin
  select lt.LeaveType, isnull(isnull(ltl.LeaveDescription, lcm.leavedescription), lt.LeaveDescription)LeaveDescription,               
    convert(float,lb.Opening) Opening,               
    (case when convert(float,lb.Availed)+0+0.0+convert(float,lb.Balance)=0 then 0.0 else convert(float,lb.Entitlement) end ) Allowed ,              
    --lb.Entitlement Allowed,              
    convert(float,lb.Availed) Availed,              
    convert(float,0.0) Deducted,              
    convert(float,0.0) Encashed,              
	convert(float,lb.Balance+isnull(fbx.Opening,0)) Balance               
  from fnLeaveBalanceFS(@EmployeeIndex) lb  
  inner join  employee e on lb.EmployeeIndex = e.EmployeeIndex 
  inner join LeaveType lt on lb.LeaveType = lt.LeaveType 
  	left JOIN 	LeaveTypeTitle ltl ON ltl.LeaveTypeIndex = lt.LeaveType and ltl.LanguageIndex = @LanguageIndex
    left outer join LeaveClientMapping lcm on lcm.LeaveType=lt.LeaveType and lcm.ClientIndex=@ClientIndex   
	left outer join (select Employeeindex,opening from fnLeaveBalance_extend (@employeeindex,@FD) ) Fbx on fbx.EmployeeIndex = lb.EmployeeIndex
  where isnull(lcm.allowbalance,0)=1       
    end
  end  
  else  
  begin  
  select lt.LeaveType, isnull(isnull(ltl.LeaveDescription, lcm.leavedescription), lt.LeaveDescription)LeaveDescription,               
    lb.Opening,               
    (case when lb.Availed+lb.Adjusted+lb.Encashed+lb.Balance=0 then 0 else lb.Entitlement end ) Allowed ,              
    --lb.Entitlement Allowed,              
    lb.Availed,              
    lb.Adjusted Deducted,              
    lb.Encashed,              
    lb.Balance               
  from fnLeaveBalance (@EmployeeIndex,@Dt) lb,  employee e, LeaveType lt
    left JOIN 	LeaveTypeTitle ltl ON ltl.LeaveTypeIndex = lt.LeaveType and ltl.LanguageIndex = @LanguageIndex
    left outer join LeaveClientMapping lcm on lcm.LeaveType=lt.LeaveType and lcm.ClientIndex=@ClientIndex              
  where lb.LeaveType=lt.LeaveType               
    and lb.employeeindex = e.employeeindex              
    and isnull(lcm.allowbalance,0)=1               
    and (lt.LeaveType not in (4,64,65) or isnull(e.Gender,'M') ='F' ) --and isnull(married,'o') in ('M','D','W'))              
    and (lt.LeaveType not in (10,82) or isnull(e.Gender,'M') <>'F') --and isnull(married,'o') in ('M','D','W'))              
 and @ClientIndex <> 1206  
  union all                        
  select lt.LeaveType, isnull(isnull(ltl.LeaveDescription, lcm.leavedescription), lt.LeaveDescription) + ' (' + ltrim(rtrim(convert(char,FromDate,107))) + ' to ' + ltrim(rtrim(convert(char,ToDate,107))) + ')' LeaveDescription,               
    0 Opening,               
    lob.Allowed ,              
    lob.Availed,              
    0 Deducted,              
    0 Encashed,              
    lob.Balance               
  from LeaveOtherBalance lob, LeaveType lt
    left JOIN 	LeaveTypeTitle ltl ON ltl.LeaveTypeIndex = lt.LeaveType and ltl.LanguageIndex = @LanguageIndex
    left outer join LeaveClientMapping lcm on lcm.LeaveType=lt.LeaveType and lcm.ClientIndex=@ClientIndex              
  where lob.LeaveType=lt.LeaveType               
    and convert(date,@Dt) between lob.FromDate and lob.ToDate              
    and lob.EmployeeIndex=@EmployeeIndex --164320              
 and @ClientIndex <> 1206  
end              
 end              
return
