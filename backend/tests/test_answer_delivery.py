import asyncio
from unittest.mock import AsyncMock, patch
import pytest
from app.services.answer_delivery import answer_chunks, deliver_answer


@pytest.mark.parametrize('text', ['', 'Short answer.', '  **Charger**\n\n- Café 👩🏽‍🔧\n- [Shelf](findez://space/a)  ', 'A long answer with repeated words. ' * 500, 'x' * 10000])
def test_chunks_preserve_exact_final_text_and_bound_delivery(text):
    chunks = list(answer_chunks(text))
    assert ''.join(chunks) == text
    assert len(chunks) <= 40
    assert all(chunks)


def test_delivery_yields_before_wait_and_cancellation_stops_following_chunks():
    async def check():
        with patch('app.services.answer_delivery.asyncio.sleep', new_callable=AsyncMock) as sleep:
            stream = deliver_answer('A final answer with enough words. ' * 10)
            first = await anext(stream)
            assert first
            sleep.assert_not_awaited()
            sleep.side_effect = asyncio.CancelledError()
            with pytest.raises(asyncio.CancelledError):
                await anext(stream)
    asyncio.run(check())
