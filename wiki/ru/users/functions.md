# Функции Пользователей

Полный справочник по всем функциям управления пользователями с параметрами, возвратами, ошибками и примерами.

**Примечание:** Все примеры на Python используют **asyncpg==0.30.0** для асинхронных операций с PostgreSQL.

## Содержание

1. [CREATE_USER](#create_user) - Регистрация пользователя
2. [CHANGE_PASSWORD](#change_password) - Изменение пароля
3. [CHANGE_EMAIL](#change_email) - Изменение email
4. [VERIFY_USER](#verify_user) - Пометить верифицированным
5. [UNVERIFY_USER](#unverify_user) - Снять верификацию
6. [FIND_USER_BY_UUID](#find_user_by_uuid) - Найти по UUID
7. [FIND_USER_BY_EMAIL](#find_user_by_email) - Найти по email
8. [LOGIN_USER](#login_user) - Аутентификация

---

## CREATE_USER

Создает нового пользователя с email и хешем пароля.

### Сигнатура

```sql
CREATE_USER(
    P_EMAIL VARCHAR(255),
    P_HASH_PASSWORD VARCHAR(255)
) RETURNS TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    CREATED_AT TIMESTAMPTZ
)
```

### Параметры

- `P_EMAIL` - Email пользователя
- `P_HASH_PASSWORD` - Хеш пароля (bcrypt/argon2)

### Возвращает

Таблицу с данными пользователя (ID, UUID, EMAIL, CREATED_AT)

### Ошибки

- **EMAIL_EXISTS** (23505) - Email уже зарегистрирован

### SQL Пример

```sql
SELECT * FROM CREATE_USER('user@example.com', '$2a$10$hash...');
```

### Пример на Python (asyncpg==0.30.0)

```python
import asyncpg
from typing import Optional

class UserRepository:
    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    async def create_user(self, email: str, password_hash: str) -> Optional[dict]:
        """
        Создать нового пользователя.

        Args:
            email: Email пользователя
            password_hash: Хеш пароля Bcrypt/Argon2

        Returns:
            Dict с данными пользователя (id, uuid, email, created_at) или None при ошибке

        Raises:
            EmailExistsError: Если email уже зарегистрирован
        """
        async with self.pool.acquire() as conn:
            try:
                row = await conn.fetchrow(
                    "SELECT * FROM CREATE_USER($1, $2)",
                    email,
                    password_hash
                )

                if row:
                    return {
                        'id': row['id'],
                        'uuid': str(row['uuid']),
                        'email': row['email'],
                        'created_at': row['created_at']
                    }

            except asyncpg.UniqueViolationError as e:
                # Проверяем hint на EMAIL_EXISTS
                if 'EMAIL_EXISTS' in str(e):
                    raise EmailExistsError(f"Email {email} уже зарегистрирован")
                raise
            except asyncpg.PostgresError as e:
                # Логируем и пробрасываем
                logger.error(f"Ошибка БД в create_user: {e}")
                raise

# Пример использования
async def register_user_handler(email: str, password: str):
    """Обработчик регистрации с хешированием пароля."""
    import bcrypt

    # Хешируем пароль
    password_hash = bcrypt.hashpw(
        password.encode('utf-8'),
        bcrypt.gensalt(rounds=12)
    ).decode('utf-8')

    # Создаём пользователя
    try:
        user = await user_repo.create_user(email, password_hash)
        return {
            'success': True,
            'user': user
        }
    except EmailExistsError:
        return {
            'success': False,
            'error': 'EMAIL_EXISTS',
            'message': 'Email уже зарегистрирован'
        }
```

---

## CHANGE_PASSWORD

Обновляет хеш пароля пользователя.

### Сигнатура

```sql
CHANGE_PASSWORD(
    P_UUID UUID,
    P_NEW_HASH_PASSWORD VARCHAR(255)
) RETURNS BOOLEAN
```

### Параметры

- `P_UUID` - UUID пользователя
- `P_NEW_HASH_PASSWORD` - Новый хеш пароля

### Возвращает

- `TRUE` - Пароль обновлен
- `FALSE` - Пользователь не найден

### SQL Пример

```sql
SELECT CHANGE_PASSWORD('550e8400-e29b-41d4-a716-446655440000', '$2a$10$new...');
```

### Пример на Python (asyncpg==0.30.0)

```python
async def change_password(self, user_uuid: str, new_password_hash: str) -> bool:
    """
    Изменить пароль пользователя.

    Args:
        user_uuid: UUID пользователя
        new_password_hash: Новый хеш пароля

    Returns:
        True если пароль изменен, False если пользователь не найден
    """
    async with self.pool.acquire() as conn:
        result = await conn.fetchval(
            "SELECT CHANGE_PASSWORD($1, $2)",
            user_uuid,
            new_password_hash
        )
        return result

# Пример использования
async def change_password_handler(user_uuid: str, old_password: str, new_password: str):
    """Обработчик с проверкой старого пароля."""
    import bcrypt

    # 1. Проверяем старый пароль
    user = await user_repo.find_user_by_uuid(user_uuid)
    if not user:
        return {'error': 'Пользователь не найден'}

    if not bcrypt.checkpw(old_password.encode(), user['hash_password'].encode()):
        return {'error': 'Неверный старый пароль'}

    # 2. Хешируем новый пароль
    new_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt(12)).decode()

    # 3. Обновляем
    success = await user_repo.change_password(user_uuid, new_hash)
    return {'success': success}
```

---

## CHANGE_EMAIL

Обновляет email пользователя и сбрасывает верификацию.

### Сигнатура

```sql
CHANGE_EMAIL(
    P_UUID UUID,
    P_NEW_EMAIL VARCHAR(255)
) RETURNS BOOLEAN
```

### Параметры

- `P_UUID` - UUID пользователя
- `P_NEW_EMAIL` - Новый email

### Возвращает

- `TRUE` - Email обновлен
- `FALSE` - Пользователь не найден

### Ошибки

- **EMAIL_EXISTS** (23505) - Email уже используется

### Побочные эффекты

- Устанавливает `IS_VERIFIED = FALSE`
- Обновляет `UPDATED_AT`

### Пример на Python (asyncpg==0.30.0)

```python
async def change_email(self, user_uuid: str, new_email: str) -> bool:
    """
    Изменить email пользователя и сбросить верификацию.

    Args:
        user_uuid: UUID пользователя
        new_email: Новый email

    Returns:
        True если email изменен, False если пользователь не найден

    Raises:
        EmailExistsError: Если email уже используется
    """
    async with self.pool.acquire() as conn:
        try:
            result = await conn.fetchval(
                "SELECT CHANGE_EMAIL($1, $2)",
                user_uuid,
                new_email
            )
            return result

        except asyncpg.UniqueViolationError as e:
            if 'EMAIL_EXISTS' in str(e):
                raise EmailExistsError(f"Email {new_email} уже используется")
            raise

# Использование с отправкой письма верификации
async def change_email_handler(user_uuid: str, new_email: str):
    """Обработчик, отправляющий письмо верификации."""
    try:
        success = await user_repo.change_email(user_uuid, new_email)

        if success:
            # Отправляем письмо верификации
            await email_service.send_verification(new_email)
            return {'success': True, 'message': 'Письмо верификации отправлено'}
        else:
            return {'error': 'Пользователь не найден'}

    except EmailExistsError:
        return {'error': 'EMAIL_EXISTS', 'message': 'Email уже используется'}
```

---

## VERIFY_USER

Помечает пользователя как верифицированного.

### Сигнатура

```sql
VERIFY_USER(P_UUID UUID) RETURNS BOOLEAN
```

### Параметры

- `P_UUID` - UUID пользователя

### Возвращает

- `TRUE` - Пользователь верифицирован
- `FALSE` - Пользователь не найден

### Пример на Python (asyncpg==0.30.0)

```python
async def verify_user(self, user_uuid: str) -> bool:
    """Пометить пользователя верифицированным."""
    async with self.pool.acquire() as conn:
        return await conn.fetchval(
            "SELECT VERIFY_USER($1)",
            user_uuid
        )

# Использование в обработчике верификации email
async def verify_email_handler(token: str):
    """Верифицировать email по токену."""
    # 1. Декодируем JWT токен
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_uuid = payload['uuid']
    except jwt.InvalidTokenError:
        return {'error': 'Неверный токен'}

    # 2. Верифицируем пользователя
    success = await user_repo.verify_user(user_uuid)

    if success:
        return {'success': True, 'message': 'Email верифицирован'}
    else:
        return {'error': 'Пользователь не найден'}
```

---

## UNVERIFY_USER

Снимает верификацию с пользователя.

### Сигнатура

```sql
UNVERIFY_USER(P_UUID UUID) RETURNS BOOLEAN
```

### Параметры

- `P_UUID` - UUID пользователя

### Возвращает

- `TRUE` - Верификация снята
- `FALSE` - Пользователь не найден

### Пример на Python (asyncpg==0.30.0)

```python
async def unverify_user(self, user_uuid: str) -> bool:
    """Снять верификацию с пользователя."""
    async with self.pool.acquire() as conn:
        return await conn.fetchval(
            "SELECT UNVERIFY_USER($1)",
            user_uuid
        )
```

---

## FIND_USER_BY_UUID

Получает полную запись пользователя по UUID.

### Сигнатура

```sql
FIND_USER_BY_UUID(P_UUID UUID) RETURNS TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    HASH_PASSWORD VARCHAR(255),
    CREATED_AT TIMESTAMPTZ,
    UPDATED_AT TIMESTAMPTZ,
    IS_VERIFIED BOOLEAN
)
```

### Параметры

- `P_UUID` - UUID пользователя

### Возвращает

Таблицу с полной записью (пустая если не найден)

### Пример на Python (asyncpg==0.30.0)

```python
async def find_user_by_uuid(self, user_uuid: str) -> Optional[dict]:
    """
    Найти пользователя по UUID.

    Args:
        user_uuid: UUID пользователя

    Returns:
        Dict с данными пользователя или None если не найден
    """
    async with self.pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM FIND_USER_BY_UUID($1)",
            user_uuid
        )

        if row:
            return {
                'id': row['id'],
                'uuid': str(row['uuid']),
                'email': row['email'],
                'hash_password': row['hash_password'],
                'created_at': row['created_at'],
                'updated_at': row['updated_at'],
                'is_verified': row['is_verified']
            }
        return None

# Использование в middleware
async def get_current_user(user_uuid: str):
    """Получить текущего пользователя из UUID в JWT токене."""
    user = await user_repo.find_user_by_uuid(user_uuid)

    if not user:
        raise HTTPException(status_code=401, detail="Пользователь не найден")

    # Не раскрываем хеш пароля
    user.pop('hash_password')
    return user
```

---

## FIND_USER_BY_EMAIL

Получает полную запись пользователя по email.

### Сигнатура

```sql
FIND_USER_BY_EMAIL(P_EMAIL VARCHAR(255)) RETURNS TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    HASH_PASSWORD VARCHAR(255),
    CREATED_AT TIMESTAMPTZ,
    UPDATED_AT TIMESTAMPTZ,
    IS_VERIFIED BOOLEAN
)
```

### Пример на Python (asyncpg==0.30.0)

```python
async def find_user_by_email(self, email: str) -> Optional[dict]:
    """Найти пользователя по email."""
    async with self.pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM FIND_USER_BY_EMAIL($1)",
            email
        )

        if row:
            return dict(row)
        return None
```

---

## LOGIN_USER

Аутентифицирует пользователя по email и паролю.

### Сигнатура

```sql
LOGIN_USER(
    P_EMAIL VARCHAR(255),
    P_HASH_PASSWORD VARCHAR(255)
) RETURNS TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    IS_VERIFIED BOOLEAN,
    CREATED_AT TIMESTAMPTZ
)
```

### Параметры

- `P_EMAIL` - Email пользователя
- `P_HASH_PASSWORD` - Хеш пароля для проверки

### Возвращает

Таблицу с данными пользователя (пустая если неверные учетные данные)

### Пример на Python (asyncpg==0.30.0)

```python
async def login_user(self, email: str, password: str) -> Optional[dict]:
    """
    Аутентификация пользователя по email и паролю.

    Args:
        email: Email пользователя
        password: Пароль в открытом виде

    Returns:
        Dict с данными пользователя если аутентифицирован, None иначе
    """
    import bcrypt

    async with self.pool.acquire() as conn:
        # Получаем пользователя с хешем пароля
        user = await conn.fetchrow(
            "SELECT * FROM FIND_USER_BY_EMAIL($1)",
            email
        )

        if not user:
            return None

        # Проверяем пароль
        if not bcrypt.checkpw(password.encode(), user['hash_password'].encode()):
            return None

        # Возвращаем данные пользователя (без пароля)
        return {
            'id': user['id'],
            'uuid': str(user['uuid']),
            'email': user['email'],
            'is_verified': user['is_verified'],
            'created_at': user['created_at']
        }

# Полный обработчик входа
async def login_handler(email: str, password: str):
    """
    Обработчик входа с генерацией JWT.

    Возвращает access token и refresh token.
    """
    user = await user_repo.login_user(email, password)

    if not user:
        return {
            'success': False,
            'error': 'INVALID_CREDENTIALS',
            'message': 'Неверный email или пароль'
        }

    if not user['is_verified']:
        return {
            'success': False,
            'error': 'EMAIL_NOT_VERIFIED',
            'message': 'Сначала верифицируйте email'
        }

    # Генерируем JWT токены
    access_token = create_access_token(user['uuid'])
    refresh_token = create_refresh_token(user['uuid'])

    return {
        'success': True,
        'user': user,
        'access_token': access_token,
        'refresh_token': refresh_token
    }
```

---

## Полный пример Repository

Полный класс репозитория с connection pooling:

```python
import asyncpg
from typing import Optional, List
import bcrypt
from datetime import datetime

class UserRepository:
    """Репозиторий для операций с пользователями используя asyncpg==0.30.0."""

    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    async def create_user(self, email: str, password_hash: str) -> Optional[dict]:
        """Создать пользователя."""
        async with self.pool.acquire() as conn:
            try:
                row = await conn.fetchrow(
                    "SELECT * FROM CREATE_USER($1, $2)",
                    email, password_hash
                )
                return dict(row) if row else None
            except asyncpg.UniqueViolationError as e:
                if 'EMAIL_EXISTS' in str(e):
                    raise EmailExistsError(f"Email {email} уже зарегистрирован")
                raise

    async def change_password(self, user_uuid: str, new_hash: str) -> bool:
        """Изменить пароль."""
        async with self.pool.acquire() as conn:
            return await conn.fetchval(
                "SELECT CHANGE_PASSWORD($1, $2)",
                user_uuid, new_hash
            )

    async def change_email(self, user_uuid: str, new_email: str) -> bool:
        """Изменить email."""
        async with self.pool.acquire() as conn:
            try:
                return await conn.fetchval(
                    "SELECT CHANGE_EMAIL($1, $2)",
                    user_uuid, new_email
                )
            except asyncpg.UniqueViolationError as e:
                if 'EMAIL_EXISTS' in str(e):
                    raise EmailExistsError(f"Email {new_email} уже используется")
                raise

    async def verify_user(self, user_uuid: str) -> bool:
        """Верифицировать пользователя."""
        async with self.pool.acquire() as conn:
            return await conn.fetchval(
                "SELECT VERIFY_USER($1)",
                user_uuid
            )

    async def find_user_by_uuid(self, user_uuid: str) -> Optional[dict]:
        """Найти по UUID."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM FIND_USER_BY_UUID($1)",
                user_uuid
            )
            return dict(row) if row else None

    async def find_user_by_email(self, email: str) -> Optional[dict]:
        """Найти по email."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM FIND_USER_BY_EMAIL($1)",
                email
            )
            return dict(row) if row else None

    async def login_user(self, email: str, password: str) -> Optional[dict]:
        """Аутентификация."""
        user = await self.find_user_by_email(email)

        if not user:
            return None

        if not bcrypt.checkpw(password.encode(), user['hash_password'].encode()):
            return None

        # Удаляем пароль из результата
        user.pop('hash_password')
        return user


# Настройка подключения
async def create_pool() -> asyncpg.Pool:
    """Создать пул подключений к БД для asyncpg==0.30.0."""
    return await asyncpg.create_pool(
        host='localhost',
        port=5432,
        user='postgres',
        password='postgres',
        database='mydb',
        min_size=10,
        max_size=20,
        command_timeout=60
    )

# Использование
pool = await create_pool()
user_repo = UserRepository(pool)
```

---

## Сводная таблица

| Функция            | Может упасть    | Возвращает данные | Изменяет БД |
| ------------------ | --------------- | ----------------- | ----------- |
| CREATE_USER        | ✅ EMAIL_EXISTS | ✅                | ✅          |
| CHANGE_PASSWORD    | ❌              | Boolean           | ✅          |
| CHANGE_EMAIL       | ✅ EMAIL_EXISTS | Boolean           | ✅          |
| VERIFY_USER        | ❌              | Boolean           | ✅          |
| UNVERIFY_USER      | ❌              | Boolean           | ✅          |
| FIND_USER_BY_UUID  | ❌              | ✅                | ❌          |
| FIND_USER_BY_EMAIL | ❌              | ✅                | ❌          |
| LOGIN_USER         | ❌              | ✅                | ❌          |
