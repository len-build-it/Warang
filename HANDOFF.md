# Current handoff

Created: 2026-10-16T22:55:00+08:00
Updated: 2026-11-21T17:15:00+08:00
State: FEAT-002 Phase 2 complete; continuing to Phase 3
Feature: FEAT-002 (FEAT-001 complete, physical-device checks pending)

## Read first

- [AGENTS.md](AGENTS.md), [GEMINI.md](GEMINI.md), and [CLAUDE.md](CLAUDE.md)
- [docs/SPEC_INDEX.md](docs/SPEC_INDEX.md)
- [docs/DESIGN_SPEC.md](docs/DESIGN_SPEC.md) and [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) (architecture; T17 keeps the tile cache in `sqflite`)
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

Allowed phases: Phases 1-4 continuously without hard stops (Len's instruction, 2026-11-21), with every gate passing in every phase.

## Progress and working tree

FEAT-001 is complete (`a85a915`).
FEAT-002 revision 1 approved at `cfeccc6`; visual baseline committed at `5d679f1`; Phase 1 complete at `c1602c5`; Phase 2 complete (`WarangToggle` removed, `MapTileStore` unified in `onOpen` + byte-free `evictToLimit`, `seedDefaults` deduplicated, `PhotoStore` uses `newId()`, gates 1-6 passed with 97 tests and 7665 `lib/` lines).
Preserve the existing untracked paths: `.agents/skills/*`, `.agents/templates/`, `.claude/`, `CLAUDE.md`, `releases/`, and `scripts/`.

## Checks and evidence

Baseline on 2026-11-21 at `a85a915`: `flutter test` passed 96 tests, and `flutter analyze` reported `No issues found!`.
FEAT-002 evidence: [docs/evidence/FEAT-002-verification.md](docs/evidence/FEAT-002-verification.md).
FEAT-001 evidence: [docs/evidence/FEAT-001-verification.md](docs/evidence/FEAT-001-verification.md).

## Blockers and attempts

| Problem | Fix-and-check attempts used (maximum 3) | Changes tried and observed result | Required decision or access |
| --- | --- | --- | --- |
| None | - | - | - |

## Next action

Continue to Phase 3 of [docs/plans/FEAT-002-implementation.md](docs/plans/FEAT-002-implementation.md).
Len still owes the FEAT-001 physical-device checklist.
