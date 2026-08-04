#!/usr/bin/env python3
"""Servidor de desarrollo para irc_app (web).

Sirve la compilación de Flutter web (build/web) y emula los endpoints PHP
del entorno de producción para poder probar la app en local sin errores:

  GET  /api/avatar_image_proxy.php?url=<url>  -> proxy de imágenes (avatares)
  POST /api/avatar_upload_proxy.php           -> proxy de subida de avatar GIF
  GET  /radio-proxy/<host>/<path>             -> proxy de streams de radio

Uso:
  python3 dev_server.py [puerto]              (por defecto 8080)
"""
import os
import sys
import urllib.parse
from http.client import HTTPConnection, HTTPSConnection
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")
UPLOAD_TARGET = "https://xmlrpc.globalchat.org/avatar/upload-custom-avatar.php"
CHUNK = 65536


class DevHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BASE_DIR, **kwargs)

    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".json": "application/json",
        ".ttf": "font/ttf",
        ".otf": "font/otf",
        ".woff": "font/woff",
        ".woff2": "font/woff2",
    }

    # ----------------------------------------------------------- helpers
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers", "Content-Type, Range, Authorization"
        )

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def _open_upstream(self, url, method="GET", headers=None, body=None):
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme == "https":
            conn = HTTPSConnection(parsed.hostname, parsed.port or 443, timeout=20)
        else:
            conn = HTTPConnection(parsed.hostname, parsed.port or 80, timeout=20)
        path = parsed.path or "/"
        if parsed.query:
            path += "?" + parsed.query
        conn.request(method, path, body=body, headers=headers or {})
        return conn, conn.getresponse()

    def _stream_response(self, resp, extra_headers=None):
        try:
            self.send_response(resp.status)
            for header in (
                "Content-Type",
                "Content-Length",
                "Content-Disposition",
                "Accept-Ranges",
                "Cache-Control",
            ):
                value = resp.getheader(header)
                if value:
                    self.send_header(header, value)
            if extra_headers:
                for k, v in extra_headers.items():
                    self.send_header(k, v)
            self.end_headers()
            while True:
                chunk = resp.read(CHUNK)
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    break
        finally:
            conn = getattr(resp, "conn", None)
            if conn:
                conn.close()

    # ----------------------------------------------------- proxy endpoints
    def _handle_avatar_image_proxy(self):
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        target = (query.get("url") or [""])[0]
        if not target:
            self.send_error(400, "Falta el parámetro url")
            return
        headers = {}
        if self.headers.get("Range"):
            headers["Range"] = self.headers["Range"]
        try:
            conn, resp = self._open_upstream(target, headers=headers)
            resp.conn = conn
        except Exception as exc:
            self.log_error("avatar proxy upstream error: %s", exc)
            self.send_error(502, f"Error del upstream: {exc}")
            return
        self._stream_response(resp, {"Access-Control-Allow-Origin": "*"})

    def _handle_avatar_upload_proxy(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length > 0 else b""
        headers = {"Content-Type": self.headers.get("Content-Type", "")}
        try:
            conn, resp = self._open_upstream(
                UPLOAD_TARGET,
                method="POST",
                headers=headers,
                body=body,
            )
            resp.conn = conn
        except Exception as exc:
            self.log_error("avatar upload proxy upstream error: %s", exc)
            self.send_error(502, f"Error del upstream: {exc}")
            return
        self._stream_response(resp, {"Access-Control-Allow-Origin": "*"})

    def _handle_radio_proxy(self):
        # /radio-proxy/<host>/<path>?query
        rest = self.path[len("/radio-proxy/"):]
        split = rest.split("/", 1)
        host = split[0]
        remainder = "/" + split[1] if len(split) > 1 else "/"
        # Restaurar la query del request original
        if "?" in self.path and "?" not in remainder:
            q = self.path.split("?", 1)[1]
            remainder += "?" + q
        target = "http://" + host + remainder
        headers = {}
        if self.headers.get("Range"):
            headers["Range"] = self.headers["Range"]
        try:
            conn, resp = self._open_upstream(target, headers=headers)
            resp.conn = conn
        except Exception as exc:
            self.log_error("radio proxy upstream error: %s", exc)
            self.send_error(502, f"Error del upstream: {exc}")
            return
        self._stream_response(resp, {"Access-Control-Allow-Origin": "*"})

    # -------------------------------------------------------------- router
    def _is_proxy_path(self):
        return (
            self.path.startswith("/api/avatar_image_proxy.php")
            or self.path.startswith("/api/avatar_upload_proxy.php")
            or self.path.startswith("/radio-proxy/")
        )

    def do_GET(self):
        if self.path.startswith("/api/avatar_image_proxy.php"):
            self._handle_avatar_image_proxy()
        elif self.path.startswith("/radio-proxy/"):
            self._handle_radio_proxy()
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/avatar_upload_proxy.php"):
            self._handle_avatar_upload_proxy()
        else:
            self.send_error(404, "Not Found")


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    if not os.path.isdir(BASE_DIR):
        print(f"No se encontró {BASE_DIR}. Ejecuta primero: flutter build web")
        sys.exit(1)
    server = ThreadingHTTPServer(("0.0.0.0", port), DevHandler)
    print(f"🌐 Servidor dev en http://localhost:{port}")
    print(f"   Sirviendo: {BASE_DIR}")
    print("   Proxies: /api/avatar_image_proxy.php, /api/avatar_upload_proxy.php, /radio-proxy/*")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor detenido.")


if __name__ == "__main__":
    main()
