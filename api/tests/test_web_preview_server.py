import importlib.util
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from urllib.request import urlopen


def test_pdf_modules_are_served_as_javascript_even_on_windows(tmp_path):
    spec = importlib.util.spec_from_file_location('serve_web', Path(__file__).parents[2] / 'scripts/serve_web.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    (tmp_path / 'pdf.min.mjs').write_text('export const test = true;', encoding='utf-8')
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(module.WebHandler, directory=str(tmp_path)))
    worker = Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        with urlopen(f'http://127.0.0.1:{server.server_port}/pdf.min.mjs') as response:
            assert response.headers.get_content_type() in ('text/javascript', 'application/javascript')
            assert response.read() == b'export const test = true;'
    finally:
        server.shutdown()
        server.server_close()
        worker.join()
