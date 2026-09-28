from contextlib import contextmanager

from fastapi.testclient import TestClient
from app import config, warehouse
from app.main import app


def test_expedition_endpoint_keeps_physical_10_and_rejects_writes(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    calls = []
    def read(**kwargs):
        calls.append(kwargs)
        return {'readOnly': True, 'items': []}
    monkeypatch.setattr(warehouse, 'read_warehouse', read)
    with TestClient(app) as client:
        assert client.get('/api/v1/expedicao?local=01').status_code == 200
        assert calls[-1]['local'] == '10'
        assert not calls[-1].get('include_order_movements', False)
        assert calls[-1]['start'] is None
        assert client.get('/api/v1/expedicao?kind=fiscal&view=history&page=2&page_size=20&start=2026-09-01&end=2026-09-30').status_code == 200
        assert calls[-1]['kind'] == 'fiscal'
        assert calls[-1]['page'] == 2
        assert str(calls[-1]['end']) == '2026-09-30'
        for query in ['page_size=101', 'page=0', 'view=bad', 'start=2026-09-30&end=2026-09-01']:
            assert client.get('/api/v1/expedicao?' + query).status_code == 422
        for method in ['post', 'put', 'patch', 'delete']:
            assert getattr(client, method)('/api/v1/expedicao').status_code == 405


def test_shipping_details_match_full_fiscal_identity_and_never_guess_order(monkeypatch):
    queries = []
    @contextmanager
    def connection():
        yield object()
    def fetch(conn, sql, params):
        queries.append((sql, params))
        if len(queries) == 1:
            return [{'filial': '04', 'document': '001234', 'series': '1',
                     'partner': '001001', 'partnerStore': '01', 'type': 'N',
                     'salesOrder': '', 'salesOrderItem': ''}]
        return [{'carrierName': 'Transportadora', 'trackingCode': ''}]
    monkeypatch.setattr(warehouse.mssql, 'conexao', connection)
    monkeypatch.setattr(warehouse.mssql, '_fetchall', fetch)
    data = warehouse.dispatch_note_details(123, '04')
    assert data['readOnly']
    assert data['item']['salesOrder'] == ''
    assert data['document']['trackingCode'] == ''
    assert "D2_LOCAL='10'" in queries[0][0]
    assert queries[0][1] == (123, '04')
    assert queries[1][1] == ('04', '001234', '1', '001001', '01', 'N')
    for name in ['F2_FILIAL', 'F2_DOC', 'F2_SERIE', 'F2_CLIENTE', 'F2_LOJA', 'F2_TIPO']:
        assert name + '=?' in queries[1][0]
    assert 'TOP (2)' in queries[1][0]
    assert all(sql.lstrip().startswith('SELECT') for sql, _ in queries)


def test_shipping_details_handle_missing_item_and_ambiguous_header(monkeypatch):
    @contextmanager
    def connection():
        yield object()
    monkeypatch.setattr(warehouse.mssql, 'conexao', connection)
    monkeypatch.setattr(warehouse.mssql, '_fetchall', lambda *args: [])
    assert warehouse.dispatch_note_details(123, '04') is None
    rows = [[{'filial':'04','document':'1','series':'1','partner':'1','partnerStore':'01','type':'N'}], [{}, {}]]
    monkeypatch.setattr(warehouse.mssql, '_fetchall', lambda *args: rows.pop(0))
    data = warehouse.dispatch_note_details(123, '04')
    assert data['headerStatus'] == 'ambiguous'
    assert data['document'] is None


def test_shipping_endpoint_handles_not_found_invalid_id_and_failure(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    monkeypatch.setattr(warehouse, 'dispatch_note_details', lambda *args: None, raising=False)
    with TestClient(app) as client:
        assert client.get('/api/v1/expedicao/notas/0').status_code == 422
        assert client.get('/api/v1/expedicao/notas/123').status_code == 404
        def fail(*args, **kwargs):
            raise RuntimeError('private connection')
        monkeypatch.setattr(warehouse, 'dispatch_note_details', fail)
        monkeypatch.setattr(warehouse, 'read_warehouse', fail)
        for path in ['/api/v1/expedicao', '/api/v1/expedicao/notas/123']:
            response = client.get(path)
            assert response.status_code == 503
            assert 'private connection' not in response.text
