#!/bin/bash
# Superset initialization script

# This script configures Superset with database connections

# Wait for Superset to be ready
sleep 10

# Create a database connection to PostgreSQL
python3 << 'EOF'
from superset.app import create_app
from superset.models.database import Database
from superset.extensions import db

app = create_app()

with app.app_context():
    # Check if database already exists
    existing_db = db.session.query(Database).filter_by(database_name="PostgreSQL").first()

    if not existing_db:
        # Create new database connection
        postgres_db = Database(
            database_name="PostgreSQL",
            sqlalchemy_uri="postgresql://postgres:postgres@postgres:5432/testdb",
            allow_run_async=False,
            expose_in_sqllab=True,
            allow_csv_upload=True,
            is_managed_externally=False
        )
        db.session.add(postgres_db)
        db.session.commit()
        print("PostgreSQL database connection created in Superset")
    else:
        print("PostgreSQL database connection already exists")

EOF

echo "Superset initialization complete!"

