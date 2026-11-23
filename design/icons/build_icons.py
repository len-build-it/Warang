"""Design-time builder for the Warang clay icon set (FEAT-003 V7).

Run from the repository root:

    python design/icons/build_icons.py svg
    cd design/icons
    npx --yes --node-options="--require=./posix-glob-shim.cjs" fantasticon@3.0.0 --config fantasticon.json
    cd ../..
    python design/icons/build_icons.py dart

The first step writes, for every glyph:
  design/icons/<name>.svg             readable source: 2.5 px round stroke
                                      plus a separate duotone fill layer
  design/icons/glyphs/<name>.svg      the stroke layer as filled outlines
  design/icons/glyphs/<name>-fill.svg the fill layer as filled outlines

Icon fonts cannot hold strokes, so this script turns each stroke into
filled outlines with consistent winding; overlapping contours then union
under the non-zero fill rule. The second step (fantasticon, run through npx
and never added to the app) packs the outlined glyphs into
design/icons/build/WarangIcons.ttf, which is copied to
assets/fonts/WarangIcons.ttf. The shim only fixes fantasticon's glob on
Windows. The third step writes
lib/app/theme/warang_icons.dart from the fixed code points below.

Only the Python standard library is used.
"""

import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
GLYPHS = os.path.join(HERE, "glyphs")
STROKE = 2.5
HALF = STROKE / 2
CAP_STEPS = 10
CURVE_STEPS = 16
FIRST_CODEPOINT = 0xE001


# ---------------------------------------------------------------- primitives
# Stroke-layer primitives describe centre lines drawn with a 2.5 px round
# stroke; "solid" primitives are filled shapes in the stroke layer; fill-layer
# primitives are the soft duotone shapes behind the stroke.


def line(x1, y1, x2, y2):
    return ("line", [(x1, y1), (x2, y2)])


def poly(*points, closed=False):
    return ("poly", list(points), closed)


def circle(cx, cy, r):
    return ("circle", (cx, cy), r)


def rrect(x, y, w, h, r):
    return ("rrect", (x, y, w, h), r)


def arc(cx, cy, r, a0, a1):
    return ("arc", (cx, cy), r, a0, a1)


def quad(p0, c, p1):
    return ("quad", p0, c, p1)


def dot(cx, cy, r):
    return ("dot", (cx, cy), r)


def solid(*points):
    return ("solid", list(points))


def area(outer, *holes):
    """A filled shape exactly as drawn, with no stroke around it."""
    return ("area", list(outer), [list(hole) for hole in holes])


def half_disc(cx, cy, r, side):
    return ("half", (cx, cy), r, side)


def teardrop(cx, cy, r, tip_y):
    return ("teardrop", (cx, cy), r, tip_y)


# ---------------------------------------------------------------- the glyphs


def _arrow_head(cx, cy, r, angle, toward):
    """Two short strokes forming an arrow head at `angle` on a circle."""
    a = math.radians(angle)
    px, py = cx + r * math.cos(a), cy + r * math.sin(a)
    # Tangent direction of travel (toward=+1 for increasing angle).
    tx, ty = -math.sin(a) * toward, math.cos(a) * toward
    shapes = []
    for turn in (math.radians(145), math.radians(-145)):
        dx = tx * math.cos(turn) - ty * math.sin(turn)
        dy = tx * math.sin(turn) + ty * math.cos(turn)
        shapes.append(line(px, py, px + 4.2 * dx, py + 4.2 * dy))
    return shapes


ICONS = {
    # name: (stroke layer, fill layer)
    "map": (
        [
            poly((3, 6), (9, 4), (15, 6), (21, 4), (21, 18), (15, 20),
                 (9, 18), (3, 20), closed=True),
            line(9, 4, 9, 18),
            line(15, 6, 15, 20),
        ],
        [poly((3, 6), (9, 4), (15, 6), (21, 4), (21, 18), (15, 20),
              (9, 18), (3, 20), closed=True)],
    ),
    "trips": (
        [
            # An upright case: tall handle, wheels, and a tilted sticker.
            # A wide body with a round sticker read as a camera.
            rrect(5.5, 7.5, 13, 12.5, 2.5),
            poly((9.25, 7.5), (9.25, 2.75), (14.75, 2.75), (14.75, 7.5)),
            dot(8.5, 22, 1.5),
            dot(15.5, 22, 1.5),
            area([(10.4, 10.2), (15.9, 11.7), (14.4, 17.2), (8.9, 15.7)]),
        ],
        [rrect(5.5, 7.5, 13, 12.5, 2.5)],
    ),
    "news": (
        [
            rrect(2.5, 5, 19, 14, 2.5),
            rrect(14, 8, 4.5, 4.5, 1),
            line(6, 10, 10.5, 10),
            line(6, 14, 12.5, 14),
        ],
        [rrect(2.5, 5, 19, 14, 2.5)],
    ),
    "search": (
        [circle(10.5, 10.5, 6.5), line(15.6, 15.6, 20.5, 20.5)],
        [circle(10.5, 10.5, 6.5)],
    ),
    "searchEmpty": (
        [
            circle(10.5, 10.5, 6.5),
            line(15.6, 15.6, 20.5, 20.5),
            quad((8.2, 12.8), (8.6, 8.6), (12.8, 8.2)),
            line(8.2, 12.8, 10.2, 10.8),
        ],
        [circle(10.5, 10.5, 6.5)],
    ),
    "capture": (
        [circle(12, 12, 8)],
        [circle(12, 12, 8)],
    ),
    "recenter": (
        [
            # An upright needle, solid to the north and open to the south,
            # under an N tick. A diagonal needle read as "no entry".
            circle(12, 13, 8.5),
            line(12, 1.75, 12, 4.5),
            area([(12, 7), (15.6, 13), (8.4, 13)]),
            area([(15.6, 13), (12, 19), (8.4, 13)],
                 [(13.8, 13.8), (12, 16.8), (10.2, 13.8)]),
        ],
        [circle(12, 13, 8.5)],
    ),
    "back": (
        [line(19, 12, 5.5, 12), poly((11, 6.5), (5.5, 12), (11, 17.5))],
        [],
    ),
    "close": (
        [line(6.5, 6.5, 17.5, 17.5), line(17.5, 6.5, 6.5, 17.5)],
        [],
    ),
    "edit": (
        [
            poly((4, 20), (5.2, 15.3), (15.3, 5.2), (18.8, 8.7), (8.7, 18.8),
                 closed=True),
            line(13.1, 7.4, 16.6, 10.9),
        ],
        [poly((4, 20), (5.2, 15.3), (15.3, 5.2), (18.8, 8.7), (8.7, 18.8),
              closed=True)],
    ),
    "delete": (
        [
            line(4, 6.75, 20, 6.75),
            line(10, 3.5, 14, 3.5),
            poly((6, 6.5), (7, 20), (17, 20), (18, 6.5)),
            line(10, 10.5, 10, 16.5),
            line(14, 10.5, 14, 16.5),
        ],
        [poly((6, 6.5), (7, 20), (17, 20), (18, 6.5), closed=True)],
    ),
    "pin": (
        [teardrop(12, 10, 6.5, 21), dot(12, 10, 2.2)],
        [teardrop(12, 10, 6.5, 21)],
    ),
    "photo": (
        [rrect(4, 3, 16, 18, 2), rrect(7, 6, 10, 9, 1)],
        [rrect(7, 6, 10, 9, 1)],
    ),
    "calendar": (
        [
            rrect(3.5, 5, 17, 15, 3),
            line(8, 3, 8, 7),
            line(16, 3, 16, 7),
            line(3.5, 10, 20.5, 10),
            dot(8.5, 14.75, 1.6),
        ],
        [rrect(3.5, 5, 17, 15, 3)],
    ),
    "settings": (
        [circle(12, 12, 8), line(12, 12, 15.3, 8.7), dot(12, 12, 2)],
        [circle(12, 12, 8)],
    ),
    "theme": (
        [circle(12, 12, 8), half_disc(12, 12, 8, "left")],
        [half_disc(12, 12, 8, "right")],
    ),
    "info": (
        [
            rrect(3, 4, 18, 13, 4),
            poly((8, 17), (7, 21), (12.5, 17)),
            dot(12, 8, 1.5),
            line(12, 11, 12, 14),
        ],
        [rrect(3, 4, 18, 13, 4)],
    ),
    "refresh": (
        [arc(12, 12, 7.5, 40, 320)] + _arrow_head(12, 12, 7.5, 320, 1),
        [],
    ),
    "chevron": (
        [poly((9.5, 5.5), (16, 12), (9.5, 18.5))],
        [],
    ),
    "more": (
        [dot(6, 12, 2), dot(12, 12, 2), dot(18, 12, 2)],
        [],
    ),
    "explore": (
        [
            rrect(4.5, 4.5, 5, 7, 2),
            rrect(14.5, 4.5, 5, 7, 2),
            circle(7, 15.5, 3.8),
            circle(17, 15.5, 3.8),
            line(10.8, 14, 13.2, 14),
        ],
        [circle(7, 15.5, 3.8), circle(17, 15.5, 3.8)],
    ),
    # Not in the V7 table: C7 chips and the C11 toggle show a check mark.
    "check": (
        [poly((5, 12.5), (10, 17.5), (19, 7))],
        [],
    ),
    # FEAT-004 D-4 place category glyphs (14 categories).
    "catCafe": (
        [
            rrect(4, 8, 12, 10, 3),
            arc(16, 12.5, 3, -90, 90),
            line(5, 20.5, 17, 20.5),
            quad((8, 5.5), (9, 4), (8.5, 2.8)),
            quad((12, 5.5), (13, 4), (12.5, 2.8)),
        ],
        [rrect(4, 8, 12, 10, 3)],
    ),
    "catFood": (
        [
            line(7, 4, 7, 20),
            line(4.8, 4, 4.8, 9),
            line(9.2, 4, 9.2, 9),
            line(4.8, 9, 9.2, 9),
            line(16.5, 11, 16.5, 20),
            rrect(13.8, 4, 5.4, 7, 2.7),
        ],
        [rrect(13.8, 4, 5.4, 7, 2.7)],
    ),
    "catSweets": (
        [
            poly((6, 12.5), (7.5, 19.5), (16.5, 19.5), (18, 12.5), closed=True),
            arc(12, 12, 6, 180, 360),
            dot(12, 4.5, 1.5),
        ],
        [poly((6, 12.5), (7.5, 19.5), (16.5, 19.5), (18, 12.5), closed=True)],
    ),
    "catNightlife": (
        [
            poly((5, 5), (19, 5), (12, 13), closed=True),
            line(12, 13, 12, 20),
            line(8, 20, 16, 20),
            dot(14.5, 8, 1.2),
        ],
        [poly((6.5, 6), (17.5, 6), (12, 12.2), closed=True)],
    ),
    "catBeach": (
        [
            arc(12, 11, 7.5, 180, 360),
            line(4.5, 11, 19.5, 11),
            line(12, 11, 12, 18),
            quad((4, 19.5), (8, 17.5), (12, 19.5)),
            quad((12, 19.5), (16, 21.5), (20, 19.5)),
        ],
        [half_disc(12, 11, 7.5, "top")],
    ),
    "catIsland": (
        [
            arc(12, 19.5, 7.5, 185, 355),
            line(4.5, 19.5, 19.5, 19.5),
            quad((12, 14), (11, 10), (12.5, 7)),
            quad((12.5, 7), (9, 5.5), (6.5, 8.5)),
            quad((12.5, 7), (16, 5.5), (18.5, 8.5)),
            quad((12.5, 7), (12.5, 4.5), (15.5, 4.5)),
        ],
        [half_disc(12, 19.5, 7.5, "top")],
    ),
    "catNature": (
        [
            poly((3, 19), (9.5, 7), (15, 19), closed=True),
            poly((11.5, 19), (16, 10.5), (21, 19), closed=True),
            dot(17.5, 5.5, 1.8),
        ],
        [poly((3, 19), (9.5, 7), (15, 19), closed=True)],
    ),
    "catPark": (
        [
            circle(12, 9.5, 5.2),
            line(12, 14.5, 12, 20),
            line(5, 20, 19, 20),
        ],
        [circle(12, 9.5, 5.2)],
    ),
    "catChurch": (
        [
            poly((5, 11.5), (12, 6), (19, 11.5), (19, 20), (5, 20), closed=True),
            line(12, 2.8, 12, 6.2),
            line(10, 4.2, 14, 4.2),
            rrect(10, 14.5, 4, 5.5, 1.8),
        ],
        [poly((5, 11.5), (12, 6), (19, 11.5), (19, 20), (5, 20), closed=True)],
    ),
    "catHeritage": (
        [
            poly((4, 9), (12, 4.5), (20, 9), closed=True),
            line(6.5, 9.5, 6.5, 18),
            line(12, 9.5, 12, 18),
            line(17.5, 9.5, 17.5, 18),
            line(4, 19.5, 20, 19.5),
        ],
        [poly((4, 9), (12, 4.5), (20, 9), closed=True)],
    ),
    "catMarket": (
        [
            rrect(5, 8.5, 14, 11.5, 2.5),
            arc(12, 8.5, 3.5, 180, 360),
            line(5, 13, 19, 13),
        ],
        [rrect(5, 8.5, 14, 11.5, 2.5)],
    ),
    "catStay": (
        [
            line(4, 7, 4, 19),
            line(4, 15.5, 20, 15.5),
            line(20, 11.5, 20, 19),
            rrect(10, 10.5, 10, 5, 2),
            circle(7.2, 11.5, 1.7),
        ],
        [rrect(10, 10.5, 10, 5, 2)],
    ),
    "catTransit": (
        [
            rrect(5, 5, 14, 12.5, 3),
            line(5, 12, 19, 12),
            dot(8.5, 14.8, 1.1),
            dot(15.5, 14.8, 1.1),
            line(7.5, 17.5, 7.5, 20),
            line(16.5, 17.5, 16.5, 20),
        ],
        [rrect(5, 5, 14, 7, 2.5)],
    ),
    "catTown": (
        [
            rrect(4, 9, 7.5, 11, 1.5),
            rrect(11.5, 5, 8.5, 15, 1.5),
            dot(7.8, 13, 1.0),
            dot(15.8, 9.5, 1.0),
            dot(15.8, 14, 1.0),
        ],
        [rrect(11.5, 5, 8.5, 15, 1.5)],
    ),
}

# Fixed code points so the font never reshuffles between builds.
ORDER = list(ICONS)


def codepoints():
    points = {}
    for index, name in enumerate(ORDER):
        points[name] = FIRST_CODEPOINT + index * 2
        if ICONS[name][1]:
            points[name + "-fill"] = FIRST_CODEPOINT + index * 2 + 1
    return points


# ---------------------------------------------------------------- geometry


def _area(points):
    total = 0.0
    for i, (x1, y1) in enumerate(points):
        x2, y2 = points[(i + 1) % len(points)]
        total += x1 * y2 - x2 * y1
    return total / 2


def _orient(points, positive=True):
    area = _area(points)
    if (area > 0) != positive:
        points = list(reversed(points))
    return points


def _circle_points(cx, cy, r, steps=48):
    return [
        (cx + r * math.cos(2 * math.pi * i / steps),
         cy + r * math.sin(2 * math.pi * i / steps))
        for i in range(steps)
    ]


def _capsule(p1, p2, hw=HALF):
    (x1, y1), (x2, y2) = p1, p2
    length = math.hypot(x2 - x1, y2 - y1)
    if length < 1e-9:
        return _circle_points(x1, y1, hw, 24)
    nx, ny = -(y2 - y1) / length, (x2 - x1) / length
    theta = math.atan2(ny, nx)
    points = []
    for i in range(CAP_STEPS + 1):
        a = theta - math.pi * i / CAP_STEPS
        points.append((x2 + hw * math.cos(a), y2 + hw * math.sin(a)))
    for i in range(CAP_STEPS + 1):
        a = theta - math.pi - math.pi * i / CAP_STEPS
        points.append((x1 + hw * math.cos(a), y1 + hw * math.sin(a)))
    return points


def _rrect_points(x, y, w, h, r, steps=8):
    r = max(0.0, min(r, w / 2, h / 2))
    corners = [
        (x + w - r, y + r, -90),
        (x + w - r, y + h - r, 0),
        (x + r, y + h - r, 90),
        (x + r, y + r, 180),
    ]
    points = []
    for cx, cy, start in corners:
        if r == 0:
            points.append((cx, cy))
            continue
        for i in range(steps + 1):
            a = math.radians(start + 90 * i / steps)
            points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return points


def _teardrop_points(cx, cy, r, tip_y, steps=48):
    distance = tip_y - cy
    half_angle = math.acos(r / distance)
    # Tangent points sit at angle pi/2 +- (pi/2 - half_angle) from +x, y-down.
    start = math.pi / 2 + half_angle
    end = math.pi / 2 - half_angle + 2 * math.pi
    points = [(cx, tip_y)]
    for i in range(steps + 1):
        a = start + (end - start) * i / steps
        points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return points


def _quad_points(p0, c, p1):
    points = []
    for i in range(CURVE_STEPS + 1):
        t = i / CURVE_STEPS
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]
        points.append((x, y))
    return points


def _polyline_capsules(points, closed=False):
    contours = []
    pairs = list(zip(points, points[1:]))
    if closed:
        pairs.append((points[-1], points[0]))
    for p1, p2 in pairs:
        contours.append(_orient(_capsule(p1, p2)))
    return contours


def stroke_outline(shape):
    """Filled contours that cover a stroke-layer primitive."""
    kind = shape[0]
    if kind == "line":
        return [_orient(_capsule(*shape[1]))]
    if kind == "poly":
        return _polyline_capsules(shape[1], shape[2])
    if kind == "quad":
        return _polyline_capsules(_quad_points(shape[1], shape[2], shape[3]))
    if kind == "circle":
        (cx, cy), r = shape[1], shape[2]
        return [
            _orient(_circle_points(cx, cy, r + HALF)),
            _orient(_circle_points(cx, cy, r - HALF), positive=False),
        ]
    if kind == "rrect":
        (x, y, w, h), r = shape[1], shape[2]
        return [
            _orient(_rrect_points(x - HALF, y - HALF, w + STROKE, h + STROKE,
                                  r + HALF)),
            _orient(_rrect_points(x + HALF, y + HALF, w - STROKE, h - STROKE,
                                  max(r - HALF, 0)), positive=False),
        ]
    if kind == "arc":
        (cx, cy), r, a0, a1 = shape[1:]
        steps = 48
        outer = []
        inner = []
        for i in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * i / steps)
            outer.append((cx + (r + HALF) * math.cos(a),
                          cy + (r + HALF) * math.sin(a)))
            inner.append((cx + (r - HALF) * math.cos(a),
                          cy + (r - HALF) * math.sin(a)))
        ends = []
        for a in (a0, a1):
            a = math.radians(a)
            ends.append(_orient(_circle_points(cx + r * math.cos(a),
                                               cy + r * math.sin(a), HALF,
                                               24)))
        return [_orient(outer + list(reversed(inner)))] + ends
    if kind == "dot":
        (cx, cy), r = shape[1], shape[2]
        return [_orient(_circle_points(cx, cy, r, 32))]
    if kind == "solid":
        return [_orient(shape[1])] + _polyline_capsules(shape[1], True)
    if kind == "area":
        return [_orient(shape[1])] + [
            _orient(hole, positive=False) for hole in shape[2]]
    if kind == "teardrop":
        (cx, cy), r, tip_y = shape[1:]
        return _polyline_capsules(_teardrop_points(cx, cy, r, tip_y), True)
    if kind == "half":
        return fill_outline(shape)
    raise ValueError(kind)


def fill_outline(shape):
    """Filled contours for a fill-layer primitive (the area it encloses)."""
    kind = shape[0]
    if kind == "poly":
        return [_orient(shape[1])]
    if kind == "circle":
        (cx, cy), r = shape[1], shape[2]
        return [_orient(_circle_points(cx, cy, r))]
    if kind == "rrect":
        (x, y, w, h), r = shape[1], shape[2]
        return [_orient(_rrect_points(x, y, w, h, r))]
    if kind == "half":
        (cx, cy), r, side = shape[1:]
        start = 90 if side == "left" else -90
        points = []
        for i in range(25):
            a = math.radians(start + 180 * i / 24)
            points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        return [_orient(points)]
    if kind == "teardrop":
        (cx, cy), r, tip_y = shape[1:]
        return [_orient(_teardrop_points(cx, cy, r, tip_y))]
    raise ValueError(kind)


# ---------------------------------------------------------------- SVG output


def _fmt(value):
    text = f"{value:.3f}".rstrip("0").rstrip(".")
    return "0" if text == "-0" else text


def _path_data(contours):
    parts = []
    for contour in contours:
        head, *rest = contour
        parts.append("M" + _fmt(head[0]) + " " + _fmt(head[1]))
        parts.extend("L" + _fmt(x) + " " + _fmt(y) for x, y in rest)
        parts.append("Z")
    return "".join(parts)


def _svg(body):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
        'viewBox="0 0 24 24">\n' + body + "</svg>\n"
    )


def _source_element(shape, layer):
    kind = shape[0]
    if kind == "line":
        (x1, y1), (x2, y2) = shape[1]
        return (f'<line x1="{_fmt(x1)}" y1="{_fmt(y1)}" x2="{_fmt(x2)}" '
                f'y2="{_fmt(y2)}"/>')
    if kind == "poly":
        points = " ".join(f"{_fmt(x)},{_fmt(y)}" for x, y in shape[1])
        tag = "polygon" if shape[2] or layer == "fill" else "polyline"
        return f'<{tag} points="{points}"/>'
    if kind == "circle":
        (cx, cy), r = shape[1], shape[2]
        return f'<circle cx="{_fmt(cx)}" cy="{_fmt(cy)}" r="{_fmt(r)}"/>'
    if kind == "rrect":
        (x, y, w, h), r = shape[1], shape[2]
        return (f'<rect x="{_fmt(x)}" y="{_fmt(y)}" width="{_fmt(w)}" '
                f'height="{_fmt(h)}" rx="{_fmt(r)}"/>')
    if kind == "quad":
        p0, c, p1 = shape[1:]
        return (f'<path d="M{_fmt(p0[0])} {_fmt(p0[1])}Q{_fmt(c[0])} '
                f'{_fmt(c[1])} {_fmt(p1[0])} {_fmt(p1[1])}"/>')
    if kind == "arc":
        (cx, cy), r, a0, a1 = shape[1:]
        x0 = cx + r * math.cos(math.radians(a0))
        y0 = cy + r * math.sin(math.radians(a0))
        x1 = cx + r * math.cos(math.radians(a1))
        y1 = cy + r * math.sin(math.radians(a1))
        large = 1 if abs(a1 - a0) > 180 else 0
        sweep = 1 if a1 > a0 else 0
        return (f'<path d="M{_fmt(x0)} {_fmt(y0)}A{_fmt(r)} {_fmt(r)} 0 '
                f'{large} {sweep} {_fmt(x1)} {_fmt(y1)}"/>')
    if kind == "teardrop" and layer == "stroke":
        (cx, cy), r, tip_y = shape[1:]
        points = " ".join(f"{_fmt(x)},{_fmt(y)}"
                          for x, y in _teardrop_points(cx, cy, r, tip_y, 24))
        return f'<polygon points="{points}"/>'
    # Dots, solid shapes, and fill-layer areas are drawn as filled paths.
    if kind in ("dot", "area"):
        contours = stroke_outline(shape)
    elif kind == "solid":
        contours = [_orient(shape[1])]
    else:
        contours = fill_outline(shape)
    paint = "currentColor" if layer == "stroke" else "#E2DFD4"
    return (f'<path d="{_path_data(contours)}" fill="{paint}" '
            'stroke="none"/>')


def write_svgs():
    os.makedirs(GLYPHS, exist_ok=True)
    for old in os.listdir(GLYPHS):
        if old.endswith(".svg"):
            os.remove(os.path.join(GLYPHS, old))
    for name, (strokes, fills) in ICONS.items():
        body = ""
        if fills:
            body += '  <g id="fill" fill="#E2DFD4" stroke="none">\n'
            body += "".join(
                "    " + _source_element(s, "fill") + "\n" for s in fills)
            body += "  </g>\n"
        body += ('  <g id="stroke" fill="none" stroke="#4F544A" '
                 f'stroke-width="{_fmt(STROKE)}" stroke-linecap="round" '
                 'stroke-linejoin="round">\n')
        body += "".join(
            "    " + _source_element(s, "stroke") + "\n" for s in strokes)
        body += "  </g>\n"
        with open(os.path.join(HERE, name + ".svg"), "w",
                  encoding="utf-8") as out:
            out.write(_svg(body))

        stroke_contours = [c for s in strokes for c in stroke_outline(s)]
        with open(os.path.join(GLYPHS, name + ".svg"), "w",
                  encoding="utf-8") as out:
            out.write(_svg(f'  <path d="{_path_data(stroke_contours)}"/>\n'))
        if fills:
            fill_contours = [c for s in fills for c in fill_outline(s)]
            with open(os.path.join(GLYPHS, name + "-fill.svg"), "w",
                      encoding="utf-8") as out:
                out.write(_svg(f'  <path d="{_path_data(fill_contours)}"/>\n'))
    with open(os.path.join(HERE, "codepoints.json"), "w",
              encoding="utf-8") as out:
        json.dump(codepoints(), out, indent=2)
        out.write("\n")


def _camel(name):
    return name[0].lower() + name[1:]


def write_dart():
    points = codepoints()
    lines = [
        "// GENERATED FILE - do not edit by hand.",
        "// Built by design/icons/build_icons.py from design/icons/*.svg.",
        "",
        "import 'package:flutter/widgets.dart';",
        "",
        "/// The Warang clay icon set (FEAT-003 V7), one stroke glyph per icon",
        "/// and an optional duotone fill glyph drawn underneath it.",
        "@immutable",
        "class WarangGlyph {",
        "  const WarangGlyph(this.stroke, [this.fill]);",
        "",
        "  /// The outlined 2.5 px stroke layer.",
        "  final IconData stroke;",
        "",
        "  /// The soft fill layer, or null when the icon has none.",
        "  final IconData? fill;",
        "}",
        "",
        "abstract final class WarangGlyphs {",
        "  static const fontFamily = 'WarangIcons';",
        "",
    ]
    for name in ORDER:
        stroke = points[name]
        fill = points.get(name + "-fill")
        fill_arg = (f", IconData(0x{fill:X}, fontFamily: fontFamily)"
                    if fill else "")
        lines.append(
            f"  static const {_camel(name)} = WarangGlyph("
            f"IconData(0x{stroke:X}, fontFamily: fontFamily){fill_arg});")
    lines += [
        "",
        "  static const all = <String, WarangGlyph>{",
    ]
    lines += [f"    '{name}': {_camel(name)}," for name in ORDER]
    lines += ["  };", "}", ""]
    path = os.path.join(ROOT, "lib", "app", "theme", "warang_icons.dart")
    with open(path, "w", encoding="utf-8", newline="\n") as out:
        out.write("\n".join(lines))
    subprocess.run(["dart", "format", path], check=True, shell=os.name == "nt")


if __name__ == "__main__":
    step = sys.argv[1] if len(sys.argv) > 1 else "svg"
    if step == "svg":
        write_svgs()
    elif step == "dart":
        write_dart()
    else:
        raise SystemExit(f"unknown step {step!r}")
