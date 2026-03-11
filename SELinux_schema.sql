DROP TABLE IF EXISTS selinux_audit_logs;
DROP TABLE IF EXISTS system_status;

-- Table to store SELinux Configuration State
CREATE TABLE system_status (
    id SERIAL PRIMARY KEY,
    mode VARCHAR(50) NOT NULL, -- enforcing, permissive, disabled
    policy_type VARCHAR(50) NOT NULL, -- targeted, mls
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table to store Access Vector Cache (AVC) Denials and Grants
CREATE TABLE selinux_audit_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    action VARCHAR(20) NOT NULL, -- denied, granted
    scontext VARCHAR(255) NOT NULL, -- Source context (subject)
    tcontext VARCHAR(255) NOT NULL, -- Target context (object)
    tclass VARCHAR(50) NOT NULL, -- file, process, tcp_socket
    details TEXT
);

-- Insert initial NSA-grade system state
INSERT INTO system_status (mode, policy_type) VALUES ('ENFORCING', 'mls (Multi-Level Security)');

-- Insert a few initial logs
INSERT INTO selinux_audit_logs (action, scontext, tcontext, tclass, details) VALUES
('denied', 'unconfined_u:unconfined_r:httpd_t:s0', 'system_u:object_r:shadow_t:s0', 'file', 'read access prevented'),
('granted', 'system_u:system_r:sshd_t:s0', 'system_u:object_r:sshd_key_t:s0', 'file', 'read access permitted');