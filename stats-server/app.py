#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
「小明」校园网加速工具箱 - 匿名统计服务端
XiaoMing Campus Network Toolkit - Anonymous Telemetry Server

特性:
  * Flask + SQLite + matplotlib，单文件，Docker 部署
  * 数据库【不记录】IP、主机名、MAC、账号等任何身份信息
  * 提供上报接口 /api/report、聚合数据 /api/stats、统计图片 /chart、看板 /
"""
import os
import sqlite3
import threading
from datetime import datetime, timedelta
from collections import Counter

from flask import Flask, request, jsonify, Response, g

# matplotlib 延迟到首次绘图时才导入：上报/统计接口不加载它，显著降低小内存服务器常驻内存
plt = None


def _ensure_plt():
    global plt
    if plt is None:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

DB_PATH = os.environ.get("DB_PATH", os.path.join(os.path.dirname(__file__), "data", "stats.db"))
PORT = int(os.environ.get("PORT", "8080"))
CHART_CACHE_SEC = int(os.environ.get("CHART_CACHE_SEC", "300"))

# 白名单（防止脏数据/刷库）
ALLOWED_MODES = {"proxy_clean", "campus", "gaming", "latency_test", "other"}
ALLOWED_VENDORS = {"Intel", "Realtek", "MediaTek", "Qualcomm/Killer", "Broadcom", "Unknown"}
ALLOWED_TYPES = {"wired", "wireless", "unknown"}

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 8 * 1024  # 上报体上限 8KB
_plot_lock = threading.Lock()
_chart_cache = {}

# 极简内存限流：不依赖 IP，仅按 install_id 限制最小间隔
_last_seen = {}
_MIN_INTERVAL_SEC = 3


# ----------------------------- 数据库 -----------------------------
def get_db():
    if "db" not in g:
        os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
        g.db = sqlite3.connect(DB_PATH, timeout=10)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.execute(
        """
        CREATE TABLE IF NOT EXISTS reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT NOT NULL,
            date TEXT NOT NULL,
            install_id TEXT,
            tool_version TEXT,
            os TEXT, build TEXT,
            vendor TEXT, adapter_type TEXT,
            mode TEXT, success INTEGER,
            opt_count INTEGER,
            latency_before REAL, latency_after REAL,
            loss_before REAL, loss_after REAL
        )
        """
    )
    con.execute("CREATE INDEX IF NOT EXISTS idx_date ON reports(date)")
    con.execute("CREATE INDEX IF NOT EXISTS idx_mode ON reports(mode)")
    con.commit()
    con.close()


# ----------------------------- 工具函数 -----------------------------
def clamp_str(value, maxlen, default=""):
    if value is None:
        return default
    s = str(value).strip()
    return s[:maxlen] if s else default


def clamp_num(value, lo, hi, default=None):
    try:
        n = float(value)
    except (TypeError, ValueError):
        return default
    if n != n or n < lo or n > hi:  # NaN 或越界
        return default
    return n


def norm_os(os_name):
    s = str(os_name or "")
    if "Windows 11" in s or "Win11" in s:
        return "Windows 11"
    if "Windows 10" in s or "Win10" in s:
        return "Windows 10"
    if s:
        return "Other Windows"
    return "Unknown"


def png_response(buf):
    return Response(buf.getvalue(), mimetype="image/png",
                    headers={"Cache-Control": "public, max-age=300"})


# ----------------------------- 接口 -----------------------------
@app.get("/health")
def health():
    return jsonify(ok=True, service="xm-stats", time=datetime.now().isoformat(timespec="seconds"))


@app.post("/api/report")
def report():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify(ok=False, error="invalid json"), 400

    install_id = clamp_str(data.get("install_id"), 64, "anonymous")
    # 限流：同一 install_id 最小间隔
    now = datetime.now()
    prev = _last_seen.get(install_id)
    if prev and (now - prev).total_seconds() < _MIN_INTERVAL_SEC:
        return jsonify(ok=True, throttled=True)
    _last_seen[install_id] = now

    mode = clamp_str(data.get("mode"), 20, "other")
    if mode not in ALLOWED_MODES:
        mode = "other"
    vendor = clamp_str(data.get("vendor"), 30, "Unknown")
    if vendor not in ALLOWED_VENDORS:
        vendor = "Unknown"
    adapter_type = clamp_str(data.get("adapter_type"), 12, "unknown")
    if adapter_type not in ALLOWED_TYPES:
        adapter_type = "unknown"

    success = 1 if data.get("success") in (True, 1, "1", "true", "True") else 0
    opt_count = clamp_num(data.get("opt_count"), 0, 100, 0)
    opt_count = int(opt_count)

    row = (
        now.strftime("%Y-%m-%d %H:%M:%S"),
        now.strftime("%Y-%m-%d"),
        install_id,
        clamp_str(data.get("tool_version"), 20, "unknown"),
        clamp_str(data.get("os"), 60, ""),
        clamp_str(data.get("build"), 20, ""),
        vendor,
        adapter_type,
        mode,
        success,
        opt_count,
        clamp_num(data.get("latency_before"), 0, 10000),
        clamp_num(data.get("latency_after"), 0, 10000),
        clamp_num(data.get("loss_before"), 0, 100),
        clamp_num(data.get("loss_after"), 0, 100),
    )
    db = get_db()
    db.execute(
        """INSERT INTO reports
           (ts,date,install_id,tool_version,os,build,vendor,adapter_type,
            mode,success,opt_count,latency_before,latency_after,loss_before,loss_after)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        row,
    )
    db.commit()
    return jsonify(ok=True)


def aggregate():
    db = get_db()
    total = db.execute("SELECT COUNT(*) c FROM reports").fetchone()["c"]
    users = db.execute("SELECT COUNT(DISTINCT install_id) c FROM reports").fetchone()["c"]
    today = datetime.now().strftime("%Y-%m-%d")
    today_n = db.execute("SELECT COUNT(*) c FROM reports WHERE date=?", (today,)).fetchone()["c"]
    succ = db.execute("SELECT COALESCE(SUM(success),0) s, COUNT(*) n FROM reports").fetchone()
    success_rate = round(100.0 * succ["s"] / succ["n"], 1) if succ["n"] else 0.0

    lat = db.execute(
        """SELECT AVG(latency_before) b, AVG(latency_after) a FROM reports
           WHERE success=1 AND latency_before IS NOT NULL AND latency_after IS NOT NULL"""
    ).fetchone()
    lat_improve = None
    if lat["b"] and lat["a"] and lat["b"] > 0:
        lat_improve = round(100.0 * (lat["b"] - lat["a"]) / lat["b"], 1)

    vendor = [dict(r) for r in db.execute(
        "SELECT vendor k, COUNT(*) v FROM reports GROUP BY vendor ORDER BY v DESC")]
    mode = [dict(r) for r in db.execute(
        "SELECT mode k, COUNT(*) v FROM reports GROUP BY mode ORDER BY v DESC")]
    osrows = [dict(r) for r in db.execute("SELECT os FROM reports")]
    osc = Counter(norm_os(r["os"]) for r in osrows)
    days = [dict(r) for r in db.execute(
        "SELECT date d, COUNT(*) v FROM reports GROUP BY date ORDER BY d")]
    return {
        "total_reports": total,
        "unique_installs": users,
        "today": today_n,
        "success_rate": success_rate,
        "avg_latency_before": round(lat["b"], 1) if lat["b"] else None,
        "avg_latency_after": round(lat["a"], 1) if lat["a"] else None,
        "latency_improve_pct": lat_improve,
        "vendor": vendor,
        "mode": mode,
        "os": [{"k": k, "v": v} for k, v in osc.most_common()],
        "daily": days,
    }


@app.get("/api/stats")
def stats():
    return jsonify(aggregate())


# ----------------------------- 图表 -----------------------------
PALETTE = ["#4C8BF5", "#34A853", "#FBBC05", "#EA4335", "#9C27B0",
           "#00ACC1", "#FF7043", "#8D6E63", "#7CB342", "#B0BEC5"]
MODE_LABEL = {
    "proxy_clean": "Proxy Clean", "campus": "Campus Mode", "gaming": "Game Mode",
    "latency_test": "Latency Test", "other": "Other",
}


def _pie(rows, title, label_map=None):
    labels = [(label_map or {}).get(r["k"], r["k"]) for r in rows]
    sizes = [r["v"] for r in rows]
    fig, ax = plt.subplots(figsize=(6.4, 4.2), dpi=130)
    if sum(sizes) == 0:
        ax.text(0.5, 0.5, "No data yet", ha="center", va="center",
                fontsize=16, color="#999")
        ax.axis("off")
    else:
        wedges, _texts, autotexts = ax.pie(
            sizes, autopct=lambda p: f"{p:.1f}%" if p >= 3 else "",
            startangle=90, colors=PALETTE[:len(sizes)],
            wedgeprops=dict(width=0.42, edgecolor="white"))
        ax.legend(wedges, [f"{l} ({s})" for l, s in zip(labels, sizes)],
                  loc="center left", bbox_to_anchor=(0.92, 0.5), fontsize=9, frameon=False)
        for t in autotexts:
            t.set_fontsize(9)
    ax.set_title(title, fontsize=14, fontweight="bold", pad=14)
    fig.tight_layout()
    return fig


def chart_usage(agg):
    daily = agg["daily"]
    # 补齐最近 30 天
    today = datetime.now().date()
    dmap = {d["d"]: d["v"] for d in daily}
    xs, ys = [], []
    for i in range(29, -1, -1):
        d = (today - timedelta(days=i)).strftime("%Y-%m-%d")
        xs.append(d[5:])
        ys.append(dmap.get(d, 0))
    fig, ax = plt.subplots(figsize=(8.2, 3.8), dpi=130)
    bars = ax.bar(xs, ys, color="#4C8BF5", width=0.7)
    if not any(ys):
        ax.text(0.5, 0.5, "No data yet", transform=ax.transAxes,
                ha="center", va="center", fontsize=16, color="#999")
    ax.set_title("Daily Usage (last 30 days)  Total: %d" % agg["total_reports"],
                 fontsize=13, fontweight="bold", pad=10)
    ax.set_ylabel("Reports")
    step = max(1, len(xs) // 10)
    ax.set_xticks(range(0, len(xs), step))
    ax.set_xticklabels(xs[::step], rotation=45, fontsize=8)
    ax.grid(axis="y", alpha=0.25)
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    fig.tight_layout()
    return fig


def chart_latency(agg):
    b, a = agg["avg_latency_before"], agg["avg_latency_after"]
    fig, ax = plt.subplots(figsize=(5.6, 4.0), dpi=130)
    if b is None or a is None:
        ax.text(0.5, 0.5, "No latency data yet", ha="center", va="center",
                fontsize=15, color="#999")
        ax.axis("off")
    else:
        vals = [b, a]
        bars = ax.bar(["Before", "After"], vals, color=["#EA4335", "#34A853"], width=0.5)
        for rect, v in zip(bars, vals):
            ax.annotate(f"{v:.1f} ms", (rect.get_x() + rect.get_width() / 2, v),
                        ha="center", va="bottom", fontsize=11, fontweight="bold")
        imp = agg["latency_improve_pct"]
        ax.set_title(f"Avg Latency  (improved {imp:+.1f}%)",
                     fontsize=13, fontweight="bold", pad=10)
        ax.set_ylabel("ms")
        ax.set_ylim(0, max(vals) * 1.2)
        ax.grid(axis="y", alpha=0.25)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
    fig.tight_layout()
    return fig


@app.get("/chart")
def chart():
    ctype = request.args.get("type", "usage")
    force = request.args.get("no_cache") or request.args.get("t")
    if not force and ctype in _chart_cache:
        ts, buf = _chart_cache[ctype]
        if (datetime.now() - ts).total_seconds() < CHART_CACHE_SEC:
            return png_response(buf)

    agg = aggregate()
    import io
    with _plot_lock:
        _ensure_plt()
        if ctype == "vendor":
            fig = _pie(agg["vendor"], "Adapter Vendor Distribution")
        elif ctype == "os":
            fig = _pie(agg["os"], "Windows Version Share")
        elif ctype == "mode":
            fig = _pie(agg["mode"], "Optimization Mode", MODE_LABEL)
        elif ctype == "latency":
            fig = chart_latency(agg)
        else:
            ctype = "usage"
            fig = chart_usage(agg)
        buf = io.BytesIO()
        fig.savefig(buf, format="png", bbox_inches="tight")
        plt.close(fig)
    buf.seek(0)
    _chart_cache[ctype] = (datetime.now(), buf)
    return png_response(buf)


# ----------------------------- 看板 -----------------------------
DASHBOARD = r"""<!doctype html><html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>「小明」校园网加速工具箱 · 匿名统计</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<style>
:root{--card:#161b22;--bd:#30363d;--fg:#e6edf3;--mut:#8b949e;--blue:#58a6ff;--grn:#3fb950;--red:#f85149;--yel:#d29922;--pur:#bc8cff}
*{box-sizing:border-box;margin:0}
body{font-family:-apple-system,"Segoe UI","Microsoft YaHei",sans-serif;background:linear-gradient(180deg,#0d1117,#0a0e14);color:var(--fg);padding:28px;min-height:100vh}
.wrap{max-width:1080px;margin:0 auto}
header{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px;margin-bottom:6px}
h1{font-size:22px;font-weight:700}h1 span{color:var(--blue)}
.badge{display:inline-block;padding:3px 11px;border:1px solid var(--bd);border-radius:20px;font-size:12px;color:var(--mut);margin-left:6px}
.badge.on{color:var(--grn)}
.kpis{display:grid;grid-template-columns:repeat(5,1fr);gap:14px;margin:20px 0}
.kpi{background:var(--card);border:1px solid var(--bd);border-radius:14px;padding:18px}
.kpi .n{font-size:30px;font-weight:800;letter-spacing:-.5px}
.kpi .l{font-size:12.5px;color:var(--mut);margin-top:5px}
.kpi.blue .n{color:var(--blue)}.kpi.grn .n{color:var(--grn)}.kpi.yel .n{color:var(--yel)}.kpi.pur .n{color:var(--pur)}
.grid{display:grid;grid-template-columns:1.5fr 1fr;gap:16px}
.grid2{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:16px}
.card{background:var(--card);border:1px solid var(--bd);border-radius:14px;padding:18px}
.card h3{font-size:12px;color:var(--mut);font-weight:600;margin-bottom:12px;letter-spacing:.5px;text-transform:uppercase}
.cbox{position:relative;height:230px}.cbox.sm{height:185px}
footer{margin-top:24px;color:var(--mut);font-size:12px;line-height:1.8;border-top:1px solid var(--bd);padding-top:14px}
code{background:#21262d;padding:2px 6px;border-radius:5px;color:#79c0ff}
@media(max-width:820px){.kpis{grid-template-columns:repeat(2,1fr)}.grid,.grid2{grid-template-columns:1fr}}
</style></head><body><div class="wrap">
<header>
  <h1>「<span>小明</span>」校园网加速工具箱</h1>
  <div><span class="badge on">● LIVE</span><span class="badge">anonymous stats</span></div>
</header>
<div class="kpis">
  <div class="kpi blue"><div class="n" id="total">-</div><div class="l">累计调用</div></div>
  <div class="kpi pur"><div class="n" id="users">-</div><div class="l">匿名安装数</div></div>
  <div class="kpi blue"><div class="n" id="today">-</div><div class="l">今日调用</div></div>
  <div class="kpi grn"><div class="n" id="succ">-</div><div class="l">成功率</div></div>
  <div class="kpi yel"><div class="n" id="imp">-</div><div class="l">平均延迟改善</div></div>
</div>
<div class="grid">
  <div class="card"><h3>每日调用趋势（近30天）</h3><div class="cbox"><canvas id="cDaily"></canvas></div></div>
  <div class="card"><h3>网关延迟 · 优化前后</h3><div class="cbox"><canvas id="cLat"></canvas></div></div>
</div>
<div class="grid2">
  <div class="card"><h3>网卡厂商</h3><div class="cbox sm"><canvas id="cVendor"></canvas></div></div>
  <div class="card"><h3>使用模式</h3><div class="cbox sm"><canvas id="cMode"></canvas></div></div>
  <div class="card"><h3>Windows 版本</h3><div class="cbox sm"><canvas id="cOs"></canvas></div></div>
</div>
<footer>
  数据完全匿名：仅含系统版本、网卡厂商、使用模式、成功与否、延迟改善等汇总，<b>不含</b> IP / 主机名 / MAC / 账号 / 位置。<br>
  供 README 嵌入的静态图：<code>/chart?type=usage</code> · vendor · os · mode · latency
</footer>
</div>
<script>
const COL=['#58a6ff','#3fb950','#d29922','#f85149','#bc8cff','#39d2c0','#ff7b72','#79c0ff'];
const axis={ticks:{color:'#8b949e',font:{size:10}},grid:{color:'#21262d'}};
function doughnut(id,rows){new Chart(document.getElementById(id),{type:'doughnut',data:{labels:rows.map(r=>r.k),datasets:[{data:rows.map(r=>r.v),backgroundColor:COL,borderColor:'#0d1117',borderWidth:2}]},options:{cutout:'68%',responsive:true,maintainAspectRatio:false,plugins:{legend:{position:'right',labels:{color:'#8b949e',boxWidth:10,font:{size:11}}}}}})}
async function go(){
  const d=await (await fetch('/api/stats')).json();
  total.textContent=d.total_reports;users.textContent=d.unique_installs;today.textContent=d.today;
  succ.textContent=d.success_rate+'%';imp.textContent=(d.latency_improve_pct==null?'-':d.latency_improve_pct+'%');
  new Chart(document.getElementById('cDaily'),{type:'bar',data:{labels:d.daily.map(r=>r.d),datasets:[{data:d.daily.map(r=>r.v),backgroundColor:'#58a6ff',borderRadius:4}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false}},scales:{x:axis,y:{...axis,beginAtZero:true,ticks:{...axis.ticks,precision:0}}}}});
  new Chart(document.getElementById('cLat'),{type:'bar',data:{labels:['优化前','优化后'],datasets:[{data:[d.avg_latency_before||0,d.avg_latency_after||0],backgroundColor:['#f85149','#3fb950'],borderRadius:6}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false}},scales:{y:{...axis,beginAtZero:true}}}});
  if(d.vendor.length)doughnut('cVendor',d.vendor);
  if(d.mode.length)doughnut('cMode',d.mode);
  if(d.os.length)doughnut('cOs',d.os);
}
go();
</script></body></html>"""


@app.get("/")
def dashboard():
    return Response(DASHBOARD, mimetype="text/html")


# 模块导入即建表（waitress 导入 app 时生效）
init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)
