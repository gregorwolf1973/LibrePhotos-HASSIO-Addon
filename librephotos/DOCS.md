# LibrePhotos – Home Assistant Add-on

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/gregorwolf1973)

## Photo Sources

**You don't need to configure a path.** The add-on automatically mounts:

- `/data/media` → HA `/media` (all media directories)
- `/data/share` → HA `/share` (shared directories)

In the LibrePhotos UI, open the **user menu (avatar, top right) → Library** and set the scan directory there (it is also offered during the first-time setup). Choose the sub-folder you want, e.g.:
- `/data/media/photoprism/originals`
- `/data/media/photos`
- `/data/share/family-photos`

### External drives (e.g. USB disks)

HA add-ons cannot access raw host paths like `/mnt/sdb1` directly. Mount external drives in Home Assistant first:

1. **HA Web UI** → Settings → System → Storage
2. **Add Drive** → pick your USB disk
3. Mount point: `media` or `share`
4. The disk shows up inside the add-on under `/data/media/<DiskName>`

## Configuration

### `db_password`
Password for the internal PostgreSQL database.
**Important:** change the default password before first start!

### `workers`
Number of Gunicorn worker processes (1–8).
- 2 workers: recommended for systems with 4 GB RAM
- 4 workers: recommended for systems with 8 GB RAM

### `log_level`
Log verbosity. Default: `info`. Applies to the add-on's start-up script and is
passed to the LibrePhotos backend as its `LOG_LEVEL` (`trace`/`debug` → `DEBUG`,
`info`/`notice` → `INFO`, `warning` → `WARNING`, `error` → `ERROR`,
`fatal` → `CRITICAL`). Takes effect after an add-on restart.

### `admin_username` / `admin_password` / `admin_email`
Credentials of the initial superuser account that is created on first start.

## Getting Started

1. Install and start the add-on
2. Wait until it has fully started (5–15 minutes on first start – ML models are downloaded)
3. Open the web interface via the **"OPEN WEB UI"** button on the add-on tab
   (or directly at `http://homeassistant.local:8001`)
4. Log in with the configured `admin_username` / `admin_password`
5. **Change the password immediately**: user menu (avatar, top right) → Settings → Change Password
6. Open the **user menu (avatar, top right) → Library** and start the first scan
   in the **Scan Library** row

## Adding LibrePhotos to the HA Sidebar (optional)

The add-on runs without Ingress (the LibrePhotos SPA is incompatible with it),
so there is no "Show in sidebar" toggle on the add-on page. The old
`panel_iframe:` YAML integration no longer exists in current Home Assistant
versions – use a dashboard with a webpage card instead:

1. **Settings → Dashboards → Add dashboard → New dashboard from scratch**
   Give it the name "LibrePhotos", pick an icon (e.g. `mdi:image-multiple`)
   and enable **Show in sidebar**.
2. Open the new dashboard → **Edit** (pencil) → **Add card → Webpage**.
3. URL: `http://homeassistant.local:8001` (or your HA host's IP and port 8001).
4. Set the card to full height (card configuration → *Aspect ratio*, or use a
   panel view: **Edit dashboard → view settings → View type: Panel (1 card)**).

The dashboard then appears in the sidebar and shows LibrePhotos directly.

## Storage Requirements

- **RAM**: at least 4 GB (8 GB recommended)
- **CPU**: at least 2 cores
- **Disk**: 10 GB + size of your photo library

## Persistence

All persistent state lives under `/config/librephotos/`:

- `postgres/` – PostgreSQL data directory
- `protected_media/` – thumbnails, faces, ML models
- `cache/` – model downloads (HuggingFace, pip)
- `logs/`
- `secret_key` – stable Django SECRET_KEY (sessions / JWT)

Add-on updates and rebuilds **do not** wipe your database or thumbnails. Home Assistant snapshots automatically include all LibrePhotos data via `/config`.

## Known Limitations

- No GPU acceleration for the ML models
- First start and first full scan can take several minutes
- Face recognition and scene classification are CPU-heavy
- Nominatim public API is rate-limited to ~1 request/sec → reverse-geocoding 10 000 photos takes ~3 h
- Thumbnail generation may fail for some niche RAW formats or video codecs – affected files remain visible but without a thumbnail

## Troubleshooting

### Add-on does not start
Check the add-on log. Common causes: low disk space under `/config`, corrupted PostgreSQL data directory.

### Web interface unreachable
Wait 2–3 minutes after start. First-time initialisation takes longer than a normal restart.

### Places ("Orte") stays empty although photos have GPS data
Make sure **Map API Provider** is set to `nominatim` (Settings page in the UI). Then trigger a full **Library → Rescan Photos**. Reverse geocoding runs through the Django-Q worker queue and respects the Nominatim rate limit.

### "Photo has no thumbnail" errors during face scan
Some video / RAW / HEIC files cannot be thumbnailed inside the container. They do not break the scan – LibrePhotos skips them.

## Support

If this add-on helps you, consider [buying me a coffee](https://buymeacoffee.com/gregorwolf1973).
