# Current handoff

Created: 2026-10-16T22:55:00+08:00
Updated: 2026-11-27T07:49:00+08:00
State: AUDIT-001 remediation Phases 1-2 complete, Phases 3-6 in progress; AUDIT-001 Phases 0-4 complete and report revision 2 re-verified by Gemini (51 findings, 0 app files changed); FEAT-004 Phases 0-8 complete, physical-device checks pending; FEAT-003 Phases 1-10 complete, physical-device checks and D-2 art pending; FEAT-001 and FEAT-002 physical-device checks pending
Feature: AUDIT-001 remediation (plan revision 2, approved); AUDIT-001 code quality audit report (plan revision 1, complete; report revision 2); FEAT-004 places, place search, and category stamps (spec and plan revision 1, approved); FEAT-003 clay keepsake redesign (spec and plan revision 1)

## Read first

- [AGENTS.md](AGENTS.md), [GEMINI.md](GEMINI.md), and [CLAUDE.md](CLAUDE.md)
- [docs/SPEC_INDEX.md](docs/SPEC_INDEX.md)
- [docs/DESIGN_SPEC.md](docs/DESIGN_SPEC.md) and [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) (architecture; T17 keeps the tile cache in `sqflite`)
- [docs/features/FEAT-003-clay-keepsake-redesign.md](docs/features/FEAT-003-clay-keepsake-redesign.md) (replaces `docs/DESIGN_SPEC.md` for appearance once implemented) and [docs/plans/FEAT-003-implementation.md](docs/plans/FEAT-003-implementation.md)
- [docs/features/FEAT-004-places-search-stamps.md](docs/features/FEAT-004-places-search-stamps.md) and [docs/plans/FEAT-004-implementation.md](docs/plans/FEAT-004-implementation.md) (approved; execute from Phase 0)
- [docs/research/RES-002-place-search-categories-progression.md](docs/research/RES-002-place-search-categories-progression.md) (background research, decided)
- [docs/research/RES-001-clay-motion-genz.md](docs/research/RES-001-clay-motion-genz.md) (background research, not a spec)
- [docs/features/FEAT-002-ponytail-cleanup.md](docs/features/FEAT-002-ponytail-cleanup.md)
- [docs/plans/FEAT-002-implementation.md](docs/plans/FEAT-002-implementation.md)
- [docs/audits/AUDIT-001-code-quality-report.md](docs/audits/AUDIT-001-code-quality-report.md) and [docs/plans/AUDIT-001-implementation.md](docs/plans/AUDIT-001-implementation.md) (verified code quality audit report; 51 findings grouped into 6 remediation batches)
- [docs/plans/AUDIT-001-remediation-implementation.md](docs/plans/AUDIT-001-remediation-implementation.md) (approved remediation plan revision 2; execute from Phase 1)

Reread these files and inspect actual Git status before acting; prior chat memory is not authoritative.

## Approval and allowed work

| Document | Approved revision or commit | Actual Len chat approval reference |
| --- | --- | --- |
| FEAT-001 feature spec | Revision 1 | 2026-10-16 chat: "approved, go ahead with all four decisions" |
| FEAT-001 plan | Revision 1 | 2026-10-16 chat: "approved, go ahead with all four decisions" |
| FEAT-002 feature spec (includes D-1, D-2) | Revision 1 | 2026-11-21 chat: "I, Len, approve FEAT-002 revision 1 (docs/features/FEAT-002-ponytail-cleanup.md) and its plan revision 1 (docs/plans/FEAT-002-implementation.md), including decisions D-1 and D-2." |
| FEAT-002 plan | Revision 1 | 2026-11-21 chat: "I, Len, approve FEAT-002 revision 1 (docs/features/FEAT-002-ponytail-cleanup.md) and its plan revision 1 (docs/plans/FEAT-002-implementation.md), including decisions D-1 and D-2." |
| FEAT-003 feature spec (includes D-1 to D-6 as recommended) | Revision 1 | 2026-11-21 20:37 project-thread decision card: "Approve as recommended" on "Approve FEAT-003 revision 1 with the recommended answers to D-1 to D-6?" |
| FEAT-003 plan (includes P-1 to P-3 as recommended) | Revision 1 | 2026-11-21 20:40 project-thread decision card: "Approve plan as written" on "Approve FEAT-003 plan revision 1 with P-1 to P-3 as recommended?" |
| FEAT-003 P-1 visual approval, T17.16 amendment, offline tile fix | Phase 6 at `c1f7163` | 2026-11-23 06:06 project thread: "1. i approve, 2. yes, update the plan 3. yes." |
| FEAT-003 map bug fixes (clustering, attribution) only; not P-1 | - | 2026-11-22 22:28 project thread: "okay you can proceed with fixing it", answering "Should I also fix two older map bugs?" |
| RES-002 recommendations and the rule overrides in FEAT-004 "Relationship to existing documents" | RES-002 draft of 2026-11-23 19:20 | 2026-11-23 19:29 project thread: "go with recommendation for all of your questions. use /council skill when youre having a hardtime. override the original doc rules in order to push this features. then come up with an implementation plan gemini can execute" |
| FEAT-004 feature spec | Revision 1 | 2026-11-23 19:37 (Asia/Manila), project thread decision card: "Approve as written" on "Approve FEAT-004 spec and plan revision 1 for Gemini to execute?" |
| FEAT-004 plan | Revision 1 | 2026-11-23 19:37 (Asia/Manila), project thread decision card: "Approve as written" on "Approve FEAT-004 spec and plan revision 1 for Gemini to execute?" |
| FEAT-004 Planned stop 2 visual approval & GitHub push | Phase 6 at `deb18a9` | 2026-11-24T06:09:23+08:00 chat: "push the changes to github, then proceed to phase 7" |
| AUDIT-001 plan | Revision 1 | 2026-11-24T07:09:41+08:00 and 2026-11-24T07:10:47+08:00 chat: "read and execute:  docs/audits/AUDIT-001-code-quality-report.md." clarified as "docs/plans/AUDIT-001-implementation.md" |
| AUDIT-001 report revision 2 corrections (editorial and severity corrections from the Claude Code review of `946b3d7`) | Report revision 2 | 2026-11-24 chat, answering the review: "Yes make the corrections, Ill have gemini re verify it" |
| AUDIT-001 remediation plan, continuous execution | Revision 2, committed as `docs(plan): AUDIT-001 remediation plan revision 2` | 2026-11-26T23:32:00+08:00 Claude Code decision card: "Approve, run without stops" on "Do you approve it (revision 2, with the fixes I'm about to make) for Gemini to run?" |
| AUDIT-001 remediation D-1 (delete `WarangToggle`, amend FEAT-003 C11 to revision 2, keep `MayaPose.footTap`) | Plan revision 2 | 2026-11-26T23:32:00+08:00 Claude Code decision card: "Delete it and amend FEAT-003" |
| AUDIT-001 remediation D-2 and D-3 as recommended | Plan revision 2 | 2026-11-26T23:32:00+08:00 Claude Code decision card: "Yes, as recommended" |

Allowed phases (AUDIT-001 remediation): Phases 1-6 of plan revision 2 continuously without approval stops, with every gate passing in every phase, then stop before Independent verification; never push and never add a dependency.
This approval replaces directive 3 ("mandatory hard stops") in `AGENTS.md` for this plan only.

Allowed phases (AUDIT-001, complete): Phases 0-4 continuously without hard stops (plan revision 1), never editing product code and never pushing.

Allowed phases (FEAT-002, complete): Phases 1-4 continuously without hard stops (Len's instruction, 2026-11-21), with every gate passing in every phase.
Allowed phases (FEAT-003): Phases 1-10 continuously, with every gate passing, and one stop after Phase 6 for Len's visual review (plan P-1).
Allowed phases (FEAT-004): Phases 0-8 continuously, with every gate passing, stopping only at the Phase 1 size budget (if exceeded after the P-1 reductions) and after Phase 6 for Len's visual review.

## Progress and working tree

FEAT-001 is complete (`a85a915`).
FEAT-002 revision 1 approved at `cfeccc6`; visual baseline committed at `5d679f1`; Phase 1 complete at `c1602c5`; Phase 2 complete at `1ac6fe8`; Phase 3 complete at `549f571`; Phase 4 complete (clutter removed, completed design docs archived to `docs/archive/`, references and `docs/SPEC_INDEX.md` updated, final gates 1-6 passed with 97 tests, 13 direct dependencies, and 7650 hand-written `lib/` lines).
FEAT-003 spec, plan, and research committed at `9a5b3f7`; visual baseline committed at `0491ab7`.
FEAT-003 Phase 1 (contrast and neutral tokens) complete in the commit `docs(plan): FEAT-003 phase 1 - contrast and neutral tokens`.
FEAT-003 Phase 2 (keepsake typography) complete in the commit `docs(plan): FEAT-003 phase 2 - keepsake typography`.
FEAT-003 Phase 3 (clay icon set) complete in the commit `docs(plan): FEAT-003 phase 3 - clay icon set`.
FEAT-003 Phase 4 (clay foundation and components) complete in the commit `docs(plan): FEAT-003 phase 4 - clay foundation and components`.
FEAT-003 Phase 5 (dock and You sheet) complete in the commit `docs(plan): FEAT-003 phase 5 - dock and You sheet`.
FEAT-003 Phase 6 (map, capture, and moment card) complete in the commit `docs(plan): FEAT-003 phase 6 - map, capture, and moment card`; the P-1 visual review stop is open.
FEAT-003 Phase 6 visual review fixes (8 must-fix, 8 polish) complete in the commit `docs(plan): FEAT-003 phase 6 - visual review fixes`; the P-1 stop stays open for Len's approval of the re-render.
The two older map bugs (clustering, attribution) are fixed in the commit `docs(plan): FEAT-003 phase 6 - map bug fixes`.
P-1 approved; the full-zoom cluster tap and the offline tile fix are in the commit `docs(plan): FEAT-003 phase 6 - approval and last fixes`.
FEAT-003 Phase 7 complete in the commit `docs(plan): FEAT-003 phase 7 - trip colours and shelf`.
FEAT-003 Phase 8 complete in the commit `docs(plan): FEAT-003 phase 8 - search, news, and settings`.
FEAT-003 Phase 9 complete in the commit `docs(plan): FEAT-003 phase 9 - interactive maya`.
FEAT-003 Phase 10 complete in the commit `docs(plan): FEAT-003 phase 10 - polish and documents`.
FEAT-004 spec and plan committed at `e4539d6`; visual baseline committed at `c22ec04`; Phase 0 complete in `docs(plan): FEAT-004 phase 0 - documents and baseline` (`feabe48`); Phase 1 complete in `docs(plan): FEAT-004 phase 1 - place book builder` (`1dec458`); Phase 2 complete in `docs(plan): FEAT-004 phase 2 - place book in the app` (`6683783`); Phase 3 complete in `docs(plan): FEAT-004 phase 3 - places table and migration` (`899ccef`); Phase 4 complete in `docs(plan): FEAT-004 phase 4 - categories and glyphs` (`30d5d31`); Phase 5 complete in `docs(plan): FEAT-004 phase 5 - place picker and capture suggestion` (`7ab55a5`); Phase 6 complete in `docs(plan): FEAT-004 phase 6 - map search and category filter` (`deb18a9`, pushed to GitHub); Phase 7 complete in `docs(plan): FEAT-004 phase 7 - category stamps` (`175d80a`); Phase 8 complete in `docs(plan): FEAT-004 phase 8 - polish and documents` (`7d6703f`; 329 tests passing, 58 PNGs at 200% text in `docs/evidence/FEAT-001/feat-004-phase-8-text-2x/` with 0 overflows).
AUDIT-001 (audited commit `7d6703f`, Flutter 3.44.7 / Dart 3.12.2, zero product files changed): Phase 0 complete in `docs(audit): AUDIT-001 phase 0 - baseline and inventory` (`17dcddb`); Phase 1 complete in `docs(audit): AUDIT-001 phase 1 - automated scans` (`9448f82`); Phase 2 complete in `docs(audit): AUDIT-001 phase 2 - manual review` (`081d32d`); Phase 3 complete in `docs(audit): AUDIT-001 phase 3 - verified candidates` (`4437761`); Phase 4 complete in `docs(audit): AUDIT-001 phase 4 - quality report` (`946b3d7`; 50 findings, not pushed).
Report revision 2 in the commit `docs(audit): AUDIT-001 report revision 2 - review corrections` (`944beac`) applies the Claude Code review: 3 false sub-claims withdrawn (R8 in `AUD-042`, the Undo part of `AUD-009`, the trip form step 0 part of `AUD-005`), wrong names or code descriptions corrected in 9 findings, 7 severities lowered, `AUD-001` proof strengthened with `aapt2` on the built release APKs, and new `AUD-051` (archive scripts archive stale APKs); totals are 51 findings, 32 Confirmed and 19 Plausible, 259 removable lines, `check_report.py` `0 problems`, and `check_identifiers.py` leaves only external API, lint, and historical names.
Gemini re-verified revision 2 on 2026-11-24 against the code, local build outputs, Flutter SDK, and Drift pub cache, confirming all corrections and fixing one line-range typo in `AUD-017` (`database.dart:69-133`, not `69-73`).
Top five AUDIT-001 findings to fix first (revision 2): `AUD-001` (release APKs omit `android.permission.INTERNET`), `AUD-002` (fresh map tiles revalidate on every view with no HTTP timeout), `AUD-004` (photo processing on the UI isolate, with unbounded avatar picks), `AUD-005` (Back and Close mid-save on capture and the trip form), `AUD-006` (multi-step moment edits outside one transaction).
Preserve the existing untracked paths: `.agents/skills/*`, `.agents/templates/`, `.claude/`, `CLAUDE.md`, `docs/evidence/FEAT-001/claude-review/`, `releases/`, and `scripts/`.
AUDIT-001 remediation plan revision 1 was drafted on 2026-11-24 and reviewed by Claude Code on 2026-11-26; revision 2 fixes the review findings (tile database upgrade for the new last-access column, no chunked place book copy, FEAT-003 C11 amendment, toggle test range 289-326, About version test, probe-source step, sourced execution mode).
AUDIT-001 remediation Phase 1 complete in `fix(android): AUDIT-001 phase 1 - release manifest, gradle, and version` (`36138c8`); Phase 2 complete in `fix(map): AUDIT-001 phase 2 - tile cache, surface state, and location helper` (42 targeted tests passed, `flutter analyze` clean).
Remediation Phases 3-6 are in progress.

## Checks and evidence

Baseline on 2026-11-24 at `7d6703f` (verified again at `081d32d` after deleting temporary V3 probes): `flutter analyze` reported `No issues found!`, `flutter test` passed 329 tests (0 failed), `python docs/audits/AUDIT-001/scripts/check_report.py` printed `0 problems`, and `git diff --stat 7d6703f -- lib test tool android ios assets design pubspec.yaml pubspec.lock analysis_options.yaml` printed nothing.
AUDIT-001 report and evidence: [docs/audits/AUDIT-001-code-quality-report.md](docs/audits/AUDIT-001-code-quality-report.md), [docs/evidence/AUDIT-001-verification.md](docs/evidence/AUDIT-001-verification.md), and scans `00` to `23` under `docs/audits/AUDIT-001/scans/`.
Baseline on 2026-11-21 at `a85a915`: `flutter test` passed 96 tests, and `flutter analyze` reported `No issues found!`.
FEAT-004 evidence: [docs/evidence/FEAT-004-verification.md](docs/evidence/FEAT-004-verification.md), with baseline screenshots under `docs/evidence/FEAT-001/feat-004-baseline/`.
FEAT-003 evidence: [docs/evidence/FEAT-003-verification.md](docs/evidence/FEAT-003-verification.md), with screenshots under `docs/evidence/FEAT-001/feat-003-*`.

FEAT-002 evidence: [docs/evidence/FEAT-002-verification.md](docs/evidence/FEAT-002-verification.md).
FEAT-001 evidence: [docs/evidence/FEAT-001-verification.md](docs/evidence/FEAT-001-verification.md).

## Blockers and attempts

| Problem | Fix-and-check attempts used (maximum 3) | Changes tried and observed result | Required decision or access |
| --- | --- | --- | --- |
| None blocking | - | - | - |

## Next action

000. **AUDIT-001 remediation (primary):** Gemini executes [docs/plans/AUDIT-001-remediation-implementation.md](docs/plans/AUDIT-001-remediation-implementation.md) revision 2, Phases 1-6, continuously, then sets the next action to its Independent verification phase for a different agent or fresh session.
00. **FEAT-004:** Phases 0-8 complete (`docs(plan): FEAT-004 phase 8 - polish and documents`). Waiting on Len for the 5-item physical-device checklist in [docs/evidence/FEAT-004-verification.md](docs/evidence/FEAT-004-verification.md) (and optional push of Phase 7-8 commits to GitHub).
0. **FEAT-003:** implemented through Phase 10. Waiting on Len for physical-device checks (REQ-023 steps are in the evidence log) and the layered maya art (D-2).
1. **Claude UI screenshot capture (requested 2026-11-21):** capture fresh UI screenshots from the current codebase (`ba0c56a`) using [tool/ux_screenshots_test.dart](tool/ux_screenshots_test.dart).
   - Working directory: `C:\Users\User\Desktop\PersonalProjects\04-FUN-STUFF\WARANG\Warang` (inner repo root, not the outer `WARANG/` folder).
   - Command (choose a fresh label such as `claude-review` or `latest`):
     `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=claude-review`
   - Output: 30 PNGs (15 screens in both dark and light themes, 390x844 @ 2x DPR) written to `docs/evidence/FEAT-001/<UX_LABEL>/`.
   - Hard rules: never run `--update-goldens` on `UX_LABEL=final` or `UX_LABEL=feat-002-baseline`, do not modify app code or tests unless Len asks, delete `tool/failures/` if created, preserve the listed untracked paths, and do not commit generated screenshots unless Len asks.
   - Known Windows gotcha: if Flutter fails to delete `build\unit_test_assets`, remove that ignored directory and rerun.
   - Note: OSM map tiles do not load in the test host (map renders as ground colour and `Codec failed to produce an image` logs are expected); `08_home_scrolled_*` and `12_capture_*` depend on the system date/clock.
2. **Len physical-device validation:** Len runs the FEAT-001 and FEAT-002 physical-device checklists.
