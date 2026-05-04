ARG BUILD_FROM
# BUILD_FROM wird für die HA-Build-Validation gesetzt, aber wir bauen direkt
# auf dem offiziellen LibrePhotos-Backend-Image auf (Debian-basiert, mit
# allen ML-Dependencies bereits vorinstalliert).
FROM reallibrephotos/librephotos:latest

# ── HA-Integration und zusätzliche Services ──────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql \
        postgresql-contrib \
        redis-server \
        nginx \
        supervisor \
        curl \
        jq \
        ca-certificates \
        gosu \
    && rm -rf /var/lib/apt/lists/*

# ── Bashio installieren (für HA-Config-Zugriff) ───────────────────────────────
ARG BASHIO_VERSION=0.16.2
RUN mkdir -p /tmp/bashio && \
    curl -J -L -o /tmp/bashio.tar.gz \
        "https://github.com/hassio-addons/bashio/archive/v${BASHIO_VERSION}.tar.gz" && \
    tar zxvf /tmp/bashio.tar.gz --strip 1 -C /tmp/bashio && \
    mv /tmp/bashio/lib /usr/lib/bashio && \
    ln -s /usr/lib/bashio/bashio /usr/bin/bashio && \
    rm -rf /tmp/bashio /tmp/bashio.tar.gz

# ── PostgreSQL: Konfiguration ────────────────────────────────────────────────
RUN mkdir -p /var/lib/postgresql/data /var/run/postgresql && \
    chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql

# ── Frontend (Static Build) holen ────────────────────────────────────────────
# Das Frontend-Image enthält den fertigen Static-Build unter /usr/share/nginx/html
# Wir kopieren ihn aus dem Frontend-Image
COPY --from=reallibrephotos/librephotos-frontend:latest /usr/share/nginx/html /opt/librephotos/static

# ── Konfigurationsdateien ────────────────────────────────────────────────────
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/librephotos.conf

# ── Datenverzeichnisse ───────────────────────────────────────────────────────
RUN mkdir -p \
    /data/librephotos/protected_media \
    /data/librephotos/data \
    /data/librephotos/logs

# ── Startskript ──────────────────────────────────────────────────────────────
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 3000

CMD ["/run.sh"]
