#!/usr/bin/env python3
"""Hard denylist for DevPurge deletions.

Usage: safety.py PATH  -> exit 0 if removable, 3 (with reason on stdout) if protected.
"""
import os
import sys

PROTECTED_HOME_FOLDERS = ("Desktop", "Documents", "Downloads", "Projects", "Developer", "Library")


def protected_reason(path, home=None):
    home = os.path.realpath(os.path.expanduser(str(home)) if home else os.path.expanduser("~"))
    target = os.path.realpath(os.path.abspath(os.path.expanduser(str(path))))
    if target == os.sep or not target:
        return "filesystem root"
    if target == home or home.startswith(target.rstrip(os.sep) + os.sep):
        return "home directory or one of its parents"
    for name in PROTECTED_HOME_FOLDERS:
        if target == os.path.join(home, name):
            return "protected folder ~/" + name
    if ".git" in target.split(os.sep):
        return "inside a Git repository's .git directory"
    subtrees = (
        (os.path.join(home, "Library", "Keychains"), "Keychains"),
        ("/Library/Keychains", "Keychains"),
        (os.path.join(home, "Library", "Developer", "Xcode", "Archives"), "Xcode Archives"),
    )
    for root, label in subtrees:
        if target == root or target.startswith(root + os.sep):
            return label
    return None


def main(argv):
    if len(argv) != 2:
        print("usage: safety.py PATH", file=sys.stderr)
        return 2
    reason = protected_reason(argv[1])
    if reason:
        print(reason)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
