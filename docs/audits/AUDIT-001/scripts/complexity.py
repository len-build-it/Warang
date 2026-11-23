#!/usr/bin/env python3
"""Report line counts for hand-written lib/ Dart files and approximate functions/methods > 60 lines."""
import pathlib
import re
import subprocess

FN_SIG_RE = re.compile(
    r"^\s*(?:static\s+)?(?:Future<[^>]+>|Stream<[^>]+>|Widget|void|bool|int|double|String|List<[^>]+>|Map<[^>]+>|Set<[^>]+>|[A-Z_][A-Za-z0-9_<>,\?\s]*)?\s*"
    r"([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]+>)?\s*\("
)
CONTROL_KEYWORDS = {"if", "for", "while", "switch", "catch", "return", "assert", "super", "this"}


def scan_file(path: pathlib.Path):
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    long_fns = []
    n = len(lines)
    i = 0
    while i < n:
        line = lines[i]
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("///"):
            i += 1
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent in (0, 2) and not stripped.startswith((
            "class ", "enum ", "mixin ", "extension ", "typedef ", "import ",
            "export ", "part ", "final ", "const ", "var ", "late ", "return ",
            "if ", "for ", "while ", "switch ",
        )):
            m = FN_SIG_RE.match(line)
            if m and m.group(1) not in CONTROL_KEYWORDS:
                name = m.group(1)
                j = i
                found_brace = False
                paren_depth = 0
                while j < min(n, i + 25):
                    code = re.sub(r"//.*", "", lines[j])
                    code = re.sub(r"'[^']*'|\"[^\"]*\"", "", code)
                    for ch in code:
                        if ch == "(":
                            paren_depth += 1
                        elif ch == ")":
                            paren_depth -= 1
                        elif paren_depth <= 0 and ch == ";":
                            j = n
                            break
                        elif paren_depth <= 0 and ch == "{":
                            found_brace = True
                            break
                    if found_brace or j == n:
                        break
                    if paren_depth <= 0 and "=>" in code:
                        break
                    j += 1
                if found_brace:
                    depth = 0
                    started = False
                    k = j
                    while k < n:
                        code = re.sub(r"//.*", "", lines[k])
                        code = re.sub(r"'[^']*'|\"[^\"]*\"", "", code)
                        for ch in code:
                            if ch == "{":
                                depth += 1
                                started = True
                            elif ch == "}":
                                depth -= 1
                        if started and depth <= 0:
                            span = k - i + 1
                            if span > 60:
                                long_fns.append((i + 1, k + 1, span, name))
                            i = k
                            break
                        k += 1
        i += 1
    return len(lines), long_fns


def main():
    files = subprocess.check_output(["git", "ls-files", "lib"], text=True).splitlines()
    hand = [f for f in files if f.endswith(".dart") and not f.endswith(".g.dart")]
    print("# Scan 17: File line counts and functions/methods > 60 lines in hand-written lib/ files")
    print("# Command: python docs/audits/AUDIT-001/scripts/complexity.py")
    print("# Note: Brace matching for function/method lengths is approximate.")
    print()
    print("=== FILE LINE COUNTS (DESCENDING) ===")
    results = []
    for f in hand:
        ln_cnt, long_fns = scan_file(pathlib.Path(f))
        results.append((ln_cnt, f, long_fns))
    for ln_cnt, f, _ in sorted(results, reverse=True):
        flag = " [>400]" if ln_cnt > 400 else (" [>300]" if ln_cnt > 300 else "")
        print(f"{ln_cnt:6d} {f}{flag}")
    print()
    print("=== FUNCTIONS / METHODS > 60 LINES (APPROXIMATE BRACE MATCHING) ===")
    all_fns = []
    for _, f, long_fns in results:
        for start, end, span, name in long_fns:
            all_fns.append((span, f, start, end, name))
    for span, f, start, end, name in sorted(all_fns, reverse=True):
        print(f"{span:4d} lines  {f}:{start}-{end}  {name}()")
    print(f"\nTotal files > 400 lines: {sum(1 for ln_cnt, _, _ in results if ln_cnt > 400)}")
    print(f"Total functions/methods > 60 lines: {len(all_fns)}")


if __name__ == "__main__":
    main()
