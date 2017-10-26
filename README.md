# perl_load_generator
This perl script can take any dynamic sql, read aruguments from "multiple" files and simulate concurrent users. 

"Multiple arguments" files are needed to simulate "Multiple users". 

Therefore if you want to simulate 5 concurrent users, you will need at least 5 argument files, if you have more than 5 then the script will keep process it after the one of the forked process are freed up.

Enjoy!


