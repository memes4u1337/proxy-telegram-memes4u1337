#!
"""
╔══════════════════════════════════════════════════════╗
║     PROXY TELEGRAM @memes4u1337 — Web Panel          ║
╚══════════════════════════════════════════════════════╝
"""

import os
import re
import subprocess
import hashlib
import secrets
import json
from datetime import datetime
from functools import wraps
from flask import Flask, render_template, request, jsonify, session, redirect, url_for

app = Flask(__name__)
app.secret_key = os.getenv("PANEL_SECRET", secrets.token_hex(32))

# ── Настройки ──────────────────────────────────────────────────
CONTAINER_NAME = os.getenv("CONTAINER_NAME", "mtproto-memes4u1337")
CONFIG_FILE    = os.getenv("CONFIG_FILE",    "/opt/mtproto_memes4u1337.conf")
SETUP_SCRIPT   = os.getenv("SETUP_SCRIPT",  "/opt/mtproto_setup.sh")
CREDS_FILE     = os.getenv("CREDS_FILE",    "/opt/panel_creds.json")
PANEL_PORT     = int(os.getenv("PANEL_PORT", "8888"))

# ── Auth helpers ───────────────────────────────────────────────

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def load_creds() -> dict:
    try:
        with open(CREDS_FILE) as f:
            return json.load(f)
    except Exception:
        default = {"username": "admin", "password": hash_password("admin1337")}
        save_creds(default)
        return default


def save_creds(creds: dict):
    with open(CREDS_FILE, "w") as f:
        json.dump(creds, f)


def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get("logged_in"):
            return redirect(url_for("login"))
        return f(*args, **kwargs)
    return decorated


# ── Proxy helpers ──────────────────────────────────────────────

def read_config() -> dict:
    cfg = {}
    try:
        with open(CONFIG_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    cfg[k.strip()] = v.strip()
    except Exception:
        pass
    return cfg


def docker_running() -> bool:
    try:
        r = subprocess.run(
            ["docker", "ps", "--filter", f"name=^{CONTAINER_NAME}$",
             "--filter", "status=running", "--format", "{{.Names}}"],
            capture_output=True, text=True, timeout=10
        )
        return CONTAINER_NAME in r.stdout
    except Exception:
        return False


def docker_connections() -> int:
    """Примерное количество активных соединений через прокси."""
    try:
        r = subprocess.run(
            ["sh", "-c", f"ss -tn | grep ':{read_config().get('PORT','443')}' | grep ESTAB | wc -l"],
            capture_output=True, text=True, timeout=10
        )
        return int(r.stdout.strip() or 0)
    except Exception:
        return 0


def docker_uptime() -> str:
    try:
        r = subprocess.run(
            ["docker", "inspect", "--format", "{{.State.StartedAt}}", CONTAINER_NAME],
            capture_output=True, text=True, timeout=10
        )
        started = r.stdout.strip()
        if started:
            dt = datetime.fromisoformat(started[:19])
            delta = datetime.utcnow() - dt
            h, rem = divmod(int(delta.total_seconds()), 3600)
            m = rem // 60
            return f"{h}ч {m}мин"
    except Exception:
        pass
    return "—"


def docker_logs(lines=50) -> str:
    try:
        r = subprocess.run(
            ["docker", "logs", "--tail", str(lines), CONTAINER_NAME],
            capture_output=True, text=True, timeout=15
        )
        return (r.stdout + r.stderr).strip() or "Логи пусты"
    except Exception as e:
        return str(e)


def bot_running() -> bool:
    try:
        r = subprocess.run(
            ["systemctl", "is-active", "mtproto-bot"],
            capture_output=True, text=True, timeout=10
        )
        return r.stdout.strip() == "active"
    except Exception:
        return False


# ── Routes ─────────────────────────────────────────────────────

@app.route("/login", methods=["GET", "POST"])
def login():
    error = ""
    if request.method == "POST":
        creds = load_creds()
        username = request.form.get("username", "")
        password = request.form.get("password", "")
        if username == creds["username"] and hash_password(password) == creds["password"]:
            session["logged_in"] = True
            session["username"] = username
            return redirect(url_for("index"))
        error = "Неверный логин или пароль"
    return render_template("login.html", error=error)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/")
@login_required
def index():
    cfg = read_config()
    return render_template("index.html",
        running=docker_running(),
        bot_running=bot_running(),
        cfg=cfg,
        uptime=docker_uptime(),
        connections=docker_connections(),
        username=session.get("username", "admin")
    )


# ── API ────────────────────────────────────────────────────────

@app.route("/api/status")
@login_required
def api_status():
    cfg = read_config()
    return jsonify({
        "proxy": docker_running(),
        "bot": bot_running(),
        "uptime": docker_uptime(),
        "connections": docker_connections(),
        "server": cfg.get("SERVER", "—"),
        "port": cfg.get("PORT", "—"),
        "domain": cfg.get("DOMAIN", "—"),
        "link": cfg.get("LINK", ""),
        "secret": cfg.get("SECRET", "—"),
    })


@app.route("/api/proxy/restart", methods=["POST"])
@login_required
def api_proxy_restart():
    try:
        subprocess.run(["docker", "restart", CONTAINER_NAME], timeout=30)
        return jsonify({"ok": True, "msg": "Прокси перезапущен"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)})


@app.route("/api/proxy/stop", methods=["POST"])
@login_required
def api_proxy_stop():
    try:
        subprocess.run(["docker", "stop", CONTAINER_NAME], timeout=30)
        return jsonify({"ok": True, "msg": "Прокси остановлен"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)})


@app.route("/api/proxy/start", methods=["POST"])
@login_required
def api_proxy_start():
    try:
        subprocess.run(["docker", "start", CONTAINER_NAME], timeout=30)
        return jsonify({"ok": True, "msg": "Прокси запущен"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)})


@app.route("/api/proxy/regen", methods=["POST"])
@login_required
def api_proxy_regen():
    domain = request.json.get("domain", "ya.ru") if request.is_json else "ya.ru"
    # Валидация домена
    if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}$', domain):
        return jsonify({"ok": False, "msg": "Неверный формат домена"})
    try:
        r = subprocess.run(
            ["bash", SETUP_SCRIPT, domain],
            capture_output=True, text=True, timeout=120
        )
        if r.returncode == 0:
            cfg = read_config()
            return jsonify({"ok": True, "msg": "Прокси пересоздан", "link": cfg.get("LINK", "")})
        return jsonify({"ok": False, "msg": r.stderr[-300:]})
    except subprocess.TimeoutExpired:
        return jsonify({"ok": False, "msg": "Таймаут — скрипт работает слишком долго"})


@app.route("/api/bot/restart", methods=["POST"])
@login_required
def api_bot_restart():
    try:
        subprocess.run(["systemctl", "restart", "mtproto-bot"], timeout=30)
        return jsonify({"ok": True, "msg": "Бот перезапущен"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)})


@app.route("/api/bot/stop", methods=["POST"])
@login_required
def api_bot_stop():
    try:
        subprocess.run(["systemctl", "stop", "mtproto-bot"], timeout=30)
        return jsonify({"ok": True, "msg": "Бот остановлен"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)})


@app.route("/api/bot/start", methods=["POST"])
@login_required
def api_bot_start():
    try:
        subprocess.run(["systemctl", "start", "mtproto-bot"], timeout=30)
        return jsonify({"ok": True, "msg": "Бот запущен"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)})


@app.route("/api/logs")
@login_required
def api_logs():
    lines = int(request.args.get("lines", 50))
    return jsonify({"logs": docker_logs(lines)})


@app.route("/api/change-password", methods=["POST"])
@login_required
def api_change_password():
    data = request.json or {}
    old_pw = data.get("old_password", "")
    new_pw = data.get("new_password", "")
    if len(new_pw) < 6:
        return jsonify({"ok": False, "msg": "Пароль минимум 6 символов"})
    creds = load_creds()
    if hash_password(old_pw) != creds["password"]:
        return jsonify({"ok": False, "msg": "Неверный текущий пароль"})
    creds["password"] = hash_password(new_pw)
    save_creds(creds)
    return jsonify({"ok": True, "msg": "Пароль изменён"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PANEL_PORT, debug=False)
