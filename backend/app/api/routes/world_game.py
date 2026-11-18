"""Additive World routes. Inventory creation continues through existing item APIs."""
from uuid import UUID
from fastapi import APIRouter, Depends, Request, Response
from app.core.limiter import limiter
from app.core.auth import AuthenticatedUser, get_current_user
from app.schemas import world_game as body
from app.services import world_game as service

router = APIRouter(tags=['world-game'])


@router.get('/world/spaces')
def spaces(user: AuthenticatedUser = Depends(get_current_user)):
    return service.spaces(user.user_id)


@router.get('/world/me')
def me(user: AuthenticatedUser = Depends(get_current_user)):
    return service.me(user.user_id)


@router.put('/world/layouts/{space_id}')
def layout(space_id: UUID, payload: body.SaveLayout, user: AuthenticatedUser = Depends(get_current_user)):
    return service.save_layout(user.user_id, space_id, payload)


@router.post('/world/spaces/{space_id}/storage-areas')
def area(space_id: UUID, payload: body.Area, user: AuthenticatedUser = Depends(get_current_user)):
    return service.create_area(user.user_id, space_id, payload)


@router.put('/world/placements/{item_id}')
def placement(item_id: UUID, payload: body.Placement, user: AuthenticatedUser = Depends(get_current_user)):
    return service.place(user.user_id, item_id, payload)


@router.post('/world/events')
def event(payload: body.Event, user: AuthenticatedUser = Depends(get_current_user)):
    return service.award(user.user_id, payload.kind, payload.ref, payload.value.model_dump(mode='json') if payload.value else None)


@router.post('/world/quests/{quest_id}/claim')
def claim(quest_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    return service.award(user.user_id, 'quest', quest_id)


@router.get('/world/daily')
def daily(scope_id: UUID | None = None, user: AuthenticatedUser = Depends(get_current_user)):
    return service.daily(user.user_id, scope_id)


@router.post('/world/daily/score')
def score(payload: body.DailyScore, user: AuthenticatedUser = Depends(get_current_user)):
    return service.score(user.user_id, payload)


@router.get('/world/daily/leaderboard')
def leaderboard(scope_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return service.leaderboard(user.user_id, scope_id)


@router.post('/world/shares')
def share_create(payload: body.ShareCreate, user: AuthenticatedUser = Depends(get_current_user)):
    return service.share_create(user.user_id, payload)


@router.get('/world/shares')
def shares(space: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return service.shares(user.user_id, space)


@router.patch('/world/shares/{share_id}')
def share_patch(share_id: UUID, payload: body.SharePatch, user: AuthenticatedUser = Depends(get_current_user)):
    return service.share_patch(user.user_id, share_id, payload)


@router.get('/public/world/s/{token}')
@limiter.limit('30/minute')
def public_room(token: str, request: Request, response: Response):
    response.headers['Cache-Control'] = 'no-store, max-age=0'
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['X-Robots-Tag'] = 'noindex, nofollow'
    return service.public_room(token)
