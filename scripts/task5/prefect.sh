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
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" <<EOF
cat <<PYTHON_SCRIPT > ~/prefect_flow.py
from prefect import flow, task
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from prefect.cache_policies import NONE

# Настройки Spark
def create_spark_session():
    return SparkSession.builder \\
        .master("yarn") \\
        .appName("PrefectSparkProcessing") \\
        .config("spark.sql.warehouse.dir", "/user/hive/warehouse") \\
        .config("spark.hadoop.hive.metastore.uris", "thrift://team-4-jn:9083") \\
        .enableHiveSupport() \\
        .getOrCreate()

# Чтение данных
@task(cache_policy=NONE)
def read_data(spark, input_path):
    return spark.read.csv(input_path, header=True, inferSchema=True)

# Трансформация данных
@task(cache_policy=NONE)
def transform_data(df):
    df = df.withColumn("year", F.year(F.to_date(F.col("date"), "MM/yyyy")))

    df_transformed = df.groupBy("year").agg(
        F.max("date").alias("max_date"),
        F.min("date").alias("min_date"),
        F.countDistinct("city").alias("unique_cities"),
        F.countDistinct("shape").alias("unique_shapes"),
        F.expr("percentile_approx(month_count, 0.5)").alias("median_month_count"),
        F.avg(F.datediff(F.to_date("report_date", "MM/dd/yyyy"), F.to_date("posted_date", "MM/dd/yyyy"))).alias("avg_days_diff")
    )
    return df_transformed

# Сохранение данных
@task(cache_policy=NONE)
def save_data(df, output_path, hive_table):
    # Сохранение в HDFS
    df.write \\
        .partitionBy("year") \\
        .mode("overwrite") \\
        .format("csv") \\
        .save(output_path)
    
    # Сохранение в Hive
    df.write \\
        .partitionBy("year") \\
        .mode("overwrite") \\
        .saveAsTable(hive_table)

# Основной поток
@flow
def spark_data_processing(input_path, output_path, hive_table):
    spark = create_spark_session()
    df = read_data(spark, input_path)
    df_transformed = transform_data(df)
    save_data(df_transformed, output_path, hive_table)

# Запуск потока
if __name__ == "__main__":
    spark_data_processing(
        input_path="/input/ufo_sightings.csv",
        output_path="/input/dataset_transformed",
        hive_table="test.prefectTestTable"
    )
PYTHON_SCRIPT
EOF
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
