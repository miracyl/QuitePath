import json
import logging

from fastapi import APIRouter, Depends, Header, HTTPException, Request

from jiragram.config import settings
from jiragram.core import JiraWebhookService
from jiragram.dependencies import get_webhook_service
from jiragram.utils.signature import verify_signature

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/{path_params:path}")
async def jira_webhook(
    path_params: str,
    request: Request,
    x_hub_signature: str = Header(None, alias="X-Hub-Signature"),
    service: JiraWebhookService = Depends(get_webhook_service),
):
    body = await request.body()

    if not verify_signature(body, settings.jira_secret, x_hub_signature):
        print("CRITICAL: Signature mismatch!")
        raise HTTPException(status_code=401, detail="Invalid signature")

    payload = json.loads(body)
    result = await service.process(payload)
    return result
