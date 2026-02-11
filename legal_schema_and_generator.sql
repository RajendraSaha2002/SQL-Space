-- 1. CLEANUP
DROP TABLE IF EXISTS verdicts CASCADE;
DROP TABLE IF EXISTS case_events CASCADE;
DROP TABLE IF EXISTS cases CASCADE;
DROP TABLE IF EXISTS judges CASCADE;
DROP TABLE IF EXISTS courts CASCADE;

-- 2. SCHEMA DEFINITION

CREATE TABLE courts (
    court_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    district VARCHAR(50),
    type VARCHAR(50) -- 'District', 'Superior', 'Supreme'
);

CREATE TABLE judges (
    judge_id SERIAL PRIMARY KEY,
    court_id INT REFERENCES courts(court_id),
    name VARCHAR(100),
    specialty VARCHAR(50), -- 'Criminal', 'Civil', 'Corporate'
    years_experience INT
);

-- PARTITIONED CASE TABLE (For handling millions of rows)
CREATE TABLE cases (
    case_id BIGSERIAL,
    filing_date DATE NOT NULL,
    category VARCHAR(50), -- 'Theft', 'Divorce', 'Contract Breach', 'Homicide'
    judge_id INT,
    status VARCHAR(20), -- 'Open', 'Closed', 'Appeal'
    complexity_score INT, -- 1-10
    PRIMARY KEY (case_id, filing_date)
) PARTITION BY RANGE (filing_date);

-- Create Partitions for last 5 years
CREATE TABLE cases_2020 PARTITION OF cases FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
CREATE TABLE cases_2021 PARTITION OF cases FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE cases_2022 PARTITION OF cases FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE cases_2023 PARTITION OF cases FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE cases_2024 PARTITION OF cases FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE verdicts (
    verdict_id BIGSERIAL PRIMARY KEY,
    case_id BIGINT,
    filing_date DATE, -- Needed for join optimization on partition
    outcome VARCHAR(50), -- 'Plaintiff Win', 'Defendant Win', 'Dismissed', 'Settled'
    compensation_amount DECIMAL(15, 2),
    verdict_date DATE,
    FOREIGN KEY (case_id, filing_date) REFERENCES cases(case_id, filing_date)
);

-- 3. INDEXING (Vital for aggregations on millions of rows)
CREATE INDEX idx_cases_judge ON cases(judge_id);
CREATE INDEX idx_cases_category ON cases(category);
CREATE INDEX idx_verdicts_outcome ON verdicts(outcome);

-- 4. ANALYTIC VIEW: JUDGE BIAS ANALYZER
CREATE OR REPLACE VIEW v_judge_stats AS
SELECT 
    j.name,
    j.specialty,
    COUNT(c.case_id) as total_cases,
    ROUND(AVG(c.complexity_score), 1) as avg_complexity,
    SUM(CASE WHEN v.outcome = 'Plaintiff Win' THEN 1 ELSE 0 END)::decimal / COUNT(c.case_id) as plaintiff_win_rate
FROM judges j
JOIN cases c ON j.judge_id = c.judge_id
JOIN verdicts v ON c.case_id = v.case_id AND c.filing_date = v.filing_date
GROUP BY j.name, j.specialty;

-- 5. MASSIVE DATA GENERATOR (The Engine)
-- Generates 1 MILLION records optimized for speed.
CREATE OR REPLACE PROCEDURE generate_legal_data()
LANGUAGE plpgsql AS $$
DECLARE
    j_id INT;
BEGIN
    -- A. Setup Courts & Judges
    INSERT INTO courts (name, district, type) VALUES 
    ('Central District Court', 'NY', 'District'),
    ('Superior Court of CA', 'CA', 'Superior'),
    ('High Court of Texas', 'TX', 'Superior');

    INSERT INTO judges (court_id, name, specialty, years_experience)
    SELECT 
        (floor(random() * 3 + 1)),
        'Honorable Judge ' || generate_series,
        (ARRAY['Criminal', 'Civil', 'Family'])[floor(random() * 3 + 1)],
        floor(random() * 30 + 5)
    FROM generate_series(1, 50);

    -- B. Generate 1,000,000 Cases (Bulk Insert)
    -- Using generate_series with randomization for speed
    INSERT INTO cases (filing_date, category, judge_id, status, complexity_score)
    SELECT 
        '2020-01-01'::DATE + (floor(random() * 1460) || ' days')::interval, -- Random date in 4 years
        (ARRAY['Theft', 'Fraud', 'Divorce', 'Contract', 'Injury'])[floor(random() * 5 + 1)],
        floor(random() * 50 + 1), -- Random Judge 1-50
        'Closed',
        floor(random() * 10 + 1)
    FROM generate_series(1, 1000000);

    -- C. Generate Verdicts for 80% of cases
    INSERT INTO verdicts (case_id, filing_date, outcome, compensation_amount, verdict_date)
    SELECT 
        case_id,
        filing_date,
        (ARRAY['Plaintiff Win', 'Defendant Win', 'Settled', 'Dismissed'])[floor(random() * 4 + 1)],
        (random() * 100000),
        filing_date + (floor(random() * 365) || ' days')::interval
    FROM cases
    WHERE random() < 0.8; -- 80% closed cases get verdicts

END;
$$;