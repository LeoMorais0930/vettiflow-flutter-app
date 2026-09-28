from contextlib import contextmanager
from datetime import date

import pytest
from fastapi.testclient import TestClient
from app import config, warehouse_reports as reports
from app.main import app


@pytest.fixture
def report_db(monkeypatch):
    calls = []
    state = {'total': 1205, 'details': []}
    @contextmanager
    def connection():
        yield object()
    def fetch(conn, sql, params=()):
        calls.append((sql, params))
        if '/* summary */' in sql:
            return [{'kind': 'transfer', 'flow': 'out', 'reversed': 0,
                     'count': state['total'], 'firstDate': '20260901', 'lastDate': '20260918'}]
        if '/* series */' in sql:
            return [{'period': '202609', 'count': state['total']}]
        if '/* products */' in sql:
            return [{'code': 'ABC', 'description': 'Componente', 'unit': 'M',
                     'kind': 'transfer', 'flow': 'out', 'reversed': 0,
                     'quantity': 0.83, 'count': state['total'], 'groupCount': 125}]
        return state['details']
    monkeypatch.setattr(reports.mssql, 'conexao', connection)
    monkeypatch.setattr(reports.mssql, '_fetchall', fetch)
    monkeypatch.setattr(reports, 'database_coverage', lambda: {'latestRecord': '20260918'})
    return calls, state


def test_full_summary_and_explicit_detail_budget(report_db):
    calls, _ = report_db
    result = reports.read_report(reports.ReportFilters(details=True))
    assert result['total'] == 1205
    assert result['detailStatus'] == 'too_large'
    assert result['items'] == []
    assert result['detailLimit'] == 1000
    assert result['products'][0]['quantity'] == 0.83
    assert result['productGroupCount'] == 125
    assert result['warehouse'] == '01' and result['readOnly']
    assert all(sql.lstrip().startswith('WITH') for sql, _ in calls)
    assert not any('/* details */' in sql for sql, _ in calls)


def test_filters_parameterized_and_shared_by_all_queries(report_db):
    calls, state = report_db
    state['total'] = 1
    state['details'] = [{'id': 'SD3:1', 'quantity': 0.83}]
    filters = reports.ReportFilters(
        start=date(2026, 9, 1), end=date(2026, 9, 30), query="x' OR 1=1--",
        kinds=['transfer', 'adjustment'], product='ABC', op='00101001001',
        operator='vera', document='123', source='SD3', flow='out', status='active',
        unit='M', cf='RE4', tm='999', tes='501', cfop='5102', details=True,
    )
    result = reports.read_report(filters)
    assert result['detailStatus'] == 'complete'
    assert result['items'][0]['quantity'] == 0.83
    assert result['filters']['operator'] == 'vera'
    for sql, params in calls:
        assert "x' OR 1=1--" not in sql
        assert "x' OR 1=1--" in params
        assert params[:4] == (config.FILIAL_PADRAO, '01', '20260901', '20260930')
        assert 'kind IN (?,?)' in sql
        assert 'reversed=?' in sql
    product_sql = next(sql for sql, _ in calls if '/* products */' in sql)
    assert 'GROUP BY code,unit,kind,flow,reversed' in product_sql
    assert 'SUM(quantity)' in product_sql


def test_changed_count_never_exports_incomplete_details(report_db):
    _, state = report_db
    state['total'] = 2
    state['details'] = [{'id': 'SD3:1'}]
    result = reports.read_report(reports.ReportFilters(details=True))
    assert result['detailStatus'] == 'changed'
    assert result['items'] == []


def test_empty_result_is_valid_and_all_dates_have_no_cutoff(report_db):
    calls, state = report_db
    state['total'] = 0
    result = reports.read_report(reports.ReportFilters(details=True))
    assert result['detailStatus'] == 'complete'
    assert result['total'] == 0
    assert calls[0][1][2:4] == (None, None)
    assert result['filters']['start'] is None


def test_summary_only_does_not_fetch_detail_and_preserves_estornos(report_db):
    calls, _ = report_db
    result = reports.read_report(reports.ReportFilters(status='reversed'))
    assert result['detailStatus'] == 'not_requested'
    assert not any('/* details */' in s for s, _ in calls)
    assert all(params[-1] == 1 for _, params in calls)


def test_http_validation_fixed_scope_auth_and_read_only(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    calls = []
    monkeypatch.setattr(reports, 'read_report', lambda f: calls.append(f) or {'warehouse': '01'})
    with TestClient(app) as client:
        path = '/api/v1/relatorios/almoxarifado'
        assert client.get(path + '?kinds=transfer&kinds=receipt').status_code == 200
        assert set(calls[-1].kinds) == {'transfer', 'receipt'}
        for query in ['local=10', 'start=bad', 'start=2026-09-30&end=2026-09-01',
                      'start=2026-09-01', 'kinds=unknown', 'flow=bad', 'status=closed',
                      'query=' + 'a'*101, 'source=SF2']:
            assert client.get(path + '?' + query).status_code == 422, query
        for method in ['post', 'put', 'patch', 'delete']:
            assert getattr(client, method)(path).status_code == 405
        monkeypatch.setattr(config, 'API_TOKEN', 'test-report-token')
        assert client.get(path).status_code == 401


def test_http_database_errors_are_generic(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    def fail(filters):
        raise RuntimeError('private connection string')
    monkeypatch.setattr(reports, 'read_report', fail)
    with TestClient(app) as client:
        response = client.get('/api/v1/relatorios/almoxarifado')
    assert response.status_code == 503
    assert 'private' not in response.text


def test_concurrency_budget_returns_retryable_error(monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    assert reports._slots.acquire(blocking=False)
    assert reports._slots.acquire(blocking=False)
    try:
        with TestClient(app) as client:
            assert client.get('/api/v1/relatorios/almoxarifado').status_code == 429
    finally:
        reports._slots.release()
        reports._slots.release()


def test_failed_coverage_is_unknown_not_zero(report_db, monkeypatch):
    def fail():
        raise RuntimeError('coverage unavailable')
    monkeypatch.setattr(reports, 'database_coverage', fail)
    result = reports.read_report(reports.ReportFilters())
    assert result['total'] == 1205
    assert result['databaseLatestRecord'] == ''


@pytest.mark.parametrize('sector,locals_', [
    ('smd', ['03']), ('producao', ['05']), ('suporte', ['06', '07']),
    ('expedicao', ['10']), ('gestao', ['01', '03', '05', '06', '07', '10']),
])
def test_sector_scopes_and_order_links(report_db, sector, locals_):
    calls, _ = report_db
    result = reports.read_report(reports.ReportFilters(), sector)
    sql, params = calls[0]
    assert result['sector'] == sector
    assert result['warehouses'] == locals_
    assert list(params[1:len(locals_) * 4:4]) == locals_
    assert ('c.C2_LOCAL=s.local' in sql) == (sector == 'producao')
    assert 'GROUP BY warehouse,kind,flow,reversed' in sql
    assert result['warehouseSummary'][0]['count'] == result['total']


def test_sector_http_scope_validation_and_selected_warehouses(report_db, monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    with TestClient(app) as client:
        for sector in ['smd', 'producao', 'suporte', 'expedicao', 'gestao']:
            assert client.get(f'/api/v1/relatorios/{sector}').status_code == 200
        for sector, local in [('smd', '01'), ('producao', '10'), ('suporte', '05'), ('expedicao', '06'), ('gestao', '99')]:
            assert client.get(f'/api/v1/relatorios/{sector}?warehouses={local}').status_code == 422
        response = client.get('/api/v1/relatorios/gestao?warehouses=10&warehouses=03&warehouses=10')
        assert response.json()['warehouses'] == ['03', '10']
        assert client.get('/api/v1/relatorios/desconhecido').status_code == 422
        assert client.post('/api/v1/relatorios/producao').status_code == 405


def test_summary_merges_kinds_without_losing_physical_warehouse_counts(report_db, monkeypatch):
    original = reports.mssql._fetchall
    def fetch(conn, sql, params):
        if '/* summary */' in sql:
            return [dict(warehouse=local, kind='transfer', flow='in', reversed=0,
                         count=count, firstDate='20260901', lastDate='20260918')
                    for local, count in [('06', 4), ('07', 3)]]
        return original(conn, sql, params)
    monkeypatch.setattr(reports.mssql, '_fetchall', fetch)
    result = reports.read_report(reports.ReportFilters(), 'suporte')
    assert result['total'] == 7
    assert len(result['summary']) == 1 and result['summary'][0]['count'] == 7
    assert result['warehouseSummary'] == [{'warehouse': '06', 'count': 4}, {'warehouse': '07', 'count': 3}]


@pytest.mark.parametrize('analysis', ['output', 'orders', 'evolution', 'destinations'])
def test_production_analysis_uses_effective_pr0_filters_and_full_metrics(report_db, monkeypatch, analysis):
    calls, _ = report_db
    original = reports.mssql._fetchall
    def fetch(conn, sql, params):
        if '/* production metrics */' in sql:
            return [{'orderCount': 5, 'productCount': 2, 'activeDays': 3, 'withoutOrder': 0}]
        if '/* production groups */' in sql:
            assert 'SUM(quantity)' in sql and 'code,unit' in sql
            return [{'code': 'P', 'unit': 'PC', 'quantity': 3.5, 'groupCount': 2}]
        return original(conn, sql, params)
    monkeypatch.setattr(reports.mssql, '_fetchall', fetch)
    result = reports.read_report(reports.ReportFilters(analysis=analysis, source='SD1', cf='ER0', status='reversed'), 'producao')
    assert result['filters']['cf'] == 'PR0'
    assert result['filters']['status'] == 'active'
    assert result['filters']['source'] == 'SD3'
    assert all('PR0' in params for _, params in calls)
    assert result['production']['metrics']['orderCount'] == 5
    assert result['production']['rows'][0]['quantity'] == 3.5


def test_analysis_is_restricted_to_production_and_reversals_are_separate(report_db, monkeypatch):
    monkeypatch.setattr(config, 'API_TOKEN', '')
    with TestClient(app) as client:
        assert client.get('/api/v1/relatorios/smd?analysis=output').status_code == 422
    calls, _ = report_db
    result = reports.read_report(reports.ReportFilters(analysis='reversals'), 'producao')
    assert "(cf='ER0' OR reversed=1)" in calls[0][0]
    assert result['production'] is None
