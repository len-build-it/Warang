# Verification: FEAT-002

Created: 2026-11-21T17:07:00+08:00
Updated: 2026-11-21T17:15:00+08:00

| Requirement / phase | Check or scenario | Environment and conditions | Actual result | When run | Evidence / limitations |
| --- | --- | --- | --- | --- | --- |
| Baseline (`a85a915` + `cfeccc6`) | `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=feat-002-baseline` | Windows host, Flutter test runner | Passed under stated conditions (`+8: All tests passed!`, 30 PNGs written) | 2026-11-21T16:58:34+08:00 | Committed as `5d679f1 test(evidence): FEAT-002 visual baseline at a85a915`. |
| Phase 1 (REQ-001..004, REQ-013) | Gate 1: `dart format lib test tool` and `dart format --output=none --set-exit-if-changed lib test tool` | Windows host | Passed under stated conditions (`Formatted 53 files (0 changed)`, exit 0) | 2026-11-21T17:00:00+08:00 | - |
| Phase 1 | Gate 2: `flutter analyze` | Windows host | Passed under stated conditions (`No issues found!`) | 2026-11-21T17:01:00+08:00 | - |
| Phase 1 | Gate 3: `flutter test` | Windows host (after removing `build\unit_test_assets` per known Windows issue) | Passed under stated conditions (`+96: All tests passed!`, matches expected 96) | 2026-11-21T17:02:00+08:00 | - |
| Phase 1 | Gate 4: `flutter build apk --debug` | Windows host (after stopping Gradle daemon and removing ignored `build\` per known Windows issue) | Passed under stated conditions (`Built build\app\outputs\flutter-apk\app-debug.apk`, exit 0) | 2026-11-21T17:05:30+08:00 | - |
| Phase 1 | Gate 5: `flutter test tool/ux_screenshots_test.dart --dart-define=UX_LABEL=feat-002-baseline` | Windows host | Passed under stated conditions (6/8 exact pixel match; only clock-dependent `12_capture_dark.png` and `12_capture_light.png` differed by 0.03% / 339px) | 2026-11-21T17:06:27+08:00 | Masked diffs verified by eye in both themes: only the clock digits changed (`4:58 PM` to `5:06 PM`). Deleted `tool/failures/`. |
| Phase 1 | Gate 6: Phase 1 success metrics | Windows host | Passed under stated conditions: services grep `0`, `models.dart` json grep `0`, package imports grep `0`, `pubspec.yaml` deps grep `0`, hand-written `lib/` lines `7720` (<= 7790, down from 8021) | 2026-11-21T17:06:27+08:00 | Direct non-SDK dependencies in `pubspec.yaml`: 14 (down from 17). |
| Phase 2 (REQ-007..011) | Gate 1: `dart format lib test tool` and `--set-exit-if-changed` | Windows host | Passed under stated conditions (`Formatted 53 files (0 changed)`, exit 0) | 2026-11-21T17:12:10+08:00 | - |
| Phase 2 | Gate 2: `flutter analyze` | Windows host | Passed under stated conditions (`No issues found!`) | 2026-11-21T17:12:15+08:00 | - |
| Phase 2 | Gate 3: `flutter test` | Windows host | Passed under stated conditions (`+97: All tests passed!`, matches expected 97) | 2026-11-21T17:12:35+08:00 | Initial run hit pending `sqflite_common_ffi` 10s lock-warning timer in `test/shell_navigation_test.dart`; resolved by memoizing `MapTileStore._opening` and draining `tester.runAsync` in `shell_navigation_test.dart`'s `settle` helper (matching `user_journey_test.dart`). |
| Phase 2 | Gate 4: `flutter build apk --debug` | Windows host | Passed under stated conditions (`Built build\app\outputs\flutter-apk\app-debug.apk`, exit 0) | 2026-11-21T17:13:20+08:00 | - |
| Phase 2 | Gate 5: `flutter test tool/ux_screenshots_test.dart --dart-define=UX_LABEL=feat-002-baseline` | Windows host | Passed under stated conditions (6/8 exact pixel match; only clock-dependent `12_capture_dark.png` and `12_capture_light.png` differed by 0.03% / 372px) | 2026-11-21T17:14:12+08:00 | Masked diffs verified by eye in both themes: only the clock digits changed (`4:58 PM` to `5:14 PM`). Deleted `tool/failures/`. |
| Phase 2 | Gate 6: Phase 2 success metrics | Windows host | Passed under stated conditions: `WarangToggle` `0`, `CREATE TABLE` `3`, `onCreate` `0`, `Uuid` in `photo_store.dart` `0`, `writeValue('activeProfileId'` `1`, `writeValue('everydayTripId'` `1`, hand-written `lib/` lines `7665` (<= 7730) | 2026-11-21T17:14:12+08:00 | Existing test `'LRU eviction removes the oldest tile first'` passed unchanged. |

## Pending physical-device checklist (Len)

Physical-device validation is performed by Len and remains pending until Len supplies results.

- [ ] FEAT-001 physical-device checklist (tracked in [FEAT-001-verification.md](FEAT-001-verification.md)).
