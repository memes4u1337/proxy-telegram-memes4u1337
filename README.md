<div align="center">

# 🚀 PROXY TELEGRAM by @memes4u1337

**Собственный MTProto прокси для Telegram + бот управления**

</div>

---

## ✨ Что это

Полный комплект для запуска личного MTProto прокси:

- 🔒 **Fake TLS** — трафик выглядит как обычный HTTPS
- 🤖 **Telegram бот** — управление прямо с телефона
- 🔔 **Watchdog** — алерт если прокси упал
- ♻️ **Автозапуск** — поднимается сам после перезагрузки сервера

---

## 📦 Файлы

| Файл | Описание |
|------|----------|
| `bot.py` | Telegram бот (управление + мониторинг) |
| `mtproto_setup.sh` | Установка прокси |
| `install_bot.sh` | Установка бота как системного сервиса |
| `requirements.txt` | Python зависимости |
| `.env.example` | Шаблон конфига |

---

## ⚡ Быстрый старт

### 1. Требования
- VPS с Ubuntu 22.04 (вне страны блокировки)
- 512 MB RAM минимум

### 2. Установка системы
```bash
apt update && apt upgrade -y
apt install -y curl wget git ufw python3 python3-pip unzip
curl -fsSL https://get.docker.com | bash
systemctl enable docker && systemctl start docker
apt install -y ufw
apt install -y git
curl -fsSL https://get.docker.com | bash
systemctl enable docker && systemctl start docker
apt install -y xxd
```

### 3. Файрвол
```bash
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
bash mtproto_setup.sh www.google.com
```

### 6. Настроить бота
```bash
cp .env.example .env
nano .env  # вставь BOT_TOKEN и ADMIN_ID
```

### 7. Запустить бота
```bash
bash install_bot.sh
systemctl start mtproto-bot
```

---

## 🎮 Команды бота

| Команда | Описание |
|---------|----------|
| `/start` | Главное меню |
| `/status` | Статус прокси + аптайм |
| `/link` | Ссылка для подключения |
| `/logs` | Логи контейнера |
| `/restart` | Перезапуск прокси |
| `/regen` | Новый секрет |

---

## 🎭 Лучшие Fake TLS домены

| Домен | Надёжность |
|-------|-----------|
| `www.google.com` | ⭐⭐⭐⭐⭐ |
| `cloudflare.com` | ⭐⭐⭐⭐⭐ |
| `www.microsoft.com` | ⭐⭐⭐⭐ |
| `apple.com` | ⭐⭐⭐⭐ |

---

## 📋 Полный гайд

Смотри файл [`GUIDE_memes4u1337.txt`](./GUIDE_memes4u1337.txt)

---

<div align="center">

**PROXY TELEGRAM by @memes4u1337** 🚀

</div>
