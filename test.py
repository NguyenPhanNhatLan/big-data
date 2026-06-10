from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("ReadAMLCSV").getOrCreate()
spark.sparkContext.setLogLevel("WARN")

path = "hdfs://100.127.25.114:9000/data/hotel_bookings.csv"


df = (
    spark.read
    .option("header", True)
    .option("inferSchema", True)
    .csv(path)
)

print("Rows:", df.count())
print("Columns:", len(df.columns))
df.printSchema()
df.show(10, truncate=False)

spark.stop()