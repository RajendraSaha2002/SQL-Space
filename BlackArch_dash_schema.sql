CREATE TABLE IF NOT EXISTS security_alerts (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(50),
    alert_type VARCHAR(100),
    severity VARCHAR(20)
);

INSERT INTO security_alerts (ip_address, alert_type, severity) VALUES
('192.168.1.105', 'Port Scan Detected', 'High'),
('10.0.0.42', 'Failed SSH Login', 'Medium'),
('172.16.0.8', 'Malware Signature Match', 'Critical'),
('192.168.1.22', 'Unauthorized Access Attempt', 'High');