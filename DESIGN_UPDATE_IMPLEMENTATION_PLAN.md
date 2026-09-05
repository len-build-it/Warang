# Implementation Plan: Warang UI Design Update

> **Status:** Phase 2 complete; waiting for confirmation before Phase 3.
> **Target Branch:** Current verified branch `master`; preserve unrelated work.
> **Test Command:** `flutter test`
> **Lint/Check Command:** `flutter analyze`
> **Build Command:** `flutter build apk --debug`
> **Date:** 2026-09-05

## 1. Overview and Len's Toolkit grounding

Redesign Warang as a quiet travel journal with minimal utility screens, compact frosted map controls, and restrained tactile photo and trip cards.
Preserve existing capture, search, storage, navigation, and offline behavior.
This is the active root plan for the user-requested UI update; `docs/IMPLEMENTATION_PLAN.md` remains the historical architecture and commit-protocol reference.

Len's Toolkit v1.1.0 was read from `C:/Users/User/Desktop/PersonalProjects/04-FUN-STUFF/Len's_Toolkit` and linked using `npm link --ignore-scripts --no-audit --no-fund`.
Its workspace setup ran with `len-toolkit --yes`, preserving existing files, and its scaffold was generated with `len-toolkit plan "Warang UI Design Update"`.
The generic scaffold has been adapted to this Flutter app.
The toolkit defines the execution workflow; the visual proposals below come from the agreed Warang direction and repository evidence.

| Verified Toolkit rule | Local source | Application in this plan |
| --- | --- | --- |
| Separate observed facts from assumptions and evaluate four perspectives | `.agents/skills/council/SKILL.md` | Council grounding below |
| Three to five incremental phases | `.agents/skills/implementation-plan/SKILL.md`, Four Iron Rules | Five phases, with UI-0 through UI-4 task IDs |
| Tests and lint pass before completion | Same skill, Verification First | Exact Flutter commands in each phase |
| Ponytail review before checkpoint | Same skill, Phase Lifecycle; `.agents/skills/ponytail/SKILL.md` | No unrequested dependency or speculative abstraction |
| Conventional commits and phase report | Planning skill, Git Commit Every Phase | Small change commits plus recorded phase checkpoint |
| Explicit user sign-off between phases | Planning skill, HARD STOP | Stop after each verified and committed phase |
| One sentence per line, no em dash or agent co-author | `AGENTS.md`, `GEMINI.md` | Plan formatting and execution reporting |

### Council deliberation: material layering

#### Grounding

- **OBSERVED:** Flutter app with an existing token system, shared controls, a three-tab shell, local photos/search, and cached OSM tiles.
- **OBSERVED:** Travel Mode launches first; trip detail currently uses generic image placeholders; capture has existing flat-disc and tap tests.
- **OBSERVED:** Existing remediation guidance keeps unfinished backup, import, Edit, and Share features unavailable.
- **UNVERIFIED:** Proposed glass opacity/blur is readable over every map state and performs well on the target Android device.
- **UNVERIFIED:** Tactile framing improves perceived clarity; verify through rendered screens and user review rather than claiming a usability result.

#### Perspectives and debate

**Devil's Advocate**

- Glass can hide roads or lose icon contrast as the map pans.
- Fixed vertical offsets can collide with navigation, the keyboard, or large text.

**Simplicity Champion**

- Reuse existing shared widgets and Flutter rendering; a new visual package is unnecessary.
- Use existing photos and metadata; passport collections and booking features do not belong in this redesign.

**Security and Reliability**

- Reuse the existing file resolver and missing-image behavior; do not add storage schemas or remote image services.
- Preserve permission handling, save errors, deletion safeguards, and truthful offline notices.

**Architecture and Developer Experience**

- Keep one token system and the current navigation structure.
- A small shared glass surface is justified only for repeated real uses; avoid a configurable material framework.

#### Consensus and tension

The four perspectives support minimal utility surfaces, compact glass controls, and neutral photo framing.
The primary tension is glass elegance versus changing-background readability and rendering cost.
These are a single-agent rapid synthesis of the Toolkit's four lenses, not independent subagent reviews.

#### Verdict

Proceed with clipped, strongly tinted glass and a solid fallback; keep photos and long-form text opaque.
Revisit blur whenever composited contrast fails or profiling shows worse map panning.

## 2. Scope and document authority

Read these local references before editing:

1. Any applicable `AGENTS.md` or `GEMINI.md` present at execution time.
2. `README.md` for the currently advertised product.
3. `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` for unavailable features and safety constraints.
4. `docs/IMPLEMENTATION_PLAN.md`, including section 3's commit protocol.
5. `docs/DESIGN_SPEC.md`, `warang-design-prompt.md`, and `design/warang-canvas.html` for the existing visual identity.
6. The installed Len's Toolkit skills and this root plan.

This user-requested redesign is a scoped visual update.
Its explicit visual changes supersede the older canvas measurements only where stated here; unmentioned visual behavior remains as implemented.
Do not restart historical implementation phases, repeat stale housekeeping instructions, or restore retired features because an older artboard shows them.
Check the current code and working tree first.

Keep the three tabs and their order: Travel Mode, Home, News.
Travel Mode remains the launch tab.
Keep the existing `IndexedStack` and desktop navigation at the current 900 logical-pixel breakpoint.

This work does not include flight or hotel booking, boarding passes, social messaging, passport collections, scratch-off maps, rewards, accounts, sync, new storage models, or new network services.
Date-stamp styling may present existing trip/moment metadata; it must not introduce a collection mechanic or invented visit data.

## 3. Visual direction

| Layer | Apply to | Design rule |
| --- | --- | --- |
| Minimalism | Search, settings, trip creation, caption/save fields, News, summaries | Opaque readable surfaces, explicit labels, clear hierarchy, limited decoration |
| Glassmorphism | Mobile navigation over the map, menu and recenter controls | Compact clipped frosting with a neutral tint and subtle edge; preserve surrounding map visibility |
| Modern skeuomorphism | Trip covers, moment cards, photo thumbnails | Neutral photo border, subtle paper-like framing, shallow shadow, existing date metadata |

Avoid frosted content cards, transparent form fields, leather textures, wood textures, simulated passport pages, glossy buttons, decorative ticket perforations, and large gradients.
Do not tint or filter the user's photographs.

### Brand and starting values

Reuse `lib/app/theme/tokens.dart`; do not introduce a second design system.

| Item | Decision |
| --- | --- |
| Accent | Keep amber `#E8A020`; dark `#231F0E` text/icons on solid amber |
| Neutrals | Keep the existing sage-grey light and dark palettes |
| Fonts | Keep bundled Bricolage Grotesque headings, Public Sans body, DM Mono metadata |
| Surfaces | Keep the existing 14 logical-pixel card radius; circular map controls remain circular |
| Spacing | Retain existing spacing unless a task needs a change; use 8/12/16/24 logical-pixel gaps for new arrangements |
| Text | Existing theme roles first; readable body copy, wrapping titles, secondary metadata with adequate contrast |
| Glass | Initial trial: existing surface tint at 88% light / 90% dark, blur sigma 8, 1-pixel subtle neutral edge |
| Photo framing | Existing surface color, 3–4 logical-pixel border, one shallow shadow; no image overlay texture |

Glass values are starting proposals, not measurements from Len's Toolkit.
Tune them after testing over roads, water, dense labels, and photographs in both themes.
Increase opacity or use a solid surface when contrast fails.
Dark text on a translucent amber selection may need a theme-specific foreground; do not blindly reuse the solid-amber foreground.

Use amber sparingly, following the existing approximate four-accent rule for interface emphasis.
Do not remove real map markers to enforce a numeric color limit.
Preserve the maya mascot's existing limited role in onboarding and empty states.

## 4. Implementation tasks, in order

### Phase 1: UI-0 - Establish the baseline

**Goal:** Establish source guidance, working behavior, screenshots, and passing baseline checks.

### Tasks

- [x] Read the verified Toolkit source mapping above and the installed skill instructions.
- [x] Inspect `git status`; preserve unrelated user changes.
Verify current files instead of assuming old plans describe the working tree.
- [x] Run the existing analyzer and tests; record existing failures separately.
- [x] Capture current light/dark screenshots of Travel Mode, open moment, Home, trip detail, search, and settings.
- [x] Inspect all callers of shared widgets before changing them.
Trace map -> capture -> save -> pin -> moment and Home -> trip detail.

Acceptance: the executor knows the current behavior, applicable guidelines, and visual baseline.
Reproduce and resolve failures with the smallest safe fix before passing the gate; report any externally blocked failure and remain in this phase.

### Verification Gate

- [x] Run `dart format --output=none --set-exit-if-changed lib test` after formatting changed Dart files; exit code 0.
- [x] Run `flutter analyze`; exit code 0.
- [x] Run `flutter test`; exit code 0.
- [x] Run `flutter build apk --debug`; exit code 0.
- [x] Verify the acceptance criteria for this phase and capture light/dark evidence for affected screens.

### Review Gate (Ponytail)

- [x] Review the diff using `.agents/skills/ponytail-review/SKILL.md`.
- [x] Confirm no unrequested packages, speculative abstractions, duplicate styling systems, or unrelated changes.
- [x] Confirm existing behavior, accessibility, and data safeguards remain intact.

### Git Checkpoint

- [x] Follow `docs/IMPLEMENTATION_PLAN.md` section 3: commit each independently reversible change as it becomes green, not one bundled phase diff.
- [x] Stage only specific changed paths, include this plan's completed checkboxes, and use conventional messages such as `refactor(ui): phase 1 - baseline`.
- [x] Use `docs(plan): phase 1 - record UI baseline` for a documentation-only baseline checkpoint.
- [x] Record all actual phase commit hashes; do not add an agent co-author or rewrite history.

Recorded Phase 1 Commits:
- `eb60a1c fix(map): guard tile store queries against closed database`
- `749ba16 fix(ui): prevent RenderFlex overflow in profile and everyday rows`
- `3e12da0 style(format): format dart files to standard style`

### HARD STOP

> **PAUSE HERE.**
> Report completed tasks, verification outputs, screenshots, and commit hashes.
> Do not touch Phase 2 files until the user explicitly confirms continuation.
> This stop comes from `.agents/skills/implementation-plan/SKILL.md`, Four Iron Rules #4: "Execution must halt at the end of each phase."
> Explain that source when requesting the next-phase sign-off.

### Phase 2: UI-1 - Shared surfaces and accessibility

**Goal:** Provide reusable restrained surfaces with readable and accessible controls.

### Tasks

Primary files: `lib/app/theme/tokens.dart`, `lib/app/theme/components.dart`.

- [x] Reuse existing buttons, metadata, settings rows, and theme roles.
Keep changes to the smallest set of shared components needed.
- [x] If multiple controls need identical glass rendering, add one small shared surface widget in the existing components file.
Use Flutter's built-in clipping, backdrop blur, and decoration; add no package.
- [x] Clip blur to the control bounds.
Keep a solid-surface rendering path for high-contrast mode and environments where blur is unsuitable.
- [x] Use supported accessibility signals from the installed Flutter SDK.
Respect reduced motion; do not add looping decorative animation.
- [x] Ensure interactive controls have at least 48 × 48 logical-pixel hit areas, meaningful semantic labels, focus indication, and visible pressed/selected states.

Acceptance: surface styling is consistent in both themes, touch feedback remains visible, and glass can render opaquely without losing controls or layout.

### Verification Gate

- [x] Run `dart format --output=none --set-exit-if-changed lib test` after formatting changed Dart files; exit code 0.
- [x] Run `flutter analyze`; exit code 0.
- [x] Run `flutter test`; exit code 0.
- [x] Run `flutter build apk --debug`; exit code 0.
- [x] Verify the acceptance criteria for this phase and capture light/dark evidence for affected screens.

### Review Gate (Ponytail)

- [x] Review the diff using `.agents/skills/ponytail-review/SKILL.md`.
- [x] Confirm no unrequested packages, speculative abstractions, duplicate styling systems, or unrelated changes.
- [x] Confirm existing behavior, accessibility, and data safeguards remain intact.

### Git Checkpoint

- [x] Follow `docs/IMPLEMENTATION_PLAN.md` section 3: commit each independently reversible change as it becomes green, not one bundled phase diff.
- [x] Stage only specific changed paths, include this plan's completed checkboxes, and use conventional messages such as `refactor(ui): phase 2 - surfaces`.
- [x] Use `docs(plan): phase 1 - record UI baseline` for a documentation-only baseline checkpoint.
- [x] Record all actual phase commit hashes; do not add an agent co-author or rewrite history.

Recorded Phase 2 Commits:
- `5bb8cf8 feat(theme): add WarangGlass tokens for frosted surfaces`
- `ef7606a feat(theme): add glass surfaces and accessible control touch targets`
- `cd8c098 test(ui): add tests for glass surfaces fallback and accessibility targets`

### HARD STOP

> **PAUSE HERE.**
> Report completed tasks, verification outputs, screenshots, and commit hashes.
> Do not touch Phase 3 files until the user explicitly confirms continuation.
> This stop comes from `.agents/skills/implementation-plan/SKILL.md`, Four Iron Rules #4: "Execution must halt at the end of each phase."
> Explain that source when requesting the next-phase sign-off.

## Phase 3: UI-2 - Map and navigation

**Goal:** Apply compact glass overlays while preserving map interaction and fast capture.

### Tasks

Primary files: `lib/app/shell/app_shell.dart`, `lib/features/travel_mode/travel_mode_screen.dart`.
Inspect `lib/features/map/warang_map.dart`; change it only if a necessary presentation issue cannot be fixed in the overlay.

- [ ] Apply the shared frosted treatment to mobile navigation on Travel Mode and compact menu/recenter controls.
Use solid navigation surfaces on content-heavy tabs and the desktop sidebar.
- [ ] Keep navigation labels, order, selection behavior, and tab state.
Make the selected state legible in dark mode and distinguishable beyond color alone.
- [ ] Keep the capture button an opaque amber disc with its existing single-shadow treatment and semantic label.
Add no menu, picker, or decorative delay before capture.
- [ ] Calculate control placement from actual safe insets and occupied navigation height.
Replace affected hardcoded device offsets where needed so capture, recenter, cards, and navigation do not overlap.
- [ ] Keep the map interactive outside overlays; clipping must not create invisible touch-blocking regions.
- [ ] Keep the drawer mostly opaque because it contains text and actions.
Preserve current open/close behavior and feature availability.
- [ ] Preserve map attribution, cache notices, clustering, selection, and location behavior.

Acceptance: launch still opens the map; map gestures work around controls; capture is reachable on short phones; selecting and dismissing a moment works without navigation collisions.

### Verification Gate

- [ ] Run `dart format --output=none --set-exit-if-changed lib test` after formatting changed Dart files; exit code 0.
- [ ] Run `flutter analyze`; exit code 0.
- [ ] Run `flutter test`; exit code 0.
- [ ] Run `flutter build apk --debug`; exit code 0.
- [ ] Verify the acceptance criteria for this phase and capture light/dark evidence for affected screens.

### Review Gate (Ponytail)

- [ ] Review the diff using `.agents/skills/ponytail-review/SKILL.md`.
- [ ] Confirm no unrequested packages, speculative abstractions, duplicate styling systems, or unrelated changes.
- [ ] Confirm existing behavior, accessibility, and data safeguards remain intact.

### Git Checkpoint

- [ ] Follow `docs/IMPLEMENTATION_PLAN.md` section 3: commit each independently reversible change as it becomes green, not one bundled phase diff.
- [ ] Stage only specific changed paths, include this plan's completed checkboxes, and use conventional messages such as `refactor(ui): phase 3 - map-navigation`.
- [ ] Use `docs(plan): phase 1 - record UI baseline` for a documentation-only baseline checkpoint.
- [ ] Record all actual phase commit hashes; do not add an agent co-author or rewrite history.

### HARD STOP

> **PAUSE HERE.**
> Report completed tasks, verification outputs, screenshots, and commit hashes.
> Do not touch Phase 4 files until the user explicitly confirms continuation.
> This stop comes from `.agents/skills/implementation-plan/SKILL.md`, Four Iron Rules #4: "Execution must halt at the end of each phase."
> Explain that source when requesting the next-phase sign-off.

## Phase 4: UI-3 - Tactile memories

**Goal:** Give real photographs and trip memories restrained tactile framing.

### Tasks

Primary files: `lib/features/travel_mode/travel_mode_screen.dart` (`MomentCard`), `lib/features/home_tab/home_tab_screen.dart`, `lib/features/home_tab/trip_detail_screen.dart`.

- [ ] Frame the existing moment photo as a restrained printed photograph: neutral edge, shallow shadow, readable opaque caption/metadata area.
- [ ] Present trip cards as simple journal covers using their real titles, dates, places, and counts.
Keep text horizontal and selectable/readable where appropriate; avoid decorative rotation.
- [ ] Replace generic trip-detail image placeholders with an existing local trip photograph when available.
Reuse the current photo-path resolver/loading pattern; do not persist new cover fields or absolute paths.
- [ ] Use real local thumbnails for existing moment rows where feasible with that same loading pattern.
Missing or unreadable files show a neutral fallback without crashing.
- [ ] Keep Everyday, New trip, summaries, and charts available.
Place memories before analytics and visually subordinate secondary summaries; do not change calculations.
- [ ] Use actual stored metadata for any stamp-like date label.
Do not generate locations, dates, stamps, achievements, or sample user memories.
- [ ] Preserve deletion handling and existing dismissal behavior.
Keep unavailable Edit/Share actions unavailable.

Acceptance: photos lead the hierarchy; long trip names and captions wrap; empty trips and missing images remain usable; no new database or repository behavior is introduced.

### Verification Gate

- [ ] Run `dart format --output=none --set-exit-if-changed lib test` after formatting changed Dart files; exit code 0.
- [ ] Run `flutter analyze`; exit code 0.
- [ ] Run `flutter test`; exit code 0.
- [ ] Run `flutter build apk --debug`; exit code 0.
- [ ] Verify the acceptance criteria for this phase and capture light/dark evidence for affected screens.

### Review Gate (Ponytail)

- [ ] Review the diff using `.agents/skills/ponytail-review/SKILL.md`.
- [ ] Confirm no unrequested packages, speculative abstractions, duplicate styling systems, or unrelated changes.
- [ ] Confirm existing behavior, accessibility, and data safeguards remain intact.

### Git Checkpoint

- [ ] Follow `docs/IMPLEMENTATION_PLAN.md` section 3: commit each independently reversible change as it becomes green, not one bundled phase diff.
- [ ] Stage only specific changed paths, include this plan's completed checkboxes, and use conventional messages such as `refactor(ui): phase 4 - memories`.
- [ ] Use `docs(plan): phase 1 - record UI baseline` for a documentation-only baseline checkpoint.
- [ ] Record all actual phase commit hashes; do not add an agent co-author or rewrite history.

### HARD STOP

> **PAUSE HERE.**
> Report completed tasks, verification outputs, screenshots, and commit hashes.
> Do not touch Phase 5 files until the user explicitly confirms continuation.
> This stop comes from `.agents/skills/implementation-plan/SKILL.md`, Four Iron Rules #4: "Execution must halt at the end of each phase."
> Explain that source when requesting the next-phase sign-off.

## Phase 5: UI-4 - Minimal utility screens and final verification

**Goal:** Simplify utility screens and complete end-to-end visual and functional verification.

### Tasks

Primary files: `lib/features/travel_mode/travel_mode_screen.dart` (`MomentSearchDelegate`), `lib/features/settings/settings_screen.dart`, `lib/features/capture/capture_screen.dart`, `lib/features/news_tab/news_tab_screen.dart`, `lib/features/onboarding/onboarding_screen.dart`.

- [ ] Search: solid background, obvious input and clear action, readable caption/place matches, explicit empty results.
Preserve offline search behavior.
- [ ] Settings: consistent grouped surfaces and spacing; distinguish informational rows from working actions.
Do not give nonfunctional rows a new tappable appearance.
- [ ] Trip creation and capture/save fields: preserve labels, validation, keyboard behavior, save feedback, and error handling; keep optional fields optional.
- [ ] News: maintain the existing bundled content and reading flow; simplify presentation without remote content, promotional placeholders, or new feeds.
- [ ] Onboarding: apply only consistency fixes needed by the shared design updates.
Keep permission/privacy language accurate to the current implementation.

Acceptance: no glass behind dense text or inputs, no hidden labels, no newly advertised unfinished features, and no extra step in the capture journey.

### Verification Gate

- [ ] Run `dart format --output=none --set-exit-if-changed lib test` after formatting changed Dart files; exit code 0.
- [ ] Run `flutter analyze`; exit code 0.
- [ ] Run `flutter test`; exit code 0.
- [ ] Run `flutter build apk --debug`; exit code 0.
- [ ] Verify the acceptance criteria for this phase and capture light/dark evidence for affected screens.

### Review Gate (Ponytail)

- [ ] Review the diff using `.agents/skills/ponytail-review/SKILL.md`.
- [ ] Confirm no unrequested packages, speculative abstractions, duplicate styling systems, or unrelated changes.
- [ ] Confirm existing behavior, accessibility, and data safeguards remain intact.

### Git Checkpoint

- [ ] Follow `docs/IMPLEMENTATION_PLAN.md` section 3: commit each independently reversible change as it becomes green, not one bundled phase diff.
- [ ] Stage only specific changed paths, include this plan's completed checkboxes, and use conventional messages such as `refactor(ui): phase 5 - utility-polish`.
- [ ] Use `docs(plan): phase 1 - record UI baseline` for a documentation-only baseline checkpoint.
- [ ] Record all actual phase commit hashes; do not add an agent co-author or rewrite history.

### HARD STOP

> **PAUSE HERE.**
> Report completed tasks, verification outputs, screenshots, and commit hashes.
> Complete all final verification and handoff items in section 5 before this checkpoint, then present the result for user review and stop; do not start additional work.
> This stop comes from `.agents/skills/implementation-plan/SKILL.md`, Four Iron Rules #4: "Execution must halt at the end of each phase."
> Explain that source when requesting the next-phase sign-off.

## 5. Verification and completion

### Automated checks

Use the installed Flutter toolchain and existing test framework; do not add testing dependencies.
Follow the repository's applicable commit gates and make small independently reversible commits during implementation.
Never stage unrelated files or rewrite history.

```sh
dart format <changed Dart files>
flutter analyze
flutter test
flutter build apk --debug
```

Retain `test/capture_button_test.dart`'s capture tap/semantics and flat-disc expectations, `test/widget_test.dart`'s accent invariant, and the unavailable-actions, identity-assets, News, and data tests.
Do not weaken behavior tests to accommodate styling changes.

Add only focused regression coverage for new behavior: glass-to-solid fallback, safe layout with large text, or navigation interaction if changed.
Prefer extending an existing relevant test; use one small UI test file only if none fits.
Avoid assertions for every decorative constant.

### Visual and interaction matrix

| Check | Cases | Pass condition |
| --- | --- | --- |
| Themes | Light and dark, including selected navigation | Text, icons, focus, and selection remain readable |
| Phone layout | 360 × 640 and existing 390 × 844 baseline | No overflow, obscured actions, or fixed-inset collisions |
| Desktop | Widths immediately below/above 900 and a wider window | Existing navigation transition works and content fits |
| Text/accessibility | Default and 200% text scale, high contrast, reduced motion | Labels remain usable; no decorative motion when disabled |
| Map backgrounds | Dense roads, water, many pins, selected photo | Controls retain contrast and surrounding map remains useful |
| Data | Empty/populated library, long captions, missing images | Honest empty states and robust readable layout |
| Keyboard | Search, New trip, capture fields | Inputs and submit actions stay reachable |
| Core journey | Capture/save, search, select/dismiss, trip open/back, settings | Existing behavior and permission/error handling are preserved |
| Offline | Cached and uncached map areas | Existing truthful cache behavior; local photos/search remain usable |

Target contrast: 4.5:1 for normal text, 3:1 for large text and essential control boundaries/icons.
Check the composited glass result rather than its tint alone.
Use solid surfaces when varying backgrounds prevent reliable contrast.

Profile map panning with overlays visible on an available Android device/emulator in profile mode.
Compare against the baseline; if blur introduces visible stutter or materially worse frame timing, reduce the effect or retain opaque surfaces.
Record the device and observed result; do not claim a performance pass without running it.

Save before/after screenshots under `design/ui-update/` using test/demo data, not private user photographs.
Include Travel Mode empty/populated, open moment, Home, trip detail, search, and settings in both themes.
Inspect screenshots for clipping, overlap, contrast, and hierarchy; iterate before marking a phase complete.

### Gemini handoff report

- [ ] Confirm each Toolkit rule in the source mapping was followed during execution.
- [ ] Mark completed tasks in this plan; leave unverified items unchecked.
- [ ] Update `docs/DESIGN_SPEC.md` to reflect the implemented visual changes and remove superseded conflicting measurements in affected sections.
- [ ] Report changed files, checks actually run, screenshots, performance observations, and remaining limitations.
- [ ] Include the actual per-phase commit log as required by the repository protocol.
- [ ] Do not publish or distribute a release APK as part of this visual update.
  A debug build is validation, not a release artifact.

## 6. Supporting references

These support the visual decisions alongside the verified Toolkit workflow sources in section 1.

- Existing Warang sources listed in section 2 and current Flutter widgets listed per task.
- [NN/g: Glassmorphism - Definition and Best Practices](https://www.nngroup.com/articles/glassmorphism/) - restrained use and legibility over complex backgrounds.
- [Apple: Materials](https://developer.apple.com/design/human-interface-guidelines/materials) - selective use for navigation and controls; adapt the principle to Flutter without attempting to clone platform-specific rendering.

## Execution prompt

> Read `IMPLEMENTATION_PLAN.md`, `AGENTS.md`, `GEMINI.md`, and the referenced local Toolkit skills.
> Execute Phase 1 only, complete its verification and Ponytail review gates, and commit the completed work using the repository protocol.
> Report the completed tasks, check results, evidence, and commit hashes.
> Stop and obtain explicit user confirmation before Phase 2, and repeat this process at every later phase boundary.
> Preserve existing product behavior and use the current Flutter components and tokens.
> Do not mark untested or externally blocked work complete.


