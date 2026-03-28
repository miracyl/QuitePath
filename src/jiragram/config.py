import os
from urllib.parse import urlparse

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # PostgreSQL
    db_url: str = os.getenv(
        "DB_URL", "postgresql://postgres:postgres@localhost:8181/jiragram_db"
    )

    # Jira
    jira_secret: str = os.getenv("JIRA_SECRET", "")
    jira_client_id: str = os.getenv("JIRA_CLIENT_ID", "")
    jira_client_secret: str = os.getenv("JIRA_CLIENT_SECRET", "")
    jira_redirect_uri: str = os.getenv("JIRA_REDIRECT_URI", "")
    jira_scopes: str = os.getenv("JIRA_SCOPES", "read:me offline_access")

    # Telegram
    tg_bot_token: str = os.getenv("TG_BOT_TOKEN", "")

    # Test mode
    test_mode: bool = os.getenv("TEST_MODE", "false").lower() in ("true", "1", "yes")
    test_chat_id: str = os.getenv("TEST_CHAT_ID", "1655677223")

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def base_url(self) -> str:
        """Возвращает базовый URL из redirect_uri (без пути)."""
        parsed = urlparse(self.jira_redirect_uri)
        return f"{parsed.scheme}://{parsed.netloc}"


settings = Settings()
