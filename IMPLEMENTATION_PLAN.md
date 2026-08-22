# Warang — Implementation Plan

**For the implementing agent (GPT‑5.6 Luna).** Read this file completely before writing any code. Work top to bottom. Do not skip ahead, do not reorder phases, and do not "improve" decisions that are marked as settled — they were argued through and the reasoning is recorded here.

Repo: `C:\Users\User\Desktop\Warang` · Branch: `master` · No remote (local commits only).

---

## 1. What you are building

**Warang** (Aklanon: *to go out and explore*) is an offline-first Flutter app for the Philippines, Android first and iOS after.

A map you fill with your own photographs. You are somewhere — a cafe, a trail, a beach — you press one button, the camera opens, you shoot, and a photo-pin drops where you stood. Later you look back at a map covered in your own pictures.

It is **not** a game. It is **not** a social network. There is no server, no account, and no cloud. Sharing happens by rendering an image to the system share sheet, or by handing a `.travelbook` file to a friend.

---

## 2. Non-negotiables

These are settled decisions. If a task seems to require breaking one, **stop and ask the human** rather than working around it.

### Never do these

| Never | Why |
| :--- | :--- |
| Use **Isar** | Unmaintained; v4 never stabilised. Use **Drift**. |
| Use **`flutter_map_tile_caching`** | GPL‑3.0 — would force open-sourcing the whole app. |
| Use **`nearby_connections`** | Android-only; iOS ships after the pilot. |
| Use the **`geocoding`** package for addresses | It calls the network. Breaks the offline promise. |
| Store **absolute file paths** | The documents directory path changes across reinstall and backup/restore. This is the single most common data-loss bug in this category. Store paths **relative** to the documents dir and resolve at read time. |
| Use **sequential integer primary keys** | UUIDs only. Accounts and social are planned later; integer IDs collide the moment two people's data meets, and retrofitting is miserable. |
| **Hard-delete** rows | Soft-delete via `deletedAt`, so deletions can propagate later. |
| Add **login, signup, accounts, Firebase, or any network sync** | There is no backend. A login screen is a door with no building behind it. |
| Add **analytics or crash SDKs that phone home** | Contradicts the privacy promise the app is sold on. |
| Block a **capture** on GPS lock, a caption, or trip selection | Nothing may stand between the button and the shutter. |
| Add **gamification** — points, streaks, badges, fog of war | Explicitly rejected. This is a diary, not a game. |
| Fetch fonts at runtime via `google_fonts` default behaviour | It downloads on first use. Bundle the `.ttf` files as assets instead. |
| Put colour near a photograph | Photos are the only saturated thing on screen. |

### Always do these

- Every table gets `id` (UUID v4), `createdAt`, `updatedAt`, `deletedAt` (nullable), and `authorId`.
- Every capture succeeds even with no GPS fix, no caption, and no trip chosen.
- Both light and dark themes, following the system setting. Never invert — the dark palette is re-picked.
- The accent colour appears roughly **four times per screen maximum**.

---

## 3. Working protocol

### Commits

Commit after **every completed task**, not at the end of a phase.

**Before each commit, all three must pass:**

```
flutter analyze          # zero issues
flutter test             # all green
flutter build apk --debug   # compiles
```

If any fails, fix it before committing. Never commit a broken tree.

**Message format** — Conventional Commits, referencing the task ID:

```
feat(capture): save a moment without requiring GPS  [T5.4]

Captures now persist immediately with null coordinates when no fix is
available within 3s. The pin can be placed manually later.
```

Types: `feat` · `fix` · `refactor` · `test` · `chore` · `build` · `docs`

**With every commit, tick the task's checkbox in this file** and include this file in the same commit. That makes progress resumable if the session dies.

**Tag at each phase boundary:** `git tag phase-2-data`

**Never** force-push, rewrite history, or `--amend` a commit that already exists. If work is abandoned, commit the revert — do not silently delete.

### What not to commit

`.dart_tool/` · `build/` · `.idea/` · `*.iml` · `android/local.properties` · `*.jks` · `*.keystore` · `key.properties` · `ios/Pods/` · any secret, token, or signing material.

**Do commit** generated `.g.dart` / `.drift.dart` files, so a clean checkout compiles without running `build_runner` first.

### When you are blocked

Tasks marked **⛔ HUMAN** need a decision or an asset only Lenard can provide. Do the dev-time fallback described in the task, commit that, and leave the checkbox unticked with a note. Do not invent a substitute.

---

## 4. Stack

| Concern | Package | Note |
| :--- | :--- | :--- |
| State | `flutter_riverpod` | Works well with Drift's reactive streams. |
| Database | `drift` + `sqlite3_flutter_libs` | Gives FTS5 for search for free. |
| Paths | `path_provider`, `path` | App documents dir. |
| Map | `flutter_map`, `latlong2` | No FMTC. Custom MBTiles tile provider. |
| Camera | `image_picker` | Phase 5. A custom `camera` UI is a later upgrade, not MVP. |
| Images | `flutter_image_compress` | Re-encode + thumbnails. |
| Location | `geolocator` | Cross-platform, better maintained than `location`. |
| Permissions | `permission_handler` | Camera + location only. |
| Sharing | `share_plus` | System share sheet; no Instagram/Facebook APIs. |
| Archive | `archive` | `.travelbook` zip. |
| IDs | `uuid` | v4. |
| Dates | `intl` | |

Dev: `build_runner`, `drift_dev`, `flutter_lints`, `riverpod_lint`, `custom_lint`.

### Folder layout

```
lib/
  main.dart
  app/
    app.dart              # root widget, theme wiring
    router.dart
    theme/                # tokens, light/dark schemes, map palette extension
  core/
    ids.dart              # uuid helpers
    result.dart
  data/
    db/                   # drift database, tables, daos
    files/                # photo storage, relative-path resolution
    repos/
  features/
    onboarding/
    map/
    capture/
    moments/
    trips/
    search/
    share/
    travelbook/
    settings/
assets/
  fonts/
  tiles/                  # bundled .mbtiles
test/
```

---

## 5. Design tokens

Put these in `lib/app/theme/tokens.dart` as constants. Do not scatter hex literals through widgets.

**Accent — `#E8A020` (amber).** Anything sitting on the accent is dark `#231F0E`, **never white** — amber cannot carry white text legibly.

| Role | Light | Dark |
| :--- | :--- | :--- |
| ground | `#ECEDE8` | `#121410` |
| surface | `#F7F8F3` | `#1B1E18` |
| line | `#D2D5CB` | `#2E332A` |
| ink | `#1A1D18` | `#E9EBE3` |
| ink-soft | `#5C6157` | `#A0A697` |
| ink-faint | `#8A8F83` | `#767C6D` |

Map palette (a `ThemeExtension`, not part of the Material scheme):

| Role | Light | Dark |
| :--- | :--- | :--- |
| land | `#E6E7E0` | `#1A1D18` |
| land-alt | `#DCDED4` | `#22261F` |
| water | `#CBD8DA` | `#141B1E` |
| roads | `#F6F7F2` | `#2C3129` |

**Type** — bundled as assets, not fetched:
- Display: **Bricolage Grotesque** (700–800, tracking ≈ −0.02em) — screen titles, trip names
- Body: **Public Sans** (400–600)
- Mono: **DM Mono** (400–500) — dates, coordinates, counts. Use `FontFeature.tabularFigures()` wherever digits align.

Radius: `14` for cards and sheets; fully round for pins and the capture button.

---

## 6. Data model

All tables carry: `id TEXT` (UUID v4, primary key), `createdAt`, `updatedAt`, `deletedAt` (nullable), `authorId TEXT`.

**`Profiles`** — `name`, `avatarRelPath?`, `bio?`

**`Trips`** — `title`, `place?`, `description?`, `startDate?`, `endDate?`, `coverMomentId?`, `isEveryday BOOL`, `tagsJson`

**`Moments`** — `tripId` (**non-null** FK → Trips), `caption?`, `capturedAt`, `latitude?`, `longitude?`, `accuracyM?`, `placeLabel?` (user-typed only, never geocoded), `sortIndex`

**`Photos`** — `momentId` FK, `relPath`, `thumbRelPath`, `width`, `height`, `bytes`, `position`

> A separate `Photos` table replaces the original spec's `List<String> photoPaths`. It supports ordering, per-photo dimensions, and cleanup without rewriting a JSON blob.

**`AppMeta`** — key/value: `schemaVersion`, `activeProfileId`, `activeTripId`, `everydayTripId`

**FTS5 virtual table** over `Moments.caption`, `Moments.placeLabel`, `Trips.title`, `Trips.place`.

### The Everyday trip

Seeded on first run with `isEveryday = true`. Every capture that has no active trip lands here. **The user is never asked to pick a trip at capture time.** A trip is "active" when today falls between its `startDate` and `endDate`; if two qualify, use the most recently updated.

---

## 7. Phases

### Phase 0 — Scaffold
**Goal:** an empty app that builds and runs.

- [x] **T0.1** `flutter create` into the existing repo without clobbering `.git` or `warang-design-prompt.md`. Package id `ph.warang.app`.
- [x] **T0.2** Write `.gitignore` per §3.
- [ ] **T0.3** Add all dependencies from §4 to `pubspec.yaml`.
- [ ] **T0.4** Create the folder layout from §4 with a `.gitkeep` in each empty dir.
- [ ] **T0.5** Configure `analysis_options.yaml` with `flutter_lints` + `riverpod_lint`, and treat warnings as errors.
- [x] **T0.6** Wrap the app in `ProviderScope`.

**Acceptance:** `flutter run` shows a blank themed screen. `flutter analyze` is clean.
**Tag:** `phase-0-scaffold`

---

### Phase 1 — Design system
**Goal:** every colour and text style in the app comes from one place.

- [ ] **T1.1** ⛔ **HUMAN** — obtain `.ttf` files for Bricolage Grotesque, Public Sans, and DM Mono (all SIL Open Font License) and place in `assets/fonts/`. *Fallback while blocked:* declare the families in `pubspec.yaml` and let them fall back to system faces; do not use `google_fonts` runtime fetching.
- [x] **T1.2** `tokens.dart` — all colours from §5 as named constants.
- [x] **T1.3** Light and dark `ThemeData`, driven by system theme.
- [x] **T1.4** `MapPalette` as a `ThemeExtension` with both variants.
- [ ] **T1.5** Text theme: display / body / mono roles, tabular figures on mono.
- [ ] **T1.6** A debug-only `StyleGalleryScreen` showing every colour, text style, and the capture button in both themes.

**Acceptance:** the style gallery renders correctly in both themes; toggling the OS theme switches it live.
**Tag:** `phase-1-design-system`

---

### Phase 2 — Data layer
**Goal:** the database exists, is reactive, and cannot lose data.

- [ ] **T2.1** Drift tables per §6, with UUID text primary keys.
- [ ] **T2.2** Database class, migration strategy, `schemaVersion` in `AppMeta`.
- [ ] **T2.3** DAOs exposing `Stream` queries (`watch`) for moments, trips, and map pins.
- [ ] **T2.4** Soft-delete helpers. Every read filters `deletedAt IS NULL`.
- [ ] **T2.5** First-run seed: a default `Profile` and the `Everyday` trip.
- [ ] **T2.6** Riverpod providers exposing the DAOs.
- [ ] **T2.7** **Tests:** insert/read/soft-delete round-trip; deleted rows excluded from every query; Everyday seeded exactly once across repeated launches; UUIDs unique across 10k inserts.

**Acceptance:** tests green. No integer primary key anywhere.
**Tag:** `phase-2-data`

---

### Phase 3 — File storage
**Goal:** photos on disk, addressed relatively, never orphaned.

- [ ] **T3.1** `PhotoStore`: `<documents>/warang/photos/<yyyy>/<MM>/<uuid>.jpg` and `.../thumbs/<uuid>.jpg`.
- [x] **T3.2** `resolve(String relPath) → File` — the **only** place a relative path becomes absolute.
- [ ] **T3.3** Import pipeline: re-encode originals to max 2000px long edge (quality ≈ 85), generate a 320px thumbnail. The re-encoded file *is* the original; do not keep the camera's raw output.
- [ ] **T3.4** Orphan sweep: delete files with no live `Photos` row, and rows whose file is missing.
- [ ] **T3.5** **Tests:** stored paths are relative and contain no drive letter or leading `/`; resolution round-trips; a simulated documents-dir change still resolves; orphan sweep removes only orphans.

**Acceptance:** grepping the DB for `/data/` or `C:\` returns nothing.
**Tag:** `phase-3-files`

---

### Phase 4 — Map surface
**Goal:** a stylized offline map fills the screen.

- [ ] **T4.1** ⛔ **HUMAN** — a bundled stylized `.mbtiles` basemap. Needs generating from an OSM extract (tilemaker or planetiler) with a Warang style, or sourcing. *Fallback while blocked:* a `TileProvider` that reads a network OSM source behind a `kDevTiles` flag, so map work can proceed. **This fallback must not ship.**
- [ ] **T4.2** `MbTilesTileProvider` — a `flutter_map` `TileProvider` reading tiles from the bundled SQLite MBTiles file. Do **not** add FMTC.
- [x] **T4.3** Full-bleed map on the home screen, no app bar over it.
- [ ] **T4.4** Position marker: amber dot, soft halo, heading cone. Not the mascot.
- [ ] **T4.5** Recenter button, bottom right.
- [x] **T4.6** Capture button, bottom centre, amber with a dark glyph. Wired to nothing yet.
- [x] **T4.7** Sheet handle peeking from the bottom edge.

**Acceptance:** map renders in both themes with the correct palette, in airplane mode when T4.1 is unblocked.
**Tag:** `phase-4-map`

---

### Phase 5 — Capture
**Goal:** the core loop. Button to saved moment in about three seconds.

- [ ] **T5.1** Permission priming for camera and location, in plain language, before the system prompt.
- [x] **T5.2** Capture button opens the camera immediately via `image_picker`.
- [x] **T5.3** Request a GPS fix in parallel with the camera, timeout **3 seconds**.
- [x] **T5.4** Save screen: photo, optional caption field (`"Say something (optional)"`), auto-filled place and time in mono, one amber **Save**.
- [x] **T5.5** Save writes the moment, assigns the active trip or Everyday, runs the photo pipeline, and returns to the map.
- [ ] **T5.6** **No GPS is not an error.** Save with null coordinates and surface a quiet "Add location" affordance on the moment later.
- [ ] **T5.7** **Tests:** a moment saves with null lat/lng; a moment saves with an empty caption; a capture with no active trip lands in Everyday.

**Acceptance:** on a real device, cold app to saved moment in under five seconds, with no dialog other than the camera.
**Tag:** `phase-5-capture`

---

### Phase 6 — Pins and clustering
**Goal:** the map fills with your photographs.

- [x] **T6.1** Photo-pin: circular thumbnail, surface-coloured ring, small pointer beneath.
- [ ] **T6.2** Clustering by zoom. Clusters render as a solid amber circle with a **dark** count.
- [ ] **T6.3** Pins stream reactively from Drift — a new capture appears without a manual refresh.
- [ ] **T6.4** Thumbnail memory cache; never decode full-size images for pins.
- [ ] **T6.5** **Tests:** clustering maths — points within the threshold group, points outside do not, counts are correct at each zoom level.

**Acceptance:** 500 seeded moments pan and zoom without dropping frames.
**Tag:** `phase-6-pins`

---

### Phase 7 — Moment card
- [x] **T7.1** Tapping a pin dims the map and raises a card: photo, caption, place and date in mono.
- [ ] **T7.2** Horizontal swipe through nearby moments, with position dots.
- [ ] **T7.3** Quiet icon actions: share, edit, delete (soft).
- [ ] **T7.4** Edit sheet: caption, place label, date, manual pin placement for moments with no coordinates.
- [ ] **T7.5** The map stays visible behind the card at all times.

**Tag:** `phase-7-moment-card`

---

### Phase 8 — Trips sheet
- [ ] **T8.1** `DraggableScrollableSheet` over the map, three snap points.
- [ ] **T8.2** Everyday pinned at the top; real trips below as wide cards with cover, title, date range, and moment count.
- [ ] **T8.3** Trip detail: grid of moments, edit title/place/dates, set cover.
- [ ] **T8.4** Create a trip; move moments from Everyday into it (multi-select).
- [ ] **T8.5** Planned trips (start date in the future) carry a visible "Planned" chip so an empty card does not read as broken.

**Tag:** `phase-8-trips`

---

### Phase 9 — Search
- [ ] **T9.1** FTS5 virtual table + triggers keeping it in sync with `Moments` and `Trips`.
- [ ] **T9.2** Search UI in the sheet: live results across captions, place labels, and trip titles.
- [ ] **T9.3** Date-range filter.
- [ ] **T9.4** **Tests:** FTS index updates on insert, update, and soft-delete; deleted moments never appear in results.

**Tag:** `phase-9-search`

---

### Phase 10 — Sharing
**Goal:** the app's only distribution channel. Make it good.

- [ ] **T10.1** Render pipeline: `RepaintBoundary` → `toImage` → PNG in a temp dir.
- [ ] **T10.2** **9:16 only.** Trip collage: grid of photos, title in the display face, dates in mono, small "Warang" wordmark in a corner.
- [ ] **T10.3** Collage photo selection auto-spread across the trip's date range — not six from day one — with tap-to-swap on any slot.
- [ ] **T10.4** Moment card format: photo + place + date + corner mark.
- [x] **T10.5** "Just the photo" — raw file, **no branding**.
- [ ] **T10.6** "All photos" — multi-file share; Instagram builds its own carousel.
- [ ] **T10.7** Preview screen before every share. No exceptions.
- [ ] **T10.8** Copy a caption to the clipboard on share (e.g. `Bohol Summer 2025 · 24 moments`).
- [x] **T10.9** Hand off via `share_plus`. No Instagram or Facebook APIs.

**Tag:** `phase-10-share`

---

### Phase 11 — `.travelbook`
**Goal:** trips move between phones as files. Treat every imported file as hostile.

- [x] **T11.1** Export: zip of `manifest.json` (with a `formatVersion`) + photos, extension `.travelbook`.
- [x] **T11.2** Import with **zip-slip guards** — reject any entry whose resolved path escapes the destination directory. The `archive` package will happily write `../../` otherwise.
- [x] **T11.3** Enforce caps: total uncompressed size, entry count, per-file size. Reject anything exceeding them.
- [ ] **T11.4** Validate every image actually decodes before it is stored.
- [ ] **T11.5** Imported trips are marked read-only and visually distinguished from your own.
- [x] **T11.6** Re-importing the same file updates rather than duplicating (match on trip UUID).
- [x] **T11.7** Reject unknown `formatVersion` with a clear message rather than guessing.
- [ ] **T11.8** **Tests:** a crafted zip with `../` entries is rejected; an oversized archive is rejected; a corrupt image is rejected; double import produces one trip.

**Acceptance:** the hostile-archive tests pass. This phase is not done until they do.
**Tag:** `phase-11-travelbook`

---

### Phase 12 — First run and settings
- [x] **T12.1** First run: the maya, "Warang", the line *"A map you fill with your own photographs."*, a name field (local only), and a **Start** button. Plain-language note that nothing leaves the phone. **No login screen.**
- [ ] **T12.2** Empty map state: centred on the user's city, no pins, one quiet prompt — *"Capture your first moment."*
- [x] **T12.3** Settings — You · Storage · Map · Sharing · About. No account section, no sync, no sign-out.
- [ ] **T12.4** Storage section shows real space used, with the orphan sweep exposed as "Clean up".
- [ ] **T12.5** The maya appears only here and on the app icon. Never over a map with photos on it.

**Tag:** `phase-12-onboarding-settings`

---

### Phase 13 — Backup
**Goal:** uninstalling must not destroy years of photographs.

- [ ] **T13.1** "Back up everything" — a full archive of the database plus all photos.
- [ ] **T13.2** Hand it to the system share sheet so the user can put it in their own Drive, iCloud, or SD card. **No Warang server.**
- [ ] **T13.3** Restore from a backup archive, reusing the Phase 11 security guards.
- [ ] **T13.4** A gentle nudge if no backup has been made in 30 days.
- [ ] **T13.5** **Tests:** backup then restore into an empty install reproduces every moment, photo, and trip exactly.

**Tag:** `phase-13-backup`

---

### Phase 14 — Pilot hardening
- [ ] **T14.1** Remove the `kDevTiles` network fallback. Verify the app is fully functional in airplane mode from a cold start.
- [ ] **T14.2** Audit: no absolute paths in the DB, no network calls anywhere, no analytics.
- [x] **T14.3** Android permissions audit — camera and location only. Nothing else.
- [ ] **T14.4** App icon (maya on amber) and splash.
- [ ] **T14.5** Release build, signed, installed on a physical device.
- [ ] **T14.6** Battery check: an hour of normal use should not show unusual drain. GPS must not be running continuously.

**Tag:** `phase-14-pilot`

---

## 8. Definition of done for the pilot

1. Airplane mode, cold start: the map renders, capture works, pins appear.
2. Capture to saved in under five seconds with no dialogs beyond the camera.
3. Uninstall and reinstall after a backup restores everything.
4. A hostile `.travelbook` cannot write outside the app's directory.
5. `flutter analyze` clean, all tests green.
6. Zero network calls. Verify with a proxy or by monitoring, not by assumption.
