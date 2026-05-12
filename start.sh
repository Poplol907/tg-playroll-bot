#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  Kosmo Studio — unified startup script
#  Запускает бэкенд + Cloudflare Tunnel одной командой
#
#  Использование:
#    ./start.sh            — запускает с автоматическим туннелем
#    ./start.sh --no-tunnel — запускает только бэкенд (локально)
#
#  Первый запуск (только один раз):
#    brew install cloudflared
# ═══════════════════════════════════════════════════════════

BACKEND_PORT=8000
NO_TUNNEL=false
LOG_FILE="/tmp/kosmo_tunnel.log"

# ── Аргументы ────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --no-tunnel) NO_TUNNEL=true ;;
  esac
done

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
echo -e "${CYAN}  → Запускаем бэкенд на порту ${BACKEND_PORT}...${RESET}"

DEV_MODE=1 $PYTHON -m uvicorn backend.app.main:app \
  --host 0.0.0.0 \
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

if $NO_TUNNEL; then
  echo ""
  echo -e "${YELLOW}  ⚡ Локальный режим (без туннеля)${RESET}"
  echo -e "  URL: ${BOLD}http://localhost:${BACKEND_PORT}${RESET}"
  echo ""
  wait $UVICORN_PID
  exit 0
fi

# ── Проверяем cloudflared ─────────────────────────────────
if ! command -v cloudflared &>/dev/null; then
  echo ""
  echo -e "${RED}  ✗ cloudflared не установлен${RESET}"
  echo -e "  Установи: ${BOLD}brew install cloudflared${RESET}"
  echo ""
  echo -e "${YELLOW}  Продолжаем без туннеля...${RESET}"
  echo -e "  URL: ${BOLD}http://localhost:${BACKEND_PORT}${RESET}"
  echo ""
  wait $UVICORN_PID
  exit 0
fi

# ── Запускаем cloudflared quick tunnel ───────────────────
echo -e "${CYAN}  → Запускаем Cloudflare Tunnel...${RESET}"
cloudflared tunnel --url "http://localhost:${BACKEND_PORT}" \
  --no-autoupdate \
  2>"$LOG_FILE" &

TUNNEL_PID=$!

# ── Парсим публичный URL из логов ────────────────────────
PUBLIC_URL=""
for i in $(seq 1 20); do
  sleep 1
  URL=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$LOG_FILE" 2>/dev/null | head -1)
  if [ -n "$URL" ]; then
    PUBLIC_URL="$URL"
    break
  fi
done

# ── Экспортируем BASE_URL для OTA ────────────────────────
if [ -n "$PUBLIC_URL" ]; then
  export BASE_URL="$PUBLIC_URL"

  MANIFEST="backend/static/manifest.plist"
  if [ -f "${MANIFEST}.template" ]; then
    sed -E "s|https://yourdomain.com|$PUBLIC_URL|g; s|http://192\\.168\\.[0-9.]+:[0-9]+|$PUBLIC_URL|g" \
      "${MANIFEST}.template" > "$MANIFEST"
    echo -e "${GREEN}  ✓ manifest.plist обновлён${RESET}"
  fi

  echo ""
  echo -e "${GREEN}${BOLD}  ══════════════════════════════════════════${RESET}"
  echo -e "${GREEN}${BOLD}  ✦ Сервер доступен по адресу:${RESET}"
  echo -e "${BOLD}     ${PUBLIC_URL}${RESET}"
  echo -e "${GREEN}${BOLD}  ══════════════════════════════════════════${RESET}"
  echo ""
  echo -e "  ${YELLOW}Скопируй этот URL и вставь в приложение${RESET}"
  echo -e "  ${CYAN}(Настройки → Сервер → вставить URL)${RESET}"
  echo ""
  echo -e "  Swagger: ${PUBLIC_URL}/docs"
  echo ""
else
  echo -e "${YELLOW}  ⚠ Не удалось получить URL туннеля${RESET}"
  echo -e "  Лог: ${LOG_FILE}"
  echo -e "  Локальный: ${BOLD}http://localhost:${BACKEND_PORT}${RESET}"
  echo ""
fi

# ── Graceful shutdown ─────────────────────────────────────
cleanup() {
  echo ""
  echo -e "${CYAN}  → Останавливаем сервисы...${RESET}"
  kill $UVICORN_PID 2>/dev/null || true
  kill $TUNNEL_PID 2>/dev/null || true
  kill $CAFFEINATE_PID 2>/dev/null || true
  echo -e "${GREEN}  ✓ Готово${RESET}"
  exit 0
}

trap cleanup SIGINT SIGTERM

# ── Ждём ─────────────────────────────────────────────────
wait $UVICORN_PID
