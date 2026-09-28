"""Contratos do fluxo SQL, com armazenamento transacional isolado."""
from copy import deepcopy
from contextlib import contextmanager
from decimal import Decimal
import importlib

import pytest


class MemoryDatabase:
    def __init__(self):
        self.tables = {name: [] for name in ('SB1', 'SG1', 'SC2', 'SD4', 'SB2', 'SD3', 'NNR')}
        self.journal = {}
        self.orders = {}
        self.numbers = {'order': 0, 'movement': 0}
        self.identity = 'HMLp12'
        self.fail_table = None
        self.fail_commit = False

    @contextmanager
    def transaction(self, preview=False):
        snapshot = deepcopy((self.tables, self.journal, self.orders, self.numbers))
        try:
            if self.identity != 'HMLp12':
                raise ValueError('Base diferente do DEV')
            yield self
            if self.fail_commit:
                raise RuntimeError('commit failed')
        except BaseException:
            self.tables, self.journal, self.orders, self.numbers = snapshot
            raise
        else:
            if preview:
                self.tables, self.journal, self.orders, self.numbers = snapshot

    def rows(self, table, **filters):
        return [deepcopy(r) for r in self.tables[table]
                if not r.get('D_E_L_E_T_', '').strip()
                and all(str(r.get(k, '')).strip() == str(v).strip() for k, v in filters.items())]

    def insert(self, table, values):
        if self.fail_table == table:
            raise RuntimeError('injected write failure')
        recno = max([r.get('R_E_C_N_O_', 0) for r in self.tables[table]], default=0) + 1
        row = {'D_E_L_E_T_': '', 'R_E_C_D_E_L_': 0, **deepcopy(values), 'R_E_C_N_O_': recno}
        self.tables[table].append(row)
        return deepcopy(row)

    def update(self, table, recno, values):
        if self.fail_table == table:
            raise RuntimeError('injected write failure')
        row = next(r for r in self.tables[table] if r['R_E_C_N_O_'] == recno)
        row.update(deepcopy(values))

    def number(self, kind):
        self.numbers[kind] += 1
        return ('V' if kind == 'order' else 'X') + str(self.numbers[kind]).zfill(5)

    def request(self, key):
        return deepcopy(self.journal.get(key))

    def result(self, key):
        return self.request(key)

    def save_request(self, key, fingerprint, result):
        self.journal[key] = {'fingerprint': fingerprint, 'result': deepcopy(result)}

    def manifest(self, reference):
        return deepcopy(self.orders.get(reference))

    def save_manifest(self, reference, manifest):
        self.orders[reference] = deepcopy(manifest)


@pytest.fixture
def db():
    db = MemoryDatabase()
    for code, kind in [('PA1', 'PA'), ('MP1', 'MP'), ('PI1', 'PI')]:
        db.insert('SB1', dict(B1_FILIAL='04', B1_COD=code, B1_DESC=code,
                             B1_UM='UN', B1_TIPO=kind, B1_GRUPO='001', B1_MSBLQL='2',
                             B1_RASTRO='N', B1_LOCALIZ='N', B1_SEGUM=''))
    db.insert('SG1', dict(G1_FILIAL='04', G1_COD='PA1', G1_COMP='MP1',
                         G1_QUANT=2, G1_FIXVAR='V', G1_PERDA=0, G1_TRT='001',
                         G1_REVINI='', G1_REVFIM='ZZZ'))
    for local in ('01', '05', '07', '10'):
        db.insert('NNR', dict(NNR_FILIAL='04', NNR_CODIGO=local))
        for code in ('PA1', 'MP1', 'PI1'):
            qty = 100 if code == 'MP1' else 0
            db.insert('SB2', dict(B2_FILIAL='04', B2_COD=code, B2_LOCAL=local,
                                 B2_QATU=qty, B2_QEMP=0, B2_RESERVA=0, B2_QACLASS=0,
                                 **{f'B2_CM{i}': 3 if code == 'MP1' else 0 for i in range(1, 6)},
                                 **{f'B2_VATU{i}': qty*3 for i in range(1, 6)}))
    return db


def run(db, operation='abrir', key='open-1', **values):
    module = importlib.import_module('app.sql_production')
    body = dict(id=key, operacao=operation, autor='Tatiane', data='2026-09-28',
                produto='PA1', quantidade='10', entrega='2026-10-10', **values)
    return module.execute(db, module.Command.model_validate(body))


def balance(db, product='MP1', local='05'):
    return db.rows('SB2', B2_COD=product, B2_LOCAL=local)[0]


def test_open_commits_order_and_commitments_without_physical_movement(db):
    result = run(db)
    assert result['status'] == 'aplicada'
    op = db.rows('SC2')[0]
    assert op['C2_LOCAL'] == '05' and op['C2_QUANT'] == 10
    assert op['C2_VOP'] == result['protheusRef'] and op['C2_VGRU'] == '001'
    assert db.rows('SD4')[0]['D4_QUANT'] == 20
    assert db.rows('SD4')[0]['D4_QTDEORI'] == 20
    assert balance(db)['B2_QEMP'] == 20
    assert balance(db)['B2_QATU'] == 100 and not db.rows('SD3')


def test_same_request_replays_and_changed_payload_conflicts(db):
    first = run(db)
    assert run(db) == first
    with pytest.raises(ValueError, match='outros dados'):
        run(db, destino='10')
    assert len(db.rows('SC2')) == 1


@pytest.mark.parametrize('fail_table', ['SC2', 'SD4', 'SB2'])
def test_open_rolls_back_every_write_on_error(db, fail_table):
    before = deepcopy(db.tables)
    db.fail_table = fail_table
    with pytest.raises(RuntimeError):
        run(db)
    assert db.tables == before and not db.journal


def test_preview_returns_plan_but_persists_nothing(db):
    before = deepcopy(db.tables)
    result = run(db, simular=True)
    assert result['status'] == 'previa'
    assert result['movimentos'] == []
    assert result['empenhos'][0]['quantidade'] == '20.000000'
    assert db.tables == before and not db.journal


def test_partial_and_final_pointing_consume_proportionally_and_close(db):
    ref = run(db)['protheusRef']
    run(db, 'apontar', 'point-1', op=ref, quantidadeApontada='4', destino='10')
    assert balance(db)['B2_QATU'] == 92 and balance(db)['B2_QEMP'] == 12
    assert balance(db, 'PA1', '10')['B2_QATU'] == 4
    assert balance(db, 'PA1', '10')['B2_VATU1'] == 24
    assert db.rows('SC2')[0]['C2_QUJE'] == 4
    assert not db.rows('SC2')[0]['C2_DATRF']
    run(db, 'apontar', 'point-2', op=ref, quantidadeApontada='6', destino='10')
    assert db.rows('SC2')[0]['C2_QUJE'] == 10
    assert db.rows('SC2')[0]['C2_DATRF'] == '20260928'
    assert db.rows('SD4')[0]['D4_QUANT'] == 0 and balance(db)['B2_QEMP'] == 0
    assert [m['D3_CF'] for m in db.rows('SD3')] == ['RE1','PR0','RE1','PR0']
    with pytest.raises(ValueError):
        run(db, 'apontar', 'point-3', op=ref, quantidadeApontada='1', destino='10')


def test_transfer_updates_both_stocks_and_cost_without_production(db):
    run(db, 'transferir', 'transfer-1', produtoTransferido='MP1', quantidadeTransferida='5', origem='01', destino='05')
    assert balance(db, local='01')['B2_QATU'] == 95
    assert balance(db)['B2_QATU'] == 105
    assert balance(db)['B2_VATU1'] == 315
    movements = db.rows('SD3')
    assert [m['D3_CF'] for m in movements] == ['RE4', 'DE4']
    assert movements[0]['D3_NUMSEQ'] == movements[1]['D3_NUMSEQ']
    assert not db.rows('SC2')


def test_transfer_respects_stock_committed_to_other_orders(db):
    row = balance(db, local='01')
    db.update('SB2', row['R_E_C_N_O_'], {'B2_QEMP': 99})
    with pytest.raises(ValueError, match='Saldo'):
        run(db, 'transferir', 't', produtoTransferido='MP1', quantidadeTransferida='5', origem='01', destino='05')
    assert not db.rows('SD3')


def test_pointing_insufficient_stock_is_atomic(db):
    ref = run(db)['protheusRef']
    row = balance(db)
    db.update('SB2', row['R_E_C_N_O_'], {'B2_QATU': 1})
    before = deepcopy(db.tables)
    with pytest.raises(ValueError, match='Saldo'):
        run(db, 'apontar', 'p', op=ref, quantidadeApontada='10', destino='10')
    assert db.tables == before


def test_update_before_pointing_rebalances_commitments(db):
    ref = run(db)['protheusRef']
    run(db, 'alterar', 'update', op=ref, novaQuantidade='15')
    assert db.rows('SC2')[0]['C2_QUANT'] == 15
    assert db.rows('SD4')[0]['D4_QUANT'] == 30
    assert balance(db)['B2_QEMP'] == 30
    run(db, 'apontar', 'p', op=ref, quantidadeApontada='1', destino='05')
    with pytest.raises(ValueError, match='apontamento'):
        run(db, 'alterar', 'u2', op=ref, novaQuantidade='12')


def test_rejects_unowned_order_lot_tracking_and_cycles(db):
    with pytest.raises(ValueError, match='VettiFlow'):
        run(db, 'apontar', 'p', op='01643101001', quantidadeApontada='1')
    db.tables['SB1'][0]['B1_RASTRO'] = 'L'
    with pytest.raises(ValueError, match='rastreabilidade'):
        run(db)
    db.tables['SB1'][0]['B1_RASTRO'] = 'N'
    db.insert('SG1', dict(G1_FILIAL='04', G1_COD='MP1', G1_COMP='PA1', G1_QUANT=1))
    with pytest.raises(ValueError, match='ciclo'):
        run(db, gerarIntermediarias=True)
    assert not db.rows('SC2')


def test_intermediate_orders_keep_parent_sequence_and_own_commitments(db):
    db.tables['SG1'][0]['G1_COMP'] = 'PI1'
    db.insert('SG1', dict(G1_FILIAL='04', G1_COD='PI1', G1_COMP='MP1', G1_QUANT=3))
    result = run(db, gerarIntermediarias=True)
    assert len(db.rows('SC2')) == 2
    parent, child = db.rows('SC2')
    assert child['C2_SEQPAI'] == parent['C2_SEQUEN']
    assert child['C2_QUANT'] == 20
    assert balance(db)['B2_QEMP'] == 60
    assert len(result['ordens']) == 2


def test_commit_failure_never_returns_success(db):
    db.fail_commit = True
    with pytest.raises(RuntimeError):
        run(db)
    assert not db.rows('SC2') and not db.journal


@pytest.mark.parametrize('value', ['0', '-1', 'NaN', 'Infinity', '0.0000001'])
def test_rejects_invalid_quantities(db, value):
    with pytest.raises(ValueError):
        run(db, 'transferir', 't', produtoTransferido='MP1', quantidadeTransferida=value, origem='01', destino='05')


def test_wrong_database_never_writes(db):
    db.identity = 'VettiP12'
    with pytest.raises(ValueError):
        run(db)
    assert not db.rows('SC2')


def test_last_stock_issue_transfers_exact_remaining_value(db):
    row = next(r for r in db.tables['SB2'] if r['B2_COD'] == 'MP1' and r['B2_LOCAL'] == '01')
    row.update(B2_QATU=3, B2_CM1=Decimal('0.333333'), B2_VATU1=1)
    run(db, 'transferir', 'last', produtoTransferido='MP1', quantidadeTransferida=3, origem='01', destino='05')
    assert balance(db, local='01')['B2_VATU1'] == 0
    assert balance(db)['B2_VATU1'] == 301


def test_self_component_is_rejected_without_intermediate_expansion(db):
    db.tables['SG1'][0]['G1_COMP'] = 'PA1'
    with pytest.raises(ValueError, match='ciclo'):
        run(db)
    assert not db.rows('SC2')
