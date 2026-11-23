# Verification: AUDIT-001

Created: 2026-11-24T07:13:00+08:00
Updated: 2026-11-24T07:13:00+08:00

| Requirement / phase | Check or scenario | Environment and conditions | Actual result | When run | Evidence / limitations |
| --- | --- | --- | --- | --- | --- |
| Phase 0 / baseline | `git log --oneline -1` and `git status --short` | Windows 11, inner repo `Warang` | Passed under stated conditions: HEAD is `7d6703f docs(plan): FEAT-004 phase 8 - polish and documents`; working tree has only Len/GPT's unstaged edit to `docs/SPEC_INDEX.md`, untracked `docs/plans/AUDIT-001-implementation.md`, and preserved untracked paths | 2026-11-24T07:11:20+08:00 | Baseline commit `7d6703f` confirmed |
| Phase 0 / baseline | `flutter --version` | Windows 11, Flutter SDK stable | Passed under stated conditions: `Flutter 3.44.7` (revision `84fc5cbb22`), `Dart 3.12.2`, `DevTools 2.57.0` | 2026-11-24T07:11:21+08:00 | Recorded in report header and inventory |
| Phase 0 / baseline | `flutter analyze` | Windows 11, `Warang` at `7d6703f` | Passed under stated conditions: `No issues found! (ran in 5.6s)` | 2026-11-24T07:11:28+08:00 | Zero analyzer issues at baseline |
| Phase 0 / baseline | `flutter test` | Windows 11, `Warang` at `7d6703f` | Passed under stated conditions: `00:39 +329: All tests passed!` (329 passed, 0 failed) | 2026-11-24T07:12:12+08:00 | OSM tile policy warnings printed to stdout during widget map tests |
| Phase 0 / inventory | `00-inventory.txt` generation | Windows 11, Python 3 stdlib + git + dart/flutter pub | Passed under stated conditions: 49 hand-written `lib/` files (15080 lines), 91 tracked non-`.g.dart` files across `lib/`, `test/`, `tool/` (24983 lines), 13 direct non-SDK dependencies, 5 direct non-SDK dev dependencies, 30 largest tracked files listed | 2026-11-24T07:13:00+08:00 | [00-inventory.txt](../audits/AUDIT-001/scans/00-inventory.txt); `sqlite3_flutter_libs` reported as `0.6.0+eol` by `flutter pub outdated` |
| Phase 0 / Gate 1 | `git status --porcelain -- lib test tool android ios assets design pubspec.yaml pubspec.lock analysis_options.yaml` | Windows 11, `Warang` | Passed under stated conditions: empty output | 2026-11-24T07:13:30+08:00 | No product files changed |
| Phase 0 / Gate 2 | Verify `test/_audit_probe/` and `tool/failures/` do not exist | Windows 11, `Warang` | Passed under stated conditions: neither directory exists | 2026-11-24T07:13:30+08:00 | Clean |
| Phase 0 / Gate 3 | Em-dash / en-dash check script | Windows 11, Python 3 | Passed under stated conditions: `0` | 2026-11-24T07:13:30+08:00 | Checked across `docs/audits`, `docs/plans/AUDIT-001-implementation.md`, `docs/evidence/AUDIT-001-verification.md` |

Use Not run, Passed under stated conditions, Failed, or Blocked.
Record actual commands or repeatable scenarios, not just conclusions.
Attach screenshots for meaningful UI checks when capture is available.
Keep emulator, physical-device, hardware-bench, and field validation distinct.
Len performs physical-device checks; keep them pending until Len supplies results.
Neither implementation nor a simulation establishes effectiveness in the intended environment.
