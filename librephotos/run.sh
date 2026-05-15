#!/usr/bin/env bash
set -e

# Load bashio if available (HA), otherwise fall back to defaults
if command -v bashio &>/dev/null && [ -f /data/options.json ]; then
    source /usr/lib/bashio/bashio.sh
    DB_PASS_CONF=$(bashio::config 'db_password')
    WORKERS_CONF=$(bashio::config 'workers')
    ADMIN_USER=$(bashio::config 'admin_username')
    ADMIN_PASS=$(bashio::config 'admin_password')
    ADMIN_MAIL=$(bashio::config 'admin_email')
    bashio::log.info "=== LibrePhotos add-on starting (v0.10) ==="
else
    DB_PASS_CONF="${DB_PASS:-LibrePhotos1234}"
    WORKERS_CONF="${WORKERS:-2}"
    ADMIN_USER="${ADMIN_USERNAME:-admin}"
    ADMIN_PASS="${ADMIN_PASSWORD:-admin}"
    ADMIN_MAIL="${ADMIN_EMAIL:-admin@example.com}"
    echo "=== LibrePhotos starting (standalone mode) ==="
fi

echo "Workers: ${WORKERS_CONF}"

# ────────────────────────────────────────────────────────────────────────────
# PERSISTENCE LAYOUT (since v0.06)
# All data that must survive an add-on rebuild lives under /config:
#
#   /config/librephotos/
#     ├── postgres/         PostgreSQL data directory
#     ├── protected_media/  thumbnails, faces, ML models (~5 GB)
#     ├── cache/            pip / HuggingFace model downloads
#     ├── logs/             application logs
#     └── secret_key        stable Django SECRET_KEY (sessions / JWT)
#
# /data is what the unified image expects as the photo source → symlinks there.
# ────────────────────────────────────────────────────────────────────────────

PERSIST=/config/librephotos
mkdir -p \
    "${PERSIST}/postgres" \
    "${PERSIST}/protected_media" \
    "${PERSIST}/cache" \
    "${PERSIST}/logs"

# Redirect container-internal paths to the persistent volume (symlinks)
echo "Linking persistence paths..."
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

# ── Auto-link photo directories under /data ─────────────────────────────────
# The unified image expects all photos under /data. We expose every
# available HA storage path there – the user picks the sub-directory to scan
# from the LibrePhotos UI.

# Reset /data (bashio has already parsed HA options.json above)
rm -rf /data 2>/dev/null || true
mkdir -p /data

for HA_PATH in /media /share; do
    if [ -d "${HA_PATH}" ]; then
        TARGET_NAME=$(basename "${HA_PATH}")
        ln -sfn "${HA_PATH}" "/data/${TARGET_NAME}"
        echo "Linked: /data/${TARGET_NAME} -> ${HA_PATH}"
    fi
done

echo "── Available photo sources under /data ──"
ls -la /data

# ── Persistent secret key ───────────────────────────────────────────────────
SECRET_FILE="${PERSIST}/secret_key"
if [ ! -f "${SECRET_FILE}" ]; then
    echo "Generating new SECRET_KEY..."
    head -c 32 /dev/urandom | base64 > "${SECRET_FILE}"
    chmod 600 "${SECRET_FILE}"
fi

# ── Export env vars for the supervisor sub-process ──────────────────────────
export DB_PASS="${DB_PASS_CONF}"
export SECRET_KEY="$(cat "${SECRET_FILE}")"
export WORKERS="${WORKERS_CONF}"
export ADMIN_USERNAME="${ADMIN_USER}"
export ADMIN_PASSWORD="${ADMIN_PASS}"
export ADMIN_EMAIL="${ADMIN_MAIL}"
export CSRF_TRUSTED_ORIGINS="http://homeassistant.local:8001,http://localhost:8001"

# PG_DATA path for start-postgres.sh (persistent in /config)
export PG_DATA="${PERSIST}/postgres"

# ── Initialise PostgreSQL (if empty) ────────────────────────────────────────
PG_BIN=$(ls -d /usr/lib/postgresql/*/bin | head -n1)

# Make sure permissions are correct (HA often mounts /config as root)
chown -R postgres:postgres "${PG_DATA}"
chmod 700 "${PG_DATA}"

if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    echo "Initialising PostgreSQL database in ${PG_DATA}..."
    gosu postgres "${PG_BIN}/initdb" -D "${PG_DATA}" --locale=C --encoding=UTF8
fi

# ── Create user / database ──────────────────────────────────────────────────
echo "Starting PostgreSQL temporarily to create user/database..."
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

# ── Start supervisor ────────────────────────────────────────────────────────
echo "Starting all services..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
