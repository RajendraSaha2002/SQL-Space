-- 1. CLEANUP
DROP TABLE IF EXISTS fraud_alerts CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;

-- 2. SCHEMA DEFINITION

CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    account_name VARCHAR(100),
    risk_score INT DEFAULT 0, -- 0 (Safe) to 100 (High Risk)
    account_type VARCHAR(20) -- Savings, Checking, Corporate
);

CREATE TABLE transactions (
    tx_id BIGSERIAL PRIMARY KEY,
    account_id INT REFERENCES accounts(account_id),
    amount DECIMAL(12, 2),
    merchant VARCHAR(100),
    tx_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    location_country VARCHAR(50)
);

CREATE TABLE fraud_alerts (
    alert_id SERIAL PRIMARY KEY,
    tx_id BIGINT REFERENCES transactions(tx_id),
    account_id INT,
    rule_triggered VARCHAR(100),
    severity VARCHAR(20), -- LOW, MEDIUM, CRITICAL
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. INDEXING (Vital for Time-Series Window Functions)
CREATE INDEX idx_tx_account ON transactions(account_id);
CREATE INDEX idx_tx_time ON transactions(tx_timestamp);

-- 4. THE FRAUD ENGINE (Stored Procedure)
-- This replaces "AI" with deterministic logic.
-- It detects:
-- A. Velocity: > 3 transactions in 10 minutes.
-- B. Spike: Amount > 500% of the user's historical average.
CREATE OR REPLACE PROCEDURE run_fraud_engine()
LANGUAGE plpgsql AS $$
BEGIN
    -- Clear old alerts for this demo run
    TRUNCATE TABLE fraud_alerts RESTART IDENTITY;

    -- 1. DETECT & INSERT
    INSERT INTO fraud_alerts (tx_id, account_id, rule_triggered, severity)
    WITH UserStats AS (
        -- Calculate historical average per user
        SELECT account_id, AVG(amount) as avg_amt 
        FROM transactions 
        GROUP BY account_id
    ),
    WindowLogic AS (
        SELECT 
            t.tx_id,
            t.account_id,
            t.amount,
            t.tx_timestamp,
            us.avg_amt,
            -- Count transactions in the last 10 minutes for this user
            COUNT(t.tx_id) OVER (
                PARTITION BY t.account_id 
                ORDER BY t.tx_timestamp 
                RANGE BETWEEN INTERVAL '10 minutes' PRECEDING AND CURRENT ROW
            ) as recent_tx_count
        FROM transactions t
        JOIN UserStats us ON t.account_id = us.account_id
    )
    SELECT 
        tx_id, 
        account_id,
        CASE 
            WHEN recent_tx_count >= 4 THEN 'High Velocity (Rapid Transactions)'
            WHEN amount > (avg_amt * 5) THEN 'Amount Spike (>500% Avg)'
            ELSE 'Suspicious Activity'
        END as rule_triggered,
        CASE 
            WHEN recent_tx_count >= 4 THEN 'CRITICAL'
            ELSE 'MEDIUM'
        END as severity
    FROM WindowLogic
    WHERE recent_tx_count >= 4 OR amount > (avg_amt * 5);

    -- 2. UPDATE ACCOUNT RISK SCORES
    UPDATE accounts 
    SET risk_score = 0; -- Reset

    UPDATE accounts a
    SET risk_score = sub.new_score
    FROM (
        SELECT account_id, COUNT(*) * 20 as new_score -- +20 points per fraud
        FROM fraud_alerts
        GROUP BY account_id
    ) sub
    WHERE a.account_id = sub.account_id;
    
END;
$$;

-- 5. DATA SEEDING (Generating 1000 txns)
INSERT INTO accounts (account_name, account_type)
SELECT 'User ' || generate_series, 'Checking' FROM generate_series(1, 20);

DO $$
DECLARE
    u_id INT;
    amt DECIMAL;
    t_time TIMESTAMP;
BEGIN
    FOR i IN 1..1000 LOOP
        u_id := floor(random() * 20 + 1);
        amt := (random() * 100) + 10; -- Normal amount $10-$110
        t_time := NOW() - (random() * interval '24 hours');
        
        -- Inject FRAUD case 1: Massive Amount (The Spike)
        IF i % 50 = 0 THEN
            amt := 2500.00; 
        END IF;

        -- Inject FRAUD case 2: Velocity (The Rapid Fire)
        -- We will insert these manually in the next block, so skipping here
        
        INSERT INTO transactions (account_id, amount, merchant, tx_timestamp, location_country)
        VALUES (u_id, amt, 'Amazon', t_time, 'US');
    END LOOP;

    -- Inject Specific Velocity Attack (User 1 does 5 txns in 1 minute)
    FOR j IN 1..5 LOOP
        INSERT INTO transactions (account_id, amount, merchant, tx_timestamp, location_country)
        VALUES (1, 50.00, 'Apple Store', NOW(), 'US');
    END LOOP;
END $$;

-- Run the engine once to populate initial views
CALL run_fraud_engine();