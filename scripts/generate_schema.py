#!/usr/bin/env python3
"""
Генератор SQL схемы из миграций
Позволяет увидеть итоговую схему БД без применения миграций
"""

import re
import sys
from pathlib import Path


def extract_sql_from_migrations(migrations_dir):
    """Извлекает и объединяет SQL из всех миграций"""
    
    migrations_path = Path(migrations_dir) / "up"
    
    if not migrations_path.exists():
        print(f"❌ Директория {migrations_path} не найдена")
        sys.exit(1)
    
    # Получаем все файлы миграций
    migration_files = sorted(migrations_path.glob("*.sql"))
    
    if not migration_files:
        print(f"❌ Миграции не найдены в {migrations_path}")
        sys.exit(1)
    
    print(f"✓ Найдено миграций: {len(migration_files)}")
    
    combined_sql = []
    combined_sql.append("-- =====================================================")
    combined_sql.append("-- Generated Schema from Migrations")
    combined_sql.append("-- =====================================================")
    combined_sql.append("")
    
    for migration_file in migration_files:
        print(f"  → {migration_file.name}")
        
        combined_sql.append(f"-- Migration: {migration_file.name}")
        combined_sql.append("-- " + "-" * 50)
        
        with open(migration_file, 'r', encoding='utf-8') as f:
            content = f.read()
            # Убираем лишние пустые строки
            content = re.sub(r'\n{3,}', '\n\n', content)
            combined_sql.append(content)
        
        combined_sql.append("")
    
    return "\n".join(combined_sql)


def main():
    # Определяем путь к проекту
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    migrations_dir = project_dir / "migrations"
    output_dir = project_dir / "docs"
    
    # Создаем директорию docs если её нет
    output_dir.mkdir(exist_ok=True)
    
    print("🔍 Генерация схемы из миграций...")
    print(f"   Директория миграций: {migrations_dir}")
    print("")
    
    # Извлекаем SQL
    schema_sql = extract_sql_from_migrations(migrations_dir)
    
    # Сохраняем
    output_file = output_dir / "schema_from_migrations.sql"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(schema_sql)
    
    print("")
    print(f"✓ Схема сохранена: {output_file}")
    print(f"  Размер: {len(schema_sql)} символов")
    print("")
    print("Теперь можно посмотреть итоговую схему БД без применения миграций!")


if __name__ == "__main__":
    main()
