#!/bin/bash
# ═══════════════════════════════════════════════════════════
#     PROXY TELEGRAM by @memes4u1337 — Установка бота
# ═══════════════════════════════════════════════════════════
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()  { echo -e "${GREEN}✔${NC} $*"; }
log() { echo -e "${BOLD}${CYAN}▶${NC} $*"; }
die() { echo -e "${RED}✖ $*${NC}"; exit 1; }

[ "$EUID" -ne 0 ] && die "Запусти от root: sudo bash install_bot.sh"

BOT_DIR="/opt/mtproto_bot"
SERVICE_NAME="mtproto-bot"

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║   PROXY TELEGRAM by @memes4u1337 — Установка бота   ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Python ──
log "Проверяем Python..."
command -v python3 &>/dev/null || apt install -y python3
ok "Python: $(python3 --version)"

# ── pip ──
log "Проверяем pip..."
if ! command -v pip3 &>/dev/null; then
    apt install -y python3-pip
fi
ok "pip: $(pip3 --version)"

# ── Копируем файлы ──
log "Копируем файлы бота в $BOT_DIR..."
mkdir -p "$BOT_DIR"
cp bot.py requirements.txt "$BOT_DIR/"
[ -f ".env" ] && cp .env "$BOT_DIR/" && ok ".env скопирован"
ok "Файлы скопированы"

# ── Копируем скрипт прокси ──
log "Копируем mtproto_setup.sh в /opt/..."
cp mtproto_setup.sh /opt/mtproto_setup.sh
chmod +x /opt/mtproto_setup.sh
ok "Скрипт установки готов"

# ── Устанавливаем зависимости ──
log "Устанавливаем Python зависимости..."
pip3 install -r "$BOT_DIR/requirements.txt" -q --break-system-packages
ok "Зависимости установлены"

# ── Проверяем .env ──
if [ ! -f "$BOT_DIR/.env" ] || grep -q "ВАШ_ТОКЕН_СЮДА\|ADMIN_ID=0" "$BOT_DIR/.env" 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}⚠  ВАЖНО: Заполни .env файл перед запуском!${NC}"
    echo -e "   ${BOLD}nano $BOT_DIR/.env${NC}"
    echo ""
    echo -e "   BOT_TOKEN  — токен от @BotFather"
    echo -e "   ADMIN_ID   — твой ID из @userinfobot"
    echo ""
fi

# ── Создаём systemd сервис ──
log "Создаём systemd сервис..."
cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=PROXY TELEGRAM by @memes4u1337 — Telegram Bot
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
WorkingDirectory=${BOT_DIR}
EnvironmentFile=${BOT_DIR}/.env
ExecStart=/usr/bin/python3 ${BOT_DIR}/bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
ok "Сервис создан и добавлен в автозапуск"

echo ""
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}Что дальше:${NC}"
echo ""
echo -e "  1️⃣  Заполни конфиг (если ещё не заполнил):"
echo -e "     ${CYAN}nano $BOT_DIR/.env${NC}"
echo ""
echo -e "  2️⃣  Запусти бота:"
echo -e "     ${CYAN}systemctl start $SERVICE_NAME${NC}"
echo ""
echo -e "  3️⃣  Проверь статус:"
echo -e "     ${CYAN}systemctl status $SERVICE_NAME${NC}"
echo ""
echo -e "  4️⃣  Логи бота:"
echo -e "     ${CYAN}journalctl -u $SERVICE_NAME -f${NC}"
echo ""
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
ok "Установка завершена! PROXY TELEGRAM by @memes4u1337 🚀"
