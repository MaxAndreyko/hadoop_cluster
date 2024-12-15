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

# Установка Prefect
print_header "Установка Prefect..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" <<EOF
source .venv/bin/activate
if ! pip show prefect > /dev/null 2>&1; then
    echo "Prefect не установлен. Запуск установки ..."
    pip install prefect
else
    echo "Prefect уже установлен"
fi
EOF
check_success

print_header "Загружаем данные в HDFS..."
HADOOP_HOME=$(sudo -u "$SSH_USER" bash -c "source ~/.profile; echo \$HADOOP_HOME")
HDFS="$HADOOP_HOME/bin/hdfs"
CSV_PATH="/input/ufo_sightings.csv"
if sudo -u $SSH_USER ssh "$SSH_USER@team-4-nn" "$HDFS dfs -test -f $CSV_PATH"; then
    print_header "CSV файл с данными $CSV_PATH уже существует."
else
    print_header "CSV файл с данными $CSV_PATH не существует. Добавление файла ..."
    sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" "$HDFS dfs -put /home/$SSH_USER/ $CSV_PATH" || error_exit "Не удалось загрузить данные в HDFS."
fi
check_success

# Создание Python файла для Prefect-потока
print_header "Создание Python файла Prefect-потока..."
cp ./prefect_flow.py $SSH_USER_HOME
sudo -u "$SSH_USER" scp $SSH_USER_HOME/prefect_flow.py $SSH_USER@team-4-nn:$SSH_USER_HOME
check_success


# Запуск потока Prefect
print_header "Запуск Prefect-потока..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" <<EOF
if pgrep -f "python3 $SSH_USER_HOME/prefect_flow.py" > /dev/null 2>&1; then
    echo "Prefect-поток уже запущен."
else
    source .venv/bin/activate
    python3 $SSH_USER_HOME/prefect_flow.py
fi
EOF
check_success

print_header "Завершение автоматической установки prefect и получение результирующего набора данных под его управлением."
