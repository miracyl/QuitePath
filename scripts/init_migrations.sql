-- Создание таблицы для отслеживания миграций
create table if not exists schema_migrations (
   id                serial primary key,
   version           varchar(255) not null unique,
   name              varchar(255) not null,
   applied_at        timestamp with time zone not null default now(),
   execution_time_ms integer,
   checksum          varchar(64)
);

-- Индекс для быстрого поиска версий
create index if not exists idx_schema_migrations_version on
   schema_migrations (
      version
   );

-- Комментарии
comment on table schema_migrations is
   'Таблица для отслеживания примененных миграций';
comment on column schema_migrations.version is
   'Номер версии миграции (например, 001, 002)';
comment on column schema_migrations.name is
   'Название миграции';
comment on column schema_migrations.applied_at is
   'Время применения миграции';
comment on column schema_migrations.execution_time_ms is
   'Время выполнения миграции в миллисекундах';
comment on column schema_migrations.checksum is
   'Контрольная сумма файла миграции';