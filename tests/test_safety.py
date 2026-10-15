"""Protected-path denylist and typed Docker confirmation."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("devpurge_safety", ROOT / "src/safety.py")
safety = importlib.util.module_from_spec(spec)
spec.loader.exec_module(safety)


class ProtectedPathTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="devpurge-safety-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        for sub in ("Desktop", "Documents", "Projects/app/.git/objects", "Library/Keychains",
                    "Library/Developer/Xcode/Archives/x.xcarchive", "Library/Caches/node-gyp"):
            (self.home / sub).mkdir(parents=True)

    def test_refuses_protected_locations(self):
        for path in (Path("/"), self.home, self.home.parent, self.home / "Desktop", self.home / "Documents",
                     self.home / "Projects", self.home / "Projects/app/.git", self.home / "Projects/app/.git/objects",
                     self.home / "Library/Keychains", self.home / "Library/Developer/Xcode/Archives/x.xcarchive",
                     Path("/Library/Keychains")):
            self.assertIsNotNone(safety.protected_reason(path, self.home), path)

    def test_symlink_to_protected_folder_is_refused(self):
        link = self.home / "Library/Caches/evil"
        link.symlink_to(self.home / "Documents")
        self.assertIsNotNone(safety.protected_reason(link, self.home))

    def test_allows_cache_paths(self):
        self.assertIsNone(safety.protected_reason(self.home / "Library/Caches/node-gyp", self.home))

    def test_shell_sweep_refuses_and_preserves_protected_path(self):
        desktop = self.home / "Desktop"
        (desktop / "keep.txt").write_text("keep")
        script = ('DIR="$1"; source "$1/utils.sh"; DRY_RUN=false; RESCUE_MODE=false; '
                  'execute_sweep_path "$HOME/Desktop" "desktop"')
        result = subprocess.run(["/bin/bash", "-c", script, "bash", str(ROOT / "src")],
                                env=dict(os.environ, HOME=str(self.home)), capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("REFUSED", result.stderr)
        self.assertTrue((desktop / "keep.txt").exists())


class DockerConfirmationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="devpurge-docker-")
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.home = base / "home"
        self.home.mkdir()
        fakebin = base / "bin"
        fakebin.mkdir()
        self.calls = base / "calls"
        for tool in ("docker", "osascript", "notify-send"):
            stub = fakebin / tool
            stub.write_text('#!/bin/bash\nprintf "%s\\n" "' + tool + ' $*" >> "$TEST_CALLS"\nexit 0\n')
            stub.chmod(0o755)
        (self.home / ".devpurge.json").write_text(json.dumps({}))
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(fakebin) + ":" + os.environ["PATH"],
                        TEST_CALLS=str(self.calls))
        self.env.pop("DEVPURGE_YES", None)

    def run_cli(self, *args):
        return subprocess.run(["/bin/bash", str(ROOT / "bin/devpurge"), *args], env=self.env,
                              stdin=subprocess.DEVNULL, capture_output=True, text=True)

    def logged(self):
        return self.calls.read_text() if self.calls.exists() else ""

    def test_noninteractive_docker_without_yes_aborts(self):
        result = self.run_cli("--docker")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("system prune", self.logged())

    def test_docker_with_yes_prunes(self):
        result = self.run_cli("--docker", "--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("docker system prune -af --volumes", self.logged())

    def test_dry_run_never_prompts_or_prunes(self):
        result = self.run_cli("--docker", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("system prune", self.logged())


if __name__ == "__main__":
    unittest.main()
