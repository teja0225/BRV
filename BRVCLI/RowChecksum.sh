#!/bin/bash

# Call getopt to validate the provided input. 
options=$(getopt -o hbrvu:p:d:t:f: --long dir:,all,du:,dp: -- "$@")
[ $? -eq 0 ] || { 
    echo "Incorrect options provided"
    exit 1
}

#variables used
backup=0
restore=0
validate=0
mysql_user=""
mysql_password=""
mysql_database=""
mysql_table=""
backup_all=0
master_backup_file=""
dest_sql_user=""
dest_sql_password=""
checksum=""
flag=0
restoreFlag=0

#parse through the command to get parameters
eval set -- "$options"
while true; do
    case "$1" in
		-h)
        printf "OPTIONS\n"
				printf ":-b\n"
        printf ":-r\n"
        printf ":-v\n"
				printf ":-u {source SQL server's username}\n"
        printf ":-p {source SQL server's password}\n"
        printf ":-d {source SQL server's database}\n"
				printf ":-t {source SQL server's table}\n"
        printf ":-f {SQL file to be used} \n"
        printf ":--dir {Output directory to store backup file created}\n"
				printf ":--all {Backup all databases in a server}\n"
        printf ":--du {Destination SQL server's username}\n"
        printf ":--dp {Destination SQL server's password}\n\n"
				printf "USAGE:\n\n"
        printf "Backup:\n"
        printf "./RowChecksum.sh -b -u {} -p {} -d {} -t {} --dir {}\n"
				printf "./RowChecksum.sh -b -u {} -p {} -d {} --dir {}\n"
        printf "./RowChecksum.sh -b -u {} -p {} --all --dir {}\n"
        printf "fill the respective details instead of '{}'\n\n"
				printf "Restore:\n"
        printf "./RowChecksum.sh -r --du {} --dp {} -d {} -f {}\n\n"
        printf "Validate:\n"
				printf "If the backup is already restored\n"
        printf "./RowChecksum.sh -v -u {} -p {} -d {} -t {} -f{}\n"
        printf "./RowChecksum.sh -v -u {} -p {} -d {} -f{}\n"
				printf "If the backup is not yet restored\n"
        printf "./RowChecksum.sh -v -u {} -p {} -f{}\n"
        ;;
    -b)
        backup=1
        ;;
    -r)
        restore=1
        ;;
    -v)
        validate=1
        ;;
    -u)
        shift; # The arg is next in position args
        mysql_user=$1
        ;;
    -p)
        shift; 
        mysql_password=$1
        ;;
    -d)
        shift; 
        mysql_database=$1
        ;;
    -t)
        shift; 
        mysql_table=$1
        ;;
    -f)
        shift; 
        if [ "$backup" -ne 1 ]; then 
        	master_backup_file=$1
				fi
        ;;
    --dir)
       	shift;
				if [ "$backup" -eq 1 ]; then 
        	master_backup_file=$1
				fi
        ;;
    --all)
        backup_all=1
        ;;
    --du)
        shift; 
        dest_sql_user=$1
        ;;
    --dp)
        shift; 
        dest_sql_password=$1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

#find cummulative checksum of entire table row wise
findChecksumTable(){

	declare -a column_names
  column_names=[]
  
	#get colun names in a table to construct string required for MD5
  column_names=`echo "select column_name from information_schema.columns where table_schema='${mysql_database}' and table_name='${mysql_table}'" | mysql --user=${mysql_user} --password=${mysql_password} | grep -v '^column_name' | sed /^column_name$/d`
	
	#after successful completion of the above query construct string
  if [ "$?" -eq 0 ]
  then
  	MDF_String=""

  	for column_name in $column_names
 		do
		#to avoid similaity of "abc|def" and "ab|cdef" on column shuffling insert "?" between them to make difference bet abc?def and ab?cdef
    	a="IFNULL(${column_name},'"A"'),'"?"',"
    	MDF_String=${MDF_String}${a}
  	done  
  	MDF_String=${MDF_String}'"?"'
    
		#find checksum for each row
  	rowChecksum=`echo "select MD5(concat(${MDF_String})) as md5Checksum from ${mysql_database}.${mysql_table};" | mysql --user=${mysql_user} --password=${mysql_password} | grep -v '^md5Checksum' | sed /^md5Checksum$/d`

		#store checksum of every row
		checksum=$checksum"\n"$rowChecksum

	else
		printf "error occurred, please check if ${mysql_database} and ${mysql_table} exists \n"
	fi
}

#find cumulative checksum of a database by inturn calling the function:findChecksumTable()
findChecksumDatabase(){
	declare -a mysql_tables

	#get all the tables in a database
  mysql_tables=`echo 'show tables' | mysql --user=${mysql_user} --password=${mysql_password} --database=${mysql_database} | grep -v '^Tables_in_' | sed /^Tables$/d`

	#if the above query failed to get results
  if [ "$?" -ne 0 ]
  then
    printf "error occurred, check if ${mysql_database} exists \n"
    exit 1
  fi

	#for each table call the function:findChecksumTable() to get checksum
  for TableName in $mysql_tables
    do
    	mysql_table=${TableName}
      findChecksumTable
    done   

}


backup_database(){

	#perform backup
  mysqldump --single-transaction --user=${mysql_user} --password=${mysql_password} ${mysql_database} > "$master_backup_file/${mysql_database}_backup.sql" 2>database.err 

	#check status of mysqldump
  if [ "$?" -eq 0 ]
  then
		findChecksumDatabase
    printf "$checksum" >> "$master_backup_file/${mysql_database}_backup.txt"
    printf "Backup Success\n" 
	else
    printf "Mysqldump encountered a problem: couldn't create backup dump\n"
    printf "possible errors: check if ${mysql_database} is present\n"
		
		#delete empty file created
    `echo rm "$master_backup_file/${mysql_database}_backup.sql"`
    #delete if new directory was created
		if [ "$flag" -eq 1 ]; then
  		`echo rm -rf $master_backup_file`
			flag=0
 		fi
	fi
}

backup_table(){
  
	#perform backup
  mysqldump --single-transaction --user=${mysql_user} --password=${mysql_password} ${mysql_database} ${mysql_table} > "$master_backup_file/${mysql_database}_${mysql_table}_backup.sql"  2>database.err 

	#check status of mysqldump
  if [ "$?" -eq 0 ]
  then
    findChecksumTable
    printf "$checksum" >> "$master_backup_file/${mysql_database}_${mysql_table}_backup.txt"
    printf "Backup Success\n"
	else
    printf "Mysqldump encountered a problem: couldn't create backup dump\n"
    printf "possible errors: check if ${mysql_database} and ${mysql_table} is present (table names may be case sensitive) \n"
		
		#delete empty file created
    `echo rm "$master_backup_file/${mysql_database}_${mysql_table}_backup.sql"`
    #delete if new directory was created
		if [ "$flag" -eq 1 ]; then
  		`echo rm $master_backup_file`
			flag=0
 		fi
	fi
}

#restore a database or table from sql dump (databse must already be created)
restore(){

	#check if the backup file mentioned exists and restore
	if [ -f "$master_backup_file" ]; then 
    mysql --user=${dest_sql_user} --password=${dest_sql_password} -D ${mysql_database} < ${master_backup_file}
		if [ "$?" -gt 0 ]; then
			#err in executing the above command, database might not be created yet			
			restoreFlag=1
		fi
  else
		#backup file doesnt exist
    restoreFlag=2
  fi
}

#verify if the restored database is same as master database by comparing already calculated checksum with current checksum calculated
verifyChecksum(){

	#extract checksum file
	file="${master_backup_file%.*}"
  master_backup_file=$file".txt"

	#check for identity
	diff_lines=diff -U 0 "dumb.txt" $master_backup_file | grep -v ^@ | tail -n +3 | wc -l

	if [ "$diff_lines" -eq 0 ]; then
		printf "backup database is valid\n"
	else
		number_ofLines=wc -l < $master_backup_file
		percent=$((200*$diff_lines/$number_ofLines % 2 + 100*$diff_lines/$number_ofLines))
		printf "$percent percentage of your data is corrupted!"
	fi

	#delete unwated files
	`echo rm -f dumb.txt`
}


if [ "$backup" -eq 1 ]; then

	start=$(date +%s.%N)
  #check if mysql server credentials are given
  if [ "$mysql_user" != "" ] && [ "$mysql_password" != "" ]; then

		# Check MySQL password
		echo exit | mysql --user=${mysql_user} --password=${mysql_password} -B 2>/dev/null
		if [ "$?" -gt 0 ]; then
  		echo "MySQL ${mysql_user} password incorrect"
  		exit 1
		fi

    #if destination mysql server credentials are not given assume source itself is the destination
    if [ "$dest_sql_user" == "" ] && [ "$dest_sql_password" == "" ]; then 
      dest_sql_user=$mysql_user
      dest_sql_password=$mysql_password

    #if any one of the destination mysql server credentials are not given prompt and exit, not usable for now
    elif [ "$dest_sql_user" == "" ] ^ [ "$dest_sql_password" == "" ]; then 
      printf "missing destination sql username or password (du or dp)\n"
      exit 0
    fi

    #if directory or file path to store backup dump is not given prompt and exit
    if [ "$master_backup_file" == "" ]; then
      printf "provide directory path to store backup\n"
			printf "usage: -b -u{user} -p{password} -d{database} -t{table} --dir{directory to store backup}\n"
      exit 0
    fi
    
    # Create backup directory and set permissions if it is not created already
    backup_date=`date +%Y_%m_%d_%H_%M_%S`
    master_backup_file="${master_backup_file}/${backup_date}"
    if [[ ! -d ${master_backup_file} ]];then
    	mkdir -p "${master_backup_file}"
    	chmod 700 "${master_backup_file}"
      flag=1
    fi
		
    #perform backup based on options
    #backup all databases
    if [ "$backup_all" -eq 1 ]; then
      # Get MySQL databases
      mysql_databases=`echo 'show databases' | mysql --user=${mysql_user} --password=${mysql_password} -B | sed /^Database$/d`
      
      # Backup each database
      for database in $mysql_databases
      do
        #skip-lock-tables for mysql server's featured databases
        if [ "${database}" == "information_schema" ] || [ "${database}" == "performance_schema" ]; then
          additional_mysqldump_params="--skip-lock-tables"
        else
          additional_mysqldump_params=""
        fi
        mysql_database=${database}
        printf "Creating backup of \"$mysql_database\" database\n" 
        backup_database
    	done

    #backup individual database
    elif [ "$mysql_database" != "" ] && [ "$mysql_table" == "" ]; then
      backup_database

    #backup a table
    elif [ "$mysql_database" != "" ] && [ "$mysql_table" != "" ]; then
			backup_table

    #mention what to backup
    else
    	printf "specify what to backup\n"
			printf "usage: -b -u{user} -p{password} -d{database} -t{table} --dir{directory to store backup}\n"
      if [ "$flag" -eq 1 ]; then
  			`echo rm -rf $master_backup_file`
				flag=0
 			fi
    fi
  else
    printf "mysql server credentials are missing\n"
		printf "usage: -b -u{user} -p{password} -d{database} -t{table} --dir{directory to store backup}\n"
    exit 0
  fi
	dur=$(echo "$(date +%s.%N) - $start" | bc); 
  printf "Execution time: %.6f seconds\n" $dur
elif [ "$restore" -eq 1 ]; then

	start=$(date +%s.%N)
  if [ "$master_backup_file" == "" ]; then 
		printf "missing sql file to load\n"
		printf "usage: -r --du{user} --dp{password} -d{databse} -f{path to zip file} \n"
    exit 0
  fi
  if [ "$mysql_database" == "" ]; then 
		printf "missing database name to load\n"
		printf "usage: -r --du{user} --dp{password} -d{databse} -f{path to zip file} \n"
    exit 0
  fi

  if [ "$dest_sql_user" != "" ] && [ "$dest_sql_password" != "" ]; then 
		# Check MySQL password
		echo exit | mysql --user=${dest_sql_user} --password=${dest_sql_password} -B 2>/dev/null
		if [ "$?" -gt 0 ]; then
		  printf "MySQL ${mysql_user} password incorrect\n"	
		  exit 1
		fi

		#get sql file to restore from zip
		file="${master_backup_file%.*}"
    master_backup_file=$file".sql"

		#call restore function
    restore

		#check status of restore function
    if [ "$restoreFlag" -eq 1 ]; then
			printf "error occured in restoring ${master_backup_file}\n"	
      printf "possible err: check if database mentioned is already there and backup file is correct\n"
		  exit 1
		elif [ "$restoreFlag" -eq 2 ]; then
			printf "File '${master_backup_file}' not found.\n"
    elif [ "$restoreFlag" -eq 0 ]; then
			printf "${master_backup_file} was successfuly restored\n"
		fi
	
		#reset
    restoreFlag=0

  else
    printf "missing database credentials\n"
 		printf "usage: -r --du{user} --dp{password} -d{databse} -f{path to zip file} \n"
  fi
	dur=$(echo "$(date +%s.%N) - $start" | bc); 
  printf "Execution time: %.6f seconds\n" $dur

elif [ "$validate" -eq 1 ]; then
	start=$(date +%s.%N)
	#check if mysql server credentials are given
  if [ "$mysql_user" != "" ] && [ "$mysql_password" != "" ]; then
		dest_sql_user=$mysql_user
    dest_sql_password=$mysql_password

		# Check MySQL password
		echo exit | mysql --user=${mysql_user} --password=${mysql_password} -B 2>/dev/null
		if [ "$?" -gt 0 ]; then
  		echo "MySQL ${mysql_user} password incorrect"
  		exit 1
		fi

	fi

	#if sql file is already restored, file to compare withb and database or table name or both will be input
	if [ "$master_backup_file" != "" ] && [ "$mysql_database" != "" ] && [ "$mysql_table" != "" ]; then 
		findChecksumTable
    printf "$checksum" >> "dumb.txt"
		verifyChecksum

	elif [ "$master_backup_file" != "" ] && [ "$mysql_database" != "" ]; then
		findChecksumDatabase
		printf "$checksum" >> "dumb.txt"
		verifyChecksum

	#if sql file is not yet restored, file must be restored, check for validity and drop the created
  elif [ "$master_backup_file" != "" ]; then
    mysql_database="dumb"

		#create dummy database
		`echo 'create database dumb;' | mysql --user=${mysql_user} --password=${mysql_password} -B`

		#on success of the above query
    if [ "$?" -eq 0 ]; then

			#get sql file to restore
			file="${master_backup_file%.*}"
      master_backup_file=$file".sql"
			restore

			#check status of restore
			if [ "$restoreFlag" -eq 1 ]; then
      	printf "err: check if backup file is correct\n"
		  	exit 1
			elif [ "$restoreFlag" -eq 2 ]; then
				printf "File '${file}.zip' not found.\n"
    	elif [ "$restoreFlag" -eq 0 ]; then
				restoreFlag=0

				#find required checksum for the restored data
				findChecksumDatabase        
        printf "${checksum}" >> "dumb.txt"

				#verify checksum of restored data and that in the zip file
				verifyChecksum

			fi
		fi

		#drop the dummy database created
		`echo 'drop database dumb;' | mysql --user=${mysql_user} --password=${mysql_password} -B`
	else
		printf "insufficient arguments\n"
		printf "usage: -v -u{user} -p{password} -f{path to zip file} -d{database} -t{table}\n"
  fi
	dur=$(echo "$(date +%s.%N) - $start" | bc); 
  printf "Execution time: %.6f seconds\n" $dur
fi
exit 0;
