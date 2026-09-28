import importlib
from contextlib import contextmanager

import pytest


class Cursor:
    def __init__(self, connection):
        self.connection = connection
        self.description = []
        self.result = []
        self.rowcount = 1

    def execute(self, sql, params=()):
        self.connection.calls.append((sql, params))
        self.description, self.result = [], []
        if 'DB_NAME()' in sql:
            self.description = [('database',)]
            self.result = [(self.connection.database,)]
        elif 'sp_getapplock' in sql:
            self.description = [('result',)]
            self.result = [(self.connection.lock_result,)]
        elif 'VF_SQL_VERSION' in sql:
            self.description = [('version',)]
            self.result = [(self.connection.version,)]
        elif 'FROM sys.columns' in sql:
            self.description = [(k,) for k in ('name', 'type', 'length', 'identity', 'computed', 'nullable', 'default_id')]
            self.result = [('R_E_C_N_O_', 'int', 4, self.connection.identity, False, False, 1),
                           ('D_E_L_E_T_', 'varchar', 1, False, False, False, 1),
                           ('R_E_C_D_E_L_', 'int', 4, False, False, False, 1)]
        elif 'FROM sys.triggers' in sql:
            self.description = [('name',)]
            self.result = [('unknown_trigger',)] if self.connection.triggers else []
        elif 'MAX(' in sql:
            self.description = [('last',)]
            self.result = [(10,)]
        elif 'OUTPUT INSERTED' in sql:
            self.description = [('value',)]
            self.connection.counter += 1
            self.result = [(self.connection.counter,)] if self.connection.counter <= 99999 else []
        elif 'SELECT TOP (1)' in sql and self.connection.counter == 1:
            self.description = [('existing',)]
            self.result = [('collision',)]
        elif 'SELECT fingerprint,result' in sql:
            self.description = [('fingerprint',), ('result',)]
            self.result = [('hash', '{"status":"aplicada"}')] if self.connection.saved else []
        elif 'SELECT manifest' in sql:
            self.description = [('manifest',)]
            self.result = [('{"product":"PA1"}',)] if self.connection.saved else []
        self.rowcount = self.connection.rowcount
        return self

    def fetchone(self):
        return self.result[0] if self.result else None

    def fetchall(self):
        return self.result


class Connection:
    database = 'HMLp12'
    lock_result = 0
    version = 1
    identity = False
    triggers = False
    counter = 0
    rowcount = 1
    saved = False
    def __init__(self):
        self.calls = []
    def cursor(self):
        return Cursor(self)


@pytest.fixture
def module():
    return importlib.import_module('app.sql_production_db')


def test_insert_uses_parameters_and_validates_field_names(module):
    connection = Connection()
    session = module.SqlSession(connection)
    session.columns = {'SC2': {'C2_NUM': {'type': 'varchar', 'length': 6},
                               'R_E_C_N_O_': {'type': 'int', 'length': 4}}}
    session.recnos = {'SC2': 10}
    session.insert('SC2', {'C2_NUM': 'A\'001'})
    sql, params = connection.calls[-1]
    assert 'A\'001' not in sql and 'A\'001' in params
    assert '[R_E_C_N_O_]' in sql and 11 in params
    with pytest.raises(ValueError):
        session.insert('SC2', {'C2_NUM); DROP TABLE X--': 'x'})
    with pytest.raises(ValueError):
        session.insert('SC2', {'C2_NUM': 'TOO-LONG'})


@pytest.mark.parametrize('preview', [True, False])
def test_transaction_locks_and_ends_correctly(module, monkeypatch, preview):
    connection = Connection()
    @contextmanager
    def connect():
        yield connection
    monkeypatch.setattr(module.mssql, 'conexao', connect)
    monkeypatch.setattr(module.SqlSession, 'prepare', lambda self: None)
    with module.SqlDatabase().transaction(preview=preview):
        pass
    statements = [sql for sql, _ in connection.calls]
    assert any('XACT_ABORT ON' in sql and 'BEGIN TRANSACTION' in sql for sql in statements)
    assert any('sp_getapplock' in sql for sql in statements)
    assert statements[-1] == ('ROLLBACK TRANSACTION' if preview else 'COMMIT TRANSACTION')


def test_wrong_live_database_rolls_back_before_any_insert(module, monkeypatch):
    connection = Connection()
    connection.database = 'VettiP12'
    @contextmanager
    def connect():
        yield connection
    monkeypatch.setattr(module.mssql, 'conexao', connect)
    with pytest.raises(ValueError, match='HMLp12'):
        with module.SqlDatabase().transaction():
            pytest.fail('wrong database yielded')
    assert not any('INSERT INTO' in sql for sql, _ in connection.calls)


def test_lock_failure_rolls_back(module, monkeypatch):
    connection = Connection()
    connection.lock_result = -1
    @contextmanager
    def connect():
        yield connection
    monkeypatch.setattr(module.mssql, 'conexao', connect)
    with pytest.raises(ValueError, match='ocupado'):
        with module.SqlDatabase().transaction():
            pytest.fail('lock failure yielded')
    assert connection.calls[-1][0] == 'IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION'


def test_prepare_verifies_profile_and_locks_all_tables(module):
    connection = Connection()
    session = module.SqlSession(connection)
    session.prepare()
    assert set(session.columns) == set(module.TABLES)
    assert session.recnos == dict.fromkeys(module.TABLES, 10)
    assert sum('TABLOCKX,HOLDLOCK' in sql for sql, _ in connection.calls) == 7


@pytest.mark.parametrize('attribute,value', [('version', 2), ('identity', True), ('triggers', True)])
def test_prepare_rejects_unmapped_schema_before_any_dml(module, attribute, value):
    connection = Connection()
    setattr(connection, attribute, value)
    with pytest.raises(ValueError):
        module.SqlSession(connection).prepare()
    assert not any('INSERT INTO' in sql or sql.startswith('UPDATE ') for sql, _ in connection.calls)


def test_number_skips_existing_erp_keys_and_refuses_exhaustion(module):
    connection = Connection()
    session = module.SqlSession(connection)
    assert session.number('order') == 'V00002'
    assert session.number('movement') == 'X00003'
    assert not any('D_E_L_E_T_' in sql for sql, _ in connection.calls)
    connection.counter = 99999
    with pytest.raises(ValueError, match='esgotada'):
        session.number('order')
    with pytest.raises(ValueError):
        session.number('arbitrary')


def test_update_requires_exactly_one_record_and_filters_are_parameterized(module):
    connection = Connection()
    session = module.SqlSession(connection)
    session.columns = {'SB2': {'B2_COD': {'type': 'varchar', 'length': 30},
                              'B2_QATU': {'type': 'float', 'length': 8}}}
    session.rows('SB2', B2_COD="X' OR 1=1--")
    sql, params = connection.calls[-1]
    assert "X' OR 1=1--" not in sql and params == ("X' OR 1=1--",)
    session.update('SB2', 12, {'B2_QATU': 2})
    assert connection.calls[-1][1] == (2, 12)
    connection.rowcount = 0
    with pytest.raises(ValueError, match='Registro'):
        session.update('SB2', 12, {'B2_QATU': 2})
    for values in ({'R_E_C_N_O_': 2}, {'D_E_L_E_T_': '*'}):
        with pytest.raises(ValueError):
            session.update('SB2', 12, values)


def test_journal_and_manifest_round_trip_and_missing_results(module):
    connection = Connection()
    session = module.SqlSession(connection)
    assert session.request('missing') is None and session.manifest('missing') is None
    connection.saved = True
    assert session.request('id')['result'] == {'status': 'aplicada'}
    assert session.manifest('op') == {'product': 'PA1'}
    session.save_request('id', 'hash', {'status': 'aplicada'})
    assert connection.calls[-1][1][:2] == ('id', 'hash')
    connection.rowcount = 0
    session.save_manifest('op', {'product': 'PA1'})
    assert connection.calls[-1][0].startswith('INSERT INTO dbo.VF_SQL_ORDERS')
    connection.rowcount = 1
    session.save_manifest('op', {'product': 'PA2'})
    assert connection.calls[-1][0].startswith('UPDATE dbo.VF_SQL_ORDERS')


def test_result_lookup_verifies_actual_database(module, monkeypatch):
    connection = Connection()
    connection.saved = True
    @contextmanager
    def connect():
        yield connection
    monkeypatch.setattr(module.mssql, 'conexao', connect)
    assert module.SqlDatabase().result('id')['result']['status'] == 'aplicada'
    connection.database = 'other'
    with pytest.raises(ValueError):
        module.SqlDatabase().result('id')


def test_insert_controls_deleted_fields_encoding_and_recno_exhaustion(module):
    session = module.SqlSession(Connection())
    session.prepare()
    inserted = session.insert('SC2', {})
    assert inserted == {'R_E_C_N_O_': 11, 'D_E_L_E_T_': '', 'R_E_C_D_E_L_': 0}
    with pytest.raises(ValueError):
        session.insert('SB1', {})
    with pytest.raises(ValueError):
        session.table('arbitrary;')
    with pytest.raises(ValueError, match='Texto'):
        session.checked('SC2', {'D_E_L_E_T_': '😀'})
    session.recnos['SC2'] = 2147483647
    with pytest.raises(ValueError, match='RECNO'):
        session.insert('SC2', {})
