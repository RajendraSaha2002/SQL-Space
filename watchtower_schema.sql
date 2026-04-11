-- Create the database schema
CREATE TABLE nodes (
    node_id SERIAL PRIMARY KEY,
    camera_name VARCHAR(50),
    ip_address VARCHAR(15),
    mac_address VARCHAR(17),
    status VARCHAR(20) DEFAULT 'Online'
);

CREATE TABLE threat_logs (
    log_id SERIAL PRIMARY KEY,
    node_id INT REFERENCES nodes(node_id),
    threat_type VARCHAR(50),
    severity VARCHAR(20),
    source_ip VARCHAR(15),
    log_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE system_metrics (
    metric_id SERIAL PRIMARY KEY,
    cpu_usage DECIMAL(5,2),
    memory_usage DECIMAL(5,2),
    metric_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Register initial simulated cameras
INSERT INTO nodes (camera_name, ip_address, mac_address) VALUES
('Camera 1 - Front Gate', '192.168.1.101', '00:14:22:01:23:45'),
('Camera 2 - Server Room', '192.168.1.102', '00:14:22:01:23:46');

-- Automated Defense: Trigger function to flag an IP/Node if compromised
CREATE OR REPLACE FUNCTION flag_compromised_node()
RETURNS TRIGGER AS $$
DECLARE
    recent_threats INT;
BEGIN
    -- Check how many threats occurred on this node in the last minute
    SELECT COUNT(*) INTO recent_threats
    FROM threat_logs
    WHERE node_id = NEW.node_id
    AND log_timestamp >= NOW() - INTERVAL '1 minute';

    -- If 5 or more threats, lock down the node
    IF recent_threats >= 5 THEN
        UPDATE nodes SET status = 'Compromised' WHERE node_id = NEW.node_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to the logs table
CREATE TRIGGER check_threat_threshold
AFTER INSERT ON threat_logs
FOR EACH ROW
EXECUTE FUNCTION flag_compromised_node();