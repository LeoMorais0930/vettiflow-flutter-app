from contextlib import contextmanager
from fastapi.testclient import TestClient
from app import config, warehouse
from app.main import app


def test_production_scope_keeps_local_movements_and_linked_ops_without_multiplying_rows():
    sql = warehouse._history(include_order_movements=True)
    assert 'OR EXISTS' in sql
    assert 'c.C2_FILIAL=d.D3_FILIAL' in sql
    assert 'c.C2_LOCAL=s.local' in sql
    assert 'c.C2_NUM+c.C2_ITEM+c.C2_SEQUEN=d.D3_OP' in sql
    assert "c.D_E_L_E_T_=''" in sql
    assert 'd.D3_LOCAL=s.local' in warehouse._history()
    assert 'OR EXISTS' not in warehouse._history()


def test_production_endpoint_is_read_only_bounded_and_fixed_to_05(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    calls = []
    def read(**kwargs):
        calls.append(kwargs)
        return {'readOnly': True, 'items': []}
    monkeypatch.setattr(warehouse, 'read_warehouse', read)
    with TestClient(app) as client:
        response = client.get('/api/v1/producao?view=history&local=70&kind=production&start=2026-09-01&end=2026-09-30')
        assert response.status_code == 200
        assert response.json()['readOnly']
        assert calls[-1]['local'] == '05'
        assert calls[-1]['include_order_movements'] is True
        assert calls[-1]['kind'] == 'production'
        assert str(calls[-1]['end']) == '2026-09-30'
        for suffix in ['page_size=101', 'view=bad', 'start=2026-09-30&end=2026-09-01']:
            assert client.get('/api/v1/producao?' + suffix).status_code == 422
        assert client.post('/api/v1/producao', json={}).status_code == 405


def test_production_scope_is_used_for_count_and_page(monkeypatch):
    queries = []
    @contextmanager
    def connection():
        yield object()
    def fetch(conn, sql, params):
        queries.append((sql, params))
        return []
    monkeypatch.setattr(warehouse.mssql, 'conexao', connection)
    monkeypatch.setattr(warehouse.mssql, '_fetchall', fetch)
    monkeypatch.setattr(warehouse, 'database_coverage', lambda: {})
    result = warehouse.read_warehouse(view='history', local='05', include_order_movements=True)
    assert result['total'] == 0
    assert len(queries) == 2
    assert all('OR EXISTS' in sql for sql, _ in queries)
    assert queries[-1][1][-2:] == (0, 50)


def test_production_errors_do_not_leak_connection_details(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    def fail(**kwargs):
        raise RuntimeError('private connection details')
    monkeypatch.setattr(warehouse, 'read_warehouse', fail)
    with TestClient(app) as client:
        response = client.get('/api/v1/producao')
        assert response.status_code == 503
        assert 'private connection' not in response.text
