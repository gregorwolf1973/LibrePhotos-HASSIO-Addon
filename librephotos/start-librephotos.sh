#!/bin/bash
# Wartet bis PostgreSQL bereit ist, dann startet LibrePhotos via entrypoint.sh
set -e

echo "Warte auf PostgreSQL..."
for i in {1..60}; do
    if pg_isready -h 127.0.0.1 -p 5432 -U librephotos 2>/dev/null; then
        echo "PostgreSQL ist bereit nach ${i}s."
        break
    fi
    sleep 1
done

if ! pg_isready -h 127.0.0.1 -p 5432 -U librephotos 2>/dev/null; then
    echo "FEHLER: PostgreSQL nicht erreichbar nach 60s!" >&2
    exit 1
fi

cd /code

# ── Patch: HA Ingress benötigt iframe-Embedding (X-Frame-Options) ────────────
# Die Default-Config setzt X_FRAME_OPTIONS = "DENY", was Ingress blockiert.
if [ -f /code/production_noproxy.py ]; then
    sed -i 's/^X_FRAME_OPTIONS = "DENY"/X_FRAME_OPTIONS = "SAMEORIGIN"/' /code/production_noproxy.py
    # Falls sie schon kopiert wurde (Re-Start) auch dort
    if [ -f /code/librephotos/settings/production.py ]; then
        sed -i 's/^X_FRAME_OPTIONS = "DENY"/X_FRAME_OPTIONS = "SAMEORIGIN"/' /code/librephotos/settings/production.py
    fi
    echo "X_FRAME_OPTIONS auf SAMEORIGIN gesetzt (für HA Ingress iframe)"
fi

exec /entrypoint.sh
