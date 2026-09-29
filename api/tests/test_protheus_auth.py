import httpx
import pytest
from fastapi.testclient import TestClient

from app import config
from app.main import app


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(config, 'PROTHEUS_REST_URL', 'https://erp.test/rest')
    monkeypatch.setattr(config, 'API_TOKEN', 'api-test')
    with TestClient(app) as client:
        yield client


def call(client):
    return client.post('/api/v1/auth/protheus/test', headers={
        'X-API-Token': 'api-test', 'username': 'operador', 'password': 'senha-teste'})


@pytest.mark.parametrize('upstream', [200, 201])
def test_success_redacts_credentials_and_uses_https_headers(client, monkeypatch, upstream):
    def post(url, **kwargs):
        assert url == 'https://erp.test/rest/api/oauth2/v1/token'
        assert kwargs['params'] == {'grant_type': 'password'}
        assert kwargs['headers']['password'] == 'senha-teste'
        assert kwargs['headers']['tenantId'] == '01,04'
        assert kwargs['follow_redirects'] is False
        assert kwargs['verify'] is not False
        return httpx.Response(upstream, json={'access_token': 'segredo-token',
                                       'refresh_token': 'segredo-refresh',
                                       'token_type': 'Bearer', 'expires_in': 3600})
    monkeypatch.setattr(httpx, 'post', post)
    response = call(client)
    assert response.status_code == 200
    assert response.json()['authenticated'] is True
    assert response.json()['upstreamStatus'] == upstream
    assert response.json()['erpWritesEnabled'] is False
    assert 'segredo' not in response.text and 'senha-teste' not in response.text
    assert response.headers['cache-control'] == 'no-store'


@pytest.mark.parametrize('upstream,expected', [(400, 400), (401, 401), (403, 403),
                                             (404, 502), (302, 502), (500, 502)])
def test_upstream_failure_is_sanitized(client, monkeypatch, upstream, expected):
    monkeypatch.setattr(httpx, 'post', lambda *a, **k: httpx.Response(
        upstream, text='senha-teste segredo-token'))
    response = call(client)
    assert response.status_code == expected
    assert 'senha-teste' not in response.text and 'segredo-token' not in response.text


@pytest.mark.parametrize('upstream', [200, 201])
@pytest.mark.parametrize('body', [{}, [], {'access_token': 'token', 'hasMFA': True},
                                 {'access_token': 'token', 'token_type': 'Basic'},
                                 {'access_token': ' ', 'token_type': 'Bearer'}])
def test_incomplete_or_mfa_response_is_not_success(client, monkeypatch, body, upstream):
    monkeypatch.setattr(httpx, 'post', lambda *a, **k: httpx.Response(upstream, json=body))
    assert call(client).status_code == 502


def test_timeout(client, monkeypatch):
    def post(*a, **k):
        raise httpx.ReadTimeout('senha-teste')
    monkeypatch.setattr(httpx, 'post', post)
    response = call(client)
    assert response.status_code == 504
    assert 'senha-teste' not in response.text


@pytest.mark.parametrize('url', ['', 'http://erp.test/rest', 'https://u:p@erp.test/rest'])
def test_invalid_destination_does_not_send_credentials(client, monkeypatch, url):
    monkeypatch.setattr(config, 'PROTHEUS_REST_URL', url)
    monkeypatch.setattr(httpx, 'post', lambda *a, **k: pytest.fail('Não deve chamar ERP'))
    assert call(client).status_code == 503


def test_requires_api_key(client):
    assert client.post('/api/v1/auth/protheus/test').status_code == 401


def test_swagger_local_and_security_schema(client):
    assert client.get('/docs').status_code == 200
    schema = client.get('/openapi.json')
    assert schema.status_code == 200
    assert schema.json()['components']['securitySchemes']['APIKeyHeader']['name'] == 'X-API-Token'


def test_swagger_remote_still_requires_api_key(client):
    with TestClient(app, client=('192.0.2.1', 1234)) as remote:
        assert remote.get('/docs').status_code == 401


def test_connection_failure_is_sanitized(client, monkeypatch):
    def post(*a, **k):
        raise httpx.ConnectError('senha-teste')
    monkeypatch.setattr(httpx, 'post', post)
    response = call(client)
    assert response.status_code == 502
    assert 'senha-teste' not in response.text


def test_html_is_not_authentication_success(client, monkeypatch):
    monkeypatch.setattr(httpx, 'post', lambda *a, **k: httpx.Response(200, text='<html>login</html>'))
    assert call(client).status_code == 502


def test_invalid_credentials_are_not_reflected_or_forwarded(client, monkeypatch):
    monkeypatch.setattr(httpx, 'post', lambda *a, **k: pytest.fail('Não deve chamar ERP'))
    response = client.post('/api/v1/auth/protheus/test', headers={
        'X-API-Token': 'api-test', 'username': 'operador', 'password': 's' * 513})
    assert response.status_code == 422
    assert 's' * 513 not in response.text
