#!/usr/bin/env python3
"""Build Warang's bundled offline Philippine place book from an OSM PBF extract."""

from __future__ import annotations

import argparse
import datetime
import json
import math
import os
import pathlib
import sqlite3
import sys
from collections import defaultdict
from typing import Dict, List, Optional, Sequence, Tuple

import osmium

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
SCHEMA_PATH = SCRIPT_DIR / "schema.sql"
CATEGORIES_PATH = SCRIPT_DIR / "categories.json"
GRID_STEP = 0.2


def load_rules(path: pathlib.Path) -> List[dict]:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def match_category(
    tags: osmium.osm.TagList,
    rules: Sequence[dict],
    *,
    drop_village_suburb: bool = False,
    strict_food: bool = False,
) -> Optional[str]:
    for rule in rules:
        key = rule["key"]
        raw = tags.get(key)
        if not raw:
            continue
        raw = raw.strip()
        if not raw:
            continue
        values = rule["values"]
        matched = False
        if values == ["*"]:
            matched = raw.lower() != "no"
        else:
            parts = [part.strip() for part in raw.split(";")]
            matched = any(part in values for part in parts)
        if not matched:
            continue
        category = rule["category"]
        if drop_village_suburb and category == "town" and key == "place":
            if raw in ("village", "suburb"):
                return None
        if strict_food and category == "food":
            has_extra = any(
                tags.get(k)
                for k in ("website", "opening_hours", "wikidata")
            ) or any(t.k.startswith("addr:") and t.v for t in tags)
            if not has_extra:
                return None
        return category
    return None


def extract_alt_names(tags: osmium.osm.TagList, primary_name: str) -> str:
    seen = {primary_name.strip().lower()}
    alts: List[str] = []
    for key in ("name:en", "name:tl", "alt_name", "old_name"):
        raw = tags.get(key)
        if not raw:
            continue
        for part in raw.split(";"):
            cleaned = part.strip()
            if not cleaned:
                continue
            low = cleaned.lower()
            if low not in seen:
                seen.add(low)
                alts.append(cleaned)
    return " | ".join(alts)


def compute_weight(category: str, tags: osmium.osm.TagList) -> int:
    if category == "town":
        place_val = (tags.get("place") or "").strip()
        base = {"city": 30, "town": 20, "suburb": 10, "village": 5}.get(
            place_val, 0
        )
        pop_raw = tags.get("population")
        if pop_raw:
            digits = "".join(ch for ch in pop_raw if ch.isdigit())
            if digits:
                pop = int(digits)
                if pop > 0:
                    base += min(10, int(math.log10(pop) * 2))
        return base
    if category == "transit":
        if tags.get("aeroway") == "aerodrome":
            return 15
        return 8
    if category in ("beach", "island", "heritage", "market"):
        return 5
    return 0


def ring_to_coords(ring) -> List[Tuple[float, float]]:
    coords: List[Tuple[float, float]] = []
    for node in ring:
        if node.location.valid():
            coords.append((node.location.lon, node.location.lat))
    return coords


def point_in_ring(lon: float, lat: float, ring: Sequence[Tuple[float, float]]) -> bool:
    inside = False
    n = len(ring)
    if n < 3:
        return False
    x1, y1 = ring[0]
    for i in range(1, n + 1):
        x2, y2 = ring[i % n]
        if (y1 > lat) != (y2 > lat):
            x_intersect = (x2 - x1) * (lat - y1) / (y2 - y1) + x1
            if lon < x_intersect:
                inside = not inside
        x1, y1 = x2, y2
    return inside


def ring_area_abs(ring: Sequence[Tuple[float, float]]) -> float:
    n = len(ring)
    if n < 3:
        return 0.0
    acc = 0.0
    for i in range(n):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % n]
        acc += x1 * y2 - x2 * y1
    return abs(acc) * 0.5


def representative_point(
    outers: Sequence[List[Tuple[float, float]]],
    inners: Sequence[List[Tuple[float, float]]],
) -> Optional[Tuple[float, float]]:
    if not outers:
        return None
    main = max(outers, key=ring_area_abs)
    if len(main) < 3:
        return None
    lons = [p[0] for p in main]
    lats = [p[1] for p in main]
    min_lon, max_lon = min(lons), max(lons)
    min_lat, max_lat = min(lats), max(lats)
    cx = (min_lon + max_lon) * 0.5
    cy = (min_lat + max_lat) * 0.5
    if point_in_ring(cx, cy, main) and not any(
        point_in_ring(cx, cy, hole) for hole in inners
    ):
        return (cy, cx)
    # Horizontal scanline at midpoint latitude to guarantee an interior point.
    xs: List[float] = []
    n = len(main)
    for i in range(n):
        x1, y1 = main[i]
        x2, y2 = main[(i + 1) % n]
        if (y1 > cy) != (y2 > cy):
            xs.append((x2 - x1) * (cy - y1) / (y2 - y1) + x1)
    xs.sort()
    best_x = cx
    best_span = -1.0
    for i in range(0, len(xs) - 1, 2):
        span = xs[i + 1] - xs[i]
        mid_x = (xs[i] + xs[i + 1]) * 0.5
        if span > best_span and not any(
            point_in_ring(mid_x, cy, hole) for hole in inners
        ):
            best_span = span
            best_x = mid_x
    if best_span >= 0.0:
        return (cy, best_x)
    return (cy, cx)


class BoundaryPolygon:
    __slots__ = ("name", "level", "bbox", "outers", "inners", "area")

    def __init__(
        self,
        name: str,
        level: int,
        outers: List[List[Tuple[float, float]]],
        inners: List[List[Tuple[float, float]]],
    ) -> None:
        self.name = name
        self.level = level
        self.outers = outers
        self.inners = inners
        all_pts = [pt for ring in outers for pt in ring]
        self.bbox = (
            min(p[0] for p in all_pts),
            min(p[1] for p in all_pts),
            max(p[0] for p in all_pts),
            max(p[1] for p in all_pts),
        )
        self.area = sum(ring_area_abs(r) for r in outers)

    def contains(self, lon: float, lat: float) -> bool:
        min_lon, min_lat, max_lon, max_lat = self.bbox
        if lon < min_lon or lon > max_lon or lat < min_lat or lat > max_lat:
            return False
        if not any(point_in_ring(lon, lat, ring) for ring in self.outers):
            return False
        if any(point_in_ring(lon, lat, hole) for hole in self.inners):
            return False
        return True


class BoundaryIndex:
    def __init__(self, polygons: Sequence[BoundaryPolygon]) -> None:
        self._grid: Dict[Tuple[int, int], List[BoundaryPolygon]] = defaultdict(list)
        # Prefer smaller polygon first if boundaries overlap slightly.
        ordered = sorted(polygons, key=lambda p: (p.area, p.name))
        for poly in ordered:
            min_lon, min_lat, max_lon, max_lat = poly.bbox
            gx0 = int(math.floor(min_lon / GRID_STEP))
            gx1 = int(math.floor(max_lon / GRID_STEP))
            gy0 = int(math.floor(min_lat / GRID_STEP))
            gy1 = int(math.floor(max_lat / GRID_STEP))
            for gx in range(gx0, gx1 + 1):
                for gy in range(gy0, gy1 + 1):
                    self._grid[(gx, gy)].append(poly)

    def find(self, lon: float, lat: float) -> str:
        cell = (int(math.floor(lon / GRID_STEP)), int(math.floor(lat / GRID_STEP)))
        candidates = self._grid.get(cell)
        if not candidates:
            return ""
        for poly in candidates:
            if poly.contains(lon, lat):
                return poly.name
        return ""


class PlaceCollector(osmium.SimpleHandler):
    def __init__(
        self,
        rules: Sequence[dict],
        *,
        drop_alt_names: bool = False,
        drop_village_suburb: bool = False,
        strict_food: bool = False,
    ) -> None:
        super().__init__()
        self.rules = rules
        self.drop_alt_names = drop_alt_names
        self.drop_village_suburb = drop_village_suburb
        self.strict_food = strict_food
        self.places: Dict[str, Tuple[str, str, str, float, float, int]] = {}
        self.area_way_ids: set[int] = set()
        self.boundaries: Dict[int, List[BoundaryPolygon]] = defaultdict(list)

    def _add_place(
        self,
        osm_ref: str,
        tags: osmium.osm.TagList,
        lat: float,
        lon: float,
    ) -> None:
        name = (tags.get("name") or "").strip()
        if not name:
            return
        category = match_category(
            tags,
            self.rules,
            drop_village_suburb=self.drop_village_suburb,
            strict_food=self.strict_food,
        )
        if not category:
            return
        alt_names = "" if self.drop_alt_names else extract_alt_names(tags, name)
        weight = compute_weight(category, tags)
        self.places[osm_ref] = (
            name,
            alt_names,
            category,
            round(lat, 6),
            round(lon, 6),
            weight,
        )

    def node(self, n: osmium.osm.Node) -> None:
        if not n.location.valid():
            return
        if "name" not in n.tags:
            return
        self._add_place(f"n{n.id}", n.tags, n.location.lat, n.location.lon)

    def area(self, a: osmium.osm.Area) -> None:
        tags = a.tags
        is_admin = (
            tags.get("boundary") == "administrative"
            and tags.get("admin_level") in ("3", "4", "6", "7")
            and bool((tags.get("name") or "").strip())
        )
        has_name = "name" in tags
        if not is_admin and not has_name:
            return

        outers: List[List[Tuple[float, float]]] = []
        inners: List[List[Tuple[float, float]]] = []
        try:
            for outer in a.outer_rings():
                coords = ring_to_coords(outer)
                if len(coords) >= 3:
                    outers.append(coords)
                for inner in a.inner_rings(outer):
                    ic = ring_to_coords(inner)
                    if len(ic) >= 3:
                        inners.append(ic)
        except Exception:
            return

        if not outers:
            return

        if is_admin:
            level = int(tags.get("admin_level"))
            self.boundaries[level].append(
                BoundaryPolygon(tags.get("name").strip(), level, outers, inners)
            )

        if has_name:
            pt = representative_point(outers, inners)
            if pt is not None:
                osm_ref = f"w{a.orig_id()}" if a.from_way() else f"r{a.orig_id()}"
                if a.from_way():
                    self.area_way_ids.add(a.orig_id())
                self._add_place(osm_ref, tags, pt[0], pt[1])

    def way(self, w: osmium.osm.Way) -> None:
        if "name" not in w.tags:
            return
        if w.id in self.area_way_ids:
            return
        osm_ref = f"w{w.id}"
        if osm_ref in self.places:
            return
        coords = [
            (nd.location.lat, nd.location.lon)
            for nd in w.nodes
            if nd.location.valid()
        ]
        if not coords:
            return
        mid = coords[len(coords) // 2]
        self._add_place(osm_ref, w.tags, mid[0], mid[1])


def read_pbf_timestamp(pbf_path: pathlib.Path) -> Tuple[str, str]:
    reader = osmium.io.Reader(str(pbf_path))
    try:
        header = reader.header()
        ts = header.get("osmosis_replication_timestamp") or ""
    finally:
        reader.close()
    if ts and len(ts) >= 10:
        return ts[:10], ts
    mtime = datetime.datetime.fromtimestamp(
        pbf_path.stat().st_mtime, tz=datetime.timezone.utc
    )
    iso = mtime.strftime("%Y-%m-%dT%H:%M:%SZ")
    return iso[:10], iso


def build_place_book(
    pbf_path: pathlib.Path,
    out_path: pathlib.Path,
    *,
    source_date: Optional[str] = None,
    built_at: Optional[str] = None,
    drop_alt_names: bool = False,
    drop_village_suburb: bool = False,
    drop_fts_prefix: bool = False,
    strict_food: bool = False,
) -> None:
    rules = load_rules(CATEGORIES_PATH)
    pbf_date, pbf_ts = read_pbf_timestamp(pbf_path)
    final_source_date = source_date or pbf_date
    final_built_at = built_at or pbf_ts

    collector = PlaceCollector(
        rules,
        drop_alt_names=drop_alt_names,
        drop_village_suburb=drop_village_suburb,
        strict_food=strict_food,
    )
    collector.apply_file(str(pbf_path), locations=True, idx="flex_mem")

    idx3 = BoundaryIndex(collector.boundaries.get(3, []))
    idx4 = BoundaryIndex(collector.boundaries.get(4, []))
    idx6 = BoundaryIndex(collector.boundaries.get(6, []))
    idx7 = BoundaryIndex(collector.boundaries.get(7, []))

    # Diagnostic check for Philippines admin levels.
    for label, lat, lon in (
        ("Kalibo", 11.706, 122.364),
        ("Malay", 11.900, 121.948),
        ("Manila", 14.599, 120.984),
    ):
        print(
            f"admin-check {label}: L3={idx3.find(lon, lat)!r} "
            f"L4={idx4.find(lon, lat)!r} L6={idx6.find(lon, lat)!r} "
            f"L7={idx7.find(lon, lat)!r}"
        )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()

    schema_sql = SCHEMA_PATH.read_text(encoding="utf-8")
    if drop_fts_prefix:
        schema_sql = schema_sql.replace(",\n  prefix = '2 3'", "")

    conn = sqlite3.connect(str(out_path))
    try:
        conn.executescript(schema_sql)
        rows = []
        for osm_ref in sorted(collector.places.keys()):
            name, alt_names, category, lat, lon, weight = collector.places[osm_ref]
            l7 = idx7.find(lon, lat)
            l6 = idx6.find(lon, lat)
            l4 = idx4.find(lon, lat)
            l3 = idx3.find(lon, lat)
            # In OSM Philippines (verified against Kalibo, Malay, Manila):
            # L6 is the municipality or city (Kalibo, Malay, Manila, Pasay),
            # L7 is sub-city legislative districts (Third District, Fifth District),
            # L4 is the province (Aklan), and L3 is the region (Metro Manila for NCR).
            town = l6 or l7
            province = l4 or (l3 if l3 != town else "")
            rows.append(
                (osm_ref, name, alt_names, category, lat, lon, town, province, weight)
            )

        conn.executemany(
            """
            INSERT INTO places (
              osm_ref, name, alt_names, category, lat, lon, town, province, weight
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            rows,
        )
        conn.execute("INSERT INTO places_fts(places_fts) VALUES('rebuild')")
        meta_rows = sorted(
            [
                ("schema_version", "1"),
                ("source", "Geofabrik Philippines OpenStreetMap extract"),
                ("source_date", final_source_date),
                ("built_at", final_built_at),
                ("licence", "ODbL 1.0 - OpenStreetMap contributors"),
            ],
            key=lambda kv: kv[0],
        )
        conn.executemany("INSERT INTO meta (key, value) VALUES (?, ?)", meta_rows)
        conn.commit()
        conn.execute("VACUUM")
        conn.commit()
    finally:
        conn.close()

    print(
        f"Built {out_path} ({out_path.stat().st_size:,} bytes) "
        f"with {len(rows):,} places."
    )


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pbf", required=True, type=pathlib.Path)
    parser.add_argument("--out", required=True, type=pathlib.Path)
    parser.add_argument("--source-date", default=None)
    parser.add_argument("--built-at", default=None)
    parser.add_argument("--drop-alt-names", action="store_true")
    parser.add_argument("--drop-village-suburb", action="store_true")
    parser.add_argument("--drop-fts-prefix", action="store_true")
    parser.add_argument("--strict-food", action="store_true")
    args = parser.parse_args(argv)

    if not args.pbf.exists():
        print(f"Input PBF not found: {args.pbf}", file=sys.stderr)
        return 1

    build_place_book(
        args.pbf,
        args.out,
        source_date=args.source_date,
        built_at=args.built_at,
        drop_alt_names=args.drop_alt_names,
        drop_village_suburb=args.drop_village_suburb,
        drop_fts_prefix=args.drop_fts_prefix,
        strict_food=args.strict_food,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
