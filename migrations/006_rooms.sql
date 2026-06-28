-- Migration 006: classroom rooms and teacher room blocks
--
-- Admins manage rooms and allocate a room to a teacher for either a weekly
-- recurring time interval or a one-off date. Exceptions cancel recurring
-- blocks for a specific date.
--
-- Запустить: psql $DATABASE_URL -f migrations/006_rooms.sql

CREATE TABLE IF NOT EXISTS rooms (
    id         SERIAL PRIMARY KEY,
    org_id     INTEGER NOT NULL REFERENCES orgs(id),
    name       VARCHAR(64) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active  BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS room_blocks (
    id              SERIAL PRIMARY KEY,
    org_id          INTEGER NOT NULL REFERENCES orgs(id),
    room_id         INTEGER NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    teacher_user_id INTEGER NOT NULL REFERENCES users(id),
    weekday         SMALLINT,
    specific_date   DATE,
    start_time      TIME NOT NULL,
    end_time        TIME NOT NULL,
    note            VARCHAR(256),
    created_by      INTEGER NOT NULL REFERENCES users(id),
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT ck_room_blocks_one_schedule CHECK ((weekday IS NULL) <> (specific_date IS NULL))
);

CREATE TABLE IF NOT EXISTS room_block_exceptions (
    id             SERIAL PRIMARY KEY,
    org_id         INTEGER NOT NULL REFERENCES orgs(id),
    block_id       INTEGER NOT NULL REFERENCES room_blocks(id) ON DELETE CASCADE,
    exception_date DATE NOT NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_room_block_exception UNIQUE (block_id, exception_date)
);

CREATE INDEX IF NOT EXISTS ix_rooms_org_id ON rooms(org_id);
CREATE INDEX IF NOT EXISTS ix_rooms_org_sort ON rooms(org_id, sort_order, id);

CREATE INDEX IF NOT EXISTS ix_room_blocks_org_id ON room_blocks(org_id);
CREATE INDEX IF NOT EXISTS ix_room_blocks_room_id ON room_blocks(room_id);
CREATE INDEX IF NOT EXISTS ix_room_blocks_teacher_user_id ON room_blocks(teacher_user_id);
CREATE INDEX IF NOT EXISTS ix_room_blocks_recurring_lookup ON room_blocks(org_id, weekday);
CREATE INDEX IF NOT EXISTS ix_room_blocks_one_off_lookup ON room_blocks(org_id, specific_date);

CREATE INDEX IF NOT EXISTS ix_room_block_exceptions_org_id ON room_block_exceptions(org_id);
CREATE INDEX IF NOT EXISTS ix_room_block_exceptions_lookup ON room_block_exceptions(block_id, exception_date);
