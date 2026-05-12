"""Системные эндпоинты: версия приложения и OTA-обновления."""
import os
from pathlib import Path

from fastapi import APIRouter
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel

router = APIRouter(prefix="/system", tags=["system"])

# ── Текущая версия бэкенда/приложения ────────────────────────────────────────
# Меняй APP_BUILD и APP_VERSION в .env.prod каждый раз при выкатке новой версии
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
APP_BUILD   = int(os.getenv("APP_BUILD", "1"))

STATIC_DIR = Path(__file__).parent.parent.parent / "static"
STATIC_DIR.mkdir(exist_ok=True)

# Соответствие платформ → файлам в /static/
_PLATFORM_FILES: dict[str, str] = {
    "ios":     "manifest.plist",
    "android": "app.apk",
    "windows": "app-windows.zip",
    "macos":   "app-macos.dmg",
}


class VersionOut(BaseModel):
    version: str
    build: int
    has_update: bool
    install_url: str | None   # Ссылка для установки (зависит от платформы)


@router.get("/version", response_model=VersionOut)
async def get_version(current_build: int = 0, platform: str = "ios"):
    """
    Проверка обновлений.
    Flutter передаёт ?current_build=N&platform=ios|android|windows|macos.
    Возвращает has_update=True и install_url если есть новая версия для этой платформы.
    """
    base_url = os.getenv("BASE_URL", "")
    fname = _PLATFORM_FILES.get(platform)

    # Обновление доступно только если:
    # 1. build на сервере новее
    # 2. файл для этой платформы реально лежит в /static/
    # 3. BASE_URL задан (иначе ссылка невалидна)
    has_update = (
        APP_BUILD > current_build
        and fname is not None
        and (STATIC_DIR / fname).exists()
        and bool(base_url)
    )

    install_url: str | None = None
    if has_update:
        if platform == "ios":
            # OTA-установка через itms-services (без App Store)
            install_url = (
                f"itms-services://?action=download-manifest"
                f"&url={base_url}/system/manifest.plist"
            )
        else:
            install_url = f"{base_url}/system/{fname}"

    return VersionOut(
        version=APP_VERSION,
        build=APP_BUILD,
        has_update=has_update,
        install_url=install_url,
    )


# ── Файлы обновлений ─────────────────────────────────────────────────────────

@router.get("/manifest.plist", include_in_schema=False)
async def serve_manifest():
    """OTA-манифест для iOS."""
    path = STATIC_DIR / "manifest.plist"
    if not path.exists():
        return JSONResponse({"detail": "no iOS update available"}, status_code=404)
    return FileResponse(path, media_type="text/xml")


@router.get("/app.ipa", include_in_schema=False)
async def serve_ipa():
    """IPA-файл для iOS OTA."""
    path = STATIC_DIR / "app.ipa"
    if not path.exists():
        return JSONResponse({"detail": "not found"}, status_code=404)
    return FileResponse(
        path,
        media_type="application/octet-stream",
        filename="cosmo_studio.ipa",
    )


@router.get("/app.apk", include_in_schema=False)
async def serve_apk():
    """APK-файл для Android."""
    path = STATIC_DIR / "app.apk"
    if not path.exists():
        return JSONResponse({"detail": "no Android update available"}, status_code=404)
    return FileResponse(
        path,
        media_type="application/vnd.android.package-archive",
        filename="cosmo_studio.apk",
    )


@router.get("/app-windows.zip", include_in_schema=False)
async def serve_windows():
    """ZIP с Windows-сборкой."""
    path = STATIC_DIR / "app-windows.zip"
    if not path.exists():
        return JSONResponse({"detail": "no Windows update available"}, status_code=404)
    return FileResponse(
        path,
        media_type="application/zip",
        filename="cosmo_studio_windows.zip",
    )


@router.get("/app-macos.dmg", include_in_schema=False)
async def serve_macos():
    """DMG-образ для macOS."""
    path = STATIC_DIR / "app-macos.dmg"
    if not path.exists():
        return JSONResponse({"detail": "no macOS update available"}, status_code=404)
    return FileResponse(
        path,
        media_type="application/octet-stream",
        filename="cosmo_studio.dmg",
    )
