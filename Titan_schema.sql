DROP TABLE IF EXISTS security_logs CASCADE;
DROP TABLE IF EXISTS job_scheduler CASCADE;
DROP TABLE IF EXISTS node_registry CASCADE;

CREATE TABLE node_registry (
    node_id VARCHAR(50) PRIMARY KEY,
    ip_address VARCHAR(50),
    status VARCHAR(20) DEFAULT 'ONLINE'
);

-- Authorized jobs on the supercomputer
CREATE TABLE job_scheduler (
    job_id SERIAL PRIMARY KEY,
    node_id VARCHAR(50) REFERENCES node_registry(node_id),
    username VARCHAR(50),
    is_active BOOLEAN DEFAULT FALSE
);

-- Ledger for Cryptojacking and Thermal Attacks
CREATE TABLE security_logs (
    log_id SERIAL PRIMARY KEY,
    node_id VARCHAR(50),
    threat_type VARCHAR(100),
    cpu_load DECIMAL(5,2),
    temperature DECIMAL(5,2),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed the Supercomputer Nodes
INSERT INTO node_registry (node_id, ip_address) VALUES 
('NODE_01', '10.0.10.1'), 
('NODE_02', '10.0.10.2'), 
('NODE_03', '10.0.10.3'), 
('NODE_04', '10.0.10.4');

-- Authorize a Physics Simulation on NODE_01 only
INSERT INTO job_scheduler (node_id, username, is_active) VALUES 
('NODE_01', 'dr_smith_physics', TRUE);