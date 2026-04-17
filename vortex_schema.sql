DROP TABLE IF EXISTS stolen_artifacts CASCADE;
DROP TABLE IF EXISTS compromise_ledger CASCADE;
DROP TABLE IF EXISTS extension_blacklist CASCADE;

CREATE TABLE compromise_ledger (
    event_id SERIAL PRIMARY KEY,
    file_modified VARCHAR(255),
    risk_score INT,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stolen_artifacts (
    artifact_id SERIAL PRIMARY KEY,
    file_source VARCHAR(255),
    payload TEXT,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE extension_blacklist (
    extension_id VARCHAR(100) PRIMARY KEY,
    threat_level VARCHAR(50),
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed the Blacklist with known malicious VS Code extensions
INSERT INTO extension_blacklist (extension_id, threat_level) VALUES 
('malicious.python.formatter', 'CRITICAL'),
('fake.prettier.vscode', 'HIGH'),
('evil.env.loader', 'CRITICAL');