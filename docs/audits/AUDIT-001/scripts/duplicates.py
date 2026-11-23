#!/usr/bin/env python3
"""Detect duplicated 8-line windows (ignoring whitespace and comments) across hand-written lib/ Dart files."""
import hashlib
import pathlib
import re
import subprocess
from collections import defaultdict

WINDOW = 8


def normalize_file(path: pathlib.Path):
    raw = path.read_text(encoding="utf-8", errors="replace")
    no_block = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), raw, flags=re.S)
    norm_lines = []
    for idx, line in enumerate(no_block.splitlines(), start=1):
        code = re.sub(r"//.*", "", line)
        compact = re.sub(r"\s+", "", code)
        if compact:
            norm_lines.append((idx, compact))
    return norm_lines


def main():
    files = subprocess.check_output(["git", "ls-files", "lib"], text=True).splitlines()
    hand = [f for f in files if f.endswith(".dart") and not f.endswith(".g.dart")]

    file_norms = {}
    windows = defaultdict(list)
    for f in hand:
        nl = normalize_file(pathlib.Path(f))
        file_norms[f] = nl
        for i in range(len(nl) - WINDOW + 1):
            chunk = "\n".join(x[1] for x in nl[i:i + WINDOW])
            h = hashlib.sha1(chunk.encode("utf-8")).hexdigest()
            windows[h].append((f, i))

    pair_hits = defaultdict(list)
    for h, locs in windows.items():
        if len(locs) < 2:
            continue
        for a_i in range(len(locs)):
            for b_i in range(a_i + 1, len(locs)):
                f1, i1 = locs[a_i]
                f2, i2 = locs[b_i]
                if f1 == f2 and abs(i1 - i2) < WINDOW:
                    continue
                if (f1, i1) > (f2, i2):
                    f1, i1, f2, i2 = f2, i2, f1, i1
                pair_hits[(f1, f2)].append((i1, i2))

    merged = []
    for (f1, f2), hits in pair_hits.items():
        hits.sort()
        used = [False] * len(hits)
        for idx, (s1, s2) in enumerate(hits):
            if used[idx]:
                continue
            used[idx] = True
            e1, e2 = s1 + WINDOW - 1, s2 + WINDOW - 1
            changed = True
            while changed:
                changed = False
                for j in range(idx + 1, len(hits)):
                    if used[j]:
                        continue
                    t1, t2 = hits[j]
                    if t1 <= e1 + 1 and t2 <= e2 + 1 and (t1 - s1) == (t2 - s2):
                        used[j] = True
                        e1 = max(e1, t1 + WINDOW - 1)
                        e2 = max(e2, t2 + WINDOW - 1)
                        changed = True
            n1 = file_norms[f1]
            n2 = file_norms[f2]
            ln_count = e1 - s1 + 1
            merged.append((ln_count, f1, n1[s1][0], n1[e1][0], f2, n2[s2][0], n2[e2][0]))

    merged.sort(reverse=True)
    print("# Scan 18: Duplicated code blocks (>= 8 consecutive non-empty normalized lines) in hand-written lib/ files")
    print("# Command: python docs/audits/AUDIT-001/scripts/duplicates.py")
    print(f"# Merged duplicate pairs found: {len(merged)}")
    print()
    for ln_count, f1, a1, b1, f2, a2, b2 in merged:
        print(f"{ln_count:3d} norm-lines  {f1}:{a1}-{b1}  <->  {f2}:{a2}-{b2}")


if __name__ == "__main__":
    main()
