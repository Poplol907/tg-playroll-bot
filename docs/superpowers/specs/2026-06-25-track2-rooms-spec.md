# Track 2 — Classroom Scheduling (Rooms) — Spec & API Contract

- **Date:** 2026-06-25
- **Status:** Design approved (v1 scope below). This doc is the **single source of truth** for the API contract — backend (Codex) and mobile (Claude) both build to it.
- **Decisions:** Room "blocks" (model B — admin allocates a room to a teacher for a time interval; lessons happen inside). Recurrence is **mixed**: a weekly template + per-date one-offs + per-date cancellations of recurring blocks. Mobile board primary view = **Day** (rooms as columns).

## Scope (v1)

- **Rooms CRUD** (admin): manage the studio's room list.
- **Room blocks** (admin): assign room + teacher + time, either recurring-by-weekday or a one-off on a specific date; cancel a recurring block on a specific date.
- **Room board (Day)** (admin): for a chosen date, rooms = columns, time = rows, colored blocks per teacher; **conflicts** (two teachers, same room, overlapping time) highlighted; tap empty → assign; tap block → edit/cancel/delete.
- **Teacher "Мои кабинеты сегодня"**: a teacher sees only their own blocks for today.
- **Calendar integration**: the calendar gets a scope switcher **[Ученики | Кабинеты]** (reuse `NebulaSegmentedControl`). Ученики = the existing calendar. Кабинеты = the Day room board.

**Out of v1:** month/week zoom for student lessons; linking lessons to a room automatically; drag-to-move blocks.

---

## Data model (backend)

Migration file: `migrations/006_rooms.sql` (raw SQL, `CREATE TABLE IF NOT EXISTS`, header comment + `psql -f` line — same style as `migrations/005_payouts.sql`). DEV_MODE `create_all` makes them locally from the models.

**`rooms`**
| col | type | notes |
|---|---|---|
| id | SERIAL PK | |
| org_id | INT NOT NULL → orgs(id) | index |
| name | VARCHAR(64) NOT NULL | |
| sort_order | INT NOT NULL DEFAULT 0 | board column order |
| is_active | BOOLEAN NOT NULL DEFAULT true | archived rooms hidden by default |
| created_at | TIMESTAMP NOT NULL DEFAULT now() | |

**`room_blocks`** — one allocation of a room to a teacher for a time interval.
| col | type | notes |
|---|---|---|
| id | SERIAL PK | |
| org_id | INT NOT NULL → orgs(id) | index |
| room_id | INT NOT NULL → rooms(id) ON DELETE CASCADE | index |
| teacher_user_id | INT NOT NULL → users(id) | index |
| weekday | SMALLINT NULL | 0=Mon … 6=Sun; set ⇒ recurring |
| specific_date | DATE NULL | set ⇒ one-off |
| start_time | TIME NOT NULL | |
| end_time | TIME NOT NULL | |
| note | VARCHAR(256) NULL | |
| created_by | INT NOT NULL → users(id) | |
| created_at | TIMESTAMP NOT NULL DEFAULT now() | |

Invariant: **exactly one** of `weekday` / `specific_date` is non-null (enforce in the create endpoint; a DB CHECK `((weekday IS NULL) <> (specific_date IS NULL))` is nice-to-have).

**`room_block_exceptions`** — "this recurring block does NOT occur on this date".
| col | type | notes |
|---|---|---|
| id | SERIAL PK | |
| org_id | INT NOT NULL → orgs(id) | index |
| block_id | INT NOT NULL → room_blocks(id) ON DELETE CASCADE | |
| exception_date | DATE NOT NULL | |
| created_at | TIMESTAMP NOT NULL DEFAULT now() | |

UNIQUE(block_id, exception_date).

### Resolution semantics (the key rule)
For a target date **D** with weekday **W** (Mon=0 … Sun=6, Python `date.weekday()`):
1. **recurring** = `room_blocks` where `org_id = me`, `weekday = W`, AND there is **no** `room_block_exceptions` row for `(block_id = that block, exception_date = D)`.
2. **one-off** = `room_blocks` where `org_id = me`, `specific_date = D`.
3. **resolved blocks for D** = recurring ∪ one-off.

Conflicts (two blocks, same `room_id`, overlapping `[start_time, end_time)`) are computed **client-side** from the resolved list — the API does not flag them.

---

## API contract

Base: same FastAPI app, JWT auth (`get_current_user`), `org`-scoped. Mirror `backend/app/routers/payouts.py` / `rates.py` patterns (router prefix, `require_admin`, explicit `await session.commit()` — `get_session` does NOT auto-commit). Times are `"HH:MM"` strings over the wire; dates `"YYYY-MM-DD"`.

### Rooms (admin-only)
- `GET /rooms?include_inactive=false` → `[RoomOut]`
- `POST /rooms` body `{ "name": str }` → `RoomOut` (201)
- `PATCH /rooms/{id}` body `{ "name"?: str, "sort_order"?: int, "is_active"?: bool }` → `RoomOut`
- `DELETE /rooms/{id}` → 204 (hard delete; `room_blocks` cascade)

`RoomOut = { id:int, name:str, sort_order:int, is_active:bool }`

### Room blocks
- `GET /room-blocks?date=YYYY-MM-DD[&teacher_id=int]` → `[ResolvedBlockOut]` — **admin-or-teacher**. A TEACHER caller always gets only their own blocks (server forces `teacher_id = self.id`, ignores/checks the param). Admin may pass `teacher_id` to filter, or omit for all.
  - Returns the **resolved** blocks for that date (recurring matching the weekday minus exceptions, plus one-offs).
  - `ResolvedBlockOut = { id:int, room_id:int, room_name:str, teacher_user_id:int, teacher_name:str|null, start_time:"HH:MM", end_time:"HH:MM", note:str|null, is_recurring:bool, specific_date:"YYYY-MM-DD"|null, weekday:int|null }`
- `POST /room-blocks` (admin) body:
  `{ "room_id":int, "teacher_user_id":int, "start_time":"HH:MM", "end_time":"HH:MM", "weekday":int|null, "specific_date":"YYYY-MM-DD"|null, "note":str|null }`
  → `RoomBlockOut` (201). Validate: exactly one of weekday/specific_date; teacher & room belong to org; end_time > start_time.
  `RoomBlockOut = { id, room_id, teacher_user_id, weekday, specific_date, start_time, end_time, note }`
- `DELETE /room-blocks/{id}` (admin) → 204 (deletes the block; its exceptions cascade).
- `POST /room-blocks/{id}/cancel` (admin) body `{ "date":"YYYY-MM-DD" }` → 201 — adds a `room_block_exceptions` row (cancel a recurring block on that date). Idempotent (UNIQUE; ignore/return existing on duplicate). Only meaningful for recurring blocks; for a one-off just `DELETE` the block.
- `DELETE /room-blocks/{id}/cancel?date=YYYY-MM-DD` (admin) → 204 — removes the exception (un-cancel).

All endpoints org-scoped; `require_admin` on everything except `GET /room-blocks` which is `require_admin_or_teacher` with the teacher-self forcing described above.

---

## Work split

- **Backend (→ Codex):** `migrations/006_rooms.sql`, models (`Room`, `RoomBlock`, `RoomBlockException`), schemas (`backend/app/schemas/rooms.py`), routers (`backend/app/routers/rooms.py` for rooms + `room_blocks` — or two routers), register in `main.py`. Verify via `py_compile` + import smoke (no pytest in the project). The resolution query is the only non-trivial logic.
- **Mobile (→ Claude):** rooms management UI (admin), the Day room board (rooms columns × time, conflict highlight, tap-to-assign/edit), the calendar **[Ученики | Кабинеты]** scope switcher routing to the board, teacher "Мои кабинеты сегодня" card. Build against this contract; unit-test repos with fakes; wire to the live API once the backend is deployed.

**Sync point:** this contract. If either side needs a contract change, update THIS doc first.

## Prod migration (after backend ships)
`docker compose -f docker-compose.prod.yml exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB" < migrations/006_rooms.sql` then redeploy (same as 005).
