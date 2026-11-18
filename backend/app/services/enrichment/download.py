"""Bounded public HTTPS download with DNS pinning, then image normalization."""
import http.client
import io
import ipaddress
import socket
import ssl
import time
from urllib.parse import urlsplit, urljoin
from PIL import Image, ImageOps
from .photos import public_https

MAX_BYTES = 5 * 1024 * 1024


def download_photo(url):
    deadline = time.monotonic() + 30
    for _ in range(4):
        if time.monotonic() > deadline:
            raise ValueError("The source photo took too long.")
        if not public_https(url):
            raise ValueError('The source image address is unavailable.')
        parsed = urlsplit(url)
        addresses = socket.getaddrinfo(parsed.hostname, 443, type=socket.SOCK_STREAM)
        if not addresses or any(not ipaddress.ip_address(info[4][0]).is_global for info in addresses):
            raise ValueError('The source image address is unavailable.')
        address = addresses[0][4][0]
        class PinnedHTTPS(http.client.HTTPSConnection):
            def connect(self):
                connection = socket.create_connection((address, 443), timeout=10)
                self.sock = ssl.create_default_context().wrap_socket(connection, server_hostname=parsed.hostname)
        connection = PinnedHTTPS(parsed.hostname, timeout=10)
        try:
            path = parsed.path or '/'
            if parsed.query:
                path += '?' + parsed.query
            connection.request('GET', path, headers={'User-Agent': 'FindEZ product-image-review/1.0', 'Accept': 'image/*'})
            response = connection.getresponse()
            if response.status in (301, 302, 303, 307, 308):
                url = urljoin(url, response.getheader('Location') or '')
                continue
            if response.status != 200 or not (response.getheader('Content-Type') or '').lower().startswith('image/'):
                raise ValueError('The source did not return a photo.')
            content = bytearray()
            while True:
                if time.monotonic() > deadline:
                    raise ValueError('The source photo took too long.')
                chunk = response.read1(min(65536, MAX_BYTES + 1 - len(content)))
                if not chunk: break
                content.extend(chunk)
                if len(content) > MAX_BYTES:
                    raise ValueError('The source photo is too large.')
            with Image.open(io.BytesIO(content)) as original:
                if original.format not in ('JPEG', 'PNG', 'WEBP', 'GIF'):
                    raise ValueError('The source is not a supported product photo.')
                if original.width * original.height > 25_000_000:
                    raise ValueError('The source photo is too large.')
                photo = ImageOps.exif_transpose(original).convert('RGB')
                photo.thumbnail((1600, 1600))
                output = io.BytesIO(); photo.save(output, 'JPEG', quality=90)
                return output.getvalue()
        finally:
            connection.close()
    raise ValueError('The source redirected too many times.')
