
-- Create sample database and tables for CDC testing
CREATE DATABASE testdb;

\c testdb

-- Create products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create customers table
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(12, 2),
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create publication for CDC
CREATE PUBLICATION cdc_publication FOR TABLE products, customers, orders;

-- Insert sample data
INSERT INTO customers (first_name, last_name, email, phone) VALUES
('John', 'Doe', 'john@example.com', '+1-555-0101'),
('Jane', 'Smith', 'jane@example.com', '+1-555-0102'),
('Bob', 'Johnson', 'bob@example.com', '+1-555-0103'),
('Alice', 'Williams', 'alice@example.com', '+1-555-0104');

INSERT INTO products (name, price, category) VALUES
('Laptop', 999.99, 'Electronics'),
('Mouse', 29.99, 'Electronics'),
('Keyboard', 79.99, 'Electronics'),
('Monitor', 299.99, 'Electronics'),
('Desk Chair', 199.99, 'Furniture'),
('Standing Desk', 449.99, 'Furniture');

INSERT INTO orders (customer_id, order_date, total_amount, status) VALUES
(1, NOW() - INTERVAL '10 days', 1329.97, 'delivered'),
(2, NOW() - INTERVAL '7 days', 299.99, 'delivered'),
(3, NOW() - INTERVAL '3 days', 649.98, 'shipped'),
(4, NOW() - INTERVAL '1 day', 109.98, 'processing'),
(1, NOW(), 79.99, 'pending');

-- Grant permissions
GRANT CONNECT ON DATABASE testdb TO postgres;
GRANT USAGE ON SCHEMA public TO postgres;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres;

