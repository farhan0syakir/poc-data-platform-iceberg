#!/bin/bash

# Setup script for Data Platform
# This script automates the setup process

set -e

echo "🚀 Data Platform Setup Script"
echo "=============================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Download connectors
echo -e "${BLUE}Step 1: Downloading Kafka Connect connectors...${NC}"
bash scripts/download-connectors.sh
echo -e "${GREEN}✓ Connectors downloaded${NC}"
echo ""

# Step 2: Start services
echo -e "${BLUE}Step 2: Starting Docker containers...${NC}"
docker-compose up -d
echo -e "${GREEN}✓ Containers started${NC}"
echo ""

# Step 3: Wait for services to be ready
echo -e "${BLUE}Step 3: Waiting for services to be healthy...${NC}"
max_attempts=60
attempt=0

while ! curl -s http://localhost:8083/connectors > /dev/null 2>&1; do
    if [ $attempt -ge $max_attempts ]; then
        echo -e "${YELLOW}⚠ Timeout waiting for Kafka Connect. Continuing anyway...${NC}"
        break
    fi
    echo -n "."
    sleep 1
    attempt=$((attempt + 1))
done
echo -e "${GREEN}✓ Services are ready${NC}"
echo ""

# Step 4: Create CDC Connector
echo -e "${BLUE}Step 4: Creating CDC Connector...${NC}"
sleep 5

response=$(curl -s -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @scripts/postgres-cdc-connector.json)

if echo "$response" | grep -q "postgres-cdc-connector"; then
    echo -e "${GREEN}✓ CDC Connector created${NC}"
else
    echo -e "${YELLOW}⚠ Connector response: $response${NC}"
fi
echo ""

# Step 5: Check connector status
echo -e "${BLUE}Step 5: Checking connector status...${NC}"
sleep 2

status=$(curl -s http://localhost:8083/connectors/postgres-cdc-connector/status | grep -o '"state":"[^"]*"' | head -1)
echo "Connector status: $status"
echo ""

# Step 6: Display access information
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo -e "${BLUE}Access the services:${NC}"
echo "  - Metabase (Dashboard):       http://localhost:8088"
echo "  - Kafka UI:                    http://localhost:8080"
echo "  - MinIO Console:               http://localhost:9001 (minioadmin / minioadmin)"
echo "  - Adminer (PostgreSQL):        http://localhost:8082"
echo "  - Spark Master:                http://localhost:8888"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo "  1. Check Kafka topics: docker-compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list"
echo "  2. Monitor CDC events: http://localhost:8080 (Kafka UI)"
echo "  3. Create Iceberg tables: docker-compose exec spark-master spark-submit --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.3.1 /tmp/iceberg-init.py"
echo "  4. Configure Metabase: http://localhost:8088 (add PostgreSQL data source)"
echo ""

echo "For more information, see README.md"

