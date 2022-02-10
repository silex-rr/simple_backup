#!/bin/bash

ssh_port=22
ssh_key=''
ssh_user=''
ssh_address_first=''
ssh_address_second=''

back_host_name=''
backup_server_id=''
backup_server_name=''

backup_source=''
backup_exclude=''
backup_name=''

backup_need_compression=''

web_callback_url=''

hostname=$(</etc/hostname)

directory=''
while [ "$directory" = "" ]; do
    echo -n "Set directory for backup (on this server): "
    read -e directory
    if [ -n "$directory" ]; then
        if [ -d "$directory" ]; then
            files=("$directory/*")
            if [ ${#files[@]} -gt 0 ]; then
                choice=''
                while [ "$choice" = "" ]; do
                    echo -n "Directory already exists and contains files, continue? (y/n): "
                    read -e choice
                    choise_bool=0
                    case "$choice" in
                      y|Y|д|Д ) choise_bool=1;;
                      n|N|н|Н ) choise_bool=0;;
                      * ) choise_bool=0;;
                    esac
                    if [ $choise_bool -ne 1 ]; then
                        directory=''
                    fi
                done
            fi
        else
            choice=''
            while [ "$choice" = "" ]; do
                echo -n "Directory does not exist, create? (y/n): "
                read -e choice
                choise_bool=0
                case "$choice" in
                  y|Y|д|Д ) choise_bool=1;;
                  n|N|н|Н ) choise_bool=0;;
                  * ) choise_bool=0;;
                esac
                if [ $choise_bool -eq 1 ]; then
                    /bin/mkdir -p $directory
                    if [ "$?" -eq "0" ]; then
                        echo 'Directory successfully created'
                    else
                        echo 'Error, cannot create this directory'
                        directory=''
                    fi
                else
                    directory=''
                fi
            done
        fi
    fi
done

read -e -p "SSH address (first): " ssh_address_first
read -e -p "SSH address (second): " ssh_address_second
read -e -p "SSH login: " ssh_user
read -e -p "SSH port:[22] " ssh_port
ssh_port=${ssh_port:-22}


KEY_STORE="$directory/keys"

echo "SSH key generation..."

if [ ! -d "$KEY_STORE" ]; then
    /bin/mkdir $KEY_STORE
fi
SSH_KEY="ssh_key"
SSH_KEY_FILE="$KEY_STORE/$SSH_KEY"
if [ ! -f "$SSH_KEY_FILE" ]; then
    /usr/bin/ssh-keygen -f $SSH_KEY_FILE -P ""
    echo "SSH key created: $SSH_KEY_FILE"
fi

ssh_key=$SSH_KEY_FILE

echo "Check connection to server..."
SERVER_CHEK=$(nc -z -v -w5 $ssh_address_first $ssh_port)
echo $SERVER_CHEK
if [ "$?" -eq "0" ]; then
    echo 'Connection is established'
else
    echo 'Cannot connect to this server'
    exit
fi

echo "SSH key check..."

$(ssh -o BatchMode=yes -o ConnectTimeout=5 $ssh_address_first -p $ssh_port -l $ssh_user -i $SSH_KEY_FILE "echo 2>&1")
if [ "$?" -eq "0" ]; then
    echo "SSH key accepted"
else
    echo "Adding this SSH key to the server - $ssh_address_first ..."

    done=""
    while [ "$done" = "" ]; do
        /usr/bin/ssh-copy-id -p $ssh_port -i $SSH_KEY_FILE $ssh_user@$ssh_address_first
        if [ "$?" -eq "0" ]; then
            done="y"
            echo "SSH key successfully added to the server - $ssh_address_first"
            if "$ssh_address_second" -ne ''; then
                ssh -p $ssh_port -i $SSH_KEY_FILE  $ssh_user@$ssh_address_second "uptime"  > /dev/null
            fi
        else
            echo "Cannot add this SSH key to the server - $ssh_address_first"
        fi
    done
fi

echo "Config setup file ..."

read -e -p "Name for this server:[$hostname] " server_name
server_name=${server_name:-$hostname}

while [ "$backup_name" = "" ]; do
    echo -n "Name for this backup: $ssh_address_first-"
    read -e backup_name
    if [ "$backup_name" = "" ]; then
            echo "Name cannot be empty"
    fi
done

while [ "$backup_need_compression" = "" ]; do
    echo -n "Compress this backup? (y/n): "
    read -e choice
    case "$choice" in
      y|Y|д|Д ) backup_need_compression="y";;
      n|N|н|Н ) backup_need_compression="n";;
      * ) backup_need_compression="";;
    esac
done

server_id=$( echo "$server_name" | md5sum | /usr/bin/awk '{print $1}')

while [ "$backup_source" = "" ]; do
    echo -n "Enter path to the directory which you want to get from the server - $ssh_address_first: "
    read -e backup_source
done

read -e -p "Enter the directories which you want to exclude from your backup (just use comma, like 'upload/videos,logs,system/backups'): " backup_exclude


backup_target="$directory/last/"
if [ ! -d "$backup_target" ]; then
    /bin/mkdir $backup_target
fi

backup_archive="$directory/archives"
if [ ! -d "$backup_archive" ]; then
    /bin/mkdir $backup_archive
fi

read -e -p "If you need get some callback over web enter URL: " web_callback_url

if [ -n "$web_callback_url" ]; then
    echo "When backup is complete, you will receive a connection at this URL: $web_callback_url&server_name=$BACKUP_SERVER_NAME&host_name=$BACKUP_HOST_NAME&host_id=$BACKUP_SERVER_ID"
fi

CONFIG_FILE="$directory/master.cfg"
MASTER_FILE="$directory/master.sh"

cat > $CONFIG_FILE <<EOF1
ROOT_DIR="$directory/"

SSH_PORT="$ssh_port"
SSH_KEY="$SSH_KEY_FILE"
SSH_USER="$ssh_user"
SSH_ADDRESS_FIRST="$ssh_address_first"
SSH_ADDRESS_SECOND="$ssh_address_second"

BACKUP_HOST_NAME="$server_name"
BACKUP_SERVER_ID="$server_id"
BACKUP_SERVER_NAME="$ssh_address_first-$backup_name"

BACKUP_SOURCE="$backup_source"
BACKUP_TARGET="$backup_target"
BACKUP_ARCHIVE="$backup_archive/$ssh_address_first-$backup_name-"
BACKUP_EXCLUDE="$backup_exclude"
BACKUP_NEED_COMPRESSION="$backup_need_compression"
BACKUP_ARCHIVE_LIFEDAY=30
BACKUP_FILESIZE=0
BACKUP_FILECOUNT=0
BACKUP_DIRCOUNT=0

WEB_CALLBACK_URL="$web_callback_url"
EOF1

/bin/cp ./master.sh $MASTER_FILE
/bin/chmod 755 $MASTER_FILE

echo "---------------------"
echo "install successfully completed"
echo "---------------------"
echo "To create an archive just run this command: $MASTER_FILE"
echo "Also you can add this string to your crontab: "
echo "0 3     * * *   $USER   $MASTER_FILE"

exit 0