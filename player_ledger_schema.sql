-- Clean slate
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS ip_blacklist CASCADE;
DROP TABLE IF EXISTS players CASCADE;

CREATE TABLE players (
    player_id VARCHAR(50) PRIMARY KEY,
    ip_address VARCHAR(15),
    x_pos DECIMAL(10,2) DEFAULT 0.0,
    y_pos DECIMAL(10,2) DEFAULT 0.0,
    gold INT DEFAULT 100,
    gems INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'ACTIVE' -- ACTIVE, SHADOW_BANNED, BANNED
);

CREATE TABLE ip_blacklist (
    ip_address VARCHAR(15) PRIMARY KEY,
    reason VARCHAR(100),
    banned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    player_id VARCHAR(50),
    action VARCHAR(50),
    details VARCHAR(255),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed some test players
INSERT INTO players (player_id, ip_address, x_pos, y_pos) VALUES 
('Player_Normal', '127.0.0.1', 0, 0),
('Player_Hacker', '10.0.0.99', 0, 0),
('Player_Bot', '192.168.1.50', 0, 0);

-- ANTI-CHEAT TRIGGER: Catch massive unverified currency injections
CREATE OR REPLACE FUNCTION check_economy_hack()
RETURNS TRIGGER AS $$
BEGIN
    -- If gems increase by more than 1000 instantly, flag and Shadow Ban
    IF (NEW.gems - OLD.gems) > 1000 THEN
        INSERT INTO audit_log (player_id, action, details) 
        VALUES (NEW.player_id, 'ECONOMY_HACK_DETECTED', 'Illegal injection of ' || (NEW.gems - OLD.gems) || ' gems');
        
        NEW.status := 'SHADOW_BANNED'; -- Apply Shadow Ban natively at DB level
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_economy_integrity
BEFORE UPDATE ON players
FOR EACH ROW EXECUTE FUNCTION check_economy_hack();