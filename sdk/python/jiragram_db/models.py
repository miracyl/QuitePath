"""
Woking with auth db version 0.0.1
"""

from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class JiraEvents(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    issue_key: str
    project_key: str
    event_type: str
    raw_payload: Dict[str, Any]
    id: Optional[UUID] = None
    author_id: Optional[str] = None
    processed: bool = False


class Users(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    telegram_id: int
    jira_account_id: str
    full_name: str
    id: Optional[int] = None

    permissions: List[str] = Field(default_factory=lambda: ["receive_updates"])


__all__ = ["JiraEvents", "Users"]
