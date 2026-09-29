import pytest
from fastapi.testclient import TestClient
from app import config, flow_tracking
from app.main import app

KEY = dict(filial='04', numero='016431', item='01', sequencia='001', grade='')

@pytest.fixture
def client(monkeypatch, tmp_path):
    monkeypatch.setattr(config, 'FLOW_DB', tmp_path / 'flow.sqlite3')
    monkeypatch.setattr(config, 'FLOW_ADMIN_USERS', ['fixture-negocio'])
    monkeypatch.setattr(flow_tracking, 'official_order', lambda key: {'produto':'P', 'emissao':'20260929', 'encerrada':False})
    with TestClient(app) as client:
        yield client

def command(client, action, version=0, stage='firmware', request_id=None, note=''):
    import uuid
    return client.post('/api/v1/flow/events', json=dict(key=KEY, action=action, stage=stage, expectedVersion=version, requestId=request_id or str(uuid.uuid4()), note=note))

def test_persisted_lifecycle_identity_and_idempotency(client):
    import uuid
    rid = str(uuid.uuid4())
    first = command(client,'start',request_id=rid)
    assert first.status_code == 200
    assert first.json()['state']['status'] == 'active'
    assert first.json()['events'][0]['actor'] == 'fixture-negocio'
    assert command(client,'start',request_id=rid).json()['state']['version'] == 1
    assert command(client,'pause',1,note='Falta de material').status_code == 200
    assert command(client,'resume',2).status_code == 200
    assert command(client,'complete',3).json()['state']['status'] == 'completed'
    saved = client.get('/api/v1/flow/order',params=KEY).json()
    assert saved['state']['version'] == 4
    assert len(saved['events']) == 4
    assert command(client,'start',4,stage='soldering').status_code == 200

def test_rejects_stale_version_invalid_transition_and_reused_id(client):
    import uuid
    rid=str(uuid.uuid4())
    assert command(client,'complete').status_code == 409
    assert command(client,'start',request_id=rid).status_code == 200
    assert command(client,'pause',0,note='reason').status_code == 409
    assert command(client,'pause',1,request_id=rid,note='reason').status_code == 409
    assert command(client,'pause',1).status_code == 422
    assert command(client,'complete',1,stage='testing').status_code == 409

def test_denies_unassigned_user_closed_order_and_wrong_branch(client,monkeypatch):
    monkeypatch.setattr(config,'FLOW_ADMIN_USERS',[])
    assert command(client,'start').status_code == 403
    monkeypatch.setattr(config,'FLOW_ADMIN_USERS',['fixture-negocio'])
    monkeypatch.setattr(flow_tracking,'official_order',lambda key: {'produto':'P','emissao':'20260929','encerrada':True})
    assert command(client,'start').status_code == 409
    assert client.get('/api/v1/flow/order',params={**KEY,'filial':'99'}).status_code == 403

def test_denies_unknown_order_and_identity_spoofing(client,monkeypatch):
    monkeypatch.setattr(flow_tracking,'official_order',lambda key: None)
    assert command(client,'start').status_code == 404
    payload=dict(key=KEY,action='start',stage='firmware',expectedVersion=0,requestId='12345678-1234-1234-1234-123456789012',actor='admin')
    assert client.post('/api/v1/flow/events',json=payload).status_code == 422


def test_concurrent_start_has_one_winner(client):
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(lambda _: command(client, 'start').status_code, range(2)))
    assert sorted(results) == [200, 409]
    assert len(client.get('/api/v1/flow/order',params=KEY).json()['events']) == 1


def test_source_replacement_and_stage_permissions(client,monkeypatch):
    monkeypatch.setattr(config,'FLOW_ADMIN_USERS',[])
    monkeypatch.setattr(config,'FLOW_STAGE_USERS',{'fixture-negocio':['testing']})
    assert command(client,'start').status_code == 403
    assert command(client,'start',stage='testing').status_code == 200
    monkeypatch.setattr(flow_tracking,'official_order',lambda key: {'produto':'REPLACED','emissao':'20260929','encerrada':False})
    assert command(client,'complete',1,stage='testing').status_code == 409
    assert client.get('/api/v1/flow/order',params=KEY,headers={'Authorization':'Bearer invalid'}).status_code == 401


def test_cannot_move_back_after_stage_completion(client):
    assert command(client,'start',stage='testing').status_code == 200
    assert command(client,'complete',1,stage='testing').status_code == 200
    assert command(client,'start',2,stage='firmware').status_code == 409


def test_dashboard_states_are_scoped_and_include_latest_pause(client, monkeypatch):
    assert command(client, 'start').status_code == 200
    assert command(client, 'pause', 1, note='Falta de peça').status_code == 200
    response = client.get('/api/v1/flow/states')
    assert response.status_code == 200
    row = response.json()['items'][0]
    assert row['key'] == KEY
    assert row['status'] == 'paused'
    assert row['stage'] == 'firmware'
    assert row['note'] == 'Falta de peça'
    assert row['actor'] == 'fixture-negocio'
    assert row['produto'] == 'P'
    assert row['emissao'] == '20260929'
    assert 'payload_hash' not in row
    assert client.get('/api/v1/flow/states', headers={'Authorization':'Bearer invalid'}).status_code == 401
    monkeypatch.setattr(config, 'FILIAL_PADRAO', '99')
    assert flow_tracking.read_states(None)['items'] == []
