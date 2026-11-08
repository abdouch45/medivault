#!/usr/bin/env bash
# Runs during PostgreSQL first-init (docker-entrypoint-initdb.d).
# Passwords come from env vars set in docker-compose.yml → .env.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE USER dr_house    WITH PASSWORD '${PW_DR_HOUSE}'    IN ROLE role_doctor;
  CREATE USER dr_wilson   WITH PASSWORD '${PW_DR_WILSON}'   IN ROLE role_doctor;
  CREATE USER nurse_joy   WITH PASSWORD '${PW_NURSE_JOY}'   IN ROLE role_nurse;
  CREATE USER recep_pam   WITH PASSWORD '${PW_RECEP_PAM}'   IN ROLE role_receptionist;
  CREATE USER pat_alice   WITH PASSWORD '${PW_PAT_ALICE}'   IN ROLE role_patient;
  CREATE USER pat_bob     WITH PASSWORD '${PW_PAT_BOB}'     IN ROLE role_patient;
  CREATE USER svc_billing WITH PASSWORD '${PW_SVC_BILLING}' IN ROLE role_billing_service;
  CREATE USER aud_smith   WITH PASSWORD '${PW_AUD_SMITH}'   IN ROLE role_auditor;
  CREATE USER adm_root    WITH PASSWORD '${PW_ADM_ROOT}'    IN ROLE role_admin;
EOSQL
