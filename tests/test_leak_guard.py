"""Leak guard: name/path matching only, never deletes, hooks block secrets."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUARD = str(ROOT / "src/leak_guard.py")


def run(*args, cwd=None, stdin=None):
    return subprocess.run(["python3", GUARD, *args], cwd=cwd, input=stdin, capture_output=True, text=True)


def git(cwd, *args):
    subprocess.run(["git", "-C", str(cwd), "-c", "user.name=t", "-c", "user.email=t@t", *args],
                   check=True, capture_output=True)


class LeakGuardTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="devpurge-leak-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for rel in ("dist/app.js", "src/.env", "node_modules/pkg/dist/.env", ".env.example", "public/index.html"):
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.root / rel).write_text("x")

    def add(self, rel):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("x")
        return p

    def test_clean_output_passes(self):
        result = run("check", str(self.root))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("No secret-looking files", result.stdout)

    def test_secrets_in_output_folders_flagged_and_kept(self):
        for rel in ("dist/.env.production", "build/keys/server.pem", ".vercel/output/.npmrc",
                    "apps/web/.next/credentials.json", "out/id_rsa", "functions/service-account-x.json"):
            self.add(rel)
        result = run("check", str(self.root))
        self.assertEqual(result.returncode, 1)
        for rel in ("dist/.env.production", "build/keys/server.pem", ".vercel/output/.npmrc",
                    "apps/web/.next/credentials.json", "out/id_rsa", "functions/service-account-x.json"):
            self.assertIn(rel, result.stdout)
            self.assertTrue((self.root / rel).exists())
        self.assertNotIn("src/.env", result.stdout)
        self.assertNotIn("node_modules", result.stdout)

    def test_unreadable_file_still_flagged_without_opening(self):
        secret = self.add("dist/.env")
        os.chmod(secret, 0)
        self.addCleanup(os.chmod, secret, 0o600)
        result = run("check", str(self.root))
        self.assertEqual(result.returncode, 1)
        self.assertIn("dist/.env", result.stdout)

    def test_cli_flag(self):
        self.add("dist/.env")
        result = subprocess.run(["bash", str(ROOT / "bin/devpurge"), "--leak-check", str(self.root)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("dist/.env", result.stdout)

    def test_git_hook_blocks_staged_env_and_allows_clean(self):
        git(self.root, "init", "-q")
        self.assertEqual(run("install-git-hook", str(self.root)).returncode, 0)
        git(self.root, "add", "dist/app.js", ".env.example")
        git(self.root, "commit", "-qm", "clean")
        git(self.root, "add", "src/.env")
        result = subprocess.run(["git", "-C", str(self.root), "-c", "user.name=t", "-c", "user.email=t@t",
                                 "commit", "-qm", "leak"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("src/.env", result.stdout + result.stderr)

    def test_git_hook_installer_refuses_to_overwrite(self):
        git(self.root, "init", "-q")
        hook = self.root / ".git/hooks/pre-commit"
        hook.parent.mkdir(parents=True, exist_ok=True)
        hook.write_text("#!/bin/sh\necho mine\n")
        self.assertEqual(run("install-git-hook", str(self.root)).returncode, 3)
        self.assertEqual(hook.read_text(), "#!/bin/sh\necho mine\n")

    def test_pre_deploy_hook_blocks_deploy_only(self):
        self.add("dist/.env")
        for event in ({"tool_input": {"command": "npx wrangler deploy"}, "cwd": str(self.root)},
                      {"command": "vercel --prod", "workspace_roots": [str(self.root)]}):
            result = run("pre-deploy", stdin=json.dumps(event))
            self.assertEqual(result.returncode, 2, event)
            self.assertIn("dist/.env", result.stderr)
        result = run("pre-deploy", stdin=json.dumps({"tool_input": {"command": "npm test"}, "cwd": str(self.root)}))
        self.assertEqual(result.returncode, 0)

    def test_pre_deploy_allows_clean_output(self):
        event = {"tool_input": {"command": "firebase deploy"}, "cwd": str(self.root)}
        self.assertEqual(run("pre-deploy", stdin=json.dumps(event)).returncode, 0)

    def test_print_config_writes_nothing(self):
        before = sorted(p for p in self.root.rglob("*"))
        for tool, key in (("claude", "PreToolUse"), ("codex", "PreToolUse"), ("cursor", "beforeShellExecution")):
            result = run("print-config", tool, cwd=self.root)
            self.assertEqual(result.returncode, 0)
            self.assertIn(key, json.loads(result.stdout)["hooks"])
        self.assertEqual(before, sorted(p for p in self.root.rglob("*")))


if __name__ == "__main__":
    unittest.main()
