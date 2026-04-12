-- Create the Historian Database Schema
CREATE TABLE node_telemetry (
    telemetry_id SERIAL PRIMARY KEY,
    node_id INT,
    voltage DECIMAL(10,2),
    frequency DECIMAL(10,2),
    load_kw DECIMAL(10,2),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE incident_logs (
    log_id SERIAL PRIMARY KEY,
    node_id INT,
    threat_vector VARCHAR(100),
    severity VARCHAR(50),
    response_taken VARCHAR(100),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- STRICT FORENSIC AUDITING: Prevent any modifications to the incident logs
CREATE OR REPLACE FUNCTION prevent_tampering()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'SECURITY ALERT: Unauthorized attempt to tamper with immutable incident logs!';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Attach triggers to block UPDATE and DELETE simulating an immutable ledger
CREATE TRIGGER enforce_immutability_update
BEFORE UPDATE ON incident_logs
FOR EACH ROW EXECUTE FUNCTION prevent_tampering();

CREATE TRIGGER enforce_immutability_delete
BEFORE DELETE ON incident_logs
FOR EACH ROW EXECUTE FUNCTION prevent_tampering();

-- Insert baseline configuration
INSERT INTO incident_logs (node_id, threat_vector, severity, response_taken) 
VALUES (0, 'System Initialization', 'INFO', 'Grid monitoring active');