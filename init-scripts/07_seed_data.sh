#!/usr/bin/env bash
# Seed data using MEDIVAULT_ENC_KEY from the environment (set in docker-compose.yml → .env)
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	INSERT INTO Doctor (db_username, name, specialty) VALUES
	('dr_house',  'Dr. Gregory House', 'Diagnostic Medicine'),
	('dr_wilson', 'Dr. James Wilson',  'Oncology');

	INSERT INTO Patient (db_username, name, date_of_birth, phone, email, billing_address) VALUES
	('pat_alice', 'Alice Martin', '1995-04-12', '+352 621 111 222', 'alice@example.lu', '12 Avenue de la Gare, Luxembourg'),
	('pat_bob',   'Bob Schmit',   '1988-11-23', '+352 621 333 444', 'bob@example.lu',   '45 Boulevard Royal, Luxembourg');

	INSERT INTO Appointment (patient_id, staff_id, date_time, status) VALUES
	(1, 1, '2026-11-05 09:30:00+01', 'completed'),
	(2, 2, '2026-11-10 14:00:00+01', 'scheduled');

	INSERT INTO MedicalRecord (appointment_id, diagnosis, notes, vital_signs) VALUES
	(
	    1,
	    pgp_sym_encrypt('Lupus ruled out; mild viral hypertension',    '${MEDIVAULT_ENC_KEY}'),
	    pgp_sym_encrypt('Patient reported fatigue. Follow up in 2 weeks.', '${MEDIVAULT_ENC_KEY}'),
	    '{"bp": "135/85", "heart_rate": 78, "temp_c": 37.1}'::JSONB
	);

	INSERT INTO Prescription (record_id, line_no, medication, dosage, duration) VALUES
	(1, 1, 'Ibuprofen', '400mg', '5 days');

	INSERT INTO Invoice (appointment_id, amount, status, issued_on) VALUES
	(1, 85.00, 'unpaid', '2026-11-05');
EOSQL
