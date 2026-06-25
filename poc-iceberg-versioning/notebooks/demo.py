from pyspark.sql import SparkSession
import os

# Initialize Spark Session
spark = SparkSession.builder \
    .appName("IcebergVersioningDemo") \
    .getOrCreate()

print("Spark Session Initialized")

# 1. Create a table
spark.sql("CREATE TABLE IF NOT EXISTS nessie.dev.demo_table (id int, data string) USING iceberg")

# 2. Insert some data
spark.sql("INSERT INTO nessie.dev.demo_table VALUES (1, 'initial data')")
spark.sql("INSERT INTO nessie.dev.demo_table VALUES (2, 'more data')")

# 3. Show snapshots
print("Table Snapshots:")
spark.sql("SELECT * FROM nessie.dev.demo_table.snapshots").show()

# 4. Time Travel
# Get the first snapshot ID
first_snapshot = spark.sql("SELECT snapshot_id FROM nessie.dev.demo_table.snapshots ORDER BY committed_at ASC LIMIT 1").collect()[0][0]

print(f"Time traveling to first snapshot: {first_snapshot}")
spark.read.option("snapshot-id", first_snapshot).table("nessie.dev.demo_table").show()

# 5. Branching with Nessie
print("Creating branch 'experiment'...")
spark.sql("CREATE BRANCH experiment IN nessie")

print("Switching to branch 'experiment'...")
spark.sql("USE REFERENCE experiment IN nessie")

spark.sql("INSERT INTO nessie.dev.demo_table VALUES (3, 'experimental data')")
print("Data on 'experiment' branch:")
spark.sql("SELECT * FROM nessie.dev.demo_table").show()

print("Switching back to 'main' branch...")
spark.sql("USE REFERENCE main IN nessie")
print("Data on 'main' branch (should not have experimental data):")
spark.sql("SELECT * FROM nessie.dev.demo_table").show()

