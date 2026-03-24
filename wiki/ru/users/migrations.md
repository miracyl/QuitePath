# История Миграций - Модуль Пользователей

История всех миграций затрагивающих модуль пользователей.

## Миграция 001: add_auth

**Создана:** 2026-01-28  
**Статус:** Применена  
**Файл:** [migrations/up/001_add_auth.sql](../../../migrations/up/001_add_auth.sql)

### Изменения

#### Расширение

- ✅ Добавлено расширение `uuid-ossp`

#### Таблица: USERS

- ✅ Создана таблица USERS
- Колонки: ID, UUID, EMAIL, HASH_PASSWORD, CREATED_AT, UPDATED_AT, IS_VERIFIED

#### Индексы

- ✅ `IDX_USERS_UUID` - Быстрый поиск по UUID
- ✅ `IDX_USERS_EMAIL` - Быстрый поиск по email

#### Триггеры

- ✅ `UPDATE_USERS_UPDATED_AT` - Автообновление updated_at
- ✅ `UPDATE_UPDATED_AT_COLUMN()` - Функция триггера

#### Функции

1. ✅ `CREATE_USER` - Регистрация нового пользователя
2. ✅ `CHANGE_PASSWORD` - Изменение пароля
3. ✅ `CHANGE_EMAIL` - Изменение email со сбросом верификации
4. ✅ `VERIFY_USER` - Пометить как верифицированного
5. ✅ `UNVERIFY_USER` - Снять верификацию
6. ✅ `FIND_USER_BY_UUID` - Получить пользователя по UUID
7. ✅ `FIND_USER_BY_EMAIL` - Получить пользователя по email
8. ✅ `LOGIN_USER` - Аутентификация пользователя

#### Коды ошибок

- ✅ `EMAIL_EXISTS` - Добавлен в CREATE_USER
- ✅ `EMAIL_EXISTS` - Добавлен в CHANGE_EMAIL

### Тестовые данные

**Файл:** [migrations/seed/001_example_users.sql](../../../migrations/seed/001_example_users.sql)

Созданы 3 тестовых пользователя:

- admin@example.com
- user@example.com
- test@example.com

---

## Будущие миграции

Будущие изменения модуля пользователей будут документированы здесь.

Планируемые функции:

- Токены сброса пароля
- Двухфакторная аутентификация
- Роли и права пользователей
- Отслеживание попыток входа
- Приостановка аккаунтов
