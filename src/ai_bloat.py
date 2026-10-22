#!/usr/bin/env python3
"""AI tool bloat report and cleanup for Codex, Claude Code and Cursor.

Default is a read-only report. --execute removes only regenerable caches, logs
and crash reports, after a typed confirmation (or DEVPURGE_YES=true).
Sessions, projects, settings, auth and history are reported or skipped, never deleted.
"""
import argparse
import fnmatch
import importlib.util
import json
import os
import re
import shutil
import sys

_spec = importlib.util.spec_from_file_location(
    "devpurge_safety", os.path.join(os.path.dirname(os.path.abspath(__file__)), "safety.py"))
safety = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(safety)
_units_spec = importlib.util.spec_from_file_location(
    "devpurge_units", os.path.join(os.path.dirname(os.path.abspath(__file__)), "units.py"))
units = importlib.util.module_from_spec(_units_spec)
_units_spec.loader.exec_module(units)

CONFIRM_PHRASE = "clean ai"
CRASH_PATTERN = re.compile(r"codex|cursor|claude", re.IGNORECASE)

# Names that are never removable, wherever they appear in a path.
NEVER_DELETE_NAMES = {
    "auth.json", "config.toml", "history.jsonl", "settings.json", "settings.local.json",
    "credentials.json", ".credentials.json", "User", "workspaceStorage", "globalStorage",
    "extensions", "projects", "memories", "sessions", "archived_sessions", "worktrees",
    "CLAUDE.md", "AGENTS.md", "Local Storage", "Cookies",
}
NEVER_DELETE_GLOBS = ("*.sqlite", "*.sqlite-*", "*.db", "*.env", ".env*", "*.pem", "*.key",
                      "settings*.json", "config.toml*", "*history*")

_AS = "Library/Application Support"
_CHROMIUM_CACHES = ("Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache",
                    "GrShaderCache", "GraphiteDawnCache", "Crashpad")

# (tool, label, path relative to HOME, kind) where kind is "cache" (eligible) or "report".
TARGETS = (
    [("Codex", "CLI cache", ".codex/cache", "cache"),
     ("Codex", "CLI log dir", ".codex/log", "cache"),
     ("Codex", "app caches", "Library/Caches/com.openai.codex", "cache"),
     ("Codex", "app logs", "Library/Logs/Codex", "cache")]
    + [("Codex", "app " + n, _AS + "/Codex/" + n, "cache") for n in _CHROMIUM_CACHES]
    + [("Codex", "sessions (history, report only)", ".codex/sessions", "report"),
       ("Codex", "archived sessions (report only)", ".codex/archived_sessions", "report"),
       ("Codex", "worktrees (report only)", ".codex/worktrees", "report"),
       ("Codex", "generated images (report only)", ".codex/generated_images", "report"),
       ("Codex", "logs database (in use, report only)", ".codex/logs_2.sqlite", "report"),
       ("Claude Code", "cache", ".claude/cache", "cache"),
       ("Claude Code", "paste cache", ".claude/paste-cache", "cache"),
       ("Claude Code", "shell snapshots", ".claude/shell-snapshots", "cache"),
       ("Claude Code", "projects/transcripts (report only)", ".claude/projects", "report"),
       ("Claude Code", "file history (report only)", ".claude/file-history", "report"),
       ("Cursor", "caches (com.todesktop)", "Library/Caches/com.todesktop.230313mzl4w4u92", "cache")]
    + [("Cursor", n, _AS + "/Cursor/" + n, "cache")
       for n in ("Cache", "CachedData", "GPUCache", "Code Cache", "CachedExtensionVSIXs", "logs", "Crashpad")]
    + [("Cursor", "User settings/state (never deleted)", _AS + "/Cursor/User", "report")]
)


def refusal_reason(path, home):
    """Return why a path must never be deleted by AI mode, or None if eligible."""
    reason = safety.protected_reason(path, home)
    if reason:
        return reason
    for part in os.path.normpath(str(path)).split(os.sep):
        if part in NEVER_DELETE_NAMES:
            return "auth/config/history/state: " + part
        for pattern in NEVER_DELETE_GLOBS:
            if fnmatch.fnmatch(part, pattern):
                return "auth/config/history/state: " + part
    return None


def _allocated(st):
    # st_blocks counts 512-byte units actually on disk (what du reports). st_size is the
    # logical length: a sparse VM disk can claim 995 GB while using 66 GB.
    blocks = getattr(st, "st_blocks", None)
    return blocks * 512 if blocks is not None else st.st_size


def size_of(path):
    """Space on disk under path: allocated blocks, hard links counted once, links not followed."""
    if os.path.islink(path):
        return 0
    try:
        if os.path.isfile(path):
            return _allocated(os.lstat(path))
    except OSError:
        return 0
    total, seen = 0, set()
    for root, _dirs, files in os.walk(path):
        for name in files:
            try:
                st = os.lstat(os.path.join(root, name))
            except OSError:
                continue
            if st.st_nlink > 1:
                if (st.st_dev, st.st_ino) in seen:
                    continue
                seen.add((st.st_dev, st.st_ino))
            total += _allocated(st)
    return total


def human(n):
    # Kept as a name for agents.py; decimal units shared with the GUI and Mac app.
    return units.fmt_bytes(n)


def scan(home):
    items = []
    for tool, label, rel, kind in TARGETS:
        path = os.path.join(home, rel)
        if not os.path.lexists(path):
            continue
        reason = refusal_reason(path, home) if kind == "cache" else "report only"
        items.append({"tool": tool, "label": label, "path": path, "bytes": size_of(path),
                      "eligible": kind == "cache" and reason is None, "reason": reason})
    crash_dir = os.path.join(home, "Library/Logs/DiagnosticReports")
    if os.path.isdir(crash_dir):
        for name in sorted(os.listdir(crash_dir)):
            m = CRASH_PATTERN.search(name)
            if not m:
                continue
            tool = {"codex": "Codex", "cursor": "Cursor", "claude": "Claude Code"}[m.group(0).lower()]
            path = os.path.join(crash_dir, name)
            reason = refusal_reason(path, home)
            items.append({"tool": tool, "label": "crash report " + name, "path": path,
                          "bytes": size_of(path), "eligible": reason is None, "reason": reason})
    return items


def print_report(items):
    for tool in ("Codex", "Claude Code", "Cursor"):
        rows = [i for i in items if i["tool"] == tool]
        eligible = sum(i["bytes"] for i in rows if i["eligible"])
        print("[%s] reclaimable caches/logs/crash reports: %s" % (tool, human(eligible)))
        for i in rows:
            tag = "eligible" if i["eligible"] else "keep"
            print("  %9s  %-8s %s" % (human(i["bytes"]), tag, i["label"]))
    total = sum(i["bytes"] for i in items if i["eligible"])
    print("Total reclaimable: %s (sizes are on-disk estimates)" % human(total))


def confirmed():
    if os.environ.get("DEVPURGE_YES") == "true":
        return True
    if not sys.stdin.isatty():
        print("AI cleanup needs confirmation: rerun with --yes or type '%s' interactively." % CONFIRM_PHRASE,
              file=sys.stderr)
        return False
    answer = input("Type '%s' to delete the eligible items above: " % CONFIRM_PHRASE)
    return answer.strip() == CONFIRM_PHRASE


def execute(items, home):
    failures = 0
    for i in items:
        if not i["eligible"]:
            continue
        reason = refusal_reason(i["path"], home)  # re-check right before deleting
        if reason:
            print("  - [REFUSED] %s: %s" % (i["label"], reason), file=sys.stderr)
            failures += 1
            continue
        try:
            if os.path.isdir(i["path"]) and not os.path.islink(i["path"]):
                shutil.rmtree(i["path"])
            else:
                os.remove(i["path"])
            print("  - Removed %s %s (%s)" % (i["tool"], i["label"], human(i["bytes"])))
        except OSError as exc:
            print("  - [FAILED] %s: %s" % (i["label"], exc), file=sys.stderr)
            failures += 1
    return failures


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    home = os.path.expanduser("~")
    items = scan(home)
    if args.json:
        print(json.dumps(items, indent=2))
        return 0
    print_report(items)
    if not args.execute:
        print("Dry run: nothing deleted.")
        return 0
    if not any(i["eligible"] for i in items):
        return 0
    if not confirmed():
        return 1
    return 1 if execute(items, home) else 0


if __name__ == "__main__":
    sys.exit(main())
