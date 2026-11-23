# RES-002 - Place search, place categories, and visit progression

Created: 2026-11-23T19:20:00+08:00
Updated: 2026-11-23T20:15:00+08:00
Status: Decided. Len accepted every recommendation in section 9 on 2026-11-23 19:29 (Asia/Manila): "go with recommendation for all of your questions".
This is background research, not a spec; the behaviour is specified in [FEAT-004](../features/FEAT-004-places-search-stamps.md).

## 1. Summary

Len asked for three things: searching for real places inside the app, a category for every saved location, and a progression system by category, such as Coffee addict, then Connoisseur, then Coffee master.
All three are possible, and they build on each other: search gives a real place, a real place gives a category, and categories give progression.

The hard part is not the UI.
It is that Warang has promised "no geocoding calls" since Part II of `docs/IMPLEMENTATION_PLAN.md`, and FEAT-003 lists "streaks, scores, badges" as a non-goal.
Every recommendation below is shaped to keep the spirit of both rules, and the places where a rule must still change are called out as decisions for Len.

The recommended direction is "an offline place book":

1. **Search:** a Philippine place index built from OpenStreetMap data, shipped with the app as a separate SQLite file, searched fully offline with the FTS5 search Warang already uses.
   No search query ever leaves the phone.
   Online search for places outside the Philippines is a later, optional add-on.
2. **Categories:** a new `places` table, so a moment points at a place, and the place has one of about fourteen Warang categories mapped from OpenStreetMap tags.
   Warang suggests a nearby place when a moment is saved, but only the user's tap attaches it, and the user can always change the category.
3. **Progression:** keepsake "stamps" per category on the You sheet, earned by visits on different days to different places, never lost to time, never counted down, and cheered once by the maya.

Section 9 lists the decisions Len needs to make.

## 2. What exists today

These facts come from the code at `67e0121` and the approved documents.

- **Map:** `flutter_map` with OpenStreetMap raster tiles from `tile.openstreetmap.org`, through the cache-first `MapTileStore` (`lib/features/map/`).
  Areas never viewed before are blank when offline.
- **Place on a moment:** `Moments.placeLabel` is free text typed by the user and is "never geocoded" (`docs/IMPLEMENTATION_PLAN.md`, data model).
  There is no place table, no category, and no link between two moments at the same place other than the same typed words.
- **Place counts:** `distinctPlaces()` in `lib/core/memory_stats.dart` counts distinct lower-cased place labels, so "Kape ni Juan" and "kape ni juan " are one place, but "Kape ni Juan, Kalibo" is another.
- **Search:** the Search tab searches the user's own moments with an FTS5 table, `warang_search`, over captions, place labels, and trip names.
  It does not search the world.
- **Pin placement:** a moment with no GPS fix can be placed by hand by panning the map under a fixed pin (`_PlacementPin` and `_PlacementBar` in `lib/features/travel_mode/travel_mode_screen.dart`).
  Finding a far-away spot means panning and zooming by hand.
- **Milestones:** `lib/core/milestones.dart` celebrates the first moment, the first moment in a trip, and "Somewhere new!" more than 25 km from every earlier moment.
  They are computed from local data, shown once (stored in `AppMeta`), and cheered by the maya in a toast.
- **You sheet:** `lib/app/shell/you_sheet.dart` shows three stamps (moments, places, trips) and links to Settings and About.
- **Rules that apply:**
  - No geocoding and no network call other than map tiles (`docs/IMPLEMENTATION_PLAN.md`, Part II amendment; README "Privacy").
  - No new dependency without Len's authorization (`AGENTS.md`).
  - L-4 "No streaks and no FOMO", FEAT-003 non-goal "Streaks, scores, badges, or any count of missed days", and maya kindness rule M5.5 "Milestones are only celebrated, never counted down, chained, or shown as missed."

## 3. Place search

### 3.1 What a good search must do in Warang

1. Find a place by name while typing, such as "Ati-Atihan", "Boracay", or "Kape ni Juan".
2. Move the map there with a short spring, and drop a temporary marker.
3. Help pin placement: search, pick, and the placement pin lands on that spot.
4. Give the moment a real place, with a stable identity and a category, which is what sections 4 and 5 need.
5. Keep working with the radio off, as the rest of Warang does.
6. Keep the privacy promise: no account, no tracking, and nothing about the user's memories on any server.

### 3.2 Options

| Option | Offline | Privacy | Cost | Storing results on the moment | Search as you type | Fit |
| --- | --- | --- | --- | --- | --- | --- |
| A. Google Places | No | Queries and location go to Google; needs an API key in the app | Paid per request after free caps, plus billing account | Only `place_id` may be kept; latitude and longitude for up to 30 days; names and addresses may not be saved | Yes | **Fails**: Places content "must not" be used with a non-Google map, and Warang draws on OpenStreetMap |
| B. Mapbox Search | No | Queries go to Mapbox; needs a token | Free tier, then paid; permanent geocoding costs more per request | Default "temporary" results may not be stored; storing needs `permanent=true`, at a higher price | Yes | Poor: storage rules and a new account and key for a "no account" app |
| C. Public Nominatim (OSM Foundation) | No | Queries go to the OSMF server | Free | Allowed, ODbL | **Forbidden**: "you must not implement such a service on the client side" | Fails for typing search; 1 request per second for all users together; can be switched off on request |
| D. Public Photon (komoot) | No | Queries go to komoot | Free | Allowed, ODbL | Yes | Demo only: "We do not give guarantees for availability", heavy use is banned |
| E. Self-hosted Photon or Nominatim | No | Queries go to Len's server | A server for life; Photon needs about 95 GB disk and 64 GB RAM for the planet, much less for one country | Allowed, ODbL | Yes (Photon) | Possible, but Warang would gain a server to run, secure, and pay for |
| F. **Offline place index (recommended)** | **Yes** | **Nothing leaves the phone** | Free data; a build script; app size or a one-time download | Allowed, ODbL | Yes, with the existing FTS5 | Best fit for the offline promise |

### 3.3 Recommendation: an offline place index for the Philippines

Build a "place book" from OpenStreetMap data for the Philippines and ship it as a read-only SQLite file separate from the user's own database.

- **Source:** the Geofabrik Philippines extract of OpenStreetMap.
- **Build:** a script under `tool/` (run by Len, not by the app) filters named places and points of interest by the tags in section 4.2, keeps name, alternative names, category, latitude, longitude, the OSM id, and the municipality and province, and writes an FTS5 table plus a latitude and longitude index.
  The build tools (for example `osmium`) are developer tools, not app dependencies.
- **In the app:** opened read-only next to `warang.db` with the Drift and SQLite packages Warang already has, so no new runtime dependency is needed.
  Search is ranked by text match first, then by distance from the map centre, so "Jollibee" finds the nearby one, not the one in Aparri.
- **Licence:** the data is ODbL.
  Warang already shows "© OpenStreetMap contributors" for tiles, so the credit only needs to name the place data too.
  The place book file is a derived database, so it must be offered under ODbL, which is simple for a file Len already publishes.
- **Updates:** rebuilt with each app release; OpenStreetMap changes slowly for this use.

Unknowns that a short spike must measure before a spec:

1. The file size after filtering, which decides whether it ships inside the APK or as a one-time download (section 9, Q-2).
2. Coverage in the places Len actually goes, such as Kalibo, Boracay, and Manila: how many cafes, beaches, and churches are mapped and named.
3. Search speed on a mid-range Android phone.

The place book does not cover the rest of the world.
Two later options exist, and neither is needed for a first version:

- More country books as optional downloads.
- A "Search online too" switch in Settings, off by default, that calls a self-hosted Photon (option E) only when the user turns it on.

### 3.4 How search fits the clay UI and the flows

**Map search pill.**
A clay pill at the top of the map, "Find a place", next to the existing map buttons.
Tapping it opens a sheet, a C9-style sheet with a C5 field focused on open, matching S9.
Results come in two groups: "Your moments" (the existing moment search) and "Places" (the place book), each row with a category glyph in a small clay disc.
Choosing a place closes the sheet, springs the map to it, and shows a temporary stamp-shaped marker with the place name and two actions: "Pin a moment here" and "Close".
The maya does not appear on the map, as M2 requires.

**Search tab.**
The Search tab keeps searching the user's own moments.
Whether it also lists places is Q-4; the recommendation is to keep the tab about memories and put place search on the map, where moving the map is the point.

**Pin placement.**
The placement bar gains a search button.
Picking a result moves the map under the fixed pin, and Confirm saves the coordinates and attaches the place.
This turns "pan across three islands" into two taps.

**Edit sheet.**
The free "Place name" field becomes a place field.
Typing shows place book matches near the moment first.
The user can still type any name and keep it as their own place, so nothing that works today stops working.

**Offline map gap.**
If the chosen place is in an area whose tiles were never cached and the phone is offline, the map shows the marker on the ground colour with a small line, "Map not saved here yet".
Search itself always works.

## 4. Place categories

### 4.1 Where a category comes from

| Source | When | Confidence |
| --- | --- | --- |
| The place book | The user picks a place from search or from the nearby suggestion | High: from OpenStreetMap tags |
| The user | The user picks a category chip for their own place, or changes a suggested one | Always wins |
| None | Old moments and moments with no place | Uncategorised, which is fine |

Two other sources were considered and rejected:

- **Guessing from the photo** with on-device image labelling: needs a new ML dependency, and a latte photo taken at home is not a cafe visit.
- **Auto-attaching the nearest place silently:** GPS in dense streets is often 10 to 30 m off, which is the next-door shop.
  A silent wrong cafe would then count towards progression, which feels broken.

### 4.2 Proposed Warang categories

About fourteen categories are enough to feel personal without becoming a filing job.
Each maps from OpenStreetMap tags and gets a clay glyph and a keepsake colour.

| Key | Name | Example OpenStreetMap tags |
| --- | --- | --- |
| `cafe` | Cafe | `amenity=cafe`, `shop=coffee`, `cuisine=coffee_shop` |
| `food` | Food | `amenity=restaurant`, `amenity=fast_food`, `amenity=food_court` |
| `sweets` | Sweets and bakery | `shop=bakery`, `shop=pastry`, `amenity=ice_cream` |
| `nightlife` | Nightlife | `amenity=bar`, `amenity=pub`, `amenity=nightclub` |
| `beach` | Beach | `natural=beach` |
| `island` | Island | `place=island`, `place=islet` |
| `nature` | Mountains and falls | `natural=peak`, `waterway=waterfall`, `natural=volcano`, `leisure=nature_reserve` |
| `park` | Parks and views | `leisure=park`, `tourism=viewpoint`, `leisure=garden` |
| `church` | Churches | `amenity=place_of_worship`, `building=church`, `building=cathedral` |
| `heritage` | Heritage and museums | `tourism=museum`, `historic=*`, `tourism=attraction` |
| `market` | Markets | `amenity=marketplace`, `shop=mall`, `shop=department_store` |
| `stay` | Stays | `tourism=hotel`, `tourism=guest_house`, `tourism=hostel`, `tourism=resort` |
| `transit` | On the way | `aeroway=aerodrome`, `amenity=ferry_terminal`, `amenity=bus_station` |
| `town` | Towns and cities | `place=city`, `place=town`, `place=village` |

`town` and `transit` are searchable and help placement, but are excluded from progression, since passing through an airport is not a hobby.
The exact list is Q-5.

### 4.3 The nearby suggestion at save time

When a moment is saved with a GPS fix, Warang looks in the place book for named places within a radius based on the fix accuracy, capped at about 75 m.
The save screen shows one quiet chip, such as "At Kape ni Juan? Cafe", with a tap to accept and a small "Other place" to choose from the nearby list.
Ignoring the chip saves the moment exactly as today.
This keeps capture one tap, as FEAT-003 requires, and needs no network.

### 4.4 Data model

The recommendation is a new `places` table rather than a category column on each moment.

```
Places
  id            text, primary key
  name          text
  categoryKey   text, nullable      one of the keys in 4.2
  latitude      real, nullable
  longitude     real, nullable
  source        text                'osm' or 'user'
  sourceRef     text, nullable      for example 'node/123456', to recognise the same place again
  createdAt, updatedAt, deletedAt, authorId   as every other table

Moments
  placeId       text, nullable, references Places
  placeLabel    kept, as the display name and for old data
```

Why a table, not a column:

- **Visits need identity.** Progression counts different places, and two moments at "the same place" must be recognisable without comparing typed text.
- **One correction fixes all.** Changing a cafe's category once updates every moment there.
- **The places stamp becomes honest.** `distinctPlaces()` can count real places instead of spellings.
- **It matches the future plans.** The `authorId` and soft-delete columns already prepare for `.travelbook` export and sharing, and a place row exports cleanly.

A place picked from the place book is copied into `Places` (name, category, coordinates, `sourceRef`), so the user's database never depends on the place book file, and a later place book update never changes a user's memory.

The migration would be schema 3: create `Places`, add `Moments.placeId`, and turn each distinct existing `placeLabel` into a user place with no category, linked to its moments.
No old moment gains a category automatically; a later "Sort your places" view could offer nearby suggestions for old moments, one tap each.
The FTS5 index would add place names and category names, so searching "cafe" finds every cafe moment.

## 5. Progression by category

### 5.1 The tension, and how to resolve it

Len wants titles that grow, such as Coffee addict, then Connoisseur, then Coffee master.
Warang's approved rules say no badges, no FOMO, and milestones are never counted down.
Those can both hold if progression is a record of what the user already did, not a goal the app sets.

The recommended form is **stamps in a stamp book**: a passport-style stamp per category that changes as the user's own history grows, using the `WarangStamp` component already on the You sheet.
That reads as a keepsake, not a game.

Rules that keep it kind, all to be written as requirements:

1. **No decay.** Time never lowers a stamp; stopping for a year changes nothing.
2. **No streaks or days in a row.** REQ-021 stays true.
3. **No countdowns.** Nothing says "3 more to go", in line with M5.5.
4. **No empty slots.** Categories the user has never visited do not appear as blank stamps waiting to be filled.
5. **No notifications.** A new stamp is cheered once by the maya, in the existing milestone toast, when the moment is saved.
6. **Private.** No ranking, no comparing, no sharing prompt.

Rule 3 and rule 4 are the ones most likely to feel too strict for Len's idea, so they are Q-7.

### 5.2 What counts as a visit

A **visit** is one place on one local calendar day with at least one moment there.
Ten photos at one cafe in one afternoon are one visit.
Going back tomorrow is a second visit.

Tiers need both visits and different places, so the highest titles reward going out and exploring, which is what "warang" means, rather than photographing the same cafe every morning.

### 5.3 Proposed tiers

| Tier | Visits | Different places | Feels like |
| --- | --- | --- | --- |
| 1 | 3 | 2 | "You like this" |
| 2 | 10 | 5 | "You know this" |
| 3 | 25 | 12 | "You are known for this" |
| 4 | 50 | 25 | Rare, a year or more of habit |

Three visits for the first stamp means a new user sees one within the first weeks without it feeling cheap.
These numbers are a starting point for Q-8 and should be checked against Len's own moments once categories exist.

### 5.4 Names in the keepsake tone

The names should sound like a friend teasing kindly, with an occasional Aklanon or Filipino word, like the maya's lines.
"Addict" may read as negative to some people; it is kept below as Len's example, with alternatives.

| Category | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
| --- | --- | --- | --- | --- |
| Cafe | Kape lover (or Coffee addict) | Coffee connoisseur | Coffee master | Barista's favourite |
| Food | Hungry wanderer | Foodie | Kain champion | Taste keeper |
| Sweets | Sweet tooth | Merienda regular | Pastry hunter | Dessert legend |
| Beach | Sun seeker | Beach bum | Shore collector | Island soul |
| Nature | Trail starter | Waterfall chaser | Summit seeker | Mountain friend |
| Church | Visita guest | Bell listener | Pilgrim | Visita Iglesia pro |
| Heritage | Curious one | History buff | Heritage keeper | Living museum |
| Market | Tiangge browser | Haggler | Market regular | Suki everywhere |
| Nightlife | Night owl | Gimmick regular | Life of the party | Sunrise survivor |

Final names are Q-9, and Len knows the voice better than any table.

### 5.5 Where it shows

- **You sheet:** a "Your stamps" row under the three count stamps, showing earned category stamps, largest tier first.
  Tapping one opens a small stamp page: the title, visits, different places, the first visit ("Since 12 March 2026, Kape ni Juan"), and the places as a short list that opens them on the map.
- **Milestone toast:** "Coffee connoisseur!" with the maya cheering, once, using the existing `AppMeta` key mechanism (for example `stamp:cafe:2`).
  The stamp milestone should come after the existing ones in priority, so the first-ever moment still says "Your first moment!".
- **Moment card:** the place name gains its category glyph.
- **Map (optional):** a category filter row above the map, such as Cafe or Beach, that shows only those pins.
  This is the strongest everyday quality-of-life gain from categories, independent of stamps.

### 5.6 Gaming the system

Warang is private and has no leaderboard, so cheating only fools the person cheating.
Heavy anti-cheat would cost more trust than it saves.
The recommended light rules are:

- Count visits per place per day, not photos (5.2).
- Count only moments linked to a place with a category.
- Moments placed by hand count, because they are often real memories without a GPS fix.
- Stamps are computed from the current data, not stored, so deleting moments or changing a category updates them truthfully.
  Only the "already cheered" flag is stored, so a stamp is never cheered twice.

The last rule means a stamp can drop if the user deletes moments or recategorises a place.
That is the user's own action, not time passing, so it does not break "no decay"; whether Len prefers stamps to be kept forever once earned is Q-10.

## 6. Privacy, offline, and approved rules that would change

| Rule today | Effect of the recommendation | Needs Len's decision |
| --- | --- | --- |
| No geocoding calls | Kept: searching the place book is local, no request is made | Only if the online add-on is ever wanted (Q-3) |
| `placeLabel` is "user-typed only, never geocoded" | Changes: a place can now come from OpenStreetMap data, but only when the user picks it | Yes (Q-1) |
| No new dependency | Kept for the app; the build script uses developer tools | Confirm the build tools are acceptable (Q-2) |
| FEAT-003 non-goal "Streaks, scores, badges" | Changes for badges: stamps are a form of badge | Yes (Q-6) |
| L-4 no streaks, no FOMO; M5.5 never counted down | Kept, by rules 5.1.1 to 5.1.6 | Q-7 if Len wants to see the next tier |
| App size | Grows by the place book, unless downloaded | Q-2 |

## 7. Suggested order of work

1. **Spike (no app change):** build the Philippine place book with a script, measure its size and coverage, and test search speed in a test harness.
2. **FEAT-004, places and search:** the `Places` table and migration, the place book, map search pill, placement search, the edit sheet place field, the nearby suggestion at save, and category glyphs on the moment card.
3. **FEAT-005, stamps:** visit counting, the stamp book on the You sheet, the milestone toast, and optionally the map category filter.

FEAT-004 is useful on its own, so stamps can wait until categories have real data to tune the thresholds.

## 8. Risks

- **Coverage:** small local cafes may not be mapped in OpenStreetMap, especially outside big cities.
  Users can always add their own place, and Len could add missing places to OpenStreetMap itself, which improves the next build.
- **App size:** a large place book could make the APK feel heavy; the spike decides.
- **Wrong suggestions:** a weak GPS fix suggests the shop next door; the suggestion is never applied without a tap.
- **Category fatigue:** too many categories feels like filing; fourteen, with two kept out of stamps, is the proposed ceiling.
- **Tone:** stamps could slide into a game; the rules in 5.1 and a review of every name against M5 guard that.
- **Data model growth:** a places table touches capture, edit, search, stats, and the migration; it needs careful tests on upgrade from schema 2.

## 9. Open questions for Len

1. **Q-1 Place data from OpenStreetMap.** May a moment's place come from OpenStreetMap data when the user picks it, instead of always being typed?
   Recommended: yes, user-picked only.
2. **Q-2 How the place book arrives.** Ship it inside the app, or download it once on first use of search (a new, one-time network fetch)?
   Recommended: decide after the spike measures the size; inside the app if it is small, otherwise a one-time download from a file Len publishes.
3. **Q-3 Places outside the Philippines.** Philippines only for now, or plan an online search switch (self-hosted Photon, off by default)?
   Recommended: Philippines only for the first version.
4. **Q-4 Where place search lives.** A search pill on the map, places inside the Search tab, or both?
   Recommended: the map pill for places, and the Search tab stays for memories.
5. **Q-5 The category list.** Is the list in 4.2 right, and are there Aklan or Filipino categories missing, such as festivals or resorts?
6. **Q-6 Badges.** May FEAT-003's "no badges" non-goal be narrowed to allow private category stamps under the rules in 5.1?
7. **Q-7 Seeing what comes next.** Keep "no countdowns and no empty slots", or allow the stamp page to show the next title without numbers?
   Recommended: keep both rules; the next title is a surprise when it arrives.
8. **Q-8 Thresholds.** Are 3, 10, 25, and 50 visits, across 2, 5, 12, and 25 places, about right for how often Len goes out?
9. **Q-9 Names.** Which names in 5.4 fit the voice, and should "Coffee addict" stay?
10. **Q-10 Keep stamps forever?** Should a stamp stay once earned even if moments are later deleted, or always match the current data?
    Recommended: match the current data, since only the user's own edits can lower it.
11. **Q-11 Map category filter.** Include the category filter on the map in FEAT-004 or FEAT-005, or leave it out?
    Recommended: include it in FEAT-004, since it is useful without stamps.
12. **Q-12 Next step.** Approve the spike in section 7 so the place book size and coverage are known before writing FEAT-004?

## Sources

- OSM Foundation, Nominatim usage policy: https://operations.osmfoundation.org/policies/nominatim/
- Photon README (public API terms, search as you type, `osm_key` and `osm_value`, self-hosting requirements): https://github.com/komoot/photon
- Mapbox, temporary versus permanent geocoding: https://docs.mapbox.com/help/dive-deeper/understand-temporary-vs-permanent-geocoding/
- Google, Places SDK for Android policies and attributions: https://developers.google.com/maps/documentation/places/android-sdk/policies
- Google Maps Platform service specific terms (Places caching): https://cloud.google.com/maps-platform/terms/maps-service-terms
- Warang code at `67e0121`: `lib/data/db/tables.dart`, `lib/core/milestones.dart`, `lib/core/memory_stats.dart`, `lib/app/shell/you_sheet.dart`, `lib/features/travel_mode/travel_mode_screen.dart`, `lib/features/map/warang_map.dart`
- Warang documents: `docs/IMPLEMENTATION_PLAN.md` (Part II amendment, data model), `docs/features/FEAT-003-clay-keepsake-redesign.md` (L-4, non-goals, M5, REQ-021)
