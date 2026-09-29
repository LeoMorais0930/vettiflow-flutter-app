"""Apontamentos próprios do VettiFlow; SQLite independente do banco restaurado do ERP."""
import hashlib
import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request, Path as PathParam
from pydantic import BaseModel, ConfigDict, Field, field_validator
from . import config, mssql

router = APIRouter(prefix='/api/v1/flow', tags=['Apontamentos VettiFlow'])
STAGES = ['warehouse', 'smd', 'firmware', 'soldering', 'testing', 'closing', 'expedition']

class OrderKey(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    filial: str = Field(pattern=r'^[0-9A-Za-z]{1,4}$')
    numero: str = Field(pattern=r'^[0-9A-Za-z]{1,12}$')
    item: str = Field(pattern=r'^[0-9A-Za-z]{1,4}$')
    sequencia: str = Field(pattern=r'^[0-9A-Za-z]{1,4}$')
    grade: str = Field(default='', pattern=r'^[0-9A-Za-z]{0,4}$')

class EventCommand(BaseModel):
    model_config = ConfigDict(extra='forbid')
    key: OrderKey
    requestId: UUID
    expectedVersion: int = Field(ge=0)
    stage: Literal['warehouse', 'smd', 'firmware', 'soldering', 'testing', 'closing', 'expedition']
    action: Literal['start', 'pause', 'resume', 'complete']
    note: str = Field(default='', max_length=500)


def key_id(key):
    if key.filial != config.FILIAL_PADRAO:
        raise HTTPException(403, 'Filial não autorizada pela sessão desta API.')
    return json.dumps([config.PROTHEUS_COMPANY_GROUP, config.MSSQL_DATABASE, *key.model_dump().values()], separators=(',', ':'))


def is_flow_admin(username):
    return username.strip().casefold() in {u.strip().casefold() for u in config.FLOW_ADMIN_USERS}


def access_scope():
    return json.dumps([config.PROTHEUS_COMPANY_GROUP, config.MSSQL_DATABASE, config.FILIAL_PADRAO])


def allowed_stages(username, conn=None):
    if is_flow_admin(username):
        return STAGES
    if conn is None:
        with database() as opened:
            return allowed_stages(username, opened)
    row = conn.execute('SELECT stages FROM flow_access WHERE scope=? AND username=?',
                       (access_scope(), username.strip().casefold())).fetchone()
    configured = json.loads(row['stages']) if row else config.FLOW_STAGE_USERS.get(username.strip().casefold(), [])
    return [stage for stage in STAGES if stage in configured]


def official_order(key):
    with mssql.conexao() as conn:
        row = mssql._fetchone(conn, f"""
            SELECT LTRIM(RTRIM(C2_PRODUTO)) AS produto, C2_EMISSAO AS emissao,
                   C2_DATRF AS encerramento
            FROM {mssql.tabela('SC2')}
            WHERE D_E_L_E_T_ <> '*' AND C2_FILIAL = ?
              AND LTRIM(RTRIM(C2_NUM)) = ? AND LTRIM(RTRIM(C2_ITEM)) = ?
              AND LTRIM(RTRIM(C2_SEQUEN)) = ? AND COALESCE(LTRIM(RTRIM(C2_ITEMGRD)), '') = ?
        """, (key.filial, key.numero, key.item, key.sequencia, key.grade))
    if row:
        row['encerrada'] = bool(str(row.get('encerramento') or '').strip())
    return row


@contextmanager
def database():
    config.FLOW_DB.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(config.FLOW_DB, timeout=10)
    conn.row_factory = sqlite3.Row
    try:
        conn.executescript("""
          CREATE TABLE IF NOT EXISTS flow_state (
            order_key TEXT PRIMARY KEY, fingerprint TEXT NOT NULL,
            stage TEXT NOT NULL, status TEXT NOT NULL, version INTEGER NOT NULL,
            updated_at TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS flow_events (
            request_id TEXT PRIMARY KEY, order_key TEXT NOT NULL,
            payload_hash TEXT NOT NULL, actor TEXT NOT NULL,
            stage TEXT NOT NULL, action TEXT NOT NULL, note TEXT NOT NULL,
            version INTEGER NOT NULL, created_at TEXT NOT NULL);
          CREATE INDEX IF NOT EXISTS flow_events_order ON flow_events(order_key, version);
          CREATE TABLE IF NOT EXISTS flow_access (
            scope TEXT NOT NULL, username TEXT NOT NULL, stages TEXT NOT NULL,
            version INTEGER NOT NULL, actor TEXT NOT NULL, updated_at TEXT NOT NULL,
            PRIMARY KEY(scope, username));
          CREATE TABLE IF NOT EXISTS flow_access_audit (
            id INTEGER PRIMARY KEY AUTOINCREMENT, scope TEXT NOT NULL,
            username TEXT NOT NULL, before_stages TEXT NOT NULL, after_stages TEXT NOT NULL,
            version INTEGER NOT NULL, actor TEXT NOT NULL, created_at TEXT NOT NULL);
          CREATE INDEX IF NOT EXISTS flow_access_history ON flow_access_audit(scope, username, version);
        """)
        yield conn
    finally:
        conn.close()


def snapshot(conn, key, username):
    state = conn.execute('SELECT stage,status,version,updated_at AS updatedAt FROM flow_state WHERE order_key=?', (key,)).fetchone()
    events = conn.execute('SELECT request_id AS requestId,actor,stage,action,note,version,created_at AS createdAt FROM flow_events WHERE order_key=? ORDER BY version DESC LIMIT 200', (key,)).fetchall()
    return {'state': dict(state) if state else {'stage': None, 'status': 'waiting', 'version': 0},
            'events': [dict(row) for row in events], 'allowedStages': allowed_stages(username, conn),
            'erpWritesEnabled': False}


class AccessCommand(BaseModel):
    model_config = ConfigDict(extra='forbid')
    stages: list[Literal['warehouse', 'smd', 'firmware', 'soldering', 'testing', 'closing', 'expedition']] = Field(max_length=7)
    expectedVersion: int = Field(ge=0)

    @field_validator('stages')
    @classmethod
    def unique_stages(cls, value):
        if len(set(value)) != len(value):
            raise ValueError('Etapas duplicadas.')
        return [stage for stage in STAGES if stage in value]


def require_flow_admin(request):
    actor = request.state.protheus_session['username']
    if not is_flow_admin(actor):
        raise HTTPException(403, 'Somente administradores podem gerenciar permissões de execução.')
    return actor


def access_snapshot(conn, username, history=False):
    username = username.strip().casefold()
    row = conn.execute('SELECT version,actor,updated_at FROM flow_access WHERE scope=? AND username=?',
                       (access_scope(), username)).fetchone()
    result = {'username': username, 'stages': allowed_stages(username, conn),
              'version': row['version'] if row else 0, 'isAdmin': is_flow_admin(username),
              'source': 'saved' if row else 'configuration',
              'updatedBy': row['actor'] if row else None, 'updatedAt': row['updated_at'] if row else None}
    if history:
        rows = conn.execute('''SELECT before_stages,after_stages,version,actor,created_at FROM flow_access_audit
            WHERE scope=? AND username=? ORDER BY version DESC LIMIT 100''', (access_scope(), username)).fetchall()
        result['history'] = [{'before': json.loads(r['before_stages']), 'after': json.loads(r['after_stages']),
                              'version': r['version'], 'actor': r['actor'], 'createdAt': r['created_at']} for r in rows]
    return result


@router.get('/access/me')
def my_access(request: Request):
    actor = request.state.protheus_session['username']
    return {'username': actor, 'canManage': is_flow_admin(actor), 'stages': allowed_stages(actor)}


@router.get('/access/users')
def access_users(request: Request):
    require_flow_admin(request)
    with database() as conn:
        rows = conn.execute('SELECT username FROM flow_access WHERE scope=?', (access_scope(),)).fetchall()
        names = {r['username'] for r in rows} | {u.strip().casefold() for u in config.FLOW_ADMIN_USERS} | {u.strip().casefold() for u in config.FLOW_STAGE_USERS}
        return {'items': [access_snapshot(conn, name) for name in sorted(names)]}


@router.get('/access/directory')
def protheus_directory(request: Request):
    require_flow_admin(request)
    try:
        items = mssql.active_users()
    except Exception:
        raise HTTPException(503, 'Não foi possível consultar os usuários ativos do Protheus. Tente atualizar novamente.') from None
    return {'items': items, 'sourceDatabase': config.MSSQL_DATABASE,
            'queriedAt': datetime.now(timezone.utc).isoformat()}


@router.get('/access/users/{username}')
def user_access(request: Request, username: str = PathParam(pattern=r'^[A-Za-z0-9][A-Za-z0-9._@-]{0,63}$')):
    require_flow_admin(request)
    with database() as conn:
        return access_snapshot(conn, username, history=True)


@router.put('/access/users/{username}')
def update_access(body: AccessCommand, request: Request, username: str = PathParam(pattern=r'^[A-Za-z0-9][A-Za-z0-9._@-]{0,63}$')):
    actor = require_flow_admin(request)
    username = username.casefold()
    if is_flow_admin(username):
        raise HTTPException(403, 'O acesso dos administradores é definido na configuração do servidor.')
    with database() as conn:
        conn.execute('BEGIN IMMEDIATE')
        try:
            old = access_snapshot(conn, username)
            if body.expectedVersion != old['version']:
                raise HTTPException(409, 'As permissões foram alteradas. Consulte o usuário novamente antes de salvar.')
            now = datetime.now(timezone.utc).isoformat()
            version = old['version'] + 1
            conn.execute('INSERT OR REPLACE INTO flow_access VALUES (?,?,?,?,?,?)',
                         (access_scope(), username, json.dumps(body.stages), version, actor, now))
            conn.execute('''INSERT INTO flow_access_audit
                (scope,username,before_stages,after_stages,version,actor,created_at) VALUES (?,?,?,?,?,?,?)''',
                (access_scope(), username, json.dumps(old['stages']), json.dumps(body.stages), version, actor, now))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        return access_snapshot(conn, username, history=True)


@router.get('/states')
def read_states(request: Request):
    """Sparse dashboard snapshot; only the configured company/database/branch."""
    items = []
    with database() as conn:
        rows = conn.execute('''
            SELECT s.*, e.actor, e.note FROM flow_state s
            JOIN flow_events e ON e.order_key=s.order_key AND e.version=s.version
            WHERE json_extract(s.order_key, '$[0]')=?
              AND json_extract(s.order_key, '$[1]')=?
              AND json_extract(s.order_key, '$[2]')=?
            ORDER BY s.order_key
        ''', (config.PROTHEUS_COMPANY_GROUP, config.MSSQL_DATABASE, config.FILIAL_PADRAO)).fetchall()
        for row in rows:
            identity = json.loads(row['order_key'])
            product, issued = json.loads(row['fingerprint'])
            items.append({
                'key': dict(zip(OrderKey.model_fields, identity[2:])),
                'produto': product, 'emissao': issued,
                'stage': row['stage'], 'status': row['status'], 'version': row['version'],
                'updatedAt': row['updated_at'], 'actor': row['actor'], 'note': row['note'],
            })
    return {'items': items}


@router.get('/order')
def read_order(request: Request, filial: str, numero: str, item: str, sequencia: str, grade: str = ''):
    # Pydantic validation errors must use a standard client response.
    from pydantic import ValidationError
    try:
        key = OrderKey(filial=filial, numero=numero, item=item, sequencia=sequencia, grade=grade)
    except ValidationError:
        raise HTTPException(422, 'Chave da OP inválida.') from None
    identity = key_id(key)
    with database() as conn:
        return snapshot(conn, identity, request.state.protheus_session['username'])


@router.post('/events')
def write_event(body: EventCommand, request: Request):
    username = request.state.protheus_session['username']
    identity = key_id(body.key)
    if body.stage not in allowed_stages(username):
        raise HTTPException(403, 'Usuário sem autorização para apontar nesta etapa.')
    if body.action == 'pause' and not body.note.strip():
        raise HTTPException(422, 'Informe o motivo da pausa.')
    payload = body.model_dump(mode='json')
    payload_hash = hashlib.sha256(json.dumps([payload, username], sort_keys=True).encode()).hexdigest()
    # Fast idempotent replay; SQL verification is unnecessary for an already committed event.
    with database() as conn:
        existing = conn.execute('SELECT payload_hash FROM flow_events WHERE request_id=?', (str(body.requestId),)).fetchone()
        if existing:
            if existing['payload_hash'] != payload_hash:
                raise HTTPException(409, 'Identificador já usado em outro apontamento.')
            return snapshot(conn, identity, username)
    try:
        official = official_order(body.key)
    except Exception:
        raise HTTPException(503, 'Não foi possível conferir a OP no Protheus. Nenhum apontamento foi salvo.') from None
    if official is None:
        raise HTTPException(404, 'OP não encontrada no Protheus.')
    if official['encerrada']:
        raise HTTPException(409, 'OP encerrada no Protheus; novos apontamentos bloqueados.')
    fingerprint = json.dumps([official['produto'], str(official['emissao'])])
    with database() as conn:
        conn.execute('BEGIN IMMEDIATE')
        try:
            if body.stage not in allowed_stages(username, conn):
                raise HTTPException(403, 'Permissão de execução removida. Consulte seus acessos novamente.')
            existing = conn.execute('SELECT payload_hash FROM flow_events WHERE request_id=?', (str(body.requestId),)).fetchone()
            if existing:
                if existing['payload_hash'] != payload_hash:
                    raise HTTPException(409, 'Identificador já usado em outro apontamento.')
                conn.rollback()
                return snapshot(conn, identity, username)
            old = conn.execute('SELECT * FROM flow_state WHERE order_key=?', (identity,)).fetchone()
            version = old['version'] if old else 0
            if version != body.expectedVersion:
                raise HTTPException(409, 'A OP foi atualizada por outra pessoa. Recarregue o apontamento.')
            if old and old['fingerprint'] != fingerprint:
                raise HTTPException(409, 'A identidade da OP mudou na base ERP. Revise o vínculo antes de continuar.')
            if body.action == 'start':
                valid = old is None or (old['status'] == 'completed' and STAGES.index(body.stage) > STAGES.index(old['stage']))
                status = 'active'
            else:
                valid = old is not None and old['stage'] == body.stage and old['status'] == {'pause':'active', 'resume':'paused', 'complete':'active'}[body.action]
                status = {'pause':'paused', 'resume':'active', 'complete':'completed'}[body.action]
            if not valid:
                raise HTTPException(409, 'Transição inválida. Confira a etapa e o estado atual da OP.')
            now = datetime.now(timezone.utc).isoformat()
            conn.execute('INSERT OR REPLACE INTO flow_state VALUES (?,?,?,?,?,?)', (identity, fingerprint, body.stage, status, version+1, now))
            conn.execute('INSERT INTO flow_events VALUES (?,?,?,?,?,?,?,?,?)', (str(body.requestId), identity, payload_hash, username, body.stage, body.action, body.note.strip(), version+1, now))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        return snapshot(conn, identity, username)
