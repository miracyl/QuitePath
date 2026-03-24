"""
Working with jiragram db version 0.0.1
Updated models to match existing SQL schema.
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, List, Optional
from uuid import UUID


@dataclass
class UserPlatform:
    """Связь пользователя с внешней платформой (Telegram и т.д.)"""

    id: Optional[int] = None
    user_id: Optional[int] = None  # id из таблицы users
    platform: str = ""  # 'telegram', 'slack' и т.д.
    external_id: str = ""  # telegram_id, slack_id и т.д.


@dataclass
class Users:
    """Пользователь Jira (данные из таблицы users)"""

    id: Optional[int] = None
    jira_id: str = ""
    permissions: List[str] = field(
        default_factory=lambda: ["dev_to_stage", "stage_to_prod", "prod_fail"]
    )
    jira_access_token: Optional[str] = None
    jira_refresh_token: Optional[str] = None
    jira_token_expires_at: Optional[datetime] = None
    platforms: List[UserPlatform] = field(default_factory=list)


@dataclass
class JiraEvents:
    """Событие Jira (из таблицы jira_events)"""

    id: Optional[UUID] = None
    issue_key: str = ""
    project_key: str = ""
    event_type: str = ""
    author_id: Optional[str] = None
    raw_payload: dict = field(default_factory=dict)
    processed: bool = False
    created_at: Optional[datetime] = None


__all__ = ["Users", "JiraEvents", "UserPlatform"]
