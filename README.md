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

# Function to generate a random password
generate_password() {
    # Generate a random 12-character alphanumeric password
    echo "$(date +%s%N | sha256sum | head -c 12)"
}

# Read the input file line by line
while IFS=';' read -r username groups; do
    # Trim any leading/trailing whitespace
    username=$(echo "$username" | tr -d '[:space:]')
    groups=$(echo "$groups" | tr -d '[:space:]')

    # Check if username or groups are empty
    if [[ -z "$username" || -z "$groups" ]]; then
        echo "Error: Username or groups missing in line: $line" >> "$LOG_FILE"
        continue
    fi

    # Check if the user already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists, skipping." >> "$LOG_FILE"
    else
        # Create the user
        useradd -m -s /bin/bash "$username" >> "$LOG_FILE" 2>&1
        echo "User $username created." >> "$LOG_FILE"

        # Create the user's personal group
        groupadd "$username" >> "$LOG_FILE" 2>&1
        echo "Group $username created." >> "$LOG_FILE"
    fi

    # Add the user to additional groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        if ! getent group "$group" &>/dev/null; then
            groupadd "$group" >> "$LOG_FILE" 2>&1
            echo "Group $group created." >> "$LOG_FILE"
        fi
        # Add user to group
        usermod -aG "$group" "$username" >> "$LOG_FILE" 2>&1
        echo "User $username added to group $group." >> "$LOG_FILE"
    done

    # Set home directory permissions
    mkdir -p "/home/$username"
    chown -R "$username:$username" "/home/$username"
    chmod 755 "/home/$username"

    # Generate and store the password securely
    password=$(generate_password)
    echo "$username:$password" >> "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    echo "Password for $username stored in $PASSWORD_FILE." >> "$LOG_FILE"

done < "$INPUT_FILE"

echo "User creation script completed."
# user-management-in-linux
