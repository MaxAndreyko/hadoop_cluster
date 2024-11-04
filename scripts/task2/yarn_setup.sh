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
    else
        error_exit "Команда завершилась с ошибкой."
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
mapfile -t HOSTS < "$HOSTS_FILE" || error_exit "Не удалось прочитать файл $HOSTS_FILE."

# Ссылка на директорию конфигурации Hadoop
HADOOP_CONFIG_DIR="/home/$SSH_USER/hadoop-3.4.0/etc/hadoop"

# Настраиваем конфигурацию на неймноде
print_header "Настройка конфигурационных файлов на нейм-ноду (team-4-nn)"

# Настройка mapred-site.xml для History Server
ssh "$SSH_USER@team-4-nn" "echo '<configuration>
<property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
</property>
<property>
    <name>mapreduce.application.classpath</name>
    <value>\$HADOOP_HOME/share/hadoop/mapreduce/*:\$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
</property>
</configuration>' > $HADOOP_CONFIG_DIR/mapred-site.xml" || error_exit "Не удалось установить mapred-site.xml."
check_success

# Настройка yarn-site.xml для YARN
ssh "$SSH_USER@team-4-nn" "echo '<configuration>
<property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
</property>
<property>
    <name>yarn.nodemanager.env-whitelist</name>
    <value>JAVA_HOME, HADOOP_COMMON_HOME, HADOOP_HDFS_HOME, HADOOP_CONF_DIR, CLASSPATH_PREPEND_DISTCACHE, HADOOP_YARN_HOME, HADOOP_HOME, PATH, LANG, TZ, HADOOP_MAPRED_HOME</value>
</property>
</configuration>' > $HADOOP_CONFIG_DIR/yarn-site.xml" || error_exit "Не удалось установить yarn-site.xml."
check_success

# Копирование файлов с нейм-ноды на дата-ноды
print_header "Копирование конфигурационных файлов на дата-ноды"
for ENTRY in "${HOSTS[@]}"; do
    SERVER_IP=$(echo "$ENTRY" | awk '{print $1}')
    SERVER_HOST=$(echo "$ENTRY" | awk '{print $2}')

    if [[ "$SERVER_HOST" == "team-4-dn-0" || "$SERVER_HOST" == "team-4-dn-1" ]]; then
        print_header "Копирование конфигурации на $SERVER_HOST ($SERVER_IP)"
        
        # Проверка и копирование mapred-site.xml
        sshpass -p "$SSH_PASS" ssh "$SSH_USER@$SERVER_IP" "[ -f $HADOOP_CONFIG_DIR/mapred-site.xml ] || scp $SSH_USER@team-4-nn:$HADOOP_CONFIG_DIR/mapred-site.xml $SSH_USER@$SERVER_IP:$HADOOP_CONFIG_DIR/" || error_exit "Не удалось скопировать mapred-site.xml на $SERVER_HOST."
        check_success

        # Проверка и копирование yarn-site.xml
        sshpass -p "$SSH_PASS" ssh "$SSH_USER@$SERVER_IP" "[ -f $HADOOP_CONFIG_DIR/yarn-site.xml ] || scp $SSH_USER@team-4-nn:$HADOOP_CONFIG_DIR/yarn-site.xml $SSH_USER@$SERVER_IP:$HADOOP_CONFIG_DIR/" || error_exit "Не удалось скопировать yarn-site.xml на $SERVER_HOST."
        check_success
    fi
done

# Запуск YARN и History Server на нейм-ноде
print_header "Запуск YARN и History Server на нейм-ноде"
ssh "$SSH_USER@team-4-nn" "cd /home/$SSH_USER/hadoop-3.4.0 && sbin/start-yarn.sh && bin/mapred --daemon start historyserver" || error_exit "Не удалось запустить YARN и History Server."
check_success

# Установить apache2-utils на джамп-ноде
print_header "Установка apache2-utils"
ssh -t team@team-4-jn "dpkg -l | grep -q apache2-utils || (sudo apt update && sudo apt install -y apache2-utils)" || error_exit "Не удалось установить apache2-utils."
check_success

# Создать директорию для хранения паролей
print_header "Создание директории для хранения паролей"
ssh -t team@team-4-jn "[ -d /etc/team4passwd ] || sudo mkdir -p /etc/team4passwd" || error_exit "Не удалось создать директорию для хранения паролей."
check_success

# Настройка пароля для доступа к веб-интерфейсу
print_header "Настройка пароля для доступа к веб-интерфейсу"
read -p "Введите имя пользователя для веб-интерфейса: " WEB_USER
ssh -t team@team-4-jn "sudo htpasswd -c /etc/team4passwd/.htpasswd $WEB_USER" || error_exit "Не удалось настроить пароль для веб-интерфейса."
check_success

# Настройка nginx на джамп-ноде для проксирования веб-интерфейсов
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

    # Настройка конфигурационного файла для соответствующего веб-интерфейса
    ssh -t team@team-4-jn "echo 'server {
    listen $PORT default_server;
    location / {
        proxy_pass http://team-4-nn:$PORT;
        auth_basic           \"Administrator’s Area\";
        auth_basic_user_file /etc/team4passwd/.htpasswd;
    }
}' | sudo tee \"$CONF_FILE\" > /dev/null" || error_exit "Не удалось настроить конфигурацию nginx для $SITE."
    check_success
    
    # Создаем симлинк для активации
    ssh -t team@team-4-jn "sudo ln -s \"$CONF_FILE\" \"/etc/nginx/sites-enabled/$SITE\"" || error_exit "Не удалось создать симлинк для $SITE."
    check_success
done

# Перезагружаем nginx для применения конфигурации
print_header "Перезагрузка nginx"
ssh -t team@team-4-jn "sudo systemctl reload nginx" || error_exit "Не удалось перезагрузить nginx."
check_success

print_header "Завершение автоматической настройки и запуска веб-интерфейсов."