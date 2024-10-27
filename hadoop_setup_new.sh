#!/bin/bash

# Функция для отображения ошибки и выхода
error_exit() {
    echo -e "\e[31m[Ошибка] $1\e[0m"  # Сообщение об ошибке красным цветом
    exit 1
}

# Функция для отображения заголовков
print_header() {
    echo -e "\e[33m>>>>>>>>>>>>>>>> $1 <<<<<<<<<<<<<<<\e[0m"  # Заголовок желтым цветом
}

# Функция для проверки успешного выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "\e[32mУспешно выполнено\e[0m"  # Сообщение об успешном выполнении зеленым цветом
    else
        echo -e "\e[31m[Ошибка] Команда не выполнена.\e[0m"  # Сообщение об ошибке красным цветом
        exit 1
    fi
}

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
HADOOP_DIR="/home/hadoop/hadoop-3.4.0"

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
        print_header "Пропуск копирования на джамп-ноде: $SERVER_HOST"
        continue
    fi

    print_header "Копируем hadoop-3.4.0.tar.gz на $SERVER_HOST ($SERVER_IP)..."
    sudo -u $SSH_USER sshpass -p "$SSH_PASS" scp "$HADOOP_TAR" "$SSH_USER@$SERVER_IP:/home/hadoop/hadoop-3.4.0.tar.gz" || error_exit "Не удалось скопировать архив на $SERVER_HOST"
done

# Распаковка дистрибутива на всех нодах
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" ]]; then
        print_header "Пропуск распаковки на джамп-ноде: $SERVER_HOST"
        continue
    fi

    if sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@$SERVER_IP" "[ -d $HADOOP_DIR ]"; then
        print_header "Директория Hadoop уже существует на $SERVER_HOST ($SERVER_IP)."
    else
        print_header "Распаковываем дистрибутив Hadoop на $SERVER_HOST ($SERVER_IP)..."
        sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@$SERVER_IP" "tar -xvzf /home/hadoop/hadoop-3.4.0.tar.gz -C /home/hadoop" || error_exit "Не удалось распаковать архив на $SERVER_HOST"
    fi
done

# Настройка переменных среды на нейм-ноде
print_header "Настройка переменных среды на нейм-ноде..."
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@192.168.1.19" "echo 'export JAVA_HOME=/path/to/java' >> /home/hadoop/.profile"
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@192.168.1.19" "echo 'export HADOOP_HOME=$HADOOP_DIR' >> /home/hadoop/.profile"
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@192.168.1.19" "echo 'export PATH=\$PATH:$HADOOP_DIR/sbin' >> /home/hadoop/.profile"

# Копирование файла ~/.profile на все ноды
print_header "Копирование файла /home/hadoop/.profile на все ноды..."
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" || "$SERVER_HOST" == "team-4-nn" ]]; then
        continue
    fi
    echo -e "$SSH_USER@192.168.1.19:/home/hadoop/.profile" "$SSH_USER@$SERVER_IP:/home/hadoop/.profile"
    sudo -u $SSH_USER sshpass -p "$SSH_PASS" scp "$SSH_USER@192.168.1.19:/home/hadoop/.profile" "$SSH_USER@$SERVER_IP:/home/hadoop/.profile"
done

# Добавление JAVA_HOME в hadoop-env.sh
print_header "Добавление JAVA_HOME в hadoop-env.sh на нейм-ноде..."
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@192.168.1.19" "echo 'export JAVA_HOME=/path/to/java' >> $HADOOP_DIR/etc/hadoop/hadoop-env.sh"

# Копирование файла hadoop-env.sh на все ноды
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" || "$SERVER_HOST" == "team-4-nn" ]]; then
        continue
    fi

    sudo -u $SSH_USER sshpass -p "$SSH_PASS" scp "$SSH_USER@192.168.1.19:$HADOOP_DIR/etc/hadoop/hadoop-env.sh" "$SSH_USER@$SERVER_IP:$HADOOP_DIR/etc/hadoop/hadoop-env.sh"
done

# Настройка core-site.xml на нейм-ноде
print_header "Настройка core-site.xml на нейм-ноде..."
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@192.168.1.19" "echo '<configuration><property><name>fs.defaultFS</name><value>hdfs://team4-nn:9000</value></property></configuration>' > $HADOOP_DIR/etc/hadoop/core-site.xml"

# Копирование core-site.xml на все ноды
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" || "$SERVER_HOST" == "team-4-nn" ]]; then
        continue
    fi

    sudo -u $SSH_USER sshpass -p "$SSH_PASS" scp "$SSH_USER@192.168.1.19:$HADOOP_DIR/etc/hadoop/core-site.xml" "$SSH_USER@$SERVER_IP:$HADOOP_DIR/etc/hadoop/core-site.xml"
done

# Настройка hdfs-site.xml на нейм-ноде
print_header "Настройка hdfs-site.xml на нейм-ноде..."
sudo -u $SSH_USER sshpass -p "$SSH_PASS" ssh "$SSH_USER@192.168.1.19" "echo '<configuration><property><name>dfs.replication</name><value>3</value></property></configuration>' > $HADOOP_DIR/etc/hadoop/hdfs-site.xml"

# Копирование hdfs-site.xml на все ноды
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-jn" || "$SERVER_HOST" == "team-4-nn" ]]; then
        continue
    fi

    sudo -u $SSH_USER sshpass -p "$SSH_PASS" scp "$SSH_USER@192.168.1.19:$HADOOP_DIR/etc/hadoop/hdfs-site.xml" "$SSH_USER@$SERVER_IP:$HADOOP_DIR/etc/hadoop/hdfs-site.xml"
done