CREATE DATABASE logindb;
USE logindb;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    email VARCHAR(100) UNIQUE,
    password VARCHAR(100)
);

INSERT INTO users (name, email, password) VALUES
('Raj', 'raj@example.com', '1234'),
('Neha', 'neha@example.com', 'abcd');

SELECT * FROM users;
