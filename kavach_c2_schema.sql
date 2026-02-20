-- 1. CLEANUP
DROP TABLE IF EXISTS system_integrity_logs CASCADE;
DROP TABLE IF EXISTS mission_ledger CASCADE;
DROP TABLE IF EXISTS connected_nodes CASCADE;

-- 2. COMMAND NODES (The Grid)
CREATE TABLE connected_nodes (
    node_id VARCHAR(20) PRIMARY KEY, -- 'AIR-CMD', 'NAVAL-HQ'
    sector VARCHAR(50),
    status VARCHAR(20) DEFAULT 'SECURE', -- 'SECURE', 'INFECTED'
    last_scan TIMESTAMP DEFAULT NOW()
);

INSERT INTO connected_nodes (node_id, sector) VALUES 
('AIR-CMD-ALPHA', 'NORTHERN_SECTOR'),
('NAVAL-HQ-WEST', 'WESTERN_FLEET'),
('GROUND-CORPS-1', 'BORDER_CONTROL');

-- 3. WORM LEDGER (Write-Once, Read-Many)
-- This table stores critical mission orders.
CREATE TABLE mission_ledger (
    ledger_id BIGSERIAL PRIMARY KEY,
    command_issued_by VARCHAR(100),
    order_details TEXT,
    timestamp TIMESTAMP DEFAULT NOW()
);

-- 4. INTEGRITY LOGS (Malware Scans)
CREATE TABLE system_integrity_logs (
    log_id BIGSERIAL PRIMARY KEY,
    node_id VARCHAR(20) REFERENCES connected_nodes(node_id),
    file_scanned VARCHAR(200),
    threat_detected VARCHAR(100), -- 'RANSOMWARE_SIG', 'TROJAN'
    scan_time TIMESTAMP DEFAULT NOW()
);

-- 5. IMMUTABILITY TRIGGER (The Anti-Ransomware Lock)
-- This prevents ANY modification to historical logs.
CREATE OR REPLACE FUNCTION block_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'SECURITY BLOCK: History cannot be rewritten. WORM Protocol Active.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_immutable_ledger
BEFORE UPDATE OR DELETE ON mission_ledger
FOR EACH ROW
EXECUTE FUNCTION block_modification();

-- 6. INFECTION TRIGGER
-- If a threat is logged, instantly mark the node as INFECTED
CREATE OR REPLACE FUNCTION quarantine_node()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE connected_nodes SET status = 'INFECTED' WHERE node_id = NEW.node_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_virus_alert
AFTER INSERT ON system_integrity_logs
FOR EACH ROW
EXECUTE FUNCTION quarantine_node();