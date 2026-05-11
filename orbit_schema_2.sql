CREATE TABLE telemetry_logs (
    log_id SERIAL PRIMARY KEY,
    satellite_id VARCHAR(50),
    latitude DECIMAL(10,4),
    longitude DECIMAL(10,4),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE command_history (
    cmd_id SERIAL PRIMARY KEY,
    raw_command VARCHAR(255),
    encrypted_payload VARCHAR(255),
    status VARCHAR(50),
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE security_audits (
    audit_id SERIAL PRIMARY KEY,
    threat_type VARCHAR(100),
    details TEXT,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);