-- 1. CLEANUP
DROP TABLE IF EXISTS transaction_logs CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;

-- 2. SCHEMA DEFINITION

CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    owner_name VARCHAR(100),
    balance DECIMAL(15, 2) CHECK (balance >= 0), -- Constraint: No Overdrafts
    account_tier VARCHAR(20) DEFAULT 'Standard',
    version_id BIGINT DEFAULT 1 -- For Optimistic Locking (Optional, but good practice)
);

CREATE TABLE transaction_logs (
    tx_id BIGSERIAL PRIMARY KEY,
    sender_id INT,
    receiver_id INT,
    amount DECIMAL(15, 2),
    status VARCHAR(20), -- SUCCESS, FAILED, ROLLBACK
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. INDEXING (Crucial for high concurrency lookups)
CREATE INDEX idx_accounts_balance ON accounts(balance);
CREATE INDEX idx_logs_status ON transaction_logs(status);

-- 4. THE CORE TRANSFER ENGINE (Stored Procedure)
-- This procedure handles the "Critical Section" of the transaction.
-- It uses explicit locking to ensure ACID compliance.
CREATE OR REPLACE PROCEDURE transfer_funds(
    p_sender_id INT,
    p_receiver_id INT,
    p_amount DECIMAL
)
LANGUAGE plpgsql AS $$
DECLARE
    current_bal DECIMAL;
BEGIN
    -- 1. START TRANSACTION (Implicit in Procedure, but we define logic flow)
    
    -- 2. LOCKING STRATEGY (Deadlock Prevention)
    -- Always lock IDs in ascending order to prevent deadlocks.
    -- If Sender=5, Receiver=2. Lock 2 first, then 5.
    IF p_sender_id < p_receiver_id THEN
        PERFORM 1 FROM accounts WHERE account_id = p_sender_id FOR UPDATE;
        PERFORM 1 FROM accounts WHERE account_id = p_receiver_id FOR UPDATE;
    ELSE
        PERFORM 1 FROM accounts WHERE account_id = p_receiver_id FOR UPDATE;
        PERFORM 1 FROM accounts WHERE account_id = p_sender_id FOR UPDATE;
    END IF;

    -- 3. VALIDATION
    SELECT balance INTO current_bal FROM accounts WHERE account_id = p_sender_id;
    
    IF current_bal < p_amount THEN
        -- Insufficient Funds
        INSERT INTO transaction_logs (sender_id, receiver_id, amount, status, error_message)
        VALUES (p_sender_id, p_receiver_id, p_amount, 'FAILED', 'Insufficient Funds');
        RETURN;
    END IF;

    -- 4. EXECUTE TRANSFER
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_sender_id;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_receiver_id;

    -- 5. AUDIT LOG
    INSERT INTO transaction_logs (sender_id, receiver_id, amount, status)
    VALUES (p_sender_id, p_receiver_id, p_amount, 'SUCCESS');

    -- COMMIT happens automatically at end of procedure call if no exception raised
EXCEPTION WHEN OTHERS THEN
    -- ROLLBACK LOGIC (Log the crash)
    INSERT INTO transaction_logs (sender_id, receiver_id, amount, status, error_message)
    VALUES (p_sender_id, p_receiver_id, p_amount, 'ERROR', SQLERRM);
    RAISE NOTICE 'Transaction Failed: %', SQLERRM;
END;
$$;

-- 5. SEED DATA
-- Create 100 Accounts with $10,000 each
INSERT INTO accounts (owner_name, balance, account_tier)
SELECT 
    'Account_' || generate_series, 
    10000.00,
    CASE WHEN random() > 0.8 THEN 'Premium' ELSE 'Standard' END
FROM generate_series(1, 100);