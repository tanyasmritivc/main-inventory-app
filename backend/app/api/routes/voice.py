from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from pydantic import BaseModel

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.voice_transcription import MAX_AUDIO_BYTES, transcribe_audio

router = APIRouter(tags=["voice"])


class TranscriptionResponse(BaseModel):
    text: str


@router.post("/voice/transcriptions", response_model=TranscriptionResponse)
@limiter.limit("10/minute")
async def transcribe_voice(
    request: Request,
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> TranscriptionResponse:
    try:
        if file.content_type not in {"audio/wav", "audio/x-wav", "audio/wave"}:
            raise HTTPException(415, "Please record your message again.")
        raw = await file.read(MAX_AUDIO_BYTES + 1)
        return TranscriptionResponse(text=await transcribe_audio(raw))
    finally:
        await file.close()
