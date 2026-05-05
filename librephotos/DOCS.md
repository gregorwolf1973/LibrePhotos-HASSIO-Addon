# LibrePhotos - Home Assistant Addon

## Konfiguration

### `scan_directory`
Pfad zum Standard-Fotoordner. Wird beim Start automatisch unter `/data/<name>` 
verlinkt und in der LibrePhotos-UI auswählbar.  
Standard: `/media/photos`

**Zusätzlich** werden automatisch verlinkt (falls vorhanden):
- `/data/media` → HA `/media` (alle Medien-Verzeichnisse)
- `/data/share` → HA `/share` (geteilte Verzeichnisse)

So kannst du in der LibrePhotos-UI bei "Tools → Library → Add scan directory"
zwischen mehreren Quellen wählen.

### Externe Festplatten (z.B. /mnt/sdb1)

HA-Addons können nicht direkt auf Host-Pfade wie `/mnt/sdb1` zugreifen. Du musst
externe Laufwerke zuerst in Home Assistant einbinden:

1. **HA Web-UI** → Settings → System → Storage
2. **Add Drive** → wähle deine USB-Disk (sdb1)
3. Mountpoint wählen: `media` oder `share`
4. Im Addon erscheint die Disk dann unter `/data/media/<Diskname>` bzw. `/data/share/<Diskname>`

### `db_password`
Passwort für die interne PostgreSQL-Datenbank.  
**Wichtig:** Ändere das Standardpasswort vor dem ersten Start!

### `workers`
Anzahl der Gunicorn-Worker-Prozesse (1-8).  
- 2 Worker: empfohlen für Systeme mit 4GB RAM
- 4 Worker: empfohlen für Systeme mit 8GB RAM

### `log_level`
Log-Level für die Ausgaben. Standard: `info`

## Erste Schritte

1. Addon installieren und starten
2. Warte bis das Addon vollständig gestartet ist (ca. 2-3 Minuten beim ersten Start)
3. Öffne das Web-Interface über das Seitenleisten-Icon
4. Erstelle einen Admin-Account beim ersten Login
5. Gehe zu `Einstellungen → Scan` und starte den ersten Foto-Scan

## Speicheranforderungen

- **RAM**: Mindestens 4 GB (8 GB empfohlen)
- **CPU**: Mindestens 2 Kerne
- **Speicher**: 10 GB + Größe der Fotobibliothek

## Bekannte Einschränkungen

- GPU-Beschleunigung für KI-Erkennung wird nicht unterstützt
- Der erste Start und der erste Scan können mehrere Minuten dauern
- Gesichtserkennung und Szenenklassifizierung benötigen viel CPU-Zeit

## Fehlerbehebung

### Addon startet nicht
Überprüfe ob der `scan_directory` Pfad existiert und lesbar ist.

### Webinterface nicht erreichbar
Warte 2-3 Minuten nach dem Start. Die Initialisierung beim ersten Start dauert länger.

### Fotos werden nicht gefunden
Stelle sicher dass der Pfad in `scan_directory` korrekt ist und das Addon Leserechte hat.
