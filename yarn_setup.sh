#!/bin/bash

# Функция для отображения ошибки и выхода
error_exit() {
    echo -e "\e[31m[Ошибка] $1\e[0m"
    exit 1
}

# Функция для проверки успешного выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "\e[32mУспешно выполнено\e[0m"
    fi
}

# Функция для отображения заголовков
print_header() {
    echo -e "\e[33m>>>>>>>>>>>>>>>> $1 <<<<<<<<<<<<<<<\e[0m"
}

# Ввод имени пользователя и пароля для каждого сервера
read -p "Введите имя пользователя для подключения: " SSH_USER
read -sp "Введите пароль для пользователя $SSH_USER: " SSH_PASS
echo

# Чтение IP-адресов и имен хостов из файла hosts.txt
HOSTS_FILE="hosts.txt"
mapfile -t HOSTS < "$HOSTS_FILE"

# Ссылка на директорию конфигурации Hadoop
HADOOP_CONFIG_DIR="/home/$SSH_USER/hadoop-3.4.0/etc/hadoop"

# Настраиваем конфигурацию на name-node (192.168.1.19, team-4-nn)
print_header "Настройка конфигурационных файлов на нейм-ноду (team-4-nn)"

# Установка mapred-site.xml для History Server на name-node
sshpass -p "$SSH_PASS" ssh "$SSH_USER@team-4-nn" "echo '<configuration>
<property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
</property>
<property>
    <name>mapreduce.application.classpath</name>
    <value>\$HADOOP_HOME/share/hadoop/mapreduce/*:\$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
</property>
</configuration>' > $HADOOP_CONFIG_DIR/mapred-site.xml"
check_success "Не удалось настроить mapred-site.xml на name-node"

# Установка yarn-site.xml для YARN на name-node
sshpass -p "$SSH_PASS" ssh "$SSH_USER@team-4-nn" "echo '<configuration>
<property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
</property>
<property>
    <name>yarn.nodemanager.env-whitelist</name>
    <value>JAVA_HOME, HADOOP_COMMON_HOME, HADOOP_HDFS_HOME, HADOOP_CONF_DIR</value>
</property>
</configuration>' > $HADOOP_CONFIG_DIR/yarn-site.xml"
check_success "Не удалось настроить yarn-site.xml на name-node"

# Копирование файлов с name-node на data-nodes
print_header "Копирование конфигурационных файлов на дата-ноды"
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-dn-0" || "$SERVER_HOST" == "team-4-dn-1" ]]; then
        print_header "Копирование конфигурации на $SERVER_HOST ($SERVER_IP)"
        
        sshpass -p "$SSH_PASS" scp "$SSH_USER@team-4-nn:$HADOOP_CONFIG_DIR/mapred-site.xml" "$SSH_USER@$SERVER_IP:$HADOOP_CONFIG_DIR/"
        check_success "Не удалось скопировать mapred-site.xml на $SERVER_HOST"
        
        sshpass -p "$SSH_PASS" scp "$SSH_USER@team-4-nn:$HADOOP_CONFIG_DIR/yarn-site.xml" "$SSH_USER@$SERVER_IP:$HADOOP_CONFIG_DIR/"
        check_success "Не удалось скопировать yarn-site.xml на $SERVER_HOST"
    fi
done

# Запуск YARN и History Server на нейм-ноде
print_header "Запуск YARN и History Server на нейм-ноде"
sshpass -p "$SSH_PASS" ssh "$SSH_USER@team-4-nn" "cd /home/$SSH_USER/hadoop-3.4.0 && sbin/start-yarn.sh && mapred --daemon start historyserver"
check_success "Не удалось запустить YARN или History Server на нейм-ноде"

# Настройка nginx на Jump Node для проксирования веб-интерфейсов
NGINX_DIR="/etc/nginx/sites-available"
print_header "Настройка nginx на джамп-ноде для веб-интерфейсов"

declare -A NGINX_SITES
NGINX_SITES["nn"]="9870"   # Namenode
NGINX_SITES["ya"]="8088"   # YARN
NGINX_SITES["dh"]="19888"  # History Server

for SITE in "${!NGINX_SITES[@]}"; do
    PORT="${NGINX_SITES[$SITE]}"
    CONF_FILE="$NGINX_DIR/$SITE"
    print_header "Создание конфигурации $CONF_FILE для порта $PORT"
    
    # Копирование дефолтного файла конфигурации
    sudo cp /etc/nginx/sites-available/default "$CONF_FILE"
    check_success "Не удалось скопировать дефолтный файл конфигурации для $SITE"

    # Настройка конфигурационного файла для соответствующего веб-интерфейса
    echo "server {
    listen $PORT default_server;
    location / {
        proxy_pass http://team-4-nn:$PORT;
    }
}" | sudo tee "$CONF_FILE" > /dev/null
    check_success "Не удалось создать конфигурацию для $SITE"
    
    # Создаем симлинк для активации
    sudo ln -s "$CONF_FILE" "/etc/nginx/sites-enabled/$SITE"
    check_success "Не удалось создать симлинк для $SITE"
done

# Перезагружаем nginx для применения конфигурации
print_header "Перезагрузка nginx"
sudo systemctl reload nginx
check_success "Не удалось перезагрузить nginx"

print_header "Конфигурация завершена. Веб-интерфейсы доступны без авторизации по паролю."

