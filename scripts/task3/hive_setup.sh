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

# Get current username and hostname of the local machine
LOCAL_USER=$(whoami)
LOCAL_HOST=$(hostname)
NN_HOSTNAME="team-4-nn"

# Read host addresses and hostnames from the file into an array
HOSTS_FILE="$(dirname "$0")/hosts.txt"
mapfile -t HOSTS < "$HOSTS_FILE"

HIVE_VER="4.0.1"
HIVE_URL="https://dlcdn.apache.org/hive/hive-$HIVE_VER/apache-hive-$HIVE_VER-bin.tar.gz"
PSQL_DRIVER_FILENAME="postgresql-42.7.4.jar"
PSQL_DRIVER_URL="https://jdbc.postgresql.org/download/postgresql-42.7.4.jar$PSQL_DRIVER_FILENAME"

read -p "Введите имя пользователя HDFS: " SSH_USER

HOME_SSH_USER="/home/$SSH_USER"
HIVE_TAR="$HOME_SSH_USER/apache-hive-$HIVE_VER-bin.tar.gz"
HIVE_DIR="$HOME_SSH_USER/apache-hive-$HIVE_VER-bin"

print_header "Смена пользователя на $SSH_USER."
print_header "Скачивание дистрибутива Hive. Это может занять некоторое время ..."

# Check if the tar file already exists
if [ -f "$HIVE_TAR" ]; then
    print_header "Архив $HIVE_TAR уже существует. Пропуск скачивания."
else
    # Download the tar file
    print_header "Скачивание дистрибутива Hive ..."
    sudo -u "$SSH_USER" wget -O "$HIVE_TAR" "$HIVE_URL" || error_exit "Не удалось скачать дистрибутив."
    check_success
fi

# Check if the directory already exists
if [ -d "$HIVE_DIR" ]; then
    print_header "Директория $HIVE_DIR уже существует. Пропуск извлечения архива."
else
    # Extract the tar file to the specified directory
    print_header "Извлечение архива Hive ..."
    sudo -u "$SSH_USER" mkdir -p "$HIVE_DIR" && sudo -u "$SSH_USER" tar -xzf "$HIVE_TAR" -C "$(dirname "$HIVE_DIR")" || error_exit "Не удалось извлечь архив."
    check_success
fi

if [ -f "$HIVE_DIR/lib/$PSQL_DRIVER_FILENAME" ]; then
    print_header "Файл драйвера$HIVE_DIR/lib/$PSQL_DRIVER_FILENAME уже существует. Пропуск скачивания."
else
    print_header "Скачивание драйвера для PostgeSQL ..."
    sudo -u "$SSH_USER" wget -P "$HIVE_DIR/lib/" "$PSQL_DRIVER_URL" || error_exit "Не удалось скачать драйвер."
    check_success
fi

print_header "Добавление переменных среды ..."
sudo -u "$SSH_USER" bash -c "echo 'export HIVE_HOME=$HIVE_DIR' >> /home/$SSH_USER/.profile && echo 'export PATH=\$HIVE_HOME/bin:\$PATH' >> /home/$SSH_USER/.profile"
check_success

print_header "Активация окружения ..."
sudo -u "$SSH_USER" bash -c "source $HOME_SSH_USER/.profile" || error_exit "Не удалось активировать окружение."
check_success

print_header "Создание файла запуска Hive ..."
sudo -u "$SSH_USER" bash -c "cp $HIVE_DIR/conf/hive-env.sh.template $HIVE_DIR/conf/hive-env.sh" || error_exit "Не удалось создать файл запуска Hive."
check_success

print_header "Добавление переменных окружения в файл запуска Hive ..."
sudo -u "$SSH_USER" bash -c "cat << EOF >> $HIVE_DIR/conf/hive-env.sh
export HIVE_HOME=$HIVE_DIR
export HIVE_CONF_DIR=$HIVE_DIR/conf
export HIVE_AUX_JARS_PATH=$HIVE_DIR/lib/*
EOF" || error_exit "Не удалось добавить переменные."
check_success

print_header "Установка Hive завершена."