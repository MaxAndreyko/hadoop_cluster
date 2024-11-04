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

read -p "Введите имя пользователя HDFS: " SSH_USER

DATA_PATH="/home/$SSH_USER/ufo_sightings.csv"

# 1. Скачивание данных
print_header "Проверка наличия данных..."
if sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" "test -f $DATA_PATH"; then
    print_header "Данные уже скачаны."
else
    print_header "Скачиваем данные..."
    sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" "wget -O $DATA_PATH https://raw.githubusercontent.com/rdjoshi0906/Dataset_UFO/refs/heads/main/ufo_sightings.csv" || error_exit "Не удалось скачать данные."
    check_success
fi

# 2. Загрузка данных в HDFS
print_header "Загружаем данные в HDFS..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" "source ~/.profile; hdfs dfs -put $DATA_PATH /input" || error_exit "Не удалось загрузить данные в HDFS."
check_success

# 3. Запуск консоли beeline и выполнение SQL-команд
print_header "Запуск beeline и настройка базы данных Hive..."
sudo -u "$SSH_USER" bash -c 'source ~/.profile; beeline -u jdbc:hive2://team-4-jn:5433 <<EOF
CREATE DATABASE IF NOT EXISTS test;
USE test;

CREATE TABLE IF NOT EXISTS test.ufo_sightings (
    details string,
    datetime string,
    city string,
    state string,
    country string,
    shape string,
    summary string,
    report_date string,
    posted_date string,
    month_count int
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ","; 

LOAD DATA INPATH "hdfs://team-4-nn:9000/input/ufo_sightings.csv" INTO TABLE test.ufo_sightings;

CREATE TABLE IF NOT EXISTS test.partitioned_ufo (
    details string,
    datetime string,
    city string,
    state string,
    country string,
    shape string,
    summary string,
    report_date string,
    posted_date string
) PARTITIONED BY (month_count int)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ","; 

INSERT INTO TABLE test.partitioned_ufo PARTITION (month_count)
SELECT
    details,
    datetime,
    city,
    state,
    country,
    shape,
    summary,
    report_date,
    posted_date,
    month_count
FROM test.ufo_sightings WHERE month_count IS NOT NULL;

SHOW PARTITIONS test.partitioned_ufo;
EOF'
check_success

print_header "Завершение автоматической загрузки и трансформации данных."