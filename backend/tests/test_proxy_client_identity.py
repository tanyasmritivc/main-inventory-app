import asyncio
from fastapi import Request
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware
from app.core.auth import _client_ip
from app.main import _client_ip as logged_ip


def test_forged_forwarding_prefix_does_not_control_client_identity():
    observed=[]
    async def app(scope,receive,send):
        request=Request(scope)
        observed.append((_client_ip(request),logged_ip(request)))
    middleware=ProxyHeadersMiddleware(app,trusted_hosts=['127.0.0.1'])
    for peer,forwarded,expected in [('127.0.0.1',b'forged, 203.0.113.8','203.0.113.8'),('203.0.113.9',b'forged','203.0.113.9')]:
        scope={'type':'http','client':(peer,12345),'scheme':'http','headers':[(b'x-forwarded-for',forwarded)]}
        asyncio.run(middleware(scope,None,None))
        assert observed[-1]==(expected,expected)
