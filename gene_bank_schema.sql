
DROP TABLE IF EXISTS soldiers;

-- 1. The Gene Bank
CREATE TABLE IF NOT EXISTS soldiers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    rank VARCHAR(50),
    blood_type VARCHAR(5),
    
    -- The Genetic Code (Stored as text for simulation)
    -- Healthy Sequence contains 'AAA' markers
    dna_sequence TEXT NOT NULL,
    
    last_checkup TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Seed Data
-- We insert soldiers with the "AAA" marker (Healthy)
INSERT INTO soldiers (name, rank, blood_type, dna_sequence) VALUES 
('Sgt. John Doe', 'Sergeant', 'O+', 'GCATAAAGCTAGCTAGCTAGCTAGCT'),
('Pvt. Jane Smith', 'Private', 'A-', 'CGTAGCTAAAGCTAGCTAGCTAGCTA'),
('Cpl. Mike Ross', 'Corporal', 'AB+', 'TGCATGCATAAAGCTAGCTAGCTAGC'),
('Lt. Ellen Ripley', 'Lieutenant', 'B+', 'AGCTAGCTAAAGCTAGCTAGCTAGCT');