#!/usr/bin/env python3
"""Leaked-key sweep (DevPurge Pro). Report only: no deletion, no network.

Reads local .env files and agent config folders in this process to pattern-match provider
API keys. Prints provider, file, line and a masked value (first 4 and last 2 characters).
Full values are never printed, logged or stored. Found keys are never sent anywhere.

Usage: key_sweep.py [--json]      exit 0 nothing found, 1 keys found
"""
import argparse
import importlib.util
import json
import os
import re
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("devpurge_agents", os.path.join(_here, "agents.py"))
agents = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(agents)

AGENT_DIRS = (".codex", ".claude", ".config/opencode", ".local/share/opencode", ".cursor", ".config/aider")
# History, transcripts, caches and checkouts: too large to read; counted as skipped.
SKIP_DIRS = {"sessions", "archived_sessions", "projects", "file-history", "worktrees", "cache", "caches",
             "node_modules", ".git", "logs", "log", "snapshot", "repos", "tool-output", "extensions",
             "shell-snapshots", "paste-cache", "plugins"}
MAX_BYTES = 1024 * 1024
TEXT_EXT = (".json", ".jsonc", ".toml", ".yaml", ".yml", ".env", ".ini", ".conf", ".cfg", ".txt", ".sh",
            ".zsh", ".md")
ENV_DEPTH = 4

# Order matters: more specific prefixes first. Each pattern's group 1 is the key.
PATTERNS = (
    ("Anthropic", re.compile(r"\b(sk-ant-[A-Za-z0-9_-]{20,})")),
    ("OpenRouter", re.compile(r"\b(sk-or-[A-Za-z0-9_-]{20,})")),
    ("OpenAI", re.compile(r"\b(sk-(?!ant-|or-)(?:proj-|svcacct-|admin-)?[A-Za-z0-9_-]{20,})")),
    ("Google/Gemini", re.compile(r"\b(AIza[0-9A-Za-z_-]{35})")),
    ("xAI", re.compile(r"\b(xai-[A-Za-z0-9_-]{20,})")),
    ("Groq", re.compile(r"\b(gsk_[A-Za-z0-9]{20,})")),
    ("Mistral", re.compile(r"MISTRAL_API_KEY[\"']?\s*[=:]\s*[\"']?([A-Za-z0-9]{20,})")),
    ("AWS", re.compile(r"\b((?:AKIA|ASIA)[0-9A-Z]{16})\b")),
    ("AWS", re.compile(r"AWS_SECRET_ACCESS_KEY[\"']?\s*[=:]\s*[\"']?([A-Za-z0-9/+]{40})")),
    ("GitHub", re.compile(r"\b((?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})")),
    ("Stripe", re.compile(r"\b((?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,})")),
    ("Cloudflare", re.compile(r"(?:CLOUDFLARE_API_TOKEN|CF_API_TOKEN|CLOUDFLARE_API_KEY)[\"']?\s*[=:]\s*[\"']?"
                              r"([A-Za-z0-9_-]{37,})")),
)

# Official dashboards. Spend-cap notes are guidance only: DevPurge can't see account settings.
PROVIDERS = {
    "OpenAI": ("https://platform.openai.com/api-keys",
               "Set a monthly budget and alerts at https://platform.openai.com/settings/organization/limits"),
    "Anthropic": ("https://console.anthropic.com/settings/keys",
                  "Set spend limits at https://console.anthropic.com/settings/limits"),
    "Google/Gemini": ("https://aistudio.google.com/app/apikey",
                      "Restrict the key and set a billing budget in Google Cloud "
                      "(https://console.cloud.google.com/apis/credentials)"),
    "xAI": ("https://console.x.ai", "Check the team's spending limit in the xAI console"),
    "OpenRouter": ("https://openrouter.ai/settings/keys", "Give each key a credit limit on that page"),
    "Groq": ("https://console.groq.com/keys", "Check usage limits in the Groq console"),
    "Mistral": ("https://console.mistral.ai/api-keys", "Check workspace usage limits in the Mistral console"),
    "AWS": ("https://console.aws.amazon.com/iam/home#/security_credentials",
            "Set AWS Budgets alerts; prefer short-lived credentials over access keys"),
    "GitHub": ("https://github.com/settings/tokens", "Prefer fine-grained tokens with an expiry"),
    "Stripe": ("https://dashboard.stripe.com/apikeys",
               "Roll the key there; use restricted keys (rk_) with the fewest permissions"),
    "Cloudflare": ("https://dash.cloudflare.com/profile/api-tokens",
                   "Roll the token there; scope tokens to one zone and permission"),
}
STEPS = ("1. Create a new key at %s and update the apps that use it.",
         "2. Revoke (delete) the old key on the same page. Editing the file does not revoke it.",
         "3. Remove the old value from the file listed above, then review recent usage for anything unexpected.",
         "4. %s.")


def mask(value):
    if len(value) < 12:
        return value[:2] + "…"
    return value[:4] + "…" + value[-2:]


def is_env_name(name):
    return (name == ".env" or name == ".envrc" or name.startswith(".env.")) and \
        not name.endswith(agents.TEMPLATE_SUFFIXES + (".dist",))


def candidate_files(home, roots):
    """(files to read, count of skipped large/history paths)."""
    files, skipped = [], 0
    bases = [os.path.join(home, d) for d in AGENT_DIRS]
    bases += [os.path.join(home, n) for n in sorted(os.listdir(home)) if n.startswith(".aider")] \
        if os.path.isdir(home) else []
    for base in bases:
        if os.path.isfile(base):
            files.append(base)
            continue
        for top, dirs, names in os.walk(base):
            skipped += sum(1 for d in dirs if d in SKIP_DIRS)
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
            for n in sorted(names):
                p = os.path.join(top, n)
                if not (n.endswith(TEXT_EXT) or is_env_name(n)) or os.path.islink(p):
                    continue
                if os.path.getsize(p) > MAX_BYTES:
                    skipped += 1
                    continue
                files.append(p)
    for root in [os.path.join(home, r) for r in roots] + [home]:
        if not os.path.isdir(root):
            continue
        depth0 = root.rstrip(os.sep).count(os.sep)
        for top, dirs, names in os.walk(root):
            if root == home:
                dirs[:] = []  # only ~/.env* at the top of home
            elif top.count(os.sep) - depth0 >= ENV_DEPTH:
                dirs[:] = []
            dirs[:] = sorted(d for d in dirs if d not in agents.DEPENDENCY_DIRS and d != ".git")
            files += [os.path.join(top, n) for n in sorted(names) if is_env_name(n)
                      and not os.path.islink(os.path.join(top, n))]
    return sorted(set(files)), skipped


def scan_file(path):
    """Findings for one file. Full values exist only inside this function."""
    found = []
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            for lineno, line in enumerate(f, 1):
                seen = set()
                for provider, pattern in PATTERNS:
                    for m in pattern.finditer(line):
                        key = m.group(1)
                        if key in seen or any(s.startswith(key) or key.startswith(s) for s in seen):
                            continue
                        seen.add(key)
                        found.append({"provider": provider, "file": path, "line": lineno, "masked": mask(key)})
    except OSError:
        pass
    return found


def sweep(home, roots):
    files, skipped = candidate_files(home, roots)
    findings = [f for p in files for f in scan_file(p)]
    return findings, len(files), skipped


def print_report(findings, nfiles, skipped):
    print("Leaked-key sweep: read %d files locally; skipped %d large or history paths. No network calls."
          % (nfiles, skipped))
    if not findings:
        print("No provider API keys found.")
        return
    for f in findings:
        print("  %-14s %s:%d  %s" % (f["provider"], f["file"], f["line"], f["masked"]))
    print("\n%d key(s) found. Treat any key stored in a file an agent tool can read as exposed." % len(findings))
    for provider in sorted({f["provider"] for f in findings}):
        url, cap = PROVIDERS[provider]
        print("\n[%s] rotate at %s" % (provider, url))
        print("  " + STEPS[0] % url)
        print("  " + STEPS[1])
        print("  " + STEPS[2])
        print("  " + STEPS[3] % ("Spend cap (guidance; DevPurge cannot check your account): " + cap))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    home = os.path.expanduser("~")
    roots = os.environ.get("DEVPURGE_AGENT_ROOTS")
    findings, nfiles, skipped = sweep(home, roots.split(os.pathsep) if roots else agents.DEFAULT_ROOTS)
    if args.json:
        print(json.dumps({"files_read": nfiles, "skipped": skipped, "findings": findings,
                          "rotate": {p: PROVIDERS[p][0] for p in sorted({f["provider"] for f in findings})}},
                         indent=2))
    else:
        print_report(findings, nfiles, skipped)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
