"""The release version is written in four files; they must agree before a DMG is built."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def find(path, pattern):
    match = re.search(pattern, (ROOT / path).read_text(), re.M)
    if not match:
        raise AssertionError(f'no version found in {path}')
    return match.group(1)


class VersionTests(unittest.TestCase):
    def test_all_version_strings_agree(self):
        versions = {
            'bin/devpurge': find('bin/devpurge', r'^VERSION="([^"]+)"'),
            'scripts/build_mac_app.sh': find('scripts/build_mac_app.sh',
                                             r'<key>CFBundleShortVersionString</key>\s*<string>([^<]+)</string>'),
            'scripts/package_dmg.sh': find('scripts/package_dmg.sh', r'^VERSION="([^"]+)"'),
            'scripts/release_mac.sh': find('scripts/release_mac.sh', r'^VERSION="\$\{VERSION:-([^}]+)\}"'),
        }
        self.assertEqual(len(set(versions.values())), 1, versions)
        self.assertRegex(versions['bin/devpurge'], r'^\d+\.\d+\.\d+$')

    def test_build_number_is_a_positive_integer(self):
        build = find('scripts/build_mac_app.sh', r'<key>CFBundleVersion</key>\s*<string>([^<]+)</string>')
        self.assertRegex(build, r'^[1-9]\d*$')


if __name__ == '__main__':
    unittest.main()
