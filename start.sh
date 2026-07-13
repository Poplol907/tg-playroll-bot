#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  Kosmo Studio — local development startup script
#  Запускает бэкенд только на loopback-интерфейсе.
#
#  Перед запуском задай непустой JWT_SECRET, например сгенерированный командой:
#    export JWT_SECRET="$(openssl rand -hex 32)"
# ═══════════════════════════════════════════════════════════

BACKEND_PORT=8000

# ── Цвета ────────────────────────────────────────────────
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"
BOLD="\033[1m"

echo ""
echo -e "${BOLD}${CYAN}  ✦ Kosmo Studio Server${RESET}"
echo -e "${CYAN}  ──────────────────────────────────${RESET}"
echo ""

# ── Переходим в директорию проекта ───────────────────────
cd "$(dirname "$0")"

# ── Проверяем обязательный секрет ─────────────────────────
if [ -z "${JWT_SECRET:-}" ]; then
  echo -e "${RED}  ✗ JWT_SECRET не задан. Укажи непустой локальный секрет и повтори запуск.${RESET}"
  exit 1
fi

# ── Проверяем Python / venv ───────────────────────────────
if [ -f ".venv/bin/python" ]; then
  PYTHON=".venv/bin/python"
elif command -v python3 &>/dev/null; then
  PYTHON="python3"
else
  echo -e "${RED}  ✗ Python не найден${RESET}"
  exit 1
fi

# ── Освобождаем порт если занят ──────────────────────────
EXISTING=$(lsof -ti:$BACKEND_PORT 2>/dev/null || true)
if [ -n "$EXISTING" ]; then
  echo -e "${YELLOW}  ⚠ Порт ${BACKEND_PORT} занят — освобождаем...${RESET}"
  echo "$EXISTING" | xargs kill -9 2>/dev/null || true
  sleep 1
fi

# ── Не даём Mac уснуть ────────────────────────────────────
caffeinate -i & 2>/dev/null
CAFFEINATE_PID=$!

# ── Запускаем uvicorn в фоне ─────────────────────────────
echo -e "${CYAN}  → Запускаем локальный бэкенд на порту ${BACKEND_PORT}...${RESET}"

DEV_MODE=1 $PYTHON -m uvicorn backend.app.main:app \
  --host 127.0.0.1 \
  --port "$BACKEND_PORT" \
  --reload \
  &

UVICORN_PID=$!
echo -e "${GREEN}  ✓ Бэкенд запущен (PID: ${UVICORN_PID})${RESET}"

# ── Ждём готовности бэкенда ──────────────────────────────
echo -e "${CYAN}  → Ждём готовности сервера...${RESET}"
for i in $(seq 1 15); do
  if curl -s "http://localhost:${BACKEND_PORT}/health" &>/dev/null; then
    echo -e "${GREEN}  ✓ Сервер готов${RESET}"
    break
  fi
  sleep 1
done

echo ""
echo -e "${YELLOW}  ⚡ Локальный режим${RESET}"
echo -e "  URL: ${BOLD}http://localhost:${BACKEND_PORT}${RESET}"
echo ""

# ── Graceful shutdown ─────────────────────────────────────
cleanup() {
  echo ""
  echo -e "${CYAN}  → Останавливаем сервис...${RESET}"
  kill $UVICORN_PID 2>/dev/null || true
  kill $CAFFEINATE_PID 2>/dev/null || true
  echo -e "${GREEN}  ✓ Готово${RESET}"
  exit 0
}

trap cleanup SIGINT SIGTERM

# ── Ждём ─────────────────────────────────────────────────
wait $UVICORN_PID
