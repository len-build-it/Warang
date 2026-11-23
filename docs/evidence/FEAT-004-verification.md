# Verification: FEAT-004

Created: 2026-11-23T21:18:00+08:00
Updated: 2026-11-23T21:18:00+08:00

All checks below ran on Len's Windows host with Flutter 3.44.7 (Dart 3.12.2) in the Flutter test runner or the Gradle build.
Screenshots come from `tool/ux_screenshots_test.dart` at 390x844 logical, 2x DPR, in both themes.
Map tiles do not load in the test host, so the map renders as its ground colour, and `Codec failed to produce an image` logs are expected.
No emulator or physical-device check has been run for FEAT-004; Len's physical-device checks stay pending until Phase 8 is complete and Len runs them.

| Requirement / phase | Check or scenario | Environment and conditions | Actual result | When run | Evidence / limitations |
| --- | --- | --- | --- | --- | --- |
| Phase 0 (Documents) | Commit approved FEAT-004 documents alone | Windows host, `Warang` repo on `master` | Passed under stated conditions (`e4539d6 docs(spec): FEAT-004 places, search, and stamps`, 7 files) | 2026-11-23T21:08:30+08:00 | Preserved all untracked paths. |
| Phase 0 (Baseline screenshots) | `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=feat-004-baseline` | Windows host | Passed under stated conditions (38 PNGs in `docs/evidence/FEAT-001/feat-004-baseline/`) | 2026-11-23T21:11:00+08:00 | Committed alone as `c22ec04 test(evidence): FEAT-004 visual baseline at e4539d6`. `tool/failures/` was not created. |
| Phase 0 (REQ-003 baseline APK) | `flutter build apk --release --split-per-abi` | Windows host, Gradle `assembleRelease` | Passed under stated conditions (`app-arm64-v8a-release.apk` = `25102014` bytes / 23.9 MB) | 2026-11-23T21:15:20+08:00 | Baseline for REQ-003 (arm64 APK growth must be at most 25 MB / 26,214,400 bytes above `25102014` bytes). |
| Phase 0 (Baseline gates) | `dart format --output=none --set-exit-if-changed lib test tool`, `flutter analyze`, `flutter test` | Windows host | Passed under stated conditions (73 files formatted 0 changed, `No issues found!`, `+267: All tests passed!`) | 2026-11-23T21:17:40+08:00 | `git status --short docs` shows only the pre-existing untracked `docs/evidence/FEAT-001/claude-review/`. |
