from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import exists, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import Room, RoomBlock, RoomBlockException, User
from backend.app.schemas.rooms import (
    CancelIn,
    ResolvedBlockOut,
    RoomBlockCreateIn,
    RoomBlockOut,
    RoomCreateIn,
    RoomOut,
    RoomUpdateIn,
)
from backend.app.services.permissions import require_admin, require_admin_or_teacher

router = APIRouter(tags=["rooms"])


def _to_room_out(room: Room) -> RoomOut:
    return RoomOut(
        id=room.id,
        name=room.name,
        sort_order=room.sort_order,
        is_active=room.is_active,
    )


def _to_block_out(block: RoomBlock) -> RoomBlockOut:
    return RoomBlockOut(
        id=block.id,
        room_id=block.room_id,
        teacher_user_id=block.teacher_user_id,
        weekday=block.weekday,
        specific_date=block.specific_date,
        start_time=block.start_time,
        end_time=block.end_time,
        note=block.note,
    )


def _validate_block_payload(payload: RoomBlockCreateIn) -> None:
    has_weekday = payload.weekday is not None
    has_specific_date = payload.specific_date is not None
    if has_weekday == has_specific_date:
        raise HTTPException(
            status_code=400,
            detail="exactly one of weekday or specific_date is required",
        )
    if payload.weekday is not None and not 0 <= payload.weekday <= 6:
        raise HTTPException(status_code=400, detail="weekday must be between 0 and 6")
    if payload.end_time <= payload.start_time:
        raise HTTPException(status_code=400, detail="end_time must be after start_time")


@router.get("/rooms", response_model=list[RoomOut])
async def list_rooms(
    include_inactive: bool = Query(False),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    q = select(Room).where(Room.org_id == current_user.org_id)
    if not include_inactive:
        q = q.where(Room.is_active.is_(True))
    q = q.order_by(Room.sort_order.asc(), Room.id.asc())
    rooms = (await session.execute(q)).scalars().all()
    return [_to_room_out(room) for room in rooms]


@router.post("/rooms", response_model=RoomOut, status_code=201)
async def create_room(
    payload: RoomCreateIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    room = Room(
        org_id=current_user.org_id,
        name=payload.name,
    )
    session.add(room)
    await session.commit()
    await session.refresh(room)
    return _to_room_out(room)


@router.patch("/rooms/{id}", response_model=RoomOut)
async def update_room(
    id: int,
    payload: RoomUpdateIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    room = await session.get(Room, id)
    if room is None or room.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="room not found")

    if payload.name is not None:
        room.name = payload.name
    if payload.sort_order is not None:
        room.sort_order = payload.sort_order
    if payload.is_active is not None:
        room.is_active = payload.is_active

    await session.commit()
    await session.refresh(room)
    return _to_room_out(room)


@router.delete("/rooms/{id}", status_code=204)
async def delete_room(
    id: int,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    room = await session.get(Room, id)
    if room is None or room.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="room not found")
    await session.delete(room)
    await session.commit()


@router.get("/room-blocks", response_model=list[ResolvedBlockOut])
async def list_room_blocks(
    date: date = Query(...),
    teacher_id: int | None = Query(None),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin_or_teacher(current_user)
    if current_user.role == "TEACHER":
        teacher_id = current_user.id

    exception_exists = exists().where(
        RoomBlockException.org_id == current_user.org_id,
        RoomBlockException.block_id == RoomBlock.id,
        RoomBlockException.exception_date == date,
    )
    q = (
        select(RoomBlock, Room.name, User.teacher_name)
        .join(Room, Room.id == RoomBlock.room_id)
        .join(User, User.id == RoomBlock.teacher_user_id)
        .where(
            RoomBlock.org_id == current_user.org_id,
            Room.org_id == current_user.org_id,
            User.org_id == current_user.org_id,
            or_(
                (
                    (RoomBlock.weekday == date.weekday())
                    & (RoomBlock.specific_date.is_(None))
                    & (~exception_exists)
                ),
                RoomBlock.specific_date == date,
            ),
        )
    )
    if teacher_id is not None:
        q = q.where(RoomBlock.teacher_user_id == teacher_id)
    q = q.order_by(
        Room.sort_order.asc(),
        Room.id.asc(),
        RoomBlock.start_time.asc(),
        RoomBlock.id.asc(),
    )

    rows = (await session.execute(q)).all()
    return [
        ResolvedBlockOut(
            id=block.id,
            room_id=block.room_id,
            room_name=room_name,
            teacher_user_id=block.teacher_user_id,
            teacher_name=teacher_name,
            start_time=block.start_time,
            end_time=block.end_time,
            note=block.note,
            is_recurring=block.weekday is not None,
            specific_date=block.specific_date,
            weekday=block.weekday,
        )
        for block, room_name, teacher_name in rows
    ]


@router.post("/room-blocks", response_model=RoomBlockOut, status_code=201)
async def create_room_block(
    payload: RoomBlockCreateIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    _validate_block_payload(payload)

    room = await session.get(Room, payload.room_id)
    if room is None or room.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="room not found")

    teacher = await session.get(User, payload.teacher_user_id)
    if teacher is None or teacher.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="teacher not found")

    block = RoomBlock(
        org_id=current_user.org_id,
        room_id=payload.room_id,
        teacher_user_id=payload.teacher_user_id,
        weekday=payload.weekday,
        specific_date=payload.specific_date,
        start_time=payload.start_time,
        end_time=payload.end_time,
        note=payload.note,
        created_by=current_user.id,
    )
    session.add(block)
    await session.commit()
    await session.refresh(block)
    return _to_block_out(block)


@router.delete("/room-blocks/{id}", status_code=204)
async def delete_room_block(
    id: int,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    block = await session.get(RoomBlock, id)
    if block is None or block.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="room block not found")
    await session.delete(block)
    await session.commit()


@router.post("/room-blocks/{id}/cancel", status_code=201)
async def cancel_room_block(
    id: int,
    payload: CancelIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    block = await session.get(RoomBlock, id)
    if block is None or block.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="room block not found")
    if block.weekday is None:
        raise HTTPException(
            status_code=400,
            detail="only recurring blocks can be cancelled",
        )

    existing = (
        await session.execute(
            select(RoomBlockException).where(
                RoomBlockException.org_id == current_user.org_id,
                RoomBlockException.block_id == id,
                RoomBlockException.exception_date == payload.date,
            )
        )
    ).scalar_one_or_none()
    if existing is None:
        exception = RoomBlockException(
            org_id=current_user.org_id,
            block_id=id,
            exception_date=payload.date,
        )
        session.add(exception)
    await session.commit()


@router.delete("/room-blocks/{id}/cancel", status_code=204)
async def uncancel_room_block(
    id: int,
    date: date = Query(...),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    block = await session.get(RoomBlock, id)
    if block is None or block.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="room block not found")

    exception = (
        await session.execute(
            select(RoomBlockException).where(
                RoomBlockException.org_id == current_user.org_id,
                RoomBlockException.block_id == id,
                RoomBlockException.exception_date == date,
            )
        )
    ).scalar_one_or_none()
    if exception is not None:
        await session.delete(exception)
    await session.commit()
