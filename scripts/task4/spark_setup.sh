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

# Ссылка на дистрибутив Spark
SPARK_URL="ttps://dlcdn.apache.org/spark/spark-3.5.3/spark-3.5.3-bin-hadoop3.tgz"
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
    echo "export SPARK_HOME=/home/$SSH_USER/spark-3.5.3-bin-hadoop3" >> ~/.profile
    echo "export PATH=\$PATH:\$SPARK_HOME/bin" >> ~/.profile
    echo "export SPARK_DIST_CLASSPATH=\$SPARK_HOME/jars/*:\$(hadoop classpath)" >> ~/.profile
    source ~/.profile
EOF
check_success

# Запись конфигурации в файл hive-site.xml
print_header "Запись конфигурации в файл hive-site.xml ..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" bash <<EOF
if [ ! -f "$SPARK_HOME/conf/hive-site.xml" ]; then
    touch "$SPARK_HOME/conf/hive-site.xml"
fi

cat > "$SPARK_HOME/conf/hive-site.xml" <<EOL
<configuration>
    <property>
        <name>hive.metastore.schema.verification</name>
        <value>false</value>
    </property>
</configuration>
EOL
EOF
check_success

# Запуск метастора Hive на джамп-ноде
print_header "Запуск метастора Hive на джамп-ноде..."
if pgrep -f "HiveMetastore" > /dev/null; then
    echo -e "\e[32mМетастор Hive уже запущен, пропускаем шаг.\e[0m"
else
    nohup hive --hiveconf hive.server2.enable.doAs=false --hiveconf hive.security.authorization.enabled=false --service metastore 1>> /tmp/metastore.log 2>> /tmp/metastore.log & || error_exit "Не удалось запустить метастора Hive"
    check_success
fi

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
        check_success
    else
        echo "Виртуальное окружение уже существует, пропускаем создание."
    fi
    source .venv/bin/activate || error_exit "Не удалось активировать окружение"
    check_success
    if ! pip list | grep -q pyspark; then
        pip install pyspark || error_exit "Не удалось установить pyspark"
        check_success
    else
        echo "pyspark уже установлен, пропускаем установку."
    fi
    check_success
EOF

print_header "Загружаем данные в HDFS..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" "hdfs dfs -put /home/$SSH_USER/ufo_sightings.csv /input" || error_exit "Не удалось загрузить данные в HDFS."
check_success

# Создание исполняемого Python файла на NameNode
print_header "Создание Python файла на NameNode..."
sudo -u "$SSH_USER" ssh "$SSH_USER@team-4-nn" <<EOF
cat <<PYTHON_SCRIPT > ~/run_spark_job.py
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Создание SparkSession с поддержкой YARN и Hive
spark = SparkSession.builder \\
    .master("yarn") \\
    .appName("spark-with-yarn") \\
    .config("spark.sql.warehouse.dir", "/user/hive/warehouse") \\
    .config("spark.hadoop.hive.metastore.uris", "thrift://team-4-jn:9083") \\
    .enableHiveSupport() \\
    .getOrCreate()

# Загрузка исходного CSV-файла в DataFrame
df = spark.read.csv(
    "/input/ufo_sightings.csv",
    header=True,
    inferSchema=True
)

# Преобразование даты и добавление столбца "year" для уменьшения числа партиций
df = df.withColumn("year", F.year(F.to_date(F.col("date"), "MM/yyyy")))

# Применение агрегирующих и трансформирующих функций
df_transformed = df.groupBy("year").agg(
    F.max("date").alias("max_date"),
    F.min("date").alias("min_date"),
    F.countDistinct("city").alias("unique_cities"),
    F.countDistinct("shape").alias("unique_shapes"),
    F.expr("percentile_approx(month_count, 0.5)").alias("median_month_count"),
    F.avg(F.datediff(
        F.to_date("report_date", "MM/dd/yyyy"),
        F.to_date("posted_date", "MM/dd/yyyy")
    )).alias("avg_days_diff")
)

# Вывод преобразованных данных
df_transformed.show()

# Сохранение результирующего набора данных в CSV с партиционированием
output_path = "/input/dataset_transformed"
df_transformed.write \\
    .partitionBy("year") \\
    .mode("overwrite") \\
    .format("csv") \\
    .save(output_path)

# Сохранение данных в Hive как партиционированную таблицу
df_transformed.write \\
    .partitionBy("year") \\
    .mode("overwrite") \\
    .saveAsTable("ufo_analysis_table")
PYTHON_SCRIPT
EOF
check_success

