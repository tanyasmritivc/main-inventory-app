"""Normalize model chunks without inventing text or exposing tool arguments."""
from types import SimpleNamespace
from time import monotonic
from app.services.chat_response_style import format_chat_reply

MAX_TOOL_CALLS = 16


class CompletionStreamError(RuntimeError):
    """A fixed parser reason safe to log; never contains provider text or arguments."""
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def completion_events(response, *, report_activity=False, thinking_message='Thinking through your request...'):
    """Yield text deltas then the assembled model message.

    The gateway can deliver a whole model message in one event. Support that
    representation as well as incremental delta/tool-call fragments.
    """
    chunks = (response,) if hasattr(response, 'choices') else response
    parts, calls = [], {}
    emitted = ""
    activity = None
    activity_started = monotonic()
    still_reported = False
    last_update = None
    try:
        for chunk in chunks:
            choices = getattr(chunk, 'choices', None) or []
            if not choices:
                continue
            choice = choices[0]
            delta = getattr(choice, 'delta', None) or getattr(choice, 'message', None)
            if delta is None:
                continue
            # Liveness is evidence of a received model chunk, not a timer claiming
            # that a stalled provider is still working. No content leaves here.
            if report_activity and any(getattr(delta, key, None) for key in ('reasoning_content', 'content', 'tool_calls')):
                now = monotonic()
                if last_update is None or now - last_update >= 5:
                    last_update = now
                    yield {'type': 'activity', 'source': 'model'}
            # Only fixed activity labels leave this boundary. Never expose or
            # summarize reasoning text, tool arguments, or arbitrary tool names.
            if report_activity and not activity and getattr(delta, 'reasoning_content', None):
                activity = thinking_message
                activity_started = monotonic()
                yield {'type': 'status', 'message': activity}
            for fallback_index, call in enumerate(getattr(delta, 'tool_calls', None) or []):
                index = getattr(call, 'index', None)
                index = fallback_index if index is None else index
                # Five legitimate lookups previously failed at index 4 and
                # restarted generation. Bound the batch, not a four-item task.
                if type(index) is not int or not 0 <= index < MAX_TOOL_CALLS:
                    raise CompletionStreamError('tool_index', 'Invalid model tool index')
                entry = calls.setdefault(index, {'id': '', 'name': '', 'arguments': ''})
                function = getattr(call, 'function', None)
                entry['id'] += getattr(call, 'id', None) or ''
                entry['name'] += getattr(function, 'name', None) or ''
                entry['arguments'] += getattr(function, 'arguments', None) or ''
                if len(entry['arguments']) > 8000 or len(entry['name']) > 200 or len(entry['id']) > 300:
                    raise CompletionStreamError('tool_size', 'Model tool call is too large')
            if report_activity and calls:
                from app.services.chat_progress import planning_status
                label = planning_status(next(iter(calls.values()))['name'])
                if activity != label:
                    activity = label
                    activity_started = monotonic()
                    still_reported = False
                    yield {'type': 'status', 'message': label}
            if report_activity and activity and not still_reported and monotonic() - activity_started >= 15:
                still_reported = True
                yield {'type': 'status', 'message': 'Still ' + activity[0].lower() + activity[1:]}
            content = getattr(delta, 'content', None)
            if content:
                if not isinstance(content, str):
                    raise CompletionStreamError('text_type', 'Invalid model text')
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
                raise CompletionStreamError('output_limit' if choice.finish_reason == 'length' else 'content_filter', 'The model answer was interrupted')
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
    async for event in async_iterate(completion_events(response)):
        yield event


async def async_iterate(iterator):
    import asyncio
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
