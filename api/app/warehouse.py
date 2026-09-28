"""Consultas paginadas do almoxarifado. Exclusivamente SELECT; sem mutações."""
from datetime import date, datetime, timezone
from threading import Lock
from time import monotonic
from typing import Literal

from fastapi import APIRouter, HTTPException, Query

from . import config, mssql

router = APIRouter()
View = Literal['overview', 'history', 'stock', 'orders', 'inventory']
Kind = Literal['all', 'transfer', 'production', 'consumption', 'adjustment',
               'dismantling', 'receipt', 'dispatch', 'fiscal', 'other']
Status = Literal['all', 'active', 'closed', 'reversed', 'nonzero']

_coverage_cache = {}
_coverage_lock = Lock()


def database_coverage():
    """Datas das cinco fontes consultadas, em todos os locais/filiais da empresa.

    Cache curto evita repetir agregações de todo o histórico a cada página.
    O lock também evita consultas iguais concorrentes. Nunca retorna documentos.
    """
    key = (config.MSSQL_HOST, config.MSSQL_DATABASE, config.MSSQL_SCHEMA, config.EMPRESA)
    with _coverage_lock:
        cached = _coverage_cache.get(key)
        if cached and monotonic() - cached[0] < 60:
            return dict(cached[1])
        sources = [('SD3', 'D3_EMISSAO'), ('SD1', 'D1_DTDIGIT'),
                   ('SD2', 'D2_EMISSAO'), ('SC2', 'C2_EMISSAO'), ('SB7', 'B7_DATA')]
        parts = [f"SELECT MIN(NULLIF({field},'')) firstRecord,MAX({field}) latestRecord "
                 f"FROM {mssql.tabela(table)} WHERE D_E_L_E_T_=''" for table, field in sources]
        sql = 'WITH dates AS (' + ' UNION ALL '.join(parts) + ') SELECT MIN(firstRecord) firstRecord,MAX(latestRecord) latestRecord FROM dates'
        with mssql.conexao() as conn:
            if hasattr(conn, 'timeout'):
                conn.timeout = 30
            result = mssql._fetchall(conn, sql)[0]
        _coverage_cache.clear()
        _coverage_cache[key] = (monotonic(), result)
        return dict(result)


@router.get('/api/v1/almoxarifado/movimentos/{recno}')
def related_endpoint(recno: int, filial: str = Query(default=config.FILIAL_PADRAO, pattern=r'^\d{2}$')):
    if recno < 1:
        raise HTTPException(422, 'Registro inválido.')
    try:
        return related_movements(recno, filial)
    except Exception:
        raise HTTPException(503, 'Não foi possível consultar os movimentos relacionados.') from None


def related_movements(recno: int, filial: str):
    sd3 = mssql.tabela('SD3')
    sql = f"""WITH scope AS (
        SELECT D3_FILIAL filial,D3_DOC document,D3_NUMSEQ sequence,
               D3_EMISSAO movementDate,D3_CF cf,D3_ESTORNO reversed
        FROM {sd3} WHERE R_E_C_N_O_=? AND D3_FILIAL=? AND D_E_L_E_T_=''
    ) SELECT d.D3_COD code,product.description,d.D3_QUANT quantity,d.D3_UM unit,
        d.D3_LOCAL warehouse,d.D3_CF cf,d.D3_RATEIO allocation,d.D3_CUSTO1 cost,
        d.D3_ESTORNO reversed,d.D3_DOC document,d.D3_NUMSEQ sequence,
        d.D3_LOTECTL lot,d.D3_NUMSERI serial,d.D3_LOCALIZ address
    FROM {sd3} d CROSS JOIN scope s {_product_join('d.D3_COD')}
    WHERE d.D_E_L_E_T_='' AND d.D3_FILIAL=s.filial AND d.D3_DOC=s.document
      AND d.D3_EMISSAO=s.movementDate AND d.D3_NUMSEQ=s.sequence AND s.sequence<>''
      AND d.D3_ESTORNO=s.reversed
      AND ((s.cf IN ('RE4','DE4') AND d.D3_CF IN ('RE4','DE4'))
        OR (s.cf IN ('RE7','DE7') AND d.D3_CF IN ('RE7','DE7')))
    ORDER BY CASE WHEN d.D3_CF LIKE 'RE%' THEN 0 ELSE 1 END,d.R_E_C_N_O_"""
    with mssql.conexao() as conn:
        if hasattr(conn, 'timeout'):
            conn.timeout = 30
        items = mssql._fetchall(conn, sql, (recno, filial))
    return {'items': items, 'readOnly': True}


@router.get('/api/v1/almoxarifado')
def warehouse_endpoint(
    view: View = 'overview',
    filial: str = Query(default=config.FILIAL_PADRAO, pattern=r'^\d{2}$'),
    local: str = Query(default='01', pattern=r'^[A-Za-z0-9]{2}$'),
    start: date | None = None,
    end: date | None = None,
    query: str = Query(default='', max_length=100),
    kind: Kind = 'all', status: Status = 'all',
    page: int = Query(default=1, ge=1, le=100000),
    page_size: int = Query(default=50, ge=1, le=100),
):
    if start and end and start > end:
        raise HTTPException(422, 'A data inicial deve ser anterior à final.')
    try:
        return read_warehouse(view=view, filial=filial, local=local, start=start,
                              end=end, query=query, kind=kind, status=status,
                              page=page, page_size=page_size)
    except Exception:
        # Não devolver detalhes do driver/conexão ao navegador.
        raise HTTPException(503, 'Não foi possível consultar o almoxarifado. Tente novamente.') from None


@router.get('/api/v1/producao')
def production_endpoint(
    view: View = 'orders',
    filial: str = Query(default=config.FILIAL_PADRAO, pattern=r'^\d{2}$'),
    start: date | None = None, end: date | None = None,
    query: str = Query(default='', max_length=100),
    kind: Kind = 'all', status: Status = 'all',
    page: int = Query(default=1, ge=1, le=100000),
    page_size: int = Query(default=50, ge=1, le=100),
):
    if start and end and start > end:
        raise HTTPException(422, 'A data inicial deve ser anterior à final.')
    try:
        return read_warehouse(view=view, filial=filial, local='05', start=start,
            end=end, query=query, kind=kind, status=status, page=page,
            page_size=page_size, include_order_movements=True)
    except Exception:
        raise HTTPException(503, 'Não foi possível consultar a produção. Tente novamente.') from None


@router.get('/api/v1/suporte')
def support_endpoint(
    view: View = 'overview',
    filial: str = Query(default=config.FILIAL_PADRAO, pattern=r'^\d{2}$'),
    local: Literal['06', '07'] = '06',
    start: date | None = None, end: date | None = None,
    query: str = Query(default='', max_length=100),
    kind: Kind = 'all', status: Status = 'all',
    page: int = Query(default=1, ge=1, le=100000),
    page_size: int = Query(default=50, ge=1, le=100),
):
    if start and end and start > end:
        raise HTTPException(422, 'A data inicial deve ser anterior à final.')
    try:
        return read_warehouse(view=view, filial=filial, local=local, start=start,
            end=end, query=query, kind=kind, status=status, page=page,
            page_size=page_size)
    except Exception:
        raise HTTPException(503, 'Não foi possível consultar o suporte. Tente novamente.') from None


@router.get('/api/v1/expedicao')
def expedition_endpoint(
    view: View = 'overview',
    filial: str = Query(default=config.FILIAL_PADRAO, pattern=r'^\d{2}$'),
    start: date | None = None, end: date | None = None,
    query: str = Query(default='', max_length=100),
    kind: Kind = 'all', status: Status = 'all',
    page: int = Query(default=1, ge=1, le=100000),
    page_size: int = Query(default=50, ge=1, le=100),
):
    if start and end and start > end:
        raise HTTPException(422, 'A data inicial deve ser anterior à final.')
    try:
        return read_warehouse(view=view, filial=filial, local='10', start=start,
            end=end, query=query, kind=kind, status=status, page=page,
            page_size=page_size)
    except Exception:
        raise HTTPException(503, 'Não foi possível consultar a expedição. Tente novamente.') from None


@router.get('/api/v1/expedicao/notas/{recno}')
def dispatch_note_endpoint(recno: int,
    filial: str = Query(default=config.FILIAL_PADRAO, pattern=r'^\d{2}$')):
    if recno < 1:
        raise HTTPException(422, 'Registro inválido.')
    try:
        data = dispatch_note_details(recno, filial)
    except Exception:
        raise HTTPException(503, 'Não foi possível consultar os dados de transporte.') from None
    if data is None:
        raise HTTPException(404, 'Item da nota não encontrado na expedição.')
    return data


def dispatch_note_details(recno: int, filial: str):
    """Dados de SD2/SF2 por identidade fiscal completa. Não executa rastreio/email."""
    with mssql.conexao() as conn:
        if hasattr(conn, 'timeout'):
            conn.timeout = 30
        items = mssql._fetchall(conn, f"""SELECT D2_FILIAL filial,D2_DOC document,
            D2_SERIE series,D2_CLIENTE partner,D2_LOJA partnerStore,D2_TIPO type,
            D2_PEDIDO salesOrder,D2_ITEMPV salesOrderItem
            FROM {mssql.tabela('SD2')}
            WHERE R_E_C_N_O_=? AND D2_FILIAL=? AND D2_LOCAL='10' AND D_E_L_E_T_=''""",
            (recno, filial))
        if not items:
            return None
        item = items[0]
        headers = mssql._fetchall(conn, f"""SELECT TOP (2) F2_NOME partnerName,
            F2_TRANSP carrier,F2_DTRANSP carrierName,F2_NPVEN headerSalesOrder,
            F2_CODRAST trackingCode,F2_TRASTRE trackingType,F2_RASTREI trackingEnabled,
            F2_LOGRAST trackingLog,F2_VOLUME1 volume1,F2_VOLUME2 volume2,
            F2_VOLUME3 volume3,F2_VOLUME4 volume4,F2_ESPECI1 packaging1,
            F2_ESPECI2 packaging2,F2_ESPECI3 packaging3,F2_ESPECI4 packaging4
            FROM {mssql.tabela('SF2')} WHERE D_E_L_E_T_='' AND F2_FILIAL=?
            AND F2_DOC=? AND F2_SERIE=? AND F2_CLIENTE=? AND F2_LOJA=? AND F2_TIPO=?
            ORDER BY R_E_C_N_O_""",
            tuple(item[k] for k in ['filial', 'document', 'series', 'partner', 'partnerStore', 'type']))
    return {'readOnly': True, 'item': item,
            'document': headers[0] if len(headers) == 1 else None,
            'headerStatus': 'found' if len(headers) == 1 else 'ambiguous' if headers else 'missing'}


def _product_join(code: str) -> str:
    return f"""OUTER APPLY (
        SELECT TOP (1) prod.B1_DESC description, prod.B1_UM unit, prod.B1_TIPO materialType
        FROM {mssql.tabela('SB1')} prod
        WHERE prod.D_E_L_E_T_='' AND prod.B1_COD={code}
          AND prod.B1_FILIAL IN (s.filial,'')
        ORDER BY CASE WHEN prod.B1_FILIAL=s.filial THEN 0 ELSE 1 END,prod.R_E_C_N_O_
    ) product"""


def _history(include_order_movements=False) -> str:
    sd3 = mssql.tabela('SD3')
    location_filter = 'd.D3_LOCAL=s.local'
    if include_order_movements:
        location_filter = f"""(d.D3_LOCAL=s.local OR EXISTS (
            SELECT 1 FROM {mssql.tabela('SC2')} c
            WHERE c.D_E_L_E_T_='' AND c.C2_FILIAL=d.D3_FILIAL
              AND c.C2_LOCAL=s.local AND c.C2_NUM+c.C2_ITEM+c.C2_SEQUEN=d.D3_OP
        ))"""
    sql = f"""
        SELECT CONCAT('SD3:',d.R_E_C_N_O_) id, 'SD3' source,
            d.D3_EMISSAO [date],d.D3_COD code,product.description,
            d.D3_QUANT quantity,d.D3_UM unit,d.D3_LOCAL warehouse,
            CASE WHEN peer.peerCount=1 THEN peer.otherWarehouse ELSE '' END otherWarehouse,
            CASE WHEN peer.peerCount=1 THEN peer.otherCode ELSE '' END otherCode,
            CASE WHEN peer.peerCount=1 THEN peer.otherQuantity END otherQuantity,
            CASE WHEN peer.peerCount=1 THEN peer.otherUnit ELSE '' END otherUnit,
            peer.peerCount,d.D3_DOC document,d.D3_NUMSEQ sequence,d.D3_OP op,
            d.D3_CF cf,d.D3_TM tm,'' tes,'' cfop,'' series,
            '' partner,'' partnerStore,d.D3_MOTTRA reason,motive.Z1_DESC reasonDescription,
            d.D3_RATEIO allocation,d.D3_CUSTO1 cost,d.D3_LOTECTL lot,
            d.D3_NUMSERI serial,d.D3_LOCALIZ address,d.D3_OBSERVA observation,
            product.materialType,'S' affectsStock,
            CASE WHEN d.D3_ESTORNO='S' THEN 1 ELSE 0 END reversed,
            CASE WHEN d.D3_CF IN ('RE4','DE4') THEN 'transfer'
                 WHEN d.D3_CF IN ('PR0','ER0') THEN 'production'
                 WHEN d.D3_CF IN ('RE1','DE1') THEN 'consumption'
                 WHEN d.D3_CF IN ('RE7','DE7') THEN 'dismantling'
                 WHEN d.D3_CF IN ('RE0','DE0') THEN 'adjustment' ELSE 'other' END kind,
            CASE WHEN d.D3_CF LIKE 'DE%' OR d.D3_CF='PR0' THEN 'in'
                 WHEN d.D3_CF LIKE 'RE%' OR d.D3_CF='ER0' THEN 'out' ELSE 'unknown' END flow, d.D3_USUARIO operator
        FROM {sd3} d CROSS JOIN scope s
        {_product_join('d.D3_COD')}
        OUTER APPLY (
            SELECT TOP (1) z.Z1_DESC FROM {mssql.tabela('SZ1')} z
            WHERE z.D_E_L_E_T_='' AND z.Z1_COD=d.D3_MOTTRA AND z.Z1_FILIAL IN (s.filial,'')
            ORDER BY CASE WHEN z.Z1_FILIAL=s.filial THEN 0 ELSE 1 END,z.R_E_C_N_O_
        ) motive
        OUTER APPLY (
            SELECT COUNT(*) peerCount,MAX(p.D3_LOCAL) otherWarehouse,MAX(p.D3_COD) otherCode,
                   MAX(p.D3_QUANT) otherQuantity,MAX(p.D3_UM) otherUnit
            FROM {sd3} p
            WHERE p.D_E_L_E_T_='' AND p.D3_FILIAL=d.D3_FILIAL
              AND p.D3_EMISSAO=d.D3_EMISSAO AND p.D3_DOC=d.D3_DOC
              AND p.D3_NUMSEQ=d.D3_NUMSEQ AND d.D3_NUMSEQ<>''
              AND p.D3_ESTORNO=d.D3_ESTORNO
              AND ((d.D3_CF='RE4' AND p.D3_CF='DE4') OR (d.D3_CF='DE4' AND p.D3_CF='RE4'))
        ) peer
        WHERE d.D_E_L_E_T_='' AND d.D3_FILIAL=s.filial AND {location_filter}
          AND (s.startDate IS NULL OR d.D3_EMISSAO>=s.startDate)
          AND (s.endDate IS NULL OR d.D3_EMISSAO<=s.endDate)
    """
    for table, p, date_field, flow, kind, partner, cost in [
        ('SD1', 'D1', 'DTDIGIT', 'in', 'receipt', 'FORNECE', 'CUSTO'),
        ('SD2', 'D2', 'EMISSAO', 'out', 'dispatch', 'CLIENTE', 'CUSTO1'),
    ]:
        sql += f""" UNION ALL
        SELECT CONCAT('{table}:',d.R_E_C_N_O_),'{table}',d.{p}_{date_field},d.{p}_COD,
            product.description,d.{p}_QUANT,d.{p}_UM,d.{p}_LOCAL,'','',NULL,'',0,
            d.{p}_DOC,d.{p}_NUMSEQ,'','', '',d.{p}_TES,d.{p}_CF,d.{p}_SERIE,
            d.{p}_{partner},d.{p}_LOJA,'',tes.F4_TEXTO,0,d.{p}_{cost},d.{p}_LOTECTL,
            '','','',product.materialType,COALESCE(tes.F4_ESTOQUE,'?'),0,'{kind}',
            CASE WHEN tes.F4_ESTOQUE='S' THEN '{flow}'
                 WHEN tes.F4_ESTOQUE='N' THEN 'none' ELSE 'unknown' END, '' operator
        FROM {mssql.tabela(table)} d CROSS JOIN scope s
        {_product_join(f'd.{p}_COD')}
        OUTER APPLY (
            SELECT TOP (1) f.F4_ESTOQUE,f.F4_TEXTO FROM {mssql.tabela('SF4')} f
            WHERE f.D_E_L_E_T_='' AND f.F4_CODIGO=d.{p}_TES AND f.F4_FILIAL IN (s.filial,'')
            ORDER BY CASE WHEN f.F4_FILIAL=s.filial THEN 0 ELSE 1 END,f.R_E_C_N_O_
        ) tes
        WHERE d.D_E_L_E_T_='' AND d.{p}_FILIAL=s.filial AND d.{p}_LOCAL=s.local
          AND (s.startDate IS NULL OR d.{p}_{date_field}>=s.startDate)
          AND (s.endDate IS NULL OR d.{p}_{date_field}<=s.endDate)
        """
    return sql


def _stock() -> str:
    return f"""SELECT CONCAT('SB2:',b.R_E_C_N_O_) id,b.B2_COD code,product.description,
        product.unit,product.materialType,b.B2_LOCAL warehouse,b.B2_QATU quantity,
        b.B2_QEMP committed,b.B2_RESERVA reserved,b.B2_QACLASS awaitingClassification,
        b.B2_CM1 averageCost,b.B2_VATU1 stockValue,
        '' document,'' op,'' [date]
        FROM {mssql.tabela('SB2')} b CROSS JOIN scope s
        {_product_join('b.B2_COD')}
        WHERE b.D_E_L_E_T_='' AND b.B2_FILIAL=s.filial AND b.B2_LOCAL=s.local"""


def _orders() -> str:
    return f"""SELECT CONCAT('SC2:',c.R_E_C_N_O_) id,
        RTRIM(c.C2_NUM)+RTRIM(c.C2_ITEM)+RTRIM(c.C2_SEQUEN) op,
        c.C2_PRODUTO code,product.description,product.unit,c.C2_LOCAL warehouse,
        c.C2_QUANT quantity,c.C2_QUJE produced,c.C2_EMISSAO [date],c.C2_DATPRF dueDate,
        c.C2_DATRF closedDate,c.C2_LOC3 thirdPartyWarehouse,
        c.C2_3ENVIO sentToThirdParty,c.C2_3RETORN returnedFromThirdParty,
        '' document,CASE WHEN c.C2_DATRF<>'' THEN 1 ELSE 0 END closed
        FROM {mssql.tabela('SC2')} c CROSS JOIN scope s
        {_product_join('c.C2_PRODUTO')}
        WHERE c.D_E_L_E_T_='' AND c.C2_FILIAL=s.filial AND c.C2_LOCAL=s.local
          AND (s.startDate IS NULL OR c.C2_EMISSAO>=s.startDate)
          AND (s.endDate IS NULL OR c.C2_EMISSAO<=s.endDate)"""


def _inventory() -> str:
    return f"""SELECT CONCAT('SB7:',b.R_E_C_N_O_) id,b.B7_COD code,product.description,
        product.unit,b.B7_LOCAL warehouse,b.B7_QUANT quantity,b.B7_DATA [date],
        b.B7_DOC document,b.B7_CONTAGE counting,b.B7_STATUS inventoryStatus,
        b.B7_LOTECTL lot,b.B7_LOCALIZ address,b.B7_NUMSERI serial,'' op
        FROM {mssql.tabela('SB7')} b CROSS JOIN scope s
        {_product_join('b.B7_COD')}
        WHERE b.D_E_L_E_T_='' AND b.B7_FILIAL=s.filial AND b.B7_LOCAL=s.local
          AND (s.startDate IS NULL OR b.B7_DATA>=s.startDate)
          AND (s.endDate IS NULL OR b.B7_DATA<=s.endDate)"""


def read_warehouse(*, view='overview', filial='04', local='01', start=None, end=None,
                   query='', kind='all', status='all', page=1, page_size=50,
                   include_order_movements=False):
    history_builder = lambda: _history(include_order_movements=include_order_movements)
    builders = {'overview': history_builder, 'history': history_builder, 'stock': _stock,
                'orders': _orders, 'inventory': _inventory}
    history = view in ('overview', 'history')
    params = [filial, local, start.strftime('%Y%m%d') if start else None,
              end.strftime('%Y%m%d') if end else None]
    conditions = ['1=1']
    if query.strip():
        fields = "CONCAT(code,' ',description,' ',document,' ',op)"
        if history:
            fields = "CONCAT(code,' ',description,' ',document,' ',op,' ',reason,' ',reasonDescription,' ',otherCode,' ',partner)"
        conditions.append(f'CHARINDEX(?,{fields})>0')
        params.append(query.strip())
    if history and kind == 'fiscal':
        conditions.append("kind IN ('receipt','dispatch')")
    elif history and kind != 'all':
        conditions.append('kind=?')
        params.append(kind)
    if history and status in ('active', 'reversed'):
        conditions.append('reversed=?')
        params.append(int(status == 'reversed'))
    if view == 'orders' and status in ('active', 'closed'):
        conditions.append('closed=?')
        params.append(int(status == 'closed'))
    if view == 'stock' and status == 'nonzero':
        conditions.append('quantity<>0')
    cte = f"""WITH scope AS (
        SELECT CAST(? AS varchar(8)) filial,CAST(? AS varchar(2)) local,
               CAST(? AS varchar(8)) startDate,CAST(? AS varchar(8)) endDate
    ), records AS ({builders[view]()}), filtered AS (
        SELECT * FROM records WHERE {' AND '.join(conditions)}
    ) """
    order = 'code,id' if view == 'stock' else '[date] DESC,id DESC'
    with mssql.conexao() as conn:
        if hasattr(conn, 'timeout'):
            conn.timeout = 30
        if history:
            summary = mssql._fetchall(conn, cte +
                'SELECT kind,flow,reversed,COUNT_BIG(*) count,MAX([date]) latestDate FROM filtered GROUP BY kind, flow, reversed', params)
            total = sum(row['count'] for row in summary)
        else:
            summary = []
            total = mssql._fetchall(conn, cte + 'SELECT COUNT_BIG(*) total FROM filtered', params)[0]['total']
        items = mssql._fetchall(conn, cte + f'SELECT * FROM filtered ORDER BY {order} OFFSET ? ROWS FETCH NEXT ? ROWS ONLY',
                                tuple(params) + ((page - 1) * page_size, page_size))
    coverage = database_coverage()
    return {'readOnly': True, 'view': view, 'filial': filial, 'warehouse': local,
            'start': start.isoformat() if start else None, 'end': end.isoformat() if end else None, 'items': items,
            'page': page, 'pageSize': page_size, 'total': total, 'summary': summary,
            'asOf': datetime.now(timezone.utc).isoformat(),
            'latestMovement': max((r.get('latestDate') or '' for r in summary), default=''),
            'databaseFirstRecord': coverage.get('firstRecord') or '',
            'databaseLatestRecord': coverage.get('latestRecord') or '',
            'database': config.MSSQL_DATABASE}
