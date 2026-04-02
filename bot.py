#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════╗
║     Бот для PROXY TELEGRAM by @memes4u1337           ║
╚══════════════════════════════════════════════════════╝
"""

import asyncio
import logging
import os
import subprocess
import json
from datetime import datetime

from aiogram import Bot, Dispatcher, types, F
from aiogram.client.default import DefaultBotProperties
from aiogram.filters import Command, CommandStart
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.utils.markdown import hbold, hcode

BOT_TOKEN      = os.getenv("BOT_TOKEN", "")
ADMIN_ID       = int(os.getenv("ADMIN_ID", "0"))
CONTAINER_NAME = os.getenv("CONTAINER_NAME", "mtproto-memes4u1337")
CONFIG_FILE    = os.getenv("CONFIG_FILE", "/opt/mtproto_memes4u1337.conf")
SETUP_SCRIPT   = os.getenv("SETUP_SCRIPT", "/opt/mtproto_setup.sh")
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "300"))
USERS_FILE     = os.getenv("USERS_FILE", "/opt/panel_users.json")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/var/log/mtproto_bot.log"),
    ],
)
log = logging.getLogger(__name__)

bot = Bot(token=BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))
dp  = Dispatcher()

# ── Сохранение пользователей ───────────────────────────────────

def save_user(user: types.User):
    try:
        try:
            with open(USERS_FILE) as f:
                users = json.load(f)
        except:
            users = []
        ids = [u["id"] for u in users]
        if user.id not in ids:
            users.append({
                "id": user.id,
                "username": f"@{user.username}" if user.username else "",
                "name": f"{user.first_name or ''} {user.last_name or ''}".strip(),
                "date": datetime.now().strftime("%Y-%m-%d %H:%M")
            })
            with open(USERS_FILE, "w") as f:
                json.dump(users, f, ensure_ascii=False)
    except Exception as e:
        log.error(f"save_user error: {e}")

# ── Хелперы ────────────────────────────────────────────────────

def is_admin(user_id: int) -> bool:
    return user_id == ADMIN_ID

def read_config() -> dict:
    cfg = {}
    try:
        with open(CONFIG_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    cfg[k.strip()] = v.strip()
    except FileNotFoundError:
        pass
    return cfg

def docker_running() -> bool:
    try:
        result = subprocess.run(
            ["docker", "ps", "--filter", f"name=^{CONTAINER_NAME}$",
             "--filter", "status=running", "--format", "{{.Names}}"],
            capture_output=True, text=True, timeout=10
        )
        return CONTAINER_NAME in result.stdout
    except:
        return False

def docker_logs(lines: int = 20) -> str:
    try:
        result = subprocess.run(
            ["docker", "logs", "--tail", str(lines), CONTAINER_NAME],
            capture_output=True, text=True, timeout=15
        )
        return (result.stdout + result.stderr).strip() or "Логи пусты"
    except Exception as e:
        return f"Ошибка: {e}"

def docker_action(action: str) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            ["docker", action, CONTAINER_NAME],
            capture_output=True, text=True, timeout=30
        )
        return result.returncode == 0, result.stdout.strip() or result.stderr.strip()
    except Exception as e:
        return False, str(e)

def uptime() -> str:
    try:
        result = subprocess.run(
            ["docker", "inspect", "--format", "{{.State.StartedAt}}", CONTAINER_NAME],
            capture_output=True, text=True, timeout=10
        )
        started = result.stdout.strip()
        if started:
            dt = datetime.fromisoformat(started[:19])
            delta = datetime.utcnow() - dt
            h, rem = divmod(int(delta.total_seconds()), 3600)
            return f"{h}ч {rem//60}мин"
    except:
        pass
    return "неизвестно"

# ── Клавиатуры ─────────────────────────────────────────────────

def main_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(text="📊 Статус",       callback_data="status"),
            InlineKeyboardButton(text="🔄 Рестарт",      callback_data="restart"),
        ],
        [
            InlineKeyboardButton(text="📋 Логи",         callback_data="logs"),
            InlineKeyboardButton(text="🔁 Новый секрет", callback_data="regen"),
        ],
        [
            InlineKeyboardButton(text="🔗 Подключиться к прокси", callback_data="link"),
        ],
        [
            InlineKeyboardButton(text="⭐ GitHub", url="https://github.com/memes4u1337/proxy-telegram-memes4u1337"),
        ],
    ])

def link_kb(proxy_link: str) -> InlineKeyboardMarkup:
    """Клавиатура со ссылкой для прямого подключения к прокси."""
    buttons = []
    if proxy_link:
        buttons.append([
            InlineKeyboardButton(text="⚡ Подключиться одним нажатием", url=proxy_link)
        ])
    buttons.append([
        InlineKeyboardButton(text="◀️ Назад", callback_data="menu")
    ])
    return InlineKeyboardMarkup(inline_keyboard=buttons)

def user_kb(proxy_link: str) -> InlineKeyboardMarkup:
    """Клавиатура для обычных пользователей."""
    buttons = []
    if proxy_link:
        buttons.append([
            InlineKeyboardButton(text="⚡ Подключиться одним нажатием", url=proxy_link)
        ])
    buttons.append([
        InlineKeyboardButton(text="⭐ GitHub", url="https://github.com/memes4u1337/proxy-telegram-memes4u1337")
    ])
    return InlineKeyboardMarkup(inline_keyboard=buttons)

def confirm_kb(action: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(text="✅ Да",  callback_data=f"confirm_{action}"),
            InlineKeyboardButton(text="❌ Нет", callback_data="cancel"),
        ]
    ])

def back_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="◀️ Назад", callback_data="menu")]
    ])

# ── Хендлеры ───────────────────────────────────────────────────

@dp.message(CommandStart())
async def cmd_start(msg: types.Message):
    save_user(msg.from_user)
    cfg  = read_config()
    link = cfg.get("LINK", "")

    if is_admin(msg.from_user.id):
        text = (
            f"👾 {hbold('Бот для PROXY TELEGRAM by @memes4u1337')}\n\n"
            f"{'🟢 Прокси работает' if docker_running() else '🔴 Прокси не запущен'}\n\n"
            f"Выбери действие:"
        )
        await msg.answer(text, reply_markup=main_kb())
    else:
        if link:
            text = (
                f"👋 Привет! Это бот {hbold('PROXY TELEGRAM by @memes4u1337')}\n\n"
                f"Нажми кнопку ниже чтобы подключиться к прокси одним нажатием 👇"
            )
        else:
            text = "⚙️ Прокси ещё не настроен. Попробуй позже."
        await msg.answer(text, reply_markup=user_kb(link))


@dp.message(Command("status"))
async def cmd_status(msg: types.Message):
    if not is_admin(msg.from_user.id): return
    await send_status(msg)

@dp.message(Command("link"))
async def cmd_link(msg: types.Message):
    if not is_admin(msg.from_user.id): return
    await send_link(msg)

@dp.message(Command("logs"))
async def cmd_logs(msg: types.Message):
    if not is_admin(msg.from_user.id): return
    await send_logs(msg)

@dp.message(Command("restart"))
async def cmd_restart(msg: types.Message):
    if not is_admin(msg.from_user.id): return
    await msg.answer("🔄 Рестартнуть прокси?", reply_markup=confirm_kb("restart"))

@dp.message(Command("regen"))
async def cmd_regen(msg: types.Message):
    if not is_admin(msg.from_user.id): return
    await msg.answer("⚠️ Пересоздать секрет? Все подключения сбросятся.", reply_markup=confirm_kb("regen"))

# ── Callbacks ───────────────────────────────────────────────────

@dp.callback_query(F.data == "menu")
async def cb_menu(cb: types.CallbackQuery):
    if not is_admin(cb.from_user.id):
        await cb.answer("⛔ Нет доступа", show_alert=True); return
    text = (
        f"👾 {hbold('Бот для PROXY TELEGRAM by @memes4u1337')}\n\n"
        f"{'🟢 Прокси работает' if docker_running() else '🔴 Прокси не запущен'}\n\n"
        f"Выбери действие:"
    )
    await cb.message.edit_text(text, reply_markup=main_kb())
    await cb.answer()

@dp.callback_query(F.data == "status")
async def cb_status(cb: types.CallbackQuery):
    if not is_admin(cb.from_user.id):
        await cb.answer("⛔ Нет доступа", show_alert=True); return
    await cb.answer("⏳ Проверяю...")
    await send_status(cb.message, edit=True)

@dp.callback_query(F.data == "link")
async def cb_link(cb: types.CallbackQuery):
    if not is_admin(cb.from_user.id):
        await cb.answer("⛔ Нет доступа", show_alert=True); return
    await send_link(cb.message, edit=True)
    await cb.answer()

@dp.callback_query(F.data == "logs")
async def cb_logs(cb: types.CallbackQuery):
    if not is_admin(cb.from_user.id):
        await cb.answer("⛔ Нет доступа", show_alert=True); return
    await cb.answer("⏳ Читаю логи...")
    await send_logs(cb.message, edit=True)

@dp.callback_query(F.data == "restart")
async def cb_restart(cb: types.CallbackQuery):
    if not is_admin(cb.from_user.id):
        await cb.answer(); return
    await cb.message.edit_text("🔄 Рестартнуть прокси?", reply_markup=confirm_kb("restart"))
    await cb.answer()

@dp.callback_query(F.data == "regen")
async def cb_regen(cb: types.CallbackQuery):
    if not is_admin(cb.from_user.id):
        await cb.answer(); return
    await cb.message.edit_text("⚠️ Пересоздать секрет? Все подключения сбросятся.", reply_markup=confirm_kb("regen"))
    await cb.answer()

@dp.callback_query(F.data == "confirm_restart")
async def cb_confirm_restart(cb: types.CallbackQuery):
    if not is_admin(cb.from_user.id):
        await cb.answer(); return
    await cb.message.edit_text("🔄 Рестартую...")
    ok, out = docker_action("restart")
    if ok:
        await cb.message.edit_text("✅ Контейнер перезапущен!", reply_markup=back_kb())
    else:
        await cb.message.edit_text(f"❌ Ошибка:\n{hcode(out)}", reply_markup=back_kb())
    await cb.answer()

@dp.callback_query(F.data == "confirm_regen")
async def cb_confirm_regen(cb: types.CallbackQuery):
    if not is_admin(cb.from_user.id):
        await cb.answer(); return
    await cb.message.edit_text("⏳ Пересоздаю прокси...")
    try:
        result = subprocess.run(["bash", SETUP_SCRIPT], capture_output=True, text=True, timeout=120)
        cfg  = read_config()
        link = cfg.get("LINK", "")
        if result.returncode == 0:
            await cb.message.edit_text(
                f"✅ {hbold('Прокси пересоздан!')}\n\nНажми кнопку для подключения:",
                reply_markup=link_kb(link)
            )
        else:
            await cb.message.edit_text(f"❌ Ошибка:\n{hcode(result.stderr[-500:])}", reply_markup=back_kb())
    except subprocess.TimeoutExpired:
        await cb.message.edit_text("⚠️ Таймаут — скрипт работает слишком долго.", reply_markup=back_kb())
    await cb.answer()

@dp.callback_query(F.data == "cancel")
async def cb_cancel(cb: types.CallbackQuery):
    await cb.message.edit_text("❌ Отменено.", reply_markup=back_kb())
    await cb.answer()

# ── Отправка данных ─────────────────────────────────────────────

async def send_status(target, edit=False):
    cfg     = read_config()
    running = docker_running()
    text = (
        f"{'🟢' if running else '🔴'} {hbold('Статус PROXY TELEGRAM by @memes4u1337')}\n\n"
        f"📡 Состояние:  {hbold('Online' if running else 'Offline')}\n"
        f"⏱ Аптайм:     {uptime() if running else '—'}\n"
        f"🌐 Сервер:     {hcode(cfg.get('SERVER', '?'))}\n"
        f"🔌 Порт:       {cfg.get('PORT', '?')}\n"
        f"🎭 Fake TLS:   {cfg.get('DOMAIN', '?')}\n"
        f"🕐 Проверено:  {datetime.now().strftime('%H:%M:%S')}"
    )
    if edit:
        await target.edit_text(text, reply_markup=main_kb())
    else:
        await target.answer(text, reply_markup=main_kb())

async def send_link(target, edit=False):
    cfg  = read_config()
    link = cfg.get("LINK", "")
    text = (
        f"🔗 {hbold('Подключение к прокси')}\n\n"
        f"PROXY TELEGRAM by @memes4u1337\n\n"
        f"Нажми кнопку ниже — Telegram автоматически добавит прокси 👇\n\n"
        f"Или вручную:\n"
        f"🌐 Сервер: {hcode(cfg.get('SERVER','?'))}\n"
        f"🔌 Порт:   {cfg.get('PORT','?')}\n"
        f"🔑 Секрет: {hcode(cfg.get('SECRET','?'))}"
    ) if link else "❌ Конфиг не найден. Запусти mtproto_setup.sh"

    if edit:
        await target.edit_text(text, reply_markup=link_kb(link))
    else:
        await target.answer(text, reply_markup=link_kb(link))

async def send_logs(target, edit=False):
    lines = docker_logs(20)
    if len(lines) > 3000:
        lines = "...(обрезано)...\n" + lines[-3000:]
    text = f"📋 {hbold('Логи контейнера')}\n\n{hcode(lines)}"
    if edit:
        await target.edit_text(text, reply_markup=back_kb())
    else:
        await target.answer(text, reply_markup=back_kb())

# ── Watchdog ────────────────────────────────────────────────────

async def watchdog():
    was_running = True
    await asyncio.sleep(30)
    while True:
        try:
            now_running = docker_running()
            if was_running and not now_running:
                log.warning("Прокси упал!")
                await bot.send_message(
                    ADMIN_ID,
                    f"🚨 {hbold('АЛЕРТ — PROXY TELEGRAM by @memes4u1337')}\n\n"
                    f"❌ Контейнер упал!\n"
                    f"🕐 {datetime.now().strftime('%H:%M:%S')}",
                    reply_markup=main_kb()
                )
            elif not was_running and now_running:
                cfg  = read_config()
                link = cfg.get("LINK", "")
                await bot.send_message(
                    ADMIN_ID,
                    f"✅ {hbold('PROXY TELEGRAM by @memes4u1337 снова работает!')}\n"
                    f"🕐 {datetime.now().strftime('%H:%M:%S')}",
                    reply_markup=link_kb(link)
                )
            was_running = now_running
        except Exception as e:
            log.error(f"Watchdog error: {e}")
        await asyncio.sleep(CHECK_INTERVAL)

# ── Запуск ──────────────────────────────────────────────────────

async def main():
    if not BOT_TOKEN or ADMIN_ID == 0:
        print("❌ Укажи BOT_TOKEN и ADMIN_ID в .env файле!")
        return

    log.info("Бот для PROXY TELEGRAM by @memes4u1337 запускается...")
    cfg  = read_config()
    link = cfg.get("LINK", "")

    try:
        await bot.send_message(
            ADMIN_ID,
            f"🤖 {hbold('Бот для PROXY TELEGRAM by @memes4u1337 запущен!')}\n\n"
            f"{'🟢 Прокси работает' if docker_running() else '🔴 Прокси не запущен'}\n\n"
            f"⏱ Watchdog каждые {CHECK_INTERVAL // 60} мин.",
            reply_markup=main_kb()
        )
    except Exception as e:
        log.error(f"Стартовое сообщение не отправлено: {e}")

    asyncio.create_task(watchdog())
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
