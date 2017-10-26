#! /db2admin/perl/bin/perl -I/db2admin/perl/perlsub

use strict;
use warnings;
use Data::Dumper;
use DBI;
use DBD::DB2::Constants;
use DBD::DB2;
use Net::Netrc;
use Getopt::Std;
use Term::ReadKey;

use DBD::DB2 qw($attrib_int $attrib_char $attrib_float $attrib_date $attrib_ts);

$|=1;

#BEGIN Global variables
my $rc = undef; # Return code
   #BEGIN Define Environment from admin DB
my $Repository_Instance="db2udp1q";
my $udp1q_DB="UDP1Q";
my $udp3q_DB="UDP3Q";
my $Repository_User="tu01945";
my $Repository_UserType="tu01945";
my $HeartLocation="/db2admin/.heart";

my $records = undef;
my $records_read = undef;
my $file_name = undef;
my $record_cnt = 0;
my $file_cnt = undef;

my $fh_proc1 = undef;
my $fh_proc2 = undef;

 my $dbh = undef;
 my $cur1 = undef;
 my $n = undef;
 my $ts1 = undef;
 my $ts2 = undef;
 my $id = undef;
 my $smonth = undef;
 my $emonth = undef;
 my $sday = undef;
 my $eday = undef;
 my $out_file_1 = undef;
 my $out_file_2 = undef;
 my $fh_property_file_udp1q = undef;
 my $fh_property_file_udp3q = undef;

 
 #Get Options
my %opts;
# Get command line options d: directory of files; u: DB user ID; t: Target DB;  s: Stored proc call; c: concurrent child processes
getopts( 'u:p:r:b:', \%opts );
 
# Global Variables to hold arguments.
my $DB_User_ID                      = undef;
my $arugment_file_name_prefix       = undef;
my $number_records_to_select        = undef;
my $batch_size_of_records           = undef;

#Set Global Varaibles
$DB_User_ID                = $opts{"u"};
$arugment_file_name_prefix = $opts{"p"};
$number_records_to_select  = $opts{"r"};
$batch_size_of_records     = $opts{"b"};

=pod
print "Type your password for $DB_User_ID\@$udp1q_DB and $udp3q_DB:";
ReadMode('noecho');    # don't echo
my $DB_User_ID_Password = ReadLine(0);
ReadMode(0);           # back to normal
=cut 
 

sub main {

    if ( !checkusage( \%opts ) ) {
        print Dumper( \%opts );
        usage();
        exit ();
    }

    # Print options passed
    print Dumper( \%opts );
    
    print "Type your password for $DB_User_ID\@$udp1q_DB and $udp3q_DB:";
    ReadMode('noecho');    # don't echo
    my $DB_User_ID_Password = ReadLine(0);
    ReadMode(0);           # back to normal
 
 
    
    
    $file_name      = $arugment_file_name_prefix;  
    $records_read   = $number_records_to_select;
    $records        = $batch_size_of_records;
    
    $file_name = 'SQL' unless $file_name;
    $records_read = 1000000 unless $records_read;
    $records = 1000 unless $records;
    
    print "\n\nFile Prefix is: $file_name; Records to read is: $records_read and Batch size is: $records\n";

   # Connect to DB Server
   $dbh = DBI->connect("dbi:DB2:$udp1q_DB", $DB_User_ID, $DB_User_ID_Password, {
                                                                                                   PrintError => 0,
                                                                                                   RaiseError => 0}
                               ) or die "Can't connect to $udp1q_DB :$!\n";

   $dbh->{ChopBlanks}=1;
    #print "DB_UDP1Q Handle: $dbh\n";

    $cur1 = $dbh->prepare(qq{
         select ID from (
                        select ID
                        from lwro1p.prsnid
                        where DATA_STATUS_CDE = 'V'
                        AND XEPRUN_ENTRPS_UNIT_TYPE_CDE = 'MEDREC'
                        AND XEPRUN_ID = 'MRENTR'
                        AND END_TS = '9999-12-31 23:59:59.999999'
          )
        FETCH FIRST $records_read ROWS ONLY
    }) or die "Can't prepare statement: $DBI::errstr";

    $rc = $cur1->execute
        or die "Can't execute statement: $DBI::errstr";

    $n=0;
    $ts1 = time;
    $ts2 = $ts1;


    while (my @flds1 = $cur1->fetchrow())
    {
        unless (($record_cnt / $records) - int($record_cnt / $records)) {
            print ".";
            $record_cnt++;
            $file_cnt++;
            my $out_file_1 = sprintf"udp1q_getlabs_arguments_only/%s_sp_SP_GET_LAB_RESULTS_%06u", $file_name, $file_cnt;
            close $fh_proc1 if $fh_proc1;
            $fh_proc1 = undef;
            $fh_proc2 = undef;
            open ($fh_proc1, ">", $out_file_1) or die "unable to open file: $out_file_1, $!";
        } else {
            $record_cnt++;
        }

    	$id = $flds1[0];
#       print "$record_cnt\n";

        $smonth = int(rand(12)) + 1;
        $emonth = int(rand(12)) + 1;
        #Used 28 so I do not have to deal with feb.
        $sday = int(rand(28)) + 1;
        $eday = int(rand(28)) + 1;

        print $fh_proc1 "'$id','2015-$smonth-$sday 00:00:00','2016-$emonth-$eday 00:00:00',10000642\n";
    }
    $cur1->finish;
    # Disconnect from database
    $dbh->disconnect();
    close $fh_proc1 if $fh_proc1;

    # Connect to DB Server
    $dbh = DBI->connect("dbi:DB2:$udp3q_DB", $DB_User_ID, $DB_User_ID_Password, {
                                                                                                   PrintError => 0,
                                                                                                   RaiseError => 0}
                               ) or die "Can't connect to $udp3q_DB :$!\n";

    $dbh->{ChopBlanks}=1;
    #print "DB_UDP1Q Handle: $dbh\n";

    $cur1 = $dbh->prepare(qq{
         select ALIAS from (
            SELECT PA.ALIAS
              FROM CERNER_MGP.PERSON_ALIAS PA
             WHERE PA.ALIAS_POOL_CD = 5766                                     
                   AND PA.PERSON_ALIAS_TYPE_CD = 2448                               
                   AND PA.ACTIVE_IND = 1
                   AND PA.END_EFFECTIVE_DT_TM > CURRENT TIMESTAMP
                   AND END_EFFECTIVE_DT_TM > CURRENT TIMESTAMP
        )
        FETCH FIRST $records_read ROWS ONLY
    }) or die "Can't prepare statement: $DBI::errstr";

    $rc = $cur1->execute
        or die "Can't execute statement: $DBI::errstr";

    $n=0;
    $ts1 = time;
    $ts2 = $ts1;
    
    while (my @flds1 = $cur1->fetchrow())
    {
        unless (($record_cnt / $records) - int($record_cnt / $records)) {
            print ".";
            $record_cnt++;
            $file_cnt++;
            $out_file_1 = sprintf"udp3q_getlabs_arguments_only/%s_sp_SP_GET_LABS_%06u", $file_name, $file_cnt;
#            $out_file_2 = sprintf"%s_sp_SP_GET_MOST_RECENT_EPISODE_%06u", $file_name, $file_cnt;
#            print "$out_file_1,$out_file_2\n";
            close $fh_proc1 if $fh_proc1;
#            close $fh_proc2 if $fh_proc2;
            $fh_proc1 = undef;
            $fh_proc2 = undef;
            open ($fh_proc1, ">", $out_file_1) or die "unable to open file: $out_file_1, $!";
        } else {
            $record_cnt++;            
        }
        
    	$id = $flds1[0];
#        print "$record_cnt\n";

        $smonth = int(rand(12)) + 1; 
        $emonth = int(rand(12)) + 1;
        #Used 28 so I do not have to deal with feb.
        $sday = int(rand(28)) + 1; 
        $eday = int(rand(28)) + 1;

        print $fh_proc1 "'$id','2015-$smonth-$sday 00:00:00','2016-$emonth-$eday 00:00:00','All Laboratory'\n";
   }
    $cur1->finish;
    # Disconnect from database
    $dbh->disconnect();
    close $fh_proc1 if $fh_proc1;

}




# Call main subroutine 
main();


### EXIT MAIN SCRIPT
exit;


####################### SUBROUTINES ############################  

sub usage {
    print <<USAGE;
	
usage: perl <script>.pl <options>
    -u User ID for the DB
    -p Pre fix output file pattern, default is "SQL"
    -r records to read
    -b batch size of records per file.
    
    **Please note the SQL to select/generate the arguments and output directory is hard coded, please change as needed.**
    **It will need the directories below**
    **1) udp1q_getlabs_arguments_only**
    **2) udp3q_getlabs_arguments_only**
    
example usage:

    # First clean output directories.
    rm udp1q_getlabs_arguments_only/*
    rm udp3q_getlabs_arguments_only/*

	# Pass the userd id tu01945 or your choice, the default prefix with SQL for the outfiles, reords read will be 1million and batch size will be 1000  	
    <script>.pl -u tu01945
        
    # Pass the userd id tu01945 or your choice, the prefix will be 'SQL_test' for the outfiles in the directory that is hard coded, records read will be 1000 and batch size will be 100,
    # so 10 files files will be created in each directory.  
    <script>.pl -u tu01945 -p SQL_test -r 1000 -b 100

	 	
    
USAGE
}



sub checkusage {
    my $opts = shift;

    my $u = $opts->{"u"};  
 
    
    # u is mandatory.
    unless ( defined($u) ) {
        return 0;
    }
    
    return 1;
}


