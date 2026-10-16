#!/usr/bin/env python3
"""Agent leftovers: stale worktrees, duplicate clones and caches from parallel
Claude Code, Codex, OpenCode (and Kilo/Clawdbot) runs.  DevPurge Pro feature.

Default is a read-only report.  --execute removes only:
  * agent-made worktrees that are clean, have no stash, are fully pushed and older
    than --days, using `git worktree remove` (never --force) then `git worktree prune`;
  * worktree records whose directory is already gone (`git worktree prune`);
  * regenerable OpenCode logs/tool output;
after typing 'remove agent leftovers' (or DEVPURGE_YES=true).
Duplicate clones are deleted only when clean, fully pushed and identical to a clone
that is kept, and each one needs its own typed name at an interactive prompt.
Everything else is report only.
"""
import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import time

_here = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("devpurge_safety", os.path.join(_here, "safety.py"))
safety = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(safety)
_spec = importlib.util.spec_from_file_location("devpurge_ai_bloat", os.path.join(_here, "ai_bloat.py"))
ai_bloat = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ai_bloat)

CONFIRM_PHRASE = "remove agent leftovers"
DEFAULT_ROOTS = ("Desktop/404 Projects", "Projects", "Developer", "code", "src", "dev", "repos")
# Path markers that show a worktree was created by an agent tool.
AGENT_MARKERS = (("/.claude/worktrees/", "Claude Code"), ("/.codex/worktrees/", "Codex"),
                 ("/opencode/", "OpenCode"), ("/.kilo/worktrees/", "Kilo"),
                 ("/.clawdbot/worktrees/", "Clawdbot"))
CACHES = ((".local/share/opencode/log", "OpenCode logs", "cache"),
          (".local/share/opencode/tool-output", "OpenCode tool output", "cache"),
          (".local/share/opencode/snapshot", "OpenCode snapshots (undo history, report only)", "report"),
          (".local/share/opencode/repos", "OpenCode repo copies (report only)", "report"))


def git(path, *args):
    r = subprocess.run(["git", "-C", path, *args], capture_output=True, text=True)
    return r.returncode, r.stdout.strip()


def agent_of(path):
    p = path.replace(os.sep, "/") + "/"
    for marker, tool in AGENT_MARKERS:
        if marker in p:
            return tool
    return None


def find_repos(home, roots):
    repos = []
    for root in roots:
        root = os.path.join(home, root)
        if not os.path.isdir(root):
            continue
        for name in sorted(os.listdir(root)):
            path = os.path.join(root, name)
            if os.path.isdir(os.path.join(path, ".git")):  # a real clone, not a worktree
                repos.append(os.path.realpath(path))
    return repos


def worktrees(repo):
    code, out = git(repo, "worktree", "list", "--porcelain")
    items, cur = [], None
    for line in out.splitlines() if code == 0 else []:
        key, _, value = line.partition(" ")
        if key == "worktree":
            cur = {"path": value}
            items.append(cur)
        elif cur is not None:
            cur[key] = value or True
    return items[1:]  # first entry is the main worktree


def unsafe_reason(path):
    """Why a checkout must be kept: uncommitted/untracked work, stash or unpushed commits."""
    code, out = git(path, "status", "--porcelain")
    if code != 0:
        return "git status failed"
    if out:
        return "uncommitted or untracked changes"
    branch = git(path, "rev-parse", "--abbrev-ref", "HEAD")[1]
    _, stashes = git(path, "stash", "list")
    label = "(no branch)" if branch == "HEAD" else branch
    if any((" on %s:" % label).lower() in s.lower() for s in stashes.splitlines()):
        return "has a stash"
    code, ahead = git(path, "rev-list", "--count", "@{u}..HEAD")
    if code == 0:
        return "unpushed commits" if ahead != "0" else None
    _, remotes = git(path, "branch", "-r", "--contains", "HEAD")
    return None if remotes else "commits not on any remote"


def age_days(path):
    code, out = git(path, "log", "-1", "--format=%ct")
    newest = max(int(out) if code == 0 and out.isdigit() else 0, os.path.getmtime(path))
    return (time.time() - newest) / 86400


def scan_worktrees(home, repos, days):
    items, seen = [], set()
    for repo in repos:
        for wt in worktrees(repo):
            path = wt["path"]
            if path in seen:
                continue
            seen.add(path)
            item = {"kind": "worktree", "repo": repo, "path": path, "tool": agent_of(path),
                    "bytes": 0, "eligible": False, "action": None}
            if wt.get("prunable") or not os.path.isdir(path):
                item.update(eligible=True, action="prune", reason="directory gone; prune record only")
            elif wt.get("locked"):
                item["reason"] = "locked"
            elif safety.protected_reason(path, home):
                item["reason"] = "protected: " + safety.protected_reason(path, home)
            elif not item["tool"]:
                item["reason"] = "not made by a known agent tool (report only)"
            else:
                item["bytes"] = ai_bloat.size_of(path)
                item["reason"] = unsafe_reason(path)
                if not item["reason"] and age_days(path) < days:
                    item["reason"] = "active in the last %d days" % days
                item["eligible"] = item["reason"] is None
                item["action"] = "remove" if item["eligible"] else None
            items.append(item)
    return items


def scan_orphans(home, registered):
    """Codex worktree folders that no repo still lists: report only."""
    items, base = [], os.path.join(home, ".codex/worktrees")
    for name in sorted(os.listdir(base)) if os.path.isdir(base) else []:
        path = os.path.join(base, name)
        if not any(r == path or r.startswith(path + os.sep) for r in registered):
            items.append({"kind": "orphan", "path": path, "tool": "Codex", "bytes": ai_bloat.size_of(path),
                          "eligible": False, "action": None, "reason": "not a registered worktree (report only)"})
    return items


def scan_clones(home, repos):
    groups = {}
    for repo in repos:
        code, url = git(repo, "remote", "get-url", "origin")
        if code == 0 and url:
            key = url.lower().rstrip("/").removesuffix(".git").replace("git@github.com:", "https://github.com/")
            groups.setdefault(key, []).append(repo)
    items = []
    for url, paths in groups.items():
        if len(paths) < 2:
            continue
        info = []
        for p in paths:
            reason = unsafe_reason(p)
            if not reason and git(p, "log", "--branches", "--not", "--remotes", "--oneline")[1]:
                reason = "local branches with unpushed commits"
            if not reason and git(p, "stash", "list")[1]:
                reason = "has a stash"
            info.append((p, reason, git(p, "rev-parse", "HEAD")[1]))
        kept = set()
        for p, reason, head in sorted(info, key=lambda x: len(x[0])):
            twin = any(k != p and h == head for k, r, h in info if r is None and k in kept)
            item = {"kind": "clone", "path": p, "remote": url, "tool": None, "bytes": ai_bloat.size_of(p),
                    "eligible": False, "action": None, "reason": reason}
            if reason is None and twin and not safety.protected_reason(p, home):
                item.update(eligible=True, action="delete-clone")
            elif reason is None:
                kept.add(p)
                item["reason"] = "kept copy" if not twin else "protected path"
            items.append(item)
    return items


def scan_caches(home):
    items = []
    for rel, label, kind in CACHES:
        path = os.path.join(home, rel)
        if os.path.lexists(path):
            reason = ai_bloat.refusal_reason(path, home) if kind == "cache" else "report only"
            items.append({"kind": "cache", "path": path, "tool": "OpenCode", "label": label,
                          "bytes": ai_bloat.size_of(path), "eligible": reason is None,
                          "action": "delete" if reason is None else None, "reason": reason})
    return items


def scan(home, roots=DEFAULT_ROOTS, days=7):
    repos = find_repos(home, roots)
    wts = scan_worktrees(home, repos, days)
    return wts + scan_orphans(home, [w["path"] for w in wts]) + scan_clones(home, repos) + scan_caches(home)


def print_report(items):
    for kind, title in (("worktree", "Worktrees"), ("orphan", "Unregistered Codex worktree folders"),
                        ("clone", "Duplicate clones"), ("cache", "Agent caches")):
        rows = [i for i in items if i["kind"] == kind]
        print("[%s] %d found, %s eligible" % (title, len(rows),
                                              ai_bloat.human(sum(i["bytes"] for i in rows if i["eligible"]))))
        for i in rows:
            tag = i["action"] if i["eligible"] else "keep"
            print("  %7s  %-12s %s%s" % (ai_bloat.human(i["bytes"]), tag, i["path"],
                                        "" if i["eligible"] else "  (%s)" % i["reason"]))
    print("Dry run is the default. Duplicate clones always need a typed name per clone.")


def execute(items, home, interactive):
    failures = 0
    for i in items:
        if not i["eligible"]:
            continue
        path = i["path"]
        if i["action"] == "prune":
            ok = git(i["repo"], "worktree", "prune")[0] == 0
        elif i["action"] == "remove":
            reason = unsafe_reason(path) or safety.protected_reason(path, home)  # re-check
            if reason:
                print("  - [REFUSED] %s: %s" % (path, reason), file=sys.stderr)
                failures += 1
                continue
            ok = git(i["repo"], "worktree", "remove", path)[0] == 0 and git(i["repo"], "worktree", "prune")[0] == 0
        elif i["action"] == "delete":
            reason = ai_bloat.refusal_reason(path, home)
            ok = reason is None
            if ok:
                shutil.rmtree(path) if os.path.isdir(path) else os.remove(path)
        elif i["action"] == "delete-clone":
            if not interactive:
                print("  - [SKIPPED] clone %s: needs an interactive typed confirmation" % path)
                continue
            if input("Type the folder name '%s' to delete this clone: " % os.path.basename(path)).strip() \
                    != os.path.basename(path):
                print("  - [SKIPPED] clone %s" % path)
                continue
            ok = not (unsafe_reason(path) or safety.protected_reason(path, home))
            if ok:
                shutil.rmtree(path)
        print(("  - Done: %s %s" if ok else "  - [FAILED] %s %s") % (i["action"], path),
              file=sys.stdout if ok else sys.stderr)
        failures += 0 if ok else 1
    return failures


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--days", type=int, default=7, help="treat worktrees idle this long as stale")
    args = parser.parse_args(argv)
    home = os.path.expanduser("~")
    roots = os.environ.get("DEVPURGE_AGENT_ROOTS")
    items = scan(home, roots.split(os.pathsep) if roots else DEFAULT_ROOTS, args.days)
    if args.json:
        print(json.dumps(items, indent=2))
        return 0
    print_report(items)
    if not args.execute or not any(i["eligible"] for i in items):
        print("Dry run: nothing deleted." if not args.execute else "Nothing eligible.")
        return 0
    interactive = sys.stdin.isatty()
    if os.environ.get("DEVPURGE_YES") != "true":
        if not interactive or input("Type '%s' to continue: " % CONFIRM_PHRASE).strip() != CONFIRM_PHRASE:
            print("Agent cleanup needs confirmation: rerun with --yes or type '%s'." % CONFIRM_PHRASE,
                  file=sys.stderr)
            return 1
    return 1 if execute(items, home, interactive) else 0


if __name__ == "__main__":
    sys.exit(main())
