-- Create Concrete Login Users for Testing & Video Presentation
CREATE USER dr_house WITH PASSWORD 'pass_doctor' IN ROLE role_doctor;
CREATE USER dr_wilson WITH PASSWORD 'pass_doctor' IN ROLE role_doctor;
CREATE USER nurse_joy WITH PASSWORD 'pass_nurse' IN ROLE role_nurse;
CREATE USER recep_pam WITH PASSWORD 'pass_recep' IN ROLE role_receptionist;
CREATE USER pat_alice WITH PASSWORD 'pass_patient' IN ROLE role_patient;
CREATE USER pat_bob WITH PASSWORD 'pass_patient' IN ROLE role_patient;
CREATE USER svc_billing WITH PASSWORD 'pass_billing' IN ROLE role_billing_service;
CREATE USER aud_smith WITH PASSWORD 'pass_auditor' IN ROLE role_auditor;
CREATE USER adm_root WITH PASSWORD 'pass_admin' IN ROLE role_admin;

-- Insert Sample Doctors
INSERT INTO Doctor (db_username, name, specialty) VALUES
('dr_house', 'Dr. Gregory House', 'Diagnostic Medicine'),
('dr_wilson', 'Dr. James Wilson', 'Oncology');

-- Insert Sample Patients
INSERT INTO Patient (db_username, name, date_of_birth, phone, email, billing_address) VALUES
('pat_alice', 'Alice Martin', '1995-04-12', '+352 621 111 222', 'alice@example.lu', '12 Avenue de la Gare, Luxembourg'),
('pat_bob', 'Bob Schmit', '1988-11-23', '+352 621 333 444', 'bob@example.lu', '45 Boulevard Royal, Luxembourg');

-- Insert Sample Appointments
INSERT INTO Appointment (patient_id, staff_id, date_time, status) VALUES
(1, 1, '2026-11-05 09:30:00+01', 'completed'), -- Alice with Dr. House (completed)
(2, 2, '2026-11-10 14:00:00+01', 'scheduled'); -- Bob with Dr. Wilson (scheduled)

-- Insert Sample Medical Records (Encrypted using pgcrypto)
INSERT INTO MedicalRecord (appointment_id, diagnosis, notes, vital_signs) VALUES
(
    1,
    pgp_sym_encrypt('Lupus ruled out; mild viral hypertension', 'dev_master_encryption_key_2026'),
    pgp_sym_encrypt('Patient reported fatigue. Follow up in 2 weeks.', 'dev_master_encryption_key_2026'),
    '{"bp": "135/85", "heart_rate": 78, "temp_c": 37.1}'::JSONB
);

-- Insert Sample Prescription (Weak Entity: record_id = 1, line_no = 1)
INSERT INTO Prescription (record_id, line_no, medication, dosage, duration) VALUES
(1, 1, 'Ibuprofen', '400mg', '5 days');

-- Insert Sample Invoice
INSERT INTO Invoice (appointment_id, amount, status, issued_on) VALUES
(1, 85.00, 'unpaid', '2026-11-05');