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
echo

SSH_USER_HOME=/home/$SSH_USER

# Ссылка на дистрибутив Spark
SPARK_URL="https://dlcdn.apache.org/spark/spark-3.5.3/spark-3.5.3-bin-hadoop3.tgz"
SPARK_TGZ="spark-3.5.3-bin-hadoop3.tgz"
SPARK_DIR="/home/$SSH_USER/spark-3.5.3-bin-hadoop3"

# Скачивание spark на джамп-нод, если он ещё не скачан
print_header "Скачиваем Spark на джамп-нод..."
if [[ ! -f "$SPARK_TGZ" ]]; then
    wget "$SPARK_URL" || error_exit "Не удалось скачать Spark."
    check_success
else
    print_header "Spark уже скачан на джамп-ноде."
fi

# Копирование Spark на NameNode
print_header "Копируем архив на неймноду..."
if sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" "[ -f /home/$SSH_USER/$SPARK_TGZ ]"; then
    echo -e "\e[32mАрхив уже существует на неймноде, пропускаем копирование.\e[0m"
else
    sudo -u "$SSH_USER" scp "$SPARK_TGZ" "$SSH_USER@team-4-nn:/home/$SSH_USER/$SPARK_TGZ" || error_exit "Не удалось скопировать архив на неймноду"
    check_success
fi

# Распаковка Spark на NameNode
print_header "Распаковываем Spark на неймноду..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" <<EOF
    if [[ -d "$SPARK_DIR" ]]; then
        echo -e "\e[33mДиректория $SPARK_DIR уже существует. Пропускаем распаковку.\e[0m"
    else
        tar -xzf "/home/$SSH_USER/$SPARK_TGZ" -C "/home/$SSH_USER" || error_exit "Не удалось распаковать архив"
        check_success
    fi
EOF

# Настройка переменных
print_header "Настройка переменных среды на неймноде..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" <<EOF
    echo "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop" >> ~/.profile
    echo "export SPARK_HOME=$SPARK_DIR" >> ~/.profile
    echo "export PATH=\$PATH:\$SPARK_HOME/bin" >> ~/.profile
    echo "export SPARK_DIST_CLASSPATH=\$SPARK_HOME/jars/*:\$(hadoop classpath)" >> ~/.profile
    source ~/.profile
EOF
check_success

# Запись конфигурации в файл hive-site.xml
print_header "Запись конфигурации в файл hive-site.xml ..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" bash <<EOF
if [ ! -f "$SPARK_DIR/conf/hive-site.xml" ]; then
    touch "$SPARK_DIR/conf/hive-site.xml"
fi

cat > "$SPARK_DIR/conf/hive-site.xml" <<EOL
<configuration>
    <property>
        <name>hive.metastore.schema.verification</name>
        <value>false</value>
    </property>
</configuration>
EOL
EOF
check_success

HIVE_HOME=$(sudo -u "$SSH_USER" bash -c "source ~/.profile; echo \$HIVE_HOME")
# Запуск метастора Hive на джамп-ноде
print_header "Запуск метастора Hive на джамп-ноде..."
sudo -u "$SSH_USER" bash -c "source ~/.profile; $HIVE_HOME/bin/hive \
    --hiveconf hive.server2.enable.doAs=false \
    --hiveconf hive.security.authorization.enabled=false \
    --service metastore 1>> /tmp/metastore.log 2>> /tmp/metastore.log &"
sleep 5
check_success

# Установка Python
print_header "Установка Python на неймноде..."
if ! command -v python3 &> /dev/null; then
    sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" "sudo apt install -y python3.12-venv" || error_exit "Не удалось установить python"
    check_success
else
    echo "Python уже установлен, пропускаем установку."
fi

# Настройка виртуального окружения на NameNode
print_header "Настройка виртуального окружения..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" <<EOF
    cd ~
    source ~/.profile
    if [ ! -d ".venv" ]; then
        python3 -m venv .venv || error_exit "Не удалось создать виртуальное окружение"
    else
        echo "Виртуальное окружение уже существует, пропускаем создание."
    fi
    source .venv/bin/activate || error_exit "Не удалось активировать окружение"
    check_success
    if ! pip list | grep -q pyspark; then
        pip install pyspark || error_exit "Не удалось установить pyspark"
    else
        echo "pyspark уже установлен, пропускаем установку."
    fi
EOF
check_success

print_header "Загружаем данные в HDFS..."
HADOOP_HOME=$(sudo -u "$SSH_USER" bash -c "source ~/.profile; echo \$HADOOP_HOME")
HDFS="$HADOOP_HOME/bin/hdfs"
CSV_PATH="/input/ufo_sightings.csv"
if sudo -u $SSH_USER ssh "$SSH_USER@team-4-nn" "$HDFS dfs -test -f $CSV_PATH"; then
    echo "CSV файл с данными $CSV_PATH уже существует."
else
    echo "CSV файл с данными $CSV_PATH не существует. Добавление файла ..."
    sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" "$HDFS dfs -put /home/$SSH_USER/ $CSV_PATH" || error_exit "Не удалось загрузить данные в HDFS."
fi
check_success

# Создание исполняемого Python файла на NameNode
print_header "Создание Python файла на NameNode..."
cp ./run_spark_job.py $SSH_USER_HOME
sudo -u "$SSH_USER" scp $SSH_USER_HOME/run_spark_job.py $SSH_USER@team-4-nn:$SSH_USER_HOME
check_success
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" << EOF
source $SSH_USER_HOME/.venv/bin/activate
python3 $SSH_USER_HOME/run_spark_job.py
EOF

print_header "Завершение автоматической установки spark и получение результирующего набора данных."
