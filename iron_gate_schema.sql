-- 1. CLEANUP
DROP TABLE IF EXISTS access_logs CASCADE;
DROP TABLE IF EXISTS secure_documents CASCADE;
DROP TABLE IF EXISTS comm_channels CASCADE;

-- 2. SECURE CHANNELS (The Grid Nodes)
CREATE TABLE comm_channels (
    channel_id SERIAL PRIMARY KEY,
    name VARCHAR(50), -- 'NORTHERN-CMD', 'STRATEGIC-FORCES', 'PMO-DIRECT'
    status VARCHAR(20) DEFAULT 'SECURE', -- 'SECURE', 'COMPROMISED', 'OFFLINE'
    signal_strength INT DEFAULT 100 -- 0 to 100
);

INSERT INTO comm_channels (name, signal_strength) VALUES 
('NORTHERN-CMD', 95), 
('STRATEGIC-FORCES', 88), 
('PMO-DIRECT', 100),
('CYBER-WARFARE-DIV', 75);

-- 3. ENCRYPTED VAULT (Documents stored as BLOBs)
CREATE TABLE secure_documents (
    doc_id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200),
    sender VARCHAR(50), -- 'CDS', 'PMO', 'NSA'
    encrypted_blob BYTEA, -- AES-256 Encrypted Binary
    iv BYTEA, -- Initialization Vector (Required for decryption)
    checksum VARCHAR(64), -- SHA-256 Integrity Check
    uploaded_at TIMESTAMP DEFAULT NOW()
);

-- 4. FORENSIC AUDIT TRAIL (Write-Once, Read-Many)
CREATE TABLE access_logs (
    log_id BIGSERIAL,
    user_identity VARCHAR(100),
    action_type VARCHAR(50), -- 'LOGIN', 'DECRYPT_ATTEMPT', 'UPLOAD'
    ip_address INET,
    status VARCHAR(20), -- 'SUCCESS', 'DENIED'
    timestamp TIMESTAMP DEFAULT NOW()
);

-- 5. BRIN INDEX (For Massive Data Speed)
-- BRIN is 100x smaller than B-Tree for time-series logs
CREATE INDEX idx_audit_brin ON access_logs USING BRIN(timestamp);

-- 6. SECURITY TRIGGER (Alert on Compromise)
CREATE OR REPLACE FUNCTION notify_security_breach()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'COMPROMISED' THEN
        PERFORM pg_notify('security_alert', 'BREACH DETECTED IN CHANNEL: ' || NEW.name);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_breach_alert
AFTER UPDATE ON comm_channels
FOR EACH ROW
EXECUTE FUNCTION notify_security_breach();