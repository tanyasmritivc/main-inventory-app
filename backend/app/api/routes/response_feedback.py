"""Authenticated feedback only; no client identities or execution claims accepted."""
from uuid import UUID
from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services import response_feedback as feedback

router = APIRouter(prefix='/response-feedback', tags=['response-feedback'])

@router.get('')
def read(conversation_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return JSONResponse(feedback.list_for_conversation(user.user_id, conversation_id), headers={'Cache-Control': 'private, no-store'})

@router.put('/{message_id}')
@limiter.limit('30/minute')
def rate(request: Request, message_id: UUID, body: feedback.Rating, user: AuthenticatedUser = Depends(get_current_user)):
    return JSONResponse(feedback.submit(user.user_id, message_id, body), headers={'Cache-Control': 'private, no-store'})

@router.delete('')
@limiter.limit('10/minute')
def reset(request: Request, user: AuthenticatedUser = Depends(get_current_user)):
    return feedback.forget(user.user_id)

@router.delete('/{message_id}')
@limiter.limit('30/minute')
def remove(request: Request, message_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return feedback.forget(user.user_id, message_id)
