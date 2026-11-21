# FEAT-002: Ponytail cleanup

Created: 2026-11-21T16:45:00+08:00
Updated: 2026-11-21T16:56:00+08:00
Revision: 1
Status: Approved

## Purpose and success

The 2026-11-21 ponytail audit found dead code, unused dependencies, duplicated logic, and committed clutter left behind by FEAT-001 and earlier work.
This feature removes them without changing anything a user can see, except the camera permission prompt described in D-2.
Success means the app behaves exactly as it did at commit `a85a915`, with fewer lines, fewer dependencies, and every gate still green.

## Baseline (measured 2026-11-21 at `a85a915`)

- `flutter test`: 96 tests, all passing.
- `flutter analyze`: `No issues found!`.
- Hand-written Dart under `lib/` (excluding `*.g.dart`): 8021 lines.
- Direct non-SDK dependencies in `pubspec.yaml`: 17.

## Scope and non-goals

In scope: audit findings 1-5 and 7-13 (see the table below).
Out of scope:
- Audit finding 6 (moving the tile cache from `sqflite` into Drift).
  `docs/IMPLEMENTATION_PLAN.md` section T17 keeps the cache in its own `sqflite` database on purpose, so it can be cleared without touching moments.
  That is an approved architecture decision, so this feature keeps it.
- `.cursorrules`, which holds Len's tool rules and is not bloat.
- Any new behavior, redesign, or refactor beyond the listed findings.
- The outer `WARANG/` folder that `len-toolkit` set up by mistake. It sits outside this repository, and Len cleans it up by hand.

## Requirements and acceptance criteria

| ID | Required behavior | Observable pass/fail criterion |
| --- | --- | --- |
| REQ-001 | Delete the unexposed `.travelbook` service. | `lib/features/travelbook/` does not exist; `grep -rn "travelbook_service\|TravelbookService" lib test tool` returns nothing. |
| REQ-002 | Delete the unused share service. | `lib/features/share/` does not exist; `grep -rn "share_service\|WarangShareService" lib test tool` returns nothing. |
| REQ-003 | Remove `toJson` and `fromJson` from `Profile`, `Trip`, and `Moment`. | `grep -n "toJson\|fromJson" lib/core/models.dart` returns nothing. |
| REQ-004 | Remove the `archive`, `share_plus`, and `cross_file` dependencies. | None of the three appear in `pubspec.yaml` or as `package:` imports under `lib`, `test`, or `tool`; `flutter pub get` succeeds. |
| REQ-005 | Remove `permission_handler`; location permission uses Geolocator, and the camera uses the system camera intent with no app permission (D-2). | `permission_handler` is absent from `pubspec.yaml` and all imports; `android.permission.CAMERA` is absent from `android/app/src/main/AndroidManifest.xml`; the capture button opens the capture flow without a permission dialog in widget tests. |
| REQ-006 | Location reads keep the current contract: one-shot reads, never blocking, `null` when denied or unavailable. | Existing capture tests pass; a new test shows that `locationReaderProvider` returns `null` when Geolocator permission is denied (via an injected seam or override). |
| REQ-007 | Delete the unused `WarangToggle` widget and its test. | `grep -rn "WarangToggle" lib test tool` returns nothing. |
| REQ-008 | The map tile store creates each table exactly once in its schema code, using `CREATE ... IF NOT EXISTS` in `onOpen` only. | `map_tile_store.dart` contains one `CREATE TABLE` statement per table, plus the index; existing tile-store tests pass; a new test opens a database that has only the `tiles` table and then saves and loads a camera snapshot. |
| REQ-009 | Tile eviction runs without loading every tile's bytes into Dart. | `evictToLimit` makes no `query` call that selects the `bytes` column; the existing "LRU eviction removes the oldest tile first" test passes unchanged; a new test with five tiles evicts the oldest ones until the total is at or below the limit. |
| REQ-010 | `seedDefaults` writes each `appMeta` key once per call. | The `writeValue('activeProfileId'...)` and `writeValue('everydayTripId'...)` calls inside the null branches are gone; existing data-layer tests pass. |
| REQ-011 | `PhotoStore` generates IDs through `newId()`. | `grep -n "Uuid" lib/data/files/photo_store.dart` returns nothing. |
| REQ-012 | Remove committed clutter and archive completed documents. | `_to_delete/`, `docs/Warang design implementation.html`, and `docs/Warang design implementation_files/` are removed from Git; `DESIGN_UPDATE_IMPLEMENTATION_PLAN.md` and `warang-design-prompt.md` move to `docs/archive/`; every Markdown link to them in `docs/`, `README.md`, and the root plan resolves. |
| REQ-013 | Keep the docs truthful. | `README.md` "Built with" and layout sections no longer list `share_plus`, `archive`, `share/`, or `travelbook/`; `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` has a dated note that the travelbook and share code was removed in FEAT-002 and will be rebuilt when its Phase 3 starts; `docs/SPEC_INDEX.md` lists FEAT-002 and the archived paths. |
| REQ-014 | Nothing a user can see changes, apart from D-2. | `flutter test` passes; the test count equals 96 minus the removed `WarangToggle` test and the removed permanently-denied camera test, plus the tests added by this feature; screenshot renders from `tool/ux_screenshots_test.dart` match a `feat-002-baseline` golden set rendered at `a85a915`, pixel for pixel, except the clock-dependent Home-scrolled and Capture screens, which are compared by eye in both themes. |

## Success metrics (feature level)

- Hand-written `lib/` Dart lines: at most 7700, down from 8021 (expected about 7680).
- Direct non-SDK dependencies: 13, down from 17.
- `flutter analyze` returns `No issues found!`, and `flutter build apk --debug` exits 0.
- No test assertion is weakened; a test is deleted only when the code it covers is deleted.

## Decisions and assumptions

- D-1 (proposed): delete the travelbook and share code now instead of keeping it until the remediation plan's Phase 3.
  Git history keeps it (last present at `a85a915`), and that phase rebuilds it against its own spec.
- D-2 (proposed, changes visible behavior): drop the CAMERA permission.
  `image_picker` with `ImageSource.camera` launches the system camera app, which needs no app permission on Android once the app stops declaring CAMERA.
  The in-app "Camera access is off" snackbar and its test go away, because there is no permission left to deny.
  Location keeps a permission prompt through `Geolocator.checkPermission` and `Geolocator.requestPermission`, which `warang_map.dart` already uses.
  Assumption: the device has a camera app that handles `ACTION_IMAGE_CAPTURE`; Len confirms this on a physical device.
- Observed: `docs/IMPLEMENTATION_PLAN.md` T17 makes the separate `sqflite` tile cache intentional, so finding 6 is dropped.

## Open questions and readiness

Approval of this revision also approves D-1 and D-2.
If Len rejects D-2, REQ-005 and REQ-006 are dropped, `permission_handler` stays, and the dependency target becomes 14.
Len's chat approval: 2026-11-21 chat: "I, Len, approve FEAT-002 revision 1 (docs/features/FEAT-002-ponytail-cleanup.md) and its plan revision 1 (docs/plans/FEAT-002-implementation.md), including decisions D-1 and D-2."
