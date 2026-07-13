-- Migration 008: make user logins globally unique.
--
-- The current login API does not include an organization selector, so allowing
-- the same login in multiple organizations makes authentication ambiguous.
-- This migration stops safely when historic duplicates exist; resolve and
-- document those records before retrying rather than choosing an owner here.
--
-- Run: psql $DATABASE_URL -f migrations/008_global_user_login.sql

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM users
        GROUP BY login
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION
            'cannot enforce global users.login uniqueness: duplicate logins exist; resolve duplicates before applying migration';
    END IF;
END $$;

ALTER TABLE users DROP CONSTRAINT IF EXISTS uq_users_org_login;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_users_login'
          AND conrelid = 'users'::regclass
    ) THEN
        ALTER TABLE users ADD CONSTRAINT uq_users_login UNIQUE (login);
    END IF;
END $$;
