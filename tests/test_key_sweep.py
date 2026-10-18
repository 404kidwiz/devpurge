"""Leaked-key sweep: finds fake keys, prints only masked values, never deletes or uses the network."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SWEEP = str(ROOT / "src/key_sweep.py")
A = "abcdefghijKLMNOPQRSTuvwxyz0123456789ABCDEFGHIJ"
# Fake keys are assembled at runtime so no key-shaped literal sits in the repo.
FAKE = {
    "OpenAI": "sk-" + "proj-" + A[:40],
    "Anthropic": "sk-" + "ant-api03-" + A[:40],
    "OpenRouter": "sk-" + "or-v1-" + A[:40],
    "Google/Gemini": "AI" + "za" + A[:35],
    "xAI": "xa" + "i-" + A[:40],
    "Groq": "gs" + "k_" + A[:40],
    "Mistral": "Zz" + A[:30],
    "AWS": "AK" + "IA" + "ABCDEFGHIJKLMNOP",
    "GitHub": "gh" + "p_" + A[:36],
    "Stripe": "sk" + "_live_" + A[:24],
    "Cloudflare": "Cf" + A[:38],
}
FILES = {
    ".codex/config.toml": 'api_key = "%s"\n' % FAKE["OpenAI"],
    ".claude/settings.json": '{"env": {"ANTHROPIC_API_KEY": "%s"}}\n' % FAKE["Anthropic"],
    ".config/opencode/opencode.json": '{"provider": {"openrouter": {"apiKey": "%s"}}}\n' % FAKE["OpenRouter"],
    ".cursor/mcp.json": '{"env": {"GEMINI_API_KEY": "%s", "XAI_API_KEY": "%s"}}\n' % (FAKE["Google/Gemini"],
                                                                                    FAKE["xAI"]),
    ".aider.conf.yml": "groq-api-key: %s\n" % FAKE["Groq"],
    "Projects/app/.env": "MISTRAL_API_KEY=%s\nAWS_ACCESS_KEY_ID=%s\nGITHUB_TOKEN=%s\n" % (
        FAKE["Mistral"], FAKE["AWS"], FAKE["GitHub"]),
    "Projects/app/apps/web/.env.local": "STRIPE_SECRET_KEY=%s\nCLOUDFLARE_API_TOKEN=%s\n" % (
        FAKE["Stripe"], FAKE["Cloudflare"]),
}
NOT_READ = {
    "Projects/app/.env.example": "OPENAI_API_KEY=%s\n" % FAKE["OpenAI"],
    "Projects/app/node_modules/pkg/.env": "OPENAI_API_KEY=%s\n" % FAKE["OpenAI"],
    ".claude/projects/p/transcript.jsonl": '{"text": "%s"}\n' % FAKE["Anthropic"],
    ".codex/sessions/s.toml": 'k = "%s"\n' % FAKE["OpenAI"],
}
NO_NET = ("import socket, runpy, sys\n"
          "def refuse(*a, **k): raise RuntimeError('network used')\n"
          "socket.socket = refuse; socket.create_connection = refuse\n"
          "sys.argv = [sys.argv[1]] + sys.argv[2:]\n"
          "runpy.run_path(sys.argv[0], run_name='__main__')\n")


class KeySweepTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="devpurge-keys-")
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name) / "home"
        for rel, text in {**FILES, **NOT_READ}.items():
            (self.home / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.home / rel).write_text(text)
        self.env = dict(os.environ, HOME=str(self.home), DEVPURGE_AGENT_ROOTS="Projects")

    def run_sweep(self, *args):
        return subprocess.run([sys.executable, "-c", NO_NET, SWEEP, *args], env=self.env,
                              capture_output=True, text=True)

    def assert_no_full_key(self, text):
        for key in FAKE.values():
            self.assertNotIn(key, text)
            self.assertNotIn(key[4:-2], text)

    def test_finds_every_provider_masked(self):
        result = self.run_sweep("--json")
        self.assertEqual(result.returncode, 1, result.stderr)
        data = json.loads(result.stdout)
        found = {(f["provider"], f["masked"]) for f in data["findings"]}
        for provider, key in FAKE.items():
            self.assertIn((provider, key[:4] + "…" + key[-2:]), found, provider)
        self.assertEqual(set(data["rotate"]), set(FAKE))
        self.assert_no_full_key(result.stdout + result.stderr)

    def test_text_report_has_rotation_links_and_no_full_keys(self):
        result = self.run_sweep()
        self.assertEqual(result.returncode, 1, result.stderr)
        for url in ("platform.openai.com/api-keys", "console.anthropic.com/settings/keys",
                    "aistudio.google.com", "console.x.ai", "openrouter.ai/settings/keys",
                    "console.groq.com/keys", "console.mistral.ai/api-keys", "console.aws.amazon.com",
                    "github.com/settings/tokens", "dashboard.stripe.com/apikeys",
                    "dash.cloudflare.com/profile/api-tokens"):
            self.assertIn(url, result.stdout)
        self.assertIn("guidance", result.stdout)
        self.assert_no_full_key(result.stdout + result.stderr)

    def test_templates_dependencies_and_history_not_reported(self):
        data = json.loads(self.run_sweep("--json").stdout)
        files = {f["file"] for f in data["findings"]}
        for rel in NOT_READ:
            self.assertNotIn(str(self.home / rel), files)
        self.assertGreater(data["skipped"], 0)

    def test_report_only_files_unchanged(self):
        before = {p: (p.stat().st_mtime_ns, p.read_text()) for p in self.home.rglob("*") if p.is_file()}
        self.run_sweep()
        after = {p: (p.stat().st_mtime_ns, p.read_text()) for p in self.home.rglob("*") if p.is_file()}
        self.assertEqual(before, after)

    def test_clean_home_exits_zero(self):
        for rel in FILES:
            (self.home / rel).write_text("nothing here\n")
        result = self.run_sweep()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("No provider API keys found", result.stdout)

    def test_cli_flag(self):
        result = subprocess.run(["bash", str(ROOT / "bin/devpurge"), "--key-sweep", "--json"], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertTrue(json.loads(result.stdout)["findings"])
        self.assert_no_full_key(result.stdout + result.stderr)

    def test_mask_never_reveals_more_than_six_characters(self):
        spec = __import__("importlib.util").util.spec_from_file_location("ks", SWEEP)
        ks = __import__("importlib.util").util.module_from_spec(spec)
        spec.loader.exec_module(ks)
        for key in FAKE.values():
            self.assertLessEqual(len(ks.mask(key).replace("…", "")), 6)
        self.assertEqual(ks.mask("short1234"), "sh…")


if __name__ == "__main__":
    unittest.main()
