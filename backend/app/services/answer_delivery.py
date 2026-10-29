"""Deliver only settled, persisted answer text to public chat streams.

Model deltas can precede tool calls, retries and answer repairs. They are private
attempts, not an append-only public answer. Call this after final validation and
history persistence, with the exact text used by the completion receipt.
"""
import asyncio
import math
import re


def answer_chunks(text: str):
    """Keep Unicode words and all Markdown/whitespace intact; bound delivery time."""
    target = max(64, math.ceil(len(text) / 40))
    start = 0
    for token in re.finditer(r"\S+\s*|\s+", text):
        if token.end() - start >= target:
            yield text[start:token.end()]
            start = token.end()
    if start < len(text):
        yield text[start:]


async def deliver_answer(text: str):
    # A short bounded cadence separates received chunks for the clients' existing
    # 180ms fade. It is presentation of finalized text, not model-token streaming.
    first = True
    for chunk in answer_chunks(text):
        if not first:
            await asyncio.sleep(0.025)
        first = False
        yield chunk
