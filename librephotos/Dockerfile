ARG BUILD_FROM
FROM $BUILD_FROM AS base

# ── System packages ──────────────────────────────────────────────────────────
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    nginx \
    postgresql16 \
    postgresql16-contrib \
    supervisor \
    python3 \
    py3-pip \
    py3-virtualenv \
    nodejs \
    npm \
    redis \
    libmagic \
    libheif \
    ffmpeg \
    imagemagick \
    exiftool \
    libraw \
    tzdata \
    shadow \
    su-exec \
    gcc \
    musl-dev \
    python3-dev \
    libffi-dev \
    openssl-dev \
    postgresql16-dev

# ── PostgreSQL setup ─────────────────────────────────────────────────────────
RUN mkdir -p /var/lib/postgresql/data \
    && chown -R postgres:postgres /var/lib/postgresql

# ── LibrePhotos Monorepo clonen ───────────────────────────────────────────────
RUN apk add --no-cache git && \
    git clone --depth 1 https://github.com/LibrePhotos/librephotos.git /opt/librephotos/repo && \
    apk del git

# Backend liegt unter apps/backend/
WORKDIR /opt/librephotos/repo/apps/backend

# Install Python dependencies
RUN python3 -m venv /opt/librephotos/venv && \
    /opt/librephotos/venv/bin/pip install --upgrade pip && \
    /opt/librephotos/venv/bin/pip install -r /opt/librephotos/repo/apps/backend/requirements.txt

# ── LibrePhotos Frontend ──────────────────────────────────────────────────────
RUN apk add --no-cache git && \
    git clone --depth 1 https://github.com/LibrePhotos/librephotos-frontend.git /opt/librephotos/frontend && \
    apk del git && \
    cd /opt/librephotos/frontend && \
    npm install && \
    npm run build && \
    mkdir -p /opt/librephotos/static && \
    cp -r /opt/librephotos/frontend/dist/* /opt/librephotos/static/ 2>/dev/null || \
    cp -r /opt/librephotos/frontend/build/* /opt/librephotos/static/ 2>/dev/null || true && \
    rm -rf /opt/librephotos/frontend/node_modules

# ── Nginx config ──────────────────────────────────────────────────────────────
COPY nginx.conf /etc/nginx/nginx.conf

# ── Supervisor config ─────────────────────────────────────────────────────────
COPY supervisord.conf /etc/supervisord.conf

# ── Data directories ──────────────────────────────────────────────────────────
RUN mkdir -p \
    /data/librephotos/protected_media \
    /data/librephotos/data \
    /data/librephotos/logs

# ── Startup script ────────────────────────────────────────────────────────────
COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
