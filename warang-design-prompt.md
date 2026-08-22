# Warang — Claude Design prompt

Paste the block below into Claude Design.

**Accent locked:** amber `#E8A020`, with dark `#231F0E` for anything sitting
on top of it.

**Deferred to a second pass:** trip detail, share preview.
**Deliberately absent:** a login screen — Warang has no backend, no accounts,
and nothing to authenticate against. First run replaces it.

---

```
Design a mobile app UI canvas for WARANG — an offline-first travel app
for the Philippines. Aklanon for "to go out and explore."

WHAT IT IS
A map you fill with your own photographs. You're somewhere — a cafe, a
trail, a beach — you hit one button, the camera opens, you shoot, and a
photo-pin drops where you stood. Later you look back at a map covered in
your own pictures. Fully offline: no accounts, no cloud, no feed, no
server. Sharing happens by exporting images to Instagram or handing a
file to a friend.

ARTBOARDS: 8 phone screens, 390×844 each, laid out in a row.

DESIGN SYSTEM

Light theme:
  ground  #ECEDE8   surface #F7F8F3   line #D2D5CB
  ink     #1A1D18   soft    #5C6157   faint #8A8F83
Dark theme (re-picked, not inverted):
  ground  #121410   surface #1B1E18   line #2E332A
  ink     #E9EBE3   soft    #A0A697   faint #767C6D

Accent — ONE colour, used sparingly: #E8A020 (amber). Text and icons
sitting ON the accent are DARK (#231F0E), never white — amber is too
light to carry white text legibly.

Map palette, light: land #E6E7E0, land-alt #DCDED4, water #CBD8DA,
roads #F6F7F2. Map palette, dark: land #1A1D18, land-alt #22261F,
water #141B1E, roads #2C3129.

Type: "Bricolage Grotesque" for headings (700–800, tight tracking),
"Public Sans" for body, "DM Mono" for dates, coordinates and counts.

Corner radius 14px for cards and sheets, fully round for pins and the
capture button.

THE THREE RULES — apply to every screen
1. The user's photos are the ONLY saturated thing on screen. All chrome
   is sage-grey. Never put colour near a photograph.
2. The accent appears about four times per screen maximum: the capture
   button, cluster pins, the position marker, and one primary action.
   Nothing else.
3. Nothing slows down a capture. No dialogs, no required fields, no
   trip picker between the button and the shutter.

MASCOT
A "maya" — the small brown Filipino sparrow. Chestnut body, cream belly,
dark cap, stubby beak. It appears ONLY on first run, empty states, and
the app icon. It never appears on a map that has photos on it, and never
over a user's photograph. The position marker is NOT the bird — it's a
small accent dot with a soft halo and a heading cone.

THE SCREENS

1. FIRST RUN — light. The maya, large and friendly. "Warang" in the
   display face. One line: "A map you fill with your own photographs."
   A single text field, "What should we call you?" (stored on the phone
   only). A primary accent button, "Start". Below it, small grey text
   explaining in plain language why the app will ask for camera and
   location — and stating clearly that nothing leaves the phone.

2. MAP HOME, EMPTY — light. Full-bleed stylized map, no satellite
   imagery: soft land shapes, water, thin road lines, very few labels.
   Centred on a Philippine city. The accent position dot in the middle.
   No pins at all. The big round accent capture button at bottom centre.
   A quiet one-line prompt above it: "Capture your first moment." A
   bottom-sheet handle peeking from the bottom edge.

3. MAP HOME, FILLED — light. Same map, now scattered with circular
   photo-pins: each is a small round crop of a photo with a thin
   surface-coloured ring and a tiny pointer beneath. Five or six pins.
   One is a CLUSTER pin — solid amber with a DARK number "12" — for a
   spot visited many times. Position dot. Capture button. Sheet handle.
   This is the hero screen; make it the most finished.

4. MAP HOME, DARK — identical composition to #3 using the dark map
   palette. The point is that photo-pins glow like little lit windows
   against dark land. Prove the theme works, don't just invert it.

5. CAPTURE — SAVE MOMENT — the screen immediately after the shutter.
   The photo fills most of the screen. Beneath it: an optional caption
   field with placeholder "Say something (optional)", and auto-filled
   place and time as quiet mono text — "MALAY, AKLAN · 4:42 PM". One
   accent "Save" button. Make it obvious that saving takes one tap and
   the caption can be skipped.

6. MOMENT CARD OPEN — the filled map, slightly dimmed, with a card
   risen over the lower half: the photo, a caption, place and date in
   mono, and small quiet icon actions (share, edit, delete). Small dots
   indicating you can swipe sideways through nearby memories. The map
   is still visible behind — you never leave it.

7. TRIPS SHEET EXPANDED — the bottom sheet dragged to full height over
   a dimmed map. At the top, a pinned row: "Everyday", where casual
   captures live. Below it, real trips as wide cards — cover photo,
   title in the display face, date range and moment count in mono.
   Examples: "Bohol Summer 2025 · Mar 12–19 · 24 moments",
   "Sagada 2024 · Nov 2–6 · 31 moments".

8. SETTINGS — light. Grouped sections, calm and plain:
   • You — name, avatar
   • Storage — how much space photos use, "Back up everything"
   • Map — theme follows your phone, downloaded regions
   • Sharing — caption copied on share, corner mark on images
   • About — version, the meaning of the word "warang"
   There is deliberately NO account section, NO sync, NO sign-out.
   If anything, say plainly somewhere: "Everything stays on this phone."

TONE
Plain English. Warm but not cute. Controls say exactly what happens.
Avoid travel-app clichés: no teal-and-coral, no gradient heroes, no
passport stamps, no dotted flight paths.
```
