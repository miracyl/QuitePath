# Схема Пользователей

## Архитектура Версионирования

Модуль использует паттерн **soft update** для пользователей и разрешений:

- **user_ids** - Хранит постоянный UUID пользователя
- **users** - Версионированные записи с email и паролем
- **verification_codes** - Временные коды верификации
- **user_permissions** - Версионированные разрешения

При изменении email или пароля создается новая версия записи с `is_active=TRUE`, старая деактивируется.

---

## Таблица: user_ids

Постоянное хранилище UUID пользователей.

### Колонки

| Колонка | Тип    | Ограничения      | Описание                   |
| ------- | ------ | ---------------- | -------------------------- |
| id      | SERIAL | PRIMARY KEY      | Внутренний ID пользователя |
| uuid    | UUID   | NOT NULL, UNIQUE | Внешний UUID для API       |

### SQL Определение

```sql
CREATE TABLE user_ids (
    id   SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE
);
```

---

## Таблица: users

Версионированные записи пользователей (email и пароль).

### Колонки

| Колонка         | Тип          | Ограничения  | По умолчанию | Описание                |
| --------------- | ------------ | ------------ | ------------ | ----------------------- |
| id              | SERIAL       | PRIMARY KEY  | auto         | ID версии записи        |
| user_id         | INT          | NOT NULL, FK | -            | Ссылка на user_ids.id   |
| email           | VARCHAR(255) | NOT NULL     | -            | Email пользователя      |
| hashed_password | VARCHAR(255) | NOT NULL     | -            | Хеш пароля (bcrypt)     |
| created_at      | TIMESTAMPTZ  | NOT NULL     | NOW()        | Время создания версии   |
| updated_at      | TIMESTAMPTZ  | -            | -            | Время обновления        |
| deleted_at      | TIMESTAMPTZ  | -            | -            | Время мягкого удаления  |
| verified_at     | TIMESTAMPTZ  | -            | -            | Время верификации email |
| is_verified     | BOOLEAN      | NOT NULL     | FALSE        | Статус верификации      |
| is_deleted      | BOOLEAN      | NOT NULL     | FALSE        | Флаг мягкого удаления   |
| is_active       | BOOLEAN      | NOT NULL     | TRUE         | Текущая активная версия |

### SQL Определение

```sql
CREATE TABLE users (
    id                SERIAL PRIMARY KEY,
    user_id           INT NOT NULL,
    email             VARCHAR(255) NOT NULL,
    hashed_password   VARCHAR(255) NOT NULL,
    created_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP WITH TIME ZONE,
    deleted_at        TIMESTAMP WITH TIME ZONE,
    verified_at       TIMESTAMP WITH TIME ZONE,
    is_verified       BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted        BOOLEAN NOT NULL DEFAULT FALSE,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_user
        FOREIGN KEY(user_id)
            REFERENCES user_ids(id)
            ON DELETE CASCADE
);
```

---

## Таблица: verification_codes

Временные коды верификации email с автоматическим истечением.

### Колонки

| Колонка    | Тип          | Ограничения  | По умолчанию | Описание              |
| ---------- | ------------ | ------------ | ------------ | --------------------- |
| id         | BIGSERIAL    | PRIMARY KEY  | auto         | ID кода               |
| user_id    | INT          | NOT NULL, FK | -            | Ссылка на user_ids.id |
| code       | VARCHAR(255) | NOT NULL     | -            | Код верификации       |
| created_at | TIMESTAMPTZ  | NOT NULL     | NOW()        | Время создания        |
| expires_at | TIMESTAMPTZ  | NOT NULL     | -            | Время истечения       |

### SQL Определение

```sql
CREATE TABLE verification_codes (
    id             BIGSERIAL PRIMARY KEY,
    user_id        INT NOT NULL,
    code           VARCHAR(255) NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at     TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_user
        FOREIGN KEY(user_id)
            REFERENCES user_ids(id)
            ON DELETE CASCADE
);
```

**Примечание:** Коды автоматически скрываются из представления `active_codes` после истечения `expires_at`.

---

## Таблица: user_permissions

Версионированные разрешения пользователей (26 прав доступа).

### Колонки разрешений

| Категория               | Разрешения                                                                         |
| ----------------------- | ---------------------------------------------------------------------------------- |
| Аутентификация          | can_login, can_refresh_token                                                       |
| Управление аккаунтом    | can_delete_own_account, can_edit_own_email, can_edit_own_password                  |
| Просмотр профилей       | can_view_own_profile, can_view_any_profile                                         |
| Управление подарками    | can_create_gift, can_view_own_wishlist, can_view_gift_details, can_delete_own_gift |
| Редактирование подарков | can_edit_own_gift_image, can_edit_own_gift_name, can_edit_own_gift_price           |
| Модерация подарков      | can_verify_gift, can_ban_gift, can_unban_gift, can_unverify_gift                   |
| Wishlist                | can_view_any_wishlist                                                              |
| Изображения             | can_upload_images, can_delete_images, can_view_any_images                          |
| Администрирование       | is_root, can_view_deleted_gifts, can_restore_deleted_gifts, can_view_banned_gifts  |

### Служебные поля

| Колонка    | Тип         | По умолчанию | Описание                |
| ---------- | ----------- | ------------ | ----------------------- |
| id         | BIGSERIAL   | auto         | ID версии разрешений    |
| user_id    | INT         | -            | Ссылка на user_ids.id   |
| created_at | TIMESTAMPTZ | NOW()        | Время создания версии   |
| updated_at | TIMESTAMPTZ | -            | Время обновления        |
| is_active  | BOOLEAN     | TRUE         | Текущая активная версия |

---

## Индексы

### Индексы user_ids

```sql
CREATE INDEX idx_users_uuid ON user_ids(uuid);
```

### Индексы users

```sql
-- Обычные индексы
CREATE INDEX idx_users_user_id ON users(user_id);
CREATE INDEX idx_users_email ON users(email);

-- Частичные уникальные индексы (только для is_active=TRUE)
CREATE UNIQUE INDEX idx_users_user_id_unique_active
    ON users(user_id)
    WHERE is_active = TRUE;

CREATE UNIQUE INDEX idx_users_email_unique_active
    ON users(email)
    WHERE is_active = TRUE;
```

**Примечание:** Частичные индексы обеспечивают уникальность email только для активных записей, позволяя хранить историю изменений.

### Индексы verification_codes

```sql
CREATE INDEX idx_verification_codes_user_id ON verification_codes(user_id);
CREATE INDEX idx_verification_codes_expires_at ON verification_codes(expires_at);
```

### Индексы user_permissions

```sql
CREATE INDEX idx_user_permissions_user_id ON user_permissions(user_id);

CREATE UNIQUE INDEX idx_user_permissions_user_id_unique_active
    ON user_permissions(user_id)
    WHERE is_active = TRUE;
```

---

## Представления (Views)

### active_users

Показывает только активные версии пользователей (не удаленные).

```sql
CREATE OR REPLACE VIEW active_users AS
SELECT
    u.id,
    uuid,
    user_id,
    email,
    hashed_password,
    created_at,
    updated_at,
    deleted_at,
    verified_at,
    is_verified,
    is_deleted,
    is_active
FROM users AS u
LEFT JOIN user_ids AS ui ON u.user_id = ui.id
WHERE is_active = TRUE;
```

### active_codes

Показывает только неистекшие коды верификации.

```sql
CREATE OR REPLACE VIEW active_codes AS
SELECT
    id,
    user_id,
    code,
    created_at,
    expires_at
FROM verification_codes
WHERE expires_at > NOW();
```

**Примечание:** Фильтрация по времени происходит динамически - истекшие коды автоматически исчезают из представления.

### active_permissions

Показывает только активные версии разрешений.

```sql
CREATE OR REPLACE VIEW active_permissions AS
SELECT
    id,
    user_id,
    can_login,
    can_refresh_token,
    -- ... все 26 разрешений
    created_at,
    updated_at,
    is_active
FROM user_permissions
WHERE is_active = TRUE;
```

---

## Пример данных

### История версий пользователя

```sql
-- user_ids (постоянный UUID)
 id |                 uuid
----+--------------------------------------
  1 | 550e8400-e29b-41d4-a716-446655440000

-- users (версии email/пароля)
 id | user_id |       email          | is_active | created_at
----+---------+----------------------+-----------+---------------------
  1 |       1 | old@example.com      | false     | 2026-01-28 10:00:00
  2 |       1 | current@example.com  | true      | 2026-02-04 15:30:00
```

### Коды верификации

```sql
 id | user_id |  code  | created_at          | expires_at
----+---------+--------+---------------------+---------------------
  1 |       1 | 123456 | 2026-02-04 15:30:00 | 2026-02-05 15:30:00  -- активен
  2 |       2 | 789012 | 2026-01-01 10:00:00 | 2026-01-02 10:00:00  -- истек (не в active_codes)
```

---

## Связанное

- [Функции](functions.md) - 7 функций и 7 процедур
- [Коды Ошибок](errors.md) - Обработка ошибок
- [Миграции](migrations.md) - История изменений
  | updated_at | TIMESTAMPTZ | - | - | Время обновления |
  | deleted_at | TIMESTAMPTZ | - | - | Время мягкого удаления |
  | verified_at | TIMESTAMPTZ | - | - | Время верификации email |
  | is_verified | BOOLEAN | NOT NULL | FALSE | Статус верификации |
  | is_deleted | BOOLEAN | NOT NULL | FALSE | Флаг мягкого удаления |
  | is_active | BOOLEAN | NOT NULL | TRUE | Текущая активная версия |

### SQL Определение

```sql
CREATE TABLE USERS (
    ID BIGSERIAL PRIMARY KEY,
    UUID UUID NOT NULL DEFAULT UUID_GENERATE_V4() UNIQUE,
    EMAIL VARCHAR(255) NOT NULL UNIQUE,
    HASH_PASSWORD VARCHAR(255) NOT NULL,
    CREATED_AT TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UPDATED_AT TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    IS_VERIFIED BOOLEAN NOT NULL DEFAULT FALSE
);
```

---

## Индексы

### IDX_USERS_UUID

Быстрый поиск по UUID для API операций.

```sql
CREATE INDEX IDX_USERS_UUID ON USERS(UUID);
```

**Использование:** Используется в `FIND_USER_BY_UUID`, всех операциях по UUID.

### IDX_USERS_EMAIL

Быстрый поиск по email для входа и проверки регистрации.

```sql
CREATE INDEX IDX_USERS_EMAIL ON USERS(EMAIL);
```

**Использование:** Используется в `FIND_USER_BY_EMAIL`, `LOGIN_USER`, проверках уникальности.

---

## Триггеры

### UPDATE_USERS_UPDATED_AT

Автоматически обновляет `UPDATED_AT` при любом изменении строки.

```sql
CREATE TRIGGER UPDATE_USERS_UPDATED_AT
BEFORE UPDATE ON USERS
FOR EACH ROW
EXECUTE FUNCTION UPDATE_UPDATED_AT_COLUMN();
```

**Функция триггера:**

```sql
CREATE OR REPLACE FUNCTION UPDATE_UPDATED_AT_COLUMN()
RETURNS TRIGGER AS $$
BEGIN
    NEW.UPDATED_AT = NOW();
    RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;
```

**Поведение:** Срабатывает перед любым UPDATE на таблице USERS, устанавливает UPDATED_AT в текущее время.

---

## Ограничения

### Первичный ключ

- `ID` - BIGSERIAL PRIMARY KEY

### Ограничения уникальности

- `UUID` - Должен быть уникальным для всех пользователей
- `EMAIL` - Должен быть уникальным для всех пользователей

### Ограничения NOT NULL

- `UUID`, `EMAIL`, `HASH_PASSWORD`, `CREATED_AT`, `UPDATED_AT`, `IS_VERIFIED`

---

## Пример данных

```sql
-- Пример записи пользователя
 id |                 uuid                 |       email          | hash_password | created_at          | updated_at          | is_verified
----+--------------------------------------+----------------------+---------------+---------------------+---------------------+-------------
  1 | 550e8400-e29b-41d4-a716-446655440000 | john.doe@example.com | $2a$10$...   | 2026-01-28 10:00:00 | 2026-01-28 10:00:00 | t
  2 | 6ba7b810-9dad-11d1-80b4-00c04fd430c8 | jane@example.com     | $2a$10$...   | 2026-01-28 10:15:00 | 2026-01-28 10:15:00 | f
```

---

## Соображения по хранению

- **UUID:** 16 байт на строку
- **EMAIL:** Переменная длина, макс 255 байт
- **HASH_PASSWORD:** ~60 байт (bcrypt) или ~100 байт (argon2)
- **Индексы:** Дополнительно ~32 байта на строку для обоих индексов

**Примерный размер строки:** ~350-400 байт на пользователя

---

## Связанное

- [Функции](functions.md) - Все операции с пользователями
- [Коды Ошибок](errors.md) - Обработка ошибки EMAIL_EXISTS
