CREATE DATABASE companydb;
USE companydb;

CREATE TABLE employees (
    emp_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    department VARCHAR(40),
    salary INT
);

INSERT INTO employees (name, department, salary) VALUES
('Rahul', 'IT', 45000),
('Neha', 'HR', 40000),
('Amit', 'IT', 50000),
('Pooja', 'Finance', 55000);

SELECT * FROM employees;
