#!/bin/bash
# Wrapper: findet die installierte PostgreSQL-Version dynamisch und startet
# den Server mit der Default-Konfiguration aus dem Data-Verzeichnis.
set -e

PG_DATA=/var/lib/postgresql/data
PG_BIN=$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | head -n1)

if [ -z "${PG_BIN}" ]; then
    echo "FEHLER: Keine PostgreSQL-Installation gefunden!" >&2
    exit 1
fi

# Stelle sicher dass postgres die Berechtigung hat
chown -R postgres:postgres "${PG_DATA}"

exec gosu postgres "${PG_BIN}/postgres" \
    -D "${PG_DATA}" \
    -c listen_addresses=127.0.0.1 \
    -c unix_socket_directories=/var/run/postgresql
