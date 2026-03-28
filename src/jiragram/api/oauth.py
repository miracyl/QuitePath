# src/jiragram/api/oauth.py
import httpx
from aiogram import Bot
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import RedirectResponse

from jiragram.config import settings
from jiragram.dependencies import get_bot, get_db
from sdk.python.jiragram_db.db import JiragramDatabase

router = APIRouter(prefix="/auth", tags=["OAuth"])


@router.get("/login")
async def jira_login(user_tg_id: int):
    """Шаг 1: Перенаправляем пользователя на страницу авторизации Atlassian."""
    state = str(user_tg_id)
    url = (
        f"https://auth.atlassian.com/authorize?"
        f"audience=api.atlassian.com&"
        f"client_id={settings.jira_client_id}&"
        f"scope={settings.jira_scopes}&"
        f"redirect_uri={settings.jira_redirect_uri}&"
        f"state={state}&"
        f"response_type=code&"
        f"prompt=consent"
    )
    return RedirectResponse(url)


@router.get("/callback")
async def jira_callback(
    code: str = Query(...),
    state: str = Query(...),
    db: JiragramDatabase = Depends(get_db),
    bot: Bot = Depends(get_bot),
):
    """Шаг 2: Обмениваем код на токен, получаем accountId и привязываем."""
    telegram_id = int(state)

    async with httpx.AsyncClient() as client:
        # Обмен кода на токен
        resp = await client.post(
            "https://auth.atlassian.com/oauth/token",
            json={
                "grant_type": "authorization_code",
                "client_id": settings.jira_client_id,
                "client_secret": settings.jira_client_secret,
                "code": code,
                "redirect_uri": settings.jira_redirect_uri,
            },
        )
    if resp.status_code != 200:
        raise HTTPException(status_code=400, detail="Failed to get access token")

    data = resp.json()
    access_token = data["access_token"]

    # Получаем информацию о пользователе (accountId)
    async with httpx.AsyncClient() as client:
        user_resp = await client.get(
            "https://api.atlassian.com/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )
    if user_resp.status_code != 200:
        raise HTTPException(status_code=400, detail="Failed to get user info")

    user_data = user_resp.json()
    jira_account_id = user_data.get("account_id")
    if not jira_account_id:
        raise HTTPException(status_code=400, detail="No account_id in user info")

    # Сохраняем привязку
    await db.bind_telegram_to_user(jira_account_id, telegram_id)

    # Отправляем уведомление пользователю в Telegram
    await bot.send_message(
        chat_id=telegram_id,
        text=f"✅ Jira аккаунт успешно привязан! Ваш accountId: <code>{jira_account_id}</code>",
        parse_mode="HTML",
    )

    return {"status": "success", "message": "Jira account linked successfully!"}
