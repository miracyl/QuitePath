import pytest
from uuid import uuid4
import asyncpg  # type: ignore
import sys
sys.path.insert(0, ".")
from auth_db import db as db  # noqa: E402
from auth_db import models as mod  # noqa: E402


@pytest.fixture
async def conn():  # type: ignore
    pool = await asyncpg.create_pool(  # type: ignore
        user="postgres",
        password="postgres",
        database="auth_db",
        host="localhost",
        port=5432,
        min_size=1,
        max_size=2,
    )
    async with pool.acquire() as connection:  # type: ignore
        yield connection
    await pool.close()


@pytest.mark.asyncio
async def test_register_and_get_user(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    user_from_db = await db.get_user(conn, user_uuid)
    assert user_from_db.email == email
    assert user_from_db.hashed_password == password
    assert user_from_db.uuid == user_uuid


@pytest.mark.asyncio
async def test_get_user_by_email(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    user_from_db = await db.get_user_by_email(conn, email)
    assert user_from_db is not None
    assert user_from_db.email == email
    assert user_from_db.uuid == user_uuid


@pytest.mark.asyncio
async def test_is_user_in_db(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    assert await db.is_user_in_db(conn, email) is True
    assert await db.is_user_in_db(conn, "notfound@example.com") is False


@pytest.mark.asyncio
async def test_save_and_get_verif(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    code = "123456"
    await db.save_verif(conn, code, user_uuid, 2)
    verif_code = await db.get_verif(conn, user_uuid)
    assert verif_code == code


@pytest.mark.asyncio
async def test_confirm_user(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    await db.confirm_user(conn, user_uuid)
    # Проверим, что не выбрасывает исключение


@pytest.mark.asyncio
async def test_is_user_exists(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    assert await db.is_user_exists(conn, user_uuid) is True
    assert await db.is_user_exists(conn, uuid4()) is False


@pytest.mark.asyncio
async def test_edit_email_user(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    new_email = f"new_{uuid4()}@example.com"
    await db.edit_email_user(conn, user_uuid, new_email)
    user_from_db = await db.get_user_by_email(conn, new_email)
    assert user_from_db is not None
    assert user_from_db.email == new_email


@pytest.mark.asyncio
async def test_edit_password_user(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    new_password = "new_hashed_password"
    await db.edit_password_user(conn, user_uuid, new_password)
    user_from_db = await db.get_user(conn, user_uuid)
    assert user_from_db.hashed_password == new_password


@pytest.mark.asyncio
async def test_delete_user(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    await db.delete_user(conn, user_uuid)
    assert await db.is_user_exists(conn, user_uuid) is False


@pytest.mark.asyncio
async def test_permissions_cycle(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    # Проверка получения и установки прав
    perms = await db.get_user_permissions(conn, user_uuid)
    assert isinstance(perms, mod.AllPermissions)
    # Изменим права
    perms.can_login = True
    await db.set_user_permissions(conn, user_uuid, perms)
    perms2 = await db.get_user_permissions(conn, user_uuid)
    assert perms2.can_login is True


@pytest.mark.asyncio
async def test_save_and_get_mongo_id(conn: asyncpg.Connection):
    email = f"test_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions(can_login=True))
    await db.register_user(conn, user)
    await db.set_user_permissions(conn=conn, user_uuid=user_uuid, permissions=user.permissions)  # Сохранение прав пользователя
    mongo_id = f"mongo_{uuid4()}"
    await db.save_mongo_id(conn, user, mongo_id)
    user_id = await db.get_user_id_by_mongo(conn, mongo_id)
    assert user_id == user_uuid


@pytest.mark.asyncio
async def test_get_user_without_permissions(conn: asyncpg.Connection):
    email = f"test_noperms_{uuid4()}@example.com"
    password = "hashed_password"
    user_uuid = uuid4()
    user = mod.User(uuid=user_uuid, email=email, hashed_password=password, permissions=mod.AllPermissions())
    await db.register_user(conn, user)
    # Не вызываем set_user_permissions
    user_from_db = await db.get_user(conn, user_uuid)
    assert user_from_db.email == email
    assert user_from_db.hashed_password == password
    assert user_from_db.uuid == user_uuid
    # Все права должны быть False
    fields = type(user_from_db.permissions).model_fields
    assert all(getattr(user_from_db.permissions, field) is False for field in fields)
