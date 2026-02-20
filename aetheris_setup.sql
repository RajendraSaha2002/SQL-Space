-- 1. Create Schemas
CREATE SCHEMA IF NOT EXISTS schema_tactical;
CREATE SCHEMA IF NOT EXISTS schema_admin;

-- 2. Create Unlogged Table for 3x write speed on live sensor data
CREATE UNLOGGED TABLE schema_tactical.live_assets (
    asset_id VARCHAR(50) PRIMARY KEY,
    asset_type VARCHAR(20),
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    status VARCHAR(20),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create Admin Table for Secure PMO Logs
CREATE TABLE schema_admin.pmo_messages (
    msg_id SERIAL PRIMARY KEY,
    sender VARCHAR(50),
    encrypted_content TEXT,
    signature TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Create Triggers for Python-to-Java GUI Bridge (No APIs)
CREATE OR REPLACE FUNCTION notify_asset_update() RETURNS trigger AS $$
BEGIN
    -- Payload format: ID,Type,Lat,Lon
    PERFORM pg_notify('tactical_channel', NEW.asset_id || ',' || NEW.asset_type || ',' || NEW.lat || ',' || NEW.lon);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_asset_update
AFTER INSERT OR UPDATE ON schema_tactical.live_assets
FOR EACH ROW EXECUTE FUNCTION notify_asset_update();

CREATE OR REPLACE FUNCTION notify_pmo_message() RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify('pmo_channel', NEW.sender || ': ' || NEW.encrypted_content);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_pmo_message
AFTER INSERT ON schema_admin.pmo_messages
FOR EACH ROW EXECUTE FUNCTION notify_pmo_message();