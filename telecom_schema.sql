-- 1. CLEANUP
DROP TABLE IF EXISTS billing_anomalies CASCADE;
DROP TABLE IF EXISTS cdr_logs CASCADE;
DROP TABLE IF EXISTS subscribers CASCADE;

-- 2. SCHEMA DEFINITION

-- Dimension: Subscribers
CREATE TABLE subscribers (
    sub_id SERIAL PRIMARY KEY,
    phone_number VARCHAR(15) UNIQUE,
    plan_type VARCHAR(20), -- Prepaid, Postpaid, Corporate
    region VARCHAR(10) -- NY, CA, TX, FL
);

-- Fact: Call Detail Records (CDR)
-- We use PARTITIONING because this table will get massive.
CREATE TABLE cdr_logs (
    call_id BIGSERIAL,
    caller_num VARCHAR(15),
    receiver_num VARCHAR(15),
    call_start TIMESTAMP NOT NULL,
    duration_sec INT,
    call_type VARCHAR(10), -- Voice, SMS, Data
    cost DECIMAL(10, 4),
    tower_id VARCHAR(10),
    status VARCHAR(10), -- Success, Dropped, Failed
    PRIMARY KEY (call_id, call_start)
) PARTITION BY RANGE (call_start);

-- Create Partitions (Simulating Monthly Buckets)
CREATE TABLE cdr_2024_01 PARTITION OF cdr_logs FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE cdr_2024_02 PARTITION OF cdr_logs FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE cdr_2024_03 PARTITION OF cdr_logs FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');

-- Table for Flagged Fraud/Leakage
CREATE TABLE billing_anomalies (
    anomaly_id SERIAL PRIMARY KEY,
    call_id BIGINT,
    reason VARCHAR(100),
    severity VARCHAR(20),
    detected_at TIMESTAMP DEFAULT NOW()
);

-- 3. INDEXING (Vital for Time-Series Queries)
CREATE INDEX idx_cdr_caller ON cdr_logs(caller_num);
CREATE INDEX idx_cdr_time ON cdr_logs(call_start);
CREATE INDEX idx_cdr_tower ON cdr_logs(tower_id);

-- 4. ANALYTIC VIEW: Hourly Traffic Peaks
CREATE OR REPLACE VIEW v_hourly_traffic AS
SELECT 
    date_trunc('hour', call_start) as hour_bucket,
    COUNT(*) as total_calls,
    SUM(duration_sec) / 60.0 as total_minutes,
    SUM(CASE WHEN status = 'Dropped' THEN 1 ELSE 0 END) as dropped_calls
FROM cdr_logs
GROUP BY 1
ORDER BY 1 DESC;

-- 5. FRAUD DETECTION PROCEDURE
-- Logic:
-- 1. "Sim Box Fraud": One number calling > 50 unique people in 1 hour.
-- 2. "Revenue Leakage": Long duration calls (> 10 mins) with $0.00 cost.
CREATE OR REPLACE PROCEDURE detect_telecom_fraud()
LANGUAGE plpgsql AS $$
BEGIN
    TRUNCATE TABLE billing_anomalies;

    -- A. Detect Revenue Leakage (Free long calls)
    INSERT INTO billing_anomalies (call_id, reason, severity)
    SELECT call_id, 'Revenue Leakage: Long duration (>' || duration_sec || 's) with zero cost', 'MEDIUM'
    FROM cdr_logs
    WHERE duration_sec > 600 AND cost = 0.00;

    -- B. Detect High-Frequency Calling (Potential Spam/Robocall)
    INSERT INTO billing_anomalies (call_id, reason, severity)
    SELECT MAX(call_id), 'High Frequency: > 20 calls in short window', 'HIGH'
    FROM cdr_logs
    GROUP BY caller_num, date_trunc('hour', call_start)
    HAVING COUNT(*) > 20;
    
END;
$$;