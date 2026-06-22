.PHONY: help setup up down logs status clean ps connector test-data

help:
	@echo "Data Platform - Available commands:"
	@echo ""
	@echo "  make setup          - Download connectors and start all services"
	@echo "  make up             - Start all services"
	@echo "  make down           - Stop all services"
	@echo "  make ps             - Show service status"
	@echo "  make logs           - View service logs"
	@echo "  make clean          - Stop services and remove volumes"
	@echo "  make connector      - Create/recreate CDC connector"
	@echo "  make test-data      - Insert test data into PostgreSQL"
	@echo "  make psql           - Connect to PostgreSQL"
	@echo "  make kafka-topics   - List Kafka topics"
	@echo "  make kafka-consume  - Consume CDC messages (usage: make kafka-consume TOPIC=cdc.customers)"
	@echo "  make minio-console  - Open MinIO console (http://localhost:9001)"
	@echo "  make superset       - Open Superset (http://localhost:8088)"
	@echo "  make kafka-ui       - Open Kafka UI (http://localhost:8080)"
	@echo "  make adminer        - Open Adminer (http://localhost:8081)"
	@echo "  make utils          - Run interactive utilities"
	@echo ""

setup:
	@echo "Setting up data platform..."
	@bash scripts/download-connectors.sh
	@docker-compose up -d
	@echo "Waiting for services..."
	@sleep 10
	@echo "Creating CDC connector..."
	@curl -s -X POST http://localhost:8083/connectors \
		-H "Content-Type: application/json" \
		-d @scripts/postgres-cdc-connector.json > /dev/null
	@echo "✓ Setup complete!"
	@echo ""
	@echo "Access the services:"
	@echo "  - Superset: http://localhost:8088 (admin/admin)"
	@echo "  - Kafka UI: http://localhost:8080"
	@echo "  - MinIO: http://localhost:9001 (minioadmin/minioadmin)"

up:
	docker-compose up -d
	@echo "✓ Services started"

down:
	docker-compose down
	@echo "✓ Services stopped"

ps:
	docker-compose ps

logs:
	docker-compose logs -f

clean:
	docker-compose down -v
	@echo "✓ Everything cleaned up"

connector:
	@echo "Recreating CDC connector..."
	@curl -s -X DELETE http://localhost:8083/connectors/postgres-cdc-connector 2>/dev/null || true
	@sleep 2
	@curl -s -X POST http://localhost:8083/connectors \
		-H "Content-Type: application/json" \
		-d @scripts/postgres-cdc-connector.json > /dev/null
	@echo "✓ Connector recreated"

test-data:
	@echo "Inserting test data..."
	docker-compose exec -T postgres psql -U postgres -d testdb << EOF
		INSERT INTO customers (first_name, last_name, email, phone) VALUES
		('Test', 'User', 'test@example.com', '+1-555-0199');
		INSERT INTO products (name, price, category) VALUES
		('Test Product', 149.99, 'Test');
		INSERT INTO orders (customer_id, total_amount, status) VALUES
		(1, 299.99, 'pending');
		SELECT COUNT(*) FROM customers;
		SELECT COUNT(*) FROM products;
		SELECT COUNT(*) FROM orders;
EOF
	@echo "✓ Test data inserted"

psql:
	docker-compose exec postgres psql -U postgres -d testdb

kafka-topics:
	docker-compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list

kafka-consume:
	docker-compose exec kafka kafka-console-consumer \
		--bootstrap-server localhost:9092 \
		--topic $(TOPIC) \
		--from-beginning

minio-console:
	@echo "Opening MinIO Console..."
	@open http://localhost:9001

superset:
	@echo "Opening Superset..."
	@open http://localhost:8088

kafka-ui:
	@echo "Opening Kafka UI..."
	@open http://localhost:8080

adminer:
	@echo "Opening Adminer..."
	@open http://localhost:8081

utils:
	@bash utils.sh

.DEFAULT_GOAL := help

