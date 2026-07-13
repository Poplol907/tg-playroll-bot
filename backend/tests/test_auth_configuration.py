import importlib
import sys

import pytest


def test_auth_requires_jwt_secret_when_dev_mode_is_enabled(monkeypatch):
    monkeypatch.delenv("JWT_SECRET", raising=False)
    monkeypatch.setenv("DEV_MODE", "1")
    sys.modules.pop("backend.app.auth", None)

    with pytest.raises(RuntimeError, match="JWT_SECRET"):
        importlib.import_module("backend.app.auth")
