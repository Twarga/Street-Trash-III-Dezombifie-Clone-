import http.server, socketserver, ssl, os

PORT = 5178
ROOT = os.path.expanduser('~/projects/street_trash_dezombifier')
WEB_DIR = os.path.join(ROOT, 'builds/web')
CERT = os.path.join(ROOT, 'tools/certs/cert.pem')
KEY = os.path.join(ROOT, 'tools/certs/key.pem')

class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)
    def guess_type(self, path):
        if path.endswith('.wasm'):
            return 'application/wasm'
        if path.endswith('.pck'):
            return 'application/octet-stream'
        return super().guess_type(path)
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True

ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(certfile=CERT, keyfile=KEY)

with ThreadedTCPServer(('0.0.0.0', PORT), GodotWebHandler) as httpd:
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    print(f'Serving Street Trash: Dezombifier (HTTPS) on https://0.0.0.0:{PORT}/', flush=True)
    httpd.serve_forever()
