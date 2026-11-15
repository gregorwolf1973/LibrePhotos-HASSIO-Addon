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
    LOG_LEVEL_CONF=$(bashio::config 'log_level')
    if bashio::config.has_value 'log_level'; then
        bashio::log.level "${LOG_LEVEL_CONF}"
    fi
    bashio::log.info "=== LibrePhotos add-on starting (v0.13) ==="
else
    DB_PASS_CONF="${DB_PASS:-LibrePhotos1234}"
    WORKERS_CONF="${WORKERS:-2}"
    ADMIN_USER="${ADMIN_USERNAME:-admin}"
    ADMIN_PASS="${ADMIN_PASSWORD:-admin}"
    ADMIN_MAIL="${ADMIN_EMAIL:-admin@example.com}"
    LOG_LEVEL_CONF="${LOG_LEVEL:-info}"
    echo "=== LibrePhotos starting (standalone mode) ==="
fi

echo "Workers: ${WORKERS_CONF}"

# ── Map the add-on log level to the backend's LOG_LEVEL ─────────────────────
# LibrePhotos reads LOG_LEVEL (Python logging names) from the environment.
case "$(echo "${LOG_LEVEL_CONF}" | tr '[:upper:]' '[:lower:]')" in
    trace|debug) LP_LOG_LEVEL="DEBUG" ;;
    notice|info) LP_LOG_LEVEL="INFO" ;;
    warning)     LP_LOG_LEVEL="WARNING" ;;
    error)       LP_LOG_LEVEL="ERROR" ;;
    fatal)       LP_LOG_LEVEL="CRITICAL" ;;
    *)           LP_LOG_LEVEL="INFO" ;;
esac
echo "Log level: ${LOG_LEVEL_CONF} (backend LOG_LEVEL=${LP_LOG_LEVEL})"

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
export LP_LOG_LEVEL
export CSRF_TRUSTED_ORIGINS="http://homeassistant.local:8001,http://localhost:8001"

# PG_DATA path for start-postgres.sh (persistent in /config)
export PG_DATA="${PERSIST}/postgres"

# ── Initialise PostgreSQL (if empty) ────────────────────────────────────────
PG_MAJOR="${PG_MAJOR:-18}"
PG_BIN="/usr/lib/postgresql/${PG_MAJOR}/bin"
export PG_BIN

# Make sure permissions are correct (HA often mounts /config as root)
chown -R postgres:postgres "${PG_DATA}"
chmod 700 "${PG_DATA}"

# ── Upgrade an existing database from an older PostgreSQL major version ─────
# Add-on <= 0.12 installed whatever PostgreSQL the base image shipped
# (16 until LibrePhotos 1.1, 18 since 1.2). A data directory of another major
# version cannot be opened, so it is upgraded with pg_upgrade. The original
# stays untouched as postgres-<old>.bak next to the new one.
if [ -f "${PG_DATA}/PG_VERSION" ]; then
    OLD_MAJOR=$(cat "${PG_DATA}/PG_VERSION")
    if [ "${OLD_MAJOR}" != "${PG_MAJOR}" ]; then
        OLD_BIN="/usr/lib/postgresql/${OLD_MAJOR}/bin"
        NEW_DATA="${PERSIST}/postgres.upgrade"
        BACKUP_DATA="${PERSIST}/postgres-${OLD_MAJOR}.bak"
        if [ ! -x "${OLD_BIN}/postgres" ]; then
            echo "ERROR: database is PostgreSQL ${OLD_MAJOR}, but only the binaries for ${PG_MAJOR} and ${PG_OLD_MAJORS:-none} are included. Cannot upgrade." >&2
            exit 1
        fi
        if [ -e "${BACKUP_DATA}" ]; then
            echo "ERROR: ${BACKUP_DATA} already exists - a previous upgrade was interrupted. Check /config/librephotos manually." >&2
            exit 1
        fi
        echo "Upgrading PostgreSQL database ${OLD_MAJOR} -> ${PG_MAJOR} (original kept as $(basename "${BACKUP_DATA}"))..."

        # Make sure the old cluster was shut down cleanly (pg_upgrade requires it)
        gosu postgres "${OLD_BIN}/pg_ctl" -D "${PG_DATA}" -l /tmp/pg_old.log \
            -o "-c listen_addresses='' -c unix_socket_directories=/tmp" start -w
        gosu postgres "${OLD_BIN}/pg_ctl" -D "${PG_DATA}" stop -w

        rm -rf "${NEW_DATA}"
        mkdir -p "${NEW_DATA}"
        chown postgres:postgres "${NEW_DATA}"
        chmod 700 "${NEW_DATA}"
        # Same settings as the original initdb; old clusters had no checksums
        gosu postgres "${PG_BIN}/initdb" -D "${NEW_DATA}" --locale=C --encoding=UTF8 \
            --no-data-checksums >/tmp/pg_upgrade_initdb.log

        UPGRADE_WORK=/tmp/pg_upgrade_work
        rm -rf "${UPGRADE_WORK}"
        mkdir -p "${UPGRADE_WORK}"
        chown postgres:postgres "${UPGRADE_WORK}"
        if ! (cd "${UPGRADE_WORK}" && gosu postgres "${PG_BIN}/pg_upgrade" \
                --old-bindir="${OLD_BIN}" --new-bindir="${PG_BIN}" \
                --old-datadir="${PG_DATA}" --new-datadir="${NEW_DATA}" \
                --socketdir="${UPGRADE_WORK}" --copy); then
            echo "ERROR: pg_upgrade failed. The original database is unchanged." >&2
            find "${UPGRADE_WORK}" "${NEW_DATA}" -name '*.log' -exec tail -n 30 {} + >&2 || true
            rm -rf "${NEW_DATA}"
            exit 1
        fi

        mv "${PG_DATA}" "${BACKUP_DATA}"
        mv "${NEW_DATA}" "${PG_DATA}"
        PG_ANALYZE_AFTER_UPGRADE=1
        echo "PostgreSQL upgrade finished. Delete $(basename "${BACKUP_DATA}") once everything works."
    fi
fi

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

# pg_upgrade does not carry over planner statistics
if [ "${PG_ANALYZE_AFTER_UPGRADE:-0}" = "1" ]; then
    echo "Rebuilding planner statistics after the upgrade..."
    gosu postgres "${PG_BIN}/vacuumdb" --all --analyze-only || true
fi

gosu postgres "${PG_BIN}/pg_ctl" -D "${PG_DATA}" stop -w

# ── Start supervisor ────────────────────────────────────────────────────────
echo "Starting all services..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
