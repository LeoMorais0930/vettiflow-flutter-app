"""Fluxo SQL delimitado do DEV: quantidades e custos correntes, sem rotina ADVPL.

Somente OPs criadas por este módulo podem ser alteradas/apontadas. O banco
implementa a transação e o diário junto aos registros ERP, nunca em SQLite.
"""
from __future__ import annotations

from datetime import date
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import json
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

SCALE = Decimal('0.000001')
ZERO = Decimal(0)
MAX_QTY = Decimal('999999999.999999')


def amount(value) -> Decimal:
    number = Decimal(str(value or 0))
    if not number.is_finite():
        raise ValueError('Quantidade ou custo inválido.')
    return number.quantize(SCALE, rounding=ROUND_HALF_UP)


def positive(value) -> Decimal:
    raw = Decimal(str(value))
    if not raw.is_finite() or raw <= 0 or raw > MAX_QTY or raw != amount(raw):
        raise ValueError('Quantidade deve ser positiva, com no máximo seis casas decimais.')
    return amount(raw)


def text(row, key):
    return str(row.get(key) or '').strip()


class Command(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    id: str = Field(min_length=1, max_length=100, pattern=r'^[A-Za-z0-9._:-]+$')
    operacao: Literal['abrir', 'alterar', 'transferir', 'apontar']
    autor: str = Field(min_length=1, max_length=25)
    data: date
    entrega: date | None = None
    produto: str = Field(default='', max_length=30)
    quantidade: Decimal = Decimal(1)
    op: str = Field(default='', max_length=14)
    novaQuantidade: Decimal | None = None
    quantidadeApontada: Decimal | None = None
    produtoTransferido: str = Field(default='', max_length=30)
    quantidadeTransferida: Decimal | None = None
    origem: Literal['01', '05', '07', '10'] = '01'
    destino: Literal['01', '05', '07', '10'] = '05'
    gerarIntermediarias: bool = False
    simular: bool = False

    @model_validator(mode='after')
    def validate_operation(self):
        positive(self.quantidade)
        for field in ('novaQuantidade', 'quantidadeApontada', 'quantidadeTransferida'):
            if getattr(self, field) is not None:
                positive(getattr(self, field))
        if self.operacao == 'abrir' and (not self.produto or not self.entrega):
            raise ValueError('Informe produto e entrega para abrir a OP.')
        if self.entrega and self.entrega < self.data:
            raise ValueError('Entrega anterior à emissão.')
        if self.operacao in ('alterar', 'apontar') and not self.op:
            raise ValueError('Informe a referência completa da OP.')
        if self.operacao == 'alterar' and self.novaQuantidade is None:
            raise ValueError('Informe a nova quantidade.')
        if self.operacao == 'apontar' and self.quantidadeApontada is None:
            raise ValueError('Informe a quantidade apontada.')
        if self.operacao == 'apontar' and self.destino not in ('05', '07', '10'):
            raise ValueError('Destino da produção deve ser 05, 07 ou 10.')
        if self.operacao == 'transferir':
            if not self.produtoTransferido or self.quantidadeTransferida is None:
                raise ValueError('Informe produto e quantidade para transferir.')
            if self.origem == self.destino:
                raise ValueError('Origem e destino devem ser diferentes.')
        return self


class StaleDateError(ValueError):
    pass


def execute(database, command: Command, today: date | None = None) -> dict:
    payload = command.model_dump(mode='json', exclude={'simular'})
    fingerprint = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
    with database.transaction(preview=command.simular) as session:
        previous = session.request(command.id)
        if previous:
            if previous['fingerprint'] != fingerprint:
                raise ValueError('Este identificador já foi usado com outros dados.')
            return previous['result']
        if today is not None and command.data != today:
            raise StaleDateError('Este fluxo registra somente operações com a data de hoje.')
        flow = Production(session, command)
        getattr(flow, command.operacao)()
        result = flow.result
        result['status'] = 'previa' if command.simular else 'aplicada'
        if not command.simular:
            session.save_request(command.id, fingerprint, result)
    # Commit must complete before any success is returned.
    return result


class Production:
    def __init__(self, session, command):
        self.db, self.cmd = session, command
        self.day = command.data.strftime('%Y%m%d')
        self.result = dict(id=command.id, operacao=command.operacao, autor=command.autor,
                           database='HMLp12', filial='04', protheusRef=command.op or None,
                           ordens=[], empenhos=[], movimentos=[])

    def one(self, table, **filters):
        rows = self.db.rows(table, **filters)
        if len(rows) != 1:
            raise ValueError(f'{table}: cadastro ausente ou duplicado para a operação.')
        return rows[0]

    def branch_rows(self, table, field, **filters):
        rows = self.db.rows(table, **filters)
        branch = [r for r in rows if text(r, field) == '04']
        return branch or [r for r in rows if not text(r, field)]

    def product(self, code):
        rows = self.branch_rows('SB1', 'B1_FILIAL', B1_COD=code)
        if len(rows) != 1:
            raise ValueError(f'Produto {code}: cadastro ausente ou duplicado.')
        row = rows[0]
        if text(row, 'B1_MSBLQL') == '1':
            raise ValueError(f'Produto {code} bloqueado.')
        if (text(row, 'B1_RASTRO') not in ('', 'N')
                or text(row, 'B1_LOCALIZ') not in ('', 'N') or text(row, 'B1_SEGUM')):
            raise ValueError(f'Produto {code} exige rastreabilidade ou segunda unidade não suportada neste fluxo.')
        if text(row, 'B1_TIPO') in ('MO', 'SV') or not text(row, 'B1_UM'):
            raise ValueError(f'Produto {code}: mão de obra/serviço ou unidade não suportada.')
        return row

    def warehouse(self, local):
        rows = self.branch_rows('NNR', 'NNR_FILIAL', NNR_CODIGO=local)
        if len(rows) != 1:
            raise ValueError(f'Armazém {local} ausente ou duplicado.')

    def balance(self, code, local):
        self.warehouse(local)
        rows = self.db.rows('SB2', B2_FILIAL='04', B2_COD=code, B2_LOCAL=local)
        if len(rows) > 1:
            raise ValueError(f'Saldo duplicado: {code}/{local}.')
        if rows:
            row = rows[0]
            if text(row, 'B2_BLOQUEI') == '1':
                raise ValueError(f'Saldo bloqueado: {code}/{local}.')
            if text(row, 'B2_DINVENT') > self.day or text(row, 'B2_DTINV') > self.day:
                raise ValueError('Movimento anterior ao inventário do armazém.')
            return row
        return self.db.insert('SB2', dict(B2_FILIAL='04', B2_COD=code, B2_LOCAL=local,
                                         B2_QATU=ZERO, B2_QEMP=ZERO,
                                         **{f'B2_CM{i}': ZERO for i in range(1, 6)},
                                         **{f'B2_VATU{i}': ZERO for i in range(1, 6)}))

    def structure(self, code):
        rows = self.branch_rows('SG1', 'G1_FILIAL', G1_COD=code)
        items = []
        for row in rows:
            if text(row, 'G1_INI') > self.day or (text(row, 'G1_FIM') and text(row, 'G1_FIM') < self.day):
                continue
            if (amount(row.get('G1_PERDA')) != ZERO
                    or any(text(row, k) for k in ('G1_GROPC', 'G1_OPC', 'G1_REVINI', 'G1_LISTA'))
                    or text(row, 'G1_REVFIM') not in ('', 'ZZZ')
                    or text(row, 'G1_FANTASM') not in ('', 'N', '2')
                    or text(row, 'G1_FIXVAR') not in ('', 'F', 'V')):
                raise ValueError(f'Estrutura de {code} exige revisão/opcionais/perda/fantasma ainda não mapeados.')
            component = text(row, 'G1_COMP')
            if component == code:
                raise ValueError('A estrutura contém um ciclo de produtos.')
            self.product(component)
            items.append(dict(code=component, rate=str(positive(row['G1_QUANT'])),
                              fixed=text(row, 'G1_FIXVAR') == 'F', trt=text(row, 'G1_TRT')))
        return items

    def add_commitment(self, reference, product, quantity, item):
        required = amount(Decimal(item['rate']) * (1 if item['fixed'] else quantity))
        if required <= ZERO or required > MAX_QTY:
            raise ValueError('Quantidade calculada de componente fora do limite.')
        balance = self.balance(item['code'], '05')
        row = self.db.insert('SD4', dict(D4_FILIAL='04', D4_COD=item['code'], D4_LOCAL='05',
                                        D4_OP=reference, D4_DATA=self.day, D4_QTDEORI=required,
                                        D4_QUANT=required, D4_TRT=item['trt'], D4_PRODUTO=product))
        self.db.update('SB2', balance['R_E_C_N_O_'], {'B2_QEMP': amount(balance.get('B2_QEMP')) + required})
        self.result['empenhos'].append(dict(op=reference, produto=item['code'], local='05', quantidade=str(required)))
        return {**item, 'recno': row['R_E_C_N_O_'], 'original': str(required), 'remaining': str(required)}

    def abrir(self):
        self.warehouse('05')
        number = self.db.number('order')
        sequence = 0

        def create(code, quantity, parent='', ancestors=()):
            nonlocal sequence
            if code in ancestors:
                raise ValueError('A estrutura contém um ciclo de produtos.')
            if len(ancestors) >= 10 or sequence >= 100:
                raise ValueError('Estrutura excede dez níveis ou cem OPs por solicitação.')
            sequence += 1
            seq = str(sequence).zfill(3)
            ref = number + '01' + seq
            product = self.product(code)
            items = self.structure(code)
            if not items:
                raise ValueError(f'Produto {code} sem estrutura vigente; não será criada OP sem empenhos.')
            self.db.insert('SC2', dict(C2_FILIAL='04', C2_NUM=number, C2_ITEM='01', C2_SEQUEN=seq,
                                      C2_SEQPAI=parent, C2_PRODUTO=code, C2_LOCAL='05', C2_QUANT=quantity,
                                      C2_UM=text(product, 'B1_UM'), C2_EMISSAO=self.day,
                                      C2_DATPRI=self.day, C2_DATPRF=self.cmd.entrega.strftime('%Y%m%d'),
                                      C2_QUJE=ZERO, C2_DATRF='', C2_STATUS='N', C2_TPOP='F', C2_BATCH='S',
                                      C2_VOP=ref, C2_VGRU=text(product, 'B1_GRUPO'),
                                      C2_OBS='VettiFlow SQL DEV ' + self.cmd.id))
            manifest = dict(product=code, quantity=str(quantity), produced='0', lastDate=self.day,
                            parent=parent, children=[], items=[])
            manifest['items'] = [self.add_commitment(ref, code, quantity, item) for item in items]
            self.result['ordens'].append(dict(op=ref, produto=code, quantidade=str(quantity), pai=parent))
            if self.cmd.gerarIntermediarias:
                for item in manifest['items']:
                    if self.structure(item['code']):
                        manifest['children'].append(create(item['code'], Decimal(item['original']), seq, (*ancestors, code)))
            self.db.save_manifest(ref, manifest)
            return ref

        self.result['protheusRef'] = create(self.cmd.produto, positive(self.cmd.quantidade))

    def owned_order(self):
        manifest = self.db.manifest(self.cmd.op)
        if not manifest:
            raise ValueError('Esta OP não foi criada pelo fluxo SQL do VettiFlow.')
        if self.day < manifest['lastDate']:
            raise ValueError('Data anterior ao último evento desta OP.')
        ref = self.cmd.op
        op = self.one('SC2', C2_FILIAL='04', C2_NUM=ref[:6], C2_ITEM=ref[6:8], C2_SEQUEN=ref[8:11])
        if (amount(op.get('C2_QUJE')) != amount(manifest['produced'])
                or amount(op.get('C2_QUANT')) != amount(manifest['quantity'])
                or text(op, 'C2_PRODUTO') != manifest['product'] or text(op, 'C2_LOCAL') != '05'
                or text(op, 'C2_ITEMGRD')):
            raise ValueError('A OP foi alterada fora do VettiFlow; concilie antes de continuar.')
        if text(op, 'C2_DATRF'):
            raise ValueError('OP encerrada.')
        actual = self.db.rows('SD4', D4_FILIAL='04', D4_OP=ref)
        if len(actual) != len(manifest['items']):
            raise ValueError('Empenhos da OP foram alterados fora do VettiFlow.')
        for item in manifest['items']:
            row = next((r for r in actual if r['R_E_C_N_O_'] == item['recno']), None)
            if (not row or text(row, 'D4_COD') != item['code'] or text(row, 'D4_LOCAL') != '05'
                    or amount(row.get('D4_QUANT')) != amount(item['remaining'])
                    or amount(row.get('D4_QTDEORI')) != amount(item['original'])
                    or any(text(row, k) for k in ('D4_LOTECTL', 'D4_NUMLOTE'))):
                raise ValueError('Empenhos da OP foram alterados fora do VettiFlow.')
        return op, manifest

    def alterar(self):
        op, manifest = self.owned_order()
        if amount(manifest['produced']) > ZERO:
            raise ValueError('Alteração de quantidade após apontamento não é suportada.')
        if manifest['children'] or manifest['parent']:
            raise ValueError('Alteração de OP com intermediárias exige replanejamento do conjunto.')
        quantity = positive(self.cmd.novaQuantidade)
        for item in manifest['items']:
            required = amount(Decimal(item['rate']) * (1 if item['fixed'] else quantity))
            if required <= ZERO or required > MAX_QTY:
                raise ValueError('Quantidade calculada de componente fora do limite.')
            balance = self.balance(item['code'], '05')
            committed = amount(balance.get('B2_QEMP')) + required - Decimal(item['remaining'])
            if committed < ZERO:
                raise ValueError('Empenho agregado inconsistente no estoque.')
            self.db.update('SB2', balance['R_E_C_N_O_'], {'B2_QEMP': committed})
            self.db.update('SD4', item['recno'], {'D4_QUANT': required, 'D4_QTDEORI': required})
            item.update(original=str(required), remaining=str(required))
            self.result['empenhos'].append(dict(op=self.cmd.op, produto=item['code'], local='05', quantidade=str(required)))
        values = {'C2_QUANT': quantity}
        if self.cmd.entrega:
            values['C2_DATPRF'] = self.cmd.entrega.strftime('%Y%m%d')
        self.db.update('SC2', op['R_E_C_N_O_'], values)
        manifest.update(quantity=str(quantity), lastDate=self.day)
        self.db.save_manifest(self.cmd.op, manifest)
        self.result['ordens'].append(dict(op=self.cmd.op, quantidade=str(quantity)))

    def move_stock(self, product, local, quantity, costs, commitment=ZERO):
        code = text(product, 'B1_COD')
        row = self.balance(code, local)
        old = amount(row.get('B2_QATU'))
        committed = amount(row.get('B2_QEMP'))
        if commitment > committed:
            raise ValueError('Empenho agregado insuficiente no estoque.')
        reserved = amount(row.get('B2_RESERVA')) + amount(row.get('B2_QACLASS'))
        if quantity < ZERO and old - committed - reserved + commitment < -quantity:
            raise ValueError(f'Saldo disponível insuficiente para {code} no {local}.')
        new = amount(old + quantity)
        if new < ZERO:
            raise ValueError('Saldo físico não pode ficar negativo.')
        values = {'B2_QATU': new, 'B2_QEMP': committed - commitment}
        for i in range(1, 6):
            value = amount(row.get(f'B2_VATU{i}')) + costs[i-1]
            if value < -SCALE:
                raise ValueError(f'Custo de estoque inconsistente para {code}/{local}.')
            # Preserve average on empty balance; a new receipt will recompute it.
            values[f'B2_VATU{i}'] = max(ZERO, amount(value))
            if new > ZERO:
                values[f'B2_CM{i}'] = amount(value / new)
        if quantity < ZERO:
            values['B2_USAI'] = self.day
        self.db.update('SB2', row['R_E_C_N_O_'], values)

    def costs(self, code, local, quantity):
        balance = self.balance(code, local)
        if quantity == amount(balance.get('B2_QATU')):
            # Consume the entire carried value on the last issue, including
            # the residual from rounding average unit costs.
            values = [amount(balance.get(f'B2_VATU{i}')) for i in range(1, 6)]
            if any(v < ZERO for v in values):
                raise ValueError('Valor de estoque negativo não suportado.')
            return values
        values = [amount(balance.get(f'B2_CM{i}')) for i in range(1, 6)]
        if any(v < ZERO for v in values):
            raise ValueError('Custo médio negativo não suportado.')
        return [amount(v * quantity) for v in values]

    def movement(self, product, local, quantity, cf, tm, sequence, costs, op='', total=False, trt=''):
        values = dict(D3_FILIAL='04', D3_COD=text(product, 'B1_COD'), D3_UM=text(product, 'B1_UM'),
                      D3_TIPO=text(product, 'B1_TIPO'), D3_GRUPO=text(product, 'B1_GRUPO'),
                      D3_QUANT=quantity, D3_LOCAL=local, D3_CF=cf, D3_TM=tm,
                      D3_OP=op, D3_DOC='VF'+sequence, D3_NUMSEQ=sequence,
                      D3_EMISSAO=self.day, D3_DTLANC=self.day, D3_USUARIO=self.cmd.autor,
                      D3_IDENT=sequence, D3_TRT=trt, D3_ESTORNO='',
                      D3_PARCTOT=('T' if total else 'P') if cf == 'PR0' else '',
                      **{f'D3_CUSTO{i}': cost for i, cost in enumerate(costs, 1)})
        self.db.insert('SD3', values)
        self.result['movimentos'].append(dict(produto=values['D3_COD'], local=local,
                                             quantidade=str(quantity), cf=cf, tm=tm,
                                             sequencia=sequence, op=op,
                                             custos=[str(v) for v in costs]))

    def transferir(self):
        product = self.product(self.cmd.produtoTransferido)
        quantity = positive(self.cmd.quantidadeTransferida)
        costs = self.costs(self.cmd.produtoTransferido, self.cmd.origem, quantity)
        sequence = self.db.number('movement')
        self.move_stock(product, self.cmd.origem, -quantity, [-v for v in costs])
        self.move_stock(product, self.cmd.destino, quantity, costs)
        self.movement(product, self.cmd.origem, quantity, 'RE4', '999', sequence, costs)
        self.movement(product, self.cmd.destino, quantity, 'DE4', '499', sequence, costs)

    def apontar(self):
        op, manifest = self.owned_order()
        product = self.product(manifest['product'])
        quantity = positive(self.cmd.quantidadeApontada)
        planned, produced = amount(manifest['quantity']), amount(manifest['produced'])
        if quantity > planned - produced:
            raise ValueError('Quantidade superior ao saldo a produzir.')
        total = produced + quantity == planned
        sequence = self.db.number('movement')
        total_cost = [ZERO] * 5
        for item in manifest['items']:
            original, remaining = amount(item['original']), amount(item['remaining'])
            # Cumulative target prevents residual components across partial postings.
            consume = remaining if total else amount(original * (produced + quantity) / planned) - (original - remaining)
            if consume <= ZERO:
                continue
            component = self.product(item['code'])
            costs = self.costs(item['code'], '05', consume)
            self.move_stock(component, '05', -consume, [-v for v in costs], commitment=consume)
            self.db.update('SD4', item['recno'], {'D4_QUANT': remaining-consume})
            item['remaining'] = str(remaining-consume)
            self.movement(component, '05', consume, 'RE1', '999', sequence, costs, self.cmd.op, trt=item['trt'])
            total_cost = [a+b for a, b in zip(total_cost, costs)]
        self.move_stock(product, self.cmd.destino, quantity, total_cost)
        self.movement(product, self.cmd.destino, quantity, 'PR0', '001', sequence, total_cost, self.cmd.op, total)
        values = dict(C2_QUJE=produced+quantity, C2_DATRF=self.day if total else '',
                      **{f'C2_APRATU{i}': amount(op.get(f'C2_APRATU{i}')) + cost
                         for i, cost in enumerate(total_cost, 1)})
        self.db.update('SC2', op['R_E_C_N_O_'], values)
        manifest.update(produced=str(produced+quantity), lastDate=self.day)
        self.db.save_manifest(self.cmd.op, manifest)
        self.result['ordens'].append(dict(op=self.cmd.op, produzida=str(produced+quantity), encerrada=total))
