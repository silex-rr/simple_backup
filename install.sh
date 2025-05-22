#!/bin/bash

readonly SSH_PORT_DEFAULT=22
readonly SSH_KEY_NAME='ssh_key'
readonly SSH_COMMAND_UPTIME="uptime"
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly BACKUP_ARCHIVE_RETENTION_DAYS=30

ssh_port=$SSH_PORT_DEFAULT
ssh_user=''
ssh_address_primary=''
ssh_address_secondary=''

back_host_name=''
backup_server_id=''
backup_server_name=''

backup_source=''
backup_exclude=''
backup_name=''

backup_need_compression=''

web_callback_url=''

hostname=$(</etc/hostname)

source "./helpers/ssh.sh"
source "./helpers/common.sh"

collect_ssh_config() {
    read -r -e -p "SSH address (primary): " ssh_address_primary
    read -r -e -p "SSH address (secondary): " ssh_address_secondary
    read -r -e -p "SSH login: " ssh_user
    read -r -e -p "SSH port:[$SSH_PORT_DEFAULT] " port_input
    ssh_port=${port_input:-$SSH_PORT_DEFAULT}
}

setup_ssh_key() {
    local directory="$1"
    local key_store="$directory/keys"
    local ssh_key_file="$key_store/$SSH_KEY_NAME"

    echo "SSH key generation..."

    if ! create_directory "$key_store"; then
        echo 'Error, cannot create a directory for key storing';
        return ${EXIT_FAILURE};
    fi

    if ! ssh_gen "$ssh_key_file"; then
      echo 'Error, cannot able to create SHH keys'
      return ${EXIT_FAILURE};
    fi

    echo "$ssh_key_file"
}
collect_ssh_config

if ! check_ssh_connectivity "$ssh_address_primary" "$ssh_port"; then
  echo "Cannot reach the server: $ssh_address_primary:$ssh_port"
  exit
fi

directory=$(setup_backup_directory)
ssh_key_file=$(setup_ssh_key "$directory")
if ! $ssh_key_file; then
  exit
fi

echo "SSH key check..."

if test_ssh_connection "$ssh_address_primary" "$ssh_user" "$ssh_port" "$ssh_key_file"; then
    echo "SSH key already accepted"
elif add_ssh_key  "$ssh_address_primary" "$ssh_user" "$ssh_port" "$ssh_key_file"; then
      if execute_ssh_command "${ssh_address_primary}" "${SSH_COMMAND_UPTIME}" > /dev/null; then
          echo "Successfully verified connection to the server"
      else
          echo "Failed to verify connection to the server"
          return ${EXIT_FAILURE}
      fi
      if [ -n "${ssh_address_secondary}" ]; then
        if execute_ssh_command "${ssh_address_secondary}" "${SSH_COMMAND_UPTIME}" > /dev/null; then
          echo "Successfully verified connection by second address"
        else
          echo "Failed to verify connection by second address"
          ssh_address_secondary=''
        fi
      fi
else
    echo "Failed to add SSH key after multiple attempts"
    return ${EXIT_FAILURE}
fi

echo "Config setup file ..."

read -r -e -p "Name for this server:[$hostname] " server_name
server_name=${server_name:-$hostname}

while [ "$backup_name" = "" ]; do
    echo -n "Name for this backup: $ssh_address_primary-"
    read -r -e backup_name
    if [ "$backup_name" = "" ]; then
            echo "Name cannot be empty"
    fi
done

backup_need_compression=get_user_confirmation "Compress this backup?"

server_id=$( echo "$server_name" | md5sum | /usr/bin/awk '{print $1}')

while [ "$backup_source" = "" ]; do
    echo -n "Enter path to the directory which you want to get from the server - $ssh_address_primary: "
    read -r -e backup_source
done

read -r -e -p "Enter the directories which you want to exclude from your backup (just use comma, like 'upload/videos,logs,system/backups'): " backup_exclude

backup_target="$directory/last/"
if [ ! -d "$backup_target" ]; then
    /bin/mkdir "$backup_target"
fi

backup_archive="$directory/archives"
if [ ! -d "$backup_archive" ]; then
    /bin/mkdir "$backup_archive"
fi

read -r -e -p "If you need get some callback over web enter URL: " web_callback_url

if [ -n "$web_callback_url" ]; then
    echo "When backup is complete, you will receive a connection at this URL: $web_callback_url&server_name=$backup_server_name&host_name=$back_host_name&host_id=$backup_server_id"
fi

CONFIG_FILE="$directory/master.cfg"
MASTER_FILE="$directory/master.sh"

cat > "$CONFIG_FILE" <<EOF1
ROOT_DIR="$directory/"

SSH_PORT="$ssh_port"
SSH_KEY="$SSH_KEY_FILE"
SSH_USER="$ssh_user"
SSH_ADDRESS_FIRST="$ssh_address_primary"
SSH_ADDRESS_SECOND="$ssh_address_secondary"

BACKUP_HOST_NAME="$server_name"
BACKUP_SERVER_ID="$server_id"
BACKUP_SERVER_NAME="$ssh_address_primary-$backup_name"

BACKUP_SOURCE="$backup_source"
BACKUP_TARGET="$backup_target"
BACKUP_ARCHIVE="$backup_archive/$ssh_address_primary-$backup_name-"
BACKUP_EXCLUDE="$backup_exclude"
BACKUP_NEED_COMPRESSION="$backup_need_compression"
BACKUP_ARCHIVE_LIFEDAY="$BACKUP_ARCHIVE_RETENTION_DAYS"
BACKUP_FILESIZE=0
BACKUP_FILECOUNT=0
BACKUP_DIRCOUNT=0

WEB_CALLBACK_URL="$web_callback_url"
EOF1

/bin/cp ./master.sh "$MASTER_FILE"
/bin/chmod 755 "$MASTER_FILE"

echo "---------------------"
echo "install successfully completed"
echo "---------------------"
echo "To create an archive, just run this command: $MASTER_FILE"
echo "Also you can add this string to your crontab: "
echo "0 3     * * *   $USER   $MASTER_FILE"

exit 0