# API Документация Базы Данных

Полный справочник по всем модулям базы данных, схемам, функциям и процедурам.

## 📦 Модули

### 1. [Пользователи](users/README.md)

Система аутентификации и управления пользователями.

- Регистрация и вход пользователей
- Верификация email
- Управление паролями
- 8 функций для работы с пользователями

---

## Краткая информация

- **Версия PostgreSQL:** 16 Alpine
- **Расширения:** uuid-ossp
- **Система миграций:** Bash с автоматической регистрацией
- **Обработка ошибок:** Коды ошибок через HINT для уровня приложения

## Быстрый старт

```bash
# Запустить базу данных
make local

# Проверить статус миграций
make migrate-status

# Сгенерировать документацию схемы
make schema-generate
```

### Таблица Users

Таблица аутентификации, хранящая учетные данные и статус верификации пользователей.

| Колонка       | Тип          | Описание                      |
| ------------- | ------------ | ----------------------------- |
| ID            | BIGSERIAL    | Первичный ключ, автоинкремент |
| UUID          | UUID         | Уникальный идентификатор (v4) |
| EMAIL         | VARCHAR(255) | Уникальный email пользователя |
| HASH_PASSWORD | VARCHAR(255) | Хеш пароля (bcrypt/argon2)    |
| CREATED_AT    | TIMESTAMPTZ  | Время регистрации             |
| UPDATED_AT    | TIMESTAMPTZ  | Время последнего обновления   |
| IS_VERIFIED   | BOOLEAN      | Статус верификации email      |

**Индексы:**

- `IDX_USERS_UUID` - Быстрый поиск по UUID
- `IDX_USERS_EMAIL` - Быстрый поиск по email

**Триггеры:**

- `UPDATE_USERS_UPDATED_AT` - Автообновление `updated_at` при изменении строки

## Функции

### CREATE_USER

Создает нового пользователя с email и хешем пароля.

**Параметры:**

- `P_EMAIL` (VARCHAR) - Email пользователя
- `P_HASH_PASSWORD` (VARCHAR) - Хеш пароля

**Возвращает:**

```sql
TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    CREATED_AT TIMESTAMPTZ
)
```

**Ошибки:**

- `EMAIL_EXISTS` (SQLSTATE 23505) - Email уже зарегистрирован

**Пример:**

```sql
SELECT * FROM CREATE_USER('user@example.com', '$2a$10$...');
```

---

### CHANGE_PASSWORD

Изменяет пароль пользователя по UUID.

**Параметры:**

- `P_UUID` (UUID) - UUID пользователя
- `P_NEW_HASH_PASSWORD` (VARCHAR) - Новый хеш пароля

**Возвращает:** `BOOLEAN` - `true` при успехе, `false` если пользователь не найден

**Пример:**

```sql
SELECT CHANGE_PASSWORD('550e8400-e29b-41d4-a716-446655440000', '$2a$10$...');
```

---

### CHANGE_EMAIL

Изменяет email пользователя и сбрасывает статус верификации.

**Параметры:**

- `P_UUID` (UUID) - UUID пользователя
- `P_NEW_EMAIL` (VARCHAR) - Новый email

**Возвращает:** `BOOLEAN` - `true` при успехе, `false` если пользователь не найден

**Ошибки:**

- `EMAIL_EXISTS` (SQLSTATE 23505) - Email уже используется

**Пример:**

```sql
SELECT CHANGE_EMAIL('550e8400-e29b-41d4-a716-446655440000', 'newemail@example.com');
```

---

### VERIFY_USER

Помечает пользователя как верифицированного.

**Параметры:**

- `P_UUID` (UUID) - UUID пользователя

**Возвращает:** `BOOLEAN` - `true` при успехе, `false` если пользователь не найден

**Пример:**

```sql
SELECT VERIFY_USER('550e8400-e29b-41d4-a716-446655440000');
```

---

### UNVERIFY_USER

Помечает пользователя как неверифицированного.

**Параметры:**

- `P_UUID` (UUID) - UUID пользователя

**Возвращает:** `BOOLEAN` - `true` при успехе, `false` если пользователь не найден

**Пример:**

```sql
SELECT UNVERIFY_USER('550e8400-e29b-41d4-a716-446655440000');
```

---

### FIND_USER_BY_UUID

Получает пользователя по UUID.

**Параметры:**

- `P_UUID` (UUID) - UUID пользователя

**Возвращает:**

```sql
TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    HASH_PASSWORD VARCHAR(255),
    CREATED_AT TIMESTAMPTZ,
    UPDATED_AT TIMESTAMPTZ,
    IS_VERIFIED BOOLEAN
)
```

**Пример:**

```sql
SELECT * FROM FIND_USER_BY_UUID('550e8400-e29b-41d4-a716-446655440000');
```

---

### FIND_USER_BY_EMAIL

Получает пользователя по email.

**Параметры:**

- `P_EMAIL` (VARCHAR) - Email пользователя

**Возвращает:**

```sql
TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    HASH_PASSWORD VARCHAR(255),
    CREATED_AT TIMESTAMPTZ,
    UPDATED_AT TIMESTAMPTZ,
    IS_VERIFIED BOOLEAN
)
```

**Пример:**

```sql
SELECT * FROM FIND_USER_BY_EMAIL('user@example.com');
```

---

### LOGIN_USER

Аутентифицирует пользователя по email и паролю.

**Параметры:**

- `P_EMAIL` (VARCHAR) - Email пользователя
- `P_HASH_PASSWORD` (VARCHAR) - Хеш пароля

**Возвращает:**

```sql
TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    IS_VERIFIED BOOLEAN,
    CREATED_AT TIMESTAMPTZ
)
```

**Возвращает пустой результат если учетные данные неверны.**

**Пример:**

```sql
SELECT * FROM LOGIN_USER('user@example.com', '$2a$10$...');
```

## Коды ошибок

Все ошибки базы данных используют механизм EXCEPTION PostgreSQL с кодами в поле HINT для уровня приложения.

### EMAIL_EXISTS

- **SQL State:** 23505 (UNIQUE_VIOLATION)
- **Код Hint:** `EMAIL_EXISTS`
- **Сообщение:** "Email conflict"
- **Функции:** `CREATE_USER`, `CHANGE_EMAIL`
- **Причина:** Email уже зарегистрирован в системе

**Обработка в приложении:**

```python
try:
    result = execute("SELECT * FROM CREATE_USER(%s, %s)", email, hash_pwd)
except psycopg2.Error as e:
    if e.pgcode == '23505' and 'EMAIL_EXISTS' in str(e):
        return {"error": "Email уже зарегистрирован"}
```

## Система миграций

### Структура

```
migrations/
├── up/          # Миграции вперед
├── down/        # Откат миграций
└── seed/        # Тестовые данные (привязаны к версиям)
```

### Создание миграций

```bash
make migrate name=add_profiles
# Создает:
# - migrations/up/002_add_profiles.sql
# - migrations/down/002_add_profiles.sql
```

**Шаблон миграции:**

```sql
BEGIN;

-- Ваш SQL код здесь

INSERT INTO SCHEMA_MIGRATIONS (VERSION, NAME)
VALUES ('002', 'add_profiles');

COMMIT;
```

### Правила

1. Миграции **неизменяемы** - никогда не редактируйте примененные миграции
2. Каждая миграция автоматически регистрируется в таблице `schema_migrations`
3. Формат версии: 3-значное число (001, 002, 003...)
4. Down миграции должны полностью откатывать up миграцию
5. Всегда оборачивайте в транзакцию BEGIN/COMMIT

## Тестовые данные

Тестовые данные привязаны к конкретным версиям миграций.

### Создание seed файлов

```bash
# Создать migrations/seed/002_example_profiles.sql
```

**Пример:**

```sql
-- Тестовые данные для миграции 002
INSERT INTO profiles (user_id, bio) VALUES
(1, 'Тестовое описание'),
(2, 'Еще одно описание');
```

### Правила

1. Seed файлы именуются `{VERSION}_description.sql`
2. Применяются автоматически после соответствующей миграции
3. Используются только в разработке (`make local`)
4. Не применяются в продакшен окружениях
5. Данные должны быть минимальными и реалистичными

### Применение

Тестовые данные применяются автоматически при запуске:

```bash
make local  # Применяет миграции + seed файлы
```
