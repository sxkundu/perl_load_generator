# perl load generator for DB2 LUW
This perl script can take any dynamic sql, read aruguments from "multiple" files and simulate concurrent users or a single user. This scipt was written since db2batch can only simulate one connection. This script can take advanatge of the DSDRIVER and WLB for purescale DB2 Systems.

"Multiple arguments" files are needed to simulate "Multiple users". 

Therefore if you want to simulate 5 concurrent users, you will need at least 5 argument files, if you have more than 5 then the script will keep process it after the one of the forked process are freed up.

You will need the following perl modules in addtion to the full db2 client.

As root install the perl modules below:

cpan App::cpanminus

cpanm Parallel::ForkManager

cpanm DateTime

cpanm Term::ReadKey

cpanm DBI

cpanm DBI


Download DBD:Db2 from CPAN

https://metacpan.org/pod/distribution/DBD-DB2/DB2.pod

Export DB2_HOME

perl Makefile.PL            # use a perl that's in your PATH

make

make test

make install (if the tests look okay)

--Sample Call

./perl_load_generator.pl -t SAMPLE -u db2inst1 -d '/home/db2user' -s 'select * from employee where salary > ?' -p SQL* -o /tmp/out -r print -c1



Enjoy!


