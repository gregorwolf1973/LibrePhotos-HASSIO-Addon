# LibrePhotos – Home Assistant Add-on

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/gregorwolf1973)

Self-hosted photo management with AI face recognition, automatic scene classification and timeline view – integrated directly into Home Assistant.

## Features

- AI-powered face recognition and clustering
- Automatic scene and object detection (Places365)
- Timeline view by date
- Album management (auto, manual, shared)
- Map view for photos with GPS data (reverse geocoding via Nominatim)
- RAW, HEIC, MOV/MP4 video support
- Full-text search across captions, places and people
- Multi-user, with per-user libraries and sharing

## Installation

1. Add this repository to your Home Assistant add-on repositories:
   `https://github.com/gregorwolf1973/LibrePhotos-HASSIO-Addon`
2. Install the **LibrePhotos** add-on
3. Configure database password and admin credentials
4. Start the add-on

## Configuration

See [DOCS.md](DOCS.md) for full configuration details.

## Photo Sources

You don't need to configure any path. The add-on automatically links:

- `/data/media` → Home Assistant `/media`
- `/data/share` → Home Assistant `/share`

In the LibrePhotos UI, pick the desired sub-folder under **User menu → Library → Add scan directory**.

## Source

Based on [LibrePhotos](https://github.com/LibrePhotos/librephotos) – an open-source photo management project.

## Support

If this add-on is useful to you:

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/gregorwolf1973)
