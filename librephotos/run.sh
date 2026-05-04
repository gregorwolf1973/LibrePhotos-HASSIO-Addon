#!/usr/bin/with-contenv bashio

set -e

bashio::log.info "=== LibrePhotos Addon startet ==="

# ── Konfiguration aus HA laden ────────────────────────────────────────────────
SCAN_DIR=$(bashio::config 'scan_directory')
DB_PASS=$(bashio::config 'db_password')
WORKERS=$(bashio::config 'workers')
LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.info "Fotoordner: ${SCAN_DIR}"
bashio::log.info "Worker-Anzahl: ${WORKERS}"

# ── Umgebungsvariablen setzen ─────────────────────────────────────────────────
export DB_NAME="librephotos"
export DB_USER="librephotos"
export DB_PASS="${DB_PASS}"
export DB_HOST="127.0.0.1"
export DB_PORT="5432"
export SCAN_DIRECTORY="${SCAN_DIR}"
export ALLOWED_HOSTS="*"
export SECRET_KEY=$(cat /data/librephotos/secret_key 2>/dev/null || openssl rand -hex 32 | tee /data/librephotos/secret_key)
export DEBUG="false"
export WORKERS="${WORKERS}"
export DJANGO_LOG_LEVEL="${LOG_LEVEL}"
export REDIS_HOST="127.0.0.1"
export REDIS_PORT="6379"
export PROTECTED_MEDIA_ROOT="/data/librephotos/protected_media"
export DATA_ROOT="${SCAN_DIR}"
export CSRF_TRUSTED_ORIGINS="http://localhost:3000,http://homeassistant.local:3000"

# ── System-User anlegen ───────────────────────────────────────────────────────
if ! id -u librephotos &>/dev/null; then
    adduser -D -s /bin/sh librephotos
fi

chown -R librephotos:librephotos \
    /opt/librephotos/repo \
    /data/librephotos

# ── PostgreSQL initialisieren ─────────────────────────────────────────────────
if [ ! -f /var/lib/postgresql/data/PG_VERSION ]; then
    bashio::log.info "PostgreSQL Datenbank wird initialisiert..."
    su-exec postgres initdb -D /var/lib/postgresql/data
fi

# PostgreSQL starten (temporär für Setup)
su-exec postgres pg_ctl -D /var/lib/postgresql/data -l /var/log/postgresql_init.log start -w

# Datenbank und User anlegen (falls nicht vorhanden)
su-exec postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
    su-exec postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

su-exec postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
    su-exec postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

su-exec postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
su-exec postgres pg_ctl -D /var/lib/postgresql/data stop -w

# ── Django Migrations & Static Files ─────────────────────────────────────────
bashio::log.info "Django Datenbank-Migrationen werden ausgeführt..."

# Wieder starten für Migrations
su-exec postgres pg_ctl -D /var/lib/postgresql/data -l /var/log/postgresql_init.log start -w
sleep 2

cd /opt/librephotos/repo/apps/backend
su-exec librephotos /opt/librephotos/venv/bin/python manage.py migrate --noinput || \
    bashio::log.warning "Migrations hatten Fehler (könnten beim ersten Start normal sein)"

su-exec librephotos /opt/librephotos/venv/bin/python manage.py collectstatic --noinput 2>/dev/null || true

su-exec postgres pg_ctl -D /var/lib/postgresql/data stop -w

# ── Supervisor starten (alle Dienste) ─────────────────────────────────────────
bashio::log.info "Alle Dienste werden gestartet..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
