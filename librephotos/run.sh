#!/usr/bin/env bash
set -e

# Bashio laden falls verfügbar (HA), sonst Defaults
if command -v bashio &>/dev/null && [ -f /data/options.json ]; then
    source /usr/lib/bashio/bashio.sh
    DB_PASS_CONF=$(bashio::config 'db_password')
    WORKERS_CONF=$(bashio::config 'workers')
    ADMIN_USER=$(bashio::config 'admin_username')
    ADMIN_PASS=$(bashio::config 'admin_password')
    ADMIN_MAIL=$(bashio::config 'admin_email')
    bashio::log.info "=== LibrePhotos Addon startet (v0.08) ==="
else
    DB_PASS_CONF="${DB_PASS:-LibrePhotos1234}"
    WORKERS_CONF="${WORKERS:-2}"
    ADMIN_USER="${ADMIN_USERNAME:-admin}"
    ADMIN_PASS="${ADMIN_PASSWORD:-admin}"
    ADMIN_MAIL="${ADMIN_EMAIL:-admin@example.com}"
    echo "=== LibrePhotos startet (Standalone-Modus) ==="
fi

echo "Worker: ${WORKERS_CONF}"

# ────────────────────────────────────────────────────────────────────────────
# PERSISTENZ-LAYOUT (v0.06)
# Alle Daten die einen Addon-Rebuild überleben müssen, liegen unter /config:
#
#   /config/librephotos/
#     ├── postgres/         PostgreSQL-Datenverzeichnis
#     ├── protected_media/  Thumbnails, Gesichter, ML-Modelle (~5 GB)
#     ├── cache/            Pip/HF-Modell-Downloads
#     ├── logs/             Application logs
#     └── secret_key        Stabiler Django SECRET_KEY (Sessions/JWT)
#
# /data wird vom unified-Image als Foto-Quelle erwartet → Symlinks dorthin.
# ────────────────────────────────────────────────────────────────────────────

PERSIST=/config/librephotos
mkdir -p \
    "${PERSIST}/postgres" \
    "${PERSIST}/protected_media" \
    "${PERSIST}/cache" \
    "${PERSIST}/logs"

# Container-interne Pfade auf Persist-Volume umlenken (Symlinks)
echo "Persistenz-Pfade verlinken..."
for pair in \
    "/protected_media:${PERSIST}/protected_media" \
    "/logs:${PERSIST}/logs" \
    "/root/.cache:${PERSIST}/cache"
do
    SRC="${pair%%:*}"
    DST="${pair##*:}"
    mkdir -p "$(dirname "${SRC}")"
    rm -rf "${SRC}" 2>/dev/null || true
    ln -sfn "${DST}" "${SRC}"
done

# ── Foto-Verzeichnisse automatisch nach /data verlinken ──────────────────────
# Das unified-Image erwartet alle Fotos unter /data. Wir verlinken einfach
# alle verfügbaren HA-Storage-Pfade dorthin – der User wählt in der
# LibrePhotos-UI selbst aus, welche Unterverzeichnisse gescannt werden sollen.

# /data zurücksetzen (HA-options.json wurde von bashio bereits eingelesen)
rm -rf /data 2>/dev/null || true
mkdir -p /data

for HA_PATH in /media /share; do
    if [ -d "${HA_PATH}" ]; then
        TARGET_NAME=$(basename "${HA_PATH}")
        ln -sfn "${HA_PATH}" "/data/${TARGET_NAME}"
        echo "Verlinkt: /data/${TARGET_NAME} -> ${HA_PATH}"
    fi
done

echo "── Verfügbare Foto-Quellen unter /data ──"
ls -la /data

# ── Persistent Secret Key ────────────────────────────────────────────────────
SECRET_FILE="${PERSIST}/secret_key"
if [ ! -f "${SECRET_FILE}" ]; then
    echo "Generiere neuen SECRET_KEY..."
    head -c 32 /dev/urandom | base64 > "${SECRET_FILE}"
    chmod 600 "${SECRET_FILE}"
fi

# ── Umgebungsvariablen für Supervisor-Subprozess exportieren ─────────────────
export DB_PASS="${DB_PASS_CONF}"
export SECRET_KEY="$(cat "${SECRET_FILE}")"
export WORKERS="${WORKERS_CONF}"
export ADMIN_USERNAME="${ADMIN_USER}"
export ADMIN_PASSWORD="${ADMIN_PASS}"
export ADMIN_EMAIL="${ADMIN_MAIL}"
export CSRF_TRUSTED_ORIGINS="http://homeassistant.local:8001,http://localhost:8001"

# PG_DATA-Pfad für start-postgres.sh exportieren (persistent in /config)
export PG_DATA="${PERSIST}/postgres"

# ── PostgreSQL initialisieren (falls leer) ───────────────────────────────────
PG_BIN=$(ls -d /usr/lib/postgresql/*/bin | head -n1)

# Berechtigungen sicherstellen (HA mounted /config oft als root)
chown -R postgres:postgres "${PG_DATA}"
chmod 700 "${PG_DATA}"

if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    echo "PostgreSQL Datenbank wird in ${PG_DATA} initialisiert..."
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
