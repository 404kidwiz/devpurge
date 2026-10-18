"""Review packs: every shipped pack passes the validator; bad packs fail."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("review_validate", ROOT / "review-packs/validate.py")
validate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validate)


class ReviewPackTests(unittest.TestCase):
    def test_shipped_packs_pass(self):
        result = subprocess.run(["python3", str(ROOT / "review-packs/validate.py")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(result.stdout.count("ok  "), 4)

    def test_missing_section_and_few_rules_fail(self):
        errs = validate.problems("# Review instructions\n\n## Always check\n\n- one\n")
        self.assertTrue(any("Do not report" in e for e in errs))
        self.assertTrue(any("at least 5" in e for e in errs))

    def test_at_import_and_bad_title_fail(self):
        errs = validate.problems("# Rules\nSee @docs/rules.md\n")
        self.assertTrue(any("@ imports" in e for e in errs))
        self.assertTrue(any("first line" in e for e in errs))

    def test_missing_file_fails(self):
        with tempfile.TemporaryDirectory() as d:
            result = subprocess.run(["python3", str(ROOT / "review-packs/validate.py"), d],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("REVIEW.md not found", result.stdout)


if __name__ == "__main__":
    unittest.main()
