<div align="center">

<img src="design/warang-maya.png" alt="Warang" width="120" />

# Warang

**An offline-first map of your own photographs.**

Aklanon: *warang* — going out and exploring.

</div>

---

Most photo apps give you a scrolling wall of images. Warang gives you a map.

Open it and you see where you are. Tap once and the camera is already open. The photo you take drops a pin exactly where you stood. Months later, zoom out — and the payoff is a map of everywhere you've been, filled in with your own pictures.

No account. No feed. No servers holding your memories. Warang works with the radio off.

## What it does

**Capture in one tap.** The button opens the camera immediately. Location is read at the moment of capture — never in the background, never continuously — so it costs you almost no battery. Captions and details are optional and can be added later. A missing GPS lock never blocks a shot; you can place the pin yourself afterwards.

**A map, not a grid.** The home screen is the map. Pins are your photos. Repeat visits to the same spot cluster into one pin with a count, so a favourite café doesn't bury a whole city.

**Moments over the map.** Tapping a pin opens a card on top of the map — photo, place, date — and you swipe sideways through nearby memories. You never leave the map to browse.

**Trips.** Pull up the sheet from the bottom for trips and a timeline. Everyday shots file themselves automatically; promote them into a real trip whenever you want.

**Share on your terms.** From a single moment: the raw photo, or a moment card. From a trip: a collage, all photos, or a portable `.travelbook` file. Every path shows you a preview before anything leaves the app, and no map image is ever exported — your coordinates stay yours.

**Search.** Full-text search across captions and places, offline.

**Yours to keep.** Export everything to a `.travelbook` archive and put it wherever you like — your own Drive, iCloud, a hard disk. There is no cloud to lock you in and none to lock you out.

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
| Sharing | `share_plus` |
| Archives | `archive` (`.travelbook` export/import) |

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
    home/         Map home screen
    map/          Map surface and offline tile store
    onboarding/   First run
    settings/     Settings
    share/        Share formats and previews
    travelbook/   .travelbook export and import
    trips/        Trips sheet
docs/             Implementation plan and design spec
design/           Brand assets and the design canvas export
assets/           Fonts and logos
test/             Widget and data-layer tests
```

## Privacy

Warang makes no account, no sync, no analytics, and no geocoding calls. Photos and locations live in the app's own storage on your device and are never uploaded. Map tiles are the only thing fetched from the network, and they are cached so the app keeps working without it.

## License

Not yet licensed — all rights reserved for now.
