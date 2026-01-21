-- Run this in your PostgreSQL Query Tool

-- 1. Create Database (Optional)
-- CREATE DATABASE banking_db;

-- 2. Create Accounts Table
CREATE TABLE IF NOT EXISTS accounts (
    account_id SERIAL PRIMARY KEY,
    user_name VARCHAR(100) NOT NULL,
    balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    -- Database-level constraint: Balance can never be negative
    CONSTRAINT balance_non_negative CHECK (balance >= 0)
);

-- 3. Create Transaction Logs
CREATE TABLE IF NOT EXISTS transaction_logs (
    id SERIAL PRIMARY KEY,
    from_account_id INT,
    to_account_id INT,
    amount DECIMAL(10, 2),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) -- 'SUCCESS' or 'FAILED'
);

-- 4. Seed Data (Initial Money)
INSERT INTO accounts (user_name, balance) VALUES 
('Alice', 1000.00),
('Bob', 500.00),
('Charlie', 0.00);