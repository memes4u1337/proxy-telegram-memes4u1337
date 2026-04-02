<div align="center">

# PROXY TELEGRAM by @memes4u1337

**Собственный MTProto прокси для Telegram + бот управления + веб-панель**

</div>

---

## Что это

Полный комплект для запуска личного MTProto прокси:

- **Fake TLS** — трафик выглядит как обычный HTTPS
- **Telegram бот** — управление прямо с телефона
- **Веб-панель** — полноценный дашборд в браузере
- **Watchdog** — алерт если прокси упал
- **Автозапуск** — поднимается сам после перезагрузки сервера

---

## Файлы

| Файл | Описание |
|------|----------|
| `bot.py` | Telegram бот (управление + мониторинг) |
| `mtproto_setup.sh` | Установка прокси |
| `install_bot.sh` | Установка бота как системного сервиса |
| `requirements.txt` | Python зависимости бота |
| `env.example` | Шаблон конфига (переименуй в `.env`) |
| `panel/app.py` | Веб-панель (Flask) |
| `panel/install_panel.sh` | Установка панели |

---

## Быстрый старт

### 1. Требования

- VPS с Ubuntu 22.04 **вне страны блокировки** (Hetzner, DigitalOcean, Vultr)
- 512 MB RAM минимум

### 2. Установка системы

```bash
apt update && apt upgrade -y
apt install -y curl wget git ufw python3 python3-pip unzip xxd
curl -fsSL https://get.docker.com | bash
systemctl enable docker && systemctl start docker
```

### 3. Файрвол

```bash
apt install -y ufw
ufw allow ssh && ufw allow 443/tcp && ufw --force enable
```

### 4. Клонировать репозиторий

```bash
git clone https://github.com/memes4u1337/proxy-telegram-memes4u1337.git
cd proxy-telegram-memes4u1337
chmod +x mtproto_setup.sh install_bot.sh
```

### 5. Запустить прокси

```bash
bash mtproto_setup.sh
```

Или с конкретным доменом:

```bash
bash mtproto_setup.sh ya.ru
```

### 6. Установить зависимости Python

```bash
apt install -y python3-pip
pip3 install -r requirements.txt --break-system-packages
```

### 7. Настроить бота

Получи токен у **@BotFather**, свой ID у **@userinfobot**, затем:

```bash
nano .env
```

Вставь и заполни:

```env
BOT_TOKEN=токен_от_BotFather
ADMIN_ID=твой_id_из_userinfobot
CONTAINER_NAME=mtproto-memes4u1337
CONFIG_FILE=/opt/mtproto_memes4u1337.conf
SETUP_SCRIPT=/opt/mtproto_setup.sh
CHECK_INTERVAL=300
```

Сохрани: **Ctrl+X → Y → Enter**

### 8. Запустить бота

```bash
bash install_bot.sh
systemctl start mtproto-bot
systemctl status mtproto-bot
```

Бот пришлёт сообщение в Telegram что запустился.

### 9. Установить веб-панель

```bash
cd panel
chmod +x install_panel.sh
bash install_panel.sh
```

Скрипт автоматически:
- Определит IPv4 адрес сервера
- Сгенерирует логин и пароль
- Установит Flask и запустит панель

В конце выдаст:
```
Адрес панели: http://ВАШ IP:8888
Логин:  admin
Пароль: xK7mR2pQnL4wZ9vA
```

---

## Команды бота

| Команда | Описание |
|---------|----------|
| `/start` | Главное меню с кнопками |
| `/status` | Статус прокси + аптайм |
| `/link` | Ссылка для подключения |
| `/logs` | Логи контейнера |
| `/restart` | Перезапуск прокси |
| `/regen` | Новый секрет (сбрасывает все подключения) |

---

## Веб-панель

Открой в браузере: `http://ВАШ_IP:8888`

Возможности панели:
- Статус прокси и бота в реальном времени
- Количество активных подключений
- Управление: запуск, стоп, рестарт прокси и бота
- Пересоздание прокси с новым секретом и доменом
- Список пользователей бота
- Логи контейнера
- Светлая и тёмная тема
- Смена пароля

---

## Лучшие Fake TLS домены

| Домен | Надёжность |
|-------|-----------|
| `ya.ru` | Отлично |
| `vk.com` | Отлично |
| `mail.ru` | Хорошо |
| `google.com` | Хорошо |

---

## Полезные команды

```bash
# Посмотреть ссылку прокси
cat /opt/mtproto_memes4u1337.conf

# Логи прокси
docker logs -f mtproto-memes4u1337

# Логи бота
journalctl -u mtproto-bot -f

# Логи панели
journalctl -u mtproto-panel -f

# Перезапустить прокси с новым секретом
bash /opt/mtproto_setup.sh

# Перезапустить бота
systemctl restart mtproto-bot

# Перезапустить панель
systemctl restart mtproto-panel
```

---

<div align="center">

**PROXY TELEGRAM by @memes4u1337**

</div>
