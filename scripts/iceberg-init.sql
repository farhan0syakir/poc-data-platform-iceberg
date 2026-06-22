-- Iceberg initialization using Spark SQL
-- Creates Iceberg tables in the MinIO warehouse and seeds them with sample data

CREATE TABLE IF NOT EXISTS s3.default.customers (
  id INT,
  first_name STRING,
  last_name STRING,
  email STRING,
  phone STRING,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)
USING ICEBERG
PARTITIONED BY (years(created_at), months(created_at));

CREATE TABLE IF NOT EXISTS s3.default.products (
  id INT,
  name STRING,
  price DECIMAL(10, 2),
  category STRING,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)
USING ICEBERG
PARTITIONED BY (category, years(created_at));

CREATE TABLE IF NOT EXISTS s3.default.orders (
  id INT,
  customer_id INT,
  order_date TIMESTAMP,
  total_amount DECIMAL(12, 2),
  status STRING,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)
USING ICEBERG
PARTITIONED BY (years(order_date), months(order_date), status);

INSERT INTO s3.default.customers VALUES
  (1, 'John', 'Doe', 'john@example.com', '+1-555-0101', current_timestamp(), current_timestamp()),
  (2, 'Jane', 'Smith', 'jane@example.com', '+1-555-0102', current_timestamp(), current_timestamp());

INSERT INTO s3.default.products VALUES
  (1, 'Laptop', 999.99, 'Electronics', current_timestamp(), current_timestamp()),
  (2, 'Mouse', 29.99, 'Electronics', current_timestamp(), current_timestamp());

INSERT INTO s3.default.orders VALUES
  (1, 1, current_timestamp(), 1329.97, 'delivered', current_timestamp(), current_timestamp()),
  (2, 2, current_timestamp(), 299.99, 'pending', current_timestamp(), current_timestamp());

SHOW TABLES IN s3.default;

