CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    clearance_level INTEGER NOT NULL
);

CREATE TABLE documents (
    doc_id SERIAL PRIMARY KEY,
    title TEXT,
    encrypted_data BYTEA,
    classification_level INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tamper_proof_audit (
    audit_id SERIAL PRIMARY KEY,
    user_id INTEGER,
    doc_id INTEGER,
    action TEXT,
    access_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY clearance_policy
ON documents
FOR SELECT
USING (
    classification_level <= current_setting('app.current_clearance')::INTEGER
);
CREATE OR REPLACE FUNCTION prevent_delete_audit()
RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs cannot be deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER block_delete_audit
BEFORE DELETE ON tamper_proof_audit
FOR EACH ROW
EXECUTE FUNCTION prevent_delete_audit();