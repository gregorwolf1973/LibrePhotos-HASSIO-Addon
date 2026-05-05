# Changelog

## 0.06 (2026-05-05)

### Persistenz (Breaking Change)
- **Alle persistenten Daten liegen jetzt unter `/config/librephotos/`**:
  - `postgres/` – PostgreSQL-Datenverzeichnis
  - `protected_media/` – Thumbnails, Gesichter, ML-Modelle
  - `cache/` – Modell-Downloads (huggingface, pip)
  - `logs/`
  - `secret_key` – stabiler Django SECRET_KEY
- Updates und Addon-Rebuilds löschen die DB & Caches **nicht mehr**
- HA-Snapshots sichern automatisch alle LibrePhotos-Daten mit `/config`
- **Migration**: Bestehende User starten beim Update neu (DB im alten Container ist verloren)

## 0.05 (2026-05-05)
- Multi-Pfad-Zugriff via Symlinks unter /data (media + share)
- Auto-Erstellung des Scan-Ordners

## 0.04 (2026-05-05)
- X_FRAME_OPTIONS Patch für HA Ingress (vorher weißer Bildschirm)

## 0.03 (2026-05-05)
- PostgreSQL Crash-Loop behoben (dynamische Versionserkennung)
- pg_isready Wartelogik ergänzt

## 0.02 (2026-05-04)
- Refactor auf offizielles librephotos-unified Image

## 0.01 (2026-05-04)

### Initial Release
- LibrePhotos Backend (Django) Integration
- LibrePhotos Frontend (React) Integration
- PostgreSQL Datenbank (integriert)
- Redis Cache (integriert)
- Nginx Reverse Proxy
- Home Assistant Ingress Support
- Konfigurierbare Worker-Anzahl
- Automatische Datenbankinitialisierung
