import pytest
from fastapi import HTTPException

from app.api.routes.vision import observe_frame, observe_status


def test_see_is_reported_unavailable_without_an_inference_path():
    status = observe_status(_user=object())
    assert status["available"] is False
    assert "Photo" in status["reason"]


def test_observe_fails_fast_instead_of_queueing_frames():
    with pytest.raises(HTTPException) as error:
        observe_frame(_user=object())
    assert error.value.status_code == 503
    assert "Photo" in error.value.detail
