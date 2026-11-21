#!/bin/sh
# Idempotent Garage bootstrap via its admin API: layout, 2 private buckets, 2 keys.
#   BACKUP_BUCKET <- key "postgres"      (pgBackRest repo: encrypted full/incr backups + WAL)
#   AUDIT_BUCKET  <- key "audit-shipper" (server/pgaudit logs + audit-chain anchors)
# No bucket is public; only the named key has access to its bucket.
set -eu
A="http://garage:3903/v1"
api() { curl -fsS -H "Authorization: Bearer $GARAGE_ADMIN_TOKEN" -H 'Content-Type: application/json' "$@"; }

until api "$A/status" >/dev/null 2>&1; do echo "[garage-init] waiting for garage..."; sleep 2; done

if [ "$(api "$A/layout" | jq .version)" = 0 ]; then
  node=$(api "$A/status" | jq -r .node)
  api -X POST "$A/layout" -d "[{\"id\":\"$node\",\"zone\":\"dc1\",\"capacity\":10737418240,\"tags\":[]}]" >/dev/null
  api -X POST "$A/layout/apply" -d '{"version":1}' >/dev/null
  echo "[garage-init] layout applied"
fi

grant() { # bucket key_name key_id key_secret
  api "$A/key?id=$3" >/dev/null 2>&1 \
    || api -X POST "$A/key/import" -d "{\"accessKeyId\":\"$3\",\"secretAccessKey\":\"$4\",\"name\":\"$2\"}" >/dev/null
  b=$(api "$A/bucket?globalAlias=$1" 2>/dev/null) \
    || b=$(api -X POST "$A/bucket" -d "{\"globalAlias\":\"$1\"}")
  id=$(echo "$b" | jq -r .id)
  api -X POST "$A/bucket/allow" \
    -d "{\"bucketId\":\"$id\",\"accessKeyId\":\"$3\",\"permissions\":{\"read\":true,\"write\":true,\"owner\":false}}" >/dev/null
  echo "[garage-init] bucket $1 -> key $2"
}
grant "$BACKUP_BUCKET" postgres      "$GARAGE_KEY_ID" "$GARAGE_KEY_SECRET"
grant "$AUDIT_BUCKET"  audit-shipper "$AUDIT_KEY_ID"  "$AUDIT_KEY_SECRET"
