-- Enable pgcrypto for column-level encryption and SHA-256 hash chaining
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- pgaudit: statement-level audit logging (preloaded via config/postgresql.conf)
CREATE EXTENSION IF NOT EXISTS pgaudit;
