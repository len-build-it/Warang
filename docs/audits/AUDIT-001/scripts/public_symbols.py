#!/usr/bin/env python3
"""Scan hand-written lib/ Dart files for public top-level and class-level symbols with 0 or test-only references."""
import pathlib
import re
import subprocess

TOP_RE = re.compile(
    r"^(?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+|mixin\s+)*"
    r"(?:class|mixin|enum|extension|typedef)\s+([A-Z][A-Za-z0-9_]*)\b"
)
TOP_VAL_RE = re.compile(
    r"^(?:final|const|var|late)\s+(?:[A-Za-z0-9_<>,\?\s]+?\s+)?([a-z][A-Za-z0-9_]*)\s*[=;]"
)
TOP_FN_RE = re.compile(
    r"^(?:[A-Za-z0-9_<>,\?\s]+\s+)?([a-z][A-Za-z0-9_]*)\s*(?:<[^>]+>)?\s*\("
)
MEMBER_RE = re.compile(
    r"^  (?:static\s+)?(?:const\s+|final\s+)?(?:[A-Za-z0-9_<>,\?\s]+\s+)?"
    r"(?:get\s+|set\s+)?([a-z][A-Za-z0-9_]*)\s*(?:\(|=>|=|;|\{)"
)
SKIP_NAMES = {
    "build", "createState", "initState", "dispose", "didUpdateWidget",
    "didChangeDependencies", "deactivate", "reassemble", "paint", "shouldRepaint",
    "shouldReclip", "getClip", "operator", "toString", "hashCode", "noSuchMethod",
    "copyWith", "lerp", "main", "if", "for", "while", "switch", "return", "catch",
    "super", "this", "else", "try", "finally", "throw", "await", "yield", "new",
    "const", "final", "var", "void", "bool", "int", "double", "String", "dynamic",
    "override", "get", "set", "factory", "external", "static", "late", "required",
    "onCreate", "onUpgrade", "beforeOpen", "schemaVersion", "migration", "allTables",
    "primaryKey", "debugFillProperties", "createRenderObject", "updateRenderObject",
}


def git_files(*roots):
    out = subprocess.check_output(["git", "ls-files", *roots], text=True).splitlines()
    return [f for f in out if f.endswith(".dart") and not f.endswith(".g.dart")]


def strip_comments(text: str) -> str:
    text = re.sub(r"//.*", "", text)
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return text


def main():
    lib_files = git_files("lib")
    all_files = git_files("lib", "test", "tool")
    file_lines = {
        f: pathlib.Path(f).read_text(encoding="utf-8", errors="replace").splitlines()
        for f in all_files
    }
    clean_lines = {
        f: strip_comments("\n".join(lns)).splitlines()
        for f, lns in file_lines.items()
    }

    decls = []
    for f in lib_files:
        lines = file_lines[f]
        brace_depth = 0
        current_class = None
        for idx, raw in enumerate(lines, start=1):
            stripped = raw.strip()
            if (
                not stripped
                or stripped.startswith("//")
                or stripped.startswith("///")
                or stripped.startswith(("import ", "export ", "part "))
            ):
                continue
            if brace_depth == 0:
                m = TOP_RE.match(raw)
                if m:
                    name = m.group(1)
                    if not name.startswith("_"):
                        decls.append((f, idx, "type", name, None))
                        current_class = name
                else:
                    m2 = TOP_VAL_RE.match(raw)
                    if m2 and m2.group(1) not in SKIP_NAMES and not m2.group(1).startswith("_"):
                        decls.append((f, idx, "top-var", m2.group(1), None))
                    else:
                        m3 = TOP_FN_RE.match(raw)
                        if m3 and m3.group(1) not in SKIP_NAMES and not m3.group(1).startswith("_"):
                            decls.append((f, idx, "top-fn", m3.group(1), None))
            elif brace_depth == 1 and current_class and not stripped.startswith("@"):
                prev = lines[idx - 2].strip() if idx >= 2 else ""
                if prev != "@override":
                    mm = MEMBER_RE.match(raw)
                    if mm:
                        name = mm.group(1)
                        if name not in SKIP_NAMES and not name.startswith("_") and name != current_class:
                            decls.append((f, idx, "member", name, current_class))
            code_part = re.sub(r"//.*", "", raw)
            code_part = re.sub(r"'[^']*'|\"[^\"]*\"", "", code_part)
            brace_depth += code_part.count("{") - code_part.count("}")
            if brace_depth <= 0:
                brace_depth = 0
                current_class = None

    seen = set()
    uniq_decls = []
    for d in decls:
        key = (d[0], d[3], d[4])
        if key not in seen:
            seen.add(key)
            uniq_decls.append(d)

    zero_refs = []
    test_only = []
    for f, line_no, kind, name, owner in uniq_decls:
        pat = re.compile(r"\b" + re.escape(name) + r"\b")
        lib_hits = []
        test_hits = []
        for other_f, clines in clean_lines.items():
            for oidx, ln in enumerate(clines, start=1):
                if other_f == f and oidx == line_no:
                    continue
                if pat.search(ln):
                    if other_f.startswith("lib/"):
                        lib_hits.append(f"{other_f}:{oidx}")
                    else:
                        test_hits.append(f"{other_f}:{oidx}")
        label = f"{owner}.{name}" if owner else name
        if not lib_hits and not test_hits:
            zero_refs.append((f, line_no, kind, label))
        elif not lib_hits and test_hits:
            test_only.append((f, line_no, kind, label, len(test_hits), test_hits[:3]))

    print("# Scan 05: Unused and test-only public symbols in hand-written lib/ files")
    print("# Command: python docs/audits/AUDIT-001/scripts/public_symbols.py")
    print(f"# Total public declarations scanned: {len(uniq_decls)}")
    print(f"# Zero outside references: {len(zero_refs)}")
    print(f"# Test/tool-only references: {len(test_only)}")
    print()
    print("=== ZERO OUTSIDE REFERENCES ===")
    for f, line_no, kind, label in zero_refs:
        print(f"{f}:{line_no} [{kind}] {label}")
    print()
    print("=== TEST/TOOL-ONLY REFERENCES ===")
    for f, line_no, kind, label, cnt, sample in test_only:
        print(f"{f}:{line_no} [{kind}] {label} (test/tool hits: {cnt}; sample: {', '.join(sample)})")


if __name__ == "__main__":
    main()
