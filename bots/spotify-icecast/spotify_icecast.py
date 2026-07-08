#!/usr/bin/env python3
"""Publica en Icecast el tema que suena en Spotify (now playing)."""

from __future__ import annotations

import argparse
import base64
import json
import logging
import os
import platform
import re
import socket
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any, Callable


def _load_config_env() -> None:
    # ponytail: config.env sin depender de bash (launchd, etc.)
    env_file = Path(__file__).with_name("config.env")
    if not env_file.exists():
        return
    for raw in env_file.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


_load_config_env()

# --- Config (config.env o entorno) ---
SPOTIFY_CLIENT_ID = os.environ.get("SPOTIFY_CLIENT_ID", "")
SPOTIFY_CLIENT_SECRET = os.environ.get("SPOTIFY_CLIENT_SECRET", "")
SPOTIFY_REDIRECT_URI = os.environ.get("SPOTIFY_REDIRECT_URI", "http://127.0.0.1:8765/callback")
# ponytail: solo lectura; sin user-modify-playback-state ni streaming
SPOTIFY_SCOPES = "user-read-currently-playing user-read-playback-state"

ICECAST_URL = os.environ.get("ICECAST_URL", "http://127.0.0.1:8000")
ICECAST_MOUNT = os.environ.get("ICECAST_MOUNT", "/radio")
ICECAST_ADMIN_USER = os.environ.get("ICECAST_ADMIN_USER", "admin")
ICECAST_ADMIN_PASSWORD = os.environ.get("ICECAST_ADMIN_PASSWORD", "")

POLL_SEC = float(os.environ.get("POLL_SEC", "3"))
IDLE_POLL_SEC = float(os.environ.get("IDLE_POLL_SEC", "15"))
# ponytail: AzuraCast/Mixxx pueden pisar metadata; republicar aunque no cambie el tema
REPUBLISH_SEC = float(os.environ.get("REPUBLISH_SEC", "15"))
AZURACAST_API_URL = os.environ.get("AZURACAST_API_URL", "https://azura.streamingradio.online")
AZURACAST_STATION_ID = os.environ.get("AZURACAST_STATION_ID", "17")
AZURACAST_API_KEY = os.environ.get("AZURACAST_API_KEY", "")

IRC_ENABLED = os.environ.get("IRC_ENABLED", "true").lower() in ("1", "true", "yes")
IRC_HOST = os.environ.get("IRC_HOST", "ceres.globalchat.org")
IRC_PORT = int(os.environ.get("IRC_PORT", "6697"))
IRC_NICK = os.environ.get("IRC_NICK", "QualiaSong")
IRC_USER = os.environ.get("IRC_USER", "qualiasong")
IRC_REALNAME = os.environ.get("IRC_REALNAME", "Now playing Qualia Radio")
IRC_CHANNEL = os.environ.get("IRC_CHANNEL", "#QualiaRadio")
NICKSERV_PASSWORD = os.environ.get("NICKSERV_PASSWORD", "")
IRC_LYRICS_ENABLED = os.environ.get("IRC_LYRICS_ENABLED", "true").lower() in ("1", "true", "yes")
IRC_LYRICS_MAX_LINES = int(os.environ.get("IRC_LYRICS_MAX_LINES", "12"))
IRC_LYRICS_LINE_DELAY = float(os.environ.get("IRC_LYRICS_LINE_DELAY", "0.35"))
IRC_MAX_LINE_BYTES = 510
# auto = AppleScript en macOS si no hay API; api = Spotify Web API
SPOTIFY_MODE = os.environ.get("SPOTIFY_MODE", "auto").lower()
STATE_FILE = Path(os.environ.get("STATE_FILE", Path(__file__).with_name("spotify_state.json")))

SPOTIFY_AUTH_URL = "https://accounts.spotify.com/authorize"
SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
SPOTIFY_NOW_PLAYING_URL = "https://api.spotify.com/v1/me/player/currently-playing"

log = logging.getLogger("spotify-icecast")


def _http(
    url: str,
    *,
    method: str = "GET",
    data: dict[str, str] | None = None,
    headers: dict[str, str] | None = None,
    auth: tuple[str, str] | None = None,
) -> tuple[int, bytes]:
    body = None
    hdrs = dict(headers or {})
    if data is not None:
        body = urllib.parse.urlencode(data).encode()
        hdrs.setdefault("Content-Type", "application/x-www-form-urlencoded")
    if auth:
        token = base64.b64encode(f"{auth[0]}:{auth[1]}".encode()).decode()
        hdrs["Authorization"] = f"Basic {token}"
    req = urllib.request.Request(url, data=body, headers=hdrs, method=method)
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def load_state() -> dict[str, Any]:
    if not STATE_FILE.exists():
        return {}
    return json.loads(STATE_FILE.read_text())


def save_state(state: dict[str, Any]) -> None:
    STATE_FILE.write_text(json.dumps(state, indent=2) + "\n")
    STATE_FILE.chmod(0o600)


def exchange_code(code: str) -> dict[str, Any]:
    status, raw = _http(
        SPOTIFY_TOKEN_URL,
        method="POST",
        data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SPOTIFY_REDIRECT_URI,
        },
        auth=(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET),
    )
    if status != 200:
        raise RuntimeError(f"Token Spotify ({status}): {raw.decode(errors='replace')}")
    return json.loads(raw)


def refresh_access_token(state: dict[str, Any]) -> dict[str, Any]:
    refresh = state.get("refresh_token")
    if not refresh:
        raise RuntimeError("Sin refresh_token. Ejecuta: ./run.sh auth")
    status, raw = _http(
        SPOTIFY_TOKEN_URL,
        method="POST",
        data={"grant_type": "refresh_token", "refresh_token": refresh},
        auth=(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET),
    )
    if status != 200:
        raise RuntimeError(f"Refresh Spotify ({status}): {raw.decode(errors='replace')}")
    data = json.loads(raw)
    state["access_token"] = data["access_token"]
    state["expires_at"] = int(time.time()) + int(data.get("expires_in", 3600)) - 60
    if data.get("refresh_token"):
        state["refresh_token"] = data["refresh_token"]
    save_state(state)
    return state


def ensure_access_token(state: dict[str, Any]) -> str:
    if not state.get("access_token") or int(state.get("expires_at", 0)) <= time.time():
        state = refresh_access_token(state)
    return str(state["access_token"])


def auth_flow() -> None:
    if not SPOTIFY_CLIENT_ID or not SPOTIFY_CLIENT_SECRET:
        sys.exit("Faltan SPOTIFY_CLIENT_ID y SPOTIFY_CLIENT_SECRET en config.env")

    code_holder: dict[str, str] = {}

    class CallbackHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path != "/callback":
                self.send_response(404)
                self.end_headers()
                return
            params = urllib.parse.parse_qs(parsed.query)
            if "error" in params:
                code_holder["error"] = params["error"][0]
            else:
                code_holder["code"] = params.get("code", [""])[0]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(
                b"<html><body><h1>Spotify conectado</h1>"
                b"<p>Puedes cerrar esta ventana y volver a la terminal.</p></body></html>"
            )

        def log_message(self, fmt: str, *args: Any) -> None:
            return

    host = urllib.parse.urlparse(SPOTIFY_REDIRECT_URI).hostname or "127.0.0.1"
    port = int(urllib.parse.urlparse(SPOTIFY_REDIRECT_URI).port or 8765)
    params = urllib.parse.urlencode(
        {
            "client_id": SPOTIFY_CLIENT_ID,
            "response_type": "code",
            "redirect_uri": SPOTIFY_REDIRECT_URI,
            "scope": SPOTIFY_SCOPES,
        }
    )
    url = f"{SPOTIFY_AUTH_URL}?{params}"
    print(
        "Permisos: solo lectura (qué suena ahora). "
        "No pausa, no cambia tema ni cierra tu sesión de Spotify.\n"
        "Abre esta URL si el navegador no se abre solo:\n",
        url,
        sep="",
    )
    webbrowser.open(url)

    server = HTTPServer((host, port), CallbackHandler)
    server.handle_request()
    server.server_close()

    if code_holder.get("error"):
        sys.exit(f"Spotify rechazó la autorización: {code_holder['error']}")
    code = code_holder.get("code", "")
    if not code:
        sys.exit("No llegó el código de autorización.")

    data = exchange_code(code)
    state = {
        "access_token": data["access_token"],
        "refresh_token": data["refresh_token"],
        "expires_at": int(time.time()) + int(data.get("expires_in", 3600)) - 60,
    }
    save_state(state)
    print(f"Tokens guardados en {STATE_FILE}")


def format_track(payload: dict[str, Any]) -> str | None:
    item = payload.get("item")
    if not item:
        return None
    artists = ", ".join(a.get("name", "") for a in item.get("artists", []) if a.get("name"))
    title = item.get("name", "").strip()
    if not title:
        return None
    return f"{artists} - {title}" if artists else title


def resolve_mode() -> str:
    if SPOTIFY_MODE in ("local", "api"):
        return SPOTIFY_MODE
    if SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET:
        return "api"
    if platform.system() == "Darwin":
        return "local"
    return "api"


def fetch_now_playing_local() -> tuple[str | None, bool]:
    # ponytail: solo lectura vía app Spotify en macOS; sin API ni OAuth
    # No lanzar Spotify si no está abierto (evita abrirlo en bucle).
    script = """
    tell application "System Events"
        if not (exists process "Spotify") then return "||stopped"
    end tell
    tell application "Spotify"
        if player state is stopped then
            return "||stopped"
        end if
        set trackName to name of current track
        set artistName to artist of current track
        set p to player state as string
        return artistName & "||" & trackName & "||" & p
    end tell
    """
    try:
        proc = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError(f"Spotify local ({exc})") from exc
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "Spotify no responde").strip()
        raise RuntimeError(f"Spotify local: {err}")
    parts = proc.stdout.strip().split("||", 2)
    if len(parts) == 1 and parts[0] == "stopped":
        return None, False
    if len(parts) < 3:
        return None, False
    artist, title, state = parts[0].strip(), parts[1].strip(), parts[2].strip().lower()
    if not title:
        return None, False
    song = f"{artist} - {title}" if artist else title
    return song, state == "playing"


def fetch_now_playing_api(access_token: str) -> tuple[str | None, bool]:
    status, raw = _http(
        SPOTIFY_NOW_PLAYING_URL,
        headers={"Authorization": f"Bearer {access_token}"},
    )
    if status == 204:
        return None, False
    if status == 401:
        raise PermissionError("token_expired")
    if status != 200:
        raise RuntimeError(f"Spotify now playing ({status}): {raw.decode(errors='replace')}")
    data = json.loads(raw)
    return format_track(data), bool(data.get("is_playing", True))


def split_song(song: str) -> tuple[str, str]:
    if " - " in song:
        artist, title = song.split(" - ", 1)
        return artist.strip(), title.strip()
    return "", song.strip()


def update_icecast(song: str) -> None:
    if not ICECAST_ADMIN_PASSWORD:
        raise RuntimeError("Falta ICECAST_ADMIN_PASSWORD en config.env")
    mount = ICECAST_MOUNT if ICECAST_MOUNT.startswith("/") else f"/{ICECAST_MOUNT}"
    query = urllib.parse.urlencode({"mount": mount, "mode": "updinfo", "song": song})
    url = f"{ICECAST_URL.rstrip('/')}/admin/metadata?{query}"
    status, raw = _http(url, auth=(ICECAST_ADMIN_USER, ICECAST_ADMIN_PASSWORD))
    if status not in (200, 204):
        raise RuntimeError(f"Icecast metadata ({status}): {raw.decode(errors='replace')}")


def update_azuracast(song: str) -> None:
    if not AZURACAST_API_KEY:
        return
    artist, title = split_song(song)
    url = f"{AZURACAST_API_URL.rstrip('/')}/api/station/{AZURACAST_STATION_ID}/nowplaying/update"
    status, raw = _http(
        url,
        method="POST",
        data={"title": title, "artist": artist},
        headers={"X-API-Key": AZURACAST_API_KEY, "Content-Type": "application/x-www-form-urlencoded"},
    )
    if status not in (200, 204):
        raise RuntimeError(f"AzuraCast metadata ({status}): {raw.decode(errors='replace')}")


def format_irc_now_playing(song: str) -> str:
    artist, title = split_song(song)
    if artist:
        return f"♪ AHORA SONANDO {artist} — {title}"
    return f"♪ AHORA SONANDO {title}"


def _irc_privmsg_max_payload_bytes(target: str) -> int:
    prefix = f"PRIVMSG {target.strip()} :"
    return max(0, IRC_MAX_LINE_BYTES - len(prefix.encode("utf-8")))


def chunk_irc_utf8(text: str, max_bytes: int) -> list[str]:
    if max_bytes <= 0:
        return [text]
    encoded = text.encode("utf-8")
    if len(encoded) <= max_bytes:
        return [text]
    chunks: list[str] = []
    start = 0
    while start < len(encoded):
        end = min(start + max_bytes, len(encoded))
        while end > start and end < len(encoded) and (encoded[end] & 0xC0) == 0x80:
            end -= 1
        if end <= start:
            end = min(start + max_bytes, len(encoded))
        chunks.append(encoded[start:end].decode("utf-8"))
        start = end
    return chunks


def _strip_synced_lyrics(text: str) -> str:
    lines: list[str] = []
    for line in text.splitlines():
        cleaned = re.sub(r"^\[\d+:\d+(?:\.\d+)?\]", "", line).strip()
        if cleaned:
            lines.append(cleaned)
    return "\n".join(lines)


def fetch_lyrics_lrclib(artist: str, title: str) -> str | None:
    params = urllib.parse.urlencode({"track_name": title, "artist_name": artist})
    status, raw = _http(f"https://lrclib.net/api/search?{params}")
    if status != 200:
        return None
    items = json.loads(raw)
    if not isinstance(items, list) or not items:
        return None

    artist_l = artist.lower()
    title_l = title.lower()

    def pick_plain(item: dict[str, Any]) -> str | None:
        plain = item.get("plainLyrics")
        if plain:
            return str(plain).strip()
        synced = item.get("syncedLyrics")
        if synced:
            return _strip_synced_lyrics(str(synced)).strip()
        return None

    for item in items:
        a = (item.get("artistName") or "").lower()
        t = (item.get("trackName") or "").lower()
        if artist_l and title_l and (artist_l in a or a in artist_l) and (title_l in t or t in title_l):
            lyrics = pick_plain(item)
            if lyrics:
                return lyrics

    for item in items:
        lyrics = pick_plain(item)
        if lyrics:
            return lyrics
    return None


def fetch_lyrics_ovh(artist: str, title: str) -> str | None:
    if not artist or not title:
        return None
    path = f"{urllib.parse.quote(artist)}/{urllib.parse.quote(title)}"
    status, raw = _http(f"https://api.lyrics.ovh/v1/{path}")
    if status != 200:
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    lyrics = data.get("lyrics")
    if isinstance(lyrics, str) and lyrics.strip():
        return lyrics.strip()
    return None


def fetch_lyrics(artist: str, title: str) -> str | None:
    if not title:
        return None
    lyrics = fetch_lyrics_lrclib(artist, title)
    if lyrics:
        return lyrics
    return fetch_lyrics_ovh(artist, title)


def lyrics_to_irc_lines(lyrics: str) -> list[str]:
    lines = [ln.strip() for ln in lyrics.splitlines() if ln.strip()]
    if IRC_LYRICS_MAX_LINES > 0:
        lines = lines[:IRC_LYRICS_MAX_LINES]
    return lines


def _irc_normalize_channel() -> str:
    channel = IRC_CHANNEL.strip()
    if not channel.startswith("#"):
        channel = f"#{channel}"
    return channel


class IRCPublisher:
    """Conexión IRC persistente: JOIN una vez y permanece visible en el canal."""

    def __init__(self) -> None:
        self._channel = _irc_normalize_channel()
        self._max_payload = _irc_privmsg_max_payload_bytes(self._channel)
        self._sock: ssl.SSLSocket | None = None
        self._lock = threading.Lock()
        self._ready = threading.Event()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if not IRC_ENABLED or self._thread is not None:
            return
        self._thread = threading.Thread(target=self._run, daemon=True, name="irc-publisher")
        self._thread.start()
        if not self._ready.wait(timeout=25):
            log.error("IRC: no se pudo conectar a %s en 25s", self._channel)

    def stop(self) -> None:
        self._stop.set()
        with self._lock:
            self._close()
        if self._thread is not None:
            self._thread.join(timeout=5)

    def _close(self) -> None:
        if self._sock is not None:
            try:
                self._sock.sendall(b"QUIT :bye\r\n")
            except OSError:
                pass
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None
        self._ready.clear()

    def _connect_and_join(self) -> None:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        sock = ctx.wrap_socket(
            socket.socket(socket.AF_INET, socket.SOCK_STREAM),
            server_hostname=IRC_HOST,
        )
        sock.settimeout(20)
        sock.connect((IRC_HOST, IRC_PORT))
        sock.sendall(f"NICK {IRC_NICK}\r\nUSER {IRC_USER} 0 * :{IRC_REALNAME}\r\n".encode())
        buf = b""
        registered = False
        while not registered:
            chunk = sock.recv(4096)
            if not chunk:
                raise RuntimeError("IRC desconectado antes del registro")
            buf += chunk
            while b"\r\n" in buf:
                line, buf = buf.split(b"\r\n", 1)
                text = line.decode("utf-8", errors="replace")
                if text.startswith("PING"):
                    sock.sendall(f"PONG :{text.split(':', 1)[-1].strip()}\r\n".encode())
                if re.search(r"\s001\s", text):
                    registered = True
                    break
        if NICKSERV_PASSWORD:
            sock.sendall(f"PRIVMSG NickServ :IDENTIFY {NICKSERV_PASSWORD}\r\n".encode())
        sock.sendall(f"JOIN {self._channel}\r\n".encode())
        joined = False
        deadline = time.time() + 12.0
        nick_re = re.escape(IRC_NICK)
        chan_re = re.escape(self._channel)
        while not joined and time.time() < deadline:
            chunk = sock.recv(4096)
            if not chunk:
                raise RuntimeError("IRC desconectado antes del JOIN")
            buf += chunk
            while b"\r\n" in buf:
                line, buf = buf.split(b"\r\n", 1)
                text = line.decode("utf-8", errors="replace")
                if text.startswith("PING"):
                    sock.sendall(f"PONG :{text.split(':', 1)[-1].strip()}\r\n".encode())
                if re.search(rf"\s366\s{nick_re}\s{chan_re}\s", text, re.I):
                    joined = True
                    break
                if re.search(rf":{nick_re}!.* JOIN :{chan_re}\b", text, re.I):
                    joined = True
                if re.search(r"\s40[0-9]\s|\s47[0-9]\s", text):
                    log.error("IRC JOIN: %s", text)
        if not joined:
            sock.close()
            raise RuntimeError(f"No se pudo unir a {self._channel}")
        self._sock = sock
        self._ready.set()
        log.info("IRC conectado y en %s como %s", self._channel, IRC_NICK)

    def _handle_inbound(self, buf: bytes) -> bytes:
        with self._lock:
            if self._sock is None:
                raise ConnectionError("sin socket")
            try:
                self._sock.settimeout(0.5)
                chunk = self._sock.recv(4096)
            except (TimeoutError, socket.timeout):
                return buf
            except OSError as exc:
                raise ConnectionError(f"recv falló: {exc}") from exc
            if not chunk:
                raise ConnectionError("IRC EOF")
            buf += chunk
            while b"\r\n" in buf:
                line, buf = buf.split(b"\r\n", 1)
                text = line.decode("utf-8", errors="replace")
                if text.startswith("PING"):
                    self._sock.sendall(f"PONG :{text.split(':', 1)[-1].strip()}\r\n".encode())
                if re.search(r"\s40[0-9]\s", text) or re.search(r"\s47[0-9]\s", text):
                    log.error("IRC servidor: %s", text)
            return buf

    def _run(self) -> None:
        buf = b""
        while not self._stop.is_set():
            try:
                with self._lock:
                    self._connect_and_join()
                while not self._stop.is_set():
                    try:
                        buf = self._handle_inbound(buf)
                    except ConnectionError as exc:
                        log.error("IRC recv: %s", exc)
                        break
            except Exception as exc:
                log.error("IRC desconectado (%s), reconectando en 5s…", exc)
                with self._lock:
                    self._close()
                time.sleep(5)

    def send_messages(self, messages: list[str], *, line_delay: float = 0.0) -> None:
        if not IRC_ENABLED or not messages:
            return
        if not self._ready.wait(timeout=20):
            log.error("IRC no disponible para enviar")
            return
        for msg in messages:
            for part in chunk_irc_utf8(msg, self._max_payload):
                with self._lock:
                    if self._sock is None:
                        return
                    self._sock.sendall(f"PRIVMSG {self._channel} :{part}\r\n".encode())
                log.info("IRC %s: %s", self._channel, part)
                if line_delay > 0:
                    time.sleep(line_delay)


_irc_publisher: IRCPublisher | None = None


def irc_connect_and_send(messages: list[str], *, line_delay: float = 0.0) -> None:
    global _irc_publisher
    if _irc_publisher is None:
        _irc_publisher = IRCPublisher()
        _irc_publisher.start()
    _irc_publisher.send_messages(messages, line_delay=line_delay)


def irc_announce(
    song: str,
    *,
    song_checker: Callable[[], tuple[str | None, bool]] | None = None,
) -> None:
    if not IRC_ENABLED:
        return

    def still_same() -> bool:
        if song_checker is None:
            return True
        current, playing = song_checker()
        return playing and current == song

    # Anuncio inmediato (no esperar a buscar la letra).
    irc_connect_and_send([format_irc_now_playing(song)], line_delay=0.0)
    if not still_same():
        log.info("Letra omitida: canción ya cambió tras el anuncio (%s)", song)
        return

    if not IRC_LYRICS_ENABLED:
        return

    artist, title = split_song(song)
    lyrics = fetch_lyrics(artist, title)
    if not still_same():
        log.info("Letra omitida: canción cambió mientras se buscaba (%s)", song)
        return
    if not lyrics:
        log.info("Sin letra disponible: %s", song)
        return

    lyric_lines = lyrics_to_irc_lines(lyrics)
    if not lyric_lines:
        log.info("Letra vacía tras filtrar: %s", song)
        return

    header = f"📝 Letra — {artist} — {title}:" if artist else f"📝 Letra — {title}:"
    log.info("Letra encontrada (%d líneas): %s", len(lyric_lines), song)
    irc_connect_and_send(
        [header, *lyric_lines],
        line_delay=IRC_LYRICS_LINE_DELAY,
    )


def _irc_announce_worker(
    song: str,
    mode: str,
    state: dict[str, Any],
) -> None:
    def song_checker() -> tuple[str | None, bool]:
        if mode == "local":
            return fetch_now_playing_local()
        token = ensure_access_token(state)
        return fetch_now_playing_api(token)

    try:
        irc_announce(song, song_checker=song_checker)
    except Exception as exc:
        log.error("IRC: %s", exc)


def irc_announce_async(song: str, mode: str, state: dict[str, Any]) -> None:
    threading.Thread(
        target=_irc_announce_worker,
        args=(song, mode, state),
        daemon=True,
        name=f"irc-{song[:24]}",
    ).start()


def publish_metadata(song: str) -> None:
    update_icecast(song)
    update_azuracast(song)


def run_loop(once: bool = False) -> None:
    mode = resolve_mode()
    state = load_state()
    if mode == "api" and not state.get("refresh_token"):
        sys.exit("Sin sesión Spotify. Ejecuta primero: ./run.sh auth")
    if mode == "local":
        log.info("Modo local (AppleScript): solo lectura, sin API de Spotify")

    global _irc_publisher
    if IRC_ENABLED:
        _irc_publisher = IRCPublisher()
        _irc_publisher.start()

    last_song: str | None = None
    last_published_at = 0.0
    try:
        while True:
            try:
                if mode == "local":
                    song, playing = fetch_now_playing_local()
                else:
                    token = ensure_access_token(state)
                    song, playing = fetch_now_playing_api(token)
                now = time.time()
                stale = playing and song and (now - last_published_at) >= REPUBLISH_SEC
                if song and (song != last_song or stale):
                    publish_metadata(song)
                    if song != last_song:
                        log.info("Publicado: %s", song)
                        irc_announce_async(song, mode, state)
                    else:
                        log.debug("Republicado: %s", song)
                    last_song = song
                    last_published_at = now
                elif not song and last_song is not None:
                    # ponytail: no pisar metadata de la radio; Spotify parado ≠ stream parado
                    log.info("Spotify sin reproducción (manteniendo: %s)", last_song)
                delay = POLL_SEC if playing and song else IDLE_POLL_SEC
            except PermissionError:
                state = refresh_access_token(state)
                delay = 1.0
            except Exception as exc:
                log.error("%s", exc)
                delay = IDLE_POLL_SEC

            if once:
                return
            time.sleep(delay)
    finally:
        if _irc_publisher is not None:
            _irc_publisher.stop()


def main() -> None:
    parser = argparse.ArgumentParser(description="Spotify now playing → Icecast metadata")
    parser.add_argument("command", nargs="?", choices=("auth", "run"), default="run")
    parser.add_argument("--once", action="store_true", help="Un ciclo y salir (prueba)")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    if args.command == "auth":
        auth_flow()
        return
    run_loop(once=args.once)


if __name__ == "__main__":
    # ponytail: self-check mínimo del formateo de pista
    assert format_track({"item": {"name": "Song", "artists": [{"name": "Artist"}]}}) == "Artist - Song"
    assert format_irc_now_playing("Artist - Song") == "♪ AHORA SONANDO Artist — Song"
    assert chunk_irc_utf8("hola", 10) == ["hola"]
    assert lyrics_to_irc_lines("a\n\nb") == ["a", "b"]
    main()
