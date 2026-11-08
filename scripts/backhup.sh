#!/usr/bin/env bash
set -e
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="./backups/medivault_${TIMESTAMP}.dump.enc"
mkdir -p ./backups

echo "[*] Creating encrypted backup: ${BACKUP_FILE}"
docker exec medivault_postgres pg_dump -U postgres -F c medivault \
  | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"${MEDIVAULT_ENC_KEY:-dev_master_encryption_key_2026}" -out "${BACKUP_FILE}"

echo "[+] Backup complete and encrypted."