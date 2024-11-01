#!/bin/bash

# Функция для отображения ошибки и выхода
error_exit() {
    echo -e "\e[31m[Ошибка] $1\e[0m"
    exit 1
}

# Функция для отображения заголовков
print_header() {
    echo -e "\e[33m>>>>>>>>>>>>>>>> $1 <<<<<<<<<<<<<<<\e[0m"
}

# Функция для проверки успешного выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "\e[32mУспешно выполнено\e[0m"
    else
        error_exit "Команда не выполнена."
    fi
}

# Установка sshpass
if ! command -v sshpass &> /dev/null; then
    print_header "Установка sshpass..."
    sudo apt-get install -y sshpass || error_exit "Не удалось установить sshpass."
    check_success
else
    echo -e "\e[32msshpass уже установлен\e[0m"
fi

# Get current username and hostname of the local machine
TEAM_USER="team"
LOCAL_HOST=$(hostname)

# Prompt for the username to create on the remote machine
read -p "Enter the username to create: " NEW_USER

# Prompt for the password for the new user
read -sp "Enter the password for new user: " PASSWORD
echo

# Create a temporary file to store public keys
TEMP_FILE="/home/$TEAM_USER/.ssh/authorized_keys.temp"
touch $TEMP_FILE
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

    # Check if the hostname matches the current hostname
    if [[ "$HOSTNAME" != "$LOCAL_HOST" ]]; then
        
        # Command to create the user and set the password
        SSH_COMMAND="sudo useradd -m -s /bin/bash $NEW_USER && echo '$NEW_USER:$PASSWORD' | sudo chpasswd"

        # Execute the command on the remote server using HOST
        ssh -t "$TEAM_USER@$HOST" "$SSH_COMMAND"

        # Check if the user was created successfully
        if [ $? -eq 0 ]; then
            echo "User '$NEW_USER' created successfully on $HOST."

            echo "Generating public ssh-key on $HOST for $NEW_USER..."
            # Generate SSH key pair for the new user on remote machine without logging in via SSH
            SSH_KEY_GEN_COMMAND="sudo -u $NEW_USER ssh-keygen -t rsa -b 4096 -f /home/$NEW_USER/.ssh/id_rsa -N ''"
            ssh -t "$TEAM_USER@$HOST" "$SSH_KEY_GEN_COMMAND"

            # Copy public key from remote machine to local temporary file
            echo "Copying public key from '$NEW_USER' on $HOST to local temporary file..."
            sshpass -p "$PASSWORD" ssh -t "$NEW_USER@$HOST" "cat /home/$NEW_USER/.ssh/id_rsa.pub" >> "$TEMP_FILE"
            echo "Public key added to $TEMP_FILE."

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
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    echo "Adding collected public keys to authorized_keys of $SERVER_HOST"
    if [[ "$SERVER_HOST" == "$LOCAL_HOST" ]]; then
        sudo cp $TEMP_FILE /home/$NEW_USER/.ssh/authorized_keys
        sudo cat $HOSTS_FILE >> /etc/hosts && sudo sed -i '/^127\.0\.0\.1/ s/^/#/' /etc/hosts && sudo sed -i '/^127\.0\.1\.1/ s/^/#/' /etc/hosts
    else
        sshpass -p "$PASSWORD" scp $TEMP_FILE $NEW_USER@$SERVER_IP:/home/$NEW_USER/.ssh/authorized_keys

        # Copy hosts hosts.txt to temp file on remote host
        echo "Copying hosts.txt to $SERVER_HOST temp ..."
        scp "$HOSTS_FILE" "$TEAM_USER@$SERVER_IP:/tmp/"

        # Add all entries from hosts.txt to /etc/hosts on remote machine
        echo "Adding entries from hosts.txt to /etc/hosts on $SERVER_IP..."
        ADD_AND_EDIT_HOSTS_COMMAND="sudo bash -c 'cat /tmp/$(basename "$HOSTS_FILE") >> /etc/hosts' && sudo sed -i '/^127\.0\.0\.1/ s/^/#/' /etc/hosts && sudo sed -i '/^127\.0\.1\.1/ s/^/#/' /etc/hosts"
        ssh -t "$TEAM_USER@$SERVER_IP" "$ADD_AND_EDIT_HOSTS_COMMAND"
        echo "Entries from hosts.txt added to /etc/hosts on $SERVER_IP."
    fi

done

echo "Connection initialization completed"