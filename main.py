import asyncio
import hashlib
import hmac
import json
import os
from contextlib import asynccontextmanager

from aiogram import Bot, Dispatcher
from aiogram.enums import ParseMode
from dotenv import load_dotenv
from fastapi import FastAPI, Header, Request
from fastapi.middleware.cors import CORSMiddleware

from apps.core.notifications import get_notification_text
from apps.telegram.handlers import router as tg_router
from sdk.python.jiragram_db.db import JiragramDatabase
from sdk.python.jiragram_db.db_models import JiraEvents

# Загрузка переменных из .env
load_dotenv()
print("DEBUG: Пытаюсь подключиться к бд")
db = JiragramDatabase(dsn=os.getenv("DB_URL"))

bot = Bot(token=os.getenv("TG_BOT_TOKEN"))
dp = Dispatcher()
dp.include_router(tg_router)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()
    asyncio.create_task(dp.start_polling(bot, db=db))
    bot_user = await bot.get_me()
    print(f"монолит запущен! Бот: @{bot_user.username}")
    yield

    await bot.session.close()
    print("app close")


app = FastAPI(lifespan=lifespan)


app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["POST"], allow_headers=["*"]
)


@app.post("/{path_params:path}")
async def handle_jira_webhook(
    path_params: str,
    request: Request,
    x_hub_signature_256: str = Header(None, alias="X-Hub-Signature-256"),
):
    body = await request.body()

    jira_secret = os.getenv("JIRA_SECRET").encode()
    expected_sig = hmac.new(jira_secret, body, hashlib.sha256).hexdigest()
    received_hash = (x_hub_signature_256 or "").removeprefix("sha256=")

    if not hmac.compare_digest(expected_sig, received_hash):
        print("CRITICAL: Signature mismatch!")

    try:
        payload = json.loads(body)

        issue = payload.get("issue", {})
        fields = issue.get("fields", {})

        issue_key = issue.get("key")
        project_key = fields.get("project", {}).get("key")
        event_type = payload.get("webhookEvent")

        event_data = JiraEvents(
            issue_key=issue_key,
            project_key=project_key,
            event_type=event_type,
            author_id=payload.get("user", {}).get("accountId"),
            raw_payload=payload,
        )

        await db.save_event(event_data)

        message_text = get_notification_text(payload)

        author_id = payload.get("user", {}).get("accountId")

        assignee_id = fields.get("assignee", {}).get("accountId")

        target_jira_id = assignee_id or author_id
        if author_id == assignee_id:
            print(f"ℹ️ Пропускаем: {author_id} сам изменил свой тикет {issue_key}")
            return {"status": "skipped", "reason": "self_action"}

        chat_id = await db.get_telegram_id_by_jira_id(target_jira_id)

        if chat_id:
            try:
                await bot.send_message(
                    chat_id=chat_id,
                    text=message_text,
                    parse_mode=ParseMode.HTML,
                    disable_web_page_preview=False,
                )
                print(f"✅ Уведомление отправлено пользователю {chat_id}")
            except Exception as send_error:
                print(f"❌ Ошибка отправки в TG: {send_error}")
        else:
            print(
                f"ℹ️ Пользователь с Jira ID {target_jira_id} не найден или не одобрен."
            )

        print(f"✅ Задача {issue_key} обработана!")
        return {"status": "success", "issue": issue_key}

    except Exception as e:
        print(f"Error processing webhook: {e}")
        return {"status": "error", "message": str(e)}
