"""Authorization boundaries for user-management mutations."""

import os
from pathlib import Path

from types import SimpleNamespace

import pytest
from httpx import ASGITransport, AsyncClient

os.environ.setdefault("JWT_SECRET", "test-secret")

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.main import app
from backend.app.models import Org, User
from backend.app.routers.dev import get_dev_router
from backend.app.schemas.dev import CreateUserIn


MIGRATION_PATH = (
    Path(__file__).resolve().parents[2] / "migrations" / "008_global_user_login.sql"
)


@pytest.fixture
async def tenant_users(session):
    org_a = Org(name="Organization A", slug="organization-a")
    org_b = Org(name="Organization B", slug="organization-b")
    session.add_all([org_a, org_b])
    await session.flush()

    admin_a = User(org_id=org_a.id, login="admin-a", role="ADMIN")
    user_a = User(org_id=org_a.id, login="user-a", role="TEACHER")
    user_b = User(
        org_id=org_b.id,
        login="user-b",
        role="TEACHER",
        password_hash="unchanged-password-hash",
    )
    session.add_all([admin_a, user_a, user_b])
    await session.commit()
    return SimpleNamespace(admin_a=admin_a, user_a=user_a, user_b=user_b)


@pytest.fixture
async def api_client(session, tenant_users):
    async def override_session():
        yield session

    async def override_current_user():
        return tenant_users.admin_a

    app.dependency_overrides[get_session] = override_session
    app.dependency_overrides[get_current_user] = override_current_user
    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            yield client
    finally:
        app.dependency_overrides.clear()


@pytest.mark.parametrize(
    ("path", "payload"),
    [
        ("/admin/set-role", {"login": "user-b", "role": "ADMIN"}),
        ("/admin/set-login", {"login": "user-b", "new_login": "renamed-b"}),
        ("/auth/set-password", {"login": "user-b", "password": "new-password"}),
    ],
)
async def test_admin_cannot_mutate_user_in_another_organization(
    api_client, tenant_users, session, path, payload
):
    response = await api_client.post(path, json=payload)

    assert response.status_code == 404
    await session.refresh(tenant_users.user_b)
    assert tenant_users.user_b.login == "user-b"
    assert tenant_users.user_b.role == "TEACHER"
    assert tenant_users.user_b.password_hash == "unchanged-password-hash"


async def test_user_login_change_rejects_login_owned_by_another_organization(
    api_client, tenant_users
):
    async def override_current_user():
        return tenant_users.user_a

    app.dependency_overrides[get_current_user] = override_current_user

    response = await api_client.post("/users/set-login", json={"new_login": "user-b"})

    assert response.status_code == 409


async def test_admin_cannot_create_login_already_owned_by_another_organization(
    api_client,
):
    response = await api_client.post(
        "/admin/create-user",
        json={"login": "user-b", "role": "TEACHER"},
    )

    assert response.status_code == 409


async def test_org_admin_cannot_create_login_owned_by_another_organization(
    api_client,
):
    response = await api_client.post(
        "/org/users",
        json={"login": "user-b", "role": "TEACHER"},
    )

    assert response.status_code == 409


async def test_dev_create_user_rejects_login_owned_by_another_organization(
    session,
    tenant_users,
):
    router = get_dev_router(dev_mode=True, dev_key="test-dev-key")
    endpoint = next(route.endpoint for route in router.routes if route.path == "/dev/create-user")

    result = await endpoint(
        CreateUserIn(login=tenant_users.user_b.login, role="TEACHER"),
        session,
    )

    assert result == {"ok": False, "error": "login exists"}


def test_global_login_migration_runs_all_constraint_changes_transactionally():
    migration = MIGRATION_PATH.read_text()

    assert "\\set ON_ERROR_STOP on" in migration
    assert migration.index("BEGIN;") < migration.index("DO $$")
    assert migration.index("DO $$") < migration.index(
        "ALTER TABLE users DROP CONSTRAINT IF EXISTS uq_users_org_login;"
    )
    assert migration.rstrip().endswith("COMMIT;")
