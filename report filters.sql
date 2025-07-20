
delete from rpt_MainFilters where ReportIndex = 1741;
delete from rpt_main where ReportIndex = 1741;


insert into screens values (13629,'Invalid Entries Report in Excel',0,0,0,0,0,null,null,0,null)

insert into rpt_main values (1741,'tm_Rpt_Qry_InvalidEntries_01','Invalid Entries Report in Excel',
'Invalid Entries Report in Excel','../TMS/CustomAttendanceReport.aspx?', null,1,53,136,13629,1,2,1,null);;



insert into rpt_MainFilters values (1741,1231,10,'From Date',1);;
insert into rpt_MainFilters values (1741,1231,12,'To Date',1.1);;
insert into rpt_MainFilters values (1741,1231,49,'Employee',1.1);;
insert into rpt_MainFilters values (1741,1231,20,'Department Name',1.1);;
insert into rpt_MainFilters values (1741,1231,26,'SubDepartment',1.1);;
insert into rpt_MainFilters values (1741,1231,21,'Location',1.1);;
insert into rpt_MainFilters values (1741,1231,23,'Territory',1.1);;
insert into rpt_MainFilters values (1741,1231,24,'Unit',1.1);;
insert into rpt_MainFilters values (1741,1231,25,'Division',1.1);;
insert into rpt_MainFilters values (1741,1231,33,'BusinessUnit',1.1);;
insert into rpt_MainFilters values (1741,1231,48,'ServiceStatus',1.1);;
insert into rpt_MainFilters values (1741,1231,29,'Grade',1.1);;
insert into rpt_MainFilters values (1741,1231,31,'Team',1.1);;


select * from rpt_main where reportcode = 'tm_Rpt_Qry_PendingLeaves_01'

select * from screens where screenno =  13624


insert into screens values ((select max(ScreenNo) + 1 from screens),'Invalid Entries Report in Excel',0,0,0,0,0,null,null,0,null)
select max(screenno) from screens


insert into rpt_main values ((select max(reportindex) + 1 from rpt_main),'tm_Rpt_Qry_InvalidEntries_01','Invalid Entries Report in Excel',
'Invalid Entries Report in Excel','../TMS/CustomAttendanceReport.aspx?', null,1,53,136,13629,1,2,1,null);;

select max(reportindex) from Rpt_Main
