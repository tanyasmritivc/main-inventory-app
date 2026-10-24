"""Account memory endpoints are intentionally outside inventory route aliasing."""
from uuid import UUID
from fastapi import APIRouter, Depends
from app.core.auth import AuthenticatedUser, get_current_user
from app.schemas.memory import MemoryChange
from app.services import account_memory

router = APIRouter(tags=['memory'])


@router.get('/memory')
def read_memory(inventory_id: UUID | None = None, user: AuthenticatedUser = Depends(get_current_user)):
    return account_memory.snapshot(account_memory.actor_id(user), inventory_id)


@router.post('/memory')
def change_memory(body: MemoryChange, user: AuthenticatedUser = Depends(get_current_user)):
    return account_memory.change(account_memory.actor_id(user), body)


@router.get('/memory/export')
def export_memory(user: AuthenticatedUser = Depends(get_current_user)):
    return account_memory.export_memory(account_memory.actor_id(user))
