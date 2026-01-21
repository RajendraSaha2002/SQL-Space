-- Run this in your PostgreSQL Query Tool (pgAdmin)
-- Create Database manually if needed: CREATE DATABASE realestate_db;

-- 1. Listings Table (User Input)
CREATE TABLE IF NOT EXISTS listings (
    id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    location VARCHAR(50) NOT NULL, -- e.g., 'Downtown', 'Suburbs'
    price DOUBLE PRECISION NOT NULL,
    size_sqft INT NOT NULL,
    price_verdict VARCHAR(50) DEFAULT 'Pending' -- 'Fair', 'High', 'Good Deal'
);

-- 2. Market Data (Simulated 'Scraped' Data)
CREATE TABLE IF NOT EXISTS market_data (
    id SERIAL PRIMARY KEY,
    location VARCHAR(50),
    avg_price_per_sqft DOUBLE PRECISION,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed some initial simulated market data
INSERT INTO market_data (location, avg_price_per_sqft) VALUES 
('Downtown', 500.00),
('Suburbs', 250.00),
('Uptown', 400.00),
('Countryside', 150.00);

-- Seed a sample user listing
INSERT INTO listings (title, location, price, size_sqft) VALUES 
('Luxury Apt', 'Downtown', 600000, 1000); 
-- Calculation: 600k / 1000sqft = 600/sqft. Market is 500. This should be 'High Price'.