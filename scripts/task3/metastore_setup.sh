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

create_hdf_dir_if_not_exists() {
  HDFS_DIR=$1 # HDFS directory to create
  SSH_USER=$2 # HDFS user on remote host
  SSH_HOSTNAME=$3 # Hostname of remote host
  HDFS=$4 # Directory with hdfs executable

  # Check if the HDFS directory exists
  if sudo -u $SSH_USER ssh "$SSH_USER@$SSH_HOSTNAME" "$HDFS dfs -test -d $HDFS_DIR"; then
      print_header "HDFS директория $HDFS_DIR уже существует."
  else
      print_header "HDFS директории $HDFS_DIR не существует. Создание директории ..."
      sudo -u $SSH_USER ssh "$SSH_USER@$SSH_HOSTNAME" "$HDFS dfs -mkdir -p $HDFS_DIR && $HDFS dfs -chmod g+w $HDFS_DIR" || error_exit "Не удалось создать директорию $HDFS_DIR."
      check_success
  fi
}
TEAM_USER="team"
# Настройка hive-site.xml на нейм-ноде для использования PostgreSQL
NN_HOSTNAME="team-4-nn"
HDFS_TEMP="/tmp"
HDFS_WAREHOUSE="/user/hive/warehouse"
HDFS_INPUT="/input"

read -p "Введите имя пользователя HDFS: " SSH_USER
read -p "Введите имя пользователя для metastore: " METASTORE_USER
read -sp "Введите пароль для пользователя metastore $METASTORE_USER: " METASTORE_PASSWORD
echo

HIVE_HOME=$(sudo -u "$SSH_USER" bash -c "source ~/.profile; echo \$HIVE_HOME")
HIVE_SITE_PATH="$HIVE_HOME/conf/hive-site.xml"

# Проверка наличия hive-site.xml
print_header "Проверка наличия hive-site.xml ..."
sudo -u "$SSH_USER" bash << EOF
if [ -f $HIVE_SITE_PATH ]; then
    echo "Файл существует, очищаем содержимое..."
    > $HIVE_SITE_PATH
else
    echo "Файл не найден, создаем новый..."
    touch $HIVE_SITE_PATH
fi
EOF
check_success

THIFT_PORT="5433"
ABS_METASTORE_ADDRESS="hdfs://$NN_HOSTNAME:9000$HDFS_WAREHOUSE" # HDFS_WAREHOUSE variable is already with / in the beginning

print_header "Запись конфигурации в файл hive-site.xml ..."

sudo -u "$SSH_USER" bash << EOF
cat > "$HIVE_SITE_PATH" << 'EOL'
<configuration>
    <property>
        <name>hive.server2.authentication</name>
        <value>NONE</value>
    </property>
    <property>
        <name>hive.metastore.warehouse.dir</name>
        <value>$ABS_METASTORE_ADDRESS</value>
    </property>
    <property>
        <name>hive.server2.thrift.port</name>
        <value>$THIFT_PORT</value>
        <description>TCP port number to listen on, default 10000</description>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:postgresql://$NN_HOSTNAME/metastore</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>org.postgresql.Driver</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>$METASTORE_USER</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionPassword</name>
        <value>$METASTORE_PASSWORD</value>
    </property>
</configuration>
EOL
EOF


# sudo -u "$SSH_USER" bash -c "echo $HIVE_SITE >> $HIVE_SITE_PATH" || error_exit "Не удалось записать конфигурацию в hive-site.xml"
check_success

# Установка PostgreSQL
print_header "Установка PostgreSQL на нейм-ноде..."
ssh -t "$TEAM_USER@$NN_HOSTNAME" "
    if ! which psql > /dev/null; then
        echo 'PostgreSQL не установлен, начинаем установку...'
        sudo apt-get install -y postgresql
    else
        echo 'PostgreSQL уже установлен'
    fi
" || error_exit "Не удалось проверить установку PostgreSQL"
check_success

PG_USER="postgres"
HIVE_DB="metastore"
# Настройка базы данных
print_header "Настройка базы данных PostgreSQL..."
ssh -t "$TEAM_USER@$NN_HOSTNAME" "
    sudo -u $PG_USER bash -c 'psql <<EOF
CREATE DATABASE $HIVE_DB;
CREATE USER $METASTORE_USER WITH PASSWORD '\''$METASTORE_PASSWORD'\'';
GRANT ALL PRIVILEGES ON DATABASE $HIVE_DB TO $METASTORE_USER;
ALTER DATABASE $HIVE_DB OWNER TO $METASTORE_USER;
EOF'
" || error_exit "Не удалось настроить базу данных PostgreSQL"
check_success

# Проверка и настройка listen_addresses в postgresql.conf
print_header "Настройка listen_addresses в postgresql.conf на нейм-ноде..."
ssh -t "$TEAM_USER@$NN_HOSTNAME" "
    sudo sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '$NN_HOSTNAME'/\" /etc/postgresql/*/main/postgresql.conf
" || error_exit "Не удалось настроить listen_addresses"
check_success

print_header "Настройка pg_hba.conf для аутентификации ..."

NEW_LINE="host    metastore       hive            192.168.1.18/32         password"

ssh -t "$TEAM_USER@$NN_HOSTNAME" "
    sudo sed -i \"/# IPv4 local connections/a $NEW_LINE\" /etc/postgresql/*/main/pg_hba.conf &&
    sudo systemctl restart postgresql
" || error_exit "Не удалось настроить pg_hba.conf"
check_success

echo -e "\e[32mНастройка завершена успешно\e[0m"

HADOOP_HOME=$(sudo -u "$SSH_USER" bash -c "source ~/.profile; echo \$HADOOP_HOME")
HDFS="$HADOOP_HOME/bin/hdfs"

# Creating HDFS directories
create_hdf_dir_if_not_exists "$HDFS_TEMP" "$SSH_USER" "$NN_HOSTNAME" "$HDFS"
create_hdf_dir_if_not_exists "$HDFS_WAREHOUSE" "$SSH_USER" "$NN_HOSTNAME" "$HDFS"
create_hdf_dir_if_not_exists "$HDFS_INPUT" "$SSH_USER" "$NN_HOSTNAME" "$HDFS"

print_header "Инициализация схемы данных ..."
sudo -u "$SSH_USER" bash -c "source ~/.profile; $HIVE_HOME/bin/schematool -dbType postgres -initSchema" || error_exit "Не удалось установить клиент."
check_success

print_header "Установка PostgreSQL клиента на джамп-ноду ..."
sudo apt install -y postgresql-client-16 || error_exit "Не удалось установить клиент."
check_success

print_header "Запуск Hive ..."
sudo -u "$SSH_USER" bash -c "source ~/.profile; $HIVE_HOME/bin/hive \
    --hiveconf hive.server2.enable.doAs=false \
    --hiveconf hive.security.authorization.enabled=false \
    --service hiveserver2 1>> /tmp/hs2.log 2>> /tmp/hs2.log &"
sleep 5

print_header "К Hive добавлен metastore"