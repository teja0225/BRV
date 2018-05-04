Introduction
This tool can be used to BAckup Restore and Validate a Database, the tool uses two techniques for validation of a database after restoring using Table Checksum and using Row Checksum.
 
Operating Instructions:

OPTIONS 

-h
-b
-r
-v
-u {source SQL server's username}
-p {source SQL server's password}
-d {source SQL server's database}
-t {source SQL server's table}
-f {SQL file to be used} 
--dir {Output directory to store backup file created}
--all {Backup all databases in a server}
--du {Destination SQL server's username}
--dp {Destination SQL server's password}

USAGE:

Backup:

./RowChecksum.sh -b -u {} -p {} -d {} -t {} --dir {}
./RowChecksum.sh -b -u {} -p {} -d {} --dir {}
./RowChecksum.sh -b -u {} -p {} --all --dir {}

fill the respective details instead of "{}"

Restore:

./RowChecksum.sh -r --du {} --dp {} -d {} -f {}

Validate:

If the backup is already restored
./RowChecksum.sh -v -u {} -p {} -d {} -t {} -f{}
./RowChecksum.sh -v -u {} -p {} -d {} -f{}

If the backup is not yet restored
./RowChecksum.sh -v -u {} -p {} -f{}

TableChecksum.sh can also be used instead of RowChecksum.sh similarly as mentioned above

Known Bugs:

[1] Checksum for a table changes if mysql version is changed from 5.5 to 5.6 due to change in formats for storing temporal types like date, time, timestamp

[2] Checksum for the table changes if the physical ordering of records changes for huge data, since mysqldump creates a single insert statement for the entire table.
Possible soolution: create dump with insert statements for each record, this may take more time for restoring and may result in huge dump file.

[1]https://dev.mysql.com/doc/refman/5.5/en/checksum-table.html
[2]http://www.justskins.com/forums/checksum-table-producing-different-283690.html

