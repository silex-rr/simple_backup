#!/bin/bash

# Constants
readonly SSH_TIMEOUT=5
readonly SSH_BATCH_MODE="yes"
readonly SSH_COMMAND_TEST="echo 2>&1"
readonly SSH_DEFAULT_SSH_PORT=22

# Helper function to execute SSH commands
execute_ssh_command() {
    local host="$1"
    local command="$2"
    local ssh_user="$3"
    local ssh_port="$4"
    local ssh_key_file="$5"

    if [ -z "$host" ] || [ -z "$command" ] || [ -z "$ssh_user" ] || [ -z "$ssh_port" ] || [ -z "$ssh_key_file" ]; then
       echo "Missing required parameters" >&2
       return ${EXIT_FAILURE}
    fi

    if [ ! -r "$ssh_key_file" ]; then
       echo "SSH key file not found or not readable: $ssh_key_file" >&2
       return ${EXIT_FAILURE}
    fi

    if ! ssh -o BatchMode="${SSH_BATCH_MODE}" \
            -o ConnectTimeout="${SSH_TIMEOUT}" \
            -p "${ssh_port}" \
            -l "${ssh_user}" \
            -i "${ssh_key_file}" \
            "${host}" "${command}"; then
        echo "SSH command execution failed" >&2
        return ${EXIT_FAILURE}
    fi

}

# Test SSH connection
test_ssh_connection() {
    local host="$1"
    local ssh_user="$2"
    local ssh_port="$3"
    local ssh_key_file="$4"
    if [ -z "$host" ]  || [ -z "$ssh_user" ] || [ -z "$ssh_port" ] || [ -z "$ssh_key_file" ]; then
       echo "Missing required parameters" >&2
       return ${EXIT_FAILURE}
    fi

    execute_ssh_command "${host}" "${SSH_COMMAND_TEST}" "{$ssh_user}" "{$ssh_port}" "{$ssh_key_file}"
    return $?
}

ssh_gen() {
    local ssh_key_file="$1"

    # Check if ssh-keygen exists
    if ! command -v /usr/bin/ssh-keygen >/dev/null 2>&1; then
        echo "Error: ssh-keygen command not found" >&2
        return ${EXIT_FAILURE}
    fi

    if [ ! -f "$ssh_key_file" ]; then
        /usr/bin/ssh-keygen -f "$ssh_key_file" -P ""
        echo "SSH key created: $ssh_key_file" >&2
    fi

    echo "$ssh_key_file";
}

# Add SSH key to remote host
add_ssh_key() {
    local host="$1"
    local ssh_user="$2"
    local ssh_port="$3"
    local ssh_key_file="$4"
    local max_attempts=3
    local attempt=1

    if [ -z "$host" ]  || [ -z "$ssh_user" ] || [ -z "$ssh_port" ] || [ -z "$ssh_key_file" ]; then
       echo "Missing required parameters" >&2
       return ${EXIT_FAILURE}
    fi

    # Check if ssh-copy-id exists
    if ! command -v /usr/bin/ssh-copy-id >/dev/null 2>&1; then
        echo "Error: ssh-copy-id command not found" >&2
        return ${EXIT_FAILURE}
    fi

    # Validate SSH key file
    if [ ! -f "${ssh_key_file}" ]; then
        echo "Error: SSH key file '${ssh_key_file}' not found" >&2
        return ${EXIT_FAILURE}
    fi

    while [ ${attempt} -le ${max_attempts} ]; do
        echo "Attempt ${attempt}/${max_attempts}: Adding SSH key to ${host}..."

        if /usr/bin/ssh-copy-id -p "${ssh_port}" -i "${ssh_key_file}" "${ssh_user}@${host}"; then
            echo "SSH key successfully added to ${host}"
            return ${EXIT_SUCCESS}
        fi
        echo "Failed to add SSH key to ${host} (attempt ${attempt})"
        ((attempt++))
        [ "${attempt}" -le "${max_attempts}" ] && sleep 2
    done

    echo "Error: Failed to add SSH key after ${max_attempts} attempts" >&2
    return ${EXIT_FAILURE}
}

check_ssh_connectivity() {
    local target_host="$1"
    local port="${2:-$SSH_DEFAULT_SSH_PORT}"

    if nc -z -w"$SSH_TIMEOUT" "$target_host" "$port" >/dev/null 2>&1; then
        echo 'Connection is established'
        return ${EXIT_SUCCESS}
    else
        echo 'Cannot connect to this server'
        return ${EXIT_FAILURE}
    fi
}
