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

print_header "Начало автоматического разворачивания hadoop."

# Чтение IP-адресов и имен хостов из файла hosts.txt
HOSTS_FILE="hosts.txt"
mapfile -t HOSTS < "$HOSTS_FILE"

# Ввод имени пользователя и пароля для каждого сервера
read -p "Введите имя пользователя для подключения: " SSH_USER
read -sp "Введите пароль для пользователя $SSH_USER: " SSH_PASS
echo

# Ссылка на дистрибутив Hadoop
HADOOP_URL="https://archive.apache.org/dist/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz"
HADOOP_TAR="hadoop-3.4.0.tar.gz"
HADOOP_DIR="/home/$SSH_USER/hadoop-3.4.0"

# Скачивание дистрибутива Hadoop на джамп-нод, если он ещё не скачан
if [[ ! -f "$HADOOP_TAR" ]]; then
    print_header "Скачиваем дистрибутив Hadoop на джамп-нод..."
    wget "$HADOOP_URL" || error_exit "Не удалось скачать Hadoop."
    check_success
else
    print_header "Дистрибутив Hadoop уже скачан на джамп-ноде."
fi

# Копирование дистрибутива на все ноды
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" ]]; then
        print_header "Копируем hadoop-3.4.0.tar.gz на локальную машину (джамп-нод)..."
        if [[ ! -f "/home/$SSH_USER/hadoop-3.4.0.tar.gz" ]]; then
            cp "$HADOOP_TAR" "/home/$SSH_USER/hadoop-3.4.0.tar.gz" || error_exit "Не удалось скопировать архив на локальную машину (джамп-нод)"
            check_success
        else
            echo -e "\e[32mАрхив уже существует на локальной машине (джамп-нод), пропускаем копирование.\e[0m"
        fi
        continue
    fi

    print_header "Проверяем наличие hadoop-3.4.0.tar.gz на $SERVER_HOST ($SERVER_IP)..."
    if sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@$SERVER_IP" "[ -f /home/$SSH_USER/hadoop-3.4.0.tar.gz ]"; then
        echo -e "\e[32mАрхив уже существует на $SERVER_HOST ($SERVER_IP), пропускаем копирование.\e[0m"
    else
        print_header "Копируем hadoop-3.4.0.tar.gz на $SERVER_HOST ($SERVER_IP)..."
        sudo -u $SSH_USER scp "$HADOOP_TAR" "$SSH_USER@$SERVER_IP:/home/$SSH_USER/hadoop-3.4.0.tar.gz" || error_exit "Не удалось скопировать архив на $SERVER_HOST"
        check_success
    fi
done

# Распаковка дистрибутива на всех нодах
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" ]]; then
        # Распаковка на джамп-ноде локально
        print_header "Распаковываем дистрибутив Hadoop на локальной машине (джамп-нод)..."
        if [[ -d "$HADOOP_DIR" ]]; then
            echo -e "\e[32mДиректория Hadoop уже существует на локальной машине (джамп-нод), пропускаем распаковку.\e[0m"
        else
            tar -xvzf "$HADOOP_TAR" -C "/home/$SSH_USER" || error_exit "Не удалось распаковать архив на локальной машине (джамп-нод)"
            check_success
        fi
        continue
    fi

    # Распаковка на остальных нодах
    if sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@$SERVER_IP" "[ -d $HADOOP_DIR ]"; then
        print_header "Директория Hadoop уже существует на $SERVER_HOST ($SERVER_IP)."
    else
        print_header "Распаковываем дистрибутив Hadoop на $SERVER_HOST ($SERVER_IP)..."
        sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@$SERVER_IP" "tar -xvzf /home/$SSH_USER/hadoop-3.4.0.tar.gz -C /home/$SSH_USER" || error_exit "Не удалось распаковать архив на $SERVER_HOST"
        check_success
    fi
done

# Настройка переменных джамп-ноде
print_header "Настройка переменных среды на джамп-ноде..."
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> "/home/$SSH_USER/.profile"
echo "export HADOOP_HOME=$HADOOP_DIR" >> "/home/$SSH_USER/.profile"
echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> "/home/$SSH_USER/.profile"
check_success

# Настройка переменных среды на нейм-ноде
print_header "Настройка переменных среды на нейм-ноде..."
sudo -u $SSH_USER ssh "$SSH_USER@team-4-nn" "echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> /home/$SSH_USER/.profile"
sudo -u $SSH_USER ssh "$SSH_USER@team-4-nn" "echo 'export HADOOP_HOME=$HADOOP_DIR' >> /home/$SSH_USER/.profile"
sudo -u $SSH_USER ssh "$SSH_USER@team-4-nn" "echo 'export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin' >> /home/$SSH_USER/.profile"
check_success

# Копирование файла ~/.profile на все ноды
print_header "Копирование файла .profile на все ноды..."
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" || "$SERVER_HOST" == "team-4-nn" ]]; then
        continue
    fi

    print_header "Копируем файл .profile на $SERVER_HOST ($SERVER_IP)..."
    sudo -u $SSH_USER scp "$SSH_USER@team-4-nn:/home/$SSH_USER/.profile" "$SSH_USER@$SERVER_IP:/home/$SSH_USER/.profile" || error_exit "Не удалось скопировать .profile на $SERVER_HOST"
    check_success
done

# Добавление JAVA_HOME на джамп-ноде
print_header "Добавление JAVA_HOME в hadoop-env.sh на джамп-ноде..."
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> "$HADOOP_DIR/etc/hadoop/hadoop-env.sh"
check_success

# Добавление JAVA_HOME в hadoop-env.sh на нейм-ноде
print_header "Добавление JAVA_HOME в hadoop-env.sh на нейм-ноде..."
sudo -u $SSH_USER ssh "$SSH_USER@team-4-nn" "echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> $HADOOP_DIR/etc/hadoop/hadoop-env.sh"
check_success

# Копирование файла hadoop-env.sh на все дата-нод
print_header "Копирование hadoop-env.sh на все ноды..."
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')
    
    if [[ "$SERVER_HOST" == "team-4-jn" || "$SERVER_HOST" == "team-4-nn" ]]; then
        continue
    fi
    
    print_header "Копируем hadoop-env.sh на $SERVER_HOST ($SERVER_IP)..."
    sudo -u $SSH_USER scp "$SSH_USER@team-4-nn:$HADOOP_DIR/etc/hadoop/hadoop-env.sh" "$SSH_USER@$SERVER_IP:$HADOOP_DIR/etc/hadoop/hadoop-env.sh" || error_exit "Не удалось скопировать hadoop-env.sh на $SERVER_HOST"
    check_success
done

# Настройка core-site.xml на нейм-ноде
print_header "Настройка core-site.xml на нейм-ноде..."
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@team-4-nn" "echo '<configuration><property><name>fs.defaultFS</name><value>hdfs://team-4-nn:9000</value></property></configuration>' > $HADOOP_DIR/etc/hadoop/core-site.xml" || error_exit "Не удалось настроить core-site.xml"
check_success

# Копирование core-site.xml на все ноды
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" || "$SERVER_HOST" == "team-4-nn" ]]; then
        continue
    fi

    print_header "Копируем файл core-site.xml на $SERVER_HOST ($SERVER_IP)..."
    sudo -u $SSH_USER sshpass -p "$SSH_PASS" scp "$SSH_USER@team-4-nn:$HADOOP_DIR/etc/hadoop/core-site.xml" "$SSH_USER@$SERVER_IP:$HADOOP_DIR/etc/hadoop/core-site.xml" || error_exit "Не удалось скопировать core-site.xml на $SERVER_HOST"
    check_success
done

# Настройка hdfs-site.xml на нейм-ноде
print_header "Настройка hdfs-site.xml на нейм-ноде..."
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@team-4-nn" "echo '<configuration><property><name>dfs.replication</name><value>3</value></property></configuration>' > $HADOOP_DIR/etc/hadoop/hdfs-site.xml" || error_exit "Не удалось настроить hdfs-site.xml"
check_success

# Копирование hdfs-site.xml на все ноды
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" || "$SERVER_HOST" == "team-4-nn" ]]; then
        continue
    fi

    print_header "Копируем файл hdfs-site.xml на $SERVER_HOST ($SERVER_IP)..."
    sudo -u $SSH_USER sshpass -p "$SSH_PASS" scp "$SSH_USER@team-4-nn:$HADOOP_DIR/etc/hadoop/hdfs-site.xml" "$SSH_USER@$SERVER_IP:$HADOOP_DIR/etc/hadoop/hdfs-site.xml" || error_exit "Не удалось скопировать hdfs-site.xml на $SERVER_HOST"
    check_success
done

# Записываем в файл workers
print_header "Обновляем файл workers на нейм-ноде..."
WORKERS_CONTENT=$(awk '!/team-4-jn/ {print $1}' "$HOSTS_FILE")
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@${HOSTS[1]%% *}" "echo -e \"$WORKERS_CONTENT\" > $HADOOP_DIR/etc/hadoop/workers" || error_exit "Не удалось обновить файл workers на нейм-ноде"
check_success

# Копирование файла workers на датаноды
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-nn" || "$SERVER_HOST" == "team-4-jn" ]]; then
        continue
    fi

    print_header "Копируем файл workers на $SERVER_HOST ($SERVER_IP)..."
    sudo -u $SSH_USER sshpass -p "$SSH_PASS" scp "$SSH_USER@${HOSTS[1]%% *}:$HADOOP_DIR/etc/hadoop/workers" "$SSH_USER@$SERVER_IP:$HADOOP_DIR/etc/hadoop/workers"
    check_success
done

# Форматирование файловой системы HDFS на нейм-ноде
print_header "Форматирование файловой системы HDFS на нейм-ноде..."
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@team-4-nn" "$HADOOP_DIR/bin/hdfs namenode -format" || error_exit "Не удалось отформатировать HDFS."
check_success

# Запуск кластера HDFS
print_header "Запуск кластера HDFS..."
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@team-4-nn" "$HADOOP_DIR/sbin/start-dfs.sh" || error_exit "Не удалось запустить кластер HDFS."
check_success

print_header "Завершение автоматического разворачивания hadoop."