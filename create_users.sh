#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0"
    echo "This script will prompt for user details for multiple remote machines."
    exit 1
}

# Get current username and hostname of the local machine
LOCAL_USER=$(whoami)
LOCAL_HOST=$(hostname)

echo "Current User: $LOCAL_USER"
echo "Current Host: $LOCAL_HOST"

# Create a temporary file to store public keys
TEMP_FILE="/home/$LOCAL_USER/.ssh/authorized_keys.temp"
> "$TEMP_FILE"  # Clear the file if it exists
echo "Path to temp file: $TEMP_FILE"

# Read host addresses and hostnames from the file into an array
HOSTS_FILE="$(dirname "$0")/hosts.txt"
mapfile -t HOSTS < "$HOSTS_FILE"

# Iterate over each host entry
for ENTRY in "${HOSTS[@]}"; do
    # Split entry into HOST and HOSTNAME
    read -r HOST HOSTNAME <<< "$ENTRY"
    
    echo "Processing host: $HOST (Hostname: $HOSTNAME)"

    # Prompt for the user to log in to the remote machine
    read -p "Enter the username to log in: " LOGIN_USER
    
    # Prompt for the username to create on the remote machine
    read -p "Enter the username to create: " NEW_USER
    
    # Prompt for the password for the new user
    read -sp "Enter the password for new user: " PASSWORD
    echo

    # Check if the hostname matches the current hostname
    if [[ "$HOSTNAME" != "$LOCAL_HOST" ]]; then
        
        # Command to create the user and set the password
        SSH_COMMAND="sudo useradd -m -s /bin/bash $NEW_USER && echo '$NEW_USER:$PASSWORD' | sudo chpasswd"

        # Execute the command on the remote server using HOST
        ssh -t "$LOGIN_USER@$HOST" "$SSH_COMMAND"

        # Check if the user was created successfully
        if [ $? -eq 0 ]; then
            echo "User '$NEW_USER' created successfully on $HOST."

            echo "Generating public ssh-key on $HOST for $NEW_USER..."
            # Generate SSH key pair for the new user on remote machine without logging in via SSH
            SSH_KEY_GEN_COMMAND="sudo -u $NEW_USER ssh-keygen -t rsa -b 4096 -f /home/$NEW_USER/.ssh/id_rsa -N ''"
            ssh -t "$LOGIN_USER@$HOST" "$SSH_KEY_GEN_COMMAND"

            # Copy public key from remote machine to local temporary file
            echo "Copying public key from '$NEW_USER' on $HOST to local temporary file..."
            ssh -t "$NEW_USER@$HOST" "cat /home/$NEW_USER/.ssh/id_rsa.pub" >> "$TEMP_FILE"
            echo "Public key added to $TEMP_FILE."

            # TODO: Move adding hostnames after copying public keys

            # echo "Copying hosts.txt to $HOST temp ..."
            # scp "$HOSTS_FILE" "$LOGIN_USER@$HOST:/tmp/"
            # # Add all entries from hosts.txt to /etc/hosts on remote machine
            # echo "Adding entries from hosts.txt to /etc/hosts on $HOST..."
            # ADD_AND_EDIT_HOSTS_COMMAND="sudo bash -c 'cat /tmp/$(basename "$HOSTS_FILE") >> /etc/hosts' && sudo sed -i '/^127\.0\.0\.1/ s/^/#/' /etc/hosts && sudo sed -i '/^127\.0\.1\.1/ s/^/#/' /etc/hosts"
            # ssh -t "$LOGIN_USER@$HOST" "$ADD_AND_EDIT_HOSTS_COMMAND"
            # echo "Entries from hosts.txt added to /etc/hosts on $HOST."
            # # Remove temproray file
            # echo "Removing temporary hosts.txt file from $HOST ..."
            # ssh "$LOGIN_USER@$HOST" "rm /tmp/$(basename "$HOSTS_FILE")"

        else
            echo "Failed to create user '$NEW_USER' on $HOST."
        fi

    else
        echo "Hostname equals local hostname ($LOCAL_HOST)."
        sudo useradd -m -s /bin/bash $NEW_USER && echo $NEW_USER:$PASSWORD | sudo chpasswd
        if [ $? -eq 0 ]; then
            echo "User $NEW_USER created successfully on $HOST."

            echo "Generating public ssh-key on $HOST for $NEW_USER..."
            # Generate SSH key pair for the new user on local machine
            sudo -u $NEW_USER ssh-keygen -t rsa -b 4096 -f /home/$NEW_USER/.ssh/id_rsa -N ""

            # Copy public key to local temporary file
            echo "Copying public key from '$NEW_USER' on $HOST to local temporary file..."
            sudo -u $NEW_USER cat /home/$NEW_USER/.ssh/id_rsa.pub >> "$TEMP_FILE"
            echo "Public key added to $TEMP_FILE."
        else
            echo "Failed to create user '$NEW_USER' on $HOST."
        fi
        continue
    fi

done  # End of loop over hosts

# Iterate over each host entry
for ENTRY in "${HOSTS[@]}"; do
    # Split entry into HOST and HOSTNAME
    read -r HOST HOSTNAME <<< "$ENTRY"

    # Prompt for the username to create on the remote machine
    read -p "Enter the created username: " NEW_USER
    echo "Adding collected public keys to authorized_keys of $HOST"
    if [[ "$HOSTNAME" != "$LOCAL_HOST" ]]; then
        scp $TEMP_FILE $NEW_USER@$HOST:/home/$NEW_USER/.ssh/authorized_keys
    else
        sudo cp $TEMP_FILE /home/$NEW_USER/.ssh/authorized_keys
    fi

done

echo "Connection initialization completed"