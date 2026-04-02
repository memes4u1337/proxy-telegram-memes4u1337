<div align="center">
🚀 PROXY TELEGRAM by @memes4u1337
Собственный MTProto прокси для Telegram + бот управления
Show Image
Show Image
</div>

✨ Что это
Полный комплект для запуска личного MTProto прокси:

🔒 Fake TLS — трафик выглядит как обычный HTTPS
🤖 Telegram бот — управление прямо с телефона
🔔 Watchdog — алерт если прокси упал
♻️ Автозапуск — поднимается сам после перезагрузки сервера


📦 Файлы
ФайлОписаниеbot.pyTelegram бот (управление + мониторинг)mtproto_setup.shУстановка проксиinstall_bot.shУстановка бота как системного сервисаrequirements.txtPython зависимостиenv.exampleШаблон конфига (переименуй в .env)

⚡ Быстрый старт
1. Требования

VPS с Ubuntu 22.04 вне страны блокировки (Hetzner, DigitalOcean, Vultr)
512 MB RAM минимум

2. Установка системы
bashapt update && apt upgrade -y
apt install -y curl wget git ufw python3 python3-pip unzip xxd
curl -fsSL https://get.docker.com | bash
systemctl enable docker && systemctl start docker
3. Файрвол
bashufw allow ssh && ufw allow 443/tcp && ufw --force enable
4. Клонировать репозиторий
bashgit clone https://github.com/memes4u1337/proxy-telegram-memes4u1337.git
cd proxy-telegram-memes4u1337
chmod +x mtproto_setup.sh install_bot.sh
5. Запустить прокси
bashbash mtproto_setup.sh
Или с конкретным доменом:
bashbash mtproto_setup.sh ya.ru
6. Установить зависимости Python
bashpip3 install -r requirements.txt --break-system-packages
7. Настроить бота
Получи токен у @BotFather, свой ID у @userinfobot, затем:
bashnano .env
Вставь и заполни:
envBOT_TOKEN=токен_от_BotFather
ADMIN_ID=твой_id_из_userinfobot
CONTAINER_NAME=mtproto-memes4u1337
CONFIG_FILE=/opt/mtproto_memes4u1337.conf
SETUP_SCRIPT=/opt/mtproto_setup.sh
CHECK_INTERVAL=300
Сохрани: Ctrl+X → Y → Enter
8. Запустить бота
bashbash install_bot.sh
systemctl start mtproto-bot
systemctl status mtproto-bot
Бот пришлёт сообщение в Telegram что запустился ✅

🎮 Команды бота
КомандаОписание/startГлавное меню с кнопками/statusСтатус прокси + аптайм/linkСсылка для подключения/logsЛоги контейнера/restartПерезапуск прокси/regenНовый секрет (сбрасывает все подключения)

🎭 Лучшие Fake TLS домены
ДоменНадёжностьya.ru⭐⭐⭐⭐⭐vk.com⭐⭐⭐⭐⭐mail.ru⭐⭐⭐⭐google.com⭐⭐⭐⭐

🛠 Полезные команды
bash# Посмотреть ссылку прокси
cat /opt/mtproto_memes4u1337.conf

# Логи прокси
docker logs -f mtproto-memes4u1337

# Логи бота
journalctl -u mtproto-bot -f

# Перезапустить прокси с новым секретом
bash /opt/mtproto_setup.sh

# Перезапустить бота
systemctl restart mtproto-bot

⚠️ Важно

Сервер обязательно должен быть вне страны где заблокирован Telegram
Файл .env не загружай на GitHub — там твой токен бота!


📋 Полный гайд
Смотри файл GUIDE.txt

<div align="center">
PROXY TELEGRAM by @memes4u1337 🚀
</div>
