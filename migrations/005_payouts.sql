-- Migration 005: teacher payouts (partial payments per teacher per month)
--
-- Admins record one or more payments toward a teacher's monthly total. The UI
-- shows owed (from the salary/studio report) vs the sum of these rows (paid)
-- vs the remainder. Multiple rows per (teacher, month) = partial payments.
--
-- Запустить: psql $DATABASE_URL -f migrations/005_payouts.sql

CREATE TABLE IF NOT EXISTS payouts (
    id              SERIAL PRIMARY KEY,
    org_id          INTEGER NOT NULL REFERENCES orgs(id),
    teacher_user_id INTEGER NOT NULL REFERENCES users(id),
    month_year      VARCHAR(7) NOT NULL,           -- 'YYYY-MM'
    amount          INTEGER NOT NULL,
    paid_at         DATE NOT NULL,
    note            VARCHAR(256),
    created_by      INTEGER NOT NULL REFERENCES users(id),
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_payouts_org_id ON payouts(org_id);
CREATE INDEX IF NOT EXISTS ix_payouts_teacher_user_id ON payouts(teacher_user_id);
CREATE INDEX IF NOT EXISTS ix_payouts_month_lookup ON payouts(org_id, month_year, teacher_user_id);
