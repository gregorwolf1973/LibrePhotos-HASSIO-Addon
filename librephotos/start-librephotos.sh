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
exec /entrypoint.sh
