#!/usr/bin/env python3
"""Bot IRC Futbol — resultados del Mundial en #globalchat (GlobalChat)."""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import re
import signal
import ssl
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

# --- Config ---
IRC_HOST = os.environ.get("IRC_HOST", "ceres.globalchat.org")
IRC_PORT = int(os.environ.get("IRC_PORT", "6697"))
IRC_NICK = os.environ.get("IRC_NICK", "Futbol")
IRC_USER = os.environ.get("IRC_USER", "futbol")
IRC_REALNAME = os.environ.get("IRC_REALNAME", "Bot de resultados del Mundial - GlobalChat")
IRC_CHANNEL = os.environ.get("IRC_CHANNEL", "#globalchat")
NICKSERV_PASSWORD = os.environ.get("NICKSERV_PASSWORD", "")

# ponytail: API JSON pública que usa la web de Marca (sin clave ni scraping HTML)
MARCA_API = "https://api.unidadeditorial.es/sports/v1"
MARCA_EVENTS_PRESET = f"{MARCA_API}/events/preset/4_d141603f"
MARCA_EVENT_FULL = f"{MARCA_API}/events/{{match_id}}/full?site=2"
MARCA_STANDINGS = (
    f"{MARCA_API}/classifications/current/?site=2&type=10&tournament=0117&group={{group}}&season=2025"
)
WC_TOURNAMENT_ID = "0117"
TZ = ZoneInfo(os.environ.get("BOT_TIMEZONE", "Europe/Madrid"))
POLL_LIVE_SEC = int(os.environ.get("POLL_LIVE_SEC", "60"))
POLL_IDLE_SEC = int(os.environ.get("POLL_IDLE_SEC", "900"))
DAILY_SUMMARY_HOUR = int(os.environ.get("DAILY_SUMMARY_HOUR", "23"))
DAILY_SUMMARY_MIN = int(os.environ.get("DAILY_SUMMARY_MIN", "30"))
PREMATCH_ALERT_MIN = int(os.environ.get("PREMATCH_ALERT_MIN", "30"))
ONLINE_MSG_COOLDOWN_MIN = int(os.environ.get("ONLINE_MSG_COOLDOWN_MIN", "30"))
ADMIN_NICKS = {n.strip().lower() for n in os.environ.get("ADMIN_NICKS", "").split(",") if n.strip()}
STATE_FILE = Path(os.environ.get("STATE_FILE", Path(__file__).with_name("futbol_state.json")))
MAX_MSG = 400
MAX_HISTORY = 80
SCORE_RE = re.compile(r"(\d+)\s*[-:]\s*(\d+)")
UA = "Mozilla/5.0 (compatible; GlobalChat-Futbol-Bot/1.0)"

log = logging.getLogger("futbol")


def _log_task_error(task: asyncio.Task) -> None:
    if task.cancelled():
        return
    exc = task.exception()
    if exc:
        log.error("Tarea fallida: %s", exc, exc_info=exc)


def _spawn(coro: Any) -> asyncio.Task:
    task = asyncio.create_task(coro)
    task.add_done_callback(_log_task_error)
    return task

LIVE_PERIODS = {"1ª parte", "2ª parte", "En juego", "Descanso", "Prórroga", "Penaltis"}
FINISHED_PERIODS = {"Finalizado", "Ended"}
HT_PERIODS = {"Descanso"}

PRIVMSG_RE = re.compile(
    r"^:(?P<nick>[^!]+)![^ ]+ PRIVMSG (?P<target>\S+) :(?P<text>.*)$",
    re.I,
)
CMD_COOLDOWN_SEC = 3
_last_cmd_at: dict[str, float] = {}


# ---------------------------------------------------------------------------
# Marca (datos del Mundial)
# ---------------------------------------------------------------------------

def _marca_get(url: str) -> Any:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
        body = json.loads(resp.read().decode())
    if body.get("status") != "success":
        raise RuntimeError(f"Marca API: {body.get('data', body)}")
    return body.get("data")


def _parse_score(value: str | int | None) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def _normalize_event(raw: dict[str, Any]) -> dict[str, Any]:
    event = raw.get("event") or raw
    competitors = event["sportEvent"]["competitors"]
    home_team = competitors["homeTeam"]
    away_team = competitors["awayTeam"]
    home = home_team["commonName"]
    away = away_team["commonName"]
    score = event["score"]
    period = score["period"]["name"]
    period_start_time = score.get("period", {}).get("startTime", "")
    status = event.get("sportEvent", {}).get("status", {}).get("name") or period
    phase = event.get("sportEvent", {}).get("phase", {}).get("name") or "Mundial 2026"
    return {
        "id": event["id"],
        "home": home,
        "away": away,
        "home_country": home_team.get("country", ""),
        "away_country": away_team.get("country", ""),
        "home_score": _parse_score(score["homeTeam"]["totalScore"]),
        "away_score": _parse_score(score["awayTeam"]["totalScore"]),
        "period": period,
        "period_start_time": period_start_time,
        "status": status,
        "phase": phase,
        "start_date": event.get("startDate", ""),
        "stadium": (event.get("sportEvent", {}).get("location") or {}).get("name", ""),
        "goals": _extract_goals(event.get("scoreDetails", {}), home, away),
        "referees": event.get("sportEvent", {}).get("referees") or [],
        "cards": _extract_cards(event.get("statsDetails", {}), home, away),
        "substitutions": _extract_substitutions(event.get("statsDetails", {}), home, away),
    }


def _extract_goals(details: dict[str, Any], home: str, away: str) -> list[dict[str, Any]]:
    goals: list[dict[str, Any]] = []
    raw = (details or {}).get("goals") or {}
    for side, team in (("homeTeam", home), ("awayTeam", away)):
        for g in raw.get(side) or []:
            scorer = g.get("playerCommonName") or g.get("playerFullName") or "?"
            minute = g.get("matchTime", "?")
            detail = (g.get("type") or {}).get("typeName") or "gol"
            goals.append(
                {
                    # ponytail: Marca regenera _id en algunos eventos; esta firma estable evita flood.
                    "id": f"{team}:{minute}:{scorer}:{detail}".lower(),
                    "scorer": scorer,
                    "team": team,
                    "minute": minute,
                    "detail": detail,
                }
            )
    return goals


def _extract_cards(details: dict[str, Any], home: str, away: str) -> list[dict[str, Any]]:
    cards: list[dict[str, Any]] = []
    raw = (details or {}).get("discipline") or {}
    for side, team in (("homeTeam", home), ("awayTeam", away)):
        team_cards = raw.get(side) or {}
        for kind, icon in (("yellowCards", "🟨"), ("redCards", "🟥")):
            for card in team_cards.get(kind) or []:
                cards.append(
                    {
                        "id": card.get("_id")
                        or f"{team}-{kind}-{card.get('matchTime')}-{card.get('playerId')}",
                        "team": team,
                        "icon": icon,
                        "kind": kind,
                        "minute": card.get("matchTime", "?"),
                        "player": card.get("playerCommonName")
                        or card.get("playerFullName")
                        or "?",
                    }
                )
    return cards


def _extract_substitutions(details: dict[str, Any], home: str, away: str) -> list[dict[str, Any]]:
    subs: list[dict[str, Any]] = []
    raw = (details or {}).get("substitutions") or {}
    for side, team in (("homeTeam", home), ("awayTeam", away)):
        for sub in raw.get(side) or []:
            sub_on = sub.get("subOn") or {}
            sub_off = sub.get("subOff") or {}
            minute = sub.get("matchTime", "?")
            on_name = sub_on.get("playerCommonName") or sub_on.get("playerFullName") or "?"
            off_name = sub_off.get("playerCommonName") or sub_off.get("playerFullName") or "?"
            subs.append(
                {
                    "id": sub.get("_id") or f"{team}-{minute}-{on_name}-{off_name}",
                    "team": team,
                    "minute": minute,
                    "on": on_name,
                    "off": off_name,
                }
            )
    return subs


def _fetch_wc_day(day: str) -> list[dict[str, Any]]:
    data = _marca_get(f"{MARCA_EVENTS_PRESET}?date={day}")
    matches = []
    for raw in data:
        if (raw.get("tournament") or {}).get("id") != WC_TOURNAMENT_ID:
            continue
        matches.append(_normalize_event(raw))
    return matches


def fetch_wc_matches(day: str | None = None) -> list[dict[str, Any]]:
    if day:
        return _fetch_wc_day(day)
    # ponytail: un partido que arranca antes de medianoche queda asociado a "ayer"
    # en la API; mientras siga en juego debe contar como de hoy. Arrastramos solo
    # los no finalizados de ayer para no duplicar resultados ya cerrados.
    today = datetime.now(TZ).strftime("%Y-%m-%d")
    yesterday = (datetime.now(TZ) - timedelta(days=1)).strftime("%Y-%m-%d")
    matches = _fetch_wc_day(today)
    seen = {m["id"] for m in matches}
    try:
        for m in _fetch_wc_day(yesterday):
            if m["id"] not in seen and m["period"] not in FINISHED_PERIODS:
                matches.insert(0, m)
    except Exception as e:
        log.debug("Carga de ayer: %s", e)
    return matches


def fetch_match_full(match_id: str) -> dict[str, Any]:
    return _normalize_event(_marca_get(MARCA_EVENT_FULL.format(match_id=match_id)))


def fetch_standings() -> list[dict[str, Any]]:
    groups: list[dict[str, Any]] = []
    for group_num in range(1, 13):
        try:
            data = _marca_get(MARCA_STANDINGS.format(group=group_num))
        except Exception as e:
            log.debug("Clasificación grupo %s: %s", group_num, e)
            continue
        if not data:
            continue
        entry = data[0] if isinstance(data, list) else data
        head = entry.get("classificationHead") or {}
        gname = (head.get("group") or {}).get("name") or f"Grupo {group_num}"
        rows = []
        for row in entry.get("rank") or []:
            st = row.get("standing") or {}
            rows.append(
                {
                    "rank": st.get("position"),
                    "team": row.get("name") or row.get("fullName"),
                    "points": _parse_score(st.get("points")),
                    "played": _parse_score(st.get("played")),
                    "gd": _parse_score(st.get("goalsDiff")),
                }
            )
        if rows:
            groups.append({"name": gname, "rows": rows})
    return groups


# ---------------------------------------------------------------------------
# Estado persistente
# ---------------------------------------------------------------------------

@dataclass
class MatchState:
    match_id: str
    home: str
    away: str
    last_home: int = 0
    last_away: int = 0
    last_period: str = ""
    announced_start: bool = False
    announced_ht: bool = False
    announced_second_half: bool = False
    announced_ft: bool = False
    announced_prematch: bool = False
    announced_porra: bool = False
    seen_goals: set[str] = field(default_factory=set)
    seen_red_cards: set[str] = field(default_factory=set)
    seen_substitutions: set[str] = field(default_factory=set)


@dataclass
class BotState:
    matches: dict[str, MatchState] = field(default_factory=dict)
    last_summary_date: str = ""
    last_online_at: str = ""
    silent_mode: bool = False
    predictions: dict[str, dict[str, dict[str, Any]]] = field(default_factory=dict)
    alerts: dict[str, list[str]] = field(default_factory=dict)
    alert_nicks: dict[str, str] = field(default_factory=dict)
    sent_alerts: set[str] = field(default_factory=set)
    porra_scores: dict[str, int] = field(default_factory=dict)
    porra_nicks: dict[str, str] = field(default_factory=dict)
    history: list[dict[str, Any]] = field(default_factory=list)

    def to_json(self) -> dict[str, Any]:
        return {
            "last_summary_date": self.last_summary_date,
            "last_online_at": self.last_online_at,
            "silent_mode": self.silent_mode,
            "predictions": self.predictions,
            "alerts": self.alerts,
            "alert_nicks": self.alert_nicks,
            "sent_alerts": sorted(self.sent_alerts),
            "porra_scores": self.porra_scores,
            "porra_nicks": self.porra_nicks,
            "history": self.history[-MAX_HISTORY:],
            "matches": {
                k: {
                    "match_id": m.match_id,
                    "home": m.home,
                    "away": m.away,
                    "last_home": m.last_home,
                    "last_away": m.last_away,
                    "last_period": m.last_period,
                    "announced_start": m.announced_start,
                    "announced_ht": m.announced_ht,
                    "announced_second_half": m.announced_second_half,
                    "announced_ft": m.announced_ft,
                    "announced_prematch": m.announced_prematch,
                    "announced_porra": m.announced_porra,
                    "seen_goals": sorted(m.seen_goals),
                    "seen_red_cards": sorted(m.seen_red_cards),
                    "seen_substitutions": sorted(m.seen_substitutions),
                }
                for k, m in self.matches.items()
            },
        }

    @classmethod
    def from_json(cls, raw: dict[str, Any]) -> BotState:
        st = cls(
            last_summary_date=raw.get("last_summary_date", ""),
            last_online_at=raw.get("last_online_at", ""),
            silent_mode=bool(raw.get("silent_mode")),
            predictions=raw.get("predictions") or {},
            alerts=raw.get("alerts") or {},
            alert_nicks=raw.get("alert_nicks") or {},
            sent_alerts=set(raw.get("sent_alerts") or []),
            porra_scores={k: int(v) for k, v in (raw.get("porra_scores") or {}).items()},
            porra_nicks=raw.get("porra_nicks") or {},
            history=list(raw.get("history") or [])[-MAX_HISTORY:],
        )
        for k, m in (raw.get("matches") or {}).items():
            st.matches[k] = MatchState(
                match_id=m["match_id"],
                home=m["home"],
                away=m["away"],
                last_home=m.get("last_home", 0),
                last_away=m.get("last_away", 0),
                last_period=m.get("last_period", ""),
                announced_start=m.get("announced_start", False),
                announced_ht=m.get("announced_ht", False),
                announced_second_half=m.get("announced_second_half", False),
                announced_ft=m.get("announced_ft", False),
                announced_prematch=m.get("announced_prematch", False),
                announced_porra=m.get("announced_porra", False),
                seen_goals=set(m.get("seen_goals") or []),
                seen_red_cards=set(m.get("seen_red_cards") or []),
                seen_substitutions=set(m.get("seen_substitutions") or []),
            )
        return st


def load_state() -> BotState:
    if not STATE_FILE.exists():
        return BotState()
    try:
        return BotState.from_json(json.loads(STATE_FILE.read_text(encoding="utf-8")))
    except (json.JSONDecodeError, KeyError, TypeError):
        log.warning("Estado corrupto, empezando de cero")
        return BotState()


def save_state(state: BotState) -> None:
    STATE_FILE.write_text(json.dumps(state.to_json(), ensure_ascii=False, indent=2), encoding="utf-8")


@dataclass
class RuntimeContext:
    state: BotState
    channel_ops: set[str] = field(default_factory=set)
    bot_start: datetime = field(default_factory=lambda: datetime.now(TZ))
    bot: Any = None


def _is_admin(nick: str, ctx: RuntimeContext) -> bool:
    key = nick.lower()
    return key in ADMIN_NICKS or key in ctx.channel_ops


def _can_predict(match: dict[str, Any]) -> bool:
    return match["period"] not in FINISHED_PERIODS and not _is_live(match)


def _parse_prediction_args(args: list[str]) -> tuple[list[str], int, int] | None:
    text = " ".join(args)
    m = SCORE_RE.search(text)
    if not m:
        return None
    home, away = int(m.group(1)), int(m.group(2))
    rest = SCORE_RE.sub("", text).strip()
    return (rest.split() if rest else []), home, away


def _pick_match_for_prediction(
    matches: list[dict[str, Any]], name_parts: list[str]
) -> dict[str, Any] | None:
    if len(name_parts) >= 2:
        a, b = name_parts[0].lower(), " ".join(name_parts[1:]).lower()
        for match in matches:
            if not _can_predict(match):
                continue
            h, aw = match["home"].lower(), match["away"].lower()
            if (a in h and b in aw) or (a in aw and b in h):
                return match
    if name_parts:
        return _pick_match([m for m in matches if _can_predict(m)], name_parts)
    upcoming = sorted(
        [m for m in matches if _can_predict(m)],
        key=lambda m: m.get("start_date") or "",
    )
    return upcoming[0] if upcoming else None


def _porra_points(h_pred: int, a_pred: int, h_real: int, a_real: int) -> int:
    if h_pred == h_real and a_pred == a_real:
        return 3
    pred = (h_pred > a_pred) - (h_pred < a_pred)
    real = (h_real > a_real) - (h_real < a_real)
    return 1 if pred == real else 0


def _add_porra_points(state: BotState, nick_key: str, display: str, pts: int) -> None:
    if pts <= 0:
        return
    state.porra_scores[nick_key] = state.porra_scores.get(nick_key, 0) + pts
    state.porra_nicks[nick_key] = display


def format_porra_results(match: dict[str, Any], state: BotState) -> list[str]:
    preds = state.predictions.get(match["id"], {})
    if not preds:
        return []
    h, a = match["home_score"], match["away_score"]
    lines = [f"🎯 Porra {_team_title(match)}:"]
    exact, partial = [], []
    for nick_key, pred in preds.items():
        pts = _porra_points(pred["home"], pred["away"], h, a)
        display = pred.get("nick") or state.porra_nicks.get(nick_key, nick_key)
        _add_porra_points(state, nick_key, display, pts)
        txt = f"{display} {pred['home']}-{pred['away']}"
        if pts == 3:
            exact.append(txt)
        elif pts == 1:
            partial.append(f"{txt} (resultado)")
    if exact:
        lines.append("Exactos (+3): " + ", ".join(exact))
    if partial:
        lines.append("Resultado (+1): " + ", ".join(partial))
    if len(lines) == 1:
        lines.append("Nadie acertó marcador ni resultado.")
    return lines


def format_porra_ranking(state: BotState, limit: int = 10) -> list[str]:
    if not state.porra_scores:
        return ["🎯 Porra: aún no hay puntos. Usa !pronostico 2-1"]
    rows = sorted(state.porra_scores.items(), key=lambda r: (-r[1], r[0]))[:limit]
    lines = ["🎯 Ranking porra:"]
    for i, (nick_key, pts) in enumerate(rows, 1):
        display = state.porra_nicks.get(nick_key, nick_key)
        lines.append(f"  {i}. {display} — {pts} pt(s)")
    return lines


def format_my_predictions(nick: str, matches: list[dict[str, Any]], state: BotState) -> list[str]:
    nick_key = nick.lower()
    lines: list[str] = []
    for match in matches:
        pred = (state.predictions.get(match["id"]) or {}).get(nick_key)
        if pred:
            lines.append(f"  • {_team_title(match)} → {pred['home']}-{pred['away']}")
    if not lines:
        return [f"🎯 {nick}: sin pronósticos hoy. !pronostico 2-1 o !pronostico España 1-0"]
    return [f"🎯 Porra de {nick}:"] + lines


def format_match_predictions(match: dict[str, Any], state: BotState) -> list[str]:
    preds = state.predictions.get(match["id"], {})
    if not preds:
        return [f"🎯 Sin pronósticos para {_team_title(match)}."]
    lines = [f"🎯 Porra {_team_title(match)}:"]
    for nick_key, pred in preds.items():
        display = pred.get("nick") or nick_key
        lines.append(f"  {display}: {pred['home']}-{pred['away']}")
    return lines


def _team_matches_needle(needle: str, match: dict[str, Any]) -> bool:
    n = needle.lower()
    return n in match["home"].lower() or n in match["away"].lower()


def _users_for_team(state: BotState, team: str) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    for nick_key, teams in state.alerts.items():
        if any(team.lower() in t or t in team.lower() for t in teams):
            display = state.alert_nicks.get(nick_key, nick_key)
            out.append((nick_key, display))
    return out


def _users_for_match(state: BotState, match: dict[str, Any]) -> list[tuple[str, str]]:
    seen: set[str] = set()
    out: list[tuple[str, str]] = []
    for side in (match["home"], match["away"]):
        for nick_key, display in _users_for_team(state, side):
            if nick_key not in seen:
                seen.add(nick_key)
                out.append((nick_key, display))
    return out


async def _emit_alert(
    state: BotState,
    outgoing: asyncio.Queue[str],
    nick_key: str,
    display: str,
    event_key: str,
    msg: str,
) -> None:
    full_key = f"{nick_key}:{event_key}"
    if full_key in state.sent_alerts:
        return
    state.sent_alerts.add(full_key)
    await outgoing.put(f"🔔 {display}: {msg}")


async def _notify_match_alerts(
    state: BotState,
    outgoing: asyncio.Queue[str],
    match: dict[str, Any],
    event: str,
    msg: str,
) -> None:
    if state.silent_mode:
        return
    event_key = f"{match['id']}:{event}"
    for nick_key, display in _users_for_match(state, match):
        await _emit_alert(state, outgoing, nick_key, display, event_key, msg)


def _append_history(state: BotState, match: dict[str, Any]) -> None:
    entry = {
        "date": datetime.now(TZ).strftime("%Y-%m-%d"),
        "id": match["id"],
        "home": match["home"],
        "away": match["away"],
        "home_score": match["home_score"],
        "away_score": match["away_score"],
        "phase": match.get("phase", ""),
    }
    state.history = [h for h in state.history if h.get("id") != match["id"]]
    state.history.append(entry)
    state.history = state.history[-MAX_HISTORY:]


def format_history_list(entries: list[dict[str, Any]], title: str) -> list[str]:
    if not entries:
        return [f"{title}: sin datos."]
    lines = [title + ":"]
    for e in reversed(entries[-15:]):
        lines.append(
            f"  • {_flag(e.get('home_country', ''))} {e['home']} {e['home_score']}-{e['away_score']} "
            f"{_flag(e.get('away_country', ''))} {e['away']} ({e.get('phase', '')}) [{e.get('date', '')}]"
        )
    return lines


async def _maybe_put(outgoing: asyncio.Queue[str], state: BotState, msg: str) -> None:
    if not state.silent_mode:
        await outgoing.put(msg)


# ---------------------------------------------------------------------------
# Mensajes IRC
# ---------------------------------------------------------------------------

def format_goal(match: dict[str, Any], goal: dict[str, Any]) -> str:
    return (
        f"⚽ ¡GOL! {goal['scorer']} ({goal['team']}) {goal['minute']}' — "
        f"{_match_label(match)} "
        f"[{goal['detail']}]"
    )


def format_score_only(match: dict[str, Any], team: str) -> str:
    return (
        f"⚽ ¡GOL de {team}! — "
        f"{_match_label(match)}"
    )


def format_ht(match: dict[str, Any]) -> str:
    return (
        f"⏸️ DESCANSO — {_match_label(match)} ({match['phase']})"
    )


def format_ft(match: dict[str, Any]) -> str:
    return (
        f"🏁 FINAL — {_match_label(match)} ({match['phase']})"
    )


def format_start(match: dict[str, Any]) -> str:
    return f"🚩 Empieza — {_team_title(match)} ({match['phase']})"


def format_second_half(match: dict[str, Any]) -> str:
    return f"▶️ Arranca la segunda parte — {_match_label(match)}"


def format_match_end_summary(match: dict[str, Any]) -> list[str]:
    lines = [f"📌 {_match_label(match)} — {match.get('phase', '')}"]
    goals = match.get("goals") or []
    if goals:
        lines.append(
            "Goles: " + ", ".join(f"{g['minute']}' {g['scorer']}" for g in goals[:8])
        )
    cards = match.get("cards") or []
    reds = [c for c in cards if c.get("kind") == "redCards"]
    yellows = [c for c in cards if c.get("kind") == "yellowCards"]
    if reds or yellows:
        parts = []
        if yellows:
            parts.append(f"🟨 {len(yellows)}")
        if reds:
            parts.append(f"🟥 {len(reds)}")
        lines.append("Tarjetas: " + ", ".join(parts))
    subs = match.get("substitutions") or []
    if subs:
        lines.append(
            "Cambios: "
            + ", ".join(f"{s['minute']}' {s['on']}←{s['off']}" for s in subs[:4])
            + (f" (+{len(subs) - 4})" if len(subs) > 4 else "")
        )
    return lines


def format_prematch(match: dict[str, Any]) -> str:
    return f"⏰ En {PREMATCH_ALERT_MIN} min: {_team_title(match)} ({match['phase']})"


def format_next_match(match: dict[str, Any]) -> str:
    raw = match.get("start_date")
    time_txt = "hora por confirmar"
    if raw:
        kickoff = datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(TZ)
        time_txt = kickoff.strftime("%H:%M")
    return f"⏭️ Próximo: {_team_title(match)} a las {time_txt} ({match['phase']})"


def format_referee(match: dict[str, Any]) -> str:
    refs = ", ".join(match.get("referees") or [])
    if not refs:
        return f"👮 Árbitro {match['home']} - {match['away']}: sin datos."
    return f"👮 Árbitro {match['home']} - {match['away']}: {refs}"


def format_stadium(match: dict[str, Any]) -> str:
    stadium = match.get("stadium") or "sin datos"
    return f"🏟️ Estadio {match['home']} - {match['away']}: {stadium}"


def format_cards(match: dict[str, Any]) -> list[str]:
    cards = match.get("cards") or []
    if not cards:
        return [f"🟨 Tarjetas {match['home']} - {match['away']}: sin tarjetas."]
    lines = [f"🟨 Tarjetas {match['home']} - {match['away']}:"]
    for card in cards:
        lines.append(f"  {card['icon']} {card['minute']}' {card['player']} ({card['team']})")
    return lines


def format_red_card(match: dict[str, Any], card: dict[str, Any]) -> str:
    return f"🟥 ROJA — {card['player']} ({card['team']}) {card['minute']}' — {_match_label(match)}"


def format_substitution(match: dict[str, Any], sub: dict[str, Any]) -> str:
    return f"🔄 Cambio {sub['team']} {sub['minute']}': entra {sub['on']}, sale {sub['off']}"


def format_substitutions(match: dict[str, Any]) -> list[str]:
    subs = match.get("substitutions") or []
    if not subs:
        return [f"🔄 Cambios {match['home']} - {match['away']}: sin cambios."]
    lines = [f"🔄 Cambios {match['home']} - {match['away']}:"]
    for sub in subs:
        lines.append(f"  {sub['minute']}' {sub['team']}: {sub['on']} por {sub['off']}")
    return lines


def format_minute(match: dict[str, Any]) -> str:
    minute = _match_minute(match)
    minute_txt = f"min. {minute} aprox." if minute is not None else match["period"]
    return f"⏱️ {_match_label(match)} — {minute_txt} ({match['period']})"


def format_day_overview(matches: list[dict[str, Any]]) -> list[str]:
    live = [m for m in matches if _is_live(m)]
    finished = [m for m in matches if m["period"] in FINISHED_PERIODS]
    upcoming = [m for m in matches if m["period"] not in FINISHED_PERIODS and not _is_live(m)]
    lines = [
        f"🌍 Mundial hoy: {len(matches)} partido(s), {len(live)} en juego, "
        f"{len(finished)} finalizado(s), {len(upcoming)} pendiente(s)."
    ]
    if live:
        lines.extend(format_matches_list(live, "🔴 En juego")[1:])
    if finished:
        lines.extend(format_matches_list(finished, "🏁 Finalizados")[1:])
    if upcoming:
        lines.extend(format_matches_list(upcoming[:3], "⏭️ Próximos")[1:])
    return lines


def format_daily_summary(matches: list[dict[str, Any]], standings: list[dict[str, Any]]) -> list[str]:
    today = datetime.now(TZ).strftime("%d/%m/%Y")
    lines = [f"📅 Resumen del día {today} — Mundial 2026"]

    finished = [m for m in matches if m["period"] in FINISHED_PERIODS]
    if finished:
        lines.append("Partidos:")
        for m in finished:
            lines.append(
                f"  • {_match_label(m)} ({m['phase']})"
            )
    else:
        lines.append("Sin partidos finalizados hoy.")

    if standings:
        lines.append("Clasificación:")
        for group in standings:
            lines.append(f"  [{group['name']}]")
            for row in group["rows"][:4]:
                lines.append(
                    f"    {row['rank']}. {row['team']} — {row['points']} pts "
                    f"({row['played']}PJ, DG {row['gd']:+d})"
                )
    return lines


def format_standings_group(group: dict[str, Any]) -> list[str]:
    lines = [f"📊 {group['name']}:"]
    for row in group["rows"]:
        lines.append(
            f"  {row['rank']}. {row['team']} — {row['points']} pts "
            f"({row['played']}PJ, DG {row['gd']:+d})"
        )
    return lines


def format_standings_compact(groups: list[dict[str, Any]]) -> list[str]:
    lines = ["📊 Clasificación (top 2 por grupo):"]
    for group in groups:
        tops = ", ".join(
            f"{r['rank']}. {r['team']} ({r['points']}pts)" for r in group["rows"][:2]
        )
        lines.append(f"  {group['name']}: {tops}")
    return lines


def format_matches_list(matches: list[dict[str, Any]], title: str) -> list[str]:
    if not matches:
        return [f"{title}: ninguno ahora mismo."]
    lines = [title + ":"]
    for m in matches:
        lines.append(
            f"  • {_match_label(m)} "
            f"({m['period']}) [{m['phase']}]"
        )
    return lines


def format_scorers_from_matches(matches: list[dict[str, Any]]) -> list[str]:
    scorers: dict[str, dict[str, Any]] = {}
    for match in matches:
        for goal in match.get("goals") or []:
            key = goal["scorer"].lower()
            current = scorers.setdefault(
                key,
                {"name": goal["scorer"], "team": goal["team"], "goals": 0},
            )
            current["goals"] += 1
    if not scorers:
        return ["🥅 Goleadores de hoy: sin goles registrados."]
    rows = sorted(scorers.values(), key=lambda row: (-row["goals"], row["name"]))[:10]
    lines = ["🥅 Goleadores de hoy:"]
    for i, row in enumerate(rows, 1):
        lines.append(f"  {i}. {row['name']} ({row['team']}) — {row['goals']} gol(es)")
    return lines


def _match_label(match: dict[str, Any]) -> str:
    return (
        f"{_flag(match.get('home_country', ''))} {match['home']} "
        f"{match['home_score']}-{match['away_score']} "
        f"{_flag(match.get('away_country', ''))} {match['away']}"
    ).replace("  ", " ").strip()


def _team_title(match: dict[str, Any]) -> str:
    return (
        f"{_flag(match.get('home_country', ''))} {match['home']} - "
        f"{_flag(match.get('away_country', ''))} {match['away']}"
    ).replace("  ", " ").strip()


def _flag(country: str) -> str:
    country = (country or "").upper()
    if len(country) != 3:
        return ""
    # ISO-3166 alpha-3 -> alpha-2 para las selecciones que usa Marca en el Mundial.
    alpha2 = {
        "ARG": "AR", "AUS": "AU", "AUT": "AT", "BEL": "BE", "BIH": "BA",
        "BRA": "BR", "CAN": "CA", "CIV": "CI", "COD": "CD", "COL": "CO",
        "CRI": "CR", "CUW": "CW", "DEU": "DE", "ECU": "EC", "ESP": "ES",
        "FRA": "FR", "GBR": "GB", "GHA": "GH", "IRN": "IR", "ITA": "IT",
        "JPN": "JP", "KOR": "KR", "MAR": "MA", "MEX": "MX", "NLD": "NL",
        "NOR": "NO", "POL": "PL", "PRT": "PT", "PRY": "PY", "SAU": "SA",
        "SEN": "SN", "SRB": "RS", "SWE": "SE", "TUR": "TR", "UKR": "UA",
        "URY": "UY", "USA": "US", "ZAF": "ZA",
    }.get(country)
    if not alpha2:
        return ""
    return "".join(chr(127397 + ord(ch)) for ch in alpha2)


def _match_minute(match: dict[str, Any]) -> int | None:
    raw = match.get("period_start_time")
    if not raw or match["period"] not in {"1ª parte", "2ª parte", "Prórroga"}:
        return None
    start = datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(TZ)
    elapsed = max(1, int((datetime.now(TZ) - start).total_seconds() // 60) + 1)
    if match["period"] == "2ª parte":
        return 45 + elapsed
    if match["period"] == "Prórroga":
        return 90 + elapsed
    return elapsed


def _started_recently(match: dict[str, Any], now: datetime, minutes: int = 5) -> bool:
    raw = match.get("start_date")
    if not raw:
        return False
    kickoff = datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(TZ)
    delta = now - kickoff
    return timedelta(0) <= delta <= timedelta(minutes=minutes)


def _pick_match(matches: list[dict[str, Any]], args: list[str]) -> dict[str, Any] | None:
    if args:
        needle = " ".join(args).lower()
        for match in matches:
            if needle in match["home"].lower() or needle in match["away"].lower():
                return match
        return None
    live = [m for m in matches if _is_live(m)]
    if live:
        return live[0]
    upcoming = sorted(
        [m for m in matches if m["period"] not in FINISHED_PERIODS],
        key=lambda m: m.get("start_date") or "",
    )
    return upcoming[0] if upcoming else (matches[-1] if matches else None)


def _group_key(arg: str) -> int | None:
    arg = arg.strip().upper()
    if not arg:
        return None
    if arg.isdigit():
        n = int(arg)
        return n if 1 <= n <= 12 else None
    if len(arg) == 1 and "A" <= arg <= "L":
        return ord(arg) - ord("A") + 1
    m = re.fullmatch(r"GRUPO\s*([A-L]|\d{1,2})", arg, re.I)
    if m:
        return _group_key(m.group(1))
    return None


HELP_TEXT = (
    "⚽ !partidos !directo !resultados !proximo !minuto [eq] !equipo <eq> | "
    "!clasificacion [A-L|all] !goleadores | !pronostico !miporra !porra | "
    "!avisame <eq> !misavisos !borraravisos | !ayer !ultimos !historial <eq>"
)


async def run_command(nick: str, text: str, outgoing: asyncio.Queue[str], ctx: RuntimeContext) -> None:
    if nick.lower() == IRC_NICK.lower():
        return
    text = text.strip()
    if not text.startswith("!"):
        return

    now = asyncio.get_event_loop().time()
    last = _last_cmd_at.get(nick.lower(), 0)
    if now - last < CMD_COOLDOWN_SEC:
        return
    _last_cmd_at[nick.lower()] = now

    parts = text[1:].split()
    if not parts:
        return
    cmd = parts[0].lower()
    args = parts[1:]

    try:
        if cmd in ("ayuda", "help", "comandos"):
            await outgoing.put(HELP_TEXT)
            return

        if cmd in ("partidos", "hoy", "calendario"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            for line in format_matches_list(matches, "📅 Partidos de hoy"):
                await outgoing.put(line)
            return

        if cmd in ("resumen", "mundial", "estado"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            for line in format_day_overview(matches):
                await outgoing.put(line)
            return

        if cmd in ("minuto", "marcador"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            match = _pick_match(matches, args)
            if not match:
                await outgoing.put("⏱️ No encuentro ese partido hoy.")
                return
            if _is_live(match):
                try:
                    match = await asyncio.to_thread(fetch_match_full, match["id"])
                except Exception:
                    pass
            await outgoing.put(format_minute(match))
            return

        if cmd in ("proximo", "próximo", "siguiente"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            now = datetime.now(TZ)
            upcoming = [
                m for m in matches
                if m["period"] not in FINISHED_PERIODS and not _is_live(m)
            ]
            upcoming.sort(key=lambda m: m.get("start_date") or "")
            target = next((m for m in upcoming if not m.get("start_date") or _kickoff_in(m, now, 48)), None)
            if not target:
                await outgoing.put("⏭️ No quedan más partidos programados hoy.")
                return
            await outgoing.put(format_next_match(target))
            return

        if cmd in ("directo", "enjuego", "live"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            live = [m for m in matches if _is_live(m)]
            for line in format_matches_list(live, "🔴 En juego"):
                await outgoing.put(line)
            return

        if cmd in ("resultados", "finalizados"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            done = [m for m in matches if m["period"] in FINISHED_PERIODS]
            for line in format_matches_list(done, "🏁 Finalizados hoy"):
                await outgoing.put(line)
            return

        if cmd in ("goleadores", "bota", "pichichi"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            full_matches = []
            for match in matches:
                try:
                    full_matches.append(await asyncio.to_thread(fetch_match_full, match["id"]))
                except Exception:
                    full_matches.append(match)
            for line in format_scorers_from_matches(full_matches):
                await outgoing.put(line)
            return

        if cmd in ("clasificacion", "clasificación", "grupo", "grupos"):
            arg = " ".join(args)
            if arg.lower() in ("", "all", "todo", "todos"):
                groups = await asyncio.to_thread(fetch_standings)
                for line in format_standings_compact(groups):
                    await outgoing.put(line)
                return
            gnum = _group_key(arg)
            if gnum is None:
                await outgoing.put("Usa: !clasificacion A  (grupos A-L)  o  !clasificacion all")
                return
            groups = await asyncio.to_thread(fetch_standings)
            target = next((g for i, g in enumerate(groups, 1) if i == gnum), None)
            if not target:
                await outgoing.put(f"No hay datos del grupo {arg.upper()}.")
                return
            for line in format_standings_group(target):
                await outgoing.put(line)
            return

        if cmd in ("arbitro", "árbitro", "var"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            match = _pick_match(matches, args)
            if not match:
                await outgoing.put("👮 No encuentro ese partido hoy.")
                return
            try:
                match = await asyncio.to_thread(fetch_match_full, match["id"])
            except Exception:
                pass
            await outgoing.put(format_referee(match))
            return

        if cmd in ("tarjetas", "amarillas", "rojas"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            match = _pick_match(matches, args)
            if not match:
                await outgoing.put("🟨 No encuentro ese partido hoy.")
                return
            try:
                match = await asyncio.to_thread(fetch_match_full, match["id"])
            except Exception:
                pass
            for line in format_cards(match):
                await outgoing.put(line)
            return

        if cmd in ("cambios", "sustituciones"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            match = _pick_match(matches, args)
            if not match:
                await outgoing.put("🔄 No encuentro ese partido hoy.")
                return
            try:
                match = await asyncio.to_thread(fetch_match_full, match["id"])
            except Exception:
                pass
            for line in format_substitutions(match):
                await outgoing.put(line)
            return

        if cmd in ("estadio", "sede", "campo"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            match = _pick_match(matches, args)
            if not match:
                await outgoing.put("🏟️ No encuentro ese partido hoy.")
                return
            try:
                match = await asyncio.to_thread(fetch_match_full, match["id"])
            except Exception:
                pass
            await outgoing.put(format_stadium(match))
            return

        if cmd in ("equipo", "partido"):
            if not args:
                matches = await asyncio.to_thread(fetch_wc_matches)
                match = _pick_match(matches, args)
                if match:
                    await outgoing.put(f"🔎 Partido destacado: {_match_label(match)} ({match['period']})")
                else:
                    await outgoing.put("Usa: !partido España  (busca partido de hoy por nombre)")
                return
            needle = " ".join(args).lower()
            matches = await asyncio.to_thread(fetch_wc_matches)
            found = [
                m for m in matches
                if needle in m["home"].lower() or needle in m["away"].lower()
            ]
            if not found:
                await outgoing.put(f"Sin partidos hoy con '{ ' '.join(args) }'.")
                return
            for line in format_matches_list(found[:3], f"🔎 {' '.join(args)}"):
                await outgoing.put(line)
            return

        if cmd == "futbol":
            if not _is_admin(nick, ctx):
                await outgoing.put("⛔ Solo ops/admins.")
                return
            sub = (args[0].lower() if args else "")
            if sub in ("silencio", "mute"):
                mode = (args[1].lower() if len(args) > 1 else "")
                if mode in ("on", "1", "si", "sí"):
                    ctx.state.silent_mode = True
                    save_state(ctx.state)
                    await outgoing.put("🔇 Modo silencio ON (solo comandos).")
                elif mode in ("off", "0", "no"):
                    ctx.state.silent_mode = False
                    save_state(ctx.state)
                    await outgoing.put("🔊 Modo silencio OFF.")
                else:
                    await outgoing.put("Usa: !futbol silencio on|off")
                return
            if sub in ("estado", "status"):
                st = ctx.state
                live_n = sum(1 for m in st.matches.values() if not m.announced_ft)
                preds = sum(len(v) for v in st.predictions.values())
                alerts = sum(len(v) for v in st.alerts.values())
                uptime = datetime.now(TZ) - ctx.bot_start
                await outgoing.put(
                    f"🤖 Futbol — silencio={'ON' if st.silent_mode else 'OFF'}, "
                    f"partidos={len(st.matches)}, porras={preds}, avisos={alerts}, "
                    f"uptime={int(uptime.total_seconds() // 60)}min"
                )
                return
            if sub in ("reiniciar", "restart", "reiniciate", "reinicia"):
                save_state(ctx.state)
                await outgoing.put("🔄 Reiniciando…")
                if ctx.bot:
                    await ctx.bot.disconnect()
                return
            await outgoing.put("Admin: !futbol silencio on|off | estado | reiniciar")
            return

        if cmd in ("pronostico", "pronóstico", "apuesta"):
            parsed = _parse_prediction_args(args)
            if not parsed:
                await outgoing.put("Usa: !pronostico 2-1  o  !pronostico España 1-0")
                return
            name_parts, ph, pa = parsed
            matches = await asyncio.to_thread(fetch_wc_matches)
            match = _pick_match_for_prediction(matches, name_parts)
            if not match:
                await outgoing.put("🎯 No hay partido abierto a pronóstico ahora.")
                return
            nick_key = nick.lower()
            ctx.state.predictions.setdefault(match["id"], {})[nick_key] = {
                "nick": nick,
                "home": ph,
                "away": pa,
            }
            save_state(ctx.state)
            await outgoing.put(
                f"🎯 {nick} apuesta {_team_title(match)} → {ph}-{pa}"
            )
            return

        if cmd in ("miporra", "mispronosticos"):
            matches = await asyncio.to_thread(fetch_wc_matches)
            for line in format_my_predictions(nick, matches, ctx.state):
                await outgoing.put(line)
            return

        if cmd in ("porra", "pronosticos", "pronósticos"):
            if args and args[0].lower() in ("ranking", "top", "clasificacion", "clasificación"):
                for line in format_porra_ranking(ctx.state):
                    await outgoing.put(line)
                return
            matches = await asyncio.to_thread(fetch_wc_matches)
            if args:
                match = _pick_match(matches, args)
                if not match:
                    await outgoing.put("🎯 No encuentro ese partido.")
                    return
                for line in format_match_predictions(match, ctx.state):
                    await outgoing.put(line)
                return
            for line in format_porra_ranking(ctx.state):
                await outgoing.put(line)
            return

        if cmd in ("avisame", "avísame", "alerta"):
            if not args:
                await outgoing.put("Usa: !avisame España")
                return
            needle = " ".join(args).lower()
            matches = await asyncio.to_thread(fetch_wc_matches)
            if not any(_team_matches_needle(needle, m) for m in matches):
                await outgoing.put(f"🔔 No hay partido hoy con '{ ' '.join(args) }'.")
                return
            nick_key = nick.lower()
            teams = ctx.state.alerts.setdefault(nick_key, [])
            if needle not in teams:
                teams.append(needle)
            ctx.state.alert_nicks[nick_key] = nick
            save_state(ctx.state)
            await outgoing.put(f"🔔 {nick}: te aviso de { ' '.join(args) } (goles, inicio, final…)")
            return

        if cmd in ("misavisos", "avisos"):
            nick_key = nick.lower()
            teams = ctx.state.alerts.get(nick_key, [])
            if not teams:
                await outgoing.put(f"🔔 {nick}: sin avisos. !avisame España")
                return
            await outgoing.put(f"🔔 Avisos de {nick}: " + ", ".join(teams))
            return

        if cmd in ("borraravisos", "quitaravisos", "noavisame"):
            nick_key = nick.lower()
            if nick_key not in ctx.state.alerts:
                await outgoing.put(f"🔔 {nick}: no tienes avisos.")
                return
            if args:
                needle = " ".join(args).lower()
                ctx.state.alerts[nick_key] = [t for t in ctx.state.alerts[nick_key] if t != needle]
                if not ctx.state.alerts[nick_key]:
                    del ctx.state.alerts[nick_key]
                    ctx.state.alert_nicks.pop(nick_key, None)
            else:
                del ctx.state.alerts[nick_key]
                ctx.state.alert_nicks.pop(nick_key, None)
            save_state(ctx.state)
            await outgoing.put(f"🔔 Avisos de {nick} borrados.")
            return

        if cmd == "ayer":
            yesterday = (datetime.now(TZ) - timedelta(days=1)).strftime("%Y-%m-%d")
            try:
                matches = await asyncio.to_thread(fetch_wc_matches, yesterday)
                done = [m for m in matches if m["period"] in FINISHED_PERIODS]
                for line in format_matches_list(done, f"📅 Ayer ({yesterday})"):
                    await outgoing.put(line)
            except Exception:
                await outgoing.put("📅 No pude cargar los partidos de ayer.")
            return

        if cmd in ("ultimos", "últimos", "recientes"):
            limit = 10
            if args and args[0].isdigit():
                limit = min(20, int(args[0]))
            hist = ctx.state.history[-limit:]
            for line in format_history_list(hist, f"📜 Últimos {len(hist)}"):
                await outgoing.put(line)
            return

        if cmd in ("historial", "historia"):
            if not args:
                await outgoing.put("Usa: !historial España")
                return
            needle = " ".join(args).lower()
            hist = [
                h for h in ctx.state.history
                if needle in h.get("home", "").lower() or needle in h.get("away", "").lower()
            ]
            for line in format_history_list(hist, f"📜 Historial {' '.join(args)}"):
                await outgoing.put(line)
            return

    except Exception as e:
        log.error("Comando !%s de %s: %s", cmd, nick, e)
        await outgoing.put("⚠️ No pude consultar ahora. Prueba en unos segundos.")


class IRCBot:
    def __init__(self, outgoing: asyncio.Queue[str], ctx: RuntimeContext) -> None:
        self.outgoing = outgoing
        self.ctx = ctx
        self._reader: asyncio.StreamReader | None = None
        self._writer: asyncio.StreamWriter | None = None
        self.registered = asyncio.Event()
        self.in_channel = asyncio.Event()

    async def connect(self) -> None:
        await self.disconnect()
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        self._reader, self._writer = await asyncio.open_connection(IRC_HOST, IRC_PORT, ssl=ctx)
        await self.send_raw(f"NICK {IRC_NICK}")
        await self.send_raw(f"USER {IRC_USER} 0 * :{IRC_REALNAME}")

    async def disconnect(self) -> None:
        writer = self._writer
        self._writer = None
        self._reader = None
        if writer is None or writer.is_closing():
            return
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:
            pass

    async def send_raw(self, line: str) -> None:
        if not self._writer:
            return
        data = (line if line.endswith("\r\n") else f"{line}\r\n").encode("utf-8")
        self._writer.write(data)
        await self._writer.drain()
        log.debug(">> %s", line)

    async def privmsg(self, target: str, text: str) -> None:
        for chunk in _chunk_message(text):
            await self.send_raw(f"PRIVMSG {target} :{chunk}")

    async def reader_loop(self) -> None:
        assert self._reader
        buf = b""
        while True:
            chunk = await self._reader.read(4096)
            if not chunk:
                raise ConnectionError("IRC desconectado")
            buf += chunk
            while b"\r\n" in buf:
                raw, buf = buf.split(b"\r\n", 1)
                line = raw.decode("utf-8", errors="replace")
                await self._handle_line(line)

    async def _handle_line(self, line: str) -> None:
        log.debug("<< %s", line)
        if line.startswith("PING"):
            payload = line.split(":", 1)[-1].strip()
            await self.send_raw(f"PONG :{payload}")
            return
        if re.search(r"\s001\s", line):
            self.registered.set()
            if NICKSERV_PASSWORD:
                await self.send_raw(f"PRIVMSG NickServ :IDENTIFY {NICKSERV_PASSWORD}")
            await self.send_raw(f"JOIN {IRC_CHANNEL}")
            return
        if re.search(rf"\sJOIN\s(:)?{re.escape(IRC_CHANNEL)}\b", line, re.I):
            nick = line.split("!", 1)[0].lstrip(":")
            if nick.lower() == IRC_NICK.lower():
                self.in_channel.set()
                await self.send_raw(f"NAMES {IRC_CHANNEL}")
            return

        if " 353 " in line and IRC_CHANNEL.lower() in line.lower():
            names = line.split(":", 2)[-1].split()
            for name in names:
                if name[0] in "@&~":
                    self.ctx.channel_ops.add(name.lstrip("@&+%~").lower())
            return

        mode_m = re.search(rf"MODE {re.escape(IRC_CHANNEL)} ([+-])(o|h|a|q) :?(\S+)", line, re.I)
        if mode_m:
            sign, _mode, who = mode_m.group(1), mode_m.group(2), mode_m.group(3).lstrip(":")
            key = who.lower()
            if sign == "+":
                self.ctx.channel_ops.add(key)
            else:
                self.ctx.channel_ops.discard(key)
            return

        m = PRIVMSG_RE.match(line)
        if not m:
            return
        target = m.group("target")
        if target.lower() != IRC_CHANNEL.lower():
            return
        nick = m.group("nick")
        text = m.group("text")
        _spawn(run_command(nick, text, self.outgoing, self.ctx))


def _chunk_message(text: str) -> list[str]:
    if len(text.encode("utf-8")) <= MAX_MSG:
        return [text]
    parts: list[str] = []
    while text:
        if len(text.encode("utf-8")) <= MAX_MSG:
            parts.append(text)
            break
        cut = MAX_MSG
        while cut > 0 and len(text[:cut].encode("utf-8")) > MAX_MSG:
            cut -= 1
        parts.append(text[:cut])
        text = text[cut:]
    return parts


# ---------------------------------------------------------------------------
# Tracker
# ---------------------------------------------------------------------------

def _is_live(match: dict[str, Any]) -> bool:
    return match["period"] in LIVE_PERIODS or match["status"] in LIVE_PERIODS


def _kickoff_in(match: dict[str, Any], now: datetime, hours: float) -> bool:
    raw = match.get("start_date")
    if not raw:
        return False
    kickoff = datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(TZ)
    delta = kickoff - now
    return timedelta(0) <= delta <= timedelta(hours=hours)


async def process_matches(
    summaries: list[dict[str, Any]], state: BotState, outgoing: asyncio.Queue[str]
) -> None:
    for summary in summaries:
        key = summary["id"]
        ms = state.matches.get(key)
        if not ms:
            ms = MatchState(
                match_id=key,
                home=summary["home"],
                away=summary["away"],
                last_home=summary["home_score"],
                last_away=summary["away_score"],
                last_period=summary["period"],
            )
            state.matches[key] = ms

        now = datetime.now(TZ)
        if (
            summary["period"] not in FINISHED_PERIODS
            and not _is_live(summary)
            and _kickoff_in(summary, now, PREMATCH_ALERT_MIN / 60)
            and not ms.announced_prematch
        ):
            ms.announced_prematch = True
            await _maybe_put(outgoing, state, format_prematch(summary))
            await _notify_match_alerts(
                state, outgoing, summary, "prematch",
                f"en {PREMATCH_ALERT_MIN} min — {_team_title(summary)}",
            )

        match = summary
        if _is_live(summary) or summary["period"] in HT_PERIODS:
            try:
                match = await asyncio.to_thread(fetch_match_full, key)
            except Exception as e:
                log.warning("Detalle partido %s: %s", key, e)

        previous_period = ms.last_period
        if (
            _is_live(match)
            and not ms.announced_start
            and _started_recently(match, now)
        ):
            ms.announced_start = True
            await _maybe_put(outgoing, state, format_start(match))
            await _notify_match_alerts(
                state, outgoing, match, "start", f"empieza — {_team_title(match)}",
            )

        if (
            match["period"] == "2ª parte"
            and previous_period in HT_PERIODS
            and not ms.announced_second_half
        ):
            ms.announced_second_half = True
            await _maybe_put(outgoing, state, format_second_half(match))

        prev_home, prev_away = ms.last_home, ms.last_away
        score_delta = (match["home_score"] - prev_home) + (match["away_score"] - prev_away)
        unseen_goals: list[dict[str, Any]] = []
        for goal in match.get("goals") or []:
            if goal["id"] in ms.seen_goals:
                continue
            ms.seen_goals.add(goal["id"])
            unseen_goals.append(goal)

        if score_delta > 0:
            for goal in unseen_goals[-score_delta:]:
                await _maybe_put(outgoing, state, format_goal(match, goal))
                for nick_key, display in _users_for_team(state, goal["team"]):
                    await _emit_alert(
                        state, outgoing, nick_key, display,
                        f"{key}:goal:{goal['id']}",
                        format_goal(match, goal),
                    )

        for card in match.get("cards") or []:
            if card.get("kind") != "redCards" or card["id"] in ms.seen_red_cards:
                continue
            ms.seen_red_cards.add(card["id"])
            await _maybe_put(outgoing, state, format_red_card(match, card))

        if score_delta > len(unseen_goals):
            if match["home_score"] > prev_home:
                await _maybe_put(outgoing, state, format_score_only(match, match["home"]))
            elif match["away_score"] > prev_away:
                await _maybe_put(outgoing, state, format_score_only(match, match["away"]))

        if match["period"] in HT_PERIODS and not ms.announced_ht:
            ms.announced_ht = True
            await _maybe_put(outgoing, state, format_ht(match))

        if match["period"] in FINISHED_PERIODS and not ms.announced_ft:
            ms.announced_ft = True
            _append_history(state, match)
            await _maybe_put(outgoing, state, format_ft(match))
            for line in format_match_end_summary(match):
                await _maybe_put(outgoing, state, line)
            if not ms.announced_porra:
                ms.announced_porra = True
                for line in format_porra_results(match, state):
                    await _maybe_put(outgoing, state, line)
            await _notify_match_alerts(
                state, outgoing, match, "ft",
                f"final — {_match_label(match)}",
            )

        ms.last_home = match["home_score"]
        ms.last_away = match["away_score"]
        ms.last_period = match["period"]


async def football_loop(outgoing: asyncio.Queue[str], dry_run: bool, ctx: RuntimeContext) -> None:
    state = ctx.state
    last_idle_poll = datetime.min.replace(tzinfo=TZ)
    today_schedule: list[dict[str, Any]] = []
    schedule_date = ""

    if not dry_run:
        now = datetime.now(TZ)
        send_online = True
        if state.last_online_at:
            try:
                last = datetime.fromisoformat(state.last_online_at)
                if (now - last).total_seconds() < ONLINE_MSG_COOLDOWN_MIN * 60:
                    send_online = False
            except ValueError:
                pass
        if send_online:
            await outgoing.put("⚽ Futbol online — Mundial 2026. !ayuda")
            state.last_online_at = now.isoformat()
            save_state(state)

    while True:
        now = datetime.now(TZ)
        today_str = now.strftime("%Y-%m-%d")

        if schedule_date != today_str:
            try:
                today_schedule = await asyncio.to_thread(fetch_wc_matches)
                schedule_date = today_str
                log.info("Partidos hoy: %d", len(today_schedule))
            except Exception as e:
                log.error("Calendario: %s", e)

        live = [m for m in today_schedule if _is_live(m)]
        soon = any(_kickoff_in(m, now, hours=2) for m in today_schedule)

        if live or soon:
            targets = live or [m for m in today_schedule if _is_live(m) or _kickoff_in(m, now, hours=0.5)]
            if not targets:
                targets = today_schedule
            await process_matches(targets, state, outgoing)
            save_state(state)
            await asyncio.sleep(POLL_LIVE_SEC)
            continue

        if (
            now.hour == DAILY_SUMMARY_HOUR
            and now.minute >= DAILY_SUMMARY_MIN
            and state.last_summary_date != today_str
            and today_schedule
        ):
            try:
                standings = await asyncio.to_thread(fetch_standings)
                for line in format_daily_summary(today_schedule, standings):
                    await _maybe_put(outgoing, state, line)
                state.last_summary_date = today_str
                save_state(state)
            except Exception as e:
                log.error("Resumen diario: %s", e)

        if (now - last_idle_poll).total_seconds() >= POLL_IDLE_SEC:
            last_idle_poll = now
            try:
                today_schedule = await asyncio.to_thread(fetch_wc_matches)
            except Exception as e:
                log.error("Idle poll: %s", e)

        await asyncio.sleep(30 if dry_run else 60)


async def sender_loop(bot: IRCBot, outgoing: asyncio.Queue[str], dry_run: bool) -> None:
    while True:
        msg = await outgoing.get()
        if dry_run:
            print(f"[DRY-RUN] -> {IRC_CHANNEL}: {msg}")
        else:
            await bot.registered.wait()
            await bot.in_channel.wait()
            await bot.privmsg(IRC_CHANNEL, msg)
            await asyncio.sleep(1.5)


async def run_bot(dry_run: bool) -> None:
    outgoing: asyncio.Queue[str] = asyncio.Queue()
    ctx = RuntimeContext(state=load_state())
    bot = IRCBot(outgoing, ctx)
    ctx.bot = bot

    if dry_run:
        await asyncio.gather(
            football_loop(outgoing, dry_run=True, ctx=ctx),
            sender_loop(bot, outgoing, True),
        )
        return

    while True:
        try:
            await bot.connect()
            await asyncio.gather(
                bot.reader_loop(),
                football_loop(outgoing, dry_run=False, ctx=ctx),
                sender_loop(bot, outgoing, False),
            )
        except Exception as e:
            log.exception("Reconectando en 30s: %s", e)
        finally:
            await bot.disconnect()
            bot.registered.clear()
            bot.in_channel.clear()
            ctx.bot_start = datetime.now(TZ)
        await asyncio.sleep(30)


def _self_check() -> None:
    assert _chunk_message("hola")[0] == "hola"
    match = {
        "home": "España",
        "away": "Brasil",
        "home_score": 2,
        "away_score": 1,
        "phase": "Grupo H",
        "period": "2ª parte",
    }
    goal = {"scorer": "Pedri", "team": "España", "minute": 67, "detail": "normal"}
    assert "Pedri" in format_goal(match, goal)
    assert "DESCANSO" in format_ht({**match, "period": "Descanso"})
    assert "FINAL" in format_ft({**match, "period": "Finalizado"})
    st = BotState()
    st.matches["x"] = MatchState("x", "A", "B", seen_goals={"g1"})
    assert BotState.from_json(st.to_json()).matches["x"].seen_goals == {"g1"}
    assert _group_key("A") == 1
    assert _group_key("12") == 12
    assert _group_key("grupo B") == 2
    groups = [{"name": "Grupo A", "rows": [{"rank": 1, "team": "México", "points": 9, "played": 3, "gd": 5}]}]
    assert "México" in format_standings_compact(groups)[1]
    parsed = _parse_prediction_args(["España", "2-1"])
    assert parsed and parsed[1:] == (2, 1)
    assert _porra_points(2, 1, 2, 1) == 3
    assert _porra_points(2, 1, 3, 0) == 1
    assert _porra_points(2, 1, 0, 2) == 0
    st.predictions = {"m1": {"alice": {"nick": "Alice", "home": 1, "away": 0}}}
    st.matches["m1"] = MatchState("m1", "A", "B")
    fm = {"id": "m1", "home": "A", "away": "B", "home_score": 1, "away_score": 0, "phase": "G"}
    assert "Alice" in format_porra_results(fm, st)[1]
    print("self-check OK")


def main() -> None:
    parser = argparse.ArgumentParser(description="Bot Futbol — Mundial 2026 en #globalchat")
    parser.add_argument("--dry-run", action="store_true", help="Sin IRC; imprime mensajes")
    parser.add_argument("--self-check", action="store_true", help="Verificación rápida")
    parser.add_argument("--fetch-today", action="store_true", help="Muestra partidos de hoy")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stdout,
        force=True,
    )

    def _on_signal(signum: int, _frame: Any) -> None:
        log.warning("Señal %s recibida", signum)
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGTERM, _on_signal)
    signal.signal(signal.SIGHUP, signal.SIG_IGN)

    if args.self_check:
        _self_check()
        return

    if args.fetch_today:
        for m in fetch_wc_matches():
            print(
                f"{m['home']} {m['home_score']}-{m['away_score']} {m['away']} "
                f"({m['period']}) [{m['phase']}]"
            )
        return

    log.info("Arrancando Futbol -> %s:%s %s", IRC_HOST, IRC_PORT, IRC_CHANNEL)
    while True:
        try:
            asyncio.run(run_bot(dry_run=args.dry_run))
            if args.dry_run:
                return
            log.warning("run_bot terminó inesperadamente, reinicio en 10s")
            time.sleep(10)
        except KeyboardInterrupt:
            log.info("Apagado")
            return
        except SystemExit as e:
            log.warning("Proceso terminado (code %s)", e.code)
            return
        except Exception:
            log.exception("Bot caído, reinicio en 10s")
            time.sleep(10)


if __name__ == "__main__":
    main()
