import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import zipfile

SPEC = importlib.util.spec_from_file_location('devpurge_report', Path(__file__).resolve().parents[1] / 'src/report.py')
report = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = report
SPEC.loader.exec_module(report)


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.apps = self.home / 'Applications'
        self.inventory = report.Inventory(self.home, [self.apps])

    def app(self, name, bundle, version='2.0', base=None):
        path = (base or self.apps) / (name + '.app') / 'Contents/Info.plist'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps({'CFBundleIdentifier': bundle,
                                       'CFBundleShortVersionString': version}))
        return path

    def marker(self, relative):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('keep this')
        return path

    def refresh(self, processes='', opened='', failed=False):
        def fake(args, **kwargs):
            if args[0] == 'ps': return subprocess.CompletedProcess(args, 0, processes, '')
            if args[0] == 'lsof': return subprocess.CompletedProcess(args, int(failed), opened, '')
            return subprocess.CompletedProcess(args, 0, plistlib.dumps({'images': []}).decode(), '')
        with patch.object(report, 'run', side_effect=fake):
            self.inventory.refresh()

    def test_browser_requires_inactive_identified_owner(self):
        self.app('Comet', 'ai.perplexity.comet')
        path = self.marker('Library/Caches/Comet/Default/Cache/data')
        self.refresh()
        self.assertEqual(self.inventory.browser_targets()[0].status, 'eligible')
        self.refresh(processes=str(self.apps / 'Comet.app/Contents/MacOS/Comet'))
        self.assertEqual(self.inventory.browser_targets()[0].status, 'in-use')
        self.assertTrue(path.exists())

    def test_open_files_and_failed_checks_block_deletion(self):
        self.app('Comet', 'ai.perplexity.comet')
        marker = self.marker('Library/Caches/Comet/Default/Cache/data')
        self.refresh(opened='n' + str(marker))
        self.assertEqual(self.inventory.browser_targets()[0].status, 'in-use')
        self.refresh(failed=True)
        self.assertEqual(self.inventory.browser_targets()[0].status, 'review')

    def test_symlink_cache_is_not_eligible(self):
        self.app('Comet', 'ai.perplexity.comet')
        elsewhere = self.home / 'important'
        elsewhere.mkdir()
        profile = self.home / 'Library/Caches/Comet/Default'
        profile.mkdir(parents=True)
        (profile / 'Cache').symlink_to(elsewhere, target_is_directory=True)
        self.refresh()
        self.assertEqual(self.inventory.browser_targets()[0].status, 'review')

    def sparkle(self, cached='1.0', bundle='com.openai.codex', fresh=False):
        self.app('ChatGPT', 'com.openai.codex', '2.0')
        staging = self.home / 'Library/Caches/com.openai.codex/org.sparkle-project.Sparkle/Installation/stage'
        self.app('ChatGPT', bundle, cached, staging / 'extracted')
        if not fresh:
            os.utime(staging, (time.time()-172800, time.time()-172800))
        return staging

    def test_old_installer_eligible_but_newer_fresh_or_foreign_retained(self):
        staging = self.sparkle()
        self.refresh()
        self.assertEqual(self.inventory.installer_targets()[0].status, 'eligible')
        for cached, bundle, fresh in [('3.0', 'com.openai.codex', False),
                                      ('1.0', 'other.app', False),
                                      ('1.0', 'com.openai.codex', True)]:
            self.app('ChatGPT', bundle, cached, staging / 'extracted')
            if fresh: os.utime(staging, None)
            self.refresh()
            self.assertEqual(self.inventory.installer_targets()[0].status, 'review')

    def test_pending_newer_zip_is_preserved(self):
        self.app('OpenCode', 'ai.opencode', '1.0')
        archive = self.home / 'Library/Caches/@opencode-aidesktop-updater/pending/update.zip'
        archive.parent.mkdir(parents=True)
        with zipfile.ZipFile(archive, 'w') as output:
            output.writestr('OpenCode.app/Contents/Info.plist', plistlib.dumps({
                'CFBundleIdentifier': 'ai.opencode', 'CFBundleShortVersionString': '2.0'}))
        self.refresh()
        target = self.inventory.installer_targets()[0]
        self.assertEqual(target.status, 'review')
        self.assertIn('Newer', target.reason)

    def test_installer_cleanup_preserves_other_updater_payloads(self):
        self.app('OpenCode', 'ai.opencode', '2.0')
        other = self.marker('Library/Caches/@opencode-aidesktop-updater/pending/newer.dmg')
        archive = other.parent / 'old.zip'
        with zipfile.ZipFile(archive, 'w') as output:
            output.writestr('OpenCode.app/Contents/Info.plist', plistlib.dumps({
                'CFBundleIdentifier': 'ai.opencode', 'CFBundleShortVersionString': '1.0'}))
        os.utime(archive, (time.time()-172800, time.time()-172800))
        self.refresh()
        target = self.inventory.installer_targets()[0]
        self.assertEqual(target.status, 'eligible')
        with patch.object(self.inventory, 'collect', return_value=[target]):
            report.cleanup(self.inventory, target)
        self.assertFalse(archive.exists())
        self.assertTrue(other.exists())

    def test_cleanup_rechecks_activity(self):
        self.app('Comet', 'ai.perplexity.comet')
        marker = self.marker('Library/Caches/Comet/Default/Cache/data')
        self.refresh()
        target = self.inventory.browser_targets()[0]
        blocked = report.Target(target.path, 'browsers', 'in-use', 'Owner started')
        with patch.object(self.inventory, 'collect', return_value=[blocked]):
            self.assertIn('SKIPPED', report.cleanup(self.inventory, target))
        self.assertTrue(marker.exists())

    def test_only_cache_deleted_profile_preserved_and_rescue_supported(self):
        self.app('Comet', 'ai.perplexity.comet')
        marker = self.marker('Library/Caches/Comet/Default/Cache/data')
        profile = self.marker('Library/Application Support/Comet/Default/Cookies')
        self.refresh()
        target = self.inventory.browser_targets()[0]
        with patch.object(self.inventory, 'collect', return_value=[target]):
            self.assertEqual(report.cleanup(self.inventory, target), 'REMOVED')
        self.assertFalse(marker.exists())
        self.assertTrue(profile.exists())
        self.marker('Library/Caches/Comet/Default/Cache/data')
        with patch.object(self.inventory, 'collect', return_value=[target]):
            self.assertIn('MOVED TO TRASH', report.cleanup(self.inventory, target, rescue=True))
        self.assertEqual(len(list((self.home / '.Trash').glob('devpurge.*/Cache/data'))), 1)

    def test_oldstores_only_use_matching_native_manager(self):
        root = self.home / 'Library/pnpm/store'
        for v in ['v3', 'v10', 'v11']: (root / v).mkdir(parents=True)
        cli = self.marker('Library/pnpm/.tools/pnpm/10.33.0/node_modules/pnpm/bin/pnpm.cjs')
        self.refresh()
        def query(args, **kwargs):
            path = root / ('v11' if args[0] == 'pnpm' else 'v10')
            return subprocess.CompletedProcess(args, 0, str(path)+'\n', '')
        with patch.object(report, 'run', side_effect=query):
            targets = {Path(t.path).name: t for t in self.inventory.oldstore_targets()}
        self.assertEqual(targets['v11'].status, 'review')
        self.assertEqual(targets['v3'].status, 'review')
        self.assertEqual(targets['v10'].status, 'eligible')
        self.assertEqual(targets['v10'].command, ['node', str(cli), 'store', 'prune'])
        with patch.object(self.inventory, 'collect', return_value=[targets['v10']]), patch.object(report.subprocess, 'run') as command:
            self.assertIn('SKIPPED', report.cleanup(self.inventory, targets['v10'], rescue=True))
            command.assert_not_called()

    def test_ignored_targets_cannot_be_cleaned(self):
        self.app('Comet', 'ai.perplexity.comet')
        self.marker('Library/Caches/Comet/Default/Cache/data')
        self.refresh()
        with patch.object(self.inventory, 'refresh'), patch.dict(os.environ, IGNORE_TARGETS='browsers'):
            self.assertEqual(self.inventory.collect('browsers')[0].status, 'ignored')

    def test_unreadable_size_is_not_zero(self):
        target = report.Target('/missing', 'browsers')
        with patch.object(report, 'run', return_value=subprocess.CompletedProcess([], 1, '', '')):
            report.measure(target)
        self.assertIsNone(target.size_bytes)
        self.assertTrue(target.size_error)


if __name__ == '__main__':
    unittest.main()
