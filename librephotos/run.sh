#!/usr/bin/env bash
set -e

# Bashio laden falls verfügbar (HA), sonst Defaults nutzen
if command -v bashio &>/dev/null && [ -f /data/options.json ]; then
    source /usr/lib/bashio/bashio.sh
    SCAN_DIR=$(bashio::config 'scan_directory')
    DB_PASS_CONF=$(bashio::config 'db_password')
    LOG_LEVEL=$(bashio::config 'log_level')
    bashio::log.info "=== LibrePhotos Addon startet ==="
else
    SCAN_DIR="${SCAN_DIRECTORY:-/media/photos}"
    DB_PASS_CONF="${DB_PASS:-LibrePhotos1234}"
    LOG_LEVEL="info"
    echo "=== LibrePhotos startet (Standalone-Modus) ==="
fi

echo "Fotoordner: ${SCAN_DIR}"

# ── Umgebungsvariablen für Supervisor ────────────────────────────────────────
export DB_PASS="${DB_PASS_CONF}"
export SCAN_DIRECTORY="${SCAN_DIR}"

# Persistent secret key
SECRET_FILE=/data/librephotos/secret_key
if [ ! -f "${SECRET_FILE}" ]; then
    mkdir -p "$(dirname "${SECRET_FILE}")"
    head -c 32 /dev/urandom | base64 > "${SECRET_FILE}"
fi
export SECRET_KEY=$(cat "${SECRET_FILE}")

# ── PostgreSQL initialisieren (falls nötig) ──────────────────────────────────
PG_DATA=/var/lib/postgresql/data
if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    echo "PostgreSQL Datenbank wird initialisiert..."
    gosu postgres /usr/lib/postgresql/*/bin/initdb -D "${PG_DATA}" \
        --locale=C --encoding=UTF8
fi

# Postgres temporär starten zum Anlegen von User/DB
gosu postgres /usr/lib/postgresql/*/bin/pg_ctl -D "${PG_DATA}" \
    -l /tmp/pg_init.log -o "-c listen_addresses=127.0.0.1" start -w

gosu postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='librephotos'" \
    | grep -q 1 || \
    gosu postgres psql -c "CREATE USER librephotos WITH PASSWORD '${DB_PASS}';"

gosu postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='librephotos'" \
    | grep -q 1 || \
    gosu postgres psql -c "CREATE DATABASE librephotos OWNER librephotos;"

gosu postgres psql -c "ALTER USER librephotos WITH PASSWORD '${DB_PASS}';"
gosu postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE librephotos TO librephotos;"

gosu postgres /usr/lib/postgresql/*/bin/pg_ctl -D "${PG_DATA}" stop -w

# ── Supervisor starten ───────────────────────────────────────────────────────
echo "Alle Dienste werden gestartet..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
