"""Presentation rules for assistant replies, separate from records and tool data."""

import re


CHAT_STYLE_INSTRUCTION = (
    "Do not use em dashes in replies. Use short sentences, commas, colons, "
    "or parentheses instead."
)


def format_chat_reply(text: str) -> str:
    """Replace any remaining em dash punctuation before emitting or saving a reply."""
    return re.sub(r'[ \t]*\u2014[ \t]*', ' - ', text)
