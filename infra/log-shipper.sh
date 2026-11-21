#!/bin/sh
# Runs in medivault_logship. Holds only the audit-bucket key: no data files, no backup key,
# no superuser password (it queries as the auditor aud_smith). Every 30s:
#   - ships each finished Postgres log file (error/access/pgaudit) once to the audit bucket,
#     then deletes local copies older than LOG_KEEP_DAYS
#   - anchors the latest AuditLog hash off-box so a rewritten chain is detectable (see verify-audit.sh)
set -u
KEEP_MIN=$(( ${LOG_KEEP_DAYS:-7} * 1440 ))
LOGDIR=/var/log/postgresql
SHIPPED=/tmp/shipped; mkdir -p "$SHIPPED"

s3put() { # file key
  curl -fsSk --aws-sigv4 "aws:amz:garage:s3" -u "$AUDIT_KEY_ID:$AUDIT_KEY_SECRET" \
    -H "x-amz-content-sha256: $(sha256sum "$1" | cut -c1-64)" -T "$1" "https://garage-tls/$AUDIT_BUCKET/$2"
}

until pg_isready -q -h /var/run/postgresql; do echo "[logship] waiting for postgres..."; sleep 2; done

last_anchor=""
while :; do
  # Ship each finished log file once (skip the one Postgres is still writing).
  # The content hash in the object name means a re-ship after a local edit lands beside the
  # original in Garage, never over it. Markers live in this container's /tmp, not the shared
  # log volume, so the DB side can't fake "already shipped" to get a file pruned unseen.
  newest=$(ls -t "$LOGDIR" 2>/dev/null | head -1)
  for f in "$LOGDIR"/*.log; do
    n=$(basename "$f")
    [ -f "$f" ] && [ "$n" != "$newest" ] && [ ! -e "$SHIPPED/$n" ] || continue
    s3put "$f" "logs/$n.$(sha256sum "$f" | cut -c1-64)" && touch "$SHIPPED/$n"
  done

  # Prune local copies older than LOG_KEEP_DAYS, but only ones already safe in Garage.
  find "$LOGDIR" -name '*.log' -mmin +"$KEEP_MIN" 2>/dev/null | while read -r f; do
    n=$(basename "$f")
    [ -e "$SHIPPED/$n" ] && rm -f "$f" "$SHIPPED/$n"
  done

  # ponytail: one anchor per change, 30s window; anchor more often if that window matters.
  a=$(psql -h /var/run/postgresql -d medivault -Atc \
      "SELECT log_id || '_' || curr_hash FROM auditlog ORDER BY log_id DESC LIMIT 1" 2>/dev/null)
  if [ -n "$a" ] && [ "$a" != "$last_anchor" ]; then
    : > /tmp/empty && s3put /tmp/empty "anchors/$a" && last_anchor=$a
  fi
  sleep 30
done
