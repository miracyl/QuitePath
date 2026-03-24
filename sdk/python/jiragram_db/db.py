"""
Working with jiragram db version 0.0.1
"""

import json
from datetime import datetime, timedelta

import asyncpg

from .db_models import JiraEvents


class JiragramDatabase:
    def __init__(self, dsn: str):
        self.dsn = dsn
        self.pool = None

    async def connect(self):
        if not self.pool:
            try:
                self.pool = await asyncpg.create_pool(self.dsn)
                print("🚀 Пул asyncpg успешно инициализирован")
            except Exception as e:
                print(f"❌ Ошибка подключения к БД: {e}")
                raise

    async def save_event(self, event: JiraEvents):
        if not self.pool:
            raise RuntimeError(
                "Database pool is not initialized. Call connect() first."
            )
        query = """
            INSERT INTO jira_events (
                issue_key, project_key, event_type, author_id, raw_payload
            ) VALUES ($1, $2, $3, $4, $5)
        """
        payload_json = json.dumps(event.raw_payload)
        await self.pool.execute(
            query,
            event.issue_key,
            event.project_key,
            event.event_type,
            event.author_id,
            payload_json,
        )

    async def check_tg_user_exist(self, user_tg_id: int):
        query = """
            SELECT EXISTS(
                SELECT 1 FROM user_platforms WHERE external_id = $1 AND platform = 'telegram'
            );
        """
        return await self.pool.fetchval(query, str(user_tg_id))

    async def check_user_jira_exist(self, user_jira_id: str):
        query = "SELECT EXISTS(SELECT 1 FROM users WHERE jira_id = $1);"
        return await self.pool.fetchval(query, user_jira_id)

    async def bind_telegram_to_user(self, jira_id: str, tg_id: int):
        """Привязывает Telegram ID к Jira ID. Если Jira ID нет в users – создаёт."""
        user_id = await self.pool.fetchval(
            "SELECT id FROM users WHERE jira_id = $1", jira_id
        )
        if not user_id:
            user_id = await self.pool.fetchval(
                "INSERT INTO users (jira_id) VALUES ($1) RETURNING id", jira_id
            )
        query = """
            INSERT INTO user_platforms (user_id, platform, external_id)
            VALUES ($1, 'telegram', $2)
            ON CONFLICT (platform, external_id) 
            DO UPDATE SET user_id = EXCLUDED.user_id;
        """
        await self.pool.execute(query, user_id, str(tg_id))

    async def get_telegram_id_by_jira_id(self, jira_id: str):
        """Находит Telegram ID по Jira ID."""
        query = """
            SELECT p.external_id
            FROM users u
            JOIN user_platforms p ON u.id = p.user_id
            WHERE u.jira_id = $1 AND p.platform = 'telegram'
        """
        row = await self.pool.fetchrow(query, jira_id)
        return row["external_id"] if row else None

    async def get_jira_id_by_telegram_id(self, telegram_id: int):
        """Находит Jira ID по Telegram ID."""
        query = """
            SELECT u.jira_id
            FROM users u
            JOIN user_platforms p ON u.id = p.user_id
            WHERE p.platform = 'telegram' AND p.external_id = $1
        """
        row = await self.pool.fetchrow(query, str(telegram_id))
        return row["jira_id"] if row else None

    async def save_oauth_tokens(
        self, telegram_id: int, access_token: str, refresh_token: str, expires_in: int
    ):
        """Сохраняет OAuth токены для пользователя по его Telegram ID."""
        expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
        async with self.pool.acquire() as conn:
            user_id = await conn.fetchval(
                "SELECT u.id FROM users u JOIN user_platforms p ON u.id = p.user_id WHERE p.platform='telegram' AND p.external_id=$1",
                str(telegram_id),
            )
            if user_id:
                await conn.execute(
                    "UPDATE users SET jira_access_token=$1, jira_refresh_token=$2, jira_token_expires_at=$3 WHERE id=$4",
                    access_token,
                    refresh_token,
                    expires_at,
                    user_id,
                )

    async def get_oauth_tokens(self, telegram_id: int):
        """Возвращает (access_token, refresh_token, expires_at) для пользователя по Telegram ID."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT u.jira_access_token, u.jira_refresh_token, u.jira_token_expires_at FROM users u JOIN user_platforms p ON u.id = p.user_id WHERE p.platform='telegram' AND p.external_id=$1",
                str(telegram_id),
            )
        if row:
            return (
                row["jira_access_token"],
                row["jira_refresh_token"],
                row["jira_token_expires_at"],
            )
        return None, None, None

    async def logout_user(self, user_tg_id: int) -> bool:
        """
        Удаляет привязку Telegram к Jira.
        Возвращает True, если пользователь был найден и удален, иначе False.
        """
        query = """
            DELETE FROM user_platforms 
            WHERE external_id = $1 AND platform = 'telegram'
            RETURNING id;
        """
        result = await self.pool.fetchval(query, str(user_tg_id))
        return result is not None
