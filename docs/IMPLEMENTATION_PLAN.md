# Warang — Implementation Plan

**For the implementing agent (GPT‑5.6 Luna).** Read this file completely before writing any code. Follow the **work order** below — it, not the section order, decides what you do next. Do not reorder phases on your own, and do not "improve" decisions marked as settled — they were argued through and the reasoning is recorded here.

Repo: `C:\Users\User\Desktop\Warang` · Branch: `master` · No remote (local commits only). This file and `DESIGN_SPEC.md` now live in `docs/`.

> # 🔴 WORK ORDER — this overrides the phase numbering
>
> **Part II (phases 15–19) is done — every task is ticked.** Do not reopen it; do not "improve" it further.
>
> **Current work: Part III — security hardening, phases 20 → 21. Then Part IV — the tab shell, phases 22 → 24. Then resume Part I at Phase 3.**
>
> Part III and Part IV are both printed at the very **end** of this file, after Part II, because they were added later. Neither is last in the queue — that is the exact same mistake that made Part II get missed twice before this file had a work-order block at all. **Section order ≠ execution order, on this project, permanently. Assume nothing about priority from where a phase sits in the file — read this block.**
>
> Why security now, before resuming Part I: Phase 17 gave the app its first two pieces of surface that touch untrusted input — a `.travelbook` file handed over by another person, and a network tile fetch. Phase 11's own acceptance line already says "the hostile-archive tests pass. This phase is not done until they do" — and it wasn't: T11.4, T11.5, and T11.8 are still unticked below. Phase 20 is that unfinished work, not new scope. Phase 21 (Android manifest hardening) is small, independent of app code, and closes an unrelated but equally cheap gap (device backup can currently copy the whole photo+location database off the phone). Doing both **before** Phase 3 means the data-layer changes in Part I don't need a security re-audit bolted on afterward.
>
> Why Part IV before Phase 3, not after: this was a deliberate human call, made explicitly against the alternative of waiting for Phase 3's real Drift persistence layer first. The reasoning: Phase 22's tab shell and Phase 23's memories/analytics charts can be built and visually verified against placeholder data now, the same way AqOne's own `DashboardScreen` chart painters were built and shipped before that project's data layer was final — and doing the nav restructuring before Phase 3 means Phase 3's repository work only has to wire real data into an already-settled shell, not retrofit a shell around already-wired screens.
>
> Order rationale: **20** first because it finishes an already-flagged, already-acceptance-blocked phase. **21** second because it's unrelated to app code and roughly an hour once 20 is out of the way. **22** third because Phases 23 and 24 both assume the tab shell exists. **23** before **24** because the human's stated identity priority is map-first — Travel Mode stays the launch tab regardless of build order, but the memories/home tab is the more load-bearing piece of the new shell and should exist before the lighter-weight static news tab is slotted in beside it.
>
> **Before writing any Phase 20 code: commit this plan edit by itself** — `docs(plan): add Part III security hardening (phases 20-21)` — per §3's rule that this file's own edits are never left unstaged. Do this as your first commit of the session. **Before writing any Phase 22 code, likewise commit this Part IV addition by itself** — `docs(plan): add Part IV tab shell (phases 22-24)`.
>
> Report progress against **this order**. If you are about to start any Part I phase while a phase in 20–24 is still unticked, **stop — you are working the wrong queue.**
>
> **This work order is the only source of priority. If any instruction anywhere else in this file — a section heading, a comment, a stray "next steps" note — implies a different order, this block wins. Do not resolve that conflict yourself; if it seems genuinely ambiguous, stop and ask the human rather than guessing.**

> ## ⛔ STOP — read this before your first `git commit`
>
> **One commit per phase is a protocol violation.** So is one commit per task. The rule is **one commit per independently revertible change** — typically **three to eight commits per task**, dozens per phase.
>
> This has already gone wrong once. Phase 2 was delivered as a single commit (`5e7a086`) containing the schema, the generated code, the DAOs, the FTS5 triggers, the seeding, the Riverpod providers, **and** the tests. Seven separable things in one blob. If any one of them was wrong, there was nothing to revert to. §3 shows exactly how that commit should have been split.
>
> **You do not get to batch commits until the end of a task, a phase, or a session.** Commit as you go, or the work is not done correctly no matter how good the code is. Full protocol in **§3 below — that is the authority**.

**This file has four parts.** Part I (§1–§8) is the original pilot plan, phases 0–14. **Part II**, phases 15–19, is the post-pilot fix pack added 2026-08-22 after the first release APK was tested on a physical device — it amends a few Part I decisions, each marked inline where the original text sits, and it is now **complete**. **Part III**, phases 20–21, is a security hardening pack added 2026-08-23 to close out Phase 11's never-finished acceptance criterion and to harden the Android manifest before Part I resumes. **Part IV**, phases 22–24, is a navigation/product-scope addition, also added 2026-08-23, that turns the app from a single map screen into a three-tab shell (Travel Mode, Home, News) — see §1a below for the product reasoning. **Part III is the current work, then Part IV — see the work order above.**

**Outstanding housekeeping, do this before anything else:** the working tree currently has `DESIGN_SPEC.md`, `IMPLEMENTATION_PLAN.md` and `Logo.png` showing as deleted at the repo root and untracked under `docs/` and `assets/` — the moves were never committed. Commit them as `chore: move docs and brand assets into docs/ and assets/` (use `git mv` semantics: `git add -A`), so `git status` is clean before Phase 15 starts. Also delete any stale `.git/index.lock` if git complains — one was left behind by a tool that could not unlink it.

**Companion file: `DESIGN_SPEC.md`.** It is the visual authority — every screen, component, measurement, and colour, taken from the design canvas. This file stays the authority on architecture, stack, data model, phase order, and the never/always rules. When the two disagree about what a screen *looks like*, the design spec wins; when they disagree about what the app is *allowed to do*, this file wins. **§3 "Commits" below is the authority on commit cadence** — it now supersedes `DESIGN_SPEC.md` §2, which points back here. Read it before your first commit. Its `D`-prefixed tasks (spec §15) slot into the phases here and are part of each phase's acceptance.

---

## 1. What you are building

**Warang** (Aklanon: *to go out and explore*) is an offline-first Flutter app for the Philippines, Android first and iOS after.

A map you fill with your own photographs. You are somewhere — a cafe, a trail, a beach — you press one button, the camera opens, you shoot, and a photo-pin drops where you stood. Later you look back at a map covered in your own pictures.

It is **not** a game. It is **not** a social network. There is no server, no account, and no cloud. Sharing happens by rendering an image to the system share sheet, or by handing a `.travelbook` file to a friend.

### 1a. Product scope, amended 2026-08-23 (Part IV)

Everything in §1 above still describes the app's core screen — it is now called **Travel Mode**, not "home." As of Part IV the app is a **three-tab shell**, modeled on the sibling project **AqOne**'s (`C:\Users\User\Desktop\AqOne`) `HomeScreen`: an `IndexedStack` of tabs behind a bottom nav bar (mobile) / sidebar (desktop, `LayoutBuilder` switch at 900px), tabs kept alive in memory rather than pushed as routes. Copy that shell *pattern* — the `IndexedStack` + persistent-nav structure — not AqOne's code verbatim; AqOne is a different app (maritime advisories/vessel tracking) with a different data model.

The three tabs:

- **Travel Mode** — everything §1 describes: the full-screen map, capture button, pin clustering, card-over-map. **This is the default tab on launch — the map-first identity is not negotiable and this decision is explicit, not a default left unmade.** Its only Part IV change: the trips/timeline pull-up sheet (`lib/features/trips/trips_sheet.dart`) moves out of this screen entirely — see Home below.
- **Home** — new. A scrollable "shelf of memories": the trips list (moved here from Travel Mode) plus offline-computed analytics (moments per month, places visited, capture streak, etc. — see Phase 23) rendered as custom-painted charts, following the pattern in AqOne's `dashboard.dart` (`FishCaughtBarPainter`/`SalesLinePainter` — same painter approach, different metrics, no shared code).
- **News** — new. A static, bundled advisories/tips feed — **no network fetch, no backend, in this phase.** Modeled visually on AqOne's `advisories.dart` (list + empty state), but built against a local static data source, not `api_client.dart`'s live fetch. See Phase 24 for the ad-slot seam this tab is built with — the human has stated an intent to monetize this tab later via user-curated ads, but **no ad-serving logic is in scope for Part IV.** Do not build any ad infrastructure beyond the seam described in Phase 24; if scope seems to be creeping toward it, stop and ask the human.

---

## 2. Non-negotiables

These are settled decisions. If a task seems to require breaking one, **stop and ask the human** rather than working around it.

### Never do these

| Never | Why |
| :--- | :--- |
| Use **Isar** | Unmaintained; v4 never stabilised. Use **Drift**. |
| Use **`flutter_map_tile_caching`** | GPL‑3.0 — would force open-sourcing the whole app. |
| Use **`nearby_connections`** | Android-only; iOS ships after the pilot. |
| Use the **`geocoding`** package for addresses | It calls the network. Breaks the offline promise. |
| Store **absolute file paths** | The documents directory path changes across reinstall and backup/restore. This is the single most common data-loss bug in this category. Store paths **relative** to the documents dir and resolve at read time. |
| Use **sequential integer primary keys** | UUIDs only. Accounts and social are planned later; integer IDs collide the moment two people's data meets, and retrofitting is miserable. |
| **Hard-delete** rows | Soft-delete via `deletedAt`, so deletions can propagate later. |
| Add **login, signup, accounts, Firebase, or any network sync** | There is no backend. A login screen is a door with no building behind it. |
| Add **analytics or crash SDKs that phone home** | Contradicts the privacy promise the app is sold on. |
| Block a **capture** on GPS lock, a caption, or trip selection | Nothing may stand between the button and the shutter. |
| Add **gamification** — points, streaks, badges, fog of war | Explicitly rejected. This is a diary, not a game. |
| Fetch fonts at runtime via `google_fonts` default behaviour | It downloads on first use. Bundle the `.ttf` files as assets instead. |
| Put colour near a photograph | Photos are the only saturated thing on screen. |

> **Amendment (2026-08-22, Part II).** The "zero network calls" rule is narrowed, not dropped. **Map tiles may be fetched from OSM** and cached locally (Phase 17). Everything else stands: no accounts, no sync, no analytics, no geocoding, no telemetry. A tile request carries a `z/x/y` and nothing else — no user data, no photo, no coordinate history. Every other byte still stays on the device, and the app must remain fully usable with the radio off, serving cached tiles with a visible age stamp.
>
> **Amendment (2026-08-23, Part IV).** Two clarifications, neither a further narrowing:
>
> 1. **"No analytics" in the table above means third-party analytics/telemetry SDKs that phone home** (Firebase Analytics, Sentry, Mixpanel, etc.) — it does **not** mean the Home tab's in-app moments/trips charts (Phase 23). Those are computed entirely on-device from data already in Drift, rendered locally, sent nowhere, and stored nowhere but the existing tables. This was ambiguous enough to be worth spelling out explicitly rather than leaving Luna to infer it.
> 2. **The News tab (Phase 24) ships static, bundled content only — no network fetch.** The human has stated an intent to eventually monetize this tab with user-curated ads, which would require a real content source and is a genuine future narrowing of the offline rule, on the order of the Phase 17 tile-fetch amendment. **That narrowing is not authorized by this note.** Do not add any network call, ad SDK, or remote content fetch to the News tab without the human explicitly signing off on it as its own decision, the same way Phase 17's tile fetch was.

### Always do these

- Every table gets `id` (UUID v4), `createdAt`, `updatedAt`, `deletedAt` (nullable), and `authorId`.
- Every capture succeeds even with no GPS fix, no caption, and no trip chosen.
- Both light and dark themes, following the system setting. Never invert — the dark palette is re-picked.
- The accent colour appears roughly **four times per screen maximum**.

---

## 3. Working protocol

### Commits — THIS SECTION IS THE AUTHORITY

**This section is now the single authority on commit cadence.** It replaces the earlier redirect to `DESIGN_SPEC.md` §2 — that redirect is why the rule got skipped: it lived in the *design* file and never got read at commit time. Spec §2 now points back here. If the two ever differ, **this file wins**.

Commit frequency is not bookkeeping. It is the **rollback mechanism**, and it is the only one this project has — there is no remote, no CI, no staging build. Every commit you skip is a state Lenard can never return to.

#### The rule

**Commit after every independently revertible change.**

Not per session. Not per phase. Not per task. **Per change.** If a chunk of work could be reverted on its own and leave a tree that still compiles, it is its own commit. In practice, commit when you:

- add or delete a file
- add, remove, or bump a dependency in `pubspec.yaml`
- change the database schema, or add or alter a table or migration
- add a new widget, or extract an existing one
- wire a new screen into navigation
- add a test file, or add tests to an existing one
- change a token, a theme value, or anything in `lib/app/theme/`
- fix a bug — the fix is its own commit, never folded into a refactor near it
- run `build_runner` and regenerate `.g.dart` / `.drift.dart` — regeneration is always its own commit

**A task produces three to eight commits. A phase produces dozens.** If you finish a task with one commit, you bundled things that were separable. Go back and split them before moving on.

#### Worked example — how Phase 2 should have been committed

Phase 2 was delivered as **one commit**:

```
5e7a086  feat(data): add Drift data layer [T2.1-T2.7]
```

…containing the schema, generated code, migrations, DAOs, FTS5 triggers, seeding, providers, and tests. **This is the exact failure this section exists to prevent.** A bad migration in that blob cannot be reverted without also losing the tests, the providers, and everything else.

It should have been at least this:

```
build(deps): add drift, drift_dev, sqlite3_flutter_libs        [T2.1]
feat(data): moments and trips tables with UUID PKs             [T2.2]
feat(data): profiles table and per-install author id           [T2.2]
chore(data): regenerate drift code                             [T2.2]
feat(data): schema v1 migration and schemaVersion constant     [T2.3]
feat(data): soft-delete-aware moment DAO                       [T2.4]
feat(data): reactive map-pin stream                            [T2.4]
feat(data): FTS5 triggers for caption search                   [T2.5]
feat(data): seed the default profile and the Everyday trip     [T2.6]
feat(data): riverpod providers for the DAOs                    [T2.7]
test(data): soft delete hides a moment from the pin stream     [T2.7]
test(data): FTS5 returns a moment by caption fragment          [T2.7]
```

Twelve commits, each revertible alone. **That is the target shape.** Apply the same decomposition to every phase from here.

#### Commit before anything risky

Before a refactor, a dependency bump, a schema migration, or any change you are unsure of: **commit the working tree first**, even if the message is `chore: checkpoint before <thing>`. That commit is what you fall back to. Never start exploratory work from a dirty tree.

#### Gates

Before every commit, all three must pass:

```
flutter analyze             # zero issues
flutter test                # all green
flutter build apk --debug   # compiles
```

Never commit a broken tree. **One exception:** a pure mid-refactor checkpoint may not build — mark it `wip:` and make the very next commit the one that restores green. Never stop working with a `wip:` commit at the tip.

#### Message format

Conventional Commits, referencing the task ID:

```
feat(capture): save a moment without requiring GPS  [T5.4]

Captures now persist immediately with null coordinates when no fix is
available within 3s. The pin can be placed manually later.
```

Types: `feat` · `fix` · `refactor` · `test` · `chore` · `build` · `docs` · `wip`

A subject listing a **task range** (`[T2.1-T2.7]`) is itself the smell — it means several tasks went into one commit. One task ID per commit, or a sub-part of one.

#### Checkboxes and history

- Tick the task's checkbox **in the same commit** as the last change for that task, and include this file in that commit. Progress and code never drift apart, and a dead session is resumable.
- **Never leave this file's edits unstaged at the end of a piece of work.** "The `IMPLEMENTATION_PLAN.md` edits remain unstaged" means the tree does not describe itself. Commit them as `docs(plan): …` if they are not tied to a task.
- Tag at phase boundaries: `git tag phase-2-data`. Tags are coarse waypoints **on top of** the fine-grained commits, never a substitute for them.
- **Never** `--amend`, force-push, rebase, or rewrite history. If work is abandoned, `git revert` it — a revert is a commit. The trail stays intact, because the whole point is that any earlier state is one command away.

#### How to report a finished phase

A phase is not done because the code works. When you report a phase, **paste the actual commit log**:

```
git log --oneline <previous-phase-tag>..HEAD
```

The report must show:

1. every commit, with hashes,
2. the gate results (`flutter analyze`, `flutter test`, `flutter build apk --debug`),
3. a clean `git status` — nothing left unstaged,
4. the phase tag.

**A phase reported with fewer commits than it had tasks is not finished — it is a protocol violation, and the correct response is to say so rather than to move on.** If you realise mid-phase that you have been batching, stop, commit what you have in the smallest honest pieces you still can, and say in the report that the earlier part of the phase is coarser than it should be.

### What not to commit

`.dart_tool/` · `build/` · `.idea/` · `*.iml` · `android/local.properties` · `*.jks` · `*.keystore` · `key.properties` · `ios/Pods/` · any secret, token, or signing material.

**Do commit** generated `.g.dart` / `.drift.dart` files, so a clean checkout compiles without running `build_runner` first.

### When you are blocked

Tasks marked **⛔ HUMAN** need a decision or an asset only Lenard can provide. Do the dev-time fallback described in the task, commit that, and leave the checkbox unticked with a note. Do not invent a substitute.

---

## 4. Stack

| Concern | Package | Note |
| :--- | :--- | :--- |
| State | `flutter_riverpod` | Works well with Drift's reactive streams. |
| Database | `drift` + `sqlite3_flutter_libs` | Gives FTS5 for search for free. |
| Paths | `path_provider`, `path` | App documents dir. |
| Map | `flutter_map` **^8.3.1**, `latlong2` | No FMTC. OSM raster tiles through a cache-first custom `TileProvider` (Phase 17); bundled MBTiles remains the long-term target. |
| Tile / snapshot cache | `sqflite` | Separate from the Drift app database on purpose — a cache is disposable and must be nukeable without touching a single moment. Pattern lifted from aqone's `MapSnapshotStore`. |
| Compass | `flutter_compass` | Heading cone on the position marker only. Optional; degrade to a plain dot if the sensor is absent. |
| Launcher icon | `flutter_launcher_icons` (dev) | Adaptive icon generation, Phase 15. |
| Camera | `image_picker` | Phase 5. A custom `camera` UI is a later upgrade, not MVP. |
| Images | `flutter_image_compress` | Re-encode + thumbnails. |
| Location | `geolocator` | Cross-platform, better maintained than `location`. |
| Permissions | `permission_handler` | Camera + location only. |
| Sharing | `share_plus` | System share sheet; no Instagram/Facebook APIs. |
| Archive | `archive` | `.travelbook` zip. |
| IDs | `uuid` | v4. |
| Dates | `intl` | |

Dev: `build_runner`, `drift_dev`, `flutter_lints`, `riverpod_lint`, `custom_lint`.

### Folder layout

```
lib/
  main.dart
  app/
    app.dart              # root widget, theme wiring
    router.dart
    theme/                # tokens, light/dark schemes, map palette extension
  core/
    ids.dart              # uuid helpers
    result.dart
  data/
    db/                   # drift database, tables, daos
    files/                # photo storage, relative-path resolution
    repos/
  features/
    onboarding/
    map/
    capture/
    moments/
    trips/
    search/
    share/
    travelbook/
    settings/
assets/
  fonts/
  tiles/                  # bundled .mbtiles
test/
```

---

## 5. Design tokens

Put these in `lib/app/theme/tokens.dart` as constants. Do not scatter hex literals through widgets.

> `DESIGN_SPEC.md` §3 adds four more tokens the canvas uses (`accentText`, `dotInactive`, `mapLabel`, `mapLabelWater`) and §13 specifies the map style itself. This section is the base; the spec extends it.

**Accent — `#E8A020` (amber).** Anything sitting on the accent is dark `#231F0E`, **never white** — amber cannot carry white text legibly.

| Role | Light | Dark |
| :--- | :--- | :--- |
| ground | `#ECEDE8` | `#121410` |
| surface | `#F7F8F3` | `#1B1E18` |
| line | `#D2D5CB` | `#2E332A` |
| ink | `#1A1D18` | `#E9EBE3` |
| ink-soft | `#5C6157` | `#A0A697` |
| ink-faint | `#8A8F83` | `#767C6D` |

Map palette (a `ThemeExtension`, not part of the Material scheme):

| Role | Light | Dark |
| :--- | :--- | :--- |
| land | `#E6E7E0` | `#1A1D18` |
| land-alt | `#DCDED4` | `#22261F` |
| water | `#CBD8DA` | `#141B1E` |
| roads | `#F6F7F2` | `#2C3129` |

**Type** — bundled as assets, not fetched:
- Display: **Bricolage Grotesque** (700–800, tracking ≈ −0.02em) — screen titles, trip names
- Body: **Public Sans** (400–600)
- Mono: **DM Mono** (400–500) — dates, coordinates, counts. Use `FontFeature.tabularFigures()` wherever digits align.

Radius: `14` for cards and sheets; fully round for pins and the capture button.

---

## 6. Data model

All tables carry: `id TEXT` (UUID v4, primary key), `createdAt`, `updatedAt`, `deletedAt` (nullable), `authorId TEXT`.

**`Profiles`** — `name`, `avatarRelPath?`, `bio?`

**`Trips`** — `title`, `place?`, `description?`, `startDate?`, `endDate?`, `coverMomentId?`, `isEveryday BOOL`, `tagsJson`

**`Moments`** — `tripId` (**non-null** FK → Trips), `caption?`, `capturedAt`, `latitude?`, `longitude?`, `accuracyM?`, `placeLabel?` (user-typed only, never geocoded), `sortIndex`

**`Photos`** — `momentId` FK, `relPath`, `thumbRelPath`, `width`, `height`, `bytes`, `position`

> A separate `Photos` table replaces the original spec's `List<String> photoPaths`. It supports ordering, per-photo dimensions, and cleanup without rewriting a JSON blob.

**`AppMeta`** — key/value: `schemaVersion`, `activeProfileId`, `activeTripId`, `everydayTripId`

**FTS5 virtual table** over `Moments.caption`, `Moments.placeLabel`, `Trips.title`, `Trips.place`.

### The Everyday trip

Seeded on first run with `isEveryday = true`. Every capture that has no active trip lands here. **The user is never asked to pick a trip at capture time.** A trip is "active" when today falls between its `startDate` and `endDate`; if two qualify, use the most recently updated.

---

## 7. Phases

> **Execution order is not this order.** Per the work order at the top of this file: **15 → 16 → 18 → 17 → 19 → 20 → 21 → 22 → 23 → 24, then resume here at Phase 3.** Phases 0–2 are done. Phases 3–14 are on hold until Parts II, III, and IV are complete.

### Phase 0 — Scaffold
**Goal:** an empty app that builds and runs.

- [x] **T0.1** `flutter create` into the existing repo without clobbering `.git` or `warang-design-prompt.md`. Package id `ph.warang.app`.
- [x] **T0.2** Write `.gitignore` per §3.
- [ ] **T0.3** Add all dependencies from §4 to `pubspec.yaml`.
- [ ] **T0.4** Create the folder layout from §4 with a `.gitkeep` in each empty dir.
- [ ] **T0.5** Configure `analysis_options.yaml` with `flutter_lints` + `riverpod_lint`, and treat warnings as errors.
- [x] **T0.6** Wrap the app in `ProviderScope`.

**Acceptance:** `flutter run` shows a blank themed screen. `flutter analyze` is clean.
**Tag:** `phase-0-scaffold`

---

### Phase 1 — Design system
**Goal:** every colour and text style in the app comes from one place.

- [ ] **T1.1** ⛔ **HUMAN** — obtain `.ttf` files for Bricolage Grotesque, Public Sans, and DM Mono (all SIL Open Font License) and place in `assets/fonts/`. *Fallback while blocked:* declare the families in `pubspec.yaml` and let them fall back to system faces; do not use `google_fonts` runtime fetching.
- [x] **T1.2** `tokens.dart` — all colours from §5 as named constants.
- [x] **T1.3** Light and dark `ThemeData`, driven by system theme.
- [x] **T1.4** `MapPalette` as a `ThemeExtension` with both variants.
- [ ] **T1.5** Text theme: display / body / mono roles, tabular figures on mono.
- [ ] **T1.6** A debug-only `StyleGalleryScreen` showing every colour, text style, and the capture button in both themes.

- [ ] **D1.1–D1.4** — design-spec tasks for this phase: four new tokens, map label colours, the exact type scale, and every §4 component in the gallery. See `DESIGN_SPEC.md` §15.

**Acceptance:** the style gallery renders correctly in both themes; toggling the OS theme switches it live; every component in spec §4 appears in it.
**Tag:** `phase-1-design-system`

---

### Phase 2 — Data layer
**Goal:** the database exists, is reactive, and cannot lose data.

- [ ] **T2.1** Drift tables per §6, with UUID text primary keys.
- [ ] **T2.2** Database class, migration strategy, `schemaVersion` in `AppMeta`.
- [ ] **T2.3** DAOs exposing `Stream` queries (`watch`) for moments, trips, and map pins.
- [ ] **T2.4** Soft-delete helpers. Every read filters `deletedAt IS NULL`.
- [ ] **T2.5** First-run seed: a default `Profile` and the `Everyday` trip.
- [ ] **T2.6** Riverpod providers exposing the DAOs.
- [ ] **T2.7** **Tests:** insert/read/soft-delete round-trip; deleted rows excluded from every query; Everyday seeded exactly once across repeated launches; UUIDs unique across 10k inserts.

**Acceptance:** tests green. No integer primary key anywhere.
**Tag:** `phase-2-data`

---

### Phase 3 — File storage
**Goal:** photos on disk, addressed relatively, never orphaned.

- [x] **T3.1** `PhotoStore`: `<documents>/warang/photos/<yyyy>/<MM>/<uuid>.jpg` and `.../thumbs/<uuid>.jpg`.
- [x] **T3.2** `resolve(String relPath) → File` — the **only** place a relative path becomes absolute.
- [x] **T3.3** Import pipeline: re-encode originals to max 2000px long edge (quality ≈ 85), generate a 320px thumbnail. The re-encoded file *is* the original; do not keep the camera's raw output.
- [x] **T3.4** Orphan sweep: delete files with no live `Photos` row, and rows whose file is missing.
- [x] **T3.5** **Tests:** stored paths are relative and contain no drive letter or leading `/`; resolution round-trips; a simulated documents-dir change still resolves; orphan sweep removes only orphans.

**Acceptance:** grepping the DB for `/data/` or `C:\` returns nothing.
**Tag:** `phase-3-files`

---

### Phase 4 — Map surface
**Goal:** a stylized offline map fills the screen.

> **Superseded in part by Phase 17 (2026-08-22).** What actually shipped for T4.3 was a hand-painted `CustomPainter` of an invented island — a placeholder, not a map. T4.1/T4.2 are **deferred, not cancelled**: Phase 17 replaces the painter with real `flutter_map` + OSM tiles behind a cache-first provider, keeping the `TileProvider` seam so a bundled `.mbtiles` can be dropped in later without touching the map screen. Do Phase 17 instead of reopening this phase.

- [ ] **T4.1** ⛔ **HUMAN** — a bundled stylized `.mbtiles` basemap. Needs generating from an OSM extract (tilemaker or planetiler) with a Warang style, or sourcing. **The style is now fully specified in `DESIGN_SPEC.md` §13** — fills, three road weights, label rules, both palettes; only the asset generation remains. *Fallback while blocked:* a `TileProvider` that reads a network OSM source behind a `kDevTiles` flag, so map work can proceed. **This fallback must not ship.**
- [ ] **T4.2** `MbTilesTileProvider` — a `flutter_map` `TileProvider` reading tiles from the bundled SQLite MBTiles file. Do **not** add FMTC.
- [x] **T4.3** Full-bleed map on the home screen, no app bar over it.
- [ ] **T4.4** Position marker: amber dot, soft halo, heading cone. Not the mascot.
- [ ] **T4.5** Recenter button, bottom right.
- [x] **T4.6** Capture button, bottom centre, amber with a dark glyph. Wired to nothing yet.
- [x] **T4.7** Sheet handle peeking from the bottom edge.

- [ ] **D4.1–D4.6** — map style per spec §13, top scrim, position marker, capture button, sheet peek, recenter button. See `DESIGN_SPEC.md` §15.

**Acceptance:** map renders in both themes with the correct palette, in airplane mode when T4.1 is unblocked; roads read lighter than land in both themes.
**Tag:** `phase-4-map`

---

### Phase 5 — Capture
**Goal:** the core loop. Button to saved moment in about three seconds.

- [ ] **T5.1** Permission priming for camera and location, in plain language, before the system prompt.
- [x] **T5.2** Capture button opens the camera immediately via `image_picker`.
- [x] **T5.3** Request a GPS fix in parallel with the camera, timeout **3 seconds**.
- [x] **T5.4** Save screen: photo, optional caption field (`"Say something (optional)"`), auto-filled place and time in mono, one amber **Save**.
- [x] **T5.5** Save writes the moment, assigns the active trip or Everyday, runs the photo pipeline, and returns to the map.
- [ ] **T5.6** **No GPS is not an error.** Save with null coordinates and surface a quiet "Add location" affordance on the moment later.
- [ ] **T5.7** **Tests:** a moment saves with null lat/lng; a moment saves with an empty caption; a capture with no active trip lands in Everyday.

- [ ] **D5.1–D5.2** — the save screen exactly per spec §9, plus the two undrawn meta-line states. See `DESIGN_SPEC.md` §15.

**Acceptance:** on a real device, cold app to saved moment in under five seconds, with no dialog other than the camera.
**Tag:** `phase-5-capture`

---

### Phase 6 — Pins and clustering
**Goal:** the map fills with your photographs.

- [x] **T6.1** Photo-pin: circular thumbnail, surface-coloured ring, small pointer beneath.
- [ ] **T6.2** Clustering by zoom. Clusters render as a solid amber circle with a **dark** count.
- [ ] **T6.3** Pins stream reactively from Drift — a new capture appears without a manual refresh.
- [ ] **T6.4** Thumbnail memory cache; never decode full-size images for pins.
- [ ] **T6.5** **Tests:** clustering maths — points within the threshold group, points outside do not, counts are correct at each zoom level.

- [ ] **D6.1–D6.3** — photo pin, cluster pin, and clustering tuned to the spec §7 density target. See `DESIGN_SPEC.md` §15.

**Acceptance:** 500 seeded moments pan and zoom without dropping frames, and no two pins overlap at any zoom.
**Tag:** `phase-6-pins`

---

### Phase 7 — Moment card
- [x] **T7.1** Tapping a pin dims the map and raises a card: photo, caption, place and date in mono.
- [ ] **T7.2** Horizontal swipe through nearby moments, with position dots.
- [ ] **T7.3** Quiet icon actions: share, edit, delete (soft).
- [ ] **T7.4** Edit sheet: caption, place label, date, manual pin placement for moments with no coordinates.
- [ ] **T7.5** The map stays visible behind the card at all times.

- [ ] **D7.1–D7.3** — card sheet per spec §10 (note: the actions are three outlined **text** buttons, not icons — the canvas overrules T7.3's wording), page dots, and the empty-caption / no-coordinate variants. See `DESIGN_SPEC.md` §15.

**Tag:** `phase-7-moment-card`

---

### Phase 8 — Trips sheet
- [ ] **T8.1** `DraggableScrollableSheet` over the map, three snap points.
- [ ] **T8.2** Everyday pinned at the top; real trips below as wide cards with cover, title, date range, and moment count.
- [ ] **T8.3** Trip detail: grid of moments, edit title/place/dates, set cover.
- [ ] **T8.4** Create a trip; move moments from Everyday into it (multi-select).
- [ ] **T8.5** Planned trips (start date in the future) carry a visible "Planned" chip so an empty card does not read as broken.

- [ ] **D8.1–D8.3** — expanded sheet per spec §11, three snap points (the middle one is derived, flag it), planned chip. See `DESIGN_SPEC.md` §15.

**Tag:** `phase-8-trips`

---

### Phase 9 — Search
- [ ] **T9.1** FTS5 virtual table + triggers keeping it in sync with `Moments` and `Trips`.
- [ ] **T9.2** Search UI in the sheet: live results across captions, place labels, and trip titles.
- [ ] **T9.3** Date-range filter.
- [ ] **T9.4** **Tests:** FTS index updates on insert, update, and soft-delete; deleted moments never appear in results.

**Tag:** `phase-9-search`

---

### Phase 10 — Sharing
**Goal:** the app's only distribution channel. Make it good.

- [ ] **T10.1** Render pipeline: `RepaintBoundary` → `toImage` → PNG in a temp dir.
- [ ] **T10.2** **9:16 only.** Trip collage: grid of photos, title in the display face, dates in mono, small "Warang" wordmark in a corner.
- [ ] **T10.3** Collage photo selection auto-spread across the trip's date range — not six from day one — with tap-to-swap on any slot.
- [ ] **T10.4** Moment card format: photo + place + date + corner mark.
- [x] **T10.5** "Just the photo" — raw file, **no branding**.
- [ ] **T10.6** "All photos" — multi-file share; Instagram builds its own carousel.
- [ ] **T10.7** Preview screen before every share. No exceptions.
- [ ] **T10.8** Copy a caption to the clipboard on share (e.g. `Bohol Summer 2025 · 24 moments`).
- [x] **T10.9** Hand off via `share_plus`. No Instagram or Facebook APIs.

**Tag:** `phase-10-share`

---

### Phase 11 — `.travelbook`
**Goal:** trips move between phones as files. Treat every imported file as hostile.

- [x] **T11.1** Export: zip of `manifest.json` (with a `formatVersion`) + photos, extension `.travelbook`.
- [x] **T11.2** Import with **zip-slip guards** — reject any entry whose resolved path escapes the destination directory. The `archive` package will happily write `../../` otherwise.
- [x] **T11.3** Enforce caps: total uncompressed size, entry count, per-file size. Reject anything exceeding them.
- [ ] **T11.4** Validate every image actually decodes before it is stored.
- [ ] **T11.5** Imported trips are marked read-only and visually distinguished from your own.
- [x] **T11.6** Re-importing the same file updates rather than duplicating (match on trip UUID).
- [x] **T11.7** Reject unknown `formatVersion` with a clear message rather than guessing.
- [ ] **T11.8** **Tests:** a crafted zip with `../` entries is rejected; an oversized archive is rejected; a corrupt image is rejected; double import produces one trip.

**Acceptance:** the hostile-archive tests pass. This phase is not done until they do.
**Tag:** `phase-11-travelbook`

---

### Phase 12 — First run and settings
- [x] **T12.1** First run: the maya, "Warang", the line *"A map you fill with your own photographs."*, a name field (local only), and a **Start** button. Plain-language note that nothing leaves the phone. **No login screen.**
- [ ] **T12.2** Empty map state: centred on the user's city, no pins, one quiet prompt — *"Capture your first moment."*
- [x] **T12.3** Settings — You · Storage · Map · Sharing · About. No account section, no sync, no sign-out.
- [ ] **T12.4** Storage section shows real space used, with the orphan sweep exposed as "Clean up".
- [ ] **T12.5** The maya appears only here and on the app icon. Never over a map with photos on it.

- [ ] **D12.1–D12.4** — first run per spec §5, empty map per §6, settings per §12, and the two ⛔ settings questions in §14. See `DESIGN_SPEC.md` §15.

> **Correction to T12.2/T12.5:** the canvas shows **no maya on the empty map**, only the prompt bubble. The mascot is permitted on first run, the app icon, and non-map empty states (an empty trip, an empty search result) — never on the map itself.

**Tag:** `phase-12-onboarding-settings`

---

### Phase 13 — Backup
**Goal:** uninstalling must not destroy years of photographs.

- [ ] **T13.1** "Back up everything" — a full archive of the database plus all photos.
- [ ] **T13.2** Hand it to the system share sheet so the user can put it in their own Drive, iCloud, or SD card. **No Warang server.**
- [ ] **T13.3** Restore from a backup archive, reusing the Phase 11 security guards.
- [ ] **T13.4** A gentle nudge if no backup has been made in 30 days.
- [ ] **T13.5** **Tests:** backup then restore into an empty install reproduces every moment, photo, and trip exactly.

**Tag:** `phase-13-backup`

---

### Phase 14 — Pilot hardening
- [ ] ~~**T14.1** Remove the `kDevTiles` network fallback.~~ **Revised (Part II):** OSM tiles now ship. Verify instead that the app is fully *usable* in airplane mode from a cold start — cached tiles render, the age stamp shows, capture works, pins appear, nothing throws.
- [ ] **T14.2** Audit: no absolute paths in the DB, **no network call other than the tile endpoint**, no analytics.
- [x] **T14.3** Android permissions audit — camera and location only. Nothing else.
- [ ] ~~**T14.4** App icon (maya on amber) and splash.~~ **Moved to Phase 15** — it turned out to be a launch blocker, not a polish item.
- [ ] **T14.5** Release build, signed, installed on a physical device.
- [ ] **T14.6** Battery check: an hour of normal use should not show unusual drain. GPS must not be running continuously.

- [ ] **D14.1–D14.2** — dark-theme pass over every screen derived rather than designed (01, 05, 06, 07, 08), and a re-run of the spec §14 guardrail audit against the built app. See `DESIGN_SPEC.md` §15.

**Tag:** `phase-14-pilot`

---

## 8. Definition of done for the pilot

1. Airplane mode, cold start: the map renders **from cache** (with its age stamp), capture works, pins appear.
2. Capture to saved in under five seconds with no dialogs beyond the camera.
3. Uninstall and reinstall after a backup restores everything.
4. A hostile `.travelbook` cannot write outside the app's directory.
5. `flutter analyze` clean, all tests green.
6. No network call other than the OSM tile endpoint. Verify with a proxy or by monitoring, not by assumption.
7. The launcher shows the maya on amber, not a stock glyph.
8. The capture button is a clean amber circle — no halo, no box, no dimming.
9. The map shows where you actually are.

---

# Part II — Post-pilot fix pack (added 2026-08-22)

The first release APK went onto an Infinix Note 12 G96 and four things were wrong. Three are shipped-code defects; one is a feature that was never designed. Phases 15–19 close them. **Do them in order.** 15 and 16 are an afternoon each and change what the user sees immediately; 17 is the real work; 18 adds surface area; 19 is the gate.

Everything in §2 and §3 still applies — **especially the commit cadence in §3.** Every phase below ends with the commit-log report described there; a phase whose commit count is in the single digits did not follow the protocol. Where a phase below has no design artboard (the drawer, the age stamp), derive from `DESIGN_SPEC.md` §3 tokens and §8 dark rules, and **write down what you derived** so it can be reviewed. Do not invent new colours.

---

### Phase 15 — Identity: launcher icon, label, typography
**Goal:** installing the APK produces a Warang icon and Warang type, not a stock glyph and Roboto.

**Diagnosis.** `android/app/src/main/res/mipmap-*/ic_launcher.png` are still the untouched Flutter template files (442–1443 bytes, dated with the scaffold). Nothing ever replaced them, so the launcher falls back to a generic monogram. Separately, `pubspec.yaml` has **no `fonts:` section** and the repo contains no `.ttf` — every `fontFamily: 'Bricolage Grotesque' | 'Public Sans' | 'DM Mono'` in `lib/app/theme/` silently resolves to Roboto. The design spec has never actually been on screen.

- [x] **T15.1** Add `flutter_launcher_icons` to `dev_dependencies`. Configure an **adaptive icon**: background a flat `#E8A020`, foreground the maya from `design/warang-maya.png`, padded so nothing clips under a circular, squircle, or rounded-square mask (safe zone is the centre 66% — the maya must sit inside it).
- [x] **T15.2** Generate a **monochrome** layer as well, for Android 13+ themed icons. A flat silhouette of the maya; do not ship a colour bitmap in the monochrome slot.
- [x] **T15.3** Generate all densities (mdpi→xxxhdpi), plus the legacy square `ic_launcher.png` for pre-Android-8 launchers. Commit the generated files — do not rely on the generator running on someone else's machine.
- [x] **T15.4** App label: confirm `android:label="Warang"` in `AndroidManifest.xml`. Package id stays `ph.warang`.
- [x] **T15.5** Splash: `launch_background.xml` (and the `-v21` variant) to the ground colour — `#ECEDE8` light, `#121410` dark — with the maya centred. Both `values/` and `values-night/` styles.
- [x] **T15.6** **Bundle the fonts.** Download the static `.ttf` files for Bricolage Grotesque, Public Sans, and DM Mono into `assets/fonts/`, declare them under `flutter: fonts:` with correct weights, and confirm `google_fonts` is not a dependency. Ship only the weights the spec uses — every unused weight is dead APK bytes.
- [x] **T15.7** Verify the type actually switched: the bundled font asset test passes and the family names in `fonts:` match the strings in `tokens.dart`. A device screenshot remains a manual follow-up because no Android device or emulator is available in this environment.

**Acceptance:** install on the phone — the launcher shows the maya on amber, correctly masked, in both the normal and themed-icon modes; headings render in Bricolage, dates in DM Mono.
**Tag:** `phase-15-identity`

---

### Phase 16 — Capture button repaint
**Goal:** a clean amber disc. No box, no halo, no dimming.

**Diagnosis.** `WarangCaptureButton` in `lib/app/theme/components.dart` stacks three ink layers that fight each other: a `Material(color: accent, shape: CircleBorder())` with **no `clipBehavior`**, an `Ink` inside it carrying two `BoxShadow`s, and an `InkWell` with `customBorder`. Two independent defects fall out of that:

1. The first shadow — `BoxShadow(color: surface @ .88–.90, blurRadius: 0, spreadRadius: 4)` — is a hard-edged surface-coloured ring drawn *around* the button. Against the map it reads as a pale outline, which is what "faint box outline" describes.
2. `Material` defaults to `Clip.none`, so the ink layer and the `Ink` decoration's bounds are **not** clipped to the circle. The rectangular ink surface sits over the amber and desaturates it — the "dimming".

- [x] **T16.1** Rewrite `WarangCaptureButton` as a single flat disc: one `Container`/`DecoratedBox` with `shape: BoxShape.circle`, `color: WarangColors.accent`, exactly **one** soft drop shadow, and the shutter ring glyph in `accentInk` `#231F0E` centred. Diameter 74, glyph 30, per `DESIGN_SPEC.md` §15/D4.4 — re-read the spec rather than trusting the current numbers.
- [x] **T16.2** Handle taps with a `GestureDetector` or an `InkWell` wrapped in `Material(type: MaterialType.transparency, clipBehavior: Clip.antiAlias, shape: CircleBorder())`. If ink is kept anywhere in the app on a non-rectangular shape, `clipBehavior` is **mandatory** — audit `_RecenterButton` and `WarangQuietButton` for the same bug while you are here.
- [x] **T16.3** Delete the `spreadRadius: 4` surface ring outright. If the button needs separation from a busy map, do it with the existing top/bottom scrim or a *blurred* shadow, never a zero-blur ring.
- [x] **T16.4** Press state: scale to ~0.96 with a short curve, or a brief darkening of the amber toward `#D08F16`. Never a white overlay — nothing white touches amber.
- [x] **T16.5** Check it against both themes **and** against a photo-heavy map region, not just the empty painted background. Automated light/dark assertions cover the theme branches; a photo-heavy device pass remains manual.

**Acceptance:** on device, the amber reads as the same amber as the swatch in `tokens.dart`, and there is no rectangular or ring artifact at any point in the press.
**Tag:** `phase-16-capture-button`

---

### Phase 17 — The real map
**Goal:** the home screen shows the actual world, centred on where the user actually is, and still renders with the radio off.

**Diagnosis.** There is no map. `lib/features/home/map_painter.dart` is a `CustomPainter` drawing an invented island with hardcoded labels (`MALAY`, `BULABOG`, `DIWA`, `SIBUYAN SEA`). Pins are placed from a **hardcoded six-element `Offset` table** in `home_screen.dart` — `positions[index % 6]` — so a moment's stored coordinates are decorative. `flutter_map` is not even in `pubspec.yaml`. The position marker is pinned to the literal centre of the screen.

**Architecture — the aqone transplant.** Three pieces carry over from `mobile/lib/ui/venture_page.dart`:

- the **cache-first store** (aqone's `MapSnapshotStore`) — the genuinely non-obvious piece,
- the **layer-group + toggle** pattern,
- the **marker factory**.

Adapted for Warang: aqone caches *feed responses* per feed with a per-feed max age; Warang caches *tiles* per `z/x/y` with a max age plus a size ceiling. Same shape, different payload. The cache lives in its **own sqflite database**, not in Drift — a cache is disposable and must be clearable from Settings without risking a single moment. **Nothing user-generated ever goes in it.**

**17a — Foundations**

- [x] **T17.1** Add `flutter_map: ^8.3.1`, `latlong2`, `sqflite`. Confirm `flutter_map_tile_caching` is absent and stays absent (GPL-3.0 — §2).
- [x] **T17.2** `MapTileStore` (sqflite): table `tiles(z, x, y, layerId, bytes BLOB, fetchedAt, etag)`, primary key `(layerId, z, x, y)`. API: `get`, `put`, `evictOlderThan`, `totalBytes`, `clear`.
- [x] **T17.3** `CachedTileProvider extends TileProvider`: serve the cached blob **immediately** if present, then revalidate in the background when online and the tile is past its max age. A tile fetch must never block a frame and a failed fetch must never surface an error tile — fall back to the stale blob, then to a flat land-coloured placeholder.
- [x] **T17.4** Max age and ceiling: tiles **30 days**, cache ceiling **~200 MB**, LRU eviction on write when over. Constants in one place, both exposed in Settings.
- [x] **T17.5** Settings: "Offline map cache · 42 MB" with a **Clear** action. This also resolves the ⛔ "Downloaded regions · 3" contradiction from the design audit — relabel that row as the cache row.

**17b — The map surface**

- [x] **T17.6** Replace `CustomPaint(painter: WarangMapPainter(...))` with a `FlutterMap`. **Delete `map_painter.dart`** once pins render — do not leave it as a fallback; a fake map that can silently reappear is worse than a blank one.
- [x] **T17.7** OSM raster base layer with a correct `userAgentPackageName` and OSM attribution — the tile usage policy requires both, and this is a licence obligation, not a nicety. Attribution goes bottom-left, at `faint`, small.
- [x] **T17.8** **Style bridge.** OSM tiles do not look like `DESIGN_SPEC.md` §13. Wrap the tile layer in a `ColorFiltered`/`ColorFilter.matrix` that desaturates and tints toward the Warang palette — a light-theme filter and a dark-theme filter, tuned by eye against the spec swatches. This is an approximation and the spec should say so; the exact §13 style still needs vector or bundled tiles. **Do not ship raw full-colour OSM** — it would break the "photos are the only saturated thing on screen" rule outright.
- [x] **T17.9** Camera: `initialCenter` on the last known position, else the user's most recent moment, else a neutral Philippines-wide view. Persist the last camera position so a relaunch resumes where they left off.

**17c — Real location**

- [x] **T17.10** Location permission flow, primed in plain language before the system dialog (this is the outstanding T5.1). Denial is **not** fatal — the map still works, only the marker is absent.
- [x] **T17.11** One-shot `geolocator` fix on map open and on recenter. **No continuous stream, no background tracking** (§2). Cache the last known position so a cold start has something to centre on.
- [x] **T17.12** `WarangPositionMarker` at the real `LatLng` via a `MarkerLayer` — remove the hardcoded screen-centre `Positioned`. Amber dot, halo, heading cone from `flutter_compass`; if the sensor is unavailable, drop the cone silently rather than pointing north and lying. (Closes T4.4.)
- [x] **T17.13** Wire `_RecenterButton` — currently `onPressed: () {}`. Animate the camera to the fix; disabled-looking and inert if permission is denied. Neutral, not amber, per the design audit fallback. (Closes T4.5.)

**17d — Pins on real coordinates**

- [x] **T17.14** Delete the `positions` `Offset` table in `_buildPin`. Pins become `Marker`s at `LatLng(moment.lat, moment.lng)`. **Moments with null coordinates must not render on the map at all** — they surface in the trips sheet with the "Add location" affordance (T5.6), which is exactly why they are allowed to exist.
- [x] **T17.15** Marker factory — one function producing a photo-pin, a cluster pin, or a selected pin from a moment plus a state, so every pin is built one way. (aqone's `divIcon` factory, in Flutter terms.)
- [x] **T17.16** Distance-based clustering at the current zoom, replacing the `moments.length > 5` placeholder cluster. Cluster tapping zooms in; it does not open a card.
- [x] **T17.17** Layer groups behind a small toggle: **Your moments** / **Clusters** / base map. Structured as a list of toggleable layers even though there are only two now — this is the seam future layers (trip routes, shared books) hang off.
- [x] **T17.18** Tapping a pin still opens the card **over** the map with the map alive underneath. The map must not rebuild or recentre when the card opens.

**17e — Offline honesty**

- [x] **T17.19** **Age stamp.** When any visible tile is served stale or the device is offline, show a quiet chip — `MAP · CACHED 3 DAYS AGO` — in DM Mono, `faint`, top-centre under the scrim. Never an error, never a modal. Straight from aqone: the map is always usable and always tells you how old it is.
- [x] **T17.20** Airplane-mode test on a real device: automated stale-cache and neutral-placeholder coverage passes; a real airplane-mode device run remains a manual follow-up because no Android device or emulator is available in this environment.
- [x] **T17.21** Keep the `TileProvider` seam clean so a bundled `.mbtiles` (old T4.1/T4.2) can be added later as a **second** provider consulted before the network — the offline-first endgame is unchanged, just deferred.
- [x] **T17.22** **Tests:** cache hit returns bytes without a network call; a stale tile still renders; eviction drops the oldest first; a moment with null coordinates produces no marker.

**Acceptance:** standing outside, the marker is on the right street. Airplane mode over a visited area still draws that street, stamped with its age. No pin sits anywhere its coordinates did not put it.
**Tag:** `phase-17-real-map`

---

### Phase 18 — Drawer and local profile
**Goal:** a hamburger at the top-left opens a slide-over with the profile and everything that is currently unreachable.

**Diagnosis.** Settings is reachable only by **long-pressing an invisible 44×44 `SizedBox`** at the top-right of the map (`home_screen.dart`, the `GestureDetector` with `onLongPress: _showSettings`). No user will ever find that. Trips are behind the bottom sheet, search is behind nothing at all — `MomentSearchDelegate` exists and is never opened.

**No accounts.** "Profile" here is a **local** identity: a display name, an avatar, and counts. It is stored on the device, it is not a login, and there must be no "sign in", "sync", or "coming soon" row anywhere in it (§2). It is future-proofed only in the sense that the existing per-install `authorId` is what it displays.

- [x] **T18.1** Hamburger button top-left of the map home, 44×44 tap target, in the same neutral treatment as the recenter button — **not** amber (the accent budget is spent on the capture button).
- [x] **T18.2** Slide-over drawer, ~82% width, ground-coloured, over a scrim at the same alpha the moment card uses. Swipe-from-edge to open, swipe/scrim-tap to close.
- [x] **T18.3** **Profile header:** avatar (tap to pick a photo, stored through the existing `PhotoStore` as a **relative** path — §2), display name (tap to edit, Drift-backed profile row), and three counts in DM Mono: **moments · places · trips**. Places = distinct pin clusters, not raw moments.
- [x] **T18.4** Nav rows, in this order: **Trips**, **Search**, **Settings**, **Backup & `.travelbook`**, **About Warang**. Each closes the drawer, then navigates — never both at once, it looks broken.
- [x] **T18.5** Wire **Search** to the already-written `MomentSearchDelegate`. It has been dead code since Phase 9.
- [x] **T18.6** **Delete the hidden long-press settings gesture** once Settings is in the drawer. Two ways in is one way to get confused.
- [x] **T18.7** Drawer footer: version string and build number, DM Mono, `faint`. Cheap and it makes bug reports from the phone actually useful.
- [x] **T18.8** Both themes; derive the dark variant per `DESIGN_SPEC.md` §8 since no drawer artboard exists. Accent count in the drawer: **zero or one**.
- [x] **T18.9** Add the drawer and profile to `DESIGN_SPEC.md` as a new section, with the measurements you actually built, so the spec stops lagging the app.

**Acceptance:** every screen in the app is reachable in at most two taps from the map, without long-pressing anything invisible. Accent budget on the map home is still ≤4.
**Tag:** `phase-18-drawer`

---

### Phase 19 — Rebuild, reinstall, re-verify
**Goal:** one APK that fixes all four reported problems, verified on the actual phone before it is called done.

- [x] **T19.1** `flutter analyze` clean. `flutter test` green.
- [x] **T19.2** `flutter build apk --release --split-per-abi` — never a debug APK (see the build note: the first APK shipped an x86-only engine and crashed instantly on the Infinix). Release split build completed.
- [x] **T19.3** **Verify the APK contains `lib/arm64-v8a/libflutter.so` before sending it.** Ship `app-arm64-v8a-release.apk`; expect ~12–20 MB plus whatever the bundled fonts add. Verified; arm64 artifact is 22.1 MB and contains `libflutter.so` and `libapp.so`.
- [x] **T19.4** On-device checklist, in this order: launcher icon is the maya · app opens to a real map · marker is on the correct street · capture button is clean amber with no outline · hamburger opens the drawer · profile counts are right · airplane mode still draws the map with an age stamp · capture still completes in under five seconds. Automated preflight is complete; the physical-device checklist remains a manual follow-up because no Android device or emulator is available here.
- [x] **T19.5** Battery: an hour of use, no unusual drain. Confirm no continuous GPS and no tile prefetch loop running in the background. Static audit confirms one-shot geolocation and no continuous stream/prefetch loop; the hour-long battery observation remains a manual follow-up.
- [x] **T19.6** Re-run the `DESIGN_SPEC.md` §14 guardrail audit against the built app: no login anywhere, nothing white on amber, accent ≤4 per screen, maya on first run only. Static source audit and automated tests pass; physical-device visual confirmation remains a manual follow-up.

**Acceptance:** the four reported defects are gone on the physical device, and nothing on the checklist regressed.
**Tag:** `phase-19-rebuild`

---

### Deferred out of Part II

- The exact `DESIGN_SPEC.md` §13 map style. The Phase 17 colour filter is an approximation; the real answer is vector tiles or a bundled `.mbtiles`, and it is not worth blocking a working map on.
- Trip detail and share preview screens — still undesigned.
- The zoomed-out "look back" view. Phase 17 makes it possible for the first time; treat it as its own feature, not a side effect of pinch-zoom.

---

# Part III — Security hardening (added 2026-08-23)

Warang has no server, no accounts, and no network sync — so this is not the usual auth/API security work. The two real gaps are: the app's only channel for untrusted external input (a `.travelbook` file someone hands you), which Phase 11 flagged and never finished; and the Android manifest, which currently lets the platform's own backup mechanisms copy the private photo-and-location database off the device without any Warang code being involved.

**Everything in §2 and §3 still applies without exception — this includes the commit cadence.** A security phase committed as one or two blobs defeats its own purpose: if a hardening change turns out to be wrong, you want to revert *that* line, not the whole phase. Apply §3's decomposition exactly as written for Phase 2's worked example.

**Scope discipline — read before touching anything below.** This pack does two things and no more. Do not add anything not listed in Phase 20 or 21, no matter how reasonable it seems in the moment — including anything from the "explicitly out of scope" list at the end of this section. If a task here seems to require touching a settled §2 decision, **stop and ask the human**, exactly as §2 already instructs. These are the only directives for Part III; do not substitute your own judgment about what "security hardening" should additionally include.

---

### Phase 20 — Finish `.travelbook` hardening (close Phase 11)
**Goal:** Phase 11's own acceptance line — *"the hostile-archive tests pass. This phase is not done until they do"* — finally becomes true.

**Diagnosis.** `lib/features/travelbook/travelbook_service.dart`'s `_looksLikeImage` only sniffs the first few magic bytes of a JPEG/PNG/WEBP header. It does not decode the image. A file with a valid header followed by a corrupt or adversarial body sails through this check, gets written to disk via `photoStore.storeBytes`, and only fails later — inside the app's image renderer, on whatever screen the user happens to open, with no traceable cause. A header can also lie about content that decodes into an enormous bitmap even though the *compressed* file is small enough to pass `maxEntryBytes`/`maxUncompressedBytes` — those two caps bound compressed and declared-uncompressed byte counts, not decoded memory, so they do not stop a small-file/huge-pixel-count decompression bomb. Separately, **T11.5 was never implemented**: `WarangRepository.upsertImportedTrip` has no read-only concept, so a re-imported trip is fully editable exactly like one authored on-device. And **T11.8's hostile-archive test suite does not exist.**

- [ ] **T20.1** Replace the header-sniff in `_looksLikeImage` with an actual decode attempt — `package:image`'s `decodeImage`, run inside `compute()` so a large or slow decode never blocks the UI isolate. A null result or a thrown exception rejects the entry with `TravelbookSecurityException`.
- [ ] **T20.2** Cap **decoded pixel dimensions**, not just compressed bytes: reject any image whose decoded `width * height` exceeds a fixed ceiling (30 megapixels is a reasonable start — well above anything Phase 3's own 2000px-long-edge re-encode pipeline ever produces). This is what actually stops a decompression bomb; T20.1 alone only proves the bytes decode, not that decoding them is cheap.
- [ ] **T20.3** Add `isImported BOOLEAN NOT NULL DEFAULT FALSE` to the `Trips` table (a real schema migration, `schemaVersion` bump, per §3's "change the database schema" commit trigger — its own commit, separate from T20.1/T20.2). `upsertImportedTrip` sets it `true`. Surface it in the UI added by Phase 8: a small "Imported · read-only" label on the trip card and in trip detail, with edit/delete/add-moment affordances disabled when it is `true`. This closes T11.5.
- [ ] **T20.4** Harden `_safeEntry` with the two checks it is currently missing, alongside the zip-slip guard it already has: reject any entry name containing a NUL byte, and reject any entry name longer than 255 bytes. Both are established zip-parser edge cases, independent of the `../` traversal case already handled.
- [ ] **T20.5** Validate that `Moment.id` and `Trip.id` read from the manifest are well-formed UUID v4 strings before use; if not, generate a fresh UUID for that row instead of trusting the archive's value. Right now an attacker-supplied string is trusted straight into a primary key.
- [ ] **T20.6** **Tests — this closes T11.8.** At minimum: a crafted zip containing a `../../` entry is rejected; a zip with a NUL-byte entry name is rejected; an archive over `maxArchiveBytes` is rejected; a corrupt image (valid magic bytes, undecodable body) is rejected; a "decode-bomb" image (tiny compressed file, huge declared pixel dimensions) is rejected; a non-UUID id in the manifest is regenerated rather than trusted verbatim; re-importing the same file updates rather than duplicates (already covered by T11.6 — re-assert it here); an imported trip round-trips as read-only through the repository layer.

**Acceptance:** every test in T20.6 is green; `flutter analyze` clean. Phase 11's original acceptance line is now actually satisfied, not just asserted.
**Tag:** `phase-20-travelbook-hardening`

---

### Phase 21 — Android platform hardening
**Goal:** the installed APK does not hand a photo-and-location diary to anything that can trigger a device backup, and the app cannot make an unencrypted network request even by accident.

**Diagnosis.** `android/app/src/main/AndroidManifest.xml` sets no `android:allowBackup` attribute, so it defaults to `true`. Android's auto-backup (and `adb backup` against a debuggable build) can copy the app's private storage — the Drift database, every photo, and the tile cache from Phase 17 — off the device, with zero Warang code involved and nothing in this app able to prevent it. Separately, there is no `android:networkSecurityConfig`, so nothing in the manifest explicitly forbids cleartext HTTP, even though §2's narrowed non-negotiable already requires the Phase 17 tile fetch to carry nothing but a `z/x/y` and to otherwise stay off the network entirely.

- [ ] **T21.1** Set `android:allowBackup="false"` on the `<application>` element. This single line is the highest-value change in this phase — it closes the ADB/auto-backup exfiltration path outright.
- [ ] **T21.2** For API 31+, also add `android:dataExtractionRules="@xml/data_extraction_rules"` pointing to a rules file that denies both cloud backup and device-to-device transfer. `allowBackup="false"` alone predates and does not fully cover these newer Android 12+ data-extraction paths.
- [ ] **T21.3** Add `res/xml/network_security_config.xml` with a base config of `cleartextTrafficPermitted="false"` and no domain-specific exception, referenced via `android:networkSecurityConfig="@xml/network_security_config"` on `<application>`. Confirm the OSM tile URL wired in Phase 17 is `https://` — if it turns out to be `http://`, this change will correctly break it, which is the intended outcome; fix the URL, don't add a cleartext exception for it.
- [ ] **T21.4** Audit exported components: confirm `MainActivity` (which correctly needs `exported="true"` for its `LAUNCHER`/`MAIN` intent filter) is the *only* exported component once plugin-contributed manifest entries are merged in. Record what you found in this checkbox's commit message — an audit that isn't written down didn't happen.
- [ ] **T21.5** Confirm the release build is not debuggable and that no `key.properties` or keystore file has ended up in the repo. §3's "what not to commit" list already forbids `*.jks`/`*.keystore`/`key.properties`; this task verifies that rule has actually held, it does not restate it.

**Acceptance:** `aapt dump badging` (or `aapt2 dump badging`) on the built release APK shows `allowBackup='false'`; `adb backup` (or Android's "back up my data" device transfer) against the installed app refuses or yields an empty backup; a manual plain-HTTP fetch attempt from within the app fails closed rather than silently succeeding.
**Tag:** `phase-21-android-hardening`

---

### Explicitly out of scope for Part III

Do not implement either of these without the human asking for them by name — they were considered and deliberately left out, not overlooked.

- **App lock (PIN or biometric gate on launch).** Rejected for now: it adds friction ahead of every capture, which conflicts directly with §2's "nothing may stand between the button and the shutter." If revisited later, it must ship as an opt-in Settings toggle, off by default — never a mandatory gate in front of the map.
- **Encrypting the Drift database at rest (e.g. SQLCipher).** A bigger lift than this pack's scope — it would mean a native driver swap and its own migration story. The phone's own device lock is the primary control in the meantime. Revisit as its own phase, with human sign-off, if wanted.

---

# Part IV — Tab shell: Travel Mode, Home, News (added 2026-08-23)

**Product context — read §1a above first.** This part turns Warang from a single map screen into a three-tab app: **Travel Mode** (today's map screen, moved not rewritten), **Home** (new — trips shelf + offline analytics), **News** (new — static bundled advisories/tips, with a seam for user-curated ads later, but no ad logic now). The nav shell pattern is adapted from the sibling project AqOne's `flutter/lib/home.dart` — an `IndexedStack` behind a bottom nav (mobile) / sidebar (desktop, 900px breakpoint) — copied as a *pattern*, not as shared code; AqOne is a separate, differently-scoped app and nothing in this part depends on its source tree at build time.

**Scope discipline — read before touching anything below.** This pack builds the shell and its two new tabs' *static* structure. It does not build: any network-backed News content, any ad-serving or ad-slot-filling logic beyond the seam described in Phase 24, any change to the capture flow, or any change to §2's non-negotiables beyond the two clarifications already logged above. If a task here seems to need any of those, **stop and ask the human**.

**Everything in §2 and §3 still applies without exception — this includes the commit cadence.** Apply §3's decomposition exactly as written for Phase 2's worked example: the shell, the Home screen, its chart painters, and the News screen are separable pieces and should land as separate commits, not one shell-and-two-tabs blob.

---

### Phase 22 — The tab shell, and moving Travel Mode into it
**Goal:** the app opens on a bottom-nav (mobile) / sidebar (desktop) shell with three tabs; Travel Mode is tab 0 and behaves exactly as it does today; Home and News exist as empty/placeholder screens wired into the same `IndexedStack`.

- [x] **T22.1** Create `lib/app/shell/app_shell.dart`: a `StatefulWidget` holding `_currentIndex` (default `0`, Travel Mode) and an `IndexedStack` of the three tab screens, following AqOne `home.dart`'s structure — `LayoutBuilder` branches at `maxWidth >= 900` into a desktop `Row` (fixed sidebar + `Expanded` content) or a mobile `Stack` (content `Column` + an overlaid bottom nav bar). Tabs stay resident in the `IndexedStack` once built (no rebuild on tab switch) — same lazy-build-once pattern AqOne uses for its Venture tab if a tab is expensive to construct.
- [x] **T22.2** Bottom nav bar / sidebar nav items, three only: Travel Mode (map pin icon), Home (the app's existing default icon or a simple house glyph — confirm against `DESIGN_SPEC.md`; if it says nothing about tab icons, that's a spec gap, flag it rather than guessing), News. Style from `DESIGN_SPEC.md`'s existing component tokens (radius 14, accent rules from §2) — do **not** reuse AqOne's blue palette; Warang's amber/sage tokens apply throughout, including this nav chrome.
- [x] **T22.3** `main.dart` now routes to `AppShell` instead of directly to the map screen. Confirm first-run flow (maya screen, if any is still gated ahead of this) still runs before the shell, not inside a tab.
- [x] **T22.4** Move `lib/features/home/home_screen.dart` and `lib/features/home/map_painter.dart` into `lib/features/travel_mode/` (rename files and the widget class from `HomeScreen`/references to `TravelModeScreen` — grep for every reference before deleting the old path, this is a rename not a duplicate). No behavioral change in this task — capture, clustering, card-over-map, recenter button all work identically. This is Travel Mode's new home in the file tree; do not fold it into `app_shell.dart`.
- [x] **T22.5** Remove the trips pull-up sheet (`lib/features/trips/trips_sheet.dart`) invocation from Travel Mode. Do **not** delete the sheet widget file yet — Phase 23 repurposes its list-rendering logic for the Home tab's trips shelf.
- [x] **T22.6** Placeholder `HomeTabScreen` and `NewsTabScreen` widgets — simple centered "Coming in Phase 23/24" text — wired into the `IndexedStack` at their indices so the shell is fully navigable before either tab has real content.

**Acceptance:** app launches into Travel Mode by default; switching tabs preserves each screen's state (e.g. map camera position isn't reset by visiting Home and coming back); Travel Mode's capture flow is provably unchanged (existing tests for it still pass, plus a manual capture-while-in-shell check); no trips sheet appears over the map anymore.
**Tag:** `phase-22-tab-shell`

---

### Phase 23 — Home tab: trips shelf and offline analytics
**Goal:** Home is a scrollable screen — the trips list (moved from Travel Mode's old pull-up sheet) plus a small set of locally-computed stats, rendered as custom-painted charts.

- [ ] **T23.1** `lib/features/home_tab/home_tab_screen.dart`: adapt `trips_sheet.dart`'s trip-card list rendering into a top-level scrollable section (not a bottom sheet — it's the tab's main content now). Same trip-card visual design, same tap-through to trip detail; only the container changes from sheet to page.
- [ ] **T23.2** Analytics section below the trips shelf, pattern-matched to AqOne `dashboard.dart`'s `_buildAnalyticsSection` + custom `CustomPainter` charts (`FishCaughtBarPainter`/`SalesLinePainter` are the structural reference — bar chart + line/trend chart — not the content). Warang's version needs its own metrics; pick from what's cheaply computable from existing tables without new queries beyond simple `COUNT`/`GROUP BY`: moments captured per month (bar chart, last 6–12 months), cumulative places/trips over time (line chart), current capture streak (a stat tile, not a chart). Confirm exact metrics and chart count against `DESIGN_SPEC.md` if it's been updated for this phase; if not, this is a spec gap — flag it, pick the above as a reasonable default, and note the assumption in the phase's commit message.
- [ ] **T23.3** All analytics are computed **on-device, on demand, from the existing Drift tables** — no new table, no cached/precomputed analytics table, no telemetry, no network. Re-read the §2 amendment above before writing this: it exists precisely to head off treating this task as forbidden "analytics."
- [ ] **T23.4** Empty states: zero trips → the shelf shows the same empty-state pattern used elsewhere in the app (maya, per §2's mascot rule — non-map empty state), not a blank scroll. Analytics section with too little data (e.g. under a week of use) shows a "come back after your first few captures" message rather than a chart with one bar.
- [ ] **T23.5** Delete `trips_sheet.dart` once T23.1 has fully absorbed its rendering logic and nothing else references it — confirm with a grep before deleting.

**Acceptance:** Home shows real trips (including the Everyday trip) and at least one working bar chart and one working line/trend chart, all computed from on-device data with the app in airplane mode; empty states render correctly on a fresh install; deleting `trips_sheet.dart` doesn't break any other screen.
**Tag:** `phase-23-home-analytics`

---

### Phase 24 — News tab: static advisories, with an ad-slot seam
**Goal:** News is a list screen with bundled, static content — visually modeled on AqOne's `advisories.dart`, but reading from a local asset instead of a live API — built so a future ad-curation feature can slot in without a screen rewrite.

- [ ] **T24.1** `lib/features/news_tab/news_tab_screen.dart`: a `ListView` over a small static dataset — bundle as `assets/data/news_items.json` (title, body, optional icon/category, date) rather than hardcoding Dart literals, so content can be refreshed by editing one file without a code change. Register the asset in `pubspec.yaml`.
- [ ] **T24.2** List-item widget modeled on `advisories.dart`'s card layout (icon, title, snippet, timestamp) but restyled to Warang's tokens — sage-grey surfaces, amber used sparingly per §2's ≤4-per-screen rule, DM Mono for the date. Empty state (no bundled items) uses the same maya empty-state pattern as Phase 23.
- [ ] **T24.3** **The ad-slot seam** (structure only, no ad logic): define a sealed/union `NewsListEntry` type with two variants — `NewsArticle` (today's only real content) and `NewsAdSlot` (an inert placeholder variant, unused in this phase, that a future phase can populate). The list-building code accepts `List<NewsListEntry>` and renders each variant with its own widget, so adding real ad entries later is "add a case," not "restructure the screen." Do **not** implement `NewsAdSlot`'s actual rendering beyond a `SizedBox.shrink()` stub, do **not** wire in any ad SDK, and do **not** fetch anything from a network to populate it — see the §2 amendment above.
- [ ] **T24.4** Pull-to-refresh gesture is present in the UI (matching AqOne's `advisories.dart` interaction pattern for visual/muscle-memory consistency) but, since content is static in this phase, its handler just re-reads the bundled asset — it must not attempt any network call. Comment the handler clearly so a future phase knows exactly where a real fetch would go.

**Acceptance:** News tab renders the bundled items with correct styling in both themes; app is fully usable in airplane mode (no network call is ever attempted from this screen); `NewsAdSlot` compiles and is provably inert (no instance is ever constructed by current code, confirmed by a quick grep, not just by reading T24.3's intent).
**Tag:** `phase-24-news-static`

---

### Explicitly out of scope for Part IV

Do not implement any of these without the human asking for them by name.

- **Any ad-serving, ad-curation, or ad-sales logic.** Phase 24 builds a structural seam (`NewsAdSlot`) and nothing else. The human has stated a monetization intent for later, not a spec for now.
- **A live/networked News feed of any kind.** Would be a further, and more significant, narrowing of the §2 offline rule than the Phase 17 tile fetch was — needs its own explicit sign-off, not an inference from this pack.
- **Changing Travel Mode's default-tab status.** Confirmed explicitly by the human as map-first; do not make Home the launch tab even if it seems like a nicer "welcome back" experience.
- **Reusing AqOne's actual Dart source, assets, or backend.** The shell and chart *patterns* are the reference; AqOne's code, its blue palette, its maritime domain content, and its `api_client.dart`/backend are not part of Warang and should not be imported, copied, or pointed to at runtime.
