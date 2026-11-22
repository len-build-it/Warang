# Verification: FEAT-003

Created: 2026-11-21T21:21:00+08:00
Updated: 2026-11-23T06:51:52+08:00

All checks below ran on Len's Windows host with Flutter 3.44.7 (Dart 3.12.2) in the Flutter test runner or the Gradle debug build.
Screenshots come from `tool/ux_screenshots_test.dart` at 390x844 logical, 2x DPR, in both themes.
Map tiles do not load in the test host, so the map renders as its ground colour, and `Codec failed to produce an image` logs are expected.
`12_capture_*` shows the host clock, so its time differs between runs.
No emulator or physical-device check has been run for FEAT-003; REQ-023 and Len's device checks stay pending.

| Requirement / phase | Check or scenario | Environment and conditions | Actual result | When run | Evidence / limitations |
| --- | --- | --- | --- | --- | --- |
| Baseline (`9a5b3f7`) | `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=feat-003-baseline` | Windows host | Passed under stated conditions (`+8: All tests passed!`, 30 PNGs) | 2026-11-21T21:00:00+08:00 | Committed as `0491ab7 test(evidence): FEAT-003 visual baseline at 9a5b3f7`. |
| Phase 1 (REQ-001, REQ-002, REQ-003) | Gate 1: `dart format lib test tool`, then `dart format --output=none --set-exit-if-changed lib test tool` | Windows host | Passed under stated conditions (`Formatted 54 files (0 changed)`, exit 0) | 2026-11-21T21:12:00+08:00 | - |
| Phase 1 | Gate 2: `flutter analyze` | Windows host | Passed under stated conditions (`No issues found!`) | 2026-11-21T21:12:00+08:00 | - |
| Phase 1 | Gate 3: `flutter test` | Windows host | Passed under stated conditions (`+128: All tests passed!`, up from 97) | 2026-11-21T21:13:00+08:00 | 31 new cases in `test/contrast_test.dart`; the old "dividers use the line token" case now asserts hairline for dividers and boundary for controls. |
| Phase 1 | Gate 4: `flutter build apk --debug` | Windows host | Passed under stated conditions (`Built build\app\outputs\flutter-apk\app-debug.apk`, exit 0) | 2026-11-21T21:15:00+08:00 | - |
| Phase 1 | Gate 5: `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=feat-003-phase-1` | Windows host | Passed under stated conditions (`+8: All tests passed!`, 30 PNGs in `docs/evidence/FEAT-001/feat-003-phase-1/`) | 2026-11-21T21:17:00+08:00 | Compared side by side with `feat-003-baseline`. Intended: warmer `ground` and `surface` in both themes; tappable trip cards, fields, and the quiet button now have the darker `boundary` outline; decorative card borders and dividers use the lighter `hairline`; metadata and hints are darker in light theme and lighter in dark theme. Unintended differences: none found. `tool/failures/` was not created. |
| Phase 1 | Gate 6: `grep -rn "Color(0x" lib --include=*.dart \| grep -v "lib/app/theme/"` | Windows host | Passed under stated conditions (no output) | 2026-11-21T21:21:00+08:00 | - |
| Phase 1 | Gate 6: mutation check of `test/contrast_test.dart` | Windows host, `lightFaint` temporarily set back to `#8A8F83`, then `darkFaint` to the old `#767C6D`, each reverted after | Passed under stated conditions (both mutations made the test fail on `inkFaint` pairs) | 2026-11-21T21:10:00+08:00 | Confirms the test guards the old failing value. |
| Phase 2 (REQ-004) | Font source | `curl` from `fonts.googleapis.com/css2` (static TTF instances served from `fonts.gstatic.com`) and `OFL.txt` from `github.com/google/fonts` `ofl/<family>/` | Passed under stated conditions: Bagel Fat One 400, Atkinson Hyperlegible Next 400/600/700, Shantell Sans 500 downloaded; each `OFL.txt` reads "licensed under the SIL Open Font License, Version 1.1" | 2026-11-21T21:22:00+08:00 | fontTools inspection: all five files are static (no `fvar`); Atkinson and Shantell carry `tnum`; Bagel has no `tnum`, so the tabular feature is a no-op there. Licences are bundled as assets next to the fonts. |
| Phase 2 | Gate 1: `dart format lib test tool` and `--set-exit-if-changed` | Windows host | Passed under stated conditions (`Formatted 55 files (0 changed)`, exit 0) | 2026-11-21T21:28:00+08:00 | - |
| Phase 2 | Gate 2: `flutter analyze` | Windows host | Passed under stated conditions (`No issues found!`) | 2026-11-21T21:28:00+08:00 | - |
| Phase 2 | Gate 3: `flutter test` | Windows host | Passed under stated conditions (`+132: All tests passed!`, up from 128) | 2026-11-21T21:29:00+08:00 | New: sentence-case formatting, OFL licence, and Bagel-size cases. Updated only for new text (sentence case) and new font names. `tactile_memories_test.dart` now scrolls to the stat tiles, which the larger type pushed below the lazy list's build extent. Removed a false drift "multiple databases" warning in `data_layer_test.dart` (two separate in-memory databases by design). |
| Phase 2 | Gate 4: `flutter build apk --debug` | Windows host | Passed under stated conditions (`Built build\app\outputs\flutter-apk\app-debug.apk`) | 2026-11-21T21:30:00+08:00 | - |
| Phase 2 | Gate 5: `UX_LABEL=feat-003-phase-2` screenshots | Windows host | Passed under stated conditions (`+8: All tests passed!`, 30 PNGs) | 2026-11-21T21:31:00+08:00 | Compared with phase 1. Intended: Bagel Fat One wordmark and screen titles; Atkinson body, buttons, and titles; every uppercase letter-spaced mono string is now sentence-case `meta` (for example `11.969°N · 121.918°E · 9:31 pm`, `Saving to Everyday`, `6-14 Sep · 2 moments`, `Tue 1 Sep, 4:42 pm`). Unintended: none found. Known test-host limitation, unchanged since the baseline: the moment card shows its photo placeholder because `Image.file` does not decode in this harness. |
| Phase 2 | Gate 6: success metrics | Windows host | Passed under stated conditions: `grep -rn "DM Mono\|Public Sans\|Bricolage" lib pubspec.yaml` no output; `ls assets/fonts` lists only the three families' TTFs and their `-OFL.txt` files; `grep -rn "toUpperCase()" lib` returns only the drawer avatar initial (`warang_drawer.dart`), which is a single capital letter, not a metadata string, and is deleted with the drawer in Phase 5 | 2026-11-21T21:31:49+08:00 | - |
| Phase 3 (REQ-005, REQ-006) | Icon font build: `python design/icons/build_icons.py svg`, then in `design/icons` `npx --yes --node-options="--require=./posix-glob-shim.cjs" fantasticon@3.0.0 --config fantasticon.json`, then `python design/icons/build_icons.py dart` | Windows host, Node 24.14.0, npx 11.9.0, fantasticon 3.0.0 fetched by npx only (nothing added to `pubspec.yaml` or a `package.json`) | Passed under stated conditions (`38 SVGs found`, `Generated build/WarangIcons.ttf`) | 2026-11-21T21:40:00+08:00 | fantasticon 3.0.0 and 4.1.0 both report "No SVGs found" on Windows because `path.join` builds a backslash glob; the committed `posix-glob-shim.cjs` preload fixes it for the build only. A PIL/FreeType render of the TTF (non-zero fill) showed every glyph and its fill layer as drawn. 22 glyphs: the 21 in V7 plus `check`, which C7 chips and the C11 toggle need. |
| Phase 3 | Gate 1: `dart format lib test tool` and `--set-exit-if-changed` | Windows host | Passed under stated conditions (`Formatted 57 files (0 changed)`, exit 0) | 2026-11-21T21:46:00+08:00 | - |
| Phase 3 | Gate 2: `flutter analyze` | Windows host | Passed under stated conditions (`No issues found!`) | 2026-11-21T21:46:00+08:00 | - |
| Phase 3 | Gate 3: `flutter test` | Windows host | Passed under stated conditions (`+134: All tests passed!`, up from 132) | 2026-11-21T21:46:30+08:00 | New `test/icon_semantics_test.dart` walks map, moment card, drawer, search (with and without results), Home, trip detail, News, Settings, and capture. Mutation check: blanking the recenter button's label and tooltip made it fail with `map: IconData(U+0E00D) is tappable but has no label or tooltip`. Icon finders in four tests now use `WarangGlyphs`. |
| Phase 3 | Gate 4: `flutter build apk --debug` | Windows host | Passed under stated conditions (`Built build\app\outputs\flutter-apk\app-debug.apk`) | 2026-11-21T21:47:00+08:00 | - |
| Phase 3 | Gate 5: `UX_LABEL=feat-003-phase-3` screenshots | Windows host | Passed under stated conditions (`+8: All tests passed!`, 30 PNGs) | 2026-11-21T21:47:49+08:00 | Compared with phase 2. Intended: every icon is the clay set (map, suitcase, postcard, compass, polaroid, dial, speech-bubble info, chevron); the selected nav icon fills with amber. Temporary until Phase 5: the drawer button shows `more` (three dots) because the drawer and its menu button are removed in Phase 5. Found and fixed during review: trip-detail rows and search results still used `dd MMM yyyy · h:mm a` (now `formatMomentTime` and `formatDate`), and drawer icons took the light `IconTheme` colour in dark mode instead of `inkSoft`. Remaining Material glyphs that the app cannot replace: the system date-range picker's internal icons (Phase 7 keeps that picker). |
| Phase 3 | Gate 6: success metrics | Windows host | Passed under stated conditions: `grep -rn "Icons\." lib` no output (the class is named `WarangGlyphs` so the check stays literal); icon test passes | 2026-11-21T21:47:49+08:00 | App-bar back and close buttons use the clay glyphs through `ActionIconThemeData`; the trip dropdown uses a turned chevron until Phase 6 replaces it with chips. |
| Phase 4 (REQ-001, REQ-010, Q-1, Q-2) | Gate 1: `dart format lib test tool` and `--set-exit-if-changed` | Windows host | Passed under stated conditions (`Formatted 62 files (0 changed)`, exit 0) | 2026-11-21T22:04:00+08:00 | - |
| Phase 4 | Gate 2: `flutter analyze` | Windows host | Passed under stated conditions (`No issues found!`) | 2026-11-21T22:04:30+08:00 | - |
| Phase 4 | Gate 3: `flutter test` | Windows host | Passed under stated conditions (`+172: All tests passed!`, up from 134) | 2026-11-21T22:05:00+08:00 | New `test/clay_components_test.dart` (38 cases): C4 buttons, C5 fields, C6 stamps, C7 chips, C8 polaroids, C9 sheets, C11 toggles, C12 toasts, and C13 speech bubbles, each in light, dark, and light/dark with `disableAnimations: true`; plus a reduced-motion "no frame scheduled" check and a V2 contrast check (every text colour over 4.5:1 on its tint and on `ground`, over 6:1 on its dark tint, and `ink` over 4.5:1 on every solid fill). Two tests now find `WarangButton` instead of `FilledButton` and `WarangQuietButton`. |
| Phase 4 | Gate 4: `flutter build apk --debug` | Windows host | Passed under stated conditions (`Built build\app\outputs\flutter-apk\app-debug.apk`) | 2026-11-21T22:05:30+08:00 | - |
| Phase 4 | Gate 5: `UX_LABEL=feat-003-phase-4` screenshots | Windows host | Passed under stated conditions (`+8: All tests passed!`, 30 PNGs) | 2026-11-21T22:05:53+08:00 | Compared with phase 3. Intended: screens that already used the shared buttons and toast now get C4 (amber clay `Start`, `Save`, `New trip`, `Create`, `Confirm` with a soft highlight, shade, and warm shadow in light; a flat fill with a rim in dark; quiet buttons keep the `boundary` outline). Nothing else changed. A temporary component gallery (rendered in `tool/`, inspected, then deleted and never committed) found two issues that were fixed before this run: the dark primary label used dark-theme ink (now light-theme ink on every keepsake fill, per V2), and long stamp words touched the dashed ring (now scaled to fit 48 wide). |
| Phase 4 | Gate 6: success metrics | Windows host | Passed under stated conditions: component tests pass in both themes and with `disableAnimations: true`; only screens that used the replaced `WarangPrimaryButton`, `WarangQuietButton`, and `showWarangSnackBar` changed | 2026-11-21T22:05:53+08:00 | `ClaySurface` caches its highlight and shade paths per size, shape, and depth (128-entry cache); `ClayPressable` wraps its animated subtree in a `RepaintBoundary`. |
| Phase 5 (REQ-007, REQ-008, REQ-012) | Gate 1: `dart format lib test tool` and `--set-exit-if-changed` | Windows host | Passed under stated conditions (`Formatted 64 files (0 changed)`, exit 0) | 2026-11-21T22:24:00+08:00 | - |
| Phase 5 | Gate 2: `flutter analyze` | Windows host | Passed under stated conditions (`No issues found!`) | 2026-11-21T22:24:10+08:00 | - |
| Phase 5 | Gate 3: `flutter test` | Windows host | Passed under stated conditions (`+176: All tests passed!`, up from 172) | 2026-11-21T22:24:40+08:00 | Drawer tests moved to the You sheet: modal with back and dimmer, stamps for the counts, and Settings, profile, Search, and About each reached in two taps or fewer. New dock tests: order Map, Trips, capture, News, Search; capture centred on the pill's top edge; selection by fill, weight, and semantics; labels hidden above 160% text with tooltips kept; a left rail at 1200 wide in the same order. Capture test: holding 500 ms opens nothing, and `CaptureScreen` is built in the frame the finger lifts. The search delegate tests now drive `MomentSearchResults`. Tests that tapped `Home` or `Travel Mode` now tap the `Trips` and `Map` dock tabs. |
| Phase 5 | Defects found and fixed | Windows host, widget tests | Fixed under stated conditions | 2026-11-21T22:20:00+08:00 | (1) Cancelling the name editor threw "A TextEditingController was used after being disposed" because the dialog disposed its controller while the dialog was still animating out; this existed in the drawer before FEAT-003 and is fixed by a dialog that owns its controller. (2) The top half of the raised capture button did not take taps because it sat outside the dock's box; the dock's box now includes it, and its empty corners pass touches through. (3) The search field's tap-to-focus area exposed an unlabelled tap node; it is now excluded from semantics. |
| Phase 5 | Gate 4: `flutter build apk --debug` | Windows host | Passed under stated conditions (`Built build\app\outputs\flutter-apk\app-debug.apk`) | 2026-11-21T22:25:00+08:00 | - |
| Phase 5 | Gate 5: `UX_LABEL=feat-003-phase-5` screenshots | Windows host | Passed under stated conditions (`+8: All tests passed!`, 30 PNGs; `05_drawer_*` is now `05_you_sheet_*`) | 2026-11-21T22:25:38+08:00 | Compared with phase 4. Intended: the clay dock with the raised capture button replaces the bottom bar on every tab; the avatar bubble (maya on amber, cropped from `design/warang-maya.png` until the layered art arrives) replaces the menu button; the recenter button is surface clay 16 above the dock; Search is a dock tab with a title and a pill field; the Home tab header reads Trips with no search icon; the You sheet shows the 72 avatar, the name in Bagel, "Only on this phone", three stamps, and Settings and About rows. Found and fixed during review: the avatar crop showed the maya's body instead of its head, and the You sheet divider ran past the card's right edge. Known until Phase 6: the open moment card sits above the dock without dimming it, and the empty-map hint is still the old pill. |
| Phase 5 | Gate 6: success metrics | Windows host | Passed under stated conditions: `test -e lib/app/shell/warang_drawer.dart` false; Settings, About, profile edit, and Search reached from the map in two taps or fewer; capture starts on release; `grep -rn "toUpperCase()" lib` now returns nothing (the drawer initial is gone) | 2026-11-21T22:25:38+08:00 | The user's colour behind the avatar is amber until trips get colours in Phase 7. |
| Phase 6 (REQ-009, REQ-015, S2 to S5) | Gate 1: `dart format lib test tool` and `--set-exit-if-changed` | Windows host | Passed under stated conditions (`Formatted 65 files (0 changed)`, exit 0) | 2026-11-21T22:44:00+08:00 | - |
| Phase 6 | Gate 2: `flutter analyze` | Windows host | Passed under stated conditions (`No issues found!`) | 2026-11-21T22:44:30+08:00 | - |
| Phase 6 | Gate 3: `flutter test` | Windows host | Passed under stated conditions (`+180: All tests passed!`) | 2026-11-21T22:45:00+08:00 | 176 to 180: 4 tests of the removed glass surfaces (`WarangGlassSurface` x3, `WarangGlassIconButton` x1) were deleted with those components; added `test/map_pins_test.dart` (6: C10 sizes and pre-painted discs in both themes with no filter on photos, the new pin dropping with motion, the new pin only fading under reduced motion, the selected pin above a full-size dimmer, and pin pop-away and undo spring-back) and 2 in `moment_actions_test.dart` (swipe between moments, the dock stepping aside); the capture test now checks the saved moment is the map's landing pin. Tests changed only for new text and widgets: place stamps show coordinates one per line, fields are found under their C5 label, and the trip is chosen from chips. |
| Phase 6 | Gate 4: `flutter build apk --debug` | Windows host | Passed under stated conditions (`Built build\app\outputs\flutter-apk\app-debug.apk`) | 2026-11-21T22:45:30+08:00 | - |
| Phase 6 | Gate 5: `UX_LABEL=feat-003-phase-6` screenshots | Windows host | Passed under stated conditions (`+8: All tests passed!`, 30 PNGs) | 2026-11-21T22:45:50+08:00 | Compared with phase 5. Intended: C10 clay pins whose pointer tip now sits on the spot (pins draw about 35 px higher than before); the empty-map speech bubble from the capture button; the moment card as a C9 sheet with a polaroid, place stamp, date, and Edit (secondary) and Delete (danger), with the dock hidden; the edit sheet with C5 fields, a handwritten caption, and trip chips; placement as a sheet with Cancel (secondary) and Confirm (primary) and the moment's own pin at the centre; capture with clay Retake and close pills, a place stamp, a trip chip, and a handwritten caption. Found and fixed during review: the dimmer inside the map was zero-sized and invisible (now full size, with a size check in the test); the empty-map bubble ran close to the recenter button (now wraps at 220); the map showed a light grey ground in dark theme where no tile had loaded, which also affects offline areas on a phone (the map background now uses the theme's land colour). Test-host limits: photos do not decode, so polaroids and pins show their placeholders; map tiles never load. |
| Phase 6 | Gate 6: success metrics | Windows host | Passed under stated conditions: `grep -rn "BackdropFilter" lib` no output; the landing test finds the new pin dropping only when animations are enabled; code review of photo widgets (`WarangPhotoPin`, `WarangPolaroid`, the moment polaroid, the capture photo, search and trip thumbnails) found no `ColorFilter`, tint, or overlay; the only `ColorFiltered` in `lib` is the map tile layer in `warang_map.dart`, which is the unchanged map style | 2026-11-21T22:45:50+08:00 | Removed the dark gradient that was drawn over the top of the capture photo; the clay pills now carry their own contrast. The capture place stamp has three short lines (latitude, longitude, time) scaled to fit 120 by 64. |
| Phase 6 | Defects found and fixed | Windows host, code review and widget tests | Fixed under stated conditions | 2026-11-21T22:40:00+08:00 | Map pins restarted their photo lookup on every rebuild, including every pan frame, so pins could flash empty while panning and each pin decoded the full photo; lookups are now cached per photo, pins use the thumbnail, and decode at pin size (supports REQ-023). |
| Phase 6 | P-1 visual review stop | - | Pending Len's approval | 2026-11-21T22:46:00+08:00 | Phase 7 does not start until Len approves the map, capture, moment card, edit sheet, and placement screenshots in both themes. |
| Phase 6 review fixes | Reproduction | Windows host | Reproduced: `test/phase_six_layout_test.dart` failed 19 of its first 20 cases before any fix | 2026-11-22T22:20:33+08:00 | Measured before the fix: polaroid right edge 356 instead of 370, pin tip under the card at y 422, Cancel 48, pointer tip 3.75 above its point, dock highlight 6 above its icon, recenter 20 from the edge. The bubble-overlap case passed before and guards the wider bubble. Stamp edges, compass, suitcase, sheet edge shade, avatar crop, and dark amber were reproduced and checked by eye in the screenshots, not by a test. |
| Phase 6 review fixes | Gate 1: `dart format lib test tool` and `--set-exit-if-changed` | Windows host | Passed under stated conditions (`Formatted 66 files (0 changed)`, exit 0) | 2026-11-22T22:20:33+08:00 | - |
| Phase 6 review fixes | Gate 2: `flutter analyze` | Windows host | Passed under stated conditions (`No issues found!`) | 2026-11-22T22:20:33+08:00 | - |
| Phase 6 review fixes | Gate 3: `flutter test` | Windows host | Passed under stated conditions (`+203: All tests passed!`, up from 180) | 2026-11-22T22:20:33+08:00 | 23 new cases in `test/phase_six_layout_test.dart`. `icon_semantics_test.dart` had a missed tap that left its News check running on another screen; it now waits for the route and treats a missed tap as a failure. `clay_components_test.dart` changed only for the `bottomSheet` rename. |
| Phase 6 review fixes | Flake check: `flutter test --test-randomize-ordering-seed` 1, 7, 42, 1234, 98765, then `flutter test -j 1` and `-j 12` | Windows host | Passed under stated conditions (203 passed in all 7 runs) | 2026-11-22T22:20:33+08:00 | No missed-tap warnings in the 5 seeded runs. |
| Phase 6 review fixes | Gate 4: `flutter build apk --debug` | Windows host | Passed under stated conditions (`Built build\app\outputs\flutter-apk\app-debug.apk`, exit 0) | 2026-11-22T22:20:33+08:00 | - |
| Phase 6 review fixes | Gate 5: `UX_LABEL=feat-003-phase-6` screenshots | Windows host | Passed under stated conditions (`+10: All tests passed!`, 34 PNGs) | 2026-11-22T22:20:33+08:00 | New: `16_map_pins` (three photo pins and a cluster of two) and `17_pin_selected` (a southern pin moved clear of the card). The harness now uses an in-memory map store and waits longer, so photos decode: polaroids, pins, and the trip cover show photos, and Settings shows the storage total instead of a dash. Compared with the previous Phase 6 renders, other screens differ only by that, the two new glyphs, the avatar crop, the dock alignment, the sheet edges, the top shade, and dark amber clay. The News spinner is caught at a different frame. The top shade is monotonic at x 500 in both themes. `tool/failures/` was not created. Map tiles still never load in the test host. |
| Phase 6 review fixes | Gate 6: Phase 6 success metrics | Windows host | Passed under stated conditions: no `BackdropFilter` in `lib`; the landing test passes; the only colour filter in `lib` is the unchanged map tile filter | 2026-11-22T22:20:33+08:00 | No colour literal outside the theme, no Material icon, and no change to `pubspec.yaml` or `pubspec.lock`. |

## Phase 6 visual review fixes

Recorded: 2026-11-22T22:20:33+08:00
Source: the Phase 6 visual review of 2026-11-22 (8 must-fix items and 8 polish items).

| Item | Change |
| --- | --- |
| 1 Polaroid off centre | The stamp overhangs into the sheet's padding, the polaroid shares the buttons' edges, and the whole top of the stamp takes taps. |
| 2 Pin behind the card | Search and swipe centre the pin in the strip above the card. A tapped pin moves the map only if it would be hidden, so a visible pin still opens without moving the map (T17.18). |
| 3 Everyday chip | Selected is `surfaceRaised`, `ink`, a 2 px `boundary` outline, and the check, in both themes. |
| 4 Placement buttons | Both are 56. |
| 5 Stamps | Round bumps with one on each corner. A three-line stamp is 80 tall. |
| 6 Capture label | "Caption" sits above the field. |
| 7 Compass | Upright two-tone needle with an N tick. |
| 8 Top shade | Fades to its own colour at zero over 80, and steps aside under the moment dimmer. |
| 9 Sheet edges | Only the top edge is lit. |
| 10 Margins | Recenter is 16 from the edge, like the avatar, and 16 above the dock. |
| 11 Speech bubble | One line with the spec's 12 by 8 padding. |
| 12 Empty pin | Photo glyph placeholder, plus a `boundary` edge for Everyday pins in dark. |
| 13 Avatar | Cropped on the face, without the camera or the W, until the D-2 art arrives. |
| 14 Capture close | A pill with an icon and "Close" (S3). |
| 15 Dark amber | Amber clay keeps its highlight and shade. |
| 16 Trips glyph | An upright suitcase with wheels and a tilted sticker. |

Also found and fixed: the dock highlight sat 6 above its icon; pin pointers ended 3.75 above their point; pins and clusters had no screen-reader label; pins did not regroup when the app changed the zoom, which blocked the single-pin screenshot.

Differences from spec revision 1, all from the review, for Len to accept or reject at P-1:

- C4: a secondary button beside a primary is 56 instead of 48.
- C6: a place stamp with three lines is 80 tall instead of 64.
- C7: selected Everyday uses an outline, because a neutral chip has no solid colour.
- C10: Everyday pins have a 1 px `boundary` edge in dark.
- V5: sheets light only their top edge, and amber in dark uses the highlight and shade instead of the rim.

Reported and not changed, both older than FEAT-003 and needing Len's decision:

- Clustering has a 2500 m floor (`_momentMarkers` in `warang_map.dart`). A throwaway widget probe with two moments 2 km apart showed one cluster at zoom 13, 15, and 18, so tapping such a cluster can never reveal its pins.
- The OpenStreetMap attribution button is covered by the dock. The same probe found it at y 758 to 806, inside the dock's box (688 to 844), and not tappable. T17.7 calls attribution a licence obligation.

Not checked: motion (pin landing, pop-away, undo, swipe tilt, placement lift), real map tiles, screen readers on a device, and anything on an emulator or phone.

## Map bug fixes

Recorded: 2026-11-22T22:42:24+08:00
Authority: Len, 2026-11-22 22:28 (Asia/Manila) in the project thread, "okay you can proceed with fixing it", answering "Should I also fix two older map bugs?".
That answer was read as covering the two bugs only; it does not approve P-1 or Phase 7.

| Bug | Change |
| --- | --- |
| Clusters under 2.5 km never split | Pins group only when they would overlap on screen at the current zoom, so they come apart as the map zooms in. The old rule also let pins overlap at low zoom (5.9 px apart in the test). |
| Attribution under the dock | An info button mirrors recenter, 16 above the dock at the bottom left (T17.7). The credit shows without a tap, folds after five seconds, and reopens from the button. |

The clustering fix exposed two placement faults, fixed with it: the moment being placed drew a second pin under the centre pin, and tapping another pin during placement opened it and blocked panning with the dimmer.
On a screen under 500 tall, the empty-map hint waits until the credit folds, because there is no room for both.
The credit follows the [OpenStreetMap attribution guideline](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines), read on 2026-11-22.
The licence address is printed, not linked, because the app has no link-opening dependency.

| Check | Environment | Actual result |
| --- | --- | --- |
| Reproduction with `test/map_clusters_and_credit_test.dart` | Windows host | 12 of the first 14 cases failed before the fix; the placement tap case failed once clusters split |
| Gate 1: format | Windows host | Passed (`Formatted 67 files (0 changed)`, exit 0) |
| Gate 2: `flutter analyze` | Windows host | Passed (`No issues found!`) |
| Gate 3: `flutter test` | Windows host | Passed (`+218: All tests passed!`, up from 203); also 218 in 5 random orders and at `-j 1` and `-j 12` |
| Gate 4: `flutter build apk --debug` | Windows host | Passed (`Built build\app\outputs\flutter-apk\app-debug.apk`) |
| Gate 5: `UX_LABEL=feat-003-phase-6` | Windows host | Passed (`+10: All tests passed!`, 34 PNGs); the nine screens outside Phase 6 are pixel-identical in both themes |
| Gate 6: Phase 6 metrics | Windows host | Passed |

Still open, reported to Len and not changed:

- Moments closer than about 37 m still share a cluster at the top zoom (18), and tapping it does nothing. Opening them needs a change to T17.16, which says a cluster tap never opens a card.
- The offline placeholder tile `_placeholderBytes` in `map_tile_store.dart` is a corrupt PNG (bad IDAT checksum). It causes the `Codec failed to produce an image` logs that earlier entries called expected. Replacing only the bytes would let a blank tile stay in the image cache after the phone reconnects, so the fix also needs an eviction.

Not checked: a phone or emulator, real tiles, and REQ-023 panning smoothness with the new grouping.

## P-1 approval and last Phase 6 fixes

Recorded: 2026-11-23T06:10:23+08:00
Len, 2026-11-23 06:06 (Asia/Manila), project thread: "1. i approve, 2. yes, update the plan 3. yes."

| Change | Check | Actual result |
| --- | --- | --- |
| At full zoom (18) a cluster tap opens its newest moment; below it the tap still zooms, now capped at 18. `docs/IMPLEMENTATION_PLAN.md` T17.16 amended. | `test/map_clusters_and_credit_test.dart` "at full zoom a cluster opens its newest moment" | Failed before the fix (no selection), passes after |
| The offline placeholder tile is a valid transparent PNG and is evicted from the image cache, so the real tile loads after reconnecting. | `test/map_tile_store_test.dart` "an unreachable tile shows blank and is fetched again next time" | Failed before the fix (`Codec failed to produce an image`), passes after |
| Gates 1 to 3 | `dart format`, `flutter analyze`, `flutter test` on the Windows host | Passed: 0 changed, `No issues found!`, `+219: All tests passed!`; `Codec failed` log lines in a full run went from 1655 to 0 |

No screen changed, so `feat-003-phase-6` was not re-rendered.
Not checked on a phone: reconnecting after offline tiles.

## Phase 7 (REQ-013, REQ-014, REQ-016, S6 to S8)

Recorded: 2026-11-23T06:39:27+08:00

| Check | Environment | Actual result | Notes |
| --- | --- | --- | --- |
| Gate 4 for the Phase 6 close at `ebf2d13` | Windows host | Passed (`Built build\app\outputs\flutter-apk\app-debug.apk`) | Run before Phase 7 began. |
| Gate 1: format | Windows host | Passed (exit 0) | - |
| Gate 2: `flutter analyze` | Windows host | Passed (`No issues found!`) | - |
| Gate 3: `flutter test` | Windows host | Passed (`+235: All tests passed!`, up from 219) | New: 5 colour data tests in `data_layer_test.dart` (schema 2, next colour, chosen colour, steady fallback, schema 1 upgrade); `trips_shelf_test.dart` (12). Removed with the charts (D-4): the monthly and cumulative `MemoryStats` assertions. Updated for new text and widgets only: the four-step form in `trips_flow_test.dart` and `utility_screens_test.dart`, the stamps in `tactile_memories_test.dart`, and the uncaptioned moment's date label in `user_journey_test.dart`. |
| Mutation: migration step removed | Windows host | The schema 1 upgrade test failed, then passed once restored | - |
| Gate 4: `flutter build apk --debug` | Windows host | Passed | - |
| Gate 5: `UX_LABEL=feat-003-phase-7` | Windows host | Passed (`+10: All tests passed!`, 36 PNGs) | New `18_trip_colour`. Compared with phase 6: the Trips shelf (stamps, Everyday fan, trip card in its tint, New trip), trip detail band and polaroid grid, the four-step form, coral rings on the trip's pins, and coloured trip chips in the edit sheet. Everything else unchanged. |
| Gate 6: metrics | Windows host | Passed: fresh database at schema 2; schema 1 upgrades and colours trips in creation order; new trips get the next colour; Everyday stays null; `analytics_charts.dart` gone | - |

Notes for Len:

- Creating a trip now takes four steps, as S8 asks, so it costs three more taps than the old single form. Editing goes through the same steps.
- A trip name too long for one line of Bagel drops to two lines of Atkinson, keeping the V3 rule.
- The empty shelf shows the current maya image until Phase 9's maya.
- Drift code was regenerated in the same commit as the schema change, because the migration and the generated table cannot build apart.
- One full test run hung after all tests had finished while some were failing; it did not recur in the next 4 runs.

## Phase 8 (S9 to S12, V8)

Recorded: 2026-11-23T06:51:52+08:00

| Check | Environment | Actual result | Notes |
| --- | --- | --- | --- |
| Gate 1: format | Windows host | Passed (exit 0) | - |
| Gate 2: `flutter analyze` | Windows host | Passed (`No issues found!`) | - |
| Gate 3: `flutter test` | Windows host | Passed (`+238: All tests passed!`, up from 235) | New: News loading and empty messages, postcards with stamps, staggered search results with and without reduced motion. Updated for new text and widgets only: Settings (Saved map areas, the quiet Clear button, the footer), search rows (polaroid, middle dot), About as a page instead of the system dialog, and the You sheet test now checks the dock is unreachable with a hit test instead of a tap that landed on About. |
| Found and fixed | Windows host, widget test | Fixed | Clearing saved map areas called `setState` with a closure that returned a Future, which Flutter rejects; it now assigns inside a block. |
| Gate 4: `flutter build apk --debug` | Windows host | Passed | - |
| Gate 5: `UX_LABEL=feat-003-phase-8` | Windows host | Passed (`+10: All tests passed!`, 38 PNGs) | New `19_about`. Compared with phase 7: Search rows with polaroid thumbnails; News with its loading message (the test host never finishes loading bundled assets, so the postcards themselves are covered by the widget test, not the screenshot); Settings as clay cards with sentence-case labels; About as a page. Everything else unchanged. |
| Gate 6: metrics | Windows host | Passed: the News widget test finds a message while loading and when empty; `grep -rniE` for every V8 "current text" string in `lib` returns nothing | - |

Notes for Len:

- About keeps a Licences button, because the system dialog it replaced was the only way to see the open-source licences, and it now names OpenStreetMap and its licence too.
- News categories in `assets/data/news_items.json` are now in sentence case.
- The maya pictures on Search, News, Settings, and About are the current image until Phase 9.
