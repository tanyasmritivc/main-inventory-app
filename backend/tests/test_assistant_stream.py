import asyncio

from app.core.assistant_stream import AssistantStreamMiddleware


ID = b'12345678-1234-1234-1234-123456789abc'


def scope(method='POST', token=b'Bearer fixture', path='/worlds/personal/ask'):
    return {'type': 'http', 'method': method, 'path': path, 'query_string': b'',
            'headers': [(b'authorization', token), (b'x-findez-stream-id', ID)] +
                       ([(b'x-findez-stream-read', b'1')] if method == 'GET' else []),
            'asgi': {'spec_version': '2.4'}}


async def receive():
    await asyncio.Future()


def test_mirror_streams_before_completion_without_second_execution():
    async def check():
        release = asyncio.Event()
        first = asyncio.Event()
        calls = 0
        async def app(s, r, send):
            nonlocal calls
            calls += 1
            await send({'type': 'http.response.start', 'status': 200, 'headers': [(b'content-type', b'text/event-stream')]})
            await send({'type': 'http.response.body', 'body': b'data: first\n\n', 'more_body': True})
            first.set()
            await release.wait()
            await send({'type': 'http.response.body', 'body': b'data: done\n\n'})
        middleware = AssistantStreamMiddleware(app)
        original, mirror = [], []
        async def sink(message): original.append(message)
        async def reader(message): mirror.append(message)
        post = asyncio.create_task(middleware(scope(), receive, sink))
        await first.wait()
        get = asyncio.create_task(middleware(scope('GET'), receive, reader))
        for _ in range(10): await asyncio.sleep(0)
        assert [m.get('body') for m in mirror if m['type'].endswith('body')] == [b'data: first\n\n']
        assert not post.done()
        release.set()
        await asyncio.gather(post, get)
        assert calls == 1
        assert b''.join(m.get('body', b'') for m in mirror) == b''.join(m.get('body', b'') for m in original)
    asyncio.run(check())


def test_read_requires_original_bearer_and_exact_scope():
    async def check():
        async def app(s, r, send):
            await send({'type': 'http.response.start', 'status': 403, 'headers': []})
            await send({'type': 'http.response.body', 'body': b'forbidden'})
        middleware = AssistantStreamMiddleware(app)
        async def discard(message): pass
        await middleware(scope(), receive, discard)
        for candidate in (scope('GET', token=b'Bearer another'), scope('GET', path='/worlds/another/ask')):
            output = []
            async def sink(message): output.append(message)
            await middleware(candidate, receive, sink)
            assert output[0]['status'] == 404
            assert b'forbidden' not in b''.join(m.get('body', b'') for m in output)
    asyncio.run(check())


def test_bounded_mirror_never_truncates_original_response():
    async def check():
        async def app(s, r, send):
            await send({'type': 'http.response.start', 'status': 200, 'headers': []})
            await send({'type': 'http.response.body', 'body': b'abcdef'})
        middleware = AssistantStreamMiddleware(app)
        middleware.max_entry_bytes = 3
        output = []
        async def sink(message): output.append(message)
        await middleware(scope(), receive, sink)
        assert output[-1]['body'] == b'abcdef'
        assert next(iter(middleware.entries.values())).size == 0
        middleware.ttl = -1
        middleware._prune()
        assert not middleware.entries
    asyncio.run(check())


def test_disconnected_reader_does_not_cancel_the_post():
    async def check():
        release, first = asyncio.Event(), asyncio.Event()
        async def app(s, r, send):
            await send({'type': 'http.response.start', 'status': 200, 'headers': []})
            await send({'type': 'http.response.body', 'body': b'first', 'more_body': True})
            first.set()
            await release.wait()
            await send({'type': 'http.response.body', 'body': b'done'})
        middleware = AssistantStreamMiddleware(app)
        output = []
        async def sink(message): output.append(message)
        async def discard(message): pass
        post = asyncio.create_task(middleware(scope(), receive, sink))
        await first.wait()
        reader = asyncio.create_task(middleware(scope('GET'), receive, discard))
        await asyncio.sleep(0)
        reader.cancel()
        try: await reader
        except asyncio.CancelledError: pass
        assert not post.done()
        release.set()
        await post
        assert output[-1]['body'] == b'done'
        assert next(iter(middleware.entries.values())).readers == 0
    asyncio.run(check())


def test_requests_without_native_header_are_unchanged():
    async def check():
        calls = []
        async def app(s, r, send): calls.append(s)
        middleware = AssistantStreamMiddleware(app)
        candidate = scope()
        candidate['headers'] = []
        async def discard(message): pass
        await middleware(candidate, receive, discard)
        assert calls == [candidate]
        assert not middleware.entries
    asyncio.run(check())
