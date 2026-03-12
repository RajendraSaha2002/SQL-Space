DROP TABLE IF EXISTS telemetry_logs;
DROP TABLE IF EXISTS ground_stations;

-- 1. Authorized Ground Stations
CREATE TABLE ground_stations (
    id SERIAL PRIMARY KEY,
    station_code VARCHAR(50) UNIQUE NOT NULL,
    clearance_level INT NOT NULL, -- 1=Top Secret, 2=Secret, 3=Confidential
    location_lat DECIMAL(9,6),
    location_lon DECIMAL(9,6),
    encryption_key VARCHAR(100) NOT NULL
);

-- 2. Encrypted Satellite Payloads
CREATE TABLE telemetry_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    satellite_id VARCHAR(50),
    encrypted_payload TEXT NOT NULL, -- The SHA-256 hashed data
    hash_signature VARCHAR(64) NOT NULL, -- Integrity check
    origin_sector VARCHAR(20)
);

-- Seed Data: Stations
INSERT INTO ground_stations (station_code, clearance_level, location_lat, location_lon, encryption_key) VALUES
('NORAD_CHEYENNE', 1, 38.742, -104.845, 'ALPHA-ZULU-99'),
('PINE_GAP_AUS', 1, -23.700, 133.870, 'KILO-MIKE-88'),
('RAF_FYLINGDALES', 2, 54.359, -0.668, 'SIERRA-TANGO-77');