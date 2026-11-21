#!/bin/sh
# Migration/test server: on an empty data dir, restore the latest encrypted backup from Garage
# (pgBackRest decrypts with BACKUP_ENC_KEY, replays WAL to the end), then start Postgres normally.
# Refresh to the newest backup: docker compose rm -sfv medivault-test && docker compose up -d medivault-test
set -eu
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  until gosu postgres pgbackrest info --output=json 2>/dev/null | jq -e '.[0].backup | length > 0' >/dev/null; do
    echo "[test] no backup in the repo yet, waiting..."; sleep 15
  done
  chown postgres:postgres "$PGDATA"
  gosu postgres pgbackrest restore
  echo "[test] restore done, starting postgres (WAL replay + promote)"
fi
exec docker-entrypoint.sh "$@"
