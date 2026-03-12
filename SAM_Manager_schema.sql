DROP TABLE IF EXISTS engagements;
DROP TABLE IF EXISTS missile_inventory;
DROP TABLE IF EXISTS batteries;

-- 1. The SAM Sites
CREATE TABLE batteries (
    id SERIAL PRIMARY KEY,
    callsign VARCHAR(50) UNIQUE NOT NULL,
    pos_x INTEGER NOT NULL, -- Kilometers
    pos_y INTEGER NOT NULL, -- Kilometers
    pos_z INTEGER NOT NULL, -- Altitude (meters)
    status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, RELOADING, OFFLINE
    radar_range_km INTEGER DEFAULT 150
);

-- 2. Ammo Inventory (Linked to Batteries)
CREATE TABLE missile_inventory (
    id SERIAL PRIMARY KEY,
    battery_id INTEGER REFERENCES batteries(id),
    missile_type VARCHAR(50), -- 'PAC-3', 'THAAD', 'STANDARD-SM6'
    count INTEGER NOT NULL,
    max_speed_mach DECIMAL(4, 1),
    max_range_km INTEGER
);

-- 3. Engagement Logs (History of shots)
CREATE TABLE engagements (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    battery_id INTEGER REFERENCES batteries(id),
    target_id VARCHAR(50),
    result VARCHAR(20), -- INTERCEPT_CALCULATED, MISSED
    notes TEXT
);

-- SEED DATA: Deploy 3 Batteries in a triangular sector
INSERT INTO batteries (callsign, pos_x, pos_y, pos_z) VALUES 
('ALPHA_BATTERY', 10, 10, 50),
('BRAVO_BATTERY', 80, 20, 120),
('CHARLIE_BATTERY', 45, 80, 80);

-- Stock them with missiles
INSERT INTO missile_inventory (battery_id, missile_type, count, max_speed_mach, max_range_km) VALUES
(1, 'PAC-3 Patriot', 16, 4.1, 80),
(2, 'THAAD Long Range', 8, 8.2, 200),
(3, 'Iron Dome', 20, 2.2, 40);