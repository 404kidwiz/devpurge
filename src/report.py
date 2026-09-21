#!/usr/bin/env python3
"""Read-only inventory and conservative, explicitly selected cache cleanup."""
import argparse
import concurrent.futures
from dataclasses import asdict, dataclass, field
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile


# Only web response/code caches, never profiles, cookies, or local storage.
BROWSERS = {
    'Comet': 'ai.perplexity.comet',
    'BrowserClaw': 'com.browseros.BrowserClaw',
    'BrowserOS': 'com.browseros.BrowserOS',
    'Google/Chrome': 'com.google.Chrome',
}
UPDATERS = {
    '@zcodedesktop-updater': 'ZCode',
    '@opencode-aidesktop-updater': 'OpenCode',
    '@granolaelectron-updater': 'Granola',
}
SPARKLE = ('com.openai.codex', 'com.browseros.BrowserClaw')


def run(args, timeout=15, cwd=None):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout, cwd=cwd)


def version(value):
    # Unknown/prerelease formats need review, never a guessed comparison.
    if not isinstance(value, str) or not re.fullmatch(r'\d+(?:\.\d+)*', value):
        raise ValueError('version format is not comparable')
    return tuple(int(part) for part in value.split('.'))


def app_info(path):
    with path.open('rb') as source:
        return plistlib.load(source)


@dataclass
class Target:
    path: str
    category: str
    status: str = 'review'
    reason: str = 'No supported safe cleanup action'
    command: list = field(default_factory=list)
    size_bytes: object = None
    size_error: str = ''


class Inventory:
    def __init__(self, home=None, app_roots=None):
        self.home = Path(home or Path.home()).resolve()
        self.cache = self.home / 'Library/Caches'
        self.app_roots = app_roots or [Path('/Applications'), self.home / 'Applications']
        self.apps = {}
        self.processes = ''
        self.open_paths = []
        self.mounted = []
        self.activity_error = ''

    def refresh(self):
        self.apps = {}
        for root in self.app_roots:
            for path in root.glob('*.app'):
                try:
                    info = app_info(path / 'Contents/Info.plist')
                    bundle = info['CFBundleIdentifier']
                    # More than one installed copy is ambiguous; keep them all.
                    self.apps.setdefault(bundle, []).append((path, info))
                except (OSError, ValueError, KeyError):
                    continue
        self.activity_error = ''
        try:
            ps = run(['ps', '-axo', 'args='])
            opened = run(['lsof', '-nP', '-F', 'n'], timeout=30)
            if ps.returncode or opened.returncode:
                raise ValueError('process or open-file inventory unavailable')
            self.processes = ps.stdout
            self.open_paths = [line[1:] for line in opened.stdout.splitlines() if line.startswith('n')]
            self.mounted = []
            if sys.platform == 'darwin':
                mounted = run(['hdiutil', 'info', '-plist'])
                if mounted.returncode:
                    raise ValueError('mounted-image inventory unavailable')
                self.mounted = [item.get('image-path', '') for item in
                                plistlib.loads(mounted.stdout.encode()).get('images', [])]
        except (OSError, ValueError, subprocess.TimeoutExpired) as error:
            self.activity_error = str(error)

    def active(self, path, bundle=None):
        if self.activity_error:
            return 'review', self.activity_error
        prefix = str(path) + '/'
        if any(p == str(path) or p.startswith(prefix) for p in self.open_paths + self.mounted):
            return 'in-use', 'Open files or a mounted disk image'
        if bundle:
            if bundle not in self.apps:
                return 'review', 'Owning app could not be identified'
            if any(str(app) + '/' in self.processes for app, _ in self.apps[bundle]):
                return 'in-use', 'Owning app is running'
        if any(name in self.processes for name in ('Autoupdate', 'ShipIt', 'org.sparkle-project')):
            return 'in-use', 'An app updater is running'
        return None

    def allowed_path(self, path):
        # Reject symlinks anywhere along the path and paths outside known roots.
        resolved = path.resolve()
        return (resolved == path and not path.is_symlink() and
                any(root in path.parents for root in
                    (self.cache, self.home / 'Library/pnpm/store', self.home / '.local/share/pnpm/store')))

    def classify(self, target, bundle=None):
        path = Path(target.path)
        if not self.allowed_path(path):
            target.status, target.reason = 'review', 'Symlink or path outside supported cache roots'
            return
        activity = self.active(path, bundle)
        if activity:
            target.status, target.reason = activity
        else:
            target.status, target.reason = 'eligible', 'Inactive cache; can be regenerated'

    def browser_targets(self):
        targets = []
        for directory, bundle in BROWSERS.items():
            root = self.cache / directory
            for profile in root.glob('*'):
                if profile.name != 'Default' and not re.fullmatch(r'Profile \d+', profile.name):
                    continue
                for name in ('Cache', 'Code Cache'):
                    path = profile / name
                    if path.exists():
                        target = Target(str(path), 'browsers')
                        self.classify(target, bundle)
                        targets.append(target)
        return targets

    def installed_version(self, bundle):
        copies = self.apps.get(bundle, [])
        if len(copies) != 1:
            raise ValueError('Installed app missing or multiple copies found')
        return version(copies[0][1]['CFBundleShortVersionString'])

    def installer_targets(self):
        targets = []
        for bundle in SPARKLE:
            root = self.cache / bundle / 'org.sparkle-project.Sparkle/Installation'
            for path in root.glob('*'):
                target = Target(str(path), 'installers')
                try:
                    infos = list(path.glob('*/*.app/Contents/Info.plist'))
                    if len(infos) != 1:
                        raise ValueError('Installer app/version could not be identified')
                    info = app_info(infos[0])
                    if info.get('CFBundleIdentifier') != bundle:
                        raise ValueError('Installer bundle does not match its cache owner')
                    if version(info['CFBundleShortVersionString']) > self.installed_version(bundle):
                        raise ValueError('Newer update is pending; retain it')
                    if time.time() - path.stat().st_mtime < 86400:
                        raise ValueError('Installer is less than one day old; retain it')
                    self.classify(target, bundle)
                except (OSError, ValueError, KeyError) as error:
                    target.reason = str(error)
                targets.append(target)
        for directory, app_name in UPDATERS.items():
            root = self.cache / directory
            if not root.exists():
                continue
            archives = list(root.rglob('*.zip'))
            if not archives:
                targets.append(Target(str(root), 'installers', reason='No identifiable updater archive'))
            for archive in archives:
                target = Target(str(archive), 'installers')
                try:
                    candidates = [(bundle, info) for bundle, copies in self.apps.items()
                                  for app, info in copies if app.stem.casefold() == app_name.casefold()]
                    if len(candidates) != 1:
                        raise ValueError('Installed app could not be uniquely identified')
                    bundle, _ = candidates[0]
                    with zipfile.ZipFile(archive) as data:
                        members = [n for n in data.namelist() if n.endswith('.app/Contents/Info.plist')
                                   and n.count('/') <= 3]
                        if len(members) != 1 or data.getinfo(members[0]).file_size > 1024 * 1024:
                            raise ValueError('Archive metadata is ambiguous or too large')
                        info = plistlib.loads(data.read(members[0]))
                    if info.get('CFBundleIdentifier') != bundle:
                        raise ValueError('Archive bundle does not match installed app')
                    if version(info['CFBundleShortVersionString']) > self.installed_version(bundle):
                        raise ValueError('Newer update is pending; retain it')
                    if time.time() - archive.stat().st_mtime < 86400:
                        raise ValueError('Archive is less than one day old; retain it')
                    self.classify(target, bundle)
                except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
                    target.reason = str(error)
                targets.append(target)
        return targets

    def oldstore_targets(self):
        targets = []
        active_store = None
        managers = {}
        try:
            result = run(['pnpm', 'store', 'path'], cwd=self.home)
            if result.returncode == 0 and result.stdout.strip().startswith('/'):
                active_store = Path(result.stdout.strip()).resolve()
            for tools in (self.home / 'Library/pnpm/.tools/pnpm',
                          self.home / '.local/share/pnpm/.tools/pnpm'):
                for package in tools.glob('*/node_modules/pnpm/bin/pnpm.cjs'):
                    if not re.fullmatch(r'\d+\.\d+\.\d+', package.parents[3].name):
                        continue
                    result = run(['node', str(package), 'store', 'path'], cwd=self.home)
                    if result.returncode == 0 and result.stdout.strip().startswith('/'):
                        managers[Path(result.stdout.strip()).resolve()] = ['node', str(package), 'store', 'prune']
        except (OSError, subprocess.TimeoutExpired):
            pass
        for root in (self.home / 'Library/pnpm/store', self.home / '.local/share/pnpm/store'):
            for path in root.glob('v*'):
                if not re.fullmatch(r'v\d+', path.name):
                    continue
                target = Target(str(path), 'oldstores')
                if active_store is None:
                    target.reason = 'Active pnpm store could not be verified'
                elif path.resolve() == active_store:
                    target.reason = 'Active pnpm store; use --node'
                elif path.resolve() not in managers:
                    target.reason = 'No installed pnpm version verified for this store; never delete it directly'
                elif re.search(r'\b(?:pnpm|npm)(?:\.cjs|\.js)?\s+(?:install|add|update|prune|store)\b', self.processes):
                    target.status, target.reason = 'in-use', 'A package manager is running'
                else:
                    self.classify(target)
                    target.command = managers[path.resolve()]
                    if target.status == 'eligible':
                        target.reason = 'Native pnpm prune only; savings are unknown'
                targets.append(target)
        return targets

    def collect(self, category=None):
        self.refresh()
        groups = {'browsers': self.browser_targets, 'installers': self.installer_targets,
                  'oldstores': self.oldstore_targets}
        targets = [target for name, collect in groups.items() if category in (None, name)
                   for target in collect()]
        if category is None:
            for path, reason in (
                ('.cache/uv', 'Use --uv for native pruning; installed runtimes may share these files'),
                ('.npm/_cacache', 'Use --node'),
                ('Library/Developer/Xcode/DerivedData', 'Close Xcode/builds, then use --mac'),
                ('Library/Caches/ms-playwright', 'Retain registered browser versions'),
                ('.cache/huggingface', 'Model files require individual review'),
                ('.cache/codex-runtimes', 'Installed runtimes require individual review'),
                ('Library/Containers/com.docker.docker/Data/vms', 'Docker VM includes persistent data; inspect through Docker'),
            ):
                full = self.home / path
                if full.exists():
                    state = self.active(full)
                    targets.append(Target(str(full), 'review', *(state or ('review', reason))))
        ignored = os.environ.get('IGNORE_TARGETS', '').split()
        for target in targets:
            if target.category in ignored:
                target.status, target.reason = 'ignored', 'Ignored by DevPurge configuration'
        return targets


def measure(target):
    try:
        result = run(['du', '-sk', target.path], timeout=30)
        if result.returncode:
            raise ValueError('Size unavailable: unreadable files')
        target.size_bytes = int(result.stdout.split()[0]) * 1024
    except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
        target.size_error = 'Size unavailable or scan timed out'
    return target


def cleanup(inventory, target, rescue=False):
    # Regenerate eligibility immediately before each action; no saved plan is executable.
    current = next((t for t in inventory.collect(target.category) if t.path == target.path), None)
    if current is None or current.status != 'eligible':
        return 'SKIPPED: ' + (current.reason if current else 'Target changed or disappeared')
    if current.command:
        if rescue:
            return 'SKIPPED: native pruning cannot be rescued to Trash'
        subprocess.run(current.command, cwd=inventory.home, check=True)
        return 'PRUNED'
    path = Path(current.path)
    if rescue:
        trash = inventory.home / '.Trash'
        trash.mkdir(exist_ok=True)
        destination = Path(tempfile.mkdtemp(prefix='devpurge.', dir=trash))
        shutil.move(str(path), str(destination / path.name))
        return 'MOVED TO TRASH (space not yet freed)'
    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()
    return 'REMOVED'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--category', choices=['browsers', 'installers', 'oldstores'])
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--rescue', action='store_true')
    args = parser.parse_args()
    if args.execute and (not args.category or args.json):
        parser.error('Execution requires one category and cannot use --json')
    inventory = Inventory()
    targets = inventory.collect(args.category)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        targets = list(pool.map(measure, targets))
    if args.json:
        print(json.dumps({'read_only': True, 'sizes_are_not_reclaimable_bytes': True,
                          'targets': [asdict(t) for t in targets]}, indent=2))
        return
    print('STATUS       SIZE       CATEGORY     PATH / REASON')
    for target in sorted(targets, key=lambda t: t.size_bytes or 0, reverse=True):
        size = f'{target.size_bytes / 1024**3:.2f} GiB' if target.size_bytes is not None else 'unknown'
        print(f'{target.status:12} {size:10} {target.category:12} {target.path}')
        print('  ' + target.reason + ('; ' + target.size_error if target.size_error else ''))
        if args.execute and target.status == 'eligible':
            print('  ' + cleanup(inventory, target, args.rescue))
    print('Sizes describe stored files, not guaranteed freed space. No targets are selected implicitly.')
    if not args.execute:
        print('Read-only report: no cleanup performed.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('DevPurge report failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
