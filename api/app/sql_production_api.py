"""Comandos explícitos do fluxo SQL DEV, separados da fila legada."""
from datetime import date
import secrets

from fastapi import APIRouter, Header, HTTPException

from . import config
from .sql_production import Command, StaleDateError, execute
from .sql_production_db import SqlDatabase, configured

router = APIRouter(prefix='/api/v1/dev/producao-sql', tags=['Produção SQL DEV'])


@router.get('/status')
def status():
    reasons = []
    if not config.SQL_WRITE_ENABLED:
        reasons.append('Escrita SQL DEV desativada.')
    if not config.SQL_EXCLUSIVE_DEV:
        reasons.append('Reserve o DEV sem AppServer/DBAccess acessando esta base durante a escrita SQL.')
    if not config.SQL_WRITE_TOKEN:
        reasons.append('Falta configurar a chave exclusiva de escrita.')
    if not configured():
        reasons.append('A conexão precisa ser HMLp12/dbo, grupo 01, filial 04, tabelas 010.')
    return dict(enabled=not reasons, database='HMLp12', filial='04',
                operations=['abrir', 'alterar', 'transferir', 'apontar'], reasons=reasons,
                schemaRequired=1, connectionVerified=False,
                limits=['OPs da produção 05 criadas neste fluxo',
                        'Sem lotes, séries, endereços ou segunda unidade',
                        'Custos correntes; sem estorno, fiscal ou recálculo de fechamento'])


def authorize(key):
    if not status()['enabled']:
        raise HTTPException(503, ' '.join(status()['reasons']))
    if not key or not secrets.compare_digest(key, config.SQL_WRITE_TOKEN):
        raise HTTPException(401, 'Chave de escrita inválida.')


@router.post('/comandos')
def command(payload: Command, x_vettiflow_write_key: str | None = Header(default=None)):
    authorize(x_vettiflow_write_key)
    try:
        return execute(SqlDatabase(), payload, today=date.today())
    except StaleDateError as exc:
        raise HTTPException(422, str(exc)) from None
    except ValueError as exc:
        raise HTTPException(409, str(exc)) from None
    except Exception:
        raise HTTPException(503, 'Resultado não confirmado. Consulte este identificador antes de criar outro pedido; não houve confirmação de sucesso.') from None


@router.get('/comandos/{key}')
def result(key: str, x_vettiflow_write_key: str | None = Header(default=None)):
    authorize(x_vettiflow_write_key)
    if not key or len(key) > 100:
        raise HTTPException(422, 'Identificador inválido.')
    try:
        saved = SqlDatabase().result(key)
    except Exception:
        raise HTTPException(503, 'Não foi possível consultar o resultado da operação.') from None
    if not saved:
        raise HTTPException(404, 'Pedido ainda sem confirmação registrada. Use o mesmo identificador para repetir os mesmos dados.')
    return saved['result']
