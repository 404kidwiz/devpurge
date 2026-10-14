#!/usr/bin/env python3
"""DevPurge's loopback-only graphical interface."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import threading
import webbrowser

from gui_model import Model

ASSETS = Path(__file__).parent / 'web'


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, model=None):
        self.model = model or Model()
        self.token = secrets.token_urlsafe(32)
        self.operation = threading.Lock()
        super().__init__(address, Handler)
        self.origin = 'http://127.0.0.1:' + str(self.server_port)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Do not log the session token or local file paths.

    def respond(self, code, body, kind='application/json'):
        if kind == 'application/json':
            body = json.dumps(body).encode()
        self.send_response(code)
        self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        self.end_headers()
        self.wfile.write(body)

    def valid_host(self):
        return self.headers.get('Host') == self.server.origin.removeprefix('http://')

    def do_GET(self):
        if not self.valid_host():
            self.respond(403, {'error': 'Invalid local host'})
            return
        routes = {'/': ('index.html', 'text/html; charset=utf-8'),
                  '/app.js': ('app.js', 'text/javascript; charset=utf-8'),
                  '/style.css': ('style.css', 'text/css; charset=utf-8')}
        asset = routes.get(self.path)
        if not asset:
            self.respond(404, {'error': 'Not found'})
            return
        self.respond(200, (ASSETS / asset[0]).read_bytes(), asset[1])

    def do_POST(self):
        if (not self.valid_host() or self.headers.get('Origin') != self.server.origin or
                not secrets.compare_digest(self.headers.get('X-DevPurge-Token', ''), self.server.token)):
            self.respond(403, {'error': 'Reopen the dashboard from devpurge --gui'})
            return
        if self.headers.get('Content-Type') != 'application/json':
            self.respond(415, {'error': 'JSON required'})
            return
        if not self.server.operation.acquire(blocking=False):
            self.respond(409, {'error': 'Another operation is running; wait for it to finish'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 65536:
                raise ValueError('Invalid request size')
            self.connection.settimeout(10)
            body = json.loads(self.rfile.read(length))
            if not isinstance(body, dict):
                raise ValueError('Request must be an object')
            if self.path == '/api/scan':
                result = self.server.model.scan()
            elif self.path == '/api/preview':
                result = self.server.model.preview(body.get('ids'), body.get('rescue'))
            elif self.path == '/api/clean':
                result = self.server.model.execute(body.get('plan'))
            else:
                self.respond(404, {'error': 'Not found'})
                return
            self.respond(200, result)
        except (ValueError, OSError) as error:
            self.respond(400, {'error': str(error)})
        except Exception:
            self.respond(500, {'error': 'Operation failed. Scan again before retrying.'})
        finally:
            self.server.operation.release()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--no-open', action='store_true')
    args = parser.parse_args()
    server = Server(('127.0.0.1', 0))
    url = server.origin + '/#' + server.token
    print('DevPurge GUI: ' + url, flush=True)
    print('Keep this terminal open. Press Ctrl+C to stop the dashboard.', flush=True)
    if not args.no_open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
