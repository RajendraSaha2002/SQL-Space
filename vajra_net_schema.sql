-- 1. CLEANUP
DROP TABLE IF EXISTS strike_orders CASCADE;
DROP TABLE IF EXISTS radar_tracks CASCADE;
DROP TABLE IF EXISTS assets CASCADE;

-- 2. ASSET REGISTRY (The "Blue" Force)
CREATE TABLE assets (
    asset_id VARCHAR(20) PRIMARY KEY, -- e.g., 'INS-VIKRANT'
    type VARCHAR(20), -- 'CARRIER', 'SU-30MKI', 'T-90'
    service VARCHAR(10), -- 'NAVY', 'AIR', 'ARMY'
    status VARCHAR(20) DEFAULT 'ACTIVE'
);

INSERT INTO assets (asset_id, type, service) VALUES 
('SQN-18', 'SU-30MKI', 'AIR'),
('CORPS-1', 'T-90 BISHMA', 'ARMY'),
('INS-KOLKATA', 'DESTROYER', 'NAVY');

-- 3. RADAR HISTORY (The "Red" & "Blue" Tracks)
CREATE TABLE radar_tracks (
    track_id BIGSERIAL PRIMARY KEY,
    detected_at TIMESTAMP DEFAULT NOW(),
    object_type VARCHAR(20), -- 'FRIENDLY', 'BOGEY', 'UNKNOWN'
    latitude DECIMAL(9, 6),
    longitude DECIMAL(9, 6),
    altitude_ft INT,
    speed_knots INT,
    heading INT
);

-- 4. STRIKE ORDERS (Command & Control)
CREATE TABLE strike_orders (
    order_id SERIAL PRIMARY KEY,
    target_track_id BIGINT,
    authorized_by VARCHAR(50), -- CDS Name
    asset_assigned VARCHAR(20) REFERENCES assets(asset_id),
    status VARCHAR(20) DEFAULT 'PENDING',
    timestamp TIMESTAMP DEFAULT NOW()
);

-- Note: We rely on ZeroMQ for real-time alerts, so no SQL Triggers here.
-- The DB is strictly for "Record of Truth" and post-action analysis.