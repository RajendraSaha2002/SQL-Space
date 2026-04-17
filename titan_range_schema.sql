DROP TABLE IF EXISTS admin_action_logs CASCADE;
DROP TABLE IF EXISTS fps_players CASCADE;

-- Core Player Database
CREATE TABLE fps_players (
    player_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    pass_hash VARCHAR(100),
    rank VARCHAR(20) DEFAULT 'BRONZE',
    currency INT DEFAULT 100,
    profile_msg VARCHAR(200) DEFAULT 'Hello World',
    is_banned BOOLEAN DEFAULT FALSE
);

-- Audit Logging
CREATE TABLE admin_action_logs (
    log_id SERIAL PRIMARY KEY,
    action_type VARCHAR(50),
    target_user VARCHAR(50),
    executed_sql TEXT,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed Data
INSERT INTO fps_players (username, pass_hash, rank, currency) VALUES 
('admin_master', 'super_secret_hash_99', 'PREDATOR', 999999),
('normal_gamer', 'password123', 'SILVER', 500),
('hacker_zero', 'weakpass', 'BRONZE', 0);

-- SECURE STORED PROCEDURE: Pro-level defense for Economy Transactions
-- Even if Java is compromised, this restricts how currency is granted
CREATE OR REPLACE FUNCTION secure_grant_currency(
    p_username VARCHAR, 
    p_amount INT
) RETURNS VOID AS $$
BEGIN
    -- Business Logic: Cannot grant more than 10,000 at once to prevent inflation
    IF p_amount > 10000 THEN
        RAISE EXCEPTION 'SECURITY ALERT: Currency grant exceeds maximum threshold!';
    END IF;

    UPDATE fps_players 
    SET currency = currency + p_amount 
    WHERE username = p_username;
    
    INSERT INTO admin_action_logs (action_type, target_user, executed_sql)
    VALUES ('SECURE_CURRENCY_GRANT', p_username, 'Granted via SP: ' || p_amount);
END;
$$ LANGUAGE plpgsql;