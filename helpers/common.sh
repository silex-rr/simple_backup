#!/bin/bash

# Validates yes/no user input
# Returns 1 for yes, 0 for no
get_user_confirmation() {
    local prompt=$1
    local choice=''

    while [ "$choice" = "" ]; do
        echo -n "$prompt (y/n): "
        read -r -e choice
        case "${choice,,}" in
            y|yes ) return ${EXIT_FAILURE};;
            n|no  ) return ${EXIT_SUCCESS};;
            *     ) choice='';;
        esac
    done
}

# Creates directory if it doesn't exist
create_directory() {
    local dir=$1

    if [ -d "$KEY_STORE" ]; then
      echo "Directory already exists: $dir"
      return ${EXIT_SUCCESS}
    fi

    if /bin/mkdir -p "$dir"; then
        echo "Directory successfully created: $dir"
        return ${EXIT_SUCCESS}
    else
        echo "Error, cannot create this directory: $dir"
        return ${EXIT_FAILURE}
    fi
}

setup_backup_directory() {
    local directory=''

    while [ -z "$directory" ]; do
        echo -n "Set directory for backup (on this server): " >&2
        read -r -e directory

        if [ -n "$directory" ]; then
            # Check if the directory already exists
            if [ -d "$directory" ]; then
                # Check if the directory contains files
                files=("$directory"/*)
                if [ ${#files[@]} -gt 0 ]; then
                    if ! get_user_confirmation "Directory already exists and contains files, continue?" >&2; then
                        directory=''
                        continue
                    fi
                fi
            else
                # Ask to create the directory if it doesn't exist
                if get_user_confirmation "Directory does not exist, create?" >&2; then
                    if ! create_directory "$directory" >&2; then
                        echo "Failed to create directory: $directory" >&2
                        directory=''
                    fi
                else
                    directory=''
                fi
            fi
        fi
    done

    echo "$directory"
}
