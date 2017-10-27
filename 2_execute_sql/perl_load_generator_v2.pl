#! /usr/bin/perl 

=pod
############################################################################
#                                                                          #
# Script          : perl_load_generator.pl                                 #
# Owner           :                                                        #
# Function        :                                                        #
# Syntax to invoke:                                                        #
# Called by       :                                                        #
# Frequency       :                                                        #
# Pre-requisites  :                                                        #
# Parameter       :                                                        #
# Options         :                                                        #
# Version         :                                                        #
# 1.0   11/07/2016   Sudip Kundu     Initial Version                       #
# 2.0   12/20/2016   Sudip Kundu     Added child output log files          #
#                                    and flag to print result set          #
# 3.0   1/12/2017    Sudip Kundu     Modify output file to parse sql       #
#                                                                          #
############################################################################
=cut

use strict; 
use warnings; #Commented out due to columns with null values.
use Data::Dumper;
use Getopt::Std;
use DateTime;
use Term::ReadKey;
use Parallel::ForkManager;
use Benchmark;
#use diagnostics;


$| = 1;

use DBI;
use DBD::DB2;
use DBD::DB2::Constants;
use DBD::DB2 qw($attrib_int $attrib_char $attrib_float $attrib_date $attrib_ts);


my $dt = DateTime->now;
$dt->set_time_zone('America/Chicago');

my $ymd    = $dt->ymd;
my $hms    = $dt->hms;
my $db2_dt = $ymd . ' ' . $hms;

#Get Options
my %opts;
# Get command line options d: directory of files; u: DB user ID; t: Target DB;  s: Stored proc call; c: concurrent child processes
getopts( 'd:p:u:t:s:c:o:r:', \%opts );

# Global Variables to hold arguments.
my $target_dbname           = undef;
my $file_pattern_to_process = undef; 
my $DB_User_ID              = undef;
my $stored_proc_template    = undef;
my $max_procs               = undef; 
my $output_dir              = undef;
my $print_resultset         = undef;



#Set Global Varaibles
$target_dbname          = $opts{"t"};
$file_pattern_to_process= $opts{"p"};
$DB_User_ID             = $opts{"u"};
$stored_proc_template   = $opts{"s"};
$max_procs              = $opts{"c"};
$output_dir             = $opts{"o"};
$print_resultset        = $opts{"r"};

    
my $pm = Parallel::ForkManager->new($max_procs);


print "Type your password for $DB_User_ID\@$target_dbname:";
ReadMode('noecho');    # don't echo
my $DB_User_ID_Password = ReadLine(0);
ReadMode(0);           # back to normal


sub main {

    if ( !checkusage( \%opts ) ) {
        print Dumper( \%opts );
        usage();
        exit ();
    }

    # Print options passed
    print Dumper( \%opts );

    my $input_dir = $opts{"d"};

    my $summary_filepath = "$output_dir/summary.out";
    # create an output file in the output directory
    open(OUTPUT_SUMMARY,">$summary_filepath") || die "Can't open $summary_filepath";
    print OUTPUT_SUMMARY "Start Time: $db2_dt\n";
    
    my $t0_start_summary_bm = Benchmark->new;
    #Time with milliseconds begin
    my $t0_start_summary = Time::HiRes::gettimeofday();
    
    #Call sub routine to get files with arguments
    my @files = get_files($input_dir);

    print "List of files that will be processed: \n", Dumper(@files);
    process_files( \@files, $input_dir );
    
    my $t0_end_summary_bm = Benchmark->new;
    #Time with milliseconds end
    my $t0_end_summary = Time::HiRes::gettimeofday();
    
    # Benchmark differecne
    my $td_summary = timediff($t0_end_summary_bm, $t0_start_summary_bm);
    print OUTPUT_SUMMARY "Total run took:",timestr($td_summary),"\n";  
     
    #Time with millisecond difference    
    printf OUTPUT_SUMMARY ("Total Time: %.4f\n", $t0_end_summary - $t0_start_summary);
    
    close(OUTPUT_SUMMARY);
}

main();


####################### SUBROUTINES ############################  

sub usage {
    print <<USAGE;
	
usage: perl <script.pl> <options>
	-d <directory>	specify directory in which to find parameter files.
	-t <target db name>	specify the target database.
    -p Post fix  input file pattern, that contains the arguments use regular expression
    -u User ID for the DB
    -s Provide the SQL or SP call.
    -c Number of child processes
    -o Output log files
    -r Print result set

example usage:
	
    # Clean output directory first
    rm /db2_temp/v1/db2edt1i/db2adm1s/perl_load_test/udp3q_output/*
    ./<script.pl> -d /db2home/db2adm1s/perl_load_test/1_generate_arguments/udp3q_getlabs_arguments_only -p 'SQL.*' -u mrj3017 -t udp3q  -s 'CALL CWS_MGP.SP_GET_LABS(?,?,?,?)'       -c 100 -o /db2_temp/v1/db2edt1i/db2adm1s/perl_load_test/udp3q_output -r print
    
    # Clean output directory first
    rm /db2_temp/v1/db2edt1i/db2adm1s/perl_load_test/udp1q_output/*
    ./<script.pl> -d /db2home/db2adm1s/perl_load_test/1_generate_arguments/udp1q_getlabs_arguments_only -p 'SQL.*' -u mrj3017 -t udp1q  -s 'CALL CWS_LW.SP_GET_LAB_RESULTS(?,?,?,?)' -c 100 -o /db2_temp/v1/db2edt1i/db2adm1s/perl_load_test/udp1q_output -r print
    
    
USAGE
}


sub checkusage {
    my $opts = shift;

    my $d = $opts->{"d"}; # directory in which to find parameter files.
    my $t = $opts->{"t"}; # target database
    my $s = $opts->{"s"};  # Provide the SQL or SP call
    my $p = $opts->{"p"};  
    my $u = $opts->{"u"};  
    my $o = $opts->{"o"};  
    my $c = $opts->{"c"};  

    
    # d is mandatory.
    # t is mandatory.
    # s is mandatory.

    unless ( defined($d) ) {
        return 0;
    }
    unless ( defined($t) ) {
        return 0;
    }
    unless ( defined($s) ) {
        return 0;
    }
    unless ( defined($p) ) {
        return 0;
    }
    unless ( defined($u) ) {
        return 0;
    }
    unless ( defined($o) ) {
        return 0;
    }
    unless ( defined($c) ) {
        return 0;
    }
    
    return 1;
}


sub process_files {
    my ( $files, $input_dir ) = @_;


    # Setup a callback for when a child finishes up so we can
    # get it's exit code
    $pm->run_on_finish( sub {
        my ($pid, $exit_code, $ident) = @_;
        print "** $ident just got out of the pool ".
          "with PID $pid and exit code: $exit_code\n";
    });
 
    $pm->run_on_start( sub {
        my ($pid, $ident)=@_;
        print "** $ident started, pid: $pid\n";
    });

=pod
    # This section causing core dump for some reason.
    $pm->run_on_wait( sub {
        print "** Have to wait for one file processor to exit ...\n"
      },
      0.1
    );
=cut

    FILES:
    foreach my $child ( 0 .. @$files-1 ) {  

        #print "$child\n";
        my $pid = $pm->start(@$files[$child]) and next FILES;
 
        #This code is the child process
        print "This is @$files[$child], Child number $child\n";
        process_file( @$files[$child], $input_dir, $child, $output_dir, $print_resultset );
        my $exit_code = 0;
        $pm->finish($exit_code); # pass an exit code to finish
    }
    
    print "Waiting for child processes...\n";
    $pm->wait_all_children;
    print "All files processed!\n";
}


sub process_file {
    my ( $file, $input_dir, $child, $output_dir, $print_resultset ) = @_;

    print "Processing $file in $input_dir ... \n";

    my $input_filepath = "$input_dir/$file";
    my $output_filepath = "$output_dir/$file.$child.out";

    # BEGIN Connect to DB
    my $dbh_admin_sub = DBI->connect( "dbi:DB2:$target_dbname", $DB_User_ID, $DB_User_ID_Password, { LongReadLen => 102400,  PrintError => 0, RaiseError => 0 } );    
    $dbh_admin_sub->{ChopBlanks} = 0;
    #print Dumper($dbh_admin_sub);
    if ($DBI::err) {
        my $value = undef;
        print STDERR "*** ERROR: Connecting $target_dbname terminated due to error: $DBI::errstr, $DBI::err in instance $target_dbname";
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
        print "\n Connect successful to $target_dbname in sub\n";
    }
     
    #?? db2_query_optimization_level  Integer
    my $sp_call = $stored_proc_template;
    my $sth_1 = $dbh_admin_sub->prepare($sp_call);
    unless ($sth_1) {
        die "Error preparing SQL sth_1  :$DBI::errstr\n";
    }
 
    open( INPUTFILE, $input_filepath ) or die "Unable to open $input_filepath\n";

    # create an output file in the output directory
    open(OUTPUT,">$output_filepath") || die "Can't open $output_filepath";
    
    
    while ( my $line = <INPUTFILE> ) {
        chomp($line);
        #print $line;
      
        #Split the line and extract the arguments
        my @sp_arguments = split /,/,$line;
        
        #Write to output file, so it could be analyzed later.
        print OUTPUT "===========\n"; # Use this as a record delimiter
        print OUTPUT "Input SQL {$sp_call with @sp_arguments}\n"; # SQL and arguments
        
        # Number of elements in array
        my $number_of_args = @sp_arguments;        

        #print Dumper(@sp_arguments);
        # Remove Escape sequences and single quotes added by split.
        for (my $i = 0;$i < $number_of_args;$i++) {
            #print "Val[$i]=|$sp_arguments[$i]|\n";
            if ($sp_arguments[$i] =~ /\\'/) {
                $sp_arguments[$i]  =~ s/\\'//g;
            } else {
                $sp_arguments[$i] =~ s/'//g;
            }
            $sp_arguments[$i] =~ s/' /'/g; 
            #print "Val[$i]=|$sp_arguments[$i]|\n";
        }       
        #print Dumper(@sp_arguments);
        
        foreach my $i (0 .. $number_of_args-1) {
            #Bind place marker start at 1 while array starts at 0
            $sth_1->bind_param(($i+1), $sp_arguments[$i]);
        }
  
        #Execute the sql
        #Time with milliseconds begin
        my $t0_start_execute = Time::HiRes::gettimeofday();
        
        $sth_1->execute() or die "Can't execute statement: $DBI::errstr";
        #Time with milliseconds end
        my $t0_end_execute = Time::HiRes::gettimeofday();
              
        #print "Query will return $sth_1->{NUM_OF_FIELDS} fields.\n\n";
        #print "$sth_1->{NAME}->[0]: $sth_1->{NAME}->[1]\n";

        
        #Fetch the rows
        #Time with milliseconds begin
        my $t0_start_fetch = Time::HiRes::gettimeofday();
        
        my $rowcount = 0;
        while (my @row = $sth_1->fetchrow()) {
            no warnings 'uninitialized'; # disable warning
            print OUTPUT "@row\n" if (defined($print_resultset)); # some columns return null, so warning is disabled.
            $rowcount++;
        }
        
        #check for problems which may have terminated the fetch early
        warn $DBI::errstr if $DBI::err;
        
        #Time with milliseconds end
        my $t0_end_fetch = Time::HiRes::gettimeofday();
       
        #Time with millisecond difference    
        printf OUTPUT ("Total Execution Time : %.6f\n", $t0_end_execute - $t0_start_execute);
    
        #Time with millisecond difference    
        printf OUTPUT ("Total Fetch Time : %.6f\n", $t0_end_fetch - $t0_start_fetch);
    
        print OUTPUT "Rows returned : $rowcount rows\n";
    }

    close(OUTPUT);
    close(INPUTFILE);
    $sth_1->finish();
    $dbh_admin_sub->disconnect();
}


sub get_files {
    my $input_dir = shift;

    unless ( opendir( INPUTDIR, $input_dir ) ) {
        die "\nUnable to open directory '$input_dir'\n";
    }

    my @files = readdir(INPUTDIR);

    closedir(INPUTDIR);

    my $regex_file_pattern_to_process = qr/$file_pattern_to_process/i; 
    @files = grep( /$regex_file_pattern_to_process/i, @files );
    return @files;
}



