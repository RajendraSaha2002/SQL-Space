-- Run in PostgreSQL (pgAdmin or psql)
-- Create Database: CREATE DATABASE chat_db;

CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    user_name VARCHAR(50) NOT NULL,
    message_text TEXT NOT NULL,
    sentiment_score DOUBLE PRECISION,     -- -1.0 to 1.0
    sentiment_icon VARCHAR(10),           -- 😃, 😐, 😢
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed Data
INSERT INTO messages (user_name, message_text) VALUES 
('Alice', 'I love this new feature! It is amazing.'),
('Bob', 'I am very angry about the delay.'),
('Charlie', 'The meeting is at 5 PM.');