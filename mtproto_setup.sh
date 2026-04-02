#!/bin/bash
# ═══════════════════════════════════════════════════════════
#           PROXY TELEGRAM by @memes4u1337
# ═══════════════════════════════════════════════════════════

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ══════════════════════════════════════════════
# НАСТРОЙКИ — меняй домен здесь или передай аргументом:
# bash mtproto_setup.sh ya.ru
# bash mtproto_setup.sh mail.ru
# bash mtproto_setup.sh vk.com
FAKE_DOMAIN="${1:-ya.ru}"
# ══════════════════════════════════════════════

CONTAINER_NAME="mtproto-memes4u1337"
PORT="443"
RESULT_FILE="/opt/mtproto_memes4u1337.conf"

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
echo -e "  Домен Fake TLS: ${BLUE}${BOLD}${FAKE_DOMAIN}${NC}"
echo ""

# ── Авто-установка зависимостей ──────────────────────────────
echo -e "  Проверка зависимостей..."

# xxd
if ! command -v xxd &>/dev/null; then
    echo -ne "  Устанавливаем xxd... "
    apt-get install -y xxd -qq &>/dev/null && echo -e "${GREEN}ok${NC}" || echo -e "${RED}ошибка${NC}"
fi

# Docker
if ! command -v docker &>/dev/null; then
    echo -e "  Устанавливаем Docker (подождите ~2 мин)..."
    curl -fsSL https://get.docker.com | bash &>/dev/null
    systemctl enable docker &>/dev/null
    systemctl start docker &>/dev/null
    echo -e "  ${GREEN}Docker установлен${NC}"
fi

# Docker запущен?
if ! docker info &>/dev/null 2>&1; then
    echo -ne "  Запускаем Docker... "
    systemctl start docker &>/dev/null
    sleep 3
    echo -e "${GREEN}ok${NC}"
fi

echo -e "  ${GREEN}Зависимости готовы${NC}"
echo ""

# ── Генерация секрета ──
echo -e "  Генерация секрета..."

DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps | tr -d '\n')
DOMAIN_LEN=${#DOMAIN_HEX}
NEEDED=$((30 - DOMAIN_LEN))
RANDOM_HEX=$(openssl rand -hex 15 | cut -c1-$NEEDED)
SECRET="ee${DOMAIN_HEX}${RANDOM_HEX}"

echo -e "     Hex домена:  ${DOMAIN_HEX}"
echo -e "     Дополнение:  ${RANDOM_HEX}"
echo -e "     Секрет:      ${YELLOW}${BOLD}${SECRET}${NC}"
echo -e "     Длина:       ${#SECRET} символов"
echo ""

# ── Проверка порта ──
echo -ne "  Проверка порта ${PORT}... "
if ss -tuln | grep -q ":${PORT} "; then
    echo -e "${YELLOW}занят${NC}"
    for alt_port in 8443 8444 8445 2053 2083; do
        if ! ss -tuln | grep -q ":${alt_port} "; then
            PORT=$alt_port
            echo -e "     Используем альтернативный порт: ${YELLOW}${PORT}${NC}"
            break
        fi
    done
else
    echo -e "${GREEN}свободен${NC}"
fi
echo ""

# ── Стоп старого контейнера ──
echo -ne "  Остановка старого контейнера... "
docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker rm   "$CONTAINER_NAME" >/dev/null 2>&1 || true
echo -e "${GREEN}готово${NC}"
echo ""

# ── Запуск ──
echo -ne "  Запуск контейнера... "
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "${PORT}:443" \
    -e "SECRET=${SECRET}" \
    telegrammessenger/proxy > /dev/null 2>&1

# ── Проверка ──
sleep 4
if docker ps | grep -q "$CONTAINER_NAME"; then
    SERVER_IP=$(curl -4 -s --max-time 8 https://api4.ipify.org 2>/dev/null || \
                curl -4 -s --max-time 8 https://ipv4.icanhazip.com 2>/dev/null || \
                curl -s --max-time 8 https://ifconfig.me 2>/dev/null || echo "YOUR_IP")

    echo -e "${GREEN}запущен${NC}"
    echo ""

    LINK="tg://proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}"

    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║    PROXY TELEGRAM by @memes4u1337 — ГОТОВО!         ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    printf "  ${BOLD}%-22s${NC} %s\n" "Сервер:"         "$SERVER_IP"
    printf "  ${BOLD}%-22s${NC} %s\n" "Порт:"           "$PORT"
    printf "  ${BOLD}%-22s${NC} %s\n" "Fake TLS домен:" "$FAKE_DOMAIN"
    printf "  ${BOLD}%-22s${NC} %s\n" "Секрет:"         "$SECRET"
    echo ""
    echo -e "  ${BOLD}Ссылка для Telegram:${NC}"
    echo -e "  ${GREEN}${BOLD}${LINK}${NC}"
    echo ""
    echo -e "${CYAN}  ══════════════════════════════════════════════${NC}"
    echo ""

    cat > "$RESULT_FILE" << EOF
# PROXY TELEGRAM by @memes4u1337 — $(date)
SERVER=${SERVER_IP}
PORT=${PORT}
SECRET=${SECRET}
DOMAIN=${FAKE_DOMAIN}
LINK=${LINK}
EOF
    echo -e "  Конфиг сохранён: ${CYAN}${RESULT_FILE}${NC}"
    echo ""
    echo -e "  ${BOLD}Управление:${NC}"
    echo -e "  Логи:      ${CYAN}docker logs -f ${CONTAINER_NAME}${NC}"
    echo -e "  Рестарт:   ${CYAN}bash mtproto_setup.sh${NC}"
    echo -e "  Др.домен:  ${CYAN}bash mtproto_setup.sh mail.ru${NC}"
    echo ""
    echo -e "${BOLD}  Последние логи контейнера:${NC}"
    docker logs --tail 6 "$CONTAINER_NAME" 2>&1 | sed 's/^/  /'

else
    echo -e "${RED}ОШИБКА${NC}"
    echo ""
    echo -e "${RED}Логи контейнера:${NC}"
    docker logs "$CONTAINER_NAME" 2>&1
fi
