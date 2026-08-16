# Promptino Bot - single-file Dockerfile
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
WORKDIR /app

RUN pip install --no-cache-dir "Flask>=3.0,<4" "requests>=2.31,<3" "gunicorn>=22,<24"

RUN cat > /app/main.py <<'PY'
import os
import requests
from flask import Flask, request

app = Flask(__name__)

TOKEN = os.getenv("BOT_TOKEN", "").strip()
ADMIN_IDS = {
    int(x.strip()) for x in os.getenv("ADMIN_IDS", "").split(",")
    if x.strip().isdigit()
}
API = f"https://api.telegram.org/bot{TOKEN}" if TOKEN else ""

PROMPTINO_CHANNEL = "https://t.me/PromptinoChannel"

# کانال‌های تبلیغاتی/عضویت اجباری اولیه
# بعداً بدون تغییر کد، مدیر می‌تواند با /addchannel و /removechannel تغییرشان دهد.
REQUIRED_CHANNELS = []

PROMPTS = {
    "p001": """📋 پرامپت نمونه پرامپتینو

Create a cinematic professional portrait from the uploaded photo.
Keep the person's identity and facial features consistent.
Use dramatic cinematic lighting, realistic skin texture, shallow depth
of field, premium editorial photography, high detail, natural colors,
and a professional camera look."""
}

WELCOME = """🤖 سلام! به پرامپتینو خوش اومدی 👋

اینجا می‌تونی به پرامپت‌های کاربردی و تست‌شده هوش مصنوعی دسترسی داشته باشی.

برای دریافت پرامپت، از پست‌های کانال پرامپتینو روی دکمه
«🚀 دریافت پرامپت» بزن."""


def api(method, data=None):
    if not API:
        return {}
    try:
        r = requests.post(f"{API}/{method}", json=data or {}, timeout=20)
        return r.json()
    except Exception as e:
        print("Telegram API error:", e)
        return {}


def send(chat_id, text, keyboard=None):
    data = {"chat_id": chat_id, "text": text}
    if keyboard:
        data["reply_markup"] = keyboard
    return api("sendMessage", data)


def is_admin(chat_id):
    return chat_id in ADMIN_IDS


def is_member(user_id, channel):
    result = api("getChatMember", {
        "chat_id": channel["username"],
        "user_id": user_id
    })
    if not result.get("ok"):
        print("Membership check failed:", result)
        return False

    status = result.get("result", {}).get("status", "")
    return (
        status in {"creator", "administrator", "member"}
        or (
            status == "restricted"
            and result.get("result", {}).get("is_member", False)
        )
    )


def require_membership(chat_id, user_id):
    missing = [
        channel for channel in REQUIRED_CHANNELS
        if not is_member(user_id, channel)
    ]

    if not missing:
        return True

    buttons = []
    for channel in missing:
        buttons.append([{
            "text": f"📢 عضویت در {channel['title']}",
            "url": channel["url"]
        }])

    buttons.append([{
        "text": "✅ بررسی عضویت",
        "callback_data": "check_membership"
    }])

    text = (
        "🔒 برای دریافت این پرامپت، ابتدا در کانال‌های زیر عضو شو:\n\n"
        + "\n".join(f"• {c['title']}" for c in missing)
        + "\n\nبعد از عضویت روی «✅ بررسی عضویت» بزن."
    )

    send(chat_id, text, {"inline_keyboard": buttons})
    return False


def add_channel(chat_id, text):
    # /addchannel @username | عنوان کانال | https://t.me/username
    parts = [p.strip() for p in text.split("|")]

    if len(parts) != 3:
        send(
            chat_id,
            "فرمت درست:\n"
            "/addchannel @ChannelUsername | عنوان کانال | https://t.me/ChannelUsername"
        )
        return

    username, title, url = parts

    if not username.startswith("@") or not url.startswith("https://t.me/"):
        send(chat_id, "❌ نام کاربری یا لینک کانال درست نیست.")
        return

    if any(c["username"].lower() == username.lower()
           for c in REQUIRED_CHANNELS):
        send(chat_id, "⚠️ این کانال قبلاً اضافه شده.")
        return

    REQUIRED_CHANNELS.append({
        "username": username,
        "title": title,
        "url": url
    })

    send(
        chat_id,
        f"✅ کانال «{title}» اضافه شد.\n"
        f"📊 تعداد کانال‌های فعلی: {len(REQUIRED_CHANNELS)}"
    )


def remove_channel(chat_id, text):
    username = text.replace("/removechannel", "", 1).strip()

    if not username.startswith("@"):
        send(chat_id, "فرمت درست:\n/removechannel @ChannelUsername")
        return

    old_count = len(REQUIRED_CHANNELS)

    REQUIRED_CHANNELS[:] = [
        c for c in REQUIRED_CHANNELS
        if c["username"].lower() != username.lower()
    ]

    if len(REQUIRED_CHANNELS) < old_count:
        send(
            chat_id,
            f"✅ کانال حذف شد.\n"
            f"📊 تعداد کانال‌های فعلی: {len(REQUIRED_CHANNELS)}"
        )
    else:
        send(chat_id, "⚠️ این کانال در لیست وجود نداشت.")


def list_channels(chat_id):
    if not REQUIRED_CHANNELS:
        send(chat_id, "📭 فعلاً هیچ کانال تبلیغاتی ثبت نشده.")
        return

    lines = ["📋 کانال‌های فعلی:\n"]

    for i, channel in enumerate(REQUIRED_CHANNELS, 1):
        lines.append(
            f"{i}. {channel['title']} — {channel['username']}"
        )

    lines.append(f"\n📊 مجموع: {len(REQUIRED_CHANNELS)}")
    send(chat_id, "\n".join(lines))


def handle_update(update):
    callback = update.get("callback_query")

    if callback:
        callback_id = callback.get("id")
        chat_id = callback.get("message", {}).get("chat", {}).get("id")
        user_id = callback.get("from", {}).get("id")

        api("answerCallbackQuery", {
            "callback_query_id": callback_id
        })

        if callback.get("data") == "check_membership":
            if require_membership(chat_id, user_id):
                send(
                    chat_id,
                    "✅ عضویتت تأیید شد!\n\n"
                    "حالا دوباره روی دکمه «🚀 دریافت پرامپت» بزن."
                )
        return

    message = update.get("message")
    if not message:
        return

    text = message.get("text", "")
    chat_id = message["chat"]["id"]
    user_id = message["from"]["id"]

    # پیدا کردن آیدی عددی مدیر
    if text == "/myid":
        send(chat_id, f"🆔 Telegram ID شما:\n{user_id}")
        return

    # مدیریت کاتالوگ تبلیغات
    if text.startswith("/addchannel"):
        if not is_admin(chat_id):
            send(chat_id, "⛔ این دستور فقط برای مدیر ربات است.")
            return
        add_channel(chat_id, text)
        return

    if text.startswith("/removechannel"):
        if not is_admin(chat_id):
            send(chat_id, "⛔ این دستور فقط برای مدیر ربات است.")
            return
        remove_channel(chat_id, text)
        return

    if text == "/channels":
        if not is_admin(chat_id):
            send(chat_id, "⛔ این دستور فقط برای مدیر ربات است.")
            return
        list_channels(chat_id)
        return

    if text.startswith("/start"):
        parts = text.split(maxsplit=1)

        # لینک دریافت پرامپت:
        # https://t.me/PromptinoPromptsBot?start=p001
        if len(parts) == 2:
            prompt_id = parts[1].strip().lower()

            if prompt_id in PROMPTS:
                if not require_membership(chat_id, user_id):
                    return

                send(
                    chat_id,
                    PROMPTS[prompt_id],
                    {
                        "inline_keyboard": [[
                            {
                                "text": "📢 کانال پرامپتینو",
                                "url": PROMPTINO_CHANNEL
                            }
                        ]]
                    }
                )
                return

        send(
            chat_id,
            WELCOME,
            {
                "inline_keyboard": [[
                    {
                        "text": "📢 ورود به کانال پرامپتینو",
                        "url": PROMPTINO_CHANNEL
                    }
                ]]
            }
        )


@app.get("/")
def home():
    return "Promptino Bot is running ✅", 200


@app.post("/webhook")
def webhook():
    handle_update(request.get_json(silent=True) or {})
    return "OK", 200


# Render آدرس سرویس را در RENDER_EXTERNAL_URL قرار می‌دهد.
# Webhook را خودکار ثبت می‌کنیم.
if TOKEN and os.getenv("RENDER_EXTERNAL_URL"):
    webhook_url = os.getenv("RENDER_EXTERNAL_URL").rstrip("/") + "/webhook"
    result = api("setWebhook", {"url": webhook_url})
    print("Webhook:", result)
PY

CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT:-10000} main:app"]
