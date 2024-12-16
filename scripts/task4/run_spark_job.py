from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Создание SparkSession с поддержкой YARN и Hive
spark = SparkSession.builder \
    .master("yarn") \
    .appName("spark-with-yarn") \
    .config("spark.sql.warehouse.dir", "/user/hive/warehouse") \
    .config("spark.hadoop.hive.metastore.uris", "thrift://team-4-jn:9083") \
    .enableHiveSupport() \
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

print("Вывод преобразованных данных")
# Вывод преобразованных данных
df_transformed.show()

# Сохранение результирующего набора данных в CSV с партиционированием
output_path = "/input/dataset_transformed"
df_transformed.write \
    .partitionBy("year") \
    .mode("overwrite") \
    .format("csv") \
    .save(output_path)

# Сохранение данных в Hive как партиционированную таблицу
df_transformed.write \
    .partitionBy("year") \
    .mode("overwrite") \
    .saveAsTable("test.ufo_analysis_table")