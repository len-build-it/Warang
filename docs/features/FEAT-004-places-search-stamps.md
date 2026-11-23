# FEAT-004: Places, place search, and category stamps

Created: 2026-11-23T20:15:00+08:00
Updated: 2026-11-23T19:40:00+08:00
Revision: 1
Status: Approved - plan approved, not started

## Purpose and success

Len wants Warang to be more than a plain map.
He asked to search for real places inside the app, to have every saved location belong to a category, and to grow a title per category the more he goes out, such as a coffee title that grows with cafe visits.
The research behind this spec is [docs/research/RES-002-place-search-categories-progression.md](../research/RES-002-place-search-categories-progression.md), and Len accepted every recommendation in its section 9.

Success means:

- Typing a place name finds Philippine places in under a second, with the phone in airplane mode.
- Finding a far-away spot for a hand-placed pin takes a search and a tap instead of panning across islands.
- A moment can belong to a real place with a category, and the same place is recognised on every visit.
- The You sheet shows earned category stamps that feel like keepsakes, never like chores.
- No search query, place, or location ever leaves the phone, and capture stays one tap.

## Relationship to existing documents

This spec changes three earlier rules, with Len's approval on 2026-11-23 (see "Decisions already made by Len"):

| Document and rule | Change |
| --- | --- |
| `docs/IMPLEMENTATION_PLAN.md`, data model: `placeLabel?` "user-typed only, never geocoded" | A moment's place may now come from bundled OpenStreetMap data when the user picks it. The place moves to a new `Places` table. Nothing is geocoded over the network. |
| `docs/IMPLEMENTATION_PLAN.md`, "Never do" table: "Add gamification - points, streaks, badges, fog of war" | Narrowed: private category stamps under the kindness rules in this spec are allowed. Points, streaks, fog of war, leaderboards, and anything social stay rejected. |
| FEAT-003 non-goal "Streaks, scores, badges, or any count of missed days" | Narrowed the same way for badges. Streaks, scores, and counts of missed days stay out. REQ-021 of FEAT-003 stays in force. |

`docs/IMPLEMENTATION_PLAN.md` stays the authority for architecture and commit protocol, and FEAT-003 stays the authority for appearance, components, and the maya.
New screens in this spec use FEAT-003 tokens and components (C1 to C14) and its motion and haptic rules.
The Part II amendment ("no geocoding") stays true: the place book is searched on the phone, and no new network call is added.

## Decisions already made by Len

| ID | Decision | Len's words and time (Asia/Manila) |
| --- | --- | --- |
| L-1 | Go with every RES-002 recommendation (Q-1 to Q-12). | "go with recommendation for all of your questions", 2026-11-23 19:29 |
| L-2 | Override the earlier document rules where they block these features. | "override the original doc rules in order to push this features", 2026-11-23 19:29 |
| L-3 | Produce a plan Gemini can execute. | "then come up with an implementation plan gemini can execute", 2026-11-23 19:29 |

What L-1 means for each RES-002 question:

| RES-002 question | Answer used in this spec |
| --- | --- |
| Q-1 Place data from OpenStreetMap | Yes, attached only when the user picks it. |
| Q-2 How the place book arrives | Inside the app if it fits the size budget in REQ-003; if it cannot fit after the listed reductions, work stops for Len. No download path in this revision. |
| Q-3 Outside the Philippines | Philippines only. No online search. |
| Q-4 Where place search lives | A search pill on the map for places; the Search tab stays for the user's own moments. |
| Q-5 Category list | The fourteen categories in D-4. |
| Q-6 Badges | Allowed as private category stamps. |
| Q-7 Next title | Not shown. No countdowns and no empty slots. |
| Q-8 Thresholds | 3, 10, 25, 50 visits across 2, 5, 12, 25 different places. |
| Q-9 Names | The RES-002 table, with "Kape lover" as the first cafe title, kept in one bundled data file so names can change without code. |
| Q-10 Keep stamps forever | No; stamps always match the current data. |
| Q-11 Map category filter | Included. |
| Q-12 Spike | Done as Phase 1 of the plan, before any app change. |

## Scope and non-goals

In scope:

- A bundled, read-only Philippine place book built from OpenStreetMap by a script in `tool/`.
- A `Places` table in the user's database, linking moments to places, with a category per place.
- Place search on the map, in pin placement, and in the edit sheet.
- A nearby-place suggestion on the capture save screen.
- Fourteen place categories with clay glyphs and keepsake colours.
- A category filter on the map.
- Category stamps on the You sheet, a stamp page, and a one-time maya cheer.
- Credits for OpenStreetMap place data.

Out of scope:

- Any network call other than the existing map tiles, including online search, downloads of the place book, and place book updates outside app releases.
- Places outside the Philippines.
- Guessing a category from the photo.
- Attaching a place without the user's tap.
- Streaks, points, leaderboards, sharing of stamps, notifications, or anything that shows a next goal or a missing stamp.
- A screen that lists or manages all places on their own.
- New runtime package dependencies. The place book builder is a developer tool and adds nothing to `pubspec.yaml`.

## User flows

### F1. Find a place on the map

1. On the map, the user taps the "Find a place" pill at the top, to the right of the avatar bubble.
2. A sheet rises with a focused search field.
   While the field is empty it shows a short line in `hand`: "Search places in the Philippines".
3. As the user types, results update after a 150 ms pause.
   Each row shows the category glyph in a small clay disc, the place name in `titleS`, and the town and province in `meta`.
   Results nearer the current map centre rank higher among equally good matches.
4. Tapping a result closes the sheet and moves the map to the place at zoom 16 with the FEAT-003 map spring (a jump under reduced motion).
5. A stamp-shaped marker shows the place name and category above the spot.
   Tapping the map elsewhere or the marker's close control removes it.
6. If the phone is offline and that map area was never cached, a small line appears under the marker: "Map not saved here yet".

States:

- No results: the maya with binoculars (M2 allows it in search) and "No place by that name yet" in `hand`.
- Place book still being prepared on first launch: the field works, and the list shows "Getting places ready" with a calm spinner until the book is ready, then runs the query.
- Place book failed to prepare: "Places are not available right now" with a Try again button. The rest of the app is unaffected.

### F2. Search while placing a pin by hand

1. In pin placement (S5), the placement bar has a search button next to Cancel.
2. It opens the same sheet as F1.
3. Choosing a place moves the map so the fixed placement pin sits on it, and marks that place as the one to attach.
4. Confirm saves the coordinates and attaches the place to the moment.
   Panning the map afterwards keeps the coordinates the user chooses but drops the attachment, since the pin is no longer on that place.

### F3. Pick or change a moment's place

1. In the edit sheet, the "Place name" text field becomes a place field showing the current place name and its category glyph, or "Add a place".
2. Tapping it opens the place picker sheet:
   - With an empty query and a moment with coordinates: "Nearby", up to eight place book places within 150 m, nearest first.
   - While typing: "Your places" (places already used on other moments, by name) above "Places" (the place book).
   - Always last while typing: "Use "<typed text>" as your own place".
   - "No place" at the bottom when the moment has one.
3. After choosing, the edit sheet shows a "Category" chip row (C7) with the fourteen categories and the place's category selected, or none.
   Changing the category changes it for that place, and so for every moment at that place.
4. Save works as today.

### F4. Accept a nearby place when saving a capture

1. On the capture save screen, once a GPS fix exists, Warang looks for place book places within a radius equal to the fix accuracy, at least 25 m and at most 75 m (50 m when accuracy is unknown).
2. If there is at least one, a chip appears under the coordinate stamp row: the category glyph and "At <name>?".
3. Tapping the chip marks it accepted (a check and a `selectionClick` haptic); tapping again unmarks it.
   A small "Other place" text button beside it opens the nearby list from F3 to pick another.
4. Save saves the moment with the accepted place.
   Saving without touching the chip saves no place, exactly as today.
5. With no fix or no nearby place, nothing is shown and the screen is as today.

### F5. Filter the map by category

1. When at least two categories have moments, a horizontal row of category chips (C7, small) sits under the search pill: "All" first, then each category that has moments, ordered by number of moments.
2. Choosing a chip shows only moments whose place has that category; clusters recount accordingly.
3. "All" or tapping the chosen chip again clears the filter.
4. The filter resets when the app restarts.

### F6. See category stamps

1. The You sheet gains a "Your stamps" row under the three count stamps when at least one stamp is earned.
   It is a horizontally scrolling row of earned stamps, highest tier first, then most visits.
2. Each stamp is a `WarangStamp` in the category's colour with its glyph and current title.
   Higher tiers look richer (tier 1 single dashed ring, tier 2 double ring, tier 3 scalloped double ring, tier 4 scalloped ring with a small star), never with a count of tiers or empty marks.
3. Tapping a stamp opens the stamp page sheet: the stamp large, the title in `displayM`, "<n> visits to <m> places" in `body`, "Since <date>, <first place>" in `meta`, and the list of places with their visit counts.
   Tapping a place closes the sheets and shows its moments on the map with the F5 filter for that category.
4. With no stamps earned, the row is absent; nothing hints that stamps exist.

### F7. Earn a stamp

1. When a saved or edited moment makes a category reach a tier not cheered before, the maya cheers once in the milestone toast: "<title>!" followed by the usual "Saved to <trip>." on capture, or alone after an edit.
2. If a FEAT-003 milestone fires on the same save, that toast shows first and the stamp toast follows it.
3. A tier that was cheered and later lost by deleting moments is never cheered again.

## Requirements and acceptance criteria

| ID | Required behavior | Observable pass/fail criterion |
| --- | --- | --- |
| REQ-001 | A script builds the place book from an OpenStreetMap Philippines extract. | `python tool/place_book/build_place_book.py --pbf <file> --out assets/place_book/place_book.sqlite` produces the file; `tool/place_book/README.md` documents the source, date, and steps; the build is repeatable from the same input to a byte-identical file. |
| REQ-002 | The place book holds named places of the fourteen categories, with name, alternative names, category, latitude, longitude, town, province, and OSM reference, plus a `meta` table with schema version, source date, and licence. | A Dart test opens the bundled file and checks the schema version and that every category has at least one row; the evidence log records row counts per category. |
| REQ-003 | The place book fits the size budget. | Release arm64 APK grows by at most 25 MB over the Phase 0 baseline, and the installed copy on disk is at most 40 MB, both recorded in evidence. |
| REQ-004 | The place book is prepared on the phone without blocking the app. | On first launch or after an update, the asset is copied to app support storage in the background under a temporary name and renamed when complete; a test shows an interrupted copy is redone, and the map is usable during the copy. |
| REQ-005 | Place search works offline and as the user types. | With networking disabled in the test, a query of two or more letters returns ranked results; prefix matches work ("kap" finds "Kape ni Juan"); accents are ignored ("pina" finds "Piña"); input with quotes, dashes, or asterisks never throws. |
| REQ-006 | Place results rank by text match, then nearness. | A test with two places of the same name returns the one nearer the map centre first. |
| REQ-007 | The map has a "Find a place" pill that opens place search and moves the map to the chosen place. | A widget test types a name, taps a result, and finds the marker with the place name; the map centre equals the place's coordinates. |
| REQ-008 | An offline area that was never cached shows "Map not saved here yet" with the marker. | A widget test with an empty tile cache and no network finds the line after choosing a place. |
| REQ-009 | Pin placement can search and attach the chosen place. | A widget test starts placement, searches, chooses, confirms, and the moment has the place's coordinates and place id; panning before confirm drops the place id. |
| REQ-010 | Moments link to places in a `Places` table, and the old free-text place becomes a user place. | A migration test from a schema 2 database with labels "Kape ni Juan", "kape ni juan ", and "Boracay" ends with two user places, every moment linked, no `place_label` column, and moment counts unchanged. |
| REQ-011 | The same place book place is one place across moments. | Attaching the same place book place to two moments creates one `Places` row with its `sourceRef`. |
| REQ-012 | The edit sheet place picker offers nearby, your places, place book results, your own typed place, and no place. | Widget tests reach each option and check the saved result. |
| REQ-013 | A place's category can be set or changed by the user, and applies to every moment there. | A test changes a category from one moment and finds it on another moment at the same place. |
| REQ-014 | The capture save screen suggests a nearby place but attaches it only on tap. | Widget tests: a fix next to a fixture cafe shows "At <name>?"; Save without a tap saves no place; Save after a tap saves the place; no fix shows no chip. |
| REQ-015 | Capture stays one tap and never waits on the place book. | A test with the place book unavailable saves a capture with one tap, as today. |
| REQ-016 | Capture stores the fix accuracy. | A capture with a fix stores `accuracyM`. |
| REQ-017 | Fourteen category glyphs exist in the Warang icon font, each with a semantic label. | `icon_semantics_test.dart` covers the new glyphs; the glyph list in `warang_icons.dart` includes all fourteen. |
| REQ-018 | Every category colour pair meets WCAG 2.2 AA in both themes. | `contrast_test.dart` covers each category's glyph and label colours against their disc and the sheet surfaces. |
| REQ-019 | The moment card shows the place with its category glyph. | A widget test finds the glyph and name on the card of a categorised moment. |
| REQ-020 | The map can be filtered by category. | A widget test with cafe and beach moments shows only cafe pins after choosing "Cafe", and all after "All". |
| REQ-021 | The moment search finds moments by place name and category name. | Searching "cafe" finds a moment at a cafe with no caption; searching the place name finds it. |
| REQ-022 | A visit is one place on one local day; a tier needs both its visits and its different places. | Unit tests: ten moments at one cafe on one day are one visit; tier 1 needs 3 visits across 2 places; 3 visits at 1 place earns nothing. |
| REQ-023 | Only the twelve stamp categories count, and only moments with a categorised place. | Unit tests: transit and town visits earn nothing; uncategorised places earn nothing. |
| REQ-024 | Stamps match the current data. | Deleting moments below a threshold lowers the stamp on the next build of the You sheet. |
| REQ-025 | Each tier is cheered once, by the maya, after any FEAT-003 milestone on the same save. | Tests: reaching tier 1 shows the stamp toast once; a second qualifying save does not; a save that is also "Somewhere new!" shows both toasts in order. |
| REQ-026 | Nothing counts down, shows a next goal, or shows an empty stamp. | Code review and a test that the You sheet and stamp page contain no stamp for an unearned category and no text matching "more to", "next", "left", "until", or "/". |
| REQ-027 | The You sheet shows earned stamps and the stamp page shows title, visits, places, first visit, and the place list. | Widget tests on a fixture with two earned categories. |
| REQ-028 | Stamp names come from one bundled data file. | `assets/data/stamps.json` holds every title; a test checks every stamp category has four titles. |
| REQ-029 | OpenStreetMap place data is credited. | The map credit and the About screen say "Places and map © OpenStreetMap contributors"; About adds "Place data is available under the ODbL" and names `tool/place_book`. |
| REQ-030 | No new network call is added. | `grep -rn "HttpClient\|http\.\|Uri.https\|Uri.parse" lib` lists only the existing tile fetch; reviewed in evidence. |
| REQ-031 | All new screens work at 200% text and with reduced motion. | The FEAT-003 200% text render and `reduced_motion_test.dart` include the search sheet, place picker, capture chip, filter row, You sheet stamps, and stamp page with no overflow and no animation under reduced motion. |
| REQ-032 | All new interactive elements have labels and 48 dp targets. | `icon_semantics_test.dart` and a tap-target check cover the new elements. |
| REQ-033 | Existing flows keep working. | All existing tests pass, with changes only where this spec changes behaviour, each noted in evidence. |

## Data and interfaces

### D-1. The place book file

A read-only SQLite file at `assets/place_book/place_book.sqlite`, copied on the phone to app support storage as `place_book_<schemaVersion>_<sourceDate>.sqlite`.
Older copies are deleted after a new copy is ready.
The schema lives in one file, `tool/place_book/schema.sql`, used by both the builder and the Dart tests:

```
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
  -- schema_version, source, source_date, built_at, licence

CREATE TABLE places (
  id INTEGER PRIMARY KEY,
  osm_ref TEXT NOT NULL UNIQUE,      -- 'n123', 'w456', or 'r789'
  name TEXT NOT NULL,
  alt_names TEXT NOT NULL DEFAULT '',-- name:en, name:tl, alt_name, old_name, joined by ' | '
  category TEXT NOT NULL,            -- one of the D-4 keys
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  town TEXT NOT NULL DEFAULT '',
  province TEXT NOT NULL DEFAULT '',
  weight INTEGER NOT NULL DEFAULT 0  -- small ranking boost, for example towns by population
);
CREATE INDEX places_lat ON places(lat);

CREATE VIRTUAL TABLE places_fts USING fts5(
  name, alt_names, town, province,
  content = 'places', content_rowid = 'id',
  tokenize = 'unicode61 remove_diacritics 2',
  prefix = '2 3'
);
```

Ways and relations use a representative point inside them.
Town and province come from the containing administrative boundaries (`admin_level` 6 for province and 7 for municipality or city, verified in Phase 1).

### D-2. The `Places` table (schema 3)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, primary key | UUID v4, as every table |
| `name` | text | Display name |
| `categoryKey` | text, nullable | One of the D-4 keys |
| `latitude`, `longitude` | real, nullable | Set for place book places |
| `source` | text | `book` or `user` |
| `sourceRef` | text, nullable | The place book `osm_ref`; unique among non-deleted rows |
| `createdAt`, `updatedAt`, `deletedAt`, `authorId` | as every table | |

`Moments` gains `placeId` (text, nullable, references `Places`).
`Moments.placeLabel` is removed from the database; the Dart `Moment` keeps `placeLabel` as a projection of the place's name, as it already does for `relPath` from `Photos`, and gains `placeId` and `placeCategory`.
A place book place is copied into `Places` when first attached, so the user's data never depends on the place book file.
User places are matched by trimmed, lower-cased name, so typing an existing name reuses the place.

The FTS5 table `warang_search` keeps its columns; the moment triggers read the place name and category name through the place id, and new triggers on `places` reindex its moments when a name or category changes.

### D-3. Stamps (derived, not stored)

`lib/core/stamps.dart` computes, from moments and places only:

- visits per category: distinct pairs of place id and local calendar day of `capturedAt`;
- different places per category;
- the tier: the highest tier whose visits and places are both met;
- first visit date and place, and the per-place visit list.

Tiers: 1 at 3 visits and 2 places, 2 at 10 and 5, 3 at 25 and 12, 4 at 50 and 25.
Cheered tiers are stored in the existing `milestonesShown` app metadata list as `stamp:<category>:<tier>`.
No new table is needed.

### D-4. Categories

| Key | Name | Stamp | Main OpenStreetMap tags |
| --- | --- | --- | --- |
| `cafe` | Cafe | yes | `amenity=cafe`, `shop=coffee`, `cuisine=coffee_shop` |
| `food` | Food | yes | `amenity=restaurant`, `amenity=fast_food`, `amenity=food_court` |
| `sweets` | Sweets and bakery | yes | `shop=bakery`, `shop=pastry`, `shop=confectionery`, `amenity=ice_cream` |
| `nightlife` | Nightlife | yes | `amenity=bar`, `amenity=pub`, `amenity=nightclub` |
| `beach` | Beach | yes | `natural=beach` |
| `island` | Island | yes | `place=island`, `place=islet` |
| `nature` | Mountains and falls | yes | `natural=peak`, `natural=volcano`, `waterway=waterfall`, `natural=cave_entrance`, `leisure=nature_reserve` |
| `park` | Parks and views | yes | `leisure=park`, `leisure=garden`, `tourism=viewpoint` |
| `church` | Churches | yes | `amenity=place_of_worship`, `building=church`, `building=cathedral`, `building=chapel` |
| `heritage` | Heritage and museums | yes | `tourism=museum`, `historic=*`, `tourism=attraction`, `tourism=gallery` |
| `market` | Markets and malls | yes | `amenity=marketplace`, `shop=mall`, `shop=department_store` |
| `stay` | Stays | yes | `tourism=hotel`, `tourism=resort`, `tourism=guest_house`, `tourism=hostel` |
| `transit` | On the way | no | `aeroway=aerodrome`, `amenity=ferry_terminal`, `amenity=bus_station` |
| `town` | Towns and cities | no | `place=city`, `place=town`, `place=village`, `place=suburb` |

The exact tag mapping, with precedence when a feature has several tags, lives in `tool/place_book/categories.json`.
Each category has a glyph and one of the seven keepsake tones (amber and the six trip colours), set in `lib/core/place_categories.dart`.

### D-5. Stamp titles

`assets/data/stamps.json` holds four titles per stamp category:

| Category | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
| --- | --- | --- | --- | --- |
| Cafe | Kape lover | Coffee connoisseur | Coffee master | Barista's favourite |
| Food | Hungry wanderer | Foodie | Kain champion | Taste keeper |
| Sweets | Sweet tooth | Merienda regular | Pastry hunter | Dessert legend |
| Nightlife | Night owl | Gimmick regular | Life of the party | Sunrise survivor |
| Beach | Sun seeker | Beach bum | Shore collector | Island soul |
| Island | Island hopper | Bangka regular | Archipelago explorer | Seven thousand islands |
| Nature | Trail starter | Waterfall chaser | Summit seeker | Mountain friend |
| Park | Fresh-air fan | Park stroller | View hunter | Golden-hour keeper |
| Church | Visita guest | Bell listener | Pilgrim | Visita Iglesia pro |
| Heritage | Curious one | History buff | Heritage keeper | Living museum |
| Market | Tiangge browser | Haggler | Market regular | Suki everywhere |
| Stay | First check-in | Weekend wanderer | Seasoned guest | Home anywhere |

## Quality constraints

- **Offline and privacy:** no new network call (REQ-030); the place book and all searches stay on the phone.
- **Performance:** place search returns in under 150 ms for a three-letter query on the Windows test host and is recorded; under 300 ms on a mid-range phone is a physical-device check for Len.
  The map stays smooth with the filter row and search pill.
- **Size:** REQ-003.
- **Reliability:** the schema 3 migration runs in one transaction, is tested from a real schema 2 file, and a failure leaves the schema 2 data untouched.
- **Accessibility:** FEAT-003 rules: WCAG 2.2 AA in both themes, 48 dp targets, labels on every control, 200% text, and reduced motion.
- **Kindness:** FEAT-003 M5 applies to stamps; stamps never use the words "missed", "lost", "only", or "behind".
- **Licence:** OpenStreetMap data is ODbL; the credit (REQ-029) and the public builder in `tool/place_book` cover attribution and the means to recreate the derived database.

## Decisions and assumptions

### Council record (architecture)

The `council` skill was applied to the three architecture choices, with these results.

**C-1. A separate read-only place book file, not rows in the user's database.**
Facts: the user's database holds only the user's memories and is the future `.travelbook` and backup source; the place book is tens of thousands of rows that change per release.
Devil's advocate: two databases mean two connections and a copy step that can fail.
Simplicity: Drift's `NativeDatabase` already opens files, so no new package is needed.
Reliability: copying under a temporary name and renaming makes a half copy impossible to open; the copy is repeated if the version differs.
Decision: a separate file.
Revisit if Android storage cost of the copy becomes a complaint, for example by reading the asset in place through a platform channel.

**C-2. A `Places` table with the place name as the single source of truth, dropping `Moments.placeLabel`.**
Devil's advocate: dropping a column is the riskiest migration Warang has done, and `.travelbook` import code writes `placeLabel`.
Simplicity: keeping `placeLabel` next to `placeId` would be one line less now, but every edit would have to keep two names in step forever.
Reliability: Drift's `TableMigration` rebuilds the table inside the migration transaction, and a test from a real schema 2 file proves no moment, photo, or label is lost.
Architecture: one source of truth, with `Moment.placeLabel` kept as a projection so screens do not change.
Decision: drop the column in schema 3, with drift_dev schema snapshots and migration tests.
Revisit only if the migration test cannot be made to pass without data loss.

**C-3. Stamps computed on demand, not stored.**
Devil's advocate: computing on every You sheet open costs time.
Facts: Warang holds at most a few thousand moments on a phone; grouping them is a few milliseconds.
Decision: derive stamps; store only which tiers were cheered.
Revisit if a profile of a 10,000-moment fixture takes over 16 ms.

### Proposed decisions within L-1

- **P-1 Size reductions before stopping.** If the place book is over budget, Phase 1 applies these in order and re-measures: drop `alt_names`; drop `village` and `suburb` from `town`; drop the FTS `prefix` option; require a `name` and at least one of `addr:*`, `website`, `opening_hours`, or `wikidata` for `food`. If it is still over budget, work stops for Len.
- **P-2 Builder tools.** The builder uses Python with `osmium` (pyosmium) pinned in `tool/place_book/requirements.txt`, installed in a local virtual environment that is not committed. The downloaded `.osm.pbf` is not committed; the built `.sqlite` is.
- **P-3 Category glyph production** follows FEAT-003 plan P-2: SVG sources and the generated font are committed, built with `design/icons/build_icons.py` and fantasticon through `npx`.

### Assumptions

- OpenStreetMap coverage of named cafes, beaches, and churches in Aklan and Metro Manila is good enough to be useful; Phase 1 checks a list of known places and records the result.
- `sqlite3_flutter_libs` includes FTS5 with `remove_diacritics 2`, as the existing `warang_search` table already relies on FTS5.
- Same-name user places in different towns (for example two "Starbucks" typed by hand) remain one user place, exactly as `distinctPlaces()` counts them today; picking the place book entry avoids this.

## Open questions and readiness

No blocking questions remain.
Revision 1 and [docs/plans/FEAT-004-implementation.md](../plans/FEAT-004-implementation.md) revision 1 were approved by Len on 2026-11-23 19:37 (Asia/Manila), project thread decision card: "Approve as written" on "Approve FEAT-004 spec and plan revision 1 for Gemini to execute?".
