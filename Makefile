-include .env.local
export
.PHONY: help migrate deploy init-roles local down clean create migrate-up migrate-down migrate-status migrate-reset seed seed-reset schema describe table erd doc preview schema-generate psql logs

# Цвета для вывода
BOLD   := \033[1m
GREEN  := \033[0;32m
CYAN   := \033[0;36m
BLUE   := \033[0;34m
YELLOW := \033[1;33m
PURPLE := \033[0;35m
RED    := \033[0;31m
NC     := \033[0m

# Загрузка переменных из .env
ifneq (,$(wildcard .env))
    include .env
    export
endif

help: ## Показать справку
	@echo ""
	@echo "$(BOLD)$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BOLD)$(CYAN)║$(NC)  $(BOLD)$(PURPLE)🗄️  PostgreSQL Database Management$(NC)                                $(BOLD)$(CYAN)║$(NC)"
	@echo "$(BOLD)$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(BOLD)$(BLUE)╭─────────────────────────────────────────────────────────────────╮$(NC)"
	@echo "$(BOLD)$(BLUE)│$(NC) 🐳 $(BOLD)Docker Commands$(NC)                                              $(BOLD)$(BLUE)│$(NC)"
	@echo "$(BOLD)$(BLUE)╰─────────────────────────────────────────────────────────────────╯$(NC)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make local$(NC)           Развернуть локальную копию БД с seed данными"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make down$(NC)            Остановить локальную БД"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make clean$(NC)           Удалить локальную БД полностью"
	@echo ""
	@echo "$(BOLD)$(BLUE)╭─────────────────────────────────────────────────────────────────╮$(NC)"
	@echo "$(BOLD)$(BLUE)│$(NC) 🚀 $(BOLD)Production Commands$(NC)                                          $(BOLD)$(BLUE)│$(NC)"
	@echo "$(BOLD)$(BLUE)╰─────────────────────────────────────────────────────────────────╯$(NC)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make migrate$(NC)         Применить миграции на основную БД (для CI/CD)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make deploy$(NC)          Миграции + обновить права/роли"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make init-roles$(NC)      Сгенерировать scripts/init_roles.sql"
	@echo ""
	@echo "$(BOLD)$(BLUE)╭─────────────────────────────────────────────────────────────────╮$(NC)"
	@echo "$(BOLD)$(BLUE)│$(NC) 📝 $(BOLD)Migration Commands$(NC)                                           $(BOLD)$(BLUE)│$(NC)"
	@echo "$(BOLD)$(BLUE)╰─────────────────────────────────────────────────────────────────╯$(NC)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make create$(NC)          Создать новую миграцию $(CYAN)(name=имя)$(NC)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make migrate-up$(NC)      Применить следующую миграцию (локально)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make migrate-down$(NC)    Откатить последнюю миграцию (локально)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make migrate-status$(NC)  Показать статус миграций"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make migrate-reset$(NC)   Откатить все и применить заново"
	@echo ""
	@echo "$(BOLD)$(BLUE)╭─────────────────────────────────────────────────────────────────╮$(NC)"
	@echo "$(BOLD)$(BLUE)│$(NC) 🌱 $(BOLD)Seed Data Commands$(NC)                                           $(BOLD)$(BLUE)│$(NC)"
	@echo "$(BOLD)$(BLUE)╰─────────────────────────────────────────────────────────────────╯$(NC)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make seed$(NC)            Применить все seed данные к текущей БД"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make seed-reset$(NC)      Очистить все тестовые данные из БД"
	@echo ""
	@echo "$(BOLD)$(BLUE)╭─────────────────────────────────────────────────────────────────╮$(NC)"
	@echo "$(BOLD)$(BLUE)│$(NC) 🔍 $(BOLD)Inspection & Documentation$(NC)                                   $(BOLD)$(BLUE)│$(NC)"
	@echo "$(BOLD)$(BLUE)╰─────────────────────────────────────────────────────────────────╯$(NC)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make preview$(NC)         Предпросмотр схемы из миграций $(CYAN)(БЕЗ БД!)$(NC)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make schema-generate$(NC) Обновить schema/ из текущей БД"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make schema$(NC)          Экспорт текущей структуры (pg_dump)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make describe$(NC)        Показать список таблиц"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make table$(NC)           Показать структуру таблицы $(CYAN)(name=имя)$(NC)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make doc$(NC)             Сгенерировать документацию БД"
	@echo ""
	@echo "$(BOLD)$(BLUE)╭─────────────────────────────────────────────────────────────────╮$(NC)"
	@echo "$(BOLD)$(BLUE)│$(NC) 🛠️  $(BOLD)Utility Commands$(NC)                                             $(BOLD)$(BLUE)│$(NC)"
	@echo "$(BOLD)$(BLUE)╰─────────────────────────────────────────────────────────────────╯$(NC)"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make psql$(NC)            Подключиться к БД"
	@echo "  $(GREEN)❯$(NC) $(YELLOW)make logs$(NC)            Показать логи"
	@echo ""
	@echo "$(BOLD)$(PURPLE)═══════════════════════════════════════════════════════════════════$(NC)"
	@echo ""

# 1. Применение миграций на основную БД (для CI/CD)
migrate: ## Применить миграции на основную БД
	@echo "$(GREEN)Применение миграций на основную БД...$(NC)"
	@./scripts/migrate.sh migrate
	@echo "$(GREEN)✓ Миграции применены (seed данные НЕ применяются на продакшене)$(NC)"

deploy: migrate ## Миграции + обновить права/роли
	@echo "$(GREEN)Обновление прав и ролей...$(NC)"
	@$(MAKE) init-roles
	@bash -c 'export PGPASSWORD="$$DEPLOY_PASSWORD"; psql -h $(DB_HOST) -p $(DB_PORT) -U $(DEPLOY_USER) -d postgres -f scripts/init_roles.sql'
	@echo "$(GREEN)✓ Деплой завершен$(NC)"

init-roles: ## Сгенерировать scripts/init_roles.sql
	@bash scripts/render_init_roles.sh

# 2. Локальная разработка с Docker
local: ## Развернуть локальную БД с миграциями и seed данными
	@echo "$(GREEN)Запуск локальной БД...$(NC)"
	@docker-compose up -d
	@echo "Ожидание запуска PostgreSQL..."
	@sleep 5
	@echo "$(GREEN)Создание базы данных...$(NC)"
	@docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE $(DB_NAME);" 2>/dev/null || echo "БД уже существует"
	@echo "$(GREEN)0️⃣  Инициализация (schema_migrations)...$(NC)"
	@docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < scripts/init_migrations.sql || exit 1
	@echo "$(GREEN)1️⃣  Применение миграций...$(NC)"
	@for file in migrations/up/*.sql; do \
		VERSION=$$(basename $$file .sql | cut -d_ -f1); \
		NAME=$$(basename $$file .sql | cut -d_ -f2-); \
		echo "  → $$VERSION: $$NAME"; \
		docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file || exit 1; \
		for seed_file in migrations/seed/$${VERSION}_*.sql; do \
			if [ -f "$$seed_file" ]; then \
				echo "    ↳ Применение seed данных для $$VERSION"; \
				docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$seed_file || exit 1; \
			fi; \
		done; \
	done
	@echo "$(GREEN)2️⃣  Применение функций...$(NC)"
	@for file in functions/*.sql; do \
		if [ -f "$$file" ]; then \
			echo "  → $$(basename $$file)"; \
			docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file || exit 1; \
		fi; \
	done
	@echo "$(GREEN)3️⃣  Применение процедур...$(NC)"
	@for file in procedures/*.sql; do \
		if [ -f "$$file" ]; then \
			echo "  → $$(basename $$file)"; \
			docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file || exit 1; \
		fi; \
	done
	@echo "$(GREEN)4️⃣  Применение data миграций...$(NC)"
	@for file in migrations/data/*.sql; do \
		if [ -f "$$file" ] && [ "$${file##*.}" = "sql" ] && [ "$$(basename $$file)" != "*.example" ]; then \
			filename=$$(basename "$$file"); \
			echo "  Проверка $$filename..."; \
			applied=$$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT COUNT(*) FROM data_migrations WHERE filename = '$$filename';" 2>/dev/null | tr -d ' '); \
			if [ "$$applied" = "0" ] || [ -z "$$applied" ]; then \
				echo "  → Применение $$filename"; \
				docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file || exit 1; \
				docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -c "INSERT INTO data_migrations (filename) VALUES ('$$filename');" > /dev/null; \
			else \
				echo "  ✓ $$filename уже применена"; \
			fi; \
		fi; \
	done
	@echo ""
	@echo "$(GREEN)✓ Локальная БД готова!$(NC)"
	@echo ""
	@echo "PostgreSQL: localhost:5432"
	@echo "  Database: $(DB_NAME)"
	@echo "  User: $(DB_USER)"
	@echo "  Password: $(DB_PASSWORD)"
	@echo ""
	@echo "pgAdmin: http://localhost:5050"
	@echo "  Email: admin@admin.com"
	@echo "  Password: admin"
	@echo ""
	@echo "Подключиться к БД: make psql"

down: ## Остановить локальную БД
	@docker-compose down
	@echo "$(GREEN)✓ Локальная БД остановлена$(NC)"

clean: ## Удалить локальную БД полностью
	@docker-compose down -v
	@echo "$(GREEN)✓ Локальная БД удалена$(NC)"

# Дополнительные утилиты
test-python: ## Запустить тесты Python SDK (pytest)
	@echo "$(GREEN)Запуск тестов Python SDK...$(NC)"
	cd sdk/python && pytest tests/

psql: ## Подключиться к локальной БД
	@docker-compose exec postgres psql -U $(DB_USER) -d $(DB_NAME)

logs: ## Показать логи
	@docker-compose logs -f

create: ## Создать новую миграцию (make create name=имя)
	@if [ -z "$(name)" ]; then \
		echo "Использование: make create name=имя_миграции"; \
		exit 1; \
	fi
	@./scripts/migrate.sh create $(name)
	@echo "$(GREEN)✓ Миграция создана$(NC)"

# Управление миграциями на локальной БД
migrate-up: ## Применить следующую миграцию на локальной БД
	@echo "$(GREEN)Применение следующей миграции...$(NC)"
	@# Получаем список применённых миграций
	@APPLIED=$$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null | tr -d ' \n' | tr '\n' '|'); \
	NEXT=""; \
	for file in migrations/up/*.sql; do \
		VERSION=$$(basename $$file .sql | cut -d_ -f1); \
		if ! echo "$$APPLIED" | grep -q "$$VERSION"; then \
			NEXT=$$file; \
			break; \
		fi; \
	done; \
	if [ -z "$$NEXT" ]; then \
		echo "$(YELLOW)Нет миграций для применения$(NC)"; \
		exit 0; \
	fi; \
	VERSION=$$(basename $$NEXT .sql | cut -d_ -f1); \
	NAME=$$(basename $$NEXT .sql | cut -d_ -f2-); \
	echo "Применение миграции: $$VERSION - $$NAME"; \
	if docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$NEXT; then \
		echo "$(GREEN)✓ Миграция $$VERSION применена$(NC)"; \
	else \
		echo "$(YELLOW)Ошибка при применении миграции $$VERSION$(NC)"; \
		exit 1; \
	fi
	@echo "Статус: make migrate-status"

migrate-down: ## Откатить последнюю миграцию на локальной БД
	@echo "$(YELLOW)Откат последней миграции...$(NC)"
	@echo "Последняя применённая миграция:"
	@docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT version, name FROM schema_migrations ORDER BY applied_at DESC LIMIT 1;"
	@echo ""
	@read -p "Вы уверены? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		VERSION=$$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT version FROM schema_migrations ORDER BY applied_at DESC LIMIT 1;" | tr -d ' \n'); \
		if [ -z "$$VERSION" ]; then \
			echo "$(YELLOW)Нет миграций для отката$(NC)"; \
		else \
			echo "$(GREEN)Откатываем миграцию $$VERSION...$(NC)"; \
			DOWNFILE=$$(ls migrations/down/$${VERSION}_*.sql 2>/dev/null | head -n 1); \
			if [ -n "$$DOWNFILE" ] && [ -f "$$DOWNFILE" ]; then \
				docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < "$$DOWNFILE"; \
				echo "$(GREEN)✓ Миграция $$VERSION откачена$(NC)"; \
			else \
				echo "$(YELLOW)Файл отката не найден для версии $$VERSION$(NC)"; \
			fi; \
		fi; \
	else \
		echo "Отменено"; \
	fi

migrate-status: ## Показать статус миграций
	@echo "$(GREEN)Статус миграций:$(NC)"
	@echo ""
	@echo "📊 Применённые миграции:"
	@docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -c "SELECT version, name, applied_at, execution_time_ms || ' ms' as duration FROM schema_migrations ORDER BY version;" 2>/dev/null || echo "Таблица schema_migrations не существует. Запустите: make local"
	@echo ""
	@echo "📁 Доступные миграции:"
	@for file in migrations/up/*.sql; do \
		VERSION=$$(basename $$file .sql | cut -d_ -f1); \
		NAME=$$(basename $$file .sql | cut -d_ -f2-); \
		if [ "$$VERSION" = "001" ]; then \
			echo "  001 (init) - $$NAME"; \
		else \
			echo "  $$VERSION - $$NAME"; \
		fi; \
	done

migrate-reset: ## Откатить все миграции и применить заново
	@echo "$(YELLOW)⚠️  ВНИМАНИЕ: Это удалит ВСЕ данные!$(NC)"
	@read -p "Вы уверены? Введите 'yes' для подтверждения: " -r; \
	echo ""; \
	if [ "$$REPLY" = "yes" ]; then \
		echo "$(GREEN)Откат всех миграций...$(NC)"; \
		while true; do \
			VERSION=$$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT version FROM schema_migrations ORDER BY applied_at DESC LIMIT 1;" | tr -d ' \n'); \
			if [ -z "$$VERSION" ]; then \
				break; \
			fi; \
			echo "Откатываем $$VERSION..."; \
			DOWNFILE="migrations/down/$${VERSION}.sql"; \
			if [ -f "$$DOWNFILE" ]; then \
				docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < "$$DOWNFILE" 2>/dev/null || true; \
				docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -c "DELETE FROM schema_migrations WHERE version = '$$VERSION';" 2>/dev/null || true; \
			fi; \
		done; \
		echo "$(GREEN)Применение всех миграций заново...$(NC)"; \
		$(MAKE) local; \
		echo "$(GREEN)✓ Reset выполнен$(NC)"; \
	else \
		echo "Отменено"; \
	fi

# Работа с seed данными
seed: ## Применить seed данные для установленных миграций
	@echo "$(GREEN)🌱 Применение seed данных для установленных миграций...$(NC)"
	@APPLIED=$$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null | tr -d ' \n' | tr '\n' ' '); \
	if [ -z "$$APPLIED" ]; then \
		echo "$(YELLOW)Нет установленных миграций$(NC)"; \
		exit 0; \
	fi; \
	COUNT=0; \
	for VERSION in $$APPLIED; do \
		for file in migrations/seed/$${VERSION}_*.sql; do \
			if [ -f "$$file" ]; then \
				echo "  → $$(basename $$file)"; \
				if docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file 2>&1 | grep -v "already exists" | grep -v "duplicate key"; then \
					COUNT=$$((COUNT + 1)); \
				fi; \
			fi; \
		done; \
	done; \
	if [ $$COUNT -eq 0 ]; then \
		echo "$(YELLOW)Seed файлы не найдены или уже применены$(NC)"; \
	else \
		echo "$(GREEN)✓ Применено seed файлов: $$COUNT$(NC)"; \
	fi

seed-reset: ## Очистить все тестовые данные из БД
	@echo "$(YELLOW)⚠️  Удаление всех данных из таблиц (структура сохранится)...$(NC)"
	@read -p "Вы уверены? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(GREEN)Очистка таблиц...$(NC)"; \
		docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -c "\
			DO \$$\$$ \
			DECLARE \
				r RECORD; \
			BEGIN \
				FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename != 'schema_migrations') LOOP \
					EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.tablename) || ' RESTART IDENTITY CASCADE'; \
					RAISE NOTICE 'Таблица % очищена', r.tablename; \
				END LOOP; \
			END \$$\$$;"; \
		echo "$(GREEN)✓ Все данные удалены (структура сохранена)$(NC)"; \
		echo "Для повторного добавления seed: make seed"; \
	else \
		echo "Отменено"; \
	fi

# Инспекция и документация
schema: ## Сгенерировать schema.sql (текущая структура БД)
	@echo "$(GREEN)Генерация schema.sql...$(NC)"
	@mkdir -p docs
	@docker-compose exec -T postgres pg_dump -U $(DB_USER) -d $(DB_NAME) --schema-only --no-owner --no-privileges > docs/schema.sql
	@echo "$(GREEN)✓ Схема сохранена в docs/schema.sql$(NC)"

describe: ## Показать структуру всех таблиц
	@echo "$(GREEN)Структура таблиц в БД:$(NC)"
	@echo ""
	@docker-compose exec postgres psql -U $(DB_USER) -d $(DB_NAME) -c "\
		SELECT \
			table_name, \
			(SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as columns, \
			pg_size_pretty(pg_total_relation_size(table_name::regclass)) as size \
		FROM information_schema.tables t \
		WHERE table_schema = 'public' AND table_type = 'BASE TABLE' \
		ORDER BY table_name;"
	@echo ""
	@echo "Детали таблицы: make table name=имя_таблицы"

table: ## Показать структуру конкретной таблицы (make table name=users)
	@if [ -z "$(name)" ]; then \
		echo "Использование: make table name=имя_таблицы"; \
		exit 1; \
	fi
	@docker-compose exec postgres psql -U $(DB_USER) -d $(DB_NAME) -c "\d+ $(name)"

erd: ## Сгенерировать ER-диаграмму (требует python3)
	@echo "$(GREEN)Генерация ER-диаграммы...$(NC)"
	@if ! command -v python3 > /dev/null; then \
		echo "$(YELLOW)Требуется python3. Установите: brew install python3$(NC)"; \
		exit 1; \
	fi
	@mkdir -p docs
	@docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -c "\
		SELECT \
			tc.table_name, \
			kcu.column_name, \
			ccu.table_name AS foreign_table_name, \
			ccu.column_name AS foreign_column_name \
		FROM information_schema.table_constraints AS tc \
		JOIN information_schema.key_column_usage AS kcu \
			ON tc.constraint_name = kcu.constraint_name \
		JOIN information_schema.constraint_column_usage AS ccu \
			ON ccu.constraint_name = tc.constraint_name \
		WHERE tc.constraint_type = 'FOREIGN KEY';" > docs/relationships.txt
	@echo "$(GREEN)✓ Связи сохранены в docs/relationships.txt$(NC)"

doc: schema ## Сгенерировать полную документацию БД
	@echo "$(GREEN)Генерация документации...$(NC)"
	@mkdir -p docs
	@echo "# Database Schema Documentation" > docs/DATABASE.md
	@echo "" >> docs/DATABASE.md
	@echo "Generated: $$(date)" >> docs/DATABASE.md
	@echo "" >> docs/DATABASE.md
	@echo "## Tables" >> docs/DATABASE.md
	@echo "" >> docs/DATABASE.md
	@docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "\
		SELECT '### ' || table_name || E'\n' || \
		       E'\n**Description:** ' || obj_description((table_schema||'.'||table_name)::regclass) || E'\n' || \
		       E'\n**Columns:**\n' || \
		       string_agg('- `' || column_name || '` (' || data_type || ')' || \
		                  CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END, E'\n' ORDER BY ordinal_position) \
		FROM information_schema.columns \
		WHERE table_schema = 'public' AND table_name IN \
		      (SELECT tablename FROM pg_tables WHERE schemaname = 'public') \
		GROUP BY table_schema, table_name;" >> docs/DATABASE.md 2>/dev/null || echo "No tables yet" >> docs/DATABASE.md
	@echo "" >> docs/DATABASE.md
	@echo "$(GREEN)✓ Документация сохранена в docs/DATABASE.md$(NC)"

preview: ## Предпросмотр схемы БД из миграций (БЕЗ применения!)
	@echo "$(GREEN)Генерация предпросмотра схемы из миграций...$(NC)"
	@python3 scripts/generate_schema.py
	@echo ""
	@echo "Файлы созданы:"
	@echo "  📄 docs/schema_from_migrations.sql - Полная схема из миграций"
	@echo ""
	@echo "Просмотр: cat docs/schema_from_migrations.sql | less"

schema-generate: ## Обновить schema/ из текущего состояния БД
	@echo "$(GREEN)Генерация schema/ из текущей БД...$(NC)"
	@rm -rf schema/tables/* schema/indexes/* schema/views/* schema/triggers/* schema/functions/* schema/procedures/* 2>/dev/null || true
	@mkdir -p schema/tables schema/indexes schema/views schema/triggers schema/functions schema/procedures
	@echo "$(GREEN)Экспорт таблиц...$(NC)"
	@for table in $$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;" | tr -d ' \r'); do \
		if [ -n "$$table" ]; then \
			echo "  → $$table"; \
			docker-compose exec -T postgres pg_dump -U $(DB_USER) -d $(DB_NAME) --schema-only --no-owner --no-privileges -t $$table 2>/dev/null > schema/tables/$$table.sql || true; \
		fi; \
	done
	@./scripts/export_schema.sh $(DB_USER) $(DB_NAME)
	@echo "$(GREEN)Экспорт триггеров...$(NC)"
	@for trigger in $$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT tgname FROM pg_trigger WHERE tgisinternal = false ORDER BY tgname;" 2>/dev/null | tr -d ' \r'); do \
		if [ -n "$$trigger" ]; then \
			echo "  → $$trigger"; \
			table=$$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT c.relname FROM pg_trigger t JOIN pg_class c ON t.tgrelid = c.oid WHERE t.tgname = '$$trigger';" | tr -d ' \r'); \
			docker-compose exec -T postgres pg_dump -U $(DB_USER) -d $(DB_NAME) --schema-only --no-owner --no-privileges -t $$table 2>/dev/null | grep -A 20 "CREATE TRIGGER $$trigger" > schema/triggers/$${table}_$${trigger}.sql || true; \
		fi; \
	done
	@echo "$(GREEN)Экспорт индексов...$(NC)"
	@for table in $$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;" | tr -d ' \r'); do \
		if [ -n "$$table" ]; then \
			indexes=$$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND tablename = '$$table' AND indexname NOT LIKE '%_pkey';" 2>/dev/null | tr -d ' \r'); \
			if [ -n "$$indexes" ]; then \
				echo "  → $$table indexes"; \
				docker-compose exec -T postgres pg_dump -U $(DB_USER) -d $(DB_NAME) --schema-only --no-owner --no-privileges -t $$table 2>/dev/null | grep "CREATE.*INDEX" > schema/indexes/$$table.sql || true; \
			fi; \
		fi; \
	done
	@echo "$(GREEN)Экспорт views...$(NC)"
	@for view in $$(docker-compose exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT viewname FROM pg_views WHERE schemaname = 'public' ORDER BY viewname;" 2>/dev/null | tr -d ' \r'); do \
		if [ -n "$$view" ]; then \
			echo "  → $$view"; \
			docker-compose exec -T postgres pg_dump -U $(DB_USER) -d $(DB_NAME) --schema-only --no-owner --no-privileges -t $$view 2>/dev/null > schema/views/$$view.sql || true; \
		fi; \
	done
	@echo "$(GREEN)✓ Схема обновлена в schema/$(NC)"
