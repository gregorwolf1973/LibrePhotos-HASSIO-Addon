# LibrePhotos – Home Assistant Add-on

## Photo Sources

**You don't need to configure a path.** The add-on automatically mounts:

- `/data/media` → HA `/media` (all media directories)
- `/data/share` → HA `/share` (shared directories)

In the LibrePhotos UI, go to **User menu → Library → Add scan directory** and choose the sub-folder you want, e.g.:
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
Log verbosity. Default: `info`.

### `admin_username` / `admin_password` / `admin_email`
Credentials of the initial superuser account that is created on first start.

## Getting Started

1. Install and start the add-on
2. Wait until it has fully started (5–15 minutes on first start – ML models are downloaded)
3. Open the web interface via the **"OPEN WEB UI"** button on the add-on tab
   (or directly at `http://homeassistant.local:8001`)
4. Log in with the configured `admin_username` / `admin_password`
5. **Change the password immediately**: User menu → Settings → Change Password
6. Go to **Tools → Library → Scan Photos** and start the first photo scan

## Adding LibrePhotos to the HA Sidebar (optional)

Because HA Ingress is incompatible with the LibrePhotos SPA, add a sidebar icon manually via `panel_iframe` in your `configuration.yaml`:

```yaml
panel_iframe:
  librephotos:
    title: "LibrePhotos"
    icon: mdi:image-multiple
    url: "http://homeassistant.local:8001"
    require_admin: true
```

After an HA restart LibrePhotos appears in the sidebar.

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

If this add-on helps you, consider buying me a coffee:

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/gregorwolf1973)
