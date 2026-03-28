import hashlib
import hmac
from typing import Optional


def verify_signature(body: bytes, secret: str, signature_header: Optional[str]) -> bool:
    """Проверяет подпись вебхука Jira."""
    if not signature_header:
        return False
    if not secret or not signature_header:
        print("Не совпадают сигнатуры")
        # return False
    expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    received = signature_header.removeprefix("sha256=")
    return hmac.compare_digest(expected, received)
