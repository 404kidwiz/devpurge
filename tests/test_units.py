"""Decimal byte formatting: the Python and web GUI copies agree with tests/units_cases.json.

The Swift copy runs the same cases in mac/Tests/DevPurgeTests/ByteFormatTests.swift.
"""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
CASES = json.loads((ROOT / 'tests/units_cases.json').read_text())['cases']
SPEC = importlib.util.spec_from_file_location('devpurge_units_test', ROOT / 'src/units.py')
units = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(units)


class UnitsTests(unittest.TestCase):
    def test_python_matches_shared_cases(self):
        for n, want in CASES:
            with self.subTest(n=n):
                self.assertEqual(units.fmt_bytes(n), want)

    def test_cli_entry_point_prints_decimal_units(self):
        result = subprocess.run(['python3', str(ROOT / 'src/units.py'), '5197000000'],
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), '5.20 GB')

    @unittest.skipUnless(shutil.which('node'), 'node is not installed')
    def test_web_gui_matches_shared_cases(self):
        script = ('const {fmtBytes} = require(process.argv[1]);'
                  'const cases = JSON.parse(process.argv[2]);'
                  'console.log(JSON.stringify(cases.map(([n]) => fmtBytes(n))));')
        result = subprocess.run(['node', '-e', script, str(ROOT / 'src/web/units.js'), json.dumps(CASES)],
                                capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout), [want for _, want in CASES])

    def test_no_binary_units_left_in_user_facing_output(self):
        # GiB/MiB or bare K/M/G suffixes would bring back the mismatch with Finder.
        for path in ('src/report.py', 'src/ai_bloat.py', 'src/agents.py', 'src/web/app.js', 'src/utils.sh'):
            text = (ROOT / path).read_text()
            with self.subTest(path=path):
                self.assertNotIn('GiB', text)
                self.assertNotIn('MiB', text)
                self.assertNotIn('du -sh', text)


if __name__ == '__main__':
    unittest.main()
