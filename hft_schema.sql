-- 1. CLEANUP
DROP TABLE IF EXISTS market_ticks CASCADE;
DROP TABLE IF EXISTS symbols CASCADE;

-- 2. REFERENCE DATA
CREATE TABLE symbols (
    symbol_id SERIAL PRIMARY KEY,
    ticker VARCHAR(10) UNIQUE,
    company_name VARCHAR(100)
);

INSERT INTO symbols (ticker, company_name) VALUES 
('AAPL', 'Apple Inc.'), ('GOOGL', 'Alphabet Inc.'), ('TSLA', 'Tesla Inc.'), 
('AMZN', 'Amazon.com'), ('MSFT', 'Microsoft Corp.');

-- 3. HYPERTABLE SIMULATION (Standard Postgres Partitioning)
-- In a real HFT scenario, you would use TimescaleDB: SELECT create_hypertable('market_ticks', 'time');
-- Here, we use standard partitioning for compatibility.
CREATE TABLE market_ticks (
    tick_id BIGSERIAL,
    symbol_id INT REFERENCES symbols(symbol_id),
    price DECIMAL(10, 4) NOT NULL,
    volume INT NOT NULL,
    tick_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) PARTITION BY RANGE (tick_time);

-- Create partitions for the current month
CREATE TABLE ticks_current PARTITION OF market_ticks
    FOR VALUES FROM ('2023-01-01') TO ('2030-01-01');

-- 4. ADVANCED INDEXING: BRIN
-- BRIN indexes are tiny and super fast for time-series data appended in order.
CREATE INDEX idx_ticks_brin ON market_ticks USING BRIN(tick_time);

-- 5. REAL-TIME NOTIFICATION SYSTEM
-- When a bulk load happens, notify the GUI to refresh the chart.
CREATE OR REPLACE FUNCTION notify_tick()
RETURNS TRIGGER AS $$
DECLARE
    v_ticker VARCHAR;
BEGIN
    -- Get ticker name for the payload
    SELECT ticker INTO v_ticker FROM symbols WHERE symbol_id = NEW.symbol_id;
    
    -- Payload format: "TICKER:PRICE:VOLUME"
    PERFORM pg_notify('market_feed', v_ticker || ':' || NEW.price || ':' || NEW.volume);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on INSERT (fires for every row, but in COPY it batches efficiently)
CREATE TRIGGER trg_realtime_feed
AFTER INSERT ON market_ticks
FOR EACH ROW
EXECUTE FUNCTION notify_tick();