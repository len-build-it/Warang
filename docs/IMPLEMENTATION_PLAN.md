# Warang — Implementation Plan

**For the implementing agent (GPT‑5.6 Luna).** Read this file completely before writing any code. Follow the **work order** below — it, not the section order, decides what you do next. Do not reorder phases on your own, and do not "improve" decisions marked as settled — they were argued through and the reasoning is recorded here.

Repo: `C:\Users\User\Desktop\Warang` · Branch: `master` · No remote (local commits only). This file and `DESIGN_SPEC.md` now live in `docs/`.

> # 🔴 WORK ORDER — this overrides the phase numbering
>
> **Do Part II first: phases 15 → 16 → 18 → 17 → 19. Then resume Part I at Phase 3.**
>
> Phases 15–19 are printed at the **end** of this file because they were added later. They are **not** last in the queue. The old instruction "work top to bottom, do not skip ahead" is what caused them to be missed twice — it is now void. **Section order ≠ execution order.**
>
> Why these first: the pilot APK has been installed on a physical phone **twice**, and both times the same defects were reported — stock launcher icon, a boxed and dimmed capture button, a fake map, and no way to reach settings. Phases 15, 16 and 18 depend on nothing in Phases 3–14 and are roughly an afternoon each. Phase 17 needs only the Phase 2 data layer, which is done. **Every build that ships without them is another round where the person testing this app sees the same four bugs.**
>
> Order rationale: **15** (icon + fonts) and **16** (capture button) are the cheapest and most visible, so they land first. **18** (drawer) makes the rest of the app reachable. **17** (real map) is the largest, so it goes after the small wins rather than blocking them. **19** is the on-device gate — nothing is "done" until it passes.
>
> Report progress against **this order**. If you are about to start any Part I phase between 3 and 14 while a phase in 15–19 is still unticked, **stop — you are working the wrong queue.**

> ## ⛔ STOP — read this before your first `git commit`
>
> **One commit per phase is a protocol violation.** So is one commit per task. The rule is **one commit per independently revertible change** — typically **three to eight commits per task**, dozens per phase.
>
> This has already gone wrong once. Phase 2 was delivered as a single commit (`5e7a086`) containing the schema, the generated code, the DAOs, the FTS5 triggers, the seeding, the Riverpod providers, **and** the tests. Seven separable things in one blob. If any one of them was wrong, there was nothing to revert to. §3 shows exactly how that commit should have been split.
>
> **You do not get to batch commits until the end of a task, a phase, or a session.** Commit as you go, or the work is not done correctly no matter how good the code is. Full protocol in **§3 below — that is the authority**.

**This file has two parts.** Part I (§1–§8) is the original pilot plan, phases 0–14. **Part II** at the end is the post-pilot fix pack, phases 15–19, added 2026-08-22 after the first release APK was tested on a physical device. Part II amends a few Part I decisions; every amendment is marked inline where the original text sits. **Part II is the current work — see the work order above.**

**Outstanding housekeeping, do this before anything else:** the working tree currently has `DESIGN_SPEC.md`, `IMPLEMENTATION_PLAN.md` and `Logo.png` showing as deleted at the repo root and untracked under `docs/` and `assets/` — the moves were never committed. Commit them as `chore: move docs and brand assets into docs/ and assets/` (use `git mv` semantics: `git add -A`), so `git status` is clean before Phase 15 starts. Also delete any stale `.git/index.lock` if git complains — one was left behind by a tool that could not unlink it.

**Companion file: `DESIGN_SPEC.md`.** It is the visual authority — every screen, component, measurement, and colour, taken from the design canvas. This file stays the authority on architecture, stack, data model, phase order, and the never/always rules. When the two disagree about what a screen *looks like*, the design spec wins; when they disagree about what the app is *allowed to do*, this file wins. **§3 "Commits" below is the authority on commit cadence** — it now supersedes `DESIGN_SPEC.md` §2, which points back here. Read it before your first commit. Its `D`-prefixed tasks (spec §15) slot into the phases here and are part of each phase's acceptance.

---

## 1. What you are building

**Warang** (Aklanon: *to go out and explore*) is an offline-first Flutter app for the Philippines, Android first and iOS after.

A map you fill with your own photographs. You are somewhere — a cafe, a trail, a beach — you press one button, the camera opens, you shoot, and a photo-pin drops where you stood. Later you look back at a map covered in your own pictures.

It is **not** a game. It is **not** a social network. There is no server, no account, and no cloud. Sharing happens by rendering an image to the system share sheet, or by handing a `.travelbook` file to a friend.

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

> **Execution order is not this order.** Per the work order at the top of this file: **15 → 16 → 18 → 17 → 19, then resume here at Phase 3.** Phases 0–2 are done. Phases 3–14 are on hold until Part II is complete.

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

- [ ] **T3.1** `PhotoStore`: `<documents>/warang/photos/<yyyy>/<MM>/<uuid>.jpg` and `.../thumbs/<uuid>.jpg`.
- [x] **T3.2** `resolve(String relPath) → File` — the **only** place a relative path becomes absolute.
- [ ] **T3.3** Import pipeline: re-encode originals to max 2000px long edge (quality ≈ 85), generate a 320px thumbnail. The re-encoded file *is* the original; do not keep the camera's raw output.
- [ ] **T3.4** Orphan sweep: delete files with no live `Photos` row, and rows whose file is missing.
- [ ] **T3.5** **Tests:** stored paths are relative and contain no drive letter or leading `/`; resolution round-trips; a simulated documents-dir change still resolves; orphan sweep removes only orphans.

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

- [ ] **T17.10** Location permission flow, primed in plain language before the system dialog (this is the outstanding T5.1). Denial is **not** fatal — the map still works, only the marker is absent.
- [ ] **T17.11** One-shot `geolocator` fix on map open and on recenter. **No continuous stream, no background tracking** (§2). Cache the last known position so a cold start has something to centre on.
- [ ] **T17.12** `WarangPositionMarker` at the real `LatLng` via a `MarkerLayer` — remove the hardcoded screen-centre `Positioned`. Amber dot, halo, heading cone from `flutter_compass`; if the sensor is unavailable, drop the cone silently rather than pointing north and lying. (Closes T4.4.)
- [ ] **T17.13** Wire `_RecenterButton` — currently `onPressed: () {}`. Animate the camera to the fix; disabled-looking and inert if permission is denied. Neutral, not amber, per the design audit fallback. (Closes T4.5.)

**17d — Pins on real coordinates**

- [x] **T17.14** Delete the `positions` `Offset` table in `_buildPin`. Pins become `Marker`s at `LatLng(moment.lat, moment.lng)`. **Moments with null coordinates must not render on the map at all** — they surface in the trips sheet with the "Add location" affordance (T5.6), which is exactly why they are allowed to exist.
- [ ] **T17.15** Marker factory — one function producing a photo-pin, a cluster pin, or a selected pin from a moment plus a state, so every pin is built one way. (aqone's `divIcon` factory, in Flutter terms.)
- [ ] **T17.16** Distance-based clustering at the current zoom, replacing the `moments.length > 5` placeholder cluster. Cluster tapping zooms in; it does not open a card.
- [ ] **T17.17** Layer groups behind a small toggle: **Your moments** / **Clusters** / base map. Structured as a list of toggleable layers even though there are only two now — this is the seam future layers (trip routes, shared books) hang off.
- [ ] **T17.18** Tapping a pin still opens the card **over** the map with the map alive underneath. The map must not rebuild or recentre when the card opens.

**17e — Offline honesty**

- [ ] **T17.19** **Age stamp.** When any visible tile is served stale or the device is offline, show a quiet chip — `MAP · CACHED 3 DAYS AGO` — in DM Mono, `faint`, top-centre under the scrim. Never an error, never a modal. Straight from aqone: the map is always usable and always tells you how old it is.
- [ ] **T17.20** Airplane-mode test on a real device: cold start over a previously-visited area renders from cache with the stamp; a never-visited area shows flat land colour, not a grid of broken tiles.
- [x] **T17.21** Keep the `TileProvider` seam clean so a bundled `.mbtiles` (old T4.1/T4.2) can be added later as a **second** provider consulted before the network — the offline-first endgame is unchanged, just deferred.
- [ ] **T17.22** **Tests:** cache hit returns bytes without a network call; a stale tile still renders; eviction drops the oldest first; a moment with null coordinates produces no marker.

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

- [ ] **T19.1** `flutter analyze` clean. `flutter test` green.
- [ ] **T19.2** `flutter build apk --release --split-per-abi` — never a debug APK (see the build note: the first APK shipped an x86-only engine and crashed instantly on the Infinix).
- [ ] **T19.3** **Verify the APK contains `lib/arm64-v8a/libflutter.so` before sending it.** Ship `app-arm64-v8a-release.apk`; expect ~12–20 MB plus whatever the bundled fonts add.
- [ ] **T19.4** On-device checklist, in this order: launcher icon is the maya · app opens to a real map · marker is on the correct street · capture button is clean amber with no outline · hamburger opens the drawer · profile counts are right · airplane mode still draws the map with an age stamp · capture still completes in under five seconds.
- [ ] **T19.5** Battery: an hour of use, no unusual drain. Confirm no continuous GPS and no tile prefetch loop running in the background.
- [ ] **T19.6** Re-run the `DESIGN_SPEC.md` §14 guardrail audit against the built app: no login anywhere, nothing white on amber, accent ≤4 per screen, maya on first run only.

**Acceptance:** the four reported defects are gone on the physical device, and nothing on the checklist regressed.
**Tag:** `phase-19-rebuild`

---

### Deferred out of Part II

- The exact `DESIGN_SPEC.md` §13 map style. The Phase 17 colour filter is an approximation; the real answer is vector tiles or a bundled `.mbtiles`, and it is not worth blocking a working map on.
- Trip detail and share preview screens — still undesigned.
- The zoomed-out "look back" view. Phase 17 makes it possible for the first time; treat it as its own feature, not a side effect of pinch-zoom.
