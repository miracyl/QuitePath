# src/jiragram/core/notifications.py
from jiragram.config import settings


def get_notification_info(payload: dict):
    """
    Возвращает словарь с информацией для уведомления:
    {
        'text': str,
        'target_jira_id': str,
        'is_test': bool,
        'issue_key': str   # ключ задачи для построения кнопки
    }
    или None, если уведомление не требуется.
    """
    issue = payload.get("issue", {})
    fields = issue.get("fields", {})
    key = issue.get("key", "N/A")
    summary = fields.get("summary", "Без названия")
    priority = fields.get("priority", {}).get("name", "Нет приоритета")
    event_type = payload.get("webhookEvent")
    author_name = payload.get("user", {}).get("displayName", "Кто-то")
    author_id = payload.get("user", {}).get("accountId")

    # Текстовая ссылка для копирования (без HTML-тега)
    issue_link_text = f"https://invix-solution-team.atlassian.net/browse/{key}"

    # Заголовок с ключом и названием
    header = (
        f"🛠 <b>Запись в Jira: {key}</b> – <i>{summary}</i>\n"
        f"⭐ Приоритет: {priority}\n"
    )

    def _prepare(text, target_jira_id):
        result = {
            "text": text,
            "target_jira_id": target_jira_id,
            "is_test": False,
            "issue_key": key,
        }
        if settings.test_mode and target_jira_id == author_id:
            result["text"] = f"[TEST] {text}"
            result["target_jira_id"] = settings.test_chat_id
            result["is_test"] = True
        return result

    # 1. Создание задачи – пропускаем
    if event_type == "jira:issue_created":
        return None

    # 2. Обновление задачи
    if event_type == "jira:issue_updated":
        changelog = payload.get("changelog", {})
        items = changelog.get("items", [])

        for item in items:
            field = item.get("field")
            to_str = item.get("toString", "").lower()

            if field == "status":
                # Статус "Доступный к выполнению" – уведомляем исполнителя
                if to_str == "доступный к выполнению":
                    assignee = fields.get("assignee")
                    if assignee:
                        jira_id = assignee.get("accountId")
                        if jira_id and jira_id != author_id:
                            text = f"{header}🔄 Задача доступна к выполнению! (Статус: {to_str})\n🔗 Ссылка: {issue_link_text}"
                            return _prepare(text, jira_id)
                    return None

                # Статус "На рассмотрении" – уведомляем репортёра
                if to_str in ["на рассмотрении", "на расмотрении"]:
                    reporter = fields.get("reporter")
                    if reporter:
                        jira_id = reporter.get("accountId")
                        if jira_id and jira_id != author_id:
                            text = f"{header}🔄 Задача, назначенная вами, выполнена <b>{author_name}</b> и готова к ревью (Статус: {to_str})\n🔗 Ссылка: {issue_link_text}"
                            return _prepare(text, jira_id)
                    return None

                # Статус "Подтверждено" (approved) – уведомляем исполнителя, если подтвердил не он сам
                if to_str == "approved":
                    assignee = fields.get("assignee")
                    if assignee:
                        jira_id = assignee.get("accountId")
                        if jira_id and jira_id != author_id:
                            text = f"{header}✅ Задача подтверждена <b>{author_name}</b>! (Статус: {to_str})\n🔗 Ссылка: {issue_link_text}"
                            return _prepare(text, jira_id)
                    return None

                # Статус "Требует исправлений" – уведомляем исполнителя, если изменил не он сам
                if to_str == "требует исправлений":
                    assignee = fields.get("assignee")
                    if assignee:
                        jira_id = assignee.get("accountId")
                        if jira_id and jira_id != author_id:
                            text = f"{header}❌ Задача отклонена <b>{author_name}</b>! (Статус: {to_str})\n🔗 Ссылка: {issue_link_text}"
                            return _prepare(text, jira_id)
                    return None

                # Остальные статусы пропускаем
                continue

            # Назначение исполнителя – пропускаем
            if field == "assignee":
                continue

            # Изменение текста – отправляем исполнителю, если изменил не он сам
            if field == "summary":
                assignee = fields.get("assignee")
                if assignee:
                    jira_id = assignee.get("accountId")
                    if jira_id and jira_id != author_id:
                        new_summary = item.get("toString", "")
                        text = f"{header}✏️ Текст задачи изменен на:\n<i>{new_summary}</i>\n🔗 Ссылка: {issue_link_text}"
                        return _prepare(text, jira_id)
                continue

    # 3. Комментарии – отправляем исполнителю, если комментарий оставил не он
    if event_type == "comment_created":
        comment_body = payload.get("comment", {}).get("body", "")
        assignee = fields.get("assignee")
        if assignee:
            jira_id = assignee.get("accountId")
            if jira_id and jira_id != author_id:
                text = f"{header}💬 <b>{author_name}</b> оставил комментарий:\n{comment_body}\n🔗 Ссылка: {issue_link_text}"
                return _prepare(text, jira_id)
        return None

    return None
