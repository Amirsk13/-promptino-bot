import os
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, ContextTypes

CHANNEL_URL = "https://t.me/PromptinoChannel"

PROMPTS = {
    "p001": """پرامپت نمونه پرامپتینو

Create a cinematic professional portrait from the uploaded photo. Keep the person's identity and facial features consistent. Use dramatic cinematic lighting, realistic skin texture, shallow depth of field, premium editorial photography, high detail, natural colors, and a professional camera look.""",
}

WELCOME_TEXT = """🤖 سلام! به پرامپتینو خوش اومدی 👋

اینجا می‌تونی به پرامپت‌های کاربردی و تست‌شده هوش مصنوعی دسترسی داشته باشی.

📢 برای دریافت پرامپت، اول وارد کانال پرامپتینو شو و پرامپتی که می‌خوای رو انتخاب کن.

بعد روی دکمه 🚀 دریافت پرامپت همون پست بزن تا ربات پرامپت رو برات ارسال کنه."""

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    args = context.args

    if args:
        prompt_id = args[0].lower()
        prompt = PROMPTS.get(prompt_id)
        if prompt:
            await update.message.reply_text(
                f"📋 پرامپت آماده است:\n\n{prompt}",
                reply_markup=InlineKeyboardMarkup([
                    [InlineKeyboardButton("📢 کانال پرامپتینو", url=CHANNEL_URL)]
                ])
            )
            return

    await update.message.reply_text(
        WELCOME_TEXT,
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("📢 ورود به کانال پرامپتینو", url=CHANNEL_URL)]
        ])
    )

def main():
    token = os.environ.get("BOT_TOKEN")
    if not token:
        raise RuntimeError("BOT_TOKEN environment variable is missing.")

    app = Application.builder().token(token).build()
    app.add_handler(CommandHandler("start", start))
    app.run_polling()

if __name__ == "__main__":
    main()
