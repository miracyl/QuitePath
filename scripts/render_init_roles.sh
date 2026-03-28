#!/bin/bash
set -eu

required_vars="DEPLOY_USER DEPLOY_PASSWORD DB_USER DB_PASSWORD DB_NAME"

for var in $required_vars; do
  if [ -z "${!var:-}" ]; then
    echo "Missing required env var: $var" >&2
    exit 1
  fi
done

envsubst '$DEPLOY_USER $DEPLOY_PASSWORD $DB_USER $DB_PASSWORD $DB_NAME' \
  < scripts/init_roles.sql.template \
  > scripts/init_roles.sql

echo "Generated: scripts/init_roles.sql"
