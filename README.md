# perl load generator for DB2 LUW
This perl script can take any dynamic sql, read aruguments from "multiple" files and simulate concurrent users or a single user. This scipt was written since db2batch can only simulate one connection. This script can take advanatge of the DSDRIVER and WLB for purescale DB2 Systems.

"Multiple arguments" files are needed to simulate "Multiple users". 

Therefore if you want to simulate 5 concurrent users, you will need at least 5 argument files, if you have more than 5 then the script will keep process it after the one of the forked process are freed up.


# PART 1 

Generate you argument files and arguments are comma delmited. Sample argument files have been generated for the example below
Please not you will need multiple argumant files to generate the load. e.g. if you have 100 argument files, you can have a between 1 and 100(max) concurrent executions.

If all you arguments are in one file use the "split" command to split it into multiple files.
https://www.computerhope.com/unix/usplit.htm

# PART 2

Generate the load

2_execute_sql

You will need the following perl modules in addtion to the full db2 client.

# If using Ubuntu, prior to installing the full db2 client, install the following as root

	apt-get install libpam0g:i386  	--https://askubuntu.com/questions/428072/64-bit-db2-10-5-missing-32-bit-libpam-and-64-bit-libaio-on-ubuntu-12-04 
	apt-get install libstdc++6		--https://askubuntu.com/questions/409821/libstdc-so-6-cannot-open-shared-object-file-no-such-file-or-directory

	
# During installing the full db2 client, ensure you select "Custom" and select the development libaries

# As root install the perl modules below:

	cpan App::cpanminus
	cpanm Parallel::ForkManager
	cpanm DateTime
	cpanm Term::ReadKey
	cpanm DBI
	cpanm DBI
	
Download DBD:Db2 from CPAN
https://metacpan.org/pod/distribution/DBD-DB2/DB2.pod

	export env DB2_HOME (under root)
	perl Makefile.PL            # use a perl that's in your PATH
	make
	make test
	make install (if the tests look okay)

# Sample Call
# Clean output directory first
    
    rm /tmp/out/*
    
    ./2_execute_sql/perl_load_generator_v2.pl -t SAMPLE -u db2inst1 -d './sample_arguments' -s 'select * from employee where salary > ? and HIREDATE > ?' -p SQL* -o /tmp/out -r print -c2
    

# usage: perl <script.pl> <options>
	-d <directory>	specify directory in which to find parameter files.
	-t <target db name>	specify the target database.
    -p Post fix  input file pattern, that contains the arguments use regular expression
    -u User ID for the DB
    -s Provide the SQL or SP call.
    -c Number of child processes  
    -o Output log files
    -r Print result set

# PART 3

Analyze the output
	
	Ensure the target tables are created (Create_tables_run_1.sql)
	
	./3_parse_output_logs/perl_parse_load_generator_logs_v2.pl -u db2inst1 -d  /tmp/out -r 2000 -t SAMPLE -s 'Description Testing Dynamic SQL ' -c 100 -p 'SQL.*'

# Misc

Sample Catalog command for SAMPLE DB in community edition

	db2 CATALOG TCPIP NODE DB2INST1 REMOTE 192.168.142.41 SERVER 50000 REMOTE_INSTANCE  db2inst1 SYSTEM  192.168.142.41 OSTYPE LINUX
	db2 CATALOG DATABASE SAMPLE AS SAMPLE AT NODE DB2INST1


Summary table  -- DB2INST1.LOAD_TEST_PERL

Detail table -- DB2INST1.LOAD_TEST_PERL_DETAILS
 
# Sample query to get summery of the performance stats for the run

 

	SELECT ID,
	AVG(ROWS_RETURNED) AS AVG_ROWS_RETURNED,
	AVG(EXEC_IN_SEC) AS AVG_EXEC_IN_SEC,
	AVG(FETCH_IN_SEC) AS AVG_FETCH_IN_SEC,
	MAX(ROWS_RETURNED) AS MAX_ROWS_RETURNED,
	MAX(EXEC_IN_SEC) AS MAX_EXEC_IN_SEC,
	MAX(FETCH_IN_SEC) AS MAX_FETCH_IN_SEC,
	SUM(ROWS_RETURNED) AS SUM_ROWS_RETURNED,
	SUM(EXEC_IN_SEC) AS SUM_EXEC_IN_SEC,
	SUM(FETCH_IN_SEC) AS SUM_FETCH_IN_SEC,
	count(*) as COMPLETED_CALLS,
	SUM(EXEC_IN_SEC)/(count(*)) AS COMPLETED_CALLS_PER_SEC_EXEC_IN_SEC,
	SUM(FETCH_IN_SEC)/(count(*)) AS COMPLETED_CALLS_PER_SEC_FETCH_IN_SEC
	FROM DB2INST1.LOAD_TEST_PERL_DETAILS
	where id in (2000)  <- subtitue the right run id
	and ROWS_RETURNED > 0
	group by  ID
	order by  ID;

 

--Query the table whichever way you like, it has details for every single sql call with arguments.

	select * from DB2INST1.LOAD_TEST_PERL_DETAILS where ID = 3001 and EXEC_IN_SEC > 4

	select count(*) from DB2INST1.LOAD_TEST_PERL_DETAILS where ID = 3003 and (EXEC_IN_SEC + FETCH_IN_SEC) < 1

	 
	select (case when FETCH_IN_SEC < 1 then 'range1'
	when FETCH_IN_SEC between 1 and 2 then 'range2'
	when FETCH_IN_SEC between 2 and 3 then 'range3'
	else 'other'
	end) as range, count(*) as cnt
	from DB2INST1.LOAD_TEST_PERL_DETAILS
	where ID = 5001
	and ROWS_RETURNED > 0
	group by (case when FETCH_IN_SEC < 1 then 'range1'
	when FETCH_IN_SEC between 1 and 2 then 'range2'
	when FETCH_IN_SEC between 2 and 3 then 'range3'
	else 'other'
	end)
	order by range ;

 
--Between 1 and 100 rows, adjust as needed

	select (case when FETCH_IN_SEC < 1 then 'range1'
	when FETCH_IN_SEC between 1 and 2 then 'range2'
	when FETCH_IN_SEC between 2 and 3 then 'range3'
	when FETCH_IN_SEC between 3 and 4 then 'range4'
	else 'other'
	end) as range, count(*) as cnt
	from DB2INST1.LOAD_TEST_PERL_DETAILS
	where ID = 725
	and ROWS_RETURNED > 0 and ROWS_RETURNED < 100
	group by (case when FETCH_IN_SEC < 1 then 'range1'
	when FETCH_IN_SEC between 1 and 2 then 'range2'
	when FETCH_IN_SEC between 2 and 3 then 'range3'
	when FETCH_IN_SEC between 3 and 4 then 'range4'
	else 'other'
	end)
	order by range;

# Other SQL queries to monitor SQL performance in  DB2 10.5 and higher.

	SELECT
	"SECTION_TYPE" AS SECTION_TYPE,
	"EXECUTABLE_ID" AS EXECUTABLE_ID,
	"NUM_COORD_EXEC" AS NUM_COORD_EXEC,
	"NUM_COORD_EXEC_WITH_METRICS" AS NUM_COORD_EXEC_WITH_METRICS,
	"TOTAL_STMT_EXEC_TIME" AS TOTAL_STMT_EXEC_TIME,
	"AVG_STMT_EXEC_TIME" AS AVG_STMT_EXEC_TIME,
	"TOTAL_CPU_TIME" AS TOTAL_CPU_TIME,
	"AVG_CPU_TIME" AS AVG_CPU_TIME,
	"TOTAL_LOCK_WAIT_TIME" AS TOTAL_LOCK_WAIT_TIME,
	"AVG_LOCK_WAIT_TIME" AS AVG_LOCK_WAIT_TIME,
	"TOTAL_IO_WAIT_TIME" AS TOTAL_IO_WAIT_TIME,
	"AVG_IO_WAIT_TIME" AS AVG_IO_WAIT_TIME,"PREP_TIME" AS PREP_TIME,"ROWS_READ_PER_ROWS_RETURNED" AS ROWS_READ_PER_ROWS_RETURNED,
	"AVG_ACT_WAIT_TIME" AS AVG_ACT_WAIT_TIME,"AVG_LOCK_ESCALS" AS AVG_LOCK_ESCALS,"AVG_RECLAIM_WAIT_TIME" AS AVG_RECLAIM_WAIT_TIME,
	"AVG_SPACEMAPPAGE_RECLAIM_WAIT_TIME" AS AVG_SPACEMAPPAGE_RECLAIM_WAIT_TIME,
	"STMT_TEXT" AS STMT_TEXT,
	 current time
	FROM "SYSIBMADM"."MON_PKG_CACHE_SUMMARY"
	WHERE STMT_TEXT LIKE '% Insert sql pattern %'  <-- Inset matching SQL here
	order by NUM_COORD_EXEC desc, TOTAL_CPU_TIME desc
	FETCH FIRST 500 ROWS ONLY
	with ur;

	
	--Get all the procedures with used withon the last 10mins
	SELECT MEMBER,
    SECTION_TYPE , 
    TOTAL_CPU_TIME/NUM_EXEC_WITH_METRICS as  
    AVG_CPU_TIME, NUM_EXECUTIONS, 
    EXECUTABLE_ID, STMT_TEXT
    FROM TABLE(MON_GET_PKG_CACHE_STMT ( NULL, NULL, '<modified_within>10</modified_within>', -2)) as T 
    WHERE STMT_TEXT LIKE '%PRDISTRIB%' ORDER BY NUM_EXECUTIONS desc    
	
	


	--Get all the procedures with schema "SCHEMA"
	SELECT ROUTINE_TYPE, ROUTINE_SCHEMA, ROUTINE_NAME, SPECIFIC_NAME, TOTAL_CPU_TIME , TOTAL_TIMES_ROUTINE_INVOKED, MEMBER, ROWS_READ, ROWS_RETURNED, ROWS_READ/ROWS_RETURNED as ratio   
	FROM TABLE(MON_GET_ROUTINE('P', 'SCHEMA', NULL, NULL, -2)) 
	AS T ORDER BY ROUTINE_NAME, MEMBER DESC
   
   
--Get details of each execution iD (Breakdown where the waits are coming from)
   
   SELECT * FROM TABLE(MON_GET_PKG_CACHE_STMT(NULL, x'<execid>', NULL, -2)) AS T

   
# Other SQL queries to monitor SQL performance in  DB2 9.7 and higher.
	
	SELECT
	"SECTION_TYPE" AS SECTION_TYPE,
	"EXECUTABLE_ID" AS EXECUTABLE_ID,
	"NUM_COORD_EXEC" AS NUM_COORD_EXEC,
	"NUM_COORD_EXEC_WITH_METRICS" AS NUM_COORD_EXEC_WITH_METRICS,
	"TOTAL_STMT_EXEC_TIME" AS TOTAL_STMT_EXEC_TIME,
	"AVG_STMT_EXEC_TIME" AS AVG_STMT_EXEC_TIME,
	"TOTAL_CPU_TIME" AS TOTAL_CPU_TIME,
	"AVG_CPU_TIME" AS AVG_CPU_TIME,
	"TOTAL_LOCK_WAIT_TIME" AS TOTAL_LOCK_WAIT_TIME,
	"AVG_LOCK_WAIT_TIME" AS AVG_LOCK_WAIT_TIME,
	"TOTAL_IO_WAIT_TIME" AS TOTAL_IO_WAIT_TIME,
	"AVG_IO_WAIT_TIME" AS AVG_IO_WAIT_TIME,
	"PREP_TIME" AS PREP_TIME,
	"ROWS_READ_PER_ROWS_RETURNED" AS ROWS_READ_PER_ROWS_RETURNED,
	--"AVG_ACT_WAIT_TIME" AS AVG_ACT_WAIT_TIME,
	--"AVG_LOCK_ESCALS" AS AVG_LOCK_ESCALS,
	--"AVG_RECLAIM_WAIT_TIME" AS AVG_RECLAIM_WAIT_TIME,
	--"AVG_SPACEMAPPAGE_RECLAIM_WAIT_TIME" AS AVG_SPACEMAPPAGE_RECLAIM_WAIT_TIME,
	"STMT_TEXT" AS STMT_TEXT
	FROM "SYSIBMADM"."MON_PKG_CACHE_SUMMARY"
	WHERE STMT_TEXT LIKE '% insert sql pattern %'  <-- Inset matching SQL here
	order by TOTAL_CPU_TIME desc , NUM_COORD_EXEC desc
	FETCH FIRST 100 ROWS ONLY
	with ur;

   
	

# Enjoy!


