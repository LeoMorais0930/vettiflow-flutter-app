"""Abertura explícita de OP em DEV; nunca escreve nas tabelas do ERP.

O adapter requer o contrato documentado em docs/desenvolvimento/escrita-dev.md.
Ele não pressupõe que qualquer serviço REST TOTVS implemente esse contrato.
"""
from __future__ import annotations

from contextlib import contextmanager
from datetime import date, datetime
import hashlib
import json
import re
import sqlite3
from urllib.parse import urlsplit

import httpx
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, ConfigDict, Field

from . import config, mssql

router = APIRouter(prefix="/api/v1/dev/almoxarifado", tags=["Escrita DEV"])
_BLOCKED = ["empenho", "apontamento_op", "transferencia", "desmontagem", "sql_direto"]


class Opening(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    opLocal: str = Field(min_length=1, max_length=80)
    criadaEm: datetime
    produto: str = Field(min_length=1, max_length=30, pattern=r"^[A-Za-z0-9._/ -]+$")
    quantidade: int = Field(gt=0, le=999999999, strict=True)
    armazem: str = Field(pattern=r"^(01|03|05)$")
    entrega: date
    usarEstruturaProtheus: bool

    @property
    def key(self) -> str:
        identity = f"HMLp12:01:04:{self.opLocal}:{self.criadaEm.isoformat()}"
        return hashlib.sha256(identity.encode()).hexdigest()


def readiness(info: dict | None = None) -> dict:
    info = info or mssql.health()
    reasons = []
    if not config.WRITE_ENABLED:
        reasons.append("Escrita DEV desativada na API.")
    if (info.get("banco", "").lower() != "hmlp12"
            or config.MSSQL_DATABASE.lower() != "hmlp12"
            or config.EMPRESA != "010" or config.PROTHEUS_COMPANY_GROUP != "01"
            or config.FILIAL_PADRAO != "04"):
        reasons.append("A escrita exige HMLp12, grupo 01 e filial 04 (tabelas 010).")
    url = urlsplit(config.PROTHEUS_WRITE_URL)
    if not url.hostname:
        reasons.append("Falta conectar o serviço de abertura de OP do Protheus DEV.")
    elif (url.scheme != "https" or url.username or url.password
          or url.query or url.fragment):
        reasons.append("O serviço DEV exige um endereço HTTPS válido.")
    configured = not reasons
    return {
        "readOnly": not configured,
        "writeEnabled": config.WRITE_ENABLED,
        "writeAvailable": configured,
        "status": "aguardando_autenticacao_protheus" if configured else
                  "conexao_pendente" if config.WRITE_ENABLED else "bloqueada_por_politica",
        "database": info.get("banco", ""),
        "company": config.PROTHEUS_COMPANY_GROUP,
        "branch": config.FILIAL_PADRAO,
        "tableSuffix": config.EMPRESA,
        "enabledOperations": ["abertura_op"] if configured else [],
        "blockedOperations": _BLOCKED + ([] if configured else ["abertura_op"]),
        "futureRequirements": reasons,
        "candidateRoutines": ["MATA650"],
    }


@contextmanager
def ledger():
    config.WRITE_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(config.WRITE_LEDGER, timeout=15)
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("""CREATE TABLE IF NOT EXISTS openings (
            id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, payload TEXT NOT NULL,
            status TEXT NOT NULL, reference TEXT, message TEXT NOT NULL,
            actor TEXT NOT NULL, updated TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )""")
        conn.commit()
        yield conn
    finally:
        conn.close()


def _result(row) -> dict:
    return {"id": row["id"], "status": row["status"],
            "protheusRef": row["reference"], "message": row["message"],
            "opLocal": json.loads(row["payload"])["opLocal"]}


def _save(key: str, status: str, message: str, reference: str | None = None) -> dict:
    with ledger() as conn:
        conn.execute("""UPDATE openings SET status=?, message=?, reference=?,
                        updated=CURRENT_TIMESTAMP WHERE id=?""",
                     (status, message, reference, key))
        conn.commit()
        return _result(conn.execute("SELECT * FROM openings WHERE id=?", (key,)).fetchone())


def _validate_target(data: dict, sql_info: dict) -> None:
    # Identidade deve ser lida pelo serviço na conexão efetiva do AppServer.
    if (data.get("contract") != "vettiflow.op.v1"
            or str(data.get("database", "")).lower() != "hmlp12"
            or str(data.get("server", "")).lower() != str(sql_info.get("servidor", "")).lower()
            or not sql_info.get("servidor")
            or data.get("company") != "01" or data.get("branch") != "04"):
        raise HTTPException(409, "O AppServer não confirmou o mesmo ambiente DEV da consulta SQL.")


def _authenticate(authorization: str | None, sql_info: dict) -> tuple[dict, dict]:
    if not authorization or not authorization.startswith("Basic ") or len(authorization) > 2048:
        raise HTTPException(401, "Informe seu usuário e senha do Protheus DEV.")
    headers = {"Authorization": authorization, "Accept": "application/json",
               "tenantId": "01,04"}
    try:
        response = httpx.get(config.PROTHEUS_WRITE_URL + "/capabilities",
                             headers=headers, timeout=12, follow_redirects=False,
                             verify=config.protheus_ssl_context(), trust_env=False)
        if response.status_code in (401, 403):
            raise HTTPException(response.status_code, "Usuário Protheus sem autorização para abrir OP pelo VettiFlow.")
        response.raise_for_status()
        data = response.json()
        if not isinstance(data, dict):
            raise ValueError("Resposta inválida")
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(503, "O serviço DEV não confirmou a conexão. Nenhum envio foi feito.") from exc
    _validate_target(data, sql_info)
    if (not data.get("userId") or "abertura_op" not in data.get("allowedOperations", [])
            or data.get("routine") != "MATA650"
            or data.get("vettiCommitmentWarehouse") is not True):
        raise HTTPException(403, "O serviço não liberou a abertura com as regras de empenho da Vetti.")
    return headers, data


def _confirmed(reference: str, payload: Opening) -> bool:
    # Somente SELECT. Não inferimos sucesso apenas de HTTP 200 do AppServer.
    with mssql.conexao() as conn:
        row = mssql._fetchone(conn, f"""
            SELECT C2_PRODUTO AS produto, C2_QUANT AS quantidade, C2_LOCAL AS armazem
            FROM {mssql.tabela('SC2')}
            WHERE D_E_L_E_T_ = '' AND C2_FILIAL = ?
              AND RTRIM(C2_NUM)+RTRIM(C2_ITEM)+RTRIM(C2_SEQUEN)+RTRIM(C2_ITEMGRD) = ?
        """, ("04", reference))
    return bool(row and row["produto"] == payload.produto
                and row["quantidade"] == payload.quantidade
                and row["armazem"] == payload.armazem)


@router.post("/ops")
def open_order(payload: Opening, authorization: str | None = Header(default=None)) -> dict:
    info = mssql.health()
    ready = readiness(info)
    if not ready["writeAvailable"]:
        raise HTTPException(503, " ".join(ready["futureRequirements"]))
    if not payload.usarEstruturaProtheus:
        raise HTTPException(422, "Esta primeira integração usa a estrutura atual do Protheus. Ajustes de empenhos serão integrados separadamente.")
    headers, capabilities = _authenticate(authorization, info)
    body = payload.model_dump(mode="json")
    encoded = json.dumps(body, sort_keys=True, ensure_ascii=False)
    fingerprint = hashlib.sha256(encoded.encode()).hexdigest()
    with ledger() as conn:
        # Persiste ANTES do POST. Falha de rede/reinício nunca autoriza reenvio.
        conn.execute("BEGIN IMMEDIATE")
        previous = conn.execute("SELECT * FROM openings WHERE id=?", (payload.key,)).fetchone()
        if previous:
            if previous["fingerprint"] != fingerprint:
                raise HTTPException(409, "Esta OP local já tem um envio com outros dados. Consulte o resultado antes de alterar.")
            return _result(previous)
        if payload.entrega < date.today():
            raise HTTPException(422, "A entrega deve ser hoje ou uma data futura.")
        product = mssql.product_by_code(payload.produto, "04")
        if not product or product.get("screenBlock") == "1":
            raise HTTPException(422, "Produto inexistente ou bloqueado no DEV.")
        conn.execute("""INSERT INTO openings
            (id, fingerprint, payload, status, message, actor) VALUES (?, ?, ?, ?, ?, ?)""",
            (payload.key, fingerprint, encoded, "conferir", "Envio iniciado. Consulte o resultado antes de repetir.", capabilities["userId"]))
        conn.commit()
    try:
        response = httpx.post(config.PROTHEUS_WRITE_URL + "/orders", headers={
            **headers, "Idempotency-Key": payload.key},
            json={"contract": "vettiflow.op.v1", "id": payload.key,
                  "company": "01", "branch": "04", "database": "HMLp12",
                  "operation": "abertura_op", "payload": body},
            timeout=60, follow_redirects=False,
            verify=config.protheus_ssl_context(), trust_env=False)
        # Respostas não documentadas, redirects e erros de rede são ambíguos.
        response.raise_for_status()
        data = response.json()
        _validate_target(data, info)
        if data.get("id") != payload.key:
            raise ValueError("Identificador de retorno diferente")
        reference = str(data.get("protheusRef", "")).strip()
        if data.get("status") == "rejected" and data.get("rolledBack") is True:
            return _save(payload.key, "recusada", str(data.get("message") or "Protheus recusou a abertura.")[:1000])
        if data.get("status") != "applied" or not re.fullmatch(r"[A-Za-z0-9]{6,40}", reference):
            raise ValueError("Sem referência de OP aplicada")
        _save(payload.key, "conferir", "Protheus respondeu. Falta confirmar a OP na consulta SQL.", reference)
        if not _confirmed(reference, payload):
            return _save(payload.key, "conferir", "OP retornada pelo Protheus; dados ainda não conferem na consulta. Não reenvie.", reference)
        return _save(payload.key, "aplicada", "OP confirmada no Protheus DEV.", reference)
    except Exception:
        # Não armazena credenciais, corpo de erro HTTP ou stacktrace em resposta.
        with ledger() as conn:
            row = conn.execute("SELECT * FROM openings WHERE id=?", (payload.key,)).fetchone()
        return _save(payload.key, "conferir", "O retorno não pôde ser confirmado. Confira no Protheus antes de qualquer novo envio.", row["reference"])


@router.post("/ops/consultar")
def consult_order(payload: Opening, authorization: str | None = Header(default=None)) -> dict:
    """Consulta o vínculo; não cria nem reenvia OP ao Protheus."""
    info = mssql.health()
    if not readiness(info)["writeAvailable"]:
        raise HTTPException(503, "A conexão de escrita DEV ainda não está configurada.")
    _authenticate(authorization, info)
    with ledger() as conn:
        row = conn.execute("SELECT * FROM openings WHERE id=?", (payload.key,)).fetchone()
    if not row:
        return {"id": payload.key, "status": "nao_enviada", "message": "Esta OP ainda não foi enviada.", "protheusRef": None, "opLocal": payload.opLocal}
    original = Opening.model_validate_json(row["payload"])
    if row["status"] == "conferir" and row["reference"] and _confirmed(row["reference"], original):
        return _save(payload.key, "aplicada", "OP confirmada no Protheus DEV.", row["reference"])
    return _result(row)
