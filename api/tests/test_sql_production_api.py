from datetime import date, timedelta
import importlib

from fastapi.testclient import TestClient
import pytest

from app import config
from app.main import app
from .test_sql_production import db


@pytest.fixture
def client(monkeypatch, db):
    module = importlib.import_module('app.sql_production_api')
    monkeypatch.setattr(config, 'SQL_WRITE_ENABLED', True)
    monkeypatch.setattr(config, 'SQL_EXCLUSIVE_DEV', True)
    monkeypatch.setattr(config, 'SQL_WRITE_TOKEN', 'test-only-write-key')
    monkeypatch.setattr(config, 'MSSQL_DATABASE', 'HMLp12')
    monkeypatch.setattr(config, 'MSSQL_SCHEMA', 'dbo')
    monkeypatch.setattr(config, 'EMPRESA', '010')
    monkeypatch.setattr(config, 'FILIAL_PADRAO', '04')
    monkeypatch.setattr(config, 'PROTHEUS_COMPANY_GROUP', '01')
    monkeypatch.setattr(module, 'SqlDatabase', lambda: db)
    with TestClient(app) as client:
        yield client


def body():
    return dict(id='opening-1', operacao='abrir', autor='Tatiane', data=str(date.today()),
                entrega=str(date.today()+timedelta(days=10)), produto='PA1', quantidade='10')


HEADERS = {'X-VettiFlow-Write-Key': 'test-only-write-key'}
URL = '/api/v1/dev/producao-sql/comandos'


def test_authentication_is_separate_from_read_access(client, db):
    assert client.post(URL, json=body()).status_code == 401
    assert not db.rows('SC2')


@pytest.mark.parametrize('name,value', [('SQL_WRITE_ENABLED', False), ('SQL_EXCLUSIVE_DEV', False),
                                      ('MSSQL_DATABASE', 'VettiP12'), ('FILIAL_PADRAO', '01'),
                                      ('MSSQL_SCHEMA', 'other'), ('EMPRESA', '999')])
def test_configuration_blocks_real_write(client, monkeypatch, db, name, value):
    monkeypatch.setattr(config, name, value)
    assert client.post(URL, json=body(), headers=HEADERS).status_code == 503
    assert not db.rows('SC2')


def test_preview_then_apply_and_query_result(client, db):
    preview = client.post(URL, json={**body(), 'simular': True}, headers=HEADERS)
    assert preview.status_code == 200 and preview.json()['status'] == 'previa'
    assert not db.rows('SC2')
    result = client.post(URL, json=body(), headers=HEADERS)
    assert result.status_code == 200 and result.json()['status'] == 'aplicada'
    assert client.post(URL, json=body(), headers=HEADERS).json() == result.json()
    fetched = client.get(URL+'/opening-1', headers=HEADERS)
    assert fetched.json() == result.json()


def test_bad_payload_and_past_date_never_write(client, db):
    assert client.post(URL, json={**body(), 'quantidade': 0}, headers=HEADERS).status_code == 422
    assert client.post(URL, json={**body(), 'sql': 'DROP TABLE SC2010'}, headers=HEADERS).status_code == 422
    assert client.post(URL, json={**body(), 'data': '2001-01-01'}, headers=HEADERS).status_code == 422
    assert not db.rows('SC2')


def test_database_failure_does_not_leak_driver_details(client, db):
    db.fail_commit = True
    result = client.post(URL, json=body(), headers=HEADERS)
    assert result.status_code == 503
    assert 'commit failed' not in result.text
    assert not db.rows('SC2')


def test_unknown_result_is_not_success(client):
    assert client.get(URL+'/unknown', headers=HEADERS).status_code == 404


def test_status_describes_distinct_operations(client):
    status = client.get('/api/v1/dev/producao-sql/status').json()
    assert status['enabled'] is True
    assert status['operations'] == ['abrir', 'alterar', 'transferir', 'apontar']
    assert status['database'] == 'HMLp12'
