"""Adaptador SQL Server para o fluxo DEV; não altera schema automaticamente."""
from contextlib import contextmanager
from decimal import Decimal
import json
import re

from . import config, mssql

TABLES = ('NNR', 'SB1', 'SB2', 'SC2', 'SD3', 'SD4', 'SG1')
WRITABLE = ('SB2', 'SC2', 'SD3', 'SD4')


def configured():
    return (config.MSSQL_DATABASE.lower() == 'hmlp12'
            and config.MSSQL_SCHEMA == 'dbo' and config.EMPRESA == '010'
            and config.FILIAL_PADRAO == '04' and config.PROTHEUS_COMPANY_GROUP == '01')


def query(connection, sql, params=()):
    cursor = connection.cursor()
    cursor.execute(sql, tuple(params))
    if not cursor.description:
        return []
    names = [column[0] for column in cursor.description]
    return [dict(zip(names, row)) for row in cursor.fetchall()]


class SqlDatabase:
    @contextmanager
    def transaction(self, preview=False):
        if not configured():
            raise ValueError('Escrita SQL exclusiva de HMLp12, dbo, grupo 01 e filial 04.')
        with mssql.conexao() as connection:
            # Explicit T-SQL transaction; no nested implicit ODBC transaction.
            connection.autocommit = True
            connection.timeout = 30
            cursor = connection.cursor()
            cursor.execute('SET XACT_ABORT ON; SET LOCK_TIMEOUT 5000; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; BEGIN TRANSACTION;')
            try:
                identity = query(connection, 'SELECT DB_NAME() AS [database]')[0]['database']
                if str(identity).lower() != 'hmlp12':
                    raise ValueError('Conexão efetiva não é HMLp12.')
                lock = query(connection, """DECLARE @result int;
                    EXEC @result=sys.sp_getapplock @Resource=N'VettiFlow.SQL.DEV.v1',
                        @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=5000;
                    SELECT @result AS result;""")[0]['result']
                if lock < 0:
                    raise ValueError('Fluxo SQL ocupado; consulte o pedido antes de repetir.')
                session = SqlSession(connection)
                session.prepare()
                yield session
                cursor.execute('ROLLBACK TRANSACTION' if preview else 'COMMIT TRANSACTION')
            except BaseException:
                try:
                    cursor.execute('IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION')
                except Exception:
                    pass  # Original error remains authoritative; caller queries request ID.
                raise

    def result(self, key):
        if not configured():
            raise ValueError('Consulta de escrita exclusiva do DEV.')
        with mssql.conexao() as connection:
            identity = query(connection, 'SELECT DB_NAME() AS [database]')[0]['database']
            if str(identity).lower() != 'hmlp12':
                raise ValueError('Conexão efetiva não é HMLp12.')
            return SqlSession(connection).request(key)


class SqlSession:
    def __init__(self, connection):
        self.connection = connection
        self.columns = {}
        self.recnos = {}

    def table(self, table):
        if table not in TABLES:
            raise ValueError('Tabela fora do fluxo de produção.')
        return f'[dbo].[{table}010]'

    def prepare(self):
        versions = query(self.connection, 'SELECT version FROM dbo.VF_SQL_VERSION')
        if versions != [{'version': 1}]:
            raise ValueError('Instale a migração SQL DEV v1 antes de usar o fluxo.')
        for table in TABLES:
            name = table + '010'
            rows = query(self.connection, """SELECT c.name AS [name], t.name AS [type],
                c.max_length AS [length],c.is_identity AS [identity],c.is_computed AS computed,
                c.is_nullable AS nullable,c.default_object_id AS default_id
                FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id
                WHERE c.object_id=OBJECT_ID(?)""", (f'dbo.{name}',))
            self.columns[table] = {r['name']: r for r in rows}
            columns = self.columns[table]
            if 'R_E_C_N_O_' not in columns or 'D_E_L_E_T_' not in columns:
                raise ValueError(f'Schema incompatível: {table}.')
            if table in WRITABLE:
                if columns['R_E_C_N_O_']['identity']:
                    raise ValueError('Perfil de RECNO diferente do DEV mapeado; revise o adaptador.')
                triggers = query(self.connection, 'SELECT name FROM sys.triggers WHERE parent_id=OBJECT_ID(?) AND is_disabled=0', (f'dbo.{name}',))
                if triggers:
                    raise ValueError(f'{table} tem triggers ativos não mapeados; revise antes de gravar.')
            # Table locks coordinate SQL writers; they do not invalidate DBAccess
            # caches. SQL_EXCLUSIVE_DEV must mean AppServer/DBAccess are stopped.
            last = query(self.connection, f'SELECT COALESCE(MAX([R_E_C_N_O_]),0) AS last FROM {self.table(table)} WITH (TABLOCKX,HOLDLOCK)')[0]['last']
            self.recnos[table] = int(last)

    def checked(self, table, values):
        columns = self.columns[table]
        for key, value in values.items():
            if key not in columns or not re.fullmatch(r'[A-Z0-9_]+', key):
                raise ValueError('Campo SQL não permitido.')
            column = columns[key]
            if column['type'] in ('varchar', 'char') and isinstance(value, str):
                try:
                    size = len(value.encode('cp1252'))
                except UnicodeEncodeError as exc:
                    raise ValueError('Texto não suportado pelo cadastro Protheus.') from exc
                if column['length'] != -1 and size > column['length']:
                    raise ValueError(f'Texto excede o tamanho de {key}.')
        return list(values)

    def rows(self, table, **filters):
        keys = self.checked(table, filters)
        where = "[D_E_L_E_T_]=''" + ''.join(f' AND [{key}]=?' for key in keys)
        return query(self.connection, f'SELECT * FROM {self.table(table)} WHERE {where}', filters.values())

    def insert(self, table, values):
        if table not in WRITABLE:
            raise ValueError('Tabela não gravável.')
        self.recnos[table] += 1
        recno = self.recnos[table]
        if recno > 2147483647:
            raise ValueError('Faixa de RECNO excedida.')
        values = dict(values, R_E_C_N_O_=recno)
        if 'D_E_L_E_T_' in self.columns[table]:
            values['D_E_L_E_T_'] = ''
        if 'R_E_C_D_E_L_' in self.columns[table]:
            values['R_E_C_D_E_L_'] = 0
        keys = self.checked(table, values)
        cursor = self.connection.cursor()
        cursor.execute(f'INSERT INTO {self.table(table)} ({",".join("["+k+"]" for k in keys)}) VALUES ({",".join("?" for _ in keys)})', tuple(values.values()))
        return values

    def update(self, table, recno, values):
        if table not in WRITABLE or 'R_E_C_N_O_' in values or 'D_E_L_E_T_' in values:
            raise ValueError('Atualização fora do fluxo permitido.')
        keys = self.checked(table, values)
        cursor = self.connection.cursor()
        cursor.execute(f'UPDATE {self.table(table)} SET '+','.join(f'[{k}]=?' for k in keys)+" WHERE [R_E_C_N_O_]=? AND [D_E_L_E_T_]=''", (*values.values(), recno))
        if cursor.rowcount != 1:
            raise ValueError('Registro mudou ou não existe; operação desfeita.')

    def number(self, kind):
        if kind not in ('order', 'movement'):
            raise ValueError('Sequência desconhecida.')
        while True:
            rows = query(self.connection, 'UPDATE dbo.VF_SQL_COUNTERS SET value=value+1 OUTPUT INSERTED.value WHERE kind=? AND value<99999', (kind,))
            if not rows:
                raise ValueError('Faixa de numeração VettiFlow esgotada ou não instalada.')
            number = ('V' if kind == 'order' else 'X') + str(rows[0]['value']).zfill(5)
            # Include deleted records and all branches; never reuse an ERP key.
            table, field = ('SC2', 'C2_NUM') if kind == 'order' else ('SD3', 'D3_NUMSEQ')
            existing = query(self.connection, f'SELECT TOP (1) [{field}] FROM {self.table(table)} WHERE [{field}]=?', (number,))
            if not existing:
                return number

    def request(self, key):
        rows = query(self.connection, 'SELECT fingerprint,result FROM dbo.VF_SQL_REQUESTS WHERE id=?', (key,))
        return {'fingerprint': rows[0]['fingerprint'], 'result': json.loads(rows[0]['result'])} if rows else None

    def save_request(self, key, fingerprint, result):
        self.connection.cursor().execute('INSERT INTO dbo.VF_SQL_REQUESTS(id,fingerprint,result) VALUES (?,?,?)',
                                         (key, fingerprint, json.dumps(result, ensure_ascii=False)))

    def manifest(self, reference):
        rows = query(self.connection, 'SELECT manifest FROM dbo.VF_SQL_ORDERS WHERE op=?', (reference,))
        return json.loads(rows[0]['manifest']) if rows else None

    def save_manifest(self, reference, manifest):
        body = json.dumps(manifest, ensure_ascii=False)
        cursor = self.connection.cursor()
        cursor.execute('UPDATE dbo.VF_SQL_ORDERS SET manifest=? WHERE op=?', (body, reference))
        if cursor.rowcount == 0:
            cursor.execute('INSERT INTO dbo.VF_SQL_ORDERS(op,manifest) VALUES (?,?)', (reference, body))
