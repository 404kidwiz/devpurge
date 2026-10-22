#!/usr/bin/env python3
"""Decimal byte formatting shared by the CLI, the local GUI and (as copies) the web and Mac apps.

1 GB = 10^9 bytes, matching Finder and About This Mac. src/web/units.js and
mac/Sources/DevPurge/Models/ByteFormat.swift implement the same rules; all three are
tested against tests/units_cases.json so they cannot drift.

Usage from shell: python3 units.py <bytes>
"""
import sys

# Largest first: (bytes per unit, label, decimals).
UNITS = ((10**12, 'TB', 2), (10**9, 'GB', 2), (10**6, 'MB', 1), (10**3, 'KB', 1))


def fmt_bytes(n):
    if n is None:
        return 'unknown'
    n = int(n)
    for i, (size, label, digits) in enumerate(UNITS):
        if n >= size:
            text = f'{n / size:.{digits}f}'
            # 999,960 bytes would print "1000.0 KB"; step up to "1.0 MB" instead.
            if float(text) >= 1000 and i > 0:
                size, label, digits = UNITS[i - 1]
                text = f'{n / size:.{digits}f}'
            return f'{text} {label}'
    return f'{n} B'


if __name__ == '__main__':
    print(fmt_bytes(int(sys.argv[1])))
