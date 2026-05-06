# Changelog

## 0.08 (2026-05-06)

### scan_directory entfernt - Foto-Quellen werden automatisch erkannt
- `scan_directory` Option ist weg. Es gibt nichts mehr zu konfigurieren.
- `/media` und `/share` werden automatisch unter `/data/media` bzw.
  `/data/share` verlinkt
- Der User wählt in der LibrePhotos-UI direkt unter Library den Pfad
  (z.B. `/data/media/photoprism/originals`)

## 0.07 (2026-05-05)

### Ingress entfernt, "OPEN WEB UI"-Button stattdessen
- `ingress: false` weil LibrePhotos' SPA hardcoded API-Pfade hat die
  inkompatibel mit HA Ingress-URL-Prefixen sind (weißer Bildschirm)
- `webui:` Property zeigt einen "OPEN WEB UI"-Button im Addon-Tab,
  der direkt auf `http://homeassistant.local:8001` verlinkt
- Optional: User können in HA's `configuration.yaml` ein `panel_iframe`
  einrichten um LibrePhotos in die Sidebar zu bekommen

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
