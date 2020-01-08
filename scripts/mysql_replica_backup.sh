#!/bin/bash

curdate=$(date +%Y-%m-%d_%H:%M:%S)

LOCAL_BACKUP_STORAGE=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASS=""
MYSQL_HOST=""
MYSQL_PORT=""

BACKUP_SERVER=""

compression_1="/usr/bin/lbzip2"
compression_2="/bin/bzip2"

sql_file="$LOCAL_BACKUP_STORAGE/mysql_$curdate.sql"
log_file="$LOCAL_BACKUP_STORAGE/slave_status_$curdate.log"
echo "$curdate stopping the slave"
/usr/bin/mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "STOP SLAVE\G" > "$log_file"
/usr/bin/mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "SHOW SLAVE STATUS\G" >> "$log_file"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time starting the database backup"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time the backup completed"
/usr/bin/mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "START SLAVE\G" >> "$log_file"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time slave reactiveted"
echo "$time starting backup archiving"

file="/etc/hosts"
if [ -f "$file" ]
then
	echo "$file found."
else
	echo "$file not found."
fi

if [ -f "$compression_1" ]
then
	compression_1 "$sql_file"
else
	compression_2 "$sql_file"
fi
#/bin/bzip2 "$sql_file"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time backup complited"


if [ -n "$BACKUP_SERVER" ]; then
  echo "$time load data to backup server"
  RESULT="`/usr/bin/wget -qO- "$BACKUP_SERVER"`"
  time=$(date +%Y-%m-%d_%H:%M:%S)
  echo "$time data loaded succsesful"
  /bin/rm "$sql_file.bz2";
  /bin/rm "$log_file";
fi


exit 0