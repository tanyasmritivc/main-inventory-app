from types import SimpleNamespace as NS
import pytest
from app.services.answer_delivery import stream_final_answer


def chunk(text='', calls=None):
    return NS(choices=[NS(delta=NS(content=text, tool_calls=calls), finish_reason=None)])


def test_first_delta_arrives_before_provider_finishes_without_replay():
    reached_end = False
    def provider():
        nonlocal reached_end
        yield chunk('The charger')
        yield chunk(' is on shelf 2.')
        reached_end = True
    stream = stream_final_answer(provider(), validate=lambda text: None)
    assert next(stream) == {'type': 'delta', 'delta': 'The charger'}
    assert not reached_end
    assert next(stream) == {'type': 'delta', 'delta': ' is on shelf 2.'}
    with pytest.raises(StopIteration) as done:
        next(stream)
    assert done.value.value == 'The charger is on shelf 2.'
    assert reached_end


def test_interruption_keeps_prefix_and_does_not_restart():
    def provider():
        yield chunk('Visible prefix')
        raise RuntimeError('interrupted')
    stream = stream_final_answer(provider(), validate=lambda text: None)
    assert next(stream)['delta'] == 'Visible prefix'
    with pytest.raises(RuntimeError, match='interrupted'):
        next(stream)


def test_validation_runs_before_any_rejected_chunk_is_published():
    def validate(text):
        if 'saved' in text:
            raise RuntimeError('unconfirmed')
    stream = stream_final_answer(iter([chunk('I '), chunk('saved the item.')]), validate=validate)
    assert next(stream)['delta'] == 'I'
    with pytest.raises(RuntimeError, match='unconfirmed'):
        next(stream)
