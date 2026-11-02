"""Reject empty requests before a model call or quota consumption."""
import pytest
from pydantic import ValidationError
from app.schemas.ai import AICommandRequest


@pytest.mark.parametrize('message', ['', ' ', '\n\t', '\u2003'])
def test_empty_chat_rejected(message):
    with pytest.raises(ValidationError):
        AICommandRequest(message=message)


def test_chat_trims_edges_without_changing_content():
    assert AICommandRequest(message='  Where is\nmy bolt?  ').message == 'Where is\nmy bolt?'
