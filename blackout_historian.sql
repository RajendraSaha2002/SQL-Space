-- Drop tables if they exist for a clean slate
DROP TABLE IF EXISTS incident_reports;
DROP TABLE IF EXISTS grid_telemetry;

-- Table for high-frequency grid telemetry ingestion
CREATE TABLE grid_telemetry (
    telemetry_id SERIAL PRIMARY KEY,
    substation VARCHAR(50),
    voltage DECIMAL(10,2),
    frequency DECIMAL(10,2),
    load_kw DECIMAL(10,2),
    breaker_status VARCHAR(20),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for Forensic Logging
CREATE TABLE incident_reports (
    incident_id SERIAL PRIMARY KEY,
    substation VARCHAR(50),
    attack_type VARCHAR(100),
    action_taken VARCHAR(100),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- INSIDER THREAT PROTECTION: Trigger to prevent deletion of forensic data
CREATE OR REPLACE FUNCTION block_incident_deletion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'SECURITY BREACH: Deletion of forensic incident reports is strictly prohibited!';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Enforce the immutability on the incident_reports table
CREATE TRIGGER enforce_audit_trail
BEFORE DELETE ON incident_reports
FOR EACH ROW EXECUTE FUNCTION block_incident_deletion();