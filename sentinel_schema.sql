

-- 1. Create the Master Logs Table (Partitioned by Range)
CREATE TABLE security_logs (
    id SERIAL,
    event_type VARCHAR(50),
    file_path TEXT,
    severity VARCHAR(20),
    occurred_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT
) PARTITION BY RANGE (occurred_at);

-- 2. Create specific partitions (e.g., for March 2024)
-- In a real production system, a Cron job or Background worker creates these.
CREATE TABLE security_logs_2024_03 PARTITION OF security_logs
    FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');

CREATE TABLE security_logs_2024_04 PARTITION OF security_logs
    FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');

-- 3. Sessions Table (for the Lockout Logic)
CREATE TABLE active_sessions (
    session_id SERIAL PRIMARY KEY,
    username VARCHAR(50),
    is_locked BOOLEAN DEFAULT FALSE,
    last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Defense Stored Procedure: Auto-Lock Sessions
-- This logic executes when a "CRITICAL" event is logged.
CREATE OR REPLACE FUNCTION lock_all_sessions_on_intrusion()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.severity = 'CRITICAL' THEN
        UPDATE active_sessions SET is_locked = TRUE;
        -- Optional: Log that a system-wide lockout was triggered
        RAISE NOTICE 'Intrusion Detected: All sessions locked.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger: Attach the defense logic to the logs
CREATE TRIGGER intrusion_detection_trigger
AFTER INSERT ON security_logs
FOR EACH ROW EXECUTE FUNCTION lock_all_sessions_on_intrusion();

-- Insert a test session
INSERT INTO active_sessions (username) VALUES ('admin_operator');