from contextlib import contextmanager
from datetime import date

import pytest
from fastapi.testclient import TestClient

from app import config, warehouse
from app.main import app

read_real_coverage = warehouse.database_coverage


def test_history_exposes_posting_operator_without_inventing_fiscal_author():
    sql = warehouse._history()
    assert 'd.D3_USUARIO operator' in sql
    # SD1/SD2 have no operator mapping in this consultation.
    assert sql.count("'' operator") == 2


def test_database_coverage_ignores_view_filters_and_caches_for_one_minute(monkeypatch):
    warehouse._coverage_cache.clear()
    calls = []
    now = [100.0]
    monkeypatch.setattr(warehouse, 'monotonic', lambda: now[0])
    @contextmanager
    def connection():
        yield object()
    def fetch(conn, sql, params=()):
        calls.append(sql)
        for table in ['SD3010', 'SD1010', 'SD2010', 'SC2010', 'SB7010']:
            assert table in sql
        assert 'FILIAL=' not in sql and 'LOCAL=' not in sql
        assert 'D_E_L_E_T_' in sql and 'MIN(' in sql and 'MAX(' in sql
        return [{'firstRecord': '19980203', 'latestRecord': '20260918'}]
    monkeypatch.setattr(warehouse.mssql, 'conexao', connection)
    monkeypatch.setattr(warehouse.mssql, '_fetchall', fetch)
    assert read_real_coverage()['firstRecord'] == '19980203'
    assert read_real_coverage()['latestRecord'] == '20260918'
    assert len(calls) == 1
    now[0] += 61
    read_real_coverage()
    assert len(calls) == 2
    warehouse._coverage_cache.clear()


@pytest.fixture(autouse=True)
def coverage_stub(monkeypatch):
    monkeypatch.setattr(warehouse, 'database_coverage', lambda: {
        'firstRecord': '19980203', 'latestRecord': '20260918',
    }, raising=False)


def test_default_period_has_no_cutoff_and_reports_database_coverage(monkeypatch):
    calls = []
    @contextmanager
    def connection():
        yield object()
    def fetch(conn, sql, params=()):
        calls.append((sql, params))
        return []
    monkeypatch.setattr(warehouse.mssql, 'conexao', connection)
    monkeypatch.setattr(warehouse.mssql, '_fetchall', fetch)
    result = warehouse.read_warehouse(view='history', query='inexistente')
    assert result['start'] is None and result['end'] is None
    assert calls[-1][1][2:4] == (None, None)
    assert calls[-1][1][-2:] == (0, 50)
    assert result['databaseLatestRecord'] == '20260918'
    assert result['databaseFirstRecord'] == '19980203'
    assert result['total'] == 0


def test_http_default_does_not_invent_a_date_window(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    captured = {}
    def read(**kwargs):
        captured.update(kwargs)
        return {'readOnly': True}
    monkeypatch.setattr(warehouse, 'read_warehouse', read)
    with TestClient(app) as client:
        assert client.get('/api/v1/almoxarifado').status_code == 200
    assert captured['start'] is None and captured['end'] is None


def test_history_is_paginated_after_filtering_and_preserves_both_products(monkeypatch):
    calls = []

    @contextmanager
    def connection():
        yield object()

    def fetch(conn, sql, params=()):
        calls.append((sql, params))
        if 'GROUP BY kind, flow, reversed' in sql:
            return [{'kind': 'transfer', 'flow': 'out', 'reversed': 0, 'count': 2}]
        return [{'id': 'SD3:7', 'quantity': 0.83, 'code': 'A', 'otherCode': 'B',
                 'peerCount': 1, 'reversed': 0, 'affectsStock': 'S'}]

    monkeypatch.setattr(warehouse.mssql, 'conexao', connection)
    monkeypatch.setattr(warehouse.mssql, '_fetchall', fetch)
    data = warehouse.read_warehouse(view='history', filial='04', local='01',
        start=date(2026, 6, 24), end=date(2026, 9, 24), query="x' OR 1=1--",
        kind='transfer', status='all', page=2, page_size=1)
    assert data['readOnly'] is True
    assert data['total'] == 2
    assert data['items'][0]['quantity'] == 0.83
    assert data['items'][0]['otherCode'] == 'B'
    sql, params = calls[-1]
    assert 'D3_NUMSEQ' in sql and 'D3_FILIAL' in sql
    assert 'OFFSET ? ROWS FETCH NEXT ? ROWS ONLY' in sql
    assert params[-2:] == (1, 1)
    assert "x' OR 1=1--" not in sql
    assert all(q.lstrip().startswith('WITH') for q, _ in calls)


@pytest.mark.parametrize('view', ['stock', 'orders', 'inventory'])
def test_other_views_have_count_and_bounded_page(monkeypatch, view):
    calls = []
    @contextmanager
    def connection():
        yield object()
    def fetch(conn, sql, params=()):
        calls.append(sql)
        return [{'total': 0}] if 'COUNT_BIG(*) total' in sql else []
    monkeypatch.setattr(warehouse.mssql, 'conexao', connection)
    monkeypatch.setattr(warehouse.mssql, '_fetchall', fetch)
    data = warehouse.read_warehouse(view=view)
    assert data['items'] == [] and data['total'] == 0
    assert len(calls) == 2
    assert 'OFFSET ? ROWS' in calls[-1]


def test_route_validation_and_only_get(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    monkeypatch.setattr(warehouse, 'read_warehouse', lambda **kwargs: {'readOnly': True, 'view': kwargs['view']})
    with TestClient(app) as client:
        assert client.get('/api/v1/almoxarifado?view=history').json()['readOnly']
        for query in ['view=bad', 'page=0', 'page_size=101', 'start=bad', 'local=01%27',
                      'start=2026-09-24&end=2026-06-24']:
            assert client.get('/api/v1/almoxarifado?' + query).status_code == 422
        assert client.post('/api/v1/almoxarifado', json={}).status_code == 405


def test_route_does_not_expose_database_errors(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    def fail(**kwargs):
        raise RuntimeError('internal connection details')
    monkeypatch.setattr(warehouse, 'read_warehouse', fail)
    with TestClient(app) as client:
        response = client.get('/api/v1/almoxarifado')
        assert response.status_code == 503
        assert 'internal connection' not in response.text


@pytest.mark.parametrize('view,status,fragment', [
    ('history', 'reversed', 'reversed=?'),
    ('history', 'active', 'reversed=?'),
    ('orders', 'closed', 'closed=?'),
    ('orders', 'active', 'closed=?'),
    ('stock', 'nonzero', 'quantity<>0'),
])
def test_status_filters_precede_count_and_pagination(monkeypatch, view, status, fragment):
    sqls = []
    @contextmanager
    def connection():
        yield object()
    def fetch(conn, sql, params=()):
        sqls.append(sql)
        if 'COUNT_BIG(*) total' in sql:
            return [{'total': 0}]
        return []
    monkeypatch.setattr(warehouse.mssql, 'conexao', connection)
    monkeypatch.setattr(warehouse.mssql, '_fetchall', fetch)
    warehouse.read_warehouse(view=view, status=status, query='teste')
    assert all(fragment in sql for sql in sqls)


def test_union_uses_fiscal_stock_flag_and_no_product_join_for_counterpart():
    sql = warehouse._history()
    assert 'F4_ESTOQUE' in sql
    assert "THEN 'none'" in sql
    assert 'd.D1_DTDIGIT>=s.startDate' in sql
    assert 'd.D2_EMISSAO>=s.startDate' in sql
    assert 'p.D3_COD=d.D3_COD' not in sql
    assert 'peer.peerCount=1' in sql


def test_product_lookup_does_not_shadow_stock_or_inventory_alias():
    # This shadowing error is only rejected by SQL Server, not Python.
    for sql in [warehouse._stock(), warehouse._inventory()]:
        assert 'prod.B1_COD=b.' in sql
        assert 'WHERE b.D_E_L_E_T_' in sql


def test_new_route_keeps_token_protection(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', 'unit-test-token')
    with TestClient(app) as client:
        assert client.get('/api/v1/almoxarifado').status_code == 401


def test_related_movements_are_scoped_by_branch_document_date_sequence(monkeypatch):
    @contextmanager
    def connection():
        yield object()
    def fetch(conn, sql, params=()):
        assert params == (42, '04')
        assert 'd.D3_NUMSEQ=s.sequence' in sql
        assert 'd.D3_FILIAL=s.filial' in sql
        assert 'd.D3_DOC=s.document' in sql
        assert 'd.D3_EMISSAO=s.movementDate' in sql
        return [{'code': 'ORIGEM', 'warehouse': '10', 'cf': 'RE7', 'quantity': 1},
                {'code': 'COMP', 'warehouse': '01', 'cf': 'DE7', 'quantity': 0.56}]
    monkeypatch.setattr(warehouse.mssql, 'conexao', connection)
    monkeypatch.setattr(warehouse.mssql, '_fetchall', fetch)
    result = warehouse.related_movements(42, '04')
    assert result['items'][1]['quantity'] == 0.56
