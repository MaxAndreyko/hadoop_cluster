from prefect import flow, task
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from prefect.cache_policies import NONE

# Настройки Spark
def create_spark_session():
    return SparkSession.builder \
        .master("yarn") \
        .appName("PrefectSparkProcessing") \
        .config("spark.sql.warehouse.dir", "/user/hive/warehouse") \
        .config("spark.hadoop.hive.metastore.uris", "thrift://team-4-jn:9083") \
        .enableHiveSupport() \
        .getOrCreate()

# Чтение данных
@task(cache_policy=NONE)
def read_data(spark, input_path):
    return spark.read.csv(input_path, header=True, inferSchema=True)

# Трансформация данных
@task(cache_policy=NONE)
def transform_data(df):
    df = df.withColumn("year", F.year(F.to_date(F.col("date"), "MM/yyyy"))) \
           .withColumn("year_group", (F.col("year") / 2).cast("int") * 2)

    df_transformed = df.groupBy("year_group").agg(
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
    df.write \
        .partitionBy("year_group") \
        .mode("overwrite") \
        .format("csv") \
        .save(output_path)
    
    # Сохранение в Hive
    df.write \
        .partitionBy("year_group") \
        .mode("overwrite") \
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