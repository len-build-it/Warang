# Verification: FEAT-001

Created: 2026-10-16T22:55:00+08:00
Updated: 2026-10-16T22:55:00+08:00

| Requirement / phase | Check or scenario | Environment and conditions | Actual result | When run | Evidence / limitations |
| --- | --- | --- | --- | --- | --- |
| Baseline | `flutter analyze` | Windows 11, Flutter 3.44.7 stable, commit `dc407c5` | Passed: `No issues found!` | 2026-10-16 | The first run failed because Flutter could not delete the ignored `ios/Flutter/ephemeral/Packages/.packages`; it passed after that generated directory was removed. |
| Baseline | `flutter test` | Same | Passed: 41 tests | 2026-10-16 | Terminal output only. |
| Baseline | Screen renders, 12 flows in light and dark | Scratch widget harness, 390 x 844, 2x DPR, 48/34 safe insets, bundled fonts loaded | Passed under stated conditions: 24 renders produced | 2026-10-16 | Selected renders in [`FEAT-001/baseline/`](FEAT-001/baseline/). Map tiles cannot load in the test host. Glyphs drawn as boxes mark text styles with no bundled font family (finding F-08). Full-size photos and the bundled News asset did not finish decoding in the harness, so those areas are not evidence of a defect. |
| Phase 1 | Gates: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, `flutter build apk --debug` | Windows 11, Flutter 3.44.7 | Passed: format clean, no analyzer issues, 50 tests, debug APK built | 2026-10-16 | Theme font, scrim, divider, accent text, inset, and shadow fixes; 9 new theme tests. |
| Phase 1 | `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=phase-1` | Widget renders, 390 x 844, light and dark | Passed under stated conditions | 2026-10-16 | [`FEAT-001/phase-1/`](FEAT-001/phase-1/). Body copy now renders in Public Sans; the dark moment dimmer darkens the map. Noted for later phases: Settings About block is centred, storage size reads 0 B, and full-size photos stay blank in the harness. |
| Physical device | Back gesture, TalkBack, keyboard, GPS, fonts | Android phone | Not run | - | Len performs physical-device checks. |
