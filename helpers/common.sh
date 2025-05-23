#!/bin/bash

# Validates yes/no user input
# Returns 1 for yes, 0 for no
get_user_confirmation() {
    local prompt=$1
    local choice=''

    while [ "$choice" = "" ]; do
        echo -n "$prompt (y/n): " >&2
        read -r -e choice
        case "${choice,,}" in
            y|yes ) return ${EXIT_SUCCESS};;
            n|no  ) return ${EXIT_FAILURE};;
            *     ) choice='';;
        esac
    done
}

# Creates directory if it doesn't exist
create_directory() {
    local dir=$1
    echo "Attempt to create a dir: $dir" >&2

    if [ -d "$KEY_STORE" ]; then
      echo "Directory already exists: $dir" >&2
      return ${EXIT_SUCCESS}
    fi

    if /bin/mkdir -p "$dir"; then
        echo "Directory successfully created: $dir" >&2
        return ${EXIT_SUCCESS}
    else
        echo "Error, cannot create this directory: $dir" >&2
        return ${EXIT_FAILURE}
    fi
}

setup_backup_directory() {
    local directory=''

    while [ -z "$directory" ]; do
        echo -n "Set directory for backup (on this server): " >&2
        read -r -e directory

        if [ -n "$directory" ]; then
            if [ -d "$directory" ]; then
                files=("$directory"/*)
                if [ ${#files[@]} -gt 0 ]; then
                    if ! get_user_confirmation "Directory already exists and contains files, continue?" >&2; then
                        directory=''
                        continue
                    fi
                fi
            else
                if get_user_confirmation "Directory does not exist, create?" >&2; then
                    ehco 'asd' >&2
                    if ! create_directory "$directory" >&2; then
                        echo "Failed to create directory: $directory" >&2
                        directory=''
                    fi
                else
                    echo 'Directory creating is declined' >&2
                    directory=''
                fi
            fi
        fi
    done

    echo "$directory"
}
