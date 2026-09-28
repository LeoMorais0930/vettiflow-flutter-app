"""Local Flutter preview with deterministic MIME types for the bundled PDF.js."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class WebHandler(SimpleHTTPRequestHandler):
    # Windows registry may otherwise classify .mjs as text/plain; ES modules refuse it.
    extensions_map = SimpleHTTPRequestHandler.extensions_map | {'.mjs': 'text/javascript'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=5174)
    args = parser.parse_args()
    directory = Path(__file__).resolve().parents[1] / 'build' / 'web'
    if not (directory / 'index.html').is_file():
        parser.error('Execute flutter build web antes de iniciar a prévia.')
    if not 1 <= args.port <= 65535:
        parser.error('Porta inválida.')
    with ThreadingHTTPServer(('127.0.0.1', args.port), partial(WebHandler, directory=str(directory))) as server:
        print(f'VettiFlow: http://127.0.0.1:{args.port}', flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
