#!/usr/bin/env python3
"""Tiny upstream for gateway/test.sh. Speaks HTTP, or HTTPS when given a cert."""

import argparse
import json
import ssl
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Lock

RECORD_LOCK = Lock()


class Handler(BaseHTTPRequestHandler):
    record_path = ""
    stub_name = ""
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        self._finish()

    def do_POST(self):
        self._drain()
        self._finish()

    def do_DELETE(self):
        self._finish()

    def do_PUT(self):
        self._drain()
        self._finish()

    def do_PATCH(self):
        self._drain()
        self._finish()

    def do_HEAD(self):
        self._finish(body=b"")

    def _drain(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        remaining = length
        while remaining > 0:
            chunk = self.rfile.read(min(remaining, 65536))
            if not chunk:
                break
            remaining -= len(chunk)

    def _finish(self, body=b'{"ok":true}\n'):
        headers = {key.lower(): value for key, value in self.headers.items()}
        entry = {
            "stub": self.stub_name,
            "method": self.command,
            "path": self.path,
            "headers": headers,
        }
        with RECORD_LOCK:
            with open(self.record_path, "a", encoding="utf-8") as handle:
                handle.write(json.dumps(entry, separators=(",", ":")) + "\n")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError, ssl.SSLError, TimeoutError):
                return

    def log_message(self, fmt, *args):
        return


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--record", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--cert")
    parser.add_argument("--key")
    args = parser.parse_args()
    Handler.record_path = args.record
    Handler.stub_name = args.name
    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    server.timeout = 5
    if args.cert:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(args.cert, args.key)
        server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
