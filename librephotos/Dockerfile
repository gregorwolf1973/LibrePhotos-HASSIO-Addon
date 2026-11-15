ARG BUILD_FROM
# Wir nutzen das offizielle "unified" LibrePhotos-Image als Basis.
# Dieses enthält bereits Backend (Django) + Frontend (statisch) und
# serviert beides auf Port 8001 mit SERVE_FRONTEND=true.
# Feste Version statt :latest – sonst bemerkt Home Assistant neue
# LibrePhotos-Versionen nicht und baut nicht neu.
FROM reallibrephotos/librephotos-unified:1.6.0

# ── PostgreSQL und Supervisor zusätzlich installieren ────────────────────────
# PG_MAJOR ist die Version, mit der die Datenbank läuft. PG_OLD_MAJORS werden
# nur mitinstalliert, damit run.sh ältere Datenbanken per pg_upgrade anheben
# kann (Add-on <= 0.12 lief je nach Bauzeitpunkt mit PostgreSQL 16).
# Beides kommt aus dem offiziellen PostgreSQL-Repo (apt.postgresql.org).
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV PG_MAJOR=18 \
    PG_OLD_MAJORS="16"
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        gnupg \
    && . /etc/os-release \
    && install -d /usr/share/postgresql-common/pgdg \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg] https://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list \
    && mkdir -p /etc/postgresql-common/createcluster.d \
    && echo "create_main_cluster = false" > /etc/postgresql-common/createcluster.d/no-main.conf \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        "postgresql-${PG_MAJOR}" \
        $(for v in ${PG_OLD_MAJORS}; do echo "postgresql-${v}"; done) \
        supervisor \
        gosu \
        jq \
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
