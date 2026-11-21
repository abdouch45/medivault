-- Makes the audit trail append-only and hard to switch off.
-- Ceiling: a superuser can still ALTER EVENT TRIGGER ... DISABLE first. That statement is itself
-- recorded by pgaudit, shipped off-box, and any chain rewrite is caught by the Garage anchors
-- (verify-audit.sh). Inside one Postgres instance nothing can fully stop a superuser.

-- 1. No UPDATE / DELETE / TRUNCATE on AuditLog for anyone, table owner included.
CREATE OR REPLACE FUNCTION fn_auditlog_append_only()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'AuditLog is append-only: % denied for %', TG_OP, session_user;
END;
$$;

CREATE TRIGGER trg_auditlog_no_modify
    BEFORE UPDATE OR DELETE ON AuditLog FOR EACH ROW EXECUTE FUNCTION fn_auditlog_append_only();
CREATE TRIGGER trg_auditlog_no_truncate
    BEFORE TRUNCATE ON AuditLog FOR EACH STATEMENT EXECUTE FUNCTION fn_auditlog_append_only();

REVOKE UPDATE, DELETE, TRUNCATE ON AuditLog FROM PUBLIC;

-- 2. ENABLE ALWAYS: triggers keep firing under SET session_replication_role = replica
--    (the classic way to silence triggers without DDL).
ALTER TABLE AuditLog ENABLE ALWAYS TRIGGER trg_auditlog_no_modify;
ALTER TABLE AuditLog ENABLE ALWAYS TRIGGER trg_auditlog_no_truncate;
DO $$
DECLARE t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY['patient', 'doctor', 'appointment', 'medicalrecord', 'prescription', 'invoice']
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ALWAYS TRIGGER %I', t, 'trg_audit_' || t);
    END LOOP;
END;
$$;

-- 3. Event triggers: block DDL that would alter, disable or drop the audit machinery.
CREATE OR REPLACE FUNCTION fn_protect_audit_objects()
RETURNS event_trigger LANGUAGE plpgsql AS $$
DECLARE
    r RECORD;
    protected CONSTANT TEXT := 'auditlog|fn_log_audit_event|verify_audit_log_integrity|fn_protect_audit_objects';
BEGIN
    IF TG_EVENT = 'sql_drop' THEN
        FOR r IN SELECT object_identity FROM pg_event_trigger_dropped_objects() LOOP
            IF r.object_identity ~* (protected || '|trg_audit') THEN
                RAISE EXCEPTION 'Audit object is protected: DROP of % denied', r.object_identity;
            END IF;
        END LOOP;
    ELSE
        FOR r IN SELECT object_identity FROM pg_event_trigger_ddl_commands() LOOP
            IF r.object_identity ~* protected THEN
                RAISE EXCEPTION 'Audit object is protected: % on % denied', TG_TAG, r.object_identity;
            END IF;
        END LOOP;
        -- Catches ALTER TABLE patient DISABLE TRIGGER trg_audit_patient (identity is just "public.patient").
        IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname LIKE 'trg_audit%' AND tgenabled <> 'A') THEN
            RAISE EXCEPTION 'Audit triggers must stay ENABLE ALWAYS: % denied', TG_TAG;
        END IF;
    END IF;
END;
$$;

CREATE EVENT TRIGGER evt_protect_audit_ddl  ON ddl_command_end EXECUTE FUNCTION fn_protect_audit_objects();
CREATE EVENT TRIGGER evt_protect_audit_drop ON sql_drop        EXECUTE FUNCTION fn_protect_audit_objects();
ALTER EVENT TRIGGER evt_protect_audit_ddl  ENABLE ALWAYS;
ALTER EVENT TRIGGER evt_protect_audit_drop ENABLE ALWAYS;
