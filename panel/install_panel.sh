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
PANEL_PORT="${1:-8888}"
PANEL_USER="${2:-admin}"
PANEL_PASS="${3:-admin1337}"

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

# ── Python ──
log "Проверяем Python..."
command -v python3 &>/dev/null || apt install -y python3
ok "Python: $(python3 --version)"

# ── pip ──
log "Проверяем pip..."
command -v pip3 &>/dev/null || apt install -y python3-pip
ok "pip готов"

# ── Копируем файлы ──
log "Копируем файлы панели в $PANEL_DIR..."
mkdir -p "$PANEL_DIR/templates"
cp app.py "$PANEL_DIR/"
cp requirements.txt "$PANEL_DIR/"
cp templates/login.html "$PANEL_DIR/templates/"
cp templates/index.html "$PANEL_DIR/templates/"
ok "Файлы скопированы"

# ── Устанавливаем Flask ──
log "Устанавливаем Flask..."
pip3 install flask==3.0.3 --break-system-packages -q
ok "Flask установлен"

# ── Генерируем секрет и сохраняем credentials ──
log "Настраиваем учётные данные..."
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
PW_HASH=$(python3 -c "import hashlib; print(hashlib.sha256('${PANEL_PASS}'.encode()).hexdigest())")

cat > "/opt/panel_creds.json" << EOF
{"username": "${PANEL_USER}", "password": "${PW_HASH}"}
EOF
ok "Credentials сохранены"

# ── Открываем порт ──
log "Открываем порт $PANEL_PORT..."
ufw allow "${PANEL_PORT}/tcp" &>/dev/null || true
ok "Порт $PANEL_PORT открыт"

# ── Создаём systemd сервис ──
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
systemctl enable "$SERVICE"
systemctl start "$SERVICE"
ok "Сервис запущен"

# ── Получаем IP ──
SERVER_IP=$(curl -s --max-time 8 https://ifconfig.me 2>/dev/null || echo "YOUR_IP")

# ── Итог ──
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║   PROXY TELEGRAM @memes4u1337 — Панель установлена! ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
printf "  ${BOLD}%-20s${NC} %s\n" "🌐 Адрес панели:" "http://${SERVER_IP}:${PANEL_PORT}"
printf "  ${BOLD}%-20s${NC} %s\n" "👤 Логин:"        "$PANEL_USER"
printf "  ${BOLD}%-20s${NC} %s\n" "🔑 Пароль:"       "$PANEL_PASS"
echo ""
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
echo -e "  Логи панели:  ${CYAN}journalctl -u ${SERVICE} -f${NC}"
echo -e "  Рестарт:      ${CYAN}systemctl restart ${SERVICE}${NC}"
echo ""
ok "Готово! Открой браузер: http://${SERVER_IP}:${PANEL_PORT} 🚀"
