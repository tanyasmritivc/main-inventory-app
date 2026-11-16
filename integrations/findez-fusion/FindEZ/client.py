"""Fixed-origin HTTPS client. Never persists or prints credentials or follows redirects."""
import json
import re
import threading
import socket
import ssl
from functools import lru_cache
from pathlib import Path
from http.client import HTTPException
from urllib import request, error, parse

API = 'https://findez.openstack.ftctools.com/fusion'
MAX_RESPONSE = 8 * 1024 * 1024

class ClientError(Exception):
    pass

class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


@lru_cache(maxsize=1)
def tls_context():
    # Embedded Fusion Python may lack the public roots present in the browser.
    # Add official ISRG roots to system trust; keep hostname/chain checks enabled.
    context = ssl.create_default_context()
    try:
        context.load_verify_locations(cafile=str(Path(__file__).with_name('isrg-roots.pem')))
    except (OSError, ValueError):
        raise ClientError('FindEZ certificate files are missing or damaged. Replace the complete add-in folder and restart Fusion. [TLS-SETUP]') from None
    return context


def network_message(exc):
    reason = exc.reason if isinstance(exc, error.URLError) else exc
    if isinstance(reason, ssl.SSLCertVerificationError):
        return 'Fusion could not verify the FindEZ certificate. Check your computer date and time. If you use a managed network, ask its administrator to check HTTPS inspection for findez.openstack.ftctools.com. [TLS-CERT]'
    if isinstance(reason, ssl.SSLError):
        return 'Fusion could not establish a secure connection to FindEZ. Check your VPN, proxy or firewall settings. [TLS-CONNECT]'
    if isinstance(reason, socket.gaierror):
        return 'Fusion could not find findez.openstack.ftctools.com. Check your internet connection and DNS settings. [DNS]'
    if isinstance(reason, TimeoutError):
        return 'The FindEZ connection timed out. Check your internet connection and try again. [TIMEOUT]'
    return 'Fusion could not connect to findez.openstack.ftctools.com. Check whether your firewall or proxy allows Fusion to reach it. [NETWORK]'


def call(path, *, method='GET', data=None, token=None):
    if not path.startswith('/') or path.startswith('//') or '\\' in path or '#' in path:
        raise ClientError('Invalid FindEZ request.')
    raw = json.dumps(data, allow_nan=False).encode('utf-8') if data is not None else None
    headers = {'Accept':'application/json','Content-Type':'application/json'}
    if token:
        headers['Authorization']='Bearer '+token
    req = request.Request(API+path,data=raw,headers=headers,method=method)
    try:
        with request.build_opener(NoRedirect(), request.HTTPSHandler(context=tls_context())).open(req,timeout=60 if path == '/search' else 30) as response:
            body=response.read(MAX_RESPONSE+1)
            if len(body)>MAX_RESPONSE:
                raise ClientError('This response is too large. Narrow your search.')
            result=json.loads(body)
            if not isinstance(result,dict):
                raise ValueError()
            return result
    except error.HTTPError as exc:
        if exc.code in (401,403):
            raise ClientError('Your connection expired or access changed. Disconnect and sign in again.') from None
        if exc.code==429:
            raise ClientError('Too many requests. Wait a minute and try again.') from None
        if exc.code==409:
            raise ClientError('The connection or inventory changed. Try again.') from None
        raise ClientError('FindEZ could not complete this request. Try again.') from None
    except (error.URLError,OSError,HTTPException) as exc:
        raise ClientError(network_message(exc)) from None
    except ValueError:
        raise ClientError('FindEZ returned an unreadable response. Try again; if it continues, contact FindEZ support. [RESPONSE]') from None


class Session:
    def __init__(self):
        self.token=None
        self.generation=0
        self.lock=threading.Lock()

    def clear(self):
        with self.lock:
            old=self.token
            self.token=None
            self.generation+=1
            return old

    def connect(self,token,generation):
        if not re.fullmatch(r'[A-Za-z0-9_-]{64}',token):
            raise ClientError('FindEZ returned an invalid session.')
        with self.lock:
            if generation!=self.generation:
                return False
            self.token=token
            return True

    def request(self,path,**kwargs):
        with self.lock:
            token=self.token
        if not token:
            raise ClientError('Sign in to FindEZ first.')
        return call(path,token=token,**kwargs)


def search_path(source,query,offset,location=None):
    if source not in ('inventory','catalog') or type(offset) is not int or not 0<=offset<=50000 or not isinstance(query,str) or len(query)>100:
        raise ClientError('Invalid search. Try again.')
    params={'q':query,'offset':offset}
    if source=='inventory' and location is not None:
        if not isinstance(location,str) or len(location)>512:
            raise ClientError('Choose a saved location.')
        params['location']=location
    return '/'+source+'?'+parse.urlencode(params)
