

DROP TABLE IF EXISTS units;
DROP TABLE IF EXISTS jammers;

-- 1. Combat Units (Blue Force)
CREATE TABLE units (
    id SERIAL PRIMARY KEY,
    callsign VARCHAR(20),
    x INT,
    y INT,
    frequency_mhz DECIMAL(5,1) DEFAULT 150.0, -- The frequency they are communicating on
    tx_power INT DEFAULT 50 -- Transmission strength
);

-- 2. Electronic Warfare Assets (Red Force)
CREATE TABLE jammers (
    id SERIAL PRIMARY KEY,
    callsign VARCHAR(20),
    x INT,
    y INT,
    target_freq_mhz DECIMAL(5,1) DEFAULT 0.0, -- The frequency they are attacking
    jamming_power INT DEFAULT 5000 -- High power noise
);

-- 3. Seed Data
-- Blue Force scattered on the map
INSERT INTO units (callsign, x, y, frequency_mhz) VALUES 
('Alpha-1', 200, 300, 145.0),
('Alpha-2', 250, 350, 145.0), -- Communicating with A-1
('Bravo-1', 600, 200, 160.0),
('Bravo-2', 650, 220, 160.0);

-- Red Force Jammer (Initially inactive/wrong freq)
INSERT INTO jammers (callsign, x, y, target_freq_mhz) VALUES 
('Jammer-X', 400, 300, 0.0);