import copy
import pytest
from fastapi.testclient import TestClient
from app import config, commitment_review as review
from app.main import app

OP = '01642901001'
PATH = '/api/v1/ops/' + OP + '/revisao-empenhos'

@pytest.fixture
def client(monkeypatch, tmp_path):
    monkeypatch.setattr(config, 'FLOW_DB', tmp_path / 'flow.sqlite3')
    monkeypatch.setattr(config, 'QUEUE_DB', tmp_path / 'queue.sqlite3')
    monkeypatch.setattr(config, 'FLOW_ADMIN_USERS', ['fixture-negocio'])
    data = {'order': {'numero': OP, 'produto': '550-TEST', 'emissao': '29/09/2026', 'encerrada': False},
            'items': [{'id': 1, 'produto': 'MP001', 'descricao': 'Componente', 'local': '01', 'unidade': 'UN', 'quantidade': 10},
                      {'id': 2, 'produto': 'MP001', 'descricao': 'Outro lote', 'local': '01', 'unidade': 'UN', 'quantidade': 20}]}
    monkeypatch.setattr(review.mssql, 'commitment_review_snapshot', lambda *_: copy.deepcopy(data), raising=False)
    with TestClient(app) as c:
        yield c, data

def command(snapshot, ids=None):
    return {'expectedVersion': snapshot['version'], 'fingerprint': snapshot['fingerprint'],
            'excluded': [{'id': i, 'reason': 'Já disponível no setor'} for i in (ids or [1])]}

def test_save_restore_and_concurrent_edit(client):
    c, _ = client
    start = c.get(PATH).json()
    saved = c.put(PATH, json=command(start))
    assert saved.status_code == 200
    assert saved.json()['appliedToErp'] is False
    assert c.get(PATH).json()['excluded'] == command(start)['excluded']
    assert c.put(PATH, json=command(start)).status_code == 409
    latest = c.get(PATH).json()
    assert c.put(PATH, json={**command(latest), 'excluded': []}).status_code == 200
    assert c.get(PATH).json()['excluded'] == []

def test_changed_erp_never_reuses_old_selection(client):
    c, data = client
    start = c.get(PATH).json()
    assert c.put(PATH, json=command(start)).status_code == 200
    data['items'][0]['quantidade'] = 11
    assert c.put(PATH, json=command(start)).status_code == 409
    refreshed = c.get(PATH).json()
    assert refreshed['stale'] is True
    assert refreshed['excluded'] == []

def test_refuses_wrong_rows_closed_order_and_unprivileged(client, monkeypatch):
    c, data = client
    start = c.get(PATH).json()
    assert c.put(PATH, json=command(start, [99])).status_code == 422
    assert c.put(PATH, json=command(start, [1, 1])).status_code == 422
    assert c.put(PATH, json={**command(start), 'actor': 'admin'}).status_code == 422
    assert c.get(PATH+'?filial=99').status_code == 403
    data['order']['encerrada'] = True
    assert c.put(PATH, json=command(start)).status_code == 409
    monkeypatch.setattr(config, 'FLOW_ADMIN_USERS', [])
    assert c.get(PATH).json()['canSave'] is False
    assert c.put(PATH, json=command(start)).status_code == 403


def test_read_failure_and_mod_cannot_be_deleted(client, monkeypatch):
    c, data = client
    data['items'][0]['produto'] = 'MOD001'
    start = c.get(PATH).json()
    assert c.put(PATH, json=command(start)).status_code == 422
    def broken(*_):
        raise RuntimeError('private sql connection')
    monkeypatch.setattr(review.mssql, 'commitment_review_snapshot', broken)
    response = c.get(PATH)
    assert response.status_code == 503
    assert 'private' not in response.text
