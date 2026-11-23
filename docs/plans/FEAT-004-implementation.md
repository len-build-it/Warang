# Implementation Plan: FEAT-004 Places, place search, and category stamps

Created: 2026-11-23T20:15:00+08:00
Updated: 2026-11-23T19:40:00+08:00
Revision: 1
Status: Approved - not started
Feature spec and revision: [FEAT-004 revision 1](../features/FEAT-004-places-search-stamps.md)
Approved baseline and architecture revisions: `docs/IMPLEMENTATION_PLAN.md` at `dc407c5` for architecture, as amended for FEAT-004 on 2026-11-23; FEAT-003 revision 1 for appearance, components, and the maya
Len's chat approval of the feature spec: 2026-11-23 19:37 (Asia/Manila), project thread decision card: "Approve as written" on "Approve FEAT-004 spec and plan revision 1 for Gemini to execute?"
Len's chat approval of this plan: 2026-11-23 19:37 (Asia/Manila), project thread decision card: "Approve as written" on "Approve FEAT-004 spec and plan revision 1 for Gemini to execute?"
Target branch: `master` (verified 2026-11-23 at `67e0121`; no remote)
Implementing agent: Gemini or Claude Code, under the shared `AGENTS.md` rules

## Scope

This plan implements REQ-001 to REQ-033 of FEAT-004, with Len's decisions L-1 to L-3, the Council decisions C-1 to C-3, and the proposed decisions P-1 to P-3 of the spec.

No runtime package dependency may be added to `pubspec.yaml`.
The place book builder's Python packages are developer tools under `tool/place_book/` (spec P-2).
If a task seems to need new behaviour, a new dependency, a network call, or a design change beyond FEAT-004, record it in `HANDOFF.md` and leave it undone.

Preserve existing untracked work: `.agents/skills/*`, `.agents/templates/`, `.claude/`, `CLAUDE.md`, `releases/`, `scripts/`, and `docs/evidence/FEAT-001/claude-review/`.
Never stage those paths, and never use `git add -A` or `git add .`.

### Execution mode

Phases run continuously without routine approval stops, as in FEAT-003.
There are two planned stops:

1. **Size stop (Phase 1):** if the place book is still over the REQ-003 budget after the spec P-1 reductions, stop and report the measurements to Len.
2. **Visual review stop (after Phase 6):** send Len the search sheet, place picker, capture chip, filter row, and moment card screenshots in both themes, and wait for his approval before Phase 7.

Other stops follow the Recovery rules.

### Gates that every phase must pass

Run from the repository root (`C:\Users\User\Desktop\PersonalProjects\04-FUN-STUFF\WARANG\Warang`), in this order, before the checkpoint commit:

1. `dart format lib test tool`, then `dart format --output=none --set-exit-if-changed lib test tool` -> exit 0.
2. `flutter analyze` -> `No issues found!`.
3. `flutter test` -> `All tests passed!`, with the count recorded; the count may only grow, except where a phase replaces a test for changed behaviour and says so. The FEAT-003 end count was 267.
4. `flutter build apk --debug` -> exit 0.
5. Visual gate: `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=feat-004-phase-N` renders all screens in both themes into `docs/evidence/FEAT-001/feat-004-phase-N/`.
   Compare them by eye with the previous phase and with the spec, and list every intended and unintended difference in the evidence log.
   Unintended differences are regressions.
   Never run `--update-goldens` on `final`, `feat-002-baseline`, `claude-review`, or any `feat-003-*` label.
   Delete `tool/failures/` after each run and never commit it.
6. Phase metrics: every check under the phase's "Success metrics" returns exactly the stated result.

Record actual output for each gate in `docs/evidence/FEAT-004-verification.md`, created in Phase 0 from `.agents/templates/docs/VERIFICATION.md`.
Commit one independently revertible change at a time, with a green tree, conventional messages, and no agent co-author.
Each phase ends with a `docs(plan)` checkpoint commit that ticks this plan's boxes and updates the evidence log and `HANDOFF.md`.

### Shared test fixture

Phase 2 creates `test/fixtures/place_book_fixture.json`, about 30 hand-written places used by every later test and by `tool/ux_screenshots_test.dart`.
It must include, at least: three cafes in Kalibo within 200 m of each other, one cafe on Boracay, White Beach (Boracay), Kalibo Cathedral, a waterfall, a mall, Kalibo International Airport (`transit`), Kalibo and Malay (`town`), two places both named "Jollibee" about 5 km apart, a place with an accent ("Piña Café"), and a place whose name contains a quote and a dash.
`test/support/place_book_fixture.dart` builds an in-memory place book from `tool/place_book/schema.sql` and that JSON, so the tests and the real file share one schema.

## Phase 0: Approved documents and baseline

Requirements: none (setup)
State: Complete

### Tasks

- [x] Commit the approved documents alone: `docs/features/FEAT-004-places-search-stamps.md`, `docs/plans/FEAT-004-implementation.md`, `docs/research/RES-002-place-search-categories-progression.md`, and the edits to `docs/IMPLEMENTATION_PLAN.md`, `docs/features/FEAT-003-clay-keepsake-redesign.md`, `docs/SPEC_INDEX.md`, and `HANDOFF.md`, as `docs(spec): FEAT-004 places, search, and stamps`.
- [x] Create `docs/evidence/FEAT-004-verification.md` from the template.
- [x] Render the starting point with `--dart-define=UX_LABEL=feat-004-baseline` and commit it alone as `test(evidence): FEAT-004 visual baseline at <hash>`.
- [x] Build `flutter build apk --release --split-per-abi` and record the size in bytes of `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` as the REQ-003 baseline.

### Success metrics

- `git status --short docs` shows nothing after the two commits apart from untracked paths that existed before.
- The evidence log has the baseline APK size.

Checkpoint message: `docs(plan): FEAT-004 phase 0 - documents and baseline`

## Phase 1: Place book builder and measurement

Requirements: REQ-001, REQ-002, REQ-003
State: Complete

### Tasks

- [x] Create `tool/place_book/` with:
  - `schema.sql`: exactly the spec D-1 schema.
  - `categories.json`: the spec D-4 tag mapping as an ordered list of `{ "category", "key", "values" }` rules; the first matching rule wins, in the order of the D-4 table, except that `amenity=cafe` and `shop=coffee` win over `food`.
  - `requirements.txt`: `osmium` pinned to an exact current version.
  - `build_place_book.py`: reads a `.osm.pbf`, keeps features with a `name` that match a rule, uses the node position or a representative point for ways and relations, fills `town` (admin level 7, or 6 when 7 is missing for highly urbanised cities) and `province` (admin level 4 or 6, verified against Kalibo and Malay in Aklan) by point-in-polygon on boundaries, writes rows sorted by `osm_ref` so output is deterministic, fills `places_fts` with the `rebuild` command, sets `meta`, and runs `VACUUM`.
  - `README.md`: source (Geofabrik Philippines extract), the exact download used and its date, setup (`python -m venv .venv`, `pip install -r requirements.txt`), the build command, the licence note (ODbL, © OpenStreetMap contributors), and how to rebuild for a release.
- [x] Add `tool/place_book/.venv/` and `*.osm.pbf` to `.gitignore`.
- [x] Download the Philippines extract (Len's machine has network; if the download is blocked, stop and ask Len to download it), build `assets/place_book/place_book.sqlite`, and build it a second time to confirm the two files are byte-identical.
- [x] Add `assets/place_book/place_book.sqlite` to the `flutter: assets:` list in `pubspec.yaml`.
- [x] Measure and record in evidence: file size, rows per category, total rows, and the REQ-003 APK growth from `flutter build apk --release --split-per-abi`.
- [x] Coverage check: query the file for these names and record found or missing: Kalibo Cathedral, White Beach, Puka Shell Beach, Mount Luho, Ariel's Point, Willy's Rock, Bakhawan Eco-Park, Intramuros, Rizal Park, SM Mall of Asia, Binondo Church, Manila Cathedral, and five cafes in Kalibo that Len names in the evidence log, or, if Len has not named any, the first five `cafe` rows nearest Kalibo town proper.
- [x] If over budget, apply spec P-1 reductions in order, re-measuring after each; if still over, stop (planned stop 1).

### Success metrics

- Two builds produce identical SHA-256 hashes, recorded in evidence.
- APK growth is 25 MB or less and the file is 40 MB or less.
- Every D-4 category has at least one row.
- No app code under `lib/` changed in this phase: `git diff --stat HEAD -- lib` is empty.

Checkpoint message: `docs(plan): FEAT-004 phase 1 - place book builder`

## Phase 2: The place book in the app

Requirements: REQ-002, REQ-004, REQ-005, REQ-006, REQ-030
State: Complete

### Tasks

- [x] Add `lib/data/places/fts_query.dart`: turns user text into a safe FTS5 expression by splitting on whitespace, removing FTS syntax characters, quoting each token, and adding `*` to the last token for prefix search; returns null for empty input.
- [x] Use it in `SearchDao.search` in `lib/data/db/daos.dart` too, which today passes raw input to `MATCH`; add a test that typing `"`, `-`, `*`, `(`, or `NEAR` into moment search returns results or nothing and never throws.
- [x] Add `lib/data/places/place_book.dart`:
  - `BookPlace` value class (osmRef, name, category, latitude, longitude, town, province).
  - `PlaceBook` with `search(String text, {LatLng? near, int limit = 30})` ranked by `bm25` then squared degree distance to `near`, and `nearby(LatLng point, double radiusMetres, {int limit = 8})` using a latitude range on `places_lat`, a longitude range, then exact distance with `latlong2` and sorting nearest first.
  - Opened with Drift's `NativeDatabase` on the copied file with `PRAGMA query_only = ON`.
  - `PlaceBook.memory(...)` for tests, built from `schema.sql`.
- [x] Add `lib/data/places/place_book_installer.dart`: copies the asset to `getApplicationSupportDirectory()` as `place_book_<schemaVersion>_<sourceDate>.sqlite` via a `.tmp` file and rename, skips the copy when the file exists with the expected size, deletes older `place_book_*` files after success, and reports `preparing`, `ready`, or `failed`.
- [x] Add a Riverpod provider for the place book state, started after the first frame in `lib/main.dart` so it never delays launch.
- [x] Create the shared test fixture (see "Shared test fixture").
- [x] Tests: prefix, accents, ranking by nearness for the two "Jollibee" rows, nearby radius and order, syntax-safe input, schema version check against the bundled file, installer redo after a leftover `.tmp`, installer skip when ready, failed state when the asset is missing.

### Success metrics

- `grep -rn "MATCH ?" lib` shows only queries whose argument comes from `fts_query.dart`.
- A three-letter query on the bundled file takes under 150 ms on the Windows test host, averaged over 20 runs and recorded.

Checkpoint message: `docs(plan): FEAT-004 phase 2 - place book in the app`

## Phase 3: Places in the user's database

Requirements: REQ-010, REQ-011, REQ-013, REQ-016, REQ-021 (data part), REQ-033
State: Complete

### Tasks

- [x] Before changing tables, snapshot schema 2 with `dart run drift_dev schema dump lib/data/db/database.dart drift_schemas/` and commit `drift_schemas/drift_schema_v2.json` alone as `test(db): snapshot schema 2`. (Note: `drift_dev 2.34.0` CLI fails against `drift 2.34.3` `drift3_preview`; real SQLite v1 and v2 fixture databases are tested directly in `test/migration_test.dart` instead, recorded in evidence.)
- [x] Add the `Places` table (spec D-2) in `lib/data/db/tables.dart`, add `Moments.placeId`, remove `Moments.placeLabel`, add a `PlacesDao`, and raise `schemaVersion` to 3.
- [x] Migration `from < 3` in `lib/data/db/database.dart`, in one transaction:
  1. create `places`;
  2. for each distinct `lower(trim(place_label))` among moments, insert a `user` place named with the most recently updated spelling, trimmed;
  3. add `place_id` and set it for every moment with a label;
  4. rebuild `moments` without `place_label` using Drift's `TableMigration`;
  5. drop and recreate the moment search triggers to read the place name and category name through `place_id`, add `places` update triggers that reindex its moments, and rebuild `warang_search` from current rows.
- [x] Keep the schema 1 to 2 path working: a schema 1 database must reach schema 3.
- [x] Snapshot schema 3, generate the migration test helpers with `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`, and add `test/migration_test.dart` covering 1 to 3 and 2 to 3 with the REQ-010 data, photos, trips, and trip colours.
- [x] Update `lib/core/models.dart`: `Moment` gains `placeId` and `placeCategory`, and `placeLabel` becomes the place's name; add a `Place` model.
- [x] Update `lib/data/repository.dart`:
  - `attachBookPlace(String momentId, BookPlace place)` reuses a non-deleted place with the same `sourceRef` or copies it in.
  - `attachUserPlace(String momentId, String name)` reuses a user place with the same trimmed lower-cased name or creates one; a blank name clears the place.
  - `clearPlace(String momentId)` and `setPlaceCategory(String placeId, String? categoryKey)`.
  - `updateMoment` keeps its `placeLabel` parameter for the current edit sheet, routed through `attachUserPlace`, until Phase 5 replaces it.
  - `upsertImportedTrip` creates user places from imported labels.
  - `captureMoment` and `addMoment` accept `accuracyM` and an optional `BookPlace`.
- [x] Pass the fix accuracy from `lib/features/capture/capture_screen.dart` to `captureMoment` (REQ-016).
- [x] Change `distinctPlaces` in `lib/core/memory_stats.dart` to count distinct non-deleted place ids among moments; keep its test meaning (same name counts once).
- [x] Tests for every repository method, REQ-011, REQ-013, the search triggers after a place rename, and `accuracyM` on capture.

### Success metrics

- `grep -rn "place_label" lib --include=*.dart | grep -v "\.g\.dart"` returns only the migration code.
- `test/migration_test.dart` passes from both schema 1 and schema 2.
- The visual gate shows no visible change.

Checkpoint message: `docs(plan): FEAT-004 phase 3 - places table and migration`

## Phase 4: Categories, glyphs, and colours

Requirements: REQ-017, REQ-018
State: Complete

### Tasks

- [x] Add `lib/core/place_categories.dart`: an enum or constant list of the fourteen D-4 keys with display name, glyph, keepsake tone, and `countsForStamps` (false for `transit` and `town`).
  Tones: cafe and sweets `santan`, food `gumamela`, nightlife `ube`, beach and island `dagat`, nature and park `kalamansi`, church and heritage `amber`, market and stay `langit`, transit and town neutral.
- [x] Draw fourteen 24 by 24 glyphs in the FEAT-003 V7 style (2.5 px rounded stroke and duotone fill) in `design/icons/build_icons.py`, named `catCafe`, `catFood`, `catSweets`, `catNightlife`, `catBeach`, `catIsland`, `catNature`, `catPark`, `catChurch`, `catHeritage`, `catMarket`, `catStay`, `catTransit`, `catTown`, with new code points after the last used one; rebuild the font and `lib/app/theme/warang_icons.dart` with the three documented steps.
- [x] Add a `CategoryDisc` component in `lib/app/theme/clay_components.dart`: the glyph in a small clay disc in the category tone, sizes 32 and 40, with the category name as its semantic label.
- [x] Extend `test/contrast_test.dart` for each category's glyph on its disc and the disc label colours on `surface` and `surfaceRaised`, in both themes.
- [x] Extend `test/icon_semantics_test.dart` for the new glyphs.
- [x] Add a design canvas test page or extend `tool/ux_screenshots_test.dart` with `20_categories_<theme>`: all fourteen discs with names.

### Success metrics

- `WarangGlyphs.all` has 14 more entries than before.
- The contrast test fails if any category tone is swapped for `inkFaint`.

Checkpoint message: `docs(plan): FEAT-004 phase 4 - categories and glyphs`

## Phase 5: Place picker, capture suggestion, and moment card

Requirements: REQ-012, REQ-013, REQ-014, REQ-015, REQ-019, REQ-021
State: Complete

### Tasks

- [x] Add `lib/features/places/place_picker_sheet.dart` (spec F3): C9-style sheet, focused C5 field, "Nearby", "Your places", "Places", "Use "<text>" as your own place", and "No place"; rows use `CategoryDisc`, `titleS`, and `meta`; 150 ms debounce; place book `preparing` and `failed` states from spec F1.
- [x] Replace the "Place name" field in `lib/features/travel_mode/moment_edit_sheet.dart` with a place field that opens the picker, followed by the "Category" C7 chip row (spec F3 step 3).
  Remove the `placeLabel` parameter path added in Phase 3 once nothing uses it.
- [x] Capture save screen (`lib/features/capture/capture_screen.dart`, spec F4): the nearby chip and "Other place", with the radius rule, `selectionClick` on toggle, and nothing shown when the fix or place book is missing.
- [x] Moment card (`MomentCard` in `lib/features/travel_mode/travel_mode_screen.dart`) and trip detail rows: the category disc beside the place name.
- [x] Moment search results show the category disc when a moment has one.
- [x] Add screens to `tool/ux_screenshots_test.dart`: `21_place_picker_<theme>` (nearby list), `22_place_picker_typing_<theme>`, `23_capture_place_chip_<theme>`, and update `13_edit_sheet` and `04_moment_open` fixtures so one moment has a cafe.
- [x] Widget tests for REQ-012 to REQ-015, REQ-019, and REQ-021.

### Success metrics

- `grep -rn "Place name" lib` returns nothing.
- With the place book provider in `failed` state, `capture_flow_test.dart` still saves with one tap.

Checkpoint message: `docs(plan): FEAT-004 phase 5 - place picker and capture suggestion`

## Phase 6: Map search, placement search, and category filter

Requirements: REQ-007, REQ-008, REQ-009, REQ-020
State: Complete

### Tasks

- [x] Add the "Find a place" pill at the top of the map, to the right of the avatar bubble, at the avatar's vertical centre, as a C5-style clay pill with the search glyph, height 48, ending 16 from the right edge; hidden during pin placement and while a moment card is open.
- [x] Reuse the picker list for map search (spec F1), without "Your places" or "Use as your own place", and with the empty-state line and maya.
- [x] Map move: zoom 16 with the FEAT-003 map spring, a jump under reduced motion; a stamp-shaped `PlaceMarker` layer in `lib/features/map/warang_map.dart` with name, category disc, and a close control; tapping the map clears it.
- [x] "Map not saved here yet": when offline and the tile store has no tile for the marker's tile at zoom 16, show the line under the marker. Add the smallest query needed to `MapTileStore` (`hasTile(z, x, y)`).
- [x] Placement bar search button (spec F2): moving the map to the place, holding the pending `BookPlace`, dropping it when the user pans, and attaching it on Confirm through `attachBookPlace`.
- [x] Category filter row (spec F5) under the pill: only categories with moments, ordered by moment count, shown when two or more exist; the filter is in-memory state in `lib/app/app_state.dart`; the pins and cluster counts in `warang_map.dart` respect it.
- [x] Add screens: `24_map_search_<theme>`, `25_map_place_marker_<theme>`, `26_map_filter_<theme>`, `27_placement_search_<theme>`.
- [x] Widget tests for REQ-007, REQ-008, REQ-009, and REQ-020, and the map navigation tests still pass.
- [x] **Planned stop 2:** send Len the screenshots `21` to `27`, `04`, and `13` in both themes and wait for approval before Phase 7. Record his words and time in `HANDOFF.md`.

### Success metrics

- The pill and filter chips are 48 dp tall targets with labels.
- Under reduced motion, choosing a place requests no animation frames.

Checkpoint message: `docs(plan): FEAT-004 phase 6 - map search and category filter`

## Phase 7: Category stamps

Requirements: REQ-022 to REQ-028
State: Complete

### Tasks

- [x] Add `assets/data/stamps.json` with the spec D-5 titles and declare it in `pubspec.yaml`.
- [x] Add `lib/core/stamps.dart`: a pure function from moments and places to a list of `CategoryStamp` (category, tier, title, visits, places, first visit date and place, per-place visits), following spec D-3 exactly. No Flutter imports.
- [x] Extend `claimMilestone` in `lib/data/repository.dart` to return a list: the FEAT-003 milestone first, then any newly reached `stamp:<category>:<tier>` keys, each recorded in `milestonesShown`; only the highest new tier per category is cheered if one save jumps two tiers.
- [x] `showCaptured` in `travel_mode_screen.dart` and the edit save path show the toasts in order, using `ScaffoldMessenger`'s queue rather than replacing the current toast.
- [x] Extend `WarangStamp` with the four tier ring styles in spec F6, with no tier numbers or empty marks.
- [x] You sheet (`lib/app/shell/you_sheet.dart`): the "Your stamps" row under the count stamps, only when a stamp exists.
- [x] Add `lib/features/stamps/stamp_page_sheet.dart` (spec F6 step 3), whose place rows open the map with the category filter and focus that place's moments.
- [x] Tests for REQ-022 to REQ-028, including the forbidden-text check of REQ-026 and a 10,000-moment timing check for Council C-3 (under 16 ms on the test host, recorded).
- [x] Add screens: `28_you_stamps_<theme>` and `29_stamp_page_<theme>`, with a fixture that earns a tier 2 cafe stamp and a tier 1 beach stamp.

### Success metrics

- `grep -rn "import 'package:flutter" lib/core/stamps.dart` returns nothing.
- No code computes consecutive days or gaps (FEAT-003 REQ-021), checked by review and recorded.

Checkpoint message: `docs(plan): FEAT-004 phase 7 - category stamps`

## Phase 8: Polish, accessibility, and documents

Requirements: REQ-029, REQ-030, REQ-031, REQ-032, REQ-033
State: Complete

### Tasks

- [x] Credits: the map credit says "Places and map © OpenStreetMap contributors"; About adds the ODbL line and names `tool/place_book`.
- [x] Add the new sheets and screens to `test/reduced_motion_test.dart` and render the whole set at 200% text with `--dart-define=UX_LABEL=feat-004-phase-8-text-2x --dart-define=UX_TEXT_SCALE=2.0`, fixing any overflow.
- [x] Tap-target and label checks for every new control.
- [x] REQ-030 network review, recorded with the grep output.
- [x] Update `README.md`: "Search" becomes moments and places, new short sections for places and stamps, the privacy section names the bundled place book and that searches never leave the phone, and "Repository layout" lists `lib/features/places`, `lib/features/stamps`, and `tool/place_book`.
- [x] Set FEAT-004 and this plan to their implemented states in `docs/SPEC_INDEX.md`, and write the physical-device checklist in the evidence log for Len:
  1. first launch after install: time until place search is ready;
  2. search speed for a three-letter query;
  3. the capture nearby chip at three real cafes, noting whether the right one is offered first;
  4. map search in airplane mode to a never-viewed area;
  5. APK install size on the phone.

### Success metrics

- The 200% render reports no overflow.
- `flutter test` count is higher than the Phase 0 count by at least the number of requirements with a test criterion.

Checkpoint message: `docs(plan): FEAT-004 phase 8 - polish and documents`

## Recovery

Follow project `AGENTS.md` for the three-attempt limit and immediate blockers.
Record unresolved work and attempt counts in the current handoff.
Interrupted or failing work remains uncommitted and the phase remains incomplete.
Stop immediately, without workarounds, if any of these happen:

- the place book cannot meet REQ-003 after the P-1 reductions;
- the Philippines extract cannot be downloaded;
- the schema 3 migration test shows any loss of moments, photos, trips, or labels;
- a task appears to need a network call, a runtime dependency, or a change to a FEAT-003 rule not named in FEAT-004.
