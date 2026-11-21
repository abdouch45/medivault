#!/bin/sh
# Runs INSIDE medivault_postgres. pgBackRest reads the data files locally, compresses them and
# encrypts them with BACKUP_ENC_KEY (AES-256) here on the database server; only ciphertext is sent
# to Garage. WAL takes the same path via archive_command.
#   full backup every BACKUP_FULL_INTERVAL_MIN, incremental every BACKUP_INCR_INTERVAL_MIN.
set -u
export PGPASSWORD="$POSTGRES_PASSWORD"
FULL=$(( ${BACKUP_FULL_INTERVAL_MIN:-15} * 60 ))
INCR=$(( ${BACKUP_INCR_INTERVAL_MIN:-5} * 60 ))

# The first boot runs a temporary init server; a backup against it fails and is simply retried next tick.
until pg_isready -q -h /var/run/postgresql; do sleep 5; done
until pgbackrest stanza-create; do echo "[backup] stanza-create failed, retrying..."; sleep 10; done

last_full=0; last_incr=0
while :; do
  now=$(date +%s)
  # pgBackRest is silent on success, so say it ourselves (shows in: docker logs medivault_postgres)
  if [ $((now - last_full)) -ge "$FULL" ]; then
    pgbackrest --type=full backup && last_full=$now && last_incr=$now && echo "[backup] full backup OK"
  elif [ $((now - last_incr)) -ge "$INCR" ]; then
    pgbackrest --type=incr backup && last_incr=$now && echo "[backup] incremental backup OK"
  fi
  sleep 30
done
