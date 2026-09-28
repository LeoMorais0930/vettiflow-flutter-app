"""Verificações locais: nenhuma conexão ou gravação no Protheus."""
import pytest
from fastapi import HTTPException
from app import config
from app.warehouse_writes import Opening, _validate_target, readiness


@pytest.fixture
def dev(monkeypatch):
    for key, value in {
        'WRITE_ENABLED': True, 'PROTHEUS_WRITE_URL': '', 'MSSQL_DATABASE': 'HMLp12',
        'EMPRESA': '010', 'PROTHEUS_COMPANY_GROUP': '01', 'FILIAL_PADRAO': '04',
    }.items():
        monkeypatch.setattr(config, key, value)
    return {'banco': 'HMLp12', 'servidor': 'WIN-L1NA6CE7LB4'}


def test_flag_is_not_an_available_connection(dev):
    data = readiness(dev)
    assert data['writeEnabled'] is True
    assert data['writeAvailable'] is False
    assert data['readOnly'] is True
    assert data['status'] == 'conexao_pendente'
    assert data['company'] == '01'
    assert data['tableSuffix'] == '010'


def test_native_company_is_not_the_sql_suffix(dev):
    target = dict(contract='vettiflow.op.v1', database='HMLp12',
                  server='WIN-L1NA6CE7LB4', company='01', branch='04')
    _validate_target(target, dev)
    for change in ({'company': '010'}, {'branch': '01'}, {'database': 'P12'}, {'server': 'OTHER'}):
        with pytest.raises(HTTPException):
            _validate_target({**target, **change}, dev)


def test_non_dev_cannot_enable_writes(dev, monkeypatch):
    monkeypatch.setattr(config, 'PROTHEUS_WRITE_URL', 'https://example.test/rest/VFDEVOP')
    data = readiness({**dev, 'banco': 'P12'})
    assert not data['writeAvailable']
    assert data['readOnly']


def test_local_order_identity_stays_the_same_when_payload_changes():
    body = dict(opLocal='LOCAL-1', criadaEm='2026-09-25T10:00:00', produto='TEST',
                quantidade=1, armazem='01', entrega='2026-10-01', usarEstruturaProtheus=True)
    # Dados diferentes devem conflitar no ledger, nunca gerar uma segunda chave.
    assert Opening(**body).key == Opening(**{**body, 'quantidade': 2}).key
