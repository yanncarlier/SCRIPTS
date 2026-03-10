setup_snap_pg.sh
#!/bin/bash

# --- PostgreSQL Snap Setup Script ---
# Use this if you installed Postgres via 'snap install postgresql'

echo "--- 1. Checking Snap Service ---"
if ! snap list postgresql &> /dev/null; then
    echo "PostgreSQL Snap not found. Please install it first."
    exit 1
fi

# Ensure the service is started
sudo snap start postgresql

echo "--- 2. Creating Database & Table (Snap Style) ---"
# Note: Snap uses 'postgresql.psql' instead of just 'psql'
# We use the default 'postgres' superuser bundled in the snap

sudo postgresql.psql -U postgres <<EOF
-- Create the Database
DROP DATABASE IF EXISTS snap_shop;
CREATE DATABASE snap_shop;

-- Connect
\c snap_shop

-- Create Table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT,
    price NUMERIC
);

-- Insert Dummy Data
INSERT INTO products (name, price) VALUES 
('Snap Laptop', 999.99),
('Snap Phone', 499.00),
('Snap Mouse', 25.50);

-- Verify
SELECT * FROM products;
EOF

echo "--- SUCCESS ---"
echo "To enter your DB, run: sudo postgresql.psql -U postgres -d snap_shop"