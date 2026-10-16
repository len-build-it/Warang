# Implementation Plan: FEAT-001 User flow quality pass

Created: 2026-10-16T22:50:00+08:00
Updated: 2026-10-16T22:50:00+08:00
Revision: 1
Status: Approved - executing
Feature spec and revision: [FEAT-001 revision 1](../features/FEAT-001-user-flow-quality.md)
Approved baseline and architecture revisions: `docs/DESIGN_SPEC.md` and `docs/IMPLEMENTATION_PLAN.md` at commit `dc407c5`; architecture changes are limited to the FEAT-001 decision record
Len's chat approval: 2026-10-16, "approved, go ahead with all four decisions"
Target branch: `master` (verified 2026-10-16; no remote)

## Scope

This plan implements REQ-001 to REQ-023 of FEAT-001.
It also completes these remediation tasks: 4A (capture resilience), 4B (edit and manual location only), 4C (trips), and the Phase 6 settings item.
When a phase finishes one of those tasks, tick it in `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` in that phase's checkpoint commit, adding a dated note.

Preserve the existing untracked work: `.agents/skills/*`, `.agents/templates/`, `.claude/`, `CLAUDE.md`, `releases/`, and `scripts/`.
Never stage those paths in a phase commit.

### Execution mode

Len asked for **no hard stops**.
After a phase passes every gate and its checkpoint commit succeeds, continue straight to the next phase without asking for sign-off.
Stop only for a real blocker under the Recovery rules, or for a decision that changes approved architecture or behavior beyond this plan.

### Gates that every phase must pass

Run from the repository root, in this order, before the checkpoint commit:

1. `dart format --output=none --set-exit-if-changed lib test tool` -> exit 0 (run `dart format lib test tool` first).
2. `flutter analyze` -> `No issues found!`.
3. `flutter test` -> all tests pass, including every test added by the phase. The baseline is 41 passing tests.
4. `flutter build apk --debug` -> exit 0.
5. From Phase 1 on: `flutter test tool/ux_screenshots_test.dart --update-goldens` -> renders written to `docs/evidence/FEAT-001/phase-N/`; inspect the affected screens in both themes.

Commit cadence follows `docs/IMPLEMENTATION_PLAN.md` section 3: one commit per independently revertible change, a green tree before each commit, conventional messages, and no agent co-author.
Each phase ends with a `docs(plan)` checkpoint commit that updates this plan's checkboxes, the verification log, and `HANDOFF.md`.

## Phase 1: Visual foundations and evidence tooling

Requirements: REQ-001, REQ-002, REQ-003, REQ-023 (inset part); findings F-06, F-08, F-17, F-18, F-23, F-25
State: Complete

### Tasks

- [x] Add `tool/ux_screenshots_test.dart`, promoted from the 2026-10-16 audit harness saved at `docs/evidence/FEAT-001/baseline-harness.dart.txt`.
  Resolve paths from `Directory.current` and the `FLUTTER_ROOT` environment variable, not from absolute paths.
  Write renders under `docs/evidence/FEAT-001/<label>/` using a `--dart-define=UX_LABEL=phase-N` value.
  Keep it outside `test/` so the default `flutter test` never runs platform-dependent goldens.
- [x] Fix `buildWarangTheme` so every body and label style carries `fontFamily: 'Public Sans'`, while display and title roles keep Bricolage.
- [x] Add a `scrim` colour to `WarangColors` (light: ink at 42%; dark: black at 55%).
  Use it for the moment dimmer and the drawer scrim.
- [x] Set `outlineVariant` to the line token in the colour scheme; set the `TextButton` theme foreground to `accentText`.
- [x] Add the missing `WarangDivider` between the Storage rows.
- [x] Replace the hard-coded Home bottom padding (108) with `WarangLayout.navigationHeight(context) + 24`.
- [x] Soften the solid nav shadow so it no longer reads as a band (one shallow shadow, as in the glass variant).

### Verification

- [x] New `test/theme_tokens_test.dart`: covers the font family on every text style in both themes, dark scrim luminance below 0.1, `outlineVariant` equal to the line token, and `accentText` contrast of at least 4.5:1 on surface.
- [x] Gates 1-5 pass; renders show body text in the bundled family and a darkened map under the dark moment card.
- [x] Record results in [`docs/evidence/FEAT-001-verification.md`](../evidence/FEAT-001-verification.md).

### Review and checkpoint

- [x] Review correctness, scope, dependencies, and unrelated changes (Ponytail review).
- [x] Update plan, evidence, and `HANDOFF.md`.
- [x] Stage only reviewed phase paths and verify the staged diff.
- [x] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-001 phase 1 - visual foundations`
Continue automatically to Phase 2.

## Phase 2: Shell navigation and shared app state

Requirements: REQ-004, REQ-005, REQ-006, REQ-022; findings F-01, F-07, F-16, F-20
State: Not started

### Tasks

- [ ] Add `photoStoreProvider` and `mapTileStoreProvider`, overridden in `main.dart` with the instances already built there.
  Replace the direct `PhotoStore()` and `MapTileStore()` constructions in widgets with `ref.watch` (tests override them).
- [ ] Add `shellTabProvider` and `selectedMomentProvider` (Riverpod `Notifier`s).
  `AppShell` reads the tab from `shellTabProvider`, and Travel Mode reads the selection from `selectedMomentProvider`.
  Add one `showMomentOnMap(ref, moment)` helper that sets the tab to 0, selects the moment, and asks the map to move.
- [ ] Move `WarangDrawer` to `AppShell`'s `Scaffold.drawer`, with width 82%, `drawerScrimColor` set to the scrim token, and `drawerEdgeDragWidth: 24`; enable edge drag only on Travel Mode.
  Remove the custom `AnimatedPositioned` drawer, its scrim, and its edge detector from Travel Mode.
  The Travel Mode hamburger opens the shell drawer through a callback.
- [ ] Wrap the shell in `PopScope` with this order: deselect the moment, then return to Travel Mode from Home or News, then allow the pop.
  The drawer and dialogs keep their built-in back handling.
- [ ] Make the drawer's search open from any tab; a selected result calls `showMomentOnMap`.
- [ ] Add a search icon button to the Home header (48 x 48, tooltip "Search moments").
- [ ] Drawer counts: Trips excludes Everyday.

### Verification

- [ ] New `test/shell_navigation_test.dart` covers: back with a moment selected deselects it; back on Home or News selects Travel Mode; back on Travel Mode with nothing open allows the pop; with the drawer open, tapping the Home nav item does not change the tab; the closed drawer has no semantics in the tree; the search result opens on Travel Mode from Home.
- [ ] Update `test/map_navigation_test.dart` and `test/unavailable_actions_test.dart` for the drawer host change without weakening their assertions.
- [ ] Gates 1-5 pass; the drawer render covers the bottom navigation in both themes.

### Review and checkpoint

- [ ] Review correctness, scope, dependencies, and unrelated changes (Ponytail review).
- [ ] Update plan, evidence, and `HANDOFF.md`.
- [ ] Stage only reviewed phase paths and verify the staged diff.
- [ ] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-001 phase 2 - shell navigation`
Continue automatically to Phase 3.

## Phase 3: Capture loop closure

Requirements: REQ-007, REQ-008, REQ-009, REQ-010; findings F-10, F-11, F-12; remediation 4A
State: Not started

### Tasks

- [ ] Extract the active-trip rule into `lib/core/trip_rules.dart` (`Trip? activeTripFor(DateTime, List<Trip>)`).
  The start and end comparisons are inclusive of the whole calendar day.
  Make `TripsDao.findActiveFor` match it (compare against the start of the day after `endDate`).
- [ ] Add `WarangRepository.captureMoment({required File photo, String? caption, double? latitude, double? longitude, DateTime? capturedAt})`.
  It imports through the injected `PhotoStore`, inserts the moment, deletes the stored files if the insert throws, rethrows, and returns the saved `Moment`.
  `CaptureScreen` calls it instead of orchestrating the two steps itself.
- [ ] Add a location state to `CaptureScreen` (locating, located, unavailable).
  The meta line shows `LOCATING… · 4:42 PM`, `11.969°N · 121.918°E · 4:42 PM`, or `NO LOCATION YET · 4:42 PM`.
  A second line reads `SAVING TO <TRIP TITLE>` (or `SAVING TO EVERYDAY`).
  Save is never blocked by location.
- [ ] Replace the raw-exception snackbar with "Couldn't save this photo. It's still here - try again." plus a Retry action; keep the photo and reset the saving state.
- [ ] Introduce a small permission seam (a provider holding a `Future<PermissionStatus> Function()` for the camera) so tests can inject denied and permanently denied states.
  A permanently denied status shows "Camera access is off for Warang." with an "Open settings" action that calls `openAppSettings()`.
- [ ] `CaptureScreen` pops with the saved `Moment`.
  Travel Mode then moves the map to it when it has coordinates and shows a floating snackbar `Saved to <trip>`, with a bottom margin of the navigation height plus 8.
- [ ] Put the coordinate formatter in `lib/core/formatting.dart`; it is shared with Phase 4.

### Verification

- [ ] `test/core_rules_test.dart`: active-trip boundaries (start-day 00:00 is in; end-day 23:59 is in; the next day at 00:00 is out; undated trips never match; the most recently updated trip wins on overlap) and coordinate formatting (hemispheres, rounding).
- [ ] `test/data_layer_test.dart` additions: `captureMoment` cleans up the stored files when the insert fails; a DAO boundary test matches `activeTripFor`.
- [ ] `test/capture_flow_test.dart`: covers the three meta-line states, the trip line, the save-failure message with Retry and no exception text, the permanently denied action, and the saved snackbar on Travel Mode.
- [ ] Gates 1-5 pass; capture renders show the location and trip lines in both themes.

### Review and checkpoint

- [ ] Review correctness, scope, dependencies, and unrelated changes (Ponytail review).
- [ ] Tick remediation 4A with a dated note.
- [ ] Update plan, evidence, and `HANDOFF.md`.
- [ ] Stage only reviewed phase paths and verify the staged diff.
- [ ] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-001 phase 3 - capture loop`
Continue automatically to Phase 4.

## Phase 4: Moment card actions

Requirements: REQ-011, REQ-012, REQ-013, REQ-014, REQ-021 (card part); findings F-02, F-04, F-05, F-21; remediation 4B edit and manual location
State: Not started

### Tasks

- [ ] Add repository methods `updateMoment(id, {caption, placeLabel, tripId})` (empty strings clear to null), `setMomentLocation(id, lat, lng)`, and `restoreMoment(id)` (clears `deletedAt` on the moment).
- [ ] Moment card meta: place label, otherwise formatted coordinates, otherwise `NO LOCATION`.
  When there are no coordinates, show `ADD LOCATION` as a tappable `inkSoft` segment that starts placement mode (design spec section 10).
- [ ] Action row: two equal quiet buttons, `Edit` and `Delete`.
  `Edit` opens a modal bottom sheet with labelled Caption and Place name fields, a Trip dropdown (Everyday plus active trips), a "Place on map" button, and Save.
  Keyboard insets must not hide the fields.
- [ ] Placement mode on Travel Mode: hide the card, show a fixed centre crosshair, and show a glass bar with "Move the map to the spot" plus Cancel and Confirm.
  Confirm calls `setMomentLocation` with the map centre, then reselects the moment. Back or Cancel exits without changes.
- [ ] Delete: soft delete, close the card, and show "Moment deleted" with Undo for 6 s (floating above the navigation); Undo calls `restoreMoment` and reselects the moment.
- [ ] The card handle dismisses the card on a downward drag (velocity above 300); add a neutral placeholder through `Image.frameBuilder` while the photo decodes.
- [ ] Update `test/unavailable_actions_test.dart` so `Edit` is expected and Share still is not.

### Verification

- [ ] Repository tests: update, clear-to-null, move between trips, set location, and restore.
- [ ] `test/moment_actions_test.dart`: the Edit sheet saves and the card updates; placement Confirm writes the centre and Cancel does not; Delete followed by Undo restores the moment; the coordinates meta appears when the label is missing; a downward drag dismisses the card.
- [ ] Gates 1-5 pass; card, sheet, and placement renders are checked in both themes; the accent count on the card stays 0.

### Review and checkpoint

- [ ] Review correctness, scope, dependencies, and unrelated changes (Ponytail review).
- [ ] Tick remediation 4B edit and manual-location items with a dated note; leave the pager and sharing unticked.
- [ ] Update plan, evidence, and `HANDOFF.md`.
- [ ] Stage only reviewed phase paths and verify the staged diff.
- [ ] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-001 phase 4 - moment actions`
Continue automatically to Phase 5.

## Phase 5: Trips that receive moments

Requirements: REQ-015, REQ-016, REQ-017; findings F-03, F-13; remediation 4C
State: Not started

### Tasks

- [ ] Replace the New trip dialog with a full-screen form (`MaterialPageRoute`, `fullscreenDialog: true`).
  It has labelled Trip name (required), Place (optional), and Dates (optional) fields; Dates opens `showDateRangePicker`, and Clear dates is allowed.
  Validate that start is on or before end next to the field.
  Show a helper line: "Photos you take between these dates go into this trip."
- [ ] Reuse the same form for Edit trip (prefilled). Trip detail gets an overflow menu with Edit and Delete for non-Everyday trips.
- [ ] Add repository methods `updateTrip` and `deleteTrip(id)`: soft-delete the trip and move its moments to Everyday in one transaction.
  Delete asks for confirmation: "Delete this trip? Its N moments move to Everyday."
- [ ] Trip detail watches the repository (it receives a trip id, not a snapshot); when the trip is deleted, it pops.
  Tapping a moment row calls `showMomentOnMap`.
- [ ] Home trip cards show the planned chip when the start date is in the future, using the stored dates (no invented data).

### Verification

- [ ] Repository tests: dated assignment at both boundaries through `captureMoment`; update; delete moves moments to Everyday; Everyday cannot be updated or deleted.
- [ ] `test/trips_flow_test.dart`: an end-before-start error shows inline; a created dated trip appears with its range; trip detail updates after a moment is deleted; a row tap opens Travel Mode with the moment selected; delete confirmation moves the moments.
- [ ] Update `test/utility_screens_test.dart` for the form that replaces the dialog without weakening its validation assertions.
- [ ] Gates 1-5 pass; renders cover the form, a dated trip card, and trip detail in both themes.

### Review and checkpoint

- [ ] Review correctness, scope, dependencies, and unrelated changes (Ponytail review).
- [ ] Tick remediation 4C items with a dated note.
- [ ] Update plan, evidence, and `HANDOFF.md`.
- [ ] Stage only reviewed phase paths and verify the staged diff.
- [ ] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-001 phase 5 - trips`
Continue automatically to Phase 6.

## Phase 6: Honest Home, Settings, onboarding, and map controls

Requirements: REQ-018, REQ-019, REQ-020, REQ-021 (map part); findings F-09, F-14, F-15, F-19, F-22, F-24
State: Not started

### Tasks

- [ ] Move the analytics snapshot and place counting into `lib/core/memory_stats.dart` (pure Dart).
  The Home stats become Moments (total), Places (distinct labels), and Days (distinct capture days); the drawer uses the same function.
- [ ] Settings: remove the Sharing section and the Clean up row.
  Hold the storage futures in `initState` and refresh them after Clear.
  Clear asks "Clear offline map cache? Areas you have visited will need a connection again."
  The profile row shows the avatar through `PhotoStore` and opens the shared name editor (extract the drawer's `_editName` into one function).
- [ ] Privacy copy, onboarding: "Warang asks for your camera to take photos and your location to place them on the map. Your name, photos and pins stay on this phone. Map tiles are downloaded from OpenStreetMap."
  The Settings footer reads "Your photos and pins stay on this phone."
  Update the README Privacy and feature sections to match.
- [ ] Remove the map layers menu and its `_showMoments` and `_showClusters` state from `warang_map.dart`.

### Verification

- [ ] `test/core_rules_test.dart` additions for memory stats: total, distinct days across midnight, places ignoring blank labels.
- [ ] Update `test/utility_screens_test.dart` and `test/unavailable_actions_test.dart`: Sharing and Clean up are absent; Clear confirm is shown and Cancel keeps the cache; the profile row opens the editor; no "Nothing leaves it" text remains in the widget tree.
- [ ] Update `test/map_navigation_test.dart` for the absent layers button.
- [ ] Gates 1-5 pass; Home, Settings, and onboarding renders are checked in both themes; the accent count per screen stays at 4 or fewer.

### Review and checkpoint

- [ ] Review correctness, scope, dependencies, and unrelated changes (Ponytail review).
- [ ] Tick the remediation Phase 6 settings task with a dated note recording the Clean up removal decision.
- [ ] Update plan, evidence, and `HANDOFF.md`.
- [ ] Stage only reviewed phase paths and verify the staged diff.
- [ ] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-001 phase 6 - honest surfaces`
Continue automatically to Phase 7.

## Phase 7: End-to-end verification and closeout

Requirements: REQ-001 to REQ-023
State: Not started

### Tasks

- [ ] Add `test/user_journey_test.dart`, one widget test that walks the full journey against an in-memory database with an injected photo, location, and permission.
  The journey is: onboarding -> capture without GPS -> saved snackbar -> open the moment -> Edit caption and place -> place on map -> create a dated trip -> move the moment into it -> trip detail -> view on map -> Delete -> Undo -> back out to an exit-ready state.
- [ ] Render every screen in both themes to `docs/evidence/FEAT-001/final/` and compare them with `baseline/`; fix any pixel-level issue found (overflow, clipping, contrast, misalignment).
- [ ] Reconcile the README feature list and the FEAT-001 status.
- [ ] Add a pending physical-device checklist to the verification log for Len (back gesture, TalkBack drawer focus, keyboard over the Edit sheet, real GPS, font rendering).

### Verification

- [ ] Gates 1-5 pass on the final tree.
- [ ] `git status --short` shows only the preserved untracked paths listed in Scope.

### Review and checkpoint

- [ ] Review the full FEAT-001 diff (`git diff dc407c5..HEAD`) for correctness, scope, and Ponytail simplicity.
- [ ] Update plan, evidence, `docs/SPEC_INDEX.md`, and `HANDOFF.md`.
- [ ] Stage only reviewed phase paths and verify the staged diff.
- [ ] Commit and verify that Git reports success.

Checkpoint message: `docs(plan): FEAT-001 phase 7 - journey verification`
FEAT-001 is complete once this commit succeeds; physical-device checks remain pending until Len supplies results.

## Recovery

Follow project `AGENTS.md` and the implementation-plan skill: at most three fix-and-check attempts for the same problem, with each attempt and its result recorded in `HANDOFF.md`.
Interrupted or failing work stays uncommitted, and the phase stays incomplete.
Known environment issue: if a Flutter command reports that it "failed to delete a directory" at `ios/Flutter/ephemeral/Packages/.packages`, remove that ignored, generated directory and rerun; this does not count as an attempt.
Do not substitute a different architecture to force progress; return to Len instead.
