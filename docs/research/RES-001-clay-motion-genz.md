# RES-001 - Claymorphism, playful motion, and Gen Z UI research

Created: 2026-11-21T19:45:00+08:00
Updated: 2026-11-21T20:25:00+08:00
Status: Draft research for discussion with Len.
This is not an approved spec.
It changes no behaviour, no tokens, and no code, and it does not override `docs/DESIGN_SPEC.md`.

## 1. Summary

Gen Z is not asking for one look.
The strongest evidence says young users prefer expressive, tactile, high-energy interfaces, but only when the basic interaction patterns stay familiar and the purpose is clear.
Claymorphism fits that trend, but no credible study shows Gen Z prefers claymorphism as such.
The adjacent evidence is Google's Material 3 Expressive research and Pinterest's Gen Z-led "squishy, jelly, 3D" aesthetic trend.

Warang is not a social app.
It has no feed, no account, and no followers, so most "social app" patterns do not transfer.
The ones that do transfer are camera-first launch, small private circles, no filters, recaps of past moments, and home-screen presence.
Warang already does the first three.

The recommended direction is "clay chrome, flat content".
Controls, pins, sheets, and the navigation become soft, squishy clay objects with playful spring motion.
Photos and the map stay flat and quiet, so the current rule "photos are the only saturated thing on screen" survives.
The signature interaction is "the photo becomes a pin": after Save, the photo squashes into a round pin and drops onto the map with a soft bounce and a haptic tap.

Four product decisions are Len's to make, listed in section 8.
Section 9 explains why the current screens read as generic and proposes distinctive typography, icons, and layout, with three more decisions.
Len has now decided all seven questions (sections 8 and 9.7).
Section 10 proposes the keepsake colour palette that replaces the amber-only rule, and section 11 specifies the interactive maya.

## 2. Evidence: what Gen Z actually prefers

Each source is rated by how much weight it deserves.
"Strong" means a disclosed method and a large or peer-reviewed sample.
"Moderate" means a disclosed method with a small sample or vendor bias.
"Weak" means opinion, marketing data, or unclear method.

### 2.1 Expressive design beats neutral design for 18 to 24 year olds (moderate to strong)

Google ran 46 studies with more than 18,000 participants for Material 3 Expressive, using eye tracking, surveys, focus groups, and usability tests.
Up to 87% of 18 to 24 year olds preferred the expressive versions, and younger participants were the most enthusiastic.
Participants found key elements up to four times faster in the expressive versions.
Expressive designs scored higher on "playful", "friendly", "energetic", and "modern" (a 34% boost in modernity).
The five levers Google names are colour, shape, size, motion, and containment.

The caveats matter as much as the headline.
When a playlist became scattered album art, usability scores dropped because people no longer recognised it as a playlist.
Removing text labels from email actions reduced usability.
Google writes that when "basic interaction paradigms are broken", expressive design leads to poor usability, and that "a strong minority of users preferred calmer, less intense versions".
This is Google's own write-up of internal research, with no per-study samples or statistics published.

Source: [Google Design, "Better, Easier, Emotional UX"](https://design.google/library/expressive-material-design-google-research).

### 2.2 Authenticity through constraint, but constraints create pressure (moderate)

A CSCW 2024 paper interviewed 29 BeReal users aged 13 to 18 (mean 15.6) in December 2022 and January 2023.
Participants tied authenticity to specific design features: the two-minute window, the dual camera, no filters, no picking from the gallery, reciprocal posting, and a small, hard-to-grow friend list.
They valued that the app is single-purpose and worried that more features would make it "like Instagram".
They also reported stress from the retake counter, the "late" label, visible reactions, and the daily cadence, and some found it repetitive.

The lesson for Warang is to keep its "no filters, no performance" stance and avoid any mechanic that counts or judges the user.

Source: [Kim et al., "Sharing, Not Showing Off", PACM HCI CSCW 2024](https://arxiv.org/html/2408.02883v1).

### 2.3 Home-screen presence and small circles (moderate, industry reporting)

Locket puts friends' photos in a home-screen widget instead of sending push notifications.
Appfigures estimates more than 91 million lifetime installs, and the CEO reported 2 million users in October 2025.
Its 2025 Rollcall feature uses a weekly Lock Screen Live Activity to prompt a recap of the week, and the company reports over a million shares in the first week.
About 80% of Rollcall's early users were Gen Alpha, which suggests the pattern is getting stronger with younger cohorts, not weaker.
TechCrunch's 2022 analysis described BeReal, Locket, and LiveIn as engaging users through widgets and notifications "instead of forcing people to spend a long time browsing", with photos that avoid "heavy editing, filters or AR effects".

Sources: [TechCrunch, Nov 2025](https://techcrunch.com/2025/11/03/lockets-social-app-is-picking-up-steam-with-gen-alpha), [TechCrunch, Jun 2022](https://techcrunch.com/2022/06/16/the-next-big-social-platform-isthe-smartphones-homescreen).

### 2.4 Tactile, squishy, 3D aesthetics are a Gen Z-led trend (moderate, search data)

Pinterest says 67% of its 2026 trends are driven by Gen Z, based on year-over-year search growth across 600 million monthly users.
"Gimme Gummy" is a Gen Z and Millennial trend for bendy, rubbery, jelly textures, with "jelly blush" searches up 130% and "jelly candy aesthetic" up 100%.
Gen Z respondents were 38% more likely to say they have embraced self-expression.
The 2025 edition had "Player One", about customising avatars and profile pictures.
This is consumer taste data, not UI preference data, so it supports the mood of claymorphism rather than its usability.

Sources: [Pinterest Predicts 2026](https://newsroom.pinterest.com/news/pinterest-predicts-nonconformity-self-preservation-and-escapism-drive-21-trends-for-2026/), [Pinterest Predicts 2025](https://newsroom.pinterest.com/en-gb/news/pinterest-predicts-20-bold-trends-for-2025/).

### 2.5 Young adults click first and dislike "trying too hard" (strong method, dated)

Nielsen Norman Group tested 91 people aged 18 to 25 across 7 countries and 372 sites, plus diary and survey studies.
They were confident, error-prone, and would "click first, and ask questions later".
They liked interactivity "only when it serves a purpose", were sensitive to tone, and noticed when a product was "trying too hard to appear cool".
The study is from 2016 and covers the oldest Gen Z and youngest Millennials, so treat it as a durable behavioural baseline rather than a current taste signal.

Source: [NN/g, "Designing for Young Adults"](https://www.nngroup.com/articles/young-adults-ux/).

### 2.6 Opinion pieces worth reading, not citing as proof (weak)

Smashing Magazine's 2024 guide argues that short-form content does not mean short attention spans, and lists accessibility, dark and light modes, and reduced motion as baseline expectations.
It reports no study of its own.
Aufait UX's "tactile maximalism" article coins a useful phrase but its statistics are second-hand and contradict each other (two different "82%" dark-mode figures), so this doc does not rely on them.

Sources: [Smashing, "Designing For Gen Z"](https://www.smashingmagazine.com/2024/10/designing-for-gen-z/), [Aufait UX](https://www.aufaitux.com/blog/tactile-maximalism-gen-z-ui/).

### 2.7 What the evidence does not say

No study found shows Gen Z prefers claymorphism specifically over other expressive styles.
No study found measures how Gen Z feels about micro-interactions or haptics in isolation.
Claims online that Gen Z has an "8-second attention span" trace back to discredited sources and are not used here.

## 3. Observed patterns in apps Gen Z uses

This section is my own analysis of the apps, not cited research.

| Pattern | Seen in | Transfers to Warang? |
| --- | --- | --- |
| Opens straight to the camera | Snapchat, BeReal, Locket | Already done: one tap opens the camera |
| Map of your own places and memories | Snap Map, Instagram's map | Yes, this is Warang's core, and it makes Warang feel familiar |
| Big, rounded, thumb-reach controls at the bottom | TikTok, Snapchat, Locket | Yes, the capture button and nav already do this |
| Bouncy, physical feedback on taps | Snapchat, Duolingo, Locket | Yes, this is the main gap today |
| Mascot with personality | Duolingo, Snapchat's ghost | Partly, the maya is underused by current rules |
| Weekly or yearly recap | Spotify Wrapped, Locket Rollcall, Instagram photo dumps | Yes, as a private trip recap, later |
| Home-screen widget | Locket, BeReal | Yes, "a moment from this day", later |
| Streaks and counts | Snapchat, Duolingo, BeReal | No, it conflicts with the no-gamification rule and BeReal users report stress from it |
| Feeds, likes, followers | Instagram, TikTok | No, Warang is private by design |

## 4. Review of the current app

Reviewed from the 30 screenshots in `docs/evidence/FEAT-001/claude-review/`, `lib/app/theme/tokens.dart`, `lib/app/theme/components.dart`, and `docs/DESIGN_SPEC.md`.

### 4.1 What is already right for Gen Z

Capture is one tap and the camera opens directly.
There are no filters, no account, and no feed, which matches what BeReal users valued.
The amber and maya brand is warm and distinctive.
The bottom navigation and capture button are already large, rounded, and thumb-friendly.
Light and dark both exist and follow the system theme.

### 4.2 What makes it feel flat today

There is almost no motion.
The only animations are a 90 ms press on the capture button and the 3.4 s position-marker pulse.
Nothing celebrates a saved moment, a new trip, or a new place.
Sheets, cards, and settings are flat outlined rectangles at radius 14, so every screen reads the same.
The navigation bar uses blurred glass, which looks generic next to iOS and Android system chrome.
The maya appears only on first run, so the app loses its personality after the first screen.

### 4.3 Accessibility issues found that exist today

These are independent of the redesign and worth fixing either way.

| Issue | Measured contrast | WCAG need |
| --- | --- | --- |
| `inkFaint` `#8A8F83` text on `ground` `#ECEDE8` (metadata, privacy note, footers) | 2.82:1 | 4.5:1 for text (1.4.3) |
| `inkFaint` on `surface` `#F7F8F3` | 3.10:1 | 4.5:1 for text |
| Text field and card border `line` `#D2D5CB` on `ground` | 1.26:1 | 3:1 where the border is what identifies the field (1.4.11) |
| Dark `line` `#2E332A` on `darkGround` | 1.43:1 | Same as above |

Amber with `accentInk` text passes at 7.44:1, and the rule "nothing white on amber" is correct.

### 4.4 Other things noticed in the screenshots

The map is blank grey in every screenshot, likely because the emulator had no tiles cached, so the review could not judge pins against a real map.
The News tab shows only a small dot in the middle of the screen, which looks like a stuck loading state or an empty state with no message.
The moment card and trip cover show a placeholder icon, so the photo-forward screens could not be judged with real photos.
These are worth a separate check before any visual redesign is approved.

## 5. Proposed direction: clay chrome, flat content

### 5.1 Principles

1. **Clay is for things you touch.** Buttons, pins, chips, toggles, sheets, the nav bar, and cards are clay. Photos, the map, and body text are flat.
2. **Photos come first, colour supports them.** Superseded in part by Len's decision 2: amber is no longer the only colour. Section 10 defines a keepsake palette and the rules that keep it from competing with photos.
3. **Familiar first, playful second.** Keep every layout and interaction pattern people already know. Add delight in feedback and transitions, never by moving or hiding controls. This follows Google's finding that breaking paradigms hurts usability.
4. **Nothing slows down a capture.** Motion runs alongside an action, never before it.
5. **No judging the user.** No streaks, counters of missed days, or "late" labels.
6. **Calm by default, playful on intent.** Idle screens are still. Motion answers a touch or marks an achievement. This respects the "strong minority" who prefer calmer interfaces.

### 5.2 Clay tokens (proposal)

Values are chosen to fix the contrast issues in 4.3 while warming the palette toward clay.
Every text pair below was checked against WCAG 2.2 relative luminance.

**Light**

| Token | Current | Proposed | Contrast check |
| --- | --- | --- | --- |
| `ground` | `#ECEDE8` | `#F1EFE7` | - |
| `surface` | `#F7F8F3` | `#FBFAF5` | - |
| `ink` | `#1A1D18` | `#1A1D18` | 14.8:1 on ground |
| `inkSoft` | `#5C6157` | `#4F544A` | 6.76:1 on ground |
| `inkFaint` | `#8A8F83` | `#646A5E` | 4.84:1 on ground, 5.34:1 on surface |
| `fieldBoundary` (new) | - | `#7E8475` | 3.35:1 on ground, 3.69:1 on surface |
| `accentText` | `#8A6412` | `#7F5C0F` | 5.3:1 on ground |
| `accent` | `#E8A020` | `#E8A020` | unchanged |
| `accentInk` | `#231F0E` | `#231F0E` | 7.44:1 on amber |

**Dark**

| Token | Current | Proposed | Contrast check |
| --- | --- | --- | --- |
| `ground` | `#121410` | `#15130F` | - |
| `surface` | `#1B1E18` | `#221F19` | - |
| `surfaceRaised` (new) | - | `#2B2720` | - |
| `ink` | `#E9EBE3` | `#EDEBE3` | 12.4:1 on raised |
| `inkSoft` | `#A0A697` | `#A9AE9F` | 6.54:1 on raised |
| `inkFaint` | `#767C6D` | `#8F9585` | 4.81:1 on raised |
| `fieldBoundary` (new) | - | `#6A7062` | 3.21:1 on surface |

**Shape**

| Token | Value | Used for |
| --- | --- | --- |
| `radiusChip` | 14 | chips, small buttons |
| `radiusControl` | 20 | buttons, fields, toggles |
| `radiusCard` | 28 | cards, trip tiles, settings groups |
| `radiusSheet` | 32 | top corners of sheets |
| `radiusPill` | 999 | nav bar, capture ring, pins |

The jump from 14 everywhere to a 14, 20, 28, 32 scale is what makes surfaces read as soft and inflated.

**Depth (the clay recipe)**

Claymorphism uses one outer shadow plus two inner shadows: a dark one on the bottom right and a light highlight on the top left ([Smashing, 2022](https://www.smashingmagazine.com/2022/03/claymorphism-css-ui-design-trend/)).
Three levels are enough.

| Level | Outer shadow (light theme) | Inner highlight | Inner shade |
| --- | --- | --- | --- |
| `clay1` resting | 0 4 10, warm umber `#5B4A2E` @ 14% | top-left, white @ 70%, blur 6 | bottom-right, `#5B4A2E` @ 10%, blur 8 |
| `clay2` raised | 0 10 24, umber @ 18% | white @ 80%, blur 8 | umber @ 12%, blur 10 |
| `clay3` hero (capture, selected pin) | 0 14 30, umber @ 24% | white @ 85%, blur 10 | umber @ 16%, blur 12 |
| `pressed` | 0 2 4, umber @ 12% | white @ 40% | umber @ 20%, larger |

Amber clay uses tinted layers instead of white and umber: highlight `#FFD27A` @ 60%, shade `#B5770F` @ 45%, outer shadow `#8A5A10` @ 30%.
Shadows are warm-tinted on purpose, because neutral grey shadows look dirty against amber and warm neutrals.

**Dark mode clay**

Clay depends on light, so dark mode cannot copy the light recipe.
Use elevation by lightness (`ground`, `surface`, `surfaceRaised`) as the main cue.
Replace the white highlight with a 1 px top rim at white @ 6% to 8%.
Use black outer shadows at roughly double the light opacity, which matches the existing rule in `DESIGN_SPEC.md` section 8.
Drop the inner shade entirely, because a dark shade on a dark surface is invisible and only costs paint time.
Amber clay keeps its tinted highlight in dark mode, because it is the one bright object on screen.

### 5.3 Motion principles

1. **Springs, not curves.** Use physical springs for anything the finger moves or releases. Flutter's `SpringDescription` and `SpringSimulation` cover this with no new dependency.
2. **Squash on press, overshoot on release.** Pressed controls scale to 0.95 and sink to `pressed` depth in about 90 ms. On release they spring back with one small overshoot.
3. **Three speeds.** Micro feedback 100 to 150 ms, component transitions 250 to 350 ms, celebrations 500 to 700 ms and rare.
4. **One bounce, not a wobble.** A damping ratio around 0.6 to 0.7 gives one visible overshoot. Anything bouncier reads as childish, which is the main criticism of claymorphism.
5. **Haptics pair with meaning.** `HapticFeedback.selectionClick` for toggles and tab changes, `lightImpact` for a pin landing, `mediumImpact` for Save. Never haptics on scroll or idle motion.
6. **Reduced motion is a first-class mode.** When `MediaQuery.disableAnimations` is on, springs become 150 ms crossfades, scale changes are removed, and idle loops stop. The position marker already does this.
7. **Idle motion is tiny and optional.** At most one idle loop per screen, under 3 px of travel, and off with reduced motion.

### 5.4 Micro-interactions per screen

**First run**
The maya medallion becomes a clay disc with a slow 2 px idle float.
When the name field is filled, the maya does a small head tilt toward it.
The Start button squashes on press, and the medallion shrinks into the map position marker as the app opens, linking the mascot to "you are here" without putting the maya on the map.

**Map home**
The capture button becomes a hero amber clay disc with the aperture glyph pressed into it.
On press it squashes, gives a `lightImpact`, and the camera opens on release with no added delay.
The bottom navigation becomes a single clay pill, and the active indicator is a soft blob that stretches between tabs as it moves.
Photo pins become small clay discs with the photo inset, and they lift slightly when the map is panned to them.
Cluster counts roll to the new number instead of jumping.

**Capture and save (signature moment)**
After Save, the photo squashes into a circle, shrinks into a pin, and the app returns to the map.
The new pin drops into place with one bounce and a `lightImpact`.
If this is the first moment at a new place, the place name appears briefly as a clay chip above the pin.
The whole sequence is under 700 ms, and it starts after the database write so it never delays saving.
With reduced motion, the pin simply fades in.

**Moment card**
The card rises on a spring and the selected pin grows with one overshoot, extending what `DESIGN_SPEC.md` section 10 already describes.
Swiping between nearby moments tilts the outgoing card slightly and moves the highlighted pin on the map in sync.
Edit and Delete become clay buttons.
Delete squashes the pin and pops it away, and Undo springs it back into place.

**Home and trips**
Trip cards become clay tiles at `radiusCard` with the cover photo inset and flat.
Pressing a tile sinks it to `pressed` depth.
Moment, place, and day counters count up the first time the screen appears in a session.
Charts draw in from left to right once, then stay still.
Creating a trip springs the new tile onto the shelf.

**Search**
The search field is a clay pill.
Results stagger in at about 30 ms apart.
An empty result shows the maya looking through binoculars, which the current rules already allow for non-map empty states.

**Settings and drawer**
Toggles become clay tracks with a knob that stretches slightly while travelling and gives a `selectionClick`.
Settings groups become clay cards with the new field boundary where a boundary carries meaning.
Drawer counts roll up when the drawer opens.

**Trip form and edit sheet**
Fields are clay insets (pressed depth) so they read as places to type, with the 3:1 boundary.
The primary button is amber clay.
Choosing dates pops each selected day as a small chip.

### 5.5 Future ideas that fit the research

These are not part of the redesign and would each need their own feature spec.

A private home-screen widget showing "a moment from this day" would bring the Locket pattern to Warang with no network or account.
A private trip recap, built when a trip ends, would bring the Rollcall and Wrapped pattern without any public sharing.
Maya reactions to milestones, such as a first moment somewhere new, would add personality without streaks or scores.

## 6. Risks and how to handle them

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Contrast | Soft UI is known for failing WCAG because shapes blend into the background ([Axess Lab](https://axesslab.com/neumorphism/), [BOIA](https://www.boia.org/blog/how-soft-user-interface-designs-impact-accessibility)) | Shadows never carry meaning on their own. Every control has a label or a 3:1 boundary. Text uses the tokens in 5.2. |
| Pressed versus selected | Inset clay can look like "selected" or "disabled" | Selected states also change colour or add a check, not only depth. |
| Reduced motion | Springs and overshoot can trigger vestibular discomfort | Follow 5.3 point 6 everywhere, and test with the system setting on. |
| Childish feel | The main known criticism of claymorphism | Keep typography and layout as they are, use one bounce, and keep amber as the only accent. |
| Performance | Flutter has no inset `BoxShadow`, and blurred shadows on dozens of map pins are expensive | Build one shared clay widget that paints highlights with gradients and cached shapes. Wrap pins in `RepaintBoundary`. Avoid blur on map layers. Replacing the current `BackdropFilter` glass nav with clay should reduce cost. |
| Dark mode | Light-based depth disappears on dark surfaces | Use the dark recipe in 5.2 and review every screen in both themes. |
| Scope creep | A visual refresh touches every screen and every widget test | Ship it as a feature with phases: tokens, shared clay widget, motion system, then screens one at a time. |
| Spec conflict | `DESIGN_SPEC.md` fixes radius 14, flat outlined cards, and the maya's placement | A redesign needs a revised design spec approved by Len before implementation. |
| New dependencies | Packages such as an inset-shadow library or Rive would help | Not needed. Everything here can be done with Flutter's painting, physics, and services libraries. Any dependency would need Len's approval. |

## 7. Suggested next steps

1. Decide the questions in sections 8 and 9.7. Done on 2026-11-21.
2. Fix the existing contrast failures in 4.3 as a small, separate change, since they are bugs today.
3. Build a one-screen prototype of the map home and capture flow with the clay tokens and the "photo becomes pin" interaction, in both themes, and record it on a real Android device.
4. If the prototype holds up, write a revised design spec and a feature spec with phases, and approve them before wider implementation.

## 8. Decisions for Len

**Decided by Len on 2026-11-21T20:10:26+08:00 in the project thread:**

- Decision 1: clay on controls and chrome, with flat photos and map, as recommended.
- Decision 2: amber does not have to be the only colour, and other colours may be used. Section 10 proposes the palette.
- Decision 3: the maya appears in more places, and it must be interactive. Section 11 specifies how.
- Decision 4: the no-gamification and no-streak rule stays. In Len's words, "We shouldnt force fomo to users".

These record direction only and do not approve implementation.

The original options were:


1. **How far should clay go?**
   Recommended: clay on controls and chrome, flat photos and map.
   Alternatives: clay everywhere including photo frames, or clay only on the capture button and pins as a lighter touch.
2. **Should the "photos are the only saturated thing" rule stay?**
   Recommended: keep it, with amber as the only brand colour.
   Alternative: add a small pastel clay palette for trips (for example mint, lilac, peach) so each trip gets its own colour, which is more "Gen Z playful" but competes with photos.
3. **Should the maya appear in more places?**
   Recommended: yes in non-map empty states and milestone moments, never on the map or over photos.
   Alternative: keep it on first run only.
4. **Should the no-gamification rule stay?**
   Recommended: keep it, and use private recaps and milestones instead of streaks, based on the BeReal pressure findings.
   Alternative: allow a gentle, non-punishing count such as "places visited this year".

## 9. Making it distinct, not generic

Added 2026-11-21T20:05:00+08:00 after Len said the layout, fonts, and icons feel generic and AI-generated.

### 9.1 Why the current screens read as generic

This is my analysis of the screenshots and code, not cited research.

| Tell | Where it shows | Why it reads as generic |
| --- | --- | --- |
| Bricolage Grotesque headings with DM Mono uppercase, letter-spaced metadata | Every screen, for example `CASUAL CAPTURES · 2 MOMENTS` and `ON-DEVICE ANALYTICS` | This exact pairing (quirky grotesque, plus a mono "label" voice) is a default look of AI design tools in 2025 and 2026. The original canvas was itself exported from an AI design tool. |
| Stock Material outlined icons | 30 different `Icons.*` glyphs, such as `home_outlined`, `map_outlined`, `article_outlined`, `wb_sunny_outlined` | Every Flutter template ships these, at the same stroke weight and size. |
| Sage-grey neutrals with one warm accent | Whole palette | The "calm neutral plus one accent" palette is the safest choice, so thousands of apps make it. |
| One radius (14) on every rectangle | Cards, fields, buttons, sheets, chips | Nothing has a shape of its own, so every screen is a stack of the same box. |
| Stock layout pieces | `AppBar` with back arrow, `ListTile` with chevron, outlined floating-label fields, `DropdownButtonFormField`, three-tab bottom bar, hamburger drawer | These are the Material defaults, unchanged. |
| A dashboard on the Home tab | Three KPI tiles (4 MOMENTS, 0 PLACES, 4 DAYS) and two line charts | KPI tiles and line charts are the most common AI-generated "home" layout, and they feel like a finance app, not a travel memory. |
| Dashboard and system copy | "Travel Mode", "On-device analytics", "Moments captured", "Offline map cache" | The words describe the software, not the trip. |
| Full-width amber button at the bottom of every form | Onboarding, capture, trip form, edit sheet | Fine on its own, but repeated with nothing else distinctive, it becomes the whole personality. |

The map, the maya, the one-tap capture, and the "photo becomes a pin" idea are the parts that are already Warang's own.
The fix is to make the rest come from the same place those come from: travel, Aklan, and physical keepsakes.

### 9.2 A source for the look: a travel keepsake from Aklan

Generic apps borrow from other apps.
Distinct apps borrow from the physical world.
Warang's name is Aklanon and its mascot is the maya, so the visual language should come from Philippine travel objects rather than from Material or iOS.

Candidate sources, all things people already associate with travel:

- **Passport stamps and ticket stubs** for place and date metadata, replacing the uppercase mono labels.
- **Polaroid and photo-booth strips** for how photos are framed on cards and in trips.
- **Postcards and pen-pal letters** for the News tab and captions, which also matches Pinterest's Gen Z-led "Pen Pals" trend (searches for "snail mail gifts" up 110%).
- **Hand-painted jeepney and sari-sari store lettering** for a few big, loud moments such as the wordmark and milestone numbers.
- **Woven banig and piña patterns** (Aklan is known for piña weaving) as subtle textures for empty states and the ground, used with care and never as a costume.

Clay fits this well, because these are all objects you can pick up.

### 9.3 Typography

Recommendation: drop DM Mono and the uppercase tracked label style everywhere, and choose fonts that are softer and more personal.
Every candidate below is on Google Fonts under the SIL Open Font License, so it can be bundled offline like the current fonts and adds no package dependency.
Licences should be confirmed from each font's own licence file before bundling.

| Role | Current | Recommended | Alternatives | Why |
| --- | --- | --- | --- | --- |
| Display (screen titles, wordmark, big counts) | Bricolage Grotesque 700 and 800 | **Bagel Fat One** | Dela Gothic One, a custom jeepney-style wordmark | Chunky, inflated letters look like clay themselves, and few apps use it. Use it only for large sizes. |
| Body and UI | Public Sans | **Atkinson Hyperlegible Next** | Figtree, Nunito Sans | Designed by the Braille Institute for legibility, with slightly unusual letterforms that do not look like the usual AI defaults. It supports the accessibility goals in section 6. |
| Personal voice (captions, place stamps, maya's lines) | Public Sans | **Shantell Sans** | Gaegu, Patrick Hand | Hand-drawn but still readable, and its variable "bounce" and "informal" axes could animate slightly on milestones. |
| Metadata | DM Mono uppercase, letter-spaced | Body font in sentence case, for example "Sat 14 Mar, 4:42 pm" | - | Natural case is warmer and easier to read than tracked capitals. |

Use three voices with clear jobs: loud (display), clear (body), and personal (handwritten).
The handwritten voice should be limited to things the user wrote or the maya says, so it stays special.

### 9.4 Icons

Recommendation: a small custom icon set of about 20 glyphs, replacing all 30 stock Material icons.

- **Style:** chunky, rounded 2.5 px strokes with a soft duotone fill, so each icon looks like a small clay object. Active icons get the amber fill, inactive ones a neutral fill.
- **Metaphors:** keep the shapes people already recognise, and add a travel twist. Map becomes a folded paper map. Trips becomes a suitcase. News becomes a postcard. Search stays a magnifier. Settings becomes a small dial. Delete stays a bin. Google's research is clear that unfamiliar or unlabelled icons hurt usability, so the shape stays familiar and the label stays visible.
- **Motion:** icons can do a one-shot animation when selected, such as the map unfolding or the suitcase lid bouncing.
- **How to ship it:** draw the icons as SVG and convert them to a bundled icon font at design time, then use them as normal `IconData`. This needs no runtime dependency. Animated versions can be done with `CustomPainter`.

### 9.5 Layout and composition

The goal is that someone could recognise a Warang screenshot with the logo cropped out.

**Map home: one clay dock instead of a nav bar plus a floating button.**
Merge the capture button into the centre of a single clay dock, with Map and Trips on either side.
Snapchat and Instagram users already know "capture in the middle", so it stays familiar while removing the stock three-tab bar.
Replace the hamburger with the user's avatar as a small clay bubble at the top left, which opens the profile.

**Home becomes a trip shelf, not a dashboard.**
Remove the KPI tiles and line charts.
Show trips as slightly rotated polaroid-style clay cards (plus or minus 2 degrees) that can be flicked through, with Everyday as a pocket at the front.
Show stats as passport stamps, for example "12 places" stamped in amber, and keep any deeper numbers behind a tap.

**Moment card becomes a polaroid.**
Frame the photo in a white clay border with a thicker bottom edge.
Write the caption in the handwritten voice on that bottom edge.
Show place and date as a stamp in the corner, not a mono line.

**Forms become one question at a time.**
New trip asks "Where to?" with one big field, then dates, using sheets that spring up.
This replaces the stock floating-label form, keeps the thumb zone, and makes the forms feel like the rest of the app.

**Varied shapes, not one box.**
Use the radius scale in 5.2, plus circles for pins and avatars, pills for the dock and chips, and the polaroid for photos.
Allow a few deliberate imperfections, such as slight rotation and overlap, only where the content is personal (trips and moments), never on settings or forms.

**Voice.**
Rename the dashboard words.
"Travel Mode" becomes "Map", "On-device analytics" is removed, "Moments captured" becomes something like "Where you've been", and empty states are spoken by the maya.
Aklanon words can appear as small brand touches, as the name already does, with the English meaning nearby.

### 9.6 Risks of going distinct

| Risk | Mitigation |
| --- | --- |
| Too much personality hurts clarity | Keep familiar positions and labels for every control. Personality goes into shape, type, and motion, not into where things are. |
| Display font legibility | Bagel Fat One only at 24 px and above, never for body text or long titles. |
| Rotation and overlap feel messy | Limit them to trip and moment cards, and test them with long titles and many trips. |
| Cultural patterns used carelessly | Use banig and piña patterns as subtle texture only, and check the meaning of any pattern before using it. |
| Custom icons are work to maintain | Keep the set small (about 20) and document the drawing rules so new icons match. |
| Bigger change to `DESIGN_SPEC.md` | This replaces the typography and component sections of the spec, so it needs a revised spec and Len's approval before implementation. |

### 9.7 More decisions for Len

**Decided by Len on 2026-11-21T19:57:30+08:00 in the project thread:**

- Decision 5: use the recommended trio, Bagel Fat One, Atkinson Hyperlegible Next, and Shantell Sans.
- Decision 6: go with the Philippine travel keepsake look.
- Decision 7: drop the drawer, merge capture into a centre clay dock, and use an avatar bubble for the profile.

These record direction only.
They do not approve implementation, which still needs a revised design spec and Len's approval.
Decisions 1 to 4 in section 8 are still open.

The original options were:

5. **Typography:** the recommended trio (Bagel Fat One, Atkinson Hyperlegible Next, Shantell Sans), one of the alternatives, or a type test of two pairings on the map home and trip shelf first.
6. **Visual source:** "Philippine travel keepsakes" (stamps, polaroids, postcards, jeepney lettering, woven textures), or a more neutral "toy clay" look without local references.
7. **Navigation:** merge capture into a centre clay dock and replace the drawer with an avatar bubble, or keep the current three-tab bar and only restyle it.

## 10. Keepsake colour palette

Proposed after Len's decision 2.
The palette comes from the same Philippine keepsake source as section 9.2: hand-painted jeepneys, sari-sari store signs, fruit, flowers, and the sea.
Names are Filipino words so the palette has its own identity, and code can use them as token names.

### 10.1 Colours

Every pair below was checked against WCAG 2.2.
"Ink on fill" is the dark `ink` `#1A1D18` used for labels on the solid colour.
"Text colour" is the darker version for coloured text on the light ground and on the tint.

| Name | Meaning | Fill | Ink on fill | Tint (light) | Text colour (light) | Tint (dark) | Text colour (dark) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `amber` | Brand, capture, the maya | `#E8A020` | 7.69:1 | `#FBE7BE` | `#7F5C0F` (5.02:1 on tint) | `#3A2E15` | `#F2B84B` (7.42:1) |
| `gumamela` | Hibiscus red | `#E8664F` | 5.23:1 | `#F9D3CB` | `#A63A26` (4.67:1) | `#3D211C` | `#F28A76` (6.05:1) |
| `dagat` | Sea teal | `#2FA7A0` | 5.80:1 | `#C9EAE6` | `#1A6E69` (4.71:1) | `#16312F` | `#5CC7BF` (6.85:1) |
| `kalamansi` | Citrus green | `#86B83A` | 7.24:1 | `#DDEDC4` | `#4D6E1C` (4.77:1) | `#25301A` | `#A6D163` (7.86:1) |
| `ube` | Purple yam | `#9B7FD6` | 5.19:1 | `#E3DAF5` | `#6A4BB0` (4.81:1) | `#2C2540` | `#B9A2EC` (6.53:1) |
| `langit` | Sky blue | `#5A97DB` | 5.58:1 | `#D4E4F7` | `#285E9C` (5.12:1) | `#1C2A3D` | `#86B6EC` (6.85:1) |
| `santan` | Ixora pink | `#F2909F` | 7.52:1 | `#FBDDE1` | `#A8435A` (4.57:1) | `#3D2328` | `#F6A9B5` (7.66:1) |

All fills use dark ink for labels in both themes, so "nothing white on colour" carries over from the current amber rule.
Body text `ink` passes at over 12:1 on every light tint, and dark `ink` `#EDEBE3` passes at over 11:1 on every dark tint.

### 10.2 Where colour goes

1. **Amber stays the brand and the action colour.** The capture button, the primary button on each screen, and the maya are amber. No other colour is used for a primary action.
2. **Each trip gets a keepsake colour.** It is chosen automatically in rotation when a trip is created and can be changed in the trip form. The colour appears on the trip's shelf card backing, its stamps, its chips, and as the ring of its photo pins on the map. Everyday stays neutral.
3. **Stamps, stickers, and postcards use the palette** for decoration, such as a place stamp in `dagat` or a postcard edge in `gumamela`.
4. **Tints for surfaces, fills for small objects.** Large areas such as a card backing use the tint. Solid fills are limited to small objects such as chips, stamps, pin rings, and icons.
5. **Photos stay untouched and unframed by colour.** Colour sits next to a photo, never over it, and never as a tint or filter on it. The polaroid border stays white clay.
6. **At most two keepsake colours per screen plus amber**, except the trip shelf, where each card shows its own trip colour.
7. **Colour never carries meaning alone.** A trip is identified by its name and cover, not only by its colour, so colour-blind users lose nothing.

### 10.3 Map pins with trip colours

A coloured pin ring (3 px, the trip's fill) is the main new use on the map.
It lets people see which trip a cluster of pins belongs to at a glance.
Everyday pins keep the neutral surface ring.
Clusters that mix trips use the neutral ring with the amber count, as today.

### 10.4 Risks

| Risk | Mitigation |
| --- | --- |
| Colour competes with photos | Rules 4 to 6 above, and review with real photos before approval. |
| Fills below 3:1 against the light ground (gumamela, dagat, ube, langit) | Solid fills always have a label or sit on their tint, and pins keep the white clay inner ring, so the shape never depends on the fill's contrast alone. |
| Palette feels like a children's app | Mid-saturation fills, mostly tints, and the clay depth carry the softness. Typography and spacing stay grown-up. |
| Changes the `DESIGN_SPEC.md` accent budget rule | The revised spec replaces "accent at most four times" with the rules in 10.2. |

## 11. The interactive maya

Proposed after Len's decision 3.
The maya becomes a small companion that lives in the app's quiet places and reacts to touch, without ever guilt-tripping the user.

### 11.1 Where the maya lives

| Place | What it does there |
| --- | --- |
| First run | Greets the user, tilts its head toward the name field, and flies off to become the "you are here" marker when Start is pressed |
| Avatar bubble (top left of the map) | Default avatar until the user picks a photo, in the user's chosen trip colour |
| Trip shelf | Perches on the edge of the shelf, above the first trip card |
| Empty states | No trips yet, no search results, an empty News tab, a trip with no moments |
| Milestones | Appears briefly after the first moment ever, the first moment in a trip, and a moment more than 25 km from every earlier one (no geocoding needed) |
| Settings and About | Sits beside the "Everything stays on this phone" line |

The maya still never appears on the map or over a photo, because it would compete with the user's own pictures.
The one exception is the first-run hand-off, where it turns into the position marker and disappears.

### 11.2 How the maya reacts to touch

| Gesture | Reaction | Haptic |
| --- | --- | --- |
| Tap | Hops once and chirps a short speech bubble, picked from a small set of lines for that screen | `lightImpact` |
| Several taps in a row | Gets dizzy, wobbles, then shakes it off | `lightImpact` on the last tap |
| Long press | Puffs up its feathers like being petted, and settles when released | `selectionClick` on start |
| Drag | Can be nudged a little, then springs back to its perch | none |
| Tilt the phone (only on first run, optional) | Leans to keep its balance | none |

### 11.3 How the maya reacts to the app

The maya only uses information the app already has on the phone, so it works offline and sends nothing anywhere.

- **Time of day:** sleepy with a tiny nightcap after 11 pm local time, stretching in the early morning.
- **Trips:** packs a tiny bag on a trip's start date, and holds a postcard when a trip ends.
- **Search:** looks through binoculars while there are no results.
- **Writing a caption:** taps its foot while the user types, and stops when the field loses focus.
- **New place:** does a small cheer next to the new place stamp.

### 11.4 Rules that keep the maya kind

1. **No guilt and no FOMO.** The maya is never sad, disappointed, or waiting because the user has not opened the app or captured anything. This follows Len's decision 4.
2. **No notifications from the maya.** It only reacts while the app is open.
3. **Never in the way.** The maya never covers a control, never blocks an action, and every action works without touching it.
4. **Short lines.** Speech bubbles are a few words, in the handwritten voice, and disappear on their own after about two seconds.
5. **Rare surprises.** A reaction repeats less often if the user keeps triggering it, so it stays charming.

### 11.5 Accessibility

The maya is announced to screen readers as "Maya, the Warang mascot", with its reactions marked as decorative.
Its speech lines are not announced, because they never carry information the user needs.
With reduced motion on, every reaction becomes a pose change with a short crossfade.
Haptics follow the system setting.

### 11.6 How to build it

Each reaction needs a pose: idle, hop, puff, dizzy, sleepy, packing, postcard, binoculars, foot-tap, and cheer.
The simplest robust approach is to draw the maya as a few layered parts (body, head, eyes, wings, camera, props) and animate them with Flutter transforms and springs.
That needs new artwork but no new dependency.
A tool such as Rive would make richer, state-driven animation easier, but it adds a dependency and a separate design tool, so it needs Len's approval first.
The current `design/warang-maya.png` is a single flat image, so new layered artwork is required either way.

## Sources

- [Google Design, "Better, Easier, Emotional UX" (Material 3 Expressive research)](https://design.google/library/expressive-material-design-google-research)
- [Kim, Wolfe, Chordia, Davis, Hiniker, "Sharing, Not Showing Off", PACM HCI CSCW 2024](https://arxiv.org/html/2408.02883v1)
- [TechCrunch, "Locket's social app is picking up steam with Gen Alpha", 3 Nov 2025](https://techcrunch.com/2025/11/03/lockets-social-app-is-picking-up-steam-with-gen-alpha)
- [TechCrunch, "The next big social platform is the smartphone's homescreen", 16 Jun 2022](https://techcrunch.com/2022/06/16/the-next-big-social-platform-isthe-smartphones-homescreen)
- [Pinterest Predicts 2026](https://newsroom.pinterest.com/news/pinterest-predicts-nonconformity-self-preservation-and-escapism-drive-21-trends-for-2026/)
- [Google Fonts: Bagel Fat One](https://fonts.google.com/specimen/Bagel+Fat+One), [Atkinson Hyperlegible Next](https://fonts.google.com/specimen/Atkinson+Hyperlegible+Next), [Shantell Sans](https://fonts.google.com/specimen/Shantell+Sans)
- [Pinterest Predicts 2025](https://newsroom.pinterest.com/en-gb/news/pinterest-predicts-20-bold-trends-for-2025/)
- [Nielsen Norman Group, "Designing for Young Adults (Ages 18-25)", 2016](https://www.nngroup.com/articles/young-adults-ux/)
- [Smashing Magazine, "Designing For Gen Z", 2024](https://www.smashingmagazine.com/2024/10/designing-for-gen-z/)
- [Smashing Magazine, "Claymorphism: Will It Stick Around?", 2022](https://www.smashingmagazine.com/2022/03/claymorphism-css-ui-design-trend/)
- [Axess Lab, "Neumorphism - the accessible and inclusive way"](https://axesslab.com/neumorphism/)
- [BOIA, "How Soft User Interface Designs Impact Accessibility", 2023](https://www.boia.org/blog/how-soft-user-interface-designs-impact-accessibility)
- [Aufait UX, "Tactile Maximalism" (opinion, weak data)](https://www.aufaitux.com/blog/tactile-maximalism-gen-z-ui/)
