-- Миграция: init_jiragram_tables
-- Создана: 2026-03-19 16:19:59

BEGIN;

-- ============================================
-- Ваш SQL код здесь
-- ============================================

-- Таблица пользователей (Jira аккаунты)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    jira_id TEXT UNIQUE NOT NULL,
    permissions TEXT[] DEFAULT '{dev_to_stage, stage_to_prod, prod_fail}',
    jira_access_token TEXT,
    jira_refresh_token TEXT,
    jira_token_expires_at TIMESTAMP
);


CREATE TABLE IF NOT EXISTS user_platforms (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    platform TEXT NOT NULL,
    external_id TEXT NOT NULL,
    UNIQUE(platform, external_id)
);

-- Таблица событий Jira
CREATE TABLE IF NOT EXISTS jira_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_key TEXT NOT NULL,
    project_key TEXT NOT NULL,
    event_type TEXT NOT NULL,
    author_id TEXT,
    raw_payload JSONB NOT NULL,
    processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- ============================================
-- Регистрация миграции (НЕ УДАЛЯТЬ!)
-- ============================================
INSERT INTO schema_migrations (version, name) 
VALUES ('001', 'init_jiragram_tables');

COMMIT;

-- Миграция: init_jiragram_tables
-- Создана: 2026-03-19 16:19:59

BEGIN;
