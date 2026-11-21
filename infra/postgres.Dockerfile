# One image for the main DB, the backup scheduler, the test server and garage-init.
# Debian (not alpine) because pgaudit + pgbackrest ship from the PGDG apt repo already configured here.
FROM postgres:16-bookworm
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-16-pgaudit pgbackrest curl jq ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && install -d -m 0700 -o postgres -g postgres /var/log/postgresql
# ^ the pglogs volume copies this owner/mode on creation, so only postgres (uid 999) can read the logs
COPY --chmod=0755 *.sh /usr/local/bin/
