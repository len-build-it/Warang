# Implementation Plan: AUDIT-001 remediation (Ponytail and Clean Code)

Created: 2026-11-24T21:40:00+08:00
Updated: 2026-11-27T07:42:00+08:00
Revision: 2
Status: In progress - Phase 1 complete
Feature spec and revision: None; this plan addresses the 51 findings in `docs/audits/AUDIT-001-code-quality-report.md` (revision 2, re-verified at `a8d3e68`) under requirements `REM-REQ-001` to `REM-REQ-006`, defined in this plan
Approved baseline and architecture revisions: `docs/IMPLEMENTATION_PLAN.md` at `dc407c5` (T17 keeps `sqflite` for map tiles), `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` at `dc407c5`, FEAT-001 to FEAT-004 revision 1 as listed in `docs/SPEC_INDEX.md`
Len's chat approval: 2026-11-26T23:32:00+08:00 chat, plan revision 2: "Approve, run without stops"; D-1: "Delete it and amend FEAT-003"; D-2 and D-3: "Yes, as recommended" (recorded in `HANDOFF.md`)
Target branch: `master` (verified 2026-11-26 at `0755fc6`; remote `origin` exists, and this plan never pushes)

## Scope

This plan fixes the verified findings in `docs/audits/AUDIT-001-code-quality-report.md` (revision 2) using the Ponytail ladder (stdlib and native APIs first, shortest root-cause diff, zero new dependencies) and Clean Code rules (local reasoning, explicit boundaries, deterministic tests).
Preserve all existing untracked paths: `.agents/skills/*`, `.agents/templates/`, `.claude/`, `CLAUDE.md`, `docs/evidence/FEAT-001/claude-review/`, `releases/`, and `scripts/`.
Never use `git add -A` or `git add .`, and never add a new dependency to `pubspec.yaml`.

### Execution mode

Len approved continuous execution on 2026-11-26 ("Approve, run without stops"), matching the outer workspace `AGENTS.md` rule "Execute every approved phase without routine approval stops."
For this plan only, that approval replaces the "mandatory hard stops" directive in the inner `Warang/AGENTS.md`.
Phases 1 to 6 run back to back with no approval stops between phases.
Each phase commits only after `flutter analyze`, its guarding `flutter test` suite, `check_claims.py`, and zero em/en-dash checks pass.
Execution stops only at a real blocker, after three failed fix-and-check attempts on the same problem, or before the `## Independent verification` phase (which must be executed by a separate agent or fresh session).

### Requirements and 51-finding coverage

| ID | Phase | Audit findings covered | Pass criterion |
| --- | --- | --- | --- |
| REM-REQ-001 | Phase 1 | `AUD-001`, `AUD-012`, `AUD-035`, `AUD-042`, `AUD-045`, `AUD-051` | Main manifest declares `INTERNET`, Gradle validates keystore properties cleanly, `AboutScreen.version` reads `APP_VERSION` and a widget test checks the shown version, archive scripts clear stale APKs and verify permissions/signing, and `test/android_hardening_test.dart` passes. |
| REM-REQ-002 | Phase 2 | `AUD-002`, `AUD-007`, `AUD-020`, `AUD-021`, `AUD-033`, `AUD-046` | Fresh map tiles trigger zero HTTP requests, shared `HttpClient` enforces timeouts, `304` avoids rewriting tile blobs, an existing tile database without `lastAccessedAt` upgrades in place, eviction runs least-recently-used first in a serialized transaction, `WarangMapSurface` debounces `saveCamera` and keeps state out of `build()`, and location checks share one helper. |
| REM-REQ-003 | Phase 3 | `AUD-003`, `AUD-004`, `AUD-013`, `AUD-015`, `AUD-034`, `AUD-049` | `PlaceBook` queries run in a background isolate with `schema_version` verification, `PhotoStore` decodes/encodes in `Isolate.run` with header dimension check and bounded avatar picks, `Image.file` sets `cacheWidth` without `existsSync()` in `build()`, `ClayDiscCache` uses record keys and disposes evicted images, `sweepOrphans` runs post-frame in one transaction, and `_SpringCurve` caches `SpringSimulation`. The first-install memory peak of the place book copy is recorded as a known limitation, not claimed fixed. |
| REM-REQ-004 | Phase 4 | `AUD-005`, `AUD-006`, `AUD-008`, `AUD-009`, `AUD-010`, `AUD-011`, `AUD-014`, `AUD-016`, `AUD-017`, `AUD-018` | Back/Close are blocked during saves, multi-step moment edits and placement run inside single Drift transactions, JSON parsing and `PlacePickerSheet._runQuery` handle errors cleanly, Maya drag listeners use `whenCompleteOrCancel`, failed asset caches clear on error, avatars clean up orphans, search refreshes on edits, v1-to-v2 migration runs in a transaction, and `pickProfilePhoto` uses an injectable provider with error feedback. |
| REM-REQ-005 | Phase 5 | `AUD-023`, `AUD-024`, `AUD-025`, `AUD-026`, `AUD-027`, `AUD-028`, `AUD-036`, `AUD-038`, `AUD-041`, `AUD-043`, `AUD-047`, `AUD-048`, `AUD-050` (plus `AUD-029`, kept under D-1) | Dead methods, YAGNI ad slots, unused theme/widget APIs, `WarangToggle` (with the FEAT-003 C11 amendment), confirmed-dead files, and test print noise are removed; readable `dart fix`, `unawaited`, and `on Exception` cleanups pass; `_categoryNameCaseSql` derives from `PlaceCategories.all`; DDL moves out of `beforeOpen`; `coversDay` normalizes `.toLocal()`. |
| REM-REQ-006 | Phase 6 | `AUD-022`, `AUD-030`, `AUD-031`, `AUD-032`, `AUD-037`, `AUD-039`, `AUD-040` | `WarangRepository` guards against out-of-order refreshes and coalesces `_refreshAll()`, repeated helpers and `_MomentPolaroid` are extracted cleanly, hardcoded durations use `WarangMotion`, `clockProvider` removes wall-clock test coupling, `Future.delayed` sleeps in `test/utility_screens_test.dart` are replaced, and `build_place_book.py` writes atomically. |

### Ponytail deferrals and decisions

Two findings are explicitly deferred rather than worked into this plan:

- `AUD-019` (`sqlite3_flutter_libs` `0.6.0+eol` at `pubspec.yaml:23`): deferred because replacing a dependency requires Len's explicit dependency approval and physical Android device testing.
- `AUD-044` (renaming `HomeTabScreen`, `TravelModeScreen`, `MemoryStats`): skipped under Ponytail because a broad class/file rename touches dozens of files for zero runtime or user benefit.

Len decided all three decisions on 2026-11-26:

- `D-1` (`AUD-023` and `AUD-029`, conflicting with `FEAT-003` C11 and M4): delete `WarangToggle` (`lib/app/theme/clay_components.dart:1147`, 103 lines) in Phase 5 and amend the approved FEAT-003 spec in the same phase, because `docs/features/FEAT-003-clay-keepsake-redesign.md:346` defines C11 and `docs/features/FEAT-003-clay-keepsake-redesign.md:452` says "Toggles use C11".
  Keep `MayaPose.footTap` (`lib/features/maya/maya_companion.dart:20`, 1 line) until layered Maya art (FEAT-003 `D-2`) lands.
- `D-2` (`AUD-026`): delete `assets/Logo2.png` and `design/ui-update/baseline/` in Phase 5, and keep `assets/Logo.png` and `design/warang-canvas.html` as brand/design sources.
- `D-3` (`AUD-012` and `AUD-051`): fix `scripts/build-and-archive.sh` and `scripts/build-and-archive.ps1` in place while keeping `scripts/` untracked (preserving the existing untracked-path rule).

New names: `APP_VERSION`, `requireKey`, `lastAccessedAt`, `_evicting`, `_httpClient`, `_cameraDebounce`, `_cachedTileProvider`, `checkLocationAccess`, `galleryPickerProvider`, `editMomentDetails`, `placeMoment`, `revision`, `_saving`, `clockProvider`, `_refreshGeneration`, `moment_polaroid.dart`
External names: `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `aapt2`, `apksigner`, `ConvertTo-Json`, `String.fromEnvironment`, `HttpClient`, `connectionTimeout`, `Isolate.run`, `startDecode`, `findDecoderForData`, `createInBackground`, `cacheWidth`, `errorBuilder`, `whenCompleteOrCancel`, `TickerFuture`, `SpringSimulation`, `unawaited`, `py_compile`, `os.replace`, `unnecessary_null_checks`, `unnecessary_lambdas`, `use_if_null_to_convert_nulls_to_bools`, `avoid_redundant_argument_values`, `discarded_futures`, `avoid_catches_without_on_clauses`, `check_claims.py`, `requireNotNull`, `getProperty`, `schema_version`, `maxHeight`, `fromEnvironment`, `dart-define`, `LASTEXITCODE`, `FileSystemException`, `DatabaseException`, `PlatformException`, `HttpException`, `TypeError`, `table_info`

### Framework citations

These SDK and package sources were opened on 2026-11-26 from the local Flutter SDK and pub cache (versions from `pubspec.lock`):

    image-4.9.2/lib/src/formats/formats.dart:191: Decoder? findDecoderForData(List<int> data) {
    image-4.9.2/lib/src/formats/decoder.dart:38:   DecodeInfo? startDecode(Uint8List bytes);
    drift-2.34.3/lib/native.dart:157:   static QueryExecutor createInBackground(
    flutter/packages/flutter/lib/src/scheduler/ticker.dart:462:   void whenCompleteOrCancel(VoidCallback callback) {
    flutter/packages/flutter/lib/src/services/asset_bundle.dart:67:   Future<ByteData> load(String key);

The last line matters for Phase 3: `AssetBundle.load` returns the whole asset as one `ByteData`, and the SDK has no streaming asset read, so no chunked copy can remove the first-install memory peak.
Any other framework behavior a phase relies on stays unverified until its source or official documentation is opened and cited in the evidence log.

## Shared gates for every phase

Run from `C:\Users\User\Desktop\PersonalProjects\04-FUN-STUFF\WARANG\Warang` before every phase commit:

1. `flutter analyze` prints `No issues found!`.
2. Phase-targeted `flutter test ...` passes, plus full `flutter test` at Phase 4, Phase 5, and Phase 6.
3. Claim check on every Markdown file created or changed in the phase: `python .agents/skills/implementation-plan/scripts/check_claims.py <files>` prints `0 problems`.
4. Writing rule check prints `0` for em/en dashes across changed Markdown files.
5. Probe or temporary test sources are saved under `docs/evidence/AUDIT-001-remediation/probes/` before they are deleted, with the exact command and output in the evidence log.
6. `git diff --cached --stat` shows only reviewed phase-related paths and zero preserved untracked paths.
7. Record actual commands, observed outputs, and timestamps in `docs/evidence/AUDIT-001-remediation-verification.md` (created in Phase 1 from `.agents/templates/docs/VERIFICATION.md`).

## Phase 1: Release blocker, Android hardening, and archive scripts

Requirements: `REM-REQ-001` (`AUD-001`, `AUD-012`, `AUD-035`, `AUD-042`, `AUD-045`, `AUD-051`)
State: Complete

Current code anchors:

    android/app/src/main/AndroidManifest.xml:2:     <uses-permission android:name="android.permission.INTERNET" />
    android/app/build.gradle.kts:25: fun requireKey(key: String): String {
    android/app/build.gradle.kts:58:                 keyAlias = requireKey("keyAlias")
    lib/features/settings/about_screen.dart:12:   static const version = String.fromEnvironment(
    lib/features/settings/about_screen.dart:55:                   'Version ${AboutScreen.version}',
    scripts/build-and-archive.sh:64: APKS=()
    scripts/build-and-archive.ps1:148: $apkFiles = @()

### Tasks

- [x] Add `<uses-permission android:name="android.permission.INTERNET" />` to `android/app/src/main/AndroidManifest.xml` (`AUD-001`).
- [x] Expand `test/android_hardening_test.dart` to verify `INTERNET`, `ACCESS_FINE_LOCATION`, and `ACCESS_COARSE_LOCATION` in `android/app/src/main/AndroidManifest.xml` and reject unchecked `keystoreProperties[...]` casts (`AUD-035`).
- [x] Remove the stale `TODO` at `android/app/build.gradle.kts:36` and validate all four `keystoreProperties` entries at lines `49-52` via a small `requireKey` helper using `requireNotNull(keystoreProperties.getProperty(key))` (`AUD-042`).
- [x] Update `AboutScreen.version` at `lib/features/settings/about_screen.dart:12` to `String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')` so version matches release builds with zero new dependencies (`AUD-045`).
- [x] Add a widget test in `test/utility_screens_test.dart` that pumps `AboutScreen` and expects the text `Version 1.0.0` when no `APP_VERSION` define is passed (`AUD-045`).
- [x] Harden untracked `scripts/build-and-archive.sh` and `scripts/build-and-archive.ps1` (`AUD-012`, `AUD-051`): pass `--dart-define=APP_VERSION=$VERSION`, remove stale `build/app/outputs/flutter-apk/*.apk` before building (or archive only the exact expected filenames for split vs universal mode), fail on zero APKs in `.sh`, serialize `.sh` JSON via Python `json.dumps`, check `$LASTEXITCODE` after `git` calls in `.ps1`, and verify `INTERNET` via `aapt2` plus signature via `apksigner` when tools are present on PATH.
- [x] Create `docs/evidence/AUDIT-001-remediation-verification.md` from `.agents/templates/docs/VERIFICATION.md` and record Phase 1 results.

### Verification

- [x] `flutter analyze` prints `No issues found!`.
- [x] `flutter test test/android_hardening_test.dart test/utility_screens_test.dart` passes.
- [x] `python .agents/skills/implementation-plan/scripts/check_claims.py docs/plans/AUDIT-001-remediation-implementation.md docs/evidence/AUDIT-001-remediation-verification.md HANDOFF.md` prints `0 problems`.
- [x] Probe or temporary test sources are saved under the evidence folder before they are deleted.
- [x] Note: physical-device validation of tile loading on a freshly built signed release APK stays pending for Len.

### Review and checkpoint

- [x] Review diff for minimal scope and confirm `scripts/` stays untracked per D-3.
- [x] Update plan, evidence, and `HANDOFF.md`; stage only reviewed tracked Phase 1 paths and verify `git diff --cached --stat`.
- [x] Commit with `fix(android): AUDIT-001 phase 1 - release manifest, gradle, and version` and verify Git exit code.

## Phase 2: Offline map tile store and map surface stability

Requirements: `REM-REQ-002` (`AUD-002`, `AUD-007`, `AUD-020`, `AUD-021`, `AUD-033`, `AUD-046`)
State: Approved - not started

Current code anchors:

    lib/features/map/map_tile_store.dart:76:       return _database = await sqflite.openDatabase(
    lib/features/map/map_tile_store.dart:81:             CREATE TABLE IF NOT EXISTS tiles (
    lib/features/map/map_tile_store.dart:172:   Future<void> put(MapTileRecord tile) async {
    lib/features/map/map_tile_store.dart:337:       unawaited(_revalidate(z: z, x: x, y: y, url: url, cached: cached));
    lib/features/map/map_tile_store.dart:368:     final httpClient = client ?? HttpClient();
    lib/features/map/map_tile_store.dart:376:       if (response.statusCode == HttpStatus.notModified && cached != null) {
    lib/main.dart:32:       mapTileStoreProvider.overrideWithValue(MapTileStore()),
    lib/features/map/warang_map.dart:186:                 unawaited(_tileStore.saveCamera(camera.center, camera.zoom));
    lib/features/map/warang_map.dart:197:                 tileProvider: CachedTileProvider(
    lib/features/map/warang_map.dart:526:   Future<void> _refreshLocation({required bool moveToUser}) async {

The tile database is opened without a `version` or `onUpgrade`, and its tables are created in `onOpen` with `CREATE TABLE IF NOT EXISTS` (`lib/features/map/map_tile_store.dart:76-110`).
Adding a column to that statement never reaches existing installs, so `lastAccessedAt` needs an explicit in-place upgrade.

### Tasks

- [ ] In `lib/features/map/map_tile_store.dart` (`AUD-002`): skip `_revalidate` in `CachedTileProvider.loadBytes` when `DateTime.now().difference(cached.fetchedAt) < mapTileMaxAge`; reuse one `_httpClient` with `connectionTimeout` (`10s`) and request timeout (`15s`); on HTTP `304`, update `fetchedAt` and `etag` in place without rewriting `bytes`; serialize `evictToLimit` with an in-memory `_evicting` guard inside one `sqflite` transaction, ordered by `lastAccessedAt` (preserving `docs/IMPLEMENTATION_PLAN.md` T17).
- [ ] Add `lastAccessedAt INTEGER` to the `tiles` table for new installs, and upgrade existing databases in `onOpen`: read `PRAGMA table_info(tiles)`, and when the column is missing run `ALTER TABLE tiles ADD COLUMN lastAccessedAt INTEGER` followed by `UPDATE tiles SET lastAccessedAt = fetchedAt`; add an index on `lastAccessedAt` (`AUD-002`).
- [ ] Write `lastAccessedAt` on a cache hit only when the stored value is more than one day old, so viewing fresh tiles does not add a database write per tile (`AUD-002`).
- [ ] Delete the redundant `mapTileStoreProvider.overrideWithValue(MapTileStore())` line at `lib/main.dart:32` (`AUD-007`).
- [ ] Replace unchecked `! as` casts on raw `sqflite` maps (`map_tile_store.dart:157-164`, `216-219`, `246-251`) and the five map `!` lookups (`repository.dart:225`, `clay.dart:61` and `63`, `trip_form_screen.dart:369`, `warang_map.dart:115`) with pattern matching and null-safe lookups (`AUD-020`).
- [ ] Narrow empty `catch (_) {}` blocks (`map_tile_store.dart:235`, `272`) and silent photo catches (`lib/app/shell/you_sheet.dart:459`, `lib/features/home_tab/trip_photo.dart:46`, `lib/features/travel_mode/travel_mode_screen.dart:1102`) to `on Exception` with debug-only `debugPrint` (`AUD-021`).
- [ ] In `lib/features/map/warang_map.dart` (`AUD-033`): debounce `saveCamera` via a 400 ms `_cameraDebounce` timer flushed in `dispose()`; cache `_cachedTileProvider` in state instead of allocating inside `build()`; move `_returning`/`_landed`/`_landing` mutations into `didUpdateWidget`; prune `_photos` entries for removed moment IDs.
- [ ] Extract one `checkLocationAccess` helper in `lib/app/device_providers.dart` that checks `isLocationServiceEnabled()` and permission status, and call it from both `locationReaderProvider` and `WarangMapSurface._refreshLocation` (`AUD-046`).
- [ ] Add regression tests in `test/map_tile_store_test.dart` covering fresh-hit zero-HTTP behavior, `304` metadata-only refresh, timeout/malformed-row resilience, upgrade of a tile database created with the old schema (no `lastAccessedAt` column), and serialized least-recently-used eviction.

### Verification

- [ ] `flutter analyze` prints `No issues found!`.
- [ ] `flutter test test/map_tile_store_test.dart test/map_pins_test.dart test/map_places_test.dart test/map_clusters_and_credit_test.dart test/map_navigation_test.dart` passes.
- [ ] `python .agents/skills/implementation-plan/scripts/check_claims.py docs/plans/AUDIT-001-remediation-implementation.md docs/evidence/AUDIT-001-remediation-verification.md HANDOFF.md` prints `0 problems`.
- [ ] Probe or temporary test sources are saved under the evidence folder before they are deleted.

### Review and checkpoint

- [ ] Verify no regression to offline tile rendering or pin clustering.
- [ ] Update plan, evidence, and `HANDOFF.md`; stage only Phase 2 paths and verify `git diff --cached --stat`.
- [ ] Commit with `fix(map): AUDIT-001 phase 2 - tile cache, surface state, and location helper` and verify Git exit code.

## Phase 3: Off-UI-isolate media, place book, and GPU image hygiene

Requirements: `REM-REQ-003` (`AUD-003`, `AUD-004`, `AUD-013`, `AUD-015`, `AUD-034`, `AUD-049`)
State: Approved - not started

Current code anchors:

    lib/data/places/place_book.dart:80:   factory PlaceBook.openFile(File file) {
    lib/data/places/place_book_installer.dart:68:     final byteData = await _bundle.load(spec.assetKey);
    lib/data/files/photo_store.dart:118:   Future<PhotoSweepResult> sweepOrphans(WarangDatabase database) async {
    lib/data/files/photo_store.dart:223:   img.Image _decode(Uint8List bytes) {
    lib/app/shell/you_sheet.dart:348:   final picked = await ImagePicker().pickImage(
    lib/features/capture/capture_screen.dart:211:           : Image.file(
    lib/features/travel_mode/travel_mode_screen.dart:1157:           if (file == null || !file.existsSync()) return placeholder;
    lib/app/theme/clay.dart:541:     final key = Object.hash(
    lib/app/theme/motion.dart:24:   Curve get curve => _SpringCurve(this, clamp: false);

### Tasks

- [ ] Open `PlaceBook.openFile` (`lib/data/places/place_book.dart:80`) with `NativeDatabase.createInBackground(file)`, and validate `meta.schema_version` on the installed database in `PlaceBookInstaller.ensureInstalled` (`lib/data/places/place_book_installer.dart:55-84`), reinstalling from the asset when it does not match (`AUD-003`).
- [ ] Keep the single `_bundle.load` call in `PlaceBookInstaller.ensureInstalled`: the SDK cannot stream an asset (see Framework citations), so do not add a chunked copy; record the 25.96 MB first-install peak in the evidence log as a known limitation that needs a device memory check by Len (`AUD-003`).
- [ ] Pass `maxWidth: 2000` and `maxHeight: 2000` to the avatar `pickImage` call (`lib/app/shell/you_sheet.dart:348`), inspect image header dimensions via `img.findDecoderForData(bytes)?.startDecode(bytes)` before full decode, and run decode, EXIF orientation bake, resize, and JPEG encode inside `Isolate.run` in `lib/data/files/photo_store.dart` (`AUD-004`).
- [ ] Add `cacheWidth` to `Image.file` in `lib/features/capture/capture_screen.dart:211` and `lib/features/travel_mode/travel_mode_screen.dart:1157`, and replace `file.existsSync()` in `_MomentPolaroid.build` with `Image.file(..., errorBuilder: ...)` (`AUD-013`).
- [ ] Replace `Object.hash(...)` keys in `ClayDiscCache._images` (`lib/app/theme/clay.dart:541`) with a value-equal Dart record tuple, and dispose evicted `ui.Image` handles safely in a post-frame callback (`AUD-015`).
- [ ] In `PhotoStore.sweepOrphans` (`lib/data/files/photo_store.dart:118-178`), use a `Set<String>` for referenced-path checks and batch missing-file soft-deletes in one `database.transaction`; move `sweepOrphans` at `lib/main.dart:28` into the post-frame callback after `runApp` (`AUD-034`).
- [ ] Precompute and cache `SpringSimulation` on `_SpringCurve` in `lib/app/theme/motion.dart:24-43` (`AUD-049`).
- [ ] Add tests in `test/photo_store_test.dart`, `test/place_book_test.dart`, and `test/clay_components_test.dart` for header-level >30 MP rejection, `schema_version` validation, and `ClayDiscCache` eviction disposal.

### Verification

- [ ] `flutter analyze` prints `No issues found!`.
- [ ] `flutter test test/photo_store_test.dart test/place_book_test.dart test/capture_flow_test.dart test/clay_components_test.dart test/reduced_motion_test.dart` passes.
- [ ] `python .agents/skills/implementation-plan/scripts/check_claims.py docs/plans/AUDIT-001-remediation-implementation.md docs/evidence/AUDIT-001-remediation-verification.md HANDOFF.md` prints `0 problems`.
- [ ] Probe or temporary test sources are saved under the evidence folder before they are deleted.

### Review and checkpoint

- [ ] Confirm `PlaceBook` tests still run cleanly on Windows without leaving background isolate handles open.
- [ ] Update plan, evidence, and `HANDOFF.md`; stage only Phase 3 paths and verify `git diff --cached --stat`.
- [ ] Commit with `perf(media): AUDIT-001 phase 3 - off-isolate media, place book, and image hygiene` and verify Git exit code.

## Phase 4: Save integrity, transactions, and UI state safety

Requirements: `REM-REQ-004` (`AUD-005`, `AUD-006`, `AUD-008`, `AUD-009`, `AUD-010`, `AUD-011`, `AUD-014`, `AUD-016`, `AUD-017`, `AUD-018`)
State: Approved - not started

Current code anchors:

    lib/features/capture/capture_screen.dart:231:       child: Scaffold(
    lib/features/home_tab/trip_form_screen.dart:98:     if (picked != null) setState(() => _dates = picked);
    lib/features/home_tab/trip_form_screen.dart:196:     return PopScope(
    lib/features/home_tab/trip_form_screen.dart:209:           leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
    lib/features/travel_mode/moment_edit_sheet.dart:107:       await widget.repository.updateMoment(
    lib/features/travel_mode/travel_mode_screen.dart:192:   Future<void> _confirmPlacement() async {
    lib/data/repository.dart:129:   Future<void> setAvatar(File source) async {
    lib/data/repository.dart:345:         : (jsonDecode(raw) as List<dynamic>).cast<String>();
    lib/features/maya/maya_companion.dart:257:     _drag.animateWith(WarangMotion.release.simulate(1, 0)).whenComplete(() {
    lib/features/places/place_picker_sheet.dart:136:       final nearby = await book.nearby(widget.near!, 150, limit: 8);
    lib/features/search/search_tab_screen.dart:139:     if (widget.query != _query ||
    lib/data/db/database.dart:65:       if (from < 2) {

### Tasks

- [ ] Wrap `CaptureScreen` (`capture_screen.dart:231`) in `PopScope(canPop: !_saving)`; in `TripFormScreen` (`trip_form_screen.dart:196-209`), set `canPop: !_saving && _step == 0`, skip `_step--` while `_saving`, and pass `onPressed: _saving ? null : () => Navigator.of(context).pop()` to `CloseButton` (`AUD-005`).
- [ ] Add transactional `WarangRepository.editMomentDetails(...)` and `WarangRepository.placeMoment(...)` wrapping multi-step writes in `database.transaction(() async { ... })`; call them from `MomentEditSheet._save` (`moment_edit_sheet.dart:107-136`) and `TravelModeScreen._confirmPlacement` (`travel_mode_screen.dart:192-203`, adding a `_saving` guard and error snackbar) (`AUD-006`).
- [ ] Guard `jsonDecode` in `WarangRepository._claimMilestones` (`repository.dart:345`) with `try/catch` resetting corrupt JSON to an empty set, and validate JSON shapes with pattern matching in `stamps.dart:33`, `maya_companion.dart:74`, and `news_tab_screen.dart:31` (`AUD-008`).
- [ ] Add `if (!mounted) return;` in `TripFormScreen._pickDates` (`trip_form_screen.dart:98`); in `MayaCompanion` (`maya_companion.dart:241-261`), stop `_drag` on drag start/update and replace `whenComplete` with `whenCompleteOrCancel` so `back` is always removed (`AUD-009`).
- [ ] Clear cached failed futures (`_lines = null` in `MayaLines.load`, `maya_companion.dart:70-79`; `_loading = null` in `StampTitles.load`, `lib/features/stamps/stamp_titles.dart:10-26`) on error (`AUD-010`).
- [ ] In `WarangRepository.setAvatar` (`repository.dart:129-139`), delete the new avatar file if `updateProfile` throws, delete the superseded avatar file after commit, and include `warang/profile/` in `PhotoStore.sweepOrphans` (`AUD-011`).
- [ ] Wrap `book.nearby` (`place_picker_sheet.dart:136`) and `book.search` (`:157`) in `try/catch/finally` to clear `_loading = false` and show an inline error state (`AUD-014`).
- [ ] Add a monotonic `revision` getter on `WarangRepository` incremented on every `notifyListeners()`, and trigger `_search()` in `MomentSearchResults.didUpdateWidget` (`search_tab_screen.dart:139`) whenever `query` or `revision` changes (`AUD-016`).
- [ ] Wrap `if (from < 2)` (`lib/data/db/database.dart:65-68`) in `await transaction(() async { ... })` and add an isolated v1-to-v2 test in `test/migration_test.dart` (`AUD-017`).
- [ ] Add `galleryPickerProvider` next to `cameraPickerProvider` in `lib/app/device_providers.dart`, inject it into `pickProfilePhoto` (`you_sheet.dart:347`), wrap `setAvatar` in `try/catch`, and show `showWarangSnackBar` on failure (`AUD-018`).
- [ ] Add permanent regression tests covering mid-save Back blocking, transactional moment edit rollback, corrupt `milestonesShown` recovery, repeated Maya drag listener cleanup, `MayaLines.load` retry after failure, superseded avatar cleanup, `PlacePickerSheet` error spinner clear, live search refresh after edit, and `pickProfilePhoto` error snackbar.

### Verification

- [ ] `flutter analyze` prints `No issues found!`.
- [ ] Full `flutter test` passes (all existing 329 tests plus new Phase 4 regression tests).
- [ ] `python .agents/skills/implementation-plan/scripts/check_claims.py docs/plans/AUDIT-001-remediation-implementation.md docs/evidence/AUDIT-001-remediation-verification.md HANDOFF.md` prints `0 problems`.
- [ ] Probe or temporary test sources are saved under the evidence folder before they are deleted.

### Review and checkpoint

- [ ] Review all touched save paths for clean rollback and mounted guards.
- [ ] Update plan, evidence, and `HANDOFF.md`; stage only Phase 4 paths and verify `git diff --cached --stat`.
- [ ] Commit with `fix(data): AUDIT-001 phase 4 - transactions, save guards, and state safety` and verify Git exit code.

## Phase 5: Dead code, YAGNI cleanup, and small code-hygiene fixes

Requirements: `REM-REQ-005` (`AUD-023`, `AUD-024`, `AUD-025`, `AUD-026`, `AUD-027`, `AUD-028`, `AUD-036`, `AUD-038`, `AUD-041`, `AUD-043`, `AUD-047`, `AUD-048`, `AUD-050`; `AUD-029` kept per D-1)
State: Approved - not started

Current code anchors:

    lib/data/repository.dart:555:   Future<void> upsertImportedTrip(
    lib/app/theme/clay_components.dart:1147: class WarangToggle extends StatelessWidget {
    test/clay_components_test.dart:289:       testWidgets('toggles show state with a check and semantics ($variant)', (
    lib/features/news_tab/news_tab_screen.dart:11: sealed class NewsListEntry {
    lib/features/news_tab/news_tab_screen.dart:41: final class NewsAdSlot extends NewsListEntry {
    lib/app/theme/tokens.dart:35:   static const lightDotInactive = Color(0xFFC3C7BC);
    lib/data/db/database.dart:36:   static const _categoryNameCaseSql = '''
    lib/data/db/database.dart:138:     beforeOpen: (details) async {
    lib/core/trip_rules.dart:38: bool coversDay(DateTime start, DateTime end, DateTime at) {

### Tasks

- [ ] Delete `WarangRepository.upsertImportedTrip` (`lib/data/repository.dart:555-629`) (`AUD-024`).
- [ ] Delete `NewsAdSlot` and `NewsListEntry` (`lib/features/news_tab/news_tab_screen.dart:11-43,131`), type the list as `List<NewsArticle>`, and update `test/news_tab_test.dart:34` (`AUD-028`).
- [ ] Delete unused `WarangColors.lightDotInactive` and `darkDotInactive`, the unnamed `WarangButton()` constructor, `WarangField.helperText`, `WarangSpeechBubble.tailAlignment`/`tailDown`, and `WarangSettingsRow.onTap` (`AUD-027`).
- [ ] Per D-1: delete `WarangToggle` (`lib/app/theme/clay_components.dart:1147-1249`) and its test (`test/clay_components_test.dart:289-326`, the whole `testWidgets` block) (`AUD-023`); keep `MayaPose.footTap` (`lib/features/maya/maya_companion.dart:20`) (`AUD-029`).
- [ ] Per D-1, amend `docs/features/FEAT-003-clay-keepsake-redesign.md` to revision 2: under `### C11. Toggle` (line 346) add a note that C11 was removed by AUDIT-001 D-1 on 2026-11-26 because nothing used it; change "Toggles use C11." (line 452) to say Settings rows have no toggles; update its `Updated:` and `Revision:` lines and its row in `docs/SPEC_INDEX.md` (`AUD-023`).
- [ ] Per D-2: remove `assets/Logo2.png` and `design/ui-update/baseline/` from Git, keeping `assets/Logo.png` and `design/warang-canvas.html` (`AUD-026`).
- [ ] Apply only readable mechanical fixes (`unnecessary_null_checks`, `unnecessary_lambdas`, `use_if_null_to_convert_nulls_to_bools`, and hand-picked redundant defaults outside `DateTime(...)` literals) without running a blanket `dart fix --apply` (`AUD-025`).
- [ ] Wrap intentional fire-and-forget futures with `unawaited(...)` (`AUD-036`) and narrow untyped `catch` blocks to `on Exception` (`AUD-038`).
- [ ] Generate `_categoryNameCaseSql` (`lib/data/db/database.dart:36-54`) from `PlaceCategories.all` (`lib/core/place_categories.dart:146`), changing it from `static const` to `static final`, and add a unit test asserting every category key and label is represented (`AUD-041`).
- [ ] Align `WarangColors.lightAccentText`/`darkAccentText` and `ColorScheme.error`/`onError` (`lib/app/theme/tokens.dart:33-34,266-267`) with `WarangKeepsake` tokens while keeping `test/contrast_test.dart` passing (`AUD-043`).
- [ ] Remove diagnostic `print` and `debugPrint` calls in `test/stamps_test.dart:230-231` and `test/place_book_test.dart:194` (`AUD-047`).
- [ ] Move `_createPlacesIndex()` and `_createSearchIndex()` out of `beforeOpen` (`lib/data/db/database.dart:138-142`) into `onCreate` and `onUpgrade` only (`AUD-048`).
- [ ] Normalize `coversDay` (`lib/core/trip_rules.dart:38-42`) with `.toLocal()` and `DateTime(y, m, d)` / `DateTime(y, m, d + 1)` matching `lib/core/stamps.dart:114` (`AUD-050`).

### Verification

- [ ] `flutter analyze` prints `No issues found!`.
- [ ] Full `flutter test` passes (including `test/contrast_test.dart`, `test/theme_tokens_test.dart`, `test/core_rules_test.dart`, `test/migration_test.dart`).
- [ ] `python .agents/skills/implementation-plan/scripts/check_claims.py docs/plans/AUDIT-001-remediation-implementation.md docs/evidence/AUDIT-001-remediation-verification.md docs/features/FEAT-003-clay-keepsake-redesign.md docs/SPEC_INDEX.md HANDOFF.md` prints `0 problems`.
- [ ] Probe or temporary test sources are saved under the evidence folder before they are deleted.

### Review and checkpoint

- [ ] Verify net line reduction and zero unintended UI change.
- [ ] Update plan, evidence, and `HANDOFF.md`; stage only Phase 5 paths (including the FEAT-003 amendment) and verify `git diff --cached --stat`.
- [ ] Commit with `refactor(cleanup): AUDIT-001 phase 5 - dead code, yagni, and hygiene` and verify Git exit code.

## Phase 6: Targeted Clean Code extractions, deterministic tests, and tooling hygiene

Requirements: `REM-REQ-006` (`AUD-022`, `AUD-030`, `AUD-031`, `AUD-032`, `AUD-037`, `AUD-039`, `AUD-040`)
State: Approved - not started

Current code anchors:

    lib/data/repository.dart:47:     _profileSubscription = database.profilesDao.watchActive().listen((row) {
    lib/data/places/place_book.dart:180:       rows = await _db
    lib/features/travel_mode/travel_mode_screen.dart:1157:           if (file == null || !file.existsSync()) return placeholder;
    tool/place_book/build_place_book.py:325:         except Exception:
    tool/place_book/build_place_book.py:423:         out_path.unlink()
    tool/place_book/build_place_book.py:427:         schema_sql = schema_sql.replace(",\n  prefix = '2 3'", "")

These anchors were taken before Phases 1 to 5; reread the current lines before editing.

### Tasks

- [ ] In `WarangRepository` (`lib/data/repository.dart`), add a monotonic `_refreshGeneration` guard in `_refreshMoments` and coalesce overlapping `_refreshAll()` triggers (keeping N+1 photo batching deferred per `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` Phase 5) (`AUD-032`).
- [ ] Apply minimal high-value Clean Code extractions without gratuitous file splitting (`AUD-030`, `AUD-031`): extract one `BookPlace` row-mapping helper in `lib/data/places/place_book.dart`, one FTS trigger SQL helper in `lib/data/db/database.dart`, one place-row builder helper in `lib/features/places/place_picker_sheet.dart`, and extract `_MomentPolaroid` into `lib/features/travel_mode/moment_polaroid.dart`.
- [ ] Replace hardcoded `Duration` literals outside `lib/app/theme/` with existing `WarangMotion` constants (skipping a speculative spacing token class under Ponytail) (`AUD-037`).
- [ ] Add `clockProvider` (`DateTime Function()`, defaulting to `DateTime.now`) in `lib/app/app_state.dart`, wire it into `CaptureScreen` and `HomeTabScreen`, and replace `DateTime.now()` test fixtures in `test/capture_flow_test.dart:138`, `test/trips_flow_test.dart:87`, and `test/user_journey_test.dart:168` with fixed dates (`AUD-039`).
- [ ] Replace real-time `Future.delayed` calls in `test/utility_screens_test.dart` (`82`, `115`, `215`, `250`, `353` before Phase 1 adds its About test) with deterministic `Completer` / `pumpAndSettle` synchronization (`AUD-040`).
- [ ] In `tool/place_book/build_place_book.py` (`AUD-022`): build into `.sqlite.tmp` and `os.replace` on success, narrow `except Exception` at line `325` to log/count malformed OSM areas, replace exact-whitespace `.replace` at line `427` with a regex, and document `.md5` verification in `tool/place_book/README.md`.

### Verification

- [ ] `flutter analyze` prints `No issues found!`.
- [ ] Full `flutter test` passes with zero flaky sleeps.
- [ ] `python -m py_compile tool/place_book/build_place_book.py` exits 0.
- [ ] `python .agents/skills/implementation-plan/scripts/check_claims.py docs/plans/AUDIT-001-remediation-implementation.md docs/evidence/AUDIT-001-remediation-verification.md docs/SPEC_INDEX.md HANDOFF.md` prints `0 problems`.
- [ ] Probe or temporary test sources are saved under the evidence folder before they are deleted.

### Review and checkpoint

- [ ] Update plan, evidence, `docs/SPEC_INDEX.md`, and `HANDOFF.md` (setting Next action to Independent verification).
- [ ] Stage only Phase 6 paths and verify `git diff --cached --stat`.
- [ ] Commit with `refactor(core): AUDIT-001 phase 6 - clean extractions, deterministic tests, and tooling` and verify Git exit code.

## Independent verification

Executed by: An agent or fresh session that did not implement Phases 1 to 6
State: Awaiting implementation

- [ ] Reread this plan, `docs/audits/AUDIT-001-code-quality-report.md`, `docs/evidence/AUDIT-001-remediation-verification.md`, and the changed code, and try to disprove each completion claim.
- [ ] Record each claim as Confirmed, Corrected, or Withdrawn with its proof in `docs/evidence/AUDIT-001-remediation-verification.md`.
- [ ] Correct documents only; send any needed product change back to Len as new work.
- [ ] Run `python .agents/skills/implementation-plan/scripts/check_claims.py` on every corrected document and require `0 problems`.
- [ ] Stage only the corrected documents and commit with `docs(plan): AUDIT-001 remediation - independent verification`.

The implementing agent stops before this phase and sets it as the next action in `HANDOFF.md`.
The plan is complete only when this phase is committed.

## Recovery

Follow project `AGENTS.md` for the three-attempt limit and immediate blockers.
Record unresolved work and attempt counts in `HANDOFF.md`.
Interrupted or failing work remains uncommitted and the phase remains incomplete.
Physical-device checks (signed release APK tile loading, 48 MP gallery avatar pick, cold place-book install and its memory peak, GPS rationale dialogs) remain pending and owned by Len.

## Revision history

- Revision 1 (2026-11-24T21:40:00+08:00): first draft, awaiting approval.
- Revision 2 (2026-11-26T23:32:00+08:00): Claude Code review corrections, approved by Len with D-1 to D-3 decided.
  Phase 2 adds the in-place `lastAccessedAt` upgrade for existing tile databases and throttles access-time writes.
  Phase 3 drops the chunked place book copy, which the SDK cannot do, and records the memory peak as a limitation.
  Phase 5 amends FEAT-003 C11 for the `WarangToggle` deletion and fixes the toggle test range to lines 289-326.
  Phase 1 adds an About version test, every phase saves probe sources, and the unsourced execution-mode quote is replaced by Len's recorded approval.
