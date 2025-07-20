--CREATE procedure [dbo].[fil_check_procNew] --914,'2023-07-01','2023-07-31',276425  
 
-- @ClientIndex int,
-- @FromDate nvarchar(10),  
-- @ToDate nvarchar(10),  
-- @UserEmpIndex int,  
-- @Str varchar(max)=''  

--as  

 begin  
  
  declare   
    @ClientIndex int=914,  
    @FromDate nvarchar(10)='2024-05-01',  
    @ToDate nvarchar(10)='2024-05-10',  
    @UserEmpIndex int = 262610,  
    --@Str nvarchar(100)=  ''  
    @Str nvarchar(100)= 'EmpCls:Regular Staff,Chief-Consultant/Adv' --'WL1:5167,5168'  --'EmpIndx:262610,288335'
  
  declare @Str2 varchar(1000)=''    
  declare @StrRegion varchar(500)=''    
  declare @StrDepartment varchar(500)=''    
  declare @StrLocation varchar(500)=''    
  declare @StrClientBranch varchar(500)=''    
  declare @StrTerritory varchar(500)=''    
  declare @StrUnit varchar(500)=''    
  declare @StrDivision varchar(500)='' 
  declare @strsubDepartment varchar(500)='' --WL9
  declare @strclientGrade varchar(500)='' --WL15
  declare @strTeam varchar(500)='' --WL18
  declare @strEmployeeClass varchar(500)='' --EmpCls:'Chief-Consultant/Adv'
  declare @strPoc varchar(500)='' --Poc
  declare @strMachineLocation varchar(500)=''--MLoc
  declare @strcluster varchar(500)=''--cluster
  declare @StrBU varchar(500)=''    
  declare @StrInvNo varchar(500)=''    
  declare @StrART varchar(500)=''    
  declare @EmpIndx varchar(500)='' 
  declare @SvcStatus varchar(500)='' 

  
  declare cur_LeavePeriod cursor for    
   select col1 from dbo.fnParseArray(@Str,'^')    
  open cur_LeavePeriod    
  fetch next from cur_LeavePeriod into @Str2    
  while @@FETCH_STATUS=0    
  begin    
--  'WL1:3222,25222,1111^WL5:222,221,56'    
   if charindex ('WL1:', @Str2)>0    
    set @StrRegion = REPLACE(@Str2,'WL1:','')    
   if charindex ('WL2:', @Str2)>0    
    set @StrDepartment = REPLACE(@Str2,'WL2:','')    
   if charindex ('WL3:', @Str2)>0    
    set @StrLocation = REPLACE(@Str2,'WL3:','')    
   if charindex ('WL4:', @Str2)>0    
    set @StrClientBranch = REPLACE(@Str2,'WL4:','')    
   if charindex ('WL5:', @Str2)>0    
    set @StrTerritory = REPLACE(@Str2,'WL5:','')    
   if charindex ('WL6:', @Str2)>0    
    set @StrInvNo = REPLACE(@Str2,'WL6:','')    
   if charindex ('WL7:', @Str2)>0    
    set @StrUnit = REPLACE(@Str2,'WL7:','')    
   if charindex ('WL8:', @Str2)>0    
    set @StrDivision = REPLACE(@Str2,'WL8:','')    
   if charindex ('WL9:', @Str2)>0   
   set @strsubDepartment = REPLACE(@Str2,'WL9:','') 
   if charindex ('WL15:', @Str2)>0   
   set @strclientGrade = REPLACE(@Str2,'WL15:','')
   if charindex ('WL18:', @Str2)>0   
   set @strTeam = REPLACE(@Str2,'WL18:','')
   if charindex ('EmpCls:', @Str2)>0   
   set @strEmployeeClass = REPLACE(@Str2,'EmpCls:','')
   if charindex ('Poc:', @Str2)>0   
   set @strPoc = REPLACE(@Str2,'Poc:','')
   if charindex ('MLoc:', @Str2)>0   
   set @strMachineLocation = REPLACE(@Str2,'MLoc:','')
   if charindex ('cluster:', @Str2)>0   
   set @strcluster = REPLACE(@Str2,'cluster:','')
   if charindex ('WL23:', @Str2)>0
    set @StrBU = REPLACE(@Str2,'WL23:','')    
   if charindex ('ART:', @Str2)>0    
    set @StrART = REPLACE(@Str2,'ART:','')   
   if charindex ('EmpIndx:', @Str2)>0    
    set @EmpIndx = REPLACE(@Str2,'EmpIndx:','') 
   if charindex ('SS:', @Str2)>0    
    set @SvcStatus = REPLACE(@Str2,'SS:','') 
   fetch next from cur_LeavePeriod into @Str2    
  end    
  close cur_LeavePeriod    
  deallocate cur_LeavePeriod   
DECLARE @cols NVARCHAR(MAX), @query NVARCHAR(MAX), @selectCols NVARCHAR(MAX); 
--(select col1 from dbo.fnParseArray(@strEmployeeClass,','))


--select OtherDetail1,* from employee where otherdetail1 in ('Chief-Consultant/Adv','Regular Staff') (select col1 from dbo.fnParseArray(@strEmployeeClass,','))

IF OBJECT_ID('tempdb.dbo.#Emp', 'U') IS NOT NULL  
    DROP TABLE #Emp;  -- Drop the temp table if it exists
CREATE TABLE #Emp (
    EmployeeIndex INT
);
 IF LTRIM(RTRIM(ISNULL(@SvcStatus, ''))) = ''
BEGIN
   set @SvcStatus = 1
END
IF LTRIM(RTRIM(ISNULL(@EmpIndx, ''))) <> ''   
BEGIN
    INSERT INTO #Emp (EmployeeIndex)
	select employeeindex from employee where employeeindex in (
    SELECT col1 AS EmployeeIndex 
    FROM dbo.fnParseArray(@EmpIndx, ','))
	and (@SvcStatus='' or ServiceStatus in (select col1 from dbo.fnParseArray(@SvcStatus,',')))
END
ELSE IF LTRIM(RTRIM(ISNULL(@EmpIndx, ''))) = '' 
BEGIN
    INSERT INTO #Emp (EmployeeIndex)
	select employeeindex from employee where employeeindex in (SELECT EmployeeIndex FROM acm_VwEmpAuthority WHERE UserEmpIndex = @UserEmpIndex AND WLCat = 3)
	 and (@SvcStatus='' or ServiceStatus in (select col1 from dbo.fnParseArray(@SvcStatus,','))) 
	 and (@StrRegion='' or RegionIndex in (select col1 from dbo.fnParseArray(@StrRegion,',')))  
	 and (@StrDepartment='' or DepartmentIndex in (select col1 from dbo.fnParseArray(@StrDepartment,',')))  
	 and (@StrLocation='' or LocationIndex in (select col1 from dbo.fnParseArray(@StrLocation,',')))  
	 and (@StrClientBranch='' or ClientBranchIndex in (select col1 from dbo.fnParseArray(@StrClientBranch,',')))  
	 and (@StrTerritory='' or TerritoryIndex in (select col1 from dbo.fnParseArray(@StrTerritory,',')))  
	 and (@StrUnit='' or UnitIndex in (select col1 from dbo.fnParseArray(@StrUnit,',')))  
	 and (@StrDivision='' or DivisionIndex in (select col1 from dbo.fnParseArray(@StrDivision,',')))  
	 and (@StrBU='' or BUIndex in (select col1 from dbo.fnParseArray(@StrBU,',')))
	 and (@strsubDepartment  ='' or SubDepartmentIndex in(select col1 from dbo.fnParseArray(@strsubDepartment,',')))
	 and (@strclientGrade  ='' or GradeIndex in(select col1 from dbo.fnParseArray(@strclientGrade,',')))
	 and (@strTeam  ='' or TeamIndex in(select col1 from dbo.fnParseArray(@strTeam,',')))
	 and (@strEmployeeClass  ='' or otherdetail1 in(select col1 from dbo.fnParseArray(@strEmployeeClass,',')))
	 and (@strPoc  ='' or lm3index in(select col1 from dbo.fnParseArray(@strPoc,',')))
	 and (@strcluster  ='' or Clusterindex in(select col1 from dbo.fnParseArray(@strcluster,',')))	 
END
  
  
 select OtherDetail1,* from employee where employeeindex in (select employeeindex from #Emp)

 end

--select OtherDetail1,* from employee where clientindex = 914