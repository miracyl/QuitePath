# Scripts - Утилиты для работы с БД

## Файлы

### init_migrations.sql

**Назначение:** Инициализация системы миграций (создание таблицы schema_migrations)

**Когда применяется:**

- Автоматически при `make local` (перед всеми миграциями)
- Один раз при первом запуске БД

**Откат:** ❌ НЕ откатывается (базовая инфраструктура)

**Содержимое:**

- Создание таблицы `schema_migrations`
- Индексы для быстрого поиска
- Комментарии к таблице

### migrate.sh

**Назначение:** Управление миграциями на продакшене

**Команды:**

```bash
./scripts/migrate.sh migrate    # Применить все миграции
./scripts/migrate.sh rollback   # Откатить последнюю
./scripts/migrate.sh status     # Показать статус
./scripts/migrate.sh create name # Создать новую миграцию
```

### generate_schema.py

**Назначение:** Генерация предпросмотра схемы БД из миграций

**Использование:**

```bash
make preview
# или напрямую
python3 scripts/generate_schema.py
```

**Результат:** Создаёт `docs/schema_from_migrations.sql`

## Разница: init vs миграции

| Аспект         | init_migrations.sql    | migrations/up/001-00X.sql |
| -------------- | ---------------------- | ------------------------- |
| **Откат**      | ❌ Нельзя              | ✅ Можно через down/      |
| **Tracking**   | -                      | ✅ В schema_migrations    |
| **Применение** | Один раз при старте    | Последовательно           |
| **Назначение** | Базовая инфраструктура | Изменения схемы           |

## Порядок применения

1. **init_migrations.sql** - создаёт таблицу schema_migrations
2. **migrations/up/002-00X.sql** - применяются в порядке версий
3. **functions/** - CREATE OR REPLACE
4. **procedures/** - CREATE OR REPLACE
5. **migrations/data/** - с tracking в data_migrations
6. **seed/** - тестовые данные (только dev)

## Почему 001 вынесена в init?

**Проблема:** Миграция 001 создаёт таблицу `schema_migrations`, которая нужна для tracking всех миграций.

**Решение:** Вынести её в отдельный init скрипт:

- ✅ Применяется всегда первой
- ✅ Не попадает в список миграций для отката
- ✅ Невозможно случайно откатить
- ✅ Чистая концепция: init != migration

## Как это работает в Makefile

```makefile
local:
    # 0. Создание БД
    CREATE DATABASE app_db;

    # 1. Init (создание schema_migrations)
    < scripts/init_migrations.sql

    # 2. Миграции (002, 003, ...) с автоматическим tracking
    for migration in 002-00X:
        psql < migrations/up/${migration}.sql
        INSERT INTO schema_migrations (version, name, duration)

    # 3. Функции, процедуры, данные, seed...
```

## Обновление init_migrations.sql

❌ **Не меняй этот файл!** Он уже применён в существующих БД.

Если нужны изменения в schema_migrations:

1. Создай миграцию: `make create name=alter_schema_migrations`
2. Напиши ALTER TABLE в migrations/up/00X\_...
3. Примени: `make migrate-up`
