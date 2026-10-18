"""Normalize model chunks without inventing text or exposing tool arguments."""
from types import SimpleNamespace
from app.services.chat_response_style import format_chat_reply


def completion_events(response):
    """Yield text deltas then the assembled model message.

    The gateway can deliver a whole model message in one event. Support that
    representation as well as incremental delta/tool-call fragments.
    """
    chunks = (response,) if hasattr(response, 'choices') else response
    parts, calls = [], {}
    emitted = ""
    try:
        for chunk in chunks:
            choices = getattr(chunk, 'choices', None) or []
            if not choices:
                continue
            choice = choices[0]
            delta = getattr(choice, 'delta', None) or getattr(choice, 'message', None)
            if delta is None:
                continue
            for fallback_index, call in enumerate(getattr(delta, 'tool_calls', None) or []):
                index = getattr(call, 'index', None)
                index = fallback_index if index is None else index
                if not isinstance(index, int) or not 0 <= index < 4:
                    raise RuntimeError('Invalid model tool index')
                entry = calls.setdefault(index, {'id': '', 'name': '', 'arguments': ''})
                function = getattr(call, 'function', None)
                entry['id'] += getattr(call, 'id', None) or ''
                entry['name'] += getattr(function, 'name', None) or ''
                entry['arguments'] += getattr(function, 'arguments', None) or ''
                if len(entry['arguments']) > 8000 or len(entry['name']) > 200 or len(entry['id']) > 300:
                    raise RuntimeError('Model tool call is too large')
            content = getattr(delta, 'content', None)
            if content:
                if not isinstance(content, str):
                    raise RuntimeError('Invalid model text')
                parts.append(content)
                if not calls:
                    # Keep punctuation identical to the saved answer, even when
                    # whitespace around an em dash spans several network chunks.
                    safe = format_chat_reply(''.join(parts)).rstrip(' \t')
                    delta = safe[len(emitted):]
                    emitted = safe
                    if delta:
                        yield {'type': 'delta', 'delta': delta}
            if getattr(choice, 'finish_reason', None) in ('length', 'content_filter'):
                raise RuntimeError('The model answer was interrupted')
        normalized = format_chat_reply(''.join(parts))
        if not calls and len(normalized) > len(emitted):
            yield {'type': 'delta', 'delta': normalized[len(emitted):]}
        yield {'type': 'completion', 'content': normalized, 'tool_calls': [
            SimpleNamespace(id=value['id'], function=SimpleNamespace(name=value['name'], arguments=value['arguments']))
            for _, value in sorted(calls.items())]}
    finally:
        close = getattr(response, 'close', None)
        if close:
            close()


async def async_completion_events(response):
    """Read blocking HTTP chunks off the event loop, one at a time."""
    import asyncio
    iterator = completion_events(response)
    sentinel = object()
    try:
        while True:
            # Shield the read so cancellation never closes an executing generator.
            pending = asyncio.create_task(asyncio.to_thread(next, iterator, sentinel))
            try:
                event = await asyncio.shield(pending)
            except asyncio.CancelledError:
                def close_after_read(task):
                    try:
                        task.result()
                    except BaseException:
                        pass
                    iterator.close()
                pending.add_done_callback(close_after_read)
                raise
            if event is sentinel:
                return
            yield event
    finally:
        if pending.done():
            iterator.close()
