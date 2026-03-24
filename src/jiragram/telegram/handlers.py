from aiogram import Router, types
from aiogram.filters import Command
from aiogram.utils.keyboard import InlineKeyboardBuilder

from jiragram.config import settings

router = Router()


@router.message(Command("start"))
async def cmd_start(message: types.Message, db):
    user_tg_id = message.from_user.id
    jira_id = await db.get_jira_id_by_telegram_id(user_tg_id)
    if jira_id:
        await message.answer(
            f"✅ Вы уже привязаны к Jira аккаунту <code>{jira_id}</code>.",
            parse_mode="HTML",
        )
        return

    builder = InlineKeyboardBuilder()
    builder.row(
        types.InlineKeyboardButton(
            text="🔑 Привязать Jira аккаунт",
            url=f"{settings.base_url}/auth/login?user_tg_id={user_tg_id}",
        )
    )
    await message.answer(
        "Привет! Чтобы получать уведомления Jira, привяжи свой аккаунт.\n\n"
        "Нажми на кнопку ниже, авторизуйся в Jira – и всё готово!",
        reply_markup=builder.as_markup(),
    )
