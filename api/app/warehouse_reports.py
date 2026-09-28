"""Bounded, read-only movement reports using the same scope as each sector."""

from datetime import date, datetime, timezone
from threading import BoundedSemaphore
from time import monotonic
from typing import Annotated, Literal
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field, model_validator

from . import config, mssql
from .warehouse import _history, database_coverage

router = APIRouter()
_slots = BoundedSemaphore(2)
DETAIL_LIMIT = 1000
GROUP_LIMIT = 100
SERIES_LIMIT = 120
Kind = Literal['transfer', 'production', 'consumption', 'adjustment',
               'dismantling', 'receipt', 'dispatch', 'other']
Sector = Literal['almoxarifado', 'smd', 'producao', 'suporte', 'expedicao', 'gestao']
Warehouse = Literal['01', '03', '05', '06', '07', '10']
Analysis = Literal['movements', 'output', 'orders', 'evolution', 'destinations', 'consumption', 'reversals']
OUTPUT_ANALYSES = ('output', 'orders', 'evolution', 'destinations')
SCOPES = {
    'almoxarifado': ('Almoxarifado', ['01']),
    'smd': ('SMD', ['03']),
    'producao': ('Produção', ['05']),
    'suporte': ('Suporte', ['06', '07']),
    'expedicao': ('Expedição', ['10']),
    'gestao': ('Gestão', ['01', '03', '05', '06', '07', '10']),
}


class ReportFilters(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    start: date | None = None
    end: date | None = None
    query: str = Field(default='', max_length=100)
    kinds: list[Kind] = Field(default_factory=list, max_length=8)
    product: str = Field(default='', max_length=40)
    op: str = Field(default='', max_length=30)
    operator: str = Field(default='', max_length=50)
    document: str = Field(default='', max_length=30)
    unit: str = Field(default='', max_length=10)
    cf: str = Field(default='', max_length=10)
    tm: str = Field(default='', max_length=10)
    tes: str = Field(default='', max_length=10)
    cfop: str = Field(default='', max_length=10)
    source: Literal['all', 'SD3', 'SD1', 'SD2'] = 'all'
    flow: Literal['all', 'in', 'out', 'none', 'unknown'] = 'all'
    status: Literal['all', 'active', 'reversed'] = 'all'
    details: bool = False
    warehouses: list[Warehouse] = Field(default_factory=list, max_length=6)
    analysis: Analysis = 'movements'

    @model_validator(mode='after')
    def validate_period(self):
        if bool(self.start) != bool(self.end) or (self.start and self.start > self.end):
            raise ValueError('Informe o início e o fim em ordem válida, ou todo o período.')
        self.kinds = sorted(set(self.kinds))
        self.warehouses = sorted(set(self.warehouses))
        return self


@router.get('/api/v1/relatorios/almoxarifado')
def report_endpoint(filters: Annotated[ReportFilters, Query()]):
    return _serve(filters, 'almoxarifado')


@router.get('/api/v1/relatorios/{sector}')
def sector_report_endpoint(sector: Sector, filters: Annotated[ReportFilters, Query()]):
    return _serve(filters, sector)


def _warehouses(filters, sector):
    allowed = SCOPES[sector][1]
    if any(local not in allowed for local in filters.warehouses):
        raise HTTPException(422, 'Armazém fora do setor selecionado.')
    return filters.warehouses or allowed


def _serve(filters, sector):
    _warehouses(filters, sector)
    if sector != 'producao' and filters.analysis != 'movements':
        raise HTTPException(422, 'Esta análise está disponível no relatório da produção.')
    if not _slots.acquire(blocking=False):
        raise HTTPException(429, 'Há relatórios em consulta. Tente novamente em instantes.')
    try:
        return read_report(filters) if sector == 'almoxarifado' else read_report(filters, sector)
    except Exception:
        raise HTTPException(503, 'Não foi possível gerar o relatório. Tente um período menor.') from None
    finally:
        _slots.release()


def _filtered_query(filters, sector='almoxarifado'):
    locals_ = _warehouses(filters, sector)
    params = []
    scopes = []
    for local in locals_:
        scopes.append('''SELECT CAST(? AS varchar(8)) filial,CAST(? AS varchar(2)) local,
                        CAST(? AS varchar(8)) startDate,CAST(? AS varchar(8)) endDate''')
        params.extend([config.FILIAL_PADRAO, local,
                       filters.start.strftime('%Y%m%d') if filters.start else None,
                       filters.end.strftime('%Y%m%d') if filters.end else None])
    conditions = ['1=1']
    if filters.query:
        conditions.append("CHARINDEX(?,CONCAT(code,' ',description,' ',document,' ',op))>0")
        params.append(filters.query)
    if filters.kinds:
        conditions.append('kind IN (' + ','.join('?' for _ in filters.kinds) + ')')
        params.extend(filters.kinds)
    for field, column in [('product', 'code'), ('op', 'op'), ('operator', 'operator'),
                          ('document', 'document'), ('unit', 'unit'), ('cf', 'cf'),
                          ('tm', 'tm'), ('tes', 'tes'), ('cfop', 'cfop')]:
        value = getattr(filters, field)
        if value:
            conditions.append(f'{column}=?')
            params.append(value)
    for field in ('source', 'flow'):
        value = getattr(filters, field)
        if value != 'all':
            conditions.append(f'{field}=?')
            params.append(value)
    if filters.status != 'all':
        conditions.append('reversed=?')
        params.append(int(filters.status == 'reversed'))
    if filters.analysis == 'reversals':
        conditions.append("(cf='ER0' OR reversed=1)")
    return f"""WITH scope AS (
        {' UNION ALL '.join(scopes)}
    ), records AS ({_history(include_order_movements=sector == 'producao')}), filtered AS (
        SELECT * FROM records WHERE {' AND '.join(conditions)}
    ) """, tuple(params)


def read_report(filters: ReportFilters, sector: str = 'almoxarifado'):
    started = datetime.now(timezone.utc).isoformat()
    deadline = monotonic() + 40
    if sector == 'producao' and filters.analysis != 'movements':
        # Return the effective filters too, so preview/PDF identify exactly what was counted.
        updates = dict(source='SD3', tes='', cfop='', cf='', status='all', flow='all', kinds=[])
        if filters.analysis in OUTPUT_ANALYSES:
            updates.update(cf='PR0', status='active', flow='in', kinds=['production'])
        elif filters.analysis == 'consumption':
            updates.update(kinds=['consumption'])
        filters = filters.model_copy(update=updates)
    locals_ = _warehouses(filters, sector)
    cte, params = _filtered_query(filters, sector)
    daily = bool(filters.start and (filters.end - filters.start).days <= 62)
    period_length = 8 if daily else 6
    with mssql.conexao() as conn:
        def fetch(sql):
            remaining = int(deadline - monotonic())
            if remaining < 1:
                raise TimeoutError('Report time budget exceeded')
            if hasattr(conn, 'timeout'):
                conn.timeout = min(remaining, 20)
            return mssql._fetchall(conn, cte + sql, params)

        grouped = fetch('''/* summary */ SELECT warehouse,kind,flow,reversed,COUNT_BIG(*) count,
            MIN([date]) firstDate,MAX([date]) lastDate FROM filtered
            GROUP BY warehouse,kind,flow,reversed''')
        by_kind, by_warehouse = {}, {}
        for row in grouped:
            key = (row['kind'], row['flow'], row['reversed'])
            if key not in by_kind:
                by_kind[key] = {k: v for k, v in row.items() if k != 'warehouse'}
            else:
                aggregate = by_kind[key]
                aggregate['count'] += row['count']
                aggregate['firstDate'] = min(aggregate['firstDate'], row['firstDate'])
                aggregate['lastDate'] = max(aggregate['lastDate'], row['lastDate'])
            local = row.get('warehouse', locals_[0]).strip()
            by_warehouse[local] = by_warehouse.get(local, 0) + row['count']
        summary = list(by_kind.values())
        total = sum(row['count'] for row in summary)
        series = fetch(f'''/* series */ SELECT TOP ({SERIES_LIMIT})
            LEFT([date],{period_length}) period,COUNT_BIG(*) count,COUNT(*) OVER() groupCount
            FROM filtered GROUP BY LEFT([date],{period_length}) ORDER BY period DESC''')
        products = fetch(f'''/* products */ SELECT TOP ({GROUP_LIMIT}) code,unit,kind,flow,reversed,warehouse,
            MAX(description) description,SUM(quantity) quantity,COUNT_BIG(*) count,
            COUNT(*) OVER() groupCount FROM filtered GROUP BY code,unit,kind,flow,reversed,warehouse
            ORDER BY count DESC,code,unit,kind,flow,reversed,warehouse''')
        production = None
        if sector == 'producao' and filters.analysis in OUTPUT_ANALYSES:
            metrics = fetch('''/* production metrics */ SELECT
                COUNT(DISTINCT NULLIF(RTRIM(op),'')) orderCount,
                COUNT(DISTINCT [date]) activeDays,
                (SELECT COUNT(*) FROM (SELECT code,unit FROM filtered GROUP BY code,unit) p) productCount,
                SUM(CASE WHEN RTRIM(op)='' THEN 1 ELSE 0 END) withoutOrder
                FROM filtered''')[0]
            dimension = {'output': '', 'orders': 'op,',
                         'evolution': f'LEFT([date],{period_length}),',
                         'destinations': 'warehouse,'}[filters.analysis]
            projection = {'output': '', 'orders': 'op,',
                          'evolution': f'LEFT([date],{period_length}) period,',
                          'destinations': 'warehouse,'}[filters.analysis]
            ordering = 'period DESC,code,unit' if filters.analysis == 'evolution' else 'count DESC,code,unit' + (',op' if filters.analysis == 'orders' else ',warehouse' if filters.analysis == 'destinations' else '')
            rows = fetch(f'''/* production groups */ SELECT TOP ({GROUP_LIMIT}) {projection}
                code,unit,MAX(description) description,SUM(quantity) quantity,
                COUNT_BIG(*) count,COUNT(DISTINCT NULLIF(RTRIM(op),'')) orderCount,
                COUNT(DISTINCT [date]) activeDays,MIN([date]) firstDate,MAX([date]) lastDate,
                COUNT(*) OVER() groupCount
                FROM filtered GROUP BY {dimension}code,unit ORDER BY {ordering}''')
            production = {'metrics': metrics, 'rows': rows,
                          'groupCount': rows[0]['groupCount'] if rows else 0,
                          'groupLimit': GROUP_LIMIT, 'periodUnit': 'day' if daily else 'month'}
        items = []
        detail_status = 'not_requested'
        if filters.details:
            detail_status = 'too_large'
            if total <= DETAIL_LIMIT:
                items = fetch(f'''/* details */ SELECT TOP ({DETAIL_LIMIT + 1})
                    id,source,[date],code,description,quantity,unit,warehouse,otherWarehouse,
                    otherCode,otherQuantity,otherUnit,peerCount,document,series,op,cf,tm,tes,cfop,
                    partner,partnerStore,operator,kind,flow,reversed,affectsStock
                    FROM filtered ORDER BY [date],id''')
                detail_status = 'complete' if len(items) == total else 'changed'
                if detail_status != 'complete':
                    items = []
    # Coverage is informational; its failure must not erase a valid scoped report.
    try:
        coverage = database_coverage()
    except Exception:
        coverage = {}
    return {
        'version': 1, 'id': uuid4().hex[:12], 'readOnly': True,
        'database': config.MSSQL_DATABASE, 'company': config.EMPRESA,
        'filial': config.FILIAL_PADRAO, 'warehouse': ','.join(locals_),
        'sector': sector, 'sectorLabel': SCOPES[sector][0], 'warehouses': locals_,
        'scopeNote': ('Movimentos do 05 e movimentos internos vinculados às OPs do 05, inclusive em outros armazéns.'
                      if sector == 'producao' else
                      'Movimentos por armazém físico. Cada registro aparece uma vez no consolidado; os dois lados de uma transferência continuam sendo registros distintos.'
                      if sector == 'gestao' else
                      'Movimentos dos armazéns ' + ', '.join(locals_) + '.'),
        'warehouseSummary': [{'warehouse': local, 'count': count}
                             for local, count in sorted(by_warehouse.items())],
        'filters': filters.model_dump(mode='json'), 'total': total,
        'summary': summary, 'series': list(reversed(series)), 'seriesUnit': 'day' if daily else 'month',
        'seriesGroupCount': series[0].get('groupCount', len(series)) if series else 0,
        'products': products,
        'production': production,
        'productGroupCount': products[0].get('groupCount', len(products)) if products else 0,
        'items': items, 'detailStatus': detail_status, 'detailLimit': DETAIL_LIMIT,
        'firstRecord': min((r['firstDate'] for r in summary if r.get('firstDate')), default=''),
        'lastRecord': max((r['lastDate'] for r in summary if r.get('lastDate')), default=''),
        'databaseLatestRecord': coverage.get('latestRecord', ''),
        'startedAt': started, 'asOf': datetime.now(timezone.utc).isoformat(),
    }
