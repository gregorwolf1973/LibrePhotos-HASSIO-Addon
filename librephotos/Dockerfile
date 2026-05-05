ARG BUILD_FROM
# Wir nutzen das offizielle "unified" LibrePhotos-Image als Basis.
# Dieses enthält bereits Backend (Django) + Frontend (statisch) und
# serviert beides auf Port 8001 mit SERVE_FRONTEND=true.
FROM reallibrephotos/librephotos-unified:latest

# ── PostgreSQL und Supervisor zusätzlich installieren ────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql \
        postgresql-contrib \
        supervisor \
        gosu \
        curl \
        jq \
        ca-certificates \
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

# ── Konfigurationsdateien ────────────────────────────────────────────────────
COPY supervisord.conf /etc/supervisor/conf.d/librephotos.conf

# ── Datenverzeichnisse ───────────────────────────────────────────────────────
RUN mkdir -p \
    /protected_media \
    /logs \
    /data/librephotos

# ── Startskripte ─────────────────────────────────────────────────────────────
COPY run.sh /run.sh
COPY start-postgres.sh /start-postgres.sh
COPY start-librephotos.sh /start-librephotos.sh
RUN chmod +x /run.sh /start-postgres.sh /start-librephotos.sh

EXPOSE 8001

CMD ["/run.sh"]
