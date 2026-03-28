from aiogram import Router, types
from aiogram.filters import Command
from aiogram.filters.chat_member_updated import KICKED, MEMBER, ChatMemberUpdatedFilter
from aiogram.utils.keyboard import InlineKeyboardBuilder

from jiragram.config import settings

router = Router()


@router.message(Command("start"))
async def cmd_start(message: types.Message, db):
    help_text = (
        "<b>🚀 Jiragram: Твоя Jira в Telegram</b>\n\n"
        "Бот автоматизирует уведомления из Jira, чтобы ты не пропускал важные изменения в задачах.\n\n"
        "<b>🛠 Основные команды:</b>\n"
        "🔗 /start — Привязать Jira аккаунт через OAuth2\n"
        "🚪 /logout — Отключить уведомления и выйти\n"
        "❓ /help — Показать эту справку\n\n"
        "<b>🔔 Как работают уведомления?</b>\n"
        "Бот пришлет сообщение, если кто-то (кроме тебя):\n"
        "• Изменит статус твоего тикета.\n"
        "• Назначит задачу на тебя (Assignee).\n"
        "• <b>Важно:</b> Если ты автор задачи, бот уведомит тебя, когда она перейдет в состояние готовности.\n\n"
        "<b>🔒 Безопасность:</b>\n"
        "Мы используем протокол <b>OAuth2</b>. Это значит:\n"
        "1. Бот <u>не видит</u> твой пароль от Jira.\n"
        "2. Доступ идет через защищенный токен Atlassian.\n"
        "3. Ты можешь отозвать доступ в любой момент.\n\n"
        "<i>Есть вопросы? Обращайся к администратору.</i>"
    )

    await message.answer(help_text, parse_mode="HTML")

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


@router.message(Command("logout"))
async def cmd_logout(message: types.Message, db):
    tg_id = message.from_user.id

    was_logged_in = await db.logout_user(tg_id)

    if not was_logged_in:
        await message.answer("Вы не авторизованы, выходить не из чего. 😉")
        return

    await message.answer(
        "✅ Вы успешно вышли из системы. Уведомления больше не будут приходить.\n"
        "Чтобы вернуться, используйте /start"
    )


@router.my_chat_member(ChatMemberUpdatedFilter(member_status_changed=KICKED))
async def user_blocked_bot(event: types.ChatMemberUpdated, db):
    user_tg_id = event.from_user.id

    print(f"🚫 Пользователь {user_tg_id} заблокировал бота.")

    await db.logout_user(user_tg_id)


@router.message(Command("help"))
async def cmd_help(message: types.Message):
    help_text = (
        "<b>🚀 Jiragram: Твоя Jira в Telegram</b>\n\n"
        "Бот автоматизирует уведомления из Jira, чтобы ты не пропускал важные изменения в задачах.\n\n"
        "<b>🛠 Основные команды:</b>\n"
        "🔗 /start — Привязать Jira аккаунт через OAuth2\n"
        "🚪 /logout — Отключить уведомления и выйти\n"
        "❓ /help — Показать эту справку\n\n"
        "<b>🔔 Как работают уведомления?</b>\n"
        "Бот пришлет сообщение, если кто-то (кроме тебя):\n"
        "• Изменит статус твоего тикета.\n"
        "• Назначит задачу на тебя (Assignee).\n"
        "• <b>Важно:</b> Если ты автор задачи, бот уведомит тебя, когда она перейдет в состояние готовности.\n\n"
        "<b>🔒 Безопасность:</b>\n"
        "Мы используем протокол <b>OAuth2</b>. Это значит:\n"
        "1. Бот <u>не видит</u> твой пароль от Jira.\n"
        "2. Доступ идет через защищенный токен Atlassian.\n"
        "3. Ты можешь отозвать доступ в любой момент.\n\n"
        "<i>Есть вопросы? Обращайся к администратору.</i>"
    )

    await message.answer(help_text, parse_mode="HTML")
