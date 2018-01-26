#! /usr/bin/perl 

=pod
############################################################################

# Script          : parse_perl_logs.pl                                     
# Owner           :                                                        
# Function        :                                                        
# Syntax to invoke:                                                        
# Called by       :                                                        
# Frequency       :                                                        
# Pre-requisites  :                                                        
# Parameter       :                                                        
# Options         :                                                        
# Version         :                                                        
# 1.0   12/30/2016   Sudip Kundu     Initial Version                       
# 2.0   1/12/2017    Sudip Kundu     Parse new output Input SQL {...}
                                     and add -p option for post fix      
############################################################################
=cut

use strict;
use warnings;
use Data::Dumper;
use Getopt::Std;
use DateTime;
use Term::ReadKey;
use Parallel::ForkManager;
use diagnostics;
use Term::ReadKey;


# Prevent buffering
$| = 1;

#DB2 modules
use DBI;
use DBD::DB2;
use DBD::DB2::Constants;
use DBD::DB2 qw($attrib_int $attrib_char $attrib_float $attrib_date $attrib_ts);


# Where the data from the log files will e inserted.
my $Repository_Instance = "db2inst1";
my $Repository_DB       = "SAMPLE";




# Get current date time and set timezone
my $dt = DateTime->now;
$dt->set_time_zone('America/Chicago');

my $ymd    = $dt->ymd;
my $hms    = $dt->hms;
my $db2_dt = $ymd . ' ' . $hms;




#Get Options
my %opts;
# Get command line options
getopts( 'd:r:t:s:c:p:u:', \%opts );

# Global Variables to hold arguments.
my $id            = undef;
my $target_dbname = undef;
my $description   = undef;
my $max_procs     = undef; 
my $post_fix      = undef;
my $DB_User_ID    = undef;


#Set Global Variables
$id            = $opts{"r"};
$target_dbname = $opts{"t"};
$description   = $opts{"s"};
$max_procs     = $opts{"c"};
$post_fix      = $opts{"p"};  
$DB_User_ID    = $opts{"u"};
    
my $pm = Parallel::ForkManager->new($max_procs);

#Routine to prompt for password.
print "Type your password for $DB_User_ID\@SAMPLE:";
ReadMode('noecho');    # don't echo
my $Repository_Password = ReadLine(0);
ReadMode(0);           # back to normal




# BEGIN Connect to DB
my $dbh_admin = DBI->connect( "dbi:DB2:$Repository_DB", $DB_User_ID, $Repository_Password, { PrintError => 0, RaiseError => 0 } );    
$dbh_admin->{ChopBlanks} = 0;

# Error handling for DB2
if ($DBI::err) {
    my $value = undef;
    print STDERR "*** ERROR: Connecting $Repository_DB terminated due to error: $DBI::errstr, $DBI::err in instance $Repository_DB";
    if ( $DBI::errstr =~ /.*?(SQL\d\d\d\d\d?N).*?SQLSTATE=(\d+)/ ) {
        $value = "ERROR $1/ST$2";
    }
    elsif ( $DBI::errstr =~ /.*?(SQL\d\d\d\d\d?N).*?Reason\scode\s=\s"(\d+)"/ )
    {
        $value = "ERROR $1/RC:$2";
    }
    else {
        $value = "ERROR " . chomp($DBI::errstr);
    }
}
else {
    print
      "\n Connect successful to $Repository_DB in instance $Repository_DB\n";
}
# END Connect to DB


# DDL for tables and some SQL.
=pod
CREATE TABLE TU01945.LOAD_TEST_PERL
(
    ID                 SMALLINT     NOT NULL,
    SNAPSHOT_TIMESTAMP TIMESTAMP(6) NOT NULL,
    DBNAME             VARCHAR(50)  NOT NULL,
    DESCRIPTION        VARCHAR(500)
) COMPRESS YES ADAPTIVE
;

CREATE TABLE TU01945.LOAD_TEST_PERL_DETAILS
(
    ID            SMALLINT      NOT NULL,
    SP_NAME       VARCHAR(500),
    ROWS_RETURNED INTEGER,
    EXEC_IN_SEC   DECIMAL(10,6),
    FETCH_IN_SEC  DECIMAL(10,6)
) COMPRESS YES ADAPTIVE
;

=cut

#Prepare statement is global, because storing the parsed data into memory is to expensive, it's faster to read the entry and insert

#my $sth_1 = $dbh_admin->prepare('insert into tu01945.load_test_details (ID, SP_NAME, ROWS_RETURNED , ROWS_RET_IN_SEC, SQL_TIME_IN_SEC) values (?, ?, ?, ?, ?)');
#unless ($sth_1) {
#    die "Error preparing SQL sth_1: $sth_1\n";
#}

my $sth_2 = $dbh_admin->prepare('insert into tu01945.load_test_perl (ID, SNAPSHOT_TIMESTAMP, DBNAME, DESCRIPTION) values (?, ?, ?, ?)');
unless ($sth_2) {
    die "Error preparing SQL sth_2: $sth_2\n";
}


sub main {

    #Call checkusage subroutine to verify options.
    if ( !checkusage( \%opts ) ) {
        print Dumper( \%opts );
        print "\n !!!!!Error in options!!!! \n";
        usage();
        exit();
    }

    print Dumper( \%opts );

    my $input_dir = $opts{"d"};
    
    #print "\n$target_dbname\n";

    #Insert in  LOAD_TEST_PERL (ID, SNAPSHOT_TIMESTAMP, DBNAME, DESCRIPTION)
    
    $sth_2->execute( $id, $db2_dt, $target_dbname, $description );
    if ($DBI::err) {
        print STDERR "*** ERROR: inserting in $Repository_DB terminated due to error: $DBI::errstr, $DBI::err in instance $Repository_DB";
        my $value = undef;
        if ( $DBI::errstr =~ /.*?(SQL\d\d\d\d\d?N).*?SQLSTATE=(\d+)/ ) {

            #       $errors{$db_name}++ unless $1 eq 'SQL30081N';
            $value = "ERROR $1/ST$2";
        }
        elsif (
            $DBI::errstr =~ /.*?(SQL\d\d\d\d\d?N).*?Reason\scode\s=\s"(\d+)"/ )
        {
            $value = "ERROR $1/RC:$2";
        }
        else {
            $value = "ERROR " . chomp($DBI::errstr);
        }
        print "\n Error Value: '$value' Exiting...\n";

        if ( $value eq 'ERROR SQL0803N/ST23505' ) {
            print "\nDelete the existing run id from both tables\n";
            print "delete FROM TU01945.LOAD_TEST_PERL where id = $id; delete FROM TU01945.LOAD_TEST_PERL_DETAILS where id = $id;\n";
        }
        exit;
    }
    #print "\nDB connect in main", Dumper($dbh_admin);

    # Retrieve list of file in directory and put them in the array by call the subroutine get_files_list
    my @files = get_files_list($input_dir);
    #print Dumper(@files);

    # Process All the files in the directory, passing the reference to the array that holds the file list.
    process_files( \@files, $input_dir );
}



main();

$sth_2->finish();
$dbh_admin->disconnect();

####################### SUBROUTINES ############################  

sub usage {
    print <<USAGE;
	
usage: perl <script.pl> <options>
	-d <directory>	specify directory in which to find log files.
	-t <target db name>	specify the database that the logs files are for.
	-r provide a unique run id.
    -s Provide a brief description.
    -c Number of child processes
    -p Post fix for output files **User a regular expression**.
    -u User Id to connect to SAMPLE

example usage:
	# Process files in directory  "d" /db2_temp/v1/db2edt1i/db2adm1s/perl_load_test/udp1q_output
    # Use the "-r" run id 2000 and above, but must be a new run id each time.

	<script.pl> -u db2inst1 -d  /tmp/out -r 2000 -t SAMPLE -s 'Description Testing SP CALL SCH.SP_NAME(?,?,?,?)' -c 100 -p 'SQL.*'
    Please note the - t SAMPLE is the db that the load test was run on, the results are stored in SAMPLE as well, but that is hard coded in the script below, change as required.
USAGE
}


sub checkusage {
    my $opts = shift;

    my $r = $opts->{"r"};
    my $d = $opts->{"d"};
    my $t = $opts->{"t"};
    my $s = $opts->{"s"};
    my $p = $opts->{"p"};
    my $u = $opts->{"u"};

    # r is mandatory.
    # d is mandatory.
    # t is mandatory.
    # s is optional.
    # p is mandatory.


    unless ( defined($d) ) {
        return 0;
    }

    unless ( defined($t) ) {
        return 0;
    }

    unless ( defined($r) ) {
        return 0;
    }

    unless ( defined($p) ) {
        return 0;
    }
    unless ( defined($u) ) {
        return 0;
    }


    return 1;
}


sub process_files {
    my ( $files, $input_dir ) = @_;

    #process_file( @$files[0], $input_dir );
    # Setup a callback for when a child finishes up so we can
    # get it's exit code
    $pm->run_on_finish( sub {
        my ($pid, $exit_code, $ident) = @_;
        print "\n** $ident just got out of the pool ".
          "with PID $pid and exit code: $exit_code\n";
    });
 
    $pm->run_on_start( sub {
        my ($pid, $ident)=@_;
        print "\n ** $ident started, pid: $pid\n";
    });
 
=pod
    $pm->run_on_wait( sub {
        print "\n** Have to wait for one file processor to exit ...\n"
      },
      10
    );
=cut    
    
    #Process each file with the sp calls using child processes.
    #@$files  $files is a scalar reference to an array so you have to cast it with @   
    FILES:
    foreach my $child ( 0 .. @$files-1 ) {  

        # Start each child process and capture the pid
        my $pid = $pm->start(@$files[$child]) and next FILES;

        #BEGIN This code is the child process
        print "This is @$files[$child], Child number $child\n";
        #Call the subrutine process_file which creates a new connection to the db, processes the contents and inserts them into the db.
        process_file( @$files[$child], $input_dir );
        my $exit_code = 0;
        $pm->finish($exit_code); # pass an exit code to finish
        #END This code is the child process
    }
    
    print "Waiting for child processes...\n";
    $pm->wait_all_children;
    print "All files processed!\n";

}


sub process_file {
    my ( $file, $input_dir ) = @_;

    print "Processing FILE $file in $input_dir ... \n";

    my $filepath = "$input_dir/$file";

    # BEGIN Connect to DB
    my $dbh_admin_sub = DBI->connect( "dbi:DB2:$Repository_DB", $DB_User_ID, $Repository_Password, { PrintError => 0, RaiseError => 0 } );    
    $dbh_admin_sub->{ChopBlanks} = 0;
    #print "\nDB connect in sub", Dumper($dbh_admin_sub);
    if ($DBI::err) {
        my $value = undef;
        print STDERR "*** ERROR: Connecting $Repository_DB terminated due to error: $DBI::errstr, $DBI::err in instance $Repository_DB";
        if ( $DBI::errstr =~ /.*?(SQL\d\d\d\d\d?N).*?SQLSTATE=(\d+)/ ) {
            $value = "ERROR $1/ST$2";
        }
        elsif ( $DBI::errstr =~ /.*?(SQL\d\d\d\d\d?N).*?Reason\scode\s=\s"(\d+)"/ ) {
                $value = "ERROR $1/RC:$2";
        }
        else {
                $value = "ERROR " . chomp($DBI::errstr);
        }
    }
    else {
        #print "\n Connect successful to $Repository_DB in sub\n";
        print ".";
    }

    my $sth_3 = $dbh_admin_sub->prepare('insert into tu01945.load_test_perl_details (ID, SP_NAME, ROWS_RETURNED , EXEC_IN_SEC, FETCH_IN_SEC) values (?, ?, ?, ?, ?)');
    unless ($sth_3) {
        die "Error preparing SQL sth_3: $sth_3\n";
    }

    open( INPUTFILE, $filepath ) or die "Unable to open $filepath\n";

=pod
===========
Input SQL {CALL SCHEMA.SP_NAME(?,?,?,?) with 1234567 2015-9-22 00:00:00 2016-6-18 00: 00:00 Some Argument}
Total Execution Time : 0.000671
Total Fetch Time : 0.000840
Rows returned : 0 rows

=cut
    
    $/ = "===========";
          
    #my @return_data;
    #print "\nBefore while:";
    while ( my $line = <INPUTFILE> ) {

        #print "\nIn while: $line";
        #sleep 5;
        #Capture SP name and parameters, ignore new line 's'
        my $regex_spname = qr/^Input SQL \{(.*?)\}$/msp;        
        my ($line1_data) = $line =~ /$regex_spname/;
        unless ( defined($line1_data) ) {
            #print "\nIn next while:";
            next;
        }

        #Capture Exec time
        my $regex_exec_time = qr/^Total Execution Time :(.*?)$/mp;
        my ($line2_data) = $line =~ /$regex_exec_time/;
        
        #Capture Fetch time
        my $regex_fetch_time = qr/^Total Fetch Time :(.*?)$/mp;
        my ($line3_data) = $line =~ /$regex_fetch_time/;
        
        #Capture Rows
        my $regex_rows_returned = qr/^Rows returned :(.*?) rows.*$/mp;
        my ($line4_data) = $line =~ /$regex_rows_returned/;
        
        
        #print Dumper($id, $line1_data, $line2_data, $line3_data, $line4_data);
        #print "Inserting $line1_data into database ...\n";
        #print "$target_dbname";

        $sth_3->execute( $id, $line1_data, $line4_data, $line2_data, $line3_data );
        if ($DBI::err) {
            print STDERR "*** ERROR: inserting in $Repository_DB terminated due to error: $DBI::errstr, $DBI::err in instance $Repository_DB Statement: $sth_3";
            my $value = undef;
            if ( $DBI::errstr =~ /.*?(SQL\d\d\d\d\d?N).*?SQLSTATE=(\d+)/ ) {

                #       $errors{$db_name}++ unless $1 eq 'SQL30081N';
                $value = "ERROR $1/ST$2";
            }
            elsif ( $DBI::errstr =~
                /.*?(SQL\d\d\d\d\d?N).*?Reason\scode\s=\s"(\d+)"/ )
            {
                $value = "ERROR $1/RC:$2";
            }
            else {
                $value = "ERROR " . chomp($DBI::errstr);
            }
            print "\n Error Value: $value Exiting";
            print Dumper($id, $line1_data, $line4_data, $line2_data, $line3_data);
            exit;
        }

        #push @return_data, {
        #           "sql" => $line1_data,
        #           "rows" => $line2_data1,
        #           "rows_time" => $line2_data2,
        #           "sql_time" => $line3_data,
        #       };
    }

    close(INPUTFILE);

    #print Dumper(@return_data);
    #return @return_data;
}

sub get_files_list {
    my $input_dir = shift;

    unless ( opendir( INPUTDIR, $input_dir ) ) {
        die "\nUnable to open directory '$input_dir'\n";
    }

    my @files = readdir(INPUTDIR);

    closedir(INPUTDIR);

    my $regex_post_fix = qr/$post_fix/i;  
    #@files = grep( /^CALL_.*$/i, @files );
    @files = grep( /$regex_post_fix/ , @files );

    return @files;
}



