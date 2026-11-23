# Implementation Plan: AUDIT-001 code quality audit report

Created: 2026-11-24T09:30:00+08:00
Updated: 2026-11-24T07:19:00+08:00
Revision: 1
Status: In progress (Phase 1 complete)
Feature spec and revision: None; this plan holds its own requirements (AUD-REQ-001 to AUD-REQ-010) because it produces a report and changes no app behavior
Approved baseline and architecture revisions: `docs/IMPLEMENTATION_PLAN.md` at `dc407c5`, FEAT-001 to FEAT-004 revision 1 as listed in `docs/SPEC_INDEX.md`
Len's chat approval: 2026-11-24T07:09:41+08:00 and 2026-11-24T07:10:47+08:00 chat: "read and execute:  docs/audits/AUDIT-001-code-quality-report.md." clarified as "docs/plans/AUDIT-001-implementation.md"
Target branch: `master` (verified 2026-11-24 at `7d6703f`; remote `origin` exists, and this plan never pushes)
Implementing agent: Gemini

## Purpose

Len wants one Markdown report that lists sloppy, unnecessary, and dangerous code in this repository.
Every finding in the report must be verified, so Len can plan later quality work from it without rechecking each claim.
The report is the only product of this plan.

## Scope

In scope:
- Hand-written Dart under `lib/` (about 15080 lines in 49 files at `7d6703f`).
- Tests under `test/` and `tool/ux_screenshots_test.dart`.
- `pubspec.yaml`, `analysis_options.yaml`, and the Android files under `android/` that Git tracks.
- `tool/place_book/` (Python builder, schema, categories) and `scripts/build-and-archive.*`.
- Tracked assets listed in `pubspec.yaml`, and the weight of tracked binary files (1098 PNG, SQLite, and TTF files at `7d6703f`).

Out of scope:
- Fixing anything.
  This plan edits no file under `lib/`, `test/`, `tool/`, `android/`, `ios/`, `assets/`, `design/`, `pubspec.yaml`, `pubspec.lock`, or `analysis_options.yaml`.
- Generated files (`*.g.dart`), `build/`, `.dart_tool/`, and `tool/place_book/.venv/`.
- The outer `WARANG/` folder, `.agents/`, `.claude/`, `.cursorrules`, `releases/`, and the agent instruction files.
- Physical-device behavior; Len checks devices.

Preserve the existing untracked paths: `.agents/skills/*`, `.agents/templates/`, `.claude/`, `CLAUDE.md`, `releases/`, and `scripts/`.
Never stage those paths, and never use `git add -A` or `git add .`.

### Execution mode

Len asked for no hard stops (2026-11-24 chat).
This overrides the "mandatory hard stops" line in the repository `AGENTS.md` for this plan only.
Run Phase 0 to Phase 4 in order without asking for sign-off between phases.
The `AGENTS.md` rule to fix unrelated lint, test failures, and flaky tests on sight does not apply here.
This plan records them as findings and fixes nothing.
A problem that would normally stop work becomes a recorded limitation in the report and the evidence log, and work continues.
The Recovery section lists the only cases where a phase stays uncommitted.

## Requirements

| ID | Requirement | Pass criterion |
| --- | --- | --- |
| AUD-REQ-001 | The report exists at `docs/audits/AUDIT-001-code-quality-report.md`. | The file exists and Git tracks it after Phase 4. |
| AUD-REQ-002 | Every finding has a stable ID, one category, one severity, one verification status, and at least one `path:line` location. | The Phase 4 report check script prints `0 problems`. |
| AUD-REQ-003 | Every finding in the main list is Confirmed or Plausible, as defined in "Verification methods". | No finding in the main list has another status. |
| AUD-REQ-004 | Every finding records the exact command, probe, or call chain that verified it, and the observed output. | Each finding has a non-empty "Proof" field with a command or a file-and-line call chain. |
| AUD-REQ-005 | Rejected candidates appear in an appendix with the reason for rejection. | The appendix exists; its count equals candidates minus reported findings, as recorded in the evidence log. |
| AUD-REQ-006 | Each finding has a concrete remediation and an effort size. | Each finding has "Fix" and "Effort" fields; no field says only "refactor" or "clean up". |
| AUD-REQ-007 | Findings that conflict with an approved decision name that decision. | Each such finding has a "Conflicts with" field naming the document and section, for example `docs/IMPLEMENTATION_PLAN.md` T17. |
| AUD-REQ-008 | The report groups findings into remediation batches Len can approve as future features. | A "Remediation batches" section lists each batch with its finding IDs, total effort, and risk. |
| AUD-REQ-009 | The audit changes no app code, test, config, or asset. | `git diff --stat 7d6703f -- lib test tool android ios assets design pubspec.yaml pubspec.lock analysis_options.yaml` prints nothing after Phase 4. |
| AUD-REQ-010 | The report follows the repository writing rules. | No em dash or en dash in the new files, sentence case headings, one sentence per line in prose. |

## Definitions

### Categories

Use exactly one category per finding.

- `dangerous`: code that can lose or corrupt user data, crash, leak data, misuse a permission, break offline use, or fail silently.
  Examples: a file deleted before its database row commits, a migration with no test, a swallowed exception on a save path, an unchecked `!` on data from disk, a missing `mounted` check after `await`, a `.travelbook` or place book import that trusts paths or sizes, an exported Android component, cleartext traffic, or a missing tile server user agent.
- `unnecessary`: code that can go with no behavior change.
  Use the ponytail tags as a sub-tag: `delete` (dead code, unused flexibility), `stdlib` (hand-rolled standard library function, name it), `native` (code or dependency doing what Flutter or Android already does, name the feature), `yagni` (abstraction with one implementation, config nobody sets, layer with one caller), `shrink` (same logic in fewer lines, show the shorter form).
- `sloppy`: code that works but costs readers or maintainers time.
  Examples: duplicated blocks, a file over 400 lines or a function over 60 lines that mixes jobs, inconsistent names for one concept, magic numbers outside `lib/app/theme/`, hard-coded colors outside the theme, stale comments, commented-out code, leftover `TODO`, tests that assert nothing or depend on the clock.

If a finding fits two categories, choose the higher one in this order: `dangerous`, `unnecessary`, `sloppy`.

### Severity

- `critical`: realistic user data loss or corruption, or a security hole, on a normal user flow.
- `high`: crash, silent failure, or data risk on a less common flow; or more than 200 removable lines in one finding.
- `medium`: wrong behavior in an edge case, a maintenance trap, or 50 to 200 removable lines.
- `low`: style, naming, or under 50 removable lines.

### Verification methods

Record the method code in each finding.

- `V1 reference proof`: a search shows zero callers, one implementation, or one call site.
  Record the exact `git grep` command and its full output.
  Search `lib`, `test`, and `tool` together, and also search for the name as a string, so reflection, routes, and asset names are not missed.
- `V2 tool output`: the analyzer, `dart fix`, `flutter pub`, or a scan script reports it.
  Record the command and the matching output line.
- `V3 reproduction probe`: a temporary test or script shows the problem happening.
  Write probes only under `test/_audit_probe/`, run them, copy the command and output into the evidence log, and delete the folder before staging.
  A probe never changes code under `lib/`.
- `V4 call chain trace`: a written chain of `path:line` steps from a user action or app start to the problem line.
  Use it when a probe is impractical, for example for camera, GPS, or Android lifecycle paths.
- `V5 documentation reference`: for `stdlib` and `native` claims, the exact Dart or Flutter API name and its documentation URL on `api.dart.dev`, `api.flutter.dev`, or `developer.android.com`.

Statuses:
- `Confirmed`: proven by V1, V2, or V3, and the proof was rerun in Phase 3 with the same result.
- `Plausible`: supported by V4 or V5 only, with no contradicting evidence.
- `Rejected`: the proof failed, the code is intended by an approved decision with no stated cost, or the candidate repeats an item that FEAT-002 already removed.

## Gates for every phase

Run from the repository root `C:\Users\User\Desktop\PersonalProjects\04-FUN-STUFF\WARANG\Warang`, not the outer `WARANG/` folder.

1. No product change: `git status --porcelain -- lib test tool android ios assets design pubspec.yaml pubspec.lock analysis_options.yaml` prints nothing.
2. No probe left: `test/_audit_probe/` does not exist, and `tool/failures/` does not exist.
3. Writing rule: this command prints `0`:
   `python -c "import pathlib as p; fs=[f for d in ['docs/audits','docs/plans/AUDIT-001-implementation.md','docs/evidence/AUDIT-001-verification.md'] for f in ([p.Path(d)] if p.Path(d).is_file() else p.Path(d).rglob('*.md'))]; print(sum(f.read_text(encoding='utf-8').count(c) for f in fs for c in (chr(0x2014), chr(0x2013))))"`
4. The phase's own checks listed below pass.

Record the actual output of every gate in `docs/evidence/AUDIT-001-verification.md`.
Create that file in Phase 0 from `.agents/templates/docs/VERIFICATION.md`.

Write throwaway scan scripts outside the repository, in `$env:TEMP\warang-audit\`.
Use only the Python standard library and the Dart and Flutter tools already installed; add no dependency.
Copy each script's source into `docs/audits/AUDIT-001/scripts/` so the scan can be rerun, and commit those copies.
Save raw scan output as text under `docs/audits/AUDIT-001/scans/`.

Commit only the paths named in each phase, check `git diff --cached --stat` before each commit, and add no agent co-author.

## Phase 0: Baseline and inventory

Requirements: AUD-REQ-009, AUD-REQ-010
State: Complete

### Tasks

- [x] Run `git status --short` and `git log --oneline -1`, and confirm HEAD is `7d6703f` or a later commit that changes no file in scope.
      If HEAD is later, use the new hash everywhere this plan says `7d6703f`, and record why.
- [x] Create `docs/evidence/AUDIT-001-verification.md` from the template.
- [x] Record the baseline: `flutter analyze` output, `flutter test` pass and fail counts, and `flutter --version`.
      A failing test or analyzer issue is not a blocker; it becomes a Phase 1 candidate.
- [x] Write `docs/audits/AUDIT-001/scans/00-inventory.txt` with:
      every tracked file under `lib`, `test`, and `tool` with its line count (`git ls-files lib test tool | grep -v "\.g\.dart$"` piped to `wc -l`),
      the direct dependencies from `pubspec.yaml`,
      the output of `dart pub deps --style=compact`,
      the output of `flutter pub outdated`,
      and the 30 largest tracked files from `git ls-files -z | xargs -0 du -k | sort -n | tail -30`.
- [x] Create `docs/audits/AUDIT-001-code-quality-report.md` with the headings from "Report layout" and `Pending` under each.

### Verification

- [x] Gates 1 to 4 pass.
- [x] The inventory lists 49 hand-written `lib/` files, or the actual count with a note if it differs.

### Review and checkpoint

- [x] Stage `docs/audits/`, `docs/evidence/AUDIT-001-verification.md`, and `docs/plans/AUDIT-001-implementation.md` only.
- [x] Commit `docs(audit): AUDIT-001 phase 0 - baseline and inventory`, and confirm the hash with `git log --oneline -1`.

## Phase 1: Automated scans

Requirements: AUD-REQ-002, AUD-REQ-004
State: Complete

Every scan below writes one file under `docs/audits/AUDIT-001/scans/`.
Each hit becomes a candidate row in the evidence log with a temporary ID `C-NNN`, the scan file, and the `path:line`.
Do not judge candidates in this phase; Phase 3 does that.

### Tasks

- [x] Strict lint pass in a throwaway worktree, so the real `analysis_options.yaml` stays untouched.
      Run `git worktree add --detach "$env:TEMP\warang-audit\wt" HEAD`.
      In the worktree, replace `analysis_options.yaml` with the current file plus these rules under `linter: rules:`:
      `unreachable_from_main`, `discarded_futures`, `cancel_subscriptions`, `close_sinks`, `avoid_dynamic_calls`, `only_throw_errors`, `avoid_catches_without_on_clauses`, `empty_catches`, `throw_in_finally`, `control_flow_in_finally`, `unnecessary_statements`, `unnecessary_lambdas`, `unnecessary_await_in_return`, `avoid_slow_async_io`, `no_runtimeType_toString`, `prefer_final_fields`, `unnecessary_null_checks`, `avoid_redundant_argument_values`, `use_if_null_to_convert_nulls_to_bools`, `literal_only_boolean_expressions`.
      Run `flutter pub get`, then `flutter analyze --no-fatal-infos --no-fatal-warnings` and save the output as `01-strict-lints.txt`.
      If the analyzer rejects a rule name, delete that rule, rerun, and list the dropped rule in the scan file.
      Run `dart fix --dry-run` in the worktree and save it as `02-dart-fix.txt`.
      Remove the worktree with `git worktree remove --force "$env:TEMP\warang-audit\wt"` and confirm `git worktree list` shows only the main tree.
- [x] Unused dependencies: for each direct dependency in `pubspec.yaml`, run `git grep -n "package:<name>/" -- lib test tool` and save the counts as `03-dependency-use.txt`.
      A dependency with zero imports, or imports only in tests while listed under `dependencies`, is a candidate.
      Packages used only through Flutter plugin registration, such as `sqlite3_flutter_libs`, need a note instead of a zero count.
- [x] Unused assets: for each asset in `pubspec.yaml`, search `lib`, `test`, and `tool` for its path and its file name, and save as `04-asset-use.txt`.
      Also list tracked files under `assets/` and `design/` that `pubspec.yaml` does not declare and no code reads.
- [x] Unused public code: write `public_symbols.py` that lists every top-level and class-level public declaration in hand-written `lib/` files, then counts word-boundary references in `lib`, `test`, and `tool` outside the declaring line.
      Save symbols with zero outside references, and symbols referenced only from tests, as `05-unused-symbols.txt`.
      Treat the result as candidates only; Dart overrides, `build` methods, Drift table columns, and Riverpod providers read by name can look unused.
- [x] Pattern scans, one file each, using `git grep -nE` over `lib` (and `test` where named):
      `06-catch.txt`: `catch \(|on [A-Z][A-Za-z]+ catch|\.catchError\(|onError:`.
      `07-null-and-late.txt`: `[A-Za-z0-9_\)\]]!(\.|\)|;|,| )` and `\blate\b`, with a per-file count.
      `08-dynamic-and-casts.txt`: `\bdynamic\b|\bas [A-Z]|as Map|as List`.
      `09-async-gaps.txt`: files that contain both `await` and `setState(`, `context.` or `ref.` after an `await` inside the same method; list method names and lines for manual reading.
      `10-lifecycle.txt`: each `AnimationController`, `TextEditingController`, `ScrollController`, `FocusNode`, `StreamSubscription`, `Timer`, and `StreamController`, with whether the same file calls `dispose()`, `cancel()`, or `close()` on it.
      `11-sql-and-fts.txt`: `customSelect|customStatement|customUpdate|rawQuery|rawInsert|rawDelete|execute\(|MATCH|LIKE`, plus every string built with `$` or `+` that reaches one of those calls.
      `12-files.txt`: `File\(|Directory\(|\.delete\(|\.rename\(|\.copy\(|writeAsBytes|readAsBytes|getApplicationDocumentsDirectory|getTemporaryDirectory|path\.join`.
      `13-network.txt`: `Uri\.parse|https?://|userAgentPackageName|TileLayer|NetworkTileProvider|HttpClient`.
      `14-debug-and-markers.txt`: `print\(|debugPrint\(|kDebugMode|assert\(|TODO|FIXME|HACK|XXX|// ignore|ignore_for_file`, over `lib`, `test`, and `tool`.
      `15-hardcoded-style.txt`: `Color\(0x|Colors\.|EdgeInsets\.(all|only|symmetric)\([0-9]|Duration\((milliseconds|seconds): [0-9]|fontSize: [0-9]` outside `lib/app/theme/`.
      `16-time-and-random.txt`: `DateTime\.now\(\)|Random\(` with file, to find code and tests that depend on the clock.
- [x] Size and complexity: write `complexity.py` that reports, for each hand-written `lib/` file, its line count, and each function or `build` method longer than 60 lines by brace matching.
      Save as `17-complexity.txt`, and mark the brace matching as approximate in the file header.
- [x] Duplication: write `duplicates.py` that strips whitespace and comments, hashes every window of 8 consecutive non-empty lines in hand-written `lib/` files, and reports windows that appear in two or more places.
      Merge overlapping windows into one block per pair of locations, and save as `18-duplicates.txt`.
- [x] Android and build config: copy the relevant lines of `android/app/src/main/AndroidManifest.xml`, the debug and profile manifests, and `android/app/build.gradle.kts` into `19-android.txt`.
      Note `android:allowBackup`, `android:usesCleartextTraffic`, `android:exported`, every `uses-permission`, `minSdk`, `targetSdk`, the release `signingConfig`, `minifyEnabled`, and any hard-coded secret or keystore path.
- [x] Tooling: read `tool/place_book/build_place_book.py`, `schema.sql`, `requirements.txt`, and both `scripts/build-and-archive.*` files.
      Save candidate lines in `20-tooling.txt`, covering unpinned versions, downloads without checksum checks, unchecked subprocess calls, and paths built from input.
- [x] Tests: in `test/` and `tool/ux_screenshots_test.dart`, list tests with no `expect` call, tests that call `Future.delayed` or `pump` with a fixed long duration, skipped tests, and goldens tied to the clock, in `21-tests.txt`.
- [x] Record each candidate as a `C-NNN` row in the evidence log with the scan file and location.

### Verification

- [x] Gates 1 to 4 pass; `git worktree list` shows one tree.
- [x] Each scan file from `01` to `21` exists and starts with the exact command or script that produced it.
- [x] The evidence log states the total candidate count.

### Review and checkpoint

- [x] Stage `docs/audits/AUDIT-001/`, `docs/evidence/AUDIT-001-verification.md`, and `docs/plans/AUDIT-001-implementation.md` only.
- [x] Commit `docs(audit): AUDIT-001 phase 1 - automated scans`, and confirm the hash.

## Phase 2: Manual review by area

Requirements: AUD-REQ-002, AUD-REQ-007
State: Awaiting approval

Read every hand-written file in scope in full, in the order below.
Add new candidates to the evidence log as `C-NNN` rows with source `manual`.
For each area, answer every question in its checklist in the evidence log, with `path:line` for each yes and the word `checked` for each no.

### Tasks

- [ ] Data layer: `lib/data/db/tables.dart`, `database.dart`, `daos.dart`, `lib/data/repository.dart`, `lib/data/files/photo_store.dart`, and `lib/data/places/*`.
      Does any write touch both the database and the file system without a defined order, so a crash between them leaves an orphan file or a row with no file?
      Does every multi-step write run inside a Drift `transaction`?
      Does each schema migration step have a test in `test/migration_test.dart` that starts from the old schema with data?
      Can a user-typed search string reach an FTS5 `MATCH` or a `LIKE` without going through `lib/data/places/fts_query.dart`?
      Does the place book installer check the asset's size, version, or integrity, and what happens if the copy stops halfway?
      Are errors from disk or SQLite caught and shown, or swallowed?
- [ ] Map: `lib/features/map/warang_map.dart` and `map_tile_store.dart`.
      Does the tile request send a user agent that meets the OpenStreetMap tile usage policy?
      Does the tile cache have a size limit and an eviction rule, and does the code enforce it?
      Is the `sqflite` tile database opened and closed once, and is it safe if two tiles write at once?
      Keep the separate `sqflite` cache itself as an approved decision (`docs/IMPLEMENTATION_PLAN.md` T17); report only costs inside it.
- [ ] Capture and travel mode: `lib/features/capture/`, `lib/features/travel_mode/`, `lib/features/places/`.
      Are denied or permanently denied location permissions handled on every path?
      Is a large photo decoded at full size in memory, and is decoding done off the UI isolate?
      After each `await`, does the code check `mounted` or `context.mounted` before using `context` or `setState`?
      Can a user leave the screen during a save and lose the moment without a message?
- [ ] Screens and shell: `lib/features/home_tab/`, `search/`, `news_tab/`, `stamps/`, `settings/`, `onboarding/`, `maya/`, and `lib/app/`.
      Is any provider, controller, stream, or timer created in `build`, or never disposed?
      Is any widget over 300 lines doing layout, state, and data access together?
      Does `lib/app/app_state.dart` or `device_providers.dart` hold global state that tests cannot reset?
      Is the same concept named two ways across files, for example trip and journey, or moment and memory?
- [ ] Theme and components: `lib/app/theme/*`.
      Does a token, component, or variant exist with one caller or none?
      Do `components.dart` and `clay_components.dart` implement the same widget twice?
      Do screens bypass tokens with literal colors, sizes, or durations (cross-check `15-hardcoded-style.txt`)?
- [ ] Android, tooling, and tests: the files from Phase 1 scans `19`, `20`, and `21`.
      Is the release build signed with the debug key?
      Would `android:allowBackup` copy the user's photos and database to a cloud backup without the user knowing, and does any spec decide this?
      Does any test pass even when the feature it names is broken?
- [ ] Cross-check every candidate against the approved documents in `docs/SPEC_INDEX.md` and against FEAT-002.
      Mark each candidate that an approved decision requires, and each one FEAT-002 already handled.

### Verification

- [ ] Gates 1 to 4 pass.
- [ ] Every area checklist question has an answer in the evidence log.
- [ ] The evidence log lists every hand-written `lib/` file as read, with its line count.

### Review and checkpoint

- [ ] Stage `docs/evidence/AUDIT-001-verification.md` and `docs/plans/AUDIT-001-implementation.md` only.
- [ ] Commit `docs(audit): AUDIT-001 phase 2 - manual review`, and confirm the hash.

## Phase 3: Verify every candidate

Requirements: AUD-REQ-003, AUD-REQ-004, AUD-REQ-005, AUD-REQ-007
State: Awaiting approval

### Tasks

- [ ] For each candidate, apply at least one method from "Verification methods" and record the method, the command or chain, and the observed output in the evidence log.
- [ ] For every `unnecessary` candidate, use V1, and also check that removing it changes no screen: name the screens or tests that touch the code, or state that none do.
- [ ] For every `dangerous` candidate rated `critical` or `high`, try V3 first.
      Write the probe under `test/_audit_probe/`, run it with `flutter test test/_audit_probe/<name>_test.dart`, and record the command and output.
      If a probe cannot reach the code without changing `lib/`, use V4 and write down why the probe was not possible.
- [ ] For every `stdlib` or `native` candidate, add V5 with the API name and URL.
- [ ] For every `shrink` candidate, write the shorter form in the finding, and count the lines saved.
- [ ] Merge duplicates: candidates with the same root cause become one finding that lists every location.
- [ ] Give each surviving candidate a final ID `AUD-NNN`, numbered after ranking in Phase 4, and set its status to Confirmed or Plausible.
      Move every failed candidate to the rejected list with its `C-NNN` ID and a one-line reason.
- [ ] Second pass: rerun every Confirmed proof command at HEAD and check that each cited `path:line` still points to the quoted code.
      A proof that gives a different result drops to Plausible or Rejected, with the reason recorded.
- [ ] Delete `test/_audit_probe/` and confirm `git status --porcelain -- test` prints nothing.

### Verification

- [ ] Gates 1 to 4 pass.
- [ ] The evidence log shows, for each candidate, one of Confirmed, Plausible, or Rejected, and the counts add up to the Phase 1 and Phase 2 total.
- [ ] `flutter analyze` and `flutter test` give the same results as the Phase 0 baseline.

### Review and checkpoint

- [ ] Stage `docs/evidence/AUDIT-001-verification.md` and `docs/plans/AUDIT-001-implementation.md` only.
- [ ] Commit `docs(audit): AUDIT-001 phase 3 - verified candidates`, and confirm the hash.

## Phase 4: Write the report

Requirements: AUD-REQ-001 to AUD-REQ-010
State: Awaiting approval

### Report layout

Write `docs/audits/AUDIT-001-code-quality-report.md` with these sections, in this order:

1. `# AUDIT-001: Code quality audit`, with Created and Updated timestamps, the audited commit hash, and the Flutter version.
2. `## Summary`: counts per category and severity in one table, removable lines, removable dependencies, and the five findings Len should fix first, by ID.
3. `## How findings were verified`: the method codes and statuses, copied from this plan, and the scan list with links to `docs/audits/AUDIT-001/scans/`.
4. `## Dangerous`, `## Unnecessary`, `## Sloppy`: one entry per finding, ranked by severity, then by lines removable, then by number of locations.
5. `## Remediation batches`: groups of findings that make sense as one future feature, each with finding IDs, total effort, risk to working features, the tests that would guard it, and any approved decision it would need to change.
6. `## Limitations`: rules dropped from the strict lint run, probes that were not possible, areas checked only by reading, and anything needing a physical device.
7. `## Appendix: rejected candidates`: a table with `C-NNN`, location, claim, and reason rejected.

Each finding uses this layout:

```markdown
### AUD-NNN: <one-line claim in plain words>

- Category: dangerous | unnecessary (<tag>) | sloppy
- Severity: critical | high | medium | low
- Status: Confirmed | Plausible
- Locations: `lib/path/file.dart:LINE`, ...
- Conflicts with: <document and section> | none
- Effort: S (under 1 hour) | M (1 to 4 hours) | L (over 4 hours)
- Lines removable: <number> | 0

<Two to five sentences: what the code does, what goes wrong or what is wasted, and who it affects.>

Proof (<method code>):

    <exact command or call chain>
    <observed output, trimmed to the lines that matter>

Fix: <the concrete change, naming the function, API, or file. For shrink, show the shorter code.>
```

### Tasks

- [ ] Write the report from the evidence log, using only Confirmed and Plausible findings.
- [ ] Write `check_report.py` that parses the report and prints one line per problem, then a final line `<N> problems`.
      It checks that every `AUD-NNN` is unique, every finding has all fields, every location's file exists at HEAD and has at least that many lines, and no em dash or en dash appears.
      Copy it to `docs/audits/AUDIT-001/scripts/` and save its output as `docs/audits/AUDIT-001/scans/22-report-check.txt`.
- [ ] Edit the report text for plain words, active voice, no filler, no vague words such as "robust" or "various", one sentence per line, and sentence case headings.
      Every claim names a file, a number, or a function; delete any sentence that would fit unchanged in another project's report.
- [ ] Add rows to `docs/SPEC_INDEX.md` for the plan, the report, and the evidence log.
- [ ] Update `HANDOFF.md` with the completed phases, commit hashes, actual checks, the top five findings, and the next action: Len reviews the report and picks remediation batches to turn into feature specs.

### Verification

- [ ] Gates 1 to 4 pass.
- [ ] `22-report-check.txt` ends with `0 problems`.
- [ ] `git diff --stat 7d6703f -- lib test tool android ios assets design pubspec.yaml pubspec.lock analysis_options.yaml` prints nothing.
- [ ] The finding count in the Summary equals the number of `### AUD-` headings.

### Review and checkpoint

- [ ] Stage `docs/audits/`, `docs/evidence/AUDIT-001-verification.md`, `docs/plans/AUDIT-001-implementation.md`, `docs/SPEC_INDEX.md`, and `HANDOFF.md` only.
- [ ] Commit `docs(audit): AUDIT-001 phase 4 - quality report`, and confirm the hash.
- [ ] Do not push.

## Recovery

There are no planned stops.
When a tool fails, try up to three fix-and-check attempts, record each in `HANDOFF.md`, then record the failure as a report limitation and continue with the next task.
Examples: if the worktree or strict lint run fails three times, skip it and rely on the other scans; if a probe cannot run, use V4.
A phase stays uncommitted only when gate 1 or gate 2 fails, because that means the audit changed product files or left a probe.
In that case, restore only the files this audit changed, check that the diff matches what the audit wrote, and rerun the gates; never reset or discard Len's own edits.
If a finding needs a decision from Len, report it with status Plausible and a "Conflicts with" field; do not stop to ask.
