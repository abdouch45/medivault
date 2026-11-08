-- Trigger function running with SECURITY DEFINER so users cannot write to AuditLog directly
CREATE OR REPLACE FUNCTION fn_log_audit_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_prev_hash VARCHAR(64);
    v_curr_hash VARCHAR(64);
    v_ts TIMESTAMPTZ := clock_timestamp();
BEGIN
    -- Lock table in Exclusive mode briefly to ensure strict serial ordering of the hash chain
    LOCK TABLE AuditLog IN EXCLUSIVE MODE;

    SELECT curr_hash INTO v_prev_hash
    FROM AuditLog
    ORDER BY log_id DESC
    LIMIT 1;

    IF v_prev_hash IS NULL THEN
        v_prev_hash := repeat('0', 64); -- Genesis hash
    END IF;

    v_curr_hash := encode(
        digest(
            session_user || '|' || TG_OP || '|' || TG_TABLE_NAME || '|' || v_ts::TEXT || '|' || v_prev_hash,
            'sha256'
        ),
        'hex'
    );

    INSERT INTO AuditLog (db_user, action, object_name, logged_at, prev_hash, curr_hash)
    VALUES (session_user, TG_OP, TG_TABLE_NAME, v_ts, v_prev_hash, v_curr_hash);

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

-- Attach audit triggers to all 6 operational tables
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY['patient', 'doctor', 'appointment', 'medicalrecord', 'prescription', 'invoice']
    LOOP
        EXECUTE format('
            CREATE TRIGGER trg_audit_%I
            AFTER INSERT OR UPDATE OR DELETE ON %I
            FOR EACH ROW EXECUTE FUNCTION fn_log_audit_event();
        ', t, t);
    END LOOP;
END;
$$;

-- Integrity Verification Function for the Auditor
CREATE OR REPLACE FUNCTION verify_audit_log_integrity()
RETURNS TABLE(is_valid BOOLEAN, broken_at_log_id INT, details TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rec RECORD;
    expected_prev VARCHAR(64) := repeat('0', 64);
    recalculated_curr VARCHAR(64);
BEGIN
    FOR rec IN SELECT * FROM AuditLog ORDER BY log_id ASC LOOP
        IF rec.prev_hash <> expected_prev THEN
            RETURN QUERY SELECT FALSE, rec.log_id, 'Chain broken: prev_hash mismatch (possible deletion or modification)';
            RETURN;
        END IF;

        recalculated_curr := encode(
            digest(
                rec.db_user || '|' || rec.action || '|' || rec.object_name || '|' || rec.logged_at::TEXT || '|' || rec.prev_hash,
                'sha256'
            ),
            'hex'
        );

        IF rec.curr_hash <> recalculated_curr THEN
            RETURN QUERY SELECT FALSE, rec.log_id, 'Tampering detected: curr_hash does not match record payload';
            RETURN;
        END IF;

        expected_prev := rec.curr_hash;
    END LOOP;

    RETURN QUERY SELECT TRUE, NULL::INT, 'All audit log entries verified intact.';
END;
$$;