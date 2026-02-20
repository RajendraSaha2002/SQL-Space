-- 1. CLEANUP
DROP TABLE IF EXISTS sonar_logs CASCADE;
DROP TABLE IF EXISTS fleet_inventory CASCADE;
DROP TABLE IF EXISTS ships CASCADE;

-- 2. FLEET REGISTRY
CREATE TABLE ships (
    ship_id VARCHAR(20) PRIMARY KEY, -- 'INS-VIKRANT'
    class VARCHAR(50), -- 'AIRCRAFT CARRIER'
    status VARCHAR(20) DEFAULT 'GREEN', -- 'GREEN', 'YELLOW', 'RED'
    fuel_level INT, -- Percentage
    ammo_stock INT -- Percentage
);

INSERT INTO ships (ship_id, class, status, fuel_level, ammo_stock) VALUES 
('INS-VIKRANT', 'AIRCRAFT CARRIER', 'GREEN', 85, 90),
('INS-KOLKATA', 'DESTROYER', 'GREEN', 60, 100),
('INS-ARIHANT', 'SUBMARINE', 'GREEN', 40, 50);

-- 3. SONAR THREAT LOGS
CREATE TABLE sonar_logs (
    log_id SERIAL PRIMARY KEY,
    ship_id VARCHAR(20) REFERENCES ships(ship_id),
    detected_freq_hz INT,
    classification VARCHAR(20), -- 'BIOLOGICAL' (Whale) or 'MECHANICAL' (Enemy Sub)
    timestamp TIMESTAMP DEFAULT NOW()
);

-- 4. FLEET INVENTORY (For Java Charts)
CREATE TABLE fleet_inventory (
    item_id SERIAL PRIMARY KEY,
    ship_id VARCHAR(20) REFERENCES ships(ship_id),
    item_name VARCHAR(50), -- 'Torpedo', 'Jet Fuel'
    quantity INT,
    last_restock DATE
);

INSERT INTO fleet_inventory (ship_id, item_name, quantity, last_restock) VALUES
('INS-VIKRANT', 'Jet Fuel (Barrels)', 5000, '2023-10-01'),
('INS-KOLKATA', 'BrahMos Missiles', 16, '2023-09-15');

-- 5. REAL-TIME THREAT NOTIFICATION
CREATE OR REPLACE FUNCTION notify_threat_level()
RETURNS TRIGGER AS $$
BEGIN
    -- If a MECHANICAL threat is detected, update ship status to RED
    IF NEW.classification = 'MECHANICAL' THEN
        UPDATE ships SET status = 'RED' WHERE ship_id = NEW.ship_id;
        
        -- Notify Java App
        PERFORM pg_notify('fleet_alert', NEW.ship_id || ':RED');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sonar_detect
AFTER INSERT ON sonar_logs
FOR EACH ROW
EXECUTE FUNCTION notify_threat_level();