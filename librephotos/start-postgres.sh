#!/bin/bash
# Wrapper: findet die installierte PostgreSQL-Version dynamisch und startet
# den Server. Das Daten-Verzeichnis kommt aus PG_DATA (gesetzt von run.sh)
# und liegt unter /config/librephotos/postgres (persistent).
set -e

# Default falls PG_DATA nicht gesetzt (Container-Standalone)
PG_DATA="${PG_DATA:-/config/librephotos/postgres}"
PG_BIN=$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | head -n1)

if [ -z "${PG_BIN}" ]; then
    echo "FEHLER: Keine PostgreSQL-Installation gefunden!" >&2
    exit 1
fi

if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    echo "FEHLER: PostgreSQL-Daten in ${PG_DATA} nicht initialisiert!" >&2
    exit 1
fi

# Berechtigungen sicherstellen
chown -R postgres:postgres "${PG_DATA}"
chmod 700 "${PG_DATA}"

exec gosu postgres "${PG_BIN}/postgres" \
    -D "${PG_DATA}" \
    -c listen_addresses=127.0.0.1 \
    -c unix_socket_directories=/var/run/postgresql
