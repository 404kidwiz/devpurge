import http.client
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
from gui import Server
from gui_model import Model
from report import Inventory, Target


class ModelTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.model = Model(Inventory(self.home))
        self.target = Target(str(self.home / 'Library/Caches/test'), 'browsers', 'eligible')
        self.model.targets = {'known': self.target}

    def test_preview_required_and_single_use(self):
        with self.assertRaises(ValueError): self.model.execute('anything')
        plan = self.model.preview(['known'], False)
        with patch('gui_model.cleanup', return_value='REMOVED') as action:
            result = self.model.execute(plan['plan'])
            self.assertEqual(result['results'][0]['result'], 'REMOVED')
            action.assert_called_once_with(self.model.inventory, self.target, rescue=False)
            with self.assertRaises(ValueError): self.model.execute(plan['plan'])

    def test_arbitrary_paths_duplicate_and_ineligible_rejected(self):
        for ids in [['/Users/example/Documents'], ['known', 'known'], [], 'known']:
            with self.assertRaises(ValueError): self.model.preview(ids, False)
        self.target.status = 'in-use'
        with self.assertRaises(ValueError): self.model.preview(['known'], False)

    def test_rescue_config_and_ignore_enforced_after_preview(self):
        for config in ({'ignore': ['browsers']}, {'rescue_mode': True}):
            self.model.targets = {'known': self.target}
            path = self.home / '.devpurge.json'
            path.write_text('{}')
            plan = self.model.preview(['known'], False)
            path.write_text(json.dumps(config))
            with patch('gui_model.cleanup') as action:
                self.assertTrue(self.model.execute(plan['plan'])['results'][0]['result'].startswith('SKIPPED'))
                action.assert_not_called()

    def test_rescue_cannot_prune_native_store(self):
        self.target.command = ['pnpm', 'store', 'prune']
        with self.assertRaises(ValueError): self.model.preview(['known'], True)

    def test_expired_plan_and_rescan_invalidate(self):
        with patch('gui_model.time.monotonic', return_value=0):
            plan = self.model.preview(['known'], False)
        with patch('gui_model.time.monotonic', return_value=301):
            with self.assertRaises(ValueError): self.model.execute(plan['plan'])
        plan = self.model.preview(['known'], False)
        with patch.object(self.model.inventory, 'collect', return_value=[]): self.model.scan()
        with self.assertRaises(ValueError): self.model.execute(plan['plan'])

    def test_partial_failure_is_reported_and_stops_remaining(self):
        self.model.targets['two'] = Target('/unused', 'browsers', 'eligible')
        plan = self.model.preview(['known', 'two'], False)
        with patch('gui_model.cleanup', side_effect=OSError('denied')) as action:
            result = self.model.execute(plan['plan'])
            self.assertEqual(action.call_count, 1)
            self.assertTrue(result['results'][0]['result'].startswith('FAILED'))
            self.assertTrue(result['results'][1]['result'].startswith('SKIPPED'))

    def test_invalid_config_blocks_scan(self):
        (self.home / '.devpurge.json').write_text('{"rescue_mode":"false"}')
        with patch.object(self.model.inventory, 'collect') as action:
            with self.assertRaises(ValueError): self.model.scan()
            action.assert_not_called()

    def test_real_fixture_cleanup_preserves_unselected(self):
        self.target_path = Path(self.target.path)
        self.target_path.mkdir(parents=True)
        (self.target_path / 'cache').write_text('fixture')
        other = self.home / 'keep.txt'
        other.write_text('keep')
        plan = self.model.preview(['known'], False)
        with patch.object(self.model.inventory, 'collect', return_value=[self.target]):
            self.model.execute(plan['plan'])
        self.assertFalse(self.target_path.exists())
        self.assertEqual(other.read_text(), 'keep')


class HttpTests(unittest.TestCase):
    def setUp(self):
        self.server = Server(('127.0.0.1', 0))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def request(self, path, method='POST', body=None, **overrides):
        headers = {'Content-Type':'application/json', 'Origin':self.server.origin,
                   'X-DevPurge-Token':self.server.token}
        headers.update(overrides)
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port)
        connection.request(method, path, json.dumps(body or {}), headers)
        response = connection.getresponse()
        result = response.status, response.read(), response.getheaders()
        connection.close()
        return result

    def test_cross_origin_missing_token_and_host_rejected(self):
        with patch.object(self.server.model, 'scan') as scan:
            for headers in ({'Origin':'https://evil.test'}, {'X-DevPurge-Token':''}, {'Host':'evil.test'}):
                self.assertEqual(self.request('/api/scan', **headers)[0],403)
            scan.assert_not_called()

    def test_authenticated_scan_and_no_path_traversal(self):
        with patch.object(self.server.model, 'scan', return_value={'targets':[]}):
            self.assertEqual(self.request('/api/scan')[0],200)
        self.assertEqual(self.request('/../gui.py', method='GET')[0],404)
        status, body, headers = self.request('/', method='GET')
        self.assertEqual(status,200)
        self.assertNotIn(self.server.token.encode(),body)
        self.assertIn('Content-Security-Policy',dict(headers))

    def test_concurrent_mutations_rejected(self):
        with self.server.operation:
            self.assertEqual(self.request('/api/scan')[0],409)

    def test_malformed_request_and_unreviewed_cleanup_rejected(self):
        self.assertEqual(self.request('/api/preview',body={'ids':['untrusted'],'rescue':False})[0],400)
        self.assertEqual(self.request('/api/clean',body={'plan':'untrusted'})[0],400)
        self.assertEqual(self.request('/api/scan',**{'Content-Type':'text/plain'})[0],415)


if __name__ == '__main__':
    unittest.main()
