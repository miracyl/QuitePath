from functools import lru_cache

from jiragram.config import settings
from jiragram.core.services import JiraWebhookService
from jiragram.infrastructure.database import create_db
from jiragram.infrastructure.telegram import create_bot, create_dispatcher


@lru_cache
def get_db():
    print("👉 Creating new DB instance")
    return create_db(settings.db_url)


@lru_cache
def get_bot():
    return create_bot(settings.tg_bot_token)


@lru_cache
def get_dispatcher():
    db = get_db()
    bot = get_bot()
    return create_dispatcher(bot, db)


def get_webhook_service():
    return JiraWebhookService(db=get_db(), bot=get_bot())
