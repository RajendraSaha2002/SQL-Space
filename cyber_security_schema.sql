-- 1. CLEANUP
DROP MATERIALIZED VIEW IF EXISTS mv_hourly_threat_summary;
DROP TABLE IF EXISTS auth_logs CASCADE;
DROP TABLE IF EXISTS ip_reputation CASCADE;

-- 2. SCHEMA DEFINITION

-- Table: IP Reputation (White/Blacklist context)
CREATE TABLE ip_reputation (
    ip_address INET PRIMARY KEY,
    risk_score INT DEFAULT 0, -- 0-100 (100 = malicious)
    country_code CHAR(2),
    last_flagged TIMESTAMP
);

-- Table: Authentication Logs (The heavy write table)
-- We use PARTITIONING by month for performance on massive log volumes
CREATE TABLE auth_logs (
    log_id BIGSERIAL,
    event_timestamp TIMESTAMP NOT NULL,
    source_ip INET NOT NULL,
    username VARCHAR(100),
    event_type VARCHAR(50), -- 'LOGIN_SUCCESS', 'LOGIN_FAILED', 'API_ACCESS'
    status_code INT,
    user_agent TEXT,
    PRIMARY KEY (log_id, event_timestamp)
) PARTITION BY RANGE (event_timestamp);

-- Create partitions for current and next month
CREATE TABLE auth_logs_current PARTITION OF auth_logs
    FOR VALUES FROM ('2023-01-01') TO ('2027-01-01');

-- 3. INDEXING (Critical for Cyber Queries)
CREATE INDEX idx_logs_ip ON auth_logs(source_ip);
CREATE INDEX idx_logs_time ON auth_logs(event_timestamp);
CREATE INDEX idx_logs_type ON auth_logs(event_type);

-- 4. MATERIALIZED VIEW (For Rapid Dashboarding)
-- Instead of querying raw logs every time, we pre-calculate hourly attack stats.
CREATE MATERIALIZED VIEW mv_hourly_threat_summary AS
SELECT 
    date_trunc('hour', event_timestamp) as log_hour,
    source_ip,
    COUNT(*) as total_attempts,
    SUM(CASE WHEN event_type = 'LOGIN_FAILED' THEN 1 ELSE 0 END) as failed_attempts,
    MAX(event_timestamp) as last_seen
FROM auth_logs
GROUP BY 1, 2
WITH DATA;

CREATE INDEX idx_mv_hour ON mv_hourly_threat_summary(log_hour);

-- 5. REFRESH FUNCTION
-- In production, a cron job runs this every hour
CREATE OR REPLACE FUNCTION refresh_threat_view()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW mv_hourly_threat_summary;
END;
$$ LANGUAGE plpgsql;

-- 6. DATA GENERATION PROCEDURES (Synthetic Attack Data)

-- Helper: Insert normal traffic
CREATE OR REPLACE PROCEDURE generate_normal_traffic(rows INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO auth_logs (event_timestamp, source_ip, username, event_type, status_code)
    SELECT 
        NOW() - (random() * interval '7 days'),
        ('192.168.1.' || floor(random()*250 + 1))::inet,
        'user_' || floor(random()*50),
        CASE WHEN random() > 0.1 THEN 'LOGIN_SUCCESS' ELSE 'LOGIN_FAILED' END,
        200
    FROM generate_series(1, rows);
END;
$$;

-- Helper: Insert BRUTE FORCE ATTACK (High volume, same IP, mostly failures)
CREATE OR REPLACE PROCEDURE simulate_brute_force(attacker_ip TEXT, attempts INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO auth_logs (event_timestamp, source_ip, username, event_type, status_code)
    SELECT 
        NOW() - (random() * interval '6 hours'), -- Happened recently
        attacker_ip::inet,
        'admin', -- Usually targeting admin
        'LOGIN_FAILED',
        401
    FROM generate_series(1, attempts);
END;
$$;

-- 7. EXECUTE GENERATION
-- Generate 5000 normal logs
CALL generate_normal_traffic(5000);

-- Simulate 3 distinct attacks
CALL simulate_brute_force('45.20.10.1', 800);  -- Attack A
CALL simulate_brute_force('103.40.20.5', 1200); -- Attack B (Heavy)
CALL simulate_brute_force('185.100.2.99', 300); -- Attack C

-- Calculate the view
REFRESH MATERIALIZED VIEW mv_hourly_threat_summary;