#!/usr/bin/env python3
"""Check that a plan, evidence log, report, or handoff only cites code that exists.

Usage: python check_claims.py [--root DIR] FILE [FILE ...]

Three checks, run on each Markdown FILE:

1. Locations: every `path:LINE` or `path:START-END` whose first path segment
   exists under the repository root must name an existing file with that many
   lines. Write paths outside the repository with a package or SDK prefix that
   does not exist in the repository, for example `drift-2.34.4/lib/...`.
2. Quotes: every line of the form `path:LINE: text` (the `git grep -n` form) is
   a verbatim quote, and `text` must appear within 2 lines of LINE (or inside
   START-END). End a quote with `...` to compare only its start.
3. Names: every code-like name in backticks (camelCase, snake_case, or a
   leading underscore) must appear in the repository's code. Fenced code blocks
   are skipped. Declare names that are not in the code on a line starting with
   `New names:` (names the work will add) or `External names:` (SDK, platform,
   or tool names), separated by commas or spaces.

The code corpus is every tracked or untracked, non-ignored file outside `docs/`
that is not Markdown, plus every file path in the repository.
Prints one line per problem, then `<N> problems`; exits 1 when N > 0.
Standard library only.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys

PATH = r"(?:[A-Za-z0-9_.~-]+[/\\])*[A-Za-z0-9_.-]+\.[A-Za-z0-9]+"
LOCATION = re.compile(rf"(?<![\w/\\.-])({PATH}):(\d+)(?:-(\d+))?")
QUOTE = re.compile(rf"^\s*({PATH}):(\d+)(?:-(\d+))?:(.*)$")
TOKEN = re.compile(r"\b_?[A-Za-z][A-Za-z0-9_]*\b")
DECLARED = re.compile(r"^\s*[-*]?\s*(New names|External names):\s*(.+)$", re.IGNORECASE)


def looks_like_code(token: str) -> bool:
    return token.startswith("_") or "_" in token or re.search(r"[a-z][A-Z]", token) is not None


def git_files(root: pathlib.Path) -> list[str]:
    out = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=root, capture_output=True, text=True, encoding="utf-8", errors="ignore", check=True,
    ).stdout
    return [line for line in out.splitlines() if line]


def build_corpus(root: pathlib.Path, files: list[str], skip: set[pathlib.Path]) -> str:
    parts = ["\n".join(files)]
    for rel in files:
        path = root / rel
        if rel.startswith("docs/") or rel.lower().endswith(".md") or path.resolve() in skip:
            continue
        try:
            if path.stat().st_size > 5_000_000:
                continue
            data = path.read_bytes()
        except OSError:
            continue
        if b"\0" in data[:4096]:
            continue
        parts.append(data.decode("utf-8", errors="ignore"))
    return "\n".join(parts)


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def read_lines(root: pathlib.Path, rel: str, cache: dict[str, list[str] | None]) -> list[str] | None:
    if rel not in cache:
        path = root / rel
        try:
            cache[rel] = path.read_text(encoding="utf-8", errors="replace").splitlines() if path.is_file() else None
        except OSError:
            cache[rel] = None
    return cache[rel]


def check_file(doc: pathlib.Path, root: pathlib.Path, corpus: str, top: set[str]) -> list[str]:
    problems: list[str] = []
    cache: dict[str, list[str] | None] = {}
    lines = doc.read_text(encoding="utf-8").splitlines()
    declared: set[str] = set()
    for line in lines:
        match = DECLARED.match(line)
        if match:
            declared.update(t for t in re.split(r"[,\s`]+", match.group(2)) if t)

    in_fence = False
    for number, line in enumerate(lines, 1):
        where = f"{doc.name}:{number}"
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue

        quote = QUOTE.match(line)
        for match in LOCATION.finditer(line):
            rel = match.group(1).replace("\\", "/")
            if rel.split("/")[0] not in top:
                continue
            start = int(match.group(2))
            end = int(match.group(3) or start)
            content = read_lines(root, rel, cache)
            if content is None:
                problems.append(f"{where}: file not found: {rel}")
                continue
            if start < 1 or end < start or end > len(content):
                problems.append(f"{where}: {rel}:{match.group(2)}{'-' + match.group(3) if match.group(3) else ''} is outside the file ({len(content)} lines)")
                continue
            if quote and quote.start(1) == match.start(1):
                text = normalize(quote.group(4))
                if not text:
                    continue
                prefix = text.endswith("...")
                if prefix:
                    text = text[:-3].rstrip()
                window = content[max(0, start - 3): min(len(content), end + 2)]
                found = any(
                    (normalize(candidate).startswith(text) if prefix else text in normalize(candidate))
                    for candidate in window
                ) or (text in normalize(" ".join(window)))
                if not found:
                    problems.append(f"{where}: quote not found near {rel}:{start}: {text[:80]}")

        if in_fence or DECLARED.match(line):
            continue
        for span in re.findall(r"`([^`]+)`", line):
            if "/" in span or "\\" in span:
                continue
            for token in TOKEN.findall(span):
                if looks_like_code(token) and token not in declared and token not in corpus:
                    problems.append(f"{where}: name not in the code: {token} (fix it, or declare it under 'New names:' or 'External names:')")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="repository root (default: current directory)")
    parser.add_argument("files", nargs="+", help="Markdown files to check")
    args = parser.parse_args()
    root = pathlib.Path(args.root).resolve()
    docs = [pathlib.Path(f).resolve() for f in args.files]
    files = git_files(root)
    top = {p.name for p in root.iterdir()}
    corpus = build_corpus(root, files, set(docs))
    problems: list[str] = []
    for doc in docs:
        problems.extend(check_file(doc, root, corpus, top))
    for problem in problems:
        print(problem)
    print(f"{len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
