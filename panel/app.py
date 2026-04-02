#!/usr/bin/env python3
"""
PROXY TELEGRAM @memes4u1337 — Web Panel
"""

import os, re, subprocess, hashlib, secrets, json, ssl
from datetime import datetime
from functools import wraps
from flask import Flask, render_template, request, jsonify, session, redirect, url_for

app = Flask(__name__)
app.secret_key = os.getenv("PANEL_SECRET", secrets.token_hex(32))

CONTAINER_NAME = os.getenv("CONTAINER_NAME", "mtproto-memes4u1337")
CONFIG_FILE    = os.getenv("CONFIG_FILE",    "/opt/mtproto_memes4u1337.conf")
SETUP_SCRIPT   = os.getenv("SETUP_SCRIPT",  "/opt/mtproto_setup.sh")
CREDS_FILE     = os.getenv("CREDS_FILE",    "/opt/panel_creds.json")
USERS_FILE     = os.getenv("USERS_FILE",    "/opt/panel_users.json")
PANEL_PORT     = int(os.getenv("PANEL_PORT", "8888"))
CERT_FILE      = "/opt/mtproto_panel/cert.pem"
KEY_FILE       = "/opt/mtproto_panel/key.pem"

def hash_password(p): return hashlib.sha256(p.encode()).hexdigest()

def load_creds():
    try:
        with open(CREDS_FILE) as f: return json.load(f)
    except:
        d = {"username":"admin","password":hash_password("admin1337")}
        save_creds(d); return d

def save_creds(c):
    with open(CREDS_FILE,"w") as f: json.dump(c,f)

def load_users():
    try:
        with open(USERS_FILE) as f: return json.load(f)
    except:
        return []

def login_required(f):
    @wraps(f)
    def dec(*a,**kw):
        if not session.get("logged_in"): return redirect(url_for("login"))
        return f(*a,**kw)
    return dec

def read_config():
    cfg = {}
    try:
        with open(CONFIG_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k,v = line.split("=",1)
                    cfg[k.strip()] = v.strip()
    except: pass
    return cfg

def docker_running():
    try:
        r = subprocess.run(["docker","ps","--filter",f"name=^{CONTAINER_NAME}$",
            "--filter","status=running","--format","{{.Names}}"],
            capture_output=True,text=True,timeout=10)
        return CONTAINER_NAME in r.stdout
    except: return False

def docker_connections():
    try:
        port = read_config().get("PORT","443")
        r = subprocess.run(["sh","-c",f"ss -tn | grep ':{port}' | grep ESTAB | wc -l"],
            capture_output=True,text=True,timeout=10)
        return int(r.stdout.strip() or 0)
    except: return 0

def docker_uptime():
    try:
        r = subprocess.run(["docker","inspect","--format","{{.State.StartedAt}}",CONTAINER_NAME],
            capture_output=True,text=True,timeout=10)
        s = r.stdout.strip()
        if s:
            dt = datetime.fromisoformat(s[:19])
            d = datetime.utcnow()-dt
            h,rem = divmod(int(d.total_seconds()),3600)
            return f"{h}h {rem//60}m"
    except: pass
    return "—"

def docker_logs(n=50):
    try:
        r = subprocess.run(["docker","logs","--tail",str(n),CONTAINER_NAME],
            capture_output=True,text=True,timeout=15)
        return (r.stdout+r.stderr).strip() or "Empty"
    except Exception as e: return str(e)

def bot_running():
    try:
        r = subprocess.run(["systemctl","is-active","mtproto-bot"],
            capture_output=True,text=True,timeout=10)
        return r.stdout.strip()=="active"
    except: return False

def ssl_exists():
    return os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE)

def get_ssl_info():
    if not ssl_exists():
        return None
    try:
        r = subprocess.run(
            ["openssl","x509","-in",CERT_FILE,"-noout","-dates"],
            capture_output=True,text=True,timeout=10
        )
        info = {}
        for line in r.stdout.strip().split("\n"):
            if "=" in line:
                k,v = line.split("=",1)
                info[k.strip()] = v.strip()
        return info
    except:
        return {}

# ── Routes ─────────────────────────────────────────────────────

@app.route("/login",methods=["GET","POST"])
def login():
    error=""
    if request.method=="POST":
        c=load_creds()
        if request.form.get("username")==c["username"] and \
           hash_password(request.form.get("password",""))==c["password"]:
            session["logged_in"]=True
            session["username"]=c["username"]
            return redirect(url_for("index"))
        error="Неверный логин или пароль"
    return render_template("login.html",error=error)

@app.route("/logout")
def logout():
    session.clear(); return redirect(url_for("login"))

@app.route("/")
@login_required
def index():
    cfg=read_config()
    return render_template("index.html",
        running=docker_running(), bot_running=bot_running(),
        cfg=cfg, uptime=docker_uptime(),
        connections=docker_connections(),
        username=session.get("username","admin"),
        users=load_users(),
        ssl_exists=ssl_exists(),
        ssl_info=get_ssl_info(),
        panel_port=PANEL_PORT,
    )

@app.route("/api/status")
@login_required
def api_status():
    cfg=read_config()
    return jsonify({
        "proxy":docker_running(),"bot":bot_running(),
        "uptime":docker_uptime(),"connections":docker_connections(),
        "server":cfg.get("SERVER","—"),"port":cfg.get("PORT","—"),
        "domain":cfg.get("DOMAIN","—"),"link":cfg.get("LINK",""),
        "secret":cfg.get("SECRET","—"),
        "ssl":ssl_exists(),
    })

@app.route("/api/proxy/<action>",methods=["POST"])
@login_required
def api_proxy(action):
    if action not in ["start","stop","restart"]:
        return jsonify({"ok":False,"msg":"Unknown action"})
    try:
        subprocess.run(["docker",action,CONTAINER_NAME],timeout=30)
        return jsonify({"ok":True,"msg":f"Proxy {action} done"})
    except Exception as e: return jsonify({"ok":False,"msg":str(e)})

@app.route("/api/proxy/regen",methods=["POST"])
@login_required
def api_regen():
    domain=(request.json or {}).get("domain","ya.ru")
    if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}$',domain):
        return jsonify({"ok":False,"msg":"Invalid domain"})
    try:
        r=subprocess.run(["bash",SETUP_SCRIPT,domain],
            capture_output=True,text=True,timeout=120)
        cfg=read_config()
        if r.returncode==0:
            return jsonify({"ok":True,"msg":"Proxy recreated","link":cfg.get("LINK","")})
        return jsonify({"ok":False,"msg":r.stderr[-300:]})
    except subprocess.TimeoutExpired:
        return jsonify({"ok":False,"msg":"Timeout"})

@app.route("/api/bot/<action>",methods=["POST"])
@login_required
def api_bot(action):
    if action not in ["start","stop","restart"]:
        return jsonify({"ok":False,"msg":"Unknown action"})
    try:
        subprocess.run(["systemctl",action,"mtproto-bot"],timeout=30)
        return jsonify({"ok":True,"msg":f"Bot {action} done"})
    except Exception as e: return jsonify({"ok":False,"msg":str(e)})

@app.route("/api/logs")
@login_required
def api_logs():
    return jsonify({"logs":docker_logs(int(request.args.get("lines",50)))})

@app.route("/api/users")
@login_required
def api_users():
    return jsonify({"users":load_users()})

@app.route("/api/ssl/generate",methods=["POST"])
@login_required
def api_ssl_generate():
    """Генерирует самоподписанный SSL сертификат и перезапускает панель на HTTPS."""
    try:
        data = request.json or {}
        days = int(data.get("days", 365))
        country = data.get("country", "RU")
        org = data.get("org", "PROXY TELEGRAM memes4u1337")

        # Генерируем ключ и сертификат
        subj = f"/C={country}/O={org}/CN=proxy-panel"
        r = subprocess.run([
            "openssl","req","-x509","-newkey","rsa:2048",
            "-keyout", KEY_FILE,
            "-out", CERT_FILE,
            "-days", str(days),
            "-nodes",
            "-subj", subj
        ], capture_output=True, text=True, timeout=30)

        if r.returncode != 0:
            return jsonify({"ok":False,"msg":r.stderr})

        # Обновляем systemd сервис чтобы использовал SSL
        service_file = "/etc/systemd/system/mtproto-panel.service"
        try:
            with open(service_file) as f:
                content = f.read()

            # Добавляем переменные SSL
            if "SSL_CERT" not in content:
                content = content.replace(
                    "ExecStart=",
                    f"Environment=SSL_CERT={CERT_FILE}\nEnvironment=SSL_KEY={KEY_FILE}\nExecStart="
                )
                with open(service_file,"w") as f:
                    f.write(content)

            subprocess.run(["systemctl","daemon-reload"],timeout=10)
            subprocess.run(["systemctl","restart","mtproto-panel"],timeout=15)
        except Exception as e:
            return jsonify({"ok":True,"msg":f"Certificate created but service restart failed: {e}. Restart manually."})

        info = get_ssl_info()
        return jsonify({
            "ok": True,
            "msg": f"SSL certificate generated for {days} days. Panel restarting on HTTPS...",
            "info": info
        })

    except Exception as e:
        return jsonify({"ok":False,"msg":str(e)})

@app.route("/api/ssl/remove",methods=["POST"])
@login_required
def api_ssl_remove():
    """Удаляет SSL и возвращает на HTTP."""
    try:
        if os.path.exists(CERT_FILE): os.remove(CERT_FILE)
        if os.path.exists(KEY_FILE):  os.remove(KEY_FILE)

        service_file = "/etc/systemd/system/mtproto-panel.service"
        try:
            with open(service_file) as f:
                content = f.read()
            content = content.replace(f"Environment=SSL_CERT={CERT_FILE}\n","")
            content = content.replace(f"Environment=SSL_KEY={KEY_FILE}\n","")
            with open(service_file,"w") as f:
                f.write(content)
            subprocess.run(["systemctl","daemon-reload"],timeout=10)
            subprocess.run(["systemctl","restart","mtproto-panel"],timeout=15)
        except: pass

        return jsonify({"ok":True,"msg":"SSL removed. Panel switching to HTTP..."})
    except Exception as e:
        return jsonify({"ok":False,"msg":str(e)})

@app.route("/api/change-password",methods=["POST"])
@login_required
def api_change_pw():
    data=request.json or {}
    old=data.get("old_password","")
    new=data.get("new_password","")
    if len(new)<6: return jsonify({"ok":False,"msg":"Min 6 chars"})
    c=load_creds()
    if hash_password(old)!=c["password"]:
        return jsonify({"ok":False,"msg":"Wrong current password"})
    c["password"]=hash_password(new)
    save_creds(c)
    return jsonify({"ok":True,"msg":"Password changed"})

if __name__=="__main__":
    ssl_cert = os.getenv("SSL_CERT","")
    ssl_key  = os.getenv("SSL_KEY","")

    if ssl_cert and ssl_key and os.path.exists(ssl_cert) and os.path.exists(ssl_key):
        print(f"Starting on HTTPS port {PANEL_PORT}")
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(ssl_cert, ssl_key)
        app.run(host="0.0.0.0", port=PANEL_PORT, ssl_context=ctx, debug=False)
    else:
        print(f"Starting on HTTP port {PANEL_PORT}")
        app.run(host="0.0.0.0", port=PANEL_PORT, debug=False)
