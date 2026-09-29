import pytest
from fastapi.testclient import TestClient
from app import config, flow_tracking as flow
from app.main import app


@pytest.fixture
def client(monkeypatch, tmp_path):
    monkeypatch.setattr(config, 'FLOW_DB', tmp_path / 'access.sqlite3')
    monkeypatch.setattr(config, 'FLOW_ADMIN_USERS', ['fixture-negocio'])
    monkeypatch.setattr(config, 'FLOW_STAGE_USERS', {'operator': ['testing']})
    with TestClient(app) as client:
        yield client


def save(client, username='operator', stages=None, version=0):
    return client.put('/api/v1/flow/access/users/' + username,
                      json={'stages': stages if stages is not None else ['soldering'], 'expectedVersion': version})


def test_directory_is_admin_only_fresh_and_safe_on_failure(client, monkeypatch):
    calls = []
    def directory():
        calls.append(True)
        return [{'id':'000123', 'username':'operator', 'name':'Operator Name'}]
    monkeypatch.setattr(flow.mssql, 'active_users', directory, raising=False)
    response = client.get('/api/v1/flow/access/directory')
    assert response.status_code == 200
    assert response.json()['items'] == directory()
    assert response.json()['sourceDatabase'] == config.MSSQL_DATABASE
    assert response.json()['queriedAt']
    assert client.get('/api/v1/flow/access/directory').status_code == 200
    assert len(calls) == 3
    def unavailable():
        raise RuntimeError('PRIVATE CONNECTION DETAILS')
    monkeypatch.setattr(flow.mssql, 'active_users', unavailable)
    failure = client.get('/api/v1/flow/access/directory')
    assert failure.status_code == 503
    assert 'PRIVATE' not in failure.text
    monkeypatch.setattr(config, 'FLOW_ADMIN_USERS', [])
    assert client.get('/api/v1/flow/access/directory').status_code == 403


def test_admin_persists_overrides_audit_and_explicit_revocation(client):
    assert client.get('/api/v1/flow/access/me').json()['canManage'] is True
    original = client.get('/api/v1/flow/access/users/operator').json()
    assert original['stages'] == ['testing']
    assert original['version'] == 0
    response = save(client, username='OPERATOR')
    assert response.status_code == 200
    assert response.json()['username'] == 'operator'
    assert flow.allowed_stages('OPERATOR') == ['soldering']
    assert save(client, stages=[], version=1).status_code == 200
    assert flow.allowed_stages('operator') == []  # No environment fallback after revocation.
    data = client.get('/api/v1/flow/access/users/operator').json()
    assert data['version'] == 2
    assert data['history'][0]['actor'] == 'fixture-negocio'
    assert data['history'][0]['before'] == ['soldering']
    assert data['history'][0]['after'] == []
    assert len(data['history']) == 2


def test_no_admin_escalation_invalid_stage_or_lost_updates(client, monkeypatch):
    assert save(client, username='fixture-negocio').status_code == 403
    assert save(client, stages=['unknown']).status_code == 422
    assert save(client, stages=['testing', 'testing']).status_code == 422
    assert save(client, username='bad user').status_code == 422
    assert client.put('/api/v1/flow/access/users/operator', json={
        'stages':['testing'], 'expectedVersion':0, 'actor':'admin'}).status_code == 422
    assert save(client).status_code == 200
    assert save(client, stages=['warehouse']).status_code == 409
    monkeypatch.setattr(config, 'FLOW_ADMIN_USERS', [])
    assert client.get('/api/v1/flow/access/me').json()['canManage'] is False
    assert client.get('/api/v1/flow/access/users').status_code == 403
    assert client.get('/api/v1/flow/access/users/operator').status_code == 403
    assert save(client, stages=[], version=1).status_code == 403
    assert client.get('/api/v1/flow/access/me', headers={'Authorization':'Bearer invalid'}).status_code == 401


def test_permissions_are_scoped_and_revocation_is_checked_at_commit(client, monkeypatch):
    assert save(client).status_code == 200
    monkeypatch.setattr(config, 'MSSQL_DATABASE', 'different-db')
    assert flow.allowed_stages('operator') == ['testing']
    monkeypatch.setattr(config, 'FLOW_STAGE_USERS', {'fixture-negocio':['testing']})
    monkeypatch.setattr(config, 'FLOW_ADMIN_USERS', [])
    def revoke_during_read(key):
        with flow.database() as conn:
            conn.execute('INSERT INTO flow_access VALUES (?,?,?,?,?,?)',
                         (flow.access_scope(), 'fixture-negocio', '[]', 1, 'admin', 'now'))
            conn.commit()
        return {'produto':'P', 'emissao':'20260929', 'encerrada':False}
    monkeypatch.setattr(flow, 'official_order', revoke_during_read)
    response = client.post('/api/v1/flow/events', json={
        'key': {'filial':config.FILIAL_PADRAO, 'numero':'123', 'item':'01', 'sequencia':'001'},
        'requestId':'12345678-1234-1234-1234-123456789012', 'expectedVersion':0,
        'stage':'testing', 'action':'start',
    })
    assert response.status_code == 403
    with flow.database() as conn:
        assert conn.execute('SELECT COUNT(*) FROM flow_events').fetchone()[0] == 0
