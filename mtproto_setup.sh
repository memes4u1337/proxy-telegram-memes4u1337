#!/bin/bash
# ═══════════════════════════════════════════════════════════
#           PROXY TELEGRAM by @memes4u1337
#           MTProto Proxy Setup Script
# ═══════════════════════════════════════════════════════════
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

CONTAINER_NAME="mtproto-memes4u1337"
FAKE_DOMAIN="${1:-www.google.com}"
CONFIG_FILE="/opt/mtproto_memes4u1337.conf"
LOG_FILE="/var/log/mtproto_memes4u1337.log"
DATA_DIR="/opt/mtproto-data"

log()  { echo -e "${BOLD}${BLUE}▶${NC} $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${GREEN}✔${NC} $*"       | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"      | tee -a "$LOG_FILE"; }
die()  { echo -e "${RED}✖ $*${NC}" | tee -a "$LOG_FILE"; exit 1; }

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

# ── Проверка root ──
[ "$EUID" -ne 0 ] && die "Запусти от root: sudo bash $0"

# ── Проверка зависимостей ──
for cmd in docker openssl curl xxd ss; do
    command -v "$cmd" &>/dev/null || die "Не найден: $cmd. Установи: apt install -y $cmd"
done
docker info &>/dev/null 2>&1 || die "Docker не запущен. Запусти: systemctl start docker"

mkdir -p "$DATA_DIR" "$(dirname "$LOG_FILE")"

# ── Генерация секрета (правильный Fake TLS формат) ──
log "Fake TLS домен: ${YELLOW}${FAKE_DOMAIN}${NC}"

RANDOM_BYTES=$(openssl rand -hex 16)
DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps | tr -d '\n')
SECRET="ee${RANDOM_BYTES}${DOMAIN_HEX}"

ok "Секрет: ${YELLOW}${SECRET}${NC}"

# ── Выбор порта ──
log "Ищем свободный порт..."
PORT=""
for p in 443 8443 2053 2083 2087 2096 7443; do
    if ! ss -tuln 2>/dev/null | grep -qE ":${p}[^0-9]"; then
        PORT="$p"
        break
    fi
done
[ -z "$PORT" ] && PORT=$((RANDOM % 10000 + 20000))
ok "Порт: ${YELLOW}${PORT}${NC}"

# ── Удаляем старый контейнер ──
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    log "Удаляем старый контейнер..."
    docker stop "$CONTAINER_NAME" &>/dev/null || true
    docker rm   "$CONTAINER_NAME" &>/dev/null || true
    ok "Старый контейнер удалён"
fi

# ── Обновляем образ ──
log "Обновляем образ Telegram MTProto..."
docker pull telegrammessenger/proxy:latest 2>&1 \
    | grep -E "Pull complete|Status|up to date|Digest" || true

# ── Запуск ──
log "Запускаем PROXY TELEGRAM by @memes4u1337..."

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "${PORT}:443/tcp" \
    -p "${PORT}:443/udp" \
    -v "${DATA_DIR}:/data" \
    -e "SECRET=${SECRET}" \
    telegrammessenger/proxy \
    > /dev/null

# ── Ждём запуска ──
log "Проверяем запуск контейнера..."
STARTED=0
for i in {1..15}; do
    sleep 2
    if docker ps --filter "name=^${CONTAINER_NAME}$" --filter "status=running" \
       --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
        STARTED=1
        break
    fi
    echo -n "."
done
echo ""

if [ "$STARTED" -eq 0 ]; then
    echo -e "\n${RED}Логи контейнера:${NC}"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    die "Контейнер не запустился. Смотри логи выше."
fi
ok "Контейнер запущен!"

# ── Внешний IP ──
log "Определяем внешний IP..."
SERVER_IP=""
for url in https://ifconfig.me https://api.ipify.org https://icanhazip.com https://ident.me; do
    SERVER_IP=$(curl -s --max-time 8 "$url" 2>/dev/null | tr -d '[:space:]')
    [ -n "$SERVER_IP" ] && break
done
[ -z "$SERVER_IP" ] && SERVER_IP="YOUR_SERVER_IP"
ok "IP: ${SERVER_IP}"

PROXY_LINK="tg://proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}"

# ── Сохраняем конфиг ──
cat > "$CONFIG_FILE" << EOF
# PROXY TELEGRAM by @memes4u1337
# Создан: $(date)
SERVER=${SERVER_IP}
PORT=${PORT}
SECRET=${SECRET}
DOMAIN=${FAKE_DOMAIN}
CONTAINER=${CONTAINER_NAME}
LINK=${PROXY_LINK}
EOF
ok "Конфиг сохранён: $CONFIG_FILE"

# ── Итог ──
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║    PROXY TELEGRAM by @memes4u1337 — ГОТОВО! 🚀      ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
printf "  ${BOLD}%-22s${NC} %s\n" "🌐 Сервер:"         "$SERVER_IP"
printf "  ${BOLD}%-22s${NC} %s\n" "🔌 Порт:"           "$PORT"
printf "  ${BOLD}%-22s${NC} %s\n" "🎭 Fake TLS домен:" "$FAKE_DOMAIN"
printf "  ${BOLD}%-22s${NC} %s\n" "🔑 Секрет:"         "$SECRET"
echo ""
echo -e "  ${BOLD}🔗 Ссылка для Telegram:${NC}"
echo -e "  ${GREEN}${BOLD}${PROXY_LINK}${NC}"
echo ""
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Управление:${NC}"
echo -e "  Логи:     ${CYAN}docker logs -f ${CONTAINER_NAME}${NC}"
echo -e "  Рестарт:  ${CYAN}docker restart ${CONTAINER_NAME}${NC}"
echo -e "  Конфиг:   ${CYAN}cat ${CONFIG_FILE}${NC}"
echo ""
echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}📋 Последние логи контейнера:${NC}"
docker logs --tail 8 "$CONTAINER_NAME" 2>&1
echo ""
ok "Готово! PROXY TELEGRAM by @memes4u1337 работает 🚀"
