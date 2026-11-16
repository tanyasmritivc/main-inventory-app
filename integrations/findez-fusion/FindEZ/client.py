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
        with request.build_opener(NoRedirect(), request.HTTPSHandler(context=tls_context())).open(req,timeout=90 if path.startswith('/generation/') else 60 if path == '/search' else 30) as response:
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
            raise ClientError('The job, saved request, or inventory changed. Refresh before trying again.') from None
        if path.startswith('/generation/'):
            if exc.code==410:
                raise ClientError('This temporary model has expired or is no longer available. Generate a new model.') from None
            if exc.code in (502,503,504):
                raise ClientError('Model generation is unavailable. Retry the same submission or open My recent generation jobs to resume it; do not change the specification just to retry.') from None
            if exc.code==422:
                raise ClientError('Check the model name, dimensions, units, and clarification answer before retrying.') from None
        if path=='/search' and exc.code in (502,503,504):
            raise ClientError('AI search is temporarily unavailable. Try Keyword search for a part, or BOM > Compare current assembly for this design. [AI-UNAVAILABLE]') from None
        if path=='/search' and exc.code==422:
            raise ClientError('Enter a part name or ask whether you have the parts for your current design. [SEARCH-QUESTION]') from None
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
        return self.request_at(self.generation,path,**kwargs)

    def request_at(self,generation,path,**kwargs):
        with self.lock:
            if generation != self.generation:
                raise ClientError('The connected inventory changed. Start this action again.')
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


def download_step(path, token):
    """Download from FindEZ only; the provider credential never leaves its server."""
    import hashlib
    import tempfile
    if not re.fullmatch(r'/generation/jobs/[a-f0-9-]{36}/download', path):
        raise ClientError('Choose a valid generated model.')
    saved = None
    try:
        req = request.Request(API + path, headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/step'})
        with request.build_opener(NoRedirect(), request.HTTPSHandler(context=tls_context())).open(req, timeout=60) as response:
            size = int(response.headers.get('Content-Length', '0'))
            digest = response.headers.get('X-STEP-SHA256', '')
            if not 0 < size <= 100 * 1024 * 1024 or not re.fullmatch('[a-f0-9]{64}', digest) or response.headers.get_content_type() != 'application/step':
                raise ClientError('The STEP download metadata could not be verified.')
            hasher = hashlib.sha256(); total = 0
            with tempfile.NamedTemporaryFile(prefix='findez-generated-', suffix='.step', delete=False) as output:
                saved = Path(output.name)
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk: break
                    total += len(chunk)
                    if total > size: raise ClientError('The STEP download exceeds its expected size.')
                    hasher.update(chunk); output.write(chunk)
            if total != size or hasher.hexdigest() != digest:
                raise ClientError('The STEP download failed its checksum. Retry before inserting.')
            return str(saved)
    except (error.URLError, OSError, HTTPException, ValueError):
        if saved: saved.unlink(missing_ok=True)
        raise ClientError('The generated model could not be downloaded. Refresh its status and retry.') from None
    except Exception:
        if saved: saved.unlink(missing_ok=True)
        raise
