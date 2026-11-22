# Current handoff

Created: 2026-10-16T22:55:00+08:00
Updated: 2026-11-23T07:09:36+08:00
State: FEAT-003 Phases 1-9 complete; Phases 10-10 running; FEAT-001 and FEAT-002 physical-device checks pending
Feature: FEAT-003 clay keepsake redesign (spec and plan revision 1)

## Read first

- [AGENTS.md](AGENTS.md), [GEMINI.md](GEMINI.md), and [CLAUDE.md](CLAUDE.md)
- [docs/SPEC_INDEX.md](docs/SPEC_INDEX.md)
- [docs/DESIGN_SPEC.md](docs/DESIGN_SPEC.md) and [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) (architecture; T17 keeps the tile cache in `sqflite`)
- [docs/features/FEAT-003-clay-keepsake-redesign.md](docs/features/FEAT-003-clay-keepsake-redesign.md) (replaces `docs/DESIGN_SPEC.md` for appearance once implemented) and [docs/plans/FEAT-003-implementation.md](docs/plans/FEAT-003-implementation.md)
- [docs/research/RES-001-clay-motion-genz.md](docs/research/RES-001-clay-motion-genz.md) (background research, not a spec)
- [docs/features/FEAT-002-ponytail-cleanup.md](docs/features/FEAT-002-ponytail-cleanup.md)
- [docs/plans/FEAT-002-implementation.md](docs/plans/FEAT-002-implementation.md)

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

Allowed phases (FEAT-002, complete): Phases 1-4 continuously without hard stops (Len's instruction, 2026-11-21), with every gate passing in every phase.
Allowed phases (FEAT-003): Phases 1-10 continuously, with every gate passing, and one stop after Phase 6 for Len's visual review (plan P-1).

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
Preserve the existing untracked paths: `.agents/skills/*`, `.agents/templates/`, `.claude/`, `CLAUDE.md`, `releases/`, and `scripts/`.

## Checks and evidence

Baseline on 2026-11-21 at `a85a915`: `flutter test` passed 96 tests, and `flutter analyze` reported `No issues found!`.
FEAT-003 evidence: [docs/evidence/FEAT-003-verification.md](docs/evidence/FEAT-003-verification.md), with screenshots under `docs/evidence/FEAT-001/feat-003-*`.

FEAT-002 evidence: [docs/evidence/FEAT-002-verification.md](docs/evidence/FEAT-002-verification.md).
FEAT-001 evidence: [docs/evidence/FEAT-001-verification.md](docs/evidence/FEAT-001-verification.md).

## Blockers and attempts

| Problem | Fix-and-check attempts used (maximum 3) | Changes tried and observed result | Required decision or access |
| --- | --- | --- | --- |
| None blocking | - | - | - |

## Next action

0. **FEAT-003:** P-1 approved on 2026-11-23. Run Phases 7-10 continuously per the plan, with every gate passing.
1. **Claude UI screenshot capture (requested 2026-11-21):** capture fresh UI screenshots from the current codebase (`ba0c56a`) using [tool/ux_screenshots_test.dart](tool/ux_screenshots_test.dart).
   - Working directory: `C:\Users\User\Desktop\PersonalProjects\04-FUN-STUFF\WARANG\Warang` (inner repo root, not the outer `WARANG/` folder).
   - Command (choose a fresh label such as `claude-review` or `latest`):
     `flutter test tool/ux_screenshots_test.dart --update-goldens --dart-define=UX_LABEL=claude-review`
   - Output: 30 PNGs (15 screens in both dark and light themes, 390x844 @ 2x DPR) written to `docs/evidence/FEAT-001/<UX_LABEL>/`.
   - Hard rules: never run `--update-goldens` on `UX_LABEL=final` or `UX_LABEL=feat-002-baseline`, do not modify app code or tests unless Len asks, delete `tool/failures/` if created, preserve the listed untracked paths, and do not commit generated screenshots unless Len asks.
   - Known Windows gotcha: if Flutter fails to delete `build\unit_test_assets`, remove that ignored directory and rerun.
   - Note: OSM map tiles do not load in the test host (map renders as ground colour and `Codec failed to produce an image` logs are expected); `08_home_scrolled_*` and `12_capture_*` depend on the system date/clock.
2. **Len physical-device validation:** Len runs the FEAT-001 and FEAT-002 physical-device checklists.
