#!/bin/bash
# ═══════════════════════════════════════════════════════════
#     PROXY TELEGRAM @memes4u1337 — Установка веб-панели
# ═══════════════════════════════════════════════════════════

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()  { echo -e "${GREEN}✔${NC} $*"; }
log() { echo -e "${BOLD}${CYAN}▶${NC} $*"; }
die() { echo -e "${RED}✖ $*${NC}"; exit 1; }

[ "$EUID" -ne 0 ] && die "Запусти от root: sudo bash install_panel.sh"

PANEL_DIR="/opt/mtproto_panel"
SERVICE="mtproto-panel"
PANEL_PORT="8888"

clear
echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
  ██████╗ ██████╗  ██████╗ ██╗  ██╗██╗   ██╗    ████████╗ ██████╗
  ██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝    ╚══██╔══╝██╔════╝
  ██████╔╝██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝        ██║   ██║  ███╗
  ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝         ██║   ██║   ██║
  ██║     ██║  ██║╚██████╔╝██╔╝ ██╗   ██║           ██║   ╚██████╔╝
  ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝           ╚═╝    ╚═════╝
BANNER
echo -e "${NC}"
echo -e "  ${BOLD}PROXY TELEGRAM @memes4u1337 — Установка панели${NC}"
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
echo ""

# ── Получаем реальный IP ──
log "Определяем IP сервера..."
SERVER_IP=""
for url in https://ifconfig.me https://api.ipify.org https://icanhazip.com https://ident.me; do
    SERVER_IP=$(curl -s --max-time 6 "$url" 2>/dev/null | tr -d '[:space:]')
    [ -n "$SERVER_IP" ] && break
done
[ -z "$SERVER_IP" ] && die "Не удалось определить IP. Проверь интернет."
ok "IP сервера: ${YELLOW}${SERVER_IP}${NC}"

# ── Генерируем логин и пароль ──
log "Генерируем учётные данные..."
PANEL_USER="admin"
PANEL_PASS=$(python3 -c "import secrets,string; a=string.ascii_letters+string.digits; print(''.join(secrets.choice(a) for _ in range(16)))")
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
PW_HASH=$(python3 -c "import hashlib; print(hashlib.sha256('${PANEL_PASS}'.encode()).hexdigest())")
ok "Логин: ${YELLOW}${PANEL_USER}${NC}"
ok "Пароль: ${YELLOW}${PANEL_PASS}${NC}"

# ── pip ──
log "Проверяем pip..."
command -v pip3 &>/dev/null || apt install -y python3-pip -q
ok "pip готов"

# ── Копируем файлы ──
log "Копируем файлы панели..."
mkdir -p "$PANEL_DIR/templates"
cp app.py "$PANEL_DIR/" 2>/dev/null || \
    curl -s -o "$PANEL_DIR/app.py" \
    "https://raw.githubusercontent.com/memes4u1337/proxy-telegram-memes4u1337/main/panel/app.py"
cp templates/login.html "$PANEL_DIR/templates/" 2>/dev/null || \
    curl -s -o "$PANEL_DIR/templates/login.html" \
    "https://raw.githubusercontent.com/memes4u1337/proxy-telegram-memes4u1337/main/panel/templates/login.html"
cp templates/index.html "$PANEL_DIR/templates/" 2>/dev/null || \
    curl -s -o "$PANEL_DIR/templates/index.html" \
    "https://raw.githubusercontent.com/memes4u1337/proxy-telegram-memes4u1337/main/panel/templates/index.html"
ok "Файлы скопированы"

# ── Flask ──
log "Устанавливаем Flask..."
pip3 install flask==3.0.3 --break-system-packages -q
ok "Flask установлен"

# ── Credentials ──
cat > "/opt/panel_creds.json" << EOF
{"username": "${PANEL_USER}", "password": "${PW_HASH}"}
EOF
ok "Учётные данные сохранены"

# ── Firewall ──
log "Открываем порт $PANEL_PORT..."
ufw allow "${PANEL_PORT}/tcp" &>/dev/null || true
ok "Порт открыт"

# ── Systemd ──
log "Создаём systemd сервис..."
cat > "/etc/systemd/system/${SERVICE}.service" << EOF
[Unit]
Description=PROXY TELEGRAM @memes4u1337 — Web Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=${PANEL_DIR}
Environment=PANEL_PORT=${PANEL_PORT}
Environment=PANEL_SECRET=${SECRET_KEY}
Environment=CONTAINER_NAME=mtproto-memes4u1337
Environment=CONFIG_FILE=/opt/mtproto_memes4u1337.conf
Environment=SETUP_SCRIPT=/opt/mtproto_setup.sh
Environment=CREDS_FILE=/opt/panel_creds.json
ExecStart=/usr/bin/python3 ${PANEL_DIR}/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE" &>/dev/null
systemctl start "$SERVICE"
ok "Сервис запущен"

# ── Итог ──
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║   PROXY TELEGRAM @memes4u1337 — ПАНЕЛЬ ГОТОВА! 🚀   ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  ${BOLD}🌐 Адрес панели:${NC}"
echo -e "  ${GREEN}${BOLD}http://${SERVER_IP}:${PANEL_PORT}${NC}"
echo ""
echo -e "  ${BOLD}🔐 Данные для входа:${NC}"
printf "  ${BOLD}%-12s${NC} %s\n" "Логин:"  "$PANEL_USER"
printf "  ${BOLD}%-12s${NC} %s\n" "Пароль:" "$PANEL_PASS"
echo ""
echo -e "${YELLOW}  ⚠  Сохрани пароль — он больше не будет показан!${NC}"
echo ""
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
echo -e "  Логи:     ${CYAN}journalctl -u ${SERVICE} -f${NC}"
echo -e "  Рестарт:  ${CYAN}systemctl restart ${SERVICE}${NC}"
echo ""
ok "Открой в браузере: http://${SERVER_IP}:${PANEL_PORT} 🚀"

# Сохраняем данные в файл
cat > "/opt/panel_access.txt" << EOF
# PROXY TELEGRAM @memes4u1337 — Panel Access
URL=http://${SERVER_IP}:${PANEL_PORT}
LOGIN=${PANEL_USER}
PASSWORD=${PANEL_PASS}
EOF
echo -e "  Данные сохранены: ${CYAN}/opt/panel_access.txt${NC}"
