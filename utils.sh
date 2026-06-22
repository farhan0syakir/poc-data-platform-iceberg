#!/bin/bash

# Utility commands for data platform management

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function print_menu() {
    echo ""
    echo -e "${BLUE}Data Platform Utilities${NC}"
    echo "======================="
    echo "1. View service status"
    echo "2. View PostgreSQL tables"
    echo "3. Insert test data"
    echo "4. View Kafka topics"
    echo "5. Monitor CDC connector"
    echo "6. View Kafka messages (customers)"
    echo "7. View Kafka messages (products)"
    echo "8. View Kafka messages (orders)"
    echo "9. Recreate CDC connector"
    echo "10. View all logs"
    echo "11. Stop all services"
    echo "12. Start all services"
    echo "13. Clean up everything"
    echo "0. Exit"
    echo ""
}

function view_status() {
    echo -e "${BLUE}Service Status:${NC}"
    docker-compose ps
}

function view_postgres_tables() {
    echo -e "${BLUE}PostgreSQL Tables:${NC}"
    docker-compose exec -T postgres psql -U postgres -d testdb -c "
    SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema');
    "
}

function view_table_data() {
    table=$1
    echo -e "${BLUE}Data from $table:${NC}"
    docker-compose exec -T postgres psql -U postgres -d testdb -c "SELECT * FROM $table LIMIT 10;"
}

function insert_test_data() {
    echo -e "${BLUE}Inserting test data...${NC}"
    docker-compose exec -T postgres psql -U postgres -d testdb << EOF
    INSERT INTO customers (first_name, last_name, email, phone) VALUES
    ('NewTest', 'User', 'newtest@example.com', '+1-555-0199');

    INSERT INTO products (name, price, category) VALUES
    ('New Product', 149.99, 'NewCategory');

    INSERT INTO orders (customer_id, total_amount, status) VALUES
    (1, 299.99, 'pending');

    SELECT COUNT(*) as customer_count FROM customers;
    SELECT COUNT(*) as product_count FROM products;
    SELECT COUNT(*) as order_count FROM orders;
EOF
    echo -e "${GREEN}✓ Test data inserted${NC}"
}

function view_kafka_topics() {
    echo -e "${BLUE}Kafka Topics:${NC}"
    docker-compose exec -T kafka kafka-topics \
        --bootstrap-server localhost:9092 \
        --list
}

function monitor_connector() {
    echo -e "${BLUE}CDC Connector Status:${NC}"
    curl -s http://localhost:8083/connectors/postgres-cdc-connector/status | jq '.'
}

function view_kafka_messages() {
    topic=$1
    echo -e "${BLUE}Latest messages from topic: $topic${NC}"
    timeout 10 docker-compose exec -T kafka kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic $topic \
        --from-beginning \
        --max-messages 5 2>/dev/null || true
    echo ""
}

function recreate_connector() {
    echo -e "${BLUE}Recreating CDC connector...${NC}"

    # Delete existing connector if it exists
    curl -s -X DELETE http://localhost:8083/connectors/postgres-cdc-connector 2>/dev/null || true

    sleep 2

    # Create new connector
    response=$(curl -s -X POST http://localhost:8083/connectors \
        -H "Content-Type: application/json" \
        -d @scripts/postgres-cdc-connector.json)

    if echo "$response" | grep -q "postgres-cdc-connector"; then
        echo -e "${GREEN}✓ Connector recreated${NC}"
    else
        echo -e "${RED}✗ Failed to create connector: $response${NC}"
    fi
}

function view_all_logs() {
    echo -e "${BLUE}Recent logs from all services:${NC}"
    docker-compose logs --tail 50
}

function stop_services() {
    echo -e "${YELLOW}Stopping all services...${NC}"
    docker-compose down
    echo -e "${GREEN}✓ Services stopped${NC}"
}

function start_services() {
    echo -e "${BLUE}Starting all services...${NC}"
    docker-compose up -d
    echo -e "${GREEN}✓ Services started${NC}"
}

function cleanup() {
    echo -e "${RED}WARNING: This will delete all data!${NC}"
    read -p "Are you sure? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose down -v
        echo -e "${GREEN}✓ Cleanup complete${NC}"
    else
        echo "Cleanup cancelled"
    fi
}

# Main loop
while true; do
    print_menu
    read -p "Enter your choice: " choice

    case $choice in
        1) view_status ;;
        2) view_postgres_tables ;;
        3) insert_test_data ;;
        4) view_kafka_topics ;;
        5) monitor_connector ;;
        6) view_kafka_messages "cdc.customers" ;;
        7) view_kafka_messages "cdc.products" ;;
        8) view_kafka_messages "cdc.orders" ;;
        9) recreate_connector ;;
        10) view_all_logs ;;
        11) stop_services ;;
        12) start_services ;;
        13) cleanup ;;
        0) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done

