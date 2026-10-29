"""Claude Code plugin: manifest and components follow the documented layout."""
import json
from pathlib import Path
import re
import unittest

PLUGIN = Path(__file__).resolve().parents[1] / "claude-plugin"


class ClaudePluginTests(unittest.TestCase):
    def test_manifest(self):
        m = json.loads((PLUGIN / ".claude-plugin/plugin.json").read_text())
        self.assertRegex(m["name"], r"^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$")
        for key in ("description", "author", "version", "license"):
            self.assertIn(key, m)
        self.assertEqual(sorted(p.name for p in (PLUGIN / ".claude-plugin").iterdir()), ["plugin.json"])

    def test_commands_and_skill_have_frontmatter(self):
        files = list((PLUGIN / "commands").glob("*.md")) + [PLUGIN / "skills/devpurge/SKILL.md"]
        self.assertEqual(len(files), 3)
        for f in files:
            text = f.read_text()
            self.assertTrue(text.startswith("---\n"), f)
            self.assertRegex(text.split("---", 2)[1], r"(?m)^description: \S", f)

    def test_clean_never_preapproves_real_cleanup(self):
        head = (PLUGIN / "commands/clean.md").read_text().split("---", 2)[1]
        safe = {"all", "uv", "node", "lang", "mac", "system", "browsers", "installers", "oldstores"}
        for rule in re.findall(r"Bash\(([^)]*)\)", head):
            if rule == "command -v devpurge":
                continue
            self.assertNotIn("*", rule)
            m = re.fullmatch(r"devpurge --(\w+) --dry-run", rule)
            self.assertTrue(m and m.group(1) in safe, rule)

    def test_readme_and_license(self):
        readme = re.sub(r"```.*?```", "", (PLUGIN / "README.md").read_text(), flags=re.S)
        self.assertGreaterEqual(len(readme.split()), 40)
        self.assertTrue((PLUGIN / "LICENSE").exists())


if __name__ == "__main__":
    unittest.main()
