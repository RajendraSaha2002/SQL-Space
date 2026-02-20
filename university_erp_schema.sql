-- =============================================
-- FULL UNIVERSITY ERP DATABASE SETUP
-- Run this ONCE to fix all missing table errors
-- =============================================

-- 1. CLEANUP (Drop everything to start fresh)
DROP VIEW IF EXISTS v_student_performance CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS fees CASCADE;
DROP TABLE IF EXISTS marks CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- 2. CREATE TABLES
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(20) UNIQUE
);

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    role_id INT REFERENCES roles(role_id),
    email VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_code VARCHAR(20) UNIQUE,
    course_name VARCHAR(100),
    credits INT,
    faculty_id INT REFERENCES users(user_id)
);

CREATE TABLE enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES users(user_id),
    course_id INT REFERENCES courses(course_id),
    semester INT,
    UNIQUE(student_id, course_id)
);

CREATE TABLE marks (
    mark_id SERIAL PRIMARY KEY,
    enrollment_id INT REFERENCES enrollments(enrollment_id),
    exam_type VARCHAR(20),
    score DECIMAL(5, 2),
    max_score INT DEFAULT 100
);

CREATE TABLE attendance (
    attendance_id BIGSERIAL PRIMARY KEY,
    enrollment_id INT REFERENCES enrollments(enrollment_id),
    date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(10) CHECK (status IN ('Present', 'Absent', 'Late'))
);

CREATE TABLE fees (
    fee_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES users(user_id),
    amount DECIMAL(10, 2),
    due_date DATE,
    status VARCHAR(20) DEFAULT 'Pending'
);

CREATE TABLE messages (
    msg_id BIGSERIAL PRIMARY KEY,
    sender_id INT REFERENCES users(user_id),
    receiver_id INT REFERENCES users(user_id),
    subject VARCHAR(200),
    body TEXT,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE
);

-- 3. INSERT DATA
INSERT INTO roles (role_name) VALUES ('Admin'), ('Faculty'), ('Student');

INSERT INTO users (username, password_hash, full_name, role_id) VALUES
('admin', 'admin123', 'System Administrator', 1),
('prof_smith', 'pass123', 'Prof. John Smith', 2),
('student_jane', 'pass123', 'Jane Doe', 3),
('student_bob', 'pass123', 'Bob Wilson', 3);

INSERT INTO courses (course_code, course_name, credits, faculty_id) VALUES
('CS101', 'Intro to Computer Science', 4, 2),
('MATH202', 'Linear Algebra', 3, 2);

INSERT INTO enrollments (student_id, course_id, semester) VALUES
(3, 1, 1), (3, 2, 1), 
(4, 1, 1);

INSERT INTO marks (enrollment_id, exam_type, score) VALUES
(1, 'Midterm', 85.5), (1, 'Final', 92.0),
(2, 'Midterm', 78.0),
(3, 'Midterm', 45.0);

-- Insert dummy attendance for the view to work
INSERT INTO attendance (enrollment_id, status) VALUES 
(1, 'Present'), (1, 'Present'), (1, 'Absent'),
(2, 'Present');

INSERT INTO fees (student_id, amount, due_date, status) VALUES 
(3, 5000.00, '2024-12-31', 'Pending');

-- 4. CREATE THE MISSING VIEW
CREATE OR REPLACE VIEW v_student_performance AS
SELECT 
    u.full_name as student_name,
    c.course_name,
    AVG(m.score) as avg_score,
    (
        SELECT COUNT(*) FROM attendance a 
        JOIN enrollments e2 ON a.enrollment_id = e2.enrollment_id 
        WHERE e2.student_id = u.user_id AND e2.course_id = c.course_id AND a.status = 'Present'
    ) as classes_attended
FROM users u
JOIN enrollments e ON u.user_id = e.student_id
JOIN courses c ON e.course_id = c.course_id
LEFT JOIN marks m ON e.enrollment_id = m.enrollment_id
WHERE u.role_id = 3 -- Student Role
GROUP BY u.full_name, c.course_name, u.user_id, c.course_id;