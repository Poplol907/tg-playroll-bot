-- Composite индексы для горячих запросов:
--  1. salary report:    teacher_rates(org_id, teacher_user_id, effective_from)
--  2. month-by-org:     lessons(org_id, scheduled_date)
--  3. teacher schedule: lessons(student_teacher_id, scheduled_date)
--  4. user-by-role:     users(org_id, role)
--
-- Запустить: psql $DATABASE_URL -f migrations/003_performance_indexes.sql

CREATE INDEX IF NOT EXISTS ix_teacher_rates_lookup
    ON teacher_rates(org_id, teacher_user_id, effective_from DESC);

CREATE INDEX IF NOT EXISTS ix_lessons_org_date
    ON lessons(org_id, scheduled_date);

CREATE INDEX IF NOT EXISTS ix_lessons_st_date
    ON lessons(student_teacher_id, scheduled_date);

CREATE INDEX IF NOT EXISTS ix_users_org_role
    ON users(org_id, role);
