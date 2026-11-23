# Verification: AUDIT-001

Created: 2026-11-24T07:13:00+08:00
Updated: 2026-11-24T07:24:00+08:00

| Requirement / phase | Check or scenario | Environment and conditions | Actual result | When run | Evidence / limitations |
| --- | --- | --- | --- | --- | --- |
| Phase 0 / baseline | `git log --oneline -1` and `git status --short` | Windows 11, inner repo `Warang` | Passed under stated conditions: HEAD is `7d6703f docs(plan): FEAT-004 phase 8 - polish and documents`; working tree has only Len/GPT's unstaged edit to `docs/SPEC_INDEX.md`, untracked `docs/plans/AUDIT-001-implementation.md`, and preserved untracked paths | 2026-11-24T07:11:20+08:00 | Baseline commit `7d6703f` confirmed |
| Phase 0 / baseline | `flutter --version` | Windows 11, Flutter SDK stable | Passed under stated conditions: `Flutter 3.44.7` (revision `84fc5cbb22`), `Dart 3.12.2`, `DevTools 2.57.0` | 2026-11-24T07:11:21+08:00 | Recorded in report header and inventory |
| Phase 0 / baseline | `flutter analyze` | Windows 11, `Warang` at `7d6703f` | Passed under stated conditions: `No issues found! (ran in 5.6s)` | 2026-11-24T07:11:28+08:00 | Zero analyzer issues at baseline |
| Phase 0 / baseline | `flutter test` | Windows 11, `Warang` at `7d6703f` | Passed under stated conditions: `00:39 +329: All tests passed!` (329 passed, 0 failed) | 2026-11-24T07:12:12+08:00 | OSM tile policy warnings printed to stdout during widget map tests |
| Phase 0 / inventory | `00-inventory.txt` generation | Windows 11, Python 3 stdlib + git + dart/flutter pub | Passed under stated conditions: 49 hand-written `lib/` files (15080 lines), 91 tracked non-`.g.dart` files across `lib/`, `test/`, `tool/` (24983 lines), 13 direct non-SDK dependencies, 5 direct non-SDK dev dependencies, 30 largest tracked files listed | 2026-11-24T07:13:00+08:00 | [00-inventory.txt](../audits/AUDIT-001/scans/00-inventory.txt); `sqlite3_flutter_libs` reported as `0.6.0+eol` by `flutter pub outdated` |
| Phase 0 / Gates 1-3 | Gate 1 (no product change), Gate 2 (no probe), Gate 3 (no em/en dash) | Windows 11, `Warang` | Passed under stated conditions: Gate 1 empty, Gate 2 absent, Gate 3 `0`; committed as `17dcddb` | 2026-11-24T07:13:34+08:00 | Clean checkpoint |
| Phase 1 / strict lints | Detached worktree at `17dcddb` with 20 extra lint rules: `flutter analyze --no-fatal-infos --no-fatal-warnings` and `dart fix --dry-run`, then worktree removal | Windows 11, Flutter 3.44.7 | Passed under stated conditions: 159 strict analyzer diagnostics (1 deprecation warning on `use_if_null_to_convert_nulls_to_bools`, 158 info hits), 74 proposed `dart fix` edits in 30 files; worktree removed and `git worktree list` shows 1 tree | 2026-11-24T07:14:34+08:00 | [01-strict-lints.txt](../audits/AUDIT-001/scans/01-strict-lints.txt), [02-dart-fix.txt](../audits/AUDIT-001/scans/02-dart-fix.txt) |
| Phase 1 / automated scans | Scans `03` to `21` via `public_symbols.py`, `complexity.py`, `duplicates.py`, `run_phase1_scans.py` | Windows 11, Python 3 stdlib + `git grep` | Passed under stated conditions: all 21 scan files (`01` to `21`) written under `docs/audits/AUDIT-001/scans/`, all 4 scripts copied to `docs/audits/AUDIT-001/scripts/`, 46 Phase 1 candidates (`C-001` to `C-046`) logged below | 2026-11-24T07:17:45+08:00 | Every scan file starts with its producing command |
| Phase 1 / Gates 1-4 | Gate 1, Gate 2, Gate 3, `git worktree list`, scan file headers | Windows 11, `Warang` | Passed under stated conditions: Gate 1 empty, Gate 2 absent, Gate 3 `0`, 1 worktree; committed as `9448f82` | 2026-11-24T07:20:11+08:00 | Clean checkpoint |
| Phase 2 / manual review | Full line-by-line review of all 49 hand-written `lib/` files (15080 lines), Android manifests/Gradle, tooling scripts, and key test suites (`migration_test.dart`, `android_hardening_test.dart`, `icon_semantics_test.dart`, `maya_test.dart`, `utility_screens_test.dart`), plus cross-check against `docs/SPEC_INDEX.md` and FEAT-001 to FEAT-004 | Windows 11, `Warang` at `9448f82` | Passed under stated conditions: all 49 `lib/` files read in full, all 6 area checklists answered below, 31 manual candidates (`C-047` to `C-077`) added (77 total candidates across Phases 1-2) | 2026-11-24T07:24:00+08:00 | Note: `lib/app/theme/warang_icons.dart` (187 lines) carries a generated header from `design/icons/build_icons.py` but was read in full |
| Phase 2 / Gates 1-4 | Gate 1, Gate 2, Gate 3, all area checklists answered, all 49 `lib/` files listed | Windows 11, `Warang` | Passed under stated conditions: Gate 1 empty, Gate 2 absent, Gate 3 `0` | 2026-11-24T07:24:30+08:00 | Verified before Phase 2 commit |

Use Not run, Passed under stated conditions, Failed, or Blocked.
Record actual commands or repeatable scenarios, not just conclusions.
Attach screenshots for meaningful UI checks when capture is available.
Keep emulator, physical-device, hardware-bench, and field validation distinct.
Len performs physical-device checks; keep them pending until Len supplies results.
Neither implementation nor a simulation establishes effectiveness in the intended environment.

## Phase 1 candidate log

Phase 1 total candidates: 46 (`C-001` to `C-046`).
Candidates are recorded without judgment here and verified in Phase 3.

| ID | Source scan | Location | Candidate summary |
| --- | --- | --- | --- |
| C-001 | `00-inventory.txt` | `pubspec.yaml:23` | `sqlite3_flutter_libs` is marked `0.6.0+eol` in `flutter pub outdated`. |
| C-002 | `00-inventory.txt` | `docs/evidence/FEAT-001/` | Tracked evidence PNGs (1000+ binaries, ~230 KB each) and `assets/place_book/place_book.sqlite` (25.3 MB) dominate repository weight. |
| C-003 | `01-strict-lints.txt` | `lib/app/theme/clay.dart:746` | Strict lint `unnecessary_null_checks` flags unnecessary `!`. |
| C-004 | `01-strict-lints.txt` | `lib/data/repository.dart:414`, `lib/features/home_tab/trip_detail_screen.dart:127` | Strict lint `use_if_null_to_convert_nulls_to_bools` flags `== true` on nullable booleans. |
| C-005 | `01-strict-lints.txt` | `lib/data/places/place_book_installer.dart:140`, `lib/features/map/warang_map.dart:123,145,153,414,723-733`, `lib/features/capture/capture_screen.dart:59,63,194,354`, `lib/app/shell/dock.dart:60,195,296`, `lib/app/theme/clay.dart:682-698`, `lib/app/theme/clay_components.dart:505,1175,1362`, `lib/app/theme/components.dart:234`, `lib/features/home_tab/trip_detail_screen.dart:36,86,95`, `lib/features/home_tab/trip_form_screen.dart:68,107`, `lib/features/maya/maya_companion.dart:158,185,223,234,257`, `lib/features/places/place_picker_sheet.dart:99,177`, `lib/features/search/search_tab_screen.dart:322` | Strict lint `discarded_futures` flags 29 unawaited future calls inside non-async functions in `lib/`. |
| C-006 | `01-strict-lints.txt` | `lib/app/device_providers.dart:65`, `lib/data/files/photo_store.dart:227`, `lib/data/places/place_book_installer.dart:97,158`, `lib/data/repository.dart:361`, `lib/features/capture/capture_screen.dart:150`, `lib/features/home_tab/trip_form_screen.dart:140`, `lib/features/home_tab/trip_photo.dart:46`, `lib/features/map/map_tile_store.dart:135,167,221,235,254,272,342,356`, `lib/features/map/warang_map.dart:571`, `lib/features/travel_mode/moment_edit_sheet.dart:138`, `lib/features/travel_mode/travel_mode_screen.dart:1102` | Strict lint `avoid_catches_without_on_clauses` flags 19 untyped catch blocks in `lib/` (plus 4 in `test/`). |
| C-007 | `01-strict-lints.txt` | `lib/app/shell/you_sheet.dart:458`, `lib/data/files/photo_store.dart:106,131,132,156,263`, `lib/data/places/place_book_installer.dart:55,62,74,78`, `lib/features/map/warang_map.dart:682`, `lib/features/travel_mode/travel_mode_screen.dart:585` | Strict lint `avoid_slow_async_io` flags 12 async `exists()` calls in `lib/` (plus 16 in `test/`). |
| C-008 | `01-strict-lints.txt`, `02-dart-fix.txt` | `lib/app/app.dart:22`, `lib/app/shell/you_sheet.dart:242,509`, `lib/app/theme/clay.dart:684,696`, `lib/app/theme/clay_components.dart:898,1217,1390,1501`, `lib/app/theme/components.dart:159,504`, `lib/features/capture/capture_screen.dart:115`, `lib/features/home_tab/trip_detail_screen.dart:339`, `lib/features/map/warang_map.dart:440,479,722`, `lib/features/maya/maya_companion.dart:390`, `lib/features/news_tab/news_tab_screen.dart:160`, `lib/features/places/place_picker_sheet.dart:136,157,469`, `lib/features/search/search_tab_screen.dart:279`, `lib/features/stamps/stamp_page_sheet.dart:90,150`, `lib/features/travel_mode/moment_edit_sheet.dart:69,71,208`, `lib/features/travel_mode/travel_mode_screen.dart:131,215,228,663,1016` | Strict lint `avoid_redundant_argument_values` flags 31 redundant default arguments in `lib/` (70 total including `test/` and `tool/`). |
| C-009 | `01-strict-lints.txt`, `02-dart-fix.txt` | `test/migration_test.dart:217` | Strict lint `unnecessary_lambdas` flags closure where tear-off suffices. |
| C-010 | `04-asset-use.txt` | `assets/Logo.png`, `assets/Logo2.png` | Two undeclared, unreferenced logo PNGs tracked in Git (1134 KB and 1089 KB). |
| C-011 | `04-asset-use.txt` | `design/warang-canvas.html`, `design/ui-update/baseline/home_dark.png` (14 PNGs) | Undeclared, unreferenced legacy design canvas HTML (796 KB) and 14 old UI-update baseline screenshots. |
| C-012 | `04-asset-use.txt` | `pubspec.yaml:44-46` | Three font OFL text files declared in `pubspec.yaml` `assets:` with zero code references. |
| C-013 | `04-asset-use.txt` | `design/icons/` | Tracked SVG sources, icon builder, and config files under `design/icons/` not declared in `pubspec.yaml`. |
| C-014 | `05-unused-symbols.txt` | `lib/data/repository.dart:555` | `WarangRepository.upsertImportedTrip` has zero references in `lib/`, `test/`, or `tool/` (75 lines). |
| C-015 | `05-unused-symbols.txt` | `lib/app/theme/tokens.dart:35-36` | `WarangColors.lightDotInactive` and `WarangColors.darkDotInactive` have zero references anywhere. |
| C-016 | `05-unused-symbols.txt` | `lib/app/theme/clay_components.dart:486` | `WarangStamp.resetSession` is referenced only in tests. |
| C-017 | `05-unused-symbols.txt` | `lib/app/theme/palette.dart:126` | `WarangKeepsake.tripTones` is referenced only in tests. |
| C-018 | `05-unused-symbols.txt` | `lib/core/place_categories.dart:163` | `PlaceCategories.stampCategories` is referenced only in tests. |
| C-019 | `05-unused-symbols.txt` | `lib/data/files/photo_store.dart:114` | `PhotoStore.storeBytesAsset` is referenced only in tests. |
| C-020 | `05-unused-symbols.txt` | `lib/data/places/place_book.dart:144` | `PlaceBook.readMeta` is referenced only in tests. |
| C-021 | `06-catch.txt` | `lib/features/map/map_tile_store.dart:235,272` | Empty `catch (_) {}` blocks silently ignore write failures in `saveCamera` and `saveLocation`. |
| C-022 | `06-catch.txt` | `lib/app/shell/you_sheet.dart:459`, `lib/features/home_tab/trip_photo.dart:46`, `lib/features/travel_mode/travel_mode_screen.dart:1102` | Broad catches swallow photo resolution errors and return null silently. |
| C-023 | `07-null-and-late.txt` | `lib/data/repository.dart:29,225` | `late Profile _profile` and `_placesById[placeId]!` rely on runtime initialization/cache invariants. |
| C-024 | `07-null-and-late.txt` | `lib/app/theme/clay.dart:61,63`, `lib/features/home_tab/trip_form_screen.dart:369`, `lib/features/map/warang_map.dart:115` | Non-null assertions `!` on map lookups. |
| C-025 | `08-dynamic-and-casts.txt` | `lib/data/repository.dart:345`, `lib/core/stamps.dart:33,36`, `lib/features/maya/maya_companion.dart:74,77`, `lib/features/news_tab/news_tab_screen.dart:31-35,63` | Unchecked `as` casts and `DateTime.parse` on decoded JSON from SQLite (`milestonesShown`) and bundled assets. |
| C-026 | `08-dynamic-and-casts.txt` | `lib/features/map/map_tile_store.dart:157-164,216-219,246-251` | Unchecked `! as` casts on raw `sqflite` map rows. |
| C-027 | `09-async-gaps.txt` | `lib/features/home_tab/trip_form_screen.dart:89-99` | `_pickDates()` calls `setState` after `await showDateRangePicker(...)` without checking `mounted`. |
| C-028 | `09-async-gaps.txt` | `lib/features/places/place_picker_sheet.dart:156` | `_runQuery()` calls `setState(() => _loading = true)` in an async method with earlier `await` branches. |
| C-029 | `10-lifecycle.txt` | `lib/app/theme/clay_components.dart:229-230` | Lazily created `_ownFocus` and other lifecycle resources in scan 10 require manual disposal verification. |
| C-030 | `11-sql-and-fts.txt` | `lib/data/db/database.dart:36-54,258,275,300,336` | `_categoryNameCaseSql` interpolates a hardcoded SQL `CASE` map that duplicates category display names from `lib/core/place_categories.dart`. |
| C-031 | `12-files.txt` | `lib/data/places/place_book_installer.dart:77-81` | `ensureInstalled` deletes `target` before renaming `tmp` to `target`. |
| C-032 | `13-network.txt` | `lib/features/map/map_tile_store.dart:368-412` | `CachedTileProvider` allocates a new `HttpClient()` per tile request with no timeout and revalidates cached tiles on every load. |
| C-033 | `14-debug-and-markers.txt` | `test/stamps_test.dart:230-231`, `test/place_book_test.dart:194` | `// ignore: avoid_print` with `print(...)` and `debugPrint(...)` in test suite. |
| C-034 | `15-hardcoded-style.txt` | `lib/app/shell/dock.dart:313,338`, `lib/app/shell/you_sheet.dart:41`, `lib/core/place_categories.dart:32-41`, `lib/features/capture/capture_screen.dart:43,157,223,226`, `lib/features/home_tab/home_tab_screen.dart:335`, `lib/features/map/warang_map.dart:183,705,829`, `lib/features/maya/maya_companion.dart:129,136,200`, `lib/features/onboarding/onboarding_screen.dart:52,55`, `lib/features/places/place_picker_sheet.dart:115`, `lib/features/search/search_tab_screen.dart:196`, `lib/features/settings/settings_screen.dart:168,246`, `lib/features/travel_mode/travel_mode_screen.dart:65,146,333,340` | Hardcoded `EdgeInsets`, `Duration`, and `Colors.transparent` literals outside `lib/app/theme/`. |
| C-035 | `16-time-and-random.txt` | `lib/features/capture/capture_screen.dart:45`, `lib/features/home_tab/home_tab_screen.dart:129,322`, `lib/features/map/map_tile_store.dart:51`, `lib/features/maya/maya_companion.dart:212`, `test/capture_flow_test.dart:138`, `test/trips_flow_test.dart:87`, `test/user_journey_test.dart:168` | Direct `DateTime.now()` and `math.Random()` calls couple production screens and tests to wall-clock time and unseeded randomness. |
| C-036 | `17-complexity.txt` | `lib/app/theme/clay_components.dart:1`, `lib/features/travel_mode/travel_mode_screen.dart:1`, `lib/features/map/warang_map.dart:1`, `lib/data/repository.dart:1`, `lib/app/theme/clay.dart:1`, `lib/features/places/place_picker_sheet.dart:1`, `lib/app/theme/components.dart:1`, `lib/app/shell/you_sheet.dart:1`, `lib/features/map/map_tile_store.dart:1`, `lib/features/capture/capture_screen.dart:1`, `lib/features/home_tab/home_tab_screen.dart:1`, `lib/features/maya/maya_companion.dart:1` | Twelve hand-written `lib/` files exceed 400 lines (up to 1516 lines). |
| C-037 | `17-complexity.txt` | `lib/features/travel_mode/travel_mode_screen.dart:276`, `lib/features/capture/capture_screen.dart:188`, `lib/app/shell/you_sheet.dart:110`, `lib/features/home_tab/trip_detail_screen.dart:134`, `lib/features/travel_mode/moment_edit_sheet.dart:150` (34 methods total) | Thirty-four functions or `build` methods exceed 60 lines (up to 264 lines). |
| C-038 | `18-duplicates.txt` | `lib/data/db/database.dart:252-283`, `lib/features/places/place_picker_sheet.dart:241-307`, `lib/features/travel_mode/travel_mode_screen.dart:206-226`, `lib/data/db/daos.dart:198-218`, `lib/data/places/place_book.dart:180-210`, `lib/features/home_tab/trip_detail_screen.dart:114-121` | Repeated logic blocks across `lib/` (160 merged window pairs >= 8 normalized lines). |
| C-039 | `19-android.txt` | `android/app/src/main/AndroidManifest.xml:1-50` | `android.permission.INTERNET` is absent from the main manifest and declared only in `debug/` and `profile/` manifests. |
| C-040 | `19-android.txt` | `android/app/build.gradle.kts:57-63` | Release build type leaves R8 code shrinking (`isMinifyEnabled`) and resource shrinking (`isShrinkResources`) unconfigured. |
| C-041 | `19-android.txt` | `android/app/build.gradle.kts:36,49-52` | Leftover Flutter template `TODO` comment and unchecked `as String` casts on `keystoreProperties` entries. |
| C-042 | `20-tooling.txt` | `tool/place_book/README.md:26` | Documented `curl` download for Geofabrik PBF extract has no checksum verification. |
| C-043 | `20-tooling.txt` | `tool/place_book/build_place_book.py:325,410-427` | Broad `except Exception: return`, non-atomic `out_path.unlink()`, hardcoded diagnostic prints, and fragile whitespace-sensitive string replacement on `schema.sql`. |
| C-044 | `20-tooling.txt` | `scripts/build-and-archive.sh:13-14,50-100`, `scripts/build-and-archive.ps1:63-64` | Bash release script does not fail on zero APKs, interpolates unescaped git branch into JSON heredoc, and uses fragile `grep | awk` on `pubspec.yaml`; neither script verifies release signing. |
| C-045 | `21-tests.txt` | `test/icon_semantics_test.dart:112-188`, `test/maya_test.dart:273-285,347-353`, `tool/ux_screenshots_test.dart:281-653` | Twelve `testWidgets` blocks contain no direct `expect()` call in the test body. |
| C-046 | `21-tests.txt` | `test/utility_screens_test.dart:82,115,215,250,353`, `test/maya_test.dart:270,344`, `test/reduced_motion_test.dart:187,204`, `test/shell_navigation_test.dart:236` | Tests use real-time `Future.delayed` sleeps and fixed multi-second `tester.pump(Duration(seconds: 11))` calls. |

## Phase 2 manual review

### Hand-written `lib/` files read in full (49 of 49, 15080 lines)

| File | Lines | Status |
| --- | --- | --- |
| `lib/app/app.dart` | 41 | Read in full |
| `lib/app/app_state.dart` | 102 | Read in full |
| `lib/app/device_providers.dart` | 70 | Read in full |
| `lib/app/shell/app_shell.dart` | 157 | Read in full |
| `lib/app/shell/dock.dart` | 362 | Read in full |
| `lib/app/shell/you_sheet.dart` | 528 | Read in full |
| `lib/app/theme/clay.dart` | 750 | Read in full |
| `lib/app/theme/clay_components.dart` | 1516 | Read in full |
| `lib/app/theme/components.dart` | 581 | Read in full |
| `lib/app/theme/motion.dart` | 82 | Read in full |
| `lib/app/theme/palette.dart` | 148 | Read in full |
| `lib/app/theme/tokens.dart` | 345 | Read in full |
| `lib/app/theme/typography.dart` | 110 | Read in full |
| `lib/app/theme/warang_icons.dart` | 187 | Read in full (generated by `design/icons/build_icons.py`) |
| `lib/core/formatting.dart` | 47 | Read in full |
| `lib/core/ids.dart` | 4 | Read in full |
| `lib/core/memory_stats.dart` | 52 | Read in full |
| `lib/core/milestones.dart` | 64 | Read in full |
| `lib/core/models.dart` | 135 | Read in full |
| `lib/core/place_categories.dart` | 174 | Read in full |
| `lib/core/stamps.dart` | 201 | Read in full |
| `lib/core/trip_rules.dart` | 60 | Read in full |
| `lib/data/db/daos.dart` | 360 | Read in full |
| `lib/data/db/database.dart` | 344 | Read in full |
| `lib/data/db/tables.dart` | 109 | Read in full |
| `lib/data/files/photo_store.dart` | 267 | Read in full |
| `lib/data/places/fts_query.dart` | 28 | Read in full |
| `lib/data/places/place_book.dart` | 294 | Read in full |
| `lib/data/places/place_book_installer.dart` | 163 | Read in full |
| `lib/data/repository.dart` | 791 | Read in full |
| `lib/features/capture/capture_screen.dart` | 465 | Read in full |
| `lib/features/home_tab/home_tab_screen.dart` | 462 | Read in full |
| `lib/features/home_tab/trip_detail_screen.dart` | 345 | Read in full |
| `lib/features/home_tab/trip_form_screen.dart` | 376 | Read in full |
| `lib/features/home_tab/trip_photo.dart` | 100 | Read in full |
| `lib/features/map/map_tile_store.dart` | 471 | Read in full |
| `lib/features/map/warang_map.dart` | 943 | Read in full |
| `lib/features/maya/maya_companion.dart` | 403 | Read in full |
| `lib/features/news_tab/news_tab_screen.dart` | 247 | Read in full |
| `lib/features/onboarding/onboarding_screen.dart` | 138 | Read in full |
| `lib/features/places/place_picker_sheet.dart` | 597 | Read in full |
| `lib/features/search/search_tab_screen.dart` | 348 | Read in full |
| `lib/features/settings/about_screen.dart` | 93 | Read in full |
| `lib/features/settings/settings_screen.dart` | 283 | Read in full |
| `lib/features/stamps/stamp_page_sheet.dart` | 182 | Read in full |
| `lib/features/stamps/stamp_titles.dart` | 34 | Read in full |
| `lib/features/travel_mode/moment_edit_sheet.dart` | 311 | Read in full |
| `lib/features/travel_mode/travel_mode_screen.dart` | 1169 | Read in full |
| `lib/main.dart` | 41 | Read in full |

### Area checklist answers

#### 1. Data layer (`lib/data/db/*`, `lib/data/repository.dart`, `lib/data/files/photo_store.dart`, `lib/data/places/*`)

- Write touching both database and filesystem without defined order or cleanup: Yes, `lib/data/repository.dart:129-139` (`setAvatar` writes the avatar file before `updateProfile`, leaves the new file orphaned if `updateProfile` fails, and never deletes superseded avatars because `sweepOrphans` scans only `warang/photos/`). `captureMoment` (`lib/data/repository.dart:90-118`) has explicit discard cleanup on DB failure (checked).
- Every multi-step write runs inside a Drift `transaction`: No; `lib/data/db/database.dart:65-68` (schema 1->2 migration), `lib/data/files/photo_store.dart:141-143` (`sweepOrphans` soft-delete loop), `lib/features/travel_mode/moment_edit_sheet.dart:107-136` (up to 3 sequential repository writes), `lib/features/travel_mode/travel_mode_screen.dart:198-201` (2 sequential repository writes), and `lib/data/repository.dart:342-390` (`_claimMilestones` read-modify-write) run outside a single transaction.
- Each schema migration step has a test in `test/migration_test.dart` starting from old schema with data: Partially; `test/migration_test.dart:222-306` tests schema 2->3 and schema 1->3 with data, but does not test schema 1->2 independently or rollback behavior on mid-migration failure (`lib/data/db/database.dart:65-68`).
- User-typed search string reaching FTS5 `MATCH` or `LIKE` without `lib/data/places/fts_query.dart`: checked (both `SearchDao.search` at `lib/data/db/daos.dart:337` and `PlaceBook.search` at `lib/data/places/place_book.dart:174` pass input through `buildFtsQuery`, and no `LIKE` queries exist).
- Place book installer checks asset size, version, or integrity, and handles halfway copy: Partially; `lib/data/places/place_book_installer.dart:55-84` checks hardcoded `expectedBytes` (`25964544`) and writes to `.tmp` before renaming, but deletes `target` before renaming `tmp` (`place_book_installer.dart:78-81`), performs no SQLite `meta` or `PRAGMA quick_check` integrity check, and loads the entire 25.96 MB asset into memory on the UI isolate.
- Errors from disk or SQLite caught and shown vs swallowed: Swallowed in `lib/data/places/place_book_installer.dart:97`, `lib/data/repository.dart:361`, `lib/features/home_tab/trip_photo.dart:46`, `lib/features/travel_mode/travel_mode_screen.dart:1102`, `lib/app/shell/you_sheet.dart:459`; uncaught in `lib/features/places/place_picker_sheet.dart:136,157`, `lib/features/travel_mode/travel_mode_screen.dart:198-201`, and `lib/app/shell/you_sheet.dart:352`.

#### 2. Map (`lib/features/map/warang_map.dart`, `lib/features/map/map_tile_store.dart`)

- Tile request sends a user agent meeting OSM tile usage policy: Suspect, needs Phase 3 V3 probe; `lib/features/map/warang_map.dart:196-203` passes `userAgentPackageName: 'ph.warang.app'` to `TileLayer`, while passing a custom `CachedTileProvider` with no explicit `headers`; `lib/features/map/map_tile_store.dart:371` copies only `this.headers`. Also, `lib/features/map/map_tile_store.dart:337` revalidates even fresh tiles on every view, violating OSM tile usage policy.
- Tile cache has size limit and eviction rule enforced: Yes, `lib/features/map/map_tile_store.dart:16,182-197` enforces `mapTileMaxBytes` (200 MB), but runs a full-table `SUM(length(bytes))` and per-row delete loop on every `put()` (`map_tile_store.dart:182`), evicts FIFO by `fetchedAt ASC` rather than true LRU, and is not wrapped in a transaction.
- `sqflite` tile database opened and closed once, safe under concurrent writes: Partially; `_opening` deduplicates opens (`map_tile_store.dart:68`), but `lib/main.dart:32` overrides `mapTileStoreProvider` with `overrideWithValue(MapTileStore())`, bypassing `ref.onDispose(store.close)` (`lib/app/app_state.dart:17`). Concurrent `put` + `evictToLimit` calls interleave without a transaction (`map_tile_store.dart:172-197`), and `warang_map.dart:186` fires `saveCamera` on every pan frame.
- Separate `sqflite` cache respected as approved decision (`docs/IMPLEMENTATION_PLAN.md` T17): checked.

#### 3. Capture and travel mode (`lib/features/capture/`, `lib/features/travel_mode/`, `lib/features/places/`)

- Denied or permanently denied location permissions handled on every path: Partially; both `lib/app/device_providers.dart:49-53` and `lib/features/map/warang_map.dart:529-557` return cleanly on denial without blocking, but `device_providers.dart:35-42` skips `isLocationServiceEnabled()` and shows no rationale dialog, unlike `warang_map.dart:528-553`.
- Large photo decoded at full size in memory, and decoded off UI isolate: Yes (problem); `lib/data/files/photo_store.dart:181,226-234` runs `img.decodeImage`, `bakeOrientation`, `copyResize`, and `encodeJpg` synchronously on the UI isolate and decodes the full bitmap before checking the 30 MP cap; `lib/features/capture/capture_screen.dart:211` and `lib/features/travel_mode/travel_mode_screen.dart:1158` render `Image.file` with no `cacheWidth`/`cacheHeight`.
- `mounted` or `context.mounted` checked after every `await` before `context`/`setState`: No; missing in `lib/features/home_tab/trip_form_screen.dart:98` (`_pickDates`), `lib/features/maya/maya_companion.dart:255` (`_onDragEnd` listener), and `lib/features/travel_mode/travel_mode_screen.dart:152` (Undo snackbar callback).
- User can leave screen during save and lose moment without a message: Yes; `lib/features/capture/capture_screen.dart:231` has no `PopScope(canPop: !_saving)`, and `lib/features/home_tab/trip_form_screen.dart:196-209` allows Back on step 0 and Close during `_saving`.

#### 4. Screens and shell (`lib/features/home_tab/`, `search/`, `news_tab/`, `stamps/`, `settings/`, `onboarding/`, `maya/`, `lib/app/`)

- Any provider, controller, stream, or timer created in `build` or never disposed: Yes; `lib/features/map/warang_map.dart:197-203` instantiates `CachedTileProvider` inside `build()`; `lib/features/travel_mode/travel_mode_screen.dart:330` runs `_revealPin(...)` side effect inside `build()`; `lib/features/map/warang_map.dart:631-636` mutates `_returning`/`_landed`/`_landing` inside `build()`; `lib/main.dart:32` leaks `MapTileStore` past `onDispose`. All `AnimationController`, `TextEditingController`, `FocusNode`, `StreamSubscription`, and `Timer` instances in scan 10 have corresponding `dispose`/`cancel` calls (checked).
- Widget over 300 lines mixing layout, state, and data access: Yes; `lib/features/travel_mode/travel_mode_screen.dart` (1169 lines), `lib/features/map/warang_map.dart` (943 lines), `lib/features/places/place_picker_sheet.dart` (597 lines), `lib/app/shell/you_sheet.dart` (528 lines), `lib/features/capture/capture_screen.dart` (465 lines), `lib/features/home_tab/home_tab_screen.dart` (462 lines), `lib/features/maya/maya_companion.dart` (403 lines), `lib/features/home_tab/trip_form_screen.dart` (376 lines), `lib/features/search/search_tab_screen.dart` (348 lines), `lib/features/home_tab/trip_detail_screen.dart` (345 lines), `lib/features/travel_mode/moment_edit_sheet.dart` (311 lines).
- `lib/app/app_state.dart` or `device_providers.dart` holds global state tests cannot reset: `app_state.dart` and `device_providers.dart` use Riverpod providers (resettable per `ProviderScope`, checked). However, global mutable static state exists in `lib/app/theme/clay_components.dart:383` (`_stampsShown`), `lib/features/maya/maya_companion.dart:70,125` (`MayaLines._lines`, `MayaCompanionState.clock`), `lib/features/stamps/stamp_titles.dart:10-11` (`_cached`, `_loading`), and `lib/app/theme/clay.dart:401,524` (`_ClayGeometry._cache`, `ClayDiscCache._images`).
- Same concept named two ways across files: Yes; `HomeTabScreen` (`lib/features/home_tab/home_tab_screen.dart`) renders the "Trips" tab, `TravelModeScreen` (`lib/features/travel_mode/travel_mode_screen.dart`) renders the "Map" tab, and `MemoryStats` (`lib/core/memory_stats.dart`) summarizes `Moment` records.

#### 5. Theme and components (`lib/app/theme/*`)

- Token, component, or variant with one caller or none: Yes; `WarangToggle` (`lib/app/theme/clay_components.dart:1147-1249`, 0 `lib/` callers), `WarangColors.lightDotInactive` / `darkDotInactive` (`lib/app/theme/tokens.dart:35-36`, 0 callers), `WarangButton()` default constructor (`clay_components.dart:25-32`), `WarangField.helperText` (`clay_components.dart:206`), `WarangSpeechBubble.tailAlignment`/`tailDown` (`clay_components.dart:1323-1324`), `WarangSettingsRow.onTap` (`components.dart:529`).
- `components.dart` and `clay_components.dart` implement the same widget twice: checked (no duplicate widget implementation; `components.dart` re-exports `clay_components.dart` and holds map/settings/icon widgets). However, `tokens.dart:33-34` duplicates and diverges from `palette.dart:67,69` for amber text colours.
- Screens bypass tokens with literal colors, sizes, or durations: Yes; `15-hardcoded-style.txt` lists 30 literal `Duration`, `EdgeInsets`, and `Colors.transparent` hits outside `lib/app/theme/`, plus `lib/app/theme/tokens.dart:266-267` uses raw `Color(0xFFB8493D)` and `Colors.white`.

#### 6. Android, tooling, and tests (`19-android.txt`, `20-tooling.txt`, `21-tests.txt`)

- Release build signed with debug key: checked (No; `android/app/build.gradle.kts:19-23` fails closed if `android/key.properties` is missing).
- `android:allowBackup` copies user photos/database to cloud backup: checked (No; `android/app/src/main/AndroidManifest.xml:8-9` sets `android:allowBackup="false"` and `@xml/data_extraction_rules`, per `REMEDIATION_IMPLEMENTATION_PLAN.md` Phase 1).
- Missing `INTERNET` permission in main manifest: Yes, `android/app/src/main/AndroidManifest.xml:1-50` omits `android.permission.INTERNET` (declared only in `debug/` and `profile/` manifests).
- Any test passes even when the feature it names is broken: Yes; `test/android_hardening_test.dart:5-58` greps raw source files instead of verifying the merged manifest or release build, missing the absent `INTERNET` permission and absent R8 shrinking. Also `test/utility_screens_test.dart` uses real-time `Future.delayed` sleeps (lines 82, 115, 215, 250, 353).

### Phase 2 manual candidates

Phase 2 added 31 manual candidates (`C-047` to `C-077`).
Combined Phase 1 + Phase 2 total candidates: **77** (`C-001` to `C-077`).

| ID | Source | Location | Candidate summary |
| --- | --- | --- | --- |
| C-047 | manual | `lib/data/files/photo_store.dart:54-67,180-246` | Image decoding, resizing, and JPEG encoding run synchronously on the UI isolate, and `img.decodeImage` allocates the full pixel buffer before checking the 30 MP limit. |
| C-048 | manual | `lib/data/repository.dart:129-139`, `lib/data/files/photo_store.dart:54-67` | `setAvatar` leaves orphan avatar files on DB failure and never removes superseded avatars. |
| C-049 | manual | `lib/data/db/database.dart:65-68` | Schema 1->2 upgrade (`addColumn` + `_colourExistingTrips`) runs outside a transaction and lacks rollback coverage in `test/migration_test.dart`. |
| C-050 | manual | `lib/data/db/database.dart:138-142,218-320` | `beforeOpen` re-executes 10 DDL statements (`_createPlacesIndex` and `_createSearchIndex`) on every launch. |
| C-051 | manual | `lib/data/places/place_book.dart:80-83` | `PlaceBook.openFile` opens the 25.96 MB SQLite database with `NativeDatabase(file)` on the UI isolate instead of `NativeDatabase.createInBackground(file)`. |
| C-052 | manual | `lib/data/places/place_book_installer.dart:55-84,147-162` | `ensureInstalled` buffers the entire 25.96 MB asset in RAM on the UI isolate, checks only byte length (no SQLite integrity/meta check), and `PlaceBookNotifier.ensureReady` does not guard against provider disposal during install. |
| C-053 | manual | `lib/data/repository.dart:47-67,120-271,399-553,665-748` | Every mutation calls `_refreshAll()` redundantly alongside reactive Drift streams, and `_refreshMoments` runs an N+1 photo query per moment with no out-of-order refresh guard. |
| C-054 | manual | `lib/data/files/photo_store.dart:118-178`, `lib/main.dart:28` | `sweepOrphans` blocks startup before `runApp()`, uses O(N^2) `List.contains` on `validRows`, and runs soft-delete updates per row outside a transaction. |
| C-055 | manual | `lib/features/map/warang_map.dart:186,197-203,631-636,677-684` | `WarangMapSurface` writes camera position to SQLite on every pan frame, allocates `CachedTileProvider` inside `build()`, mutates pin-animation sets inside `build()`, and never evicts `_photos` cache entries. |
| C-056 | manual | `lib/features/map/map_tile_store.dart:172-204,334-413`, `lib/features/map/warang_map.dart:196-203` | `MapTileStore.put` runs a full-table size sum and unserialized eviction loop on every tile write, evicts FIFO instead of LRU, revalidates fresh tiles on every view, and `CachedTileProvider` may omit `User-Agent` header when passed to `TileLayer`. |
| C-057 | manual | `lib/features/capture/capture_screen.dart:231`, `lib/features/home_tab/trip_form_screen.dart:196-209` | System Back / Close is not blocked while `_saving == true`, allowing users to dismiss mid-save and lose feedback or navigation. |
| C-058 | manual | `lib/features/capture/capture_screen.dart:211-218`, `lib/features/travel_mode/travel_mode_screen.dart:1157-1164`, `lib/features/home_tab/trip_photo.dart:45` | `CaptureScreen` and `_MomentPolaroid` decode full-resolution `Image.file` without `cacheWidth`/`cacheHeight`; `_MomentPolaroid.build` calls synchronous `file.existsSync()` on every build. |
| C-059 | manual | `lib/features/travel_mode/moment_edit_sheet.dart:107-136` | `MomentEditSheet._save` runs up to three separate repository writes outside a single transaction, risking partial edits on failure. |
| C-060 | manual | `lib/features/travel_mode/travel_mode_screen.dart:192-203` | `_confirmPlacement` runs two separate writes without a transaction, saving guard, or error handling. |
| C-061 | manual | `lib/features/places/place_picker_sheet.dart:118-163` | `_runQuery` awaits `book.nearby` and `book.search` without `try/catch`, leaving `_loading` stuck `true` on error. |
| C-062 | manual | `lib/app/shell/you_sheet.dart:347-353` | `pickProfilePhoto` directly instantiates `ImagePicker()`, has no `try/catch`, and gives no error feedback on corrupt/oversized images. |
| C-063 | manual | `lib/features/search/search_tab_screen.dart:139-142` | `MomentSearchResults.didUpdateWidget` only re-runs search when `query` or `moments.length` changes, leaving results stale after editing captions, places, categories, or trips. |
| C-064 | manual | `lib/main.dart:32`, `lib/app/app_state.dart:15-19` | `main.dart` overrides `mapTileStoreProvider` with `overrideWithValue(MapTileStore())`, bypassing `ref.onDispose(store.close)`. |
| C-065 | manual | `lib/app/theme/clay_components.dart:1147-1249` | `WarangToggle` (103 lines) has zero callers in `lib/`, re-introducing the dead widget FEAT-002 REQ-007 removed. |
| C-066 | manual | `lib/features/news_tab/news_tab_screen.dart:11-13,41-43,131` | `NewsAdSlot` and `NewsListEntry` sealed hierarchy are unused speculative ad-slot seams contradicting `REMEDIATION_IMPLEMENTATION_PLAN.md` non-goals. |
| C-067 | manual | `lib/app/theme/clay.dart:541-583` | `ClayDiscCache.image` uses `Object.hash(...)` as a `Map` key (collision hazard) and evicts `ui.Image` handles without calling `.dispose()`. |
| C-068 | manual | `lib/app/theme/clay_components.dart:383`, `lib/features/maya/maya_companion.dart:70,125`, `lib/features/stamps/stamp_titles.dart:10-26` | Mutable global static state leaks across tests, and `MayaLines.load` / `StampTitles.load` permanently cache failed `Future`s. |
| C-069 | manual | `lib/features/maya/maya_companion.dart:20,248-261` | `MayaPose.footTap` is unused in `lib/`; `_onDragEnd`'s `back()` listener calls `setState` without checking `mounted` and races with a subsequent drag. |
| C-070 | manual | `lib/app/theme/tokens.dart:33-34,266-267`, `lib/app/theme/palette.dart:67,69` | Amber text colour tokens diverge between `WarangColors` and `WarangKeepsake.amber`; `ColorScheme.error`/`onError` hardcodes colors outside `WarangKeepsake`. |
| C-071 | manual | `lib/app/theme/motion.dart:24-43` | `_SpringCurve.transformInternal` recreates `SpringDescription` and `SpringSimulation` on every animation frame, and `curve`/`settleCurve` allocate new `_SpringCurve` objects on every access. |
| C-072 | manual | `lib/features/settings/about_screen.dart:12`, `lib/features/settings/settings_screen.dart:103` | App version string `'1.0.0'` is hardcoded separately from `pubspec.yaml`. |
| C-073 | manual | `lib/core/trip_rules.dart:38-42` | `coversDay` uses `.add(Duration(days: 1))` without `.toLocal()` normalization or calendar-day construction, diverging from `lib/core/stamps.dart:114`. |
| C-074 | manual | `lib/features/home_tab/home_tab_screen.dart`, `lib/features/travel_mode/travel_mode_screen.dart`, `lib/core/memory_stats.dart` | Naming drift for core product concepts (`HomeTabScreen` = Trips tab, `TravelModeScreen` = Map tab, `MemoryStats` = Moment totals). |
| C-075 | manual | `lib/app/device_providers.dart:35-42`, `lib/features/map/warang_map.dart:526-557` | Location permission flow is duplicated with divergent behavior (`device_providers.dart` skips location-service check and explanation dialog). |
| C-076 | manual | `lib/app/theme/clay_components.dart:25-32,206,1323-1324`, `lib/app/theme/components.dart:230,246,529` | Unused public constructors/parameters (`WarangButton()`, `WarangField.helperText`, `WarangSpeechBubble.tailAlignment`/`tailDown`, `WarangSettingsRow.onTap`), and `WarangPositionMarker` bypasses `WarangMotion.reduced`. |
| C-077 | manual | `test/android_hardening_test.dart:5-58` | Android hardening tests grep raw source strings rather than checking merged manifest/release behavior, missing the absent `INTERNET` permission and R8 shrinking. |

### Cross-check against approved documents and FEAT-002

- `docs/IMPLEMENTATION_PLAN.md` T17: Separate `sqflite` map tile cache is an approved architecture decision; kept out of findings (only internal costs in `C-032`, `C-056`, `C-064` are reported).
- `docs/features/FEAT-002-ponytail-cleanup.md`: Removed `TravelbookService`, `WarangShareService`, `toJson`/`fromJson`, `archive`/`share_plus`/`cross_file`/`permission_handler`, old `WarangToggle`, duplicate `MapTileStore` table creation, `bytes` select in `evictToLimit`, duplicate `seedDefaults` writes, `Uuid` in `PhotoStore`, and `_to_delete/`. Note that `WarangRepository.upsertImportedTrip` (`C-014`) was missed by FEAT-002 when `TravelbookService` was deleted, and `WarangToggle` (`C-065`) was re-introduced by FEAT-003 C11 even though no screen renders a toggle.
- `docs/features/FEAT-003-clay-keepsake-redesign.md`: Bundled font OFL files in `pubspec.yaml` (`C-012`) are required by FEAT-003 V3/REQ-004 (candidate `C-012` conflicts with FEAT-003 REQ-004). `WarangToggle` (`C-065`) is specified in FEAT-003 C11 and `MayaPose.footTap` (`C-069`) in FEAT-003 M4 (conflicts noted). Layered Maya art (`D-2`) is intentionally pending.
- `docs/features/FEAT-004-places-search-stamps.md`: Separate `assets/place_book/place_book.sqlite` file (`C-002`) is approved under FEAT-004 C-1 and REQ-003 (25.3 MB is within the 40 MB installed budget). `design/icons/` SVG sources and `build_icons.py` (`C-013`) are required by FEAT-004 P-3 and FEAT-003 P-2.
- `docs/REMEDIATION_IMPLEMENTATION_PLAN.md`: Phase 5 explicitly specifies skipping revalidation for fresh tiles, reusing a bounded HTTP client with timeout, and only batching N+1 photo lookups if profiling justifies it (`C-032`, `C-053`, `C-056`). Non-goals explicitly forbid ad SDKs/advertising (`C-066`).
