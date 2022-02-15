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

#url of http trigger
BACKUP_HTTP_SERVERS=() #fill it like (http://10.10.0.150/backup_activate http://10.10.0.151/backup_activate)
BACKUP_SSH_SERVERS=() #fill it like ("user:/usr/backup/keys/ssh_key:10.10.0.150:22:/remote_server_backup_script.sh") #user:ssh_key_path:address:port
###/CONFIG###

compression_1="/usr/bin/lbzip2"
compression_2="/bin/bzip2"

sql_file="$LOCAL_BACKUP_STORAGE/mysql_$curdate.sql"

ignore_table=""
for table in ${MYSQL_IGNORE_TABLE[*]}
do
    ignore_table+=" --ignore-table=$MYSQL_DATABASE.$table"
done

time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time starting the database backup"
/usr/bin/mysqldump --single-transaction -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
 "$MYSQL_DATABASE" $ignore_table > "$sql_file"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time The data dumping is completed"

echo "$time Data compression begins"

if [ -f "$compression_1" ]
then
	eval $compression_1 "$sql_file"
else
	eval $compression_2 "$sql_file"
fi
#/bin/bzip2 "$sql_file"
time=$(date +%Y-%m-%d_%H:%M:%S)
echo "$time backup is created"


for BACKUP_SERVER in ${BACKUP_HTTP_SERVERS[*]}
do
  echo "$time data is sending by HTTP to backup server: $BACKUP_SERVER"
  RESULT="`/usr/bin/wget -qO- "$BACKUP_SERVER"`"
  time=$(date +%Y-%m-%d_%H:%M:%S)
  echo "$time data is loaded"
done

for BACKUP_SERVER in ${BACKUP_SSH_SERVERS[*]}
do
  IFS=':'
  read -ra BACKUP_SERVER_ARR <<< "$BACKUP_SERVER"
  user=${BACKUP_SERVER_ARR[0]}
  SSH_KEY_FILE=${BACKUP_SERVER_ARR[1]}
  ssh_ip=${BACKUP_SERVER_ARR[2]}
  ssh_port=${BACKUP_SERVER_ARR[3]}
  ssh_script=${BACKUP_SERVER_ARR[4]}

  echo "$time data is sending by SSH to backup server: $ssh_ip"

  RESULT=`ssh -p $ssh_port -i $SSH_KEY_FILE -l $user $ssh_ip $ssh_script`
  time=$(date +%Y-%m-%d_%H:%M:%S)
  echo "$time data is loaded"
done

/bin/rm "$sql_file.bz2";

exit 0