# Data Platform with Iceberg, CDC, Local S3, and BI

A comprehensive Docker Compose setup that simulates a complete data platform with PostgreSQL, CDC (Kafka Connect), Iceberg, local MinIO S3, Metabase, and Dremio OSS.

## Architecture

```
PostgreSQL (CDC Source)
         ↓
    Kafka Connect (Debezium CDC)
         ↓
      Kafka Topics
         ↓
Spark + Iceberg (Warehouse)
         ↓
    MinIO (S3 Storage)
         ↓
  Metabase / Dremio (BI + SQL)
```

## Services

- **PostgreSQL**: Source database with sample data and logical replication support
- **Zookeeper**: Coordination service for Kafka
- **Kafka**: Message broker for CDC events
- **Kafka UI**: Web interface for Kafka management (port 8080)
- **Kafka Connect**: Connectors for capturing changes from PostgreSQL using Debezium
- **MinIO**: S3-compatible object storage (local)
- **Nessie**: Iceberg metadata catalog server
- **Spark Master/Worker**: Execution engine for Iceberg operations
- **Metabase**: Open-source data visualization and dashboarding platform
- **Dremio OSS**: SQL query engine and semantic layer for lakehouse datasets
- **Adminer**: Web-based database manager for PostgreSQL

## Quick Start

### 1. Prerequisites

- Docker
- Docker Compose
- ~8GB free RAM (recommended)

### 2. Start Everything

Use the single setup script to download connectors, start services, and create the CDC connector:

```bash
./setup.sh
```

If you want to watch startup logs while it runs, open another terminal and run:

```bash
docker-compose logs -f
```

## Access the Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **Metabase** (Dashboard) | http://localhost:8088 | Initial setup wizard |
| **Dremio OSS** | http://localhost:9047 | Create admin user on first login |
| **Kafka UI** | http://localhost:8080 | - |
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin |
| **Adminer** (Database UI) | http://localhost:8082 | - |
| **Spark Master** | http://localhost:8888 | - |
| **Postgres** | localhost:5432 | postgres / postgres |
| **Kafka** | localhost:9092 | - |
| **Nessie API** | http://localhost:19120 | - |

## Configuration

### Step 1: Verify the CDC Connector

`./setup.sh` creates the connector for you. If you want to inspect it manually:

```bash
curl http://localhost:8083/connectors
curl http://localhost:8083/connectors/postgres-cdc-connector/status
```

### Step 2: Monitor CDC Events in Kafka UI

Open http://localhost:8080 and navigate to Topics to see the CDC events being captured:
- `cdc.customers`
- `cdc.products`
- `cdc.orders`

### Step 3: Create Iceberg Tables in Spark

Submit the Iceberg initialization job:

```bash
docker-compose exec spark-master spark-submit \
  --master local[*] \
  --properties-file /opt/spark-conf/spark-defaults.conf \
  --packages org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.3.1,org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262 \
  /tmp/iceberg-init.sql
```

This step writes Iceberg metadata and sample rows into MinIO, so the bucket will only be empty before this Spark job runs.

### Step 4: Complete Metabase Setup

1. Open http://localhost:8088
2. Complete the Metabase onboarding wizard
3. Add PostgreSQL as a database and configure:
   - Host: `postgres`
   - Port: `5432`
   - Database: `testdb`
   - Username: `postgres`
   - Password: `postgres`
4. Test and save the connection

### Step 5: Create Dashboards in Metabase

1. Use the Metabase question editor or native SQL editor
2. Select the PostgreSQL database
3. Run queries on `customers`, `products`, and `orders` tables
4. Create charts, saved questions, and dashboards from query results

### Step 6: Configure Dremio (Optional)

1. Open http://localhost:9047
2. Create the initial admin account
3. Add object storage source (MinIO) and Nessie catalog if you want branch-aware Iceberg exploration
4. Query your tables from the SQL Runner

## Database Tables

### Customers
```sql
SELECT * FROM customers;
```

### Products
```sql
SELECT * FROM products;
```

### Orders
```sql
SELECT * FROM orders;
```

## Generate Test Data Changes for CDC

To test the CDC pipeline, insert new data into PostgreSQL:

```bash
# Connect to PostgreSQL
psql -h localhost -U postgres -d testdb -c "
  INSERT INTO customers (first_name, last_name, email) VALUES ('Test', 'User', 'test@example.com');
  INSERT INTO products (name, price, category) VALUES ('Test Product', 99.99, 'Test');
  INSERT INTO orders (customer_id, total_amount, status) VALUES (1, 199.99, 'pending');
"
```

Watch the changes flow through Kafka:
1. Open Kafka UI (http://localhost:8080)
2. Navigate to Topics
3. Select `cdc.customers`, `cdc.products`, or `cdc.orders`
4. View messages in real-time

## Useful Commands

### View PostgreSQL logs
```bash
docker-compose logs postgres
```

### View Kafka Connect logs
```bash
docker-compose logs kafka-connect
```

### View Kafka logs
```bash
docker-compose logs kafka
```

### Connect to PostgreSQL
```bash
docker-compose exec postgres psql -U postgres -d testdb
```

### View Kafka topics
```bash
docker-compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

### Consume messages from a topic
```bash
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic cdc.customers \
  --from-beginning
```

### Check Kafka Connect connectors
```bash
curl http://localhost:8083/connectors
```

### Delete a connector
```bash
curl -X DELETE http://localhost:8083/connectors/postgres-cdc-connector
```

## Performance Tuning

For production-like workloads:

1. **Increase Kafka partitions**: Edit docker-compose.yml and adjust `KAFKA_NUM_PARTITIONS`
2. **Increase Spark resources**: Modify `spark.driver.memory` and `spark.executor.memory`
3. **Optimize Iceberg partitioning**: Adjust partition columns in `scripts/iceberg-init.sql`
4. **Enable dashboard caching**: Configure Redis in docker-compose.yml if needed

## Troubleshooting

### Kafka Connect won't start
1. Ensure connectors are downloaded: `bash scripts/download-connectors.sh`
2. Check logs: `docker-compose logs kafka-connect`

### CDC connector fails
1. Verify PostgreSQL is running: `docker-compose logs postgres`
2. Check PostgreSQL logical replication: `psql -U postgres -c "SHOW wal_level;"`
3. Verify publication exists: `psql -d testdb -c "\dP+"`

### MinIO access issues
1. Ensure MinIO bucket is created: Check MinIO Console at http://localhost:9001
2. Verify S3 credentials in Spark config
3. If the bucket exists but looks empty, run `./setup.sh` or rerun the Spark Iceberg init job above

### Metabase can't connect to PostgreSQL
1. Check network connectivity: `docker-compose exec metabase ping postgres`
2. Verify database exists: `docker-compose exec postgres psql -l`

## Cleanup

Stop and remove all containers:

```bash
docker-compose down
```

Remove volumes (BE CAREFUL - deletes all data):

```bash
docker-compose down -v
```

## Next Steps

1. **Create more complex schemas**: Add dimensions, facts, and slowly changing dimensions
2. **Set up Spark jobs**: Create Spark jobs to transform and enrich Iceberg tables
3. **Advanced analytics**: Use PySpark to create ML models on Iceberg data
4. **Real-time dashboards**: Create Metabase dashboards with real-time data refresh
5. **Data quality monitoring**: Add Great Expectations for data quality checks
6. **Cost optimization**: Configure Iceberg compaction and maintenance tasks
7. **Multi-cloud setup**: Extend to use cloud S3 instead of MinIO

## References

- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [Debezium Documentation](https://debezium.io/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Metabase Documentation](https://www.metabase.com/docs/latest/)
- [MinIO Documentation](https://docs.min.io/)
- [PySpark Documentation](https://spark.apache.org/docs/latest/api/python/)

