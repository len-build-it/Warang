#!/usr/bin/env python3
"""List code identifiers named in AUDIT-001 findings that the repository does not contain.

Added in AUDIT-001 revision 2.
For each `### AUD-NNN` block, the script reads backticked spans outside `Fix:` lines and fenced code blocks,
keeps tokens that look like code (camelCase, snake_case, or a leading underscore),
and reports each token that appears nowhere in the tracked files under lib, test, tool, android, and pubspec.yaml,
or in the untracked scripts/ folder.
An optional first argument names another report file, such as an earlier revision.
The output is for review by hand: Dart, Flutter, and Android API names, tool names, and names a fix proposes are expected leftovers.
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parents[4]
REPORT = REPO / "docs/audits/AUDIT-001-code-quality-report.md"
CODE_TOKEN = re.compile(r"\b_?[A-Za-z][A-Za-z0-9_]*\b")


def looks_like_code(token: str) -> bool:
    return (
        token.startswith("_")
        or "_" in token
        or re.search(r"[a-z][A-Z]", token) is not None
    )


def corpus() -> str:
    tracked = subprocess.run(
        ["git", "grep", "-h", "-I", "-e", ".", "--", "lib", "test", "tool", "android", "pubspec.yaml"],
        cwd=REPO,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="ignore",
    ).stdout
    scripts = "".join(
        f.read_text(encoding="utf-8", errors="ignore")
        for f in (REPO / "scripts").glob("*")
        if f.is_file()
    )
    return tracked + scripts


def main() -> int:
    text = corpus()
    report = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else REPORT
    lines = report.read_text(encoding="utf-8").splitlines()
    current = None
    in_fence = False
    missing: dict[str, set[str]] = {}
    for line in lines:
        heading = re.match(r"^### (AUD-\d{3}):", line)
        if heading:
            current = heading.group(1)
            in_fence = False
        elif line.startswith("## "):
            current = None
        if current is None:
            continue
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence or line.startswith("Fix:"):
            continue
        for span in re.findall(r"`([^`]+)`", line):
            if "/" in span or "\\" in span:
                continue
            for token in CODE_TOKEN.findall(span):
                if looks_like_code(token) and token not in text:
                    missing.setdefault(current, set()).add(token)
    for finding in sorted(missing):
        print(f"{finding}: {', '.join(sorted(missing[finding]))}")
    total = sum(len(v) for v in missing.values())
    print(f"{total} unresolved identifiers in {len(missing)} findings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
