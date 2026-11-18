"""Bounded, transient voice transcription through the server-only provider."""
import io
import wave

import httpx
from fastapi import HTTPException

from app.core.config import get_settings

MAX_AUDIO_BYTES = 2_100_000


def validate_audio(raw: bytes) -> None:
    if not raw or len(raw) > MAX_AUDIO_BYTES:
        raise HTTPException(413, "Record a message of up to one minute.")
    try:
        with wave.open(io.BytesIO(raw), "rb") as audio:
            frames = audio.getnframes()
            if (audio.getnchannels() != 1 or audio.getsampwidth() != 2
                    or audio.getframerate() != 16000 or not 1600 <= frames <= 1_040_000
                    or len(audio.readframes(frames)) != frames * 2):
                raise ValueError("Unsupported recording")
    except (wave.Error, EOFError, ValueError):
        raise HTTPException(422, "Please record your message again.") from None


async def transcribe_audio(raw: bytes) -> str:
    validate_audio(raw)
    key = get_settings().whisper_api_key
    if not key:
        raise HTTPException(503, "Voice input is temporarily unavailable. You can still type your message.")
    try:
        # Fixed destination, no redirects, no audio/transcript logging or storage.
        async with httpx.AsyncClient(timeout=httpx.Timeout(45, connect=10), follow_redirects=False) as client:
            response = await client.post(
                "https://llmtest.ftctools.com/v1/audio/transcriptions",
                headers={"Authorization": f"Bearer {key.get_secret_value()}"},
                files={"file": ("voice.wav", raw, "audio/wav")},
                data={"model": "whisper-large-v3", "response_format": "json"},
            )
        response.raise_for_status()
        text = response.json().get("text")
        if not isinstance(text, str) or len(text) > 10000:
            raise ValueError("Invalid transcription")
        return text.strip()
    except httpx.TimeoutException:
        raise HTTPException(504, "Transcription took too long. Please try again.") from None
    except (httpx.HTTPError, ValueError, AttributeError):
        raise HTTPException(502, "Could not transcribe that recording. Please try again.") from None
