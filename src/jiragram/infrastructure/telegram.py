from aiogram import Bot, Dispatcher

from jiragram.telegram.handlers import router as tg_router


def create_bot(token: str) -> Bot:
    return Bot(token=token)


def create_dispatcher(bot: Bot, db) -> Dispatcher:
    dp = Dispatcher()
    dp.include_router(tg_router)
    dp["db"] = db
    dp["bot"] = bot
    return dp
