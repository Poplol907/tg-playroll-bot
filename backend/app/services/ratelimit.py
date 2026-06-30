"""In-process rate limiting для чувствительных эндпоинтов (логин и т.п.).

Скользящее окно по client IP, без внешних зависимостей. Подходит для
single-instance деплоя (один backend-контейнер за Caddy). Для горизонтального
масштабирования заменить in-memory хранилище на общий бэкенд (Redis) —
публичный API `enforce` при этом не меняется.
"""
from __future__ import annotations

import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

# key -> очередь timestamp'ов попыток
_buckets: dict[str, deque[float]] = defaultdict(deque)


def _client_ip(request: Request) -> str:
    """Реальный IP клиента.

    За обратным прокси (Caddy) сокет-пир — это прокси, поэтому доверяем
    первому хопу в X-Forwarded-For, который проставляет Caddy.
    """
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def enforce(key: str, *, max_calls: int, window_seconds: float) -> None:
    """Разрешить не более `max_calls` обращений по `key` за окно. Иначе 429."""
    now = time.monotonic()
    bucket = _buckets[key]
    cutoff = now - window_seconds
    while bucket and bucket[0] <= cutoff:
        bucket.popleft()
    if len(bucket) >= max_calls:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="too many attempts, try again later",
        )
    bucket.append(now)


def login_rate_limit(request: Request) -> None:
    """Тормозит попытки логина по IP — защита от брутфорса пароля."""
    enforce(f"login:{_client_ip(request)}", max_calls=10, window_seconds=300)
