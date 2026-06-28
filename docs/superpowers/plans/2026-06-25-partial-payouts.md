# Partial Payouts (3.2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (project default — CLAUDE.md). Steps use `- [ ]`.

**Goal:** Let admins record partial payments to a teacher for a month and see "owed / paid / remaining" on the teacher profile. Owed = the month's per-teacher `totalAmount` (already on the profile via `TeacherStats`). Paid = sum of recorded payouts. New backend `payouts` table + API; mobile repo + profile UI.

**Tech Stack:** Backend FastAPI + SQLAlchemy (async) + raw-SQL migrations (`migrations/*.sql`, no Alembic). Mobile Flutter/Riverpod/Dio. Branch `feature/partial-payouts` off `main`.

**No backend test harness exists** — Task 1 is verified by `py_compile` + an import smoke test; correctness is by careful pattern-matching to `rates.py`/`TeacherRate`. The table reaches prod via a new `migrations/005_payouts.sql` the user runs (`psql $DATABASE_URL -f migrations/005_payouts.sql`); locally DEV_MODE `create_all` makes it from the model.

---

### Task 1: Backend — payouts table, model, schema, router

**Files:**
- Create: `migrations/005_payouts.sql`
- Modify: `backend/app/models.py` (append a `Payout` model)
- Create: `backend/app/schemas/payouts.py`
- Create: `backend/app/routers/payouts.py`
- Modify: `backend/app/main.py` (import + register the router)

- [ ] **Step 1: Migration** — create `migrations/005_payouts.sql`:

```sql
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
```

- [ ] **Step 2: Model** — append to `backend/app/models.py` (after the last model; all imports it needs — `Integer, String, Date, DateTime, ForeignKey, func, Mapped, mapped_column, date, datetime` — are already imported, same as `TeacherRate`):

```python
class Payout(Base):
    """Выплата педагогу за месяц. Несколько записей на (teacher, month) =
    частичные выплаты. owed считается из отчёта; paid = сумма этих записей."""

    __tablename__ = "payouts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    org_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("orgs.id"), nullable=False, index=True
    )
    teacher_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False, index=True
    )
    month_year: Mapped[str] = mapped_column(String(7), nullable=False, index=True)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    paid_at: Mapped[date] = mapped_column(Date, nullable=False)
    note: Mapped[str | None] = mapped_column(String(256), nullable=True)
    created_by: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )
```

- [ ] **Step 3: Schemas** — create `backend/app/schemas/payouts.py`:

```python
from datetime import date

from pydantic import BaseModel


class PayoutCreateIn(BaseModel):
    teacher_user_id: int
    month_year: str       # 'YYYY-MM'
    amount: int
    paid_at: date
    note: str | None = None


class PayoutOut(BaseModel):
    id: int
    teacher_user_id: int
    month_year: str
    amount: int
    paid_at: date
    note: str | None
```

- [ ] **Step 4: Router** — create `backend/app/routers/payouts.py`:

```python
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import Payout, User
from backend.app.schemas.payouts import PayoutCreateIn, PayoutOut
from backend.app.services.permissions import require_admin

router = APIRouter(prefix="/payouts", tags=["payouts"])


def _to_out(p: Payout) -> PayoutOut:
    return PayoutOut(
        id=p.id,
        teacher_user_id=p.teacher_user_id,
        month_year=p.month_year,
        amount=p.amount,
        paid_at=p.paid_at,
        note=p.note,
    )


@router.get("", response_model=list[PayoutOut])
async def list_payouts(
    month_year: str = Query(..., description="YYYY-MM"),
    teacher_id: int | None = Query(None),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    q = select(Payout).where(
        Payout.org_id == current_user.org_id,
        Payout.month_year == month_year,
    )
    if teacher_id is not None:
        q = q.where(Payout.teacher_user_id == teacher_id)
    q = q.order_by(Payout.paid_at.desc(), Payout.id.desc())
    rows = (await session.execute(q)).scalars().all()
    return [_to_out(p) for p in rows]


@router.post("", response_model=PayoutOut, status_code=201)
async def create_payout(
    payload: PayoutCreateIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    teacher = await session.get(User, payload.teacher_user_id)
    if teacher is None or teacher.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="teacher not found")
    payout = Payout(
        org_id=current_user.org_id,
        teacher_user_id=payload.teacher_user_id,
        month_year=payload.month_year,
        amount=payload.amount,
        paid_at=payload.paid_at,
        note=payload.note,
        created_by=current_user.id,
    )
    session.add(payout)
    await session.commit()
    await session.refresh(payout)
    return _to_out(payout)


@router.delete("/{payout_id}", status_code=204)
async def delete_payout(
    payout_id: int,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    payout = await session.get(Payout, payout_id)
    if payout is None or payout.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="payout not found")
    await session.delete(payout)
    await session.commit()
```

- [ ] **Step 5: Register the router** — in `backend/app/main.py`, mirror the existing pattern: add `from backend.app.routers.payouts import router as payouts_router` with the other router imports, and `app.include_router(payouts_router)` after `app.include_router(rates_router)`.

- [ ] **Step 6: Verify (no test harness)** — from repo root:
  - `.venv/bin/python -m py_compile backend/app/models.py backend/app/schemas/payouts.py backend/app/routers/payouts.py backend/app/main.py` → no errors.
  - Import smoke (DEV create_all path needs a DB URL but import alone shouldn't): `DATABASE_URL="postgresql+asyncpg://x/y" .venv/bin/python -c "import backend.app.routers.payouts; import backend.app.main; print('import OK')"` — if it fails ONLY at engine creation (database.py), that's unrelated to this change; the payouts module + main import must parse/resolve names. If `backend.app.routers.payouts` imports cleanly, that's the key signal.
  - Confirm the route is registered: `grep -n "payouts_router" backend/app/main.py`.

- [ ] **Step 7: Commit** scoped to the 5 files. Message: `feat(payouts): backend table, model, schema + CRUD router` + Co-Authored-By trailer.

---

### Task 2: Mobile — payouts repo/provider + profile "owed / paid / remaining" + mark-payment

**Files:**
- Create: `mobile/lib/features/admin/data/payouts_repository.dart`
- Create: `mobile/lib/features/admin/presentation/widgets/add_payout_sheet.dart`
- Modify: `mobile/lib/features/admin/presentation/screens/admin_screen.dart` (`_TeacherProfileScreen` payout island)
- Test: `mobile/test/features/admin/data/payouts_repository_test.dart`

- [ ] **Step 1: Repository + provider** — `payouts_repository.dart`, mirroring `rates_repository.dart`:
  - `PayoutsRepository(Dio)` with:
    - `Future<int> getPaidSum(int teacherId, String monthYear)` → `GET /payouts?month_year=$monthYear&teacher_id=$teacherId`, sum the `amount` fields of the returned list (0 if empty).
    - `Future<void> addPayout({required int teacherId, required String monthYear, required int amount, required DateTime paidAt})` → `POST /payouts` body `{teacher_user_id, month_year, amount, paid_at: 'YYYY-MM-DD', note: null}`.
  - `payoutsRepositoryProvider` (Provider, `RatesRepository`-style, `dioProvider` from `core/network/api_client.dart`).
  - `teacherPaidProvider` — `FutureProvider.family<int, ({int teacherId, String monthYear})>` returning `getPaidSum(...)`.

- [ ] **Step 2: TDD test** — `payouts_repository_test.dart`, mirroring `rates_repository_test.dart`'s fake-adapter approach: assert `getPaidSum` sums the `amount`s from a canned list response, and `addPayout` POSTs `amount` + `paid_at` as today's `YYYY-MM-DD` + `teacher_user_id`/`month_year`. Write FIRST, confirm FAIL.

- [ ] **Step 3: AddPayoutSheet** — `add_payout_sheet.dart`, mirroring `set_rate_sheet.dart`: `AddPayoutSheet.show(context, teacherId, monthYear, suggestedAmount)` → `Future<bool>`; numeric amount input (prefill with `suggestedAmount` = remaining), saves via `addPayout` with `paidAt: DateTime.now()`, returns true on success, snackbar on error. Title 'Отметить выплату'.

- [ ] **Step 4: Profile owed/paid/remaining** — in `_TeacherProfileScreen` (`admin_screen.dart`), the payout island currently shows just 'К выплате' = `Money.format(s?.totalAmount ?? 0)`. Extend it: read the month from `ref.watch(globalMonthYearProvider)` and `ref.watch(teacherPaidProvider((teacherId: user.id, monthYear: month)))`. Show three values — `К выплате` (owed = `s?.totalAmount ?? 0`), `Выплачено` (paid), `Осталось` (owed - paid, clamped ≥ 0) — each via `Money.format`. Add a full-width `NebulaTextButton` 'Отметить выплату' below the island → `AddPayoutSheet.show(context, user.id, month, remaining)`; on success `ref.invalidate(teacherPaidProvider((teacherId: user.id, monthYear: month)))`. Use OrbitLoader while the paid sum loads. Keep design tokens only.
  - `globalMonthYearProvider` is in `shared/providers/month_provider.dart` (used elsewhere in admin_screen, e.g. the view-as handler's `invalidateMonthData(ref, ref.read(globalMonthYearProvider))`). Confirm the import is present.

- [ ] **Step 5: Run repo test → PASS. `flutter analyze && flutter test` clean + all pass** (architecture ratchet tests must stay green — use typography/token styles, no raw fontSize/alpha).

- [ ] **Step 6: Commit** scoped to the 4 files. Message: `feat(payouts): record partial payments + owed/paid/remaining on profile` + Co-Authored-By trailer.

---

## After both tasks (prod migration — for the user)
The new table reaches production by running, once, on the server:
```bash
psql "$DATABASE_URL" -f migrations/005_payouts.sql
```
(or via the existing deploy flow). Then redeploy the backend. Mobile changes need a `flutter run` rebuild.

## Self-review
- Profile shows owed / paid / remaining for the selected month; "Отметить выплату" adds a payment and the numbers refresh.
- Backend `/payouts` GET/POST/DELETE are admin-only and org-scoped.
- `flutter analyze` clean; full mobile suite green; backend modules `py_compile` clean.
