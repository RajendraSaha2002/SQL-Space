


-- ─── 1. Assets Table ─────────────────────────────────────
--  Uses PostgreSQL's native POINT geometric type.
--  The <-> operator computes Euclidean distance natively.
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS assets (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL UNIQUE,
    asset_type  VARCHAR(20)  NOT NULL
                    CHECK (asset_type IN ('tank','drone','soldier','laptop','vehicle')),

    -- Native PostgreSQL geometric POINT type: stores (x, y)
    location    POINT        NOT NULL DEFAULT point(0, 0),

    -- Velocity for simulation (stored as separate point = (vx, vy))
    velocity    POINT        NOT NULL DEFAULT point(0, 0),

    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Spatial index using GiST for fast proximity queries
CREATE INDEX idx_assets_location ON assets USING GIST (location);

COMMENT ON COLUMN assets.location IS
    'Native PostgreSQL POINT (x, y) in local coordinate system (0–100 units)';


-- ─── 2. Geofence Polygons Table ──────────────────────────
--  Stores geofence boundaries as native PostgreSQL POLYGON type.
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS geofences (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,

    -- Native PostgreSQL POLYGON geometric type
    boundary    POLYGON      NOT NULL,

    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_geofences_boundary ON geofences USING GIST (boundary);

COMMENT ON COLUMN geofences.boundary IS
    'PostgreSQL native POLYGON: list of (x,y) vertices defining the zone';


-- ─── 3. Alerts Table ─────────────────────────────────────
--  Written by Python engine, polled by JS frontend.
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS alerts (
    id           SERIAL PRIMARY KEY,
    alert_type   VARCHAR(30)  NOT NULL
                     CHECK (alert_type IN ('PROXIMITY','GEOFENCE','SYSTEM')),
    message      TEXT         NOT NULL,
    asset_ids    JSONB        NOT NULL DEFAULT '[]',
    acknowledged BOOLEAN      NOT NULL DEFAULT FALSE,
    triggered_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_alerts_triggered ON alerts (triggered_at DESC);
CREATE INDEX idx_alerts_type      ON alerts (alert_type);


-- ─── 4. Position History ─────────────────────────────────
--  Append-only movement log for playback / audit trail.
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS position_history (
    id          BIGSERIAL    PRIMARY KEY,
    asset_id    INT          NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    location    POINT        NOT NULL,
    recorded_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_history_asset ON position_history (asset_id, recorded_at DESC);

-- Auto-log every position change via trigger
CREATE OR REPLACE FUNCTION log_position_change()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.location IS DISTINCT FROM OLD.location THEN
        INSERT INTO position_history (asset_id, location)
        VALUES (NEW.id, NEW.location);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_position
    AFTER UPDATE ON assets
    FOR EACH ROW
    EXECUTE FUNCTION log_position_change();


-- ============================================================
--  SEED DATA — Initial Asset Deployment
-- ============================================================
INSERT INTO assets (name, asset_type, location, velocity) VALUES
    ('ALPHA-1',  'tank',     point(20, 30),  point( 0.04,  0.03)),
    ('BRAVO-2',  'drone',    point(60, 20),  point(-0.05,  0.06)),
    ('CHARLIE',  'soldier',  point(50, 50),  point( 0.03, -0.04)),
    ('DELTA-4',  'laptop',   point(80, 70),  point(-0.02, -0.05)),
    ('ECHO-5',   'vehicle',  point(30, 80),  point( 0.05,  0.02));

-- Default geofence polygon (inner safe zone)
INSERT INTO geofences (name, boundary) VALUES
    ('PRIMARY_ZONE',
     polygon('((5,5),(95,5),(95,95),(5,95))')
    );


-- ============================================================
--  USEFUL QUERIES — Using PostgreSQL Geometric Operators
-- ============================================================

-- Q1: Find all assets within 10 units of the origin (0,0)
--     <-> is the native distance operator for geometric types
SELECT name, asset_type, location,
       location <-> point(0,0) AS dist_from_origin
FROM assets
WHERE location <-> point(0,0) < 10
ORDER BY dist_from_origin;


-- Q2: Find all assets within 15 units of a specific point (50,50)
SELECT name, asset_type, location,
       ROUND((location <-> point(50,50))::numeric, 2) AS distance
FROM assets
WHERE location <-> point(50,50) < 15
  AND active = TRUE
ORDER BY distance;


-- Q3: Detect "Dangerously Close" pairs using self-join + <-> operator
SELECT
    a1.name     AS asset_a,
    a2.name     AS asset_b,
    ROUND((a1.location <-> a2.location)::numeric, 2) AS distance_units
FROM assets a1
JOIN assets a2 ON a1.id < a2.id   -- avoid duplicate pairs
WHERE (a1.location <-> a2.location) < 15   -- danger radius = 15 units
  AND a1.active = TRUE
  AND a2.active = TRUE
ORDER BY distance_units ASC;


-- Q4: Check which assets are OUTSIDE the geofence polygon
--     @> = "polygon contains point"
SELECT a.name, a.asset_type, a.location
FROM assets a
CROSS JOIN geofences g
WHERE g.name = 'PRIMARY_ZONE'
  AND NOT (g.boundary @> a.location)   -- NOT inside polygon
  AND a.active = TRUE;


-- Q5: Distance matrix — all pair distances (full situational picture)
SELECT
    a1.name     AS from_asset,
    a2.name     AS to_asset,
    ROUND((a1.location <-> a2.location)::numeric, 2) AS distance,
    CASE
        WHEN (a1.location <-> a2.location) < 15 THEN 'DANGER'
        WHEN (a1.location <-> a2.location) < 30 THEN 'CAUTION'
        ELSE 'CLEAR'
    END AS status
FROM assets a1
CROSS JOIN assets a2
WHERE a1.id < a2.id
  AND a1.active = TRUE
  AND a2.active = TRUE
ORDER BY distance ASC;


-- Q6: Recent unacknowledged alerts (polled by JS frontend every 2s)
SELECT id, alert_type, message, asset_ids, triggered_at
FROM alerts
WHERE acknowledged = FALSE
  AND triggered_at > NOW() - INTERVAL '10 seconds'
ORDER BY triggered_at DESC;


-- Q7: Asset movement trail — last 20 positions for playback
SELECT ph.recorded_at,
       a.name,
       ph.location[0] AS x,
       ph.location[1] AS y
FROM position_history ph
JOIN assets a ON a.id = ph.asset_id
WHERE a.name = 'ALPHA-1'
ORDER BY ph.recorded_at DESC
LIMIT 20;


-- ============================================================
--  VIEWS
-- ============================================================

-- Tactical status view (used by the frontend polling endpoint)
CREATE OR REPLACE VIEW v_tactical_status AS
SELECT
    a.id,
    a.name,
    a.asset_type,
    a.location[0]  AS x,
    a.location[1]  AS y,
    a.velocity[0]  AS vx,
    a.velocity[1]  AS vy,
    a.updated_at,
    -- Is asset inside the primary geofence?
    (SELECT g.boundary @> a.location
     FROM geofences g WHERE g.name = 'PRIMARY_ZONE') AS in_geofence,
    -- Distance from centre of map (50, 50)
    ROUND((a.location <-> point(50,50))::numeric, 2) AS dist_from_center
FROM assets a
WHERE a.active = TRUE;

COMMENT ON VIEW v_tactical_status IS
    'Live snapshot polled by the JS frontend every 2 seconds';


-- ============================================================
--  HELPER FUNCTIONS
-- ============================================================

-- Pure SQL Euclidean distance function (mirrors Python kinematics)
CREATE OR REPLACE FUNCTION euclidean_distance(
    x1 FLOAT, y1 FLOAT, x2 FLOAT, y2 FLOAT
) RETURNS FLOAT AS $$
BEGIN
    -- d = √( (x₂−x₁)² + (y₂−y₁)² )
    RETURN SQRT(POWER(x2 - x1, 2) + POWER(y2 - y1, 2));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Usage: SELECT euclidean_distance(0,0,30,40);  → 50.0


-- Acknowledge all current alerts (operator action)
CREATE OR REPLACE PROCEDURE acknowledge_all_alerts()
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE alerts SET acknowledged = TRUE
    WHERE acknowledged = FALSE;
END;
$$;

-- Usage: CALL acknowledge_all_alerts();