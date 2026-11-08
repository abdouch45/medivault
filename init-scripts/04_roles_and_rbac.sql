-- Revoke default public permissions
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO PUBLIC;

-- Create the 7 Actor Group Roles
CREATE ROLE role_doctor NOLOGIN;
CREATE ROLE role_nurse NOLOGIN;
CREATE ROLE role_receptionist NOLOGIN;
CREATE ROLE role_patient NOLOGIN;
CREATE ROLE role_billing_service NOLOGIN;
CREATE ROLE role_auditor NOLOGIN;
CREATE ROLE role_admin NOLOGIN;

-- 1. DOCTOR Permissions
-- billing_address excluded: doctors need patient identity, not billing data
GRANT SELECT (patient_id, name, date_of_birth, phone) ON Patient TO role_doctor;
GRANT SELECT, UPDATE (name, specialty) ON Doctor TO role_doctor;
GRANT SELECT, UPDATE (status) ON Appointment TO role_doctor;
GRANT SELECT, INSERT, UPDATE ON MedicalRecord TO role_doctor;
GRANT USAGE, SELECT ON SEQUENCE medicalrecord_record_id_seq TO role_doctor;
GRANT SELECT, INSERT, UPDATE ON Prescription TO role_doctor;

-- 2. NURSE Permissions
GRANT SELECT ON Patient, Doctor, Appointment, Prescription TO role_nurse;
GRANT SELECT (record_id, appointment_id, vital_signs, created_at),
      INSERT (appointment_id, vital_signs),
      UPDATE (vital_signs) ON MedicalRecord TO role_nurse;
GRANT USAGE, SELECT ON SEQUENCE medicalrecord_record_id_seq TO role_nurse;

-- 3. RECEPTIONIST Permissions
GRANT SELECT (patient_id, name, date_of_birth, phone, email, billing_address),
      INSERT (name, date_of_birth, phone, email, billing_address, db_username),
      UPDATE (name, date_of_birth, phone, email, billing_address) ON Patient TO role_receptionist;
GRANT USAGE, SELECT ON SEQUENCE patient_patient_id_seq TO role_receptionist;
GRANT SELECT (staff_id, name, specialty) ON Doctor TO role_receptionist;
-- DELETE removed: cancellation is an UPDATE (status='cancelled'), not a hard delete
GRANT SELECT, INSERT, UPDATE ON Appointment TO role_receptionist;
GRANT USAGE, SELECT ON SEQUENCE appointment_appointment_id_seq TO role_receptionist;
GRANT SELECT ON Invoice TO role_receptionist;

-- 4. PATIENT Permissions
GRANT SELECT, UPDATE (phone, email, billing_address) ON Patient TO role_patient;
GRANT SELECT (staff_id, name, specialty) ON Doctor TO role_patient;
GRANT SELECT, INSERT ON Appointment TO role_patient;
GRANT USAGE, SELECT ON SEQUENCE appointment_appointment_id_seq TO role_patient;
GRANT SELECT ON MedicalRecord, Prescription, Invoice TO role_patient;

-- 5. BILLING SERVICE Permissions (Strict Column-Level Access)
GRANT SELECT (patient_id, name, billing_address) ON Patient TO role_billing_service;
GRANT SELECT ON Appointment TO role_billing_service;
GRANT SELECT, INSERT, UPDATE ON Invoice TO role_billing_service;
GRANT USAGE, SELECT ON SEQUENCE invoice_invoice_id_seq TO role_billing_service;

-- 6. AUDITOR Permissions
GRANT SELECT ON Invoice, AuditLog TO role_auditor;
REVOKE ALL ON FUNCTION verify_audit_log_integrity() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION verify_audit_log_integrity() TO role_auditor;

-- 7. ADMIN Permissions (Contact data on Patient, full staff accounts, read Appointments)
GRANT SELECT (patient_id, name, phone, email, billing_address),
      UPDATE (phone, email, billing_address) ON Patient TO role_admin;
GRANT SELECT, INSERT, UPDATE ON Doctor TO role_admin;
GRANT USAGE, SELECT ON SEQUENCE doctor_staff_id_seq TO role_admin;
GRANT SELECT ON Appointment TO role_admin;