#!/bin/bash

# Download Debezium PostgreSQL connector
mkdir -p /Users/farhan/IdeaProjects/github/farhan0syakir/poc-data-platform-iceberg/connectors

# Download Debezium PostgreSQL connector JAR
echo "Downloading Debezium PostgreSQL connector..."
curl -L https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/2.3.0.Final/debezium-connector-postgres-2.3.0.Final-plugin.tar.gz -o /tmp/debezium-postgres.tar.gz

if [ -f /tmp/debezium-postgres.tar.gz ]; then
    tar -xzf /tmp/debezium-postgres.tar.gz -C /Users/farhan/IdeaProjects/github/farhan0syakir/poc-data-platform-iceberg/connectors/
    rm /tmp/debezium-postgres.tar.gz
    echo "Debezium PostgreSQL connector installed successfully"
else
    echo "Warning: Failed to download Debezium connector. Please install manually."
fi

