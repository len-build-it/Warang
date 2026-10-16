<div align="center">

<img src="design/warang-maya.png" alt="Warang" width="120" />

# Warang

**An offline-first map of your own photographs.**

Aklanon: *warang* — going out and exploring.

</div>

---

Most photo apps give you a scrolling wall of images. Warang gives you a map.

Open it and you see where you are. Tap once and the camera is already open. The photo you take drops a pin exactly where you stood. Months later, zoom out — and the payoff is a map of everywhere you've been, filled in with your own pictures.

No account. No feed. No servers holding your memories. Previously visited map
areas remain visible with the radio off; uncached areas need a connection for
OpenStreetMap tiles.

## What it does

**Capture in one tap.** The button opens the camera immediately. Location is
read at capture time, never continuously or in the background. A missing GPS
lock never blocks saving the photograph.

**A map, not a grid.** The home screen is the map. Pins are your photos. Repeat visits to the same spot cluster into one pin with a count, so a favourite café doesn't bury a whole city.

**Moments over the map.** Tapping a pin opens its photograph, caption, place,
and date over the live map.
Edit adds or changes the caption, a place name, and the trip, and a photo taken without GPS can be pinned by hand.
Delete can be undone for a few seconds.

**Trips.** Give a trip dates and every photo taken on those days goes into it; the capture screen says which trip a photo will join.
Moments can also be moved into a trip by hand, and deleting a trip moves its moments back to Everyday.

**Home.** The Home tab lists Everyday and user-created trips, with local
moment, place, and day counts and capture-trend charts.

**News.** The News tab contains a small bundled set of offline travel notes.

**Search.** Full-text search across captions and places, offline.

Backup, restore, sharing, and `.travelbook`
import/export are tracked in
[`docs/REMEDIATION_IMPLEMENTATION_PLAN.md`](docs/REMEDIATION_IMPLEMENTATION_PLAN.md)
and are not exposed as finished features yet.

## Design

Warang is deliberately quiet. Three rules govern every screen:

- Photos are the only saturated thing on screen.
- The accent colour appears at most four times per screen.
- Nothing slows down a capture.

Amber `#E8A020` against sage-grey neutrals, in both light and dark, following your system theme. Typeset in Bricolage Grotesque, Public Sans, and DM Mono — bundled, not fetched. The mascot is the maya, the small brown sparrow you see everywhere in the Philippines, here carrying a camera.

## Built with

| | |
|---|---|
| Framework | Flutter (Dart SDK ^3.12.2) |
| State | Riverpod |
| Database | Drift over SQLite, with FTS5 search |
| Map | `flutter_map` + `latlong2`, cache-first custom tile provider |
| Location | `geolocator`, one-shot reads only |
| Planned sharing/archive primitives | `share_plus` + `archive` (not exposed yet) |

Android first, iOS to follow. No platform-only dependencies.

## Running it

You'll need the [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
git clone <repo-url>
cd Warang
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift codegen
flutter run
```

To build a release APK for a real device:

```bash
flutter build apk --release --split-per-abi
```

Install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` on most modern Android phones.

Run the tests with:

```bash
flutter test
```

## Repository layout

```
lib/
  app/            App shell, theme tokens, shared components
  core/           Models and id generation
  data/           Drift database, DAOs, repository, photo storage
  features/
    capture/      Camera and save flow
    home_tab/     Trips shelf and local summaries
    map/          Map surface and offline tile store
    news_tab/     Bundled offline notes
    onboarding/   First run
    settings/     Settings
    share/        Planned share hand-off primitive
    travel_mode/  Capture, map, search, and moment cards
    travelbook/   Unexposed archive service under remediation
docs/             Implementation plan and design spec
design/           Brand assets and the design canvas export
assets/           Fonts and logos
test/             Widget and data-layer tests
```

## Privacy

Warang makes no account, no sync, no telemetry, and no geocoding calls. Photos
and locations live in the app's own storage and are never uploaded by Warang.
OpenStreetMap tiles are the only network fetch, which means OpenStreetMap's servers see which map areas you view; tiles are cached for revisiting
areas offline. Android cloud backup and device transfer are disabled for the app's data.

## License

Not yet licensed — all rights reserved for now.
