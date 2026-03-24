#!/bin/bash

DB_USER=${1:-postgres}
DB_NAME=${2:-myapp_db}

TMPFUNCS="/tmp/pg_funcs_$$.txt"
TMPPROCS="/tmp/pg_procs_$$.txt"

echo "Экспорт функций..."
docker-compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "
  SELECT p.oid || '|' || p.proname 
  FROM pg_proc p 
  WHERE p.pronamespace = 'public'::regnamespace 
    AND p.prokind = 'f' 
    AND p.proname NOT LIKE 'uuid_generate%' 
    AND p.proname NOT LIKE 'uuid_n%' 
  ORDER BY p.proname;
" 2>/dev/null > "$TMPFUNCS"

while IFS='|' read -r oid funcname; do
  oid=$(echo "$oid" | tr -d ' \r\n')
  funcname=$(echo "$funcname" | tr -d ' \r\n')
  if [ -n "$oid" ] && [ -n "$funcname" ]; then
    echo "  → $funcname()"
    docker-compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_get_functiondef($oid);" 2>/dev/null > "schema/functions/$funcname.sql" < /dev/null || echo "    ! Failed: $funcname"
  fi
done < "$TMPFUNCS"

rm -f "$TMPFUNCS"

echo "Экспорт процедур..."
docker-compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "
  SELECT p.oid || '|' || p.proname 
  FROM pg_proc p 
  WHERE p.pronamespace = 'public'::regnamespace 
    AND p.prokind = 'p' 
  ORDER BY p.proname;
" 2>/dev/null > "$TMPPROCS"

while IFS='|' read -r oid procname; do
  oid=$(echo "$oid" | tr -d ' \r\n')
  procname=$(echo "$procname" | tr -d ' \r\n')
  if [ -n "$oid" ] && [ -n "$procname" ]; then
    echo "  → $procname()"
    docker-compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_get_functiondef($oid);" 2>/dev/null > "schema/procedures/$procname.sql" < /dev/null || echo "    ! Failed: $procname"
  fi
done < "$TMPPROCS"

rm -f "$TMPPROCS"
