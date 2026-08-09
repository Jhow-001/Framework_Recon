(function () {
  const domainSelect = document.getElementById("domain");
  const statusEl = document.getElementById("ws-status");
  let toolTimers = [];
  let lastPayload = ""; // skip redraw when data unchanged

  function currentDomain() {
    return domainSelect ? domainSelect.value : "";
  }

  function setStatus(text, ok) {
    if (!statusEl) return;
    statusEl.textContent = text;
    statusEl.style.color = ok ? "#3dd68c" : "#8aa0b8";
  }

  function esc(s) {
    return String(s ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function partsBRT(date) {
    const fmt = new Intl.DateTimeFormat("en-GB", {
      timeZone: "America/Sao_Paulo",
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    });
    const p = fmt.formatToParts(date);
    const g = (t) => (p.find((x) => x.type === t) || {}).value || "";
    return (
      g("day") + "/" + g("month") + "/" + g("year") + " " +
      g("hour") + ":" + g("minute") + ":" + g("second")
    );
  }

  function elapsedBetween(startIso, endMs) {
    if (!startIso) return "00:00";
    let s = String(startIso).replace("Z", "+00:00");
    const st = new Date(s.includes("T") ? s : s.replace(" ", "T"));
    if (isNaN(st.getTime())) return "00:00";
    let sec = Math.max(0, Math.floor((endMs - st.getTime()) / 1000));
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s2 = sec % 60;
    const p = (x) => String(x).padStart(2, "0");
    return h > 0 ? p(h) + ":" + p(m) + ":" + p(s2) : p(m) + ":" + p(s2);
  }

  function tickClock() {
    const el = document.getElementById("live-clock");
    if (el) el.textContent = partsBRT(new Date());
    const now = Date.now();
    toolTimers.forEach((t) => {
      if (!t.el || !t.live || !t.startedIso) return;
      t.el.textContent = elapsedBetween(t.startedIso, now);
    });
  }

  function apply(data) {
    if (!data) return;

    // Stable serialization — skip DOM rebuild if nothing changed
    let payload;
    try {
      payload = JSON.stringify(data);
    } catch (_) {
      payload = String(Date.now());
    }
    if (payload === lastPayload) {
      return; // no flicker
    }
    lastPayload = payload;

    const tg = document.getElementById("target-domain");
    if (tg) tg.textContent = data.domain || "—";

    const st = document.getElementById("started-fmt");
    if (st) st.textContent = data.started_fmt || "—";

    const mb = document.getElementById("modules-body");
    if (mb) {
      if (!data.modules || !data.modules.length) {
        mb.innerHTML = '<tr><td colspan="2" class="empty">—</td></tr>';
      } else {
        mb.innerHTML = data.modules
          .map(
            (m) =>
              `<tr><td>${esc(m.name)}</td><td class="num">${esc(m.results)}</td></tr>`
          )
          .join("");
      }
    }

    toolTimers = [];

    const box = document.getElementById("running-tools");
    if (box) {
      const tools = data.running_tools || [];
      if (!tools.length) {
        box.innerHTML = '<div class="empty">no tools running</div>';
      } else {
        box.innerHTML = tools
          .map((t, i) => {
            return `<div class="tool-line">
              <span class="t">${esc(t.started_fmt)}</span>
              <span>${esc(t.module)} → ${esc(t.tool)}</span>
              <span class="elapsed live" data-r="${i}">${esc(t.elapsed || "00:00")}</span>
            </div>`;
          })
          .join("");
        tools.forEach((t, i) => {
          const el = box.querySelector('.elapsed[data-r="' + i + '"]');
          toolTimers.push({
            el,
            startedIso: t.started_iso || "",
            live: !!t.live && !!t.started_iso,
          });
        });
      }
    }

    const tb = document.getElementById("all-tools-body");
    if (tb) {
      const all = data.all_tools || [];
      if (!all.length) {
        tb.innerHTML = '<tr><td colspan="5" class="empty">—</td></tr>';
      } else {
        tb.innerHTML = all
          .map((t, i) => {
            return `<tr>
              <td>${esc(t.tool)}</td>
              <td>${esc(t.module)}</td>
              <td class="${esc(t.status_class)}">${esc(t.status_label)}</td>
              <td class="num">${esc(t.results)}</td>
              <td class="num elapsed${t.live ? " live" : ""}" data-a="${i}">${esc(
              t.elapsed || "00:00"
            )}</td>
            </tr>`;
          })
          .join("");
        all.forEach((t, i) => {
          if (!t.live || !t.started_iso) return;
          const el = tb.querySelector('.elapsed[data-a="' + i + '"]');
          toolTimers.push({
            el,
            startedIso: t.started_iso || "",
            live: true,
          });
        });
      }
    }
  }

  async function fetchSnapshot() {
    const d = currentDomain();
    if (!d) return;
    try {
      const res = await fetch("/api/snapshot?domain=" + encodeURIComponent(d), {
        cache: "no-store",
      });
      if (!res.ok) return;
      apply(await res.json());
    } catch (_) {}
  }

  if (domainSelect) {
    domainSelect.addEventListener("change", () => {
      lastPayload = ""; // force refresh on domain switch
      fetchSnapshot();
    });
  }

  if (typeof io !== "undefined") {
    const socket = io({
      transports: ["websocket", "polling"],
      reconnection: true,
    });
    socket.on("connect", () => {
      setStatus("WebSocket: connected", true);
      const d = currentDomain();
      if (d) socket.emit("subscribe", { domain: d });
    });
    socket.on("disconnect", () => setStatus("WebSocket: polling", false));
    socket.on("dashboard_update", (p) => {
      if (p && p.domain && p.domain !== currentDomain()) return;
      fetchSnapshot();
    });
    if (domainSelect) {
      domainSelect.addEventListener("change", () => {
        socket.emit("subscribe", { domain: currentDomain() });
      });
    }
  } else {
    setStatus("WebSocket: offline", false);
  }

  tickClock();
  setInterval(tickClock, 1000);
  fetchSnapshot();
  setInterval(fetchSnapshot, 2000);
})();


/* ----- Reporting V2 card ----- */
async function loadReportCard(domain) {
  const box = document.getElementById("report-alerts");
  const gen = document.getElementById("report-generated");
  if (!domain || !box) return;
  try {
    const r = await fetch("/api/report/" + encodeURIComponent(domain));
    if (!r.ok) {
      box.textContent = "Sem report para " + domain;
      if (gen) gen.textContent = "—";
      ["rpt-c","rpt-h","rpt-m","rpt-l","rpt-i"].forEach(id => {
        const el = document.getElementById(id); if (el) el.textContent = "0";
      });
      return;
    }
    const data = await r.json();
    const c = data.counts || {};
    const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v ?? 0; };
    set("rpt-c", c.critical);
    set("rpt-h", c.high);
    set("rpt-m", c.medium);
    set("rpt-l", c.low);
    set("rpt-i", c.info);
    if (gen) gen.textContent = data.generated_at || "—";

    const a = await fetch("/api/report/" + encodeURIComponent(domain) + "/alerts");
    if (a.ok) {
      const aj = await a.json();
      box.textContent = (aj.lines || []).join("\n") || "(vazio)";
    } else {
      box.textContent = "alerts indisponível";
    }
  } catch (e) {
    box.textContent = "Erro ao carregar report: " + e;
  }
}

// integra com refresh existente se houver domain global
(function bindReportRefresh() {
  const tryLoad = () => {
    const sel = document.querySelector("#domain-select, select#domain, [data-domain]");
    let domain = null;
    if (sel && sel.value) domain = sel.value;
    if (!domain && window.CURRENT_DOMAIN) domain = window.CURRENT_DOMAIN;
    if (!domain && window.targetDomain) domain = window.targetDomain;
    // fallback: query ?domain=
    if (!domain) {
      const q = new URLSearchParams(location.search).get("domain");
      if (q) domain = q;
    }
    if (domain) loadReportCard(domain);
  };
  document.addEventListener("DOMContentLoaded", tryLoad);
  setInterval(tryLoad, 15000);
  // se o dashboard já dispara evento de troca de domínio
  document.addEventListener("domain-changed", (ev) => {
    if (ev.detail) loadReportCard(ev.detail);
  });
})();

