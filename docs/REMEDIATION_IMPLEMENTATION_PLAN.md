# Warang — Remediation Implementation Plan

**Status:** proposed after the 2026-08-29 codebase audit.

This plan fixes the app's broken promises and release blockers before adding
new surface area. It supplements `docs/IMPLEMENTATION_PLAN.md`; for the work
listed here, this document's order takes precedence.

## Goal

Ship a trustworthy Android pilot: photos and location data are protected,
backup and restore are real, advertised actions work, and a release APK is
properly signed and verifiable.

## Non-goals

- No accounts, cloud sync, telemetry, ad SDK, or new analytics.
- No new map provider or bundled map package in this remediation.
- No feature work that is unrelated to a finding below.
- Do not expose `.travelbook` import/export until Phase 3 is complete.

## Hard stops

Stop immediately and do not start later phases if any condition below is true.

1. **Release stop:** Never distribute an APK signed with the debug key. A
   production upload/signing key must be provided outside the repository.
2. **Privacy stop:** Do not claim that everything stays on the phone until
   Android backup/data-extraction behavior is explicitly disabled and checked
   in the built manifest.
3. **Data-loss stop:** Do not expose “Back up everything” until it produces a
   complete, restorable archive. Do not implement restore until its conflict
   behavior is decided and tested.
4. **Untrusted-input stop:** Do not wire `.travelbook` import into the UI
   until malformed archives, malformed IDs, corrupt images, decompression
   bombs, and partial-write cleanup are covered by tests.
5. **Truthfulness stop:** Remove or relabel any user-facing control and README
   claim that is not working at the end of its phase.
6. **Green-tree stop:** Never commit or continue from a broken tree. Before
   each commit, run formatter, `flutter analyze`, and the smallest relevant
   test file. Run the full suite at every phase boundary.
7. **Migration stop:** No database schema change without a migration test for
   an existing database. Generated Drift code is committed separately after
   the schema change.

## Commit and test rules

The existing repository rules on small, reversible commits still apply. The
following are mandatory for this plan.

- Commit this plan first as `docs(plan): add remediation work order`.
- One independently revertible behavior change per commit. Do not batch a
  phase into one commit.
- Write the test before the implementation locally, then commit the passing
  test in the same commit as the behavior it proves. A test-only commit is
  allowed only when it is green on the current code.
- Every security, backup, database, import, or deletion change needs a direct
  automated test in the same commit. Manual testing is extra evidence, never
  a replacement.
- Run `dart format .` before each commit. Commit generated `*.g.dart` files
  in their own `build(data): regenerate Drift code` commit immediately after
  the matching schema commit.
- Each phase ends with `flutter analyze`, `flutter test`, a release build, and
  an actual commit log in the phase report.

## Work order

0. Establish truthful UI and documentation
1. Android privacy and production distribution
2. Full backup and restore
3. Secure, usable `.travelbook`
4. Complete the capture → moment → trip journey
5. Make offline map behavior honest and efficient
6. Release verification and documentation closeout

---

## Phase 0 — Remove false promises

**Goal:** no current screen or document says an unfinished feature works.

### Tasks

- [x] Replace the current text-only “Back up everything” action with an
  unavailable/coming-soon state, or remove it, until Phase 2 is complete.
- [x] Remove the text-only “Backup & `.travelbook`” drawer action until Phase
  3 is complete.
- [x] Remove disabled Share/Edit controls and fake “Swipe for nearby moments”
  affordances, or label them as unavailable, until Phase 4 implements them.
- [x] Rewrite the README feature list to match the current app. In particular,
  do not claim manual pin placement, travelbook access, share previews,
  full-device backup, trip promotion, or nearby swiping.
- [x] Add a widget test for every temporarily hidden/relabelled action.

### Required commits

1. `fix(ui): hide unavailable backup and travelbook actions` — widget tests
   included.
2. `fix(moment): remove inactive actions and fake pagination` — widget tests
   included.
3. `docs(readme): describe shipped functionality accurately`.

### Acceptance

- No visible action performs a no-op or shares placeholder text.
- README claims can be demonstrated on a device.

**Completed 2026-08-30:** `2770a86`, `e91013d`, `8d64418`. Analyzer clean;
all 18 tests green.

---

## Phase 1 — Android privacy and production distribution

**Goal:** protect the local photo-and-location diary and produce a properly
signed release artifact.

### Tasks

- [x] Set `android:allowBackup="false"` on the application.
- [x] Add Android 12+ data-extraction rules that deny cloud backup and
  device-to-device transfer.
- [x] Add a network-security configuration that blocks cleartext traffic.
  Keep the map endpoint HTTPS; do not add an HTTP exception.
- [ ] Inspect the merged release manifest. Record every exported component,
  why it is exported, and any permission that protects it. The currently
  merged `ProfileInstallReceiver` must be explicitly reviewed rather than
  assumed to be harmless.
- [ ] Configure release signing through ignored local key properties or the CI
  environment. Never commit a key, certificate, password, or `key.properties`.
- [x] Add a repeatable release-verification script/check that asserts the
  manifest protections and refuses debug signing for distribution builds.

### Required commits

1. `fix(android): disable platform backups` — manifest/resource changes and
   verification check.
2. `fix(android): forbid cleartext traffic` — network configuration and
   verification check.
3. `build(android): require release signing configuration` — no secrets.
4. `test(android): verify merged release manifest and signing` — a green,
   repeatable check against a release APK.

### Acceptance

- The built release manifest includes backup denial, data-extraction denial,
  and the network-security configuration.
- The distribution APK is signed with the supplied release key, not debug.
- The exported-component audit is checked into the commit message or this doc.

**Progress 2026-08-30:** `c1bf0ee`, `9d75459`, `aa52028`. The merged debug
manifest contains the required privacy attributes. Two components are
exported: `MainActivity` for the launcher, and AndroidX
`ProfileInstallReceiver`, which is protected by `android.permission.DUMP`.
Debug builds succeed. Release builds now fail closed with “Missing
android/key.properties” instead of using the debug key.

**⛔ HUMAN BLOCKER:** provide a production upload keystore outside the
repository and an ignored `android/key.properties` containing `storeFile`,
`storePassword`, `keyAlias`, and `keyPassword`. Then build the release APK,
inspect its merged manifest/signature, tick the two remaining Phase 1 tasks,
and only then start Phase 2.

---

## Phase 2 — Full backup and restore

**Goal:** one explicit action creates a complete archive the app can restore.

### Hard stop before implementation

Choose and record the restore policy before writing code:

- **Recommended:** “Restore creates a new local library after explicit
  confirmation.” It is the simplest policy that does not silently merge or
  overwrite memories.
- If merge is required, define deterministic ID-collision and duplicate-photo
  rules first. Do not improvise them in the restore code.

### Tasks

- [ ] Define a versioned backup manifest containing the profile, trips,
  moments, photos, and app metadata needed for restoration. Reuse the existing
  archive and photo-store primitives; do not add a backup package.
- [ ] Export database data and every live photo into one temporary archive,
  then share that file through the system sheet.
- [ ] Validate the entire archive before changing local data during restore.
- [ ] Restore database records and photos transactionally where possible; on
  failure, remove only files created by the failed restore and preserve the
  prior library.
- [ ] Add a last-successful-backup timestamp only after a successful archive
  has been created. Do not add reminder scheduling in this phase.
- [ ] Re-enable the backup control only after export and restore tests pass.

### Required tests

- Backup an initialized library and restore it into an empty library; profile,
  trips, moments, image bytes, thumbnails, and relative paths match.
- Corrupt, unsupported-version, oversized, and missing-file archives leave
  the existing library unchanged.
- A forced write failure leaves no restore-created orphan files.
- A restore requires explicit confirmation before any replacement behavior.

### Required commits

1. `feat(backup): define versioned archive manifest` — model/serialization
   tests.
2. `feat(backup): export full local library` — round-trip export tests.
3. `feat(backup): restore local library safely` — failure and preservation
   tests.
4. `feat(settings): expose verified backup and restore actions` — widget
   tests.

### Acceptance

- A real device can export, reinstall, restore, and see the same memories.
- No archive error can delete or partially replace the current library.

---

## Phase 3 — Secure and expose `.travelbook`

**Goal:** sharing a trip is safe, read-only on import, and reachable only when
the complete flow works.

### Tasks

- [ ] Decode every imported image before storage and cap decoded pixel count
  at 30 megapixels. Keep decoding off the UI isolate.
- [ ] Reject NUL-byte names, names longer than 255 bytes, traversal paths,
  symlinks, excessive entry counts, excessive compressed size, and excessive
  uncompressed size.
- [ ] Validate external UUIDs. Do not use an archive-supplied ID to overwrite
  a local trip or moment. Keep a separate import-origin identifier so a
  genuine re-import updates only its own imported book.
- [ ] Add `isImported` through a real Drift migration and make imported trips
  read-only in every relevant UI path.
- [ ] Ensure failure after photo processing cleans up photos written by that
  failed import.
- [ ] Add explicit import/export UI only after the service and repository are
  secure.

### Required tests

- Zip-slip, NUL-name, long-name, symlink, oversized, and entry-count archive
  rejection.
- Valid magic bytes with corrupt image data and a decode-bomb image rejection.
- Invalid external IDs receive safe local IDs.
- A malicious archive ID cannot overwrite a local trip or Everyday.
- Re-import updates the matching imported book without duplicating it.
- Imported trips remain read-only after an application restart.
- A mid-import failure leaves no extra rows or photo files.

### Required commits

1. `feat(data): track imported trip ownership`.
2. `build(data): regenerate Drift code`.
3. `fix(travelbook): validate archive structure and image content` — hostile
   archive tests included.
4. `fix(travelbook): isolate imported identities from local records` —
   collision and re-import tests included.
5. `feat(travelbook): render imported trips as read-only` — UI tests included.
6. `feat(travelbook): expose verified trip import and export` — end-to-end
   service tests included.

### Acceptance

- Every hostile-archive test is green.
- Importing a file can never change an unrelated local memory.
- Imported content is visibly and behaviorally read-only.

---

## Phase 4 — Complete the core memory journey

**Goal:** capture, correct, organize, browse, and share a moment without a
dead end.

### 4A. Capture resilience

- [ ] Show a plain-language permission explanation before camera/location
  requests.
- [ ] Handle image processing and database failures: reset the saving state,
  preserve the captured image when safe, and show a useful retry message.
- [ ] Add tests for no-location capture, empty caption, denied permissions,
  photo-store failure, and database failure.

**Commit:** `fix(capture): recover from save failures` with its tests.

### 4B. Moment actions

- [ ] Implement caption, place-label, date, and manual map-pin editing.
- [ ] Make “Add location” a real action.
- [ ] Implement either a real nearby-moment pager or remove that interaction
  entirely. Do not ship decorative pagination.
- [ ] Implement raw-photo sharing first. Add rendered card sharing and preview
  only after raw sharing works.
- [ ] Add widget/repository tests for edit, manual location, deletion, and
  sharing hand-off.

**Required commits:**

1. `feat(moment): edit moment metadata and location` — tests included.
2. `feat(moment): browse nearby moments` — pager tests included, or
   `fix(moment): remove nearby affordance`.
3. `feat(share): share raw moment photos` — service tests included.
4. `feat(share): preview rendered moment cards` — rendering/widget tests.

### 4C. Trips that can contain moments

- [ ] Require or edit trip dates at creation, and validate start ≤ end.
- [ ] Make the active-trip assignment rule visible and deterministic.
- [ ] Add move-to-trip for existing Everyday moments.
- [ ] Add trip edit, delete, cover, and planned-trip states only after
  assignment works.
- [ ] Test date-boundary assignment, no-date behavior, moving moments,
  deletion, and cover validation.

**Required commits:**

1. `feat(trips): create dated trips and validate ranges` — tests included.
2. `feat(trips): assign and move moments between trips` — tests included.
3. `feat(trips): edit trip details and cover` — tests included.

### Acceptance

- A user can take a photo without GPS, later add its pin and label, organize
  it into a trip, reopen it, and share it.
- A newly created trip can receive moments through a documented, tested rule.

---

## Phase 5 — Honest, efficient map caching

**Goal:** cached map tiles do not cause unnecessary requests and offline state
is understandable.

### Tasks

- [ ] Revalidate only stale entries. A fresh cache hit must make no network
  request.
- [ ] Reuse a bounded HTTP client and add a request timeout; do not create a
  client per tile.
- [ ] Clearly distinguish cached-map availability from a fully offline map.
  A cold offline install must show a useful empty-map state, not imply that a
  basemap was bundled.
- [ ] Preserve stale tiles after failed revalidation and retain the age stamp.
- [ ] Profile startup and large-library behavior before changing repository
  loading. Only fix the current N+1 photo lookup if profiling shows a user
  visible regression; use one joined/batched query, not a new cache layer.

### Required tests

- Fresh cached tile returns immediately and does not invoke the network.
- Stale cached tile returns immediately, revalidates in the background, and
  survives a failed request.
- Missing tile offline returns the neutral placeholder and a truthful status.
- Cache ceiling evicts the least-recently-used tile.

### Required commits

1. `fix(map): skip revalidation for fresh tiles` — network-spy test included.
2. `fix(map): bound tile requests and reuse client` — timeout tests included.
3. `feat(map): explain unavailable offline map areas` — widget tests included.
4. `perf(data): batch moment photo loading` — only if profiling justifies it;
   benchmark and regression test included.

### Acceptance

- Revisiting a map area within 30 days creates no tile traffic.
- Airplane mode remains usable for cached areas and honest for uncached ones.

---

## Phase 6 — Release closeout

**Goal:** the app, tests, docs, and release artifact agree.

### Tasks

- [ ] Persist or remove settings toggles that currently do nothing.
- [ ] Make “Clean up” report and run the existing orphan sweep, with a clear
  result message and test coverage.
- [ ] Update README, in-app copy, and `IMPLEMENTATION_PLAN.md` checkboxes to
  reflect only completed behavior. Keep historical entries; add a dated note
  instead of rewriting history.
- [ ] Run the full suite, release build, merged-manifest verification, archive
  round trips, and manual Android device checklist.
- [ ] Verify the actual signed ARM64 APK installs and supports: onboarding,
  capture with/without GPS, edit location, trip assignment, backup/restore,
  travelbook import/export, cache behavior, and theme switching.

### Required commits

1. `fix(settings): make storage controls functional` — tests included.
2. `docs: reconcile product claims and implementation status`.
3. `build(release): record verified pilot artifact` — only after every gate is
   green; do not commit APKs or signing material.

### Final release gate

All items must be true:

- [ ] `dart format .` makes no changes.
- [ ] `flutter analyze` is clean.
- [ ] `flutter test` is green, including every new security and data test.
- [ ] Release APK build succeeds for ARM64.
- [ ] Release APK is not debug-signed.
- [ ] Merged manifest passes the Phase 1 verification check.
- [ ] Backup/restore and travelbook round trips pass on a physical Android
  device.
- [ ] README and visible UI contain no unimplemented claims.
- [ ] `git status --short` is empty.

## Deferred until after the pilot is trustworthy

- Custom bundled/vector map tiles.
- More chart types or performance caching beyond measured needs.
- Advertising or an ad SDK.
- Accounts, sync, social features, or cloud backup.

The shortest path to a better app is completing these existing promises, not
adding another product layer.
