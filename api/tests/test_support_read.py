from contextlib import contextmanager

from fastapi.testclient import TestClient
from app import config, warehouse
from app.main import app


def test_support_only_reads_06_or_07_with_bounded_monthly_pages(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    calls = []
    def read(**kwargs):
        calls.append(kwargs)
        return {'readOnly': True, 'items': []}
    monkeypatch.setattr(warehouse, 'read_warehouse', read)
    with TestClient(app) as client:
        assert client.get('/api/v1/suporte').status_code == 200
        assert calls[-1]['local'] == '06'
        assert calls[-1]['start'] is None
        response = client.get('/api/v1/suporte?local=07&view=history&kind=fiscal&start=2026-09-01&end=2026-09-30&page=2&page_size=20')
        assert response.status_code == 200
        assert response.json()['readOnly']
        assert calls[-1]['local'] == '07'
        assert calls[-1]['kind'] == 'fiscal'
        assert str(calls[-1]['end']) == '2026-09-30'
        assert calls[-1]['page'] == 2
        assert calls[-1]['page_size'] == 20
        for query in ['local=01', 'page_size=101', 'page=0', 'view=bad',
                      'start=2026-09-30&end=2026-09-01']:
            assert client.get('/api/v1/suporte?' + query).status_code == 422
        for method in ['post', 'put', 'patch', 'delete']:
            assert getattr(client, method)('/api/v1/suporte').status_code == 405


def test_fiscal_filter_applies_before_count_and_pagination(monkeypatch):
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
    result = warehouse.read_warehouse(view='history', local='07', kind='fiscal', page=2, page_size=20)
    assert result['total'] == 0
    assert len(queries) == 2
    assert all("kind IN ('receipt','dispatch')" in sql for sql, _ in queries)
    assert all('OR EXISTS' not in sql for sql, _ in queries)
    assert queries[-1][1][-2:] == (20, 20)


def test_support_error_does_not_expose_private_connection(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    def fail(**kwargs):
        raise RuntimeError('private connection details')
    monkeypatch.setattr(warehouse, 'read_warehouse', fail)
    with TestClient(app) as client:
        response = client.get('/api/v1/suporte')
        assert response.status_code == 503
        assert 'private connection' not in response.text
