# Verification: AUDIT-001 remediation

Created: 2026-11-27T07:42:00+08:00
Updated: 2026-11-27T07:49:00+08:00

| Requirement / phase | Check or scenario | Environment and conditions | Actual result | When run | Evidence / limitations |
| --- | --- | --- | --- | --- | --- |
| REM-REQ-001 / Phase 1 | `flutter analyze` | Windows, Flutter 3.44.7, Dart 3.12.2 | Passed under stated conditions: `No issues found!` | 2026-11-27T07:41:37+08:00 | Static analysis only. |
| REM-REQ-001 / Phase 1 | `flutter test test/android_hardening_test.dart test/utility_screens_test.dart` | Windows, Flutter 3.44.7, Dart 3.12.2 | Passed under stated conditions: 13 passed, 0 failed | 2026-11-27T07:41:37+08:00 | Verifies `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `requireNotNull(keystoreProperties.getProperty(...))`, and `AboutScreen` showing `Version 1.0.0` without `APP_VERSION`. |
| REM-REQ-001 / Phase 1 | PowerShell syntax check on untracked `scripts/build-and-archive.ps1` | Windows PowerShell AST parser | Passed under stated conditions: `PS1 parse errors: 0` | 2026-11-27T07:40:03+08:00 | Untracked script per D-3; full release APK build and `aapt2`/`apksigner` run not executed here. |
| REM-REQ-001 / Phase 1 | Physical-device map tile loading on a freshly built signed release APK | Physical Android phone | Not run | Pending (Len) | Owned by Len. |
| REM-REQ-002 / Phase 2 | `flutter analyze` | Windows, Flutter 3.44.7, Dart 3.12.2 | Passed under stated conditions: `No issues found!` | 2026-11-27T07:48:44+08:00 | Static analysis only. |
| REM-REQ-002 / Phase 2 | `flutter test test/map_tile_store_test.dart test/map_pins_test.dart test/map_places_test.dart test/map_clusters_and_credit_test.dart test/map_navigation_test.dart` | Windows, Flutter 3.44.7, Dart 3.12.2 | Passed under stated conditions: 42 passed, 0 failed | 2026-11-27T07:48:44+08:00 | Covers fresh-hit zero-HTTP, 304 metadata refresh, timeout/malformed-row resilience, legacy `lastAccessedAt` upgrade, serialized LRU eviction, map pins, places, clusters, credit, and navigation. |

## Phase 1 notes

Changed tracked files:
- `android/app/src/main/AndroidManifest.xml`: added `<uses-permission android:name="android.permission.INTERNET" />`.
- `android/app/build.gradle.kts`: removed stale `TODO` and validated all four `keystoreProperties` entries via `requireKey` using `requireNotNull(keystoreProperties.getProperty(key))`.
- `lib/features/settings/about_screen.dart`: changed `AboutScreen.version` to `String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')`.
- `test/android_hardening_test.dart`: added release manifest permission checks (`INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) and rejected unchecked `keystoreProperties[` casts.
- `test/utility_screens_test.dart`: added `AboutScreen shows Version 1.0.0 by default`.

Changed untracked files (kept untracked per D-3):
- `scripts/build-and-archive.sh`: passed `--dart-define=APP_VERSION=${VERSION}`, cleared stale APKs before build, required exact expected APK filenames, failed on zero APKs, serialized `build-info.json` via Python `json.dumps`, and verified `INTERNET` via `aapt2` and signature via `apksigner` when on PATH.
- `scripts/build-and-archive.ps1`: passed `--dart-define=APP_VERSION=$version`, cleared stale APKs before build, required exact expected APK filenames, checked `$LASTEXITCODE` after `git` calls, and verified `INTERNET` via `aapt2` and signature via `apksigner` when on PATH.
