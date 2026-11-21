# Implementation Plan: FEAT-002 Ponytail cleanup

Created: 2026-11-21T16:50:00+08:00
Updated: 2026-11-21T16:56:00+08:00
Revision: 1
Status: Approved
Feature spec and revision: [FEAT-002 revision 1](../features/FEAT-002-ponytail-cleanup.md)
Approved baseline and architecture revisions: `docs/DESIGN_SPEC.md` and `docs/IMPLEMENTATION_PLAN.md` at commit `dc407c5`; the tile cache stays in `sqflite` per T17
Len's chat approval: 2026-11-21 chat: "I, Len, approve FEAT-002 revision 1 (docs/features/FEAT-002-ponytail-cleanup.md) and its plan revision 1 (docs/plans/FEAT-002-implementation.md), including decisions D-1 and D-2."
Target branch: `master` (verified 2026-11-21 at `a85a915`; no remote)
Implementing agent: Gemini

## Scope

This plan implements REQ-001 to REQ-014 of FEAT-002.
It removes code and files; it adds no features and no dependencies.
If a task seems to need new behavior, a new dependency, or a design change, that is out of scope: record it in `HANDOFF.md` and leave it undone.

Preserve the existing untracked work: `.agents/skills/*`, `.agents/templates/`, `.claude/`, `CLAUDE.md`, `releases/`, and `scripts/`.
Never stage those paths, and never use `git add -A` or `git add .`.

### Execution mode

Len asked for **no hard stops** (2026-11-21 chat).
This overrides the "mandatory hard stops" line in the project-root `AGENTS.md` for this plan only.
After a phase passes every gate and its checkpoint commit succeeds, continue straight to the next phase without asking.
Stop only under the Recovery rules below.

### Gates that every phase must pass

Run these from the repository root, in this order, before the checkpoint commit:

1. `dart format lib test tool`, then `dart format --output=none --set-exit-if-changed lib test tool` -> exit 0.
2. `flutter analyze` -> `No issues found!`.
3. `flutter test` -> `All tests passed!`, and the count equals the expected count stated in the phase.
4. `flutter build apk --debug` -> exit 0.
5. Visual no-change gate: `flutter test tool/ux_screenshots_test.dart --dart-define=UX_LABEL=feat-002-baseline` -> passes, except for the time-dependent screens listed below.
   Before any Phase 1 edit, while the tree is still at `a85a915`, create that baseline once with `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=feat-002-baseline`, and commit it in the first Phase 1 commit.
   Never run `--update-goldens` again on `feat-002-baseline` or on `final`.
   Observed on 2026-11-21 at `a85a915`: `final/` no longer matches because two screens depend on the clock.
   `08_home_scrolled_*` failed by 3.91% because the capture-trend chart window moves with today's date, and `12_capture_*` failed by 0.07% because the capture time is shown.
   Those four test cases (`filled flows light/dark` and `capture light/dark`) may fail only on those two screens.
   For them, render with `--update-goldens --dart-define=UX_LABEL=feat-002-phase-N` and compare with `feat-002-baseline/` by eye in both themes; any difference other than the date window or the clock time is a regression.
   Every other screen must match exactly.
   Delete the generated `tool/failures/` folder after each run and never commit it.
6. Phase metric: every grep and count listed under the phase's "Success metrics" returns exactly the stated result.

Record the actual command output (the test count, analyzer line, grep results, and line counts) in `docs/evidence/FEAT-002-verification.md` for each phase.
Create that file in Phase 1 from `.agents/templates/docs/VERIFICATION.md`.

Commit cadence: one commit per independently revertible change, a green tree before each commit, conventional messages, and no agent co-author.
Each phase ends with a `docs(plan)` checkpoint commit that ticks this plan's boxes and updates the evidence log and `HANDOFF.md`.

Line-count command (hand-written Dart under `lib/`):
`find lib -name "*.dart" ! -name "*.g.dart" | xargs cat | wc -l` (baseline 8021).

## Phase 1: Remove the unexposed archive and share code

Requirements: REQ-001, REQ-002, REQ-003, REQ-004, REQ-013 (README and remediation note)
State: Complete
Expected test count: 96 (no test covers this code)

### Tasks

- [x] Before editing any code, render `docs/evidence/FEAT-001/feat-002-baseline/` as described in gate 5, and commit it alone as `test(evidence): FEAT-002 visual baseline at a85a915`.
- [x] Delete `lib/features/travelbook/` and `lib/features/share/`.
- [x] Remove `toJson` and every `fromJson` factory from `Profile`, `Trip`, and `Moment` in `lib/core/models.dart`.
  Leave `NewsArticle.fromJson` in `news_tab_screen.dart` alone, because it parses the bundled news asset.
- [x] Remove `archive`, `share_plus`, and `cross_file` from `pubspec.yaml`, then run `flutter pub get` so `pubspec.lock` updates.
- [x] In `README.md`, remove the "Planned sharing/archive primitives" row and the `share/` and `travelbook/` lines from the layout.
  Keep the sentence that says backup, restore, sharing, and `.travelbook` are tracked in the remediation plan.
- [x] Add a dated note under Phase 3 of `docs/REMEDIATION_IMPLEMENTATION_PLAN.md`: "2026-11-21: unexposed `TravelbookService` and `WarangShareService` removed in FEAT-002 (last present at `a85a915`); rebuild against this phase's spec."

### Success metrics

- `grep -rn "travelbook_service\|TravelbookService\|share_service\|WarangShareService" lib test tool` -> no output.
- `grep -n "toJson\|fromJson" lib/core/models.dart` -> no output.
- `grep -rn "package:archive/\|package:share_plus/\|package:cross_file/" lib test tool` -> no output.
- `grep -nE "^  (archive|share_plus|cross_file):" pubspec.yaml` -> no output.
- Line count: at most 7790 (expected drop of about 230).

### Verification

- [x] Gates 1-6 pass.
- [x] Results are recorded in `docs/evidence/FEAT-002-verification.md`.

### Review and checkpoint

- [x] Review correctness, scope, dependencies, and unrelated changes (Ponytail review).
- [x] Update plan, evidence, and `HANDOFF.md`.
- [x] Stage only reviewed phase paths and verify the staged diff.
- [x] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-002 phase 1 - remove unexposed archive and share code`
Continue automatically to Phase 2.

## Phase 2: Shrink duplicated logic

Requirements: REQ-007, REQ-008, REQ-009, REQ-010, REQ-011
State: Awaiting approval
Expected test count: 96 - 1 (`WarangToggle` test) + 2 (new tile-store tests) = 97

### Tasks

- [ ] Delete `WarangToggle` from `lib/app/theme/components.dart` and its test `'WarangToggle includes toggle semantics'` in `test/shared_surfaces_test.dart`.
- [ ] In `lib/features/map/map_tile_store.dart`, remove `onCreate` and `version`.
  Have `onOpen` run `CREATE TABLE IF NOT EXISTS` for `tiles`, `map_camera`, and `map_location`, plus `CREATE INDEX IF NOT EXISTS tiles_fetched_at ON tiles (fetchedAt)`.
  Keep the column definitions exactly as they are now.
- [ ] Rewrite `evictToLimit` so SQL does the work: read `totalBytes()`; if it is over the limit, delete tiles oldest first until the running total is at or below the limit, using a `rowid` subquery with a window `SUM(length(bytes)) OVER (ORDER BY fetchedAt DESC)` or an equivalent single statement.
  No Dart-side query may select the `bytes` column during eviction.
  Bundled Android SQLite (API 21) may not support window functions, because the tile store uses the platform `sqflite`.
  If so, fall back to a loop that selects only `rowid` and `length(bytes)` ordered by `fetchedAt ASC` and deletes by `rowid`; that still meets REQ-009.
- [ ] In `WarangDatabase.seedDefaults`, delete the two `writeValue` calls inside the `if (profile == null)` and `if (everyday == null)` branches; the unconditional writes after them stay.
- [ ] In `lib/data/files/photo_store.dart`, replace `const Uuid().v4()` with `newId()` from `lib/core/ids.dart` and drop the `uuid` import there.

### New tests

- [ ] `test/map_tile_store_test.dart`: a database file that already has only the `tiles` table (created by raw `sqflite_common_ffi` SQL) opens through `MapTileStore`, and `saveCamera` followed by `loadCamera` round-trips.
- [ ] `test/map_tile_store_test.dart`: put five 100-byte tiles with increasing `fetchedAt`, call `evictToLimit(250)`, then `totalBytes()` is at most 250 and the two newest tiles are still readable.

### Success metrics

- `grep -rn "WarangToggle" lib test tool` -> no output.
- `grep -c "CREATE TABLE" lib/features/map/map_tile_store.dart` -> `3`.
- `grep -n "onCreate" lib/features/map/map_tile_store.dart` -> no output.
- `grep -n "Uuid" lib/data/files/photo_store.dart` -> no output.
- `grep -c "writeValue('activeProfileId'" lib/data/db/database.dart` -> `1`, and the same for `'everydayTripId'`.
- The existing test `'LRU eviction removes the oldest tile first'` passes with no edits to it.
- Line count: at most 7730.

### Verification

- [ ] Gates 1-6 pass with 97 tests.
- [ ] Results are recorded in the evidence log.

### Review and checkpoint

- [ ] Review correctness, scope, dependencies, and unrelated changes (Ponytail review).
- [ ] Update plan, evidence, and `HANDOFF.md`.
- [ ] Stage only reviewed phase paths and verify the staged diff.
- [ ] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-002 phase 2 - shrink duplicated logic`
Continue automatically to Phase 3.

## Phase 3: Drop permission_handler (decision D-2)

Requirements: REQ-005, REQ-006
State: Awaiting approval
Expected test count: 97 - 1 (permanently-denied camera test) + 1 (new location-denied test) = 97

Skip this whole phase if Len's approval rejects D-2; record "skipped by decision" in the plan and evidence, then continue to Phase 4 with a dependency target of 14.

### Tasks

- [ ] Remove `<uses-permission android:name="android.permission.CAMERA" />` from `android/app/src/main/AndroidManifest.xml`.
  Keep both location permissions.
- [ ] In `lib/app/device_providers.dart`, delete `CameraPermissionRequest` and `cameraPermissionProvider`.
  Change `locationReaderProvider` to call `Geolocator.checkPermission()`, then `Geolocator.requestPermission()` only when the result is `denied`, and return `null` for `denied`, `deniedForever`, or `unableToDetermine`.
  Keep the try/catch, the 3-second `timeLimit`, and the medium accuracy.
- [ ] In `lib/features/travel_mode/travel_mode_screen.dart`, delete the camera permission check and the two snackbars at the start of `_capture`, so it pushes `CaptureScreen` directly.
  Keep the save confirmation snackbar.
- [ ] Remove the `permission_handler` import from `lib/` and `test/`, and remove it from `pubspec.yaml`; run `flutter pub get`.
- [ ] Update `test/capture_flow_test.dart` and `test/user_journey_test.dart`: drop the `cameraPermissionProvider` overrides and delete `'a permanently denied camera offers system settings'`.
  Do not weaken any other assertion.
- [ ] If `test/android_hardening_test.dart` checks manifest permissions, update it to expect no CAMERA permission and both location permissions.

### New tests

- [ ] One test showing that the location reader returns `null` when permission is denied.
  If the Geolocator static calls cannot be faked without a new dependency, extract the permission check into a function parameter or provider, in the same style as the existing device adapters, and test through that seam.

### Success metrics

- `grep -rn "permission_handler" lib test tool pubspec.yaml` -> no output.
- `grep -n "android.permission.CAMERA" android/app/src/main/AndroidManifest.xml` -> no output.
- `grep -rn "cameraPermissionProvider\|openAppSettings" lib test tool` -> no output.
- Line count: at most 7710.

### Verification

- [ ] Gates 1-6 pass with 97 tests.
- [ ] Add these lines to the pending physical-device checklist in the evidence log, for Len: "Capture opens the system camera with no Warang permission dialog," "The photo saves and pins," and "Denying location still saves the photo with NO LOCATION."
  Mark them pending; do not claim them.

### Review and checkpoint

- [ ] Review correctness, scope, dependencies, and unrelated changes (Ponytail review).
- [ ] Update plan, evidence, and `HANDOFF.md`.
- [ ] Stage only reviewed phase paths and verify the staged diff.
- [ ] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-002 phase 3 - drop permission_handler`
Continue automatically to Phase 4.

## Phase 4: Repository clutter and final verification

Requirements: REQ-012, REQ-013, REQ-014
State: Awaiting approval
Expected test count: 97 (or 97 if Phase 3 was skipped, because it nets to zero)

### Tasks

- [ ] `git rm -r _to_delete "docs/Warang design implementation.html" "docs/Warang design implementation_files"`.
- [ ] `git mv DESIGN_UPDATE_IMPLEMENTATION_PLAN.md docs/archive/DESIGN_UPDATE_IMPLEMENTATION_PLAN.md` and `git mv warang-design-prompt.md docs/archive/warang-design-prompt.md`.
- [ ] Fix every reference to the moved or removed files: run `grep -rn "DESIGN_UPDATE_IMPLEMENTATION_PLAN\|warang-design-prompt\|Warang design implementation\|_to_delete" --include=*.md . | grep -v "^./.agents\|^./.claude"` and update the paths in `docs/SPEC_INDEX.md`, `docs/IMPLEMENTATION_PLAN.md`, and the archived plan itself.
  Historical prose in completed plans may keep the old name if it is not a link, but every Markdown link must resolve.
- [ ] Update `docs/SPEC_INDEX.md`: add rows for the FEAT-002 feature, plan, and evidence; point the UI design update row at `docs/archive/`; set the timestamps.
- [ ] Set FEAT-002 spec status to "Implemented - physical-device checks pending" and this plan's status to "Complete".

### Success metrics (feature totals)

- `ls _to_delete "docs/Warang design implementation.html" DESIGN_UPDATE_IMPLEMENTATION_PLAN.md warang-design-prompt.md` -> every path reports "No such file".
- The reference grep above returns only lines that point at `docs/archive/` or plain, non-link historical prose.
- Line count: at most 7700.
- Direct non-SDK dependencies in `pubspec.yaml`: 13 (14 if D-2 was rejected).
- `git status --short` shows only the preserved untracked paths listed in Scope.
- The full diff `git diff a85a915..HEAD -- lib` contains only deletions and the replacements named in this plan; there is no new public API except the Phase 3 test seam, if one was needed.

### Verification

- [ ] Gates 1-6 pass on the final tree.
- [ ] Record the before and after numbers for lines, dependencies, and tests in the evidence log.

### Review and checkpoint

- [ ] Review the full FEAT-002 diff (`git diff a85a915..HEAD`) for correctness, scope, and Ponytail simplicity.
- [ ] Update plan, evidence, `docs/SPEC_INDEX.md`, and `HANDOFF.md`, with the next action being "Len runs the FEAT-001 and FEAT-002 physical-device checklists".
- [ ] Stage only reviewed phase paths and verify the staged diff.
- [ ] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-002 phase 4 - clutter and final verification`
FEAT-002 is complete once this commit succeeds.

## Recovery

Follow project `AGENTS.md` and the implementation-plan skill: at most three fix-and-check attempts for the same problem, with each attempt and its result recorded in `HANDOFF.md`.
After the third failed attempt, stop that phase and report the failing gate, the exact error, each attempt, and the outstanding edits.
Interrupted or failing work stays uncommitted, and the phase stays incomplete.
Known environment issue: if a Flutter command reports that it "failed to delete a directory" under `build/` or `ios/Flutter/ephemeral/`, remove that ignored, generated directory and rerun; this does not count as an attempt.
Never make a gate pass by deleting or weakening a test that does not cover deleted code, by running gate 5 with `--update-goldens` on the `final` label, or by adding a dependency.
