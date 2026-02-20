-- 1. CLEANUP
DROP TABLE IF EXISTS intelligence_reports CASCADE;
DROP TABLE IF EXISTS uav_feeds CASCADE;
DROP TABLE IF EXISTS secure_channels CASCADE;

-- 2. SECURE COMM CHANNELS
CREATE TABLE secure_channels (
    channel_id SERIAL PRIMARY KEY,
    name VARCHAR(50), -- e.g., 'NORTH-SECTOR', 'PMO-DIRECT'
    encryption_key_id VARCHAR(100) -- Reference to external key vault
);

INSERT INTO secure_channels (name) VALUES ('NORTH-SECTOR'), ('EAST-SECTOR'), ('PMO-RED-LINE');

-- 3. UAV FEED DATA (Partitioned by Region)
-- We store metadata here. Images are stored on encrypted disk.
CREATE TABLE uav_feeds (
    log_id BIGSERIAL,
    region_id VARCHAR(10), -- 'N-01', 'E-05'
    detected_object VARCHAR(50), -- 'TANK', 'BUNKER', 'TROOP'
    threat_level VARCHAR(20), -- 'LOW', 'MEDIUM', 'CRITICAL'
    latitude DECIMAL(9, 6),
    longitude DECIMAL(9, 6),
    image_path TEXT, -- Path to local encrypted file
    timestamp TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (log_id, region_id)
) PARTITION BY LIST (region_id);

-- Create Partitions
CREATE TABLE uav_north PARTITION OF uav_feeds FOR VALUES IN ('N-01', 'N-02');
CREATE TABLE uav_east PARTITION OF uav_feeds FOR VALUES IN ('E-01', 'E-05');

-- 4. INTELLIGENCE REPORTS (For PDF Generation)
CREATE TABLE intelligence_reports (
    report_id SERIAL PRIMARY KEY,
    author_rank VARCHAR(50),
    summary TEXT,
    generated_at TIMESTAMP DEFAULT NOW()
);

-- 5. REAL-TIME ALERT TRIGGER
CREATE OR REPLACE FUNCTION notify_threat()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.threat_level = 'CRITICAL' THEN
        PERFORM pg_notify('pmo_alert', 
            'CRITICAL THREAT DETECTED: ' || NEW.detected_object || ' AT ' || NEW.latitude || ',' || NEW.longitude);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_critical_threat
AFTER INSERT ON uav_feeds
FOR EACH ROW
EXECUTE FUNCTION notify_threat();