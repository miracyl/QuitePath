# PostgreSQL Database Project

Профессиональная структура для управления PostgreSQL базой данных с миграциями, функциями и тестовыми данными.

📚 **[Database API Documentation →](wiki/ru/README.md)** | **[EN Version →](wiki/en/README.md)**

## 📁 Структура проекта

```
auth-db/
├── migrations/           # Миграции БД (версионированные, неизменяемые)
│   ├── up/              # Миграции применения
│   │   └── 001_add_auth.sql
│   ├── down/            # Миграции отката
│   │   └── 001_add_auth.sql
│   └── seed/            # Тестовые данные (только для dev)
│       └── 001_example_users.sql
│
├── schema/              # Snapshot текущей структуры БД (документация)
│   ├── tables/          # Определения таблиц (user_ids, users, verification_codes, user_permissions)
│   ├── indexes/         # Индексы (partial unique для is_active=TRUE)
│   ├── views/           # SQL представления (active_users, active_codes, active_permissions)
│   ├── functions/       # SQL функции (7 read-only функций)
│   └── procedures/      # SQL процедуры (7 процедур изменения данных)
│
├── scripts/             # Утилиты
│   ├── migrate.sh       # Управление миграциями
│   ├── export_schema.sh # Экспорт схемы в файлы
│   └── generate_schema.py  # Генерация schema из миграций
│
├── wiki/                # Документация
│   ├── ru/              # Русская документация
│   └── en/              # Английская документация
│
├── docker/              # Docker конфигурация
│   └── pgadmin/         # Настройки pgAdmin
│
├── db.py               # Python API для работы с БД (asyncpg)
├── docker-compose.yml   # PostgreSQL + pgAdmin
├── Makefile            # Команды для управления
└── README.md           # Этот файл
```

## 🎯 Ключевые принципы

### 1. migrations/ - Source of Truth

- ✅ Версионированные файлы (`001_название.sql`)
- ❌ **НЕЛЬЗЯ** изменять после применения
- ✅ Применяются последовательно
- ✅ Отслеживаются в `schema_migrations` таблице

### 2. schema/ - Документация

- ✅ Snapshot текущей структуры БД
- ✅ Разделено по типам (tables, views, indexes, triggers)
- ✅ Можно просмотреть БЕЗ применения к БД
- ✅ Обновляется через `make schema-generate`

### 3. functions/ & procedures/ - Переприменяемые

- ✅ Используют `CREATE OR REPLACE`
- ✅ Можно изменять напрямую
- ✅ Применяются при каждом `make local`
- ✅ Версионируются через Git

## 🚀 Быстрый старт

### Локальная разработка

```bash
# Развернуть БД с тестовыми данными
make local

# Подключиться к БД
make psql

# Остановить
make down

# Полная очистка
make clean
```

### Продакшен (CI/CD)

```bash
# Применить миграции БЕЗ seed данных
make migrate
```

## 📝 Работа с миграциями

### Создание новой миграции

```bash
# Создать новую миграцию
make create name=add_posts_table

# Результат:
# migrations/up/007_add_posts_table.sql
# migrations/down/007_add_posts_table.sql
```

### После создания миграции

```bash
# 1. Написать SQL в migrations/up/007_add_posts_table.sql
# 2. Применить локально
make clean && make local

# 3. Обновить schema/ для документации
make schema-generate

# 4. Закоммитить
git add migrations/up/007_add_posts_table.sql
git add migrations/down/007_add_posts_table.sql
git add schema/
git commit -m "feat: add posts table"
```

## 🔍 Инспекция БД

### Просмотр БЕЗ применения

```bash
# Посмотреть что будет в БД из миграций (БЕЗ применения!)
make preview

# Результат: docs/schema_from_migrations.sql
cat docs/schema_from_migrations.sql | less
```

### Просмотр структуры таблицы

```bash
# Из snapshot (БЕЗ БД)
cat schema/tables/users.sql

# Из живой БД
make table name=users
```

### Список всех таблиц

```bash
make describe
```

### Экспорт текущей схемы

```bash
# pg_dump текущей БД
make schema

# Результат: docs/schema.sql
```

## 📊 Разница: migrations/ vs schema/

| Аспект           | migrations/                           | schema/                               |
| ---------------- | ------------------------------------- | ------------------------------------- |
| **Назначение**   | Применение изменений к БД             | Документация текущей структуры        |
| **Изменяемость** | ❌ Нельзя менять после применения     | ✅ Обновляется командой               |
| **Формат**       | `001_название.sql` (версии)           | `table_name.sql` (по объектам)        |
| **Применение**   | Через `make local` или `make migrate` | Не применяется (только для просмотра) |
| **Tracking**     | `schema_migrations` таблица           | Не отслеживается                      |

## 🛠 Команды

### Docker

```bash
make local    # Развернуть локальную БД с seed данными
make down     # Остановить
make clean    # Полностью удалить
```

### Продакшен

```bash
make migrate  # Применить миграции (без seed)
```

### Миграции

```bash
make create name=название  # Создать новую миграцию
make migrate-up           # Применить следующую миграцию
make migrate-down         # Откатить последнюю миграцию
make migrate-status       # Показать статус миграций
make migrate-reset        # Откатить все и применить заново
```

### Инспекция

```bash
make preview          # Предпросмотр из миграций (БЕЗ БД!)
make schema-generate  # Обновить schema/ из текущей БД
make schema           # pg_dump текущей БД
make describe         # Список таблиц
make table name=users # Структура таблицы
make doc              # Полная документация
```

### Утилиты

```bash
make psql  # Подключиться к БД
make logs  # Показать логи
make help  # Справка
```

## 🌐 Доступ

### PostgreSQL

```
Host: localhost
Port: 5432
Database: app_db (из .env)
User: postgres (из .env)
Password: postgres (из .env)
```

### pgAdmin (Web UI)

```
URL: http://localhost:5050
Email: admin@admin.com
Password: admin
```

## 📚 Документация

- [MIGRATIONS.md](MIGRATIONS.md) - Управление миграциями (откат/накат)
- [ARCHITECTURE.md](ARCHITECTURE.md) - Детальная архитектура
- [FAQ.md](FAQ.md) - Частые вопросы
- [schema/README.md](schema/README.md) - О структуре schema/
- [QUICKSTART.md](QUICKSTART.md) - Быстрое введение

## ✏️ Типичные сценарии

### Добавить новую таблицу

```bash
# 1. Создать миграцию
make create name=add_orders

# 2. Написать SQL в migrations/up/00X_add_orders.sql
# 3. Применить
make clean && make local

# 4. Обновить документацию
make schema-generate

# 5. Закоммитить
git add migrations/ schema/
git commit -m "feat: add orders table"
```

### Изменить существующую функцию

```bash
# 1. Изменить напрямую
vi functions/users.sql

# 2. Обновить версию в комментариях
# v1.0.1: Fixed validation

# 3. Применить (функции переприменяются автоматически)
make local

# 4. Закоммитить
git add functions/users.sql
git commit -m "fix: user validation in create_user"
```

### Добавить view

```bash
# Можно в миграцию или в schema/ напрямую
# Рекомендуется: в миграцию если это часть feature

# 1. Создать миграцию
make create name=add_user_stats_view

# 2. Написать CREATE VIEW в migrations/up/00X_add_user_stats_view.sql
# 3. Применить
make clean && make local

# 4. Обновить schema/
make schema-generate
```

## 🤝 Workflow для команды

### Developer

1. Создаёт миграцию: `make create name=feature`
2. Пишет SQL
3. Тестирует: `make clean && make local`
4. Обновляет schema/: `make schema-generate`
5. Коммитит migration + schema/

### CI/CD

1. Запускает тесты на чистой БД
2. Применяет миграции: `make migrate`
3. Проверяет успешность

### Code Review

1. Смотрит изменения в migrations/
2. Проверяет down миграцию
3. Смотрит изменения в schema/ для контекста

## 📈 Преимущества этой архитектуры

✅ **migrations/** - чёткая история изменений  
✅ **schema/** - быстрый просмотр текущей структуры  
✅ **Разделение по типам** - легко найти нужное  
✅ **make preview** - видно результат БЕЗ применения  
✅ **functions/procedures/** - легко изменять  
✅ **Простой Makefile** - 2 основные команды

## 📄 Лицензия

MIT
