

-- ── 1. USERS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id            SERIAL PRIMARY KEY,
    username      VARCHAR(50)  UNIQUE NOT NULL,
    password_hash TEXT         NOT NULL,   -- pbkdf2_hmac:  salt_hex:key_hex
    email         VARCHAR(120) UNIQUE,
    full_name     VARCHAR(120),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_login    TIMESTAMPTZ
);

-- ── 2. ROLES  (self-referencing for inheritance) ─────────────────
-- parent_role_id → a role inherits ALL permissions of its parent
-- Example chain:  viewer → analyst → manager → admin → super_admin
CREATE TABLE IF NOT EXISTS roles (
    id             SERIAL      PRIMARY KEY,
    name           VARCHAR(60) UNIQUE NOT NULL,
    description    TEXT,
    parent_role_id INT         REFERENCES roles(id) ON DELETE SET NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 3. PERMISSIONS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS permissions (
    id          SERIAL       PRIMARY KEY,
    name        VARCHAR(100) UNIQUE NOT NULL,   -- e.g. 'admin_view'
    description TEXT,
    module      VARCHAR(60)  NOT NULL,          -- logical grouping
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── 4. USER ↔ ROLE  (many-to-many) ──────────────────────────────
CREATE TABLE IF NOT EXISTS user_roles (
    user_id    INT         NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    role_id    INT         NOT NULL REFERENCES roles(id)  ON DELETE CASCADE,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by INT                  REFERENCES users(id)  ON DELETE SET NULL,
    PRIMARY KEY (user_id, role_id)
);

-- ── 5. ROLE ↔ PERMISSION  (many-to-many) ────────────────────────
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id       INT NOT NULL REFERENCES roles(id)       ON DELETE CASCADE,
    permission_id INT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- ── 6. SESSIONS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
    id         SERIAL      PRIMARY KEY,
    user_id    INT         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      VARCHAR(64) UNIQUE NOT NULL,       -- secrets.token_hex(32)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    ip_address INET,
    user_agent TEXT,
    is_active  BOOLEAN     NOT NULL DEFAULT TRUE
);

-- ── 7. AUDIT LOG ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
    id         SERIAL       PRIMARY KEY,
    user_id    INT                   REFERENCES users(id) ON DELETE SET NULL,
    action     VARCHAR(100) NOT NULL,
    resource   VARCHAR(100),
    details    JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_sessions_token     ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_user      ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_active    ON sessions(is_active, expires_at);
CREATE INDEX IF NOT EXISTS idx_user_roles_user    ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role    ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_role_perms_role    ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_audit_user         ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created      ON audit_log(created_at DESC);

-- ═══════════════════════════════════════════════════════════════
-- CORE FUNCTION: get_user_permissions(p_user_id)
--
-- Uses a RECURSIVE CTE to walk the role inheritance tree.
-- For user_id = 3 (manager):
--   manager (depth 0) → analyst (depth 1) → viewer (depth 2)
-- Collects DISTINCT permissions from every role in that chain.
--
-- This single query replaces dozens of application-level joins.
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id INT)
RETURNS TABLE (
    permission_name VARCHAR(100),
    permission_desc TEXT,
    module          VARCHAR(60),
    via_role        VARCHAR(60),
    depth           INT
)
LANGUAGE sql STABLE
AS $$
WITH RECURSIVE role_tree AS (

    -- ── ANCHOR: roles directly assigned to this user ──────────
    SELECT
        r.id,
        r.name           AS role_name,
        r.parent_role_id,
        0                AS depth
    FROM   roles r
    INNER  JOIN user_roles ur ON r.id = ur.role_id
    WHERE  ur.user_id = p_user_id
      AND  EXISTS (
               SELECT 1 FROM users u
               WHERE  u.id = p_user_id AND u.is_active = TRUE
           )

    UNION ALL

    -- ── RECURSIVE: climb the parent chain ────────────────────
    SELECT
        r.id,
        r.name,
        r.parent_role_id,
        rt.depth + 1
    FROM   roles r
    INNER  JOIN role_tree rt ON r.id = rt.parent_role_id
    WHERE  rt.depth < 20        -- circuit-breaker (max inheritance depth)

)
-- Join the full role tree to its permissions
SELECT DISTINCT
    p.name          AS permission_name,
    p.description   AS permission_desc,
    p.module,
    rt.role_name    AS via_role,
    rt.depth
FROM   permissions   p
INNER  JOIN role_permissions rp ON p.id  = rp.permission_id
INNER  JOIN role_tree        rt ON rt.id = rp.role_id
ORDER  BY p.module, p.name;
$$;

-- ── Convenience wrapper: boolean permission check ────────────────
CREATE OR REPLACE FUNCTION has_permission(p_user_id INT, p_perm_name VARCHAR)
RETURNS BOOLEAN
LANGUAGE sql STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM   get_user_permissions(p_user_id)
        WHERE  permission_name = p_perm_name
    );
$$;

-- ── Convenience: all permission names as a flat array ────────────
CREATE OR REPLACE FUNCTION get_permission_names(p_user_id INT)
RETURNS TEXT[]
LANGUAGE sql STABLE
AS $$
    SELECT COALESCE(array_agg(permission_name ORDER BY permission_name), '{}')
    FROM   get_user_permissions(p_user_id);
$$;

-- ═══════════════════════════════════════════════════════════════
-- SEED: ROLES  (ordered so FK parent_role_id resolves correctly)
-- ═══════════════════════════════════════════════════════════════
INSERT INTO roles (name, description, parent_role_id) VALUES
    ('viewer',      'Read-only dashboard access', NULL)
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description, parent_role_id) VALUES
    ('analyst', 'View reports and monitor systems',
     (SELECT id FROM roles WHERE name = 'viewer'))
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description, parent_role_id) VALUES
    ('manager', 'Manage users and export reports',
     (SELECT id FROM roles WHERE name = 'analyst'))
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description, parent_role_id) VALUES
    ('admin', 'Full admin access excluding system-level ops',
     (SELECT id FROM roles WHERE name = 'manager'))
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description, parent_role_id) VALUES
    ('super_admin', 'Unrestricted — all permissions + system control',
     (SELECT id FROM roles WHERE name = 'admin'))
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- SEED: PERMISSIONS  (19 permissions across 7 modules)
-- ═══════════════════════════════════════════════════════════════
INSERT INTO permissions (name, module, description) VALUES
    -- dashboard
    ('dashboard_view',   'dashboard', 'View main dashboard page'),
    ('dashboard_edit',   'dashboard', 'Customise dashboard widgets'),
    -- users
    ('users_view',       'users',     'List and view user accounts'),
    ('users_create',     'users',     'Create new user accounts'),
    ('users_edit',       'users',     'Modify existing user accounts'),
    ('users_delete',     'users',     'Permanently delete user accounts'),
    -- roles
    ('roles_view',       'roles',     'View roles and permission assignments'),
    ('roles_create',     'roles',     'Create new roles'),
    ('roles_edit',       'roles',     'Edit role permission assignments'),
    ('roles_delete',     'roles',     'Delete roles from the system'),
    -- reports
    ('reports_view',     'reports',   'View pre-built reports'),
    ('reports_create',   'reports',   'Build custom reports'),
    ('reports_export',   'reports',   'Export reports to CSV/PDF'),
    -- settings
    ('settings_view',    'settings',  'View system configuration'),
    ('settings_edit',    'settings',  'Modify system configuration'),
    -- audit
    ('audit_view',       'audit',     'View the audit event log'),
    ('audit_export',     'audit',     'Export audit log to file'),
    -- system
    ('system_monitor',   'system',    'Monitor server and DB health'),
    ('system_admin',     'system',    'Full system administration (danger zone)')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- SEED: ROLE → PERMISSION  (own permissions per level;
--       inherited ones come from the recursive CTE at query time)
-- ═══════════════════════════════════════════════════════════════

-- viewer (depth 0 — base)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE  r.name = 'viewer'
  AND  p.name IN ('dashboard_view', 'system_monitor')
ON CONFLICT DO NOTHING;

-- analyst (depth 1 — inherits viewer)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE  r.name = 'analyst'
  AND  p.name IN ('dashboard_edit', 'reports_view')
ON CONFLICT DO NOTHING;

-- manager (depth 2 — inherits analyst+viewer)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE  r.name = 'manager'
  AND  p.name IN ('users_view', 'reports_create', 'reports_export')
ON CONFLICT DO NOTHING;

-- admin (depth 3 — inherits manager+analyst+viewer)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE  r.name = 'admin'
  AND  p.name IN (
      'users_create', 'users_edit', 'users_delete',
      'roles_view', 'roles_create', 'roles_edit',
      'settings_view', 'audit_view', 'audit_export'
  )
ON CONFLICT DO NOTHING;

-- super_admin (depth 4 — inherits everything above + these)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE  r.name = 'super_admin'
  AND  p.name IN ('roles_delete', 'settings_edit', 'system_admin')
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- VERIFICATION QUERY (run manually to confirm inheritance)
-- SELECT * FROM get_user_permissions(3);   -- manager sees 9 perms
-- SELECT has_permission(1, 'system_admin'); -- super_admin → true
-- SELECT has_permission(5, 'users_create'); -- viewer      → false
-- ═══════════════════════════════════════════════════════════════