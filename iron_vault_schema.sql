DROP TABLE IF EXISTS fraud_incidents;
DROP TABLE IF EXISTS transaction_ledger;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    acct_id VARCHAR(20) PRIMARY KEY,
    balance DECIMAL(15,2) NOT NULL CHECK (balance >= 0),
    status VARCHAR(20) DEFAULT 'ACTIVE'
);

CREATE TABLE transaction_ledger (
    tx_id SERIAL PRIMARY KEY,
    from_acct VARCHAR(20),
    to_acct VARCHAR(20),
    amount DECIMAL(15,2),
    status VARCHAR(20),
    tx_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fraud_incidents (
    incident_id SERIAL PRIMARY KEY,
    acct_id VARCHAR(20),
    rule_triggered VARCHAR(100),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed Accounts
INSERT INTO accounts (acct_id, balance, status) VALUES 
('ACCT_ALICE', 50000.00, 'ACTIVE'),
('ACCT_BOB', 10000.00, 'ACTIVE'),
('ACCT_HACKER', 1000000.00, 'ACTIVE'), -- Used for Smurfing
('ACCT_DUMMY', 0.00, 'ACTIVE');

-- ACID Compliant Transfer Function (Blocks Double Spending)
CREATE OR REPLACE FUNCTION process_transfer(
    p_from VARCHAR, p_to VARCHAR, p_amount DECIMAL
) RETURNS VARCHAR AS $$
DECLARE
    v_balance DECIMAL;
    v_status VARCHAR;
BEGIN
    -- ROW-LEVEL LOCK to prevent Race Conditions / Double Spending
    SELECT balance, status INTO v_balance, v_status 
    FROM accounts WHERE acct_id = p_from FOR UPDATE;

    IF v_status = 'FROZEN' THEN
        RETURN 'FAILED: ACCOUNT_FROZEN';
    END IF;

    IF v_balance < p_amount THEN
        RETURN 'FAILED: INSUFFICIENT_FUNDS';
    END IF;

    -- Execute transfer
    UPDATE accounts SET balance = balance - p_amount WHERE acct_id = p_from;
    UPDATE accounts SET balance = balance + p_amount WHERE acct_id = p_to;
    
    INSERT INTO transaction_ledger (from_acct, to_acct, amount, status) 
    VALUES (p_from, p_to, p_amount, 'SUCCESS');

    RETURN 'SUCCESS';
EXCEPTION WHEN OTHERS THEN
    -- Auto-rollback on any mathematical/constraint failure
    RETURN 'FAILED: SYSTEM_ERROR';
END;
$$ LANGUAGE plpgsql;