"""Leitura direta da base Protheus dev em SQL Server.

Este módulo concentra consultas. A escrita explícita do DEV fica em
sql_production.py e sql_production_db.py, desativada por padrão.
"""
from __future__ import annotations

from contextlib import contextmanager
from datetime import date
from decimal import Decimal
import re
from typing import Any, Iterable

from . import config

_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def _quote_identifier(value: str) -> str:
    if not _IDENTIFIER.fullmatch(value):
        raise ValueError(f"Identificador SQL Server invalido: {value!r}")
    return f"[{value}]"


def tabela(nome: str) -> str:
    """`SB1` -> `[dbo].[SB1010]`, usando o sufixo da empresa Protheus."""
    schema = _quote_identifier(config.MSSQL_SCHEMA)
    table = _quote_identifier(f"{nome.upper()}{config.EMPRESA}")
    return f"{schema}.{table}"


@contextmanager
def conexao():
    try:
        import pyodbc
    except ImportError as exc:  # pragma: no cover - depende do ambiente local
        raise RuntimeError(
            "Backend MSSQL exige pyodbc. Instale com `pip install pyodbc`."
        ) from exc

    parts = [
        f"DRIVER={{{config.MSSQL_DRIVER}}}",
        f"SERVER={config.MSSQL_HOST},{config.MSSQL_PORT}",
        f"DATABASE={config.MSSQL_DATABASE}",
        f"Encrypt={config.MSSQL_ENCRYPT}",
        f"TrustServerCertificate={config.MSSQL_TRUST_SERVER_CERT}",
        "Connection Timeout=8",
    ]
    if config.MSSQL_USER:
        parts.extend(
            [
                f"UID={config.MSSQL_USER}",
                f"PWD={config.MSSQL_PASSWORD}",
            ]
        )
    else:
        parts.append("Trusted_Connection=yes")

    conn = pyodbc.connect(";".join(parts))
    try:
        yield conn
    finally:
        conn.close()


def _clean(value: Any) -> Any:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, Decimal):
        return float(value)
    return value


def _rows(cursor) -> list[dict[str, Any]]:
    columns = [column[0] for column in cursor.description]
    return [
        {column: _clean(value) for column, value in zip(columns, row)}
        for row in cursor.fetchall()
    ]


def _fetchall(conn, sql: str, params: Iterable[Any] = ()) -> list[dict[str, Any]]:
    cursor = conn.cursor()
    cursor.execute(sql, tuple(params))
    return _rows(cursor)


def _fetchone(conn, sql: str, params: Iterable[Any] = ()) -> dict[str, Any] | None:
    cursor = conn.cursor()
    cursor.execute(sql, tuple(params))
    row = cursor.fetchone()
    if row is None:
        return None
    columns = [column[0] for column in cursor.description]
    return {column: _clean(value) for column, value in zip(columns, row)}


def health() -> dict[str, str]:
    with conexao() as conn:
        row = _fetchone(
            conn,
            "SELECT DB_NAME() AS banco, @@SERVERNAME AS servidor",
        )
    return row or {"banco": config.MSSQL_DATABASE, "servidor": config.MSSQL_HOST}


def write_readiness() -> dict[str, Any]:
    """Separa autorização local de escrita da conexão efetiva com o AppServer."""
    from .warehouse_writes import readiness
    return readiness(health())


def search_products(query: str, filial: str, limit: int) -> list[dict[str, Any]]:
    normalized = query.strip().upper()
    pattern = f"%{normalized}%"
    prefix = f"{normalized}%"
    sb1 = tabela("SB1")
    with conexao() as conn:
        return _fetchall(
            conn,
            f"""
            SELECT TOP ({int(limit)})
              LTRIM(RTRIM(B1_FILIAL)) AS filial,
              LTRIM(RTRIM(B1_COD)) AS code,
              LTRIM(RTRIM(B1_DESC)) AS description,
              LTRIM(RTRIM(B1_TIPO)) AS type,
              LTRIM(RTRIM(B1_UM)) AS unit,
              LTRIM(RTRIM(B1_GRUPO)) AS [group],
              LTRIM(RTRIM(COALESCE(B1_MSBLQL, ''))) AS screenBlock
            FROM {sb1}
            WHERE LTRIM(RTRIM(B1_COD)) <> ''
              AND LTRIM(RTRIM(COALESCE(B1_DESC, ''))) <> ''
              AND (
                LTRIM(RTRIM(B1_FILIAL)) = ?
                OR LTRIM(RTRIM(B1_FILIAL)) = ''
              )
              AND COALESCE(NULLIF(LTRIM(RTRIM(COALESCE(B1_MSBLQL, ''))), ''), '2') <> '1'
              AND (
                ? = ''
                OR UPPER(LTRIM(RTRIM(B1_COD))) LIKE ?
                OR UPPER(LTRIM(RTRIM(B1_DESC))) LIKE ?
              )
            ORDER BY
              CASE WHEN UPPER(LTRIM(RTRIM(B1_COD))) = ? THEN 0 ELSE 1 END,
              CASE WHEN UPPER(LTRIM(RTRIM(B1_COD))) LIKE ? THEN 0 ELSE 1 END,
              CASE WHEN LTRIM(RTRIM(B1_COD)) LIKE '7%' THEN 0 ELSE 1 END,
              LTRIM(RTRIM(B1_COD))
            """,
            (filial, normalized, pattern, pattern, normalized, prefix),
        )


def product_by_code(codigo: str, filial: str) -> dict[str, Any] | None:
    sb1 = tabela("SB1")
    with conexao() as conn:
        return _fetchone(
            conn,
            f"""
            SELECT TOP (1)
              LTRIM(RTRIM(B1_FILIAL)) AS filial,
              LTRIM(RTRIM(B1_COD)) AS code,
              LTRIM(RTRIM(B1_DESC)) AS description,
              LTRIM(RTRIM(B1_TIPO)) AS type,
              LTRIM(RTRIM(B1_UM)) AS unit,
              LTRIM(RTRIM(B1_GRUPO)) AS [group],
              LTRIM(RTRIM(COALESCE(B1_MSBLQL, ''))) AS screenBlock
            FROM {sb1}
            WHERE UPPER(LTRIM(RTRIM(B1_COD))) = ?
              AND (
                LTRIM(RTRIM(B1_FILIAL)) = ?
                OR LTRIM(RTRIM(B1_FILIAL)) = ''
              )
              AND COALESCE(NULLIF(LTRIM(RTRIM(COALESCE(B1_MSBLQL, ''))), ''), '2') <> '1'
            """,
            (codigo.strip().upper(), filial),
        )


def balances_for(codigo: str, filial: str) -> list[dict[str, Any]]:
    sb2 = tabela("SB2")
    with conexao() as conn:
        return _fetchall(
            conn,
            f"""
            SELECT
              LTRIM(RTRIM(B2_FILIAL)) AS filial,
              LTRIM(RTRIM(B2_LOCAL)) AS armazem,
              B2_QATU AS currentStock,
              B2_QEMP AS committedQuantity,
              COALESCE(B2_RESERVA, 0) AS reservedQuantity,
              B2_QATU AS availableQuantity
            FROM {sb2}
            WHERE D_E_L_E_T_ <> '*'
              AND B2_FILIAL = ?
              AND UPPER(LTRIM(RTRIM(B2_COD))) = ?
            ORDER BY armazem
            """,
            (filial, codigo.strip().upper()),
        )


def _best_balance(balances: list[dict[str, Any]]) -> dict[str, Any] | None:
    values = [
        item
        for item in balances
        if (item.get("availableQuantity") or 0) > 0
        or (item.get("currentStock") or 0) > 0
    ] or balances
    if not values:
        return None
    return sorted(
        values,
        key=lambda item: (
            item.get("availableQuantity") or 0,
            item.get("currentStock") or 0,
        ),
        reverse=True,
    )[0]


def components_for(codigo: str, filial: str) -> list[dict[str, Any]]:
    sg1 = tabela("SG1")
    sb1 = tabela("SB1")
    today = date.today().strftime("%Y%m%d")
    with conexao() as conn:
        rows = _fetchall(
            conn,
            f"""
            SELECT
              LTRIM(RTRIM(s.G1_FILIAL)) AS filial,
              LTRIM(RTRIM(s.G1_COMP)) AS code,
              LTRIM(RTRIM(COALESCE(p.B1_DESC, ''))) AS description,
              s.G1_QUANT AS quantityPerUnit,
              LTRIM(RTRIM(COALESCE(p.B1_UM, ''))) AS unit,
              LTRIM(RTRIM(COALESCE(s.G1_TRT, ''))) AS structureSequence
            FROM {sg1} s
            LEFT JOIN {sb1} p
              ON LTRIM(RTRIM(p.B1_COD)) = LTRIM(RTRIM(s.G1_COMP))
             AND (
               LTRIM(RTRIM(p.B1_FILIAL)) = ?
               OR LTRIM(RTRIM(p.B1_FILIAL)) = ''
             )
            WHERE s.D_E_L_E_T_ <> '*'
              AND UPPER(LTRIM(RTRIM(s.G1_COD))) = ?
              AND (
                LTRIM(RTRIM(s.G1_FILIAL)) = ?
                OR LTRIM(RTRIM(s.G1_FILIAL)) = ''
              )
              AND LTRIM(RTRIM(COALESCE(s.G1_INI, ''))) <= ?
              AND (
                LTRIM(RTRIM(COALESCE(s.G1_FIM, ''))) = ''
                OR LTRIM(RTRIM(s.G1_FIM)) >= ?
              )
              AND COALESCE(NULLIF(LTRIM(RTRIM(COALESCE(p.B1_MSBLQL, ''))), ''), '2') <> '1'
            ORDER BY
              LTRIM(RTRIM(COALESCE(s.G1_TRT, ''))),
              LTRIM(RTRIM(s.G1_COMP))
            """,
            (filial, codigo.strip().upper(), filial, today, today),
        )

    components = []
    for row in rows:
        balances = balances_for(row["code"], filial)
        best = _best_balance(balances)
        row["warehouseBalances"] = balances
        row["childOrders"] = []
        row["requirementSource"] = "SG1"
        row["sourceOrder"] = ""
        row["commitmentDate"] = ""
        row["originalQuantity"] = 0
        row["commitmentQuantity"] = 0
        row["armazem"] = best.get("armazem", "") if best else ""
        row["stockAvailable"] = best.get("availableQuantity", 0) if best else 0
        row["currentStock"] = best.get("currentStock", 0) if best else 0
        row["committedQuantity"] = best.get("committedQuantity", 0) if best else 0
        row["reservedQuantity"] = best.get("reservedQuantity", 0) if best else 0
        components.append(row)
    return components


def open_orders(filial: str) -> list[dict[str, Any]]:
    sc2 = tabela("SC2")
    with conexao() as conn:
        rows = _fetchall(
            conn,
            f"""
            SELECT
              C2_FILIAL AS filial,
              LTRIM(RTRIM(C2_NUM)) AS numero,
              LTRIM(RTRIM(C2_ITEM)) AS item,
              LTRIM(RTRIM(C2_SEQUEN)) AS sequencia,
              LTRIM(RTRIM(C2_ITEMGRD)) AS itemGrade,
              LTRIM(RTRIM(C2_PRODUTO)) AS produto,
              C2_QUANT AS quantidade,
              LTRIM(RTRIM(C2_LOCAL)) AS local,
              C2_EMISSAO AS emissao,
              C2_DATPRF AS previsao
            FROM {sc2}
            WHERE D_E_L_E_T_ <> '*'
              AND C2_FILIAL = ?
              AND LTRIM(RTRIM(C2_DATRF)) = ''
            ORDER BY numero, item, sequencia
            """,
            (filial,),
        )
    for row in rows:
        row["emissao"] = _date_br(row.get("emissao"))
        row["previsao"] = _date_br(row.get("previsao"))
        row["encerrada"] = False
    return rows


def commitments_for(op: str, filial: str) -> list[dict[str, Any]]:
    sd4 = tabela("SD4")
    with conexao() as conn:
        return _fetchall(
            conn,
            f"""
            SELECT
              LTRIM(RTRIM(D4_OP)) AS op,
              LTRIM(RTRIM(D4_COD)) AS produto,
              LTRIM(RTRIM(D4_LOCAL)) AS local,
              D4_QUANT AS quantidade,
              D4_QTDEORI AS quantidadeOriginal
            FROM {sd4}
            WHERE D_E_L_E_T_ <> '*'
              AND D4_FILIAL = ?
              AND LTRIM(RTRIM(D4_OP)) = ?
            ORDER BY produto
            """,
            (filial, op.strip()),
        )


def op_movements(op: str, filial: str) -> dict[str, Any]:
    """Snapshot read-only da OP em SC2, SD4 e SD3."""
    normalized = _normalize_op(op)
    with conexao() as conn:
        ordem = _official_order(conn, normalized, filial)
        empenhos = _official_commitments(conn, normalized, filial)
        movimentos = _official_movements(conn, normalized, filial)

    for row in movimentos:
        row["data"] = _date_br(row.get("data"))
        row["estorno"] = str(row.pop("estornoRaw", "") or "").strip().upper() == "S"

    status = _official_status(ordem, empenhos, movimentos)
    divergencias = _movement_warnings(ordem, movimentos)
    return {
        "op": normalized,
        "filial": filial,
        "statusOficial": status,
        "ordem": ordem,
        "empenhos": empenhos,
        "movimentos": movimentos,
        "divergencias": divergencias,
    }


def production_completion_preview(
    op: str,
    filial: str,
    quantidade: float | None = None,
    armazem: str | None = None,
) -> dict[str, Any]:
    """Previa read-only dos movimentos esperados para apontar uma OP.

    `armazem` troca o local de entrada do acabado (PR0), como o campo
    Armazem da MATA250, que vem preenchido mas aceita edicao.
    """
    normalized = _normalize_op(op)
    with conexao() as conn:
        ordem = _official_order(conn, normalized, filial)
        empenhos = _official_commitments(conn, normalized, filial)
        movimentos = _official_movements(conn, normalized, filial)

    if ordem is None:
        return {
            "op": normalized,
            "filial": filial,
            "readOnly": True,
            "rotinaStatus": "pendente_pesquisa",
            "rotinasCandidatas": ["MATA250", "MATA680", "MATA681"],
            "quantidadeSolicitada": quantidade or 0,
            "quantidadeRestante": 0,
            "ordem": None,
            "movimentosPrevistos": [],
            "saldosComponentes": [],
            "divergencias": ["OP nao encontrada em SC2 para simular apontamento."],
            "pendenciasPesquisa": _completion_preview_research_gaps(),
        }

    planned = ordem.get("quantidadePlanejada") or 0
    produced = ordem.get("quantidadeProduzida") or 0
    remaining = max(planned - produced, 0)
    requested = quantidade if quantidade is not None else remaining
    requested = max(float(requested or 0), 0)
    # Igual a MATA250: sugere sempre o C2_LOCAL, mesmo com PR0 anterior.
    default_local = str(ordem.get("local") or "").strip()
    chosen_local = (armazem or "").strip().upper()
    finished_local = chosen_local or default_local
    document = _document_preview_reference(normalized, ordem, movimentos)

    preview_movements = [
        {
            "cf": "PR0",
            "tm": "001",
            "produto": ordem.get("produto") or "",
            "produtoDescricao": ordem.get("produtoDescricao") or "",
            "local": finished_local,
            "quantidade": requested,
            "documentoReferencia": document,
        }
    ]
    component_balances = []
    divergences = []
    for commitment in empenhos:
        quantity = _component_preview_quantity(commitment, planned, requested)
        if quantity <= 0:
            continue
        preview_movements.append(
            {
                "cf": "RE1",
                "tm": "999",
                "produto": commitment.get("produto") or "",
                "produtoDescricao": commitment.get("produtoDescricao") or "",
                "local": commitment.get("local") or "",
                "quantidade": quantity,
                "documentoReferencia": document,
            }
        )
        balance = _component_preview_balance(commitment, filial, quantity)
        component_balances.append(balance)
        if not balance["suficiente"]:
            divergences.append(
                "Saldo insuficiente para "
                f"{balance['produto']} no local {balance['local']}: "
                f"{balance['saldoAtual']} disponivel, {quantity} previsto."
            )

    if chosen_local and chosen_local not in {
        str(item.get("code") or "").strip().upper()
        for item in warehouses(filial)
    }:
        divergences.append(
            f"Armazem {chosen_local} nao cadastrado na NNR da filial {filial}."
        )
    if ordem.get("encerrada"):
        divergences.append("OP ja encerrada em SC2; apontamento deve ser bloqueado.")
    if remaining and requested > remaining:
        divergences.append(
            f"Quantidade solicitada {requested} supera saldo restante {remaining}."
        )
    if not empenhos:
        divergences.append("OP sem empenhos SD4 para prever RE1.")

    return {
        "op": normalized,
        "filial": filial,
        "readOnly": True,
        "rotinaStatus": "pendente_pesquisa",
        "rotinasCandidatas": ["MATA250", "MATA680", "MATA681"],
        "quantidadeSolicitada": requested,
        "quantidadeRestante": remaining,
        "armazemPadrao": default_local,
        "armazemInformado": chosen_local,
        "ordem": ordem,
        "movimentosPrevistos": preview_movements,
        "saldosComponentes": component_balances,
        "divergencias": divergences,
        "pendenciasPesquisa": _completion_preview_research_gaps(),
    }


def transfer_movements(
    filial: str,
    produto: str = "",
    local_origem: str = "",
    local_destino: str = "",
    limit: int = 20,
) -> dict[str, Any]:
    """Snapshot read-only de transferencias oficiais RE4/DE4 em SD3."""
    product = produto.strip().upper()
    rows_limit = max(1, min(int(limit), 100)) * 4
    sd3 = tabela("SD3")
    sb1 = tabela("SB1")
    params: list[Any] = [filial, filial]
    product_filter = ""
    if product:
        product_filter = "AND UPPER(LTRIM(RTRIM(d.D3_COD))) = ?"
        params.append(product)

    with conexao() as conn:
        rows = _fetchall(
            conn,
            f"""
            SELECT TOP ({rows_limit})
              LTRIM(RTRIM(d.D3_CF)) AS cf,
              LTRIM(RTRIM(d.D3_TM)) AS tm,
              LTRIM(RTRIM(d.D3_COD)) AS produto,
              LTRIM(RTRIM(COALESCE(p.B1_DESC, ''))) AS produtoDescricao,
              LTRIM(RTRIM(d.D3_LOCAL)) AS local,
              d.D3_QUANT AS quantidade,
              LTRIM(RTRIM(d.D3_DOC)) AS documento,
              d.D3_EMISSAO AS data,
              LTRIM(RTRIM(COALESCE(d.D3_ESTORNO, ''))) AS estornoRaw
            FROM {sd3} d
            LEFT JOIN {sb1} p
              ON LTRIM(RTRIM(p.B1_COD)) = LTRIM(RTRIM(d.D3_COD))
             AND (
               LTRIM(RTRIM(p.B1_FILIAL)) = ?
               OR LTRIM(RTRIM(p.B1_FILIAL)) = ''
             )
            WHERE d.D_E_L_E_T_ <> '*'
              AND d.D3_FILIAL = ?
              AND LTRIM(RTRIM(d.D3_CF)) IN ('RE4', 'DE4')
              {product_filter}
            ORDER BY d.D3_EMISSAO DESC, d.D3_DOC DESC, d.D3_COD, d.D3_CF
            """,
            params,
        )

    for row in rows:
        row["data"] = _date_br(row.get("data"))
        row["estorno"] = str(row.pop("estornoRaw", "") or "").strip().upper() == "S"

    transferencias = _pair_transfer_rows(rows)
    origem = local_origem.strip()
    destino = local_destino.strip()
    if origem:
        transferencias = [
            item for item in transferencias if item.get("localOrigem") == origem
        ]
    if destino:
        transferencias = [
            item for item in transferencias if item.get("localDestino") == destino
        ]
    transferencias = transferencias[: max(1, min(int(limit), 100))]
    return {
        "filial": filial,
        "transferencias": transferencias,
        "divergencias": _transfer_warnings(transferencias),
    }


def dismantling_movements(
    filial: str,
    documento: str = "",
    produto: str = "",
    limit: int = 20,
) -> dict[str, Any]:
    """Snapshot read-only de desmontagens oficiais RE7/DE7 em SD3."""
    document = documento.strip().upper()
    product = produto.strip().upper()
    rows_limit = max(1, min(int(limit), 100)) * 12
    sd3 = tabela("SD3")
    sb1 = tabela("SB1")
    params: list[Any] = [filial, filial]
    filters = []
    if document:
        filters.append("AND UPPER(LTRIM(RTRIM(d.D3_DOC))) = ?")
        params.append(document)
    extra_filters = "\n              ".join(filters)

    with conexao() as conn:
        rows = _fetchall(
            conn,
            f"""
            SELECT TOP ({rows_limit})
              LTRIM(RTRIM(d.D3_CF)) AS cf,
              LTRIM(RTRIM(d.D3_TM)) AS tm,
              LTRIM(RTRIM(d.D3_COD)) AS produto,
              LTRIM(RTRIM(COALESCE(p.B1_DESC, ''))) AS produtoDescricao,
              LTRIM(RTRIM(d.D3_LOCAL)) AS local,
              d.D3_QUANT AS quantidade,
              LTRIM(RTRIM(d.D3_DOC)) AS documento,
              LTRIM(RTRIM(COALESCE(d.D3_NUMSEQ, ''))) AS numSeq,
              d.D3_EMISSAO AS data,
              LTRIM(RTRIM(COALESCE(d.D3_ESTORNO, ''))) AS estornoRaw
            FROM {sd3} d
            LEFT JOIN {sb1} p
              ON LTRIM(RTRIM(p.B1_COD)) = LTRIM(RTRIM(d.D3_COD))
             AND (
               LTRIM(RTRIM(p.B1_FILIAL)) = ?
               OR LTRIM(RTRIM(p.B1_FILIAL)) = ''
             )
            WHERE d.D_E_L_E_T_ <> '*'
              AND d.D3_FILIAL = ?
              AND LTRIM(RTRIM(d.D3_CF)) IN ('RE7', 'DE7')
              {extra_filters}
            ORDER BY d.D3_EMISSAO DESC, d.D3_DOC DESC, d.D3_NUMSEQ, d.D3_CF
            """,
            params,
        )

    for row in rows:
        row["data"] = _date_br(row.get("data"))
        row["estorno"] = str(row.pop("estornoRaw", "") or "").strip().upper() == "S"

    desmontagens = _pair_dismantling_rows(rows)
    if product:
        desmontagens = [
            item
            for item in desmontagens
            if item.get("produtoOrigem") == product
            or any(
                component.get("produto") == product
                for component in item.get("componentesRetornados", [])
            )
        ]
    desmontagens = desmontagens[: max(1, min(int(limit), 100))]
    return {
        "filial": filial,
        "desmontagens": desmontagens,
        "divergencias": _dismantling_warnings(desmontagens),
    }


def inventory_audit_movements(
    filial: str,
    documento: str = "",
    op: str = "",
    produto: str = "",
    tipo: str = "",
    limit: int = 50,
) -> dict[str, Any]:
    """Snapshot read-only de estornos, retornos e ajustes oficiais em SD3."""
    document = documento.strip().upper()
    order = _normalize_op(op) if op.strip() else ""
    product = produto.strip().upper()
    kind = tipo.strip().lower()
    rows_limit = max(1, min(int(limit), 200)) * 2
    sd3 = tabela("SD3")
    sb1 = tabela("SB1")
    params: list[Any] = [filial, filial]
    filters = []
    if document:
        filters.append("AND UPPER(LTRIM(RTRIM(d.D3_DOC))) = ?")
        params.append(document)
    if order:
        filters.append("AND UPPER(LTRIM(RTRIM(d.D3_OP))) = ?")
        params.append(order)
    if product:
        filters.append("AND UPPER(LTRIM(RTRIM(d.D3_COD))) = ?")
        params.append(product)
    extra_filters = "\n              ".join(filters)

    with conexao() as conn:
        rows = _fetchall(
            conn,
            f"""
            SELECT TOP ({rows_limit})
              LTRIM(RTRIM(d.D3_CF)) AS cf,
              LTRIM(RTRIM(d.D3_TM)) AS tm,
              LTRIM(RTRIM(d.D3_COD)) AS produto,
              LTRIM(RTRIM(COALESCE(p.B1_DESC, ''))) AS produtoDescricao,
              LTRIM(RTRIM(d.D3_LOCAL)) AS local,
              d.D3_QUANT AS quantidade,
              LTRIM(RTRIM(d.D3_DOC)) AS documento,
              LTRIM(RTRIM(COALESCE(d.D3_OP, ''))) AS op,
              LTRIM(RTRIM(COALESCE(d.D3_NUMSEQ, ''))) AS numSeq,
              d.D3_EMISSAO AS data,
              LTRIM(RTRIM(COALESCE(d.D3_USUARIO, ''))) AS usuario,
              LTRIM(RTRIM(COALESCE(d.D3_MOTTRA, ''))) AS motivoRaw,
              LTRIM(RTRIM(COALESCE(d.D3_OBS, ''))) AS obsRaw,
              LTRIM(RTRIM(COALESCE(d.D3_OBSERVA, ''))) AS observaRaw,
              LTRIM(RTRIM(COALESCE(d.D3_ESTORNO, ''))) AS estornoRaw
            FROM {sd3} d
            LEFT JOIN {sb1} p
              ON LTRIM(RTRIM(p.B1_COD)) = LTRIM(RTRIM(d.D3_COD))
             AND (
               LTRIM(RTRIM(p.B1_FILIAL)) = ?
               OR LTRIM(RTRIM(p.B1_FILIAL)) = ''
             )
            WHERE d.D_E_L_E_T_ <> '*'
              AND d.D3_FILIAL = ?
              AND (
                (LTRIM(RTRIM(d.D3_CF)) = 'ER0' AND LTRIM(RTRIM(d.D3_TM)) = '999')
                OR (LTRIM(RTRIM(d.D3_CF)) = 'DE1' AND LTRIM(RTRIM(d.D3_TM)) = '499')
                OR (LTRIM(RTRIM(d.D3_CF)) = 'DE0' AND LTRIM(RTRIM(d.D3_TM)) = '400')
                OR (LTRIM(RTRIM(d.D3_CF)) = 'RE0' AND LTRIM(RTRIM(d.D3_TM)) = '501')
              )
              {extra_filters}
            ORDER BY d.D3_EMISSAO DESC, d.D3_DOC DESC, d.D3_NUMSEQ DESC
            """,
            params,
        )

    movimentos = [_inventory_audit_row(row) for row in rows]
    if kind:
        movimentos = [item for item in movimentos if item.get("tipo") == kind]
    movimentos = movimentos[: max(1, min(int(limit), 200))]
    return {
        "filial": filial,
        "movimentos": movimentos,
        "resumoPorTipo": _inventory_audit_summary(movimentos),
        "pendenciasPesquisa": [
            "Validar se motivo/usuario oficiais dependem de workflow, aprovacao "
            "ou parametro fora da SD3.",
            "Confirmar regra oficial para diferenciar ajuste manual, retorno "
            "operacional e estorno automatico quando CF/TM nao bastarem.",
        ],
    }


def _component_preview_quantity(
    commitment: dict[str, Any],
    planned: float,
    requested: float,
) -> float:
    original = commitment.get("quantidadeOriginal") or 0
    remaining = commitment.get("quantidadeRestante") or 0
    if planned and original:
        calculated = float(original) / float(planned) * requested
    else:
        calculated = float(remaining or 0)
    if remaining:
        return round(min(float(remaining), calculated), 6)
    return round(calculated, 6)


def _component_preview_balance(
    commitment: dict[str, Any],
    filial: str,
    quantity: float,
) -> dict[str, Any]:
    product = str(commitment.get("produto") or "").strip()
    local = str(commitment.get("local") or "").strip()
    balance_rows = balances_for(product, filial) if product else []
    balance = next(
        (
            item
            for item in balance_rows
            if str(item.get("armazem") or "").strip() == local
        ),
        None,
    )
    available = balance.get("availableQuantity", 0) if balance else 0
    return {
        "produto": product,
        "produtoDescricao": commitment.get("produtoDescricao") or "",
        "local": local,
        "saldoAtual": available,
        "quantidadePrevista": quantity,
        "suficiente": available >= quantity,
    }


def _completion_preview_research_gaps() -> list[str]:
    return [
        "Confirmar rotina oficial usada pela Vetti: MATA250, MATA680, MATA681 "
        "ou customizacao.",
        "Validar regra oficial para perda, ganho, apontamento parcial e "
        "encerramento automatico.",
        "Confirmar campos obrigatorios do payload oficial antes de qualquer "
        "escrita futura em HML.",
    ]


def _document_preview_reference(
    op: str,
    ordem: dict[str, Any],
    movimentos: list[dict[str, Any]],
) -> str:
    for movement in movimentos:
        document = str(movement.get("documento") or "").strip()
        if document:
            return document
    number = str(ordem.get("numeroBase") or "").strip()
    item = str(ordem.get("item") or "").strip()
    sequence = str(ordem.get("sequencia") or "").strip()
    fallback = f"{number}{item}{sequence}".strip()
    return fallback or op


def _pair_transfer_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    groups: dict[tuple[str, str, Any, str], list[dict[str, Any]]] = {}
    for row in rows:
        key = (
            str(row.get("documento") or "").strip(),
            str(row.get("produto") or "").strip(),
            row.get("quantidade") or 0,
            str(row.get("data") or "").strip(),
        )
        groups.setdefault(key, []).append(row)

    transfers = []
    for (documento, produto, quantidade, data), group in groups.items():
        saidas = [item for item in group if item.get("cf") == "RE4"]
        entradas = [item for item in group if item.get("cf") == "DE4"]
        origem = str(saidas[0].get("local") or "").strip() if saidas else ""
        destino = str(entradas[0].get("local") or "").strip() if entradas else ""
        if saidas and entradas:
            status = "pareada"
        elif saidas:
            status = "sem_entrada"
        else:
            status = "sem_saida"
        description = next(
            (
                str(item.get("produtoDescricao") or "").strip()
                for item in group
                if str(item.get("produtoDescricao") or "").strip()
            ),
            "",
        )
        transfers.append(
            {
                "documento": documento,
                "produto": produto,
                "produtoDescricao": description,
                "quantidade": quantidade,
                "localOrigem": origem,
                "localDestino": destino,
                "data": data,
                "status": status,
                "movimentos": group,
            }
        )

    return sorted(
        transfers,
        key=lambda item: (item.get("data") or "", item.get("documento") or ""),
        reverse=True,
    )


def _inventory_audit_row(row: dict[str, Any]) -> dict[str, Any]:
    row = dict(row)
    row["data"] = _date_br(row.get("data"))
    row["estorno"] = str(row.pop("estornoRaw", "") or "").strip().upper() == "S"
    motivo = _first_text(row.pop("motivoRaw", ""), row.get("obsRaw"), row.get("observaRaw"))
    observacao = _first_text(row.pop("observaRaw", ""), row.pop("obsRaw", ""))
    tipo, label = _inventory_audit_type(row.get("cf"), row.get("tm"))
    return {
        "cf": row.get("cf") or "",
        "tm": row.get("tm") or "",
        "tipo": tipo,
        "tipoLabel": label,
        "documento": row.get("documento") or "",
        "op": row.get("op") or "",
        "produto": row.get("produto") or "",
        "produtoDescricao": row.get("produtoDescricao") or "",
        "quantidade": row.get("quantidade") or 0,
        "local": row.get("local") or "",
        "data": row.get("data") or "",
        "numSeq": row.get("numSeq") or "",
        "usuario": row.get("usuario") or "",
        "motivo": motivo,
        "observacao": observacao,
        "estorno": row["estorno"],
    }


def _inventory_audit_type(cf: Any, tm: Any) -> tuple[str, str]:
    key = (str(cf or "").strip().upper(), str(tm or "").strip())
    return {
        ("ER0", "999"): ("estorno_op", "Estorno de OP"),
        ("DE1", "499"): ("retorno_op", "Retorno de OP"),
        ("DE0", "400"): ("devolucao_manual", "Devolucao manual"),
        ("RE0", "501"): ("requisicao_manual", "Requisicao manual"),
    }.get(key, ("outro", "Movimento especial"))


def _inventory_audit_summary(
    movimentos: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    counts: dict[str, dict[str, Any]] = {}
    for item in movimentos:
        tipo = str(item.get("tipo") or "outro")
        if tipo not in counts:
            counts[tipo] = {
                "tipo": tipo,
                "tipoLabel": item.get("tipoLabel") or "Movimento especial",
                "quantidadeMovimentos": 0,
            }
        counts[tipo]["quantidadeMovimentos"] += 1
    return list(counts.values())


def _first_text(*values: Any) -> str:
    for value in values:
        text = str(value or "").strip()
        if text:
            return text
    return ""


def _pair_dismantling_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for row in rows:
        key = (
            str(row.get("documento") or "").strip(),
            str(row.get("data") or "").strip(),
        )
        groups.setdefault(key, []).append(row)

    dismantlings = []
    for (documento, data), group in groups.items():
        origins = [item for item in group if item.get("cf") == "RE7"]
        returns = [item for item in group if item.get("cf") == "DE7"]
        origin = origins[0] if origins else {}
        if origins and returns:
            status = "pareada"
        elif origins:
            status = "sem_retorno"
        else:
            status = "sem_origem"
        dismantlings.append(
            {
                "documento": documento,
                "produtoOrigem": str(origin.get("produto") or "").strip(),
                "produtoOrigemDescricao": str(
                    origin.get("produtoDescricao") or ""
                ).strip(),
                "quantidadeOrigem": origin.get("quantidade") or 0,
                "localOrigem": str(origin.get("local") or "").strip(),
                "data": data,
                "status": status,
                "componentesRetornados": [
                    {
                        "produto": item.get("produto") or "",
                        "produtoDescricao": item.get("produtoDescricao") or "",
                        "quantidade": item.get("quantidade") or 0,
                        "local": item.get("local") or "",
                        "documento": item.get("documento") or "",
                        "data": item.get("data") or "",
                        "numSeq": item.get("numSeq") or "",
                    }
                    for item in returns
                ],
                "movimentos": group,
            }
        )

    return sorted(
        dismantlings,
        key=lambda item: (item.get("data") or "", item.get("documento") or ""),
        reverse=True,
    )


def _dismantling_warnings(desmontagens: list[dict[str, Any]]) -> list[str]:
    warnings = []
    for item in desmontagens:
        if item.get("status") == "pareada":
            continue
        warnings.append(
            "Desmontagem "
            f"{item.get('documento') or ''} esta "
            f"{item.get('status') or 'incompleta'} no par RE7/DE7."
        )
    return warnings


def _transfer_warnings(transferencias: list[dict[str, Any]]) -> list[str]:
    warnings = []
    for item in transferencias:
        if item.get("status") == "pareada":
            continue
        warnings.append(
            "Transferencia "
            f"{item.get('documento') or ''} do produto {item.get('produto') or ''} "
            f"esta {item.get('status') or 'incompleta'} no par RE4/DE4."
        )
    return warnings


def _normalize_op(op: str) -> str:
    return re.sub(r"\s+", "", op.strip().upper())


def _op_match_sql(alias: str, field: str) -> str:
    full = (
        f"CONCAT(LTRIM(RTRIM({alias}.C2_NUM)), "
        f"LTRIM(RTRIM({alias}.C2_ITEM)), "
        f"LTRIM(RTRIM({alias}.C2_SEQUEN)), "
        f"LTRIM(RTRIM({alias}.C2_ITEMGRD)))"
    )
    compact = (
        f"CONCAT(LTRIM(RTRIM({alias}.C2_NUM)), "
        f"LTRIM(RTRIM({alias}.C2_ITEM)), "
        f"LTRIM(RTRIM({alias}.C2_SEQUEN)))"
    )
    return (
        f"({full} = ? OR {compact} = ? OR "
        f"LTRIM(RTRIM({alias}.{field})) = ?)"
    )


def _official_order(conn, op: str, filial: str) -> dict[str, Any] | None:
    sc2 = tabela("SC2")
    sb1 = tabela("SB1")
    row = _fetchone(
        conn,
        f"""
        SELECT TOP (1)
          LTRIM(RTRIM(c.C2_FILIAL)) AS filial,
          CONCAT(
            LTRIM(RTRIM(c.C2_NUM)),
            LTRIM(RTRIM(c.C2_ITEM)),
            LTRIM(RTRIM(c.C2_SEQUEN)),
            LTRIM(RTRIM(c.C2_ITEMGRD))
          ) AS numero,
          LTRIM(RTRIM(c.C2_NUM)) AS numeroBase,
          LTRIM(RTRIM(c.C2_ITEM)) AS item,
          LTRIM(RTRIM(c.C2_SEQUEN)) AS sequencia,
          LTRIM(RTRIM(c.C2_ITEMGRD)) AS itemGrade,
          LTRIM(RTRIM(c.C2_PRODUTO)) AS produto,
          LTRIM(RTRIM(COALESCE(p.B1_DESC, ''))) AS produtoDescricao,
          c.C2_QUANT AS quantidadePlanejada,
          COALESCE(c.C2_QUJE, 0) AS quantidadeProduzida,
          LTRIM(RTRIM(c.C2_LOCAL)) AS local,
          c.C2_EMISSAO AS emissao,
          c.C2_DATPRF AS previsao,
          c.C2_DATRF AS encerramento
        FROM {sc2} c
        LEFT JOIN {sb1} p
          ON LTRIM(RTRIM(p.B1_COD)) = LTRIM(RTRIM(c.C2_PRODUTO))
         AND (
           LTRIM(RTRIM(p.B1_FILIAL)) = ?
           OR LTRIM(RTRIM(p.B1_FILIAL)) = ''
         )
        WHERE c.D_E_L_E_T_ <> '*'
          AND c.C2_FILIAL = ?
          AND {_op_match_sql("c", "C2_NUM")}
        ORDER BY c.C2_EMISSAO DESC, c.C2_NUM DESC
        """,
        (filial, filial, op, op, op),
    )
    if row is None:
        return None
    row["emissao"] = _date_br(row.get("emissao"))
    row["previsao"] = _date_br(row.get("previsao"))
    row["encerramento"] = _date_br(row.get("encerramento"))
    row["encerrada"] = row["encerramento"] is not None
    return row


def _official_commitments(conn, op: str, filial: str) -> list[dict[str, Any]]:
    sd4 = tabela("SD4")
    return _fetchall(
        conn,
        f"""
        SELECT
          LTRIM(RTRIM(D4_OP)) AS op,
          LTRIM(RTRIM(D4_COD)) AS produto,
          LTRIM(RTRIM(D4_LOCAL)) AS local,
          D4_QTDEORI AS quantidadeOriginal,
          D4_QUANT AS quantidadeRestante
        FROM {sd4}
        WHERE D_E_L_E_T_ <> '*'
          AND D4_FILIAL = ?
          AND LTRIM(RTRIM(D4_OP)) = ?
        ORDER BY produto, local
        """,
        (filial, op),
    )


def _official_movements(conn, op: str, filial: str) -> list[dict[str, Any]]:
    sd3 = tabela("SD3")
    sb1 = tabela("SB1")
    return _fetchall(
        conn,
        f"""
        SELECT
          LTRIM(RTRIM(d.D3_OP)) AS op,
          LTRIM(RTRIM(d.D3_CF)) AS cf,
          LTRIM(RTRIM(d.D3_TM)) AS tm,
          LTRIM(RTRIM(d.D3_COD)) AS produto,
          LTRIM(RTRIM(COALESCE(p.B1_DESC, ''))) AS produtoDescricao,
          LTRIM(RTRIM(d.D3_LOCAL)) AS local,
          d.D3_QUANT AS quantidade,
          d.D3_DOC AS documento,
          LTRIM(RTRIM(d.D3_NUMSEQ)) AS numSeq,
          d.D3_EMISSAO AS data,
          COALESCE(d.D3_PERDA, 0) AS perda,
          COALESCE(d.D3_QTGANHO, 0) AS ganho,
          LTRIM(RTRIM(COALESCE(d.D3_ESTORNO, ''))) AS estornoRaw
        FROM {sd3} d
        LEFT JOIN {sb1} p
          ON LTRIM(RTRIM(p.B1_COD)) = LTRIM(RTRIM(d.D3_COD))
         AND (
           LTRIM(RTRIM(p.B1_FILIAL)) = ?
           OR LTRIM(RTRIM(p.B1_FILIAL)) = ''
         )
        WHERE d.D_E_L_E_T_ <> '*'
          AND d.D3_FILIAL = ?
          AND LTRIM(RTRIM(d.D3_OP)) = ?
          AND LTRIM(RTRIM(d.D3_CF)) IN ('PR0', 'RE1', 'ER0', 'DE1')
        ORDER BY d.D3_EMISSAO, d.D3_DOC, d.D3_NUMSEQ, d.D3_CF, d.D3_COD
        """,
        (filial, filial, op),
    )


def _official_status(
    ordem: dict[str, Any] | None,
    empenhos: list[dict[str, Any]],
    movimentos: list[dict[str, Any]],
) -> str:
    if ordem is None and not empenhos and not movimentos:
        return "nao_encontrada"
    if ordem and ordem.get("encerrada"):
        return "encerrada"
    has_reversal = any(item.get("cf") in {"ER0", "DE1"} for item in movimentos)
    if has_reversal:
        return "com_estorno"
    has_production = any(item.get("cf") == "PR0" for item in movimentos)
    if has_production:
        planned = ordem.get("quantidadePlanejada") if ordem else 0
        produced = ordem.get("quantidadeProduzida") if ordem else 0
        if planned and produced and produced < planned:
            return "apontada_parcial"
        return "apontada"
    if empenhos:
        return "aberta_com_empenho"
    return "aberta_sem_empenho"


def _movement_warnings(
    ordem: dict[str, Any] | None,
    movimentos: list[dict[str, Any]],
) -> list[str]:
    if ordem is None:
        return []
    local_op = str(ordem.get("local") or "").strip()
    locais_pr0 = sorted(
        {
            str(item.get("local") or "").strip()
            for item in movimentos
            if item.get("cf") == "PR0" and str(item.get("local") or "").strip()
        }
    )
    if not local_op or not locais_pr0:
        return []
    if locais_pr0 == [local_op]:
        return []
    return [
        "Produto acabado entrou em "
        f"{', '.join(locais_pr0)}, diferente do local da OP {local_op}."
    ]


def stock_by_code(codigo: str, filial: str) -> list[dict[str, Any]]:
    return [
        {
            "local": item.get("armazem", ""),
            "saldo": item.get("currentStock", 0),
            "empenhado": item.get("committedQuantity", 0),
        }
        for item in balances_for(codigo, filial)
    ]


def warehouses(filial: str) -> list[dict[str, Any]]:
    nnr = tabela("NNR")
    with conexao() as conn:
        return _fetchall(
            conn,
            f"""
            SELECT
              LTRIM(RTRIM(NNR_FILIAL)) AS filial,
              LTRIM(RTRIM(NNR_CODIGO)) AS code,
              LTRIM(RTRIM(NNR_DESCRI)) AS description,
              LTRIM(RTRIM(COALESCE(NNR_TIPO, ''))) AS type,
              LTRIM(RTRIM(COALESCE(NNR_INTP, ''))) AS integratesProduction,
              LTRIM(RTRIM(COALESCE(NNR_MRP, ''))) AS mrp,
              LTRIM(RTRIM(COALESCE(NNR_ARMALT, ''))) AS alternateWarehouse
            FROM {nnr}
            WHERE D_E_L_E_T_ <> '*'
              AND (
                LTRIM(RTRIM(NNR_FILIAL)) = ?
                OR LTRIM(RTRIM(NNR_FILIAL)) = ''
              )
              AND LTRIM(RTRIM(NNR_CODIGO)) <> ''
            ORDER BY LTRIM(RTRIM(NNR_CODIGO))
            """,
            (filial,),
        )


def _date_br(value: Any) -> str | None:
    raw = str(value or "").strip()
    if len(raw) != 8:
        return None
    return f"{raw[6:8]}/{raw[4:6]}/{raw[0:4]}"
