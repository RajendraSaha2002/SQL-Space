-- 1. CLEANUP
DROP TABLE IF EXISTS exam_results CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- 2. SCHEMA DEFINITION

CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE,
    dean_name VARCHAR(100)
);

CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    dept_id INT REFERENCES departments(dept_id),
    current_gpa DECIMAL(3, 2) DEFAULT 0.00, -- Updated via Trigger
    enrollment_year INT
);

CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    credits INT,
    dept_id INT REFERENCES departments(dept_id)
);

CREATE TABLE enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(student_id),
    course_id INT REFERENCES courses(course_id),
    semester INT
);

CREATE TABLE attendance (
    record_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(student_id),
    course_id INT REFERENCES courses(course_id),
    total_classes INT,
    attended_classes INT,
    attendance_pct DECIMAL(5,2) GENERATED ALWAYS AS ((attended_classes::decimal / total_classes::decimal) * 100) STORED
);

CREATE TABLE exam_results (
    result_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(student_id),
    course_id INT REFERENCES courses(course_id),
    score DECIMAL(5, 2), -- Out of 100
    grade_point DECIMAL(3, 1) -- 4.0 scale
);

-- 3. ADVANCED LOGIC: AUTO-GPA TRIGGER
-- Whenever a new exam result is added, recalculate the student's GPA automatically.
CREATE OR REPLACE FUNCTION update_student_gpa()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE students
    SET current_gpa = (
        SELECT AVG(grade_point)
        FROM exam_results
        WHERE student_id = NEW.student_id
    )
    WHERE student_id = NEW.student_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalc_gpa
AFTER INSERT OR UPDATE ON exam_results
FOR EACH ROW
EXECUTE FUNCTION update_student_gpa();

-- 4. ANALYTIC STORED PROCEDURE
-- Calculate department ranking based on average GPA
CREATE OR REPLACE VIEW v_dept_performance AS
SELECT 
    d.name as department,
    COUNT(s.student_id) as student_count,
    ROUND(AVG(s.current_gpa), 2) as avg_dept_gpa
FROM departments d
JOIN students s ON d.dept_id = s.dept_id
GROUP BY d.name
ORDER BY avg_dept_gpa DESC;

-- 5. DATA GENERATION (SEEDING)
INSERT INTO departments (name) VALUES ('Computer Science'), ('Electrical Eng'), ('Business Admin');

INSERT INTO courses (name, credits, dept_id) VALUES 
('Data Structures', 4, 1), ('Algorithms', 4, 1), ('Database Systems', 3, 1),
('Circuit Analysis', 4, 2), ('Signals & Systems', 3, 2),
('Microeconomics', 3, 3), ('Marketing 101', 3, 3);

-- Generate 60 Students with varied performance
DO $$
DECLARE
    s_id INT;
    d_id INT;
    base_score INT;
    attend_pct DECIMAL;
BEGIN
    FOR i IN 1..60 LOOP
        d_id := floor(random() * 3 + 1);
        
        INSERT INTO students (first_name, last_name, dept_id, enrollment_year)
        VALUES ('Student', i::text, d_id, 2023)
        RETURNING student_id INTO s_id;

        -- Create Enrollments & Results for 3 courses per student
        -- Logic: We simulate that random students are "High Performers" vs "Strugglers"
        base_score := floor(random() * 50 + 40); -- Random base between 40 and 90
        
        FOR c IN 1..3 LOOP
            -- Add Exam Result (Trigger will calc GPA)
            INSERT INTO exam_results (student_id, course_id, score, grade_point)
            VALUES (
                s_id, 
                (SELECT course_id FROM courses WHERE dept_id = d_id ORDER BY random() LIMIT 1),
                base_score + (random() * 10), -- Score variation
                (base_score / 25.0) -- Rough conversion to 4.0 scale
            );
            
            -- Add Attendance (Correlated with score for realism)
            -- Higher score = Higher attendance usually
            attend_pct := CASE 
                WHEN base_score > 80 THEN 0.90 
                WHEN base_score > 60 THEN 0.75 
                ELSE 0.50 
            END;
            
            INSERT INTO attendance (student_id, course_id, total_classes, attended_classes)
            VALUES (s_id, c, 40, (40 * (attend_pct + (random()*0.1 - 0.05)))::int);
        END LOOP;
    END LOOP;
END $$;