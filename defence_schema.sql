-- 1. CLEANUP: Drop old tables to avoid any column errors
DROP TABLE IF EXISTS logs CASCADE;
DROP TABLE IF EXISTS units CASCADE;
DROP TABLE IF EXISTS missions CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 2. CREATE TABLES
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(50) NOT NULL,
    clearance_level INT NOT NULL
);

CREATE TABLE missions (
    id SERIAL PRIMARY KEY,
    mission_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    location VARCHAR(100) NOT NULL
);

CREATE TABLE units (
    id SERIAL PRIMARY KEY,
    unit_name VARCHAR(100) NOT NULL,
    deployment_status VARCHAR(50) NOT NULL,
    personnel_count INT NOT NULL
);

CREATE TABLE logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    message TEXT NOT NULL
);

-- 3. INSERT SAMPLE DATA
-- Admin Login Credentials
INSERT INTO users (username, password, clearance_level) VALUES ('commander', 'alpha123', 5);

-- Dummy Missions
INSERT INTO missions (mission_name, status, location) VALUES 
('Operation Blackout', 'Active', 'Sector 7G'),
('Eagle Eye', 'Pending', 'Northern Border'),
('Iron Shield', 'Completed', 'Western Coast');

-- Dummy Units
INSERT INTO units (unit_name, deployment_status, personnel_count) VALUES 
('Alpha Squad', 'Deployed', 120),
('Bravo Team', 'Standby', 85),
('Ghost Recon', 'Deployed', 12);

-- Initial Log Entry
INSERT INTO logs (message) VALUES ('System initialized. Command panel database reset and online.');