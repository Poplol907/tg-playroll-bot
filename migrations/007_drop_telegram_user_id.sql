-- Migration 007: drop legacy users.telegram_user_id
--
-- Телеграм-бот выведен из эксплуатации (продукт — мобильное приложение на JWT).
-- Колонка и её уникальный индекс больше не используются кодом; вход по
-- telegram_user_id удалён из аутентификации как небезопасный (публичное число,
-- не секрет). Удаляем колонку — её unique-constraint уходит вместе с ней.
--
-- Запустить: psql $DATABASE_URL -f migrations/007_drop_telegram_user_id.sql

ALTER TABLE users DROP COLUMN IF EXISTS telegram_user_id;
