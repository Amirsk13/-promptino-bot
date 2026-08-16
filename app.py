import os
import requests
from flask import Flask, request

app = Flask(__name__)

BOT_TOKEN = os.environ.get("BOT_TOKEN")
CHANNEL_URL = "https://t.me/PromptinoChannel"
BOT_API = f"https://api.telegram.org/bot{BOT_TOKEN}" if BOT_TOKEN else ""

PROMPTS = {
    "p001": """📋 پرامپت نمونه پرامپتینو

Create a cinematic professional portrait from the uploaded photo. Keep the person's identity and facial features consistent. Use dramatic cinematic lighting, realistic skin texture, shallow depth of field, premium editorial photography, high detail, natural colors, and a professional camera look."""
}

WELCOME_TEXT = """🤖 سلام! به پرامپتینو خوش اومدی 👋

اینجا می‌تونی به پرامپت‌های کاربردی و تست‌شده هوش مصنوعی دسترسی داشته باشی.

📢 برای دریافت پرامپت، اول وارد کانال پرامپتینو شو و پرامپتی که می‌خوای رو انتخاب کن.

بعد روی دکمه 🚀 دریافت پرامپت همون پست بزن تا ربات پرامپت رو برات ارسال کنه."""

def send_message(chat_id, text, keyboard=None):
    data = {"chat_id": chat_id, "text": text}
    if keyboard:
        data["reply_markup"] = keyboard
    return requests.post(f"{BOT_API}/sendMessage", json=data, timeout=20)

def handle_update(update):
    message = update.get("message")
    if not message:
        return
    text = message.get("text", "")
    chat_id = message["chat"]["id"]

    if text.startswith("/start"):
        parts = text.split(maxsplit=1)
        if len(parts) == 2:
            prompt = PROMPTS.get(parts[1].strip().lower())
            if prompt:
                send_message(chat_id, prompt, {
                    "inline_keyboard": [[
                        {"text": "📢 کانال پرامپتینو", "url": CHANNEL_URL}
                    ]]
                })
                return

        send_message(chat_id, WELCOME_TEXT, {
            "inline_keyboard": [[
                {"text": "📢 ورود به کانال پرامپتینو", "url": CHANNEL_URL}
            ]]
        })

@app.get("/")
def home():
    return "Promptino Bot is running ✅", 200

@app.post("/webhook")
def webhook():
    handle_update(request.get_json(silent=True) or {})
    return "OK", 200

def setup_webhook():
    if not BOT_TOKEN:
        print("BOT_TOKEN is not set.")
        return
    external_url = os.environ.get("RENDER_EXTERNAL_URL")
    if not external_url:
        print("RENDER_EXTERNAL_URL is not available yet.")
        return
    webhook_url = external_url.rstrip("/") + "/webhook"
    response = requests.post(
        f"{BOT_API}/setWebhook",
        json={"url": webhook_url},
        timeout=20
    )
    print("Webhook:", response.text)

setup_webhook()
