from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.eezy_service import ask_eezy

router = APIRouter(tags=["inventory"])


class EezyChatRequest(BaseModel):
    message: str
    context: str = ""


@router.post("/eezy/chat")
async def eezy_chat(
    body: EezyChatRequest,
    _user: AuthenticatedUser = Depends(get_current_user),
):
    response = await ask_eezy(body.message, body.context)
    return {"response": response}
