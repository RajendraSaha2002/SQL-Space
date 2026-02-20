-- 1. CLEANUP
DROP TABLE IF EXISTS access_logs CASCADE;
DROP TABLE IF EXISTS digital_fingerprints CASCADE;
DROP ROLE IF EXISTS sec_analyst;

-- 2. SENSITIVE FILE FINGERPRINTS
-- We store the SHA-256 Hash of high-clearance documents.
CREATE TABLE digital_fingerprints (
    file_id SERIAL PRIMARY KEY,
    filename_masked VARCHAR(100), -- e.g., '*****_BRIEF.PDF'
    file_hash VARCHAR(64) UNIQUE NOT NULL, -- The SHA-256 Signature
    classification VARCHAR(20) DEFAULT 'TOP_SECRET'
);

-- Insert a "known" sensitive file hash (Simulating a Cabinet Draft)
-- Hash represents string "SECRET_DATA"
INSERT INTO digital_fingerprints (filename_masked, file_hash) 
VALUES ('CABINET_MEETING_LOG_2026.PDF', '6e6e2e5050720275810239243750892700388279883651717362919927382749');

-- 3. AUDIT LOGS
CREATE TABLE access_logs (
    log_id SERIAL PRIMARY KEY,
    event_type VARCHAR(50), -- 'EXFILTRATION_ATTEMPT', 'NORMAL_TRAFFIC'
    detected_at TIMESTAMP DEFAULT NOW()
);

-- 4. ROW LEVEL SECURITY (RLS)
-- Create a specific role for the application
CREATE ROLE sec_analyst WITH LOGIN PASSWORD 'monitor123';

ALTER TABLE digital_fingerprints ENABLE ROW LEVEL SECURITY;

-- Policy: Security Analyst can READ fingerprints to check matches
CREATE POLICY analyst_read_policy ON digital_fingerprints
    FOR SELECT
    TO sec_analyst
    USING (true);

-- Policy: No one can DELETE fingerprints remotely
CREATE POLICY admin_no_delete ON digital_fingerprints
    FOR DELETE
    USING (false);

GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA public TO sec_analyst;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sec_analyst;