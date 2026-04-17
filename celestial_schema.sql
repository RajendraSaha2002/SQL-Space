DROP TABLE IF EXISTS anomaly_hex_archive CASCADE;
DROP TABLE IF EXISTS c2_uplink_ledger CASCADE;
DROP TABLE IF EXISTS celestial_telemetry CASCADE;

-- High-speed telemetry ingestion
CREATE TABLE celestial_telemetry (
    telemetry_id SERIAL PRIMARY KEY,
    sequence_num INT,
    latitude DECIMAL(10,4),
    longitude DECIMAL(10,4),
    altitude_km DECIMAL(10,2),
    battery_pct DECIMAL(5,2),
    signal_rssi INT,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Command Authorization Ledger
CREATE TABLE c2_uplink_ledger (
    cmd_id SERIAL PRIMARY KEY,
    operator_id VARCHAR(50) DEFAULT 'SYS_ADMIN',
    command_raw VARCHAR(255),
    crypto_status VARCHAR(20),
    satellite_response VARCHAR(50),
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Forensics: Stores exact Hex Dumps of corrupted/malicious packets
CREATE TABLE anomaly_hex_archive (
    anomaly_id SERIAL PRIMARY KEY,
    attack_classification VARCHAR(100),
    raw_hex_dump TEXT,
    source_ip VARCHAR(50),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger: Automatically flag dangerous altitude drops (Orbital Decay)
CREATE OR REPLACE FUNCTION check_orbital_decay()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.altitude_km < 300.00 THEN
        INSERT INTO anomaly_hex_archive (attack_classification, raw_hex_dump, source_ip)
        VALUES ('CRITICAL_ORBITAL_DECAY', 'ALTITUDE_DROP_DETECTED: ' || NEW.altitude_km, 'INTERNAL_MONITOR');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_orbital_decay
AFTER INSERT ON celestial_telemetry
FOR EACH ROW EXECUTE FUNCTION check_orbital_decay();