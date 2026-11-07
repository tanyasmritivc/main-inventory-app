"""A bounded, read-only mirror of an already authorized native POST response.

The iOS background upload owns the request. A foreground reader sees the same
bytes promptly without starting another model call or write. Entries exist only
in this worker's memory; failure or another worker falls back to the upload's
response. Nothing is logged or persisted.
"""

import asyncio
import hashlib
import re
import time
from dataclasses import dataclass, field

from starlette.responses import Response, StreamingResponse


@dataclass
class _Stream:
    created: float = field(default_factory=time.monotonic)
    start: dict | None = None
    chunks: list[bytes] = field(default_factory=list)
    size: int = 0
    done: bool = False
    readers: int = 0
    changed: asyncio.Event = field(default_factory=asyncio.Event)


class AssistantStreamMiddleware:
    max_entries = 64
    max_bytes = 16 * 1024 * 1024
    max_entry_bytes = 2 * 1024 * 1024
    ttl = 600

    def __init__(self, app):
        self.app = app
        self.entries: dict[bytes, _Stream] = {}

    def _prune(self):
        cutoff = time.monotonic() - self.ttl
        for key, entry in list(self.entries.items()):
            if entry.created < cutoff:
                entry.done = True
                entry.changed.set()
                del self.entries[key]

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            return await self.app(scope, receive, send)
        headers = dict(scope['headers'])
        stream_id = headers.get(b'x-findez-stream-id', b'')
        bearer = headers.get(b'authorization', b'')
        if not re.fullmatch(rb'[a-fA-F0-9-]{36}', stream_id) or not bearer.startswith(b'Bearer '):
            return await self.app(scope, receive, send)
        self._prune()
        # The exact bearer, path and query must match the originating request.
        key = hashlib.sha256(b'\0'.join((bearer, stream_id, scope['path'].encode(), scope.get('query_string', b'')))).digest()
        reading = scope['method'] == 'GET' and headers.get(b'x-findez-stream-read') == b'1'
        if reading:
            entry = self.entries.get(key)
            if entry is None or entry.readers >= 1:
                return await Response(status_code=404)(scope, receive, send)
            entry.readers += 1
            try:
                async def body():
                    index = 0
                    while True:
                        entry.changed.clear()
                        while index < len(entry.chunks):
                            yield entry.chunks[index]
                            index += 1
                        if entry.done:
                            return
                        try:
                            await asyncio.wait_for(entry.changed.wait(), 30)
                        except TimeoutError:
                            if time.monotonic() - entry.created >= self.ttl:
                                return
                while entry.start is None and not entry.done:
                    entry.changed.clear()
                    try:
                        await asyncio.wait_for(entry.changed.wait(), 30)
                    except TimeoutError:
                        return await Response(status_code=404)(scope, receive, send)
                if entry.start is None:
                    return await Response(status_code=404)(scope, receive, send)
                response = StreamingResponse(body(), status_code=entry.start['status'])
                response.raw_headers = [(k, v) for k, v in entry.start['headers'] if k.lower() in (b'content-type', b'content-encoding')]
                response.raw_headers += [(b'x-findez-stream-ready', b'1'), (b'cache-control', b'no-store'), (b'x-accel-buffering', b'no')]
                await response(scope, receive, send)
            finally:
                entry.readers -= 1
            return
        if scope['method'] != 'POST' or key in self.entries or len(self.entries) >= self.max_entries:
            return await self.app(scope, receive, send)
        entry = _Stream()
        self.entries[key] = entry

        async def tee(message):
            if message['type'] == 'http.response.start':
                entry.start = message.copy()
            elif message['type'] == 'http.response.body':
                chunk = message.get('body', b'')
                if not entry.done:
                    if entry.size + len(chunk) > self.max_entry_bytes or sum(e.size for e in self.entries.values()) + len(chunk) > self.max_bytes:
                        # Native upload still receives the complete original response.
                        entry.done = True
                    else:
                        entry.chunks.append(chunk)
                        entry.size += len(chunk)
                if not message.get('more_body', False):
                    entry.done = True
            entry.changed.set()
            await send(message)
        try:
            await self.app(scope, receive, tee)
        finally:
            entry.done = True
            entry.changed.set()
            # Expiry also runs without another incoming request.
            asyncio.get_running_loop().call_later(self.ttl, self._prune)
