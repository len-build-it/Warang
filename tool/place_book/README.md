# Warang Place Book Builder

This directory builds Warang's bundled offline Philippine place book (`assets/place_book/place_book.sqlite`) from OpenStreetMap data.

## Source

- **Provider:** Geofabrik Philippines OpenStreetMap extract
- **Download URL:** `https://download.geofabrik.de/asia/philippines-latest.osm.pbf`
- **Extract used for initial build:** `philippines-latest.osm.pbf` (`614,820,870` bytes), replication timestamp `2026-11-22T21:20:48Z` (`source_date = 2026-11-22`).
- **Licence:** Data is from OpenStreetMap contributors and is available under the Open Database License (ODbL 1.0). Places and map (c) OpenStreetMap contributors.

## Setup

Create a local virtual environment (ignored by Git via `.gitignore`) and install the pinned dependency:

```bash
python -m venv tool/place_book/.venv
tool/place_book/.venv/Scripts/python.exe -m pip install -r tool/place_book/requirements.txt
```

## Build command

Download the latest Philippines extract (also ignored by Git via `*.osm.pbf`):

```bash
curl -fSL -o tool/place_book/philippines-latest.osm.pbf https://download.geofabrik.de/asia/philippines-latest.osm.pbf
```

Build the bundled SQLite file:

```bash
tool/place_book/.venv/Scripts/python.exe tool/place_book/build_place_book.py \
  --pbf tool/place_book/philippines-latest.osm.pbf \
  --out assets/place_book/place_book.sqlite
```

## Determinism and release rebuilds

Running `build_place_book.py` twice on the same `.osm.pbf` produces byte-identical `.sqlite` files because rows are sorted by `osm_ref`, `source_date` and `built_at` are derived from the PBF replication timestamp, and the database is vacuumed at the end.

To refresh the place book for a future release:

1. Download a fresh `philippines-latest.osm.pbf` from Geofabrik.
2. Run `build_place_book.py` into `assets/place_book/place_book.sqlite`.
3. Update the extract date in this file and verify the REQ-003 size budget (file at most 40 MB, arm64 release APK growth at most 25 MB).
4. Commit the updated `assets/place_book/place_book.sqlite` and `README.md`.
