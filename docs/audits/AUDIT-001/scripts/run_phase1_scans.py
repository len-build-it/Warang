#!/usr/bin/env python3
"""Run AUDIT-001 Phase 1 automated scans 03, 04, 06-16, 19-21."""
import pathlib
import re
import subprocess
from collections import Counter

SCANS = pathlib.Path("docs/audits/AUDIT-001/scans")
SCANS.mkdir(parents=True, exist_ok=True)


def run_grep(args):
    p = subprocess.run(["git", "grep", *args], capture_output=True, text=True)
    return p.stdout.splitlines()


def git_ls(*paths):
    p = subprocess.run(["git", "ls-files", *paths], capture_output=True, text=True)
    return [x for x in p.stdout.splitlines() if x]


def write_scan(name, header_lines, body_lines):
    out = SCANS / name
    text = "\n".join([*header_lines, "", *body_lines, ""])
    out.write_text(text, encoding="utf-8")
    print(f"Wrote {name} ({len(body_lines)} lines)")


def scan_03_dependencies():
    pub = pathlib.Path("pubspec.yaml").read_text(encoding="utf-8").splitlines()
    section = None
    deps = []
    dev_deps = []
    for ln in pub:
        if ln.startswith("dependencies:"):
            section = "dep"
            continue
        elif ln.startswith("dev_dependencies:"):
            section = "dev"
            continue
        elif ln and not ln.startswith(" "):
            section = None
        if section in ("dep", "dev"):
            m = re.match(r"^  ([a-z0-9_]+):", ln)
            if m and m.group(1) not in ("flutter", "flutter_test", "sdk"):
                (deps if section == "dep" else dev_deps).append(m.group(1))
    body = ["=== dependencies ==="]
    plugin_notes = {
        "sqlite3_flutter_libs": "plugin-registered native SQLite library (no Dart import needed; note 0.6.0+eol in pub outdated)",
    }
    for d in deps:
        lib_hits = [h for h in run_grep(["-n", f"package:{d}/", "--", "lib"]) if ".g.dart:" not in h]
        test_hits = run_grep(["-n", f"package:{d}/", "--", "test", "tool"])
        note = f"  [{plugin_notes[d]}]" if d in plugin_notes else ""
        flag = "  <-- CANDIDATE (0 lib imports)" if (len(lib_hits) == 0 and d not in plugin_notes) else ""
        body.append(f"{d:24s} lib={len(lib_hits):3d}  test/tool={len(test_hits):3d}{note}{flag}")
    body.append("")
    body.append("=== dev_dependencies ===")
    dev_notes = {
        "build_runner": "CLI codegen runner",
        "drift_dev": "Drift build_runner codegen",
        "flutter_launcher_icons": "CLI launcher icon generator configured in pubspec.yaml",
        "flutter_lints": "included in analysis_options.yaml",
    }
    for d in dev_deps:
        lib_hits = [h for h in run_grep(["-n", f"package:{d}/", "--", "lib"]) if ".g.dart:" not in h]
        test_hits = run_grep(["-n", f"package:{d}/", "--", "test", "tool"])
        note = f"  [{dev_notes[d]}]" if d in dev_notes else ""
        body.append(f"{d:24s} lib={len(lib_hits):3d}  test/tool={len(test_hits):3d}{note}")
    write_scan(
        "03-dependency-use.txt",
        [
            "# Scan 03: Direct dependency usage across lib, test, tool",
            '# Command: for each dep in pubspec.yaml: git grep -n "package:<name>/" -- lib test tool (via docs/audits/AUDIT-001/scripts/run_phase1_scans.py)',
        ],
        body,
    )


def scan_04_assets():
    pub = pathlib.Path("pubspec.yaml").read_text(encoding="utf-8")
    declared = [a for a in re.findall(r"^\s*-\s+(?:asset:\s+)?([^\s#]+)", pub, flags=re.M) if "/" in a]
    body = ["=== DECLARED ASSETS IN pubspec.yaml ==="]
    for a in declared:
        fname = pathlib.Path(a).name
        path_hits = run_grep(["-n", a, "--", "lib", "test", "tool"])
        name_hits = run_grep(["-n", fname, "--", "lib", "test", "tool"])
        flag = "  <-- CANDIDATE (0 refs)" if not path_hits and not name_hits else ""
        body.append(f"{a:55s} path_hits={len(path_hits):2d}  name_hits={len(name_hits):2d}{flag}")
        for h in path_hits[:3]:
            body.append(f"    {h}")
    body.append("")
    body.append("=== TRACKED FILES UNDER assets/ AND design/ NOT IN pubspec.yaml ===")
    tracked = git_ls("assets", "design")
    declared_set = set(declared)
    launcher_paths = set(re.findall(r"(?:image_path|adaptive_icon_foreground|adaptive_icon_monochrome):\s*(\S+)", pub))
    for f in tracked:
        if f in declared_set:
            continue
        fname = pathlib.Path(f).name
        hits = run_grep(["-n", fname, "--", "lib", "test", "tool", "pubspec.yaml", "android"])
        size_kb = (pathlib.Path(f).stat().st_size + 1023) // 1024
        tag = " [flutter_launcher_icons]" if f in launcher_paths else (" <-- CANDIDATE (undeclared, 0 refs)" if not hits else "")
        body.append(f"{size_kb:6d} KB  {f}  refs={len(hits)}{tag}")
    write_scan(
        "04-asset-use.txt",
        [
            "# Scan 04: Declared asset usage and undeclared tracked files under assets/ and design/",
            "# Command: python docs/audits/AUDIT-001/scripts/run_phase1_scans.py (scan_04_assets)",
        ],
        body,
    )


def per_file_counts(hits):
    c = Counter(h.split(":", 1)[0] for h in hits)
    lines = ["=== PER-FILE COUNTS ==="]
    for f, n in c.most_common():
        lines.append(f"{n:4d}  {f}")
    lines.append("")
    return lines


def pattern_scan(filename, title, pattern, paths, exclude_prefixes=(), extra_fn=None):
    hits = run_grep(["-nE", pattern, "--", *paths])
    filtered = []
    for h in hits:
        f = h.split(":", 1)[0]
        if f.endswith(".g.dart"):
            continue
        if any(f.startswith(p) for p in exclude_prefixes):
            continue
        filtered.append(h)
    body = []
    if extra_fn:
        body.extend(extra_fn(filtered))
    body.append(f"Total matching lines: {len(filtered)}")
    body.append("")
    body.extend(filtered)
    write_scan(
        filename,
        [
            f"# {title}",
            f'# Command: git grep -nE "{pattern}" -- {" ".join(paths)} (excluding *.g.dart{", " + ", ".join(exclude_prefixes) if exclude_prefixes else ""})',
        ],
        body,
    )


def scan_09_async_gaps():
    lib_files = [f for f in git_ls("lib") if f.endswith(".dart") and not f.endswith(".g.dart")]
    body = []
    total_methods = 0
    for f in lib_files:
        lines = pathlib.Path(f).read_text(encoding="utf-8", errors="replace").splitlines()
        full = "\n".join(lines)
        if "await " not in full or not re.search(r"setState\(|context\.|ref\.", full):
            continue
        i = 0
        n = len(lines)
        file_hits = []
        while i < n:
            ln = lines[i]
            if "async" in ln and "{" in ln:
                start = i
                depth = 0
                started = False
                k = i
                while k < n:
                    code = re.sub(r"//.*", "", lines[k])
                    for ch in code:
                        if ch == "{":
                            depth += 1
                            started = True
                        elif ch == "}":
                            depth -= 1
                    if started and depth <= 0:
                        break
                    k += 1
                block = lines[start:k + 1]
                first_await = None
                uses_after = []
                mounted_checks = []
                for rel_idx, bln in enumerate(block):
                    abs_ln = start + rel_idx + 1
                    if "await " in bln and first_await is None:
                        first_await = abs_ln
                    if first_await is not None:
                        if re.search(r"\bmounted\b", bln):
                            mounted_checks.append(abs_ln)
                        if re.search(r"setState\(|\bcontext\.|\bref\.", bln):
                            uses_after.append((abs_ln, bln.strip()))
                if first_await is not None and uses_after:
                    file_hits.append((start + 1, k + 1, lines[start].strip(), first_await, mounted_checks, uses_after))
                    total_methods += 1
                i = k + 1
            else:
                i += 1
        if file_hits:
            body.append(f"=== {f} ===")
            for s, e, sig, aw, mchecks, uses in file_hits:
                body.append(f"  method lines {s}-{e}: {sig}")
                body.append(f"    first await: L{aw}; mounted checks after await: {mchecks}")
                for uln, utxt in uses:
                    body.append(f"    L{uln}: {utxt}")
    body.insert(0, f"Total async methods with setState/context./ref. after await: {total_methods}")
    write_scan(
        "09-async-gaps.txt",
        [
            "# Scan 09: Async methods using setState(, context., or ref. after an await",
            "# Command: python docs/audits/AUDIT-001/scripts/run_phase1_scans.py (scan_09_async_gaps)",
        ],
        body,
    )


def scan_10_lifecycle():
    types = [
        "AnimationController", "TextEditingController", "ScrollController",
        "FocusNode", "StreamSubscription", "Timer", "StreamController",
    ]
    lib_files = [f for f in git_ls("lib") if f.endswith(".dart") and not f.endswith(".g.dart")]
    body = []
    for f in lib_files:
        text = pathlib.Path(f).read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        hits = []
        for idx, ln in enumerate(lines, start=1):
            for t in types:
                if re.search(r"\b" + t + r"\b", ln):
                    hits.append((idx, t, ln.strip()))
        if hits:
            has_dispose = ".dispose()" in text
            has_cancel = ".cancel()" in text
            has_close = ".close()" in text
            body.append(f"=== {f} (file has dispose={has_dispose}, cancel={has_cancel}, close={has_close}) ===")
            for idx, t, txt in hits:
                body.append(f"  L{idx:4d} [{t}]: {txt}")
    write_scan(
        "10-lifecycle.txt",
        [
            "# Scan 10: Lifecycle-managed controllers, FocusNode, StreamSubscription, Timer, StreamController",
            "# Command: python docs/audits/AUDIT-001/scripts/run_phase1_scans.py (scan_10_lifecycle)",
        ],
        body,
    )


def scan_11_sql_and_fts():
    pat = r"customSelect|customStatement|customUpdate|rawQuery|rawInsert|rawDelete|execute\(|MATCH|LIKE"
    hits = [h for h in run_grep(["-nE", pat, "--", "lib"]) if ".g.dart:" not in h]
    interp_hits = []
    for f in sorted({h.split(":", 1)[0] for h in hits}):
        lines = pathlib.Path(f).read_text(encoding="utf-8", errors="replace").splitlines()
        for idx, ln in enumerate(lines, start=1):
            if ("$" in ln or " + " in ln) and re.search(r"SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|PRAGMA|WHERE|MATCH|LIKE|customStatement|customSelect|rawQuery|execute|sql|Sql|CASE", ln, re.I):
                interp_hits.append(f"{f}:{idx}: {ln.strip()}")
    body = [f"Total SQL/FTS call hits: {len(hits)}", "", *hits, "", "=== STRING INTERPOLATION / CONCATENATION IN SQL FILES ===", *interp_hits]
    write_scan(
        "11-sql-and-fts.txt",
        [
            "# Scan 11: Raw SQL, FTS5 MATCH/LIKE, and SQL string interpolation in lib/",
            f'# Command: git grep -nE "{pat}" -- lib (excluding *.g.dart) + interpolation scan',
        ],
        body,
    )


def scan_19_android():
    files = [
        "android/app/src/main/AndroidManifest.xml",
        "android/app/src/debug/AndroidManifest.xml",
        "android/app/src/profile/AndroidManifest.xml",
        "android/app/src/main/res/xml/data_extraction_rules.xml",
        "android/app/src/main/res/xml/network_security_config.xml",
        "android/app/build.gradle.kts",
    ]
    body = [
        "=== KEY SECURITY & BUILD OBSERVATIONS ===",
        '- android:allowBackup="false" (AndroidManifest.xml:8)',
        '- android:dataExtractionRules="@xml/data_extraction_rules" excludes cloud-backup and device-transfer',
        '- android:networkSecurityConfig="@xml/network_security_config" sets cleartextTrafficPermitted="false"',
        '- android:exported="true" on .MainActivity (launcher activity)',
        "- uses-permission in main manifest: ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION ONLY (android.permission.INTERNET is ONLY in debug/ and profile/ manifests)",
        "- minSdk = flutter.minSdkVersion, targetSdk = flutter.targetSdkVersion",
        "- release signingConfig: fails closed if android/key.properties is missing; uses unchecked `as String` casts when present",
        "- release minifyEnabled / shrinkResources: NOT configured in buildTypes.release",
        "- leftover template TODO at android/app/build.gradle.kts:36",
        "- hard-coded secret or keystore path: none found in tracked android/ files",
        "",
    ]
    for f in files:
        p = pathlib.Path(f)
        body.append(f"=== {f} ===")
        if p.exists():
            for idx, ln in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
                body.append(f"{idx:3d}: {ln}")
        else:
            body.append("(missing)")
        body.append("")
    write_scan(
        "19-android.txt",
        [
            "# Scan 19: Android manifests, XML security configs, and build.gradle.kts",
            "# Command: python docs/audits/AUDIT-001/scripts/run_phase1_scans.py (scan_19_android)",
        ],
        body,
    )


def scan_20_tooling():
    files = [
        "tool/place_book/requirements.txt",
        "tool/place_book/schema.sql",
        "tool/place_book/README.md",
        "tool/place_book/build_place_book.py",
        "scripts/build-and-archive.ps1",
        "scripts/build-and-archive.sh",
    ]
    body = [
        "=== TOOLING CANDIDATE OBSERVATIONS ===",
        "- tool/place_book/requirements.txt:1 -> osmium==4.3.2 (pinned).",
        "- tool/place_book/README.md:26 -> curl download of philippines-latest.osm.pbf has no checksum verification.",
        "- tool/place_book/build_place_book.py:325 -> broad `except Exception: return` silently skips malformed OSM areas.",
        "- tool/place_book/build_place_book.py:422-423 -> `out_path.unlink()` deletes existing output SQLite before rebuilding (non-atomic).",
        "- tool/place_book/build_place_book.py:427 -> fragile exact-whitespace string replacement for `--drop-fts-prefix`.",
        "- tool/place_book/build_place_book.py:410-419 -> hardcoded diagnostic print statements run on every build.",
        "- scripts/build-and-archive.sh:50-88 -> does not fail if 0 release APKs are found; builds JSON via unescaped heredoc (lines 91-100); grep/awk pubspec parser breaks on inline comments; neither script verifies release signing.",
        "- scripts/build-and-archive.ps1:63-64 -> git stderr suppressed without checking exit code.",
        "",
    ]
    tracked_set = set(git_ls("tool", "scripts"))
    for f in files:
        p = pathlib.Path(f)
        body.append(f"=== {f} ({'tracked' if f in tracked_set else 'untracked'}) ===")
        if p.exists():
            lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
            body.append(f"Line count: {len(lines)}")
            for idx, ln in enumerate(lines, start=1):
                if re.search(r"http|curl|subprocess|except|unlink|replace\(|LASTEXITCODE|flutter build|git |key|sign|TODO|FIXME|eval|os\.system", ln, re.I):
                    body.append(f"  L{idx:3d}: {ln}")
        body.append("")
    write_scan(
        "20-tooling.txt",
        [
            "# Scan 20: Tooling scripts (tool/place_book/* and scripts/build-and-archive.*)",
            "# Command: python docs/audits/AUDIT-001/scripts/run_phase1_scans.py (scan_20_tooling)",
        ],
        body,
    )


def scan_21_tests():
    test_files = [f for f in git_ls("test") if f.endswith(".dart")] + ["tool/ux_screenshots_test.dart"]
    no_expect = []
    long_delays = []
    skipped = []
    clock_goldens = []
    for f in test_files:
        text = pathlib.Path(f).read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        i = 0
        n = len(lines)
        while i < n:
            m = re.match(r"^\s*(test|testWidgets)\s*\(\s*(['\"].*?['\"])", lines[i])
            if m:
                start = i
                depth = 0
                started = False
                k = i
                while k < n:
                    code = re.sub(r"//.*", "", lines[k])
                    for ch in code:
                        if ch == "(":
                            depth += 1
                            started = True
                        elif ch == ")":
                            depth -= 1
                    if started and depth <= 0:
                        break
                    k += 1
                block_text = "\n".join(lines[start:k + 1])
                if "expect(" not in block_text and "expectLater(" not in block_text and "fail(" not in block_text:
                    no_expect.append(f"{f}:{start + 1}-{k + 1} {m.group(1)}({m.group(2)})")
                if re.search(r"\bskip\s*:", block_text):
                    skipped.append(f"{f}:{start + 1} {m.group(2)}")
                i = k + 1
            else:
                i += 1
        for idx, ln in enumerate(lines, start=1):
            if re.search(r"Future\.delayed\(|pump\(\s*const\s+Duration\(|pump\(\s*Duration\(|pumpAndSettle\(\s*const\s+Duration\(|sleep\(", ln):
                long_delays.append(f"{f}:{idx}: {ln.strip()}")
            if "DateTime.now(" in ln and ("golden" in text.lower() or "ux_screenshots" in f):
                clock_goldens.append(f"{f}:{idx}: {ln.strip()}")
    body = [
        f"Test files scanned: {len(test_files)}",
        "",
        f"=== TESTS WITHOUT DIRECT expect()/expectLater() CALL ({len(no_expect)}) ===",
        *no_expect,
        "",
        f"=== Future.delayed / FIXED DURATION pump CALLS ({len(long_delays)}) ===",
        *long_delays,
        "",
        f"=== SKIPPED TESTS ({len(skipped)}) ===",
        *skipped,
        "",
        f"=== GOLDENS / SCREENSHOT TESTS USING DateTime.now() ({len(clock_goldens)}) ===",
        *clock_goldens,
    ]
    write_scan(
        "21-tests.txt",
        [
            "# Scan 21: Test quality scan (missing expect, delays/fixed pumps, skipped tests, clock-bound goldens)",
            "# Command: python docs/audits/AUDIT-001/scripts/run_phase1_scans.py (scan_21_tests)",
        ],
        body,
    )


def main():
    scan_03_dependencies()
    scan_04_assets()
    pattern_scan("06-catch.txt", "Scan 06: Exception catch / error handlers in lib/", r"catch \(|on [A-Z][A-Za-z]+ catch|\.catchError\(|onError:", ["lib"])
    pattern_scan("07-null-and-late.txt", "Scan 07: Null assertion (!) and late declarations in lib/", r"[A-Za-z0-9_\)\]]!(\.|\)|;|,| )|\blate\b", ["lib"], extra_fn=per_file_counts)
    pattern_scan("08-dynamic-and-casts.txt", "Scan 08: dynamic types and explicit casts in lib/", r"\bdynamic\b|\bas [A-Z]|as Map|as List", ["lib"])
    scan_09_async_gaps()
    scan_10_lifecycle()
    scan_11_sql_and_fts()
    pattern_scan("12-files.txt", "Scan 12: File and directory operations in lib/", r"File\(|Directory\(|\.delete\(|\.rename\(|\.copy\(|writeAsBytes|readAsBytes|getApplicationDocumentsDirectory|getTemporaryDirectory|path\.join|p\.join", ["lib"])
    pattern_scan("13-network.txt", "Scan 13: Network URLs, HTTP clients, and TileLayer in lib/", r"Uri\.parse|https?://|userAgentPackageName|TileLayer|NetworkTileProvider|HttpClient", ["lib"])
    pattern_scan("14-debug-and-markers.txt", "Scan 14: Debug calls, assertions, TODO/FIXME/HACK/XXX, analyzer ignores in lib, test, tool", r"print\(|debugPrint\(|kDebugMode|assert\(|TODO|FIXME|HACK|XXX|// ignore|ignore_for_file", ["lib", "test", "tool"])
    pattern_scan("15-hardcoded-style.txt", "Scan 15: Hardcoded Color/Colors/EdgeInsets/Duration/fontSize outside lib/app/theme/", r"Color\(0x|Colors\.|EdgeInsets\.(all|only|symmetric)\([0-9]|Duration\((milliseconds|seconds): [0-9]|fontSize: [0-9]", ["lib"], exclude_prefixes=("lib/app/theme/",), extra_fn=per_file_counts)
    pattern_scan("16-time-and-random.txt", "Scan 16: DateTime.now() and Random() across lib, test, tool", r"DateTime\.now\(\)|Random\(", ["lib", "test", "tool"], extra_fn=per_file_counts)
    scan_19_android()
    scan_20_tooling()
    scan_21_tests()


if __name__ == "__main__":
    main()
