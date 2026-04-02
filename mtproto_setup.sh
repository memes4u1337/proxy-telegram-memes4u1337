#!/bin/bash
# ═══════════════════════════════════════════════════════════
#           PROXY TELEGRAM by @memes4u1337
# ═══════════════════════════════════════════════════════════

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

CONTAINER="mtproto-memes4u1337"
IMAGE="nineseconds/mtg:stable"
PORT=443
CONFIG_DIR="/opt/mtproto-data"
CONFIG_FILE="${CONFIG_DIR}/config.toml"
RESULT_FILE="/opt/mtproto_memes4u1337.conf"

# ══════════════════════════════════════════════
# ДОМЕН ДЛЯ FAKE TLS — меняй здесь:
# ya.ru, mail.ru, vk.com, google.com
FAKE_DOMAIN="${1:-ya.ru}"
# ══════════════════════════════════════════════

ok()  { echo -e "${GREEN}✔${NC} $*"; }
log() { echo -e "${BOLD}${CYAN}▶${NC} $*"; }
die() { echo -e "${RED}✖ $*${NC}"; exit 1; }

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
echo -e "  ${BOLD}PROXY TELEGRAM by @memes4u1337${NC}"
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
echo ""

command -v docker &>/dev/null || die "Docker не найден. Установи: curl -fsSL https://get.docker.com | bash"
docker info &>/dev/null 2>&1 || die "Docker не запущен: systemctl start docker"

# ── Стоп старого контейнера ──
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    log "Останавливаем старый контейнер..."
    docker stop "$CONTAINER" &>/dev/null || true
    docker rm   "$CONTAINER" &>/dev/null || true
    ok "Старый контейнер удалён"
fi

mkdir -p "$CONFIG_DIR"

# ── Генерируем секрет (правильный флаг --host) ──
log "Генерируем Fake TLS секрет для: ${YELLOW}${FAKE_DOMAIN}${NC}"
SECRET=$(docker run --rm "$IMAGE" generate-secret tls --host "$FAKE_DOMAIN" 2>/dev/null | tr -d '[:space:]')
[ -z "$SECRET" ] && die "Не удалось сгенерировать секрет. Проверь интернет."
ok "Секрет: ${YELLOW}${SECRET}${NC}"

# ── config.toml ──
log "Создаём конфиг..."
cat > "$CONFIG_FILE" << EOF
secret  = "${SECRET}"
bind-to = "0.0.0.0:3128"
EOF
ok "Конфиг: $CONFIG_FILE"

# ── Запуск ──
log "Запускаем прокси..."
docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    -p "${PORT}:3128" \
    -v "${CONFIG_FILE}:/config.toml" \
    "$IMAGE" \
    > /dev/null

# ── Ждём ──
log "Проверяем запуск..."
STARTED=0
for i in {1..10}; do
    sleep 2
    if docker ps --filter "name=^${CONTAINER}$" --filter "status=running" \
       --format '{{.Names}}' | grep -q "$CONTAINER"; then
        STARTED=1; break
    fi
    echo -n "."
done
echo ""

if [ "$STARTED" -eq 0 ]; then
    docker logs "$CONTAINER" 2>&1 | tail -20
    die "Контейнер не запустился!"
fi
ok "Контейнер запущен!"

# ── IP и ссылка ──
SERVER_IP=$(curl -s --max-time 8 https://ifconfig.me 2>/dev/null || \
            curl -s --max-time 8 https://api.ipify.org 2>/dev/null || echo "YOUR_IP")
LINK="tg://proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}"

cat > "$RESULT_FILE" << EOF
# PROXY TELEGRAM by @memes4u1337 — $(date)
SERVER=${SERVER_IP}
PORT=${PORT}
SECRET=${SECRET}
DOMAIN=${FAKE_DOMAIN}
LINK=${LINK}
EOF

# ── Итог ──
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║    PROXY TELEGRAM by @memes4u1337 — ГОТОВО! 🚀      ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
printf "  ${BOLD}%-20s${NC} %s\n" "🌐 Сервер:"   "$SERVER_IP"
printf "  ${BOLD}%-20s${NC} %s\n" "🔌 Порт:"     "$PORT"
printf "  ${BOLD}%-20s${NC} %s\n" "🎭 Fake TLS:" "$FAKE_DOMAIN"
printf "  ${BOLD}%-20s${NC} %s\n" "🔑 Секрет:"   "$SECRET"
echo ""
echo -e "  ${BOLD}🔗 Ссылка для Telegram:${NC}"
echo -e "  ${GREEN}${BOLD}${LINK}${NC}"
echo ""
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
echo -e "  Конфиг:   ${CYAN}cat ${RESULT_FILE}${NC}"
echo -e "  Логи:     ${CYAN}docker logs -f ${CONTAINER}${NC}"
echo -e "  Рестарт:  ${CYAN}bash mtproto_setup.sh${NC}"
echo -e "  Др.домен: ${CYAN}bash mtproto_setup.sh mail.ru${NC}"
echo ""
echo -e "${BOLD}📋 Логи контейнера:${NC}"
docker logs --tail 8 "$CONTAINER" 2>&1
echo ""
ok "PROXY TELEGRAM by @memes4u1337 работает 🚀"
