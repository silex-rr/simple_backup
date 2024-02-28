#!/bin/bash

my_dir="$(dirname "$0")"

. "$my_dir/master.cfg"

#if [ "$EUID" -eq 0 ]
#  then echo "Please run this script as a non-root user"
#  exit
#fi

CALLBACK_URL=""

if [ ! -z "$WEB_CALLBACK_URL" ]
then
  CALLBACK_URL_SUB=""
  if [[ "$WEB_CALLBACK_URL" == *"?"* ]]; then
    CALLBACK_URL_SUB="&server_name=$BACKUP_SERVER_NAME&host_name=$BACKUP_HOST_NAME&host_id=$BACKUP_SERVER_ID"
  else
    CALLBACK_URL_SUB="?server_name=$BACKUP_SERVER_NAME&host_name=$BACKUP_HOST_NAME&host_id=$BACKUP_SERVER_ID"
  fi
  CALLBACK_URL="$WEB_CALLBACK_URL$CALLBACK_URL_SUB"
fi

SSH_PARAMS="ssh -p $SSH_PORT -i $SSH_KEY -o ConnectTimeout=30"

BACKUP_EXCLUDE_COMPILED=""
if [ -n "$BACKUP_EXCLUDE" ]
then
    BACKUP_EXCLUDE_COMPILED="--exclude ${BACKUP_EXCLUDE//,/ --exclude }"
fi

STATUS=false
MODE="first_address"

echo "Synchronizing data using the first address $SSH_ADDRESS_FIRST"
/usr/bin/rsync -azq -e "$SSH_PARAMS"  --delete $SSH_USER@$SSH_ADDRESS_FIRST:$BACKUP_SOURCE $BACKUP_TARGET $BACKUP_EXCLUDE_COMPILED
if [ "$?" -eq "0" ]
then
	echo "done"
    STATUS=true
else
	echo "fail"
    echo "Synchronizing data using the second address $SSH_ADDRESS_SECOND"
    /usr/bin/rsync -azq -e "$SSH_PARAMS"  --delete $SSH_USER@$SSH_ADDRESS_SECOND:$BACKUP_SOURCE $BACKUP_TARGET $BACKUP_EXCLUDE_COMPILED
    if [ "$?" -eq "0" ]
    then
        echo "done"
        MODE="second_address"
        STATUS=true
    else
        echo "fail"
    fi
fi

BACKUP_LOCATION=''

if [ $STATUS ] ; then

    if [ "$BACKUP_NEED_COMPRESSION" == 'y' ]; then
      ARCHIVE_FILE=$BACKUP_ARCHIVE$(date +%Y-%m-%d_%H-%M-%S).tgz
      /bin/tar cfz "$ARCHIVE_FILE" "$BACKUP_TARGET"
      BACKUP_FILESIZE=$(stat -c%s "$ARCHIVE_FILE")
      BACKUP_LOCATION=$ARCHIVE_FILE
    else
      ARCHIVE_DIR=$BACKUP_ARCHIVE$(date +%Y-%m-%d_%H_%M_%S)
      /bin/cp -r "$BACKUP_TARGET" "$ARCHIVE_DIR"
      BACKUP_FILESIZE=$(/usr/bin/du -sB 1 "$ARCHIVE_DIR" | cut -f1)
      BACKUP_LOCATION=$ARCHIVE_DIR
    fi

    BACKUP_LAST_CHANGE=$(find "$BACKUP_TARGET" -maxdepth 10 -type d -exec stat \{} -c %Z \; |  sort -n -r |  head -n 1)
    BACKUP_FILECOUNT=$(find "$BACKUP_TARGET" -type f | /usr/bin/wc -l)
    BACKUP_DIRCOUNT=$(find "$BACKUP_TARGET" -type d | /usr/bin/wc -l)
    #DELETING old archives
    /usr/bin/find "$BACKUP_ARCHIVE"* -maxdepth 1 -mtime +"$BACKUP_ARCHIVE_LIFEDAY" -exec /bin/rm -r {} \;
fi

AVAILABLE_SPACE=$(/bin/df -kT $BACKUP_TARGET | /bin/grep / | /usr/bin/awk '{print $5}' )

let "AVAILABLE_SPACE = AVAILABLE_SPACE * 1024"

echo "file_size $BACKUP_FILESIZE"
echo "file_file_count $BACKUP_FILECOUNT"
echo "file_dir_count $BACKUP_DIRCOUNT"
echo "available_space $AVAILABLE_SPACE"
echo "last_change $BACKUP_LAST_CHANGE"
echo "backup_location $BACKUP_LOCATION"

if [ -n "$CALLBACK_URL_SUB" ]; then
  RESULT="`/usr/bin/wget -qO- "$CALLBACK_URL&mode=$MODE&file_size=$BACKUP_FILESIZE&file_filecount=$BACKUP_FILECOUNT&file_dircount=$BACKUP_DIRCOUNT&available_space=$AVAILABLE_SPACE&last_change=$BACKUP_LAST_CHANGE&backup_location=$BACKUP_LOCATION"`"
fi

exit 0
