# src/jiragram/core/services.py
import logging

from jiragram.config import settings
from jiragram.core.notifications import get_notification_info
from jiragram.telegram.keyboards import get_issue_button
from sdk.python.jiragram_db.db_models import JiraEvents

logger = logging.getLogger(__name__)


class JiraWebhookService:
    def __init__(self, db, bot):
        self.db = db
        self.bot = bot

    async def process(self, payload: dict) -> dict:
        try:
            issue = payload.get("issue", {})
            fields = issue.get("fields", {})
            event_data = JiraEvents(
                issue_key=issue.get("key"),
                project_key=fields.get("project", {}).get("key"),
                event_type=payload.get("webhookEvent"),
                author_id=(payload.get("user") or {}).get("accountId"),
                raw_payload=payload,
            )
            await self.db.save_event(event_data)

            # Получаем информацию для уведомления (теперь словарь)
            notification = get_notification_info(payload)

            if not notification:
                logger.info(
                    "No notification needed for event: %s", payload.get("webhookEvent")
                )
                return {"status": "skipped", "reason": "no_notification_required"}

            text = notification["text"]
            target_jira_id = notification["target_jira_id"]
            is_test = notification["is_test"]
            issue_key = notification["issue_key"]

            # Определяем chat_id для отправки
            if is_test:
                chat_id = target_jira_id  # в тестовом режиме target_jira_id уже содержит chat_id
            else:
                chat_id = await self.db.get_telegram_id_by_jira_id(target_jira_id)
                if not chat_id:
                    logger.info("User with Jira ID %s not found", target_jira_id)
                    return {"status": "skipped", "reason": "user_not_found"}

            # Создаём клавиатуру с кнопкой
            keyboard = get_issue_button(issue_key)

            # Отправляем сообщение
            await self.bot.send_message(
                chat_id=chat_id,
                text=text,
                parse_mode="HTML",
                disable_web_page_preview=False,
                reply_markup=keyboard,
            )
            logger.info(
                "Notification sent to chat_id=%s for issue %s",
                chat_id,
                issue.get("key"),
            )
            return {"status": "success", "issue": issue.get("key")}

        except Exception as e:
            logger.exception("Error processing webhook")
            return {"status": "error", "message": str(e)}
