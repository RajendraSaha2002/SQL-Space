-- Clean up previous runs
DROP TABLE IF EXISTS forensic_logs CASCADE;
DROP TABLE IF EXISTS authorized_mission_plan CASCADE;
DROP TABLE IF EXISTS telemetry_logs CASCADE;

-- 1. Telemetry Partitioning (High-speed insertion, partitioned by Orbit Number)
CREATE TABLE telemetry_logs (
    log_id SERIAL,
    orbit_num INT,
    voltage DECIMAL(5,2),
    temperature DECIMAL(5,2),
    sun_exposure DECIMAL(5,2),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) PARTITION BY RANGE (orbit_num);

-- Create the partition for the first 100 orbits
CREATE TABLE telemetry_logs_orbit_1 PARTITION OF telemetry_logs FOR VALUES FROM (1) TO (100);

-- 2. Command Authorization Ledger
CREATE TABLE authorized_mission_plan (
    cmd_id SERIAL PRIMARY KEY,
    command_name VARCHAR(50) UNIQUE,
    authorized_by VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE
);

-- 3. Forensics Table for Rejected/Spoofed Packets
CREATE TABLE forensic_logs (
    incident_id SERIAL PRIMARY KEY,
    packet_data TEXT,
    rejection_reason VARCHAR(100),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed the Authorized Mission Plan
INSERT INTO authorized_mission_plan (command_name, authorized_by) VALUES 
('ROTATE_ANTENNA', 'FLIGHT_DIRECTOR_01'),
('FIRE_THRUSTERS', 'FLIGHT_DIRECTOR_01');
-- Note: 'DE-ORBIT' is NOT in this table, making it an unauthorized phantom command.