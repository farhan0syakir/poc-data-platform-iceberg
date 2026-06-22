#!/usr/bin/env python3
"""
Iceberg table initialization script
This script creates Iceberg tables from the CDC data
"""

from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DecimalType, TimestampType
from datetime import datetime

def create_spark_session():
    """Create Spark session with Iceberg configuration"""
    spark = SparkSession.builder \
        .appName("IcebergInitializer") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.s3", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.s3.type", "hadoop") \
        .config("spark.sql.catalog.s3.warehouse", "s3a://warehouse/") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false") \
        .getOrCreate()

    return spark

def create_iceberg_tables(spark):
    """Create Iceberg tables for CDC data and seed them with sample rows"""

    # Create customers table
    customers_schema = StructType([
        StructField("id", IntegerType(), False),
        StructField("first_name", StringType(), False),
        StructField("last_name", StringType(), False),
        StructField("email", StringType(), True),
        StructField("phone", StringType(), True),
        StructField("created_at", TimestampType(), True),
        StructField("updated_at", TimestampType(), True)
    ])

    spark.sql("""
        CREATE TABLE IF NOT EXISTS s3.warehouse.customers (
            id INT,
            first_name STRING,
            last_name STRING,
            email STRING,
            phone STRING,
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        )
        USING ICEBERG
        PARTITIONED BY (year(created_at), month(created_at))
    """)

    # Create products table
    spark.sql("""
        CREATE TABLE IF NOT EXISTS s3.warehouse.products (
            id INT,
            name STRING,
            price DECIMAL(10, 2),
            category STRING,
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        )
        USING ICEBERG
        PARTITIONED BY (category, year(created_at))
    """)

    # Create orders table
    spark.sql("""
        CREATE TABLE IF NOT EXISTS s3.warehouse.orders (
            id INT,
            customer_id INT,
            order_date TIMESTAMP,
            total_amount DECIMAL(12, 2),
            status STRING,
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        )
        USING ICEBERG
        PARTITIONED BY (year(order_date), month(order_date), status)
    """)

    customers = [
        (1, "John", "Doe", "john@example.com", "+1-555-0101", datetime.utcnow(), datetime.utcnow()),
        (2, "Jane", "Smith", "jane@example.com", "+1-555-0102", datetime.utcnow(), datetime.utcnow()),
    ]
    products = [
        (1, "Laptop", 999.99, "Electronics", datetime.utcnow(), datetime.utcnow()),
        (2, "Mouse", 29.99, "Electronics", datetime.utcnow(), datetime.utcnow()),
    ]
    orders = [
        (1, 1, datetime.utcnow(), 1329.97, "delivered", datetime.utcnow(), datetime.utcnow()),
        (2, 2, datetime.utcnow(), 299.99, "pending", datetime.utcnow(), datetime.utcnow()),
    ]

    spark.createDataFrame(customers, customers_schema).writeTo("s3.warehouse.customers").append()
    spark.createDataFrame(products, ["id", "name", "price", "category", "created_at", "updated_at"]).writeTo("s3.warehouse.products").append()
    spark.createDataFrame(orders, ["id", "customer_id", "order_date", "total_amount", "status", "created_at", "updated_at"]).writeTo("s3.warehouse.orders").append()

    print("Iceberg tables created and seeded successfully!")

if __name__ == "__main__":
    spark = create_spark_session()
    create_iceberg_tables(spark)
    spark.stop()

