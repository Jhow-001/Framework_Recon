#!/bin/bash
# core/metrics/metrics.sh — Persistência SQLite (Fase 3)
set -euo pipefail

metrics_init() {
    local domain="${1:-${TARGET_DOMAIN}}"
    local db
    db=$(storage_metrics_db "$domain")
    mkdir -p "$(dirname "$db")"
    sqlite3 "$db" <<'SQL' >/dev/null
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
CREATE TABLE IF NOT EXISTS runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  domain TEXT NOT NULL,
  started_at TEXT,
  finished_at TEXT,
  status TEXT,
  modules_total INTEGER DEFAULT 0,
  modules_finished INTEGER DEFAULT 0,
  modules_failed INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS modules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER,
  name TEXT NOT NULL,
  status TEXT,
  started_at TEXT,
  finished_at TEXT,
  findings INTEGER DEFAULT 0,
  tools_total INTEGER DEFAULT 0,
  tools_finished INTEGER DEFAULT 0,
  FOREIGN KEY(run_id) REFERENCES runs(id)
);
CREATE TABLE IF NOT EXISTS tools (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER,
  module TEXT NOT NULL,
  tool TEXT NOT NULL,
  status TEXT,
  started_at TEXT,
  finished_at TEXT,
  duration_ms INTEGER DEFAULT 0,
  lines INTEGER DEFAULT 0,
  exit_code INTEGER,
  retries INTEGER DEFAULT 0,
  FOREIGN KEY(run_id) REFERENCES runs(id)
);
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER,
  ts TEXT NOT NULL,
  event TEXT NOT NULL,
  payload TEXT,
  FOREIGN KEY(run_id) REFERENCES runs(id)
);
CREATE TABLE IF NOT EXISTS metrics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER,
  key TEXT NOT NULL,
  value REAL,
  ts TEXT,
  FOREIGN KEY(run_id) REFERENCES runs(id)
);
CREATE INDEX IF NOT EXISTS idx_tools_module ON tools(module, tool);
CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
SQL
    export METRICS_DB="$db"
    export METRICS_RUN_ID=""
}

metrics_run_start() {
    local domain="${1:-${TARGET_DOMAIN}}"
    local total="${2:-0}"
    local db="${METRICS_DB:-$(storage_metrics_db "$domain")}"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local domain_esc=${domain//\'/\'\'}
    METRICS_RUN_ID=$(sqlite3 "$db" \
        "INSERT INTO runs (domain, started_at, status, modules_total)
         VALUES ('$domain_esc', '$now', 'running', $total);
         SELECT last_insert_rowid();")
    export METRICS_RUN_ID
}

metrics_run_end() {
    local status="${1:-finished}"
    local db="${METRICS_DB:-}"
    [[ -n "$db" && -n "${METRICS_RUN_ID:-}" ]] || return 0
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    status=${status//\'/\'\'}
    sqlite3 "$db" \
        "UPDATE runs SET finished_at='$now', status='$status'
         WHERE id=$METRICS_RUN_ID;"
}

metrics_event() {
    local event="$1"
    shift || true
    local payload="$*"
    local db="${METRICS_DB:-}"
    [[ -n "$db" ]] || return 0
    local now run_id
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    run_id="${METRICS_RUN_ID:-NULL}"
    payload=${payload//\'/\'\'}
    event=${event//\'/\'\'}
    sqlite3 "$db" \
        "INSERT INTO events (run_id, ts, event, payload)
         VALUES ($run_id, '$now', '$event', '$payload');"
}

# Grava tool como running no início (dashboard ao vivo)
metrics_tool_start() {
    local module="$1" tool="$2"
    local db="${METRICS_DB:-}"
    [[ -n "$db" ]] || return 0
    local now run_id
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    run_id="${METRICS_RUN_ID:-NULL}"
    module=${module//\'/\'\'}
    tool=${tool//\'/\'\'}
    sqlite3 "$db" \
        "INSERT INTO tools (run_id, module, tool, status, started_at, finished_at, duration_ms, lines, exit_code, retries)
         VALUES ($run_id, '$module', '$tool', 'running', '$now', NULL, 0, 0, 0, 0);" 2>/dev/null || true
}

# Atualiza a linha running; se não existir, insere final
metrics_tool_end() {
    local module="$1" tool="$2" status="$3"
    local duration_ms="${4:-0}" lines="${5:-0}" exit_code="${6:-0}" retries="${7:-0}"
    local db="${METRICS_DB:-}"
    [[ -n "$db" ]] || return 0
    local now run_id
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    run_id="${METRICS_RUN_ID:-NULL}"
    module=${module//\'/\'\'}
    tool=${tool//\'/\'\'}
    status=${status//\'/\'\'}

    local updated
    updated=$(sqlite3 "$db" \
        "UPDATE tools SET
            status='$status',
            finished_at='$now',
            duration_ms=$duration_ms,
            lines=$lines,
            exit_code=$exit_code,
            retries=$retries
          WHERE id = (
            SELECT id FROM tools
            WHERE module='$module' AND tool='$tool' AND status='running'
            ORDER BY id DESC LIMIT 1
          );
          SELECT changes();" 2>/dev/null || echo 0)

    if [[ "${updated:-0}" == "0" ]]; then
        sqlite3 "$db" \
            "INSERT INTO tools (run_id, module, tool, status, finished_at, duration_ms, lines, exit_code, retries)
             VALUES ($run_id, '$module', '$tool', '$status', '$now', $duration_ms, $lines, $exit_code, $retries);" 2>/dev/null || true
    fi
}

metrics_module_end() {
    local name="$1" status="$2" findings="${3:-0}"
    local db="${METRICS_DB:-}"
    [[ -n "$db" ]] || return 0
    local now run_id
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    run_id="${METRICS_RUN_ID:-NULL}"
    name=${name//\'/\'\'}
    status=${status//\'/\'\'}
    sqlite3 "$db" \
        "INSERT INTO modules (run_id, name, status, finished_at, findings)
         VALUES ($run_id, '$name', '$status', '$now', $findings);"
}

export -f metrics_init metrics_run_start metrics_run_end
export -f metrics_event metrics_tool_start metrics_tool_end metrics_module_end
