

-- 1. Medical Devices Registry
CREATE TABLE IF NOT EXISTS medical_devices (
    device_uuid VARCHAR(50) PRIMARY KEY,
    device_type VARCHAR(50), -- 'Pacemaker', 'Insulin_Pump'
    patient_name VARCHAR(100),
    
    -- The critical field. We store it as VARCHAR to allow "Encryption" (text injection)
    -- In a real secure system, this would be strictly numeric to prevent this exact attack.
    config_value VARCHAR(50) DEFAULT '75', 
    
    status_message VARCHAR(100) DEFAULT 'OPERATIONAL',
    last_ping TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Seed Data
-- Patient Zero: John Doe with a connected Pacemaker
INSERT INTO medical_devices (device_uuid, device_type, patient_name, config_value) 
VALUES ('PM-001', 'Pacemaker', 'John Doe', '75');

-- Patient One: Jane Smith with an Insulin Pump
INSERT INTO medical_devices (device_uuid, device_type, patient_name, config_value) 
VALUES ('IP-002', 'Insulin_Pump', 'Jane Smith', '0.5');