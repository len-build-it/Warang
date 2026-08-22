# Warang — Design Specification

**For the implementing agent (GPT‑5.6 Luna).** This file is the visual authority. `IMPLEMENTATION_PLAN.md` remains the authority on architecture, stack, data model, phase order, and the never/always rules. Where the two disagree about *what a screen looks like*, this file wins. Where they disagree about *what the app is allowed to do*, the plan wins.

Read §1 and §2 before you write a single widget. Then implement screens in phase order, reading each screen's section immediately before you build it.

Source of truth: the Claude Design canvas, 8 artboards, exported to `design/warang-canvas.html`. Every number in this file was read out of that export. Nothing here is estimated. Where the canvas did not specify something, it says so explicitly and is marked **⛔ HUMAN** or **DERIVE**.

---

## 1. How to read this file

**Units.** Every measurement is Flutter logical pixels at a **390 × 844** frame. That is the design baseline. Do **not** scale these values by screen width — they are absolute. What flexes is stated per screen (the map fills, sheets stretch, spacer marked `flex` absorbs slack). Everything else is fixed.

**Chrome you do not draw.** The artboards render a phone status bar (52px, `9:41`, signal, battery) and a home indicator (138 × 5, radius 3, 9px from the bottom). These are the OS drawing itself. Do **not** build them. What you *do* take from them:

- Reserve a **52px** top inset for the status bar. Screens that place content behind it say so.
- Reserve a **34px** bottom inset for the home indicator region. Content that must clear it is specified with its own bottom padding, already inclusive.
- The status bar's *brightness* is specified per screen, because you must set `SystemUiOverlayStyle` to match. Get this wrong and the clock disappears into the photo.

**Spacers.** The canvas uses fixed-height spacer boxes rather than margins. They are reproduced here as explicit gaps. Use `SizedBox(height: n)` — do not "improve" them into a spacing scale. The rhythm is deliberate and irregular.

**Colour naming.** Names refer to the token constants in `lib/app/theme/tokens.dart` (plan §5), extended by §3 of this file. Never write a hex literal in a widget.

**Opacity.** Written as `token @ NN%`. In Flutter: `token.withValues(alpha: 0.NN)`.

---

## 2. Commit protocol — MOVED to IMPLEMENTATION_PLAN.md §3

> **This section no longer holds the rule.** `IMPLEMENTATION_PLAN.md` **§3** is now the single authority on commit cadence. It was moved because keeping the rule in the *design* file meant it was not in front of you at commit time — and it got skipped: Phase 2 shipped as one commit (`5e7a086`) for seven separable things. **Read `IMPLEMENTATION_PLAN.md` §3 before your first commit.** What follows is a reminder only; where it and §3 differ, **§3 wins**, and §3 additionally requires a per-phase commit-log report.

Commit frequency is not bookkeeping — it is the rollback mechanism, and it is the only one this project has.

### Commit after every independently revertible change

Not per phase. Not per task. **Per change.** If a chunk of work could be reverted on its own and leave a tree that still compiles, it is its own commit. In practice that means a commit when you:

- add or delete a file
- add, remove, or bump a dependency in `pubspec.yaml`
- change the database schema, or add/alter a table or migration
- add a new widget, or extract an existing one
- wire a new screen into the router
- add a test file, or add tests to one
- change a token, theme value, or anything in `lib/app/theme/`
- fix a bug (the fix is its own commit, separate from any refactor near it)
- run `build_runner` and regenerate `.g.dart` / `.drift.dart` (regeneration is its own commit)

A task in the plan will typically produce **three to eight commits**, not one. If you finish a task with one commit, you almost certainly bundled things that should have been separable.

### Commit before you start anything risky

Before a refactor, a dependency upgrade, a schema migration, or any change you are unsure about: commit the working tree first, even if the message is `chore: checkpoint before <thing>`. That commit is the thing you fall back to. Never begin exploratory work from a dirty tree.

### Gates

Before every commit, all three must pass:

```
flutter analyze          # zero issues
flutter test             # all green
flutter build apk --debug   # compiles
```

If a commit is a pure checkpoint mid-refactor and the tree does not yet build, that is the **one** exception — mark it `wip:` in the subject and make the very next commit the one that restores green. Never leave a `wip:` commit as the tip when you stop working.

### Message format

Conventional Commits, referencing the task ID:

```
feat(map): photo pin with surface ring and pointer  [D6.1]

58px outer circle, 3px surface padding, 52px photo, 11px rotated
pointer beneath. Measurements from DESIGN_SPEC.md §9.
```

Types: `feat` · `fix` · `refactor` · `test` · `chore` · `build` · `docs` · `wip`

### Checkboxes and history

- When a task completes, tick its checkbox **in the same commit** as the last change for that task. Progress and code never drift.
- Tag at phase boundaries: `git tag phase-6-pins`. Tags are coarse waypoints on top of the fine-grained commits, not a substitute for them.
- **Never** `--amend`, force-push, rebase, or rewrite history. If work is abandoned, `git revert` it — a revert is a commit. The trail must stay intact, because the whole point is that any earlier state is one command away.

---

## 3. Token additions

The canvas uses four colours that are not in `IMPLEMENTATION_PLAN.md` §5. Add them to `tokens.dart`.

| Token | Light | Dark | Where it appears |
| :--- | :--- | :--- | :--- |
| `accentText` | `#8A6412` | **⛔ HUMAN** | The "Back up everything" row label (§12). Amber is unreadable as text on a light surface, so the canvas darkens it. |
| `dotInactive` | `#C3C7BC` | **⛔ HUMAN** | Inactive page dots on the moment card (§10). |
| `mapLabel` | `#8A8F83` | `#767C6D` | Place labels on the map. |
| `mapLabelWater` | `#93A2A4` | `#5D6A6B` | Sea and water labels. Cooler than land labels on purpose. |

`mapLabel` and `mapLabelWater` join the existing `MapPalette` `ThemeExtension` alongside land / land-alt / water / roads.

**⛔ HUMAN — two dark values are undefined.** The canvas has only one dark artboard (map home), and neither `accentText` nor `dotInactive` appears on it. *Dev-time fallback:* `accentText` dark → `#E8A020` at full strength (the accent is legible as text on a dark ground, which is why the light theme needed a darker variant and the dark theme does not); `dotInactive` dark → `#3A4035`. Implement the fallbacks, leave the checkbox unticked, and note it.

Everything else the canvas uses resolves to an existing token. The audit in §14 confirms no other stray colours.

---

## 4. Global components

These recur across screens. Build them once, in `lib/app/theme/` or a shared `widgets/` directory, and reference them from every screen. Do not re-implement per screen.

### 4.1 Capture button

The single most important control in the app.

- 74 × 74, fully circular, fill `accent`
- Positioned bottom-centre, **62** from the bottom edge of the frame
- Glyph: a 30 × 30 circle, border **2.5px** solid `onAccent`, no fill — an aperture, not an icon from a font
- Light shadow: `0 0 0 4px surface @88%`, then `0 10px 24px ink @26%`
- Dark shadow: `0 0 0 4px surfaceDark @90%`, then `0 12px 28px black @55%`

The 4px ring is a spread shadow in the *surface* colour, not a border — it separates the button from a busy map without adding a stroke. Reproduce it as an outer container, not a `BoxBorder`.

- z-order: above the sheet peek, below nothing.

### 4.2 Sheet peek (collapsed trips sheet)

- Full width, **34** tall, anchored to the bottom edge
- Fill `surface` (light) / `surfaceDark`
- Radius **14** on the top two corners only
- Shadow: `0 -8px 22px ink @10%` light / `0 -8px 24px black @45%` dark
- Handle: **44 × 5**, radius 3, fill `line` (light) / `lineDark`, centred, **9** from the top of the peek

### 4.3 Position marker

Never the mascot. Three stacked layers in a 76 × 76 box, centred on the coordinate:

1. **Halo** — fills the 76 × 76 box, circular, fill `accent`, opacity **18%** light / **22%** dark. Animated: 3.4s, ease-in-out, infinite, alternating pulse.
2. **Heading cone** — 52 wide × 44 tall triangle (apex at the bottom, at the dot's centre), anchored so its base is above the dot. Fill is a vertical gradient, `accent @40%` at the base fading to `accent @0%` at the top (light); `@42%` dark.
3. **Dot** — 17 × 17 circle, fill `accent`, border **3px** `surface` (light) / `surfaceDark`. Shadow `0 2px 7px ink @30%` light / `0 2px 8px black @55%` dark.

The cone is drawn *above* the dot in the layout but *beneath* it in paint order.

### 4.4 Photo pin

- Outer ring: **58 × 58** circle, fill `surface` / `surfaceDark`, padding **3** — so the photo is **52 × 52**, circular
- Light shadow: `0 5px 12px ink @22%`
- Dark shadow: `0 0 0 1px inkDark @10%`, then `0 6px 16px black @50%`
- Pointer: **11 × 11** square, radius 2, same fill as the ring, rotated 45°, centred, with a **−6** top margin so it tucks under the circle
- Anchoring: the pin's **bottom-centre** (the pointer's tip) sits on the coordinate. In canvas terms `translate(-50%, -100%)`.

**Selected variant** (§10): outer **66 × 66**, padding 3, photo **60 × 60**; shadow `0 8px 20px ink @35%`; pointer **12 × 12**, top margin **−7**.

### 4.5 Cluster pin

- **54 × 54** circle, fill `accent`
- Count: DM Mono **500**, **18px**, letter-spacing **−0.6**, colour `onAccent`, centred, tabular figures
- Shadow `0 5px 14px ink @24%` light / `0 6px 18px black @50%` dark
- Pointer: 11 × 11 square, radius 2, **fill `accent`**, rotated 45°, −6 top margin
- Same bottom-centre anchoring as the photo pin
- Sits one z-level above photo pins

Never white on the amber. The count is `#231F0E`.

### 4.6 Primary button

- Height **56** (the "New trip" button in §11 is **54** — deliberate, keep it)
- Radius **14**, fill `accent`, no border, no shadow
- Label: Public Sans **600**, **16.5px** (New trip: **16px**), colour `onAccent`, centred

### 4.7 Quiet button (outlined)

- Height **44**, radius 14, **no fill**, border 1px `line`
- Label: Public Sans **500**, **14px**, colour `inkSoft`

### 4.8 Text field

- Height **56** single-line / **96** multi-line
- Radius 14, fill `surface`, border 1px `line`
- Single-line padding: horizontal **18**; multi-line padding: **15** vertical, **17** horizontal
- Text: Public Sans 400, **16px** (multi-line line-height **1.4**)
- Placeholder colour `inkFaint`

### 4.9 Settings card + row

- Card: radius 14, fill `surface`, border 1px `line`, `clipBehavior: antiAlias`
- Row: padding **14** vertical / **15** horizontal (toggle rows: **12** vertical)
- Label: Public Sans 400, **15.5px**, colour `ink`
- Value: DM Mono 400, **12.5px**, colour `inkSoft`, tabular figures
- Divider between rows: 1px `line`, **inset 15 from the left**, flush right

### 4.10 Section label

- DM Mono **500**, **10px**, letter-spacing **1.8**, uppercase, colour `inkFaint`, left padding **2**
- Followed by a **9** gap before its card

### 4.11 Metadata line

The mono voice, used for every place/date/count string.

- DM Mono 400, **11px**, letter-spacing **1.6** (list rows use **1.4**, headers **1.5**), uppercase, colour `inkFaint`
- Separator is a middle dot with spaces: `MALAY, AKLAN · 14 MAR 2025 · 4:42 PM`
- Always tabular figures

### 4.12 Toggle

- Track **46 × 27**, radius 14, padding 3
- On: track `accent`, knob `onAccent`, aligned right
- Off: track `line`, knob `surface`, aligned left
- Knob **21 × 21**, circular

---

## 5. Screen 01 — First run

Light only in the canvas. Ground `ground`. Status bar dark icons.

Content is inset **52** from the top (clearing the status bar) and **32** from both sides. Then, in order:

| # | Element | Spec |
| :--- | :--- | :--- |
| 1 | gap | **44** |
| 2 | Maya medallion | 192 × 192 circle, fill `surface`, border 1px `line`, padding **14**, centred. Image inside: 164 × 164, circular, `BoxFit.contain`. Asset: `assets/brand/maya.png`. |
| 3 | gap | **40** |
| 4 | Wordmark | `Warang` — Bricolage Grotesque **800**, **54px**, line-height 1.0, letter-spacing **−0.04em**, colour `ink`. Left-aligned. |
| 5 | gap | **12** |
| 6 | Promise | `A map you fill with your own photographs.` — Public Sans 400, **17px**, line-height **1.45**, colour `inkSoft`, max width **280**. |
| 7 | gap | **38** |
| 8 | Name field | §4.8 single-line. Placeholder: `What should we call you?` |
| 9 | gap | **12** |
| 10 | Start button | §4.6. Label `Start`. |
| 11 | gap | **26** |
| 12 | Privacy note | Public Sans 400, **13px**, line-height **1.6**, colour `inkFaint`. Exact text: *"Warang asks for your camera to take photos and your location to place them on the map. Your name, photos and pins are stored on this phone. Nothing leaves it."* |

The wordmark, promise and note are all left-aligned. Only the medallion is centred.

**No login. No signup. No skip link.** The name is optional in spirit — an empty name proceeds with a default. `Start` is never disabled.

---

## 6. Screen 02 — Map home, empty

Full-bleed map, no app bar, nothing between the user and the map.

**Layer order, bottom to top:**

1. **Map** — fills the frame edge to edge, behind the status bar.
2. **Top scrim** — height **78**, full width, vertical gradient `ground @82%` → `ground @0%` (dark: `groundDark @78%` → 0). Ignores pointer events. This is what makes the status bar readable over the map; it is not a header.
3. **Position marker** (§4.3) at the user's location — canvas places it at frame centre.
4. **Prompt bubble** — centred, **158** from the bottom. Padding 9 vertical / 15 horizontal, radius 14, fill `surface @94%`, shadow `0 2px 10px ink @9%`. Text `Capture your first moment.` — Public Sans 400, **13.5px**, colour `inkSoft`, single line.
5. **Sheet peek** (§4.2).
6. **Capture button** (§4.1).

Status bar: dark icons (light theme) / light icons (dark theme).

**The maya does not appear here.** The plan's §12.2/§12.5 wording allowed the mascot on empty states; the canvas overrules it for this screen, and the canvas is right — the maya never sits on a map. Maya is permitted only on first run (§5), the app icon, and non-map empty states (an empty trip, an empty search result).

**No recenter button in the canvas.** See §14, open question 3.

---

## 7. Screen 03 — Map home, filled (hero)

Everything from §6, minus the prompt bubble, plus pins.

Canvas pin positions, for the seeded demo and for your own eyeballing — these are **not** app logic, they are where the designer put them:

| Pin | x | y | Type |
| :--- | :--- | :--- | :--- |
| 1 | 100 | 272 | photo |
| 2 | 238 | 222 | photo |
| 3 | 156 | 398 | photo |
| 4 | 288 | 362 | photo |
| 5 | 82 | 508 | photo |
| 6 | 214 | 552 | cluster, count `12` |
| — | 150 | 646 | position marker |

Photo pins per §4.4, cluster per §4.5, all bottom-centre anchored.

**Density read:** six pins in a 390 × 844 frame with no overlap. That is the visual target for clustering thresholds — tune the zoom threshold in T6.2 so a screen looks about this busy, not busier. Overlapping pins are a clustering bug, not a rendering one.

**Accent count on this screen: 3** (cluster, position marker, capture button). At the ceiling of four with one to spare. Do not add a fourth amber element here.

---

## 8. Screen 04 — Map home, dark

Identical geometry to §7. Only colour changes. This is the reference for how *every* screen derives its dark variant, since it is the only dark artboard the canvas contains.

| Element | Light | Dark |
| :--- | :--- | :--- |
| frame ground | `#ECEDE8` | `#121410` |
| map land | `#E6E7E0` | `#1A1D18` |
| map land-alt | `#DCDED4` | `#22261F` |
| map water | `#CBD8DA` | `#141B1E` |
| map roads | `#F6F7F2` | `#2C3129` |
| map label | `#8A8F83` | `#767C6D` |
| map water label | `#93A2A4` | `#5D6A6B` |
| top scrim | `ground @82%` → 0 | `groundDark @78%` → 0 |
| status bar icons | dark | light |
| pin ring fill | `surface` | `surfaceDark` |
| pin shadow | `0 5px 12px ink @22%` | `0 0 0 1px inkDark @10%`, `0 6px 16px black @50%` |
| cluster shadow | `0 5px 14px ink @24%` | `0 6px 18px black @50%` |
| marker halo opacity | 18% | 22% |
| marker cone opacity | 40% | 42% |
| marker dot border | 3px `surface` | 3px `surfaceDark` |
| capture ring shadow | `surface @88%` | `surfaceDark @90%` |
| sheet peek fill | `surface` | `surfaceDark` |
| sheet handle | `line` | `lineDark` |
| home indicator | `ink @28%` | `inkDark @34%` |

**DERIVE — the rules this table encodes.** Apply them to screens 01, 05, 06, 07, 08, which have no dark artboard:

1. **Accent never changes.** `#E8A020` and `#231F0E` are identical in both themes. Amber is the constant.
2. **Swap tokens role-for-role.** `ground`→`groundDark`, `surface`→`surfaceDark`, and so on. Never invert or compute a dark value.
3. **Shadows change kind, not just strength.** Light shadows are tinted `ink` at low opacity. Dark shadows are **pure black at roughly double the opacity**, and gain a `0 0 0 1px inkDark @10%` hairline where an element must separate from a near-identical background. A dark shadow alone does not read.
4. **Scrims and dimmers get slightly *less* opaque in dark** (82%→78%, and see §11's dimmer), because the ground beneath is already dark.
5. **Glows get slightly *more* opaque in dark** (18%→22%, 40%→42%).

---

## 9. Screen 05 — Capture, save moment

No map. Photo on top, form below. The photo is the subject; everything under it is quiet.

**Photo region** — top 0, full width **390**, height **520** (61.6% of the frame). `BoxFit.cover`. Square corners, edge to edge, behind the status bar.

**Photo scrim** — height **96**, gradient `ink @42%` → `ink @0%`, top-anchored, ignores pointer events. Status bar icons are **light** on this screen regardless of theme.

**Retake chip** — top **62**, left **20**. Padding 8 vertical / 15 horizontal, radius 14, fill `ink @50%`. Label `Retake` — Public Sans **500**, **13.5px**, colour `surface`. Returns to the camera and discards the current shot.

**Form panel** — occupies the frame from y=**520** to the bottom. Fill `ground`. Padding **22** top, **24** horizontal.

| # | Element | Spec |
| :--- | :--- | :--- |
| 1 | Meta line | §4.11, letter-spacing 1.6. Format `PLACE · TIME`, e.g. `MALAY, AKLAN · 4:42 PM`. |
| 2 | gap | **16** |
| 3 | Caption field | §4.8 multi-line, height **96**. Placeholder `Say something (optional)`. |
| 4 | gap | **18** |
| 5 | Save button | §4.6, height 56. Label `Save`. |
| 6 | gap | **12** |
| 7 | Reassurance | Centred. Public Sans 400, **12.5px**, line-height 1.5, colour `inkFaint`. Exact text: *"Save now, caption later. One tap is enough."* |

**States the canvas does not draw, which you must still build (T5.6):**

- **No GPS fix.** The meta line has no place to show. Render it as `NO LOCATION YET · 4:42 PM` in the same style, and nothing else changes — no warning colour, no icon, no dialog, no blocked Save. It is not an error.
- **No place label.** Show the time alone: `4:42 PM`.

**Accent count: 1.**

---

## 10. Screen 06 — Moment card open

The card rises over the map. **The map never leaves.**

**Layers, bottom to top:**

1. Map, unchanged, still live.
2. Unselected photo pins, normal size, z-below the dimmer — so they get dimmed with everything else.
3. **Dimmer** — full-frame `ink @42%`. Animate in with the card.
4. **Selected pin**, above the dimmer, in the enlarged variant (§4.4): 66 outer / 60 photo, shadow `0 8px 20px ink @35%`, pointer 12 × 12 at −7. It stays undimmed and grows — that is what tells you which pin you opened.
5. Status bar: **light** icons (it now sits over a dimmed map).
6. **Card sheet** — bottom-anchored, height **472**, full width. Fill `surface`, radius **14** top corners only, shadow `0 -14px 40px ink @28%`. Padding **14** top, **16** horizontal.

Card contents, in order:

| # | Element | Spec |
| :--- | :--- | :--- |
| 1 | Handle | 44 × 5, radius 3, `line`, centred, **14** bottom margin |
| 2 | Photo | **358 × 224**, radius **14**, `BoxFit.cover` |
| 3 | gap | **16** |
| 4 | Caption | Public Sans 400, **16.5px**, line-height **1.45**, colour `ink` |
| 5 | gap | **12** |
| 6 | Meta line | §4.11. Format `PLACE · DATE · TIME`, e.g. `MALAY, AKLAN · 14 MAR 2025 · 4:42 PM` |
| 7 | gap | **18** |
| 8 | Divider | 1px `line`, full card width |
| 9 | gap | **16** |
| 10 | Action row | Three §4.7 quiet buttons, equal width, gap **10**: `Share` · `Edit` · `Delete` |
| 11 | flex | absorbs remaining height |
| 12 | Footer | Centred column, gap **9**, bottom padding **30**. Page dots: 6 × 6 circles, gap 6, active `ink`, inactive `dotInactive`. Below: `Swipe for nearby moments` — Public Sans 400, **11.5px**, colour `inkFaint`. |

**Note the action row is text, not icons.** The plan's Phase 7 called for "quiet icon actions"; the canvas resolved it as three equal outlined text buttons. The canvas wins — labels are unambiguous and `Delete` deserves to be readable.

**Accent count: 0.** There is no amber on this screen at all. That is correct and deliberate: the photograph is the only saturated thing here. Do not add an amber Share button.

**Empty caption:** omit element 4 and its gap entirely. Do not render placeholder text.
**No coordinates:** the meta line drops the place and shows `ADD LOCATION` as a tappable `inkSoft` segment, opening the edit sheet's manual pin placement (T7.4).

---

## 11. Screen 07 — Trips sheet, expanded

The sheet over a dimmed map.

- **Dimmer** — full-frame `ink @46%` (four points heavier than the moment card's, because the sheet covers more).
- Status bar: **light** icons.
- **Sheet** — top edge at y=**64**, extending to the bottom. Fill `surface`, radius 14 top corners, shadow `0 -14px 40px ink @30%`. Padding **14** top, **16** horizontal.

| # | Element | Spec |
| :--- | :--- | :--- |
| 1 | Handle | 44 × 5, radius 3, `line`, centred, **18** bottom margin |
| 2 | Header row | Baseline-aligned, space-between, horizontal padding **2**. Left: `Trips` — Bricolage Grotesque **700**, **28px**, line-height 1, letter-spacing **−0.03em**. Right: total count — §4.11 at letter-spacing **1.5**, e.g. `113 MOMENTS`. |
| 3 | gap | **18** |
| 4 | Everyday row | Padding **12**, radius 14, fill `ground`, border 1px `line`, row gap **14**. Thumb 56 × 56, radius **10**. Text column gap **5**: title `Everyday` — Bricolage 700, **18px**, line-height 1, letter-spacing −0.02em; below, §4.11 at letter-spacing 1.4, e.g. `CASUAL CAPTURES · 58 MOMENTS`. |
| 5 | gap | **22** |
| 6 | Section label | §4.10, `TRIPS` |
| 7 | gap | **12** |
| 8 | Trip cards | Column, gap **16**. Each: radius 14, `clipBehavior: antiAlias`, fill `ground`, border 1px `line`. Cover image full width × **132**, `BoxFit.cover`. Body padding **13** top / **15** sides / **15** bottom, gap **6**: title — Bricolage 700, **21px**, line-height 1, letter-spacing **−0.025em**; meta — §4.11 at letter-spacing 1.4, e.g. `MAR 12–19 · 24 MOMENTS`. |
| 9 | flex | min height **16** |
| 10 | New trip | §4.6 at height **54**, label size **16px**. Bottom padding **30**. |

Note the inversion: cards inside the sheet are `ground` on a `surface` sheet. Everywhere else `surface` sits on `ground`. Do not "fix" this.

The date range uses an **en dash with no spaces**: `MAR 12–19`. Cross-month: `NOV 2–6`. These come straight from the canvas.

**Snap points (T8.1).** The canvas draws two of the three:

- **Peek** — 34px (§4.2), the resting state over the map.
- **Expanded** — top at y=64, i.e. **0.924** of frame height.
- **Middle** — **not designed. DERIVE:** use **0.45**. At that height the Everyday row and the first trip card are both fully visible, which is the point of a middle stop. Flag it in your commit message so it can be reviewed.

**Planned-trip chip (T8.5)** is not in the canvas. **DERIVE:** render it in the meta line position as a separate pill — padding 4 vertical / 9 horizontal, radius 8, fill `line`, label `PLANNED` in DM Mono 500, 9px, letter-spacing 1.4, colour `inkSoft`. Not amber; a planned trip is not an alert.

**Accent count: 1.**

---

## 12. Screen 08 — Settings

Plain scrolling page. No map, no sheet.

Content inset **52** from the top, then padding **14** top / **20** horizontal.

| # | Element | Spec |
| :--- | :--- | :--- |
| 1 | Title | `Settings` — Bricolage Grotesque **700**, **30px**, line-height 1, letter-spacing **−0.03em** |
| 2 | gap | **22** |
| 3 | `YOU` | §4.10 |
| 4 | Profile card | Radius 14, fill `surface`, border 1px `line`, padding **14**, row gap **14**. Avatar 48 × 48 circle. Text column gap **3**: name — Public Sans **500**, **16px**; below — `Stored on this phone only`, Public Sans 400, **12.5px**, colour `inkFaint`. |
| 5 | gap | **20** |
| 6 | `STORAGE` | §4.10 |
| 7 | Storage card | Two §4.9 rows. Row 1: `Photos on this phone` / real computed size, e.g. `2.4 GB`. Row 2: `Back up everything` in Public Sans **500**, 15.5px, colour **`accentText`**, with a trailing chevron `›` in Public Sans 400, 15px, `inkFaint`. |
| 8 | gap | **20** |
| 9 | `MAP` | §4.10 |
| 10 | Map card | Row 1: `Theme` / `FOLLOWS PHONE`. Row 2: `Downloaded regions` / count — **see §14, open question 1.** |
| 11 | gap | **20** |
| 12 | `SHARING` | §4.10 |
| 13 | Sharing card | Two toggle rows (§4.9 at 12px vertical padding, §4.12). `Copy caption on share` — **on** by default. `Corner mark on images` — **off** in the canvas; see §14, open question 2. |
| 14 | gap | **20** |
| 15 | `ABOUT` | §4.10 |
| 16 | About card | Row 1: `Version` / `1.0.0`. Then a block, padding 14/15, gap **4**: `warang` in Public Sans 400, 15.5px; below, `Aklanon. To go out and explore.` in Public Sans 400, **13px**, line-height 1.45, `inkFaint`. |
| 17 | flex | min height **16** |
| 18 | Footer | Centred. `Everything stays on this phone.` — Public Sans 400, **12.5px**, `inkFaint`. Bottom padding **34**. |

**No account section. No sign-out. No sync row.** The `Back up everything` row is the only thing that touches the outside world, and it does so through the system share sheet.

The plan's T12.4 wants storage to expose the orphan sweep as "Clean up". The canvas does not draw it. **DERIVE:** add it as a third row in the Storage card, label `Clean up`, value = space reclaimable, styled as a normal §4.9 row (not `accentText` — only backup gets that emphasis).

**Accent count: 1** (the enabled toggle). `accentText` is a text colour, not an accent surface; it does not count against the ceiling.

---

## 13. Map style

This is the largest remaining piece of visual work and it blocks T4.1. The canvas draws the map as SVG, which is not a tile style — but it *is* a complete statement of intent, and the `.mbtiles` style must match it. Extract the following into your tilemaker/planetiler style:

**Fills, in paint order:**

1. Water fills the whole canvas as the base layer.
2. Land is drawn on top of water as a single polygon.
3. Land-alt marks parks, blocks and built-up areas — soft rounded rectangles (corner radius ~9 at the design scale) and ellipses, rotated a few degrees off-axis. Organic, not gridded.

**Roads** are strokes in the `roads` colour with round caps, in three weights:

| Class | Width |
| :--- | :--- |
| primary | **8** |
| secondary | **5** |
| minor | **3** |

Critically: **roads are lighter than the land in both themes** (`#F6F7F2` on `#E6E7E0` light; `#2C3129` on `#1A1D18` dark). Roads read as channels cut through the land, not as lines drawn on it. Do not use a darker road colour "for contrast" — it destroys the effect.

**Labels:** DM Mono, **9px**, letter-spacing **1.7**, **uppercase**, colour `mapLabel`; water labels in `mapLabelWater`. Place names only. **No POI icons, no building outlines, no road shields, no house numbers, no transit.** The map is a backdrop for photographs; anything that competes with a photo-pin is wrong.

Canvas label examples, all real Aklan/Visayas geography: `MALAY`, `BULABOG`, `DIWA`, `SIBUYAN SEA`.

**⛔ HUMAN — T4.1 remains blocked.** The style is now specified; the asset still has to be generated from an OSM extract. Keep building behind the `kDevTiles` flag. **The fallback must not ship** (T14.1).

---

## 14. Guardrail audit and open questions

I checked all eight artboards against the locked rules before writing any of the above.

**Passed:**

- **No login, signup, or account screen anywhere.** First run collects a name and nothing else.
- **Nothing white on amber.** Every element on `#E8A020` uses `#231F0E`: the Start button, the Save button, the New trip button, the cluster count, the capture button's aperture, the toggle knob.
- **Accent budget respected on every screen.** Counts: 01→1, 02→2, 03→3, 04→3, 05→1, 06→**0**, 07→1, 08→1. Ceiling is 4. Nothing is close.
- **The maya appears on exactly one artboard** — first run — and never over a map, never over a photo, never as the position marker.
- **Photos are the only saturated thing.** The moment card, which is the most photo-forward screen, has zero accent on it.
- **No gamification.** No points, streaks, badges, progress bars, or fog.
- **No colour near a photograph** — pin rings are `surface`, the moment card is `surface`, the capture screen's form is `ground`.

**Open questions — resolve these before or during the phase that hits them:**

1. **⛔ HUMAN — "Downloaded regions · 3" (Settings, §12).** This implies the user downloads map regions on demand, which contradicts a single bundled `.mbtiles` and implies a network fetch on the offline path. Three ways out: (a) drop the row; (b) relabel it `Bundled regions` and show what shipped, read-only; (c) genuinely build region downloading, which is a new feature with a network dependency and needs its own decision. *Dev-time fallback:* implement (b) — it is truthful about a bundled basemap and requires no new capability. Leave the checkbox unticked.

2. **⛔ HUMAN — "Corner mark on images" toggle (Settings, §12).** The brand rule says the wordmark always appears on the moment card and collage, never on a raw photo share. This toggle lets the user turn it off, which the rule did not anticipate. It also ships **off** in the canvas, meaning branding is opt-in by default. Confirm: is the corner mark user-controlled, and if so what is its default? *Dev-time fallback:* build the toggle, default it **on**, matching the brand rule; the canvas's off state is likely just a demonstration of the off style.

3. **⛔ HUMAN — recenter button (T4.5).** The plan calls for one at bottom-right. No artboard contains it. Either it was dropped, or it was overlooked. *Dev-time fallback:* build it — losing your own position with no way back is worse than one extra control. Spec: 44 × 44 circle, fill `surface` / `surfaceDark`, shadow `0 2px 10px ink @14%`, glyph a 20px crosshair stroked 1.6px in `inkSoft`. Right **20**, bottom **150** (clearing the capture button's shadow). **Not amber** — that would put a fourth accent on screen 03. Flag it for review.

4. **Dark variants for screens 01, 05, 06, 07, 08 do not exist.** Derive them with the §8 rules. This is expected work, not a blocker — but every derived screen needs an eyeball before its phase is tagged.

5. **Trip detail and share preview were deferred and are still undesigned.** Phases 8 (T8.3) and 10 (T10.7) will need either a design pass or your own judgement extended from the components here. Prefer extending §4 components over inventing new ones.

6. **Two dark token values are undefined** — `accentText` and `dotInactive`. See §3.

---

## 15. Drawer and local profile

The map home has a neutral hamburger control at **44 × 44**, positioned **16** from the left edge and **52** from the top. It uses the current theme surface, never amber, and has the same circular clipping as the recenter control.

The drawer is a slide-over panel **82% of the viewport width**, filled with the theme ground colour. It enters from the left over an on-surface scrim at **42% opacity**, matching the selected-moment dimmer. Tapping the scrim, swiping the drawer left, or completing a navigation action closes it. A **24px** edge gesture zone opens it with a rightward swipe.

The safe-area header uses **20px** horizontal padding and **18px** top padding. The profile avatar is **52 × 52**, circular, and is either the `PhotoStore`-resolved relative path or an amber fallback with the first initial. Tapping it opens the system photo picker and stores the imported image as a relative path. The display name is Public Sans 500 at **16px** and is edited through a modal field backed by the Drift profile row. The reassurance line is Public Sans 400 at **12.5px**. Counts sit below the header in DM Mono: value **17px/500**, label **9px/1.2px tracking**, and report **moments**, distinct non-empty place labels, and trips.

Navigation rows are ordered **Trips**, **Search**, **Settings**, **Backup & `.travelbook`**, and **About Warang**. Rows use **12px** corner radii, **12px** horizontal padding, **14px** vertical padding, a **20px** neutral icon, and **14px** gap before a Public Sans 400 label at **15.5px**. The footer uses DM Mono 400 at **9px**, **1.2px** tracking, and on-surface at **42%**, with version and build number.

The dark drawer derives from the §8 ground, surface, ink, and faint tokens. Amber is reserved for the profile fallback avatar; all navigation and counts remain neutral.

## 16. Tasks

These slot into the existing phases in `IMPLEMENTATION_PLAN.md`. Task IDs are `D`-prefixed so they never collide with the plan's own numbering, and existing ticked tasks are untouched.

### Into Phase 1 — Design system

- [ ] **D1.1** Add the four §3 tokens to `tokens.dart`, including the two ⛔ dark fallbacks.
- [ ] **D1.2** Extend `MapPalette` with `label` and `labelWater` in both variants.
- [ ] **D1.3** Text theme: the exact roles used in this spec — display 54/30/28/21/18, body 17/16.5/16/15.5/14/13.5/13/12.5/11.5, mono 13/12.5/11/10/9 — with the letter-spacings recorded per use. Tabular figures on every mono style.
- [ ] **D1.4** Extend the debug style gallery to render every §4 component in both themes side by side.

### Into Phase 4 — Map surface

- [ ] **D4.1** Encode §13 as the map style: fills, three road weights, label rules, both palettes.
- [ ] **D4.2** Top scrim (§6 layer 2) as a reusable widget, both themes.
- [ ] **D4.3** Position marker (§4.3) with the 3.4s pulse. Respect `MediaQuery.disableAnimations`.
- [ ] **D4.4** Capture button (§4.1) with the surface ring shadow.
- [ ] **D4.5** Sheet peek (§4.2).
- [ ] **D4.6** Recenter button per §14 question 3, flagged for review.

### Into Phase 5 — Capture

- [ ] **D5.1** Screen 05 exactly per §9, including the 520px photo region and the light status bar.
- [ ] **D5.2** The two undrawn meta-line states (no fix, no place label).

### Into Phase 6 — Pins

- [ ] **D6.1** Photo pin (§4.4), both themes, both sizes.
- [ ] **D6.2** Cluster pin (§4.5).
- [ ] **D6.3** Tune the clustering threshold against the §7 density target.

### Into Phase 7 — Moment card

- [ ] **D7.1** Card sheet per §10, including the dimmer and the enlarged selected pin.
- [ ] **D7.2** Page dots and swipe affordance footer.
- [ ] **D7.3** Empty-caption and no-coordinate variants.

### Into Phase 8 — Trips

- [ ] **D8.1** Expanded sheet per §11.
- [ ] **D8.2** Three snap points, with the derived 0.45 middle flagged.
- [ ] **D8.3** Planned chip per §11.

### Into Phase 12 — First run and settings

- [ ] **D12.1** Screen 01 per §5.
- [ ] **D12.2** Empty map state per §6 — bubble only, **no maya**.
- [ ] **D12.3** Settings per §12, including the derived Clean up row.
- [ ] **D12.4** Resolve §14 questions 1 and 2, or ship the stated fallbacks unticked.

### Into Phase 14 — Pilot hardening

- [ ] **D14.1** Dark-theme pass over every derived screen (01, 05, 06, 07, 08) against the §8 rules.
- [ ] **D14.2** Re-run the §14 audit on the built app: count accent uses per screen, confirm nothing white on amber, confirm the maya appears only on first run and the icon.

---

## 17. Assets

| Path | What | Status |
| :--- | :--- | :--- |
| `design/warang-canvas.html` | The exported design canvas, all 8 artboards. Open it in a browser to check anything this file left ambiguous. | in repo |
| `design/warang-maya.png` | The mascot: a maya holding a camera, on amber. Source for the app icon and the first-run medallion. | in repo |
| `assets/brand/maya.png` | Trimmed, transparent-background version for the first-run medallion (§5) — the medallion supplies its own `surface` circle, so the amber square must be removed. | **⛔ HUMAN** |
| `assets/fonts/*.ttf` | Bricolage Grotesque, Public Sans, DM Mono. Bundled, never fetched. | **⛔ HUMAN** (T1.1) |
| `assets/tiles/*.mbtiles` | Stylized basemap per §13. | **⛔ HUMAN** (T4.1) |
