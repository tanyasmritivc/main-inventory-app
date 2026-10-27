"""Public extraction milestones from the actual pipeline, not timed guesses."""
import asyncio
import json
import logging
from fastapi import HTTPException


async def stream_extraction(extract):
    queue = asyncio.Queue()
    loop = asyncio.get_running_loop()
    active = True
    def report(message):
        if active:
            loop.call_soon_threadsafe(queue.put_nowait, str(message)[:200])
    def encode(event):
        return 'data: ' + json.dumps(event) + '\n\n'
    yield encode({'type': 'status', 'message': 'Preparing your photo...'})
    task = asyncio.create_task(extract(report))
    try:
        while not task.done() or not queue.empty():
            try:
                update = await asyncio.wait_for(queue.get(), timeout=1)
                yield encode({'type': 'status', 'message': update})
            except asyncio.TimeoutError:
                yield ': keep-alive\n\n'
        result = await task
        await asyncio.sleep(0)  # Flush thread-safe callbacks queued just before completion.
        while not queue.empty():
            yield encode({'type': 'status', 'message': queue.get_nowait()})
        yield encode({'type': 'done', 'result': result.model_dump()})
    except HTTPException as error:
        detail = error.detail if isinstance(error.detail, str) else 'Photo analysis could not finish. Please retry.'
        yield encode({'type': 'error', 'message': detail})
    except Exception:
        logging.getLogger(__name__).exception('Extraction stream failed')
        yield encode({'type': 'error', 'message': 'Photo analysis could not finish. Please retry.'})
    finally:
        active = False
        # Worker-backed uploads must settle. A disconnected client cannot cause
        # a second extraction or an unobserved exception.
        if not task.done():
            try:
                await asyncio.shield(task)
            except Exception:
                pass
