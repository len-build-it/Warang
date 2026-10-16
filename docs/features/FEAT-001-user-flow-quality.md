# FEAT-001: User flow quality pass

Created: 2026-10-16T22:45:00+08:00
Updated: 2026-10-16T23:10:00+08:00
Revision: 1
Status: Implemented - physical-device checks pending

## Purpose and success

Warang's screens look finished, but the core journey still has dead ends, false affordances, and visual defects that only show up when the flows are walked end to end.
This feature closes the capture -> moment -> trip loop, makes navigation behave predictably, and fixes the visual defects found in the 2026-10-16 audit.
Success means a user can capture a photo without GPS, see where it went, correct and organize it later, undo a mistaken delete, and navigate back from anywhere without leaving the app by accident.

## Audit method

- Read every screen and the repository under `lib/`, the design spec, and the three existing plans.
- Ran the baseline: `flutter analyze` reported no issues, and `flutter test` passed all 41 tests on 2026-10-16.
- Rendered 24 real screens (12 flows, light and dark) at 390 x 844 with 48/34 safe insets.
  The renders came from a scratch widget harness with the bundled fonts loaded.
  No Android emulator or device was available, so these renders stand in for device screenshots.
- Selected baseline renders live in [`docs/evidence/FEAT-001/baseline/`](../evidence/FEAT-001/baseline/).
- Map tiles cannot load in the test host, so the map shows as an empty ground colour in every render.

## Findings

Severity follows the ui-ux-pro-max priority table: accessibility and touch first, then navigation, then forms and feedback, then polish.

### Critical - broken flows and false states

| ID | Finding | Evidence |
| --- | --- | --- |
| F-01 | Android back exits the app from every state. Back does not close an open moment card or the drawer, and it does not return from Home or News to Travel Mode. | No `PopScope` anywhere in `lib/`; drawer is a custom `AnimatedPositioned` in `travel_mode_screen.dart:241`. |
| F-02 | Delete is instant and has no undo, even though rows are only soft-deleted until the next launch's orphan sweep. | `travel_mode_screen.dart:804`; `photo_store.dart:118` purges the files on the next start. |
| F-03 | User-created trips can never contain moments. The create dialog has no dates, and `findActiveFor` only matches trips that have both dates. There is also no way to move a moment. Every trip shows `NO DATES · 0 MOMENTS` forever. | `home_tab_screen.dart:40`, `daos.dart:69`, render `07_home_light.png`. |
| F-04 | The capture screen promises "Save now, caption later", but no caption, place, or location can be edited after saving. | `capture_screen.dart:285`; the moment card only offers Delete. |
| F-05 | Moments that have coordinates show `NO LOCATION`, because `placeLabel` is never written (geocoding is banned). For the same reason the Places count is always 0 in the drawer and on Home. | Renders `04_moment_open_*.png`, `05_drawer_*.png`, `07_home_light.png`. |
| F-06 | In dark theme the moment dimmer and the drawer scrim use `onSurface` (near-white) at 42%, so they lighten the map instead of dimming it. | `travel_mode_screen.dart:202,235`; render `04_moment_open_dark.png`. |
| F-07 | The floating bottom navigation draws over the open drawer, and the drawer scrim does not cover it. Tabs stay tappable while the drawer is modal. | Render `05_drawer_light.png`, `05_drawer_dark.png`. |
| F-08 | The bundled Public Sans font is lost for most text. `buildWarangTheme` replaces `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `labelMedium`, and `labelSmall` with styles that have no `fontFamily`, so body copy, nav labels, drawer rows, and settings labels fall back to the platform font. | `tokens.dart:166-176`; every tofu-box glyph in the renders marks text without a bundled family. |

### High - truthfulness and feedback

| ID | Finding | Evidence |
| --- | --- | --- |
| F-09 | Settings shows two amber toggles, "Copy caption on share" and "Corner mark on images", for a share feature that does not exist. They are not persisted either. "Clean up · 0 B" is a hard-coded constant. | `settings_screen.dart:113-140,93`; render `11_settings_light.png`. |
| F-10 | A capture saves silently. The user returns to the map with no confirmation, no indication of which trip it went to, and the camera does not move to the new pin. | `travel_mode_screen.dart:59`. |
| F-11 | A save failure shows the raw exception text (`Failed to save photograph: $e`). A permanently denied camera permission shows a snackbar with no route to system settings. | `capture_screen.dart:106`, `travel_mode_screen.dart:50`. |
| F-12 | The capture meta line shows only the time. It never says whether location is still being read, was found, or is unavailable (design spec section 9 requires `NO LOCATION YET · time`). | `capture_screen.dart:259`; render `12_capture_light.png`. |
| F-13 | Trip detail is a static snapshot (it does not update after a delete), and its moment rows do nothing when tapped. There is no way from Home to see a moment on the map. | `home_tab_screen.dart:232`, `trip_detail_screen.dart:76`. |
| F-14 | Clearing the offline map cache has no confirmation, even though it removes offline map coverage. | `settings_screen.dart:174`. |
| F-15 | Onboarding and Settings say "Nothing leaves it" and "Everything stays on this phone", but OpenStreetMap tiles are fetched over the network, which reveals the map area being viewed. | `onboarding_screen.dart:103`, `settings_screen.dart:170`; README Privacy section. |

### Medium - accessibility, consistency, and polish

| ID | Finding | Evidence |
| --- | --- | --- |
| F-16 | The closed drawer stays in the semantics tree off-screen, so TalkBack can focus invisible rows. | `travel_mode_screen.dart:241` keeps the drawer mounted at negative `left`. |
| F-17 | "Clear" in Settings uses amber text on a light surface (about 2:1 contrast, below 4.5:1). | `settings_screen.dart:104`; `lightAccentText` exists for this purpose. |
| F-18 | Default `Divider()` renders in full ink because the colour scheme does not set `outlineVariant`. The drawer divider is a stark black or white rule. | `tokens.dart:122`; render `05_drawer_*.png`. |
| F-19 | Home "Moments" counts only the last six months, while the drawer counts all moments. "Streak" contradicts the design guardrail "No gamification. No points, streaks, badges". The drawer "Trips" count includes Everyday (it shows 2 for one user trip). | `home_tab_screen.dart:343,353`, `DESIGN_SPEC.md` section 14, render `05_drawer_light.png`. |
| F-20 | Search and Settings are reachable only through the Travel Mode drawer. Home has no route to search its own memories. | `travel_mode_screen.dart:401`. |
| F-21 | The moment card shows a drag handle that cannot be dragged. Its photo area is blank while the image decodes, with no placeholder. | `travel_mode_screen.dart:700,738`. |
| F-22 | The map layers menu offers "Your moments", "Clusters", and a disabled "Base map". Turning off "Clusters" hides grouped photos, so pictures disappear with no explanation. | `warang_map.dart:111-131`. |
| F-23 | Home uses a hard-coded 108 px bottom inset instead of `WarangLayout.navigationHeight`. The solid nav shadow (offset -4, blur 18) reads as a grey band above the bar on Home and News. | `home_tab_screen.dart:157`, `app_shell.dart:121`; render `07_home_light.png`. |
| F-24 | Settings recreates its storage futures on every rebuild, so sizes flash `0 B`. Its profile row shows only an initial, while the drawer shows the avatar photo, and the name cannot be edited from Settings. | `settings_screen.dart:87,192`. |
| F-25 | The Storage card has no divider between its two rows, unlike every other settings card. | Render `11_settings_light.png`. |

### Clean Architecture assessment

Observed facts:

- Widgets construct infrastructure directly: `PhotoStore()` in five screens, `MapTileStore()` in the map and Settings, plus `ImagePicker`, `Permission`, and `Geolocator`.
  `main.dart` already builds a configured `PhotoStore`, but most screens ignore it.
- The capture use case (import the photo, then insert the moment) lives in `CaptureScreen._save`, with no cleanup if the insert fails.
- Pure policy is buried in widgets: the analytics snapshot, place counting (duplicated in the drawer and Home), and moment metadata formatting.
- Selection and tab state are private widget state, so Home, trip detail, and search cannot ask the map to show a moment.
- `WarangRepository` is a `ChangeNotifier` facade that mixes row mapping with application actions.
  For an offline, single-user app of this size, this is an acceptable partial boundary.

Proposed direction (lightest enforceable boundary, no rewrite):

- Wire `PhotoStore` and `MapTileStore` once in the composition root (`main.dart`) and expose them through Riverpod providers.
- Move capture orchestration into a repository method with failure cleanup, so the screen only collects input.
- Lift the selected moment and the current tab into providers, so any screen can say "show this moment on the map".
- Extract pure Dart functions (memory stats, place and coordinate formatting, active-trip rule) into `lib/core/` with plain unit tests.
- Do not add a use-case layer, a generic service locator, or new packages.

## Scope and non-goals

In scope: findings F-01 to F-25, plus the parts of remediation Phase 4A, 4B (edit and manual location), 4C, and the Phase 6 settings items that these findings cover.

Out of scope:

- Sharing, backup and restore, and `.travelbook` import/export.
  These stay under `docs/REMEDIATION_IMPLEMENTATION_PLAN.md` and its hard stops.
- A nearby-moment pager.
- Geocoding, new network services, accounts, sync, or new dependencies.
- Any schema change.
  Every requirement below uses existing columns (`caption`, `placeLabel`, `latitude`, `longitude`, `tripId`, `startDate`, `endDate`, `deletedAt`).
- Release signing and physical-device distribution.

## User flows

1. **Capture:** tap capture -> camera -> the meta line shows `LOCATING… · 4:42 PM`, then the coordinates or `NO LOCATION YET` -> it shows `SAVING TO <TRIP>` -> Save -> back on the map, the camera moves to the new pin and a floating snackbar says `Saved to <trip>`.
   - Camera permission denied: snackbar explains the reason. When the denial is permanent, it offers "Open settings".
   - Save fails: the photo is kept, a plain message appears, and Retry is offered. No raw exception text is shown.
2. **Review and correct:** tap a pin or search result -> the moment card shows the place label, or the coordinates, or `NO LOCATION` -> Edit opens a sheet with caption, place name, and trip -> "Place on map" enters a crosshair mode, and Confirm writes the map-centre coordinates.
3. **Delete:** Delete -> the card closes -> the snackbar shows "Moment deleted" with Undo, which restores the moment.
4. **Organize:** New trip -> name, optional place, optional date range (start must be on or before end) -> captures dated inside that range, inclusive of the whole end day, go to the trip -> trip detail stays live, and tapping a moment switches to Travel Mode and opens it -> edit or delete the trip, and deleting moves its moments to Everyday.
5. **Navigate:** Back closes, in order: an open sheet or dialog, the drawer, the placement mode, the open moment, then a non-map tab (returns to Travel Mode), and only then exits.
   The drawer covers the bottom navigation, and Search is also reachable from the Home header.

## Requirements and acceptance criteria

| ID | Required behavior | Observable pass/fail criterion |
| --- | --- | --- |
| REQ-001 | Every theme text style uses a bundled family. | A test asserts that every `TextTheme` style from `buildWarangTheme` has a non-null `fontFamily` in both brightnesses; Public Sans for body and label roles. |
| REQ-002 | Scrims and dimmers darken in both themes. | A test asserts that the moment dimmer and drawer scrim colours have luminance below 0.1 in dark theme; dark render shows a darkened map. |
| REQ-003 | Dividers and text buttons meet the token rules. | `outlineVariant` equals the line token; the Settings "Clear" foreground is `accentText`, which has a contrast of at least 4.5:1 on surface (asserted by a test). |
| REQ-004 | Back behaves predictably (flow 5). | Widget tests: back with a moment open deselects it; back with the drawer open closes it; back on Home or News selects Travel Mode; back on Travel Mode with nothing open lets the route pop. |
| REQ-005 | The drawer is modal over the whole shell. | With the drawer open, tapping the Home nav item does not change the tab; the closed drawer exposes no semantics nodes. |
| REQ-006 | Selection is app state. | Selecting a moment from search, from trip detail, or after capture opens it on Travel Mode, switching tabs when needed (widget test from trip detail). |
| REQ-007 | Capture saves robustly. | Repository test: when the moment insert fails after the photo is stored, the stored files are deleted and the error surfaces; widget test: the failure message has no exception text and offers Retry, and the photo stays on screen. |
| REQ-008 | Capture states are visible. | Widget tests cover the meta line for locating, located (coordinates), and unavailable (`NO LOCATION YET`); a `SAVING TO <TRIP>` line names the trip the active-trip rule resolves. |
| REQ-009 | Saves are confirmed. | After a save, a floating snackbar `Saved to <trip>` appears above the navigation, and the map is asked to move to the new moment when it has coordinates. |
| REQ-010 | Denied camera permission is recoverable. | A permanently denied status shows an "Open settings" snackbar action (test through an injectable permission seam). |
| REQ-011 | Location never reads as missing when it exists. | The moment card shows the place label, otherwise coordinates formatted as `11.969°N · 121.918°E`, otherwise `NO LOCATION`; unit test for the formatter. |
| REQ-012 | Moments can be edited. | Repository tests: the caption, place label, and trip update and persist, and an empty caption or place clears to null; widget test: the Edit sheet saves and the card reflects the change. |
| REQ-013 | Location can be added manually. | Placement mode writes the map-centre coordinates on Confirm and leaves the moment unchanged on Cancel or Back (widget test). |
| REQ-014 | Delete is undoable. | Repository test: restore clears `deletedAt`; widget test: Delete shows an Undo snackbar, and Undo brings the moment back. |
| REQ-015 | Trips can receive moments. | A dated trip receives captures from 00:00 on its start day through 23:59:59.999 on its end day (boundary tests); trip creation rejects end before start; a moment can be moved between trips. |
| REQ-016 | Trips can be maintained. | Edit changes the title, place, and dates; Delete asks for confirmation, soft-deletes the trip, and moves its moments to Everyday (repository test); Everyday cannot be edited or deleted. |
| REQ-017 | Trip detail is live and navigable. | Deleting a moment elsewhere updates an open trip detail; tapping a row opens that moment on Travel Mode. |
| REQ-018 | Stats are honest and non-gamified. | Moments is the total; Streak is replaced by Days (distinct capture days); the drawer Trips count excludes Everyday; Places counts distinct user place labels. |
| REQ-019 | Settings shows only working controls. | No Sharing section; no Clean up row; storage sizes do not flash `0 B` on rebuild; Clear asks for confirmation; the profile row shows the avatar and opens the name editor. |
| REQ-020 | Privacy copy is accurate. | Onboarding, Settings, and the README say that OpenStreetMap tiles are downloaded and that photos, pins, and the name stay on the phone; no "Nothing leaves it" claim remains. |
| REQ-021 | No false affordances on the map or card. | The layers menu is removed; the moment card handle dismisses the card on a downward drag; the photo shows a neutral placeholder until it decodes. |
| REQ-022 | Search is reachable from Home. | The Home header has a search action that opens the same search; a selected result opens on Travel Mode. |
| REQ-023 | Layout uses measured insets. | Home bottom padding uses `WarangLayout.navigationHeight`; the solid nav shadow no longer draws a band (render check in both themes). |

## Data and interfaces

The schema does not change.
New repository methods: `captureMoment`, `updateMoment`, `setMomentLocation`, `restoreMoment`, `moveMoment`, `updateTrip`, `deleteTrip`.
New providers: `photoStoreProvider`, `mapTileStoreProvider`, `selectedMomentProvider`, `shellTabProvider`.
The active-trip rule moves to a pure function in `lib/core/` and is used by both the DAO query and the capture preview.

## Quality constraints

- Follow `AGENTS.md`: no new dependencies, no em dash, one sentence per line in Markdown, and no agent co-author on commits.
- Keep the design guardrails: amber at most four times per screen, never white on amber, no maya on the map, and no gamification.
- Every interactive control keeps a 48 x 48 hit area and a semantic label.
- Respect `MediaQuery.disableAnimations` for any new motion.

## Council decision record

Single-agent synthesis of the four Council lenses; no independent subagents were used.

**Observed facts:** the findings above, the green baseline (analyze clean, 41 tests), soft delete plus a next-launch purge, no geocoding, and existing remediation tasks that overlap with 4A, 4B, 4C, and 6.

**Unverified assumptions:** the renders match an Android device closely enough for layout and colour (fonts excepted); the users want trips assigned by date rather than by an explicit "start trip now" toggle.

| Decision | Devil's advocate | Simplicity | Security and reliability | Architecture | Proposed |
| --- | --- | --- | --- | --- | --- |
| Delete safety | Undo can be missed; a confirm dialog is the conventional guard. | Undo adds no step to every delete. | Rows are recoverable until the next launch's sweep, so an in-session undo is genuinely safe. | `restoreMoment` mirrors `softDeleteMoment`. | Undo snackbar for 6 s, floating above the navigation. Confirmation dialogs stay for trip delete and cache clear, which cannot be undone in place. |
| Drawer | Moving it changes tested behavior and the spec's custom geometry. | `Scaffold.drawer` already provides modal scrim, back handling, semantics, and edge swipe. | The custom drawer leaks off-screen semantics. | Hosting it at `AppShell` lets it cover the navigation. | Use `Scaffold.drawer` on the shell scaffold with width 82%, a dark scrim token, and a 24 px edge drag. Only Travel Mode shows the hamburger. |
| Missing place names | Coordinates feel technical. | No geocoding is allowed, so only coordinates and user labels are honest. | No network call. | A pure formatter in `core/`. | Show coordinates in the mono voice, and let Edit add a place name. |
| Trip assignment | Date ranges may confuse users who travel on short notice. | Date ranges reuse the existing `findActiveFor` rule and columns. | The current inclusive end date is a midnight boundary bug once real dates exist. | One pure rule shared by the query and the capture preview. | Optional date range at creation with an inclusive end day, visible `SAVING TO` on capture, and manual move. |
| Layers menu | Some users may want to hide pins. | Three toggles, one of them disabled, for little value. | None. | Less state in the map widget. | Remove it, pending Len's confirmation, because it is an existing feature. |
| Clean up row | Remediation Phase 6 asks to make it real. | The sweep already runs on every launch, so the reclaimable size is almost always 0. | None. | No duplicate entry point. | Remove the row and mark that remediation task as resolved by removal, pending Len's confirmation. |
| Streak stat | Plan Part IV listed a capture streak. | A neutral count replaces it at no cost. | None. | The design spec guardrail outranks the old plan wording on what screens show. | Replace Streak with Days. |
| Architecture depth | A full use-case layer would be cleaner on paper. | Providers plus a few repository methods solve the testability gaps. | Capture cleanup belongs below the UI. | Partial boundaries fit an offline single-user app. | Composition-root providers, repository methods, and pure `core/` functions only. |

**Unresolved trade-offs:** coordinates versus a friendlier "Pinned" label; whether Home should also get a hamburger. Both can be revisited after a device review.

**Revisit when:** a geocoding-free place dataset is bundled, sharing ships (the share toggles return with it), or device testing shows that the undo snackbar is missed.

## Open questions and readiness

All open questions were resolved by Len in chat on 2026-10-16 ("approved, go ahead with all four decisions"):

1. The map layers menu is removed (REQ-021) and the Clean up row is removed (REQ-019).
2. Streak is replaced with Days (REQ-018).
3. The privacy copy states that OpenStreetMap tiles are downloaded (REQ-020).

Readiness: approved revision 1.
