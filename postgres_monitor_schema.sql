-- 1. CLEANUP
DROP TABLE IF EXISTS stress_test_data CASCADE;
DROP VIEW IF EXISTS v_index_efficiency CASCADE;
DROP VIEW IF EXISTS v_table_bloat CASCADE;
DROP VIEW IF EXISTS v_lock_monitor CASCADE;

-- 2. DUMMY DATA TABLE (Target for Stress Testing)
-- We will fill this with millions of rows to analyze performance.
CREATE TABLE stress_test_data (
    id SERIAL PRIMARY KEY,
    payload TEXT,
    random_val INT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP
);

-- Index to monitor usage
CREATE INDEX idx_stress_val ON stress_test_data(random_val);

-- 3. MONITORING VIEW: INDEX EFFICIENCY
-- Calculates if indexes are actually being used or if the DB is doing slow "Sequential Scans".
CREATE OR REPLACE VIEW v_index_efficiency AS
SELECT 
    schemaname || '.' || relname as table_name,
    seq_scan as full_table_scans,
    idx_scan as index_lookups,
    n_live_tup as total_rows,
    CASE 
        WHEN (seq_scan + idx_scan) = 0 THEN 0
        ELSE ROUND((idx_scan::decimal / (seq_scan + idx_scan)) * 100, 2) 
    END as index_usage_pct
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;

-- 4. MONITORING VIEW: TABLE BLOAT (Dead Tuples)
-- PostgreSQL doesn't delete rows immediately; it marks them "dead". 
-- Too many dead rows = Bloat = Slow Performance.
CREATE OR REPLACE VIEW v_table_bloat AS
SELECT 
    schemaname || '.' || relname as table_name,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows, -- Deleted but not vacuumed
    last_autovacuum,
    ROUND((n_dead_tup::decimal / NULLIF(n_live_tup + n_dead_tup, 0)) * 100, 2) as bloat_pct
FROM pg_stat_user_tables
WHERE n_live_tup > 0
ORDER BY n_dead_tup DESC;

-- 5. MONITORING VIEW: ACTIVE LOCKS & CONTENTION
-- Who is blocking whom?
CREATE OR REPLACE VIEW v_lock_monitor AS
SELECT 
    COALESCE(blockingl.relation::regclass::text, blockingl.locktype) as locked_item,
    now() - blockeda.query_start as wait_duration,
    blockeda.pid as blocked_pid,
    blockeda.query as blocked_query,
    blockinga.pid as blocking_pid,
    blockinga.query as blocking_query
FROM pg_catalog.pg_locks blockedl
JOIN pg_stat_activity blockeda ON blockedl.pid = blockeda.pid
JOIN pg_catalog.pg_locks blockingl ON(
    (blockingl.transactionid=blockedl.transactionid) OR
    (blockingl.relation=blockedl.relation AND blockingl.locktype=blockedl.locktype)
) AND blockedl.pid != blockingl.pid
JOIN pg_stat_activity blockinga ON blockingl.pid = blockinga.pid
WHERE NOT blockedl.granted;

-- 6. PROCEDURE: GENERATE MILLIONS OF ROWS
-- Generates 1M rows rapidly for the "Big Data" requirement.
CREATE OR REPLACE PROCEDURE generate_load(row_count INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO stress_test_data (payload, random_val)
    SELECT 
        md5(random()::text),
        floor(random() * 10000)
    FROM generate_series(1, row_count);
END;
$$;