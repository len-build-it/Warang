#!/usr/bin/env python3
"""Validate docs/audits/AUDIT-001-code-quality-report.md against AUDIT-001 Phase 4 rules."""

from __future__ import annotations

import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[4] if (pathlib.Path(__file__).resolve().parents[0].name == "scripts") else pathlib.Path.cwd()
if not (REPO / "docs/audits/AUDIT-001-code-quality-report.md").exists():
    REPO = pathlib.Path.cwd()

REPORT = REPO / "docs/audits/AUDIT-001-code-quality-report.md"

REQUIRED_FIELDS = [
    "Category",
    "Severity",
    "Status",
    "Locations",
    "Conflicts with",
    "Effort",
    "Lines removable",
]

VALID_CATEGORIES = {
    "dangerous",
    "unnecessary (delete)",
    "unnecessary (stdlib)",
    "unnecessary (native)",
    "unnecessary (yagni)",
    "unnecessary (shrink)",
    "sloppy",
}
VALID_SEVERITIES = {"critical", "high", "medium", "low"}
VALID_STATUSES = {"Confirmed", "Plausible"}
VALID_EFFORTS = {
    "S (under 1 hour)",
    "M (1 to 4 hours)",
    "L (over 4 hours)",
}


def main() -> int:
    problems: list[str] = []
    text = REPORT.read_text(encoding="utf-8")
    lines = text.splitlines()

    # Check em dash / en dash across report
    for idx, line in enumerate(lines, 1):
        if "\u2014" in line or "\u2013" in line:
            problems.append(f"L{idx}: contains em dash or en dash")

    # Parse Summary total row
    summary_total = None
    for line in lines:
        m = re.match(r"^\|\s*Total\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|$", line)
        if m:
            summary_total = int(m.group(5))
            if sum(int(m.group(i)) for i in range(1, 5)) != summary_total:
                problems.append("Summary Total row columns do not sum to Total")
            break
    if summary_total is None:
        problems.append("Summary table Total row not found")

    # Find all ### AUD-NNN headings and split sections
    heading_re = re.compile(r"^### (AUD-\d{3}):\s+(.+)$")
    finding_starts: list[tuple[int, str, str]] = []
    for idx, line in enumerate(lines):
        m = heading_re.match(line)
        if m:
            finding_starts.append((idx, m.group(1), m.group(2)))

    if not finding_starts:
        problems.append("No ### AUD-NNN findings found")

    if summary_total is not None and len(finding_starts) != summary_total:
        problems.append(
            f"Summary total ({summary_total}) != number of ### AUD- headings ({len(finding_starts)})"
        )

    seen_ids: set[str] = set()
    for i, (start_idx, fid, _title) in enumerate(finding_starts):
        if fid in seen_ids:
            problems.append(f"{fid}: duplicate finding ID")
        seen_ids.add(fid)

        # Slice until next heading (## or ###)
        end_idx = len(lines)
        for j in range(start_idx + 1, len(lines)):
            if lines[j].startswith("## ") or lines[j].startswith("### "):
                end_idx = j
                break
        block_lines = lines[start_idx + 1 : end_idx]
        block = "\n".join(block_lines)

        fields: dict[str, str] = {}
        for bl in block_lines:
            fm = re.match(r"^- ([A-Za-z ]+):\s*(.+)$", bl)
            if fm:
                fields[fm.group(1).strip()] = fm.group(2).strip()

        for req in REQUIRED_FIELDS:
            if req not in fields or not fields[req]:
                problems.append(f"{fid}: missing required field '{req}'")

        if "Category" in fields and fields["Category"] not in VALID_CATEGORIES:
            problems.append(f"{fid}: invalid Category '{fields['Category']}'")
        if "Severity" in fields and fields["Severity"] not in VALID_SEVERITIES:
            problems.append(f"{fid}: invalid Severity '{fields['Severity']}'")
        if "Status" in fields and fields["Status"] not in VALID_STATUSES:
            problems.append(f"{fid}: invalid Status '{fields['Status']}'")
        if "Effort" in fields and fields["Effort"] not in VALID_EFFORTS:
            problems.append(f"{fid}: invalid Effort '{fields['Effort']}'")
        if "Lines removable" in fields and not re.match(r"^\d+$", fields["Lines removable"]):
            problems.append(f"{fid}: invalid Lines removable '{fields['Lines removable']}'")

        # Check Proof and Fix
        if not re.search(r"^Proof \([^)]+\):\s*$", block, re.MULTILINE):
            problems.append(f"{fid}: missing 'Proof (<method>):' section")
        fix_match = re.search(r"^Fix:\s*(.+)$", block, re.MULTILINE)
        if not fix_match or fix_match.group(1).strip().lower() in {"refactor", "clean up", "cleanup"}:
            problems.append(f"{fid}: missing or vague 'Fix:' line")

        # Validate every backticked path:line location at HEAD
        if "Locations" in fields:
            locs = re.findall(r"`([^`]+)`", fields["Locations"])
            if not locs:
                problems.append(f"{fid}: no backticked locations found")
            for loc in locs:
                lm = re.match(r"^(.+):(\d+)$", loc)
                if not lm:
                    problems.append(f"{fid}: location '{loc}' is not in path:line format")
                    continue
                rel_path, line_no = lm.group(1), int(lm.group(2))
                target = REPO / rel_path
                if not target.exists():
                    problems.append(f"{fid}: file does not exist '{rel_path}'")
                    continue
                if target.is_dir():
                    continue
                if target.suffix.lower() in {".png", ".jpg", ".jpeg", ".sqlite", ".ttf"}:
                    if line_no < 1:
                        problems.append(f"{fid}: invalid line number for binary '{loc}'")
                    continue
                try:
                    file_lines = target.read_text(encoding="utf-8", errors="replace").splitlines()
                except OSError as exc:
                    problems.append(f"{fid}: cannot read '{rel_path}': {exc}")
                    continue
                if line_no < 1 or line_no > len(file_lines):
                    problems.append(
                        f"{fid}: line {line_no} out of range for '{rel_path}' (has {len(file_lines)} lines)"
                    )

    for p in problems:
        print(p)
    print(f"{len(problems)} problems")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
