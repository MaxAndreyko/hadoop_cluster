#!/bin/bash

# Get current username and hostname of the local machine
LOCAL_USER=$(whoami)
LOCAL_HOST=$(hostname)
NN_HOSTNAME="team-4-nn"

echo "Current User: $LOCAL_USER"
echo "Current Host: $LOCAL_HOST"

# Read host addresses and hostnames from the file into an array
HOSTS_FILE="$(dirname "$0")/hosts.txt"
mapfile -t HOSTS < "$HOSTS_FILE"

HIVE_VER="4.0.1"
HIVE_URL="https://dlcdn.apache.org/hive/hive-$HIVE_VER/apache-hive-$HIVE_VER-bin.tar.gz"

read -p "Введите имя пользователя для подключения: " SSH_USER

HOME_SSH_USER="/home/$SSH_USER"
HIVE_TAR="$HOME_SSH_USER/apache-hive-$HIVE_VER-bin.tar.gz"
HIVE_DIR="$HOME_SSH_USER/apache-hive-$HIVE_VER-bin"

echo "Смена пользователя на $SSH_USER."
echo "Скачивание дистрибутива Hive. Это может занять некоторое время ..."

# Check if the tar file already exists
if [ -f "$HIVE_TAR" ]; then
    echo "Архив $HIVE_TAR уже существует. Пропуск скачивания."
else
    # Download the tar file
    sudo -u "$SSH_USER" wget -O "$HIVE_TAR" "$HIVE_URL"
fi

# Check if the directory already exists
if [ -d "$HIVE_DIR" ]; then
    echo "Директория $HIVE_DIR уже существует. Пропуск извлечения архива."
else
    # Extract the tar file to the specified directory
    sudo -u "$SSH_USER" mkdir -p "$HIVE_DIR" && tar -xzf "$HIVE_TAR" -C "$(dirname "$HIVE_DIR")"
fi

echo "Копирование дистрибутива Hive на неймноду ..."
sudo -u $SSH_USER scp -r "$HIVE_DIR" "$SSH_USER@$NN_HOSTNAME:$HIVE_DIR"

echo "Добавление переменных среды ..."
sudo -u $SSH_USER ssh "$SSH_USER@$NN_HOSTNAME" "echo 'export HIVE_HOME=$HIVE_DIR' >> $HOME_SSH_USER/.profile && echo 'export PATH=\$HIVE_HOME/bin:\$PATH' >> $HOME_SSH_USER/.profile"


HADOOP_HOME=$(sudo -u "$SSH_USER" ssh "$SSH_USER@$NN_HOSTNAME" "source ~/.profile; echo \$HADOOP_HOME")
HDFS="$HADOOP_HOME/bin/hdfs"
HDFS_TEMP="/tmp"

# Check if the HDFS directory exists
if sudo -u $SSH_USER ssh "$SSH_USER@$NN_HOSTNAME" "$HDFS dfs -test -d $HDFS_TEMP"; then
    echo "HDFS директория $HDFS_TEMP уже существует."
else
    echo "HDFS директории $HDFS_TEMP не существует. Создание директории ..."
    sudo -u $SSH_USER ssh "$SSH_USER@$NN_HOSTNAME" "$HDFS dfs -mkdir $HDFS_TEMP && $HDFS dfs -chmod g+w $HDFS_TEMP"
    
    # Check if the directory creation was successful
    if [ $? -eq 0 ]; then
        echo "Директория $HDFS_TEMP успешно создана."
    else
        echo "Не удалось создать директорию $HDFS_TEMP."
        exit 1
    fi
fi

HDFS_WAREHOUSE="/user/hive/warehouse"

# Check if the HDFS directory exists
if sudo -u $SSH_USER ssh "$SSH_USER@$NN_HOSTNAME" "$HDFS dfs -test -d $HDFS_WAREHOUSE"; then
    echo "HDFS директория $HDFS_WAREHOUSE уже существует."
else
    echo "HDFS директории $HDFS_WAREHOUSE не существует. Создание директории ..."
    sudo -u $SSH_USER ssh "$SSH_USER@$NN_HOSTNAME" "$HDFS dfs -mkdir -p $HDFS_WAREHOUSE && $HDFS dfs -chmod g+w $HDFS_WAREHOUSE"
    
    # Check if the directory creation was successful
    if [ $? -eq 0 ]; then
        echo "Директория $HDFS_WAREHOUSE успешно создана."
    else
        echo "Не удалось создать директорию $HDFS_WAREHOUSE."
        exit 1
    fi
fi

echo "Создание файла запуска Hive ..."
sudo -u $SSH_USER ssh "$SSH_USER@$NN_HOSTNAME" "cp $HIVE_DIR/conf/hive-env.sh.template $HIVE_DIR/conf/hive-env.sh"
sudo -u $SSH_USER ssh "$SSH_USER@$NN_HOSTNAME" "cat << EOF >> $HIVE_DIR/conf/hive-env.sh
export HIVE_HOME=$HIVE_DIR
export HIVE_CONF_DIR=$HIVE_DIR/conf
export HIVE_AUX_JARS_PATH=$HIVE_DIR/lib/*
EOF"

echo "Установка Hive завершена"
