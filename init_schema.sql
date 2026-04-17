CREATE TABLE IF NOT EXISTS hardware_assets (
    asset_id        SERIAL PRIMARY KEY,
    asset_key       VARCHAR(50) UNIQUE NOT NULL,
    asset_type      VARCHAR(30) NOT NULL,
    rack_label      VARCHAR(30) NOT NULL,
    critical_temp_c  NUMERIC(5,2) NOT NULL DEFAULT 30.00,
    safe_mode       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS telemetry_logs (
    log_id       BIGSERIAL PRIMARY KEY,
    asset_key    VARCHAR(50) NOT NULL,
    temp_c       NUMERIC(5,2),
    humidity     NUMERIC(5,2),
    voltage_v    NUMERIC(6,2),
    load_pct     NUMERIC(5,2),
    status       VARCHAR(30) NOT NULL,
    raw_json     TEXT NOT NULL,
    received_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS access_control (
    user_id        SERIAL PRIMARY KEY,
    username       VARCHAR(80) UNIQUE NOT NULL,
    password_hash  TEXT NOT NULL,
    role_name      VARCHAR(30) NOT NULL,
    active         BOOLEAN NOT NULL DEFAULT TRUE,
    session_token  VARCHAR(120)
);

CREATE TABLE IF NOT EXISTS auth_events (
    event_id      BIGSERIAL PRIMARY KEY,
    username      VARCHAR(120) NOT NULL,
    source        VARCHAR(50) NOT NULL,
    event_type    VARCHAR(40) NOT NULL,
    flagged       BOOLEAN NOT NULL DEFAULT FALSE,
    raw_json      TEXT NOT NULL,
    received_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO hardware_assets(asset_key, asset_type, rack_label, critical_temp_c, safe_mode) VALUES
('HVAC-01','cooling_unit','A1',30.00,false),
('UPS-01','power_unit','A2',32.00,false),
('PDU-01','power_unit','B1',32.00,false)
ON CONFLICT (asset_key) DO NOTHING;

INSERT INTO access_control(username, password_hash, role_name, active, session_token) VALUES
('admin', 'HASHED_ADMIN_PASSWORD', 'ADMIN', true, 'TOKEN-ADMIN-001'),
('operator', 'HASHED_OPERATOR_PASSWORD', 'OPERATOR', true, 'TOKEN-OPER-001')
ON CONFLICT (username) DO NOTHING;