# src/jiragram/ui/keyboards.py
from aiogram.types import InlineKeyboardButton, InlineKeyboardMarkup


def get_issue_button(issue_key: str) -> InlineKeyboardMarkup:
    """Возвращает inline-клавиатуру с одной кнопкой для перехода к задаче в Jira."""
    url = f"https://invix-solution-team.atlassian.net/browse/{issue_key}"
    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[[InlineKeyboardButton(text="🔗 Перейти к задаче", url=url)]]
    )
    return keyboard
