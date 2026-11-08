#!/usr/bin/env bash
# Generates config/pg_hba.conf from the template, substituting TRUSTED_IP from .env
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
TEMPLATE="$ROOT/config/pg_hba.conf.template"
OUTPUT="$ROOT/config/pg_hba.conf"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env not found. Run: node scripts/generate-passwords.js" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

if [[ -z "${TRUSTED_IP:-}" ]]; then
  echo "Error: TRUSTED_IP is not set in .env" >&2
  exit 1
fi

mkdir -p "$ROOT/config"
sed "s/TRUSTED_IP_HERE/${TRUSTED_IP}/g" "$TEMPLATE" > "$OUTPUT"
echo "Generated config/pg_hba.conf  (TRUSTED_IP=${TRUSTED_IP})"
echo "Now run: docker-compose up -d"
