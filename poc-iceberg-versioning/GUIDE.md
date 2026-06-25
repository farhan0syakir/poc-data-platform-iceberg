# Apache Iceberg Versioning Guide

This project demonstrates the versioning capabilities of Apache Iceberg, including snapshots, time travel, and Git-like branching/tagging using Nessie.

## Architecture
- **Storage**: MinIO (S3-compatible)
- **Catalog**: Project Nessie (provides branching/tagging)
- **Compute**: Apache Spark (Spark SQL & PySpark)

## Getting Started

1. **Start the environment**:
   ```bash
   docker-compose up -d
   ```

2. **Access Spark SQL Shell**:
   ```bash
   docker exec -it spark-iceberg spark-sql
   ```

3. **Access Jupyter Notebook**:
   Open [http://localhost:8888](http://localhost:8888) in your browser.

---

## 1. Native Iceberg Versioning (Snapshots & Time Travel)

Iceberg automatically creates a **snapshot** for every write operation.

### Create a table and insert data
```sql
USE nessie;

CREATE TABLE dev.users (id bigint, name string, city string) USING iceberg;

INSERT INTO dev.users VALUES (1, 'Alice', 'New York');
INSERT INTO dev.users VALUES (2, 'Bob', 'London');
```

### View Snapshots
You can inspect the table history and snapshots using metadata tables:
```sql
SELECT * FROM dev.users.history;
SELECT * FROM dev.users.snapshots;
```

### Time Travel
Update data to create a new snapshot:
```sql
UPDATE dev.users SET city = 'Paris' WHERE id = 1;

-- Current state
SELECT * FROM dev.users;
```

Now, query a previous snapshot (replace `[snapshot_id]` with an ID from `users.snapshots`):
```sql
-- Using Snapshot ID
SELECT * FROM dev.users VERSION AS OF [snapshot_id];

-- Using Timestamp
SELECT * FROM dev.users TIMESTAMP AS OF '2023-10-01 10:00:00'; -- Use a relevant timestamp
```

---

## 2. Advanced Versioning with Nessie (Branching & Tagging)

Nessie allows you to branch the entire catalog, similar to Git.

### Create a Branch
By default, you are on the `main` branch. Create a new branch for experimentation:
```sql
CREATE BRANCH experimental_feature IN nessie;

-- Switch to the branch in Spark
USE REFERENCE experimental_feature IN nessie;
```

### Work on the Branch
```sql
INSERT INTO dev.users VALUES (3, 'Charlie', 'Tokyo');

-- Verify data on the branch
SELECT * FROM dev.users; -- Should see 3 rows
```

### Compare with Main
Switch back to `main`:
```sql
USE REFERENCE main IN nessie;

-- Verify data on main
SELECT * FROM dev.users; -- Should see only 2 rows
```

### Merge Branch
```sql
MERGE BRANCH experimental_feature INTO main IN nessie;

-- Now main has the data
SELECT * FROM dev.users;
```

### Tagging
Create a fixed point in time:
```sql
CREATE TAG release_v1 IN nessie;
```

---

## 3. Maintenance

### Expiring Old Snapshots
To save space, you can expire old snapshots:
```sql
CALL nessie.system.expire_snapshots('dev.users', current_timestamp(), 1);
```

### Compaction
Optimize table layout:
```sql
CALL nessie.system.rewrite_data_files('dev.users');
```

