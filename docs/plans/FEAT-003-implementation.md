# Implementation Plan: FEAT-003 Clay keepsake redesign

Created: 2026-11-21T20:38:00+08:00
Updated: 2026-11-21T21:21:00+08:00
Revision: 1
Status: Approved - in progress
Feature spec and revision: [FEAT-003 revision 1](../features/FEAT-003-clay-keepsake-redesign.md)
Approved baseline and architecture revisions: `docs/IMPLEMENTATION_PLAN.md` at `dc407c5` for architecture; FEAT-003 revision 1 replaces `docs/DESIGN_SPEC.md` for appearance and motion
Len's chat approval of the feature spec: 2026-11-21 20:37 (Asia/Manila), project thread decision card: "Approve as recommended" on "Approve FEAT-003 revision 1 with the recommended answers to D-1 to D-6?"
Len's chat approval of this plan: 2026-11-21 20:40 (Asia/Manila), project thread decision card: "Approve plan as written" on "Approve FEAT-003 plan revision 1 with P-1 to P-3 as recommended?"
Target branch: `master` (verified 2026-11-21 at `ba0c56a`; no remote)
Implementing agent: Gemini or Claude Code, under the shared `AGENTS.md` rules

## Scope

This plan implements REQ-001 to REQ-025 of FEAT-003, with D-1 to D-6 answered as recommended:

- D-1: a nullable `colorKey` column on trips, added by a Drift migration from schema 1 to 2.
- D-2: Len or an illustrator draws the layered maya; Phase 9 may use placeholder layers until the art arrives.
- D-3: no Rive.
- D-4: the Home tab charts are removed.
- D-5: dock order Map, Trips, capture, News, Search.
- D-6: contrast fixes ship first.

No runtime package dependency may be added.
Fonts, icons, artwork, and the maya's lines are bundled assets.
If a task seems to need new behaviour, a new dependency, or a design change beyond FEAT-003, record it in `HANDOFF.md` and leave it undone.

Preserve existing untracked work: `.agents/skills/*`, `.agents/templates/`, `.claude/`, `CLAUDE.md`, `releases/`, `scripts/`, and `docs/evidence/FEAT-001/claude-review/`.
Never stage those paths, and never use `git add -A` or `git add .`.

### Execution mode (approved with P-1)

Phases run continuously without routine approval stops, as in FEAT-002.
There is one planned stop: after Phase 6, the agent sends Len the map, capture, and moment-card screenshots in both themes and waits for his visual approval before Phase 7.
That stop is the "prototype first" check from RES-001, so a wrong direction is caught before the rest of the app is restyled.
Other stops follow the Recovery rules.

### Decisions this plan needs from Len

| ID | Question | Recommendation |
| --- | --- | --- |
| P-1 | Keep the one visual-review stop after Phase 6? | Yes. |
| P-2 | How are icon SVGs turned into a font? | A one-off conversion with a design-time tool run outside the app build (for example `fantasticon` through `npx`), with the source SVGs and the generated font both committed. It adds nothing to `pubspec.yaml`. |
| P-3 | Who supplies the font files? | The agent downloads the OFL releases from the Google Fonts GitHub repository with their licence files. If the device network blocks it, Len downloads them. |

### Gates that every phase must pass

Run from the repository root, in this order, before the checkpoint commit:

1. `dart format lib test tool`, then `dart format --output=none --set-exit-if-changed lib test tool` -> exit 0.
2. `flutter analyze` -> `No issues found!`.
3. `flutter test` -> `All tests passed!`, with the count recorded; the count may only grow, except where a phase deletes a screen's tests and says so.
4. `flutter build apk --debug` -> exit 0.
5. Visual gate: `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=feat-003-phase-N` renders all screens in both themes into `docs/evidence/FEAT-001/feat-003-phase-N/`.
   The agent compares them by eye with the previous phase and with the spec, and lists every intended and unintended difference in the evidence log.
   Unintended differences are regressions.
   Never run `--update-goldens` on `final`, `feat-002-baseline`, or `claude-review`.
   Delete `tool/failures/` after each run and never commit it.
6. Phase metrics: every check under the phase's "Success metrics" returns exactly the stated result.

Record actual output for each gate in `docs/evidence/FEAT-003-verification.md`, created in Phase 1 from `.agents/templates/docs/VERIFICATION.md`.
Commit one independently revertible change at a time, with a green tree, conventional messages, and no agent co-author.
Each phase ends with a `docs(plan)` checkpoint commit that ticks this plan's boxes and updates the evidence log and `HANDOFF.md`.

Before Phase 1, render the starting point once with `--dart-define=UX_LABEL=feat-003-baseline` and commit it alone as `test(evidence): FEAT-003 visual baseline at <hash>`.

## Phase 1: Contrast and neutral tokens

Requirements: REQ-001, REQ-002, REQ-003 (neutrals only)
State: Complete (checkpoint commit recorded in `HANDOFF.md`)

### Tasks

- [x] Replace the neutral colours in `lib/app/theme/tokens.dart` with spec V1 (`ground`, `surface`, `surfaceRaised`, `ink`, `inkSoft`, `inkFaint`, `boundary`, `hairline`, `shadowTint`) in both themes.
- [x] Point text fields, cards, and outlines that identify a control at `boundary`; keep purely decorative dividers on `hairline`.
- [x] Move any `Color(0x...)` literal outside `lib/app/theme/` into a token.
- [x] Add `test/contrast_test.dart`, which computes WCAG relative luminance and asserts every text pair in V1 is at least 4.5:1 and `boundary` is at least 3:1 against `ground` and `surface`, in both themes.

### Success metrics

- `grep -rn "Color(0x" lib --include=*.dart | grep -v "lib/app/theme/"` -> no output.
- `contrast_test.dart` passes and fails if any V1 value is changed back to the old `inkFaint` `#8A8F83`.

Checkpoint message: `docs(plan): FEAT-003 phase 1 - contrast and neutral tokens`

## Phase 2: Typography

Requirements: REQ-004
State: Approved - not started

### Tasks

- [ ] Add Bagel Fat One (400), Atkinson Hyperlegible Next (400, 600, 700), and Shantell Sans (500) to `assets/fonts/`, each with its `OFL.txt`, per P-3.
- [ ] Declare them in `pubspec.yaml` and remove Bricolage Grotesque, Public Sans, and DM Mono and their files.
- [ ] Define the V3 roles in the theme, with tabular figures where numbers appear.
- [ ] Change `WarangMetadata` and every uppercase, letter-spaced mono string to sentence case with the `meta` role, using `intl` date formats such as "Sat 14 Mar, 4:42 pm".
- [ ] Update tests that match the old uppercase strings.

### Success metrics

- `grep -rn "DM Mono\|Public Sans\|Bricolage" lib pubspec.yaml` -> no output.
- `ls assets/fonts` lists only the three new families and their licence files.
- `grep -rn "toUpperCase()" lib` -> no output in display code.

Checkpoint message: `docs(plan): FEAT-003 phase 2 - keepsake typography`

## Phase 3: Icons

Requirements: REQ-005, REQ-006
State: Approved - not started

### Tasks

- [ ] Draw the 21 glyphs in spec V7 as 24 by 24 SVG under `design/icons/`, with a 2.5 px rounded stroke and a separate duotone fill layer.
- [ ] Convert them to `assets/fonts/WarangIcons.ttf` per P-2, and add `lib/app/theme/warang_icons.dart` with one `IconData` per glyph.
- [ ] Replace every `Icons.*` use.
- [ ] Add a widget test that walks the main screens and asserts every tappable icon has a tooltip or semantic label.

### Success metrics

- `grep -rn "Icons\." lib` -> no output.
- The icon test passes.

Checkpoint message: `docs(plan): FEAT-003 phase 3 - clay icon set`

## Phase 4: Clay foundation and shared components

Requirements: REQ-001, REQ-010, Q-1, Q-2
State: Approved - not started

### Tasks

- [ ] Add the V2 keepsake palette, V4 shape scale, V5 depth levels, and V6 motion and haptic tokens to `lib/app/theme/`.
- [ ] Build `ClaySurface` per V5 with cached gradients and a dark-theme rim, and a `ClayPressable` wrapper that applies `press`, `release`, and the haptic for its role.
- [ ] Build the shared components C4 buttons, C5 fields, C6 stamp, C7 chip, C8 polaroid, C9 sheet, C11 toggle, C12 toast, and C13 speech bubble.
- [ ] Make every component fall back to `fade` and no scale or rotation when `MediaQuery.disableAnimations` is true.
- [ ] Add widget tests for each component in both themes and with reduced motion.

### Success metrics

- No screen changes yet except where a screen already uses a replaced shared component.
- Component tests pass in both themes and with `disableAnimations: true`.

Checkpoint message: `docs(plan): FEAT-003 phase 4 - clay foundation and components`

## Phase 5: Dock, capture button, avatar bubble, and You sheet

Requirements: REQ-007, REQ-008, REQ-012
State: Approved - not started

### Tasks

- [ ] Build C1 dock and C2 capture button, and replace the bottom bar and the wide-screen rail in `app_shell.dart` with them, in the order Map, Trips, capture, News, Search.
- [ ] Make Search a dock tab that reuses the existing search behaviour.
- [ ] Build C3 avatar bubble and the You sheet with every function of the current drawer: photo, name, counts, Settings, About.
- [ ] Delete `lib/app/shell/warang_drawer.dart` and its tests, moving the still-relevant assertions to You sheet tests.
- [ ] Rename the tabs to Map and Trips per V8.

### Success metrics

- `test -e lib/app/shell/warang_drawer.dart` -> false.
- Widget tests reach Settings, About, profile edit, and Search from the map in two taps or fewer.
- The capture test finds the capture flow started on tap release with no delay.

Checkpoint message: `docs(plan): FEAT-003 phase 5 - dock and You sheet`

## Phase 6: Map, pins, capture, moment card, edit sheet, and placement

Requirements: REQ-009, REQ-015, S2 to S5
State: Approved - not started

### Tasks

- [ ] Build C10 pins as pre-painted clay images cached per size and ring colour, including the selected and new-pin variants.
- [ ] Restyle the map home (S2), with the empty-map speech bubble and the recenter button.
- [ ] Restyle capture (S3), including the place stamp, trip chip, and the "photo becomes pin" save sequence that starts only after the database write.
- [ ] Restyle the moment card (S4) as a polaroid, with swipe, Edit, Delete, and the undo toast.
- [ ] Restyle the edit sheet and placement (S5), replacing the trip dropdown with a chip row.
- [ ] Remove the `BackdropFilter` glass surfaces.

### Success metrics

- `grep -rn "BackdropFilter" lib` -> no output.
- A widget test saves a moment and finds the new pin, with the landing animation running only when animations are enabled.
- Code review finds no colour filter or overlay on any photo widget.

### Visual review stop (P-1)

- [ ] Send Len the Phase 6 screenshots of map, capture, moment card, edit sheet, and placement in both themes, and wait for his approval before Phase 7.

Checkpoint message: `docs(plan): FEAT-003 phase 6 - map, capture, and moment card`

## Phase 7: Trip colours, Trips shelf, trip detail, and trip form

Requirements: REQ-013, REQ-014, REQ-016, S6 to S8
State: Approved - not started

### Tasks

- [ ] Add a nullable `colorKey` text column to `Trips`, bump `schemaVersion` to 2, and add an `onUpgrade` step that adds the column and assigns colours to existing non-Everyday trips in creation order.
- [ ] Regenerate Drift code in its own commit.
- [ ] Assign the next colour to new trips in the repository, and add `colorKey` to the `Trip` model.
- [ ] Draw pin rings and shelf cards in each trip's colour.
- [ ] Replace the Home tab with the Trips shelf (S6), and delete `analytics_charts.dart` and its tests.
- [ ] Restyle trip detail (S7) with a polaroid grid and the options sheet.
- [ ] Rebuild the trip form (S8) as four steps with the colour step.

### Success metrics

- Data tests: a fresh database is at schema 2; a schema 1 database with three trips upgrades and gets colours in creation order; a new trip gets the next colour; Everyday stays null.
- `test -e lib/features/home_tab/analytics_charts.dart` -> false.

Checkpoint message: `docs(plan): FEAT-003 phase 7 - trip colours and shelf`

## Phase 8: Search, News, Settings, and About

Requirements: S9 to S12
State: Approved - not started

### Tasks

- [ ] Restyle Search (S9) with polaroid thumbnails and the staggered results.
- [ ] Restyle News (S10) as postcards, and add a clear loading and empty state in place of the lone dot.
- [ ] Restyle Settings (S11) and add About (S12), both opened from the You sheet.
- [ ] Apply the V8 copy changes everywhere.

### Success metrics

- A widget test finds a visible message on the News tab while loading and when empty.
- Every V8 "current text" string is absent from `lib`.

Checkpoint message: `docs(plan): FEAT-003 phase 8 - search, news, and settings`

## Phase 9: The interactive maya

Requirements: REQ-017 to REQ-021
State: Approved - not started

### Tasks

- [ ] Add the layered maya artwork under `assets/maya/` (placeholder layers until Len's art arrives, per D-2).
- [ ] Build `MayaCompanion` with the poses in M1 to M4 and the gestures in M3, using Flutter transforms and springs.
- [ ] Add the bundled lines file next to `assets/data/news_items.json`.
- [ ] Place the maya only where M2 allows.
- [ ] Add milestone detection (first moment, first in a trip, more than 25 km from every earlier moment), storing the last shown milestone in the existing app metadata.
- [ ] Show the milestone toast with the cheering maya.

### Success metrics

- Widget tests drive tap, repeated taps, long press, and drag and find the expected pose.
- Widget tests find no maya on the map, capture, or moment card.
- The pose enum has no sad, lonely, or waiting value.
- Data tests show each milestone fires once.
- `grep -rni "streak\|consecutive" lib` -> no output.

Checkpoint message: `docs(plan): FEAT-003 phase 9 - interactive maya`

## Phase 10: Dark mode, text scale, motion, performance, and documents

Requirements: REQ-010, REQ-011, REQ-022, REQ-023, REQ-024, REQ-025
State: Approved - not started

### Tasks

- [ ] Review every screen in dark mode against V5 and fix differences.
- [ ] Render goldens at text scale 2.0 and fix any clipping or overlap.
- [ ] Run every screen's tests with `disableAnimations: true`.
- [ ] Prepare the REQ-023 profile-mode check for Len's phone and record it as pending in the evidence log.
- [ ] Archive `docs/DESIGN_SPEC.md` revision 1 to `docs/archive/DESIGN_SPEC-r1.md`, replace `docs/DESIGN_SPEC.md` with a short pointer to FEAT-003, and update `docs/SPEC_INDEX.md`.
- [ ] Update the README "Design" section to describe the clay keepsake look.

### Success metrics

- Text-scale and dark goldens exist for every screen with no clipped text.
- `pubspec.yaml` dependencies match `ba0c56a` except for removed ones.
- `docs/SPEC_INDEX.md` lists FEAT-003 as Implemented with physical-device checks pending.

Checkpoint message: `docs(plan): FEAT-003 phase 10 - polish and documents`

## Recovery

Follow project `AGENTS.md` for the three-attempt limit and immediate blockers.
Missing artwork (D-2) or fonts (P-3) blocks only the tasks that need them; continue other approved work with placeholders and record it in `HANDOFF.md`.
Record unresolved work and attempt counts in the current handoff.
Interrupted or failing work stays uncommitted and the phase stays incomplete.
