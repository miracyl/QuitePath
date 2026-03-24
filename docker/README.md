# Docker конфигурация

Эта директория содержит конфигурационные файлы для Docker контейнеров.

## Структура

```
docker/
└── pgadmin/
    └── servers.json  # Автоматическая конфигурация серверов для pgAdmin
```

## servers.json

Этот файл автоматически добавляет подключение к PostgreSQL в pgAdmin при первом запуске.

Параметры:

- **Host**: `postgres` - имя сервиса из docker-compose.yml
- **Port**: `5432` - стандартный порт PostgreSQL
- **MaintenanceDB**: `postgres` - база данных по умолчанию
- **Username**: `postgres` - пользователь БД

## Изменение конфигурации

Если вы хотите изменить параметры подключения, отредактируйте `servers.json` перед первым запуском контейнеров.

После изменения файла:

1. Остановите контейнеры: `make down`
2. Удалите volume pgAdmin: `docker volume rm postgres-database_pgadmin_data`
3. Запустите заново: `make up`
