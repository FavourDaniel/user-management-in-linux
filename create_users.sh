#!/bin/bash

# Check if the script is run as root
if [[ $(id -u) -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

# Check if the input file is provided as argument
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <input-file>"
    exit 1
fi

INPUT_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Ensure /var/secure directory exists
if [[ ! -d "/var/secure" ]]; then
    mkdir -p /var/secure
    chown root:root /var/secure
    chmod 600 /var/secure
fi

# Function to generate a random password
generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*()_+=-[]{}|;:<>,.?/~' </dev/urandom | head -c 16
}

# Read the input file line by line
while IFS=';' read -r username groups; do
    # Trim any leading/trailing whitespace
    username=$(echo "$username" | tr -d '[:space:]')
    groups=$(echo "$groups" | tr -d '[:space:]')

    # Debug: Log the username and groups read from the file
    log_message "Read line: username='$username', groups='$groups'"

    # Check if username or groups are empty
    if [[ -z "$username" || -z "$groups" ]]; then
        log_message "Error: Username or groups missing in line: $username"
        continue
    fi

    # Check if the user already exists
    if id "$username" &>/dev/null; then
        log_message "User $username already exists, skipping."
    else
        # Create the user's personal group
        if ! getent group "$username" >/dev/null; then
            groupadd "$username"
            log_message "Created group: $username"
        fi

        # Create the user with the personal group
        useradd -m -g "$username" "$username"
        log_message "Created user: $username"

        # Generate a random password and set it for the user
        password=$(generate_password)
        echo "$username:$password" | chpasswd
        log_message "Set password for user: $username"

        # Add the user to additional groups
        IFS=',' read -ra group_array <<< "$groups"
        for group in "${group_array[@]}"; do
            if ! getent group "$group" &>/dev/null; then
                groupadd "$group"
                log_message "Created group: $group"
            fi
            usermod -aG "$group" "$username"
            log_message "Added user $username to group: $group"
        done

        # Set home directory permissions
        mkdir -p "/home/$username"
        chown -R "$username:$username" "/home/$username"
        chmod 755 "/home/$username"

        # Store the username and password securely
        echo "$username,$password" >> $PASSWORD_FILE
        chmod 600 "$PASSWORD_FILE"
        log_message "Password for $username stored in $PASSWORD_FILE"
    fi
done < "$1"

log_message "User creation process completed."