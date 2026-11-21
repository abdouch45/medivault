#!/bin/sh
# medivault_postgres entrypoint: start the backup loop detached, then hand over to the official
# entrypoint so Postgres stays the main process. The ( ... & ) double fork re-parents the loop to
# docker's init (compose: init: true), which reaps it — Postgres never sees a foreign child process.
( gosu postgres backup-loop.sh & )
exec docker-entrypoint.sh "$@"
