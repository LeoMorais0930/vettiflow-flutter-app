"""Teste da barreira real de autenticação, sem bypass de sessão."""
import base64
import json
import time

import httpx
import pytest
from fastapi.testclient import TestClient

from app import config, mssql
from app.main import app


def jwt(exp=None):
    payload = base64.urlsafe_b64encode(json.dumps({
        'sub': 'operador', 'exp': exp or time.time() + 300,
    }).encode()).decode().rstrip('=')
    return 'eyJhbGciOiJIUzI1NiJ9.' + payload + '.assinatura-fixture'


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', 'test-key')
    monkeypatch.setattr(config, 'PROTHEUS_REST_URL', 'https://erp.test/rest')
    monkeypatch.setattr(mssql, 'health', lambda: {'banco': 'HMLp12'})
    with TestClient(app, headers={'X-API-Token': 'test-key'}) as client:
        yield client


def login(client, monkeypatch, token=None):
    token = token or jwt()
    monkeypatch.setattr(httpx, 'post', lambda *a, **k: httpx.Response(201, json={
        'access_token': token, 'token_type': 'Bearer', 'expires_in': 300,
    }))
    return client.post('/api/v1/auth/protheus/login', headers={
        'username': 'operador', 'password': 'senha-fixture'})


def test_api_key_alone_blocks_every_business_route(client):
    # Não deixa chegar nem à validação do payload, nem ao banco.
    for path, operations in app.openapi()['paths'].items():
        if not path.startswith('/api/v1/') or path.startswith('/api/v1/auth/'):
            continue
        for method in operations:
            response = client.request(method, path)
            assert response.status_code == 401, (method, path, response.status_code)


def test_login_session_and_logout(client, monkeypatch):
    response = login(client, monkeypatch)
    assert response.status_code == 200
    data = response.json()
    assert data['token_type'] == 'Bearer'
    assert 'refresh_token' not in data
    assert response.headers['cache-control'] == 'no-store'
    headers = {'Authorization': 'Bearer ' + data['access_token']}
    assert client.get('/api/v1/health', headers=headers).status_code == 200
    session = client.get('/api/v1/auth/protheus/session', headers=headers)
    assert session.json()['username'] == 'operador'
    assert client.post('/api/v1/auth/protheus/logout', headers=headers).status_code == 200
    assert client.get('/api/v1/health', headers=headers).status_code == 401


def test_forged_or_modified_token_denied(client, monkeypatch):
    token = jwt()
    assert client.get('/api/v1/health', headers={'Authorization': 'Bearer ' + token}).status_code == 401
    login(client, monkeypatch, token)
    assert client.get('/api/v1/health', headers={'Authorization': 'Bearer ' + token + 'x'}).status_code == 401


def test_expiration(client, monkeypatch):
    response = login(client, monkeypatch)
    assert response.status_code == 200
    from app import sessions
    monkeypatch.setattr(sessions.time, 'time', lambda: 9999999999)
    assert client.get('/api/v1/health', headers={
        'Authorization': 'Bearer ' + response.json()['access_token']}).status_code == 401


def test_refresh_rotates_access_without_exposing_refresh_secret(client, monkeypatch):
    old, new = jwt(), jwt(time.time() + 600)
    def post(url, **kwargs):
        if kwargs['params']['grant_type'] == 'password':
            return httpx.Response(201, json={'access_token': old, 'token_type': 'Bearer',
                                           'expires_in': 300, 'refresh_token': 'secret-refresh'})
        assert kwargs['params']['grant_type'] == 'refresh_token'
        assert kwargs['headers']['refresh_token'] == 'secret-refresh'
        assert 'password' not in kwargs['headers']
        return httpx.Response(201, json={'access_token': new, 'token_type': 'Bearer',
                                       'expires_in': 600, 'refresh_token': 'rotated-secret'})
    monkeypatch.setattr(httpx, 'post', post)
    first = client.post('/api/v1/auth/protheus/login', headers={'username': 'operador', 'password': 'fixture'})
    assert first.json()['refreshAvailable'] is True
    renewed = client.post('/api/v1/auth/protheus/refresh', headers={'Authorization': 'Bearer ' + old})
    assert renewed.status_code == 200
    assert renewed.json()['access_token'] == new
    assert 'secret' not in renewed.text
    assert client.get('/api/v1/health', headers={'Authorization': 'Bearer ' + old}).status_code == 401
    assert client.get('/api/v1/health', headers={'Authorization': 'Bearer ' + new}).status_code == 200
    client.post('/api/v1/auth/protheus/logout', headers={'Authorization': 'Bearer ' + new})
    assert client.post('/api/v1/auth/protheus/refresh', headers={'Authorization': 'Bearer ' + new}).status_code == 401


@pytest.mark.parametrize('token', ['not-a-jwt', jwt(1)])
def test_invalid_upstream_token_does_not_create_session(client, monkeypatch, token):
    assert login(client, monkeypatch, token).status_code == 502


def test_probe_forwards_token_only_and_revokes_on_401(client, monkeypatch):
    response = login(client, monkeypatch)
    assert response.status_code == 200
    token = response.json()['access_token']
    headers = {'Authorization': 'Bearer ' + token}
    def get(url, **kwargs):
        assert url == 'https://erp.test/rest/api/pcp/v1/prodOrders/fields'
        assert kwargs['headers']['Authorization'] == 'Bearer ' + token
        assert 'password' not in kwargs['headers']
        assert kwargs['follow_redirects'] is False
        return httpx.Response(401)
    monkeypatch.setattr(httpx, 'get', get)
    assert client.post('/api/v1/auth/protheus/probe', headers=headers).status_code == 401
    assert client.get('/api/v1/health', headers=headers).status_code == 401


def test_no_loopback_jwt_bypass(client, monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    assert client.get('/api/v1/health').status_code == 401


def test_target_change_invalidates_session(client, monkeypatch):
    response = login(client, monkeypatch)
    headers = {'Authorization': 'Bearer ' + response.json()['access_token']}
    monkeypatch.setattr(config, 'FILIAL_PADRAO', '01')
    assert client.get('/api/v1/health', headers=headers).status_code == 401


@pytest.mark.parametrize('status,expected', [(200, 200), (403, 403), (404, 502), (302, 502)])
def test_probe_outcomes(client, monkeypatch, status, expected):
    response = login(client, monkeypatch)
    headers = {'Authorization': 'Bearer ' + response.json()['access_token']}
    monkeypatch.setattr(httpx, 'get', lambda *a, **k: httpx.Response(status, json={'fields': []}))
    result = client.post('/api/v1/auth/protheus/probe', headers=headers)
    assert result.status_code == expected
    assert 'access_token' not in result.text


def test_restart_invalidates_session(client, monkeypatch):
    response = login(client, monkeypatch)
    from app import sessions
    monkeypatch.setattr(sessions, '_active', {})
    assert client.get('/api/v1/health', headers={
        'Authorization': 'Bearer ' + response.json()['access_token']}).status_code == 401


def test_swagger_requires_both_credentials_for_business(client):
    paths = client.get('/openapi.json').json()['paths']
    assert paths['/api/v1/health']['get']['security'] == [{'APIKeyHeader': [], 'ProtheusJWT': []}]
    assert paths['/api/v1/auth/protheus/login']['post']['security'] == [{'APIKeyHeader': []}]


@pytest.mark.parametrize('token,lifetime,reason', [
    ('not-a-jwt', 3600, 'jwt_format'),
    ('header.bm90LWpzb24.signature', 3600, 'jwt_payload'),
    ('header.e30.signature', 3600, 'exp_missing'),
    (jwt(), None, 'expires_in_missing'),
    (jwt(), 'abc', 'expires_in_invalid'),
    (jwt(1), 3600, 'token_expired'),
    (jwt(), 0, 'expires_in_invalid'),
])
def test_expiration_errors_have_safe_specific_reason(client, monkeypatch, token, lifetime, reason):
    monkeypatch.setattr(httpx, 'post', lambda *a, **k: httpx.Response(201, json={
        'access_token': token, 'token_type': 'Bearer', 'expires_in': lifetime,
    }))
    result = client.post('/api/v1/auth/protheus/login', headers={
        'username': 'operador', 'password': 'senha-fixture'})
    assert result.status_code == 502
    assert result.json()['detail']['code'] == reason
    assert token not in result.text and 'senha-fixture' not in result.text


def test_expired_token_reports_issuance_delta_without_identity_or_token(client, monkeypatch):
    now = time.time()
    payload = base64.urlsafe_b64encode(json.dumps({
        'exp': now - 3, 'iat': now - 3603, 'sub': 'private-identity',
    }).encode()).decode().rstrip('=')
    token = 'header.' + payload + '.signature'
    result = login(client, monkeypatch, token)
    detail = result.json()['detail']
    assert detail['tokenLifetimeSeconds'] == 3600
    assert 3603 <= detail['issuedSecondsAgo'] <= 3605
    assert 'private-identity' not in result.text and token not in result.text


def clock_login(client, monkeypatch, upstream=200, anonymous=401):
    now = time.time()
    payload = base64.urlsafe_b64encode(json.dumps({'iat': now-3603, 'exp': now-3}).encode()).decode().rstrip('=')
    token = 'header.' + payload + '.signature'
    monkeypatch.setattr(httpx, 'post', lambda *a, **k: httpx.Response(201, json={
        'access_token': token, 'token_type': 'Bearer', 'expires_in': 3600}))
    calls = []
    def get(url, **kwargs):
        calls.append(kwargs['headers']['Authorization'])
        assert url == 'https://erp.test/rest/api/pcp/v1/prodOrders/fields'
        assert kwargs['verify'] is not False and kwargs['follow_redirects'] is False
        return httpx.Response(upstream if calls[-1] == 'Bearer ' + token else anonymous,
                              json={'fields': []})
    monkeypatch.setattr(httpx, 'get', get)
    result = client.post('/api/v1/auth/protheus/login', headers={'username': 'operador', 'password': 'fixture'})
    return result, calls


def test_clock_skew_requires_online_validation_on_every_call(client, monkeypatch):
    result, calls = clock_login(client, monkeypatch)
    assert result.status_code == 200
    assert result.json()['validationMode'] == 'protheus_online'
    assert 0 < result.json()['expiresAt'] - time.time() <= 300
    headers = {'Authorization': 'Bearer ' + result.json()['access_token']}
    count = len(calls)
    assert client.get('/api/v1/health', headers=headers).status_code == 200
    assert len(calls) == count + 2
    monkeypatch.setattr(httpx, 'get', lambda *a, **k: httpx.Response(401))
    assert client.get('/api/v1/health', headers=headers).status_code == 401
    assert client.get('/api/v1/health', headers=headers).status_code == 401


@pytest.mark.parametrize('upstream,anonymous,expected', [(401, 401, 401), (403, 401, 403),
                                                       (200, 200, 503), (500, 401, 503)])
def test_clock_skew_fails_closed(client, monkeypatch, upstream, anonymous, expected):
    result, _ = clock_login(client, monkeypatch, upstream, anonymous)
    assert result.status_code == expected
    assert 'access_token' not in result.text


@pytest.mark.parametrize('reuse_token', [True, False])
def test_logout_during_refresh_cannot_restore_session(client, monkeypatch, reuse_token):
    from app import sessions
    old = jwt()
    new = old if reuse_token else jwt(time.time() + 600)
    session = sessions.register(old, 'operador', 300)
    sessions.enable_refresh(session, 'refresh-fixture')
    def post(*args, **kwargs):
        sessions.revoke(old)
        return httpx.Response(201, json={'access_token':new, 'expires_in':300,
                                       'token_type':'Bearer', 'refresh_token':'new-secret'})
    monkeypatch.setattr(httpx, 'post', post)
    assert client.post('/api/v1/auth/protheus/refresh', headers={'Authorization':'Bearer '+old}).status_code == 401
    assert client.get('/api/v1/health', headers={'Authorization':'Bearer '+new}).status_code == 401


def test_refresh_rejection_revokes_access(client, monkeypatch):
    from app import sessions
    old = jwt()
    session = sessions.register(old, 'operador', 300)
    sessions.enable_refresh(session, 'refresh-fixture')
    monkeypatch.setattr(httpx, 'post', lambda *a, **k: httpx.Response(400))
    assert client.post('/api/v1/auth/protheus/refresh', headers={'Authorization':'Bearer '+old}).status_code == 401
    assert client.get('/api/v1/health', headers={'Authorization':'Bearer '+old}).status_code == 401
