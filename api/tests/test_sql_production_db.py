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
            self.result = [(1,)]
        elif 'MAX(' in sql:
            self.description = [('last',)]
            self.result = [(10,)]
        elif 'OUTPUT INSERTED' in sql:
            self.description = [('value',)]
            self.result = [(1,)]
        return self

    def fetchone(self):
        return self.result[0] if self.result else None

    def fetchall(self):
        return self.result


class Connection:
    database = 'HMLp12'
    lock_result = 0
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
