#!/bin/bash

curdate=$(date +%Y-%m-%d_%H:%M:%S)

###CONFIG###

LOCAL_BACKUP_STORAGE=""
MYSQL_DATABASE=""
MYSQL_IGNORE_TABLE=() #fill it like (table1 table2 table3)
MYSQL_USER=""
MYSQL_PASS=""
MYSQL_HOST=""
MYSQL_PORT=""

BACKUP_SERVER=""

###/CONFIG###

compression_1="/usr/bin/lbzip2"
compression_2="/bin/bzip2"

sql_file="$LOCAL_BACKUP_STORAGE/mysql_$curdate.sql"
log_file="$LOCAL_BACKUP_STORAGE/slave_status_$curdate.log"

ignore_table=""
for table in ${MYSQL_IGNORE_TABLE[*]}
do
    ignore_table+=" --ignore-table=$MYSQL_DATABASE.$table"
done
echo "$curdate stopping the slave"
/usr/bin/mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "STOP SLAVE\G"
/usr/bin/mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "SHOW SLAVE STATUS\G" > "$log_file"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time starting the database backup"
/usr/bin/mysqldump --single-transaction -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
 "$MYSQL_DATABASE" $ignore_table > "$sql_file"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time the backup completed"
/usr/bin/mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "START SLAVE\G"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time slave reactivated"
echo "$time Data compression begins"

if [ -f "$compression_1" ]
then
	eval $compression_1 "$sql_file"
else
	eval $compression_2 "$sql_file"
fi
#/bin/bzip2 "$sql_file"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time backup was created"


if [ -n "$BACKUP_SERVER" ]; then
  echo "$time data is sending to backup server"
  RESULT="`/usr/bin/wget -qO- "$BACKUP_SERVER"`"
  time=$(date +%Y-%m-%d_%H:%M:%S)
  echo "$time data was loaded"
  /bin/rm "$sql_file.bz2";
  /bin/rm "$log_file";
fi


exit 0