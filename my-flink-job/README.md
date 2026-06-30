# My Flink Job — Kafka → Flink Streaming Demo

A minimal proof-of-concept that streams messages from **Apache Kafka** into an **Apache Flink** job running on a local cluster. Everything runs locally via **Docker Compose**, including a **Kafka UI** for inspecting topics and messages.

## Architecture

```
┌──────────────┐      input-topic      ┌─────────────────┐
│ Kafka        │ ────────────────────► │ Flink           │
│ (KRaft mode) │                       │ JobManager +    │
│              │                       │ TaskManager     │
└──────┬───────┘                       └─────────────────┘
       │
       ▼
┌──────────────┐
│ Kafka UI     │  (browse topics / produce messages)
└──────────────┘
```

The Flink job ([`DataStreamJob.java`](src/main/java/com/example/DataStreamJob.java)):
- Consumes `String` messages from the Kafka topic **`input-topic`**
- Prints each message to the TaskManager standard output (`stream.print()`)

## Services & Ports

| Service          | Description                       | URL / Port              |
|------------------|-----------------------------------|-------------------------|
| Flink Dashboard  | Submit & monitor jobs             | http://localhost:8081   |
| Kafka UI         | Browse topics / produce messages  | http://localhost:8080   |
| Kafka (internal) | Used by Flink & Kafka UI          | `kafka:9092`            |
| Kafka (external) | Used from your host machine       | `localhost:9093`        |

## Prerequisites

- **Docker** & **Docker Compose**
- **JDK 17** and **Maven** (only needed to build the job JAR)

---

## Step-by-Step Guide

### 1. Start the infrastructure

Spin up Flink, Kafka, and Kafka UI:

```bash
docker compose up -d
```

Verify all containers are running:

```bash
docker compose ps
```

You should see `jobmanager`, `taskmanager`, `kafka`, and `kafka-ui` all `Up`.

### 2. Build the Flink job JAR

The `target/` directory is mounted into the JobManager container at `/opt/flink/usrlib`, so building locally makes the JAR available inside the cluster.

```bash
mvn clean package
```

This produces `target/my-flink-job-1.0-SNAPSHOT.jar` (a shaded/fat JAR with the Kafka connector bundled).

> If you have multiple JDKs installed, build with Java 17:
> ```bash
> JAVA_HOME=$(/usr/libexec/java_home -v 17) mvn clean package
> ```

### 3. Create the Kafka topic

The job reads from `input-topic`. Create it once:

```bash
docker exec -it my-flink-job-kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic input-topic \
  --partitions 1 --replication-factor 1 --if-not-exists
```

> You can also create it from the Kafka UI at http://localhost:8080.

### 4. Submit the Flink job

```bash
docker exec -it my-flink-job-jobmanager-1 \
  flink run -d /opt/flink/usrlib/my-flink-job-1.0-SNAPSHOT.jar
```

Confirm it's running:

```bash
docker exec -it my-flink-job-jobmanager-1 flink list
```

You should see: `Flink Kafka Stream Job (RUNNING)`. You can also view it in the Flink Dashboard at http://localhost:8081.

### 5. Produce test messages

Send some messages to the topic:

```bash
docker exec -it my-flink-job-kafka-1 /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic input-topic
```

Type a few lines and press **Enter** after each:

```
hello-flink
test-message-1
```

Press `Ctrl+C` to exit the producer. *(You can also produce messages from the Kafka UI.)*

### 6. View the output

The job prints each consumed message to the TaskManager logs:

```bash
docker logs -f my-flink-job-taskmanager-1
```

You should see your messages appear:

```
hello-flink
test-message-1
```

---

## Useful Commands

**Stop the job:**
```bash
docker exec -it my-flink-job-jobmanager-1 flink list          # get the JobID
docker exec -it my-flink-job-jobmanager-1 flink cancel <JobID>
```

**Tear everything down:**
```bash
docker compose down
```

**Rebuild and redeploy after code changes:**
```bash
mvn clean package
docker exec -it my-flink-job-jobmanager-1 \
  flink run -d /opt/flink/usrlib/my-flink-job-1.0-SNAPSHOT.jar
```

---

## Troubleshooting

| Problem | Cause / Fix |
|---------|-------------|
| `JAR file does not exist` | Run `mvn clean package` first; the JAR is served from the mounted `./target` directory at `/opt/flink/usrlib`. |
| `UnknownTopicOrPartitionException` | The `input-topic` doesn't exist yet — create it (Step 3). |
| `WARNING: Unknown module: jdk.compiler` | Harmless Flink 1.19 startup noise; safe to ignore. |
| No output in logs | Make sure the job is `RUNNING` and you produced messages **after** it started (or rely on `earliest` offset). |

