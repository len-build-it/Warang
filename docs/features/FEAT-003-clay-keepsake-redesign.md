# FEAT-003: Clay keepsake redesign

Created: 2026-11-21T20:40:00+08:00
Updated: 2026-11-27T09:00:00+08:00
Revision: 2
Status: Approved - plan approved, not started

## Purpose and success

Len wants Warang to stop looking like the many generic, AI-generated apps on the Play Store, and to feel familiar to Gen Z while standing out.
The research behind this spec is [docs/research/RES-001-clay-motion-genz.md](../research/RES-001-clay-motion-genz.md).
This feature replaces Warang's visual system with a "clay keepsake" look: soft clay controls, Philippine travel-keepsake details, a wider colour palette, playful spring motion, and an interactive maya.

Success means:

- A screenshot of any main screen is recognisable as Warang with the logo hidden.
- Every existing user flow still works the same way and in the same number of taps or fewer.
- All text meets WCAG 2.2 AA contrast in both themes, which the current app does not.
- Panning the map and opening sheets stays smooth on a mid-range Android phone.
- Nothing in the app counts, judges, or pressures the user.

## Relationship to existing documents

`docs/DESIGN_SPEC.md` is the current visual authority.
When this revision is approved, the visual system, component, and screen sections of this spec replace `docs/DESIGN_SPEC.md` sections 1 and 3 to 15 for appearance and motion.
At that point `docs/DESIGN_SPEC.md` revision 1 is archived to `docs/archive/` with a link here, and the index is updated.
`docs/IMPLEMENTATION_PLAN.md` stays the authority for architecture, stack, data model, and commit protocol.
Until approval, `docs/DESIGN_SPEC.md` remains in force and nothing in this file may be implemented.

## Decisions already made by Len

| ID | Decision | Len's words and time (Asia/Manila) |
| --- | --- | --- |
| L-1 | Clay goes on controls and chrome; photos and the map stay flat. | "1. Sure", 2026-11-21 20:10 |
| L-2 | Amber is no longer the only colour; other colours may be used. | "2. No, you can choose to use other colors", 2026-11-21 20:10 |
| L-3 | The maya appears in more places and must be interactive. | "3. Yes we also need to make sure that the character is interactable", 2026-11-21 20:10 |
| L-4 | No streaks and no FOMO. | "4. Yes, the no streak rule should stay. We shouldnt force fomo to users", 2026-11-21 20:10 |
| L-5 | Fonts: Bagel Fat One, Atkinson Hyperlegible Next, Shantell Sans. | "Proceed with the proposed trio", 2026-11-21 19:57 |
| L-6 | The look comes from Philippine travel keepsakes. | "sure lets go with the philippine keepsake look", 2026-11-21 19:57 |
| L-7 | Drop the drawer; capture moves into a centre dock; profile becomes an avatar bubble. | "fine lets drop the drawer", 2026-11-21 19:57 |

## Scope and non-goals

In scope:

- New colour, type, shape, depth, motion, haptic, and icon tokens, in both themes.
- A shared set of clay components that every screen uses.
- Restyling every current screen: first run, map home, capture, moment card, edit sheet, pin placement, search, trips, trip detail, trip form, news, and settings.
- Replacing the bottom bar and drawer with the clay dock, the avatar bubble, and a "You" sheet.
- Replacing the Home tab dashboard (number tiles and charts) with the trip shelf.
- A colour for each trip.
- The interactive maya, with new layered artwork.
- Fixing the existing contrast failures listed in RES-001 section 4.3.

Out of scope:

- New capabilities such as home-screen widgets, trip recaps, sharing, backup, or sync.
- Any network call, account, analytics, or telemetry.
- Streaks, scores, badges, or any count of missed days.
  Amended 2026-11-23 by [FEAT-004](FEAT-004-places-search-stamps.md) with Len's approval: private category stamps under FEAT-004's kindness rules are allowed; streaks, scores, and counts of missed days stay out, and REQ-021 stays in force.
- New runtime package dependencies. Fonts and artwork are bundled assets. Rive is excluded unless Len approves it separately (see D-3).
- The map tile style in `docs/DESIGN_SPEC.md` section 13, which stays as it is apart from the pin changes here.

## Visual system

All sizes are Flutter logical pixels at a 390 by 844 baseline, as in the current spec.
Tokens live in `lib/app/theme/`, and widgets never use raw colour or size literals.

### V1. Neutral colours

| Token | Light | Dark | Notes |
| --- | --- | --- | --- |
| `ground` | `#F1EFE7` | `#15130F` | Screen background |
| `surface` | `#FBFAF5` | `#221F19` | Clay cards, sheets, dock |
| `surfaceRaised` | `#FFFFFF` | `#2B2720` | Polaroid border, raised clay in dark |
| `ink` | `#1A1D18` | `#EDEBE3` | Primary text, 14.8:1 light, 12.4:1 dark on raised |
| `inkSoft` | `#4F544A` | `#A9AE9F` | Secondary text, 6.76:1 light, 6.54:1 dark |
| `inkFaint` | `#646A5E` | `#8F9585` | Metadata and hints, 4.84:1 light, 4.81:1 dark |
| `boundary` | `#7E8475` | `#6A7062` | Field and toggle outlines, 3.35:1 light, 3.21:1 dark |
| `hairline` | `#E2DFD4` | `#34302A` | Decorative dividers only, never the only cue |
| `shadowTint` | `#5B4A2E` | `#000000` | Base colour of clay shadows |

### V2. Keepsake palette

Every fill takes `ink` `#1A1D18` for labels in both themes, and nothing is written in white on a fill.

| Token | Fill | Ink on fill | Light tint | Light text | Dark tint | Dark text |
| --- | --- | --- | --- | --- | --- | --- |
| `amber` | `#E8A020` | 7.69:1 | `#FBE7BE` | `#7F5C0F` | `#3A2E15` | `#F2B84B` |
| `gumamela` | `#E8664F` | 5.23:1 | `#F9D3CB` | `#A63A26` | `#3D211C` | `#F28A76` |
| `dagat` | `#2FA7A0` | 5.80:1 | `#C9EAE6` | `#1A6E69` | `#16312F` | `#5CC7BF` |
| `kalamansi` | `#86B83A` | 7.24:1 | `#DDEDC4` | `#4D6E1C` | `#25301A` | `#A6D163` |
| `ube` | `#9B7FD6` | 5.19:1 | `#E3DAF5` | `#6A4BB0` | `#2C2540` | `#B9A2EC` |
| `langit` | `#5A97DB` | 5.58:1 | `#D4E4F7` | `#285E9C` | `#1C2A3D` | `#86B6EC` |
| `santan` | `#F2909F` | 7.52:1 | `#FBDDE1` | `#A8435A` | `#3D2328` | `#F6A9B5` |

Every "text" value passes 4.5:1 on its own tint and on `ground`, and every dark text value passes 6:1 on its dark tint.

Colour rules:

1. Amber is the brand and the action colour. The capture button and the one primary button on a screen are amber, and no other colour is used for a primary action.
2. Each trip has one keepsake colour other than amber (see Data and interfaces). Everyday is neutral.
3. Large areas use tints. Solid fills are only for small objects: chips, stamps, pin rings, icon fills, and the dock indicator.
4. No colour, tint, or filter is ever drawn over a photo.
5. A screen shows amber plus at most two other keepsake colours, except the trip shelf and the map, where each trip shows its own colour.
6. Colour never carries meaning alone. Every coloured item also has a label, a shape, or a position that identifies it.

### V3. Typography

All three families are bundled under `assets/fonts/` with their OFL licence files, and none is fetched at runtime.
The licence of each font must be confirmed from its own licence file before it is bundled.
DM Mono, Public Sans, and Bricolage Grotesque are removed from the bundle.
All styles use tabular figures where numbers appear.

| Role | Family and weight | Size / line height | Tracking | Used for |
| --- | --- | --- | --- | --- |
| `wordmark` | Bagel Fat One 400 | 56 / 1.0 | -0.5 | "Warang" on first run |
| `displayL` | Bagel Fat One 400 | 34 / 1.05 | -0.3 | Screen titles: Trips, Search, News, Settings |
| `displayM` | Bagel Fat One 400 | 26 / 1.1 | -0.2 | Trip names on shelf cards and trip detail |
| `stampNumber` | Bagel Fat One 400 | 28 / 1.0 | 0 | Numbers inside stamps |
| `titleS` | Atkinson Hyperlegible Next 700 | 19 / 1.25 | 0 | Sheet titles, row titles, Everyday |
| `bodyL` | Atkinson Hyperlegible Next 400 | 17 / 1.45 | 0 | Main body text, field input |
| `body` | Atkinson Hyperlegible Next 400 | 15.5 / 1.45 | 0 | Settings rows, list text |
| `button` | Atkinson Hyperlegible Next 700 | 16.5 / 1.2 | 0.1 | Button labels |
| `meta` | Atkinson Hyperlegible Next 600 | 13.5 / 1.35 | 0.1 | Dates, places, counts, in sentence case |
| `caption` | Atkinson Hyperlegible Next 600 | 12 / 1.3 | 0.2 | Dock labels, stamp labels |
| `handL` | Shantell Sans 500 | 19 / 1.35 | 0 | User captions on polaroids |
| `hand` | Shantell Sans 500 | 15 / 1.3 | 0 | Maya speech bubbles, empty-state lines |

Rules:

- Bagel Fat One is used only at 24 and above, and never for more than one line of text.
- Shantell Sans is used only for words the user wrote or words the maya says.
- Metadata is written in sentence case, for example "Sat 14 Mar, 4:42 pm" and "Malay, Aklan", replacing uppercase mono strings.
- Text scales with the system font size up to 200%, and layouts reflow instead of clipping (see Q-3).

### V4. Shape

| Token | Radius | Used for |
| --- | --- | --- |
| `rChip` | 14 | Chips, stamps' inner panel, small buttons |
| `rControl` | 20 | Buttons, fields, toggles' track, list groups |
| `rCard` | 28 | Trip cards, settings groups, the You sheet's cards |
| `rSheet` | 32 | Top corners of every bottom sheet |
| `rPill` | full | Dock, capture button, avatar bubble, pins, speech bubbles |
| `rPhoto` | 6 | Photos inside a polaroid, so the photo reads as a print |

Stamps use a scalloped edge (a circle or rounded rectangle with 18 to 24 small bumps), drawn with a path.
Trip and moment cards may rotate between -2 and +2 degrees, and nothing else rotates.

### V5. Clay depth

Flutter's `BoxShadow` cannot draw inner shadows, so every clay surface is drawn by one shared widget, `ClaySurface`, which paints:

1. an outer shadow,
2. the fill,
3. a highlight: a soft gradient from the top-left edge inward,
4. a shade: a soft gradient from the bottom-right edge inward (light theme only),
5. in dark theme, a 1 px top rim instead of the highlight.

| Level | Light outer shadow | Light highlight | Light shade | Dark outer shadow | Dark rim |
| --- | --- | --- | --- | --- | --- |
| `clay1` | y 4, blur 10, `shadowTint` 14% | white 70%, 6 px deep | `shadowTint` 10%, 8 px deep | y 4, blur 12, black 40% | white 6% |
| `clay2` | y 10, blur 24, `shadowTint` 18% | white 80%, 8 px deep | `shadowTint` 12%, 10 px deep | y 10, blur 26, black 50% | white 7% |
| `clay3` | y 14, blur 30, `shadowTint` 24% | white 85%, 10 px deep | `shadowTint` 16%, 12 px deep | y 14, blur 32, black 60% | white 8% |
| `pressed` | y 2, blur 4, `shadowTint` 12% | white 40%, 4 px deep | `shadowTint` 20%, 12 px deep | y 2, blur 6, black 40% | white 4% |
| `inset` (fields) | none | `shadowTint` 10% from the top, 6 px deep | white 60% from the bottom, 4 px deep | none | black 30% inner top edge |

Coloured clay replaces white and `shadowTint` with tones of its own fill.
For amber: highlight `#FFD27A` 60%, shade `#B5770F` 45%, outer shadow `#8A5A10` 30%.
Other fills derive the same way: highlight is the fill lightened 25%, shade is the fill darkened 25%, and outer shadow is the fill darkened 45% at 30%.

Rules:

- Depth never carries meaning alone. A selected item also changes colour, label weight, or shows a check.
- Photos and the map are never clay. They may sit inside a clay frame.
- Map pins use a cached, pre-painted clay image per size and colour, so the map never paints live blurs (see Q-1).

### V6. Motion and haptics

Motion uses physical springs through Flutter's `SpringDescription` and `SpringSimulation`, with no animation package.

| Token | Duration (approx.) | Bounce | Used for |
| --- | --- | --- | --- |
| `press` | 90 ms, eased | none | Pressing any clay control: scale to 0.95, depth to `pressed` |
| `release` | 300 ms spring | 0.3 | Releasing a control: back to scale 1 with one small overshoot |
| `sheet` | 380 ms spring | 0.12 | Sheets and the moment card rising and settling |
| `pop` | 450 ms spring | 0.35 | Pins landing, chips and stamps appearing, the maya hopping |
| `slide` | 320 ms spring | 0.15 | Dock indicator moving, page and card swipes |
| `count` | 600 ms, eased out | none | Numbers counting up |
| `fade` | 150 ms, linear | none | The reduced-motion replacement for everything above |

Haptics use `HapticFeedback` from Flutter services:

| Event | Haptic |
| --- | --- |
| Capture pressed | `lightImpact` |
| Save a moment | `mediumImpact` |
| A new pin lands | `lightImpact` |
| Dock tab, toggle, chip, or date selected | `selectionClick` |
| Delete confirmed | `mediumImpact` |
| Maya tapped | `lightImpact` |

Rules:

1. Motion never delays an action. The camera opens on release of the capture button with no wait, and saving is written to the database before any celebration plays.
2. When `MediaQuery.disableAnimations` is true, every spring becomes `fade`, scale and rotation changes are skipped, counters show the final value, and idle loops stop.
3. At most one idle loop per screen, under 3 px of travel. The position marker's existing pulse counts as the map's loop.
4. No haptic fires during scrolling, panning, or idle motion.

### V7. Icons

A custom set of chunky clay icons replaces every `Icons.*` glyph.
Icons are drawn as 24 by 24 SVG on a 2.5 px rounded stroke with a soft duotone fill, converted at design time into a bundled icon font, and used as ordinary `IconData`.
No runtime SVG package is added.

| Glyph | Replaces | Shape |
| --- | --- | --- |
| `map` | `map`, `map_outlined` | Folded paper map |
| `trips` | `home`, `home_outlined` | Suitcase with a sticker |
| `news` | `article`, `article_outlined`, `auto_stories_outlined` | Postcard with a stamp |
| `search` | `search` | Magnifier |
| `searchEmpty` | `search_off_outlined` | Magnifier with a feather |
| `capture` | `photo_camera_outlined`, `camera_alt_outlined` | Kept as the existing aperture ring |
| `recenter` | `gps_fixed`, `near_me_outlined` | Small compass |
| `back` | `arrow_back` | Rounded arrow |
| `close` | `close`, `clear` | Rounded cross |
| `edit` | `edit_outlined` | Pencil |
| `delete` | none today | Bin |
| `pin` | `place` | Clay pin |
| `photo` | `photo_outlined`, `image_outlined`, `landscape_outlined` | Polaroid |
| `calendar` | `date_range_outlined` | Tear-off calendar |
| `settings` | `tune` | Small dial |
| `theme` | `wb_sunny_outlined` | Half sun, half moon |
| `info` | `info_outline` | Speech bubble with "i" |
| `refresh` | `refresh` | Rounded loop |
| `chevron` | `chevron_right` | Rounded chevron |
| `more` | none today | Three dots |
| `explore` | `explore_outlined` | Binoculars |

Rules:

- Every icon-only control keeps a tooltip and a semantic label.
- Dock items always show a text label under the icon.
- Selected icons fill with amber and animate once (the map unfolds, the suitcase lid bounces, the postcard flips). Unselected icons use an `inkSoft` stroke with a `hairline` fill.

### V8. Voice

| Current text | New text |
| --- | --- |
| Travel Mode (tab) | Map |
| Home (tab) | Trips |
| On-device analytics | Removed |
| Moments captured / Trips over time (charts) | Removed with the charts (see D-4) |
| YOUR MEMORIES | Removed; the shelf speaks for itself |
| CASUAL CAPTURES · 2 MOMENTS | Everyday, 2 moments |
| Offline map cache | Saved map areas |
| Stored on this phone only | Only on this phone |
| Capture your first moment. | Tap the camera to drop your first pin |
| What should we call you? | What should we call you? (unchanged) |

Copy stays short, plain, and kind.
Aklanon words appear only as brand touches with their English meaning nearby, as "warang" already does.

## Components

Every component is built once under `lib/app/theme/` and reused.

### C1. Clay dock

- A single `surface` pill at `clay2`, 72 tall, 12 from each side, 8 above the bottom safe-area inset.
- Five slots, left to right: Map, Trips, capture, News, Search.
- Side slots: 56 wide, 48 by 48 minimum tap target, icon 26, `caption` label 6 below the icon.
- The active slot has an amber-tint indicator blob 52 by 34 behind the icon that moves between slots with `slide` and stretches up to 1.3 times its width while moving.
- The capture slot is C2, centred, raised so its centre sits on the dock's top edge.
- On screens wider than 900 the dock becomes a vertical clay rail on the left with the same order, matching today's adaptive behaviour.
- The dock is visible on Map, Trips, News, and Search, and hidden on capture, sheets, forms, and settings.

### C2. Capture button

- 76 diameter amber clay disc at `clay3`, with a 4 px `surface` ring drawn as an outer spread, as today.
- The aperture glyph (30 diameter, 2.5 px `ink` ring) looks pressed into the surface: it has an `inset` shade inside the ring.
- Press: `press`, plus `lightImpact`. Release: the camera opens at once, and the button plays `release` underneath.
- Semantic label: "Capture a moment".

### C3. Avatar bubble and You sheet

- The avatar bubble is 48 diameter at `clay2`, 16 from the left and 8 below the status bar inset on the map.
- It shows the profile photo, or the maya's head on the user's own colour (the first trip colour, or amber when there are no trips).
- Tap opens the You sheet. Semantic label: "You, profile and settings".
- The You sheet is a C9 sheet with: the avatar at 72 diameter (tap to change photo, as today), the name in `displayM` (tap to edit, as today), "Only on this phone" in `meta`, three stamps (C6) for moments, places, and trips, then two rows: Settings and About Warang.
- This replaces every function of the current drawer. Search moves to the dock.

### C4. Buttons

| Variant | Fill | Height | Radius | Label | Depth |
| --- | --- | --- | --- | --- | --- |
| Primary | `amber` | 56 | `rControl` | `button`, `ink` | `clay2` |
| Secondary | `surface` | 48 | `rControl` | `button`, `ink` | `clay1` |
| Quiet | none | 44 | `rControl` | `button`, `inkSoft` | none, with a `boundary` outline |
| Danger | `gumamela` tint | 48 | `rControl` | `button`, gumamela text colour | `clay1` |

All buttons use `press` and `release`, and none ever uses white text.
There is at most one primary button per screen or sheet.

### C5. Fields

- Height 56 single-line and 104 multi-line, radius `rControl`, `surface` fill at `inset` depth, 1 px `boundary` outline.
- The label sits above the field in `meta` `inkSoft`, never as a floating label inside it.
- Focus: the outline becomes 2 px amber, and the field rises from `inset` to flat with `release`.
- Error: 2 px `gumamela` outline plus an error line in the gumamela text colour, so colour is not the only cue.
- Dropdowns (the trip picker) are replaced by a row of trip chips (C7) that scrolls sideways.

### C6. Stamp

- A scalloped circle 84 diameter, or a scalloped rounded rectangle 120 by 64, filled with a keepsake tint, with a 2 px dashed inner ring in the matching text colour.
- Contents: a number in `stampNumber` above a word in `caption`, or a place and date in `meta` for place stamps.
- Rotated between -8 and +8 degrees, decided once per item from its id so it does not change between visits.
- Appears with `pop` the first time it is shown in a session.

### C7. Chip

- Height 36, radius `rChip`, keepsake tint fill at `clay1`, `meta` label in the matching text colour, optional 18 icon.
- Selected: the fill becomes the solid colour, the label becomes `ink`, and a check icon appears.

### C8. Polaroid

- A `surfaceRaised` clay frame at `clay2`, with 12 on the top and sides and 60 on the bottom.
- The photo sits inside with `rPhoto` corners and no depth effects.
- The caption is written on the bottom strip in `handL` `ink`, two lines at most with an ellipsis.
- An optional place stamp overlaps the top-right corner.

### C9. Sheet

- `surface` fill, `rSheet` top corners, `clay3` upward shadow, a 40 by 5 handle in `boundary` 14 below the top edge.
- Rises with `sheet`, and closes with a downward swipe, a tap on the dimmer, or the system back gesture.
- Dimmer: `ink` 40% in light, black 55% in dark, faded in with the sheet.

### C10. Pins

- Photo pin: 58 outer clay disc at `clay1` (pre-painted), a 3 px ring in the trip's fill (`surface` for Everyday), a 2 px `surfaceRaised` inner ring, then a 48 photo. The pointer is an 11 by 11 rounded square in the ring colour, as today.
- Selected photo pin: 70 outer, 60 photo, `clay3`, grows with `pop`.
- Cluster pin: 54 amber clay disc, count in `stampNumber` at 20 `ink`. Clusters that hold more than one trip use the amber ring; clusters of one trip use that trip's fill for the ring.
- New pin: drops from 40 above its spot with `pop`, with a small clay "splat" ring that fades over 300 ms, and `lightImpact`.

### C11. Toggle

Removed by AUDIT-001 D-1 on 2026-11-26 because no screen used a toggle control.

- Track 52 by 32, radius `rPill`, `inset` depth, `boundary` outline when off.
- Knob 26 diameter at `clay1`.
- On: track becomes the amber fill, and a check mark appears in the knob, so state is not shown by colour alone.
- While moving, the knob stretches to 1.25 times its width and springs back (`slide`), with `selectionClick`.

### C12. Toast with undo

- A `surface` pill at `clay2`, 56 tall, 16 from the sides, above the dock.
- Message in `body`, action in `button` amber text colour, for example "Moment deleted" and "Undo".
- Rises with `sheet` and leaves after 4 seconds, as the current undo does.

### C13. Speech bubble

- `surfaceRaised` pill at `clay1`, `hand` text in `ink`, 12 by 8 padding, with a small tail toward the maya.
- Appears with `pop`, stays about 2 seconds, then fades.
- Never covers a control, and is skipped by screen readers.

### C14. Maya

The maya is one widget, `MayaCompanion`, with a pose and a size.
It is specified in full under "The maya" below.

## Screens

Each screen keeps its current behaviour and flow unless a change is listed.
Both themes are required for every screen.

### S1. First run

- Layout from top: the maya standing on a 180 diameter amber clay disc (C14 at 160) with a 2 px idle float, then "Warang" in `wordmark`, then the promise in `bodyL` `inkSoft`, then the name field (C5), then Start (C4 primary), then the privacy note in `meta` `inkFaint`.
- Text is left-aligned and the maya is centred, as today.
- While the name field has focus, the maya turns its head toward it.
- Start: the button presses, the maya hops, shrinks, and flies into the map's position marker as the map fades in. Under reduced motion it crossfades.
- Tapping the maya follows the gesture table under "The maya".

### S2. Map home

- The map fills the screen behind the status bar with the existing top scrim.
- The avatar bubble (C3) sits top left, and the recenter button (40 diameter `surface` clay, compass icon) sits on the right, 16 above the dock.
- The dock (C1) with the capture button (C2) sits at the bottom.
- Empty map: a speech bubble from the capture button says "Tap the camera to drop your first pin". The maya does not appear on the map.
- Pins use C10, coloured by trip.

### S3. Capture and save

- Photo region and form layout stay as today, with fields restyled (C5) and Save as C4 primary.
- The retake chip and close button become `surface` clay pills with icons and labels.
- The meta line becomes a place stamp (C6 rectangle) showing coordinates or place and time, and "Saving to Everyday" or the trip name becomes a chip (C7) in that trip's colour.
- The caption field placeholder is in `hand` so the user sees they are writing on the polaroid.
- Save: `mediumImpact`, the moment is written, then the photo shrinks into a circle and the app returns to the map, where the new pin lands (C10 new pin). Under reduced motion the screen closes and the pin fades in.
- Failure states (no location yet, retry) keep today's behaviour and wording.

### S4. Moment card

- A C9 sheet over the dimmed map, with the selected pin grown above the dimmer, as today.
- Content: a polaroid (C8) of the photo with its caption, a place stamp overlapping its top-right corner, the date and time in `meta` below, then Edit (C4 secondary) and Delete (C4 danger) side by side.
- Swiping sideways moves between nearby moments: the outgoing polaroid tilts 4 degrees and slides off with `slide`, and the selected pin on the map changes in step.
- Delete: the pin pops away, the sheet closes, and the toast (C12) offers Undo. Undo springs the pin back.
- No coordinates: the place stamp reads "Add location" and opens placement, as today.

### S5. Edit sheet and pin placement

- The edit sheet is a C9 sheet with Caption, Place name, and the trip chips row (C5, C7), then "Move pin on map" (C4 secondary) and Save (C4 primary).
- Placement keeps today's flow, with the centre pin drawn as a C10 pin that lifts 8 while the map moves and drops with `pop` when it stops, and Cancel and Confirm as C4 secondary and primary.

### S6. Trips (the shelf, replaces the Home tab)

- Title "Trips" in `displayL`.
- A row of three stamps (C6) for moments, places, and days, each in a different keepsake tint, counting up with `count` the first time per session.
- Everyday as a wide `surface` clay card with a fan of its three latest photos as small polaroids, its name in `titleS`, and its count in `meta`.
- Trips as a vertical list of cards: each card is the trip's tint at `clay2` with `rCard` corners, a cover polaroid on the left at 112 wide, the name in `displayM`, dates and count in `meta`, and a rotation of -1.5 or +1.5 degrees alternating by position.
- The maya perches on the top edge of the first trip card, or stands in the empty state when there are no trips with the line "Plan a trip and I'll pack my bag".
- New trip as C4 primary at the end of the list, and a new trip springs onto the shelf with `pop`.
- The number tiles and both charts are removed (D-4).

### S7. Trip detail

- Header: the trip's tint as a full-width band with the cover polaroid, the name in `displayM`, and dates and count in `meta`.
- Moments as a two-column grid of small polaroids, replacing the list rows.
- The options menu (edit, delete) is a `more` icon button that opens a C9 sheet with those two actions, keeping today's delete confirmation.

### S8. Trip form

- A C9-style full-screen sheet asking one thing at a time: "Where to?" (trip name, required), then "Where is it?" (place, optional), then "When?" (dates, optional), then "Pick a colour" (the six trip colours as C7 chips, preselected).
- Back and Next sit at the bottom; Create is the C4 primary on the last step.
- All fields remain optional except the name, as today.
- This adds the colour choice only. The trip's other behaviour is unchanged.

### S9. Search

- A dock tab. Title "Search" in `displayL`, then a pill-shaped C5 field that is focused on open.
- Results are rows with a 56 polaroid thumbnail, caption in `titleS`, and place and date in `meta`, appearing in a 30 ms stagger.
- No results: the maya with binoculars and "Nothing here yet, try another word" in `hand`.

### S10. News

- A dock tab. Title "News" in `displayL`.
- Each bundled note is a postcard: a `surfaceRaised` clay card at `clay1`, a stamp in the top-right corner, title in `titleS`, and body in `body`.
- Empty or still loading: a clear message and the maya holding a blank postcard, replacing the lone dot seen in the current screenshots.

### S11. Settings

- Opened from the You sheet. Title "Settings" in `displayL` with a back button.
- Groups are `surface` clay cards (`rCard`, `clay1`) with section labels in `meta` `inkSoft` sentence case.
- Rows are 56 tall with `body` labels and `meta` values. Settings rows have no toggles.
- Theme stays a read-only row that says "Follows your phone", as today. Adding a manual theme choice is out of scope.
- The footer line "Everything stays on this phone" sits beside a small sitting maya.

### S12. About

- Opened from the You sheet. The maya at 120, the wordmark, the version, and "Aklanon. To go out and explore." in `hand`.

## The maya

### M1. Artwork

The maya is redrawn as layered artwork: body, head, eyes (open, closed, happy), beak, two wings, feet, the camera, and props (bag, postcard, binoculars, nightcap, party hat).
Each layer is a separate transparent image exported at 1x, 2x, and 3x, plus a single flat image for the app icon.
Poses are made by moving, rotating, and swapping these layers in Flutter, with no animation package.
The artwork itself needs an illustrator or Len (see D-2).

### M2. Where the maya appears

| Place | Size | Pose |
| --- | --- | --- |
| First run | 160 | Idle float, head tilt toward the name field |
| Avatar bubble (no photo) | 40 head only | Idle |
| Trip shelf | 56 | Perched on the first trip card |
| Empty shelf, search, trip, and news | 120 | Contextual (bag, binoculars, postcard) |
| Milestone toast | 48 | Cheer |
| Settings footer, About | 40 and 120 | Sitting |

The maya never appears on the map, over a photo, or on the capture screen.

### M3. Touch

| Gesture | Reaction | Haptic |
| --- | --- | --- |
| Tap | Hops once and says one short line for that place | `lightImpact` |
| Three or more taps within 2 seconds | Gets dizzy, wobbles, shakes it off | `lightImpact` on the last tap |
| Long press | Puffs up its feathers and settles on release | `selectionClick` |
| Drag | Moves up to 24 with resistance, then springs back | none |

Lines come from a small bundled list per place, never repeat twice in a row, and are in English with the occasional Aklanon word.
If the same reaction is triggered more than five times in a minute, the maya plays a calmer version.

### M4. Context

The maya reacts only to information already on the phone.

| Situation | Pose |
| --- | --- |
| Local time 23:00 to 05:00 | Sleepy, nightcap |
| Today is a trip's start date | Holding a packed bag |
| A trip's end date has passed and it has moments | Holding a postcard |
| The user is typing a caption (edit sheet only) | Foot tapping |
| A milestone was just reached | Cheer, in the milestone toast |

Milestones are: the first moment ever, the first moment in a trip, and a moment more than 25 km from every earlier moment ("Somewhere new!").
These need no geocoding and no network.

### M5. Kindness rules

1. The maya is never sad, disappointed, lonely, or waiting because of something the user did or did not do.
2. The maya never sends notifications and never appears outside the app.
3. The maya never covers or blocks a control, and every action works without touching it.
4. Lines are a few words and disappear on their own.
5. Milestones are only celebrated, never counted down, chained, or shown as missed.

### M6. Accessibility

The maya has the semantic label "Maya, the Warang mascot" and is announced once per screen.
Its lines and reactions are not announced, because they never hold information the user needs.
With reduced motion, reactions become a pose change with `fade`.

## User flows

The flows are unchanged except for these navigation changes:

| Flow | Before | After |
| --- | --- | --- |
| Open search | Drawer, or the Home tab search icon | Search tab in the dock |
| Open settings | Drawer | Avatar bubble, then Settings |
| Edit name or photo | Drawer header | Avatar bubble, then the You sheet |
| See moment, place, and trip counts | Drawer | You sheet stamps and the Trips shelf stamps |
| About | Drawer | Avatar bubble, then About Warang |
| Choose a trip in the edit sheet | Dropdown | Chip row |
| Create a trip | Single form | Four short steps, with a colour step |

Empty, offline, error, and denied-permission states keep today's behaviour and wording, restyled with these components, and use the maya only where M2 allows.

## Data and interfaces

- **Trip colour (D-1):** the recommended approach adds a nullable `colorKey` text column to the trips table, holding one of `gumamela`, `dagat`, `kalamansi`, `ube`, `langit`, `santan`. New trips get the next colour in that order after the most recently created trip's colour. Existing trips get colours assigned in creation order by the migration. A null value falls back to a colour picked from the trip id. Everyday keeps a null value and is drawn neutral. This is a schema change and a Drift migration, so it follows `docs/IMPLEMENTATION_PLAN.md` commit rules.
- **Milestones:** computed from existing moments, trips, and coordinates when a moment is saved. The last milestone shown is stored in the existing app metadata so it is not shown twice. No new table is needed.
- **Maya lines:** a bundled JSON asset next to `assets/data/news_items.json`.
- **Fonts and icons:** bundled assets with licence files.
- **No network, no analytics, and no new permissions.**

## Requirements and acceptance criteria

| ID | Required behavior | Observable pass/fail criterion |
| --- | --- | --- |
| REQ-001 | All colours come from the V1 and V2 tokens. | `grep -rn "Color(0x" lib --include=*.dart` matches only files under `lib/app/theme/`. |
| REQ-002 | All text meets WCAG 2.2 AA in both themes. | A token test computes contrast for every text and background pair used and asserts at least 4.5:1, or 3:1 for text 24 and above. |
| REQ-003 | Field, toggle, and selected-state outlines meet 3:1. | The same test asserts `boundary` against `ground` and `surface` is at least 3:1 in both themes. |
| REQ-004 | Only the three new font families are bundled and used. | `pubspec.yaml` lists Bagel Fat One, Atkinson Hyperlegible Next, and Shantell Sans only; each has a licence file in `assets/fonts/`; `grep -rn "DM Mono\|Public Sans\|Bricolage" lib` returns nothing. |
| REQ-005 | No stock Material icon is used. | `grep -rn "Icons\." lib` returns nothing. |
| REQ-006 | Every icon-only control has a tooltip or semantic label. | A widget test walks every screen and finds no tappable icon without a semantic label. |
| REQ-007 | The dock replaces the bottom bar and drawer. | `warang_drawer.dart` no longer exists; widget tests find the dock with Map, Trips, capture, News, and Search in that order. |
| REQ-008 | Capture opens with no added delay. | A widget test taps the capture button and finds the capture flow started in the same frame as the tap is released. |
| REQ-009 | Saving a moment shows the new pin landing on the map. | A widget test saves a moment and finds the new pin on the map, with a landing animation running when animations are enabled. |
| REQ-010 | Reduced motion is honoured everywhere. | With `disableAnimations` true, widget tests on every screen find no scale or rotation transition and no repeating animation. |
| REQ-011 | Every user flow still works. | All existing widget and data tests pass after being updated only for new widget types and text. |
| REQ-012 | Settings, profile, search, and About are reachable without the drawer. | Widget tests reach each one from the map in two taps or fewer. |
| REQ-013 | Each trip has a keepsake colour. | Data tests: a new trip gets the next colour; migration assigns colours to existing trips in creation order; Everyday has none. |
| REQ-014 | Trip colours appear on shelf cards and pin rings. | Golden screenshots show each trip's tint on its card and fill on its pins. |
| REQ-015 | No colour or filter is drawn over photos. | Code review: no `ColorFilter`, tint, or overlay is applied to any photo widget. |
| REQ-016 | The Trips shelf replaces the dashboard. | `analytics_charts.dart` no longer exists; the Trips tab shows the stamps, Everyday, and trip cards. |
| REQ-017 | The maya appears only where M2 allows. | Widget tests find `MayaCompanion` on the listed screens and not on the map, capture, or moment card. |
| REQ-018 | The maya reacts to tap, repeated taps, long press, and drag. | Widget tests drive each gesture and find the expected pose. |
| REQ-019 | The maya never shows a sad or waiting pose. | The pose enum contains no sad, lonely, or waiting value. |
| REQ-020 | Milestones fire once and need no network. | Data tests cover first moment, first in a trip, and more than 25 km away, and show each fires once. |
| REQ-021 | Nothing counts streaks or missed days. | Code review: no code computes consecutive days or gaps. |
| REQ-022 | Layouts survive 200% text size. | Golden screenshots at text scale 2.0 show no clipped or overlapping text on every screen. |
| REQ-023 | Map panning stays smooth with pins. | A profile-mode run on Len's phone with at least 50 pins shows no frames over 16 ms on the UI or raster thread during a 10-second pan (Len records the result). |
| REQ-024 | Dark theme follows the dark clay rules. | Golden screenshots of every screen in dark mode exist and are reviewed by Len. |
| REQ-025 | No new runtime package dependencies. | `pubspec.yaml` dependencies are unchanged except for removed ones. |

## Quality constraints

- **Q-1 Performance:** map pins are pre-painted images, never live blurs. `ClaySurface` caches its gradients per size. The current `BackdropFilter` glass is removed. Every animated subtree has a `RepaintBoundary`.
- **Q-2 Accessibility:** 48 by 48 minimum touch targets, WCAG 2.2 AA contrast, semantics on every control, colour never the only cue, and reduced motion honoured.
- **Q-3 Text scale:** the dock hides labels above 160% text scale and keeps tooltips, and all other layouts reflow.
- **Q-4 Offline and privacy:** unchanged from today. Nothing new leaves the phone.
- **Q-5 Evidence:** golden screenshots in both themes for every screen go to `docs/evidence/FEAT-003/`, and physical-device checks stay pending until Len runs them.

## Decisions and assumptions

Confirmed by Len: L-1 to L-7 above.

Proposed decisions that need Len's answer before approval:

| ID | Question | Recommendation |
| --- | --- | --- |
| D-1 | How is a trip's colour stored? | A nullable `colorKey` column with a migration, so users can choose and keep a colour. The alternative, deriving it from the trip id, needs no migration but cannot be changed by the user. |
| D-2 | Who draws the layered maya artwork? | Len or an illustrator draws it from the existing maya. The feature can be built with placeholder layers first, but it cannot be approved as finished without the real artwork. |
| D-3 | Use Rive for the maya? | No. Flutter transforms are enough for these poses, and Rive adds a dependency and a separate tool. |
| D-4 | Remove the Home tab charts? | Yes. They read as a finance dashboard and go against the keepsake look. The stamps keep the useful numbers. |
| D-5 | Dock order? | Map, Trips, capture, News, Search. |
| D-6 | Ship the contrast fixes first? | Yes, as the first phase, because they fix accessibility failures that exist today. |

Observed facts:

- The current app uses 30 distinct stock Material icons, DM Mono uppercase metadata, Bricolage Grotesque headings, and Public Sans body text.
- `inkFaint` text is 2.82:1 on `ground` and field borders are 1.26:1 today.
- Only two animations exist today: the capture button press and the position marker pulse.
- The News tab shows only a small dot in the 2026-11-21 screenshots, and map tiles do not load in the test host.

Assumptions:

- Bagel Fat One, Atkinson Hyperlegible Next, and Shantell Sans are available under the SIL Open Font License from Google Fonts. This must be confirmed from each licence file before bundling.
- Flutter's `SpringDescription` supports the spring settings in V6 on the project's SDK (^3.12.2). If not, the same springs are expressed with mass, stiffness, and damping.

## Open questions and readiness

- D-1 to D-6 are answered as recommended (see approval below).
- Blocking for completion, not for starting: the layered maya artwork (D-2).
- Approved: Len approved revision 1 with the recommended answers to D-1 to D-6 on 2026-11-21 at 20:37 (Asia/Manila) by choosing "Approve as recommended" on the project-thread decision card "Approve FEAT-003 revision 1 with the recommended answers to D-1 to D-6?".
- After approval, the next step is `docs/plans/FEAT-003-implementation.md` with phases, for example: 1 contrast and tokens; 2 fonts and icons; 3 `ClaySurface`, motion, and haptics; 4 dock, avatar bubble, and You sheet; 5 map, pins, capture, and moment card; 6 trips, trip detail, and trip form with trip colours; 7 search, news, settings, and About; 8 the maya; 9 dark-mode and text-scale pass with golden evidence.


External names: `rPill`, `rPhoto`, `BoxShadow`, `map_outlined`, `home_outlined`, `article_outlined`, `auto_stories_outlined`, `search_off_outlined`, `photo_camera_outlined`, `camera_alt_outlined`, `gps_fixed`, `near_me_outlined`, `arrow_back`, `edit_outlined`, `photo_outlined`, `image_outlined`, `landscape_outlined`, `date_range_outlined`, `wb_sunny_outlined`, `info_outline`, `chevron_right`, `explore_outlined`, `warang_drawer`
