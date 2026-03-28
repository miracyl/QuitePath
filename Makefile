-include .env.local
export

DOCKER_BIN := $(shell command -v docker-compose 2> /dev/null || echo "docker compose")

ifeq ($(shell command -v docker 2> /dev/null),)
  DOCKER_BIN := podman compose
endif
# -------------------------------------

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


ifneq (,$(wildcard .env))
    include .env
    export
endif

help:
	@echo ""
	@echo "$(BOLD)$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BOLD)$(CYAN)║$(NC)  $(BOLD)$(PURPLE)🗄️  PostgreSQL Database Management$(NC)                                $(BOLD)$(CYAN)║$(NC)"
	@echo "$(BOLD)$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(BOLD)$(BLUE)╭─────────────────────────────────────────────────────────────────╮$(NC)"
	@echo "$(BOLD)$(BLUE)│$(NC) 🐳 $(BOLD)Docker/Podman Commands$(NC)                                        $(BOLD)$(BLUE)│$(NC)"
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
	@echo "$(BOLD)$(PURPLE)═══════════════════════════════════════════════════════════════════$(NC)"

migrate:
	@echo "$(GREEN)Применение миграций на основную БД...$(NC)"
	@./scripts/migrate.sh migrate
	@echo "$(GREEN)✓ Миграции применены$(NC)"

deploy: migrate 
	@echo "$(GREEN)Обновление прав и ролей...$(NC)"
	@$(MAKE) init-roles
	@bash -c 'export PGPASSWORD="$$DEPLOY_PASSWORD"; psql -h $(DB_HOST) -p $(DB_PORT) -U $(DEPLOY_USER) -d postgres -f scripts/init_roles.sql'
	@echo "$(GREEN)✓ Деплой завершен$(NC)"

init-roles: ## Сгенерировать scripts/init_roles.sql
	@bash scripts/render_init_roles.sh

local: ## Развернуть локальную БД с миграциями и seed данными
	@echo "$(GREEN)Запуск локальной БД через $(DOCKER_BIN)...$(NC)"
	@$(DOCKER_BIN) up -d
	@echo "Ожидание запуска PostgreSQL..."
	@sleep 5
	@echo "$(GREEN)Создание базы данных...$(NC)"
	@$(DOCKER_BIN) exec -T postgres psql -U postgres -c "CREATE DATABASE $(DB_NAME);" 2>/dev/null || echo "БД уже существует"
	@echo "$(GREEN)0️⃣  Инициализация (schema_migrations)...$(NC)"
	@$(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < scripts/init_migrations.sql || exit 1
	@echo "$(GREEN)1️⃣  Применение миграций...$(NC)"
	@for file in migrations/up/*.sql; do \
		VERSION=$$(basename $$file .sql | cut -d_ -f1); \
		NAME=$$(basename $$file .sql | cut -d_ -f2-); \
		echo "  → $$VERSION: $$NAME"; \
		$(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file || exit 1; \
		for seed_file in migrations/seed/$${VERSION}_*.sql; do \
			if [ -f "$$seed_file" ]; then \
				echo "    ↳ Применение seed данных для $$VERSION"; \
				$(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$seed_file || exit 1; \
			fi; \
		done; \
	done
	@echo "$(GREEN)2️⃣  Применение функций...$(NC)"
	@for file in functions/*.sql; do \
		if [ -f "$$file" ]; then \
			echo "  → $$(basename $$file)"; \
			$(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file || exit 1; \
		fi; \
	done
	@echo "$(GREEN)3️⃣  Применение процедур...$(NC)"
	@for file in procedures/*.sql; do \
		if [ -f "$$file" ]; then \
			echo "  → $$(basename $$file)"; \
			$(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file || exit 1; \
		fi; \
	done
	@echo "$(GREEN)4️⃣  Применение data миграций...$(NC)"
	@for file in migrations/data/*.sql; do \
		if [ -f "$$file" ] && [ "$${file##*.}" = "sql" ] && [ "$$(basename $$file)" != "*.example" ]; then \
			filename=$$(basename "$$file"); \
			echo "  Проверка $$filename..."; \
			applied=$$($(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT COUNT(*) FROM data_migrations WHERE filename = '$$filename';" 2>/dev/null | tr -d ' '); \
			if [ "$$applied" = "0" ] || [ -z "$$applied" ]; then \
				echo "  → Применение $$filename"; \
				$(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file || exit 1; \
				$(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -c "INSERT INTO data_migrations (filename) VALUES ('$$filename');" > /dev/null; \
			else \
				echo "  ✓ $$filename уже применена"; \
			fi; \
		fi; \
	done
	@echo ""
	@echo "$(GREEN)✓ Локальная БД готова!$(NC)"
	@echo "Подключиться к БД: make psql"

down: ## Остановить локальную БД
	@$(DOCKER_BIN) down
	@echo "$(GREEN)✓ Локальная БД остановлена$(NC)"

clean: ## Удалить локальную БД полностью
	@$(DOCKER_BIN) down -v
	@echo "$(GREEN)✓ Локальная БД удалена$(NC)"

psql: ## Подключиться к локальной БД
	@$(DOCKER_BIN) exec -it postgres psql -U $(DB_USER) -d $(DB_NAME)

logs: ## Показать логи
	@$(DOCKER_BIN) logs -f

create: ## Создать новую миграцию
	@if [ -z "$(name)" ]; then echo "Использование: make create name=имя"; exit 1; fi
	@./scripts/migrate.sh create $(name)

migrate-up: ## Применить следующую миграцию
	@APPLIED=$$($(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null | tr -d ' \n' | tr '\n' '|'); \
	NEXT=""; \
	for file in migrations/up/*.sql; do \
		VERSION=$$(basename $$file .sql | cut -d_ -f1); \
		if ! echo "$$APPLIED" | grep -q "$$VERSION"; then NEXT=$$file; break; fi; \
	done; \
	if [ -z "$$NEXT" ]; then echo "$(YELLOW)Нет миграций для применения$(NC)"; exit 0; fi; \
	$(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$NEXT && echo "$(GREEN)✓ Применена: $$VERSION$(NC)"

migrate-status: ## Показать статус миграций
	@$(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -c "SELECT version, name, applied_at FROM schema_migrations ORDER BY version;" 2>/dev/null || echo "БД не инициализирована"

seed: ## Применить seed данные
	@APPLIED=$$($(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null); \
	for VERSION in $$APPLIED; do \
		for file in migrations/seed/$${VERSION}_*.sql; do \
			[ -f "$$file" ] && $(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) < $$file; \
		done; \
	done

schema: ## Сгенерировать schema.sql
	@mkdir -p docs
	@$(DOCKER_BIN) exec -T postgres pg_dump -U $(DB_USER) -d $(DB_NAME) --schema-only > docs/schema.sql

describe: ## Показать структуру всех таблиц
	@$(DOCKER_BIN) exec postgres psql -U $(DB_USER) -d $(DB_NAME) -c "\dt"

table: ## Показать структуру таблицы (make table name=users)
	@$(DOCKER_BIN) exec postgres psql -U $(DB_USER) -d $(DB_NAME) -c "\d+ $(name)"

schema-generate:
	@mkdir -p schema/tables
	@for table in $$($(DOCKER_BIN) exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public';" | tr -d ' \r'); do \
		[ -n "$$table" ] && $(DOCKER_BIN) exec -T postgres pg_dump -U $(DB_USER) -d $(DB_NAME) --schema-only -t $$table > schema/tables/$$table.sql; \
	done