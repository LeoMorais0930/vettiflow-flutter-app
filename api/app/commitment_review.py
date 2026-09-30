"""Revisão reversível no VettiFlow. Envia exclusões selecionadas ao executor ADVPL, sem escrever no ERP."""
import hashlib
import json
from datetime import datetime, timezone
from uuid import uuid5, NAMESPACE_URL
from . import solicitacoes as queue
from .solicitacoes_store import NovaSolicitacao, ConflitoError
from fastapi import APIRouter, HTTPException, Request, Path as PathParam
from pydantic import BaseModel, ConfigDict, Field
from . import config, mssql
from .flow_tracking import database, access_scope, is_flow_admin, allowed_stages

router = APIRouter(prefix='/api/v1/ops', tags=['Revisão de empenhos'])

class Exclusion(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    id: int = Field(gt=0)
    reason: str = Field(min_length=3, max_length=250)

class Draft(BaseModel):
    model_config = ConfigDict(extra='forbid')
    expectedVersion: int = Field(ge=0)
    fingerprint: str = Field(pattern=r'^[a-f0-9]{64}$')
    excluded: list[Exclusion] = Field(max_length=5000)

def can_save(actor):
    return is_flow_admin(actor) or bool(set(allowed_stages(actor)) & {'warehouse', 'smd', 'firmware', 'soldering', 'testing', 'closing'})

def snapshot(op, filial):
    if filial != config.FILIAL_PADRAO:
        raise HTTPException(403, 'Filial não autorizada.')
    try:
        data = mssql.commitment_review_snapshot(op, filial)
    except Exception:
        raise HTTPException(503, 'Não foi possível consultar os empenhos. Tente novamente.') from None
    if not data['order'] or data['order']['numero'] != op:
        raise HTTPException(404, 'OP não confirmada no Protheus. Um rascunho local não possui empenhos oficiais.')
    data['items'] = sorted(data['items'], key=lambda row: row['id'])
    fingerprint = hashlib.sha256(json.dumps(data, sort_keys=True, default=str).encode()).hexdigest()
    return data, fingerprint

def prepare(conn):
    conn.executescript("""
      CREATE TABLE IF NOT EXISTS commitment_reviews (
        scope TEXT NOT NULL, op TEXT NOT NULL, actor TEXT NOT NULL,
        fingerprint TEXT NOT NULL, excluded TEXT NOT NULL,
        version INTEGER NOT NULL, updated_at TEXT NOT NULL,
        PRIMARY KEY(scope, op, actor));
      CREATE TABLE IF NOT EXISTS commitment_review_history (
        scope TEXT NOT NULL, op TEXT NOT NULL, actor TEXT NOT NULL,
        fingerprint TEXT NOT NULL, excluded TEXT NOT NULL,
        version INTEGER NOT NULL, updated_at TEXT NOT NULL);
    """)

def active(op):
    return queue.store().revisao_empenhos(access_scope(), op, somente_ativas=True)


def response(data, fingerprint, row, actor):
    stale = bool(row and row['fingerprint'] != fingerprint)
    submitted = queue.store().revisao_empenhos(access_scope(), data['order']['numero'], actor)
    if submitted and (not row or submitted.payload['reviewVersion'] != row['version']
                      or submitted.payload['fingerprint'] != row['fingerprint']):
        submitted = None
    locked = active(data['order']['numero']) is not None
    return {**data, 'fingerprint': fingerprint, 'version': row['version'] if row else 0,
            'excluded': json.loads(row['excluded']) if row and not stale else [],
            'stale': stale, 'canSave': can_save(actor) and not data['order'].get('encerrada') and not locked,
            'updatedAt': row['updated_at'] if row else None,
            'appliedToErp': bool(submitted and submitted.status == 'aplicada'),
            'status': submitted.status if submitted else 'draft',
            'submission': queue._saida(submitted) if submitted else None,
            'canSubmit': config.QUEUE_ENABLED and 'exclusao_empenhos' in config.QUEUE_OPERATIONS and not locked,
            'executionEnabled': config.QUEUE_EXECUTION_ENABLED}

@router.get('/{op}/revisao-empenhos')
def read(request: Request, op: str = PathParam(pattern=r'^[A-Za-z0-9]{6,24}$'), filial: str = config.FILIAL_PADRAO):
    actor = request.state.protheus_session['username']
    data, fingerprint = snapshot(op, filial)
    with database() as conn:
        prepare(conn)
        row = conn.execute('SELECT * FROM commitment_reviews WHERE scope=? AND op=? AND actor=?',
                           (access_scope(), op, actor)).fetchone()
    return response(data, fingerprint, row, actor)

@router.put('/{op}/revisao-empenhos')
def save(body: Draft, request: Request, op: str = PathParam(pattern=r'^[A-Za-z0-9]{6,24}$'), filial: str = config.FILIAL_PADRAO):
    actor = request.state.protheus_session['username']
    if not can_save(actor):
        raise HTTPException(403, 'Seu usuário não tem permissão para salvar a revisão.')
    data, fingerprint = snapshot(op, filial)
    if data['order'].get('encerrada'):
        raise HTTPException(409, 'OP encerrada. Não é possível revisar seus empenhos.')
    if fingerprint != body.fingerprint:
        raise HTTPException(409, 'Os empenhos mudaram no Protheus. Recarregue e revise novamente.')
    ids = [item.id for item in body.excluded]
    eligible = {row['id'] for row in data['items'] if float(row['quantidade']) > 0 and not row['produto'].upper().startswith('MOD')}
    if len(ids) != len(set(ids)) or not set(ids).issubset(eligible):
        raise HTTPException(422, 'Há linhas duplicadas ou indisponíveis para retirada.')
    with database() as conn:
        prepare(conn)
        conn.execute('BEGIN IMMEDIATE')
        if active(op):
            raise HTTPException(409, 'Já existe uma revisão enviada para esta OP. Aguarde e confira o resultado.')
        row = conn.execute('SELECT * FROM commitment_reviews WHERE scope=? AND op=? AND actor=?',
                           (access_scope(), op, actor)).fetchone()
        if (row['version'] if row else 0) != body.expectedVersion:
            raise HTTPException(409, 'A revisão foi alterada em outra aba. Recarregue antes de salvar.')
        if not is_flow_admin(actor) and not set(allowed_stages(actor, conn)) & {'warehouse', 'smd', 'firmware', 'soldering', 'testing', 'closing'}:
            raise HTTPException(403, 'Permissão de revisão revogada.')
        values = (access_scope(), op, actor, fingerprint,
                  json.dumps([item.model_dump() for item in body.excluded], ensure_ascii=False),
                  body.expectedVersion + 1, datetime.now(timezone.utc).isoformat())
        conn.execute('INSERT OR REPLACE INTO commitment_reviews VALUES (?,?,?,?,?,?,?)', values)
        conn.execute('INSERT INTO commitment_review_history VALUES (?,?,?,?,?,?,?)', values)
        conn.commit()
        row = conn.execute('SELECT * FROM commitment_reviews WHERE scope=? AND op=? AND actor=?',
                           (access_scope(), op, actor)).fetchone()
    return response(data, fingerprint, row, actor)


class Submit(BaseModel):
    model_config = ConfigDict(extra='forbid')
    expectedVersion: int = Field(ge=1)
    fingerprint: str = Field(pattern=r'^[a-f0-9]{64}$')


@router.post('/{op}/revisao-empenhos/enviar')
def submit(body: Submit, request: Request, op: str = PathParam(pattern=r'^[A-Za-z0-9]{6,24}$'),
           filial: str = config.FILIAL_PADRAO):
    queue._exigir_fila()
    if 'exclusao_empenhos' not in config.QUEUE_OPERATIONS:
        raise HTTPException(503, 'Exclusão de empenhos ainda não liberada para envio.')
    actor = request.state.protheus_session['username']
    if not can_save(actor):
        raise HTTPException(403, 'Seu usuário não pode enviar exclusões de empenhos.')
    if filial != config.FILIAL_PADRAO:
        raise HTTPException(403, 'Filial não autorizada.')
    identity = str(uuid5(NAMESPACE_URL, json.dumps([access_scope(), op, actor,
                   body.expectedVersion, body.fingerprint])))
    with database() as conn:
        prepare(conn)
        conn.execute('BEGIN IMMEDIATE')
        # Reenvio após timeout devolve a mesma solicitação, inclusive depois da execução.
        previous = queue.store().obter(identity)
        if previous:
            return queue._saida(previous)
        row = conn.execute('SELECT * FROM commitment_reviews WHERE scope=? AND op=? AND actor=?',
                           (access_scope(), op, actor)).fetchone()
        if not row or row['version'] != body.expectedVersion or row['fingerprint'] != body.fingerprint:
            raise HTTPException(409, 'Salve e recarregue a revisão atual antes de enviar.')
        data, fingerprint = snapshot(op, filial)
        if fingerprint != body.fingerprint or data['order'].get('encerrada'):
            raise HTTPException(409, 'A OP ou os empenhos mudaram. Recarregue e revise novamente.')
        excluded = json.loads(row['excluded'])
        eligible = {item['id'] for item in data['items'] if float(item['quantidade']) > 0
                    and not item['produto'].upper().startswith('MOD')}
        if not excluded or any(item['id'] not in eligible for item in excluded):
            raise HTTPException(422, 'Selecione ao menos um empenho de material válido. MOD fica separado.')
        # Não criar um comando executável sem todas as chaves nativas da SD4.
        keys = {'id','produto','local','quantidade','quantidadeOriginal','tratamento',
                'loteControle','numeroLote','opOrigem','sequencia'}
        if any(not keys.issubset(item) for item in data['items']):
            raise HTTPException(503, 'Consulta de empenhos sem identificação completa para o ADVPL.')
        native_keys = ('produto','tratamento','loteControle','numeroLote','local','opOrigem','sequencia')
        identities = [tuple(item[k] for k in native_keys) for item in data['items']]
        if len(set(identities)) != len(identities):
            raise HTTPException(409, 'Há empenhos com identificação nativa duplicada. Confira no Protheus antes de excluir.')
        order_keys = {'numeroBase','item','sequencia','itemGrade','produto','emissao','local',
                      'quantidadePlanejada','quantidadeProduzida'}
        if not order_keys.issubset(data['order']):
            raise HTTPException(503, 'OP sem identificação completa para o ADVPL.')
        if not is_flow_admin(actor) and not set(allowed_stages(actor, conn)) & {'warehouse','smd','firmware','soldering','testing','closing'}:
            raise HTTPException(403, 'Permissão revogada.')
        payload = {'op': op, 'scope': access_scope(), 'fingerprint': fingerprint,
                   'reviewVersion': body.expectedVersion, 'excluded': excluded,
                   'snapshot': json.loads(json.dumps(data, default=str))}
        try:
            item, _ = queue.store().criar(NovaSolicitacao(identity, queue.VERSAO_CONTRATO,
                         'exclusao_empenhos', queue.EMPRESA, filial, payload, actor))
        except ConflitoError as exc:
            raise HTTPException(409, str(exc)) from None
    return queue._saida(item)
