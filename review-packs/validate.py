#!/usr/bin/env python3
"""Check that each review pack's REVIEW.md has the expected format.

Usage: validate.py [PACK_DIR ...]   (default: every folder next to this script)
"""
import os
import re
import sys

REQUIRED = ("## What Important means here", "## Always check", "## Do not report", "## Evidence required")
MIN_RULES = 5


def problems(text):
    found = []
    if not text.startswith("# Review instructions"):
        found.append("first line must start with '# Review instructions'")
    for heading in REQUIRED:
        if heading not in text.splitlines():
            found.append("missing section: " + heading)
    if "## Always check" in text:
        section = text.split("## Always check", 1)[1].split("\n## ", 1)[0]
        rules = [l for l in section.splitlines() if l.startswith("- ")]
        if len(rules) < MIN_RULES:
            found.append("Always check needs at least %d rules, has %d" % (MIN_RULES, len(rules)))
    if re.search(r"(^|\s)@[\w./-]+\.md", text):
        found.append("@ imports are not expanded by Code Review; inline the rules")
    return found


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    packs = argv[1:] or sorted(os.path.join(here, d) for d in os.listdir(here)
                               if os.path.isdir(os.path.join(here, d)) and not d.startswith((".", "_")))
    failed = 0
    for pack in packs:
        path = os.path.join(pack, "REVIEW.md")
        errs = ["REVIEW.md not found"] if not os.path.isfile(path) else problems(open(path).read())
        print("%s %s" % ("FAIL" if errs else "ok  ", os.path.basename(pack.rstrip("/"))))
        for e in errs:
            print("     " + e)
        failed += bool(errs)
    return 1 if failed or not packs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
