#!/bin/bash

# Скрипт для управления миграциями PostgreSQL

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Загрузка переменных окружения (опционально, если уже не заданы)
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Используем DEPLOY_USER для миграций, если задан, иначе DB_USER
MIGRATION_USER="${DEPLOY_USER:-$DB_USER}"
MIGRATION_PASSWORD="${DEPLOY_PASSWORD:-$DB_PASSWORD}"

# Проверка обязательных переменных
if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$DB_NAME" ] || [ -z "$MIGRATION_USER" ] || [ -z "$MIGRATION_PASSWORD" ]; then
    echo -e "${RED}Ошибка: не все переменные окружения установлены${NC}"
    echo "Задайте переменные: DB_HOST, DB_PORT, DB_NAME"
    echo "Для миграций: DEPLOY_USER + DEPLOY_PASSWORD (или DB_USER + DB_PASSWORD)"
    echo "Через .env файл или переменные окружения (например, GitLab CI/CD Variables)"
    exit 1
fi

# Строка подключения
export PGPASSWORD=$MIGRATION_PASSWORD
PSQL="psql -h $DB_HOST -p $DB_PORT -U $MIGRATION_USER -d $DB_NAME"

# Директории
MIGRATIONS_UP_DIR="./migrations/up"
MIGRATIONS_DOWN_DIR="./migrations/down"

# Функция для проверки соединения с БД
check_connection() {
    echo -e "${BLUE}Проверка соединения с базой данных...${NC}"
    echo -e "${BLUE}Host: $DB_HOST, Port: $DB_PORT, DB: $DB_NAME, User: $MIGRATION_USER${NC}"
    
    if $PSQL -c "SELECT 1;" 2>&1 | tee /tmp/psql_error.log > /dev/null; then
        echo -e "${GREEN}✓ Соединение установлено${NC}"
        return 0
    else
        echo -e "${RED}✗ Не удалось подключиться к базе данных${NC}"
        echo -e "${RED}Ошибка:${NC}"
        cat /tmp/psql_error.log
        return 1
    fi
}

# Функция для создания таблицы миграций
init_migrations_table() {
    echo -e "${BLUE}Инициализация таблицы миграций...${NC}"
    $PSQL -c "CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        version VARCHAR(255) NOT NULL UNIQUE,
        name VARCHAR(255) NOT NULL,
        applied_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        execution_time_ms INTEGER,
        checksum VARCHAR(64)
    );" > /dev/null
    echo -e "${GREEN}✓ Таблица миграций готова${NC}"
}

# Функция для вычисления контрольной суммы файла
get_checksum() {
    local file=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        md5 -q "$file"
    else
        md5sum "$file" | awk '{print $1}'
    fi
}

# Функция для получения списка примененных миграций
get_applied_migrations() {
    $PSQL -t -c "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null | grep -v '^$' | sed 's/^[[:space:]]*//'
}

# Функция для получения списка доступных миграций
get_available_migrations() {
    find "$MIGRATIONS_UP_DIR" -name "*.sql" -type f | sort | xargs -n1 basename | sed 's/\.sql$//'
}

# Функция для применения одной миграции
apply_migration() {
    local version=$1
    local file="${MIGRATIONS_UP_DIR}/${version}.sql"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ Файл миграции не найден: $file${NC}"
        return 1
    fi
    
    local name=$(echo "$version" | sed 's/^[0-9]*_//')
    local checksum=$(get_checksum "$file")
    local start_time=$(date +%s%3N)
    
    echo -e "${BLUE}Применение миграции: ${version}${NC}"
    
    if $PSQL -f "$file" > /dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local execution_time=$((end_time - start_time))
        
        $PSQL -c "INSERT INTO schema_migrations (version, name, checksum, execution_time_ms) 
                  VALUES ('$version', '$name', '$checksum', $execution_time);" > /dev/null
        
        echo -e "${GREEN}✓ Миграция $version применена успешно (${execution_time}ms)${NC}"
        return 0
    else
        echo -e "${RED}✗ Ошибка при применении миграции $version${NC}"
        return 1
    fi
}

# Функция для отката одной миграции
rollback_migration() {
    local version=$1
    local file="${MIGRATIONS_DOWN_DIR}/${version}.sql"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ Файл отката не найден: $file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Откат миграции: ${version}${NC}"
    
    if $PSQL -f "$file" > /dev/null 2>&1; then
        $PSQL -c "DELETE FROM schema_migrations WHERE version = '$version';" > /dev/null
        echo -e "${GREEN}✓ Миграция $version откачена успешно${NC}"
        return 0
    else
        echo -e "${RED}✗ Ошибка при откате миграции $version${NC}"
        return 1
    fi
}

# Команда: migrate (применить все новые миграции)
cmd_migrate() {
    check_connection || exit 1
    init_migrations_table
    
    local applied=$(get_applied_migrations)
    local available=$(get_available_migrations)
    local new_migrations=0
    
    echo -e "${BLUE}Поиск новых миграций...${NC}"
    
    for migration in $available; do
        if ! echo "$applied" | grep -q "^${migration}$"; then
            apply_migration "$migration" || exit 1
            ((new_migrations++))
        fi
    done
    
    if [ $new_migrations -eq 0 ]; then
        echo -e "${GREEN}База данных актуальна, новых миграций нет${NC}"
    else
        echo -e "${GREEN}✓ Применено миграций: $new_migrations${NC}"
    fi
}

# Команда: rollback (откатить последнюю миграцию)
cmd_rollback() {
    check_connection || exit 1
    
    local last_migration=$($PSQL -t -c "SELECT version FROM schema_migrations ORDER BY applied_at DESC LIMIT 1;" | sed 's/^[[:space:]]*//')
    
    if [ -z "$last_migration" ]; then
        echo -e "${YELLOW}Нет миграций для отката${NC}"
        exit 0
    fi
    
    rollback_migration "$last_migration"
}

# Команда: rollback-all (откатить все миграции)
cmd_rollback_all() {
    check_connection || exit 1
    
    local migrations=$($PSQL -t -c "SELECT version FROM schema_migrations ORDER BY applied_at DESC;" | grep -v '^$' | sed 's/^[[:space:]]*//')
    
    if [ -z "$migrations" ]; then
        echo -e "${YELLOW}Нет миграций для отката${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}Вы собираетесь откатить ВСЕ миграции. Продолжить? (y/n)${NC}"
    read -r response
    
    if [ "$response" != "y" ]; then
        echo -e "${BLUE}Отмена операции${NC}"
        exit 0
    fi
    
    for migration in $migrations; do
        rollback_migration "$migration" || exit 1
    done
    
    echo -e "${GREEN}✓ Все миграции откачены${NC}"
}

# Команда: status (показать статус миграций)
cmd_status() {
    check_connection || exit 1
    init_migrations_table
    
    local applied=$(get_applied_migrations)
    local available=$(get_available_migrations)
    
    echo -e "${BLUE}Статус миграций:${NC}"
    echo ""
    
    for migration in $available; do
        if echo "$applied" | grep -q "^${migration}$"; then
            local info=$($PSQL -t -c "SELECT applied_at, execution_time_ms FROM schema_migrations WHERE version = '$migration';" | sed 's/^[[:space:]]*//')
            echo -e "${GREEN}✓${NC} $migration - Применена ($info)"
        else
            echo -e "${YELLOW}○${NC} $migration - Не применена"
        fi
    done
    
    echo ""
    local total=$(echo "$available" | wc -l | tr -d ' ')
    local applied_count=$(echo "$applied" | wc -l | tr -d ' ')
    echo -e "Всего миграций: $total, Применено: $applied_count"
}

# Команда: create (создать новую миграцию)
cmd_create() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${RED}Ошибка: укажите название миграции${NC}"
        echo "Использование: $0 create <name>"
        exit 1
    fi
    
    # Получаем следующий номер версии
    # Формат: 001, 002, 003... (3 цифры позволяют до 999 миграций)
    # Если нужно больше - измените на %04d для 0001, 0002...
    local last_version=$(find "$MIGRATIONS_UP_DIR" -name "*.sql" -type f | sort | tail -1 | xargs basename | sed 's/_.*//')
    local next_version=$(printf "%03d" $((10#$last_version + 1)))
    
    local filename="${next_version}_${name}"
    local up_file="${MIGRATIONS_UP_DIR}/${filename}.sql"
    local down_file="${MIGRATIONS_DOWN_DIR}/${filename}.sql"
    
    # Создаем файлы миграций
    cat > "$up_file" << EOF
-- Миграция: $name
-- Создана: $(date '+%Y-%m-%d %H:%M:%S')

BEGIN;

-- ============================================
-- Ваш SQL код здесь
-- ============================================



-- ============================================
-- Регистрация миграции (НЕ УДАЛЯТЬ!)
-- ============================================
INSERT INTO schema_migrations (version, name) 
VALUES ('${next_version}', '${name}');

COMMIT;
EOF
    
    cat > "$down_file" << EOF
-- Откат миграции: $name
-- Создана: $(date '+%Y-%m-%d %H:%M:%S')

BEGIN;

-- ============================================
-- Ваш SQL код для отката здесь
-- ============================================



-- ============================================
-- Удаление записи о миграции (НЕ УДАЛЯТЬ!)
-- ============================================
DELETE FROM schema_migrations WHERE version = '${next_version}';

COMMIT;
EOF
    
    echo -e "${GREEN}✓ Создана миграция: $filename${NC}"
    echo -e "  UP:   $up_file"
    echo -e "  DOWN: $down_file"
}

# Команда: reset (полный сброс и повторное применение всех миграций)
cmd_reset() {
    echo -e "${RED}ВНИМАНИЕ: Эта команда удалит ВСЕ данные и пересоздаст базу данных!${NC}"
    echo -e "${YELLOW}Продолжить? (y/n)${NC}"
    read -r response
    
    if [ "$response" != "y" ]; then
        echo -e "${BLUE}Отмена операции${NC}"
        exit 0
    fi
    
    cmd_rollback_all
    cmd_migrate
    
    echo -e "${GREEN}✓ База данных сброшена и пересоздана${NC}"
}

# Главная функция
main() {
    local command=$1
    shift
    
    case "$command" in
        migrate)
            cmd_migrate "$@"
            ;;
        rollback)
            cmd_rollback "$@"
            ;;
        rollback-all)
            cmd_rollback_all "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        create)
            cmd_create "$@"
            ;;
        reset)
            cmd_reset "$@"
            ;;
        *)
            echo "Использование: $0 {migrate|rollback|rollback-all|status|create|reset}"
            echo ""
            echo "Команды:"
            echo "  migrate       - Применить все новые миграции"
            echo "  rollback      - Откатить последнюю миграцию"
            echo "  rollback-all  - Откатить все миграции"
            echo "  status        - Показать статус миграций"
            echo "  create <name> - Создать новую миграцию"
            echo "  reset         - Полный сброс и пересоздание БД"
            exit 1
            ;;
    esac
}

main "$@"
