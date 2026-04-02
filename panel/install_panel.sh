#!/bin/bash
# ═══════════════════════════════════════════════════════════
#     PROXY TELEGRAM @memes4u1337 — Установка веб-панели
# ═══════════════════════════════════════════════════════════

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()  { echo -e "${GREEN}+${NC} $*"; }
log() { echo -e "${BOLD}${CYAN}>${NC} $*"; }
die() { echo -e "${RED}! $*${NC}"; exit 1; }

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

# ── Получаем только IPv4 ──
log "Определяем IPv4 адрес сервера..."
SERVER_IP=""
for url in \
    "https://api4.ipify.org" \
    "https://ipv4.icanhazip.com" \
    "https://ipv4bot.whatismyipaddress.com" \
    "https://v4.ident.me"; do
    IP=$(curl -4 -s --max-time 6 "$url" 2>/dev/null | tr -d '[:space:]')
    # Проверяем что это IPv4 (нет двоеточий)
    if echo "$IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        SERVER_IP="$IP"
        break
    fi
done
[ -z "$SERVER_IP" ] && die "Не удалось определить IPv4. Проверь интернет."
ok "IPv4 сервера: ${YELLOW}${SERVER_IP}${NC}"

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

for f in app.py; do
    if [ -f "$f" ]; then
        cp "$f" "$PANEL_DIR/"
    else
        curl -s -o "$PANEL_DIR/$f" \
        "https://raw.githubusercontent.com/memes4u1337/proxy-telegram-memes4u1337/main/panel/$f"
    fi
done

for f in login.html index.html; do
    if [ -f "templates/$f" ]; then
        cp "templates/$f" "$PANEL_DIR/templates/"
    else
        curl -s -o "$PANEL_DIR/templates/$f" \
        "https://raw.githubusercontent.com/memes4u1337/proxy-telegram-memes4u1337/main/panel/templates/$f"
    fi
done
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
Environment=USERS_FILE=/opt/panel_users.json
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

# ── Сохраняем доступ ──
cat > "/opt/panel_access.txt" << EOF
# PROXY TELEGRAM @memes4u1337 — Panel Access
URL=http://${SERVER_IP}:${PANEL_PORT}
LOGIN=${PANEL_USER}
PASSWORD=${PANEL_PASS}
EOF

# ── Итог ──
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║      PROXY TELEGRAM @memes4u1337 — ПАНЕЛЬ ГОТОВА    ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  ${BOLD}Адрес панели:${NC}"
echo -e "  ${GREEN}${BOLD}http://${SERVER_IP}:${PANEL_PORT}${NC}"
echo ""
echo -e "  ${BOLD}Данные для входа:${NC}"
printf "  %-12s %s\n" "Логин:"  "$PANEL_USER"
printf "  %-12s %s\n" "Пароль:" "$PANEL_PASS"
echo ""
echo -e "${YELLOW}  ! Сохрани пароль — больше не будет показан!${NC}"
echo -e "  Данные также в: ${CYAN}/opt/panel_access.txt${NC}"
echo ""
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
echo -e "  Логи:    ${CYAN}journalctl -u ${SERVICE} -f${NC}"
echo -e "  Рестарт: ${CYAN}systemctl restart ${SERVICE}${NC}"
echo ""
ok "Открой: http://${SERVER_IP}:${PANEL_PORT}"
