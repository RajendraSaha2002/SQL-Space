-- ==========================================
-- PostgreSQL RBAC Schema ("Protocol")
-- ==========================================

-- 1. Users Table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL -- In production, use bcrypt. Hardcoded for demo.
);

-- 2. Roles Table (Supports Inheritance via parent_role_id)
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    parent_role_id INT REFERENCES roles(id) ON DELETE SET NULL
);

-- 3. Permissions Table
CREATE TABLE permissions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

-- 4. Mapping: Users <-> Roles
CREATE TABLE user_roles (
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    role_id INT REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- 5. Mapping: Roles <-> Permissions
CREATE TABLE role_permissions (
    role_id INT REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INT REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- 6. Sessions Table (Custom Session Manager)
CREATE TABLE sessions (
    token VARCHAR(255) PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL
);

-- ==========================================
-- Insert Mock Data
-- ==========================================

-- Insert Users (Passwords are plain text 'pass123' for this raw demo)
INSERT INTO users (username, password_hash) VALUES 
('admin_alice', 'pass123'),
('editor_bob', 'pass123'),
('viewer_charlie', 'pass123');

-- Insert Permissions
INSERT INTO permissions (name) VALUES
('view_dashboard'),
('edit_content'),
('delete_content'),
('admin_view'); -- Target from your request

-- Insert Roles (with inheritance)
INSERT INTO roles (id, name, parent_role_id) VALUES
(1, 'Viewer', NULL),               -- Base role
(2, 'Editor', 1),                  -- Inherits from Viewer
(3, 'Admin', 2);                   -- Inherits from Editor

-- Insert Role Permissions (Assigned to explicit roles)
INSERT INTO role_permissions (role_id, permission_id) VALUES
(1, 1), -- Viewer -> view_dashboard
(2, 2), -- Editor -> edit_content
(3, 3), -- Admin -> delete_content
(3, 4); -- Admin -> admin_view

-- Insert User Roles
INSERT INTO user_roles (user_id, role_id) VALUES
(1, 3), -- Alice is Admin
(2, 2), -- Bob is Editor
(3, 1); -- Charlie is Viewer

-- ==========================================
-- Recursive CTE for the Python Backend to execute
-- Example Query (used in Python code below)
-- ==========================================
/*
WITH RECURSIVE RoleHierarchy AS (
    -- Anchor member: Direct roles assigned to the user
    SELECT r.id, r.name, r.parent_role_id
    FROM roles r
    JOIN user_roles ur ON r.id = ur.role_id
    WHERE ur.user_id = $1 -- Variable from Python

    UNION ALL

    -- Recursive member: Parent roles of the currently selected roles
    SELECT r.id, r.name, r.parent_role_id
    FROM roles r
    JOIN RoleHierarchy rh ON rh.parent_role_id = r.id
)
-- Finally, get unique permissions by combining the inherited roles with the role_permissions mapping.
SELECT DISTINCT p.name
FROM RoleHierarchy rh
JOIN role_permissions rp ON rh.id = rp.role_id
JOIN permissions p ON rp.permission_id = p.id;
*/