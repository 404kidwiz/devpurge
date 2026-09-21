"""Behavior checks using isolated homes and fake package managers."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CliTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="devpurge-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home with 'quotes"
        self.home.mkdir()
        self.fakebin = Path(self.temp.name) / "bin"
        self.fakebin.mkdir()
        self.calls = Path(self.temp.name) / "calls"
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=str(self.fakebin) + ":" + os.environ["PATH"],
                        TEST_CALLS=str(self.calls))
        for tool in ("uv", "npm", "pnpm", "brew", "pip3", "go", "docker",
                     "git", "osascript", "notify-send", "launchctl", "systemctl"):
            self.stub(tool)

    def stub(self, tool, status=0):
        script = self.fakebin / tool
        script.write_text('#!/bin/bash\nprintf "%s\\n" "' + tool +
                          ' $*" >> "$TEST_CALLS"\nexit ' + str(status) + '\n')
        script.chmod(0o755)

    def run_cli(self, *args, binary=None):
        return subprocess.run(["/bin/bash", str(binary or ROOT / "bin/devpurge"), *args],
                              env=self.env, capture_output=True, text=True)

    def config(self, **settings):
        (self.home / ".devpurge.json").write_text(json.dumps(settings))

    def marker(self, name):
        path = self.home / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("preserve me")
        return path

    def logged(self):
        return self.calls.read_text() if self.calls.exists() else ""

    def test_help_loads_all_modules(self):
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--uv", result.stdout)
        self.assertIn("Node Ecosystem", result.stdout)
        self.assertEqual(self.logged(), "")

    def test_dry_run_order_and_files_are_preserved(self):
        marker = self.marker("Library/Caches/node-gyp/sentinel")
        result = self.run_cli("--node", "--uv", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(marker.exists())
        self.assertEqual(self.logged(), "")
        self.assertIn("No cleanup performed", result.stdout)

    def test_all_only_cleans_caches(self):
        history = self.marker(".claude/history.jsonl")
        archive = self.marker("Library/Developer/Xcode/Archives/sentinel")
        derived = self.marker("Library/Developer/Xcode/DerivedData/sentinel")
        result = self.run_cli("--all")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(history.exists())
        self.assertTrue(archive.exists())
        self.assertFalse(derived.exists())
        self.assertIn("uv cache prune", self.logged())
        self.assertNotIn("docker ", self.logged())
        self.assertNotIn("git ", self.logged())

    def test_unknown_options_fail_before_any_cleanup(self):
        result = self.run_cli("--node", "--typo")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.logged(), "")

    def test_failed_command_is_visible_and_stops_sweep(self):
        self.stub("npm", 42)
        result = self.run_cli("--node")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("[FAILED]", result.stderr)
        self.assertNotIn("pnpm ", self.logged())
        self.assertNotIn("cleanup finished", result.stdout)

    def test_rescue_mode_skips_commands_and_preserves_collisions(self):
        self.config(rescue_mode=True)
        marker = self.marker("Library/Caches/node-gyp/sentinel")
        existing = self.marker(".Trash/node-gyp/sentinel")
        result = self.run_cli("--node", "--ai", "--docker", "--git")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(marker.exists())
        self.assertTrue(existing.exists())
        self.assertEqual(self.logged(), "")
        self.assertEqual(len(list((self.home / ".Trash").glob("devpurge.*/node-gyp/sentinel"))), 1)

    def test_ignore_and_disabled_background(self):
        self.config(ignore=["uv"], automated_sweep=False)
        self.assertEqual(self.run_cli("--uv").returncode, 0)
        self.assertEqual(self.run_cli("--background", "--all").returncode, 0)
        self.assertEqual(self.logged(), "")

    def test_background_rejects_non_cache_modules(self):
        self.config(automated_sweep=True)
        self.assertNotEqual(self.run_cli("--background", "--docker").returncode, 0)
        self.assertEqual(self.logged(), "")

    def test_invalid_config_fails_closed(self):
        for text in ('{broken', '{"rescue_mode":"false"}', '{"interval_days":0}'):
            (self.home / ".devpurge.json").write_text(text)
            self.assertNotEqual(self.run_cli("--node").returncode, 0)
        self.assertEqual(self.logged(), "")

    def test_install_symlink_and_no_automatic_schedule(self):
        self.config(ignore=["git"], automated_sweep=False)
        before = (self.home / ".devpurge.json").read_bytes()
        result = self.run_cli("--install")
        self.assertEqual(result.returncode, 0, result.stderr)
        binary = self.home / ".local/bin/devpurge"
        self.assertEqual(self.run_cli("--help", binary=binary).returncode, 0)
        self.assertEqual(self.run_cli("--install", binary=binary).returncode, 0)
        self.assertEqual(before, (self.home / ".devpurge.json").read_bytes())
        self.assertEqual(self.logged(), "")
        scan = self.run_cli("--scan", "--json", binary=binary)
        self.assertEqual(scan.returncode, 0, scan.stderr)
        self.assertTrue(json.loads(scan.stdout)["read_only"])
        self.assertFalse((self.home / "Library/LaunchAgents/com.devpurge.sweeper.plist").exists())

    def test_scan_json_is_read_only_and_cannot_mix_with_cleanup(self):
        marker = self.marker(".cache/uv/sentinel")
        result = self.run_cli("--scan", "--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertTrue(data["read_only"])
        self.assertTrue(marker.exists())
        for args in (("--node", "--scan"), ("--scan", "--install"), ("--json", "--node")):
            self.assertNotEqual(self.run_cli(*args).returncode, 0)
        self.assertEqual(self.logged(), "pnpm store path\n")

    def test_new_modules_are_not_part_of_all(self):
        marker = self.marker("Library/Caches/Comet/Default/Cache/sentinel")
        installer = self.marker("Library/Caches/@opencode-aidesktop-updater/pending/update.zip")
        result = self.run_cli("--all")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(marker.exists())
        self.assertTrue(installer.exists())

    def test_dry_run_never_installs_or_uninstalls(self):
        for flag in ("--install", "--uninstall"):
            self.assertNotEqual(self.run_cli("--dry-run", flag).returncode, 0)
        self.assertFalse((self.home / ".local").exists())
        self.assertEqual(self.logged(), "")

    @unittest.skipUnless(os.uname().sysname == "Darwin", "macOS scheduler")
    def test_schedule_honors_interval_and_never_runs_at_load(self):
        self.config(automated_sweep=True, interval_days=3)
        result = subprocess.run(["/bin/bash", str(ROOT / "install.sh"), "--schedule"],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        with (self.home / "Library/LaunchAgents/com.devpurge.sweeper.plist").open("rb") as f:
            job = plistlib.load(f)
        self.assertEqual(job["StartInterval"], 259200)
        self.assertFalse(job["RunAtLoad"])
        self.assertEqual(job["ProgramArguments"][-2:], ["--background", "--all"])
        self.assertNotIn("npm ", self.logged())


if __name__ == "__main__":
    unittest.main()
