#!/usr/bin/env bash
set -e

# Bashio laden falls verfügbar (HA), sonst Defaults
if command -v bashio &>/dev/null && [ -f /data/options.json ]; then
    source /usr/lib/bashio/bashio.sh
    SCAN_DIR=$(bashio::config 'scan_directory')
    DB_PASS_CONF=$(bashio::config 'db_password')
    WORKERS_CONF=$(bashio::config 'workers')
    ADMIN_USER=$(bashio::config 'admin_username')
    ADMIN_PASS=$(bashio::config 'admin_password')
    ADMIN_MAIL=$(bashio::config 'admin_email')
    bashio::log.info "=== LibrePhotos Addon startet ==="
else
    SCAN_DIR="${SCAN_DIRECTORY:-/media/photos}"
    DB_PASS_CONF="${DB_PASS:-LibrePhotos1234}"
    WORKERS_CONF="${WORKERS:-2}"
    ADMIN_USER="${ADMIN_USERNAME:-admin}"
    ADMIN_PASS="${ADMIN_PASSWORD:-admin}"
    ADMIN_MAIL="${ADMIN_EMAIL:-admin@example.com}"
    echo "=== LibrePhotos startet (Standalone-Modus) ==="
fi

echo "Fotoordner: ${SCAN_DIR}"
echo "Worker: ${WORKERS_CONF}"

# ── Foto-Verzeichnis nach /data verlinken ────────────────────────────────────
# Das unified-Image erwartet ALLE Fotos unter /data. Wir machen daraus ein
# Sammel-Verzeichnis mit Symlinks zu allen verfügbaren HA-Pfaden, damit der
# User in der LibrePhotos-UI zwischen den Quellen wählen kann.

# Scan-Ordner auf dem Host anlegen falls fehlt
if [ ! -d "${SCAN_DIR}" ]; then
    echo "Lege Scan-Ordner an: ${SCAN_DIR}"
    mkdir -p "${SCAN_DIR}" 2>/dev/null || \
        echo "WARNUNG: ${SCAN_DIR} konnte nicht angelegt werden"
fi

# /data komplett neu aufbauen (Container-Mount, kein Persistenz-Verlust)
rm -rf /data 2>/dev/null || true
mkdir -p /data

# Konfigurierten Scan-Ordner verlinken
if [ -d "${SCAN_DIR}" ]; then
    SCAN_NAME=$(basename "${SCAN_DIR}")
    ln -sfn "${SCAN_DIR}" "/data/${SCAN_NAME}"
    echo "Verlinkt: /data/${SCAN_NAME} -> ${SCAN_DIR}"
fi

# Standard-HA-Pfade ebenfalls anbieten falls vorhanden und nicht schon verlinkt
for HA_PATH in /media /share; do
    if [ -d "${HA_PATH}" ]; then
        TARGET_NAME=$(basename "${HA_PATH}")
        if [ ! -e "/data/${TARGET_NAME}" ]; then
            ln -sfn "${HA_PATH}" "/data/${TARGET_NAME}"
            echo "Verlinkt: /data/${TARGET_NAME} -> ${HA_PATH}"
        fi
    fi
done

ls -la /data

# ── Persistent Secret Key ────────────────────────────────────────────────────
SECRET_FILE=/data/librephotos/secret_key
mkdir -p /data/librephotos
if [ ! -f "${SECRET_FILE}" ]; then
    head -c 32 /dev/urandom | base64 > "${SECRET_FILE}"
fi

# ── Umgebungsvariablen für Supervisor-Subprozess exportieren ─────────────────
export DB_PASS="${DB_PASS_CONF}"
export SECRET_KEY="$(cat "${SECRET_FILE}")"
export WORKERS="${WORKERS_CONF}"
export ADMIN_USERNAME="${ADMIN_USER}"
export ADMIN_PASSWORD="${ADMIN_PASS}"
export ADMIN_EMAIL="${ADMIN_MAIL}"
export CSRF_TRUSTED_ORIGINS="http://homeassistant.local:8001,http://localhost:8001"

# ── PostgreSQL initialisieren (falls leer) ───────────────────────────────────
PG_DATA=/var/lib/postgresql/data
PG_BIN=$(ls -d /usr/lib/postgresql/*/bin | head -n1)

if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    echo "PostgreSQL Datenbank wird initialisiert..."
    chown -R postgres:postgres "${PG_DATA}"
    gosu postgres "${PG_BIN}/initdb" -D "${PG_DATA}" --locale=C --encoding=UTF8
fi

# ── User/DB anlegen ──────────────────────────────────────────────────────────
echo "PostgreSQL temporär starten zum Anlegen von User/DB..."
gosu postgres "${PG_BIN}/pg_ctl" -D "${PG_DATA}" \
    -l /tmp/pg_init.log -o "-c listen_addresses=127.0.0.1" start -w

gosu postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='librephotos'" \
    | grep -q 1 || \
    gosu postgres psql -c "CREATE USER librephotos WITH PASSWORD '${DB_PASS}';"

gosu postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='librephotos'" \
    | grep -q 1 || \
    gosu postgres psql -c "CREATE DATABASE librephotos OWNER librephotos;"

gosu postgres psql -c "ALTER USER librephotos WITH PASSWORD '${DB_PASS}';"
gosu postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE librephotos TO librephotos;"

gosu postgres "${PG_BIN}/pg_ctl" -D "${PG_DATA}" stop -w

# ── Supervisor starten ───────────────────────────────────────────────────────
echo "Alle Dienste werden gestartet..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
