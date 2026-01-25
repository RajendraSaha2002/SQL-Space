
-- 1. The Genome Table (Storing the Building Blocks)
CREATE TABLE IF NOT EXISTS genome_sequence (
    id SERIAL PRIMARY KEY,
    chromosome_id VARCHAR(10) DEFAULT 'CHR-1',
    position_index INT NOT NULL, -- The location on the strand
    base_pair CHAR(1) NOT NULL, -- 'A', 'T', 'C', 'G'
    gene_marker VARCHAR(50),    -- Metadata (e.g., 'Spike Protein')
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast "Guide RNA" searches
CREATE INDEX idx_position ON genome_sequence(position_index);

-- 2. Seed Data (A Synthetic Viral Genome)
-- Cleaning old data to ensure clean slate
TRUNCATE TABLE genome_sequence;

-- We will insert a sequence representing a "Replication Gene"
-- Sequence: ATG CCT AAG TCG ...
INSERT INTO genome_sequence (position_index, base_pair, gene_marker) VALUES 
(1, 'A', 'Replication_Start'), (2, 'T', 'Replication_Start'), (3, 'G', 'Replication_Start'),
(4, 'C', 'Enzyme_Alpha'), (5, 'C', 'Enzyme_Alpha'), (6, 'T', 'Enzyme_Alpha'),
(7, 'A', 'Enzyme_Alpha'), (8, 'A', 'Enzyme_Alpha'), (9, 'G', 'Enzyme_Alpha'),
(10, 'T', 'Spike_Protein'), (11, 'C', 'Spike_Protein'), (12, 'G', 'Spike_Protein'),
(13, 'A', 'Spike_Protein'), (14, 'T', 'Spike_Protein'), (15, 'C', 'Spike_Protein'),
(16, 'G', 'Terminator'), (17, 'G', 'Terminator'), (18, 'A', 'Terminator'),
(19, 'T', 'Terminator'), (20, 'C', 'Terminator');