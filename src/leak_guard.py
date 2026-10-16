#!/usr/bin/env python3
"""Secret-leak guard (DevPurge Pro). Matches file names and paths only; never opens files.

  leak_guard.py check [PATH]       scan deploy/build output folders under PATH (default .)
  leak_guard.py staged             check files staged in the current git repo
  leak_guard.py pre-deploy [--cursor]  agent hook: read hook JSON on stdin, block deploy commands
                                   when output folders hold secret-looking files (exit 2)
  leak_guard.py install-git-hook [REPO]   write .git/hooks/pre-commit (refuses to overwrite)
  leak_guard.py print-config claude|codex|cursor   print an agent hook config; writes nothing

Exit 0 clean, 1 findings (2 for pre-deploy blocks), 3 usage or install refusal.
"""
import importlib.util
import json
import os
import re
import subprocess
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("devpurge_agents", os.path.join(_here, "agents.py"))
agents = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(agents)

# Templates meant to be committed and published.
ALLOWED = (".env.example", ".env.sample", ".env.template")
OUTPUT_DIRS = {"dist", "build", "out", ".vercel", ".netlify", ".next", "public", ".output", ".wrangler",
               "functions"}
SKIP_DIRS = {".git", "node_modules"}
DEPLOY_RE = re.compile(r"\b(wrangler(@\S+)?\s+((pages|versions)\s+)?(deploy|publish)|vercel(@\S+)?(\s|$)|"
                       r"netlify(-cli)?(@\S+)?\s+deploy|firebase(-tools)?(@\S+)?\s+deploy)")
CD_RE = re.compile(r"(?:^|[;&|(]\s*)cd\s+(\"[^\"]+\"|'[^']+'|[^\s;&|)]+)")
HOOK_MARKER = "# devpurge leak-guard"


def looks_secret(name):
    return os.path.basename(name) not in ALLOWED and agents.looks_secret(name)


def scan_outputs(root):
    """Paths (relative to root) of secret-looking files inside output folders. Names only."""
    found = []
    for top, dirs, _files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for d in [d for d in dirs if d in OUTPUT_DIRS]:
            for sub, subdirs, files in os.walk(os.path.join(top, d)):
                subdirs[:] = [s for s in subdirs if s != ".git"]
                found += [os.path.relpath(os.path.join(sub, f), root) for f in files if looks_secret(f)]
        dirs[:] = [d for d in dirs if d not in OUTPUT_DIRS]
    return sorted(found)


def staged(repo="."):
    r = subprocess.run(["git", "-C", repo, "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR"],
                       capture_output=True, text=True)
    return [p for p in r.stdout.split("\0") if p and looks_secret(p)]


def report(found, what):
    for p in found:
        print("  secret-looking file %s: %s" % (what, p))
    print(("%d secret-looking file(s) found." % len(found)) if found else "No secret-looking files found.")


def pre_deploy(stdin, cursor=False):
    """Exit 0 to allow, 2 to block. Unreadable hook input blocks (fail closed)."""
    def decide(allow, message=""):
        if cursor:
            out = {"permission": "allow"} if allow else \
                {"permission": "deny", "user_message": message, "agent_message": message}
            print(json.dumps(out))
        if not allow:
            print(message, file=sys.stderr)
        return 0 if allow else 2
    try:
        event = json.loads(stdin)
        command = (event.get("tool_input") or {}).get("command") or event.get("command") or ""
        if not isinstance(command, str):
            raise ValueError
    except (ValueError, AttributeError):
        return decide(False, "DevPurge leak guard could not read the hook input, so it blocked the command.")
    if not DEPLOY_RE.search(command):
        return decide(True)
    roots = event.get("workspace_roots") or []
    base = event.get("cwd") or (roots[0] if roots else os.getcwd())
    targets = [base] + [os.path.join(base, os.path.expanduser(d.strip("'\""))) for d in CD_RE.findall(command)]
    found = sorted({os.path.join(os.path.relpath(t, base), f) if t != base else f
                    for t in targets if os.path.isdir(t) for f in scan_outputs(t)})
    if not found:
        return decide(True)
    return decide(False, "DevPurge leak guard blocked this deploy: secret-looking files in build output: %s. "
                  "Remove them from the output and retry." % ", ".join(found[:10]))


def install_git_hook(repo, dry_run=False):
    r = subprocess.run(["git", "-C", repo, "rev-parse", "--git-path", "hooks"], capture_output=True, text=True)
    if r.returncode != 0:
        print("Not a git repository: %s" % repo, file=sys.stderr)
        return 3
    hooks = os.path.join(repo, r.stdout.strip())
    path = os.path.join(hooks, "pre-commit")
    if os.path.exists(path) and HOOK_MARKER not in open(path).read():
        print("Refusing to overwrite existing %s; add this line to it instead:\n  python3 %s staged"
              % (path, os.path.abspath(__file__)), file=sys.stderr)
        return 3
    if dry_run:
        print("Dry run: would write %s; nothing written." % path)
        return 0
    os.makedirs(hooks, exist_ok=True)
    with open(path, "w") as f:
        f.write("#!/bin/sh\n%s\nexec python3 '%s' staged\n" % (HOOK_MARKER, os.path.abspath(__file__)))
    os.chmod(path, 0o755)
    print("Installed %s. Bypass once with git commit --no-verify." % path)
    return 0


def print_config(tool):
    cmd = "python3 '%s' pre-deploy%s" % (os.path.abspath(__file__), " --cursor" if tool == "cursor" else "")
    if tool == "claude":  # .claude/settings.json
        conf = {"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": cmd}]}]}}
    elif tool == "codex":  # ~/.codex/hooks.json or <repo>/.codex/hooks.json
        conf = {"hooks": {"PreToolUse": [{"matcher": "^Bash$", "hooks": [{"type": "command", "command": cmd}]}]}}
    elif tool == "cursor":  # .cursor/hooks.json
        conf = {"version": 1, "hooks": {"beforeShellExecution": [
            {"command": cmd, "matcher": DEPLOY_RE.pattern, "failClosed": True}]}}
    else:
        print("print-config takes claude, codex or cursor", file=sys.stderr)
        return 3
    print(json.dumps(conf, indent=2))
    return 0


def main(argv):
    cmd, args = (argv[1], argv[2:]) if len(argv) > 1 else ("check", [])
    if cmd == "check":
        if args and not os.path.isdir(args[0]):
            print("Not a directory: %s" % args[0], file=sys.stderr)
            return 3
        found = scan_outputs(args[0] if args else ".")
        report(found, "in build output")
        return 1 if found else 0
    if cmd == "staged":
        found = staged()
        report(found, "staged")
        if found:
            print("Commit blocked by DevPurge leak guard. Unstage with git restore --staged <file>.",
                  file=sys.stderr)
        return 1 if found else 0
    if cmd == "pre-deploy":
        return pre_deploy(sys.stdin.read(), cursor="--cursor" in args)
    if cmd == "install-git-hook":
        paths = [a for a in args if a != "--dry-run"]
        return install_git_hook(paths[0] if paths else ".", dry_run="--dry-run" in args)
    if cmd == "print-config" and args:
        return print_config(args[0])
    print(__doc__, file=sys.stderr)
    return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
