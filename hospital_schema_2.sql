CREATE TABLE patients (
    patient_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    gender VARCHAR(10),
    dob DATE,
    phone VARCHAR(20),
    email VARCHAR(100),
    address TEXT
);

CREATE TABLE doctors (
    doctor_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    specialization VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100)
);

CREATE TABLE appointments (
    appointment_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id) ON DELETE CASCADE,
    doctor_id INT REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    status VARCHAR(20) DEFAULT 'Scheduled'
);

CREATE TABLE billing (
    bill_id SERIAL PRIMARY KEY,
    appointment_id INT REFERENCES appointments(appointment_id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL,
    paid BOOLEAN DEFAULT FALSE,
    billed_date DATE DEFAULT CURRENT_DATE
);

-- Sample data
INSERT INTO patients (full_name, gender, dob, phone, email, address) VALUES
('Amit Sharma', 'Male', '1995-05-12', '900000001', 'amit@gmail.com', 'Delhi'),
('Priya Verma', 'Female', '1998-03-21', '900000002', 'priya@gmail.com', 'Mumbai');

INSERT INTO doctors (full_name, specialization, phone, email) VALUES
('Dr. Rao', 'Cardiology', '888800001', 'rao@hospital.com'),
('Dr. Mehta', 'Neurology', '888800002', 'mehta@hospital.com');

INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, status) VALUES
(1, 1, '2026-02-15', '10:00', 'Scheduled'),
(2, 2, '2026-02-16', '12:30', 'Scheduled');

INSERT INTO billing (appointment_id, amount, paid, billed_date) VALUES
(1, 1500.00, TRUE, '2026-02-15'),
(2, 2000.00, FALSE, '2026-02-16');