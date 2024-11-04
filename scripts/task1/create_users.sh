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
read -p "Введите имя пользователя для создания: " NEW_USER

# Prompt for the password for the new user
read -sp "Введите пароль для нового пользователя: " PASSWORD
echo

# Create a temporary file to store public keys
TEMP_FILE="/home/$TEAM_USER/.ssh/authorized_keys.temp"
touch $TEMP_FILE
> "$TEMP_FILE"  # Clear the file if it exists

# Read host addresses and hostnames from the file into an array
HOSTS_FILE="$(dirname "$0")/hosts.txt"
mapfile -t HOSTS < "$HOSTS_FILE"


# Iterate over each host entry
for ENTRY in "${HOSTS[@]}"; do
    # Split entry into HOST and HOSTNAME
    read -r HOST HOSTNAME <<< "$ENTRY"

    print_header "Создание пользователя $NEW_USER для хоста: $HOSTNAME."
    echo "ВНИМАНИЕ! При выполнении команд на удаленных хостах потребуется ввод пароля пользователя $TEAM_USER"

    # Check if the hostname matches the current hostname
    if [[ "$HOSTNAME" != "$LOCAL_HOST" ]]; then

        # Command to create the user and set the password
        SSH_COMMAND="sudo useradd -m -s /bin/bash $NEW_USER && echo '$NEW_USER:$PASSWORD' | sudo chpasswd"
        # Execute the command on the remote server using HOST
        ssh -t "$TEAM_USER@$HOST" "$SSH_COMMAND"
        check_success

        # Check if the user was created successfully
        if [ $? -eq 0 ]; then
            print_header "Пользователь $NEW_USER создан для хоста: $HOSTNAME."

            print_header "Генерация публичного SSH-ключа на $HOSTNAME для пользователя $NEW_USER..."
            # Generate SSH key pair for the new user on remote machine without logging in via SSH
            SSH_KEY_GEN_COMMAND="sudo -u $NEW_USER ssh-keygen -t rsa -b 4096 -f /home/$NEW_USER/.ssh/id_rsa -N ''"
            ssh -t "$TEAM_USER@$HOST" "$SSH_KEY_GEN_COMMAND" || error_exit "Не удалось сгенерировать публичный ключ."
            check_success

            # Copy public key from remote machine to local temporary file
            echo "Копирование публичного SSH-ключа для пользователя $NEW_USER на $HOSTNAME в временный файл..."
            sshpass -p "$PASSWORD" ssh -t "$NEW_USER@$HOST" "cat /home/$NEW_USER/.ssh/id_rsa.pub" >> "$TEMP_FILE" || error_exit "Не удалось скопировать ключ."
            check_success
        else
            error_exit "Не удалось создать пользователя $NEW_USER на хосте $HOSTNAME."
        fi

    else

        sudo useradd -m -s /bin/bash "$NEW_USER" && echo "$NEW_USER":"$PASSWORD" | sudo chpasswd
        if [ $? -eq 0 ]; then
            print_header "Пользователь $NEW_USER создан для хоста: $HOSTNAME."

            print_header "Генерация публичного SSH-ключа на $HOSTNAME для пользователя $NEW_USER..."
            # Generate SSH key pair for the new user on local machine
            sudo -u "$NEW_USER" ssh-keygen -t rsa -b 4096 -f "/home/$NEW_USER/.ssh/id_rsa" -N "" || error_exit "Не удалось сгенерировать ключ."
            check_success

            # Copy public key to local temporary file
            echo "Копирование публичного SSH-ключа для пользователя $NEW_USER на $HOSTNAME в временный файл..."
            sudo -u "$NEW_USER" cat "/home/$NEW_USER/.ssh/id_rsa.pub" >> "$TEMP_FILE" || error_exit "Не удалось скопировать ключ."
            check_success
        else
            error_exit "Не удалось создать пользователя $NEW_USER на хосте $HOSTNAME."
        fi
        continue
    fi

done

# Iterate over each host entry
for ENTRY in "${HOSTS[@]}"; do
    # Split entry into HOST and HOSTNAME
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    print_header "Добавление созданных публичных ключей на $SERVER_HOST ..."
    if [[ "$SERVER_HOST" == "$LOCAL_HOST" ]]; then
        sudo cp "$TEMP_FILE" "/home/$NEW_USER/.ssh/authorized_keys" || error_exit "Не удалось добавить ключ."
        check_success
        print_header "Копирование файла hosts.txt на $SERVER_HOST ..."
        sudo cat "$HOSTS_FILE" >> /etc/hosts && sudo sed -i '/^127\.0\.0\.1/ s/^/#/' /etc/hosts && sudo sed -i '/^127\.0\.1\.1/ s/^/#/' /etc/hosts || error_exit "Не удалось скопировать файл hosts.txt."
        check_success
    else
        sshpass -p "$PASSWORD" scp "$TEMP_FILE" "$NEW_USER@$SERVER_IP:/home/$NEW_USER/.ssh/authorized_keys" || error_exit "Не удалось добавить ключ."
        check_success
        # Copy hosts hosts.txt to temp file on remote host
        print_header "Копирование файла hosts.txt на $SERVER_HOST ..."
        scp "$HOSTS_FILE" "$TEAM_USER@$SERVER_IP:/tmp/" || error_exit "Не удалось скопировать файл hosts.txt."
        check_success
        # Add all entries from hosts.txt to /etc/hosts on remote machine
        print_header "Копирование содержимого файла host.txt в /etc/hosts на $SERVER_HOST ..."
        ADD_AND_EDIT_HOSTS_COMMAND="sudo bash -c 'cat /tmp/$(basename "$HOSTS_FILE") >> /etc/hosts' && sudo sed -i '/^127\.0\.0\.1/ s/^/#/' /etc/hosts && sudo sed -i '/^127\.0\.1\.1/ s/^/#/' /etc/hosts"
        ssh -t "$TEAM_USER@$SERVER_IP" "$ADD_AND_EDIT_HOSTS_COMMAND" || error_exit "Не удалось скопировать содержимое."
        check_success
    fi

done

print_header "Завершение автоматического создания подключения по SSH."
