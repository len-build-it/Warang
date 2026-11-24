# AUDIT-001: Code quality audit

Created: 2026-11-24T07:13:00+08:00
Updated: 2026-11-24T08:27:00+08:00
Revision: 2 (corrections from a Claude Code review of revision 1 at `946b3d7`; re-verified by Gemini on 2026-11-24)
Audited commit: `7d6703f` (`docs(plan): FEAT-004 phase 8 - polish and documents`)
Flutter version: `Flutter 3.44.7` (channel stable, revision `84fc5cbb22`, `Dart 3.12.2`)

## Summary

This audit reviewed all 49 hand-written Dart files under `lib/` (15080 lines), all tests under `test/` and `tool/ux_screenshots_test.dart`, Android Gradle and manifest configs, `tool/place_book/`, `scripts/build-and-archive.*` (untracked in Git), and tracked assets.
Zero application files were edited.
Of 77 raw candidates logged across automated scans and full manual reading, 15 merged into findings with the same root cause, 50 survived as verified findings (`AUD-001` to `AUD-050`), and 12 were rejected in the appendix.
Revision 2 added `AUD-051`, found during the review, for 51 findings.
Revision 2 also withdrew three false sub-claims, corrected wrong names or code descriptions in nine findings, and lowered seven severities; [Appendix: revision 2 corrections](#appendix-revision-2-corrections) lists every change.
Finding IDs stay stable, so after the severity changes the findings inside each section are no longer strictly ranked by severity.

| Category | Critical | High | Medium | Low | Total |
| --- | --- | --- | --- | --- | --- |
| Dangerous | 1 | 4 | 11 | 7 | 23 |
| Unnecessary | 0 | 0 | 2 | 5 | 7 |
| Sloppy | 0 | 0 | 6 | 15 | 21 |
| Total | 1 | 4 | 19 | 27 | 51 |

- Verified status breakdown: 32 `Confirmed`, 19 `Plausible`.
- Total removable code lines: 259 lines across 7 findings (plus 17 undeclared binary and HTML files totaling about 3.0 MB of checkout size in `AUD-026`).
- Removable direct dependencies: 0 (all 13 direct non-SDK dependencies in `pubspec.yaml` are in use, though `sqlite3_flutter_libs` is marked end-of-life in `AUD-019`).
- Five findings to fix first: `AUD-001` (release APKs omit the `INTERNET` permission, so the map cannot load tiles), `AUD-002` (fresh map tiles revalidate on every view with no HTTP timeout and a full-table size query per write), `AUD-004` (photo decode, resize, and encode run on the UI isolate, and avatar picks are decoded at full resolution), `AUD-005` (system Back and Close leave the capture and trip forms mid-save), and `AUD-006` (multi-step moment edits and pin placement write outside one transaction).

## How findings were verified

Each finding records its verification method code and status.

- `V1 reference proof`: a `git grep` across `lib`, `test`, and `tool` (or `android`) shows zero callers, one implementation, or one call site.
- `V2 tool output`: `flutter analyze`, `dart fix --dry-run`, `flutter pub outdated`, or a committed scan script reports the hit.
- `V3 reproduction probe`: a temporary test under `test/_audit_probe/` reproduces the failure without editing `lib/`, then is deleted before staging.
- `V4 call chain trace`: a step-by-step `path:line` trace from app startup or user action to the problem line when a probe is impractical without editing `lib/` or running on a device.
- `V5 documentation reference`: an official API name and URL on `api.dart.dev`, `api.flutter.dev`, or `developer.android.com`.

Statuses:

- `Confirmed`: proven by `V1`, `V2`, or `V3`, and rerun in Phase 3 at HEAD with the same result.
- `Plausible`: supported by `V4` or `V5` only, with no contradicting evidence.
- `Rejected`: the proof failed, an approved decision requires the code with no stated cost, or FEAT-002 already handled the item.

Scan artifacts committed under `docs/audits/AUDIT-001/scans/`:

- [00-inventory.txt](AUDIT-001/scans/00-inventory.txt): tracked file line counts, direct dependencies, `dart pub deps`, `flutter pub outdated`, and 30 largest tracked files.
- [01-strict-lints.txt](AUDIT-001/scans/01-strict-lints.txt): strict analyzer pass with 20 extra lint rules in a detached worktree (159 hits).
- [02-dart-fix.txt](AUDIT-001/scans/02-dart-fix.txt): `dart fix --dry-run` output in the detached worktree (74 proposed fixes in 30 files).
- [03-dependency-use.txt](AUDIT-001/scans/03-dependency-use.txt): import counts for every dependency in `pubspec.yaml`.
- [04-asset-use.txt](AUDIT-001/scans/04-asset-use.txt): asset references and undeclared files under `assets/` and `design/`.
- [05-unused-symbols.txt](AUDIT-001/scans/05-unused-symbols.txt): public symbol reference scan from `public_symbols.py`.
- [06-catch.txt](AUDIT-001/scans/06-catch.txt): `catch`, `catchError`, and `onError` scan over `lib/`.
- [07-null-and-late.txt](AUDIT-001/scans/07-null-and-late.txt): non-null assertion (`!`) and `late` counts over `lib/`.
- [08-dynamic-and-casts.txt](AUDIT-001/scans/08-dynamic-and-casts.txt): `dynamic` and `as` casts over `lib/`.
- [09-async-gaps.txt](AUDIT-001/scans/09-async-gaps.txt): methods with `await` followed by `setState`, `context.`, or `ref.`.
- [10-lifecycle.txt](AUDIT-001/scans/10-lifecycle.txt): controller, focus node, subscription, and timer disposal audit.
- [11-sql-and-fts.txt](AUDIT-001/scans/11-sql-and-fts.txt): raw SQL, FTS5 `MATCH`, and interpolated query strings.
- [12-files.txt](AUDIT-001/scans/12-files.txt): filesystem read, write, rename, and delete sites.
- [13-network.txt](AUDIT-001/scans/13-network.txt): HTTP client, tile layer, and URL usage.
- [14-debug-and-markers.txt](AUDIT-001/scans/14-debug-and-markers.txt): `print`, `debugPrint`, `TODO`, and `ignore` comments across `lib`, `test`, and `tool`.
- [15-hardcoded-style.txt](AUDIT-001/scans/15-hardcoded-style.txt): hardcoded colors, insets, durations, and font sizes outside `lib/app/theme/`.
- [16-time-and-random.txt](AUDIT-001/scans/16-time-and-random.txt): `DateTime.now()` and `Random()` calls across `lib`, `test`, and `tool`.
- [17-complexity.txt](AUDIT-001/scans/17-complexity.txt): file lengths and approximate brace-matched methods over 60 lines from `complexity.py`.
- [18-duplicates.txt](AUDIT-001/scans/18-duplicates.txt): normalized 8-line duplicate windows from `duplicates.py`.
- [19-android.txt](AUDIT-001/scans/19-android.txt): Android manifests and `build.gradle.kts` review.
- [20-tooling.txt](AUDIT-001/scans/20-tooling.txt): `tool/place_book/` and `scripts/build-and-archive.*` review.
- [21-tests.txt](AUDIT-001/scans/21-tests.txt): tests without direct `expect()`, real-time delays, and long fixed pumps.
- [22-report-check.txt](AUDIT-001/scans/22-report-check.txt): automated validation of this report from `check_report.py`.
- [23-identifier-check.txt](AUDIT-001/scans/23-identifier-check.txt): revision 2 check from `check_identifiers.py` that lists every code identifier a finding names but the repository does not contain, for review by hand.

## Dangerous

### AUD-001: Release builds omit `android.permission.INTERNET` and cannot load map tiles

- Category: dangerous
- Severity: critical
- Status: Confirmed
- Locations: `android/app/src/main/AndroidManifest.xml:1`, `android/app/src/debug/AndroidManifest.xml:6`, `android/app/src/profile/AndroidManifest.xml:6`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

The main Android manifest declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` but omits `android.permission.INTERNET`.
Only the debug and profile manifests declare `INTERNET`, and inspecting all nine Android plugins in `.flutter-plugins-dependencies` confirms none of them merges `INTERNET` either.
The release APKs already built on this machine confirm it: `aapt2` lists no `INTERNET` permission in either the 2026-11-23 release build or the 2026-09-12 archived release, while the debug APK has it.
Any release APK installed on a physical Android phone fails every OpenStreetMap tile download and leaves the map permanently blank unless tiles were pre-cached.
Severity note: the plan defines critical as data loss or a security hole; this finding is rated critical instead as a release blocker that breaks the map on every release install.

Proof (V1, V2):

    git grep -n "android.permission.INTERNET" -- android
    android/app/src/debug/AndroidManifest.xml:6:    <uses-permission android:name="android.permission.INTERNET"/>
    android/app/src/profile/AndroidManifest.xml:6:    <uses-permission android:name="android.permission.INTERNET"/>
    # Plugin manifest check over all 9 Android plugins in .flutter-plugins-dependencies:
    # flutter_plugin_android_lifecycle, geolocator_android, image_picker_android, jni, jni_flutter, package_info_plus, path_provider_android, sqflite_android, sqlite3_flutter_libs -> INTERNET=False for all 9.
    "$LOCALAPPDATA/Android/Sdk/build-tools/37.0.0/aapt2.exe" dump permissions build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
    package: ph.warang.app
    uses-permission: name='android.permission.ACCESS_FINE_LOCATION'
    uses-permission: name='android.permission.ACCESS_COARSE_LOCATION'
    permission: ph.warang.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
    uses-permission: name='ph.warang.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'
    # Same command on releases/latest/warang-latest-arm64-v8a.apk (built 2026-09-12 at 2d3386a): CAMERA and location only, no INTERNET.
    # Same command on build/app/outputs/flutter-apk/app-debug.apk: uses-permission: name='android.permission.INTERNET'.
    # Merged release manifest build/app/intermediates/merged_manifests/release/processReleaseManifest/arm64-v8a/AndroidManifest.xml: 0 matches for permission.INTERNET.

Fix: Add `<uses-permission android:name="android.permission.INTERNET" />` to `android/app/src/main/AndroidManifest.xml` (see https://developer.android.com/reference/android/Manifest.permission#INTERNET) and assert its presence in `test/android_hardening_test.dart`.

### AUD-002: Map tile cache revalidates fresh tiles on every view, opens a new HTTP client per tile with no timeout, and runs a full-table size query per write

- Category: dangerous
- Severity: high
- Status: Confirmed
- Locations: `lib/features/map/map_tile_store.dart:172`, `lib/features/map/map_tile_store.dart:182`, `lib/features/map/map_tile_store.dart:337`, `lib/features/map/map_tile_store.dart:368`
- Conflicts with: none
- Effort: M (1 to 4 hours)
- Lines removable: 0

`CachedTileProvider.loadBytes` calls `unawaited(_revalidate(...))` on every cache hit, even when a tile was fetched one minute ago and `mapTileMaxAge` is 30 days.
Every revalidation and cache miss opens a new `HttpClient()` and closes it in `finally` at line 411, so tile requests never reuse a connection and have no connection or request timeout, which leaves requests hanging on flaky mobile networks.
A `304 Not Modified` answer at line 376 still rewrites the full cached blob through `put`.
On every tile write, `MapTileStore.put` runs a full-table `SUM(length(bytes))` and, once over `mapTileMaxBytes`, an unserialized per-row delete loop ordered by `fetchedAt ASC` (FIFO rather than LRU) without a transaction.
Note that a separate V3 probe disproved the earlier suspicion of a missing OpenStreetMap `User-Agent`: `flutter_map` `TileLayer` mutates `provider.headers` to `User-Agent: flutter_map (ph.warang.app)`.

Proof (V3, V4):

    flutter test -j 1 -r expanded test/_audit_probe/map_tile_probe_test.dart
    PROBE_FRESH_HIT_HTTP_REQUESTS=1 paths=[/10/1/2.png] ua=[flutter_map (ph.warang.app)]
    PROBE_TILELAYER_PROVIDER_HEADERS={User-Agent: flutter_map (ph.warang.app)} receivedCount=0 firstUA=null
    V4 chain: MapTileStore.put (lib/features/map/map_tile_store.dart:172) -> evictToLimit (line 182, totalBytes SUM(length(bytes)) at line 201 + unserialized delete loop at lines 192-196); _fetchAndStore (line 368, new HttpClient(), no connectionTimeout or request timeout; closed with close(force: true) at line 411); 304 path rewrites cached bytes via put at lines 376-387.

Fix: Skip `_revalidate` in `CachedTileProvider.loadBytes` when `cached` is fresher than `mapTileMaxAge` (matching `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` Phase 5), share one bounded `HttpClient` with `connectionTimeout` and request timeout, track last-access time for LRU eviction, and serialize eviction inside a `sqflite` transaction when cached bytes exceed `mapTileMaxBytes`.

### AUD-003: Place book queries run synchronously on the UI isolate, and first-launch install buffers the full 25.96 MB asset in memory

- Category: dangerous
- Severity: medium
- Status: Plausible
- Locations: `lib/data/places/place_book.dart:80`, `lib/data/places/place_book_installer.dart:55`, `lib/data/places/place_book_installer.dart:68`, `lib/data/places/place_book_installer.dart:147`
- Conflicts with: none
- Effort: M (1 to 4 hours)
- Lines removable: 0

`PlaceBook.openFile` opens the 25.96 MB SQLite database with `NativeDatabase(file)` instead of `NativeDatabase.createInBackground(file)` used by `WarangDatabase.open`, so every place search and nearby lookup runs its SQLite work synchronously on the UI isolate while the user types or captures.
During first launch, `PlaceBookInstaller.ensureInstalled` loads the full 25.96 MB asset into memory at line 68 before writing it, and accepts any existing file whose length equals the hardcoded `expectedBytes` (`25964544`) without checking SQLite `meta`.
An interrupted copy repairs itself: if the app stops between `target.delete()` at line 79 and `tmp.rename` at line 81, the next launch finds no `target` and copies the bundled asset again; the `delete` is needed because `File.rename` does not overwrite on Windows, where the tests run.
`PlaceBookNotifier.ensureReady` updates `state` after `await` without checking whether the provider was disposed, but `placeBookProvider` is never disposed in the app.
A V3 probe was skipped because measuring UI-isolate frame drops requires device profiling.

Proof (V4, V5):

    lib/data/places/place_book_installer.dart:147 (ensureReady) -> line 154 (await installer.ensureInstalled())
    -> lib/data/places/place_book_installer.dart:55-66 (exists + length == expectedBytes only)
    -> lib/data/places/place_book_installer.dart:68 (rootBundle.load 25.96 MB into RAM)
    -> lib/data/places/place_book_installer.dart:74-81 (tmp written, target.delete(), tmp.rename(target.path); a missing target on the next launch reruns the copy)
    -> lib/data/places/place_book_installer.dart:155 -> lib/data/places/place_book.dart:80 (NativeDatabase(file): queries run on the calling isolate)
    V5: NativeDatabase.createInBackground (already used at lib/data/db/database.dart:33); Isolate.run https://api.dart.dev/dart-isolate/Isolate/run.html

Fix: Open `PlaceBook` with `NativeDatabase.createInBackground(file)` so queries leave the UI isolate, copy the asset in chunks (for example with `Isolate.run`) to avoid the 25.96 MB peak, and read `meta.schema_version` from the copied file before trusting it.

### AUD-004: Photo import decodes, resizes, and encodes on the UI isolate, and avatar picks are decoded at full resolution

- Category: dangerous
- Severity: high
- Status: Plausible
- Locations: `lib/data/files/photo_store.dart:54`, `lib/data/files/photo_store.dart:180`, `lib/data/files/photo_store.dart:223`, `lib/app/shell/you_sheet.dart:348`, `lib/app/device_providers.dart:28`
- Conflicts with: none
- Effort: M (1 to 4 hours)
- Lines removable: 0

`PhotoStore.importAvatar` and `PhotoStore._storeDecoded` run `img.decodeImage`, `img.bakeOrientation`, `img.copyResize`, and `img.encodeJpg` synchronously on the UI isolate.
Camera captures arrive bounded, because `cameraPickerProvider` calls `pickImage(maxWidth: 2000, imageQuality: 85)` at `device_providers.dart:28-31`, so the capture path costs UI jank on a roughly 2000-pixel image rather than an out-of-memory risk.
The avatar path is unbounded: `pickProfilePhoto` at `you_sheet.dart:348` calls `pickImage` with only `imageQuality: 88`, and `_decode` at `photo_store.dart:223` calls `img.decodeImage(bytes)` before the 30-megapixel check at line 231, so a 48 MP or 108 MP gallery photo allocates its full uncompressed bitmap before rejection.
Users picking an avatar from a high-resolution gallery photo on a mid-range Android phone can see a long UI freeze or an out-of-memory kill.
A V3 probe was skipped because proving real frame jank and OOM kills requires physical-device photos and memory profiling.

Proof (V4, V5):

    lib/features/capture/capture_screen.dart:131 -> WarangRepository.captureMoment (lib/data/repository.dart:96)
    -> PhotoStore._storeDecoded (lib/data/files/photo_store.dart:180)
    -> _decode (lib/data/files/photo_store.dart:223-235: img.decodeImage runs on the UI isolate before the 30 * 1000 * 1000 pixel check at line 231).
    Camera input is bounded at lib/app/device_providers.dart:28-31 (maxWidth: 2000, imageQuality: 85).
    Avatar input is unbounded: lib/app/shell/you_sheet.dart:348-351 (pickImage(source: ImageSource.gallery, imageQuality: 88)) -> WarangRepository.setAvatar (lib/data/repository.dart:129) -> PhotoStore.importAvatar (lib/data/files/photo_store.dart:54-55) -> _decode.
    V5: Isolate.run https://api.dart.dev/dart-isolate/Isolate/run.html

Fix: Pass `maxWidth: 2000` and `maxHeight: 2000` to the avatar `pickImage` call, read image dimensions from the header via `img.findDecoderForData(bytes)?.startDecode(bytes)` before full decoding, and run decode, EXIF orientation bake, resize, and JPEG encode inside `Isolate.run`.

### AUD-005: System Back dismisses capture mid-save, and the trip form steps back or closes mid-save, dropping save feedback

- Category: dangerous
- Severity: high
- Status: Confirmed
- Locations: `lib/features/capture/capture_screen.dart:231`, `lib/features/home_tab/trip_form_screen.dart:196`, `lib/features/home_tab/trip_form_screen.dart:209`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`CaptureScreen` has no `PopScope(canPop: !_saving)`, so pressing Android system Back while `captureMoment` is running dismisses the screen immediately and returns `null` to the caller.
If the in-flight save fails after dismissal, `if (!mounted) return;` at line 151 silently discards the retry snackbar and the user loses the moment without any message.
`TripFormScreen` only saves on its last question (`_last` at line 106), so its save can never be in flight on step 0.
On the last question, system Back during a save reaches `PopScope(canPop: _step == 0)` at line 196, and `onPopInvokedWithResult` runs `_step--` at line 200, so the form jumps back a question while the save keeps running and then pops.
The `CloseButton` at line 209 is never disabled, so Close during a save pops the route, and a failed save then drops its error snackbar the same way as capture.

Proof (V3, V4):

    flutter test -j 1 -r expanded test/_audit_probe/capture_back_probe_test.dart
    PROBE_CAPTURE_BACK_MID_SAVE: poppedMidSave=true routeReturned=true poppedResult=null snackBarShown=false momentsInDb=0
    V4: lib/features/home_tab/trip_form_screen.dart:106-107 (_next calls _save only when _last) -> line 118 (_saving = true) -> system Back -> line 198 (canPop: _step == 0 is false) -> line 200 (setState(() => _step--) while saving).
    V4: lib/features/home_tab/trip_form_screen.dart:209 (CloseButton(onPressed: () => Navigator.of(context).pop()) with no _saving check) -> line 141 (if (!mounted) return; drops the failure snackbar).

Fix: Wrap `CaptureScreen` in `PopScope(canPop: !_saving)` (see https://api.flutter.dev/flutter/widgets/PopScope-class.html), and in `TripFormScreen` set `canPop: !_saving && _step == 0`, skip `_step--` in `onPopInvokedWithResult` while `_saving`, and pass `onPressed: _saving ? null : ...` to the `CloseButton`.

### AUD-006: Multi-step moment edits and map placement writes run outside a single database transaction

- Category: dangerous
- Severity: high
- Status: Plausible
- Locations: `lib/features/travel_mode/moment_edit_sheet.dart:107`, `lib/features/travel_mode/travel_mode_screen.dart:192`
- Conflicts with: none
- Effort: M (1 to 4 hours)
- Lines removable: 0

`MomentEditSheet._save` executes up to three independent repository writes in sequence: `updateMoment`, then one of `clearPlace`, `attachBookPlace`, or `attachUserPlace`, then `setPlaceCategory`.
If the second or third write fails, the first write remains committed in SQLite while the sheet reports an error, leaving a partially updated moment.
`TravelModeScreen._confirmPlacement` similarly calls `setMomentLocation` and then `attachBookPlace` in two separate writes with no transaction, no re-entry `_saving` guard, and no `try/catch` error feedback.
A V3 probe was skipped because injecting a failure between internal DAO calls without editing `lib/` would only test a mock subclass rather than the real Drift transaction boundary.

Proof (V4):

    lib/features/travel_mode/moment_edit_sheet.dart:107 (await widget.repository.updateMoment)
    -> line 114, 117, or 123 (await widget.repository.clearPlace / attachBookPlace / attachUserPlace)
    -> line 134 (await widget.repository.setPlaceCategory)
    lib/features/travel_mode/travel_mode_screen.dart:192 (_confirmPlacement: await repository.setMomentLocation at line 198, then await repository.attachBookPlace at line 200, no try/catch or _saving guard).

Fix: Add a single `WarangRepository.editMomentDetails(...)` method that executes caption, trip, place, and category updates inside one `database.transaction(() async { ... })` block, do the same for location plus place in `_confirmPlacement`, and guard `_confirmPlacement` with a `_saving` flag and error snackbar.

### AUD-007: `main.dart` overrides `mapTileStoreProvider` with `overrideWithValue`, bypassing `ref.onDispose(store.close)`

- Category: dangerous
- Severity: low
- Status: Confirmed
- Locations: `lib/main.dart:32`, `lib/app/app_state.dart:15`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 1

`lib/app/app_state.dart:15-19` defines `mapTileStoreProvider` to construct `MapTileStore()` and register `ref.onDispose(store.close)`.
`lib/main.dart:32` replaces it with `mapTileStoreProvider.overrideWithValue(MapTileStore())`, which creates the exact same default store but bypasses the provider factory and its `onDispose` hook.
The `sqflite` database handle inside `MapTileStore` is never closed when the container disposes.
The practical effect is small: the app's `ProviderContainer` at `lib/main.dart:29` is never disposed while the process runs, so the default hook would not run in production either, and the override is mainly redundant code.

Proof (V1, V4):

    git grep -n "mapTileStoreProvider" -- lib
    lib/app/app_state.dart:15:final mapTileStoreProvider = Provider<MapTileStore>((ref) {
    lib/main.dart:32:      mapTileStoreProvider.overrideWithValue(MapTileStore()),

Fix: Delete the redundant `mapTileStoreProvider.overrideWithValue(MapTileStore())` line from `lib/main.dart:32` so the default provider in `lib/app/app_state.dart:15` creates and disposes the store.

### AUD-008: Unchecked JSON decoding and casts on persisted `milestonesShown` and bundled assets crash on malformed data

- Category: dangerous
- Severity: low
- Status: Confirmed
- Locations: `lib/data/repository.dart:345`, `lib/core/stamps.dart:33`, `lib/features/maya/maya_companion.dart:74`, `lib/features/news_tab/news_tab_screen.dart:31`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`WarangRepository._claimMilestones` parses `app_meta.milestonesShown` with `jsonDecode(raw) as List` without a `try/catch` or type check, so any corrupt row in SQLite throws an unhandled `FormatException` or `TypeError` every time a user saves a moment.
Bundled JSON parsers in `stamps.dart:33`, `maya_companion.dart:74`, and `news_tab_screen.dart:31-35` also cast decoded values directly with `as Map<String, dynamic>`, `as String`, and `DateTime.parse` without defensive fallback handling.
The trigger is rare: `milestonesShown` is written only by the app itself, and the bundled parsers fail only if a broken asset ships with the app.

Proof (V3, V4):

    flutter test -j 1 -r expanded test/_audit_probe/state_and_data_probe_test.dart
    PROBE_CORRUPT_MILESTONES_THREW=FormatException: FormatException: Unexpected character (at character 2)
    {corrupt
    V4: lib/core/stamps.dart:33-36, lib/features/maya/maya_companion.dart:74-77, lib/features/news_tab/news_tab_screen.dart:31-35 cast decoded JSON directly.

Fix: Wrap `jsonDecode` in `WarangRepository._claimMilestones` with a `try/catch` that resets invalid JSON to an empty set, and validate JSON field types with safe pattern matching (`if (decoded is Map<String, Object?>)`) in `stamps.dart`, `maya_companion.dart`, and `news_tab_screen.dart`.

### AUD-009: A missing `mounted` check after the date picker, and Maya drag-return listeners that pile up on repeated drags

- Category: dangerous
- Severity: medium
- Status: Plausible
- Locations: `lib/features/home_tab/trip_form_screen.dart:98`, `lib/features/maya/maya_companion.dart:255`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`TripFormScreen._pickDates` calls `setState` at line 98 after `await showDateRangePicker(...)` without checking `if (!mounted) return;`.
`MayaCompanion._onDragEnd` adds a `back` listener at line 256 and removes it only in `whenComplete` on the spring's `TickerFuture` at line 257.
If the user drags again before the spring settles, the next `_onDragEnd` sets `_drag.value = 1` at line 254, which calls `AnimationController.stop()` with `canceled: true`; a canceled `TickerFuture` never completes, so the old `back` listener is never removed and keeps overwriting `_offset` from a stale start position.
During that second drag, `_onDragUpdate` (line 241) also fights the still-running return spring, because nothing stops it when a pan starts.
The disposed-widget case is covered, because disposing `_drag` at line 168 stops its ticks.

Proof (V4, V5):

    lib/features/home_tab/trip_form_screen.dart:89 (_pickDates) -> line 91 (await showDateRangePicker) -> line 98 (setState without mounted check).
    lib/features/maya/maya_companion.dart:248 (_onDragEnd) -> line 254 (_drag.value = 1 stops any running spring as canceled) -> line 256 (_drag.addListener(back)) -> line 257 (whenComplete removes back only on normal completion).
    V5: TickerFuture https://api.flutter.dev/flutter/scheduler/TickerFuture-class.html ("if it is stopped with canceled set to true, then this Future will never complete"; whenCompleteOrCancel covers both cases).

Fix: Add `if (!mounted) return;` before `setState` in `TripFormScreen._pickDates`, and in `MayaCompanion._onDragEnd` replace `whenComplete` with `whenCompleteOrCancel` so `back` is always removed, and stop `_drag` when a new pan starts.

### AUD-010: `MayaLines.load` and `StampTitles.load` permanently cache rejected futures, and static caches leak across tests

- Category: dangerous
- Severity: low
- Status: Confirmed
- Locations: `lib/features/maya/maya_companion.dart:70`, `lib/features/stamps/stamp_titles.dart:10`, `lib/app/theme/clay_components.dart:383`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`MayaLines.load` stores the in-flight `Future` in static `_lines` and never clears it if asset loading fails, so one transient error permanently breaks Maya copy for the entire app process.
`StampTitles.load` repeats the same pattern in static `_loading`.
The trigger is rare, because loading a bundled asset seldom fails on a device, and the repository already catches a `StampTitles.load` failure at `lib/data/repository.dart:359-363` and falls back to `const {}`.
Global mutable static fields in `WarangStamp` (`_stampsShown`), `MayaCompanionState.clock`, `MayaLines._lines`, and `StampTitles._cached` also require manual resets across widget tests.

Proof (V3, V4):

    flutter test -j 1 -r expanded test/_audit_probe/state_and_data_probe_test.dart
    PROBE_MAYALINES_FAILED_CACHE: err1=Bad state: boom err2=Bad state: boom
    V4: lib/features/stamps/stamp_titles.dart:22-26 assigns _loading without clearing on error; lib/app/theme/clay_components.dart:383 holds process-global Set _stampsShown.

Fix: Clear `_lines = null` and `_loading = null` in a `.catchError` or `try/catch` block on load failure so retries can succeed, and move test-resettable state into Riverpod providers where practical.

### AUD-011: `setAvatar` leaves superseded avatars on disk forever and does not clean up on database failure

- Category: dangerous
- Severity: medium
- Status: Confirmed
- Locations: `lib/data/repository.dart:129`, `lib/data/files/photo_store.dart:54`, `lib/data/files/photo_store.dart:145`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`WarangRepository.setAvatar` writes a new UUID-named JPEG under `warang/profile/` before updating the `profiles` table, does not delete the newly written file if `updateProfile` throws, and never deletes the previous avatar file.
`PhotoStore.sweepOrphans` scans only `warang/photos/` at line 145, so every replaced profile photo stays on the user's storage indefinitely.

Proof (V3, V4):

    flutter test -j 1 -r expanded test/_audit_probe/state_and_data_probe_test.dart
    PROBE_AVATAR_ORPHAN: first=warang/profile/64433336-5429-4bae-bc41-2227397d4785.jpg second=warang/profile/b735b086-74d8-4b9b-9bff-baa38ec0e241.jpg firstStillExists=true sweepDeleted=0
    V4: lib/data/repository.dart:129-139 has no catch cleanup for newRelPath and never deletes previous avatarRelPath.

Fix: Delete the new avatar file in `setAvatar` if `updateProfile` fails, delete the old avatar file after `updateProfile` commits, and include `warang/profile/` (referencing `profiles.avatarRelPath`) in `PhotoStore.sweepOrphans`.

### AUD-012: Release archive scripts allow zero-APK archives, interpolate unescaped JSON, and skip APK signature verification

- Category: dangerous
- Severity: medium
- Status: Plausible
- Locations: `scripts/build-and-archive.sh:50`, `scripts/build-and-archive.sh:91`, `scripts/build-and-archive.ps1:63`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

Both scripts are untracked in Git (`scripts/` is a preserved untracked path), so these fixes edit files outside version control.
`scripts/build-and-archive.sh` does not fail if zero release APKs exist in the output directory, interpolates `GIT_BRANCH` directly into a JSON heredoc at lines 91-100 without escaping quotes or slashes, and parses `pubspec.yaml` with `grep | awk` that breaks on inline comments.
`scripts/build-and-archive.ps1` already stops on zero APKs (`$ErrorActionPreference = "Stop"` at line 32 and `Write-Error` at line 123), but suppresses `git` stderr at lines 63-64 without verifying exit codes.
Neither script runs `apksigner verify` to confirm the archived APK carries the production release certificate before archiving.

Proof (V4):

    scripts/build-and-archive.sh:13-14 (grep/awk pubspec parser), lines 50-88 (no error when 0 APKs matched), lines 91-100 (raw JSON heredoc with ${GIT_BRANCH}).
    scripts/build-and-archive.ps1:32 ($ErrorActionPreference = "Stop") and lines 122-124 (Write-Error when $apkFiles.Count -eq 0).
    scripts/build-and-archive.ps1:63-64 (git rev-parse 2>$null without $LASTEXITCODE check); neither script invokes apksigner verify.
    git ls-files scripts -> no output (untracked).

Fix: Fail `build-and-archive.sh` if zero APKs are found, run `apksigner verify --print-certs` on every archived APK in both scripts, serialize the `.sh` manifest JSON with a real serializer (Python `json.dumps`, as the `.ps1` already does with `ConvertTo-Json` at line 179), and check `$LASTEXITCODE` after `git` calls; decide whether `scripts/` should be committed so these fixes are tracked.

### AUD-013: Capture preview and moment polaroids decode full-resolution `Image.file` bitmaps without `cacheWidth`, and polaroid builds call `existsSync()`

- Category: dangerous
- Severity: medium
- Status: Plausible
- Locations: `lib/features/capture/capture_screen.dart:211`, `lib/features/travel_mode/travel_mode_screen.dart:1157`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`CaptureScreen` at line 211 and `_MomentPolaroid` at line 1157 render `Image.file` without passing `cacheWidth` or `cacheHeight`, causing Flutter's image cache to decode each photo at its full stored size (up to 2000 pixels on the long edge, from `pickImage(maxWidth: 2000)` and `PhotoStore.maxLongEdge`) even for small preview cards.
`_MomentPolaroid.build` also calls synchronous `file.existsSync()` on the UI thread during every rebuild, adding synchronous disk I/O to frame rendering.

Proof (V4, V5):

    lib/features/capture/capture_screen.dart:211 (Image.file(File(photo.path), fit: BoxFit.cover) with no cacheWidth/cacheHeight).
    lib/features/travel_mode/travel_mode_screen.dart:1157-1164 (file.existsSync() inside build, then Image.file without cacheWidth/cacheHeight).
    V5: Image.file cacheWidth https://api.flutter.dev/flutter/widgets/Image/Image.file.html

Fix: Compute `cacheWidth` from the widget display width multiplied by `MediaQuery.devicePixelRatioOf(context)`, and replace synchronous `file.existsSync()` in `_MomentPolaroid.build` with `Image.file(..., errorBuilder: ...)` or async state resolved once in `initState`.

### AUD-014: `PlacePickerSheet._runQuery` leaves the loading spinner stuck forever when `PlaceBook` throws

- Category: dangerous
- Severity: medium
- Status: Confirmed
- Locations: `lib/features/places/place_picker_sheet.dart:136`, `lib/features/places/place_picker_sheet.dart:157`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`PlacePickerSheet._runQuery` sets `_loading = true` and awaits `book.nearby(...)` (line 136) or `book.search(...)` (line 157) with no `try/catch` or `finally` block.
If the place book SQLite file fails to query or was closed, the exception escapes unhandled and `_loading` remains `true` forever, trapping the user on an infinite spinner.

Proof (V3):

    flutter test -j 1 -r expanded test/_audit_probe/state_and_data_probe_test.dart
    PROBE_PLACE_PICKER_ERROR: errors=1 (StateError) stuckSpinner=true

Fix: Wrap both `book.nearby` and `book.search` calls in `PlacePickerSheet._runQuery` with `try/catch` and clear `_loading = false` in `finally` (guarded by `mounted` and sequence check), showing an inline retry/error message on failure.

### AUD-015: `ClayDiscCache.image` uses colliding `Object.hash` keys and drops evicted `ui.Image` handles without calling `dispose()`

- Category: dangerous
- Severity: low
- Status: Plausible
- Locations: `lib/app/theme/clay.dart:541`, `lib/app/theme/clay.dart:578`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`ClayDiscCache.image` keys its static cache map with an `int` from `Object.hash(...)` at line 541, unlike `_ClayGeometry.of` at line 406 which uses a value-equal Dart record tuple, creating a silent hash-collision hazard where one disc renders another disc's bitmap.
A collision is very unlikely with at most 48 cached entries, so this is a correctness trap rather than an observed failure.
When the cache exceeds 48 entries at line 578, `_images.remove(_images.keys.first)` drops the evicted `ui.Image` reference without calling `evicted.dispose()`, delaying release of GPU texture memory until GC finalization.

Proof (V4, V5):

    lib/app/theme/clay.dart:541 (final key = Object.hash(...); int map key)
    lib/app/theme/clay.dart:578 (_images.remove(_images.keys.first); return value ignored, ui.Image.dispose() never called)
    V5: ui.Image.dispose https://api.flutter.dev/flutter/dart-ui/Image/dispose.html

Fix: Key `ClayDiscCache._images` by a typed record matching the quantized disc parameters, and call `evicted?.dispose()` on evicted `ui.Image` handles (ensuring no frame is mid-draw via post-frame callback or ref-counted disposal).

### AUD-016: `MomentSearchResults` stays stale after editing an existing moment's caption, place, category, or trip title

- Category: dangerous
- Severity: medium
- Status: Confirmed
- Locations: `lib/features/search/search_tab_screen.dart:139`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`MomentSearchResults.didUpdateWidget` only re-runs `_search()` when `widget.query != _query || widget.repository.moments.length != _momentCount`.
Editing an existing moment's caption, place, category, or trip title leaves `moments.length` unchanged, so the Search tab displays stale results until the user changes the query or adds/deletes a moment.

Proof (V3):

    flutter test -j 1 -r expanded test/_audit_probe/state_and_data_probe_test.dart
    PROBE_SEARCH_STALE_AFTER_EDIT: stillEmpty=true foundNew=false

Fix: Expose a monotonic `int revision` counter on `WarangRepository` incremented on every `notifyListeners()` call, and trigger `_search()` in `MomentSearchResults.didUpdateWidget` whenever `widget.query != _query || widget.repository.revision != _revision`.

### AUD-017: Schema 1 to 2 migration runs outside a Drift transaction and lacks independent v1-to-v2 rollback coverage

- Category: dangerous
- Severity: medium
- Status: Plausible
- Locations: `lib/data/db/database.dart:65`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

In `WarangDatabase.migration.onUpgrade`, the `from < 2` block at lines 65-68 calls `m.addColumn(trips, trips.colorKey)` and `await _colourExistingTrips()` outside a Drift `transaction`, whereas `from < 3` at lines 69-133 runs inside `transaction` (lines 70-132).
Drift writes the new `user_version` only after every migration step succeeds, so if `_colourExistingTrips` throws after `addColumn` commits, the next launch reruns `addColumn` on a column that already exists, and the database likely fails to open on every launch after that.
`test/migration_test.dart` tests v2-to-v3 and v1-to-v3 upgrades with data, leaving v1-to-v2 atomicity and rollback untested.

Proof (V4):

    lib/data/db/database.dart:65-68 (if (from < 2) runs addColumn + _colourExistingTrips outside transaction, unlike if (from < 3) at line 69).
    drift 2.34.4 lib/src/runtime/executor/helpers/engines.dart:557-562 (user.beforeOpen runs the migration, then setSchemaVersion runs only after it returns; no transaction wraps onUpgrade).
    test/migration_test.dart:222-306 tests v2->v3 and v1->v3 only.

Fix: Wrap the `if (from < 2)` upgrade steps in `await transaction(() async { ... })` in `lib/data/db/database.dart:65-68` and add an isolated v1-to-v2 test in `test/migration_test.dart`.

### AUD-018: `pickProfilePhoto` directly instantiates `ImagePicker` and has no error handling or feedback for corrupt or oversized images

- Category: dangerous
- Severity: medium
- Status: Plausible
- Locations: `lib/app/shell/you_sheet.dart:347`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`pickProfilePhoto` creates `ImagePicker()` directly inside the function rather than reading an injectable provider, and calls `await repository.setAvatar(File(picked.path))` at line 352 without `try/catch`.
If the user picks a corrupt file or an image over the 30-megapixel cap (the literal `30 * 1000 * 1000` at `lib/data/files/photo_store.dart:231`), `PhotoStore._decode` throws `FormatException`, which escapes unhandled with no user feedback.
A V3 probe was skipped because `ImagePicker()` is constructed inline and cannot be stubbed without editing `lib/`.

Proof (V4):

    lib/app/shell/you_sheet.dart:347 (pickProfilePhoto) -> line 348 (ImagePicker().pickImage) -> line 352 (await repository.setAvatar(File(picked.path)), no try/catch or snackbar)
    -> lib/data/repository.dart:129 (setAvatar) -> lib/data/files/photo_store.dart:55 (_decode) -> lines 228, 230, 232 (throw FormatException).

Fix: Add a gallery picker provider next to `cameraPickerProvider` in `lib/app/device_providers.dart` and read it in `pickProfilePhoto`, wrap `setAvatar` in `try/catch`, and show `showWarangSnackBar` on failure (matching `CaptureScreen._save`).

### AUD-019: `sqlite3_flutter_libs` is marked end-of-life (`0.6.0+eol`) in `flutter pub outdated`

- Category: dangerous
- Severity: medium
- Status: Confirmed
- Locations: `pubspec.yaml:23`
- Conflicts with: none
- Effort: M (1 to 4 hours)
- Lines removable: 0

`pubspec.yaml:23` depends on `sqlite3_flutter_libs: ^0.5.24`, which `flutter pub outdated` reports as superseded by `0.6.0+eol` because the package is officially end-of-life.
Keeping an unmaintained native SQLite wrapper risks breakage on future Flutter, Android NDK, or 16 KB page-size releases.

Proof (V2):

    flutter pub outdated (saved in docs/audits/AUDIT-001/scans/00-inventory.txt)
    sqlite3_flutter_libs  0.5.43  0.5.43  0.5.43  0.6.0+eol

Fix: Migrate native SQLite bundling to the official `sqlite3` / `drift_flutter` native-assets path once Len approves the dependency change, and remove `sqlite3_flutter_libs` from `pubspec.yaml`.

### AUD-020: Unchecked `!` and `as` casts on raw `sqflite` rows and internal lookup maps

- Category: dangerous
- Severity: low
- Status: Confirmed
- Locations: `lib/features/map/map_tile_store.dart:157`, `lib/features/map/map_tile_store.dart:216`, `lib/features/map/map_tile_store.dart:246`, `lib/data/repository.dart:225`, `lib/app/theme/clay.dart:61`, `lib/features/home_tab/trip_form_screen.dart:369`, `lib/features/map/warang_map.dart:115`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`MapTileStore` reads raw `sqflite` maps using unchecked `! as` casts (`row['bytes']! as Uint8List`, `row['lat']! as num`), which throw `TypeError` on unexpected nulls or column types.
`WarangRepository` asserts `_placesById[placeId]!` at line 225, and `clay.dart:61,63`, `trip_form_screen.dart:369`, and `warang_map.dart:115` assert `!` on map lookups instead of handling missing keys defensively.

Proof (V2, V4):

    # docs/audits/AUDIT-001/scans/08-dynamic-and-casts.txt & 07-null-and-late.txt
    lib/features/map/map_tile_store.dart:157-164, 216-219, 246-251 (! as casts on raw sqflite rows)
    lib/data/repository.dart:225 (_placesById[placeId]!)
    lib/app/theme/clay.dart:61,63; lib/features/home_tab/trip_form_screen.dart:369; lib/features/map/warang_map.dart:115

Fix: Use pattern matching (`if (row case {'bytes': final Uint8List bytes, ...})`) in `MapTileStore` to return `null` on malformed rows, and guard the four map lookups with `??` or `if (value != null)`.

### AUD-021: Empty and broad catch blocks silently swallow tile-state and photo-resolution errors

- Category: dangerous
- Severity: low
- Status: Confirmed
- Locations: `lib/features/map/map_tile_store.dart:235`, `lib/features/map/map_tile_store.dart:272`, `lib/app/shell/you_sheet.dart:459`, `lib/features/home_tab/trip_photo.dart:46`, `lib/features/travel_mode/travel_mode_screen.dart:1102`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`MapTileStore.saveCamera` (line 235) and `MapTileStore.saveLocation` (line 272) contain empty `catch (_) {}` blocks that discard SQLite write failures without any debug logging.
Three photo loaders (`you_sheet.dart:459`, `trip_photo.dart:46`, `travel_mode_screen.dart:1102`) catch all exceptions and return `null` silently, masking corrupted files or storage permission failures.

Proof (V2, V4):

    # docs/audits/AUDIT-001/scans/06-catch.txt
    lib/features/map/map_tile_store.dart:235:    } catch (_) {}
    lib/features/map/map_tile_store.dart:272:    } catch (_) {}
    lib/app/shell/you_sheet.dart:459, lib/features/home_tab/trip_photo.dart:46, lib/features/travel_mode/travel_mode_screen.dart:1102

Fix: Narrow these catches to `on Exception catch (e)` (or `on FileSystemException` / `on DatabaseException`) and emit `debugPrint` in debug mode so storage failures remain diagnosable without crashing the UI.

### AUD-022: Place book builder swallows OSM area exceptions, deletes output non-atomically, and skips PBF checksum verification

- Category: dangerous
- Severity: low
- Status: Plausible
- Locations: `tool/place_book/build_place_book.py:325`, `tool/place_book/build_place_book.py:423`, `tool/place_book/build_place_book.py:427`, `tool/place_book/README.md:26`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`tool/place_book/build_place_book.py` catches `except Exception: return` at line 325 without counting or logging skipped OSM areas, and calls `out_path.unlink()` at line 423 before building the replacement database so a failed run destroys the prior working SQLite file.
Line 427 strips FTS prefix configuration with a fragile exact-whitespace string replace (`schema_sql.replace(",\n  prefix = '2 3'", "")`), and `tool/place_book/README.md:26` downloads `philippines-latest.osm.pbf` without checking Geofabrik's `.md5` checksum.

Proof (V4):

    # docs/audits/AUDIT-001/scans/20-tooling.txt
    tool/place_book/build_place_book.py:325 (except Exception: return)
    tool/place_book/build_place_book.py:423 (out_path.unlink() before rebuild)
    tool/place_book/build_place_book.py:427 (exact-whitespace replace)
    tool/place_book/README.md:26 (curl download with no checksum step)

Fix: Build into `out_path.with_suffix('.sqlite.tmp')` and `os.replace` on success, catch specific `osmium` geometry exceptions with a skipped-area counter, use a regex or flag for FTS prefix configuration, and document verifying `philippines-latest.osm.pbf.md5` in `README.md`.

### AUD-051: Release archive scripts archive stale APKs left from earlier builds under the new version and Git hash

- Category: dangerous
- Severity: medium
- Status: Plausible
- Locations: `scripts/build-and-archive.sh:56`, `scripts/build-and-archive.sh:62`, `scripts/build-and-archive.ps1:114`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

Added in revision 2 from the review of revision 1.
Both scripts archive every non-debug `*.apk` they find in `build/app/outputs/flutter-apk`, and `flutter build apk` does not delete outputs from earlier builds.
A build without `--split-per-abi` therefore archives the new `app-release.apk` together with any per-ABI APKs left from an earlier split build, and names every copy with the current version, timestamp, and Git hash.
That folder holds three per-ABI release APKs from 2026-11-23 today, so the next non-split run would archive them as if they were built from the new commit, and `releases/latest/` could then serve an old build.
A V3 probe was skipped because it requires a full release build, and both scripts are untracked in Git.

Proof (V4):

    scripts/build-and-archive.sh:50 (APK_DIR=build/app/outputs/flutter-apk) -> line 56 (APKS=("${APK_DIR}"/*.apk)) -> lines 62-66 (skips only names containing "debug") -> lines 73-75 (copies each APK as ${APP_NAME}-v${VERSION}-release-${abi}-${TIMESTAMP}-${GIT_HASH}.apk and into releases/latest).
    scripts/build-and-archive.ps1:106-117 (Get-ChildItem -Filter "*.apk" | Where-Object { $_.Name -notlike "*debug*" }) -> line 139 (same versioned name).
    ls build/app/outputs/flutter-apk -> app-arm64-v8a-release.apk, app-armeabi-v7a-release.apk, app-x86_64-release.apk (2026-11-23 22:51), app-debug.apk (2026-11-24 06:35).

Fix: Delete `build/app/outputs/flutter-apk/*.apk` (or run `flutter clean`) before `flutter build apk` in both scripts, or archive only the exact file names the chosen mode produces (`app-release.apk`, or the three `app-<abi>-release.apk` files), and fail if an expected file is missing.

## Unnecessary

### AUD-023: `WarangToggle` has zero callers in `lib/`

- Category: unnecessary (delete)
- Severity: medium
- Status: Confirmed
- Locations: `lib/app/theme/clay_components.dart:1147`
- Conflicts with: `docs/features/FEAT-003-clay-keepsake-redesign.md` C11
- Effort: S (under 1 hour)
- Lines removable: 103

`WarangToggle` spans 103 lines (`lib/app/theme/clay_components.dart:1147-1249`) and has zero callers anywhere in `lib/`.
FEAT-002 REQ-007 previously deleted the unused toggle widget, and FEAT-003 C11 re-introduced a clay toggle even though no screen renders a toggle control.
Removing it touches no screen and requires removing only its isolated unit test block in `test/clay_components_test.dart:297-322`.

Proof (V1):

    git grep -n "WarangToggle" -- lib test tool
    lib/app/theme/clay_components.dart:1147:class WarangToggle extends StatelessWidget {
    lib/app/theme/clay_components.dart:1148:  const WarangToggle({
    test/clay_components_test.dart:297:              builder: (context, setState) => WarangToggle(
    test/clay_components_test.dart:307:        expect(tester.getSize(find.byType(WarangToggle)), const Size(52, 48));
    test/clay_components_test.dart:309:        await tester.tap(find.byType(WarangToggle));
    test/clay_components_test.dart:322:          tester.getSemantics(find.byType(WarangToggle)),

Fix: With Len's approval to drop FEAT-003 C11 until a screen needs a toggle, delete `WarangToggle` from `lib/app/theme/clay_components.dart:1147-1249` and its test in `test/clay_components_test.dart:297-322`.

### AUD-024: `WarangRepository.upsertImportedTrip` has zero references in `lib/`, `test/`, or `tool/`

- Category: unnecessary (delete)
- Severity: medium
- Status: Confirmed
- Locations: `lib/data/repository.dart:555`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 75

`WarangRepository.upsertImportedTrip` spans 75 lines (`lib/data/repository.dart:555-629`) and has zero callers in application code, tests, or tools.
It was left behind when FEAT-002 deleted `TravelbookService`.
Removing it affects no screen and no test.

Proof (V1):

    git grep -n "upsertImportedTrip" -- lib test tool
    lib/data/repository.dart:555:  Future<void> upsertImportedTrip(

Fix: Delete `upsertImportedTrip` (`lib/data/repository.dart:555-629`).

### AUD-025: 74 mechanical `dart fix` simplifications across 30 files

- Category: unnecessary (shrink)
- Severity: low
- Status: Confirmed
- Locations: `lib/app/app.dart:22`, `lib/app/shell/you_sheet.dart:242`, `lib/app/theme/clay.dart:746`, `lib/app/theme/clay_components.dart:898`, `lib/app/theme/components.dart:159`, `lib/data/repository.dart:414`, `lib/features/capture/capture_screen.dart:115`, `lib/features/home_tab/trip_detail_screen.dart:127`, `lib/features/map/warang_map.dart:440`, `lib/features/maya/maya_companion.dart:390`, `lib/features/news_tab/news_tab_screen.dart:160`, `lib/features/places/place_picker_sheet.dart:136`, `lib/features/search/search_tab_screen.dart:279`, `lib/features/stamps/stamp_page_sheet.dart:90`, `lib/features/travel_mode/moment_edit_sheet.dart:69`, `lib/features/travel_mode/travel_mode_screen.dart:131`, `test/migration_test.dart:217`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 27

Running `dart fix --dry-run` under the strict lint set reports 74 purely syntactic fixes across 30 files: 70 redundant default arguments (`avoid_redundant_argument_values`), 1 unnecessary `!` (`lib/app/theme/clay.dart:746`), 2 verbose `== true` checks on nullable booleans (`lib/data/repository.dart:414`, `lib/features/home_tab/trip_detail_screen.dart:127`), and 1 unnecessary closure (`test/migration_test.dart:217`).
The strict analyzer pass lists 64 redundant-argument hits, 32 of them in `lib/`.
Only 27 of those hits (20 in `lib/`) sit alone on their own line, such as `depth: ClayDepth.clay1,`, so the fixes remove 27 lines; the rest shorten a line without removing it.
24 of the hits are default-valued arguments inside `DateTime(...)` literals in `test/` and `tool/`, such as the day in `DateTime(2026, 3, 1)` or the minute in `DateTime(2026, 9, 5, 12, 0)`, where dropping the argument makes the date harder to read.
Applying the remaining edits changes no screen behavior and no test semantics.

Proof (V2):

    # docs/audits/AUDIT-001/scans/02-dart-fix.txt
    dart fix --dry-run
    74 proposed fixes in 30 files.
    # Breakdown: avoid_redundant_argument_values (70), use_if_null_to_convert_nulls_to_bools (2), unnecessary_null_checks (1), unnecessary_lambdas (1).
    # docs/audits/AUDIT-001/scans/01-strict-lints.txt: 64 avoid_redundant_argument_values hits (32 in lib/); 27 hit lines match the pattern "name: value," alone on the line (20 in lib/); 24 hit lines contain DateTime(.

Fix: Apply only the readable fixes, file by file, with `dart fix --apply --code=unnecessary_null_checks`, `--code=unnecessary_lambdas`, and `--code=use_if_null_to_convert_nulls_to_bools`, and remove redundant arguments by hand outside `DateTime(...)` literals; do not run a blanket `dart fix --apply`.
Shorter forms for the three cited lines:

```dart
// Before (lib/app/theme/clay.dart:746):
result = Tooltip(message: widget.tooltip!, child: result);
// After:
result = Tooltip(message: widget.tooltip, child: result);

// Before (lib/data/repository.dart:414):
place: Value(place?.trim().isEmpty == true ? null : place?.trim()),
// After:
place: Value((place?.trim().isEmpty ?? false) ? null : place?.trim()),

// Before (lib/features/places/place_picker_sheet.dart:136):
final nearby = await book.nearby(widget.near!, 150, limit: 8);
// After:
final nearby = await book.nearby(widget.near!, 150);
```

### AUD-026: Undeclared, unreferenced logo PNGs and legacy design assets tracked in Git

- Category: unnecessary (delete)
- Severity: low
- Status: Confirmed
- Locations: `assets/Logo.png:1`, `assets/Logo2.png:1`, `design/warang-canvas.html:1`, `design/ui-update/baseline/home_dark.png:1`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

Two large logo images (`assets/Logo.png` at 1134 KB and `assets/Logo2.png` at 1089 KB), one legacy design mockup (`design/warang-canvas.html` at 796 KB), and 14 pre-redesign screenshots under `design/ui-update/baseline/` are tracked in Git even though `pubspec.yaml` does not declare them and zero code or tests reference them.
Together these 17 files add about 3.0 MB to every checkout; deleting them does not shrink the existing Git history.
`assets/Logo.png` and `design/warang-canvas.html` may be brand and design source files (archived `docs/archive/DESIGN_SPEC-r1.md` names the canvas as its source of truth), the same reason C-013 kept `design/icons/`, so Len decides whether they stay.
Deleting them changes no screen, build, or test.

Proof (V1):

    git grep -n "Logo.png" -- lib test tool -> 0 hits
    git grep -n "Logo2.png" -- lib test tool -> 0 hits
    git grep -n "warang-canvas.html" -- lib test tool -> 0 hits
    git grep -n "ui-update" -- lib test tool -> 0 hits
    # docs/audits/AUDIT-001/scans/04-asset-use.txt confirms none are declared in pubspec.yaml.

Fix: Remove `assets/Logo2.png` and `design/ui-update/baseline/` from Git, and remove `assets/Logo.png` and `design/warang-canvas.html` only if Len confirms they are not brand or design sources (keeping `assets/logo_icon.png` and `design/icons/`, which are actively used).

### AUD-027: Unused theme colour tokens and unused component constructors and parameters

- Category: unnecessary (delete)
- Severity: low
- Status: Confirmed
- Locations: `lib/app/theme/tokens.dart:35`, `lib/app/theme/tokens.dart:36`, `lib/app/theme/clay_components.dart:25`, `lib/app/theme/clay_components.dart:206`, `lib/app/theme/clay_components.dart:1323`, `lib/app/theme/components.dart:529`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 34

Six public theme tokens and widget API hooks have zero callers anywhere in `lib/`, `test/`, or `tool/`: `WarangColors.lightDotInactive` (`tokens.dart:35`), `WarangColors.darkDotInactive` (`tokens.dart:36`), the default `WarangButton(...)` constructor (`clay_components.dart:25-32`, all callers use named constructors), `WarangField.helperText` (`clay_components.dart:182,206,368-371`), `WarangSpeechBubble.tailAlignment` and `tailDown` (`clay_components.dart:1323-1324,1333-1336,1383-1386,1420-1429`), and `WarangSettingsRow.onTap` (`components.dart:524,529,535`, all three call sites in `settings_screen.dart` omit `onTap`).
Deleting these unused tokens and parameters affects no screen and no test.

Proof (V1):

    git grep -n "lightDotInactive" -- lib test tool -> 1 hit (lib/app/theme/tokens.dart:35)
    git grep -n "darkDotInactive" -- lib test tool -> 1 hit (lib/app/theme/tokens.dart:36)
    git grep -n "WarangButton(" -- lib test tool -> 1 hit (lib/app/theme/clay_components.dart:25)
    git grep -n "helperText" -- lib test tool -> 4 hits (declaration + internal branch only)
    git grep -n "tailAlignment" -- lib test tool -> 4 hits (declaration + internal usage only)
    git grep -n "tailDown" -- lib test tool -> 5 hits (declaration + internal usage only)
    # All 3 WarangSettingsRow call sites (settings_screen.dart:83, 101, 218) omit onTap.

Fix: Remove `lightDotInactive`, `darkDotInactive`, the unnamed `WarangButton()` constructor, `WarangField.helperText`, `WarangSpeechBubble.tailAlignment`/`tailDown`, and `WarangSettingsRow.onTap` (and its unused `InkWell` wrapper).

### AUD-028: Speculative `NewsAdSlot` and `NewsListEntry` sealed hierarchy with zero ad callers

- Category: unnecessary (yagni)
- Severity: low
- Status: Confirmed
- Locations: `lib/features/news_tab/news_tab_screen.dart:11`, `lib/features/news_tab/news_tab_screen.dart:41`, `lib/features/news_tab/news_tab_screen.dart:131`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 18

`NewsTabScreen` wraps `NewsArticle` in a sealed `NewsListEntry` hierarchy solely to hold an empty `NewsAdSlot` subtype rendered as `SizedBox.shrink()`.
Nothing in `lib/`, `test/`, or `tool/` ever constructs `NewsAdSlot`, and `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` explicitly lists "No advertising or an ad SDK" as a non-goal.
Replacing `NewsListEntry` with `NewsArticle` changes no screen behavior and requires updating only one type annotation in `test/news_tab_test.dart:34`.

Proof (V1):

    git grep -n "NewsAdSlot" -- lib test tool
    lib/features/news_tab/news_tab_screen.dart:41:final class NewsAdSlot extends NewsListEntry {
    lib/features/news_tab/news_tab_screen.dart:42:  const NewsAdSlot();
    lib/features/news_tab/news_tab_screen.dart:131:                        NewsAdSlot _ => const SizedBox.shrink(),

Fix: Delete `NewsAdSlot` and `NewsListEntry` in `lib/features/news_tab/news_tab_screen.dart`, type the list directly as `List<NewsArticle>`, and update `Completer<List<NewsArticle>>` in `test/news_tab_test.dart:34`.

### AUD-029: Unused `MayaPose.footTap` enum value

- Category: unnecessary (delete)
- Severity: low
- Status: Confirmed
- Locations: `lib/features/maya/maya_companion.dart:20`
- Conflicts with: `docs/features/FEAT-003-clay-keepsake-redesign.md` M4
- Effort: S (under 1 hour)
- Lines removable: 1

`MayaPose.footTap` is declared at `lib/features/maya/maya_companion.dart:20` but never referenced anywhere in `lib/`, `test/`, or `tool/`.
Deleting it changes no screen and no test.

Proof (V1):

    git grep -n "footTap" -- lib test tool
    lib/features/maya/maya_companion.dart:20:  footTap,

Fix: Either wire `MayaPose.footTap` into Maya's idle rotation when layered art (D-2) lands, or delete `footTap` from `MayaPose` if Len drops it from FEAT-003 M4.

## Sloppy

### AUD-030: Twelve `lib/` files exceed 400 lines and 34 functions or `build` methods exceed 60 lines

- Category: sloppy
- Severity: medium
- Status: Confirmed
- Locations: `lib/app/theme/clay_components.dart:1`, `lib/features/travel_mode/travel_mode_screen.dart:1`, `lib/features/map/warang_map.dart:1`, `lib/data/repository.dart:1`, `lib/app/theme/clay.dart:1`, `lib/features/places/place_picker_sheet.dart:1`, `lib/app/theme/components.dart:1`, `lib/app/shell/you_sheet.dart:1`, `lib/features/map/map_tile_store.dart:1`, `lib/features/capture/capture_screen.dart:1`, `lib/features/home_tab/home_tab_screen.dart:1`, `lib/features/maya/maya_companion.dart:1`
- Conflicts with: none
- Effort: L (over 4 hours)
- Lines removable: 0

Twelve of the 49 hand-written `lib/` files exceed 400 lines, led by `clay_components.dart` (1516 lines), `travel_mode_screen.dart` (1169 lines), `warang_map.dart` (943 lines), and `repository.dart` (791 lines).
Thirty-four functions or `build` methods exceed 60 lines (up to 264 lines in `travel_mode_screen.dart:276`), mixing layout, gesture state, and repository mutations in single widgets.

Proof (V2):

    # docs/audits/AUDIT-001/scans/17-complexity.txt (python docs/audits/AUDIT-001/scripts/complexity.py)
    1516  lib/app/theme/clay_components.dart
    1169  lib/features/travel_mode/travel_mode_screen.dart
     943  lib/features/map/warang_map.dart
     791  lib/data/repository.dart
    # Plus 8 more files > 400 lines and 34 methods > 60 lines (approximate brace matching).

Fix: Split `clay_components.dart` by component group (buttons, fields, sheets, stamps), extract `_MomentPolaroid` and placement overlay from `travel_mode_screen.dart`, and extract clustering/pin rendering from `warang_map.dart`.

### AUD-031: 160 repeated normalized 8-line code windows across `lib/`

- Category: sloppy
- Severity: medium
- Status: Confirmed
- Locations: `lib/data/db/database.dart:252`, `lib/features/places/place_picker_sheet.dart:241`, `lib/features/travel_mode/travel_mode_screen.dart:206`, `lib/data/db/daos.dart:198`, `lib/data/places/place_book.dart:180`, `lib/features/home_tab/trip_detail_screen.dart:114`
- Conflicts with: none
- Effort: M (1 to 4 hours)
- Lines removable: 0

`duplicates.py` identifies 160 merged pairs of identical >=8-line normalized windows across `lib/`.
Substantive repetitions include the FTS5 trigger SQL definitions in `database.dart:252-283`, place-row builders in `place_picker_sheet.dart:241-307`, `BookPlace` row mapping in `place_book.dart:180-210`, and moment card actions shared between `travel_mode_screen.dart` and `trip_detail_screen.dart`.

Proof (V2):

    # docs/audits/AUDIT-001/scans/18-duplicates.txt (python docs/audits/AUDIT-001/scripts/duplicates.py)
    Total merged duplicate block pairs (>= 8 normalized lines): 160

Fix: Extract shared helpers for `BookPlace` row mapping in `lib/data/places/place_book.dart`, FTS trigger SQL generation in `lib/data/db/database.dart`, and place-result row rendering in `lib/features/places/place_picker_sheet.dart`.

### AUD-032: `WarangRepository` calls `_refreshAll()` redundantly alongside Drift streams and runs N+1 photo queries without an out-of-order guard

- Category: sloppy
- Severity: medium
- Status: Plausible
- Locations: `lib/data/repository.dart:47`, `lib/data/repository.dart:120`, `lib/data/repository.dart:665`, `lib/data/repository.dart:717`
- Conflicts with: `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` Phase 5
- Effort: M (1 to 4 hours)
- Lines removable: 0

`WarangRepository` subscribes to reactive Drift `watch*()` streams in `initialize()` (lines 47-67) and also invokes `await _refreshAll()` manually at the end of mutations, causing duplicate reloads on every write.
`_refreshMoments` at lines 717-741 issues one photo lookup per moment (N+1 queries) and writes `_moments` without a sequence check, so an earlier slower refresh can overwrite a newer state.
Batching the N+1 photo queries was previously deferred in `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` Phase 5 pending profiling.

Proof (V4):

    lib/data/repository.dart:47-67 (watch streams invoke _refresh* callbacks)
    lib/data/repository.dart:120-271, 399-553 (mutations also call await _refreshAll())
    lib/data/repository.dart:717-741 (_refreshMoments queries photos per moment in a loop without a generation counter).

Fix: Add a monotonic generation counter inside `_refreshMoments` to discard stale responses, coalesce overlapping `_refreshAll` triggers, and batch photo lookups in one `IN (...)` query once Len approves revisiting Phase 5.

### AUD-033: `WarangMapSurface` saves camera state on every pan frame, allocates `CachedTileProvider` and mutates pin sets inside `build()`, and never evicts `_photos`

- Category: sloppy
- Severity: medium
- Status: Plausible
- Locations: `lib/features/map/warang_map.dart:186`, `lib/features/map/warang_map.dart:197`, `lib/features/map/warang_map.dart:631`, `lib/features/map/warang_map.dart:677`
- Conflicts with: none
- Effort: M (1 to 4 hours)
- Lines removable: 0

`WarangMapSurface` writes camera coordinates to `sqflite` on every `onPositionChanged` callback at line 186 without debouncing, generating dozens of SQLite writes per second during pan gestures.
`build()` instantiates a fresh `CachedTileProvider` at line 197 and mutates `_returning`, `_landed`, and `_landing` state sets at lines 631-636, while `_photos` at line 677 caches resolved `File` paths indefinitely without pruning deleted moments.

Proof (V4):

    lib/features/map/warang_map.dart:186 (onPositionChanged -> _tileStore.saveCamera on every frame)
    lib/features/map/warang_map.dart:197-203 (CachedTileProvider constructed inside build)
    lib/features/map/warang_map.dart:631-636 (state sets mutated inside build)
    lib/features/map/warang_map.dart:677-684 (_photos map grows without eviction)

Fix: Debounce `saveCamera` by 400 ms (flushing in `dispose()`), cache `CachedTileProvider` in state (recreating only when `tileStore` changes), move pin-animation tracking into `didUpdateWidget`, and prune `_photos` entries for removed moment IDs.

### AUD-034: `PhotoStore.sweepOrphans` blocks startup before `runApp()`, scans `validRows` in O(N^2), and soft-deletes rows outside a transaction

- Category: sloppy
- Severity: medium
- Status: Plausible
- Locations: `lib/main.dart:28`, `lib/data/files/photo_store.dart:118`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`main()` awaits `photoStore.sweepOrphans(database)` at `lib/main.dart:28` before calling `runApp()`, delaying the first frame on startup as the photo library grows.
Inside `sweepOrphans` (`lib/data/files/photo_store.dart:118-178`), checking referenced paths against a `List` produces O(N^2) work and each missing-file soft-delete executes a separate database update outside a transaction.

Proof (V4):

    lib/main.dart:28 (await photoStore.sweepOrphans(database); before runApp at line 31)
    lib/data/files/photo_store.dart:141-143 (per-row soft-delete loop outside transaction) and List.contains scan over referenced paths.

Fix: Convert referenced paths to a `Set<String>`, batch soft-delete updates inside one `database.transaction`, and defer `sweepOrphans` to a post-frame background task after `runApp()`.

### AUD-035: `test/android_hardening_test.dart` greps raw source strings instead of verifying merged release manifest and APK properties

- Category: sloppy
- Severity: medium
- Status: Plausible
- Locations: `test/android_hardening_test.dart:5`
- Conflicts with: none
- Effort: M (1 to 4 hours)
- Lines removable: 0

`test/android_hardening_test.dart` reads raw XML and Gradle source files with `contains(...)` checks rather than inspecting a merged manifest or release build output.
All three tests in the file pass at `7d6703f` even while the main manifest lacks `android.permission.INTERNET` (`AUD-001`).

Proof (V4):

    test/android_hardening_test.dart:5-58 checks only allowBackup="false", cleartextTrafficPermitted="false", and key.properties presence via raw String.contains.
    flutter test test/android_hardening_test.dart -> +3: All tests passed! despite AUD-001.

Fix: Add manifest checks for required release permissions (`INTERNET`, location) in `test/android_hardening_test.dart`, and verify the built release APK with `aapt2 dump permissions` inside `scripts/build-and-archive.*`.

### AUD-036: 29 unawaited futures in non-async functions without explicit `unawaited(...)` markers

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `lib/data/places/place_book_installer.dart:140`, `lib/features/map/warang_map.dart:123`, `lib/features/capture/capture_screen.dart:59`, `lib/app/shell/dock.dart:60`, `lib/app/theme/clay.dart:682`, `lib/app/theme/clay_components.dart:505`, `lib/app/theme/components.dart:234`, `lib/features/home_tab/trip_detail_screen.dart:36`, `lib/features/home_tab/trip_form_screen.dart:68`, `lib/features/maya/maya_companion.dart:158`, `lib/features/places/place_picker_sheet.dart:99`, `lib/features/search/search_tab_screen.dart:322`, `lib/features/map/warang_map.dart:723`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

The strict lint `discarded_futures` flags 29 unawaited future calls inside synchronous functions across 13 `lib/` files, including `WarangHaptic.*.play()`, `AnimationController` triggers, and async helper launches.
Without explicit `unawaited(...)` markers, reviewers cannot distinguish intentional fire-and-forget calls from accidentally dropped futures.

Proof (V2):

    # docs/audits/AUDIT-001/scans/01-strict-lints.txt
    # 29 info hits for discarded_futures across 13 lib/ files (e.g., place_book_installer.dart:140, warang_map.dart:123, capture_screen.dart:59).

Fix: Wrap intentional fire-and-forget calls with `unawaited(...)` from `dart:async` (or return `void` from `WarangHaptic.play()` if callers never await it) and enable `discarded_futures` in `analysis_options.yaml`.

### AUD-037: 30 hardcoded `EdgeInsets`, `Duration`, and `Colors.transparent` literals outside `lib/app/theme/`

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `lib/app/shell/dock.dart:313`, `lib/app/shell/you_sheet.dart:41`, `lib/core/place_categories.dart:32`, `lib/features/capture/capture_screen.dart:43`, `lib/features/home_tab/home_tab_screen.dart:335`, `lib/features/map/warang_map.dart:183`, `lib/features/maya/maya_companion.dart:129`, `lib/features/onboarding/onboarding_screen.dart:52`, `lib/features/places/place_picker_sheet.dart:115`, `lib/features/search/search_tab_screen.dart:196`, `lib/features/settings/settings_screen.dart:168`, `lib/features/travel_mode/travel_mode_screen.dart:65`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

Thirty styling literals (`EdgeInsets`, `Duration`, and `Colors.transparent`) appear in feature files outside `lib/app/theme/`, bypassing `WarangMotion` durations and the theme generally.
No spacing token class exists today; `WarangLayout` at `lib/app/theme/tokens.dart:155` holds only dock and rail sizes.
Scattering raw spacing and animation durations makes global layout or motion tuning error-prone.

Proof (V2):

    # docs/audits/AUDIT-001/scans/15-hardcoded-style.txt
    # 30 matches across 12 files outside lib/app/theme/.

Fix: Replace hardcoded `Duration` literals in feature screens with `WarangMotion` constants (`lib/app/theme/motion.dart`), and add a spacing scale to `lib/app/theme/tokens.dart` for the repeated `EdgeInsets` values only if Len approves a new token set under FEAT-003.

### AUD-038: 19 untyped `catch` blocks in `lib/` catch `Error` alongside `Exception`

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `lib/app/device_providers.dart:65`, `lib/data/files/photo_store.dart:227`, `lib/data/places/place_book_installer.dart:97`, `lib/data/repository.dart:361`, `lib/features/capture/capture_screen.dart:150`, `lib/features/home_tab/trip_form_screen.dart:140`, `lib/features/home_tab/trip_photo.dart:46`, `lib/features/map/map_tile_store.dart:135`, `lib/features/map/warang_map.dart:571`, `lib/features/travel_mode/moment_edit_sheet.dart:138`, `lib/features/travel_mode/travel_mode_screen.dart:1102`, `lib/data/places/place_book_installer.dart:158`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

Nineteen `catch` clauses in `lib/` (plus four in `test/`) omit `on Exception`, so programming errors such as `TypeError`, `RangeError`, or `StateError` are caught alongside runtime I/O or platform exceptions.
Catching `Error` silently converts developer bugs into generic fallback states.

Proof (V2):

    # docs/audits/AUDIT-001/scans/01-strict-lints.txt
    # 19 info hits for avoid_catches_without_on_clauses in lib/ (23 total including test/).

Fix: Narrow `catch (e)` blocks to `on Exception catch (e)` or specific exception types (`FileSystemException`, `PlatformException`, `HttpException`, `DatabaseException`) so programming `Error` instances fail loudly during testing.

### AUD-039: Direct `DateTime.now()` and unseeded `Random()` calls couple screens and tests to wall-clock time

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `lib/features/capture/capture_screen.dart:45`, `lib/features/home_tab/home_tab_screen.dart:129`, `lib/features/home_tab/home_tab_screen.dart:322`, `lib/features/map/map_tile_store.dart:51`, `lib/features/maya/maya_companion.dart:212`, `test/capture_flow_test.dart:138`, `test/trips_flow_test.dart:87`, `test/user_journey_test.dart:168`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

Four `lib/` files read `DateTime.now()` or construct unseeded `Random()` directly instead of taking an injected clock or RNG, and three test suites construct test fixtures with `DateTime.now()`.
This already causes `08_home_scrolled_*` and `12_capture_*` golden screenshots to drift with the system clock (noted in `HANDOFF.md`) and makes date-boundary tests sensitive to midnight or DST transitions.

Proof (V2):

    # docs/audits/AUDIT-001/scans/16-time-and-random.txt
    lib/features/capture/capture_screen.dart:45:  late final DateTime _capturedAt = DateTime.now();
    lib/features/home_tab/home_tab_screen.dart:129, 322; lib/features/map/map_tile_store.dart:51; lib/features/maya/maya_companion.dart:212
    test/capture_flow_test.dart:138; test/trips_flow_test.dart:87; test/user_journey_test.dart:168

Fix: Expose a `clockProvider` (`DateTime Function()`) in `lib/app/app_state.dart` (defaulting to `DateTime.now`), pass fixed `DateTime` literals in the three test files, and allow injecting `math.Random` in `MayaCompanion`.

### AUD-040: Widget tests rely on real-time `Future.delayed` sleeps and 11-second fixed `pump` durations

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `test/utility_screens_test.dart:82`, `test/maya_test.dart:270`, `test/reduced_motion_test.dart:187`, `test/shell_navigation_test.dart:236`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`test/utility_screens_test.dart` calls `Future.delayed` five times (`:82,115,215,250,353`) to wait for async widget updates, while `test/maya_test.dart:270,344`, `test/reduced_motion_test.dart:187,204`, and `test/shell_navigation_test.dart:236` advance fake time with fixed 11-second `tester.pump` calls.
Real-time sleeps introduce flakiness under slow CI or Windows disk load.

Proof (V2):

    # docs/audits/AUDIT-001/scans/21-tests.txt
    test/utility_screens_test.dart:82, 115, 215, 250, 353 (Future.delayed)
    test/maya_test.dart:270, 344; test/reduced_motion_test.dart:187, 204; test/shell_navigation_test.dart:236 (pump(Duration(seconds: 11)))

Fix: Replace `Future.delayed` in `test/utility_screens_test.dart` with explicit `Completer` synchronization or `tester.pumpAndSettle()`, and document or centralize the idle-timer test constant shared with `MayaCompanion`.

### AUD-041: Hardcoded SQL `_categoryNameCaseSql` duplicates category display names from `PlaceCategories`

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `lib/data/db/database.dart:36`, `lib/data/db/database.dart:258`, `lib/data/db/database.dart:275`, `lib/data/db/database.dart:300`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`lib/data/db/database.dart:36-54` hardcodes a 12-branch SQL `CASE` string mapping category keys to display names and interpolates it into four FTS5 trigger and rebuild queries (`:258,275,300,336`).
The canonical category names live in `lib/core/place_categories.dart:32-41`, so renaming or adding a category in `PlaceCategories` silently drifts out of sync with SQLite full-text search.

Proof (V1, V2):

    # docs/audits/AUDIT-001/scans/11-sql-and-fts.txt
    lib/data/db/database.dart:36-54 defines _categoryNameCaseSql manually; interpolated at lines 258, 275, 300, 336.

Fix: Build `_categoryNameCaseSql` dynamically from `PlaceCategories.all` (escaping single quotes) and add a unit test asserting every `PlaceCategory.key` and `label` appears in the generated SQL `CASE`.

### AUD-042: Release Gradle config keeps the template `TODO` and casts `keystoreProperties` with `as String`

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `android/app/build.gradle.kts:36`, `android/app/build.gradle.kts:49`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

Line 36 still contains Flutter's boilerplate `TODO: Specify your own unique Application ID` although `applicationId` is already `ph.warang.app`, and lines 49-52 cast `keystoreProperties[...]` with `as String`, throwing an unclear `NullPointerException` if any property key is missing from `android/key.properties`.
Release shrinking is not a problem: the `release` block at lines 57-63 sets only `signingConfig`, but the Flutter Gradle plugin turns on `isMinifyEnabled` and `isShrinkResources` for release builds by default, and the 2026-11-23 release build wrote an R8 mapping file.

Proof (V2):

    # docs/audits/AUDIT-001/scans/19-android.txt
    android/app/build.gradle.kts:36: // TODO: Specify your own unique Application ID
    android/app/build.gradle.kts:49-52: keyAlias = keystoreProperties["keyAlias"] as String (4 unchecked casts)
    # Flutter SDK packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt:217-218: releaseBuildType.isMinifyEnabled = true; releaseBuildType.isShrinkResources = FlutterPluginUtils.isBuiltAsApp(project)
    # build/app/outputs/mapping/release/mapping.txt exists (6209270 bytes, 2026-11-23 21:15).

Fix: Remove the stale `TODO` at line 36, and validate all four `keystoreProperties` keys with `requireNotNull(keystoreProperties.getProperty(key))`.

### AUD-043: Amber text tokens diverge between `WarangColors` and `WarangKeepsake.amber`, and `ColorScheme.error` hardcodes raw colours

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `lib/app/theme/tokens.dart:33`, `lib/app/theme/tokens.dart:266`, `lib/app/theme/palette.dart:67`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`WarangColors.lightAccentText` (`0xFF8A6412`) and `darkAccentText` (`0xFFE8A020`) in `tokens.dart:33-34` duplicate and diverge from `WarangKeepsake.amber` in `palette.dart:67-69`.
In the same file, `buildWarangTheme` hardcodes `error: const Color(0xFFB8493D)` and `onError: Colors.white` at lines 266-267 instead of referencing a semantic palette token.

Proof (V1, V4):

    lib/app/theme/tokens.dart:33-34 defines lightAccentText/darkAccentText separately from lib/app/theme/palette.dart:67-69.
    lib/app/theme/tokens.dart:266-267 hardcodes Color(0xFFB8493D) and Colors.white inside ColorScheme.

Fix: Derive `WarangColors.accentText` from `WarangKeepsake.amber` (or document the exact contrast delta) and move the error colour pair into `WarangColors` / `WarangKeepsake` tokens.

### AUD-044: Core product concepts carry conflicting names (`HomeTabScreen` for Trips, `TravelModeScreen` for Map, `MemoryStats` for Moment totals)

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `lib/features/home_tab/home_tab_screen.dart:1`, `lib/features/travel_mode/travel_mode_screen.dart:1`, `lib/core/memory_stats.dart:1`
- Conflicts with: none
- Effort: M (1 to 4 hours)
- Lines removable: 0

Three central files and classes still carry pre-redesign names that contradict the current UI and data model: `HomeTabScreen` renders the "Trips" tab, `TravelModeScreen` renders the "Map" tab, and `MemoryStats` aggregates `Moment` records.
New contributors and agents searching for "Trips" or "Map" screens must know these legacy aliases.

Proof (V1):

    # lib/app/shell/app_shell.dart wires TravelModeScreen to the Map tab and HomeTabScreen to the Trips tab.
    # lib/core/memory_stats.dart:MemoryStats.from(List<Moment>) summarizes Moment objects under the name Memory.

Fix: Rename `HomeTabScreen` to `TripsTabScreen`, `TravelModeScreen` to `MapTabScreen`, and `MemoryStats` to `MomentStats` in one dedicated rename PR with updated imports and tests.

### AUD-045: App version `'1.0.0'` is hardcoded in Dart separately from `pubspec.yaml`

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `lib/features/settings/about_screen.dart:12`, `lib/features/settings/settings_screen.dart:103`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`AboutScreen.version` hardcodes `static const version = '1.0.0';` at `lib/features/settings/about_screen.dart:12`, which `SettingsScreen` displays at line 103.
Bumping `version:` in `pubspec.yaml` leaves the in-app About and Settings screens reporting `1.0.0`.

Proof (V1):

    git grep -n "AboutScreen.version" -- lib test tool
    lib/features/settings/settings_screen.dart:103:                    value: AboutScreen.version,
    # lib/features/settings/about_screen.dart:12: static const version = '1.0.0';

Fix: Pass the version from `scripts/build-and-archive.*` via `--dart-define=APP_VERSION=...` read with `String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')`, or expose `package_info_plus` directly in `pubspec.yaml` if Len approves adding it as a direct dependency.

### AUD-046: Location permission flow is duplicated with divergent checks between `device_providers.dart` and `warang_map.dart`

- Category: sloppy
- Severity: low
- Status: Plausible
- Locations: `lib/app/device_providers.dart:35`, `lib/features/map/warang_map.dart:526`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`locationPermissionProvider` in `lib/app/device_providers.dart:35-42`, used by `locationReaderProvider` at lines 45-69 for capture, checks `Geolocator.checkPermission()` without calling `Geolocator.isLocationServiceEnabled()` and without displaying a rationale dialog.
`_refreshLocation` in `lib/features/map/warang_map.dart:526-575` checks both service status and permission and shows an explanation dialog, creating two inconsistent GPS experiences between capture and map recentering.

Proof (V4):

    lib/app/device_providers.dart:35-42 (locationPermissionProvider: no isLocationServiceEnabled check, no rationale UI) -> lines 45-69 (locationReaderProvider)
    lib/features/map/warang_map.dart:526 (_refreshLocation) -> line 528 (isLocationServiceEnabled) -> line 532 (showDialog explanation)

Fix: Extract one shared location-access helper in `lib/app/device_providers.dart` that checks `isLocationServiceEnabled()` and permission status consistently across capture and map recentering.

### AUD-047: Routine test runs emit diagnostic `print` and `debugPrint` noise

- Category: sloppy
- Severity: low
- Status: Confirmed
- Locations: `test/stamps_test.dart:230`, `test/place_book_test.dart:194`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`test/stamps_test.dart:230-231` suppresses `avoid_print` to print benchmark timings during every `flutter test` run, and `test/place_book_test.dart:194` calls `debugPrint(...)`.
Unnecessary console output obscures real warnings during test execution.

Proof (V2):

    # docs/audits/AUDIT-001/scans/14-debug-and-markers.txt
    test/stamps_test.dart:230-231: // ignore: avoid_print + print(...)
    test/place_book_test.dart:194: debugPrint(...)

Fix: Delete the `print` and `debugPrint` calls in `test/stamps_test.dart:230-231` and `test/place_book_test.dart:194`, keeping the underlying timing/count `expect(...)` assertions.

### AUD-048: `WarangDatabase.beforeOpen` re-executes 10 FTS and index DDL statements on every app launch

- Category: sloppy
- Severity: low
- Status: Plausible
- Locations: `lib/data/db/database.dart:138`, `lib/data/db/database.dart:218`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`WarangDatabase.migration.beforeOpen` runs `_createPlacesIndex()` and `_createSearchIndex()` on every database open, executing 10 `CREATE INDEX IF NOT EXISTS` / `CREATE VIRTUAL TABLE IF NOT EXISTS` / `CREATE TRIGGER IF NOT EXISTS` DDL statements on every launch even when the schema version has not changed.

Proof (V4):

    lib/data/db/database.dart:138-142 (beforeOpen awaits _createPlacesIndex() and _createSearchIndex() unconditionally)
    lib/data/db/database.dart:218-320 (10 DDL statements executed per open)

Fix: Run `_createPlacesIndex()` and `_createSearchIndex()` inside `onCreate` and `onUpgrade` only, keeping `PRAGMA foreign_keys = ON` in `beforeOpen`.

### AUD-049: `_SpringCurve` allocates `SpringDescription` and `SpringSimulation` on every animation frame

- Category: sloppy
- Severity: low
- Status: Plausible
- Locations: `lib/app/theme/motion.dart:24`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`_SpringCurve.transformInternal` constructs a new `SpringDescription` and `SpringSimulation` on every animation frame tick, and `WarangSpring.curve` / `settleCurve` allocate a new `_SpringCurve` on every getter access.
Precomputing the `SpringSimulation` once per `WarangSpring` eliminates per-frame allocations during clay animations.

Proof (V4):

    lib/app/theme/motion.dart:24-43 (_SpringCurve.transformInternal instantiates SpringDescription + SpringSimulation on every t evaluation).

Fix: Construct and cache `final SpringSimulation _simulation` in `_SpringCurve` (or `WarangSpring`) once instead of inside `transformInternal`.

### AUD-050: `coversDay` advances dates with `Duration(days: 1)` without `.toLocal()` normalization

- Category: sloppy
- Severity: low
- Status: Plausible
- Locations: `lib/core/trip_rules.dart:38`
- Conflicts with: none
- Effort: S (under 1 hour)
- Lines removable: 0

`coversDay` in `lib/core/trip_rules.dart:38-42` computes date boundaries via `.add(const Duration(days: 1))` without `.toLocal()` normalization or calendar-day construction (`DateTime(y, m, d + 1)`), diverging from `lib/core/stamps.dart:114`.
On devices in time zones observing daylight saving time, adding 24 hours can land at 23:00 of the same day or 01:00 of the next day.
The Philippines does not observe daylight saving time, so this affects only travellers whose device is set to a zone that does.

Proof (V4):

    lib/core/trip_rules.dart:38-42 (uses .add(const Duration(days: 1)) without .toLocal() or DateTime(y, m, d + 1), unlike lib/core/stamps.dart:114).

Fix: Normalize timestamps with `.toLocal()` and compare calendar days using `DateTime(d.year, d.month, d.day)` / `DateTime(d.year, d.month, d.day + 1)` to match `lib/core/stamps.dart:114`.

## Remediation batches

These batches group all 51 findings into actionable future features Len can approve independently.

### Batch 1: Release blocker and Android hardening

- Findings: `AUD-001`, `AUD-012`, `AUD-035`, `AUD-042`, `AUD-045`, `AUD-051`
- Total effort: M (2 to 4 hours)
- Risk to working features: Low; adds the missing `INTERNET` permission and tightens the release build and archive checks (R8 shrinking is already on through the Flutter Gradle plugin and needs no change).
- Guarding tests: Expanded `test/android_hardening_test.dart`, release APK `aapt2 dump permissions` and `apksigner verify` checks, and Len's physical-device check loading map tiles in a signed release build.
- Approved decisions needing change: none.

### Batch 2: Offline map tile store and map surface stability

- Findings: `AUD-002`, `AUD-007`, `AUD-020`, `AUD-021`, `AUD-033`, `AUD-046`
- Total effort: L (5 to 8 hours)
- Risk to working features: Medium; touches map panning, offline tile caching, and GPS recentering.
- Guarding tests: `test/map_tile_store_test.dart` (add fresh-hit zero-HTTP test and LRU eviction test), `test/map_pins_test.dart`, `test/map_places_test.dart`, `test/map_clusters_and_credit_test.dart`.
- Approved decisions needing change: none (preserves `docs/IMPLEMENTATION_PLAN.md` T17 separate `sqflite` cache and completes `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` Phase 5).

### Batch 3: UI-thread media, place book install, and GPU image hygiene

- Findings: `AUD-003`, `AUD-004`, `AUD-013`, `AUD-015`, `AUD-034`, `AUD-049`
- Total effort: L (6 to 10 hours)
- Risk to working features: Medium; moves photo decoding, place book queries, and orphan sweep off the UI isolate, bounds avatar picks, and adds `ui.Image` disposal.
- Guarding tests: `test/photo_store_test.dart`, `test/place_book_test.dart`, `test/capture_flow_test.dart`, `test/clay_components_test.dart`, plus a physical-device test picking a 48 MP gallery photo as the avatar and a cold first launch.
- Approved decisions needing change: none.

### Batch 4: Save integrity, transactions, and UI state safety

- Findings: `AUD-005`, `AUD-006`, `AUD-008`, `AUD-009`, `AUD-010`, `AUD-011`, `AUD-014`, `AUD-016`, `AUD-017`, `AUD-018`
- Total effort: L (6 to 9 hours)
- Risk to working features: Medium; modifies save flows, search refresh, avatar replacement, and v1-to-v2 migration.
- Guarding tests: `test/capture_flow_test.dart`, `test/trips_flow_test.dart`, `test/moment_actions_test.dart`, `test/user_journey_test.dart`, `test/migration_test.dart`, `test/maya_test.dart`, plus new regression tests converted from the Phase 3 V3 probes.
- Approved decisions needing change: none.

### Batch 5: Dead code, unused assets, and mechanical `dart fix` cleanup (Ponytail pass 2)

- Findings: `AUD-023`, `AUD-024`, `AUD-025`, `AUD-026`, `AUD-027`, `AUD-028`, `AUD-029`, `AUD-036`, `AUD-038`, `AUD-047`
- Total effort: M (2 to 4 hours)
- Risk to working features: Low; deletes dead code and assets and applies selected lint fixes (not a blanket `dart fix --apply`, see `AUD-025`) with zero intended UI change.
- Guarding tests: Full `flutter analyze` and `flutter test` suite (329 tests) plus golden visual regression check.
- Approved decisions needing change: `docs/features/FEAT-003-clay-keepsake-redesign.md` C11 (`WarangToggle`) and M4 (`MayaPose.footTap`) if Len approves deleting them, and Len's call on keeping `assets/Logo.png` and `design/warang-canvas.html` as sources (`AUD-026`).

### Batch 6: Structural maintainability, repository performance, and tooling hygiene

- Findings: `AUD-019`, `AUD-022`, `AUD-030`, `AUD-031`, `AUD-032`, `AUD-037`, `AUD-039`, `AUD-040`, `AUD-041`, `AUD-043`, `AUD-044`, `AUD-048`, `AUD-050`
- Total effort: L (10+ hours, split into smaller focused PRs)
- Risk to working features: Medium; touches large screens, repository refresh plumbing, SQLite dependency migration, and core class names.
- Guarding tests: Full `flutter test` suite, `test/data_layer_test.dart`, `test/contrast_test.dart`, `test/theme_tokens_test.dart`, `test/core_rules_test.dart`, and `tool/place_book/build_place_book.py` dry run.
- Approved decisions needing change: `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` Phase 5 (for batching N+1 photo queries in `AUD-032`) and Len's dependency approval for replacing `sqlite3_flutter_libs` (`AUD-019`).

## Limitations

- Strict lint deprecation: `use_if_null_to_convert_nulls_to_bools` emitted 1 `deprecated_lint` warning in Dart 3.12.2 during the Phase 1 detached-worktree run; no rule had to be dropped because the analyzer still executed all 20 extra rules cleanly.
- Probes not possible without `lib/` edits or physical devices: `AUD-003` and `AUD-004` (require real device frame-timing and memory profiling), `AUD-006` (injecting a fault between sequential Drift calls inside `MomentEditSheet` requires altering internal DAO wiring), `AUD-018` (`ImagePicker()` is instantiated inline inside `pickProfilePhoto`), and `AUD-051` (requires a full release build).
- Revision 1 listed `AUD-001` here; revision 2 removed it, because `android/key.properties` is present locally and the existing release APKs were inspected with `aapt2` instead.
- The V3 probe sources under `test/_audit_probe/` were deleted after Phase 3 without a saved copy, so the probe outputs quoted in `AUD-002`, `AUD-005`, `AUD-008`, `AUD-010`, `AUD-011`, `AUD-014`, and `AUD-016` cannot be rerun from the repository; a re-verification has to rewrite those probes.
- `check_report.py` checks field format and that each `path:line` exists, but not that the functions and code a finding names exist; revision 2 adds `check_identifiers.py` (scan `23-identifier-check.txt`) for that.
- Areas checked by reading and static scans only: `android/` Gradle and XML configs, `scripts/build-and-archive.*` (untracked in Git), `tool/place_book/build_place_book.py`, and `lib/app/theme/warang_icons.dart` (generated icon codepoints).
- Physical-device validation remains pending and owned by Len: verifying OSM tile loading on a signed release APK, picking a >30 MP gallery photo as the avatar, cold-start place book installation timing, GPS permission dialogs, and offline airplane-mode behavior.

## Appendix: rejected candidates

Twelve of the 62 unique evaluated candidates (after merging 15 duplicate candidates with shared root causes, detailed in `docs/evidence/AUDIT-001-verification.md`) were rejected.

| Candidate | Location | Claim | Reason rejected |
| --- | --- | --- | --- |
| C-002 | `assets/place_book/place_book.sqlite`, `docs/evidence/FEAT-001/` | Tracked place book SQLite and evidence PNGs bloat repository weight | `place_book.sqlite` (25.3 MB) is approved under FEAT-004 C-1 and within REQ-003's 40 MB budget; `docs/evidence/` PNGs are non-runtime verification files outside APK assets. |
| C-007 | `lib/data/files/photo_store.dart:106` (12 sites) | Strict lint `avoid_slow_async_io` flags async `File.exists()` calls | Lint targets CLI/server Dart; async `exists()` in Flutter UI intentionally avoids blocking the UI thread (the actual sync-IO bug is tracked in `AUD-013`). |
| C-012 | `pubspec.yaml:44` | Three font OFL license text files have zero Dart references | Bundling the three font OFL files is explicitly required by `docs/features/FEAT-003-clay-keepsake-redesign.md` V3 and REQ-004. |
| C-013 | `design/icons/` | Tracked SVG sources and `build_icons.py` are undeclared in `pubspec.yaml` | Required source inputs and generator script under FEAT-003 P-2 and FEAT-004 P-3. |
| C-016 | `lib/app/theme/clay_components.dart:486` | `WarangStamp.resetSession` is referenced only in tests | Intentional test-isolation hook called by 6 test files; the broader static-state issue is reported in `AUD-010`. |
| C-017 | `lib/app/theme/palette.dart:126` | `WarangKeepsake.tripTones` is referenced only in tests | Intentional public palette contract constant verified by `test/trips_shelf_test.dart:88`. |
| C-018 | `lib/core/place_categories.dart:163` | `PlaceCategories.stampCategories` is referenced only in tests | Intentional public FEAT-004 REQ-009 stamp-set contract verified by `test/stamps_test.dart:89,208`. |
| C-019 | `lib/data/files/photo_store.dart:114` | `PhotoStore.storeBytesAsset` is referenced only in tests and tools | Intentional test and golden-screenshot fixture helper called at 7 sites across `test/photo_store_test.dart` and `tool/ux_screenshots_test.dart`. |
| C-020 | `lib/data/places/place_book.dart:144` | `PlaceBook.readMeta` is referenced only in tests | Intentional metadata inspection API required by FEAT-004 REQ-002 and verified in `test/place_book_test.dart:155`. |
| C-028 | `lib/features/places/place_picker_sheet.dart:156` | `setState(() => _loading = true)` appears after an `await` in `_runQuery` | False positive from regex scan: line 156 runs synchronously before `await book.search` at line 157; the earlier `await` at line 136 is inside an early-returning `if (query.isEmpty)` branch. |
| C-029 | `lib/app/theme/clay_components.dart:229` | Lazily created `_ownFocus` and scan-10 lifecycle resources may leak | Manual review of every controller, `FocusNode`, `StreamSubscription`, and `Timer` in `10-lifecycle.txt` confirmed matching `dispose()`/`cancel()` calls (`_ownFocus?.dispose()` at line 257). |
| C-045 | `test/icon_semantics_test.dart:112` (12 tests) | Twelve `testWidgets` blocks contain no direct `expect()` call | `icon_semantics_test.dart` delegates to `expectLabelledIcons()`, `maya_test.dart` delegates to `expectMaya()`, and `tool/ux_screenshots_test.dart` is a golden generator using `matchesGoldenFile`. |

## Appendix: revision 2 corrections

Revision 2 applies a Claude Code review of revision 1 (`946b3d7`), requested by Len on 2026-11-24 ("Yes make the corrections, Ill have gemini re verify it").
Every correction below was checked against the code at `946b3d7`, which matches `7d6703f` for all product paths; the commands and outputs are in `docs/evidence/AUDIT-001-verification.md` under "Revision 2 review" and "Gemini re-verification of revision 2".
Gemini re-verified revision 2 against the codebase, local build artifacts, Flutter SDK, and Drift pub cache on 2026-11-24 and corrected one line-range typo in `AUD-017` (`from < 3` spans `database.dart:69-133`, not `69-73`).

### Withdrawn sub-claims

| Finding | Revision 1 claim | Why it was withdrawn |
| --- | --- | --- |
| `AUD-042` (and `AUD-035`, Batch 1) | Release builds leave R8 code and resource shrinking off. | The Flutter Gradle plugin sets `isMinifyEnabled = true` and `isShrinkResources` for release (`FlutterPlugin.kt:217-218`), and `build/app/outputs/mapping/release/mapping.txt` exists from the 2026-11-23 release build. |
| `AUD-009` | The Undo snackbar calls `ref.read(repositoryProvider)` at `travel_mode_screen.dart:152` without a `mounted` check. | `_delete` already reads `repository` and `selection` at lines 137-138 before the snackbar; line 152 is `selection.select(restored)`. |
| `AUD-005` | `TripFormScreen` has a mid-save dismissal gap on step 0. | The form saves only on its last question (`_last`, line 106); the real gap is `_step--` on Back and the always-enabled Close button during a last-step save, now described in the finding. |

### Wrong names and invented code corrected

| Finding | Revision 1 text | Code at HEAD |
| --- | --- | --- |
| `AUD-004` | `_decodeAndFit`, `maxPixels`; 48 MP camera photos | `_decode` (`photo_store.dart:223`) and the literal `30 * 1000 * 1000` (line 231); camera input is already bounded by `pickImage(maxWidth: 2000)` (`device_providers.dart:28-31`), and only the avatar picker (`you_sheet.dart:348`) is unbounded. |
| `AUD-006` | `setMomentPlace`, `attachMomentPlace`, `setMomentCategory` | `updateMoment`, then `clearPlace`, `attachBookPlace`, or `attachUserPlace`, then `setPlaceCategory` (`moment_edit_sheet.dart:107-134`); `_confirmPlacement` calls `setMomentLocation` and `attachBookPlace` (lines 198, 200). |
| `AUD-017` | `trips.colour`; `from < 3` at lines 69-94 | `trips.colorKey` (line 66); `from < 3` runs at lines 69-133 (`transaction` lines 70-132; initial rev 2 text wrote `69-73`, fixed during Gemini re-verification). |
| `AUD-018` | `PhotoStore.maxPixels`, `PhotoTooLargeException`, `imagePickerProvider` | None of the three exist; the cap throws `FormatException`, and the existing provider is `cameraPickerProvider`. |
| `AUD-025` | Before and after examples `final c = color!;`, `if (flag == true)`, `book.nearby(lat: lat, lon: lon, limit: 20)`; 74 lines removable | The real lines are `widget.tooltip!` (`clay.dart:746`), `place?.trim().isEmpty == true` (`repository.dart:414`), and `book.nearby(widget.near!, 150, limit: 8)` (`place_picker_sheet.dart:136`); only 27 hits remove a whole line. |
| `AUD-037` | `WarangSpace` | No such class; `WarangLayout` (`tokens.dart:155`) holds only dock and rail sizes. |
| `AUD-046` | `defaultLocationReader`, `_locateUser` | `locationPermissionProvider` and `locationReaderProvider` (`device_providers.dart:35-69`); `_refreshLocation` (`warang_map.dart:526`). |
| `AUD-002` | Unbounded HTTP clients risking socket exhaustion | Each client is closed in `finally` (`map_tile_store.dart:411`); the cost is no connection reuse and no timeout. |
| `AUD-012` | Both scripts should start failing on zero APKs and use a JSON serializer | `build-and-archive.ps1` already stops on zero APKs (lines 32, 122-124) and already uses `ConvertTo-Json` (line 179); both scripts are untracked. |

### Severity changes

| Finding | Revision 1 | Revision 2 | Reason |
| --- | --- | --- | --- |
| `AUD-003` | high | medium | An interrupted copy repairs itself on the next launch; the real cost is place book queries on the UI isolate. |
| `AUD-007` | medium | low | The app's `ProviderContainer` (`main.dart:29`) is never disposed, so the bypassed hook would not run in production either. |
| `AUD-008` | medium | low | Fails only on corrupted app-written JSON or a broken bundled asset. |
| `AUD-010` | medium | low | Bundled asset loads seldom fail, and `StampTitles.load` failures are already caught at `repository.dart:359-363`. |
| `AUD-015` | medium | low | A hash collision among at most 48 entries is very unlikely. |
| `AUD-025` | medium | low | 27 removable lines, under the plan's 50-line medium threshold. |
| `AUD-026` | medium | low | 0 removable lines; deleting files does not shrink Git history, and two files may be design sources. |
| `AUD-001` | critical | critical (kept) | Kept as a release blocker, with a note that it does not match the plan's data-loss or security definition of critical. |

### Added finding and stronger proof

- `AUD-051` (new): both archive scripts archive stale APKs left from earlier builds under the new version and Git hash.
- `AUD-001`: `aapt2 dump permissions` on the 2026-11-23 release APK and the 2026-09-12 archived release shows no `INTERNET` permission; the debug APK has it.
- `AUD-009`: the Maya part now names the actual cause, a canceled `TickerFuture` that never completes, so `back` listeners pile up.
- `AUD-017`: Drift writes `user_version` only after every migration step succeeds (drift 2.34.4 `engines.dart:557-562`), so a failure after `addColumn` likely leaves the database unable to open.
- `check_identifiers.py` and scan `23-identifier-check.txt` list every code identifier the report names that the repository does not contain.
