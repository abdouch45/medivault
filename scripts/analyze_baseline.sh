#!/usr/bin/env bash
echo "=== 1. Default Authentication Rules (pg_hba.conf) ==="
docker exec medivault_postgres sh -c "grep -v '^#' /var/lib/postgresql/data/pg_hba.conf | grep -v '^$'"

echo -e "\n=== 2. Default Security & Logging Parameters ==="
docker exec medivault_postgres psql -U postgres -d medivault -c "
SELECT name, setting, short_desc
FROM pg_settings
WHERE name IN (
    'ssl',
    'password_encryption',
    'log_connections',
    'log_disconnections',
    'log_statement',
    'row_security',
    'listen_addresses'
);"