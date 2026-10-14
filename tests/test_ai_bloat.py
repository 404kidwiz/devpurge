"""AI tool bloat mode: caches eligible, auth/config/history/state refused."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("devpurge_ai_bloat", ROOT / "src/ai_bloat.py")
ai_bloat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ai_bloat)

AS = "Library/Application Support"
CACHES = (".codex/cache/x", ".claude/cache/x", AS + "/Cursor/Cache/x", AS + "/Cursor/CachedData/x",
          AS + "/Cursor/GPUCache/x", AS + "/Cursor/logs/x", AS + "/Codex/Code Cache/x",
          "Library/Logs/DiagnosticReports/Cursor-2026-10-01.ips",
          "Library/Logs/DiagnosticReports/Codex_2026-10-02.ips")
KEEP = (".codex/auth.json", ".codex/config.toml", ".codex/history.jsonl", ".codex/sessions/s.jsonl",
        ".codex/logs_2.sqlite", ".claude/settings.json", ".claude/history.jsonl",
        ".claude/projects/p/m.jsonl", AS + "/Cursor/User/settings.json",
        AS + "/Cursor/User/workspaceStorage/w/state.vscdb", ".cursor/extensions/e/x",
        "Library/Logs/DiagnosticReports/Safari-2026.ips")


class AiBloatTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="devpurge-ai-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        for rel in CACHES + KEEP:
            p = self.home / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("x" * 100)
        self.env = dict(os.environ, HOME=str(self.home))
        self.env.pop("DEVPURGE_YES", None)

    def run_ai(self, *args, env=None):
        return subprocess.run(["python3", str(ROOT / "src/ai_bloat.py"), *args], env=env or self.env,
                              stdin=subprocess.DEVNULL, capture_output=True, text=True)

    def test_config_auth_history_and_state_are_refused(self):
        for rel in (".codex/auth.json", ".codex/config.toml", ".claude/history.jsonl",
                    ".claude/settings.json", ".codex/sessions", ".claude/projects",
                    AS + "/Cursor/User", AS + "/Cursor/User/workspaceStorage", ".cursor/extensions",
                    ".codex/logs_2.sqlite", ".codex/.env", ".codex/key.pem"):
            self.assertIsNotNone(ai_bloat.refusal_reason(self.home / rel, self.home), rel)

    def test_caches_are_eligible(self):
        for rel in (".codex/cache", ".claude/cache", AS + "/Cursor/Cache", AS + "/Cursor/CachedData",
                    AS + "/Cursor/GPUCache", AS + "/Cursor/logs"):
            self.assertIsNone(ai_bloat.refusal_reason(self.home / rel, self.home), rel)

    def test_scan_reports_tools_and_only_caches_eligible(self):
        items = {i["path"]: i for i in ai_bloat.scan(str(self.home))}
        self.assertTrue(items[str(self.home / AS / "Cursor/CachedData")]["eligible"])
        self.assertFalse(items[str(self.home / ".codex/sessions")]["eligible"])
        self.assertFalse(items[str(self.home / AS / "Cursor/User")]["eligible"])
        self.assertNotIn(str(self.home / "Library/Logs/DiagnosticReports/Safari-2026.ips"), items)
        self.assertEqual({i["tool"] for i in items.values()}, {"Codex", "Claude Code", "Cursor"})

    def test_default_is_dry_run(self):
        result = self.run_ai()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Dry run", result.stdout)
        for rel in CACHES + KEEP:
            self.assertTrue((self.home / rel).exists(), rel)

    def test_execute_without_confirmation_aborts(self):
        result = self.run_ai("--execute")
        self.assertNotEqual(result.returncode, 0)
        for rel in CACHES:
            self.assertTrue((self.home / rel).exists(), rel)

    def test_execute_with_yes_removes_caches_and_preserves_keep(self):
        result = self.run_ai("--execute", env=dict(self.env, DEVPURGE_YES="true"))
        self.assertEqual(result.returncode, 0, result.stderr)
        for rel in CACHES:
            self.assertFalse((self.home / rel).exists(), rel)
        for rel in KEEP:
            self.assertTrue((self.home / rel).exists(), rel)

    def test_symlinked_cache_to_protected_folder_is_refused(self):
        (self.home / "Documents").mkdir()
        link = self.home / ".claude/paste-cache"
        link.symlink_to(self.home / "Documents")
        self.assertIsNotNone(ai_bloat.refusal_reason(link, self.home))

    def test_cli_ai_flag_is_dry_run_and_keeps_history(self):
        result = subprocess.run(["/bin/bash", str(ROOT / "bin/devpurge"), "--ai", "--dry-run"],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Cursor", result.stdout)
        self.assertEqual((self.home / ".claude/history.jsonl").read_text(), "x" * 100)
