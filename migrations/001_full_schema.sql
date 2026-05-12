-- =============================================================================
-- Kosmo Studio — полная схема БД
-- Идемпотентна: безопасно запускать повторно (IF NOT EXISTS везде)
-- Порядок важен: таблицы создаются от независимых к зависимым
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Организации
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orgs (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(128) NOT NULL,
    slug       VARCHAR(64)  NOT NULL UNIQUE,
    is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP    NOT NULL DEFAULT NOW()
);


-- -----------------------------------------------------------------------------
-- 2. Пользователи
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id                 SERIAL PRIMARY KEY,
    org_id             INTEGER      NOT NULL REFERENCES orgs(id),
    login              VARCHAR(64)  NOT NULL,
    role               VARCHAR(16)  NOT NULL,   -- ADMIN / TEACHER / PENDING
    telegram_user_id   INTEGER      UNIQUE,
    teacher_name       VARCHAR(128),
    password_hash      VARCHAR(256),
    CONSTRAINT uq_users_org_login UNIQUE (org_id, login)
);

-- Добавляем password_hash если таблица уже существовала без него
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(256);


-- -----------------------------------------------------------------------------
-- 3. Ученики
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS students (
    id         SERIAL PRIMARY KEY,
    org_id     INTEGER     NOT NULL REFERENCES orgs(id),
    first_name VARCHAR(64) NOT NULL,
    last_name  VARCHAR(64) NOT NULL,
    phone      VARCHAR(32),
    status     VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    note       TEXT,
    created_at TIMESTAMP   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_student_identity UNIQUE (org_id, first_name, last_name, phone)
);

CREATE INDEX IF NOT EXISTS ix_students_org_id    ON students (org_id);
CREATE INDEX IF NOT EXISTS ix_students_first_name ON students (first_name);
CREATE INDEX IF NOT EXISTS ix_students_last_name  ON students (last_name);


-- -----------------------------------------------------------------------------
-- 4. Инструменты
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS instruments (
    id         SERIAL PRIMARY KEY,
    org_id     INTEGER     NOT NULL REFERENCES orgs(id),
    name       VARCHAR(64) NOT NULL,
    is_active  BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_instruments_org_name UNIQUE (org_id, name)
);


-- -----------------------------------------------------------------------------
-- 5. Связь ученик ↔ педагог
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS student_teachers (
    id               SERIAL PRIMARY KEY,
    org_id           INTEGER NOT NULL REFERENCES orgs(id),
    student_id       INTEGER NOT NULL REFERENCES students(id),
    teacher_user_id  INTEGER NOT NULL REFERENCES users(id),
    instrument_id    INTEGER REFERENCES instruments(id),
    is_primary       BOOLEAN NOT NULL DEFAULT TRUE,
    status           VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    created_at       TIMESTAMP   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_student_teacher UNIQUE (org_id, student_id, teacher_user_id)
);

CREATE INDEX IF NOT EXISTS ix_student_teachers_org_id          ON student_teachers (org_id);
CREATE INDEX IF NOT EXISTS ix_student_teachers_student_id      ON student_teachers (student_id);
CREATE INDEX IF NOT EXISTS ix_student_teachers_teacher_user_id ON student_teachers (teacher_user_id);
CREATE INDEX IF NOT EXISTS ix_student_teachers_instrument_id   ON student_teachers (instrument_id);

-- Добавляем instrument_id если таблица уже существовала без него
ALTER TABLE student_teachers ADD COLUMN IF NOT EXISTS instrument_id INTEGER REFERENCES instruments(id);


-- -----------------------------------------------------------------------------
-- 6. Абонементы
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscriptions (
    id               SERIAL PRIMARY KEY,
    org_id           INTEGER     NOT NULL REFERENCES orgs(id),
    student_id       INTEGER     NOT NULL REFERENCES students(id),
    teacher_user_id  INTEGER     NOT NULL REFERENCES users(id),
    month_year       VARCHAR(7)  NOT NULL,   -- '2026-04'
    lessons_count    INTEGER     NOT NULL,
    paid_at          DATE,
    status           VARCHAR(16) NOT NULL DEFAULT 'active',  -- active / frozen / cancelled
    created_at       TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_subscriptions_org_id          ON subscriptions (org_id);
CREATE INDEX IF NOT EXISTS ix_subscriptions_student_id      ON subscriptions (student_id);
CREATE INDEX IF NOT EXISTS ix_subscriptions_teacher_user_id ON subscriptions (teacher_user_id);
CREATE INDEX IF NOT EXISTS ix_subscriptions_month_year      ON subscriptions (month_year);


-- -----------------------------------------------------------------------------
-- 7. Уроки (главная таблица)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lessons (
    id                 SERIAL PRIMARY KEY,
    org_id             INTEGER     NOT NULL REFERENCES orgs(id),
    student_teacher_id INTEGER     NOT NULL REFERENCES student_teachers(id),
    subscription_id    INTEGER     REFERENCES subscriptions(id),
    scheduled_date     DATE        NOT NULL,
    scheduled_time     TIME,
    status             VARCHAR(16) NOT NULL DEFAULT 'scheduled',
    -- scheduled / attended / missed / cancelled
    cancelled_by       VARCHAR(16),   -- student / teacher
    makeup_status      VARCHAR(16) NOT NULL DEFAULT 'none',
    -- none / scheduled / done / burned / transferred
    makeup_date        DATE,
    payment_counted    BOOLEAN     NOT NULL DEFAULT FALSE,
    notes              TEXT,
    created_at         TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_lessons_org_id             ON lessons (org_id);
CREATE INDEX IF NOT EXISTS ix_lessons_student_teacher_id ON lessons (student_teacher_id);
CREATE INDEX IF NOT EXISTS ix_lessons_subscription_id    ON lessons (subscription_id);
CREATE INDEX IF NOT EXISTS ix_lessons_scheduled_date     ON lessons (scheduled_date);
CREATE INDEX IF NOT EXISTS ix_lessons_status             ON lessons (status);


-- -----------------------------------------------------------------------------
-- 8. Ставки педагогов (история)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS teacher_rates (
    id               SERIAL PRIMARY KEY,
    org_id           INTEGER      NOT NULL REFERENCES orgs(id),
    teacher_user_id  INTEGER      NOT NULL REFERENCES users(id),
    instrument_id    INTEGER      REFERENCES instruments(id),  -- null = для всех инструментов
    rate_per_lesson  INTEGER      NOT NULL,
    effective_from   DATE         NOT NULL,
    note             VARCHAR(256),
    created_by       INTEGER      NOT NULL REFERENCES users(id),
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_teacher_rates_org_id          ON teacher_rates (org_id);
CREATE INDEX IF NOT EXISTS ix_teacher_rates_teacher_user_id ON teacher_rates (teacher_user_id);
CREATE INDEX IF NOT EXISTS ix_teacher_rates_instrument_id   ON teacher_rates (instrument_id);
CREATE INDEX IF NOT EXISTS ix_teacher_rates_effective_from  ON teacher_rates (effective_from);


-- -----------------------------------------------------------------------------
-- 9. Расширенные отчёты
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reports_v2 (
    id               SERIAL PRIMARY KEY,
    org_id           INTEGER  NOT NULL REFERENCES orgs(id),
    teacher_user_id  INTEGER  NOT NULL REFERENCES users(id),
    period_start     DATE     NOT NULL,
    period_end       DATE     NOT NULL,
    report_type      VARCHAR(16) NOT NULL,   -- advance / final
    lessons_done     INTEGER  NOT NULL DEFAULT 0,
    lessons_missed   INTEGER  NOT NULL DEFAULT 0,
    lessons_debt     INTEGER  NOT NULL DEFAULT 0,
    advance_amount   INTEGER  NOT NULL DEFAULT 0,
    final_amount     INTEGER  NOT NULL DEFAULT 0,
    total_amount     INTEGER  NOT NULL DEFAULT 0,
    generated_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_reports_v2_org_id          ON reports_v2 (org_id);
CREATE INDEX IF NOT EXISTS ix_reports_v2_teacher_user_id ON reports_v2 (teacher_user_id);


-- -----------------------------------------------------------------------------
-- 10. Push-токены (для Flutter уведомлений)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS device_tokens (
    id         SERIAL PRIMARY KEY,
    user_id    INTEGER      NOT NULL REFERENCES users(id),
    token      VARCHAR(512) NOT NULL,
    platform   VARCHAR(16)  NOT NULL,   -- ios / android
    created_at TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_device_token UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS ix_device_tokens_user_id ON device_tokens (user_id);


-- -----------------------------------------------------------------------------
-- 11. Старая таблица отчётов (бот — не трогать!)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reports (
    id               SERIAL PRIMARY KEY,
    teacher_user_id  INTEGER   NOT NULL REFERENCES users(id),
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    total_sum        INTEGER   NOT NULL,
    raw_text         TEXT      NOT NULL
);
