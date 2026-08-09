#!/usr/bin/env python3
"""TOOLS SET JHOW-001 — simple read-only dashboard."""

from __future__ import annotations

import json
import os
import sqlite3
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

from flask import Flask, jsonify, render_template, request, send_from_directory
from flask_socketio import SocketIO, emit, join_room, leave_room

from config import HOST, PORT, RESULTS_DIR, ROOT_DIR, WS_WATCH_INTERVAL

try:
    from zoneinfo import ZoneInfo
    BRT = ZoneInfo("America/Sao_Paulo")
except Exception:
    BRT = timezone.utc

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("DASHBOARD_SECRET", "jhow-001")
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")


def _parse_ts(value: Any) -> Optional[datetime]:
    if not value:
        return None
    s = str(value).strip().replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(s)
    except Exception:
        try:
            dt = datetime.fromisoformat(s.replace(" ", "T"))
        except Exception:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def fmt_brt(value: Any) -> str:
    dt = _parse_ts(value)
    if not dt:
        return "—"
    return dt.astimezone(BRT).strftime("%d/%m/%Y %H:%M:%S")


def fmt_elapsed(started: Any, finished: Any = None) -> str:
    st = _parse_ts(started)
    if not st:
        return "00:00"
    end = _parse_ts(finished) or datetime.now(timezone.utc)
    sec = max(0, int((end - st).total_seconds()))
    h, rem = divmod(sec, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


def list_domains() -> list[str]:
    root = Path(RESULTS_DIR)
    if not root.is_dir():
        return []
    return sorted(
        d.name for d in root.iterdir()
        if d.is_dir() and (d / "_status").is_dir()
    )


def db_path(domain: str) -> Path:
    return Path(RESULTS_DIR) / domain / "_status" / "metrics.db"


def json_path(domain: str, name: str) -> Path:
    return Path(RESULTS_DIR) / domain / "_status" / name


def open_db(domain: str) -> Optional[sqlite3.Connection]:
    p = db_path(domain)
    if not p.is_file():
        return None
    conn = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def q(domain: str, sql: str, params: tuple = ()) -> list[dict]:
    conn = open_db(domain)
    if not conn:
        return []
    try:
        return [dict(r) for r in conn.execute(sql, params).fetchall()]
    except sqlite3.Error:
        return []
    finally:
        conn.close()


def read_json(path: Path) -> Any:
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def run_started(domain: str) -> str:
    data = read_json(json_path(domain, "run.json"))
    raw = data.get("started") or data.get("started_at") or data.get("start") or ""
    if not raw:
        rows = q(domain, "SELECT started_at FROM runs ORDER BY id DESC LIMIT 1")
        if rows:
            raw = rows[0].get("started_at") or ""
    return raw or ""


def modules_results(domain: str) -> list[dict]:
    rows = q(
        domain,
        """
        SELECT module AS name, COALESCE(SUM(lines), 0) AS results
        FROM tools
        GROUP BY module
        ORDER BY name
        """,
    )
    mods = q(domain, "SELECT name FROM modules ORDER BY id")
    have = {r["name"] for r in rows}
    for m in mods:
        if m["name"] not in have:
            rows.append({"name": m["name"], "results": 0})
    return rows


def active_tools(domain: str) -> list[dict]:
    rows = q(
        domain,
        """
        SELECT tool, module, status, started_at, finished_at, duration_ms, lines
        FROM tools
        WHERE lower(coalesce(status,'')) IN ('running', 'in_progress', 'running_tool')
           OR (
                started_at IS NOT NULL
                AND (finished_at IS NULL OR finished_at = '')
                AND lower(coalesce(status,'')) NOT IN
                    ('ok', 'error', 'failed', 'timeout', 'finished', 'skipped')
           )
        ORDER BY started_at ASC, id ASC
        """,
    )
    if not rows:
        rows = q(
            domain,
            """
            SELECT tool, module, status, started_at, finished_at, duration_ms, lines
            FROM tools
            WHERE started_at IS NOT NULL
              AND (finished_at IS NULL OR finished_at = '')
            ORDER BY id DESC
            LIMIT 20
            """,
        )

    out = []
    for t in rows:
        started = t.get("started_at")
        finished = t.get("finished_at")
        live = bool(started and not finished)
        out.append({
            "tool": t.get("tool") or "—",
            "module": t.get("module") or "—",
            "started_fmt": fmt_brt(started) if started else "—",
            "started_iso": started or "",
            "finished_iso": finished or "",
            "elapsed": fmt_elapsed(started, finished),
            "live": live,
            "lines": t.get("lines") if t.get("lines") is not None else 0,
            "status": (t.get("status") or "").lower(),
        })
    return out

def all_tools(domain: str) -> list[dict]:
    """Full tool list with independent timers."""
    rows = q(
        domain,
        """
        SELECT tool, module, status, started_at, finished_at, duration_ms, lines
        FROM tools
        ORDER BY id ASC
        LIMIT 500
        """,
    )
    out = []
    for t in rows:
        started = t.get("started_at")
        finished = t.get("finished_at")
        st = (t.get("status") or "").lower()
        live = bool(started and not finished and st not in (
            "ok", "error", "failed", "timeout", "finished", "skipped"
        ))
        # Prefer duration_ms when finished
        if finished and t.get("duration_ms") is not None and int(t.get("duration_ms") or 0) > 0:
            sec = int(t["duration_ms"]) // 1000
            h, rem = divmod(sec, 3600)
            m, s = divmod(rem, 60)
            elapsed = f"{h:02d}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"
        else:
            elapsed = fmt_elapsed(started, finished)

        if st in ("ok", "finished", "success"):
            status_label, status_class = "ok", "ok"
        elif st in ("error", "failed"):
            status_label, status_class = "error", "error"
        elif st in ("timeout",):
            status_label, status_class = "timeout", "error"
        elif live or st in ("running", "in_progress"):
            status_label, status_class = "running", "running"
        elif st in ("pending", "queued", "waiting", ""):
            status_label, status_class = "waiting", "waiting"
        else:
            status_label, status_class = st or "—", "muted"

        out.append({
            "tool": t.get("tool") or "—",
            "module": t.get("module") or "—",
            "status_label": status_label,
            "status_class": status_class,
            "results": t.get("lines") if t.get("lines") is not None else "—",
            "elapsed": elapsed,
            "started_iso": started or "",
            "finished_iso": finished or "",
            "live": live,
        })
    return out

def fingerprint(domain: str) -> str:
    parts = []
    p = db_path(domain)
    if p.is_file():
        st = p.stat()
        parts.append(f"{st.st_mtime_ns}:{st.st_size}")
    for n in ("run.json", "modules.json", "tools.json"):
        f = json_path(domain, n)
        if f.is_file():
            st = f.stat()
            parts.append(f"{n}:{st.st_mtime_ns}")
    return "|".join(parts) if parts else "empty"


_stop = threading.Event()
_fp: dict[str, str] = {}


def _watch():
    while not _stop.is_set():
        try:
            for d in list_domains():
                fp = fingerprint(d)
                if _fp.get(d) is None:
                    _fp[d] = fp
                    continue
                if _fp[d] != fp:
                    _fp[d] = fp
                    socketio.emit("dashboard_update", {"domain": d}, room=f"domain:{d}")
                    socketio.emit("dashboard_update", {"domain": d}, room="all")
        except Exception:
            pass
        _stop.wait(WS_WATCH_INTERVAL)


def start_watcher():
    t = threading.Thread(target=_watch, daemon=True)
    t.start()


@socketio.on("connect")
def on_connect():
    join_room("all")
    emit("connected", {"ok": True})


@socketio.on("subscribe")
def on_subscribe(data):
    domain = (data or {}).get("domain") or ""
    if domain in list_domains():
        join_room(f"domain:{domain}")
        emit("subscribed", {"domain": domain})


@app.route("/")
def index():
    domains = list_domains()
    domain = request.args.get("domain") or (domains[0] if domains else "")
    return render_template("index.html", domains=domains, domain=domain)


@app.route("/api/snapshot")
def api_snapshot():
    domain = request.args.get("domain", "")
    domains = list_domains()
    if not domain or domain not in domains:
        return jsonify({
            "domains": domains,
            "domain": domain,
            "started_fmt": "—",
            "started_iso": "",
            "modules": [],
            "running_tools": [],
            "all_tools": [],
    })
    started = run_started(domain)
    return jsonify({
        "domains": domains,
        "domain": domain,
        "started_fmt": fmt_brt(started) if started else "—",
        "started_iso": started,
        "modules": modules_results(domain),
        "running_tools": active_tools(domain),
        "all_tools": all_tools(domain),
    })


@app.route("/static/<path:filename>")
def static_files(filename):
    return send_from_directory(Path(__file__).parent / "static", filename)



# ----- Reporting V2 (Phase 5) -----
@app.route("/api/report/<domain>")
def api_report(domain):
    """Counts + meta do último reporting V2."""
    import re as _re
    domain = _re.sub(r"[^a-zA-Z0-9._-]", "", domain)
    base = Path(os.environ.get("ROOT_DIR", str(Path(__file__).resolve().parents[2])))
    work = base / "results" / domain / "report" / ".work_classify"
    report_dir = base / "results" / domain / "report"
    if not report_dir.is_dir():
        return jsonify({"ok": False, "error": "no_report", "domain": domain}), 404

    def _count(name):
        f = work / name
        if not f.is_file():
            return 0
        try:
            return sum(1 for line in f.read_text(errors="ignore").splitlines() if line.strip())
        except Exception:
            return 0

    alerts = report_dir / "alerts.txt"
    summary = report_dir / "summary.md"
    generated = None
    if alerts.is_file():
        try:
            first = alerts.read_text(errors="ignore").splitlines()[0]
            # # ALERTS — domain — 2026-08-08T22:57:12Z
            parts = first.split(" — ")
            if len(parts) >= 3:
                generated = parts[-1].strip()
        except Exception:
            pass

    return jsonify({
        "ok": True,
        "domain": domain,
        "generated_at": generated,
        "counts": {
            "critical": _count("CRITICAL.txt"),
            "high": _count("HIGH.txt"),
            "medium": _count("MEDIUM.txt"),
            "low": _count("LOW.txt"),
            "info": _count("INFO.txt"),
        },
        "files": {
            "alerts": str(alerts) if alerts.is_file() else None,
            "summary": str(summary) if summary.is_file() else None,
            "findings": str(report_dir / "findings.json") if (report_dir / "findings.json").is_file() else None,
        },
    })


@app.route("/api/report/<domain>/alerts")
def api_report_alerts(domain):
    """Texto de alerts.txt (CRITICAL+HIGH)."""
    import re as _re
    domain = _re.sub(r"[^a-zA-Z0-9._-]", "", domain)
    base = Path(os.environ.get("ROOT_DIR", str(Path(__file__).resolve().parents[2])))
    alerts = base / "results" / domain / "report" / "alerts.txt"
    if not alerts.is_file():
        return jsonify({"ok": False, "error": "no_alerts"}), 404
    text = alerts.read_text(errors="ignore")
    # limita payload
    lines = text.splitlines()[:200]
    return jsonify({"ok": True, "domain": domain, "lines": lines, "text": "\n".join(lines)})


@app.route("/api/report/<domain>/summary")
def api_report_summary(domain):
    import re as _re
    domain = _re.sub(r"[^a-zA-Z0-9._-]", "", domain)
    base = Path(os.environ.get("ROOT_DIR", str(Path(__file__).resolve().parents[2])))
    summary = base / "results" / domain / "report" / "summary.md"
    if not summary.is_file():
        return jsonify({"ok": False, "error": "no_summary"}), 404
    return jsonify({"ok": True, "domain": domain, "markdown": summary.read_text(errors="ignore")[:50000]})


if __name__ == "__main__":
    start_watcher()
    print(f"TOOLS SET JHOW-001 | http://{HOST}:{PORT}/")
    socketio.run(app, host=HOST, port=PORT, debug=False, allow_unsafe_werkzeug=True)
