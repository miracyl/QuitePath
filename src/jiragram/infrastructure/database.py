from sdk.python.jiragram_db.db import JiragramDatabase


def create_db(dsn: str) -> JiragramDatabase:
    return JiragramDatabase(dsn=dsn)
