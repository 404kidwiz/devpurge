"""UI-neutral controller: scan-derived IDs and single-use cleanup previews."""
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
import json
from pathlib import Path
import secrets
import shutil
import time

from report import Inventory, cleanup, measure


def settings(home):
    path = home / '.devpurge.json'
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict):
        raise ValueError('Configuration must be an object')
    for key in ('automated_sweep', 'rescue_mode'):
        if key in data and type(data[key]) is not bool:
            raise ValueError(key + ' must be a boolean')
    ignored = data.get('ignore', [])
    if not isinstance(ignored, list) or not all(isinstance(x, str) for x in ignored):
        raise ValueError('ignore must be a list of module names')
    days = data.get('interval_days', 7)
    if type(days) is not int or not 1 <= days <= 365:
        raise ValueError('interval_days must be an integer between 1 and 365')
    return data


class Model:
    def __init__(self, inventory=None):
        self.inventory = inventory or Inventory()
        self.targets = {}
        self.plan = None

    def scan(self):
        config = settings(self.inventory.home)
        self.targets = {}
        self.plan = None
        targets = self.inventory.collect()
        with ThreadPoolExecutor(max_workers=4) as pool:
            targets = list(pool.map(measure, targets))
        for target in targets:
            if target.category in config.get('ignore', []):
                target.status, target.reason = 'ignored', 'Ignored by DevPurge configuration'
            self.targets[secrets.token_hex(16)] = target
        disk = shutil.disk_usage(self.inventory.home)
        return {'targets': [dict(asdict(t), id=key) for key, t in self.targets.items()],
                'disk': {'total': disk.total, 'free': disk.free},
                'rescue': config.get('rescue_mode', False), 'scanned_at': time.time()}

    def preview(self, ids, rescue):
        self.plan = None
        if type(rescue) is not bool:
            raise ValueError('Choose a valid cleanup mode')
        if not isinstance(ids, list) or not ids or not all(isinstance(x, str) for x in ids):
            raise ValueError('Select eligible targets first')
        if len(set(ids)) != len(ids) or any(x not in self.targets for x in ids):
            raise ValueError('Selection is stale; scan again')
        targets = [self.targets[x] for x in ids]
        if any(t.status != 'eligible' for t in targets):
            raise ValueError('Only eligible targets can be selected')
        if rescue and any(t.command for t in targets):
            raise ValueError('Native pnpm pruning cannot move files to Trash; deselect pnpm stores')
        config = settings(self.inventory.home)
        if config.get('rescue_mode') and not rescue:
            raise ValueError('Rescue mode is enabled in your configuration')
        if any(t.category in config.get('ignore', []) for t in targets):
            raise ValueError('A selected group is now ignored; scan again')
        token = secrets.token_hex(24)
        self.plan = (token, targets, rescue, time.monotonic())
        return {'plan': token, 'rescue': rescue, 'targets': [asdict(t) for t in targets]}

    def execute(self, token):
        plan, self.plan = self.plan, None
        if not plan or not isinstance(token, str) or not secrets.compare_digest(token, plan[0]):
            raise ValueError('Review the selection before cleanup')
        _, targets, rescue, created = plan
        if time.monotonic() - created > 300:
            raise ValueError('Preview expired; review the selection again')
        self.targets = {}  # Every execution requires another scan, including failures.
        results = []
        for target in targets:
            try:
                config = settings(self.inventory.home)
                if target.category in config.get('ignore', []):
                    result = 'SKIPPED: group is now ignored'
                elif config.get('rescue_mode') and not rescue:
                    result = 'SKIPPED: rescue mode was enabled'
                else:
                    result = cleanup(self.inventory, target, rescue=rescue)
            except Exception as error:
                results.append({'path': target.path, 'result': 'FAILED: ' + str(error)})
                results.extend({'path': t.path, 'result': 'SKIPPED: earlier cleanup failed'}
                               for t in targets[len(results):])
                break
            results.append({'path': target.path, 'result': result})
        return {'results': results, 'free': shutil.disk_usage(self.inventory.home).free}
