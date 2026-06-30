# My Flink Job — Kafka ⇄ Flink Streaming Demo

A minimal proof-of-concept built as a **multi-module Gradle** project with two Flink jobs:

| Module   | Job class                       | Role                                                                  |
|----------|---------------------------------|-----------------------------------------------------------------------|
| `stream` | `com.example.DataGeneratorJob`  | **Consumes** from `landing` and **produces** to `target`.             |
| `sink`   | `com.example.DataStreamJob`     | **Consumes** from `target` and prints them (the sink).                |

Everything runs locally via **Docker Compose**, including a **Kafka UI** for inspecting topics and messages.

## Architecture

```
┌──────────────┐    landing     ┌──────────────┐    target     ┌──────────────┐    target     ┌──────────────┐
│ producer     │ ─────────────► │ Flink:       │ ────────────► │ Kafka        │ ────────────► │ Flink:       │
│ (Kafka UI /  │                │ stream       │               │ (KRaft mode) │               │ sink         │
│  console)    │                │ (landing →   │               │              │               │ (print)      │
│              │                │  target)     │               │              │               │              │
└──────────────┘                └──────────────┘               └──────┬───────┘               └──────────────┘
                                                                       │
                                                                       ▼
                                                                ┌──────────────┐
                                                                │ Kafka UI     │
                                                                └──────────────┘
```

## Project layout

```
my-flink-job/
├── settings.gradle          # includes the sink & stream modules
├── build.gradle             # shared config (Java 17, deps, shadow fat-jar)
├── gradlew / gradlew.bat    # Gradle wrapper (Gradle 8.10.2)
├── docker-compose.yml
├── sink/
│   ├── build.gradle         # Main-Class: com.example.DataStreamJob
│   └── src/main/java/com/example/DataStreamJob.java
└── stream/
    ├── build.gradle         # Main-Class: com.example.DataGeneratorJob
    └── src/main/java/com/example/DataGeneratorJob.java
```

## Services & Ports

| Service          | Description                       | URL / Port              |
|------------------|-----------------------------------|-------------------------|
| Flink Dashboard  | Submit & monitor jobs             | http://localhost:8081   |
| Kafka UI         | Browse topics / produce messages  | http://localhost:8080   |
| Kafka (internal) | Used by Flink & Kafka UI          | `kafka:9092`            |
| Kafka (external) | Used from your host machine       | `localhost:9093`        |

## Prerequisites

- **Docker** & **Docker Compose**
- **JDK 17** (the Gradle wrapper is bundled — no local Gradle install needed)

---

## Step-by-Step Guide

### 1. Start the infrastructure

```bash
docker compose up -d
```

Verify all containers are running:

```bash
docker compose ps
```

You should see `jobmanager`, `taskmanager`, `kafka`, and `kafka-ui` all `Up`.

### 2. Build the Flink job JARs

Each module's `build/libs` directory is mounted into the JobManager container under
`/opt/flink/usrlib/<module>`, so building locally makes the JARs available inside the cluster.

```bash
./gradlew clean build
```

This produces the shaded/fat JARs (Kafka connector bundled):

- `sink/build/libs/sink-1.0-SNAPSHOT.jar`
- `stream/build/libs/stream-1.0-SNAPSHOT.jar`

> If you have multiple JDKs installed, build with Java 17:
> ```bash
> JAVA_HOME=$(/usr/libexec/java_home -v 17) ./gradlew clean build
> ```
>
> Build a single module with e.g. `./gradlew :sink:build` or `./gradlew :stream:build`.

### 3. Create the Kafka topics

The pipeline uses two topics: `landing` (stream input) and `target` (stream output / sink input). Create them once:

```bash
docker exec -it my-flink-job-kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic landing \
  --partitions 1 --replication-factor 1 --if-not-exists

docker exec -it my-flink-job-kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic target \
  --partitions 1 --replication-factor 1 --if-not-exists
```

> You can also create them from the Kafka UI at http://localhost:8080.

### 4. Submit the Flink jobs

Submit the **sink** (consumer) job:

```bash
docker exec -it my-flink-job-jobmanager-1 \
  flink run -d /opt/flink/usrlib/sink/sink-1.0-SNAPSHOT.jar
```

Submit the **stream** (generator) job:

```bash
docker exec -it my-flink-job-jobmanager-1 \
  flink run -d /opt/flink/usrlib/stream/stream-1.0-SNAPSHOT.jar
```

Confirm they're running:

```bash
docker exec -it my-flink-job-jobmanager-1 flink list
```

You should see `Flink Kafka Stream Job` and `Flink Kafka Landing To Target Job` as `RUNNING`.
You can also view them in the Flink Dashboard at http://localhost:8081.

### 5. Produce test messages into `landing`

The `stream` job consumes from `landing` and forwards to `target`. Send some messages to kick off the pipeline:

```bash
docker exec -it my-flink-job-kafka-1 /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic landing
```

Type a few lines (e.g. `message-0`, `message-1`) and press Enter for each.
You can also produce messages from the Kafka UI at http://localhost:8080.

### 6. View the output

The sink job prints each consumed message from `target` to the TaskManager logs:

```bash
docker logs -f my-flink-job-taskmanager-1
```

You should see the messages you produced into `landing` appear:

```
message-0
message-1
message-2
```

---

## Useful Commands

**List / stop jobs:**
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
./gradlew clean build
docker exec -it my-flink-job-jobmanager-1 \
  flink run -d /opt/flink/usrlib/sink/sink-1.0-SNAPSHOT.jar
docker exec -it my-flink-job-jobmanager-1 \
  flink run -d /opt/flink/usrlib/stream/stream-1.0-SNAPSHOT.jar
```

---

## Troubleshooting

| Problem | Cause / Fix |
|---------|-------------|
| `JAR file does not exist` | Run `./gradlew clean build` first; the JARs are served from the mounted `./sink/build/libs` and `./stream/build/libs` directories under `/opt/flink/usrlib`. |
| `UnknownTopicOrPartitionException` | The `landing` / `target` topics don't exist yet — create them (Step 3). |
| `WARNING: Unknown module: jdk.compiler` | Harmless Flink 1.19 startup noise; safe to ignore. |
| No output in logs | Make sure both jobs are `RUNNING` and the topic exists. |
