ALTER TABLE Patient ENABLE ROW LEVEL SECURITY;
ALTER TABLE Doctor ENABLE ROW LEVEL SECURITY;
ALTER TABLE Appointment ENABLE ROW LEVEL SECURITY;
ALTER TABLE MedicalRecord ENABLE ROW LEVEL SECURITY;
ALTER TABLE Prescription ENABLE ROW LEVEL SECURITY;
ALTER TABLE Invoice ENABLE ROW LEVEL SECURITY;

-- ================= PATIENT RLS =================
-- Patients see/update only their own row
CREATE POLICY patient_self_policy ON Patient
    FOR ALL TO role_patient
    USING (db_username = session_user)
    WITH CHECK (db_username = session_user);

-- Doctors see only patients who have an appointment with them
CREATE POLICY patient_doctor_policy ON Patient
    FOR SELECT TO role_doctor
    USING (
        patient_id IN (
            SELECT a.patient_id FROM Appointment a
            JOIN Doctor d ON a.staff_id = d.staff_id
            WHERE d.db_username = session_user
        )
    );

-- Nurses, Receptionists, Billing Service, and Admin see all patient rows (filtered by column grants)
CREATE POLICY patient_staff_policy ON Patient
    FOR ALL TO role_nurse, role_receptionist, role_billing_service, role_admin
    USING (TRUE) WITH CHECK (TRUE);

-- ================= DOCTOR RLS =================
CREATE POLICY doctor_read_all ON Doctor
    FOR SELECT TO role_doctor, role_nurse, role_receptionist, role_patient, role_admin
    USING (TRUE);

CREATE POLICY doctor_update_self ON Doctor
    FOR UPDATE TO role_doctor
    USING (db_username = session_user)
    WITH CHECK (db_username = session_user);

CREATE POLICY doctor_admin_manage ON Doctor
    FOR ALL TO role_admin
    USING (TRUE) WITH CHECK (TRUE);

-- ================= APPOINTMENT RLS =================
-- Doctors see/update only their own appointments
CREATE POLICY appt_doctor_policy ON Appointment
    FOR ALL TO role_doctor
    USING (staff_id IN (SELECT staff_id FROM Doctor WHERE db_username = session_user))
    WITH CHECK (staff_id IN (SELECT staff_id FROM Doctor WHERE db_username = session_user));

-- Patients see/create only their own appointments
CREATE POLICY appt_patient_policy ON Appointment
    FOR ALL TO role_patient
    USING (patient_id IN (SELECT patient_id FROM Patient WHERE db_username = session_user))
    WITH CHECK (patient_id IN (SELECT patient_id FROM Patient WHERE db_username = session_user));

-- Billing Service sees ONLY completed appointments
CREATE POLICY appt_billing_completed_only ON Appointment
    FOR SELECT TO role_billing_service
    USING (status = 'completed');

-- Nurses, Receptionists, Admin see all appointments
CREATE POLICY appt_staff_all ON Appointment
    FOR ALL TO role_nurse, role_receptionist, role_admin
    USING (TRUE) WITH CHECK (TRUE);

-- ================= MEDICAL RECORD RLS =================
-- Doctors access records for their own appointments
CREATE POLICY medrec_doctor_policy ON MedicalRecord
    FOR ALL TO role_doctor
    USING (
        appointment_id IN (
            SELECT a.appointment_id FROM Appointment a
            JOIN Doctor d ON a.staff_id = d.staff_id
            WHERE d.db_username = session_user
        )
    )
    WITH CHECK (
        appointment_id IN (
            SELECT a.appointment_id FROM Appointment a
            JOIN Doctor d ON a.staff_id = d.staff_id
            WHERE d.db_username = session_user
        )
    );

-- Patients read only their own medical records
CREATE POLICY medrec_patient_policy ON MedicalRecord
    FOR SELECT TO role_patient
    USING (
        appointment_id IN (
            SELECT a.appointment_id FROM Appointment a
            JOIN Patient p ON a.patient_id = p.patient_id
            WHERE p.db_username = session_user
        )
    );

-- Nurses can view/insert vitals across clinic appointments
CREATE POLICY medrec_nurse_policy ON MedicalRecord
    FOR ALL TO role_nurse
    USING (TRUE) WITH CHECK (TRUE);

-- ================= PRESCRIPTION RLS =================
CREATE POLICY presc_doctor_policy ON Prescription
    FOR ALL TO role_doctor
    USING (
        record_id IN (
            SELECT mr.record_id FROM MedicalRecord mr
            JOIN Appointment a ON mr.appointment_id = a.appointment_id
            JOIN Doctor d ON a.staff_id = d.staff_id
            WHERE d.db_username = session_user
        )
    );

CREATE POLICY presc_patient_policy ON Prescription
    FOR SELECT TO role_patient
    USING (
        record_id IN (
            SELECT mr.record_id FROM MedicalRecord mr
            JOIN Appointment a ON mr.appointment_id = a.appointment_id
            JOIN Patient p ON a.patient_id = p.patient_id
            WHERE p.db_username = session_user
        )
    );

CREATE POLICY presc_nurse_policy ON Prescription
    FOR SELECT TO role_nurse
    USING (TRUE);

-- ================= INVOICE RLS =================
CREATE POLICY invoice_patient_policy ON Invoice
    FOR SELECT TO role_patient
    USING (
        appointment_id IN (
            SELECT a.appointment_id FROM Appointment a
            JOIN Patient p ON a.patient_id = p.patient_id
            WHERE p.db_username = session_user
        )
    );

CREATE POLICY invoice_staff_policy ON Invoice
    FOR ALL TO role_receptionist, role_billing_service, role_auditor
    USING (TRUE) WITH CHECK (TRUE);