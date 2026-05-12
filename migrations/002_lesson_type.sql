-- Миграция: добавляем поддержку уроков-отработок
-- Запустить один раз: psql $DATABASE_URL -f migrations/002_lesson_type.sql

ALTER TABLE lessons
    ADD COLUMN IF NOT EXISTS lesson_type VARCHAR(16) NOT NULL DEFAULT 'regular',
    ADD COLUMN IF NOT EXISTS makeup_for_id INTEGER REFERENCES lessons(id);

CREATE INDEX IF NOT EXISTS ix_lessons_makeup_for_id ON lessons(makeup_for_id);

-- Исторические данные: если makeup_status = 'done' — значит отработка уже была
-- Существующие записи остаются regular, новые makeup-уроки создаются с нуля
