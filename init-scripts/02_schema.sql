-- 1. Patient Table
CREATE TABLE Patient (
    patient_id SERIAL PRIMARY KEY,
    db_username VARCHAR(64) UNIQUE, -- Maps to PostgreSQL role/user for RLS
    name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    phone VARCHAR(30),
    email VARCHAR(100) UNIQUE,
    billing_address TEXT
);

-- 2. Doctor Table
CREATE TABLE Doctor (
    staff_id SERIAL PRIMARY KEY,
    db_username VARCHAR(64) UNIQUE, -- Maps to PostgreSQL role/user for RLS
    name VARCHAR(100) NOT NULL,
    specialty VARCHAR(100) NOT NULL
);

-- 3. Appointment Table
CREATE TABLE Appointment (
    appointment_id SERIAL PRIMARY KEY,
    patient_id INT NOT NULL REFERENCES Patient(patient_id) ON DELETE CASCADE,
    staff_id INT NOT NULL REFERENCES Doctor(staff_id) ON DELETE RESTRICT,
    date_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'completed', 'cancelled'))
);

-- 4. MedicalRecord Table (1:0..1 with Appointment)
-- Note: diagnosis and notes are stored encrypted via pgcrypto (BYTEA)
CREATE TABLE MedicalRecord (
    record_id SERIAL PRIMARY KEY,
    appointment_id INT NOT NULL UNIQUE REFERENCES Appointment(appointment_id) ON DELETE CASCADE,
    diagnosis BYTEA,      -- Encrypted using pgp_sym_encrypt
    notes BYTEA,          -- Encrypted using pgp_sym_encrypt
    vital_signs JSONB,    -- Nurses can read/write vitals without seeing diagnosis
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Prescription Table (Weak Entity: PK is record_id + line_no)
CREATE TABLE Prescription (
    record_id INT NOT NULL REFERENCES MedicalRecord(record_id) ON DELETE CASCADE,
    line_no INT NOT NULL,
    medication VARCHAR(120) NOT NULL,
    dosage VARCHAR(80) NOT NULL,
    duration VARCHAR(80) NOT NULL,
    PRIMARY KEY (record_id, line_no)
);

-- 6. Invoice Table (1:0..1 with Appointment)
CREATE TABLE Invoice (
    invoice_id SERIAL PRIMARY KEY,
    appointment_id INT NOT NULL UNIQUE REFERENCES Appointment(appointment_id) ON DELETE RESTRICT,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'unpaid'
        CHECK (status IN ('unpaid', 'paid', 'void')),
    issued_on DATE NOT NULL DEFAULT CURRENT_DATE
);

-- 7. AuditLog Table (Standalone, populated strictly by triggers)
CREATE TABLE AuditLog (
    log_id SERIAL PRIMARY KEY,
    db_user VARCHAR(64) NOT NULL,
    action VARCHAR(10) NOT NULL,
    object_name VARCHAR(64) NOT NULL,
    logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    prev_hash VARCHAR(64) NOT NULL,
    curr_hash VARCHAR(64) NOT NULL
);