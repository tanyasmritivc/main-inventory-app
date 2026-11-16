"""Embedded-runtime TLS trust and credential-safe connection failures."""
import importlib.util
import socket
import ssl
from pathlib import Path
from unittest.mock import Mock
from urllib.error import URLError

import pytest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('fusion_transport_test', ROOT / 'integrations/findez-fusion/FindEZ/client.py')
client = importlib.util.module_from_spec(spec)
spec.loader.exec_module(client)


def test_bundled_roots_work_without_system_trust_and_keep_verification(monkeypatch):
    client.tls_context.cache_clear()
    empty = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    assert empty.cert_store_stats()['x509_ca'] == 0
    monkeypatch.setattr(client.ssl, 'create_default_context', lambda: empty)
    try:
        context = client.tls_context()
        assert context.cert_store_stats()['x509_ca'] == 2
        assert context.verify_mode == ssl.CERT_REQUIRED
        assert context.check_hostname
        subjects = {cert['subject'][-1][0][1] for cert in context.get_ca_certs()}
        assert subjects == {'ISRG Root X1', 'ISRG Root X2'}
    finally:
        client.tls_context.cache_clear()


@pytest.mark.parametrize('failure,code', [
    (URLError(ssl.SSLCertVerificationError(1, 'private connection detail')), '[TLS-CERT]'),
    (URLError(ssl.SSLError(1, 'private connection detail')), '[TLS-CONNECT]'),
    (URLError(socket.gaierror(-2, 'private connection detail')), '[DNS]'),
    (URLError(TimeoutError('private connection detail')), '[TIMEOUT]'),
    (TimeoutError('private connection detail'), '[TIMEOUT]'),
    (URLError(ConnectionRefusedError('private connection detail')), '[NETWORK]'),
])
def test_transport_errors_are_actionable_without_raw_details(monkeypatch, failure, code):
    opener = Mock(); opener.open.side_effect = failure
    monkeypatch.setattr(client.request, 'build_opener', lambda *args: opener)
    with pytest.raises(client.ClientError) as error:
        client.call('/pairing', method='POST')
    assert code in str(error.value)
    assert 'private connection detail' not in str(error.value)


def test_invalid_json_is_not_reported_as_network_failure(monkeypatch):
    response = Mock(); response.read.return_value = b'<html>private response</html>'
    opener = Mock(); opener.open.return_value.__enter__ = Mock(return_value=response)
    opener.open.return_value.__exit__ = Mock(return_value=False)
    monkeypatch.setattr(client.request, 'build_opener', lambda *args: opener)
    with pytest.raises(client.ClientError, match=r'\[RESPONSE\]'):
        client.call('/pairing', method='POST')


def test_missing_certificate_file_fails_closed(monkeypatch):
    client.tls_context.cache_clear()
    context = Mock(); context.load_verify_locations.side_effect = FileNotFoundError()
    monkeypatch.setattr(client.ssl, 'create_default_context', lambda: context)
    try:
        with pytest.raises(client.ClientError, match='TLS-SETUP'):
            client.tls_context()
    finally:
        client.tls_context.cache_clear()


@pytest.mark.parametrize('status,code',[(503,'AI-UNAVAILABLE'),(502,'AI-UNAVAILABLE'),(504,'AI-UNAVAILABLE'),(422,'SEARCH-QUESTION')])
def test_search_http_errors_offer_a_safe_action(monkeypatch,status,code):
    from urllib.error import HTTPError
    opener=Mock();opener.open.side_effect=HTTPError('https://example.invalid',status,'private response',{},None)
    monkeypatch.setattr(client.request,'build_opener',lambda *args:opener)
    with pytest.raises(client.ClientError) as exc:client.call('/search',method='POST',data={'query':'parts'})
    assert code in str(exc.value)
    assert 'private response' not in str(exc.value)
