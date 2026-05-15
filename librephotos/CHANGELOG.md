# Changelog

## 0.10 (2026-05-15)

### Documentation translated to English
- All README / DOCS / changelog content is now in English
- Added "Buy Me A Coffee" support button to top-level and add-on README
- Added GitHub topics on the repository for discoverability

## 0.09 (2026-05-06)

### MAP_API_PROVIDER pinned to nominatim
- `MAP_API_PROVIDER=nominatim` set explicitly as an env var in `supervisord.conf`
- Prevents the `production.py` fallback (`"photon"`) from kicking in when the
  Constance migration 0093 has not run
- Photon's public API has been unreliable for a long time (502s); Nominatim is
  also the new default upstream

## 0.08 (2026-05-06)

### `scan_directory` removed – photo sources are auto-detected
- The `scan_directory` option is gone. Nothing to configure any more.
- `/media` and `/share` are auto-linked under `/data/media` and `/data/share`
- In the LibrePhotos UI the user picks the path directly under Library
  (e.g. `/data/media/photoprism/originals`)

## 0.07 (2026-05-05)

### Ingress removed, "OPEN WEB UI" button instead
- `ingress: false` because the LibrePhotos SPA has hard-coded API paths
  incompatible with the HA Ingress URL prefix (white screen)
- `webui:` property exposes an "OPEN WEB UI" button on the add-on tab linking
  directly to `http://homeassistant.local:8001`
- Optional: users can wire a `panel_iframe` entry in `configuration.yaml` to
  put LibrePhotos in the HA sidebar

## 0.06 (2026-05-05)

### Persistence (Breaking Change)
- **All persistent data now lives under `/config/librephotos/`**:
  - `postgres/` – PostgreSQL data directory
  - `protected_media/` – thumbnails, faces, ML models
  - `cache/` – model downloads (HuggingFace, pip)
  - `logs/`
  - `secret_key` – stable Django SECRET_KEY
- Updates and add-on rebuilds **no longer** wipe DB & caches
- HA snapshots automatically back up all LibrePhotos data with `/config`
- **Migration**: existing users start fresh on update (DB in the old container is lost)

## 0.05 (2026-05-05)
- Multi-path access via symlinks under /data (media + share)
- Auto-creation of the scan folder

## 0.04 (2026-05-05)
- X_FRAME_OPTIONS patch for HA Ingress (used to show a white screen)

## 0.03 (2026-05-05)
- PostgreSQL crash loop fixed (dynamic version detection)
- pg_isready wait logic added

## 0.02 (2026-05-04)
- Refactor onto the official librephotos-unified image

## 0.01 (2026-05-04)

### Initial Release
- LibrePhotos backend (Django) integration
- LibrePhotos frontend (React) integration
- PostgreSQL database (bundled)
- Redis cache (bundled)
- Nginx reverse proxy
- Home Assistant Ingress support
- Configurable worker count
- Automatic database initialisation
