import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from jiragram.api import router as webhook_router
from jiragram.api.oauth import router as oauth_router

# Добавляем импорт get_bot
from jiragram.dependencies import get_bot, get_db, get_dispatcher
from jiragram.utils.logging import setup_logging

setup_logging()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. Подключаем БД
    db = get_db()
    print(f"👉 DB instance id: {id(db)}")
    await db.connect()
    print(f"👉 DB connected, pool: {db.pool}")

    dp = get_dispatcher()
    bot = get_bot()

    polling_task = asyncio.create_task(dp.start_polling(bot))

    bot_user = await bot.get_me()
    print(f"🚀 Bot started: @{bot_user.username}")

    yield

    # 4. Завершаем работу
    polling_task.cancel()  # Останавливаем polling при выключении сервера
    await bot.session.close()
    # await db.disconnect() # Проверь правильное название метода у твоего db объекта


app = FastAPI(lifespan=lifespan)
app.include_router(oauth_router)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST"],
    allow_headers=["*"],
)

app.include_router(webhook_router)
