#!/bin/sh
# docker exec medivault_logship verify-audit.sh   (runs as the auditor aud_smith)
# 1) recomputes the in-DB hash chain, 2) checks every off-box anchor in Garage still matches the DB.
# A superuser can rewrite the chain consistently (no secret in the hash) — step 2 is what catches that.
set -u
q() { psql -h /var/run/postgresql -d medivault -Atc "$1"; }
bad=0; n=0
q "SELECT details FROM verify_audit_log_integrity()"
[ "$(q "SELECT is_valid FROM verify_audit_log_integrity()")" = t ] || bad=1
EMPTY=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
# ponytail: first 1000 anchors only (one ListObjectsV2 page); paginate if the lab runs that long.
# prefix must be URL-encoded (%2F) or the SigV4 signature won't match.
xml=$(curl -fsSk --aws-sigv4 "aws:amz:garage:s3" -u "$AUDIT_KEY_ID:$AUDIT_KEY_SECRET" -H "x-amz-content-sha256: $EMPTY" \
  "https://garage-tls/$AUDIT_BUCKET?list-type=2&prefix=anchors%2F") || { echo "ERROR: cannot list anchors in Garage"; exit 2; }
keys=$(echo "$xml" | grep -o '<Key>anchors/[^<]*' | sed 's|<Key>anchors/||')
[ -n "$keys" ] || { echo "ERROR: no off-box anchors found"; exit 2; }
for k in $keys; do
  id=${k%%_*}; h=${k#*_}; n=$((n + 1))
  [ "$(q "SELECT curr_hash FROM auditlog WHERE log_id = $id")" = "$h" ] || { echo "TAMPERED: log_id=$id differs from off-box anchor"; bad=1; }
done
echo "$n off-box anchors checked"
exit $bad
