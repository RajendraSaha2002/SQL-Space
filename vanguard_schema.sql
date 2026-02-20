-- 1. CLEANUP
DROP TABLE IF EXISTS asset_pings CASCADE;
DROP TABLE IF EXISTS secure_messages CASCADE;
DROP TABLE IF EXISTS assets CASCADE;

-- 2. ASSET REGISTRY
CREATE TABLE assets (
    asset_id SERIAL PRIMARY KEY,
    callsign VARCHAR(20) UNIQUE NOT NULL,
    type VARCHAR(20), -- 'FIGHTER', 'DESTROYER', 'TANK'
    service_branch VARCHAR(20), -- 'AIR_FORCE', 'NAVY', 'ARMY'
    status VARCHAR(20) DEFAULT 'ACTIVE'
);

INSERT INTO assets (callsign, type, service_branch) VALUES 
('VIPER-1', 'FIGHTER', 'AIR_FORCE'),
('VIPER-2', 'FIGHTER', 'AIR_FORCE'),
('IRONCLAD-X', 'DESTROYER', 'NAVY'),
('THUNDER-A', 'TANK', 'ARMY');

-- 3. SECURE COMMS (Encrypted Link Simulation)
CREATE TABLE secure_messages (
    msg_id BIGSERIAL PRIMARY KEY,
    sender VARCHAR(50),
    encrypted_payload TEXT, -- Simulation of encrypted hex
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. PARTITIONED TRACKING DATA (Big Data handling)
CREATE TABLE asset_pings (
    ping_id BIGSERIAL,
    asset_id INT REFERENCES assets(asset_id),
    latitude DECIMAL(9, 6),
    longitude DECIMAL(9, 6),
    heading DECIMAL(5, 2),
    speed_knots INT,
    ping_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ping_id, ping_time)
) PARTITION BY RANGE (ping_time);

-- Create partitions for current operation window
CREATE TABLE pings_current_month PARTITION OF asset_pings
    FOR VALUES FROM ('2023-01-01') TO ('2030-01-01');

-- 5. REAL-TIME NOTIFICATION TRIGGER
-- Notify the GUI when a new coordinate arrives
CREATE OR REPLACE FUNCTION notify_radar()
RETURNS TRIGGER AS $$
DECLARE
    v_callsign VARCHAR;
    v_type VARCHAR;
BEGIN
    SELECT callsign, type INTO v_callsign, v_type FROM assets WHERE asset_id = NEW.asset_id;
    
    -- Payload: "CALLSIGN:TYPE:LAT:LONG:HEADING"
    PERFORM pg_notify('radar_feed', 
        v_callsign || ':' || v_type || ':' || NEW.latitude || ':' || NEW.longitude || ':' || NEW.heading);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_radar_update
AFTER INSERT ON asset_pings
FOR EACH ROW
EXECUTE FUNCTION notify_radar();