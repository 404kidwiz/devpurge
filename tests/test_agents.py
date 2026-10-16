"""Agent leftovers mode: only clean, pushed, stale agent worktrees are removable."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("devpurge_agents", ROOT / "src/agents.py")
agents = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agents)
OLD = time.time() - 30 * 86400


def git(cwd, *args):
    env = dict(os.environ, GIT_AUTHOR_DATE="@%d" % OLD, GIT_COMMITTER_DATE="@%d" % OLD)
    subprocess.run(["git", "-C", str(cwd), "-c", "user.name=t", "-c", "user.email=t@t",
                    "-c", "init.defaultBranch=main", *args], check=True, capture_output=True, env=env)


class AgentLeftoverTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="devpurge-agents-")
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name).resolve() / "home"
        self.remote = Path(temp.name).resolve() / "remote.git"
        self.repo = self.home / "Projects" / "app"
        self.repo.mkdir(parents=True)
        git(self.home, "init", "--bare", str(self.remote))
        git(self.repo, "init")
        (self.repo / "a.txt").write_text("a")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-m", "init")
        git(self.repo, "remote", "add", "origin", str(self.remote))
        git(self.repo, "push", "-u", "origin", "main")
        self.env = dict(os.environ, HOME=str(self.home), DEVPURGE_AGENT_ROOTS="Projects")
        self.env.pop("DEVPURGE_YES", None)

    def add_worktree(self, name, base=".claude/worktrees"):
        path = self.repo / base / name
        git(self.repo, "worktree", "add", "-b", name, str(path))
        git(path, "push", "-u", "origin", name)
        os.utime(path, (OLD, OLD))
        return path

    def items(self):
        return {i["path"]: i for i in agents.scan(str(self.home), ("Projects",), 7)}

    def run_cli(self, *args, env=None):
        return subprocess.run(["python3", str(ROOT / "src/agents.py"), *args], env=env or self.env,
                              stdin=subprocess.DEVNULL, capture_output=True, text=True)

    def test_clean_stale_worktree_is_removable_with_git_worktree_remove(self):
        wt = self.add_worktree("agent-clean")
        self.assertEqual(self.items()[str(wt)]["action"], "remove")
        dry = self.run_cli()
        self.assertIn("Dry run", dry.stdout)
        self.assertTrue(wt.exists())
        result = self.run_cli("--execute", env=dict(self.env, DEVPURGE_YES="true"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(wt.exists())
        out = subprocess.run(["git", "-C", str(self.repo), "worktree", "list"], capture_output=True, text=True)
        self.assertNotIn("agent-clean", out.stdout)
        self.assertTrue((self.repo / "a.txt").exists())

    def test_dirty_worktree_refused(self):
        wt = self.add_worktree("agent-dirty")
        (wt / "a.txt").write_text("changed")
        self.assertEqual(self.items()[str(wt)]["reason"], "uncommitted or untracked changes")

    def test_untracked_file_refused(self):
        wt = self.add_worktree("agent-untracked")
        (wt / "new.txt").write_text("n")
        self.assertFalse(self.items()[str(wt)]["eligible"])
        self.run_cli("--execute", env=dict(self.env, DEVPURGE_YES="true"))
        self.assertTrue((wt / "new.txt").exists())

    def test_unpushed_commits_refused(self):
        wt = self.add_worktree("agent-unpushed")
        (wt / "b.txt").write_text("b")
        git(wt, "add", ".")
        git(wt, "commit", "-m", "local")
        self.assertEqual(self.items()[str(wt)]["reason"], "unpushed commits")

    def test_stash_refused(self):
        wt = self.add_worktree("agent-stash")
        (wt / "a.txt").write_text("stashed")
        git(wt, "stash")
        self.assertEqual(self.items()[str(wt)]["reason"], "has a stash")

    def test_recent_worktree_kept(self):
        wt = self.add_worktree("agent-recent")
        os.utime(wt, None)
        self.assertIn("active", self.items()[str(wt)]["reason"])

    def test_non_agent_worktree_is_report_only(self):
        wt = self.add_worktree("feature-x", base="../manual")
        item = self.items()[str(wt.resolve())]
        self.assertFalse(item["eligible"])
        self.assertIn("report only", item["reason"])

    def test_protected_path_refused(self):
        self.assertIsNotNone(agents.safety.protected_reason(self.home / "Projects", self.home))
        wt = self.add_worktree("agent-git", base=".git/agent-worktrees/.claude/worktrees")
        item = self.items()[str(wt)]
        self.assertFalse(item["eligible"])
        self.assertIn("protected", item["reason"])

    def test_missing_worktree_dir_only_pruned(self):
        wt = self.add_worktree("agent-gone")
        subprocess.run(["rm", "-rf", str(wt)], check=True)
        self.assertEqual(self.items()[str(wt)]["action"], "prune")

    def test_execute_without_confirmation_aborts(self):
        wt = self.add_worktree("agent-noconfirm")
        self.assertNotEqual(self.run_cli("--execute").returncode, 0)
        self.assertTrue(wt.exists())

    def test_duplicate_clones_need_identical_clean_twin_and_typed_name(self):
        twin = self.home / "Projects" / "app-copy"
        git(self.home, "clone", str(self.remote), str(twin))
        dirty = self.home / "Projects" / "app-dirty"
        git(self.home, "clone", str(self.remote), str(dirty))
        (dirty / "x").write_text("x")
        items = self.items()
        self.assertEqual(items[str(self.repo)]["reason"], "kept copy")
        self.assertEqual(items[str(twin)]["action"], "delete-clone")
        self.assertFalse(items[str(dirty)]["eligible"])
        result = self.run_cli("--execute", env=dict(self.env, DEVPURGE_YES="true"))
        self.assertIn("needs an interactive typed confirmation", result.stdout)
        self.assertTrue(twin.exists())

    def test_clone_with_unpushed_branch_refused(self):
        twin = self.home / "Projects" / "app-copy"
        git(self.home, "clone", str(self.remote), str(twin))
        git(twin, "branch", "local-only")
        git(twin, "checkout", "-q", "local-only")
        (twin / "c").write_text("c")
        git(twin, "add", ".")
        git(twin, "commit", "-m", "c")
        git(twin, "checkout", "-q", "main")
        self.assertFalse(self.items()[str(twin)]["eligible"])

    def test_opencode_logs_eligible_db_and_auth_untouched(self):
        base = self.home / ".local/share/opencode"
        for rel in ("log/a.log", "snapshot/s", "auth.json", "opencode.db"):
            (base / rel).parent.mkdir(parents=True, exist_ok=True)
            (base / rel).write_text("x")
        self.run_cli("--execute", env=dict(self.env, DEVPURGE_YES="true"))
        self.assertFalse((base / "log").exists())
        for rel in ("snapshot/s", "auth.json", "opencode.db"):
            self.assertTrue((base / rel).exists(), rel)

    def test_clone_with_dirty_linked_worktree_is_report_only(self):
        # QA repro: deleting such a clone used to destroy the linked worktree's repository.
        twin = self.home / "Projects" / "app-copy"
        git(self.home, "clone", str(self.remote), str(twin))
        wip = self.home / "Documents" / "wip-wt"
        git(twin, "worktree", "add", "-b", "wip", str(wip))
        (wip / "c").write_text("staged")
        git(wip, "add", "c")
        (wip / "a.txt").write_text("edit")
        item = self.items()[str(twin)]
        self.assertFalse(item["eligible"])
        self.assertIn("linked worktrees", item["reason"])
        self.assertEqual(agents.git(str(wip), "status", "--porcelain")[0], 0)

    def test_ignored_secret_blocks_worktree_removal(self):
        wt = self.add_worktree("agent-env")
        (wt / ".gitignore").write_text(".env\n*.local\nnode_modules/\n")
        git(wt, "add", ".gitignore")
        git(wt, "commit", "-m", "ignore")
        git(wt, "push")
        os.utime(wt, (OLD, OLD))
        (wt / ".env").write_text("SECRET=1")
        item = self.items()[str(wt)]
        self.assertFalse(item["eligible"])
        self.assertIn("ignored secret", item["reason"])
        self.run_cli("--execute", env=dict(self.env, DEVPURGE_YES="true"))
        self.assertTrue((wt / ".env").exists())

    def ignored_twin(self, rel):
        twin = self.home / "Projects" / "app-copy"
        git(self.home, "clone", str(self.remote), str(twin))
        (twin / ".git/info/exclude").write_text("node_modules/\nbuild/\nconfig/\n.npmrc\n*.txt\n")
        (twin / "node_modules/pkg").mkdir(parents=True)
        (twin / "node_modules/pkg/index.js").write_text("x")
        (twin / "build").mkdir()
        (twin / "build/out.txt").write_text("x")
        if rel:
            (twin / rel).parent.mkdir(parents=True, exist_ok=True)
            (twin / rel).write_text("x")
        return twin, self.items()[str(twin)]

    def test_ignored_regenerable_dirs_without_secrets_do_not_block(self):
        _, item = self.ignored_twin(None)
        self.assertEqual(item["action"], "delete-clone")

    def test_ignored_local_config_blocks_clone(self):
        _, item = self.ignored_twin("config/app.local")
        self.assertIn("config/app.local", item["reason"])

    def test_secrets_inside_regenerable_dirs_block(self):
        for rel in ("node_modules/pkg/secrets.json", "build/.env"):
            subprocess.run(["rm", "-rf", str(self.home / "Projects" / "app-copy")], check=True)
            _, item = self.ignored_twin(rel)
            self.assertFalse(item["eligible"], rel)
            self.assertIn(rel, item["reason"])

    def test_extended_secret_patterns_block(self):
        for rel in (".npmrc", "config/.pypirc", "config/.netrc", "config/id_rsa", "config/id_ed25519.pub",
                    "config/terraform.tfstate.backup", "config/service-account-prod.json"):
            subprocess.run(["rm", "-rf", str(self.home / "Projects" / "app-copy")], check=True)
            _, item = self.ignored_twin(rel)
            self.assertFalse(item["eligible"], rel)

    def test_non_ascii_ignored_secret_blocks(self):
        twin, item = self.ignored_twin("config/ünï/.env")
        self.assertFalse(item["eligible"])
        self.assertIn("ünï/.env", item["reason"])
        wt = self.add_worktree("agent-uni")
        (self.repo / ".git/info/exclude").write_text("ünï/\n")
        (wt / "ünï").mkdir()
        (wt / "ünï/.env").write_text("S")
        self.assertIn("ignored secret", self.items()[str(wt)]["reason"])

    def test_cli_flag_is_dry_run(self):
        wt = self.add_worktree("agent-cli")
        result = subprocess.run(["bash", str(ROOT / "bin/devpurge"), "--agents", "--dry-run"], env=self.env,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Worktrees", result.stdout)
        self.assertTrue(wt.exists())


if __name__ == "__main__":
    unittest.main()
