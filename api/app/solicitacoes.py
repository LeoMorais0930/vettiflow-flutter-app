"""Fila de solicitações: o app pede, o consumidor ADVPL executa no Protheus.

A API nunca grava no ERP. Ela guarda o pedido, entrega ao consumidor com uma
reserva exclusiva, recebe o resultado e confere por SELECT antes de marcar
`aplicada`. Primeiro incremento: só `abertura_op` (MATA650).
"""
from __future__ import annotations

from datetime import date
import secrets
from typing import Any, Literal
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Query, Response, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from . import config, mssql
from .solicitacoes_store import (
    AGUARDANDO_CONFERENCIA,
    ConflitoError,
    NaoEncontradaError,
    NovaSolicitacao,
    ReservaInvalidaError,
    Resultado,
    Solicitacao,
    SolicitacaoStore,
    SqliteSolicitacaoStore,
)

VERSAO_CONTRATO = "vettiflow.solicitacao.v1"
EMPRESA = "01"
FILIAL = "04"

router = APIRouter(prefix="/api/v1", tags=["Fila de solicitações"])

_stores: dict[str, SolicitacaoStore] = {}


def store() -> SolicitacaoStore:
    chave = str(config.QUEUE_DB)
    if chave not in _stores:
        _stores[chave] = SqliteSolicitacaoStore(config.QUEUE_DB)
    return _stores[chave]


class AberturaOp(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    produto: str = Field(min_length=1, max_length=30, pattern=r"^[A-Za-z0-9._/ -]+$")
    quantidade: float = Field(gt=0, le=999_999_999)
    armazem: str = Field(pattern=r"^[0-9A-Z]{2}$")
    dataInicio: date
    dataEntrega: date
    observacao: str = Field(default="", max_length=250)

    @field_validator("quantidade")
    @classmethod
    def _duas_casas(cls, valor: float) -> float:
        if round(valor, 2) != valor:
            raise ValueError("quantidade aceita no máximo 2 casas decimais")
        return valor

    @model_validator(mode="after")
    def _datas(self) -> "AberturaOp":
        if self.dataEntrega < self.dataInicio:
            raise ValueError("dataEntrega não pode ser anterior a dataInicio")
        return self


class NovaSolicitacaoIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    id: UUID
    versaoContrato: Literal["vettiflow.solicitacao.v1"]
    operacao: Literal["abertura_op"]
    solicitante: str = Field(default='', max_length=128)
    payload: AberturaOp


class ReservarIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    operacoes: list[str] | None = None


class ResultadoIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    reserva: str = Field(min_length=1, max_length=64)
    sucesso: bool
    semEfeito: bool = False
    protheusRefs: list[str] = Field(default_factory=list, max_length=50)
    mensagem: str = Field(default="", max_length=2000)
    logExecauto: str = Field(default="", max_length=20000)
    executor: str = Field(default="", max_length=80)

    @model_validator(mode="after")
    def _coerente(self) -> "ResultadoIn":
        if self.sucesso and not self.protheusRefs:
            raise ValueError("sucesso exige ao menos uma referência do Protheus")
        if self.sucesso and self.semEfeito:
            raise ValueError("sucesso e semEfeito são excludentes")
        return self


def _saida(item: Solicitacao, *, com_reserva: bool = False,
           eventos: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    saida = {
        "id": item.id, "versaoContrato": item.versao_contrato,
        "operacao": item.operacao, "empresa": item.empresa, "filial": item.filial,
        "payload": item.payload, "solicitante": item.solicitante,
        "executor": item.executor, "status": item.status,
        "protheusRefs": item.protheus_refs, "mensagem": item.mensagem,
        "criadoEm": item.criado_em, "atualizadoEm": item.atualizado_em,
        "reservadoEm": item.reservado_em,
    }
    if com_reserva:
        saida["reserva"] = item.reserva
    if eventos is not None:
        saida["eventos"] = eventos
        saida["logExecauto"] = item.log_execauto
    return saida


def _exigir_fila() -> None:
    if not config.QUEUE_ENABLED:
        raise HTTPException(503, "Fila de solicitações desativada (VF_QUEUE_ENABLED).")


def _exigir_consumidor(chave: str | None) -> None:
    _exigir_fila()
    if not config.QUEUE_EXECUTION_ENABLED:
        raise HTTPException(503, 'Execução ADVPL bloqueada até homologação.')
    if not config.QUEUE_CONSUMER_TOKEN:
        raise HTTPException(503, "Falta configurar VF_QUEUE_CONSUMER_TOKEN.")
    if not chave or not secrets.compare_digest(chave, config.QUEUE_CONSUMER_TOKEN):
        raise HTTPException(401, "Chave do consumidor inválida.")


def _validar_abertura(payload: AberturaOp) -> None:
    """Valida contra o ERP antes de enfileirar. Falha de leitura recusa o pedido."""
    if payload.dataEntrega < date.today():
        raise HTTPException(422, "A entrega deve ser hoje ou uma data futura.")
    try:
        produto = mssql.product_by_code(payload.produto, FILIAL)
        armazens = {str(a.get("code") or "").strip().upper()
                    for a in mssql.warehouses(FILIAL)}
    except Exception:
        raise HTTPException(
            503, "Não foi possível consultar o Protheus para validar o pedido."
            " Nada foi enfileirado.") from None
    if not produto:
        raise HTTPException(422, f"Produto {payload.produto} não existe na filial {FILIAL}.")
    if str(produto.get("screenBlock") or "") == "1":
        raise HTTPException(422, f"Produto {payload.produto} está bloqueado.")
    if payload.armazem not in armazens:
        raise HTTPException(422, f"Armazém {payload.armazem} não cadastrado na filial {FILIAL}.")


def conferir_abertura(item: Solicitacao) -> tuple[bool, str]:
    """Confere por SELECT a OP que o consumidor informou.

    `protheusRefs[0]` é a OP do produto pedido (C2_NUM+C2_ITEM+C2_SEQUEN);
    o consumidor atual deve retornar somente a OP solicitada, sem intermediárias.
    """
    referencia = item.protheus_refs[0] if item.protheus_refs else ""
    pedido = item.payload
    with mssql.conexao() as conn:
        ordem = mssql._fetchone(conn, f"""
            SELECT LTRIM(RTRIM(C2_PRODUTO)) AS produto, C2_QUANT AS quantidade,
                   LTRIM(RTRIM(C2_LOCAL)) AS armazem
            FROM {mssql.tabela('SC2')}
            WHERE D_E_L_E_T_ = '' AND C2_FILIAL = ?
              AND RTRIM(C2_NUM)+RTRIM(C2_ITEM)+RTRIM(C2_SEQUEN) = ?
        """, (item.filial, referencia))
        empenhos = mssql._fetchone(conn, f"""
            SELECT COUNT(*) AS linhas FROM {mssql.tabela('SD4')}
            WHERE D_E_L_E_T_ = '' AND D4_FILIAL = ? AND D4_OP LIKE ?
        """, (item.filial, referencia + "%"))
    if not ordem:
        return False, f"OP {referencia} não encontrada na SC2. Confira no Protheus antes de repetir."
    divergencias = []
    if ordem["produto"] != pedido["produto"]:
        divergencias.append(f"produto {ordem['produto']} (pedido {pedido['produto']})")
    if float(ordem["quantidade"]) != float(pedido["quantidade"]):
        divergencias.append(f"quantidade {ordem['quantidade']} (pedido {pedido['quantidade']})")
    if ordem["armazem"] != pedido["armazem"]:
        divergencias.append(f"armazém {ordem['armazem']} (pedido {pedido['armazem']})")
    if divergencias:
        return False, f"OP {referencia} diverge do pedido: " + "; ".join(divergencias) + "."
    linhas = int((empenhos or {}).get("linhas") or 0)
    return True, f"OP {referencia} confirmada na SC2 com {linhas} empenho(s) na SD4."


def conferir_exclusao_empenhos(item: Solicitacao) -> tuple[bool, str]:
    pedido = item.payload
    if item.protheus_refs != [pedido['op']]:
        return False, 'Referência retornada diverge da OP revisada.'
    atual = mssql.commitment_review_snapshot(pedido['op'], item.filial)
    antes = pedido['snapshot']
    campos = ('numero', 'produto', 'emissao', 'quantidadePlanejada', 'quantidadeProduzida', 'local', 'encerrada')
    if not atual['order'] or any(str(atual['order'].get(c)) != str(antes['order'].get(c)) for c in campos):
        return False, 'A OP mudou durante a execução. Confira no Protheus.'
    removidos = {r['id'] for r in pedido['excluded']}
    esperados = {r['id']: r for r in antes['items'] if r['id'] not in removidos}
    encontrados = {r['id']: r for r in atual['items']}
    campos_linha = ('produto','local','quantidade','quantidadeOriginal','tratamento',
                    'loteControle','numeroLote','opOrigem','sequencia')
    if set(esperados) != set(encontrados) or any(
        any(encontrados[id_].get(c) != row.get(c) for c in campos_linha)
        for id_, row in esperados.items()):
        return False, 'SD4 diverge da seleção: confira exclusões e empenhos mantidos antes de repetir.'
    return True, f"Exclusão de {len(removidos)} empenho(s) confirmada; demais linhas preservadas."


_CONFERENCIAS = {"abertura_op": conferir_abertura, 'exclusao_empenhos': conferir_exclusao_empenhos}


@router.get('/solicitacoes-status')
def status_fila():
    return {'enabled': config.QUEUE_ENABLED, 'executionEnabled': config.QUEUE_EXECUTION_ENABLED}


def _tentar_conferir(item: Solicitacao) -> Solicitacao:
    if item.status != AGUARDANDO_CONFERENCIA:
        return item
    try:
        confere, mensagem = _CONFERENCIAS[item.operacao](item)
    except Exception:
        # Sem leitura, fica aguardando: nunca vira aplicada nem reenvia.
        return item
    return store().concluir_conferencia(item.id, confere, mensagem)


@router.post("/solicitacoes", status_code=201)
def criar(entrada: NovaSolicitacaoIn, response: Response, request: Request) -> dict:
    _exigir_fila()
    if entrada.operacao not in config.QUEUE_OPERATIONS:
        raise HTTPException(503, f"Operação {entrada.operacao} não liberada nesta API.")
    nova = NovaSolicitacao(
        id=str(entrada.id), versao_contrato=entrada.versaoContrato,
        operacao=entrada.operacao, empresa=EMPRESA, filial=FILIAL,
        payload=entrada.payload.model_dump(mode="json"),
        solicitante=request.state.protheus_session['username'])
    existente = store().obter(nova.id)
    if existente and existente.solicitante != nova.solicitante:
        raise HTTPException(404, 'Solicitação não encontrada.')
    if existente is None:
        _validar_abertura(entrada.payload)
    try:
        item, criada = store().criar(nova)
    except ConflitoError as exc:
        raise HTTPException(409, str(exc)) from None
    if not criada:
        response.status_code = 200
    return _saida(item)


@router.get("/solicitacoes")
def listar(request: Request, status: str | None = None,
           limit: int = Query(default=50, ge=1, le=200)) -> list[dict]:
    return [_saida(item) for item in store().listar(status, limit)
            if item.solicitante == request.state.protheus_session['username']]


@router.get("/solicitacoes/{id_}")
def consultar(id_: UUID, request: Request) -> dict:
    item = store().obter(str(id_))
    if item is None or item.solicitante != request.state.protheus_session['username']:
        raise HTTPException(404, "Solicitação não encontrada.")
    return _saida(item, eventos=store().eventos(item.id))


@router.post("/solicitacoes/{id_}/conferir")
def conferir(id_: UUID, request: Request) -> dict:
    """Refaz a conferência de quem ficou aguardando por falha de leitura."""
    item = store().obter(str(id_))
    if item is None or item.solicitante != request.state.protheus_session['username']:
        raise HTTPException(404, "Solicitação não encontrada.")
    if item.status != AGUARDANDO_CONFERENCIA:
        raise HTTPException(409, f"Solicitação em '{item.status}' não aguarda conferência.")
    item = _tentar_conferir(item)
    if item.status == AGUARDANDO_CONFERENCIA:
        raise HTTPException(503, "Não foi possível consultar o Protheus. Tente de novo.")
    return _saida(item)


@router.post("/consumidor/reservar")
def reservar(entrada: ReservarIn | None = None,
             x_vettiflow_consumer_key: str | None = Header(default=None)):
    _exigir_consumidor(x_vettiflow_consumer_key)
    pedidas = (entrada.operacoes if entrada and entrada.operacoes
               else config.QUEUE_OPERATIONS)
    operacoes = [op for op in pedidas if op in config.QUEUE_OPERATIONS]
    item = store().reservar(operacoes, config.QUEUE_RESERVATION_MINUTES)
    if item is None:
        return Response(status_code=204)
    return _saida(item, com_reserva=True)


@router.get("/consumidor/pendentes")
def pendentes(limit: int = Query(default=20, ge=1, le=100),
              x_vettiflow_consumer_key: str | None = Header(default=None)) -> list[dict]:
    """Só consulta: a opção de menu mostra o pedido antes de reservar."""
    _exigir_consumidor(x_vettiflow_consumer_key)
    itens = store().listar("pendente", limit)
    return [_saida(item) for item in reversed(itens)
            if item.operacao in config.QUEUE_OPERATIONS]


@router.post("/consumidor/solicitacoes/{id_}/reservar")
def reservar_id(id_: UUID,
                x_vettiflow_consumer_key: str | None = Header(default=None)) -> dict:
    _exigir_consumidor(x_vettiflow_consumer_key)
    atual = store().obter(str(id_))
    if atual is None:
        raise HTTPException(404, "Solicitação não encontrada.")
    if atual.operacao not in config.QUEUE_OPERATIONS:
        raise HTTPException(503, f"Operação {atual.operacao} não liberada nesta API.")
    item = store().reservar_id(str(id_), config.QUEUE_RESERVATION_MINUTES)
    if item is None:
        raise HTTPException(409, "Solicitação já não está pendente: outro consumidor pegou"
                                 " ou ela foi concluída.")
    return _saida(item, com_reserva=True)


@router.post("/consumidor/solicitacoes/{id_}/resultado")
def registrar_resultado(id_: UUID, entrada: ResultadoIn, request: Request,
                        x_vettiflow_consumer_key: str | None = Header(default=None)) -> dict:
    _exigir_consumidor(x_vettiflow_consumer_key)
    try:
        item = store().registrar_resultado(str(id_), entrada.reserva, Resultado(
            sucesso=entrada.sucesso, sem_efeito=entrada.semEfeito,
            protheus_refs=entrada.protheusRefs, mensagem=entrada.mensagem,
            log_execauto=entrada.logExecauto, executor=request.state.protheus_session['username']))
    except NaoEncontradaError:
        raise HTTPException(404, "Solicitação não encontrada.") from None
    except ReservaInvalidaError:
        raise HTTPException(409, "Reserva não confere com a solicitação.") from None
    except ConflitoError as exc:
        raise HTTPException(409, str(exc)) from None
    return _saida(_tentar_conferir(item))
